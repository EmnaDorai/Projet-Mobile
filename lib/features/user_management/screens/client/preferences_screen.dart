import 'package:flutter/material.dart';

import '../../dao/preference_dao.dart';
import '../../models/preference.dart';

class PreferencesScreen extends StatefulWidget {
  final int userId;
  const PreferencesScreen({super.key, required this.userId});
  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _dao = PreferenceDao();
  final _otherAllergy = TextEditingController();
  static const _allergenes = [
    'Gluten', 'Lactose', 'Arachides', 'Fruits à coque', 'Œufs',
    'Poisson', 'Crustacés', 'Soja',
  ];
  final _selected = <String>{};
  String _langue = 'fr';
  bool _notifs = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dao.get(widget.userId).then((p) {
      final list = (p.allergies ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      setState(() {
        _selected.addAll(list.where(_allergenes.contains));
        _otherAllergy.text = list.where((e) => !_allergenes.contains(e)).join(', ');
        _langue = p.langue;
        _notifs = p.notifications;
        _loading = false;
      });
    });
  }

  Future<void> _save() async {
    final all = [
      ..._selected,
      ..._otherAllergy.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
    ];
    await _dao.save(Preference(
      userId: widget.userId,
      allergies: all.isEmpty ? null : all.join(', '),
      langue: _langue,
      notifications: _notifs,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Préférences enregistrées')));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _otherAllergy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes préférences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text('Allergies', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final a in _allergenes)
                  FilterChip(
                    label: Text(a),
                    selected: _selected.contains(a),
                    onSelected: (v) =>
                        setState(() => v ? _selected.add(a) : _selected.remove(a)),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _otherAllergy,
                decoration: const InputDecoration(
                    labelText: 'Autres (séparées par des virgules)'),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _langue,
                decoration: const InputDecoration(labelText: 'Langue'),
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) => setState(() => _langue = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications'),
                subtitle: const Text('Suivi de commande, offres'),
                value: _notifs,
                onChanged: (v) => setState(() => _notifs = v),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Enregistrer')),
            ]),
    );
  }
}
