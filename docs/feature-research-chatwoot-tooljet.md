# Nghiên cứu tính năng: Chatwoot & ToolJet → Alpha CRM

> Mục tiêu: rút ra các tính năng **đáng giá và phù hợp** để tích hợp vào Alpha CRM (Flutter CRM "personal Zalo first" + backend Node `zalo-bot-service`), bao gồm hướng mở rộng **Facebook** và **Email**, kèm chấm điểm thang 10.
>
> Nguồn tham chiếu:
> - **Chatwoot** (`.CRM-ref/chatwoot`) — nền tảng customer engagement / omnichannel support (Ruby on Rails). Bản này có cả phần `enterprise/` (Captain AI, SLA, Voice, Companies, SAML/SCIM).
> - **ToolJet** (`.CRM-ref/ToolJet`) — low-code internal tool builder (NestJS + React). ~45 data-source plugins, workflows, RBAC, audit logs, white-labelling.

---

## 0. Cách chấm điểm

Mỗi tính năng chấm 3 trục, mỗi trục /10, rồi tính **Điểm ưu tiên** (trung bình có trọng số):

| Trục | Ý nghĩa | Trọng số |
|------|---------|----------|
| **Giá trị (V)** | Mức độ tăng giá trị sản phẩm cho người dùng cuối (sale/marketer Zalo) | ×0.45 |
| **Phù hợp (F)** | Khớp với mô hình "personal Zalo first", kiến trúc Flutter + Node hiện có, rủi ro tuân thủ | ×0.35 |
| **Khả thi (E)** | Dễ tích hợp (cao = ít công sức / ít phụ thuộc hạ tầng nặng) | ×0.20 |

`Ưu tiên = V×0.45 + F×0.35 + E×0.20` → quy về thang 10.

Ngưỡng đề xuất: **≥7.5 = nên làm sớm**, **6.0–7.4 = làm khi có nhu cầu**, **<6.0 = bỏ qua / không phù hợp hiện tại**.

---

## 1. Bảng tổng hợp (xếp theo Điểm ưu tiên)

| # | Tính năng | Nguồn | V | F | E | **Ưu tiên** | Nhóm |
|---|-----------|-------|---|---|---|------------|------|
| 1 | Canned Responses (mẫu trả lời nhanh, biến động) | Chatwoot | 9 | 9 | 9 | **9.0** | Inbox |
| 2 | Labels / Tags hội thoại + bộ lọc lưu sẵn | Chatwoot | 9 | 9 | 8 | **8.8** | Inbox/CRM |
| 3 | Custom Attributes (trường tùy biến contact/hội thoại) | Chatwoot | 9 | 9 | 8 | **8.8** | CRM |
| 4 | Automation Rules (event → điều kiện → hành động) | Chatwoot | 9 | 8 | 7 | **8.2** | Tự động hóa |
| 5 | Contact / Conversation notes + timeline | Chatwoot | 8 | 9 | 9 | **8.4** | CRM |
| 6 | Macros (chuỗi hành động 1 chạm) | Chatwoot | 8 | 8 | 8 | **8.0** | Tự động hóa |
| 7 | Reporting & Conversation metrics (rollup) | Chatwoot | 8 | 8 | 7 | **7.8** | Phân tích |
| 8 | **Email channel (IMAP/SMTP → hội thoại)** | Chatwoot | 9 | 7 | 6 | **7.5** | Kênh mới |
| 9 | CSAT survey (khảo sát hài lòng) | Chatwoot | 7 | 8 | 8 | **7.5** | Inbox |
| 10 | **Facebook Page Messenger channel** | Chatwoot | 9 | 7 | 5 | **7.3** | Kênh mới |
| 11 | Agent Bot / chatbot handoff framework | Chatwoot | 8 | 7 | 6 | **7.2** | Tự động hóa |
| 12 | Help Center / Portal (KB công khai) | Chatwoot | 7 | 7 | 7 | **7.0** | Nội dung |
| 13 | Teams + Auto-assignment (round-robin) | Chatwoot | 7 | 7 | 7 | **7.0** | Vận hành |
| 14 | Audit Logs (nhật ký thao tác người dùng) | ToolJet | 7 | 8 | 7 | **7.3** | Quản trị |
| 15 | RBAC / Group permissions chi tiết | ToolJet | 7 | 7 | 7 | **7.0** | Quản trị |
| 16 | SLA policy + cảnh báo quá hạn | Chatwoot(EE) | 7 | 6 | 6 | **6.5** | Vận hành |
| 17 | Captain AI: Copilot trả lời + Auto-suggest | Chatwoot(EE) | 8 | 6 | 5 | **6.6** | AI |
| 18 | Dashboard builder / widget kéo-thả | ToolJet | 6 | 5 | 4 | **5.3** | Phân tích |
| 19 | Data-source plugins (45+ connector) | ToolJet | 5 | 4 | 4 | **4.5** | Tích hợp |
| 20 | Instagram / WhatsApp / Telegram channel | Chatwoot | 6 | 5 | 4 | **5.2** | Kênh mới |
| 21 | White-labelling / Custom domain | ToolJet | 5 | 6 | 5 | **5.3** | Thương hiệu |
| 22 | App versioning / Git-sync cấu hình | ToolJet | 4 | 4 | 4 | **4.0** | DevOps |

