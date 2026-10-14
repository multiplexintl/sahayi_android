import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../service/admin_service.dart';
import 'all_devices_tab.dart';
import 'device_logs_tab.dart';

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
      const Tab(height: 30, text: 'This device'),
      if (session.canSeeAllDevices) const Tab(height: 30, text: 'All devices'),
    ];
    final who = session.mode == AdminMode.online
        ? (session.userName ?? session.userId ?? '')
        : 'Offline PIN · this device only';

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        // Compact header for small scanner screens
        appBar: AppBar(
          toolbarHeight: 40,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Logs dashboard', style: TextStyle(fontSize: 15)),
              Text(who, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          bottom: tabs.length < 2
              ? null // offline PIN: one tab, no tab bar needed
              : TabBar(
                  tabs: tabs,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  labelPadding: EdgeInsets.zero,
                  indicatorSize: TabBarIndicatorSize.tab,
                ),
          actions: [
            IconButton(
              tooltip: 'Close',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.logout, size: 20),
              onPressed: () => Get.back(),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            const DeviceLogsTab(),
            if (session.canSeeAllDevices) const AllDevicesTab(),
          ],
        ),
      ),
    );
  }
}
