import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../model/app_log.dart';

/// Stores app logs on the device in their own database file, separate from the
/// work database (sahayi_android.db), so logging can never affect scan data.
class LogDB {
  static const String dbName = "sahayi_logs.db";
  static const String table = "AppLog";
  static const String settingsTable = "Settings";

  /// How long logs are kept on the device, and the hard cap on row count.
  static const Duration keepFor = Duration(days: 14);
  static const int maxRows = 50000;

  final Database _db;
  LogDB._(this._db);

  /// [factory] and [dbPath] can be overridden in tests.
  static Future<LogDB> open({DatabaseFactory? factory, String? dbPath}) async {
    final f = factory ?? databaseFactory;
    final p = dbPath ?? path.join(await getDatabasesPath(), dbName);
    final db = await f.openDatabase(
      p,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createSettings(db);
        },
        onCreate: (db, version) async {
          await _createSettings(db);
          await db.execute("""CREATE TABLE $table(
            LocalID INTEGER PRIMARY KEY AUTOINCREMENT,
            ClientTime TEXT NOT NULL,
            Level TEXT NOT NULL,
            UserID TEXT NULL,
            Company TEXT NULL,
            DeviceID TEXT NULL,
            AppVersion TEXT NULL,
            Screen TEXT NULL,
            Action TEXT NOT NULL,
            DocNum TEXT NULL,
            DocType TEXT NULL,
            Message TEXT NOT NULL,
            Details TEXT NULL,
            Uploaded INTEGER NOT NULL DEFAULT 0)""");
          await db.execute(
              "CREATE INDEX IX_${table}_ClientTime ON $table(ClientTime)");
          await db.execute(
              "CREATE INDEX IX_${table}_Uploaded ON $table(Uploaded)");
        },
      ),
    );
    return LogDB._(db);
  }

  // Small key/value store (e.g. the scrambled admin PIN).
  static Future<void> _createSettings(Database db) => db.execute(
      "CREATE TABLE IF NOT EXISTS $settingsTable(Key TEXT PRIMARY KEY, Value TEXT NULL)");

  Future<String?> getSetting(String key) async {
    final rows = await _db.query(settingsTable,
        columns: ['Value'], where: 'Key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['Value'] as String?;
  }

  Future<void> setSetting(String key, String? value) => _db.insert(
      settingsTable, {'Key': key, 'Value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> insert(AppLog log) => _db.insert(table, log.toDB());

  /// Newest first.
  Future<List<AppLog>> recent({int limit = 100}) async {
    final rows = await _db.query(table, orderBy: 'LocalID DESC', limit: limit);
    return rows.map(AppLog.fromDB).toList();
  }

  /// Oldest first, for uploading in order.
  Future<List<AppLog>> notUploaded({int limit = 500}) async {
    final rows = await _db.query(table,
        where: 'Uploaded = 0', orderBy: 'LocalID ASC', limit: limit);
    return rows.map(AppLog.fromDB).toList();
  }

  Future<int> markUploaded(List<int> localIds) async {
    if (localIds.isEmpty) return 0;
    final marks = List.filled(localIds.length, '?').join(',');
    return _db.rawUpdate(
        'UPDATE $table SET Uploaded = 1 WHERE LocalID IN ($marks)', localIds);
  }

  /// Server refused these entries (HTTP 400): never retry them. Uploaded = 2.
  Future<int> markRejected(List<int> localIds) async {
    if (localIds.isEmpty) return 0;
    final marks = List.filled(localIds.length, '?').join(',');
    return _db.rawUpdate(
        'UPDATE $table SET Uploaded = 2 WHERE LocalID IN ($marks)', localIds);
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM $table')) ??
      0;

  /// Removes logs older than [keepFor], then the oldest rows above [maxRows].
  Future<int> purge({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(keepFor).toIso8601String();
    var removed =
        await _db.delete(table, where: 'ClientTime < ?', whereArgs: [cutoff]);
    removed += await _db.rawDelete(
        'DELETE FROM $table WHERE LocalID NOT IN '
        '(SELECT LocalID FROM $table ORDER BY LocalID DESC LIMIT ?)',
        [maxRows]);
    return removed;
  }

  Future<void> close() => _db.close();
}
