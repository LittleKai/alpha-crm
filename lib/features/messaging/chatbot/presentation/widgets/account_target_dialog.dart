import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/account_avatar_stack.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';

/// Lets the operator scope an item (keyword rule or knowledge document) to all
/// Zalo accounts (default) or to specific accounts.
///
/// Returns the new list of account ids, or null if cancelled. An empty list
/// means "all accounts".
Future<List<String>?> showAccountTargetDialog({
  required BuildContext context,
  required List<ZaloConnectedAccount> accounts,
  required List<String> selectedIds,
  String title = 'Áp dụng cho tài khoản',
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _AccountTargetDialog(
      accounts: accounts,
      selectedIds: selectedIds,
      title: title,
    ),
  );
}

class _AccountTargetDialog extends StatefulWidget {
  final List<ZaloConnectedAccount> accounts;
  final List<String> selectedIds;
  final String title;

  const _AccountTargetDialog({
    required this.accounts,
    required this.selectedIds,
    required this.title,
  });

  @override
  State<_AccountTargetDialog> createState() => _AccountTargetDialogState();
}

class _AccountTargetDialogState extends State<_AccountTargetDialog> {
  late bool _allAccounts;
  late Set<String> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIds.where((id) => id.isNotEmpty).toSet();
    _allAccounts = _selected.isEmpty;
  }

  Widget _modeChoice({required bool isAll, required String label}) {
    final selected = _allAccounts == isAll;
    return InkWell(
      borderRadius: AppSpacing.borderRadiusM,
      onTap: () => setState(() => _allAccounts = isAll),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s),
            Text(label, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final filtered = widget.accounts.where((acc) {
      if (query.isEmpty) return true;
      return acc.label.toLowerCase().contains(query) ||
          acc.id.toLowerCase().contains(query);
    }).toList();

    return AppDialog(
      title: widget.title,
      subtitle:
          'Mặc định áp dụng cho mọi tài khoản. Chọn cụ thể nếu chỉ muốn dùng cho một số tài khoản Zalo.',
      icon: Icons.account_circle_outlined,
      width: 520,
      actions: [
        AppDialogAction(
          text: 'Hủy',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          text: 'Lưu',
          icon: Icons.save_outlined,
          onPressed: () {
            Navigator.of(context).pop(
              _allAccounts ? <String>[] : _selected.toList(),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _modeChoice(isAll: true, label: 'Mọi tài khoản (mặc định)'),
          _modeChoice(isAll: false, label: 'Chọn tài khoản cụ thể'),
          if (!_allAccounts) ...[
            const SizedBox(height: AppSpacing.s),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Tìm tài khoản…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusM,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            if (widget.accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Text(
                  'Chưa có tài khoản Zalo nào đang kết nối.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final acc = filtered[i];
                    final checked = _selected.contains(acc.id);
                    final name = accountDisplayName(acc.label);
                    return CheckboxListTile(
                      value: checked,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(acc.id);
                        } else {
                          _selected.remove(acc.id);
                        }
                      }),
                      title: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.surfaceMuted,
                            backgroundImage: acc.avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(acc.avatarUrl)
                                : null,
                            child: acc.avatarUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'A',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Text(
                              name.isNotEmpty ? name : 'Tài khoản',
                              style: AppTextStyles.bodyMedium,
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
        ],
      ),
    );
  }
}
