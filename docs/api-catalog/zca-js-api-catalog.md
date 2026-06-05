# zca-js API Catalog

**Last Updated:** 2026-06-05T16:04:23+07:00

This catalog summarizes the usable public API surface from the local reference repository:

```text
D:\Dev\2.reference_pj\Zalo-ref\zca-js
```

Source files checked:

- `src/index.ts` - public package exports.
- `src/zalo.ts` - login facade.
- `src/apis.ts` - generated `API` facade.
- `src/apis/listen.ts` - realtime listener methods and events.
- `src/apis/*.ts` - endpoint wrappers behind `API`.

## Scope and Counts

`zca-js` is an unofficial personal Zalo Web client. It is not Zalo OA/OpenAPI. In Alpha CRM, keep it behind the Node backend service; Flutter must not store cookies, IMEI, user-agent, QR artifacts, or any other account secret.

Public surface snapshot:

| Surface | Count | Notes |
| --- | ---: | --- |
| `Zalo` login facade methods | 2 | `login`, `loginQR` return an authenticated `API` instance. |
| `API` public members | 148 | `zpwServiceMap`, `listener`, and 146 callable API methods. |
| `api.listener` public methods | 9 | Includes connection control, deprecated callbacks, low-level WebSocket send, and old-message/reaction requests. |
| `api.listener` event names | 16 | EventEmitter events for messages, reactions, typing, seen/delivered states, friend/group events, uploads, and connection state. |

Important integration notes:

- File-path image/GIF sending requires a backend `imageMetadataGetter`; do not add that dependency to Flutter.
- Many friend/group/bulk-action methods are high-risk personal-account operations. Keep rate limits, cooldowns, operator confirmation, and stop conditions in the backend.
- The currently installed Alpha CRM backend dependency is `zca-js@^2.1.2`; re-check this catalog against the local reference repo if the package version changes.
- For Alpha CRM gap planning, see also `docs/api-catalog/zca-js-unintegrated-apis.md`.

## Login and Session Facade

These are used before any endpoint call:

- `new Zalo(options)` - creates a client facade. Useful options include logging, proxy/fetch agent, and `imageMetadataGetter`.
- `zalo.login(credentials)` - login with saved cookie, IMEI, user agent, and optional language.
- `zalo.loginQR(options, callback)` - login through QR flow; callback can return QR/login-info events and final credentials.

## API Classification

The following 146 callable methods are available on the authenticated `API` object returned by `login` or `loginQR`.

### 1. Core Session, Settings, and Escape Hatch - 11

Use for backend health, identity, service metadata, global settings, language, active status, and custom endpoint experiments.

- `getContext`
- `getCookie`
- `getOwnId`
- `keepAlive`
- `fetchAccountInfo`
- `getBizAccount`
- `getSettings`
- `updateSettings`
- `updateLang`
- `updateActiveStatus`
- `custom`

Related non-callable public member:

- `zpwServiceMap` - service URL map returned by Zalo login metadata.

### 2. Account Profile, Avatar, and QR - 9

Use for profile display/update and account avatar workflows.

- `changeAccountAvatar`
- `deleteAvatar`
- `getAvatarList`
- `getAvatarUrlProfile`
- `getFullAvatar`
- `getQR`
- `reuseAvatar`
- `updateProfile`
- `updateProfileBio`

### 3. Friends, Contact Discovery, and CRM Lookup - 23

Use for customer lookup, friend lists, friend request workflows, aliases, online state, and blocking.

- `acceptFriendRequest`
- `rejectFriendRequest`
- `sendFriendRequest`
- `undoFriendRequest`
- `removeFriend`
- `blockUser`
- `unblockUser`
- `blockViewFeed`
- `findUser`
- `findUserByUsername`
- `getAllFriends`
- `getCloseFriends`
- `getFriendOnlines`
- `getFriendRecommendations`
- `getFriendRequestStatus`
- `getMultiUsersByPhones`
- `getSentFriendRequest`
- `getRelatedFriendGroup`
- `changeFriendAlias`
- `removeFriendAlias`
- `getAliasList`
- `lastOnline`
- `getUserInfo`

