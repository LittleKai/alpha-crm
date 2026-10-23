import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../mock/mock_groups.dart';
import '../../../shared/utils/image_helper.dart';
import '../../../shared/widgets/activity_log_panel.dart';
import '../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../zalo_integration/data/zalo_integration_api.dart';
import '../../settings/providers/settings_provider.dart';

class LeaveGroupsState {
  final bool isRunning;
  final List<LogItem> logs;
  final String? selectedAccountId;
  final List<ZaloGroup> groups;
  final Set<String> selectedGroupIds;
  final bool isSilent;
  final String searchQuery;
  final bool isLoadingGroups;
  final int minDelay;
  final int maxDelay;

  const LeaveGroupsState({
    required this.isRunning,
    required this.logs,
    this.selectedAccountId,
    required this.groups,
    required this.selectedGroupIds,
    this.isSilent = true,
    this.searchQuery = '',
    this.isLoadingGroups = false,
    this.minDelay = 5,
    this.maxDelay = 15,
  });

  LeaveGroupsState copyWith({
    bool? isRunning,
    List<LogItem>? logs,
    String? selectedAccountId,
    List<ZaloGroup>? groups,
    Set<String>? selectedGroupIds,
    bool? isSilent,
    String? searchQuery,
    bool? isLoadingGroups,
    int? minDelay,
    int? maxDelay,
  }) {
    return LeaveGroupsState(
      isRunning: isRunning ?? this.isRunning,
      logs: logs ?? this.logs,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      groups: groups ?? this.groups,
      selectedGroupIds: selectedGroupIds ?? this.selectedGroupIds,
      isSilent: isSilent ?? this.isSilent,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoadingGroups: isLoadingGroups ?? this.isLoadingGroups,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
    );
  }
}

class LeaveGroupsNotifier extends StateNotifier<LeaveGroupsState> {
  final Ref _ref;
  Timer? _timer;
  int _currentGroupIndex = 0;
  List<String> _groupIdsToLeave = [];

  LeaveGroupsNotifier(this._ref)
    : super(
        LeaveGroupsState(
          isRunning: false,
          logs: [],
          groups: const [],
          selectedGroupIds: {},
        ),
      );

  void setAccount(String? accountId) {
    if (state.selectedAccountId != accountId) {
      state = state.copyWith(selectedAccountId: accountId, groups: const [], selectedGroupIds: {});
      if (accountId != null) {
        reloadGroups();
      }
    }
  }

