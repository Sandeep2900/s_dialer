import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/telephony_service.dart';
import 'core/theme/app_theme.dart';
import 'features/call/data/models/call_state.dart';
import 'features/call/presentation/providers/call_provider.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch synchronous framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Captured Flutter Error: ${details.exceptionAsString()}');
  };

  // Catch unhandled asynchronous errors across isolates
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Captured Asynchronous Error: $error\n$stack');
    return true; // Handled, prevent app crash
  };

  // Graceful fallback UI in case any sub-widget throws an error
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Configure edge-to-edge transparent system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(
    const ProviderScope(
      child: SamDialerApp(),
    ),
  );
}

class SamDialerApp extends ConsumerStatefulWidget {
  const SamDialerApp({super.key});

  @override
  ConsumerState<SamDialerApp> createState() => _SamDialerAppState();
}

class _SamDialerAppState extends ConsumerState<SamDialerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupIncomingCallListeners();
    });
  }

  void _setupIncomingCallListeners() async {
    // 1. Listen to native showInCallScreen method channel calls
    ref.read(telephonyServiceProvider).setIncomingCallHandler((callData) {
      if (!mounted) return;
      _navigateToInCall(callData);
    });

    // 2. Check if launched cold with incoming/active call intent
    final initialCall = await ref.read(telephonyServiceProvider).getInitialCall();
    if (initialCall != null && initialCall.isNotEmpty && mounted) {
      _navigateToInCall(initialCall);
    }
  }

  void _navigateToInCall([Map<String, dynamic>? extra]) {
    final router = ref.read(appRouterProvider);
    final location = router.routerDelegate.currentConfiguration.uri.toString();
    if (!location.startsWith('/in_call')) {
      router.push('/in_call', extra: extra);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Global listener on callProvider: when state becomes ringing, dialing, or active,
    // ensure /in_call screen is presented immediately across the whole app
    ref.listen<CallState>(callProvider, (previous, next) {
      if (next.isRinging || next.isDialing || next.isConnected) {
        _navigateToInCall({
          'number': next.number,
          'name': next.name,
        });
      }
    });

    return MaterialApp.router(
      title: 'SamDialer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
