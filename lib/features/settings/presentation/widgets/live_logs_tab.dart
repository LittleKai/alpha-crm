import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/utils/app_logger.dart';
import 'export_log_file_helper.dart';

/// Tab hiển thị nhật ký hoạt động trực tiếp trong bộ nhớ (vòng đệm gần nhất
/// của `AppLogger`, tối đa 300 dòng) — hữu ích để chẩn đoán sự cố đang xảy ra
/// ngay trong phiên làm việc hiện tại, kể cả khi chưa được báo cáo lên backend.
/// Chuyển từ thẻ "Lỗi hệ thống & Nhật ký" trong tab Cài đặt sang đây.
class LiveLogsTab extends StatefulWidget {
  const LiveLogsTab({super.key});

  @override
  State<LiveLogsTab> createState() => _LiveLogsTabState();
}

class _LiveLogsTabState extends State<LiveLogsTab> {
  bool _errorsOnly = true;
  List<String> _logs = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadLogs() {
    setState(() {
      final allLogs = AppLogger().recentLogs;
      if (_errorsOnly) {
        _logs = allLogs.where(_isErrorOrWarning).toList();
      } else {
        _logs = allLogs;
      }
    });
  }

  bool _isErrorOrWarning(String line) {
    final upper = line.toUpperCase();
    return upper.contains('[WARN]') ||
        upper.contains('[ERROR]') ||
        upper.contains('[FATAL]') ||
        upper.contains('LỖI') ||
        upper.contains('FAIL') ||
        upper.contains('ERROR') ||
        upper.contains('EXCEPTION');
  }

  List<String> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    return _logs.where((l) => l.toLowerCase().contains(_searchQuery)).toList();
  }

  Future<void> _exportLogs() async {
    if (_filteredLogs.isEmpty) return;
    await exportLogTextToFile(
      context: context,
      content: _filteredLogs.join('\n'),
      fileNamePrefix: 'alpha_crm_local_logs',
      dialogTitle: 'Trích xuất nhật ký thành công',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final consoleBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final consoleText = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final filtered = _filteredLogs;
    final errorCount = _logs.where((l) => l.toUpperCase().contains('[ERROR]') || l.toUpperCase().contains('[FATAL]')).length;
    final warnCount = _logs.where((l) => l.toUpperCase().contains('[WARN]')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Text('Đang hiển thị', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    const SizedBox(width: AppSpacing.s),
                    AppBadge(label: '${filtered.length} dòng', variant: AppBadgeVariant.neutral),
                    const SizedBox(width: AppSpacing.s),
                    if (errorCount > 0)
                      AppBadge(label: '$errorCount lỗi', variant: AppBadgeVariant.error),
                    const SizedBox(width: AppSpacing.s),
                    if (warnCount > 0)
                      AppBadge(label: '$warnCount cảnh báo', variant: AppBadgeVariant.warning),
                    const Spacer(),
                    Text('Chỉ lỗi/cảnh báo', style: AppTextStyles.caption),
                    const SizedBox(width: 4),
                    Switch(
                      value: _errorsOnly,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          _errorsOnly = val;
                          _loadLogs();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tìm trong nhật ký...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                  border: OutlineInputBorder(borderRadius: AppSpacing.borderRadiusS),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Làm mới',
                  onPressed: _loadLogs,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all_rounded),
                  tooltip: 'Sao chép nhật ký',
                  onPressed: filtered.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: filtered.join('\n')));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sao chép nhật ký vào Clipboard.')),
                          );
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Xuất ra file',
                  onPressed: filtered.isEmpty ? null : _exportLogs,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Xóa nhật ký',
                  onPressed: () {
                    AppLogger().clearLogs();
                    _loadLogs();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã xóa nhật ký.')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: consoleBg,
              borderRadius: AppSpacing.borderRadiusS,
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.s),
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _logs.isEmpty
                          ? (_errorsOnly
                              ? 'Không có lỗi hoặc cảnh báo nào được ghi nhận.'
                              : 'Nhật ký trống.')
                          : 'Không tìm thấy dòng nào khớp với tìm kiếm.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final line = filtered[filtered.length - 1 - index];

                      Color textColor = consoleText;
                      FontWeight weight = FontWeight.normal;

                      final upper = line.toUpperCase();
                      if (upper.contains('[ERROR]') || upper.contains('[FATAL]')) {
                        textColor = const Color(0xFFEF4444);
                        weight = FontWeight.w600;
                      } else if (upper.contains('[WARN]')) {
                        textColor = const Color(0xFFF59E0B);
                        weight = FontWeight.w600;
                      } else if (upper.contains('[INFO]')) {
                        textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: SelectableText(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor,
                            fontWeight: weight,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
