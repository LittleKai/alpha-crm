# SPEC — Production backend startup reliability (Alpha CRM Windows)

## Goal

Make the bundled Node sidecar backend (`integration/zalo-bot-service`) start **reliably and
correctly** in the Windows production build of Alpha CRM, and make the release packaging
**fail fast** when the bundled backend is broken. This fixes user reports of "backend không
khởi động" (won't start) and "khởi động không đúng" (starts but the app can't reach it).

### Root causes (already diagnosed — do NOT re-investigate)

1. **`active-port.json` path mismatch.** The backend writes the chosen port to
   `<serviceDir>/.data/active-port.json` (its `projectRoot` is the folder containing `dist/`),
   but Flutter's `ZaloBackendManager._getActivePortFile()` reads
   `<launcherDir>/.data/active-port.json` (the folder containing the `.cmd`). In the production
   layout `launcherDir` = `<Release>` and `serviceDir` = `<Release>/zalo-bot-service`, so the
   two paths **never match**. Port detection therefore always silently falls back to hardcoded
   `8787`, and the backend's `EADDRINUSE` port-walk (8787→8788→…) is effectively dead: the
   backend moves to a new port while Flutter keeps polling 8787.

2. **Orphaned `node.exe` (the recurring failure).** Flutter starts the backend with
   `Process.start('zalo-bot-service.cmd', runInShell: true)`, creating a process tree
   `cmd.exe → node.exe`. `stopBackend()` calls `_backendProcess.kill()`, which terminates only
   `cmd.exe`; the child `node.exe` **orphans** and keeps holding port 8787. The next app launch
   then hits `EADDRINUSE` → port-walk → root cause #1 → the app can't reach the new backend.
   The failure compounds across crashes/restarts.

3. **Startup failure is swallowed.** `waitUntilReady()` returning `false` is ignored; the UI
   proceeds. There is no file log in release builds (only `debugPrint`, which is stripped), no
   retry, and no check that the backend process is still alive vs. merely slow.

4. **(Build) No smoke-test of the packaged backend.** `release-to-b2.js` zips and uploads the
   Windows bundle without ever running the staged backend, so packaging breakage (missing
   module, or a `zca-js` junction/symlink like the session-#52 bug) only surfaces on the
   customer machine.

### Fix direction (decided)

- **Launch `node.exe` directly** (`<serviceDir>/node.exe <serviceDir>/dist/server.js` with
  `workingDirectory = <serviceDir>`) instead of going through the `.cmd` wrapper. This yields a
  single killable process (no orphans), no console flash, and — because `workingDirectory` is
  the service dir — makes the port file land exactly where Flutter reads it. Keep the existing
  `.cmd`/`.exe`/`.bat` launcher search as a **fallback** (dev / older bundles), and fix the
  fallback's port-file path too.
- **Reuse-or-replace:** before spawning, probe `/health`; if a healthy instance of our backend
  already answers, reuse it instead of spawning a duplicate.
- **Tree-kill on shutdown** (`taskkill /PID <pid> /T /F` on Windows) as a second line of defense.
- **Liveness + logging:** `waitUntilReady` bails early if the process already exited; route
  backend stdout/stderr and startup steps through the existing `AppLogger` (file log); add a
  bounded startup retry in `main.dart`.
- **Release smoke-test:** after staging the Windows bundle, run the staged `node.exe dist/server.js`
  on a throwaway port, poll `/health` until 200, then tree-kill it. Also assert `zca-js` is a
  real package (not a junction/symlink). Fail the release if either check fails.

## Phases

Execute in order. Each phase file is self-contained.

| Phase | File | Scope | Depends on |
|-------|------|-------|-----------|
| 1 | `SPEC-phase-1.md` | **Flutter `ZaloBackendManager.startBackend()`** — reuse-or-replace `/health` probe; launch `node.exe` directly with `.cmd` fallback; fix `_getActivePortFile()` to resolve the service-dir `.data/active-port.json` in both modes. | none |
| 2 | `SPEC-phase-2.md` | **Flutter shutdown + observability** — tree-kill in `stopBackend()`; liveness short-circuit + correct port in `waitUntilReady()`; route logs through `AppLogger`; bounded startup retry in `main.dart`. | Phase 1 |
| 3 | `SPEC-phase-3.md` | **Release hardening (cross-project)** — in `alpha-studio-backend/scripts/release-to-b2.js`, assert `zca-js` is not a symlink/junction and smoke-test the staged backend (`/health` 200) before zipping. | none (independent; can run anytime) |

## Global conventions (apply to every phase)

- **Flutter project root:** `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm`. Phase 1–2 paths are
  relative to it. **Phase 3 edits a file OUTSIDE this root** — its absolute path is given in
  that phase; do not create a copy inside `tools/alpha-crm`.
- **Flutter app** uses inline **Vietnamese** debug strings (no i18n framework). No new packages.
  Existing imports in `zalo_backend_manager.dart`: `dart:convert`, `dart:io`,
  `package:flutter/foundation.dart` (for `debugPrint`, `kIsWeb`, `kDebugMode`),
  `package:http/http.dart as http`.
- **Backend** is TypeScript compiled to `dist/`. Tests use Node's built-in runner
  (`node:test`, `node:assert/strict`) run via `npm.cmd test`. The release script is **plain
  Node ESM** (`.js`, `import`), run with `node scripts/release-to-b2.js`.
- **Surgical changes only.** Touch only the files named in each phase. Do not rename existing
  params/identifiers, do not refactor surrounding code, do not reformat untouched lines, do not
  add dependencies.

## Out of scope / deferred (do not implement)

- Version-stamping the Windows ZIP filename for rollback (separate future task).
- Any new UI screen for backend status — failure surfacing relies on the **existing** health-based
  warning in the Zalo integration provider / dashboard (sessions #39), plus the new file logs.
- Changing the backend's own port-binding logic in `server.ts`/`config.ts` (it already writes
  `active-port.json` correctly relative to its `projectRoot`; only the Flutter read path is wrong).
- Replacing the hardcoded `8787` in `AppLogger._reportToBackend` (unrelated).

## Final verification (run after Phases 1–2; Phase 3 verified inside its own file)

```bash
cd D:/Dev/NodeJS/alpha-studio/tools/alpha-crm
flutter analyze        # no new error/warning (existing baseline info lints only)
flutter test           # all pass (currently 98/98), incl. new ZaloBackendManager tests
flutter run -d windows # backend comes up; close app; confirm NO orphan node.exe in Task Manager
```

After all phases pass, update `.claude/PROJECT_SUMMARY.md` (Last Updated timestamp + new session
entry) and add an entry to `.claude/IMPORTANT_FIXED_BUGS.md` for the active-port path mismatch +
orphaned-node.exe bugs (high-impact, hard to detect, likely to recur).
