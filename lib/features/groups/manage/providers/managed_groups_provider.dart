import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/managed_groups_repository.dart';

final managedGroupsRepositoryProvider = Provider<ManagedGroupsRepository>((
  ref,
) {
  return ManagedGroupsRepository();
});

class ManagedZaloGroup {
  final String id;
  final String accountId;
  final String groupId;
  final String name;
  final String avatarUrl;
  final int memberCount;
  final bool isManaged;
  final String summaryCadence;
  final String notes;
  final DateTime? lastMessageAt;

  const ManagedZaloGroup({
    required this.id,
    required this.accountId,
    required this.groupId,
    required this.name,
    this.avatarUrl = '',
    required this.memberCount,
    required this.isManaged,
    required this.summaryCadence,
    required this.notes,
    this.lastMessageAt,
  });

  ManagedZaloGroup copyWith({
    bool? isManaged,
    String? summaryCadence,
    String? notes,
  }) {
    return ManagedZaloGroup(
      id: id,
      accountId: accountId,
      groupId: groupId,
      name: name,
      avatarUrl: avatarUrl,
      memberCount: memberCount,
      isManaged: isManaged ?? this.isManaged,
      summaryCadence: summaryCadence ?? this.summaryCadence,
      notes: notes ?? this.notes,
      lastMessageAt: lastMessageAt,
    );
  }

  static ManagedZaloGroup fromJson(Map<String, dynamic> json) {
    return ManagedZaloGroup(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      accountId: (json['accountId'] ?? '').toString(),
      groupId: (json['groupId'] ?? '').toString(),
      name: (json['name'] ?? json['groupId'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar'] ?? '').toString(),
      memberCount: int.tryParse((json['memberCount'] ?? 0).toString()) ?? 0,
      isManaged: json['isManaged'] == true,
      summaryCadence: (json['summaryCadence'] ?? 'daily').toString(),
      notes: (json['notes'] ?? '').toString(),
      lastMessageAt: DateTime.tryParse(
        (json['lastMessageAt'] ?? '').toString(),
      ),
    );
  }
}

class GroupInsight {
  final String id;
  final String type;
  final String title;
  final String description;
  final int priority;

  const GroupInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
  });

  static GroupInsight fromJson(Map<String, dynamic> json) {
    return GroupInsight(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      priority: int.tryParse((json['priority'] ?? 0).toString()) ?? 0,
    );
  }
}

class GroupSummaryRecord {
  final String id;
  final String summaryText;
  final DateTime createdAt;

  const GroupSummaryRecord({
    required this.id,
    required this.summaryText,
    required this.createdAt,
  });

