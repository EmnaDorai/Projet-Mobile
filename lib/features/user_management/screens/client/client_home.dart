import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../common/order_history_view.dart';
import '../common/profile_screen.dart';
import 'addresses_screen.dart';
import 'loyalty_screen.dart';
import 'preferences_screen.dart';

/// Espace Client.
/// ⚠️ Pour le groupe : l'onglet « Menu » (module Menu/Commande) peut être
/// ajouté ici en première position.
class ClientHome extends StatefulWidget {
  const ClientHome({super.key});
  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final pages = [
      OrderHistoryView(clientId: user.id!),
      AddressesScreen(userId: user.id!),
      ProfileScreen(extraTiles: [
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const Text('Fidélité et parrainage'),
          subtitle: const Text('Mes points, mon niveau, mon code'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LoyaltyScreen(userId: user.id!))),
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('Mes préférences'),
          subtitle: const Text('Allergies, langue, notifications'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PreferencesScreen(userId: user.id!))),
        ),
      ]),
    ];
    const titles = ['Mes commandes', 'Mes adresses', 'Mon profil'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), label: 'Adresses'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
