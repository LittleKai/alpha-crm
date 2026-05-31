/**
 * Personal Zalo login bootstrap — CLI-only, server-side.
 * Captures personal Zalo credentials via QR code and saves to local file.
 *
 * Usage: npm run zalo:login-personal
 *
 * SECURITY: This script runs locally only. It does NOT expose QR or
 * credentials via HTTP. Cookie/token values are NOT printed to console.
 */

import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';
import { config, projectRoot } from './config.js';
import { Zalo, LoginQRCallbackEventType } from 'zca-js';
import type { LoginQRCallback, LoginQRCallbackEvent } from 'zca-js';

async function main(): Promise<void> {
  const credPath = resolve(projectRoot, config.personalCredentialsPath);
  const qrPath = resolve(projectRoot, config.personalQrPath);

  // Ensure directory exists
  const credDir = dirname(credPath);
  if (!existsSync(credDir)) {
    mkdirSync(credDir, { recursive: true });
    console.log(`[login] Created directory: ${credDir}`);
  }

  console.log(`[login] Starting personal Zalo QR login...`);
  console.log(`[login] QR image will be saved to: ${qrPath}`);
  console.log(`[login] Credentials will be saved to: ${credPath}`);
  console.log('');

  const zalo = new Zalo({
    selfListen: config.personalSelfListen,
    logging: true,
  });

  const callback: LoginQRCallback = (event: LoginQRCallbackEvent) => {
    switch (event.type) {
      case LoginQRCallbackEventType.GotLoginInfo:
        if (event.data) {
          writeFileSync(credPath, JSON.stringify(event.data, null, 2), 'utf-8');
          console.log(`[login] ✅ Credentials saved to: ${credPath}`);
          console.log('[login] DO NOT commit this file to version control.');
        }
        break;
      default:
        console.log(`[login] Event: ${event.type}`);
        break;
    }
  };

  try {
    const api = await zalo.loginQR(
      {
        qrPath,
        language: 'vi',
      },
      callback,
    );

    if (api) {
      console.log('');
      console.log('[login] ✅ Login successful!');
      console.log(`[login] Account label: ${config.personalAccountLabel}`);
      console.log(`[login] Credentials file: ${credPath}`);
      console.log('[login] You can now start the service with: npm start');
    }
  } catch (err) {
    console.error(
      '[login] ❌ Login failed:',
      err instanceof Error ? err.message : err,
    );
    process.exit(1);
  }

  process.exit(0);
}

main();
