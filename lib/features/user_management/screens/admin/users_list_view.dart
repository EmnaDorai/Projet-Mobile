import 'dart:async';

import 'package:flutter/material.dart';

import '../../dao/user_dao.dart';
import '../../models/user.dart';
import '../../widgets/common_widgets.dart';
import 'account_status_action.dart';
import 'create_user_screen.dart';
import 'user_detail_screen.dart';

/// Liste des utilisateurs avec recherche et filtres.
/// [admin] = true : tous les rôles + création de compte (espace Admin).
/// [fixedRole] : liste limitée à un rôle (ex. clients dans l'espace Manager).
class UsersListView extends StatefulWidget {
  final bool admin;
  final UserRole? fixedRole;
  final void Function(User user)? onOpen;

  const UsersListView({super.key, this.admin = false, this.fixedRole, this.onOpen});

  @override
  State<UsersListView> createState() => _UsersListViewState();
}

class _UsersListViewState extends State<UsersListView> {
  final _dao = UserDao();
  final _search = TextEditingController();
  Timer? _debounce;
  UserRole? _role;
  UserStatus? _statut;
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _role = widget.fixedRole;
    _reload();
  }

  void _reload() => setState(() {
        _future = _dao.getAll(
            role: _role, statut: _statut, search: _search.text, limit: 200);
      });

  Future<void> _open(User u) async {
    if (widget.onOpen != null) {
      widget.onOpen!(u);
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => UserDetailScreen(userId: u.id!)));
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.admin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add),
              label: const Text('Nouveau compte'),
              onPressed: () async {
                final created = await Navigator.push<bool>(context,
                    MaterialPageRoute(builder: (_) => const CreateUserScreen()));
                if (created == true) _reload();
              },
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Rechercher (nom, email, téléphone)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              isDense: true,
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _reload);
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            if (widget.fixedRole == null) ...[
              _chip('Tous', _role == null, () => _role = null),
              for (final r in UserRole.values) _chip(r.label, _role == r, () => _role = r),
              const SizedBox(width: 8),
              const SizedBox(height: 24, child: VerticalDivider()),
            ],
            _chip('Actifs', _statut == UserStatus.actif,
                () => _statut = _statut == UserStatus.actif ? null : UserStatus.actif),
            _chip('Désactivés', _statut == UserStatus.bloque,
                () => _statut = _statut == UserStatus.bloque ? null : UserStatus.bloque),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<User>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final users = snap.data!;
              if (users.isEmpty) {
                return const EmptyState(
                    icon: Icons.person_search, message: 'Aucun utilisateur trouvé');
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = users[i];
                  return ListTile(
                    leading: UserAvatar(user: u),
                    title: Text(u.nomComplet),
                    subtitle: Text(u.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.fixedRole == null) RoleChip(u.role),
                        if (widget.admin)
                          AccountStatusSwitch(user: u, onChanged: _reload)
                        else if (u.estBloque) ...[
                          const SizedBox(width: 4),
                          StatusChip(u.statut),
                        ],
                      ],
                    ),
                    onTap: () => _open(u),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            onTap();
            _reload();
          },
        ),
      );
}
