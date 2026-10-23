import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_crm/app/theme/app_colors.dart';

void main() {
  test('ThemeColor value test', () {
    AppColors.isDarkMode = false;
    debugPrint('LIGHT MODE VALUE: ${AppColors.surface.toARGB32().toRadixString(16)}');
    AppColors.isDarkMode = true;
    debugPrint('DARK MODE VALUE: ${AppColors.surface.toARGB32().toRadixString(16)}');

    expect(AppColors.surface.toARGB32(), AppColors.isDarkMode ? 0xFF111827 : 0xFFFFFFFF);
  });
}
