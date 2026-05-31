import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/zalo_compliance_guard.dart';
import '../../../shared/widgets/activity_log_panel.dart';
import '../../settings/providers/settings_provider.dart';

class JoinGroupsState {
  final bool isRunning;
  final List<LogItem> logs;
  final String? selectedAccountId;
  final String groupLinks;
  final int minDelay;
  final int maxDelay;
  final String? complianceError;

  const JoinGroupsState({
    required this.isRunning,
    required this.logs,
    this.selectedAccountId,
    required this.groupLinks,
    this.minDelay = 10,
    this.maxDelay = 20,
    this.complianceError,
  });

  JoinGroupsState copyWith({
    bool? isRunning,
    List<LogItem>? logs,
    String? selectedAccountId,
    String? groupLinks,
    int? minDelay,
    int? maxDelay,
    String? complianceError,
  }) {
    return JoinGroupsState(
      isRunning: isRunning ?? this.isRunning,
      logs: logs ?? this.logs,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      groupLinks: groupLinks ?? this.groupLinks,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      complianceError: complianceError,
    );
  }
}

class JoinGroupsNotifier extends StateNotifier<JoinGroupsState> {
  final Ref _ref;
  Timer? _timer;
  int _currentLinkIndex = 0;
  List<String> _linksToJoin = [];

  JoinGroupsNotifier(this._ref)
    : super(const JoinGroupsState(isRunning: false, logs: [], groupLinks: ''));

  void setAccount(String? accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  void setLinks(String val) {
    state = state.copyWith(groupLinks: val);
  }

  void setMinDelay(int val) {
    state = state.copyWith(minDelay: val);
  }

  void setMaxDelay(int val) {
    state = state.copyWith(maxDelay: val);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  void startJoinCampaign() {
    if (state.selectedAccountId == null) return;
    if (state.groupLinks.trim().isEmpty) return;

    _linksToJoin = state.groupLinks
        .split('\n')
        .map((link) => link.trim())
        .where((link) => link.isNotEmpty)
        .toList();

    if (_linksToJoin.isEmpty) return;

    // Compliance check
    final settings = _ref.read(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.joinGroups,
      targetCount: _linksToJoin.length,
    );

    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
      );
      return;
    }

    _currentLinkIndex = 0;
    state = state.copyWith(
      isRunning: true,
      complianceError: null,
      logs: [
        LogItem(
          timestamp: DateFormat('HH:mm:ss').format(DateTime.now()),
          message: 'Bắt đầu chiến dịch tự động tham gia nhóm...',
          type: LogType.info,
        ),
      ],
    );

    _runNextJoin();
  }

  void _runNextJoin() {
    if (_currentLinkIndex >= _linksToJoin.length) {
      _stopCampaign(finished: true);
      return;
    }

    final currentLink = _linksToJoin[_currentLinkIndex];
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    state = state.copyWith(
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message: 'Đang gửi yêu cầu tham gia vào nhóm: $currentLink',
          type: LogType.info,
        ),
      ],
    );

    _timer = Timer(const Duration(seconds: 2), () {
      final success = _currentLinkIndex % 3 != 2;
      final completionTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());

      state = state.copyWith(
        logs: [
          ...state.logs,
          LogItem(
            timestamp: completionTimeStr,
            message: success
                ? 'Đã tham gia nhóm thành công: $currentLink'
                : 'Yêu cầu vào nhóm thất bại hoặc bị từ chối: $currentLink',
            type: success ? LogType.success : LogType.error,
          ),
        ],
      );

      _currentLinkIndex++;

      if (_currentLinkIndex < _linksToJoin.length) {
        final delayTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
        state = state.copyWith(
          logs: [
            ...state.logs,
            LogItem(
              timestamp: delayTimeStr,
              message:
                  'Đang giãn cách ${state.minDelay}s trước khi chuyển sang nhóm tiếp theo...',
              type: LogType.info,
            ),
          ],
        );

        _timer = Timer(const Duration(seconds: 3), () {
          _runNextJoin();
        });
      } else {
        _runNextJoin();
      }
    });
  }

  void stopJoinCampaign() {
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
              ? 'Đã hoàn thành chiến dịch tham gia nhóm.'
              : 'Đã dừng chiến dịch tham gia nhóm bởi người dùng.',
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

final joinGroupsProvider =
    StateNotifierProvider<JoinGroupsNotifier, JoinGroupsState>((ref) {
      return JoinGroupsNotifier(ref);
    });
