import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/zalo_backend_manager.dart';
import '../../../messaging/live_chat/data/live_chat_local_bridge_api.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../tasks/providers/crm_tasks_provider.dart'
    show defaultDueByPriority, crmTasksProvider;
import '../data/managed_groups_repository.dart';

final managedGroupsRepositoryProvider = Provider<ManagedGroupsRepository>((
  ref,
) {
  return ManagedGroupsRepository();
});

class ManagedZaloGroup {
  final String id;
  final String accountId;
  final String groupId;
  final String name;
  final String avatarUrl;
  final int memberCount;
  final bool isManaged;
  final String summaryCadence;
  final String notes;
  final DateTime? lastMessageAt;
  final Map<String, dynamic>? summaryConfig;

  const ManagedZaloGroup({
    required this.id,
    required this.accountId,
    required this.groupId,
    required this.name,
    this.avatarUrl = '',
    required this.memberCount,
    required this.isManaged,
    required this.summaryCadence,
    required this.notes,
    this.lastMessageAt,
    this.summaryConfig,
  });

  ManagedZaloGroup copyWith({
    bool? isManaged,
    String? summaryCadence,
    String? notes,
    Map<String, dynamic>? summaryConfig,
  }) {
    return ManagedZaloGroup(
      id: id,
      accountId: accountId,
      groupId: groupId,
      name: name,
      avatarUrl: avatarUrl,
      memberCount: memberCount,
      isManaged: isManaged ?? this.isManaged,
      summaryCadence: summaryCadence ?? this.summaryCadence,
      notes: notes ?? this.notes,
      lastMessageAt: lastMessageAt,
      summaryConfig: summaryConfig ?? this.summaryConfig,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ManagedZaloGroup && other.id == id && other.groupId == groupId;

  @override
  int get hashCode => Object.hash(id, groupId);

  static ManagedZaloGroup fromJson(Map<String, dynamic> json) {
    return ManagedZaloGroup(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      accountId: (json['accountId'] ?? '').toString(),
      groupId: (json['groupId'] ?? '').toString(),
      name: (json['name'] ?? json['groupId'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar'] ?? '').toString(),
      memberCount: int.tryParse((json['memberCount'] ?? 0).toString()) ?? 0,
      isManaged: json['isManaged'] == true,
      summaryCadence: (json['summaryCadence'] ?? 'manual').toString(),
      notes: (json['notes'] ?? '').toString(),
      lastMessageAt: DateTime.tryParse(
        (json['lastMessageAt'] ?? '').toString(),
      ),
      summaryConfig: json['summaryConfig'] is Map
          ? Map<String, dynamic>.from(json['summaryConfig'] as Map)
          : null,
    );
  }
}

class GroupInsight {
  final String id;
  final String type;
  final String title;
  final String description;
  final String priority;
  final String status;

  const GroupInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    this.status = 'open',
  });

  bool get isActionItem => type == 'follow_up';

  static GroupInsight fromJson(Map<String, dynamic> json) {
    return GroupInsight(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      status: (json['status'] ?? 'open').toString(),
    );
  }
}

class GroupSummaryRecord {
  final String id;
  final String summaryText;
  final DateTime createdAt;
  final List<String> keyTopics;
  final List<String> decisions;
  final List<String> questions;
  final List<String> risks;
  final List<String> opportunities;
  final String sentiment;
  final int messageCount;
  final DateTime? coveredFrom;
  final DateTime? coveredTo;

  const GroupSummaryRecord({
    required this.id,
    required this.summaryText,
    required this.createdAt,
    this.keyTopics = const [],
    this.decisions = const [],
    this.questions = const [],
    this.risks = const [],
    this.opportunities = const [],
    this.sentiment = 'neutral',
    this.messageCount = 0,
    this.coveredFrom,
    this.coveredTo,
  });

  bool get hasStructured =>
      keyTopics.isNotEmpty ||
      decisions.isNotEmpty ||
      questions.isNotEmpty ||
      risks.isNotEmpty ||
      opportunities.isNotEmpty;

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static GroupSummaryRecord fromJson(Map<String, dynamic> json) {
    return GroupSummaryRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      summaryText: (json['summaryText'] ?? json['summary'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      keyTopics: _stringList(json['keyTopics']),
      decisions: _stringList(json['decisions']),
      questions: _stringList(json['questions']),
      risks: _stringList(json['risks']),
      opportunities: _stringList(json['opportunities']),
      sentiment: (json['sentiment'] ?? 'neutral').toString(),
      messageCount: int.tryParse((json['messageCount'] ?? 0).toString()) ?? 0,
      coveredFrom: DateTime.tryParse((json['coveredFrom'] ?? '').toString()),
      coveredTo: DateTime.tryParse((json['coveredTo'] ?? '').toString()),
    );
  }
}

/// Wizard-configurable summary settings persisted per group on the cloud.
class GroupSummaryConfig {
  final String scopeMode; // 'incremental' | 'recent' | 'range'
  final int recentCount; // for 'recent'
  final int rangeDays; // for 'range'
  final Set<String> goals;
  final String industry;
  final String prompt;
  final bool autoCreateTasks;

  const GroupSummaryConfig({
    this.scopeMode = 'incremental',
    this.recentCount = 100,
    this.rangeDays = 7,
    this.goals = const {'leads', 'questions', 'actions'},
    this.industry = 'generic',
    this.prompt = '',
    this.autoCreateTasks = true,
  });

  GroupSummaryConfig copyWith({
    String? scopeMode,
    int? recentCount,
    int? rangeDays,
    Set<String>? goals,
    String? industry,
    String? prompt,
    bool? autoCreateTasks,
  }) {
    return GroupSummaryConfig(
      scopeMode: scopeMode ?? this.scopeMode,
      recentCount: recentCount ?? this.recentCount,
      rangeDays: rangeDays ?? this.rangeDays,
      goals: goals ?? this.goals,
      industry: industry ?? this.industry,
      prompt: prompt ?? this.prompt,
      autoCreateTasks: autoCreateTasks ?? this.autoCreateTasks,
    );
  }

  static GroupSummaryConfig? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final scope = json['scope'] is Map
        ? Map<String, dynamic>.from(json['scope'] as Map)
        : const {};
    return GroupSummaryConfig(
      scopeMode: (scope['mode'] ?? 'incremental').toString(),
      recentCount: int.tryParse((scope['count'] ?? 100).toString()) ?? 100,
      rangeDays: int.tryParse((scope['rangeDays'] ?? 7).toString()) ?? 7,
      goals: json['goals'] is List
          ? (json['goals'] as List).map((e) => e.toString()).toSet()
          : const {'leads', 'questions', 'actions'},
      industry: (json['industry'] ?? 'generic').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      autoCreateTasks: json['autoCreateTasks'] == true,
    );
  }

  /// Body sent to POST /crm/groups/:id/summarize.
  Map<String, dynamic> toSummarizeBody() {
    final scope = <String, dynamic>{'mode': scopeMode};
    if (scopeMode == 'recent') scope['count'] = recentCount;
    if (scopeMode == 'range') {
      scope['rangeDays'] = rangeDays;
      scope['fromAt'] = DateTime.now()
          .subtract(Duration(days: rangeDays))
          .toIso8601String();
      scope['toAt'] = DateTime.now().toIso8601String();
    }
    return {
      'scope': scope,
      'goals': goals.toList(),
      'industry': industry,
      'prompt': prompt,
      'autoCreateTasks': autoCreateTasks,
      'saveConfig': true,
    };
  }

  /// Local mirror of the cloud `summaryConfig` shape (for caching on the group).
  Map<String, dynamic> toConfigMap() {
    return {
      'scope': {'mode': scopeMode, 'count': recentCount, 'rangeDays': rangeDays},
      'goals': goals.toList(),
      'industry': industry,
      'prompt': prompt,
      'autoCreateTasks': autoCreateTasks,
    };
  }
}

class SummarizeOutcome {
  final bool success;
  final bool empty;
  final int messageCount;
  final int leadCount;
  final int questionCount;
  final List<GroupInsight> actionItems;

  const SummarizeOutcome({
    required this.success,
    this.empty = false,
    this.messageCount = 0,
    this.leadCount = 0,
    this.questionCount = 0,
    this.actionItems = const [],
  });

  const SummarizeOutcome.failure() : this(success: false);
}

class ManagedGroupsState {
  final List<ManagedZaloGroup> groups;
  final List<GroupInsight> insights;
  final List<GroupSummaryRecord> selectedSummaries;
  final List<GroupInsight> proposedActionItems;
  final ManagedZaloGroup? selectedGroup;
  final String selectedAccountId;
  final bool showManagedOnly;
  final bool isLoading;
  final bool isWorking;
  final String? errorMessage;
  final String? exportCsv;

  const ManagedGroupsState({
    required this.groups,
    required this.insights,
    required this.selectedSummaries,
    this.proposedActionItems = const [],
    this.selectedGroup,
    this.selectedAccountId = '',
    required this.showManagedOnly,
    required this.isLoading,
    required this.isWorking,
    this.errorMessage,
    this.exportCsv,
  });

  factory ManagedGroupsState.initial() {
    return const ManagedGroupsState(
      groups: [],
      insights: [],
      selectedSummaries: [],
      proposedActionItems: [],
      selectedGroup: null,
      selectedAccountId: '',
      showManagedOnly: false,
      isLoading: false,
      isWorking: false,
      errorMessage: null,
      exportCsv: null,
    );
  }

  ManagedGroupsState copyWith({
    List<ManagedZaloGroup>? groups,
    List<GroupInsight>? insights,
    List<GroupSummaryRecord>? selectedSummaries,
    List<GroupInsight>? proposedActionItems,
    ManagedZaloGroup? selectedGroup,
    bool clearSelectedGroup = false,
    String? selectedAccountId,
    bool? showManagedOnly,
    bool? isLoading,
    bool? isWorking,
    String? errorMessage,
    String? exportCsv,
  }) {
    return ManagedGroupsState(
      groups: groups ?? this.groups,
      insights: insights ?? this.insights,
      selectedSummaries: selectedSummaries ?? this.selectedSummaries,
      proposedActionItems: proposedActionItems ?? this.proposedActionItems,
      selectedGroup: clearSelectedGroup
          ? null
          : selectedGroup ?? this.selectedGroup,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      showManagedOnly: showManagedOnly ?? this.showManagedOnly,
      isLoading: isLoading ?? this.isLoading,
      isWorking: isWorking ?? this.isWorking,
      errorMessage: errorMessage,
      exportCsv: exportCsv ?? this.exportCsv,
    );
  }
}

class ManagedGroupsNotifier extends StateNotifier<ManagedGroupsState> {
  final Ref _ref;
  final ManagedGroupsRepository _repository;

  ManagedGroupsNotifier(this._ref, this._repository)
    : super(ManagedGroupsState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.wait([loadGroups(), loadInsights()]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadGroups() async {
    final response = await _repository.getGroups(
      accountId: state.selectedAccountId,
      managed: state.showManagedOnly ? true : null,
    );
    if (response['success'] == true && response['data'] is List) {
      final groups = (response['data'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                ManagedZaloGroup.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      state = state.copyWith(groups: groups);
    } else {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Không thể tải nhóm.').toString(),
      );
    }
  }

  Future<void> loadInsights() async {
    final response = await _repository.getInsights();
    if (response['success'] == true && response['data'] is List) {
      state = state.copyWith(
        insights: (response['data'] as List)
            .whereType<Map>()
            .map(
              (item) => GroupInsight.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
    }
  }

  Future<void> setSelectedAccountId(String accountId) async {
    state = state.copyWith(
      selectedAccountId: accountId,
      clearSelectedGroup: true,
    );
    await loadGroups();
  }

  Future<void> syncGroups() async {
    state = state.copyWith(isWorking: true, errorMessage: null);
    final response = await _repository.syncGroups(
      accountId: state.selectedAccountId,
    );
    state = state.copyWith(
      isWorking: false,
      errorMessage: response['success'] == true
          ? null
          : (response['message'] ?? 'Đồng bộ nhóm thất bại.').toString(),
    );
    if (response['success'] == true) {
      await loadGroups();
    }
  }

  Future<void> setManaged(ManagedZaloGroup group, bool isManaged) async {
    final targetGroups = state.groups.where((g) => g.groupId == group.groupId).toList();
    bool anySuccess = false;

    for (final g in targetGroups) {
      final response = await _repository.updateManaged(
        g.id,
        isManaged: isManaged,
        summaryCadence: g.summaryCadence,
        notes: g.notes,
      );
      if (response['success'] == true) {
        anySuccess = true;
      }
    }

    if (anySuccess) {
      state = state.copyWith(
        groups: state.groups.map((item) {
          if (item.groupId == group.groupId) {
            return item.copyWith(isManaged: isManaged);
          }
          return item;
        }).toList(),
        selectedGroup: state.selectedGroup?.groupId == group.groupId
            ? state.selectedGroup?.copyWith(isManaged: isManaged)
            : state.selectedGroup,
      );
    }
  }

  Future<void> selectGroup(ManagedZaloGroup group) async {
    state = state.copyWith(
      selectedGroup: group,
      selectedSummaries: [],
      proposedActionItems: [],
    );
    final response = await _repository.getSummaries(group.id);
    if (response['success'] == true && response['data'] is List) {
      state = state.copyWith(
        selectedSummaries: (response['data'] as List)
            .whereType<Map>()
            .map(
              (item) =>
                  GroupSummaryRecord.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
    }
  }

  /// Run an incremental/structured summary for the selected group using [config].
  Future<SummarizeOutcome> summarizeWithConfig(
    GroupSummaryConfig config,
  ) async {
    final group = state.selectedGroup;
    if (group == null) return const SummarizeOutcome.failure();
    state = state.copyWith(
      isWorking: true,
      errorMessage: null,
      proposedActionItems: [],
    );

    // Privacy: message content lives only in the local store. Read it here and
    // send transiently to the cloud for AI processing — the backend never stores it.
    final messages = await _gatherLocalGroupMessages(group, config);
    if (messages.isEmpty) {
      state = state.copyWith(
        isWorking: false,
        errorMessage:
            'Không đọc được tin nhắn nhóm từ máy (cần bản desktop có backend local, '
            'nhóm đã bật quản lý và có tin nhắn mới).',
      );
      return const SummarizeOutcome.failure();
    }

    final body = {
      ...config.toSummarizeBody(),
      'messages': messages,
      // Summary model is a local preference; send it with the request.
      'aiModel': _ref.read(settingsProvider).settings.summaryAiModel,
    };
    final response = await _repository.summarizeGroup(group.id, body);
    if (response['success'] != true) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: (response['message'] ?? 'Tóm tắt nhóm thất bại.')
            .toString(),
      );
      return const SummarizeOutcome.failure();
    }

    final data = response['data'];
    final proposed = <GroupInsight>[];
    int leadCount = 0;
    int questionCount = 0;
    int messageCount = 0;
    if (data is Map) {
      if (data['insights'] is List) {
        for (final item in (data['insights'] as List).whereType<Map>()) {
          final insight = GroupInsight.fromJson(Map<String, dynamic>.from(item));
          if (insight.isActionItem) proposed.add(insight);
        }
      }
      if (data['summary'] is Map) {
        final summary = GroupSummaryRecord.fromJson(
          Map<String, dynamic>.from(data['summary'] as Map),
        );
        leadCount = summary.opportunities.length;
        questionCount = summary.questions.length;
        messageCount = summary.messageCount;
      }
    }
    final isEmpty = data is Map && data['empty'] == true;

    final updatedGroup = group.copyWith(summaryConfig: config.toConfigMap());
    state = state.copyWith(
      selectedGroup: updatedGroup,
      groups: state.groups
          .map((g) => g.id == group.id ? updatedGroup : g)
          .toList(),
    );
    await selectGroup(updatedGroup);
    await loadInsights();
    state = state.copyWith(
      isWorking: false,
      proposedActionItems: proposed,
      errorMessage: isEmpty ? 'Không có tin nhắn mới để tóm tắt.' : null,
    );
    return SummarizeOutcome(
      success: true,
      empty: isEmpty,
      messageCount: messageCount,
      leadCount: leadCount,
      questionCount: questionCount,
      actionItems: proposed,
    );
  }

  /// Reads group messages from the operator's LOCAL store (via the live-chat
  /// bridge) according to [config] scope. Returns `[{senderName, content, sentAt}]`.
  /// Empty when the local backend is unavailable or no messages match.
  Future<List<Map<String, dynamic>>> _gatherLocalGroupMessages(
    ManagedZaloGroup group,
    GroupSummaryConfig config,
  ) async {
    final port = ZaloBackendManager.activePort ?? 8787;
    final bridge = LiveChatLocalBridgeApi(baseUrl: 'http://127.0.0.1:$port');
    try {
      // Map the managed group (accountId + groupId) to a local conversation.
      // ponytail: scans first 300 threads; raise if an operator has more groups.
      final convRes = await bridge.getLocalConversations(
        accountId: group.accountId,
        limit: 300,
      );
      final conversations = (convRes['data'] as List?) ?? const [];
      String? conversationId;
      for (final raw in conversations.whereType<Map>()) {
        if (raw['threadId']?.toString() == group.groupId) {
          conversationId = raw['id']?.toString();
          break;
        }
      }
      if (conversationId == null || conversationId.isEmpty) return const [];

      // Scope → cursor + limit.
      String? after;
      int limit = 400;
      if (config.scopeMode == 'recent') {
        limit = config.recentCount;
      } else if (config.scopeMode == 'range') {
        after = DateTime.now()
            .subtract(Duration(days: config.rangeDays))
            .millisecondsSinceEpoch
            .toString();
      } else {
        // incremental: continue from the last summary's watermark.
        final latest = state.selectedSummaries.isNotEmpty
            ? state.selectedSummaries.first
            : null;
        if (latest?.coveredTo != null) {
          after = latest!.coveredTo!.millisecondsSinceEpoch.toString();
        }
      }

      final msgRes = await bridge.getLocalMessages(
        conversationId,
        limit: limit,
        after: after,
      );
      final rawMessages = (msgRes['data'] as List?) ?? const [];
      return rawMessages
          .whereType<Map>()
          .map(
            (m) => <String, dynamic>{
              'senderName': (m['senderName'] ?? m['senderId'] ?? '').toString(),
              'content': (m['content'] ?? '').toString(),
              'sentAt': m['createdAt'],
            },
          )
          .where((m) => (m['content'] as String).trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void clearProposedActionItems() {
    state = state.copyWith(proposedActionItems: []);
  }

  /// Create follow-up tasks from selected action items and mark them done so
  /// they are skipped on the next incremental summary. Returns count created.
  Future<int> createTasksFromInsights(List<GroupInsight> items) async {
    final group = state.selectedGroup;
    int created = 0;
    final doneIds = <String>{};
    for (final item in items) {
      final ok = await _repository.createTask({
        'title': item.title,
        'description': item.description,
        'priority': item.priority,
        'relatedType': 'insight',
        'insightId': item.id,
        if (group != null) 'groupId': group.id,
        'ownerNote': 'Từ tóm tắt nhóm',
        'dueAt': defaultDueByPriority(item.priority).toIso8601String(),
      });
      if (ok['success'] == true) {
        created++;
        doneIds.add(item.id);
        await _repository.updateInsightStatus(item.id, 'done');
      }
    }
    if (created > 0) {
      state = state.copyWith(
        proposedActionItems: state.proposedActionItems
            .where((e) => !doneIds.contains(e.id))
            .toList(),
      );
      await loadInsights();
      // Refresh the care-tasks tab + sidebar badge with the newly created tasks.
      await _ref.read(crmTasksProvider.notifier).loadTasks();
    }
    return created;
  }

  Future<void> toggleManagedOnly(bool value) async {
    state = state.copyWith(showManagedOnly: value);
    await loadGroups();
  }

  Future<void> exportSummaries() async {
    final response = await _repository.exportSummaries(
      groupId: state.selectedGroup?.id,
    );
    final data = response['data'];
    if (response['success'] == true && data is Map) {
      state = state.copyWith(exportCsv: (data['csv'] ?? '').toString());
    }
  }
}

final managedGroupsProvider =
    StateNotifierProvider<ManagedGroupsNotifier, ManagedGroupsState>((ref) {
      return ManagedGroupsNotifier(
        ref,
        ref.read(managedGroupsRepositoryProvider),
      );
    });
