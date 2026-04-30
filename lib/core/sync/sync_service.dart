import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../notifications/notification_service.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

/// What to do when a user signs in on a device that already has local data
/// AND a cloud document set.
enum InitialSyncStrategy {
  /// Push everything local to the cloud, replacing any cloud data.
  overwriteCloud,

  /// Wipe local data, then pull everything from the cloud.
  overwriteLocal,

  /// Bidirectional last-write-wins merge across both sides.
  merge,
}

/// Coordinates bidirectional sync between the local SQLite database and
/// Firestore. Last-write-wins per record using `updatedAt` (epoch ms).
///
/// Runs only when:
///  - Firebase is configured (Firebase.apps not empty)
///  - The user is signed in
///  - Connectivity is online
///
/// Otherwise no-ops and exposes [pendingChanges] so the UI can communicate
/// "X wijzigingen wachten op verbinding".
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

  /// Wires up listeners. Call once after Firebase + Auth + Connectivity
  /// have been initialized.
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

  void _onLocalChange() {
    _refreshPendingCount();
    _scheduleAutoSync();
  }

  void _onAuthOrConnectivityChange() {
    _refreshPendingCount();
    if (AuthService.instance.isSignedIn &&
        ConnectivityService.instance.isOnline) {
      // Fire-and-forget; errors are surfaced via [lastError].
      unawaited(syncNow());
    } else {
      notifyListeners();
    }
  }

  void _scheduleAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(const Duration(seconds: 2), () {
      if (AuthService.instance.isSignedIn &&
          ConnectivityService.instance.isOnline) {
        unawaited(syncNow());
      }
    });
  }

  Future<void> _refreshPendingCount() async {
    final since = _lastSyncAt?.millisecondsSinceEpoch ?? 0;
    final count = await DatabaseHelper.instance.countLocalChangesSince(since);
    if (count != _pendingChanges) {
      _pendingChanges = count;
      notifyListeners();
    }
  }

  /// True when sync infrastructure is callable (Firebase + Auth + Online).
  bool get canSync =>
      Firebase.apps.isNotEmpty &&
      AuthService.instance.isSignedIn &&
      ConnectivityService.instance.isOnline;

  /// Run a full bidirectional sync. Safe to call repeatedly.
  Future<bool> syncNow({InitialSyncStrategy? strategy}) async {
    if (_isSyncing) return false;
    if (Firebase.apps.isEmpty) return false;
    final uid = AuthService.instance.uid;
    if (uid == null) return false;
    if (!ConnectivityService.instance.isOnline) {
      // Recheck once before giving up — connectivity events can lag.
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

      // 1. Push local changes (after sinceMs) to Firestore.
      await _pushChanges(uid, sinceMs);

      // 2. Pull remote changes (after sinceMs) from Firestore.
      await _pullChanges(uid, sinceMs);

      // 3. Sync the notifications preference. Different conflict rules apply
      //    here, so it lives outside the row-level sync.
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

  Future<void> _pullChanges(String uid, int sinceMs) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(uid);

    final collectionSnap = await userDoc
        .collection('collection')
        .where('updatedAt', isGreaterThan: sinceMs)
        .get();
    for (final doc in collectionSnap.docs) {
      await DatabaseHelper.instance.applyRemoteCollectionRow(
        Map<String, dynamic>.from(doc.data()),
      );
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

  // ── Cloud cleanup ────────────────────────────────────────────────────────

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
    // Also clear user-level preferences (notifications, …).
    await userDoc
        .collection('preferences')
        .doc('main')
        .delete()
        .catchError((_) {});
  }

  // ── Preferences sync (notifications) ─────────────────────────────────────
  //
  // Conflict rules (per spec):
  //   merge           → enabled = local OR remote (any AAN wins)
  //   overwriteCloud  → push local, ignore remote
  //   overwriteLocal  → take remote, ignore local
  //   null (regular)  → last-write-wins on `updatedAt`

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

    if (strategy == InitialSyncStrategy.overwriteCloud) {
      newRemotePayload = {
        'notificationsEnabled': localEnabled,
        'notificationsEnabledUpdatedAt': localUpdatedAt == 0
            ? newUpdatedAt
            : localUpdatedAt,
      };
    } else if (strategy == InitialSyncStrategy.overwriteLocal) {
      if (hasRemote) {
        newLocalValue = remoteEnabled;
        newUpdatedAt = remoteUpdatedAt;
      }
    } else if (strategy == InitialSyncStrategy.merge) {
      // OR-merge: any "AAN" wins.
      final merged = localEnabled || (hasRemote && remoteEnabled);
      if (merged != localEnabled) newLocalValue = merged;
      newRemotePayload = {
        'notificationsEnabled': merged,
        'notificationsEnabledUpdatedAt': newUpdatedAt,
      };
    } else {
      // Normal sync: OR-merge — any "AAN" wins; alleen "uit+uit" = "uit".
      // Rationale: een expliciete "aan" op om het even welk apparaat moet
      // gerespecteerd worden, ook als het lokale apparaat toevallig "uit"
      // heeft (bv. net aangemeld terwijl meldingen lokaal tijdelijk uitstonden).
      final merged = localEnabled || (hasRemote && remoteEnabled);
      if (merged != localEnabled) newLocalValue = merged;
      // Schrijf altijd naar de cloud zodat het document altijd bestaat en de
      // waarde up-to-date blijft.
      final mergedUpdatedAt = localUpdatedAt == 0
          ? newUpdatedAt
          : localUpdatedAt;
      newRemotePayload = {
        'notificationsEnabled': merged,
        'notificationsEnabledUpdatedAt': mergedUpdatedAt,
      };
    }

    if (newRemotePayload != null) {
      try {
        // Force the use of merge: true so that the write succeeds even if
        // the parent document doesn't strictly exist via a prior set().
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
      // Apply the change to the platform notification scheduler.
      if (newLocalValue) {
        await NotificationService.instance.requestPermissions();
        await NotificationService.instance.scheduleAll();
      } else {
        await NotificationService.instance.cancelAll();
      }
    }
  }

  /// Returns true if the cloud already has data for this user. Used to decide
  /// whether to prompt the merge dialog at sign-in time.
  /// Tombstones (soft-deleted rows where `deletedAt` is set) are ignored —
  /// they are not real user data, just deletion markers.
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

  /// Whether the device has local syncable data right now.
  /// Considers both the game collection and unlocked app-level achievements,
  /// so the merge dialog also fires for users with no games but with progress.
  Future<bool> localHasData() async {
    final items = await DatabaseHelper.instance.getCollectionItems();
    if (items.isNotEmpty) return true;
    final achievements = await DatabaseHelper.instance.getAppAchievements();
    return achievements.isNotEmpty;
  }

  Map<String, dynamic> _stripLocalIds(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    out.remove('id'); // local autoincrement, not synced
    return out;
  }

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
