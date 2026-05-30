import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatbotRule {
  final String id;
  final String keyword;
  final String response;
  final bool isActive;

  const ChatbotRule({
    required this.id,
    required this.keyword,
    required this.response,
    this.isActive = true,
  });

  ChatbotRule copyWith({
    String? id,
    String? keyword,
    String? response,
    bool? isActive,
  }) {
    return ChatbotRule(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      response: response ?? this.response,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ChatbotLogRecord {
  final String id;
  final String customerName;
  final String keyword;
  final String response;
  final DateTime timestamp;
  final String status; // 'Thành công', 'Thất bại'

  const ChatbotLogRecord({
    required this.id,
    required this.customerName,
    required this.keyword,
    required this.response,
    required this.timestamp,
    required this.status,
  });
}

class ChatbotState {
  final int
  activeTab; // 0: Kịch bản từ khóa, 1: AI, 2: Tài liệu kiến thức, 3: Nhật ký
  final List<ChatbotRule> rules;
  final String aiModel;
  final String systemPrompt;
  final double temperature;
  final List<String> knowledgeDocuments;
  final List<ChatbotLogRecord> logs;

  const ChatbotState({
    required this.activeTab,
    required this.rules,
    required this.aiModel,
    required this.systemPrompt,
    required this.temperature,
    required this.knowledgeDocuments,
    required this.logs,
  });

  factory ChatbotState.initial() {
    return const ChatbotState(
      activeTab: 0,
      rules: [],
      aiModel: 'Gemini 1.5 Flash',
      systemPrompt:
          'Bạn là trợ lý ảo CSKH thông minh của phần mềm marketing CRM Zalo. Hãy trả lời thân thiện, ngắn gọn, và luôn hướng khách hàng sử dụng dịch vụ của chúng tôi.',
      temperature: 0.7,
      knowledgeDocuments: [],
      logs: [],
    );
  }

  ChatbotState copyWith({
    int? activeTab,
    List<ChatbotRule>? rules,
    String? aiModel,
    String? systemPrompt,
    double? temperature,
    List<String>? knowledgeDocuments,
    List<ChatbotLogRecord>? logs,
  }) {
    return ChatbotState(
      activeTab: activeTab ?? this.activeTab,
      rules: rules ?? this.rules,
      aiModel: aiModel ?? this.aiModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      knowledgeDocuments: knowledgeDocuments ?? this.knowledgeDocuments,
      logs: logs ?? this.logs,
    );
  }
}

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  ChatbotNotifier() : super(ChatbotState.initial());

  void setActiveTab(int tab) {
    state = state.copyWith(activeTab: tab);
  }

  void toggleRuleStatus(String id) {
    final updatedRules = state.rules.map((rule) {
      if (rule.id == id) {
        return rule.copyWith(isActive: !rule.isActive);
      }
      return rule;
    }).toList();
    state = state.copyWith(rules: updatedRules);
  }

  void addRule(String keyword, String response) {
    final newRule = ChatbotRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      keyword: keyword,
      response: response,
    );
    state = state.copyWith(rules: [...state.rules, newRule]);
  }

  void deleteRule(String id) {
    final updatedRules = state.rules.where((rule) => rule.id != id).toList();
    state = state.copyWith(rules: updatedRules);
  }

  void clearRules() {
    state = state.copyWith(rules: []);
  }

  void updateAiConfig(String model, String prompt, double temp) {
    state = state.copyWith(
      aiModel: model,
      systemPrompt: prompt,
      temperature: temp,
    );
  }

  void addKnowledgeDocument(String name) {
    state = state.copyWith(
      knowledgeDocuments: [...state.knowledgeDocuments, name],
    );
  }

  void removeKnowledgeDocument(String name) {
    final updatedDocs = state.knowledgeDocuments
        .where((doc) => doc != name)
        .toList();
    state = state.copyWith(knowledgeDocuments: updatedDocs);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }
}

final chatbotProvider = StateNotifierProvider<ChatbotNotifier, ChatbotState>((
  ref,
) {
  return ChatbotNotifier();
});
