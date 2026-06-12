import 'dart:convert';

import '../providers/live_chat_provider.dart';

enum LiveChatAttachmentKind { image, file, video }

class LiveChatAttachmentView {
  final LiveChatAttachmentKind kind;
  final String displayName;
  final String url;
  final String localPath;
  final String sizeLabel;
  final String thumbnailUrl;

  const LiveChatAttachmentView({
    required this.kind,
    required this.displayName,
    this.url = '',
    this.localPath = '',
    this.sizeLabel = '',
    this.thumbnailUrl = '',
  });

  bool get hasRemoteUrl =>
      url.startsWith('http://') || url.startsWith('https://');

  bool get hasLocalPath => localPath.trim().isNotEmpty;
}

LiveChatAttachmentView? resolveLiveChatAttachmentView(ChatMessage message) {
  final attachment = _firstAttachmentMap(message.attachments);
  if (attachment != null) {
    return _viewFromAttachmentMap(attachment, message.contentType);
  }
  final stringAttachment = _firstAttachmentString(message.attachments);
  if (stringAttachment.isNotEmpty) {
    return _viewFromPath(stringAttachment, message.contentType);
  }
  return _viewFromLegacyJson(message) ?? _viewFromMessageType(message);
}

Map<String, dynamic>? _firstAttachmentMap(Object? value) {
  if (value is List) {
    for (final item in value) {
      if (item is Map) return Map<String, dynamic>.from(item);
    }
  }
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _firstAttachmentString(Object? value) {
  if (value is List) {
    for (final item in value) {
      final text = item?.toString().trim() ?? '';
      if (text.isNotEmpty && item is! Map) return text;
    }
  }
  if (value is String) return value.trim();
  return '';
}

LiveChatAttachmentView? _viewFromAttachmentMap(
  Map<String, dynamic> data,
  String contentType,
) {
  final kindText = (data['kind'] ?? contentType).toString().toLowerCase();
  final mimeType = (data['mimeType'] ?? '').toString().toLowerCase();
  final url = (data['cacheUrl'] ?? data['url'] ?? data['href'] ?? '')
      .toString();
  final localPath = (data['localPath'] ?? data['path'] ?? '').toString();
  final name = _firstNonEmpty([
    data['name'],
    data['fileName'],
    _basename(localPath),
    _basename(url),
  ]);
  final isImage =
      contentType == 'image' ||
      kindText == 'image' ||
      mimeType.startsWith('image/') ||
      _looksLikeImagePath(localPath) ||
      _looksLikeImagePath(url);
  final isVideo =
      contentType == 'video' ||
      kindText == 'video' ||
      mimeType.startsWith('video/') ||
      _looksLikeVideoPath(localPath) ||
      _looksLikeVideoPath(url);
  final metadata = data['metadata'] is Map
      ? Map<String, dynamic>.from(data['metadata'] as Map)
      : const <String, dynamic>{};

  return LiveChatAttachmentView(
    kind: isVideo
        ? LiveChatAttachmentKind.video
        : isImage
        ? LiveChatAttachmentKind.image
        : LiveChatAttachmentKind.file,
    displayName: name.isEmpty
        ? (isVideo
              ? 'video'
              : isImage
              ? 'image'
              : 'file')
        : _safeDecodeComponent(name),
    url: url,
    localPath: localPath,
    sizeLabel: _formatSize(data['sizeBytes']),
    thumbnailUrl: _firstNonEmpty([
      data['thumbnailUrl'],
      data['thumb'],
      metadata['thumbnailUrl'],
      metadata['thumb'],
    ]),
  );
}

LiveChatAttachmentView _viewFromPath(String path, String contentType) {
  final isImage = contentType == 'image' || _looksLikeImagePath(path);
  return LiveChatAttachmentView(
    kind: isImage ? LiveChatAttachmentKind.image : LiveChatAttachmentKind.file,
    displayName: _safeDecodeComponent(
      _basename(path).isEmpty
          ? (isImage ? 'Hinh anh' : 'Tep dinh kem')
          : _basename(path),
    ),
    url: path.startsWith('http://') || path.startsWith('https://') ? path : '',
    localPath: path.startsWith('http://') || path.startsWith('https://')
        ? ''
        : path,
  );
}

LiveChatAttachmentView? _viewFromMessageType(ChatMessage message) {
  final type = message.contentType.toLowerCase();
  if (type != 'image' &&
      type != 'gif' &&
      type != 'file' &&
      type != 'video' &&
      type != 'voice') {
    return null;
  }
  final trimmed = message.message.trim();
  final isImage = type == 'image' || type == 'gif';
  final displayName =
      trimmed.isNotEmpty &&
          trimmed != '[image]' &&
          trimmed != '[file]' &&
          trimmed != '[video]'
      ? trimmed
      : (isImage ? 'Hinh anh' : 'Tep dinh kem');
  return LiveChatAttachmentView(
    kind: isImage ? LiveChatAttachmentKind.image : LiveChatAttachmentKind.file,
    displayName: displayName,
  );
}

LiveChatAttachmentView? _viewFromLegacyJson(ChatMessage message) {
  final trimmed = message.message.trim();
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return null;
    final data = Map<String, dynamic>.from(decoded);
    var params = data['params'];
    if (params is String && params.trim().startsWith('{')) {
      params = jsonDecode(params);
    }
    if (params is Map) {
      final name = _firstNonEmpty([
        data['title'],
        data['fileName'],
        params['fileName'],
        params['name'],
      ]);
      if (params['fileExt'] != null || params['fType'] == 1) {
        return LiveChatAttachmentView(
          kind: LiveChatAttachmentKind.file,
          displayName: name.isEmpty
              ? 'file.${params['fileExt'] ?? 'unknown'}'
              : name,
          url: (data['href'] ?? params['fileUrl'] ?? '').toString(),
          sizeLabel: _formatSize(params['fileSize'] ?? params['totalSize']),
        );
      }
    }
  } catch (_) {}
  return null;
}

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _basename(String value) {
  if (value.trim().isEmpty) return '';
  final normalized = value.replaceAll('\\', '/');
  return normalized.split('/').last;
}

bool _looksLikeImagePath(String value) {
  return RegExp(
    r'\.(jpg|jpeg|png|webp|gif)$',
    caseSensitive: false,
  ).hasMatch(value.split('?').first);
}

bool _looksLikeVideoPath(String value) {
  return RegExp(
    r'\.(mp4|mov|m4v|webm|mkv|avi|3gp)$',
    caseSensitive: false,
  ).hasMatch(value.split('?').first);
}

String _safeDecodeComponent(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

String _formatSize(Object? raw) {
  final bytes = int.tryParse((raw ?? '').toString()) ?? 0;
  if (bytes <= 0) return '';
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).ceil()} KB';
}
