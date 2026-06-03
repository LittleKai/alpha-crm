import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../mock/mock_messages.dart';
import '../../../shared/models/crm_template.dart';
import '../data/templates_repository.dart';

final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  return TemplatesRepository();
});

extension MessageTemplateJson on MessageTemplate {
  static MessageTemplate fromCrmTemplate(CrmTemplate template) {
    return MessageTemplate(
      id: template.id,
      title: template.name,
      content: template.body,
      variables: template.variables,
      createdAt: template.createdAt,
      shortcut: template.shortcut,
      isQuick: template.isQuick,
    );
  }
}

class TemplatesState {
  final List<MessageTemplate> templates;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const TemplatesState({
    required this.templates,
    required this.searchQuery,
    required this.isLoading,
    this.errorMessage,
  });

  factory TemplatesState.initial() {
    return const TemplatesState(
      templates: [],
      searchQuery: '',
      isLoading: false,
      errorMessage: null,
    );
  }

  TemplatesState copyWith({
    List<MessageTemplate>? templates,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TemplatesState(
      templates: templates ?? this.templates,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TemplatesNotifier extends StateNotifier<TemplatesState> {
  final TemplatesRepository _repository;

  TemplatesNotifier(Ref ref)
    : _repository = ref.read(templatesRepositoryProvider),
      super(TemplatesState.initial()) {
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final response = await _repository.getTemplates(search: state.searchQuery);

    if (response['success'] == true && response['data'] != null) {
      final List<dynamic> raw = response['data'];
      final List<MessageTemplate> loaded = raw
          .map((json) => CrmTemplate.fromJson(json))
          .map((t) => MessageTemplateJson.fromCrmTemplate(t))
          .toList();
      state = state.copyWith(templates: loaded, isLoading: false);
    } else {
      if (kDebugMode) {
        state = state.copyWith(
          templates: MockMessages.sampleTemplates,
          isLoading: false,
          errorMessage:
              'Lỗi tải đám mây (Dữ liệu mẫu chế độ phát triển): ${response['message']}',
        );
      } else {
        state = state.copyWith(
          templates: const [],
          isLoading: false,
          errorMessage:
              response['message'] ?? 'Không thể tải mẫu tin từ đám mây.',
        );
      }
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadTemplates();
  }

  Future<void> addTemplate(MessageTemplate template) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final crmTemplate = CrmTemplate(
      id: '',
      userId: '',
      name: template.title,
      subject: '',
      body: template.content,
      type: 'zalo',
      variables: template.variables,
      category: 'general',
      shortcut: template.shortcut,
      isQuick: template.isQuick,
      status: 'active',
      language: 'vi',
      usageCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final response = await _repository.createTemplate(crmTemplate);
    if (response['success'] == true && response['data'] != null) {
      final newCrmTpl = CrmTemplate.fromJson(response['data']);
      final newTpl = MessageTemplateJson.fromCrmTemplate(newCrmTpl);
      state = state.copyWith(
        templates: [newTpl, ...state.templates],
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: response['message'] ?? 'Thêm mẫu tin thất bại.',
      );
    }
  }

  Future<void> deleteTemplate(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final response = await _repository.deleteTemplate(id);
    if (response['success'] == true) {
      state = state.copyWith(
        templates: state.templates.where((t) => t.id != id).toList(),
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: response['message'] ?? 'Xóa mẫu tin thất bại.',
      );
    }
  }

  void triggerError() {
    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Không thể đồng bộ tin mẫu từ máy chủ.',
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clearTemplates() {
    state = state.copyWith(templates: []);
  }
}

final templatesProvider =
    StateNotifierProvider<TemplatesNotifier, TemplatesState>((ref) {
      return TemplatesNotifier(ref);
    });
