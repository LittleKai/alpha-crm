import 'package:alpha_crm/shared/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

String logName(int day) =>
    'app_log_2026-09-${day.toString().padLeft(2, '0')}T10-00-00.000.txt';

void main() {
  test('không xoá gì khi còn dưới hạn mức', () {
    final names = List.generate(5, (i) => logName(i + 1));
    expect(AppLogger.logFilesToPrune(names, keep: 20), isEmpty);
  });

  test('xoá file cũ nhất trước, giữ đúng số lượng mới nhất', () {
    final names = List.generate(25, (i) => logName(i + 1));
    final pruned = AppLogger.logFilesToPrune(names, keep: 20);

    expect(pruned.length, 5);
    expect(pruned.first, logName(1));
    expect(pruned.last, logName(5));
    // Không được đụng tới file mới nhất.
    expect(pruned.contains(logName(25)), isFalse);
  });

  test('bỏ qua file không phải log của app', () {
    final names = [
      ...List.generate(22, (i) => logName(i + 1)),
      'crm_token.json',
      'app_log_readme.md',
      'notes.txt',
    ];
    final pruned = AppLogger.logFilesToPrune(names, keep: 20);

    expect(pruned.length, 2);
    expect(pruned.every((n) => n.startsWith('app_log_') && n.endsWith('.txt')), isTrue);
    expect(pruned.contains('crm_token.json'), isFalse);
    expect(pruned.contains('notes.txt'), isFalse);
  });
}
