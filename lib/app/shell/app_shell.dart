import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_shell_providers.dart';
import 'command_palette_dialog.dart';
import 'responsive_scaffold.dart';
import '../../features/security/providers/app_lock_provider.dart';
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
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint(
        '[ZALO-STARTUP-DEBUG] AppShell mounted @ ${DateTime.now().toIso8601String()} -> gọi startPollingBackend()',
      );
      ref.read(zaloIntegrationProvider.notifier).startPollingBackend();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (ref.read(appLockProvider).isLocked) return false;
    final isModifierPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!isModifierPressed) return false;
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      showCommandPaletteDialog(context);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.backslash) {
      final current = ref.read(sidebarCollapsedProvider);
      persistSidebarCollapsed(ref, !current);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Determine current path
    final location = widget.state.uri.path;

    return ResponsiveScaffold(currentRoute: location, child: widget.child);
  }
}
