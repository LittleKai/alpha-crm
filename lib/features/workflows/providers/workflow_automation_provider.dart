import 'dart:async';

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
  final String appSecret;
  final String pageAccessToken;
  final bool enforce24hWindow;
  final String? cloudId;

  const FacebookSettingsState({
    this.enabled = false,
    this.status = 'cloud_required',
    this.pageName = '',
    this.pageId = '',
    this.appId = '',
    this.webhookCallbackUrl = '',
    this.verifyToken = '',
    this.appSecret = '',
    this.pageAccessToken = '',
    this.enforce24hWindow = true,
    this.cloudId,
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
      appSecret: json['appSecret']?.toString() ?? '',
      pageAccessToken: json['pageAccessToken']?.toString() ?? '',
      enforce24hWindow: json['enforce24hWindow'] != false,
      cloudId: json['cloudId']?.toString(),
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
      'appSecret': appSecret,
      'pageAccessToken': pageAccessToken,
      'enforce24hWindow': enforce24hWindow,
      if (cloudId != null) 'cloudId': cloudId,
    };
  }
}

/// TikTok integration state, structurally mirroring [FacebookSettingsState].
/// Field names/shape are a placeholder pending real TikTok Business
/// Messaging API docs/credentials — see `tiktok-channel.ts` for the backend
/// side of this same caveat.
class TiktokSettingsState {
  final bool enabled;
  final String status;
  final String accountName;
  final String accountId;
  final String appId;
  final String webhookCallbackUrl;
  final String verifyToken;
  final String appSecret;
  final String accessToken;
  final bool enforce24hWindow;
  final String? cloudId;

  const TiktokSettingsState({
    this.enabled = false,
    this.status = 'cloud_required',
    this.accountName = '',
    this.accountId = '',
    this.appId = '',
    this.webhookCallbackUrl = '',
    this.verifyToken = '',
    this.appSecret = '',
    this.accessToken = '',
    this.enforce24hWindow = true,
    this.cloudId,
  });

  factory TiktokSettingsState.fromJson(Map<dynamic, dynamic> json) {
    return TiktokSettingsState(
      enabled: json['enabled'] == true,
      status: json['status']?.toString() ?? 'cloud_required',
      accountName: json['accountName']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      appId: json['appId']?.toString() ?? '',
      webhookCallbackUrl: json['webhookCallbackUrl']?.toString() ?? '',
      verifyToken: json['verifyToken']?.toString() ?? '',
      appSecret: json['appSecret']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      enforce24hWindow: json['enforce24hWindow'] != false,
      cloudId: json['cloudId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'status': enabled ? 'configured' : status,
      'accountName': accountName,
      'accountId': accountId,
      'appId': appId,
      'webhookCallbackUrl': webhookCallbackUrl,
      'verifyToken': verifyToken,
      'appSecret': appSecret,
      'accessToken': accessToken,
      'enforce24hWindow': enforce24hWindow,
      if (cloudId != null) 'cloudId': cloudId,
    };
  }
}

/// Instagram Direct Messaging integration state, structurally mirroring
/// [TiktokSettingsState]. Instagram rides the same Meta Graph API/App
/// Secret as Facebook — see `instagram-channel.ts` for the backend side.
class InstagramSettingsState {
  final bool enabled;
  final String status;
  final String accountName;
  final String accountId;
  final String appId;
  final String webhookCallbackUrl;
  final String verifyToken;
  final String appSecret;
  final String accessToken;
  final bool enforce24hWindow;
  final String? cloudId;

  const InstagramSettingsState({
    this.enabled = false,
    this.status = 'cloud_required',
    this.accountName = '',
    this.accountId = '',
    this.appId = '',
    this.webhookCallbackUrl = '',
    this.verifyToken = '',
    this.appSecret = '',
    this.accessToken = '',
    this.enforce24hWindow = true,
    this.cloudId,
  });

