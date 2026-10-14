import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../service/admin_service.dart';

/// Hidden logs dashboard. Online admin: "This device" + "All devices".
/// Offline PIN: "This device" only. Leaving the screen ends the admin session.
class LogsDashboardScreen extends StatefulWidget {
  const LogsDashboardScreen({super.key});

  @override
  State<LogsDashboardScreen> createState() => _LogsDashboardScreenState();
}

class _LogsDashboardScreenState extends State<LogsDashboardScreen> {
  final AdminSession? _session = AdminService.current;

  @override
  void initState() {
    super.initState();
    if (_session == null) {
      // Opened without logging in (should not happen): go straight back.
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.back());
    }
  }

  @override
  void dispose() {
    AdminService.logout();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const Scaffold();

    final tabs = <Tab>[
      const Tab(icon: Icon(Icons.phone_android), text: 'This device'),
      if (session.canSeeAllDevices)
        const Tab(icon: Icon(Icons.devices), text: 'All devices'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Logs dashboard'),
          bottom: TabBar(tabs: tabs),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  session.mode == AdminMode.online
                      ? (session.userName ?? session.userId ?? '')
                      : 'Offline PIN',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.logout),
              onPressed: () => Get.back(),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            const _ComingSoon(text: "This device's logs: next step"),
            if (session.canSeeAllDevices)
              const _ComingSoon(text: 'All devices: coming after that'),
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String text;
  const _ComingSoon({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      );
}
