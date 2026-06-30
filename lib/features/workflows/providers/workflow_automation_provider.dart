import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/providers/settings_provider.dart';
import '../data/workflow_automation_api.dart';
import '../data/workflow_models.dart';
import '../data/workflow_templates.dart';

class N8nSettingsState {
  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String eventWebhookUrl;
  final String callbackUrl;

  const N8nSettingsState({
    this.enabled = false,
    this.baseUrl = '',
    this.apiKey = '',
    this.eventWebhookUrl = '',
    this.callbackUrl = '',
  });

  N8nSettingsState copyWith({
    bool? enabled,
    String? baseUrl,
    String? apiKey,
    String? eventWebhookUrl,
    String? callbackUrl,
  }) {
    return N8nSettingsState(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      eventWebhookUrl: eventWebhookUrl ?? this.eventWebhookUrl,
      callbackUrl: callbackUrl ?? this.callbackUrl,
    );
  }
}

class EmailSettingsState {
  final bool enabled;
  final String mode;
  final String fromName;
  final String fromAddress;
  final String smtpHost;
  final int smtpPort;
  final bool smtpSecure;
  final String smtpUsername;
  final String smtpPassword;
  final bool inboundEnabled;
  final String imapHost;
  final int imapPort;
  final bool imapSecure;
  final String imapUsername;
  final String imapPassword;

  const EmailSettingsState({
    this.enabled = false,
    this.mode = 'transactional',
    this.fromName = '',
    this.fromAddress = '',
    this.smtpHost = '',
    this.smtpPort = 587,
    this.smtpSecure = false,
    this.smtpUsername = '',
    this.smtpPassword = '',
    this.inboundEnabled = false,
    this.imapHost = '',
    this.imapPort = 993,
    this.imapSecure = true,
    this.imapUsername = '',
    this.imapPassword = '',
  });

  factory EmailSettingsState.fromJson(Map<dynamic, dynamic> json) {
    return EmailSettingsState(
      enabled: json['enabled'] == true,
      mode: json['mode']?.toString() == 'inbox' ? 'inbox' : 'transactional',
      fromName: json['fromName']?.toString() ?? '',
      fromAddress: json['fromAddress']?.toString() ?? '',
      smtpHost: json['smtpHost']?.toString() ?? '',
      smtpPort: int.tryParse(json['smtpPort']?.toString() ?? '') ?? 587,
      smtpSecure: json['smtpSecure'] == true,
      smtpUsername: json['smtpUsername']?.toString() ?? '',
      smtpPassword: json['smtpPassword']?.toString() ?? '',
      inboundEnabled: json['inboundEnabled'] == true,
      imapHost: json['imapHost']?.toString() ?? '',
      imapPort: int.tryParse(json['imapPort']?.toString() ?? '') ?? 993,
      imapSecure: json['imapSecure'] != false,
      imapUsername: json['imapUsername']?.toString() ?? '',
      imapPassword: json['imapPassword']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'mode': mode,
      'fromName': fromName,
      'fromAddress': fromAddress,
      'smtpHost': smtpHost,
      'smtpPort': smtpPort,
      'smtpSecure': smtpSecure,
      'smtpUsername': smtpUsername,
      'smtpPassword': smtpPassword,
      'inboundEnabled': inboundEnabled,
      'imapHost': imapHost,
      'imapPort': imapPort,
      'imapSecure': imapSecure,
      'imapUsername': imapUsername,
      'imapPassword': imapPassword,
    };
  }
}

class FacebookSettingsState {
  final bool enabled;
  final String status;
  final String pageName;
  final String pageId;
  final String appId;
  final String webhookCallbackUrl;
  final String verifyToken;
  final String pageAccessToken;
  final bool enforce24hWindow;

  const FacebookSettingsState({
    this.enabled = false,
    this.status = 'cloud_required',
    this.pageName = '',
    this.pageId = '',
    this.appId = '',
    this.webhookCallbackUrl = '',
    this.verifyToken = '',
    this.pageAccessToken = '',
    this.enforce24hWindow = true,
  });

