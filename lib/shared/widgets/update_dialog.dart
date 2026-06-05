import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../features/settings/providers/update_provider.dart';
import 'app_button.dart';

/// Hiển thị dialog thông báo cập nhật mới.
/// Hỗ trợ tải xuống và cài đặt trực tiếp từ dialog.
void showUpdateDialog({required BuildContext context, required WidgetRef ref}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UpdateDialog(),
  );
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF111827) : AppColors.surface;
    final primarySoftColor = isDark
        ? const Color(0xFF1E293B)
        : AppColors.primarySoft;
    final surfaceMutedColor = isDark
        ? const Color(0xFF162033)
        : AppColors.surfaceMuted;
    final borderSoftColor = isDark
        ? const Color(0xFF253247)
        : AppColors.borderSoft;
    final borderColor = isDark ? const Color(0xFF253247) : AppColors.border;
    final textMutedColor = isDark
        ? const Color(0xFF64748B)
        : AppColors.textMuted;

    final successSoftColor = isDark
        ? const Color(0xFF003F2D)
        : AppColors.successSoft;
    final successTextColor = isDark
        ? const Color(0xFF34D399)
        : AppColors.successText;

    final errorSoftColor = isDark
        ? const Color(0xFF3F0000)
        : AppColors.errorSoft;
    final errorTextColor = isDark
        ? const Color(0xFFF87171)
        : AppColors.errorText;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusM),
      backgroundColor: surfaceColor,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  decoration: BoxDecoration(
                    color: primarySoftColor,
                    borderRadius: AppSpacing.borderRadiusS,
                  ),
                  child: const Icon(
                    Icons.system_update_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phiên bản mới',
                        style: AppTextStyles.sectionTitle.copyWith(
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${state.currentVersion} → v${state.latestRelease?.version ?? "?"}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chỉ cho đóng khi chưa đang tải
                if (state.status != UpdateStatus.downloading &&
                    state.status != UpdateStatus.installing)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.m),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.m),

            // Tên release
            if (state.latestRelease?.name != null &&
                state.latestRelease!.name.isNotEmpty)
              Text(
                state.latestRelease!.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

            // Nội dung changelog
            if (state.latestRelease?.body != null &&
                state.latestRelease!.body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: surfaceMutedColor,
                  borderRadius: AppSpacing.borderRadiusS,
                  border: Border.all(color: borderSoftColor),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    state.latestRelease!.body,
                    style: AppTextStyles.body.copyWith(
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],

            // Thông tin file tải
            if (state.targetAsset != null) ...[
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    size: 14,
                    color: textMutedColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${state.targetAsset!.name} (${state.targetAsset!.sizeFormatted})',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],

            // Thanh tiến trình tải
            if (state.status == UpdateStatus.downloading) ...[
              const SizedBox(height: AppSpacing.m),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Đang tải xuống...', style: AppTextStyles.label),
                  Text(
                    '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppSpacing.borderRadiusS,
                child: LinearProgressIndicator(
                  value: state.downloadProgress,
                  minHeight: 8,
                  backgroundColor: borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
            ],

            // Tải xong - sẵn sàng cài
            if (state.status == UpdateStatus.readyToInstall) ...[
              const SizedBox(height: AppSpacing.m),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: successSoftColor,
                  borderRadius: AppSpacing.borderRadiusS,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF065F46)
                        : const Color(0xFFD1FAE5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: successTextColor,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        'Tải xuống hoàn tất! Nhấn "Cài đặt ngay" để cập nhật.',
                        style: AppTextStyles.body.copyWith(
                          color: successTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Đang cài đặt
            if (state.status == UpdateStatus.installing) ...[
              const SizedBox(height: AppSpacing.m),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.s),
                  Text('Đang mở trình cài đặt...'),
                ],
              ),
            ],

            // Lỗi
            if (state.status == UpdateStatus.error &&
                state.errorText != null) ...[
              const SizedBox(height: AppSpacing.m),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: errorSoftColor,
                  borderRadius: AppSpacing.borderRadiusS,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: errorTextColor),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        state.errorText!,
                        style: AppTextStyles.body.copyWith(
                          color: errorTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.l),

            // Nút hành động
            _buildActions(context, state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    UpdateState state,
    UpdateNotifier notifier,
  ) {
    switch (state.status) {
      case UpdateStatus.available:
        if (state.targetAsset != null) {
          return Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Để sau',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: AppButton(
                  text: 'Tải và cài đặt',
                  icon: Icons.download_outlined,
                  onPressed: notifier.downloadUpdate,
                ),
              ),
            ],
          );
        }
        // Không có asset cho nền tảng này
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Đóng',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: AppButton(
                text: 'Mở trang Releases',
                icon: Icons.open_in_new,
                onPressed: () {
                  notifier.openReleasePage();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );

      case UpdateStatus.downloading:
        return const SizedBox.shrink();

      case UpdateStatus.readyToInstall:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Để sau',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: AppButton(
                text: 'Cài đặt ngay',
                icon: Icons.install_desktop_outlined,
                onPressed: () {
                  notifier.installUpdate();
                },
              ),
            ),
          ],
        );

      case UpdateStatus.error:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Đóng',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: AppButton(
                text: 'Mở trang Releases',
                icon: Icons.open_in_new,
                onPressed: () {
                  notifier.openReleasePage();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );

      default:
        return AppButton(
          text: 'Đóng',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        );
    }
  }
}
