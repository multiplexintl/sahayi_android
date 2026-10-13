import 'dart:async';

import 'package:http/http.dart' as http;

/// Puts time limits on every request so the app shows an error instead of
/// waiting forever when the server or network stops answering.
///
/// Reads (GET) get a shorter limit than saves (POST): a save that is cut off
/// may already have been stored by the server, and retrying it could store it twice.
class TimeoutClient extends http.BaseClient {
  final http.Client _inner;

  /// Max wait for the server to start answering: reads (GET) / saves (POST).
  final Duration readTimeout;
  final Duration saveTimeout;

  /// Max silence while the answer is being downloaded.
  final Duration idleTimeout;

  TimeoutClient(
    this._inner, {
    this.readTimeout = const Duration(seconds: 30),
    this.saveTimeout = const Duration(seconds: 120),
    this.idleTimeout = const Duration(seconds: 30),
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final limit = request.method == 'GET' ? readTimeout : saveTimeout;
    final response = await _inner.send(request).timeout(limit,
        onTimeout: () => throw TimeoutException(
            '${request.method} ${request.url.path} got no answer within ${limit.inSeconds}s',
            limit));

    return http.StreamedResponse(
      response.stream.timeout(idleTimeout, onTimeout: (sink) {
        sink.addError(TimeoutException(
            '${request.url.path} stopped sending data for ${idleTimeout.inSeconds}s',
            idleTimeout));
        sink.close();
      }),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
