import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/user_management/providers/auth_provider.dart';
import 'features/user_management/screens/role_router.dart';
import 'features/user_management/widgets/inactivity_guard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ...providers des autres modules
      ],
      child: const BninApp(),
    ),
  );
}

class BninApp extends StatelessWidget {
  const BninApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppTheme.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Déconnexion automatique après 30 min sans toucher l'écran.
      navigatorKey: AuthProvider.navigatorKey,
      builder: (context, child) => InactivityGuard(child: child!),
      home: const RoleRouter(),
    );
  }
}
