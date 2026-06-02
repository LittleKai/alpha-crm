# Important Fixed Bugs

**Last Updated:** 2026-06-01 +07:00

---

## Purpose

This file records important fixed bugs that should not be repeated. Keep entries concise and actionable.

Record only high-impact, hard-to-detect, or likely-to-recur bugs. Do not record ordinary bug fixes, do not append entries after every task, and do not use this file as a changelog.

---

## Fixed Bugs

### 2026-06-01 - Background Campaign Start Must Not Complete Campaigns

- Symptom: A campaign command could start asynchronously on the Windows agent, but the backend treated the initial `{ status: 'running' }` report as a final successful result and could mark the campaign `completed` before messages finished sending.
- Root cause: The agent runner reports every command result through the same endpoint, while the backend result handler did not distinguish in-progress reports from final campaign results.
- Fix summary: Backend result handling now stores `{ status: 'running' }` as command status `running` and returns without setting `finishedAt` or changing `CrmCampaign.status`; final background results still complete/cancel the campaign.
- Rule: Long-running agent commands need an explicit in-progress state and must update campaign status only from final result payloads.
- Related files: `alpha-studio-backend/server/routes/crm.js`, `tools/alpha-crm/integration/zalo-bot-service/src/agent/agent-runner.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/agent/command-executor.ts`.

### 2026-06-02 - Zalo Group Dropdown Assertion Crash (g['groupId'] vs g['id'])

- Symptom: Opening "Kết bạn từ nhóm" -> "Chọn từ nhóm Zalo" threw a Flutter DropdownButton assertion crash (`items == null || items.isEmpty || ...`).
- Root cause: `FriendByGroupNotifier.loadGroups` mapped backend group records using `id: g['groupId']` instead of the correct `g['id']` returned by ZCA API, causing all loaded groups to fallback to an empty string `""` as their ID, which created multiple dropdown items with duplicate empty string values.
- Fix summary: Changed group mapping in `FriendByGroupNotifier.loadGroups` to map `id: g['id']` and safely parse `memberCount: int.tryParse(g['memberCount']?.toString() ?? '0') ?? 0` to align with the backend payload.
- Rule: Always align Zalo group structure parsing across providers (such as `InviteToGroupNotifier`, `LeaveGroupsNotifier`, and `FriendByGroupNotifier`) to use `id: g['id']` and robustly parse `memberCount` via `int.tryParse`.
- Related files: `tools/alpha-crm/lib/features/friends/by_group/providers/friend_by_group_provider.dart`.

### 2026-06-02 - Zalo Group Member Scanning 0-Member Failure due to Account Mismatch

- Symptom: Selecting a group from the Zalo groups dropdown in "Kết bạn từ nhóm" yielded 0 members and failed scanning with: `[PersonalZcaChannel] Found 0 members in group <groupId>`.
- Root cause: The dropdown returned groups belonging to all logged in accounts, but the member scanner utilized the currently active Zalo account from the config. When an account attempted to read members of a group it did not belong to, the ZCA API returned empty details/errors.
- Fix summary: Modified backend Zalo adapters (`PersonalZcaChannel`, `MockZaloChannel`) to return `accountId` alongside group info. Updated Flutter provider group builders to map `accountId` to ZaloGroup models. Configured the dropdown list in UI screens (`friend_by_group_screen.dart`, `invite_to_group_screen.dart`) to dynamically filter the Zalo groups, showing only groups that belong to the currently selected sending Zalo account.
- Rule: Always filter target groups dropdown lists by the selected active account ID in the UI scaffolding to prevent empty member API results and permissions errors.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `tools/alpha-crm/integration/zalo-bot-service/src/channels/mock-channel.ts`, `tools/alpha-crm/lib/features/friends/by_group/presentation/screens/friend_by_group_screen.dart`, `tools/alpha-crm/lib/features/groups/presentation/screens/invite_to_group_screen.dart`.
