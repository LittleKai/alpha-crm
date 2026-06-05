import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/zalo_compliance_guard.dart';
export '../utils/zalo_compliance_guard.dart' show ZaloActionType;

/// Một nút Icon cảnh báo nhấp nháy đẹp mắt hiển thị số lượng cảnh báo chủ động
/// Khi click vào sẽ mở ra popup danh sách các cảnh báo bảo mật & tuân thủ.
class WarningIconButton extends StatefulWidget {
  final ZaloActionType? actionType;
  const WarningIconButton({super.key, this.actionType});

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
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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

  int _getWarningCount(ZaloActionType? actionType) {
    if (actionType == null) return 5;
    final isBulk =
        actionType == ZaloActionType.bulkMessageByPhone ||
        actionType == ZaloActionType.bulkMessageToGroup ||
        actionType == ZaloActionType.bulkMessageToFriends ||
        actionType == ZaloActionType.chatbotReply ||
        actionType == ZaloActionType.liveChatReply;

    final isFriend =
        actionType == ZaloActionType.friendByPhone ||
        actionType == ZaloActionType.friendByGroup;

    final isGroup =
        actionType == ZaloActionType.joinGroups ||
        actionType == ZaloActionType.inviteToGroup ||
        actionType == ZaloActionType.createGroups ||
        actionType == ZaloActionType.scanGroupMembers;

    if (isBulk) return 3;
    if (isFriend) return 3;
    if (isGroup) return 3;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final int warningCount = _getWarningCount(widget.actionType);

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
                    color: AppColors.warning.withValues(alpha: 0.25),
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
                      decoration: BoxDecoration(
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
              onPressed: () => showComplianceWarningsDialog(
                context,
                actionType: widget.actionType,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Hiển thị Dialog trung tâm tuân thủ & an toàn Zalo CRM
void showComplianceWarningsDialog(
  BuildContext context, {
  String? activeWarning,
  ZaloActionType? actionType,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return _ComplianceWarningsDialog(
        activeWarning: activeWarning,
        actionType: actionType,
      );
    },
  );
}

class _ComplianceWarningsDialog extends StatelessWidget {
  final String? activeWarning;
  final ZaloActionType? actionType;

  const _ComplianceWarningsDialog({this.activeWarning, this.actionType});

  List<Widget> _buildRulesList() {
    final List<Widget> items = [];

    // Group rules based on ZaloActionType
    final isBulk =
        actionType == ZaloActionType.bulkMessageByPhone ||
        actionType == ZaloActionType.bulkMessageToGroup ||
        actionType == ZaloActionType.bulkMessageToFriends ||
        actionType == ZaloActionType.chatbotReply ||
        actionType == ZaloActionType.liveChatReply;

    final isFriend =
        actionType == ZaloActionType.friendByPhone ||
        actionType == ZaloActionType.friendByGroup;

    final isGroup =
        actionType == ZaloActionType.joinGroups ||
        actionType == ZaloActionType.inviteToGroup ||
        actionType == ZaloActionType.createGroups ||
        actionType == ZaloActionType.scanGroupMembers;

    if (isBulk || actionType == null) {
      items.addAll([
        const _WarningItem(
          title: 'Thời gian chờ (Delay) tự động',
          description:
              'Khuyến nghị cài đặt khoảng trễ ngẫu nhiên từ 30-60 giây giữa các tin nhắn. Giãn cách giúp hoạt động tự động tương tự thao tác của người dùng thật, giảm thiểu tối đa nguy cơ bị Zalo quét khóa tài khoản.',
          badgeText: 'Khuyến nghị',
          badgeColor: Colors.blue,
          icon: Icons.timer_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        const _WarningItem(
          title: 'Tự động hóa tài khoản cá nhân',
          description:
              'Sử dụng các công cụ tự động hóa thông qua QR login hoặc giả lập có rủi ro bị khóa tài khoản theo Chính sách Zalo. Hãy chuyển sang kết nối Official Account nếu cần gửi tin nhắn số lượng lớn.',
          badgeText: 'Nguy cơ cao',
          badgeColor: Colors.red,
          icon: Icons.report_gmailerrorred_rounded,
        ),
        const SizedBox(height: AppSpacing.m),
        const _WarningItem(
          title: 'Sự đồng ý & Tương tác hai chiều',
          description:
              'Để tránh bị Zalo quét vi phạm spam, bạn nên nhận được sự đồng ý trước của khách hàng hoặc họ đã từng nhắn tin trao đổi với bạn trước khi thực hiện gửi tin nhắn hàng loạt.',
          badgeText: 'Quy định',
          badgeColor: Colors.indigo,
          icon: Icons.check_circle_outline_rounded,
        ),
      ]);
    } else if (isFriend) {
      items.addAll([
        const _WarningItem(
          title: 'Thời gian chờ (Delay) tự động',
          description:
              'Khuyến nghị cài đặt khoảng trễ từ 30-60 giây giữa các lời mời kết bạn. Giãn cách giúp tài khoản hoạt động tự nhiên, tránh bị Zalo quét spam chặn kết bạn.',
          badgeText: 'Khuyến nghị',
          badgeColor: Colors.blue,
          icon: Icons.timer_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        const _WarningItem(
          title: 'Giới hạn kết bạn hàng ngày',
          description:
              'Zalo quy định hạn mức kết bạn tối đa của tài khoản cá nhân hàng ngày. Tránh gửi quá nhiều lời mời trong 24 giờ để tránh bị khóa tính năng kết bạn.',
          badgeText: 'Bảo mật',
          badgeColor: Colors.orange,
          icon: Icons.person_add_alt_1_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        const _WarningItem(
          title: 'Tự động hóa tài khoản cá nhân',
          description:
              'Sử dụng công cụ tự động gửi kết bạn hàng loạt qua QR login hoặc giả lập có rủi ro bị khóa tài khoản theo Chính sách Zalo. Alpha CRM khuyến khích chia nhỏ chiến dịch để chạy an toàn.',
          badgeText: 'Nguy cơ cao',
          badgeColor: Colors.red,
          icon: Icons.report_gmailerrorred_rounded,
        ),
      ]);
    } else if (isGroup) {
      items.addAll([
        const _WarningItem(
          title: 'Giới hạn hoạt động nhóm',
          description:
              'Mời quá nhiều người lạ vào nhóm hoặc tham gia/tạo quá nhiều nhóm trong ngày dễ bị Zalo báo cáo vi phạm cộng đồng. Hãy chia nhỏ chiến dịch ra nhiều ngày.',
          badgeText: 'Bảo mật',
          badgeColor: Colors.orange,
          icon: Icons.group_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        const _WarningItem(
          title: 'Thời gian chờ (Delay) tự động',
          description:
              'Khuyến nghị cài đặt khoảng trễ từ 10-20 giây giữa các thao tác mời, tham gia hoặc tạo nhóm để Zalo không nhận diện hành vi bot tự động.',
          badgeText: 'Khuyến nghị',
          badgeColor: Colors.blue,
          icon: Icons.timer_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        const _WarningItem(
          title: 'Tự động hóa tài khoản cá nhân',
          description:
              'Sử dụng các công cụ tự động hóa thông qua QR login hoặc giả lập có rủi ro bị khóa tài khoản theo Chính sách Zalo. Alpha CRM khuyến khích kiểm soát tốt số lượng nhóm xử lý.',
          badgeText: 'Nguy cơ cao',
          badgeColor: Colors.red,
          icon: Icons.report_gmailerrorred_rounded,
        ),
      ]);
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final hasWarning = activeWarning != null;

    final isBulk =
        actionType == ZaloActionType.bulkMessageByPhone ||
        actionType == ZaloActionType.bulkMessageToGroup ||
        actionType == ZaloActionType.bulkMessageToFriends ||
        actionType == ZaloActionType.chatbotReply ||
        actionType == ZaloActionType.liveChatReply;

    final isFriend =
        actionType == ZaloActionType.friendByPhone ||
        actionType == ZaloActionType.friendByGroup;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final textMuted = isDark ? const Color(0xFF64748B) : AppColors.textMuted;
    final appBackground = isDark
        ? const Color(0xFF0B1120)
        : AppColors.appBackground;
    final borderSoft = isDark ? const Color(0xFF253247) : AppColors.borderSoft;

    final activeWarningBg = isDark
        ? const Color(0xFF3F2D00)
        : const Color(0xFFFFFBEB);
    final activeWarningBorder = isDark
        ? const Color(0xFFD97706)
        : const Color(0xFFFDE68A);
    final activeWarningTextColor = isDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFF92400E);

    final safeBg = isDark ? const Color(0xFF003F2D) : const Color(0xFFECFDF5);
    final safeBorder = isDark
        ? const Color(0xFF10B981)
        : const Color(0xFFA7F3D0);
    final safeTextColor = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF047857);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusM),
      backgroundColor: surfaceColor,
      elevation: 24,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Dialog với dải màu gradient cao cấp (Amber cho warning, Slate cho safe)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.l,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasWarning
                      ? const [
                          Color(0xFFD97706),
                          Color(0xFFB45309),
                        ] // Deep Amber warning gradient
                      : const [
                          Color(0xFF0F172A),
                          Color(0xFF1E293B),
                        ], // Dark slate premium gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasWarning
                        ? Icons.security_rounded
                        : Icons.gpp_good_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'An Toàn & Tuân Thủ Zalo',
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Các khuyến cáo quan trọng nhằm bảo vệ tài khoản của bạn',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Danh sách cảnh báo cuộn
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.l,
                ),
                children: [
                  // Active warning card (if any) or Success card
                  if (hasWarning)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      margin: const EdgeInsets.only(bottom: AppSpacing.l),
                      decoration: BoxDecoration(
                        color: activeWarningBg,
                        borderRadius: AppSpacing.borderRadiusM,
                        border: Border.all(
                          color: activeWarningBorder,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFD97706,
                            ).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.report_problem_rounded,
                                color: AppColors.warningText,
                                size: 22,
                              ),
                              SizedBox(width: AppSpacing.s),
                              Text(
                                'CẢNH BÁO TỪ TIẾN TRÌNH HIỆN TẠI',
                                style: TextStyle(
                                  color: AppColors.warningText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s),
                          Text(
                            activeWarning!,
                            style: TextStyle(
                              color: activeWarningTextColor,
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      margin: const EdgeInsets.only(bottom: AppSpacing.l),
                      decoration: BoxDecoration(
                        color: safeBg,
                        borderRadius: AppSpacing.borderRadiusM,
                        border: Border.all(color: safeBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HỆ THỐNG AN TOÀN',
                                  style: TextStyle(
                                    color: Color(0xFF065F46),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Không phát hiện thấy rủi ro chặn hành động nào ở màn hình hiện tại.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: safeTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  Text(
                    actionType == null
                        ? 'QUY TẮC AN TOÀN CHUNG KHI SỬ DỤNG ZALO'
                        : (isBulk
                              ? 'QUY TẮC AN TOÀN GỬI TIN NHẮN'
                              : (isFriend
                                    ? 'QUY TẮC AN TOÀN KẾT BẠN'
                                    : 'QUY TẮC AN TOÀN HOẠT ĐỘNG NHÓM')),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  ..._buildRulesList(),
                ],
              ),
            ),

            // Footer Dialog
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.m,
              ),
              decoration: BoxDecoration(
                color: appBackground,
                border: Border(top: BorderSide(color: borderSoft, width: 1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: textMuted),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      'Cấu hình an toàn có thể tùy chỉnh trong phần "Cài đặt".',
                      style: AppTextStyles.caption.copyWith(color: textMuted),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.borderRadiusS,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.m,
                      ),
                      elevation: 0,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF162033) : AppColors.surface;
    final borderSoftColor = isDark
        ? const Color(0xFF253247)
        : AppColors.borderSoft;
    final textPrimaryColor = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textSecondaryColor = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: borderSoftColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              color: badgeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 20),
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
                          color: textPrimaryColor,
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
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.3),
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
                    color: textSecondaryColor,
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
