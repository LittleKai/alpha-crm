# Alpha CRM Reference Analysis

**Date:** 2026-06-04
**Target project:** `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm`
**Reference projects:**
- `D:\Dev\2.reference_pj\Zalo-ref\deplao-builder`
- `D:\Dev\2.reference_pj\Zalo-ref\ZaloCRM`

## 1. Current Alpha CRM Analysis

### Architecture

Alpha CRM is a Flutter 3 CRM client using Dart SDK `^3.10.7`, Material 3, Riverpod, GoRouter, `fl_chart`, `data_table_2`, `google_fonts`, `intl`, and a local Node.js Zalo bot service. The app is feature-first:

- `lib/app/`: routing, shell, sidebar/topbar, theme tokens.
- `lib/features/`: dashboard, customers, messaging, friends, groups, settings, auth, subscription, devices, tasks.
- `lib/shared/widgets/`: reusable app primitives such as cards, buttons, tabs, tables, dialogs, empty states, alerts, and compliance warnings.
- `lib/mock/`: mock records and fallback UI data.
- `integration/zalo-bot-service/`: local Node.js bridge, personal-Zalo-first via `zca-js`.

State management is Riverpod-based, mainly `StateNotifierProvider` and selected `StateProvider`. Routing is centralized in `AppRoutes` and `AppRouter`, with a `ShellRoute` wrapping the CRM shell.

### Main Screens

- Dashboard
- Customers
- Content templates
- Bulk messaging
- Live chat
- Auto chatbot
- Send history
- Friend by phone
- Friend by group
- Auto approve friends
- Friend history
- Scan members
- Join groups
- Invite to group
- Create groups
- Leave groups
- Managed groups
- Follow-up tasks
- Subscription and AI package
- Device pairing
- Settings

### Existing UI Components

The app already has a usable CRM design system:

- Tokens: `AppColors`, `AppSpacing`, `AppTextStyles`, `AppTheme`.
- Primitives: `AppCard`, `AppButton`, `AppBadge`, `AppMetricCard`, `AppSearchField`, `AppSelectField`, `AppTable`, `AppTabs`, `AppDialog`.
- Shell: responsive sidebar/topbar, desktop/tablet/mobile layout switching.
- Safety: custom `showComplianceWarningsDialog` for high-risk Zalo operations.

### Existing CRM Features

- Cloud-backed customer list with search, status/tag/segment filters, add customer, import, export, and saved segments.
- Messaging workflows, live chat, chatbot, quick replies, send history, campaign execution status.
- Group and friend automation workflows with compliance warning entrypoints.
- Subscription/AI quota and device pairing.
- Zalo account integration and local backend health handling.

### UI/UX Weaknesses

- The Customers screen is still mostly table-first. It lacks a CRM pipeline overview, contact detail side panel, and selected-row action bar like mature CRM tools.
- Contact rows are not strongly scannable: no avatar/initials, no inline priority/relationship cues, and limited visual grouping.
- Complex Customers dialogs still use `AlertDialog` instead of the existing `AppDialog` pattern.
- Topbar does not yet provide a project-wide global search or notification center.
- Dashboard has campaign metrics, but not yet the fuller pipeline/source/appointment/order split from ZaloCRM.

### Code Structure Weaknesses

- Some screens are large single files. This is acceptable for current scope, but new reusable contact widgets should be extracted once reused.
- Several filters are split between backend queries and local filtering. This can confuse expectations unless UI labels clearly match data fields.
- Some old placeholder screens still exist even when real screens are routed through placeholders.
- Vietnamese text in several files is stored with encoding artifacts; changes should avoid unnecessary broad copy edits.

### Safe Refactor Areas

- Customers screen presentation and local interaction state.
- Small reusable widgets inside the Customers screen file, if not reused elsewhere yet.
- Dialog conversion to `AppDialog`.
- Documentation and analysis files under `docs/`.

## 2. Reference: deplao-builder

### Technology

