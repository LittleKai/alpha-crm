const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', 'utf8');

const newLineFunc = `
  LineChartBarData _line(double Function(_TokenPoint) sel, Color color) {
    return LineChartBarData(
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: _points.length <= 14,
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
        for (int i = 0; i < _points.length; i++)
          FlSpot(i.toDouble(), sel(_points[i])),
      ],
    );
  }

  Widget _rangeChip`;

code = code.replace(/Widget _rangeChip/m, newLineFunc);

// remove unused import
code = code.replace(/import '\.\.\/\.\.\/\.\.\/messaging\/chatbot\/providers\/chatbot_provider\.dart';\r?\n/, '');

// remove _legend
code = code.replace(/Widget _legend\([\s\S]*?\}\r?\n\r?\n/, '');

fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');