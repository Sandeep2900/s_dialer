import '../../data/models/contact_item.dart';

/// Service to serialize and parse standard vCard (.vcf) format
class VcfService {
  VcfService._();

  /// Export list of contacts to .vcf string
  static String exportToVcf(List<ContactItem> contacts) {
    final buffer = StringBuffer();
    for (final contact in contacts) {
      buffer.writeln('BEGIN:VCARD');
      buffer.writeln('VERSION:3.0');
      buffer.writeln('FN:${contact.displayName}');
      buffer.writeln('N:${contact.lastName};${contact.firstName};;;');
      if (contact.company != null && contact.company!.isNotEmpty) {
        buffer.writeln('ORG:${contact.company}');
      }
      for (final phone in contact.phones) {
        buffer.writeln('TEL;TYPE=${phone.label.toUpperCase()}:${phone.number}');
      }
      for (final email in contact.emails) {
        buffer.writeln('EMAIL;TYPE=INTERNET:${email.address}');
      }
      if (contact.notes != null && contact.notes!.isNotEmpty) {
        buffer.writeln('NOTE:${contact.notes}');
      }
      buffer.writeln('END:VCARD');
    }
    return buffer.toString();
  }

  /// Parse .vcf string into ContactItem list
  static List<ContactItem> importFromVcf(String vcfContent) {
    final List<ContactItem> result = [];
    final lines = vcfContent.split(RegExp(r'\r?\n'));

    String displayName = '';
    String firstName = '';
    String lastName = '';
    String? company;
    String? notes;
    List<ContactPhone> phones = [];
    List<ContactEmail> emails = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line == 'BEGIN:VCARD') {
        displayName = '';
        firstName = '';
        lastName = '';
        company = null;
        notes = null;
        phones = [];
        emails = [];
      } else if (line.startsWith('FN:')) {
        displayName = line.substring(3).trim();
      } else if (line.startsWith('N:')) {
        final parts = line.substring(2).split(';');
        if (parts.isNotEmpty) lastName = parts[0].trim();
        if (parts.length > 1) firstName = parts[1].trim();
      } else if (line.startsWith('ORG:')) {
        company = line.substring(4).trim();
      } else if (line.startsWith('NOTE:')) {
        notes = line.substring(5).trim();
      } else if (line.startsWith('TEL')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1) {
          final number = line.substring(colonIdx + 1).trim();
          phones.add(ContactPhone(number: number, label: 'Mobile'));
        }
      } else if (line.startsWith('EMAIL')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1) {
          final address = line.substring(colonIdx + 1).trim();
          emails.add(ContactEmail(address: address, label: 'Work'));
        }
      } else if (line == 'END:VCARD') {
        if (displayName.isEmpty && (firstName.isNotEmpty || lastName.isNotEmpty)) {
          displayName = '$firstName $lastName'.trim();
        }
        if (displayName.isNotEmpty || phones.isNotEmpty) {
          result.add(
            ContactItem(
              id: 'vcf_${DateTime.now().microsecondsSinceEpoch}_${result.length}',
              displayName: displayName.isNotEmpty ? displayName : (phones.isNotEmpty ? phones.first.number : 'Unknown'),
              firstName: firstName,
              lastName: lastName,
              phones: phones,
              emails: emails,
              company: company,
              notes: notes,
              accountType: ContactAccountType.phone,
            ),
          );
        }
      }
    }
    return result;
  }
}
