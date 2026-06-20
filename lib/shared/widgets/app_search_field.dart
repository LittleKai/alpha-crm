import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class AppSearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final VoidCallback? onClear;
  final Duration debounceDuration;

  const AppSearchField({
    super.key,
    this.hintText = 'Tìm kiếm...',
    this.onChanged,
    this.controller,
    this.onClear,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    // Always update clear-button visibility immediately
    setState(() {});

    if (widget.onChanged == null) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onChanged!(value);
    });
  }

  void _onClear() {
    widget.controller?.clear();
    _debounceTimer?.cancel();
    setState(() {});
    if (widget.onClear != null) widget.onClear!();
    if (widget.onChanged != null) widget.onChanged!('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? const Color(0xFF475569) : AppColors.iconMuted;
    final hasText =
        widget.controller != null && widget.controller!.text.isNotEmpty;

    return SizedBox(
      height: 40,
      child: TextField(
        controller: widget.controller,
        onChanged: _onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(Icons.search, size: 18, color: iconColor),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(Icons.clear, size: 16, color: iconColor),
                  onPressed: _onClear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}
