import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../utils/string_helper.dart';

class LogItem {
  final String timestamp;
  final String message;
  final LogType type;

  LogItem({
    required this.timestamp,
    required String message,
    this.type = LogType.info,
  }) : message = message.toWellFormed();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF111827) : AppColors.surface;
    final borderColor = isDark ? const Color(0xFF253247) : AppColors.border;
    final textPrimaryColor = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textMutedColor = isDark
        ? Colors.white70
        : AppColors.textMuted;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: borderColor, width: 1),
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
                  SizedBox(
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
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (widget.onClear != null && widget.logs.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: textMutedColor,
                    ),
                    onPressed: widget.onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Xóa nhật ký',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Log List
          Expanded(
            child: widget.logs.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có hoạt động nào được ghi nhận.',
                      style: AppTextStyles.caption.copyWith(
                        color: textMutedColor,
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
                                color: textMutedColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            // Log message
                            Expanded(
                              child: Text(
                                log.message,
                                style: AppTextStyles.caption.copyWith(
                                  color: _getLogColor(log.type, isDark),
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

  Color _getLogColor(LogType type, bool isDark) {
    switch (type) {
      case LogType.success:
        return isDark ? const Color(0xFF34D399) : AppColors.successText;
      case LogType.warning:
        return isDark ? const Color(0xFFFBBF24) : AppColors.warningText;
      case LogType.error:
        return isDark ? const Color(0xFFF87171) : AppColors.errorText;
      case LogType.info:
        return isDark ? Colors.white : AppColors.textSecondary;
    }
  }
}
