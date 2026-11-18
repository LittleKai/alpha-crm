import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../../mock/mock_accounts.dart';

const double kSidebarMinWidth = SystemSettings.minSidebarWidth;
const double kSidebarMaxWidth = SystemSettings.maxSidebarWidth;
const double kSidebarDefaultWidth = SystemSettings.defaultSidebarWidth;
const double kSidebarCollapsedWidth = 56.0;
const double kAppFrameHeaderHeight = 48.0;

final sidebarCollapsedProvider = StateProvider<bool>(
  (ref) => ref.read(settingsProvider).settings.sidebarCollapsed,
);

final sidebarWidthProvider = StateProvider<double>(
  (ref) => ref.read(settingsProvider).settings.sidebarWidth,
);

void persistSidebarCollapsed(WidgetRef ref, bool collapsed) {
  ref.read(sidebarCollapsedProvider.notifier).state = collapsed;
  unawaited(
    ref.read(settingsProvider.notifier).setSidebarPreferences(collapsed: collapsed),
  );
}

void persistSidebarWidth(WidgetRef ref, double width, {bool saveToDisk = true}) {
  final clamped = SystemSettings.clampSidebarWidth(width);
  ref.read(sidebarWidthProvider.notifier).state = clamped;
  if (saveToDisk) {
    unawaited(
      ref.read(settingsProvider.notifier).setSidebarPreferences(width: clamped),
    );
  }
}
