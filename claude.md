# Instructions for Claude Code

---

## Core Principle

Read `.claude/PROJECT_SUMMARY.md` first, not the entire codebase.
Update documentation after every change.
Use the skill in `C:\Users\XEON\.gemini\skills\flutter-dev\skill.md`.

---

## Before Any Task

### 1. Read in order

```text
.claude/PROJECT_SUMMARY.md     -> Project state, architecture, active features
Specific files user mentioned  -> Only if needed for implementation
```

### 2. Search in Architecture Knowledge Graph if it exists

- Graph file: `.understand-anything/knowledge-graph.json` if present.
- Do not read the whole graph file directly. It can be very large. Use targeted search only when impact analysis or dependency lookup is needed.
- This project does not currently have `.understand-anything/`. Recommend running `/understand` to create the architecture graph before large refactors.

### 3. Do Not Read by Default

- Do not read the entire `lib/` folder just to understand the project.
- Do not read all components when the summary already covers the relevant architecture.
- Do not read files already summarized in `.claude/PROJECT_SUMMARY.md` unless the task touches them.
- Do not read all of `.understand-anything/knowledge-graph.json`; use targeted search only.

---

## After Any Task

### Update `.claude/PROJECT_SUMMARY.md`

Always update:
- Top `Last Updated` timestamp and session number.
- `Active Features & Status` when feature state changes.
- `Known Issues & TODOs` by marking completed items and adding current issues.

Update if changed:
- `File Structure` when files or folders are added, removed, or moved.
- `Dependencies & External Resources` when dependencies, platforms, APIs, or assets change.

`PROJECT_SUMMARY.md` reflects current project state only. Do not use it for recent changes, changelog, change history, last 3 sessions, or bug-fix log content. If a fixed bug is high-impact, hard to detect, likely to recur, or affects architecture/API/workflow, record it briefly in `.claude/IMPORTANT_FIXED_BUGS.md`.

---

## Reading Priority

```text
1. Always     -> .claude/PROJECT_SUMMARY.md
2. If needed  -> Files mentioned in the user request
3. Rarely     -> Other source files
```

---

## Special Cases

**Review entire project**: Exception. Read all relevant source, config, docs, and assets, then update the full summary.

**Summary outdated**: Ask the user before proceeding if the summary conflicts with source in a way that changes task scope.

**Major refactor**: Update `File Structure` and `Architecture & Patterns` completely.

**PROJECT_SUMMARY.md missing**: Treat as review entire project, then create the summary.

---

## Project Quick Reference

**Tech Stack:** Flutter 3, Dart SDK 3.10.7, Material 3, Riverpod, GoRouter, fl_chart, data_table_2, google_fonts, intl.

**Key Files:**
- `lib/main.dart` - App entry point, wraps `MyApp` in `ProviderScope`.
- `lib/app/routing/app_router.dart` - GoRouter route tree and CRM shell integration.
- `lib/app/shell/` - Sidebar, topbar, responsive scaffold, navigation models.
- `lib/app/theme/` - App color, spacing, typography, and Material theme tokens.
- `lib/shared/widgets/` - Reusable CRM UI primitives.
- `lib/features/` - Feature-first screen and provider modules.
- `lib/mock/` - Mock domain data used by current UI.
- `docs/00-image-analysis.md` - Visual requirements derived from reference images.
- `docs/01-design-system.md` - Design tokens and responsive rules.
- `docs/06-progress-tracker.md` - Agent task status.

**Dev Commands:**

```bash
flutter pub get        # Install Flutter dependencies
flutter analyze        # Static analysis
flutter test           # Widget/unit tests
flutter run -d chrome  # Run web app locally
flutter run -d windows # Run Windows desktop app
```

---

## Documentation Structure

```text
project-root/
  claude.md                         # Instructions for Claude
  .claude/
    PROJECT_SUMMARY.md              # Current project state and architecture
    CONVENTIONS.md                  # Coding standards and patterns
    IMPORTANT_FIXED_BUGS.md          # Important fixed bugs to avoid repeating
    SETUP_REPORT.md                 # One-time setup snapshot
```

---

## Notes for Claude

