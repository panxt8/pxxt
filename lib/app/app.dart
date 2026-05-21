import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme_controller.dart';
import '../features/auth/auth_controller.dart';
import '../features/home/main_shell_page.dart';

class PxxtApp extends StatelessWidget {
  const PxxtApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppThemeController>().themeMode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PXXT',
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: Consumer<AuthController>(
        builder: (context, auth, _) {
          if (!auth.ready) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const MainShellPage();
        },
      ),
    );
  }
}
