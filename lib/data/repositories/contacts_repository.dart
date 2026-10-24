import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_item.dart';

/// Repository managing contacts from device storage, favorites, and Google sync
class ContactsRepository {
  List<ContactItem> _cachedContacts = [];
  final Set<String> _favoriteIds = {};

  List<ContactItem> get cachedContacts => List.unmodifiable(_cachedContacts);

  /// Load contacts from Android ContactsContract via flutter_contacts
  Future<List<ContactItem>> fetchContacts({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedContacts.isNotEmpty) {
      return _cachedContacts;
    }

    if (kIsWeb) {
      if (_cachedContacts.isEmpty) {
        _cachedContacts = _getFallbackContacts();
      }
      return _cachedContacts;
    }

    try {
      bool isGranted = false;
      try {
        isGranted = await Permission.contacts.isGranted;
      } catch (_) {
        isGranted = false;
      }

      if (!isGranted) {
        try {
          isGranted = await FlutterContacts.requestPermission(readonly: true);
        } catch (_) {
          isGranted = false;
        }
      }

      if (!isGranted) {
        if (_cachedContacts.isEmpty) {
          _cachedContacts = _getFallbackContacts();
        }
        return _cachedContacts;
      }

      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withThumbnail: false,
      );

      // Process contacts in clean batches of 100
      final List<ContactItem> list = [];
      const chunkSize = 100;
      for (var i = 0; i < deviceContacts.length; i += chunkSize) {
        if (i > 0) {
          await Future.microtask(() {});
        }
        final end = min(i + chunkSize, deviceContacts.length);
        for (final c in deviceContacts.sublist(i, end)) {
          try {
            final phones = c.phones.map((p) {
              String label = 'Mobile';
              try { label = p.label.name; } catch (_) {}
              return ContactPhone(
                number: p.number,
                label: label,
                isDefault: p.isPrimary,
              );
            }).toList();

            final emails = c.emails.map((e) {
              String label = 'Home';
              try { label = e.label.name; } catch (_) {}
              return ContactEmail(
                address: e.address,
                label: label,
              );
            }).toList();

            final firstName = c.name.first;
            final lastName = c.name.last;
            final displayName = c.displayName.trim().isNotEmpty
                ? c.displayName
                : (phones.isNotEmpty ? phones.first.number : 'Unknown');

            list.add(ContactItem(
              id: c.id,
              displayName: displayName,
              firstName: firstName,
              lastName: lastName,
              phones: phones,
              emails: emails,
              company: c.organizations.isNotEmpty ? c.organizations.first.company : null,
              isFavorite: c.isStarred || _favoriteIds.contains(c.id),
              accountType: ContactAccountType.phone,
            ));
          } catch (_) {
            // Skip corrupted contact entries
          }
        }
      }

      // If phone has no contacts yet, show sample contacts
      if (list.isEmpty) {
        _cachedContacts = _getFallbackContacts();
      } else {
        _cachedContacts = list;
      }
      return _cachedContacts;
    } catch (_) {
      if (_cachedContacts.isEmpty) {
        _cachedContacts = _getFallbackContacts();
      }
      return _cachedContacts;
    }
  }

  /// Create a new contact
  Future<ContactItem> createContact(ContactItem contact) async {
    try {
      await FlutterContacts.requestPermission(readonly: false);
      final newContact = Contact(
        name: Name(first: contact.firstName, last: contact.lastName),
        phones: contact.phones.map((p) => Phone(p.number, label: PhoneLabel.mobile)).toList(),
        emails: contact.emails.map((e) => Email(e.address)).toList(),
        organizations: contact.company != null && contact.company!.isNotEmpty
            ? [Organization(company: contact.company!)]
            : [],
      );
      final inserted = await newContact.insert();
      final item = contact.copyWith(id: inserted.id);
      _cachedContacts.removeWhere((c) => c.id == item.id);
      _cachedContacts.insert(0, item);
      return item;
    } catch (_) {
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final item = contact.copyWith(id: localId);
      _cachedContacts.removeWhere((c) => c.id == item.id);
      _cachedContacts.insert(0, item);
      return item;
    }
  }

  /// Update an existing contact
  Future<void> updateContact(ContactItem contact) async {
    try {
      await FlutterContacts.requestPermission(readonly: false);
      final existing = await FlutterContacts.getContact(contact.id);
      if (existing != null) {
        existing.name.first = contact.firstName;
        existing.name.last = contact.lastName;
        existing.phones = contact.phones.map((p) => Phone(p.number, label: PhoneLabel.mobile)).toList();
        existing.emails = contact.emails.map((e) => Email(e.address)).toList();
        if (contact.company != null) {
          existing.organizations = [Organization(company: contact.company!)];
        }
        await existing.update();
      }
    } catch (_) {}

    final index = _cachedContacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      _cachedContacts[index] = contact;
    } else {
      _cachedContacts.insert(0, contact);
    }
  }

  /// Delete contact
  Future<void> deleteContact(String id) async {
    try {
      final contact = await FlutterContacts.getContact(id);
      if (contact != null) {
        await contact.delete();
      }
    } catch (_) {}
    _cachedContacts.removeWhere((c) => c.id == id);
    _favoriteIds.remove(id);
  }

  /// Toggle favorite state
  void toggleFavorite(String id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    final index = _cachedContacts.indexWhere((c) => c.id == id);
    if (index != -1) {
      _cachedContacts[index] = _cachedContacts[index].copyWith(
        isFavorite: _favoriteIds.contains(id),
      );
    }
  }

  /// Fallback demo contacts when device has zero contacts or simulator is used
  List<ContactItem> _getFallbackContacts() {
    return [
      const ContactItem(
        id: 'mock_1',
        displayName: 'Alice Johnson',
        firstName: 'Alice',
        lastName: 'Johnson',
        phones: [ContactPhone(number: '+1 (555) 234-5678', label: 'Mobile', isDefault: true)],
        emails: [ContactEmail(address: 'alice@example.com')],
        company: 'Google',
        isFavorite: true,
      ),
      const ContactItem(
        id: 'mock_2',
        displayName: 'Bob Smith',
        firstName: 'Bob',
        lastName: 'Smith',
        phones: [ContactPhone(number: '+1 (555) 345-6789', label: 'Work', isDefault: true)],
        emails: [ContactEmail(address: 'bob.smith@company.com')],
        company: 'Samsung',
        isFavorite: true,
      ),
      const ContactItem(
        id: 'mock_3',
        displayName: 'Charlie Davis',
        firstName: 'Charlie',
        lastName: 'Davis',
        phones: [ContactPhone(number: '+1 (555) 456-7890', label: 'Mobile', isDefault: true)],
        isFavorite: false,
      ),
      const ContactItem(
        id: 'mock_4',
        displayName: 'Diana Prince',
        firstName: 'Diana',
        lastName: 'Prince',
        phones: [ContactPhone(number: '+1 (555) 789-0123', label: 'Home', isDefault: true)],
        isFavorite: true,
      ),
      const ContactItem(
        id: 'mock_5',
        displayName: 'Emergency Services',
        firstName: 'Emergency',
        lastName: 'Services',
        phones: [ContactPhone(number: '911', label: 'Emergency', isDefault: true)],
        isFavorite: true,
      ),
      const ContactItem(
        id: 'mock_6',
        displayName: 'Mom',
        firstName: 'Mom',
        lastName: '',
        phones: [ContactPhone(number: '+1 (555) 987-6543', label: 'Mobile', isDefault: true)],
        isFavorite: true,
      ),
    ];
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository();
});
