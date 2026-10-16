import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';
import 'package:sahayi_android/model/return/customer.dart';
import 'package:sahayi_android/model/return/reasons.dart';

import '../model/company.dart';
import '../model/return/part.dart';

import '../repo/home_repo.dart';
import '../repo/retrun_repo.dart';
import '../routes.dart';
import '../widgets/button.dart';
import '../service/app_logger.dart';

class ReturnController extends GetxController {
  var custController = TextEditingController();
  var docNumController = TextEditingController();
  var docDateController = TextEditingController();
  var reasonController = TextEditingController();
  var expiryDateController = TextEditingController();
  var custSuggestions = <Customer>[].obs;
  var unFinishedDocs = <DocMaster>[].obs;

  /// Lines and units scanned per unfinished return, key "Company|DocNum"
  /// (DocNum as stored: customer ID + number).
  final unfinishedCounts = <String, (int, int)>{}.obs;

  static String countKey(String? company, String? fullDocNum) =>
      '$company|$fullDocNum';
  var selectedCustomer = Customer().obs;
  var docNumber = Rxn<String>();
  var selectedPart = Rxn<Part>();
  var scanStartingSlNo = Rx<int>(0);
  var docDate = Rxn<String>();
  var expiryDate = Rxn<String>();
  var homeCon = Get.find<HomeController>();
  var totalQty = Rx<int>(0);
  var driverList = <Pickers>[].obs;
  var selectedDriver = Rxn<Pickers>();
  var driver = Rxn<Pickers>();

  TextEditingController barcodeController = TextEditingController();
  TextEditingController qtyController = TextEditingController();
  final qtyFocusNode = FocusNode();
  final barcodeFocusNode = FocusNode();
  Timer? _debounceTimer;
  var selectIsLoading = false.obs;
  var scanIsLoading = false.obs;
  var finalizeIsLoading = false.obs;
  // var showOtherTextField = false.obs;
  var reasons = <Reasons>[].obs;
  var selectedReason = Rxn<Reasons>();
  List<Company> companyList = [];
  var savedItems = <DocDetail>[].obs;
  var consolidatedSavedItems = <DocDetail>[].obs;
  var syncIsLoading = false.obs;
  Rxn<Company> selectedCompany = Rxn<Company>();
  @override
  void onInit() {
    super.onInit();
    getCompanies();
    getAllReasons();
    getUnfinishedDocs();
    getPickers();
  }

