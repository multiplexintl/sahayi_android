import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/service/admin_service.dart';
import 'package:sahayi_android/service/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Made-up test PIN (NOT the real one); expected value computed with Python's
// hashlib using the same recipe: salt + PIN, SHA-256 x 100,000.
const testSalt = 'testsalt';
const testPin = '1234';
const testHash = 'e4ccce0272ece73ba0892c3b4c6b3ea7d56aa0772be79842f869212313ef76b4';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late LogDB db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLogger.resetForTest();
    AdminService.resetForTest();
    db = await LogDB.open(factory: databaseFactoryFfi, dbPath: inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  Future<void> useTestPin() async {
    await db.setSetting(AdminService.pinSaltKey, testSalt);
    await db.setSetting(AdminService.pinHashKey, testHash);
  }

  test('PIN scrambling matches the recipe used on the Mac', () {
    expect(AdminService.hashPin(testSalt, testPin), testHash);
  });

  test('correct PIN opens an offline session (this device only)', () async {
    await useTestPin();
    expect(await AdminService.unlockWithPin(testPin, db: db), isNull);
    expect(AdminService.current?.mode, AdminMode.offlinePin);
    expect(AdminService.current?.canSeeAllDevices, isFalse);
  });

  test('wrong PIN is refused; 5 wrong PINs lock it', () async {
    await useTestPin();
    for (var i = 0; i < 4; i++) {
      expect(await AdminService.unlockWithPin('0000', db: db), 'Wrong PIN.');
    }
    expect(await AdminService.unlockWithPin('0000', db: db), contains('Locked'));
    // Even the right PIN is refused while locked.
    expect(await AdminService.unlockWithPin(testPin, db: db), contains('Too many'));
    expect(AdminService.current, isNull);
  });

  test('first use stores the built-in scrambled PIN in the device database', () async {
    expect(await db.getSetting(AdminService.pinHashKey), isNull);
    await AdminService.unlockWithPin('0000', db: db);
    expect(await db.getSetting(AdminService.pinHashKey), hasLength(64));
    expect(await db.getSetting(AdminService.pinSaltKey), isNotEmpty);
  });

  test('logout clears the session', () async {
    await useTestPin();
    await AdminService.unlockWithPin(testPin, db: db);
    AdminService.logout();
    expect(AdminService.current, isNull);
  });

  test('existing devices: log database version 1 upgrades and keeps its logs', () async {
    final dir = await Directory.systemTemp.createTemp('logdb');
    final path = p.join(dir.path, 'v1.db');

    // Build a version-1 database like the one on scanners today.
    final v1 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) => d.execute(
              'CREATE TABLE AppLog(LocalID INTEGER PRIMARY KEY AUTOINCREMENT, ClientTime TEXT NOT NULL, '
              'Level TEXT NOT NULL, UserID TEXT, Company TEXT, DeviceID TEXT, AppVersion TEXT, Screen TEXT, '
              'Action TEXT NOT NULL, DocNum TEXT, DocType TEXT, Message TEXT NOT NULL, Details TEXT, '
              'Uploaded INTEGER NOT NULL DEFAULT 0)'),
        ));
    await v1.insert('AppLog', {
      'ClientTime': DateTime.now().toIso8601String(),
      'Level': 'INFO',
      'Action': 'Old',
      'Message': 'from version 1',
    });
    await v1.close();

    final upgraded = await LogDB.open(factory: databaseFactoryFfi, dbPath: path);
    expect(await upgraded.count(), 1);
    await upgraded.setSetting('k', 'v');
    expect(await upgraded.getSetting('k'), 'v');
    await upgraded.close();
    await dir.delete(recursive: true);
  });
}
