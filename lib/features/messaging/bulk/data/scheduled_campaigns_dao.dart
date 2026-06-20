import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../shared/local_db/local_db.dart';
import 'scheduled_campaign.dart';

/// CRUD for the `scheduled_campaigns` table (see LocalDbSchema).
class ScheduledCampaignsDao {
  static const String _table = 'scheduled_campaigns';

  Future<List<ScheduledCampaign>> getAll() async {
    final db = await LocalDb.instance;
    final rows = await db.query(_table, orderBy: 'scheduledAt ASC');
    return rows.map(ScheduledCampaign.fromMap).toList();
  }

  Future<void> upsert(ScheduledCampaign job) async {
    final db = await LocalDb.instance;
    await db.insert(
      _table,
      job.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await LocalDb.instance;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
