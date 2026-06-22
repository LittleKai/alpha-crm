const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', 'utf8');

const newBuild = `Widget build(BuildContext context) {
    final totalIn = _points.fold<double>(0, (s, p) => s + p.tokenIn);
    final totalOut = _points.fold<double>(0, (s, p) => s + p.tokenOut);
    final totalAiUses = _points.fold<int>(0, (s, p) => s + p.aiUses);
    final totalSkipped = _points.fold<int>(0, (s, p) => s + p.skipped);
    final totalKeyword = _points.fold<int>(0, (s, p) => s + p.keywordUses);

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
                  Text('Bỏ qua: \$totalSkipped', style: AppTextStyles.captionBold.copyWith(color: AppColors.textSecondary)),
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
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: 240,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _points.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có dữ liệu thống kê trong khoảng thời gian này.',
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
              interval: (_points.length / 4).clamp(1, 999).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _points.length) {
                  return const SizedBox.shrink();
                }
                final d = DateTime.tryParse(_points[i].date);
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
                final p = (i >= 0 && i < _points.length) ? _points[i] : null;
                if (p == null) return null;
                
                if (spot.barIndex == 0) {
                  // Token In tooltip
                  return LineTooltipItem(
                    'Token vào: \${_fmt(spot.y)}\\n\\nAI phản hồi: \${p.aiUses}\\nBỏ qua: \${p.skipped}\\nTừ khóa: \${p.keywordUses}',
                    AppTextStyles.captionBold.copyWith(color: AppColors.primary),
                  );
                } else {
                  // Token Out tooltip
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
          _line((p) => p.tokenIn, AppColors.primary),
          _line((p) => p.tokenOut, AppColors.success),
        ],
      ),
    );
  }`;

code = code.replace(/Widget build\(BuildContext context\) \{[\s\S]*?Widget _rangeChip\(int days, String label\)/m, newBuild + '\n\n  Widget _rangeChip(int days, String label)');

// Strip out the manual log parsing logic from load() or build() if I left any.
// The original `_load()` was just setting `_points` from API. We need to make sure `_load()` is pristine.
// Wait, my previous script modified `build()` but `_load()` was untouched! So `_load()` still reads from API!
// I just need to make sure the build method doesn't reference `logsByDate`. The `newBuild` above doesn't use `logsByDate`, it uses `_points` directly!
fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');