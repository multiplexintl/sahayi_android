import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/controller/report_controller.dart';
import 'package:sahayi_android/helper/custom_colors.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/model/report/report.dart';
import 'package:sahayi_android/widgets/bottom_bar.dart';
import 'package:sahayi_android/widgets/button.dart';

import '../../widgets/year_picker.dart';

class ReportViewPage extends StatelessWidget {
  const ReportViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    var con = Get.put(ReportController());
    var user = Get.find<HomeController>().user.value;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: CustomWidget.customAppBar("Report", back: true),
        backgroundColor: CustomColors.scaffoldColor,
        bottomNavigationBar: BottomBarWidget(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 12, bottom: 0),
              child: Text(
                "Employee : ${user.empName}",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => CheckboxListTile(
                      value: con.fetchAll.value,
                      onChanged: (val) {
                        con.fetchAll.value = val!;
                      },
                      title: Text("Fetch all companies reports"),
                      controlAffinity: ListTileControlAffinity.leading,
                      visualDensity:
                          VisualDensity(horizontal: -4, vertical: -4),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                // Padding(
                //   padding: const EdgeInsets.only(right: 12),
                //   child: SizedBox(
                //     height: 38,
                //     width: 160,
                //     child: Obx(() => TextField(
                //           controller: con.docNumController.value,
                //           keyboardType: TextInputType.number,
                //           decoration: CustomWidget()
                //               .inputDecoration(context: context, radius: 10)
                //               .copyWith(
                //                 labelText: "Doc Num",
                //                 contentPadding: EdgeInsets.only(left: 12),
                //               ),
                //         )),
                //   ),
                // ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: Obx(
                    () => DropdownButton<Map<String, dynamic>>(
                      icon: const Icon(Icons.arrow_drop_down),
                      alignment: Alignment.centerLeft,
                      isDense: true,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 5,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      hint: Text(
                        "Select Report Type",
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.merge(const TextStyle(
                              letterSpacing: 1.2,
                            )),
                      ),
                      style: Theme.of(context).textTheme.labelLarge,
                      menuWidth: 200,
                      value: con.selectedType.value,
                      items: con.reportTypes.map((element) {
                        return DropdownMenuItem(
                          value: element,
                          child: Text(element.values.first
                              .toString()), // Correctly extracts a value
                        );
                      }).toList(),
                      onChanged: (map) {
                        if (map != null) {
                          con.selectedType.value = map;
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.only(left: 10, right: 10),
                  child: Row(
                    children: [
                      Container(
                        height: 20,
                        width: 20,
                        decoration: BoxDecoration(color: Colors.green),
                      ),
                      Text(" : Invoice"),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(left: 10, right: 10),
                  child: Row(
                    children: [
                      Container(
                        height: 20,
                        width: 20,
                        decoration: BoxDecoration(color: Colors.yellow),
                      ),
                      Text(" : Transfer"),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(left: 10, right: 10),
                  child: Row(
                    children: [
                      Container(
                        height: 20,
                        width: 20,
                        decoration: BoxDecoration(color: Colors.red),
                      ),
                      Text(" : Return"),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: 40,
                    width: context.width * 0.45,
                    child: Obx(() => TextFormField(
                          readOnly: true,
                          controller: con.fromDateController.value,
                          onTap: () {
                            DateTime today = DateTime.now();
                            showYearMonthPicker(
                              minimumYear: DateTime.now().year - 32,
                              maximumYear: DateTime.now().year,
                              maximumDate: today,
                              minimumDate: DateTime(
                                  today.year - 32, today.month, today.day),
                              dateNeeded: true,
                              initialDateTime: con
                                      .fromDateController.value.text.isNotEmpty
                                  ? DateFormat("dd-MM-yyyy")
                                      .parse(con.fromDateController.value.text)
                                  : null,
                              onTapCancel: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                con.updateDate(date: null, isFrom: true);
                                Get.back();
                              },
                              onTapSubmit: () {
                                if (con.fromDateController.value.text.isEmpty) {
                                  con.updateDate(
                                      date: DateTime.now(), isFrom: true);
                                }
                                Get.back();
                              },
                              onDateTimeChanged: (date) {
                                con.updateDate(date: date, isFrom: true);
                              },
                            );
                          },
                          decoration: CustomWidget()
                              .inputDecoration(
                                context: context,
                                labelText: "From Date",
                                radius: 10,
                              )
                              .copyWith(
                                contentPadding: EdgeInsets.only(left: 15),
                              ),
                        )),
                  ),
                  SizedBox(
                    height: 40,
                    width: context.width * 0.45,
                    child: Obx(() => TextFormField(
                          controller: con.toDateController.value,
                          readOnly: true,
                          onTap: () {
                            DateTime today = DateTime.now();
                            showYearMonthPicker(
                              minimumYear: DateTime.now().year - 32,
                              maximumYear: DateTime.now().year,
                              maximumDate: today,
                              minimumDate: DateTime(
                                  today.year - 32, today.month, today.day),
                              dateNeeded: true,
                              initialDateTime: con
                                      .toDateController.value.text.isNotEmpty
                                  ? DateFormat("dd-MM-yyyy")
                                      .parse(con.toDateController.value.text)
                                  : null,
                              onTapCancel: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                con.updateDate(date: null, isFrom: false);
                                Get.back();
                              },
                              onTapSubmit: () {
                                if (con.toDateController.value.text.isEmpty) {
                                  con.updateDate(
                                      date: DateTime.now(), isFrom: false);
                                }
                                Get.back();
                              },
                              onDateTimeChanged: (date) {
                                con.updateDate(date: date, isFrom: false);
                              },
                            );
                          },
                          decoration: CustomWidget()
                              .inputDecoration(
                                context: context,
                                labelText: "To Date",
                                radius: 10,
                              )
                              .copyWith(
                                  contentPadding: EdgeInsets.only(left: 15)),
                        )),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  top: 10, bottom: 10, left: 15, right: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Obx(() => ButtonWidget(
                        title: "Clear",
                        height: 40,
                        width: context.width * 0.40,
                        onPressed: con.isLoading.value
                            ? null
                            : () {
                                con.clearDates();
                              },
                      )),
                  Obx(() => ButtonWidget(
                        title: "Submit",
                        height: 40,
                        width: context.width * 0.40,
                        onPressed: con.isLoading.value
                            ? null
                            : () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                con.fetchReport();
                              },
                        child: con.isLoading.value
                            ? SizedBox(
                                height: 25,
                                width: 25,
                                child: CircularProgressIndicator.adaptive())
                            : null,
                      )),
                ],
              ),
            ),
            Expanded(
              child: Obx(() => ListView.builder(
                  shrinkWrap: true,
                  itemCount: con.reports.length,
                  itemBuilder: (context, index) {
                    var item = con.reports[index];
                    return GestureDetector(
                      onTap: () {
                        con.selectReport(item);
                      },
                      child: ReportContainerWidget(
                        index: index,
                        report: item,
                      ),
                    );
                  })),
            )
          ],
        ),
      ),
    );
  }
}

