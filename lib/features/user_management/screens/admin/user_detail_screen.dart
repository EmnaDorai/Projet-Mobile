import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dao/activity_log_dao.dart';
import '../../dao/delivery_agent_dao.dart';
import '../../dao/history_repository.dart';
import '../../dao/user_dao.dart';
import '../../models/activity_log.dart';
import '../../models/delivery_agent.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/password_hasher.dart';
import '../../widgets/common_widgets.dart';
import '../common/delivery_history_view.dart';
import '../common/order_history_view.dart';
import 'account_status_action.dart';
import 'activity_logs_view.dart';

/// Fiche utilisateur : infos + historique (+ actions si [adminActions]).
/// Admin : adminActions = true. Manager : adminActions = false (lecture seule).
class UserDetailScreen extends StatefulWidget {
  final int userId;
  final bool adminActions;
  const UserDetailScreen({super.key, required this.userId, this.adminActions = true});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _admin = AdminService();
  User? _user;
  DeliveryAgent? _agent;
  ({int nbCommandes, double totalDepense})? _clientStats;
  int? _livraisons30j;

  int get _me => context.read<AuthProvider>().currentUser!.id!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await UserDao().getById(widget.userId);
    DeliveryAgent? agent;
    ({int nbCommandes, double totalDepense})? stats;
    int? liv;
    if (u?.role == UserRole.livreur) {
      agent = await DeliveryAgentDao().getProfile(u!.id!);
      liv = await HistoryRepository().countAgentDeliveriesSince(
          u.id!, DateTime.now().subtract(const Duration(days: 30)));
    } else if (u?.role == UserRole.client) {
      stats = await HistoryRepository().getClientStats(u!.id!);
    }
    if (!mounted) return;
    setState(() {
      _user = u;
      _agent = agent;
      _clientStats = stats;
      _livraisons30j = liv;
    });
  }

  // ───────────── Actions Admin ─────────────
  Future<void> _changeRole() async {
    final role = await showDialog<UserRole>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Changer le rôle'),
        children: [
          for (final r in UserRole.values)
            ListTile(
              leading: Icon(r == _user!.role
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(r.label),
              onTap: () => Navigator.pop(c, r),
            ),
        ],
      ),
    );
    if (role == null || role == _user!.role || !mounted) return;
    await runWithFeedback(context, () => _admin.changeRole(_me, _user!, role),
        success: 'Rôle modifié');
    _load();
  }

  Future<void> _toggleBlock() async {
    if (await toggleAccountStatus(context, _user!)) _load();
  }

  Future<void> _resetPassword() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Réinitialiser le mot de passe'),
        content: Form(
          key: formKey,
          child: PasswordField(
              controller: ctrl,
              label: 'Nouveau mot de passe',
              validator: PasswordHasher.validate),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await runWithFeedback(
          context, () => AuthService().adminResetPassword(_me, _user!.id!, ctrl.text),
          success: 'Mot de passe réinitialisé — communiquez-le à l\'utilisateur');
    }
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'Supprimer le compte',
        'Supprimer définitivement ${_user!.nomComplet} ?',
        confirm: 'Supprimer', danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await runWithFeedback(context, () => _admin.deleteUser(_me, _user!),
        success: 'Compte supprimé');
    if (ok && mounted) Navigator.pop(context);
  }

  // ───────────── UI ─────────────
  @override
  Widget build(BuildContext context) {
    final u = _user;
    if (u == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    final hasHistory = u.role == UserRole.client || u.role == UserRole.livreur;
    final tabs = [
      const Tab(text: 'Infos'),
      if (hasHistory) const Tab(text: 'Historique'),
      if (widget.adminActions) const Tab(text: 'Activité'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(u.nomComplet),
          actions: [
            if (widget.adminActions && u.id != _me)
              PopupMenuButton<String>(
                onSelected: (v) => switch (v) {
                  'role' => _changeRole(),
                  'block' => _toggleBlock(),
                  'pwd' => _resetPassword(),
                  'delete' => _delete(),
                  _ => null,
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'role', child: Text('Changer le rôle')),
                  PopupMenuItem(
                      value: 'block',
                      child: Text(u.estBloque ? 'Activer le compte' : 'Désactiver le compte')),
                  const PopupMenuItem(
                      value: 'pwd', child: Text('Réinitialiser le mot de passe')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                ],
              ),
          ],
          bottom: tabs.length > 1 ? TabBar(tabs: tabs) : null,
        ),
        body: TabBarView(children: [
          _infos(u),
          if (u.role == UserRole.client) OrderHistoryView(clientId: u.id!),
          if (u.role == UserRole.livreur) DeliveryHistoryView(livreurId: u.id!),
          if (widget.adminActions) _activity(u.id!),
        ]),
      ),
    );
  }

  Widget _infos(User u) => ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: UserAvatar(user: u, radius: 44)),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          RoleChip(u.role),
          StatusChip(u.statut),
        ]),
        const SizedBox(height: 16),
        if (widget.adminActions && u.id != _me)
          Card(
            color: u.estBloque ? Colors.red.shade50 : Colors.green.shade50,
            child: ListTile(
              leading: Icon(u.estBloque ? Icons.block : Icons.verified_user,
                  color: u.estBloque ? Colors.red : Colors.green),
              title: Text(u.estBloque ? 'Compte désactivé' : 'Compte actif',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('L\'utilisateur est prévenu par email'),
              trailing: AccountStatusSwitch(user: u, onChanged: _load),
            ),
          ),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.email_outlined), title: Text(u.email)),
            ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: Text(u.telephone?.isNotEmpty == true ? u.telephone! : '—')),
            ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text('Inscrit le ${formatDate(u.dateCreation)}')),
          ]),
        ),
        if (_clientStats != null)
          Row(children: [
            Expanded(
              child: StatCard(
                  label: 'Commandes',
                  value: '${_clientStats!.nbCommandes}',
                  icon: Icons.receipt_long,
                  color: Colors.teal),
            ),
            Expanded(
              child: StatCard(
                  label: 'Total dépensé',
                  value: '${_clientStats!.totalDepense.toStringAsFixed(0)} DT',
                  icon: Icons.payments_outlined,
                  color: Colors.indigo),
            ),
          ]),
        if (_agent != null) ...[
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.two_wheeler),
                title: const Text('Véhicule'),
                trailing: Text(_agent!.typeVehicule ?? '—'),
              ),
              ListTile(
                leading: Icon(Icons.circle,
                    color: _agent!.disponible ? Colors.green : Colors.grey, size: 16),
                title: const Text('Disponibilité'),
                trailing: Text(_agent!.disponible ? 'En ligne' : 'Hors ligne'),
              ),
              ListTile(
                leading: const Icon(Icons.delivery_dining),
                title: const Text('Livraisons (30 derniers jours)'),
                trailing: Text('${_livraisons30j ?? 0}'),
              ),
            ]),
          ),
          _permisCard(_agent!.permisPhoto),
        ],
      ]);

  /// Photo du permis, à vérifier avant d'activer un livreur.
  Widget _permisCard(String? path) {
    final ok = path != null && File(path).existsSync();
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          leading: Icon(ok ? Icons.verified : Icons.report_gmailerrorred,
              color: ok ? Colors.green : Colors.orange),
          title: const Text('Permis de conduire'),
          subtitle: Text(ok ? 'Toucher la photo pour l\'agrandir' : 'Document non fourni'),
        ),
        if (ok)
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(child: Image.file(File(path))),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), height: 160, fit: BoxFit.cover),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _activity(int userId) => FutureBuilder<List<ActivityLog>>(
        future: ActivityLogDao().getByUser(userId),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty) {
            return const EmptyState(icon: Icons.history, message: 'Aucune activité');
          }
          return ListView(children: [for (final l in snap.data!) LogTile(log: l)]);
        },
      );
}
