import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
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

class ReturnController extends GetxController {
  var custController = TextEditingController();
  var docNumController = TextEditingController();
  var docDateController = TextEditingController();
  var reasonController = TextEditingController();
  var expiryDateController = TextEditingController();
  var custSuggestions = <Customer>[].obs;
  var unFinishedDocs = <DocMaster>[].obs;
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
    } catch (e) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Failed to load companies. Error: $e",
      );
    }
  }

  void selectComapny(Company? company) {
    selectedCompany.value = company;
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
    } catch (e) {
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

        selectedCompany.value =
            companyList.firstWhere((test) => test.companyId == item.company);
        fullDocNum = "${item.custID}${item.docNum}";
        selectedCustomer.value.custId = item.custID;
        selectedCustomer.value.custName = item.custName;
        docNumber.value = item.docNum;
        docDate.value = item.docDate?.toString() ?? DateTime.now().toString();
        driver.value =
            driverList.firstWhere((element) => element.id == item.pickedBy);

        // **Fetch API Data**
        log("STEP 2: Checking API for existing details...");
        var apiRes = await getReturnDetails();
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

        // **Ensure Unique SL No in DB**
        if (localItems.isNotEmpty && lastApiSlNo > 0) {
          log("Adjusting SL Numbers...");
          int newSlNo = lastApiSlNo + 1;
          for (var localItem in localItems) {
            localItem.slNo = newSlNo++;
          }

          await _updateDatabase(
            tableName: DBHelper.docDetail,
            data: localItems.map((e) => e.toDB()).toList(),
          );
          log("Updated SL Numbers in Local DB.");
        }

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

      docNumber.value = docNumController.text;
      docDate.value = docDateController.text;
      fullDocNum = "${selectedCustomer.value.custId}${docNumber.value}";
      driver.value = selectedDriver.value;

      log("User entered details: $fullDocNum");

      // **Check API**
      log("STEP 5: Checking API for Existing Document...");
      var apiRes = await getReturnDetails();
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
      log("❌ Error in onSubmit: $e");
      log("StackTrace: $stackTrace");
      CustomWidget.customSnackBar(
        backgroundColor: Colors.red,
        title: "Error",
        message: "Something went wrong. Please try again.",
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
      log("❌ Failed to Update DocMaster!");
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
            color: Colors.white,
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
            color: Colors.white,
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
  Future<void> fetchBarcodeDetails(String barcode,
      {required bool shouldRequestFocus}) async {
    final result = await RetrunRepo().getPart(query: barcode);
    log(result.toString());

    result.fold(
      (error) {
        // Handle only real API failure here
        if (error != "No Item Found!!") {
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
  }

  void onSavePart() async {
    log("Current scanStartingSlNo: ${scanStartingSlNo.value}");

    if (barcodeController.text.trim().isEmpty) {
      Get.snackbar("Error", "Barcode is required",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (qtyController.text.trim().isEmpty) {
      Get.snackbar("Error", "Quantity is required",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    int? qty = int.tryParse(qtyController.text.trim());
    if (qty == null || qty <= 0) {
      Get.snackbar("Error", "Enter a valid quantity",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (selectedReason.value?.reasonId == null) {
      Get.snackbar("Error", "Select a reason",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (selectedReason.value != null &&
        (selectedReason.value?.reasonId == 'NRE' ||
            selectedReason.value?.reasonId == 'EXP') &&
        expiryDate.value == null) {
      Get.snackbar("Error", "Select an expiry date",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    String fullDocNum = "${selectedCustomer.value.custId}${docNumber.value}";

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

      savedItems.value =
          updatedDbItems.map((element) => DocDetail.fromJson(element)).toList();
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
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Something went wrong, please refresh the app",
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
    try {
      // see if any updates happened in api first
      var apiRes = await getReturnDetails();
      int apiCount = apiRes.isNotEmpty ? apiRes[0].docDetails?.length ?? 0 : 0;
      log("API Item Count: $apiCount");
      apiCount += 1;
      log("API Item Count: $apiCount");
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

      // Update to API first
      bool apiSuccess = await RetrunRepo().updateReturn(master: docMaster);
      log(apiSuccess.toString());
      if (!apiSuccess) {
        log("API update failed.");
        finalizeIsLoading.value = false;
        return false;
      }

      // delete the particular item from master and details
      var resMaster = await DBHelper.deleteItemsByQuery(
          tableName: DBHelper.docMaster,
          where:
              '${DBHelper.companyDocMaster} = ? and ${DBHelper.docNumDocMaster} = ? and ${DBHelper.docTypeDocMaster} = ?',
          whereArgs: [
            selectedCompany.value?.companyId,
            "${selectedCustomer.value.custId}${docNumber.value}",
            'R'
          ]);
      log(resMaster.toString());
      var resDet = await DBHelper.deleteItemsByQuery(
          tableName: DBHelper.docDetail,
          where:
              '${DBHelper.companyDocDetail} = ? and ${DBHelper.docNumDocDetail} = ? and ${DBHelper.docTypeDocDetail} = ?',
          whereArgs: [
            selectedCompany.value?.companyId,
            "${selectedCustomer.value.custId}${docNumber.value}",
            'R'
          ]);
      log(resDet.toString());
      if (resDet != -1 && resMaster != -1 && apiSuccess) {
        log("DB update successful: Master & Details updated.");
        finalizeIsLoading.value = false;
        return true;
      } else {
        log("DB update failed.");
      }
      savedItems.clear();
      consolidatedSavedItems.clear();
      selectedCustomer.value = Customer();
      selectedPart.value = null;
    } catch (e) {
      log("Error in finalize(): $e");
    }

    finalizeIsLoading.value = false;
    return false; // Return false if any step fails
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
    } catch (e) {
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
    update();
    log(unFinishedDocs.toString());
  }
}
