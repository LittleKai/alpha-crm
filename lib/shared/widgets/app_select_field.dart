import 'package:flutter/material.dart';
import 'app_dropdown_field.dart';

@Deprecated('Use AppDropdownField directly instead')
class AppSelectField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? labelText;

  const AppSelectField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hintText,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    return AppDropdownField<T>(
      value: value,
      items: items.map((e) {
        String label = '';
        if (e.child is Text) {
          label = (e.child as Text).data ?? '';
        }
        return AppDropdownItem<T>(
          value: e.value as T,
          label: label,
        );
      }).toList(),
      onChanged: onChanged == null ? null : (v) => onChanged!(v),
      hintText: hintText,
      labelText: labelText,
    );
  }
}
