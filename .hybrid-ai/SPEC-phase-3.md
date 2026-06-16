# SPEC Phase 3 — Release hardening: smoke-test the staged backend before zipping

## Goal

Make `release-to-b2.js` **fail fast** when the bundled Windows backend is broken, instead of
shipping a dead backend to customers. Two guards, run after staging and before zipping:
1. **Assert `zca-js` is a real package**, not a junction/symlink (regression guard for the
   session-#52 bug where a local junction broke the packaged backend).
2. **Smoke-test the staged backend**: boot `node.exe dist/server.js` on a throwaway port, poll
   `/health` until it returns 200 `{ "status": "ok" }`, then tree-kill it. Abort the release if it
   never becomes healthy.

## Context Pack (read this; do not explore further)

**⚠️ File to modify is OUTSIDE the Flutter project root. Modify ONLY this exact file:**
`D:\Dev\NodeJS\alpha-studio\alpha-studio-backend\scripts\release-to-b2.js`
Do **not** create a copy under `tools/alpha-crm`. Do not touch any other file.

**The script is plain Node ESM** (`import ...`, top-level `async function main()` called at the
bottom with `main();`). Node 18+ is assumed (so `http` core module is available).

**Current imports (verbatim, top of file):**
```js
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';
import { S3Client, PutObjectCommand, GetObjectCommand, ListObjectsV2Command, DeleteObjectsCommand } from '@aws-sdk/client-s3';
import dotenv from 'dotenv';
import readline from 'readline';
```

**Staging function already present:** `function stageZaloBackendForWindows(winReleaseDir) { ... }`.
It stages the backend into `path.join(winReleaseDir, 'zalo-bot-service')`, copying `dist/`,
`node_modules/`, `package.json`, `.env.example`, writing a `.env` with `PORT=8787`, and copying
the build machine's Node runtime to `<serviceReleaseDir>/node.exe`.

**Where staging is called (verbatim anchor, inside `async function main()`, step `[4/5]`):**
```js
    try {
        stageZaloBackendForWindows(winReleaseDir);
        console.log('Local Zalo backend staged beside the Windows app.');

        // Utilize native PowerShell Compress-Archive since the workspace is on Windows
        const zipCmd = `powershell -Command "Compress-Archive -Path '${winReleaseDir}\\*' -DestinationPath '${zipDestPath}' -Force"`;
```

**Backend boot behavior (why the smoke-test is safe & meaningful):** `dist/server.js` starts an
HTTP server and answers `GET /health` immediately with `{ "status": "ok", ... }`. It does **not**
require a Zalo login at boot (it logs "Waiting for Flutter session sync before starting CRM
runtime."). Config reads `process.env` first, so passing `PORT` in the child env overrides the
staged `.env`'s `PORT=8787`.

## No-Placeholder Contract

This phase must ship working behavior. The smoke-test must actually boot the staged backend and
assert a real 200 `/health`. No mock/no-op verification.

## Deferred Work

None. (Version-stamping the ZIP filename for rollback is explicitly out of scope per `SPEC.md`.)

## Steps

### Step 1 — Add `spawn` and the `http` module to imports

**File:** `alpha-studio-backend/scripts/release-to-b2.js`
**Location anchor:** The import line `import { execSync } from 'child_process';`.
**Action:** Replace that single line with:
```js
import { execSync, spawn } from 'child_process';
import http from 'http';
```
**Do NOT:** reorder or remove the other imports.

### Step 2 — Add a `/health` poller and a `verifyStagedBackend` function

**File:** `alpha-studio-backend/scripts/release-to-b2.js`
**Location anchor:** Directly **above** the existing line
`function stageZaloBackendForWindows(winReleaseDir) {`.
**Action:** Add these two functions:
```js
/**
 * Polls http://127.0.0.1:<port>/health until it returns 200 {status:'ok'} or times out.
 * Resolves true if healthy, false on timeout.
 */
function waitForHealth(port, timeoutMs) {
    return new Promise((resolve) => {
        const deadline = Date.now() + timeoutMs;
        const retry = () => {
            if (Date.now() >= deadline) { resolve(false); return; }
            setTimeout(tryOnce, 500);
        };
        const tryOnce = () => {
            const req = http.get(
                { host: '127.0.0.1', port, path: '/health', timeout: 2000 },
                (res) => {
                    let body = '';
                    res.on('data', (c) => { body += c; });
                    res.on('end', () => {
                        try {
                            const json = JSON.parse(body);
                            if (res.statusCode === 200 && json.status === 'ok') {
                                resolve(true);
                                return;
                            }
                        } catch { /* not ready yet */ }
                        retry();
                    });
                }
            );
            req.on('error', retry);
            req.on('timeout', () => { req.destroy(); retry(); });
        };
        tryOnce();
    });
}

/**
 * Hardening guard: asserts zca-js is a real package (not a junction/symlink) and boots the
 * staged backend on a throwaway port to confirm it serves /health before we zip & upload.
 * Throws (aborting the release) if anything is wrong.
 */
async function verifyStagedBackend(serviceReleaseDir) {
    // 1. zca-js must be a real installed package, not a junction/symlink (regression: session #52).
    const zcaPath = path.join(serviceReleaseDir, 'node_modules', 'zca-js');
    const zcaStat = fs.lstatSync(zcaPath); // throws if missing
    if (zcaStat.isSymbolicLink()) {
        throw new Error(
            `[verify] zca-js in the staged bundle is a symlink/junction, not a real package: ${zcaPath}. ` +
            `Reinstall it from the registry (npm install zca-js@2.1.2) and re-run the release.`
        );
    }
    if (!fs.existsSync(path.join(zcaPath, 'package.json'))) {
        throw new Error(`[verify] zca-js package.json missing in staged bundle: ${zcaPath}`);
    }

    // 2. Smoke-test: boot the staged backend on a throwaway port and wait for /health.
    const nodeExe = path.join(serviceReleaseDir, 'node.exe');
    const entryJs = path.join(serviceReleaseDir, 'dist', 'server.js');
    const SMOKE_PORT = 8799;

    console.log(`[verify] Smoke-testing staged backend on port ${SMOKE_PORT}...`);
    const child = spawn(nodeExe, [entryJs], {
        cwd: serviceReleaseDir,
        env: {
            ...process.env,
            PORT: String(SMOKE_PORT),
            LOCAL_BIND_PORT: String(SMOKE_PORT),
            NODE_ENV: 'production',
        },
        stdio: 'inherit',
    });

    let healthy = false;
    try {
        healthy = await waitForHealth(SMOKE_PORT, 15000);
    } finally {
        try {
            if (process.platform === 'win32') {
                execSync(`taskkill /PID ${child.pid} /T /F`, { stdio: 'ignore' });
            } else {
                child.kill('SIGKILL');
            }
        } catch { /* process may already be gone */ }
    }

    // Remove the ephemeral active-port.json the smoke-test wrote so it is not shipped.
    try {
        fs.rmSync(path.join(serviceReleaseDir, '.data', 'active-port.json'), { force: true });
    } catch { /* ignore */ }

    if (!healthy) {
        throw new Error(
            '[verify] Staged backend failed the /health smoke-test — release aborted. ' +
            'Inspect the staged dist/ and node_modules under ' + serviceReleaseDir + '.'
        );
    }
    console.log('[verify] Staged backend responded healthy on /health. OK.');
}
```
**Do NOT:** change `stageZaloBackendForWindows`. Do NOT add a new npm dependency (uses core
`http`/`child_process` only).

### Step 3 — Call `verifyStagedBackend` after staging, before zipping

**File:** `alpha-studio-backend/scripts/release-to-b2.js`
**Location anchor:** Inside `main()`, the two lines:
```js
        stageZaloBackendForWindows(winReleaseDir);
        console.log('Local Zalo backend staged beside the Windows app.');
```
**Action:** Insert immediately after the `console.log('Local Zalo backend staged beside the Windows app.');`
line (and before the `// Utilize native PowerShell Compress-Archive...` comment):
```js
        await verifyStagedBackend(path.join(winReleaseDir, 'zalo-bot-service'));
```
**Do NOT:** move the zip command; only insert the one `await` line. (`main` is already `async`, so
`await` is valid here.)

## Validation Plan

```bash
# 1. Syntax check (no execution side effects)
cd D:/Dev/NodeJS/alpha-studio/alpha-studio-backend
node --check scripts/release-to-b2.js
#    Expect: no output, exit 0

# 2. Confirm the guards are wired in
rg -n "verifyStagedBackend|waitForHealth|taskkill|isSymbolicLink" scripts/release-to-b2.js

# 3. Placeholder scan
rg -n "TODO|FIXME|placeholder" scripts/release-to-b2.js
```

Behavioral verification (manual, requires a Windows build to have produced a staged bundle):
1. Produce a staged bundle by running a normal release once (or build Windows + stage), so
   `tools/alpha-crm/build/windows/x64/runner/Release/zalo-bot-service/` exists with `node.exe`
   and `dist/server.js`.
2. **Positive:** run the release; confirm the log shows
   `[verify] Staged backend responded healthy on /health. OK.` before zipping.
3. **Negative:** temporarily rename the staged `dist/server.js`, run the release again, and
   confirm it **aborts** with `[verify] Staged backend failed the /health smoke-test — release aborted.`
   (restore the file afterward).

## Dependencies

None — independent of Phases 1–2 (different project, different file). Can be implemented and
verified on its own.
