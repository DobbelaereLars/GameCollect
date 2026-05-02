import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../notifications/notification_service.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

/// Wat te doen als een gebruiker inlogt op een toestel dat al lokale data heeft
/// EN er al clouddata aanwezig is.
enum InitialSyncStrategy {
  /// Stuur alles lokaal naar de cloud, vervangt eventuele clouddata.
  overwriteCloud,

  /// Wis lokale data en haal alles op uit de cloud.
  overwriteLocal,

  /// Bidirectionele last-write-wins-samenvoeging over beide kanten.
  merge,
}

/// Coördineert bidirectionele synchronisatie tussen de lokale SQLite-database en
/// Firestore. Last-write-wins per record op basis van `updatedAt` (epoch ms).
///
/// Actief alleen wanneer:
///  - Firebase geconfigureerd is (Firebase.apps niet leeg)
///  - De gebruiker is ingelogd
///  - Er een internetverbinding is
///
/// Anders no-op en stelt [pendingChanges] beschikbaar zodat de UI
/// "X wijzigingen wachten op verbinding" kan tonen.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _kLastSyncAtKey = 'lastSyncAt';

  bool _isSyncing = false;
  String? _lastError;
  DateTime? _lastSyncAt;
  int _pendingChanges = 0;
  Timer? _autoSyncTimer;
  bool _wired = false;

  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => _lastSyncAt;
  int get pendingChanges => _pendingChanges;

  /// Koppelt luisteraars. Eenmalig aanroepen nadat Firebase, Auth en Connectivity
  /// zijn geïnitialiseerd.
  Future<void> wire() async {
    if (_wired) return;
    _wired = true;

    final lastSyncStr = await DatabaseHelper.instance.getSetting(
      _kLastSyncAtKey,
    );
    if (lastSyncStr != null) {
      _lastSyncAt = DateTime.tryParse(lastSyncStr);
    }
    await _refreshPendingCount();

    DatabaseHelper.instance.addListener(_onLocalChange);
    AuthService.instance.addListener(_onAuthOrConnectivityChange);
    ConnectivityService.instance.addListener(_onAuthOrConnectivityChange);
  }

  /// Reageert op lokale databasewijzigingen: herlaadt pending count en plant autosync.
  void _onLocalChange() {
    _refreshPendingCount();
    _scheduleAutoSync();
  }

  /// Reageert op wijzigingen in authenticatie of connectiviteit: start sync indien mogelijk.
  void _onAuthOrConnectivityChange() {
    _refreshPendingCount();
    if (AuthService.instance.isSignedIn &&
        ConnectivityService.instance.isOnline) {
      // Achtergrond uitvoeren; fouten worden via [lastError] zichtbaar gemaakt.
      unawaited(syncNow());
    } else {
      notifyListeners();
    }
  }

  /// Plant een debounced autosync van 2 seconden na elke lokale wijziging.
  void _scheduleAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(const Duration(seconds: 2), () {
      if (AuthService.instance.isSignedIn &&
          ConnectivityService.instance.isOnline) {
        unawaited(syncNow());
      }
    });
  }

  /// Herlaadt het aantal niet-gesynchroniseerde lokale wijzigingen.
  Future<void> _refreshPendingCount() async {
    final since = _lastSyncAt?.millisecondsSinceEpoch ?? 0;
    final count = await DatabaseHelper.instance.countLocalChangesSince(since);
    if (count != _pendingChanges) {
      _pendingChanges = count;
      notifyListeners();
    }
  }

  /// True als de sync-infrastructuur beschikbaar is (Firebase + Auth + Online).
  bool get canSync =>
      Firebase.apps.isNotEmpty &&
      AuthService.instance.isSignedIn &&
      ConnectivityService.instance.isOnline;

  /// Voert een volledige bidirectionele sync uit. Veilig om meerdere keren aan te roepen.
  Future<bool> syncNow({InitialSyncStrategy? strategy}) async {
    if (_isSyncing) return false;
    if (Firebase.apps.isEmpty) return false;
    final uid = AuthService.instance.uid;
    if (uid == null) return false;
    if (!ConnectivityService.instance.isOnline) {
      // Hercontroleer één keer vóór opgave — connectiviteitsgebeurtenissen kunnen vertraagd zijn.
      final ok = await ConnectivityService.instance.recheck();
      if (!ok) return false;
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      if (strategy == InitialSyncStrategy.overwriteLocal) {
        await DatabaseHelper.instance.clearAllSyncableLocalData();
        _lastSyncAt = null;
      } else if (strategy == InitialSyncStrategy.overwriteCloud) {
        await _wipeCloud(uid);
        await DatabaseHelper.instance.markAllSyncableRowsDirty();
        _lastSyncAt = null;
      }

      final sinceMs = _lastSyncAt?.millisecondsSinceEpoch ?? 0;
      final cycleStart = DateTime.now();

      // 1. Duw lokale wijzigingen (na sinceMs) naar Firestore.
      await _pushChanges(uid, sinceMs);

      // 2. Haal externe wijzigingen (na sinceMs) op uit Firestore.
      await _pullChanges(uid, sinceMs);

      // 3. Synchroniseer de notificatievoorkeur. Afwijkende conflictregels;
      //    buiten de rijniveau-sync gehouden.
      await _syncNotificationsPreference(uid, strategy);

      _lastSyncAt = cycleStart;
      await DatabaseHelper.instance.setSetting(
        _kLastSyncAtKey,
        cycleStart.toIso8601String(),
      );
      await _refreshPendingCount();
      return true;
    } catch (error) {
      _lastError = error.toString();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ── PUSH ──────────────────────────────────────────────────────────────────

  /// Stuurt lokale wijzigingen (collectie, achievements, tellers) naar Firestore.
  Future<void> _pushChanges(String uid, int sinceMs) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(uid);

    final collectionRows = await DatabaseHelper.instance
        .getCollectionRowsChangedSince(sinceMs);
    for (final batchRows in _chunked(collectionRows, 400)) {
      final batch = firestore.batch();
      for (final row in batchRows) {
        final syncId = row['syncId'] as String?;
        if (syncId == null) continue;
        batch.set(
          userDoc.collection('collection').doc(syncId),
          _stripLocalIds(row),
        );
      }
      await batch.commit();
    }

    final achievementRows = await DatabaseHelper.instance
        .getAppAchievementRowsChangedSince(sinceMs);
    for (final batchRows in _chunked(achievementRows, 400)) {
      final batch = firestore.batch();
      for (final row in batchRows) {
        final id = row['id'] as String?;
        if (id == null) continue;
        batch.set(
          userDoc.collection('appAchievements').doc(id),
          Map<String, dynamic>.from(row),
        );
      }
      await batch.commit();
    }

    final counterRows = await DatabaseHelper.instance
        .getEventCounterRowsChangedSince(sinceMs);
    for (final batchRows in _chunked(counterRows, 400)) {
      final batch = firestore.batch();
      for (final row in batchRows) {
        final key = row['key'] as String?;
        if (key == null) continue;
        batch.set(
          userDoc.collection('eventCounters').doc(key),
          Map<String, dynamic>.from(row),
        );
      }
      await batch.commit();
    }
  }

  // ── PULL ──────────────────────────────────────────────────────────────────

  /// Haalt wijzigingen op uit Firestore en past ze toe op de lokale database.
  Future<void> _pullChanges(String uid, int sinceMs) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(uid);

    final collectionSnap = await userDoc
        .collection('collection')
        .where('updatedAt', isGreaterThan: sinceMs)
        .get();
    for (final doc in collectionSnap.docs) {
      final row = Map<String, dynamic>.from(doc.data());
      await DatabaseHelper.instance.applyRemoteCollectionRow(row);
      // Als er een cloud-cover URL is, download dan lokaal zodat de UI
      // geen netwerkverzoek nodig heeft voor elke weergave.
      final cloudUrl = row['cloudCoverUrl'] as String?;
      if (cloudUrl != null && cloudUrl.isNotEmpty) {
        await _downloadCoverIfAbsent(cloudUrl, uid, row['syncId'] as String?);
      }
    }

    final achievementsSnap = await userDoc
        .collection('appAchievements')
        .where('updatedAt', isGreaterThan: sinceMs)
        .get();
    for (final doc in achievementsSnap.docs) {
      await DatabaseHelper.instance.applyRemoteAppAchievementRow(
        Map<String, dynamic>.from(doc.data()),
      );
    }

    final countersSnap = await userDoc
        .collection('eventCounters')
        .where('updatedAt', isGreaterThan: sinceMs)
        .get();
    for (final doc in countersSnap.docs) {
      await DatabaseHelper.instance.applyRemoteEventCounterRow(
        Map<String, dynamic>.from(doc.data()),
      );
    }
  }

  // ── Cloud opschonen ──────────────────────────────────────────────────────────

  Future<void> _wipeCloud(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(uid);
    for (final sub in const [
      'collection',
      'appAchievements',
      'eventCounters',
    ]) {
      final snap = await userDoc.collection(sub).get();
      for (final batchDocs in _chunked(snap.docs, 400)) {
        final batch = firestore.batch();
        for (final doc in batchDocs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    // Verwijder ook voorkeuren op gebruikersniveau (meldingen, ...).
    await userDoc
        .collection('preferences')
        .doc('main')
        .delete()
        .catchError((_) {});
  }

  // ── Voorkeurssync (notificaties) ───────────────────────────────────────────────
  //
  // Conflictregels (per spec):
  //   merge           → ingeschakeld = lokaal OF extern (AAN wint altijd)
  //   overwriteCloud  → duw lokale waarde, negeer extern
  //   overwriteLocal  → neem externe waarde, negeer lokaal
  //   null (normaal)  → last-write-wins op `updatedAt`

  /// Synchroniseert de meldingsvoorkeur tussen de lokale database en Firestore.
  Future<void> _syncNotificationsPreference(
    String uid,
    InitialSyncStrategy? strategy,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore
        .collection('users')
        .doc(uid)
        .collection('preferences')
        .doc('main');

    final localEnabled = await DatabaseHelper.instance
        .getNotificationsEnabled();
    final localUpdatedAt = await DatabaseHelper.instance
        .getNotificationsUpdatedAt();

    final snap = await docRef.get();
    final remoteData = snap.data();
    final hasRemote = remoteData != null;
    final remoteEnabled =
        (remoteData?['notificationsEnabled'] as bool?) ?? true;
    final remoteUpdatedAt =
        (remoteData?['notificationsEnabledUpdatedAt'] as num?)?.toInt() ?? 0;

    debugPrint(
      '[SyncService] notif sync: strategy=$strategy local=$localEnabled '
      '(t=$localUpdatedAt) remote=$remoteEnabled (t=$remoteUpdatedAt) '
      'hasRemote=$hasRemote',
    );

    bool? newLocalValue;
    Map<String, dynamic>? newRemotePayload;
    int newUpdatedAt = DateTime.now().millisecondsSinceEpoch;

    if (strategy != null) {
      // Account koppelen (registreren of inloggen): altijd OR-samenvoeging.
      // Notificatie is AAN zodra één kant AAN is.
      // Geldt ongeacht de gekozen datastrategie (merge/overwrite).
      final merged = localEnabled || (hasRemote && remoteEnabled);
      if (merged != localEnabled) newLocalValue = merged;
      newRemotePayload = {
        'notificationsEnabled': merged,
        'notificationsEnabledUpdatedAt': newUpdatedAt,
      };
    } else {
      // Normale sync: last-write-wins op `updatedAt`.
      // OR-samenvoeging gebeurt uitsluitend bij account koppelen (strategy != null).
      if (!hasRemote) {
        // Niets in de cloud → stuur lokale waarde.
        newRemotePayload = {
          'notificationsEnabled': localEnabled,
          'notificationsEnabledUpdatedAt': localUpdatedAt == 0
              ? newUpdatedAt
              : localUpdatedAt,
        };
      } else if (localUpdatedAt > remoteUpdatedAt) {
        // Lokaal is recenter → naar cloud pushen.
        newRemotePayload = {
          'notificationsEnabled': localEnabled,
          'notificationsEnabledUpdatedAt': localUpdatedAt,
        };
      } else if (remoteUpdatedAt > localUpdatedAt) {
        // Cloud is recenter → externe waarde overnemen.
        if (remoteEnabled != localEnabled) newLocalValue = remoteEnabled;
        newUpdatedAt = remoteUpdatedAt;
      }
      // Gelijk: niets te doen.
    }

    if (newRemotePayload != null) {
      try {
        // Gebruik merge: true zodat de schrijfactie slaagt ook als het
        // bovenliggende document nog niet strikt bestaat via set().
        await docRef.set(newRemotePayload, SetOptions(merge: true));
        debugPrint(
          '[SyncService] notif sync: pushed $newRemotePayload to '
          '${docRef.path}',
        );
      } catch (e, st) {
        debugPrint('[SyncService] notif sync: push FAILED: $e\n$st');
        rethrow;
      }
    } else {
      debugPrint('[SyncService] notif sync: no remote write needed');
    }
    if (newLocalValue != null) {
      await DatabaseHelper.instance.applyRemoteNotificationsPreference(
        enabled: newLocalValue,
        updatedAt: newUpdatedAt,
      );
      // Pas de wijziging toe op de platformnotificatieplanner.
      if (newLocalValue) {
        await NotificationService.instance.requestPermissions();
        await NotificationService.instance.scheduleAll();
      } else {
        await NotificationService.instance.cancelAll();
      }
    }
  }

  /// Geeft true als de cloud al data heeft voor deze gebruiker. Gebruikt om te bepalen
  /// of het samenvoegdialoog getoond moet worden bij aanmelden.
  /// Tombstones (zacht-verwijderde rijen met `deletedAt`) worden genegeerd —
  /// dit zijn geen echte gebruikersdata, alleen verwijderingsmarkeringen.
  Future<bool> remoteHasData(String uid) async {
    if (Firebase.apps.isEmpty) return false;
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(uid);
    final colSnap = await userDoc
        .collection('collection')
        .where('deletedAt', isNull: true)
        .limit(1)
        .get();
    if (colSnap.docs.isNotEmpty) return true;
    final achSnap = await userDoc
        .collection('appAchievements')
        .where('deletedAt', isNull: true)
        .limit(1)
        .get();
    return achSnap.docs.isNotEmpty;
  }

  /// Of het toestel op dit moment lokale syncbare data heeft.
  /// Houdt rekening met zowel de gamecollectie als ontgrendelde achievements,
  /// zodat het dialoog ook verschijnt voor gebruikers zonder games maar met voortgang.
  Future<bool> localHasData() async {
    final items = await DatabaseHelper.instance.getCollectionItems();
    if (items.isNotEmpty) return true;
    final achievements = await DatabaseHelper.instance.getAppAchievements();
    return achievements.isNotEmpty;
  }

  /// Downloadt een cover-afbeelding van [cloudUrl] naar lokale opslag als die
  /// nog niet aanwezig is, en werkt de DB-rij bij met het lokale pad.
  Future<void> _downloadCoverIfAbsent(
    String cloudUrl,
    String uid,
    String? syncId,
  ) async {
    try {
      if (syncId == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/covers/$syncId.jpg';
      final file = File(localPath);
      if (await file.exists()) return; // al aanwezig
      await file.parent.create(recursive: true);
      final response = await http.get(Uri.parse(cloudUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        // Werk het lokale pad bij in de DB via een directe update.
        final db = await DatabaseHelper.instance.database;
        await db.rawUpdate(
          'UPDATE collection SET customCoverPath = ? WHERE syncId = ?',
          [localPath, syncId],
        );
      }
    } catch (_) {
      // Niet fataal: app werkt gewoon met de cloud URL als fallback.
    }
  }

  /// Verwijdert het lokale auto-increment ID en het lokale bestandspad zodat
  /// Firestore alleen overdraagbare data ontvangt.
  Map<String, dynamic> _stripLocalIds(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    out.remove('id'); // lokale auto-increment, wordt niet gesynchroniseerd
    out.remove('customCoverPath'); // lokaal bestandspad, niet over te dragen
    return out;
  }

  /// Splits een lijst in sublijsten van maximaal [size] elementen.
  Iterable<List<T>> _chunked<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, (i + size).clamp(0, list.length));
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    DatabaseHelper.instance.removeListener(_onLocalChange);
    AuthService.instance.removeListener(_onAuthOrConnectivityChange);
    ConnectivityService.instance.removeListener(_onAuthOrConnectivityChange);
    super.dispose();
  }
}
