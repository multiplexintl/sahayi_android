import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow-the-system choice, remembered on the device.
/// Default: follow the scanner's system setting.
class ThemeService extends GetxController {
  static const _key = 'themeMode'; // 'system' | 'light' | 'dark'

  final mode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = switch (prefs.getString(_key)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, m.name);
  }

  /// Light <-> dark (from "system", flips to the opposite of what is showing).
  Future<void> toggle(BuildContext context) => setMode(
      Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}
