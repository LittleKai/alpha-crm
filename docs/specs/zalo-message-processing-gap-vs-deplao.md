# Phân tích phần xử lý tin nhắn Zalo còn thiếu so với Deplao

**Ngày nghiên cứu:** 2026-06-06  
**Dự án hiện tại:** `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm`  
**Dự án tham chiếu:** `D:\Dev\2.reference_pj\.Zalo-ref\deplao-builder`  
**Phạm vi:** Chỉ nghiên cứu xử lý tin nhắn Zalo. Không bao gồm Facebook.

## Trạng thái triển khai ngày 2026-06-06

Toàn bộ P0-P2 trong tài liệu này đã được áp dụng vào Alpha CRM:

- **P0:** chuẩn hóa ID thu hồi/xóa, mark-read local-first, SSE có replay/filter, hiển thị lỗi và gửi lại, `clientMessageId` chống self-echo, hỗ trợ các tên event receipt thực tế.
- **P1:** typing hai chiều, receipt theo người đọc, reaction, lưu event nhóm/bạn bè, quote/mentions/styles/link/sticker/nhiều ảnh/video/voice, worker tải media có checksum và trạng thái lỗi.
- **P2:** phân loại system/reminder/poll/pin, tìm kiếm và tải vùng quanh kết quả, lưu draft, theo dõi trạng thái focus, lịch sử có trạng thái và ghi theo batch.

Các API chuyên biệt như sticker/reaction/typing được gọi theo capability của phiên bản `zca-js` đang cài. Khi capability không tồn tại, Local Bridge trả lỗi rõ ràng thay vì âm thầm coi là thành công. Kiểm thử tự động không thay thế kiểm thử E2E với tài khoản Zalo thật.

## 1. Kết luận tổng quan

Alpha CRM đã có nền tảng local-first cho Live Chat:

- Nhận tin nhắn mới và tin nhắn cũ từ Zalo.
- Phân biệt hội thoại cá nhân và hội thoại nhóm.
- Bổ sung tên, ảnh đại diện người gửi và tên nhóm.
- Lưu hội thoại, tin nhắn và tệp đính kèm vào SQLite.
- Gửi văn bản và tệp đính kèm theo đường dẫn.
- Thu hồi tin nhắn đã gửi.
- Phân trang tin nhắn cũ.
- Đồng bộ dữ liệu từ máy cục bộ lên cloud.
- Hiển thị văn bản, hình ảnh, tệp, video, giọng nói, sticker và trạng thái đã thu hồi ở mức cơ bản.

Tuy nhiên, chức năng Live Chat **chưa tích hợp đầy đủ cách xử lý tin nhắn của Deplao**. Alpha CRM mới hoàn thành vòng đời tin nhắn cơ bản, còn thiếu hoặc mới xử lý một phần các nội dung sau:

- Truyền sự kiện realtime từ Local Bridge tới Flutter.
- Hiển thị người đang nhập và gửi trạng thái đang nhập.
- Hiển thị chi tiết trạng thái đã nhận, đã xem và danh sách thành viên đã xem trong nhóm.
- Thả cảm xúc cho tin nhắn.
- Trích xuất đúng ID của tin nhắn bị thu hồi.
- Xử lý `chat.delete`, tin hệ thống, nhắc hẹn, bình chọn và ghim tin nhắn.
- Đồng bộ đầy đủ sự kiện nhóm và sự kiện bạn bè.
- Trả lời/trích dẫn, nhắc tên, định dạng văn bản, link preview, sticker, ghi âm và video chuyên biệt.
- Hiển thị tin đang gửi, đối soát self-echo, thử gửi lại và hiển thị lỗi gửi.
- Tải media về máy và cập nhật đường dẫn cục bộ.
- Lưu bản nháp, tính chưa đọc theo trạng thái cửa sổ, thông báo desktop và tìm kiếm tin nhắn.

File `docs/specs/pending-livechat-features.md` hiện tuyên bố đã hoàn thành 100%. Kết luận đó không phù hợp với source hiện tại. Source chỉ chứng minh đã hoàn thành nền tảng local-first cơ bản, chưa đạt mức tương đương Deplao.

