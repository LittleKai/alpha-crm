import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../providers/live_chat_provider.dart';

class LiveChatScreen extends ConsumerStatefulWidget {
  const LiveChatScreen({super.key});

  @override
  ConsumerState<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends ConsumerState<LiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _tagController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveChatProvider);
    final notifier = ref.read(liveChatProvider.notifier);
    final selected = state.selectedConversation;

    if (selected != null) {
      if (_tagController.text != selected.tag) {
        _tagController.text = selected.tag;
      }
      if (_notesController.text != selected.notes) {
        _notesController.text = selected.notes;
      }
    }

    final isMobile = ResponsiveBreakpoints.isMobile(context);
    return Scaffold(
      backgroundColor: AppColors.appBackground,
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
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
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
        const Icon(
          Icons.chat_bubble_outline,
          color: AppColors.primary,
          size: 32,
        ),
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
            value: zaloState.accounts.any((acc) => acc.id == state.selectedAccount?.id)
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
                      child: const Icon(
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
                final cleanLabel = account.label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
                final avatarUrl = account.avatarUrl;

                return DropdownMenuItem(
                  value: account.id,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.surfaceMuted,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                cleanLabel.isNotEmpty ? cleanLabel[0].toUpperCase() : 'A',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
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

  const _MobileInbox({
    required this.state,
    required this.notifier,
    required this.messageController,
    required this.searchController,
    required this.tagController,
    required this.notesController,
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

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Tìm hội thoại...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: notifier.setSearchQuery,
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: state.conversations.isEmpty
                ? AppEmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Chưa có hội thoại',
                    description:
                        state.errorMessage ??
                        'Tin nhắn mới sẽ hiển thị tại đây.',
                    height: 220,
                  )
                : ListView.separated(
                    itemCount: state.conversations.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conversation = state.conversations[index];
                      final selected =
                          conversation.id == state.selectedConversation?.id;
                      
                      final matchingAccount = zaloState.accounts.firstWhere(
                        (a) => a.id == conversation.accountId,
                        orElse: () => ZaloConnectedAccount(
                          id: conversation.accountId,
                          label: conversation.accountId,
                          connected: true,
                          listenerRunning: false,
                        ),
                      );
                      final accountLabel = matchingAccount.label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
                      final accountAvatar = matchingAccount.avatarUrl;

                      return ListTile(
                        selected: selected,
                        selectedTileColor: AppColors.primarySoft,
                        isThreeLine: true,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceMuted,
                          backgroundImage: conversation.customerAvatar.isNotEmpty && conversation.customerAvatar.startsWith('http')
                              ? NetworkImage(conversation.customerAvatar)
                              : null,
                          child: conversation.customerAvatar.isEmpty || !conversation.customerAvatar.startsWith('http')
                              ? Text(
                                  conversation.customerName.isNotEmpty ? conversation.customerName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                            if (conversation.tag.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.primaryBorder,
                                  ),
                                ),
                                child: Text(
                                  conversation.tag,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatLastMessage(conversation.lastMessage),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 7,
                                  backgroundColor: AppColors.surfaceMuted,
                                  backgroundImage: accountAvatar.isNotEmpty
                                      ? NetworkImage(accountAvatar)
                                      : null,
                                  child: accountAvatar.isEmpty
                                      ? const Text(
                                          'A',
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textSecondary,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Chat qua: $accountLabel',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
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
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(conversation.lastMessageTime),
                              style: AppTextStyles.caption,
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
                                  borderRadius: BorderRadius.circular(10),
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
                        onTap: () => notifier.selectConversation(conversation),
                      );
                    },
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

  const _ConversationPanel({
    required this.state,
    required this.notifier,
    required this.messageController,
    required this.tagController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = state.selectedConversation;
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
      orElse: () => ZaloConnectedAccount(
        id: conversation.accountId,
        label: conversation.accountId,
        connected: true,
        listenerRunning: false,
      ),
    );
    final accountLabel = matchingAccount.label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '');

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.surfaceMuted,
                  backgroundImage: conversation.customerAvatar.isNotEmpty && conversation.customerAvatar.startsWith('http')
                      ? NetworkImage(conversation.customerAvatar)
                      : null,
                  child: conversation.customerAvatar.isEmpty || !conversation.customerAvatar.startsWith('http')
                      ? Text(
                          conversation.customerName.isNotEmpty ? conversation.customerName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
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
                    Text('Bot', style: AppTextStyles.caption),
                    Switch(
                      value: conversation.chatbotEnabled,
                      onChanged: notifier.toggleChatbot,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
                  const Icon(
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
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.m),
              itemCount: conversation.messages.length,
              itemBuilder: (context, index) {
                final message = conversation.messages[index];
                return _MessageBubble(
                  message: message,
                  conversation: conversation,
                );
              },
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Gửi',
                  icon: Icons.send_rounded,
                  onPressed: state.isSending ? null : _send,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: tagController,
                    decoration: const InputDecoration(
                      labelText: 'Nhãn',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: notifier.updateTag,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: notifier.updateNotes,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    messageController.clear();
    notifier.sendMessage(text);
  }
}

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final Conversation conversation;

  const _MessageBubble({
    required this.message,
    required this.conversation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMine = message.isMine;
    final color = isMine ? AppColors.primary : AppColors.surfaceMuted;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;

    Widget avatarWidget;
    if (!isMine) {
      final hasImg = conversation.customerAvatar.isNotEmpty && conversation.customerAvatar.startsWith('http');
      avatarWidget = CircleAvatar(
        radius: 13,
        backgroundColor: AppColors.surfaceMuted,
        backgroundImage: hasImg ? NetworkImage(conversation.customerAvatar) : null,
        child: !hasImg
            ? Text(
                conversation.customerName.isNotEmpty ? conversation.customerName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      );
    } else {
      final zaloState = ref.watch(zaloIntegrationProvider);
      final matching = zaloState.accounts.firstWhere(
        (a) => a.id == conversation.accountId,
        orElse: () => ZaloConnectedAccount(
          id: conversation.accountId,
          label: '',
          connected: true,
          listenerRunning: false,
        ),
      );
      final avatarUrl = matching.avatarUrl;
      final label = matching.label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
      final hasImg = avatarUrl.isNotEmpty;
      avatarWidget = CircleAvatar(
        radius: 13,
        backgroundColor: AppColors.surfaceMuted,
        backgroundImage: hasImg ? NetworkImage(avatarUrl) : null,
        child: !hasImg
            ? Text(
                label.isNotEmpty ? label[0].toUpperCase() : 'A',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            avatarWidget,
            const SizedBox(width: AppSpacing.s),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(context, textColor),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd/MM HH:mm').format(message.timestamp)} ${message.status}',
                    style: AppTextStyles.caption.copyWith(
                      color: textColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: AppSpacing.s),
            avatarWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Color textColor) {
    final trimmed = message.message.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final data = jsonDecode(trimmed);
        if (data is Map<String, dynamic>) {
          final title = data['title']?.toString() ?? '';
          final description = data['description']?.toString() ?? '';
          final href = data['href']?.toString() ?? data['url']?.toString() ?? '';
          final thumb = data['thumb']?.toString() ?? data['thumbnail']?.toString() ?? '';

          if (title.isNotEmpty || description.isNotEmpty || href.isNotEmpty) {
            return InkWell(
              onTap: href.isNotEmpty
                  ? () async {
                      final uri = Uri.tryParse(href);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  : null,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thumb.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: Image.network(
                          thumb,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
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
                                color: textColor.withOpacity(0.8),
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

    return Text(
      message.message,
      style: AppTextStyles.body.copyWith(color: textColor),
    );
  }
}

String _formatLastMessage(String rawMessage) {
  final trimmed = rawMessage.trim();

  // Try to parse using regex if it contains JSON keys representing a link card
  if (trimmed.contains('"title":') || trimmed.contains('"href":') || trimmed.contains('"url":')) {
    // 1. Try to extract "title" value
    final titleRegExp = RegExp(r'"title"\s*:\s*"([^"]+)"');
    final titleMatch = titleRegExp.firstMatch(trimmed);
    if (titleMatch != null) {
      final title = titleMatch.group(1) ?? '';
      if (title.isNotEmpty) {
        if (title.startsWith('http')) {
          return '[Liên kết] ${Uri.tryParse(title)?.host ?? title}';
        }
        return '[Liên kết] $title';
      }
    }

    // 2. Fallback to extracting "href" or "url" value
    final hrefRegExp = RegExp(r'"(?:href|url)"\s*:\s*"([^"]+)"');
    final hrefMatch = hrefRegExp.firstMatch(trimmed);
    if (hrefMatch != null) {
      final href = hrefMatch.group(1) ?? '';
      if (href.isNotEmpty) {
        return '[Liên kết] ${Uri.tryParse(href)?.host ?? href}';
      }
    }
    
    // 3. Fallback to general URL pattern
    final urlRegExp = RegExp(r'(https?://[^\s"]+)');
    final urlMatch = urlRegExp.firstMatch(trimmed);
    if (urlMatch != null) {
      final url = urlMatch.group(1) ?? '';
      return '[Liên kết] ${Uri.tryParse(url)?.host ?? url}';
    }

    return '[Liên kết]';
  }
  
  // If the raw message is just a raw URL, format it nicely
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return '[Liên kết] ${Uri.tryParse(trimmed)?.host ?? trimmed}';
  }

  return rawMessage;
}
