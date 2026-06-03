import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';

class AutoApproveState {
  final bool autoApprove;
  final bool sendWelcome;
  final String welcomeMessage;
  final int runningAccountsCount;

  const AutoApproveState({
    required this.autoApprove,
    required this.sendWelcome,
    required this.welcomeMessage,
    required this.runningAccountsCount,
  });
}

class AutoApproveNotifier extends StateNotifier<AutoApproveState> {
  final Ref _ref;

  AutoApproveNotifier(this._ref)
    : super(
        AutoApproveState(
          autoApprove: _ref.read(settingsProvider).settings.autoApproveFriend,
          sendWelcome: _ref
              .read(settingsProvider)
              .settings
              .autoSendWelcomeMessage,
          welcomeMessage: _ref
              .read(settingsProvider)
              .settings
              .welcomeMessageText,
          runningAccountsCount: _ref
              .read(zaloIntegrationProvider)
              .accounts
              .length,
        ),
      ) {
    // Listen to settings changes to keep this state in sync
    _ref.listen<SettingsState>(settingsProvider, (previous, next) {
      state = AutoApproveState(
        autoApprove: next.settings.autoApproveFriend,
        sendWelcome: next.settings.autoSendWelcomeMessage,
        welcomeMessage: next.settings.welcomeMessageText,
        runningAccountsCount: _ref
            .read(zaloIntegrationProvider)
            .accounts
            .length,
      );
    });

    // Listen to account changes
    _ref.listen<ZaloIntegrationState>(zaloIntegrationProvider, (
      previous,
      next,
    ) {
      state = AutoApproveState(
        autoApprove: _ref.read(settingsProvider).settings.autoApproveFriend,
        sendWelcome: _ref
            .read(settingsProvider)
            .settings
            .autoSendWelcomeMessage,
        welcomeMessage: _ref.read(settingsProvider).settings.welcomeMessageText,
        runningAccountsCount: next.accounts.length,
      );
    });
  }

  void toggleAutoApprove(bool val) {
    _ref.read(settingsProvider.notifier).updateAutoApproveFriend(val);
  }

  void toggleSendWelcome(bool val) {
    _ref.read(settingsProvider.notifier).updateAutoSendWelcomeMessage(val);
  }

  void updateWelcomeMessage(String val) {
    _ref.read(settingsProvider.notifier).updateWelcomeMessageText(val);
  }
}

final autoApproveProvider =
    StateNotifierProvider<AutoApproveNotifier, AutoApproveState>((ref) {
      return AutoApproveNotifier(ref);
    });
