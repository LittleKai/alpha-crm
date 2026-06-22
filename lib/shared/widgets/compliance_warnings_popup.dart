import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/zalo_compliance_guard.dart';
export '../utils/zalo_compliance_guard.dart' show ZaloActionType;

/// Một nút Icon cảnh báo (hào quang tĩnh) hiển thị số lượng cảnh báo chủ động.
///
/// LƯU Ý HIỆU NĂNG: KHÔNG dùng animation lặp vô hạn ở đây. Nút này nằm trong
/// header của MỌI màn rủi ro cao; một animation `repeat()` sẽ ép engine dựng
/// frame 60fps liên tục, khiến các glass-card BackdropFilter (blur) trên màn
/// hình phải rasterize lại mỗi frame trên luồng raster → treo UI + CPU rất cao
/// (BackdropFilter không thể cache qua RepaintBoundary). Hào quang để TĨNH.
class WarningIconButton extends StatelessWidget {
  final ZaloActionType? actionType;
  const WarningIconButton({super.key, this.actionType});

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
    final int warningCount = _getWarningCount(actionType);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Hào quang TĨNH quanh nút (không animation → không ép vẽ frame liên tục).
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.25),
                blurRadius: 6,
                spreadRadius: 3,
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
            actionType: actionType,
          ),
        ),
      ],
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

    switch (actionType) {
      case ZaloActionType.bulkMessageByPhone:
        items.addAll([
          const _WarningItem(
            title: 'Thời gian chờ (Delay) tự động',
            description:
                'Khuyến nghị cài đặt khoảng trễ ngẫu nhiên từ 30-60 giây giữa các tin nhắn. Giãn cách giúp hoạt động tự động tương tự thao tác của người dùng thật, tránh bị bộ lọc quét khóa tài khoản.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Danh sách SĐT chưa lưu danh bạ',
            description:
                'Gửi tin nhắn hàng loạt đến SĐT chưa lưu hoặc chưa tương tác trước có rủi ro bị báo cáo spam rất cao. Alpha CRM khuyên bạn nên chia nhỏ và kiểm soát chất lượng danh sách.',
            badgeText: 'Nguy cơ cao',
            badgeColor: Colors.red,
            icon: Icons.report_gmailerrorred_rounded,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Chế độ thử nghiệm (Test Mode)',
            description:
                'Hãy bật chế độ thử nghiệm trước khi chạy chiến dịch thật để kiểm tra cấu hình tin nhắn và danh bạ gửi không bị lỗi.',
            badgeText: 'Mẹo an toàn',
            badgeColor: Colors.green,
            icon: Icons.info_outline,
          ),
        ]);
        break;

      case ZaloActionType.bulkMessageToGroup:
        items.addAll([
          const _WarningItem(
            title: 'Khoảng cách gửi tin vào nhóm',
            description:
                'Cần giãn cách ít nhất 10-20 giây giữa các nhóm. Đăng tin liên tục vào quá nhiều nhóm cùng một thời điểm sẽ bị hệ thống chống spam của Zalo phát hiện.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Nội dung tin nhắn giá trị',
            description:
                'Đảm bảo nội dung hữu ích, đúng chủ đề của nhóm. Nếu thành viên báo cáo xấu (spam) quá nhiều, tài khoản Zalo của bạn sẽ bị giới hạn tính năng chat nhóm.',
            badgeText: 'Quy định',
            badgeColor: Colors.indigo,
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Xoay vòng nội dung tin nhắn',
            description:
                'Sử dụng các biến động nội dung hoặc trộn văn bản (spintax) để các tin gửi vào nhóm không trùng lặp hoàn toàn, giúp tăng độ an toàn.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.orange,
            icon: Icons.dynamic_feed,
          ),
        ]);
        break;

      case ZaloActionType.bulkMessageToFriends:
        items.addAll([
          const _WarningItem(
            title: 'Độ trễ gửi tin bạn bè',
            description:
                'Gửi tin cho bạn bè an toàn hơn SĐT lạ, nhưng bạn vẫn nên giữ độ trễ từ 15-30 giây giữa các tin nhắn để tài khoản hoạt động tự nhiên.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Giới hạn số lượng hàng ngày',
            description:
                'Alpha CRM khuyên bạn không nên gửi vượt quá 200-300 bạn bè mỗi ngày để tránh tài khoản bị đưa vào danh sách theo dõi lưu lượng bất thường.',
            badgeText: 'Bảo mật',
            badgeColor: Colors.orange,
            icon: Icons.security,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Cá nhân hóa nội dung',
            description:
                'Dùng thẻ {{tên}} để tự động chèn tên bạn bè vào nội dung. Tin nhắn cá nhân hóa giúp giảm tỷ lệ bị bạn bè đánh dấu là tin nhắn quảng cáo phiền phức.',
            badgeText: 'Mẹo an toàn',
            badgeColor: Colors.green,
            icon: Icons.person_outline,
          ),
        ]);
        break;

      case ZaloActionType.friendByPhone:
        items.addAll([
          const _WarningItem(
            title: 'Thời gian chờ gửi lời mời',
            description:
                'Khuyến nghị cài đặt khoảng trễ ngẫu nhiên từ 30-60 giây giữa các lời mời kết bạn để Zalo không nhận diện hành vi bot tự động.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Giới hạn kết bạn mỗi ngày',
            description:
                'Tránh gửi quá 30-50 lời mời kết bạn qua SĐT mỗi ngày. Vượt quá hạn mức này có thể bị Zalo khóa tính năng tìm kiếm tài khoản qua số điện thoại.',
            badgeText: 'Bảo mật',
            badgeColor: Colors.orange,
            icon: Icons.person_add_alt_1_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Lời nhắn kết bạn thân thiện',
            description:
                'Soạn nội dung kết bạn rõ ràng mục đích, xưng hô lịch sự để người nhận dễ dàng chấp nhận và không bấm báo cáo spam/người lạ quấy rối.',
            badgeText: 'Mẹo an toàn',
            badgeColor: Colors.green,
            icon: Icons.rate_review_outlined,
          ),
        ]);
        break;

      case ZaloActionType.friendByGroup:
        items.addAll([
          const _WarningItem(
            title: 'Giãn cách kết bạn thành viên',
            description:
                'Khuyến nghị cài đặt khoảng trễ từ 30-60 giây giữa các lời mời kết bạn từ thành viên nhóm. Giãn cách tự nhiên giúp tài khoản an toàn hơn.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Lựa chọn nhóm phù hợp',
            description:
                'Gửi lời mời kết bạn với thành viên trong các nhóm có chung chủ đề sở thích/công việc sẽ tăng tỷ lệ chấp nhận lời mời lên đáng kể.',
            badgeText: 'Mẹo an toàn',
            badgeColor: Colors.green,
            icon: Icons.group_add_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Giới hạn kết bạn Zalo',
            description:
                'Tài khoản cá nhân có hạn mức kết bạn tối đa hàng ngày. Hãy kiểm soát số lượng gửi đi để tránh bị khóa tạm thời tính năng kết bạn.',
            badgeText: 'Quy định',
            badgeColor: Colors.indigo,
            icon: Icons.security,
          ),
        ]);
        break;

      case ZaloActionType.scanGroupMembers:
        items.addAll([
          const _WarningItem(
            title: 'Bảo mật thông tin nhóm',
            description:
                'Quét danh sách thành viên chỉ khả dụng với các nhóm công khai hoặc nhóm bạn đã tham gia làm thành viên hoạt động.',
            badgeText: 'Quy định',
            badgeColor: Colors.indigo,
            icon: Icons.lock_open_rounded,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Hạn chế quét liên tục',
            description:
                'Không nên quét danh sách thành viên của quá nhiều nhóm lớn cùng lúc để tránh bị Zalo tạm khóa tính năng do truy vấn dữ liệu API bất thường.',
            badgeText: 'Bảo mật',
            badgeColor: Colors.orange,
            icon: Icons.report_gmailerrorred_rounded,
          ),
        ]);
        break;

      case ZaloActionType.joinGroups:
        items.addAll([
          const _WarningItem(
            title: 'Hạn mức tham gia nhóm',
            description:
                'Không nên tham gia quá 5-10 nhóm mới mỗi ngày. Việc tài khoản đột ngột gia nhập nhiều nhóm trong thời gian ngắn sẽ bị Zalo đánh dấu bất thường.',
            badgeText: 'Bảo mật',
            badgeColor: Colors.orange,
            icon: Icons.group_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Khoảng trễ tham gia nhóm',
            description:
                'Khuyến nghị cài đặt khoảng trễ từ 15-30 giây trước khi bấm tham gia nhóm tiếp theo để hoạt động giống người dùng thật.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.timer_outlined,
          ),
        ]);
        break;

      case ZaloActionType.inviteToGroup:
        items.addAll([
          const _WarningItem(
            title: 'Mời bạn bè có chọn lọc',
            description:
                'Chỉ nên mời những bạn bè thực sự quan tâm đến chủ đề của nhóm. Mời hàng loạt người không quan tâm sẽ làm tăng tỷ lệ bị họ thoát nhóm và báo cáo phiền hà.',
            badgeText: 'Quy định',
            badgeColor: Colors.indigo,
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Hạn mức mời vào nhóm',
            description:
                'Không nên mời quá 50 người vào nhóm mỗi ngày để giữ tài khoản Zalo của bạn luôn an toàn trước các bộ lọc quét tự động.',
            badgeText: 'Bảo mật',
            badgeColor: Colors.orange,
            icon: Icons.group_add_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Giãn cách gửi lời mời',
            description:
                'Duy trì khoảng trễ từ 5-10 giây cho mỗi lượt mời thành viên để hạn chế tối đa nguy cơ bị quét bot tự động.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.timer_outlined,
          ),
        ]);
        break;

      case ZaloActionType.createGroups:
        items.addAll([
          const _WarningItem(
            title: 'Giới hạn tạo nhóm hàng loạt',
            description:
                'Tạo nhiều nhóm trong ngày rất dễ bị Zalo quét khóa tài khoản. Chỉ nên tạo tối đa 3-5 nhóm mỗi ngày tùy vào độ tin cậy của tài khoản.',
            badgeText: 'Bảo mật',
            badgeColor: Colors.orange,
            icon: Icons.group_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Giãn cách khi tạo nhóm',
            description:
                'Thiết lập khoảng trễ từ 20-30 giây giữa các thao tác tạo nhóm và tự động thêm các thành viên đã chọn.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Thêm thành viên chọn lọc',
            description:
                'Chỉ thêm các bạn bè thân thiết hoặc đã tương tác vào nhóm mới lập để tránh bị họ thoát nhóm ngay lập tức và báo cáo spam nhóm.',
            badgeText: 'Quy định',
            badgeColor: Colors.indigo,
            icon: Icons.check_circle_outline_rounded,
          ),
        ]);
        break;

      case ZaloActionType.liveChatReply:
        items.addAll([
          const _WarningItem(
            title: 'Tương tác trực tiếp (Live Chat)',
            description:
                'Hoạt động chat thủ công trực tiếp từ tư vấn viên có độ an toàn và tin cậy cao nhất. Bạn có thể trò chuyện thoải mái với khách hàng.',
            badgeText: 'Bảo mật',
            badgeColor: Colors.green,
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Hạn chế spam tin mẫu',
            description:
                'Tránh việc copy-paste gửi cùng một mẫu tin nhắn dài giống hệt nhau liên tục cho nhiều khách hàng khác nhau trong vài giây.',
            badgeText: 'Khuyến nghị',
            badgeColor: Colors.blue,
            icon: Icons.copy_all,
          ),
        ]);
        break;

      case ZaloActionType.chatbotReply:
        items.addAll([
          const _WarningItem(
            title: 'Giám sát hành vi của Bot',
            description:
                'Thiết lập kịch bản chatbot tự nhiên, tránh trả lời liên tục dồn dập khiến khách hàng khó chịu và nhấn nút báo cáo spam tài khoản của bạn.',
            badgeText: 'Bảo mật',
            badgeColor: Colors.orange,
            icon: Icons.smart_toy_outlined,
          ),
          const SizedBox(height: AppSpacing.m),
          const _WarningItem(
            title: 'Hỗ trợ chuyển đổi tư vấn viên',
            description:
                'Luôn tích hợp nút chuyển tiếp gặp tư vấn viên thật khi chatbot không giải quyết được vấn đề của khách hàng để tối ưu trải nghiệm.',
            badgeText: 'Quy định',
            badgeColor: Colors.indigo,
            icon: Icons.contact_support_outlined,
          ),
        ]);
        break;

      default:
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
                'Sử dụng các công cụ tự động hóa thông qua QR login hoặc giả lập có rủi ro bị khóa tài khoản theo Chính sách Zalo. Alpha CRM khuyến khích chia nhỏ chiến dịch để chạy an toàn.',
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
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final hasWarning = activeWarning != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final textMuted = isDark ? Colors.white70 : AppColors.textMuted;
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
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m,
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
                    _getDialogTitle(actionType),
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

  String _getDialogTitle(ZaloActionType? actionType) {
    if (actionType == null) return 'QUY TẮC AN TOÀN CHUNG KHI SỬ DỤNG ZALO';
    switch (actionType) {
      case ZaloActionType.bulkMessageByPhone:
        return 'QUY TẮC AN TOÀN GỬI TIN THEO SĐT';
      case ZaloActionType.bulkMessageToGroup:
        return 'QUY TẮC AN TOÀN GỬI TIN VÀO NHÓM';
      case ZaloActionType.bulkMessageToFriends:
        return 'QUY TẮC AN TOÀN GỬI TIN CHO BẠN BÈ';
      case ZaloActionType.friendByPhone:
        return 'QUY TẮC AN TOÀN KẾT BẠN THEO SĐT';
      case ZaloActionType.friendByGroup:
        return 'QUY TẮC AN TOÀN KẾT BẠN TỪ NHÓM';
      case ZaloActionType.scanGroupMembers:
        return 'QUY TẮC AN TOÀN QUÉT THÀNH VIÊN';
      case ZaloActionType.joinGroups:
        return 'QUY TẮC AN TOÀN THAM GIA NHÓM';
      case ZaloActionType.inviteToGroup:
        return 'QUY TẮC AN TOÀN MỜI VÀO NHÓM';
      case ZaloActionType.createGroups:
        return 'QUY TẮC AN TOÀN TẠO NHÓM';
      case ZaloActionType.liveChatReply:
        return 'QUY TẮC AN TOÀN LIVE CHAT';
      case ZaloActionType.chatbotReply:
        return 'QUY TẮC AN TOÀN CHATBOT TỰ ĐỘNG';
    }
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
        ? Colors.white
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
