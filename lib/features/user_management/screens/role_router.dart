import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_logo.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'admin/admin_home.dart';
import 'auth/login_screen.dart';
import 'client/client_home.dart';
import 'livreur/livreur_home.dart';
import 'manager/manager_home.dart';

/// Point d'entrée du module : à mettre en `home:` du MaterialApp.
/// Affiche la connexion, puis l'espace correspondant au rôle connecté.
class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});
  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<AuthProvider>().init());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.initialized) {
      return const Scaffold(
        backgroundColor: AppColors.olive,
        body: Center(child: BninLogo(markSize: 64, wordColor: Colors.white)),
      );
    }
    final user = auth.currentUser;
    if (user == null) return const LoginScreen();
    // La clé force la reconstruction complète lors d'un changement de compte.
    return KeyedSubtree(
      key: ValueKey(user.id),
      child: switch (user.role) {
        UserRole.client => const ClientHome(),
        UserRole.admin => const AdminHome(),
        UserRole.manager => const ManagerHome(),
        UserRole.livreur => const LivreurHome(),
      },
    );
  }
}
