import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/connectivity_controller.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/helper/custom_colors.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/widgets/bottom_bar.dart';
import 'package:sahayi_android/widgets/button.dart';

import '../helper/custom_widget.dart';

class SyncInvoiceScreen extends StatelessWidget {
  const SyncInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var con = Get.find<HomeController>();
    var connecCon = Get.find<ConnectivityController>();
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: CustomColors.scaffoldColor,
        resizeToAvoidBottomInset: false,
        appBar: CustomWidget.customAppBar(
            con.isInvoice.value ? "Sync Invoice" : "Sync Transfer",
            back: true),
        bottomNavigationBar: BottomBarWidget(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 30),
              Obx(() => CompanyDropdown(
                    companies: con.companyList,
                    onChanged: con.syncIsLoading.value
                        ? null
                        : (value) {
                            con.selectComapny(value);
                          },
                    selectedCompany: con.selectedCompany.value,
                    height: 53,
                    width: context.width - 100,
                    isDisabled: con.syncIsLoading.value,
                  )),
              SizedBox(height: 10),
              SizedBox(
                height: 79,
                width: context.width - 100,
                child: Obx(
                  () => TextFormField(
                    enabled: !con.syncIsLoading.value,
                    controller: con.invController,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.number,
                    // onTap: () {
                    //   log("message");
                    // },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'This field cannot be empty';
                      }
                      return null; // Input is valid
                    },
                    decoration: CustomWidget()
                        .inputDecoration(
                          context: context,
                          labelText: con.isInvoice.value
                              ? "Inv Number"
                              : "Shipment Number",
                        )
                        .copyWith(
                            suffixIcon: IconButton(
                          padding: EdgeInsets.all(0),
                          visualDensity: VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          onPressed: () {
                            con.invController.clear();
                          },
                          icon: Icon(Icons.clear),
                        )),
                  ),
                ),
              ),
              SizedBox(height: 0),
              Obx(() => ButtonWidget(
                    height: 48,
                    width: 250,
                    title: con.isInvoice.value
                        ? "Sync Invoice from Server"
                        : "Sync Transfer from Server",
                    onPressed: con.syncIsLoading.value
                        ? null
                        : () {
                            con.checkValidation();
                          },
                    child: con.syncIsLoading.value
                        ? SizedBox(
                            height: 25,
                            width: 25,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : null,
                  )),
              SizedBox(height: 30),
              Divider(
                thickness: 2,
                color: Colors.black,
                endIndent: 15,
                indent: 15,
              ),
              SizedBox(height: 30),
              Obx(() => ButtonWidget(
                    height: 48,
                    width: 250,
                    title: "DELETE DATABASE",
                    onPressed:
                        con.clearIsLoading.value || con.syncIsLoading.value
                            ? null
                            : () {
                                con.clearInvoiceDB();
                              },
                    child: con.clearIsLoading.value
                        ? SizedBox(
                            height: 25,
                            width: 25,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : null,
                  )),
              Spacer(),
              Obx(() => Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 25,
                        width: 25,
                        color: connecCon.isInternetConnected.value
                            ? Colors.green
                            : Colors.red,
                      ),
                      SizedBox(width: 20),
                      Text(
                        "Connection   -",
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: connecCon.isInternetConnected.value
                                      ? Colors.green
                                      : Colors.red,
                                ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        connecCon.isInternetConnected.value
                            ? "Success"
                            : "Fail",
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: connecCon.isInternetConnected.value
                                      ? Colors.green
                                      : Colors.red,
                                ),
                      ),
                    ],
                  )),
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class CompanyDropdown extends StatelessWidget {
  final List<Company> companies;
  final Company? selectedCompany;
  final ValueChanged<Company?>? onChanged;
  final double height;
  final double width;
  final String? Function(Company?)? validator;
  final bool isDisabled;

  const CompanyDropdown({
    super.key,
    required this.companies,
    required this.selectedCompany,
    required this.onChanged,
    this.height = 50.0,
    this.width = 200.0,
    this.validator,
    required this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<Company>(
      validator: validator,
      builder: (FormFieldState<Company> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: height,
              width: width,
              padding: const EdgeInsets.only(
                left: 18,
                right: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: state.hasError
                      ? Colors.red
                      : isDisabled
                          ? Colors.grey.shade400
                          : Colors.grey,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Company>(
                  value: selectedCompany,
                  // onChanged: (value) {
                  //   onChanged!(value);
                  //   state.didChange(value);
                  // },
                  onChanged: isDisabled
                      ? null
                      : (value) {
                          if (value != null) {
                            onChanged!(value);
                            state.didChange(value);
                          }
                        },
                  isExpanded: true,
                  items: companies.map((company) {
                    return DropdownMenuItem<Company>(
                      value: company,
                      child: Text(company.companyName ?? ''),
                    );
                  }).toList(),
                  icon: const Icon(Icons.arrow_drop_down),
                  hint: Text(
                    "Select Company",
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.merge(const TextStyle(
                          letterSpacing: 1.2,
                        )),
                  ),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 5, left: 10),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
