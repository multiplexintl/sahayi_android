import 'package:flutter/material.dart';

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
    return SizedBox(
      width: width ?? 350,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          visualDensity: VisualDensity(vertical: -4, horizontal: -4),
          fixedSize: Size(350, height ?? 48),
          alignment: Alignment.center,
          backgroundColor: backgroundColor ?? Colors.blueGrey.shade400,
          foregroundColor: Colors.white,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: child ?? Text(title),
      ),
    );
  }
}
