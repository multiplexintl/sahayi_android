import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:sahayi_android/model/return/customer.dart';
import 'package:http/http.dart' as http;
import 'package:sahayi_android/model/return/reasons.dart';
import '../helper/retry_helper.dart';
import '../model/invoice/doc_master.dart';
import '../model/return/part.dart';

class RetrunRepo {
  final String _url = GlobalConfiguration().getValue('api_base_url');
  Future<Either<String, List<Customer>?>> fetchCustomer(
      {required String company, required String query}) async {
    return await RetryHelper.retry<Either<String, List<Customer>?>>(
        apiCall: () async {
          final Uri url = Uri.parse(
              '${_url}Return/Sync_NewCustomer?Company=EPIC01&query=$query');
          final client = http.Client();
          log(url.toString());
          final response = await client.get(url);
          log("Response Code: ${response.statusCode}");

          if (response.statusCode == 200) {
            List<dynamic> responseBody = jsonDecode(response.body);

            if (responseBody.isEmpty) {
              return left("No Customer Found!!");
            } else {
              var report =
                  responseBody.map((json) => Customer.fromJson(json)).toList();
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

  Future<Either<String, List<Reasons>?>> fetchReasons() async {
    return await RetryHelper.retry<Either<String, List<Reasons>?>>(
        apiCall: () async {
          final Uri url = Uri.parse('${_url}Return/GetReason?query');
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
                  responseBody.map((json) => Reasons.fromJson(json)).toList();
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

  Future<Either<String, Part?>> getPart({
    required String company,
    required String query,
  }) async {
    return await RetryHelper.retry<Either<String, Part?>>(
        apiCall: () async {
          final Uri url = Uri.parse('${_url}Return/GetPartData?barcode=$query');
          final client = http.Client();
          log(url.toString());
          final response = await client.get(url);
          log("Response Code: ${response.statusCode}");

          if (response.statusCode == 200) {
            List<dynamic> responseBody = jsonDecode(response.body);

            if (responseBody.isEmpty) {
              return Left("No Item Found!!");
            } else {
              var report =
                  responseBody.map((json) => Part.fromJson(json)).toList();
              return Right(report[0]);
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

  Future<List<DocMaster>> getReturnDetails({
    required String company,
    required String docNum,
    required String docType,
  }) async {
    return await RetryHelper.retry<List<DocMaster>>(
      apiCall: () async {
        final Uri url = Uri.parse(
            '${_url}Operational/DocumentGetRecords?DocNum=$docNum&DocType=$docType&Company=$company');
        log(url.toString());
        final client = http.Client();
        final response = await client.get(url);
        log("Response Code get invoice: ${response.statusCode}");
        if (response.statusCode == 200) {
          List<dynamic> jsonList = json.decode(response.body);
          List<DocMaster> invoices =
              jsonList.map((json) => DocMaster.fromJson(json)).toList();
          return invoices;
        } else {
          return [];
        }
      },
      defaultValue: [],
      maxRetries: 3,
      shouldRetry: (result) => result == [],
    );
  }

  Future<bool> updateReturn({required String master}) async {
    return await RetryHelper.retry<bool>(
      apiCall: () async {
        final Uri url = Uri.parse('${_url}Return/CreateReturn');
        var body = master;
        final client = http.Client();
        log(url.toString());
        final response = await client.post(url,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: body);
        log("Response Code Sync Return Master: ${response.statusCode}");
        if (response.statusCode == 200) {
          return true;
        } else {
          return false;
        }
      },
      defaultValue: false,
      maxRetries: 3,
      shouldRetry: (result) => result == false,
    );
  }
}
