import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../mock/mock_groups.dart';
import '../../../shared/utils/image_helper.dart';
import '../../../shared/utils/zalo_compliance_guard.dart';
import '../../settings/providers/settings_provider.dart';
import '../../zalo_integration/data/zalo_integration_api.dart';
import '../../zalo_integration/providers/zalo_integration_provider.dart';

class ScanMembersState {
  final List<ScannedMember> members;
  final String? selectedGroupId;
  final String? scannedGroupName;
  final int? scannedTotalMember;
  final bool isScanning;
  final String? errorText;
  final String? complianceError;

  final List<SavedScannedGroup> savedGroups;

  const ScanMembersState({
    required this.members,
    this.selectedGroupId,
    this.scannedGroupName,
    this.scannedTotalMember,
    this.isScanning = false,
    this.errorText,
    this.complianceError,
    this.savedGroups = const [],
  });

  ScanMembersState copyWith({
    List<ScannedMember>? members,
    String? selectedGroupId,
    String? scannedGroupName,
    int? scannedTotalMember,
    bool? isScanning,
    String? errorText,
    String? complianceError,
    List<SavedScannedGroup>? savedGroups,
  }) {
    return ScanMembersState(
      members: members ?? this.members,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      scannedGroupName: scannedGroupName ?? this.scannedGroupName,
      scannedTotalMember: scannedTotalMember ?? this.scannedTotalMember,
      isScanning: isScanning ?? this.isScanning,
      errorText: errorText,
      complianceError: complianceError,
      savedGroups: savedGroups ?? this.savedGroups,
    );
  }
}

class ScanMembersNotifier extends StateNotifier<ScanMembersState> {
  final Ref _ref;

  ScanMembersNotifier(this._ref)
    : super(const ScanMembersState(members: [], savedGroups: []));

  void removeSavedGroup(String id) {
    final newList = state.savedGroups.where((g) => g.id != id).toList();
    if (state.selectedGroupId == id) {
      state = state.copyWith(
        savedGroups: newList,
        selectedGroupId: null,
        members: [],
        scannedGroupName: null,
        scannedTotalMember: null,
      );
    } else {
      state = state.copyWith(savedGroups: newList);
    }
  }

  ZaloIntegrationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    return ZaloIntegrationApi(baseUrl: baseUrl);
  }

  bool get _isConnected => _ref.read(zaloIntegrationProvider).isConnected;

  ComplianceDecision _checkCompliance() {
    final settings = _ref.read(settingsProvider).settings;
    return ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.scanGroupMembers,
      targetCount: 1,
    );
  }

  List<ScannedMember> _parseMembers(List<dynamic> rawMembers) {
    return rawMembers.map((m) {
      final role = m['role'] as String? ?? 'member';
      String roleLabel;
      switch (role) {
        case 'owner':
          roleLabel = 'Trưởng nhóm';
          break;
        case 'admin':
          roleLabel = 'Phó nhóm';
          break;
        default:
          roleLabel = 'Thành viên';
      }
      return ScannedMember(
        id: m['id']?.toString() ?? '',
        name: m['displayName']?.toString() ?? m['zaloName']?.toString() ?? '',
        phone: '',
        role: roleLabel,
        status: 'Chưa xác định',
        avatarUrl: sanitizeImageUrl(m['avatar']?.toString() ?? ''),
      );
    }).toList();
  }

  Future<void> selectSavedGroup(String? groupId) async {
    if (groupId == null || groupId == 'none') {
      state = state.copyWith(
        members: [],
        selectedGroupId: null,
        scannedGroupName: null,
        scannedTotalMember: null,
      );
      return;
    }

    final decision = _checkCompliance();
    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
      );
      return;
    }

    state = state.copyWith(
      isScanning: true,
      selectedGroupId: groupId,
      complianceError: null,
      scannedGroupName: null,
      scannedTotalMember: null,
    );

    if (_isConnected) {
      try {
        final api = _getApi();
        var response = await api.fetchGroupMembers(groupId: groupId);
        if (response['success'] != true) {
          response = await api.fetchGroupLinkMembers(
            link: 'https://zalo.me/g/$groupId',
          );
        }
        if (response['success'] == true && response['members'] != null) {
          final members = _parseMembers(response['members'] as List<dynamic>);
          state = state.copyWith(
            members: members,
            isScanning: false,
            scannedGroupName:
                response['groupName']?.toString() ??
                state.savedGroups.firstWhere((g) => g.id == groupId).name,
            scannedTotalMember:
                response['totalMember'] as int? ?? members.length,
          );
          return;
        }
      } catch (_) {
        // Fall through to mock
      }
    }

    state = state.copyWith(
      members: const [],
      isScanning: false,
      errorText: 'Không tải được thành viên nhóm hoặc Zalo backend chưa kết nối.',
    );
  }

  Future<void> scanGroupLink(String url) async {
    if (url.trim().isEmpty || !url.contains('zalo.me/g/')) {
      state = state.copyWith(
        errorText:
            'Link nhóm Zalo không hợp lệ. Định dạng yêu cầu: zalo.me/g/xxxxxx',
      );
      return;
    }

    final decision = _checkCompliance();
    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
      );
      return;
    }

    state = state.copyWith(
      isScanning: true,
      errorText: null,
      selectedGroupId: null,
      complianceError: null,
      scannedGroupName: null,
      scannedTotalMember: null,
    );

    if (_isConnected) {
      try {
        final api = _getApi();
        final response = await api.fetchGroupLinkMembers(link: url.trim());
        if (response['success'] == true && response['members'] != null) {
          final members = _parseMembers(response['members'] as List<dynamic>);
          final groupName =
              response['groupName']?.toString() ?? 'Nhóm quét bằng link';
          final totalMember = response['totalMember'] as int? ?? members.length;
          final avatarUrl = sanitizeImageUrl(
            response['avatar']?.toString() ??
                response['groupAvatar']?.toString() ??
                '',
          );

          String groupId = 'link_${DateTime.now().millisecondsSinceEpoch}';
          final regex = RegExp(r'zalo\.me/g/([a-zA-Z0-9_-]+)');
          final match = regex.firstMatch(url);
          if (match != null && match.groupCount >= 1) {
            groupId = match.group(1)!;
          }

          List<SavedScannedGroup> updatedSaved = List.from(state.savedGroups);
          if (!updatedSaved.any((g) => g.id == groupId)) {
            updatedSaved.insert(
              0,
              SavedScannedGroup(
                id: groupId,
                name: groupName,
                memberCount: totalMember,
                avatarUrl: avatarUrl,
              ),
            );
          }

          state = state.copyWith(
            members: members,
            isScanning: false,
            scannedGroupName: groupName,
            scannedTotalMember: totalMember,
            selectedGroupId: groupId,
            savedGroups: updatedSaved,
          );
          return;
        }
      } catch (_) {
        // Fall through to mock
      }
    }

    state = state.copyWith(
      members: const [],
      isScanning: false,
      errorText: 'Quét nhóm thất bại hoặc Zalo backend chưa kết nối.',
    );
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
      return ScanMembersNotifier(ref);
    });
