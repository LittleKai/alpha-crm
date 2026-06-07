import 'package:alpha_crm/shared/utils/zalo_text_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves Vietnamese placeholders and deterministic spintax', () {
    final result = ZaloTextFormatter.resolveVariablesAndSpintax(
      '{{tên}} {{sdt}} {{nhóm}} {A|B|C}',
      name: 'Nguyễn An',
      phone: '0901234567',
      group: 'Nhóm Demo',
      randomizeSpintax: false,
    );

    expect(result, 'Nguyễn An 0901234567 Nhóm Demo A');
  });

  test('renders Zalo preview without leaking formatting markers', () {
    final result = ZaloTextFormatter.renderZaloPreview(
      '**xin chào** *bạn* __hôm nay__~~ thế nào~~ {{tên}}{{sdt}}{{nhóm}}{A|B|C}',
      name: 'Nguyễn An',
      phone: '0901234567',
      group: 'Nhóm Demo',
    );

    expect(result, contains('Nguyễn An0901234567Nhóm DemoA'));
    expect(result, isNot(contains('**')));
    expect(result, isNot(contains('__')));
    expect(result, isNot(contains('~~')));
    expect(result, contains('\u0332'));
    expect(result, contains('\u0336'));
  });
}
