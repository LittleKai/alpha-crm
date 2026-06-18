import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/crm_auth_provider.dart';
import 'app_dialog.dart';
import 'app_button.dart';

/// Bọc toàn app: khi KHÔI PHỤC phiên lúc mở app phát hiện tài khoản đã đạt giới
/// hạn thiết bị (máy khác đang active), hiện dialog hỏi có đăng xuất máy cũ để
/// dùng máy này không — thay vì văng im lặng về login.
///
/// Render inline (không qua showDialog/Navigator) như [RevocationGate] để hiện
/// được ở mọi trạng thái router.
class DeviceConflictGate extends ConsumerWidget {
  final Widget child;

  const DeviceConflictGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflict = ref.watch(
      crmAuthProvider.select((s) => s.pendingDeviceConflict),
    );

    return Stack(
      children: [
        child,
        if (conflict != null)
          Positioned.fill(
            child: Stack(
              children: [
                Container(color: Colors.black.withValues(alpha: 0.55)),
                Center(
                  child: AppDialog(
                    title: 'Đăng xuất máy tính cũ?',
                    icon: Icons.desktop_windows_rounded,
                    showCloseButton: false,
                    width: 480,
                    subtitle:
                        'Tài khoản đang hoạt động trên '
                        '${conflict.displayName ?? 'một máy tính khác'}. '
                        'Mỗi tài khoản chỉ dùng được trên một máy. Bạn có muốn '
                        'đăng xuất máy cũ để dùng trên MÁY NÀY không?',
                    actions: [
                      AppDialogAction(
                        text: 'Hủy',
                        variant: AppButtonVariant.outline,
                        onPressed: () =>
                            ref.read(crmAuthProvider.notifier).cancelPendingLogin(),
                      ),
                      AppDialogAction(
                        text: 'Đăng xuất máy cũ',
                        icon: Icons.swap_horiz_rounded,
                        variant: AppButtonVariant.destructive,
                        onPressed: () => ref
                            .read(crmAuthProvider.notifier)
                            .confirmDeviceReplacement(),
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
