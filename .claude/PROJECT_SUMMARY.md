# Project Summary

**Last Updated:** 2026-05-30 22:36:00 +07:00  
**Session:** #2 - Readme Writing

---

## 1. Project Overview

- **Type:** Cross-platform CRM UI application for web, Android, and Windows desktop.
- **Tech Stack:** Flutter, Dart SDK 3.10.7, Material 3, Riverpod, GoRouter.
- **Package Manager:** Flutter pub via `pubspec.yaml` and `pubspec.lock`.
- **i18n:** No formal localization solution. Vietnamese UI strings are currently inline; `intl` is used for formatting.
- **State Management:** `flutter_riverpod` with `StateNotifierProvider`, `StateProvider`, and local widget state.
- **Styling:** Central design tokens in `lib/app/theme/` plus reusable widgets in `lib/shared/widgets/`.
- **Deployment:** Not configured. Flutter targets exist for web, Android, and Windows.
- **Knowledge Graph:** `.understand-anything/` is not present. Recommend running `/understand` before large impact analysis work.

---

## 2. File Structure

### Key Directories

```text
android/                     Native Android runner and Gradle config
docs/                        Design, architecture, agent task, and progress docs
img/                         Reference UI screenshots for the CRM app
lib/
  main.dart                   Flutter entry point
  app/                        App shell, routing, theme, responsive scaffold
  features/                   Feature-first CRM screens and providers
  mock/                       Mock domain models and sample/default data
  shared/                     Reusable widgets and responsive utilities
test/                         Flutter widget tests
web/                          Flutter web manifest, icons, and index page
windows/                      Native Windows runner and CMake config
```

### Critical Files

| File | Purpose | Notes |
|------|---------|-------|
| `pubspec.yaml` | Flutter package metadata and dependencies | Uses Dart SDK `^3.10.7`; dependencies include GoRouter, Riverpod, fl_chart, data_table_2, google_fonts, intl. |
| `analysis_options.yaml` | Analyzer and lint configuration | Includes `package:flutter_lints/flutter.yaml`. |
| `lib/main.dart` | Entry point | Wraps `MyApp` in `ProviderScope`; uses `MaterialApp.router`. |
| `lib/app/routing/app_routes.dart` | Route constants | Defines 17 CRM routes. |
| `lib/app/routing/app_router.dart` | GoRouter tree | Root redirects to `/dashboard`; `ShellRoute` wraps CRM screens. |
| `lib/app/shell/responsive_scaffold.dart` | Layout switching | Mobile drawer, tablet collapsed sidebar, desktop sidebar. |
| `lib/app/shell/app_sidebar.dart` | Main navigation | Uses grouped nav items, active state, collapsed mode. |
| `lib/app/theme/app_colors.dart` | Color tokens | Implements design-system colors from `docs/01-design-system.md`. |
| `lib/app/theme/app_spacing.dart` | Spacing and radius tokens | 4/8/12/16/20/24/32/40/48 scale and radius tokens. |
| `lib/app/theme/app_text_styles.dart` | Typography tokens | Inter font via `google_fonts`. |
| `lib/shared/widgets/` | Shared UI primitives | Buttons, cards, inputs, tabs, alerts, badges, tables, logs. |
| `lib/features/**/providers/` | Feature state | Riverpod `StateNotifier` classes for mock interactions. |
| `lib/mock/` | Mock data | Contacts, campaigns, messages, groups, accounts. |
| `test/widget_test.dart` | Smoke test | Verifies app shell and initial dashboard route. |

---

## 3. Architecture & Patterns

### Component Structure

The app follows a feature-first Flutter architecture:

```text
lib/features/<feature>/
  presentation/screens/
  providers/
```

Screens are mostly `StatelessWidget`, `StatefulWidget`, `ConsumerWidget`, or `ConsumerStatefulWidget`. Large feature screens often keep private helper widgets in the same file, named with a leading underscore. Placeholder route files delegate to real screens, for example `DashboardScreenPlaceholder` returns `DashboardScreen`.

### State Management

Riverpod is the standard state layer:

- Feature state uses immutable-ish state classes with `copyWith`.
- Feature notifiers extend `StateNotifier<TState>`.
- App shell uses `StateProvider<bool>` for sidebar collapsed state.
- Some UI-only controls use local `StatefulWidget` state and `TextEditingController`.
- Data is mock/local only; no backend or repository abstraction is wired yet.

### Styling Approach

Styling is token-driven:

- Colors: `AppColors`.
- Spacing/radius: `AppSpacing`.
- Text: `AppTextStyles`.
- Material theme: `AppTheme.lightTheme`.
- Shared widgets compose the tokens for common CRM UI patterns.

Feature code still contains some literal dimensions and labels where screen-specific layout requires it. New code should prefer existing tokens and shared widgets first.

### API Integration

There is no real API integration. Current providers simulate user flows with local state, mock lists, and short `Future.delayed` operations.

### Routing

`GoRouter` is centralized in `lib/app/routing/app_router.dart`.

Routes:

```text
/dashboard
/customers
/content/templates
/messaging/bulk
/messaging/live-chat
/messaging/chatbot
/messaging/history
/friends/by-phone
/friends/by-group
/friends/auto-approve
/friends/history
/groups/scan-members
/groups/join
/groups/invite
/groups/create
/groups/leave
/settings
```

The shell receives the current route and renders sidebar/topbar around each screen.

### Responsive Layout

Breakpoints live in `ResponsiveBreakpoints`:

- Mobile: `<= 649`
- Tablet: `650..1099`
- Desktop: `>= 1100`

Mobile uses a drawer and stacked feature layouts. Tablet uses a collapsed sidebar. Desktop uses fixed sidebar and 2-3 column feature layouts where appropriate.

