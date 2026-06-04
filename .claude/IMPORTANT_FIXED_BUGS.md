# Important Fixed Bugs

**Last Updated:** 2026-06-04 +07:00

---

## Purpose

This file records important fixed bugs that should not be repeated. Keep entries concise and actionable.

Record only high-impact, hard-to-detect, or likely-to-recur bugs. Do not record ordinary bug fixes, do not append entries after every task, and do not use this file as a changelog.

---

## Fixed Bugs

### 2026-06-04 - Windows ZIP Updates Must Self-Apply, Not Just Open Explorer

- Symptom: The in-app Windows updater downloaded the release ZIP, opened it, and then stopped. Users had to manually extract/copy files, so the update did not actually apply.
- Root cause: Portable ZIP releases are not installers. Calling `OpenFilex.open(zipPath)` only opens the archive in Explorer and cannot replace the running `alpha_crm.exe` bundle.
- Fix summary: `AppUpdateService` now generates a detached `apply_update.cmd` helper for ZIP releases. The helper waits for the app to exit, expands the ZIP with PowerShell, finds the folder containing `alpha_crm.exe`, copies files into the current app directory with `robocopy`, restarts the app, and writes an update log.
- Rule: For Windows portable ZIP releases, always launch a separate updater process/script that applies the bundle after the running app exits. Do not use `OpenFilex.open` as an installer for ZIP assets.
- Related files: `tools/alpha-crm/lib/shared/utils/app_update_service.dart`, `tools/alpha-crm/test/app_update_service_test.dart`.

### 2026-06-03 - Device Pairing Must Read `pairedMobileUserIds`, Not Mobile Device Records

- Symptom: On mobile, tapping QR scan did not open a real scanner. Entering the pairing code could show success, but the PC and mobile device pairing screens still appeared unchanged.
- Root cause: The cloud backend does not create separate active Android/iOS `CrmDevice` records for paired phones. It records mobile pairings on the active Windows device in `pairedMobileUserIds`. The Flutter provider incorrectly searched `/crm/devices` for non-Windows active device records, so confirmed pairings were ignored by the UI. The QR button was also a mock dialog rather than a camera scanner.
- Fix summary: Parse paired state from the active Windows device's `pairedMobileUserIds`, accept both 6-digit `pairingCode` and QR `qrToken` confirm payloads, poll the PC pairing screen while waiting, render a real QR with `qr_flutter`, scan it with `mobile_scanner`, and add Android camera permission.
- Rule: Treat the active Windows `CrmDevice` as the host record for mobile pairings unless the cloud backend schema changes; never infer mobile pairing status from separate mobile `CrmDevice` rows.
- Related files: `tools/alpha-crm/lib/features/devices/providers/crm_device_provider.dart`, `tools/alpha-crm/lib/features/devices/presentation/screens/device_pairing_screen.dart`, `tools/alpha-crm/android/app/src/main/AndroidManifest.xml`, `tools/alpha-crm/test/crm_device_provider_test.dart`.

### 2026-06-03 - Windows Localhost vs 127.0.0.1 Loopback Refusal Error

- Symptom: Linking Zalo account or performing health check in the Windows build fails with SocketException (OS Error: The remote computer refused the network connection, errno = 1225).
- Root cause: The local Node.js server binds to `127.0.0.1` (IPv4 loopback), but the Flutter app was configured with `http://localhost:8787` by default. On Windows, `localhost` resolves to `::1` (IPv6 loopback) first. Since the Node.js server was not listening on `::1`, the connection was refused.
- Fix summary: Changed default Zalo Backend Base URL from `http://localhost:8787` to `http://127.0.0.1:8787` in settings config schema, mock defaults, UI fallbacks, and the existing `zalo_settings.json` file.
- Rule: Always use explicit IPv4 `127.0.0.1` instead of `localhost` for local/loopback backend server connections on Windows to avoid IPv6 name resolution issues.
- Related files: `tools/alpha-crm/zalo_settings.json`, `tools/alpha-crm/lib/mock/mock_accounts.dart`, `tools/alpha-crm/lib/features/zalo_integration/data/zalo_integration_api.dart`, `tools/alpha-crm/lib/features/settings/presentation/screens/settings_screen.dart`, `tools/alpha-crm/docs/zalo-integration-installation-and-usage.md`.

### 2026-06-03 - Live Chat Must Preserve Plain Text Inbound Payloads

- Symptom: Live Chat appeared to load only messages that had links/files/rich attachments, while plain text inbound messages were missing or blank; sender avatars also fell back to initials even when Zalo provided an avatar.
- Root cause: The local `PersonalZcaChannel` normalizer only read a narrow set of top-level content/avatar fields. Some zca-js plain text events can carry text in nested objects such as `content.msg`, while avatar URLs may be protocol-relative (`//...`). Flutter Live Chat also only read `content` and `avatarUrl`.
- Fix summary: Added robust inbound content extraction for nested text fields while preserving rich preview JSON for link/file messages, normalized protocol-relative avatars, and extended Flutter Live Chat model parsing to accept `text`, `message`, `avatar`, `customerAvatar`, and related aliases.
- Rule: Zalo inbound payload handling must normalize both top-level and nested message fields, and UI model parsing should accept backend/agent aliases rather than assuming a single field name.
- Related files: `tools/alpha-crm/integration/zalo-bot-service/src/channels/personal-zca-channel.ts`, `tools/alpha-crm/lib/features/messaging/live_chat/providers/live_chat_provider.dart`, `tools/alpha-crm/lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`.

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
