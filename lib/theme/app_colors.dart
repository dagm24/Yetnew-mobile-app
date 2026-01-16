import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color deep = Color(0xFF4A3461);
  static const Color purple = Color(0xFF634682);
  static const Color mid = Color(0xFF7C58A3);
  static const Color lavender = Color(0xFF967BB6);
  static const Color softLavender = Color(0xFFB099CB);
  static const Color paleLavender = Color(0xFFC9BADA);
  static const Color light = Color(0xFFE3DBEC);
  static const Color overlay = Color(0xFFF5F1F9);
  static const Color neutral = Color(0xFF6D6A7C);

  static const Color success = Color(0xFF18B24B);
  static const Color warning = Color(0xFFE9A93E);
  static const Color danger = Color(0xFFE65E5D);
  static const Color info = Color(0xFF1A73E8);

  static const Gradient authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      deep,
      purple,
      lavender,
    ],
  );

  static const Gradient onboardingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      lavender,
      softLavender,
      light,
    ],
  );
}

