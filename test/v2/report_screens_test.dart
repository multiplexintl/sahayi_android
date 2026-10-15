import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/controller/report_controller.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/report/report.dart';
import 'package:sahayi_android/model/user.dart';
import 'package:sahayi_android/view/Report/detailed_report.dart';
import 'package:sahayi_android/view/Report/report.dart';

class TestHome extends HomeController {
  @override
  // ignore: must_call_super
  void onInit() => user.value = User(empID: 'MX1576', empName: 'Amjadh', company: 'EPIC01');
}

class TestInv extends InvoiceOrTransferController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

/// Real ReportController (its onInit sets the default dates and types);
/// only the server calls are replaced.
class TestReport extends ReportController {
  final calls = <String>[];
  @override
  Future<void> fetchReport() async {
    calls.add('fetchReport(${selectedType.value?.keys.first})');
    reports.assignAll([
      for (var i = 0; i < 8; i++)
        Report(
            company: 'EPIC Trading',
            docNum: '2503270$i',
            custId: '107$i',
            custName: 'Customer number $i with a long trading name LLC (COD)',
            scanTime: '14-10-2026 0$i:30 PM',
            docType: ['I', 'T', 'R'][i % 3]),
    ]);
    filteredReports.assignAll(reports);
  }

  @override
  Future<void> selectReport(Report report) async => calls.add('selectReport(${report.docNum})');
}

void eda52(WidgetTester tester, double font) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  tester.platformDispatcher.textScaleFactorTestValue = font;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final ch in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
  }
  late TestReport con;
  setUp(() {
    Get.testMode = true;
    Get.put<HomeController>(TestHome());
    Get.put<InvoiceOrTransferController>(TestInv());
    con = Get.put<ReportController>(TestReport()) as TestReport;
  });
  tearDown(Get.reset);

  group('Report', () {
    for (final font in [1.0, 1.3]) {
      testWidgets('fits 360x640 before and after results (font x$font)', (tester) async {
        eda52(tester, font);
        await tester.pumpWidget(const GetMaterialApp(home: ReportViewPage()));
        await tester.pumpAndSettle();
        expect(find.text('No report yet'), findsOneWidget);
        await tester.tap(find.text('Show report'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('defaults kept: last 7 days, type All; chips change the type', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: ReportViewPage()));
      await tester.pumpAndSettle();
      final f = DateFormat('dd-MM-yyyy');
      expect(con.fromDateController.value.text, f.format(DateTime.now().subtract(const Duration(days: 7))));
      expect(con.toDateController.value.text, f.format(DateTime.now()));
      await tester.tap(find.text('Return'));
      await tester.pump();
      await tester.tap(find.text('Show report'));
      await tester.pumpAndSettle();
      expect(con.calls, ['fetchReport(R)']);
    });

    testWidgets('local filter and opening a document', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: ReportViewPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show report'));
      await tester.pumpAndSettle();
      expect(find.text('8 of 8 documents'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Filter by document number'), '25032703');
      await tester.pumpAndSettle();
      expect(find.text('1 of 8 documents'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, '25032703'));
      expect(con.calls.last, 'selectReport(25032703)');
    });
  });

  group('Report details', () {
    setUp(() {
      con.isLoadingDetailed.value = false;
      con.detailedReport.value = DocMaster(
        company: 'EPIC Trading',
        docNum: '22362025-37088',
        docDate: '3/20/2025 12:00:00 AM',
        custID: '2236',
        custName: 'Lulu Barsha',
        scanTime: '2025-03-20T14:26:09',
        userId: 'MX1680',
        pickedBy: 'D1',
        stat: 'Y',
        docType: 'R',
        docDetails: [
          for (var i = 0; i < 6; i++)
            DocDetail(
                partNum: 'JOS0$i',
                partName: 'Returned item $i with a long product name',
                brand: 'JO',
                barcode: '685847500000$i',
                checkQty: i + 1,
                reasonCode: i.isEven ? 'EXP' : 'DMG',
                reasonName: i.isEven ? 'Expired' : 'Damaged',
                expiryDate: '2027-01-31',
                docType: 'R'),
        ],
      );
    });

    for (final font in [1.0, 1.3]) {
      testWidgets('fits 360x640 (font x$font)', (tester) async {
        eda52(tester, font);
        await tester.pumpWidget(const GetMaterialApp(home: DetailedReportPage()));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('summary, barcode search filters lines, line details', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: DetailedReportPage()));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Return report'), findsOneWidget);

      await tester.tap(find.byTooltip('Find a barcode'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '6858475000004');
      await tester.pumpAndSettle();
      expect(find.text('1 of 6'), findsOneWidget);

      await tester.tap(find.text('Returned item 4 with a long product name'));
      await tester.pumpAndSettle();
      expect(find.text('Expiry date'), findsOneWidget); // EXP reason on a return
    });
  });
}
