import type { IncomingMessage, ServerResponse } from 'http';
import { CloudApiError } from '../agent/cloud-api.js';
import {
  LocalSessionError,
  type SessionCoordinator,
} from './session-coordinator.js';
import type { SessionEventHub } from './session-events.js';

const MAX_BODY_BYTES = 64 * 1024;

type JsonResponder = (
  response: ServerResponse,
  status: number,
  data: unknown,
  request?: IncomingMessage,
) => void;

export async function handleLocalSessionRoute(
  method: string,
  rawUrl: string,
  request: IncomingMessage,
  response: ServerResponse,
  json: JsonResponder,
  coordinator: SessionCoordinator,
  eventHub: SessionEventHub,
): Promise<boolean> {
  const pathname = new URL(rawUrl, 'http://127.0.0.1').pathname;

  if (method === 'GET' && pathname === '/local/events') {
    response.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    const remove = eventHub.addClient(response);
    request.on('close', remove);
    return true;
  }

  if (method === 'POST' && pathname === '/local/auth/sync') {
    try {
      const body = await readJsonBody(request);
      const result = await coordinator.sync({
        token: body.token,
        userId: body.userId,
        displayName: body.displayName,
        machineFingerprint: body.machineFingerprint,
        force: body.force === true,
      });
      if (result.status === 'conflict') {
        json(response, 409, {
          success: false,
          code: 'DEVICE_ALREADY_ACTIVE',
          data: result.activeDevice,
        }, request);
      } else {
        json(response, 200, { success: true, data: result }, request);
      }
    } catch (error) {
      respondWithError(response, request, json, error);
    }
    return true;
  }

  if (method === 'POST' && pathname === '/local/auth/logout') {
    try {
      const body = await readJsonBody(request);
      if (typeof body.token !== 'string' || body.token.length === 0) {
        throw new LocalSessionError(
          'token is required.',
          400,
          'INVALID_SESSION_REQUEST',
        );
      }
      await coordinator.logout(body.token);
      json(response, 200, { success: true }, request);
    } catch (error) {
      respondWithError(response, request, json, error);
    }
    return true;
  }

  return false;
}

async function readJsonBody(request: IncomingMessage): Promise<Record<string, any>> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let size = 0;
    let exceeded = false;
    request.on('data', (chunk: Buffer) => {
      size += chunk.length;
      if (exceeded) {
        return;
      }
      if (size > MAX_BODY_BYTES) {
        exceeded = true;
        chunks.length = 0;
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => {
      if (exceeded) {
        reject(new LocalSessionError(
          'Request body exceeds 64 KiB.',
          413,
          'REQUEST_TOO_LARGE',
        ));
        return;
      }
      try {
        const raw = Buffer.concat(chunks).toString('utf8');
        resolve(raw.length === 0 ? {} : JSON.parse(raw));
      } catch {
        reject(new LocalSessionError(
          'Request body must be valid JSON.',
          400,
          'INVALID_JSON',
        ));
      }
    });
    request.on('error', reject);
  });
}

function respondWithError(
  response: ServerResponse,
  request: IncomingMessage,
  json: JsonResponder,
  error: unknown,
): void {
  if (error instanceof LocalSessionError || error instanceof CloudApiError) {
    json(response, error.status, {
      success: false,
      code: error.code,
      message: error.message,
      data: error instanceof CloudApiError ? error.data : undefined,
    }, request);
    return;
  }
  console.error('[local-session-api] Request failed:', error);
  json(response, 503, {
    success: false,
    code: 'LOCAL_SESSION_UNAVAILABLE',
    message: error instanceof Error ? error.message : String(error),
  }, request);
}