  factory InstagramSettingsState.fromJson(Map<dynamic, dynamic> json) {
    return InstagramSettingsState(
      enabled: json['enabled'] == true,
      status: json['status']?.toString() ?? 'cloud_required',
      accountName: json['accountName']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      appId: json['appId']?.toString() ?? '',
      webhookCallbackUrl: json['webhookCallbackUrl']?.toString() ?? '',
      verifyToken: json['verifyToken']?.toString() ?? '',
      appSecret: json['appSecret']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      enforce24hWindow: json['enforce24hWindow'] != false,
      cloudId: json['cloudId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'status': enabled ? 'configured' : status,
      'accountName': accountName,
      'accountId': accountId,
      'appId': appId,
      'webhookCallbackUrl': webhookCallbackUrl,
      'verifyToken': verifyToken,
      'appSecret': appSecret,
      'accessToken': accessToken,
      'enforce24hWindow': enforce24hWindow,
      if (cloudId != null) 'cloudId': cloudId,
    };
  }
}

class WhatsappSettingsState {
  final bool enabled;
  final String status;
  final String accountName;
  final String accountId;
  final String appId;
  final String webhookCallbackUrl;
  final String verifyToken;
  final String appSecret;
  final String accessToken;
  final bool enforce24hWindow;
  final String? cloudId;

  const WhatsappSettingsState({
    this.enabled = false,
    this.status = 'cloud_required',
    this.accountName = '',
    this.accountId = '',
    this.appId = '',
    this.webhookCallbackUrl = '',
    this.verifyToken = '',
    this.appSecret = '',
    this.accessToken = '',
    this.enforce24hWindow = true,
    this.cloudId,
  });

  factory WhatsappSettingsState.fromJson(Map<dynamic, dynamic> json) {
    return WhatsappSettingsState(
      enabled: json['enabled'] == true,
      status: json['status']?.toString() ?? 'cloud_required',
      accountName: json['accountName']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      appId: json['appId']?.toString() ?? '',
      webhookCallbackUrl: json['webhookCallbackUrl']?.toString() ?? '',
      verifyToken: json['verifyToken']?.toString() ?? '',
      appSecret: json['appSecret']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      enforce24hWindow: json['enforce24hWindow'] != false,
      cloudId: json['cloudId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'status': enabled ? 'configured' : status,
      'accountName': accountName,
      'accountId': accountId,
      'appId': appId,
      'webhookCallbackUrl': webhookCallbackUrl,
      'verifyToken': verifyToken,
      'appSecret': appSecret,
      'accessToken': accessToken,
      'enforce24hWindow': enforce24hWindow,
      if (cloudId != null) 'cloudId': cloudId,
    };
  }
}

class TelegramSettingsState {
  final bool enabled;
  final String status;
  final String accountName;
  final String accountId;
  final String webhookCallbackUrl;
  final String botToken;
  final String verifyToken;
  final String? cloudId;

  const TelegramSettingsState({
    this.enabled = false,
    this.status = 'cloud_required',
    this.accountName = '',
    this.accountId = '',
    this.webhookCallbackUrl = '',
    this.botToken = '',
    this.verifyToken = '',
    this.cloudId,
  });

  factory TelegramSettingsState.fromJson(Map<dynamic, dynamic> json) {
    return TelegramSettingsState(
      enabled: json['enabled'] == true,
      status: json['status']?.toString() ?? 'cloud_required',
      accountName: json['accountName']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      webhookCallbackUrl: json['webhookCallbackUrl']?.toString() ?? '',
      botToken: json['botToken']?.toString() ?? '',
      verifyToken: json['verifyToken']?.toString() ?? '',
      cloudId: json['cloudId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'status': enabled ? 'configured' : status,
      'accountName': accountName,
      'accountId': accountId,
      'webhookCallbackUrl': webhookCallbackUrl,
      'botToken': botToken,
      'verifyToken': verifyToken,
      if (cloudId != null) 'cloudId': cloudId,
    };
  }
}

class WebchatSettingsState {
  final bool enabled;
  final String status;
  final String widgetId;
  final String widgetName;
  final String welcomeMessage;
  final String primaryColorHex;
  final String siteLabel;
  final String? cloudId;

  const WebchatSettingsState({
    this.enabled = false,
    this.status = 'cloud_required',
    this.widgetId = '',
    this.widgetName = '',
    this.welcomeMessage = '',
    this.primaryColorHex = '#4F46E5',
    this.siteLabel = '',
    this.cloudId,
  });

