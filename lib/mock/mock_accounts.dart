class SystemSettings {
  final String proxy;
  final int minDelay;
  final int maxDelay;
  final bool autoApproveFriend;
  final bool autoSendWelcomeMessage;
  final String welcomeMessageText;
  final bool autoAddFriendGroup;

  const SystemSettings({
    required this.proxy,
    required this.minDelay,
    required this.maxDelay,
    required this.autoApproveFriend,
    required this.autoSendWelcomeMessage,
    required this.welcomeMessageText,
    required this.autoAddFriendGroup,
  });

  SystemSettings copyWith({
    String? proxy,
    int? minDelay,
    int? maxDelay,
    bool? autoApproveFriend,
    bool? autoSendWelcomeMessage,
    String? welcomeMessageText,
    bool? autoAddFriendGroup,
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
  );
}
