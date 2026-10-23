---
name: build-and-release
description: |
  Build Alpha CRM cho Windows (ZIP kèm Zalo backend bundle + Node LTS runtime) và Android (APK),
  sau đó phát hành đồng thời lên GitHub Release và Backblaze B2 (cập nhật tự động trong app + link tải trên giaiphapsangtao.com/studio/crm).
  Trigger: khi user yêu cầu build, release, publish, xuất bản, deploy, hoặc tạo phiên bản mới cho Alpha CRM.
---

# Build & Release Alpha CRM

Skill này tự động hóa quy trình: kiểm tra pre-flight → build Windows (kèm bundle Zalo backend cục bộ + smoke-test `/health` & `/local/health`) + Android APK → commit version bump & tạo GitHub Release → đẩy bản tải + `version.json` lên Backblaze B2.

## ⚠️ Hai kênh phát hành — đừng nhầm

| Kênh | Phục vụ | Nguồn dữ liệu |
|------|---------|---------------|
| **Backblaze B2** | **Cập nhật tự động trong app (`AppUpdateService`) + Link tải trên web (`/studio/crm/subscription`)** | `crm-app/version.json` + `crm-app/releases/alpha-crm-windows.zip` + `crm-app/releases/alpha-crm-v<version>.apk` (bucket `alpha-studio`) |
| **GitHub Release** | **Lưu trữ bản phát hành theo tag `v<version>` trên repo `LittleKai/alpha-crm`** | Tag `v<version>` + Release Notes + Asset ZIP/APK đính kèm |

- Khác với các app đơn lẻ chỉ đóng gói Flutter, bản **Windows ZIP của Alpha CRM bắt buộc phải đi qua pipeline đóng gói backend Zalo cục bộ** (`alpha-studio-backend/scripts/release-to-b2.js`):
  1. Bundle `integration/zalo-bot-service` bằng `esbuild` thành 1 file `dist/server.cjs` đã minify (không lộ source `.ts`/`.js`, không kèm `.env` hay `.data` của máy build).
  2. Stage `better-sqlite3` native closure (`dereference: true`) kèm **Node LTS runtime được ghim (`v22.23.2`, ABI 127)** và prebuilt `better_sqlite3.node` khớp ABI.
  3. Tự động boot thử `node.exe dist/server.cjs` trên cổng tạm `8799`, kiểm tra cả `/health` lẫn `/local/health` (ép mở SQLite thật) trước khi nén ZIP.
  4. Giữ lại `build/alpha-crm-windows-v<version>-server.cjs.map` ngoài ZIP để giải mã stack trace khi cần.
- **Mỗi lần release chính thức phải đẩy đủ cả GitHub Release (kèm git branch + tag) và Backblaze B2.**

## Yêu cầu trước khi chạy

1. **Flutter** phải có trong PATH (`D:\3.Flutter\flutter\bin\flutter.bat`).
2. **Node.js & npm** phải có trong PATH (để bundle `zalo-bot-service` và chạy script đóng gói).
3. **Credential B2 & GITHUB_TOKEN** nằm trong `../../alpha-studio-backend/.env` (hoặc `.env` tại root `alpha-crm`):
   ```env
   GITHUB_TOKEN=<github pat>
   B2_ENDPOINT=https://s3.us-west-004.backblazeb2.com
   B2_REGION=us-west-004
   B2_ACCESS_KEY_ID=<b2 keyID>
   B2_SECRET_ACCESS_KEY=<b2 applicationKey>
   B2_BUCKET_NAME=alpha-studio
   CDN_BASE_URL=https://download.giaiphapsangtao.com/file/alpha-studio
   ```
   **Tuyệt đối không commit giá trị thật của `.env` và không in secret ra log.**
4. **Không còn tiến trình `alpha_crm.exe` hoặc `node.exe` của bản build trước** đang giữ khóa file trong `build/windows/`.
5. Máy phải là **Windows** (build Windows native + smoke-test `node.exe` cần chạy trên Windows).

## Quy trình release

### Bước 1: Xác nhận thông tin

