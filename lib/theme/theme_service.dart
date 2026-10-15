import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow-the-system choice, remembered on the device.
/// Default: follow the scanner's system setting.
class ThemeService extends GetxController {
  static const _key = 'themeMode'; // 'system' | 'light' | 'dark'

  final mode = ThemeMode.system.obs;

  static ThemeService get to => Get.find<ThemeService>();

  /// Reads the saved choice before the first frame (no light/dark flash).
  static Future<ThemeService> init() async {
    final service = Get.put(ThemeService(), permanent: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      service.mode.value = parse(prefs.getString(_key));
    } catch (_) {
      // Keep "system" if the setting cannot be read.
    }
    return service;
  }

  static ThemeMode parse(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    Get.changeThemeMode(m);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, m.name);
  }

  /// Light <-> dark (from "system", flips to the opposite of what is showing).
  Future<void> toggle(BuildContext context) => setMode(
      Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}
