import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_search_field.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/app_tabs.dart';
import '../../providers/bulk_messaging_provider.dart';

class BulkMessagingScreen extends ConsumerStatefulWidget {
  const BulkMessagingScreen({super.key});

  @override
  ConsumerState<BulkMessagingScreen> createState() =>
      _BulkMessagingScreenState();
}

class _BulkMessagingScreenState extends ConsumerState<BulkMessagingScreen> {
  final _campaignNameController = TextEditingController();
  final _recipientsController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _minDelayController = TextEditingController(text: '30');
  final _maxDelayController = TextEditingController(text: '60');

  @override
  void initState() {
    super.initState();
    _recipientsController.addListener(() {
      ref
          .read(bulkMessagingProvider.notifier)
          .setRecipientsText(_recipientsController.text);
    });
    _messageController.addListener(() {
      ref
          .read(bulkMessagingProvider.notifier)
          .setMessageText(_messageController.text);
    });
  }

  @override
  void dispose() {
    _campaignNameController.dispose();
    _recipientsController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkMessagingProvider);
    final notifier = ref.read(bulkMessagingProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.xl),
            _CampaignTabs(
              selectedIndex: state.selectedTab,
              onChanged: notifier.setSelectedTab,
              onManageCampaigns: _showPlaceholder,
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1100;
                  final children = [
                    _TargetPanel(
                      searchController: _searchController,
                      recipientsController: _recipientsController,
                      isSending: state.isSending,
                      onImport: _importDemoRecipients,
                      onPlaceholder: _showPlaceholder,
                    ),
                    _ConfigPanel(
                      campaignNameController: _campaignNameController,
                      messageController: _messageController,
                      minDelayController: _minDelayController,
                      maxDelayController: _maxDelayController,
                      notifier: notifier,
                      onPlaceholder: _showPlaceholder,
                    ),
                    _ZaloPreview(message: state.messageText),
                  ];

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          children[0],
                          const SizedBox(height: AppSpacing.m),
                          children[1],
                          const SizedBox(height: AppSpacing.m),
                          children[2],
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: children[0]),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(flex: 6, child: children[1]),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(flex: 4, child: children[2]),
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

