/// Utility class to format telephone numbers on the fly
class PhoneNumberFormatter {
  PhoneNumberFormatter._();

  /// Format raw number string for clean One UI display
  static String format(String rawNumber) {
    if (rawNumber.isEmpty) return '';

    // If it's a USSD code (contains * or #), do not format
    if (rawNumber.contains('*') || rawNumber.contains('#')) {
      return rawNumber;
    }

    final hasPlus = rawNumber.startsWith('+');
    final digits = rawNumber.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return hasPlus ? '+' : '';
    }

    if (hasPlus) {
      // International number formatting
      if (digits.length <= 3) {
        return '+$digits';
      } else if (digits.length <= 6) {
        return '+${digits.substring(0, 2)} ${digits.substring(2)}';
      } else if (digits.length <= 10) {
        return '+${digits.substring(0, 2)} ${digits.substring(2, 6)} ${digits.substring(6)}';
      } else if (digits.length <= 12) {
        return '+${digits.substring(0, 2)} ${digits.substring(2, 7)} ${digits.substring(7)}';
      } else {
        return '+${digits.substring(0, 3)} ${digits.substring(3, 7)} ${digits.substring(7)}';
      }
    } else {
      // Local / standard 7 to 10 digit formatting
      if (digits.length <= 3) {
        return digits;
      } else if (digits.length <= 7) {
        return '${digits.substring(0, 3)}-${digits.substring(3)}';
      } else if (digits.length <= 10) {
        return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
      } else {
        // More than 10 digits
        return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 10)} ${digits.substring(10)}';
      }
    }
  }

  /// Strip all formatting characters leaving only digits and leading plus
  static String normalize(String formattedNumber) {
    final trimmed = formattedNumber.trim();
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^\d*#]'), '');
    return hasPlus ? '+$digits' : digits;
  }
}
