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
const chatbotDefaultSystemPrompt =
    'Bạn là một người hỗ trợ tư vấn khách hàng Zalo. Hãy phản hồi tự nhiên, ngắn gọn và đời thường như một người thật, tránh viết quá dài (dưới 40 từ). Đặc biệt: CHỈ gửi lời chào (như Chào bạn, Dạ chào anh/chị) ở câu đầu tiên của cuộc hội thoại, từ các câu tiếp theo tuyệt đối không lặp lại câu chào hỏi nữa mà trả lời thẳng vào vấn đề.';
const chatbotDefaultSoul =
    'Bạn là nhân viên tư vấn Zalo của doanh nghiệp: chuyên nghiệp, gần gũi, hiểu sản phẩm/dịch vụ, không tiết lộ mình là AI, không nói về hệ thống nội bộ.';
const chatbotDefaultResponseRules =
    '- Trả lời bằng tiếng Việt theo ngôn ngữ của khách.\n'
    '- Không bịa thông tin ngoài kho kiến thức; nếu thiếu dữ liệu thì đề nghị chuyển nhân viên.\n'
    '- Không gửi mật khẩu, token, cookie hoặc dữ liệu nhạy cảm.\n'
    '- Khi cần gửi file/ảnh, chỉ nêu đúng tài liệu phù hợp trong kho kiến thức để agent Zalo gửi.';

String normalizeChatbotAiModel(String value) {
  return chatbotAiModels.contains(value) ? value : chatbotDefaultAiModel;
}

class ChatbotRule {
  final String id;
  final String name;
  final String description;
  final String keyword;
  final String response;
  final bool isActive;

  const ChatbotRule({
    required this.id,
    required this.name,
    required this.description,
    required this.keyword,
    required this.response,
    this.isActive = true,
  });

  ChatbotRule copyWith({
    String? id,
    String? name,
    String? description,
    String? keyword,
    String? response,
    bool? isActive,
  }) {
    return ChatbotRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
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
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
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
  final String soulPrompt;
  final String responseRules;
  final double temperature;
  final bool aiEnabled;
  final String personalAudience;
  final String groupAudience;
  final List<String> knowledgeDocuments;
  final List<ChatbotLogRecord> logs;
  final bool isLoading;
  final String? errorMessage;

  const ChatbotState({
    required this.activeTab,
    required this.rules,
    required this.aiModel,
    required this.systemPrompt,
    required this.soulPrompt,
    required this.responseRules,
    required this.temperature,
    required this.aiEnabled,
    required this.personalAudience,
    required this.groupAudience,
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
      systemPrompt: chatbotDefaultSystemPrompt,
      soulPrompt: chatbotDefaultSoul,
      responseRules: chatbotDefaultResponseRules,
      temperature: 0.7,
      aiEnabled: true,
      personalAudience: 'all',
      groupAudience: 'none',
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
    String? soulPrompt,
    String? responseRules,
    double? temperature,
    bool? aiEnabled,
    String? personalAudience,
    String? groupAudience,
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
      soulPrompt: soulPrompt ?? this.soulPrompt,
      responseRules: responseRules ?? this.responseRules,
      temperature: temperature ?? this.temperature,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      personalAudience: personalAudience ?? this.personalAudience,
      groupAudience: groupAudience ?? this.groupAudience,
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
      soulPrompt: (json['soulPrompt'] ?? state.soulPrompt).toString(),
      responseRules: (json['responseRules'] ?? state.responseRules).toString(),
      temperature:
          double.tryParse(
            (json['temperature'] ?? state.temperature).toString(),
          ) ??
          state.temperature,
      aiEnabled: json['aiEnabled'] != false,
      personalAudience: (json['personalAudience'] ?? state.personalAudience)
          .toString(),
      groupAudience: (json['groupAudience'] ?? state.groupAudience).toString(),
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

  Future<void> addRule(
    String keyword,
    String response, {
    String? name,
    String? description,
  }) async {
    if (keyword.trim().isEmpty || response.trim().isEmpty) return;
    if (_isCreatingRule) return;
    _isCreatingRule = true;
    final result = await _repository.createRule(
      name: name?.trim().isNotEmpty == true ? name!.trim() : keyword.trim(),
      description: description?.trim(),
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

  Map<String, dynamic> _settingsPayload({
    String? aiModel,
    String? systemPrompt,
    String? soulPrompt,
    String? responseRules,
    double? temperature,
    bool? aiEnabled,
    String? personalAudience,
    String? groupAudience,
    List<String>? knowledgeDocuments,
  }) {
    return {
      'aiEnabled': aiEnabled ?? state.aiEnabled,
      'aiModel': aiModel ?? state.aiModel,
      'systemPrompt': systemPrompt ?? state.systemPrompt,
      'soulPrompt': soulPrompt ?? state.soulPrompt,
      'responseRules': responseRules ?? state.responseRules,
      'temperature': temperature ?? state.temperature,
      'personalAudience': personalAudience ?? state.personalAudience,
      'groupAudience': groupAudience ?? state.groupAudience,
      'knowledgeSnippets': knowledgeDocuments ?? state.knowledgeDocuments,
    };
  }

  Future<void> updateAiConfig({
    required String model,
    required String prompt,
    required String soulPrompt,
    required String responseRules,
    required double temperature,
  }) async {
    state = state.copyWith(
      aiModel: normalizeChatbotAiModel(model),
      systemPrompt: prompt,
      soulPrompt: soulPrompt,
      responseRules: responseRules,
      temperature: temperature,
    );
    final response = await _repository.saveSettings(_settingsPayload());
    if (response['success'] != true) {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Lưu cấu hình thất bại.')
            .toString(),
      );
    }
  }

  Future<void> setAiEnabled(bool enabled) async {
    state = state.copyWith(aiEnabled: enabled);
    await _repository.saveSettings(_settingsPayload());
  }

  Future<void> updateAudienceConfig({
    String? personalAudience,
    String? groupAudience,
  }) async {
    state = state.copyWith(
      personalAudience: personalAudience,
      groupAudience: groupAudience,
    );
    await _repository.saveSettings(_settingsPayload());
  }

  Future<void> addKnowledgeDocument(String name) async {
    final documents = [...state.knowledgeDocuments, name];
    state = state.copyWith(knowledgeDocuments: documents);
    await _repository.saveSettings(
      _settingsPayload(knowledgeDocuments: documents),
    );
  }

  Future<void> removeKnowledgeDocument(String name) async {
    final documents = state.knowledgeDocuments
        .where((doc) => doc != name)
        .toList();
    state = state.copyWith(knowledgeDocuments: documents);
    await _repository.saveSettings(
      _settingsPayload(knowledgeDocuments: documents),
    );
  }

  Future<Map<String, dynamic>> uploadKnowledgeFile({
    required String filename,
    required List<int> bytes,
    required String contentType,
  }) {
    return _repository.uploadKnowledgeFile(
      filename: filename,
      bytes: bytes,
      contentType: contentType,
    );
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
