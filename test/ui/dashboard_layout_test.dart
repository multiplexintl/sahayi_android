import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/model/app_log.dart';
import 'package:sahayi_android/service/admin_service.dart';
import 'package:sahayi_android/service/app_logger.dart';
import 'package:sahayi_android/view/admin/logs_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../v2/test_app.dart';

/// EDA52-sized screen (360 x 640): no overflow, and the log list gets most of
/// the screen.
void main() => bothThemes(_tests);

void _tests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for (final fontScale in [1.0, 1.3]) {
    testWidgets('dashboard fits a 360x640 screen (font x$fontScale)', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = fontScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
          appName: 'Sahayi', packageName: 'x', version: '1.0.15', buildNumber: '15', buildSignature: '');
      GlobalConfiguration().loadFromMap({'api_base_url': 'https://api.test/api/'});
      AppLogger.resetForTest();
      AdminService.resetForTest();

      late LogDB db;
      await tester.runAsync(() async {
        db = await LogDB.open(factory: databaseFactoryFfi, dbPath: inMemoryDatabasePath);
        await AppLogger.init(db: db);
        for (var i = 0; i < 30; i++) {
          await db.insert(AppLog(
              clientTime: DateTime(2026, 10, 14, 9, i),
              level: i % 3 == 0 ? 'ERROR' : 'INFO',
              action: 'Action$i',
              message: 'Message $i with some longer text to wrap on a small screen',
              userId: 'MX1576',
              docNum: '2503270$i',
              screen: '/scan-invoice'));
        }
        // Online admin session (two tabs)
        AdminService.current = AdminService.testSession(online: true);
      });

      await tester.pumpWidget(testApp(home: LogsDashboardScreen()));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      final listHeight = tester.getSize(find.byType(ListView).last).height;
      // ignore: avoid_print
      print('font x$fontScale: log list height ${listHeight.toStringAsFixed(0)} of 640');
      expect(listHeight, greaterThan(fontScale == 1.0 ? 400 : 340));

      await tester.runAsync(() => db.close());
    });
  }
}
