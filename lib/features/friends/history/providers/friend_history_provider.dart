import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FriendHistoryRecord {
  final String id;
  final String targetName;
  final String targetPhone;
  final String accountLabel;
  final String timestamp;
  final String status; // 'Thành công', 'Thất bại', 'Đang gửi'
  final String message;

  const FriendHistoryRecord({
    required this.id,
    required this.targetName,
    required this.targetPhone,
    required this.accountLabel,
    required this.timestamp,
    required this.status,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetName': targetName,
      'targetPhone': targetPhone,
      'accountLabel': accountLabel,
      'timestamp': timestamp,
      'status': status,
      'message': message,
    };
  }

  factory FriendHistoryRecord.fromJson(Map<String, dynamic> json) {
    return FriendHistoryRecord(
      id: json['id'] as String? ?? '',
      targetName: json['targetName'] as String? ?? '',
      targetPhone: json['targetPhone'] as String? ?? '',
      accountLabel: json['accountLabel'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      status: json['status'] as String? ?? 'Chưa xác định',
      message: json['message'] as String? ?? '',
    );
  }
}

class FriendHistoryState {
  final List<FriendHistoryRecord> records;

  const FriendHistoryState({required this.records});

  FriendHistoryState copyWith({List<FriendHistoryRecord>? records}) {
    return FriendHistoryState(records: records ?? this.records);
  }
}

class FriendHistoryNotifier extends StateNotifier<FriendHistoryState> {
  FriendHistoryNotifier() : super(const FriendHistoryState(records: [])) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final file = File('zalo_friend_history.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonList = jsonDecode(content) as List<dynamic>;
        final loadedRecords = jsonList
            .map(
              (item) =>
                  FriendHistoryRecord.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        state = state.copyWith(records: loadedRecords);
      }
    } catch (_) {
      // Fallback
    }
  }

  Future<void> _saveHistory() async {
    try {
      final file = File('zalo_friend_history.json');
      final content = const JsonEncoder.withIndent(
        '  ',
      ).convert(state.records.map((r) => r.toJson()).toList());
      await file.writeAsString(content);
    } catch (_) {
      // Ignore
    }
  }

  void addRecord(FriendHistoryRecord record) {
    state = state.copyWith(records: [record, ...state.records]);
    _saveHistory();
  }

  void clearHistory() {
    state = const FriendHistoryState(records: []);
    _saveHistory();
  }
}

final friendHistoryProvider =
    StateNotifierProvider<FriendHistoryNotifier, FriendHistoryState>((ref) {
      return FriendHistoryNotifier();
    });