  factory FacebookSettingsState.fromJson(Map<dynamic, dynamic> json) {
    return FacebookSettingsState(
      enabled: json['enabled'] == true,
      status: json['status']?.toString() ?? 'cloud_required',
      pageName: json['pageName']?.toString() ?? '',
      pageId: json['pageId']?.toString() ?? '',
      appId: json['appId']?.toString() ?? '',
      webhookCallbackUrl: json['webhookCallbackUrl']?.toString() ?? '',
      verifyToken: json['verifyToken']?.toString() ?? '',
      pageAccessToken: json['pageAccessToken']?.toString() ?? '',
      enforce24hWindow: json['enforce24hWindow'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'status': enabled ? 'configured' : status,
      'pageName': pageName,
      'pageId': pageId,
      'appId': appId,
      'webhookCallbackUrl': webhookCallbackUrl,
      'verifyToken': verifyToken,
      'pageAccessToken': pageAccessToken,
      'enforce24hWindow': enforce24hWindow,
    };
  }
}

class AutomationRule {
  final String id;
  final String name;
  final String event;
  final String conditionField;
  final String conditionOperator;
  final String conditionValue;
  final List<String> actions;
  final bool enabled;
  final DateTime createdAt;

  const AutomationRule({
    required this.id,
    required this.name,
    required this.event,
    required this.conditionField,
    required this.conditionOperator,
    required this.conditionValue,
    required this.actions,
    required this.enabled,
    required this.createdAt,
  });

  AutomationRule copyWith({
    String? name,
    String? event,
    String? conditionField,
    String? conditionOperator,
    String? conditionValue,
    List<String>? actions,
    bool? enabled,
  }) {
    return AutomationRule(
      id: id,
      name: name ?? this.name,
      event: event ?? this.event,
      conditionField: conditionField ?? this.conditionField,
      conditionOperator: conditionOperator ?? this.conditionOperator,
      conditionValue: conditionValue ?? this.conditionValue,
      actions: actions ?? this.actions,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }
}

final _defaultAutomationRules = [
  AutomationRule(
    id: 'rule_hot_price_request',
    name: 'Gắn nhãn khách hỏi báo giá',
    event: 'Tin nhắn mới',
    conditionField: 'Nội dung tin nhắn',
    conditionOperator: 'chứa',
    conditionValue: 'báo giá',
    actions: const ['Gắn nhãn: khách nóng', 'Tạo ghi chú chăm sóc'],
    enabled: true,
    createdAt: DateTime(2026, 6, 1),
  ),
  AutomationRule(
    id: 'rule_high_budget',
    name: 'Đẩy ưu tiên khách ngân sách cao',
    event: 'Cập nhật custom attribute',
    conditionField: 'Ngân sách',
    conditionOperator: 'lớn hơn',
    conditionValue: '100 triệu',
    actions: const ['Gắn nhãn: VIP', 'Thông báo nhân viên phụ trách'],
    enabled: false,
    createdAt: DateTime(2026, 6, 2),
  ),
];

class WorkflowAutomationState {
  final List<WorkflowTemplate> templates;
  final List<AutomationRule> automationRules;
  final WorkflowTemplateCategory? selectedCategory;
  final CrmChannel? selectedChannel;
  final String searchQuery;
  final N8nSettingsState n8n;
  final EmailSettingsState email;
  final FacebookSettingsState facebook;
  final bool isLoading;
  final String? errorText;
  final String? statusText;

  const WorkflowAutomationState({
    this.templates = workflowTemplateCatalog,
    this.automationRules = const [],
    this.selectedCategory,
    this.selectedChannel,
    this.searchQuery = '',
    this.n8n = const N8nSettingsState(),
    this.email = const EmailSettingsState(),
    this.facebook = const FacebookSettingsState(),
    this.isLoading = false,
    this.errorText,
    this.statusText,
  });

