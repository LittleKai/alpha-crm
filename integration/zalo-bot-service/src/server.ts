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
import { getZaloStatus, sendMessage, handleWebhookEvent, getAllGroups, leaveGroup, getAccounts, deleteAccount, initializeZalo, getAllFriends, getGroupMembers, getGroupLinkMembers, createGroup, joinGroup, inviteToGroup, findUser, sendFriendRequest, acceptFriendRequest } from './zalo.js';
import { existsSync, createReadStream, writeFileSync, unlinkSync, readFileSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { projectRoot } from './config.js';
import { Zalo, LoginQRCallbackEventType } from 'zca-js';
import type { LoginQRCallback, LoginQRCallbackEvent } from 'zca-js';
import { addAccountInstance } from './channels/personal-zca-channel.js';

const VERSION = '0.2.0';

interface PendingSession {
  id: string;
  qrFileName: string;
  status: 'pending' | 'success' | 'failed' | 'timeout';
  error?: string;
  accountLabel?: string;
}
const pendingSessions = new Map<string, PendingSession>();

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

      const zalo = new Zalo({
        selfListen: config.personalSelfListen,
        logging: true,
      });

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
              writeFileSync(targetPath, raw, 'utf-8');
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

          await addAccountInstance(uId, apiInstance);

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

      console.log(`[server] Leaving group ${groupId} (silent: ${silent})`);
      const success = await leaveGroup(groupId, silent);
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

      console.log(`[server] Creating group: "${name}" with ${members.length} members`);
      
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

      const result = await createGroup(name, members);
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

      console.log(`[server] Joining group via link: ${link}`);

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

      const result = await joinGroup(link);
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

      console.log(`[server] Inviting user ${userId} to group ${groupId}`);

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

      const result = await inviteToGroup(userId, groupId);
      json(res, result.success ? 200 : 500, result);
    } catch (err) {
      json(res, 400, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // GET /api/zalo/friends
  if (method === 'GET' && url === '/api/zalo/friends') {
    try {
      const friends = await getAllFriends();
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

      console.log(`[server] Searching user by phone: ${phone}`);
      const result = await findUser(phone);
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

      console.log(`[server] Gửi yêu cầu kết bạn đến ${userId}: "${message}"`);

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

      const result = await sendFriendRequest(userId, message);
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

      console.log(`[server] Chấp nhận kết bạn từ: ${senderId}`);
      const result = await acceptFriendRequest(senderId);
      json(res, result.success ? 200 : 500, result);
    } catch (err) {
      json(res, 400, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  // 404 for everything else
  json(res, 404, { error: 'Not found' });
});

server.listen(config.port, async () => {
  console.log(`
╔══════════════════════════════════════════════╗
║  Alpha CRM — Zalo Bot Service v${VERSION}       ║
║  Running on http://localhost:${config.port}          ║
║  Channel: ${config.channelMode.padEnd(34)}║
║  Environment: ${config.nodeEnv.padEnd(30)}║
║  Personal Automation: ${(config.allowPersonalAccountAutomation ? 'ENABLED' : 'DISABLED').padEnd(23)}║
║  Friend Automation: ${(config.allowFriendAutomation ? 'ENABLED' : 'DISABLED').padEnd(25)}║
║  Group Automation: ${(config.allowGroupAutomation ? 'ENABLED' : 'DISABLED').padEnd(26)}║
╚══════════════════════════════════════════════╝
  `);
  try {
    await initializeZalo();
    console.log('[server] Zalo integration initialized successfully.');
  } catch (err) {
    console.error('[server] Failed to initialize Zalo integration:', err);
  }
});
