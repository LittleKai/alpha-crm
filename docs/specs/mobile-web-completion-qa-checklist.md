# QA-1 Checklist — Mobile/Web Realtime E2E (manual execution required)

> Companion to `mobile-web-completion-tasklist.md` (QA-1). Requires a live Windows desktop
> running the agent, a real paired Zalo account, Chrome, and an Android device/emulator —
> none of which are available in the coding environment, so this matrix must be run manually.
> Check items off as they pass; note the actual measured latency next to each `<Ns` target.

## Setup

- [ ] Windows desktop running `alpha-crm` with the Zalo bridge connected to a live Zalo account.
- [ ] Chrome tab open to the web build, signed in to the same CRM account.
- [ ] Android APK installed, signed in to the same CRM account, paired via QR (device_pairing_screen).
- [ ] Backend deployed build includes Sprint 1–4 changes (`crmEventHub`, long-poll, outbound reporting, transport mode, SSE client, rate limiter).

## Matrix: (Windows desktop + agent) × (Chrome web, Android APK)

| Scenario | Target | Chrome web | Android APK |
|---|---|---|---|
| Inbound Zalo message → client shows it | <1s | [ ] ___s | [ ] ___s |
| Send from client → Zalo delivers it | <3s | [ ] ___s | [ ] ___s |
| Kill the agent process → client shows offline banner + composer locks | ≤90s | [ ] ___s | [ ] ___s |
| Restart the agent → banner clears, composer unlocks, no manual refresh | auto | [ ] pass/fail | [ ] pass/fail |
| Zalo session expires on desktop (force logout) → client shows the *expired* banner, distinct from *offline* | distinct copy | [ ] pass/fail | [ ] pass/fail |
| Pairing: mobile scans desktop QR → desktop shows "paired" | <2s | n/a | [ ] ___s |

## Multi-client sync

- [ ] 2 Chrome tabs + 1 Android device, same account, same conversation open on all three.
- [ ] Send from the Android device → both Chrome tabs update without a manual refresh.
- [ ] Send from the desktop UI (local bridge) → both Chrome tabs and the Android device update.

## Light load

- [ ] Hold 1 user's SSE connection open (Chrome tab idle, screen unlocked) for 30 minutes.
- [ ] Confirm backend memory (`alpha-studio-backend` Fly.io process) does not grow monotonically over the window — a few MB of GC sawtooth is expected, a steady climb is not.
- [ ] Confirm the connection is still alive after 30 minutes (no silent drop — check `sseConnected` state client-side, or `: ping` comments arriving every 25s in a raw `curl -N` session).

## Known, accepted gaps (do not fail QA-1 on these — see tasklist §4)

- Cloud message history is outbound-only for content; inbound is metadata-only by design.
- No delivered/seen receipts on mobile/web.
- No "typing…" indicator from Zalo → mobile/web.
- Attachment sends from mobile/web are out of scope (local file path only, per BE-6 DoD note).
