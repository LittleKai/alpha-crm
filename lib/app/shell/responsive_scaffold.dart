import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/utils/responsive_breakpoints.dart';
import '../../shared/widgets/update_dialog.dart';
import '../../features/settings/providers/update_provider.dart';
import 'app_sidebar.dart';
import 'app_topbar.dart';
import 'app_shell_providers.dart';

class ResponsiveScaffold extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const ResponsiveScaffold({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _updateCheckTriggered = false;

  @override
  void initState() {
    super.initState();
    // Tự động kiểm tra cập nhật khi app khởi động (chỉ Windows/Android)
    if (!kIsWeb && (Platform.isWindows || Platform.isAndroid)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerStartupUpdateCheck();
      });
    }
  }

  void _triggerStartupUpdateCheck() {
    if (_updateCheckTriggered) return;
    _updateCheckTriggered = true;
    ref.read(updateProvider.notifier).checkForUpdates();
  }

  void _showUpdateDialog(BuildContext context) {
    showUpdateDialog(context: context, ref: ref);
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe kết quả kiểm tra cập nhật và hiện dialog khi có bản mới
    if (!kIsWeb && (Platform.isWindows || Platform.isAndroid)) {
      ref.listen<UpdateState>(updateProvider, (previous, next) {
        if (previous?.status != UpdateStatus.available &&
            next.status == UpdateStatus.available) {
          _showUpdateDialog(context);
        }
      });
    }
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final isTablet = ResponsiveBreakpoints.isTablet(context);

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          width: 250,
          child: AppSidebar(currentRoute: widget.currentRoute),
        ),
        body: SafeArea(
          child: Column(
            children: [
              AppTopbar(
                currentRoute: widget.currentRoute,
                onMenuPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool isCollapsed = isTablet || ref.watch(sidebarCollapsedProvider);
    final double sidebarWidth = isCollapsed ? 72 : 250;

    // Tablet or Desktop
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Spacer to occupy the space of the sidebar
              SizedBox(width: sidebarWidth),
              // Content Area
              Expanded(
                child: Column(
                  children: [
                    AppTopbar(currentRoute: widget.currentRoute),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Sidebar rendered on top of the content area so its collapse button isn't overlapped
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: AppSidebar(
              currentRoute: widget.currentRoute,
              forceCollapsed: isTablet ? true : null,
            ),
          ),
        ],
      ),
    );
  }
}
