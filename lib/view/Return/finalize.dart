import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';

import '../../helper/custom_colors.dart';
import '../../helper/custom_widget.dart';
import '../../widgets/button.dart';
import '../../widgets/part_show.dart';

class FinalizeReturnScreen extends StatelessWidget {
  const FinalizeReturnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var con = Get.find<ReturnController>();

    return WillPopScope(
      onWillPop: () async => false, // Prevents accidental back navigation
      child: Scaffold(
        backgroundColor: CustomColors.scaffoldColor,
        resizeToAvoidBottomInset: false,
        appBar: CustomWidget.customAppBar("Finalize Returns", back: true),
        bottomNavigationBar: _buildBottomBar(con, context),
        body: Padding(
          padding: const EdgeInsets.only(top: 0, left: 10, right: 10),
          child: Column(
            children: [
              _buildHeader(),
              PartShowWidget(
                isHead: true,
                slNo: "Sl No",
                barcode: "Barcode",
                partName: 'Part Name',
                qty: "Qty",
                rsn: "Rsn",
                isView: true,
              ),
              Expanded(child: _buildItemList(con)),
            ],
          ),
        ),
      ),
    );
  }

  /// **Builds the Bottom Bar with Finalize Button**
  Widget _buildBottomBar(ReturnController con, BuildContext context) {
    return Container(
      height: 90,
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Total Quantity: ${con.totalQty.value}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ButtonWidget(
            width: 160,
            title: "Finalize",
            backgroundColor: Colors.green,
            onPressed: () => _finalizeReturn(con),
          ),
        ],
      ),
    );
  }

  /// **Builds the Header**
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        "Consolidated Items",
        style: Get.textTheme.titleLarge,
      ),
    );
  }

  /// **Builds the List of Consolidated Items**
  Widget _buildItemList(ReturnController con) {
    return Obx(() {
      if (con.finalizeIsLoading.value) {
        return Center(
          child: CircularProgressIndicator.adaptive(),
        );
      }
      return ListView.builder(
        padding: EdgeInsets.only(top: 5),
        shrinkWrap: true,
        itemCount: con.consolidatedSavedItems.length,
        itemBuilder: (context, index) {
          var item = con.consolidatedSavedItems[index];
          return Column(
            children: [
              PartShowWidget(
                isView: true,
                isHead: false,
                slNo: "${index + 1}",
                barcode: item.barcode.toString(),
                partName: item.partName.toString(),
                qty: item.checkQty.toString(),
                rsn: item.reasonCode.toString(),
                onTap: () => _showItemDetails(context, con, item),
              ),
              Divider(thickness: 1.5, color: Colors.black),
            ],
          );
        },
      );
    });
  }

  /// **Handles Finalization Process**
  Future<void> _finalizeReturn(ReturnController con) async {
    var res = await con.finalize();
    if (!res) {
      CustomWidget.customSnackBar(
        title: "Error!!",
        message: "Something went wrong, try again.",
        backgroundColor: Colors.red,
      );
      return;
    }
    Get.dialog(
      Align(
        alignment: Alignment.center,
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
                mainAxisSize: MainAxisSize.min, // Ensures it wraps content
                children: [
                  Text(
                    "Success!!",
                    style: Get.textTheme.titleLarge,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Successfully finalized the returns of ${con.selectedCustomer.value.custName} with Document Number: ${con.docNumber.value}.",
                    textAlign: TextAlign.left,
                    style: Get.textTheme.labelLarge,
                  ),
                  SizedBox(height: 20),
                  _buildSuccessButton(con),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// **Builds the "Okay" Button on Success Dialog**
  Widget _buildSuccessButton(ReturnController con) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ButtonWidget(
          width: 100,
          height: 48,
          title: "Okay!!",
          backgroundColor: Colors.green,
          onPressed: () {
            con.getUnfinishedDocs();
            con.update();
            Get.close(3);
          },
        ),
      ],
    );
  }

  /// **Displays Item Details in a Dialog**
  void _showItemDetails(
      BuildContext context, ReturnController con, DocDetail item) {
    // log(item.toString());
    var items = con.savedItems
        .where((pt) =>
            pt.barcode == item.barcode &&
            pt.reasonCode == item.reasonCode &&
            pt.expiryDate == item.expiryDate)
        .toList();
    log(items.toString());
    var entries = items.map<int>((element) => element.checkQty ?? 0).toList();
    log(entries.toString());
    int total = entries.reduce((a, b) => a + b);
    log("Total: $total");

    Get.dialog(
      Center(
        child: Material(
          elevation: 15,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: SizedBox(
            width: Get.width * 0.8,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Text(
                      "Details",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.black,
                            decorationThickness: 1.5,
                            decorationStyle: TextDecorationStyle.solid,
                          ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _rowWidget(
                                head: "Item", detail: "${item.partName}"),
                            _rowWidget(
                                head: "Barcode", detail: "${item.barcode}"),
                            _rowWidget(
                                head: "Reason", detail: "${item.reasonName}"),
                            _rowWidget(head: "Entries", detail: "$entries"),
                            Visibility(
                              visible: item.expiryDate != null,
                              child: _rowWidget(
                                  head: "Expiry",
                                  detail: formatDate("${item.expiryDate}")),
                            ),
                            _rowWidget(head: "Total", detail: "$total"),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildDialogOkayButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Widget _rowWidget({required String head, required String detail}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              head,
              style: Get.textTheme.labelLarge,
            ),
          ),
          Text(
            ": ",
            style: Get.textTheme.labelLarge,
          ),
          Expanded(
            child: Text(
              detail,
              style: Get.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(String date) {
    if (date == "null" || date.isEmpty) return "";
    try {
      DateTime parsedDate = DateTime.parse(date);
      return "${parsedDate.day.toString().padLeft(2, '0')}/"
          "${parsedDate.month.toString().padLeft(2, '0')}/"
          "${parsedDate.year}";
    } catch (e) {
      return date; // Return original string if parsing fails
    }
  }
  // Widget _rowWidget2(
  //     {required String head, required List<Map<String, String>> items}) {

  //   return Padding(
  //     padding: const EdgeInsets.only(top: 10),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         SizedBox(
  //           width: 70,
  //           child: Text(
  //             head,
  //             style: Get.textTheme.labelLarge,
  //           ),
  //         ),
  //         Text(
  //           ": ",
  //           style: Get.textTheme.labelLarge,
  //         ),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: items.map((item) {
  //               String checkQty = item.keys.first; // Get checkQty from key
  //               String expiryDate =
  //                   item.values.first; // Get expiryDate from value

  //               return Text(
  //                 "$checkQty${formatDate(expiryDate)}",
  //                 style: Get.textTheme.labelLarge,
  //               );
  //             }).toList(),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// **Builds the "Okay" Button in Item Details Dialog**
  Widget _buildDialogOkayButton() {
    return ButtonWidget(
      width: 100,
      height: 48,
      title: "Okay",
      backgroundColor: Colors.green,
      onPressed: () => Get.back(),
    );
  }
}
