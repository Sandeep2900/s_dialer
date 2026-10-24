import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum ContactAccountType { phone, google, sim }

class ContactPhone {
  final String number;
  final String label;
  final bool isDefault;

  const ContactPhone({
    required this.number,
    this.label = 'Mobile',
    this.isDefault = false,
  });

  ContactPhone copyWith({String? number, String? label, bool? isDefault}) {
    return ContactPhone(
      number: number ?? this.number,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class ContactEmail {
  final String address;
  final String label;

  const ContactEmail({
    required this.address,
    this.label = 'Home',
  });
}

/// Rich Contact Entity matching Samsung Contacts specification
class ContactItem {
  final String id;
  final String displayName;
  final String firstName;
  final String lastName;
  final List<ContactPhone> phones;
  final List<ContactEmail> emails;
  final String? company;
  final String? address;
  final String? notes;
  final String? photoUri;
  final bool isFavorite;
  final bool isBlocked;
  final ContactAccountType accountType;

  const ContactItem({
    required this.id,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.phones = const [],
    this.emails = const [],
    this.company,
    this.address,
    this.notes,
    this.photoUri,
    this.isFavorite = false,
    this.isBlocked = false,
    this.accountType = ContactAccountType.phone,
  });

  /// Get primary number for call / SMS
  String get primaryNumber {
    if (phones.isEmpty) return '';
    final def = phones.firstWhere((p) => p.isDefault, orElse: () => phones.first);
    return def.number;
  }

  /// Initials (1-2 characters) for circular avatar
  String get initials {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) {
      final firstChar = parts[0].characters.firstOrNull ?? '';
      final secondChar = parts[1].characters.firstOrNull ?? '';
      final combined = '$firstChar$secondChar'.trim();
      return combined.isNotEmpty ? combined.toUpperCase() : '?';
    }
    return trimmed.characters.firstOrNull?.toUpperCase() ?? '?';
  }

  /// Samsung-style consistent color based on name hash
  Color get avatarColor => AppColors.getAvatarColor(displayName);

  ContactItem copyWith({
    String? id,
    String? displayName,
    String? firstName,
    String? lastName,
    List<ContactPhone>? phones,
    List<ContactEmail>? emails,
    String? company,
    String? address,
    String? notes,
    String? photoUri,
    bool? isFavorite,
    bool? isBlocked,
    ContactAccountType? accountType,
  }) {
    return ContactItem(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      company: company ?? this.company,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      photoUri: photoUri ?? this.photoUri,
      isFavorite: isFavorite ?? this.isFavorite,
      isBlocked: isBlocked ?? this.isBlocked,
      accountType: accountType ?? this.accountType,
    );
  }
}
