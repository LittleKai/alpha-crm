const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', 'utf8');

const newChart = `  Widget _chart(List<_TokenPoint> points) {
    final maxY = points.fold<double>(
      1,
      (m, p) => [m, p.aiUses.toDouble(), p.skipped.toDouble(), p.keywordUses.toDouble()].reduce((a, b) => a > b ? a : b),
    );
    
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxY * 1.25).ceilToDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4) > 0 ? (maxY / 4) : 1,
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
              interval: (maxY / 4) > 0 ? (maxY / 4) : 1,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
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
                  padding: const EdgeInsets.only(top: 8),
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
                if (p == null) return null;
                
                if (spot.barIndex == 0) {
                  return LineTooltipItem(
                    'AI phản hồi: \${spot.y.toInt()}\\nToken vào: \${_fmt(p.tokenIn)} | Token ra: \${_fmt(p.tokenOut)}',
                    AppTextStyles.captionBold.copyWith(color: AppColors.primary),
                  );
                } else if (spot.barIndex == 1) {
                  return LineTooltipItem(
                    'Bỏ qua: \${spot.y.toInt()}',
                    AppTextStyles.captionBold.copyWith(color: AppColors.textSecondary),
                  );
                } else {
                  return LineTooltipItem(
                    'Từ khóa: \${spot.y.toInt()}',
                    AppTextStyles.captionBold.copyWith(color: const Color(0xFFF97316)),
                  );
                }
              }).toList().whereType<LineTooltipItem>().toList();
            },
          ),
        ),
        lineBarsData: [
          _line((p) => p.aiUses.toDouble(), AppColors.primary, points),
          _line((p) => p.skipped.toDouble(), AppColors.textSecondary, points),
          _line((p) => p.keywordUses.toDouble(), const Color(0xFFF97316), points),
        ],
      ),
    );
  }`;

code = code.replace(/Widget _chart\(List<_TokenPoint> points\) \{[\s\S]*?lineBarsData: \[\s*_line\(\(p\) => p\.tokenIn, AppColors\.primary, points\),\s*_line\(\(p\) => p\.tokenOut, AppColors\.success, points\),\s*\],\s*\),\s*\);\s*\}/m, newChart);

// If the regex above fails because the current signature is _chart() instead of _chart(List<_TokenPoint> points)
// I will replace it generally.
code = code.replace(/Widget _chart\([\s\S]*?lineBarsData: \[[\s\S]*?\],\s*\),\s*\);\s*\}/m, newChart);

fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');