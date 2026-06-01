# Alpha CRM zca-js Personal Zalo Integration SPEC

**Architect:** Codex using `architect` skill  
**Created:** 2026-05-31 12:30 +07:00  
**Target project:** `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm`  
**Reference project:** `D:\Dev\2.reference_pj\Zalo-ref\zca-js`

---

## Goal

Integrate Alpha CRM with the local `zca-js` project as the primary Zalo channel for personal-account workflows, while keeping Zalo Official Account / OA integration available as a secondary channel.

This replaces the previous official-only Zalo integration direction. The new architecture is personal-Zalo-first, backend-contained, risk-aware, and adapter-based so the product can still switch to OA where official APIs are required.

---

## Context / Constraints

### Product Direction

The requested product priority is:

1. Use personal Zalo first through `zca-js`.
2. Keep Zalo OA / Official API as an optional fallback or secondary adapter.
3. Do not put personal Zalo cookies, IMEI, QR artifacts, access tokens, or user-agent secrets in Flutter.
4. Keep all Zalo credentials and sessions inside the Node backend service.
5. Keep user-facing UI explicit about channel mode, connection status, and account risk.

### Existing Alpha CRM Reality

Alpha CRM currently has:

- Flutter UI in `lib/` with Riverpod providers and mock-first feature screens.
- Settings/risk controls in `lib/features/settings/**` and `lib/mock/mock_accounts.dart`.
- A Flutter-side guard in `lib/shared/utils/zalo_compliance_guard.dart`.
- A backend bridge in `integration/zalo-bot-service/`.
- Existing backend files: `src/config.ts`, `src/server.ts`, `src/zalo.ts`, `src/compliance.ts`.
- Existing backend dependency on `zalo-bot-js` and placeholder OA send behavior.
- Existing docs that still say official-only or prohibit QR/session/cookie personal flows.

### zca-js Reality

The local `zca-js` project is a TypeScript library for unofficial Zalo Web personal-account API access. It supports:

- `new Zalo().login(credentials)` with cookie, IMEI, and user agent.
- `new Zalo().loginQR(...)` for QR login and credential capture.
- `api.sendMessage(...)`, `api.uploadAttachment(...)`, `api.listener`, and many personal-account API wrappers.
- `ThreadType.User` and `ThreadType.Group` message routing.
- Optional `imageMetadataGetter` for file-path image/GIF sending.

`zca-js` is unofficial and the reference README warns that use may lock or ban accounts. Treat this as an accepted product tradeoff for this SPEC, but do not remove backend-side limits, logs, approval gates, or status visibility.

### Architectural Constraints

- Flutter remains UI/advisory. It must not become the Zalo automation runtime.
- Node service is the credential/session/enforcement boundary.
- Implement adapter boundaries before wiring feature screens to real sends.
- Default channel mode should become personal (`personal_zca`) rather than official-only.
- OA support should remain present but optional (`official_oa`).
- Existing action names can remain, but the compliance language must change from "personal is blocked" to "personal is allowed only when configured and rate/approval/risk checks pass".
- Do not expose QR images, cookies, or session JSON through public HTTP endpoints in the first implementation. Use a local backend CLI bootstrap for personal login.

### Important Path Note

From `integration/zalo-bot-service`, the local `zca-js` package resolves on this machine with:

```text
file:../../../../../../2.reference_pj/Zalo-ref/zca-js
```

The current `zalo-bot-js` dependency path uses four `..` segments. Spot-checking from this workspace did not resolve that path. Builder must verify dependency paths before install.

---

## Proposed Architecture

```text
Alpha CRM Flutter UI
  -> HTTP
  -> integration/zalo-bot-service
      -> ZaloChannel interface
          -> PersonalZcaChannel       primary, uses zca-js personal account
          -> OfficialOaChannel        optional, existing OA path
          -> MockZaloChannel          test/dev fallback
      -> server-side risk guard
      -> credential/session files under ignored backend-local data directory
  -> Zalo Web personal account or OA API
```

### Channel Modes

Use a backend config value:

```text
ZALO_CHANNEL_MODE=personal_zca | official_oa | mock
```

Default for local/dev after this integration: `personal_zca`.

