# Live Chat Media And Message Actions Design

## Goal

Make Live Chat reactions, recall, message search, media viewing, and downloads reliable on Windows, Android, and Web while keeping the Zalo session and durable media cache on the bridge host.

## Architecture

The local Zalo bridge downloads inbound and outbound image, file, and video attachments into its managed media cache. Message records retain provider identifiers and attachment metadata, while the bridge exposes media content through HTTP endpoints that support normal downloads and byte ranges for video playback.

Flutter treats the bridge as the media source. It uses the provider message identifier for Zalo actions, updates recall state only after a successful provider response, hides reactions on outbound messages, and renders normalized image, file, and video attachment models.

## Media Lifecycle

- Cache media for 90 days by default.
- Limit cache usage to 20 GB by default.
- Remove oldest files first when either limit is exceeded.
- Track `pending`, `ready`, and `failed` download states.
- Serve cached media with safe content disposition and MIME headers.
- Support HTTP `Range` requests for video seeking.
- Export downloads to the configured folder on Windows and Android.
- On Web, use browser downloads without opening a new tab; a browser-granted directory may be used where supported.

## Message Actions

- Reaction and recall use `zaloMsgId` or `providerMessageId`, never the CRM/database row ID.
- Reaction controls are absent for outbound messages.
- Recall calls the active API path and only reloads or marks the message recalled after success.
- Bridge failures return actionable errors and are logged at the API boundary.

## Search

Search is scoped to the open conversation. The custom dialog shows loading, errors, empty state, count, message preview, sender, and timestamp. Selecting a result loads messages around it, closes the dialog, scrolls to the message, and highlights it temporarily.

## Video

Video attachments have a distinct normalized kind, thumbnail, media URL, filename, MIME type, duration, and cache status. Selecting a video opens a Flutter page with play/pause, seek, full-screen support supplied by the player, and download.

## Settings

Settings include the download folder, cache age, cache size, current cache usage, and a clear-cache action. Defaults are Downloads, 90 days, and 20 GB.

## Verification

Backend tests cover cache metadata, cleanup ordering, media responses including ranges, and provider-ID action lookup. Flutter tests cover safe URL/name decoding, video normalization, outbound reaction hiding, provider-ID dispatch, recall success ordering, search state, and download destination behavior.
