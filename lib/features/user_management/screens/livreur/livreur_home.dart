import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dao/activity_log_dao.dart';
import '../../dao/delivery_agent_dao.dart';
import '../../dao/history_repository.dart';
import '../../models/activity_log.dart';
import '../../models/delivery_agent.dart';
import '../../providers/auth_provider.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/common_widgets.dart';
import '../common/delivery_history_view.dart';
import '../common/profile_screen.dart';
import 'permis_screen.dart';

/// Espace Livreur : disponibilité, statistiques, historique, profil.
/// ⚠️ Pour le groupe : l'écran « Livraisons en cours » appartient au module
/// Livraison et peut être ajouté comme onglet ici.
class LivreurHome extends StatefulWidget {
  const LivreurHome({super.key});
  @override
  State<LivreurHome> createState() => _LivreurHomeState();
}

class _LivreurHomeState extends State<LivreurHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final pages = [
      _LivreurDashboard(userId: user.id!),
      DeliveryHistoryView(livreurId: user.id!),
      ProfileScreen(extraTiles: [
        ListTile(
          leading: const Icon(Icons.two_wheeler),
          title: const Text('Mon véhicule'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _editVehicle(context, user.id!),
        ),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Mon permis de conduire'),
          subtitle: const Text('Document vérifié par l\'administrateur'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PermisScreen(userId: user.id!))),
        ),
      ]),
    ];
    const titles = ['Accueil', 'Mes livraisons', 'Mon profil'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }

  Future<void> _editVehicle(BuildContext context, int userId) async {
    final dao = DeliveryAgentDao();
    final profile = await dao.getProfile(userId);
    if (!context.mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Type de véhicule'),
        children: [
          for (final v in const ['Moto', 'Scooter', 'Vélo', 'Voiture'])
            ListTile(
              leading: Icon(v == profile.typeVehicule
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(v),
              onTap: () => Navigator.pop(c, v),
            ),
        ],
      ),
    );
    if (choice == null) return;
    await dao.save(profile.copyWith(typeVehicule: choice));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Véhicule : $choice')));
    }
  }
}

class _LivreurDashboard extends StatefulWidget {
  final int userId;
  const _LivreurDashboard({required this.userId});
  @override
  State<_LivreurDashboard> createState() => _LivreurDashboardState();
}

class _LivreurDashboardState extends State<_LivreurDashboard> {
  final _dao = DeliveryAgentDao();
  final _history = HistoryRepository();
  DeliveryAgent? _profile;
  int _today = 0;
  int _month = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final p = await _dao.getProfile(widget.userId);
    final t = await _history.countAgentDeliveriesSince(
        widget.userId, DateTime(now.year, now.month, now.day));
    final m = await _history.countAgentDeliveriesSince(
        widget.userId, DateTime(now.year, now.month));
    if (!mounted) return;
    setState(() {
      _profile = p;
      _today = t;
      _month = m;
    });
  }

  Future<void> _toggle(bool v) async {
    await _dao.setAvailability(widget.userId, v);
    await ActivityLogDao()
        .log(widget.userId, LogAction.availability, v ? 'En ligne' : 'Hors ligne');
    setState(() => _profile = _profile!.copyWith(disponible: v));
    // En ligne : on partage la position pour la carte du Manager.
    if (v) await _sharePosition(silent: true);
  }

  bool _locating = false;

  Future<void> _sharePosition({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final pos = await GeocodingService().currentPosition();
      await _dao.updatePosition(widget.userId, pos.latitude, pos.longitude);
      final p = await _dao.getProfile(widget.userId);
      if (!mounted) return;
      setState(() => _profile = p);
      if (!silent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Position partagée')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Position non partagée : $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p == null) return const Center(child: CircularProgressIndicator());
    final color = p.disponible ? Colors.green : Colors.grey;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: color.withValues(alpha: .08),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            secondary: Icon(Icons.power_settings_new, color: color, size: 36),
            title: Text(p.disponible ? 'Vous êtes en ligne' : 'Vous êtes hors ligne',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(p.disponible
                ? 'Vous pouvez recevoir des livraisons'
                : 'Activez pour recevoir des livraisons'),
            value: p.disponible,
            onChanged: _toggle,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: StatCard(
                label: 'Aujourd\'hui',
                value: '$_today',
                icon: Icons.today,
                color: Colors.orange),
          ),
          Expanded(
            child: StatCard(
                label: 'Ce mois',
                value: '$_month',
                icon: Icons.calendar_month,
                color: Colors.indigo),
          ),
        ]),
        Card(
          child: ListTile(
            leading: const Icon(Icons.two_wheeler),
            title: const Text('Véhicule'),
            trailing: Text(p.typeVehicule ?? 'Non renseigné'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.share_location,
                color: p.hasPosition ? Colors.green : Colors.grey),
            title: const Text('Ma position'),
            subtitle: Text(p.positionMaj == null
                ? 'Jamais partagée'
                : 'Mise à jour le ${formatDate(p.positionMaj!, withTime: true)}'),
            trailing: _locating
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    tooltip: 'Partager ma position',
                    icon: const Icon(Icons.my_location),
                    onPressed: () => _sharePosition(),
                  ),
          ),
        ),
        if (!p.hasPermis)
          Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: const Icon(Icons.badge_outlined, color: Colors.orange),
              title: const Text('Ajoute ton permis de conduire'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PermisScreen(userId: widget.userId)));
                _load();
              },
            ),
          ),
      ]),
    );
  }
}
