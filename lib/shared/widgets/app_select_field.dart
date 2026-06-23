import 'package:flutter/material.dart';
import 'app_dropdown_field.dart';

@Deprecated('Use AppDropdownField directly instead')
class AppSelectField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final DropdownButtonBuilder? selectedItemBuilder;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final double? itemHeight;

  const AppSelectField({
    super.key,
    required this.items,
    this.selectedItemBuilder,
    this.value,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.helperText,
    this.itemHeight,
  });

  @override
  Widget build(BuildContext context) {
    return AppDropdownField<T>(
      value: value,
      items: items.map((e) {
        return AppDropdownItem<T>(
          value: e.value as T,
          label: _extractLabel(e.child),
        );
      }).toList(),
      onChanged: onChanged == null ? null : (v) => onChanged!(v),
      hintText: hintText,
      labelText: labelText,
    );
  }

  /// Recursively pull the first non-empty [Text] string out of a rich item
  /// child (e.g. Row(avatar + name)). Without this, items built as anything
  /// other than a bare [Text] render blank in the dropdown.
  static String _extractLabel(Widget? w) {
    if (w == null) return '';
    if (w is Text) return w.data ?? '';
    if (w is Flexible) return _extractLabel(w.child); // covers Expanded
    if (w is Padding) return _extractLabel(w.child);
    if (w is Align) return _extractLabel(w.child);
    if (w is Container) return _extractLabel(w.child);
    if (w is MultiChildRenderObjectWidget) {
      for (final child in w.children) {
        final label = _extractLabel(child);
        if (label.isNotEmpty) return label;
      }
    }
    return '';
  }
}
