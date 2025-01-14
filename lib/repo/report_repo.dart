import 'dart:convert';
import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:http/http.dart' as http;
import 'package:sahayi_android/model/report/report.dart';

import '../helper/retry_helper.dart';

class ReportRepo {
  final String _url = GlobalConfiguration().getValue('api_base_url');

  Future<Either<String, List<Report>?>> fetchReports({
    String? company,
    required String empId,
    String? fromDate,
    String? toDate,
  }) async {
    return await RetryHelper.retry<Either<String, List<Report>?>>(
        apiCall: () async {
          final Uri url = Uri.parse(
              '${_url}Operational/GetRecentActivity?UserID=$empId&Company=$company&FromDate=$fromDate&ToDate=$toDate');
          final client = http.Client();
          log(url.toString());
          final response = await client.get(url);
          log("Response Code: ${response.statusCode}");

          if (response.statusCode == 200) {
            List<dynamic> responseBody = jsonDecode(response.body);

            if (responseBody.isEmpty) {
              return left("No Reports Found!!");
            } else {
              var report =
                  responseBody.map((json) => Report.fromJson(json)).toList();
              return Right(report);
            }
          } else {
            return Left("${response.statusCode} : ${response.body}");
          }
        },
        defaultValue: const Left("Retry failed"),
        maxRetries: 3,
        shouldRetry: (result) =>
            result.isLeft() &&
            result.fold((l) => l == "Retry failed", (_) => false));
  }
}
