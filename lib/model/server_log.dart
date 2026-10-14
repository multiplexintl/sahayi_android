/// A log row from the server (GET /api/v2/Logs).
class ServerLog {
  final int logId;
  final DateTime loggedAt; // server time it was saved
  final DateTime? clientTime; // device time it happened
  final String? source; // APP or API
  final String? level;
  final String? userId;
  final String? company;
  final String? deviceId;
  final String? appVersion;
  final String? screen;
  final String action;
  final String? docNum;
  final String? docType;
  final String message;
  final String? details;

  const ServerLog({
    required this.logId,
    required this.loggedAt,
    this.clientTime,
    this.source,
    this.level,
    this.userId,
    this.company,
    this.deviceId,
    this.appVersion,
    this.screen,
    required this.action,
    this.docNum,
    this.docType,
    required this.message,
    this.details,
  });

  /// Time to show: when it happened on the device, else when the server saved it.
  DateTime get time => clientTime ?? loggedAt;

  factory ServerLog.fromJson(Map<String, dynamic> j) => ServerLog(
        logId: (j['LogID'] as num).toInt(),
        loggedAt: DateTime.parse(j['LoggedAt'] as String),
        clientTime: j['ClientTime'] == null ? null : DateTime.parse(j['ClientTime'] as String),
        source: j['Source'] as String?,
        level: j['Level'] as String?,
        userId: j['UserID'] as String?,
        company: j['Company'] as String?,
        deviceId: j['DeviceID'] as String?,
        appVersion: j['AppVersion'] as String?,
        screen: j['Screen'] as String?,
        action: (j['Action'] as String?) ?? '',
        docNum: j['DocNum'] as String?,
        docType: j['DocType'] as String?,
        message: (j['Message'] as String?) ?? '',
        details: j['Details'] as String?,
      );
}

/// GET /api/v2/Logs/Summary
class ServerLogSummary {
  final int total, errors, warnings, infos, devices;
  final DateTime? firstLog, lastLog;
  final List<ServerDevice> deviceList;

  const ServerLogSummary({
    required this.total,
    required this.errors,
    required this.warnings,
    required this.infos,
    required this.devices,
    this.firstLog,
    this.lastLog,
    this.deviceList = const [],
  });

  factory ServerLogSummary.fromJson(Map<String, dynamic> j) {
    final t = (j['Totals'] as Map<String, dynamic>?) ?? const {};
    DateTime? date(Object? v) => v == null ? null : DateTime.parse(v as String);
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return ServerLogSummary(
      total: n(t['Total']),
      errors: n(t['Errors']),
      warnings: n(t['Warnings']),
      infos: n(t['Infos']),
      devices: n(t['Devices']),
      firstLog: date(t['FirstLog']),
      lastLog: date(t['LastLog']),
      deviceList: ((j['Devices'] as List?) ?? const [])
          .map((d) => ServerDevice.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One scanner in the summary (DeviceID null = the API's own logs).
class ServerDevice {
  final String? deviceId;
  final String? lastUserId;
  final String? lastAppVersion;
  final DateTime lastSeen;
  final int total, errors, warnings;

  const ServerDevice({
    this.deviceId,
    this.lastUserId,
    this.lastAppVersion,
    required this.lastSeen,
    required this.total,
    required this.errors,
    required this.warnings,
  });

  factory ServerDevice.fromJson(Map<String, dynamic> j) => ServerDevice(
        deviceId: j['DeviceID'] as String?,
        lastUserId: j['LastUserID'] as String?,
        lastAppVersion: j['LastAppVersion'] as String?,
        lastSeen: DateTime.parse(j['LastSeen'] as String),
        total: (j['Total'] as num).toInt(),
        errors: (j['Errors'] as num).toInt(),
        warnings: (j['Warnings'] as num).toInt(),
      );
}
