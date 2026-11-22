# Alpha CRM - Agent Router (Codex, Antigravity & Claude Code)

Ứng dụng CRM đa nền tảng Flutter (Windows desktop + Android) kèm local Zalo bot service (`integration/zalo-bot-service`) và đồng bộ Alpha Studio cloud.

Text files are UTF-8 without BOM. In PowerShell read them with
`Get-Content -Encoding UTF8`; plain `Get-Content` under `-NoProfile` garbles
Vietnamese, and writing that text back corrupts the file.

## 📖 ĐỌC THEO VIỆC

Luôn đọc `.claude/PROJECT_SUMMARY.md` trước mọi việc (trạng thái hiện tại — đọc nó, đừng đọc lại toàn bộ code).

| Task | Đọc bắt buộc |
|---|---|
| Live Chat, Zalo, SSE, SQLite, Windows lifecycle/updater | `.claude/IMPORTANT_FIXED_BUGS.md` (đọc Bảng bẫy trước, rồi mục liên quan) |
| Flutter/provider/service/crypto, thêm kênh hoặc sửa cơ chế | `.claude/CONVENTIONS.md` |
| Quy tắc Zalo cá nhân, đóng gói release chi tiết | `.claude/PROJECT_RULES.md` |
| Trước khi giao / phát hành artifact | `.claude/SMOKE_TEST_CHECKLIST.md` |
| Đụng sang repo ngoài (`alpha-studio-backend`, repo tham chiếu) | `AGENTS.md` + `.claude/` và `.agents/skills/` của repo ngoài đó trước khi đọc/sửa |

**KHÔNG đọc:**

- ❌ Toàn bộ `lib/` hoặc `integration/` chỉ để hiểu dự án (đã có `.claude/PROJECT_SUMMARY.md`).
- ❌ `build/`, `integration/zalo-bot-service/dist/`, `node_modules/`, local DB/media (`.data/`, `dataRoot`), temp/debug dump chỉ để hiểu dự án.
- ❌ `.claude/archive/` — lịch sử đã hết hiệu lực; chỉ mở khi cần biết vì sao một quyết định cũ ra đời, không làm theo.

## Luật bất biến

- UI text cập nhật cả `vi` và `en`; dialog dùng `showStandardDialog`.
- Không block Flutter UI isolate bằng process/file/database sync.
- Local/cloud transport và provider refresh phải được verify cả Windows và Android khi contract đổi.
- Sửa provider/service/crypto phải có `flutter test`; build release phải chạy artifact thật.
- Giữ nguyên package manager/lockfile (`pubspec.lock`, `package-lock.json`); tách riêng Python tooling (`D:\Dev\conda-envs\py312\python.exe`) với Node LTS runtime đóng gói trong release.

## 🔒 BẢO MẬT

- Không đưa secret, API key, JWT, cookie/session Zalo (`credentials_*.json`, `zpw_sek`), `.env` hay SQLite/media người dùng vào repo, test fixture, markdown hoặc log; chỉ dùng placeholder `<YOUR_API_KEY>`.
- HTTP server của `zalo-bot-service` chỉ bind `127.0.0.1` và giới hạn CORS; Flutter client là môi trường không tin cậy, không lưu hay nhúng secret bên thứ ba.

## 🧪 VERIFY — artifact Windows/Android release

1. Chạy `flutter analyze` và `flutter test` (bằng chứng của chính lần chạy này).
2. Build đúng platform bị tác động (Windows ZIP kèm Zalo backend bundle + Node LTS runtime; Android APK); mở artifact release, không nghiệm thu bằng `flutter run` (thiếu thiết bị Android thật thì ghi rõ *"chưa verify trên thiết bị Android thật"*).
3. Smoke local bridge/cloud transport, ghi dữ liệu, đóng/mở lại và kiểm lần chạy thứ hai theo `.claude/SMOKE_TEST_CHECKLIST.md`.
4. Task chỉ sửa docs được miễn build; vẫn phải kiểm path, placeholder, secret, diff và chạy `D:\Dev\conda-envs\py312\python.exe .claude\guard_check.py` khi chạm Bảng bẫy/guard.
5. Rào chắn code: CI `.github/workflows/guard.yml` chạy lại trên mỗi push/PR.

## ✍️ SAU MỖI TASK

Cập nhật `.claude/PROJECT_SUMMARY.md` theo luật ngay đầu file đó. Cơ chế/quy ước bền đưa vào `.claude/CONVENTIONS.md`; lỗi im lặng dễ tái phát đưa vào `.claude/IMPORTANT_FIXED_BUGS.md` (khi đã có rào chắn `✅` kèm test `bug_N` thì rút văn xuôi xuống `.claude/archive/`); lỗi vặt không ghi.
