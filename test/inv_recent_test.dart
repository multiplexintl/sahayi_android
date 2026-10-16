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
}
