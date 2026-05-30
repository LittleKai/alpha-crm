import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_search_field.dart';
import '../../../../../shared/widgets/app_tabs.dart';

class FriendByGroupScreenPlaceholder extends StatefulWidget {
  const FriendByGroupScreenPlaceholder({super.key});

  @override
  State<FriendByGroupScreenPlaceholder> createState() =>
      _FriendByGroupScreenPlaceholderState();
}

class _FriendByGroupScreenPlaceholderState
    extends State<FriendByGroupScreenPlaceholder> {
  final _searchController = TextEditingController();
  final _groupLinkController = TextEditingController();
  final _messageController = TextEditingController(
    text: 'Chào bạn, mình kết bạn nhé!',
  );
  final _minDelayController = TextEditingController(text: '30');
  final _maxDelayController = TextEditingController(text: '60');
  int _sourceTab = 0;
  bool _sendInboxAfterAccepted = false;

  @override
  void dispose() {
    _searchController.dispose();
    _groupLinkController.dispose();
    _messageController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.l),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1100;
                  final memberPanel = _MemberPanel(
                    searchController: _searchController,
                    groupLinkController: _groupLinkController,
                    sourceTab: _sourceTab,
                    onSourceTabChanged: (index) {
                      setState(() {
                        _sourceTab = index;
                      });
                    },
                  );
                  final configPanel = _ConfigPanel(
                    messageController: _messageController,
                    minDelayController: _minDelayController,
                    maxDelayController: _maxDelayController,
                    sendInboxAfterAccepted: _sendInboxAfterAccepted,
                    onSendInboxChanged: (value) {
                      setState(() {
                        _sendInboxAfterAccepted = value ?? false;
                      });
                    },
                  );

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 560, child: memberPanel),
                          const SizedBox(height: AppSpacing.m),
                          configPanel,
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: memberPanel),
                      const SizedBox(width: AppSpacing.l),
                      Expanded(flex: 5, child: configPanel),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.groups_2_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kết bạn từ Nhóm Zalo', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quét thành viên và gửi lời mời kết bạn hàng loạt trong nhóm Zalo.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberPanel extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController groupLinkController;
  final int sourceTab;
  final ValueChanged<int> onSourceTabChanged;

  const _MemberPanel({
    required this.searchController,
    required this.groupLinkController,
    required this.sourceTab,
    required this.onSourceTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: searchController,
                    hintText: 'Tìm kiếm thành viên...',
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Lọc',
                  icon: Icons.filter_alt_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Bắt đầu',
                  icon: Icons.play_arrow_rounded,
                  onPressed: null,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppTabs(
                    isSegmented: true,
                    selectedIndex: sourceTab,
                    onTabSelected: onSourceTabChanged,
                    tabs: const [
                      AppTabItem(label: 'Quét từ link nhóm'),
                      AppTabItem(label: 'Chọn từ nhóm Zalo'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: groupLinkController,
                        style: AppTextStyles.body,
                        decoration: const InputDecoration(
                          hintText: 'Dán link nhóm Zalo (zalo.me/g/...)',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    AppButton(
                      text: 'Quét nhóm',
                      icon: Icons.notifications_none_rounded,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          const Expanded(
            child: _FeatureEmpty(
              title: 'THÀNH VIÊN NHÓM ZALO',
              description:
                  'Vui lòng nhập link nhóm hoặc chọn nhóm có sẵn và click "Quét nhóm" để hiển thị thành viên.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  final TextEditingController messageController;
  final TextEditingController minDelayController;
  final TextEditingController maxDelayController;
  final bool sendInboxAfterAccepted;
  final ValueChanged<bool?> onSendInboxChanged;

  const _ConfigPanel({
    required this.messageController,
    required this.minDelayController,
    required this.maxDelayController,
    required this.sendInboxAfterAccepted,
    required this.onSendInboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cấu hình kết bạn tự động',
                      style: AppTextStyles.sectionTitle,
                    ),
                    Text(
                      'Thiết lập thông số và nội dung cho chiến dịch',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          _Section(
            title: '1. CẤU HÌNH CHUNG',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn tài khoản Zalo gửi lời mời',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: AppSpacing.xs),
                const AppAlert(
                  message:
                      'Chưa có tài khoản nào kết nối. Vui lòng vào Cài đặt để đăng nhập.',
                  variant: AppAlertVariant.error,
                ),
                const SizedBox(height: AppSpacing.l),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: 'Delay tối thiểu (s)',
                        controller: minDelayController,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _NumberField(
                        label: 'Delay tối đa (s)',
                        controller: maxDelayController,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          _Section(
            title: '2. CẤU HÌNH NỘI DUNG',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lời nhắn kết bạn *', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    const _Token(label: 'Chèn mẫu Spintax xoay vòng'),
                    const Spacer(),
                    Text(
                      'Xoay vòng {A|B|C}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.l),
                const Divider(color: AppColors.borderSoft),
                CheckboxListTile(
                  value: sendInboxAfterAccepted,
                  onChanged: onSendInboxChanged,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Gửi inbox sau khi kết bạn',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusM,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            child: Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          Padding(padding: const EdgeInsets.all(AppSpacing.m), child: child),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _NumberField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTextStyles.body,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _Token extends StatelessWidget {
  final String label;

  const _Token({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppSpacing.borderRadiusS,
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _FeatureEmpty extends StatelessWidget {
  final String title;
  final String description;

  const _FeatureEmpty({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            width: 360,
            child: Text(
              description,
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
