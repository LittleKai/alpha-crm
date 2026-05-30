import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/utils/responsive_breakpoints.dart';
import '../theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.appBackground,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tablet or Desktop
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AppSidebar(
            currentRoute: widget.currentRoute,
            forceCollapsed: isTablet ? true : null,
          ),
          // Content Area
          Expanded(
            child: Column(
              children: [
                AppTopbar(currentRoute: widget.currentRoute),
                Expanded(
                  child: Container(
                    color: AppColors.appBackground,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