---

## 2. Chatwoot — phân tích chi tiết

Chatwoot đã giải đúng bài toán Alpha CRM đang làm: **một inbox hợp nhất nhiều kênh, có công cụ năng suất cho người trực chat**. Phần lớn giá trị nằm ở các tính năng "agent productivity" — nhẹ, không phụ thuộc hạ tầng nặng, map thẳng vào Live Chat hiện có.

### 2.1 Canned Responses — **9.0** ⭐ nên làm đầu tiên
- **Là gì:** thư viện mẫu trả lời, gọi bằng shortcode (vd gõ `/gia` → bung nội dung), hỗ trợ biến (`{{contact.name}}`).
- **Vì sao hợp:** Alpha CRM đã có `quick_reply_shortcuts.dart` (`/1`, `/2`...) — đây là bản nâng cấp tự nhiên: thêm CRUD mẫu, biến động, tìm kiếm. Lưu SQLite backend, đồng bộ như knowledge base sẵn có.
- **Công sức:** thấp. Một bảng `canned_responses` + picker trong khung soạn tin.
- File tham chiếu: `app/models/canned_response.rb`.

### 2.2 Labels / Tags + Saved Filters — **8.8** ⭐
- **Là gì:** gắn nhãn màu cho hội thoại/contact (vd "khách nóng", "đã chốt"), lọc & lưu bộ lọc.
- **Vì sao hợp:** marketer cần phân loại sau chiến dịch bulk. Map vào danh sách hội thoại Live Chat + danh bạ.
- File: `app/models/label.rb`, `app/services/filter_service.rb`, `app/finders/`.

### 2.3 Custom Attributes — **8.8** ⭐
- **Là gì:** admin tự định nghĩa trường dữ liệu (text/number/list/date/checkbox) cho contact & conversation, hiển thị ở panel bên phải.
- **Vì sao hợp:** biến CRM từ "danh bạ Zalo" thành CRM thật (nguồn khách, ngân sách, giai đoạn phễu) mà không phải đổi schema mỗi lần.
- File: `app/models/custom_attribute_definition.rb`.

### 2.4 Contact/Conversation Notes + Timeline — **8.4** ⭐
- **Là gì:** ghi chú nội bộ về khách + dòng thời gian sự kiện (đã nhắn, đổi nhãn, được giao...).
- **Vì sao hợp:** đã có `group_summary_local_store.dart` (timeline nhóm) — mở rộng sang contact là chi phí thấp, giá trị cao cho việc chăm sóc.
- File: `app/models/note.rb`.

### 2.5 Automation Rules — **8.2** ⭐
- **Là gì:** quy tắc `khi [sự kiện] + nếu [điều kiện] → [hành động]` (vd: tin nhắn mới chứa "báo giá" → gắn nhãn + giao cho người X + gửi canned response).
- **Vì sao hợp:** đây là "bộ não" liên kết tất cả tính năng trên. Map tự nhiên vào listener tin nhắn `zca-js` đã có ở backend.
- **Lưu ý tuân thủ:** mọi hành động gửi tin tự động phải đi qua rate-limit/cooldown hiện có — **không** bỏ qua guard.
- File: `app/models/automation_rule.rb`, `app/services/automation_rules/`.

### 2.6 Macros — **8.0**
- Chuỗi hành động đóng gói, agent bấm 1 nút để chạy (vd "Quy trình chốt đơn": gắn nhãn + ghi chú + gửi mẫu). Khác Automation ở chỗ kích hoạt thủ công. File: `app/models/macro.rb`.

