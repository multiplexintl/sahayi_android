import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:global_configuration/global_configuration.dart';

import 'controller/splash_controller.dart';
import 'routes.dart';
import 'service/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  _installErrorLogging();
  await GlobalConfiguration().loadFromAsset("config");
  AppLogger.info('AppStart', 'App started',
      details: 'Device: ${AppLogger.deviceSummary}, '
          'API: ${GlobalConfiguration().getValue('api_base_url')}');

  AppLogger.watchLifecycle();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((value) => runApp(const MyApp()));
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
        return child!;
      },
      title: 'Sahayi',
      initialRoute: RouteLinks.splash,
      getPages: RouteGenerator.list,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
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
