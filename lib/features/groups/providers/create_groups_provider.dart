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

class CreateGroupsState {
  final bool isRunning;
  final List<LogItem> logs;
  final String? selectedAccountId;
  final String groupNamesText;
  final List<FriendRecord> friends;
  final Set<String> selectedFriendIds;
  final String searchQuery;
  final int minDelay;
  final int maxDelay;
  final String? complianceError;

  const CreateGroupsState({
    required this.isRunning,
    required this.logs,
    this.selectedAccountId,
    required this.groupNamesText,
    required this.friends,
    required this.selectedFriendIds,
    this.searchQuery = '',
    this.minDelay = 5,
    this.maxDelay = 10,
    this.complianceError,
  });

  CreateGroupsState copyWith({
    bool? isRunning,
    List<LogItem>? logs,
    String? selectedAccountId,
    String? groupNamesText,
    List<FriendRecord>? friends,
    Set<String>? selectedFriendIds,
    String? searchQuery,
    int? minDelay,
    int? maxDelay,
    String? complianceError,
  }) {
    return CreateGroupsState(
      isRunning: isRunning ?? this.isRunning,
      logs: logs ?? this.logs,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      groupNamesText: groupNamesText ?? this.groupNamesText,
      friends: friends ?? this.friends,
      selectedFriendIds: selectedFriendIds ?? this.selectedFriendIds,
      searchQuery: searchQuery ?? this.searchQuery,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      complianceError: complianceError,
    );
  }
}

class CreateGroupsNotifier extends StateNotifier<CreateGroupsState> {
  final Ref _ref;
  Timer? _timer;
  int _currentGroupIndex = 0;
  List<String> _groupNames = [];
  int _successCount = 0;
  int _failCount = 0;

  CreateGroupsNotifier(this._ref)
    : super(
        CreateGroupsState(
          isRunning: false,
          logs: [],
          groupNamesText: '',
          friends: const [],
          selectedFriendIds: {},
        ),
      );

  ZaloIntegrationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    return ZaloIntegrationApi(baseUrl: baseUrl);
  }

  bool get _isConnected => _ref.read(zaloIntegrationProvider).isConnected;

  void setAccount(String? accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  Future<void> loadFriends() async {
    if (_isConnected) {
      try {
        final api = _getApi();
        final response = await api.fetchFriends();
        if (response['success'] == true && response['friends'] != null) {
          final List<dynamic> rawFriends = response['friends'];
          final friends = rawFriends.map((f) {
            return FriendRecord(
              id: f['userId']?.toString() ?? '',
              name: f['displayName']?.toString() ??
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

    // Mock fallback
    state = state.copyWith(friends: MockGroups.sampleFriends);
  }

  void setGroupNames(String val) {
    state = state.copyWith(groupNamesText: val);
  }

  void setSearchQuery(String val) {
    state = state.copyWith(searchQuery: val);
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

  void startCreateCampaign() {
    if (state.groupNamesText.trim().isEmpty) return;
    if (state.selectedFriendIds.isEmpty) return;

    _groupNames = state.groupNamesText
        .split('\n')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (_groupNames.isEmpty) return;

    // Compliance check
    final settings = _ref.read(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.createGroups,
      targetCount: _groupNames.length,
    );

    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
      );
      return;
    }

    _currentGroupIndex = 0;
    _successCount = 0;
    _failCount = 0;
    state = state.copyWith(
      isRunning: true,
      complianceError: null,
      logs: [
        LogItem(
          timestamp: DateFormat('HH:mm:ss').format(DateTime.now()),
          message: 'Bắt đầu chiến dịch tự động tạo nhóm Zalo...',
          type: LogType.info,
        ),
      ],
    );

    _runNextCreation();
  }

  void _runNextCreation() {
    if (_currentGroupIndex >= _groupNames.length) {
      _stopCampaign(finished: true);
      return;
    }

    final groupName = _groupNames[_currentGroupIndex];
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    state = state.copyWith(
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message: 'Đang tạo nhóm mới: "$groupName"',
          type: LogType.info,
        ),
      ],
    );

    _timer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final api = _getApi();
        final membersList = state.selectedFriendIds.toList();
        final response = await api.createGroup(
          name: groupName,
          members: membersList,
          accountId: state.selectedAccountId,
        );
        
        final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());

        if (response['success'] == true) {
          _successCount++;
          final String newGroupId = response['groupId'] ?? '';
          
          List<LogItem> updatedLogs = [
            ...state.logs,
            LogItem(
              timestamp: completionTimeStr,
              message: 'Tạo nhóm "$groupName" thành công. ID nhóm: $newGroupId.',
              type: LogType.success,
            ),
          ];

          // Add selected members success logs
          for (final friendId in state.selectedFriendIds) {
            final friend = state.friends.firstWhere(
              (f) => f.id == friendId,
              orElse: () => FriendRecord(id: friendId, name: friendId, phone: ''),
            );
            updatedLogs.add(
              LogItem(
                timestamp: completionTimeStr,
                message: 'Đã thêm thành viên: ${friend.name}',
                type: LogType.success,
              ),
            );
          }

          state = state.copyWith(logs: updatedLogs);
        } else {
          _failCount++;
          final errorMsg = response['error'] ?? 'Lỗi không rõ từ server';
          state = state.copyWith(
            logs: [
              ...state.logs,
              LogItem(
                timestamp: completionTimeStr,
                message: 'Tạo nhóm "$groupName" thất bại: $errorMsg',
                type: LogType.error,
              ),
            ],
          );
        }
      } catch (err) {
        _failCount++;
        final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: completionTimeStr,
              message: 'Lỗi mạng khi tạo nhóm "$groupName": $err',
              type: LogType.error,
            ),
          ],
        );
      }

      _currentGroupIndex++;

      if (_currentGroupIndex < _groupNames.length) {
        final delaySeconds = state.minDelay + (state.maxDelay > state.minDelay ? (state.maxDelay - state.minDelay) : 0);
        final delayTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: delayTimeStr,
              message: 'Đang giãn cách ${delaySeconds}s trước khi tạo nhóm tiếp theo...',
              type: LogType.info,
            ),
          ],
        );

        _timer = Timer(Duration(seconds: delaySeconds), () {
          _runNextCreation();
        });
      } else {
        _runNextCreation();
      }
    });
  }

  void stopCreateCampaign() {
    _stopCampaign(finished: false);
  }

  void _stopCampaign({required bool finished}) {
    _timer?.cancel();
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    LogItem finalLog;
    if (finished) {
      if (_successCount > 0 && _failCount == 0) {
        finalLog = LogItem(
          timestamp: timeStr,
          message: 'Chiến dịch tự động tạo nhóm hoàn tất thành công. Đã tạo $_successCount nhóm.',
          type: LogType.success,
        );
      } else if (_successCount > 0 && _failCount > 0) {
        finalLog = LogItem(
          timestamp: timeStr,
          message: 'Chiến dịch hoàn tất với lỗi. Thành công: $_successCount, Thất bại: $_failCount.',
          type: LogType.warning,
        );
      } else {
        finalLog = LogItem(
          timestamp: timeStr,
          message: 'Chiến dịch tự động tạo nhóm thất bại. Thất bại: $_failCount nhóm.',
          type: LogType.error,
        );
      }
    } else {
      finalLog = LogItem(
        timestamp: timeStr,
        message: 'Chiến dịch đã bị dừng bởi người dùng. Thành công: $_successCount, Thất bại: $_failCount.',
        type: LogType.warning,
      );
    }

    state = state.copyWith(
      isRunning: false,
      logs: [
        ...state.logs,
        finalLog,
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final createGroupsProvider =
    StateNotifierProvider<CreateGroupsNotifier, CreateGroupsState>((ref) {
      return CreateGroupsNotifier(ref);
    });
