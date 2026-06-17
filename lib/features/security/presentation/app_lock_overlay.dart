import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../providers/app_lock_provider.dart';

class AppLockOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockOverlay({super.key, required this.child});

  @override
  ConsumerState<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<AppLockOverlay> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockProvider);
    return Stack(
      children: [
        widget.child,
        if (state.isLocked)
          Positioned.fill(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (context) => Material(
                  color: const Color(0xEE0F172A),
                  child: Center(
                    child: Container(
                      width: 420,
                      margin: const EdgeInsets.all(AppSpacing.l),
                      padding: const EdgeInsets.all(AppSpacing.l),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppSpacing.borderRadiusM,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primary,
                        size: 42,
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Text(
                        state.setupRequired
                            ? 'Tạo mật khẩu khóa'
                            : 'Alpha CRM đang bị khóa',
                        style: AppTextStyles.sectionTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        state.setupRequired
                            ? 'Mật khẩu này chỉ lưu trên thiết bị cục bộ.'
                            : 'Nhập mật khẩu để tiếp tục làm việc.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.l),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _submit(state.setupRequired),
                      ),
                      if (state.setupRequired) ...[
                        const SizedBox(height: AppSpacing.m),
                        TextField(
                          controller: _confirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nhập lại mật khẩu',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _submit(true),
                        ),
                      ],
                      if (state.errorText != null) ...[
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          state.errorText!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.errorText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.l),
                      Row(
                        children: [
                          if (state.setupRequired) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _passwordController.clear();
                                  _confirmController.clear();
                                  ref
                                      .read(appLockProvider.notifier)
                                      .cancelSetup();
                                },
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.m),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _submit(state.setupRequired),
                              icon: const Icon(Icons.lock_open_rounded),
                              label: Text(
                                state.setupRequired ? 'Tạo khóa' : 'Mở khóa',
                              ),
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
      ),
      ],
    );
  }

  void _submit(bool setupRequired) {
    final password = _passwordController.text;
    if (setupRequired) {
      if (password != _confirmController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mật khẩu nhập lại không khớp.')),
        );
        return;
      }
      ref.read(appLockProvider.notifier).setPassword(password);
    } else {
      ref.read(appLockProvider.notifier).unlock(password);
    }
    _passwordController.clear();
    _confirmController.clear();
  }
}
