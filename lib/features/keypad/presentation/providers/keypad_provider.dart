import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/phone_number_formatter.dart';
import '../../../../core/services/t9_search_service.dart';
import '../../../../core/services/telephony_service.dart';
import '../../../../data/models/contact_item.dart';
import '../../../../data/repositories/contacts_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../call/presentation/providers/call_provider.dart';

class KeypadState {
  final String rawNumber;
  final String formattedNumber;
  final List<ContactItem> suggestions;

  const KeypadState({
    this.rawNumber = '',
    this.formattedNumber = '',
    this.suggestions = const [],
  });

  KeypadState copyWith({
    String? rawNumber,
    String? formattedNumber,
    List<ContactItem>? suggestions,
  }) {
    return KeypadState(
      rawNumber: rawNumber ?? this.rawNumber,
      formattedNumber: formattedNumber ?? this.formattedNumber,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

class KeypadNotifier extends StateNotifier<KeypadState> {
  final Ref _ref;

  KeypadNotifier(this._ref) : super(const KeypadState());

  void pressDigit(String digit) {
    final settings = _ref.read(settingsProvider);
    if (settings.dtmfSoundEnabled) {
      _ref.read(telephonyServiceProvider).playDtmfTone(digit);
    }
    if (settings.hapticsEnabled) {
      HapticFeedback.lightImpact();
    }

    final newRaw = state.rawNumber + digit;
    _updateNumber(newRaw);
  }

  void pressBackspace() {
    final settings = _ref.read(settingsProvider);
    if (settings.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }

    if (state.rawNumber.isNotEmpty) {
      final newRaw = state.rawNumber.substring(0, state.rawNumber.length - 1);
      _updateNumber(newRaw);
    }
  }

  void clearAll() {
    final settings = _ref.read(settingsProvider);
    if (settings.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    _updateNumber('');
  }

  void setNumber(String number) {
    _updateNumber(PhoneNumberFormatter.normalize(number));
  }

  void _updateNumber(String raw) {
    final formatted = PhoneNumberFormatter.format(raw);
    final allContacts = _ref.read(contactsRepositoryProvider).cachedContacts;

    List<ContactItem> matches = [];
    if (raw.isNotEmpty) {
      final cleanQuery = raw.replaceAll(RegExp(r'\D'), '');
      if (cleanQuery.isNotEmpty) {
        matches = allContacts.where((c) {
          final phones = c.phones.map((p) => p.number).toList();
          return T9SearchService.matches(
            queryDigits: cleanQuery,
            displayName: c.displayName,
            phoneNumbers: phones,
          );
        }).take(5).toList();
      }
    }

    state = state.copyWith(
      rawNumber: raw,
      formattedNumber: formatted,
      suggestions: matches,
    );
  }

  Future<bool> makeCall([String? targetNumber]) async {
    final number = targetNumber ?? state.rawNumber;
    if (number.trim().isEmpty) return false;
    final settings = _ref.read(settingsProvider);
    if (settings.hapticsEnabled) {
      HapticFeedback.heavyImpact();
    }

    String? contactName;
    try {
      final contacts = _ref.read(contactsRepositoryProvider).cachedContacts;
      final cleanNum = number.replaceAll(RegExp(r'\D'), '');
      final match = contacts.firstWhere(
        (c) => c.phones.any((p) => p.number.replaceAll(RegExp(r'\D'), '') == cleanNum),
        orElse: () => ContactItem(id: '', displayName: '', phones: const []),
      );
      if (match.displayName.isNotEmpty) {
        contactName = match.displayName;
      }
    } catch (_) {}

    return await _ref.read(callProvider.notifier).startOutgoingCall(
      number: number,
      name: contactName,
    );
  }
}

final keypadProvider = StateNotifierProvider<KeypadNotifier, KeypadState>((ref) {
  return KeypadNotifier(ref);
});
