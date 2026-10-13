import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/model/app_log.dart';
import 'package:sahayi_android/service/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late LogDB db;

  Future<LogDB> openTestDb() =>
      LogDB.open(factory: databaseFactoryFfi, dbPath: inMemoryDatabasePath);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Sahayi',
      packageName: 'com.multiplex.sahayi_android',
      version: '1.0.15',
      buildNumber: '15',
      buildSignature: '',
    );
    AppLogger.resetForTest();
    db = await openTestDb();
  });

  tearDown(() => db.close());

  test('saves an entry with context attached', () async {
    await AppLogger.init(db: db);
    AppLogger.setUser('MX1576');
    AppLogger.setCompany('EPIC01');
    AppLogger.setScreen('/scan-invoice');
    AppLogger.info('Test', 'hello', docNum: '25032700', docType: 'I');
    await AppLogger.flush();

    final last = (await db.recent(limit: 1)).single;
    expect(last.level, 'INFO');
    expect(last.action, 'Test');
    expect(last.message, 'hello');
    expect(last.userId, 'MX1576');
    expect(last.company, 'EPIC01');
    expect(last.screen, '/scan-invoice');
    expect(last.docNum, '25032700');
    expect(last.appVersion, '1.0.15+15');
    expect(last.deviceId, matches(RegExp(r'^.+-[0-9a-f]{8}$')));
    expect(last.uploaded, isFalse);
  });

  test('error() keeps the error and stack trace in Details', () async {
    await AppLogger.init(db: db);
    try {
      throw StateError('boom');
    } catch (e, st) {
      AppLogger.error('Finalize', 'Upload failed', error: e, stack: st);
    }
    await AppLogger.flush();

    final last = (await db.recent(limit: 1)).single;
    expect(last.level, 'ERROR');
    expect(last.details, contains('Bad state: boom'));
    expect(last.details, contains('Stack:'));
  });

  test('entries logged before init are kept and saved in order', () async {
    AppLogger.info('Early1', 'before init');
    AppLogger.warn('Early2', 'before init');
    await AppLogger.init(db: db);
    await AppLogger.flush();

    final actions = (await db.recent()).reversed.map((e) => e.action).toList();
    expect(actions, ['Early1', 'Early2']);
  });

  test('long text is cut to the server column sizes', () async {
    await AppLogger.init(db: db);
    AppLogger.setUser('WAY_TOO_LONG_USER');
    AppLogger.info('Test', 'x' * 1500);
    await AppLogger.flush();

    final last = (await db.recent(limit: 1)).single;
    expect(last.userId, 'WAY_TOO_LO');
    expect(last.message.length, 1000);
  });

  test('purge removes entries older than 14 days only', () async {
    final now = DateTime(2026, 10, 13, 12);
    await db.insert(AppLog(
        clientTime: now.subtract(const Duration(days: 15)),
        level: 'INFO',
        action: 'Old',
        message: 'old'));
    await db.insert(AppLog(
        clientTime: now.subtract(const Duration(days: 13)),
        level: 'INFO',
        action: 'Recent',
        message: 'recent'));

    expect(await db.purge(now: now), 1);
    expect((await db.recent()).map((e) => e.action), ['Recent']);
  });

  test('upload bookkeeping: notUploaded / markUploaded', () async {
    await AppLogger.init(db: db);
    AppLogger.info('A', 'a');
    AppLogger.info('B', 'b');
    await AppLogger.flush();

    final pending = await db.notUploaded();
    expect(pending.map((e) => e.action), ['A', 'B']);
    await db.markUploaded([pending.first.localId!]);
    expect((await db.notUploaded()).map((e) => e.action), ['B']);
    expect(pending.first.toApiJson()['Source'], 'APP');
  });

  test('logging never throws, even when the database is closed', () async {
    await AppLogger.init(db: db);
    await db.close();
    expect(() => AppLogger.info('Test', 'after close'), returnsNormally);
    await AppLogger.flush(); // write fails internally, must not throw
    db = await openTestDb(); // for tearDown
  });
}
