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

  const CrmTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.relatedType,
    this.dueAt,
    required this.ownerNote,
  });

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
    );
  }

  static CrmTask fromJson(Map<String, dynamic> json) {
    return CrmTask(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      status: (json['status'] ?? 'open').toString(),
      relatedType: (json['relatedType'] ?? 'manual').toString(),
      dueAt: DateTime.tryParse((json['dueAt'] ?? '').toString()),
      ownerNote: (json['ownerNote'] ?? '').toString(),
    );
  }
}

class CrmTasksState {
  final List<CrmTask> tasks;
  final String statusFilter;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const CrmTasksState({
    required this.tasks,
    required this.statusFilter,
    required this.isLoading,
    required this.isSaving,
    this.errorMessage,
  });

  factory CrmTasksState.initial() {
    return const CrmTasksState(
      tasks: [],
      statusFilter: 'open',
      isLoading: false,
      isSaving: false,
      errorMessage: null,
    );
  }

  CrmTasksState copyWith({
    List<CrmTask>? tasks,
    String? statusFilter,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return CrmTasksState(
      tasks: tasks ?? this.tasks,
      statusFilter: statusFilter ?? this.statusFilter,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
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
      state = state.copyWith(
        tasks: (response['data'] as List)
            .whereType<Map>()
            .map((item) => CrmTask.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: (response['message'] ?? 'Không thể tải danh sách công việc.')
            .toString(),
      );
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
    final response = await CrmCloudApi.post('/crm/tasks', {
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority,
      'relatedType': 'manual',
      if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
    });
    state = state.copyWith(isSaving: false);
    if (response['success'] == true) {
      await loadTasks();
    } else {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Tạo công việc thất bại.').toString(),
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
    }
  }
}

final crmTasksProvider = StateNotifierProvider<CrmTasksNotifier, CrmTasksState>(
  (ref) {
    return CrmTasksNotifier();
  },
);