  void setIsSilent(bool val) {
    state = state.copyWith(isSilent: val);
  }

  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(searchQuery: query);
  }

  void toggleGroup(String id) {
    final updated = Set<String>.from(state.selectedGroupIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedGroupIds: updated);
  }

  void toggleAllGroups(List<ZaloGroup> visibleGroups) {
    final updated = Set<String>.from(state.selectedGroupIds);
    final visibleIds = visibleGroups.map((g) => g.id).toSet();

    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every((id) => updated.contains(id));
    if (allSelected) {
      updated.removeAll(visibleIds);
    } else {
      updated.addAll(visibleIds);
    }
    state = state.copyWith(selectedGroupIds: updated);
  }

  Future<void> reloadGroups() async {
    state = state.copyWith(isLoadingGroups: true, selectedGroupIds: {});

    try {
      await _ref.read(zaloIntegrationProvider.notifier).checkConnection();
      final integrationState = _ref.read(zaloIntegrationProvider);

      if (integrationState.isConnected) {
        final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
        final apiClient = ZaloIntegrationApi(baseUrl: baseUrl);

        final result = await apiClient.fetchGroups();
        if (result['success'] == true && result['groups'] != null) {
          final List<dynamic> rawList = result['groups'];
          final realGroups = rawList.map((g) {
            return ZaloGroup(
              id: g['id']?.toString() ?? '',
              name: g['name']?.toString() ?? 'Nhóm không tên',
              memberCount:
                  int.tryParse(g['memberCount']?.toString() ?? '0') ?? 0,
              role: g['role']?.toString() ?? 'Thành viên',
              avatarUrl: sanitizeImageUrl(g['avatar']?.toString() ?? ''),
              accountId: g['accountId']?.toString(),
            );
          }).toList();

          String? autoAccountId = state.selectedAccountId;
          if ((autoAccountId == null ||
                  !integrationState.accounts.any(
                    (acc) => acc.id == autoAccountId,
                  )) &&
              integrationState.accounts.isNotEmpty) {
            autoAccountId = integrationState.accounts.first.id;
            debugPrint(
              '[LeaveGroupsNotifier] Auto-selected account ID: $autoAccountId',
            );
          }

          state = state.copyWith(
            isLoadingGroups: false,
            groups: realGroups,
            selectedAccountId: autoAccountId,
          );
          debugPrint(
            '[LeaveGroupsNotifier] Successfully reloaded ${realGroups.length} groups from backend.',
          );
          return;
        } else {
          debugPrint(
            '[LeaveGroupsNotifier] Failed to load groups from API: $result',
          );
        }
      } else {
        debugPrint(
          '[LeaveGroupsNotifier] Zalo backend is not connected: mode=${integrationState.mode}, error=${integrationState.errorText}',
        );
      }
    } catch (e, stack) {
      debugPrint('[LeaveGroupsNotifier] Exception in reloadGroups: $e\n$stack');
    }

    final integrationState = _ref.read(zaloIntegrationProvider);
    String? autoAccountId = state.selectedAccountId;
    if (autoAccountId == null && integrationState.accounts.isNotEmpty) {
      autoAccountId = integrationState.accounts.first.id;
    }

    state = state.copyWith(
      isLoadingGroups: false,
      groups: const [],
      selectedAccountId: autoAccountId,
    );
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  void startLeaveCampaign() {
    if (state.selectedAccountId == null) return;
    if (state.selectedGroupIds.isEmpty) return;

    _groupIdsToLeave = state.selectedGroupIds.toList();
    _currentGroupIndex = 0;

    state = state.copyWith(
      isRunning: true,
      logs: [
        LogItem(
          timestamp: DateFormat('HH:mm:ss').format(DateTime.now()),
          message: 'Bắt đầu chiến dịch tự động rời nhóm hàng loạt...',
          type: LogType.info,
        ),
      ],
    );

    _runNextLeave();
  }

  void _runNextLeave() {
    if (_currentGroupIndex >= _groupIdsToLeave.length) {
      _stopCampaign(finished: true);
      return;
    }

    final groupId = _groupIdsToLeave[_currentGroupIndex];
    final group = state.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () =>
          const ZaloGroup(id: '', name: 'Nhóm cũ', memberCount: 0, role: ''),
    );
    if (group.id.isEmpty) {
      _currentGroupIndex++;
      _runNextLeave();
      return;
    }

    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    state = state.copyWith(
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message:
              'Đang tiến hành rời khỏi nhóm: "${group.name}" ${state.isSilent ? "(âm thầm)" : ""}',
          type: LogType.info,
        ),
      ],
    );

    _timer = Timer(const Duration(seconds: 2), () async {
      final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());

      bool leaveSuccess = false;
      try {
        final integrationState = _ref.read(zaloIntegrationProvider);
        if (integrationState.isConnected) {
          final baseUrl = _ref
              .read(settingsProvider)
              .settings
              .zaloBackendBaseUrl;
          final apiClient = ZaloIntegrationApi(baseUrl: baseUrl);

          final result = await apiClient.leaveGroup(
            groupId: groupId,
            silent: state.isSilent,
            accountId: state.selectedAccountId,
          );
          leaveSuccess = result['success'] == true;
        }
      } catch (e) {
        // Handled silently
      }

      if (!mounted || !state.isRunning) return;

      final logTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
      List<LogItem> updatedLogs;

      if (leaveSuccess) {
        updatedLogs = [
          ...state.logs,
          LogItem(
            timestamp: completionTimeStr,
            message: 'Đã rời nhóm thành công: "${group.name}"',
            type: LogType.success,
          ),
        ];
      } else {
        updatedLogs = [
          ...state.logs,
          LogItem(
            timestamp: logTimeStr,
            message: 'Không thể rời nhóm: "${group.name}". Lỗi từ hệ thống.',
            type: LogType.error,
          ),
        ];
      }

      final updatedGroupsList = leaveSuccess
          ? state.groups.where((g) => g.id != groupId).toList()
          : state.groups;

      state = state.copyWith(logs: updatedLogs, groups: updatedGroupsList);

      _currentGroupIndex++;

      if (_currentGroupIndex < _groupIdsToLeave.length) {
        final delaySeconds =
            state.minDelay +
            (state.maxDelay > state.minDelay
                ? Random().nextInt(state.maxDelay - state.minDelay + 1)
                : 0);
        final delayTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: delayTimeStr,
              message:
                  'Đang giãn cách ${delaySeconds}s trước khi rời nhóm tiếp theo...',
              type: LogType.info,
            ),
          ],
        );

        _timer = Timer(Duration(seconds: delaySeconds), () {
          _runNextLeave();
        });
      } else {
        _runNextLeave();
      }
    });
  }

  void setMinDelay(int val) {
    if (val > 0) state = state.copyWith(minDelay: val);
  }

  void setMaxDelay(int val) {
    if (val >= state.minDelay) state = state.copyWith(maxDelay: val);
  }

  void stopLeaveCampaign() {
    _stopCampaign(finished: false);
  }

  void _stopCampaign({required bool finished}) {
    _timer?.cancel();
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    state = state.copyWith(
      isRunning: false,
      selectedGroupIds: {},
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message: finished
              ? 'Chiến dịch rời nhóm hoàn tất.'
              : 'Chiến dịch rời nhóm đã bị dừng bởi người dùng.',
          type: finished ? LogType.success : LogType.warning,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final leaveGroupsProvider =
    StateNotifierProvider<LeaveGroupsNotifier, LeaveGroupsState>((ref) {
      return LeaveGroupsNotifier(ref);
    });
