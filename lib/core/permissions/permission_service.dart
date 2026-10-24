import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'permission_state.dart';

/// Service for handling Android runtime permissions for Phone, Contacts, Call Log, and SMS
class PermissionService {
  /// Check current status of all relevant dialer permissions
  Future<AppPermissionsState> checkPermissions() async {
    if (kIsWeb) {
      return const AppPermissionsState(
        phone: PermissionStatus.granted,
        contacts: PermissionStatus.granted,
        callLog: PermissionStatus.granted,
        sms: PermissionStatus.granted,
        isChecking: false,
      );
    }

    try {
      final phone = await Permission.phone.status;
      final contacts = await Permission.contacts.status;
      final callLog = await Permission.phone.status;
      final sms = await Permission.sms.status;

      return AppPermissionsState(
        phone: phone,
        contacts: contacts,
        callLog: callLog,
        sms: sms,
        isChecking: false,
      );
    } catch (_) {
      return const AppPermissionsState(
        phone: PermissionStatus.denied,
        contacts: PermissionStatus.denied,
        callLog: PermissionStatus.denied,
        sms: PermissionStatus.denied,
        isChecking: false,
      );
    }
  }

  /// Request core dialer permissions contextually
  Future<AppPermissionsState> requestCorePermissions() async {
    if (kIsWeb) {
      return const AppPermissionsState(
        phone: PermissionStatus.granted,
        contacts: PermissionStatus.granted,
        callLog: PermissionStatus.granted,
        sms: PermissionStatus.granted,
        isChecking: false,
      );
    }
    try {
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.phone,
        Permission.contacts,
      ].request();

      final phoneStatus = statuses[Permission.phone] ?? PermissionStatus.denied;
      final contactsStatus = statuses[Permission.contacts] ?? PermissionStatus.denied;

      return AppPermissionsState(
        phone: phoneStatus,
        contacts: contactsStatus,
        callLog: phoneStatus,
        isChecking: false,
      );
    } catch (_) {
      return const AppPermissionsState(
        phone: PermissionStatus.denied,
        contacts: PermissionStatus.denied,
        callLog: PermissionStatus.denied,
        isChecking: false,
      );
    }
  }

  /// Request individual permission
  Future<PermissionStatus> requestPermission(Permission permission) async {
    return await permission.request();
  }

  /// Direct user to application settings if permissions were permanently denied
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
