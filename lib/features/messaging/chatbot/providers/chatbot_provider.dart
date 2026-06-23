import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chatbot_repository.dart';
import '../data/chatbot_local_bridge_api.dart';
import '../data/local_ai_key_store.dart';
import '../../../settings/providers/settings_provider.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  return ChatbotRepository();
});
final chatbotLocalBridgeApiProvider = Provider<ChatbotLocalBridgeApi>((ref) {
  final baseUrl = ref.watch(settingsProvider).settings.zaloBackendBaseUrl;
  return ChatbotLocalBridgeApi(baseUrl: baseUrl);
});

const chatbotAiModels = [
  'gemini-3-flash',
  'gemini-2.5-pro',
];
const chatbotDefaultAiModel = 'gemini-3-flash';
const chatbotDefaultSystemPrompt =
    'Bạn là một người hỗ trợ tư vấn khách hàng Zalo. Hãy phản hồi tự nhiên, ngắn gọn và đời thường như một người thật, tránh viết quá dài (dưới 100 từ). Đặc biệt: Chỉ gửi lời chào (như Chào bạn, Dạ chào anh/chị) ở câu đầu tiên của cuộc hội thoại, từ các câu tiếp theo tuyệt đối không lặp lại câu chào hỏi nữa mà trả lời thẳng vào vấn đề.';
const chatbotDefaultSoul =
    'Bạn là nhân viên tư vấn Zalo của doanh nghiệp: chuyên nghiệp, gần gũi, hiểu sản phẩm/dịch vụ, không tiết lộ mình là AI, không nói về hệ thống nội bộ.';
const chatbotDefaultResponseRules =
    '- Trả lời bằng tiếng Việt.\n'
    '- Không bịa thông tin ngoài kho kiến thức; nếu thiếu dữ liệu thì đề nghị chuyển nhân viên.\n'
    '- Không gửi mật khẩu, token, cookie hoặc dữ liệu nhạy cảm.';

/// AI provider configuration for the chatbot.
class ChatbotAiProviderConfig {
  final String id;
  final String label;
  final String keyHint;
  final List<String> presetModels;
  final String defaultModel;
  final bool requiresApiKey;

  const ChatbotAiProviderConfig({
    required this.id,
    required this.label,
    this.keyHint = '',
    required this.presetModels,
    required this.defaultModel,
    this.requiresApiKey = true,
  });
}

const chatbotAiProviderConfigs = <ChatbotAiProviderConfig>[
  ChatbotAiProviderConfig(
    id: 'alpha_studio',
    label: 'Alpha Studio',
    presetModels: ['gemini-3-flash', 'gemini-2.5-pro'],
    defaultModel: 'gemini-3-flash',
    requiresApiKey: false,
  ),
  ChatbotAiProviderConfig(
    id: 'gemini',
    label: 'Google Gemini',
    keyHint: 'AIzaSy...',
    presetModels: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-3-flash-preview', 'gemini-3.1-pro-preview'],
    defaultModel: 'gemini-2.5-flash',
  ),
  ChatbotAiProviderConfig(
    id: 'openai',
    label: 'OpenAI',
    keyHint: 'sk-...',
    presetModels: ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1', 'o4-mini', 'o3'],
    defaultModel: 'gpt-4o-mini',
  ),
  ChatbotAiProviderConfig(
    id: 'deepseek',
    label: 'DeepSeek',
    keyHint: 'sk-...',
    presetModels: ['deepseek-chat', 'deepseek-reasoner'],
    defaultModel: 'deepseek-chat',
  ),
  ChatbotAiProviderConfig(
    id: 'openrouter',
    label: 'OpenRouter',
    keyHint: 'sk-or-...',
    presetModels: ['google/gemini-2.5-flash', 'openai/gpt-4o-mini', 'anthropic/claude-sonnet-4-5'],
    defaultModel: 'google/gemini-2.5-flash',
  ),
];

const chatbotDefaultAiProvider = 'alpha_studio';

