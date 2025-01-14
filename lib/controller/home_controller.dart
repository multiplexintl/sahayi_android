import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/connectivity_controller.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/model/invoice/inv_detail.dart';
import 'package:sahayi_android/model/invoice/invoice.dart';
import 'package:sahayi_android/model/user.dart';
import 'package:sahayi_android/repo/home_repo.dart';
import 'package:sahayi_android/routes.dart';
import 'package:vibration/vibration.dart';

class HomeController extends GetxController {
  var date = RxString('');
  var connectionStatus = false.obs;
  TextEditingController invController = TextEditingController();
  TextEditingController barcodeController = TextEditingController();
  TextEditingController qtyController = TextEditingController();
  var user = Rx<User>(User());
  var invoice = Rx<DocMaster>(DocMaster());
  var syncIsLoading = false.obs;
  var scanIsLoading = false.obs;
  var clearIsLoading = false.obs;
  var scannedItem = Rx<DocDetail>(DocDetail());
  final ScrollController scrollController = ScrollController();
  final player = AudioPlayer();
  final String errorSound = "sound/wrong_barcode_1.wav";
  var lastInvoices = <DocMaster>[].obs;
  var isInvoice = true.obs;
  Rxn<Company> selectedCompany = Rxn<Company>();
  List<Company> companyList = [];

