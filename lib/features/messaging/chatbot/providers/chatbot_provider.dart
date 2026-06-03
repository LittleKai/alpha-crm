import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chatbot_repository.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  return ChatbotRepository();
});

const chatbotAiModels = [
  'gemini-3-flash-preview',
  'gemini-2.5-pro',
  'gemini-3.1-pro-preview',
];
const chatbotDefaultAiModel = 'gemini-3-flash-preview';

String normalizeChatbotAiModel(String value) {
  return chatbotAiModels.contains(value) ? value : chatbotDefaultAiModel;
}

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

  static ChatbotRule fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'];
    final keywords = rawKeywords is List
        ? rawKeywords
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];
    return ChatbotRule(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      keyword: keywords.isNotEmpty
          ? keywords.join(', ')
          : (json['name'] ?? '').toString(),
      response: (json['response'] ?? '').toString(),
      isActive: json['isActive'] != false,
    );
  }
}

class ChatbotLogRecord {
  final String id;
  final String customerName;
  final String keyword;
  final String response;
  final DateTime timestamp;
  final String status;

  const ChatbotLogRecord({
    required this.id,
    required this.customerName,
    required this.keyword,
    required this.response,
    required this.timestamp,
    required this.status,
  });

  static ChatbotLogRecord fromJson(Map<String, dynamic> json) {
    return ChatbotLogRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      customerName: (json['conversationId'] ?? 'Chatbot').toString(),
      keyword: (json['mode'] ?? '').toString(),
      response: (json['responsePreview'] ?? json['errorMessage'] ?? '')
          .toString(),
      timestamp:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      status: (json['status'] ?? '').toString() == 'succeeded'
          ? 'Thành công'
          : (json['status'] ?? '').toString(),
    );
  }
}

class ChatbotState {
  final int activeTab;
  final List<ChatbotRule> rules;
  final String aiModel;
  final String systemPrompt;
  final double temperature;
  final bool aiEnabled;
  final List<String> knowledgeDocuments;
  final List<ChatbotLogRecord> logs;
  final bool isLoading;
  final String? errorMessage;

  const ChatbotState({
    required this.activeTab,
    required this.rules,
    required this.aiModel,
    required this.systemPrompt,
    required this.temperature,
    required this.aiEnabled,
    required this.knowledgeDocuments,
    required this.logs,
    required this.isLoading,
    this.errorMessage,
  });

  factory ChatbotState.initial() {
    return const ChatbotState(
      activeTab: 0,
      rules: [],
      aiModel: chatbotDefaultAiModel,
      systemPrompt:
          'Bạn là trợ lý CSKH của Alpha CRM. Hãy trả lời thân thiện, ngắn gọn và hướng khách hàng đến tư vấn viên khi cần.',
      temperature: 0.7,
      aiEnabled: true,
      knowledgeDocuments: [],
      logs: [],
      isLoading: false,
      errorMessage: null,
    );
  }

