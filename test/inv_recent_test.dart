import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/helper/http_client_helper.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';
import 'package:sahayi_android/model/user.dart';
import 'package:sahayi_android/routes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestInv extends InvoiceOrTransferController {
  final calls = <String>[];
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> getItemsThenToScanPage() async => calls.add('scan');
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  late String dbDir;
  setUpAll(() async {
    dbDir = (await Directory.systemTemp.createTemp('sahayi_inv_')).path;
    await databaseFactory.setDatabasesPath(dbDir);
  });
  // The controller creates an AudioPlayer (wrong-barcode sound); no audio in tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  // Includes its per-player event channels (names end in a random id).
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.allMessagesHandler =
      (channel, handler, message) async => channel.startsWith('xyz.luan/audioplayers')
          ? const StandardMethodCodec().encodeSuccessEnvelope(null)
          : null;

  late TestInv con;
  final epic = Company(companyId: 'EPIC01', companyName: 'EPIC Trading');
  final other = Company(companyId: 'OTHR01', companyName: 'Other Co');
  final picker = Pickers(id: 'EX0085', name: 'Rashid K.');

  Map<String, dynamic> masterRow(String docNum) => {
        DBHelper.companyDocMaster: 'EPIC01',
        DBHelper.docNumDocMaster: docNum,
        DBHelper.docTypeDocMaster: 'I',
        DBHelper.docDateDocMaster: '3/20/2025 12:00:00 AM',
        DBHelper.custNumDocMaster: '1308',
        DBHelper.custNameDocMaster: 'Kesariya',
        DBHelper.statDocMaster: 'N',
        DBHelper.userIDDocMaster: 'MX1576',
        DBHelper.scanTimeDocMaster: '2026-10-16 10:00:00',
        DBHelper.pickedByDocMaster: 'EX0085',
      };

  Future<void> app(WidgetTester tester) => tester.pumpWidget(GetMaterialApp(
        home: const Scaffold(body: Text('HUB')),
        getPages: [
          GetPage(name: RouteLinks.syncInvoice, page: () => const Scaffold(body: Text('SYNC PAGE'))),
        ],
      ));

  setUp(() async {
    Get.testMode = true;
    await DBHelper.resetForTest();
    for (final t in [DBHelper.docMaster, DBHelper.docDetail, DBHelper.lastInvoices]) {
      await DBHelper.deleteAllItem(tableName: t);
    }
    con = Get.put<InvoiceOrTransferController>(TestInv()) as TestInv;
    con.companyList = [epic, other];
    con.pickerList = [picker];
    con.isInvoice.value = true;
  });
  tearDown(() {
    HttpClientHelper.testClient = null;
    Get.reset();
  });

  group('Smart tap on a recent invoice', () {
    testWidgets('still on this scanner: continue scanning it', (tester) async {
      await app(tester);
      await tester.runAsync(() async {
        await DBHelper.bulkInsert(tableName: DBHelper.docMaster, items: [masterRow('25032179')]);
        await con.openRecent(DocMaster(docNum: '25032179', stat: 'N', company: 'EPIC01'));
      });
      await tester.pumpAndSettle();
      expect(con.calls, ['scan']);
      expect(find.text('SYNC PAGE'), findsNothing);
    });

    testWidgets('replaced by a newer sync: Sync page with number, company and picker filled', (tester) async {
      await app(tester);
      await tester.runAsync(() async {
        await DBHelper.bulkInsert(tableName: DBHelper.docMaster, items: [masterRow('99999999')]);
        await con.openRecent(
            DocMaster(docNum: '25032179', stat: 'N', company: 'OTHR01', pickedBy: 'EX0085'));
      });
      await tester.pumpAndSettle();
      expect(find.text('SYNC PAGE'), findsOneWidget);
      expect(con.calls, isEmpty);
      expect(con.invController.text, '25032179');
      expect(con.selectedCompany.value?.companyId, 'OTHR01');
      expect(con.selectedPicker.value?.id, 'EX0085');
      expect(con.pickerController.text, 'Rashid K.');
    });

    testWidgets('older entry without company/picker: number filled, rest left to choose', (tester) async {
      await app(tester);
      con.selectedCompany.value = epic; // left over from an earlier sync
      con.selectedPicker.value = picker;
      await tester.runAsync(() => con.openRecent(DocMaster(docNum: '25030001', stat: 'N')));
      await tester.pumpAndSettle();
      expect(find.text('SYNC PAGE'), findsOneWidget);
      expect(con.invController.text, '25030001');
      expect(con.selectedCompany.value, isNull);
      expect(con.selectedPicker.value, isNull);
    });

    testWidgets('completed: nothing happens', (tester) async {
      await app(tester);
      await tester.runAsync(() => con.openRecent(DocMaster(docNum: '25032700', stat: 'Y')));
      await tester.pumpAndSettle();
      expect(find.text('HUB'), findsOneWidget);
      expect(con.calls, isEmpty);
    });
  });

  testWidgets('sync remembers company and picker in the recent list', (tester) async {
    GlobalConfiguration().loadFromMap({'api_base_url': 'https://api.test/api/'});
    HttpClientHelper.testClient = MockClient((req) async {
      if (req.url.path.endsWith('Sync_Document')) {
        return http.Response('"Document synchronized successfully."', 200);
      }
      if (req.url.path.endsWith('DocumentGetRecords')) {
        return http.Response(
            jsonEncode([
              {
                'Company': 'OTHR01', 'DocNum': '25032179', 'DocDate': '3/20/2025 12:00:00 AM',
                'CustNum': '1308', 'Stat': 'N', 'UserID': '', 'ScanTime': '1/1/0001 12:00:00 AM',
                'CustName': 'Kesariya', 'DocType': 'I', 'PickedBy': '',
                'DocDetails': [
                  {
                    'SlNo': 1, 'Company': 'OTHR01', 'DocNum': '25032179', 'PartNum': 'P1', 'ShipQty': 5,
                    'CheckQty': 0, 'Stat': 'N', 'Barcode': '6858475000001', 'PartName': 'Item',
                    'Brand': 'X', 'DocType': 'I', 'ReasonCode': '', 'ReasonName': '',
                    'ExpDate': '1/1/0001 12:00:00 AM'
                  }
                ]
              }
            ]),
            200);
      }
      return http.Response('not found', 404);
    });
    con.user.value = User(empID: 'MX1576');
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: Text('SYNC'))));
    await tester.runAsync(() async {
      con.invController.text = '25032179';
      con.selectComapny(other);
      con.selectPicker(picker);
      await con.syncInvoice(); // returns only after the invoice is saved (M5)
    });
    await tester.pumpAndSettle();
    final rows = await tester.runAsync(() => DBHelper.getAllItems(tableName: DBHelper.lastInvoices));
    expect(rows!.single[DBHelper.companyLastInvoices], 'OTHR01');
    expect(rows.single[DBHelper.pickedByLastInvoices], 'EX0085');
    expect(con.lastInvoices.single.company, 'OTHR01');
    expect(con.syncIsLoading.value, isFalse);
    expect(find.text('Success!!'), findsOneWidget);
    await tester.tap(find.text('Start scanning'));
    await tester.pumpAndSettle();
    expect(con.calls, ['scan'], reason: 'straight on to step 2');
    expect(con.currentDocNum.value, '25032179');
    expect((con.currentChecked.value, con.currentTotal.value), (0, 5));
  });

  test('phone database upgrade 2 → 3 keeps recent invoices and adds the columns', () async {
    await DBHelper.resetForTest();
    final path = p.join(dbDir, DBHelper.dbName);
    await databaseFactory.deleteDatabase(path);
    // A version-2 database as on the scanners today
    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, v) async {
            await db.execute('CREATE TABLE DocMaster(Company TEXT NOT NULL, DocNum TEXT NOT NULL, '
                'DocType TEXT NOT NULL, DocDate TEXT NOT NULL, CustNum TEXT NOT NULL, CustName TEXT NOT NULL, '
                'Stat TEXT NOT NULL, UserID TEXT NOT NULL, ScanTime TEXT NOT NULL, PickedBy TEXT NULL, '
                'PRIMARY KEY (Company,DocNum,DocType))');
            await db.execute('CREATE TABLE LastInvoices(UserID TEXT NOT NULL, DocNum TEXT NOT NULL, '
                'DocType TEXT NOT NULL, Stat TEXT NOT NULL, PRIMARY KEY (UserID,DocNum))');
            await db.insert('LastInvoices', {'UserID': 'MX1576', 'DocNum': '25030001', 'DocType': 'I', 'Stat': 'N'});
          },
        ));
    await old.close();

    final columns = await DBHelper.listColumnsInTable(DBHelper.lastInvoices);
    expect(columns, containsAll(['Company', 'PickedBy']));
    final rows = await DBHelper.getAllItems(tableName: DBHelper.lastInvoices);
    expect(rows.single['DocNum'], '25030001');
    expect(rows.single['Company'], isNull);
    expect(await (await DBHelper.db).getVersion(), 3);
    await DBHelper.resetForTest();
    await databaseFactory.deleteDatabase(path);
  });

  group('M4: same part on several lines (like invoice 23014637)', () {
    // Part X on lines 5, 22 and 40 (3 + 9 + 3 = 15), part Y on line 3 (2)
    Map<String, dynamic> line(int slNo, String barcode, int ship) => {
          DBHelper.companyDocDetail: 'EPIC01', DBHelper.docNumDocDetail: '23014637',
          DBHelper.docTypeDocDetail: 'I', DBHelper.slNoDocDetail: slNo,
          DBHelper.barcodeDocDetail: barcode, DBHelper.partNumDocDetail: 'P-$barcode',
          DBHelper.partNameDocDetail: 'Part $barcode', DBHelper.brandDocDetail: 'X',
          DBHelper.shipQtyDocDetail: ship, DBHelper.checkQtyDocDetail: 0, DBHelper.statDocDetail: 'N',
          DBHelper.reasonCodeDocDetail: '', DBHelper.reasonNameDocDetail: '', DBHelper.expiryDateDocDetail: null,
        };

    Future<List<Map<String, dynamic>>> rows() =>
        DBHelper.getItemsByQuery(tableName: DBHelper.docDetail, where: 'DocNum = ?', whereArgs: ['23014637']);

    Future<bool> scan(WidgetTester tester, String barcode, int qty) async {
      late bool ok;
      await tester.runAsync(() async {
        con.scrollToBarcode(barcode);
        con.qtyController.text = '$qty';
        ok = await con.saveQty();
      });
      await tester.pump(const Duration(milliseconds: 500));
      return ok;
    }

    Future<void> load(WidgetTester tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: Text('SCAN'))));
      await tester.runAsync(() async {
        await DBHelper.bulkInsert(tableName: DBHelper.docMaster, items: [masterRow('23014637')]);
        await DBHelper.bulkInsert(
            tableName: DBHelper.docDetail,
            items: [line(3, 'Y', 2), line(5, 'X', 3), line(22, 'X', 9), line(40, 'X', 3)]);
        con.docMaster.value = DocMaster(
            company: 'EPIC01', docNum: '23014637', docType: 'I',
            docDetails: (await rows()).map(DocDetail.fromJson).toList());
      });
    }

    Future<Map<int, int>> checked(WidgetTester tester) async => {
          for (final r in (await tester.runAsync(rows))!)
            r[DBHelper.slNoDocDetail] as int: r[DBHelper.checkQtyDocDetail] as int
        };

    testWidgets('fills the lines in order; no line is ever removed', (tester) async {
      await load(tester);
      expect(await scan(tester, 'X', 5), isTrue); // 3 to line 5, 2 to line 22
      expect(await checked(tester), {3: 0, 5: 3, 22: 2, 40: 0}, reason: 'all 4 lines still there');

      await tester.runAsync(() async => con.scrollToBarcode('X'));
      expect(con.scannedItem.value.slNo, 22, reason: 'next scan points at the first open line');

      expect(await scan(tester, 'X', 10), isTrue); // 7 to line 22, 3 to line 40
      expect(await checked(tester), {3: 0, 5: 3, 22: 9, 40: 3});
      expect(con.isFinalize.value, isFalse, reason: 'part Y not scanned yet');

      expect(await scan(tester, 'Y', 2), isTrue);
      expect(con.isFinalize.value, isTrue, reason: 'all 15 + 2 units checked');
      final memory = {for (final d in con.docMaster.value.docDetails!) d.slNo!: d.checkQty};
      expect(memory, {3: 2, 5: 3, 22: 9, 40: 3}, reason: 'screen matches the phone database');
      Get.closeAllSnackbars();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('more than what is open over all lines: refused, nothing changes', (tester) async {
      await load(tester);
      expect(await scan(tester, 'X', 3), isTrue);
      expect(await scan(tester, 'X', 13), isFalse); // 12 open (line 22: 9, line 40: 3)
      expect(find.text('Quantity Exceeded'), findsOneWidget);
      expect(find.textContaining('(16) exceeds the shipped quantity (15 over 3 lines)'), findsOneWidget);
      expect(await checked(tester), {3: 0, 5: 3, 22: 0, 40: 0});
      Get.back();
      await tester.pumpAndSettle();
      Get.closeAllSnackbars();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('all lines full: "Already Completed" names the total', (tester) async {
      await load(tester);
      expect(await scan(tester, 'X', 15), isTrue);
      expect(await scan(tester, 'X', 1), isFalse);
      expect(find.text('Already Completed'), findsOneWidget);
      expect(find.textContaining('shipping quantity (15 over 3 lines)'), findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();
      Get.closeAllSnackbars();
      await tester.pump(const Duration(seconds: 5));
    });

    test('fillInOrder / openQty', () {
      DocDetail d(int sl, int ship, int check) => DocDetail(slNo: sl, shipQty: ship, checkQty: check);
      final lines = [d(5, 3, 3), d(22, 9, 1), d(40, 3, 0)];
      expect(InvoiceOrTransferController.openQty(lines), 11);
      final changed = InvoiceOrTransferController.fillInOrder(lines, 9);
      expect(changed.map((l) => l.slNo), [22, 40]);
      expect(lines.map((l) => l.checkQty), [3, 9, 1]);
      expect(InvoiceOrTransferController.openQty(lines), 2);
    });
  });
}
