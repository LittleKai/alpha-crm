import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../mock/mock_campaigns.dart';
import '../../../../shared/models/crm_execution_log.dart';
import '../data/send_history_repository.dart';

final sendHistoryRepositoryProvider = Provider<SendHistoryRepository>((ref) {
  return SendHistoryRepository();
});

extension SendHistoryRecordJson on SendHistoryRecord {
  static SendHistoryRecord fromCrmExecutionLog(CrmExecutionLog log) {
    String uiStatus = 'Đang chờ';
    if (log.status == 'success') {
      uiStatus = 'Thành công';
    } else if (log.status == 'failed' || log.status == 'cancelled') {
      uiStatus = 'Thất bại';
    }

    return SendHistoryRecord(
      id: log.id,
      campaignName: log.campaignSnapshot?['name']?.toString() ?? 'CSKH Zalo',
      phone: log.recipientPhone,
      message: log.messagePreview.isNotEmpty
          ? log.messagePreview
          : 'Gửi tin nhắn chiến dịch',
      status: uiStatus,
      sentAt: log.sentAt ?? log.createdAt,
    );
  }
}

class SendHistoryState {
  final List<SendHistoryRecord> records;
  final Set<String> selectedIds;
  final String searchQuery;
  final String selectedStatus; // 'Tất cả' or specific status
  final bool isLoading;
  final String? errorMessage;

  const SendHistoryState({
    required this.records,
    required this.selectedIds,
    required this.searchQuery,
    required this.selectedStatus,
    required this.isLoading,
    this.errorMessage,
  });

  factory SendHistoryState.initial() {
    return const SendHistoryState(
      records: [],
      selectedIds: {},
      searchQuery: '',
      selectedStatus: 'Tất cả',
      isLoading: false,
      errorMessage: null,
    );
  }

  SendHistoryState copyWith({
    List<SendHistoryRecord>? records,
    Set<String>? selectedIds,
    String? searchQuery,
    String? selectedStatus,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SendHistoryState(
      records: records ?? this.records,
      selectedIds: selectedIds ?? this.selectedIds,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class SendHistoryNotifier extends StateNotifier<SendHistoryState> {
  final SendHistoryRepository _repository;

  SendHistoryNotifier(Ref ref)
    : _repository = ref.read(sendHistoryRepositoryProvider),
      super(SendHistoryState.initial()) {
    loadRecords();
  }

  Future<void> loadRecords() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final response = await _repository.getExecutionLogs(
      search: state.searchQuery,
      status: state.selectedStatus == 'Tất cả' ? null : state.selectedStatus,
      limit: 100, // Load a reasonable list for history view
    );

    if (response['success'] == true && response['data'] != null) {
      final List<dynamic> raw = response['data'];
      final List<SendHistoryRecord> loaded = raw
          .map((json) => CrmExecutionLog.fromJson(json))
          .map((log) => SendHistoryRecordJson.fromCrmExecutionLog(log))
          .toList();
      state = state.copyWith(records: loaded, isLoading: false);
    } else {
      if (kDebugMode) {
        state = state.copyWith(
          records: MockCampaignsData.sampleSendHistory,
          isLoading: false,
          errorMessage:
              'Lỗi tải đám mây (Dữ liệu mẫu chế độ phát triển): ${response['message']}',
        );
      } else {
        state = state.copyWith(
          records: const [],
          isLoading: false,
          errorMessage:
              response['message'] ??
              'Không thể tải lịch sử gửi tin từ đám mây.',
        );
      }
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadRecords();
  }

  void setSelectedStatus(String status) {
    state = state.copyWith(selectedStatus: status);
    loadRecords();
  }

  void toggleRecordSelection(String id) {
    final newSelected = Set<String>.from(state.selectedIds);
    if (newSelected.contains(id)) {
      newSelected.remove(id);
    } else {
      newSelected.add(id);
    }
    state = state.copyWith(selectedIds: newSelected);
  }

  void toggleAllSelection(List<SendHistoryRecord> visibleRecords) {
    final newSelected = Set<String>.from(state.selectedIds);
    final visibleIds = visibleRecords.map((r) => r.id).toSet();

    final allVisibleSelected = visibleIds.every(
      (id) => newSelected.contains(id),
    );
    if (allVisibleSelected) {
      newSelected.removeAll(visibleIds);
    } else {
      newSelected.addAll(visibleIds);
    }
    state = state.copyWith(selectedIds: newSelected);
  }

  Future<bool> exportToCsv() async {
    if (state.records.isEmpty) return false;

    try {
      final buffer = StringBuffer();
      buffer.write('\xEF\xBB\xBF');
      buffer.writeln('Chiến dịch,Người nhận,SĐT,Nội dung,Trạng thái,Thời gian');

      for (final r in state.records) {
        final campaign = '"${r.campaignName.replaceAll('"', '""')}"';
        final phone = '"${r.phone.replaceAll('"', '""')}"';
        final message = '"${r.message.replaceAll('"', '""')}"';
        final status = '"${r.status.replaceAll('"', '""')}"';
        final time = '"${r.sentAt.toString().replaceAll('"', '""')}"';
        buffer.writeln('$campaign,"",$phone,$message,$status,$time');
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      return true;
    } catch (e) {
      debugPrint('Export error: $e');
      return false;
    }
  }
}

final sendHistoryProvider =
    StateNotifierProvider<SendHistoryNotifier, SendHistoryState>((ref) {
      return SendHistoryNotifier(ref);
    });
