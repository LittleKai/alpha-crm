# Alpha CRM - Agent Router

Flutter Android/Windows app kem local Zalo bot service va cloud integration.

## Doc theo viec

Luon doc `.claude/PROJECT_SUMMARY.md`.

| Task | Doc bat buoc |
|---|---|
| Flutter/provider/service/crypto | `.claude/CONVENTIONS.md` |
| Live Chat, Zalo, SQLite, Windows lifecycle | `.claude/IMPORTANT_FIXED_BUGS.md` |
| Luat chi tiet cu | `.claude/PROJECT_RULES.md` |
| Truoc khi giao | `.claude/SMOKE_TEST_CHECKLIST.md` |

Khong doc build output, local DB/media, secrets, temp/debug dump hay `.claude/archive/` chi de hieu project.

## Luat bat bien

- UI text cap nhat ca `vi` va `en`; dialog dung `showStandardDialog`.
- Khong block Flutter UI isolate bang process/file/database sync.
- Local/cloud transport va provider refresh phai duoc verify ca Windows va Android khi contract doi.
- Secret/token/session/SQLite nguoi dung khong vao repo hoac log.
- Sua provider/service/crypto phai co `flutter test`; build release phai chay artifact that.

## VERIFY - artifact Windows/Android release

1. Chay `flutter analyze` va `flutter test`.
2. Build dung platform bi tac dong; mo artifact release, khong nghiem thu bang `flutter run`.
3. Smoke local bridge/cloud transport, ghi du lieu, dong/mo lai va kiem lan chay thu hai.
4. Task chi sua docs duoc mien build; van phai kiem path, placeholder, secret va diff.

## Sau moi task

Cap nhat `.claude/PROJECT_SUMMARY.md`; bug im lang moi vao bang bay, khong ghi moi bug vat.
