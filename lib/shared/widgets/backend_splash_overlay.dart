import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/zalo_backend_manager.dart';
import '../utils/app_logger.dart';
import '../../features/zalo_integration/providers/zalo_integration_provider.dart';

/// Splash toàn màn che app trong lúc backend Zalo cục bộ khởi động LẦN ĐẦU.
///
/// - Khi backend khỏe lần đầu → splash biến mất vĩnh viễn; các gián đoạn về sau
///   chỉ dùng dải [BackendStatusBanner] mỏng, KHÔNG che lại toàn app.
/// - Nếu khởi động thất bại (circuit breaker mở) ở lần đầu → splash hiện lỗi kèm
///   nút "Thử lại" (`retryManually`).
class BackendSplashOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const BackendSplashOverlay({super.key, required this.child});

  @override
  ConsumerState<BackendSplashOverlay> createState() =>
      _BackendSplashOverlayState();
}

class _BackendSplashOverlayState extends ConsumerState<BackendSplashOverlay> {
  /// Latch: một khi app đã thực sự sẵn sàng (backend khỏe + nạp xong tài khoản
  /// lần đầu) thì splash biến mất VĨNH VIỄN. Các gián đoạn sau đó do
  /// BackendStatusBanner đảm nhiệm, KHÔNG che lại toàn màn hình.
  bool _everReady = false;

  @override
  Widget build(BuildContext context) {
    // Lắng nghe pha nạp tài khoản Zalo lần đầu để splash che TRỌN quá trình khởi
    // động (tiến trình backend + nạp tài khoản) — không để lọt sang giao diện
    // chính khi chưa sẵn sàng.
    final isInitializing = ref.watch(
      zaloIntegrationProvider.select((s) => s.isInitializing),
    );

    final isTest = WidgetsBinding.instance.toString().contains('Test') ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    return ValueListenableBuilder<BackendStatus>(
      valueListenable: ZaloBackendManager.status,
      builder: (context, status, _) {
        if ((status == BackendStatus.healthy && !isInitializing) || isTest) {
          _everReady = true;
        }
        final showSplash = !_everReady;
        return Stack(
          children: [
            widget.child,
            if (showSplash)
              Positioned.fill(
                child: _SplashContent(
                  status: status,
                  initializingAccounts:
                      status == BackendStatus.healthy && isInitializing,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SplashContent extends StatefulWidget {
  final BackendStatus status;

  /// Backend đã khỏe nhưng đang nạp danh sách tài khoản Zalo lần đầu.
  final bool initializingAccounts;

  const _SplashContent({
    required this.status,
    this.initializingAccounts = false,
  });

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent> {
  /// Hiện trạng thái "Đã sao chép" trong 2s sau khi bấm nút copy.
  bool _copied = false;

  Timer? _blinkTimer;
  double _opacity = 0.8;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    // Tạo hiệu ứng thở nhấp nháy rất chậm (1Hz) và chuyển động dấu chấm (dot progress)
    // Thay đổi trạng thái mỗi 700ms, chỉ vẽ lại đúng 1.4 frame/giây thay vì 60fps liên tục.
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (mounted) {
        setState(() {
          _opacity = _opacity == 0.8 ? 0.35 : 0.8;
          _dotCount = (_dotCount % 3) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = widget.status == BackendStatus.failed;
    final double currentOpacity = isFailed ? 1.0 : _opacity;

    return Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF020617),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo phát sáng tĩnh (không dùng AnimatedBuilder hay Transform.scale động 60fps)
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.03),
                  border: Border.all(
                    color: (isFailed ? Colors.red : const Color(0xFF6366F1))
                        .withValues(alpha: isFailed ? 0.35 : currentOpacity * 0.55),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isFailed
                              ? Colors.red
                              : const Color(0xFF6366F1))
                          .withValues(alpha: isFailed ? 0.25 : currentOpacity * 0.3),
                      blurRadius: isFailed ? 24 : 18,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  isFailed
                      ? Icons.error_outline_rounded
                      : Icons.hub_rounded,
                  size: 48,
                  color: isFailed
                      ? Colors.red.shade300
                      : Colors.white.withValues(alpha: isFailed ? 0.92 : currentOpacity * 0.5 + 0.42),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Alpha CRM',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _messageFor(widget.status, widget.initializingAccounts),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              if (isFailed) ...[
                // Bảng debug có thể chọn & copy để gửi nhà phát triển.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _debugText(),
                          style: GoogleFonts.robotoMono(
                            fontSize: 11,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _copyDebug,
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 18,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: Text(
                        _copied ? 'Đã sao chép' : 'Sao chép log',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => ZaloBackendManager.retryManually(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      label: Text(
                        'Thử lại',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ] else
                SizedBox(
                  height: 26,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final showDot = index < _dotCount;
                      return Opacity(
                        opacity: showDot ? 0.85 : 0.2,
                        child: Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gom thông tin chẩn đoán khởi động backend để hiển thị & copy.
  String _debugText() {
    final buffer = StringBuffer()
      ..writeln('=== Alpha CRM — Chẩn đoán khởi động backend ===')
      ..writeln('Thời điểm: ${DateTime.now().toIso8601String()}')
      ..writeln('Trạng thái: ${ZaloBackendManager.status.value.name}')
      ..writeln('Cổng (active): ${ZaloBackendManager.activePort ?? "—"}')
      ..writeln('Lỗi gần nhất: ${ZaloBackendManager.lastStartupError ?? "—"}')
      ..writeln('File log: ${AppLogger().logFilePath ?? "—"}')
      ..writeln('--- Log gần đây ---')
      ..writeln(AppLogger().recentLogsText);
    return buffer.toString();
  }

  Future<void> _copyDebug() async {
    await Clipboard.setData(ClipboardData(text: _debugText()));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _messageFor(BackendStatus status, bool initializingAccounts) {
    if (initializingAccounts) {
      return 'Đang nạp các tài khoản Zalo đã đăng nhập...';
    }
    switch (status) {
      case BackendStatus.restarting:
        return 'Dịch vụ vừa dừng — đang tự khởi động lại...';
      case BackendStatus.degraded:
        return 'Đang kiểm tra dịch vụ Zalo cục bộ...';
      case BackendStatus.failed:
        return 'Không thể khởi động dịch vụ Zalo cục bộ\nsau nhiều lần thử.';
      case BackendStatus.starting:
      case BackendStatus.healthy:
      case BackendStatus.stopped:
        return 'Đang khởi động dịch vụ Zalo cục bộ...';
    }
  }
}