ChatbotAiProviderConfig? findProviderConfig(String id) {
  for (final p in chatbotAiProviderConfigs) {
    if (p.id == id) return p;
  }
  return null;
}

String normalizeChatbotAiModel(String value) {
  return value.isNotEmpty ? value : chatbotDefaultAiModel;
}

int _normalizeDebounceSeconds(Object? value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  return (parsed ?? 20).clamp(10, 120);
}

int _normalizeAiHistoryLimit(Object? value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  return (parsed ?? 5).clamp(0, 20);
}

Map<String, List<String>> _parseAiApiKeys(Object? value) {
  if (value is! Map) return {};
  final result = <String, List<String>>{};
  for (final entry in value.entries) {
    final key = entry.key.toString();
    if (entry.value is List) {
      final keys = (entry.value as List)
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
      if (keys.isNotEmpty) result[key] = keys;
    }
  }
  return result;
}

class ChatbotRule {
  final String id;
  final String name;
  final String description;
  final String keyword;
  final String response;
  final bool isActive;

  /// Zalo account ids this rule applies to. Empty = all accounts.
  final List<String> accountIds;

  const ChatbotRule({
    required this.id,
    required this.name,
    required this.description,
    required this.keyword,
    required this.response,
    this.isActive = true,
    this.accountIds = const [],
  });

  ChatbotRule copyWith({
    String? id,
    String? name,
    String? description,
    String? keyword,
    String? response,
    bool? isActive,
    List<String>? accountIds,
  }) {
    return ChatbotRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      keyword: keyword ?? this.keyword,
      response: response ?? this.response,
      isActive: isActive ?? this.isActive,
      accountIds: accountIds ?? this.accountIds,
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
      accountIds: json['accountIds'] is List
          ? (json['accountIds'] as List)
                .map((item) => item.toString())
                .where((item) => item.isNotEmpty)
                .toList()
          : <String>[],
    );
  }
}

/// Maps a chatbot skip/handoff/fail reason code (stored by the bridge in the
/// audit `reason`/`error`) to a human-readable Vietnamese explanation. Returns
/// the raw value unchanged if it is not a known code (e.g. a real error text).
String friendlyChatbotReason(String raw) {
  switch (raw) {
    case 'global_disabled':
      return 'Chatbot đang tắt.';
    case 'no_eligible_messages':
      return 'Không có tin nhắn hợp lệ (vd: tin không phải văn bản, hoặc đã xử lý).';
    case 'no_matching_rule':
      return 'Không khớp kịch bản từ khóa nào và AI đang tắt.';
    case 'personal_audience':
      return 'Ngoài phạm vi đối tượng cá nhân đã chọn.';
    case 'group_audience':
      return 'Ngoài phạm vi nhóm đã chọn.';
    case 'group_trigger':
      return 'Trong nhóm bot chỉ trả lời khi được nhắc tên hoặc trả lời tin của bot.';
    case 'handoff_keyword':
      return 'Phát hiện từ khóa chuyển nhân viên.';
    case 'send_failed':
      return 'Gửi tin nhắn thất bại.';
    case 'ai_failed':
      return 'AI tạo câu trả lời thất bại.';
  }
  if (raw.startsWith('conversation_')) {
    return 'Hội thoại đang được giao cho nhân viên (không tự động trả lời).';
  }
  return raw;
}

class ChatbotLogRecord {
  final String id;
  final String customerName;
  final String keyword;
  final String response;
  final DateTime timestamp;

  /// Raw status from the cloud: `succeeded` | `failed` | `skipped`.
  final String status;
  final String accountId;
  final String threadId;

  /// 'chatbot' (auto-reply) or 'group_summary' (group AI summary).
  final String kind;
  final int tokenIn;
  final int tokenOut;

  const ChatbotLogRecord({
    required this.id,
    required this.customerName,
    required this.keyword,
    required this.response,
    required this.timestamp,
    required this.status,
    this.accountId = '',
    this.threadId = '',
    this.kind = 'chatbot',
    this.tokenIn = 0,
    this.tokenOut = 0,
  });

