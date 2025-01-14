import 'dart:developer';

import 'package:auto_size_text_plus/auto_size_text_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/helper/custom_colors.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/widgets/button.dart';

class ScanInvoiceScreen extends StatelessWidget {
  const ScanInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    GlobalKey<FormState> formKey = GlobalKey<FormState>();
    var con = Get.find<HomeController>();
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: CustomColors.scaffoldColor,
        resizeToAvoidBottomInset: false,
        appBar: CustomWidget.customAppBar("Scan", back: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            con.fillAllDebug();
                          },
                          child: Text(
                            "Inv No:  ${con.invoice.value.docNum ?? ''}",
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Colors.blue,
                                ),
                          ),
                        ),
                        Text(
                          "Inv Date:",
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.blue,
                                  ),
                        ),
                        Text(
                          (() {
                            try {
                              return DateFormat("MM/dd/yyyy").format(
                                  DateFormat("M/d/yyyy h:mm:ss a")
                                      .parse("${con.invoice.value.docDate}"));
                            } catch (e) {
                              return "";
                            }
                          })(),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.blue,
                                  ),
                        ),
                      ],
                    )),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Obx(() => Text(
                          "${(con.isInvoice.value) ? "Cust Name" : "Store Name"}: ${con.invoice.value.custName ?? ''}",
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.red,
                                  ),
                        )),
                  ),
                ),
                Form(
                  key: formKey,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        // height: 50,
                        width: 160,
                        child: Obx(
                          () => TextFormField(
                            controller: con.barcodeController,
                            enabled: !con.scanIsLoading.value,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'This field cannot be empty';
                              } else if (value.length < 10 ||
                                  value.length > 14) {
                                return 'Length must be between 10 and 14 characters';
                              }
                              return null; // Input is valid
                            },
                            onChanged: (value) {
                              con.scrollToBarcode(
                                  value); // Scroll when barcode is submitted
                            },
                            decoration: CustomWidget()
                                .inputDecoration(context: context)
                                .copyWith(
                                  labelText: "Barcode",
                                  contentPadding:
                                      EdgeInsets.only(left: 12, right: 10),
                                  errorStyle: TextStyle(
                                    fontSize:
                                        10.0, // Smaller text for error message
                                    height:
                                        0.8, // Adjust height for compactness
                                  ),
                                ),
                          ),
                        ),
                      ),
                      SizedBox(width: 5),
                      SizedBox(
                        // height: 50,
                        width: 70,
                        child: Obx(() => TextFormField(
                              controller: con.qtyController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.go,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onEditingComplete: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                con.saveQty();
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'This field cannot be empty';
                                }
                                return null; // Input is valid
                              },
                              enabled: !con.scanIsLoading.value,
                              decoration: CustomWidget()
                                  .inputDecoration(context: context)
                                  .copyWith(
                                    labelText: "Qty",
                                    contentPadding: EdgeInsets.only(left: 12),
                                    errorStyle: TextStyle(
                                      fontSize:
                                          10.0, // Smaller text for error message
                                      height:
                                          0.8, // Adjust height for compactness
                                    ),
                                  ),
                            )),
                      ),
                      SizedBox(width: 5),
                      Obx(() => ButtonWidget(
                            width: 100,
                            // height: 35,
                            title: "Save",
                            onPressed: con.scanIsLoading.value
                                ? null
                                : () {
                                    // each save needs to trigger local database save
                                    if (formKey.currentState?.validate() ==
                                        true) {
                                      con.saveQty();
                                    }
                                  },
                            child: con.scanIsLoading.value
                                ? SizedBox(
                                    height: 15,
                                    width: 15,
                                    child: CircularProgressIndicator.adaptive(),
                                  )
                                : null,
                          )),
                    ],
                  ),
                ),
                SizedBox(height: 5),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                //   children: [
                //     Obx(() => ButtonWidget(
                //           width: 120,
                //           height: 35,
                //           title: "Clear",
                // onPressed: con.scanIsLoading.value
                //     ? null
                //     : () {
                //         FocusManager.instance.primaryFocus?.unfocus();
                //         con.clearFields();
                //       },
                //         )),
                //     Obx(() => ButtonWidget(
                //           width: 120,
                //           height: 35,
                //           title: "Save",
                //           onPressed: con.scanIsLoading.value
                //               ? null
                //               : () {
                //                   // each save needs to trigger local database save
                //                   if (formKey.currentState?.validate() ==
                //                       true) {
                //                     con.saveQty();
                //                   }
                //                 },
                //           child: con.scanIsLoading.value
                //               ? SizedBox(
                //                   height: 15,
                //                   width: 15,
                //                   child: CircularProgressIndicator.adaptive(),
                //                 )
                //               : null,
                //         )),
                //   ],
                // ),
                SizedBox(height: 5),
                Obx(() => Text(
                      "Item Name: ${con.scannedItem.value.partName ?? ''}",
                      style: Theme.of(context).textTheme.titleSmall,
                    )),
                SizedBox(height: 10),
                // Table using listvie builder
                HeadingWidget2(),
                Expanded(
                  child: Obx(() => con.invoice.value.docNum == null
                      ? Center(
                          child: Text("No Data"),
                        )
                      : ListView.builder(
                          controller: con.scrollController,
                          shrinkWrap: true,
                          itemCount: con.invoice.value.docDetails?.length,
                          padding: EdgeInsets.only(bottom: 230),
                          itemBuilder: (context, index) {
                            var item = con.invoice.value.docDetails?[index];
                            return GestureDetector(
                              onTap: () {
                                con.testSave(item.barcode!, item.shipQty!);
                              },
                              child: TableRowWidget2(
                                index: index + 1,
                                partNum: "${item?.partNum}",
                                partName: "${item?.partName}",
                                barcode: "${item?.barcode}",
                                qty1: item!.shipQty!,
                                qty2: item.checkQty!,
                                bgColor: item.checkQty == item.shipQty
                                    ? Colors.green.shade300
                                    : Colors.red.shade100,
                                textColor: item.checkQty == item.shipQty
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            );
                          },
                        )),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Obx(() => ButtonWidget(
                            title: "Clear",
                            height: 48,
                            width: 150,
                            onPressed: con.scanIsLoading.value
                                ? null
                                : () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    con.clearFields();
                                  },
                          )),
                      Obx(() => ButtonWidget(
                            title: "Finalize ",
                            height: 48,
                            width: 150,
                            onPressed: con.scanIsLoading.value
                                ? null
                                : () {
                                    con.finalize();
                                  },
                            child: con.scanIsLoading.value
                                ? SizedBox(
                                    height: 15,
                                    width: 15,
                                    child: CircularProgressIndicator.adaptive(),
                                  )
                                : null,
                          )),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TableRowWidget2 extends StatelessWidget {
  final int index;
  final String partNum;
  final String partName;
  final String barcode;
  final int qty1;
  final int qty2;
  final Color bgColor;
  final Color textColor;

  const TableRowWidget2({
    super.key,
    required this.index,
    required this.partNum,
    required this.partName,
    required this.barcode,
    required this.qty1,
    required this.qty2,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: 0, right: 0),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.white,
            width: 1,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                " $index",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: textColor),
              ),
            ),
            VerticalDivider(
              color: Colors.white,
              width: 1,
            ),
            SizedBox(
              width: 206,
              child: Padding(
                padding:
                    const EdgeInsets.only(left: 5, top: 8, bottom: 8, right: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 90,
                            child: AutoSizeText(partNum,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    )),
                          ),
                          SizedBox(
                            height: 20,
                            width: 100,
                            child: AutoSizeText(barcode,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    )),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      partName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: textColor),
                    ),
                  ],
                ),
              ),
            ),
            Spacer(),
            VerticalDivider(
              color: Colors.white,
              width: 1,
            ),
            SizedBox(
                width: 50,
                child: Center(
                  child: Text(
                    "$qty1",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: textColor),
                  ),
                )),
            VerticalDivider(
              color: Colors.white,
              width: 1,
            ),
            SizedBox(
                width: 50,
                child: Center(
                  child: Text(
                    "$qty2",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: textColor),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class HeadingWidget2 extends StatelessWidget {
  const HeadingWidget2({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Colors.black,
            width: 1,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              child: Text(" No", style: Theme.of(context).textTheme.bodyMedium),
            ),
            VerticalDivider(
              color: Colors.black,
              width: 1,
            ),
            SizedBox(
              width: 190,
              child: Padding(
                padding: const EdgeInsets.only(left: 5, top: 8, bottom: 8),
                child: Text("Part Num \\ Barcode\nPartName",
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
            Spacer(),
            VerticalDivider(
              color: Colors.black,
              width: 1,
            ),
            SizedBox(
                width: 50,
                child: Center(
                  child:
                      Text("Q1", style: Theme.of(context).textTheme.bodyMedium),
                )),
            VerticalDivider(
              color: Colors.black,
              width: 1,
            ),
            SizedBox(
                width: 50,
                child: Center(
                  child:
                      Text("Q2", style: Theme.of(context).textTheme.bodyMedium),
                )),
          ],
        ),
      ),
    );
  }
}

// class HeadingWidget extends StatelessWidget {
//   const HeadingWidget({
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 30,
//       width: double.infinity,
//       decoration: BoxDecoration(
//           color: Colors.blueGrey.withOpacity(0.3),
//           border: Border.all(
//             color: Colors.black,
//             width: 1,
//           )),
//       padding: EdgeInsets.only(left: 5, right: 5),
//       child: IntrinsicHeight(
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             SizedBox(
//               width: 24,
//               child: Text("No", style: Theme.of(context).textTheme.bodyMedium),
//             ),
//             VerticalDivider(
//               color: Colors.black,
//               width: 1,
//             ),
//             SizedBox(
//               width: 145,
//               child: Text(" Part Num\\PartName",
//                   style: Theme.of(context).textTheme.bodyMedium),
//             ),
//             VerticalDivider(
//               color: Colors.black,
//               width: 1,
//             ),
//             SizedBox(
//               width: 100,
//               child: Text(" Barcode",
//                   style: Theme.of(context).textTheme.bodyMedium),
//             ),
//             VerticalDivider(
//               color: Colors.black,
//               width: 1,
//             ),
//             SizedBox(
//                 width: 30,
//                 child:
//                     Text(" Q1", style: Theme.of(context).textTheme.bodyMedium)),
//             VerticalDivider(
//               color: Colors.black,
//               width: 1,
//             ),
//             SizedBox(
//                 width: 30,
//                 child:
//                     Text(" Q2", style: Theme.of(context).textTheme.bodyMedium)),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class TableRowWidget extends StatelessWidget {
//   final int index;
//   final String partNumName;
//   final String barcode;
//   final int qty1;
//   final int qty2;
//   final Color bgColor;
//   final Color textColor;

//   const TableRowWidget({
//     super.key,
//     required this.index,
//     required this.partNumName,
//     required this.barcode,
//     required this.qty1,
//     required this.qty2,
//     required this.bgColor,
//     required this.textColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.only(left: 0, right: 0),
//       decoration: BoxDecoration(
//         color: bgColor,
//         border: Border(
//           bottom: BorderSide(
//             color: Colors.white,
//             width: 1,
//           ),
//         ),
//       ),
//       child: IntrinsicHeight(
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             SizedBox(
//               width: 30,
//               child: Text(
//                 " $index",
//                 style: Theme.of(context)
//                     .textTheme
//                     .bodyMedium
//                     ?.copyWith(color: textColor),
//               ),
//             ),
//             VerticalDivider(
//               color: Colors.white,
//               width: 1,
//             ),
//             SizedBox(
//               width: 145,
//               child: Text(
//                 partNumName,
//                 style: Theme.of(context)
//                     .textTheme
//                     .bodyMedium
//                     ?.copyWith(color: textColor),
//               ),
//             ),
//             VerticalDivider(
//               color: Colors.white,
//               width: 1,
//             ),
//             SizedBox(
//                 width: 100,
//                 child: Text(
//                   barcode,
//                   style: Theme.of(context)
//                       .textTheme
//                       .bodyMedium
//                       ?.copyWith(color: textColor),
//                 )),
//             VerticalDivider(
//               color: Colors.white,
//               width: 1,
//             ),
//             SizedBox(
//                 width: 30,
//                 child: Center(
//                   child: Text(
//                     "$qty1",
//                     style: Theme.of(context)
//                         .textTheme
//                         .bodyMedium
//                         ?.copyWith(color: textColor),
//                   ),
//                 )),
//             VerticalDivider(
//               color: Colors.white,
//               width: 1,
//             ),
//             SizedBox(
//                 width: 30,
//                 child: Center(
//                   child: Text(
//                     "$qty2",
//                     style: Theme.of(context)
//                         .textTheme
//                         .bodyMedium
//                         ?.copyWith(color: textColor),
//                   ),
//                 )),
//           ],
//         ),
//       ),
//     );
//   }
// }
