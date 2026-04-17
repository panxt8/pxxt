import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/auth_controller.dart';
import '../features/home/main_shell_page.dart';

class PxxtApp extends StatelessWidget {
  const PxxtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PXXT',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
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
