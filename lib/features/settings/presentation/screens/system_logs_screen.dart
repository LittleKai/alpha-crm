import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:data_table_2/data_table_2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/utils/zalo_backend_manager.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _selectedLogIds = {};

  @override
  void initState() {
    super.initState();
    _fetchLogs();
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
          // Clear selected IDs that are no longer in the loaded logs
          final existingIds = _logs.map((l) => l['id'] as String? ?? '').toSet();
          _selectedLogIds.retainAll(existingIds);
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

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: log['message'] ?? 'Chi tiết lỗi',
        icon: Icons.bug_report_outlined,
        width: 600,
        actions: [
          AppDialogAction(
            text: 'Đóng',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform: ${log['platform'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Time: ${log['timestamp']}'),
            const Divider(),
            if (log['error'] != null) ...[
              const Text('Error:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: AppColors.surface,
                child: SelectableText(log['error']),
              ),
              const SizedBox(height: 16),
            ],
            if (log['stackTrace'] != null) ...[
              const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: AppColors.surface,
                child: SelectableText(log['stackTrace']),
              ),
            ],
          ],
        ),
      ),
    );
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
    setState(() {
      _isLoading = true;
    });

    try {
      final port = ZaloBackendManager.activePort ?? 28080;
      final response = await http.post(
        Uri.parse('http://127.0.0.1:$port/api/logs/client/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ids': ids}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _selectedLogIds.clear();
        });
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

  Future<void> _exportLogsToFile() async {
    final logsToExport = _selectedLogIds.isEmpty
        ? _logs
        : _logs.where((log) => _selectedLogIds.contains(log['id'])).toList();

    if (logsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có dữ liệu lỗi để trích xuất.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Không tìm thấy thư mục Downloads trên hệ thống.');
      }

      final crmDir = Directory('${downloadsDir.path}${Platform.pathSeparator}AlphaCRM');
      if (!await crmDir.exists()) {
        await crmDir.create(recursive: true);
      }

      final timeStr = DateTime.now().toLocal().toString().replaceAll(RegExp(r'[:. ]'), '_');
      final fileName = 'alpha_crm_errors_$timeStr.txt';
      final filePath = '${crmDir.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      // Hiển thị dialog hỏi có muốn mở thư mục không
      showDialog(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: 'Trích xuất file log thành công',
          icon: Icons.folder_open_outlined,
          actions: [
            AppDialogAction(
              text: 'Đóng',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppDialogAction(
              text: 'Mở thư mục',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  final folderUri = Uri.parse('file:///${crmDir.path.replaceAll(r'\', '/')}');
                  if (await canLaunchUrl(folderUri)) {
                    await launchUrl(folderUri);
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Không thể mở thư mục tự động.')),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi mở thư mục: $e')),
                  );
                }
              },
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'File lỗi hệ thống đã được lưu thành công tại:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s),
                color: AppColors.surfaceMuted,
                child: SelectableText(
                  filePath,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              const Text('Bạn có muốn mở thư mục chứa tệp tin này không?'),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi trích xuất: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử lỗi hệ thống'),
        actions: [
          if (_logs.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: _selectedLogIds.isEmpty ? Colors.grey : Colors.redAccent,
              ),
              tooltip: _selectedLogIds.isEmpty ? 'Chọn lỗi để xóa' : 'Xóa ${_selectedLogIds.length} lỗi đã chọn',
              onPressed: _selectedLogIds.isEmpty ? null : _confirmDeleteSelectedLogs,
            ),
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: _selectedLogIds.isEmpty ? 'Trích xuất tất cả lỗi' : 'Trích xuất ${_selectedLogIds.length} lỗi đã chọn',
              onPressed: _exportLogsToFile,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _fetchLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Lỗi khi tải dữ liệu: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: _fetchLogs,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _logs.isEmpty
                  ? const Center(child: Text('Chưa có lỗi nào được ghi nhận.'))
                  : Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: DataTable2(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        minWidth: 600,
                        columns: const [
                          DataColumn2(label: Text('Thời gian'), size: ColumnSize.S),
                          DataColumn2(label: Text('Nền tảng'), size: ColumnSize.S),
                          DataColumn2(label: Text('Lỗi'), size: ColumnSize.L),
                          DataColumn2(label: Text('Hành động'), size: ColumnSize.S, fixedWidth: 100),
                        ],
                        rows: _logs.map((log) {
                          final logId = log['id'] as String? ?? '';
                          return DataRow(
                            selected: _selectedLogIds.contains(logId),
                            onSelectChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  if (logId.isNotEmpty) _selectedLogIds.add(logId);
                                } else {
                                  _selectedLogIds.remove(logId);
                                }
                              });
                            },
                            cells: [
                              DataCell(Text(_formatDate(log['timestamp']))),
                              DataCell(Text(log['platform'] ?? 'Unknown')),
                              DataCell(
                                Text(
                                  log['message'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 20),
                                      tooltip: 'Chi tiết lỗi',
                                      onPressed: () => _showLogDetails(log),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
