import 'package:characters/characters.dart';

/// High performance T9 predictive dialer search engine
class T9SearchService {
  T9SearchService._();

  static const Map<String, String> _charToDigit = {
    'a': '2', 'b': '2', 'c': '2',
    'd': '3', 'e': '3', 'f': '3',
    'g': '4', 'h': '4', 'i': '4',
    'j': '5', 'k': '5', 'l': '5',
    'm': '6', 'n': '6', 'o': '6',
    'p': '7', 'q': '7', 'r': '7', 's': '7',
    't': '8', 'u': '8', 'v': '8',
    'w': '9', 'x': '9', 'y': '9', 'z': '9',
  };

  /// Convert a text string to its T9 numeric representation
  static String textToT9(String text) {
    final buffer = StringBuffer();
    for (final char in text.characters) {
      final lower = char.toLowerCase();
      buffer.write(_charToDigit[lower] ?? lower);
    }
    return buffer.toString();
  }

  /// Check whether a contact matches a dialed numeric query either by T9 name or number substring
  static bool matches({
    required String queryDigits,
    required String displayName,
    required List<String> phoneNumbers,
  }) {
    if (queryDigits.isEmpty) return false;

    // 1. Direct phone number substring match
    for (final phone in phoneNumbers) {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.contains(queryDigits)) {
        return true;
      }
    }

    // 2. T9 Name matching (full name or word start matching)
    final t9Name = textToT9(displayName);
    if (t9Name.contains(queryDigits)) {
      return true;
    }

    // 3. Word initials matching (e.g. "JD" for John Doe -> "53")
    final words = displayName.split(RegExp(r'\s+'));
    final initialsT9 = words
        .where((w) => w.isNotEmpty)
        .map((w) => _charToDigit[(w.characters.firstOrNull ?? '').toLowerCase()] ?? '')
        .join();
    if (initialsT9.startsWith(queryDigits)) {
      return true;
    }

    return false;
  }
}
