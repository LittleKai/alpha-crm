import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/api/crm_cloud_api.dart';

class CrmTask {
  final String id;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String relatedType;
  final DateTime? dueAt;
  final String ownerNote;

  /// Group context (populated from CrmZaloGroup on the cloud). Empty when the
  /// task is not linked to a Zalo group.
  final String groupName;
  final String groupAccountId;
  final String groupThreadId;

  const CrmTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.relatedType,
    this.dueAt,
    required this.ownerNote,
    this.groupName = '',
    this.groupAccountId = '',
    this.groupThreadId = '',
  });

  bool get hasGroupLink => groupThreadId.isNotEmpty;

  CrmTask copyWith({String? status}) {
    return CrmTask(
      id: id,
      title: title,
      description: description,
      priority: priority,
      status: status ?? this.status,
      relatedType: relatedType,
      dueAt: dueAt,
      ownerNote: ownerNote,
      groupName: groupName,
      groupAccountId: groupAccountId,
      groupThreadId: groupThreadId,
    );
  }

  static CrmTask fromJson(Map<String, dynamic> json) {
    // `groupId` is populated to { name, accountId, groupId } on the cloud.
    final group = json['groupId'] is Map
        ? Map<String, dynamic>.from(json['groupId'] as Map)
        : const <String, dynamic>{};
    return CrmTask(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      status: (json['status'] ?? 'open').toString(),
      relatedType: (json['relatedType'] ?? 'manual').toString(),
      dueAt: DateTime.tryParse((json['dueAt'] ?? '').toString()),
      ownerNote: (json['ownerNote'] ?? '').toString(),
      groupName: (group['name'] ?? '').toString(),
      groupAccountId: (group['accountId'] ?? '').toString(),
      groupThreadId: (group['groupId'] ?? '').toString(),
    );
  }
}

class CrmTasksState {
  final List<CrmTask> tasks;
  final String statusFilter;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  /// Number of tasks with status `open` — drives the sidebar red badge.
  final int openCount;

  const CrmTasksState({
    required this.tasks,
    required this.statusFilter,
    required this.isLoading,
    required this.isSaving,
    this.errorMessage,
    this.openCount = 0,
  });

  factory CrmTasksState.initial() {
    return const CrmTasksState(
      tasks: [],
      statusFilter: 'open',
      isLoading: false,
      isSaving: false,
      errorMessage: null,
      openCount: 0,
    );
  }

  CrmTasksState copyWith({
    List<CrmTask>? tasks,
    String? statusFilter,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    int? openCount,
  }) {
    return CrmTasksState(
      tasks: tasks ?? this.tasks,
      statusFilter: statusFilter ?? this.statusFilter,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      openCount: openCount ?? this.openCount,
    );
  }
}

/// Default deadline by priority when none is provided: high → +1d, medium → +3d,
/// low → +7d. Tasks remain user-editable afterwards.
DateTime defaultDueByPriority(String priority) {
  final now = DateTime.now();
  switch (priority) {
    case 'high':
      return now.add(const Duration(days: 1));
    case 'low':
      return now.add(const Duration(days: 7));
    default:
      return now.add(const Duration(days: 3));
  }
}

class CrmTasksNotifier extends StateNotifier<CrmTasksState> {
  CrmTasksNotifier() : super(CrmTasksState.initial()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final response = await CrmCloudApi.get(
      '/crm/tasks?status=${state.statusFilter}',
    );
    if (response['success'] == true && response['data'] is List) {
      final tasks = (response['data'] as List)
          .whereType<Map>()
          .map((item) => CrmTask.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
        openCount: state.statusFilter == 'open' ? tasks.length : state.openCount,
      );
      if (state.statusFilter != 'open') {
        await _refreshOpenCount();
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            (response['message'] ?? 'Không thể tải danh sách công việc.')
                .toString(),
      );
    }
  }

  Future<void> _refreshOpenCount() async {
    final response = await CrmCloudApi.get('/crm/tasks?status=open');
    if (response['success'] == true && response['data'] is List) {
      state = state.copyWith(openCount: (response['data'] as List).length);
    }
  }

  Future<void> setStatusFilter(String status) async {
    state = state.copyWith(statusFilter: status);
    await loadTasks();
  }

  Future<void> createTask({
    required String title,
    String description = '',
    String priority = 'medium',
    DateTime? dueAt,
  }) async {
    if (title.trim().isEmpty) return;
    state = state.copyWith(isSaving: true, errorMessage: null);
    // Auto-assign a deadline by priority when none is provided (user-editable).
    final effectiveDueAt = dueAt ?? defaultDueByPriority(priority);
    final response = await CrmCloudApi.post('/crm/tasks', {
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority,
      'relatedType': 'manual',
      'dueAt': effectiveDueAt.toIso8601String(),
    });
    state = state.copyWith(isSaving: false);
    if (response['success'] == true) {
      await loadTasks();
    } else {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Tạo công việc thất bại.')
            .toString(),
      );
    }
  }

  /// Edit an existing task (title, description, priority, deadline).
  Future<void> updateTask(
    CrmTask task, {
    String? title,
    String? description,
    String? priority,
    DateTime? dueAt,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    final response = await CrmCloudApi.put('/crm/tasks/${task.id}', {
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (priority != null) 'priority': priority,
      if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
    });
    state = state.copyWith(isSaving: false);
    if (response['success'] == true) {
      await loadTasks();
    } else {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Cập nhật công việc thất bại.')
            .toString(),
      );
    }
  }

  Future<void> updateStatus(CrmTask task, String status) async {
    final response = await CrmCloudApi.put('/crm/tasks/${task.id}', {
      'status': status,
    });
    if (response['success'] == true) {
      state = state.copyWith(
        tasks: state.tasks
            .map(
              (item) =>
                  item.id == task.id ? item.copyWith(status: status) : item,
            )
            .toList(),
      );
      await loadTasks();
    }
  }

  Future<void> deleteTask(CrmTask task) async {
    final response = await CrmCloudApi.delete('/crm/tasks/${task.id}');
    if (response['success'] == true) {
      state = state.copyWith(
        tasks: state.tasks.where((item) => item.id != task.id).toList(),
      );
      await _refreshOpenCount();
    }
  }
}

final crmTasksProvider = StateNotifierProvider<CrmTasksNotifier, CrmTasksState>(
  (ref) {
    return CrmTasksNotifier();
  },
);
