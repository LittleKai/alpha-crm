class ScannedMember {
  final String id;
  final String name;
  final String phone;
  final String role; // 'Trưởng nhóm', 'Phó nhóm', 'Thành viên'
  final String status; // 'Đã kết bạn', 'Chưa kết bạn', 'Đang gửi yêu cầu'
  final String avatarUrl;

  const ScannedMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.status,
    this.avatarUrl = '',
  });
}

class SavedScannedGroup {
  final String id;
  final String name;
  final int memberCount;
  final String avatarUrl;

  const SavedScannedGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    this.avatarUrl = '',
  });
}

class ZaloGroup {
  final String id;
  final String name;
  final int memberCount;
  final String role; // 'Trưởng nhóm', 'Phó nhóm', 'Thành viên'
  final String status; // 'Hoạt động', 'Đang bảo trì'
  final String avatarUrl;
  final String? accountId;

  const ZaloGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.role,
    this.status = 'Hoạt động',
    this.avatarUrl = '',
    this.accountId,
  });
}

class FriendRecord {
  final String id;
  final String name;
  final String phone;
  final String avatarUrl;

  const FriendRecord({
    required this.id,
    required this.name,
    required this.phone,
    this.avatarUrl = '',
  });
}

class MockGroups {
  static const List<SavedScannedGroup> savedGroups = [
    SavedScannedGroup(id: 'g1', name: 'Cộng đồng Flutter Việt Nam', memberCount: 1240),
    SavedScannedGroup(id: 'g2', name: 'Hội Khởi nghiệp TPHCM', memberCount: 850),
    SavedScannedGroup(id: 'g3', name: 'Cộng đồng AI Builder', memberCount: 412),
    SavedScannedGroup(id: 'g4', name: 'Chia sẻ kiến thức Marketing', memberCount: 620),
  ];

  static const List<ZaloGroup> myGroups = [
    ZaloGroup(id: 'mg1', name: 'Hội Chủ Doanh Nghiệp Q1', memberCount: 124, role: 'Thành viên'),
    ZaloGroup(id: 'mg2', name: 'Khách hàng VIP 2026', memberCount: 56, role: 'Trưởng nhóm'),
    ZaloGroup(id: 'mg3', name: 'Nhóm Hỗ Trợ Kỹ Thuật Alpha', memberCount: 312, role: 'Phó nhóm'),
    ZaloGroup(id: 'mg4', name: 'Cộng Tác Viên Alpha Studio', memberCount: 85, role: 'Trưởng nhóm'),
    ZaloGroup(id: 'mg5', name: 'Giao lưu bóng đá CRM', memberCount: 22, role: 'Thành viên'),
  ];

  static const List<FriendRecord> sampleFriends = [
    FriendRecord(id: 'f1', name: 'Lê Hoàng Minh', phone: '0901112222'),
    FriendRecord(id: 'f2', name: 'Nguyễn Thị Hồng', phone: '0903334444'),
    FriendRecord(id: 'f3', name: 'Trần Minh Hải', phone: '0905556666'),
    FriendRecord(id: 'f4', name: 'Phạm Thanh Sơn', phone: '0907778888'),
    FriendRecord(id: 'f5', name: 'Vũ Ngọc Anh', phone: '0909990000'),
    FriendRecord(id: 'f6', name: 'Đỗ Tiến Đạt', phone: '0912223333'),
    FriendRecord(id: 'f7', name: 'Hoàng Kim Liên', phone: '0914445555'),
    FriendRecord(id: 'f8', name: 'Bùi Thế Vinh', phone: '0916667777'),
    FriendRecord(id: 'f9', name: 'Ngô Thu Thủy', phone: '0918889999'),
    FriendRecord(id: 'f10', name: 'Đặng Quốc Khánh', phone: '0921112222'),
  ];

  static const List<ScannedMember> flutterGroupMembers = [
    ScannedMember(id: 'sm1', name: 'Phạm Minh Đức', phone: '0981112222', role: 'Trưởng nhóm', status: 'Đã kết bạn'),
    ScannedMember(id: 'sm2', name: 'Trần Thanh Hằng', phone: '0982223333', role: 'Phó nhóm', status: 'Chưa kết bạn'),
    ScannedMember(id: 'sm3', name: 'Nguyễn Duy Mạnh', phone: '0983334444', role: 'Thành viên', status: 'Đang gửi yêu cầu'),
    ScannedMember(id: 'sm4', name: 'Lê Việt Anh', phone: '0984445555', role: 'Thành viên', status: 'Chưa kết bạn'),
    ScannedMember(id: 'sm5', name: 'Hoàng Quốc Việt', phone: '0985556666', role: 'Thành viên', status: 'Đã kết bạn'),
    ScannedMember(id: 'sm6', name: 'Vũ Thị Lan', phone: '0986667777', role: 'Thành viên', status: 'Chưa kết bạn'),
  ];

  static const List<ScannedMember> startupGroupMembers = [
    ScannedMember(id: 'sm7', name: 'Nguyễn Lâm Tới', phone: '0902223333', role: 'Trưởng nhóm', status: 'Đã kết bạn'),
    ScannedMember(id: 'sm8', name: 'Đặng Lê Nguyên', phone: '0904445555', role: 'Thành viên', status: 'Chưa kết bạn'),
    ScannedMember(id: 'sm9', name: 'Phan Văn Trị', phone: '0906667777', role: 'Thành viên', status: 'Đã kết bạn'),
  ];
}
