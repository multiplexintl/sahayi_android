import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:global_configuration/global_configuration.dart';

import 'controller/splash_controller.dart';
import 'routes.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // Ensure proper handshake without skipping cert validation
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // Keep default behavior: only allow valid certs
      return false;
    };

    client.connectionTimeout = Duration(seconds: 10);

    return client;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await GlobalConfiguration().loadFromAsset("config");
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((value) => runApp(const MyApp()));
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
    );
  }
}
