import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_clock/one_clock.dart';

import '../controller/home_controller.dart';

class BottomBarWidget extends StatelessWidget {
  const BottomBarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var con = Get.find<HomeController>();
    return Container(
      height: 40,
      width: double.infinity,
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Obx(() => Text(
                "${con.date}",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.merge(const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
              )),
          DigitalClock(
            showSeconds: true,
            isLive: true,
            digitalClockColor: Colors.white,
            datetime: DateTime.now(),
            textScaleFactor: 1.15,
          ),
        ],
      ),
    );
  }
}
