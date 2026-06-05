import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildN8nWorkflowPayload,
  filterTemplatesByChannel,
  workflowTemplates,
} from './workflow-templates.js';

test('workflow catalog includes Zalo and Facebook Page templates', () => {
  assert.ok(workflowTemplates.length >= 6);
  assert.ok(filterTemplatesByChannel('zalo_personal').length > 0);
  assert.ok(filterTemplatesByChannel('facebook_page').length > 0);
});

test('buildN8nWorkflowPayload creates inactive Alpha CRM workflow and injects variables', () => {
  const payload = buildN8nWorkflowPayload({
    templateId: 'zalo-ai-reply-suggestion',
    channel: 'zalo_personal',
    accountId: 'zalo_1',
    variables: {
      webhookPath: 'alpha-crm/zalo-ai',
      callbackUrl: 'https://alpha.example/api/crm/n8n/actions',
    },
    createInactive: true,
  });

  assert.equal(payload.active, false);
  assert.match(payload.name, /^Alpha CRM - /);
  assert.equal(payload.nodes[0].parameters.path, 'alpha-crm/zalo-ai');
  assert.equal(payload.nodes.at(-1)?.parameters.url, 'https://alpha.example/api/crm/n8n/actions');
  assert.equal(payload.metadata.alphaCrm.templateId, 'zalo-ai-reply-suggestion');
  assert.equal(payload.metadata.alphaCrm.channel, 'zalo_personal');
  assert.equal(payload.metadata.alphaCrm.accountId, 'zalo_1');
});
