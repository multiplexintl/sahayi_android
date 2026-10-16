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
    AppLogger.warn('Test', 'hello', docNum: '25032700', docType: 'I');
    await AppLogger.flush();

    final last = (await db.recent(limit: 1)).single;
    expect(last.level, 'WARN');
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
    AppLogger.error('Early1', 'before init');
    AppLogger.warn('Early2', 'before init');
    await AppLogger.init(db: db);
    await AppLogger.flush();

    final actions = (await db.recent()).reversed.map((e) => e.action).toList();
    expect(actions, ['Early1', 'Early2']);
  });

  test('long text is cut to the server column sizes', () async {
    await AppLogger.init(db: db);
    AppLogger.setUser('WAY_TOO_LONG_USER');
    AppLogger.warn('Test', 'x' * 1500);
    await AppLogger.flush();

    final last = (await db.recent(limit: 1)).single;
    expect(last.userId, 'WAY_TOO_LO');
    expect(last.message.length, lessThanOrEqualTo(1000));
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
    AppLogger.warn('A', 'a');
    AppLogger.warn('B', 'b');
    await AppLogger.flush();

    final pending = await db.notUploaded();
    expect(pending.map((e) => e.action), ['A', 'B']);
    await db.markUploaded([pending.first.localId!]);
    expect((await db.notUploaded()).map((e) => e.action), ['B']);
    expect(pending.first.toApiJson()['Source'], 'APP');
  });

  group('problems only', () {
    Future<List<AppLog>> saved() async {
      await AppLogger.flush();
      return (await db.recent()).reversed.toList();
    }

    test('INFO is not saved; WARN and ERROR are', () async {
      await AppLogger.init(db: db);
      AppLogger.info('Navigate', 'Open: /home');
      AppLogger.warn('Retry', 'Attempt 1 threw');
      AppLogger.error('FinalizeFailed', 'Upload failed');
      expect((await saved()).map((e) => e.action), ['Retry', 'FinalizeFailed']);
    });

    test('popups, input mistakes, wrong password, network chatter: not saved', () async {
      await AppLogger.init(db: db);
      for (final a in AppLogger.notStoredWarnings) {
        AppLogger.warn(a, 'something');
      }
      expect(await saved(), isEmpty);
    });

    test('an ERROR carries the recent steps that led to it', () async {
      await AppLogger.init(db: db);
      AppLogger.info('Navigate', 'Open: /scan-invoice');
      AppLogger.info('Http', 'GET .../DocumentGetRecords → 200 in 120ms');
      AppLogger.warn('Popup', 'Error!!: Wrong barcode');
      AppLogger.error('FinalizeFailed', 'POST failed: TIMEOUT');
      final e = (await saved()).single;
      expect(e.details, contains('Recent steps (oldest first):'));
      expect(e.details, contains('Navigate: Open: /scan-invoice'));
      expect(e.details, contains('Http: GET .../DocumentGetRecords → 200'));
      expect(e.details, contains('WARN Popup: Error!!: Wrong barcode'));
      expect(e.details!.indexOf('Navigate'), lessThan(e.details!.indexOf('Popup')));
    });

    test('recent steps keep only the last 20', () async {
      await AppLogger.init(db: db);
      for (var i = 1; i <= 30; i++) {
        AppLogger.info('Step', 'step $i');
      }
      AppLogger.error('X', 'boom');
      final d = (await saved()).single.details!;
      expect(d, isNot(contains('step 10\n')));
      expect(d, contains('step 11'));
      expect(d, contains('step 30'));
    });

    test('the same problem within 5 minutes: one row + one "Repeated" row', () async {
      var now = DateTime(2026, 10, 16, 12, 30);
      AppLogger.clock = () => now;
      await AppLogger.init(db: db);
      // ids and numbers differ between repeats of one layout error
      for (var i = 0; i < 12; i++) {
        AppLogger.error('FlutterError', 'RenderBox was not laid out: RenderFlex#0db4$i relayoutBoundary=up$i');
        now = now.add(const Duration(seconds: 1));
      }
      expect((await saved()).map((e) => e.action), ['FlutterError']);

      now = now.add(const Duration(minutes: 5));
      AppLogger.reportRepeats();
      final rows = await saved();
      expect(rows.map((e) => '${e.level} ${e.action}'), ['ERROR FlutterError', 'WARN Repeated']);
      expect(rows.last.message, contains('11 more time(s)'));

      // after the window a new occurrence is saved again
      AppLogger.error('FlutterError', 'RenderBox was not laid out: RenderFlex#0db99 relayoutBoundary=up1');
      expect((await saved()).length, 3);
    });

    test('a problem that did not repeat leaves no "Repeated" row', () async {
      var now = DateTime(2026, 10, 16, 12, 30);
      AppLogger.clock = () => now;
      await AppLogger.init(db: db);
      AppLogger.error('X', 'once');
      now = now.add(const Duration(minutes: 6));
      AppLogger.reportRepeats();
      expect((await saved()).map((e) => e.action), ['X']);
    });

    test('long stack traces are cut to 40 lines', () async {
      await AppLogger.init(db: db);
      final stack = StackTrace.fromString(List.generate(200, (i) => '#$i frame $i').join('\n'));
      AppLogger.error('X', 'boom', error: 'e', stack: stack);
      final d = (await saved()).single.details!;
      expect(d, contains('#39 frame 39'));
      expect(d, isNot(contains('#40 frame 40')));
      expect(d, contains('(160 more lines)'));
    });

    test('full logging saves INFO too, and switches itself off after 24 h', () async {
      var now = DateTime(2026, 10, 16, 9);
      AppLogger.clock = () => now;
      await AppLogger.init(db: db);
      await AppLogger.setFullLogging(true);
      expect(AppLogger.fullLoggingUntil, DateTime(2026, 10, 17, 9));
      AppLogger.info('Navigate', 'Open: /home');
      expect((await saved()).map((e) => e.action), ['FullLogging', 'Navigate']);

      now = now.add(const Duration(hours: 25));
      expect(AppLogger.fullLogging, isFalse);
      AppLogger.info('Navigate', 'Open: /report');
      expect((await saved()).length, 2);
    });

    test('full logging survives an app restart (saved in the log DB)', () async {
      await AppLogger.init(db: db);
      await AppLogger.setFullLogging(true);
      AppLogger.resetForTest();
      await AppLogger.init(db: db);
      expect(AppLogger.fullLogging, isTrue);
      await AppLogger.setFullLogging(false);
      AppLogger.resetForTest();
      await AppLogger.init(db: db);
      expect(AppLogger.fullLogging, isFalse);
    });

    test('first start after the update drops unsent INFO rows only (once)', () async {
      AppLog row(String level, String action) =>
          AppLog(clientTime: DateTime.now(), level: level, action: action, message: 'm');
      await db.insert(row('INFO', 'Navigate'));
      await db.insert(row('INFO', 'SentInfo'));
      await db.insert(row('ERROR', 'Crash'));
      final sent = (await db.recent()).firstWhere((e) => e.action == 'SentInfo');
      await db.markUploaded([sent.localId!]);

      await AppLogger.init(db: db);
      expect((await saved()).map((e) => e.action), ['SentInfo', 'Crash']);

      // full-logging INFO written later is not removed by the next start
      await AppLogger.setFullLogging(true);
      AppLogger.info('Later', 'kept');
      await AppLogger.flush();
      AppLogger.resetForTest();
      await AppLogger.init(db: db);
      expect((await saved()).map((e) => e.action), contains('Later'));
    });
  });

  test('logging never throws, even when the database is closed', () async {
    await AppLogger.init(db: db);
    await db.close();
    expect(() => AppLogger.info('Test', 'after close'), returnsNormally);
    await AppLogger.flush(); // write fails internally, must not throw
    db = await openTestDb(); // for tearDown
  });
}