### 4. Messaging, Media, Reactions, and Reports - 22

Use for direct/group sends, rich media, link parsing, delivery/seen/typing events, reactions, undo/delete, and abuse reports.

- `sendMessage`
- `sendLink`
- `sendCard`
- `sendBankCard`
- `sendSticker`
- `sendVideo`
- `sendVoice`
- `forwardMessage`
- `sendTypingEvent`
- `sendSeenEvent`
- `sendDeliveredEvent`
- `addReaction`
- `undo`
- `deleteMessage`
- `deleteChat`
- `parseLink`
- `sendReport`
- `getStickers`
- `searchSticker`
- `getStickerCategoryDetail`
- `getStickersDetail`
- `uploadAttachment`

### 5. Conversation State, Labels, Pins, Mute, Archive, and TTL - 17

Use for inbox organization and conversation lifecycle state.

- `addUnreadMark`
- `removeUnreadMark`
- `getUnreadMark`
- `setMute`
- `getMute`
- `setPinnedConversations`
- `getPinConversations`
- `getHiddenConversations`
- `setHiddenConversations`
- `updateHiddenConversPin`
- `resetHiddenConversPin`
- `getArchivedChatList`
- `updateArchivedChatList`
- `getAutoDeleteChat`
- `updateAutoDeleteChat`
- `getLabels`
- `updateLabels`

### 6. Quick Messages and Auto Reply - 8

Use for canned replies and account-side auto-reply rules.

- `addQuickMessage`
- `getQuickMessageList`
- `updateQuickMessage`
- `removeQuickMessage`
- `createAutoReply`
- `getAutoReplyList`
- `updateAutoReply`
- `deleteAutoReply`

### 7. Groups, Members, Links, Invite Boxes, and Community - 31

Use for group inventory, membership operations, invite links, moderation, deputy/owner actions, pending member review, and community upgrade.

- `createGroup`
- `getAllGroups`
- `getGroupInfo`
- `getGroupMembersInfo`
- `getGroupChatHistory`
- `addUserToGroup`
- `inviteUserToGroups`
- `removeUserFromGroup`
- `leaveGroup`
- `disperseGroup`
- `changeGroupName`
- `changeGroupAvatar`
- `changeGroupOwner`
- `addGroupDeputy`
- `removeGroupDeputy`
- `addGroupBlockedMember`
- `removeGroupBlockedMember`
- `getGroupBlockedMember`
- `getPendingGroupMembers`
- `reviewPendingMemberRequest`
- `enableGroupLink`
- `disableGroupLink`
- `getGroupLinkInfo`
- `getGroupLinkDetail`
- `joinGroupLink`
- `getGroupInviteBoxList`
- `getGroupInviteBoxInfo`
- `joinGroupInviteBox`
- `deleteGroupInviteBox`
- `upgradeGroupToCommunity`
- `updateGroupSettings`

### 8. Polls, Notes, Reminders, and Boards - 16

Use for collaborative group artifacts and social board/reminder data.

- `createPoll`
- `addPollOptions`
- `votePoll`
- `lockPoll`
- `sharePoll`
- `getPollDetail`
- `createNote`
- `editNote`
- `createReminder`
- `getReminder`
- `getListReminder`
- `editReminder`
- `removeReminder`
- `getReminderResponses`
- `getListBoard`
- `getFriendBoardList`

### 9. Catalog, Product Catalog, and Shop Media - 9

Use for Zalo catalog/shop-like product data and product image upload.

- `createCatalog`
- `getCatalogList`
- `updateCatalog`
- `deleteCatalog`
- `createProductCatalog`
- `getProductCatalogList`
- `updateProductCatalog`
- `deleteProductCatalog`
- `uploadProductPhoto`

## Realtime Listener

`api.listener` is a public `Listener` instance and should be started from the backend only.

Public listener methods:

