export type CrmChannel = 'zalo_personal' | 'zalo_oa' | 'facebook_page';

export interface WorkflowTemplate {
  id: string;
  name: string;
  description: string;
  category: string;
  tags: string[];
  difficulty: 'easy' | 'medium' | 'advanced';
  supportedChannels: CrmChannel[];
  requiredConnections: string[];
  n8nWorkflow: {
    nodes: Array<Record<string, any>>;
    connections: Record<string, any>;
    settings?: Record<string, any>;
  };
}

export interface InstallWorkflowTemplateRequest {
  templateId: string;
  channel: CrmChannel;
  accountId?: string;
  pageId?: string;
  variables?: Record<string, unknown>;
  createInactive?: boolean;
}

export const workflowTemplates: WorkflowTemplate[] = [
  {
    id: 'zalo-ai-reply-suggestion',
    name: 'Gợi ý trả lời bằng AI',
    description: 'Nhận tin nhắn mới từ Zalo, gọi AI của Alpha CRM và gửi gợi ý trả lời về cloud relay.',
    category: 'ai',
    tags: ['ai', 'reply', 'zalo', 'goi y'],
    difficulty: 'easy',
    supportedChannels: ['zalo_personal', 'zalo_oa'],
    requiredConnections: ['Alpha CRM cloud relay', 'n8n webhook'],
    n8nWorkflow: {
      nodes: [
        {
          id: 'alpha_event',
          name: 'Alpha CRM Event',
          type: 'n8n-nodes-base.webhook',
          parameters: { path: '{{webhookPath}}', httpMethod: 'POST' },
        },
        {
          id: 'ai_suggest',
          name: 'AI Suggest Reply',
          type: 'n8n-nodes-base.httpRequest',
          parameters: {
            method: 'POST',
            url: '{{callbackUrl}}',
            body: { action: 'crm.ai.suggest_reply' },
          },
        },
      ],
      connections: {},
      settings: { executionOrder: 'v1' },
    },
  },
  {
    id: 'ai-classify-intent',
    name: 'AI phân loại intent',
    description: 'Phân loại nội dung hội thoại thành lead nóng, cần hỗ trợ, hoặc chăm sóc sau bán.',
    category: 'ai',
    tags: ['ai', 'phan loai', 'intent', 'zalo', 'facebook'],
    difficulty: 'medium',
    supportedChannels: ['zalo_personal', 'facebook_page'],
    requiredConnections: ['Alpha CRM AI quota', 'Alpha CRM cloud relay'],
    n8nWorkflow: {
      nodes: [
        {
          id: 'alpha_event',
          name: 'Alpha CRM Event',
          type: 'n8n-nodes-base.webhook',
          parameters: { path: '{{webhookPath}}', httpMethod: 'POST' },
        },
        {
          id: 'classify',
          name: 'Classify Intent',
          type: 'n8n-nodes-base.httpRequest',
          parameters: {
            method: 'POST',
            url: '{{callbackUrl}}',
            body: { action: 'crm.ai.classify_intent' },
          },
        },
      ],
      connections: {},
      settings: { executionOrder: 'v1' },
    },
  },
  {
    id: 'new-lead-to-crm',
    name: 'Tạo lead CRM từ hội thoại mới',
    description: 'Khi có khách nhắn lần đầu, chuẩn hóa dữ liệu và tạo hoặc cập nhật khách hàng trong CRM.',
    category: 'sales',
    tags: ['lead', 'crm', 'zalo', 'facebook'],
    difficulty: 'easy',
    supportedChannels: ['zalo_personal', 'facebook_page'],
    requiredConnections: ['Alpha CRM cloud relay'],
    n8nWorkflow: {
      nodes: [
        {
          id: 'alpha_event',
          name: 'Alpha CRM Event',
          type: 'n8n-nodes-base.webhook',
          parameters: { path: '{{webhookPath}}', httpMethod: 'POST' },
        },
        {
          id: 'upsert_customer',
          name: 'Upsert CRM Customer',
          type: 'n8n-nodes-base.httpRequest',
          parameters: {
            method: 'POST',
            url: '{{callbackUrl}}',
            body: { action: 'crm.customer.upsert' },
          },
        },
      ],
      connections: {},
      settings: { executionOrder: 'v1' },
    },
  },
  {
    id: 'off-hours-auto-reply',
    name: 'Trả lời ngoài giờ',
    description: 'Tự động phản hồi lịch sự ngoài giờ làm việc và tạo task follow-up cho nhân viên.',
    category: 'management',
    tags: ['ngoai gio', 'auto reply', 'task'],
    difficulty: 'easy',
    supportedChannels: ['zalo_personal', 'facebook_page'],
    requiredConnections: ['Alpha CRM cloud relay'],
    n8nWorkflow: {
      nodes: [
        {
          id: 'alpha_event',
          name: 'Alpha CRM Event',
          type: 'n8n-nodes-base.webhook',
          parameters: { path: '{{webhookPath}}', httpMethod: 'POST' },
        },
        {
          id: 'send_reply',
          name: 'Send Off-hours Reply',
          type: 'n8n-nodes-base.httpRequest',
          parameters: {
            method: 'POST',
            url: '{{callbackUrl}}',
            body: { action: 'crm.conversation.off_hours_reply' },
          },
        },
      ],
      connections: {},
      settings: { executionOrder: 'v1' },
    },
  },
  {
    id: 'important-message-alert',
    name: 'Cảnh báo tin nhắn quan trọng',
    description: 'Phát hiện từ khóa khẩn cấp và gửi thông báo tới email, Telegram hoặc dashboard.',
    category: 'notification',
    tags: ['alert', 'telegram', 'email', 'khan cap'],
    difficulty: 'medium',
    supportedChannels: ['zalo_personal', 'facebook_page'],
    requiredConnections: ['Notification channel'],
    n8nWorkflow: {
      nodes: [
        {
          id: 'alpha_event',
          name: 'Alpha CRM Event',
          type: 'n8n-nodes-base.webhook',
          parameters: { path: '{{webhookPath}}', httpMethod: 'POST' },
        },
        {
          id: 'notify',
          name: 'Notify Operator',
          type: 'n8n-nodes-base.httpRequest',
          parameters: {
            method: 'POST',
            url: '{{callbackUrl}}',
            body: { action: 'crm.notification.send' },
          },
        },
      ],
      connections: {},
      settings: { executionOrder: 'v1' },
    },
  },
  {
    id: 'facebook-new-message-to-crm',
    name: 'Facebook Messenger sang CRM',
    description: 'Nhận tin nhắn Page Messenger chính thức, tạo lead và đưa hội thoại vào Live Chat.',
    category: 'integration',
    tags: ['facebook', 'messenger', 'page', 'crm'],
    difficulty: 'medium',
    supportedChannels: ['facebook_page'],
    requiredConnections: ['Meta Page token', 'Alpha CRM cloud relay'],
    n8nWorkflow: {
      nodes: [
        {
          id: 'alpha_event',
          name: 'Alpha CRM Event',
          type: 'n8n-nodes-base.webhook',
          parameters: { path: '{{webhookPath}}', httpMethod: 'POST' },
        },
        {
          id: 'facebook_ingest',
          name: 'Ingest Facebook Message',
          type: 'n8n-nodes-base.httpRequest',
          parameters: {
            method: 'POST',
            url: '{{callbackUrl}}',
            body: { action: 'facebook.message.ingest' },
          },
        },
      ],
      connections: {},
      settings: { executionOrder: 'v1' },
    },
  },
];