  ChatbotLogRecord copyWith({String? customerName}) {
    return ChatbotLogRecord(
      id: id,
      customerName: customerName ?? this.customerName,
      keyword: keyword,
      response: response,
      timestamp: timestamp,
      status: status,
      accountId: accountId,
      threadId: threadId,
      kind: kind,
      tokenIn: tokenIn,
      tokenOut: tokenOut,
    );
  }

  static ChatbotLogRecord fromJson(Map<String, dynamic> json) {
    final preview = (json['responsePreview'] ?? '').toString().trim();
    final errorMsg = (json['errorMessage'] ?? '').toString().trim();
    // `??` does not fall through on empty strings, so an empty responsePreview
    // would previously hide the skip reason stored in errorMessage.
    final response = preview.isNotEmpty
        ? preview
        : friendlyChatbotReason(errorMsg);
    return ChatbotLogRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      customerName: '',
      keyword: (json['mode'] ?? '').toString(),
      response: response,
      // createdAt is a UTC ISO string; convert to the machine's local time.
      timestamp:
          DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      status: (json['status'] ?? '').toString(),
      accountId: (json['accountId'] ?? '').toString(),
      threadId: (json['threadId'] ?? '').toString(),
      kind: (json['kind'] ?? 'chatbot').toString(),
      tokenIn: int.tryParse((json['tokenIn'] ?? 0).toString()) ?? 0,
      tokenOut: int.tryParse((json['tokenOut'] ?? 0).toString()) ?? 0,
    );
  }
}

class ChatbotState {
  final int activeTab;
  final List<ChatbotRule> rules;
  final String aiProvider;
  final String aiModel;
  final String systemPrompt;
  final String soulPrompt;
  final String responseRules;
  final double temperature;
  final int debounceSeconds;

  /// Number of recent conversation turns the AI reads as context (0–20).
  final int aiHistoryLimit;
  final bool aiEnabled;

  /// Master switch for keyword scenarios. When false, no keyword rule runs.
  final bool keywordRulesEnabled;
  final String personalAudience;
  final String groupAudience;
  final List<String> selectedGroupKeys;
  final List<String> knowledgeDocuments;
  final List<ChatbotLogRecord> logs;
  final bool isLoading;
  final String? errorMessage;
  final ChatbotBridgeStatus? bridgeStatus;
  final bool isSyncingBridge;
  final String? bridgeSyncWarning;
  final Map<String, List<String>> aiApiKeys;

  const ChatbotState({
    required this.activeTab,
    required this.rules,
    required this.aiProvider,
    required this.aiModel,
    required this.systemPrompt,
    required this.soulPrompt,
    required this.responseRules,
    required this.temperature,
    required this.debounceSeconds,
    this.aiHistoryLimit = 5,
    required this.aiEnabled,
    this.keywordRulesEnabled = true,
    required this.personalAudience,
    required this.groupAudience,
    this.selectedGroupKeys = const [],
    required this.knowledgeDocuments,
    required this.logs,
    required this.isLoading,
    this.errorMessage,
    this.bridgeStatus,
    this.isSyncingBridge = false,
    this.bridgeSyncWarning,
    this.aiApiKeys = const {},
  });

  factory ChatbotState.initial() {
    return const ChatbotState(
      activeTab: 0,
      rules: [],
      aiProvider: chatbotDefaultAiProvider,
      aiModel: chatbotDefaultAiModel,
      systemPrompt: chatbotDefaultSystemPrompt,
      soulPrompt: chatbotDefaultSoul,
      responseRules: chatbotDefaultResponseRules,
      temperature: 0.7,
      debounceSeconds: 20,
      aiHistoryLimit: 5,
      aiEnabled: false,
      keywordRulesEnabled: true,
      personalAudience: 'all',
      groupAudience: 'tagOnly',
      selectedGroupKeys: [],
      knowledgeDocuments: [],
      logs: [],
      isLoading: false,
      errorMessage: null,
      bridgeStatus: null,
      isSyncingBridge: false,
      bridgeSyncWarning: null,
    );
  }

