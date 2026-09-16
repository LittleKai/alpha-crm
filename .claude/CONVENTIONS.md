# Conventions - Alpha CRM

**Last Updated:** 2026-09-16

| Quy uoc | Vi du that |
|---|---|
| Business state nam trong provider/repository, UI khong goi transport truc tiep | `lib/features/messaging/live_chat/providers/live_chat_provider.dart::LiveChatNotifier`, `lib/features/messaging/live_chat/data/live_chat_repository.dart::LiveChatRepository` |
| Dialog dung helper chung de giu navigation va style nhat quan | `lib/shared/widgets/standard_dialog.dart::showStandardDialog`, `lib/features/settings/presentation/screens/settings_screen.dart::SettingsScreen` |
| Process backend Windows duoc quan ly async qua mot owner | `lib/shared/utils/zalo_backend_manager.dart::ZaloBackendManager`, `lib/shared/utils/desktop_window_manager.dart::DesktopShell` |
| Logic merge/transform tach khoi widget va co test | `lib/features/dashboard/utils/dashboard_chart_data.dart::mergeFriendStatsIntoPerformanceData`, `lib/features/messaging/live_chat/data/live_chat_repository.dart::watchEvents` |
| Local bot service enforce policy tai chokepoint channel | `integration/zalo-bot-service/src/channels/personal-zca-channel.ts::sendTyping`, `integration/zalo-bot-service/src/channels/personal-zca-channel.ts::sendMessage` |

## Cuong che bang cong cu

| Quy uoc | Cong cu cuong che |
|---|---|
| Dart/Flutter lint | `flutter analyze` + `flutter_lints` |
| Provider/service/crypto regressions | `flutter test` |
| Tai lieu rao chan con symbol | `D:\Dev\conda-envs\py312\python.exe .claude\guard_check.py` |
