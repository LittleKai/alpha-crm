import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alpha_crm/shared/local_db/local_db.dart';
import 'package:alpha_crm/features/messaging/bulk/data/bulk_campaign_repository.dart';
import 'package:alpha_crm/features/messaging/bulk/data/scheduled_campaign.dart';
import 'package:alpha_crm/features/messaging/bulk/providers/bulk_messaging_provider.dart';

class _FakeBulkCampaignRepository extends BulkCampaignRepository {
  Map<String, dynamic>? lastTemplatePayload;
  Map<String, dynamic>? lastCampaignPayload;

  @override
  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> data) async {
    lastTemplatePayload = data;
    return {
      'success': true,
      'data': {'_id': 'tpl-1'},
    };
  }

  @override
  Future<Map<String, dynamic>> createCampaign(Map<String, dynamic> data) async {
    lastCampaignPayload = data;
    return {
      'success': true,
      'data': {'_id': 'cmp-1'},
    };
  }

  @override
  Future<Map<String, dynamic>> startCampaign(
    String campaignId, {
    String? humanApprovedAt,
  }) async {
    return {'success': true};
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalDb', () {
    test('opens in-memory database and creates tables', () async {
      final db = await LocalDb.getInMemoryInstance();
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final tableNames = tables.map((t) => t['name'] as String).toList();
      expect(tableNames, contains('cache_entries'));
      expect(tableNames, contains('live_chat_conversations'));
      expect(tableNames, contains('live_chat_messages'));
      expect(tableNames, contains('media_cache'));
      expect(tableNames, contains('live_chat_drafts'));
      expect(tableNames, contains('live_chat_receipts'));
      expect(tableNames, contains('live_chat_reactions'));
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

    test('ScheduledCampaign round-trips attachments and launchCampaign forwards them', () async {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final campaign = ScheduledCampaign(
        id: 'sched-1',
        name: 'Promo',
        message: '',
        isGroupMessage: false,
        recipients: const [ScheduledRecipient(id: '0901234567', name: 'An')],
        attachments: const ['C:/tmp/promo.png', 'C:/tmp/brochure.pdf'],
        accountId: 'acc-1',
        minDelay: 15,
        maxDelay: 30,
        requireHumanApproval: false,
        scheduledAt: now,
        status: ScheduledStatus.pending,
        createdAt: now,
      );

      final restored = ScheduledCampaign.fromMap(campaign.toMap());
      expect(restored.recipients.single.id, '0901234567');
      expect(restored.attachments, ['C:/tmp/promo.png', 'C:/tmp/brochure.pdf']);

      final fakeRepo = _FakeBulkCampaignRepository();
      final launchedId = await launchCampaign(
        fakeRepo,
        CampaignLaunchParams(
          name: restored.name,
          message: restored.message,
          isGroupMessage: restored.isGroupMessage,
          recipientIds: restored.recipients.map((r) => r.id).toList(),
          recipientNames: {for (final r in restored.recipients) r.id: r.name},
          attachments: restored.attachments,
          accountId: restored.accountId,
          minDelay: restored.minDelay,
          maxDelay: restored.maxDelay,
          requireHumanApproval: restored.requireHumanApproval,
        ),
      );
      expect(launchedId, 'cmp-1');
      expect(fakeRepo.lastTemplatePayload?['body'], '[Đính kèm]');
      expect(
        fakeRepo.lastCampaignPayload?['attachments'],
        ['C:/tmp/promo.png', 'C:/tmp/brochure.pdf'],
      );
    });
  });
}
