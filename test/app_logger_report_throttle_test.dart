import 'package:alpha_crm/shared/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final logger = AppLogger();
  final t0 = DateTime(2026, 9, 5, 12, 0, 0);

  setUp(() => logger.resetReportThrottleForTest());

  test('chặn thông điệp trùng trong cửa sổ 10 giây', () {
    expect(logger.shouldReportForTest('boom', t0), isTrue);
    expect(
      logger.shouldReportForTest('boom', t0.add(const Duration(seconds: 9))),
      isFalse,
    );
    expect(
      logger.shouldReportForTest('boom', t0.add(const Duration(seconds: 11))),
      isTrue,
    );
  });

  test('thông điệp khác nhau không chặn nhau', () {
    expect(logger.shouldReportForTest('a', t0), isTrue);
    expect(logger.shouldReportForTest('b', t0), isTrue);
  });

  test('trần 20 lượt mỗi phút — một trận stderr không thành trận HTTP POST', () {
    for (var i = 0; i < 20; i++) {
      expect(
        logger.shouldReportForTest('lỗi-$i', t0.add(Duration(seconds: i))),
        isTrue,
        reason: 'lượt thứ $i phải được gửi',
      );
    }
    expect(
      logger.shouldReportForTest('lỗi-mới', t0.add(const Duration(seconds: 21))),
      isFalse,
    );
    // Qua khỏi cửa sổ 1 phút thì mở lại.
    expect(
      logger.shouldReportForTest('lỗi-sau', t0.add(const Duration(minutes: 2))),
      isTrue,
    );
  });
}
