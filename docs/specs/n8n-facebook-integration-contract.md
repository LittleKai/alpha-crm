# Alpha CRM n8n and Facebook Integration Contract

## Current implementation in this repo

- Flutter adds the `/workflows` workspace with a workflow template catalog, n8n settings, and template install actions.
- The local `integration/zalo-bot-service` stores n8n settings at `.data/integrations/settings.json`, masks the API key for UI responses, creates n8n workflows through the n8n Public API, and dispatches inbound Zalo events to a configured n8n webhook.
- Per-account Zalo proxy metadata is now enforced when `personal_zca` credentials are loaded: the account setting proxy URL becomes the `agent` passed into `zca-js`.
- Facebook is represented as `facebook_page` in the channel capability matrix and template catalog, but official Page/Messenger send/webhook handling must live in the Alpha Studio cloud backend.

## Required cloud backend endpoints

The local desktop backend is bound to `127.0.0.1`, so an outside n8n instance cannot reliably call it directly. n8n action callbacks must call the cloud backend, and the existing local agent polling loop should receive queued commands.

Required endpoints:

- `POST /api/crm/n8n/actions`
  - Auth: signed secret or tenant-scoped token issued by cloud.
  - Body: `{ action, channel, accountId?, pageId?, conversationId?, payload, idempotencyKey? }`.
  - Behavior: validate tenant, rate-limit risky actions, enqueue supported agent commands such as `zalo.message.send`, or execute cloud-owned actions such as Facebook Page send.
- `GET /api/crm/integrations/facebook/pages`
  - Returns masked Page connection status for Flutter.
- `PUT /api/crm/integrations/facebook/pages`
  - Stores encrypted Meta Page token and page metadata.
- `GET /api/crm/facebook/webhook`
  - Meta webhook verification with verify token.
- `POST /api/crm/facebook/webhook`
  - Receives Messenger events, verifies Meta signature, stores conversation/message records, and can fan out to n8n event webhooks.

## Channel rules

- `zalo_personal`: personal-account operations remain behind the local agent and existing compliance guard.
- `zalo_oa`: official webhook/send only; no friend/group automation.
- `facebook_page`: official Meta Page/Messenger API only; no cookie login, no personal profile automation, no bulk send outside valid policy windows.

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
