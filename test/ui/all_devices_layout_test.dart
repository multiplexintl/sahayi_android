import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahayi_android/repo/admin_logs_repo.dart';
import 'package:sahayi_android/view/admin/all_devices_tab.dart';

/// "All devices" tab on a 360x640 screen with realistic server answers.
void main() {
  http.Response answer(http.Request req) {
    if (req.url.path.endsWith('/Summary')) {
      return http.Response(jsonEncode({
        'Totals': {'Total': 131, 'Errors': 3, 'Warnings': 6, 'Infos': 122, 'Devices': 1,
          'FirstLog': '2026-10-13T15:06:39.848', 'LastLog': '2026-10-14T14:35:10.123'},
        'Devices': [
          {'DeviceID': 'EDA52-7f35a775', 'LastUserID': 'MX1576', 'LastAppVersion': '1.0.15+15',
           'LastSeen': '2026-10-14T14:35:10.123', 'Total': 130, 'Errors': 3, 'Warnings': 6}
        ]
      }), 200);
    }
    return http.Response(jsonEncode([
      for (var i = 0; i < 30; i++)
        {
          'LogID': 200 - i, 'LoggedAt': '2026-10-14T14:${10 + i}:00', 'ClientTime': '2026-10-14T14:${10 + i}:00',
          'Source': 'APP', 'Level': i % 4 == 0 ? 'ERROR' : 'INFO', 'UserID': 'MX1576',
          'DeviceID': 'EDA52-7f35a775', 'Action': 'SomeLongActionName$i',
          'Message': 'A fairly long message number $i that will need two lines on a small screen',
          'Screen': '/scan-invoice', 'DocNum': '2503270$i',
        }
    ]), 200);
  }

  for (final fontScale in [1.0, 1.3]) {
    testWidgets('All devices tab fits 360x640 (font x$fontScale)', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = fontScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final repo = AdminLogsRepo(
          baseUrl: 'https://api.test/api/',
          headers: () => const {},
          client: () async => MockClient((req) async => answer(req)));

      await tester.pumpWidget(GetMaterialApp(home: Scaffold(body: AllDevicesTab(repo: repo))));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('131 logs · 1 devices · ', findRichText: true), findsNothing); // rich text, checked below
      expect(find.textContaining('131 logs', findRichText: true), findsOneWidget);
      expect(find.text('SomeLongActionName0'), findsOneWidget);

      // Device picker opens and lists the scanner
      await tester.tap(find.text('All devices'));
      await tester.pumpAndSettle();
      expect(find.text('EDA52-7f35a775'), findsOneWidget);
      expect(tester.takeException(), isNull);

      Get.reset();
    });
  }
}