⚡ **Quy tắc ngầm định (Zero-Prompting):** Khi user yêu cầu build hoặc release mà **không nói gì thêm / không chỉ định cụ thể**, MẶC ĐỊNH HIỂU LÀ **build release phiên bản mới**:
- **Version**: Tự động tăng version từ `pubspec.yaml` (`minor` nếu có tính năng mới, `patch` nếu chỉ sửa lỗi; `build number` `+N` luôn tự tăng `+1`).
- **Targets**: Mặc định cả hai (`windows,android`).
- **Loại release**: Bản chính thức (không phải prerelease).
- **Release notes**: Tự động thu thập toàn bộ thay đổi từ tag/commit release gần nhất đến `HEAD` theo góc nhìn người dùng tiếng Việt.
- **Git Push**: Tự động commit `pubspec.yaml` (`chore(release): bump version to <ver>+<build>`), push branch hiện tại (`git push origin <branch>`) và tag `v<version>` lên GitHub.
- **Kênh phát hành**: Đẩy đồng thời cả GitHub Release và Backblaze B2 mà không cần hỏi lại các lựa chọn mặc định.

Nếu user có yêu cầu tùy biến riêng, hỏi hoặc làm theo yêu cầu:
- **Version**: `patch`, `minor`, `major`, hoặc số cụ thể (ví dụ `0.2.2` / `v0.2.2`).
- **Release title**: tên hiển thị (mặc định: `Alpha CRM v<version>`).
- **Release notes**: nội dung phiên bản, tổng hợp **TOÀN BỘ** các commit kể từ lần release trước đó.

  #### Cách thu thập commit:
  1. Tìm tag release gần nhất hoặc commit bump version gần nhất:
     ```powershell
     rtk git tag --sort=-creatordate -n1
     rtk git log --grep="chore(release):" -n 5 --oneline
     ```
  2. Lấy tất cả commits từ mốc release trước đến `HEAD`:
     ```powershell
     rtk git log <mốc_trước>..HEAD --oneline
     ```
  3. BẮT BUỘC kiểm tra chi tiết nội dung thay đổi của từng commit: `rtk git log <mốc_trước>..HEAD -p` hoặc `rtk git show <commit_hash>` để nắm trọn vẹn từng tính năng, cải tiến Live Chat, Zalo/đa kênh, chiến dịch, và sửa lỗi giao diện.
  4. Nếu có uncommitted changes (`rtk git diff`), đọc kỹ các file thay đổi để commit trước hoặc đưa vào nội dung release.
  5. Tuyệt đối KHÔNG tóm tắt qua loa hay bỏ sót các chi tiết nhỏ.

  #### Cấu trúc release notes (viết bằng tiếng Việt):

  ```markdown
  ## Có gì mới trong phiên bản <version>

  ### ✨ Tính năng mới & Cải tiến
  - **Tên tính năng 1:**
    - Chi tiết cải tiến 1.1
    - Chi tiết cải tiến 1.2
  - **Tên tính năng 2:**
    - Chi tiết cải tiến 2.1

  ### 🐛 Sửa lỗi & Tinh chỉnh Giao diện
  - **Mô tả lỗi/tinh chỉnh 1:**
    - Chi tiết sửa lỗi 1.1
  ```

  #### Quy tắc viết nội dung:
  - ⚠️ **Bắt buộc**: Kiểm tra KỸ LƯỠNG và ĐẦY ĐỦ toàn bộ thay đổi trước khi soạn Release Notes.
  - Tuyệt đối **TRÁNH nhắc đến các phần kỹ thuật code**, tên file (`.dart`, `.ts`), tên class, provider, function hay refactor nội bộ.
  - Chỉ mô tả dưới **góc độ trải nghiệm người dùng** nhưng phải **CHI TIẾT và PHONG PHÚ** (dùng các nhóm gạch đầu dòng con để liệt kê rõ từng điểm cải tiến).
  - Gộp các commit cùng chủ đề thành một mục chính kèm các dòng mô tả chi tiết bên dưới.
  - Nếu một section không có nội dung, **bỏ section đó đi** (không để trống).

### Bước 2: Kiểm tra trước khi build (Pre-flight)

```powershell
# Kiểm tra trạng thái git
rtk git status

# Kiểm tra rào chắn tài liệu & symbol
D:\Dev\conda-envs\py312\python.exe .claude\guard_check.py

# Chạy phân tích tĩnh và unit test Flutter
flutter analyze
flutter test
```

Nếu có lỗi analyze, guard check hoặc test fail → xử lý hoặc báo user, **KHÔNG** tiếp tục build.

