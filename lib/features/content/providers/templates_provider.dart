import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../mock/mock_messages.dart';

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
  TemplatesNotifier() : super(TemplatesState.initial());

  void loadTemplates() {
    state = state.copyWith(isLoading: true);
    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 400), () {
      state = state.copyWith(
        templates: MockMessages.sampleTemplates,
        isLoading: false,
      );
    });
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void addTemplate(MessageTemplate template) {
    state = state.copyWith(templates: [template, ...state.templates]);
  }

  void deleteTemplate(String id) {
    state = state.copyWith(
      templates: state.templates.where((t) => t.id != id).toList(),
    );
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
      return TemplatesNotifier();
    });