  static GroupSummaryRecord fromJson(Map<String, dynamic> json) {
    return GroupSummaryRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      summaryText: (json['summaryText'] ?? json['summary'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ManagedGroupsState {
  final List<ManagedZaloGroup> groups;
  final List<GroupInsight> insights;
  final List<GroupSummaryRecord> selectedSummaries;
  final ManagedZaloGroup? selectedGroup;
  final String selectedAccountId;
  final bool showManagedOnly;
  final bool isLoading;
  final bool isWorking;
  final String? errorMessage;
  final String? exportCsv;

  const ManagedGroupsState({
    required this.groups,
    required this.insights,
    required this.selectedSummaries,
    this.selectedGroup,
    this.selectedAccountId = '',
    required this.showManagedOnly,
    required this.isLoading,
    required this.isWorking,
    this.errorMessage,
    this.exportCsv,
  });

  factory ManagedGroupsState.initial() {
    return const ManagedGroupsState(
      groups: [],
      insights: [],
      selectedSummaries: [],
      selectedGroup: null,
      selectedAccountId: '',
      showManagedOnly: false,
      isLoading: false,
      isWorking: false,
      errorMessage: null,
      exportCsv: null,
    );
  }

  ManagedGroupsState copyWith({
    List<ManagedZaloGroup>? groups,
    List<GroupInsight>? insights,
    List<GroupSummaryRecord>? selectedSummaries,
    ManagedZaloGroup? selectedGroup,
    bool clearSelectedGroup = false,
    String? selectedAccountId,
    bool? showManagedOnly,
    bool? isLoading,
    bool? isWorking,
    String? errorMessage,
    String? exportCsv,
  }) {
    return ManagedGroupsState(
      groups: groups ?? this.groups,
      insights: insights ?? this.insights,
      selectedSummaries: selectedSummaries ?? this.selectedSummaries,
      selectedGroup: clearSelectedGroup
          ? null
          : selectedGroup ?? this.selectedGroup,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      showManagedOnly: showManagedOnly ?? this.showManagedOnly,
      isLoading: isLoading ?? this.isLoading,
      isWorking: isWorking ?? this.isWorking,
      errorMessage: errorMessage,
      exportCsv: exportCsv ?? this.exportCsv,
    );
  }
}

class ManagedGroupsNotifier extends StateNotifier<ManagedGroupsState> {
  final ManagedGroupsRepository _repository;

  ManagedGroupsNotifier(this._repository)
    : super(ManagedGroupsState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.wait([loadGroups(), loadInsights()]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadGroups() async {
    final response = await _repository.getGroups(
      accountId: state.selectedAccountId,
      managed: state.showManagedOnly ? true : null,
    );
    if (response['success'] == true && response['data'] is List) {
      final groups = (response['data'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                ManagedZaloGroup.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      state = state.copyWith(groups: groups);
    } else {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Không thể tải nhóm.').toString(),
      );
    }
  }

  Future<void> loadInsights() async {
    final response = await _repository.getInsights();
    if (response['success'] == true && response['data'] is List) {
      state = state.copyWith(
        insights: (response['data'] as List)
            .whereType<Map>()
            .map(
              (item) => GroupInsight.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
    }
  }

  Future<void> setSelectedAccountId(String accountId) async {
    state = state.copyWith(
      selectedAccountId: accountId,
      clearSelectedGroup: true,
    );
    await loadGroups();
  }

  Future<void> syncGroups() async {
    state = state.copyWith(isWorking: true, errorMessage: null);
    final response = await _repository.syncGroups(
      accountId: state.selectedAccountId,
    );
    state = state.copyWith(
      isWorking: false,
      errorMessage: response['success'] == true
          ? null
          : (response['message'] ?? 'Đồng bộ nhóm thất bại.').toString(),
    );
    if (response['success'] == true) {
      await loadGroups();
    }
  }

  Future<void> setManaged(ManagedZaloGroup group, bool isManaged) async {
    final targetGroups = state.groups.where((g) => g.groupId == group.groupId).toList();
    bool anySuccess = false;

    for (final g in targetGroups) {
      final response = await _repository.updateManaged(
        g.id,
        isManaged: isManaged,
        summaryCadence: g.summaryCadence,
        notes: g.notes,
      );
      if (response['success'] == true) {
        anySuccess = true;
      }
    }

    if (anySuccess) {
      state = state.copyWith(
        groups: state.groups.map((item) {
          if (item.groupId == group.groupId) {
            return item.copyWith(isManaged: isManaged);
          }
          return item;
        }).toList(),
        selectedGroup: state.selectedGroup?.groupId == group.groupId
            ? state.selectedGroup?.copyWith(isManaged: isManaged)
            : state.selectedGroup,
      );
    }
  }

  Future<void> selectGroup(ManagedZaloGroup group) async {
    state = state.copyWith(selectedGroup: group, selectedSummaries: []);
    final response = await _repository.getSummaries(group.id);
    if (response['success'] == true && response['data'] is List) {
      state = state.copyWith(
        selectedSummaries: (response['data'] as List)
            .whereType<Map>()
            .map(
              (item) =>
                  GroupSummaryRecord.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
    }
  }

  Future<void> summarizeSelected() async {
    final group = state.selectedGroup;
    if (group == null) return;
    state = state.copyWith(isWorking: true, errorMessage: null);
    final response = await _repository.summarizeGroup(group.id);
    if (response['success'] == true) {
      await selectGroup(group);
      await loadInsights();
    } else {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Tóm tắt nhóm thất bại.')
            .toString(),
      );
    }
    state = state.copyWith(isWorking: false);
  }

  Future<void> toggleManagedOnly(bool value) async {
    state = state.copyWith(showManagedOnly: value);
    await loadGroups();
  }

  Future<void> exportSummaries() async {
    final response = await _repository.exportSummaries(
      groupId: state.selectedGroup?.id,
    );
    final data = response['data'];
    if (response['success'] == true && data is Map) {
      state = state.copyWith(exportCsv: (data['csv'] ?? '').toString());
    }
  }
}

final managedGroupsProvider =
    StateNotifierProvider<ManagedGroupsNotifier, ManagedGroupsState>((ref) {
      return ManagedGroupsNotifier(ref.read(managedGroupsRepositoryProvider));
    });
