import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/collection/domain/collection_item.dart';
import '../../features/discover/domain/rawg_game.dart';

import "package:flutter/foundation.dart";

/// Genereert een v4 UUID via een cryptografisch veilige willekeurigeidsgenerator.
/// Geen externe afhankelijkheden vereist.
String generateSyncId() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  // RFC 4122 variant- en versie-4-bits instellen.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

class DatabaseHelper extends ChangeNotifier {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Wist de gecachte databasereferentie zodat de volgende toegang hem opnieuw opent.
  /// Roep dit aan voor het verwijderen van het databasebestand bij een app-reset.
  static void resetInstance() {
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gamecollect.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 11,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE collection (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  apiId INTEGER NOT NULL,
  title TEXT NOT NULL,
  coverUrl TEXT,
  customCoverPath TEXT,
  publisher TEXT,
  format TEXT NOT NULL,
  selectedPlatforms TEXT NOT NULL,
  tags TEXT NOT NULL,
  suggestedTags TEXT NOT NULL DEFAULT '[]',
  selectedSuggestedTags TEXT NOT NULL DEFAULT '[]',
  customTags TEXT NOT NULL DEFAULT '[]',
  selectedCustomTags TEXT NOT NULL DEFAULT '[]',
  notes TEXT NOT NULL DEFAULT '',
  playtimeEntries TEXT NOT NULL DEFAULT '[]',
  achievementStates TEXT NOT NULL DEFAULT '[]',
  requirements TEXT NOT NULL DEFAULT '[]',
  addedAt TEXT NOT NULL,
  isManuallyCompleted INTEGER NOT NULL DEFAULT 0,
  startedPlayingAt TEXT,
  availablePlatforms TEXT NOT NULL DEFAULT '[]',
  syncId TEXT NOT NULL UNIQUE,
  updatedAt INTEGER NOT NULL DEFAULT 0,
  deletedAt INTEGER
)
''');
    await db.execute('''
CREATE TABLE game_achievements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  apiId INTEGER NOT NULL,
  rawgId INTEGER NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  imageUrl TEXT,
  percent REAL,
  UNIQUE(apiId, rawgId)
)
''');
    await db.execute('''
CREATE TABLE app_achievements (
  id TEXT PRIMARY KEY,
  unlockedAt TEXT,
  seenAt TEXT,
  updatedAt INTEGER NOT NULL DEFAULT 0,
  deletedAt INTEGER
)
''');
    await db.execute('''
CREATE TABLE event_counters (
  key TEXT PRIMARY KEY,
  value INTEGER NOT NULL DEFAULT 0,
  updatedAt INTEGER NOT NULL DEFAULT 0
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE collection ADD COLUMN publisher TEXT');
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE collection ADD COLUMN suggestedTags TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE collection ADD COLUMN selectedSuggestedTags TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE collection ADD COLUMN customTags TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE collection ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE collection ADD COLUMN playtimeEntries TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE collection ADD COLUMN requirements TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        'ALTER TABLE collection ADD COLUMN isManuallyCompleted INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE collection ADD COLUMN selectedCustomTags TEXT NOT NULL DEFAULT '[]'",
      );
    }

    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE collection ADD COLUMN achievementStates TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute('''
CREATE TABLE IF NOT EXISTS game_achievements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  apiId INTEGER NOT NULL,
  rawgId INTEGER NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  imageUrl TEXT,
  percent REAL,
  UNIQUE(apiId, rawgId)
)
''');
    }

    if (oldVersion < 6) {
      try {
        await db.execute(
          "ALTER TABLE collection ADD COLUMN requirements TEXT NOT NULL DEFAULT '[]'",
        );
      } catch (_) {
        // Kolom kan al bestaan vanuit een eerdere migratie.
      }
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE collection ADD COLUMN customCoverPath TEXT',
      );
      await db.execute(
        'ALTER TABLE collection ADD COLUMN startedPlayingAt TEXT',
      );
    }
    if (oldVersion < 8) {
      await db.execute(
        "ALTER TABLE collection ADD COLUMN availablePlatforms TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (oldVersion < 9) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS app_achievements (
  id TEXT PRIMARY KEY,
  unlockedAt TEXT,
  seenAt TEXT
)
''');
      await db.execute('''
CREATE TABLE IF NOT EXISTS event_counters (
  key TEXT PRIMARY KEY,
  value INTEGER NOT NULL DEFAULT 0
)
''');
    }
    if (oldVersion < 10) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
    }
    if (oldVersion < 11) {
      // Voeg synchronisatiekolommen toe en vul bestaande rijen bij.
      await db.execute('ALTER TABLE collection ADD COLUMN syncId TEXT');
      await db.execute(
        'ALTER TABLE collection ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE collection ADD COLUMN deletedAt INTEGER');
      await db.execute(
        'ALTER TABLE app_achievements ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE app_achievements ADD COLUMN deletedAt INTEGER',
      );
      await db.execute(
        'ALTER TABLE event_counters ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0',
      );
      // Vul syncId en beginwaarde van updatedAt in voor bestaande rijen.
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = await db.query('collection', columns: ['id']);
      for (final row in rows) {
        await db.update(
          'collection',
          {'syncId': generateSyncId(), 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      await db.execute('UPDATE app_achievements SET updatedAt = ?', [now]);
      await db.execute('UPDATE event_counters SET updatedAt = ?', [now]);
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_collection_syncId ON collection(syncId)',
      );
    }
  }

  Future<int> insertCollectionItem(CollectionItem item) async {
    final db = await instance.database;

    final map = item.toMap();
    // Wijs een nieuw syncId toe en stel de initiële updatedAt in.
    map['syncId'] = generateSyncId();
    map['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    map['deletedAt'] = null;
    final id = await db.insert("collection", map);
    notifyListeners();
    return id;
  }

  Future<int> updateCollectionItem(CollectionItem item) async {
    final db = await instance.database;

    final map = item.toMap();
    // Behoud het bestaande syncId; verhoog updatedAt; zorg dat deletedAt leeg is.
    map.remove('syncId');
    map['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    map['deletedAt'] = null;
    final result = await db.update(
      "collection",
      map,
      where: "id = ?",
      whereArgs: [item.id],
    );
    notifyListeners();
    return result;
  }

  Future<List<CollectionItem>> getCollectionItems() async {
    final db = await instance.database;
    final result = await db.query(
      'collection',
      where: 'deletedAt IS NULL',
      orderBy: 'addedAt DESC',
    );
    return result.map((json) => CollectionItem.fromMap(json)).toList();
  }

  Future<CollectionItem?> getCollectionItemById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'collection',
      where: 'id = ? AND deletedAt IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) {
      return null;
    }
    return CollectionItem.fromMap(result.first);
  }

  Future<void> deleteCollectionItem(int id) async {
    final db = await instance.database;
    final rows = await db.query(
      'collection',
      columns: ['apiId'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    // Zachte verwijdering: stel deletedAt en updatedAt in zodat de wijziging gesynchroniseerd wordt.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'collection',
      {'deletedAt': now, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      final apiId = rows.first['apiId'] as int;
      final remaining = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM collection WHERE apiId = ? AND deletedAt IS NULL',
        [apiId],
      );
      final count = remaining.first['total'] as int? ?? 0;
      if (count == 0) {
        await db.delete(
          'game_achievements',
          where: 'apiId = ?',
          whereArgs: [apiId],
        );
      }
    }
    notifyListeners();
  }

  Future<void> deleteCollectionItemsByApiId(int apiId) async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'collection',
      {'deletedAt': now, 'updatedAt': now},
      where: 'apiId = ? AND deletedAt IS NULL',
      whereArgs: [apiId],
    );
    await db.delete(
      'game_achievements',
      where: 'apiId = ?',
      whereArgs: [apiId],
    );
    notifyListeners();
  }

  Future<List<CollectionItem>> getCollectionItemsByApiId(int apiId) async {
    final db = await instance.database;
    final result = await db.query(
      'collection',
      where: 'apiId = ? AND deletedAt IS NULL',
      whereArgs: [apiId],
    );
    return result.map((json) => CollectionItem.fromMap(json)).toList();
  }

  Future<int> countCollectionItemsByApiId(int apiId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM collection WHERE apiId = ? AND deletedAt IS NULL',
      [apiId],
    );
    final total = result.first['total'] as int?;
    return total ?? 0;
  }

  Future<bool> isGameInCollection(int apiId) async {
    final db = await instance.database;
    final result = await db.query(
      'collection',
      where: 'apiId = ? AND deletedAt IS NULL',
      whereArgs: [apiId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // ── Achievement DAO ──────────────────────────────────────────────────────

  Future<bool> hasAchievementsForGame(int apiId) async {
    final db = await instance.database;
    final result = await db.query(
      'game_achievements',
      where: 'apiId = ?',
      whereArgs: [apiId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Interne helper: schrijft achievements naar de database met het opgegeven [algorithm].
  Future<void> _writeAchievementsForGame(
    int apiId,
    List<RawgAchievement> achievements,
    ConflictAlgorithm algorithm,
  ) async {
    if (achievements.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final a in achievements) {
      batch.insert('game_achievements', {
        'apiId': apiId,
        'rawgId': a.id,
        'name': a.name,
        'description': a.description,
        'imageUrl': a.imageUrl,
        'percent': a.percent,
      }, conflictAlgorithm: algorithm);
    }
    await batch.commit(noResult: true);
    notifyListeners();
  }

  /// Voegt achievements in; slaat duplicaten over (ignore bij conflict).
  Future<void> insertAchievementsForGame(
    int apiId,
    List<RawgAchievement> achievements,
  ) => _writeAchievementsForGame(apiId, achievements, ConflictAlgorithm.ignore);

  /// Voegt achievements in of overschrijft bestaande (replace bij conflict).
  Future<void> upsertAchievementsForGame(
    int apiId,
    List<RawgAchievement> achievements,
  ) =>
      _writeAchievementsForGame(apiId, achievements, ConflictAlgorithm.replace);

  Future<List<Map<String, dynamic>>> getRawAchievementsForGame(
    int apiId,
  ) async {
    final db = await instance.database;
    return db.query(
      'game_achievements',
      where: 'apiId = ?',
      whereArgs: [apiId],
      orderBy: 'name ASC',
    );
  }

  Future<List<GameAchievementWithState>> getAchievementsWithStates(
    int apiId,
    List<AchievementState> states,
  ) async {
    final db = await instance.database;
    final rows = await db.query(
      'game_achievements',
      where: 'apiId = ?',
      whereArgs: [apiId],
      orderBy: 'name ASC',
    );
    final stateMap = {for (final s in states) s.rawgId: s};
    return rows
        .map((row) {
          final rawgId = row['rawgId'] as int;
          final state = stateMap[rawgId];
          return GameAchievementWithState(
            rawgId: rawgId,
            name: row['name'] as String? ?? '',
            description: row['description'] as String? ?? '',
            imageUrl: row['imageUrl'] as String?,
            percent: (row['percent'] as num?)?.toDouble(),
            isCompleted: state?.isCompleted ?? false,
            isEnabled: state?.isEnabled ?? true,
          );
        })
        .toList(growable: false);
  }

  // ── App-level Achievements DAO ────────────────────────────────────────────

  /// Geeft een map terug van achievement-id naar {unlockedAt, seenAt}
  /// voor alle rijen in de app_achievements-tabel.
  Future<Map<String, Map<String, String?>>> getAppAchievements() async {
    final db = await instance.database;
    final rows = await db.query('app_achievements');
    return {
      for (final row in rows)
        row['id'] as String: {
          'unlockedAt': row['unlockedAt'] as String?,
          'seenAt': row['seenAt'] as String?,
        },
    };
  }

  /// Markeert een app-achievement als ontgrendeld (no-op als al ontgrendeld).
  Future<void> unlockAppAchievement(String id) async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('app_achievements', {
      'id': id,
      'unlockedAt': DateTime.now().toIso8601String(),
      'seenAt': null,
      'updatedAt': now,
      'deletedAt': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    notifyListeners();
  }

  /// Markeert een ontgrendeld achievement als "gezien" door de gebruiker.
  Future<void> markAppAchievementSeen(String id) async {
    final db = await instance.database;
    await db.update(
      'app_achievements',
      {
        'seenAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND seenAt IS NULL',
      whereArgs: [id],
    );
  }

  /// Geeft de huidige waarde van een gebeurtenisteller terug (0 als niet aanwezig).
  Future<int> getEventCounter(String key) async {
    final db = await instance.database;
    final rows = await db.query(
      'event_counters',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['value'] as int? ?? 0;
  }

  /// Verhoogt een gebeurtenisteller met 1; maakt hem aan met waarde 1 als hij nog niet bestaat.
  Future<void> incrementEventCounter(String key) async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.execute(
      'INSERT INTO event_counters (key, value, updatedAt) VALUES (?, 1, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = value + 1, updatedAt = excluded.updatedAt',
      [key, now],
    );
    notifyListeners();
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await instance.database;
    await db.execute(
      'INSERT INTO settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  Future<bool> getNotificationsEnabled() async {
    final val = await getSetting('notificationsEnabled');
    // Standaard ingeschakeld als nog niet ingesteld.
    return val == null || val == '1';
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await setSetting('notificationsEnabled', enabled ? '1' : '0');
    await setSetting(
      'notificationsEnabledUpdatedAt',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    notifyListeners();
  }

  /// Tijdstip waarop de notificatievoorkeur lokaal het laatste is gewijzigd
  /// (epoch ms). 0 als nooit expliciet ingesteld.
  Future<int> getNotificationsUpdatedAt() async {
    final raw = await getSetting('notificationsEnabledUpdatedAt');
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// Past een meldingenvoorkeur toe die vanuit synchronisatie binnenkomt. De aanroeper
  /// is verantwoordelijk voor het opnieuw plannen of annuleren van meldingen.
  Future<void> applyRemoteNotificationsPreference({
    required bool enabled,
    required int updatedAt,
  }) async {
    await setSetting('notificationsEnabled', enabled ? '1' : '0');
    await setSetting('notificationsEnabledUpdatedAt', updatedAt.toString());
    notifyListeners();
  }

  // ── Sync-helpers ──────────────────────────────────────────────────────────
  // Gebruikt door SyncService. Stelt ruwe rijen bloot inclusief syncmetadata
  // (syncId, updatedAt, deletedAt) zodat Firestore-logica buiten de modellaag
  // kan worden gehouden.

  /// Alle collectierijen die strikt na [sinceMs] (epoch ms) zijn bijgewerkt,
  /// inclusief zacht-verwijderde tombstones. Elke map bevat alle DB-kolommen.
  Future<List<Map<String, dynamic>>> getCollectionRowsChangedSince(
    int sinceMs,
  ) async {
    final db = await instance.database;
    return db.query(
      'collection',
      where: 'updatedAt > ?',
      whereArgs: [sinceMs],
      orderBy: 'updatedAt ASC',
    );
  }

  Future<int> countLocalChangesSince(int sinceMs) async {
    final db = await instance.database;
    final cRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM collection WHERE updatedAt > ?',
      [sinceMs],
    );
    final aRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM app_achievements WHERE updatedAt > ?',
      [sinceMs],
    );
    final eRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM event_counters WHERE updatedAt > ?',
      [sinceMs],
    );
    int read(List<Map<String, Object?>> rows) => (rows.first['c'] as int?) ?? 0;
    return read(cRows) + read(aRows) + read(eRows);
  }

  Future<List<Map<String, dynamic>>> getAppAchievementRowsChangedSince(
    int sinceMs,
  ) async {
    final db = await instance.database;
    return db.query(
      'app_achievements',
      where: 'updatedAt > ?',
      whereArgs: [sinceMs],
    );
  }

  Future<List<Map<String, dynamic>>> getEventCounterRowsChangedSince(
    int sinceMs,
  ) async {
    final db = await instance.database;
    return db.query(
      'event_counters',
      where: 'updatedAt > ?',
      whereArgs: [sinceMs],
    );
  }

  /// Voegt een collectierij uit de cloud in of werkt deze bij, op basis van [syncId].
  /// Slaat de schrijfactie over als de lokale rij een nieuwere [updatedAt] heeft.
  /// Respecteert tombstones (deletedAt != null).
  Future<void> applyRemoteCollectionRow(Map<String, dynamic> row) async {
    final syncId = row['syncId'] as String?;
    if (syncId == null) return;
    final db = await instance.database;
    final existing = await db.query(
      'collection',
      where: 'syncId = ?',
      whereArgs: [syncId],
      limit: 1,
    );
    final remoteUpdated = (row['updatedAt'] as num?)?.toInt() ?? 0;
    if (existing.isNotEmpty) {
      final localUpdated = (existing.first['updatedAt'] as num?)?.toInt() ?? 0;
      if (localUpdated >= remoteUpdated) return;
      final patch = Map<String, dynamic>.from(row)..remove('id');
      await db.update(
        'collection',
        patch,
        where: 'syncId = ?',
        whereArgs: [syncId],
      );
    } else {
      final insert = Map<String, dynamic>.from(row)..remove('id');
      await db.insert(
        'collection',
        insert,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    notifyListeners();
  }

  Future<void> applyRemoteAppAchievementRow(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;
    final db = await instance.database;
    final existing = await db.query(
      'app_achievements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final remoteUpdated = (row['updatedAt'] as num?)?.toInt() ?? 0;
    if (existing.isNotEmpty) {
      final localUpdated = (existing.first['updatedAt'] as num?)?.toInt() ?? 0;
      if (localUpdated >= remoteUpdated) return;
      await db.update(
        'app_achievements',
        row,
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.insert(
        'app_achievements',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    notifyListeners();
  }

  Future<void> applyRemoteEventCounterRow(Map<String, dynamic> row) async {
    final key = row['key'] as String?;
    if (key == null) return;
    final db = await instance.database;
    final existing = await db.query(
      'event_counters',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    final remoteUpdated = (row['updatedAt'] as num?)?.toInt() ?? 0;
    if (existing.isNotEmpty) {
      final localUpdated = (existing.first['updatedAt'] as num?)?.toInt() ?? 0;
      if (localUpdated >= remoteUpdated) return;
      // Tellers: neem de hoogste waarde voor veiligheid over meerdere toestellen.
      final remoteVal = (row['value'] as num?)?.toInt() ?? 0;
      final localVal = (existing.first['value'] as num?)?.toInt() ?? 0;
      await db.update(
        'event_counters',
        {
          'value': remoteVal > localVal ? remoteVal : localVal,
          'updatedAt': remoteUpdated,
        },
        where: 'key = ?',
        whereArgs: [key],
      );
    } else {
      await db.insert(
        'event_counters',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    notifyListeners();
  }

  /// Wist alle lokale syncbare gebruikersdata. Gebruikt bij "cloud overschrijft lokaal".
  Future<void> clearAllSyncableLocalData() async {
    final db = await instance.database;
    await db.delete('collection');
    await db.delete('app_achievements');
    await db.delete('event_counters');
    await db.delete('game_achievements');
    // Clear synced preferences so the cloud values become the source of truth.
    await db.delete(
      'settings',
      where: 'key IN (?, ?)',
      whereArgs: ['notificationsEnabled', 'notificationsEnabledUpdatedAt'],
    );
    notifyListeners();
  }

  /// Markeert elke syncbare rij als gewijzigd (updatedAt = nu) en wist het
  /// lokale syncwatermerk. Gebruikt bij "lokaal overschrijft cloud".
  Future<void> markAllSyncableRowsDirty() async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.execute('UPDATE collection SET updatedAt = ?', [now]);
    await db.execute('UPDATE app_achievements SET updatedAt = ?', [now]);
    await db.execute('UPDATE event_counters SET updatedAt = ?', [now]);
    // Verhoog ook de notificatietijdstempel zodat die ook gepusht wordt.
    await setSetting('notificationsEnabledUpdatedAt', now.toString());
  }
}