  Future<void> getCompanies() async {
    try {
      final list = await HomeRepo().getCompany();
      if (list.isNotEmpty) {
        companyList = list;
      } else {
        CustomWidget.customSnackBar(
          title: "Error!!",
          message: "Companies not loaded, please restart the app.",
        );
      }
    } catch (e, st) {
      AppLogger.error('LoadCompanies', 'Failed to load companies',
          error: e, stack: st);
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Failed to load companies. Error: $e",
      );
    }
  }

  void selectComapny(Company? company) {
    selectedCompany.value = company;
    AppLogger.setCompany(company?.companyId);
    update();
  }

  Future<void> getPickers() async {
    try {
      final list = await HomeRepo().getPickers();
      if (list.isNotEmpty) {
        driverList.value = list.where((ls) => ls.type == 'Driver').toList();
        log("Drivers : ${driverList.length}");
      } else {
        CustomWidget.customSnackBar(
          title: "Error!!",
          message: "Pickers not loaded, please restart the app.",
        );
      }
    } catch (e, st) {
      AppLogger.error('LoadPickers', 'Failed to load drivers',
          error: e, stack: st);
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Failed to load companies. Error: $e",
      );
    }
  }

  void selectDriver(Pickers? driver) {
    selectedDriver.value = driver;
    log(selectedDriver.toString());
    update();
  }

  Future<List<Customer>> getSuggestions(String query) async {
    List<Customer> matches = <Customer>[];
    // here do api
    if (query.isNotEmpty) {
      // matches.addAll(fakeCustomers);
      var res = await RetrunRepo().fetchCustomer(
        company: selectedCompany.value!.companyId!,
        query: query,
      );
      res.fold((error) {
        AppLogger.warn('CustomerSearch', 'Search "$query" failed: $error');
        CustomWidget.customSnackBar(
            title: "Error!!", message: error, backgroundColor: Colors.red);
      }, (custs) {
        matches.addAll(custs!);
      });
    } else {
      custSuggestions.clear();
    }
    return matches;
  }

  void getAllReasons() async {
    var res = await RetrunRepo().fetchReasons();
    res.fold((error) {
      log(error);
      AppLogger.warn('LoadReasons', 'Failed to load return reasons: $error');
    }, (custs) {
      reasons.addAll(custs!);
    });
  }

  void onCustomerSelected(Customer cust) {
    custController.text = "${cust.custId} - ${cust.custName}";
    selectedCustomer.value = cust;
  }

  void clearCustSelction() {
    selectedCompany.value = null;
    custController.clear();
    docNumController.clear();
    docDateController.clear();
    selectedCustomer.value = Customer();
    docNumber.value = null;
    docDate.value = null;
    selectedDriver.value = null;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void clearPart() {
    FocusManager.instance.primaryFocus?.unfocus();
    barcodeController.clear();
    qtyController.clear();
    selectedReason.value = null;
    selectedPart.value = null;
    expiryDate.value = null;
    expiryDateController.clear();
    update();
  }

  void clearAll() async {
    var dets = await DBHelper.deleteItemsByQuery(
        tableName: DBHelper.docDetail,
        where:
            "${DBHelper.docNumDocDetail} = ? and ${DBHelper.docTypeDocDetail} = ?",
        whereArgs: ["${selectedCustomer.value.custId}${docNumber.value}", 'R']);

    log(dets.toString());
    if (dets != -1) {
      AppLogger.warn(
          'ReturnClearItems', 'User cleared all scanned items ($dets rows)',
          docNum: "${selectedCustomer.value.custId}${docNumber.value}",
          docType: 'R');
      savedItems.clear();
    } else {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Error deleting details, try again",
        backgroundColor: Colors.red,
      );
    }
    update();
  }

  Future<void> onSubmit(DocMaster? item) async {
    log("======== STARTING onSubmit ========");
    selectIsLoading.value = true;
    FocusManager.instance.primaryFocus?.unfocus();

    String fullDocNum;
    int lastApiSlNo = 0;

    try {
      log("STEP 1: Checking if user selected from Unfinished List...");

      /// **Handling Unfinished Document Selection**
      if (item != null) {
        log("User selected from Unfinished List: $item");
        AppLogger.info('ReturnResume', 'Resuming unfinished return',
            docNum: "${item.custID}${item.docNum}", docType: 'R');

        // Step 1 fix: guard firstWhere — missing company/driver shows clear error
        final company = companyList
            .firstWhereOrNull((test) => test.companyId == item.company);
        if (company == null) {
          log("❌ Company not found in list: ${item.company}");
          CustomWidget.customSnackBar(
            backgroundColor: Colors.red,
            title: "Company Not Found",
            message:
                "Could not find company for this document. Please restart the app.",
          );
          return;
        }
        selectedCompany.value = company;
        AppLogger.setCompany(company.companyId);

        fullDocNum = "${item.custID}${item.docNum}";
        selectedCustomer.value.custId = item.custID;
        selectedCustomer.value.custName = item.custName;
        docNumber.value = item.docNum;
        docDate.value = item.docDate?.toString() ?? DateTime.now().toString();
        log(selectedCustomer.toString());
        final foundDriver = driverList
            .firstWhereOrNull((element) => element.id == item.pickedBy);
        if (foundDriver == null) {
          log("❌ Driver not found in list: ${item.pickedBy}");
          CustomWidget.customSnackBar(
            backgroundColor: Colors.red,
            title: "Driver Not Found",
            message:
                "Could not find driver for this document. Please reload pickers and try again.",
          );
          return;
        }
        driver.value = foundDriver;

        // Step 2 fix: separate network error from empty result
        log("STEP 2: Checking API for existing details...");
        List<DocMaster> apiRes;
        try {
          apiRes = await getReturnDetails();
        } catch (e) {
          AppLogger.error(
              'ReturnResume', 'Could not check server for existing return',
              error: e, docNum: fullDocNum, docType: 'R');
          log("❌ Network error fetching return details: $e");
          CustomWidget.customSnackBar(
            backgroundColor: Colors.red,
            title: "Connection Error",
            message:
                "Could not connect to server. Check your connection and try again.",
          );
          return;
        }
        log("API Response: ${apiRes.length} items found.");

        lastApiSlNo = (apiRes.isNotEmpty &&
                apiRes[0].docDetails != null &&
                apiRes[0].docDetails!.isNotEmpty)
            ? apiRes[0]
                .docDetails!
                .map((d) => d.slNo ?? 0)
                .reduce((a, b) => a > b ? a : b)
            : 0;
        log("Last API SL No: $lastApiSlNo");

        // **Fetch Local DB Data**
        log("STEP 3: Fetching Local DB Data...");
        var fromDB = await DBHelper.getItemsByQuery(
          tableName: DBHelper.docDetail,
          where:
              '${DBHelper.companyDocDetail} = ? AND ${DBHelper.docNumDocDetail} = ? AND ${DBHelper.docTypeDocDetail} = ?',
          whereArgs: [item.company, fullDocNum, 'R'],
        );

        List<DocDetail> localItems = fromDB.isNotEmpty
            ? fromDB.map((it) => DocDetail.fromJson(it)).toList()
            : [];
        log("Found ${localItems.length} items in Local DB.");

        // Local line numbers are NOT renumbered here any more. Renumbering
        // re-saved each line through DocDetail.toDB(), whose DocNum has the
        // customer ID cut off, so every resume left invisible copies under
        // the wrong document number. Line numbers only need to be unique on
        // this phone: finalize() numbers the uploaded lines after the
        // server's highest line anyway.

        // **Set Next SL No and Move to Scan Screen**
        log(lastApiSlNo.toString());
        scanStartingSlNo.value = lastApiSlNo;
        savedItems.value = localItems;
        log("Redirecting to Scan Page...$scanStartingSlNo");
        log(driverList.toString());

        Get.toNamed(RouteLinks.scanReturns);
        return;
      }

      // **Handling New Document Entry**
      log("STEP 4: Handling User-Entered Document...");
      if (selectedCompany.value == null ||
          custController.text.isEmpty ||
          docNumController.text.isEmpty ||
          docDateController.text.isEmpty ||
          selectedDriver.value == null) {
        log("❌ Error: Empty Fields Detected!");
        CustomWidget.customSnackBar(
          backgroundColor: Colors.red,
          title: "Empty Fields!!",
          message: "The fields should not be empty.",
        );
        return;
      }

      // Step 6 fix: trim input to avoid phantom duplicates from trailing spaces
      docNumber.value = docNumController.text.trim();
      docDate.value = docDateController.text;
      fullDocNum = "${selectedCustomer.value.custId}${docNumber.value}";
      driver.value = selectedDriver.value;

      log("User entered details: $fullDocNum");
      AppLogger.info('ReturnStart',
          'New return for customer ${selectedCustomer.value.custId}, driver ${driver.value?.id}',
          docNum: fullDocNum, docType: 'R');

      // Step 2 fix (new-doc path): separate network error from empty result
      log("STEP 5: Checking API for Existing Document...");
      List<DocMaster> apiRes;
      try {
        apiRes = await getReturnDetails();
      } catch (e) {
        log("❌ Network error fetching return details: $e");
        AppLogger.error(
            'ReturnStart', 'Could not check server for existing return',
            error: e, docNum: fullDocNum, docType: 'R');
        CustomWidget.customSnackBar(
          backgroundColor: Colors.red,
          title: "Connection Error",
          message:
              "Could not connect to server. Check your connection and try again.",
        );
        return;
      }
      log("API Response: ${apiRes.length} items found.");

      lastApiSlNo = (apiRes.isNotEmpty &&
              apiRes[0].docDetails != null &&
              apiRes[0].docDetails!.isNotEmpty)
          ? apiRes[0]
              .docDetails!
              .map((d) => d.slNo ?? 0)
              .reduce((a, b) => a > b ? a : b)
          : 0;
      log("Last API SL No: $lastApiSlNo");

      // **Check Local DB**
      log("STEP 6: Checking Local Database...");
      var fromDB = await DBHelper.getItemsByQuery(
        tableName: DBHelper.docDetail,
        where:
            '${DBHelper.companyDocDetail} = ? AND ${DBHelper.docNumDocDetail} = ? AND ${DBHelper.docTypeDocDetail} = ?',
        whereArgs: [selectedCompany.value?.companyId, fullDocNum, 'R'],
      );
      log(fromDB.toString());
      bool existsInDB = fromDB.isNotEmpty;
      bool existsInAPI = apiRes.isNotEmpty;

      log("Exists in DB: $existsInDB");
      log("Exists in API: $existsInAPI");
      AppLogger.info('ReturnCheck',
          'On device: $existsInDB, on server: $existsInAPI (last server line $lastApiSlNo)',
          docNum: fullDocNum, docType: 'R');

      // **Step 7: Handling Different Cases**
      if (existsInDB && existsInAPI) {
        log("Case 1: Exists in Both API & DB. Showing Dialog...");
        Get.dialog<bool>(
          _showApiDbExistDialog(apiRes, fromDB, fullDocNum, lastApiSlNo),
          barrierDismissible: false,
        ).then((value) {
          if (value == true) {
            _handleContinue(fullDocNum, lastApiSlNo);
          }
        });
      } else if (existsInAPI) {
        log("Case 2: Exists in API Only. Showing Dialog...");
        Get.dialog<bool>(
          _showApiExistDialog(apiRes, fullDocNum, lastApiSlNo),
          barrierDismissible: false,
        ).then((value) {
          if (value == true) {
            _handleContinue(fullDocNum, lastApiSlNo - 1);
          }
        });
      } else if (existsInDB) {
        log("Case 3: Exists in DB Only. Showing Snackbar...");
        CustomWidget.customSnackBar(
          title: "Unfinished!!",
          message:
              "This document exists in unfinished list. Please select from there.",
          backgroundColor: Colors.red,
          duration: 5,
        );
      } else {
        log("Case 4: New Document. Creating Master Entry...");
        _handleContinue(fullDocNum, lastApiSlNo - 1);
      }
    } catch (e, stackTrace) {
      AppLogger.error('ReturnStart', 'onSubmit crashed',
          error: e, stack: stackTrace);
      log("❌ Error in onSubmit: $e");
      log("StackTrace: $stackTrace");
      // Step 5 fix: show actual error so user/support can act on it
      CustomWidget.customSnackBar(
        backgroundColor: Colors.red,
        title: "Error",
        message: "An unexpected error occurred: $e",
      );
    } finally {
      log("Finalizing onSubmit execution...");
      selectIsLoading.value = false;
      log("======== END of onSubmit ========");
    }
  }

  // Future<void> onSubmit(DocMaster? item) async {
  //   log("======== STARTING onSubmit ========");
  //   selectIsLoading.value = true;
  //   FocusManager.instance.primaryFocus?.unfocus();

  //   String fullDocNum;
  //   int lastApiSlNo = 0;

  //   log("STEP 1: Checking if user selected from Unfinished List...");

  //   /// **Handling Unfinished Document Selection**
  //   if (item != null) {
  //     log("User selected from Unfinished List: ${item.docNum}");

  //     fullDocNum = "${item.custID}${item.docNum}";
  //     selectedCustomer.value.custId = item.custID;
  //     selectedCustomer.value.custName = item.custName;
  //     docNumber.value = item.docNum;
  //     docDate.value = item.docDate?.toString() ?? DateTime.now().toString();
  //     driver.value = driverList
  //         .where((element) => element.id == item.pickedBy)
  //         .toList()[0];

  //     // **Fetch API Data**
  //     log("STEP 2: Checking API for existing details...");
  //     var apiRes = await getReturnDetails();
  //     log("API Response: ${apiRes.length} items found.");

  //     lastApiSlNo = (apiRes.isNotEmpty &&
  //             apiRes[0].docDetails != null &&
  //             apiRes[0].docDetails!.isNotEmpty)
  //         ? apiRes[0]
  //             .docDetails!
  //             .map((d) => d.slNo ?? 0)
  //             .reduce((a, b) => a > b ? a : b)
  //         : 0;
  //     log("Last API SL No: $lastApiSlNo");

  //     // **Fetch Local DB Data**
  //     log("STEP 3: Fetching Local DB Data...");
  //     var fromDB = await DBHelper.getItemsByQuery(
  //       tableName: DBHelper.docDetail,
  //       where:
  //           '${DBHelper.companyDocDetail} = ? AND ${DBHelper.docNumDocDetail} = ? AND ${DBHelper.docTypeDocDetail} = ?',
  //       whereArgs: [item.company, fullDocNum, 'R'],
  //     );

  //     List<DocDetail> localItems = fromDB.isNotEmpty
  //         ? fromDB.map((it) => DocDetail.fromJson(it)).toList()
  //         : [];
  //     log("Found ${localItems.length} items in Local DB.");

  //     // **Ensure Unique SL No in DB**
  //     if (localItems.isNotEmpty && lastApiSlNo > 0) {
  //       log("Adjusting SL Numbers...");
  //       int newSlNo = lastApiSlNo + 1;
  //       for (var localItem in localItems) {
  //         localItem.slNo = newSlNo++;
  //       }

  //       await _updateDatabase(
  //         tableName: DBHelper.docDetail,
  //         data: localItems.map((e) => e.toDB()).toList(),
  //       );
  //       log("Updated SL Numbers in Local DB.");
  //     }

  //     // **Set Next SL No and Move to Scan Screen**
  //     log(lastApiSlNo.toString());
  //     scanStartingSlNo.value = lastApiSlNo;
  //     savedItems.value = localItems;
  //     log("Redirecting to Scan Page...$scanStartingSlNo");
  //     log(driverList.toString());
  //     selectIsLoading.value = false;
  //     Get.toNamed(RouteLinks.scanReturns);
  //     return;
  //   }

  //   // **Handling New Document Entry**
  //   log("STEP 4: Handling User-Entered Document...");
  //   if (custController.text.isEmpty ||
  //       docNumController.text.isEmpty ||
  //       docDateController.text.isEmpty ||
  //       selectedDriver.value == null) {
  //     log("❌ Error: Empty Fields Detected!");
  //     CustomWidget.customSnackBar(
  //       backgroundColor: Colors.red,
  //       title: "Empty Fields!!",
  //       message: "The fields should not be empty.",
  //     );
  //     return;
  //   }

  //   docNumber.value = docNumController.text;
  //   docDate.value = docDateController.text;
  //   fullDocNum = "${selectedCustomer.value.custId}${docNumber.value}";
  //   driver.value = selectedDriver.value;

  //   log("User entered details: $fullDocNum");

  //   // **Check API**
  //   log("STEP 5: Checking API for Existing Document...");
  //   var apiRes = await getReturnDetails();
  //   log("API Response: ${apiRes.length} items found.");

  //   lastApiSlNo = (apiRes.isNotEmpty &&
  //           apiRes[0].docDetails != null &&
  //           apiRes[0].docDetails!.isNotEmpty)
  //       ? apiRes[0]
  //           .docDetails!
  //           .map((d) => d.slNo ?? 0)
  //           .reduce((a, b) => a > b ? a : b)
  //       : 0;
  //   log("Last API SL No: $lastApiSlNo");

  //   // **Check Local DB**
  //   log("STEP 6: Checking Local Database...");
  //   var fromDB = await DBHelper.getItemsByQuery(
  //     tableName: DBHelper.docDetail,
  //     where:
  //         '${DBHelper.companyDocDetail} = ? AND ${DBHelper.docNumDocDetail} = ? AND ${DBHelper.docTypeDocDetail} = ?',
  //     whereArgs: [selectedCompany.value.companyId, fullDocNum, 'R'],
  //   );
  //   log(fromDB.toString());
  //   bool existsInDB = fromDB.isNotEmpty;
  //   bool existsInAPI = apiRes.isNotEmpty;

  //   log("Exists in DB: $existsInDB");
  //   log("Exists in API: $existsInAPI");

  //   // **Step 7: Handling Different Cases**
  //   if (existsInDB && existsInAPI) {
  //     log("Case 1: Exists in Both API & DB. Showing Dialog...");
  //     Get.dialog<bool>(
  //       _showApiDbExistDialog(apiRes, fromDB, fullDocNum, lastApiSlNo),
  //       barrierDismissible: false,
  //     ).then((value) {
  //       if (value == true) {
  //         _handleContinue(fullDocNum, lastApiSlNo);
  //       }
  //     });
  //   } else if (existsInAPI) {
  //     log("Case 2: Exists in API Only. Showing Dialog...");
  //     Get.dialog<bool>(
  //       _showApiExistDialog(apiRes, fullDocNum, lastApiSlNo),
  //       barrierDismissible: false,
  //     ).then((value) {
  //       if (value == true) {
  //         _handleContinue(fullDocNum, lastApiSlNo - 1);
  //       }
  //     });
  //   } else if (existsInDB) {
  //     log("Case 3: Exists in DB Only. Showing Snackbar...");
  //     CustomWidget.customSnackBar(
  //       title: "Unfinished!!",
  //       message:
  //           "This document exists in unfinished list. Please select from there.",
  //       backgroundColor: Colors.red,
  //       duration: 5,
  //     );
  //   } else {
  //     log("Case 4: New Document. Creating Master Entry...");
  //     _handleContinue(fullDocNum, lastApiSlNo - 1);
  //   }
  //   selectIsLoading.value = false;
  //   log("======== END of onSubmit ========");
  // }

  /// **Handles Master DB & Moves to Scan Page**
  Future<void> _handleContinue(String fullDocNum, int lastApiSlNo) async {
    log("Handling Continue for: $fullDocNum");
    savedItems.clear();
    scanStartingSlNo.value = lastApiSlNo + 1;
    log("Setting Next SL No: ${scanStartingSlNo.value}");

    var data = {
      DBHelper.companyDocMaster: selectedCompany.value?.companyId,
      DBHelper.custNumDocMaster: selectedCustomer.value.custId,
      DBHelper.docTypeDocMaster: 'R',
      DBHelper.docDateDocMaster: docDate.value,
      DBHelper.custNameDocMaster: selectedCustomer.value.custName,
      DBHelper.docNumDocMaster: fullDocNum,
      DBHelper.statDocMaster: 'N',
      DBHelper.userIDDocMaster: homeCon.user.value.empID,
      DBHelper.scanTimeDocMaster: DateTime.now().toString(),
      DBHelper.pickedByDocMaster: driver.value?.id,
    };

    log("Updating DocMaster in DB...$data");
    var success =
        await _updateDatabase(tableName: DBHelper.docMaster, data: [data]);

    if (success) {
      log("DocMaster Updated Successfully!");
      getUnfinishedDocs();
      _clearFields();
      var fromDB = await DBHelper.getItemsByQuery(
        tableName: DBHelper.docDetail,
        where:
            '${DBHelper.companyDocDetail} = ? AND ${DBHelper.docNumDocDetail} = ? AND ${DBHelper.docTypeDocDetail} = ?',
        whereArgs: [selectedCompany.value?.companyId, fullDocNum, 'R'],
      );

      List<DocDetail> localItems = fromDB.isNotEmpty
          ? fromDB.map((it) => DocDetail.fromJson(it)).toList()
          : [];
      savedItems.value = localItems;
      clearPart();
      Get.toNamed(RouteLinks.scanReturns);
    } else {
      // Step 3 fix: show error so user knows why nothing happened
      log("❌ Failed to Update DocMaster!");
      AppLogger.error('LocalDbError', 'Failed to save return header on device',
          docNum: fullDocNum, docType: 'R');
      CustomWidget.customSnackBar(
        backgroundColor: Colors.red,
        title: "Database Error",
        message: "Failed to save document locally. Please try again.",
      );
    }
  }

  /// **Fetch Return Details from API**
  Future<List<DocMaster>> getReturnDetails() async {
    return await RetrunRepo().getReturnDetails(
      company: selectedCompany.value!.companyId!,
      docNum: "${selectedCustomer.value.custId}${docNumber.value!}",
      docType: 'R',
    );
  }

  /// **Dialog for API & DB Existing Case**
  Widget _showApiDbExistDialog(List<DocMaster> apiRes,
      List<Map<String, dynamic>> fromDB, String fullDocNum, int lastApiSlNo) {
    int apiCount = apiRes[0].docDetails?.length ?? 0;
    int dbCount = fromDB.length;
    return Center(
      child: Material(
        elevation: 15,
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: Container(
          width: Get.width * 0.8,
          decoration: BoxDecoration(
            color: Get.theme.colorScheme.surface, // light/dark aware (UI v2)
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Already Exist!!", style: Get.textTheme.titleLarge),
                SizedBox(height: 20),
                Text(
                  "This document exists in both API ($apiCount items) and local DB ($dbCount items).\n"
                  "Do you want to continue scanning more items?",
                  textAlign: TextAlign.justify,
                  style: Get.textTheme.labelLarge,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ButtonWidget(
                      width: 120,
                      height: 48,
                      title: "No",
                      backgroundColor: Colors.red,
                      onPressed: () => Get.back(result: false),
                    ),
                    ButtonWidget(
                      width: 120,
                      height: 48,
                      title: "Continue",
                      backgroundColor: Colors.green,
                      onPressed: () {
                        // scanStartingSlNo.value = lastApiSlNo + 1;
                        Get.back(result: true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _showApiExistDialog(
      List<DocMaster> apiRes, String fullDocNum, int apiCount) {
    return Center(
      child: Material(
        elevation: 15,
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: Container(
          width: Get.width * 0.8,
          decoration: BoxDecoration(
            color: Get.theme.colorScheme.surface, // light/dark aware (UI v2)
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Already Exist!!", style: Get.textTheme.titleLarge),
                SizedBox(height: 20),
                Text(
                  "The document number: ${apiRes[0].docNum} already exists in data base with $apiCount items.\n"
                  "Do you wish to continue to add more items?",
                  textAlign: TextAlign.justify,
                  style: Get.textTheme.labelLarge,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ButtonWidget(
                      width: 120,
                      height: 48,
                      title: "No",
                      backgroundColor: Colors.red,
                      onPressed: () async {
                        Get.back(result: false);
                      },
                    ),
                    ButtonWidget(
                      width: 120,
                      height: 48,
                      title: "Continue",
                      backgroundColor: Colors.green,
                      onPressed: () async {
                        // await addtoMaster(fullDocNum);
                        Get.back(result: true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearFields() {
    custController.clear();
    docNumController.clear();
    docDateController.clear();
    selectedDriver.value = null;
  }

  void onBarcodeChanged(String value) {
    selectedPart.value = null;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    final trimmedValue = value.trim();

    if (trimmedValue.length == 13) {
      fetchBarcodeDetails(trimmedValue, shouldRequestFocus: true);
      return;
    }

    if (trimmedValue.length >= 10) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        fetchBarcodeDetails(trimmedValue, shouldRequestFocus: true);
      });
    }
  }

  /// **Fetch Part Details from API**
  /// Returns the part found for the selected company (also put in
  /// [selectedPart]), or null. An answer that arrives after the barcode field
  /// has changed is ignored: with a 14-digit barcode the lookup started at the
  /// 13th digit can answer after the full barcode's lookup.
  Future<Part?> fetchBarcodeDetails(String barcode,
      {required bool shouldRequestFocus}) async {
    final result = await RetrunRepo().getPart(query: barcode);
    log(result.toString());

    if (barcodeController.text.trim() != barcode) {
      log("Ignoring lookup for old barcode $barcode");
      return null;
    }

    result.fold(
      (error) {
        // Handle only real API failure here
        if (error != "No Item Found!!") {
          AppLogger.warn(
              'PartLookup', 'Lookup failed for barcode $barcode: $error');
          CustomWidget.customSnackBar(
            title: "Error",
            message: "Unable to fetch item details. Please check the barcode.",
            backgroundColor: Colors.red,
          );
        }
      },
      (parts) {
        if (parts == null || parts.isEmpty) {
          // No parts found by API
          CustomWidget.customSnackBar(
            title: "Not Found!!",
            message:
                "No item found for the entered barcode. Please check again.",
            backgroundColor: Colors.red,
          );
          return;
        }

        // Search for item matching the selected company
        selectedPart.value = parts.firstWhereOrNull(
          (part) => part.company == selectedCompany.value?.companyId,
        );

        if (selectedPart.value == null) {
          // Item exists but doesn't belong to selected company
          CustomWidget.customSnackBar(
            title: "Not Found!!",
            message:
                "No item found for the entered barcode. Please check again.",
            backgroundColor: Colors.red,
          );
          return;
        }

        log(selectedPart.string);

        if (shouldRequestFocus) {
          qtyFocusNode.requestFocus();
        }
      },
    );
    return selectedPart.value;
  }

  void onSavePart() async {
    log("Current scanStartingSlNo: ${scanStartingSlNo.value}");

    if (barcodeController.text.trim().isEmpty) {
      AppLogger.warn('Validation', 'Barcode is required');
      Get.snackbar("Error", "Barcode is required",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (qtyController.text.trim().isEmpty) {
      AppLogger.warn('Validation', 'Quantity is required');
      Get.snackbar("Error", "Quantity is required",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    int? qty = int.tryParse(qtyController.text.trim());
    if (qty == null || qty <= 0) {
      AppLogger.warn('Validation', 'Enter a valid quantity');
      Get.snackbar("Error", "Enter a valid quantity",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (selectedReason.value?.reasonId == null) {
      AppLogger.warn('Validation', 'Select a reason');
      Get.snackbar("Error", "Select a reason",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (selectedReason.value != null &&
        (selectedReason.value?.reasonId == 'NRE' ||
            selectedReason.value?.reasonId == 'EXP') &&
        expiryDate.value == null) {
      AppLogger.warn('Validation', 'Select an expiry date');
      Get.snackbar("Error", "Select an expiry date",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // The item must be known: without it the line has no part number and the
    // phone database refuses it. Not looked up yet (short barcode, or Save
    // tapped before the lookup answered): look it up once now.
    if (selectedPart.value == null) {
      final part = await fetchBarcodeDetails(barcodeController.text.trim(),
          shouldRequestFocus: false);
      if (part == null) {
        // The lookup itself stays silent for "not found" (it also runs while
        // typing), so say it here.
        AppLogger.info('ReturnSave',
            'Not saved: no item for barcode ${barcodeController.text.trim()}');
        CustomWidget.customSnackBar(
          title: "Item not found",
          message:
              "No item for barcode ${barcodeController.text.trim()} in this company. Check the barcode and scan again.",
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    String fullDocNum = "${selectedCustomer.value.custId}${docNumber.value}";

    try {
      // Fetch the highest SlNo in the database
      var dbItems = await DBHelper.getItemsByQuery(
        tableName: DBHelper.docDetail,
        where:
            '${DBHelper.companyDocDetail} = ? AND ${DBHelper.docNumDocDetail} = ? AND ${DBHelper.docTypeDocDetail} = ?',
        whereArgs: [selectedCompany.value?.companyId, fullDocNum, 'R'],
      );

      int lastDbSlNo = dbItems.isNotEmpty
          ? dbItems
              .map((d) => d[DBHelper.slNoDocDetail] as int? ?? 0)
              .reduce((a, b) => a > b ? a : b)
          : scanStartingSlNo.value;

      int nextSlNo = lastDbSlNo + 1;

      log("Next SL No: $nextSlNo");

      // Prepare data
      var data = {
        DBHelper.companyDocDetail: selectedCompany.value?.companyId,
        DBHelper.docNumDocDetail: fullDocNum,
        DBHelper.docTypeDocDetail: 'R',
        DBHelper.barcodeDocDetail: barcodeController.text,
        DBHelper.partNumDocDetail: selectedPart.value?.partNum,
        DBHelper.partNameDocDetail: selectedPart.value?.partName,
        DBHelper.brandDocDetail: selectedPart.value?.brand,
        DBHelper.shipQtyDocDetail: 0,
        DBHelper.checkQtyDocDetail: qty,
        DBHelper.statDocDetail: 'N',
        DBHelper.reasonCodeDocDetail: selectedReason.value?.reasonId,
        DBHelper.reasonNameDocDetail: selectedReason.value?.reason,
        DBHelper.expiryDateDocDetail: expiryDate.value,
      };

      log("Saving Item: $data");

      var res = await DBHelper.insertItemWithSlNo(
        tableName: DBHelper.docDetail,
        data: data,
        startingSlNo: nextSlNo,
      );

      log("Insert Result: $res");

      if (res > 0) {
        scanStartingSlNo.value = nextSlNo + 1; // Update SL No for next entry

        var updatedDbItems = await DBHelper.getItemsByQuery(
          tableName: DBHelper.docDetail,
          where:
              '${DBHelper.companyDocDetail} = ? AND ${DBHelper.docNumDocDetail} = ? AND ${DBHelper.docTypeDocDetail} = ?',
          whereArgs: [selectedCompany.value?.companyId, fullDocNum, 'R'],
        );

        savedItems.value = updatedDbItems
            .map((element) => DocDetail.fromJson(element))
            .toList();
        log(savedItems.toString());
        barcodeController.clear();
        qtyController.clear();
        reasonController.clear();
        expiryDateController.clear();
        selectedReason.value = null;
        selectedPart.value = null;
        expiryDate.value = null;
        FocusManager.instance.primaryFocus?.unfocus();
        barcodeFocusNode.requestFocus();
      } else {
        AppLogger.error('LocalDbError', 'Failed to save return line on device',
            docNum: fullDocNum,
            docType: 'R',
            details: 'Barcode ${barcodeController.text}');
        CustomWidget.customSnackBar(
          title: "Error!!",
          message: "Something went wrong, please refresh the app",
          backgroundColor: Colors.red,
        );
      }
    } catch (e, st) {
      AppLogger.error('LocalDbError', 'Saving return line crashed',
          error: e, stack: st, docNum: fullDocNum, docType: 'R');
      CustomWidget.customSnackBar(
        title: "Not saved",
        message: "The item could not be saved. Please scan it again.",
        backgroundColor: Colors.red,
      );
    }

    update();
  }

  void onConfirm() async {
    var dbItems = await DBHelper.getItemsByQuery(
        tableName: DBHelper.docDetail,
        where:
            '${DBHelper.companyDocDetail} = ? and ${DBHelper.docNumDocDetail} = ? and ${DBHelper.docTypeDocDetail} = ?',
        whereArgs: [
          selectedCompany.value?.companyId,
          "${selectedCustomer.value.custId}${docNumber.value}",
          'R'
        ]);

    savedItems.value =
        dbItems.map((element) => DocDetail.fromJson(element)).toList();
    log(dbItems.toString());
    log(savedItems.toString());
    if (savedItems.isEmpty) {
      CustomWidget.customSnackBar(
        title: "No Items Found!!",
        message: "No Items have been scanned, please scan items and try again",
        backgroundColor: Colors.red,
      );
      return;
    } else {
      log(json.encode(savedItems).toString());
      consolidateSavedItems();
      getTotalQty();
      AppLogger.info('ReturnReview',
          '${savedItems.length} lines (${consolidatedSavedItems.length} after merge), total qty ${totalQty.value}',
          docNum: "${selectedCustomer.value.custId}${docNumber.value}",
          docType: 'R');
      log(json.encode(consolidatedSavedItems));
      Get.toNamed(RouteLinks.finlaizeReturns);
    }
  }

  Future<void> onDeleteItem(int slNo) async {
    log("🚀 Attempting to delete item with SlNo: $slNo");

    String fullDocNum = "${selectedCustomer.value.custId}${docNumber.value}";

    // **Step 1: Call DBHelper function**
    bool success = await DBHelper.deleteItemAndShiftSlNo(
      tableName: DBHelper.docDetail,
      company: selectedCompany.value!.companyId!,
      docNum: fullDocNum,
      docType: 'R',
      slNo: slNo,
    );

    if (success) {
      log("✔ Item deleted & SL numbers updated.");
      AppLogger.info('ReturnDeleteLine', 'Deleted line $slNo',
          docNum: fullDocNum, docType: 'R');

      // **Step 2: Fetch updated list**
      var updatedDbItems = await DBHelper.getItemsByQuery(
        tableName: DBHelper.docDetail,
        where:
            '${DBHelper.companyDocDetail} = ? AND ${DBHelper.docNumDocDetail} = ? AND ${DBHelper.docTypeDocDetail} = ?',
        whereArgs: [selectedCompany.value?.companyId, fullDocNum, 'R'],
      );

      // **Step 3: Update UI with new list**
      savedItems.value =
          updatedDbItems.map((e) => DocDetail.fromJson(e)).toList();

      log("✔ Updated savedItems list.");
    } else {
      log("❌ Error: Item could not be deleted.");
      AppLogger.error('LocalDbError', 'Failed to delete line $slNo',
          docNum: fullDocNum, docType: 'R');
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Failed to delete item. Please try again.",
        backgroundColor: Colors.red,
      );
    }

    update();
  }

  void consolidateSavedItems() {
    final Map<String, DocDetail> consolidatedMap = {};

    for (var item in savedItems) {
      String expiryKey =
          item.expiryDate?.isNotEmpty == true ? item.expiryDate! : "NO_EXPIRY";
      String key = "${item.barcode}-${item.reasonCode}-$expiryKey";
      log(key.toString());
      if (consolidatedMap.containsKey(key)) {
        consolidatedMap[key]!.checkQty =
            (consolidatedMap[key]!.checkQty ?? 0) + (item.checkQty ?? 0);
      } else {
        consolidatedMap[key] = DocDetail(
          company: item.company,
          docNum: item.docNum,
          slNo: item.slNo,
          barcode: item.barcode,
          brand: item.brand,
          docType: item.docType,
          shipQty: item.shipQty,
          checkQty: item.checkQty,
          partNum: item.partNum,
          partName: item.partName,
          stat: item.stat,
          reasonCode: item.reasonCode,
          reasonName: item.reasonName,
          expiryDate: item.expiryDate,
        );
      }
    }

    consolidatedSavedItems.value = consolidatedMap.values.toList();
  }

  // void consolidateSavedItems() {
  //   final Map<String, DocDetail> consolidatedMap = {};

  //   for (var item in savedItems) {
  //     String key = "${item.barcode}-${item.reasonCode}";

  //     if (consolidatedMap.containsKey(key)) {
  //       consolidatedMap[key]!.checkQty =
  //           (consolidatedMap[key]!.checkQty ?? 0) + (item.checkQty ?? 0);
  //     } else {
  //       consolidatedMap[key] = DocDetail(
  //         company: item.company,
  //         docNum: item.docNum,
  //         slNo: item.slNo,
  //         barcode: item.barcode,
  //         brand: item.brand,
  //         docType: item.docType,
  //         shipQty: item.shipQty,
  //         checkQty: item.checkQty,
  //         partNum: item.partNum,
  //         partName: item.partName,
  //         stat: item.stat,
  //         reasonCode: item.reasonCode,
  //         reasonName: item.reasonName,
  //         expiryDate: item.expiryDate,
  //       );
  //     }
  //   }
  //   consolidatedSavedItems.value = consolidatedMap.values.toList();
  // }

  Future<bool> finalize() async {
    finalizeIsLoading.value = true;
    final logDocNum = "${selectedCustomer.value.custId}${docNumber.value}";
    final company = selectedCompany.value?.companyId ?? '';
    AppLogger.info('FinalizeStart',
        '${consolidatedSavedItems.length} lines, total qty ${totalQty.value}',
        docNum: logDocNum, docType: 'R');
    try {
      // Fetch existing API records to determine next SlNo — network errors throw, empty = new doc
      List<DocMaster> apiRes;
      try {
        apiRes = await getReturnDetails();
      } catch (e) {
        AppLogger.error(
            'FinalizeFailed', 'Could not check server before upload',
            error: e, docNum: logDocNum, docType: 'R');
        log("Network error fetching return details: $e");
        CustomWidget.customSnackBar(
          title: "Connection Error",
          message:
              "Could not connect to server. Check your connection and try again.",
          backgroundColor: Colors.red,
        );
        return false;
      }

      // An earlier attempt for this return may have reached the server even
      // though the phone got no answer (e.g. timeout). If those exact lines are
      // there, it was saved: do not send it a second time.
      final pending = await _loadPendingUpload(company, logDocNum);
      if (pending != null) {
        if (uploadIsOnServer(_serverLines(apiRes), pending)) {
          AppLogger.warn('FinalizeRecovered',
              'Earlier upload had reached the server; not sent again',
              docNum: logDocNum, docType: 'R');
          return await _clearAfterUpload(company, logDocNum);
        }
        await _clearPendingUpload(company, logDocNum);
      }

      int apiCount = apiRes.isNotEmpty
          ? (apiRes[0].docDetails?.map((d) => d.slNo ?? 0).fold<int>(0, max) ??
              0)
          : 0;
      log("API Max SlNo: $apiCount");
      apiCount += 1;
      log("Next SlNo start: $apiCount");

      // Prepare master data
      DateTime parsedDate = DateFormat("dd-MM-yyyy")
          .parse(docDate.value ?? DateTime.now().toString());
      String formattedDate = DateFormat("yyyy-MM-dd").format(parsedDate);
      log(formattedDate);
      var masterData = {
        DBHelper.companyDocMaster: selectedCompany.value?.companyId,
        DBHelper.custNumDocMaster: selectedCustomer.value.custId,
        DBHelper.custNameDocMaster: selectedCustomer.value.custName,
        DBHelper.docNumDocMaster: docNumber.value,
        DBHelper.docDateDocMaster: formattedDate,
        DBHelper.statDocMaster: 'Y',
        DBHelper.userIDDocMaster: homeCon.user.value.empID,
        DBHelper.scanTimeDocMaster: DateTime.now().toString(),
        DBHelper.pickedByDocMaster: driver.value?.id,
      };

      // Prepare detailed data with sequential SlNo
      var toUpload = consolidatedSavedItems.asMap().entries.map((entry) {
        var item = entry.value.toJson();
        log("Item Count: ${item[DBHelper.slNoDocDetail]}");
        log("API Item Count: $apiCount");
        item[DBHelper.statDocDetail] = 'Y';
        item[DBHelper.slNoDocDetail] = apiCount++;
        return item;
      }).toList();

      // Convert to `DocMaster` format
      var docMaster = generateReturnJson(masterData, toUpload);
      log(docMaster);

      // Remember exactly what is being sent, until we know whether it arrived.
      final sending = pendingLinesOf(toUpload);
      await _savePendingUpload(company, logDocNum, sending);

      // Upload to API
      bool apiSuccess = await RetrunRepo().updateReturn(master: docMaster);
      log(apiSuccess.toString());
      if (!apiSuccess) {
        // The server saves a return all-or-nothing, so asking it now tells us
        // whether this upload arrived after all.
        bool? onServer;
        try {
          onServer =
              uploadIsOnServer(_serverLines(await getReturnDetails()), sending);
        } catch (e) {
          onServer = null; // server not reachable: unknown
        }

        if (onServer == true) {
          AppLogger.warn('FinalizeRecovered',
              'No answer to CreateReturn, but the server has the lines',
              docNum: logDocNum, docType: 'R');
          return await _clearAfterUpload(company, logDocNum);
        }

        if (onServer == false) {
          await _clearPendingUpload(company, logDocNum);
          log("API update failed.");
          AppLogger.error(
              'FinalizeFailed', 'Server did not accept CreateReturn',
              docNum: logDocNum, docType: 'R');
          CustomWidget.customSnackBar(
            title: "Upload Failed",
            message: "Failed to upload return to server. Please try again.",
            backgroundColor: Colors.red,
          );
          return false;
        }

        // Unknown: keep the record; the next Finalize checks the server first.
        AppLogger.error('FinalizeUnconfirmed',
            'No answer to CreateReturn and the server could not be checked',
            docNum: logDocNum, docType: 'R');
        CustomWidget.customSnackBar(
          title: "Not confirmed",
          message:
              "The server did not answer, so the return may already be saved. "
              "Do not scan it again. When the connection is back, tap Finalize "
              "again: the app checks the server first and never sends it twice.",
          backgroundColor: Colors.red,
          duration: 8,
        );
        return false;
      }

      // API succeeded — clear local DB
      return await _clearAfterUpload(company, logDocNum);
    } catch (e, st) {
      AppLogger.error('FinalizeFailed', 'finalize crashed',
          error: e, stack: st, docNum: logDocNum, docType: 'R');
      log("Error in finalize(): $e");
      CustomWidget.customSnackBar(
        title: "Unexpected Error",
        message: "An error occurred: $e",
        backgroundColor: Colors.red,
      );
      return false;
    } finally {
      finalizeIsLoading.value = false;
    }
  }

  /// Removes the uploaded return from this phone. Returns true: the return IS
  /// on the server (even if clearing the phone fails, it must not be re-sent).
  Future<bool> _clearAfterUpload(String company, String fullDocNum) async {
    await _clearPendingUpload(company, fullDocNum);

    var resMaster = await DBHelper.deleteItemsByQuery(
        tableName: DBHelper.docMaster,
        where:
            '${DBHelper.companyDocMaster} = ? and ${DBHelper.docNumDocMaster} = ? and ${DBHelper.docTypeDocMaster} = ?',
        whereArgs: [company, fullDocNum, 'R']);
    log(resMaster.toString());

    var resDet = await DBHelper.deleteItemsByQuery(
        tableName: DBHelper.docDetail,
        where:
            '${DBHelper.companyDocDetail} = ? and ${DBHelper.docNumDocDetail} = ? and ${DBHelper.docTypeDocDetail} = ?',
        whereArgs: [company, fullDocNum, 'R']);
    log(resDet.toString());

    if (resDet != -1 && resMaster != -1) {
      log("DB cleanup successful.");
      AppLogger.info('FinalizeDone', 'Return uploaded and cleared from device',
          docNum: fullDocNum, docType: 'R');
      savedItems.clear();
      consolidatedSavedItems.clear();
      // selectedCustomer.value = Customer();
      selectedPart.value = null;
    } else {
      // Upload succeeded but local cleanup failed — warn user, do NOT let them retry (would double-upload)
      log("DB cleanup failed after successful API upload.");
      AppLogger.error(
          'FinalizeCleanup', 'Uploaded, but clearing device data failed',
          docNum: fullDocNum, docType: 'R');
      CustomWidget.customSnackBar(
        title: "Warning",
        message:
            "Return was uploaded to server but local data cleanup failed. Please contact support.",
        backgroundColor: Colors.orange,
      );
    }
    return true;
  }

  static List<DocDetail> _serverLines(List<DocMaster> apiRes) =>
      apiRes.isNotEmpty ? (apiRes[0].docDetails ?? const []) : const [];

  /// What identifies an uploaded line on the server: number, part, quantity
  /// and reason.
  static List<Map<String, dynamic>> pendingLinesOf(
          List<Map<String, dynamic>> toUpload) =>
      [
        for (final l in toUpload)
          {
            'SlNo': l[DBHelper.slNoDocDetail],
            'PartNum': l[DBHelper.partNumDocDetail],
            'CheckQty': l[DBHelper.checkQtyDocDetail],
            'ReasonCode': l[DBHelper.reasonCodeDocDetail],
          }
      ];

  /// True when every sent line is on the server with the same number, part,
  /// quantity and reason. CreateReturn saves all lines or none, so this tells
  /// whether that upload arrived.
  static bool uploadIsOnServer(
      List<DocDetail> serverLines, List<Map<String, dynamic>> sent) {
    if (sent.isEmpty) return false;
    final bySlNo = {for (final l in serverLines) l.slNo: l};
    return sent.every((p) {
      final s = bySlNo[p['SlNo']];
      return s != null &&
          (s.partNum ?? '') == (p['PartNum'] ?? '') &&
          s.checkQty == p['CheckQty'] &&
          (s.reasonCode ?? '') == (p['ReasonCode'] ?? '');
    });
  }

  static String _pendingKey(String company, String fullDocNum) =>
      'pendingReturnUpload|$company|$fullDocNum';

  Future<void> _savePendingUpload(String company, String fullDocNum,
      List<Map<String, dynamic>> lines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey(company, fullDocNum), jsonEncode(lines));
  }

  Future<List<Map<String, dynamic>>?> _loadPendingUpload(
      String company, String fullDocNum) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_pendingKey(company, fullDocNum));
      if (text == null) return null;
      return (jsonDecode(text) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      log("Could not read pending upload: $e");
      return null;
    }
  }

  Future<void> _clearPendingUpload(String company, String fullDocNum) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey(company, fullDocNum));
  }

  void getTotalQty() {
    var entries = consolidatedSavedItems
        .map<int>((element) => element.checkQty ?? 0)
        .toList();
    log(entries.toString());
    int total = entries.reduce((a, b) => a + b);
    totalQty.value = total;
    log("Total: ${totalQty.value}");
  }

  Future<bool> _updateDatabase({
    required String tableName,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      /// Insert new records
      final insertCount =
          await DBHelper.bulkInsert(tableName: tableName, items: data);
      log("$insertCount rows inserted into $tableName.");
      return true;
    } catch (e, stacktrace) {
      AppLogger.error('LocalDbError', 'Failed to write $tableName',
          error: e, stack: stacktrace);
      log("Database error on table $tableName: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Database Error",
        message: "Failed to update $tableName.",
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  String generateReturnJson(
      Map<String, dynamic> masterData, List<Map<String, dynamic>> detailsData) {
    // Construct JSON structure
    final Map<String, dynamic> returnJson = {
      "SReturnMaster": {
        "Company": masterData['Company'],
        "DocNum": masterData['DocNum'],
        "DocType": masterData['DocType'] ?? 'R',
        "DocDate": masterData['DocDate'],
        "CustID": masterData['CustNum'],
        "Stat": masterData['Stat'],
        "UserID": masterData['UserID'],
        "ScanTime": masterData['ScanTime'],
        "PickedBy": masterData['PickedBy'],
        "RtnDetails": detailsData.asMap().entries.map((entry) {
          var item = entry.value;
          return {
            "Company": item['Company'],
            "DocNum": item['DocNum'],
            "DocType": item['DocType'],
            "SlNo": item['SlNo'].toString(),
            "PartNum": item['PartNum'],
            "ShipQty": "0",
            "CheckQty": item['CheckQty'],
            "Stat": item['Stat'],
            "ReasonCode": item['ReasonCode'],
            "ExpDate": item['ExpDate']
          };
        }).toList(),
      }
    };

    // Convert to JSON string
    String jsonString = jsonEncode([returnJson]);
    log(jsonString); // Optional: Log for debugging
    return jsonString;
  }

  Future<bool> removeUnfinished(DocMaster item) async {
    try {
      int res = await DBHelper.deleteItem(
        tableName: DBHelper.docMaster,
        columnName: DBHelper.docNumDocMaster,
        condition: "${item.custID}${item.docNum}",
      );
      log(res.toString());
      int res2 = await DBHelper.deleteItem(
        tableName: DBHelper.docDetail,
        columnName: DBHelper.docNumDocDetail,
        condition: "${item.custID}${item.docNum}",
      );
      log(res2.toString());

      if (res > 0 && res2 != -1) {
        AppLogger.warn(
            'ReturnDiscard', 'User deleted unfinished return from device',
            docNum: "${item.custID}${item.docNum}", docType: 'R');
        CustomWidget.customSnackBar(
          title: "Success",
          message: "Deleted Successfully",
          backgroundColor: Colors.green,
        );

        // Refresh the list
        unFinishedDocs.remove(item);
        return true; // Deletion was successful
      } else {
        CustomWidget.customSnackBar(
          title: "Error",
          message: "Deletion failed. Please try again.",
          backgroundColor: Colors.red,
        );
        return false; // Deletion failed
      }
    } catch (e, st) {
      AppLogger.error('ReturnDiscard', 'removeUnfinished crashed',
          error: e, stack: st);
      CustomWidget.customSnackBar(
        title: "Error",
        message: "An error occurred: $e",
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  void getUnfinishedDocs() async {
    unFinishedDocs.clear();
    var items = await DBHelper.getItemsByQuery(
      tableName: DBHelper.docMaster,
      where:
          "${DBHelper.statDocMaster} = ? and ${DBHelper.docTypeDocMaster} = ? ",
      whereArgs: ['N', 'R'],
    );
    unFinishedDocs.value = items.map((it) => DocMaster.fromJson(it)).toList();
    final counts = await DBHelper.getItemsByRawQuery(
        "SELECT ${DBHelper.companyDocDetail} AS C, ${DBHelper.docNumDocDetail} AS D, "
        "COUNT(*) AS N, SUM(${DBHelper.checkQtyDocDetail}) AS Q FROM ${DBHelper.docDetail} "
        "WHERE ${DBHelper.docTypeDocDetail} = 'R' GROUP BY ${DBHelper.companyDocDetail}, ${DBHelper.docNumDocDetail}");
    unfinishedCounts.value = {
      for (final r in counts)
        countKey(r['C'] as String?, r['D'] as String?): (
          (r['N'] as int?) ?? 0,
          (r['Q'] as int?) ?? 0
        )
    };
    update();
    log(unFinishedDocs.toString());
  }
}
