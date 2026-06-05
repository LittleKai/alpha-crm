import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alpha_crm/shared/local_db/local_db.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_cache.dart';

void main() {
  late LiveChatCache cache;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Reset DB for each test
    await LocalDb.getInMemoryInstance();
    cache = LiveChatCache();
  });

  group('LiveChatCache', () {
    test('save and get conversations respects TTL', () async {
      final conversations = [
        {
          'threadId': 't1',
          'accountId': 'a1',
          'displayName': 'Test User',
        }
      ];

      await cache.saveConversations('my_key', conversations, const Duration(seconds: 10));
      
      final fresh = await cache.getFreshConversations('my_key');
      expect(fresh, isNotNull);
      expect(fresh!.length, 1);
      expect(fresh[0]['displayName'], 'Test User');

      // Test expired
      await cache.saveConversations('my_key2', conversations, const Duration(milliseconds: -100));
      final expired = await cache.getFreshConversations('my_key2');
      expect(expired, isNull);
    });

    test('save and get messages', () async {
      final messages = [
        {
          '_id': 'm1',
          'content': 'Hello',
          'createdAt': '2026-06-05T10:00:00.000Z',
          'status': 'sent'
        },
        {
          '_id': 'm2',
          'content': 'World',
          'createdAt': '2026-06-05T10:05:00.000Z',
          'status': 'failed'
        }
      ];

      await cache.saveMessages('conv1', messages);

      final cached = await cache.getMessages('conv1');
      expect(cached.length, 2);
      
      // Order should be descending by default (m2 then m1)
      expect(cached[0]['content'], 'World');
      expect(cached[1]['content'], 'Hello');

      // Test clear failed
      await cache.clearFailedMessages('conv1');
      final cleared = await cache.getMessages('conv1');
      expect(cleared.length, 1);
      expect(cleared[0]['content'], 'Hello');
    });
  });
}
