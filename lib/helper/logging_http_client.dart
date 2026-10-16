import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../service/app_logger.dart';

/// Wraps an [http.Client] and logs requests: URL (passwords masked), status
/// code and duration.
/// - Success: only a "recent step" in memory, not saved, unless it took
///   longer than [slowAfter] (saved as WARN "SlowResponse").
/// - 4xx (WARN) / 5xx (ERROR) / no response (ERROR "HttpFailed"): saved with
///   the data sent and the server's answer (each capped at [maxBody]).
/// Responses and errors are passed through unchanged.
class LoggingClient extends http.BaseClient {
  final http.Client _inner;
  LoggingClient(this._inner);

  static final _secretParams = RegExp(r'(pwd|password)=[^&]*', caseSensitive: false);
  static final _secretJson =
      RegExp(r'("(?:pwd|password)"\s*:\s*)"[^"]*"', caseSensitive: false);

  static Duration slowAfter = const Duration(seconds: 10);
  static const int maxBody = 4000;

  /// Request body as text for the log: passwords masked, capped.
  static String? requestBody(http.BaseRequest request) {
    if (request is! http.Request || request.body.isEmpty) return null;
    return cap(request.body.replaceAllMapped(_secretJson, (m) => '${m[1]}"***"'));
  }

  static String cap(String text) => text.length <= maxBody
      ? text
      : '${text.substring(0, maxBody)}... (${text.length - maxBody} more chars)';

  static String maskUrl(Uri url) =>
      url.toString().replaceAllMapped(_secretParams, (m) => '${m[1]}=***');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Log UPLOADS (POST /v2/Logs) are not logged themselves, otherwise every
    // upload would create a new log entry to upload, forever. The dashboard's
    // reads and deletes on the same address are logged like any other call.
    if (request.method == 'POST' && request.url.path.endsWith('/v2/Logs')) {
      return _inner.send(request);
    }

    final url = maskUrl(request.url);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      final ms = stopwatch.elapsedMilliseconds;
      final status = response.statusCode;
      final message = '${request.method} $url → $status in ${ms}ms';

      if (status < 400) {
        if (stopwatch.elapsed > slowAfter) {
          AppLogger.warn('SlowResponse', message);
        } else {
          AppLogger.info('Http', message);
        }
        return response;
      }

      // Failure: read the server's answer for the log, then hand the same
      // bytes on to the caller.
      final full = await http.Response.fromStream(response);
      final sent = requestBody(request);
      final answer = utf8.decode(full.bodyBytes, allowMalformed: true);
      final details = [
        if (sent != null) 'Sent: $sent',
        'Response: ${answer.isEmpty ? '(empty)' : cap(answer)}',
      ].join('\n');
      if (status >= 500) {
        AppLogger.error('Http', message, details: details);
      } else {
        AppLogger.warn('Http', message, details: details);
      }
      return http.StreamedResponse(
        http.ByteStream.fromBytes(full.bodyBytes),
        status,
        contentLength: full.bodyBytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e, st) {
      final ms = stopwatch.elapsedMilliseconds;
      AppLogger.error(
        'HttpFailed',
        '${request.method} $url failed after ${ms}ms: ${describe(e)}',
        error: e,
        stack: st,
        details: requestBody(request) == null ? null : 'Sent: ${requestBody(request)}',
      );
      rethrow;
    }
  }

  /// Plain-language category for common network failures.
  static String describe(Object e) {
    if (e is TimeoutException) return 'TIMEOUT (server too slow)';
    if (e is HandshakeException || e is TlsException) {
      return 'SECURE CONNECTION FAILED (certificate / TLS)';
    }
    if (e is SocketException) {
      final msg = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
      if (msg.contains('host lookup') || msg.contains('no address')) {
        return 'DNS FAILED (server name could not be resolved)';
      }
      if (msg.contains('refused')) return 'CONNECTION REFUSED (server not accepting)';
      if (msg.contains('unreachable')) return 'NETWORK UNREACHABLE';
      if (msg.contains('timed out')) return 'CONNECTION TIMED OUT';
      if (msg.contains('reset') || msg.contains('broken pipe')) {
        return 'CONNECTION DROPPED';
      }
      return 'NETWORK ERROR';
    }
    if (e is http.ClientException) return 'CLIENT ERROR';
    return e.runtimeType.toString();
  }
}
