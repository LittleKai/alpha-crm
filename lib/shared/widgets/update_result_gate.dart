import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/update_provider.dart';
import '../utils/app_update_service.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// Bọc toàn app: sau khi khởi động lại từ một lần cập nhật, hiển thị kết quả.
/// - Thành công: banner nhỏ ở trên, tự ẩn sau ít giây.
/// - Thất bại (update không áp dụng được, vd do đổi tên exe): dialog yêu cầu
///   tải lại bản mới và cài thủ công.
///
/// Render inline (không qua showDialog/Navigator) như các gate khác để hiện
/// được ở mọi trạng thái router. Dữ liệu lấy từ [postUpdateResultProvider]
/// (main.dart nạp lúc startup).
class UpdateResultGate extends ConsumerStatefulWidget {
  final Widget child;

  const UpdateResultGate({super.key, required this.child});

  @override
  ConsumerState<UpdateResultGate> createState() => _UpdateResultGateState();
}

class _UpdateResultGateState extends ConsumerState<UpdateResultGate> {
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    _successTimer?.cancel();
    _successTimer = null;
    ref.read(postUpdateResultProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    // Khi có kết quả thành công → hẹn giờ tự ẩn banner.
    ref.listen<PostUpdateResult?>(postUpdateResultProvider, (prev, next) {
      _successTimer?.cancel();
      _successTimer = null;
      if (next?.outcome == PostUpdateOutcome.success) {
        _successTimer = Timer(const Duration(seconds: 6), _dismiss);
      }
    });

    final result = ref.watch(postUpdateResultProvider);

    return Stack(
      children: [
        widget.child,
        if (result?.outcome == PostUpdateOutcome.failed)
          Positioned.fill(child: _buildFailedDialog(result!)),
        if (result?.outcome == PostUpdateOutcome.success)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildSuccessBanner(result!)),
          ),
      ],
    );
  }

  Widget _buildFailedDialog(PostUpdateResult r) {
    return Stack(
      children: [
        Container(color: Colors.black.withValues(alpha: 0.55)),
        Center(
          child: AppDialog(
            title: 'Cập nhật chưa hoàn tất',
            icon: Icons.system_update_alt_rounded,
            showCloseButton: false,
            width: 480,
            subtitle:
                'Không thể cập nhật tự động lên phiên bản ${r.targetVersion} '
                '(đang ở ${r.currentVersion}). Vui lòng tải lại bản mới nhất và '
                'cài đặt thủ công.',
            actions: [
              AppDialogAction(
                text: 'Để sau',
                variant: AppButtonVariant.outline,
                onPressed: _dismiss,
              ),
              AppDialogAction(
                text: 'Tải lại bản mới',
                icon: Icons.download_rounded,
                onPressed: () {
                  AppUpdateService.openReleasePage();
                  _dismiss();
                },
              ),
            ],
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessBanner(PostUpdateResult r) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Đã cập nhật thành công lên phiên bản ${r.currentVersion}.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Đóng',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: _dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