Recommended status values returned by `/api/zalo/status`:

```json
{
  "connected": true,
  "mode": "personal_zca",
  "accountType": "personal",
  "accountLabel": "Personal Zalo 1",
  "listenerRunning": false,
  "lastEventAt": null,
  "version": "0.2.0"
}
```

---

## Steps

### Step 1 - Keep Claude Instructions Personal-First

**Files:**

- Modify: `claude.md`
- Modify: `CLAUDE.md`

**Action:**

Add a Zalo integration direction section that states:

- Alpha CRM now prioritizes personal Zalo via `zca-js`.
- OA remains supported as a fallback/secondary adapter.
- Flutter must not store credentials, cookies, IMEI, user agent, QR files, or tokens.
- Backend service owns sessions and channel selection.
- Do not reintroduce official-only assumptions unless the user explicitly asks.
- Any personal-account workflow must keep risk controls, rate limits, audit logs, and manual approval gates where applicable.

Keep `claude.md` and `CLAUDE.md` synchronized because this project has both.

**Verify:**

```bash
rg -n "personal Zalo|zca-js|official_oa|personal_zca|Backend service owns" claude.md CLAUDE.md
```

Expected: both files contain the same personal-first direction.

---

### Step 2 - Update Zalo Documentation Direction

**Files:**

- Modify: `docs/zalo-integration-and-risk-controls.md`
- Modify: `docs/zalo-integration-installation-and-usage.md`

**Action:**

Rewrite the current official-only language into personal-first language:

- State that `zca-js` personal mode is the primary local/product direction.
- Keep OA as optional secondary channel for policy-sensitive or official template/ZNS needs.
- Replace absolute prohibitions such as "no QR login/cookie/session personal account" with scoped rules: personal credentials are allowed only in backend-local storage, never Flutter or repo.
- Keep risk explanations and limits, but do not frame personal mode as inherently blocked.
- Document backend CLI login bootstrap and ignored credential storage.
- Update installation guide to use `zca-js` dependency and new env values.

Recommended new env fields:

```env
ZALO_CHANNEL_MODE=personal_zca
ZALO_PERSONAL_CREDENTIALS_PATH=.data/zalo-personal/credentials.json
ZALO_PERSONAL_QR_PATH=.data/zalo-personal/qr.png
ZALO_PERSONAL_ACCOUNT_LABEL=Personal Zalo 1
ZALO_PERSONAL_SELF_LISTEN=false

# Optional secondary OA mode
ZALO_OA_ID=
ZALO_OA_SECRET=
ZALO_OA_ACCESS_TOKEN=
ZALO_OA_REFRESH_TOKEN=
```

**Verify:**

```bash
rg -n "personal_zca|zca-js|ZALO_CHANNEL_MODE|ZALO_PERSONAL_CREDENTIALS_PATH|official_oa" docs/zalo-integration-and-risk-controls.md docs/zalo-integration-installation-and-usage.md
rg -n "Official API only|Không sử dụng QR login|personal-account automation trong Alpha CRM|official-only" docs/zalo-integration-and-risk-controls.md docs/zalo-integration-installation-and-usage.md
```

Expected: first command finds the new direction. Second command finds no stale absolute prohibition, or only finds it in a clearly marked legacy/migration note.

---

### Step 3 - Update Backend Dependencies and Config

**Files:**

- Modify: `integration/zalo-bot-service/package.json`
- Modify: `integration/zalo-bot-service/package-lock.json` after install
- Modify: `integration/zalo-bot-service/src/config.ts`
- Modify: `integration/zalo-bot-service/README.md`
- Modify: `integration/zalo-bot-service/.gitignore` if present, otherwise root `.gitignore`

**Action:**

Add `zca-js` as the primary dependency. Keep `zalo-bot-js` only if the builder is also keeping the OA adapter in this phase.

Recommended package dependency for local integration:

```json
"zca-js": "file:../../../../../../2.reference_pj/Zalo-ref/zca-js"
```

Add config fields:

```ts
export type ZaloChannelMode = 'personal_zca' | 'official_oa' | 'mock';

interface Config {
  channelMode: ZaloChannelMode;
  personalCredentialsPath: string;
  personalQrPath: string;
  personalAccountLabel: string;
  personalSelfListen: boolean;
  // existing OA fields remain optional
}
```

