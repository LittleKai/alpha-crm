import 'package:flutter/material.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_tabs.dart';
import '../widgets/reported_errors_tab.dart';
import '../widgets/live_logs_tab.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem lỗi hệ thống'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTabs(
              isSegmented: true,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) => setState(() => _selectedTabIndex = index),
              tabs: const [
                AppTabItem(label: 'Lỗi đã ghi nhận', icon: Icons.cloud_outlined),
                AppTabItem(label: 'Nhật ký trực tiếp', icon: Icons.terminal_outlined),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: const [
                  ReportedErrorsTab(),
                  LiveLogsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
