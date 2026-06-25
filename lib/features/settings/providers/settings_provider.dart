import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
      ) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final file = File('zalo_settings.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        final loadedSettings = SystemSettings.fromJson(jsonMap);
        state = state.copyWith(settings: loadedSettings);
        print('[SettingsNotifier] Loaded settings from zalo_settings.json');
      } else {
        await _saveSettingsToFile(state.settings);
      }
    } catch (e) {
      print('[SettingsNotifier] Error loading settings: $e');
    }
  }

  Future<void> _saveSettingsToFile(SystemSettings settings) async {
    try {
      final file = File('zalo_settings.json');
      final content = const JsonEncoder.withIndent(
        '  ',
      ).convert(settings.toJson());
      await file.writeAsString(content);
      print('[SettingsNotifier] Saved settings to zalo_settings.json');
    } catch (e) {
      print('[SettingsNotifier] Error saving settings: $e');
    }
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

  void updateDownloadFolder(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(downloadFolder: value),
      isSaved: false,
    );
  }

  void updateLiveChatMediaCacheMaxAgeDays(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        liveChatMediaCacheMaxAgeDays: value.clamp(1, 3650),
      ),
      isSaved: false,
    );
  }

  void updateLiveChatMediaCacheMaxGb(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        liveChatMediaCacheMaxGb: value.clamp(1, 1024),
      ),
      isSaved: false,
    );
  }

  Future<void> updateShowTokenAnalytics(bool value) async {
    state = state.copyWith(
      settings: state.settings.copyWith(showTokenAnalytics: value),
      isSaved: true,
    );
    await _saveSettingsToFile(state.settings);
  }

  Future<void> updateSummaryAiModel(String value) async {
    state = state.copyWith(
      settings: state.settings.copyWith(summaryAiModel: value),
      isSaved: true,
    );
    await _saveSettingsToFile(state.settings);
  }

  Future<void> updateLiveChatNotifications(bool value) async {
    state = state.copyWith(
      settings: state.settings.copyWith(liveChatNotifications: value),
      isSaved: true,
    );
    await _saveSettingsToFile(state.settings);
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

  // Zalo risk / compliance update methods

  void updateZaloChannelMode(ZaloChannelMode mode) {
    var updated = state.settings.copyWith(zaloChannelMode: mode);
    // Sync officialApiOnly for backward compatibility
    if (mode == ZaloChannelMode.officialOa) {
      updated = updated.copyWith(
        officialApiOnly: true,
        allowPersonalAccountAutomation: false,
        allowProxyUsage: false,
        allowFriendAutomation: false,
        allowGroupAutomation: false,
      );
    } else if (mode == ZaloChannelMode.personalZca) {
      updated = updated.copyWith(
        officialApiOnly: false,
        allowPersonalAccountAutomation: true,
      );
    } else {
      updated = updated.copyWith(officialApiOnly: false);
    }
    state = state.copyWith(settings: updated, isSaved: false);
  }

  void updateOfficialApiOnly(bool value) {
    // Delegate to channel mode for consistency
    updateZaloChannelMode(
      value ? ZaloChannelMode.officialOa : ZaloChannelMode.personalZca,
    );
  }

  void updateAllowPersonalAccountAutomation(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(allowPersonalAccountAutomation: value),
      isSaved: false,
    );
  }

  void updateAllowProxyUsage(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(allowProxyUsage: value),
      isSaved: false,
    );
  }

  void updateAllowFriendAutomation(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(allowFriendAutomation: value),
      isSaved: false,
    );
  }

  void updateAllowGroupAutomation(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(allowGroupAutomation: value),
      isSaved: false,
    );
  }

  void updateRequireConsentProof(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(requireConsentProof: value),
      isSaved: false,
    );
  }

  void updateRequireRecentInteraction(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(requireRecentInteraction: value),
      isSaved: false,
    );
  }

  void updateDisableSpintax(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(disableSpintax: value),
      isSaved: false,
    );
  }

  void updateRequireHumanApproval(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(requireHumanApproval: value),
      isSaved: false,
    );
  }

  void updateHumanApprovalThreshold(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(humanApprovalThreshold: value),
      isSaved: false,
    );
  }

  void updateMaxBatchSize(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(maxBatchSize: value),
      isSaved: false,
    );
  }

  void updateDailySendLimit(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(dailySendLimit: value),
      isSaved: false,
    );
  }

  void updatePerRecipientCooldownHours(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(perRecipientCooldownHours: value),
      isSaved: false,
    );
  }

  void updateMaxFailureRatePercent(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(maxFailureRatePercent: value),
      isSaved: false,
    );
  }

  void updateStopOnReportCount(int value) {
    state = state.copyWith(
      settings: state.settings.copyWith(stopOnReportCount: value),
      isSaved: false,
    );
  }

  void updateQuietHoursStart(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(quietHoursStart: value),
      isSaved: false,
    );
  }

  void updateQuietHoursEnd(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(quietHoursEnd: value),
      isSaved: false,
    );
  }

  void updateAutoReplyNewFriend(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(autoReplyNewFriend: value),
      isSaved: false,
    );
  }

  void updateZaloBackendBaseUrl(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(zaloBackendBaseUrl: value),
      isSaved: false,
    );
  }

  Future<void> setAppThemeMode(String value) async {
    final normalized = switch (value) {
      'dark' => 'dark',
      'system' => 'system',
      _ => 'light',
    };
    final updated = state.settings.copyWith(appThemeMode: normalized);
    state = state.copyWith(settings: updated, isSaved: false);
    await _saveSettingsToFile(updated);
  }

  Future<void> saveAccountNickname(String accountId, String nickname) async {
    final trimmedId = accountId.trim();
    if (trimmedId.isEmpty) return;

    final nicknames = Map<String, String>.from(state.settings.accountNicknames);
    final trimmedNickname = nickname.trim();
    if (trimmedNickname.isEmpty) {
      nicknames.remove(trimmedId);
    } else {
      nicknames[trimmedId] = trimmedNickname;
    }

    final updated = state.settings.copyWith(accountNicknames: nicknames);
    state = state.copyWith(settings: updated, isSaved: false);
    await _saveSettingsToFile(updated);
  }

  Future<void> saveSettings() async {
    final s = state.settings;

    if (s.minDelay > s.maxDelay) {
      state = state.copyWith(
        errorText: 'Thời gian delay tối thiểu không được lớn hơn delay tối đa.',
      );
      return;
    }

    if (s.maxBatchSize <= 0) {
      state = state.copyWith(errorText: 'Kích thước batch phải lớn hơn 0.');
      return;
    }

    if (s.dailySendLimit < s.maxBatchSize) {
      state = state.copyWith(
        errorText:
            'Giới hạn gửi hàng ngày phải lớn hơn hoặc bằng kích thước batch.',
      );
      return;
    }

    if (s.humanApprovalThreshold < 1) {
      state = state.copyWith(
        errorText: 'Ngưỡng duyệt thủ công phải ít nhất là 1.',
      );
      return;
    }

    if (s.maxFailureRatePercent < 1 || s.maxFailureRatePercent > 100) {
      state = state.copyWith(
        errorText: 'Tỷ lệ lỗi tối đa phải từ 1% đến 100%.',
      );
      return;
    }

    if (s.stopOnReportCount < 1) {
      state = state.copyWith(errorText: 'Số báo cáo dừng phải ít nhất là 1.');
      return;
    }

    final enforcedSettings = s.zaloChannelMode == ZaloChannelMode.officialOa
        ? s.copyWith(
            officialApiOnly: true,
            allowPersonalAccountAutomation: false,
            allowProxyUsage: false,
            allowFriendAutomation: false,
            allowGroupAutomation: false,
          )
        : s;

    state = state.copyWith(
      settings: enforcedSettings,
      isLoading: true,
      errorText: null,
    );
    await _saveSettingsToFile(enforcedSettings);
    try {
      await http
          .post(
            Uri.parse(
              '${enforcedSettings.localBridgeBaseUrl}/local/media-cache/settings',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'maxGb': enforcedSettings.liveChatMediaCacheMaxGb,
              'maxAgeDays': enforcedSettings.liveChatMediaCacheMaxAgeDays,
            }),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Settings remain persisted locally; the bridge applies them next save.
    }
    // Push risk-control settings to the local Zalo backend so server-side
    // compliance enforcement (quiet hours, daily limits, automation gates)
    // reflects the operator's choices instead of startup env defaults.
    try {
      await http
          .post(
            Uri.parse(
              '${enforcedSettings.zaloBackendBaseUrl}/api/zalo/compliance/settings',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'maxBatchSize': enforcedSettings.maxBatchSize,
              'dailySendLimit': enforcedSettings.dailySendLimit,
              'quietHoursStart': enforcedSettings.quietHoursStart,
              'quietHoursEnd': enforcedSettings.quietHoursEnd,
              'maxFailureRatePercent': enforcedSettings.maxFailureRatePercent,
              'stopOnReportCount': enforcedSettings.stopOnReportCount,
              'allowFriendAutomation': enforcedSettings.allowFriendAutomation,
              'allowGroupAutomation': enforcedSettings.allowGroupAutomation,
              'requireHumanApproval': enforcedSettings.requireHumanApproval,
              'humanApprovalThreshold': enforcedSettings.humanApprovalThreshold,
              'autoReplyNewFriend': enforcedSettings.autoReplyNewFriend,
            }),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Backend may be offline; settings are persisted locally and re-sent
      // on the next save. The backend also applies its own persisted copy.
    }
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(isLoading: false, isSaved: true);
  }

  Future<void> updateFontSettings(double multiplier, String family) async {
    final updated = state.settings.copyWith(
      fontSizeMultiplier: multiplier,
      fontFamily: family,
    );
    state = state.copyWith(settings: updated, isSaved: false);
    await _saveSettingsToFile(updated);
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
