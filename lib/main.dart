import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:global_configuration/global_configuration.dart';

import 'controller/splash_controller.dart';
import 'routes.dart';
import 'service/app_logger.dart';
import 'service/log_uploader.dart';
import 'theme/app_theme.dart';
import 'theme/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  _installErrorLogging();
  await GlobalConfiguration().loadFromAsset("config");
  await ThemeService.init(); 
  _startLogUpload();
  AppLogger.info('AppStart', 'App started',
      details: 'Device: ${AppLogger.deviceSummary}, '
          'API: ${GlobalConfiguration().getValue('api_base_url')}');

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((value) => runApp(const MyApp()));
}

/// Sends device logs to the API automatically (see LogUploader).
void _startLogUpload() {
  final db = AppLogger.db;
  if (db == null) return; // logger failed to start; nothing to upload
  AppLogger.onSaved = LogUploader.notify;
  LogUploader.start(
    apiBaseUrl: GlobalConfiguration().getValue('api_base_url'),
    db: db,
  );
}

/// Logs every error that escapes the app's own try/catch blocks.
void _installErrorLogging() {
  // Errors inside Flutter (building screens, layout, etc.)
  FlutterError.onError = (details) {
    AppLogger.error('FlutterError', details.exceptionAsString(),
        stack: details.stack, details: details.context?.toString());
    FlutterError.presentError(details);
  };

  // Any other uncaught error (async code, timers, plugins)
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('UncaughtError', error.toString(), stack: stack);
    return true; // handled: keep the app running, as before
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      builder: (context, child) {
        Get.put(SplashController());
        // Status bar icons readable on the light and the dark theme.
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: child!,
        );
      },
      title: 'Sahayi',
      initialRoute: RouteLinks.splash,
      getPages: RouteGenerator.list,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeService.to.mode.value,
      routingCallback: (routing) {
        // Track page changes only (not dialogs / bottom sheets).
        if (routing == null ||
            routing.isDialog == true ||
            routing.isBottomSheet == true) {
          return;
        }
        AppLogger.setScreen(routing.current);
        AppLogger.info('Navigate',
            '${routing.isBack == true ? 'Back' : 'Open'}: ${routing.previous} → ${routing.current}');
      },
    );
  }
}
