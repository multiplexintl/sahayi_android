import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';
import 'package:sahayi_android/view/Invoice_Transfer/invoice.dart';
import 'package:sahayi_android/view/Invoice_Transfer/scan_invoice.dart';
import 'package:sahayi_android/view/Invoice_Transfer/sync_invoice.dart';
import 'test_app.dart';

/// Real controller, but without the network calls in onInit.
class TestController extends InvoiceOrTransferController {
  final calls = <String>[];
  @override
  // ignore: must_call_super
  void onInit() {} // skip getCompanies / getPickers / date
  @override
  void checkValidation() => calls.add('checkValidation');
  @override
  Future<void> clearInvoiceDB() async => calls.add('clearInvoiceDB');
  @override
  Future<void> finalize() async => calls.add('finalize');
  @override
  Future<void> getItemsThenToScanPage() async => calls.add('getItemsThenToScanPage');
  @override
  Future<void> openRecent(DocMaster doc) async => calls.add('openRecent ${doc.docNum}');
}

DocDetail item(int i, int check, int ship) => DocDetail(
      slNo: i,
      partNum: 'JOS04${i}0000',
      partName: 'Jo Item number $i with a fairly long product name 500 ML',
      barcode: '685847500000$i',
      shipQty: ship,
      checkQty: check,
    );

void eda52(WidgetTester tester, double font) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  tester.platformDispatcher.textScaleFactorTestValue = font;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() => bothThemes(_tests);

void _tests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The controller creates an AudioPlayer (wrong-barcode sound); no audio in tests.
  for (final ch in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
  }
  late TestController con;

  setUp(() {
    Get.testMode = true;
    con = Get.put<InvoiceOrTransferController>(TestController()) as TestController;
    con.docMaster.value = DocMaster(
      docNum: '25032700',
      docDate: '3/20/2025 12:00:00 AM',
      custName: 'Kesariya & Co LLC (COD)',
      docType: 'I',
      docDetails: [
        item(0, 1800, 1800),
        item(1, 600, 600),
        item(2, 0, 120),
        item(3, 40, 96),
        item(4, 0, 50),
        item(5, 0, 10),
      ],
    );
    con.companyList = [Company(companyId: 'EPIC01', companyName: 'EPIC Trading')];
    con.pickerList = [Pickers(id: 'EX0085', name: 'Rashid K.')];
  });
  tearDown(Get.reset);

  for (final font in [1.0, 1.3]) {
    testWidgets('Scan: fits 360x640, progress + reason on Finalize (font x$font)', (tester) async {
      eda52(tester, font);
      await tester.pumpWidget(testApp(home: ScanInvoiceScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2 of 6 items done'), findsOneWidget);
      expect(find.text('Finalize · 4 left'), findsOneWidget);
      expect(find.text('20/03/2025', findRichText: true), findsNothing); // part of subtitle
      expect(find.textContaining('Kesariya'), findsOneWidget);
    });
  }

  testWidgets('Scan: Save validates like before (empty barcode is refused)', (tester) async {
    eda52(tester, 1.0);
    await tester.pumpWidget(testApp(home: ScanInvoiceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Scan a barcode'), findsOneWidget);
    expect(find.text('Qty'), findsWidgets);
  });

  testWidgets('Scan: typing a barcode marks the item as scanning and scrolls to it', (tester) async {
    eda52(tester, 1.0);
    await tester.pumpWidget(testApp(home: ScanInvoiceScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '6858475000005'); // last item
    await tester.pumpAndSettle();
    expect(con.scannedItem.value.barcode, '6858475000005');
    expect(find.text('Scanning'), findsOneWidget);
    expect(con.scrollController.offset, greaterThan(0)); // scrolled down to it
    expect(tester.takeException(), isNull);
  });

  testWidgets('Scan: Finalize enabled only when all done, calls finalize()', (tester) async {
    eda52(tester, 1.0);
    con.isFinalize.value = true;
    await tester.pumpWidget(testApp(home: ScanInvoiceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalize'));
    expect(con.calls, contains('finalize'));
  });

  testWidgets('Hub: two steps, recent documents with status words', (tester) async {
    eda52(tester, 1.3);
    con.lastInvoices.assignAll([DocMaster(docNum: '25032700', stat: 'Y'), DocMaster(docNum: '25032179', stat: 'N')]);
    await tester.pumpWidget(testApp(home: InvoiveTransferSceen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sync invoice'), findsOneWidget);
    expect(find.text('Scan items'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Not completed'), findsOneWidget);
    await tester.tap(find.text('Scan items'));
    expect(con.calls, contains('getItemsThenToScanPage'));
  });

  testWidgets('Hub: tapping an unfinished recent document opens it; completed ones do nothing',
      (tester) async {
    eda52(tester, 1.0);
    con.lastInvoices.assignAll([DocMaster(docNum: '25032700', stat: 'Y'), DocMaster(docNum: '25032179', stat: 'N')]);
    await tester.pumpWidget(testApp(home: InvoiveTransferSceen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25032700'));
    await tester.tap(find.text('25032179'));
    expect(con.calls, ['openRecent 25032179']);
    Finder arrowIn(String docNum) => find.descendant(
        of: find.ancestor(of: find.text(docNum), matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.chevron_right_rounded));
    expect(arrowIn('25032179'), findsOneWidget);
    expect(arrowIn('25032700'), findsNothing);
  });

  for (final font in [1.0, 1.3]) {
    testWidgets('Sync: fits, picks company, sync and delete call the same actions (font x$font)',
        (tester) async {
      eda52(tester, font);
      await tester.pumpWidget(testApp(home: SyncInvoiceScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Select company'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EPIC Trading'));
      await tester.pumpAndSettle();
      expect(con.selectedCompany.value?.companyId, 'EPIC01');

      await tester.tap(find.text('Sync invoice from server'));
      await tester.ensureVisible(find.text('Delete local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete local data'));
      expect(con.calls, containsAll(['checkValidation', 'clearInvoiceDB']));
    });
  }
}
