import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../service/app_logger.dart';
import '../ui/ui.dart';

/// Popups used by the controllers. Signatures and logging are unchanged from
/// Version 1; only the look follows the Version 2 theme (light and dark).
class CustomWidget {
  /// The colour a controller passes still decides the meaning:
  /// red = error, orange = warning, anything else = success.
  static ToastKind _kindOf(Color? backgroundColor) {
    if (backgroundColor == Colors.red) return ToastKind.error;
    if (backgroundColor == Colors.orange) return ToastKind.warning;
    return ToastKind.success;
  }

  // custom snack bar
  static Future<SnackbarController> customSnackBar(
      {required String title,
      required String message,
      Color? textColor,
      Color? backgroundColor,
      int? duration}) async {
    // Record exactly what the user was shown. Red = problem, otherwise info.
    if (backgroundColor == Colors.red) {
      AppLogger.warn('Popup', '$title: $message');
    } else {
      AppLogger.info('Popup', '$title: $message');
    }
    final context = Get.context;
    final c = context == null ? AppColors.light : context.c;
    final (Color bg, Color fg, IconData icon) = switch (_kindOf(backgroundColor)) {
      ToastKind.error => (c.dangerSoft, c.dangerText, Icons.error_rounded),
      ToastKind.warning => (c.warningSoft, c.warningText, Icons.warning_amber_rounded),
      ToastKind.info => (c.primarySoft, c.onPrimarySoft, Icons.info_rounded),
      ToastKind.success => (c.successSoft, c.successText, Icons.check_circle_rounded),
    };
    Get.closeAllSnackbars();
    return Get.snackbar(
      title,
      message,
      backgroundColor: bg,
      colorText: fg,
      icon: Icon(icon, color: fg),
      isDismissible: true,
      snackPosition: SnackPosition.TOP,
      animationDuration: const Duration(milliseconds: 300),
      duration: Duration(seconds: duration ?? 3),
      margin: const EdgeInsets.all(Space.md),
      borderRadius: Radii.lg,
      snackStyle: SnackStyle.FLOATING,
      borderColor: fg.withValues(alpha: 0.25),
      borderWidth: 1,
    );
  }

  static Future<dynamic> customDialogue({
    String? okText,
    required String title,
    required String subTitle,
    Color? buttonColor,
    required void Function()? onPressed,
    void Function()? onPressedBack,
  }) {
    AppLogger.info('Dialog', '$title: $subTitle');
    return Get.dialog(Builder(builder: (context) {
      final danger = buttonColor == Colors.red;
      return AlertDialog(
        icon: Icon(
          danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
          size: 36,
          color: danger ? context.c.dangerText : context.c.primary,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: SingleChildScrollView(child: Text(subTitle, textAlign: TextAlign.center)),
        actionsPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        actions: [
          Row(children: [
            if (onPressedBack != null) ...[
              Expanded(child: AppButton.secondary(label: 'Back', onPressed: onPressedBack)),
              const SizedBox(width: Space.sm),
            ],
            Expanded(
              child: danger
                  ? AppButton.danger(label: okText ?? 'Confirm', onPressed: onPressed)
                  : AppButton(label: okText ?? 'Confirm', onPressed: onPressed),
            ),
          ]),
        ],
      );
    }));
  }
}
