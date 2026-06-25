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
          leading: _extractLeading(e.child),
        );
      }).toList(),
      onChanged: onChanged == null ? null : (v) => onChanged!(v),
      hintText: hintText,
      labelText: labelText,
    );
  }

  /// Extracts any leading widget (avatar, icon) from a rich item child (e.g. Row(avatar + name)).
  static Widget? _extractLeading(Widget? w) {
    if (w == null) return null;
    if (w is CircleAvatar || w is ClipOval || w is ClipRRect || w is Icon || w is Image) {
      return w;
    }
    if (w is Row) {
      for (final child in w.children) {
        final leading = _extractLeading(child);
        if (leading != null) return leading;
      }
    }
    if (w is MultiChildRenderObjectWidget) {
      for (final child in w.children) {
        final leading = _extractLeading(child);
        if (leading != null) return leading;
      }
    }
    if (w is SingleChildRenderObjectWidget) {
      return _extractLeading(w.child);
    }
    if (w is Padding) return _extractLeading(w.child);
    if (w is Align) return _extractLeading(w.child);
    if (w is Container) return _extractLeading(w.child);
    if (w is SizedBox) return _extractLeading(w.child);
    if (w is Expanded) return _extractLeading(w.child);
    if (w is Flexible) return _extractLeading(w.child);
    return null;
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
