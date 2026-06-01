import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../mock/mock_contacts.dart';
import '../../../shared/api/crm_cloud_api.dart';
import '../../auth/providers/crm_auth_provider.dart';

extension ContactJson on Contact {
  static Contact fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      group: json['company']?.toString() ?? 'Mặc định',
      tag: json['notes']?.toString() ?? 'Tất cả',
      source: 'Cloud DB',
      status: _mapStatusToVietnamese(json['status']?.toString() ?? 'lead'),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
    );
  }

  static String _mapStatusToVietnamese(String dbStatus) {
    switch (dbStatus) {
      case 'lead':
        return 'Chưa gửi';
      case 'contact':
        return 'Đã gửi';
      case 'inactive':
        return 'Thất bại';
      case 'customer':
      default:
        return 'Thành công';
    }
  }
}

class CustomersState {
  final List<Contact> contacts;
  final Set<String> selectedIds;
  final String searchQuery;
  final String selectedGroup; // 'Tất cả' or specific group
  final String selectedTag; // 'Tất cả' or specific tag
  final String selectedStatus; // 'Tất cả' or specific status
  final bool isLoading;
  final String? errorMessage;

  const CustomersState({
    required this.contacts,
    required this.selectedIds,
    required this.searchQuery,
    required this.selectedGroup,
    required this.selectedTag,
    required this.selectedStatus,
    required this.isLoading,
    this.errorMessage,
  });

  factory CustomersState.initial() {
    return const CustomersState(
      contacts: [],
      selectedIds: {},
      searchQuery: '',
      selectedGroup: 'Tất cả',
      selectedTag: 'Tất cả',
      selectedStatus: 'Tất cả',
      isLoading: false,
      errorMessage: null,
    );
  }

  CustomersState copyWith({
    List<Contact>? contacts,
    Set<String>? selectedIds,
    String? searchQuery,
    String? selectedGroup,
    String? selectedTag,
    String? selectedStatus,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CustomersState(
      contacts: contacts ?? this.contacts,
      selectedIds: selectedIds ?? this.selectedIds,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      selectedTag: selectedTag ?? this.selectedTag,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CustomersNotifier extends StateNotifier<CustomersState> {
  final Ref _ref;
  CustomersNotifier(this._ref) : super(CustomersState.initial()) {
    loadContacts();
  }

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final response = await CrmCloudApi.get('/crm/customers');
    
    if (response['success'] == true && response['data'] != null) {
      final List<dynamic> raw = response['data'];
      final List<Contact> loaded = raw.map((json) => ContactJson.fromJson(json)).toList();
      state = state.copyWith(contacts: loaded, isLoading: false);
    } else {
      if (kDebugMode) {
        state = state.copyWith(
          contacts: MockContacts.sampleContacts,
          isLoading: false,
          errorMessage: 'Lỗi tải đám mây (Dữ liệu mẫu chế độ phát triển): ${response['message']}',
        );
      } else {
        state = state.copyWith(
          contacts: const [],
          isLoading: false,
          errorMessage: response['message'] ?? 'Không thể tải dữ liệu khách hàng từ đám mây.',
        );
      }
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedGroup(String group) {
    state = state.copyWith(selectedGroup: group);
  }

  void setSelectedTag(String tag) {
    state = state.copyWith(selectedTag: tag);
  }

  void setSelectedStatus(String status) {
    state = state.copyWith(selectedStatus: status);
  }

  void toggleContactSelection(String id) {
    final newSelected = Set<String>.from(state.selectedIds);
    if (newSelected.contains(id)) {
      newSelected.remove(id);
    } else {
      newSelected.add(id);
    }
    state = state.copyWith(selectedIds: newSelected);
  }

  void toggleAllSelection(List<Contact> visibleContacts) {
    final newSelected = Set<String>.from(state.selectedIds);
    final visibleIds = visibleContacts.map((c) => c.id).toSet();

    // Check if all visible are currently selected
    final allVisibleSelected = visibleIds.every(
      (id) => newSelected.contains(id),
    );

    if (allVisibleSelected) {
      // Unselect all visible
      newSelected.removeAll(visibleIds);
    } else {
      // Select all visible
      newSelected.addAll(visibleIds);
    }
    state = state.copyWith(selectedIds: newSelected);
  }

  Future<bool> addContact(Contact contact) async {
    final auth = _ref.read(crmAuthProvider);
    if (auth.subscriptionStatus == 'expired') {
      state = state.copyWith(
        errorMessage: 'Gói dịch vụ đã hết hạn. Hệ thống đang hoạt động ở chế độ Đọc-Chỉ-Xem (Read-Only).',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    final response = await CrmCloudApi.post('/crm/customers', {
      'name': contact.name,
      'phone': contact.phone,
      'company': contact.group,
      'notes': contact.tag,
      'status': 'lead',
    });

    if (response['success'] == true && response['data'] != null) {
      final newContact = ContactJson.fromJson(response['data']);
      state = state.copyWith(
        contacts: [newContact, ...state.contacts],
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: response['message'] ?? 'Thêm khách hàng vào cơ sở dữ liệu đám mây thất bại.',
      );
      return false;
    }
  }

  Future<void> importContacts(List<Contact> newContacts) async {
    final auth = _ref.read(crmAuthProvider);
    if (auth.subscriptionStatus == 'expired') {
      state = state.copyWith(
        errorMessage: 'Gói dịch vụ đã hết hạn. Hệ thống đang hoạt động ở chế độ Đọc-Chỉ-Xem (Read-Only).',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    bool allSuccess = true;
    final List<Contact> imported = [];

    for (final contact in newContacts) {
      final response = await CrmCloudApi.post('/crm/customers', {
        'name': contact.name,
        'phone': contact.phone,
        'company': contact.group,
        'notes': contact.tag,
        'status': 'lead',
      });
      if (response['success'] == true && response['data'] != null) {
        imported.add(ContactJson.fromJson(response['data']));
      } else {
        allSuccess = false;
      }
    }

    state = state.copyWith(
      contacts: [...imported, ...state.contacts],
      isLoading: false,
      errorMessage: allSuccess ? null : 'Một số khách hàng import thất bại.',
    );
  }

  void clearContacts() {
    state = state.copyWith(contacts: [], selectedIds: {});
  }

  Future<bool> deleteSelected() async {
    final auth = _ref.read(crmAuthProvider);
    if (auth.subscriptionStatus == 'expired') {
      state = state.copyWith(
        errorMessage: 'Gói dịch vụ đã hết hạn. Hệ thống đang hoạt động ở chế độ Đọc-Chỉ-Xem (Read-Only).',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    bool allSuccess = true;
    final idsToDelete = List<String>.from(state.selectedIds);
    
    for (final id in idsToDelete) {
      final response = await CrmCloudApi.delete('/crm/customers/$id');
      if (response['success'] != true) {
        allSuccess = false;
      }
    }

    if (allSuccess) {
      final remainingContacts = state.contacts
          .where((c) => !state.selectedIds.contains(c.id))
          .toList();
      state = state.copyWith(contacts: remainingContacts, selectedIds: {}, isLoading: false);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Xóa danh sách khách hàng thất bại.',
      );
      return false;
    }
  }

  void triggerError() {
    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Kết nối cơ sở dữ liệu thất bại.',
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final customersProvider =
    StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
      return CustomersNotifier(ref);
    });