export function filterTemplatesByChannel(channel: CrmChannel): WorkflowTemplate[] {
  return workflowTemplates.filter((template) => template.supportedChannels.includes(channel));
}

export function buildN8nWorkflowPayload(req: InstallWorkflowTemplateRequest): any {
  const template = workflowTemplates.find((item) => item.id === req.templateId);
  if (!template) {
    throw new Error(`Workflow template not found: ${req.templateId}`);
  }
  if (!template.supportedChannels.includes(req.channel)) {
    throw new Error(`Template ${template.id} does not support channel ${req.channel}.`);
  }

  const variables = {
    webhookPath: `alpha-crm/${template.id}`,
    callbackUrl: '',
    ...(req.variables || {}),
  };

  const renderedWorkflow = interpolateWorkflow(template.n8nWorkflow, variables);
  return {
    name: `Alpha CRM - ${template.name}`,
    active: req.createInactive === false,
    nodes: renderedWorkflow.nodes,
    connections: renderedWorkflow.connections,
    settings: renderedWorkflow.settings || {},
    metadata: {
      alphaCrm: {
        templateId: template.id,
        channel: req.channel,
        accountId: req.accountId || null,
        pageId: req.pageId || null,
      },
    },
  };
}

function interpolateWorkflow<T>(value: T, variables: Record<string, unknown>): T {
  if (typeof value === 'string') {
    return value.replace(/\{\{([a-zA-Z0-9_]+)\}\}/g, (_, key: string) => {
      const replacement = variables[key];
      return replacement === undefined || replacement === null ? '' : String(replacement);
    }) as T;
  }
  if (Array.isArray(value)) {
    return value.map((item) => interpolateWorkflow(item, variables)) as T;
  }
  if (value && typeof value === 'object') {
    const entries = Object.entries(value).map(([key, entryValue]) => [
      key,
      interpolateWorkflow(entryValue, variables),
    ]);
    return Object.fromEntries(entries) as T;
  }
  return value;
}
