import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/connectivity_controller.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/routes.dart';

import '../theme/theme_service.dart';
import '../ui/ui.dart';
import '../widgets/admin_tap_detector.dart';

/// Home (Version 2): greeting, date and connection, four action cards.
/// Navigation and logout behave exactly as in Version 1.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String greeting(DateTime now) => now.hour < 12
      ? 'Good morning'
      : now.hour < 17
          ? 'Good afternoon'
          : 'Good evening';

  @override
  Widget build(BuildContext context) {
    // Same controllers, created in the same order as Version 1.
    final con = Get.put(HomeController());
    Get.put(ReturnController());
    final invTrfCon = Get.put(InvoiceOrTransferController());

    return Builder(builder: (context) {
      final c = context.c;
      final t = Theme.of(context).textTheme;
      final now = DateTime.now();
      final name = con.user.value.empName ?? '';

      Future<void> logout() async {
        final ok = await showConfirmSheet(
          context: context,
          title: 'Log out?',
          message: 'You will need your Employee ID and password to log in again.',
          confirmLabel: 'Log out',
          icon: Icons.logout_rounded,
        );
        if (ok) con.logOut();
      }

      return Scaffold(
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.sm, Space.sm),
              child: Row(children: [
                InitialsAvatar(name),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(greeting(now), style: t.bodySmall),
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleLarge),
                  ]),
                ),
                // Light / dark switch (remembered on this scanner)
                if (Get.isRegistered<ThemeService>())
                  AppIconButton(
                    icon: Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    tooltip: Theme.of(context).brightness == Brightness.dark
                        ? 'Light mode'
                        : 'Dark mode',
                    color: c.muted,
                    background: c.surface,
                    onPressed: () => ThemeService.to.toggle(context),
                  ),
                const SizedBox(width: Space.xs),
                AppIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: 'Log out',
                  color: c.muted,
                  background: c.surface,
                  onPressed: logout,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.md),
              child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('EEE, d MMM yyyy').format(now),
                ),
                if (Get.isRegistered<ConnectivityController>())
                  Obx(() {
                    final online = Get.find<ConnectivityController>().isInternetConnected.value;
                    return _InfoChip(
                      dotColor: online ? c.success : c.danger,
                      label: online ? 'Online' : 'Offline',
                    );
                  }),
              ]),
            ),
            const SectionLabel('Start work', padding: EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.sm)),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                // 2 x 2 cards that use the available height without scrolling,
                // but never shorter than a comfortable tap target.
                const gap = Space.md;
                final tileH = ((box.maxHeight - gap - Space.lg) / 2).clamp(124.0, 168.0);
                final tileW = (box.maxWidth - 2 * Space.lg - gap) / 2;
                return GridView.count(
                  padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
                  crossAxisCount: 2,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: tileW / tileH,
                  children: [
                    ActionTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Invoice',
                      subtitle: 'Check an outgoing invoice',
                      iconColor: c.invoice,
                      iconBackground: c.invoiceSoft,
                      onTap: () async {
                        invTrfCon.isInvoice.value = true;
                        await invTrfCon.getLastInvoices(docType: 'I');
                        Get.toNamed(RouteLinks.invoiceTransfer);
                      },
                    ),
                    ActionTile(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Transfer',
                      subtitle: 'Check a store transfer',
                      iconColor: c.transfer,
                      iconBackground: c.transferSoft,
                      onTap: () async {
                        invTrfCon.getLastInvoices(docType: 'T');
                        invTrfCon.isInvoice.value = false;
                        Get.toNamed(RouteLinks.invoiceTransfer);
                      },
                    ),
                    ActionTile(
                      icon: Icons.assignment_return_rounded,
                      title: 'Return',
                      subtitle: 'Receive a customer return',
                      iconColor: c.returnC,
                      iconBackground: c.returnSoft,
                      onTap: () => Get.toNamed(RouteLinks.customerSelect),
                    ),
                    ActionTile(
                      icon: Icons.bar_chart_rounded,
                      title: 'Report',
                      subtitle: 'Your past activity',
                      iconColor: c.accentText,
                      iconBackground: c.accentSoft,
                      onTap: () => Get.toNamed(RouteLinks.invoiceReport),
                    ),
                  ],
                );
              }),
            ),
            // 7 taps on the version opens the hidden admin login
            Center(
              child: AdminTapDetector(
                child: Obx(() => Text(
                      'Sahayi · v${con.version.value ?? ''} (${con.buildNumber.value ?? ''})',
                      style: t.labelSmall?.copyWith(color: c.faint),
                    )),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _InfoChip extends StatelessWidget {
  final IconData? icon;
  final Color? dotColor;
  final String label;
  const _InfoChip({this.icon, this.dotColor, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.all(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) Icon(icon, size: 14, color: c.muted),
        if (dotColor != null)
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}
