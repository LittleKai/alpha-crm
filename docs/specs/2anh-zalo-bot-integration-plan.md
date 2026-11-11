# 2anh-zalo-bot Selective Integration Plan (Mode B — Phase 1 & Phase 2 Gate 1 Revised)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Selectively extract and integrate 9 high-value, zero-cloud, battle-tested Zalo (`zca-js`), SQLite, rate-limiting, campaign broadcast, and anti-flood subsystems (`P5`, `P4`, `P2`, `P1` in Phase 1 + `P6`, `P7`, `P8`, `P9`, `P10` in Phase 2, all scored `>= 8.0/10` with `Reference Depth - Existing Depth >= 3.5..5.5`; `P3`, `zalo-welcome.js`, and `call-words.js` remain `deferred`) from `luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7` (`MIT`) into Alpha CRM's local `integration/zalo-bot-service` backend.

**Architecture:** We preserve Alpha CRM's multi-account `PersonalZcaChannel` (`accountPool`), SQLite `LocalChatStore` (`better-sqlite3`), `LocalChatbotRuntime` / `LocalChatbotEngine`, and `command-executor.ts` / `agent-runner.ts` architecture, and upgrade them via 4 focused TypeScript modules (`src/local-chat/vietnamese-fold.ts`, `src/channels/zalo-media-enricher.ts`, `src/channels/zalo-markdown-formatter.ts`, `src/channels/zalo-rate-limiter.ts`) plus targeted wiring in `src/zca-js.d.ts`, `src/channels/types.ts`, `src/channels/personal-zca-channel.ts`, `src/local-chat/local-chat-media-worker.ts`, `src/local-chat/local-chat-store.ts`, `src/agent/campaign-progress.ts`, `src/agent/command-executor.ts`, `src/agent/agent-runner.ts`, `src/chatbot/chatbot-engine.ts`, and `src/chatbot/chatbot-runtime.ts`. All paid cloud AI / key-pool / Hermes-specific subsystems are strictly excluded.

**Tech Stack:** TypeScript `^5.4.0` (`Node16`), Node.js `>=20`, `zca-js@^2.1.2`, `better-sqlite3@^11.7.0`, tests: `npm --prefix integration/zalo-bot-service test` (`tsc && node scripts/run-tests.mjs` over `dist/**/*.test.js`).

**Spec:** `D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/docs/specs/2anh-zalo-bot-integration-plan.md` (self-contained Mode B spec + implementation plan).

**Attribution:** `Source: https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 | License: MIT`

---

## Global Constraints

