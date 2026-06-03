export interface OfficialBotClientOptions {
  token: string;
  baseUrl: string;
  timeoutMs: number;
}

export interface OfficialBotSendResult {
  messageId?: string;
  raw: unknown;
}

type RequestPayload = Record<string, string | number | boolean | null | undefined>;

export class OfficialBotApiError extends Error {
  constructor(
    message: string,
    public readonly statusCode?: number,
    public readonly code?: string,
  ) {
    super(message);
    this.name = 'OfficialBotApiError';
  }
}

export class OfficialBotClient {
  constructor(private readonly options: OfficialBotClientOptions) {}

  async sendTextMessage(chatId: string, text: string): Promise<OfficialBotSendResult> {
    const result = await this.post('sendMessage', {
      chat_id: chatId,
      text,
    });

    return {
      messageId: extractMessageId(result),
      raw: result,
    };
  }

  private async post(endpoint: string, payload: RequestPayload): Promise<unknown> {
    const token = this.options.token.trim();
    if (!token) {
      throw new OfficialBotApiError('ZALO_BOT_TOKEN is not configured.');
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.options.timeoutMs);

    try {
      const res = await fetch(this.buildUrl(endpoint), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(compactPayload(payload)),
        signal: controller.signal,
      });

      const body = await readJsonBody(res);
      if (!res.ok || isExplicitApiFailure(body)) {
        throw mapApiError(res.status, body);
      }

      if (isRecord(body) && 'result' in body) return body.result;
      if (isRecord(body) && 'data' in body) return body.data;
      return body;
    } catch (err) {
      if (err instanceof OfficialBotApiError) throw err;
      if (err instanceof Error && err.name === 'AbortError') {
        throw new OfficialBotApiError(
          `Official Bot API timed out after ${this.options.timeoutMs}ms.`,
          undefined,
          'timeout',
        );
      }
      throw new OfficialBotApiError(
        err instanceof Error ? err.message : String(err),
        undefined,
        'network_error',
      );
    } finally {
      clearTimeout(timeout);
    }
  }

  private buildUrl(endpoint: string): string {
    const baseUrl = this.options.baseUrl.replace(/\/+$/, '');
    return `${baseUrl}/bot${this.options.token}/${endpoint}`;
  }
}

function compactPayload(payload: RequestPayload): Record<string, string | number | boolean | null> {
  const compact: Record<string, string | number | boolean | null> = {};
  for (const [key, value] of Object.entries(payload)) {
    if (value !== undefined) compact[key] = value;
  }
  return compact;
}

async function readJsonBody(res: Response): Promise<unknown> {
  const text = await res.text();
  if (!text) return {};
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new OfficialBotApiError(
      `Official Bot API returned non-JSON response (${res.status}).`,
      res.status,
      'invalid_json',
    );
  }
}

function isExplicitApiFailure(body: unknown): boolean {
  return isRecord(body) && body.ok === false;
}

function mapApiError(statusCode: number, body: unknown): OfficialBotApiError {
  if (!isRecord(body)) {
    return new OfficialBotApiError(`Official Bot API error (${statusCode}).`, statusCode);
  }

  const description =
    toStringValue(body.description) ||
    toStringValue(body.error_description) ||
    toStringValue(body.message) ||
    `Official Bot API error (${statusCode}).`;
  const code = toStringValue(body.error_code) || toStringValue(body.code) || undefined;

  return new OfficialBotApiError(description, statusCode, code);
}

function extractMessageId(value: unknown): string | undefined {
  if (!isRecord(value)) return undefined;
  return (
    toStringValue(value.message_id) ||
    toStringValue(value.messageId) ||
    toStringValue(value.msg_id) ||
    toStringValue(value.id) ||
    undefined
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function toStringValue(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}
