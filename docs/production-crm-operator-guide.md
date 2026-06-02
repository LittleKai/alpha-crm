# Alpha CRM Production Operator Guide

## Daily Startup

1. Confirm the cloud backend is deployed and MongoDB is reachable.
2. Open the Windows CRM app and verify the local Zalo backend status is online.
3. Confirm the subscribed device is registered and heartbeat is current.
4. Open Live Chat and verify new Zalo messages arrive in the inbox.
5. Open Dashboard and check task, chatbot, group, and campaign metrics for anomalies.

## Live Chat

- Use account filters to isolate a Zalo account before replying.
- Use tags and notes for operator handoff context.
- Disable chatbot on a conversation when a user asks for a human, sends a complaint, or needs sensitive handling.
- Mark conversations read after manual review to keep unread counts actionable.

## Chatbot

- Keep keyword rules narrow and ordered by priority.
- Test a rule in the playground before enabling it.
- Review chatbot logs for failures, handoff triggers, and unexpected replies.
- Disable global chatbot settings during incidents or before high-risk campaign windows.

## Managed Groups

- Run group sync after connecting or changing a Zalo account.
- Mark only business-relevant groups as managed.
- Create checkpoints for the time window that needs analysis.
- Generate summaries from checkpoints and convert high-priority insights into follow-up tasks.

## Tasks And Segments

- Use saved segments for repeatable follow-up audiences.
- Review overdue and urgent tasks before starting bulk campaigns.
- Keep task notes concise and tied to a customer, group, conversation, or insight when possible.

## Import And Export

- Import customer CSVs only from approved sources with consent evidence.
- Export customer, campaign log, or group summary CSVs for audit and reporting.
- Treat exported files as customer data and store them according to internal policy.

## Incident Response

1. Use the web admin CRM health tab to inspect subscriptions, devices, commands, AI usage, and task queues.
2. Click Disable Automation if chatbot or campaign automation must stop immediately.
3. Confirm live chat remains usable for manual support.
4. Document the incident with timestamps, impacted users, and actions taken.
