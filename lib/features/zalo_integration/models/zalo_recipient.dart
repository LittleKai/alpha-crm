/// Represents a Zalo recipient with consent and risk metadata.
class ZaloRecipient {
  final String id;
  final String displayName;
  final String? phone;
  final ZaloRecipientChannel channel;
  final ZaloConsentStatus consentStatus;
  final bool hasRecentInteraction;
  final DateTime? lastInteractionAt;
  final String? blockedReason;

  const ZaloRecipient({
    required this.id,
    required this.displayName,
    this.phone,
    required this.channel,
    required this.consentStatus,
    this.hasRecentInteraction = false,
    this.lastInteractionAt,
    this.blockedReason,
  });

  bool get isSendable =>
      channel == ZaloRecipientChannel.officialAccount &&
      consentStatus == ZaloConsentStatus.optedIn &&
      blockedReason == null;

  ZaloRecipient copyWith({
    String? id,
    String? displayName,
    String? phone,
    ZaloRecipientChannel? channel,
    ZaloConsentStatus? consentStatus,
    bool? hasRecentInteraction,
    DateTime? lastInteractionAt,
    String? blockedReason,
  }) {
    return ZaloRecipient(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      channel: channel ?? this.channel,
      consentStatus: consentStatus ?? this.consentStatus,
      hasRecentInteraction: hasRecentInteraction ?? this.hasRecentInteraction,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      blockedReason: blockedReason ?? this.blockedReason,
    );
  }
}

enum ZaloRecipientChannel { officialAccount, personalAccount, mockLocal }

enum ZaloConsentStatus { optedIn, optedOut, unknown, blocked }
