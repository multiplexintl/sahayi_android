import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Text input with its label ABOVE the field (stays readable while typing).
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final TextAlign textAlign;
  final TextStyle? style;
  final InputDecoration? additionalDecoration;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.validator,
    this.textAlign = TextAlign.start,
    this.style,
    this.additionalDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final baseDecoration = InputDecoration(
      hintText: hint,
      prefixIcon:
          prefixIcon == null ? null : Icon(prefixIcon, size: Sizes.iconSm + 2),
      suffixIcon: suffix,
      fillColor: enabled ? c.surface : c.surfaceAlt,
    );

    final theme = Theme.of(context).textTheme;
    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      onTap: onTap,
      validator: validator,
      textAlign: textAlign,
      style: style ?? theme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      decoration: additionalDecoration != null
          ? baseDecoration.copyWith(
              contentPadding: additionalDecoration?.contentPadding,
              suffix: additionalDecoration?.suffix,
            )
          : baseDecoration,
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Space.xs + 2),
          child: Text(label!, style: theme.labelMedium),
        ),
        field,
      ],
    );
  }
}
