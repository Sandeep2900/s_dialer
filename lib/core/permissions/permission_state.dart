import 'package:permission_handler/permission_handler.dart';

/// State of permissions required by SamDialer
class AppPermissionsState {
  final PermissionStatus phone;
  final PermissionStatus contacts;
  final PermissionStatus callLog;
  final PermissionStatus sms;
  final bool isChecking;

  const AppPermissionsState({
    this.phone = PermissionStatus.denied,
    this.contacts = PermissionStatus.denied,
    this.callLog = PermissionStatus.denied,
    this.sms = PermissionStatus.denied,
    this.isChecking = false,
  });

  bool get isPhoneGranted => phone.isGranted;
  bool get isContactsGranted => contacts.isGranted;
  bool get isCallLogGranted => callLog.isGranted;

  /// Whether the core permissions (Phone, Contacts, Call Log) are all granted
  bool get hasAllCorePermissions =>
      isPhoneGranted && isContactsGranted && isCallLogGranted;

  /// Whether any permission is permanently denied (requires opening settings)
  bool get isPermanentlyDenied =>
      phone.isPermanentlyDenied ||
      contacts.isPermanentlyDenied ||
      callLog.isPermanentlyDenied;

  AppPermissionsState copyWith({
    PermissionStatus? phone,
    PermissionStatus? contacts,
    PermissionStatus? callLog,
    PermissionStatus? sms,
    bool? isChecking,
  }) {
    return AppPermissionsState(
      phone: phone ?? this.phone,
      contacts: contacts ?? this.contacts,
      callLog: callLog ?? this.callLog,
      sms: sms ?? this.sms,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}