- **Zero Paid / Cloud API Keys:** Never import or port `hermes-plugin/zalo_tools/media_engines.py`, `key_pool.py`, `insight_ai.py`, `dashboard/lib/ai-keys.js`, `ai-models.js`, or any external LLM/TTS/Search API client.
- **Zero New npm Dependencies:** Use only Node.js built-ins and packages already installed in `integration/zalo-bot-service/package.json` (`zca-js`, `better-sqlite3`).
- **Alpha CRM Session Invariant (`zpw_sek` Immutability):** Never re-serialize the live cookie jar back to `credentials_<uId>.json` on listener reconnect or close (`IMPORTANT_FIXED_BUGS.md` #9).
- **Backward-Compatible HTTP / SSE / SQLite Contracts:** Existing Flutter Windows & Android clients consuming `/local/conversations`, `/local/messages/search`, `/local/messages/send`, and `/local/media/:id` must require zero breaking schema changes.
- **Attribution Header:** Every newly created TypeScript module adapted from `2anh-zalo-bot` must carry the header comment `// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)`.

## Review Focus (Incorporating Gate 1 Refinements `R1`–`R16`)

1. **UTF-16 Surrogate Pairs (Emoji) & UTF-8 Byte Budget in Zalo Styled Chunks (`P1`):** Guards **every** split point (`MAX_CHARS`, style-boundary, and byte-budget shrink) so surrogate pairs are never split across chunks.
2. **Scoped Markdown Formatting, Partial Multi-Chunk Failure Guard & SQLite Echo Alias Deduplication (`P1`):** Secondary chunk IDs are stored in `message_chunk_aliases` so self-echoes reconcile to the parent `messageId`, and partial multi-chunk failure returns `{ success: true, error: 'partial: ...' }` so delivered chunks are never resent.
3. **Inbound Sticker Enrichment with 4s Timeout & `/gr/jxl/` Deduplication (`P2`):** Live `sticker` messages resolve sticker metadata via `api.getStickersDetail` with a `4000ms` timeout, 7-day TTL cache (`500` entries), no negative cache, and internal Zalo sticker code filtering (`INTERNAL_CODE = /^\[\^[\d.]+\^\]$/`).
4. **Top-Down BMP Negative Height & Magic-Byte MIME Sniffing (`P4`):** Uses `buffer.readUInt16BE(0) === 0x424d`, `height = Math.abs(buffer.readInt32LE(22))`, sniffs magic bytes when `contentType` is empty or `application/octet-stream`, and persists `mimeType` into SQLite `attachments.mimeType`.
5. **Vietnamese Diacritic Folding (`zd_fold`) in SQLite (`P5`):** Deterministic SQLite UDF `zd_fold` (`instr(zd_fold(content), ?) > 0`), keeping `accountId`/`threadId` indexed filters first.
6. **Non-Media Denylist Guard (`hasRealMedia`), URL-Required Check, File Thumb Exclusion, URL Pathname Extension Inference, Single 31-Ext MIME Map & Friend Request Code `222`/`225` Idempotency (`P6`, `R9`, `R10`):**
   - `hasRealMedia(rawType, messageType)` stays a **denylist** (`!/(recommended|webchat|chat\.text|poll|ecard|undo|sticker|link)/i` and `!['text', 'link', 'poll', 'reminder', 'contact_card', 'system', 'location', 'sticker'].includes(messageType)`) so quoted messages with numeric `cliMsgType` retain real images while `link` (`chat.recommended`), `poll`, `ecard`, `undo`, and raw `sticker` never create bogus `{ kind: 'file', url: href }` attachments. Note: `P2` live sticker enrichment runs *after* `normalizeInboundMessage` so live stickers still receive their enriched PNG attachment.
   - `extractAttachmentFromRecord` requires a valid `http(s)://` URL (`url || thumbnailUrl`); when `isFileMessage(rawType, messageType)` (`share.file` / `file` / `doc`) is true, `record.thumb` / `record.thumbnail` are excluded.
   - `extensionOf(input)` parses `new URL(input).pathname` first when `input` is an `http(s)://` URL before matching `/\.([A-Za-z0-9]{1,5})$/` (so `https://zalo.me` returns `''` instead of `'.me'`), and `extensionMimeType` delegates to the single 31-extension `MIME_BY_EXT` table in `zalo-media-enricher.ts` (falling back to `'application/octet-stream'` for `kind === 'file'` and `'image/jpeg'` for `kind === 'image'`).
   - In `PersonalZcaChannel.sendFriendRequest`, `selectedInstance` is hoisted outside `try` so `catch (err)` can check `isAlreadyFriendErrorCode(err)` (`222`, `225`), invalidate `friendsCache.delete(selectedInstance.uId)`, and return `{ success: true }`.
7. **Monotonic-Clock Per-Account Priority Token-Bucket Outbound Rate Limiter & `RATE_LIMITED` Campaign Retry (`P7`, `R5`, `R6`, `R11`, `R12`):**
   - `ZaloRateLimiter` (`capacity = 5`, `refillMs = 3000`, `maxWaitMs = 20000`, two-lane priority queue `'high' | 'normal'`) uses fractional refill (`tokens = Math.min(capacity, tokens + (now() - lastRefill) / refillMs)`), defaults `now` to `() => performance.now()` so `runWithFixedDateNow` (`Date.now` pinning in `personal-zca-channel.ts:1056`) never freezes token refills, and enforces **both** an up-front estimate check (`projectedWait > maxWaitMs`) and a per-waiter deadline timer (`maxWaitMs`).
   - `acquire()` is called **outside** `runWithFixedDateNow` once per logical chunk (retries on the same chunk reuse the token; `RateLimitedError` on chunk `k > 0` returns `partial:` success so delivered chunks are never re-sent; with `maxWaitMs = 20_000`, a single message under an empty bucket has a ~11-chunk ceiling before hitting `maxWaitMs`).
   - When `acquire()` rejects with `RateLimitedError` on chunk 0 (or single send), `sendMessage` returns `{ success: false, error: err.message, errorCode: 'RATE_LIMITED', retryAfterMs: err.waitMs }`, and `runCampaignInBackground` (`command-executor.ts`) waits `retryAfterMs` and retries the **same** recipient once without incrementing `failStreak`!
8. **Crash-Safe Campaign Checkpointing, Windows Retry Atomic Writes, `5-min` Send Timeout (`status: 'unknown'`) & `MAX_FAIL_STREAK = 5` Circuit Breaker (`P8`, `R7`, `R13`):**
   - `campaign-progress.ts` ports `writeFileAtomic` from `dashboard/lib/json-store.js:16-45` (writing `.tmp`, retrying `renameSync` up to 3 times 50ms apart on Windows `EPERM`/`EBUSY`/`EACCES`, cleaning up `.tmp` on failure, and returning `boolean`), and saves a diagnostic copy `in-flight.json.corrupt-<ts>` when `readAll` encounters corrupt JSON.
   - `runCampaignInBackground` (`command-executor.ts`) checkpoints `inFlightRecipient` **before** `sendMessage` (skipping the send if the checkpoint write returns `false`), wraps `sendMessage` in a `CAMPAIGN_SEND_TIMEOUT_MS = 5 * 60_000` race with a `dead` flag, records `status: 'unknown'` (never `'failed'`, while still incrementing `failStreak`) on timeout so the agent never re-sends a timed-out recipient (cloud mapping tracked in `.claude/PROJECT_SUMMARY.md §6`), and aborts remaining recipients (`status: 'cancelled'`, `abortedReason: 'aborted_fail_streak'`, calling `updateCampaign` and `reportCommandProgress` before `break`) when `failStreak >= CAMPAIGN_MAX_FAIL_STREAK` (`5`).
   - `reportInterruptedCampaigns` (`src/agent/agent-runner.ts`) and `finalResult` (`command-executor.ts`) include `inFlightRecipient` and `abortedReason`.
9. **Pre-Debouncer Per-Sender Sliding-Window Anti-Flood Guard (`P9`, `R3`, `R4`):**
   - `FloodGuard` (`threshold = 6`, `windowSeconds = 15`, `muteSeconds = 90`, states `'ok' | 'just_muted' | 'muted'`, auto-pruning at `>= 256` keys) matches upstream `flood.py` (`hits.length > threshold` = 7th message within 15s returns `'just_muted'`, subsequent messages during 90s mute return `'muted'`) and is wired inside `LocalChatbotRuntime.handlePersistedInbound` **before** `this.debouncer.push(conversationKey, ...)` so raw inbound message floods are counted per message (not post-debounce).
   - Upstream `call_words.py` / `dashboard/lib/call-words.js` is deferred (`R4`) because upstream scopes call words strictly to the bot owner (`is_owner`) and Alpha CRM has no cloud/Flutter `ChatbotSettings` producer for `callWords`.
10. **Group `@Tên` & `@All` Post-Markdown Mention Offset Resolver (`P10`, `R8`):**
    - `findMentions(msg, members, { selfUid, continuesInNextChunk, canMentionAll })` ports `zalo-mentions.js:1-109` verbatim: `NAME_CHAR = /[\p{L}\p{N}_]/u` boundary checks, `NAME_CONTINUES = /^ \p{Lu}/u` prefix protection, ambiguous-name exclusion (`uids.size !== 1` across NFC-normalized `displayName` and `zaloName`), `@All` (`/all(?![\p{L}\p{N}_])/iu`, `len = 4`, `uid: '-1'`) when `canMentionAll` (`members.length <= 100 || isAdminOrOwner` for the **sending** `selectedInstance.uId`), and `continuesInNextChunk` skipping matches where `after.trim() === ''`.
    - Group member lookup in `personal-zca-channel.ts` is cached per `${selectedInstance.uId}:${groupId}` for 10 minutes (`10 * 60_000ms`), uses `info.currentMems` from `getGroupInfo` with a `4000ms` timeout, and falls back tostale cache or `[]` so member lookup never fails a message send.

---

## 1. Candidate Evaluation & Scoring (`/10` — Step 3B & Gate 1 Revised)

### 1.1 Candidate Metadata
- **Repository:** `https://github.com/luonghaianh1208/2anh-zalo-bot` (local mirror inspected via isolated shallow clone at `C:\Users\XEON\AppData\Local\Temp\eval_20261110_1831_2anh_zalo_bot_p2\2anh-zalo-bot`)
- **Pinned Commit SHA:** `9ab55105c83487588e66b55f0ef66894224250a7` (`2026-11-03`, `v2.66.1`)
- **License:** `MIT` (`Copyright (c) 2026 2Anh AI Education`)
- **Age Penalty:** `last_active_year = 2026` (shallow clone `is-shallow-repository=true`) $\implies \Delta = 0 \implies \text{Age Penalty} = 0.0$.
- **AST Scan Summary (`ast_scan.json`):** `files_matched = 400`, `nodes = 4840`, `edges = 12049`, `ast_summary = partial_ast_capped`.

### 1.2 Whole-Repo Score vs Proposal Scores (Phase 1: `P5 > P4 > P2 > P1`; Phase 2: `P6 > P7 > P8 > P9 > P10`; `P3` Deferred)

| Target / Proposal | Classification | Existing Depth (`0..10`) | Reference Depth (`0..10`) | C1 Relevance (`0..3`) | C2 Quality (`0..2`) | C3 Effort (`0..2`) | C4 Security (`0..2`) | C5 License (`0..1`) | Age Penalty | Total (`/10`) | Decision |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Whole Repo (`2anh-zalo-bot`)** | `SKIP_SELF` (Wholesale) | `7.5` | `8.0` | `2.0` | `1.5` | `0.0` | `1.0` | `1.0` | `0.0` | **5.5/10** | **Do NOT wholesale install**; extract pure modules (`Mode 1`) |
| **P5: Vietnamese Diacritic-Insensitive & Case-Insensitive SQLite Search (`zd_fold`)** | `UPGRADE` (`Mode 1`) | `4.0` | `9.0` | `2.4` | `2.0` | `1.5` | `1.9` | `1.0` | `0.0` | **8.8/10** | **ADOPT (`Task 1` — Done)** |
| **P4: BMP (`0x424d`) Header Parser + Magic-Byte MIME Sniffing** | `UPGRADE` (`Mode 1`) | `6.0` | `7.0` | `2.5` | `2.0` | `1.5` | `2.0` | `1.0` | `0.0` | **9.0/10** | **ADOPT (`Task 2` — Done)** |
| **P2: Inbound Sticker Enrichment (`getStickersDetail` 7-day TTL FIFO cache) & `/gr/jxl/` Filtering** | `UPGRADE` (`Mode 1`) | `4.5` | `9.0` | `2.5` | `1.9` | `1.5` | `2.0` | `1.0` | `0.0` | **8.9/10** | **ADOPT (`Task 3` — Done)** |
| **P1: Outbound Zalo Markdown + LaTeX Formatter, Surrogate-Safe Budget Chunker & Echo Alias Dedup** | `UPGRADE` (`Mode 1`) | `3.0` | `9.0` | `2.8` | `2.0` | `1.5` | `2.0` | `1.0` | `0.0` | **9.3/10** | **ADOPT (`Task 4` — Done)** |
| **P6: Attachment Extraction Hardening (`hasRealMedia` Denylist, URL-Required, File Thumb Exclusion, URL Pathname Extension Inference, Single 31-Ext MIME Map) & Friend Code `222`/`225` Idempotency** | `UPGRADE` (`Mode 1`) | `4.5` | `9.0` (`zalo-attachments.js:1-124` + `zalo-friends.js:40`) | `2.6` | `2.0` | `1.5` | `2.0` (pre-4.0: `1.5`) | `1.0` | `0.0` | **9.1/10** (pre-4.0: `8.6`) | **ADOPT (`Task 5`)** |
| **P7: Monotonic-Clock Per-Account Priority Token-Bucket Outbound Rate Limiter (`high` vs `normal` queue, burst `5`, refill `3s`, `maxWaitMs = 20s` fail-fast + deadline `RateLimitedError`)** | `UPGRADE` (`Mode 1`) | `3.5` (`src/compliance.ts` has zero runtime pacing) | `9.0` (`rate-limiter.js:1-147`) | `2.6` | `2.0` | `1.4` | `2.0` (pre-4.0: `1.5`) | `1.0` | `0.0` | **9.0/10** (pre-4.0: `8.5`) | **ADOPT (`Task 6`)** |
| **P8: Crash-Safe Campaign Checkpointing (Pre-Send `inFlightRecipient`, Windows 3-Retry Atomic Writes, Corrupt JSON Snapshot, `5-min` Send Timeout `status: 'unknown'` & `MAX_FAIL_STREAK = 5` Breaker)** | `UPGRADE` (`Mode 1`) | `5.0` | `9.0` (`zalo-broadcast.js:24-281` + `dashboard/lib/json-store.js:1-45`) | `2.5` | `2.0` | `1.4` | `2.0` (pre-4.0: `1.5`) | `1.0` | `0.0` | **8.9/10** (pre-4.0: `8.4`) | **ADOPT (`Task 7`)** |
| **P9: Pre-Debouncer Per-Sender Sliding-Window Anti-Flood Guard (`> 6 msgs / 15s -> 90s mute`, `'ok' \| 'just_muted' \| 'muted'`)** | `NEW` / `UPGRADE` (`Mode 1`) | `3.5` | `8.5` (`hermes-plugin/zalo/flood.py:1-95`) | `2.4` | `1.9` | `1.4` | `2.0` (pre-4.0: `1.5`) | `1.0` | `0.0` | **8.7/10** (pre-4.0: `8.2`) | **ADOPT (`Task 8`)** |
| **P10: Group `@Tên` & `@All` Post-Markdown Mention Offset Resolver (`findMentions` with Ambiguous-Name Exclusion & `NAME_CONTINUES`)** | `UPGRADE` (`Mode 1`) | `4.5` | `8.5` (`zalo-mentions.js:1-109`) | `2.3` | `1.9` | `1.3` | `2.0` (pre-4.0: `1.5`) | `1.0` | `0.0` | **8.5/10** (pre-4.0: `8.0`) | **ADOPT (`Task 9`)** |
| **P3: First-Connect Duplicate Code `3000` Flap Guard (`flapWindowMs = 10s`)** | `DEFERRED` (`Mode 4`) | `6.5` | `8.5` (`bot-handler.js:55-202`) | `1.5` | `1.8` | `1.0` | `1.5` | `1.0` | `0.0` | **5.8/10** | **DEFER (`P3`)** |

---

## 2. Seven-Direction Deep Analysis & 4-Layer Vertical Slice

### 2.1 Seven-Direction Analysis
1. **Algorithms & Formulas:**
   - `zalo-math.js` + `markdown-formatter.js` (`P1`): LaTeX-to-Unicode + Markdown parser + UTF-16 surrogate-safe budget chunker (`MAX_CHARS = 2000`, `MAX_STYLES = 40`, `MAX_PAYLOAD_BYTES = 3000`).
   - `fold.js` (`P5`): NFD normalization + stripping `\u0300-\u036f` + mapping `đ/Đ -> d` (`foldVietnamese`).
   - `rate-limiter.js` (`P7`): Fractional token bucket (`tokens = Math.min(capacity, tokens + (now() - lastRefill) / refillMs)`, `lastRefill = now()`) using `performance.now()`, two FIFO queues (`highQueue` drained before `normalQueue`), up-front `projectedWait > maxWaitMs` check plus per-waiter deadline timer (`maxWaitMs = 20_000`) rejecting with `RateLimitedError`.
   - `flood.py` (`P9`): Per-sender sliding window (`threshold = 6` within `windowSeconds = 15`; when `hits.length > threshold` — i.e., 7th message within 15s — sets `mutedUntil = now + muteSeconds * 1000` (`90s`) and returns `'just_muted'`, returning `'muted'` while `now < mutedUntil`, and pruning expired entries when maps reach `256` keys).
   - `zalo-mentions.js` (`P10`): Builds a case-folded (`toLocaleLowerCase('vi')`) NFC name map from group members, skips ambiguous names (`uids.size !== 1`) and `selfUid`, sorts unique names longest-first, scans `@` positions where the preceding character does not match `NAME_CHAR = /[\p{L}\p{N}_]/u`, matches `@All` via `/^all(?![\p{L}\p{N}_])/iu` (`len = 4`, `uid: '-1'`) when `canMentionAll` is true, checks `NAME_CHAR` and `NAME_CONTINUES = /^ \p{Lu}/u` after each matched name, and skips matches where `continuesInNextChunk && after.trim() === ''`.
2. **Architecture & State Machine:**
   - `zalo-broadcast.js` + `dashboard/lib/json-store.js` (`P8`): Checkpoints `inFlightRecipient = { index, recipientId, startedAt }` to `in-flight.json` via Windows-safe 3-retry `writeFileAtomic` **before** `sendMessage` (skipping the send if the checkpoint write fails), wraps `sendMessage` in a `CAMPAIGN_SEND_TIMEOUT_MS = 300_000` race (recording `status: 'unknown'` on timeout), retries once on `errorCode === 'RATE_LIMITED'` without incrementing `failStreak`, and trips a circuit breaker after `CAMPAIGN_MAX_FAIL_STREAK = 5` consecutive non-rate-limit failures.
3. **Data Structures & Schemas:**
   - `zalo-stickers.js` (`P2`) + `zalo-attachments.js` (`P6`): 7-day FIFO sticker cache (`maxEntries = 500`, `timeoutMs = 4000`), `hasRealMedia(rawType, messageType)` denylist filter, 31-extension `MIME_BY_EXT` map, and `ALREADY_FRIEND_CODES = new Set([222, 225])`.
4. **Edge Cases & Production Hardening:**
   - Surrogate pair boundary check (`P1`), internal Zalo sticker code filter (`P2`), top-down negative BMP height `Math.abs` (`P4`), URL-required attachment validation, URL pathname extension parsing & `share.file` blurry thumbnail suppression (`P6`), monotonic clock immunity to `runWithFixedDateNow` (`P7`), Windows `EPERM/EBUSY/EACCES` atomic rename retry & `.corrupt-<ts>` diagnostic snapshot (`P8`), pre-debounce flood counting (`P9`), and ambiguous-name / `NAME_CONTINUES` / trailing chunk `@Tên` suppression (`P10`).
5. **Performance & Caching:**
   - Deterministic SQLite UDF `zd_fold` (`P5`), per-account `ZaloRateLimiter` instances (`P7`), `${uId}:${groupId}` 10-minute group member cache with `4000ms` timeout (`P10`), and bounded 256-entry auto-pruning in `FloodGuard` (`P9`).
6. **Testing & Determinism:**
   - Deterministic unit and wiring tests across `local-chat-store.test.ts`, `image-metadata-and-sniff.test.ts`, `zalo-media-enricher.test.ts`, `zalo-markdown-formatter.test.ts`, `zalo-rate-limiter.test.ts`, `campaign-progress.test.ts`, `command-executor.test.ts`, and `chatbot-runtime.test.ts`.
7. **Security, SSRF & Privacy / Assets & Presets:**
   - Target `src/local-chat/external-media.ts` already pins DNS and blocks private/loopback/link-local IPs (`SKIP_SELF`).
   - Magic-byte sniffing (`P4`) + `hasRealMedia` (`P6`) prevent non-media URLs (`chat.recommended` web links) from being downloaded into the media cache.

### 2.2 Four-Layer Vertical Slice Mapping (`Schema ↔ State/Control ↔ Core Logic ↔ Output/IO`)

| Layer | Role | Target Files in Alpha CRM | Candidate Source (`2anh-zalo-bot`) |
|---|---|---|---|
| **Schema** | Ambient `zca-js` API declarations (`getStickersDetail`), `ZaloSendMessageResult` (`chunkMessageIds`, `chunkClientMessageIds`, `errorCode`, `retryAfterMs`), `ResolvedZaloMention`, `CampaignProgressRecord` (`inFlightRecipient`, `abortedReason`, `unknownCount`) | `src/zca-js.d.ts`, `src/channels/types.ts`, `src/agent/campaign-progress.ts`, `src/channels/zalo-markdown-formatter.ts` | `markdown-formatter.js`, `zalo-stickers.js`, `zalo-broadcast.js`, `zalo-mentions.js`, `rate-limiter.js` |
| **State / Control** | Bounded FIFO sticker cache (`P2`), monotonic-clock per-account `ZaloRateLimiter` (`high` vs `normal` priority queues, `P7`), pre-send `inFlightRecipient` checkpoint + `CAMPAIGN_SEND_TIMEOUT_MS` + `CAMPAIGN_MAX_FAIL_STREAK = 5` breaker (`P8`), pre-debounce `FloodGuard` (`P9`), `${uId}:${groupId}` 10-min group member cache (`P10`) | `src/channels/zalo-media-enricher.ts`, `src/channels/zalo-rate-limiter.ts`, `src/channels/personal-zca-channel.ts`, `src/agent/campaign-progress.ts`, `src/agent/command-executor.ts`, `src/chatbot/chatbot-runtime.ts` | `zalo-stickers.js`, `rate-limiter.js`, `zalo-broadcast.js`, `hermes-plugin/zalo/flood.py`, `zalo-mentions.js` |
| **Core Logic** | Markdown + LaTeX formatter & surrogate-safe chunker (`P1`), `findMentions` (`P10`), `hasRealMedia` + `isFileMessage` + `extensionOf` + 31-ext `MIME_BY_EXT` + `isAlreadyFriendErrorCode` (`P6`), BMP parser & magic-byte MIME sniffer (`P4`), `foldVietnamese` (`P5`), `FloodGuard` (`P9`) | `src/channels/zalo-markdown-formatter.ts`, `src/channels/zalo-media-enricher.ts`, `src/channels/personal-zca-channel.ts`, `src/local-chat/local-chat-media-worker.ts`, `src/local-chat/vietnamese-fold.ts`, `src/chatbot/chatbot-engine.ts` | `markdown-formatter.js`, `zalo-math.js`, `zalo-mentions.js`, `zalo-attachments.js`, `zalo-friends.js`, `image-metadata.js`, `dashboard/lib/image-proxy.js`, `dashboard/public/fold.js`, `hermes-plugin/zalo/flood.py` |
| **Output / IO** | SQLite `zd_fold` search & `message_chunk_aliases` echo dedup (`P5`, `P1`), Windows 3-retry atomic `.tmp` + `renameSync` & `.corrupt-<ts>` snapshot in `campaign-progress.ts` + interrupted/final cloud reporting in `agent-runner.ts` & `command-executor.ts` (`P8`), rate-limited multi-chunk group/user dispatch & code `222`/`225` friend-request handling in `personal-zca-channel.ts` (`P6`, `P7`, `P10`) | `src/local-chat/local-chat-store.ts`, `src/local-chat/local-chat-media-worker.ts`, `src/channels/personal-zca-channel.ts`, `src/agent/campaign-progress.ts`, `src/agent/command-executor.ts`, `src/agent/agent-runner.ts` | `dashboard/lib/store-reader.js:158`, `dashboard/lib/json-store.js`, `zalo-broadcast.js`, `rate-limiter.js`, `zalo-friends.js`, `zalo-mentions.js` |

---

## 3. Full-Surface Subsystem Matrix (`2anh-zalo-bot` — All Top-Level, Dashboard, Plugin & Script Modules)

| Subsystem in `2anh-zalo-bot` | Candidate Paths | Existing Depth (`0..10`) | Reference Depth (`0..10`) | Disposition (`adopted` / `deferred` / `excluded`) | Score (`/10`) | Rationale / Trigger Condition |
|---|---|---|---|---|---|---|
| **Vietnamese Diacritic-Insensitive Folding (`zd_fold`)** | `dashboard/public/fold.js`, `dashboard/lib/store-reader.js:158` | `4.0` | `9.0` | **`adopted` (`P5`)** | `8.8` | Enables accent-insensitive & case-insensitive Vietnamese search in `LocalChatStore`. |
| **BMP Image Metadata Parser & Magic-Byte MIME Sniffer** | `image-metadata.js`, `dashboard/lib/image-proxy.js:55-66,124-141`, `dashboard/public/media.js` | `6.0` | `7.0` | **`adopted` (`P4`)** | `9.0` | Fixes outbound BMP `imageMetadataGetter` crashes (fixing upstream LE bug) and `application/octet-stream` CDN image caching. |
| **Inbound Sticker Detail Enricher & `/gr/jxl/` Deduplicator** | `zalo-stickers.js`, `zalo-attachments.js` | `4.5` | `9.0` | **`adopted` (`P2`)** | `8.9` | Resolves sticker PNG + meaning via `getStickersDetail` (7-day FIFO cache, 4s timeout) and strips unreadable `/gr/jxl/` duplicates. |
| **Zalo Markdown + LaTeX Formatter & Budget Chunker + Safe Numeric Error Fallback** | `markdown-formatter.js`, `zalo-math.js`, `hermes-bridge.js:1002-1048` | `3.0` | `9.0` | **`adopted` (`P1`)** | `9.3` | Eliminates raw `**`/`#`/LaTeX clutter on chatbot outbound messages, guards surrogate splits, and retries plain text on non-600 numeric Zalo errors. |
| **Attachment Extraction Guard (`hasRealMedia` Denylist, URL-Required, File Thumb Filter, 31-Ext MIME Map) & Friend Code `222`/`225` Idempotency** | `zalo-attachments.js`, `zalo-friends.js:40` | `4.5` | `9.0` | **`adopted` (`P6`)** | `9.1` | Prevents bogus file downloads on `link`/`poll`/`ecard` messages, drops blurry duplicate `share.file` thumbnails, infers extensions from URL pathnames, and treats friend-request codes `222`/`225` as success. |
| **Priority Token-Bucket Outbound Rate Limiter (`high` vs `normal`)** | `rate-limiter.js` | `3.5` | `9.0` | **`adopted` (`P7`)** | `9.0` | Monotonic-clock per-account token bucket (`burst = 5`, `refill = 3s`, `maxWait = 20s`) with `'high'` priority for Live Chat/Chatbot vs `'normal'` for bulk campaigns and friend/group ops. |
| **Crash-Safe Broadcast Checkpointing, Windows 3-Retry Atomic Writes, `5-min` Send Timeout (`status: 'unknown'`) & `MAX_FAIL_STREAK = 5` Breaker** | `zalo-broadcast.js`, `dashboard/lib/json-store.js` | `5.0` | `9.0` | **`adopted` (`P8`)** | `8.9` | Windows-safe atomic `.tmp` + `renameSync` writes, `.corrupt-<ts>` snapshot, pre-send `inFlightRecipient` checkpoint, `5-min` send timeout (`unknown`), and `MAX_FAIL_STREAK = 5` circuit breaker in `campaign-progress.ts`, `command-executor.ts`, and `agent-runner.ts`. |
| **Sender Sliding-Window Flood Guard (`> 6 msgs / 15s -> 90s mute`, `'ok' / 'just_muted' / 'muted'`)** | `hermes-plugin/zalo/flood.py` | `3.5` | `8.5` | **`adopted` (`P9`)** | `8.7` | Protects `LocalChatbotRuntime` (`handlePersistedInbound` before `debouncer.push`) from rapid-fire sender spam (`> 6 msgs / 15s -> 90s mute`) before AI calls. |
| **Group `@Tên` & `@All` Post-Markdown Mention Offset Resolver** | `zalo-mentions.js` | `4.5` | `8.5` | **`adopted` (`P10`)** | `8.5` | Resolves `@Tên` (skipping ambiguous names and `NAME_CONTINUES`) and `@All` (`uid: '-1'`) into accurate UTF-16 `pos`/`len` offsets on each formatted chunk after Markdown stripping. |
| **Batched Group Member Join Welcome (`GROUP_JOIN_LEAVE`)** | `zalo-welcome.js` | `3.0` | `8.5` | **`deferred`** | `7.3` | Clean 4s batching + `@Tên` mention builder for new group members; deferred until Alpha CRM adds a Group Welcome toggle & template in Flutter Group Management UI (`lib/`). |
| **Owner Group Call-Words Trigger (`call_words.py` / `call-words.js`)** | `hermes-plugin/zalo/call_words.py`, `dashboard/lib/call-words.js` | `4.0` | `8.0` | **`deferred`** | `7.0` | Upstream feature is strictly owner-only (`is_owner`) and Alpha CRM has no `ownerId` or cloud/Flutter `ChatbotSettings` producer for `callWords`; deferred until Flutter `chatbot_screen.dart` adds a Group Call-Words setting (`vi`/`en`). |
| **First-Connect Code `3000` Flap Guard & Reconnect Scheduler** | `bot-handler.js:55-202` | `6.5` (`IMPORTANT_FIXED_BUGS.md` 2026-06-17) | `8.5` | **`deferred` (`P3`)** | `5.8` | Alpha CRM deliberately treats `3000`/`3003` as `disconnected_expired` to prevent self-duplicate loops; deferred unless an Alpha CRM production log captures a first-connect `3000` flap within 10s. |
| **Group Name Cache & Friend/Reminder Directory (`group-directory.js`, `zalo-directory.js`) & Bulk Friend-Then-Group Orchestrator (`zalo-friends.js` bulk loop)** | `group-directory.js`, `zalo-directory.js`, `zalo-friends.js` (bulk loop) | `7.5` (`personal-zca-channel.ts` `groupsCache`/`friendsCache` + cloud CRM campaigns) | `7.5` | **`excluded`** | `6.4` | Alpha CRM already caches group/friend lists per account in `personal-zca-channel.ts` (`groupsCache`, `friendsCache`) and orchestrates bulk campaigns via `command-executor.ts` (`SKIP_SELF`; codes `222`/`225` from `zalo-friends.js:40` are adopted in `P6`). |
| **Contact Policy & DM Rules** | `zalo-policy.js`, `dm-rules.js` | `7.5` (`chatbot-engine.ts`) | `7.5` | **`excluded`** | `6.2` | Alpha CRM already manages per-account/per-thread chatbot audience and handoff policies in `LocalChatStore` + `LocalChatbotEngine` (`SKIP_SELF`). |
| **Cron / Interval Schedules & Runtime Health Monitor** | `dashboard/lib/schedules.js`, `runtime-health.js` | `7.5` (`src/listener-health.ts` + CRM campaigns) | `7.5` | **`excluded`** | `6.0` | Alpha CRM already has `ListenerHealthMonitor` (`src/listener-health.ts`) and cloud/local campaign scheduling (`SKIP_SELF`). |
| **Smart Contextual Reaction Picker & Owner Mention DM Notifier** | `smart-reaction.js`, `owner-mention.js` | `6.0` | `7.0` | **`excluded`** | `6.2` | Persona-specific to 2Anh bot; Alpha CRM operators control reactions manually or via explicit CRM automation rules. |
| **Single-Account SQLite Store, People/KB/Memory Stores, Thread Names & File Log** | `zalo-store.js`, `dashboard/lib/people-store.js`, `dashboard/lib/kb-store.js`, `dashboard/lib/learned-memory.js`, `dashboard/lib/thread-names.js`, `file-log.js` | `8.0` (`src/local-chat/local-chat-store.ts` + `chatbot-store.ts`) | `7.5` | **`excluded`** | `5.8` | Alpha CRM already has a richer multi-account `LocalChatStore` (`conversations`, `messages`, `attachments`, `sync_queue`, `chatbot-store.ts`) (`SKIP_SELF`). |
| **Single-Account QR Login, Control API, Dashboard Link & Preact Web Dashboard** | `server.js`, `qr-login.js`, `control-api.js`, `auth.js`, `dashboard-link.js`, `dashboard/*` (excluding adopted `fold.js`, `image-proxy.js`, `media.js`, `json-store.js`, `store-reader.js`) | `7.5` | `8.0` | **`excluded`** | `5.5` | Alpha CRM already has multi-account `PersonalZcaChannel` + native Flutter Windows/Android desktop/mobile UI (`SKIP_SELF`). |
| **Hermes WebSocket Bridge, Python Adapter, Live Settings, Model Command, Bot Uses & Soul Presets** | `hermes-bridge.js` (WS server), `legacy-history-import.js`, `hermes-plugin/zalo/adapter.py`, `hermes-plugin/zalo/bot_uses.py`, `hermes-plugin/zalo/live_settings.py`, `hermes-plugin/zalo/model_command.py`, `hermes-plugin/zalo_memory/*`, `dashboard/lib/soul-presets.json` | `7.0` | `7.5` | **`excluded`** | `4.5` | Tightly coupled to Hermes Agent runtime (`HERMES_HOME`) and 2Anh persona; Alpha CRM uses `LocalChatStore` + `LocalChatbotEngine`. |
| **Hermes Non-Cloud Tool Helpers (`group_safety.py`, `people.py`, `freshness.py`, `folder_rules.py`)** | `hermes-plugin/zalo_tools/group_safety.py`, `hermes-plugin/zalo_tools/people.py`, `hermes-plugin/zalo_tools/freshness.py`, `hermes-plugin/zalo_tools/folder_rules.py` | `6.0` | `7.0` | **`excluded`** | `5.5` | Coupled to Hermes Python tool registry and owner alert DM flow with no CRM UI owner (`SKIP_SELF`). |
| **Cloud Media Engines, API Key Pool, TTS, Studio Sandbox, Self-Update, Hermes Installers & FB Token Scripts** | `hermes-plugin/zalo_tools/media_engines.py`, `hermes-plugin/zalo_tools/key_pool.py`, `hermes-plugin/zalo_tools/insight_ai.py`, `hermes-plugin/zalo_tools/studio.py`, `hermes-plugin/zalo_tools/studio_sandbox.py`, `dashboard/lib/ai-keys.js`, `dashboard/lib/ai-models.js`, `tts/*`, `scripts/self-update.js`, `scripts/install-hermes.js`, `scripts/hermes-update.js`, `scripts/uninstall-hermes.js`, `scripts/hermes-install-lib.js`, `scripts/dashboard-service.js`, `scripts/doctor.js`, `scripts/setup-env.js`, `scripts/run-python-tests.js`, `scripts/lay-token-facebook.py` | `N/A` | `6.0` | **`excluded`** | `2.0` | Violates Invariant 2 (requires paid Gemini/OpenAI/ElevenLabs/Edge-TTS API keys, external scrapers, or mutates host git/systemd/processes). |

### 3.1 Recommended Roadmap for Remaining Deferred Subsystems (`>= 7.0`)
- **`zalo-welcome.js` (`7.3/10`):** Wire 4-second batched `GROUP_JOIN_LEAVE` welcome messages with `@Tên` mention offsets once the Flutter Group Management screen exposes a per-group welcome toggle and template (`vi`/`en`).
- **`dashboard/lib/call-words.js` + `hermes-plugin/zalo/call_words.py` (`7.0/10`):** Wire group call-word triggers once `ChatbotSettings` in Cloud & Flutter `chatbot_screen.dart` adds a Group Call-Words configuration field with `vi`/`en` localization.

---

## 4. Security Gate (`skill-inspector` Step 4.0) & Boundary Contracts (Step 4.1–4.2)

### 4.1 Step 4.0 Security Gate Evidence Contract
- **Orca Run ID:** `run_b0f8995349ee`
- **Durable Audit Evidence Manifest:** `C:\Users\XEON\AppData\Local\alpha-crm-eval-evidence\20261110_2anh-zalo-bot\manifest.json` (`schema_version: 1`).
- **Source Identity:** `source_type = github_repo`, `origin_url = https://github.com/luonghaianh1208/2anh-zalo-bot`, `commit_sha = 9ab55105c83487588e66b55f0ef66894224250a7`
- **Wholesale Install Verdict:** `UNSAFE` (`skill_gate_full_report.json`: score `100/100 CRITICAL`, 211 issues across 498 files — self-updater, external cloud API keys, Python studio subprocess execution).
- **Extraction Verdict (17-File Phase 1 + Phase 2 Combined Bundle):** `EXTRACTION_SAFE_AFTER_PRUNE` (`skillspector_bundle_p2.json`: score `55/100 HIGH` on the 17-file bundle, `3` issues total, `0 MAL`):
  1. Rule `PE3` (`hermes-bridge.js:16`, `.env `, `match_fingerprint = 66ef81c27c03406fd9935e5fc86fc4126d7150c15b8d076fdc528d05cea7c7bf`): **`FP`** — Static Vietnamese notice string (`FRIEND_TOOLS_OFF`) in `source_evidence_set`, not ported.
  2. Rule `MP3` (`zalo-broadcast.js:174`, `delete state`, `match_fingerprint = fcedd71f239b20cbe2035a054be9ccc65c57785d1df89a405fb205537c0337aa`): **`FP`** — Standard JS object property deletion (`delete state.sentByDay[key]`) pruning broadcast daily counters older than `KEEP_DAYS = 7` days; matched heuristic substring `"delete state"`. Not ported to `campaign-progress.ts`.
  3. Rule `AE4` (`zalo-math.js:1`, mixed-script Unicode, `match_fingerprint = null`): **`FP`** — Static mathematical Unicode subscript/superscript/Greek character maps (`SUB`, `SUP`, `GREEK`, `SYMBOLS`) for LaTeX-to-Unicode conversion; zero obfuscation or dynamic execution.
  - **Manual 100% Line-by-Line Inspection of all `partially_inspected_files` (`static_parse_limit`):** `dashboard/lib/image-proxy.js` (172 lines), `dashboard/lib/store-reader.js` (500 lines), `dashboard/public/media.js` (111 lines), `dashboard/lib/json-store.js` (45 lines), `hermes-bridge.js` (1332 lines), `zalo-attachments.js` (124 lines), `zalo-broadcast.js` (405 lines), `zalo-friends.js` (399 lines), and `zalo-math.js` (127 lines) were read in full (`100%` line coverage) by the Host Session; zero hidden network calls, shell executions, or credential exfiltration exist in any extracted logic.
- **Import-Closure Verification (`eval_workspace.py check-closure`):**
  - On the isolated 17-file extraction bundle (`--cand-dir "$evalRoot\source_bundles\2anh-zalo-bot"`): `{"ok": true, "status": "ok", "missing_imports": [], "uncovered_cited_files": [], "unknown_extraction_paths": [], "manual_closure_required_files": [], "modules_capped": false}` (persisted to `check_closure_p2.json`).
  - Note on full-repo `check-closure` (`--cand-dir "$evalRoot\2anh-zalo-bot"`): returns `status: "fail", modules_capped: true, missing_imports: []` because the full repository has `417 > 400` JS/TS/Py files (including 156 test files), which triggers `eval_workspace.py`'s 400-file cap (`R1`). Manual closure inspection of all 16 extracted/evidence files confirms `missing_imports = []` (only `dashboard/lib/image-proxy.js -> ../public/media.js` and `zalo-broadcast.js / zalo-friends.js -> ./rate-limiter.js`, all included in `extraction_set`).
- **Explicit File Sets:**
  - `extraction_set`: `["markdown-formatter.js", "zalo-math.js", "zalo-stickers.js", "zalo-attachments.js", "image-metadata.js", "dashboard/public/fold.js", "dashboard/lib/image-proxy.js", "dashboard/public/media.js", "rate-limiter.js", "zalo-broadcast.js", "dashboard/lib/json-store.js", "zalo-mentions.js", "hermes-plugin/zalo/flood.py"]`
  - `source_evidence_set`: `["hermes-bridge.js", "dashboard/lib/store-reader.js", "zalo-friends.js"]`
  - `features_excluded`: `["bot-handler.js", "zalo-welcome.js", "group-directory.js", "zalo-directory.js", "zalo-policy.js", "dm-rules.js", "smart-reaction.js", "owner-mention.js", "zalo-store.js", "file-log.js", "runtime-health.js", "server.js", "qr-login.js", "control-api.js", "auth.js", "dashboard-link.js", "legacy-history-import.js", "dashboard/lib/call-words.js", "dashboard/lib/schedules.js", "dashboard/lib/people-store.js", "dashboard/lib/kb-store.js", "dashboard/lib/learned-memory.js", "dashboard/lib/thread-names.js", "dashboard/lib/ai-keys.js", "dashboard/lib/ai-models.js", "dashboard/lib/soul-presets.json", "hermes-plugin/zalo/call_words.py", "hermes-plugin/zalo/adapter.py", "hermes-plugin/zalo/bot_uses.py", "hermes-plugin/zalo/live_settings.py", "hermes-plugin/zalo/model_command.py", "hermes-plugin/zalo_tools/*", "hermes-plugin/zalo_memory/*", "tts/*", "scripts/*"]`
  - `legacy_purge_set`:
    - `integration/zalo-bot-service/src/local-chat/local-chat-store.ts` (`P5`, `P1`): `zd_fold` search + `message_chunk_aliases` echo reconciliation.
    - `integration/zalo-bot-service/src/channels/personal-zca-channel.ts` (`P4`, `P2`, `P1`, `P6`, `P7`, `P10`):
      - `P6`: Guard `extractInboundAttachments` with `hasRealMedia(rawType, messageType)`; require valid `http(s)://` URL in `extractAttachmentFromRecord` and exclude `record.thumb` / `record.thumbnail` when `isFileMessage(rawType, messageType)` is true; infer missing `fileExt` from `extensionOf(fileName) || extensionOf(url)` and delegate `extensionMimeType` to `resolveAttachmentMimeType` (single 31-extension `MIME_BY_EXT` map); in `sendFriendRequest`, hoist `selectedInstance` outside `try` and treat `isAlreadyFriendErrorCode(err)` (`222`, `225`) as `{ success: true }` while invalidating `friendsCache`.
      - `P7`: Wire per-account `ZaloRateLimiter` (`getAccountRateLimiter(uId)`, using `performance.now()`) **outside** `runWithFixedDateNow` into `sendMessage` (`'high'` priority for interactive/chatbot sends, `'normal'` priority when `req.metadata?.source === 'campaign'`, returning `errorCode: 'RATE_LIMITED', retryAfterMs` on chunk 0 or `partial:` on chunk `k > 0`), `sendFriendRequest` (`'normal'`), `createGroup` (`'normal'`), and `inviteToGroup` (`'normal'`), cleaning up limiter state in `deleteAccount`.
      - `P10`: In `sendMessage`'s multi-chunk loop, when `threadType === ThreadType.Group` and `chunk.text.includes('@')` and explicit `req.mentions` were not preserved, resolve `@Tên` and `@All` (`uid: '-1'`) offsets on `chunk.text` via `findMentions(chunk.text, groupMeta.members, { selfUid: selectedInstance.uId, continuesInNextChunk: chunkIndex < effectiveChunks.length - 1, canMentionAll })` backed by a `${selectedInstance.uId}:${groupId}` 10-minute cache with a `4000ms` lookup timeout.
    - `integration/zalo-bot-service/src/agent/campaign-progress.ts`, `src/agent/command-executor.ts`, & `src/agent/agent-runner.ts` (`P8`): Replace non-atomic `fs.writeFileSync` in `writeAll` with Windows 3-retry `EPERM/EBUSY/EACCES` atomic `.tmp` + `fs.renameSync` (cleaning up `.tmp` on failure and returning `boolean`); save corrupt `in-flight.json` to `in-flight.json.corrupt-<ts>` in `readAll`; add `inFlightRecipient` + `abortedReason` to `CampaignProgressRecord` and include them in `reportInterruptedCampaigns` (`agent-runner.ts`) and `finalResult` (`command-executor.ts`); checkpoint `inFlightRecipient` before `sendMessage` (skipping the send if checkpoint returns `false`), wrap `sendMessage` in a `CAMPAIGN_SEND_TIMEOUT_MS = 300_000` race recording `status: 'unknown'` on timeout, retry once on `errorCode === 'RATE_LIMITED'` without incrementing `failStreak`, and abort remaining recipients after `CAMPAIGN_MAX_FAIL_STREAK = 5` consecutive failures.
    - `integration/zalo-bot-service/src/chatbot/chatbot-engine.ts` & `src/chatbot/chatbot-runtime.ts` (`P9`): Implement `FloodGuard` (`> threshold` = 7th message in 15s $\to$ 90s mute) in `chatbot-engine.ts` and wire it in `LocalChatbotRuntime.handlePersistedInbound` **before** `this.debouncer.push(conversationKey, ...)`.

### 4.2 Contract-First Boundary Specifications
- **Owner & Consumer:** Provider is `integration/zalo-bot-service` (TypeScript backend); consumers are `ChatbotDispatcher`, `LocalChatStore`, `command-executor.ts`, `agent-runner.ts`, and the Flutter Live Chat client (`http://127.0.0.1:<port>/local/*`).
- **Authoritative Contract Artifacts:** `integration/zalo-bot-service/src/zca-js.d.ts`, `integration/zalo-bot-service/src/channels/types.ts`, and `integration/zalo-bot-service/src/agent/campaign-progress.ts`.
- **Behavioral Guarantees (`P6`–`P10`):**
  1. **`P6` (`zalo-media-enricher.ts` + `personal-zca-channel.ts`):**
     - `hasRealMedia(rawType, messageType)` is a denylist returning `false` for `text`, `link`, `poll`, `reminder`, `contact_card`, `system`, `location`, `sticker`, and raw `msgType` matching `/(recommended|webchat|chat\.text|poll|ecard|undo|sticker|link)/i`.
     - `isFileMessage(rawType, messageType)` returns `true` for `messageType === 'file' || messageType === 'doc'` or raw `msgType` matching `/file|doc/i`.
     - `extractAttachmentFromRecord` returns `null` if neither `url` nor `thumbnailUrl` is a valid `http(s)://` URL; when `isFileMessage` is true, `record.thumb` / `record.thumbnail` are excluded.
     - `extensionOf(input)` parses `new URL(input).pathname` when `input` starts with `http(s)://`, matches `/\.([A-Za-z0-9]{1,5})$/`, and `resolveAttachmentMimeType(ext, kind)` resolves all 31 extensions in `MIME_BY_EXT` (single source of truth delegated from `extensionMimeType`).
     - `isAlreadyFriendErrorCode(err)` returns `true` for numeric Zalo error codes `222` and `225`, causing `PersonalZcaChannel.sendFriendRequest` to invalidate `friendsCache.delete(selectedInstance.uId)` and return `{ success: true }`.
  2. **`P7` (`src/channels/zalo-rate-limiter.ts` + `personal-zca-channel.ts`):**
     - `createZaloRateLimiter({ capacity = 5, refillMs = 3000, maxWaitMs = 20000, now = () => performance.now() })` uses fractional token refill, drains `'high'` waiters before `'normal'` waiters, and rejects with `RateLimitedError` (`err.code === 'RATE_LIMITED'`, `err.waitMs`) both on up-front `projectedWait > maxWaitMs` and if a queued waiter exceeds `maxWaitMs`.
     - `PersonalZcaChannel` acquires tokens **outside** `runWithFixedDateNow` (`'high'` for interactive/chatbot `sendMessage`, `'normal'` when `req.metadata?.source === 'campaign'` or in `sendFriendRequest` / `createGroup` / `inviteToGroup`), returning `{ success: false, errorCode: 'RATE_LIMITED', retryAfterMs: err.waitMs }` if chunk 0 / single send is rate-limited, or `partial:` if chunk `k > 0` is rate-limited. `RateLimitedError` carries bilingual `vi`/`en` text, `local-chat-api.ts` forwards `errorCode` + `retryAfterMs`, and `ChatbotDispatcher.handleSendFailure` records `reason: 'rate_limited'` without entering permanent human handoff.
  3. **`P8` (`src/agent/campaign-progress.ts`, `src/agent/command-executor.ts`, `src/agent/agent-runner.ts`):**
     - `writeAll` writes `.tmp`, retries `fs.renameSync` up to 3 times (50ms apart) on Windows `EPERM`/`EBUSY`/`EACCES`, removes `.tmp` on failure, and returns `boolean`.
     - `readAll` copies corrupt `in-flight.json` to `in-flight.json.corrupt-${Date.now()}` (capping to the latest `.corrupt-<ts>` file) before returning `{}`.
     - `runCampaignInBackground` checks `beginCampaign` return value before entering the loop, checkpoints `inFlightRecipient` before `sendMessage` (skipping the send if `updateCampaign` returns `false`), retries once on `errorCode === 'RATE_LIMITED'` without incrementing `failStreak`, records `status: 'unknown'` on `CAMPAIGN_SEND_TIMEOUT_MS = 300_000` timeout, and aborts remaining recipients (`status: 'cancelled'`, `abortedReason: 'aborted_fail_streak'`) when `failStreak >= 5`.
     - `reportInterruptedCampaigns` (`agent-runner.ts`) includes `unknownCount`, `inFlightRecipient`, and `abortedReason` in the interrupted report sent to Cloud.
     - *Cloud Boundary Note (`F1`):* The local agent emits `status: 'unknown'`, `unknownCount`, `abortedReason`, and `inFlightRecipient` in campaign progress/final/interrupted payloads; the separate `alpha-studio-backend` repository (`server/routes/crm.js` / `CrmExecutionLog.status`) currently maps unrecognised statuses to `queued` $\to$ `cancelled` until the cloud schema adds `'unknown'` (tracked in `.claude/PROJECT_SUMMARY.md` §6).
  4. **`P9` (`src/chatbot/chatbot-engine.ts` + `src/chatbot/chatbot-runtime.ts`):**
     - `FloodGuard` (`threshold = 6`, `windowSeconds = 15`, `muteSeconds = 90`, default monotonic clock `performance.now()` immune to `runWithFixedDateNow` `Date.now` pinning, plus `reset()`) returns `'ok'` for the first 6 messages within 15s, `'just_muted'` on the 7th message within 15s (`hits.length > threshold`), and `'muted'` during the 90s mute window.
     - Wired in `LocalChatbotRuntime.handlePersistedInbound` (`chatbot-runtime.ts`) **before** `this.debouncer.push(conversationKey, ...)` for `event.threadType === 'group'` (silent mute logged at `console.warn` on `'just_muted'` so the bot does not add extra traffic to a flooded group, while 1:1 user DMs remain coalesced by `ConversationDebouncer` without dropping lines).
  5. **`P10` (`src/channels/zalo-markdown-formatter.ts` + `src/channels/personal-zca-channel.ts`):**
     - `findMentions(msg, members, { selfUid, continuesInNextChunk, canMentionAll })` matches `@All` (`/all(?![\p{L}\p{N}_])/iu`, `len = 4`, `uid: '-1'`) when `canMentionAll` is true and `@<name>` longest-first where `uid !== selfUid`, `uids.size === 1` (ambiguous names skipped), preceding char is not `NAME_CHAR = /[\p{L}\p{N}_]/u`, following char is not `NAME_CHAR`, following text does not match `NAME_CONTINUES = /^ \p{Lu}/u` (unless `name.includes(' ')`), and `!(continuesInNextChunk && after.trim() === '')`.
     - Wired into `PersonalZcaChannel.sendMessage` for group threads (`threadType === ThreadType.Group`) using a `${selectedInstance.uId}:${groupId}` 10-minute `performance.now()` cache (with a 60s short TTL for incomplete large-group member lists) and a `4000ms` timeout (`canMentionAll = members.length <= 100 || isAdminOrOwner` evaluated for `selectedInstance.uId`).

---

## 5. Bite-Sized Implementation Tasks (Phase 1 Tasks 1–4 Completed; Phase 2 Tasks 5–10 Ordered `P6 > P7 > P8 > P9 > P10`)

### Task 1–4: Phase 1 (`P5`, `P4`, `P2`, `P1`) — [COMPLETED]
- [x] Implemented and verified (`184/184` tests passing).

---

### Task 5: Attachment Extraction Guard (`hasRealMedia` Denylist, URL-Required Check, File Thumb Exclusion, URL Pathname Extension Inference, Single 31-Ext MIME Map) & Friend Request Code `222`/`225` Idempotency (`P6`)

**Files:**
- Modify: `integration/zalo-bot-service/src/channels/zalo-media-enricher.ts`
- Modify: `integration/zalo-bot-service/src/channels/zalo-media-enricher.test.ts`
- Modify: `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- Modify: `integration/zalo-bot-service/src/channels/personal-zca-channel.test.ts`

**Interfaces:**
- Produces in `src/channels/zalo-media-enricher.ts`:
  - `export const MIME_BY_EXT: Readonly<Record<string, string>>` (all 31 extensions from `zalo-attachments.js:13-27`)
  - `export function hasRealMedia(rawMsgType: unknown, messageType?: string): boolean`
  - `export function isFileMessage(rawMsgType: unknown, messageType?: string): boolean`
  - `export function extensionOf(input: unknown): string`
  - `export function resolveAttachmentMimeType(fileExtOrNameOrUrl: string, kind: string): string`
  - `export function isAlreadyFriendErrorCode(err: unknown): boolean`

- [ ] **Step 1: Write the failing unit & wiring tests in `zalo-media-enricher.test.ts` and `personal-zca-channel.test.ts`**
  Test cases:
  1. `hasRealMedia` returns `false` for `chat.recommended` (`link`), `share.ecard` (`contact_card`), `chat.poll` (`poll`), `chat.sticker` (`sticker`), `chat.undo`, `webchat`, `system`, `location`, and `reminder`, and returns `true` for `chat.photo` (`image`), `chat.video.msg` (`video`), `chat.voice` (`voice`), `share.file` (`file`), `chat.gif` (`gif`), and numeric `cliMsgType` on quoted messages.
  2. `extensionOf` extracts `'pdf'` from `'bao-gia_2026.PDF'`, `'docx'` from `'https://cdn.zalo.me/files/hop-dong.docx?token=abc'`, and returns `''` for `'https://zalo.me'` (no path extension) or extensions `> 5` chars.
  3. `resolveAttachmentMimeType` resolves all 31 extensions in `MIME_BY_EXT` and falls back to `'application/octet-stream'` for `kind === 'file'` and `'image/jpeg'` for `kind === 'image'`.
  4. `normalizeInboundMessage` in `personal-zca-channel.test.ts`: a `link` (`chat.recommended`) message produces `attachments: []`; a `file` (`share.file`) message with both `href` and `thumb` produces a single file attachment with `url: href` and no blurry `thumb` URL; a record with only `title` and no `http(s)://` URL produces `attachments: []`.
  5. `isAlreadyFriendErrorCode` returns `true` for codes `222` and `225` and `false` for `112` or `600`.

- [ ] **Step 2: Run test to verify it fails**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: FAIL

- [ ] **Step 3: Implement `P6` in `zalo-media-enricher.ts` and wire into `personal-zca-channel.ts`**
  - Implement `MIME_BY_EXT` (31 extensions), `hasRealMedia`, `isFileMessage`, `extensionOf` (parsing `new URL(str).pathname` for URLs), `resolveAttachmentMimeType`, and `isAlreadyFriendErrorCode` in `src/channels/zalo-media-enricher.ts`.
  - Wire into `extractAttachmentFromRecord`, `extractInboundAttachments`, `extensionMimeType`, and `sendFriendRequest` (hoisting `selectedInstance` outside `try`) in `src/channels/personal-zca-channel.ts`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: PASS

---

### Task 6: Monotonic-Clock Per-Account Priority Token-Bucket Outbound Rate Limiter (`P7`)

**Files:**
- Create: `integration/zalo-bot-service/src/channels/zalo-rate-limiter.ts`
- Create: `integration/zalo-bot-service/src/channels/zalo-rate-limiter.test.ts`
- Modify: `integration/zalo-bot-service/src/channels/types.ts`
- Modify: `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`

**Interfaces:**
- Produces in `src/channels/zalo-rate-limiter.ts`:
  - `export type RateLimitPriority = 'high' | 'normal';`
  - `export class RateLimitedError extends Error { readonly code = 'RATE_LIMITED'; readonly waitMs: number; }`
  - `export interface ZaloRateLimiter { acquire(priority?: RateLimitPriority): Promise<{ waitedMs: number; priority: RateLimitPriority }>; state(): { tokens: number; highQueued: number; normalQueued: number }; dispose(): void; }`
  - `export function createZaloRateLimiter(opts?: { capacity?: number; refillMs?: number; maxWaitMs?: number; now?: () => number }): ZaloRateLimiter`
- Extends `ZaloSendMessageResult` in `src/channels/types.ts` with `errorCode?: 'RATE_LIMITED'; retryAfterMs?: number;`.

- [ ] **Step 1: Write the failing tests in `zalo-rate-limiter.test.ts`**
  Test cases:
  1. Immediate burst up to `capacity = 5` resolves with `waitedMs = 0`.
  2. When tokens are exhausted, `'high'` priority waiters drain ahead of queued `'normal'` priority waiters as tokens refill fractionally every `refillMs`.
  3. Up-front `projectedWait > maxWaitMs` rejects immediately with `RateLimitedError`, and a `'normal'` waiter starved past `maxWaitMs` by later `'high'` arrivals also rejects via its per-waiter deadline timer.
  4. Pinning global `Date.now = () => 1700000000000` does **not** freeze the default limiter clock (`performance.now()`), so token refill still completes on schedule.

- [ ] **Step 2: Run test to verify it fails**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: FAIL (`Cannot find module './zalo-rate-limiter.js'`)

- [ ] **Step 3: Implement `zalo-rate-limiter.ts` and wire per-account rate limiting into `personal-zca-channel.ts`**
  - Implement `createZaloRateLimiter` and `RateLimitedError` in `src/channels/zalo-rate-limiter.ts`.
  - In `src/channels/personal-zca-channel.ts`, acquire `'high'` (or `'normal'` when `req.metadata?.source === 'campaign'`) **outside** `runWithFixedDateNow` once per logical chunk in `sendMessage` (returning `errorCode: 'RATE_LIMITED', retryAfterMs` on chunk 0 or `partial:` on chunk `k > 0`) and `'normal'` in `sendFriendRequest`, `createGroup`, and `inviteToGroup`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: PASS

---

### Task 7: Crash-Safe Campaign Checkpointing, Windows 3-Retry Atomic Writes, `5-min` Send Timeout (`status: 'unknown'`) & `MAX_FAIL_STREAK = 5` Circuit Breaker (`P8`)

**Files:**
- Modify: `integration/zalo-bot-service/src/agent/campaign-progress.ts`
- Modify: `integration/zalo-bot-service/src/agent/command-executor.ts`
- Modify: `integration/zalo-bot-service/src/agent/agent-runner.ts`
- Modify: `integration/zalo-bot-service/src/agent/campaign-progress.test.ts`
- Modify: `integration/zalo-bot-service/src/agent/command-executor.test.ts`

**Interfaces:**
- Produces in `src/agent/campaign-progress.ts`:
  - `export interface InFlightRecipient { index: number; recipientId: string; startedAt: string; }`
  - Extended `CampaignProgressRecord` with `inFlightRecipient?: InFlightRecipient | null; abortedReason?: string; unknownCount?: number;`
  - `beginCampaign` and `updateCampaign` return `boolean`.
- Produces in `src/agent/command-executor.ts`:
  - `export const CAMPAIGN_SEND_TIMEOUT_MS = 5 * 60 * 1000;`
  - `export const CAMPAIGN_MAX_FAIL_STREAK = 5;`
  - `export function withSendTimeoutForTest<T>(promise: Promise<T>, timeoutMs: number, label: string): { promise: Promise<T>; isDead: () => boolean }`

- [ ] **Step 1: Write the failing tests in `campaign-progress.test.ts` and `command-executor.test.ts`**
  Test cases:
  1. `beginCampaign` and `updateCampaign` write `in-flight.json` atomically via `.tmp` + `renameSync` (retrying transient Windows `EPERM`/`EBUSY`/`EACCES`), return `true`, and persist `inFlightRecipient` + `abortedReason`.
  2. Corrupt `in-flight.json` saves a diagnostic `in-flight.json.corrupt-<ts>` copy while keeping `listInterruptedCampaigns(dir)` returning `[]` without throwing.
  3. `withSendTimeoutForTest` rejects with a timeout error (`err.code === 'SEND_TIMEOUT'`) and sets `isDead() === true` when a send hangs past `timeoutMs`.

- [ ] **Step 2: Run test to verify it fails**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: FAIL

- [ ] **Step 3: Implement `P8` across `campaign-progress.ts`, `command-executor.ts`, and `agent-runner.ts`**
  - Update `campaign-progress.ts` with Windows 3-retry atomic writes, `.corrupt-<ts>` snapshot, `inFlightRecipient`, `abortedReason`, and `unknownCount`.
  - Update `command-executor.ts` (`runCampaignInBackground`) to checkpoint `inFlightRecipient` before `sendMessage`, pass `metadata: { source: 'campaign', campaignId }`, retry once on `errorCode === 'RATE_LIMITED'` without counting `failStreak`, record `status: 'unknown'` on `SEND_TIMEOUT`, and abort remaining recipients (`abortedReason: 'aborted_fail_streak'`) when `failStreak >= 5`.
  - Update `reportInterruptedCampaigns` in `agent-runner.ts` to include `inFlightRecipient`, `abortedReason`, and `unknownCount`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: PASS

---

### Task 8: Pre-Debouncer Per-Sender Sliding-Window Anti-Flood Guard (`P9`)

**Files:**
- Modify: `integration/zalo-bot-service/src/chatbot/chatbot-engine.ts`
- Modify: `integration/zalo-bot-service/src/chatbot/chatbot-runtime.ts`
- Modify: `integration/zalo-bot-service/src/chatbot/chatbot-engine.test.ts`
- Modify: `integration/zalo-bot-service/src/chatbot/chatbot-runtime.test.ts`

**Interfaces:**
- Produces in `src/chatbot/chatbot-engine.ts`:
  - `export type FloodVerdict = 'ok' | 'just_muted' | 'muted';`
  - `export class FloodGuard { constructor(opts?: { threshold?: number; windowSeconds?: number; muteSeconds?: number; now?: () => number }); check(senderKey: string, nowMs?: number): FloodVerdict; reset(senderKey?: string): void; }`

- [ ] **Step 1: Write the failing unit & runtime wiring tests in `chatbot-engine.test.ts` and `chatbot-runtime.test.ts`**
  Test cases:
  1. `FloodGuard` (`threshold = 6`, `windowSeconds = 15`, `muteSeconds = 90`): first 6 messages within 15s return `'ok'`; the **7th** message (`hits.length > threshold`) within 15s returns `'just_muted'`; subsequent messages during the 90s mute window return `'muted'`; after 90s elapses, the next message returns `'ok'`.
  2. `LocalChatbotRuntime.handlePersistedInbound` (`chatbot-runtime.test.ts`): when a sender sends 8 rapid messages within 2 seconds into `handlePersistedInbound`, the first 6 messages are pushed to the debouncer while the 7th (`just_muted`) and 8th (`muted`) are dropped before `debouncer.push`, and subsequent messages from that sender during the 90s mute window do not trigger `evaluate` or `generateAi`.

- [ ] **Step 2: Run test to verify it fails**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: FAIL (`FloodGuard is not exported`)

- [ ] **Step 3: Implement `FloodGuard` in `chatbot-engine.ts` and wire into `LocalChatbotRuntime.handlePersistedInbound`**
  - Implement `FloodGuard` in `src/chatbot/chatbot-engine.ts` with attribution header.
  - Wire `this.floodGuard.check(`${event.accountId}:${event.senderId}`)` inside `LocalChatbotRuntime.handlePersistedInbound` (`src/chatbot/chatbot-runtime.ts`) before `this.debouncer.push`, accepting an optional `floodGuard?: FloodGuard` in `ChatbotRuntimeDependencies`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: PASS

---

### Task 9: Group `@Tên` & `@All` Post-Markdown Mention Offset Resolver (`P10`)

**Files:**
- Modify: `integration/zalo-bot-service/src/channels/zalo-markdown-formatter.ts`
- Modify: `integration/zalo-bot-service/src/channels/zalo-markdown-formatter.test.ts`
- Modify: `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`

**Interfaces:**
- Produces in `src/channels/zalo-markdown-formatter.ts`:
  - `export interface ZaloGroupMemberCandidate { id?: string; uid?: string; name?: string; displayName?: string; zaloName?: string; }`
  - `export interface ResolvedZaloMention { pos: number; len: number; uid: string; }`
  - `export function findMentions(msg: string, members: readonly ZaloGroupMemberCandidate[], opts?: { selfUid?: string; continuesInNextChunk?: boolean; canMentionAll?: boolean }): ResolvedZaloMention[]`

- [ ] **Step 1: Write the failing tests in `zalo-markdown-formatter.test.ts`**
  Test cases:
  1. `findMentions` resolves `@Nguyễn Văn A` and `@All` (`uid: '-1'`, `len: 4` when `canMentionAll: true`) into exact `{ pos, len, uid }` UTF-16 offsets after `formatAndChunkZaloMarkdown` strips `**` and `#` markers.
  2. Ambiguous names (two members sharing `displayName: "Minh"`) are **not** tagged (`uids.size !== 1`), while unique names are tagged longest-first.
  3. `NAME_CONTINUES = /^ \p{Lu}/u`: in `"Chào @Trang Nguyễn nhé"`, a member named `"Trang"` is **not** tagged when `"Trang Nguyễn"` is not in the member list because the name continues with a capital letter.
  4. Email addresses (`lienhe@gmail.com`) and mid-word `@` (`abc@Tên`) are ignored (`NAME_CHAR = /[\p{L}\p{N}_]/u`), and `@Tên   ` at the end of a chunk when `continuesInNextChunk: true` (`after.trim() === ''`) is skipped.
  5. `selfUid` is never mentioned, and `@All` is ignored when `canMentionAll` is `false`.

- [ ] **Step 2: Run test to verify it fails**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: FAIL (`findMentions is not exported`)

- [ ] **Step 3: Implement `findMentions` in `zalo-markdown-formatter.ts` and wire into `personal-zca-channel.ts`**
  - Implement `findMentions` in `src/channels/zalo-markdown-formatter.ts` (ported from `zalo-mentions.js:1-109`).
  - In `src/channels/personal-zca-channel.ts`:
    - Add `${selectedInstance.uId}:${groupId}` 10-minute `groupMembersMentionCache` with a `4000ms` timeout around `instance.api.getGroupInfo(groupId)` (using `info.currentMems`, not per-member `getGroupMembersInfo`, and evaluating `canMentionAll = totalMembers <= 100 || creatorId === selectedInstance.uId || adminIds.includes(selectedInstance.uId)` for the sending `selectedInstance`).
    - Wire `findMentions` into `sendMessage`'s multi-chunk loop when `threadType === ThreadType.Group && !chunkMentions && chunk.text.includes('@')`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: PASS

---

### Task 10: Target Verification, Security Delta (`fingerprint-delta`), & Project Summary Update (`AGENTS.md` VERIFY)

- [ ] **Step 1: Run backend build & test suite**
  Run: `npm --prefix integration/zalo-bot-service test`
  Expected: PASS (0 errors)

- [ ] **Step 2: Run repo guard & Flutter analysis/tests**
  Run:
  - `D:\Dev\conda-envs\py312\python.exe -X utf8 -I -B .claude\guard_check.py`
  - `flutter analyze`
  - `flutter test`
  Expected: PASS (0 errors)

- [ ] **Step 3: Run Step 7.3 Post-Integration `skill_gate.py scan` & `fingerprint-delta`**
  Run:
  - `D:\Dev\conda-envs\py312\python.exe -X utf8 -I -B D:\Dev\3.lib_pj\hybrid-ai-skills\skills\skill-inspector\scripts\skill_gate.py scan "D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\integration\zalo-bot-service\src" --no-flash --allow-internal-links --report-out "$evalRoot\skillspector_post_p2.json"`
  - `D:\Dev\conda-envs\py312\python.exe -X utf8 -I -B D:\Dev\3.lib_pj\hybrid-ai-skills\skills\skill-inspector\scripts\skill_gate.py fingerprint-delta "$evalRoot\skillspector_baseline_p2.json" "$evalRoot\skillspector_post_p2.json"`
  Expected: `new_count == 0`, `new_mal == 0`, `incomplete_count == 0` (or all partially inspected files manually audited 100%).
