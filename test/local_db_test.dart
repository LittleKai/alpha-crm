import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alpha_crm/shared/local_db/local_db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalDb', () {
    test('opens in-memory database and creates tables', () async {
      final db = await LocalDb.getInMemoryInstance();
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      
      final tableNames = tables.map((t) => t['name'] as String).toList();
      expect(tableNames, contains('cache_entries'));
      expect(tableNames, contains('live_chat_conversations'));
      expect(tableNames, contains('live_chat_messages'));
      expect(tableNames, contains('media_cache'));
    });

    test('cleanupExpiredCache removes expired entries', () async {
      final db = await LocalDb.getInMemoryInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Insert one active, one expired
      await db.insert('cache_entries', {
        'key': 'active',
        'value': '{}',
        'expiresAt': now + 10000,
      });
      await db.insert('cache_entries', {
        'key': 'expired',
        'value': '{}',
        'expiresAt': now - 10000,
      });

      await LocalDb.cleanupExpiredCache();

      final remaining = await db.query('cache_entries');
      expect(remaining.length, 1);
      expect(remaining.first['key'], 'active');
    });
  });
}
