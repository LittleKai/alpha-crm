class CrmTemplate {
  final String id;
  final String userId;
  final String name;
  final String subject;
  final String body;
  final String type;
  final List<String> variables;
  final String category;
  final String shortcut;
  final bool isQuick;
  final String status;
  final String language;
  final DateTime? lastUsedAt;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CrmTemplate({
    required this.id,
    required this.userId,
    required this.name,
    required this.subject,
    required this.body,
    required this.type,
    required this.variables,
    required this.category,
    required this.shortcut,
    required this.isQuick,
    required this.status,
    required this.language,
    this.lastUsedAt,
    required this.usageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrmTemplate.fromJson(Map<String, dynamic> json) {
    return CrmTemplate(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'zalo',
      variables: json['variables'] != null
          ? List<String>.from(json['variables'].map((v) => v.toString()))
          : const [],
      category: json['category']?.toString() ?? 'general',
      shortcut: json['shortcut']?.toString() ?? '',
      isQuick: json['isQuick'] == true,
      status: json['status']?.toString() ?? 'active',
      language: json['language']?.toString() ?? 'vi',
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'].toString())
          : null,
      usageCount: json['usageCount'] is int
          ? json['usageCount']
          : (int.tryParse(json['usageCount']?.toString() ?? '0') ?? 0),
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
      'subject': subject,
      'body': body,
      'type': type,
      'variables': variables,
      'category': category,
      'shortcut': shortcut,
      'isQuick': isQuick,
      'status': status,
      'language': language,
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
      'usageCount': usageCount,
    };
  }
}
