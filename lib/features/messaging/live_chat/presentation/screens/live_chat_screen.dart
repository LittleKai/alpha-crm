import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
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

class _Header extends StatelessWidget {
  final LiveChatState state;
  final VoidCallback onRefresh;
  final ValueChanged<LiveChatAccount?> onAccountChanged;

  const _Header({
    required this.state,
    required this.onRefresh,
    required this.onAccountChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                'Tin nhan Zalo realtime, ghi chu hoi thoai va handoff chatbot.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<LiveChatAccount>(
            initialValue: state.selectedAccount,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: state.accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account,
                    child: Text(account.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: onAccountChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        IconButton(
          tooltip: 'Tai lai',
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

class _ConversationList extends StatelessWidget {
  final LiveChatState state;
  final LiveChatNotifier notifier;
  final TextEditingController searchController;

  const _ConversationList({
    required this.state,
    required this.notifier,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Tim hoi thoai...',
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
                    title: 'Chua co hoi thoai',
                    description:
                        state.errorMessage ??
                        'Tin nhan moi se hien thi tai day.',
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
                      return ListTile(
                        selected: selected,
                        selectedTileColor: AppColors.primarySoft,
                        leading: CircleAvatar(
                          child: Text(conversation.customerAvatar),
                        ),
                        title: Text(
                          conversation.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium,
                        ),
                        subtitle: Text(
                          conversation.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

class _ConversationPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final conversation = state.selectedConversation;
    if (conversation == null) {
      return const AppCard(
        child: AppEmptyState(
          icon: Icons.mark_chat_unread_outlined,
          title: 'Chon mot hoi thoai',
          description: 'Noi dung tin nhan va ghi chu se hien thi tai day.',
          height: 420,
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                CircleAvatar(child: Text(conversation.customerAvatar)),
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
                        '${conversation.threadType} - ${conversation.accountId}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.m),
              itemCount: conversation.messages.length,
              itemBuilder: (context, index) {
                final message = conversation.messages[index];
                return _MessageBubble(message: message);
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
                      hintText: 'Nhap tin nhan...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Gui',
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
                      labelText: 'Nhan',
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
                      labelText: 'Ghi chu',
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isMine
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = message.isMine ? AppColors.primary : AppColors.surfaceMuted;
    final textColor = message.isMine ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s),
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
              Text(
                message.message,
                style: AppTextStyles.body.copyWith(color: textColor),
              ),
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
    );
  }
}