Default config should be:

```ts
channelMode: (process.env['ZALO_CHANNEL_MODE'] as ZaloChannelMode) || 'personal_zca'
```

Add ignored backend-local credential paths:

```text
integration/zalo-bot-service/.data/
integration/zalo-bot-service/*.credentials.json
integration/zalo-bot-service/qr.png
```

**Verify:**

```bash
cd integration/zalo-bot-service
npm install
npm run build
rg -n "zca-js|ZALO_CHANNEL_MODE|personal_zca|personalCredentialsPath|personalQrPath" package.json src README.md
```

Expected: dependency installs, build passes, and config/docs mention personal mode.

---

### Step 4 - Add Channel Adapter Boundary

**Files:**

- Create: `integration/zalo-bot-service/src/channels/types.ts`
- Create: `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- Create: `integration/zalo-bot-service/src/channels/official-oa-channel.ts` if keeping OA implementation separate
- Create: `integration/zalo-bot-service/src/channels/mock-channel.ts`
- Modify: `integration/zalo-bot-service/src/zalo.ts`

**Action:**

Create an adapter interface that hides personal vs OA details from `server.ts`:

```ts
export interface ZaloChannelStatus {
  connected: boolean;
  mode: 'personal_zca' | 'official_oa' | 'mock' | 'disconnected';
  accountType: 'personal' | 'official' | 'mock' | 'none';
  accountLabel: string;
  listenerRunning: boolean;
  lastEventAt: string | null;
}

export interface ZaloSendMessageRequest {
  recipientId: string;
  message: string;
  threadType?: 'user' | 'group';
  messageType?: 'text' | 'template';
}

export interface ZaloSendMessageResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

export interface ZaloChannel {
  getStatus(): ZaloChannelStatus;
  sendMessage(req: ZaloSendMessageRequest, isTestMode?: boolean): Promise<ZaloSendMessageResult>;
  handleWebhookEvent?(event: Record<string, unknown>): void;
  startListener?(): Promise<void>;
  stopListener?(): Promise<void>;
}
```

`PersonalZcaChannel` should:

- Load credentials from `config.personalCredentialsPath`.
- Instantiate `new Zalo({ selfListen: config.personalSelfListen, logging: true })`.
- Login with `zalo.login(credentials)` lazily on first status/send or at service startup.
- Map `threadType: 'group'` to `ThreadType.Group`, otherwise `ThreadType.User`.
- Use `api.sendMessage({ msg: req.message }, req.recipientId, threadType)`.
- Return an actionable error if credentials are missing and tell the operator to run the login bootstrap script.

`OfficialOaChannel` can initially wrap existing placeholder behavior from `src/zalo.ts`.

`MockZaloChannel` should preserve test-send behavior without real Zalo calls.

`src/zalo.ts` should become the channel selector and keep existing exported functions so `server.ts` changes are minimal:

- `getZaloStatus()`
- `sendMessage(req, isTestMode)`
- `handleWebhookEvent(event)`

**Verify:**

```bash
rg -n "interface ZaloChannel|class PersonalZcaChannel|ThreadType|new Zalo|sendMessage" integration/zalo-bot-service/src
cd integration/zalo-bot-service && npm run build
```

Expected: channel interface exists, personal adapter imports `zca-js`, and the backend builds.

---

### Step 5 - Add Backend-Only Personal Login Bootstrap

**Files:**

- Create: `integration/zalo-bot-service/src/personal-login.ts`
- Modify: `integration/zalo-bot-service/package.json`
- Modify: `integration/zalo-bot-service/README.md`

**Action:**

Add a local CLI script that captures personal Zalo credentials server-side only:

- Ensure `.data/zalo-personal/` exists.
- Call `new Zalo().loginQR({ qrPath: config.personalQrPath }, callback)`.
- In the `GotLoginInfo` callback, write credentials JSON to `config.personalCredentialsPath`.
- Print only file paths and status, not cookie values.
- Exit after credentials are saved and a login check succeeds.

Add package script:

```json
"zalo:login-personal": "tsc && node dist/personal-login.js"
```

Do not add QR-login HTTP endpoints in this phase.

**Verify:**

```bash
cd integration/zalo-bot-service
npm run build
npm run zalo:login-personal
Test-Path .data/zalo-personal/credentials.json
```

Expected: QR login script builds and writes credentials locally. Do not commit `.data/`.

---

### Step 6 - Rework Server Compliance for Personal-First Mode

**Files:**

- Modify: `integration/zalo-bot-service/src/compliance.ts`
- Modify: `integration/zalo-bot-service/src/server.ts`

**Action:**

Change compliance from official-only blocking to channel-aware risk gating.

Add channel context to request:

```ts
channelMode: 'personal_zca' | 'official_oa' | 'mock';
allowPersonalAccountAutomation?: boolean;
requireHumanApproval?: boolean;
hasHumanApproval?: boolean;
```

Rules:

- `mock` is allowed for test mode only.
- `official_oa` requires existing official channel metadata and consent/recent-interaction rules.
- `personal_zca` is allowed when personal automation is enabled and server limits pass.
- Friend/group actions in personal mode require explicit allow flag and human approval for batch or high-risk actions.
- Batch limits, daily limits, quiet hours, failure-rate stop, and report stop remain enforced.
- Missing credentials should fail with a setup error, not a policy error.

`server.ts` should pass `config.channelMode` into compliance and status responses.

**Verify:**

```bash
rg -n "channelMode|personal_zca|allowPersonalAccountAutomation|hasHumanApproval" integration/zalo-bot-service/src/compliance.ts integration/zalo-bot-service/src/server.ts
cd integration/zalo-bot-service && npm run build
```

Expected: personal mode is not blanket-blocked; high-risk actions still require explicit flags/approval.

---

### Step 7 - Update Flutter Settings Model and Guard

**Files:**

- Modify: `lib/mock/mock_accounts.dart`
- Modify: `lib/features/settings/providers/settings_provider.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Modify: `lib/shared/utils/zalo_compliance_guard.dart`

