import 'package:alpha_crm/features/messaging/live_chat/utils/quick_reply_shortcuts.dart';
import 'package:alpha_crm/mock/mock_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves numeric quick reply shortcut by display order', () {
    final templates = [
      MessageTemplate(
        id: 'a',
        title: 'A',
        content: 'First quick reply',
        variables: const [],
        createdAt: DateTime(2026),
        shortcut: '/hello',
        isQuick: true,
      ),
      MessageTemplate(
        id: 'b',
        title: 'B',
        content: 'Second quick reply',
        variables: const [],
        createdAt: DateTime(2026),
        shortcut: '/quote',
        isQuick: true,
      ),
    ];

    expect(resolveQuickReplyShortcut('/2', templates), 'Second quick reply');
  });

  test('resolves named quick reply shortcut case-insensitively', () {
    final templates = [
      MessageTemplate(
        id: 'a',
        title: 'A',
        content: 'Named reply',
        variables: const [],
        createdAt: DateTime(2026),
        shortcut: '/Hello',
        isQuick: true,
      ),
    ];

    expect(resolveQuickReplyShortcut('/hello', templates), 'Named reply');
  });

  test('ignores normal message text', () {
    final templates = [
      MessageTemplate(
        id: 'a',
        title: 'A',
        content: 'Reply',
        variables: const [],
        createdAt: DateTime(2026),
        shortcut: '/hello',
        isQuick: true,
      ),
    ];

    expect(resolveQuickReplyShortcut('hello', templates), isNull);
  });

  test('ignores templates that are not marked as quick replies', () {
    final templates = [
      MessageTemplate(
        id: 'a',
        title: 'A',
        content: 'Normal template',
        variables: const [],
        createdAt: DateTime(2026),
        shortcut: '/hello',
        isQuick: false,
      ),
    ];

    expect(resolveQuickReplyShortcut('/1', templates), isNull);
    expect(resolveQuickReplyShortcut('/hello', templates), isNull);
  });

  test('rejects malformed and out-of-range shortcuts', () {
    final templates = [
      MessageTemplate(
        id: 'a',
        title: 'A',
        content: 'Reply',
        variables: const [],
        createdAt: DateTime(2026),
        shortcut: '/hello',
        isQuick: true,
      ),
    ];

    expect(normalizeQuickReplyShortcut('/hello world'), isNull);
    expect(resolveQuickReplyShortcut('/2', templates), isNull);
  });

  test('renders canned response variables for shortcut content', () {
    final templates = [
      MessageTemplate(
        id: 'a',
        title: 'A',
        content: 'Chào {{contact.name}}, hôm nay là {ngay_hom_nay}.',
        variables: const ['contact.name', 'ngay_hom_nay'],
        createdAt: DateTime(2026),
        shortcut: '/hello',
        isQuick: true,
      ),
    ];

    expect(
      resolveQuickReplyShortcut(
        '/hello',
        templates,
        variables: const {'contact.name': 'Minh', 'ngay_hom_nay': '29/06/2026'},
      ),
      'Chào Minh, hôm nay là 29/06/2026.',
    );
  });
}