  List<WorkflowTemplate> get filteredTemplates {
    return filterWorkflowTemplates(
      templates,
      category: selectedCategory,
      channel: selectedChannel,
      searchQuery: searchQuery,
    );
  }

  WorkflowAutomationState copyWith({
    List<WorkflowTemplate>? templates,
    List<AutomationRule>? automationRules,
    WorkflowTemplateCategory? selectedCategory,
    bool clearSelectedCategory = false,
    CrmChannel? selectedChannel,
    bool clearSelectedChannel = false,
    String? searchQuery,
    N8nSettingsState? n8n,
    EmailSettingsState? email,
    FacebookSettingsState? facebook,
    bool? isLoading,
    String? errorText,
    String? statusText,
  }) {
    return WorkflowAutomationState(
      templates: templates ?? this.templates,
      automationRules: automationRules ?? this.automationRules,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      selectedChannel: clearSelectedChannel
          ? null
          : (selectedChannel ?? this.selectedChannel),
      searchQuery: searchQuery ?? this.searchQuery,
      n8n: n8n ?? this.n8n,
      email: email ?? this.email,
      facebook: facebook ?? this.facebook,
      isLoading: isLoading ?? this.isLoading,
      errorText: errorText,
      statusText: statusText,
    );
  }
}

class WorkflowAutomationNotifier
    extends StateNotifier<WorkflowAutomationState> {
  final Ref _ref;
  WorkflowAutomationApi? _api;

  WorkflowAutomationNotifier(this._ref)
    : super(WorkflowAutomationState(automationRules: _defaultAutomationRules));

  WorkflowAutomationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    final normalizedBaseUrl = WorkflowAutomationApi.normalizeUrl(baseUrl);
    if (_api == null || _api!.baseUrl != normalizedBaseUrl) {
      _api?.dispose();
      _api = WorkflowAutomationApi(baseUrl: baseUrl);
    }
    return _api!;
  }

  Future<void> loadN8nSettings() async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().fetchN8nSettings();
    if (result['success'] == true) {
      final settings = result['settings'];
      final n8n = settings is Map ? settings['n8n'] : null;
      final email = settings is Map ? settings['email'] : null;
      final facebook = settings is Map ? settings['facebook'] : null;
      state = state.copyWith(
        isLoading: false,
        n8n: n8n is Map
            ? N8nSettingsState(
                enabled: n8n['enabled'] == true,
                baseUrl: n8n['baseUrl']?.toString() ?? '',
                apiKey: n8n['apiKey']?.toString() ?? '',
                eventWebhookUrl: n8n['eventWebhookUrl']?.toString() ?? '',
                callbackUrl: n8n['callbackUrl']?.toString() ?? '',
              )
            : state.n8n,
        email: email is Map ? EmailSettingsState.fromJson(email) : state.email,
        facebook: facebook is Map
            ? FacebookSettingsState.fromJson(facebook)
            : state.facebook,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không tải được cấu hình n8n.',
      );
    }
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setCategory(WorkflowTemplateCategory? value) {
    state = state.copyWith(
      selectedCategory: value,
      clearSelectedCategory: value == null,
    );
  }

  void setChannel(CrmChannel? value) {
    state = state.copyWith(
      selectedChannel: value,
      clearSelectedChannel: value == null,
    );
  }

