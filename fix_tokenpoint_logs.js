const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', 'utf8');

// Add import
if (!code.includes('chatbot_provider.dart')) {
  code = code.replace(
    "import '../../../../shared/widgets/app_card.dart';",
    "import '../../../../shared/widgets/app_card.dart';\nimport '../../../messaging/chatbot/providers/chatbot_provider.dart';"
  );
}

// Modify build method
const newBuild = `Widget build(BuildContext context) {
    final chatbotState = ref.watch(chatbotProvider);
    final logs = chatbotState.logs;

    // Group logs by yyyy-MM-dd
    final Map<String, Map<String, int>> logsByDate = {};
    for (final log in logs) {
      final dateKey = DateFormat('yyyy-MM-dd').format(log.timestamp);
      logsByDate.putIfAbsent(dateKey, () => {'ai': 0, 'skipped': 0, 'keyword': 0});
      
      if (log.status == 'skipped') {
        logsByDate[dateKey]!['skipped'] = logsByDate[dateKey]!['skipped']! + 1;
      } else if (log.keyword == 'ai' && log.status == 'succeeded') {
        logsByDate[dateKey]!['ai'] = logsByDate[dateKey]!['ai']! + 1;
      } else if (log.keyword == 'keyword') {
        logsByDate[dateKey]!['keyword'] = logsByDate[dateKey]!['keyword']! + 1;
      }
    }

    // Merge log stats into points
    final enrichedPoints = _points.map((p) {
      // The API returns 'date' typically as yyyy-MM-dd or ISO. Let's extract yyyy-MM-dd.
      String dateKey = p.date;
      final parsedDate = DateTime.tryParse(p.date);
      if (parsedDate != null) {
        dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);
      }
      final stats = logsByDate[dateKey] ?? {'ai': 0, 'skipped': 0, 'keyword': 0};
      
      return _TokenPoint(
        p.date,
        p.tokenIn,
        p.tokenOut,
        aiUses: stats['ai'] ?? 0,
        skipped: stats['skipped'] ?? 0,
        keywordUses: stats['keyword'] ?? 0,
      );
    }).toList();

    final totalIn = enrichedPoints.fold<double>(0, (s, p) => s + p.tokenIn);
    final totalOut = enrichedPoints.fold<double>(0, (s, p) => s + p.tokenOut);
    final totalAiUses = enrichedPoints.fold<int>(0, (s, p) => s + p.aiUses);
    final totalSkipped = enrichedPoints.fold<int>(0, (s, p) => s + p.skipped);
    final totalKeyword = enrichedPoints.fold<int>(0, (s, p) => s + p.keywordUses);

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
          Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.xs,
            children: [
              _legend(AppColors.primary, 'Token vào: \${_fmt(totalIn)}'),
              _legend(AppColors.success, 'Token ra: \${_fmt(totalOut)}'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                'AI phản hồi: \$totalAiUses',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Bỏ qua (Skip): \$totalSkipped',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Kịch bản từ khóa: \$totalKeyword',
                style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFFF97316),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: 240,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : enrichedPoints.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có dữ liệu token trong khoảng thời gian này.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : _chart(enrichedPoints),
          ),
        ],
      ),
    );
  }

  Widget _chart(List<_TokenPoint> points) {
    final maxY = points.fold<double>(
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
          horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.borderSoft, strokeWidth: 1, dashArray: [4, 4]),
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
              interval: maxY / 4 > 0 ? maxY / 4 : 1,
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
              interval: (points.length / 4).clamp(1, 999).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                final d = DateTime.tryParse(points[i].date);
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
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.surface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final i = spot.x.toInt();
                final p = (i >= 0 && i < points.length) ? points[i] : null;
                
                final isTokenIn = spot.barIndex == 0;
                String labelText = '\${isTokenIn ? "Token vào" : "Token ra"}: \${_fmt(spot.y)}';
                
                // Show extra stats on the first bar tooltip only so it's not duplicated
                if (isTokenIn && p != null) {
                  labelText += '\\n\\nAI: \${p.aiUses} | Bỏ qua: \${p.skipped} | Từ khóa: \${p.keywordUses}';
                }
                
                final textColor = isTokenIn ? AppColors.primary : AppColors.success;
                return LineTooltipItem(
                  labelText,
                  AppTextStyles.captionBold.copyWith(color: textColor),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          _line((p) => p.tokenIn, AppColors.primary, points),
          _line((p) => p.tokenOut, AppColors.success, points),
        ],
      ),
    );
  }

  LineChartBarData _line(double Function(_TokenPoint) sel, Color color, List<_TokenPoint> points) {
    return LineChartBarData(
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: points.length <= 14,
        getDotPainter: (spot, xPct, bar, idx) => FlDotCirclePainter(
          radius: 2.5,
          color: AppColors.surface,
          strokeColor: color,
          strokeWidth: 2,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
      spots: [
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), sel(points[i])),
      ],
    );
  }`;

code = code.replace(/Widget build\(BuildContext context\) \{[\s\S]*?Widget _rangeChip\(int days, String label\)/m, newBuild + '\n\n  Widget _rangeChip(int days, String label)');

fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');