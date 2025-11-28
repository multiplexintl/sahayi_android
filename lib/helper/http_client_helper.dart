// lib/helper/http_client_helper.dart
import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class HttpClientHelper {
  Future<http.Client> getClient() async {
    SecurityContext context = SecurityContext(withTrustedRoots: true);

// Load full chain PEM
    final certData = await rootBundle
        .load('assets/cert/PositiveSSL_Wildcard_multiroute.ae.pem');
    context.setTrustedCertificatesBytes(certData.buffer.asUint8List());
    final httpClient = HttpClient(context: context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        log(host);
        log(cert.issuer);
        log(cert.subject);

        // Only accept for YOUR specific domain
        // if (host == 'sahayiapi.multiroute.ae') {
        //   // Verify it's the Sectigo certificate (not win5.server.ae)
        //   return cert.subject.contains('Sectigo') &&
        //       !cert.subject.contains('win5.server.ae');
        // }
        return false; // Reject all other bad certificates
      };
    return IOClient(httpClient);
  }
}