  void _importDemoRecipients() {
    _recipientsController.text = '0901234567\n0987654321\n0912345678';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã nhập 3 SĐT mẫu vào danh sách.')),
    );
  }

  void _showPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chức năng này đang chờ thiết kế chi tiết.'),
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
        const Icon(Icons.near_me_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gửi tin nhắn hàng loạt', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tạo và quản lý các chiến dịch gửi tin nhắn Zalo tự động, cá nhân hóa.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CampaignTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onManageCampaigns;

  const _CampaignTabs({
    required this.selectedIndex,
    required this.onChanged,
    required this.onManageCampaigns,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AppTabs(
              selectedIndex: selectedIndex,
              onTabSelected: onChanged,
              tabs: const [
                AppTabItem(label: 'Gửi theo Số điện thoại', icon: Icons.phone),
                AppTabItem(label: 'Gửi vào nhóm Zalo', icon: Icons.groups_2),
                AppTabItem(label: 'Gửi cho Bạn bè Zalo', icon: Icons.group),
                AppTabItem(label: 'Nhãn phân loại Zalo', icon: Icons.badge),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        TextButton.icon(
          onPressed: onManageCampaigns,
          icon: const Icon(Icons.access_time, size: 17),
          label: Text(
            'Quản lý chiến dịch (0)',
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _TargetPanel extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController recipientsController;
  final bool isSending;
  final VoidCallback onImport;
  final VoidCallback onPlaceholder;

  const _TargetPanel({
    required this.searchController,
    required this.recipientsController,
    required this.isSending,
    required this.onImport,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: searchController,
                    hintText: 'Tìm kiếm liên hệ/SĐT...',
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Lọc',
                  icon: Icons.filter_alt_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: onPlaceholder,
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Bắt đầu chạy',
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
                  onPressed: isSending ? null : onImport,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          Expanded(
            child: recipientsController.text.trim().isEmpty
                ? const _ManualPhoneEmpty()
                : _RecipientPreview(controller: recipientsController),
          ),
        ],
      ),
    );
  }
}

class _ManualPhoneEmpty extends StatelessWidget {
  const _ManualPhoneEmpty();

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
          Text(
            'CRM ZALO - GỬI SĐT THỦ CÔNG',
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            width: 360,
            child: Text(
              'Vui lòng nhập danh sách số điện thoại ở phần soạn thảo bên dưới hoặc bấm nút "Nhập từ file" để tải tệp .txt chứa số điện thoại.',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientPreview extends StatelessWidget {
  final TextEditingController controller;

  const _RecipientPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final rows = controller.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: rows.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.borderSoft),
      itemBuilder: (context, index) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.phone, color: AppColors.primary, size: 18),
          title: Text(rows[index], style: AppTextStyles.bodyMedium),
        );
      },
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  final TextEditingController campaignNameController;
  final TextEditingController messageController;
  final TextEditingController minDelayController;
  final TextEditingController maxDelayController;
  final BulkMessagingNotifier notifier;
  final VoidCallback onPlaceholder;

  const _ConfigPanel({
    required this.campaignNameController,
    required this.messageController,
    required this.minDelayController,
    required this.maxDelayController,
    required this.notifier,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cấu hình chiến dịch gửi tin',
                          style: AppTextStyles.sectionTitle,
                        ),
                        Text(
                          'Thiết lập tên, tài khoản và nội dung tin nhắn gửi đi',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
            _Section(
              title: '1. CẤU HÌNH CHUNG',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tên chiến dịch *', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: campaignNameController,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      hintText: 'VD: Chúc mừng sinh nhật khách hàng tháng 5',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    'Chọn tài khoản Zalo gửi tin nhắn',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const AppAlert(
                    message:
                        'Chưa có tài khoản nào kết nối. Vui lòng vào Cài đặt để đăng nhập.',
                    variant: AppAlertVariant.error,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 420;
                      final fields = [
                        _NumberField(
                          controller: minDelayController,
                          label: 'Delay tối thiểu (s)',
                          onChanged: notifier.setMinDelay,
                        ),
                        _NumberField(
                          controller: maxDelayController,
                          label: 'Delay tối đa (s)',
                          onChanged: notifier.setMaxDelay,
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
            _Section(
              title: '2. CẤU HÌNH NỘI DUNG',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nội dung tin nhắn *',
                          style: AppTextStyles.label,
                        ),
                      ),
                      AppButton(
                        text: 'Chọn tin mẫu',
                        icon: Icons.inventory_2_outlined,
                        variant: AppButtonVariant.outline,
                        onPressed: onPlaceholder,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  const _EditorToolbar(),
                  TextField(
                    controller: messageController,
                    maxLines: 7,
                    minLines: 7,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      hintText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(AppSpacing.radiusS),
                          bottomRight: Radius.circular(AppSpacing.radiusS),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: const [
                      _TokenChip('{{tên}}'),
                      _TokenChip('{{sdt}}'),
                      _TokenChip('{{nhóm}}'),
                      _TokenChip('Spintax xoay vòng'),
                    ],
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

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
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
  final TextEditingController controller;
  final String label;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTextStyles.body,
      onChanged: (value) => onChanged(int.tryParse(value) ?? 0),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
          left: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusS),
          topRight: Radius.circular(AppSpacing.radiusS),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.format_bold, size: 16),
            tooltip: 'Đậm',
          ),
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.format_italic, size: 16),
            tooltip: 'Nghiêng',
          ),
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.format_underlined, size: 16),
            tooltip: 'Gạch chân',
          ),
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.strikethrough_s, size: 16),
            tooltip: 'Gạch ngang',
          ),
          const VerticalDivider(width: AppSpacing.m),
          const _MiniChip(icon: Icons.person, label: 'Tên'),
          const SizedBox(width: AppSpacing.xs),
          const _MiniChip(icon: Icons.phone, label: 'SĐT'),
          const SizedBox(width: AppSpacing.xs),
          const _MiniChip(icon: Icons.group, label: 'Nhóm'),
          const SizedBox(width: AppSpacing.xs),
          const _MiniChip(icon: Icons.shuffle, label: 'Spintax'),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppSpacing.borderRadiusS,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  final String label;

  const _TokenChip(this.label);

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

class _ZaloPreview extends StatelessWidget {
  final String message;

  const _ZaloPreview({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Xem trước hiển thị trên Zalo',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Kiểm tra giao diện tin nhắn trước khi gửi',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFDDEAF8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Container(
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.zaloBlue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 18,
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'KH',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        const Expanded(
                          child: Text(
                            'Khách hàng Zalo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (message.trim().isNotEmpty)
                          Positioned(
                            left: AppSpacing.m,
                            top: AppSpacing.m,
                            right: AppSpacing.xl,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.s),
                                child: Text(message, style: AppTextStyles.body),
                              ),
                            ),
                          ),
                        Positioned(
                          right: AppSpacing.m,
                          bottom: AppSpacing.m,
                          child: Container(
                            width: 28,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC7E8FF),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
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
      ),
    );
  }
}
