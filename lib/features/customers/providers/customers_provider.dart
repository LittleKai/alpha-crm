import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../mock/mock_contacts.dart';
import '../../../shared/models/crm_customer.dart';
import '../data/customers_repository.dart';
import '../data/segments_repository.dart';
import '../../auth/providers/crm_auth_provider.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository();
});

final segmentsRepositoryProvider = Provider<SegmentsRepository>((ref) {
  return SegmentsRepository();
});

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
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
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
  final List<CustomerSegment> segments;
  final String selectedSegmentId;
  final bool isLoading;
  final String? errorMessage;
  final String? exportCsv;

  const CustomersState({
    required this.contacts,
    required this.selectedIds,
    required this.searchQuery,
    required this.selectedGroup,
    required this.selectedTag,
    required this.selectedStatus,
    required this.segments,
    required this.selectedSegmentId,
    required this.isLoading,
    this.errorMessage,
    this.exportCsv,
  });

  factory CustomersState.initial() {
    return const CustomersState(
      contacts: [],
      selectedIds: {},
      searchQuery: '',
      selectedGroup: 'Tất cả',
      selectedTag: 'Tất cả',
      selectedStatus: 'Tất cả',
      segments: [],
      selectedSegmentId: '',
      isLoading: false,
      errorMessage: null,
      exportCsv: null,
    );
  }

  CustomersState copyWith({
    List<Contact>? contacts,
    Set<String>? selectedIds,
    String? searchQuery,
    String? selectedGroup,
    String? selectedTag,
    String? selectedStatus,
    List<CustomerSegment>? segments,
    String? selectedSegmentId,
    bool? isLoading,
    String? errorMessage,
    String? exportCsv,
  }) {
    return CustomersState(
      contacts: contacts ?? this.contacts,
      selectedIds: selectedIds ?? this.selectedIds,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      selectedTag: selectedTag ?? this.selectedTag,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      segments: segments ?? this.segments,
      selectedSegmentId: selectedSegmentId ?? this.selectedSegmentId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      exportCsv: exportCsv ?? this.exportCsv,
    );
  }
}

class CustomersNotifier extends StateNotifier<CustomersState> {
  final Ref _ref;
  final CustomersRepository _repository;
  final SegmentsRepository _segmentsRepository;

  CustomersNotifier(this._ref)
    : _repository = _ref.read(customersRepositoryProvider),
      _segmentsRepository = _ref.read(segmentsRepositoryProvider),
      super(CustomersState.initial()) {
    loadSegments();
    loadContacts();
  }

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final response = await _repository.getCustomers(
      search: state.searchQuery,
      status: _mapUiStatusToDb(state.selectedStatus),
      tag: state.selectedTag == 'Tất cả' ? null : state.selectedTag,
      segmentId: state.selectedSegmentId,
      limit: 100,
    );

