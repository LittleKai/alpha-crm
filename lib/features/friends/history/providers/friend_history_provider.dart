import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../shared/local_db/local_db.dart';

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
  Future<void>? _loadFuture;

  FriendHistoryNotifier() : super(const FriendHistoryState(records: [])) {
    print('DEBUG: FriendHistoryNotifier initialized');
    _loadFuture = loadHistory();
  }

  Future<void> _migrateJsonToSqlite(Database db) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final crmDir = Directory('${directory.path}/AlphaCRM');
      final file = File('${crmDir.path}/zalo_friend_history.json');
      
      print('DEBUG: Checking for legacy JSON at ${file.path}');
      if (await file.exists()) {
        final content = await file.readAsString();
        print('DEBUG: Found legacy JSON, length: ${content.length}');
        if (content.trim().isNotEmpty) {
          final jsonList = jsonDecode(content) as List<dynamic>;
          print('DEBUG: Parsed ${jsonList.length} legacy records. Migrating...');
          for (final item in jsonList) {
            final record = FriendHistoryRecord.fromJson(item as Map<String, dynamic>);
            await db.insert('friend_history', record.toJson(), conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
        await file.rename('${crmDir.path}/zalo_friend_history.json.migrated');
        print('DEBUG: Legacy JSON migrated and renamed successfully.');
      } else {
        print('DEBUG: No legacy JSON found.');
      }
    } catch (e) {
      print('DEBUG: Error migrating JSON: $e');
    }
  }

  Future<void> loadHistory() async {
    try {
      print('DEBUG: loadHistory started');
      final db = await LocalDb.instance;
      print('DEBUG: DB instance retrieved');
      
      await _migrateJsonToSqlite(db);

      print('DEBUG: Querying friend_history table...');
      final maps = await db.query('friend_history', orderBy: 'id DESC');
      print('DEBUG: DB returned ${maps.length} records');
      
      final loadedRecords = maps.map((e) => FriendHistoryRecord.fromJson(e)).toList();
      state = state.copyWith(records: loadedRecords);
      print('DEBUG: state updated with ${state.records.length} records');
    } catch (e) {
      print('DEBUG: Exception in loadHistory: $e');
    }
  }

  Future<void> addRecord(FriendHistoryRecord record) async {
    print('DEBUG: addRecord called for ${record.targetName} (${record.targetPhone})');
    if (_loadFuture != null) {
      print('DEBUG: Waiting for initial loadHistory to complete...');
      await _loadFuture;
      _loadFuture = null;
    }
    
    state = state.copyWith(records: [record, ...state.records]);
    print('DEBUG: Record added to local state. New total: ${state.records.length}');
    
    try {
      final db = await LocalDb.instance;
      await db.insert('friend_history', record.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      print('DEBUG: Record successfully inserted into DB');
    } catch (e) {
      print('DEBUG: Error inserting record into DB: $e');
    }
  }

  Future<void> clearHistory() async {
    print('DEBUG: clearHistory called');
    if (_loadFuture != null) {
      await _loadFuture;
      _loadFuture = null;
    }
    
    state = const FriendHistoryState(records: []);
    
    try {
      final db = await LocalDb.instance;
      await db.delete('friend_history');
      print('DEBUG: clearHistory completed successfully');
    } catch (e) {
      print('DEBUG: Error clearing history from DB: $e');
    }
  }
}

final friendHistoryProvider =
    StateNotifierProvider<FriendHistoryNotifier, FriendHistoryState>((ref) {
      return FriendHistoryNotifier();
    });
