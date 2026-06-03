class CrmExecutionLog {
  final String id;
  final String userId;
  final String? campaignId;
  final String customerId;
  final String channel;
  final String status;
  final Map<String, dynamic> details;
  final String errorMessage;
  final String? deviceId;
  final String? accountId;
  final String? templateId;
  final String? recipientId;
  final String recipientPhone;
  final String recipientName;
  final String threadType;
  final String messagePreview;
  final String providerMessageId;
  final DateTime? attemptedAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final Map<String, dynamic>? campaignSnapshot;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CrmExecutionLog({
    required this.id,
    required this.userId,
    this.campaignId,
    required this.customerId,
    required this.channel,
    required this.status,
    required this.details,
    required this.errorMessage,
    this.deviceId,
    this.accountId,
    this.templateId,
    this.recipientId,
    required this.recipientPhone,
    required this.recipientName,
    required this.threadType,
    required this.messagePreview,
    required this.providerMessageId,
    this.attemptedAt,
    this.sentAt,
    this.deliveredAt,
    this.failedAt,
    this.campaignSnapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrmExecutionLog.fromJson(Map<String, dynamic> json) {
    return CrmExecutionLog(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      campaignId: json['campaignId']?.toString(),
      customerId: json['customerId']?.toString() ?? '',
      channel: json['channel']?.toString() ?? 'zalo',
      status: json['status']?.toString() ?? 'queued',
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'])
          : const {},
      errorMessage: json['errorMessage']?.toString() ?? '',
      deviceId: json['deviceId']?.toString(),
      accountId: json['accountId']?.toString(),
      templateId: json['templateId']?.toString(),
      recipientId: json['recipientId']?.toString(),
      recipientPhone: json['recipientPhone']?.toString() ?? '',
      recipientName: json['recipientName']?.toString() ?? '',
      threadType: json['threadType']?.toString() ?? 'zalo',
      messagePreview: json['messagePreview']?.toString() ?? '',
      providerMessageId: json['providerMessageId']?.toString() ?? '',
      attemptedAt: json['attemptedAt'] != null
          ? DateTime.tryParse(json['attemptedAt'].toString())
          : null,
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString())
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      failedAt: json['failedAt'] != null
          ? DateTime.tryParse(json['failedAt'].toString())
          : null,
      campaignSnapshot: json['campaignSnapshot'] is Map
          ? Map<String, dynamic>.from(json['campaignSnapshot'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (campaignId != null) 'campaignId': campaignId,
      'customerId': customerId,
      'channel': channel,
      'status': status,
      'details': details,
      'errorMessage': errorMessage,
      if (deviceId != null) 'deviceId': deviceId,
      if (accountId != null) 'accountId': accountId,
      if (templateId != null) 'templateId': templateId,
      if (recipientId != null) 'recipientId': recipientId,
      'recipientPhone': recipientPhone,
      'recipientName': recipientName,
      'threadType': threadType,
      'messagePreview': messagePreview,
      'providerMessageId': providerMessageId,
      if (attemptedAt != null) 'attemptedAt': attemptedAt!.toIso8601String(),
      if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
      if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
      if (failedAt != null) 'failedAt': failedAt!.toIso8601String(),
      if (campaignSnapshot != null) 'campaignSnapshot': campaignSnapshot,
    };
  }
}
