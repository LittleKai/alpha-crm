import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../mock/mock_campaigns.dart';

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
  SendHistoryNotifier() : super(SendHistoryState.initial());

  void loadRecords() {
    state = state.copyWith(isLoading: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      state = state.copyWith(
        records: MockCampaignsData.sampleSendHistory,
        isLoading: false,
      );
    });
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedStatus(String status) {
    state = state.copyWith(selectedStatus: status);
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

  void deleteRecord(String id) {
    final updatedRecords = state.records.where((r) => r.id != id).toList();
    final newSelected = Set<String>.from(state.selectedIds)..remove(id);
    state = state.copyWith(records: updatedRecords, selectedIds: newSelected);
  }

  void deleteSelected() {
    final remainingRecords = state.records
        .where((r) => !state.selectedIds.contains(r.id))
        .toList();
    state = state.copyWith(records: remainingRecords, selectedIds: {});
  }

  void clearHistory() {
    state = state.copyWith(records: [], selectedIds: {});
  }
}

final sendHistoryProvider =
    StateNotifierProvider<SendHistoryNotifier, SendHistoryState>((ref) {
      return SendHistoryNotifier();
    });
