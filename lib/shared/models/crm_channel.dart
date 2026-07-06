import 'package:flutter/material.dart';

enum CrmChannel {
  zaloPersonal('zalo_personal', 'Zalo cá nhân'),
  zaloOa('zalo_oa', 'Zalo OA'),
  facebookPage('facebook_page', 'Trang Facebook'),
  tiktok('tiktok', 'TikTok'),
  instagram('instagram', 'Instagram'),
  whatsapp('whatsapp', 'WhatsApp'),
  telegram('telegram', 'Telegram'),
  webchat('webchat', 'Webchat'),
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
      case CrmChannel.instagram:
        return Icons.camera_alt_outlined;
      case CrmChannel.whatsapp:
        return Icons.chat_outlined;
      case CrmChannel.telegram:
        return Icons.send_outlined;
      case CrmChannel.webchat:
        return Icons.forum_outlined;
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
      case CrmChannel.instagram:
        return const Color(0xFFE1306C);
      case CrmChannel.whatsapp:
        return const Color(0xFF25D366);
      case CrmChannel.telegram:
        return const Color(0xFF26A5E4);
      case CrmChannel.webchat:
        return const Color(0xFF4F46E5);
      case CrmChannel.email:
        return const Color(0xFF6366F1);
    }
  }
}
