import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../mock/mock_groups.dart';

class ScanMembersState {
  final List<ScannedMember> members;
  final String? selectedGroupId;
  final bool isScanning;
  final String? errorText;

  const ScanMembersState({
    required this.members,
    this.selectedGroupId,
    this.isScanning = false,
    this.errorText,
  });

  ScanMembersState copyWith({
    List<ScannedMember>? members,
    String? selectedGroupId,
    bool? isScanning,
    String? errorText,
  }) {
    return ScanMembersState(
      members: members ?? this.members,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      isScanning: isScanning ?? this.isScanning,
      errorText: errorText,
    );
  }
}

class ScanMembersNotifier extends StateNotifier<ScanMembersState> {
  ScanMembersNotifier() : super(const ScanMembersState(members: []));

  void selectSavedGroup(String? groupId) {
    if (groupId == null || groupId == 'none') {
      state = state.copyWith(members: [], selectedGroupId: null);
      return;
    }

    state = state.copyWith(isScanning: true, selectedGroupId: groupId);
    // Simulate loading/scanning saved group
    Future.delayed(const Duration(milliseconds: 500), () {
      List<ScannedMember> loadedMembers = [];
      if (groupId == 'g1') {
        loadedMembers = MockGroups.flutterGroupMembers;
      } else if (groupId == 'g2') {
        loadedMembers = MockGroups.startupGroupMembers;
      } else {
        loadedMembers = [
          const ScannedMember(
            id: 'sm_gen1',
            name: 'Nguyễn Văn Hải',
            phone: '0901112222',
            role: 'Thành viên',
            status: 'Chưa kết bạn',
          ),
          const ScannedMember(
            id: 'sm_gen2',
            name: 'Trần Thị Mai',
            phone: '0903334444',
            role: 'Thành viên',
            status: 'Đã kết bạn',
          ),
        ];
      }
      state = state.copyWith(members: loadedMembers, isScanning: false);
    });
  }

  void scanGroupLink(String url) {
    if (url.trim().isEmpty || !url.contains('zalo.me/g/')) {
      state = state.copyWith(
        errorText:
            'Link nhóm Zalo không hợp lệ. Định dạng yêu cầu: zalo.me/g/xxxxxx',
      );
      return;
    }

    state = state.copyWith(
      isScanning: true,
      errorText: null,
      selectedGroupId: null,
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      state = state.copyWith(
        members: MockGroups.flutterGroupMembers,
        isScanning: false,
      );
    });
  }

  void clearResults() {
    state = const ScanMembersState(members: []);
  }

  void clearError() {
    state = state.copyWith(errorText: null);
  }
}

final scanMembersProvider =
    StateNotifierProvider<ScanMembersNotifier, ScanMembersState>((ref) {
      return ScanMembersNotifier();
    });
