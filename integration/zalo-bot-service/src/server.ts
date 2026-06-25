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
import { config, dataRoot, projectRoot } from './config.js';
import { evaluateCompliance, ComplianceRequest } from './compliance.js';
import { getZaloStatus, sendMessage, handleWebhookEvent, getAllGroups, leaveGroup, getAccounts, updateAccountSettings, deleteAccount, getAllFriends, getGroupMembers, getGroupLinkMembers, createGroup, joinGroup, inviteToGroup, findUser, sendFriendRequest, acceptFriendRequest } from './zalo.js';
import { existsSync, createReadStream, writeFileSync, unlinkSync, readFileSync, mkdirSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { LoginQRCallbackEventType } from 'zca-js';
import type { LoginQRCallback, LoginQRCallbackEvent } from 'zca-js';
import { addAccountInstance, createZaloClient } from './channels/personal-zca-channel.js';
import { writeSecure } from './secure-store.js';
import { getAgentCredentials } from './agent/agent-identity.js';
import { startPairingSession } from './agent/cloud-api.js';
import { maskIntegrationSettings, readIntegrationSettings, writeIntegrationSettings } from './integrations/integration-store.js';
import { readRiskControlSettings, writeRiskControlSettings, applyRiskControlToConfig } from './risk-control-store.js';
import { N8nClient } from './integrations/n8n-client.js';
import { buildN8nWorkflowPayload, workflowTemplates } from './integrations/workflow-templates.js';
import { testProxyConnection } from './integrations/proxy-helper.js';
import { handleLocalRoute } from './local-chat/local-chat-api.js';
import { handleLocalSessionRoute } from './local-session/local-session-api.js';
import { saveClientLog, getClientLogs, deleteClientLogs } from './agent/client-log.js';
import {
  sessionCoordinator,
  sessionEventHub,
  shutdownSessionRuntime,
  resumeRuntimeFromStoredCredentials,
} from './local-session/session-runtime.js';

const VERSION = '0.2.0';
const SERVICE_ID = 'alpha-crm-zalo-bot-service';
let activePort = config.localBindPort;

if (!['127.0.0.1', 'localhost', '::1'].includes(config.localBindHost)) {
  throw new Error('LOCAL_BIND_HOST must be a loopback address.');
}

interface PendingSession {
  id: string;
  qrFileName: string;
  status: 'pending' | 'success' | 'failed' | 'timeout';
  error?: string;
  accountLabel?: string;
}
const pendingSessions = new Map<string, PendingSession>();

function setCorsHeaders(res: ServerResponse, req?: IncomingMessage): void {
  let origin = '*';
  if (req && req.headers.origin) {
    const reqOrigin = req.headers.origin;
    const isLocalhost = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(reqOrigin);
    const isTrustedDomain = [
      'https://giaiphapsangtao.com',
      'https://alphastudio.vercel.app'
    ].includes(reqOrigin);
    
    if (reqOrigin === 'null' || isLocalhost || isTrustedDomain) {
      origin = reqOrigin;
    } else {
      origin = 'null';
    }
  }
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, x-bot-api-secret-token, x-zalo-webhook-secret',
  );
}

