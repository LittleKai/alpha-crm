import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/routing/app_router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/app_colors.dart';
import 'features/security/presentation/app_lock_overlay.dart';
import 'features/security/providers/app_lock_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'shared/utils/zalo_backend_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tự động chạy Zalo Bot backend khi chạy trên máy tính (Desktop)
  await ZaloBackendManager.startBackend();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appLockProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ZaloBackendManager.stopBackend();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      ZaloBackendManager.stopBackend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = switch (ref
        .watch(settingsProvider)
        .settings
        .appThemeMode) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    return MaterialApp.router(
      title: 'Alpha CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final isDark = switch (themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        AppColors.isDarkMode = isDark;
        return AppLockOverlay(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
