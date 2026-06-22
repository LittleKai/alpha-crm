import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

typedef AvatarEntry = ({String avatarUrl, String name});

/// Overlapping account avatars. Shows up to [maxShown]; any extras collapse into
/// a "+N" badge. Avatars are disk-cached via cached_network_image and show the
/// account name on hover.
class AccountAvatarStack extends StatelessWidget {
  final List<AvatarEntry> accounts;
  final double size;
  final int maxShown;

  const AccountAvatarStack({
    super.key,
    required this.accounts,
    this.size = 26,
    this.maxShown = 3,
  });

  double get _step => size * 0.62;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final shown = accounts.take(maxShown).toList();
    final extra = accounts.length - shown.length;
    final slots = shown.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      width: size + (slots - 1) * _step,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(left: i * _step, child: _avatar(shown[i])),
          if (extra > 0)
            Positioned(
              left: shown.length * _step,
              child: _circle(
                color: AppColors.primarySoft,
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(AvatarEntry account) {
    final name = account.name;
    final url = account.avatarUrl;
    return Tooltip(
      message: name.isNotEmpty ? name : 'Tài khoản',
      child: _circle(
        color: AppColors.surfaceMuted,
        image: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
        child: url.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      ),
    );
  }

  Widget _circle({required Color color, ImageProvider? image, Widget? child}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: AppColors.surface, width: 2),
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Strips a trailing "(id)" suffix from an account label so only the name shows.
String accountDisplayName(String label) {
  return label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
}
