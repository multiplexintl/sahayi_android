import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../service/app_logger.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Yes/no confirmation as a bottom sheet (easy to reach on a scanner).
/// Returns true only when the user confirms. [danger] makes the confirm
/// button red and is for destructive actions only.
Future<bool> showConfirmSheet({
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
  IconData? icon,
  BuildContext? context,
}) async {
  AppLogger.info('Dialog', '$title: $message');
  context ??= Get.context!;
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final c = context.c;
      final t = Theme.of(context).textTheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (icon != null || danger) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: danger ? c.dangerSoft : c.primarySoft,
                  borderRadius: Radii.all(Radii.lg),
                ),
                child: Icon(icon ?? Icons.warning_amber_rounded,
                    color: danger ? c.dangerText : c.onPrimarySoft),
              ),
            ),
            const SizedBox(height: Space.md),
          ],
          Text(title, style: t.titleLarge),
          const SizedBox(height: Space.sm),
          Text(message, style: t.bodyLarge?.copyWith(color: c.muted)),
          const SizedBox(height: Space.xl),
          Row(children: [
            Expanded(
              child: AppButton.secondary(
                label: cancelLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: danger
                  ? AppButton.danger(label: confirmLabel, onPressed: () => Navigator.of(context).pop(true))
                  : AppButton(label: confirmLabel, onPressed: () => Navigator.of(context).pop(true)),
            ),
          ]),
        ]),
      );
    },
  );
  return result == true;
}

enum ToastKind { success, info, warning, error }

/// Short message at the top. Logged like the old snackbars (errors as WARN).
class AppToast {
  AppToast._();

  static void show(String title, String message, {ToastKind kind = ToastKind.info, int seconds = 3}) {
    if (kind == ToastKind.error || kind == ToastKind.warning) {
      AppLogger.warn('Popup', '$title: $message');
    } else {
      AppLogger.info('Popup', '$title: $message');
    }
    final context = Get.context;
    final c = context == null ? AppColors.light : context.c;  // safe fallback
    final (Color bg, Color fg, IconData icon) = switch (kind) {
      ToastKind.success => (c.successSoft, c.successText, Icons.check_circle_rounded),
      ToastKind.info => (c.primarySoft, c.onPrimarySoft, Icons.info_rounded),
      ToastKind.warning => (c.warningSoft, c.warningText, Icons.warning_amber_rounded),
      ToastKind.error => (c.dangerSoft, c.dangerText, Icons.error_rounded),
    };
    Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      backgroundColor: bg,
      colorText: fg,
      icon: Icon(icon, color: fg),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(Space.md),
      borderRadius: Radii.lg,
      borderColor: fg.withValues(alpha: 0.25),
      borderWidth: 1,
      duration: Duration(seconds: seconds),
      animationDuration: const Duration(milliseconds: 300),
      isDismissible: true,
    );
  }

  static void success(String title, String message) => show(title, message, kind: ToastKind.success);
  static void error(String title, String message) => show(title, message, kind: ToastKind.error, seconds: 4);
  static void warning(String title, String message) => show(title, message, kind: ToastKind.warning);
  static void info(String title, String message) => show(title, message);
}
