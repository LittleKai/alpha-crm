export interface ChatbotHistoryTurn {
  role: 'user' | 'assistant';
  content: string;
}

export interface ChatbotHistorySourceMessage {
  direction: 'inbound' | 'outbound';
  content: string;
  messageType: string;
  providerMessageId?: string;
  isDeleted?: boolean;
}

/**
 * Build the recent-conversation context sent to the AI.
 *
 * Messages are collapsed into "turns": a maximal run of consecutive messages
 * from the same side counts as ONE turn (per product spec — if the customer
 * sends 3 messages in a row with no reply between them, that is 1 turn). The
 * most recent `limitTurns` turns are returned in chronological order.
 *
 * @param messages chronological (oldest -> newest) local message rows
 * @param excludeProviderIds provider message ids of the messages currently being
 *   answered (they are sent separately as `messages`, so keep them out of history)
 * @param limitTurns max number of collapsed turns (0 = no history)
 */
export function buildChatbotHistory(
  messages: ChatbotHistorySourceMessage[],
  excludeProviderIds: ReadonlySet<string>,
  limitTurns: number,
): ChatbotHistoryTurn[] {
  if (!Number.isFinite(limitTurns) || limitTurns <= 0) return [];

  const usable = messages.filter(
    (message) =>
      !message.isDeleted
      && message.messageType === 'text'
      && message.content.trim().length > 0
      && !(
        message.providerMessageId
        && excludeProviderIds.has(message.providerMessageId)
      ),
  );

  const turns: ChatbotHistoryTurn[] = [];
  for (const message of usable) {
    const role: ChatbotHistoryTurn['role'] =
      message.direction === 'outbound' ? 'assistant' : 'user';
    const last = turns[turns.length - 1];
    if (last && last.role === role) {
      last.content = `${last.content}\n${message.content.trim()}`;
    } else {
      turns.push({ role, content: message.content.trim() });
    }
  }

  return turns.slice(-limitTurns);
}
