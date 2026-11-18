import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/customers/providers/customers_provider.dart';
import '../../features/messaging/live_chat/providers/live_chat_provider.dart';
import '../../features/security/providers/app_lock_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/tasks/providers/crm_tasks_provider.dart';
import '../../shared/widgets/app_dialog.dart';
import '../routing/app_routes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_tokens.dart';
import 'app_shell_providers.dart';
import 'nav_item_models.dart';

bool _isCommandPaletteOpen = false;

Future<void> showCommandPaletteDialog(BuildContext context) async {
  if (_isCommandPaletteOpen) return;
  _isCommandPaletteOpen = true;
  try {
    await showStandardDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const CommandPaletteDialog(),
    );
  } finally {
    _isCommandPaletteOpen = false;
  }
}

class _PaletteEntry {
  final String id;
  final String title;
  final String subtitle;
  final String groupLabel;
  final IconData icon;
  final String? badge;
  final VoidCallback onExecute;

  const _PaletteEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.groupLabel,
    required this.icon,
    this.badge,
    required this.onExecute,
  });
}

class CommandPaletteDialog extends ConsumerStatefulWidget {
  const CommandPaletteDialog({super.key});

  @override
  ConsumerState<CommandPaletteDialog> createState() =>
      _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  int _selectedIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _normalize(String input) {
    var str = input.toLowerCase().trim();
    const vietnamese =
        'aáàảãạâấầẩẫậăắằẳẵặeéèẻẽẹêếềểễệiíìỉĩịoóòỏõọôốồổỗộơớờởỡợuúùủũụưứừửữựyýỳỷỹỵdđ';
    const english =
        'aaaaaaaaaaaaaaaaaaeeeeeeeeeeeeiiiiiioooooooooooooooooouuuuuuuuuuuuyyyyyydd';
    assert(vietnamese.length == english.length);
    for (int i = 0; i < vietnamese.length; i++) {
      str = str.replaceAll(vietnamese[i], english[i]);
    }
    return str;
  }

  String _digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

  void _navigateTo(String route) {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    router?.go(route);
  }

  List<_PaletteEntry> _buildEntries(String normalizedQuery) {
    final List<_PaletteEntry> entries = [];

    // 1. Quick Actions
    final currentTheme = ref.read(settingsProvider).settings.appThemeMode;
    final nextTheme = currentTheme == 'dark' ? 'light' : 'dark';
    final quickActions = <_PaletteEntry>[
      _PaletteEntry(
        id: 'action_toggle_theme',
        title: 'Chuyển giao diện Sáng / Tối',
        subtitle: currentTheme == 'dark'
            ? 'Đang dùng Dark Mode — bấm để chuyển Light Mode'
            : 'Đang dùng Light Mode — bấm để chuyển Dark Mode',
        groupLabel: 'Hành động nhanh',
        icon: Icons.brightness_6_outlined,
        badge: 'Theme',
        onExecute: () {
          Navigator.of(context).pop();
          unawaited(
            ref.read(settingsProvider.notifier).setAppThemeMode(nextTheme),
          );
        },
      ),
      _PaletteEntry(
        id: 'action_toggle_sidebar',
        title: 'Thu gọn / Mở rộng thanh điều hướng trái',
        subtitle: 'Chuyển đổi chế độ rail gọn (Ctrl+\\)',
        groupLabel: 'Hành động nhanh',
        icon: Icons.view_sidebar_outlined,
        onExecute: () {
          final current = ref.read(sidebarCollapsedProvider);
          persistSidebarCollapsed(ref, !current);
          Navigator.of(context).pop();
        },
      ),
      _PaletteEntry(
        id: 'action_lock_app',
        title: 'Khóa ứng dụng',
        subtitle: 'Bật màn hình khóa bảo mật phiên làm việc',
        groupLabel: 'Hành động nhanh',
        icon: Icons.lock_outline_rounded,
        onExecute: () {
          Navigator.of(context).pop();
          ref.read(appLockProvider.notifier).lock();
        },
      ),
    ];

    for (final action in quickActions) {
      if (normalizedQuery.isEmpty ||
          _normalize(action.title).contains(normalizedQuery) ||
          _normalize(action.subtitle).contains(normalizedQuery)) {
        entries.add(action);
      }
    }

    // 2. Navigation Routes
    for (final group in navigationGroups) {
      for (final item in group.items) {
        if (normalizedQuery.isEmpty ||
            _normalize(item.title).contains(normalizedQuery) ||
            _normalize(group.groupName).contains(normalizedQuery) ||
            item.routePath.toLowerCase().contains(normalizedQuery)) {
          entries.add(
            _PaletteEntry(
              id: 'route_${item.routePath}',
              title: item.title,
              subtitle: 'Điều hướng • ${group.groupName}',
              groupLabel: 'Điều hướng',
              icon: item.icon,
              badge: item.routePath,
              onExecute: () => _navigateTo(item.routePath),
            ),
          );
        }
      }
    }

    // 3. CRM Records (lazy-evaluated only when searching so initial open stays instant & side-effect free)
    if (normalizedQuery.isNotEmpty) {
      final customersState = ref.watch(customersProvider);
      final liveChatState = ref.watch(liveChatProvider);
      final tasksState = ref.watch(crmTasksProvider);
      final queryDigits = _digitsOnly(_query);

      for (final contact in customersState.contacts.take(200)) {
        if (_normalize(contact.name).contains(normalizedQuery) ||
            (queryDigits.isNotEmpty &&
                _digitsOnly(contact.phone).contains(queryDigits)) ||
            _normalize(contact.group).contains(normalizedQuery) ||
            _normalize(contact.tag).contains(normalizedQuery)) {
          entries.add(
            _PaletteEntry(
              id: 'contact_${contact.id}',
              title: contact.name,
              subtitle: 'Khách hàng • ${contact.phone} • ${contact.status}',
              groupLabel: 'Khách hàng',
              icon: Icons.person_outline,
              badge: contact.group,
              onExecute: () => _navigateTo(AppRoutes.customers),
            ),
          );
        }
      }

      for (final conv in liveChatState.conversations.take(100)) {
        if (_normalize(conv.customerName).contains(normalizedQuery) ||
            conv.threadId.contains(normalizedQuery) ||
            _normalize(conv.lastMessage).contains(normalizedQuery)) {
          entries.add(
            _PaletteEntry(
              id: 'chat_${conv.threadId}',
              title: conv.customerName,
              subtitle: 'Live Chat • ${conv.lastMessage}',
              groupLabel: 'Live Chat',
              icon: Icons.chat_bubble_outline,
              badge: conv.tag.isNotEmpty ? conv.tag : null,
              onExecute: () => _navigateTo(AppRoutes.messagingLiveChat),
            ),
          );
        }
      }

      for (final task in tasksState.tasks.take(100)) {
        if (_normalize(task.title).contains(normalizedQuery) ||
            _normalize(task.description).contains(normalizedQuery)) {
          entries.add(
            _PaletteEntry(
              id: 'task_${task.id}',
              title: task.title,
              subtitle: 'Công việc • ${task.description}',
              groupLabel: 'Công việc',
              icon: Icons.task_alt_outlined,
              badge: task.priority.toUpperCase(),
              onExecute: () => _navigateTo(AppRoutes.tasks),
            ),
          );
        }
      }
    }

    return entries.take(30).toList();
  }