## 2. Ánh xạ kiến trúc hai dự án

| Trách nhiệm | Alpha CRM | Deplao |
|---|---|---|
| Phiên đăng nhập và listener Zalo | `PersonalZcaChannel` | `ZaloLoginHelper`, `ConnectionManager` |
| API gửi tin Zalo | `PersonalZcaChannel.sendMessage`, `recallMessage` | `ZaloService` |
| Chuẩn hóa sự kiện | `normalizeInboundMessage` | `ZaloLoginHelper`, `EventBroadcaster` |
| Lưu trữ cục bộ | `LocalChatStore` | `DatabaseService` |
| Truyền sự kiện tới giao diện | HTTP polling qua local/cloud API | Electron IPC qua `EventBroadcaster` |
| Quản lý trạng thái giao diện | Riverpod `LiveChatNotifier` | Zustand `chatStore` |
| Nhận sự kiện tại giao diện | Polling mỗi 12 giây | `useZaloEvents` realtime |
| Khung soạn tin | Văn bản, trả lời nhanh, một tệp | Văn bản, định dạng, nhắc tên, trích dẫn, link, nhiều ảnh, file, video, voice, sticker |

## 3. Những phần Alpha CRM đã có

### 3.1. Định danh hội thoại và lưu tin nhắn đến

Alpha CRM đã sử dụng đúng cặp định danh tài khoản và luồng hội thoại:

- Bảng `conversations` có unique index `(accountId, threadId)`.
- Tin nhắn nhóm sử dụng Zalo group ID làm `threadId`.
- Người gửi được lưu riêng trong `senderId`.
- Loại luồng được lưu bằng `threadType` là `user` hoặc `group`.

Các file liên quan:

