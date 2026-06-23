import 'package:alpha_crm/features/dashboard/utils/dashboard_chart_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merges chatbot daily stats without fabricating totals', () {
    final rows = mergeChatbotStatsIntoPerformanceData(
      [
        {'date': '2026-06-20', 'label': '20/06', 'success': 2},
        {'date': '2026-06-21', 'label': '21/06', 'success': 3},
      ],
      [
        {'date': '2026-06-20', 'aiUses': 1, 'keywordUses': 2, 'skipped': 9},
        {'date': '2026-06-21', 'aiUses': 0, 'keywordUses': 4, 'skipped': 3},
      ],
    );

    expect(rows[0]['responses'], 3);
    expect(rows[1]['responses'], 4);
  });

  test('does not distribute chatbot total when daily stats are empty', () {
    final rows = mergeChatbotStatsIntoPerformanceData([
      {'date': '2026-06-20', 'label': '20/06', 'responses': 0},
      {'date': '2026-06-21', 'label': '21/06', 'responses': 0},
    ], const []);

    expect(rows.map((row) => row['responses']), [0, 0]);
  });

  test('merges local friend daily stats into the friend series', () {
    final rows = mergeFriendStatsIntoPerformanceData(
      [
        {'date': '2026-06-20', 'label': '20/06', 'success': 2},
        {'date': '2026-06-21', 'label': '21/06', 'success': 3},
      ],
      [
        {'date': '2026-06-20', 'friendSuccess': 4, 'friendFailure': 1},
        {'date': '2026-06-21', 'friendSuccess': 0, 'friendFailure': 2},
      ],
    );

    expect(rows[0]['friendSuccess'], 4);
    expect(rows[0]['friendFailure'], 1);
    expect(rows[1]['friendSuccess'], 0);
    expect(rows[1]['friendFailure'], 2);
  });

  test('leaves performance rows untouched when no friend stats exist', () {
    final rows = mergeFriendStatsIntoPerformanceData([
      {'date': '2026-06-20', 'label': '20/06', 'success': 1},
    ], const []);

    expect(rows[0].containsKey('friendSuccess'), false);
  });

  test(
    'converts cumulative message series only when final point matches total',
    () {
      expect(normalizeDailySeries([1, 3, 6, 10], rangeTotal: 10), [1, 2, 3, 4]);
      expect(normalizeDailySeries([1, 3, 6, 10], rangeTotal: 99), [
        1,
        3,
        6,
        10,
      ]);
    },
  );
}
