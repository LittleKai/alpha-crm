import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bulk_campaign_repository.dart';
import '../data/scheduled_campaign.dart';
import '../data/scheduled_campaigns_dao.dart';
import 'bulk_messaging_provider.dart';

/// Owns the queue of scheduled (pending) bulk campaigns. Each pending job has its
/// own client-side [Timer]; at fire time the snapshot is launched through the
/// shared [launchCampaign]. State + Timers live here (top-level provider, no
/// autoDispose) so the queue survives navigating between screens, and the jobs
/// are mirrored to SQLite so they survive an app restart (past-due jobs are
/// surfaced as `missed`, never silently sent late).
class ScheduledCampaignsNotifier
    extends StateNotifier<List<ScheduledCampaign>> {
  final BulkCampaignRepository _repository;
  final ScheduledCampaignsDao _dao;
  final Map<String, Timer> _timers = {};

  ScheduledCampaignsNotifier(this._repository, this._dao) : super(const []) {
    _loadAndRearm();
  }

  /// Number of jobs still in the queue (pending + missed + failed).
  int get pendingCount => state.length;

  Future<void> _loadAndRearm() async {
    List<ScheduledCampaign> jobs;
    try {
      jobs = await _dao.getAll();
    } catch (e) {
      debugPrint('[scheduled] load failed: $e');
      return;
    }

    final now = DateTime.now();
    final restored = <ScheduledCampaign>[];
    for (final job in jobs) {
      if (job.status == ScheduledStatus.pending &&
          job.scheduledAt.isAfter(now)) {
        restored.add(job);
      } else if (job.status == ScheduledStatus.pending) {
        // Was due while the app was closed → mark missed (do NOT auto-send late).
        final missed = job.copyWith(status: ScheduledStatus.missed);
        restored.add(missed);
        await _dao.upsert(missed);
      } else {
        restored.add(job); // already missed/failed
      }
    }
    state = restored;

    for (final job in restored) {
      if (job.status == ScheduledStatus.pending) _scheduleTimer(job);
    }
  }

  void _scheduleTimer(ScheduledCampaign job) {
    _timers.remove(job.id)?.cancel();
    final delay = job.scheduledAt.difference(DateTime.now());
    if (delay.inSeconds <= 0) {
      _fire(job.id);
      return;
    }
    _timers[job.id] = Timer(delay, () => _fire(job.id));
  }

  ScheduledCampaign? _byId(String id) {
    for (final j in state) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// Queue a new snapshot and arm its Timer.
  Future<void> arm(ScheduledCampaign job) async {
    await _dao.upsert(job);
    state = [...state, job];
    _scheduleTimer(job);
  }

  /// Remove a job from the queue entirely.
  Future<void> cancel(String id) async {
    _timers.remove(id)?.cancel();
    await _dao.delete(id);
    state = state.where((j) => j.id != id).toList();
  }

  /// Change the fire time of a job and re-arm it (also revives missed/failed).
  Future<void> reschedule(String id, DateTime newTime) async {
    final job = _byId(id);
    if (job == null) return;
    final updated = job.copyWith(
      scheduledAt: newTime,
      status: ScheduledStatus.pending,
    );
    await _dao.upsert(updated);
    state = [
      for (final j in state) j.id == id ? updated : j,
    ];
    _scheduleTimer(updated);
  }

  /// Launch a job immediately, regardless of its scheduled time.
  Future<void> sendNow(String id) => _fire(id);

  Future<void> _fire(String id) async {
    final job = _byId(id);
    if (job == null) return;
    _timers.remove(id)?.cancel();

    try {
      await launchCampaign(
        _repository,
        CampaignLaunchParams(
          name: job.name,
          message: job.message,
          isGroupMessage: job.isGroupMessage,
          recipientIds: job.recipients.map((r) => r.id).toList(),
          recipientNames: {for (final r in job.recipients) r.id: r.name},
          accountId: job.accountId,
          minDelay: job.minDelay,
          maxDelay: job.maxDelay,
          requireHumanApproval: job.requireHumanApproval,
        ),
      );
      // Launched successfully → it now runs on the Cloud/agent; drop from queue.
      await _dao.delete(id);
      state = state.where((j) => j.id != id).toList();
    } catch (e) {
      debugPrint('[scheduled] fire failed for $id: $e');
      final failed = job.copyWith(status: ScheduledStatus.failed);
      await _dao.upsert(failed);
      state = [
        for (final j in state) j.id == id ? failed : j,
      ];
    }
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

final scheduledCampaignsProvider =
    StateNotifierProvider<ScheduledCampaignsNotifier, List<ScheduledCampaign>>(
      (ref) =>
          ScheduledCampaignsNotifier(BulkCampaignRepository(), ScheduledCampaignsDao()),
    );
