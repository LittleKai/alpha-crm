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
import '../../../../../shared/widgets/app_select_field.dart';

class FriendByPhoneScreenPlaceholder extends StatefulWidget {
  const FriendByPhoneScreenPlaceholder({super.key});

  @override
  State<FriendByPhoneScreenPlaceholder> createState() =>
      _FriendByPhoneScreenPlaceholderState();
}

class _FriendByPhoneScreenPlaceholderState
    extends State<FriendByPhoneScreenPlaceholder> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController(
    text: 'Chào bạn, mình kết bạn nhé!',
  );
  final _minDelayController = TextEditingController(text: '30');
  final _maxDelayController = TextEditingController(text: '60');
  bool _sendInboxAfterAccepted = false;

  @override
  void dispose() {
    _searchController.dispose();
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
            const _PageHeader(
              icon: Icons.phone_in_talk_outlined,
              title: 'Kết bạn theo Số điện thoại',
              subtitle:
                  'Gửi lời mời kết bạn hàng loạt theo danh sách số điện thoại hoặc nhóm danh bạ.',
            ),
            const SizedBox(height: AppSpacing.l),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1100;
                  final targetPanel = _TargetPhonePanel(
                    searchController: _searchController,
                  );
                  final configPanel = _FriendConfigPanel(
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
                          SizedBox(height: 560, child: targetPanel),
                          const SizedBox(height: AppSpacing.m),
                          configPanel,
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: targetPanel),
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

class _PageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PageHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetPhonePanel extends StatelessWidget {
  final TextEditingController searchController;

  const _TargetPhonePanel({required this.searchController});

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
                    hintText: 'Tìm kiếm SĐT...',
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
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: AppSelectField<String>(
                    hintText: 'Chọn nhóm',
                    items: const [],
                    onChanged: null,
                  ),
                ),
                const Spacer(),
                AppButton(
                  text: 'Nhập từ file (.txt)',
                  icon: Icons.description_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          const Expanded(
            child: _FeatureEmpty(
              title: 'CRM ZALO - KẾT BẠN TỰ ĐỘNG',
              description:
                  'Vui lòng nhập danh sách số điện thoại hoặc chọn tệp .txt để lọc và thực hiện chiến dịch.',
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendConfigPanel extends StatelessWidget {
  final TextEditingController messageController;
  final TextEditingController minDelayController;
  final TextEditingController maxDelayController;
  final bool sendInboxAfterAccepted;
  final ValueChanged<bool?> onSendInboxChanged;

  const _FriendConfigPanel({
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
          _AccordionSection(
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack = constraints.maxWidth < 430;
                    final fields = [
                      _NumberField(
                        label: 'Delay tối thiểu (s)',
                        controller: minDelayController,
                      ),
                      _NumberField(
                        label: 'Delay tối đa (s)',
                        controller: maxDelayController,
                      ),
                    ];
                    if (stack) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: AppSpacing.s),
                          fields[1],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          _AccordionSection(
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
                    _TokenButton(label: 'Chèn mẫu Spintax xoay vòng'),
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

class _AccordionSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _AccordionSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

class _TokenButton extends StatelessWidget {
  final String label;

  const _TokenButton({required this.label});

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
