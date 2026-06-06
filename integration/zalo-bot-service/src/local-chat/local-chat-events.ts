import { randomUUID } from 'crypto';

export interface LocalChatEventInput {
  type: string;
  accountId?: string;
  threadId?: string;
  data?: Record<string, unknown>;
}

export interface LocalChatEvent extends LocalChatEventInput {
  id: string;
  timestamp: string;
}

export interface LocalChatEventFilter {
  accountId?: string;
  threadId?: string;
}

type LocalChatEventListener = (event: LocalChatEvent) => void;

function matchesFilter(event: LocalChatEvent, filter: LocalChatEventFilter): boolean {
  if (filter.accountId && event.accountId !== filter.accountId) return false;
  if (filter.threadId && event.threadId !== filter.threadId) return false;
  return true;
}

export class LocalChatEventBus {
  private readonly listeners = new Map<
    LocalChatEventListener,
    LocalChatEventFilter
  >();
  private readonly events: LocalChatEvent[] = [];

  constructor(private readonly replayLimit = 200) {}

  publish(input: LocalChatEventInput): LocalChatEvent {
    const event: LocalChatEvent = {
      ...input,
      id: randomUUID(),
      timestamp: new Date().toISOString(),
      data: input.data ?? {},
    };
    this.events.push(event);
    if (this.events.length > this.replayLimit) {
      this.events.splice(0, this.events.length - this.replayLimit);
    }
    for (const [listener, filter] of this.listeners) {
      if (matchesFilter(event, filter)) listener(event);
    }
    return event;
  }

  subscribe(
    listener: LocalChatEventListener,
    filter: LocalChatEventFilter = {},
  ): () => void {
    this.listeners.set(listener, filter);
    return () => this.listeners.delete(listener);
  }

  replayAfter(
    eventId: string,
    filter: LocalChatEventFilter = {},
  ): LocalChatEvent[] {
    const index = this.events.findIndex((event) => event.id === eventId);
    if (index < 0) return [];
    return this.events
      .slice(index + 1)
      .filter((event) => matchesFilter(event, filter));
  }
}

export const localChatEvents = new LocalChatEventBus();
