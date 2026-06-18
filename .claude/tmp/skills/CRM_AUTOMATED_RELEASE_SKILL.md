# 🚀 CRM Release Skill: Automated Building and Backblaze B2 Upload

This document details the automated skill to release new versions of the **Alpha CRM** client applications (Android APK & Windows ZIP package) to Backblaze B2 public cloud storage.

---

## Skill Overview

When a user requests to release, build, or deploy a new version of the Android or Windows client for `alpha-crm`:
1. You can automatically invoke the [release-to-b2.js](file:///d:/Dev/NodeJS/alpha-studio/alpha-studio-backend/scripts/release-to-b2.js) script.
2. The script compiles both desktop and mobile platforms (`flutter build apk` and `flutter build windows`).

3. It builds and stages the local Zalo backend (`tools/alpha-crm/integration/zalo-bot-service`) into the Windows release folder, including `dist/`, `node_modules/`, a bundled Windows `node.exe`, `.env.example`, and a `zalo-bot-service.cmd` launcher.
   - Important: `node_modules/zca-js` must be a real package directory from the npm registry, not a symlink/junction to a local reference repository. If it is a junction, the Windows ZIP may omit it and the packaged backend will exit with `ERR_MODULE_NOT_FOUND: Cannot find package 'zca-js'`.
4. It packages the Windows build (which contains necessary DLLs, data assets, and the staged local backend) into a single `.zip` distribution.
5. It reads B2 keys automatically from the backend `.env`.
6. It uploads the APK and ZIP packages to Backblaze B2.
7. It automatically updates the public metadata [version.json](https://cdn.giaiphapsangtao.com/file/alpha-studio/crm-app/version.json) on B2.

---

## How to Execute the Release

To run a release, navigate to the `alpha-studio-backend` folder and run `node scripts/release-to-b2.js` with the corresponding parameters.

### Command Format
```bash
node scripts/release-to-b2.js <bump_type_or_version> "<release_notes>" [--no-upload]
```

The optional `--no-upload` flag (alias `--local`) builds the app + bundles the backend + stages + zips **locally only**, then stops before uploading to B2 (no B2 credentials required). The flag may appear in any position.

### Options

1. **Auto-increment version (patch)**:
   Increments the patch version (e.g., `1.0.0+1` -> `1.0.1+2`), builds, packages, uploads, and updates B2.
   ```bash
   node scripts/release-to-b2.js patch "Bản vá sửa lỗi kết nối Zalo Personal"
   ```

2. **Auto-increment version (minor)**:
   Increments the minor version (e.g., `1.0.3+12` -> `1.1.0+13`), builds, packages, uploads, and updates B2.
   ```bash
   node scripts/release-to-b2.js minor "Bản cập nhật tính năng đồng bộ danh bạ nâng cao"
   ```

3. **Specify a custom version**:
   Sets the exact semver version (e.g., `1.0.5+build_num_auto_incremented`), builds, packages, uploads, and updates B2.
   ```bash
   node scripts/release-to-b2.js 1.0.5 "Phát hành phiên bản 1.0.5 với hiệu năng cải tiến"
   ```

4. **Build & Upload Current Version (No Bump)**:
   Rebuilds and re-uploads the exact current version defined in `pubspec.yaml` without changing the version string (default release notes will be used).
   ```bash
   node scripts/release-to-b2.js
   ```

5. **Release Current Version with Custom Notes (No Bump)**:
   Rebuilds and re-uploads the exact current version defined in `pubspec.yaml` without changing the version string, while using a custom release notes string. You can pass `none`, `skip`, `current`, or `nobump` as the first argument.
   ```bash
   node scripts/release-to-b2.js none "Bản cập nhật minor CRM tự động và đồng bộ lên B2"
   ```

6. **Local build only — app + backend, NO B2 upload** (`--no-upload` / `--local`):
   Builds the Flutter Windows app, bundles + stages the local Zalo backend, zips to `tools/alpha-crm/build/alpha-crm-windows.zip`, then stops (no upload, no B2 credentials needed). Combine with any bump option, or use alone to keep the current version.
   ```bash
   node scripts/release-to-b2.js --no-upload
   node scripts/release-to-b2.js patch "Thử nghiệm cục bộ" --no-upload
   ```

---

## Script Architecture

The script performs the following fully-automated steps:
- **`dotenv.config()`**: Seamlessly loads `B2_*` credentials from the backend `.env` file.
- **Pubspec Parser**: Uses RegExp to parse, calculate, and increment the `version: major.minor.patch+build` line in `tools/alpha-crm/pubspec.yaml`.
- **Flutter Builders**: Runs child processes to build production release binaries for Android (APK) and Windows.

- **Local Zalo Backend Builder**: Runs `npm.cmd run build` in `tools/alpha-crm/integration/zalo-bot-service`, then stages the compiled backend, dependencies, `.env.example`, and bundled Node runtime into the Windows release folder. The public ZIP must never include build-machine `.env` or `.data` secrets.
- **Backend Dependency Guard**: Before zipping, verify `tools/alpha-crm/integration/zalo-bot-service/node_modules/zca-js` and the staged `build/windows/x64/runner/Release/zalo-bot-service/node_modules/zca-js` are real directories, not symlinks/junctions. If `package-lock.json` resolves `node_modules/zca-js` to a local path or marks it with `"link": true`, run `npm.cmd install zca-js@2.1.2 --save` in `tools/alpha-crm/integration/zalo-bot-service`, rebuild the backend, and restage `node_modules`.
- **Windows Packager**: Flutter Windows applications generate multiple DLLs and data assets under the Release folder. The script also places `zalo-bot-service.cmd` beside `Alpha CRM.exe` so the desktop app can auto-start the local backend in production. It then uses PowerShell's native `Compress-Archive` to package the folder into `alpha-crm-windows.zip` to ensure it is runnable out-of-the-box for users.
- **Windows ZIP Verification**: After zipping, inspect the ZIP and confirm it contains `zalo-bot-service/node_modules/zca-js/package.json`. Then start the packaged backend with the bundled `zalo-bot-service/node.exe` on a temporary local port and confirm `/health` returns HTTP 200 before uploading to B2.
- **B2 Client**: Utilizes the AWS SDK S3 client to perform direct file streams to the B2 bucket.
- **Metadata Update**: Downloads, updates, and re-uploads `crm-app/version.json` in the B2 bucket to match the new download URLs and metadata, allowing both the Flutter app update-checker and the studio website to dynamically receive the new links!
