# SQLite Encryption-at-Rest — Proposal (not yet implemented)

Status: **proposal only**. The credential-file encryption (Zalo
`credentials_*.json`, `account-settings.json`) and the CRM token are already
encrypted at rest (see `secure-store.ts` / `flutter_secure_storage`). This doc
covers the remaining gap: the message databases.

## Scope

Two SQLite databases hold message content in plaintext today:

| DB | Engine | Location | Sensitive content |
|----|--------|----------|-------------------|
| `live-chat.sqlite` | `better-sqlite3` (Node backend) | `dataRoot/live-chat/` | message bodies, attachments metadata, contact names |
| `alpha_crm_local_v1.db` | `sqflite` / `sqflite_common_ffi` (Flutter) | app support dir | cached conversations/messages, drafts, offline contact cache |

## Options

### Option A — Full-database encryption (SQLCipher)
- Backend: replace `better-sqlite3` with `better-sqlite3-multiple-ciphers`
  (drop-in, supports `PRAGMA key`). Flutter: replace `sqflite_common_ffi` with
  `sqflite_sqlcipher` / `sqlcipher_flutter_libs`.
- Key supplied via `PRAGMA key` at open, sourced from the same machine-bound
  key already used by `secure-store.ts` (backend) and `flutter_secure_storage`
  (Flutter).
- **Pros:** transparent, encrypts everything including indexes; minimal app code.
- **Cons:** native dependency swap. The Windows release stages a native
  `better-sqlite3` runtime closure — switching modules means re-validating that
  closure and the minified bundle. A **one-time migration** is required to
  re-encrypt existing plaintext DBs (`ATTACH` + `sqlcipher_export`), with a
  fallback for users whose machine key is unavailable. Highest blast radius.

### Option B — Field-level column encryption (no engine change)
- Keep both engines. AES-256-GCM only the sensitive columns
  (`messages.content`, `messages.attachments`, conversation display names) using
  the existing machine key. Store ciphertext with the same magic-header format
  as `secure-store.ts` so reads transparently fall back to plaintext rows.
- **Pros:** no native dependency change, no bundle re-validation, incremental
  migration (encrypt on next write).
- **Cons:** touches every read/write path of the live-chat store and the Flutter
  cache; indexes / `LIKE` search over encrypted columns break (search would need
  decryption in app code); easy to miss a column.

## Recommendation

Defer until there is a concrete threat model that justifies the cost. If/when
implemented, prefer **Option A (SQLCipher)** for completeness, gated behind:
1. A migration that re-encrypts in place with verified rollback.
2. Release-bundle re-validation of the new native closure.
3. The same machine-key source already in `secure-store.ts`, so key management
   stays uniform across credentials, token, and DB.

Field-level (Option B) is the right choice only if the native bundle must not
change and full-text search on message bodies is not required.
