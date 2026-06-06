import type { ServerResponse } from 'http';

export interface LocalSessionEvent {
  type: 'session.revoked';
  code: 'DEVICE_REVOKED';
  reason: string;
}

export class SessionEventHub {
  private readonly clients = new Set<ServerResponse>();

  addClient(response: ServerResponse): () => void {
    this.clients.add(response);
    response.write(': connected\n\n');
    return () => {
      this.clients.delete(response);
    };
  }

  publish(event: LocalSessionEvent): void {
    const payload = `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`;
    for (const client of this.clients) {
      try {
        client.write(payload);
      } catch {
        this.clients.delete(client);
      }
    }
  }

  keepAlive(): void {
    for (const client of this.clients) {
      try {
        client.write(': keepalive\n\n');
      } catch {
        this.clients.delete(client);
      }
    }
  }

  close(): void {
    for (const client of this.clients) {
      client.end();
    }
    this.clients.clear();
  }
}
