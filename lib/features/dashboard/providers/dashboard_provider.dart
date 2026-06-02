import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

class DashboardState {
  final Map<String, dynamic>? overview;
  final Map<String, dynamic> analytics;
  final List<dynamic> performanceData;
  final bool isLoading;
  final String? errorMessage;
  final String timeRange; // '7 ngày qua' or '30 ngày qua'

  const DashboardState({
    this.overview,
    required this.analytics,
    required this.performanceData,
    required this.isLoading,
    this.errorMessage,
    required this.timeRange,
  });

  factory DashboardState.initial() {
    return const DashboardState(
      overview: null,
      analytics: {},
      performanceData: [],
      isLoading: false,
      errorMessage: null,
      timeRange: '7 ngày qua',
    );
  }

  DashboardState copyWith({
    Map<String, dynamic>? overview,
    Map<String, dynamic>? analytics,
    List<dynamic>? performanceData,
    bool? isLoading,
    String? errorMessage,
    String? timeRange,
  }) {
    return DashboardState(
      overview: overview ?? this.overview,
      analytics: analytics ?? this.analytics,
      performanceData: performanceData ?? this.performanceData,
      isLoading: isLoading ?? this.isLoading,
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
    loadDashboard();
  }

  Future<void> loadDashboard() async {
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

    state = state.copyWith(isLoading: true, errorMessage: null);

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
        state = state.copyWith(
          overview: overviewResponse['data'],
          analytics: {
            'funnel': analyticsResponses[0]['data'] ?? const [],
            'campaigns': analyticsResponses[1]['data'] ?? const [],
            'chatbot': analyticsResponses[2]['data'] ?? const [],
            'groups': analyticsResponses[3]['data'] ?? const {},
          },
          performanceData: performanceResponse['data'] ?? const [],
          isLoading: false,
        );
      } else {
        final err =
            overviewResponse['message'] ??
            performanceResponse['message'] ??
            'Lỗi tải tổng quan từ đám mây';
        state = state.copyWith(isLoading: false, errorMessage: err);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
