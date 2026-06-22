import re

file_path = r'D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\lib\features\dashboard\presentation\screens\dashboard_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if "import 'package:syncfusion_flutter_charts/charts.dart';" not in content:
    content = content.replace("import 'package:fl_chart/fl_chart.dart';", "import 'package:fl_chart/fl_chart.dart';\nimport 'package:syncfusion_flutter_charts/charts.dart';")

start_idx = content.find("  Widget _buildCampaignStatusSection(DashboardState state) {")
end_idx = content.find("  Widget _buildQuickActionsSection() {")

if start_idx != -1 and end_idx != -1:
    new_section = '''  Widget _buildCampaignStatusAndPerformance(DashboardState state) {
    final campaignStats = _safeMap(state.overview?['campaignStats']);
    var byStatus = _safeMap(campaignStats['byStatus']);
    if (byStatus.isEmpty) {
      byStatus = const {
        'running': 0,
        'completed': 0,
        'draft': 0,
        'paused': 0,
        'scheduled': 0,
      };
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final children = [
          _buildCampaignStatusDonut(byStatus),
          _buildRecentPerformanceBarChart(state),
        ];
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: AppSpacing.l),
              Expanded(child: children[1]),
            ],
          );
        }
        return Column(
          children: [
            children[0],
            const SizedBox(height: AppSpacing.l),
            children[1],
          ],
        );
      },
    );
  }

  // --- Campaign Status Donut Chart ---
  Widget _buildCampaignStatusDonut(Map<String, dynamic> byStatus) {
    String mapLabel(String s) {
      switch (s.toLowerCase()) {
        case 'running': return 'Đang chạy';
        case 'completed': return 'Hoàn thành';
        case 'draft': return 'Nháp';
        case 'paused': return 'Tạm dừng';
        case 'scheduled': return 'Lên lịch';
        case 'failed': return 'Thất bại';
        case 'stopped': return 'Đã dừng';
        case 'pending': return 'Đang chờ';
        case 'active': return 'Hoạt động';
        case 'cancelled': return 'Bị hủy';
        default: return s;
      }
    }

    Color statusColor(String s) {
      switch (s.toLowerCase()) {
        case 'running': return AppColors.primary;
        case 'completed': return AppColors.success;
        case 'draft': return AppColors.textSecondary;
        case 'paused': return AppColors.warning;
        case 'scheduled': return AppColors.info;
        case 'failed': return AppColors.error;
        case 'stopped': return AppColors.error;
        case 'pending': return AppColors.warning;
        case 'active': return AppColors.success;
        case 'cancelled': return AppColors.disabledText;
        default: return AppColors.textSecondary;
      }
    }

    final entries = byStatus.entries
        .map((e) => MapEntry(e.key, _safeInt(e.value)))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (s, e) => s + e.value);

    return AppCard(
      key: const ValueKey('dashboard_status_donut'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trạng thái chiến dịch', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: entries.isEmpty
                      ? SfCircularChart(
                          margin: EdgeInsets.zero,
                          series: <CircularSeries>[
                            DoughnutSeries<int, String>(
                              dataSource: [1],
                              xValueMapper: (int data, _) => '',
                              yValueMapper: (int data, _) => data,
                              pointColorMapper: (int data, _) => AppColors.border,
                              innerRadius: '75%',
                              radius: '100%',
                            )
                          ],
                          annotations: <CircularChartAnnotation>[
                            CircularChartAnnotation(
                              widget: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '0',
                                    style: AppTextStyles.pageTitle.copyWith(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'chiến dịch',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        )
                      : SfCircularChart(
                          margin: EdgeInsets.zero,
                          series: <CircularSeries>[
                            DoughnutSeries<MapEntry<String, int>, String>(
                              dataSource: entries,
                              xValueMapper: (MapEntry<String, int> data, _) => data.key,
                              yValueMapper: (MapEntry<String, int> data, _) => data.value,
                              pointColorMapper: (MapEntry<String, int> data, _) => statusColor(data.key),
                              innerRadius: '75%',
                              radius: '100%',
                            )
                          ],
                          annotations: <CircularChartAnnotation>[
                            CircularChartAnnotation(
                              widget: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    total.toString(),
                                    style: AppTextStyles.pageTitle.copyWith(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'chiến dịch',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entries.isEmpty)
                        Text(
                          'Chưa có chiến dịch',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                        )
                      else
                        ...entries.map((e) {
                          final color = statusColor(e.key);
                          final pct = total > 0
                              ? (e.value / total * 100).toStringAsFixed(0)
                              : '0';
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                  child: Text(
                                    mapLabel(e.key),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  e.value.toString(),
                                  style: AppTextStyles.captionBold.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    pct + '%',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Recent Performance Bar Chart ---
  Widget _buildRecentPerformanceBarChart(DashboardState state) {
    final recentPerformance = _safeList(state.performanceData);
    // Take only latest 7 entries for readability
    final data = recentPerformance.length > 7
        ? recentPerformance.sublist(recentPerformance.length - 7)
        : List<dynamic>.from(recentPerformance);

    int totalSuccess = 0;
    int totalFailure = 0;
    double maxY = 4;

    final List<Map<String, dynamic>> chartData = [];
    for (int i = 0; i < data.length; i++) {
      final item = _safeMap(data[i]);
      final success = _safeInt(item['success']);
      final failure = _safeInt(item['failure']);
      final label = item['label']?.toString() ?? '';
      totalSuccess += success;
      totalFailure += failure;
      
      chartData.add({
        'index': i,
        'label': label,
        'success': success,
        'failure': failure,
      });

      final sum = (success + failure).toDouble();
      if (sum > maxY) maxY = sum;
    }
    maxY = (maxY * 1.25).ceilToDouble();
    if (maxY == 0) maxY = 4;

    return AppCard(
      key: const ValueKey('dashboard_recent_performance_bar'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hiệu suất gần đây',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              _buildLegendItem(label: 'Thành công', color: AppColors.primary),
              const SizedBox(width: AppSpacing.m),
              _buildLegendItem(
                label: 'Thất bại',
                color: AppColors.error.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                'Thành công: ' + totalSuccess.toString(),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Thất bại: ' + totalFailure.toString(),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: 200,
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có dữ liệu gửi tin gần đây.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : SfCartesianChart(
                    margin: EdgeInsets.zero,
                    plotAreaBorderWidth: 0,
                    primaryXAxis: CategoryAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                      axisLine: const AxisLine(width: 0),
                      labelStyle: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                    primaryYAxis: NumericAxis(
                      minimum: 0,
                      maximum: maxY,
                      interval: maxY / 4,
                      majorGridLines: MajorGridLines(
                        color: AppColors.borderSoft,
                        dashArray: const <double>[4, 4],
                      ),
                      axisLine: const AxisLine(width: 0),
                      labelStyle: AppTextStyles.caption,
                    ),
                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                      color: AppColors.surface,
                      textStyle: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary),
                      builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                        final isSuccess = seriesIndex == 0;
                        final val = isSuccess ? data['success'] : data['failure'];
                        final color = isSuccess ? AppColors.primary : AppColors.error.withValues(alpha: 0.7);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            (isSuccess ? 'Thành công: ' : 'Thất bại: ') + val.toString(),
                            style: AppTextStyles.captionBold.copyWith(color: color),
                          ),
                        );
                      },
                    ),
                    series: <CartesianSeries>[
                      ColumnSeries<Map<String, dynamic>, String>(
                        dataSource: chartData,
                        xValueMapper: (Map<String, dynamic> data, _) => data['label'] as String,
                        yValueMapper: (Map<String, dynamic> data, _) => data['success'] as int,
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        width: 0.4,
                        spacing: 0.1,
                      ),
                      ColumnSeries<Map<String, dynamic>, String>(
                        dataSource: chartData,
                        xValueMapper: (Map<String, dynamic> data, _) => data['label'] as String,
                        yValueMapper: (Map<String, dynamic> data, _) => data['failure'] as int,
                        color: AppColors.error.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        width: 0.4,
                        spacing: 0.1,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

'''
    
    content = content[:start_idx] + new_section + content[end_idx:]
    content = content.replace("_buildCampaignStatusSection(state)", "_buildCampaignStatusAndPerformance(state)")

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replace done.")
else:
    print("Indexes not found!")
