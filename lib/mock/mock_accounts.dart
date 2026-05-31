enum ZaloChannelMode { personalZca, officialOa, mock }

class SystemSettings {
  final String proxy;
  final int minDelay;
  final int maxDelay;
  final bool autoApproveFriend;
  final bool autoSendWelcomeMessage;
  final String welcomeMessageText;
  final bool autoAddFriendGroup;

  // Zalo channel mode (new source of truth)
  final ZaloChannelMode zaloChannelMode;

  // Zalo risk / compliance settings
  final bool officialApiOnly;
  final bool allowPersonalAccountAutomation;
  final bool allowProxyUsage;
  final bool allowFriendAutomation;
  final bool allowGroupAutomation;
  final bool requireConsentProof;
  final bool requireRecentInteraction;
  final bool disableSpintax;
  final bool requireHumanApproval;
  final int humanApprovalThreshold;
  final int maxBatchSize;
  final int dailySendLimit;
  final int perRecipientCooldownHours;
  final int maxFailureRatePercent;
  final int stopOnReportCount;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool allowTestModeOnlyForRiskyActions;
  final String zaloBackendBaseUrl;
  final String zaloWebhookPath;

  const SystemSettings({
    required this.proxy,
    required this.minDelay,
    required this.maxDelay,
    required this.autoApproveFriend,
    required this.autoSendWelcomeMessage,
    required this.welcomeMessageText,
    required this.autoAddFriendGroup,
    this.zaloChannelMode = ZaloChannelMode.personalZca,
    this.officialApiOnly = false,
    this.allowPersonalAccountAutomation = true,
    this.allowProxyUsage = false,
    this.allowFriendAutomation = false,
    this.allowGroupAutomation = false,
    this.requireConsentProof = true,
    this.requireRecentInteraction = false,
    this.disableSpintax = true,
    this.requireHumanApproval = true,
    this.humanApprovalThreshold = 20,
    this.maxBatchSize = 20,
    this.dailySendLimit = 100,
    this.perRecipientCooldownHours = 24,
    this.maxFailureRatePercent = 10,
    this.stopOnReportCount = 1,
    this.quietHoursStart = '21:00',
    this.quietHoursEnd = '08:00',
    this.allowTestModeOnlyForRiskyActions = true,
    this.zaloBackendBaseUrl = 'http://localhost:8787',
    this.zaloWebhookPath = '/api/zalo/webhook',
  });

  SystemSettings copyWith({
    String? proxy,
    int? minDelay,
    int? maxDelay,
    bool? autoApproveFriend,
    bool? autoSendWelcomeMessage,
    String? welcomeMessageText,
    bool? autoAddFriendGroup,
    ZaloChannelMode? zaloChannelMode,
    bool? officialApiOnly,
    bool? allowPersonalAccountAutomation,
    bool? allowProxyUsage,
    bool? allowFriendAutomation,
    bool? allowGroupAutomation,
    bool? requireConsentProof,
    bool? requireRecentInteraction,
    bool? disableSpintax,
    bool? requireHumanApproval,
    int? humanApprovalThreshold,
    int? maxBatchSize,
    int? dailySendLimit,
    int? perRecipientCooldownHours,
    int? maxFailureRatePercent,
    int? stopOnReportCount,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? allowTestModeOnlyForRiskyActions,
    String? zaloBackendBaseUrl,
    String? zaloWebhookPath,
  }) {
    return SystemSettings(
      proxy: proxy ?? this.proxy,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      autoApproveFriend: autoApproveFriend ?? this.autoApproveFriend,
      autoSendWelcomeMessage:
          autoSendWelcomeMessage ?? this.autoSendWelcomeMessage,
      welcomeMessageText: welcomeMessageText ?? this.welcomeMessageText,
      autoAddFriendGroup: autoAddFriendGroup ?? this.autoAddFriendGroup,
      zaloChannelMode: zaloChannelMode ?? this.zaloChannelMode,
      officialApiOnly: officialApiOnly ?? this.officialApiOnly,
      allowPersonalAccountAutomation:
          allowPersonalAccountAutomation ?? this.allowPersonalAccountAutomation,
      allowProxyUsage: allowProxyUsage ?? this.allowProxyUsage,
      allowFriendAutomation:
          allowFriendAutomation ?? this.allowFriendAutomation,
      allowGroupAutomation: allowGroupAutomation ?? this.allowGroupAutomation,
      requireConsentProof: requireConsentProof ?? this.requireConsentProof,
      requireRecentInteraction:
          requireRecentInteraction ?? this.requireRecentInteraction,
      disableSpintax: disableSpintax ?? this.disableSpintax,
      requireHumanApproval: requireHumanApproval ?? this.requireHumanApproval,
      humanApprovalThreshold:
          humanApprovalThreshold ?? this.humanApprovalThreshold,
      maxBatchSize: maxBatchSize ?? this.maxBatchSize,
      dailySendLimit: dailySendLimit ?? this.dailySendLimit,
      perRecipientCooldownHours:
          perRecipientCooldownHours ?? this.perRecipientCooldownHours,
      maxFailureRatePercent:
          maxFailureRatePercent ?? this.maxFailureRatePercent,
      stopOnReportCount: stopOnReportCount ?? this.stopOnReportCount,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      allowTestModeOnlyForRiskyActions: allowTestModeOnlyForRiskyActions ??
          this.allowTestModeOnlyForRiskyActions,
      zaloBackendBaseUrl: zaloBackendBaseUrl ?? this.zaloBackendBaseUrl,
      zaloWebhookPath: zaloWebhookPath ?? this.zaloWebhookPath,
    );
  }
}

class MockAccounts {
  static const SystemSettings defaultSettings = SystemSettings(
    proxy: '',
    minDelay: 30,
    maxDelay: 60,
    autoApproveFriend: false,
    autoSendWelcomeMessage: false,
    welcomeMessageText: 'Chào bạn! Rất vui được kết nối.',
    autoAddFriendGroup: false,
    zaloChannelMode: ZaloChannelMode.personalZca,
    officialApiOnly: false,
    allowPersonalAccountAutomation: true,
    allowProxyUsage: false,
    allowFriendAutomation: false,
    allowGroupAutomation: false,
    requireConsentProof: true,
    requireRecentInteraction: false,
    disableSpintax: true,
    requireHumanApproval: true,
    humanApprovalThreshold: 20,
    maxBatchSize: 20,
    dailySendLimit: 100,
    perRecipientCooldownHours: 24,
    maxFailureRatePercent: 10,
    stopOnReportCount: 1,
    quietHoursStart: '21:00',
    quietHoursEnd: '08:00',
    allowTestModeOnlyForRiskyActions: true,
    zaloBackendBaseUrl: 'http://localhost:8787',
    zaloWebhookPath: '/api/zalo/webhook',
  );
}
