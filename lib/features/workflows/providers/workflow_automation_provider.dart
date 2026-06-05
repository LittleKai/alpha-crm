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

class WorkflowAutomationState {
  final List<WorkflowTemplate> templates;
  final WorkflowTemplateCategory? selectedCategory;
  final CrmChannel? selectedChannel;
  final String searchQuery;
  final N8nSettingsState n8n;
  final bool isLoading;
  final String? errorText;
  final String? statusText;

  const WorkflowAutomationState({
    this.templates = workflowTemplateCatalog,
    this.selectedCategory,
    this.selectedChannel,
    this.searchQuery = '',
    this.n8n = const N8nSettingsState(),
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
    WorkflowTemplateCategory? selectedCategory,
    bool clearSelectedCategory = false,
    CrmChannel? selectedChannel,
    bool clearSelectedChannel = false,
    String? searchQuery,
    N8nSettingsState? n8n,
    bool? isLoading,
    String? errorText,
    String? statusText,
  }) {
    return WorkflowAutomationState(
      templates: templates ?? this.templates,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      selectedChannel: clearSelectedChannel
          ? null
          : (selectedChannel ?? this.selectedChannel),
      searchQuery: searchQuery ?? this.searchQuery,
      n8n: n8n ?? this.n8n,
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
    : super(const WorkflowAutomationState());

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
