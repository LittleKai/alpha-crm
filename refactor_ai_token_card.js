const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', 'utf8');

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
              _legend(
                AppColors.primary, 
                'AI phản hồi: \$totalAiUses (Tổng Token: \${_fmt(totalIn + totalOut)})'
              ),
              _legend(AppColors.textSecondary, 'Bỏ qua (Skip): \$totalSkipped'),
              _legend(const Color(0xFFF97316), 'Kịch bản từ khóa: \$totalKeyword'),
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
              reservedSize: 32,
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
                    'AI phản hồi: \${spot.y.toInt()}\\nToken: \${_fmt(p.tokenIn + p.tokenOut)}',
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

code = code.replace(/Widget build\(BuildContext context\) \{[\s\S]*?Widget _rangeChip\(int days, String label\)/m, newBuild + '\n\n  Widget _rangeChip(int days, String label)');

fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');