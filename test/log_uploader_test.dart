import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/model/app_log.dart';
import 'package:sahayi_android/service/app_logger.dart';
import 'package:sahayi_android/service/log_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const api = 'https://api.test/api/';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late LogDB db;
  late List<http.Request> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Sahayi',
        packageName: 'com.multiplex.sahayi_android',
        version: '1.0.15',
        buildNumber: '15',
        buildSignature: '');
    AppLogger.resetForTest();
    LogUploader.resetForTest();
    db = await LogDB.open(factory: databaseFactoryFfi, dbPath: inMemoryDatabasePath);
    requests = [];
  });

  tearDown(() async {
    LogUploader.resetForTest();
    await db.close();
  });

  Future<void> addLogs(int n) async {
    for (var i = 0; i < n; i++) {
      await db.insert(AppLog(
          clientTime: DateTime.now(), level: 'INFO', action: 'T$i', message: 'm$i'));
    }
  }

  void startWith(Future<http.Response> Function(http.Request) server) {
    LogUploader.start(
      apiBaseUrl: api,
      db: db,
      client: () async => MockClient((req) {
        requests.add(req);
        return server(req);
      }),
    );
  }

  test('sends pending logs as a JSON array and marks them uploaded', () async {
    await addLogs(3);
    startWith((_) async => http.Response('{"Inserted":3,"Purged":0}', 200));

    expect(await LogUploader.uploadNow(), 3);
    expect(requests.single.url.toString(), '${api}v2/Logs');
    final body = jsonDecode(requests.single.body) as List;
    expect(body.length, 3);
    expect(body.first['Source'], 'APP');
    expect(await db.notUploaded(), isEmpty);
  });

  test('large backlog goes up in batches of 200', () async {
    await addLogs(450);
    startWith((_) async => http.Response('{}', 200));

    expect(await LogUploader.uploadNow(), 450);
    expect(requests.length, 3); // 200 + 200 + 50
  });

  test('offline: logs stay on the device for the next attempt', () async {
    await addLogs(2);
    startWith((_) async => throw const SocketException('Network is unreachable'));

    expect(await LogUploader.uploadNow(), 0);
    expect((await db.notUploaded()).length, 2);
  });

  test('server error 500: logs stay, retried later', () async {
    await addLogs(2);
    startWith((_) async => http.Response('oops', 500));

    expect(await LogUploader.uploadNow(), 0);
    expect((await db.notUploaded()).length, 2);
  });

  test('endpoint not deployed (404): pauses instead of retrying constantly', () async {
    await addLogs(2);
    startWith((_) async => http.Response('', 404));

    await LogUploader.uploadNow();
    await LogUploader.uploadNow(); // paused: must not call the server again
    expect(requests.length, 1);
    expect((await db.notUploaded()).length, 2);
  });

  test('rejected batch (400) is skipped so the queue keeps moving', () async {
    await addLogs(2);
    startWith((_) async => http.Response('{"Message":"bad"}', 400));

    await LogUploader.uploadNow();
    expect(await db.notUploaded(), isEmpty);
    expect(await db.count(), 2); // still on the device, just not re-sent
  });

  test('new log triggers an upload automatically (no manual call)', () async {
    LogUploader.debounce = const Duration(milliseconds: 50);
    await AppLogger.init(db: db);
    AppLogger.onSaved = LogUploader.notify;
    startWith((_) async => http.Response('{}', 200));

    AppLogger.info('Test', 'auto upload');
    await AppLogger.flush();
    await Future.delayed(const Duration(milliseconds: 300));

    expect(requests, isNotEmpty);
    expect(await db.notUploaded(), isEmpty);
  });

  // Real server check. Off by default. Run with:
  //   flutter test test/log_uploader_test.dart --dart-define=E2E_API=https://testsahayiapi.multiroute.ae/api/
  const e2eApi = String.fromEnvironment('E2E_API');
  test('E2E: uploads to the real test server', () async {
    HttpOverrides.global = null; // allow real network in this test
    await db.insert(AppLog(
        clientTime: DateTime.now(),
        level: 'INFO',
        deviceId: 'CLAUDE-TEST',
        action: 'Test',
        message: 'E2E upload check from flutter test'));

    LogUploader.start(apiBaseUrl: e2eApi, db: db, client: () async => http.Client());
    expect(await LogUploader.uploadNow(), 1);
    expect(await db.notUploaded(), isEmpty);
  }, skip: e2eApi.isEmpty ? 'set --dart-define=E2E_API=... to run' : false);
}
