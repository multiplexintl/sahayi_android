import 'dart:convert';
import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:http/http.dart' as http;

import '../helper/retry_helper.dart';
import '../model/user.dart';

class LoginRepo {
  final String _url = GlobalConfiguration().getValue('api_base_url');

  Future<Either<String, User>> getEmployee(
      {required String empId, required String pwd}) async {
    return await RetryHelper.retry<Either<String, User>>(
      apiCall: () async {
        final Uri url =
            Uri.parse('${_url}Login/GetUsersLogin?UserID=$empId&Pwd=$pwd');
        final client = http.Client();

        final response = await client.get(url);
        log("Response Code: ${response.statusCode}");

        if (response.statusCode == 200) {
          List<dynamic> responseBody = jsonDecode(response.body);

          if (responseBody.isEmpty) {
            return const Left("Emp ID or Password is wrong, try again.");
          } else {
            var user = User.fromJson(responseBody[0]);
            return Right(user);
          }
        } else {
          return Left(response.body);
        }
      },
      defaultValue: const Left("Retry failed"),
      maxRetries: 3,
      shouldRetry: (result) =>
          result.isLeft() &&
          result.fold((l) => l == "Retry failed", (_) => false),
    );
  }
}
