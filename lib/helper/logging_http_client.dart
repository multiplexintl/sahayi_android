import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../service/app_logger.dart';

/// Wraps an [http.Client] and logs every request: URL (passwords masked),
/// status code, duration and, on failure, the exact kind of error.
/// Responses and errors are passed through unchanged.
class LoggingClient extends http.BaseClient {
  final http.Client _inner;
  LoggingClient(this._inner);

  static final _secretParams = RegExp(r'(pwd|password)=[^&]*', caseSensitive: false);

  static String maskUrl(Uri url) =>
      url.toString().replaceAllMapped(_secretParams, (m) => '${m[1]}=***');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = maskUrl(request.url);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      final ms = stopwatch.elapsedMilliseconds;
      final status = response.statusCode;
      final message = '${request.method} $url → $status in ${ms}ms';

      if (status >= 500) {
        AppLogger.error('Http', message);
      } else if (status >= 400) {
        AppLogger.warn('Http', message);
      } else {
        AppLogger.info('Http', message);
      }
      return response;
    } catch (e, st) {
      final ms = stopwatch.elapsedMilliseconds;
      AppLogger.error(
        'HttpFailed',
        '${request.method} $url failed after ${ms}ms: ${describe(e)}',
        error: e,
        stack: st,
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
