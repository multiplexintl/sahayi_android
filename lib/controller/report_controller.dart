import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/model/report/report.dart';
import 'package:sahayi_android/repo/home_repo.dart';
import 'package:sahayi_android/repo/report_repo.dart';
import 'package:sahayi_android/routes.dart';

import '../model/company.dart';
import '../model/invoice/doc_detail.dart';
import '../model/invoice/doc_master.dart';

class ReportController extends GetxController {
  var fromDateController = TextEditingController().obs;
  var toDateController = TextEditingController().obs;
  var docNumController = TextEditingController().obs;
  var homeCon = Get.find<InvoiceOrTransferController>();
  var reports = <Report>[].obs;
  var isLoading = false.obs;
  var isLoadingDetailed = false.obs;
  var fetchAll = true.obs;
  var selectedType = Rxn<Map<String, dynamic>>();
  var reportTypes = <Map<String, dynamic>>[].obs;
  var selectedReport = Rxn<Report>();
  var detailedReport = Rxn<DocMaster>();

  @override
  void onInit() {
    super.onInit();
    var today = DateTime.now();
    var sevenDaysBefore = today.subtract(Duration(days: 7));
    fromDateController.value.text =
        DateFormat("dd-MM-yyyy").format(sevenDaysBefore);
    toDateController.value.text = DateFormat("dd-MM-yyyy").format(today);
    reportTypes.value = [
      {'I': 'Invoice'},
      {"T": "Transfer"},
      {"R": "Return"},
      {"A": "All"}
    ];
    selectedType.value = reportTypes.last;
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
    reports.clear();
    try {
      isLoading.value = true;
      DateFormat dateFormat = DateFormat("dd-MM-yyyy");

      // Check if either DocNum or Dates are provided
      if (docNumController.value.text.isEmpty &&
          (fromDateController.value.text.isEmpty ||
              toDateController.value.text.isEmpty)) {
        CustomWidget.customSnackBar(
          title: "Error",
          message:
              "Please provide either a Doc Number or both 'From Date' and 'To Date'.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        isLoading.value = false;
        return;
      }

      DateTime? fromDate;
      DateTime? toDate;

      // Parse Dates if provided
      if (fromDateController.value.text.isNotEmpty &&
          toDateController.value.text.isNotEmpty) {
        fromDate = dateFormat.parse(fromDateController.value.text);
        toDate = dateFormat.parse(toDateController.value.text);

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
      }

      log("From Date: ${fromDate?.toString() ?? "N/A"}");
      log("To Date: ${toDate?.toString() ?? "N/A"}");
      log("Doc Num: ${docNumController.value.text}");
      log("fetchAll: ${fetchAll.value}");

      // Determine docType from selectedType
      String selectedTypeKey = selectedType.value?.keys.firstOrNull ?? 'A';
      List<Report> allReports = [];

      if (selectedTypeKey == 'A') {
        // Fetch reports for each type (I, T, R) and combine results
        List<String> types = ['I', 'T', 'R'];

        for (String type in types) {
          final res = await ReportRepo().fetchReports(
            company: !fetchAll.value ? homeCon.user.value.company! : '',
            empId: homeCon.user.value.empID!,
            fromDate: fromDate != null
                ? DateFormat('yyyy-MM-dd').format(fromDate)
                : '',
            toDate:
                toDate != null ? DateFormat('yyyy-MM-dd').format(toDate) : '',
            docNum: docNumController.value.text,
            type: docNumController.value.text.isNotEmpty ? 'Doc' : 'Date',
            docType: type,
          );

          res.fold(
            (errorMsg) {
              log("Error fetching reports for type $type: $errorMsg");
            },
            (reps) {
              if (reps != null) {
                log(reps.length.toString());
                allReports.addAll(reps);
              }
            },
          );
        }
        log(allReports.length.toString());
      } else {
        // Fetch report for the selected type (I, T, or R)
        final res = await ReportRepo().fetchReports(
          company: !fetchAll.value ? homeCon.user.value.company! : '',
          empId: homeCon.user.value.empID!,
          fromDate:
              fromDate != null ? DateFormat('yyyy-MM-dd').format(fromDate) : '',
          toDate: toDate != null ? DateFormat('yyyy-MM-dd').format(toDate) : '',
          docNum: docNumController.value.text,
          type: docNumController.value.text.isNotEmpty ? 'Doc' : 'Date',
          docType: selectedTypeKey,
        );

        res.fold(
          (errorMsg) {
            log("Error fetching reports: $errorMsg");
            CustomWidget.customSnackBar(
              title: "Error",
              message: errorMsg,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          },
          (reps) {
            if (reps != null) {
              allReports.addAll(reps);
            }
          },
        );
      }

      // Map and sort reports
      reports.value =
          mapAndSortReportsByScanTime(allReports, homeCon.companyList);
      log(reports[0].toString());

      CustomWidget.customSnackBar(
        title: "Success",
        message: "Reports fetched successfully.",
        backgroundColor: Colors.green,
        textColor: Colors.white,
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
    docNumController.value.clear();
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
          company: matchingCompany.companyId ?? 'Unknown Company',
          docNum: report.docNum,
          custId: report.custId,
          custName: report.custName,
          userId: report.userId,
          scanTime: report.scanTime,
          docType: report.docType);
    }).toList();

    return updatedReports;
  }

  Future<void> selectReport(Report report) async {
    try {
      detailedReport.value = null;
      isLoadingDetailed.value = true;
      selectedReport.value = report;
      log("Selected Report: ${selectedReport.value}");

      Get.toNamed(RouteLinks.detailedReport);

      // Fetching invoice details
      var detailed = await HomeRepo().getInvoiceDetails(
        company: selectedReport.value!.company!,
        docNum: selectedReport.value?.docType == 'R'
            ? "${selectedReport.value?.custId}${selectedReport.value!.docNum!}"
            : selectedReport.value!.docNum!,
        docType: selectedReport.value!.docType!,
      );

      if (detailed.isNotEmpty) {
        var docMaster = detailed[0];

        // Convert company ID to company name
        var company = homeCon.companyList.firstWhere(
          (c) => c.companyId == docMaster.company,
          orElse: () => Company(companyId: '', companyName: 'Unknown Company'),
        );
        docMaster = docMaster.copyWith(company: company.companyName);

        // Format dates
        docMaster = docMaster.copyWith(
          docDate: formatDate(docMaster.docDate),
          scanTime: formatDate(docMaster.scanTime, includeTime: true),
        );

        // Format docDetails
        List<DocDetail> updatedDetails = docMaster.docDetails?.map((detail) {
              return detail.copyWith(
                expiryDate: (detail.expiryDate == "0001-01-01T00:00:00")
                    ? null
                    : formatDate(detail.expiryDate),
              );
            }).toList() ??
            [];

        docMaster = docMaster.copyWith(docDetails: updatedDetails);

        detailedReport.value = docMaster;
        log("Updated Detailed Report: $detailedReport");
      } else {
        log("No details found for the selected report.");
      }
    } catch (e, stacktrace) {
      log("Error in selectReport: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Error",
        message: "Failed to fetch report details: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      isLoadingDetailed.value = false;
    }
  }

  /// Helper function to format dates
  // String formatDate(String? date) {
  //   if (date == null || date.isEmpty) return '';
  //   try {
  //     DateTime parsedDate = DateTime.parse(date);
  //     return "${parsedDate.day.toString().padLeft(2, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.year}"
  //         "${date.contains('T') ? ' ${parsedDate.hour}:${parsedDate.minute}:${parsedDate.second}' : ''}";
  //   } catch (e) {
  //     log("Error formatting date: $e");
  //     return date;
  //   }
  // }
  String formatDate(String? date, {bool includeTime = false}) {
    if (date == null || date.isEmpty) return '';

    try {
      DateTime parsedDate;

      if (date.contains('T')) {
        // ISO 8601 format (e.g., "2025-03-14T12:00:00")
        parsedDate = DateTime.parse(date);
      } else {
        // US format (e.g., "3/14/2025 12:00:00 AM")
        parsedDate = DateFormat("M/d/yyyy h:mm:ss a").parse(date);
      }

      String formattedDate = DateFormat("dd-MM-yyyy").format(parsedDate);

      if (includeTime) {
        formattedDate += " ${DateFormat("HH:mm:ss a").format(parsedDate)}";
      }

      return formattedDate;
    } catch (e) {
      log("Error formatting date: $e");
      return date; // Return original date if parsing fails
    }
  }
}
