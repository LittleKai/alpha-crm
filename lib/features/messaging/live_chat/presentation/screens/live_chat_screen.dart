import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../mock/mock_messages.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/app_search_field.dart';
import '../../../../content/providers/templates_provider.dart';
import '../../../../settings/providers/settings_provider.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../data/live_chat_download_service.dart';
import '../../data/live_chat_transport.dart';
import '../../providers/agent_status_provider.dart';
import '../../providers/live_chat_provider.dart';
import '../../utils/live_chat_attachment_view.dart';
import '../../utils/live_chat_local_image_stub.dart'
    if (dart.library.io) '../../utils/live_chat_local_image_io.dart';
import '../../utils/quick_reply_shortcuts.dart';
import '../widgets/live_chat_settings_dialog.dart';

class LiveChatScreen extends ConsumerStatefulWidget {
  const LiveChatScreen({super.key});

  @override
  ConsumerState<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends ConsumerState<LiveChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  bool _showContactPanel = false;
  String? _lastSelectedConversationId;
  int _lastMessageCount = 0;
  // True for the first message paint after switching threads, so we snap to the
  // bottom instantly instead of animating through the freshly loaded list.
  bool _justSwitchedConversation = false;
  Timer? _pollingTimer;
  // Lightweight rebuild so the AI status icon flips from "paused" back to
  // "active" when the operator-pause cooldown elapses (no backend event fires).
  Timer? _statusTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _startStatusTicker();
    Future.microtask(() {
      if (mounted) {
        debugPrint('[LiveChatScreen] Tab active: Setting chat focused to true');
        ref.read(liveChatProvider.notifier).setChatFocused(true);
        ref.read(zaloIntegrationProvider.notifier).checkConnection();
        final target = ref.read(liveChatDeepLinkProvider);
        if (target != null) {
          ref.read(liveChatDeepLinkProvider.notifier).state = null;
          ref
              .read(liveChatProvider.notifier)
              .openByThread(target.accountId, target.threadId);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    final newMessageCount = ref.read(liveChatProvider).unfocusedNewMessageCount;
    ref.read(liveChatProvider.notifier).setChatFocused(resumed);
    if (resumed && newMessageCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$newMessageCount tin nhắn mới')),
        );
      });
    }
  }