  factory WebchatSettingsState.fromJson(Map<dynamic, dynamic> json) {
    return WebchatSettingsState(
      enabled: json['enabled'] == true,
      status: json['status']?.toString() ?? 'cloud_required',
      widgetId: json['widgetId']?.toString() ?? '',
      widgetName: json['widgetName']?.toString() ?? '',
      welcomeMessage: json['welcomeMessage']?.toString() ?? '',
      primaryColorHex: json['primaryColorHex']?.toString() ?? '#4F46E5',
      siteLabel: json['siteLabel']?.toString() ?? '',
      cloudId: json['cloudId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'status': enabled ? 'configured' : status,
      'widgetId': widgetId,
      'widgetName': widgetName,
      'welcomeMessage': welcomeMessage,
      'primaryColorHex': primaryColorHex,
      'siteLabel': siteLabel,
      if (cloudId != null) 'cloudId': cloudId,
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

  factory AutomationRule.fromJson(Map<dynamic, dynamic> json) {
    final rawActions = json['actions'];
    return AutomationRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      event: json['event']?.toString() ?? 'Tin nhắn mới',
      conditionField: json['conditionField']?.toString() ?? 'Nội dung tin nhắn',
      conditionOperator: json['conditionOperator']?.toString() ?? 'chứa',
      conditionValue: json['conditionValue']?.toString() ?? '',
      actions: rawActions is List
          ? rawActions
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      enabled: json['enabled'] != false,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'event': event,
      'conditionField': conditionField,
      'conditionOperator': conditionOperator,
      'conditionValue': conditionValue,
      'actions': actions,
      'enabled': enabled,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
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
  final List<FacebookSettingsState> facebookPages;
  final List<TiktokSettingsState> tiktokAccounts;
  final List<InstagramSettingsState> instagramAccounts;
  final List<WhatsappSettingsState> whatsappAccounts;
  final List<TelegramSettingsState> telegramBots;
  final List<WebchatSettingsState> webchatWidgets;
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
    this.facebookPages = const [],
    this.tiktokAccounts = const [],
    this.instagramAccounts = const [],
    this.whatsappAccounts = const [],
    this.telegramBots = const [],
    this.webchatWidgets = const [],
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
    List<FacebookSettingsState>? facebookPages,
    List<TiktokSettingsState>? tiktokAccounts,
    List<InstagramSettingsState>? instagramAccounts,
    List<WhatsappSettingsState>? whatsappAccounts,
    List<TelegramSettingsState>? telegramBots,
    List<WebchatSettingsState>? webchatWidgets,
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
      facebookPages: facebookPages ?? this.facebookPages,
      tiktokAccounts: tiktokAccounts ?? this.tiktokAccounts,
      instagramAccounts: instagramAccounts ?? this.instagramAccounts,
      whatsappAccounts: whatsappAccounts ?? this.whatsappAccounts,
      telegramBots: telegramBots ?? this.telegramBots,
      webchatWidgets: webchatWidgets ?? this.webchatWidgets,
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
    : super(WorkflowAutomationState(automationRules: _defaultAutomationRules)) {
    unawaited(loadAutomationRules());
    unawaited(loadChannelAccounts());
  }

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
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không tải được cấu hình n8n.',
      );
    }
  }

  Future<void> loadChannelAccounts() async {
    final facebookResult = await _getApi().fetchFacebookAccounts();
    if (!mounted) return;
    if (facebookResult['success'] == true && facebookResult['data'] is List) {
      state = state.copyWith(
        facebookPages: (facebookResult['data'] as List)
            .whereType<Map>()
            .map(FacebookSettingsState.fromJson)
            .toList(),
      );
    }
    final tiktokResult = await _getApi().fetchTiktokAccounts();
    if (!mounted) return;
    if (tiktokResult['success'] == true && tiktokResult['data'] is List) {
      state = state.copyWith(
        tiktokAccounts: (tiktokResult['data'] as List)
            .whereType<Map>()
            .map(TiktokSettingsState.fromJson)
            .toList(),
      );
    }
    final instagramResult = await _getApi().fetchInstagramAccounts();
    if (!mounted) return;
    if (instagramResult['success'] == true && instagramResult['data'] is List) {
      state = state.copyWith(
        instagramAccounts: (instagramResult['data'] as List)
            .whereType<Map>()
            .map(InstagramSettingsState.fromJson)
            .toList(),
      );
    }
    final whatsappResult = await _getApi().fetchWhatsappAccounts();
    if (!mounted) return;
    if (whatsappResult['success'] == true && whatsappResult['data'] is List) {
      state = state.copyWith(
        whatsappAccounts: (whatsappResult['data'] as List)
            .whereType<Map>()
            .map(WhatsappSettingsState.fromJson)
            .toList(),
      );
    }
    final telegramResult = await _getApi().fetchTelegramBots();
    if (!mounted) return;
    if (telegramResult['success'] == true && telegramResult['data'] is List) {
      state = state.copyWith(
        telegramBots: (telegramResult['data'] as List)
            .whereType<Map>()
            .map(TelegramSettingsState.fromJson)
            .toList(),
      );
    }
    final webchatResult = await _getApi().fetchWebchatWidgets();
    if (!mounted) return;
    if (webchatResult['success'] == true && webchatResult['data'] is List) {
      state = state.copyWith(
        webchatWidgets: (webchatResult['data'] as List)
            .whereType<Map>()
            .map(WebchatSettingsState.fromJson)
            .toList(),
      );
    }
  }

  Future<void> loadAutomationRules() async {
    final result = await _getApi().fetchAutomationRules();
    if (!mounted) return;
    if (result['success'] != true || result['data'] is! List) {
      await _syncAutomationRules();
      return;
    }
    final rules = (result['data'] as List)
        .whereType<Map>()
        .map(AutomationRule.fromJson)
        .where((rule) => rule.id.isNotEmpty && rule.name.isNotEmpty)
        .toList();
    if (rules.isEmpty) {
      await _syncAutomationRules();
      return;
    }
    state = state.copyWith(automationRules: rules);
  }

  Future<void> _syncAutomationRules() async {
    if (!mounted) return;
    final api = _getApi();
    await api.saveAutomationRules(
      state.automationRules.map((rule) => rule.toJson()).toList(),
    );
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
    unawaited(_syncAutomationRules());
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
    unawaited(_syncAutomationRules());
  }

  void deleteAutomationRule(String ruleId) {
    state = state.copyWith(
      automationRules: state.automationRules
          .where((rule) => rule.id != ruleId)
          .toList(),
      statusText: 'Đã xóa rule automation.',
      errorText: null,
    );
    unawaited(_syncAutomationRules());
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

  Future<void> saveFacebookAccount(FacebookSettingsState account) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveFacebookAccount(account.toJson());
    if (result['success'] == true) {
      final saved = result['data'] is Map
          ? FacebookSettingsState.fromJson(result['data'] as Map)
          : account;
      final exists = state.facebookPages.any(
        (page) => page.pageId == saved.pageId,
      );
      state = state.copyWith(
        isLoading: false,
        facebookPages: exists
            ? [
                for (final page in state.facebookPages)
                  page.pageId == saved.pageId ? saved : page,
              ]
            : [...state.facebookPages, saved],
        statusText: 'Đã lưu cấu hình Facebook Page.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ??
            'Không lưu được cấu hình Facebook Page.',
      );
    }
  }

  Future<void> deleteFacebookAccount(String pageId) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().deleteFacebookAccount(pageId);
    if (result['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        facebookPages: state.facebookPages
            .where((page) => page.pageId != pageId)
            .toList(),
        statusText: 'Đã xóa Facebook Page.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không xóa được Facebook Page.',
      );
    }
  }

