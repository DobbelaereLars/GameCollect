import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/collection/domain/collection_item.dart';
import '../../features/discover/domain/rawg_game.dart';

import "package:flutter/foundation.dart";

class DatabaseHelper extends ChangeNotifier {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

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
      version: 8,
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
  availablePlatforms TEXT NOT NULL DEFAULT '[]'
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
        // Column may already exist from an earlier migration
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
  }

  Future<int> insertCollectionItem(CollectionItem item) async {
    final db = await instance.database;

    final id = await db.insert("collection", item.toMap());
    notifyListeners();
    return id;
  }

  Future<int> updateCollectionItem(CollectionItem item) async {
    final db = await instance.database;

    final result = await db.update(
      "collection",
      item.toMap(),
      where: "id = ?",
      whereArgs: [item.id],
    );
    notifyListeners();
    return result;
  }

  Future<List<CollectionItem>> getCollectionItems() async {
    final db = await instance.database;
    final result = await db.query('collection', orderBy: 'addedAt DESC');
    return result.map((json) => CollectionItem.fromMap(json)).toList();
  }

  Future<CollectionItem?> getCollectionItemById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'collection',
      where: 'id = ?',
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
    // Look up the apiId before deleting so we can clean up achievements if needed.
    final rows = await db.query(
      'collection',
      columns: ['apiId'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.delete('collection', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final apiId = rows.first['apiId'] as int;
      final remaining = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM collection WHERE apiId = ?',
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
    await db.delete('collection', where: 'apiId = ?', whereArgs: [apiId]);
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
      where: 'apiId = ?',
      whereArgs: [apiId],
    );
    return result.map((json) => CollectionItem.fromMap(json)).toList();
  }

  Future<int> countCollectionItemsByApiId(int apiId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM collection WHERE apiId = ?',
      [apiId],
    );
    final total = result.first['total'] as int?;
    return total ?? 0;
  }

  Future<bool> isGameInCollection(int apiId) async {
    final db = await instance.database;
    final result = await db.query(
      'collection',
      where: 'apiId = ?',
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

  Future<void> insertAchievementsForGame(
    int apiId,
    List<RawgAchievement> achievements,
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
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertAchievementsForGame(
    int apiId,
    List<RawgAchievement> achievements,
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
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

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
}
