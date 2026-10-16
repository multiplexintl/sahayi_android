import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sahayi_android/controller/connectivity_controller.dart';
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/helper/logging_http_client.dart';
import 'package:sahayi_android/helper/retry_helper.dart';
import 'package:sahayi_android/model/app_log.dart';
import 'package:sahayi_android/service/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late LogDB db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Sahayi',
        packageName: 'com.multiplex.sahayi_android',
        version: '1.0.15',
        buildNumber: '15',
        buildSignature: '');
    AppLogger.resetForTest();
    db = await LogDB.open(
        factory: databaseFactoryFfi, dbPath: inMemoryDatabasePath);
    await AppLogger.init(db: db);
  });

  tearDown(() => db.close());

  Future<List<AppLog>> logs() async {
    await AppLogger.flush();
    return (await db.recent()).reversed.toList();
  }

  group('LoggingClient (every server call)', () {
    test('success → not saved, but kept as a recent step (password masked)', () async {
      final client = LoggingClient(MockClient((_) async => http.Response('[]', 200)));
      final res = await client.get(Uri.parse(
          'https://api.test/api/Login/GetUsersLogin?UserID=MX1576&Pwd=secret'));

      expect(res.statusCode, 200);
      expect(await logs(), isEmpty);
      AppLogger.error('Later', 'something broke');
      final steps = (await logs()).single.details!;
      expect(steps, contains('Http: GET https://api.test/api/Login/GetUsersLogin?UserID=MX1576&Pwd=*** → 200 in'));
      expect(steps, isNot(contains('secret')));
    });

    test('slow success (over 10 s) → WARN SlowResponse', () async {
      LoggingClient.slowAfter = const Duration(milliseconds: 50);
      addTearDown(() => LoggingClient.slowAfter = const Duration(seconds: 10));
      final client = LoggingClient(MockClient((_) async {
        await Future.delayed(const Duration(milliseconds: 80));
        return http.Response('[]', 200);
      }));
      await client.get(Uri.parse('https://api.test/api/x'));
      final log = (await logs()).single;
      expect('${log.level} ${log.action}', 'WARN SlowResponse');
      expect(log.message, contains('→ 200 in'));
    });

    test('server error 500 → ERROR with data sent + server answer; caller gets the same body', () async {
      final client = LoggingClient(MockClient((_) async =>
          http.Response('{"Message":"An error has occurred.","ExceptionMessage":"Timeout expired"}', 500)));
      final res = await client.post(Uri.parse('https://api.test/api/Return/Insert'),
          body: '{"DocNum":"R1","Password":"secret","Qty":3}');

      expect(res.statusCode, 500);
      expect(res.body, contains('Timeout expired'));
      final log = (await logs()).last;
      expect(log.level, 'ERROR');
      expect(log.details, contains('Sent: {"DocNum":"R1","Password":"***","Qty":3}'));
      expect(log.details, contains('Response: {"Message":"An error has occurred.","ExceptionMessage":"Timeout expired"}'));
      expect(log.details, isNot(contains('secret')));
    });

    test('4xx → WARN with the server answer', () async {
      final client = LoggingClient(MockClient((_) async => http.Response('Not found', 404)));
      final res = await client.get(Uri.parse('https://api.test/api/x'));
      expect(res.body, 'Not found');
      final log = (await logs()).single;
      expect(log.level, 'WARN');
      expect(log.details, 'Response: Not found');
    });

    test('huge server answer is capped at 4000 chars', () async {
      final client = LoggingClient(MockClient((_) async => http.Response('y' * 20000, 500)));
      final res = await client.get(Uri.parse('https://api.test/api/x'));
      expect(res.body.length, 20000);
      expect((await logs()).single.details, contains('(16000 more chars)'));
    });

    test('network failure → HttpFailed with plain reason, error rethrown', () async {
      final client = LoggingClient(MockClient((_) async => throw const SocketException(
          'Failed host lookup: testsahayiapi.multiroute.ae')));

      await expectLater(
          client.get(Uri.parse('https://api.test/api/x')), throwsA(isA<SocketException>()));
      final log = (await logs()).last;
      expect(log.level, 'ERROR');
      expect(log.action, 'HttpFailed');
      expect(log.message, contains('DNS FAILED'));
    });

    test('log upload (POST /v2/Logs) is never logged, even when it fails; dashboard reads are', () async {
      final client = LoggingClient(MockClient((_) async => http.Response('down', 500)));
      await client.post(Uri.parse('https://api.test/api/v2/Logs'), body: '[]');
      expect(await logs(), isEmpty);

      await client.get(Uri.parse('https://api.test/api/v2/Logs?top=100'));
      final http1 = (await logs()).where((e) => e.action == 'Http').toList();
      expect(http1.single.message, contains('GET https://api.test/api/v2/Logs?top=100'));
    });

    test('describe() categories', () {
      expect(LoggingClient.describe(TimeoutException('t')), startsWith('TIMEOUT'));
      expect(LoggingClient.describe(const HandshakeException('h')),
          startsWith('SECURE CONNECTION FAILED'));
      expect(LoggingClient.describe(const SocketException('Connection refused')),
          startsWith('CONNECTION REFUSED'));
      expect(LoggingClient.describe(const SocketException('Network is unreachable')),
          startsWith('NETWORK UNREACHABLE'));
    });
  });

  group('RetryHelper', () {
    test('logs each failed attempt and the final give-up', () async {
      final result = await RetryHelper.retry<String>(
        apiCall: () async => throw const SocketException('Connection refused'),
        defaultValue: 'fallback',
        maxRetries: 2,
        retryDelay: Duration.zero,
      );

      expect(result, 'fallback'); // behaviour unchanged
      final saved = await logs();
      // 2nd attempt is the same problem again: counted, and visible in the
      // give-up error's recent steps.
      expect(saved.map((e) => '${e.level} ${e.action}'), ['WARN Retry', 'ERROR RetryGaveUp']);
      expect(saved.last.details, contains('WARN Retry: (repeat) Attempt 2 of 2 threw'));
    });

    test('no retry logs when the first attempt succeeds', () async {
      await RetryHelper.retry<String>(
          apiCall: () async => 'ok', defaultValue: 'fallback');
      expect((await logs()).where((e) => e.action.startsWith('Retry')), isEmpty);
    });
  });

  group('Offline', () {
    test('one row when the connection comes back, with the duration', () {
      expect(
          ConnectivityController.offlineMessage(
              DateTime(2026, 10, 18, 12, 31, 5), DateTime(2026, 10, 18, 12, 44, 30), 'wifi'),
          'Offline 12:31 → 12:44 (13 min), back on wifi');
      expect(
          ConnectivityController.offlineMessage(
              DateTime(2026, 10, 18, 12, 31, 5), DateTime(2026, 10, 18, 12, 31, 50), ''),
          'Offline 12:31 → 12:31 (45 s)');
      expect(
          ConnectivityController.offlineMessage(
              DateTime(2026, 10, 17, 23, 50), DateTime(2026, 10, 18, 0, 20), 'mobile'),
          'Offline 23:50 → 00:20 (from 17/10) (30 min), back on mobile');
    });
  });
}
