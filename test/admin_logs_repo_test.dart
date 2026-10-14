import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahayi_android/model/log_filter.dart';
import 'package:sahayi_android/repo/admin_logs_repo.dart';

const logJson = {
  'LogID': 120,
  'LoggedAt': '2026-10-14T14:35:10.123',
  'ClientTime': '2026-10-14T14:35:09.900',
  'Source': 'APP',
  'Level': 'ERROR',
  'UserID': 'MX1576',
  'DeviceID': 'EDA52-7f35a775',
  'Action': 'HttpFailed',
  'Message': 'DNS FAILED',
  'Screen': '/scan-invoice',
  'DocNum': '25032700',
  'DocType': 'I',
};

const summaryJson = {
  'Totals': {
    'Total': 131, 'Errors': 3, 'Warnings': 6, 'Infos': 122, 'Devices': 2,
    'FirstLog': '2026-10-13T15:06:39.848', 'LastLog': '2026-10-14T14:35:10.123'
  },
  'Devices': [
    {'DeviceID': 'EDA52-7f35a775', 'LastUserID': 'MX1576', 'LastAppVersion': '1.0.15+15',
     'LastSeen': '2026-10-14T14:35:10.123', 'Total': 130, 'Errors': 3, 'Warnings': 6},
    {'DeviceID': null, 'LastUserID': 'MX1576', 'LastAppVersion': null,
     'LastSeen': '2026-10-14T12:00:26.395', 'Total': 1, 'Errors': 0, 'Warnings': 0},
  ]
};

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) server;

  AdminLogsRepo repo() => AdminLogsRepo(
        baseUrl: 'https://api.test/api/',
        headers: () => {'X-Admin-User': 'MX1576', 'X-Admin-Password': 'secret'},
        client: () async => MockClient((req) async {
          requests.add(req);
          return server(req);
        }),
      );

  setUp(() => requests = []);

  test('search sends filters as query parameters and admin headers', () async {
    server = (_) => http.Response(jsonEncode([logJson]), 200);
    final f = LogPreset.network.apply(LogFilter(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 14)));
    final logs = await repo().search(f, text: ' DNS ', deviceId: 'EDA52-7f35a775', beforeLogId: 500);

    final q = requests.single.url.queryParameters;
    expect(requests.single.url.path, '/api/v2/Logs');
    expect(q['levels']!.split(',').toSet(), {'ERROR', 'WARN'});
    expect(q['actions'], contains('HttpFailed'));
    expect(q['fromDate'], '2026-10-01T00:00:00');
    expect(q['toDate'], '2026-10-15T00:00:00'); // day after "to" (inclusive day)
    expect(q['deviceId'], 'EDA52-7f35a775');
    expect(q['text'], 'DNS');
    expect(q['beforeLogId'], '500');
    expect(q.containsKey('screen'), isFalse); // empty filters are not sent
    expect(requests.single.headers['X-Admin-User'], 'MX1576');
    expect(requests.single.url.toString(), isNot(contains('secret'))); // password never in URL

    expect(logs.single.logId, 120);
    expect(logs.single.time, DateTime(2026, 10, 14, 14, 35, 9, 900)); // device time preferred
  });

  test('summary parses totals and devices (API logs have no device)', () async {
    server = (_) => http.Response(jsonEncode(summaryJson), 200);
    final s = await repo().summary();
    expect([s.total, s.errors, s.devices], [131, 3, 2]);
    expect(s.deviceList.first.deviceId, 'EDA52-7f35a775');
    expect(s.deviceList.last.deviceId, isNull);
  });

  test('values parses value + count', () async {
    server = (_) => http.Response(jsonEncode([{'Value': 'Navigate', 'Count': 36}]), 200);
    expect(await repo().values('Action'), [(value: 'Navigate', count: 36)]);
    expect(requests.single.url.queryParameters['column'], 'Action');
  });

  test('delete everything sends confirmAll=DELETE ALL; device delete does not', () async {
    server = (_) => http.Response('{"Deleted":131}', 200);
    expect(await repo().delete(all: true), 131);
    expect(requests.last.method, 'DELETE');
    expect(requests.last.url.queryParameters['confirmAll'], 'DELETE ALL');

    await repo().delete(deviceId: 'EDA52-7f35a775');
    expect(requests.last.url.queryParameters.containsKey('confirmAll'), isFalse);
    expect(requests.last.url.queryParameters['deviceId'], 'EDA52-7f35a775');
  });

  test('401 / 429 become login problems; 500 shows the server message', () async {
    server = (_) => http.Response('{"Message":"Admin login required."}', 401);
    await expectLater(repo().summary(),
        throwsA(isA<AdminLogsException>().having((e) => e.loginProblem, 'loginProblem', true)));

    server = (_) => http.Response('{}', 429);
    await expectLater(repo().summary(), throwsA(isA<AdminLogsException>()));

    server = (_) => http.Response('{"Message":"An error has occurred."}', 500);
    await expectLater(repo().summary(),
        throwsA(isA<AdminLogsException>().having((e) => e.message, 'message', contains('HTTP 500'))));
  });

  test('no connection gives a readable message', () async {
    server = (_) => throw http.ClientException('Connection refused');
    await expectLater(repo().summary(),
        throwsA(isA<AdminLogsException>().having((e) => e.message, 'message', contains('Could not reach'))));
  });
}
