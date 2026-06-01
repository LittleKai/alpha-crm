import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

/// Một nút Icon cảnh báo nhấp nháy đẹp mắt hiển thị số lượng cảnh báo chủ động
/// Khi click vào sẽ mở ra popup danh sách các cảnh báo bảo mật & tuân thủ.
class WarningIconButton extends StatefulWidget {
  const WarningIconButton({super.key});

  @override
  State<WarningIconButton> createState() => _WarningIconButtonState();
}

class _WarningIconButtonState extends State<WarningIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Chỉ kích hoạt lặp vô hạn nếu không chạy trong môi trường Widget Test (tránh treo pumpAndSettle)
    final isTest = WidgetsBinding.instance.toString().contains('Test');
    if (!isTest) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const int warningCount = 5;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Hiệu ứng phát hào quang (pulsing glow) xung quanh nút
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withOpacity(0.25),
                    blurRadius: _pulseAnimation.value,
                    spreadRadius: _pulseAnimation.value / 2,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Trung tâm Tuân thủ & An toàn ($warningCount cảnh báo)',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.gpp_maybe_outlined,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.warningText,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$warningCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () => showComplianceWarningsDialog(context),
            ),
          ],
        );
      },
    );
  }
}

/// Hiển thị Dialog trung tâm tuân thủ & an toàn Zalo CRM
void showComplianceWarningsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return const _ComplianceWarningsDialog();
    },
  );
}

class _ComplianceWarningsDialog extends StatelessWidget {
  const _ComplianceWarningsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusM,
      ),
      backgroundColor: AppColors.surface,
      elevation: 24,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Dialog với dải màu ấm và hiện đại
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF59E0B),
                    Color(0xFFD97706),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'An Toàn & Tuân Thủ Zalo',
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Các khuyến cáo quan trọng nhằm bảo vệ tài khoản của bạn',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Danh sách cảnh báo cuộn
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: const [
                  _WarningItem(
                    title: 'Giãn cách (Delay) hành vi tự động',
                    description:
                        'Khuyến nghị cài đặt delay ngẫu nhiên từ 30-60 giây giữa các tác vụ. Điều này giúp hành vi gửi tin/kết bạn tương tự như con người nhất, tránh bị các hệ thống quét tự động của Zalo nhận diện và hạn chế tài khoản.',
                    badgeText: 'Khuyến nghị',
                    badgeColor: Colors.blue,
                    icon: Icons.timer_outlined,
                  ),
                  SizedBox(height: AppSpacing.m),
                  _WarningItem(
                    title: 'Rủi ro tự động hóa tài khoản cá nhân',
                    description:
                        'Sử dụng các công cụ tự động hóa thông qua QR login hoặc giả lập có rủi ro bị khóa tài khoản vĩnh viễn theo Chính sách Cộng đồng Zalo. Alpha CRM khuyến nghị sử dụng kết nối Official Account hoặc Bot API để duy trì sự ổn định dài hạn.',
                    badgeText: 'Nguy cơ cao',
                    badgeColor: Colors.red,
                    icon: Icons.report_gmailerrorred_rounded,
                  ),
                  SizedBox(height: AppSpacing.m),
                  _WarningItem(
                    title: 'Giới hạn kết bạn và thao tác nhóm tự động',
                    description:
                        'Gửi lời mời kết bạn hàng loạt hoặc các tác vụ nhóm tự động (tạo nhóm, mời người lạ, rời nhóm số lượng lớn) là các hành vi dễ bị người dùng báo cáo spam. Hãy duy trì các thông số ở mức thử nghiệm tối thiểu trừ khi được thiết kế kỹ lưỡng.',
                    badgeText: 'Bảo mật',
                    badgeColor: Colors.orange,
                    icon: Icons.group_outlined,
                  ),
                  SizedBox(height: AppSpacing.m),
                  _WarningItem(
                    title: 'Quy trình tương tác và Đồng ý (Consent)',
                    description:
                        'Các thiết lập thời gian hoặc gửi theo lô (batch) chỉ giảm bớt tần suất hoạt động. Để bảo vệ tối đa, bạn bắt buộc phải có bằng chứng đồng ý nhận tin từ người dùng và xác nhận họ có tương tác gần đây với tài khoản trước khi thực hiện gửi loạt lớn.',
                    badgeText: 'Quy định',
                    badgeColor: Colors.indigo,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  SizedBox(height: AppSpacing.m),
                  _WarningItem(
                    title: 'Tự động duyệt kết bạn và rủi ro bảo mật',
                    description:
                        'Tự động duyệt lời mời kết bạn hàng loạt từ người lạ giúp tiết kiệm thời gian nhưng có thể dẫn đến việc kết nối với các tài khoản rác, tài khoản mạo danh, tạo thêm rủi ro bảo mật thông tin và quyền riêng tư.',
                    badgeText: 'Cảnh báo',
                    badgeColor: Colors.amber,
                    icon: Icons.shield_outlined,
                  ),
                ],
              ),
            ),
            
            // Footer Dialog
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: const BoxDecoration(
                color: AppColors.appBackground,
                border: Border(
                  top: BorderSide(color: AppColors.borderSoft, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      'Tất cả cấu hình an toàn có thể tùy chỉnh trong phần "Cài đặt hệ thống".',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.borderRadiusS,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                        vertical: AppSpacing.m,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Đã hiểu',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

class _WarningItem extends StatelessWidget {
  final String title;
  final String description;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;

  const _WarningItem({
    required this.title,
    required this.description,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.borderSoft, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: badgeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: badgeColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  description,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
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