- This project is a mock-first Flutter CRM UI for Zalo marketing workflows.
- Prioritize visual fidelity to `img/*.png`, the design tokens in `lib/app/theme/`, and the architecture rules in `docs/02-architecture.md`.
- Keep feature changes inside the relevant `lib/features/<feature>/` module unless the task explicitly approves shared/app-layer changes.
- Use Riverpod `StateNotifierProvider` or `StateProvider` for app state, and keep large mock lists in `lib/mock/`, not inside widget build methods.
- When in doubt, ask before structural changes that affect routing, theme tokens, shared widget public APIs, or cross-feature data contracts.

---

## Coding Rules

### 1. Think Before Coding

Do not assume. Do not hide confusion. Surface tradeoffs.

Before implementing:
- State assumptions explicitly when they affect scope.
- If multiple interpretations exist, present them instead of silently choosing.
- If a simpler approach exists, say so.
- If something is unclear and risky, stop and ask.

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No flexibility or configurability that was not requested.
- No error handling for impossible scenarios.
- If code can be materially shorter without losing clarity, simplify it.

### 3. Surgical Changes

Touch only what is required.

- Do not improve adjacent code, comments, or formatting unrelated to the task.
- Do not refactor unrelated code.
- Match existing style, even if a different style is preferred.
- Mention unrelated dead code instead of deleting it.
- Remove only imports, variables, and functions made unused by your own changes.

Every changed line should trace directly to the user request.

### 4. Goal-Driven Execution

Define success criteria and verify them.

For multi-step tasks, state a brief plan:

```text
1. Step -> verify: check
2. Step -> verify: check
3. Step -> verify: check
```

Examples:
- Add validation -> add or update tests for invalid inputs, then make them pass.
- Fix a bug -> reproduce it, fix it, verify the symptom no longer occurs.
- Refactor -> verify tests or analyzer before and after when practical.

---

**Remember:** Documentation is the single source of truth.


---

## Zalo Integration Direction

- For a categorized snapshot of the usable public `zca-js` API surface, read `docs/api-catalog/zca-js-api-catalog.md` before designing new personal-Zalo backend features. It catalogs the local reference repo at `D:\Dev\2.reference_pj\Zalo-ref\zca-js`, including `Zalo` login, the generated `API` facade, listener events, and high-risk API groups.

- Current product direction is personal Zalo first. The Node backend uses the official NPM package `zca-js@^2.1.2` for dependency portability. Khi muốn tìm hiểu thêm về các API hoặc tìm kiếm xem còn API nào khác, nhà phát triển/AI có thể tham khảo mã nguồn tại local repository [zca-js/claude.md](file:///d:/Dev/2.reference_pj/Zalo-ref/zca-js/claude.md) và chạy công cụ CodeGraph tại thư mục đó để tra cứu/phân tích chi tiết.
- Zalo Official Account / OA remains supported as an optional secondary adapter, not the default direction unless the user explicitly asks for official-only mode.
- Backend service owns all Zalo credentials, cookies, IMEI, user-agent values, QR artifacts, access tokens, and listener sessions. Flutter must never store or display these secrets.
- Preferred backend channel names are `personal_zca` for the `zca-js` personal-account adapter, `official_oa` for OA/OpenAPI, and `mock` for local test mode.
- Keep personal-account workflows risk-aware: use rate limits, cooldowns, human approval for high-risk batches, stop conditions, and clear operator status. Do not silently remove safeguards just because personal Zalo is preferred.
- Đối với tất cả màn hình có tính năng tiếp thị hoặc hành động rủi ro cao trên Zalo (Gửi tin hàng loạt, kết bạn qua SĐT/Nhóm, mời/tạo/tham gia nhóm, quét thành viên), luôn hiển thị một nút cảnh báo/an toàn ở Header trang và luôn sử dụng hộp thoại thiết kế riêng biệt `showComplianceWarningsDialog` từ `lib/shared/widgets/compliance_warnings_popup.dart` để hiển thị các khuyến cáo thay vì dùng Dialog mặc định của Flutter.
- Do not reintroduce official-only assumptions into docs, settings, guards, or backend code unless the user explicitly changes the product direction.
- For media/file sends through `zca-js`, remember that file-path image/GIF metadata requires a backend `imageMetadataGetter`; keep that dependency in the Node service, not Flutter.

---
