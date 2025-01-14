import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class DBHelper {
  // Database instance
  static Database? _db;

  //database name
  static const String dbName = "sahayi_android.db";

  // tables
  static const String docMaster = "DocMaster";
  static const String docDetail = "DocDetails";
  static const String lastInvoices = "LastInvoices";

  // columns in tables

  //InvMaster
  static const String companyDocMaster = "Company";
  static const String docNumDocMaster = "DocNum";
  static const String docDateDocMaster = "DocDate";
  static const String custNumDocMaster = "CustNum";
  static const String custNameDocMaster = "CustName";
  static const String statDocMaster = "Stat";
  static const String userIDDocMaster = "UserID";
  static const String scanTimeDocMaster = "ScanTime";

  // Part
  static const String companyDocDetail = "Company";
  static const String docNumDocDetail = "DocNum";
  static const String slNoDocDetail = "SlNo";
  static const String barcodeDocDetail = "Barcode";
  static const String partNumDocDetail = "PartNum";
  static const String partNameDocDetail = "PartName";
  static const String brandDocDetail = "Brand";
  static const String shipQtyDocDetail = "ShipQty";
  static const String checkQtyDocDetail = "CheckQty";
  static const String statDocDetail = "Stat";

  // Last Invoices
  static const String userIDLastInvoices = "UserID";
  static const String docNumLastInvoices = "DocNum";
  static const String statLastInvoices = "Stat";

  // get db
  static Future<Database> get db async {
    if (_db != null) {
      return _db!;
    }
    _db = await openDb();
    return _db!;
  }

  static Future<String> get _localPath async {
    // final directory = await getApplicationDocumentsDirectory();
    // return directory.path;
    // To get the external path from device of download folder
    final String directory = await getExternalDocumentPath();
    return directory;
  }

  static Future<String> getExternalDocumentPath() async {
    Directory directory = Directory("");
    if (Platform.isAndroid) {
      // Redirects it to download folder in android
      directory = Directory("/storage/emulated/0/sahayi/database/");
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    final exPath = directory.path;
    log("Saved Path: $exPath");
    await Directory(exPath).create(recursive: true);
    return exPath;
  }

  //open database
  static Future<Database> openDb() async {
    // this saves the db to accessible location
    final databasePath = await _localPath;
    // this save the db to application location
    // final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, dbName);
    log(dbPath);
    return openDatabase(
      dbPath,
      //if app is building from scratch in dev, change the version to 1, then increment the number while uncommenting respective code in onUpgrade
      // make sure all tables have altered table code before production.
      version: 1,
      onCreate: (db, version) async {
        await createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        log("Upgrade old Version $oldVersion");
        log("Upgrade new Version $newVersion");
        if (oldVersion < newVersion) {
          // use this to create new tables, alter table in dev only upgrade the version to run this
          // make sure all altered table codes are integreted to create table code before production.
        }
      },
    );
  }

  // on create
  // if app is creating from scratch make sure to update this function to add altered table code
  static Future<void> createTables(Database database) async {
    // InvMaster
    await database.execute("""CREATE TABLE $docMaster(
      $companyDocMaster TEXT NOT NULL,
      $docNumDocMaster TEXT NOT NULL,
      $docDateDocMaster TEXT NOT NULL,
      $custNumDocMaster TEXT NOT NULL,
      $custNameDocMaster TEXT NOT NULL,
      $statDocMaster TEXT NOT NULL,
      $userIDDocMaster TEXT NOT NULL,
      $scanTimeDocMaster TEXT NOT NULL, PRIMARY KEY ($companyDocMaster,$docNumDocMaster))""");

    // InvDetail table
    await database.execute("""CREATE TABLE $docDetail(
      $companyDocDetail TEXT NOT NULL,
      $docNumDocDetail TEXT NOT NULL,
      $slNoDocDetail INTEGER NOT NULL,
      $barcodeDocDetail TEXT NOT NULL,
      $partNumDocDetail TEXT NOT NULL,
      $partNameDocDetail TEXT NOT NULL,
      $brandDocDetail TEXT NOT NULL,
      $shipQtyDocDetail INTEGER NOT NULL,
      $checkQtyDocDetail INTEGER NOT NULL,
      $statDocDetail TEXT NOT NULL, PRIMARY KEY ($companyDocDetail,$docNumDocDetail,$slNoDocDetail))""");

    // LastInvoice table
    await database.execute("""CREATE TABLE $lastInvoices(
      $userIDLastInvoices TEXT NOT NULL,
      $docNumLastInvoices TEXT NOT NULL,
      $statLastInvoices TEXT NOT NULL, PRIMARY KEY ($userIDLastInvoices,$docNumLastInvoices))""");
  }

  // insert into table single function, takes table name and list of map data
  static Future<void> addItemsToTable({
    required String tableName,
    required List<dynamic> item,
  }) async {
    final database = await db;
    for (int i = 0; i < item.length; i++) {
      await database.insert(tableName, item[i],
          conflictAlgorithm: ConflictAlgorithm.replace);
      log("added to $tableName ${item[i]}");
    }
  }

  static Future<List<Object?>> bulkInsert({
    required String tableName,
    required List<Map<String, dynamic>> items,
  }) async {
    Database database = await db;
    var result = [];
    // Use a transaction for bulk insert
    await database.transaction((txn) async {
      Batch batch = txn.batch();
      try {
        for (var record in items) {
          batch.insert(
            tableName,
            record,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        result = await batch.commit(
          noResult: false,
        );
      } catch (e) {
        // Handle different error scenarios
        log("Error during bulk insert: $e");
        if (e is DatabaseException) {
          // Handle database-specific exceptions
          if (e.isUniqueConstraintError()) {
            log("Unique constraint violation. Duplicate entry found.");
            result = [];
          } else if (e.isSyntaxError()) {
            log("SQL syntax error.");
            result = [];
          }
          // Add more specific error handling as needed
        } else {
          // Handle other types of exceptions
          log("Unexpected error: $e");
          result = [];
        }
      }
    });
    return result;
  }

  // get items form a table and returns a list of map
  static Future<List<Map<String, dynamic>>> getAllItems(
      {required String tableName}) async {
    final database = await db;
    var result = await database.query(tableName);
    // log("$tableName:$result");
    return result;
  }

  static Future<int> getTableLength({required String tableName}) async {
    final database = await db;
    final List<Map<String, dynamic>> result =
        await database.rawQuery('SELECT COUNT(*) as count FROM $tableName');

    if (result.isNotEmpty) {
      log("$tableName length is ${result.first['count']}");
      return result.first['count'] as int;
    } else {
      log("0");
      return 0;
    }
  }

  static Future<int> getSumofColumn(
      {required String tableName, required String columnName}) async {
    final database = await db;
    final List<Map<String, dynamic>> result = await database
        .rawQuery('SELECT SUM($columnName) as count FROM $tableName');
    // log(result.toString());

    if (result.isNotEmpty && result.first['count'] != null) {
      log("$tableName $columnName sum is ${result.first['count']}");
      return result.first['count'] as int;
    } else {
      // log("0");
      return 0;
    }
  }

  // get a single item from a table based on condition, returns a list of map
  static Future<List<Map<String, dynamic>>> getItems(
      {required String tableName,
      required String columnName,
      required String condition}) async {
    final database = await db;
    return database.query(
      tableName,
      where: "$columnName = ?",
      whereArgs: [condition],
    );
  }

  // sqflite query
  static Future<List<Map<String, dynamic>>> getItemsByQuery(String tableName,
      {String? where, List<Object?>? whereArgs}) async {
    final database = await db;
    return database.query(
      tableName,
      where: where, // should be like string1 = ? and string2 = ?
      whereArgs: whereArgs, // should be like [condition1,condition2]
    );
  }

  // sqflite get by raw query
  static Future<List<Map<String, dynamic>>> getItemsByRawQuery(
      String query) async {
    final database = await db;
    return database.rawQuery(query);
  }

  // update a single item in a table
  static Future<int> updateItem({
    required String tableName,
    required Map<String, dynamic> data,
    required String keyColumn,
    required dynamic condition,
  }) async {
    // log("Table to be updated: $tableName");
    // log("Data to be updated: $data");
    final database = await db;
    final result = await database.update(
      tableName,
      data,
      where: "$keyColumn = ?",
      whereArgs: [condition],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // log(result.toString());
    //  var updatedTable = await database.query(tableName);
    // log("Updated $tableName = $updatedTable");
    return result;
  }

  Future<int> insertOrUpdateWithLimit({
    required String tableName,
    required Map<String, dynamic> data,
    required String keyColumn,
    required dynamic condition,
    int limit = 10, // Default limit is 10, but can be changed dynamically
  }) async {
    final database = await db;

    try {
      return await database.transaction((txn) async {
        // Check if the item already exists
        final existingItem = await txn.query(
          tableName,
          where: "$keyColumn = ?",
          whereArgs: [condition],
        );

        if (existingItem.isNotEmpty) {
          // If item exists, update it
          final result = await txn.update(
            tableName,
            data,
            where: "$keyColumn = ?",
            whereArgs: [condition],
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          log("Item updated successfully.");
          return result;
        } else {
          // If item doesn't exist, insert it
          await txn.insert(
            tableName,
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Check if the table exceeds the limit
          final countResult =
              await txn.rawQuery('SELECT COUNT(*) as count FROM $tableName');
          final int currentCount = Sqflite.firstIntValue(countResult) ?? 0;

          // If the limit is exceeded, delete the oldest item (FIFO)
          if (currentCount > limit) {
            await txn.rawDelete('''
            DELETE FROM $tableName
            WHERE rowid IN (
              SELECT rowid FROM $tableName 
              ORDER BY rowid ASC 
              LIMIT 1
            )
          ''');
            log("Oldest item removed due to exceeding the limit of $limit.");
          }

          log("Item inserted successfully.");
          return 1; // Insert success
        }
      });
    } catch (e) {
      log("Error in insertOrUpdateWithLimit: $e");
      return 0; // Failure
    }
  }

  // update a single item in a table
  static Future<int> updateItemWith2Conditions(
    String tableName,
    Map<String, dynamic> data,
    String keyColumn1,
    String keyColumn2,
    String condition1,
    String condition2,
  ) async {
    final database = await db;
    final result = await database.update(
      tableName,
      data,
      where: "$keyColumn1 = ? and $keyColumn2 = ?",
      whereArgs: [condition1, condition2],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    log(result.toString());
    return result;
  }

  // insert new item to table
  static Future<int> insertItem({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    // log("Table to be inserted: $tableName");
    // log("Data to be inserted: $data");
    final database = await db;
    final result = await database.insert(
      tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // log(result.toString());
    //var updatedTable = await database.query(tableName);
    // log("inserted into $tableName = $updatedTable");
    return result;
  }

  // db raw insert

  static Future<int> updateItemTest({
    required String tableName,
    required Map<String, dynamic> data,
    required String keyColumn1,
    required String keyColumn2,
    required String keyColumn3,
    required String keyColumn4,
    required String condition1,
    required String condition2,
    required String condition3,
    required String condition4,
  }) async {
    final database = await db;
    final result = await database.update(
      tableName,
      data,
      where:
          "$keyColumn1 = ? and $keyColumn2 = ? and $keyColumn3 = ? and $keyColumn4 = ?",
      whereArgs: [condition1, condition2, condition3, condition4],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    //await database.query(tableName);
    return result;
  }

  // delete a single item from a table based on a condition
  static Future<void> deleteItem(
      String tableName, String columnName, String condition) async {
    final database = await db;
    try {
      await database
          .delete(tableName, where: "$columnName = ?", whereArgs: [condition]);
    } catch (e) {
      log("Something went wrong with error: $e");
    }
  }

  // delete all items from a table
  static Future<int> deleteAllItem({required String tableName}) async {
    final database = await db;
    try {
      var rows = await database.delete(tableName);
      //   log(rows.toString());
      return rows;
    } catch (e) {
      log("Something went wrong with error: $e");
      return -1;
    }
  }

  // get the path of the database, takes the database name
  static Future<String> getPath(String databaseName) async {
    final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, databaseName);
    return dbPath;
  }

  // list all the table in sqlite master
  static Future<List<String>> listTables() async {
    final database = await db;
    var tableNames = (await database
            .query('sqlite_master', where: 'type = ?', whereArgs: ['table']))
        .map((row) => row['name'] as String)
        .toList(growable: false);
    log(tableNames.toString());
    final dbVersion = await database.getVersion();
    log("$dbVersion");
    return tableNames;
  }

  // list all columns in a given table
  static Future<List<String>> listColumnsInTable(String tableName) async {
    final database = await db;
    final columnsQuery =
        await database.rawQuery('PRAGMA table_info($tableName)');
    final columnNames =
        columnsQuery.map((column) => column['name'] as String).toList();
    log(columnNames.toString());
    return columnNames;
  }

  // execute raw query

  static Future<void> executeRawQuery(String query) async {
    final database = await db;
    await database.execute(query);
  }

  // close database
  static Future<void> closeDb() async {
    final database = await db;
    await database.close();
  }
}