  Future<void> saveTiktokAccount(TiktokSettingsState account) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveTiktokAccount(account.toJson());
    if (result['success'] == true) {
      final saved = result['data'] is Map
          ? TiktokSettingsState.fromJson(result['data'] as Map)
          : account;
      final exists = state.tiktokAccounts.any(
        (acc) => acc.accountId == saved.accountId,
      );
      state = state.copyWith(
        isLoading: false,
        tiktokAccounts: exists
            ? [
                for (final acc in state.tiktokAccounts)
                  acc.accountId == saved.accountId ? saved : acc,
              ]
            : [...state.tiktokAccounts, saved],
        statusText: 'Đã lưu cấu hình TikTok.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không lưu được cấu hình TikTok.',
      );
    }
  }

  Future<void> deleteTiktokAccount(String accountId) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().deleteTiktokAccount(accountId);
    if (result['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        tiktokAccounts: state.tiktokAccounts
            .where((acc) => acc.accountId != accountId)
            .toList(),
        statusText: 'Đã xóa tài khoản TikTok.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không xóa được tài khoản TikTok.',
      );
    }
  }

  Future<void> saveInstagramAccount(InstagramSettingsState account) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveInstagramAccount(account.toJson());
    if (result['success'] == true) {
      final saved = result['data'] is Map
          ? InstagramSettingsState.fromJson(result['data'] as Map)
          : account;
      final exists = state.instagramAccounts.any(
        (acc) => acc.accountId == saved.accountId,
      );
      state = state.copyWith(
        isLoading: false,
        instagramAccounts: exists
            ? [
                for (final acc in state.instagramAccounts)
                  acc.accountId == saved.accountId ? saved : acc,
              ]
            : [...state.instagramAccounts, saved],
        statusText: 'Đã lưu cấu hình Instagram.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không lưu được cấu hình Instagram.',
      );
    }
  }

