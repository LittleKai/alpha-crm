import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_crm/app/theme/app_colors.dart';

void main() {
  test('ThemeColor value test', () {
    AppColors.isDarkMode = false;
    print('LIGHT MODE VALUE: ${AppColors.surface.value.toRadixString(16)}');
    AppColors.isDarkMode = true;
    print('DARK MODE VALUE: ${AppColors.surface.value.toRadixString(16)}');
    
    expect(AppColors.surface.value, AppColors.isDarkMode ? 0xFF111827 : 0xFFFFFFFF);
  });
}
