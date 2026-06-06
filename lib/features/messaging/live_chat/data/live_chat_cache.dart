import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../shared/local_db/local_db.dart';

class LiveChatCache {
  /// Save a list of conversations to the generic cache and specific conversations table
  Future<void> saveConversations(
    String cacheKey,
    List<Map<String, dynamic>> conversations,
    Duration ttl,
  ) async {
    final db = await LocalDb.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + ttl.inMilliseconds;

    await db.transaction((txn) async {
      // 1. Save metadata list order in cache_entries
      await txn.insert('cache_entries', {
        'key': cacheKey,
        'value': jsonEncode(conversations),
        'expiresAt': expiresAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Upsert individual conversations
      for (final conv in conversations) {
        if (conv['threadId'] == null || conv['accountId'] == null) continue;

        await txn.insert('live_chat_conversations', {
          'threadId': conv['threadId'],
          'accountId': conv['accountId'],
          'threadType': conv['threadType'] ?? 'user',
          'displayName': conv['displayName'],
          'avatarUrl': conv['avatarUrl'],
          'lastMessagePreview': conv['lastMessagePreview'],
          'lastMessageAt': conv['lastMessageAt'] != null
              ? DateTime.tryParse(
                  conv['lastMessageAt'].toString(),
                )?.millisecondsSinceEpoch
              : null,
          'unreadCount': conv['unreadCount'] ?? 0,
          'deviceId': conv['deviceId'],
          'updatedAt': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Returns cached conversations if valid, else null
  Future<List<Map<String, dynamic>>?> getFreshConversations(
    String cacheKey,
  ) async {
    final db = await LocalDb.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    final result = await db.query(
      'cache_entries',
      where: 'key = ? AND expiresAt > ?',
      whereArgs: [cacheKey, now],
      limit: 1,
    );

    if (result.isNotEmpty) {
      final value = result.first['value'] as String;
      return List<Map<String, dynamic>>.from(jsonDecode(value));
    }
    return null;
  }

  /// Saves full messages to the message cache
  Future<void> saveMessages(
    String conversationId,
    List<Map<String, dynamic>> messages, {
    bool merge = true,
  }) async {
    final db = await LocalDb.instance;

    await db.transaction((txn) async {
      for (final msg in messages) {
        // Use _id, id, or providerMessageId as primary key
        final String id =
            msg['_id'] ??
            msg['id'] ??
            msg['providerMessageId'] ??
            _generateDeterministicId(msg);

        await txn.insert(
          'live_chat_messages',
          {
            'id': id,
            'conversationId': conversationId,
            'providerMessageId': msg['providerMessageId'],
            'clientMessageId': msg['clientMessageId'],
            'senderId': msg['senderId'],
            'senderName': msg['senderName'],
            'direction': msg['direction'],
            'messageType': msg['messageType'],
            'content': msg['content'],
            'status': msg['status'],
            'errorText': msg['errorText'],
            'quoteJson': msg['quoteJson'] ?? _encodeNullable(msg['quote']),
            'mentionsJson':
                msg['mentionsJson'] ?? _encodeNullable(msg['mentions']),
            'stylesJson': msg['stylesJson'] ?? _encodeNullable(msg['styles']),
            'metadataJson':
                msg['metadataJson'] ?? _encodeNullable(msg['metadata']),
            'recalledContent': msg['recalledContent'],
            'attachments': msg['attachments'] != null
                ? jsonEncode(msg['attachments'])
                : null,
            'createdAt': _extractTimestamp(msg),
          },
          conflictAlgorithm: merge
              ? ConflictAlgorithm.replace
              : ConflictAlgorithm.ignore,
        );
      }
    });
  }

  int _extractTimestamp(Map<String, dynamic> msg) {
    final val = msg['createdAt'] ?? msg['receivedAt'] ?? msg['sentAt'];
    if (val != null) {
      return DateTime.tryParse(val.toString())?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  String _generateDeterministicId(Map<String, dynamic> msg) {
    // Fallback key matching _messageKey behavior in LiveChatNotifier
    final timestamp =
        msg['createdAt'] ??
        msg['receivedAt'] ??
        msg['sentAt'] ??
        DateTime.now().toIso8601String();
    return 'local_${msg['senderId']}_$timestamp';
  }

  String? _encodeNullable(Object? value) {
    return value == null ? null : jsonEncode(value);
  }

  /// Get messages from cache
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
    String? after,
  }) async {
    final db = await LocalDb.instance;

    String where = 'conversationId = ?';
    List<Object?> whereArgs = [conversationId];

    if (before != null) {
      where += ' AND createdAt < ?';
      whereArgs.add(DateTime.parse(before).millisecondsSinceEpoch);
    }

    if (after != null) {
      where += ' AND createdAt > ?';
      whereArgs.add(DateTime.parse(after).millisecondsSinceEpoch);
    }

    final results = await db.query(
      'live_chat_messages',
      where: where,
      whereArgs: whereArgs,
      orderBy: after != null ? 'createdAt ASC' : 'createdAt DESC',
      limit: limit,
    );

    return results.map((row) {
      final map = Map<String, dynamic>.from(row);
      if (map['attachments'] != null) {
        map['attachments'] = jsonDecode(map['attachments'] as String);
      }
      if (map['createdAt'] != null) {
        map['createdAt'] = DateTime.fromMillisecondsSinceEpoch(
          map['createdAt'] as int,
        ).toIso8601String();
      }
      map['_id'] = map['id'];
      return map;
    }).toList();
  }

  /// Clears failed messages
  Future<void> clearFailedMessages(String conversationId) async {
    final db = await LocalDb.instance;
    await db.delete(
      'live_chat_messages',
      where: 'conversationId = ? AND status = ?',
      whereArgs: [conversationId, 'failed'],
    );
  }

  /// Keeps a media URL fresh in the cache
  Future<void> touchMediaUrl(String url, Map<String, dynamic> metadata) async {
    final db = await LocalDb.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + const Duration(days: 7).inMilliseconds;

    await db.insert('media_cache', {
      'url': url,
      'localPath': metadata['localPath'] ?? '',
      'mimeType': metadata['mimeType'],
      'size': metadata['size'],
      'lastAccessedAt': now,
      'expiresAt': expiresAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
