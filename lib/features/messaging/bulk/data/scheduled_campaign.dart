import 'dart:convert';

/// Lifecycle of a scheduled (pending) campaign while it sits in the queue.
/// `sent` jobs are removed from the queue, so only these three are ever stored.
enum ScheduledStatus {
  /// Armed with a Timer; will auto-launch at [ScheduledCampaign.scheduledAt].
  pending,

  /// The fire time passed while the app was closed → it was NOT auto-sent.
  missed,

  /// Auto-launch ran but the backend rejected it; kept so the user can retry.
  failed,
}

ScheduledStatus _statusFromString(String value) {
  return ScheduledStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ScheduledStatus.pending,
  );
}

class ScheduledRecipient {
  final String id; // phone / userId / groupId
  final String name;

  const ScheduledRecipient({required this.id, this.name = ''});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory ScheduledRecipient.fromJson(Map<String, dynamic> json) =>
      ScheduledRecipient(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
}

/// Immutable snapshot of a bulk campaign captured at the moment the user arms a
/// schedule. The send at fire time uses THIS snapshot, never the live compose
/// form, so editing the form afterwards never affects a queued campaign.
class ScheduledCampaign {
  final String id;
  final String name;
  final String message; // raw markdown; formatting applied at launch
  final bool isGroupMessage;
  final List<ScheduledRecipient> recipients;
  final List<String> attachments;
  final String? accountId;
  final int minDelay;
  final int maxDelay;
  final bool requireHumanApproval;
  final DateTime scheduledAt;
  final ScheduledStatus status;
  final DateTime createdAt;

  const ScheduledCampaign({
    required this.id,
    required this.name,
    required this.message,
    required this.isGroupMessage,
    required this.recipients,
    this.attachments = const [],
    required this.accountId,
    required this.minDelay,
    required this.maxDelay,
    required this.requireHumanApproval,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
  });

  ScheduledCampaign copyWith({
    DateTime? scheduledAt,
    ScheduledStatus? status,
    List<String>? attachments,
  }) {
    return ScheduledCampaign(
      id: id,
      name: name,
      message: message,
      isGroupMessage: isGroupMessage,
      recipients: recipients,
      attachments: attachments ?? this.attachments,
      accountId: accountId,
      minDelay: minDelay,
      maxDelay: maxDelay,
      requireHumanApproval: requireHumanApproval,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'message': message,
    'isGroupMessage': isGroupMessage ? 1 : 0,
    'recipientsJson': attachments.isEmpty
        ? jsonEncode(recipients.map((r) => r.toJson()).toList())
        : jsonEncode({
            'recipients': recipients.map((r) => r.toJson()).toList(),
            'attachments': attachments,
          }),
    'accountId': accountId,
    'minDelay': minDelay,
    'maxDelay': maxDelay,
    'requireHumanApproval': requireHumanApproval ? 1 : 0,
    'scheduledAt': scheduledAt.millisecondsSinceEpoch,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ScheduledCampaign.fromMap(Map<String, dynamic> map) {
    final decoded = jsonDecode((map['recipientsJson'] ?? '[]').toString());
    final List<dynamic> rawRecipients = decoded is Map
        ? (decoded['recipients'] as List? ?? const [])
        : (decoded as List? ?? const []);
    final List<String> attachments = decoded is Map
        ? ((decoded['attachments'] as List?) ?? const [])
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : const [];
    return ScheduledCampaign(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      isGroupMessage: (map['isGroupMessage'] ?? 0) == 1,
      recipients: rawRecipients
          .map((e) => ScheduledRecipient.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      attachments: attachments,
      accountId: map['accountId']?.toString(),
      minDelay: (map['minDelay'] ?? 30) as int,
      maxDelay: (map['maxDelay'] ?? 60) as int,
      requireHumanApproval: (map['requireHumanApproval'] ?? 0) == 1,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        (map['scheduledAt'] ?? 0) as int,
      ),
      status: _statusFromString((map['status'] ?? 'pending').toString()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] ?? 0) as int,
      ),
    );
  }
}
