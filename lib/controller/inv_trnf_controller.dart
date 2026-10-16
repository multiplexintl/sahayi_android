import 'dart:developer';
import 'dart:math' show max, min;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';
import 'package:sahayi_android/model/user.dart';
import 'package:sahayi_android/repo/home_repo.dart';
import 'package:sahayi_android/routes.dart';
import 'package:vibration/vibration.dart';
import '../service/app_logger.dart';

class InvoiceOrTransferController extends GetxController {
  var date = RxString('');
  var connectionStatus = false.obs;
  TextEditingController invController = TextEditingController();
  TextEditingController barcodeController = TextEditingController();
  TextEditingController qtyController = TextEditingController();
  var pickerController = TextEditingController();
  var user = Rx<User>(User());
  var pickerList = <Pickers>[];
  var selectedPicker = Rxn<Pickers>();
  var docMaster = Rx<DocMaster>(DocMaster());
  var syncIsLoading = false.obs;
  var scanIsLoading = false.obs;
  var clearIsLoading = false.obs;
  var scannedItem = Rx<DocDetail>(DocDetail());
  final ScrollController scrollController = ScrollController();
  final player = AudioPlayer();
  final String errorSound = "sound/wrong_barcode_1.wav";
  var lastInvoices = <DocMaster>[].obs;

  /// Number of the invoice/transfer downloaded on this scanner (step 2), or
  /// null. Lets "Recent" mark the one being scanned now.
  final currentDocNum = RxnString();

  /// Units checked / shipped of [currentDocNum] (for the hub's step 2 card).
  final currentChecked = 0.obs;
  final currentTotal = 0.obs;
  var isInvoice = true.obs;
  Rxn<Company> selectedCompany = Rxn<Company>();
  List<Company> companyList = [];
  final qtyFocusNode = FocusNode();
  final barcodeFocusNode = FocusNode();
  var isFinalize = false.obs;

  @override
  void onInit() async {
    super.onInit();
    user.value = Get.arguments;
    getCompanies();
    getSystemDate();
    getPickers();
    // await getLastInvoices();
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

  Future<void> getPickers() async {
    try {
      final list = await HomeRepo().getPickers();
      if (list.isNotEmpty) {
        pickerList = list.where((ls) => ls.type != 'Driver').toList();
        log("Pickers : ${pickerList.length}");
      } else {
        CustomWidget.customSnackBar(
          title: "Error!!",
          message: "Pickers and Drivers not loaded, please restart the app.",
          backgroundColor: Colors.red,
        );
      }
    } catch (e, st) {
      AppLogger.error('LoadPickers', 'Failed to load pickers',
          error: e, stack: st);
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Failed to load Drivers and Pickers. Error: $e",
        backgroundColor: Colors.red,
      );
    }
  }

  void selectComapny(Company? company) {
    selectedCompany.value = company;
    AppLogger.setCompany(company?.companyId);
    update();
  }

