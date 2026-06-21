import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_crm/app/theme/app_colors.dart';

void main() {
  testWidgets('ThemeColor widget paint test', (tester) async {
    AppColors.isDarkMode = true;
    
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
          ),
        ),
      ),
    );
    
    final container = tester.widget<Container>(find.byType(Container));
    final boxDecoration = container.decoration as BoxDecoration?;
    print('DECORATION COLOR VALUE: ${boxDecoration?.color?.toARGB32().toRadixString(16)}');
    
    expect(boxDecoration?.color?.toARGB32(), 0xFF111827);
  });
}
