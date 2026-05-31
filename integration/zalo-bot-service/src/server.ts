/**
 * Alpha CRM — Zalo Bot Service
 * Native Node.js HTTP server on port 8787.
 *
 * Endpoints:
 *   GET  /health           — Health check
 *   GET  /api/zalo/status  — Zalo connection status (channel-aware)
 *   POST /api/zalo/webhook — Receive Zalo webhook events
 *   POST /api/zalo/test-send   — Test send (no real API call)
 *   POST /api/zalo/send-message — Send message via active channel
 */

import { createServer, IncomingMessage, ServerResponse } from 'http';
import { config } from './config.js';
import { evaluateCompliance, ComplianceRequest } from './compliance.js';
import { getZaloStatus, sendMessage, handleWebhookEvent } from './zalo.js';

const VERSION = '0.2.0';

function setCorsHeaders(res: ServerResponse): void {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, x-bot-api-secret-token, x-zalo-webhook-secret',
  );
}

function json(res: ServerResponse, status: number, data: unknown): void {
  setCorsHeaders(res);
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on('data', (chunk: Buffer) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks).toString()));
    req.on('error', reject);
  });
}

function hasValidWebhookSecret(req: IncomingMessage): boolean {
  if (!config.zaloWebhookSecret) return false;
  const secret =
    req.headers['x-zalo-webhook-secret'] ||
    req.headers['x-bot-api-secret-token'];
  return secret === config.zaloWebhookSecret;
}

function isAllowedTestRecipient(recipientId: unknown): recipientId is string {
  return (
    typeof recipientId === 'string' &&
    recipientId.trim().length > 0 &&
    config.allowedTestUids.includes(recipientId.trim())
  );
}

interface SendPayload {
  recipientId: string;
  message: string;
  threadType?: 'user' | 'group';
  messageType?: 'text' | 'template';
  // Context for compliance — server reads enforcement flags from env config
  actionType?: ComplianceRequest['actionType'];
  targetCount?: number;
  hasConsentProof?: boolean;
  hasRecentInteraction?: boolean;
  isTestMode?: boolean;
}

function hasValidSendPayload(payload: unknown): payload is SendPayload {
  if (!payload || typeof payload !== 'object') return false;
  const data = payload as Record<string, unknown>;
  return (
    typeof data['recipientId'] === 'string' &&
    data['recipientId'].trim().length > 0 &&
    typeof data['message'] === 'string' &&
    data['message'].trim().length > 0
  );
}

const server = createServer(async (req, res) => {
  const url = req.url || '/';
  const method = req.method || 'GET';

  // Handle CORS preflight
  if (method === 'OPTIONS') {
    setCorsHeaders(res);
    res.writeHead(204);
    res.end();
    return;
  }

  // GET /health
  if (method === 'GET' && url === '/health') {
    json(res, 200, {
      status: 'ok',
      version: VERSION,
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    });
    return;
  }

  // GET /api/zalo/status
  if (method === 'GET' && url === '/api/zalo/status') {
    const status = getZaloStatus();
    json(res, 200, {
      ...status,
      version: VERSION,
    });
    return;
  }

  // POST /api/zalo/webhook
  if (method === 'POST' && url === '/api/zalo/webhook') {
    if (!hasValidWebhookSecret(req)) {
      json(res, 403, {
        error:
          'Webhook secret is missing, invalid, or not configured on the server.',
      });
      return;
    }

    try {
      const body = await readBody(req);
      const event = JSON.parse(body);
      handleWebhookEvent(event);
      json(res, 200, { received: true });
    } catch {
      json(res, 400, { error: 'Invalid JSON body' });
    }
    return;
  }

  // POST /api/zalo/test-send
  if (method === 'POST' && url === '/api/zalo/test-send') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const recipientId = payload.recipientId;

      if (!isAllowedTestRecipient(recipientId)) {
        json(res, 403, {
          error:
            'Test send recipient is not allowlisted in ZALO_ALLOWED_TEST_UIDS.',
        });
        return;
      }

      const result = await sendMessage(
        {
          recipientId,
          message: payload.message || 'Test message from Alpha CRM',
          threadType: payload.threadType,
        },
        true, // isTestMode = true
      );

      json(res, 200, result);
    } catch {
      json(res, 400, { error: 'Invalid request body' });
    }
    return;
  }

  // POST /api/zalo/send-message
  if (method === 'POST' && url === '/api/zalo/send-message') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);

      if (!hasValidSendPayload(payload)) {
        json(res, 400, {
          error: 'recipientId and message are required.',
        });
        return;
      }

      // Server-side compliance check (enforcement boundary)
      // Enforcement flags come from server config only, NOT from client payload
      const complianceReq: ComplianceRequest = {
        actionType: payload.actionType || 'bulk_message_to_friends',
        targetCount: payload.targetCount || 1,
        hasConsentProof: payload.hasConsentProof || false,
        hasRecentInteraction: payload.hasRecentInteraction || false,
        isTestMode: payload.isTestMode || false,
        // Server-tracked counters (TODO: wire to actual counters)
        dailySentCount: 0,
        recentFailureRate: 0,
        recentReportCount: 0,
      };

      const decision = evaluateCompliance(complianceReq);
      if (!decision.allowed) {
        json(res, 403, {
          error: 'Compliance check failed',
          riskLevel: decision.riskLevel,
          reason: decision.reason,
        });
        return;
      }

      const result = await sendMessage(
        {
          recipientId: payload.recipientId,
          message: payload.message,
          threadType: payload.threadType,
          messageType: payload.messageType,
        },
        payload.isTestMode || false,
      );

      json(res, result.success ? 200 : 500, result);
    } catch {
      json(res, 400, { error: 'Invalid request body' });
    }
    return;
  }

  // 404 for everything else
  json(res, 404, { error: 'Not found' });
});

server.listen(config.port, () => {
  console.log(`
╔══════════════════════════════════════════════╗
║  Alpha CRM — Zalo Bot Service v${VERSION}       ║
║  Running on http://localhost:${config.port}          ║
║  Channel: ${config.channelMode.padEnd(34)}║
║  Environment: ${config.nodeEnv.padEnd(30)}║
╚══════════════════════════════════════════════╝
  `);
});
