# Phân Tích Tính Năng ChatbotX — Khả Năng Áp Dụng Vào Alpha CRM

- **Ngày:** 2026-07-01
- **Dự án tham khảo:** `D:\Dev\2.reference_pj\.Zalo-ref\.CRM-ref\ChatbotX` (mã nguồn mở, giấy phép AGPLv3 + bản enterprise thương mại; Next.js/TypeScript/Turborepo; nền tảng SaaS đa kênh đa tenant cho chat marketing — tương tự ManyChat/Chatfuel)
- **Dự án mục tiêu:** `alpha-crm` (Flutter desktop/mobile CRM, dành cho 1 hoặc vài operator, ưu tiên personal-Zalo qua thư viện không chính thức `zca-js` thông qua backend Node cục bộ — xem mục "Zalo Integration Direction" trong `CLAUDE.md` gốc)

## Phạm vi & phương pháp

Đã khảo sát qua 4 lượt nghiên cứu song song trên `apps/builder` (inbox, contacts, broadcasts, sequences, flow builder, analytics, team), `apps/worker` (thực thi job/flow), `packages/{business,database,ai,flow-config,variables,sequence-scheduler,analytics,analytics-nextjs,sdk}`, `integrations/{zalo,telegram,instagram,messenger,webchat}`, và `docs/{tech-stack,tenancy,websocket,request-workflow}.md`. Đối chiếu với hiện trạng thực tế của alpha-crm: `lib/features/{messaging/live_chat,messaging/bulk,customers,groups,workflows,security,zalo_integration}`, `docs/specs/pending-livechat-features.md`, và `docs/api-catalog/zca-js-api-catalog.md`.

## Lưu ý kiến trúc quan trọng — đọc trước khi xem điểm số

**Tính năng Zalo của ChatbotX kết nối qua Zalo OA Cloud API chính thức (OAuth2 + `access_token`), KHÔNG dùng `zca-js`.** Tính năng "buttons" trong inbox của ChatbotX gửi các template gốc của Zalo OA `oa.open.url` / `oa.query.hide` (`integrations/zalo/src/handlers/message/outgoing-message/send-button.ts`). Bề mặt API `zca-js` (personal account) mà alpha-crm đang dùng **không có API button/quick-reply/template tương đương** — các hàm gần nhất là `sendCard`, `sendBankCard`, `sendSticker`, `sendLink`, `sendVideo`, `sendVoice` (theo `docs/api-catalog/zca-js-api-catalog.md:119-137,315`). Những tính năng ChatbotX có giá trị phụ thuộc vào template OA sẽ bị chấm điểm thấp tương ứng; các tính năng thuộc dạng pattern UI/workflow (không phụ thuộc API gửi tin bên dưới) được chấm điểm theo giá trị riêng của chúng.

---

## 1. Live Chat Inbox

