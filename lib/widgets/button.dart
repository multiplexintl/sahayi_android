import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// Version 1 button still used by two ReturnController dialogs. The look now
/// follows the Version 2 theme; red still means "danger", any other colour
/// becomes the primary button. [child] and [height] are ignored (unused).
class ButtonWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final String title;
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final Widget? child;
  final Color? backgroundColor;

  const ButtonWidget({
    super.key,
    this.width,
    required this.title,
    this.onPressed,
    this.height,
    this.child,
    this.backgroundColor,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final onTap = onPressed;
    return SizedBox(
      width: width ?? 350,
      child: backgroundColor == Colors.red
          ? AppButton.danger(label: title, onPressed: onTap, onLongPress: onLongPress)
          : AppButton(label: title, onPressed: onTap, onLongPress: onLongPress),
    );
  }
}
