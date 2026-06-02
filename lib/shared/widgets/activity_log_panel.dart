import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class LogItem {
  final String timestamp;
  final String message;
  final LogType type;

  const LogItem({
    required this.timestamp,
    required this.message,
    this.type = LogType.info,
  });
}

enum LogType { info, success, warning, error }

class ActivityLogPanel extends StatefulWidget {
  final List<LogItem> logs;
  final String title;
  final bool isRunning;
  final VoidCallback? onClear;
  final double height;

  const ActivityLogPanel({
    super.key,
    required this.logs,
    this.title = 'NHẬT KÝ HOẠT ĐỘNG',
    this.isRunning = false,
    this.onClear,
    this.height = 300.0,
  });

  @override
  State<ActivityLogPanel> createState() => _ActivityLogPanelState();
}

class _ActivityLogPanelState extends State<ActivityLogPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ActivityLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (widget.isRunning) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                ],
                Text(
                  widget.title,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (widget.onClear != null && widget.logs.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    onPressed: widget.onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Xóa nhật ký',
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          // Log List
          Expanded(
            child: widget.logs.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có hoạt động nào được ghi nhận.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    itemCount: widget.logs.length,
                    itemBuilder: (context, index) {
                      // Chronological order (oldest at top, newest at bottom)
                      final log = widget.logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timestamp
                            Text(
                              '[${log.timestamp}]',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            // Log message
                            Expanded(
                              child: Text(
                                log.message,
                                style: AppTextStyles.caption.copyWith(
                                  color: _getLogColor(log.type),
                                  fontWeight: log.type == LogType.error
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getLogColor(LogType type) {
    switch (type) {
      case LogType.success:
        return AppColors.successText;
      case LogType.warning:
        return AppColors.warningText;
      case LogType.error:
        return AppColors.errorText;
      case LogType.info:
        return AppColors.textSecondary;
    }
  }
}
