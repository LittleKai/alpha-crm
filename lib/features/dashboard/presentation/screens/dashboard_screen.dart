import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_campaigns.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tabs.dart';
import '../../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: state.isLoading && state.overview == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: notifier.loadDashboard,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(
                  ResponsiveBreakpoints.isMobile(context)
                      ? AppSpacing.m
                      : AppSpacing.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(state),
                    const SizedBox(height: AppSpacing.l),
                    if (state.overview != null) ...[
                      _buildSubscriptionWarning(state),
                      const SizedBox(height: AppSpacing.l),
                      _buildOperationsMetrics(state),
                      const SizedBox(height: AppSpacing.l),
                    ],
                    _buildPerformanceCard(state, notifier),
                    const SizedBox(height: AppSpacing.l),
                    _buildQuickActionsSection(),
                    const SizedBox(height: AppSpacing.l),
                    _buildGuideSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(DashboardState state) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tổng quan chiến dịch', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hệ thống theo dõi hiệu suất gửi tin và các chỉ số Zalo Marketing của bạn',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionWarning(DashboardState state) {
    final sub = state.overview?['subscription'];
    final isActive = sub != null && sub['active'] == true;

    if (isActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              sub == null
                  ? 'Bạn chưa đăng ký gói dịch vụ Alpha CRM. Vui lòng đăng ký để sử dụng đầy đủ các tính năng.'
                  : 'Gói đăng ký Alpha CRM của bạn đã hết hạn. Hãy gia hạn gói dịch vụ để tiếp tục gửi tin.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsMetrics(DashboardState state) {
    final taskStats = state.overview?['taskStats'] ?? const {};
    final groupStats = state.analytics['groups'] ?? const {};
    final chatbotStats = state.analytics['chatbot'];
    final chatbotTotal = chatbotStats is List
        ? chatbotStats.fold<int>(
            0,
            (sum, item) => sum + ((item['count'] ?? 0) as num).toInt(),
          )
        : 0;
    final metrics = [
      _OperationMetric(
        label: 'Task qua han',
        value: (taskStats['overdue'] ?? 0).toString(),
        icon: Icons.warning_amber_outlined,
        color: AppColors.error,
      ),
      _OperationMetric(
        label: 'Task hom nay',
        value: (taskStats['dueToday'] ?? 0).toString(),
        icon: Icons.today_outlined,
        color: AppColors.warning,
      ),
      _OperationMetric(
        label: 'Bot replies',
        value: chatbotTotal.toString(),
        icon: Icons.smart_toy_outlined,
        color: AppColors.primary,
      ),
      _OperationMetric(
        label: 'Nhom managed',
        value: (groupStats['managedGroups'] ?? 0).toString(),
        icon: Icons.groups_2_outlined,
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
            mainAxisExtent: 74,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) => metrics[index],
        );
      },
    );
  }

  Widget _buildPerformanceCard(
    DashboardState state,
    DashboardNotifier notifier,
  ) {
    // Extract totals from send stats
    final timeRangeKey = state.timeRange == '7 ngày qua'
        ? 'last7Days'
        : 'last30Days';
    final sendStats = state.overview?['sendHistoryStats']?[timeRangeKey];
    final int totalSuccess = sendStats?['success'] ?? 0;
    final int totalFailure = sendStats?['failed'] ?? 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackHeader = constraints.maxWidth < 1200;
              final title = Text(
                'Báo cáo hiệu suất chiến dịch',
                style: AppTextStyles.sectionTitle,
              );

              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: AppSpacing.m),
                    _buildChartControls(
                      state,
                      notifier,
                      totalSuccess,
                      totalFailure,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: AppSpacing.m),
                  _buildChartControls(
                    state,
                    notifier,
                    totalSuccess,
                    totalFailure,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            height: 300,
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _buildPerformanceChart(state.performanceData),
          ),
        ],
      ),
    );
  }

  Widget _buildChartControls(
    DashboardState state,
    DashboardNotifier notifier,
    int success,
    int failure,
  ) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppTabs(
          isSegmented: true,
          tabs: const [
            AppTabItem(label: 'Tin nhắn', icon: Icons.near_me_outlined),
            AppTabItem(label: 'Kết bạn', icon: Icons.person_add_alt_outlined),
            AppTabItem(label: 'Phản hồi', icon: Icons.chat_bubble_outline),
          ],
          selectedIndex: _selectedTab,
          onTabSelected: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
        ),
        _buildRangeButtons(state, notifier),
        _buildChartTotals(success, failure),
      ],
    );
  }

  Widget _buildRangeButtons(DashboardState state, DashboardNotifier notifier) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRangeButton(state, notifier, '7 ngày qua'),
          _buildRangeButton(state, notifier, '30 ngày qua'),
        ],
      ),
    );
  }

  Widget _buildRangeButton(
    DashboardState state,
    DashboardNotifier notifier,
    String label,
  ) {
    final selected = state.timeRange == label;

    return InkWell(
      onTap: () => notifier.setTimeRange(label),
      borderRadius: BorderRadius.circular(AppSpacing.radiusS),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildChartTotals(int success, int failure) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Thành công: ',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          success.toString(),
          style: AppTextStyles.captionBold.copyWith(color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.m),
        Container(width: 1, height: 18, color: AppColors.border),
        const SizedBox(width: AppSpacing.m),
        Text(
          'Thất bại: ',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          failure.toString(),
          style: AppTextStyles.captionBold.copyWith(color: AppColors.error),
        ),
      ],
    );
  }

  Widget _buildPerformanceChart(List<dynamic> performanceData) {
    if (performanceData.isEmpty) {
      return const Center(
        child: Text('Không có dữ liệu hiệu suất gửi tin từ đám mây.'),
      );
    }

    final spotsSuccess = List<FlSpot>.generate(
      performanceData.length,
      (index) => FlSpot(
        index.toDouble(),
        (performanceData[index]['success'] as num).toDouble(),
      ),
    );

    final spotsFailure = List<FlSpot>.generate(
      performanceData.length,
      (index) => FlSpot(
        index.toDouble(),
        (performanceData[index]['failure'] as num).toDouble(),
      ),
    );

    // Calculate dynamic Y scaling
    double maxY = 4;
    for (final item in performanceData) {
      final s = (item['success'] as num).toDouble();
      final f = (item['failure'] as num).toDouble();
      if (s > maxY) maxY = s;
      if (f > maxY) maxY = f;
    }
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY == 0) maxY = 4;

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (performanceData.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) {
                  return const FlLine(
                    color: AppColors.borderSoft,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  );
                },
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 4,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: AppTextStyles.caption,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: performanceData.length > 10 ? 5 : 1,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= performanceData.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s),
                        child: Text(
                          performanceData[index]['label']?.toString() ?? '',
                          style: AppTextStyles.caption,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: AppColors.surface,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final isSuccessSeries = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${isSuccessSeries ? "Thành công" : "Thất bại"}: ${spot.y.toInt()}',
                        AppTextStyles.captionBold.copyWith(
                          color: isSuccessSeries
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spotsSuccess,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
                LineChartBarData(
                  spots: spotsFailure,
                  isCurved: true,
                  color: AppColors.error,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(label: 'Gửi thành công', color: AppColors.primary),
            const SizedBox(width: AppSpacing.m),
            _buildLegendItem(label: 'Gửi thất bại', color: AppColors.error),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bắt đầu nhanh', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _columnsForWidth(constraints.maxWidth);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.m,
                  mainAxisSpacing: AppSpacing.m,
                  mainAxisExtent: 94,
                ),
                itemCount: MockCampaigns.quickActions.length,
                itemBuilder: (context, index) =>
                    _buildQuickActionCard(MockCampaigns.quickActions[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(QuickActionItem action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(action.route),
        borderRadius: AppSpacing.borderRadiusM,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.borderRadiusM,
            border: Border.all(color: AppColors.border),
            gradient: LinearGradient(
              colors: action.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                ),
                child: Icon(action.icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: action.titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      action.description,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hướng dẫn & Mẹo sử dụng nhanh',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _columnsForWidth(constraints.maxWidth);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.m,
                  mainAxisSpacing: AppSpacing.m,
                  mainAxisExtent: 104,
                ),
                itemCount: MockCampaigns.guideSteps.length,
                itemBuilder: (context, index) =>
                    _buildGuideStep(MockCampaigns.guideSteps[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(GuideStepItem step) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step.stepNumber,
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.primary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: AppTextStyles.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  step.description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _columnsForWidth(double width) {
    if (width >= 980) return 3;
    if (width >= 680) return 2;
    return 1;
  }
}

class _OperationMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OperationMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(value, style: AppTextStyles.sectionTitle.copyWith(color: color)),
        ],
      ),
    );
  }
}
