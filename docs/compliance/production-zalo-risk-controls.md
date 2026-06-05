# Alpha CRM Production Zalo Risk Controls

## Account Controls

- Connect only approved business Zalo accounts.
- Keep personal and campaign activity separated by account when possible.
- Use account-specific send routing for replies and campaigns that originate from a known account.
- Remove or rotate accounts that show login, rate, or trust warnings.

## Messaging Controls

- Send only to customers or groups with consent or a documented business relationship.
- Keep campaign rate limits conservative and review success/failure metrics during execution.
- Stop campaigns when failure rates rise, provider warnings appear, or complaint signals increase.
- Avoid duplicate sends by using backend campaign status and execution logs as the source of truth.

## Chatbot Controls

- Use keyword rules for deterministic replies; keep AI-assisted content within quota and review logs.
- Configure handoff keywords for complaint, pricing, cancellation, refund, and support escalation cases.
- Disable chatbot per conversation when an operator takes over.
- Use the admin emergency disable control to stop automation globally during an incident.

## Group Controls

- Ingest messages only from groups explicitly marked as managed.
- Do not summarize unmanaged or private groups.
- Review summaries and insights before acting on sensitive topics.
- Convert insights to tasks for traceable follow-up instead of acting from chat context alone.

## Data Controls

- Treat live chat, group messages, summaries, exports, and chatbot logs as customer data.
- Limit CSV exports to operational users who need them.
- Keep audit logs and execution logs for compliance review.
- Do not paste secrets, cookies, QR session artifacts, or local `.data` files into support tickets.

## Release Controls

- Verify the packaged Windows release includes the local Zalo backend launcher and dependencies.
- Confirm `.env` and local session `.data` files are not included in public ZIPs.
- Run smoke tests for login, account sync, inbound message reporting, manual send, group sync, chatbot test, and campaign stop before broad rollout.
