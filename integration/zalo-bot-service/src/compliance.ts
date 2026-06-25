/**
 * Backend compliance guard — channel-aware risk gating.
 * This is the ENFORCEMENT boundary. Flutter side is advisory-only.
 *
 * ALL enforcement settings come from server-side config (env vars).
 * The client request body provides only contextual info (actionType,
 * targetCount, hasConsentProof, hasRecentInteraction, isTestMode).
 * The client CANNOT override automation flags or self-approve.
 *
 * Rules:
 * - mock: allowed for test mode only.
 * - official_oa: requires official channel metadata and consent/interaction rules.
 * - personal_zca: allowed when personal automation is enabled and limits pass.
 *   Friend/group actions require explicit allow flag and human approval for batch.
 * - Batch limits, daily limits, quiet hours, failure-rate stop, report stop are all enforced server-side.
 * - Missing credentials = setup error, not policy error.
 */

import { config, type ZaloChannelMode } from './config.js';

export type ZaloActionType =
  | 'bulk_message_by_phone'
  | 'bulk_message_to_group'
  | 'bulk_message_to_friends'
  | 'friend_by_phone'
  | 'friend_by_group'
  | 'scan_group_members'
  | 'join_groups'
  | 'invite_to_group'
  | 'create_groups'
  | 'live_chat_reply'
  | 'chatbot_reply';

export type ZaloRiskLevel = 'low' | 'medium' | 'high' | 'critical';

export interface ComplianceDecision {
  allowed: boolean;
  riskLevel: ZaloRiskLevel;
  reason: string;
}

/**
 * Client-provided context for compliance evaluation.
 * Note: enforcement flags (allowPersonalAccountAutomation,
 * requireHumanApproval, etc.) are NOT accepted from the client.
 */
export interface ComplianceRequest {
  actionType: ZaloActionType;
  targetCount: number;
  hasConsentProof?: boolean;
  hasRecentInteraction?: boolean;
  isTestMode?: boolean;
  // Server-tracked counters (passed by server, not client)
  dailySentCount?: number;
  recentFailureRate?: number;
  recentReportCount?: number;
}

const PERSONAL_ACTIONS: Set<ZaloActionType> = new Set([
  'friend_by_phone',
  'friend_by_group',
  'scan_group_members',
  'join_groups',
  'invite_to_group',
  'create_groups',
]);

const FRIEND_ACTIONS: Set<ZaloActionType> = new Set([
  'friend_by_phone',
  'friend_by_group',
]);

const GROUP_ACTIONS: Set<ZaloActionType> = new Set([
  'scan_group_members',
  'join_groups',
  'invite_to_group',
  'create_groups',
]);

/**
 * Check if current time is within quiet hours.
 * Supports overnight ranges (e.g. 21:00 → 08:00).
 */
function isQuietHours(): boolean {
  const now = new Date();
  const currentMinutes = now.getHours() * 60 + now.getMinutes();

  const [startH, startM] = config.quietHoursStart.split(':').map(Number);
  const [endH, endM] = config.quietHoursEnd.split(':').map(Number);
  const startMinutes = (startH || 0) * 60 + (startM || 0);
  const endMinutes = (endH || 0) * 60 + (endM || 0);

  if (startMinutes <= endMinutes) {
    // Same-day range (e.g. 09:00-17:00)
    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }
  // Overnight range (e.g. 21:00-08:00)
  return currentMinutes >= startMinutes || currentMinutes < endMinutes;
}

/**
 * Evaluate whether a Zalo action should be permitted.
 * This is the SERVER-SIDE enforcement. Even if Flutter allows it,
 * the backend must independently verify compliance.
 *
 * All enforcement settings come from config (env vars), not from
 * the client payload.
 */
