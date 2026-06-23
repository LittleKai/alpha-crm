import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

/// Data model for a dropdown item.
class AppDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.leading,
  });
}

/// Premium styled dropdown field with overlay popup.
///
/// Standard CRM dropdown widget. Use this instead of [DropdownButtonFormField]
/// or the legacy [AppSelectField] for consistent styling across the app.
///
/// Features:
/// - Custom overlay popup with smooth animation
/// - Hover highlight and selected check mark
/// - Optional leading icon and subtitle per item
/// - Dark-mode aware via [AppColors]
/// - Animated chevron rotation
class AppDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T>? onChanged;
  final String? hintText;
  final String? labelText;
  final bool enabled;

  const AppDropdownField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.enabled = true,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isOpen = false;
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final renderBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final triggerSize = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _DropdownOverlay<T>(
        link: _layerLink,
        triggerWidth: triggerSize.width,
        triggerHeight: triggerSize.height,
        items: widget.items,
        selectedValue: widget.value,
        fadeAnim: _fadeAnim,
        slideAnim: _slideAnim,
        hoveredIndex: _hoveredIndex,
        onHover: (index) {
          _hoveredIndex = index;
          _overlayEntry?.markNeedsBuild();
        },
        onSelect: (value) {
          widget.onChanged?.call(value);
          _close();
        },
        onDismiss: _close,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward(from: 0);
    if (mounted) setState(() => _isOpen = true);
  }

  void _close() {
    if (!_isOpen) return;
    _animController.reverse().then((_) {
      _removeOverlay();
    });
    if (mounted) setState(() => _isOpen = false);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredIndex = -1;
  }

  AppDropdownItem<T>? get _selectedItem {
    if (widget.value == null) return null;
    for (final item in widget.items) {
      if (item.value == widget.value) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem;
    final hasValue = selected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText != null) ...[
          Text(widget.labelText!, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              key: _triggerKey,
              onTap: _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? AppColors.surface
                      : AppColors.disabledSoft,
                  borderRadius: AppSpacing.borderRadiusM,
                  border: Border.all(
                    color: _isOpen ? AppColors.primary : AppColors.border,
                    width: _isOpen ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (selected?.leading != null) ...[
                      selected!.leading!,
                      const SizedBox(width: 8),
                    ] else if (selected?.icon != null) ...[
                      Icon(selected!.icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        hasValue ? selected.label : (widget.hintText ?? ''),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          color: hasValue
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color:
                            _isOpen ? AppColors.primary : AppColors.iconMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Overlay popup ──────────────────────────────────────────────────────────

class _DropdownOverlay<T> extends StatelessWidget {
  final LayerLink link;
  final double triggerWidth;
  final double triggerHeight;
  final List<AppDropdownItem<T>> items;
  final T? selectedValue;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final int hoveredIndex;
  final ValueChanged<int> onHover;
  final ValueChanged<T> onSelect;
  final VoidCallback onDismiss;

  const _DropdownOverlay({
    required this.link,
    required this.triggerWidth,
    required this.triggerHeight,
    required this.items,
    required this.selectedValue,
    required this.fadeAnim,
    required this.slideAnim,
    required this.hoveredIndex,
    required this.onHover,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap-away barrier
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Popup
        CompositedTransformFollower(
          link: link,
          offset: Offset(0, triggerHeight + 4),
          showWhenUnlinked: false,
          child: FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: slideAnim,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: triggerWidth,
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.borderRadiusM,
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppSpacing.borderRadiusM,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final isSelected = item.value == selectedValue;
                          final isHovered = index == hoveredIndex;

                          return MouseRegion(
                            onEnter: (_) => onHover(index),
                            onExit: (_) => onHover(-1),
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => onSelect(item.value),
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 80),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                color: isSelected
                                    ? AppColors.primarySoft
                                    : isHovered
                                        ? AppColors.surfaceMuted
                                        : Colors.transparent,
                                child: Row(
                                  children: [
                                    if (item.leading != null) ...[
                                      item.leading!,
                                      const SizedBox(width: 10),
                                    ] else if (item.icon != null) ...[
                                      Icon(
                                        item.icon,
                                        size: 18,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.iconMuted,
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.label,
                                            style:
                                                AppTextStyles.body.copyWith(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          if (item.subtitle != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle!,
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: AppColors.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
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
}
