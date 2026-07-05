# Alpha CRM n8n, Facebook, and TikTok Integration Contract

## Current implementation in this repo

- Flutter adds the `/workflows` workspace with a workflow template catalog, n8n settings, and template install actions.
- The local `integration/zalo-bot-service` stores n8n settings at `.data/integrations/settings.json`, masks the API key for UI responses, creates n8n workflows through the n8n Public API, and dispatches inbound Zalo events to a configured n8n webhook.
- Per-account Zalo proxy metadata is now enforced when `personal_zca` credentials are loaded: the account setting proxy URL becomes the `agent` passed into `zca-js`.
- Facebook is represented as `facebook_page` in the channel capability matrix and template catalog. Built and shipped: Meta webhook **receiving** is cloud-owned (`alpha-studio-backend`); outbound **sending** happens directly from the local `zalo-bot-service` agent to the Graph API using a page access token that never leaves the local machine, exactly like Zalo.
- TikTok is represented as `tiktok` and mirrors the same adapter shape (`TiktokChannel`, structurally identical to `FacebookChannel`) and the same cloud-relay webhook pattern (`GET/POST /api/crm/tiktok/webhook`). Every TikTok-specific field/header/endpoint name (`account_id`, `x-tiktok-signature`, the TikTok Business Messaging API base URL) is an explicitly-commented **unverified placeholder** — it has not been checked against real TikTok Business Messaging API docs or live credentials, and must be re-verified before relying on it in production.
- All chat data (Zalo, Facebook, TikTok) continues to be stored in the local SQLite `LocalChatStore` via `emitInboundMessage`. The cloud webhook only keeps a durable Mongo backup copy and relays the raw event down to the desktop agent through the existing `CrmAgentCommand` + `/agent/commands/next` poll mechanism (`channel.message.relay` command type), so the agent can write it into local SQLite the same way it does for native Zalo events.

## Required cloud backend endpoints

The local desktop backend is bound to `127.0.0.1`, so an outside n8n instance cannot reliably call it directly. n8n action callbacks must call the cloud backend, and the existing local agent polling loop should receive queued commands.

Required endpoints:

- `POST /api/crm/n8n/actions` — **not yet implemented.**
  - Auth: signed secret or tenant-scoped token issued by cloud.
  - Body: `{ action, channel, accountId?, pageId?, conversationId?, payload, idempotencyKey? }`.
  - Behavior: validate tenant, rate-limit risky actions, enqueue supported agent commands such as `zalo.message.send`.
- `POST /api/crm/agent/channels/register` — **implemented** (`server/routes/crm.js`).
  - Auth: `x-agent-device-id` + `x-agent-secret` (same auth as the rest of the agent-polling API), not a Flutter-facing endpoint.
  - Body: `{ channel, externalAccountId, appId?, verifyToken, appSecret, enabled? }`.
  - Behavior: called automatically by the local bridge (`zalo-bot-service/src/server.ts`) whenever the operator saves a complete, enabled Facebook or TikTok integration in the Flutter settings screen. Persists `verifyToken`/`appSecret` (encrypted at rest) on `CrmChannelIntegration` so the webhook routes below can verify the platform's signature — the page/account access token itself is never sent to the cloud.
- `GET /api/crm/facebook/webhook` — **implemented** (`server/routes/channelWebhooks.js`).
  - Meta webhook verification with verify token.
- `POST /api/crm/facebook/webhook` — **implemented** (`server/routes/channelWebhooks.js`).
  - Verifies Meta's `X-Hub-Signature-256` against the stored `appSecret`, writes a durable `CrmConversation`/`CrmMessage` backup copy, and creates a `CrmAgentCommand{type:'channel.message.relay'}` so the desktop agent relays the event into local SQLite.
- `GET /api/crm/tiktok/webhook` — **implemented** (`server/routes/channelWebhooks.js`), mirrors the Facebook handshake shape. **Placeholder**: verify-token query param name is an unverified guess pending real TikTok docs.
- `POST /api/crm/tiktok/webhook` — **implemented** (`server/routes/channelWebhooks.js`), mirrors the Facebook flow: verifies an `x-tiktok-signature` HMAC-SHA256 against the stored `appSecret`, writes the same durable Mongo backup, and creates a `CrmAgentCommand{type:'channel.message.relay', payload:{channel:'tiktok', ...}}`. **Placeholder**: header name, payload shape (`account_id`, `messages[]`), and signature scheme are unverified guesses mirroring Facebook — re-check once real TikTok Business Messaging API docs/credentials are available.

## Channel rules

- `zalo_personal`: personal-account operations remain behind the local agent and existing compliance guard.
- `zalo_oa`: official webhook/send only; no friend/group automation.
- `facebook_page`: official Meta Page/Messenger API only; no cookie login, no personal profile automation, no bulk send outside valid policy windows.
- `tiktok`: official TikTok Business Messaging API only (placeholder pending verification); no cookie login, no personal profile automation, no bulk send outside valid policy windows — same posture as `facebook_page`.

## n8n expectations

- Users bring an external n8n URL and API key.
- Alpha CRM creates workflows inactive by default; the operator reviews and activates in n8n.
- n8n webhook production URLs require the workflow to be active in n8n.
- n8n action nodes should call the cloud relay URL, not `127.0.0.1`.

References:

- n8n Public API: https://docs.n8n.io/api/
- n8n API authentication: https://docs.n8n.io/api/authentication/
- n8n Webhook node: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/
- Meta Messenger Platform: https://developers.facebook.com/docs/messenger-platform/
- Meta platform terms: https://www.facebook.com/terms
