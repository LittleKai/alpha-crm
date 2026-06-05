import 'workflow_models.dart';

const List<WorkflowTemplate> workflowTemplateCatalog = [
  WorkflowTemplate(
    id: 'zalo-ai-reply-suggestion',
    name: 'Gợi ý trả lời bằng AI',
    description:
        'Nhận tin nhắn mới từ Zalo, gọi AI của Alpha CRM và gửi gợi ý trả lời về cloud relay.',
    category: WorkflowTemplateCategory.ai,
    tags: ['ai', 'reply', 'zalo', 'goi y'],
    iconName: 'smart_toy',
    difficulty: WorkflowDifficulty.easy,
    supportedChannels: [CrmChannel.zaloPersonal, CrmChannel.zaloOa],
    requiredConnections: ['Alpha CRM cloud relay', 'n8n webhook'],
    n8nWorkflow: {
      'nodes': [
        {
          'id': 'alpha_event',
          'name': 'Alpha CRM Event',
          'type': 'n8n-nodes-base.webhook',
          'parameters': {'path': '{{webhookPath}}', 'httpMethod': 'POST'},
        },
        {
          'id': 'ai_suggest',
          'name': 'AI Suggest Reply',
          'type': 'n8n-nodes-base.httpRequest',
          'parameters': {
            'method': 'POST',
            'url': '{{callbackUrl}}',
            'body': {'action': 'crm.ai.suggest_reply'},
          },
        },
      ],
      'connections': {},
      'settings': {'executionOrder': 'v1'},
    },
  ),
  WorkflowTemplate(
    id: 'ai-classify-intent',
    name: 'AI phân loại intent',
    description:
        'Phân loại nội dung hội thoại thành lead nóng, cần hỗ trợ, hoặc chăm sóc sau bán.',
    category: WorkflowTemplateCategory.ai,
    tags: ['ai', 'phan loai', 'intent', 'zalo', 'facebook'],
    iconName: 'psychology',
    difficulty: WorkflowDifficulty.medium,
    supportedChannels: [CrmChannel.zaloPersonal, CrmChannel.facebookPage],
    requiredConnections: ['Alpha CRM AI quota', 'Alpha CRM cloud relay'],
    n8nWorkflow: {
      'nodes': [
        {
          'id': 'alpha_event',
          'name': 'Alpha CRM Event',
          'type': 'n8n-nodes-base.webhook',
          'parameters': {'path': '{{webhookPath}}', 'httpMethod': 'POST'},
        },
        {
          'id': 'classify',
          'name': 'Classify Intent',
          'type': 'n8n-nodes-base.httpRequest',
          'parameters': {
            'method': 'POST',
            'url': '{{callbackUrl}}',
            'body': {'action': 'crm.ai.classify_intent'},
          },
        },
      ],
      'connections': {},
      'settings': {'executionOrder': 'v1'},
    },
  ),
  WorkflowTemplate(
    id: 'new-lead-to-crm',
    name: 'Tạo lead CRM từ hội thoại mới',
    description:
        'Khi có khách nhắn lần đầu, chuẩn hóa dữ liệu và tạo hoặc cập nhật khách hàng trong CRM.',
    category: WorkflowTemplateCategory.sales,
    tags: ['lead', 'crm', 'zalo', 'facebook'],
    iconName: 'person_add',
    difficulty: WorkflowDifficulty.easy,
    supportedChannels: [CrmChannel.zaloPersonal, CrmChannel.facebookPage],
    requiredConnections: ['Alpha CRM cloud relay'],
    n8nWorkflow: {
      'nodes': [
        {
          'id': 'alpha_event',
          'name': 'Alpha CRM Event',
          'type': 'n8n-nodes-base.webhook',
          'parameters': {'path': '{{webhookPath}}', 'httpMethod': 'POST'},
        },
        {
          'id': 'upsert_customer',
          'name': 'Upsert CRM Customer',
          'type': 'n8n-nodes-base.httpRequest',
          'parameters': {
            'method': 'POST',
            'url': '{{callbackUrl}}',
            'body': {'action': 'crm.customer.upsert'},
          },
        },
      ],
      'connections': {},
      'settings': {'executionOrder': 'v1'},
    },
  ),
  WorkflowTemplate(
    id: 'off-hours-auto-reply',
    name: 'Trả lời ngoài giờ',
    description:
        'Tự động phản hồi lịch sự ngoài giờ làm việc và tạo task follow-up cho nhân viên.',
    category: WorkflowTemplateCategory.management,
    tags: ['ngoai gio', 'auto reply', 'task'],
    iconName: 'schedule',
    difficulty: WorkflowDifficulty.easy,
    supportedChannels: [CrmChannel.zaloPersonal, CrmChannel.facebookPage],
    requiredConnections: ['Alpha CRM cloud relay'],
    n8nWorkflow: {
      'nodes': [
        {
          'id': 'alpha_event',
          'name': 'Alpha CRM Event',
          'type': 'n8n-nodes-base.webhook',
          'parameters': {'path': '{{webhookPath}}', 'httpMethod': 'POST'},
        },
        {
          'id': 'send_reply',
          'name': 'Send Off-hours Reply',
          'type': 'n8n-nodes-base.httpRequest',
          'parameters': {
            'method': 'POST',
            'url': '{{callbackUrl}}',
            'body': {'action': 'crm.conversation.off_hours_reply'},
          },
        },
      ],
      'connections': {},
      'settings': {'executionOrder': 'v1'},
    },
  ),
  WorkflowTemplate(
    id: 'important-message-alert',
    name: 'Cảnh báo tin nhắn quan trọng',
    description:
        'Phát hiện từ khóa khẩn cấp và gửi thông báo tới email, Telegram hoặc dashboard.',
    category: WorkflowTemplateCategory.notification,
    tags: ['alert', 'telegram', 'email', 'khẩn cấp'],
    iconName: 'notifications',
    difficulty: WorkflowDifficulty.medium,
    supportedChannels: [CrmChannel.zaloPersonal, CrmChannel.facebookPage],
    requiredConnections: ['Notification channel'],
    n8nWorkflow: {
      'nodes': [
        {
          'id': 'alpha_event',
          'name': 'Alpha CRM Event',
          'type': 'n8n-nodes-base.webhook',
          'parameters': {'path': '{{webhookPath}}', 'httpMethod': 'POST'},
        },
        {
          'id': 'notify',
          'name': 'Notify Operator',
          'type': 'n8n-nodes-base.httpRequest',
          'parameters': {
            'method': 'POST',
            'url': '{{callbackUrl}}',
            'body': {'action': 'crm.notification.send'},
          },
        },
      ],
      'connections': {},
      'settings': {'executionOrder': 'v1'},
    },
  ),
  WorkflowTemplate(
    id: 'facebook-new-message-to-crm',
    name: 'Facebook Messenger sang CRM',
    description:
        'Nhận tin nhắn Page Messenger chính thức, tạo lead và đưa hội thoại vào Live Chat.',
    category: WorkflowTemplateCategory.integration,
    tags: ['facebook', 'messenger', 'page', 'crm'],
    iconName: 'facebook',
    difficulty: WorkflowDifficulty.medium,
    supportedChannels: [CrmChannel.facebookPage],
    requiredConnections: ['Meta Page token', 'Alpha CRM cloud relay'],
    n8nWorkflow: {
      'nodes': [
        {
          'id': 'alpha_event',
          'name': 'Alpha CRM Event',
          'type': 'n8n-nodes-base.webhook',
          'parameters': {'path': '{{webhookPath}}', 'httpMethod': 'POST'},
        },
        {
          'id': 'facebook_ingest',
          'name': 'Ingest Facebook Message',
          'type': 'n8n-nodes-base.httpRequest',
          'parameters': {
            'method': 'POST',
            'url': '{{callbackUrl}}',
            'body': {'action': 'facebook.message.ingest'},
          },
        },
      ],
      'connections': {},
      'settings': {'executionOrder': 'v1'},
    },
  ),
];

List<WorkflowTemplate> filterWorkflowTemplates(
  List<WorkflowTemplate> templates, {
  WorkflowTemplateCategory? category,
  CrmChannel? channel,
  String searchQuery = '',
}) {
  final query = searchQuery.trim().toLowerCase();
  return templates
      .where((template) {
        final matchesCategory =
            category == null || template.category == category;
        final matchesChannel =
            channel == null || template.supportsChannel(channel);
        final haystack = [
          template.name,
          template.description,
          ...template.tags,
        ].join(' ').toLowerCase();
        final matchesSearch = query.isEmpty || haystack.contains(query);
        return matchesCategory && matchesChannel && matchesSearch;
      })
      .toList(growable: false);
}
