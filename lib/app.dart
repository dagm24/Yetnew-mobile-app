import 'package:flutter/material.dart';
import 'presentation/navigation/app_router.dart';
import 'core/theme/app_theme.dart';

class YetnewApp extends StatelessWidget {
  const YetnewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Yetnew',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}