function json(res: ServerResponse, status: number, data: unknown, req?: IncomingMessage): void {
  setCorsHeaders(res, req);
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
  accountId?: string;
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
    setCorsHeaders(res, req);
    res.writeHead(204);
    res.end();
    return;
  }

  if (await handleLocalSessionRoute(
    method,
    url,
    req,
    res,
    json,
    sessionCoordinator,
    sessionEventHub,
  )) {
    return;
  }

  // Handle local-first Live Chat APIs
  if (handleLocalRoute(method, url, req, res, json, readBody)) {
    return;
  }

  // GET /health
  if (method === 'GET' && url === '/health') {
    const credentials = getAgentCredentials();
    const zaloStatus = getZaloStatus();
    json(res, 200, {
      status: 'ok',
      service: SERVICE_ID,
      version: VERSION,
      pid: process.pid,
      projectRoot,
      dataRoot,
      bindHost: config.localBindHost,
      bindPort: activePort,
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      agent: {
        mode: config.crmAgentMode,
        registered: credentials !== null,
        deviceId: credentials ? credentials.deviceId : null,
        error: null
      },
      zalo: {
        channel: config.channelMode,
        status: zaloStatus.connected ? 'online' : 'offline',
        error: null
      }
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

  // GET /api/integrations/n8n/settings
  if (method === 'GET' && url === '/api/integrations/n8n/settings') {
    const settings = readIntegrationSettings();
    json(res, 200, { success: true, settings: maskIntegrationSettings(settings) });
    return;
  }

  // GET /api/zalo/compliance/settings
  if (method === 'GET' && url === '/api/zalo/compliance/settings') {
    json(res, 200, { success: true, settings: readRiskControlSettings() });
    return;
  }

  // POST|PUT /api/zalo/compliance/settings
  // Client (Flutter risk-control UI) pushes its settings; backend persists and
  // applies them to the live compliance config.
  if ((method === 'POST' || method === 'PUT') && url === '/api/zalo/compliance/settings') {
    try {
      const payload = JSON.parse(await readBody(req));
      const saved = writeRiskControlSettings(payload);
      json(res, 200, { success: true, settings: saved });
    } catch (err) {
      json(res, 400, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST|PUT /api/integrations/n8n/settings
  if ((method === 'POST' || method === 'PUT') && url === '/api/integrations/n8n/settings') {
    try {
      const current = readIntegrationSettings();
      const payload = JSON.parse(await readBody(req));
      const incomingN8n = payload.n8n || {};
      const incomingApiKey = typeof incomingN8n.apiKey === 'string' ? incomingN8n.apiKey.trim() : '';
      const apiKey = incomingApiKey.includes('*') ? current.n8n.apiKey : incomingApiKey;
      const saved = writeIntegrationSettings({
        ...current,
        n8n: {
          ...current.n8n,
          ...incomingN8n,
          apiKey,
        },
        facebook: {
          ...current.facebook,
          ...(payload.facebook || {}),
        },
      });
      json(res, 200, { success: true, settings: maskIntegrationSettings(saved) });
    } catch (err) {
      json(res, 400, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/integrations/n8n/test
  if (method === 'POST' && url === '/api/integrations/n8n/test') {
    try {
      const current = readIntegrationSettings();
      const payload = JSON.parse(await readBody(req) || '{}');
      const incoming = payload.n8n || {};
      const apiKey = typeof incoming.apiKey === 'string' && !incoming.apiKey.includes('*')
        ? incoming.apiKey
        : current.n8n.apiKey;
      const client = new N8nClient({
        baseUrl: incoming.baseUrl || current.n8n.baseUrl,
        apiKey,
      });
      const result = await client.testConnection();
      json(res, result.success ? 200 : 400, result);
    } catch (err) {
      json(res, 400, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // GET /api/integrations/n8n/templates
  if (method === 'GET' && url === '/api/integrations/n8n/templates') {
    json(res, 200, { success: true, templates: workflowTemplates });
    return;
  }

  // GET /api/integrations/n8n/workflows
  if (method === 'GET' && url === '/api/integrations/n8n/workflows') {
    try {
      const settings = readIntegrationSettings();
      const client = new N8nClient(settings.n8n);
      const workflows = await client.listWorkflows();
      json(res, 200, { success: true, workflows });
    } catch (err) {
      json(res, 400, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/integrations/n8n/templates/install
  if (method === 'POST' && url === '/api/integrations/n8n/templates/install') {
    try {
      const settings = readIntegrationSettings();
      if (!settings.n8n.baseUrl || !settings.n8n.apiKey) {
        json(res, 400, { success: false, error: 'n8n settings are missing.' });
        return;
      }
      const payload = JSON.parse(await readBody(req));
      const workflowPayload = buildN8nWorkflowPayload({
        ...payload,
        variables: {
          callbackUrl: settings.n8n.callbackUrl,
          ...(payload.variables || {}),
        },
      });
      const client = new N8nClient(settings.n8n);
      const workflow = await client.createWorkflow(workflowPayload);
      json(res, 200, {
        success: true,
        workflow,
        metadata: workflowPayload.metadata,
      });
    } catch (err) {
      json(res, 400, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/proxy/test
  if (method === 'POST' && url === '/api/proxy/test') {
    try {
      const payload = JSON.parse(await readBody(req));
      const proxy = typeof payload.proxy === 'string' ? payload.proxy : '';
      const result = await testProxyConnection(proxy);
      json(res, result.success ? 200 : 400, result);
    } catch (err) {
      json(res, 400, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // GET /api/agent/pairing/start
  if (method === 'GET' && url === '/api/agent/pairing/start') {
    try {
      const credentials = getAgentCredentials();
      if (!credentials) {
        json(res, 400, { success: false, error: 'Thiết bị chưa được đăng ký Agent.' });
        return;
      }
      const pairingData = await startPairingSession(credentials.deviceId, credentials.agentSecret);
      
      const qrPayload = {
        type: 'alpha_crm_pairing',
        apiBaseUrl: config.crmCloudApiUrl,
        pairingToken: pairingData.qrToken
      };

      json(res, 200, {
        success: true,
        ...pairingData,
        qrPayload
      });
    } catch (err: any) {
      json(res, 500, { success: false, error: err.message });
    }
    return;
  }

  // GET /api/zalo/accounts
  if (method === 'GET' && url === '/api/zalo/accounts') {
    try {
      const accounts = getAccounts();
      json(res, 200, { success: true, accounts });
    } catch (err) {
      json(res, 500, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/zalo/accounts/settings
  if (method === 'POST' && url === '/api/zalo/accounts/settings') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const accountId = payload.accountId;

      if (!accountId || typeof accountId !== 'string') {
        json(res, 400, { success: false, error: 'accountId is required.' });
        return;
      }

      const success = await updateAccountSettings(accountId, {
        proxy: payload.proxy,
        blockSeen: payload.blockSeen,
        blockTyping: payload.blockTyping,
      });
      json(res, success ? 200 : 404, { success });
    } catch (err) {
      json(res, 400, { success: false, error: 'Invalid request body or account settings update failed.' });
    }
    return;
  }

  // POST /api/zalo/accounts/delete
  if (method === 'POST' && url === '/api/zalo/accounts/delete') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const accountId = payload.accountId;

      if (!accountId || typeof accountId !== 'string') {
        json(res, 400, { error: 'accountId is required.' });
        return;
      }

      console.log(`[server] Unlinking account: ${accountId}`);
      const success = await deleteAccount(accountId);
      json(res, success ? 200 : 500, { success });
    } catch (err) {
      json(res, 400, { error: 'Invalid request body or unlink failed.' });
    }
    return;
  }

  // GET /api/zalo/accounts/create-qr
  if (method === 'GET' && url === '/api/zalo/accounts/create-qr') {
    try {
      const sessionId = `session_${Date.now()}`;
      const qrFileName = `qr_${sessionId}.png`;

      const credPath = resolve(projectRoot, config.personalCredentialsPath);
      const credDir = dirname(credPath);
      const qrPath = resolve(credDir, qrFileName);

      console.log(`[server - ${sessionId}] Starting QR authentication...`);

      const zalo = createZaloClient();

      pendingSessions.set(sessionId, {
        id: sessionId,
        qrFileName,
        status: 'pending',
      });

      // Wait for QR code image file to be successfully written to disk before responding
      await new Promise<void>((resolvePromise, rejectPromise) => {
        let isSettled = false;

        zalo.loginQR(
          {
            qrPath,
            language: 'vi',
          },
          (event) => {
            if (event.type === LoginQRCallbackEventType.QRCodeGenerated && event.actions) {
              console.log(`[server - ${sessionId}] QR code generated! Saving to ${qrPath}...`);
              event.actions.saveToFile(qrPath)
                .then(() => {
                  console.log(`[server - ${sessionId}] QR code image saved to ${qrPath}`);
                  if (!isSettled) {
                    isSettled = true;
                    resolvePromise();
                  }
                })
                .catch((err: any) => {
                  console.error(`[server - ${sessionId}] Failed to save QR code image:`, err);
                  if (!isSettled) {
                    isSettled = true;
                    rejectPromise(err);
                  }
                });
            }
            if (event.type === LoginQRCallbackEventType.QRCodeExpired) {
              console.log(`[server - ${sessionId}] QR code expired!`);
              const session = pendingSessions.get(sessionId);
              if (session) {
                session.status = 'timeout';
                session.error = 'Mã QR đã hết hạn. Vui lòng quét lại.';
              }
              try {
                if (existsSync(qrPath)) {
                  unlinkSync(qrPath);
                }
              } catch {}
            }
            if (event.type === LoginQRCallbackEventType.QRCodeDeclined) {
              console.log(`[server - ${sessionId}] QR code declined by user!`);
              const session = pendingSessions.get(sessionId);
              if (session) {
                session.status = 'failed';
                session.error = 'Yêu cầu đăng nhập bị từ chối trên điện thoại.';
              }
              try {
                if (existsSync(qrPath)) {
                  unlinkSync(qrPath);
                }
              } catch {}
            }
            if (event.type === LoginQRCallbackEventType.GotLoginInfo && event.data) {
              console.log(`[server - ${sessionId}] Got credentials! Saving temp session...`);
              const tempPath = resolve(credDir, `temp_${sessionId}.json`);
              try {
                writeFileSync(tempPath, JSON.stringify(event.data, null, 2), 'utf-8');
              } catch (writeErr) {
                console.error(`[server - ${sessionId}] Failed to write temp credentials:`, writeErr);
              }
            }
          }
        ).then(async (apiInstance) => {
          const uId = apiInstance.getOwnId ? apiInstance.getOwnId() : `personal_${Date.now()}`;
          console.log(`[server - ${sessionId}] Login success! Account ID: ${uId}`);

          const tempPath = resolve(credDir, `temp_${sessionId}.json`);
          const targetPath = resolve(credDir, `credentials_${uId}.json`);

          if (existsSync(tempPath)) {
            try {
              const raw = readFileSync(tempPath, 'utf-8');
              writeSecure(targetPath, raw);
              unlinkSync(tempPath);
              console.log(`[server - ${sessionId}] Saved credentials to ${targetPath}`);
            } catch (moveErr) {
              console.error(`[server - ${sessionId}] Failed to save credentials file:`, moveErr);
            }
          }

          try {
            if (existsSync(qrPath)) {
              unlinkSync(qrPath);
            }
          } catch {}

          await addAccountInstance(uId, apiInstance, targetPath);

          const session = pendingSessions.get(sessionId);
          if (session) {
            session.status = 'success';
            session.accountLabel = uId;
          }
        }).catch((err) => {
          console.error(`[server - ${sessionId}] QR login failed:`, err);
          const session = pendingSessions.get(sessionId);
          if (session) {
            session.status = 'failed';
            session.error = err instanceof Error ? err.message : String(err);
          }
          if (!isSettled) {
            isSettled = true;
            rejectPromise(err);
          }
        });

        // Safety timeout in case Zalo is slow or fails to generate QR
        setTimeout(() => {
          if (!isSettled) {
            isSettled = true;
            rejectPromise(new Error('QR generation timeout (12s)'));
          }
        }, 12000);
      });

      const qrUrl = `/api/zalo/accounts/qr-image?file=${qrFileName}`;
      json(res, 200, { success: true, sessionId, qrUrl });
    } catch (err) {
      json(res, 500, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // GET /api/zalo/accounts/qr-image
  if (method === 'GET' && url.startsWith('/api/zalo/accounts/qr-image')) {
    try {
      const query = url.split('?')[1] || '';
      const params = new URLSearchParams(query);
      const fileName = params.get('file');

      if (!fileName || !fileName.startsWith('qr_') || !fileName.endsWith('.png')) {
        json(res, 400, { error: 'Invalid or missing file parameter.' });
        return;
      }

      const credPath = resolve(projectRoot, config.personalCredentialsPath);
      const credDir = dirname(credPath);
      const filePath = resolve(credDir, fileName);

      if (!existsSync(filePath)) {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('QR Image not found or already scanned.');
        return;
      }

      setCorsHeaders(res);
      res.writeHead(200, { 'Content-Type': 'image/png' });
      createReadStream(filePath).pipe(res);
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Internal server error streaming QR image.');
    }
    return;
  }

  // GET /api/zalo/accounts/check-session
  if (method === 'GET' && url.startsWith('/api/zalo/accounts/check-session')) {
    try {
      const query = url.split('?')[1] || '';
      const params = new URLSearchParams(query);
      const sessionId = params.get('id');

      if (!sessionId) {
        json(res, 400, { error: 'id parameter is required.' });
        return;
      }

      const session = pendingSessions.get(sessionId);
      if (!session) {
        json(res, 404, { error: 'Session not found.' });
        return;
      }

      json(res, 200, {
        success: true,
        status: session.status,
        error: session.error,
        accountId: session.accountLabel,
      });
    } catch (err) {
      json(res, 500, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // GET /api/zalo/groups
  if (method === 'GET' && url === '/api/zalo/groups') {
    try {
      const groups = await getAllGroups();
      json(res, 200, { success: true, groups });
    } catch (err) {
      json(res, 500, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/zalo/groups/leave
  if (method === 'POST' && url === '/api/zalo/groups/leave') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const groupId = payload.groupId;
      const silent = payload.silent || false;

      if (!groupId || typeof groupId !== 'string') {
        json(res, 400, { error: 'groupId is required.' });
        return;
      }

      console.log(`[server] Leaving group ${groupId} (silent: ${silent}, accountId: ${payload.accountId || 'default'})`);
      const success = await leaveGroup(groupId, silent, payload.accountId);
      json(res, success ? 200 : 500, { success });
    } catch (err) {
      json(res, 400, { error: 'Invalid request body or leave group failed' });
    }
    return;
  }

  // POST /api/zalo/groups/create
  if (method === 'POST' && url === '/api/zalo/groups/create') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const name = payload.name;
      const members = payload.members;

      if (!name || typeof name !== 'string') {
        json(res, 400, { error: 'name is required and must be a string.' });
        return;
      }
      if (!members || !Array.isArray(members) || members.length === 0) {
        json(res, 400, { error: 'members list is required and cannot be empty.' });
        return;
      }

      console.log(`[server] Creating group: "${name}" with ${members.length} members (accountId: ${payload.accountId || 'default'})`);
      
      // Compliance check
      const complianceReq: ComplianceRequest = {
        actionType: 'create_groups',
        targetCount: 1,
        dailySentCount: 0,
        recentFailureRate: 0,
        recentReportCount: 0,
      };

      const decision = evaluateCompliance(complianceReq);
      if (!decision.allowed) {
        console.warn(`[server] Compliance check failed for group creation: ${decision.reason} [Risk: ${decision.riskLevel}]`);
        json(res, 403, {
          error: 'Compliance check failed',
          riskLevel: decision.riskLevel,
          reason: decision.reason,
        });
        return;
      }

      const result = await createGroup(name, members, payload.accountId);
      json(res, result.success ? 200 : 500, result);
    } catch (err) {
      json(res, 400, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/zalo/groups/join
  if (method === 'POST' && url === '/api/zalo/groups/join') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const link = payload.link;

      if (!link || typeof link !== 'string') {
        json(res, 400, { error: 'link is required and must be a string.' });
        return;
      }

      console.log(`[server] Joining group via link: ${link} (accountId: ${payload.accountId || 'default'})`);

      // Compliance check
      const complianceReq: ComplianceRequest = {
        actionType: 'join_groups',
        targetCount: 1,
        dailySentCount: 0,
        recentFailureRate: 0,
        recentReportCount: 0,
      };

      const decision = evaluateCompliance(complianceReq);
      if (!decision.allowed) {
        console.warn(`[server] Compliance check failed for group join: ${decision.reason} [Risk: ${decision.riskLevel}]`);
        json(res, 403, {
          error: 'Compliance check failed',
          riskLevel: decision.riskLevel,
          reason: decision.reason,
        });
        return;
      }

      const result = await joinGroup(link, payload.accountId);
      json(res, result.success ? 200 : 500, result);
    } catch (err) {
      json(res, 400, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/zalo/groups/invite
  if (method === 'POST' && url === '/api/zalo/groups/invite') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const userId = payload.userId;
      const groupId = payload.groupId;

      if (!userId || typeof userId !== 'string') {
        json(res, 400, { error: 'userId is required and must be a string.' });
        return;
      }
      if (!groupId || typeof groupId !== 'string') {
        json(res, 400, { error: 'groupId is required and must be a string.' });
        return;
      }

      console.log(`[server] Inviting user ${userId} to group ${groupId} (accountId: ${payload.accountId || 'default'})`);

      // Compliance check
      const complianceReq: ComplianceRequest = {
        actionType: 'invite_to_group',
        targetCount: 1,
        dailySentCount: 0,
        recentFailureRate: 0,
        recentReportCount: 0,
      };

      const decision = evaluateCompliance(complianceReq);
      if (!decision.allowed) {
        console.warn(`[server] Compliance check failed for group invite: ${decision.reason} [Risk: ${decision.riskLevel}]`);
        json(res, 403, {
          error: 'Compliance check failed',
          riskLevel: decision.riskLevel,
          reason: decision.reason,
        });
        return;
      }

      const result = await inviteToGroup(userId, groupId, payload.accountId);
      json(res, result.success ? 200 : 500, result);
    } catch (err) {
      json(res, 400, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // GET /api/zalo/friends
  if (method === 'GET' && url.startsWith('/api/zalo/friends')) {
    try {
      const query = url.split('?')[1] || '';
      const params = new URLSearchParams(query);
      const accountId = params.get('accountId') || undefined;

      const friends = await getAllFriends(accountId);
      json(res, 200, { success: true, friends });
    } catch (err) {
      json(res, 500, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/zalo/groups/members
  if (method === 'POST' && url === '/api/zalo/groups/members') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const groupId = payload.groupId;

      if (!groupId || typeof groupId !== 'string') {
        json(res, 400, { error: 'groupId is required.' });
        return;
      }

      console.log(`[server] Fetching members for group ${groupId}`);
      const members = await getGroupMembers(groupId);
      json(res, 200, { success: true, members });
    } catch (err) {
      json(res, 500, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/zalo/groups/link-members
  if (method === 'POST' && url === '/api/zalo/groups/link-members') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const link = payload.link;

      if (!link || typeof link !== 'string') {
        json(res, 400, { error: 'link is required.' });
        return;
      }

      console.log(`[server] Fetching group members from link: ${link}`);
      const result = await getGroupLinkMembers(link);
      json(res, 200, { success: true, ...result });
    } catch (err) {
      json(res, 500, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
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
          accountId: payload.accountId,
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
        console.warn(`[server] Compliance check failed for send-message: ${decision.reason} [Risk: ${decision.riskLevel}]`);
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
          accountId: payload.accountId,
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

  // POST /api/zalo/friends/search
  if (method === 'POST' && url === '/api/zalo/friends/search') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const phone = payload.phone;

      if (!phone || typeof phone !== 'string') {
        json(res, 400, { error: 'phone is required and must be a string.' });
        return;
      }

      console.log(`[server] Searching user by phone: ${phone} (accountId: ${payload.accountId || 'default'})`);
      const result = await findUser(phone, payload.accountId);
      json(res, 200, { success: true, user: result });
    } catch (err) {
      json(res, 500, { success: false, error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/zalo/friends/add
  if (method === 'POST' && url === '/api/zalo/friends/add') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const userId = payload.userId;
      const message = payload.message || 'Chào bạn, mình kết bạn nhé!';
      const actionType = payload.actionType || 'friend_by_phone';

      if (!userId || typeof userId !== 'string') {
        json(res, 400, { error: 'userId is required and must be a string.' });
        return;
      }

      console.log(`[server] Gửi yêu cầu kết bạn đến ${userId}: "${message}" (accountId: ${payload.accountId || 'default'})`);

      // Compliance check
      const complianceReq: ComplianceRequest = {
        actionType: actionType as any,
        targetCount: 1,
        dailySentCount: 0,
        recentFailureRate: 0,
        recentReportCount: 0,
      };

      const decision = evaluateCompliance(complianceReq);
      if (!decision.allowed) {
        console.warn(`[server] Compliance check failed for friend request: ${decision.reason} [Risk: ${decision.riskLevel}]`);
        json(res, 403, {
          error: 'Compliance check failed',
          riskLevel: decision.riskLevel,
          reason: decision.reason,
        });
        return;
      }

      const result = await sendFriendRequest(userId, message, payload.accountId);
      json(res, result.success ? 200 : 500, result);
    } catch (err) {
      json(res, 400, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/zalo/friends/approve
  if (method === 'POST' && url === '/api/zalo/friends/approve') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const senderId = payload.senderId;

      if (!senderId || typeof senderId !== 'string') {
        json(res, 400, { error: 'senderId is required and must be a string.' });
        return;
      }

      console.log(`[server] Chấp nhận kết bạn từ: ${senderId} (accountId: ${payload.accountId || 'default'})`);
      const result = await acceptFriendRequest(senderId, payload.accountId);
      json(res, result.success ? 200 : 500, result);
    } catch (err) {
      json(res, 400, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // POST /api/logs/client (Receive from Flutter)
  if (method === 'POST' && url === '/api/logs/client') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      saveClientLog(payload);
      json(res, 200, { success: true });
    } catch (err) {
      json(res, 400, { error: 'Invalid log payload' });
    }
    return;
  }

  // GET /api/logs/client (Fetch for Flutter/Web CRM)
  if (method === 'GET' && url === '/api/logs/client') {
    try {
      const logs = getClientLogs();
      json(res, 200, { success: true, logs });
    } catch (err) {
      json(res, 500, { error: 'Failed to read logs' });
    }
    return;
  }

  // POST /api/logs/client/delete (Delete specific logs)
  if (method === 'POST' && url === '/api/logs/client/delete') {
    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);
      const ids = payload.ids;
      if (Array.isArray(ids)) {
        deleteClientLogs(ids);
        json(res, 200, { success: true });
      } else {
        json(res, 400, { error: 'Invalid ids array' });
      }
    } catch (err) {
      json(res, 500, { error: 'Failed to delete logs' });
    }
    return;
  }

  // 404 for everything else
  json(res, 404, { error: 'Not found' });
});

function listenOnPort(port: number): void {
  server.listen(port, config.localBindHost, async () => {
    activePort = port;
    console.log(`
╔══════════════════════════════════════════════╗
║  Alpha CRM — Zalo Bot Service v${VERSION}       ║
║  Running on http://${config.localBindHost}:${port}          ║
║  Channel: ${config.channelMode.padEnd(34)}║
║  Environment: ${config.nodeEnv.padEnd(30)}║
║  Personal Automation: ${(config.allowPersonalAccountAutomation ? 'ENABLED' : 'DISABLED').padEnd(23)}║
║  Friend Automation: ${(config.allowFriendAutomation ? 'ENABLED' : 'DISABLED').padEnd(25)}║
║  Group Automation: ${(config.allowGroupAutomation ? 'ENABLED' : 'DISABLED').padEnd(26)}║
╚══════════════════════════════════════════════╝
    `);

    // Write the active port to .data/active-port.json
    try {
      const dataDir = join(projectRoot, '.data');
      if (!existsSync(dataDir)) {
        mkdirSync(dataDir, { recursive: true });
      }
      writeFileSync(join(dataDir, 'active-port.json'), JSON.stringify({
        service: SERVICE_ID,
        port,
        pid: process.pid,
        projectRoot,
        dataRoot,
        startedAt: new Date().toISOString(),
      }, null, 2));
      console.log(`[server] Wrote active port ${port} to .data/active-port.json`);
    } catch (writeErr) {
      console.error('[server] Failed to write active-port.json:', writeErr);
    }

    // Tự khôi phục runtime từ credentials đã lưu (nếu có) để nạp ngay pool tài
    // khoản, không phải chờ Flutter gửi /local/auth/sync. Flutter vẫn sẽ sync để
    // xác thực/heartbeat — sync sau đó là idempotent (heartbeat + activate lại).
    void resumeRuntimeFromStoredCredentials().then((resumed) => {
      if (!resumed) {
        console.log('[server] Waiting for Flutter session sync before starting CRM runtime.');
      }
    });
  });

  server.on('error', (err: any) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`[server] Port ${port} is already in use. Refusing to auto-fallback; the Flutter supervisor must select the backend port.`);
      process.exit(1);
    } else {
      console.error('[server] Server error:', err);
    }
  });
}

listenOnPort(config.localBindPort);

let shuttingDown = false;
async function shutdown(): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;
  await shutdownSessionRuntime();
  server.close(() => process.exit(0));
}

process.on('SIGINT', () => {
  void shutdown();
});
process.on('SIGTERM', () => {
  void shutdown();
});

// Safety net: a single unhandled async error (e.g. a dead Zalo session thrown
// from deep inside zca-js) must never crash the whole service and take down the
// listeners of every other account. Log and keep running.
process.on('unhandledRejection', (reason) => {
  console.error('[server] Unhandled promise rejection (kept alive):', reason);
});
