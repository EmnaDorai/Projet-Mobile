import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dao/user_dao.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/export_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/export_sheet.dart';
import 'activity_logs_view.dart';
import 'admin_charts.dart';
import 'bulk_email_screen.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  Future<void> _export(BuildContext context, {required bool pdf}) async {
    final adminId = context.read<AuthProvider>().currentUser?.id;
    await exportWithChoice(context,
        title: pdf ? 'Liste des utilisateurs (PDF)' : 'Liste des utilisateurs (Excel)',
        run: (mode) async {
      final users = await UserDao().getAll(limit: 100000);
      return pdf
          ? ExportService().exportUsersPdf(users, adminId: adminId, mode: mode)
          : ExportService().exportUsersCsv(users, adminId: adminId, mode: mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardData>(
      future: AdminService().dashboard(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        return ListView(padding: const EdgeInsets.all(12), children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: [
              StatCard(
                  label: 'Utilisateurs',
                  value: '${d.total}',
                  icon: Icons.people,
                  color: Colors.blueGrey),
              StatCard(
                  label: 'Nouveaux (7 j)',
                  value: '${d.nouveaux7j}',
                  icon: Icons.person_add,
                  color: Colors.green),
              StatCard(
                  label: 'Désactivés',
                  value: '${d.bloques}',
                  icon: Icons.block,
                  color: Colors.red),
              StatCard(
                  label: 'Livreurs',
                  value: '${d.count(UserRole.livreur)}',
                  icon: Icons.delivery_dining,
                  color: roleColor(UserRole.livreur)),
            ],
          ),
          const SizedBox(height: 8),
          _chartCard(context, 'Répartition par rôle',
              RolePieChart(counts: {for (final r in UserRole.values) r: d.count(r)})),
          const SizedBox(height: 8),
          _chartCard(context, 'Inscriptions (6 derniers mois)',
              SignupsBarChart(byMonth: d.parMois)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Actions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _export(context, pdf: true),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Export PDF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _export(context, pdf: false),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('Export Excel'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BulkEmailScreen())),
                  icon: const Icon(Icons.forward_to_inbox),
                  label: const Text('Envoyer un email groupé'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              const ListTile(
                title: Text('Dernières activités',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (d.derniersLogs.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16), child: Text('Aucune activité')),
              for (final l in d.derniersLogs) LogTile(log: l),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _chartCard(BuildContext context, String title, Widget chart) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            chart,
          ]),
        ),
      );
}
