import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/return/reasons.dart';
import 'package:sahayi_android/widgets/part_show.dart';

import '../../helper/custom_colors.dart';
import '../../helper/custom_widget.dart';
import '../../widgets/button.dart';
import '../../widgets/year_picker.dart';

class ScanReturns extends StatelessWidget {
  const ScanReturns({super.key});

  @override
  Widget build(BuildContext context) {
    var con = Get.find<ReturnController>();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: CustomColors.scaffoldColor,
        resizeToAvoidBottomInset: false,
        appBar: CustomWidget.customAppBar("Scan Returns", back: true),
        bottomNavigationBar: _buildBottomBar(con),
        body: Padding(
          padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerInfo(context, "Customer",
                  "${con.selectedCustomer.value.custId} - ${con.selectedCustomer.value.custName}"),
              SizedBox(height: 1),
              _buildCustomerInfo(context, "Doc Num", con.docNumber.value ?? ''),
              SizedBox(height: 1),
              _buildCustomerInfo(context, "Doc Date", con.docDate.value ?? ''),
              SizedBox(height: 1),
              _buildCustomerInfo(
                  context, "Returned By", con.driver.value?.name ?? ''),
              SizedBox(height: 1),
              _buildBarcodeAndQtyFields(con, context),
              SizedBox(height: 5),
              _buildReasonDropdown(con, context),
              SizedBox(height: 5),
              _buildExpiryDateField(context),
              _buildSelectedPart(con, context),
              SizedBox(height: 5),
              _buildSaveAndClearButtons(con, context),
              Divider(height: 20, color: Colors.black, thickness: 2.5),
              Obx(() => Visibility(
                    visible: con.savedItems.isNotEmpty,
                    child: PartShowWidget(
                      isHead: true,
                      slNo: "Sl No",
                      barcode: "Barcode",
                      partName: 'Part Name',
                      qty: "Qty",
                      rsn: "Rsn",
                    ),
                  )),
              Expanded(
                child: _buildSavedItemsList(con),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryDateField(BuildContext context) {
    return GetBuilder<ReturnController>(
      builder: (con) {
        return con.selectedReason.value != null &&
                    con.selectedReason.value?.reasonId == 'NRE' ||
                con.selectedReason.value?.reasonId == 'EXP'
            ? SizedBox(
                height: 60,
                child: TextField(
                  controller: con.expiryDateController,
                  readOnly: true,
                  onTap: () {
                    int currentYear = DateTime.now().year;
                    showYearMonthPicker(
                      minimumYear: currentYear - 1,
                      maximumYear: currentYear + 2,
                      maximumDate: DateTime(
                          currentYear + 2, 12, 31), // December 31 of max year
                      minimumDate: DateTime(
                          currentYear - 1, 1, 1), // January 1 of min year
                      // initialDateTime: null,
                      dateNeeded: true,
                      onTapCancel: () {
                        con.expiryDate.value = null;
                        con.expiryDateController.clear();
                        FocusManager.instance.primaryFocus?.unfocus();
                        con.update();
                        Get.back();
                      },
                      onTapSubmit: () {
                        log(con.expiryDateController.value.text);
                        if (con.expiryDateController.value.text.isEmpty) {
                          String formattedDate =
                              DateFormat("yyyy-MM-dd").format(DateTime.now());
                          con.expiryDateController.text = formattedDate;
                          con.expiryDate.value = formattedDate;
                        }
                        Get.back();
                      },
                      onDateTimeChanged: (date) {
                        log(date.toString());
                        String formattedDate =
                            DateFormat("yyyy-MM-dd").format(date);
                        con.expiryDateController.text = formattedDate;
                        con.expiryDate.value = formattedDate;
                        con.update();
                      },
                    );
                  },
                  decoration: CustomWidget().inputDecoration(
                      context: context, labelText: "Expiry Date", radius: 16),
                ),
              )
            : SizedBox();
      },
    );
  }

  /// Builds the customer and document number info rows.
  Widget _buildCustomerInfo(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        Text(": ", style: Theme.of(context).textTheme.titleSmall),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.titleSmall),
        )
      ],
    );
  }

  /// Builds barcode and quantity input fields.
  Widget _buildBarcodeAndQtyFields(ReturnController con, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Obx(() => TextFormField(
                controller: con.barcodeController,
                enabled: !con.scanIsLoading.value,
                focusNode: con.barcodeFocusNode,
                onChanged: con.onBarcodeChanged,
                decoration:
                    CustomWidget().inputDecoration(context: context).copyWith(
                          labelText: "Barcode",
                          contentPadding: EdgeInsets.only(left: 12, right: 10),
                          errorStyle: TextStyle(fontSize: 10.0, height: 0.8),
                        ),
              )),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Obx(() => TextFormField(
                controller: con.qtyController,
                keyboardType: TextInputType.number,
                focusNode: con.qtyFocusNode,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !con.scanIsLoading.value,
                decoration:
                    CustomWidget().inputDecoration(context: context).copyWith(
                          labelText: "Qty",
                          contentPadding: EdgeInsets.only(left: 12),
                          errorStyle: TextStyle(fontSize: 10.0, height: 0.8),
                        ),
              )),
        ),
      ],
    );
  }

  /// Builds the dropdown for selecting a reason.
  Widget _buildReasonDropdown(ReturnController con, BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Obx(() => DropdownButtonFormField<Reasons>(
            decoration: CustomWidget()
                .inputDecoration(
                    context: context, labelText: "Select Reason", radius: 16)
                .copyWith(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
            value: con.selectedReason.value, // Nullable handling
            items: con.reasons.map((reason) {
              return DropdownMenuItem<Reasons>(
                value: reason,
                child: Text(
                  "${reason.reasonId} - ${reason.reason}",
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              );
            }).toList(),
            onChanged: (Reasons? newValue) {
              con.selectedReason.value = newValue;
              con.update();
            },
          )),
    );
  }

  /// Builds save and clear buttons.
  Widget _buildSelectedPart(ReturnController con, BuildContext context) {
    return Obx(() {
      return con.selectedPart.value == null
          ? SizedBox()
          : Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Selected Item : ",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Expanded(
                    child: Obx(() => Text(
                          "${con.selectedPart.value?.partName}",
                          style: Theme.of(context).textTheme.labelLarge,
                        )),
                  )
                ],
              ),
            );
    });
  }

  /// Builds save and clear buttons.
  Widget _buildSaveAndClearButtons(ReturnController con, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ButtonWidget(
            title: "Save",
            width: context.width - (context.width / 2) - 30,
            backgroundColor: Colors.greenAccent.shade700,
            onPressed: con.onSavePart,
          ),
          ButtonWidget(
            title: "Clear",
            width: context.width - (context.width / 2) - 30,
            backgroundColor: Colors.red,
            onPressed: con.clearPart,
          )
        ],
      ),
    );
  }

  /// Builds the bottom navigation bar.
  Widget _buildBottomBar(ReturnController con) {
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25), topRight: Radius.circular(25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ButtonWidget(
            width: 140,
            title: "Clear",
            backgroundColor: Colors.red,
            onPressed: () => _showClearDialog(con),
          ),
          ButtonWidget(
            width: 140,
            title: "Confirm",
            backgroundColor: Colors.green,
            onPressed: con.onConfirm,
            onLongPress: () async {
              var det =
                  await DBHelper.getAllItems(tableName: DBHelper.docDetail);
              log(det.toString());
            },
          ),
        ],
      ),
    );
  }

  /// Builds the saved items list.
  Widget _buildSavedItemsList(ReturnController con) {
    return Obx(() => ListView.builder(
          padding: EdgeInsets.only(top: 5),
          shrinkWrap: true,
          itemCount: con.savedItems.length,
          itemBuilder: (context, index) {
            var item = con.savedItems[index];
            return Column(
              children: [
                GestureDetector(
                  onTap: () {
                    log(item.toString());
                  },
                  child: PartShowWidget(
                    isHead: false,
                    // slNo: "${item.slNo}",
                    slNo: "${index + 1}",
                    barcode: item.barcode.toString(),
                    partName: item.partName.toString(),
                    qty: item.checkQty.toString(),
                    rsn: item.reasonCode.toString(),
                    onTap: () => _showDeleteDialog(con, item),
                  ),
                ),
                Divider(thickness: 1.5, color: Colors.black),
              ],
            );
          },
        ));
  }

  /// Shows confirmation dialog for clearing all items.
  void _showClearDialog(ReturnController con) {
    Get.dialog(
      Center(
        child: Material(
          elevation: 15,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            width: Get.width * 0.8,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Delete all items?", style: Get.textTheme.titleLarge),
                  SizedBox(height: 20),
                  Text(
                    "Are you sure you want to delete all items? This is IRREVERSIBLE!",
                    textAlign: TextAlign.justify,
                    style: Get.textTheme.labelLarge,
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ButtonWidget(
                        title: "Yes",
                        backgroundColor: Colors.green,
                        width: 100,
                        onPressed: () {
                          con.clearAll();
                          Get.back();
                        },
                        onLongPress: con.clearAll,
                      ),
                      ButtonWidget(
                          title: "No",
                          width: 100,
                          backgroundColor: Colors.red,
                          onPressed: () => Get.back()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  /// Shows a confirmation dialog before deleting an item.
  void _showDeleteDialog(ReturnController con, DocDetail item) {
    Get.dialog(
      Center(
        child: Material(
          elevation: 15,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            width: Get.width * 0.8,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // Ensures dialog height fits content
                children: [
                  Text(
                    "Delete Item?",
                    style: Get.textTheme.titleLarge,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Are you sure you want to delete ${item.barcode} with ${item.checkQty} quantity?",
                    textAlign: TextAlign.justify,
                    style: Get.textTheme.labelLarge,
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ButtonWidget(
                        width: 100,
                        height: 48,
                        title: "Yes",
                        backgroundColor: Colors.green,
                        onPressed: () {
                          con.onDeleteItem(item.slNo!);
                          Get.back();
                        },
                      ),
                      ButtonWidget(
                        width: 100,
                        height: 48,
                        title: "No",
                        backgroundColor: Colors.red,
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
}
