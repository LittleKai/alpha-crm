import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_crm/shared/utils/string_helper.dart';

void main() {
  test('toWellFormed extension test', () {
    const invalidString = 'Hello \uD800 World'; // unpaired high surrogate
    final wellFormed = invalidString.toWellFormed();
    expect(wellFormed, 'Hello \uFFFD World');

    const invalidString2 = 'Hello \uDC00 World'; // unpaired low surrogate
    final wellFormed2 = invalidString2.toWellFormed();
    expect(wellFormed2, 'Hello \uFFFD World');

    const validString = 'Hello 👋 World'; // valid surrogate pair (emoji)
    final wellFormed3 = validString.toWellFormed();
    expect(wellFormed3, validString);
  });
}
