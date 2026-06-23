double readDashboardMetric(Map<dynamic, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

List<double> normalizeDailySeries(
  List<num> values, {
  required int? rangeTotal,
}) {
  final original = values.map((value) => value.toDouble()).toList();
  if (original.length < 2 || rangeTotal == null || rangeTotal < 0) {
    return original;
  }

  final last = original.last.round();
  if (last != rangeTotal) return original;

  for (var i = 1; i < original.length; i++) {
    if (original[i] < original[i - 1]) return original;
  }

  final daily = <double>[];
  var previous = 0.0;
  for (final current in original) {
    daily.add((current - previous).clamp(0, double.infinity).toDouble());
    previous = current;
  }
  return daily;
}

List<Map<String, dynamic>> mergeChatbotStatsIntoPerformanceData(
  List<dynamic> performanceData,
  List<Map<String, dynamic>> chatbotStats,
) {
  final statsByDate = <String, Map<String, dynamic>>{};
  final statsByLabel = <String, Map<String, dynamic>>{};
  for (final stat in chatbotStats) {
    final date = (stat['date'] ?? '').toString();
    if (date.isEmpty) continue;
    statsByDate[date] = stat;
    statsByLabel[_labelFromDateKey(date)] = stat;
  }

  if (performanceData.isEmpty) {
    return chatbotStats.map((stat) {
      final date = (stat['date'] ?? '').toString();
      return <String, dynamic>{
        'date': date,
        'label': _labelFromDateKey(date),
        'success': 0,
        'failure': 0,
        'friendSuccess': 0,
        'friendFailure': 0,
        'responses': _chatbotResponseCount(stat),
      };
    }).toList();
  }

  return performanceData.whereType<Map>().map((item) {
    final row = Map<String, dynamic>.from(item);
    final date = (row['date'] ?? row['day'] ?? '').toString();
    final label = (row['label'] ?? '').toString();
    final stat = statsByDate[date] ?? statsByLabel[label];
    if (stat != null) {
      row['responses'] = _chatbotResponseCount(stat);
    }
    return row;
  }).toList();
}

/// Injects local friend-add daily counts into the campaign performance rows.
///
/// Friend requests run against the local Zalo backend and are only persisted
/// in the local `friend_history` table — they never reach the cloud
/// `CrmExecutionLog`, so the cloud campaign-performance payload always reports
/// 0 for the friend series. We merge the same local history the Friend History
/// tab uses, keyed by `yyyy-MM-dd` (matching the cloud row `date`).
List<Map<String, dynamic>> mergeFriendStatsIntoPerformanceData(
  List<Map<String, dynamic>> performanceData,
  List<Map<String, dynamic>> friendStats,
) {
  final statsByDate = <String, Map<String, dynamic>>{};
  final statsByLabel = <String, Map<String, dynamic>>{};
  for (final stat in friendStats) {
    final date = (stat['date'] ?? '').toString();
    if (date.isEmpty) continue;
    statsByDate[date] = stat;
    statsByLabel[_labelFromDateKey(date)] = stat;
  }

  if (statsByDate.isEmpty) return performanceData;

  return performanceData.map((item) {
    final row = Map<String, dynamic>.from(item);
    final date = (row['date'] ?? row['day'] ?? '').toString();
    final label = (row['label'] ?? '').toString();
    final stat = statsByDate[date] ?? statsByLabel[label];
    if (stat != null) {
      row['friendSuccess'] =
          readDashboardMetric(stat, const ['friendSuccess']).round();
      row['friendFailure'] =
          readDashboardMetric(stat, const ['friendFailure']).round();
    }
    return row;
  }).toList();
}

int _chatbotResponseCount(Map<String, dynamic> stat) {
  return (readDashboardMetric(stat, const ['aiUses', 'ai', 'ai_uses']) +
          readDashboardMetric(stat, const [
            'keywordUses',
            'keyword',
            'keyword_uses',
          ]))
      .round();
}

String _labelFromDateKey(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length != 3) return dateKey;
  return '${parts[2]}/${parts[1]}';
}
