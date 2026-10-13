import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahayi_android/helper/retry_helper.dart';
import 'package:sahayi_android/helper/timeout_http_client.dart';

void main() {
  group('TimeoutClient', () {
    const short = Duration(milliseconds: 100);
    const long = Duration(milliseconds: 400);

    TimeoutClient slowServer(Duration delay) => TimeoutClient(
          MockClient((_) async {
            await Future.delayed(delay);
            return http.Response('[]', 200);
          }),
          readTimeout: short,
          saveTimeout: long,
          idleTimeout: long,
        );

    test('read (GET) that takes too long → TimeoutException', () async {
      await expectLater(slowServer(const Duration(milliseconds: 250)).get(Uri.parse('https://x/api/a')),
          throwsA(isA<TimeoutException>()));
    });

    test('save (POST) gets the longer limit', () async {
      final res = await slowServer(const Duration(milliseconds: 250)).post(Uri.parse('https://x/api/a'));
      expect(res.statusCode, 200);
    });

    test('fast answer passes through unchanged', () async {
      final res = await slowServer(Duration.zero).get(Uri.parse('https://x/api/a'));
      expect(res.statusCode, 200);
      expect(res.body, '[]');
    });
  });

  group('RetryHelper', () {
    test('throwWhenAllFail passes the real error to the caller', () async {
      var calls = 0;
      await expectLater(
        RetryHelper.retry<List<int>>(
          apiCall: () async {
            calls++;
            throw const SocketException('Connection refused');
          },
          defaultValue: [],
          retryDelay: Duration.zero,
          throwWhenAllFail: true,
        ),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 3);
    });

    test('empty list is a valid answer: returned at once, no retries', () async {
      var calls = 0;
      final result = await RetryHelper.retry<List<int>>(
        apiCall: () async {
          calls++;
          return [];
        },
        defaultValue: [],
        retryDelay: Duration.zero,
        throwWhenAllFail: true,
      );
      expect(result, isEmpty);
      expect(calls, 1);
    });

    test('retryOnError=false stops after a timeout (no second save)', () async {
      var calls = 0;
      final result = await RetryHelper.retry<bool>(
        apiCall: () async {
          calls++;
          throw TimeoutException('slow');
        },
        defaultValue: false,
        retryDelay: Duration.zero,
        shouldRetry: (r) => r == false,
        retryOnError: (e) => e is! TimeoutException,
      );
      expect(result, isFalse);
      expect(calls, 1);
    });

    test('other errors on a save are still retried', () async {
      var calls = 0;
      await RetryHelper.retry<bool>(
        apiCall: () async {
          calls++;
          throw const SocketException('Connection refused');
        },
        defaultValue: false,
        retryDelay: Duration.zero,
        retryOnError: (e) => e is! TimeoutException,
      );
      expect(calls, 3);
    });
  });
}
