# Zalo Live Chat Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện toàn bộ P0-P2 trong tài liệu `docs/specs/zalo-message-processing-gap-vs-deplao.md` cho backend Zalo local-first và Flutter Live Chat.

**Architecture:** SQLite trong Local Bridge tiếp tục là nguồn dữ liệu đầy đủ. Một event bus nội bộ phát SSE tới Flutter để cập nhật tăng dần; polling chỉ dùng để đối soát. Mọi loại gửi tin dùng một contract có kiểu chung, còn adapter Zalo chọn API `zca-js` phù hợp. Các sự kiện listener được chuẩn hóa trước khi ghi database và phát realtime.

**Tech Stack:** TypeScript, Node HTTP/SSE, `better-sqlite3`, `zca-js`, Flutter 3, Riverpod, `http`, `sqflite`.

**Trạng thái:** Hoàn tất triển khai P0-P2 ngày 2026-06-06. Danh sách bên dưới được giữ lại như nhật ký kế hoạch ban đầu; kết quả xác minh cuối được ghi trong tài liệu gap và `.claude/PROJECT_SUMMARY.md`.

---

### Task 1: Hợp đồng dữ liệu và normalizer

**Files:**
- Modify: `integration/zalo-bot-service/src/channels/types.ts`
- Modify: `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- Modify: `integration/zalo-bot-service/src/channels/personal-zca-channel.test.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-types.ts`

- [ ] Viết test thất bại cho undo ID, receipt, typing, reaction và `chat.delete`.
- [ ] Chạy test để xác nhận RED.
- [ ] Thêm normalizer và contract gửi tin nâng cao tối thiểu.
- [ ] Chạy test để xác nhận GREEN.

### Task 2: Schema và kho dữ liệu Live Chat

**Files:**
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-store.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-store.test.ts`

- [ ] Viết test migration và CRUD cho `cliMsgId`, metadata, receipt, reaction, draft, history state, search và around.
- [ ] Chạy test để xác nhận RED.
- [ ] Thêm migration idempotent và phương thức store.
- [ ] Chạy test để xác nhận GREEN.

### Task 3: Event bus SSE và listener integration

**Files:**
- Create: `integration/zalo-bot-service/src/local-chat/local-chat-events.ts`
- Create: `integration/zalo-bot-service/src/local-chat/local-chat-events.test.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/index.ts`
- Modify: `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- Modify: `integration/zalo-bot-service/src/agent/agent-runner.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-api.ts`

- [ ] Viết test event replay, account/thread filter và cleanup subscriber.
- [ ] Chạy test để xác nhận RED.
- [ ] Tạo event bus, endpoint SSE và phát event sau transaction.
- [ ] Nối message, undo, receipt, typing, reaction, group/friend/system và health.
- [ ] Chạy test để xác nhận GREEN.

### Task 4: API local nâng cao và outbound

**Files:**
- Modify: `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- Modify: `integration/zalo-bot-service/src/local-chat/local-chat-api.ts`
- Modify: `integration/zalo-bot-service/src/zalo.ts`
- Modify: `integration/zalo-bot-service/src/zca-js.d.ts`

- [ ] Viết test route/helper cho mark-read, typing, reaction, retry, search, around, draft và payload gửi nâng cao.
- [ ] Chạy test để xác nhận RED.
- [ ] Triển khai route và adapter tương ứng.
- [ ] Chạy test để xác nhận GREEN.

### Task 5: Flutter contract, model, cache và realtime

**Files:**
- Modify: `lib/features/messaging/live_chat/data/live_chat_local_bridge_api.dart`
- Modify: `lib/features/messaging/live_chat/data/live_chat_repository.dart`
- Create: `lib/features/messaging/live_chat/data/live_chat_event.dart`
- Modify: `lib/features/messaging/live_chat/providers/live_chat_provider.dart`
- Modify: `lib/shared/local_db/local_db_schema.dart`
- Modify: `test/live_chat_local_first_contract_test.dart`
- Modify: `test/live_chat_provider_test.dart`
- Modify: `test/local_db_test.dart`

- [ ] Viết test thất bại cho parsing SSE, merge event, optimistic/self-echo, failed/retry, typing, receipt và reaction.
- [ ] Chạy test để xác nhận RED.
- [ ] Mở stream SSE, mở rộng model/state và định tuyến API local-first.
- [ ] Chạy test để xác nhận GREEN.

### Task 6: Flutter UI và composer

**Files:**
- Modify: `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`
- Add focused widgets under: `lib/features/messaging/live_chat/presentation/widgets/`
- Add tests under: `test/`

- [ ] Viết widget test cho trạng thái gửi, typing, seen, reaction, reply, draft, search và health.
- [ ] Chạy test để xác nhận RED.
- [ ] Triển khai UI responsive và composer nâng cao.
- [ ] Chạy test để xác nhận GREEN.

### Task 7: Xác minh toàn hệ thống và tài liệu

**Files:**
- Modify: `.claude/PROJECT_SUMMARY.md`
- Modify: `.claude/IMPORTANT_FIXED_BUGS.md` khi có lỗi kiến trúc quan trọng
- Modify: `docs/specs/zalo-message-processing-gap-vs-deplao.md`

- [ ] Chạy TypeScript build và toàn bộ Node tests.
- [ ] Chạy `dart format`, `flutter analyze`, `flutter test`.
- [ ] Kiểm tra diff, schema migration và không ghi đè thay đổi có sẵn.
- [ ] Cập nhật trạng thái từng mục trong tài liệu gap.
