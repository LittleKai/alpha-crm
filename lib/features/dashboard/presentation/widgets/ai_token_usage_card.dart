import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/api/crm_cloud_api.dart';
import '../../../../shared/widgets/app_card.dart';

/// Self-contained card showing daily AI token in/out usage (chatbot + summaries)
/// from `GET /crm/analytics/ai-tokens`. Hidden via the showTokenAnalytics setting.
class AiTokenUsageCard extends ConsumerStatefulWidget {
  const AiTokenUsageCard({super.key});

  @override
  ConsumerState<AiTokenUsageCard> createState() => _AiTokenUsageCardState();
}

class _TokenPoint {
  final String date;
  final double tokenIn;
  final double tokenOut;

  const _TokenPoint(this.date, this.tokenIn, this.tokenOut);
}

class _AiTokenUsageCardState extends ConsumerState<AiTokenUsageCard> {
  int _rangeDays = 30;
  bool _loading = true;
  List<_TokenPoint> _points = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final to = DateTime.now();
    final from = to.subtract(Duration(days: _rangeDays));
    final path = Uri(
      path: '/crm/analytics/ai-tokens',
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    ).toString();
    final res = await CrmCloudApi.get(path);
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _loading = false;
      if (res['success'] == true && data is List) {
        _points = data.whereType<Map>().map((m) {
          return _TokenPoint(
            (m['date'] ?? '').toString(),
            double.tryParse((m['tokenIn'] ?? 0).toString()) ?? 0,
            double.tryParse((m['tokenOut'] ?? 0).toString()) ?? 0,
          );
        }).toList();
      } else {
        _points = const [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalIn = _points.fold<double>(0, (s, p) => s + p.tokenIn);
    final totalOut = _points.fold<double>(0, (s, p) => s + p.tokenOut);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.toll_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Token AI sử dụng (chatbot + tóm tắt)',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              _rangeChip(7, '7 ngày'),
              const SizedBox(width: AppSpacing.xs),
              _rangeChip(30, '30 ngày'),
              const SizedBox(width: AppSpacing.xs),
              _rangeChip(90, '90 ngày'),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              _legend(AppColors.primary, 'Token vào: ${_fmt(totalIn)}'),
              const SizedBox(width: AppSpacing.m),
              _legend(AppColors.success, 'Token ra: ${_fmt(totalOut)}'),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: 240,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _points.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có dữ liệu token trong khoảng thời gian này.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : _chart(),
          ),
        ],
      ),
    );
  }

  Widget _chart() {
    final maxY = _points.fold<double>(
      1,
      (m, p) => [m, p.tokenIn, p.tokenOut].reduce((a, b) => a > b ? a : b),
    );
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.borderSoft, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                _fmt(value),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (_points.length / 4).clamp(1, 999).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _points.length) {
                  return const SizedBox.shrink();
                }
                final d = DateTime.tryParse(_points[i].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    d == null ? '' : DateFormat('dd/MM').format(d),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _line((p) => p.tokenIn, AppColors.primary),
          _line((p) => p.tokenOut, AppColors.success),
        ],
      ),
    );
  }

  LineChartBarData _line(double Function(_TokenPoint) sel, Color color) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      spots: [
        for (int i = 0; i < _points.length; i++)
          FlSpot(i.toDouble(), sel(_points[i])),
      ],
    );
  }

  Widget _rangeChip(int days, String label) {
    final selected = _rangeDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        if (_rangeDays != days) {
          setState(() => _rangeDays = days);
          _load();
        }
      },
      selectedColor: AppColors.primarySoft,
      labelStyle: AppTextStyles.caption.copyWith(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
