/// One log entry. Fields match the server table dbo.AppLog so entries can be
/// uploaded to POST /api/v2/Logs later without conversion.
class AppLog {
  final int? localId;
  final DateTime clientTime;
  final String level; // INFO, WARN, ERROR
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
  final bool uploaded;

  const AppLog({
    this.localId,
    required this.clientTime,
    required this.level,
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
    this.uploaded = false,
  });

  // Same limits as dbo.AppLog, so the server never has to cut anything.
  static String? _cut(String? value, int max) =>
      value == null || value.length <= max ? value : value.substring(0, max);

  Map<String, dynamic> toDB() => {
        'ClientTime': clientTime.toIso8601String(),
        'Level': level,
        'UserID': _cut(userId, 10),
        'Company': _cut(company, 10),
        'DeviceID': _cut(deviceId, 100),
        'AppVersion': _cut(appVersion, 20),
        'Screen': _cut(screen, 100),
        'Action': _cut(action, 100)!,
        'DocNum': _cut(docNum, 100),
        'DocType': _cut(docType, 1),
        'Message': _cut(message, 1000)!,
        'Details': details,
        'Uploaded': uploaded ? 1 : 0,
      };

  factory AppLog.fromDB(Map<String, dynamic> row) => AppLog(
        localId: row['LocalID'] as int?,
        clientTime: DateTime.parse(row['ClientTime'] as String),
        level: row['Level'] as String,
        userId: row['UserID'] as String?,
        company: row['Company'] as String?,
        deviceId: row['DeviceID'] as String?,
        appVersion: row['AppVersion'] as String?,
        screen: row['Screen'] as String?,
        action: row['Action'] as String,
        docNum: row['DocNum'] as String?,
        docType: row['DocType'] as String?,
        message: row['Message'] as String,
        details: row['Details'] as String?,
        uploaded: (row['Uploaded'] as int? ?? 0) == 1,
      );

  /// Body format for POST /api/v2/Logs.
  Map<String, dynamic> toApiJson() => {
        'ClientTime': clientTime.toIso8601String(),
        'Source': 'APP',
        'Level': level,
        'UserID': userId,
        'Company': company,
        'DeviceID': deviceId,
        'AppVersion': appVersion,
        'Screen': screen,
        'Action': action,
        'DocNum': docNum,
        'DocType': docType,
        'Message': message,
        'Details': details,
      };

  @override
  String toString() =>
      'AppLog($localId, $clientTime, $level, $action, $message, screen: $screen, user: $userId)';
}
