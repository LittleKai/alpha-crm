import 'dart:math';

class ZaloTextFormatter {
  static String formatMarkdownToUnicode(String text) {
    String result = text;

    // Bold **text**
    result = result.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (match) {
      return _toUnicodeFormat(match.group(1) ?? '', _boldChars);
    });

    // Italic *text*
    result = result.replaceAllMapped(RegExp(r'\*(.*?)\*'), (match) {
      return _toUnicodeFormat(match.group(1) ?? '', _italicChars);
    });

    // Underline __text__
    result = result.replaceAllMapped(RegExp(r'__(.*?)__'), (match) {
      return _addCombiningMark(match.group(1) ?? '', '\u0332');
    });

    // Strikethrough ~~text~~
    result = result.replaceAllMapped(RegExp(r'~~(.*?)~~'), (match) {
      return _addCombiningMark(match.group(1) ?? '', '\u0336');
    });

    return result;
  }

  static String resolveVariablesAndSpintax(
    String text, {
    String? name,
    String? phone,
    String? group,
    bool randomizeSpintax = true,
    Random? random,
  }) {
    String result = text;
    if (name != null) result = result.replaceAll('{{tên}}', name);
    if (phone != null) result = result.replaceAll('{{sdt}}', phone);
    if (group != null) result = result.replaceAll('{{nhóm}}', group);

    if (name != null) {
      result = result.replaceAll(
        RegExp(r'\{\{\s*(tên|ten)\s*\}\}', caseSensitive: false),
        name,
      );
    }
    if (group != null) {
      result = result.replaceAll(
        RegExp(r'\{\{\s*(nhóm|nhom)\s*\}\}', caseSensitive: false),
        group,
      );
    }

    // Resolve Spintax {A|B|C}
    final spintaxRegex = RegExp(r'\{([^{}]*\|[^{}]*)\}');
    while (spintaxRegex.hasMatch(result)) {
      result = result.replaceAllMapped(spintaxRegex, (match) {
        final options = match.group(1)!.split('|');
        // We just take the first option for preview, or random for actual sending if needed?
        // Wait, if it's sending, we would pick randomly. Since this method can be used for both,
        // let's just pick the first option for consistency in preview, or maybe pick random?
        // Let's use the first one for preview, or random for sending.
        // I will use random.
        if (!randomizeSpintax) return options.first;
        return options[(random ?? Random()).nextInt(options.length)];
      });
    }
    return result;
  }

  static String renderZaloPreview(
    String text, {
    String name = 'Anh/Chị Khách Hàng',
    String phone = '0901234567',
    String group = 'Nhóm Zalo Demo',
  }) {
    final resolved = resolveVariablesAndSpintax(
      text,
      name: name,
      phone: phone,
      group: group,
      randomizeSpintax: false,
    );
    return formatMarkdownToUnicode(resolved);
  }

  static String _toUnicodeFormat(String text, Map<String, String> map) {
    return text.split('').map((char) => map[char] ?? char).join('');
  }

  static String _addCombiningMark(String text, String mark) {
    return text.split('').map((char) => '$char$mark').join('');
  }

  static const Map<String, String> _boldChars = {
    'a': '𝗮',
    'b': '𝗯',
    'c': '𝗰',
    'd': '𝗱',
    'e': '𝗲',
    'f': '𝗳',
    'g': '𝗴',
    'h': '𝗵',
    'i': '𝗶',
    'j': '𝗷',
    'k': '𝗸',
    'l': '𝗹',
    'm': '𝗺',
    'n': '𝗻',
    'o': '𝗼',
    'p': '𝗽',
    'q': '𝗾',
    'r': '𝗿',
    's': '𝘀',
    't': '𝘁',
    'u': '𝘂',
    'v': '𝘃',
    'w': '𝘄',
    'x': '𝘅',
    'y': '𝘆',
    'z': '𝘇',
    'A': '𝗔',
    'B': '𝗕',
    'C': '𝗖',
    'D': '𝗗',
    'E': '𝗘',
    'F': '𝗙',
    'G': '𝗚',
    'H': '𝗛',
    'I': '𝗜',
    'J': '𝗝',
    'K': '𝗞',
    'L': '𝗟',
    'M': '𝗠',
    'N': '𝗡',
    'O': '𝗢',
    'P': '𝗣',
    'Q': '𝗤',
    'R': '𝗥',
    'S': '𝗦',
    'T': '𝗧',
    'U': '𝗨',
    'V': '𝗩',
    'W': '𝗪',
    'X': '𝗫',
    'Y': '𝗬',
    'Z': '𝗭',
    '0': '𝟬',
    '1': '𝟭',
    '2': '𝟮',
    '3': '𝟯',
    '4': '𝟰',
    '5': '𝟱',
    '6': '𝟲',
    '7': '𝟳',
    '8': '𝟴',
    '9': '𝟵',
  };

  static const Map<String, String> _italicChars = {
    'a': '𝘢',
    'b': '𝘣',
    'c': '𝘤',
    'd': '𝘥',
    'e': '𝘦',
    'f': '𝘧',
    'g': '𝘨',
    'h': '𝘩',
    'i': '𝘪',
    'j': '𝘫',
    'k': '𝘬',
    'l': '𝘭',
    'm': '𝘮',
    'n': '𝘯',
    'o': '𝘰',
    'p': '𝘱',
    'q': '𝘲',
    'r': '𝘳',
    's': '𝘴',
    't': '𝘵',
    'u': '𝘶',
    'v': '𝘷',
    'w': '𝘸',
    'x': '𝘹',
    'y': '𝘺',
    'z': '𝘻',
    'A': '𝘈',
    'B': '𝘉',
    'C': '𝘊',
    'D': '𝘋',
    'E': '𝘌',
    'F': '𝘍',
    'G': '𝘎',
    'H': '𝘏',
    'I': '𝘐',
    'J': '𝘑',
    'K': '𝘒',
    'L': '𝘓',
    'M': '𝘔',
    'N': '𝘕',
    'O': '𝘖',
    'P': '𝘗',
    'Q': '𝘘',
    'R': '𝘙',
    'S': '𝘚',
    'T': '𝘛',
    'U': '𝘜',
    'V': '𝘝',
    'W': '𝘞',
    'X': '𝘟',
    'Y': '𝘠',
    'Z': '𝘡',
    '0': '0',
    '1': '1',
    '2': '2',
    '3': '3',
    '4': '4',
    '5': '5',
    '6': '6',
    '7': '7',
    '8': '8',
    '9': '9',
  };
}