  void _startStatusTicker() {
    _statusTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final selected = ref.read(liveChatProvider).selectedConversation;
      // Only rebuild while a pause is pending — flips the icon at expiry.
      if (selected != null && selected.chatbotPausedUntil != null) {
        setState(() {});
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (mounted) {
        final state = ref.read(liveChatProvider);
        final selected = state.selectedConversation;
        if (selected != null && !state.realtimeConnected) {
          ref.read(liveChatProvider.notifier).refreshSelectedMessages();
        }
        if (!state.realtimeConnected) {
          ref.read(liveChatProvider.notifier).loadConversations(silent: true);
        }
      }
    });
  }

  @override
  void dispose() {
    debugPrint('[LiveChatScreen] Tab inactive: Setting chat focused to false');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(liveChatProvider.notifier).setChatFocused(false);
      } catch (_) {}
    });
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _statusTicker?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _tagController.dispose();
    _notesController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _sourceController.dispose();
    _statusController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveChatProvider);
    final notifier = ref.read(liveChatProvider.notifier);
    final selected = state.selectedConversation;

    if (selected != null) {
      if (_lastSelectedConversationId != selected.id) {
        _lastSelectedConversationId = selected.id;
        _lastMessageCount = selected.messages.length;
        _justSwitchedConversation = true;
        _scrollMessagesToBottom(animate: false);
        _tagController.text = selected.displayLabels.join(', ');
        _notesController.text = selected.notes;
        _messageController.text = state.draftText;
        final cust = selected.crmCustomer;
        if (cust != null) {
          _nameController.text = cust.name;
          _phoneController.text = cust.phone;
          _emailController.text = cust.email;
          _sourceController.text = cust.source;
          _statusController.text = cust.status;
        } else {
          _nameController.text = selected.customerName;
          _phoneController.clear();
          _emailController.clear();
          _sourceController.clear();
          _statusController.clear();
        }
      }
      if (_messageController.text.isEmpty && state.draftText.isNotEmpty) {
        _messageController.text = state.draftText;
      }
      final currentMessageCount = selected.messages.length;
      if (currentMessageCount != _lastMessageCount) {
        // After a thread switch the first batch should snap, not animate.
        final justSwitched = _justSwitchedConversation;
        final shouldStickToBottom = justSwitched || _isMessageListNearBottom();
        _lastMessageCount = currentMessageCount;
        _justSwitchedConversation = false;
        if (shouldStickToBottom) {
          _scrollMessagesToBottom(animate: !justSwitched);
        }
      }
    } else {
      _lastSelectedConversationId = null;
      _lastMessageCount = 0;
    }

    final isMobile = ResponsiveBreakpoints.isMobile(context);
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              state: state,
              onRefresh: () {
                notifier.loadAccounts();
                notifier.loadConversations();
                ref.read(zaloIntegrationProvider.notifier).checkConnection();
              },
              onAccountChanged: notifier.selectAccount,
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: isMobile
                  ? _MobileInbox(
                      state: state,
                      notifier: notifier,
                      messageController: _messageController,
                      searchController: _searchController,
                      tagController: _tagController,
                      notesController: _notesController,
                      messageScrollController: _messageScrollController,
                      showContactPanel: false,
                      onToggleContactPanel: () {
                        if (selected != null) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(
                                  context,
                                ).viewInsets.bottom,
                              ),
                              child: Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.75,
                                decoration: BoxDecoration(
                                  color: AppColors.appBackground,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                child: _ContactInfoPanel(
                                  conversation: selected,
                                  notifier: notifier,
                                  nameController: _nameController,
                                  phoneController: _phoneController,
                                  emailController: _emailController,
                                  sourceController: _sourceController,
                                  statusController: _statusController,
                                  tagController: _tagController,
                                  notesController: _notesController,
                                  onClose: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 360,
                          child: _ConversationList(
                            state: state,
                            notifier: notifier,
                            searchController: _searchController,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: _ConversationPanel(
                            state: state,
                            notifier: notifier,
                            messageController: _messageController,
                            tagController: _tagController,
                            notesController: _notesController,
                            messageScrollController: _messageScrollController,
                            showContactPanel: _showContactPanel,
                            onToggleContactPanel: () {
                              setState(() {
                                _showContactPanel = !_showContactPanel;
                              });
                            },
                          ),
                        ),
                        if (_showContactPanel && selected != null) ...[
                          const SizedBox(width: AppSpacing.m),
                          SizedBox(
                            width: 320,
                            child: _ContactInfoPanel(
                              conversation: selected,
                              notifier: notifier,
                              nameController: _nameController,
                              phoneController: _phoneController,
                              emailController: _emailController,
                              sourceController: _sourceController,
                              statusController: _statusController,
                              tagController: _tagController,
                              notesController: _notesController,
                              onClose: () {
                                setState(() {
                                  _showContactPanel = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isMessageListNearBottom() {
    if (!_messageScrollController.hasClients) return true;
    final position = _messageScrollController.position;
    return position.maxScrollExtent - position.pixels < 80;
  }

  void _scrollMessagesToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_messageScrollController.hasClients) return;
      final target = _messageScrollController.position.maxScrollExtent;
      if (animate) {
        _messageScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _messageScrollController.jumpTo(target);
      }
    });
  }
}

class _Header extends ConsumerWidget {
  final LiveChatState state;
  final VoidCallback onRefresh;
  final ValueChanged<LiveChatAccount?> onAccountChanged;

  const _Header({
    required this.state,
    required this.onRefresh,
    required this.onAccountChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zaloState = ref.watch(zaloIntegrationProvider);

    return Row(
      children: [
        Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Chat CRM Inbox', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tin nhắn Zalo realtime, ghi chú hội thoại và handoff chatbot.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 240,
          child: AppSelectField<String>(
            value:
                zaloState.accounts.any(
                  (acc) => acc.id == state.selectedAccount?.id,
                )
                ? state.selectedAccount?.id
                : '',
            hintText: 'Chọn tài khoản...',
            items: [
              DropdownMenuItem(
                value: '',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.group_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        'Tất cả tài khoản',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ...zaloState.accounts.map((account) {
                final cleanLabel = account.label.replaceAll(
                  RegExp(r'\s*\([^)]*\)$'),
                  '',
                );
                final avatarUrl = account.avatarUrl;

                return DropdownMenuItem(
                  value: account.id,
                  child: Row(
                    children: [
                      _buildAvatar(
                        url: avatarUrl,
                        fallbackText: cleanLabel.isNotEmpty ? cleanLabel : 'A',
                        radius: 12,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          cleanLabel,
                          style: AppTextStyles.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (val) {
              if (val != null) {
                final label = val.isEmpty
                    ? 'Tất cả tài khoản'
                    : (zaloState.accounts.firstWhere((a) => a.id == val).label);
                onAccountChanged(LiveChatAccount(id: val, label: label));
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        IconButton(
          tooltip: 'Tải lại',
          onPressed: state.isLoading ? null : onRefresh,
          icon: state.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Cài đặt Live Chat',
          onPressed: () => showLiveChatSettingsDialog(context, ref),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _MobileInbox extends StatelessWidget {
  final LiveChatState state;
  final LiveChatNotifier notifier;
  final TextEditingController messageController;
  final TextEditingController searchController;
  final TextEditingController tagController;
  final TextEditingController notesController;
  final ScrollController messageScrollController;
  final bool showContactPanel;
  final VoidCallback onToggleContactPanel;

  const _MobileInbox({
    required this.state,
    required this.notifier,
    required this.messageController,
    required this.searchController,
    required this.tagController,
    required this.notesController,
    required this.messageScrollController,
    required this.showContactPanel,
    required this.onToggleContactPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: _ConversationList(
            state: state,
            notifier: notifier,
            searchController: searchController,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Expanded(
          child: _ConversationPanel(
            state: state,
            notifier: notifier,
            messageController: messageController,
            tagController: tagController,
            notesController: notesController,
            messageScrollController: messageScrollController,
            showContactPanel: showContactPanel,
            onToggleContactPanel: onToggleContactPanel,
          ),
        ),
      ],
    );
  }
}

class _ConversationList extends ConsumerWidget {
  final LiveChatState state;
  final LiveChatNotifier notifier;
  final TextEditingController searchController;

  const _ConversationList({
    required this.state,
    required this.notifier,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zaloState = ref.watch(zaloIntegrationProvider);
    final conversations = state.filteredConversations;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Column(
        children: [
          AppSearchField(
            controller: searchController,
            hintText: 'Tìm hội thoại...',
            onChanged: notifier.setSearchQuery,
          ),
          const SizedBox(height: AppSpacing.s),
          _buildFilterBar(context),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: conversations.isEmpty
                ? AppEmptyState(
                    icon: Icons.forum_outlined,
                    title: state.hasActiveConversationFilters
                        ? 'Không có hội thoại phù hợp'
                        : 'Chưa có hội thoại',
                    description: state.hasActiveConversationFilters
                        ? 'Thử bỏ lọc hoặc chọn một nhãn khác.'
                        : state.errorMessage ??
                              'Tin nhắn mới sẽ hiển thị tại đây.',
                    height: 220,
                  )
                : ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final selected =
                          conversation.id == state.selectedConversation?.id;

                      final matchingAccount = zaloState.accounts.firstWhere(
                        (a) => a.id == conversation.accountId,
                        orElse: () => ZaloConnectedAccount(
                          id: conversation.accountId,
                          label: conversation.accountId,
                          connected: false,
                          listenerRunning: false,
                        ),
                      );
                      final accountLabel = matchingAccount.label.replaceAll(
                        RegExp(r'\s*\([^)]*\)$'),
                        '',
                      );
                      final accountAvatar = matchingAccount.avatarUrl;

                      return ListTile(
                        selected: selected,
                        selectedTileColor: AppColors.primarySoft,
                        isThreeLine: true,
                        leading: _buildAvatar(
                          url: conversation.customerAvatar,
                          fallbackText: conversation.customerName,
                          radius: 20,
                        ),
                        title: Row(
                          children: [
                            if (conversation.threadType == 'group') ...[
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  'Nhóm',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                conversation.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: selected
                                      ? (AppColors.isDarkMode
                                            ? Colors.white
                                            : AppColors.primary)
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            ...conversation.displayLabels
                                .take(2)
                                .map(
                                  (label) => Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: _ConversationLabelChip(label: label),
                                  ),
                                ),
                            if (conversation.displayLabels.length > 2)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  '+${conversation.displayLabels.length - 2}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatLastMessage(conversation.lastMessage),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: selected
                                    ? (AppColors.isDarkMode
                                          ? const Color(0xFF93C5FD)
                                          : AppColors.primary)
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildAvatar(
                                  url: accountAvatar,
                                  fallbackText: accountLabel.isNotEmpty
                                      ? accountLabel
                                      : 'A',
                                  radius: 7,
                                  textStyle: TextStyle(
                                    fontSize: 5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Chat qua: $accountLabel',
                                    style: AppTextStyles.caption.copyWith(
                                      color: selected
                                          ? (AppColors.isDarkMode
                                                ? const Color(0xFF93C5FD)
                                                : AppColors.primary)
                                          : AppColors.textSecondary,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 88,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatRelativeTime(
                                        conversation.lastMessageTime,
                                      ),
                                      style: AppTextStyles.caption,
                                    ),
                                    if (conversation.followUpAt != null)
                                      Icon(
                                        Icons.schedule,
                                        size: 14,
                                        color: AppColors.warningText,
                                      ),
                                    if (conversation.assignedTo.isNotEmpty)
                                      Icon(
                                        Icons.person_pin_circle_outlined,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                    if (conversation.unreadCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          conversation.unreadCount.toString(),
                                          style: AppTextStyles.caption.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _ConversationActionMenu(
                                conversation: conversation,
                                notifier: notifier,
                              ),
                            ],
                          ),
                        ),
                        onTap: () => notifier.selectConversation(conversation),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final labels = state.availableLabels;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ConversationFilterChip(
            label: 'Tất cả',
            selected: !state.hasActiveConversationFilters,
            onSelected: (_) => notifier.clearConversationFilters(),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ConversationFilterChip(
            label: 'Chưa đọc',
            selected: state.inboxStatusFilter == InboxStatusFilter.unread,
            onSelected: (selected) => notifier.setInboxStatusFilter(
              selected ? InboxStatusFilter.unread : InboxStatusFilter.all,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ConversationFilterChip(
            label: 'Theo dõi sau',
            selected: state.inboxStatusFilter == InboxStatusFilter.followUp,
            onSelected: (selected) => notifier.setInboxStatusFilter(
              selected ? InboxStatusFilter.followUp : InboxStatusFilter.all,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ConversationFilterChip(
            label: 'Đã lưu trữ',
            selected: state.inboxStatusFilter == InboxStatusFilter.archived,
            onSelected: (selected) => notifier.setInboxStatusFilter(
              selected ? InboxStatusFilter.archived : InboxStatusFilter.all,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ConversationFilterChip(
            label: 'Đã gán',
            selected: state.inboxStatusFilter == InboxStatusFilter.assigned,
            onSelected: (selected) => notifier.setInboxStatusFilter(
              selected ? InboxStatusFilter.assigned : InboxStatusFilter.all,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ConversationFilterChip(
            label: 'Có nhãn',
            selected: state.labeledOnlyFilter,
            onSelected: notifier.setLabeledOnlyFilter,
          ),
          for (final label in labels.take(8)) ...[
            const SizedBox(width: AppSpacing.xs),
            _ConversationFilterChip(
              label: label,
              selected: state.selectedLabelFilter == label,
              onSelected: (selected) {
                notifier.setLabelFilter(selected ? label : '');
              },
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
          PopupMenuButton<String>(
            tooltip: 'Bộ lọc đã lưu',
            onSelected: (value) {
              if (value == '__save__') {
                _showSaveFilterDialog(context);
                return;
              }
              final matches = state.savedFilters.where(
                (filter) => filter.id == value,
              );
              if (matches.isNotEmpty) {
                notifier.applySavedFilter(matches.first);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '__save__',
                enabled: state.hasActiveConversationFilters,
                child: const Text('Lưu bộ lọc hiện tại'),
              ),
              if (state.savedFilters.isNotEmpty) const PopupMenuDivider(),
              ...state.savedFilters.map(
                (filter) => PopupMenuItem(
                  value: filter.id,
                  child: Row(
                    children: [
                      Expanded(child: Text(filter.name)),
                      if (state.selectedSavedFilterId == filter.id)
                        Icon(Icons.check, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
            child: Chip(
              avatar: Icon(
                Icons.bookmark_border,
                size: 16,
                color: AppColors.textSecondary,
              ),
              label: Text(
                state.savedFilters.isEmpty
                    ? 'Lưu lọc'
                    : 'Đã lưu (${state.savedFilters.length})',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }

  void _showSaveFilterDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Lưu bộ lọc',
        icon: Icons.bookmark_add_outlined,
        width: 420,
        actions: [
          AppDialogAction(
            text: 'Hủy',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppDialogAction(
            text: 'Lưu',
            icon: Icons.save_outlined,
            onPressed: () {
              notifier.saveCurrentFilter(nameController.text);
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
        child: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên bộ lọc',
            hintText: 'Ví dụ: Khách nóng chưa đọc',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ).whenComplete(nameController.dispose);
  }
}

class _ConversationFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _ConversationFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
      labelStyle: AppTextStyles.caption.copyWith(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.primaryBorder : AppColors.border,
      ),
    );
  }
}

class _ConversationLabelChip extends StatelessWidget {
  final String label;

  const _ConversationLabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ConversationActionMenu extends StatelessWidget {
  final Conversation conversation;
  final LiveChatNotifier notifier;

  const _ConversationActionMenu({
    required this.conversation,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Thao tác hội thoại',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) async {
        switch (value) {
          case 'pause_bot':
            await notifier.setChatbotForConversation(conversation, false);
            break;
          case 'resume_bot':
            await notifier.setChatbotForConversation(conversation, true);
            break;
          case 'follow_1h':
            notifier.setFollowUp(
              conversation,
              DateTime.now().add(const Duration(hours: 1)),
            );
            break;
          case 'follow_tomorrow':
            final now = DateTime.now();
            notifier.setFollowUp(
              conversation,
              DateTime(now.year, now.month, now.day + 1, 9),
            );
            break;
          case 'clear_follow':
            notifier.setFollowUp(conversation, null);
            break;
          case 'archive':
            notifier.toggleArchived(conversation);
            break;
          case 'assign':
            notifier.toggleAssignedToMe(conversation);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: conversation.chatbotEnabled ? 'pause_bot' : 'resume_bot',
          child: Row(
            children: [
              Icon(
                conversation.chatbotEnabled
                    ? Icons.smart_toy_outlined
                    : Icons.play_circle_outline,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                conversation.chatbotEnabled ? 'Tạm dừng bot' : 'Bật lại bot',
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'follow_1h',
          child: Row(
            children: [
              Icon(Icons.schedule, size: 18),
              SizedBox(width: AppSpacing.s),
              Text('Theo dõi sau 1 giờ'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'follow_tomorrow',
          child: Row(
            children: [
              Icon(Icons.today_outlined, size: 18),
              SizedBox(width: AppSpacing.s),
              Text('Theo dõi sáng mai'),
            ],
          ),
        ),
        if (conversation.followUpAt != null)
          const PopupMenuItem(
            value: 'clear_follow',
            child: Row(
              children: [
                Icon(Icons.event_busy_outlined, size: 18),
                SizedBox(width: AppSpacing.s),
                Text('Bỏ theo dõi sau'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'assign',
          child: Row(
            children: [
              Icon(
                conversation.assignedTo.isEmpty
                    ? Icons.person_add_alt_1_outlined
                    : Icons.person_remove_outlined,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(conversation.assignedTo.isEmpty ? 'Gán cho tôi' : 'Bỏ gán'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(
                conversation.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(conversation.archived ? 'Bỏ lưu trữ' : 'Lưu trữ'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationNoticeBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  const _ConversationNoticeBanner({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      color: color,
      width: double.infinity,
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationPanel extends ConsumerWidget {
  final LiveChatState state;
  final LiveChatNotifier notifier;
  final TextEditingController messageController;
  final TextEditingController tagController;
  final TextEditingController notesController;
  final ScrollController messageScrollController;
  final bool showContactPanel;
  final VoidCallback onToggleContactPanel;

  const _ConversationPanel({
    required this.state,
    required this.notifier,
    required this.messageController,
    required this.tagController,
    required this.notesController,
    required this.messageScrollController,
    required this.showContactPanel,
    required this.onToggleContactPanel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = state.selectedConversation;
    final templates = ref.watch(templatesProvider).templates;
    final quickTemplates = templates
        .where((template) => template.isQuick)
        .toList();
    if (conversation == null) {
      return const AppCard(
        child: AppEmptyState(
          icon: Icons.mark_chat_unread_outlined,
          title: 'Chọn một hội thoại',
          description: 'Nội dung tin nhắn và ghi chú sẽ hiển thị tại đây.',
          height: 420,
        ),
      );
    }

    final zaloState = ref.watch(zaloIntegrationProvider);
    final matchingAccount = zaloState.accounts.firstWhere(
      (a) => a.id == conversation.accountId,
      // Fail-safe: if the conversation's account is no longer in the connected
      // list (logged out / session expired / removed), treat it as disconnected
      // so the composer is blocked instead of silently failing on send.
      orElse: () => ZaloConnectedAccount(
        id: conversation.accountId,
        label: conversation.accountId,
        connected: false,
        listenerRunning: false,
        status: 'disconnected_expired',
      ),
    );
    final accountLabel = matchingAccount.label.replaceAll(
      RegExp(r'\s*\([^)]*\)$'),
      '',
    );
    final responseVariables = _cannedResponseVariables(
      conversation,
      accountLabel,
    );
    final transportMode = ref.watch(liveChatTransportModeProvider);
    // On web/mobile there is no local bridge, so `zaloIntegrationProvider`
    // (which queries the local bridge process) never has real account state —
    // the composer would be permanently disabled for the wrong reason. Gate
    // on the Desktop Agent's reported health instead (FE-4).
    final bool isAccountConnected;
    String? remoteBlockedReason;
    if (transportMode == LiveChatTransportMode.cloudRemote) {
      final agentStatus = ref.watch(agentStatusProvider);
      final agentOffline = agentStatus.hasSnapshot && !agentStatus.anyDeviceOnline;
      final zaloIssue = agentStatus.anyOnlineDeviceHasZaloIssue;
      isAccountConnected = !agentOffline && !zaloIssue;
      if (zaloIssue) {
        remoteBlockedReason =
            'Phiên đăng nhập Zalo trên máy tính chủ đã hết hạn. Vui lòng quét lại QR trên Desktop.';
      } else if (agentOffline) {
        remoteBlockedReason =
            'Không kết nối được với máy tính chủ (Desktop Agent). Tin nhắn có thể bị trễ.';
      } else if (!agentStatus.sseConnected) {
        remoteBlockedReason = 'Đang kết nối lại...';
      }
    } else {
      isAccountConnected =
          matchingAccount.connected &&
          matchingAccount.status != 'disconnected_expired';
    }
    // When the account's AI auto-reply is turned off in the settings dialog, the
    // per-conversation Bot toggle is forced off and cannot be enabled.
    final bool accountAiOn = state.isAccountAiAutoReplyEnabled(
      conversation.accountId,
    );
    final bool botToggleOn = conversation.chatbotEnabled && accountAiOn;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                _buildAvatar(
                  url: conversation.customerAvatar,
                  fallbackText: conversation.customerName,
                  radius: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.customerName,
                        style: AppTextStyles.sectionTitle,
                      ),
                      Text(
                        '${conversation.threadType == 'group' ? 'Nhóm Zalo' : 'Trực tuyến'} • Chat qua: $accountLabel',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (botToggleOn) ...[
                      _AiStatusIcon(
                        paused: conversation.chatbotPaused,
                        pausedUntil: conversation.chatbotPausedUntil,
                        onResumeNow: () => notifier.resumeChatbotNow(),
                      ),
                      const SizedBox(width: AppSpacing.m),
                    ],
                    Switch(
                      value: botToggleOn,
                      onChanged: accountAiOn ? notifier.toggleChatbot : null,
                    ),
                    Text('Bot', style: AppTextStyles.caption),
                    const SizedBox(width: AppSpacing.s),
                    IconButton(
                      tooltip: 'Tìm trong tin nhắn',
                      icon: const Icon(Icons.search),
                      onPressed: () => _showMessageSearch(context, ref),
                    ),
                    IconButton(
                      tooltip: 'Thông tin khách hàng',
                      icon: Icon(
                        showContactPanel
                            ? Icons.account_box
                            : Icons.account_box_outlined,
                        color: showContactPanel ? AppColors.primary : null,
                      ),
                      onPressed: onToggleContactPanel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!botToggleOn || conversation.chatbotPaused)
            _ConversationNoticeBanner(
              icon: Icons.smart_toy_outlined,
              text: !botToggleOn
                  ? 'Bot đang tạm dừng cho hội thoại này.'
                  : 'Bot tạm dừng đến ${DateFormat('HH:mm dd/MM').format(conversation.chatbotPausedUntil!)}.',
              color: AppColors.warningSoft,
              textColor: AppColors.warningText,
            ),
          if (conversation.followUpAt != null)
            _ConversationNoticeBanner(
              icon: Icons.schedule,
              text:
                  'Theo dõi sau: ${DateFormat('HH:mm dd/MM/yyyy').format(conversation.followUpAt!)}',
              color: AppColors.primarySoft,
              textColor: AppColors.primary,
            ),
          if (conversation.notes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              color: AppColors.warningSoft,
              width: double.infinity,
              child: Row(
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    color: AppColors.warningText,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ghi chú: ${conversation.notes}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warningText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              color: AppColors.isDarkMode
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFF3F4F6),
              child: ListView.builder(
                controller: messageScrollController,
                padding: const EdgeInsets.all(AppSpacing.m),
                itemCount:
                    conversation.messages.length +
                    (state.hasMoreMessages && conversation.messages.isNotEmpty
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  final showLoadOlder =
                      state.hasMoreMessages && conversation.messages.isNotEmpty;
                  if (showLoadOlder && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: state.isLoadingOlderMessages
                              ? null
                              : notifier.loadOlderMessages,
                          icon: state.isLoadingOlderMessages
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.keyboard_arrow_up),
                          label: const Text('Tải tin cũ hơn'),
                        ),
                      ),
                    );
                  }
                  final messageIndex = showLoadOlder ? index - 1 : index;
                  final message = conversation.messages[messageIndex];
                  return _MessageBubble(
                    message: message,
                    conversation: conversation,
                    highlighted: state.highlightedMessageId == message.id,
                  );
                },
              ),
            ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text(
                state.errorMessage!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.errorText,
                ),
              ),
            ),
          if (state.isBridgeOffline && !state.isUsingCachedMessages)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s),
              color: AppColors.errorSoft,
              width: double.infinity,
              child: Text(
                'Local Bridge đang offline. Chỉ xem được tóm tắt và dữ liệu từ bộ nhớ đệm.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.errorText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (state.typingUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.s,
                AppSpacing.m,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Khách hàng đang nhập...',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          if (state.replyingTo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.s,
                AppSpacing.m,
                0,
              ),
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 18),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      state.replyingTo!.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hủy trả lời',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => notifier.replyTo(null),
                  ),
                ],
              ),
            ),
          if (!isAccountConnected)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warningText,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      remoteBlockedReason ??
                          'Tài khoản Zalo đã mất kết nối. Không thể nhắn tin hay gửi file.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warningText,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (transportMode == LiveChatTransportMode.cloudRemote &&
              remoteBlockedReason != null)
            // Soft state: SSE reconnecting but the agent may still be
            // online — composer stays open, this is informational only.
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      remoteBlockedReason,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: AppColors.textSecondary),
                  tooltip: 'Đính kèm file/ảnh/video',
                  onPressed:
                      state.isSending ||
                          state.isBridgeOffline ||
                          !isAccountConnected
                      ? null
                      : () => _pickAndSendFile(notifier),
                ),
                IconButton(
                  icon: Icon(
                    Icons.quickreply_outlined,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Mẫu trả lời',
                  onPressed: state.isBridgeOffline || !isAccountConnected
                      ? null
                      : () => _showCannedResponsePicker(
                          context,
                          ref,
                          templates,
                          conversation,
                          accountLabel,
                        ),
                ),
                Expanded(
                  child: CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.enter): () {
                        if (isAccountConnected && !state.isBridgeOffline) {
                          _send(quickTemplates, responseVariables);
                        }
                      },
                    },
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !state.isBridgeOffline && isAccountConnected,
                      decoration: InputDecoration(
                        hintText: !isAccountConnected
                            ? (remoteBlockedReason ??
                                  'Không thể gửi tin do mất kết nối')
                            : state.isBridgeOffline
                            ? 'Không thể gửi tin khi Bridge offline'
                            : 'Nhập tin nhắn hoặc /1, /hello...',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        notifier.updateDraft(value);
                        notifier.notifyTyping();
                      },
                      onSubmitted: (_) {
                        if (isAccountConnected && !state.isBridgeOffline) {
                          _send(quickTemplates, responseVariables);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Gửi',
                  icon: Icons.send_rounded,
                  onPressed:
                      state.isSending ||
                          state.isBridgeOffline ||
                          !isAccountConnected
                      ? null
                      : () => _send(quickTemplates, responseVariables),
                ),
              ],
            ),
          ),
          if (quickTemplates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                0,
                AppSpacing.m,
                AppSpacing.m,
              ),
              child: _QuickReplyStrip(
                templates: quickTemplates,
                onPick: (template) {
                  final content = renderCannedResponse(
                    template.content,
                    responseVariables,
                  );
                  messageController.text = content;
                  messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: content.length),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showCannedResponsePicker(
    BuildContext context,
    WidgetRef ref,
    List<MessageTemplate> templates,
    Conversation conversation,
    String accountLabel,
  ) {
    final searchController = TextEditingController();
    var query = '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = templates.where((template) {
              final haystack =
                  '${template.title} ${template.content} ${template.shortcut}'
                      .toLowerCase();
              return haystack.contains(query.toLowerCase());
            }).toList();
            return AppDialog(
              title: 'Mẫu trả lời',
              subtitle:
                  'Tìm mẫu, chèn biến theo khách hiện tại hoặc lưu draft.',
              icon: Icons.quickreply_outlined,
              width: 640,
              actions: [
                AppDialogAction(
                  text: 'Lưu draft',
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: messageController.text.trim().isEmpty
                      ? null
                      : () {
                          final draft = messageController.text.trim();
                          Navigator.of(dialogContext).pop();
                          _showSaveCannedResponseDialog(context, ref, draft);
                        },
                ),
                AppDialogAction(
                  text: 'Đóng',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm theo tiêu đề, nội dung hoặc shortcode',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() => query = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SizedBox(
                    height: 360,
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Không tìm thấy mẫu phù hợp'),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final template = filtered[index];
                              final content = renderCannedResponse(
                                template.content,
                                _cannedResponseVariables(
                                  conversation,
                                  accountLabel,
                                ),
                              );
                              final shortcut = template.shortcut.isEmpty
                                  ? 'Không có shortcode'
                                  : template.shortcut;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        template.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (template.isQuick)
                                      _ConversationLabelChip(label: shortcut),
                                  ],
                                ),
                                subtitle: Text(
                                  content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: SizedBox(
                                  width: 88,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Sửa mẫu',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _showEditCannedResponseDialog(
                                            context,
                                            ref,
                                            template,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Xóa mẫu',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        onPressed: template.id.isEmpty
                                            ? null
                                            : () {
                                                ref
                                                    .read(
                                                      templatesProvider
                                                          .notifier,
                                                    )
                                                    .deleteTemplate(
                                                      template.id,
                                                    );
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () {
                                  messageController.text = content;
                                  messageController.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(offset: content.length),
                                      );
                                  notifier.updateDraft(content);
                                  Navigator.of(dialogContext).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(searchController.dispose);
  }

  void _showSaveCannedResponseDialog(
    BuildContext context,
    WidgetRef ref,
    String draft,
  ) {
    final titleController = TextEditingController();
    final shortcutController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Lưu mẫu trả lời',
        subtitle:
            'Mẫu mới sẽ xuất hiện trong thư viện và dùng được bằng shortcode.',
        icon: Icons.save_outlined,
        width: 460,
        actions: [
          AppDialogAction(
            text: 'Hủy',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppDialogAction(
            text: 'Lưu',
            icon: Icons.save_outlined,
            onPressed: () async {
              final title = titleController.text.trim();
              final rawShortcut = shortcutController.text.trim();
              final shortcut = rawShortcut.isEmpty
                  ? ''
                  : (rawShortcut.startsWith('/')
                        ? rawShortcut
                        : '/$rawShortcut');
              if (title.isEmpty) return;
              await ref
                  .read(templatesProvider.notifier)
                  .addTemplate(
                    MessageTemplate(
                      id: '',
                      title: title,
                      content: draft,
                      variables: _extractCannedVariables(draft),
                      createdAt: DateTime.now(),
                      shortcut: shortcut,
                      isQuick: true,
                    ),
                  );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên mẫu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: shortcutController,
              decoration: const InputDecoration(
                labelText: 'Shortcode',
                hintText: '/gia hoặc /hello',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              draft,
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      titleController.dispose();
      shortcutController.dispose();
    });
  }

  void _showEditCannedResponseDialog(
    BuildContext context,
    WidgetRef ref,
    MessageTemplate template,
  ) {
    final titleController = TextEditingController(text: template.title);
    final shortcutController = TextEditingController(text: template.shortcut);
    final contentController = TextEditingController(text: template.content);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Sửa mẫu trả lời',
        subtitle: 'Cập nhật nội dung và shortcode dùng trong Live Chat.',
        icon: Icons.edit_outlined,
        width: 520,
        actions: [
          AppDialogAction(
            text: 'Hủy',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppDialogAction(
            text: 'Lưu',
            icon: Icons.save_outlined,
            onPressed: template.id.isEmpty
                ? null
                : () async {
                    final title = titleController.text.trim();
                    final content = contentController.text.trim();
                    final rawShortcut = shortcutController.text.trim();
                    final shortcut = rawShortcut.isEmpty
                        ? ''
                        : (rawShortcut.startsWith('/')
                              ? rawShortcut
                              : '/$rawShortcut');
                    if (title.isEmpty || content.isEmpty) return;
                    await ref
                        .read(templatesProvider.notifier)
                        .updateTemplate(
                          template.copyWith(
                            title: title,
                            content: content,
                            variables: _extractCannedVariables(content),
                            shortcut: shortcut,
                            isQuick: true,
                          ),
                        );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên mẫu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: shortcutController,
              decoration: const InputDecoration(
                labelText: 'Shortcode',
                hintText: '/gia hoặc /hello',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: contentController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      titleController.dispose();
      shortcutController.dispose();
      contentController.dispose();
    });
  }

  void _send(
    List<MessageTemplate> quickTemplates,
    Map<String, String> responseVariables,
  ) {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    final resolved = resolveQuickReplyShortcut(
      text,
      quickTemplates,
      variables: responseVariables,
    );
    messageController.clear();
    notifier.updateDraft('');
    notifier.sendMessage(resolved ?? text);
  }

  Future<void> _pickAndSendFile(LiveChatNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final paths = result.files
        .map((file) => file.path)
        .whereType<String>()
        .toList();
    if (paths.isEmpty) return;

    final extensions = result.files
        .map((file) => file.extension?.toLowerCase() ?? '')
        .toList();
    String messageType = 'file';
    if (extensions.every(
      (ext) => ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext),
    )) {
      messageType = 'image';
    } else if (extensions.length == 1 &&
        ['mp4', 'mov', 'avi', 'webm'].contains(extensions.single)) {
      messageType = 'video';
    } else if (extensions.length == 1 &&
        ['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(extensions.single)) {
      messageType = 'voice';
    }

    await notifier.sendAttachment(
      paths,
      content: messageController.text.trim(),
      messageType: messageType,
    );
    messageController.clear();
    notifier.updateDraft('');
  }

  void _showMessageSearch(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final results = ref.watch(
            liveChatProvider.select((value) => value.messageSearchResults),
          );
          return AppDialog(
            title: 'Tìm trong tin nhắn',
            icon: Icons.manage_search,
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Nhập nội dung cần tìm',
                  ),
                  onChanged: ref.read(liveChatProvider.notifier).searchMessages,
                ),
                const SizedBox(height: AppSpacing.s),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${results.length} kết quả',
                    style: AppTextStyles.caption,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                SizedBox(
                  height: 280,
                  child: results.isEmpty
                      ? const Center(
                          child: Text('Không tìm thấy tin nhắn phù hợp'),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final message = results[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                message.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${message.senderName} • ${DateFormat('dd/MM/yyyy HH:mm').format(message.timestamp)}',
                              ),
                              onTap: () async {
                                await ref
                                    .read(liveChatProvider.notifier)
                                    .openSearchResult(message);
                                final current = ref.read(liveChatProvider);
                                final selected = current.selectedConversation;
                                final index = selected?.messages.indexWhere(
                                  (item) => item.id == message.id,
                                );
                                if (index != null &&
                                    index >= 0 &&
                                    messageScrollController.hasClients) {
                                  final max = messageScrollController
                                      .position
                                      .maxScrollExtent;
                                  final count = selected!.messages.length;
                                  await messageScrollController.animateTo(
                                    count <= 1 ? 0 : max * index / (count - 1),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Map<String, String> _cannedResponseVariables(
  Conversation conversation,
  String accountLabel,
) {
  final now = DateTime.now();
  final customer = conversation.crmCustomer;
  final name = customer?.name.trim().isNotEmpty == true
      ? customer!.name.trim()
      : conversation.customerName;
  return {
    'contact.name': name,
    'conversation.name': conversation.customerName,
    'account.label': accountLabel,
    'date.today': DateFormat('dd/MM/yyyy').format(now),
    'ho_ten': name,
    'ten_khach': name,
    'ngay_hom_nay': DateFormat('dd/MM/yyyy').format(now),
  };
}

List<String> _extractCannedVariables(String content) {
  final variables = <String>{};
  final regex = RegExp(r'\{\{\s*([\w.]+)\s*\}\}|\{([\w_]+)\}');
  for (final match in regex.allMatches(content)) {
    final name = match.group(1) ?? match.group(2);
    if (name != null && name.isNotEmpty) variables.add(name);
  }
  return variables.toList();
}

class _QuickReplyStrip extends StatelessWidget {
  final List<MessageTemplate> templates;
  final ValueChanged<MessageTemplate> onPick;

  const _QuickReplyStrip({required this.templates, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final visible = templates.length > 8
        ? templates.take(8).toList()
        : templates;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.s),
        itemBuilder: (context, index) {
          final template = visible[index];
          final label = template.shortcut.isNotEmpty
              ? template.shortcut
              : '/${index + 1}';
          return OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              minimumSize: const Size(0, 32),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              ),
            ),
            onPressed: () => onPick(template),
            child: Text(
              '$label ${template.title}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final Conversation conversation;
  final bool highlighted;

  const _MessageBubble({
    required this.message,
    required this.conversation,
    this.highlighted = false,
  });

  String? _getImageUrl(ChatMessage msg) {
    if (msg.contentType == 'image' && msg.message.isNotEmpty) {
      if (msg.message.startsWith('http')) return msg.message;
      try {
        final p = jsonDecode(msg.message);
        if (p is Map) {
          return p['href']?.toString() ??
              p['thumb']?.toString() ??
              p['hdUrl']?.toString();
        }
      } catch (_) {}
    }
    if (msg.message.startsWith('{')) {
      try {
        final p = jsonDecode(msg.message);
        if (p is Map) {
          final href = p['href']?.toString() ?? p['thumb']?.toString() ?? '';
          if (href.isNotEmpty) {
            if (RegExp(
              r'\.(jpg|jpeg|png|webp|gif)',
              caseSensitive: false,
            ).hasMatch(href)) {
              return href;
            }
            if (href.contains('zdn.vn') &&
                !(p['params']?.toString().contains('fileExt') ?? false)) {
              return href;
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Map<String, String>? _getFileInfo(ChatMessage msg) {
    if (msg.contentType == 'link') return null;
    if (!msg.message.startsWith('{')) return null;
    try {
      final p = jsonDecode(msg.message);
      if (p is Map) {
        var params = p['params'];
        if (params is String && params.toString().startsWith('{')) {
          params = jsonDecode(params);
        }
        if (params is Map) {
          final isLinkPreview = p['href'] != null && params['fileExt'] == null;
          if (isLinkPreview) return null;

          if (params['fileExt'] != null || params['fType'] == 1) {
            final fileSizeStr = params['fileSize']?.toString() ?? '0';
            final bytes = int.tryParse(fileSizeStr) ?? 0;
            final size = bytes > 1048576
                ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
                : '${(bytes / 1024).round()} KB';
            final name =
                p['title']?.toString() ??
                'file.${params['fileExt'] ?? 'unknown'}';
            final href = p['href']?.toString() ?? '';
            return {'name': name, 'size': size, 'href': href};
          }
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isReminderMessage(ChatMessage msg) {
    if (msg.message.isEmpty) return false;
    try {
      final p = jsonDecode(msg.message);
      return p is Map && p['action'] == 'msginfo.actionlist';
    } catch (_) {
      return false;
    }
  }

  String _getReminderTitle(ChatMessage msg) {
    try {
      final p = jsonDecode(msg.message);
      return p['title']?.toString() ?? '';
    } catch (_) {
      return msg.message;
    }
  }

  String _formatWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ hai';
      case DateTime.tuesday:
        return 'Thứ ba';
      case DateTime.wednesday:
        return 'Thứ tư';
      case DateTime.thursday:
        return 'Thứ năm';
      case DateTime.friday:
        return 'Thứ sáu';
      case DateTime.saturday:
        return 'Thứ bảy';
      case DateTime.sunday:
        return 'Chủ nhật';
      default:
        return '';
    }
  }

  String? _getReminderTime(ChatMessage msg) {
    try {
      final p = jsonDecode(msg.message);
      if (p is Map) {
        var params = p['params'];
        if (params is String && params.toString().startsWith('{')) {
          params = jsonDecode(params);
        }
        if (params is Map) {
          final highlights = params['highLightsV2'];
          if (highlights is List) {
            for (final h in highlights) {
              if (h is Map) {
                final tsStr = h['ts']?.toString() ?? '0';
                final ts = int.tryParse(tsStr) ?? 0;
                if (ts > 1000000000000) {
                  final date = DateTime.fromMillisecondsSinceEpoch(ts);
                  final weekday = _formatWeekday(date.weekday);
                  final dayStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
                  return '$weekday, $dayStr';
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _showImagePreviewDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: (context, url, error) => const Text(
                    'Không thể xem ảnh lớn',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocalImagePreviewDialog(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                child: buildLiveChatLocalImage(
                  path,
                  fit: BoxFit.contain,
                  errorWidget: const Text(
                    'Không thể xem ảnh lớn',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = conversation.messages;
    final messageIndex = messages.indexWhere((m) => m.id == message.id);

    List<LiveChatAttachmentView> groupMedia = [];
    bool isGrouped = false;

    if (messageIndex != -1 && !message.isDeleted) {
      final currentMedia = resolveLiveChatMediaAttachments(message);
      if (currentMedia.isNotEmpty) {
        if (messageIndex > 0) {
          final prevMsg = messages[messageIndex - 1];
          if (!prevMsg.isDeleted &&
              resolveLiveChatMediaAttachments(prevMsg).isNotEmpty &&
              prevMsg.senderId == message.senderId &&
              message.timestamp.difference(prevMsg.timestamp).inSeconds.abs() <=
                  15) {
            isGrouped = true;
          }
        }

        if (!isGrouped) {
          groupMedia.addAll(currentMedia);
          int j = messageIndex + 1;
          while (j < messages.length) {
            final nextMsg = messages[j];
            if (!nextMsg.isDeleted) {
              final nextMedia = resolveLiveChatMediaAttachments(nextMsg);
              if (nextMedia.isNotEmpty &&
                  nextMsg.senderId == message.senderId &&
                  nextMsg.timestamp
                          .difference(messages[j - 1].timestamp)
                          .inSeconds
                          .abs() <=
                      15) {
                groupMedia.addAll(nextMedia);
                j++;
              } else {
                break;
              }
            } else {
              break;
            }
          }
        }
      }
    }

    if (isGrouped) {
      return const SizedBox.shrink();
    }

    final isMine = message.isMine;
    final color = isMine
        ? (AppColors.isDarkMode
              ? const Color(0xFF93C5FD)
              : const Color(0xFFEFF6FF))
        : AppColors.surfaceMuted;
    final textColor = isMine
        ? (AppColors.isDarkMode
              ? const Color(0xFF0F172A)
              : const Color(0xFF1E40AF))
        : AppColors.textPrimary;

    final bool isBot = message.isFromBot;
    final Color badgeBg;
    final Color badgeContentColor;
    if (isBot) {
      badgeBg = const Color(0xFFF3E8FF);
      badgeContentColor = const Color(0xFF7E22CE);
    } else {
      badgeBg = const Color(0xFFCCFBF1);
      badgeContentColor = const Color(0xFF0F766E);
    }

    Widget avatarWidget;
    if (!isMine) {
      final isGroup = conversation.threadType == 'group';
      final avatarUrl =
          isGroup &&
              message.senderAvatarUrl != null &&
              message.senderAvatarUrl!.isNotEmpty
          ? message.senderAvatarUrl!
          : conversation.customerAvatar;
      final fallbackText = isGroup && message.senderName.isNotEmpty
          ? message.senderName
          : conversation.customerName;

      avatarWidget = _buildAvatar(
        url: avatarUrl,
        fallbackText: fallbackText,
        radius: 13,
      );
    } else {
      final zaloState = ref.watch(zaloIntegrationProvider);
      final matching = zaloState.accounts.firstWhere(
        (a) => a.id == conversation.accountId,
        orElse: () => ZaloConnectedAccount(
          id: conversation.accountId,
          label: '',
          connected: false,
          listenerRunning: false,
        ),
      );
      final avatarUrl = matching.avatarUrl;
      final label = matching.label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
      avatarWidget = _buildAvatar(
        url: avatarUrl,
        fallbackText: label.isNotEmpty ? label : 'A',
        radius: 13,
      );
    }

    final bubbleWidget = Padding(
      padding: EdgeInsets.only(
        bottom: message.reactions.isNotEmpty ? AppSpacing.m : AppSpacing.s,
      ),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[avatarWidget, const SizedBox(width: AppSpacing.s)],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (conversation.threadType == 'group' && !isMine) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.senderName.isNotEmpty
                          ? message.senderName
                          : 'Unknown',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                _HoverReactionsStack(
                  message: message,
                  conversation: conversation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                      border: highlighted
                          ? Border.all(color: AppColors.warning, width: 3)
                          : null,
                      boxShadow: highlighted
                          ? [
                              BoxShadow(
                                color: AppColors.warning.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.quote != null) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: AppSpacing.s),
                            padding: const EdgeInsets.all(AppSpacing.s),
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusS,
                              ),
                            ),
                            child: Text(
                              (message.quote!['content'] ??
                                      'Tin nhắn đã trả lời')
                                  .toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                        _buildMessageContent(
                          context,
                          ref,
                          textColor,
                          groupMedia,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isMine) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      message.isFromBot
                                          ? Icons.smart_toy
                                          : Icons.support_agent,
                                      size: 11,
                                      color: badgeContentColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      message.isFromBot ? 'AI' : 'NV',
                                      style: AppTextStyles.caption.copyWith(
                                        color: badgeContentColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              DateFormat(
                                'dd/MM HH:mm',
                              ).format(message.timestamp),
                              style: AppTextStyles.caption.copyWith(
                                color: textColor.withValues(alpha: 0.75),
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.status == 'seen'
                                    ? Icons.done_all
                                    : message.status == 'failed'
                                    ? Icons.error_outline
                                    : message.status == 'sending' ||
                                          message.status == 'queued'
                                    ? Icons.schedule
                                    : Icons.done,
                                size: 14,
                                color: message.status == 'failed'
                                    ? AppColors.errorText
                                    : textColor.withValues(alpha: 0.75),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (message.status == 'failed')
                  TextButton.icon(
                    onPressed: () => ref
                        .read(liveChatProvider.notifier)
                        .retryMessage(message),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(
                      message.errorText.isEmpty
                          ? 'Gửi lại'
                          : 'Gửi lại: ${message.errorText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) ...[const SizedBox(width: AppSpacing.s), avatarWidget],
        ],
      ),
    );

    if (!message.isDeleted) {
      return GestureDetector(
        onSecondaryTapUp: (details) =>
            _showRecallMenu(context, ref, details.globalPosition),
        onLongPress: () => _showRecallMenu(context, ref, null),
        child: bubbleWidget,
      );
    }
    return bubbleWidget;
  }

  void _showRecallMenu(BuildContext context, WidgetRef ref, Offset? position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final pos =
        position ??
        (context.findRenderObject()! as RenderBox).localToGlobal(Offset.zero);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy,
        overlay.size.width - pos.dx,
        0,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Sao chép tin nhắn'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply, size: 18),
              SizedBox(width: 8),
              Text('Trả lời'),
            ],
          ),
        ),

        if (message.isMine && message.status != 'recalled')
          const PopupMenuItem<String>(
            value: 'recall',
            child: Row(
              children: [
                Icon(Icons.undo, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('Thu hồi tin nhắn', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Xóa tin nhắn', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'copy') {
        String copyText = message.message;
        if (message.message.startsWith('{') && message.message.endsWith('}')) {
          try {
            final data = jsonDecode(message.message);
            if (data is Map) {
              copyText =
                  data['title']?.toString() ??
                  data['description']?.toString() ??
                  data['href']?.toString() ??
                  message.message;
            }
          } catch (_) {}
        }
        Clipboard.setData(ClipboardData(text: copyText)).then((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã sao chép tin nhắn vào bộ nhớ tạm.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      } else if (value == 'reply') {
        ref.read(liveChatProvider.notifier).replyTo(message);
      } else if (value == 'heart') {
        ref.read(liveChatProvider.notifier).reactToMessage(message, 'heart');
      } else if (value == 'recall') {
        showDialog<bool>(
          context: context,
          builder: (confirmContext) => AppDialog(
            title: 'Thu hồi tin nhắn',
            icon: Icons.undo,
            subtitle:
                'Bạn có chắc chắn muốn thu hồi tin nhắn này không? Tin nhắn sẽ bị ẩn ở cả hai phía thiết bị.',
            actions: [
              AppDialogAction(
                text: 'Hủy',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.pop(confirmContext, false),
              ),
              AppDialogAction(
                text: 'Thu hồi',
                variant: AppButtonVariant.destructive,
                onPressed: () => Navigator.pop(confirmContext, true),
              ),
            ],
            child: const SizedBox.shrink(),
          ),
        ).then((confirmed) {
          if (confirmed == true) {
            ref
                .read(liveChatProvider.notifier)
                .recallMessage(message.providerActionId)
                .then((success) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Đã thu hồi tin nhắn.'
                              : 'Thu hồi thất bại.',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                });
          }
        });
      } else if (value == 'delete') {
        showDialog<bool>(
          context: context,
          builder: (confirmContext) => AppDialog(
            title: 'Xóa tin nhắn',
            icon: Icons.delete_outline,
            subtitle:
                'Bạn có chắc chắn muốn xóa tin nhắn này không? Hành động này chỉ xóa tin nhắn ở giao diện của bạn.',
            actions: [
              AppDialogAction(
                text: 'Hủy',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.pop(confirmContext, false),
              ),
              AppDialogAction(
                text: 'Xóa',
                variant: AppButtonVariant.destructive,
                onPressed: () => Navigator.pop(confirmContext, true),
              ),
            ],
            child: const SizedBox.shrink(),
          ),
        ).then((confirmed) {
          if (confirmed == true) {
            ref.read(liveChatProvider.notifier).deleteMessage(message.id).then((
              success,
            ) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Đã xóa tin nhắn.' : 'Xóa tin nhắn thất bại.',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            });
          }
        });
      }
    });
  }

  Widget _buildMessageContent(
    BuildContext context,
    WidgetRef ref,
    Color textColor,
    List<LiveChatAttachmentView> groupMedia,
  ) {
    if (message.isDeleted) {
      return Text(
        message.message.isNotEmpty
            ? '${message.message} (đã thu hồi)'
            : '(tin nhắn đã thu hồi)',
        style: AppTextStyles.body.copyWith(
          color: textColor.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
          decoration: TextDecoration.lineThrough,
        ),
      );
    }

    if (groupMedia.isNotEmpty) {
      return _buildImageGrid(context, ref, groupMedia, textColor);
    }

    final attachmentView = resolveLiveChatAttachmentView(message);
    if (attachmentView?.kind == LiveChatAttachmentKind.video) {
      final video = attachmentView!;
      return InkWell(
        onTap: () => _showImageGalleryPreviewDialog(context, ref, [video], 0),
        child: Container(
          width: 260,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            image: video.thumbnailUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(video.thumbnailUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 52),
          ),
        ),
      );
    }
    if (attachmentView?.kind == LiveChatAttachmentKind.image) {
      final image = attachmentView!;
      final useLocal =
          image.hasLocalPath && liveChatLocalFileExists(image.localPath);
      final errorWidget = Container(
        padding: const EdgeInsets.all(AppSpacing.s),
        color: Colors.black12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.grey),
            const SizedBox(width: 8),
            Text('Không thể tải ảnh', style: TextStyle(color: textColor)),
          ],
        ),
      );
      return Stack(
        children: [
          InkWell(
            onTap: useLocal
                ? () => _showLocalImagePreviewDialog(context, image.localPath)
                : image.hasRemoteUrl
                ? () => _showImagePreviewDialog(context, image.url)
                : image.hasLocalPath
                ? () => _showLocalImagePreviewDialog(context, image.localPath)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: useLocal
                  ? buildLiveChatLocalImage(
                      image.localPath,
                      fit: BoxFit.contain,
                      errorWidget: errorWidget,
                    )
                  : image.hasRemoteUrl
                  ? CachedNetworkImage(
                      imageUrl: image.url,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(
                        width: 100,
                        height: 100,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => errorWidget,
                    )
                  : buildLiveChatLocalImage(
                      image.localPath,
                      fit: BoxFit.contain,
                      errorWidget: errorWidget,
                    ),
            ),
          ),
          if (image.hasRemoteUrl)
            Positioned(
              right: 4,
              bottom: 4,
              child: IconButton.filledTonal(
                tooltip: 'Tải ảnh',
                icon: const Icon(Icons.download_outlined, size: 18),
                onPressed: () async {
                  final url = image.url.contains('/local/media/')
                      ? '${image.url}/download'
                      : image.url;
                  try {
                    final path = await const LiveChatDownloadService().download(
                      url: url,
                      fileName: image.displayName,
                      directory: ref
                          .read(settingsProvider)
                          .settings
                          .downloadFolder,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã tải ảnh: $path')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tải ảnh thất bại: $error')),
                      );
                    }
                  }
                },
              ),
            ),
        ],
      );
    }

    final imageUrl = _getImageUrl(message);
    if (imageUrl != null) {
      return InkWell(
        onTap: () => _showImagePreviewDialog(context, imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(
              width: 100,
              height: 100,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Container(
              padding: const EdgeInsets.all(AppSpacing.s),
              color: Colors.black12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Không thể tải ảnh', style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (attachmentView?.kind == LiveChatAttachmentKind.file) {
      final file = attachmentView!;
      return InkWell(
        onTap: () async {
          if (file.hasLocalPath && liveChatLocalFileExists(file.localPath)) {
            OpenFilex.open(file.localPath);
          } else if (file.hasRemoteUrl) {
            try {
              final url = file.url.contains('/local/media/')
                  ? '${file.url}/download'
                  : file.url;
              final path = await const LiveChatDownloadService().download(
                url: url,
                fileName: file.displayName,
                directory: ref.read(settingsProvider).settings.downloadFolder,
              );
              OpenFilex.open(path);
            } catch (_) {}
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: textColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.displayName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (file.sizeLabel.isNotEmpty)
                      Text(
                        file.sizeLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
              if (file.hasLocalPath || file.hasRemoteUrl)
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 20),
                  tooltip: 'Mở thư mục chứa tệp',
                  color: textColor,
                  onPressed: () async {
                    String pathToOpen = file.localPath;
                    if (!file.hasLocalPath && file.hasRemoteUrl) {
                      final url = file.url.contains('/local/media/')
                          ? '${file.url}/download'
                          : file.url;
                      try {
                        pathToOpen = await const LiveChatDownloadService()
                            .download(
                              url: url,
                              fileName: file.displayName,
                              directory: ref
                                  .read(settingsProvider)
                                  .settings
                                  .downloadFolder,
                            );
                      } catch (_) {
                        return;
                      }
                    }
                    if (pathToOpen.isNotEmpty) {
                      try {
                        if (Platform.isWindows) {
                          final winPath = pathToOpen.replaceAll('/', '\\');
                          await Process.run('explorer.exe', [
                            '/select,$winPath',
                          ]);
                        } else {
                          final parentPath = pathToOpen.substring(
                            0,
                            pathToOpen.lastIndexOf(RegExp(r'[/\\]')),
                          );
                          final folderUri = Uri.parse('file:///$parentPath');
                          if (await canLaunchUrl(folderUri)) {
                            await launchUrl(folderUri);
                          }
                        }
                      } catch (_) {}
                    }
                  },
                ),
              if (file.hasRemoteUrl)
                IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  color: textColor,
                  tooltip: 'Tải xuống',
                  onPressed: () async {
                    try {
                      final url = file.url.contains('/local/media/')
                          ? '${file.url}/download'
                          : file.url;
                      final path = await const LiveChatDownloadService()
                          .download(
                            url: url,
                            fileName: file.displayName,
                            directory: ref
                                .read(settingsProvider)
                                .settings
                                .downloadFolder,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã tải tệp: $path')),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tải tệp thất bại: $error')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      );
    }

    final fileInfo = _getFileInfo(message);
    if (fileInfo != null) {
      return InkWell(
        onTap: () async {
          if (fileInfo['href']?.isNotEmpty == true) {
            final url = fileInfo['href']!;
            try {
              final path = await const LiveChatDownloadService().download(
                url: url,
                fileName: fileInfo['name'] ?? 'file',
                directory: ref.read(settingsProvider).settings.downloadFolder,
              );
              OpenFilex.open(path);
            } catch (_) {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: textColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileInfo['name'] ?? '',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      fileInfo['size'] ?? '',
                      style: AppTextStyles.caption.copyWith(
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (fileInfo['href']?.isNotEmpty == true) ...[
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 20),
                  tooltip: 'Mở thư mục chứa tệp',
                  color: textColor,
                  onPressed: () async {
                    try {
                      final path = await const LiveChatDownloadService()
                          .download(
                            url: fileInfo['href']!,
                            fileName: fileInfo['name'] ?? 'file',
                            directory: ref
                                .read(settingsProvider)
                                .settings
                                .downloadFolder,
                          );
                      if (path.isNotEmpty) {
                        if (Platform.isWindows) {
                          final winPath = path.replaceAll('/', '\\');
                          await Process.run('explorer.exe', [
                            '/select,$winPath',
                          ]);
                        } else {
                          final parentPath = path.substring(
                            0,
                            path.lastIndexOf(RegExp(r'[/\\]')),
                          );
                          final folderUri = Uri.parse('file:///$parentPath');
                          if (await canLaunchUrl(folderUri)) {
                            await launchUrl(folderUri);
                          }
                        }
                      }
                    } catch (_) {}
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  color: textColor,
                  tooltip: 'Tải xuống',
                  onPressed: () async {
                    try {
                      final path = await const LiveChatDownloadService()
                          .download(
                            url: fileInfo['href']!,
                            fileName: fileInfo['name'] ?? 'file',
                            directory: ref
                                .read(settingsProvider)
                                .settings
                                .downloadFolder,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã tải tệp: $path')),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tải tệp thất bại: $error')),
                        );
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (message.contentType == 'sticker') {
      return Text(
        '🏷️ Sticker',
        style: AppTextStyles.body.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (message.contentType == 'video') {
      return Text(
        '🎥 Video',
        style: AppTextStyles.body.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (message.contentType == 'voice') {
      return Text(
        '🎤 Tin nhắn thoại',
        style: AppTextStyles.body.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (message.contentType == 'gif') {
      return Text(
        'GIF',
        style: AppTextStyles.body.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (_isReminderMessage(message)) {
      final title = _getReminderTitle(message);
      final time = _getReminderTime(message);
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: Colors.orange, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Nhắc hẹn',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
            if (time != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: textColor.withValues(alpha: 0.6),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: AppTextStyles.caption.copyWith(
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              icon: const Icon(Icons.sync, size: 14),
              label: const Text('Đồng bộ lịch', style: TextStyle(fontSize: 11)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đồng bộ thành công! (Mô phỏng: Lịch hẹn đã được lưu)',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    final trimmed = message.message.trim();
    bool isPollJson = false;
    Map<String, dynamic>? parsedPollData;
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final paramsVal = decoded['params'];
          if (paramsVal != null) {
            Map<String, dynamic>? paramsMap;
            if (paramsVal is Map<String, dynamic>) {
              paramsMap = paramsVal;
            } else if (paramsVal is String &&
                paramsVal.trim().startsWith('{')) {
              final parsedParams = jsonDecode(paramsVal);
              if (parsedParams is Map<String, dynamic>) {
                paramsMap = parsedParams;
              }
            }
            if (paramsMap != null &&
                (paramsMap.containsKey('pollId') ||
                    paramsMap.containsKey('question') ||
                    paramsMap.containsKey('dName'))) {
              isPollJson = true;
              parsedPollData = decoded;
            }
          }
        }
      } catch (_) {}
    }

    if (message.contentType == 'poll' ||
        message.contentType == 'system' ||
        isPollJson) {
      final isPoll = message.contentType == 'poll' || isPollJson;
      String displayMessage = message.message;

      if (isPoll) {
        try {
          final decoded = parsedPollData ?? jsonDecode(message.message);
          if (decoded is Map<String, dynamic>) {
            final paramsVal = decoded['params'];
            Map<String, dynamic>? params;
            if (paramsVal is Map<String, dynamic>) {
              params = paramsVal;
            } else if (paramsVal is String &&
                paramsVal.trim().startsWith('{')) {
              final parsedParams = jsonDecode(paramsVal);
              if (parsedParams is Map<String, dynamic>) {
                params = parsedParams;
              }
            }
            if (params != null) {
              final dName = params['dName']?.toString() ?? '';
              final question = params['question']?.toString() ?? '';
              final msgMap = params['msg'];
              String template = '';
              if (msgMap is Map<String, dynamic>) {
                template = msgMap['vi']?.toString() ?? '';
              }
              if (template.isNotEmpty) {
                displayMessage = template
                    .replaceAll('%1\$s', dName)
                    .replaceAll('%2\$s', question);
              } else if (dName.isNotEmpty || question.isNotEmpty) {
                displayMessage = '$dName: $question';
              }
            }
          }
        } catch (_) {}
      }

      // Strip any HTML tags that might be in the system/poll message
      displayMessage = displayMessage.replaceAll(RegExp(r'<[^>]*>'), '');

      return Container(
        padding: const EdgeInsets.all(AppSpacing.s),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusS),
          border: Border.all(color: textColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPoll ? Icons.poll_outlined : Icons.info_outline,
              color: textColor,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.s),
            Flexible(
              child: Text(
                displayMessage,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      );
    }

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final data = jsonDecode(trimmed);
        if (data is Map<String, dynamic>) {
          final title = data['title']?.toString() ?? '';
          final description = data['description']?.toString() ?? '';
          final href =
              data['href']?.toString() ?? data['url']?.toString() ?? '';
          final thumb =
              data['thumb']?.toString() ?? data['thumbnail']?.toString() ?? '';

          if (title.isNotEmpty || description.isNotEmpty || href.isNotEmpty) {
            return InkWell(
              onTap: href.isNotEmpty
                  ? () async {
                      final uri = Uri.tryParse(href);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  : null,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thumb.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: thumb,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                          errorWidget: (context, error, stackTrace) =>
                              const SizedBox(),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title.isNotEmpty)
                            Text(
                              title,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: AppTextStyles.caption.copyWith(
                                color: textColor.withValues(alpha: 0.8),
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (href.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              href,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      } catch (_) {
        // Fall back to showing raw text
      }
    }

    return SelectableText(
      message.message,
      style: AppTextStyles.body.copyWith(color: textColor),
      contextMenuBuilder: (innerContext, editableTextState) {
        final position = editableTextState.contextMenuAnchors.primaryAnchor;
        Future.microtask(() {
          if (context.mounted) {
            _showRecallMenu(context, ref, position);
          }
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildImageGrid(
    BuildContext context,
    WidgetRef ref,
    List<LiveChatAttachmentView> images,
    Color textColor,
  ) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return _buildSingleImage(context, ref, images[0], textColor);
    }

    final totalCount = images.length;
    final displayCount = totalCount > 6 ? 6 : totalCount;
    final displayImages = images.sublist(0, displayCount);

    final List<Widget> rows = [];
    int startIndex = 0;

    if (displayCount % 2 != 0) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildGridImageItem(
            context,
            ref,
            displayImages[0],
            300,
            180,
            index: 0,
            total: totalCount,
            allImages: images,
          ),
        ),
      );
      startIndex = 1;
    }

    for (int i = startIndex; i < displayCount; i += 2) {
      final hasNext = i + 1 < displayCount;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < displayCount ? 4 : 0),
          child: Row(
            children: [
              Expanded(
                child: _buildGridImageItem(
                  context,
                  ref,
                  displayImages[i],
                  148,
                  148,
                  index: i,
                  total: totalCount,
                  allImages: images,
                ),
              ),
              if (hasNext) ...[
                const SizedBox(width: 4),
                Expanded(
                  child: _buildGridImageItem(
                    context,
                    ref,
                    displayImages[i + 1],
                    148,
                    148,
                    index: i + 1,
                    total: totalCount,
                    allImages: images,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      width: 300,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _buildGridImageItem(
    BuildContext context,
    WidgetRef ref,
    LiveChatAttachmentView image,
    double width,
    double height, {
    required int index,
    required int total,
    required List<LiveChatAttachmentView> allImages,
  }) {
    final useLocal =
        image.hasLocalPath && liveChatLocalFileExists(image.localPath);
    final errorWidget = Container(
      width: width,
      height: height,
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
    );

    final isVideo = image.kind == LiveChatAttachmentKind.video;

    Widget imageWidget = isVideo
        ? Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.black87,
              image: image.thumbnailUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(image.thumbnailUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 36,
              ),
            ),
          )
        : useLocal
        ? SizedBox(
            width: width,
            height: height,
            child: buildLiveChatLocalImage(
              image.localPath,
              fit: BoxFit.cover,
              errorWidget: errorWidget,
            ),
          )
        : image.hasRemoteUrl
        ? CachedNetworkImage(
            imageUrl: image.url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: width,
              height: height,
              color: Colors.black12,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => errorWidget,
          )
        : SizedBox(
            width: width,
            height: height,
            child: buildLiveChatLocalImage(
              image.localPath,
              fit: BoxFit.cover,
              errorWidget: errorWidget,
            ),
          );

    final showOverlay = index == 5 && total > 6;

    return InkWell(
      onTap: () =>
          _showImageGalleryPreviewDialog(context, ref, allImages, index),
      child: Stack(
        children: [
          imageWidget,
          if (showOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+${total - 5}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          if (image.hasRemoteUrl && !showOverlay)
            Positioned(
              right: 2,
              bottom: 2,
              child: SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.download_outlined, size: 14),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final url = image.url.contains('/local/media/')
                        ? '${image.url}/download'
                        : image.url;
                    try {
                      final path = await const LiveChatDownloadService()
                          .download(
                            url: url,
                            fileName: image.displayName,
                            directory: ref
                                .read(settingsProvider)
                                .settings
                                .downloadFolder,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã tải ảnh: $path')),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tải ảnh thất bại: $error')),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleImage(
    BuildContext context,
    WidgetRef ref,
    LiveChatAttachmentView image,
    Color textColor,
  ) {
    if (image.kind == LiveChatAttachmentKind.video) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
        child: Stack(
          children: [
            InkWell(
              onTap: () =>
                  _showImageGalleryPreviewDialog(context, ref, [image], 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 300,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    image: image.thumbnailUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(image.thumbnailUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                ),
              ),
            ),
            if (image.hasRemoteUrl)
              Positioned(
                right: 4,
                bottom: 4,
                child: IconButton.filledTonal(
                  tooltip: 'Tải video',
                  icon: const Icon(Icons.download_outlined, size: 18),
                  onPressed: () async {
                    final url = image.url.contains('/local/media/')
                        ? '${image.url}/download'
                        : image.url;
                    try {
                      final path = await const LiveChatDownloadService()
                          .download(
                            url: url,
                            fileName: image.displayName,
                            directory: ref
                                .read(settingsProvider)
                                .settings
                                .downloadFolder,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã tải video: $path')),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tải video thất bại: $error')),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        ),
      );
    }

    final useLocal =
        image.hasLocalPath && liveChatLocalFileExists(image.localPath);
    final errorWidget = Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      color: Colors.black12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.grey),
          const SizedBox(width: 8),
          Text('Không thể tải ảnh', style: TextStyle(color: textColor)),
        ],
      ),
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
      child: Stack(
        children: [
          InkWell(
            onTap: () =>
                _showImageGalleryPreviewDialog(context, ref, [image], 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: useLocal
                  ? buildLiveChatLocalImage(
                      image.localPath,
                      fit: BoxFit.contain,
                      errorWidget: errorWidget,
                    )
                  : image.hasRemoteUrl
                  ? CachedNetworkImage(
                      imageUrl: image.url,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(
                        width: 100,
                        height: 100,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => errorWidget,
                    )
                  : buildLiveChatLocalImage(
                      image.localPath,
                      fit: BoxFit.contain,
                      errorWidget: errorWidget,
                    ),
            ),
          ),
          if (image.hasRemoteUrl)
            Positioned(
              right: 4,
              bottom: 4,
              child: IconButton.filledTonal(
                tooltip: 'Tải ảnh',
                icon: const Icon(Icons.download_outlined, size: 18),
                onPressed: () async {
                  final url = image.url.contains('/local/media/')
                      ? '${image.url}/download'
                      : image.url;
                  try {
                    final path = await const LiveChatDownloadService().download(
                      url: url,
                      fileName: image.displayName,
                      directory: ref
                          .read(settingsProvider)
                          .settings
                          .downloadFolder,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã tải ảnh: $path')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tải ảnh thất bại: $error')),
                      );
                    }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

String _formatLastMessage(String rawMessage) {
  final trimmed = rawMessage.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      final data = jsonDecode(trimmed);
      if (data is Map<String, dynamic>) {
        final isDeleted = data['isDeleted'] == true;
        if (isDeleted) return '(tin nhắn đã thu hồi)';

        final contentType = data['contentType']?.toString() ?? '';
        final prefix = data['direction'] == 'outbound' ? 'Bạn: ' : '';

        if (contentType == 'image') {
          return '$prefix📷 Hình ảnh';
        } else if (contentType == 'sticker') {
          return '$prefix🏷️ Sticker';
        } else if (contentType == 'video') {
          return '$prefix🎥 Video';
        } else if (contentType == 'voice') {
          return '$prefix🎤 Tin nhắn thoại';
        } else if (contentType == 'gif') {
          return '${prefix}GIF';
        } else if (contentType == 'file') {
          return '$prefix📎 Tệp đính kèm';
        } else if (contentType == 'link') {
          return '$prefix🔗 Liên kết';
        }

        final params = data['params'];
        if (params is Map<String, dynamic> ||
            (params is String && params.toString().startsWith('{'))) {
          final pMap = params is String ? jsonDecode(params) : params;
          if (pMap is Map && (pMap['fileExt'] != null || pMap['fType'] == 1)) {
            return '$prefix📎 Tệp đính kèm';
          }
        }

        final title = data['title']?.toString() ?? '';
        if (title.isNotEmpty) {
          if (title.startsWith('http')) {
            return '$prefix[Liên kết] ${Uri.tryParse(title)?.host ?? title}';
          }
          return '$prefix[Liên kết] $title';
        }

        final href = data['href']?.toString() ?? data['url']?.toString() ?? '';
        if (href.isNotEmpty) {
          return '$prefix[Liên kết] ${Uri.tryParse(href)?.host ?? href}';
        }
      }
    } catch (_) {}
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return '[Liên kết] ${Uri.tryParse(trimmed)?.host ?? trimmed}';
  }

  return rawMessage;
}

String _formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'Vừa xong';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} phút';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} giờ';
  } else if (difference.inDays == 1 ||
      (difference.inDays < 2 && now.day != dateTime.day)) {
    return 'Hôm qua';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} ngày';
  } else {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}

Widget _buildAvatar({
  required String url,
  required String fallbackText,
  required double radius,
  Color? backgroundColor,
  TextStyle? textStyle,
}) {
  final trimmed = url.trim();
  final hasImage =
      (trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
      !trimmed.contains('/default');

  final String fallbackChar = fallbackText.trim().isNotEmpty
      ? fallbackText.trim()[0].toUpperCase()
      : '?';

  final TextStyle defaultTextStyle = TextStyle(
    fontSize: radius * 0.8,
    fontWeight: FontWeight.bold,
    color: AppColors.textSecondary,
  );

  return ClipOval(
    child: Container(
      width: radius * 2,
      height: radius * 2,
      color: backgroundColor ?? AppColors.surfaceMuted,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: trimmed,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorWidget: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    fallbackChar,
                    style: textStyle ?? defaultTextStyle,
                  ),
                );
              },
            )
          : Center(
              child: Text(fallbackChar, style: textStyle ?? defaultTextStyle),
            ),
    ),
  );
}

class _ContactInfoPanel extends ConsumerStatefulWidget {
  final Conversation conversation;
  final LiveChatNotifier notifier;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController sourceController;
  final TextEditingController statusController;
  final TextEditingController tagController;
  final TextEditingController notesController;
  final VoidCallback onClose;

  const _ContactInfoPanel({
    required this.conversation,
    required this.notifier,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.sourceController,
    required this.statusController,
    required this.tagController,
    required this.notesController,
    required this.onClose,
  });

  @override
  ConsumerState<_ContactInfoPanel> createState() => _ContactInfoPanelState();
}

class _ContactInfoPanelState extends ConsumerState<_ContactInfoPanel> {
  bool _isSaving = false;
  late Map<String, String> _customFields;

  @override
  void initState() {
    super.initState();
    _customFields = _initialCustomFields(widget.conversation);
  }

  @override
  void didUpdateWidget(covariant _ContactInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _customFields = _initialCustomFields(widget.conversation);
    }
  }

  Map<String, String> _initialCustomFields(Conversation conversation) {
    final customerFields = conversation.crmCustomer?.customFields ?? const {};
    return Map<String, String>.from(
      customerFields.isNotEmpty
          ? customerFields
          : conversation.customAttributes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomer = widget.conversation.crmCustomer != null;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Icon(Icons.account_box, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Thông tin khách hàng', style: AppTextStyles.sectionTitle),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                if (!hasCustomer)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.m),
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Khách hàng này chưa có trong CRM. Vui lòng cập nhật thông tin và bấm Lưu.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warningText,
                      ),
                    ),
                  ),
                TextField(
                  controller: widget.nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: widget.phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: widget.emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: widget.sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Nguồn',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<String>(
                  initialValue: widget.statusController.text.isEmpty
                      ? 'lead'
                      : widget.statusController.text,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'lead',
                      child: Text('Mới tiếp cận (Lead)'),
                    ),
                    DropdownMenuItem(
                      value: 'contact',
                      child: Text('Đang liên hệ (Contact)'),
                    ),
                    DropdownMenuItem(
                      value: 'customer',
                      child: Text('Khách hàng (Customer)'),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Không tương tác (Inactive)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      widget.statusController.text = val;
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: widget.tagController,
                  decoration: const InputDecoration(
                    labelText: 'Nhãn (phân tách bằng dấu phẩy)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: widget.notesController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.m),
                _CustomFieldsEditor(
                  fields: _customFields,
                  onChanged: (key, value) {
                    setState(() {
                      final trimmed = value.trim();
                      if (trimmed.isEmpty) {
                        _customFields.remove(key);
                      } else {
                        _customFields[key] = trimmed;
                      }
                    });
                  },
                  onAddField: _addCustomField,
                ),
                if (widget.conversation.timeline.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  _buildTimeline(),
                ],
                const SizedBox(height: AppSpacing.l),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(hasCustomer ? 'Lưu thông tin' : 'Thêm vào CRM'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timeline', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.s),
        ...widget.conversation.timeline
            .take(6)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.summary,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatRelativeTime(item.createdAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
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
      ],
    );
  }

  Future<void> _save() async {
    final name = widget.nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập họ tên')));
      return;
    }

    setState(() => _isSaving = true);
    final tagText = widget.tagController.text.trim();
    final tagsList = tagText
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final success = await widget.notifier.saveCrmCustomer(
      name: name,
      phone: widget.phoneController.text.trim(),
      email: widget.emailController.text.trim(),
      source: widget.sourceController.text.trim(),
      status: widget.statusController.text.trim(),
      notes: widget.notesController.text.trim(),
      tags: tagsList,
      customFields: Map<String, String>.from(_customFields),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Lưu thông tin thành công!' : 'Lưu thông tin thất bại.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _addCustomField() {
    const baseKey = 'custom_field';
    var key = baseKey;
    var suffix = 2;
    while (_customFields.containsKey(key)) {
      key = '${baseKey}_$suffix';
      suffix++;
    }
    setState(() => _customFields[key] = '');
  }
}

class _CustomFieldsEditor extends StatelessWidget {
  final Map<String, String> fields;
  final void Function(String key, String value) onChanged;
  final VoidCallback onAddField;

  const _CustomFieldsEditor({
    required this.fields,
    required this.onChanged,
    required this.onAddField,
  });

  @override
  Widget build(BuildContext context) {
    final entries = fields.entries.toList();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Thuộc tính tùy biến',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Thêm trường',
                onPressed: onAddField,
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          if (entries.isEmpty)
            Text(
              'Chưa có thuộc tính riêng cho khách hàng này.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: TextFormField(
                  key: ValueKey('custom-field-${entry.key}'),
                  initialValue: entry.value,
                  decoration: InputDecoration(
                    labelText: _labelForCustomField(entry.key),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => onChanged(entry.key, value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _labelForCustomField(String key) {
  switch (key) {
    case 'budget':
      return 'Ngân sách';
    case 'lifecycle':
      return 'Giai đoạn chăm sóc';
    case 'priority':
      return 'Độ ưu tiên';
    case 'need':
      return 'Nhu cầu';
    default:
      return key
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
  }
}

void _showImageGalleryPreviewDialog(
  BuildContext context,
  WidgetRef ref,
  List<LiveChatAttachmentView> images,
  int initialIndex,
) {
  showDialog(
    context: context,
    builder: (context) {
      return _ImageGalleryDialog(
        images: images,
        initialIndex: initialIndex,
        ref: ref,
      );
    },
  );
}

class _ImageGalleryDialog extends StatefulWidget {
  final List<LiveChatAttachmentView> images;
  final int initialIndex;
  final WidgetRef ref;

  const _ImageGalleryDialog({
    required this.images,
    required this.initialIndex,
    required this.ref,
  });

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gallery view
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final image = widget.images[index];
              if (image.kind == LiveChatAttachmentKind.video) {
                return _GalleryVideoItem(
                  url: image.url,
                  localPath: image.localPath,
                );
              }
              final useLocal =
                  image.hasLocalPath &&
                  liveChatLocalFileExists(image.localPath);

              return GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: InteractiveViewer(
                  child: Center(
                    child: useLocal
                        ? buildLiveChatLocalImage(
                            image.localPath,
                            fit: BoxFit.contain,
                            errorWidget: const Text(
                              'Không thể xem ảnh lớn',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : image.hasRemoteUrl
                        ? CachedNetworkImage(
                            imageUrl: image.url,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (context, url, error) => const Text(
                              'Không thể xem ảnh lớn',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : buildLiveChatLocalImage(
                            image.localPath,
                            fit: BoxFit.contain,
                            errorWidget: const Text(
                              'Không thể xem ảnh lớn',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
          // Top bar details
          Positioned(
            top: 16,
            left: 16,
            child: Text(
              '${_currentIndex + 1} / ${widget.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Download button for current media
                IconButton(
                  icon: const Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 26,
                  ),
                  tooltip:
                      widget.images[_currentIndex].kind ==
                          LiveChatAttachmentKind.video
                      ? 'Tải video hiện tại'
                      : 'Tải ảnh hiện tại',
                  onPressed: () async {
                    final image = widget.images[_currentIndex];
                    final isVideo = image.kind == LiveChatAttachmentKind.video;
                    final mediaTypeLabel = isVideo ? 'video' : 'ảnh';
                    final url = image.url.contains('/local/media/')
                        ? '${image.url}/download'
                        : image.url;
                    if (!image.hasRemoteUrl) return;
                    try {
                      final path = await const LiveChatDownloadService()
                          .download(
                            url: url,
                            fileName: image.displayName,
                            directory: widget.ref
                                .read(settingsProvider)
                                .settings
                                .downloadFolder,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã tải $mediaTypeLabel: $path'),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tải $mediaTypeLabel thất bại: $error',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Navigation indicators
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white60,
                  size: 36,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          if (_currentIndex < widget.images.length - 1)
            Positioned(
              right: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white60,
                  size: 36,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryVideoItem extends StatefulWidget {
  final String url;
  final String localPath;

  const _GalleryVideoItem({required this.url, this.localPath = ''});

  @override
  State<_GalleryVideoItem> createState() => _GalleryVideoItemState();
}

class _GalleryVideoItemState extends State<_GalleryVideoItem> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<String>? _errorSubscription;
  bool _isLoading = true;
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _errorSubscription = _player.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _playbackError = 'Không thể phát video: $error';
        });
      }
    });
    unawaited(_initializePlayer());
  }

  Future<void> _initializePlayer() async {
    try {
      final source = widget.url.isNotEmpty ? widget.url : widget.localPath;
      await _player.open(
        Media(source),
        play: true,
      ); // Auto play in fullscreen preview is great!
    } catch (error) {
      _playbackError = 'Không thể phát video: $error';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    unawaited(_errorSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_playbackError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _playbackError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Video(controller: _controller, controls: AdaptiveVideoControls),
      ),
    );
  }
}

String _formatResumeTime(DateTime time) {
  final local = time.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// AI status indicator in the chat header. Bright = active; dimmed = paused
/// because a human just replied. Double-clicking the dimmed icon resumes the bot
/// immediately without waiting out the cooldown.
class _AiStatusIcon extends StatelessWidget {
  final bool paused;
  final DateTime? pausedUntil;
  final VoidCallback onResumeNow;

  const _AiStatusIcon({
    required this.paused,
    required this.pausedUntil,
    required this.onResumeNow,
  });

  @override
  Widget build(BuildContext context) {
    final accent = paused ? AppColors.textMuted : AppColors.primary;
    final badge = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: paused ? AppColors.surfaceMuted : AppColors.primarySoft,
        border: Border.all(
          color: paused ? AppColors.borderSoft : AppColors.primary,
          width: 1.5,
        ),
      ),
      child: Icon(Icons.smart_toy, size: 16, color: accent),
    );
    if (!paused) {
      return Tooltip(message: 'AI đang hoạt động', child: badge);
    }
    final resume = pausedUntil != null
        ? ' Tự bật lại lúc ${_formatResumeTime(pausedUntil!)}.'
        : '';
    return Tooltip(
      message:
          'AI tạm nghỉ vì bạn vừa trả lời.$resume\n'
          'Nhấp đúp để bật lại ngay.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onDoubleTap: onResumeNow, child: badge),
      ),
    );
  }
}

class GlossyHeart extends StatelessWidget {
  final double size;
  const GlossyHeart({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlossyHeartPainter()),
    );
  }
}

class _GlossyHeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final path = Path();

    // Start at top center cleft
    path.moveTo(width * 0.5, height * 0.25);

    // Left lobe
    path.cubicTo(
      width * 0.15,
      height * 0.02,
      width * -0.08,
      height * 0.38,
      width * 0.15,
      height * 0.68,
    );

    // Left side to bottom point
    path.cubicTo(
      width * 0.25,
      height * 0.78,
      width * 0.4,
      height * 0.88,
      width * 0.5,
      height * 0.98,
    );

    // Right side from bottom point
    path.cubicTo(
      width * 0.6,
      height * 0.88,
      width * 0.75,
      height * 0.78,
      width * 0.85,
      height * 0.68,
    );

    // Right lobe
    path.cubicTo(
      width * 1.08,
      height * 0.38,
      width * 0.85,
      height * 0.02,
      width * 0.5,
      height * 0.25,
    );

    path.close();

    // Premium shiny linear gradient: top-left to bottom-right
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(width * 0.1, height * 0.1),
        Offset(width * 0.9, height * 0.9),
        [
          const Color(0xFFFF5252), // Top-left: bright red/coral
          const Color(0xFFFF1744), // Middle: rich red
          const Color(0xFFC2185B), // Bottom-right: deep crimson/pinkish red
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // 3D glossy highlight on the top left
    final highlightPath = Path();
    highlightPath.moveTo(width * 0.22, height * 0.22);
    highlightPath.cubicTo(
      width * 0.15,
      height * 0.25,
      width * 0.15,
      height * 0.45,
      width * 0.32,
      height * 0.5,
    );
    highlightPath.cubicTo(
      width * 0.28,
      height * 0.42,
      width * 0.25,
      height * 0.30,
      width * 0.22,
      height * 0.22,
    );

    final highlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(width * 0.22, height * 0.22),
        Offset(width * 0.32, height * 0.5),
        [
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.0),
        ],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(highlightPath, highlightPaint);

    // Add a second tiny glossy dot on the top right lobe
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(width * 0.72, height * 0.32),
      width * 0.08,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HoverReactionsStack extends ConsumerStatefulWidget {
  final ChatMessage message;
  final Conversation conversation;
  final Widget child;

  const _HoverReactionsStack({
    required this.message,
    required this.conversation,
    required this.child,
  });

  @override
  ConsumerState<_HoverReactionsStack> createState() =>
      _HoverReactionsStackState();
}

class _HoverReactionsStackState extends ConsumerState<_HoverReactionsStack> {
  bool _isBubbleHovered = false;
  bool _showEmojiBar = false;
  bool _hoveringLikeButton = false;
  bool _hoveringEmojiBar = false;

  void _updateEmojiBarVisibility() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _showEmojiBar = _hoveringLikeButton || _hoveringEmojiBar;
        });
      }
    });
  }

  void _reactAndClose(String type) {
    ref.read(liveChatProvider.notifier).reactToMessage(widget.message, type);
    setState(() {
      _showEmojiBar = false;
      _hoveringEmojiBar = false;
      _hoveringLikeButton = false;
    });
  }

  String _getReactionEmoji(String reaction) {
    switch (reaction.toLowerCase()) {
      case 'heart':
        return '❤️';
      case 'like':
        return '👍';
      case 'haha':
        return '😆';
      case 'wow':
        return '😮';
      case 'sad':
        return '😭';
      case 'angry':
        return '😡';
      default:
        return reaction;
    }
  }

  Widget _buildReactionPill(List<Map<String, dynamic>> reactions) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final hasMyReaction = reactions.any((r) {
      final userId = r['userId']?.toString();
      return r['isMine'] == true ||
          (userId != null && userId == widget.conversation.accountId);
    });

    final uniqueTypes = reactions
        .map((r) => (r['reaction'] ?? '').toString().toLowerCase())
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();

    final displayTypes = uniqueTypes.take(3).toList();

    return InkWell(
      onTap: () {
        if (hasMyReaction) {
          ref
              .read(liveChatProvider.notifier)
              .reactToMessage(widget.message, 'none');
        } else if (uniqueTypes.isNotEmpty) {
          ref
              .read(liveChatProvider.notifier)
              .reactToMessage(widget.message, uniqueTypes.first);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.isDarkMode
                ? const Color(0xFF253247)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...displayTypes.map((type) {
              if (type == 'heart') {
                return const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: GlossyHeart(size: 14),
                );
              }
              final emoji = _getReactionEmoji(type);
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(emoji, style: const TextStyle(fontSize: 12)),
              );
            }),
            Text(
              reactions.length.toString(),
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLikeButton() {
    final bool hasMyLike = widget.message.reactions.any(
      (r) =>
          (r['reaction'] ?? '').toString().toLowerCase() == 'like' &&
          (r['isMine'] == true || r['userId'] == widget.conversation.accountId),
    );

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hoveringLikeButton = true;
          _showEmojiBar = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hoveringLikeButton = false;
        });
        _updateEmojiBarVisibility();
      },
      child: InkWell(
        onTap: () {
          ref
              .read(liveChatProvider.notifier)
              .reactToMessage(widget.message, hasMyLike ? 'none' : 'like');
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.isDarkMode
                  ? const Color(0xFF253247)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            hasMyLike ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
            size: 11,
            color: hasMyLike ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiReactionBar() {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hoveringEmojiBar = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hoveringEmojiBar = false;
        });
        _updateEmojiBarVisibility();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.isDarkMode
                ? const Color(0xFF253247)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmojiHoverItem(
              child: const Text('👍', style: TextStyle(fontSize: 20)),
              onTap: () => _reactAndClose('like'),
            ),
            _EmojiHoverItem(
              child: const GlossyHeart(size: 20),
              onTap: () => _reactAndClose('heart'),
            ),
            _EmojiHoverItem(
              child: const Text('😆', style: TextStyle(fontSize: 20)),
              onTap: () => _reactAndClose('haha'),
            ),
            _EmojiHoverItem(
              child: const Text('😮', style: TextStyle(fontSize: 20)),
              onTap: () => _reactAndClose('wow'),
            ),
            _EmojiHoverItem(
              child: const Text('😭', style: TextStyle(fontSize: 20)),
              onTap: () => _reactAndClose('sad'),
            ),
            _EmojiHoverItem(
              child: const Text('😡', style: TextStyle(fontSize: 20)),
              onTap: () => _reactAndClose('angry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showLikeBtn = _isBubbleHovered || _showEmojiBar;

    return MouseRegion(
      onEnter: (_) => setState(() => _isBubbleHovered = true),
      onExit: (_) => setState(() => _isBubbleHovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (widget.message.reactions.isNotEmpty || showLikeBtn)
            Positioned(
              bottom: -10,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.message.reactions.isNotEmpty)
                    _buildReactionPill(widget.message.reactions),
                  if (showLikeBtn) ...[
                    if (widget.message.reactions.isNotEmpty)
                      const SizedBox(width: 4),
                    _buildQuickLikeButton(),
                  ],
                ],
              ),
            ),
          if (_showEmojiBar)
            Positioned(bottom: 12, right: 0, child: _buildEmojiReactionBar()),
        ],
      ),
    );
  }
}

class _EmojiHoverItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _EmojiHoverItem({required this.child, required this.onTap});

  @override
  State<_EmojiHoverItem> createState() => _EmojiHoverItemState();
}

class _EmojiHoverItemState extends State<_EmojiHoverItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          transform:
              Matrix4.translationValues(
                _isHovered ? -2.0 : 0.0,
                _isHovered ? -4.0 : 0.0,
                0.0,
              ) *
              Matrix4.diagonal3Values(
                _isHovered ? 1.25 : 1.0,
                _isHovered ? 1.25 : 1.0,
                1.0,
              ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: widget.child,
        ),
      ),
    );
  }
}
