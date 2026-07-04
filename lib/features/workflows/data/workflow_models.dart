import '../../../shared/models/crm_channel.dart';

export '../../../shared/models/crm_channel.dart';

enum WorkflowTemplateCategory {
  sales('ban_hang', 'Bán hàng'),
  management('quan_ly', 'Quản lý'),
  marketing('marketing', 'Marketing'),
  notification('thong_bao', 'Thông báo'),
  ai('ai', 'AI'),
  integration('tich_hop', 'Tích hợp');

  final String apiValue;
  final String label;

  const WorkflowTemplateCategory(this.apiValue, this.label);
}

enum WorkflowDifficulty {
  easy('easy', 'Dễ'),
  medium('medium', 'Trung bình'),
  advanced('advanced', 'Nâng cao');

  final String apiValue;
  final String label;

  const WorkflowDifficulty(this.apiValue, this.label);
}

class WorkflowTemplate {
  final String id;
  final String name;
  final String description;
  final WorkflowTemplateCategory category;
  final List<String> tags;
  final String iconName;
  final WorkflowDifficulty difficulty;
  final List<CrmChannel> supportedChannels;
  final List<String> requiredConnections;
  final Map<String, dynamic> n8nWorkflow;

  const WorkflowTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tags,
    required this.iconName,
    required this.difficulty,
    required this.supportedChannels,
    required this.requiredConnections,
    required this.n8nWorkflow,
  });

  bool supportsChannel(CrmChannel channel) {
    return supportedChannels.contains(channel);
  }
}

class WorkflowTemplateInstallRequest {
  final String templateId;
  final CrmChannel channel;
  final String? accountId;
  final String? pageId;
  final Map<String, dynamic> variables;
  final bool createInactive;

  const WorkflowTemplateInstallRequest({
    required this.templateId,
    required this.channel,
    this.accountId,
    this.pageId,
    this.variables = const {},
    this.createInactive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'templateId': templateId,
      'channel': channel.apiValue,
      'accountId': accountId,
      'pageId': pageId,
      'variables': variables,
      'createInactive': createInactive,
    };
  }
}
