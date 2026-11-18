import 'dart:isolate';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_theme_tokens.dart';
import '../../../../mock/mock_contacts.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../providers/customers_provider.dart';
import '../../utils/customer_file_parser.dart';

enum CustomerImportStep { selectHeader, matchColumns, validatePreview }

Future<List<Contact>?> showCustomerImportWizardDialog(
  BuildContext context, {
  required String fileName,
  required List<List<String>> rawRows,
  required List<CustomerAttributeDefinition> customAttributes,
}) {
  return showStandardDialog<List<Contact>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => CustomerImportWizardDialog(
      fileName: fileName,
      rawRows: rawRows,
      customAttributes: customAttributes,
    ),
  );
}

/// 3-step spreadsheet import wizard modeled after Twenty's
/// `SelectHeaderStep -> MatchColumnsStep -> ValidationStep`.
class CustomerImportWizardDialog extends StatefulWidget {
  final String fileName;
  final List<List<String>> rawRows;
  final List<CustomerAttributeDefinition> customAttributes;

  const CustomerImportWizardDialog({
    super.key,
    required this.fileName,
    required this.rawRows,
    required this.customAttributes,
  });

  @override
  State<CustomerImportWizardDialog> createState() =>
      _CustomerImportWizardDialogState();
}

class _CustomerImportWizardDialogState
    extends State<CustomerImportWizardDialog> {
  late CustomerImportStep _step;
  late int _headerRowIndex;
  late List<ImportColumnMapping> _mappings;
  List<ImportedRowValidation> _validatedRows = const [];
  bool _onlyShowErrors = false;
  bool _isValidating = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _headerRowIndex = detectHeaderRowIndex(widget.rawRows);
    _mappings = suggestImportMappings(
      widget.rawRows,
      headerRowIndex: _headerRowIndex,
    );
    // Start at MatchColumns if headers detected at row 0; otherwise let user confirm header row
    _step = _headerRowIndex == 0
        ? CustomerImportStep.matchColumns
        : CustomerImportStep.selectHeader;
  }

  void _selectHeaderRow(int index) {
    setState(() {
      _headerRowIndex = index;
      _mappings = suggestImportMappings(
        widget.rawRows,
        headerRowIndex: index,
      );
    });
  }

  void _updateColumnMapping(
    int colIndex,
    ImportTargetField nextField, {
    String? customKey,
  }) {
    setState(() {
      _mappings = _mappings.map((m) {
        if (m.sourceIndex == colIndex) {
          return m.copyWith(
            targetField: nextField,
            customKey: customKey ?? (nextField == ImportTargetField.custom
                ? (m.customKey ?? 'col_${colIndex + 1}')
                : null),
            clearCustomKey: nextField != ImportTargetField.custom,
          );
        }
        // Single-target CRM fields cannot be mapped twice simultaneously
        if (nextField != ImportTargetField.ignore &&
            nextField != ImportTargetField.custom &&
            m.targetField == nextField) {
          return m.copyWith(
            targetField: ImportTargetField.ignore,
            clearCustomKey: true,
          );
        }
        return m;
      }).toList();
    });
  }

  bool get _hasRequiredMapping => _mappings.any(
        (m) =>
            m.targetField == ImportTargetField.name ||
            m.targetField == ImportTargetField.phone,
      );

  static const int _isolateRowThreshold = 500;

  static Future<List<ImportedRowValidation>> _validateRowsInIsolate(
    List<List<String>> rows,
    int headerIndex,
    List<ImportColumnMapping> mappings,
  ) {
    return Isolate.run(
      () => buildValidatedImportRows(
        rows,
        headerRowIndex: headerIndex,
        mappings: mappings,
      ),
    );
  }

  Future<void> _goToValidate() async {
    if (_isValidating) return;
    final rowsSnapshot = widget.rawRows;
    final headerIndex = _headerRowIndex;
    final mappingsSnapshot = List<ImportColumnMapping>.unmodifiable(_mappings);
    if (rowsSnapshot.length <= _isolateRowThreshold) {
      final validated = buildValidatedImportRows(
        rowsSnapshot,
        headerRowIndex: headerIndex,
        mappings: mappingsSnapshot,
      );
      setState(() {
        _validatedRows = validated;
        _onlyShowErrors = false;
        _step = CustomerImportStep.validatePreview;
      });
      return;
    }
    setState(() {
      _isValidating = true;
      _validationError = null;
    });
    try {
      final validated = await _validateRowsInIsolate(
        rowsSnapshot,
        headerIndex,
        mappingsSnapshot,
      );
      if (!mounted) return;
      setState(() {
        _validatedRows = validated;
        _onlyShowErrors = false;
        _isValidating = false;
        _step = CustomerImportStep.validatePreview;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _validationError =
            'Không kiểm tra được dữ liệu tệp. Vui lòng thử lại.';
      });
    }
  }

  void _submit() {
    final selected = _validatedRows
        .where((r) => r.selected)
        .map((r) => r.contact)
        .toList();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final selectedCount = _validatedRows.where((r) => r.selected).length;

    return AppDialog(
      key: const ValueKey('customer_import_wizard_dialog'),
      title: 'Nhập khách hàng từ "${widget.fileName}"',
      subtitle: 'Chọn dòng tiêu đề, ghép cột dữ liệu và kiểm tra trước khi lưu.',
      icon: Icons.table_chart_outlined,
      width: 760,
      showCloseButton: true,
      actions: [
        if (_step == CustomerImportStep.selectHeader) ...[
          AppDialogAction(
            text: 'Hủy',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppDialogAction(
            text: 'Tiếp tục ghép cột',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => setState(() {
              _step = CustomerImportStep.matchColumns;
            }),
          ),
        ] else if (_step == CustomerImportStep.matchColumns) ...[
          AppDialogAction(
            text: 'Chọn lại tiêu đề',
            variant: AppButtonVariant.outline,
            onPressed: _isValidating
                ? null
                : () => setState(() {
                    _step = CustomerImportStep.selectHeader;
                  }),
          ),
          AppDialogAction(
            text: _isValidating ? 'Đang kiểm tra...' : 'Kiểm tra dữ liệu',
            icon: Icons.fact_check_outlined,
            onPressed: (_hasRequiredMapping && !_isValidating)
                ? _goToValidate
                : null,
          ),
        ] else ...[
          AppDialogAction(
            text: 'Quay lại ghép cột',
            variant: AppButtonVariant.outline,
            onPressed: () => setState(() {
              _step = CustomerImportStep.matchColumns;
            }),
          ),
          AppDialogAction(
            text: 'Nhập $selectedCount khách hàng',
            icon: Icons.check_rounded,
            onPressed: selectedCount > 0 ? _submit : null,
          ),
        ],
      ],
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepIndicatorBar(current: _step, tokens: tokens),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: switch (_step) {
                CustomerImportStep.selectHeader => _buildHeaderStep(tokens),
                CustomerImportStep.matchColumns => _buildMatchStep(tokens),
                CustomerImportStep.validatePreview => _buildValidateStep(tokens),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStep(AppThemeTokens tokens) {
    final previewCount = widget.rawRows.length < 10 ? widget.rawRows.length : 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Chọn dòng chứa tiêu đề cột (hoặc chọn không có tiêu đề):',
                style: AppTextStyles.body.copyWith(color: tokens.textSecondary),
              ),
            ),
            TextButton(
              key: const ValueKey('import_wizard_no_header_btn'),
              onPressed: () => _selectHeaderRow(-1),
              child: Text(
                _headerRowIndex == -1
                    ? 'Đang chọn: Không có tiêu đề'
                    : 'File không có tiêu đề',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Expanded(
          child: ListView.separated(
            itemCount: previewCount,
            separatorBuilder: (_, _) => Divider(height: 1, color: tokens.borderLight),
            itemBuilder: (context, index) {
              final row = widget.rawRows[index];
              final isSelected = _headerRowIndex == index;
              return InkWell(
                key: ValueKey('import_header_row_$index'),
                onTap: () => _selectHeaderRow(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  color: isSelected ? tokens.transparentLight : Colors.transparent,
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: isSelected
                            ? tokens.accentBlue
                            : tokens.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dòng ${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.where((c) => c.trim().isNotEmpty).take(5).join('  •  '),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tokens.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMatchStep(AppThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_validationError != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.dangerBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: tokens.dangerText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _validationError!,
                    style: TextStyle(fontSize: 12, color: tokens.dangerText),
                  ),
                ),
              ],
            ),
          ),
        if (!_hasRequiredMapping)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.warningBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: tokens.warningText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cần ghép ít nhất cột "Họ và tên" hoặc "Số điện thoại".',
                    style: TextStyle(fontSize: 12, color: tokens.warningText),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: _mappings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final mapping = _mappings[index];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderMedium),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mapping.headerText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mapping.sampleValue.isEmpty
                                ? 'VD: (trống)'
                                : 'VD: ${mapping.sampleValue}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: tokens.textTertiary,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<ImportTargetField>(
                        key: ValueKey('import_col_dropdown_${mapping.sourceIndex}'),
                        initialValue: mapping.targetField,
                        isDense: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: ImportTargetField.values
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(
                                  f.label,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (next) {
                          if (next != null) {
                            _updateColumnMapping(mapping.sourceIndex, next);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildValidateStep(AppThemeTokens tokens) {
    final errorCount = _validatedRows.where((r) => r.hasError).length;
    final validCount = _validatedRows.length - errorCount;
    final displayed = _onlyShowErrors
        ? _validatedRows.where((r) => r.hasError).toList()
        : _validatedRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _CountTag(
              label: 'Hợp lệ: $validCount',
              bg: tokens.successBg,
              fg: tokens.successText,
            ),
            const SizedBox(width: 8),
            _CountTag(
              label: 'Có lỗi: $errorCount',
              bg: errorCount > 0 ? tokens.dangerBg : tokens.surfaceQuaternary,
              fg: errorCount > 0 ? tokens.dangerText : tokens.textSecondary,
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chỉ xem dòng lỗi',
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                ),
                const SizedBox(width: 6),
                Switch(
                  key: const ValueKey('import_wizard_only_errors_switch'),
                  value: _onlyShowErrors,
                  onChanged: (v) => setState(() => _onlyShowErrors = v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Expanded(
          child: displayed.isEmpty
              ? Center(
                  child: Text(
                    _onlyShowErrors
                        ? 'Không có dòng nào bị lỗi.'
                        : 'Không có dòng dữ liệu hợp lệ.',
                    style: TextStyle(color: tokens.textTertiary),
                  ),
                )
              : ListView.separated(
                  itemCount: displayed.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: tokens.borderLight),
                  itemBuilder: (context, idx) {
                    final item = displayed[idx];
                    final realIdx = _validatedRows.indexOf(item);
                    return Container(
                      key: ValueKey('import_preview_row_${item.rowIndex}'),
                      color: item.hasError
                          ? tokens.dangerBg.withValues(alpha: 0.45)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: item.selected,
                            onChanged: (checked) {
                              if (realIdx < 0) return;
                              setState(() {
                                _validatedRows[realIdx] =
                                    item.copyWith(selected: checked ?? false);
                              });
                            },
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.contact.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.contact.phone.isEmpty
                                  ? '(thiếu SĐT)'
                                  : item.contact.phone,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: item.hasError
                                    ? tokens.dangerText
                                    : tokens.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.errorReason ?? '${item.contact.group} • ${item.contact.tag}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: item.hasError
                                    ? tokens.dangerText
                                    : tokens.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StepIndicatorBar extends StatelessWidget {
  final CustomerImportStep current;
  final AppThemeTokens tokens;

  const _StepIndicatorBar({required this.current, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (CustomerImportStep.selectHeader, '1. Chọn tiêu đề'),
      (CustomerImportStep.matchColumns, '2. Ghép cột'),
      (CustomerImportStep.validatePreview, '3. Kiểm tra & Nhập'),
    ];
    return Row(
      children: steps.map((entry) {
        final active = entry.$1 == current;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: active ? tokens.transparentLight : tokens.surfaceSecondary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active ? tokens.accentBlue : tokens.borderMedium,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? tokens.textPrimary : tokens.textTertiary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CountTag extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _CountTag({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