| Tính năng | Cách ChatbotX triển khai | Điểm | Lý do |
|---|---|:-:|---|
| Chuyển đổi bot ↔ người xử lý trên từng hội thoại | Cờ boolean trên bảng `conversation`, bật/tắt qua `enable/disableLiveChatConversationAction`; flow step `transfer-conversation-to-human` cho phép bot tự chuyển giao | **8/10** | Ánh xạ trực tiếp vào phần `workflows` (n8n) + `live_chat` của alpha-crm. Nếu n8n đang tự động trả lời, alpha-crm rất cần một cờ "tạm dừng automation cho contact này" — bổ sung nhỏ nhưng giá trị cao. |
| Gán hội thoại thủ công cho 1 agent | `assignConversationAction` set `assignedUserId` trên hội thoại; UI `AssignConversationDialog` | **5/10** | Chỉ hữu ích khi alpha-crm hỗ trợ >1 operator dùng chung 1 tài khoản Zalo. Hiện chưa có hạ tầng team/role — nên ghi nhận như một building block tương lai cho multi-operator, chưa cấp thiết ngay. |
| Gán theo team + inbox teams | Tính năng bản Enterprise (`apps/builder/src/enterprise/features/inbox-teams/`) | **2/10** | Cấu trúc dành cho multi-tenant enterprise; ngoài phạm vi của CRM 1-operator/máy. |
| Bộ lọc inbox: chưa đọc / gán cho tôi / theo dõi sau (snooze) / đã lưu trữ / bị chặn | `conversation-filter.tsx`, enum `conversationStatuses` | **9/10** | Đòn bẩy UX lớn với chi phí thấp. Danh sách hội thoại live chat của alpha-crm hiện có lẽ chỉ sắp theo thời gian gần nhất; thêm thanh filter (Chưa đọc / Theo dõi sau / Đã lưu trữ) là việc ít công sức nhưng giá trị cao cho operator quản lý nhiều luồng chat Zalo. |
| Trạng thái "theo dõi sau" (đánh dấu/snooze hội thoại) | `follow-conversation.action.ts` / `unfollow-conversation.action.ts` | **8/10** | Model dữ liệu đơn giản (boolean + nhóm sắp xếp). Phù hợp với luồng "để trả lời sau" phổ biến trong chat bán hàng Zalo. |
| Ghi chú nội bộ (message type `"comment"`, chỉ team thấy, không gửi cho khách) | Toggle chế độ trong composer (`message-input.tsx`) | **7/10** | Hữu ích ngay cả với 1 operator (ghi chú ngữ cảnh về lead) và bắt buộc khi có operator thứ hai. Chỉ cần thêm 1 cột DB + toggle composer, không phải subsystem mới. |
| Thư viện câu trả lời soạn sẵn (saved/canned replies) | `features/saved-replies/` — thư viện cấp workspace, popover trong composer | **9/10** | **Alpha-crm đã có `quick_reply_shortcuts.dart` (`/1`, `/2` slash shortcut)** — đây là bước tinh chỉnh (popover có tìm kiếm + UI CRUD quản lý thư viện) chứ không phải tính năng hoàn toàn mới. Giá trị cao, khoảng cách cần lấp thấp. |
| Gắn tag contact, lọc được ngay từ inbox | `features/tags/` + filter panel | **6/10** | Alpha-crm (mục `customers`) đã có tag theo tag per contact; điểm thiếu là *hiển thị/lọc theo tag ngay trên danh sách live-chat*, không phải bản thân hệ thống tag. |
| Panel thông tin contact bên cạnh hội thoại | `contact-inbox-panel.tsx` — hiển thị các inbox kênh liên kết với contact; panel profile đầy đủ chưa truy vết hết | **6/10** | Pattern UX tốt (xem mục UI bên dưới) — hiển thị profile khách/tag/custom field ngay cạnh khung chat thay vì phải điều hướng sang màn hình Customers. |
| Read receipt / typing indicator / presence | **Không tìm thấy** trong code inbox của ChatbotX — chỉ có "đánh dấu đã đọc" phía agent, không có typing indicator hay presence | **N/A** | Không có gì để tham khảo — **alpha-crm đang đi trước** theo `docs/specs/pending-livechat-features.md` (trạng thái đã xem/đã gửi, sự kiện typing đã ghi log). |
| AI gợi ý trả lời / tóm tắt hội thoại trong inbox | **Không tìm thấy** — AI của ChatbotX nằm trong automation flow-bot, không phải công cụ hỗ trợ agent trong inbox | **N/A** | Không phải tính năng để tham khảo từ ChatbotX, nhưng đáng lưu ý là khoảng trống của *cả hai* dự án — alpha-crm đã có AI tóm tắt cho **groups** (theo project summary), nên mở rộng pattern đó sang hội thoại 1:1 là ý tưởng gốc của alpha-crm, không phải copy từ ChatbotX. |
| Kênh truyền realtime (PartySocket theo phòng workspace → Zustand store) | Server PartyKit `apps/realtime`, `usePartySocket` | **3/10** | Đặc thù kiến trúc Next.js/multi-tenant của ChatbotX; backend alpha-crm đã có realtime bridge riêng (`LiveChatLocalBridgeApi`) — không cần port, chỉ ghi nhận pattern tồn tại. |

