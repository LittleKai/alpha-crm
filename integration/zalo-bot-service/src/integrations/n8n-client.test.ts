import test from 'node:test';
import assert from 'node:assert/strict';
import { toN8nCreateWorkflowRequest } from './n8n-client.js';

test('toN8nCreateWorkflowRequest strips Alpha CRM metadata before calling n8n API', () => {
  const request = toN8nCreateWorkflowRequest({
    name: 'Alpha CRM - Test',
    active: false,
    nodes: [{ id: 'node_1', parameters: {} }],
    connections: {},
    settings: { executionOrder: 'v1' },
    metadata: { alphaCrm: { templateId: 'tpl' } },
  });

  assert.deepEqual(request, {
    name: 'Alpha CRM - Test',
    active: false,
    nodes: [{ id: 'node_1', parameters: {} }],
    connections: {},
    settings: { executionOrder: 'v1' },
  });
});
