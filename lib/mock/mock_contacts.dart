class Contact {
  final String id;
  final String name;
  final String phone;
  final String group;
  final String tag;
  final String source;
  final String status; // 'Chưa gửi', 'Đã gửi', 'Thất bại', 'Thành công'
  final DateTime createdAt;

  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.group,
    required this.tag,
    required this.source,
    required this.status,
    required this.createdAt,
  });

  Contact copyWith({
    String? id,
    String? name,
    String? phone,
    String? group,
    String? tag,
    String? source,
    String? status,
    DateTime? createdAt,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      group: group ?? this.group,
      tag: tag ?? this.tag,
      source: source ?? this.source,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MockContacts {
  static final List<Contact> sampleContacts = [
    Contact(
      id: '1',
      name: 'Nguyễn Văn A',
      phone: '0987654321',
      group: 'Khách hàng VIP',
      tag: 'Bất động sản',
      source: 'Import File',
      status: 'Thành công',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Contact(
      id: '2',
      name: 'Trần Thị B',
      phone: '0912345678',
      group: 'Khách hàng tiềm năng',
      tag: 'Tài chính',
      source: 'Quét nhóm',
      status: 'Đã gửi',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Contact(
      id: '3',
      name: 'Lê Văn C',
      phone: '0909090909',
      group: 'Khách hàng VIP',
      tag: 'Công nghệ',
      source: 'Import File',
      status: 'Thất bại',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Contact(
      id: '4',
      name: 'Phạm Thị D',
      phone: '0933333333',
      group: 'Đối tác',
      tag: 'Giáo dục',
      source: 'Thêm thủ công',
      status: 'Chưa gửi',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Contact(
      id: '5',
      name: 'Hoàng Văn E',
      phone: '0944444444',
      group: 'Khách hàng tiềm năng',
      tag: 'Bất động sản',
      source: 'Import File',
      status: 'Thành công',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Contact(
      id: '6',
      name: 'Vũ Thị F',
      phone: '0955555555',
      group: 'Khách hàng VIP',
      tag: 'Thời trang',
      source: 'Quét nhóm',
      status: 'Chưa gửi',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    Contact(
      id: '7',
      name: 'Đặng Văn G',
      phone: '0966666666',
      group: 'Đối tác',
      tag: 'Tài chính',
      source: 'Thêm thủ công',
      status: 'Đã gửi',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    Contact(
      id: '8',
      name: 'Bùi Thị H',
      phone: '0977777777',
      group: 'Khách hàng tiềm năng',
      tag: 'Công nghệ',
      source: 'Import File',
      status: 'Thành công',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  static const Map<String, String> stats = {
    'total': '1,248',
    'newThisWeek': '+124',
    'interacted': '856',
    'accountsConnected': '5',
  };
}
