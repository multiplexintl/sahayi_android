import 'package:flutter_test/flutter_test.dart';
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/model/app_log.dart';
import 'package:sahayi_android/model/log_filter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('LogPreset', () {
    test('presets keep the date range, drop other filters', () {
      final base = LogFilter(
          from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 3), screen: '/home', levels: {'INFO'});
      final f = LogPreset.errors.apply(base);
      expect(f.levels, {'ERROR'});
      expect(f.screen, isNull);
      expect(f.from, DateTime(2026, 10, 1));
      expect(f.to, DateTime(2026, 10, 3));
    });

    test('matching() recognises each preset, null for custom', () {
      for (final p in LogPreset.values) {
        expect(LogPreset.matching(p.apply(const LogFilter())), p);
      }
      expect(LogPreset.matching(const LogFilter(screen: '/home')), isNull);
    });

    test('activeCount (dates count once)', () {
      expect(const LogFilter().activeCount, 0);
      expect(LogFilter(from: DateTime(2026), to: DateTime(2026), levels: {'ERROR'}).activeCount, 2);
    });

    test('toExclusive is the next midnight', () {
      expect(LogFilter(to: DateTime(2026, 10, 14)).toExclusive, DateTime(2026, 10, 15));
    });
  });

  group('LogDB multi-value filters', () {
    late LogDB db;
    setUp(() async {
      db = await LogDB.open(factory: databaseFactoryFfi, dbPath: inMemoryDatabasePath);
      final t = DateTime(2026, 10, 14, 9);
      Future<void> add(String level, String action,
              {String? screen, String? docType, String? user, int up = 0}) =>
          db.insert(AppLog(
              clientTime: t,
              level: level,
              action: action,
              message: action,
              screen: screen,
              docType: docType,
              userId: user,
              uploadState: up));
      await add('ERROR', 'HttpFailed', screen: '/scan-invoice', docType: 'I', user: 'MX1');
      await add('WARN', 'Network', screen: '/home', user: 'MX1');
      await add('INFO', 'Network', screen: '/home', up: 1);
      await add('ERROR', 'FlutterError', screen: '/scan-returns', docType: 'R', user: 'MX2');
      await add('WARN', 'SyncFailed', screen: '/sync-invoice', docType: 'I', up: 2);
    });
    tearDown(() => db.close());

    Future<List<String>> run(LogFilter f) async =>
        (await db.search(
                levels: f.levels,
                actions: f.actions,
                screen: f.screen,
                userId: f.userId,
                docType: f.docType,
                uploadState: f.uploadState))
            .map((e) => e.action)
            .toList();

    test('Network preset: only network problems (INFO Network excluded)', () async {
      expect(await run(LogPreset.network.apply(const LogFilter())), ['Network', 'HttpFailed']);
    });
    test('Crashes preset', () async {
      expect(await run(LogPreset.crashes.apply(const LogFilter())), ['FlutterError']);
    });
    test('Failed work preset', () async {
      expect(await run(LogPreset.failedWork.apply(const LogFilter())), ['SyncFailed']);
    });
    test('Errors + warnings', () async {
      expect((await run(LogPreset.problems.apply(const LogFilter()))).length, 4);
    });
    test('Waiting upload', () async {
      expect(await run(LogPreset.waiting.apply(const LogFilter())),
          ['FlutterError', 'Network', 'HttpFailed']);
    });
    test('screen / user / doc type / upload state filters', () async {
      expect(await run(const LogFilter(screen: '/home')), ['Network', 'Network']);
      expect(await run(const LogFilter(userId: 'MX2')), ['FlutterError']);
      expect(await run(const LogFilter(docType: 'I')), ['SyncFailed', 'HttpFailed']);
      expect(await run(const LogFilter(uploadState: 2)), ['SyncFailed']);
    });
    test('distinctValues: most frequent first; unsafe column refused', () async {
      final actions = await db.distinctValues('Action');
      expect(actions.first, (value: 'Network', count: 2));
      expect(() => db.distinctValues('Message; DROP TABLE AppLog'), throwsArgumentError);
    });
  });
}