**Action:**

Add a channel mode setting instead of treating `officialApiOnly` as the product default. To minimize churn, keep `officialApiOnly` temporarily if needed, but introduce the new source of truth:

```dart
enum ZaloChannelMode { personalZca, officialOa, mock }
```

Recommended defaults:

```dart
zaloChannelMode: ZaloChannelMode.personalZca,
officialApiOnly: false,
allowPersonalAccountAutomation: true,
allowProxyUsage: false,
allowFriendAutomation: false,
allowGroupAutomation: false,
requireConsentProof: true,
requireRecentInteraction: false,
requireHumanApproval: true,
```

Settings UI should show:

- Preferred channel: Personal Zalo (`zca-js`) / Official OA / Mock.
- Backend-only credential note.
- Personal account risk note.
- OA optional/fallback note.
- Current backend mode from `/api/zalo/status`.

`ZaloComplianceGuard` should:

- Stop saying personal automation is blocked just because official-only is enabled.
- Evaluate based on `zaloChannelMode`.
- In personal mode, allow live chat and normal replies when backend is connected.
- In personal mode, require explicit settings and approval for friend/group/bulk actions.
- In official mode, keep existing consent/recent-interaction checks.

**Verify:**

```bash
rg -n "ZaloChannelMode|personalZca|officialOa|zca-js|officialApiOnly" lib/mock lib/features/settings lib/shared/utils/zalo_compliance_guard.dart
flutter analyze
flutter test
```

Expected: UI and guard reflect personal-first mode and Flutter checks pass.

---

### Step 8 - Extend Flutter Backend API Client Status Handling

**Files:**

- Modify: `lib/features/zalo_integration/data/zalo_integration_api.dart`
- Modify: `lib/features/zalo_integration/providers/zalo_integration_provider.dart`
- Modify only if needed: `lib/features/settings/presentation/screens/settings_screen.dart`

**Action:**

Read new status fields from `/api/zalo/status`:

- `mode`
- `accountType`
- `accountLabel`
- `listenerRunning`
- `lastEventAt`
- `connected`

Display those fields in Settings without exposing secrets.

