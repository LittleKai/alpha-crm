extension SafeString on String {
  /// Returns a copy of this string with any malformed UTF-16 surrogate pairs
  /// replaced by the Unicode replacement character (U+FFFD).
  ///
  /// This prevents ArgumentError (Invalid argument(s): string is not well-formed UTF-16)
  /// when passing strings to native paragraph/text rendering.
  String toWellFormed() {
    final units = codeUnits;
    final cleanUnits = <int>[];
    for (int i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        // High surrogate
        if (i + 1 < units.length) {
          final next = units[i + 1];
          if (next >= 0xDC00 && next <= 0xDFFF) {
            // Valid surrogate pair
            cleanUnits.add(unit);
            cleanUnits.add(next);
            i++; // skip next
            continue;
          }
        }
        // Unpaired high surrogate
        cleanUnits.add(0xFFFD);
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        // Unpaired low surrogate
        cleanUnits.add(0xFFFD);
      } else {
        // Normal character
        cleanUnits.add(unit);
      }
    }
    return String.fromCharCodes(cleanUnits);
  }
}
