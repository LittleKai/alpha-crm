import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/crm_auth_provider.dart';
import 'app_dialog.dart';
import 'app_button.dart';

/// Bọc toàn app: khi phiên trên máy này bị thu hồi (`deviceRevokedReason` khác
/// null), hiện dialog xác nhận — dùng máy này (thu hồi máy kia) hay đăng xuất.
///
/// Render dialog trực tiếp trong cây widget (không qua `showDialog`/Navigator)
/// và mount ở tầng cao nhất nên hiện được ở MỌI trạng thái router — kể cả khi
/// màn hình đang chuyển — tránh trường hợp dialog "không kịp hiện".
class RevocationGate extends ConsumerWidget {
  final Widget child;

  const RevocationGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(
      crmAuthProvider.select((s) => s.deviceRevokedReason),
    );

    return Stack(
      children: [
        child,
        if (reason != null && reason.isNotEmpty)
          Positioned.fill(
            child: Stack(
              children: [
                Container(color: Colors.black.withValues(alpha: 0.55)),
                Center(
                  child: AppDialog(
                    title: 'Phiên đăng nhập bị thay thế',
                    icon: Icons.devices_other_rounded,
                    showCloseButton: false,
                    width: 480,
                    subtitle:
                        'Tài khoản của bạn vừa được sử dụng trên một thiết bị '
                        'khác. Bạn có muốn tiếp tục dùng trên MÁY NÀY và thu hồi '
                        'thiết bị kia không?',
                    actions: [
                      AppDialogAction(
                        text: 'Đăng xuất',
                        variant: AppButtonVariant.outline,
                        onPressed: () => ref
                            .read(crmAuthProvider.notifier)
                            .dismissRevokedDevice(),
                      ),
                      AppDialogAction(
                        text: 'Dùng máy này',
                        icon: Icons.check_circle_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: () => ref
                            .read(crmAuthProvider.notifier)
                            .reclaimRevokedDevice(),
                      ),
                    ],
                    child: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
