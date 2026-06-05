import 'local_db.dart';

class LocalDbMaintenance {
  /// Cleans up expired cache entries. Can be run safely on app start.
  /// Set [clearMessagesOlderThanDays] to a positive number to purge old messages.
  static Future<void> runCleanup({int? clearMessagesOlderThanDays}) async {
    try {
      final db = await LocalDb.instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Cleanup expired generic cache
      await db.delete(
        'cache_entries',
        where: 'expiresAt < ?',
        whereArgs: [now],
      );

      // Cleanup expired media cache
      await db.delete('media_cache', where: 'expiresAt < ?', whereArgs: [now]);

      // Cleanup old messages if explicitly configured
      if (clearMessagesOlderThanDays != null &&
          clearMessagesOlderThanDays > 0) {
        final threshold = DateTime.now()
            .subtract(Duration(days: clearMessagesOlderThanDays))
            .millisecondsSinceEpoch;
        await db.delete(
          'live_chat_messages',
          where: 'createdAt < ?',
          whereArgs: [threshold],
        );
      }
    } catch (e) {
      // Opportunistic cleanup should not crash the app
      print('Local DB maintenance failed: $e');
    }
  }
}
