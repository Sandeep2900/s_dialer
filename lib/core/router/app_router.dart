import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/main_navigation_shell.dart';
import '../../features/keypad/presentation/screens/keypad_screen.dart';
import '../../features/recents/presentation/screens/recents_screen.dart';
import '../../features/recents/presentation/screens/call_detail_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/contacts/presentation/screens/contact_detail_screen.dart';
import '../../features/contacts/presentation/screens/contact_edit_screen.dart';
import '../../features/permissions/presentation/screens/permission_rationale_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/blocked_numbers_screen.dart';
import '../../data/models/contact_item.dart';
import '../../data/models/call_log_item.dart';
import '../../features/call/presentation/screens/in_call_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNav');

/// Application Router using GoRouter with StatefulShellRoute
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/keypad',
    debugLogDiagnostics: false,
    // Intercept tel: URIs that Android passes when launching via ACTION_DIAL/ACTION_CALL.
    // GoRouter has no route for tel: scheme — redirect to keypad to avoid crash.
    redirect: (context, state) {
      final location = state.uri.toString();
      if (location.startsWith('tel:') || location.startsWith('%2B') || location.contains('tel%3A')) {
        return '/keypad';
      }
      return null; // no redirect for normal routes
    },
    routes: [
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return navigationShell;
        },
        navigatorContainerBuilder: (context, navigationShell, children) {
          return MainNavigationShell(
            navigationShell: navigationShell,
            children: children,
          );
        },
        branches: [
          // Branch 0: Keypad
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/keypad',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: KeypadScreen(),
                ),
              ),
            ],
          ),
          // Branch 1: Recents
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recents',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RecentsScreen(),
                ),
              ),
            ],
          ),
          // Branch 2: Contacts
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ContactsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Recents Detail
      GoRoute(
        path: '/recents/detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          if (state.extra is CallLogItem) {
            return CallDetailScreen(callLog: state.extra as CallLogItem);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Call Details')),
            body: const Center(child: Text('No call details found')),
          );
        },
      ),
      // Contact Detail
      GoRoute(
        path: '/contacts/detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          if (state.extra is ContactItem) {
            return ContactDetailScreen(contact: state.extra as ContactItem);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Contact Details')),
            body: const Center(child: Text('Contact not found')),
          );
        },
      ),
      // Contact Add / Edit
      GoRoute(
        path: '/contacts/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return ContactEditScreen(initialData: state.extra);
        },
      ),
      // Permissions Rationale
      GoRoute(
        path: '/permissions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PermissionRationaleScreen(),
      ),
      // Settings
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'blocked',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const BlockedNumbersScreen(),
          ),
        ],
      ),
      // In-Call Screen
      GoRoute(
        path: '/in_call',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extraMap = state.extra is Map ? (state.extra as Map) : null;
          final number = extraMap?['number'] as String?;
          final name = extraMap?['name'] as String?;
          return CustomTransitionPage(
            key: state.pageKey,
            child: InCallScreen(
              initialNumber: number,
              initialName: name,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
    ],
  );
});
