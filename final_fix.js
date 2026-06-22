const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', 'utf8');

// Ensure import is there
if (!code.includes('chatbot_provider.dart')) {
  code = code.replace(
    "import '../../../../shared/widgets/app_card.dart';",
    "import '../../../../shared/widgets/app_card.dart';\nimport '../../../messaging/chatbot/providers/chatbot_provider.dart';"
  );
}

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
              const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Thống kê phản hồi Chatbot & Token AI',
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
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.l,
            runSpacing: AppSpacing.s,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('AI phản hồi: \$totalAiUses ', style: AppTextStyles.captionBold.copyWith(color: AppColors.primary)),
                  Text('(Vào: \${_fmt(totalIn)} | Ra: \${_fmt(totalOut)})', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('Bỏ qua (Skip): \$totalSkipped', style: AppTextStyles.captionBold.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('Từ khóa: \$totalKeyword', style: AppTextStyles.captionBold.copyWith(color: const Color(0xFFF97316))),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            height: 240,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : enrichedPoints.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có dữ liệu thống kê trong khoảng thời gian này.',
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
                
                final isTokenIn = spot.barIndex == 0;
                
                if (isTokenIn) {
                  return LineTooltipItem(
                    'Token vào: \${_fmt(spot.y)}\\n\\nAI phản hồi: \${p.aiUses}\\nBỏ qua: \${p.skipped}\\nTừ khóa: \${p.keywordUses}',
                    AppTextStyles.captionBold.copyWith(color: AppColors.primary),
                  );
                } else {
                  return LineTooltipItem(
                    'Token ra: \${_fmt(spot.y)}',
                    AppTextStyles.captionBold.copyWith(color: AppColors.success),
                  );
                }
              }).toList().whereType<LineTooltipItem>().toList();
            },
          ),
        ),
        lineBarsData: [
          _line((p) => p.tokenIn, AppColors.primary, points),
          _line((p) => p.tokenOut, AppColors.success, points),
        ],
      ),
    );
  }`;

code = code.replace(/Widget build\(BuildContext context\) \{[\s\S]*?Widget _rangeChip\(int days, String label\)/m, newBuild + '\n\n  Widget _rangeChip(int days, String label)');

fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');