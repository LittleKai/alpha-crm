import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_tokens.dart';

/// Shared resizable desktop right side panel (`320..600px`) modeled after
/// Twenty's `CommandMenuOpenContainer` + `SidePanelFooter`.
class AppSidePanel extends StatelessWidget {
  static const double minWidth = 320.0;
  static const double maxWidth = 600.0;
  static const double defaultWidth = 380.0;

  final Key? panelKey;
  final double width;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onClose;
  final Widget header;
  final Widget child;
  final Widget? footer;
  final bool allowResize;

  const AppSidePanel({
    super.key,
    this.panelKey,
    this.width = defaultWidth,
    required this.onWidthChanged,
    required this.onClose,
    required this.header,
    required this.child,
    this.footer,
    this.allowResize = true,
  });

  static double clampWidth(double raw) => raw.clamp(minWidth, maxWidth);

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final double effectiveWidth = clampWidth(width);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              key: panelKey,
              width: effectiveWidth,
              decoration: BoxDecoration(
                color: tokens.surfacePrimary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderMedium, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: header,
                  ),
                  Divider(height: 1, color: tokens.borderMedium),
                  child,
                  if (footer != null) ...[
                    Divider(height: 1, color: tokens.borderMedium),
                    Container(
                      color: tokens.surfaceSecondary,
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: footer,
                    ),
                  ],
                ],
              ),
            ),
            if (allowResize)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    key: const ValueKey('app_side_panel_resize_handle'),
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      onWidthChanged(
                        clampWidth(effectiveWidth - details.delta.dx),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