---

## 2. Flow Builder / Automation / AI Agent

| Tính năng | Cách ChatbotX triển khai | Điểm | Lý do |
|---|---|:-:|---|
| Flow builder kéo-thả trực quan (React Flow, ~80 loại step) | `apps/builder` flow editor + `packages/flow-config` | **2/10** | Hướng automation của alpha-crm dựa trên n8n (workflow engine ngoài), không phải builder trực quan trong app. Xây lại cái này sẽ trùng lặp việc n8n đã làm và trái với nguyên tắc "Simplicity First". Không khuyến nghị. |
| Các step `disableBot` / `enableBot` / `assignConversation` / `notifyAgent` | `packages/flow-config/src/steps/step-action.ts` | **7/10** | *Ý tưởng* (node n8n bật/tắt cờ "tạm dừng automation" hoặc báo cho operator) hoàn toàn có thể mang vào n8n integration contract của alpha-crm (`docs/specs/n8n-facebook-integration-contract.md`) như node mới, không cần builder của ChatbotX. |
| AI Agent step: chọn provider (OpenAI/Claude/Gemini/DeepSeek/OpenRouter), ghi kết quả vào custom field, toggle nhớ ngữ cảnh hội thoại | `ai-generate-text-agent.ts`, `packages/ai` | **6/10** | Alpha-crm đã định tuyến AI qua `tools/openclaw-server` (GCLI proxy). Ý tưởng hữu ích là pattern **chọn provider theo từng step + "ghi kết quả vào custom field của contact"** — có thể áp dụng khi n8n workflow gọi ngược vào alpha-crm để hỗ trợ trả lời bằng AI. |
| RAG / knowledge base (tìm kiếm tương đồng pgvector trên file đã embed) | `packages/ai/src/server/knowledge-base.ts` | **5/10** | Hấp dẫn cho tính năng tương lai "AI trả lời FAQ từ tài liệu của bạn", nhưng đây là năng lực backend hoàn toàn mới (embedding + vector search), không phải tích hợp nhanh. Đáng để spike trong tương lai, chưa ưu tiên chu kỳ này. |
| Hệ thống biến/cá nhân hóa (thay thế token `{{variable}}` bằng dữ liệu contact + custom field) | `packages/variables/src/contact-variable.ts` | **8/10** | Rất hữu ích cho bulk messaging (`messaging/bulk`) và saved replies của alpha-crm — cá nhân hóa kiểu "Chào {{name}}, đơn hàng của bạn..." là nhu cầu phổ biến và pattern extract/interpolate ở đây đơn giản, đã kiểm chứng. |
| `splitTraffic` (định tuyến A/B, chia theo % trọng số) | `packages/flow-config/src/steps/split-traffic.ts` | **3/10** | Chỉ liên quan khi alpha-crm có flow branching; ưu tiên thấp nếu chưa có builder. |
| Node `callApi` / webhook HTTP | Có trong schema nhưng handler **chưa triển khai** (`undefined` trong `apps/worker/src/integration/handlers/step.ts`) | **N/A** | Ngay cả ChatbotX cũng chưa chạy được — không có gì để tham khảo. |
| Comment-to-DM (nhắn tin tự động khi có comment chứa từ khóa trên Instagram/Messenger) | `integrations/{instagram,messenger}/src/handlers/comment/` | **1/10** | Zalo không có bề mặt "comment trên bài post" công khai tương đương IG/FB; không áp dụng được cho kênh của dự án này. |

---

## 3. Contact CRM