  void addAutomationRule({
    required String name,
    required String event,
    required String conditionField,
    required String conditionOperator,
    required String conditionValue,
    required List<String> actions,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final rule = AutomationRule(
      id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      event: event.trim().isEmpty ? 'Tin nhắn mới' : event.trim(),
      conditionField: conditionField.trim().isEmpty
          ? 'Nội dung tin nhắn'
          : conditionField.trim(),
      conditionOperator: conditionOperator.trim().isEmpty
          ? 'chứa'
          : conditionOperator.trim(),
      conditionValue: conditionValue.trim(),
      actions: actions
          .map((action) => action.trim())
          .where((action) => action.isNotEmpty)
          .toList(),
      enabled: true,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      automationRules: [rule, ...state.automationRules],
      statusText: 'Đã thêm rule automation.',
      errorText: null,
    );
  }

  void toggleAutomationRule(String ruleId, bool enabled) {
    state = state.copyWith(
      automationRules: [
        for (final rule in state.automationRules)
          rule.id == ruleId ? rule.copyWith(enabled: enabled) : rule,
      ],
      statusText: enabled
          ? 'Đã bật rule automation.'
          : 'Đã tắt rule automation.',
      errorText: null,
    );
  }

  void deleteAutomationRule(String ruleId) {
    state = state.copyWith(
      automationRules: state.automationRules
          .where((rule) => rule.id != ruleId)
          .toList(),
      statusText: 'Đã xóa rule automation.',
      errorText: null,
    );
  }

  Future<void> saveN8nSettings(N8nSettingsState settings) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveN8nSettings(
      enabled: settings.enabled,
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      eventWebhookUrl: settings.eventWebhookUrl,
      callbackUrl: settings.callbackUrl,
    );
    state = state.copyWith(
      isLoading: false,
      n8n: result['success'] == true ? settings : state.n8n,
      statusText: result['success'] == true ? 'Đã lưu cấu hình n8n.' : null,
      errorText: result['success'] == true
          ? null
          : result['error']?.toString() ?? 'Không lưu được cấu hình n8n.',
    );
  }

  Future<void> saveEmailSettings(EmailSettingsState settings) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveEmailSettings(email: settings.toJson());
    state = state.copyWith(
      isLoading: false,
      email: result['success'] == true ? settings : state.email,
      statusText: result['success'] == true ? 'Đã lưu cấu hình Email.' : null,
      errorText: result['success'] == true
          ? null
          : result['error']?.toString() ?? 'Không lưu được cấu hình Email.',
    );
  }

  Future<void> saveFacebookSettings(FacebookSettingsState settings) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveFacebookSettings(
      facebook: settings.toJson(),
    );
    state = state.copyWith(
      isLoading: false,
      facebook: result['success'] == true ? settings : state.facebook,
      statusText: result['success'] == true
          ? 'Đã lưu cấu hình Facebook Page.'
          : null,
      errorText: result['success'] == true
          ? null
          : result['error']?.toString() ??
                'Không lưu được cấu hình Facebook Page.',
    );
  }

  Future<void> testN8nConnection(N8nSettingsState settings) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().testN8nConnection(
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
    );
    state = state.copyWith(
      isLoading: false,
      statusText: result['success'] == true ? 'Kết nối n8n thành công.' : null,
      errorText: result['success'] == true
          ? null
          : result['error']?.toString() ?? 'Không kết nối được n8n.',
    );
  }

  Future<void> installTemplate(WorkflowTemplate template) async {
    final channel =
        state.selectedChannel ??
        (template.supportedChannels.contains(CrmChannel.zaloPersonal)
            ? CrmChannel.zaloPersonal
            : template.supportedChannels.first);
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().installTemplate(
      WorkflowTemplateInstallRequest(
        templateId: template.id,
        channel: channel,
        variables: {
          if (state.n8n.eventWebhookUrl.isNotEmpty)
            'webhookPath':
                Uri.tryParse(state.n8n.eventWebhookUrl)?.pathSegments.last ??
                template.id,
        },
        createInactive: true,
      ),
    );
    state = state.copyWith(
      isLoading: false,
      statusText: result['success'] == true
          ? 'Đã tạo workflow nháp trong n8n.'
          : null,
      errorText: result['success'] == true
          ? null
          : result['error']?.toString() ?? 'Không tạo được workflow n8n.',
    );
  }

  @override
  void dispose() {
    _api?.dispose();
    super.dispose();
  }
}

final workflowAutomationProvider =
    StateNotifierProvider<WorkflowAutomationNotifier, WorkflowAutomationState>(
      (ref) => WorkflowAutomationNotifier(ref),
    );