  ChatbotState copyWith({
    int? activeTab,
    List<ChatbotRule>? rules,
    String? aiModel,
    String? systemPrompt,
    double? temperature,
    bool? aiEnabled,
    List<String>? knowledgeDocuments,
    List<ChatbotLogRecord>? logs,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChatbotState(
      activeTab: activeTab ?? this.activeTab,
      rules: rules ?? this.rules,
      aiModel: aiModel ?? this.aiModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      knowledgeDocuments: knowledgeDocuments ?? this.knowledgeDocuments,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  final ChatbotRepository _repository;
  bool _isCreatingRule = false;

  ChatbotNotifier(this._repository) : super(ChatbotState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.wait([loadSettings(), loadRules(), loadLogs()]);
    state = state.copyWith(isLoading: false);
  }

  void setActiveTab(int tab) {
    state = state.copyWith(activeTab: tab);
    if (tab == 3) loadLogs();
  }

  Future<void> loadSettings() async {
    final response = await _repository.getSettings();
    if (response['success'] != true || response['data'] is! Map) return;
    final json = Map<String, dynamic>.from(response['data'] as Map);
    final snippets = json['knowledgeSnippets'] is List
        ? List<String>.from(
            (json['knowledgeSnippets'] as List).map((item) => item.toString()),
          )
        : <String>[];
    state = state.copyWith(
      aiModel: normalizeChatbotAiModel(
        (json['aiModel'] ?? state.aiModel).toString(),
      ),
      systemPrompt: (json['systemPrompt'] ?? state.systemPrompt).toString(),
      temperature:
          double.tryParse(
            (json['temperature'] ?? state.temperature).toString(),
          ) ??
          state.temperature,
      aiEnabled: json['aiEnabled'] != false,
      knowledgeDocuments: snippets,
    );
  }

  Future<void> loadRules() async {
    final response = await _repository.getRules();
    if (response['success'] == true && response['data'] is List) {
      final rules = (response['data'] as List)
          .whereType<Map>()
          .map((item) => ChatbotRule.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      state = state.copyWith(rules: rules);
    }
  }

  Future<void> loadLogs() async {
    final response = await _repository.getLogs();
    if (response['success'] == true && response['data'] is List) {
      final logs = (response['data'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                ChatbotLogRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      state = state.copyWith(logs: logs);
    }
  }

  Future<void> toggleRuleStatus(String id) async {
    ChatbotRule? rule;
    for (final item in state.rules) {
      if (item.id == id) {
        rule = item;
        break;
      }
    }
    if (rule == null) return;
    final next = !rule.isActive;
    state = state.copyWith(
      rules: state.rules
          .map((item) => item.id == id ? item.copyWith(isActive: next) : item)
          .toList(),
    );
    final response = await _repository.updateRule(id, {'isActive': next});
    if (response['success'] != true) await loadRules();
  }

  Future<void> addRule(String keyword, String response) async {
    if (keyword.trim().isEmpty || response.trim().isEmpty) return;
    if (_isCreatingRule) return;
    _isCreatingRule = true;
    final result = await _repository.createRule(
      keyword: keyword.trim(),
      response: response.trim(),
    );
    if (result['success'] == true) {
      await loadRules();
    } else {
      state = state.copyWith(
        errorMessage: (result['message'] ?? 'Tạo kịch bản thất bại.')
            .toString(),
      );
    }
    _isCreatingRule = false;
  }

  Future<void> deleteRule(String id) async {
    final response = await _repository.deleteRule(id);
    if (response['success'] == true) {
      state = state.copyWith(
        rules: state.rules.where((rule) => rule.id != id).toList(),
      );
    }
  }

  Future<void> clearRules() async {
    for (final rule in List<ChatbotRule>.from(state.rules)) {
      await deleteRule(rule.id);
    }
  }

  Future<void> updateAiConfig(String model, String prompt, double temp) async {
    state = state.copyWith(
      aiModel: model,
      systemPrompt: prompt,
      temperature: temp,
    );
    final response = await _repository.saveSettings({
      'aiModel': model,
      'systemPrompt': prompt,
      'temperature': temp,
      'aiEnabled': state.aiEnabled,
      'knowledgeSnippets': state.knowledgeDocuments,
    });
    if (response['success'] != true) {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Lưu cấu hình thất bại.')
            .toString(),
      );
    }
  }

  Future<void> setAiEnabled(bool enabled) async {
    state = state.copyWith(aiEnabled: enabled);
    await _repository.saveSettings({
      'aiEnabled': enabled,
      'aiModel': state.aiModel,
      'systemPrompt': state.systemPrompt,
      'temperature': state.temperature,
      'knowledgeSnippets': state.knowledgeDocuments,
    });
  }

  Future<void> addKnowledgeDocument(String name) async {
    final documents = [...state.knowledgeDocuments, name];
    state = state.copyWith(knowledgeDocuments: documents);
    await _repository.saveSettings({
      'aiEnabled': state.aiEnabled,
      'aiModel': state.aiModel,
      'systemPrompt': state.systemPrompt,
      'temperature': state.temperature,
      'knowledgeSnippets': documents,
    });
  }

  Future<void> removeKnowledgeDocument(String name) async {
    final documents = state.knowledgeDocuments
        .where((doc) => doc != name)
        .toList();
    state = state.copyWith(knowledgeDocuments: documents);
    await _repository.saveSettings({
      'aiEnabled': state.aiEnabled,
      'aiModel': state.aiModel,
      'systemPrompt': state.systemPrompt,
      'temperature': state.temperature,
      'knowledgeSnippets': documents,
    });
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }
}

final chatbotProvider = StateNotifierProvider<ChatbotNotifier, ChatbotState>((
  ref,
) {
  return ChatbotNotifier(ref.read(chatbotRepositoryProvider));
});
