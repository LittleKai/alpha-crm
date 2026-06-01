import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../providers/zalo_integration_provider.dart';

class BackendWaitingScreen extends ConsumerStatefulWidget {
  const BackendWaitingScreen({super.key});

  @override
  ConsumerState<BackendWaitingScreen> createState() => _BackendWaitingScreenState();
}

class _BackendWaitingScreenState extends ConsumerState<BackendWaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  bool _isCheckingManually = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 10.0, end: 35.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleManualCheck() async {
    if (_isCheckingManually) return;
    setState(() {
      _isCheckingManually = true;
    });

    // Gọi trực tiếp checkConnection từ provider
    await ref.read(zaloIntegrationProvider.notifier).checkConnection();

    if (mounted) {
      setState(() {
        _isCheckingManually = false;
      });
      
      final state = ref.read(zaloIntegrationProvider);
      if (state.isBackendActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kết nối backend thành công!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vẫn không thể kết nối tới backend. Vui lòng kiểm tra lại.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final integrationState = ref.watch(zaloIntegrationProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Nền Gradient chuyển động mượt mà
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate cực tối
                  Color(0xFF1E293B), // Slate tối vừa
                  Color(0xFF020617), // Deepest dark
                ],
              ),
            ),
          ),

          // 2. Các Đốm sáng Neon mờ ảo (Glow Orbs) chuyển động
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                children: [
                  // Orb Trái Trên
                  Positioned(
                    top: size.height * 0.15,
                    left: size.width * 0.15,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 100 + _glowAnimation.value * 2,
                              spreadRadius: 20 + _glowAnimation.value,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Orb Phải Dưới
                  Positioned(
                    bottom: size.height * 0.15,
                    right: size.width * 0.15,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.purple.withOpacity(0.12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.18),
                              blurRadius: 120 + _glowAnimation.value * 2,
                              spreadRadius: 30 + _glowAnimation.value,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Toàn bộ nội dung căn giữa với Glassmorphic Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    width: 520,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 40,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Biểu tượng trạng thái & Animation
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.02),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.3),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.1),
                                        blurRadius: _glowAnimation.value,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            if (integrationState.isLoading || _isCheckingManually)
                              const SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 44,
                                color: Colors.orange.shade300,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),

                        // Tiêu đề
                        Text(
                          'Đang đợi kết nối Backend...',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.s),

                        // Trạng thái / Gợi ý
                        Text(
                          'Hệ thống đang tự động kết nối tới Node.js Backend service (port 8787).',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Hướng dẫn khắc phục lỗi (Developer tips)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.m),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.04),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.terminal_rounded,
                                    size: 16,
                                    color: Colors.cyan.shade300,
                                  ),
                                  const SizedBox(width: AppSpacing.s),
                                  Text(
                                    'HƯỚNG DẪN KHỞI ĐỘNG (DEVELOPER)',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.cyan.shade300,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _buildStepText(
                                '1',
                                'Mở một terminal mới tại thư mục dự án.',
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              _buildStepText(
                                '2',
                                'Di chuyển vào thư mục backend:',
                                codeText: 'cd tools/alpha-crm/integration/zalo-bot-service',
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              _buildStepText(
                                '3',
                                'Chạy lệnh khởi động:',
                                codeText: 'npm run dev',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Các nút hành động
                        Row(
                          children: [
                            // Nút thử lại thủ công
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (_isCheckingManually || integrationState.isLoading)
                                    ? null
                                    : _handleManualCheck,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      AppColors.primary.withOpacity(0.4),
                                  disabledForegroundColor: Colors.white.withOpacity(0.6),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.m,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isCheckingManually || integrationState.isLoading) ...[
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.s),
                                      Text(
                                        'Đang kiểm tra...',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ] else ...[
                                      const Icon(Icons.refresh_rounded, size: 20),
                                      const SizedBox(width: AppSpacing.s),
                                      Text(
                                        'Thử kết nối lại',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppSpacing.m),
                        
                        // Thông báo đếm ngược / Tự động check
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Text(
                              'Đang tự động ping mỗi 5 giây...',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepText(String stepNumber, String instruction, {String? codeText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$stepNumber. ',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              Expanded(
                child: Text(
                  instruction,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
          if (codeText != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                codeText,
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: Colors.green.shade300,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
