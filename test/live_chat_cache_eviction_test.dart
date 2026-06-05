import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alpha_crm/shared/local_db/local_db.dart';
import 'package:alpha_crm/shared/local_db/local_db_maintenance.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await LocalDb.getInMemoryInstance();
  });

  group('LocalDbMaintenance', () {
    test('runCleanup removes expired cache and media but preserves fresh', () async {
      final db = await LocalDb.getInMemoryInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Setup expired and fresh generic cache
      await db.insert('cache_entries', {
        'key': 'expired_cache',
        'value': '{}',
        'expiresAt': now - 1000,
      });
      await db.insert('cache_entries', {
        'key': 'fresh_cache',
        'value': '{}',
        'expiresAt': now + 10000,
      });

      // 2. Setup expired and fresh media cache
      await db.insert('media_cache', {
        'url': 'expired_url',
        'localPath': '',
        'lastAccessedAt': now - 1000,
        'expiresAt': now - 1000,
      });
      await db.insert('media_cache', {
        'url': 'fresh_url',
        'localPath': '',
        'lastAccessedAt': now,
        'expiresAt': now + 10000,
      });

      // 3. Setup messages
      await db.insert('live_chat_messages', {
        'id': 'msg_old',
        'conversationId': 'conv1',
        'createdAt': DateTime.now().subtract(const Duration(days: 35)).millisecondsSinceEpoch,
      });
      await db.insert('live_chat_messages', {
        'id': 'msg_new',
        'conversationId': 'conv1',
        'createdAt': now,
      });

      await LocalDbMaintenance.runCleanup(clearMessagesOlderThanDays: 30);

      // Verify generic cache
      final cacheRows = await db.query('cache_entries');
      expect(cacheRows.length, 1);
      expect(cacheRows.first['key'], 'fresh_cache');

      // Verify media cache
      final mediaRows = await db.query('media_cache');
      expect(mediaRows.length, 1);
      expect(mediaRows.first['url'], 'fresh_url');

      // Verify messages
      final msgRows = await db.query('live_chat_messages');
      expect(msgRows.length, 1);
      expect(msgRows.first['id'], 'msg_new');
    });

    test('runCleanup does not delete messages if not explicitly configured', () async {
      final db = await LocalDb.getInMemoryInstance();

      await db.insert('live_chat_messages', {
        'id': 'msg_old',
        'conversationId': 'conv1',
        'createdAt': DateTime.now().subtract(const Duration(days: 100)).millisecondsSinceEpoch,
      });

      await LocalDbMaintenance.runCleanup();

      final msgRows = await db.query('live_chat_messages');
      expect(msgRows.length, 1);
    });
  });
}