---

## 4. Active Features & Status

| Feature | Status | Files Involved | Notes |
|---------|--------|----------------|-------|
| Project setup | Completed / Working | `pubspec.yaml`, platform folders, `lib/main.dart` | Flutter project targets web, Android, and Windows. |
| Design system | Completed / Working | `lib/app/theme/**` | Matches documented CRM color/spacing/type tokens. |
| App shell | Completed / Working | `lib/app/shell/**` | Sidebar, topbar, responsive scaffold are implemented. |
| Routing | Completed / Working | `lib/app/routing/**`, placeholder screen wrappers | 17 route paths are configured through a shell route. |
| Shared widgets | Completed / Working | `lib/shared/widgets/**`, `lib/shared/utils/**` | Core CRM UI primitives are available. |
| Dashboard | Completed / Mock UI | `lib/features/dashboard/**`, `lib/mock/mock_campaigns.dart` | Zero-state campaign chart and quick actions. |
| Customers | Completed / Mock UI | `lib/features/customers/**`, `lib/mock/mock_contacts.dart` | Empty-first CRM screen with filters and data mode. |
| Content templates | Completed / Mock UI | `lib/features/content/**`, `lib/mock/mock_messages.dart` | Search/add action and empty-first template UI. |
| Messaging | Completed / Mock UI | `lib/features/messaging/**`, `lib/mock/mock_campaigns.dart`, `lib/mock/mock_messages.dart` | Bulk messaging, live chat, chatbot, send history screens. |
| Friends | Completed / Mock UI | `lib/features/friends/**` | Phone/group friend campaign screens and history/approval placeholders with real UI. |
| Groups | Completed / Mock UI | `lib/features/groups/**`, `lib/mock/mock_groups.dart` | Scan, join, invite, create, and leave group screens. |
| Settings | Completed / Mock UI | `lib/features/settings/**`, `lib/mock/mock_accounts.dart` | Account/proxy/time/advanced settings UI. |
| Mobile responsive pass | Completed / Working | `lib/app/shell/**`, feature presentation files, `lib/shared/widgets/app_tabs.dart` | Stack/wrap patterns are present; manual device sweep remains useful. |
| QA review | Completed / Approved in docs | `docs/06-progress-tracker.md` | Existing tracker marks AGENT-00 through AGENT-21 approved. |

**Legend:**
- Planning / Not Started
- In Progress / Incomplete
- Completed / Working
- Completed / Mock UI

---

## 5. Known Issues & TODOs

### High Priority

- [ ] Run `/understand` to create `.understand-anything/knowledge-graph.json` before major cross-module refactors or impact analysis.
- [ ] Perform a manual viewport sweep on real browser/device widths after future UI changes: 390px, 768px, 1440px.

### Medium Priority

- [ ] Decide whether Vietnamese UI strings should move to a formal localization layer.
- [ ] Replace mock-only providers with repository/API contracts when backend requirements are defined.
- [ ] Add targeted widget tests for high-risk shared widgets and feature forms beyond the current smoke test.

### Low Priority / Nice to Have

- [ ] Add real app branding assets if the project needs a production web/mobile manifest.
- [ ] Review inline screen-specific dimensions and extract shared layout helpers only where duplication becomes meaningful.

---

## 6. Dependencies & External Resources

### Key Dependencies

- `flutter` - UI framework.
- `cupertino_icons` - Cupertino icon font.
- `go_router` - Declarative routing and shell route setup.
- `flutter_riverpod` - App and feature state management.
- `fl_chart` - Dashboard campaign performance chart.
- `data_table_2` - Desktop-friendly table component.
- `google_fonts` - Inter typography.
- `intl` - Date/number formatting.
- `flutter_lints` - Recommended lint rules.

### External APIs / Services

- None currently wired.
- Zalo account, messaging, group, and CRM actions are represented by mock data only.

### External Assets

- `img/*.png` - Reference screenshots used as source of truth for UI implementation.
- `web/icons/*.png` and `web/favicon.png` - Default Flutter web icons.
- `windows/runner/resources/app_icon.ico` - Windows runner icon.

---

## 7. Important Notes for Claude

### When making changes to:

- **Routing:** Keep route constants in `AppRoutes` and update `app_router.dart` only when route behavior changes.
- **Theme:** Use existing `AppColors`, `AppSpacing`, and `AppTextStyles`. Avoid hard-coded theme values unless they are screen-specific and justified.
- **Shared widgets:** Preserve public constructor APIs unless all usage sites are updated and verified.
- **Feature screens:** Keep changes inside the relevant `lib/features/<feature>/` module unless the task explicitly authorizes shared/app-layer edits.
- **Mock data:** Put reusable sample/default data in `lib/mock/`; do not embed large lists directly inside `build`.
- **Responsive UI:** Preserve mobile stack, tablet collapsed sidebar, and desktop multi-column behavior.

### Testing checklist:

- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] For UI changes, inspect desktop, tablet, and mobile widths.
- [ ] For routing changes, navigate all affected sidebar routes.

### Don't forget to:

- Update this file's timestamp and session number.
- Follow `.claude/CONVENTIONS.md`.
- Keep documentation current-state only.
- Record only high-impact or likely-to-recur fixed bugs in `.claude/IMPORTANT_FIXED_BUGS.md`.

---

## 8. Quick Commands

```bash
# Development
flutter pub get
flutter run -d chrome
flutter run -d windows

# Analysis
flutter analyze

# Test
flutter test

# Build examples
flutter build web
flutter build apk
flutter build windows
```

---

**Critical:** Read this entire file before making any changes to the project.