    if (response['success'] == true && response['data'] != null) {
      final List<dynamic> raw = response['data'];
      final List<Contact> loaded = raw
          .map((json) => ContactJson.fromJson(json))
          .toList();
      state = state.copyWith(contacts: loaded, isLoading: false);
    } else {
      if (kDebugMode) {
        state = state.copyWith(
          contacts: MockContacts.sampleContacts,
          isLoading: false,
          errorMessage:
              'Lỗi tải đám mây (Dữ liệu mẫu chế độ phát triển): ${response['message']}',
        );
      } else {
        state = state.copyWith(
          contacts: const [],
          isLoading: false,
          errorMessage:
              response['message'] ??
              'Không thể tải dữ liệu khách hàng từ đám mây.',
        );
      }
    }
  }

  Future<void> loadSegments() async {
    final response = await _segmentsRepository.getSegments();
    if (response['success'] == true && response['data'] is List) {
      state = state.copyWith(
        segments: (response['data'] as List)
            .whereType<Map>()
            .map(
              (item) =>
                  CustomerSegment.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
    }
  }

  void setSelectedSegment(String segmentId) {
    state = state.copyWith(selectedSegmentId: segmentId);
    loadContacts();
  }

  Future<void> saveCurrentFiltersAsSegment(String name) async {
    final filters = <String, dynamic>{
      if (state.searchQuery.isNotEmpty) 'search': state.searchQuery,
      if (state.selectedTag != 'Tất cả') 'tags': [state.selectedTag],
      if (state.selectedGroup != 'Tất cả') 'source': state.selectedGroup,
    };
    final response = await _segmentsRepository.createSegment(name, filters);
    if (response['success'] == true) {
      await loadSegments();
    } else {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Lưu phân khúc thất bại.')
            .toString(),
      );
    }
  }

  String? _mapUiStatusToDb(String status) {
    switch (status) {
      case 'Chưa gửi':
        return 'lead';
      case 'Đã gửi':
        return 'contact';
      case 'Thất bại':
        return 'inactive';
      case 'Thành công':
        return 'customer';
      case 'Tất cả':
      default:
        return null;
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadContacts();
  }

  void setSelectedGroup(String group) {
    state = state.copyWith(selectedGroup: group);
  }

  void setSelectedTag(String tag) {
    state = state.copyWith(selectedTag: tag);
    loadContacts();
  }

  void setSelectedStatus(String status) {
    state = state.copyWith(selectedStatus: status);
    loadContacts();
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
        errorMessage:
            'Gói dịch vụ đã hết hạn. Hệ thống đang hoạt động ở chế độ Đọc-Chỉ-Xem (Read-Only).',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    final customer = CrmCustomer(
      id: '',
      userId: '',
      name: contact.name,
      email: '',
      phone: contact.phone,
      company: contact.group,
      notes: contact.tag,
      status: 'lead',
      zaloUserId: '',
      zaloThreadId: '',
      tags: [contact.tag],
      source: 'Desktop App',
      lifecycleStage: 'lead',
      consentStatus: 'granted',
      consentEvidence: 'User added from CRM client',
      customFields: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final response = await _repository.createCustomer(customer);

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
        errorMessage:
            response['message'] ??
            'Thêm khách hàng vào cơ sở dữ liệu đám mây thất bại.',
      );
      return false;
    }
  }

  Future<void> importContacts(List<Contact> newContacts) async {
    final auth = _ref.read(crmAuthProvider);
    if (auth.subscriptionStatus == 'expired') {
      state = state.copyWith(
        errorMessage:
            'Gói dịch vụ đã hết hạn. Hệ thống đang hoạt động ở chế độ Đọc-Chỉ-Xem (Read-Only).',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    final rows = newContacts
        .map(
          (contact) => {
            'name': contact.name,
            'phone': contact.phone,
            'company': contact.group,
            'tags': contact.tag,
            'source': 'Import File',
            'consentStatus': 'granted',
            'consentEvidence': 'Imported from CRM client',
          },
        )
        .toList();
    final response = await _repository.importCustomers(rows);

    if (response['success'] == true) {
      await loadContacts();
      state = state.copyWith(isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: (response['message'] ?? 'Nhập khách hàng thất bại.')
            .toString(),
      );
    }
  }

  Future<void> exportContacts() async {
    final response = await _repository.exportCustomers(
      segmentId: state.selectedSegmentId,
    );
    final data = response['data'];
    if (response['success'] == true && data is Map) {
      state = state.copyWith(exportCsv: (data['csv'] ?? '').toString());
    } else {
      state = state.copyWith(
        errorMessage: (response['message'] ?? 'Xuất dữ liệu thất bại.')
            .toString(),
      );
    }
  }

  void clearContacts() {
    state = state.copyWith(contacts: [], selectedIds: {});
  }

  Future<bool> deleteSelected() async {
    final auth = _ref.read(crmAuthProvider);
    if (auth.subscriptionStatus == 'expired') {
      state = state.copyWith(
        errorMessage:
            'Gói dịch vụ đã hết hạn. Hệ thống đang hoạt động ở chế độ Đọc-Chỉ-Xem (Read-Only).',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    bool allSuccess = true;
    final idsToDelete = List<String>.from(state.selectedIds);

    for (final id in idsToDelete) {
      final response = await _repository.deleteCustomer(id);
      if (response['success'] != true) {
        allSuccess = false;
      }
    }

    if (allSuccess) {
      final remainingContacts = state.contacts
          .where((c) => !state.selectedIds.contains(c.id))
          .toList();
      state = state.copyWith(
        contacts: remainingContacts,
        selectedIds: {},
        isLoading: false,
      );
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