- `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- `integration/zalo-bot-service/src/local-chat/local-chat-store.ts`
- `integration/zalo-bot-service/src/agent/agent-runner.ts`

### 3.2. Metadata người gửi và nhóm

Khi nhận tin mới hoặc tin cũ, Alpha CRM đã:

- Gọi `getUserInfo` khi thiếu tên hoặc avatar người gửi.
- Dùng cache hồ sơ để hạn chế gọi API Zalo quá nhiều.
- Tra cứu tên nhóm.
- Lưu tên và avatar người gửi vào dữ liệu cục bộ.

### 3.3. Lưu trữ local-first và đồng bộ cloud

Alpha CRM đã có:

- SQLite chạy chế độ WAL.
- Upsert tin nhắn theo provider message ID để chống trùng.
- Bảng tệp đính kèm.
- Số tin chưa đọc và metadata tin nhắn cuối của hội thoại.
- Hàng đợi đồng bộ.
- Cơ chế thử lại với thời gian chờ tăng dần.
- Gửi metadata lên cloud khi bật local-first.

### 3.4. Gửi tin, thu hồi và lấy lịch sử cơ bản

Alpha CRM đã hỗ trợ:

- Gửi văn bản.
- Gửi tệp theo đường dẫn qua `zca-js`.
- Trạng thái cục bộ `queued`, `sent`, `failed`.
- Endpoint thu hồi và đánh dấu tin đã xóa trong SQLite.
- Truy vấn tin nhắn theo `before` và `after`.
- Gọi `requestOldMessages` khi lịch sử cục bộ đã hết.

Đây là nền tảng phù hợp để mở rộng, không cần thay thế toàn bộ.

## 4. Các phần còn thiếu hoặc mới xử lý một phần

### 4.1. Truyền sự kiện realtime tới Flutter

**Cách Deplao thực hiện**

- `ZaloLoginHelper` nhận sự kiện từ listener.
- `EventBroadcaster` lưu dữ liệu và phát IPC ngay lập tức.
- `useZaloEvents` cập nhật Zustand store mà không cần tải lại toàn bộ.

**Trạng thái Alpha CRM: Chưa có**

- Flutter tải lại tin nhắn và hội thoại mỗi 12 giây.
- Local Bridge chưa có SSE hoặc WebSocket dành cho Live Chat.
- Handler `typing` mới ghi log và có chú thích sẽ truyền tới frontend trong tương lai.

**Cần triển khai**

- Thêm endpoint SSE hoặc WebSocket. SSE phù hợp nếu chỉ cần bridge đẩy sự kiện một chiều.
- Chuẩn hóa các sự kiện:
  - `message.created`
  - `message.updated`
  - `message.recalled`
  - `message.status`
  - `typing`
  - `conversation.updated`
  - `group.event`
  - `connection.status`
- Flutter chỉ mở một kết nối sự kiện và hợp nhất dữ liệu theo ID ổn định.
- Giữ polling làm cơ chế đối soát dự phòng, không dùng làm realtime chính.

### 4.2. Chuẩn hóa ID khi thu hồi tin nhắn

**Cách Deplao thực hiện**

Deplao ưu tiên lấy ID theo thứ tự:

1. `undo.data.content.globalMsgId`
2. `undo.data.content.cliMsgId`
3. Các trường ID dự phòng

`undo.data.msgId` có thể là ID của thao tác thu hồi, không phải ID tin nhắn gốc.

**Trạng thái Alpha CRM: Có một phần và có rủi ro**

Alpha CRM hiện lấy `data?.data?.msgId ?? data?.msgId`, chưa ưu tiên `content.globalMsgId`.

**Cần triển khai**

- Tạo hàm `normalizeUndoEvent` riêng.
- Đối chiếu cả provider message ID và client message ID.
- Thêm cột `cliMsgId` độc lập trong SQLite.
- Thêm test cho payload thu hồi ở chat cá nhân và chat nhóm.
- Có thể giữ nội dung gốc trong trường audit nếu chính sách sản phẩm cho phép, nhưng giao diện vẫn phải hiển thị là đã thu hồi.

### 4.3. Trạng thái đã nhận và đã xem

**Cách Deplao thực hiện**

- Chuẩn hóa riêng payload seen của chat cá nhân và chat nhóm.
- Lưu danh sách `seenUids` đối với nhóm.
- Cập nhật giao diện ngay khi có sự kiện.
- Gửi seen event khi người dùng đang thực sự xem hội thoại.

**Trạng thái Alpha CRM: Có một phần**

- Listener cập nhật trạng thái một tin thành `delivered` hoặc `seen`.
- Flutter chưa có danh sách người đã xem hoặc trạng thái receipt chi tiết.
- `LiveChatRepository.markRead()` luôn gọi cloud, dù Local Bridge đã có `/local/conversations/:id/mark-read`.
- Cần xác minh tên event thực tế của phiên bản `zca-js` đang cài. Deplao dùng `seen`, còn Alpha dùng `seen_messages` và `delivered_messages`.

**Cần triển khai**

- Khi bật local-first, `markRead` phải gọi Local Bridge.
- Hỗ trợ các tên event receipt tương ứng với phiên bản `zca-js`.
- Tạo bảng receipt riêng hoặc bổ sung `seenByJson`, `deliveredAt`, `seenAt`.
- Hiển thị trạng thái đang gửi, đã gửi, đã nhận và đã xem.
- Với nhóm, cho phép xem danh sách thành viên đã đọc.
- Luôn kiểm tra `blockSeen` trước khi gửi seen event lên Zalo.

### 4.4. Trạng thái đang nhập

**Cách Deplao thực hiện**

- Nhận và chuẩn hóa typing cho chat cá nhân và nhóm.
- Phát sự kiện tới renderer.
- Lưu tạm người đang nhập với thời hạn tự hết.
- Gửi typing event từ khung soạn tin với throttle/debounce.

**Trạng thái Alpha CRM: Chỉ ghi log**

**Cần triển khai**

- Phát typing event qua kết nối realtime.
- Lưu typing state theo `accountId`, `threadId`, `userId`.
- Tự xóa trạng thái sau một khoảng thời gian.
- Hiển thị “đang nhập...” cho chat cá nhân và tên người đang nhập trong nhóm.
- Chỉ gửi outbound typing khi `blockTyping` đang tắt.
- Giới hạn tần suất gửi để tránh spam sự kiện.

### 4.5. Cảm xúc trên tin nhắn

**Cách Deplao thực hiện**

- Bắt listener event `reaction`.
- Tra cứu metadata nếu người thả cảm xúc chưa có trong dữ liệu.
- Lưu reaction vào database.
- Cập nhật bong bóng tin nhắn realtime.
- Hỗ trợ thêm, đổi và xóa reaction.

**Trạng thái Alpha CRM: Chưa có**

**Cần triển khai**

- Chuẩn hóa reaction event.
- Tạo bảng dạng `(messageId, userId, emoji, updatedAt)`.
- Thêm local API để thêm hoặc xóa reaction.
- Thêm thao tác reaction trên Flutter.
- Khi người dùng đổi hoặc xóa cảm xúc, phải cập nhật bản ghi hiện có thay vì cộng dồn sai.

### 4.6. Phân biệt xóa phía tôi và thu hồi

**Cách Deplao thực hiện**

- Nhận diện `msgType === 'chat.delete'` trước khi lưu như tin nhắn thường.
- Trích xuất toàn bộ ID bị ảnh hưởng.
- Đánh dấu recalled thay vì xóa vật lý khỏi lịch sử.
- Cập nhật preview hội thoại nếu tin cuối bị xóa.

**Trạng thái Alpha CRM: Chưa có**

**Cần triển khai**

- Chặn và phân loại `chat.delete` trước bước insert tin nhắn thông thường.
- Chuẩn hóa danh sách ID đích.
- Cập nhật các tin và preview hội thoại trong cùng transaction.
- Chỉ phát một sự kiện batch tới giao diện.

### 4.7. Sự kiện nhóm

**Cách Deplao thực hiện**

- Lưu thay đổi thành viên và thay đổi cấu trúc nhóm.
- Chỉ tải lại toàn bộ thông tin nhóm khi thật sự cần.
- Phát event cập nhật giao diện.
- Chèn tin hệ thống nằm giữa khung chat.
- Cập nhật thành viên, quản trị viên, tên, avatar và cài đặt nhóm.

**Trạng thái Alpha CRM: Có một phần**

Alpha CRM mới ghi log và xóa cache tên/danh sách nhóm.

**Cần triển khai**

- Chuẩn hóa loại sự kiện và danh sách người bị ảnh hưởng.
- Lưu thay đổi thành viên, admin, tên, avatar và cài đặt.
- Tạo tin hệ thống với ID xác định để không bị trùng khi replay.
- Cập nhật tên/avatar hội thoại ngay lập tức.
- Chỉ gọi lấy toàn bộ group info với sự kiện không thể cập nhật tăng dần.

### 4.8. Sự kiện bạn bè

**Cách Deplao thực hiện**

- Xử lý lời mời đã gửi, đã nhận, đã chấp nhận, xóa bạn, từ chối và hủy lời mời.
- Lấy hồ sơ người liên quan.
- Lưu trạng thái lời mời và contact.
- Phát thông báo cho operator và cập nhật CRM.

**Trạng thái Alpha CRM: Có một phần**

Alpha CRM mới ghi log lời mời và có thể tự động chấp nhận lời mời đến.

**Cần triển khai**

- Lưu chiều và trạng thái lời mời.
- Phát sự kiện lên UI.
- Cập nhật trạng thái kết bạn của contact.
- Tự động chấp nhận chỉ là policy tùy chọn, không được thay thế việc lưu sự kiện.

### 4.9. Tin hệ thống, nhắc hẹn, bình chọn và ghim

**Cách Deplao thực hiện**

- Nhận diện `webchat` action list và hiển thị thành tin hệ thống.
- Nhận diện reminder từ `chat.ecard`.
- Cập nhật tin bình chọn hiện có khi có vote.
- Phát hiện ghim/bỏ ghim và lưu metadata.

**Trạng thái Alpha CRM: Phần lớn chưa có**

Flutter đã có thể hiển thị một số rich card nếu nhận được dữ liệu phù hợp, nhưng backend chưa có bước phân loại và cập nhật chuyên biệt như Deplao.

**Cần triển khai**

- Thêm bộ phân loại trước khi lưu generic message.
- Lưu payload hệ thống, reminder, poll và pin dưới dạng JSON có cấu trúc.
- Cập nhật poll/pin hiện có thay vì tạo thêm tin nhắn thường.
- Bổ sung renderer và hành động tương ứng trên Flutter.

### 4.10. Các định dạng gửi tin nâng cao

**Cách Deplao thực hiện**

`ZaloService` có xử lý riêng cho:

- Trả lời/trích dẫn.
- Nhắc tên thành viên.
- Định dạng chữ.
- Link preview.
- Sticker.
- Một ảnh và nhiều ảnh.
- File.
- Video.
- Voice.
- Danh thiếp và thẻ ngân hàng.
- Chuyển tiếp tin nhắn.

**Trạng thái Alpha CRM: Mới có mức cơ bản**

Alpha CRM chủ yếu gửi `{ msg, attachments }`. Flutter có văn bản, trả lời nhanh và chọn một tệp. Video vẫn đi qua luồng attachment chung.

**Cần triển khai**

- Thay payload gửi bằng contract có kiểu rõ ràng.
- Dùng API chuyên biệt khi `zca-js` cung cấp API riêng.
- Thêm `quote`, `mentions`, `styles` cho văn bản.
- Thêm gửi nhiều ảnh, sticker, link, video và voice.
- Kiểm tra khả năng theo loại luồng và metadata bắt buộc.
- Mọi xử lý đường dẫn file và metadata ảnh phải nằm trong Node backend, không đưa sang Flutter.

### 4.11. Tin tạm và đối soát self-echo

**Cách Deplao thực hiện**

- Chèn ngay tin tạm có trạng thái `sending`.
- Khi listener nhận self-echo, thay thế tin tạm bằng tin thật.
- Chống trùng theo message ID, client ID, nội dung, loại tin và tên file.

**Trạng thái Alpha CRM: Chưa có**

Alpha CRM chờ HTTP hoàn thành rồi tải lại danh sách. Tin lỗi bị lọc khỏi giao diện nên operator không thể xem hoặc thử gửi lại.

**Cần triển khai**

- Sinh client message ID cho mọi lần gửi.
- Chèn tin optimistic vào Flutter và SQLite.
- Đối soát self-echo bằng `providerMessageId` hoặc `cliMsgId`.
- Hiển thị `sending`, `sent`, `delivered`, `seen`, `failed`.
- Thêm nút thử lại và xóa tin lỗi.
- Không được âm thầm ẩn tin gửi thất bại.

### 4.12. Vòng đời media

**Cách Deplao thực hiện**

- Tách metadata từ xa và đường dẫn file cục bộ.
- Tải media nhận được về máy ở background.
- Phát event cập nhật local path sau khi tải xong.
- Có thư viện media/file và thao tác mở file cục bộ.

**Trạng thái Alpha CRM: Có một phần**

Schema đã có `url` và `localPath`, nhưng chưa thấy đầy đủ worker tải file và luồng cập nhật UI.

**Cần triển khai**

- Tạo hàng đợi tải media có giới hạn số tác vụ đồng thời.
- Dùng đường dẫn ổn định và đổi tên file tạm theo cách atomic.
- Lưu trạng thái tải, checksum, MIME type, lỗi và thời điểm tải.
- Phát `attachment.updated`.
- Có cơ chế thử lại và dọn cache.

### 4.13. Lịch sử, tìm kiếm và điều hướng

**Cách Deplao thực hiện**

- Tải lịch sử bằng cursor và offset.
- Tìm kiếm tin nhắn.
- Truy vấn riêng media và file.
- Lấy các tin quanh một timestamp đích.
- Xử lý old messages theo batch để không chặn tiến trình.

**Trạng thái Alpha CRM: Có một phần**

- Đã có phân trang `before` và `after`.
- Khi SQLite hết dữ liệu, `requestOldMessages` chạy fire-and-forget nên response hiện tại vẫn có thể trả về rỗng.
- Chưa thấy API tìm kiếm cục bộ hoặc tải quanh một tin đích.

**Cần triển khai**

- Trả trạng thái/token khi đang yêu cầu lịch sử từ Zalo.
- Flutter chờ event hoặc thử lại với backoff có giới hạn.
- Ghi và bổ sung metadata old messages theo batch.
- Thêm full-text search cục bộ và endpoint `messages/around`.
- Phân biệt `hasMoreLocal`, `historyFetchPending` và `historyExhausted`.

### 4.14. Chưa đọc, focus, thông báo và bản nháp

**Cách Deplao thực hiện**

- Tính chưa đọc theo hội thoại đang mở và trạng thái focus của cửa sổ.
- Tự đánh dấu đã đọc khi người dùng đang xem.
- Cập nhật badge.
- Phát âm thanh và thông báo desktop có thể mở đúng tài khoản/hội thoại.
- Lưu bản nháp riêng cho từng tài khoản và luồng chat.

**Trạng thái Alpha CRM: Chưa có hoặc mới có mức cơ bản**

SQLite có số chưa đọc nhưng polling của Flutter chưa có hành vi realtime tương đương. Chưa thấy model bản nháp theo hội thoại.

**Cần triển khai**

- Theo dõi vòng đời ứng dụng, focus và hội thoại đang chọn.
- Mark read cục bộ và chỉ gửi seen khi policy cho phép.
- Tích hợp thông báo native/desktop.
- Lưu draft theo `(accountId, threadId)`.

### 4.15. Sức khỏe kết nối và khôi phục

**Cách Deplao thực hiện**

- Phát trạng thái connected, disconnected và listener dead.
- Có kiểm tra sức khỏe listener và cơ chế kết nối lại.
- Thông báo rõ cookie hoặc session đã hết hạn.

**Trạng thái Alpha CRM: Có một phần**

Alpha CRM đánh dấu một số mã đóng kết nối là `DISCONNECTED_EXPIRED`, nhưng Live Chat chủ yếu chỉ hiển thị trạng thái Bridge offline chung.

**Cần triển khai**

- Phân biệt:
  - Tiến trình Local Bridge offline.
  - Phiên Zalo hết hạn.
  - Listener đang kết nối lại.
  - Một tài khoản cụ thể bị ngắt.
- Phát health event theo từng tài khoản.
- Chỉ khóa thao tác của tài khoản bị lỗi.
- Hiển thị hành động kết nối lại hoặc quét QR rõ ràng.

## 5. Đề xuất bổ sung mô hình dữ liệu

| Dữ liệu | Cách lưu đề xuất |
|---|---|
| Client message ID | `messages.cliMsgId`, có index |
| Trích dẫn/trả lời | `messages.quoteJson` |
| Mentions và styles | `messages.mentionsJson`, `messages.stylesJson` |
| Nội dung trước khi thu hồi | `messages.recalledContent`, phụ thuộc chính sách |
| Receipt | `message_receipts(messageId, userId, status, timestamp)` |
| Reaction | `message_reactions(messageId, userId, emoji, updatedAt)` |
| Payload hệ thống/poll/pin | `messages.metadataJson` hoặc bảng chuyên biệt |
| Trạng thái tải media | Status, checksum, error, downloadedAt trong attachment |
| Bản nháp | `chat_drafts(accountId, threadId, content, updatedAt)` |
| Trạng thái lịch sử | Provider ID cũ nhất và cờ pending/exhausted theo thread |

Mọi migration phải idempotent và không làm mất liên kết giữa local ID, cloud ID và Zalo message ID hiện có.

## 6. Thứ tự triển khai đề xuất

### P0: Đảm bảo tính đúng đắn

1. Sửa cách lấy ID trong undo event.
2. Chuyển mark-read local-first sang Local Bridge.
3. Thêm SSE realtime cho tạo, cập nhật, thu hồi và trạng thái tin nhắn.
4. Không ẩn tin lỗi; hiển thị lỗi và cho phép thử lại.
5. Thêm `cliMsgId` và đối soát self-echo.
6. Xác minh tên receipt event của phiên bản `zca-js` đang sử dụng.

### P1: Hoàn thiện chức năng chat cốt lõi

1. Typing hai chiều.
2. Chi tiết người đã xem.
3. Reaction.
4. Lưu và cập nhật UI cho sự kiện nhóm/bạn bè.
5. Quote, mentions, styles, link, sticker, nhiều ảnh, video và voice.
6. Worker tải media và cập nhật local path.

### P2: Hoàn thiện chức năng vận hành nâng cao

1. Tin hệ thống, reminder, poll và pin.
2. Tìm kiếm tin nhắn và tải quanh kết quả.
3. Bản nháp và thông báo theo focus.
4. Đồng bộ lịch sử có trạng thái và xử lý theo batch.

## 7. Các file Alpha CRM dự kiến cần thay đổi

- `integration/zalo-bot-service/src/channels/personal-zca-channel.ts`
- `integration/zalo-bot-service/src/channels/types.ts`
- `integration/zalo-bot-service/src/local-chat/local-chat-store.ts`
- `integration/zalo-bot-service/src/local-chat/local-chat-types.ts`
- `integration/zalo-bot-service/src/local-chat/local-chat-api.ts`
- `integration/zalo-bot-service/src/local-chat/sync-worker.ts`
- `integration/zalo-bot-service/src/server.ts`
- `lib/features/messaging/live_chat/data/live_chat_local_bridge_api.dart`
- `lib/features/messaging/live_chat/data/live_chat_repository.dart`
- `lib/features/messaging/live_chat/providers/live_chat_provider.dart`
- `lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart`
- `lib/shared/database/local_db.dart`

## 8. Các file Deplao dùng để tham chiếu

- `src/utils/ZaloLoginHelper.ts`
- `src/services/zalo/ZaloService.ts`
- `src/services/event/EventBroadcaster.ts`
- `src/services/database/DatabaseService.ts`
- `electron/ipc/zaloIpc.ts`
- `src/ui/hooks/useZaloEvents.ts`
- `src/ui/store/chatStore.ts`
- `src/ui/components/chat/MessageInput.tsx`
- `src/ui/components/chat/ChatWindow.tsx`
- `src/ui/components/chat/MessageBubbles.tsx`

## 9. Ma trận kiểm thử tối thiểu

- Nhận văn bản ở chat cá nhân và chat nhóm.
- Nhận self-echo của tin do chính tài khoản gửi.
- Gửi/nhận một ảnh, nhiều ảnh, file, video, voice, sticker và link.
- Trả lời tin văn bản, media và sticker.
- Nhắc tên thành viên và gửi văn bản có định dạng.
- Thu hồi bởi chính mình, bởi người khác và bởi quản trị viên nhóm.
- Xử lý `chat.delete`.
- Trạng thái delivered và seen ở chat cá nhân.
- Nhiều người xem trong chat nhóm.
- Typing start/stop khi bật hoặc tắt `blockTyping`.
- Đổi tên/avatar nhóm, thêm/xóa thành viên và đổi quản trị viên.
- Toàn bộ vòng đời lời mời kết bạn.
- Thêm, đổi và xóa reaction.
- Tải tin cũ khi cache rỗng, có một phần và đã hết hoàn toàn.
- Bridge offline, phiên Zalo hết hạn, listener đang kết nối lại và chỉ một tài khoản bị lỗi.
- Sự kiện listener trùng, self-echo trùng và khôi phục sau khi khởi động lại.
- Media tải lỗi, thử lại và file cục bộ bị mất.
- Độ ổn định cuộn và hiển thị trên Flutter desktop/mobile.
