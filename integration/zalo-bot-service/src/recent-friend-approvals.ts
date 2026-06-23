/**
 * Tracks contacts that were just auto-approved as friends, so the chatbot can
 * optionally suppress an automatic reply to their first messages (controlled by
 * `config.autoReplyNewFriend`). Entries expire after a short window.
 */
const TTL_MS = 10 * 60 * 1000; // 10 minutes

const approvedAt = new Map<string, number>();

export function markAutoApproved(userId: string): void {
  const id = String(userId || '').trim();
  if (!id) return;
  approvedAt.set(id, Date.now());
}

export function wasRecentlyAutoApproved(userId: string): boolean {
  const id = String(userId || '').trim();
  if (!id) return false;
  const ts = approvedAt.get(id);
  if (ts === undefined) return false;
  if (Date.now() - ts > TTL_MS) {
    approvedAt.delete(id);
    return false;
  }
  return true;
}
