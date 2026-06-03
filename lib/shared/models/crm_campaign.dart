class CrmCampaign {
  final String id;
  final String userId;
  final String name;
  final String templateId;
  final List<String> targetCustomerIds;
  final String channel;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String audienceType;
  final String targetSummary;
  final String? selectedDeviceId;
  final String? selectedAccountId;
  final int rateLimit;
  final bool requireHumanApproval;
  final Map<String, int> metrics;
  final DateTime? lastProgressAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CrmCampaign({
    required this.id,
    required this.userId,
    required this.name,
    required this.templateId,
    required this.targetCustomerIds,
    required this.channel,
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.finishedAt,
    required this.audienceType,
    required this.targetSummary,
    this.selectedDeviceId,
    this.selectedAccountId,
    required this.rateLimit,
    required this.requireHumanApproval,
    required this.metrics,
    this.lastProgressAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrmCampaign.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'] is Map
        ? Map<String, dynamic>.from(json['metrics'])
        : const {};
    final parsedMetrics = {
      'totalSent': rawMetrics['totalSent'] is int
          ? rawMetrics['totalSent'] as int
          : (int.tryParse(rawMetrics['totalSent']?.toString() ?? '0') ?? 0),
      'successCount': rawMetrics['successCount'] is int
          ? rawMetrics['successCount'] as int
          : (int.tryParse(rawMetrics['successCount']?.toString() ?? '0') ?? 0),
      'failedCount': rawMetrics['failedCount'] is int
          ? rawMetrics['failedCount'] as int
          : (int.tryParse(rawMetrics['failedCount']?.toString() ?? '0') ?? 0),
    };

    return CrmCampaign(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      templateId: json['templateId']?.toString() ?? '',
      targetCustomerIds: json['targetCustomerIds'] != null
          ? List<String>.from(
              json['targetCustomerIds'].map((id) => id.toString()),
            )
          : const [],
      channel: json['channel']?.toString() ?? 'zalo',
      status: json['status']?.toString() ?? 'draft',
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'].toString())
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.tryParse(json['finishedAt'].toString())
          : null,
      audienceType: json['audienceType']?.toString() ?? 'all',
      targetSummary: json['targetSummary']?.toString() ?? '',
      selectedDeviceId: json['selectedDeviceId']?.toString(),
      selectedAccountId: json['selectedAccountId']?.toString(),
      rateLimit: json['rateLimit'] is int
          ? json['rateLimit']
          : (int.tryParse(json['rateLimit']?.toString() ?? '30') ?? 30),
      requireHumanApproval: json['requireHumanApproval'] == true,
      metrics: parsedMetrics,
      lastProgressAt: json['lastProgressAt'] != null
          ? DateTime.tryParse(json['lastProgressAt'].toString())
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
      'name': name,
      'templateId': templateId,
      'targetCustomerIds': targetCustomerIds,
      'channel': channel,
      'status': status,
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
      if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
      'audienceType': audienceType,
      'targetSummary': targetSummary,
      if (selectedDeviceId != null) 'selectedDeviceId': selectedDeviceId,
      if (selectedAccountId != null) 'selectedAccountId': selectedAccountId,
      'rateLimit': rateLimit,
      'requireHumanApproval': requireHumanApproval,
      'metrics': metrics,
      if (lastProgressAt != null)
        'lastProgressAt': lastProgressAt!.toIso8601String(),
    };
  }
}