### 2.7 Reporting & Metrics Rollup — **7.8**
- **Là gì:** thống kê hội thoại (số tin, thời gian phản hồi đầu, độ giải quyết) với bảng rollup tổng hợp sẵn để query nhanh.
- **Vì sao hợp:** Dashboard hiện tại dùng mock (`dashboard_chart_data.dart`) — đây là nguồn số liệu thật. Kiến trúc `reporting_events_rollup` đáng học để tránh quét toàn bộ tin nhắn mỗi lần.
- File: `app/models/reporting_event.rb`, `reporting_events_rollup.rb`, `app/services/reports/`.

### 2.8 CSAT Survey — **7.5**
- Gửi khảo sát hài lòng sau khi đóng hội thoại (rating + comment), tổng hợp điểm. Bản EE có cả CSAT template management bằng LLM. File: `app/models/csat_survey_response.rb`, `app/services/csat_survey_service.rb`.

### 2.9 Agent Bot framework — **7.2**
- Cơ chế bot xử lý trước rồi **bàn giao cho người** (handoff) khi cần. Alpha CRM đã có `chatbot-knowledge` → đây là khung điều phối bot↔người chuẩn hơn. File: `app/models/agent_bot.rb`.

### 2.10 Help Center / Portal — **7.0**
- Knowledge base công khai (categories → articles, đa ngôn ngữ). Dùng được cho FAQ khách hàng hoặc tài liệu nội bộ. File: `app/models/portal.rb`, `article.rb`, `category.rb`.

### 2.11 Teams + Auto-assignment — **7.0**
- Nhóm agent + tự động chia hội thoại (round-robin, giới hạn tải mỗi người). Hợp khi có nhiều nhân viên trực chung 1 tài khoản Zalo doanh nghiệp. File: `app/models/team.rb`, `app/services/auto_assignment/`.

### 2.12 SLA policy — **6.5** (EE)
- Cam kết thời gian phản hồi/giải quyết, đếm ngược + cảnh báo quá hạn. Giá trị rõ nhưng cần Teams + Reporting làm nền trước. File: `enterprise/app/services/sla/`, `enterprise/app/jobs/sla/`.

### 2.13 Captain AI (Copilot) — **6.6** (EE)
- Trợ lý AI gợi ý câu trả lời, tóm tắt hội thoại, tự trả lời từ KB. Alpha Studio **đã có hạ tầng LLM** (`openclaw-server` / gcli-proxy) → có thể tái dùng thay vì dựng mới. Điểm phù hợp bị hạ vì cần KB chất lượng + chi phí token. File: `enterprise/app/services/captain/`, `enterprise/app/services/llm/`.

---

## 3. ToolJet — phân tích chi tiết

ToolJet là loại sản phẩm **khác hẳn** (low-code builder), nên phần lớn lõi của nó (canvas kéo-thả, query panel, 45 connector) **không phù hợp** để bê vào một CRM Flutter dọc nghiệp vụ. Giá trị nằm ở các **module hạ tầng quản trị** đã được làm chỉn chu.

### 3.1 Audit Logs — **7.3** ⭐ (module hợp nhất)
- **Là gì:** ghi lại mọi thao tác người dùng (ai, làm gì, khi nào, IP) — `server/src/modules/audit-logs`.
- **Vì sao hợp:** Alpha CRM thực hiện hành động **rủi ro cao** (gửi hàng loạt, kết bạn SĐT, quét nhóm). Một sổ nhật ký thao tác là cực kỳ giá trị cho minh bạch + truy vết sự cố + bằng chứng tuân thủ. Backend Node đã có SQLite → thêm bảng `audit_log` rất rẻ.

### 3.2 RBAC / Group Permissions — **7.0**
- Phân quyền theo nhóm/vai trò chi tiết (`group-permissions`, `roles`, `casl`/ability). Hợp khi CRM có nhiều người dùng với mức truy cập khác nhau (ai được gửi bulk, ai chỉ xem). Học mô hình CASL ability thay vì hard-code role.

### 3.3 White-labelling / Custom domain — **5.3**
- Đổi logo/brand/domain (`white-labelling`, `custom-domains`, `custom-styles`). Chỉ đáng làm nếu bán CRM dạng SaaS đa khách hàng — hiện chưa phải hướng.