### Bước 3: Build (hoặc chạy gộp ở Bước 4)

Nếu muốn chạy bước build riêng (hoặc chỉ build local kiểm thử trước khi release):

```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\build-and-release\scripts\build.ps1" -Version "<patch|minor|major|x.y.z>" [-Targets "windows,android"] [-SkipVersionUpdate] [-SkipApkBuild]
```

Script `build.ps1` sẽ:
1. Kiểm tra và tự động dọn `build/windows` nếu `CMakeCache.txt` bị lệch generator platform (bẫy #20 trong `.claude/IMPORTANT_FIXED_BUGS.md`).
2. Gọi `alpha-studio-backend/scripts/release-to-b2.js <version> --no-upload` để:
   - Cập nhật `version: <semver>+<build>` trong `pubspec.yaml`
   - Build Android APK (`flutter build apk --release`)
   - Build Windows EXE (`flutter build windows --release`)
   - Bundle `integration/zalo-bot-service` (`npm.cmd run bundle` → `dist/server.cjs`)
   - Stage `dist/server.cjs`, native addon `better-sqlite3` (ABI 127) và Node LTS runtime được ghim (`v22.23.2`)
   - Chạy smoke-test thực tế: khởi động `node.exe dist/server.cjs` trên cổng `8799`, kiểm tra `/health` và `/local/health` (mở SQLite thật)
   - Đóng gói `build/alpha-crm-windows.zip` và lưu sourcemap `build/alpha-crm-windows-v<version>-server.cjs.map`
3. Gom toàn bộ artifacts chuẩn hóa vào `build/release/`:
   - `build/release/alpha-crm-windows.zip`
   - `build/release/alpha-crm-v<version>.apk`

### Bước 4: Release lên GitHub + Backblaze B2

Để tránh lỗi escape ký tự xuống dòng hoặc dấu nháy kép trên PowerShell, **nên ghi nội dung Release Notes ra một file tạm UTF-8** (ví dụ `build/release_notes.md`) rồi truyền đường dẫn file vào `-Notes`:

```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\build-and-release\scripts\release.ps1" -Version "<patch|minor|major|x.y.z>" -Title "Alpha CRM v<version>" -Notes "build\release_notes.md" [-Targets "windows,android"] [-SkipBuild] [-SkipB2] [-SkipGitHub] [-Prerelease]
```

Script `release.ps1` sẽ:
1. Chạy `build.ps1` (nếu không truyền `-SkipBuild`).
   Trước commit/push/upload, chỉ chọn artifact đúng `-Targets` và kiểm tra version + build nhúng trong EXE của ZIP hoặc APK (`aapt` từ Android SDK). File thiếu, sai version/build hoặc APK cũ qua `-SkipApkBuild` đều bị từ chối; tên file không phải bằng chứng version.
2. Tự động commit `pubspec.yaml` (`chore(release): bump version to <semver>+<build>`) nếu file này vừa được bump version, đảm bảo git tag luôn trỏ đúng vào commit mang version mới.
3. Push branch hiện tại lên `origin`.
4. Tạo git tag `v<version>` và push tag lên `origin`.
5. Tạo/cập nhật **GitHub Release** trên `LittleKai/alpha-crm` và đính kèm `alpha-crm-windows.zip` + `alpha-crm-v<version>.apk` (trừ khi truyền `-SkipGitHub`).
6. Gọi `upload-b2.ps1` để upload lên **Backblaze B2** (bucket `alpha-studio`):
   - `crm-app/releases/alpha-crm-windows.zip`
   - `crm-app/releases/alpha-crm-v<version>.apk`
   - `crm-app/version.json`: `platform_releases.windows/android` giữ metadata và assets theo version/build thật của từng nền tảng. Release một nền tảng giữ nguyên snapshot global cho app cũ/web; chỉ nâng global khi cả hai nền tảng cùng version/build. App mới đọc `platform_releases`; lần đầu chỉ có một nền tảng thì nền tảng còn lại không có update.
   - URL Windows tĩnh chỉ đổi khi global được nâng. Tự động dọn bản cũ, giữ 3 phiên bản mới nhất và mọi artifact đang được global/platform manifest tham chiếu.

> Nếu bước B2 fail sau khi GitHub Release đã tạo xong: **đừng tạo lại tag**, chỉ cần chạy lại riêng `upload-b2.ps1` (xem mục "Chạy từng bước thủ công").

### Bước 5: Xác nhận sau khi phát hành

Sau khi hoàn tất, hiển thị:
- Link đến GitHub Release (`https://github.com/LittleKai/alpha-crm/releases/tag/v<version>`)
- Link tải trực tiếp trên CDN (`alpha-crm-windows.zip` và `alpha-crm-v<version>.apk`)
- Link manifest `version.json`
- Danh sách artifacts đã upload + kích thước từng file

Kiểm tra nhanh manifest trên CDN:

```powershell
Invoke-RestMethod -Uri "https://download.giaiphapsangtao.com/file/alpha-studio/crm-app/version.json" | ConvertTo-Json -Depth 5
```

## Cấu trúc output

Local (`build/release/`):

```text
build/
├── alpha-crm-windows-v<version>-server.cjs.map   # Sourcemap giữ ngoài ZIP để giải mã crash log
└── release/
    ├── alpha-crm-v<version>.apk                  # Upload lên cả GitHub Release và B2
    └── alpha-crm-windows.zip                     # Upload lên cả GitHub Release và B2
```

Trên Backblaze B2 (bucket `alpha-studio`):

```text
crm-app/
├── version.json
└── releases/
    ├── alpha-crm-windows.zip
    └── alpha-crm-v<version>.apk
```

## Lưu ý quan trọng

- **Windows CMakeCache trap**: Nếu `flutter build windows` báo `CMake Error: Error: generator platform: x64 Does not match the platform used previously:`, đừng chỉ chạy `flutter clean` — xóa hẳn thư mục `build/windows` (`Remove-Item -Recurse -Force build\windows`). Script `build.ps1` đã tự động kiểm tra và xử lý lỗi này.
- **Không bao giờ đóng gói `.env` hoặc `.data` vào ZIP**: `release-to-b2.js` chỉ stage `dist/server.cjs`, native addon `better-sqlite3` và `node.exe` được ghim; sau khi chạy smoke-test trên cổng `8799`, file `.data/active-port.json` sinh ra trong lúc test sẽ bị xóa trước khi nén ZIP.
- **Dọn bản cũ tự động trên B2**: B2 giữ lại tối đa 3 phiên bản mới nhất trong `crm-app/releases/`, tự động xóa các bản APK cũ hơn để tiết kiệm dung lượng.

## Chạy từng bước thủ công

Chỉ build local (không đẩy lên GitHub/B2):

```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\build-and-release\scripts\build.ps1" -Version "patch"
```

Chỉ build riêng Windows hoặc riêng Android:

```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\build-and-release\scripts\build.ps1" -Version "none" -Targets "windows" -SkipVersionUpdate
powershell -ExecutionPolicy Bypass -File ".agents\skills\build-and-release\scripts\build.ps1" -Version "none" -Targets "android" -SkipVersionUpdate
```

Release khi đã có sẵn artifacts trong `build/release/`:

```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\build-and-release\scripts\release.ps1" -Version "<version>" -Title "Alpha CRM v<version>" -Notes "build\release_notes.md" -SkipBuild
```

Chỉ đẩy lại bản tải + `version.json` lên Backblaze B2:

```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\build-and-release\scripts\upload-b2.ps1" -Version "<version>" -Title "Alpha CRM v<version>" -Notes "build\release_notes.md" -ReleaseUrl "https://github.com/LittleKai/alpha-crm/releases/tag/v<version>"
```

Upload riêng một nền tảng: thêm `-Targets "windows"` hoặc `-Targets "android"`; nếu chỉ truyền `-ZipPath`/`-ApkPath`, chỉ nền tảng có path được chọn. Không tự lấy artifact từ thư mục build khác; mặc định không path/Targets yêu cầu đủ hai artifact chính xác trong `build/release/`.

Không tái dùng semver đã có trên B2 với build khác (hoặc manifest cũ chưa ghi build): phải tăng semver để tránh ghi đè artifact của snapshot trước. Retry cùng semver/build đã ghi trong manifest được phép.

Kiểm tra hồi quy local, không build/publish/network:

```powershell
node .agents/skills/build-and-release/scripts/release-safety.test.mjs
powershell -ExecutionPolicy Bypass -File .agents/skills/build-and-release/scripts/release-safety.test.ps1
flutter test test/app_update_service_test.dart --no-pub
```
