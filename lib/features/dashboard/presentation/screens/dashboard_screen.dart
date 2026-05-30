import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_campaigns.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tabs.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTab = 0;
  String _timeRange = '7 ngày qua';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          ResponsiveBreakpoints.isMobile(context) ? AppSpacing.m : AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.l),
            _buildPerformanceCard(),
            const SizedBox(height: AppSpacing.l),
            _buildQuickActionsSection(),
            const SizedBox(height: AppSpacing.l),
            _buildGuideSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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

  Widget _buildPerformanceCard() {
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
                    _buildChartControls(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: AppSpacing.m),
                  _buildChartControls(),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.l),
          SizedBox(height: 300, child: _buildZeroChart()),
        ],
      ),
    );
  }

  Widget _buildChartControls() {
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
        _buildRangeButtons(),
        _buildChartTotals(),
      ],
    );
  }

  Widget _buildRangeButtons() {
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
          _buildRangeButton('7 ngày qua'),
          _buildRangeButton('30 ngày qua'),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String label) {
    final selected = _timeRange == label;

    return InkWell(
      onTap: () {
        setState(() {
          _timeRange = label;
        });
      },
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

  Widget _buildChartTotals() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Thành công: ',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          '0',
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
          '0',
          style: AppTextStyles.captionBold.copyWith(color: AppColors.error),
        ),
      ],
    );
  }

  Widget _buildZeroChart() {
    final labels = _timeRange == '7 ngày qua'
        ? MockCampaigns.zeroChart7Days
        : MockCampaigns.zeroChart30Days;
    final spots = List<FlSpot>.generate(
      labels.length,
      (index) => FlSpot(index.toDouble(), 0),
    );

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (labels.length - 1).toDouble(),
              minY: 0,
              maxY: 4,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
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
                    interval: 1,
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
                    interval: 1,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s),
                        child: Text(
                          labels[index],
                          style: AppTextStyles.caption,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: AppColors.primary,
                  barWidth: 0,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: AppColors.error,
                  barWidth: 0,
                  dotData: const FlDotData(show: false),
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
