import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/view/Report/detailed_report.dart';
import 'package:sahayi_android/view/Return/finalize.dart';
import 'package:sahayi_android/view/Return/scan_returns.dart';
import 'package:sahayi_android/view/Invoice_Transfer/invoice.dart';
import 'package:sahayi_android/view/Return/customer_select.dart';
import 'package:sahayi_android/view/home.dart';
import 'package:sahayi_android/view/Report/report.dart';
import 'package:sahayi_android/view/Invoice_Transfer/sync_invoice.dart';

import 'view/login.dart';
import 'view/Invoice_Transfer/scan_invoice.dart';
import 'view/splash.dart';

class RouteGenerator {
  // Common transition settings
  static const Transition _transition = Transition.cupertino;
  static const Curve _curve = Curves.easeIn;
  static const Duration _duration = Duration(milliseconds: 1000);
  static const bool _fullscreenDialog = false;
  static const bool _popGesture = false;

  // Helper function to create GetPage
  static GetPage _createPage(String route, Widget Function() page) {
    return GetPage(
      name: route,
      page: page,
      transition: _transition,
      curve: _curve,
      fullscreenDialog: _fullscreenDialog,
      popGesture: _popGesture,
      transitionDuration: _duration,
    );
  }

  // List of app routes
  static final list = [
    _createPage(RouteLinks.splash, () => const SplashScreen()),
    _createPage(RouteLinks.login, () => const LoginScreen()),
    _createPage(RouteLinks.home, () => const HomeScreen()),
    _createPage(RouteLinks.invoiceTransfer, () => const InvoiveTransferSceen()),
    _createPage(RouteLinks.syncInvoice, () => const SyncInvoiceScreen()),
    _createPage(RouteLinks.scanInvoice, () => const ScanInvoiceScreen()),
    _createPage(RouteLinks.invoiceReport, () => const ReportViewPage()),
    _createPage(RouteLinks.detailedReport, () => const DetailedReportPage()),
    _createPage(RouteLinks.customerSelect, () => const CustomerSelectScreen()),
    _createPage(RouteLinks.scanReturns, () => const ScanReturns()),
    _createPage(RouteLinks.finlaizeReturns, () => const FinalizeReturnScreen()),
  ];
}

// Route Names (Centralized)
class RouteLinks {
  static const String splash = "/splash";
  static const String login = "/login";
  static const String home = "/home";
  static const String invoiceTransfer = "/invoice-transfer";
  static const String syncInvoice = "/sync-invoice";
  static const String scanInvoice = "/scan-invoice";
  static const String invoiceReport = "/invoice-report";
  static const String detailedReport = "/report-detailed";
  static const String customerSelect = "/customer-select";
  static const String scanReturns = "/scan-returns";
  static const String finlaizeReturns = "/finalize-returns";
}


//0555474129