  ChatbotState copyWith({
    int? activeTab,
    List<ChatbotRule>? rules,
    String? aiProvider,
    String? aiModel,
    String? systemPrompt,
    String? soulPrompt,
    String? responseRules,
    double? temperature,
    int? debounceSeconds,
    int? aiHistoryLimit,
    bool? aiEnabled,
    bool? keywordRulesEnabled,
    String? personalAudience,
    String? groupAudience,
    List<String>? selectedGroupKeys,
    List<String>? knowledgeDocuments,
    List<ChatbotLogRecord>? logs,
    bool? isLoading,
    String? errorMessage,
    ChatbotBridgeStatus? bridgeStatus,
    bool? isSyncingBridge,
    String? bridgeSyncWarning,
    Map<String, List<String>>? aiApiKeys,
  }) {
    return ChatbotState(
      activeTab: activeTab ?? this.activeTab,
      rules: rules ?? this.rules,
      aiProvider: aiProvider ?? this.aiProvider,
      aiModel: aiModel ?? this.aiModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      soulPrompt: soulPrompt ?? this.soulPrompt,
      responseRules: responseRules ?? this.responseRules,
      temperature: temperature ?? this.temperature,
      debounceSeconds: debounceSeconds ?? this.debounceSeconds,
      aiHistoryLimit: aiHistoryLimit ?? this.aiHistoryLimit,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      keywordRulesEnabled: keywordRulesEnabled ?? this.keywordRulesEnabled,
      personalAudience: personalAudience ?? this.personalAudience,
      groupAudience: groupAudience ?? this.groupAudience,
      selectedGroupKeys: selectedGroupKeys ?? this.selectedGroupKeys,
      knowledgeDocuments: knowledgeDocuments ?? this.knowledgeDocuments,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      bridgeStatus: bridgeStatus ?? this.bridgeStatus,
      isSyncingBridge: isSyncingBridge ?? this.isSyncingBridge,
      bridgeSyncWarning: bridgeSyncWarning,
      aiApiKeys: aiApiKeys ?? this.aiApiKeys,
    );
  }
}

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  final ChatbotRepository _repository;
  final ChatbotLocalBridgeApi _bridge;
  bool _isCreatingRule = false;

  ChatbotNotifier(this._repository, {ChatbotLocalBridgeApi? bridge})
    : _bridge = bridge ?? ChatbotLocalBridgeApi(),
      super(ChatbotState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.wait([
      loadSettings(),
      loadRules(),
      loadLogs(),
      loadBridgeStatus(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadBridgeStatus() async {
    try {
      final status = await _bridge.getStatus();
      state = state.copyWith(
        bridgeStatus: status,
        bridgeSyncWarning: status.lastError,
      );
    } catch (error) {
      state = state.copyWith(bridgeSyncWarning: error.toString());
    }
  }

  Future<void> syncBridgeNow() async {
    state = state.copyWith(isSyncingBridge: true, bridgeSyncWarning: null);
    try {
      final status = await _bridge.syncNow();
      state = state.copyWith(
        isSyncingBridge: false,
        bridgeStatus: status,
        bridgeSyncWarning: status.lastError,
      );
    } catch (error) {
      state = state.copyWith(
        isSyncingBridge: false,
        bridgeSyncWarning: error.toString(),
      );
    }
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
    final selectedGroupKeys = json['selectedGroupKeys'] is List
        ? List<String>.from(
            (json['selectedGroupKeys'] as List).map((item) => item.toString()),
          )
        : <String>[];
    state = state.copyWith(
      aiProvider: (json['aiProvider'] ?? state.aiProvider).toString(),
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
      debounceSeconds: _normalizeDebounceSeconds(json['debounceSeconds']),
      aiHistoryLimit: _normalizeAiHistoryLimit(json['aiHistoryLimit']),
      aiEnabled: json['aiEnabled'] != false,
      keywordRulesEnabled: json['keywordRulesEnabled'] != false,
      personalAudience: (json['personalAudience'] ?? state.personalAudience)
          .toString(),
      groupAudience: (json['groupAudience'] ?? state.groupAudience).toString(),
      selectedGroupKeys: selectedGroupKeys,
      knowledgeDocuments: snippets,
      aiApiKeys: await LocalAiKeyStore.loadKeys(),
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
      var logs = (response['data'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                ChatbotLogRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      // The cloud audit only stores account/thread ids, so resolve real
      // customer names from the local conversation store (desktop only).
      final names = await _bridge.getConversationNames();
      logs = logs
          .map(
            (log) => log.copyWith(
              customerName: names[log.threadId] ??
                  (log.threadId.isNotEmpty ? log.threadId : 'Khách hàng'),
            ),
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
    if (response['success'] != true) {
      await loadRules();
    } else {
      await syncBridgeNow();
    }
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
      await syncBridgeNow();
    } else {
      state = state.copyWith(
        errorMessage: (result['message'] ?? 'Tạo kịch bản thất bại.')
            .toString(),
      );
    }
    _isCreatingRule = false;
  }

  Future<void> updateRule(
    String id, {
    required String keyword,
    required String response,
    String? name,
    String? description,
  }) async {
    if (keyword.trim().isEmpty || response.trim().isEmpty) return;
    final keywords = keyword
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final result = await _repository.updateRule(id, {
      'name': name?.trim().isNotEmpty == true ? name!.trim() : keyword.trim(),
      'description': description?.trim() ?? '',
      'keywords': keywords.isEmpty ? [keyword] : keywords,
      'response': response.trim(),
    });
    if (result['success'] == true) {
      await loadRules();
      await syncBridgeNow();
    } else {
      state = state.copyWith(
        errorMessage: (result['message'] ?? 'Cập nhật kịch bản thất bại.')
            .toString(),
      );
    }
  }


  /// Scope a keyword rule to specific Zalo accounts (empty = all accounts).
  Future<void> updateRuleAccounts(String id, List<String> accountIds) async {
    state = state.copyWith(
      rules: state.rules
          .map((rule) =>
              rule.id == id ? rule.copyWith(accountIds: accountIds) : rule)
          .toList(),
    );
    final response = await _repository.updateRule(id, {'accountIds': accountIds});
    if (response['success'] != true) {
      await loadRules();
    } else {
      await syncBridgeNow();
    }
  }

  Future<void> deleteRule(String id) async {
    final response = await _repository.deleteRule(id);
    if (response['success'] == true) {
      state = state.copyWith(
        rules: state.rules.where((rule) => rule.id != id).toList(),
      );
      await syncBridgeNow();
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
    int? debounceSeconds,
    int? aiHistoryLimit,
    bool? aiEnabled,
    String? personalAudience,
    String? groupAudience,
    List<String>? selectedGroupKeys,
    List<String>? knowledgeDocuments,
  }) {
    return {
      'aiEnabled': aiEnabled ?? state.aiEnabled,
      'aiProvider': state.aiProvider,
      'aiModel': aiModel ?? state.aiModel,
      'systemPrompt': systemPrompt ?? state.systemPrompt,
      'soulPrompt': soulPrompt ?? state.soulPrompt,
      'responseRules': responseRules ?? state.responseRules,
      'temperature': temperature ?? state.temperature,
      'debounceSeconds': debounceSeconds ?? state.debounceSeconds,
      'aiHistoryLimit': aiHistoryLimit ?? state.aiHistoryLimit,
      'keywordRulesEnabled': state.keywordRulesEnabled,
      'personalAudience': personalAudience ?? state.personalAudience,
      'groupAudience': groupAudience ?? state.groupAudience,
      'selectedGroupKeys': selectedGroupKeys ?? state.selectedGroupKeys,
      'knowledgeSnippets': knowledgeDocuments ?? state.knowledgeDocuments,
    };
  }

  Future<void> updateAiConfig({
    required String provider,
    required String model,
    required String prompt,
    required String soulPrompt,
    required String responseRules,
    required double temperature,
    required int debounceSeconds,
    required int aiHistoryLimit,
  }) async {
    state = state.copyWith(
      aiProvider: provider,
      aiModel: normalizeChatbotAiModel(model),
      systemPrompt: prompt,
      soulPrompt: soulPrompt,
      responseRules: responseRules,
      temperature: temperature,
      debounceSeconds: _normalizeDebounceSeconds(debounceSeconds),
      aiHistoryLimit: _normalizeAiHistoryLimit(aiHistoryLimit),
    );
    final response = await _repository.saveSettings(_settingsPayload());
    if (response['success'] != true) {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Lưu cấu hình thất bại.')
            .toString(),
      );
    } else {
      await syncBridgeNow();
    }
  }

  Future<void> setAiEnabled(bool enabled) async {
    state = state.copyWith(aiEnabled: enabled);
    final response = await _repository.saveSettings(_settingsPayload());
    if (response['success'] == true) await syncBridgeNow();
  }

  /// Master switch for the keyword-scenarios tab. When off, no keyword rule runs.
  Future<void> setKeywordRulesEnabled(bool enabled) async {
    state = state.copyWith(keywordRulesEnabled: enabled);
    final response = await _repository.saveSettings(_settingsPayload());
    if (response['success'] == true) await syncBridgeNow();
  }

  Future<void> updateAiApiKeys(Map<String, List<String>> keys) async {
    state = state.copyWith(aiApiKeys: keys);
    await LocalAiKeyStore.saveKeys(keys);
    // Keys stay local, no need to send settings payload to cloud for keys.
    await syncBridgeNow();
  }

  Future<void> updateAudienceConfig({
    String? personalAudience,
    String? groupAudience,
    List<String>? selectedGroupKeys,
  }) async {
    state = state.copyWith(
      personalAudience: personalAudience,
      groupAudience: groupAudience,
      selectedGroupKeys: selectedGroupKeys,
    );
    final response = await _repository.saveSettings(_settingsPayload());
    if (response['success'] == true) await syncBridgeNow();
  }

  Future<void> addKnowledgeDocument(String name) async {
    final documents = [...state.knowledgeDocuments, name];
    state = state.copyWith(knowledgeDocuments: documents);
    await _repository.saveSettings(
      _settingsPayload(knowledgeDocuments: documents),
    );
    await syncBridgeNow();
  }

  Future<void> removeKnowledgeDocument(String name) async {
    final documents = state.knowledgeDocuments
        .where((doc) => doc != name)
        .toList();
    state = state.copyWith(knowledgeDocuments: documents);
    await _repository.saveSettings(
      _settingsPayload(knowledgeDocuments: documents),
    );
    await syncBridgeNow();
  }

  Future<void> updateKnowledgeDocument(int index, String name) async {
    if (index < 0 || index >= state.knowledgeDocuments.length) return;
    final documents = List<String>.from(state.knowledgeDocuments);
    documents[index] = name;
    state = state.copyWith(knowledgeDocuments: documents);
    await _repository.saveSettings(
      _settingsPayload(knowledgeDocuments: documents),
    );
    await syncBridgeNow();
  }


  /// Upload an operator-attached knowledge file to the LOCAL bridge store. The
  /// bytes never leave this machine; only the content-hash id goes into config.
  Future<Map<String, dynamic>> uploadKnowledgeFile({
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      final data = await _bridge.uploadKnowledgeFile(
        filename: filename,
        bytes: bytes,
      );
      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Ids of knowledge files present on this machine, for "missing file" warnings.
  Future<Set<String>> knowledgeFileIdsPresent() {
    return _bridge.listKnowledgeFileIds();
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }
}

final chatbotProvider = StateNotifierProvider<ChatbotNotifier, ChatbotState>((
  ref,
) {
  return ChatbotNotifier(
    ref.read(chatbotRepositoryProvider),
    bridge: ref.read(chatbotLocalBridgeApiProvider),
  );
});
