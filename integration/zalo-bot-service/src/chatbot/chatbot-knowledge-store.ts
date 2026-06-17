import { createHash } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  readdirSync,
  writeFileSync,
} from 'node:fs';
import { extname, resolve } from 'node:path';
import { projectRoot } from '../config.js';

// Knowledge files attached to the auto-chatbot live ONLY on the operator's
// machine (the same machine that owns the Zalo session). The cloud stores just
// name/type/description + this content-hash id. Files are sent straight from
// here — no download, no B2.
const KNOWLEDGE_DIR = resolve(projectRoot, '.data/chatbot-knowledge');

function ensureDir(): void {
  if (!existsSync(KNOWLEDGE_DIR)) {
    mkdirSync(KNOWLEDGE_DIR, { recursive: true });
  }
}

// A stored file is named "<id><ext>" where id is a hex sha256 (no dots), so the
// id is always everything before the first dot.
function idOfStoredName(storedName: string): string {
  const dot = storedName.indexOf('.');
  return dot === -1 ? storedName : storedName.slice(0, dot);
}

function sanitizeExt(filename: string): string {
  const ext = extname(filename).toLowerCase();
  // Keep only a plain ".alnum" extension; zca-js infers media kind from it.
  return /^\.[a-z0-9]{1,8}$/.test(ext) ? ext : '';
}

export interface SavedKnowledgeFile {
  id: string;
  name: string;
}

/**
 * Persist an operator-attached knowledge file. The id is the content hash, so
 * re-uploading the same bytes is idempotent (and dedups across documents).
 */
export function saveKnowledgeFile(
  bytes: Buffer,
  filename: string,
): SavedKnowledgeFile {
  ensureDir();
  const id = createHash('sha256').update(bytes).digest('hex');
  const storedName = `${id}${sanitizeExt(filename)}`;
  const target = resolve(KNOWLEDGE_DIR, storedName);
  if (!existsSync(target)) {
    writeFileSync(target, bytes);
  }
  return { id, name: filename };
}

/** Resolve a stored file id to its absolute local path, or null if missing. */
export function resolveKnowledgeFilePath(id: string): string | null {
  if (!id || !/^[a-f0-9]{8,}$/i.test(id) || !existsSync(KNOWLEDGE_DIR)) {
    return null;
  }
  for (const entry of readdirSync(KNOWLEDGE_DIR)) {
    if (idOfStoredName(entry) === id) {
      return resolve(KNOWLEDGE_DIR, entry);
    }
  }
  return null;
}

/** List the ids of every knowledge file currently present on this machine. */
export function listKnowledgeFileIds(): string[] {
  if (!existsSync(KNOWLEDGE_DIR)) return [];
  const ids = new Set<string>();
  for (const entry of readdirSync(KNOWLEDGE_DIR)) {
    ids.add(idOfStoredName(entry));
  }
  return [...ids];
}
