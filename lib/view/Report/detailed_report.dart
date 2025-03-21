import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/report_controller.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import '../../helper/custom_colors.dart';

class DetailedReportPage extends StatefulWidget {
  const DetailedReportPage({super.key});

  @override
  State<DetailedReportPage> createState() => _DetailedReportPageState();
}

class _DetailedReportPageState extends State<DetailedReportPage> {
  var con = Get.find<ReportController>();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final ScrollController _scrollController = ScrollController();

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  void _scrollToBarcode(String barcode) {
    if (con.detailedReport.value?.docDetails == null) return;

    int index = con.detailedReport.value!.docDetails!.indexWhere(
        (item) => item.barcode?.toLowerCase() == barcode.toLowerCase());

    if (index != -1) {
      _scrollController.animateTo(
        index * 160.0, // Adjust based on your item height
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      CustomWidget.customSnackBar(
        title: "Not Found",
        message: "No matching barcode found!",
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Scan or Enter Barcode...",
                    border: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _scrollToBarcode,
                )
              : Text("Report"),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Get.back(),
          ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
          ],
        ),
        backgroundColor: CustomColors.scaffoldColor,
        body: Obx(
          () => con.isLoadingDetailed.value
              ? Center(child: CircularProgressIndicator.adaptive())
              : con.detailedReport.value == null
                  ? Center(child: Text("No Details Found, Please try again."))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          _buildReportHeader(context),
                          _buildItemDetailsHeader(context),
                          Expanded(child: _buildItemList()),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildReportHeader(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            con.detailedReport.value?.docType == 'R'
                ? 'Return Report'
                : con.detailedReport.value?.docType == 'I'
                    ? "Invoice Report"
                    : 'Transfer Report',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            itemWidget(context, "Company", con.detailedReport.value?.company),
            itemWidget(context, "Doc Num", con.detailedReport.value?.docNum),
            itemWidget(context, "Doc Date", con.detailedReport.value?.docDate),
            itemWidget(context, "Cust ID", con.detailedReport.value?.custID),
            itemWidget(
                context, "Cust Name", con.detailedReport.value?.custName),
            itemWidget(
                context, "Scan Time", con.detailedReport.value?.scanTime),
            itemWidget(context, "Scanned By", con.detailedReport.value?.userId),
            itemWidget(
                context,
                con.detailedReport.value?.docType == 'R'
                    ? 'Returned By'
                    : 'Picked By',
                con.detailedReport.value?.pickedBy),
            itemWidget(
              context,
              "Status",
              con.detailedReport.value?.stat == 'D'
                  ? 'Downloaded'
                  : 'Completed',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemDetailsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        "Item Details",
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildItemList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(top: 10),
      shrinkWrap: true,
      itemCount: con.detailedReport.value?.docDetails?.length ?? 0,
      itemBuilder: (context, index) {
        var item = con.detailedReport.value!.docDetails?[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: index.isEven
                    ? Colors.amber.shade200
                    : Colors.blueAccent.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  itemWidget(context, "Sl No", "${index + 1}"),
                  itemWidget(context, "Part Num", item?.partNum),
                  itemWidget(context, "Part Name", item?.partName),
                  itemWidget(context, "Brand", item?.brand),
                  itemWidget(context, "Barcode", item?.barcode),
                  itemWidget(context, "Quantity", "${item?.checkQty}"),
                  if (item!.reasonCode!.isNotEmpty)
                    itemWidget(context, "Reason Code", item.reasonCode),
                  if (item.reasonName!.isNotEmpty)
                    itemWidget(context, "Reason Name", item.reasonName),
                  if (item.docType == 'R' &&
                      (item.reasonCode == 'NRE' || item.reasonCode == 'EXP'))
                    itemWidget(context, "Expiry Date", item.expiryDate),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget itemWidget(BuildContext context, String title, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(' :  '),
            ],
          ),
        ),
        Expanded(
          child: Text(
            value ?? "-",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}
