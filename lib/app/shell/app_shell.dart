import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'responsive_scaffold.dart';
import '../../features/zalo_integration/providers/zalo_integration_provider.dart';

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
      debugPrint(
        '[ZALO-STARTUP-DEBUG] AppShell mounted @ ${DateTime.now().toIso8601String()} -> gọi startPollingBackend()',
      );
      ref.read(zaloIntegrationProvider.notifier).startPollingBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine current path
    final location = widget.state.uri.path;

    return ResponsiveScaffold(currentRoute: location, child: widget.child);
  }
}
