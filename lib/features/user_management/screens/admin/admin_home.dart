import 'package:flutter/material.dart';

import '../common/profile_screen.dart';
import 'activity_logs_view.dart';
import 'admin_dashboard_view.dart';
import 'users_list_view.dart';

/// Espace Administrateur.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;
  // Les clés permettent de rafraîchir un onglet quand on y revient.
  final _keys = List.generate(3, (_) => UniqueKey());

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboardView(key: _keys[0]),
      UsersListView(key: _keys[1], admin: true),
      ActivityLogsView(key: _keys[2]),
      const ProfileScreen(),
    ];
    const titles = ['Tableau de bord', 'Utilisateurs', 'Journal d\'activité', 'Mon profil'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          if (i < 3) _keys[i] = UniqueKey();
          _index = i;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Utilisateurs'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
