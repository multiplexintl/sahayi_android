import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/routes.dart';

import '../helper/custom_colors.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var con = Get.put(HomeController());
    return Scaffold(
      backgroundColor: CustomColors.scaffoldColor,
      bottomNavigationBar: BottomBarWidget(),
      appBar: CustomWidget.customAppBar(
        "Sahayi",
        connectivity: false,
        logout: () async {
          var res = await CustomWidget.customDialogue(
            title: "Log Out",
            subTitle: "Are you sure you want to log out?",
            onPressedBack: () => Get.back(result: false),
            onPressed: () => Get.back(result: true),
          );
          if (res) {
            con.logOut();
          }
        },
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, top: 5),
                  child: Text(
                    "Hi, ${con.user.value.empName}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )),
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              child: Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Material(
                        elevation: con.isInvoice.value ? 20 : 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: GestureDetector(
                          onTap: () => con.isInvoice.value
                              ? null
                              : con.isInvoice.toggle(),
                          child: Container(
                            height: 50,
                            width: 150,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: con.isInvoice.value
                                  ? Colors.green
                                  : Colors.red.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              "Invoice",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: con.isInvoice.value
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: con.isInvoice.value
                                        ? FontWeight.bold
                                        : null,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      Material(
                        elevation: con.isInvoice.value ? 0 : 20,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: GestureDetector(
                          onTap: () => con.isInvoice.value
                              ? con.isInvoice.toggle()
                              : null,
                          child: Container(
                            height: 50,
                            width: 150,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !con.isInvoice.value
                                  ? Colors.green
                                  : Colors.red.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              "Transfer",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: !con.isInvoice.value
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: con.isInvoice.value
                                        ? null
                                        : FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Obx(() => ButtonWidget(
                    width: 250,
                    title:
                        con.isInvoice.value ? 'Sync Invoice' : 'Sync Transfer',
                    onPressed: () {
                      Get.toNamed(RouteLinks.syncInvoice);
                    },
                  )),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Obx(() => ButtonWidget(
                    width: 250,
                    title: "Scan",
                    onPressed: con.scanIsLoading.value
                        ? null
                        : () {
                            con.getItemsThenToScanPage();
                          },
                    child: con.scanIsLoading.value
                        ? SizedBox(
                            height: 25,
                            width: 25,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : null,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Obx(
                () => ButtonWidget(
                  width: 250,
                  title: "Report",
                  onPressed: con.scanIsLoading.value ||
                          con.syncIsLoading.value ||
                          con.clearIsLoading.value
                      ? null
                      : () {
                          Get.toNamed(RouteLinks.invoiceReport);
                        },
                ),
              ),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 10),
                child: Text(
                  "Last fetched 10 invoices",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Row(
                children: [
                  Container(
                    width: context.width * 0.2 - 10,
                    alignment: Alignment.center,
                    color: Colors.blueGrey.shade300,
                    child: Text(
                      "Sl No",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Container(
                    width: context.width * 0.4 - 20,
                    color: Colors.blueGrey.shade300,
                    alignment: Alignment.center,
                    child: Text(
                      "Invoice Number",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Container(
                    width: context.width * 0.4 - 20,
                    color: Colors.blueGrey.shade300,
                    alignment: Alignment.center,
                    child: Text(
                      "Status  ",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() => ListView.builder(
                  padding: EdgeInsets.only(left: 20, right: 20, top: 8),
                  shrinkWrap: true,
                  itemCount: con.lastInvoices.length,
                  itemBuilder: (context, index) {
                    var item = con.lastInvoices[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: context.width * 0.2 - 10,
                            alignment: Alignment.center,
                            // color: index.isEven ? Colors.grey : Colors.white,
                            child: Text(
                              "${index + 1}",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: item.stat == "Y"
                                          ? Colors.green
                                          : Colors.red),
                            ),
                          ),
                          Container(
                            width: context.width * 0.4 - 20,
                            // color: index.isEven ? Colors.grey : Colors.white,
                            alignment: Alignment.center,
                            child: Text(
                              "${item.docNum}",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: item.stat == "Y"
                                          ? Colors.green
                                          : Colors.red),
                            ),
                          ),
                          Container(
                            width: context.width * 0.4 - 20,
                            // color: index.isEven ? Colors.grey : Colors.white,
                            alignment: Alignment.center,
                            child: Text(
                              item.stat == "Y" ? "Completed" : "Not Completed",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: item.stat == "Y"
                                          ? Colors.green
                                          : Colors.red),
                            ),
                          ),
                        ],
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
