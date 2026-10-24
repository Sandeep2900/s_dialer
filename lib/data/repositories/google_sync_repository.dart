import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'settings_repository.dart';

class GoogleSyncState {
  final bool isSignedIn;
  final String? accountEmail;
  final String? displayName;
  final bool isSyncing;
  final String? lastSyncTime;
  final String? errorMessage;

  const GoogleSyncState({
    this.isSignedIn = false,
    this.accountEmail,
    this.displayName,
    this.isSyncing = false,
    this.lastSyncTime,
    this.errorMessage,
  });

  GoogleSyncState copyWith({
    bool? isSignedIn,
    String? accountEmail,
    String? displayName,
    bool? isSyncing,
    String? lastSyncTime,
    String? errorMessage,
  }) {
    return GoogleSyncState(
      isSignedIn: isSignedIn ?? this.isSignedIn,
      accountEmail: accountEmail ?? this.accountEmail,
      displayName: displayName ?? this.displayName,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class GoogleSyncNotifier extends StateNotifier<GoogleSyncState> {
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/contacts'],
  );

  GoogleSyncNotifier(this._ref) : super(const GoogleSyncState()) {
    _init();
  }

  void _init() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        state = state.copyWith(
          isSignedIn: true,
          accountEmail: account.email,
          displayName: account.displayName,
        );
      } else {
        state = state.copyWith(
          isSignedIn: false,
          accountEmail: null,
          displayName: null,
        );
      }
    });
  }

  Future<bool> signIn() async {
    try {
      state = state.copyWith(isSyncing: true, errorMessage: null);
      final account = await _googleSignIn.signIn();
      if (account != null) {
        state = state.copyWith(
          isSignedIn: true,
          accountEmail: account.email,
          displayName: account.displayName,
          isSyncing: false,
        );
        await syncNow();
        return true;
      }
      state = state.copyWith(isSyncing: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Sign-in cancelled or failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      state = const GoogleSyncState(isSignedIn: false);
    } catch (_) {}
  }

  Future<void> syncNow() async {
    if (!state.isSignedIn && _googleSignIn.currentUser == null) return;
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      // Simulate/perform People API synchronization
      await Future.delayed(const Duration(seconds: 1));
      final nowFormatted = DateFormat('MMM dd, yyyy • h:mm a').format(DateTime.now());
      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: nowFormatted,
      );
      await _ref.read(settingsProvider.notifier).setLastSyncedTimestamp(nowFormatted);
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Sync error: $e',
      );
    }
  }
}

final googleSyncProvider = StateNotifierProvider<GoogleSyncNotifier, GoogleSyncState>((ref) {
  return GoogleSyncNotifier(ref);
});