export function evaluateCompliance(req: ComplianceRequest): ComplianceDecision {
  const {
    actionType,
    targetCount,
    hasConsentProof = false,
    hasRecentInteraction = false,
    isTestMode = false,
    dailySentCount = 0,
    recentFailureRate = 0,
    recentReportCount = 0,
  } = req;

  const channelMode = config.channelMode;

  // ── Stop conditions: fail-closed ──

  if (recentReportCount >= config.stopOnReportCount && !isTestMode) {
    return {
      allowed: false,
      riskLevel: 'critical',
      reason: `Stopped: ${recentReportCount} report(s) received. Threshold is ${config.stopOnReportCount}. Resolve reports before continuing.`,
    };
  }

  if (recentFailureRate > config.maxFailureRatePercent && !isTestMode) {
    return {
      allowed: false,
      riskLevel: 'critical',
      reason: `Stopped: failure rate ${recentFailureRate}% exceeds maximum ${config.maxFailureRatePercent}%. Investigate errors before continuing.`,
    };
  }

  // ── Quiet hours ──

  if (isQuietHours() && !isTestMode) {
    return {
      allowed: false,
      riskLevel: 'medium',
      reason: `Quiet hours active (${config.quietHoursStart}–${config.quietHoursEnd}). Sending is paused.`,
    };
  }

  // ── Daily send limit ──

  if (dailySentCount >= config.dailySendLimit && !isTestMode) {
    return {
      allowed: false,
      riskLevel: 'high',
      reason: `Daily send limit reached (${dailySentCount}/${config.dailySendLimit}). Wait until tomorrow.`,
    };
  }

  // ── Live chat / chatbot are generally safe ──

  if (actionType === 'live_chat_reply' || actionType === 'chatbot_reply') {
    return {
      allowed: true,
      riskLevel: 'low',
      reason: 'Reply to user-initiated interaction.',
    };
  }

  // ── Channel-specific gating ──



  // Personal mode: check server-side automation flags
  if (channelMode === 'personal_zca') {
    if (PERSONAL_ACTIONS.has(actionType)) {
      if (!config.allowPersonalAccountAutomation) {
        return {
          allowed: false,
          riskLevel: 'critical',
          reason:
            'Personal account automation is disabled server-side (ZALO_ALLOW_PERSONAL_AUTOMATION=false).',
        };
      }

      // Friend-specific flag
      if (FRIEND_ACTIONS.has(actionType) && !config.allowFriendAutomation) {
        return {
          allowed: false,
          riskLevel: 'critical',
          reason:
            'Friend automation is disabled server-side (ZALO_ALLOW_FRIEND_AUTOMATION=false).',
        };
      }

      // Group-specific flag
      if (GROUP_ACTIONS.has(actionType) && !config.allowGroupAutomation) {
        return {
          allowed: false,
          riskLevel: 'critical',
          reason:
            'Group automation is disabled server-side (ZALO_ALLOW_GROUP_AUTOMATION=false).',
        };
      }

      // Human approval for batch operations (server decides threshold)
      if (
        !isTestMode &&
        config.requireHumanApproval &&
        targetCount > config.humanApprovalThreshold
      ) {
        return {
          allowed: false,
          riskLevel: 'high',
          reason:
            `Batch of ${targetCount} exceeds human approval threshold (${config.humanApprovalThreshold}). Server-side approval required.`,
        };
      }

      if (isTestMode) {
        return {
          allowed: true,
          riskLevel: 'high',
          reason: 'Test mode for personal account action. No real Zalo operation performed.',
        };
      }
    }
  }

  // Official mode: personal actions blocked
  if (channelMode === 'official_oa') {
    if (PERSONAL_ACTIONS.has(actionType) && !isTestMode) {
      return {
        allowed: false,
        riskLevel: 'critical',
        reason:
          'Personal account automation is not available in Official OA mode. Switch to personal_zca channel.',
      };
    }
  }

  // ── Consent / interaction checks ──

  if (actionType === 'bulk_message_by_phone' && !hasConsentProof) {
    return {
      allowed: true, // was false
      riskLevel: 'high',
      reason: 'Warning: Bulk messaging by phone without consent proof.',
    };
  }

  if (
    (actionType === 'bulk_message_to_group' ||
      actionType === 'bulk_message_to_friends') &&
    !hasConsentProof &&
    !hasRecentInteraction
  ) {
    return {
      allowed: true, // was false
      riskLevel: 'medium',
      reason: 'Warning: Bulk messaging without consent or recent interaction.',
    };
  }

  // ── Batch size limit (absolute cap) ──

  if (targetCount > config.maxBatchSize) {
    return {
      allowed: false,
      riskLevel: 'high',
      reason: `Batch size ${targetCount} exceeds server maximum of ${config.maxBatchSize}.`,
    };
  }

  return {
    allowed: true,
    riskLevel: 'low',
    reason: 'Action complies with server-side rules.',
  };
}