Deplao is an Electron desktop application with React 18, TypeScript, Vite, Tailwind CSS, Zustand, SQLite through `better-sqlite3`, zca-js, Facebook modules, local relay services, workflow services, integration adapters, and AI assistant services. It also has a separate React/Vite landing site with Three.js.

### Screens And Flows Worth Referencing

- `CRMPage`: dense multi-tab CRM workspace for dashboard, contacts, campaigns, history, groups, search, and friend requests.
- `CRMContactList`: compact contact rows with selection, filters, sorting, labels, birthday/gender, and message action.
- `CRMContactDetailPanel`: right-side contact panel with identity, labels, notes, and send history tabs.
- `BulkActionBar`: bottom floating action bar for selected contacts.
- `CRMDashboard`: mini statistic cards, activity comparison by period, label distribution, and campaign performance table.
- `GlobalSearchPanel`: Vietnamese-aware normalization, contact/message tabs, phone search, and rich result list.
- `Notification` patterns: compact actionable in-app notifications.

### Valuable Ideas For Alpha CRM

- Contact detail side panel instead of opening every detail as a modal.
- Bulk selection with a contextual bottom bar.
- Pipeline/contact health summary above the table.
- Search that handles Vietnamese text and phone numbers.
- Compact operational dashboard sections rather than large marketing-style cards.
- Account-aware filtering and action affordances.

### Not Suitable To Port As-Is

- Electron IPC, BrowserWindow, tray, SQLite, workspace, and relay architecture.
- Facebook channel surface and ERP modules unless Alpha CRM product scope changes.
- Workflow editor and POS/shipping/payment integration breadth in a single step.
- BrowserView/network-interception mechanics.

## 3. Reference: ZaloCRM

### Technology

ZaloCRM is a full-stack web application:

- Backend: Node.js 20, TypeScript, Fastify 5, Prisma 7, PostgreSQL 16, Socket.IO, zca-js.
- Frontend: Vue 3, TypeScript, Vite, Vuetify 4, Pinia, Vue Router, Chart.js.
- Deployment: Docker Compose with backend serving production frontend assets.

### Screens And Flows Worth Referencing

- `ContactsView`: contact table with create/edit dialog, source/status filters, pagination, assigned user, next appointment, first contact date.
- `ContactDetailDialog`: structured customer form with source, status, tags, notes, appointment date, and delete action.
- `DashboardView`: KPI cards, message volume chart, pipeline chart, source chart, appointment chart, and order KPI cards.
- `ChatView` plus chat contact components: conversation list, thread, contact panel, appointments, orders.
- `GlobalSearch`: topbar search across contacts, messages, and appointments.
- `NotificationBell`: periodic actionable notifications for unreplied messages, appointments, and disconnected Zalo accounts.
- `ReportsView`: reporting and export surface.

### Valuable Ideas For Alpha CRM

- Pipeline/status model: new, contacted, interested, converted, lost.
- Source filter and status filter should be visually clear and quick to adjust.
- Contact detail should carry notes, tags, source, lifecycle/status, and next action date.
- Dashboard should include pipeline/source/appointment/order slices over time.
- Global search and notification should be topbar-level utilities.

### Not Suitable To Port As-Is

- Prisma/PostgreSQL data schema and Fastify route contracts, because Alpha CRM already uses Alpha Studio cloud APIs plus a local Zalo bot service.
- Docker deployment flow.
- Vuetify/Liquid Silicon CSS system as a separate theme.
- Public API/webhook settings until backend contract is intentionally extended.

## 4. Feature Comparison And Integration Table

