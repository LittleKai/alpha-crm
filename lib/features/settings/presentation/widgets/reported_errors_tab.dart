import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/utils/zalo_backend_manager.dart';
import 'export_log_file_helper.dart';

/// Tab hiển thị các lỗi hệ thống đã được ứng dụng tự động báo cáo lên backend
/// (qua `AppLogger._reportToBackend`) — lưu trữ lâu dài, xem lại được sau khi
/// khởi động lại app. Thiết kế dạng danh sách thẻ mở rộng để dễ xem xét và
/// trích xuất hơn bảng dữ liệu phẳng trước đây.
class ReportedErrorsTab extends StatefulWidget {
  const ReportedErrorsTab({super.key});

  @override
  State<ReportedErrorsTab> createState() => _ReportedErrorsTabState();
}

class _ReportedErrorsTabState extends State<ReportedErrorsTab> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _selectedLogIds = {};
  final Set<String> _expandedLogIds = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _platformFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final port = ZaloBackendManager.activePort ?? 28080;
      final response = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/logs/client'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _logs = data['logs'] ?? [];
          final existingIds = _logs.map((l) => l['id'] as String? ?? '').toSet();
          _selectedLogIds.retainAll(existingIds);
          _expandedLogIds.retainAll(existingIds);
          if (_platformFilter != 'Tất cả' && !_platforms.contains(_platformFilter)) {
            _platformFilter = 'Tất cả';
          }
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load logs. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Set<String> get _platforms =>
      _logs.map((l) => (l['platform'] as String?) ?? 'Không rõ').toSet();

  List<dynamic> get _filteredLogs {
    return _logs.where((log) {
      final platform = (log['platform'] as String?) ?? 'Không rõ';
      if (_platformFilter != 'Tất cả' && platform != _platformFilter) return false;
      if (_searchQuery.isEmpty) return true;
      final haystack = [
        log['message'],
        log['error'],
        platform,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  void _confirmDeleteSelectedLogs() {
    if (_selectedLogIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Xác nhận xóa lỗi',
        icon: Icons.warning_amber_rounded,
        actions: [
          AppDialogAction(
            text: 'Hủy',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppDialogAction(
            text: 'Xóa',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteLogs(_selectedLogIds.toList());
            },
          ),
        ],
        child: Text(
          'Bạn có chắc chắn muốn xóa ${_selectedLogIds.length} lỗi hệ thống đã chọn không? Hành động này không thể hoàn tác.',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Future<void> _deleteLogs(List<String> ids) async {
    setState(() => _isLoading = true);

    try {
      final port = ZaloBackendManager.activePort ?? 28080;
      final response = await http.post(
        Uri.parse('http://127.0.0.1:$port/api/logs/client/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ids': ids}),
      );

      if (response.statusCode == 200) {
        setState(() => _selectedLogIds.clear());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa các lỗi đã chọn thành công.')),
        );
      } else {
        throw Exception('Failed to delete logs. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa: $e'), backgroundColor: Colors.red),
      );
    } finally {
      await _fetchLogs();
    }
  }

  Future<void> _exportLogs() async {
    final logsToExport = _selectedLogIds.isEmpty
        ? _filteredLogs
        : _filteredLogs.where((log) => _selectedLogIds.contains(log['id'])).toList();

    if (logsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có dữ liệu lỗi để trích xuất.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('=========================================');
    buffer.writeln('ALPHA CRM - SYSTEM ERROR REPORT');
    buffer.writeln('Exported at: ${DateTime.now().toLocal().toString()}');
    buffer.writeln('Total errors: ${logsToExport.length}');
    buffer.writeln('=========================================');
    buffer.writeln();

    for (int i = 0; i < logsToExport.length; i++) {
      final log = logsToExport[i];
      buffer.writeln('-----------------------------------------');
      buffer.writeln('Error #${i + 1}');
      buffer.writeln('-----------------------------------------');
      buffer.writeln('ID: ${log['id'] ?? 'N/A'}');
      buffer.writeln('Time: ${log['timestamp'] ?? 'N/A'}');
      buffer.writeln('Platform: ${log['platform'] ?? 'N/A'}');
      buffer.writeln('Message: ${log['message'] ?? 'N/A'}');
      if (log['error'] != null) {
        buffer.writeln('Error details: ${log['error']}');
      }
      if (log['stackTrace'] != null) {
        buffer.writeln('Stack Trace:\n${log['stackTrace']}');
      }
      buffer.writeln();
    }

    await exportLogTextToFile(
      context: context,
      content: buffer.toString(),
      fileNamePrefix: 'alpha_crm_errors',
      dialogTitle: 'Trích xuất file log thành công',
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'Không rõ';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatRelative(String? isoString) {
    if (isoString == null) return 'Không rõ';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      return '${diff.inDays} ngày trước';
    } catch (_) {
      return 'Không rõ';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Lỗi khi tải dữ liệu: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: AppSpacing.sm),
            AppButton(text: 'Thử lại', icon: Icons.refresh_rounded, onPressed: _fetchLogs),
          ],
        ),
      );
    }

    final filtered = _filteredLogs;
    String? latestTimestamp;
    if (_logs.isNotEmpty) {
      final sorted = [..._logs]..sort((a, b) =>
          (b['timestamp'] as String? ?? '').compareTo(a['timestamp'] as String? ?? ''));
      latestTimestamp = sorted.first['timestamp'] as String?;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsRow(
          total: _logs.length,
          platformCount: _platforms.length,
          latestRelative: _formatRelative(latestTimestamp),
        ),
        const SizedBox(height: AppSpacing.m),
        _Toolbar(
          searchController: _searchController,
          platformFilter: _platformFilter,
          platforms: _platforms,
          onPlatformChanged: (v) => setState(() => _platformFilter = v),
          selectedCount: _selectedLogIds.length,
          onRefresh: _fetchLogs,
          onDelete: _selectedLogIds.isEmpty ? null : _confirmDeleteSelectedLogs,
          onExport: _logs.isEmpty ? null : _exportLogs,
        ),
        const SizedBox(height: AppSpacing.m),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _logs.isEmpty
                        ? 'Chưa có lỗi nào được ghi nhận.'
                        : 'Không tìm thấy lỗi phù hợp với bộ lọc.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    final logId = log['id'] as String? ?? '';
                    return _ErrorLogCard(
                      log: log,
                      selected: _selectedLogIds.contains(logId),
                      expanded: _expandedLogIds.contains(logId),
                      timeLabel: _formatDate(log['timestamp'] as String?),
                      onSelectChanged: (v) {
                        setState(() {
                          if (v) {
                            if (logId.isNotEmpty) _selectedLogIds.add(logId);
                          } else {
                            _selectedLogIds.remove(logId);
                          }
                        });
                      },
                      onExpandToggle: () {
                        setState(() {
                          if (_expandedLogIds.contains(logId)) {
                            _expandedLogIds.remove(logId);
                          } else {
                            _expandedLogIds.add(logId);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int total;
  final int platformCount;
  final String latestRelative;

  const _StatsRow({
    required this.total,
    required this.platformCount,
    required this.latestRelative,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.bug_report_outlined,
            iconColor: AppColors.errorText,
            label: 'Tổng số lỗi',
            value: '$total',
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: _StatTile(
            icon: Icons.devices_outlined,
            iconColor: AppColors.infoText,
            label: 'Nền tảng',
            value: '$platformCount',
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: _StatTile(
            icon: Icons.schedule_outlined,
            iconColor: AppColors.warningText,
            label: 'Lỗi gần nhất',
            value: latestRelative,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String platformFilter;
  final Set<String> platforms;
  final ValueChanged<String> onPlatformChanged;
  final int selectedCount;
  final VoidCallback onRefresh;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;

  const _Toolbar({
    required this.searchController,
    required this.platformFilter,
    required this.platforms,
    required this.onPlatformChanged,
    required this.selectedCount,
    required this.onRefresh,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              height: 40,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tìm theo nội dung lỗi...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                  border: OutlineInputBorder(borderRadius: AppSpacing.borderRadiusS),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: platformFilter,
                  items: [
                    const DropdownMenuItem(value: 'Tất cả', child: Text('Tất cả nền tảng')),
                    ...platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                  ],
                  onChanged: (v) {
                    if (v != null) onPlatformChanged(v);
                  },
                ),
              ),
            ),
            if (selectedCount > 0)
              AppBadge(label: 'Đã chọn $selectedCount', variant: AppBadgeVariant.info),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
              onPressed: onRefresh,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: onDelete == null ? Colors.grey : Colors.redAccent),
              tooltip: onDelete == null ? 'Chọn lỗi để xóa' : 'Xóa $selectedCount lỗi đã chọn',
              onPressed: onDelete,
            ),
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: selectedCount == 0 ? 'Trích xuất tất cả lỗi' : 'Trích xuất $selectedCount lỗi đã chọn',
              onPressed: onExport,
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool selected;
  final bool expanded;
  final String timeLabel;
  final ValueChanged<bool> onSelectChanged;
  final VoidCallback onExpandToggle;

  const _ErrorLogCard({
    required this.log,
    required this.selected,
    required this.expanded,
    required this.timeLabel,
    required this.onSelectChanged,
    required this.onExpandToggle,
  });

  @override
  Widget build(BuildContext context) {
    final platform = (log['platform'] as String?) ?? 'Không rõ';
    final message = (log['message'] as String?) ?? '(không có nội dung)';
    final error = log['error'] as String?;
    final stackTrace = log['stackTrace'] as String?;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => onSelectChanged(v ?? false),
              ),
              Icon(Icons.error_outline, color: AppColors.errorText, size: 20),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: InkWell(
                  onTap: onExpandToggle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        maxLines: expanded ? null : 1,
                        overflow: expanded ? null : TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          AppBadge(label: platform, variant: AppBadgeVariant.neutral),
                          const SizedBox(width: AppSpacing.s),
                          Text(timeLabel, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                tooltip: expanded ? 'Thu gọn' : 'Xem chi tiết',
                onPressed: onExpandToggle,
              ),
            ],
          ),
          if (expanded) ...[
            const Divider(height: AppSpacing.l),
            if (error != null) ...[
              Text('Lỗi:', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppSpacing.borderRadiusS,
                ),
                child: SelectableText(error, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
            if (stackTrace != null) ...[
              Text('Dấu vết ngăn xếp:', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(AppSpacing.s),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppSpacing.borderRadiusS,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    stackTrace,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
