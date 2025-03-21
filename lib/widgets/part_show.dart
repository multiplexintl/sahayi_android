import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PartShowWidget extends StatelessWidget {
  final String slNo;
  final String barcode;
  final String partName;
  final String qty;
  final String rsn;
  final Function()? onTap;
  final bool isHead;
  final bool isView;
  const PartShowWidget(
      {super.key,
      required this.slNo,
      required this.barcode,
      required this.qty,
      required this.rsn,
      this.onTap,
      required this.isHead,
      this.isView = false,
      required this.partName});

  @override
  Widget build(BuildContext context) {
    var fontSize = isHead ? 16.0 : 13.0;
    return Container(
      color: isHead ? Colors.blueGrey.shade300 : Colors.transparent,
      height: null,
      child: Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: context.width * 0.1 - 10,
              alignment: Alignment.center,
              padding: EdgeInsets.only(left: isHead ? 3 : 0),
              child: Text(
                slNo,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: fontSize,
                      height: 0.8,
                    ),
              ),
            ),
            Container(
              width: context.width * 0.6 - 20,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    barcode,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: fontSize,
                          height: isHead ? 0.9 : 1.1,
                        ),
                  ),
                  Text(
                    partName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: fontSize,
                          height: isHead ? 0.9 : 1.1,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              width: context.width * 0.14 - 20,
              alignment: Alignment.centerRight,
              child: Text(
                qty,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: fontSize),
              ),
            ),
            Container(
              width: context.width * 0.2 - 20,
              alignment: Alignment.center,
              child: Text(
                rsn,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: fontSize),
              ),
            ),
            Container(
              width: context.width * 0.15 - 20,
              alignment: Alignment.center,
              child: isHead
                  ? Text(
                      isView ? "view" : "del",
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontSize: fontSize),
                    )
                  : GestureDetector(
                      onTap: onTap,
                      child: Icon(
                        isView ? Icons.visibility : Icons.delete,
                        color: isView ? Colors.black : Colors.red,
                        size: 30,
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }
}
