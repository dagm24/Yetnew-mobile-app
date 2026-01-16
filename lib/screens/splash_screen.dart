import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/household_service.dart';
import '../theme/app_colors.dart';
import 'family/setup_household_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 900));

    // If the splash screen is disposed (e.g., in widget tests), do nothing.
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else {
      final householdService = HouseholdService(FirebaseFirestore.instance);
      final householdId = await householdService.getUserHouseholdId(user.uid);
      if (!mounted) return;
      if (householdId == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupHouseholdScreen()),
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.authGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white,
                child: Icon(Icons.search, color: AppColors.deep, size: 42),
              ),
              SizedBox(height: 16),
              Text(
                'Yetnew',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
