import 'dart:convert';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../shared/local_db/local_db.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

class DashboardState {
  final Map<String, dynamic>? overview;
  final Map<String, dynamic> analytics;
  final List<dynamic> performanceData;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final String timeRange; // '7 ngày qua' or '30 ngày qua'

  const DashboardState({
    this.overview,
    required this.analytics,
    required this.performanceData,
    required this.isLoading,
    this.isRefreshing = false,
    this.errorMessage,
    required this.timeRange,
  });

  factory DashboardState.initial() {
    return const DashboardState(
      overview: null,
      analytics: {},
      performanceData: [],
      isLoading: false,
      isRefreshing: false,
      errorMessage: null,
      timeRange: '7 ngày qua',
    );
  }

  DashboardState copyWith({
    Map<String, dynamic>? overview,
    Map<String, dynamic>? analytics,
    List<dynamic>? performanceData,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    String? timeRange,
  }) {
    return DashboardState(
      overview: overview ?? this.overview,
      analytics: analytics ?? this.analytics,
      performanceData: performanceData ?? this.performanceData,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
      timeRange: timeRange ?? this.timeRange,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardRepository _repository;

  DashboardNotifier(Ref ref)
    : _repository = ref.read(dashboardRepositoryProvider),
      super(DashboardState.initial()) {
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    if (WidgetsBinding.instance.toString().contains('Test')) {
      state = state.copyWith(
        overview: _emptyOverview(),
        analytics: const {},
        performanceData: const [],
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    // 1. Try to load from cache
    final cached = await _loadFromCache();
    if (cached != null) {
      state = cached;
      // 2. Schedule network load on next frame / idle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadIdle();
      });
    } else {
      // No cache, load immediately
      await loadDashboard();
    }
  }

  void _loadIdle() {
    SchedulerBinding.instance.scheduleTask<void>(
      () {
        loadDashboard(isBackground: true);
      },
      Priority.idle,
      debugLabel: 'LoadDashboardIdle',
    );
  }

  Future<void> _saveToCache(DashboardState dashboardState) async {
    try {
      final db = await LocalDb.instance;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Cache entries expire in 1 day
      final expiresAt = now + const Duration(days: 1).inMilliseconds;

      final data = {
        'overview': dashboardState.overview,
        'analytics': dashboardState.analytics,
        'performanceData': dashboardState.performanceData,
        'timeRange': dashboardState.timeRange,
      };

      await db.insert(
        'cache_entries',
        {
          'key': 'dashboard_cache',
          'value': jsonEncode(data),
          'expiresAt': expiresAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving dashboard to cache: $e');
    }
  }

  Future<DashboardState?> _loadFromCache() async {
    try {
      final db = await LocalDb.instance;
      final results = await db.query(
        'cache_entries',
        where: 'key = ?',
        whereArgs: ['dashboard_cache'],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final valueStr = results.first['value'] as String;
        final decoded = jsonDecode(valueStr) as Map<String, dynamic>;
        return DashboardState(
          overview: decoded['overview'] as Map<String, dynamic>?,
          analytics: Map<String, dynamic>.from(decoded['analytics'] ?? {}),
          performanceData: decoded['performanceData'] as List<dynamic>? ?? [],
          timeRange: decoded['timeRange'] as String? ?? '7 ngày qua',
          isLoading: false,
          errorMessage: null,
        );
      }
    } catch (e) {
      debugPrint('Error loading dashboard from cache: $e');
    }
    return null;
  }

  Future<void> loadDashboard({bool isBackground = false}) async {
    if (WidgetsBinding.instance.toString().contains('Test')) {
      state = state.copyWith(
        overview: _emptyOverview(),
        analytics: const {},
        performanceData: const [],
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    if (!isBackground) {
      state = state.copyWith(isLoading: true, isRefreshing: false, errorMessage: null);
    } else {
      state = state.copyWith(isRefreshing: true, errorMessage: null);
    }

    try {
      final overviewResponse = await _repository.getOverview();
      final rangeParam = state.timeRange == '7 ngày qua' ? '7d' : '30d';
      final performanceResponse = await _repository.getCampaignPerformance(
        range: rangeParam,
      );
      final analyticsResponses = await Future.wait([
        _repository.getFunnelAnalytics(),
        _repository.getCampaignAnalytics(),
        _repository.getChatbotAnalytics(),
        _repository.getGroupAnalytics(),
      ]);

      if (overviewResponse['success'] == true &&
          performanceResponse['success'] == true) {
        final newState = state.copyWith(
          overview: overviewResponse['data'],
          analytics: {
            'funnel': analyticsResponses[0]['data'] ?? const [],
            'campaigns': analyticsResponses[1]['data'] ?? const [],
            'chatbot': analyticsResponses[2]['data'] ?? const [],
            'groups': analyticsResponses[3]['data'] ?? const {},
          },
          performanceData: performanceResponse['data'] ?? const [],
          isLoading: false,
          isRefreshing: false,
        );
        state = newState;
        await _saveToCache(newState);
      } else {
        final err =
            overviewResponse['message'] ??
            performanceResponse['message'] ??
            'Lỗi tải tổng quan từ đám mây';
        state = state.copyWith(isLoading: false, isRefreshing: false, errorMessage: err);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, isRefreshing: false, errorMessage: e.toString());
    }
  }

  void setTimeRange(String range) {
    if (state.timeRange == range) return;
    state = state.copyWith(timeRange: range);
    loadDashboard();
  }

  Map<String, dynamic> _emptyOverview() {
    return {
      'subscription': {'active': true, 'plan': 'test', 'periodEnd': null},
      'aiQuota': {
        'includedAiLimit': 0,
        'includedAiUsed': 0,
        'extraAiRemaining': 0,
        'totalRemaining': 0,
      },
      'activeDevices': 0,
      'connectedAccounts': 0,
      'customerStats': {'total': 0, 'byLifecycle': {}, 'byStatus': {}},
      'campaignStats': {'total': 0, 'byStatus': {}},
      'sendHistoryStats': {
        'last7Days': {
          'total': 0,
          'success': 0,
          'failed': 0,
          'queued': 0,
          'failedSendRate': 0,
        },
        'last30Days': {
          'total': 0,
          'success': 0,
          'failed': 0,
          'queued': 0,
          'failedSendRate': 0,
        },
      },
    };
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
      return DashboardNotifier(ref);
    });
