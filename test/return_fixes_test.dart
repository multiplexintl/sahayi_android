import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/db/log_db.dart';
import 'package:sahayi_android/service/app_logger.dart';
import 'package:sahayi_android/helper/http_client_helper.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';
import 'package:sahayi_android/model/return/customer.dart';
import 'package:sahayi_android/model/return/reasons.dart';
import 'package:sahayi_android/model/user.dart';
import 'package:sahayi_android/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestHome extends HomeController {
  @override
  // ignore: must_call_super
  void onInit() => user.value = User(empID: 'MX1576', company: 'EPIC01');
}

class TestReturn extends ReturnController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

/// Pretend API: parts, the server's lines of return 1308R1, CreateReturn.
class FakeServer {
  final parts = <String, Map<String, dynamic>>{};
  final serverLines = <Map<String, dynamic>>[];

  /// ok | timeoutAfterSave | timeoutNoSave
  String createMode = 'ok';
  bool getFails = false;

  /// The connection drops right after CreateReturn (its check then fails).
  bool dropAfterCreate = false;
  int creates = 0;

  http.Client client() => MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('Return/GetPartData')) {
          final p = parts[req.url.queryParameters['barcode']];
          return http.Response(jsonEncode(p == null ? [] : [p]), 200);
        }
        if (path.endsWith('Return/DocumentGetRecords')) {
          if (getFails) throw const SocketException('Network is unreachable');
          if (serverLines.isEmpty) return http.Response('[]', 200);
          return http.Response(
              jsonEncode([
                {
                  'Company': 'EPIC01',
                  'DocNum': '1308R1',
                  'DocDate': '10/16/2026 12:00:00 AM',
                  'CustNum': '1308',
                  'Stat': 'Y',
                  'UserID': 'MX1576',
                  'ScanTime': '2026-10-16T10:00:00',
                  'CustName': 'Lulu',
                  'DocType': 'R',
                  'PickedBy': 'D1',
                  'DocDetails': serverLines,
                }
              ]),
              200);
        }
        if (path.endsWith('Return/CreateReturn')) {
          creates++;
          if (dropAfterCreate) getFails = true;
          if (createMode == 'timeoutNoSave') throw TimeoutException('no answer');
          final master = (jsonDecode(req.body) as List).first['SReturnMaster'];
          for (final d in master['RtnDetails'] as List) {
            serverLines.add(line(int.parse(d['SlNo']), d['PartNum'], d['CheckQty'], d['ReasonCode']));
          }
          if (createMode == 'timeoutAfterSave') throw TimeoutException('no answer');
          return http.Response('"Return Created successfully."', 200);
        }
        return http.Response('not found', 404);
      });

  static Map<String, dynamic> line(int slNo, String part, int qty, String reason) => {
        'SlNo': slNo,
        'Company': 'EPIC01',
        'DocNum': '1308R1',
        'PartNum': part,
        'ShipQty': 0,
        'CheckQty': qty,
        'Stat': 'Y',
        'Barcode': 'B-$part',
        'PartName': 'Part $part',
        'Brand': 'X',
        'DocType': 'R',
        'ReasonCode': reason,
        'ReasonName': reason,
        'ExpDate': null,
      };
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late FakeServer server;
  late ReturnController con;
  final driver = Pickers(id: 'D1', name: 'Driver', type: 'Driver');

  Map<String, dynamic> localRow(int slNo, String barcode, String part, int qty,
          {String reason = 'DMG'}) =>
      {
        DBHelper.companyDocDetail: 'EPIC01',
        DBHelper.docNumDocDetail: '1308R1',
        DBHelper.docTypeDocDetail: 'R',
        DBHelper.slNoDocDetail: slNo,
        DBHelper.barcodeDocDetail: barcode,
        DBHelper.partNumDocDetail: part,
        DBHelper.partNameDocDetail: 'Part $part',
        DBHelper.brandDocDetail: 'X',
        DBHelper.shipQtyDocDetail: 0,
        DBHelper.checkQtyDocDetail: qty,
        DBHelper.statDocDetail: 'N',
        DBHelper.reasonCodeDocDetail: reason,
        DBHelper.reasonNameDocDetail: reason,
        DBHelper.expiryDateDocDetail: null,
      };

  Future<List<Map<String, dynamic>>> localLines() => DBHelper.getItemsByQuery(
      tableName: DBHelper.docDetail,
      where: '${DBHelper.docNumDocDetail} = ?',
      whereArgs: ['1308R1']);

  Future<void> seedReturn(List<Map<String, dynamic>> rows) async {
    await DBHelper.bulkInsert(tableName: DBHelper.docMaster, items: [
      {
        DBHelper.companyDocMaster: 'EPIC01',
        DBHelper.docNumDocMaster: '1308R1',
        DBHelper.docTypeDocMaster: 'R',
        DBHelper.docDateDocMaster: '16-10-2026',
        DBHelper.custNumDocMaster: '1308',
        DBHelper.custNameDocMaster: 'Lulu',
        DBHelper.statDocMaster: 'N',
        DBHelper.userIDDocMaster: 'MX1576',
        DBHelper.scanTimeDocMaster: '2026-10-16 10:00:00',
        DBHelper.pickedByDocMaster: 'D1',
      }
    ]);
    await DBHelper.bulkInsert(tableName: DBHelper.docDetail, items: rows);
  }

  Future<void> app(WidgetTester tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: const Scaffold(body: Text('RETURN START')),
      getPages: [GetPage(name: RouteLinks.scanReturns, page: () => const Scaffold(body: Text('SCAN')))],
    ));
  }

  /// Saved log actions, oldest first (the outcome of each finalize is logged).
  Future<List<String>> logged(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        await AppLogger.flush();
        return (await AppLogger.recent()).reversed.map((e) => e.action).toList();
      }))!;

  /// Pop-up messages are queued and slide in over several frames.
  Future<void> showMessages(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets every queued message run out (they show for up to 8 s each).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      Get.closeAllSnackbars();
      await tester.pump(const Duration(seconds: 10));
    }
  }

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    GlobalConfiguration().loadFromMap({'api_base_url': 'https://api.test/api/'});
    server = FakeServer();
    HttpClientHelper.testClient = server.client();
    for (final t in [DBHelper.docMaster, DBHelper.docDetail, DBHelper.lastInvoices]) {
      await DBHelper.deleteAllItem(tableName: t);
    }
    AppLogger.resetForTest();
    await AppLogger.init(
        db: await LogDB.open(factory: databaseFactoryFfiNoIsolate, dbPath: inMemoryDatabasePath));
    Get.put<HomeController>(TestHome());
    con = Get.put<ReturnController>(TestReturn());
    con.companyList = [Company(companyId: 'EPIC01', companyName: 'Epic')];
    con.selectedCompany.value = con.companyList.first;
    con.driverList.value = [driver];
    con.driver.value = driver;
    con.selectedCustomer.value = Customer(custId: '1308', custName: 'Lulu');
    con.docNumber.value = 'R1';
    con.docDate.value = '16-10-2026';
  });

  tearDown(() {
    HttpClientHelper.testClient = null;
    Get.reset();
  });

  group('Bug 1: Save item needs a known item', () {
    testWidgets('unknown barcode: nothing saved, user told "Item not found"', (tester) async {
      await app(tester);
      await tester.runAsync(() async {
        con.barcodeController.text = '1234567';
        con.qtyController.text = '2';
        con.selectedReason.value = Reasons(reasonId: 'DMG', reason: 'Damaged');
        con.onSavePart();
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await showMessages(tester);
      expect(find.text('Item not found'), findsOneWidget);
      expect(await tester.runAsync(localLines), isEmpty);
      await settle(tester);
    });

    testWidgets('short barcode not looked up yet: Save looks it up, then saves', (tester) async {
      server.parts['1234567'] = {
        'Company': 'EPIC01', 'PartNum': 'P1', 'Barcode': '1234567', 'PartName': 'Short code', 'Brand': 'X'
      };
      await app(tester);
      await tester.runAsync(() async {
        con.barcodeController.text = '1234567';
        con.qtyController.text = '2';
        con.selectedReason.value = Reasons(reasonId: 'DMG', reason: 'Damaged');
        con.onSavePart();
        await Future.delayed(const Duration(milliseconds: 300));
      });
      final rows = await tester.runAsync(localLines);
      expect(rows!.single[DBHelper.partNumDocDetail], 'P1');
      expect(rows.single[DBHelper.checkQtyDocDetail], 2);
      await settle(tester);
    });

    testWidgets('answer for an older barcode is ignored (13 → 14 digits)', (tester) async {
      server.parts['1234567890123'] = {
        'Company': 'EPIC01', 'PartNum': 'WRONG', 'Barcode': '1234567890123', 'PartName': 'Prefix item', 'Brand': 'X'
      };
      await app(tester);
      await tester.runAsync(() async {
        con.barcodeController.text = '12345678901234'; // field already has 14 digits
        final part = await con.fetchBarcodeDetails('1234567890123', shouldRequestFocus: false);
        expect(part, isNull);
      });
      expect(con.selectedPart.value, isNull);
      await settle(tester);
    });
  });

  group('Bug 2: resuming does not copy lines', () {
    testWidgets('server has more lines: phone keeps exactly its lines, no hidden copies', (tester) async {
      await app(tester);
      await tester.runAsync(() async {
        await seedReturn([localRow(1, 'B-A', 'A', 2), localRow(2, 'B-B', 'B', 1), localRow(3, 'B-C', 'C', 5)]);
        for (var i = 1; i <= 4; i++) {
          server.serverLines.add(FakeServer.line(i, 'S$i', 1, 'DMG'));
        }
        await con.onSubmit(DocMaster(company: 'EPIC01', docNum: 'R1', custID: '1308', custName: 'Lulu', pickedBy: 'D1'));
      });
      await tester.pumpAndSettle();
      final rows = await tester.runAsync(localLines);
      expect(rows!.map((r) => r[DBHelper.slNoDocDetail]).toSet(), {1, 2, 3});
      expect(con.savedItems.length, 3);
      // Before the fix: 3 extra rows saved under DocNum "R1" (customer ID cut off)
      final all = await tester.runAsync(() => DBHelper.getAllItems(tableName: DBHelper.docDetail));
      expect(all!.length, 3, reason: 'no copies under another document number');
      await settle(tester);
    });
  });

  group('Bug 3: upload that times out', () {
    Future<bool?> finalizeWith(WidgetTester tester, List<Map<String, dynamic>> rows) async {
      bool? ok;
      await tester.runAsync(() async {
        await seedReturn(rows);
        con.savedItems.value = (await localLines()).map(DocDetail.fromJson).toList();
        con.consolidateSavedItems();
        con.getTotalQty();
        ok = await con.finalize();
        await Future.delayed(const Duration(milliseconds: 300)); // message queue runs in real time
      });
      await showMessages(tester);
      return ok;
    }

    testWidgets('timed out but the server saved it: treated as done, not sent again', (tester) async {
      await app(tester);
      server.serverLines.add(FakeServer.line(1, 'OLD', 1, 'DMG')); // earlier lines of this return
      server.createMode = 'timeoutAfterSave';
      final ok = await finalizeWith(tester, [localRow(1, 'B-A', 'A', 2), localRow(2, 'B-B', 'B', 1)]);
      expect(ok, isTrue);
      expect(server.creates, 1);
      expect(server.serverLines.length, 3); // 1 old + 2 new, no copies
      expect(await logged(tester), contains('FinalizeRecovered'));
      expect(await tester.runAsync(localLines), isEmpty, reason: 'phone cleared');
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getKeys().where((k) => k.startsWith('pendingReturnUpload')), isEmpty);
      await settle(tester);
    });

    testWidgets('timed out and the server does NOT have it: failed, safe to try again', (tester) async {
      await app(tester);
      server.createMode = 'timeoutNoSave';
      final ok = await finalizeWith(tester, [localRow(1, 'B-A', 'A', 2)]);
      expect(ok, isFalse);
      expect(await logged(tester), contains('FinalizeFailed'));
      expect(await logged(tester), isNot(contains('FinalizeUnconfirmed')));
      expect((await tester.runAsync(localLines))!.length, 1, reason: 'kept on the phone');

      server.createMode = 'ok';
      bool? again;
      await tester.runAsync(() async => again = await con.finalize());
      expect(again, isTrue);
      expect(server.serverLines.length, 1);
      await settle(tester);
    });

    testWidgets('no answer and server unreachable: next Finalize checks first, never sends twice',
        (tester) async {
      await app(tester);
      server.createMode = 'timeoutAfterSave';
      // CreateReturn saves, then the connection drops for the check
      server.dropAfterCreate = true;
      final ok = await finalizeWith(tester, [localRow(1, 'B-A', 'A', 2), localRow(2, 'B-B', 'B', 1)]);
      expect(ok, isFalse);
      expect(await logged(tester), contains('FinalizeUnconfirmed'));
      expect((await tester.runAsync(localLines))!.length, 2, reason: 'kept until confirmed');

      // connection back: Finalize again finds the lines and does not re-send
      server.dropAfterCreate = false;
      server.getFails = false;
      bool? again;
      await tester.runAsync(() async => again = await con.finalize());
      expect(again, isTrue);
      expect(await logged(tester), contains('FinalizeRecovered'));
      expect(server.creates, 1, reason: 'sent only once');
      expect(server.serverLines.length, 2);
      expect(await tester.runAsync(localLines), isEmpty);
      await settle(tester);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('uploadIsOnServer: all sent lines must match number, part, qty and reason', () {
    final sent = [
      {'SlNo': 5, 'PartNum': 'A', 'CheckQty': 2, 'ReasonCode': 'DMG'},
      {'SlNo': 6, 'PartNum': 'B', 'CheckQty': 1, 'ReasonCode': 'EXP'},
    ];
    DocDetail s(int n, String p, int q, String r) => DocDetail(slNo: n, partNum: p, checkQty: q, reasonCode: r);
    expect(ReturnController.uploadIsOnServer([s(5, 'A', 2, 'DMG'), s(6, 'B', 1, 'EXP')], sent), isTrue);
    expect(ReturnController.uploadIsOnServer([s(5, 'A', 2, 'DMG')], sent), isFalse);
    // another phone's lines with the same numbers are not ours
    expect(ReturnController.uploadIsOnServer([s(5, 'A', 2, 'DMG'), s(6, 'C', 1, 'EXP')], sent), isFalse);
    expect(ReturnController.uploadIsOnServer([], const []), isFalse);
  });
}
