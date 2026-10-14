import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    test('success → INFO with status and time, password masked', () async {
      final client = LoggingClient(MockClient((_) async => http.Response('[]', 200)));
      final res = await client.get(Uri.parse(
          'https://api.test/api/Login/GetUsersLogin?UserID=MX1576&Pwd=secret'));

      expect(res.statusCode, 200);
      final log = (await logs()).last;
      expect(log.level, 'INFO');
      expect(log.action, 'Http');
      expect(log.message, contains('→ 200 in'));
      expect(log.message, contains('Pwd=***'));
      expect(log.message, isNot(contains('secret')));
    });

    test('server error 500 → ERROR, response still returned', () async {
      final client = LoggingClient(MockClient((_) async => http.Response('x', 500)));
      final res = await client.get(Uri.parse('https://api.test/api/x'));

      expect(res.statusCode, 500);
      expect((await logs()).last.level, 'ERROR');
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

    test('log upload (POST /v2/Logs) is not logged; dashboard reads (GET) are', () async {
      final client = LoggingClient(MockClient((_) async => http.Response('[]', 200)));
      await client.post(Uri.parse('https://api.test/api/v2/Logs'), body: '[]');
      expect((await logs()).where((e) => e.action == 'Http'), isEmpty);

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
      final actions = (await logs()).map((e) => '${e.level} ${e.action}').toList();
      expect(actions, containsAllInOrder(['WARN Retry', 'WARN Retry', 'ERROR RetryGaveUp']));
    });

    test('no retry logs when the first attempt succeeds', () async {
      await RetryHelper.retry<String>(
          apiCall: () async => 'ok', defaultValue: 'fallback');
      expect((await logs()).where((e) => e.action.startsWith('Retry')), isEmpty);
    });
  });
}
