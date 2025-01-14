// Bottom Sheet for Month and Year Selection
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/widgets/button.dart';

void showYearMonthPicker({
  required void Function(DateTime) onDateTimeChanged,
  required bool dateNeeded,
  required void Function()? onTapCancel,
  required void Function()? onTapSubmit,
  DateTime? initialDateTime,
}) {
  DateTime today = DateTime.now();
  Get.bottomSheet(
    Container(
      color: Colors.white,
      height: 400,
      width: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: CupertinoDatePicker(
              onDateTimeChanged: onDateTimeChanged,
              mode: dateNeeded
                  ? CupertinoDatePickerMode.date
                  : CupertinoDatePickerMode.monthYear,
              dateOrder: DatePickerDateOrder.dmy,
              initialDateTime: initialDateTime ?? today,
              minimumYear: DateTime.now().year - 32,
              maximumYear: DateTime.now().year,
              maximumDate: today,
              minimumDate: DateTime(today.year - 32, today.month, today.day),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 15, right: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  flex: 1,
                  child: ButtonWidget(
                    height: 48,
                    title: "Clear",
                    onPressed: onTapCancel,
                  ),
                ),
                SizedBox(width: 10),
                Flexible(
                  flex: 1,
                  child: ButtonWidget(
                    height: 48,
                    onPressed: onTapSubmit,
                    title: "Submit",
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    ),
  );
}
