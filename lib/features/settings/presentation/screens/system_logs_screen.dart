import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:data_table_2/data_table_2.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _error;

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
      final response = await http.get(Uri.parse('http://127.0.0.1:8787/api/logs/client'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _logs = data['logs'] ?? [];
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
      builder: (context) => AlertDialog(
        title: Text(log['message'] ?? 'Error Details'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform: ${log['platform'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Time: ${log['timestamp']}'),
                const Divider(),
                if (log['error'] != null) ...[
                  const Text('Error:', style: TextStyle(fontWeight: FontWeight.bold)),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử lỗi hệ thống'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                        ],
                        rows: _logs.map((log) {
                          return DataRow(
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
                            ],
                            onSelectChanged: (_) => _showLogDetails(log),
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