**Verify:**

```bash
rg -n "accountType|accountLabel|listenerRunning|lastEventAt|mode" lib/features/zalo_integration lib/features/settings
flutter analyze
flutter test
```

Expected: Settings can distinguish personal, official, mock, and disconnected states.

---

### Step 9 - Update Current-State Project Documentation

**Files:**

- Modify: `.claude/PROJECT_SUMMARY.md`
- Modify if conventions changed: `.claude/CONVENTIONS.md`
- Modify only for important recurring issues: `.claude/IMPORTANT_FIXED_BUGS.md`

**Action:**

After implementation, update project state to say:

- Zalo integration is personal-first through `zca-js` backend adapter.
- OA remains optional/fallback.
- Node service owns credentials and sessions.
- Flutter remains UI/advisory.
- Add any new files under `integration/zalo-bot-service/src/channels/` and `src/personal-login.ts`.
- Update quick commands with `npm run zalo:login-personal`.

Do not use summary files as a changelog.

**Verify:**

```bash
rg -n "personal-first|zca-js|personal_zca|zalo:login-personal|Official OA" .claude/PROJECT_SUMMARY.md claude.md CLAUDE.md
```

Expected: docs reflect the new current architecture after implementation.

---

## Dependencies

No phase files are used. This is a monolithic SPEC because the project already has a single `SPEC.md` convention and no `SPEC-phase-*.md` files.

Implementation should be done in this order:

1. Step 1 and Step 2 documentation direction.
2. Step 3 dependency/config.
3. Step 4 channel adapter boundary.
4. Step 5 personal login bootstrap.
5. Step 6 server compliance.
6. Step 7 and Step 8 Flutter settings/status.
7. Step 9 project documentation refresh.

---

## Spot-Check Results

Confirmed before writing this SPEC:

- Target project has `CLAUDE.md`, `claude.md`, `.claude/PROJECT_SUMMARY.md`, `.claude/CONVENTIONS.md`, and `SPEC.md`.
- No `SPEC-phase-*.md` files exist, so monolithic `SPEC.md` is the current convention.
- Existing `SPEC.md` was archived before rewrite.
- Current `SPEC.md` and docs were official-only and explicitly excluded personal Zalo session automation.
- `integration/zalo-bot-service/src/server.ts` exists and exports endpoints `/health`, `/api/zalo/status`, `/api/zalo/webhook`, `/api/zalo/test-send`, and `/api/zalo/send-message`.
- `integration/zalo-bot-service/src/zalo.ts` exists and is currently an OA placeholder around `ZALO_OA_ACCESS_TOKEN`.
- `integration/zalo-bot-service/src/compliance.ts` exists and currently blocks personal-account automation unless test mode.
- `integration/zalo-bot-service/src/config.ts` exists and currently has only OA/webhook/test/batch config, no personal `zca-js` config.
- `lib/mock/mock_accounts.dart` exists and defaults `officialApiOnly=true` and `allowPersonalAccountAutomation=false`.
- `lib/features/settings/providers/settings_provider.dart` exists and forces personal/proxy/friend/group flags false when official-only is enabled.
- `lib/shared/utils/zalo_compliance_guard.dart` exists and currently blocks critical personal-account actions under official-only mode.
- `lib/features/zalo_integration/data/zalo_integration_api.dart` and `providers/zalo_integration_provider.dart` exist and currently handle health/status/test-send only.
- The local reference project `D:\Dev\2.reference_pj\Zalo-ref\zca-js` exists and contains `package.json`, `src/zalo.ts`, `src/apis/sendMessage.ts`, `src/apis/listen.ts`, and `src/context.ts`.
- From `integration/zalo-bot-service`, `file:../../../../../../2.reference_pj/Zalo-ref/zca-js` resolves to the local `zca-js` path on this machine.
- The existing four-level `zalo-bot-js` relative path did not resolve during spot-check; verify before retaining OA dependency.

---

## Builder Handoff

Use the Builder from the Alpha CRM project root:

```text
use build
```

The Builder should implement this SPEC task-by-task and verify each step with the listed commands. Do not interpret the old official-only SPEC as current direction; this SPEC supersedes it.