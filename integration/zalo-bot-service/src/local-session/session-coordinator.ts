import type { AgentCredentials } from '../agent/agent-identity.js';
import {
  CloudApiError,
  isDeviceRevokedError,
} from '../agent/cloud-api.js';
import type { LocalSessionEvent } from './session-events.js';

export interface SessionSyncRequest {
  token: string;
  userId: string;
  displayName: string;
  machineFingerprint: string;
  force?: boolean;
}

export type SessionSyncResult =
  | { status: 'active'; deviceId: string }
  | {
    status: 'conflict';
    activeDevice: {
      displayName?: string;
      lastSeenAt?: string;
    };
  };

export interface SessionCoordinatorDependencies {
  verifyIdentity(token: string): Promise<{ userId: string }>;
  getCredentials(): AgentCredentials | null;
  register(
    token: string,
    displayName: string,
    machineFingerprint: string,
  ): Promise<{ deviceId: string; agentSecret: string }>;
  forceReplace(
    token: string,
    displayName: string,
    machineFingerprint: string,
  ): Promise<{ deviceId: string; agentSecret: string }>;
  heartbeat(deviceId: string, agentSecret: string): Promise<void>;
  disable(token: string, deviceId: string): Promise<void>;
  saveCredentials(credentials: AgentCredentials): void;
  saveToken(token: string, userId: string): void;
  deleteCredentials(): void;
  deleteToken(): void;
  startRuntime(credentials: AgentCredentials): Promise<void>;
  stopRuntime(): Promise<void>;
  cancelCampaigns(): void;
  resetCampaignCancellation(): void;
  publish(event: LocalSessionEvent): void;
}

export class LocalSessionError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly code: string,
  ) {
    super(message);
    this.name = 'LocalSessionError';
  }
}

export class SessionCoordinator {
  private revokePromise: Promise<void> | null = null;

  constructor(private readonly dependencies: SessionCoordinatorDependencies) {}

  async sync(request: SessionSyncRequest): Promise<SessionSyncResult> {
    this.validateSyncRequest(request);
    const identity = await this.dependencies.verifyIdentity(request.token);
    if (identity.userId !== request.userId) {
      throw new LocalSessionError(
        'The JWT identity does not match the requested CRM user.',
        401,
        'IDENTITY_MISMATCH',
      );
    }

    const existing = this.dependencies.getCredentials();
    if (existing?.userId === request.userId && !request.force) {
      try {
        await this.dependencies.heartbeat(existing.deviceId, existing.agentSecret);
        await this.activate(request.token, existing);
        return { status: 'active', deviceId: existing.deviceId };
      } catch (error) {
        if (!isDeviceRevokedError(error)) {
          throw error;
        }
        await this.stopAndDeleteSessionFiles();
      }
    } else if (existing) {
      await this.stopAndDeleteSessionFiles();
    }

    let registered: { deviceId: string; agentSecret: string };
    try {
      registered = request.force
        ? await this.dependencies.forceReplace(
          request.token,
          request.displayName,
          request.machineFingerprint,
        )
        : await this.dependencies.register(
          request.token,
          request.displayName,
          request.machineFingerprint,
        );
    } catch (error) {
      if (
        error instanceof CloudApiError
        && error.status === 409
        && error.code === 'DEVICE_ALREADY_ACTIVE'
      ) {
        const rawData = error.data && typeof error.data === 'object'
          ? error.data as {
            device?: { displayName?: string; lastSeenAt?: string };
            displayName?: string;
            lastSeenAt?: string;
          }
          : {};
        const activeDevice = rawData.device ?? rawData;
        return {
          status: 'conflict',
          activeDevice: {
            displayName: activeDevice.displayName,
            lastSeenAt: activeDevice.lastSeenAt,
          },
        };
      }
      throw error;
    }

    const credentials: AgentCredentials = {
      userId: request.userId,
      deviceId: registered.deviceId,
      agentSecret: registered.agentSecret,
    };
    await this.activate(request.token, credentials);
    return { status: 'active', deviceId: credentials.deviceId };
  }

  async logout(token: string): Promise<void> {
    const credentials = this.dependencies.getCredentials();
    if (credentials) {
      try {
        await this.dependencies.disable(token, credentials.deviceId);
      } catch (error) {
        console.warn('[session-coordinator] Failed to disable cloud device:', error);
      }
    }
    await this.stopAndDeleteSessionFiles();
  }

  revoke(reason: string): Promise<void> {
    if (this.revokePromise) {
      return this.revokePromise;
    }
    this.revokePromise = (async () => {
      await this.stopAndDeleteSessionFiles();
      this.dependencies.publish({
        type: 'session.revoked',
        code: 'DEVICE_REVOKED',
        reason,
      });
    })();
    return this.revokePromise;
  }

  private async activate(token: string, credentials: AgentCredentials): Promise<void> {
    this.dependencies.saveToken(token, credentials.userId);
    this.dependencies.saveCredentials(credentials);
    this.dependencies.resetCampaignCancellation();
    this.revokePromise = null;
    await this.dependencies.startRuntime(credentials);
  }

  private async stopAndDeleteSessionFiles(): Promise<void> {
    this.dependencies.cancelCampaigns();
    await this.dependencies.stopRuntime();
    this.dependencies.deleteToken();
    this.dependencies.deleteCredentials();
  }

  private validateSyncRequest(request: SessionSyncRequest): void {
    for (const value of [
      request.token,
      request.userId,
      request.displayName,
      request.machineFingerprint,
    ]) {
      if (typeof value !== 'string' || value.trim().length === 0) {
        throw new LocalSessionError(
          'token, userId, displayName and machineFingerprint are required.',
          400,
          'INVALID_SESSION_REQUEST',
        );
      }
    }
  }
}