| Tính năng | Cách ChatbotX triển khai | Điểm | Lý do |
|---|---|:-:|---|
| Custom field có kiểu dữ liệu (`shortText, email, phoneNumber, number, date, datetime, boolean, longText`) | `packages/database/src/partials/custom-field.ts` | **4/10** | Alpha-crm (mục `customers`) đã có custom field theo CLAUDE.md; nếu implementation hiện tại chỉ là text tự do, áp dụng enum kiểu dữ liệu này là nâng cấp đáng làm nhưng không lớn — cần xác nhận hiện trạng trước khi coi là việc mới. |
| Bộ lọc contact tạm thời (theo toán tử từng field: in/notIn/isNotEmpty/contains/...), dùng ngay lúc broadcast — **không lưu thành "segment"** | `apps/builder/src/features/contacts/schemas/contact-filter/*` | **7/10** | Pattern thực dụng tốt cho việc target trong bulk messaging của alpha-crm: UI điều kiện lọc tái sử dụng được (tag là / tag không là / custom field bằng / ngày trước-sau) áp dụng tại thời điểm gửi, không cần xây cả hệ thống "segments". |
| Import CSV có mapping field (không có logic dedup/merge) | `contact-import.service.ts` | **3/10** | Chỉ hữu ích nếu alpha-crm chưa hỗ trợ import; lưu ý bản thân ChatbotX cũng không có dedup dù đặt tên marketing là "Smart Contact Import" — không nên đầu tư quá nhiều để copy một tính năng thực ra không "smart" trong bản gốc. |

---

## 4. Broadcasting & Sequences

| Tính năng | Cách ChatbotX triển khai | Điểm | Lý do |
|---|---|:-:|---|
| Gửi broadcast theo batch có giới hạn tốc độ, dedup theo contact, có retry (`DEFAULT_BROADCAST_RATE_LIMIT = 500`/tick) | `apps/worker/src/schedule/handlers/*broadcast*.ts` | **7/10** | Liên quan trực tiếp đến an toàn tuân thủ Zalo (rate limit/cooldown đã là yêu cầu có sẵn của dự án). Pattern idempotency-key + retry là tham khảo tốt để làm cứng cáp hàng đợi bulk-send của alpha-crm, vượt ra ngoài "gửi ngay + lên lịch phía client". |
| Gửi lại broadcast (resend) cho người nhận thất bại/chưa phản hồi | `resend-broadcast.action.ts` | **6/10** | Bổ sung thực tế, ít công sức cho tính năng chiến dịch bulk messaging hiện có. |
| Sequence nhỏ giọt (drip): enrollment idempotent, delay theo ngày/phút/thời điểm cụ thể, tiến trình tuyến tính (không thấy re-enrollment/branching) | `packages/sequence-scheduler/*` | **5/10** | Khoảng trống tính năng thực sự so với alpha-crm (hiện chỉ có gửi ngay + lên lịch 1 lần, chưa có chuỗi drip nhiều bước) — nhưng đây là công việc subsystem mới thực sự, không phải port nhanh. Đáng đưa vào roadmap tương lai, ưu tiên trung bình. |
| A/B testing cho broadcast/sequence | **Không tìm thấy** — README có nhắc nhưng không tìm ra implementation | **N/A** | Không có gì để copy; tính năng có vẻ chỉ tồn tại ở mức flow-level `splitTraffic`, bị quảng cáo sai trong README. |

---

## 5. Quản Lý Team

| Tính năng | Cách ChatbotX triển khai | Điểm | Lý do |
|---|---|:-:|---|
| Mô hình 2 role (`owner`, `agent`) + luồng mời thành viên | `packages/database/src/partials/workspace.ts`, `features/workspace-members/`, `features/invitations/` | **5/10** | Mô hình multi-operator đơn giản nhất có thể — hoàn toàn dùng lại được *nếu và khi* alpha-crm quyết định hỗ trợ >1 operator dùng chung 1 tài khoản Zalo (liên hệ tới tính năng "gán hội thoại" ở trên). Chưa cấp thiết cho hướng 1-operator hiện tại, nhưng là hình mẫu đúng để tham khảo sau này thay vì tự nghĩ ra cái phức tạp hơn. |

---

## 6. Analytics

