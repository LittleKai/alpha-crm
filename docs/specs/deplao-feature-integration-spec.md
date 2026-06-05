# Deplao Feature Integration Spec

**Date:** 2026-06-03
**Target:** Alpha CRM (`tools/alpha-crm`)
**Reference:** Deplao App (`D:\Dev\2.reference_pj\Zalo-ref\Deplao-App`)

## Objective

Tich hop cac tinh nang phu hop tu Deplao vao Alpha CRM ma khong sao chep mo hinh Electron/BrowserView cua Deplao. Alpha CRM tiep tuc giu kien truc Flutter + Riverpod + local Zalo bot service.

## Implemented Features

### 1. Quick Reply Shortcuts

Nguoi dung co the tao tin mau nhanh voi shortcut va dung trong Live Chat:

- Shortcut dang so: `/1`, `/2`, ... lay theo thu tu danh sach tin mau quick.
- Shortcut dat ten: `/hello`, `/chao`, ... khop khong phan biet hoa thuong.
- Neu text khong phai shortcut hop le thi gui nhu tin nhan binh thuong.
- Live Chat co quick reply strip hien toi da 8 nut de chen nhanh noi dung vao o nhap.

Files:

- `lib/features/messaging/live_chat/utils/quick_reply_shortcuts.dart`
- `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`
- `lib/features/content/presentation/screens/content_templates_screen.dart`
- `lib/features/content/providers/templates_provider.dart`
- `lib/mock/mock_messages.dart`
- `test/quick_reply_shortcuts_test.dart`

### 2. Quick Template Metadata

`MessageTemplate` va template provider da them metadata:

- `shortcut`
- `isQuick`

Khi tao tin mau moi trong man hinh Tin mau nhanh, CRM luu shortcut va gan template do la quick template de dung ngay trong Live Chat.

### 3. App Lock

Da them khoa ung dung local:

- Nut khoa o sidebar footer.
- Overlay khoa ung dung tren toan bo app.
- Neu chua co mat khau, lan khoa dau tien yeu cau tao mat khau.
- Mat khau duoc bam SHA-256 lap voi salt local, luu trong application support directory.
- Co co che khoa lai khi startup neu da co mat khau va `lockOnStartup`.

Files:

- `lib/features/security/providers/app_lock_provider.dart`
- `lib/features/security/presentation/app_lock_overlay.dart`
- `lib/features/security/utils/app_lock_crypto.dart`
- `lib/app/shell/app_sidebar.dart`
- `lib/main.dart`
- `test/app_lock_crypto_test.dart`
- `pubspec.yaml`

### 4. Per-Account Zalo Bot Settings

Da them cau hinh rieng theo tai khoan Zalo trong Settings:

- Proxy rieng theo account.
- Toggle `blockSeen`.
- Toggle `blockTyping`.
- Local bot service luu metadata vao `account-settings.json` cung thu muc credential.
- Khi fetch accounts, settings duoc tra ve lai cho Flutter UI.
- Khi xoa account, settings tuong ung cung duoc xoa.

Files:

- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/zalo_integration/data/zalo_integration_api.dart`
- `lib/features/zalo_integration/providers/zalo_integration_provider.dart`
- `integration/zalo-bot-service/src/channels/types.ts`
- `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- `integration/zalo-bot-service/src/zalo.ts`
- `integration/zalo-bot-service/src/server.ts`

## Deliberately Not Ported As-Is

### Electron BrowserView Shell

Khong port BrowserView cua Deplao vi Alpha CRM la Flutter app, Zalo automation duoc tach qua local bot service.

### Network Hook For Seen/Typing

`blockSeen` va `blockTyping` hien duoc luu nhu metadata theo account. Chua hook truc tiep vao request Zalo vi adapter hien tai la `zca-js`/Node service, khong co cung BrowserView network interception surface nhu Deplao. Reviewer can xem tiep kha nang enforce o adapter neu co API chinh thuc hoac cach lam on dinh.

### Download Panel

Deplao co UX download/update rieng, nhung Alpha CRM da co update provider/update card va packaging Windows rieng. Khong them download manager moi de tranh trung lap.

## Review Checklist

- Quick reply:
  - Tao tin mau co shortcut `/hello`, vao Live Chat nhap `/hello`, noi dung gui ra phai la template content.
  - Tao nhieu quick templates, nhap `/1`, `/2` phai map dung thu tu hien thi.
  - Tin nhan binh thuong bat dau khong phai shortcut hop le van gui raw text.

- App lock:
  - Bam nut khoa khi chua co mat khau phai mo form tao mat khau.
  - Mat khau khong khop phai bao loi.
  - Mat khau dung mo khoa duoc, mat khau sai khong mo khoa.
  - Restart app native phai load lai trang thai khoa neu da co password va lock-on-startup.

- Account settings:
  - Settings hien nut cau hinh tung account.
  - Luu proxy/blockSeen/blockTyping thanh cong phai reload account list va giu lai gia tri.
  - Xoa account phai xoa metadata settings cua account do.

- Bot service:
  - `POST /api/zalo/accounts/settings` validate `accountId`.
  - `GET /api/zalo/accounts` tra `settings` theo account.
  - TypeScript build pass.

## Known Risks And Follow-Up Bugs

- App lock la UX gate local, khong ma hoa du lieu CRM at rest.
- App lock provider dung local file storage, nen reviewer can danh gia them neu can secure storage tren mobile.
- Proxy/blockSeen/blockTyping chua co enforcement trong `PersonalZcaChannel`; hien moi la luu cau hinh va UI.
- `flutter analyze` cua repo van con nhieu lint info hien huu ngoai pham vi: `withOpacity`, deprecated dropdown `value`, `avoid_print`, deprecated web `dart:html`. Khong con error moi tu phan tich hop.

## Verification

Da chay:

```bash
flutter test test\quick_reply_shortcuts_test.dart
flutter test test\app_lock_crypto_test.dart
flutter test
npm.cmd run build
flutter analyze
```

Ket qua:

- Focused quick reply tests: pass.
- Focused app lock crypto test: pass.
- Full Flutter test suite: pass.
- Zalo bot service TypeScript build: pass.
- Flutter analyze: khong con error, nhung command van exit code 1 do 63 lint info hien huu trong repo.
