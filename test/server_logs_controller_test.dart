import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sahayi_android/controller/admin/server_logs_controller.dart';
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/repo/admin_logs_repo.dart';
import 'package:sahayi_android/service/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const summary =
    '{"Totals":{"Total":5,"Errors":0,"Warnings":0,"Infos":5,"Devices":2},"Devices":[]}';
const oneLog =
    '[{"LogID":1,"LoggedAt":"2026-10-14T15:00:00","Level":"INFO","Action":"A","Message":"m"}]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LogDB db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'S', packageName: 'x', version: '1', buildNumber: '1', buildSignature: '');
    AppLogger.resetForTest();
    db = await LogDB.open(factory: databaseFactoryFfi, dbPath: inMemoryDatabasePath);
    await AppLogger.init(db: db);
  });
  tearDown(() => db.close());

  ServerLogsController controller(http.Response Function(http.Request) server) =>
      ServerLogsController(AdminLogsRepo(
          baseUrl: 'https://api.test/api/',
          headers: () => const {},
          client: () async => MockClient((r) async => server(r))));

  test('list fails, summary works: summary kept, list error shown and logged', () async {
    final c = controller((r) => r.url.path.endsWith('/Summary')
        ? http.Response(summary, 200)
        : http.Response('{"Message":"An error has occurred."}', 500));
    await c.refreshAll();

    expect(c.summary.value?.devices, 2);
    expect(c.error.value, contains('HTTP 500'));
    await AppLogger.flush();
    final logged = await db.search(actions: ['AdminLogsError']);
    expect(logged.single.message, contains('list could not load'));
  });

  test('summary fails, list works: logs still shown', () async {
    final c = controller((r) => r.url.path.endsWith('/Summary')
        ? http.Response('{}', 500)
        : http.Response(oneLog, 200));
    await c.refreshAll();

    expect(c.logs.length, 1);
    expect(c.error.value, isNull);
  });
}
