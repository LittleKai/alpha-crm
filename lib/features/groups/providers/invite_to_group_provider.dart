import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../mock/mock_groups.dart';
import '../../../shared/utils/image_helper.dart';
import '../../../shared/utils/zalo_compliance_guard.dart';
import '../../../shared/widgets/activity_log_panel.dart';
import '../../settings/providers/settings_provider.dart';
import '../../zalo_integration/data/zalo_integration_api.dart';
import '../../zalo_integration/providers/zalo_integration_provider.dart';

class InviteToGroupState {
  final bool isRunning;
  final List<LogItem> logs;
  final String? selectedAccountId;
  final String? selectedGroupId;
  final List<FriendRecord> friends;
  final List<ZaloGroup> groups;
  final Set<String> selectedFriendIds;
  final String searchQuery;
  final int maxInviteCount;
  final int minDelay;
  final int maxDelay;
  final String? complianceError;

  const InviteToGroupState({
    required this.isRunning,
    required this.logs,
    this.selectedAccountId,
    this.selectedGroupId,
    required this.friends,
    required this.groups,
    required this.selectedFriendIds,
    this.searchQuery = '',
    this.maxInviteCount = 50,
    this.minDelay = 5,
    this.maxDelay = 10,
    this.complianceError,
  });

  InviteToGroupState copyWith({
    bool? isRunning,
    List<LogItem>? logs,
    String? selectedAccountId,
    String? selectedGroupId,
    List<FriendRecord>? friends,
    List<ZaloGroup>? groups,
    Set<String>? selectedFriendIds,
    String? searchQuery,
    int? maxInviteCount,
    int? minDelay,
    int? maxDelay,
    String? complianceError,
  }) {
    return InviteToGroupState(
      isRunning: isRunning ?? this.isRunning,
      logs: logs ?? this.logs,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      friends: friends ?? this.friends,
      groups: groups ?? this.groups,
      selectedFriendIds: selectedFriendIds ?? this.selectedFriendIds,
      searchQuery: searchQuery ?? this.searchQuery,
      maxInviteCount: maxInviteCount ?? this.maxInviteCount,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      complianceError: complianceError,
    );
  }
}

class InviteToGroupNotifier extends StateNotifier<InviteToGroupState> {
  final Ref _ref;
  Timer? _timer;
  int _currentFriendIndex = 0;
  List<String> _friendIdsToInvite = [];

  InviteToGroupNotifier(this._ref)
    : super(
        const InviteToGroupState(
          isRunning: false,
          logs: [],
          friends: [],
          groups: [],
          selectedFriendIds: {},
        ),
      );

  ZaloIntegrationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    return ZaloIntegrationApi(baseUrl: baseUrl);
  }

  bool get _isConnected => _ref.read(zaloIntegrationProvider).isConnected;

  void setAccount(String? accountId) {
    if (state.selectedAccountId != accountId) {
      state = state.copyWith(
        selectedAccountId: accountId,
        friends: const [],
        selectedFriendIds: {},
      );
      if (accountId != null) {
        loadFriends();
      }
    }
  }

  void setGroupId(String? groupId) {
    state = state.copyWith(selectedGroupId: groupId);
  }

  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(searchQuery: query);
  }

  void setMaxInvite(int val) {
    state = state.copyWith(maxInviteCount: val);
  }

  void setMinDelay(int val) {
    state = state.copyWith(minDelay: val);
  }

  void setMaxDelay(int val) {
    state = state.copyWith(maxDelay: val);
  }

  void toggleFriend(String id) {
    final updated = Set<String>.from(state.selectedFriendIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedFriendIds: updated);
  }

  void toggleAllFriends(List<FriendRecord> visibleFriends) {
    final updated = Set<String>.from(state.selectedFriendIds);
    final visibleIds = visibleFriends.map((f) => f.id).toSet();

    final allSelected = visibleIds.every((id) => updated.contains(id));
    if (allSelected) {
      updated.removeAll(visibleIds);
    } else {
      updated.addAll(visibleIds);
    }
    state = state.copyWith(selectedFriendIds: updated);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  Future<void> loadFriends() async {
    if (_isConnected) {
      try {
        final api = _getApi();
        final response = await api.fetchFriends(
          accountId: state.selectedAccountId,
        );
        if (response['success'] == true && response['friends'] != null) {
          final List<dynamic> rawFriends = response['friends'];
          final friends = rawFriends.map((f) {
            return FriendRecord(
              id: f['userId']?.toString() ?? '',
              name:
                  f['displayName']?.toString() ??
                  f['zaloName']?.toString() ??
                  '',
              phone: f['phoneNumber']?.toString() ?? '',
              avatarUrl: sanitizeImageUrl(f['avatar']?.toString() ?? ''),
            );
          }).toList();
          state = state.copyWith(friends: friends);
          return;
        }
      } catch (_) {
        // Fall through to mock
      }
    }

    // No fallback - keep list empty
    state = state.copyWith(friends: const []);
  }

  Future<void> loadGroups() async {
    if (_isConnected) {
      try {
        final api = _getApi();
        final response = await api.fetchGroups();
        if (response['success'] == true && response['groups'] != null) {
          final List<dynamic> rawList = response['groups'];
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

          state = state.copyWith(groups: realGroups);
          return;
        }
      } catch (_) {
        // Fall through to mock
      }
    }

    // No fallback - keep list empty
    state = state.copyWith(groups: const []);
  }

  void startInviteCampaign() {
    if (state.selectedAccountId == null || state.selectedGroupId == null) {
      return;
    }
    if (state.selectedFriendIds.isEmpty) return;

    // Compliance check
    final settings = _ref.read(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.inviteToGroup,
      targetCount: state.selectedFriendIds.length,
    );

    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
      );
      return;
    }

    _friendIdsToInvite = state.selectedFriendIds.toList();
    _currentFriendIndex = 0;

    final targetGroupName = state.groups
        .firstWhere(
          (g) => g.id == state.selectedGroupId,
          orElse: () => const ZaloGroup(
            id: '',
            name: 'Nhóm Zalo',
            memberCount: 0,
            role: '',
          ),
        )
        .name;

    state = state.copyWith(
      isRunning: true,
      complianceError: null,
      logs: [
        LogItem(
          timestamp: DateFormat('HH:mm:ss').format(DateTime.now()),
          message: 'Bắt đầu mời bạn bè vào nhóm "$targetGroupName"...',
          type: LogType.info,
        ),
      ],
    );

    _runNextInvite(targetGroupName);
  }

  void _runNextInvite(String targetGroupName) {
    if (_currentFriendIndex >= _friendIdsToInvite.length ||
        _currentFriendIndex >= state.maxInviteCount) {
      _stopCampaign(finished: true);
      return;
    }

    final friendId = _friendIdsToInvite[_currentFriendIndex];
    final friend = state.friends.firstWhere(
      (f) => f.id == friendId,
      orElse: () => FriendRecord(id: friendId, name: friendId, phone: ''),
    );
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    state = state.copyWith(
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message:
              'Đang gửi lời mời vào nhóm đến: ${friend.name} (${friend.phone})',
          type: LogType.info,
        ),
      ],
    );

    _timer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final api = _getApi();
        final response = await api.inviteToGroup(
          userId: friendId,
          groupId: state.selectedGroupId ?? '',
          accountId: state.selectedAccountId,
        );

        final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());

        if (response['success'] == true) {
          state = state.copyWith(
            logs: [
              ...state.logs,
              LogItem(
                timestamp: completionTimeStr,
                message: 'Đã gửi lời mời thành công đến: ${friend.name}',
                type: LogType.success,
              ),
            ],
          );
        } else {
          final errorMsg =
              response['error'] ?? 'Có thể do thiết lập chặn nhận lời mời';
          state = state.copyWith(
            logs: [
              ...state.logs,
              LogItem(
                timestamp: completionTimeStr,
                message: 'Gửi lời mời thất bại đến: ${friend.name} ($errorMsg)',
                type: LogType.error,
              ),
            ],
          );
        }
      } catch (err) {
        final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: completionTimeStr,
              message: 'Lỗi mạng khi mời ${friend.name}: $err',
              type: LogType.error,
            ),
          ],
        );
      }

      _currentFriendIndex++;

      if (_currentFriendIndex < _friendIdsToInvite.length &&
          _currentFriendIndex < state.maxInviteCount) {
        final delaySeconds =
            state.minDelay +
            (state.maxDelay > state.minDelay
                ? (state.maxDelay - state.minDelay)
                : 0);
        final delayTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: delayTimeStr,
              message:
                  'Đang giãn cách ${delaySeconds}s trước khi mời người tiếp theo...',
              type: LogType.info,
            ),
          ],
        );

        _timer = Timer(Duration(seconds: delaySeconds), () {
          _runNextInvite(targetGroupName);
        });
      } else {
        _runNextInvite(targetGroupName);
      }
    });
  }

  void stopInviteCampaign() {
    _stopCampaign(finished: false);
  }

  void _stopCampaign({required bool finished}) {
    _timer?.cancel();
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    state = state.copyWith(
      isRunning: false,
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message: finished
              ? 'Chiến dịch mời bạn bè hoàn tất.'
              : 'Chiến dịch đã bị dừng bởi người dùng.',
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

final inviteToGroupProvider =
    StateNotifierProvider<InviteToGroupNotifier, InviteToGroupState>((ref) {
      return InviteToGroupNotifier(ref);
    });
