import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/model/app_log.dart';
import 'package:sahayi_android/service/log_uploader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late LogDB db;
  final t0 = DateTime(2026, 10, 14, 9);

  Future<void> add(String level, String action, String message,
      {int minutes = 0, String? docNum, String? userId, int uploadState = 0}) =>
      db.insert(AppLog(
        clientTime: t0.add(Duration(minutes: minutes)),
        level: level,
        action: action,
        message: message,
        docNum: docNum,
        userId: userId,
        uploadState: uploadState,
      ));

  setUp(() async {
    LogUploader.resetForTest();
    db = await LogDB.open(factory: databaseFactoryFfi, dbPath: inMemoryDatabasePath);
    await add('INFO', 'Login', 'User logged in', minutes: 0, userId: 'MX1576', uploadState: 1);
    await add('ERROR', 'HttpFailed', 'DNS FAILED', minutes: 10, uploadState: 1);
    await add('WARN', 'Popup', 'Error!: 50% off_sale', minutes: 20);
    await add('INFO', 'SyncDone', 'Downloaded 42 lines', minutes: 60 * 24, docNum: '25032700');
    await add('ERROR', 'FinalizeFailed', 'Server did not accept', minutes: 60 * 25, uploadState: 2);
  });

  tearDown(() async {
    LogUploader.resetForTest();
    await db.close();
  });

  List<String> actions(List<AppLog> logs) => logs.map((e) => e.action).toList();

  test('no filters: newest first', () async {
    expect(actions(await db.search()),
        ['FinalizeFailed', 'SyncDone', 'Popup', 'HttpFailed', 'Login']);
  });

  test('level filter (case-insensitive)', () async {
    expect(actions(await db.search(level: 'error')), ['FinalizeFailed', 'HttpFailed']);
  });

  test('text search looks in action, message, doc number and user', () async {
    expect(actions(await db.search(text: 'dns')), ['HttpFailed']);
    expect(actions(await db.search(text: '25032700')), ['SyncDone']);
    expect(actions(await db.search(text: 'MX1576')), ['Login']);
  });

  test('% and _ in the search are plain characters', () async {
    expect(actions(await db.search(text: '50%')), ['Popup']);
    expect(actions(await db.search(text: 'f_s')), ['Popup']); // "off_sale"
    expect(await db.search(text: '%%'), isEmpty);
  });

  test('date range uses device time; "to" is exclusive', () async {
    final day1 = await db.search(from: t0, to: t0.add(const Duration(days: 1)));
    expect(actions(day1), ['Popup', 'HttpFailed', 'Login']);
  });

  test('paging with beforeId', () async {
    final first = await db.search(limit: 2);
    final next = await db.search(limit: 2, beforeId: first.last.localId);
    expect(actions(first), ['FinalizeFailed', 'SyncDone']);
    expect(actions(next), ['Popup', 'HttpFailed']);
  });

  test('stats: totals, upload states and levels', () async {
    final s = await db.stats();
    expect([s.total, s.waiting, s.sent, s.rejected, s.errors, s.warnings], [5, 2, 2, 1, 2, 1]);
    expect(s.oldest, t0);
  });

  test('upload state survives a save/load round trip', () async {
    final rejected = (await db.search(text: 'Server did not accept')).single;
    expect(rejected.uploadState, 2);
    expect(rejected.uploaded, isFalse);
  });

  test('clear sent logs keeps the ones still waiting', () async {
    expect(await db.clear(onlySent: true), 3); // 2 sent + 1 rejected
    expect(actions(await db.search()), ['SyncDone', 'Popup']);
  });

  test('clear all removes everything', () async {
    expect(await db.clear(onlySent: false), 5);
    expect(await db.count(), 0);
  });

  test('"Upload now" ignores a pause and records the result', () async {
    var calls = 0;
    var answer = 404;
    LogUploader.start(
      apiBaseUrl: 'https://api.test/api/',
      db: db,
      client: () async => MockClient((_) async {
        calls++;
        return http.Response('{}', answer);
      }),
    );

    await LogUploader.uploadNow(); // 404 → paused
    expect(LogUploader.pausedUntil, isNotNull);
    expect(LogUploader.lastResult, contains('no log endpoint'));
    await LogUploader.uploadNow(); // paused: no call
    expect(calls, 1);

    answer = 200;
    expect(await LogUploader.uploadNow(force: true), 2); // the 2 waiting logs
    expect(LogUploader.pausedUntil, isNull);
    expect(LogUploader.lastSuccessAt, isNotNull);
  });
}
