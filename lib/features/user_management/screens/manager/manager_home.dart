import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../admin/user_detail_screen.dart';
import '../admin/users_list_view.dart';
import '../common/profile_screen.dart';
import 'agents_list_view.dart';
import 'agents_map_view.dart';
import 'agents_ranking_view.dart';

/// Espace Manager : consultation des clients et des livreurs (lecture seule)
/// avec leurs historiques.
class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});
  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  int _index = 0;

  void _openDetail(User u) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UserDetailScreen(userId: u.id!, adminActions: false)),
      );

  @override
  Widget build(BuildContext context) {
    final pages = [
      UsersListView(fixedRole: UserRole.client, onOpen: _openDetail),
      AgentsListView(onOpen: _openDetail),
      AgentsMapView(onOpen: _openDetail),
      AgentsRankingView(onOpen: _openDetail),
      const ProfileScreen(),
    ];
    const titles = ['Clients', 'Livreurs', 'Carte des livreurs', 'Classement', 'Mon profil'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.delivery_dining), label: 'Livreurs'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Carte'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Classement'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