  List<Pickers> searchPickers(String query) {
    if (query.isEmpty) return pickerList;

    query = query.toLowerCase();
    return pickerList.where((picker) {
      return (picker.id?.toLowerCase().contains(query) ?? false) ||
          (picker.name?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void selectPicker(Pickers picker) {
    selectedPicker.value = picker;
    pickerController.text = picker.name!;
    update();
  }

  void addNewPicker(String name) {
    bool exists = pickerList.any((picker) => picker.name == name);
    if (!exists) {
      final newPicker = Pickers(
          id: DateTime.now().millisecondsSinceEpoch.toString(), name: name);
      pickerList.add(newPicker);
      selectPicker(newPicker);
    }
  }

  Future<void> getLastInvoices({String? docType}) async {
    lastInvoices.clear();
    List<Map<String, dynamic>> lastInvoicesCheck = [];
    if (docType != null) {
      lastInvoicesCheck = await DBHelper.getItems(
          tableName: DBHelper.lastInvoices,
          columnName: DBHelper.docTypeLastInvoices,
          condition: docType);
    } else {
      lastInvoicesCheck =
          await DBHelper.getAllItems(tableName: DBHelper.lastInvoices);
    }
    log("Last Invoice Table: $lastInvoicesCheck");
    var list =
        lastInvoicesCheck.map((json) => DocMaster.fromJson(json)).toList();
    await refreshCurrent(docType: docType);
    lastInvoices.value = list.reversed.toList();
    update();
  }

  /// Reads which document is downloaded on this scanner and how far it is.
  Future<void> refreshCurrent({String? docType}) async {
    final type = docType ?? (isInvoice.value ? 'I' : 'T');
    final onDevice = await DBHelper.getItems(
        tableName: DBHelper.docMaster,
        columnName: DBHelper.docTypeDocMaster,
        condition: type);
    currentDocNum.value = onDevice.isEmpty
        ? null
        : onDevice.first[DBHelper.docNumDocMaster] as String?;
    if (currentDocNum.value == null) {
      currentChecked.value = currentTotal.value = 0;
      return;
    }
    final sums = await DBHelper.getItemsByQuery(
      tableName: DBHelper.docDetail,
      where:
          "${DBHelper.docTypeDocDetail} = ? and ${DBHelper.docNumDocDetail} = ?",
      whereArgs: [type, currentDocNum.value],
    );
    currentChecked.value = sums.fold<int>(
        0, (s, r) => s + ((r[DBHelper.checkQtyDocDetail] as int?) ?? 0));
    currentTotal.value = sums.fold<int>(
        0, (s, r) => s + ((r[DBHelper.shipQtyDocDetail] as int?) ?? 0));
  }

  /// Tap on a document in "Recent". Completed: nothing. Unfinished and still
  /// on this scanner (step 2): continue scanning it. Unfinished but replaced
  /// by a newer sync: open Sync with number, company and picker filled in,
  /// so it can be downloaded again and scanned from the start.
  Future<void> openRecent(DocMaster doc) async {
    if (doc.stat == 'Y' || doc.docNum == null) return;
    try {
      final onDevice = await DBHelper.getItemsByQuery(
        tableName: DBHelper.docMaster,
        where:
            "${DBHelper.docNumDocMaster} = ? and ${DBHelper.docTypeDocMaster} = ?",
        whereArgs: [doc.docNum, isInvoice.value ? 'I' : 'T'],
      );
      if (onDevice.isNotEmpty) {
        AppLogger.info('RecentOpen', 'Continue scanning ${doc.docNum}',
            docNum: doc.docNum);
        await getItemsThenToScanPage();
        return;
      }

      invController.text = doc.docNum!;
      final company =
          companyList.firstWhereOrNull((c) => c.companyId == doc.company);
      selectComapny(company);
      final picker = pickerList.firstWhereOrNull((p) => p.id == doc.pickedBy);
      if (picker != null) {
        selectPicker(picker);
      } else {
        selectedPicker.value = null;
        pickerController.clear();
      }
      AppLogger.info('RecentOpen',
          'Sync again ${doc.docNum} (company ${company?.companyId ?? '-'}, picker ${picker?.id ?? '-'})',
          docNum: doc.docNum);
      Get.toNamed(RouteLinks.syncInvoice);
    } catch (e, st) {
      AppLogger.error('RecentOpen', 'Opening recent ${doc.docNum} failed',
          error: e, stack: st, docNum: doc.docNum);
      _showErrorSnackbar("Could not open ${doc.docNum}. Please try again.");
    }
  }

  void getSystemDate() {
    var now = DateTime.now();
    date.value = DateFormat("dd-MM-yyyy").format(now);
  }

  void checkValidation() {
    if (invController.value.text.isEmpty &&
        selectedCompany.value?.companyId == null &&
        selectedPicker.value == null) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message:
            "Company, ${isInvoice.value ? 'Invoice' : 'Transfer'} Number and Picker should not be empty",
        backgroundColor: Colors.red,
      );
    } else if (invController.value.text.isEmpty) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message:
            "${isInvoice.value ? 'Invoice' : 'Transfer'} Number should not be empty",
        backgroundColor: Colors.red,
      );
    } else if (selectedCompany.value?.companyId == null) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Company should not be empty",
        backgroundColor: Colors.red,
      );
    } else if (selectedPicker.value == null) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Picker should not be empty",
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
      AppLogger.info('SyncStart',
          'Download ${isInvoice.value ? 'invoice' : 'transfer'} ${invController.text}, picker ${selectedPicker.value?.id}',
          docNum: invController.text, docType: isInvoice.value ? 'I' : 'T');

      // Check if the invMaster table is empty
      // var invDB = await DBHelper.getAllItems(tableName: DBHelper.docMaster);
      var invDB2 = await DBHelper.getItemsByQuery(
        tableName: DBHelper.docMaster,
        where:
            "${DBHelper.companyDocMaster} = ? and ${DBHelper.statDocMaster} = ? and ${DBHelper.docTypeDocMaster} = ?",
        whereArgs: [
          selectedCompany.value?.companyId,
          'N',
          isInvoice.value ? 'I' : 'T'
        ],
      );
      log(invDB2.toString());

      if (invDB2.isNotEmpty) {
        var data = invDB2.map((json) => DocMaster.fromJson(json)).toList();
        log(data.toString());
        AppLogger.info('SyncOverwritePrompt',
            'Unfinished ${data[0].docNum} on device; asking to overwrite',
            docNum: data[0].docNum);
        // Show a confirmation dialog if data exists
        CustomWidget.customDialogue(
          title: "${isInvoice.value ? 'Invoice' : 'Transfer'} Exists!",
          subTitle:
              "${isInvoice.value ? 'An' : 'A'} ${isInvoice.value ? 'invoice' : 'transfer'} with ${isInvoice.value ? 'invoice' : 'transfer'} number : ${data[0].docNum} already exists in the database without completion. Continuing will overwrite the existing data. Do you want to proceed?",
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
      AppLogger.error('SyncFailed', 'syncInvoice crashed',
          error: e, stack: stacktrace, docNum: invController.text);
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
        docType: isInvoice.value ? "I" : "T",
      );

      // Awaited: the save step below must finish (spinner stays on) and its
      // errors must reach the catch below. Unawaited, the spinner stopped
      // early and a failed save showed no message.
      await syncResult.fold<Future<void>>(
        (failureMessage) async {
          AppLogger.warn(
              'SyncFailed', 'Server sync refused/failed: $failureMessage',
              docNum: invController.text, docType: isInvoice.value ? 'I' : 'T');
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
            AppLogger.warn(
                'SyncNoItems', 'Synced but document details came back empty',
                docNum: invController.text,
                docType: isInvoice.value ? 'I' : 'T');
            CustomWidget.customSnackBar(
              title: "Error!!",
              message: "No invoice found. Try again.",
              backgroundColor: Colors.red,
            );
            return;
          }

          log(invoiceList.toString());

          ///invoice observable and prepare data
          var tempInvList = invoiceList[0];
          tempInvList.userId = user.value.empID;
          tempInvList.pickedBy = selectedPicker.value?.id;

          /// master table data and update the database
          final masterTableData = tempInvList.toDB();
          log(masterTableData.toString());
          // delete any invoice or transfer item from master
          var res1 = await DBHelper.deleteItem(
              tableName: DBHelper.docMaster,
              columnName: DBHelper.docTypeDocMaster,
              condition: isInvoice.value ? 'I' : 'T');
          log("$res1 deleted in details");
          await _updateDatabase(
            tableName: DBHelper.docMaster,
            data: [masterTableData],
            // delete: false,
          );

          /// detail table data and update the database
          final detailTableData =
              tempInvList.docDetails?.map((e) => e.toDB()).toList() ?? [];
          log(detailTableData.toString());
          // delete any invoice or transfer item from master
          var res = await DBHelper.deleteItem(
              tableName: DBHelper.docDetail,
              columnName: DBHelper.docTypeDocDetail,
              condition: isInvoice.value ? 'I' : 'T');
          log("$res deleted in master");
          await _updateDatabase(
            tableName: DBHelper.docDetail,
            data: detailTableData,
            // delete: false,
          );

          /// last invoice table data and update the database
          final lastInvTableData = {
            DBHelper.userIDLastInvoices: tempInvList.userId,
            DBHelper.docNumLastInvoices: tempInvList.docNum,
            DBHelper.docTypeLastInvoices: isInvoice.value ? 'I' : 'T',
            DBHelper.statLastInvoices: tempInvList.stat,
            DBHelper.companyLastInvoices: selectedCompany.value?.companyId,
            DBHelper.pickedByLastInvoices: selectedPicker.value?.id,
          };
          log(lastInvTableData.toString());
          await DBHelper().insertOrUpdateWithLimit(
            tableName: DBHelper.lastInvoices,
            keyColumn: DBHelper.docNumLastInvoices,
            condition: tempInvList.docNum,
            data: lastInvTableData,
          );
          await getLastInvoices(docType: isInvoice.value ? 'I' : 'T');

          ///ccess message
          final itemCount = tempInvList.docDetails?.length ?? 0;
          final itemLabel = itemCount == 1 ? "item" : "items";
          AppLogger.info('SyncDone', 'Downloaded $itemCount lines',
              docNum: tempInvList.docNum, docType: tempInvList.docType);

          CustomWidget.customDialogue(
            title: "Success!!",
            subTitle:
                "$itemCount $itemLabel of ${isInvoice.value ? 'invoice' : 'transfer'} ${tempInvList.docNum} downloaded. Start scanning now.",
            okText: "Start scanning",
            onPressed: () {
              invController.clear();
              selectedCompany.value = null;
              selectedPicker.value = null;
              pickerController.clear();
              Get.close(2);
              // straight on to step 2 (saves a tap on the hub)
              getItemsThenToScanPage();
            },
          );
        },
      );
    } catch (e, stacktrace) {
      AppLogger.error('SyncFailed', '_syncAndUpdateInvoice crashed',
          error: e, stack: stacktrace, docNum: invController.text);
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
  Future<void> _updateDatabase({
    required String tableName,
    required List<Map<String, dynamic>> data,
    // required bool delete,
  }) async {
    try {
      // if (delete) {
      //   /// Delete existing records
      //   final deleteCount = await DBHelper.deleteAllItem(tableName: tableName);
      //   log("Deleted $deleteCount rows from $tableName.");
      // }

      /// Insert new records
      final insertCount =
          await DBHelper.bulkInsert(tableName: tableName, items: data);
      log("$insertCount rows inserted into $tableName.");
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
      throw Exception("Database update failed");
    }
  }

  /// All lines of the open document with this barcode, in invoice order.
  /// The same part can be on several lines (e.g. invoice 23014637: one part
  /// on 8 lines); they are filled one after the other.
  List<DocDetail> linesForBarcode(String? barcode) => [
        for (final l in docMaster.value.docDetails ?? const <DocDetail>[])
          if (barcode != null && l.barcode == barcode) l
      ];

  /// How much can still be checked for this barcode, over all its lines.
  static int openQty(List<DocDetail> lines) => lines.fold(
      0, (sum, l) => sum + max(0, (l.shipQty ?? 0) - (l.checkQty ?? 0)));

  /// Spreads [qty] over [lines] in order, filling each up to its shipped
  /// quantity. Returns the lines that received something. Caller checks
  /// that qty <= openQty(lines).
  static List<DocDetail> fillInOrder(List<DocDetail> lines, int qty) {
    final changed = <DocDetail>[];
    var left = qty;
    for (final l in lines) {
      if (left == 0) break;
      final open = (l.shipQty ?? 0) - (l.checkQty ?? 0);
      if (open <= 0) continue;
      final take = min(open, left);
      l.checkQty = (l.checkQty ?? 0) + take;
      l.stat = 'Y';
      left -= take;
      changed.add(l);
    }
    return changed;
  }

  // auto scroll
  void scrollToBarcode(String barcode) {
    // The first line of this barcode that is not full yet (or the first one
    // when all are full), so the list shows where the next units go.
    final lines = linesForBarcode(barcode);
    final target =
        lines.firstWhereOrNull((l) => (l.checkQty ?? 0) < (l.shipQty ?? 0)) ??
            lines.firstOrNull;
    final index =
        target == null ? -1 : docMaster.value.docDetails!.indexOf(target);

    if (index != -1) {
      // Assign the matched item to the reactive variable
      scannedItem.value = docMaster.value.docDetails![index];
      if (scrollController.hasClients) {
        scrollController.animateTo(
          index * 63, // Adjust item height if necessary
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      qtyFocusNode.requestFocus();
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
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate();
    }
  }

  // get items and move to scan page
  Future<void> getItemsThenToScanPage() async {
    log(isInvoice.toString());
    try {
      scanIsLoading.value = true;

      /// Fetch master and detail data from the local database
      final tempInvoiceListFromDB = await DBHelper.getItems(
          tableName: DBHelper.docMaster,
          columnName: DBHelper.docTypeDocMaster,
          condition: isInvoice.value ? "I" : "T");
      final tempInvoiceDetailsFromDB = await DBHelper.getItems(
          tableName: DBHelper.docDetail,
          columnName: DBHelper.docTypeDocDetail,
          condition: isInvoice.value ? "I" : "T");

      /// Deserialize the data
      final List<DocMaster> invoices = tempInvoiceListFromDB
          .map((json) => DocMaster.fromJson(json))
          .toList();
      final List<DocDetail> invoiceDetails = tempInvoiceDetailsFromDB
          .map((json) => DocDetail.fromJson(json))
          .toList();
      log(invoices.toString());
      log(invoiceDetails.toString());
      if (invoices.isNotEmpty) {
        /// Assign the first invoice and its details
        docMaster.value = invoices.first;
        docMaster.value.docDetails = invoiceDetails;

        /// Navigate to scan page if invoice number exists
        if (docMaster.value.docNum != null) {
          // here check for enabling finalize button
          isFinalize.value =
              invoiceDetails.every((item) => item.checkQty == item.shipQty);
          AppLogger.info('OpenScan',
              'Opened ${invoiceDetails.length} lines, ${invoiceDetails.where((i) => i.checkQty == i.shipQty).length} complete',
              docNum: docMaster.value.docNum, docType: docMaster.value.docType);
          Get.toNamed(RouteLinks.scanInvoice);
        } else {
          _showErrorSnackbar(
              "No ${isInvoice.value ? 'Invoice' : 'Transfer'} found, Check details and sync again.");
        }
      } else {
        _showErrorSnackbar(
            "No ${isInvoice.value ? 'Invoice' : 'Transfer'} found, Check details and sync again.");
      }
    } catch (e, stacktrace) {
      AppLogger.error('OpenScan', 'getItemsThenToScanPage crashed',
          error: e, stack: stacktrace);
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

  Future<bool> saveQty() async {
    try {
      scanIsLoading.value = true;

      // Parse and validate quantity
      final qty = int.tryParse(qtyController.text) ?? 0;

      if (qty <= 0) {
        _showErrorSnackbar("Please enter a valid quantity.");
        return false;
      }

      // Check if an item is selected
      if (scannedItem.value.barcode == null) {
        soundAndVibrate();
        _showErrorSnackbar("No item selected. Scan an item first.");
        return false;
      }

      // All lines of this barcode count together (same part on several lines).
      final lines = linesForBarcode(scannedItem.value.barcode);
      if (lines.isEmpty) {
        soundAndVibrate();
        _showErrorSnackbar("Item not found in the invoice list.");
        return false;
      }
      final shipQty = lines.fold<int>(0, (s, l) => s + (l.shipQty ?? 0));
      final open = openQty(lines);
      final linesText = lines.length > 1 ? " over ${lines.length} lines" : "";

      // Every line of this item is already full: no more can be scanned
      if (open <= 0) {
        CustomWidget.customDialogue(
          title: "Already Completed",
          subTitle:
              "The scanned item has already reached the shipping quantity ($shipQty$linesText).",
          onPressed: () {
            clearInputFields();
            // Clear focus and request focus again with a delay
            barcodeFocusNode.unfocus();
            qtyFocusNode.unfocus();
            Future.delayed(Duration(milliseconds: 100), () {
              if (barcodeFocusNode.canRequestFocus && !isFinalize.value) {
                barcodeFocusNode.requestFocus();
                log("Barcode focus requested");
              } else {
                log("Cannot request focus");
              }
            });
            Get.back();
          },
          okText: "OK",
          buttonColor: Colors.red,
        );
        return false;
      }

      // If total check quantity exceeds ship quantity, show a warning dialog
      if (qty > open) {
        final totalCheckQty = shipQty - open + qty;
        CustomWidget.customDialogue(
          title: "Quantity Exceeded",
          subTitle:
              "The total checked quantity ($totalCheckQty) exceeds the shipped quantity ($shipQty$linesText).",
          onPressed: () => Get.back(),
          okText: "OK",
          buttonColor: Colors.red,
        );
        return false;
      }

      // Fill the lines in order and save exactly those lines (by line number,
      // so other lines of the same item are never touched or removed).
      final before = {for (final l in lines) l: (l.checkQty, l.stat)};
      final changed = fillInOrder(lines, qty);
      final updated = await DBHelper.updateDocDetailLines(
          changed.map((l) => l.toDB()).toList());

      if (updated != changed.length) {
        // put the screen back as it was
        for (final e in before.entries) {
          e.key.checkQty = e.value.$1;
          e.key.stat = e.value.$2;
        }
        AppLogger.error('LocalDbError',
            'Quantity update matched $updated of ${changed.length} lines',
            docNum: docMaster.value.docNum,
            details: 'Barcode ${scannedItem.value.barcode}');
        _showErrorSnackbar("Failed to update the database.");
        return false;
      }
      docMaster.refresh();

      // Check if all items' checkQty and shipQty are equal in the database
      final allItemsMap = await DBHelper.getItems(
          tableName: DBHelper.docDetail,
          columnName: DBHelper.docTypeDocDetail,
          condition: isInvoice.value ? "I" : "T");
      final allItems =
          allItemsMap.map((item) => DocDetail.fromJson(item)).toList();

      log(allItems.toString());

      // Check if all items are finalized
      isFinalize.value =
          allItems.every((item) => item.checkQty == item.shipQty);

      log("Ready to finalize : ${isFinalize.value}");
      await refreshCurrent(); // hub's step 2 card shows the new progress

      // Show success message and clear fields
      CustomWidget.customSnackBar(
        title: "Success",
        message: "Quantity updated successfully!",
      );
      clearInputFields();
      // Clear focus and request focus again with a delay
      barcodeFocusNode.unfocus();
      Future.delayed(Duration(milliseconds: 100), () {
        if (barcodeFocusNode.canRequestFocus && !isFinalize.value) {
          barcodeFocusNode.requestFocus();
          log("Barcode focus requested");
        } else {
          log("Cannot request focus");
        }
      });

      return true;
    } catch (e, stacktrace) {
      AppLogger.error('SaveQty', 'saveQty crashed',
          error: e, stack: stacktrace, docNum: docMaster.value.docNum);
      log("Error in saveQty: $e");
      log("Stacktrace: $stacktrace");
      _showErrorSnackbar("An error occurred while saving quantity.");
      return false;
    } finally {
      scanIsLoading.value = false;
    }
  }

  /// Helper method to clear input fields
  void clearInputFields() {
    barcodeController.clear();
    qtyController.clear();
    scannedItem.value = DocDetail();
  }

  // Future<void> finalize() async {
  //   try {
  //     scanIsLoading.value = true;
  //     // Fetch all items from the database
  //     final dbItems = await DBHelper.getAllItems(tableName: DBHelper.docDetail);

  //     // Convert the raw database data into a list of InvDetail objects
  //     final List<DocDetail> invDetails =
  //         dbItems.map((item) => DocDetail.fromJson(item)).toList();
  //     log(invDetails.toString());
  //     // Check if all quantities match
  //     bool allMatch = invDetails.every((item) => item.shipQty == item.checkQty);

  //     if (allMatch) {
  //       // Call the API since all quantities match
  //       CustomWidget.customDialogue(
  //         title: "Proceed?",
  //         subTitle: "Are you sure you want to finalize this invoice?",
  //         onPressed: () async {
  //           Get.back();
  //           final success = await _callApi();
  //           if (success) {
  //             isFinalize.value = false; // Reset after success
  //           }
  //         },
  //         onPressedBack: () {
  //           scanIsLoading.value = false;
  //           Get.back();
  //         },
  //       );
  //     } else {
  //       // Show a Snackbar indicating mismatch
  //       CustomWidget.customSnackBar(
  //         title: "Error!!",
  //         message: "Quantities do not match for all items.",
  //         backgroundColor: Colors.red,
  //       );
  //     }
  //   } catch (e, stacktrace) {
  //     log("Error in finalize: $e");
  //     log("Stacktrace: $stacktrace");
  //     CustomWidget.customSnackBar(
  //       title: "Error!!",
  //       message: "An error occurred while finalizing. Please try again.",
  //       backgroundColor: Colors.red,
  //     );
  //   } finally {
  //     isFinalize.value = false;
  //   }
  // }

  Future<void> finalize() async {
    log(docMaster.toString());
    try {
      scanIsLoading.value = true;

      // Fetch all items from the database
      final dbItems = await DBHelper.getItemsByQuery(
          tableName: DBHelper.docDetail,
          where:
              "${DBHelper.companyDocDetail} = ? and ${DBHelper.docNumDocDetail} = ? and ${DBHelper.docTypeDocDetail} = ? and ${DBHelper.statDocDetail} = ?",
          whereArgs: [
            docMaster.value.company,
            docMaster.value.docNum,
            docMaster.value.docType,
            'Y'
          ]);
      log(dbItems.toString());
      // Convert the raw database data into a list of DocDetail objects
      final List<DocDetail> invDetails =
          dbItems.map((item) => DocDetail.fromJson(item)).toList();
      log(invDetails.toString());
      if (invDetails.isEmpty) {
        log("No doc details found");
        AppLogger.warn('FinalizeStart', 'No checked lines found on device',
            docNum: docMaster.value.docNum, docType: docMaster.value.docType);
        return;
      }
      // Check if all quantities match
      bool allMatch = invDetails.every((item) => item.shipQty == item.checkQty);

      log(allMatch.toString());
      AppLogger.info('FinalizeStart',
          '${invDetails.length} lines, all quantities match: $allMatch',
          docNum: docMaster.value.docNum, docType: docMaster.value.docType);

      if (allMatch) {
        // Set `isFinalize` to true before proceeding
        // isFinalize.value = true;

        // Show confirmation dialog
        CustomWidget.customDialogue(
          title: "Proceed?",
          subTitle: "Are you sure you want to finalize this invoice?",
          onPressed: () async {
            Get.back(); // Close the dialog
            AppLogger.info('FinalizeConfirm', 'User confirmed finalize',
                docNum: docMaster.value.docNum,
                docType: docMaster.value.docType);
            final success = await _callApi();
            if (success) {
              isFinalize.value = false; // Reset after success
              docMaster.value = DocMaster();
            } else {
              CustomWidget.customSnackBar(
                  title: "Error!!", message: "API call failed, try again");
            }
          },
          onPressedBack: () {
            AppLogger.info('FinalizeCancel', 'User cancelled finalize',
                docNum: docMaster.value.docNum);
            scanIsLoading.value = false; // Reset loading state
            // isFinalize.value = false; // Reset `isFinalize` if user cancels
            Get.back(); // Close the dialog
          },
        );
      } else {
        // Show a Snackbar indicating mismatch
        CustomWidget.customSnackBar(
          title: "Error!!",
          message: "Quantities do not match for all items.",
          backgroundColor: Colors.red,
        );
        isFinalize.value = false; // Reset `isFinalize` if not matched
      }
    } catch (e, stacktrace) {
      AppLogger.error('FinalizeFailed', 'finalize crashed',
          error: e, stack: stacktrace, docNum: docMaster.value.docNum);
      log("Error in finalize: $e");
      log("Stacktrace: $stacktrace");
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "An error occurred while finalizing. Please try again.",
        backgroundColor: Colors.red,
      );
      // isFinalize.value = false; // Reset `isFinalize` in case of error
    } finally {
      scanIsLoading.value = false; // Reset loading state
    }
  }

  /// Placeholder API call function
  /// Updated API Call with Error Handling
  Future<bool> _callApi() async {
    try {
      // Call the API first
      final result = await HomeRepo().updateInvoice(
        company: docMaster.value.company!,
        userId: user.value.empID!,
        docNum: docMaster.value.docNum!.toString(),
        docType: isInvoice.value ? "I" : "T",
        pickedBy: docMaster.value.pickedBy!,
      );
      log(result.toString());
      if (!result) {
        AppLogger.error(
            'FinalizeFailed', 'Server did not accept UpdateDocument',
            docNum: docMaster.value.docNum, docType: docMaster.value.docType);
        CustomWidget.customSnackBar(
          title: "Error!",
          message: "Failed to submit data. Please try again.",
          backgroundColor: Colors.red,
        );
        return false;
      }

      // Attempt to delete data from both tables only if API call was successful
      final masterDeleteResult = await DBHelper.deleteItemsByQuery(
          tableName: DBHelper.docMaster,
          where:
              "${DBHelper.companyDocMaster} = ? and ${DBHelper.docNumDocMaster} = ? and ${DBHelper.docTypeDocMaster} = ?",
          whereArgs: [
            docMaster.value.company,
            docMaster.value.docNum,
            docMaster.value.docType,
          ]);
      final detailDeleteResult = await DBHelper.deleteItemsByQuery(
          tableName: DBHelper.docDetail,
          where:
              "${DBHelper.companyDocDetail} = ? and ${DBHelper.docNumDocDetail} = ? and ${DBHelper.docTypeDocDetail} = ?",
          whereArgs: [
            docMaster.value.company,
            docMaster.value.docNum,
            docMaster.value.docType,
          ]);
      log(docMaster.value.toString());

      /// last invoice table data and update the database
      final lastInvTableData = {
        DBHelper.userIDLastInvoices: docMaster.value.userId,
        DBHelper.docNumLastInvoices: docMaster.value.docNum,
        DBHelper.docTypeLastInvoices: isInvoice.value ? 'I' : 'T',
        DBHelper.statLastInvoices: 'Y',
        DBHelper.companyLastInvoices: docMaster.value.company,
        DBHelper.pickedByLastInvoices: docMaster.value.pickedBy,
      };
      log(lastInvTableData.toString());
      await _updateDatabase(
        tableName: DBHelper.lastInvoices,
        data: [lastInvTableData],
        // delete: false,
      );
      await getLastInvoices(docType: isInvoice.value ? 'I' : "T");

      ///the data in the last invoice table (Optional Logging)
      // var lastInvoicesCheck =
      //     await DBHelper.getAllItems(tableName: DBHelper.lastInvoices);
      // log("Last Invoice Table: $lastInvoicesCheck");
      // var list =
      //     lastInvoicesCheck.map((json) => DocMaster.fromJson(json)).toList();
      // lastInvoices.value = list.reversed.toList();
      log(lastInvoices.toString());

      // Confirm success if both deletions were successful
      if (masterDeleteResult != -1 && detailDeleteResult != -1) {
        AppLogger.info(
            'FinalizeDone', 'Submitted to server and cleared from device',
            docNum: lastInvTableData[DBHelper.docNumLastInvoices]?.toString(),
            docType: isInvoice.value ? 'I' : 'T');
        CustomWidget.customDialogue(
          title: "Success!",
          subTitle: "All quantities matched and data submitted successfully!",
          okText: "OK",
          onPressed: () {
            Get.back();
            Get.back();
          },
        );
        isFinalize.value = false;
        return true;
      } else {
        AppLogger.error(
            'FinalizeCleanup', 'Submitted, but clearing device data failed',
            docNum: docMaster.value.docNum);
        CustomWidget.customSnackBar(
          title: "Error!",
          message: "Data submitted but failed to clear local data.",
          backgroundColor: Colors.red,
        );
        return false;
      }
    } catch (e, stacktrace) {
      AppLogger.error('FinalizeFailed', '_callApi crashed',
          error: e, stack: stacktrace, docNum: docMaster.value.docNum);
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
      for (var element in docMaster.value.docDetails!) {
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
      isFinalize.value = true;
    }
    update();
  }

  void clearAllDebug() async {
    if (kDebugMode) {
      for (var element in docMaster.value.docDetails!) {
        element.stat = 'N';
        element.checkQty = 0;
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
      isFinalize.value = false;
    }
    update();
  }

  Future<void> clearInvoiceDB() async {
    try {
      clearIsLoading.value = true;

      // Fetch invoices from the database
      final dbItems = await DBHelper.getItems(
          tableName: DBHelper.docMaster,
          columnName: DBHelper.docTypeDocMaster,
          condition: isInvoice.value ? "I" : "T");
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
          AppLogger.warn('ClearLocal',
              'User cleared all ${isInvoice.value ? 'invoices' : 'transfers'} from device');

          //  Attempt to delete records from both tables
          final masterDeleteResult = await DBHelper.deleteItem(
              tableName: DBHelper.docMaster,
              columnName: DBHelper.docTypeDocMaster,
              condition: isInvoice.value ? "I" : "T");
          final detailDeleteResult = await DBHelper.deleteItem(
              tableName: DBHelper.docDetail,
              columnName: DBHelper.docTypeDocDetail,
              condition: isInvoice.value ? "I" : "T");
          final lastInvsResult = await DBHelper.deleteItem(
              tableName: DBHelper.lastInvoices,
              columnName: DBHelper.docTypeLastInvoices,
              condition: isInvoice.value ? "I" : "T");

          //  Check if deletion was successful
          if (masterDeleteResult != -1 &&
              detailDeleteResult != -1 &&
              lastInvsResult != -1) {
            docMaster.value = DocMaster(); // Clear local data
            lastInvoices.clear();
            currentDocNum.value = null;
            currentChecked.value = currentTotal.value = 0;
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
      AppLogger.error('ClearLocal', 'clearInvoiceDB crashed',
          error: e, stack: stacktrace);
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

//25000208
