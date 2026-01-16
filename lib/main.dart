import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/reset_success_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/devices/devices_list_screen.dart';
import 'screens/family/setup_household_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const YetNewApp());
}

class YetNewApp extends StatefulWidget {
  const YetNewApp({super.key});

  @override
  State<YetNewApp> createState() => _YetNewAppState();
}

class _YetNewAppState extends State<YetNewApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription? _linkSub;

  @override
  void initState() {
    super.initState();
    _initLinkHandling();
  }

  Future<void> _initLinkHandling() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleIncomingUri(initialUri);

      _linkSub = _appLinks.uriLinkStream.listen(_handleIncomingUri);
    } catch (_) {
      // No-op: deep links are an enhancement; app should still function.
    }
  }

  void _handleIncomingUri(Uri uri) {
    final qp = uri.queryParameters;
    final mode = qp['mode'];
    final oobCode = qp['oobCode'];
    if (mode == 'resetPassword' && oobCode != null && oobCode.isNotEmpty) {
      _navigatorKey.currentState?.pushNamed(
        '/reset-password',
        arguments: oobCode,
      );
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Yetnew',
      theme: buildAppTheme(),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/auth': (_) => const AuthScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/reset-password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final actionCodeFromArgs = args is String ? args : null;
          final actionCodeFromQuery = Uri.base.queryParameters['oobCode'];
          return ResetPasswordScreen(
            actionCode: actionCodeFromArgs ?? actionCodeFromQuery,
          );
        },
        '/reset-success': (_) => const ResetSuccessScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/devices': (_) => const DevicesListScreen(),
        '/setup-household': (_) => const SetupHouseholdScreen(),
      },
    );
  }
}
