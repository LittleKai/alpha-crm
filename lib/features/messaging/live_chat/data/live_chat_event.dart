import 'dart:convert';

class LiveChatEvent {
  final String id;
  final String type;
  final String accountId;
  final String threadId;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const LiveChatEvent({
    required this.id,
    required this.type,
    required this.accountId,
    required this.threadId,
    required this.timestamp,
    required this.data,
  });

  factory LiveChatEvent.fromJson(
    Map<String, dynamic> json, {
    String? eventId,
    String? eventType,
  }) {
    return LiveChatEvent(
      id: eventId ?? (json['id'] ?? '').toString(),
      type: eventType ?? (json['type'] ?? 'message.updated').toString(),
      accountId: (json['accountId'] ?? '').toString(),
      threadId: (json['threadId'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{},
    );
  }
}

class LiveChatSseDecoder {
  String _id = '';
  String _type = '';
  final List<String> _data = [];

  List<LiveChatEvent> addLine(String line) {
    if (line.startsWith(':')) {
      if (line.substring(1).trim() == 'connected') {
        return [
          LiveChatEvent(
            id: '',
            type: 'bridge.connected',
            accountId: '',
            threadId: '',
            timestamp: DateTime.now(),
            data: const {},
          ),
        ];
      }
      return const [];
    }
    if (line.isEmpty) {
      if (_data.isEmpty) {
        _reset();
        return const [];
      }
      final event = _decode();
      _reset();
      return event == null ? const [] : [event];
    }
    if (line.startsWith('id:')) {
      _id = line.substring(3).trim();
    } else if (line.startsWith('event:')) {
      _type = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      _data.add(line.substring(5).trimLeft());
    }
    return const [];
  }

  LiveChatEvent? _decode() {
    try {
      final decoded = jsonDecode(_data.join('\n'));
      if (decoded is! Map) return null;
      return LiveChatEvent.fromJson(
        Map<String, dynamic>.from(decoded),
        eventId: _id,
        eventType: _type.isEmpty ? null : _type,
      );
    } catch (_) {
      return null;
    }
  }

  void _reset() {
    _id = '';
    _type = '';
    _data.clear();
  }
}
