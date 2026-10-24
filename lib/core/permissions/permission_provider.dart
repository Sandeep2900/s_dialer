import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'permission_service.dart';
import 'permission_state.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionsNotifier extends StateNotifier<AppPermissionsState> {
  final PermissionService _service;

  PermissionsNotifier(this._service)
      : super(
          kIsWeb
              ? const AppPermissionsState(
                  phone: PermissionStatus.granted,
                  contacts: PermissionStatus.granted,
                  callLog: PermissionStatus.granted,
                  sms: PermissionStatus.granted,
                )
              : const AppPermissionsState(),
        ) {
    if (!kIsWeb) {
      Future.microtask(() => checkAll());
    }
  }

  Future<void> checkAll() async {
    state = state.copyWith(isChecking: true);
    final newState = await _service.checkPermissions();
    state = newState;
  }

  Future<bool> requestCore() async {
    state = state.copyWith(isChecking: true);
    final newState = await _service.requestCorePermissions();
    state = newState;
    return newState.hasAllCorePermissions;
  }

  Future<void> openSettings() async {
    await _service.openSettings();
  }
}

final permissionsProvider =
    StateNotifierProvider<PermissionsNotifier, AppPermissionsState>((ref) {
  final service = ref.watch(permissionServiceProvider);
  return PermissionsNotifier(service);
});
