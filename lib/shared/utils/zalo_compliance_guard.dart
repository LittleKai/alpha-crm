import '../../mock/mock_accounts.dart';

enum ZaloActionType {
  bulkMessageByPhone,
  bulkMessageToGroup,
  bulkMessageToFriends,
  friendByPhone,
  friendByGroup,
  scanGroupMembers,
  joinGroups,
  inviteToGroup,
  createGroups,
  liveChatReply,
  chatbotReply,
}

enum ZaloRiskLevel { low, medium, high, critical }

class ComplianceDecision {
  final bool allowed;
  final ZaloRiskLevel riskLevel;
  final String title;
  final String message;
  final List<String> requiredActions;

  const ComplianceDecision({
    required this.allowed,
    required this.riskLevel,
    required this.title,
    required this.message,
    this.requiredActions = const [],
  });
}

class ZaloComplianceGuard {
  static ComplianceDecision evaluateZaloAction({
    required SystemSettings settings,
    required ZaloActionType actionType,
    required int targetCount,
    bool hasConsentProof = false,
    bool hasRecentInteraction = false,
    bool isOfficialChannel = false,
    bool isTestMode = false,
  }) {
    // Live chat and chatbot replies are generally safe in any channel mode
    if (actionType == ZaloActionType.liveChatReply ||
        actionType == ZaloActionType.chatbotReply) {
      if (hasRecentInteraction || !settings.requireRecentInteraction) {
        return const ComplianceDecision(
          allowed: true,
          riskLevel: ZaloRiskLevel.low,
          title: 'Hành động an toàn',
          message: 'Trả lời tin nhắn từ người dùng đã tương tác.',
        );
      }
      return const ComplianceDecision(
        allowed: false,
        riskLevel: ZaloRiskLevel.medium,
        title: 'Cần tương tác gần đây',
        message:
            'Người nhận chưa có tương tác gần đây. Bật tương tác gần đây hoặc tắt yêu cầu trong Cài đặt.',
        requiredActions: ['Xác nhận tương tác gần đây từ người nhận'],
      );
    }

    final personalActions = {
      ZaloActionType.friendByPhone,
      ZaloActionType.friendByGroup,
      ZaloActionType.scanGroupMembers,
      ZaloActionType.joinGroups,
      ZaloActionType.inviteToGroup,
      ZaloActionType.createGroups,
    };

    // Channel-mode-aware evaluation
    switch (settings.zaloChannelMode) {
      case ZaloChannelMode.officialOa:
        // Official mode: block personal-account actions unless test mode
        if (personalActions.contains(actionType)) {
          if (!isTestMode || !settings.allowTestModeOnlyForRiskyActions) {
            return const ComplianceDecision(
              allowed: false,
              riskLevel: ZaloRiskLevel.critical,
              title: 'Hành động bị chặn — Chế độ Official OA',
              message:
                  'Hành động này yêu cầu tài khoản cá nhân và không khả dụng khi '
                  'chế độ Official OA đang bật. Chuyển sang Personal Zalo hoặc Mock.',
              requiredActions: [
                'Chuyển channel sang Personal Zalo (zca-js)',
                'Hoặc bật chế độ thử nghiệm',
              ],
            );
          }
        }
        break;

      case ZaloChannelMode.personalZca:
        // Personal mode: allow with risk controls
        if (personalActions.contains(actionType)) {
          if (!settings.allowPersonalAccountAutomation) {
            return const ComplianceDecision(
              allowed: false,
              riskLevel: ZaloRiskLevel.critical,
              title: 'Tự động hóa cá nhân bị tắt',
              message:
                  'Bật "Cho phép tự động hóa tài khoản cá nhân" trong '
                  'Settings → Kiểm soát rủi ro để sử dụng tính năng này.',
              requiredActions: [
                'Bật tự động hóa tài khoản cá nhân trong Cài đặt',
              ],
            );
          }
        }
        break;

    }

    // Block group/friend automation unless allow flag
    if (actionType == ZaloActionType.friendByPhone ||
        actionType == ZaloActionType.friendByGroup) {
      if (!settings.allowFriendAutomation) {
        return const ComplianceDecision(
          allowed: false,
          riskLevel: ZaloRiskLevel.critical,
          title: 'Tự động kết bạn bị chặn',
          message:
              'Gửi lời mời kết bạn hàng loạt là hành vi rủi ro cao theo chính sách '
              'Zalo. Cần bật rõ ràng và có duyệt thủ công.',
          requiredActions: [
            'Bật tự động kết bạn trong Cài đặt',
            'Duyệt thủ công trước khi gửi',
          ],
        );
      }
    }

    if (actionType == ZaloActionType.joinGroups ||
        actionType == ZaloActionType.inviteToGroup ||
        actionType == ZaloActionType.createGroups) {
      if (!settings.allowGroupAutomation) {
        return const ComplianceDecision(
          allowed: false,
          riskLevel: ZaloRiskLevel.critical,
          title: 'Tự động nhóm bị chặn',
          message:
              'Tham gia/mời/tạo nhóm tự động là hành vi rủi ro cao. '
              'Zalo có thể khóa tài khoản nếu phát hiện hoạt động bất thường.',
          requiredActions: [
            'Bật tự động nhóm trong Cài đặt',
            'Duyệt thủ công trước khi gửi',
          ],
        );
      }
    }

    final riskyTestActions = {
      ZaloActionType.friendByPhone,
      ZaloActionType.friendByGroup,
      ZaloActionType.scanGroupMembers,
      ZaloActionType.joinGroups,
      ZaloActionType.inviteToGroup,
      ZaloActionType.createGroups,
    };
    if (isTestMode && riskyTestActions.contains(actionType)) {
      return const ComplianceDecision(
        allowed: true,
        riskLevel: ZaloRiskLevel.high,
        title: 'Chế độ thử nghiệm',
        message:
            'Hành động chạy trong chế độ thử nghiệm. Không có thao tác thật '
            'nào được thực hiện trên Zalo.',
      );
    }

    // Block phone-list bulk messaging without consent proof
    if (actionType == ZaloActionType.bulkMessageByPhone) {
      if (settings.requireConsentProof && !hasConsentProof) {
        return const ComplianceDecision(
          allowed: false,
          riskLevel: ZaloRiskLevel.high,
          title: 'Thiếu bằng chứng đồng ý',
          message:
              'Gửi tin nhắn hàng loạt theo SĐT yêu cầu consent proof từ người nhận. '
              'Nhập danh sách từ nguồn có opt-in rõ ràng hoặc tắt yêu cầu consent.',
          requiredActions: ['Cung cấp consent proof cho người nhận'],
        );
      }
    }

    // Block target counts > maxBatchSize without human approval
    if (targetCount > settings.maxBatchSize) {
      if (settings.requireHumanApproval) {
        return ComplianceDecision(
          allowed: false,
          riskLevel: ZaloRiskLevel.high,
          title: 'Vượt ngưỡng batch — Cần duyệt thủ công',
          message:
              'Số lượng mục tiêu ($targetCount) vượt quá batch tối đa '
              '(${settings.maxBatchSize}). Giảm số lượng hoặc phê duyệt thủ công.',
          requiredActions: [
            'Giảm số lượng xuống ${settings.maxBatchSize}',
            'Hoặc duyệt thủ công trước khi gửi',
          ],
        );
      }
    }

    // Warn for delay-only mitigation on bulk sends
    if (actionType == ZaloActionType.bulkMessageToGroup ||
        actionType == ZaloActionType.bulkMessageToFriends) {
      if (!hasConsentProof && settings.requireConsentProof) {
        return const ComplianceDecision(
          allowed: false,
          riskLevel: ZaloRiskLevel.medium,
          title: 'Cảnh báo — Chưa có consent',
          message:
              'Gửi tin nhắn hàng loạt mà không có consent chỉ dựa vào delay/batch '
              'để giảm rủi ro tần suất. Consent và tương tác gần đây là kiểm soát mạnh hơn.',
          requiredActions: ['Cung cấp consent proof'],
        );
      }
    }

    // Default: allowed
    return const ComplianceDecision(
      allowed: true,
      riskLevel: ZaloRiskLevel.low,
      title: 'Hành động được phép',
      message: 'Hành động tuân thủ các cài đặt kiểm soát rủi ro hiện tại.',
    );
  }
}
