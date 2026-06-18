import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/zalo_backend_manager.dart';

/// Splash toàn màn che app trong lúc backend Zalo cục bộ khởi động LẦN ĐẦU.
///
/// - Khi backend khỏe lần đầu → splash biến mất vĩnh viễn; các gián đoạn về sau
///   chỉ dùng dải [BackendStatusBanner] mỏng, KHÔNG che lại toàn app.
/// - Nếu khởi động thất bại (circuit breaker mở) ở lần đầu → splash hiện lỗi kèm
///   nút "Thử lại" (`retryManually`).
class BackendSplashOverlay extends StatefulWidget {
  final Widget child;

  const BackendSplashOverlay({super.key, required this.child});

  @override
  State<BackendSplashOverlay> createState() => _BackendSplashOverlayState();
}

class _BackendSplashOverlayState extends State<BackendSplashOverlay> {
  /// Một khi backend đã khỏe lần đầu thì không bao giờ che splash nữa.
  bool _everHealthy = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BackendStatus>(
      valueListenable: ZaloBackendManager.status,
      builder: (context, status, child) {
        if (status == BackendStatus.healthy ||
            status == BackendStatus.stopped) {
          _everHealthy = true;
        }

        final showSplash = !_everHealthy &&
            (status == BackendStatus.starting ||
                status == BackendStatus.restarting ||
                status == BackendStatus.degraded ||
                status == BackendStatus.failed);

        return Stack(
          children: [
            widget.child,
            if (showSplash)
              Positioned.fill(child: _SplashContent(status: status)),
          ],
        );
      },
    );
  }
}

class _SplashContent extends StatefulWidget {
  final BackendStatus status;

  const _SplashContent({required this.status});

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 8.0, end: 30.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = widget.status == BackendStatus.failed;

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
              // Logo phát sáng + spinner
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return Transform.scale(
                    scale: isFailed ? 1.0 : _scale.value,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.03),
                        border: Border.all(
                          color: (isFailed ? Colors.red : const Color(0xFF6366F1))
                              .withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isFailed
                                    ? Colors.red
                                    : const Color(0xFF6366F1))
                                .withValues(alpha: 0.25),
                            blurRadius: isFailed ? 24 : _glow.value,
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
                            : Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  );
                },
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
                _messageFor(widget.status),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              if (isFailed)
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
                )
              else
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _messageFor(BackendStatus status) {
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
