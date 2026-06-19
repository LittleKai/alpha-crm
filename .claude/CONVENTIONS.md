# Project Conventions

**Last Updated:** 2026-05-30 22:30:39 +07:00

---

## File & Folder Naming

### Files

- Dart files: `snake_case.dart`.
- Screens: `<feature>_screen.dart` or `<feature>_screen_placeholder.dart`.
- Providers: `<feature>_provider.dart`.
- Theme files: `app_<token_group>.dart`.
- Mock files: `mock_<domain>.dart`.
- Tests: `<subject>_test.dart`.

### Folders

- `lib/app/` for app-wide routing, shell, and theme.
- `lib/features/<feature>/presentation/screens/` for feature screens.
- `lib/features/<feature>/providers/` for Riverpod feature state.
- `lib/shared/widgets/` for reusable UI components.
- `lib/shared/utils/` for shared helpers.
- `lib/mock/` for reusable mock models/data.

**Examples:**

```text
lib/app/routing/app_router.dart
lib/app/theme/app_colors.dart
lib/features/customers/presentation/screens/customers_screen.dart
lib/features/customers/providers/customers_provider.dart
lib/shared/widgets/app_button.dart
lib/mock/mock_contacts.dart
test/widget_test.dart
```

---

## Component Structure

### Typical Flutter Screen Pattern

```dart
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersProvider);
    final notifier = ref.read(customersProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          ResponsiveBreakpoints.isMobile(context) ? AppSpacing.m : AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.l),
            _buildContent(state, notifier),
          ],
        ),
      ),
    );
  }
}
```

### Typical Provider Pattern

```dart
class CustomersState {
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const CustomersState({
    required this.searchQuery,
    required this.isLoading,
    this.errorMessage,
  });

  CustomersState copyWith({
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CustomersState(
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final customersProvider =
    StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
  return CustomersNotifier();
});
```

### Component Organization

```text
FeatureName/
  presentation/
    screens/
      feature_screen.dart
      feature_screen_placeholder.dart
  providers/
    feature_provider.dart
```

For large screens, private helper widgets can live in the same file if they are used only there:

```dart
class _Header extends StatelessWidget { ... }
class _ConfigPanel extends StatelessWidget { ... }
class _NumberField extends StatelessWidget { ... }
```

Extract to `presentation/widgets/` only when a widget is reused across multiple files in the same feature.

---

## Code Style

### Imports Order

```dart
// 1. Dart SDK imports
import 'dart:async';

// 2. Flutter and package imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 3. App/theme/mock/shared imports
import '../../../../app/theme/app_colors.dart';
import '../../../../mock/mock_contacts.dart';
import '../../../../shared/widgets/app_card.dart';

// 4. Local feature imports
import '../../providers/customers_provider.dart';
```

### Spacing & Formatting

- Indentation: 2 spaces, Dart formatter style.
- Line length: follow `dart format`; long expressions are split by formatter.
- Quotes: single quotes in Dart code.
- Semicolons: required by Dart.
- Trailing commas: use where they improve formatter output for multi-line widget trees.
- Constructors: prefer `const` where possible.

---

## TypeScript Conventions

This project does not use TypeScript.

Equivalent Dart conventions:

- Classes and widgets: `PascalCase`.
- Fields, variables, functions, methods: `camelCase`.
- Constants: lower camel for static constants inside token classes, for example `AppColors.primary`.
- Private declarations: leading underscore.
- Provider variables: `<name>Provider`.

**Examples:**

```dart
class AppColors {
  static const Color primary = Color(0xFF2563EB);
}

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
```

---

## Styling Conventions

### Token Usage

- Use `AppColors` for all shared palette values.
- Use `AppSpacing` for spacing, radius, and common gaps.
- Use `AppTextStyles` for page, section, card, body, label, and caption text.
- Use `AppTheme.lightTheme` through `MaterialApp.router`.

### Widget Styling Pattern

```dart
Container(
  padding: const EdgeInsets.all(AppSpacing.m),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppSpacing.borderRadiusM,
    border: Border.all(color: AppColors.border, width: 1),
  ),
  child: Text(title, style: AppTextStyles.sectionTitle),
)
```

