import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'responsive_scaffold.dart';
import '../../features/zalo_integration/providers/zalo_integration_provider.dart';
import '../../features/zalo_integration/presentation/screens/backend_waiting_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final GoRouterState state;

  const AppShell({super.key, required this.child, required this.state});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).startPollingBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    final integrationState = ref.watch(zaloIntegrationProvider);
    
    // Determine current path
    final location = widget.state.uri.path;

    // Nếu backend chưa hoạt động, chuyển hướng sang màn hình chờ kính mờ
    if (!integrationState.isBackendActive) {
      return const BackendWaitingScreen();
    }

    return ResponsiveScaffold(currentRoute: location, child: widget.child);
  }
}
