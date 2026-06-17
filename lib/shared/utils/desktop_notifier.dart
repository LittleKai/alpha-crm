import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// Thin wrapper around `local_notifier` for desktop toast notifications.
/// No-op on web and mobile (the package only supports Windows/macOS/Linux).
class DesktopNotifier {
  DesktopNotifier._();
  static final DesktopNotifier instance = DesktopNotifier._();

  bool _ready = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await localNotifier.setup(
        appName: 'Alpha CRM',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> show(String title, String body) async {
    if (!_supported || !_ready) return;
    try {
      final notification = LocalNotification(
        title: title,
        body: body.isEmpty ? ' ' : body,
      );
      await notification.show();
    } catch (_) {
      // Notifications are best-effort; never break the chat flow.
    }
  }
}
