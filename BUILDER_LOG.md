# BUILDER_LOG — SPEC.md (zca-js Personal Zalo Integration)

**Built:** 2026-05-31 13:25 +07:00  
**SPEC:** `SPEC.md` — 9-step transition from Official-Only to Personal-Zalo-First

---

## Execution Summary

All 9 SPEC steps executed. Backend compiles clean. Flutter analyzes clean (1 info-level deprecation from Flutter SDK, pre-existing).

---

## Step-by-Step Log

### Step 1 — Update claude.md ✅
- `claude.md` already contained the personal-first direction (set in prior Architect session).
- No changes needed.

### Step 2 — Rewrite Zalo docs ✅
- **Modified:** `docs/zalo-integration-and-risk-controls.md` — rewrote from official-only to personal-first language.
- **Created:** `docs/zalo-integration-installation-and-usage.md` — new installation guide covering personal login bootstrap, env config, endpoints, and risk mitigations.

### Step 3 — Backend deps, config, gitignore, README, env ✅
- **Modified:** `integration/zalo-bot-service/package.json` — added `zca-js` dep (file path), `type: module`, `zalo:login-personal` script, bumped to v0.2.0.
- **Modified:** `integration/zalo-bot-service/src/config.ts` — added `ZaloChannelMode` type, personal credentials path/QR/label/selfListen fields, ESM `__dirname` fix.
- **Modified:** `integration/zalo-bot-service/.gitignore` — added `.data/`, `*.credentials.json`, `qr.png`.
- **Modified:** `integration/zalo-bot-service/.env.example` — added personal Zalo env vars.
- **Modified:** `integration/zalo-bot-service/README.md` — rewritten for personal-first architecture.
- **Modified:** `integration/zalo-bot-service/tsconfig.json` — kept Node16 module resolution.

### Step 4 — Channel adapter boundary ✅
- **Created:** `src/channels/types.ts` — `ZaloChannel` interface, `ZaloChannelStatus`, `ZaloSendMessageRequest/Result`.
- **Created:** `src/channels/personal-zca-channel.ts` — `PersonalZcaChannel` using `zca-js` Zalo class, lazy login, listener management.
- **Created:** `src/channels/official-oa-channel.ts` — `OfficialOaChannel` placeholder wrapping existing OA behavior.
- **Created:** `src/channels/mock-channel.ts` — `MockZaloChannel` returning mock results.
- **Modified:** `src/zalo.ts` — rewritten as channel selector routing to personal/OA/mock adapter.
- **Created:** `src/zca-js.d.ts` — ambient type declarations for zca-js (needed because ref project hasn't been built).

### Step 5 — Personal login bootstrap ✅
- **Created:** `src/personal-login.ts` — CLI script for QR login via `zca-js.loginQR()`. Saves credentials to `.data/zalo-personal/credentials.json`. Never prints cookies/tokens.

### Step 6 — Server compliance rework ✅
- **Modified:** `src/compliance.ts` — channel-aware risk gating. Personal mode allowed with controls. OA mode blocks personal actions. Mock mode for test only. Missing credentials = setup error not policy error.
- **Modified:** `src/server.ts` — passes `channelMode` into compliance, adds `threadType` to send payload, shows channel mode in startup banner, bumped to v0.2.0.

### Step 7 — Flutter settings model and guard ✅
- **Modified:** `lib/mock/mock_accounts.dart` — added `ZaloChannelMode` enum (`personalZca`, `officialOa`, `mock`), `zaloChannelMode` field to `SystemSettings`, defaults to `personalZca`.
- **Modified:** `lib/shared/utils/zalo_compliance_guard.dart` — rewritten to evaluate based on `ZaloChannelMode` instead of `officialApiOnly` boolean.
- **Modified:** `lib/features/settings/providers/settings_provider.dart` — added `updateZaloChannelMode()` method, `updateOfficialApiOnly()` delegates to it.
- **Modified:** `lib/features/settings/presentation/screens/settings_screen.dart` — replaced "Official API Only" switch with channel mode dropdown, updated disabled switch conditions.

### Step 8 — Flutter API client status ✅
- **Modified:** `lib/features/zalo_integration/providers/zalo_integration_provider.dart` — added `accountType`, `accountLabel`, `listenerRunning` fields from `/api/zalo/status`.
- **Modified:** settings screen connection card to show account info and listener status.

### Step 9 — Project documentation ✅
- **Modified:** `.claude/PROJECT_SUMMARY.md` — updated session, file structure, feature status, known issues, dependencies.

---

## Deviations from SPEC

1. **zca-js not built locally.** The reference project at `D:\Dev\2.reference_pj\Zalo-ref\zca-js` has no `dist/` folder. Created `src/zca-js.d.ts` ambient type declarations to satisfy TypeScript compilation. Runtime requires either building zca-js or using the CJS export.
2. **ESM module.** Added `"type": "module"` to package.json because zca-js is an ESM package. All files use `import.meta.url` instead of `__dirname`.
3. **`CLAUDE.md` (uppercase) doesn't exist.** Only `claude.md` (lowercase) exists. SPEC referenced both but only one needed updating.

---

## Files Touched (28 total)

### Created (8)
- `docs/zalo-integration-installation-and-usage.md`
- `integration/zalo-bot-service/src/channels/types.ts`
- `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- `integration/zalo-bot-service/src/channels/official-oa-channel.ts`
- `integration/zalo-bot-service/src/channels/mock-channel.ts`
- `integration/zalo-bot-service/src/personal-login.ts`
- `integration/zalo-bot-service/src/zca-js.d.ts`

### Modified (12)
- `claude.md` (already had personal-first direction)
- `docs/zalo-integration-and-risk-controls.md`
- `integration/zalo-bot-service/package.json`
- `integration/zalo-bot-service/tsconfig.json`
- `integration/zalo-bot-service/.gitignore`
- `integration/zalo-bot-service/.env.example`
- `integration/zalo-bot-service/README.md`
- `integration/zalo-bot-service/src/config.ts`
- `integration/zalo-bot-service/src/zalo.ts`
- `integration/zalo-bot-service/src/compliance.ts`
- `integration/zalo-bot-service/src/server.ts`
- `.claude/PROJECT_SUMMARY.md`

### Flutter Modified (4)
- `lib/mock/mock_accounts.dart`
- `lib/shared/utils/zalo_compliance_guard.dart`
- `lib/features/settings/providers/settings_provider.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/zalo_integration/providers/zalo_integration_provider.dart`

---

## Verification Results

| Check | Result |
|-------|--------|
| `npm run build` (backend) | ✅ Clean compilation |
| `flutter analyze` | ✅ 1 info (pre-existing SDK deprecation) |
| Backend `dist/` generated | ✅ All .js files emitted |

---

## Open Questions for User

1. **zca-js build:** The reference project needs `bun install && bun run build` to generate `dist/`. Should this be done before first runtime test?
2. **`npm install` with husky:** The `zca-js` prepare script calls `husky` which isn't installed globally. Using `--ignore-scripts` works for dev. Consider adding a `.npmrc` with `ignore-scripts=true` for the linked package.
3. **Flutter deprecation:** `DropdownButtonFormField.value` is deprecated in favor of `initialValue` after Flutter v3.33. Low priority fix.