  void _moveSelection(int delta, int count) {
    if (count == 0) return;
    final next = (_selectedIndex + delta).clamp(0, count - 1);
    if (next == _selectedIndex) return;
    setState(() => _selectedIndex = next);
    if (_scrollController.hasClients) {
      final targetOffset = (next * 46.0 - 92.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(targetOffset);
    }
  }

  void _executeSelected(List<_PaletteEntry> entries) {
    if (entries.isEmpty) return;
    final idx = _selectedIndex.clamp(0, entries.length - 1);
    entries[idx].onExecute();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final entries = _buildEntries(_normalize(_query));
    final int clampedIndex =
        entries.isEmpty ? 0 : _selectedIndex.clamp(0, entries.length - 1);

    return Dialog(
      key: const ValueKey('global_search_panel'),
      backgroundColor: tokens.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tokens.borderMedium, width: 1),
      ),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _moveSelection(1, entries.length),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _moveSelection(-1, entries.length),
            const SingleActivator(LogicalKeyboardKey.enter): () =>
                _executeSelected(entries),
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).pop(),
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: TextField(
                  key: const ValueKey('command_palette_input'),
                  controller: _searchController,
                  focusNode: _inputFocusNode,
                  autofocus: true,
                  style: AppTextStyles.body.copyWith(
                    color: tokens.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm trang, khách hàng, công việc hoặc lệnh...',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: tokens.textTertiary,
                    ),
                    filled: true,
                    fillColor: tokens.surfaceSecondary,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: tokens.textTertiary,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: tokens.textTertiary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _selectedIndex = 0;
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.borderMedium),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.borderMedium),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.accentBlue, width: 1.2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                      _selectedIndex = 0;
                    });
                  },
                  onSubmitted: (_) => _executeSelected(entries),
                ),
              ),
              Divider(height: 1, color: tokens.borderMedium),
              Flexible(
                child: entries.isEmpty
                    ? SizedBox(
                        height: 160,
                        child: Center(
                          child: Text(
                            'Không tìm thấy lệnh hoặc dữ liệu phù hợp.',
                            style: AppTextStyles.body.copyWith(
                              color: tokens.textTertiary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.s),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final selected = index == clampedIndex;
                          return Material(
                            key: selected
                                ? ValueKey('command_palette_item_${index}_selected')
                                : ValueKey('command_palette_item_$index'),
                            color: selected
                                ? tokens.transparentLight
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: tokens.transparentLighter,
                              onTap: entry.onExecute,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.icon,
                                      size: 16,
                                      color: selected
                                          ? tokens.textPrimary
                                          : tokens.textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.title,
                                            style: AppTextStyles.body.copyWith(
                                              color: tokens.textPrimary,
                                              fontSize: 13,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            entry.subtitle,
                                            style: AppTextStyles.caption.copyWith(
                                              color: tokens.textTertiary,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (entry.badge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.surfaceQuaternary,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          entry.badge!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: tokens.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Divider(height: 1, color: tokens.borderMedium),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _KbdHint(label: '↑↓', text: 'Chọn', tokens: tokens),
                    const SizedBox(width: 14),
                    _KbdHint(label: '↵', text: 'Mở', tokens: tokens),
                    const SizedBox(width: 14),
                    _KbdHint(label: 'Esc', text: 'Đóng', tokens: tokens),
                    const Spacer(),
                    Text(
                      'Ctrl+K',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KbdHint extends StatelessWidget {
  final String label;
  final String text;
  final AppThemeTokens tokens;

  const _KbdHint({
    required this.label,
    required this.text,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: tokens.surfaceQuaternary,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tokens.borderStrong, width: 0.6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
      ],
    );
  }
}
