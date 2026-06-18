import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'responsive_scaffold.dart';
import '../../features/zalo_integration/providers/zalo_integration_provider.dart';
import '../../features/auth/providers/crm_auth_provider.dart';
import '../../features/auth/models/crm_login_result.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_button.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final GoRouterState state;

  const AppShell({super.key, required this.child, required this.state});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Chặn mở nhiều dialog thu hồi cùng lúc.
  bool _revokeDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).startPollingBackend();
    });
  }

  /// Khi phiên trên máy này bị thu hồi: thay vì văng thẳng về login, hỏi user
  /// có muốn dùng máy này (thu hồi máy kia) hay đăng xuất.
  Future<void> _showRevokeDialog(String reason) async {
    if (_revokeDialogOpen) return;
    _revokeDialogOpen = true;

    final useThisDevice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppDialog(
        title: 'Phiên đăng nhập bị thay thế',
        icon: Icons.devices_other_rounded,
        subtitle:
            'Tài khoản của bạn vừa được sử dụng trên một thiết bị khác '
            '($reason). Bạn có muốn tiếp tục dùng trên MÁY NÀY và thu hồi '
            'thiết bị kia không?',
        actions: [
          AppDialogAction(
            text: 'Đăng xuất',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppDialogAction(
            text: 'Dùng máy này',
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
        child: const SizedBox.shrink(),
      ),
    );

    if (!mounted) {
      _revokeDialogOpen = false;
      return;
    }

    if (useThisDevice == true) {
      final result =
          await ref.read(crmAuthProvider.notifier).reclaimRevokedDevice();
      if (mounted && result is! CrmLoginSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể giành lại phiên trên máy này. Vui lòng đăng nhập lại.',
            ),
          ),
        );
      }
    } else {
      await ref.read(crmAuthProvider.notifier).dismissRevokedDevice();
    }

    _revokeDialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe sự kiện thu hồi phiên → hiện dialog xác nhận thay vì kick.
    ref.listen<String?>(
      crmAuthProvider.select((s) => s.deviceRevokedReason),
      (previous, next) {
        if (next != null && next.isNotEmpty) {
          _showRevokeDialog(next);
        }
      },
    );

    final location = widget.state.uri.path;
    return ResponsiveScaffold(currentRoute: location, child: widget.child);
  }
}
