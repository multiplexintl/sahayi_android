import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Compact app bar: back, optional badge + title, optional subtitle, actions.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? badge;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.showBack = true,
    this.onBack,
    this.actions = const [],
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? Sizes.appBar : 60);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: EdgeInsets.only(left: showBack ? Space.xs : Space.lg, right: Space.xs),
            child: Row(children: [
              if (showBack)
                AppIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: onBack ?? () => Get.back(),
                ),
              if (showBack) const SizedBox(width: Space.xs),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (badge != null) ...[badge!, const SizedBox(width: Space.sm)],
                      Flexible(
                        child: Text(title,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleLarge?.copyWith(
                                fontSize: 17, fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                    ]),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                  ],
                ),
              ),
              ...actions,
            ]),
          ),
        ),
      ),
    );
  }
}
