
import '../../../../mock/mock_messages.dart';

String? resolveQuickReplyShortcut(
  String input,
  List<MessageTemplate> templates,
) {
  final shortcut = normalizeQuickReplyShortcut(input);
  if (shortcut == null) return null;

  final quickTemplates = templates
      .where((template) => template.isQuick)
      .toList();
  final numeric = int.tryParse(shortcut.substring(1));
  if (numeric != null) {
    final index = numeric - 1;
    if (index >= 0 && index < quickTemplates.length) {
      return quickTemplates[index].content;
    }
    return null;
  }

  for (final template in quickTemplates) {
    final templateShortcut = normalizeQuickReplyShortcut(template.shortcut);
    if (templateShortcut == shortcut) return template.content;
  }
  return null;
}

String? normalizeQuickReplyShortcut(String input) {
  final trimmed = input.trim();
  if (!trimmed.startsWith('/') || trimmed.length < 2) return null;
  if (trimmed.contains(' ')) return null;
  return trimmed.toLowerCase();
}
