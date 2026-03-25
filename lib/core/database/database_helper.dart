import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/collection/domain/collection_item.dart';

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
      version: 2,
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
  publisher TEXT,
  format TEXT NOT NULL,
  selectedPlatforms TEXT NOT NULL,
  tags TEXT NOT NULL,
  addedAt TEXT NOT NULL
)
''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE collection ADD COLUMN publisher TEXT');
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

  Future<void> deleteCollectionItem(int id) async {
    final db = await instance.database;
    await db.delete("collection", where: "id = ?", whereArgs: [id]);
    notifyListeners();
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
}
