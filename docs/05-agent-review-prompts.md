# 05 - Agent Review Prompts

Mỗi prompt bên dưới dùng khi người dùng yêu cầu `Review AGENT-XX`.

## REVIEW FOR TASK: AGENT-00-ProjectSetup

Bạn là senior Flutter reviewer. Hãy review task AGENT-00 dựa trên: `docs/00-image-analysis.md`, `docs/01-design-system.md`, `docs/02-architecture.md`, `docs/04-agent-tasks.md`, code đã tạo/sửa.

Kiểm tra: đúng task, không sửa ngoài scope, Flutter project chạy được, dependencies đúng, folder structure đúng, compile/lint sạch, không implement UI feature sớm.

Output gồm: PASS hoặc NEEDS_CHANGES; lỗi nghiêm trọng; lỗi kiến trúc; file cần sửa; patch suggestion nếu có; checklist hoàn thành.

## REVIEW FOR TASK: AGENT-01-DesignSystem

Bạn là senior Flutter reviewer. Hãy review task AGENT-01 dựa trên docs, ảnh trong `/img`, và code theme/shared primitive.

Kiểm tra: màu, typography, spacing, radius, shadow có bám `docs/01-design-system.md`; không hard-code tràn lan; không sửa feature/routing; analyzer sạch.

Output gồm: PASS hoặc NEEDS_CHANGES; lỗi UI so với ảnh; lỗi kiến trúc; file cần sửa; patch suggestion; checklist.

## REVIEW FOR TASK: AGENT-02-AppShell

Review AppShell/sidebar/topbar theo `img/*.png`, đặc biệt sidebar desktop và active state.

Kiểm tra: sidebar 250px, grouped menu, active nav, breadcrumb, responsive desktop/tablet/mobile, không sửa route/feature ngoài scope, analyzer sạch.

Output gồm PASS hoặc NEEDS_CHANGES và các danh sách lỗi theo format chuẩn.

## REVIEW FOR TASK: AGENT-03-Routing

Review routing theo `docs/02-architecture.md`.

Kiểm tra: đầy đủ route path, parent shell, breadcrumb metadata, menu điều hướng được, không đổi theme/shared, placeholder không lấn sang implementation feature, analyzer sạch.

Output gồm PASS hoặc NEEDS_CHANGES và checklist route.

## REVIEW FOR TASK: AGENT-04-SharedWidgets

Review shared widgets theo design system và nhu cầu component trong `docs/00-image-analysis.md`.

Kiểm tra: button/card/input/table/empty/tabs/alert/badge reusable, states loading/empty/error, API không gắn business logic feature, responsive tốt, analyzer sạch.

Output gồm PASS hoặc NEEDS_CHANGES; lỗi UI; lỗi API; file cần sửa.

## REVIEW FOR TASK: AGENT-05-Dashboard

Review Dashboard theo `img/1.tong-quan.png`.

Kiểm tra: chart card, tabs, range buttons, quick actions, guide cards, mock data, states, responsive, chỉ sửa `lib/features/dashboard/**` và mock được phép.

Output gồm PASS hoặc NEEDS_CHANGES; lỗi visual; lỗi architecture; patch suggestion.

## REVIEW FOR TASK: AGENT-06-Customers

Review Customers theo `img/2.crm-khach-hang.png`.

Kiểm tra: stat cards, toolbar, import/export/add buttons, empty state, data/loading/error state, table nếu có, scope file, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-07-Content

Review Content/Tin mẫu theo `img/3.quan-ly-noi-dung.png`.

Kiểm tra: search, add button, empty card, template mock data, no overbuilt modal without image, scope file, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-08-BulkMessaging

Review Bulk Messaging theo `img/4-1.png`.

Kiểm tra: 3-column layout, campaign tabs, target panel, config accordions, alert account missing, editor toolbar/chips, Zalo preview, disabled start, mock data, responsive stack, scope.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-09-LiveChat

Review Live Chat theo `img/4-2.png`.

Kiểm tra: header, account dropdown, refresh button, disconnected empty state, không suy đoán quá mức UI chat data, scope file, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-10-Chatbot

Review Chatbot theo `img/4-3.png`.

Kiểm tra: tabs, create button, empty state, mock rule models, loading/error/data states, scope file, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-11-SendHistory

Review Lịch sử gửi tin theo `img/4-4.png`.

Kiểm tra: 4 stat cards, filter/action toolbar, empty/table states, destructive action style, scope file, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-12-FriendByPhone

Review Kết bạn theo SĐT theo `img/5-1.png`.

Kiểm tra: 2-column layout, target import panel, config card, account alert, delay fields, textarea, checkbox, disabled/validation states, scope file, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-13-FriendByGroup

Review Kết bạn từ Nhóm theo `img/5-2.png`.

Kiểm tra: member panel, scan source tabs, group link input, scan button, config card, empty/scanning/data states, scope, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-14-AutoApprove

Review Tự động Duyệt theo `img/5-3.png`.

Kiểm tra: setting rows, switches, info alert, running accounts panel, disabled account states, scope file, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-15-FriendHistory

Review Lịch sử kết bạn theo `img/5-4.png`.

Kiểm tra: single card layout, empty state, optional table data state, không thêm filter ngoài ảnh, scope, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-16-Groups

Review group management theo `img/6-1.png` đến `img/6-5.png`.

Kiểm tra: 5 route/screen, form panels, list panels, log panels, destructive leave group style, empty/loading/data states, no changes outside `lib/features/groups/**` và mock group, responsive.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-17-Settings

Review Settings theo `img/7.cai-dat-he-thon.png`.

Kiểm tra: account card, proxy input, badge, add account button, delay settings, warning alert, advanced checkbox, vertical scroll, scope file.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-18-MobileResponsive

Review mobile/tablet responsive pass.

Kiểm tra: không overflow ở 390/768/1440 width, sidebar drawer/collapse hợp lý, 2-3 column stack, toolbar wrap, table scroll/card rows, desktop không regress.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-19-PolishCleanup

Review polish cleanup.

Kiểm tra: spacing/màu/typography nhất quán, không đổi route/architecture vô cớ, không xóa behavior, duplicate giảm hợp lý, format/analyze/test.

Output chuẩn PASS/NEEDS_CHANGES.

## REVIEW FOR TASK: AGENT-20-QAReview

Review QA report.

Kiểm tra: reviewer đã đọc docs/ảnh/code, findings có file/line, phân loại lỗi nghiêm trọng/UI/kiến trúc, có kết quả analyze/test hoặc ghi rõ không chạy được.

Output chuẩn PASS/NEEDS_CHANGES cho chính chất lượng review report.