### UI Rules
### Dialogs
- Do not use the default `AlertDialog` for complex forms or selections.
- Use the standard `AppDialog` widget (or `Dialog` with custom container using `AppColors.surface` and `AppSpacing.borderRadiusM` with `clipBehavior: Clip.antiAlias`).
- All dialogs must feature the premium dark/slate gradient header (`0xFF0F172A` to `0xFF1E293B`) with white text (title size 19 bold, subtitle size 11.5 with 85% opacity), an un-boxed white icon (size 28), and a white close button.
- The footer / actions section should have `AppColors.appBackground` background, a top border of `AppColors.borderSoft`, and `horizontal: AppSpacing.xl, vertical: AppSpacing.m` padding to ensure a standardized, high-fidelity experience.
- **Zalo Compliance Warnings:** Never use Flutter's default `AlertDialog` or `showDialog` to display compliance warnings or safety recommendations. Instead, always import and use `showComplianceWarningsDialog` from `lib/shared/widgets/compliance_warnings_popup.dart`.


- Desktop CRM layout should be dense, structured, and work-focused.
- Cards use white surface, `AppColors.border`, and radius near 8px.
- Use shared widgets before creating local versions.
- Keep mobile layouts stacked and avoid overflow.
- Avoid large speculative UI not present in `img/*.png`.

### Chatbot Knowledge Attachments (Tài liệu kiến thức)

`_showKnowledgeDialog` in `lib/features/messaging/chatbot/presentation/screens/chatbot_screen.dart`:
- Attachments support **4 media groups** (`image`, `video`, `audio`, `file`) via the
  `KnowledgeAttachmentType` enum; a file's group is **derived from its extension**
  (`_attachmentTypeOf`), not stored. Auto-grouped after upload, no fixed file-count cap,
  the "Chọn thêm file" button is multi-select and repeatable.
- **Files are stored LOCALLY by the bridge, not on B2.** Upload goes to the local bridge
  `POST /local/chatbot/knowledge-file` (via `ChatbotLocalBridgeApi.uploadKnowledgeFile`),
  which writes `<bridge>/.data/chatbot-knowledge/<id><ext>` and returns a content-hash `id`.
  The cloud only ever stores **name + type + description + id** (never the bytes/URL).
- Knowledge docs serialize each file as `- [File] Tên: NAME | ID: <id> | Mô tả: DESC`
  (legacy `| URL: ... |` entries parse with an empty id → shown as "missing").
- The bridge sends a file by resolving `id → local path` at send time (no download). If the
  file is absent on this machine (e.g. attached on another device), the send is skipped and
  the knowledge tab flags it: `_knowledgeIdsPresent` (from `GET /local/chatbot/knowledge-files`)
  drives a red "thiếu file" chip. Refresh it after the dialog closes.
- The AI never types filenames: the backend (`/crm/agent/chatbot/generate`) gives the model a
  catalog with `[[SEND:Fx]]` markers, resolves them to `{id,name,type}`, and strips both the
  markers and any stray `[File]…` text before returning `{reply, attachments}`.

---

## Naming Conventions

### Variables

- Booleans: `isMobile`, `isLoading`, `hasActiveAccount`, `useColumns`.
- Text controllers: `_searchController`, `_linksController`.
- Notifiers: `notifier` when local to a build method, otherwise `<feature>Notifier`.
- State values: `state`, or more specific names if multiple providers are watched.

### Functions

- Event handlers and setters: `setSelectedTab`, `setSearchQuery`, `toggleContactSelection`.
- Build helpers: `_buildHeader`, `_buildToolbar`, `_buildConfigCard`.
- Provider actions: imperative verbs such as `loadContacts`, `saveSettings`, `startSending`, `stopSending`.

---

## Testing

### Test File Naming

```text
test/widget_test.dart
```

### Current Test Pattern

```dart
testWidgets('App shell and routing smoke test', (WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const ProviderScope(child: MyApp()));
  await tester.pumpAndSettle();

  expect(find.text('CRM ZALO'), findsOneWidget);
});
```

### Test Expectations

- Add widget tests for shared widgets when changing public behavior.
- Add feature tests for provider transitions when implementing real workflows.
- Keep smoke tests at realistic viewport sizes for responsive shell checks.

---

## Do / Don't

### Do:

- Use `const` constructors for static widgets.
- Keep feature changes in the relevant feature folder.
- Use Riverpod providers for feature state that affects rendering.
- Store reusable mock records in `lib/mock/`.
- Preserve route paths unless a task explicitly changes routing.
- Run `flutter analyze` and `flutter test` before reporting completion.

### Don't:

- Do not create backend calls in the mock UI phase.
- Do not change theme tokens or shared widget APIs casually.
- Do not place large mock lists inside widget `build` methods.
- Do not read the whole architecture graph file if `.understand-anything` exists.
- Do not use documentation as recent changes, changelog, change history, last 3 sessions, or bug-fix log storage.

---

**Note:** These conventions are derived from the current codebase. When in doubt, follow the nearest similar file.

