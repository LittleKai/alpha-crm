import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobileMax = 649.0;
  static const double tabletMin = 650.0;
  static const double tabletMax = 1099.0;
  static const double desktopMin = 1100.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= mobileMax;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMin && width <= tabletMax;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopMin;
  }

  static T select<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopMin) return desktop;
    if (width >= tabletMin) return tablet;
    return mobile;
  }
}
