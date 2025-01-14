import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/view/home.dart';
import 'package:sahayi_android/view/report.dart';
import 'package:sahayi_android/view/sync_invoice.dart';

import 'view/login.dart';
import 'view/scan_invoice.dart';
import 'view/splash.dart';

class RouteGenerator {
  static var list = [
    GetPage(
      name: RouteLinks.splash,
      page: () => const SplashScreen(),
      transition: Transition.native,
      curve: Curves.easeIn,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: RouteLinks.login,
      page: () => const LoginScreen(),
      transition: Transition.native,
      curve: Curves.easeIn,
      fullscreenDialog: true,
      popGesture: false,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: RouteLinks.home,
      page: () => const HomeScreen(),
      transition: Transition.native,
      curve: Curves.easeIn,
      fullscreenDialog: true,
      popGesture: false,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: RouteLinks.syncInvoice,
      page: () => const SyncInvoiceScreen(),
      transition: Transition.native,
      curve: Curves.easeIn,
      fullscreenDialog: true,
      popGesture: false,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: RouteLinks.scanInvoice,
      page: () => const ScanInvoiceScreen(),
      transition: Transition.native,
      curve: Curves.easeIn,
      fullscreenDialog: true,
      popGesture: false,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: RouteLinks.invoiceReport,
      page: () => const ReportViewPage(),
      transition: Transition.native,
      curve: Curves.easeIn,
      fullscreenDialog: true,
      popGesture: false,
      transitionDuration: const Duration(milliseconds: 500),
    ),
  ];
}

class RouteLinks {
  static const String splash = "/Splash";
  static const String login = "/Login";
  static const String home = "/Home";
  static const String syncInvoice = "/SyncInvoice";
  static const String scanInvoice = "/ScanInvoice";
  static const String invoiceReport = "/InvoiceReport";
}
