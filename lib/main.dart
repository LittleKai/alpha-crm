import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app/routing/app_router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/app_colors.dart';
import 'features/security/presentation/app_lock_overlay.dart';
import 'features/security/providers/app_lock_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'shared/utils/zalo_backend_manager.dart';
import 'shared/utils/desktop_window_manager.dart';
import 'shared/utils/desktop_notifier.dart';
import 'shared/utils/app_logger.dart';
import 'shared/widgets/backend_status_banner.dart';
import 'shared/widgets/backend_splash_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }

  // Cửa sổ + System Tray (Windows): maximize khi mở, nút X ẩn xuống tray.
  await DesktopShell.instance.init();

  // Thông báo desktop (Live Chat) — no-op trên web/mobile
  await DesktopNotifier.instance.init();

  // Khởi tạo Logger (ghi log ra file + console)
  final appLogger = AppLogger();
  await appLogger.init();

  // Bắt các lỗi liên quan đến UI/Framework của Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    appLogger.error('Flutter Framework Error', details.exception, details.stack);
    FlutterError.presentError(details); // Hiển thị lỗi ra UI (nếu trong debug)
  };

  // Bắt các lỗi Async / Logic Dart nằm ngoài UI
  PlatformDispatcher.instance.onError = (error, stack) {
    appLogger.error('Dart Unhandled Exception', error, stack);
    return true; // Ngăn không cho crash app nếu có thể
  };

  // Khởi động backend Zalo dưới quyền supervisor: tự khởi động lại khi chết,
  // có watchdog + circuit breaker. KHÔNG block boot — UI hiện ngay và phản ứng
  // theo trạng thái backend qua BackendStatusBanner.
  unawaited(ZaloBackendManager.startSupervised());

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

    // Set isDarkMode early so that the widget tree has the correct state during build evaluation
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    AppColors.isDarkMode = isDark;

    return MaterialApp.router(
      title: 'Alpha CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final currentIsDark = switch (themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        AppColors.isDarkMode = currentIsDark;
        return AppLockOverlay(
          child: BackendSplashOverlay(
            child: Column(
              children: [
                const BackendStatusBanner(),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            ),
          ),
        );
      },
    );
  }
}
