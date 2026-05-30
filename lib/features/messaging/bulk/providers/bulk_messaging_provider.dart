import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../mock/mock_campaigns.dart';

class BulkMessagingState {
  final int
  selectedTab; // 0: Theo SĐT, 1: Vào nhóm, 2: Cho bạn bè, 3: Theo nhãn
  final String recipientsText;
  final int minDelay;
  final int maxDelay;
  final String messageText;
  final ZaloAccount? selectedAccount;
  final List<ZaloAccount> accounts;
  final bool isSending;
  final List<String> logs;
  final int successCount;
  final int failureCount;

  const BulkMessagingState({
    required this.selectedTab,
    required this.recipientsText,
    required this.minDelay,
    required this.maxDelay,
    required this.messageText,
    this.selectedAccount,
    required this.accounts,
    required this.isSending,
    required this.logs,
    required this.successCount,
    required this.failureCount,
  });

  factory BulkMessagingState.initial() {
    return const BulkMessagingState(
      selectedTab: 0,
      recipientsText: '',
      minDelay: 30,
      maxDelay: 60,
      messageText: '',
      selectedAccount: null,
      accounts: [],
      isSending: false,
      logs: [],
      successCount: 0,
      failureCount: 0,
    );
  }

  BulkMessagingState copyWith({
    int? selectedTab,
    String? recipientsText,
    int? minDelay,
    int? maxDelay,
    String? messageText,
    ZaloAccount? selectedAccount,
    List<ZaloAccount>? accounts,
    bool? isSending,
    List<String>? logs,
    int? successCount,
    int? failureCount,
  }) {
    return BulkMessagingState(
      selectedTab: selectedTab ?? this.selectedTab,
      recipientsText: recipientsText ?? this.recipientsText,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      messageText: messageText ?? this.messageText,
      selectedAccount: selectedAccount ?? this.selectedAccount,
      accounts: accounts ?? this.accounts,
      isSending: isSending ?? this.isSending,
      logs: logs ?? this.logs,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
    );
  }
}

class BulkMessagingNotifier extends StateNotifier<BulkMessagingState> {
  BulkMessagingNotifier() : super(BulkMessagingState.initial());

  void setSelectedTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  void setRecipientsText(String text) {
    state = state.copyWith(recipientsText: text);
  }

  void setMinDelay(int min) {
    state = state.copyWith(minDelay: min);
  }

  void setMaxDelay(int max) {
    state = state.copyWith(maxDelay: max);
  }

  void setMessageText(String text) {
    state = state.copyWith(messageText: text);
  }

  void selectAccount(ZaloAccount? account) {
    state = state.copyWith(selectedAccount: account);
  }

  void clearLogs() {
    state = state.copyWith(logs: [], successCount: 0, failureCount: 0);
  }

  void addLog(String log) {
    state = state.copyWith(logs: [...state.logs, log]);
  }

  Future<void> startSending() async {
    if (state.isSending) return;
    final recipients = state.recipientsText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (recipients.isEmpty || state.selectedAccount == null) return;

    state = state.copyWith(
      isSending: true,
      successCount: 0,
      failureCount: 0,
      logs: [
        '[Hệ thống] Bắt đầu chiến dịch gửi tin nhắn hàng loạt...',
        '[Hệ thống] Tài khoản gửi: ${state.selectedAccount!.name}',
      ],
    );

    // Simulate sending progress with intervals
    for (int i = 0; i < recipients.length; i++) {
      if (!state.isSending) break;
      final target = recipients[i];
      addLog('[Đang gửi] Gửi tin đến $target...');

      await Future.delayed(const Duration(milliseconds: 1000));

      if (!state.isSending) break;

      final isSuccess = i % 5 != 2; // Simulate some failures for realistic UI
      if (isSuccess) {
        state = state.copyWith(
          successCount: state.successCount + 1,
          logs: [...state.logs, '[Thành công] Gửi thành công tới $target!'],
        );
      } else {
        state = state.copyWith(
          failureCount: state.failureCount + 1,
          logs: [
            ...state.logs,
            '[Thất bại] Gửi thất bại tới $target (Lỗi kết nối)',
          ],
        );
      }
    }

    if (state.isSending) {
      state = state.copyWith(
        isSending: false,
        logs: [
          ...state.logs,
          '[Hệ thống] Chiến dịch hoàn tất. Thành công: ${state.successCount}, Thất bại: ${state.failureCount}',
        ],
      );
    }
  }

  void stopSending() {
    if (!state.isSending) return;
    state = state.copyWith(
      isSending: false,
      logs: [...state.logs, '[Hệ thống] Người dùng đã dừng chiến dịch.'],
    );
  }
}

final bulkMessagingProvider =
    StateNotifierProvider<BulkMessagingNotifier, BulkMessagingState>((ref) {
      return BulkMessagingNotifier();
    });
