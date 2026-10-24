import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/contact_item.dart';
import '../../../../data/repositories/contacts_repository.dart';
import '../../../../data/repositories/settings_repository.dart';

class ContactsState {
  final List<ContactItem> allContacts;
  final List<ContactItem> favorites;
  final List<ContactItem> searchResults;
  final Map<String, List<ContactItem>> groupedSections;
  final List<String> availableLetters;
  final String searchQuery;
  final bool isLoading;

  const ContactsState({
    this.allContacts = const [],
    this.favorites = const [],
    this.searchResults = const [],
    this.groupedSections = const {},
    this.availableLetters = const [],
    this.searchQuery = '',
    this.isLoading = false,
  });

  ContactsState copyWith({
    List<ContactItem>? allContacts,
    List<ContactItem>? favorites,
    List<ContactItem>? searchResults,
    Map<String, List<ContactItem>>? groupedSections,
    List<String>? availableLetters,
    String? searchQuery,
    bool? isLoading,
  }) {
    return ContactsState(
      allContacts: allContacts ?? this.allContacts,
      favorites: favorites ?? this.favorites,
      searchResults: searchResults ?? this.searchResults,
      groupedSections: groupedSections ?? this.groupedSections,
      availableLetters: availableLetters ?? this.availableLetters,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ContactsNotifier extends StateNotifier<ContactsState> {
  final Ref _ref;

  ContactsNotifier(this._ref) : super(const ContactsState()) {
    Future.microtask(() => loadContacts());
  }

  Future<void> loadContacts({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true);
    final repo = _ref.read(contactsRepositoryProvider);
    final contacts = await repo.fetchContacts(forceRefresh: forceRefresh);
    _processContacts(contacts, state.searchQuery);
  }

  void search(String query) {
    _processContacts(state.allContacts, query);
  }

  void toggleFavorite(String id) {
    _ref.read(contactsRepositoryProvider).toggleFavorite(id);
    final updated = state.allContacts.map((c) {
      if (c.id == id) {
        return c.copyWith(isFavorite: !c.isFavorite);
      }
      return c;
    }).toList();
    _processContacts(updated, state.searchQuery);
  }

  Future<void> deleteContact(String id) async {
    await _ref.read(contactsRepositoryProvider).deleteContact(id);
    final updated = state.allContacts.where((c) => c.id != id).toList();
    _processContacts(updated, state.searchQuery);
  }

  void _processContacts(List<ContactItem> contacts, String query) {
    final settings = _ref.read(settingsProvider);
    final accountFilter = settings.contactsAccountFilter;
    final sortByLastName = settings.sortByLastName;

    // Filter by account
    var filtered = contacts.where((c) {
      if (accountFilter == 'phone' && c.accountType != ContactAccountType.phone) return false;
      if (accountFilter == 'google' && c.accountType != ContactAccountType.google) return false;
      return true;
    }).toList();

    // Filter by search query with intelligent normalization
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      final q = trimmedQuery.toLowerCase();
      final qDigits = trimmedQuery.replaceAll(RegExp(r'\D'), '');
      final queryTokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      filtered = filtered.where((c) {
        final name = c.displayName.toLowerCase();
        final company = c.company?.toLowerCase() ?? '';
        final emails = c.emails.map((e) => e.address.toLowerCase()).join(' ');

        // Check if all tokens match text properties
        final matchesTokens = queryTokens.every((token) =>
            name.contains(token) || company.contains(token) || emails.contains(token));

        // Check if phone numbers match (raw or stripped digits)
        final matchesPhone = c.phones.any((p) {
          final pRaw = p.number.toLowerCase();
          final pDigits = p.number.replaceAll(RegExp(r'\D'), '');
          return pRaw.contains(q) || (qDigits.isNotEmpty && pDigits.contains(qDigits));
        });

        return matchesTokens || matchesPhone;
      }).toList();
    }

    // Sort contacts
    filtered.sort((a, b) {
      final keyA = sortByLastName && a.lastName.isNotEmpty ? a.lastName : a.displayName;
      final keyB = sortByLastName && b.lastName.isNotEmpty ? b.lastName : b.displayName;
      return keyA.toLowerCase().compareTo(keyB.toLowerCase());
    });

    final favorites = filtered.where((c) => c.isFavorite).toList();
    final searchResults = trimmedQuery.isNotEmpty ? filtered : <ContactItem>[];

    // Group into sections A-Z, # (fast character code check without recompiling RegExp)
    final Map<String, List<ContactItem>> groups = {};
    for (final contact in filtered) {
      final keyName = (sortByLastName && contact.lastName.isNotEmpty)
          ? contact.lastName
          : contact.displayName;
      final trimmed = keyName.trim();
      String letter = '#';
      if (trimmed.isNotEmpty) {
        final code = trimmed.codeUnitAt(0);
        if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
          letter = trimmed[0].toUpperCase();
        }
      }
      groups.putIfAbsent(letter, () => []).add(contact);
    }

    final letters = groups.keys.toList()..sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    state = state.copyWith(
      allContacts: contacts,
      favorites: favorites,
      searchResults: searchResults,
      groupedSections: groups,
      availableLetters: letters,
      searchQuery: query,
      isLoading: false,
    );
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  return ContactsNotifier(ref);
});
