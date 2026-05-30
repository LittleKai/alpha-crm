import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../mock/mock_contacts.dart';

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
  CustomersNotifier() : super(CustomersState.initial());

  void loadContacts() {
    state = state.copyWith(isLoading: true);
    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 500), () {
      state = state.copyWith(
        contacts: MockContacts.sampleContacts,
        isLoading: false,
      );
    });
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

  void addContact(Contact contact) {
    state = state.copyWith(contacts: [contact, ...state.contacts]);
  }

  void importContacts(List<Contact> newContacts) {
    state = state.copyWith(contacts: [...newContacts, ...state.contacts]);
  }

  void clearContacts() {
    state = state.copyWith(contacts: [], selectedIds: {});
  }

  void deleteSelected() {
    final remainingContacts = state.contacts
        .where((c) => !state.selectedIds.contains(c.id))
        .toList();
    state = state.copyWith(contacts: remainingContacts, selectedIds: {});
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
      return CustomersNotifier();
    });
