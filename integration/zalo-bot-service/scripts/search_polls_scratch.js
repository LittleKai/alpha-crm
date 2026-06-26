import Database from 'better-sqlite3';
import path from 'path';
import os from 'os';

const dataRoot = path.join(os.homedir(), 'AppData', 'Local', 'AlphaCRM', 'zalo-bot-service');
const dbPath = path.join(dataRoot, 'live-chat', 'live-chat.sqlite');

try {
  console.log(`Opening DB at: ${dbPath}`);
  const db = new Database(dbPath);
  
  const polls = db.prepare("SELECT id, messageType, content, receivedAt, sentAt FROM messages WHERE messageType = 'poll' OR content LIKE '%poll%' LIMIT 5").all();
  console.log(`Found ${polls.length} poll messages:`);
  console.log(JSON.stringify(polls, null, 2));

} catch (err) {
  console.error('Error running script:', err);
}
