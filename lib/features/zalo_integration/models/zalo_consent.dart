/// Represents a consent record for a Zalo recipient.
class ZaloConsent {
  final String recipientId;
  final ZaloConsentSource source;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final String? evidence;

  const ZaloConsent({
    required this.recipientId,
    required this.source,
    required this.grantedAt,
    this.revokedAt,
    this.evidence,
  });

  bool get isActive => revokedAt == null;

  ZaloConsent copyWith({
    String? recipientId,
    ZaloConsentSource? source,
    DateTime? grantedAt,
    DateTime? revokedAt,
    String? evidence,
  }) {
    return ZaloConsent(
      recipientId: recipientId ?? this.recipientId,
      source: source ?? this.source,
      grantedAt: grantedAt ?? this.grantedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      evidence: evidence ?? this.evidence,
    );
  }
}

enum ZaloConsentSource {
  oaFollowed,
  formSubmission,
  manualImport,
  chatInteraction,
}
