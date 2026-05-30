import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../mock/mock_groups.dart';
import '../../../shared/widgets/activity_log_panel.dart';

class CreateGroupsState {
  final bool isRunning;
  final List<LogItem> logs;
  final String groupNamesText;
  final List<FriendRecord> friends;
  final Set<String> selectedFriendIds;
  final String searchQuery;
  final int minDelay;
  final int maxDelay;

  const CreateGroupsState({
    required this.isRunning,
    required this.logs,
    required this.groupNamesText,
    required this.friends,
    required this.selectedFriendIds,
    this.searchQuery = '',
    this.minDelay = 5,
    this.maxDelay = 10,
  });

  CreateGroupsState copyWith({
    bool? isRunning,
    List<LogItem>? logs,
    String? groupNamesText,
    List<FriendRecord>? friends,
    Set<String>? selectedFriendIds,
    String? searchQuery,
    int? minDelay,
    int? maxDelay,
  }) {
    return CreateGroupsState(
      isRunning: isRunning ?? this.isRunning,
      logs: logs ?? this.logs,
      groupNamesText: groupNamesText ?? this.groupNamesText,
      friends: friends ?? this.friends,
      selectedFriendIds: selectedFriendIds ?? this.selectedFriendIds,
      searchQuery: searchQuery ?? this.searchQuery,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
    );
  }
}

class CreateGroupsNotifier extends StateNotifier<CreateGroupsState> {
  Timer? _timer;
  int _currentGroupIndex = 0;
  List<String> _groupNames = [];

  CreateGroupsNotifier()
    : super(
        CreateGroupsState(
          isRunning: false,
          logs: [],
          groupNamesText: '',
          friends: const [],
          selectedFriendIds: {},
        ),
      );

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

    _currentGroupIndex = 0;
    state = state.copyWith(
      isRunning: true,
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

    _timer = Timer(const Duration(seconds: 2), () {
      final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());

      // Update logs list with creation success
      List<LogItem> updatedLogs = [
        ...state.logs,
        LogItem(
          timestamp: completionTimeStr,
          message:
              'Tạo nhóm "$groupName" thành công. Đang thêm thành viên đã chọn...',
          type: LogType.success,
        ),
      ];

      // Add selected members logs
      for (final friendId in state.selectedFriendIds) {
        final friend = state.friends.firstWhere((f) => f.id == friendId);
        updatedLogs.add(
          LogItem(
            timestamp: completionTimeStr,
            message: 'Đã thêm thành viên: ${friend.name}',
            type: LogType.success,
          ),
        );
      }

      state = state.copyWith(logs: updatedLogs);
      _currentGroupIndex++;

      if (_currentGroupIndex < _groupNames.length) {
        final delayTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: delayTimeStr,
              message:
                  'Đang giãn cách ${state.minDelay}s trước khi tạo nhóm tiếp theo...',
              type: LogType.info,
            ),
          ],
        );

        _timer = Timer(const Duration(seconds: 3), () {
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
    state = state.copyWith(
      isRunning: false,
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message: finished
              ? 'Chiến dịch tự động tạo nhóm hoàn tất.'
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

final createGroupsProvider =
    StateNotifierProvider<CreateGroupsNotifier, CreateGroupsState>((ref) {
      return CreateGroupsNotifier();
    });
