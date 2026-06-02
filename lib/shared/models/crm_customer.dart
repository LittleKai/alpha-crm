class CrmCustomer {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String notes;
  final String status;
  final String zaloUserId;
  final String zaloThreadId;
  final List<String> tags;
  final String source;
  final String lifecycleStage;
  final String consentStatus;
  final String consentEvidence;
  final DateTime? lastInteractionAt;
  final DateTime? lastMessageAt;
  final Map<String, String> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CrmCustomer({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.notes,
    required this.status,
    required this.zaloUserId,
    required this.zaloThreadId,
    required this.tags,
    required this.source,
    required this.lifecycleStage,
    required this.consentStatus,
    required this.consentEvidence,
    this.lastInteractionAt,
    this.lastMessageAt,
    required this.customFields,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrmCustomer.fromJson(Map<String, dynamic> json) {
    return CrmCustomer(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'lead',
      zaloUserId: json['zaloUserId']?.toString() ?? '',
      zaloThreadId: json['zaloThreadId']?.toString() ?? '',
      tags: json['tags'] != null
          ? List<String>.from(json['tags'].map((t) => t.toString()))
          : const [],
      source: json['source']?.toString() ?? '',
      lifecycleStage: json['lifecycleStage']?.toString() ?? 'lead',
      consentStatus: json['consentStatus']?.toString() ?? 'pending',
      consentEvidence: json['consentEvidence']?.toString() ?? '',
      lastInteractionAt: json['lastInteractionAt'] != null
          ? DateTime.tryParse(json['lastInteractionAt'].toString())
          : null,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      customFields: json['customFields'] != null
          ? Map<String, String>.from(json['customFields'].map((k, v) => MapEntry(k.toString(), v.toString())))
          : const {},
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
      'name': name,
      'email': email,
      'phone': phone,
      'company': company,
      'notes': notes,
      'status': status,
      'zaloUserId': zaloUserId,
      'zaloThreadId': zaloThreadId,
      'tags': tags,
      'source': source,
      'lifecycleStage': lifecycleStage,
      'consentStatus': consentStatus,
      'consentEvidence': consentEvidence,
      if (lastInteractionAt != null) 'lastInteractionAt': lastInteractionAt!.toIso8601String(),
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt!.toIso8601String(),
      'customFields': customFields,
    };
  }
}
