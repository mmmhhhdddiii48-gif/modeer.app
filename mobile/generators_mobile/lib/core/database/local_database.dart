import 'package:sqflite/sqflite.dart';

final class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      '$root/nukhba_generators_mobile.sqlite3',
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE app_meta (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_uuid TEXT NOT NULL UNIQUE,
            operation_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            client_created_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            server_received_at TEXT,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status, id)');
      },
    );
  }

  Future<void> setMeta(String key, String? value) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'app_meta',
      {'key': key, 'value': value, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('app_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }
}
