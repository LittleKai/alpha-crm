import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../../features/settings/providers/update_provider.dart';
import '../../mock/mock_accounts.dart';
import '../../shared/utils/responsive_breakpoints.dart';
import '../../shared/widgets/update_dialog.dart';
import '../theme/app_theme_tokens.dart';
import 'app_shell_providers.dart';
import 'app_sidebar.dart';
import 'app_topbar.dart';

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
    if (Platform.isWindows || Platform.isAndroid) {
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
    final tokens = AppThemeTokens.of(context);

    // Sync sidebar persisted settings once loaded from zalo_settings.json
    ref.listen<SystemSettings>(
      settingsProvider.select((s) => s.settings),
      (previous, next) {
        if (previous?.sidebarCollapsed != next.sidebarCollapsed) {
          ref.read(sidebarCollapsedProvider.notifier).state =
              next.sidebarCollapsed;
        }
        if (previous?.sidebarWidth != next.sidebarWidth) {
          ref.read(sidebarWidthProvider.notifier).state = next.sidebarWidth;
        }
      },
    );

    if (Platform.isWindows || Platform.isAndroid) {
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
        backgroundColor: tokens.surfacePrimary,
        drawer: Drawer(
          width: 260,
          child: AppSidebar(currentRoute: widget.currentRoute),
        ),
        body: SafeArea(
          child: Column(
            children: [
              AppTopbar(
                currentRoute: widget.currentRoute,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              Expanded(
                child: Container(
                  color: tokens.surfacePrimary,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Twenty PageCardLayout: calm neutral frame cradling an elevated rounded workspace card
    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: Row(
        children: [
          AppSidebar(
            currentRoute: widget.currentRoute,
            forceCollapsed: isTablet ? true : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.surfacePrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderMedium, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    AppTopbar(currentRoute: widget.currentRoute),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
