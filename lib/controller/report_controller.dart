import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/model/report/report.dart';
import 'package:sahayi_android/repo/report_repo.dart';

import '../model/company.dart';

class ReportController extends GetxController {
  var fromDateController = TextEditingController().obs;
  var toDateController = TextEditingController().obs;
  var homeCon = Get.find<HomeController>();
  var reports = <Report>[].obs;
  var isLoading = false.obs;
  var fetchAll = true.obs;

  @override
  void onInit() {
    super.onInit();
    var today = DateTime.now();
    var sevenDaysBefore = today.subtract(Duration(days: 7));
    fromDateController.value.text =
        DateFormat("dd-MM-yyyy").format(sevenDaysBefore);
    toDateController.value.text = DateFormat("dd-MM-yyyy").format(today);
  }

  void updateDate({DateTime? date, required bool isFrom}) async {
    if (date != null) {
      log(date.toString());
      String formattedDate = DateFormat("dd-MM-yyyy").format(date);
      if (isFrom) {
        fromDateController.value.text = formattedDate;
      } else {
        toDateController.value.text = formattedDate;
      }
    } else {
      if (isFrom) {
        fromDateController.value.clear();
      } else {
        toDateController.value.clear();
      }
    }
  }

  Future<void> fetchReport() async {
    try {
      isLoading.value = true;
      DateFormat dateFormat = DateFormat("dd-MM-yyyy");

      // Validate if the date controllers are empty
      if (fromDateController.value.text.isEmpty ||
          toDateController.value.text.isEmpty) {
        CustomWidget.customSnackBar(
          title: "Error",
          message: "Both 'From Date' and 'To Date' must be filled.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        isLoading.value = false;
        return;
      }

      // Parse the date strings
      var fromDate = dateFormat.parse(fromDateController.value.text);
      var toDate = dateFormat.parse(toDateController.value.text);

      // Validate if 'To Date' is before 'From Date'
      if (toDate.isBefore(fromDate)) {
        log("To Date should be after From Date");
        CustomWidget.customDialogue(
          title: "Error!!",
          subTitle: '"From Date" should be before "To Date"!!!',
          onPressedBack: () => Get.back(),
          okText: "Clear",
          onPressed: () {
            clearDates();
            Get.back();
          },
        );
        isLoading.value = false;
        return;
      }

      log(fromDate.toString());
      log(toDate.toString());

      // Fetch report data using the repository
      log("fetchAll : ${fetchAll.value}");
      final res = await ReportRepo().fetchReports(
          company: !fetchAll.value ? homeCon.user.value.company! : '',
          empId: homeCon.user.value.empID!,
          fromDate: DateFormat('yyyy-MM-dd').format(fromDate),
          toDate: DateFormat('yyyy-MM-dd').format(toDate));

      // Handle API response using Either pattern
      res.fold(
        (errorMsg) {
          log("Error: $errorMsg");
          CustomWidget.customSnackBar(
            title: "Error",
            message: errorMsg,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        },
        (reps) {
          log("Reports fetched successfully: $reps");
          reports.value =
              mapAndSortReportsByScanTime(reps ?? [], homeCon.companyList);
          CustomWidget.customSnackBar(
            title: "Success",
            message: "Reports fetched successfully.",
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
        },
      );
    } catch (e, stacktrace) {
      log("Error in fetchReport: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Error",
        message: "An unexpected error occurred: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void clearDates() {
    fromDateController.value.clear();
    toDateController.value.clear();
  }

  List<Report> mapAndSortReportsByScanTime(
      List<Report> reports, List<Company> companies) {
    // Map company names to reports
    List<Report> updatedReports = reports.map((report) {
      final matchingCompany = companies.firstWhere(
        (company) => company.companyId == report.company,
      );

      // Return a modified Report object with the updated company name
      return Report(
        company: matchingCompany.companyName ?? 'Unknown Company',
        docNum: report.docNum,
        custNum: report.custNum,
        custName: report.custName,
        userId: report.userId,
        scanTime: report.scanTime,
      );
    }).toList();
// return updatedReports;
    // // ✅ Sorting by scanTime in descending order
    // updatedReports.sort((a, b) {
    //   final DateTime aDate = DateTime.parse(
    //       a.scanTime!.replaceAll(' ', 'T')); // Convert to DateTime for sorting
    //   final DateTime bDate = DateTime.parse(b.scanTime!.replaceAll(' ', 'T'));
    //   return bDate.compareTo(aDate); // Descending order
    // });

    return updatedReports;
  }
}
