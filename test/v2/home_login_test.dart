import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sahayi_android/controller/connectivity_controller.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/controller/login_controller.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/model/user.dart';
import 'package:sahayi_android/routes.dart';
import 'package:sahayi_android/view/home.dart';
import 'package:sahayi_android/view/login.dart';
import 'package:sahayi_android/view/splash.dart';

// Real controllers minus their start-up network / platform work.
class TestHome extends HomeController {
  bool loggedOut = false;
  @override
  // ignore: must_call_super
  void onInit() {
    user.value = User(empID: 'MX1576', empName: 'Amjadh Changanakattil');
    version.value = '1.0.16';
    buildNumber.value = '16';
  }

  @override
  void logOut() async => loggedOut = true;
}

class TestReturn extends ReturnController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class TestInv extends InvoiceOrTransferController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> getLastInvoices({String? docType}) async {}
}

class TestConn extends ConnectivityController {
  @override
  // ignore: must_call_super
  void onInit() => isInternetConnected.value = true;
}

class TestLogin extends LoginController {
  int calls = 0;
  @override
  void getEmployee() async => calls++;
}

void eda52(WidgetTester tester, double font, {double keyboard = 0}) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
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
  setUp(() {
    Get.testMode = true;
    PackageInfo.setMockInitialValues(
        appName: 'Sahayi', packageName: 'x', version: '1.0.16', buildNumber: '16', buildSignature: '');
  });
  tearDown(Get.reset);

  group('Home', () {
    late TestHome home;
    setUp(() {
      Get.put<ConnectivityController>(TestConn());
      home = Get.put<HomeController>(TestHome()) as TestHome;
      Get.put<ReturnController>(TestReturn());
      Get.put<InvoiceOrTransferController>(TestInv());
    });

    for (final font in [1.0, 1.3]) {
      testWidgets('fits 360x640, greeting, 4 cards, online chip (font x$font)', (tester) async {
        eda52(tester, font);
        await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Amjadh Changanakattil'), findsOneWidget);
        expect(find.text('AC'), findsOneWidget);
        expect(find.text('Online'), findsOneWidget);
        for (final card in ['Invoice', 'Transfer', 'Return', 'Report']) {
          expect(find.text(card), findsOneWidget);
        }
        expect(find.text('Sahayi · v1.0.16 (16)'), findsOneWidget);
      });
    }

    testWidgets('cards open the same screens as before', (tester) async {
      eda52(tester, 1.0);
      final opened = <String>[];
      await tester.pumpWidget(GetMaterialApp(
        home: const HomeScreen(),
        getPages: [
          for (final r in [RouteLinks.invoiceTransfer, RouteLinks.customerSelect, RouteLinks.invoiceReport])
            GetPage(name: r, page: () {
              opened.add(r);
              return const Scaffold();
            }),
        ],
      ));
      await tester.pumpAndSettle();
      for (final card in ['Invoice', 'Return', 'Report']) {
        await tester.tap(find.text(card));
        await tester.pumpAndSettle();
        Get.back();
        await tester.pumpAndSettle();
      }
      expect(opened, [RouteLinks.invoiceTransfer, RouteLinks.customerSelect, RouteLinks.invoiceReport]);
      expect(Get.find<InvoiceOrTransferController>().isInvoice.value, isTrue);
    });

    testWidgets('log out asks first; Cancel keeps you in, Log out logs out', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(home.loggedOut, isFalse);

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Log out'));
      await tester.pumpAndSettle();
      expect(home.loggedOut, isTrue);
    });

    test('greeting by time of day', () {
      expect(HomeScreen.greeting(DateTime(2026, 1, 1, 9)), 'Good morning');
      expect(HomeScreen.greeting(DateTime(2026, 1, 1, 14)), 'Good afternoon');
      expect(HomeScreen.greeting(DateTime(2026, 1, 1, 20)), 'Good evening');
    });
  });

  group('Login', () {
    late TestLogin login;
    setUp(() => login = Get.put<LoginController>(TestLogin()) as TestLogin);

    for (final keyboard in [0.0, 300.0]) {
      for (final font in [1.0, 1.3]) {
        testWidgets('fits 360x640 (keyboard ${keyboard.toInt()}, font x$font)', (tester) async {
          eda52(tester, font, keyboard: keyboard);
          await tester.pumpWidget(const GetMaterialApp(home: LoginScreen()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('ID is upper-cased, Log in calls getEmployee()', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'mx1576');
      expect(login.idController.text, 'MX1576');
      await tester.tap(find.text('Log in'));
      expect(login.calls, 1);
      expect(find.text('v1.0.16 (16)'), findsOneWidget);
    });

    testWidgets('password hidden by default; eye button shows it', (tester) async {
      eda52(tester, 1.0);
      await tester.pumpWidget(const GetMaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      EditableText pwd() => tester.widget<EditableText>(find.byType(EditableText).last);
      expect(pwd().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(pwd().obscureText, isFalse);
    });
  });

  testWidgets('Splash shows the brand', (tester) async {
    eda52(tester, 1.3);
    await tester.pumpWidget(const GetMaterialApp(home: SplashScreen()));
    await tester.pump();
    expect(find.text('Sahayi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