  @override
  void onInit() async {
    super.onInit();
    user.value = Get.arguments;
    Get.put(ConnectivityController());
    getCompanies();
    getSystemDate();
    await getLastInvoices();
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

  Future<void> getLastInvoices() async {
    var lastInvoicesCheck =
        await DBHelper.getAllItems(tableName: DBHelper.lastInvoices);
    // log("Last Invoice Table: $lastInvoicesCheck");
    var list =
        lastInvoicesCheck.map((json) => DocMaster.fromJson(json)).toList();
    lastInvoices.value = list.reversed.toList();
  }

  void getSystemDate() {
    var now = DateTime.now();
    date.value = DateFormat("dd-MM-yyyy").format(now);
  }

  void checkValidation() {
    if (invController.value.text.isEmpty &&
        selectedCompany.value?.companyId == null) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Invoice Number and Company should not be empty",
        backgroundColor: Colors.red,
      );
    } else if (invController.value.text.isEmpty) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Invoice Number should not be empty",
        backgroundColor: Colors.red,
      );
    } else if (selectedCompany.value?.companyId == null) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Company should not be empty",
        backgroundColor: Colors.red,
      );
    } else {
      syncInvoice();
    }
  }

  Future<void> syncInvoice() async {
    try {
      syncIsLoading.value = true;
      log("User Info: ${user.value}");

      // Check if the invMaster table is empty
      // var invDB = await DBHelper.getAllItems(tableName: DBHelper.docMaster);
      var invDB2 = await DBHelper.getItems(
          tableName: DBHelper.docMaster,
          columnName: DBHelper.statDocMaster,
          condition: 'N');
      log(invDB2.toString());

      if (invDB2.isNotEmpty) {
        var data = invDB2.map((json) => DocMaster.fromJson(json)).toList();
        // Show a confirmation dialog if data exists
        CustomWidget.customDialogue(
          title: "Invoice Exists!",
          subTitle:
              "An invoice with invoice number : ${data[0].docNum} already exists in the database without completion. Continuing will overwrite the existing data. Do you want to proceed?",
          onPressed: () async {
            Get.back(); // Close dialog
            await _syncAndUpdateInvoice();
          },
          onPressedBack: () => Get.back(),
        );
      } else {
        //data does not exists, proceed directly with sync
        await _syncAndUpdateInvoice();
      }
    } catch (e, stacktrace) {
      log("Error in syncInvoice: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Exception",
        message: "An error occurred: $e",
        backgroundColor: Colors.red,
      );
    } finally {
      syncIsLoading.value = false;
    }
  }

  ///e method to handle the sync and update logic
  Future<void> _syncAndUpdateInvoice() async {
    try {
      syncIsLoading.value = true;

      /// to sync the invoice with API call
      final syncResult = await HomeRepo().syncInvoice(
          company: selectedCompany.value!.companyId!,
          docNum: invController.text,
          docType: isInvoice.value ? "I" : "T");

      syncResult.fold(
        (failureMessage) {
          CustomWidget.customSnackBar(
            title: "Error!",
            message: failureMessage,
            backgroundColor: Colors.red,
          );
        },
        (isSuccessful) async {
          /// successful, fetch invoice details
          final invoiceList = await HomeRepo().getInvoiceDetails(
            company: selectedCompany.value!.companyId!,
            docNum: invController.text,
            docType: isInvoice.value ? "I" : "T",
          );

          if (invoiceList.isEmpty) {
            CustomWidget.customSnackBar(
              title: "Error!!",
              message: "No invoice found. Try again.",
              backgroundColor: Colors.red,
            );
            return;
          }

          ///invoice observable and prepare data
          var tempInvList = invoiceList[0];
          tempInvList.userId = user.value.empID;

          /// master table data and update the database
          final masterTableData = tempInvList.toDB();
          await _updateDatabase(
            tableName: DBHelper.docMaster,
            data: [masterTableData],
            delete: true,
          );
          log(masterTableData.toString());

          /// detail table data and update the database
          final detailTableData =
              tempInvList.docDetails?.map((e) => e.toDB()).toList() ?? [];
          await _updateDatabase(
            tableName: DBHelper.docDetail,
            data: detailTableData,
            delete: true,
          );

          /// last invoice table data and update the database
          final lastInvTableData = {
            DBHelper.userIDLastInvoices: tempInvList.userId,
            DBHelper.docNumLastInvoices: tempInvList.docNum,
            DBHelper.statLastInvoices: tempInvList.stat
          };
          await DBHelper().insertOrUpdateWithLimit(
            tableName: DBHelper.lastInvoices,
            keyColumn: DBHelper.docNumLastInvoices,
            condition: tempInvList.docNum,
            data: lastInvTableData,
          );

          ///the data in the last invoice table (Optional Logging)
          var lastInvoicesCheck =
              await DBHelper.getAllItems(tableName: DBHelper.lastInvoices);
          log("Last Invoice Table: $lastInvoicesCheck");
          var list = lastInvoicesCheck
              .map((json) => DocMaster.fromJson(json))
              .toList();
          log(list.toString());
          lastInvoices.value = list.reversed.toList();

          ///ccess message
          final itemCount = tempInvList.docDetails?.length ?? 0;
          final itemLabel = itemCount == 1 ? "item" : "items";

          CustomWidget.customDialogue(
            title: "Success!!",
            subTitle:
                "$itemCount $itemLabel of Invoice Num ${tempInvList.docNum} fetched successfully.",
            onPressed: () {
              Get.back();
              Get.back();
            },
          );
        },
      );
    } catch (e, stacktrace) {
      log("Error in _syncAndUpdateInvoice: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Exception",
        message: "An error occurred: $e",
        backgroundColor: Colors.red,
      );
    } finally {
      syncIsLoading.value = false;
    }
  }

  /// Helper method for handling database operations with exception handling
  Future<void> _updateDatabase(
      {required String tableName,
      required List<Map<String, dynamic>> data,
      required bool delete}) async {
    try {
      if (delete) {
        /// Delete existing records
        final deleteCount = await DBHelper.deleteAllItem(tableName: tableName);
        log("Deleted $deleteCount rows from $tableName.");
      }

      /// Insert new records
      final insertCount =
          await DBHelper.bulkInsert(tableName: tableName, items: data);
      log("$insertCount rows inserted into $tableName.");
    } catch (e, stacktrace) {
      log("Database error on table $tableName: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Database Error",
        message: "Failed to update $tableName.",
        backgroundColor: Colors.red,
      );
      throw Exception("Database update failed");
    }
  }

  // auto scroll
  void scrollToBarcode(String barcode) {
    final index =
        invoice.value.docDetails?.indexWhere((item) => item.barcode == barcode);

    if (index != null && index != -1) {
      // Assign the matched item to the reactive variable
      scannedItem.value = invoice.value.docDetails![index];
      scrollController.animateTo(
        index * 63, // Adjust item height if necessary
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {}
  }

  void testSave(String barcode, int qty) {
    if (kDebugMode) {
      log(barcode.toString());
      barcodeController.clear();
      barcodeController.text = barcode.toString();
      qtyController.text = qty.toString();
      scrollToBarcode(barcode);
    }
  }

  void soundAndVibrate() async {
    player.play(AssetSource(errorSound), volume: 1);
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate();
    }
  }

  // get items and move to scan page
  Future<void> getItemsThenToScanPage() async {
    try {
      scanIsLoading.value = true;

      /// Fetch master and detail data from the local database
      final tempInvoiceListFromDB =
          await DBHelper.getAllItems(tableName: DBHelper.docMaster);
      final tempInvoiceDetailsFromDB =
          await DBHelper.getAllItems(tableName: DBHelper.docDetail);

      /// Deserialize the data
      final List<DocMaster> invoices = tempInvoiceListFromDB
          .map((json) => DocMaster.fromJson(json))
          .toList();
      final List<DocDetail> invoiceDetails = tempInvoiceDetailsFromDB
          .map((json) => DocDetail.fromJson(json))
          .toList();

      if (invoices.isNotEmpty) {
        /// Assign the first invoice and its details
        invoice.value = invoices.first;
        invoice.value.docDetails = invoiceDetails;

        /// Navigate to scan page if invoice number exists
        if (invoice.value.docNum != null) {
          Get.toNamed(RouteLinks.scanInvoice);
        } else {
          _showErrorSnackbar("No Invoice found, Sync Invoice again.");
        }
      } else {
        _showErrorSnackbar("No Invoice found, Sync Invoice again.");
      }
    } catch (e, stacktrace) {
      log("Error in getItemsThenToScanPage: $e");
      log("Stacktrace: $stacktrace");
      _showErrorSnackbar("An error occurred: $e");
    } finally {
      /// Stop the loading indicator regardless of the outcome
      scanIsLoading.value = false;
    }
  }

  /// Helper method to show error messages
  void _showErrorSnackbar(String message) {
    CustomWidget.customSnackBar(
      title: "Error!",
      message: message,
      backgroundColor: Colors.red,
    );
  }

  Future<void> saveQty() async {
    try {
      scanIsLoading.value = true;

      // Parse and validate quantity
      final qty = int.tryParse(qtyController.text) ?? 0;

      // Check for a valid scanned item before proceeding
      if (scannedItem.value.barcode == null) {
        soundAndVibrate();
        _showErrorSnackbar("No item selected. Scan an item first.");

        return;
      }

      // update the variable list if the database update succeeds
      scannedItem.update((item) {
        item?.checkQty = qty;
        item?.stat = 'Y';
      });

      // Prepare data for the database update
      final updatedData = scannedItem.value.toDB();
      log(updatedData.toString());

      // Update the database first
      final result = await DBHelper.updateItemWith2Conditions(
        DBHelper.docDetail, // Table name
        updatedData, // Data to update
        DBHelper.barcodeDocDetail, // Key column 1
        DBHelper.docNumDocDetail, // Key column 2
        scannedItem.value.barcode!, // Condition 1 (barcode)
        invoice.value.docNum!.toString(), // Condition 2 (invoice number)
      );

      if (result == 0) {
        _showErrorSnackbar("Failed to update the database.");
        return; // Stop execution if the database update fails
      }

      // Find and update the corresponding item in the invoice list
      final index = invoice.value.docDetails
          ?.indexWhere((item) => item.barcode == scannedItem.value.barcode);

      if (index != null && index != -1) {
        invoice.update((inv) {
          inv?.docDetails?[index].checkQty = qty;
          inv?.docDetails?[index].stat = 'Y';
        });
      } else {
        soundAndVibrate();
        _showErrorSnackbar("Item not found in the invoice list.");
        return;
      }

      // Clear input fields after successful update
      _clearInputFields();
      CustomWidget.customSnackBar(
        title: "Success",
        message: "Quantity updated successfully!",
      );
    } catch (e, stacktrace) {
      log("Error in saveQty: $e");
      log("Stacktrace: $stacktrace");
      _showErrorSnackbar("An error occurred while saving quantity.");
    } finally {
      scanIsLoading.value = false;
    }
  }

  /// Helper method to clear input fields
  void _clearInputFields() {
    barcodeController.clear();
    qtyController.clear();
  }

  void clearFields() async {
    barcodeController.clear();
    qtyController.clear();
    scannedItem.value = DocDetail();
  }

  Future<void> finalize() async {
    try {
      scanIsLoading.value = true;
      // Fetch all items from the database
      final dbItems = await DBHelper.getAllItems(tableName: DBHelper.docDetail);

      // Convert the raw database data into a list of InvDetail objects
      final List<DocDetail> invDetails =
          dbItems.map((item) => DocDetail.fromJson(item)).toList();
      log(invDetails.toString());
      // Check if all quantities match
      bool allMatch = invDetails.every((item) => item.shipQty == item.checkQty);

      if (allMatch) {
        // Call the API since all quantities match
        CustomWidget.customDialogue(
          title: "Proceed?",
          subTitle: "Are you sure you want to finalize this invoice?",
          onPressed: () async {
            Get.back();
            await _callApi();
          },
          onPressedBack: () {
            scanIsLoading.value = false;
            Get.back();
          },
        );
      } else {
        // Show a Snackbar indicating mismatch
        CustomWidget.customSnackBar(
          title: "Error!!",
          message: "Quantities do not match for all items.",
          backgroundColor: Colors.red,
        );
      }
    } catch (e, stacktrace) {
      log("Error in finalize: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "An error occurred while finalizing. Please try again.",
        backgroundColor: Colors.red,
      );
    } finally {
      scanIsLoading.value = false;
    }
  }

  /// Placeholder API call function
  /// Updated API Call with Error Handling
  Future<bool> _callApi() async {
    try {
      // Call the API first
      final result = await HomeRepo().updateInvoice(
        company: invoice.value.company!,
        userId: user.value.empID!,
        docNum: invoice.value.docNum!.toString(),
        docType: isInvoice.value ? "I" : "T",
      );

      if (!result) {
        CustomWidget.customSnackBar(
          title: "Error!",
          message: "Failed to submit data. Please try again.",
          backgroundColor: Colors.red,
        );
        return false;
      }

      // Attempt to delete data from both tables only if API call was successful
      final masterDeleteResult =
          await DBHelper.deleteAllItem(tableName: DBHelper.docMaster);
      final detailDeleteResult =
          await DBHelper.deleteAllItem(tableName: DBHelper.docDetail);
      log(invoice.value.toString());

      /// last invoice table data and update the database
      final lastInvTableData = {
        DBHelper.userIDLastInvoices: invoice.value.userId,
        DBHelper.docNumLastInvoices: invoice.value.docNum,
        DBHelper.statLastInvoices: 'Y'
      };
      log(lastInvTableData.toString());
      await _updateDatabase(
        tableName: DBHelper.lastInvoices,
        data: [lastInvTableData],
        delete: false,
      );

      ///the data in the last invoice table (Optional Logging)
      var lastInvoicesCheck =
          await DBHelper.getAllItems(tableName: DBHelper.lastInvoices);
      log("Last Invoice Table: $lastInvoicesCheck");
      var list =
          lastInvoicesCheck.map((json) => DocMaster.fromJson(json)).toList();
      lastInvoices.value = list.reversed.toList();
      log(lastInvoices.toString());

      // Confirm success if both deletions were successful
      if (masterDeleteResult != -1 && detailDeleteResult != -1) {
        CustomWidget.customDialogue(
          title: "Success!",
          subTitle: "All quantities matched and data submitted successfully!",
          okText: "OK",
          onPressed: () {
            Get.back();
            Get.back();
          },
        );
        return true;
      } else {
        CustomWidget.customSnackBar(
          title: "Error!",
          message: "Data submitted but failed to clear local data.",
          backgroundColor: Colors.red,
        );
        return false;
      }
    } catch (e, stacktrace) {
      log("Error in _callApi: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Error!",
        message: "An unexpected error occurred while submitting data.",
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  void fillAllDebug() async {
    if (kDebugMode) {
      for (var element in invoice.value.docDetails!) {
        element.stat = 'Y';
        element.checkQty = element.shipQty;
        final updatedData = element.toDB();
        // Update the database first
        await DBHelper.updateItemWith2Conditions(
          DBHelper.docDetail, // Table name
          updatedData, // Data to update
          DBHelper.barcodeDocDetail, // Key column 1
          DBHelper.docNumDocDetail, // Key column 2
          element.barcode!, // Condition 1 (barcode)
          element.docNum!.toString(), // Condition 2 (invoice number)
        );
      }
    }
    update();
  }

  void logOut() async {
    Get.offNamed(RouteLinks.login);
  }

  Future<void> clearInvoiceDB() async {
    try {
      clearIsLoading.value = true;

      // Fetch invoices from the database
      final dbItems = await DBHelper.getAllItems(tableName: DBHelper.docMaster);
      final dbItemsLastInvs =
          await DBHelper.getAllItems(tableName: DBHelper.lastInvoices);
      // final List<DocMaster> invoicesFromDB =
      //     dbItems.map((item) => DocMaster.fromJson(item)).toList();

      log("Invoices in DB: $dbItems");

      // If no invoices are found, show a message
      if (dbItems.isEmpty && dbItemsLastInvs.isEmpty) {
        CustomWidget.customDialogue(
            title: "Nothing Found",
            subTitle: "No Invoice or Transfer Found in the Database",
            // onPressedBack: () => Get.back(),
            onPressed: () => Get.back(),
            okText: "Back");
        return;
      }

      // If invoices are found, ask for confirmation before deletion
      CustomWidget.customDialogue(
        title: "Invoices Found",
        subTitle:
            "Are you sure you want to clear Invoices from Database?? This action is IRREVERSIBLE!!!",
        onPressedBack: () => Get.back(),
        onPressed: () async {
          Get.back(); // Close the dialog before proceeding

          //  Attempt to delete records from both tables
          final masterDeleteResult =
              await DBHelper.deleteAllItem(tableName: DBHelper.docMaster);
          final detailDeleteResult =
              await DBHelper.deleteAllItem(tableName: DBHelper.docDetail);
          final lastInvsResult =
              await DBHelper.deleteAllItem(tableName: DBHelper.lastInvoices);

          //  Check if deletion was successful
          if (masterDeleteResult != -1 &&
              detailDeleteResult != -1 &&
              lastInvsResult != -1) {
            invoice.value = DocMaster(); // Clear local data
            lastInvoices.clear();
            CustomWidget.customSnackBar(
                title: "Success!!", message: "Invoice deleted successfully.");
          } else {
            CustomWidget.customSnackBar(
                title: "Error!!",
                message: "Failed to delete the invoice. Try again.",
                backgroundColor: Colors.red);
          }
        },
      );
    } catch (e, stacktrace) {
      log("Error in clearInvoiceDB: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
          title: "Error!!",
          message: "An error occurred while clearing the database.",
          backgroundColor: Colors.red);
    } finally {
      clearIsLoading.value = false;
    }
  }
}