  Future<void> deleteInstagramAccount(String accountId) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().deleteInstagramAccount(accountId);
    if (result['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        instagramAccounts: state.instagramAccounts
            .where((acc) => acc.accountId != accountId)
            .toList(),
        statusText: 'Đã xóa tài khoản Instagram.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không xóa được tài khoản Instagram.',
      );
    }
  }

  Future<void> saveWhatsappAccount(WhatsappSettingsState account) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveWhatsappAccount(account.toJson());
    if (result['success'] == true) {
      final saved = result['data'] is Map
          ? WhatsappSettingsState.fromJson(result['data'] as Map)
          : account;
      final exists = state.whatsappAccounts.any(
        (acc) => acc.accountId == saved.accountId,
      );
      state = state.copyWith(
        isLoading: false,
        whatsappAccounts: exists
            ? [
                for (final acc in state.whatsappAccounts)
                  acc.accountId == saved.accountId ? saved : acc,
              ]
            : [...state.whatsappAccounts, saved],
        statusText: 'Đã lưu cấu hình WhatsApp.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không lưu được cấu hình WhatsApp.',
      );
    }
  }

  Future<void> deleteWhatsappAccount(String accountId) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().deleteWhatsappAccount(accountId);
    if (result['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        whatsappAccounts: state.whatsappAccounts
            .where((acc) => acc.accountId != accountId)
            .toList(),
        statusText: 'Đã xóa tài khoản WhatsApp.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không xóa được tài khoản WhatsApp.',
      );
    }
  }

  Future<void> saveTelegramBot(TelegramSettingsState bot) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveTelegramBot(bot.toJson());
    if (result['success'] == true) {
      final saved = result['data'] is Map
          ? TelegramSettingsState.fromJson(result['data'] as Map)
          : bot;
      final exists = state.telegramBots.any(
        (acc) => acc.accountId == saved.accountId,
      );
      state = state.copyWith(
        isLoading: false,
        telegramBots: exists
            ? [
                for (final acc in state.telegramBots)
                  acc.accountId == saved.accountId ? saved : acc,
              ]
            : [...state.telegramBots, saved],
        statusText: 'Đã lưu cấu hình Telegram.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không lưu được cấu hình Telegram.',
      );
    }
  }

  Future<void> deleteTelegramBot(String accountId) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().deleteTelegramBot(accountId);
    if (result['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        telegramBots: state.telegramBots
            .where((acc) => acc.accountId != accountId)
            .toList(),
        statusText: 'Đã xóa bot Telegram.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không xóa được bot Telegram.',
      );
    }
  }

  Future<void> saveWebchatWidget(WebchatSettingsState widget) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().saveWebchatWidget(widget.toJson());
    if (result['success'] == true) {
      final saved = result['data'] is Map
          ? WebchatSettingsState.fromJson(result['data'] as Map)
          : widget;
      final exists = state.webchatWidgets.any(
        (w) => w.widgetId == saved.widgetId,
      );
      state = state.copyWith(
        isLoading: false,
        webchatWidgets: exists
            ? [
                for (final w in state.webchatWidgets)
                  w.widgetId == saved.widgetId ? saved : w,
              ]
            : [...state.webchatWidgets, saved],
        statusText: 'Đã lưu cấu hình Webchat.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không lưu được cấu hình Webchat.',
      );
    }
  }

  Future<void> deleteWebchatWidget(String widgetId) async {
    state = state.copyWith(isLoading: true, errorText: null, statusText: null);
    final result = await _getApi().deleteWebchatWidget(widgetId);
    if (result['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        webchatWidgets: state.webchatWidgets
            .where((w) => w.widgetId != widgetId)
            .toList(),
        statusText: 'Đã xóa widget Webchat.',
        errorText: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            result['error']?.toString() ?? 'Không xóa được widget Webchat.',
      );
    }
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
