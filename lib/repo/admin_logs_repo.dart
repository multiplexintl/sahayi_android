import 'dart:convert';

import 'package:global_configuration/global_configuration.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../helper/http_client_helper.dart';
import '../model/log_filter.dart';
import '../model/server_log.dart';
import '../service/admin_service.dart';

/// A problem talking to the admin log endpoints, with a message for the user.
class AdminLogsException implements Exception {
  final String message;
  final bool loginProblem; // 401 / 429: admin must log in again
  const AdminLogsException(this.message, {this.loginProblem = false});
  @override
  String toString() => message;
}

/// Admin-only log endpoints on the server (/api/v2/Logs...).
class AdminLogsRepo {
  final Future<http.Client> Function() _client;
  final String? _baseUrl;
  final Map<String, String> Function() _headers;

  AdminLogsRepo({
    Future<http.Client> Function()? client,
    String? baseUrl,
    Map<String, String> Function()? headers,
  })  : _client = client ?? (() => HttpClientHelper().getClient()),
        _baseUrl = baseUrl,
        _headers = headers ?? (() => AdminService.current?.headers ?? const {});

  static final _date = DateFormat("yyyy-MM-ddTHH:mm:ss");

  String get _base => _baseUrl ?? GlobalConfiguration().getValue('api_base_url');

  Uri _uri(String path, Map<String, String?> query) => Uri.parse('$_base$path').replace(
      queryParameters: {
        for (final e in query.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
      });

  Future<dynamic> _send(String method, Uri uri) async {
    final client = await _client();
    final http.Response res;
    try {
      res = method == 'DELETE'
          ? await client.delete(uri, headers: _headers())
          : await client.get(uri, headers: _headers());
    } catch (e) {
      throw AdminLogsException('Could not reach the server. Check the connection. ($e)');
    }
    if (res.statusCode == 200) return jsonDecode(res.body);
    if (res.statusCode == 401) {
      throw const AdminLogsException('Admin login not accepted. Close the dashboard and log in again.',
          loginProblem: true);
    }
    if (res.statusCode == 429) {
      throw const AdminLogsException('Too many wrong attempts. Try again in 15 minutes.',
          loginProblem: true);
    }
    String detail = '';
    try {
      detail = (jsonDecode(res.body) as Map)['Message']?.toString() ?? '';
    } catch (_) {}
    throw AdminLogsException('Server error (HTTP ${res.statusCode}) $detail'.trim());
  }

  /// Logs newest first. [beforeLogId] = smallest LogID of the previous page.
  Future<List<ServerLog>> search(
    LogFilter f, {
    String? text,
    String? deviceId,
    int? beforeLogId,
    int top = 100,
  }) async {
    final json = await _send(
        'GET',
        _uri('v2/Logs', {
          'fromDate': f.from == null ? null : _date.format(f.from!),
          'toDate': f.toExclusive == null ? null : _date.format(f.toExclusive!),
          'levels': f.levels.join(','),
          'actions': f.actions.join(','),
          'screen': f.screen,
          'userId': f.userId,
          'docType': f.docType,
          'deviceId': deviceId,
          'text': text?.trim(),
          'beforeLogId': beforeLogId?.toString(),
          'top': '$top',
        })) as List;
    return json.map((j) => ServerLog.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<ServerLogSummary> summary({DateTime? from, DateTime? toExclusive}) async {
    final json = await _send(
        'GET',
        _uri('v2/Logs/Summary', {
          'fromDate': from == null ? null : _date.format(from),
          'toDate': toExclusive == null ? null : _date.format(toExclusive),
        }));
    return ServerLogSummary.fromJson(json as Map<String, dynamic>);
  }

  /// Values + counts for a filter list (Action, Screen, UserID, DeviceID, DocType).
  Future<List<({String value, int count})>> values(String column) async {
    final json = await _send('GET', _uri('v2/Logs/Values', {'column': column})) as List;
    return json
        .map((j) => (value: j['Value'] as String, count: (j['Count'] as num).toInt()))
        .toList();
  }

  /// Clear logs on the server. Returns how many rows were deleted.
  /// Give [deviceId] and/or [beforeDate], or [all] = true for everything.
  Future<int> delete({String? deviceId, DateTime? beforeDate, bool all = false}) async {
    final json = await _send(
        'DELETE',
        _uri('v2/Logs', {
          'deviceId': deviceId,
          'beforeDate': beforeDate == null ? null : _date.format(beforeDate),
          'confirmAll': all ? 'DELETE ALL' : null,
        }));
    return ((json as Map)['Deleted'] as num).toInt();
  }
}
