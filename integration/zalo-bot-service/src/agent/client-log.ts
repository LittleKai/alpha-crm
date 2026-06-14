import fs from 'fs';
import { resolve } from 'path';
import { projectRoot } from '../config.js';

const clientLogDirectory = resolve(projectRoot, '.data/logs');
const clientLogFilePath = resolve(clientLogDirectory, 'client_errors.json');

export interface ClientLog {
  id: string;
  message: string;
  error?: string;
  stackTrace?: string;
  platform?: string;
  timestamp: string;
}

function ensureLogDirectory(): void {
  if (!fs.existsSync(clientLogDirectory)) {
    fs.mkdirSync(clientLogDirectory, { recursive: true });
  }
}

export function saveClientLog(logData: Partial<ClientLog>): void {
  ensureLogDirectory();
  
  const log: ClientLog = {
    id: `log_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
    message: logData.message || 'Unknown Error',
    error: logData.error,
    stackTrace: logData.stackTrace,
    platform: logData.platform || 'Unknown',
    timestamp: logData.timestamp || new Date().toISOString(),
  };

  let logs: ClientLog[] = [];
  if (fs.existsSync(clientLogFilePath)) {
    try {
      const content = fs.readFileSync(clientLogFilePath, 'utf-8');
      logs = JSON.parse(content);
    } catch {
      logs = [];
    }
  }

  // Keep latest 500 logs
  logs.unshift(log);
  if (logs.length > 500) {
    logs = logs.slice(0, 500);
  }

  fs.writeFileSync(clientLogFilePath, JSON.stringify(logs, null, 2), 'utf-8');
}

export function getClientLogs(): ClientLog[] {
  if (!fs.existsSync(clientLogFilePath)) {
    return [];
  }
  try {
    const content = fs.readFileSync(clientLogFilePath, 'utf-8');
    return JSON.parse(content);
  } catch {
    return [];
  }
}