### 3.4 Email module (SMTP) — tham chiếu kỹ thuật
- ToolJet có `modules/email` + `modules/smtp` + plugins `smtp`, `sendgrid`, `amazonses`, `mailgun`. **Đáng đọc làm tham chiếu** cho phần Email bên dưới (cấu hình SMTP per-org, transactional email). Nhưng nó là email **gửi đi/thông báo**, không phải email **2 chiều thành hội thoại** như Chatwoot.

### 3.5 Dashboard builder / Data-source plugins — **4.5–5.3** (không khuyến nghị)
- Canvas kéo-thả + 45 connector là điểm mạnh của ToolJet nhưng **trùng mục tiêu sản phẩm sai**. Alpha CRM cần dashboard nghiệp vụ cố định, không cần builder generic. Bỏ qua; nếu cần biểu đồ thì `fl_chart` hiện có là đủ.

### 3.6 Đáng học về mặt kiến trúc (không phải "feature")
- **Workflows engine** (`modules/workflows`) — mô hình node-based để chạy chuỗi xử lý nền; ý tưởng tham khảo cho Automation Rules nâng cao.
- **Background-processor / queue** — tách tác vụ nặng (gửi bulk) ra worker. Alpha CRM đã có scheduled campaigns SQLite; mô hình queue của ToolJet là tham chiếu tốt khi scale.

---

## 4. Tích hợp Facebook — phân tích sâu

> Hướng sản phẩm chính là **personal Zalo first**, nên Facebook là **kênh thứ hai tùy chọn**, không thay thế Zalo. Đánh giá dưới đây giả định mục tiêu: gom tin nhắn Facebook Page vào cùng inbox Live Chat.

### Chatwoot làm thế nào (tham chiếu chuẩn)
- Model: `app/models/channel/facebook_page.rb` (+ `instagram.rb`).
- Service: `app/services/facebook/` — dùng **Messenger Platform API chính thức** qua Facebook App + Page Access Token, nhận tin qua **webhook**, gửi tin qua Graph API.
- Đặc điểm: **OAuth + webhook công khai**, cần Facebook App đã review quyền `pages_messaging`.

### Hai lựa chọn cho Alpha CRM

| Phương án | Mô tả | V | F | E | Ưu tiên | Ghi chú |
|-----------|-------|---|---|---|---------|---------|
| **A. Messenger API chính thức** (kiểu Chatwoot) | Facebook App + Page token + webhook → backend Node nhận/gửi | 9 | 7 | 5 | **7.3** | Bền vững, đúng ToS. Cần domain public cho webhook (backend chạy local → cần tunnel/ngrok như openclaw-server đã làm) + review app. |
| **B. Tự động hóa Facebook cá nhân** (kiểu zca-js) | Reverse-engineer như cách làm với Zalo | 8 | 4 | 3 | **5.2** | **Không khuyến nghị.** Rủi ro khóa tài khoản cao, không có thư viện ổn định tương đương zca-js, vi phạm ToS rõ ràng hơn Zalo. |

**Khuyến nghị:** chọn **Phương án A**. Kiến trúc:
```
Facebook Page ──webhook──▶ zalo-bot-service (Node) ──▶ SQLite live-chat ──▶ Flutter inbox
Flutter gửi ──▶ backend ──▶ Graph API Send ──▶ Facebook
```
Tái dùng được: lớp `LiveChatLocalBridgeApi`, hệ thống hội thoại SQLite, tunnel public sẵn có. Cần thêm: bảng channel `facebook_page` (lưu page token mã hóa trong `secure-store.ts`, **không** để Flutter giữ token), adapter gửi/nhận.

**Cảnh báo tuân thủ:** Messenger có **cửa sổ 24h** (chỉ nhắn tự do trong 24h kể từ tin cuối của khách), ngoài ra phải dùng message tag. Automation gửi Facebook phải tôn trọng giới hạn này — thêm guard tương tự `zalo_compliance_guard.dart`.

---

## 5. Tích hợp Email — phân tích sâu

### Chatwoot làm thế nào (tham chiếu chuẩn — đây là model nên theo)
- Model: `app/models/channel/email.rb`.
- Nhận: `app/services/imap/` + `app/services/mailbox/` — poll IMAP, parse email thành **tin nhắn trong hội thoại** (mỗi email reply nối vào conversation theo `In-Reply-To`/`References`).
- Gửi: `app/services/email_templates/`, mailer — gửi qua SMTP, reply email map ngược vào conversation.
- Điểm hay: email được đối xử **y như một kênh chat** → cùng một inbox, cùng canned response/label/automation.

