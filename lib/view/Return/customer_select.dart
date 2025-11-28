import 'dart:developer';

import 'package:drop_down_search_field/drop_down_search_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';
import 'package:sahayi_android/model/return/customer.dart';
import 'package:sahayi_android/widgets/button.dart';

import '../../helper/custom_colors.dart';
import '../../helper/custom_widget.dart';
import '../../model/company.dart';
import '../../model/user.dart';
import '../../widgets/bottom_bar.dart';
import '../../widgets/drop_down.dart';
import '../../widgets/year_picker.dart';

class CustomerSelectScreen extends StatelessWidget {
  const CustomerSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var con = Get.find<ReturnController>();
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: CustomColors.scaffoldColor,
        bottomNavigationBar: BottomBarWidget(),
        appBar: CustomWidget.customAppBar(
          "Return",
          connectivity: false,
          logout: null,
          back: true,
        ),
        resizeToAvoidBottomInset: false,
        body: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
          child: Column(
            children: [
              Obx(
                () => CustomDropdown<Company>(
                  items: con.companyList,
                  onChanged: con.syncIsLoading.value
                      ? null
                      : (value) {
                          con.selectComapny(value);
                        },
                  selectedItem: con.selectedCompany.value,
                  height: 53,
                  width: context.width,
                  isDisabled: con.syncIsLoading.value,
                  getItemLabel: (company) => company?.companyName ?? '',
                  label: "Select Company",
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: 60,
                child: Obx(
                  () => DropDownSearchField<Customer>(
                    displayAllSuggestionWhenTap: true,
                    isMultiSelectDropdown: false,
                    debounceDuration: Duration(milliseconds: 500),
                    textFieldConfiguration: TextFieldConfiguration(
                      controller: con.custController,
                      keyboardType: TextInputType.name,
                      style: Theme.of(context).textTheme.labelLarge,
                      enabled: con.selectedCompany.value != null,
                      decoration: CustomWidget().inputDecoration(
                        context: context,
                        labelText: "Customer",
                        radius: 16,
                      ),
                    ),
                    hideOnEmpty: true,
                    hideOnLoading: false,
                    suggestionsCallback: (pattern) async {
                      return await con.getSuggestions(pattern);
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        leading: Icon(Icons.business),
                        title: Text(suggestion.custId!),
                        subtitle: Text('${suggestion.custName}'),
                      );
                    },
                    onSuggestionSelected: (suggestion) {
                      con.onCustomerSelected(suggestion);
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 60,
                child: Obx(
                  () => TextField(
                    controller: con.docNumController,
                    enabled: con.selectedCompany.value != null,
                    decoration: CustomWidget().inputDecoration(
                        context: context, labelText: "Doc Number", radius: 16),
                  ),
                ),
              ),
              SizedBox(height: 5),
              SizedBox(
                height: 60,
                child: Obx(
                  () => TextField(
                    controller: con.docDateController,
                    readOnly: true,
                    enabled: con.selectedCompany.value != null,
                    onTap: () {
                      DateTime today = DateTime.now();

                      DateTime maxAllowedDate =
                          DateTime(today.year, today.month, today.day);
                      log(maxAllowedDate.toString());

                      showYearMonthPicker(
                        minimumYear: DateTime.now().year -
                            2, // Allow dates up to 100 years ago
                        maximumYear: DateTime.now().year, // 12 years or older+
                        maximumDate: maxAllowedDate,
                        minimumDate:
                            DateTime(today.year - 2, today.month, today.day),
                        dateNeeded: true,
                        initialDateTime:
                            con.docDateController.value.text.isNotEmpty
                                ? DateFormat("dd-MM-yyyy")
                                    .parse(con.docDateController.value.text)
                                : maxAllowedDate,
                        onTapCancel: () {
                          con.docDateController.clear();
                          FocusManager.instance.primaryFocus?.unfocus();
                          Get.back();
                        },
                        onTapSubmit: () {
                          log(con.docDateController.value.text);
                          if (con.docDateController.value.text.isEmpty) {
                            String formattedDate =
                                DateFormat("dd-MM-yyyy").format(DateTime.now());
                            con.docDateController.text = formattedDate;
                            con.docDate.value = formattedDate;
                          }
                          Get.back();
                        },
                        onDateTimeChanged: (date) {
                          log(date.toString());
                          String formattedDate =
                              DateFormat("dd-MM-yyyy").format(date);
                          con.docDateController.text = formattedDate;
                          con.docDate.value = formattedDate;
                          con.update();
                        },
                      );
                    },
                    decoration: CustomWidget().inputDecoration(
                        context: context,
                        labelText: "Document Date",
                        radius: 16),
                  ),
                ),
              ),
              SizedBox(height: 5),
              Obx(
                () => CustomDropdown<Pickers?>(
                  items: con.driverList,
                  onChanged: con.selectIsLoading.value
                      ? null
                      : (value) {
                          con.selectDriver(value);
                        },
                  selectedItem: con.selectedDriver.value,
                  height: 53,
                  width: context.width,
                  isDisabled: con.selectIsLoading.value ||
                      con.selectedCompany.value == null,
                  getItemLabel: (driver) => driver?.name ?? '',
                  label: "Select Driver/Helper",
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ButtonWidget(
                    title: "Submit",
                    width: context.width - (context.width / 2) - 30,
                    backgroundColor: Colors.green,
                    onPressed: () async {
                      con.onSubmit(null);
                    },
                    onLongPress: () async {
                      await DBHelper.listColumnsInTable(DBHelper.docMaster);
                      await DBHelper.listColumnsInTable(DBHelper.docDetail);
                    },
                  ),
                  ButtonWidget(
                    title: "Clear",
                    width: context.width - (context.width / 2) - 30,
                    backgroundColor: Colors.red,
                    onPressed: () {
                      con.clearCustSelction();
                      // con.getUnfinishedDocs();
                    },
                    // onLongPress: () => con.clearUnfinished(),
                  )
                ],
              ),
              SizedBox(height: 5),
              // Divider(
              //   color: Colors.black,
              //   thickness: 1.5,
              // ),
              Obx(() => Visibility(
                    visible: con.unFinishedDocs.isNotEmpty,
                    child: Text(
                      "Not Finished Documnets",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: TextDecoration.underline,
                            decorationThickness: 1.5,
                            decorationColor: Colors.black,
                            decorationStyle: TextDecorationStyle.solid,
                          ),
                    ),
                  )),

              Obx(() => Visibility(
                    visible: con.unFinishedDocs.isNotEmpty,
                    child: Container(
                      // padding: EdgeInsets.only(top: 5, bottom: 5),
                      decoration: BoxDecoration(
                          color: Colors.blueGrey,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          )),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: Text(
                                "Sl No",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                            VerticalDivider(
                              color: Colors.white,
                              thickness: 1.5,
                              width: 10,
                            ),
                            Container(
                              padding: EdgeInsets.only(top: 8, bottom: 8),
                              width: 160,
                              child: Text(
                                "Cust ID\nCust Name",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      height: 0.9,
                                    ),
                              ),
                            ),
                            // SizedBox(width: 10),
                            VerticalDivider(
                              color: Colors.white,
                              thickness: 1.5,
                              width: 10,
                            ),
                            Expanded(
                              child: SizedBox(
                                child: Text(
                                  "Doc Num",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    itemCount: con.unFinishedDocs.length,
                    itemBuilder: (context, index) {
                      var item = con.unFinishedDocs[index];
                      return GestureDetector(
                        onTap: () async {
                          con.onSubmit(item);
                        },
                        child: Dismissible(
                          key: Key(
                              "${item.custID}${item.docNum}"), // Unique key for each item
                          direction: DismissDirection
                              .horizontal, // Swipe left or right
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: 20),
                            color: Colors.red,
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            bool confirm = await CustomWidget.customDialogue(
                              title: "Confirm Delete",
                              subTitle:
                                  "Are you sure you want to delete this document?",
                              onPressed: () => Get.back(result: true),
                              onPressedBack: () => Get.back(result: false),
                            );
                            log(confirm.toString());
                            if (confirm == true) {
                              bool success = await con.removeUnfinished(item);
                              if (success) {
                                return true; // Only now remove from UI
                              }
                              return false; // Keep in UI if deletion failed
                            }
                            return false; // Cancel dismissal
                          },

                          child: Container(
                            decoration: BoxDecoration(
                                color: index.isOdd ? Colors.grey : Colors.white,
                                borderRadius: BorderRadius.only(
                                  bottomLeft:
                                      index == con.unFinishedDocs.length - 1
                                          ? Radius.circular(10)
                                          : Radius.circular(0),
                                  bottomRight:
                                      index == con.unFinishedDocs.length - 1
                                          ? Radius.circular(10)
                                          : Radius.circular(0),
                                )),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    alignment: Alignment.center,
                                    child: Text(
                                      "${index + 1}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Colors.black,
                                          ),
                                    ),
                                  ),
                                  VerticalDivider(
                                    color: index.isEven
                                        ? Colors.grey
                                        : Colors.white,
                                    thickness: 1.5,
                                    width: 10,
                                  ),
                                  Container(
                                    padding: EdgeInsets.only(top: 8, bottom: 8),
                                    width: 160,
                                    child: Text(
                                      "${item.custID}\n${item.custName}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Colors.black,
                                            height: 1.2,
                                          ),
                                    ),
                                  ),
                                  // SizedBox(width: 10),
                                  VerticalDivider(
                                    color: index.isEven
                                        ? Colors.grey
                                        : Colors.white,
                                    thickness: 1.5,
                                    width: 10,
                                  ),
                                  Expanded(
                                    child: SizedBox(
                                      child: Text(
                                        "${item.docNum}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Colors.black,
                                            ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Icon(
                                      Icons.forward_rounded,
                                      color: Colors.green,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 10,
              )
            ],
          ),
        ),
      ),
    );
  }
}