| Tính năng | Cách ChatbotX triển khai | Điểm | Lý do |
|---|---|:-:|---|
| Biểu đồ khối lượng tin nhắn, tăng trưởng contact, thời gian phản hồi theo admin, tỷ lệ bot trả lời thành công | `packages/analytics-nextjs/src/components/charts/*`, `packages/analytics/src/services/*` | **6/10** | Mục `dashboard` của alpha-crm có lẽ đã có biểu đồ cơ bản (fl_chart đã có trong stack). Các chỉ số giá trị cao nên thêm: **thời gian phản hồi đầu tiên trung bình**, **tin gửi thành công vs. thất bại**, **tăng trưởng contact theo thời gian** — hỗ trợ trực tiếp câu hỏi hàng ngày của operator "mình có đang theo kịp lead không". Không cần làm đủ dashboard như bản gốc, chọn 3-4 chỉ số là đủ. |
| Growth link ("Magic Links" xuất QR + analytics riêng mỗi link; "Ref Links" đo lường giới thiệu) | `apps/builder/src/features/magic-links/`, `packages/analytics/src/services/ref-link-analytics.service.ts` | **7/10** | Phù hợp mạnh với ý tưởng tạo QR/deep-link "bắt đầu chat nhanh" trên Zalo (khách quét QR để mở chat Zalo có sẵn ngữ cảnh) kèm đếm số lượt click cơ bản. Cụ thể, phạm vi vừa phải, đúng khoảng trống "Growth Tools" mà alpha-crm hiện chưa có. |

---

## Danh sách ưu tiên áp dụng cho Live Chat Inbox (xếp hạng)

1. **Nâng cấp UI popover câu trả lời soạn sẵn** (9/10) — alpha-crm đã có cơ chế shortcut nền (`/1`, `/2`); ChatbotX cho thấy phần còn thiếu: popover có tìm kiếm + màn hình quản lý để tạo/sửa shortcut mà không cần sửa code/config.
2. **Bộ lọc trạng thái inbox (Chưa đọc / Theo dõi sau / Đã lưu trữ / Đã gán)** (9/10) — đòn bẩy UX lớn nhất với chi phí thấp nhất; biến danh sách phẳng theo thời gian thành công cụ triage thực sự.
3. **Cờ tạm dừng bot theo từng hội thoại + node handoff trong n8n** (8/10) — giải quyết vấn đề thực tế "bot vẫn tự trả lời trong khi mình đang tự tay chat", gắn liền với hướng workflow n8n hiện có.
4. **Trạng thái theo dõi sau/snooze** (8/10) — model dữ liệu đơn giản, cải thiện workflow rõ rệt.
5. **Ghi chú nội bộ trên hội thoại** (7/10) — chi phí thấp ngay bây giờ, cần thiết khi có operator thứ hai.
6. **Panel thông tin contact bên cạnh luồng chat** (6/10, xem mục UI) — giảm ma sát điều hướng.
7. **Lọc inbox theo tag** (6/10) — tái sử dụng dữ liệu tag sẵn có, chỉ cần hiển thị trên danh sách live-chat.

## Không khuyến nghị áp dụng

- **Flow builder trực quan đầy đủ** — trái với hướng automation n8n-first của alpha-crm và nguyên tắc "Simplicity First"; sẽ là một subsystem lớn, trùng lặp.
- **Button/quick-reply template kiểu OA** — `zca-js` (personal account) không có API gửi tương đương; muốn dùng phải thêm Zalo OA như một adapter kênh *thứ hai*, đây là thay đổi hướng sản phẩm cần user xác nhận rõ ràng theo `CLAUDE.md` gốc.
- **Mô hình multi-tenant workspace/reseller, quota pooling, OAuth broker host** (`docs/tenancy.md`) — giải quyết bài toán SaaS-reseller mà alpha-crm không gặp phải.
- **Comment-to-DM** — không có bề mặt công khai tương đương trên personal Zalo.
- **A/B testing** — thực ra không tồn tại trong ChatbotX dù được quảng cáo; không có gì để port.