- `onConnected(cb)` - deprecated callback helper; prefer `listener.on("connected", cb)`.
- `onClosed(cb)` - deprecated callback helper; prefer `listener.on("closed", cb)`.
- `onError(cb)` - deprecated callback helper; prefer `listener.on("error", cb)`.
- `onMessage(cb)` - deprecated callback helper; prefer `listener.on("message", cb)`.
- `start({ retryOnClose })`
- `stop()`
- `sendWs(payload, requireId = true)` - low-level WebSocket send; use only when wrapping unsupported socket flows.
- `requestOldMessages(threadType, lastMsgId = null)`
- `requestOldReactions(threadType, lastMsgId = null)`

Listener event names:

- `connected`
- `disconnected`
- `closed`
- `error`
- `typing`
- `message`
- `old_messages`
- `seen_messages`
- `delivered_messages`
- `reaction`
- `old_reactions`
- `upload_attachment`
- `undo`
- `friend_event`
- `group_event`
- `cipher_key`

## Public Types and Enums Worth Importing

`src/index.ts` re-exports errors, models, `Zalo`, context/session option types, API response/payload types, and selected enums.

Common imports for Alpha CRM backend work:

- `Zalo`
- `ThreadType`
- `TextStyle`
- `Urgency`
- `CloseReason`
- `LoginQRCallbackEventType`
- `ReportReason`
- `MuteAction`
- `MuteDuration`
- `ChatTTL`
- `UpdateSettingsType`
- `UpdateLangAvailableLanguages`
- `ReviewPendingMemberRequestStatus`
- `FriendRecommendationsType`

Common type families:

- Context/session: `ContextSession`, `ContextBase`, `Options`, `ZPWServiceMap`, `ImageMetadataGetter`, `ImageMetadataGetterResponse`.
- Messaging: `MessageContent`, `SendMessageQuote`, `SendMessageResponse`, `SendMessageResult`, `Mention`, `Style`.
- Attachments: `FileData`, `ImageData`, `UploadAttachmentResponse`, `UploadAttachmentType`.
- Profiles/friends/groups: `ProfileInfo`, `UserInfoResponse`, `GroupInfoResponse`, `GroupMemberProfile`.
- Catalogs/reminders/polls/settings: payload and response types exported beside each API wrapper.

## Alpha CRM Use Guidance

Recommended backend-first mapping:

- Live Chat: `listener`, `sendMessage`, `sendSeenEvent`, `sendDeliveredEvent`, `sendTypingEvent`, `getUserInfo`, `getGroupInfo`, `getGroupMembersInfo`, `uploadAttachment`.
- Bulk Messaging: `sendMessage`, `sendLink`, `sendCard`, `sendSticker`, `sendVideo`, `sendVoice`, with backend cooldowns and per-account limits.
- Customer Enrichment: `getMultiUsersByPhones`, `findUser`, `findUserByUsername`, `getUserInfo`, `getAllFriends`, `getAliasList`, `changeFriendAlias`.
- Friend Operations: `sendFriendRequest`, `acceptFriendRequest`, `rejectFriendRequest`, `undoFriendRequest`, `removeFriend`, `blockUser`, `unblockUser`.
- Group Operations: `getAllGroups`, `getGroupInfo`, `getGroupMembersInfo`, `createGroup`, `addUserToGroup`, `inviteUserToGroups`, `joinGroupLink`, `leaveGroup`, `reviewPendingMemberRequest`.
- Operator Productivity: `addQuickMessage`, `getQuickMessageList`, `updateQuickMessage`, `removeQuickMessage`, `createReminder`, `createNote`, `createPoll`.

Operations requiring extra safeguards before enabling in user-facing automation:

- Mass sending, mass friend requests, group invites, group joins, and member scans.
- Group moderation actions such as kicking members, changing owner/deputies, dispersing groups, and blocking members.
- Account/profile mutation such as avatar, profile, bio, language, and settings changes.
- Low-level `custom` and `listener.sendWs` calls.
