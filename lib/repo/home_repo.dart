import 'dart:convert';
import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:http/http.dart' as http;
import 'package:sahayi_android/model/company.dart';

import '../helper/retry_helper.dart';
import '../model/invoice/invoice.dart';

class HomeRepo {
  final String _url = GlobalConfiguration().getValue('api_base_url');

  Future<Either<String, bool>> syncInvoice({
    required String company,
    required String docNum,
    required String docType,
  }) async {
    return await RetryHelper.retry<Either<String, bool>>(
      apiCall: () async {
        final Uri url = Uri.parse(
            '${_url}Operational/Sync_Document?Company=$company&DocNum=$docNum&DocType=$docType');
        final client = http.Client();
        log(url.toString());
        try {
          final response = await client.get(url);
          log("Response Code Sync DocMaster: ${response.statusCode}");
          final responseBody = response.body.trim();
          log(responseBody);

          if (response.statusCode == 200) {
            if (responseBody.contains('successfully')) {
              return const Right(true); // Success case
            } else if (responseBody.contains("Already")) {
              return Left(responseBody); // Return the message as a failure
            } else {
              return Left("Unknown response received: $responseBody");
            }
          } else {
            return Left("Error: HTTP ${response.statusCode}");
          }
        } catch (e) {
          log("Error in syncInvoice: $e");
          return Left("An error occurred: $e");
        } finally {
          client.close();
        }
      },
      defaultValue: const Left("An error occurred during the sync process."),
      maxRetries: 3,
      shouldRetry: (result) =>
          result.isLeft() &&
          result.fold(
            (failure) =>
                failure.contains("Error: HTTP") ||
                failure.contains("An error occurred"),
            (success) => false,
          ),
    );
  }

  Future<List<DocMaster>> getInvoiceDetails({
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
          log(response.body.toString());
          List<dynamic> jsonList = json.decode(response.body);
          log(response.body.toString());
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

  // update invoice
  Future<bool> updateInvoice({
    required String company,
    required String userId,
    required String docNum,
    required String docType,
  }) async {
    return await RetryHelper.retry<bool>(
      apiCall: () async {
        final Uri url = Uri.parse(
            '${_url}Operational/UpdateDocument?UserID=$userId&DocNum=$docNum&DocType=$docType&Company=$company');
        final client = http.Client();
        log(url.toString());
        final response = await client.post(url);
        log("Response Code Sync DocMaster: ${response.statusCode}");
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

  Future<List<Company>> getCompany() async {
    return await RetryHelper.retry<List<Company>>(
      apiCall: () async {
        final Uri url = Uri.parse('${_url}Operational/GetCompanyMaster');
        log(url.toString());
        final client = http.Client();
        final response = await client.get(url);
        log("Response Code get invoice: ${response.statusCode}");
        if (response.statusCode == 200) {
          log(response.body.toString());
          List<dynamic> jsonList = json.decode(response.body);
          log(response.body.toString());
          List<Company> invoices =
              jsonList.map((json) => Company.fromJson(json)).toList();
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
}

//"Document synchronized successfully."
//"Already finalized invoice, cannot synchronize."
