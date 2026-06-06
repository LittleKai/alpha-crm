import { readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

async function collectTests(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...await collectTests(path));
    } else if (entry.name.endsWith('.test.js')) {
      files.push(path);
    }
  }
  return files;
}

const tests = await collectTests('dist');
if (tests.length === 0) {
  throw new Error('No compiled tests found under dist.');
}

const child = spawn(process.execPath, ['--test', ...tests], {
  stdio: 'inherit',
  shell: false,
});
child.on('exit', (code) => {
  process.exit(code ?? 1);
});
