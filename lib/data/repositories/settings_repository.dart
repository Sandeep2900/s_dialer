import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool dtmfSoundEnabled;
  final bool hapticsEnabled;
  final bool sortByLastName;
  final String contactsAccountFilter; // 'all', 'phone', 'google'
  final List<String> blockedNumbers;
  final String? lastSyncedTimestamp;

  const SettingsState({
    this.dtmfSoundEnabled = true,
    this.hapticsEnabled = true,
    this.sortByLastName = false,
    this.contactsAccountFilter = 'all',
    this.blockedNumbers = const [],
    this.lastSyncedTimestamp,
  });

  SettingsState copyWith({
    bool? dtmfSoundEnabled,
    bool? hapticsEnabled,
    bool? sortByLastName,
    String? contactsAccountFilter,
    List<String>? blockedNumbers,
    String? lastSyncedTimestamp,
  }) {
    return SettingsState(
      dtmfSoundEnabled: dtmfSoundEnabled ?? this.dtmfSoundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      sortByLastName: sortByLastName ?? this.sortByLastName,
      contactsAccountFilter: contactsAccountFilter ?? this.contactsAccountFilter,
      blockedNumbers: blockedNumbers ?? this.blockedNumbers,
      lastSyncedTimestamp: lastSyncedTimestamp ?? this.lastSyncedTimestamp,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const String _keyDtmf = 'keypad_dtmf_enabled';
  static const String _keyHaptics = 'keypad_haptics_enabled';
  static const String _keySort = 'contacts_sort_last_name';
  static const String _keyFilter = 'contacts_account_filter';
  static const String _keyBlocked = 'blocked_phone_numbers';
  static const String _keySyncTime = 'google_last_sync_time';

  SettingsNotifier() : super(const SettingsState()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      dtmfSoundEnabled: prefs.getBool(_keyDtmf) ?? true,
      hapticsEnabled: prefs.getBool(_keyHaptics) ?? true,
      sortByLastName: prefs.getBool(_keySort) ?? false,
      contactsAccountFilter: prefs.getString(_keyFilter) ?? 'all',
      blockedNumbers: prefs.getStringList(_keyBlocked) ?? [],
      lastSyncedTimestamp: prefs.getString(_keySyncTime),
    );
  }

  Future<void> toggleDtmf(bool value) async {
    state = state.copyWith(dtmfSoundEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDtmf, value);
  }

  Future<void> toggleHaptics(bool value) async {
    state = state.copyWith(hapticsEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptics, value);
  }

  Future<void> toggleSortByLastName(bool value) async {
    state = state.copyWith(sortByLastName: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySort, value);
  }

  Future<void> setContactsAccountFilter(String filter) async {
    state = state.copyWith(contactsAccountFilter: filter);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFilter, filter);
  }

  Future<void> blockNumber(String number) async {
    final clean = number.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty || state.blockedNumbers.contains(clean)) return;
    final updated = List<String>.from(state.blockedNumbers)..add(clean);
    state = state.copyWith(blockedNumbers: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBlocked, updated);
  }

  Future<void> unblockNumber(String number) async {
    final clean = number.replaceAll(RegExp(r'\D'), '');
    final updated = List<String>.from(state.blockedNumbers)..remove(clean);
    state = state.copyWith(blockedNumbers: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBlocked, updated);
  }

  Future<void> setLastSyncedTimestamp(String timestamp) async {
    state = state.copyWith(lastSyncedTimestamp: timestamp);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncTime, timestamp);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
