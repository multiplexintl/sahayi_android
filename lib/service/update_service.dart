import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkName;
  final String notes;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkName,
    required this.notes,
  });

  String get apkUrl =>
      'https://github.com/multiplexintl/sahayi_android/releases/latest/download/$apkName';

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final versionName = json['versionName'] as String;
    return UpdateInfo(
      versionCode: json['versionCode'] as int,
      versionName: versionName,
      apkName: json['apkName'] as String? ?? 'sahayi_v$versionName.apk',
      notes: json['notes'] as String? ?? '',
    );
  }
}

class UpdateService {
  static const String _versionJsonUrl =
      'https://github.com/multiplexintl/sahayi_android/releases/latest/download/version.json';

  /// Returns [UpdateInfo] if an update is available, null otherwise.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      log('Current versionCode: $currentVersionCode');

      final response = await http
          .get(Uri.parse(_versionJsonUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        log('version.json fetch failed: ${response.statusCode}');
        return null;
      }

      final updateInfo = UpdateInfo.fromJson(jsonDecode(response.body));
      log('Remote versionCode: ${updateInfo.versionCode}');

      if (updateInfo.versionCode > currentVersionCode) {
        return updateInfo;
      }
      return null;
    } catch (e) {
      log('Update check error: $e');
      return null;
    }
  }

  /// Downloads the APK and reports progress via [onProgress] (0.0 – 1.0).
  /// Returns the [File] path on success, throws on failure.
  Future<File> downloadApk({
    required UpdateInfo updateInfo,
    required void Function(double progress) onProgress,
  }) async {
    final dir = await getExternalStorageDirectory();
    final filePath = '${dir!.path}/sahayi_update.apk';
    final file = File(filePath);

    // Clean up any previous partial download
    if (await file.exists()) {
      await file.delete();
    }

    final request = http.Request('GET', Uri.parse(updateInfo.apkUrl));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('APK download failed: HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      }
    }
    await sink.flush();
    await sink.close();

    log('APK downloaded to: $filePath');
    return file;
  }
}
