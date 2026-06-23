import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/utils/zalo_compliance_guard.dart';
import '../../../../shared/widgets/activity_log_panel.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zalo_integration/data/zalo_integration_api.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../history/providers/friend_history_provider.dart';

class FriendByPhoneState {
  final bool isRunning;
  final List<LogItem> logs;
  final String? selectedAccountId;
  final String phoneListText;
  final String messageText;
  final int minDelay;
  final int maxDelay;
  final bool sendInboxAfterAccepted;
  final String? complianceError;

  const FriendByPhoneState({
    required this.isRunning,
    required this.logs,
    this.selectedAccountId,
    required this.phoneListText,
    this.messageText = 'Chào bạn, mình kết bạn nhé!',
    this.minDelay = 30,
    this.maxDelay = 60,
    this.sendInboxAfterAccepted = false,
    this.complianceError,
  });

  FriendByPhoneState copyWith({
    bool? isRunning,
    List<LogItem>? logs,
    String? selectedAccountId,
    String? phoneListText,
    String? messageText,
    int? minDelay,
    int? maxDelay,
    bool? sendInboxAfterAccepted,
    String? complianceError,
  }) {
    return FriendByPhoneState(
      isRunning: isRunning ?? this.isRunning,
      logs: logs ?? this.logs,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      phoneListText: phoneListText ?? this.phoneListText,
      messageText: messageText ?? this.messageText,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      sendInboxAfterAccepted:
          sendInboxAfterAccepted ?? this.sendInboxAfterAccepted,
      complianceError: complianceError,
    );
  }
}

class FriendByPhoneNotifier extends StateNotifier<FriendByPhoneState> {
  final Ref _ref;
  Timer? _timer;
  int _currentIndex = 0;
  List<String> _phones = [];

  FriendByPhoneNotifier(this._ref)
    : super(
        const FriendByPhoneState(isRunning: false, logs: [], phoneListText: ''),
      );

  ZaloIntegrationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    return ZaloIntegrationApi(baseUrl: baseUrl);
  }

  void setAccount(String? accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  void setPhones(String val) {
    state = state.copyWith(phoneListText: val);
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

  void startCampaign() {
    if (state.selectedAccountId == null) return;
    if (state.phoneListText.trim().isEmpty) return;

    _phones = state.phoneListText
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (_phones.isEmpty) return;

    // Compliance Check
    final settings = _ref.read(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.friendByPhone,
      targetCount: _phones.length,
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
          message: 'Bắt đầu chiến dịch kết bạn theo Số điện thoại...',
          type: LogType.info,
        ),
      ],
    );

    _runNext();
  }

  void _runNext() {
    if (_currentIndex >= _phones.length) {
      _stopCampaign(finished: true);
      return;
    }

    final currentPhone = _phones[_currentIndex];
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    state = state.copyWith(
      logs: [
        ...state.logs,
        LogItem(
          timestamp: timeStr,
          message:
              '[$_currentIndex] Đang tìm kiếm tài khoản Zalo cho SĐT: $currentPhone',
          type: LogType.info,
        ),
      ],
    );

    // Short gap before calling API
    _timer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final api = _getApi();

        // Step 1: Search User profile
        final searchResult = await api.searchUserByPhone(
          phone: currentPhone,
          accountId: state.selectedAccountId,
        );
        final stepTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());

        if (searchResult['success'] == true && searchResult['user'] != null) {
          final user = searchResult['user'];
          final userId = user['uid']?.toString() ?? '';
          final displayName =
              user['display_name']?.toString() ??
              user['zalo_name']?.toString() ??
              'Khách Hàng';

          state = state.copyWith(
            logs: [
              ...state.logs,
              LogItem(
                timestamp: stepTimeStr,
                message:
                    'Tìm thấy Zalo: "$displayName" (ID: $userId). Đang gửi lời mời kết bạn...',
                type: LogType.info,
              ),
            ],
          );

          // Step 2: Send friend request
          final sendResult = await api.sendFriendRequest(
            userId: userId,
            message: state.messageText,
            actionType: 'friend_by_phone',
            accountId: state.selectedAccountId,
          );

          final completionTimeStr = DateFormat(
            'HH:mm:ss',
          ).format(DateTime.now());
          final accountLabel = _ref
              .read(zaloIntegrationProvider)
              .accounts
              .firstWhere(
                (acc) => acc.id == state.selectedAccountId,
                orElse: () => const ZaloConnectedAccount(
                  id: '',
                  label: 'Tài khoản nguồn',
                  connected: false,
                  listenerRunning: false,
                ),
              )
              .label;

          if (sendResult['success'] == true) {
            state = state.copyWith(
              logs: [
                ...state.logs,
                LogItem(
                  timestamp: completionTimeStr,
                  message:
                      'Gửi yêu cầu kết bạn THÀNH CÔNG đến: "$displayName" ($currentPhone)',
                  type: LogType.success,
                ),
              ],
            );

            // Log to Friend History
            _ref
                .read(friendHistoryProvider.notifier)
                .addRecord(
                  FriendHistoryRecord(
                    id: 'fh_${DateTime.now().millisecondsSinceEpoch}',
                    targetName: displayName,
                    targetPhone: currentPhone,
                    accountLabel: accountLabel,
                    timestamp: DateFormat(
                      'dd/MM/yyyy HH:mm:ss',
                    ).format(DateTime.now()),
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
                  message: 'Gửi lời mời THẤT BẠI: $errorMsg ($currentPhone)',
                  type: LogType.error,
                ),
              ],
            );

            _ref
                .read(friendHistoryProvider.notifier)
                .addRecord(
                  FriendHistoryRecord(
                    id: 'fh_${DateTime.now().millisecondsSinceEpoch}',
                    targetName: displayName,
                    targetPhone: currentPhone,
                    accountLabel: accountLabel,
                    timestamp: DateFormat(
                      'dd/MM/yyyy HH:mm:ss',
                    ).format(DateTime.now()),
                    status: 'Thất bại',
                    message: '$errorMsg',
                  ),
                );
          }
        } else {
          final errorMsg =
              searchResult['error'] ?? 'Không tìm thấy tài khoản Zalo liên kết';
          state = state.copyWith(
            logs: [
              ...state.logs,
              LogItem(
                timestamp: stepTimeStr,
                message:
                    'Không tìm thấy tài khoản Zalo cho SĐT: $currentPhone ($errorMsg)',
                type: LogType.warning,
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
              message: 'Lỗi mạng khi thực hiện kết bạn cho $currentPhone: $err',
              type: LogType.error,
            ),
          ],
        );

        _ref.read(friendHistoryProvider.notifier).addRecord(
              FriendHistoryRecord(
                id: 'fh_${DateTime.now().millisecondsSinceEpoch}',
                targetName: currentPhone, // We might not have the display name
                targetPhone: currentPhone,
                accountLabel: 'Không rõ',
                timestamp: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
                status: 'Thất bại',
                message: 'Lỗi ngoại lệ: $err',
              ),
            );
      }

      _currentIndex++;

      if (_currentIndex < _phones.length) {
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
                  'Đang giãn cách ${delaySeconds}s trước khi xử lý SĐT tiếp theo...',
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
              ? 'Đã hoàn thành chiến dịch kết bạn theo SĐT.'
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

final friendByPhoneProvider =
    StateNotifierProvider<FriendByPhoneNotifier, FriendByPhoneState>((ref) {
      return FriendByPhoneNotifier(ref);
    });
