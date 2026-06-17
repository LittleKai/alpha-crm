# VocabFlip Release Skill: Automated Building and Backblaze B2 Upload

This document details the automated skill to release new versions of the **VocabFlip** client applications (Android APK, Windows ZIP package, and embedded Web build) to Backblaze B2 public cloud storage.

---

## Skill Overview

When a user requests to release, build, deploy, or publish a new version of `tools/vocabflip`:
1. Run the [release-vocabflip-to-b2.js](file:///d:/Dev/NodeJS/alpha-studio/alpha-studio-backend/scripts/release-vocabflip-to-b2.js) script from `alpha-studio-backend`.
2. The script optionally bumps `tools/vocabflip/pubspec.yaml`.
3. It builds Android with `flutter build apk --release`.
4. It builds Windows with `flutter build windows --release` and packages the Release folder into a runnable ZIP.
5. It builds Flutter Web with `--base-href "/vocab/"` and copies `build/web` to `alpha-studio/public/vocab`.
6. It reads B2 credentials from `alpha-studio-backend/.env`.
7. It uploads APK and Windows ZIP artifacts to Backblaze B2 under `vocabflip-app/releases/`.
8. It updates public metadata at `https://cdn.giaiphapsangtao.com/file/alpha-studio/vocabflip-app/version.json`.

VocabFlip does not require a monthly subscription plan. The Studio route `/studio/vocab` reads this public metadata to show direct Android and Windows download links.

---

## How to Execute the Release

Run from `alpha-studio-backend`:

```bash
node scripts/release-vocabflip-to-b2.js <bump_type_or_version> "<release_notes>"
```

### Options

1. **Patch release**
   ```bash
   node scripts/release-vocabflip-to-b2.js patch "Fix sync and dictionary lookup issues"
   ```

2. **Minor release**
   ```bash
   node scripts/release-vocabflip-to-b2.js minor "Add deck study improvements"
   ```

3. **Major release**
   ```bash
   node scripts/release-vocabflip-to-b2.js major "New VocabFlip desktop release"
   ```

4. **Specific version**
   ```bash
   node scripts/release-vocabflip-to-b2.js 1.2.0 "VocabFlip 1.2.0 release"
   ```

5. **Rebuild current version without bump**
   ```bash
   node scripts/release-vocabflip-to-b2.js
   ```

6. **Rebuild current version with custom notes**
   ```bash
   node scripts/release-vocabflip-to-b2.js none "Rebuild current VocabFlip release and refresh B2 metadata"
   ```

---

## Script Architecture

The script performs these steps:
- **Env loading:** Uses `dotenv` to load `B2_*` and `CDN_BASE_URL` from `alpha-studio-backend/.env`.
- **Version handling:** Parses and optionally updates the `version: major.minor.patch+build` line in `tools/vocabflip/pubspec.yaml`.
- **Flutter builders:** Runs production builds for Android, Windows, and Web.
- **Web publisher:** Clears and replaces `alpha-studio/public/vocab` with the new Flutter Web build.
- **Windows packager:** Uses PowerShell `Compress-Archive` to package the Windows Release folder into `vocabflip-windows.zip`.
- **B2 uploader:** Uploads `vocabflip-v{version}.apk` and `vocabflip-windows.zip`.
- **Metadata writer:** Writes `vocabflip-app/version.json` using a GitHub-release-compatible JSON shape: `tag_name`, `name`, `body`, `published_at`, and `assets[]`.
- **Retention cleanup:** Keeps the three newest VocabFlip versions on B2 and deletes older APK/ZIP files.

---

## Expected Public URLs

After a successful release:

```text
https://cdn.giaiphapsangtao.com/file/alpha-studio/vocabflip-app/version.json
https://cdn.giaiphapsangtao.com/file/alpha-studio/vocabflip-app/releases/vocabflip-v{version}.apk
https://cdn.giaiphapsangtao.com/file/alpha-studio/vocabflip-app/releases/vocabflip-windows.zip
```

The React route `/studio/vocab` and VocabFlip in-app updater both depend on `vocabflip-app/version.json`.
