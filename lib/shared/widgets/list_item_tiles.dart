import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../mock/mock_groups.dart';
import 'app_badge.dart';

/// Regex to strip ID prefix like "[1234] " from display names.
final _idPrefixRegex = RegExp(r'^\[\d+\]\s*');

/// A lightweight, self-contained list tile for a [FriendRecord].
///
/// Extracted so that Flutter can skip rebuilding unchanged items when the
/// parent list is filtered or scrolled.
class FriendCheckboxTile extends StatelessWidget {
  final FriendRecord friend;
  final bool isChecked;
  final bool enabled;
  final ValueChanged<String> onToggle;

  const FriendCheckboxTile({
    super.key,
    required this.friend,
    required this.isChecked,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceMuted,
              backgroundImage: friend.avatarUrl.isNotEmpty
                  ? NetworkImage(friend.avatarUrl)
                  : null,
              child: friend.avatarUrl.isEmpty
                  ? Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(child: Text(friend.name, style: AppTextStyles.bodyMedium)),
          ],
        ),
        subtitle: friend.phone.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(left: 36.0),
                child: Text(
                  friend.phone,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              )
            : null,
        value: isChecked,
        enabled: enabled,
        onChanged: (_) => onToggle(friend.id),
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      ),
    );
  }
}

/// A lightweight, self-contained list tile for a [ZaloGroup] with checkbox.
class GroupCheckboxTile extends StatelessWidget {
  final ZaloGroup group;
  final bool isChecked;
  final bool enabled;
  final ValueChanged<String> onToggle;
  final Widget? trailing;

  const GroupCheckboxTile({
    super.key,
    required this.group,
    required this.isChecked,
    required this.enabled,
    required this.onToggle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cleanName = group.name.replaceAll(_idPrefixRegex, '');

    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceMuted,
              backgroundImage: group.avatarUrl.isNotEmpty
                  ? NetworkImage(group.avatarUrl)
                  : null,
              child: group.avatarUrl.isEmpty
                  ? Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                cleanName,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.s),
              trailing!,
            ],
          ],
        ),
        subtitle: Text(
          '${group.memberCount} thành viên',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
        value: isChecked,
        enabled: enabled,
        onChanged: (_) => onToggle(group.id),
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      ),
    );
  }
}

/// A lightweight, self-contained list tile for a [ScannedMember] with checkbox.
class ScannedMemberCheckboxTile extends StatelessWidget {
  final ScannedMember member;
  final bool isChecked;
  final bool enabled;
  final ValueChanged<String> onToggle;
  final bool isSelf;

  const ScannedMemberCheckboxTile({
    super.key,
    required this.member,
    required this.isChecked,
    required this.enabled,
    required this.onToggle,
    this.isSelf = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = member.role.contains('Tr') && member.role.contains('ng nh'); // Trưởng nhóm fallback
    final isAdmin = member.role.contains('Ph') && member.role.contains('nh'); // Phó nhóm fallback

    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceMuted,
              backgroundImage: member.avatarUrl.isNotEmpty
                  ? NetworkImage(member.avatarUrl)
                  : null,
              child: member.avatarUrl.isEmpty
                  ? Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                member.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: isOwner || isAdmin
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isSelf ? AppColors.textMuted : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOwner || isAdmin || isSelf) ...[
              const SizedBox(width: AppSpacing.xs),
              AppBadge(
                label: isSelf ? 'Tài khoản của bạn' : member.role,
                variant: isSelf
                    ? AppBadgeVariant.warning
                    : (isOwner ? AppBadgeVariant.error : AppBadgeVariant.warning),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            if (member.phone.isNotEmpty) ...[
              Text(
                member.phone,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                '•',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: AppSpacing.s),
            ],
            Text(
              member.status,
              style: AppTextStyles.caption.copyWith(
                color: member.status.contains('k') && member.status.contains('t b')
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
        value: isChecked,
        enabled: enabled && !isSelf,
        onChanged: (_) => onToggle(member.id),
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      ),
    );
  }
}
