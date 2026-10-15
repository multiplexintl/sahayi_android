import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';
import 'package:sahayi_android/model/return/customer.dart';
import 'package:sahayi_android/model/return/reasons.dart';
import 'package:sahayi_android/model/user.dart';
import 'package:sahayi_android/view/Return/customer_select.dart';
import 'package:sahayi_android/view/Return/finalize.dart';
import 'package:sahayi_android/view/Return/scan_returns.dart';

class TestHome extends HomeController {
  @override
  // ignore: must_call_super
  void onInit() => user.value = User(empID: 'MX1576', empName: 'Amjadh');
}

/// Real ReturnController; network/database actions replaced by recorders.
class TestReturn extends ReturnController {
  final calls = <String>[];
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> onSubmit(DocMaster? item) async => calls.add('onSubmit(${item?.docNum})');
  @override
  Future<bool> removeUnfinished(DocMaster item) async {
    calls.add('removeUnfinished(${item.docNum})');
    return true;
  }
  @override
  Future<List<Customer>> getSuggestions(String query) async {
    calls.add('getSuggestions($query)');
    return [Customer(custId: '2236', custName: 'Lulu Barsha')];
  }
  @override
  void onSavePart() async => calls.add('onSavePart');
  @override
  void clearPart() => calls.add('clearPart');
  @override
  Future<void> onDeleteItem(int slNo) async => calls.add('onDeleteItem($slNo)');
  @override
  void clearAll() async => calls.add('clearAll');
  @override
  void onConfirm() async => calls.add('onConfirm');
  @override
  Future<bool> finalize() async {
    calls.add('finalize');
    return true;
  }
  @override
  void getUnfinishedDocs() async => calls.add('getUnfinishedDocs');
}

DocDetail line(int sl, String reason, {String? exp}) => DocDetail(
    slNo: sl,
    barcode: '68584750000$sl',
    partName: 'Jo Returned item $sl with a long descriptive product name 1 KG',
    checkQty: sl * 2,
    reasonCode: reason,
    reasonName: 'Reason $reason',
    expiryDate: exp);

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
  late TestReturn con;

  setUp(() {
    Get.testMode = true;
    Get.put<HomeController>(TestHome());
    con = Get.put<ReturnController>(TestReturn()) as TestReturn;
    con.companyList = [Company(companyId: 'EPIC01', companyName: 'EPIC Trading')];
    con.driverList.assignAll([Pickers(id: 'D1', name: 'Rashid K.', type: 'Driver')]);
    con.reasons.assignAll([Reasons(reasonId: 'DMG', reason: 'Damaged'), Reasons(reasonId: 'EXP', reason: 'Expired')]);
    con.unFinishedDocs.assignAll([
      DocMaster(custID: '3011', custName: 'Carrefour Mirdif', docNum: '2025-36825'),
      DocMaster(custID: '2240', custName: 'Lulu Al Qusais', docNum: '2025-36901'),
    ]);
    con.selectedCustomer.value = Customer(custId: '2236', custName: 'Lulu Barsha');
    con.docNumber.value = '2025-37088';
    con.docDate.value = '15-10-2026';
    con.driver.value = Pickers(id: 'D1', name: 'Rashid K.');
    con.savedItems.assignAll([line(1, 'DMG'), line(2, 'EXP', exp: '2027-01-31'), line(3, 'DMG')]);
    con.consolidatedSavedItems.assignAll([line(1, 'DMG'), line(2, 'EXP', exp: '2027-01-31')]);
    con.totalQty.value = 12;
  });
  tearDown(Get.reset);

  group('Return start', () {
    for (final font in [1.0, 1.3]) {
      testWidgets('fits 360x640 with unfinished returns (font x$font)', (tester) async {
        eda52(tester, font);
        await tester.pumpWidget(const GetMaterialApp(home: CustomerSelectScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Resume'), findsNWidgets(2));
      });
    }

    testWidgets('Start, Resume and Delete call the same actions', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: CustomerSelectScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start return'));
      await tester.ensureVisible(find.text('Resume').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume').first);
      await tester.tap(find.byTooltip('Delete unfinished return').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(con.calls, ['onSubmit(null)', 'onSubmit(2025-36825)', 'removeUnfinished(2025-36901)']);
    });

    testWidgets('customer search: type, results from the server, pick fills the field', (tester) async {
      eda52(tester, 1.0);
      con.selectedCompany.value = con.companyList.first;
      await tester.pumpWidget(const GetMaterialApp(home: CustomerSelectScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search customer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'lulu');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lulu Barsha'));
      await tester.pumpAndSettle();
      expect(con.calls, contains('getSuggestions(lulu)'));
      expect(con.custController.text, '2236 - Lulu Barsha');
    });

    testWidgets('no unfinished returns → friendly empty state', (tester) async {
      eda52(tester, 1.0);
      con.unFinishedDocs.clear();
      await tester.pumpWidget(const GetMaterialApp(home: CustomerSelectScreen()));
      await tester.pumpAndSettle();
      expect(find.text('All caught up'), findsOneWidget);
    });
  });

  group('Scan returns', () {
    for (final font in [1.0, 1.3]) {
      testWidgets('fits 360x640 with items (font x$font)', (tester) async {
        eda52(tester, font);
        await tester.pumpWidget(const GetMaterialApp(home: ScanReturns()));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('two different buttons: "Clear fields" vs "Delete all" (with confirm)', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: ScanReturns()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear fields'));
      expect(con.calls, ['clearPart']);

      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all items?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(con.calls, ['clearPart']); // cancelled: nothing deleted

      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete all').last);
      await tester.pumpAndSettle();
      expect(con.calls, ['clearPart', 'clearAll']);
    });

    testWidgets('Save item, delete one item (after confirm), Review & confirm', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: ScanReturns()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete item').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review & confirm'));
      expect(con.calls, ['onSavePart', 'onDeleteItem(1)', 'onConfirm']);
    });

    testWidgets('expiry date appears only for NRE / EXP reasons', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: ScanReturns()));
      await tester.pumpAndSettle();
      expect(find.text('Expiry date'), findsNothing);
      con.selectedReason.value = con.reasons.last; // EXP
      con.update();
      await tester.pumpAndSettle();
      expect(find.text('Expiry date'), findsOneWidget);
    });
  });

  group('Finalize return', () {
    for (final font in [1.0, 1.3]) {
      testWidgets('fits 360x640 (font x$font)', (tester) async {
        eda52(tester, font);
        await tester.pumpWidget(const GetMaterialApp(home: FinalizeReturnScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('12'), findsOneWidget); // total quantity
      });
    }

    testWidgets('Finalize → success → Done refreshes unfinished list and goes back 3 screens', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(GetMaterialApp(home: const Scaffold(body: Text('RETURN START'))));
      Get.to(() => const Scaffold(body: Text('SCAN')));
      await tester.pumpAndSettle();
      Get.to(() => const FinalizeReturnScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finalize'));
      await tester.pumpAndSettle();
      expect(find.text('Return finalized'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(con.calls, ['finalize', 'getUnfinishedDocs']);
      expect(find.text('RETURN START'), findsOneWidget);
    });

    testWidgets('item details show entries and total', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: FinalizeReturnScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).at(1)); // first item card
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);
    });
  });
}