| Feature / UI / Flow | Source | Description | Value In Alpha CRM | Priority | Difficulty | Integrate? | Technical Notes |
|---|---|---|---|---|---|---|---|
| Customer pipeline summary | ZaloCRM | Status-based customer pipeline with clear lifecycle stages. | Gives operators an immediate view of lead/contact/customer health before table work. | High | Easy | Yes | Can derive from existing `Contact.status` without backend changes. |
| Customer detail side panel | Deplao + ZaloCRM | Click a row to inspect identity, tags/source/status, notes, and quick actions. | Reduces modal churn and makes the Customers screen feel like a CRM workspace. | High | Medium | Yes | Implement locally in Flutter using existing `Contact` model and `AppCard`; no API change. |
| Bulk selection action bar | Deplao | Floating contextual bar when contacts are selected. | Makes multi-contact workflows discoverable and less cluttered. | High | Medium | Yes | Existing `CustomersState.selectedIds` already supports this. Wire visible checkboxes and a bottom bar. |
| AppDialog-based customer forms | Alpha CRM convention + ZaloCRM | Structured create/save dialogs instead of default `AlertDialog`. | Aligns with current project conventions and improves polish. | High | Easy | Yes | Use existing `AppDialog`; no dependency. |
| Source and status chips in table | ZaloCRM | Source and status are visible as chips/badges. | Improves scanability for campaigns and segmentation. | Medium | Easy | Yes | Use `AppBadge`; keep current fields. |
| Global topbar search | ZaloCRM + Deplao | Search contacts/messages/appointments from topbar. | High workflow value across screens. | High | Hard | Later | Needs repository/API support and clear navigation targets. |
| Notification bell | ZaloCRM | Actionable alerts for unreplied conversations, appointments, disconnected accounts. | Helps operators act on urgent items. | Medium | Medium | Later | Should combine dashboard/zalo/chat providers; avoid polling too aggressively. |
| Dashboard pipeline/source/appointment cards | ZaloCRM | KPI + charts for pipeline, sources, appointments, orders. | Better leadership overview than campaign-only chart. | High | Medium | Later | Requires mapping dashboard analytics payloads or adding local derived fallback. |
| Activity comparison by day/week/month | Deplao | Compare conversations/messages against previous periods. | Useful for operational trend review. | Medium | Hard | Later | Requires reliable message/activity data from backend/local service. |
| Contact appointments/orders context | ZaloCRM | Chat/contact panels show appointments and orders. | Strong CRM value beyond messaging. | Medium | Hard | Later | Needs backend/API contract or explicit mock-first scope. |
| Campaign performance table | Deplao | Recent campaigns with success/failure/reply bars. | Good fit for dashboard or send history. | Medium | Medium | Later | Current send history and campaign APIs should be reviewed first. |
| Zalo labels/local labels management | Deplao | Label assignment and filtering in CRM contact list/detail. | Useful, but overlaps with current tags/segments. | Medium | Hard | Later | Needs strict account-specific label model and backend support. |
| Employee/team ACL | ZaloCRM + Deplao | Assign users/teams/accounts and restrict access. | Valuable for multi-operator CRM. | Medium | Hard | Later | Requires backend auth/device/account policy changes; not Flutter-only. |
| Reports and Excel export | ZaloCRM | Message/contact/appointment reports and export. | Useful for operations. | Medium | Medium | Later | Existing export exists for customers; broader reports need API scope. |
| Workflow editor/automation graph | Deplao | Visual automation/workflow engine. | Powerful but much larger than current CRM UI scope. | Low | Hard | No | Too much architecture and backend surface for current Flutter app. |
| ERP/POS/shipping/payment modules | Deplao | Full business operations stack. | Product expansion only, not core Zalo CRM right now. | Low | Hard | No | Would bloat app and introduce unrelated dependencies. |
| BrowserView/network interception | Deplao | Electron-specific browser automation and request hooks. | Not compatible with Flutter architecture. | Low | Hard | No | Alpha CRM uses local `zca-js` backend service instead. |

## 5. Recommended First Integration

The safest high-value first phase is to improve `CustomersScreen`:

- Add a CRM pipeline summary derived from existing customer status.
- Add selectable rows and contextual bulk action bar.
- Add right-side contact detail panel on desktop and modal/detail card behavior on narrow widths.
- Convert save segment and add customer dialogs to `AppDialog`.
- Keep backend/API contracts unchanged.
- Keep all changes in the Customers feature unless a shared widget is clearly reused.

