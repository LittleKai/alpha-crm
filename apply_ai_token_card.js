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
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.surface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isTokenIn = spot.barIndex == 0;
                final labelText = \`\${isTokenIn ? "Token vào" : "Token ra"}: \${_fmt(spot.y)}\`;
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
          _line((p) => p.tokenIn, AppColors.primary),
          _line((p) => p.tokenOut, AppColors.success),
        ],
      ),
    );
  }`;

code = code.replace(/Widget build\(BuildContext context\) \{[\s\S]*?lineBarsData: \[\r?\n\s*_line\(\(p\) => p\.tokenIn, AppColors\.primary\),\r?\n\s*_line\(\(p\) => p\.tokenOut, AppColors\.success\),\r?\n\s*\],\r?\n\s*\),\r?\n\s*\);[\r\n\s]*\}/m, newBuild);

fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');