import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/routes.dart';

import '../helper/custom_colors.dart';
import '../widgets/bottom_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var con = Get.put(HomeController());
    Get.put(ReturnController());
    var invTrfCon = Get.put(InvoiceOrTransferController());
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
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 25, bottom: 15),
              child: Text(
                "Hi, ${con.user.value.empName}",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 15,
              runSpacing: 15,
              children: [
                _containerWidget(
                  context: context,
                  title: "Invoice",
                  onTap: () async {
                    invTrfCon.isInvoice.value = true;
                    await invTrfCon.getLastInvoices(docType: 'I');
                    Get.toNamed(RouteLinks.invoiceTransfer);
                  },
                ),
                _containerWidget(
                  context: context,
                  title: "Transfer",
                  onTap: () async {
                    invTrfCon.getLastInvoices(docType: 'T');
                    invTrfCon.isInvoice.value = false;
                    Get.toNamed(RouteLinks.invoiceTransfer);
                  },
                ),
                _containerWidget(
                  context: context,
                  title: "Return",
                  onTap: () {
                    Get.toNamed(RouteLinks.customerSelect);
                  },
                ),
                _containerWidget(
                  context: context,
                  title: "Report",
                  onTap: () {
                    Get.toNamed(RouteLinks.invoiceReport);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Material _containerWidget({
    required BuildContext context,
    required String title,
    void Function()? onTap,
  }) {
    // List<Color> colors = [
    //   Colors.red,
    //   Colors.blue,
    //   Colors.green,
    //   Colors.orange,
    //   Colors.indigo,
    //   Colors.deepOrange
    // ];
    // List<Color> getUniqueColors(List<Color> colors) =>
    //     (colors..shuffle(Random()));
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 10,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 100,
          padding: EdgeInsets.only(left: 15, right: 15),
          width: context.width - (context.width / 2) - 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.indigo.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
