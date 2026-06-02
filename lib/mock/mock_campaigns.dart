import 'package:flutter/material.dart';

class CampaignPerformanceData {
  final double success;
  final double failure;
  final String dateLabel;

  const CampaignPerformanceData({
    required this.success,
    required this.failure,
    required this.dateLabel,
  });
}

class QuickActionItem {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final String route;
  final Color titleColor;

  const QuickActionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.route,
    this.titleColor = const Color(0xFF2563EB),
  });
}

class GuideStepItem {
  final String stepNumber;
  final String title;
  final String description;
  final String route;

  const GuideStepItem({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.route,
  });
}

class MockCampaigns {
  static const List<String> zeroChart7Days = [
    '24/5',
    '25/5',
    '26/5',
    '27/5',
    '28/5',
    '29/5',
    '30/5',
  ];

  static const List<String> zeroChart30Days = [
    'Tuần 1',
    'Tuần 2',
    'Tuần 3',
    'Tuần 4',
  ];

  static const Map<String, String> stats = {
    'totalMessages': '0',
    'successRate': '0%',
    'failedCount': '0',
    'activeCampaigns': '0',
  };

  static const List<CampaignPerformanceData> chartData7DaysMessages = [
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: '24/5'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: '25/5'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: '26/5'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: '27/5'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: '28/5'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: '29/5'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: '30/5'),
  ];

  static const List<CampaignPerformanceData> chartData7DaysFriends =
      chartData7DaysMessages;
  static const List<CampaignPerformanceData> chartData7DaysResponses =
      chartData7DaysMessages;

  static const List<CampaignPerformanceData> chartData30DaysMessages = [
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: 'Tuần 1'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: 'Tuần 2'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: 'Tuần 3'),
    CampaignPerformanceData(success: 0, failure: 0, dateLabel: 'Tuần 4'),
  ];

  static const List<CampaignPerformanceData> chartData30DaysFriends =
      chartData30DaysMessages;
  static const List<CampaignPerformanceData> chartData30DaysResponses =
      chartData30DaysMessages;

  static const List<QuickActionItem> quickActions = [
    QuickActionItem(
      title: 'Gửi tin nhắn hàng loạt',
      description: 'Soạn tin và gửi đến nhiều khách hàng cùng lúc',
      icon: Icons.send_rounded,
      gradient: [Color(0xFFFFFFFF), Color(0xFFEAF1FF)],
      route: '/messaging/bulk',
    ),
    QuickActionItem(
      title: 'Quản lý danh bạ',
      description: 'Import và quản lý danh sách liên hệ khách hàng',
      icon: Icons.group_outlined,
      gradient: [Color(0xFFFFFFFF), Color(0xFFFFF7ED)],
      route: '/customers',
    ),
    QuickActionItem(
      title: 'Chatbot tự động',
      description: 'Tạo kịch bản trả lời tự động theo từ khóa tin nhắn',
      icon: Icons.smart_toy_outlined,
      gradient: [Color(0xFFFFFFFF), Color(0xFFEFFDF7)],
      route: '/messaging/chatbot',
      titleColor: Color(0xFF10B981),
    ),
  ];

  static const List<GuideStepItem> guideSteps = [
    GuideStepItem(
      stepNumber: '1',
      title: 'Kết nối tài khoản Zalo trước',
      description:
          'Vào Cài đặt -> Nhập Proxy nếu có -> Click "Thêm tài khoản Zalo" và quét mã QR trên điện thoại để liên kết.',
      route: '/settings',
    ),
    GuideStepItem(
      stepNumber: '2',
      title: 'Chuẩn bị danh sách khách hàng',
      description:
          'Import file Excel/CSV chứa dữ liệu khách hàng hoặc nhập SĐT thủ công trực tiếp khi tạo chiến dịch gửi tin.',
      route: '/customers',
    ),
    GuideStepItem(
      stepNumber: '3',
      title: 'Thiết lập delay gửi tin hợp lý',
      description:
          'Luôn đặt thời gian delay giãn cách từ 30-60 giây giữa mỗi tin nhắn để giữ tài khoản an toàn, chống spam.',
      route: '/messaging/bulk',
    ),
  ];
}

class ZaloAccount {
  final String id;
  final String name;
  final String phone;
  final String type; // 'Business' or 'Cá nhân'
  final bool isConnected;

  const ZaloAccount({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    this.isConnected = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZaloAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SendHistoryRecord {
  final String id;
  final String campaignName;
  final String phone;
  final String message;
  final String status; // 'Thành công', 'Thất bại', 'Đang chờ'
  final DateTime sentAt;

  const SendHistoryRecord({
    required this.id,
    required this.campaignName,
    required this.phone,
    required this.message,
    required this.status,
    required this.sentAt,
  });

  SendHistoryRecord copyWith({
    String? id,
    String? campaignName,
    String? phone,
    String? message,
    String? status,
    DateTime? sentAt,
  }) {
    return SendHistoryRecord(
      id: id ?? this.id,
      campaignName: campaignName ?? this.campaignName,
      phone: phone ?? this.phone,
      message: message ?? this.message,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}

class MockCampaignsData {
  static const List<ZaloAccount> sampleAccounts = [
    ZaloAccount(id: '1', name: 'Zalo Business - Nguyễn Văn A', phone: '0901234567', type: 'Business'),
    ZaloAccount(id: '2', name: 'Zalo Cá nhân - Trần Thị B', phone: '0911223344', type: 'Cá nhân'),
    ZaloAccount(id: '3', name: 'Zalo Cá nhân - Lê Hoàng C', phone: '0988776655', type: 'Cá nhân', isConnected: false),
  ];

  static final List<SendHistoryRecord> sampleSendHistory = [
    SendHistoryRecord(
      id: '1',
      campaignName: 'CSKH Tháng 5',
      phone: '0987654321',
      message: 'Chào {ho_ten}, chúc bạn một {buoi_trong_ngay} vui vẻ!',
      status: 'Thành công',
      sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    SendHistoryRecord(
      id: '2',
      campaignName: 'Khuyến mãi hè 2026',
      phone: '0901234567',
      message: 'Ưu đãi cực lớn dành cho {ho_ten} trong mùa hè này. Đăng ký ngay!',
      status: 'Thành công',
      sentAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    SendHistoryRecord(
      id: '3',
      campaignName: 'CSKH Tháng 5',
      phone: '0912345678',
      message: 'Chào {ho_ten}, chúc bạn một {buoi_trong_ngay} vui vẻ!',
      status: 'Thất bại',
      sentAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    SendHistoryRecord(
      id: '4',
      campaignName: 'Giới thiệu sản phẩm mới',
      phone: '0933445566',
      message: 'Chào {ho_ten}, chúng tôi ra mắt sản phẩm mới siêu đột phá.',
      status: 'Đang chờ',
      sentAt: DateTime.now().add(const Duration(minutes: 10)),
    ),
    SendHistoryRecord(
      id: '5',
      campaignName: 'Khuyến mãi hè 2026',
      phone: '0977889900',
      message: 'Ưu đãi cực lớn dành cho {ho_ten} trong mùa hè này. Đăng ký ngay!',
      status: 'Thành công',
      sentAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

