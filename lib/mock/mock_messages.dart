class MessageTemplate {
  final String id;
  final String title;
  final String content;
  final List<String> variables;
  final DateTime createdAt;

  const MessageTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.variables,
    required this.createdAt,
  });

  MessageTemplate copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? variables,
    DateTime? createdAt,
  }) {
    return MessageTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      variables: variables ?? this.variables,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MockMessages {
  static final List<MessageTemplate> sampleTemplates = [
    MessageTemplate(
      id: '1',
      title: 'Chào mừng khách hàng mới',
      content:
          'Chào {ho_ten}, cảm ơn bạn đã quan tâm đến dịch vụ của chúng tôi. Hãy cho tôi biết nếu bạn có bất kỳ câu hỏi nào nhé! Chúc bạn một ngày {buoi_trong_ngay} vui vẻ.',
      variables: ['ho_ten', 'buoi_trong_ngay'],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    MessageTemplate(
      id: '2',
      title: 'Thông báo chương trình khuyến mãi',
      content:
          'Tin sốt dẻo! {ho_ten} ơi, chúng tôi đang có chương trình giảm giá {phan_tram_giam}% chỉ dành riêng cho bạn trong tuần này. Xem ngay tại {link_web} nhé.',
      variables: ['ho_ten', 'phan_tram_giam', 'link_web'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    MessageTemplate(
      id: '3',
      title: 'Xác nhận lịch hẹn tư vấn',
      content:
          'Xin chào {ho_ten}, lịch hẹn tư vấn của bạn vào lúc {gio_hen} ngày {ngay_hen} đã được xác nhận. Chúng tôi sẽ liên hệ lại với bạn. Xin cảm ơn!',
      variables: ['ho_ten', 'gio_hen', 'ngay_hen'],
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    MessageTemplate(
      id: '4',
      title: 'Lời chúc sinh nhật khách hàng',
      content:
          'Chúc mừng sinh nhật {ho_ten}! Kính chúc quý khách tuổi mới tràn đầy niềm vui, hạnh phúc và thành công. Để tri ân khách hàng, chúng tôi xin gửi tặng mã giảm giá đặc biệt {ma_giam}.',
      variables: ['ho_ten', 'ma_giam'],
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
  ];
}
