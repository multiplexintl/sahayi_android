// lib/helper/http_client_helper.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class HttpClientHelper {
  static http.Client? _client;

  // Returns a singleton client with our certificate chain pinned.
  // Uses withTrustedRoots: false so BoringSSL (Flutter/Android) only
  // validates against our bundled chain, avoiding the missing-root issue.
  Future<http.Client> getClient() async {
    if (_client != null) return _client!;

    final SecurityContext context = SecurityContext(withTrustedRoots: false);
    final certData =
        await rootBundle.load('assets/cert/full_chain_multiroute.ae.pem');
    context.setTrustedCertificatesBytes(certData.buffer.asUint8List());

    _client = IOClient(HttpClient(context: context));
    return _client!;
  }
}
