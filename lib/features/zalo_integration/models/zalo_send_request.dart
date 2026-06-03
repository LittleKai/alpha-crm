import 'zalo_recipient.dart';

/// Represents a validated send request with compliance metadata.
class ZaloSendRequest {
  final ZaloRecipient recipient;
  final String message;
  final String? messageType;
  final bool isTestMode;
  final ZaloSendRiskLevel riskLevel;
  final String? blockedReason;

  const ZaloSendRequest({
    required this.recipient,
    required this.message,
    this.messageType,
    this.isTestMode = false,
    this.riskLevel = ZaloSendRiskLevel.low,
    this.blockedReason,
  });

  bool get canSend => blockedReason == null && recipient.isSendable;

  ZaloSendRequest copyWith({
    ZaloRecipient? recipient,
    String? message,
    String? messageType,
    bool? isTestMode,
    ZaloSendRiskLevel? riskLevel,
    String? blockedReason,
  }) {
    return ZaloSendRequest(
      recipient: recipient ?? this.recipient,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
      isTestMode: isTestMode ?? this.isTestMode,
      riskLevel: riskLevel ?? this.riskLevel,
      blockedReason: blockedReason ?? this.blockedReason,
    );
  }
}

enum ZaloSendRiskLevel { low, medium, high, critical }