### Hai mức tích hợp cho Alpha CRM

| Mức | Mô tả | V | F | E | Ưu tiên |
|-----|-------|---|---|---|---------|
| **E1. Email 2 chiều thành hội thoại** (kiểu Chatwoot) | IMAP poll nhận + SMTP gửi, thread vào conversation | 9 | 7 | 6 | **7.5** |
| **E2. Email thông báo/transactional** (kiểu ToolJet) | Chỉ gửi đi: thông báo hệ thống, kết quả chiến dịch, OTP | 6 | 8 | 8 | **7.0** |

**Khuyến nghị lộ trình:** làm **E2 trước** (rẻ, dùng được ngay cho thông báo + báo cáo chiến dịch qua email), rồi **E1** khi muốn biến email thành kênh chăm sóc khách thật sự.

Kiến trúc E1 (tái dùng tối đa hạ tầng Node hiện có):
```
IMAP inbox ──poll (node-imap)──▶ parse (mailparser) ──▶ SQLite live-chat (channel=email)
Flutter compose reply ──▶ backend ──▶ SMTP (nodemailer) ──▶ khách
```
- Lưu credentials IMAP/SMTP trong `secure-store.ts` (mã hóa, 0600) — **không** ở Flutter, đúng nguyên tắc "backend owns all credentials".
- Thread email bằng header `Message-ID` / `In-Reply-To` để nối đúng hội thoại.
- Thư viện đề xuất: `imapflow` + `mailparser` + `nodemailer` (đều thuần Node, không cần dịch vụ ngoài).

**Lưu ý:** với Gmail/Outlook nên dùng **OAuth2** thay vì mật khẩu ứng dụng để bền hơn; ToolJet `modules/email-listener` là tham chiếu cho phần listener.

---

## 6. Lộ trình đề xuất (theo điểm ưu tiên + chi phí)

### Giai đoạn 1 — Năng suất Inbox (rẻ, giá trị cao, không đổi kiến trúc)
1. Canned Responses (nâng cấp từ quick reply hiện có) — **9.0**
2. Labels/Tags + Saved Filters — **8.8**
3. Contact Notes + Timeline — **8.4**
4. Custom Attributes — **8.8**

### Giai đoạn 2 — Tự động hóa & Quản trị
5. Automation Rules (gắn vào listener zca-js, qua compliance guard) — **8.2**
6. Macros — **8.0**
7. Audit Logs (ToolJet model) — **7.3**
8. Reporting/Metrics thật cho Dashboard — **7.8**

### Giai đoạn 3 — Kênh mới (mở rộng omnichannel)
9. Email E2 (thông báo) → E1 (2 chiều) — **7.0 → 7.5**
10. Facebook Page Messenger (Phương án A, API chính thức) — **7.3**

### Giai đoạn 4 — Nâng cao (khi có nền tảng)
11. CSAT, Teams + Auto-assign, Agent Bot handoff, RBAC chi tiết
12. Captain-style AI Copilot (tái dùng openclaw-server LLM)
13. SLA (sau khi có Teams + Reporting)

### Loại khỏi phạm vi (không phù hợp hiện tại)
- ToolJet dashboard builder / 45 data-source plugins / app versioning / git-sync — sai mục tiêu sản phẩm.
- Facebook qua reverse-engineer tài khoản cá nhân — rủi ro tuân thủ quá cao.
- White-labelling/custom domain — chỉ cần nếu chuyển sang SaaS đa khách hàng.

---

## 7. Nguyên tắc xuyên suốt khi tích hợp

1. **Backend giữ mọi credential** (Page token, IMAP/SMTP, OAuth) trong `secure-store.ts`; Flutter không bao giờ chạm secret — đúng quy ước hiện có.
2. **Mọi hành động gửi tự động** (Automation, bot, bulk qua email/FB) phải đi qua rate-limit + cooldown + compliance guard; tôn trọng cửa sổ 24h của Messenger.
3. **Tái dùng SQLite live-chat + LiveChatLocalBridgeApi** làm lớp hội thoại chung cho mọi kênh (Zalo/Email/Facebook) thay vì dựng store riêng từng kênh.
4. **Học kiến trúc rollup của Chatwoot** cho Reporting để không quét lại toàn bộ tin nhắn mỗi lần render dashboard.
5. **Channel adapter pattern**: trừu tượng hóa "gửi/nhận tin" để thêm kênh mới (Email, FB) chỉ là một adapter, không sửa lõi inbox.
