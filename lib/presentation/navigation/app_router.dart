import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/devices/devices_screen.dart';
import '../screens/devices/add_edit_device_screen.dart';
import '../screens/devices/device_detail_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/devices',
        name: 'devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/devices/add',
        name: 'addDevice',
        builder: (context, state) => const AddEditDeviceScreen(),
      ),
      GoRoute(
        path: '/devices/:id',
        name: 'deviceDetail',
        builder: (context, state) => DeviceDetailScreen(deviceId: state.pathParameters['id']!),
      ),
    ],
  );
}

class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Dashboard')));
  }
}


