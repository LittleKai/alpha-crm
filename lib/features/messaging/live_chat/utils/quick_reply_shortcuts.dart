import '../../../../mock/mock_messages.dart';

String? resolveQuickReplyShortcut(
  String input,
  List<MessageTemplate> templates, {
  Map<String, String> variables = const {},
}) {
  final shortcut = normalizeQuickReplyShortcut(input);
  if (shortcut == null) return null;

  final quickTemplates = templates
      .where((template) => template.isQuick)
      .toList();
  final numeric = int.tryParse(shortcut.substring(1));
  if (numeric != null) {
    final index = numeric - 1;
    if (index >= 0 && index < quickTemplates.length) {
      return renderCannedResponse(quickTemplates[index].content, variables);
    }
    return null;
  }

  for (final template in quickTemplates) {
    final templateShortcut = normalizeQuickReplyShortcut(template.shortcut);
    if (templateShortcut == shortcut) {
      return renderCannedResponse(template.content, variables);
    }
  }
  return null;
}

String? normalizeQuickReplyShortcut(String input) {
  final trimmed = input.trim();
  if (!trimmed.startsWith('/') || trimmed.length < 2) return null;
  if (trimmed.contains(' ')) return null;
  return trimmed.toLowerCase();
}

String renderCannedResponse(String content, Map<String, String> variables) {
  if (variables.isEmpty) return content;
  var rendered = content;
  variables.forEach((key, value) {
    rendered = rendered
        .replaceAll('{{$key}}', value)
        .replaceAll('{{ $key }}', value)
        .replaceAll('{$key}', value);
  });
  return rendered;
}