## Ghi chú bảo mật từ quá trình nghiên cứu

Webhook Zalo của chính ChatbotX có xác thực chữ ký HMAC **đã viết nhưng bị comment out** (`integrations/zalo/src/handlers/webhook.ts:68-79`), và `state` trong OAuth không được ký HMAC. Không phải action item cho alpha-crm (model kênh/auth hoàn toàn khác), chỉ ghi nhận như một "lỗ hổng không nên copy" nếu sau này cân nhắc lại adapter OA chính thức.

---

## Ý tưởng nâng cấp giao diện cho màn hình Live Chat của alpha-crm

Các thay đổi layout cụ thể lấy cảm hứng từ inbox của ChatbotX, điều chỉnh theo ngôn ngữ thiết kế CRM shell tối màu / `AppDialog` hiện có của alpha-crm (không cần design system mới — chỉ thêm vùng layout mới):

1. **Layout 3 cột** (hiện tại có lẽ 2 cột: danh sách hội thoại + khung chat): thêm **panel contact có thể thu gọn** bên phải hiển thị avatar, tên/SĐT, tag, các custom field quan trọng, và link "Xem hồ sơ đầy đủ" dẫn vào mục `customers` — tránh phải điều hướng hẳn ra khỏi khung chat để xem đang nói chuyện với ai.
2. **Thanh chip lọc phía trên danh sách hội thoại**: `Tất cả · Chưa đọc · Theo dõi sau · Đã lưu trữ · Gán cho tôi`, theo pattern filter của ChatbotX nhưng dùng component chip/tab sẵn có nếu alpha-crm đã có (kiểm tra `lib/shared/widgets/`).
3. **Hàng action trên từng hội thoại** (menu kebab hoặc icon row khi hover/long-press): Tạm dừng bot · Đánh dấu theo dõi sau · Lưu trữ · Gán (nếu sau này có multi-operator). Bổ sung nhỏ, tăng dần trên widget hội thoại hiện có thay vì redesign toàn bộ.
4. **Hàng icon footer trong composer**: đính kèm (đã có) · popover câu trả lời soạn sẵn (nâng cấp từ shortcut `/`) · toggle chế độ "Ghi chú nội bộ" (bong bóng chat có màu nền khác biệt rõ, ví dụ vàng nhạt/amber, so với bong bóng tin gửi thông thường — đây là điểm khác biệt hình ảnh duy nhất đáng thêm).
5. **Banner "Bot đang tạm dừng"** ở đầu khung chat khi automation bị tắt cho contact đó, dùng pattern hình ảnh sẵn có của `backend_status_banner.dart` (dải màu nhỏ có icon + text) thay vì tạo kiểu banner mới.
6. **Màn hình tạo QR/link "bắt đầu chat nhanh"** như một màn hình nhẹ mới (phù hợp đặt trong mục `content` hoặc `customers`) — tạo deep link Zalo + mã QR theo từng campaign/nguồn, đếm số lượt click trong bảng đơn giản, chưa cần dashboard analytics đầy đủ ngay từ đầu.

Tất cả các mục trên nên tuân theo quy tắc i18n hiện có của dự án (vi + en), quy ước `useConfirm`/`AppDialog`, và các token CSS/theme đã thiết lập trong `lib/app/theme/` — không có ngôn ngữ hình ảnh mới, chỉ thêm vùng layout mới dùng component hiện có.

---

## Đề xuất bước tiếp theo

Tài liệu này **chỉ mang tính phân tích** — chưa có thay đổi code nào được thực hiện. Nếu muốn triển khai, khuyến nghị bắt đầu với mục 1-4 trong "Danh sách ưu tiên áp dụng cho Live Chat Inbox" ở trên như một task có phạm vi rõ ràng, vì chúng dùng chung bề mặt UI danh sách hội thoại/khung chat và không cần subsystem backend mới (chỉ cần thêm field: `botPaused: bool`, `followUpAt: DateTime?`, `isInternalNote: bool` vào model conversation/message hiện có).