class ReportContainerWidget extends StatelessWidget {
  final int index;
  final Report? report;
  const ReportContainerWidget({
    super.key,
    required this.index,
    this.report,
  });

  @override
  Widget build(BuildContext context) {
    /// Returns color based on the document type
    Color getColor(String? docType) {
      switch (docType) {
        case 'I':
          return Colors.green.shade300;
        case 'T':
          return Colors.yellow.shade300;
        case 'R':
          return Colors.red.shade300;
        default:
          return Colors.white;
      }
    }

    final Color bgColor = getColor(report?.docType);
    final Color sidePanelColor =
        index.isOdd ? Colors.white : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      child: Material(
        elevation: 15,
        shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: context.width,
          decoration: BoxDecoration(
            // color: index.isEven ? Colors.white : Colors.grey.shade300,
            color: bgColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      // color: index.isOdd ? Colors.white : Colors.grey.shade300,
                      color: sidePanelColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        topLeft: Radius.circular(15),
                      )),
                  child: Text(
                    "${index + 1}",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.black.withOpacity(0.7),
                        ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(left: 8.0, top: 5, bottom: 5),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Company"),
                            Text("Doc Num"),
                            Text("Cust ID"),
                            Text("Cust Name"),
                            Spacer(),
                            Text("Scan Time"),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(" : "),
                            Text(" : "),
                            Text(" : "),
                            Text(" : "),
                            Spacer(),
                            Text(" : "),
                          ],
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${report?.company}"),
                              Text("${report?.docNum}"),
                              Text("${report?.custId}"),
                              Text("${report?.custName}"),
                              Spacer(),
                              Text("${report?.scanTime}"),
                            ],
                          ),
                        ),
                      ],
                    ),
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
