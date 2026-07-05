import 'package:flutter/material.dart';

enum CrmChannel {
  zaloPersonal('zalo_personal', 'Zalo cá nhân'),
  zaloOa('zalo_oa', 'Zalo OA'),
  facebookPage('facebook_page', 'Trang Facebook'),
  tiktok('tiktok', 'TikTok'),
  email('email', 'Email');

  final String apiValue;
  final String label;

  const CrmChannel(this.apiValue, this.label);

  static CrmChannel fromApiValue(String value) {
    return CrmChannel.values.firstWhere(
      (channel) => channel.apiValue == value,
      orElse: () => CrmChannel.zaloPersonal,
    );
  }

  IconData get icon {
    switch (this) {
      case CrmChannel.zaloPersonal:
      case CrmChannel.zaloOa:
        return Icons.chat_bubble_outline;
      case CrmChannel.facebookPage:
        return Icons.facebook_outlined;
      case CrmChannel.tiktok:
        return Icons.music_note_outlined;
      case CrmChannel.email:
        return Icons.mail_outline;
    }
  }

  Color get color {
    switch (this) {
      case CrmChannel.zaloPersonal:
      case CrmChannel.zaloOa:
        return const Color(0xFF0068FF);
      case CrmChannel.facebookPage:
        return const Color(0xFF1877F2);
      case CrmChannel.tiktok:
        return const Color(0xFF010101);
      case CrmChannel.email:
        return const Color(0xFF6366F1);
    }
  }
}
