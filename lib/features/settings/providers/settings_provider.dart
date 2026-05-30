import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../mock/mock_accounts.dart';
import '../../../mock/mock_campaigns.dart';

class SettingsState {
  final SystemSettings settings;
  final List<ZaloAccount> accounts;
  final bool isLoading;
  final bool isSaved;
  final String? errorText;

  const SettingsState({
    required this.settings,
    required this.accounts,
    this.isLoading = false,
    this.isSaved = false,
    this.errorText,
  });

  SettingsState copyWith({
    SystemSettings? settings,
    List<ZaloAccount>? accounts,
    bool? isLoading,
    bool? isSaved,
    String? errorText,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      isSaved: isSaved ?? this.isSaved,
      errorText: errorText,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
    : super(
        SettingsState(
          settings: MockAccounts.defaultSettings,
          accounts: const [],
        ),
      );

  void updateProxy(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(proxy: value),
      isSaved: false,
    );
  }

  void updateMinDelay(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(minDelay: value),
      isSaved: false,
    );
  }

  void updateMaxDelay(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(maxDelay: value),
      isSaved: false,
    );
  }

  void updateAutoApproveFriend(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(autoApproveFriend: value),
      isSaved: false,
    );
  }

  void updateAutoSendWelcomeMessage(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(autoSendWelcomeMessage: value),
      isSaved: false,
    );
  }

  void updateWelcomeMessageText(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(welcomeMessageText: value),
      isSaved: false,
    );
  }

  void updateAutoAddFriendGroup(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(autoAddFriendGroup: value),
      isSaved: false,
    );
  }

  Future<void> saveSettings() async {
    if (state.settings.minDelay > state.settings.maxDelay) {
      state = state.copyWith(
        errorText: 'Thời gian delay tối thiểu không được lớn hơn delay tối đa.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorText: null);
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(isLoading: false, isSaved: true);
  }

  void resetSavedState() {
    state = state.copyWith(isSaved: false);
  }

  void addMockAccount() {
    final newAccount = ZaloAccount(
      id: (state.accounts.length + 1).toString(),
      name: 'Zalo Cá nhân - Tài khoản mới ${state.accounts.length + 1}',
      phone: '09${10000000 + state.accounts.length}',
      type: 'Cá nhân',
      isConnected: true,
    );
    state = state.copyWith(accounts: [...state.accounts, newAccount]);
  }

  void removeAccount(String id) {
    state = state.copyWith(
      accounts: state.accounts.where((acc) => acc.id != id).toList(),
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
