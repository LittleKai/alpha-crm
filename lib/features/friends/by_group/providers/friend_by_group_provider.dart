import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../mock/mock_groups.dart';
import '../../../../shared/utils/image_helper.dart';
import '../../../../shared/utils/zalo_compliance_guard.dart';
import '../../../../shared/widgets/activity_log_panel.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zalo_integration/data/zalo_integration_api.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../history/providers/friend_history_provider.dart';

class FriendByGroupState {
  final bool isScanning;
  final bool isRunning;
  final List<ZaloGroup> groups;
  final List<ScannedMember> members;
  final Set<String> selectedMemberIds;
  final List<LogItem> logs;
  
  final String? selectedGroupId;
  final String groupLinkInput;
  final String? selectedAccountId;
  
  final String messageText;
  final int minDelay;
  final int maxDelay;
  final bool sendInboxAfterAccepted;
  final String? complianceError;
  final String? errorText;

  const FriendByGroupState({
    required this.isScanning,
    required this.isRunning,
    required this.groups,
    required this.members,
    required this.selectedMemberIds,
    required this.logs,
    this.selectedGroupId,
    required this.groupLinkInput,
    this.selectedAccountId,
    this.messageText = 'Chào bạn, mình kết bạn nhé!',
    this.minDelay = 30,
    this.maxDelay = 60,
    this.sendInboxAfterAccepted = false,
    this.complianceError,
    this.errorText,
  });

  FriendByGroupState copyWith({
    bool? isScanning,
    bool? isRunning,
    List<ZaloGroup>? groups,
    List<ScannedMember>? members,
    Set<String>? selectedMemberIds,
    List<LogItem>? logs,
    String? selectedGroupId,
    String? groupLinkInput,
    String? selectedAccountId,
    String? messageText,
    int? minDelay,
    int? maxDelay,
    bool? sendInboxAfterAccepted,
    String? complianceError,
    String? errorText,
  }) {
    return FriendByGroupState(
      isScanning: isScanning ?? this.isScanning,
      isRunning: isRunning ?? this.isRunning,
      groups: groups ?? this.groups,
      members: members ?? this.members,
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      logs: logs ?? this.logs,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      groupLinkInput: groupLinkInput ?? this.groupLinkInput,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      messageText: messageText ?? this.messageText,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      sendInboxAfterAccepted: sendInboxAfterAccepted ?? this.sendInboxAfterAccepted,
      complianceError: complianceError,
      errorText: errorText,
    );
  }
}

class FriendByGroupNotifier extends StateNotifier<FriendByGroupState> {
  final Ref _ref;
  Timer? _timer;
  int _currentIndex = 0;
  List<String> _membersToInvite = [];

  FriendByGroupNotifier(this._ref)
      : super(const FriendByGroupState(
          isScanning: false,
          isRunning: false,
          groups: [],
          members: [],
          selectedMemberIds: {},
          logs: [],
          groupLinkInput: '',
        )) {
    // Initial fetch of groups if connected
    Future.microtask(() => loadGroups());
  }

  ZaloIntegrationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    return ZaloIntegrationApi(baseUrl: baseUrl);
  }

  bool get _isConnected => _ref.read(zaloIntegrationProvider).isConnected;

  void setAccount(String? accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  void setGroupLink(String val) {
    state = state.copyWith(groupLinkInput: val);
  }

  void setMessage(String val) {
    state = state.copyWith(messageText: val);
  }

  void setMinDelay(int val) {
    state = state.copyWith(minDelay: val);
  }

  void setMaxDelay(int val) {
    state = state.copyWith(maxDelay: val);
  }

  void setSendInboxAfterAccepted(bool val) {
    state = state.copyWith(sendInboxAfterAccepted: val);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  Future<void> loadGroups() async {
    if (!_isConnected) return;
    try {
      final api = _getApi();
      final response = await api.fetchGroups();
      if (response['success'] == true && response['groups'] != null) {
        final rawGroups = response['groups'] as List<dynamic>;
        final loadedGroups = rawGroups.map((g) {
          return ZaloGroup(
            id: g['id']?.toString() ?? '',
            name: g['name']?.toString() ?? '',
            memberCount: int.tryParse(g['memberCount']?.toString() ?? '0') ?? 0,
            role: g['role']?.toString() ?? 'member',
            avatarUrl: sanitizeImageUrl(g['avatar']?.toString() ?? ''),
            accountId: g['accountId']?.toString(),
          );
        }).toList();
        state = state.copyWith(groups: loadedGroups);
      }
    } catch (_) {}
  }

  Future<void> scanGroupLink(String link) async {
    if (link.trim().isEmpty || !link.contains('zalo.me/g/')) {
      state = state.copyWith(
        errorText: 'Link nhóm Zalo không hợp lệ. Định dạng yêu cầu: zalo.me/g/xxxxxx',
      );
      return;
    }

    state = state.copyWith(
      isScanning: true,
      errorText: null,
      selectedGroupId: null,
      members: [],
      selectedMemberIds: {},
    );

    if (_isConnected) {
      try {
        final api = _getApi();
        final response = await api.fetchGroupLinkMembers(link: link.trim());
        if (response['success'] == true && response['members'] != null) {
          final members = _parseMembers(response['members'] as List<dynamic>);
          state = state.copyWith(
            members: members,
            isScanning: false,
          );
          return;
        }
      } catch (e) {
        state = state.copyWith(isScanning: false, errorText: e.toString());
      }
    } else {
      // Mock fallback
      state = state.copyWith(
        members: MockGroups.flutterGroupMembers,
        isScanning: false,
      );
    }
  }

  Future<void> selectSavedGroup(String? groupId) async {
    if (groupId == null || groupId == 'none') {
      state = state.copyWith(
        members: [],
        selectedGroupId: null,
        selectedMemberIds: {},
      );
      return;
    }

    state = state.copyWith(
      isScanning: true,
      selectedGroupId: groupId,
      members: [],
      selectedMemberIds: {},
    );

    if (_isConnected) {
      try {
        final api = _getApi();
        final response = await api.fetchGroupMembers(groupId: groupId);
        if (response['success'] == true && response['members'] != null) {
          final members = _parseMembers(response['members'] as List<dynamic>);
          state = state.copyWith(
            members: members,
            isScanning: false,
          );
          return;
        }
      } catch (e) {
        state = state.copyWith(isScanning: false, errorText: e.toString());
      }
    } else {
      // Mock fallback
      List<ScannedMember> loadedMembers = MockGroups.flutterGroupMembers;
      if (groupId == 'g2') loadedMembers = MockGroups.startupGroupMembers;
      state = state.copyWith(members: loadedMembers, isScanning: false);
    }
  }

  List<ScannedMember> _parseMembers(List<dynamic> rawMembers) {
    return rawMembers.map((m) {
      final role = m['role'] as String? ?? 'member';
      String roleLabel;
      switch (role) {
        case 'owner':
          roleLabel = 'Trưởng nhóm';
          break;
        case 'admin':
          roleLabel = 'Phó nhóm';
          break;
        default:
          roleLabel = 'Thành viên';
      }
      return ScannedMember(
        id: m['id']?.toString() ?? '',
        name: m['displayName']?.toString() ?? m['zaloName']?.toString() ?? '',
        phone: '',
        role: roleLabel,
        status: 'Chưa kết bạn',
        avatarUrl: sanitizeImageUrl(m['avatar']?.toString() ?? ''),
      );
    }).toList();
  }

  void toggleMember(String memberId) {
    final updated = Set<String>.from(state.selectedMemberIds);
    if (updated.contains(memberId)) {
      updated.remove(memberId);
    } else {
      updated.add(memberId);
    }
    state = state.copyWith(selectedMemberIds: updated);
  }

  void toggleAllMembers(List<ScannedMember> visibleMembers) {
    final updated = Set<String>.from(state.selectedMemberIds);
    final allSelected = visibleMembers.every((m) => updated.contains(m.id));

    if (allSelected) {
      for (final m in visibleMembers) {
        updated.remove(m.id);
      }
    } else {
      for (final m in visibleMembers) {
        updated.add(m.id);
      }
    }
    state = state.copyWith(selectedMemberIds: updated);
  }

  void startCampaign() {
    if (state.selectedAccountId == null) return;
    if (state.selectedMemberIds.isEmpty) return;

    _membersToInvite = state.selectedMemberIds.toList();

    // Compliance Check
    final settings = _ref.read(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.friendByGroup,
      targetCount: _membersToInvite.length,
    );

    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
      );
      return;
    }

    _currentIndex = 0;
    state = state.copyWith(
      isRunning: true,
      complianceError: null,
      logs: [
        LogItem(
          timestamp: DateFormat('HH:mm:ss').format(DateTime.now()),
          message: 'Bắt đầu chiến dịch kết bạn từ Nhóm Zalo...',
          type: LogType.info,
        ),
      ],
    );

    _runNext();
  }

  void _runNext() {
    if (_currentIndex >= _membersToInvite.length) {
      _stopCampaign(finished: true);
      return;
    }

    final currentId = _membersToInvite[_currentIndex];
    final member = state.members.firstWhere((m) => m.id == currentId,
        orElse: () => ScannedMember(
            id: currentId,
            name: 'Thành viên nhóm',
            phone: '',
            role: 'Thành viên',
            status: 'Chưa kết bạn'));
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    state = state.copyWith(
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message: '[$_currentIndex] Đang gửi yêu cầu kết bạn đến: "${member.name}"',
          type: LogType.info,
        ),
      ],
    );

    _timer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final api = _getApi();
        
        // Step: Send friend request directly with uid
        final sendResult = await api.sendFriendRequest(
          userId: currentId,
          message: state.messageText,
          actionType: 'friend_by_group',
          accountId: state.selectedAccountId,
        );

        final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        final accountLabel = _ref
            .read(zaloIntegrationProvider)
            .accounts
            .firstWhere((acc) => acc.id == state.selectedAccountId,
                orElse: () => const ZaloConnectedAccount(
                    id: '',
                    label: 'Tài khoản nguồn',
                    connected: false,
                    listenerRunning: false))
            .label;

        if (sendResult['success'] == true) {
          state = state.copyWith(
            logs: [
              ...state.logs,
              LogItem(
                timestamp: completionTimeStr,
                message: 'Gửi yêu cầu kết bạn THÀNH CÔNG đến: "${member.name}"',
                type: LogType.success,
              ),
            ],
          );

          // Log to Friend History
          _ref.read(friendHistoryProvider.notifier).addRecord(
            FriendHistoryRecord(
              id: 'fh_${DateTime.now().millisecondsSinceEpoch}',
              targetName: member.name,
              targetPhone: 'Quét từ nhóm',
              accountLabel: accountLabel,
              timestamp: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
              status: 'Thành công',
              message: state.messageText,
            ),
          );
        } else {
          final errorMsg = sendResult['error'] ?? 'Gửi lời mời thất bại';
          state = state.copyWith(
            logs: [
              ...state.logs,
              LogItem(
                timestamp: completionTimeStr,
                message: 'Gửi lời mời THẤT BẠI: $errorMsg ("${member.name}")',
                type: LogType.error,
              ),
            ],
          );

          _ref.read(friendHistoryProvider.notifier).addRecord(
            FriendHistoryRecord(
              id: 'fh_${DateTime.now().millisecondsSinceEpoch}',
              targetName: member.name,
              targetPhone: 'Quét từ nhóm',
              accountLabel: accountLabel,
              timestamp: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
              status: 'Thất bại',
              message: '$errorMsg',
            ),
          );
        }
      } catch (err) {
        final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: completionTimeStr,
              message: 'Lỗi mạng khi thực hiện kết bạn cho ${member.name}: $err',
              type: LogType.error,
            ),
          ],
        );
      }

      _currentIndex++;

      if (_currentIndex < _membersToInvite.length) {
        final delaySeconds = state.minDelay +
            (state.maxDelay > state.minDelay
                ? (state.maxDelay - state.minDelay)
                : 0);
        final delayTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: delayTimeStr,
              message: 'Đang giãn cách ${delaySeconds}s trước khi chuyển sang thành viên tiếp theo...',
              type: LogType.info,
            ),
          ],
        );

        _timer = Timer(Duration(seconds: delaySeconds), () {
          _runNext();
        });
      } else {
        _runNext();
      }
    });
  }

  void stopCampaign() {
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
              ? 'Đã hoàn thành chiến dịch kết bạn từ nhóm.'
              : 'Đã dừng chiến dịch kết bạn bởi người dùng.',
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

final friendByGroupProvider =
    StateNotifierProvider<FriendByGroupNotifier, FriendByGroupState>((ref) {
  return FriendByGroupNotifier(ref);
});
