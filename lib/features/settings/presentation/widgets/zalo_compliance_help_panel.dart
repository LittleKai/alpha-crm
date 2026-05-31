import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_card.dart';

class ZaloComplianceHelpPanel extends StatelessWidget {
  const ZaloComplianceHelpPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Hướng dẫn tuân thủ Zalo',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const AppAlert(
            title: 'Delay và batch KHÔNG đủ để đảm bảo an toàn',
            message:
                'Giãn cách thời gian và giới hạn batch chỉ giảm rủi ro về tần suất. '
                'Chúng không biến việc tiếp cận tự động thành hành vi tuân thủ. '
                'Bạn vẫn cần đảm bảo đồng ý (consent) và tương tác gần đây từ người nhận.',
            variant: AppAlertVariant.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppAlert(
            title: 'Consent và tương tác gần đây là kiểm soát mạnh hơn',
            message:
                'Yêu cầu bằng chứng đồng ý (consent proof) và xác nhận người nhận '
                'đã tương tác gần đây với OA/Bot là biện pháp bảo vệ hiệu quả nhất. '
                'Đây là yêu cầu bắt buộc từ chính sách gửi tin OA Zalo.',
            variant: AppAlertVariant.info,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppAlert(
            title: 'Official OA/Bot API là ranh giới tích hợp được hỗ trợ',
            message:
                'Alpha CRM chỉ hỗ trợ tích hợp qua Official Account hoặc Bot API. '
                'Tự động hóa tài khoản cá nhân (QR login, emulator) có nguy cơ bị '
                'khóa tài khoản vĩnh viễn theo Chính sách Cộng đồng Zalo.',
            variant: AppAlertVariant.info,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppAlert(
            title: 'Proxy và đa tài khoản bị vô hiệu trong chế độ official',
            message:
                'Sử dụng proxy hoặc xoay vòng nhiều tài khoản cá nhân có thể bị '
                'Zalo nhận diện là hành vi né tránh và dẫn đến hạn chế tài khoản. '
                'Các tùy chọn này bị tắt khi chế độ Official API được bật.',
            variant: AppAlertVariant.error,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppAlert(
            title: 'Kết bạn và nhóm tự động nên giữ ở chế độ thử nghiệm',
            message:
                'Gửi lời mời kết bạn hàng loạt, tham gia/mời/tạo nhóm tự động '
                'là các hành vi rủi ro cao. Nên giữ ở chế độ test-only trừ khi '
                'được thiết kế lại với consent rõ ràng và official APIs.',
            variant: AppAlertVariant.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppAlert(
            title: 'Điều kiện dừng tự động',
            message:
                'Hệ thống tự động dừng khi phát hiện: báo cáo từ người nhận, '
                'tỷ lệ lỗi vượt ngưỡng, tín hiệu opt-out/block, hoặc lỗi bất thường. '
                'Cấu hình các ngưỡng này trong phần Kiểm soát rủi ro.',
            variant: AppAlertVariant.success,
          ),
        ],
      ),
    );
  }
}
