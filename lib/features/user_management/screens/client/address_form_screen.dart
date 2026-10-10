import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../dao/address_dao.dart';
import '../../models/address.dart';
import '../../services/geocoding_service.dart';
import '../common/map_picker_screen.dart';
import '../../widgets/common_widgets.dart';

/// Ajout / modification d'une adresse. Le bouton GPS enregistre la position
/// actuelle (utile au futur module Livraison).
class AddressFormScreen extends StatefulWidget {
  final int userId;
  final Address? address;
  const AddressFormScreen({super.key, required this.userId, this.address});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _libelle = TextEditingController(text: widget.address?.libelle ?? 'Maison');
  late final _rue = TextEditingController(text: widget.address?.rue);
  late final _ville = TextEditingController(text: widget.address?.ville);
  late double? _lat = widget.address?.latitude;
  late double? _lng = widget.address?.longitude;
  late bool _defaut = widget.address?.parDefaut ?? false;
  bool _locating = false;

  bool get _isEdit => widget.address != null;

  /// Position GPS actuelle, puis rue et ville via l'API Nominatim.
  Future<void> _locate() async {
    setState(() => _locating = true);
    await runWithFeedback(context, () async {
      final pos = await GeocodingService().currentPosition();
      await _applyPoint(pos.latitude, pos.longitude);
    }, success: 'Position enregistrée');
    if (mounted) setState(() => _locating = false);
  }

  /// Position choisie en touchant la carte OpenStreetMap.
  Future<void> _pickOnMap() async {
    final p = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
            initial: _lat == null ? null : LatLng(_lat!, _lng!)),
      ),
    );
    if (p == null || !mounted) return;
    setState(() => _locating = true);
    await runWithFeedback(context, () => _applyPoint(p.latitude, p.longitude));
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _applyPoint(double lat, double lng) async {
    final addr = await GeocodingService().reverse(lat, lng);
    if (!mounted) return;
    setState(() {
      _lat = lat;
      _lng = lng;
      if (addr.street != null) _rue.text = addr.street!;
      if (addr.city != null) _ville.text = addr.city!;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final a = Address(
      id: widget.address?.id,
      userId: widget.userId,
      libelle: _libelle.text.trim(),
      rue: _rue.text.trim(),
      ville: _ville.text.trim(),
      latitude: _lat,
      longitude: _lng,
      parDefaut: _defaut,
    );
    final dao = AddressDao();
    _isEdit ? await dao.update(a) : await dao.insert(a);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _libelle.dispose();
    _rue.dispose();
    _ville.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier l\'adresse' : 'Nouvelle adresse')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Wrap(spacing: 8, children: [
            for (final l in ['Maison', 'Travail', 'Autre'])
              ChoiceChip(
                label: Text(l),
                selected: _libelle.text == l,
                onSelected: (_) => setState(() => _libelle.text = l),
              ),
          ]),
          const SizedBox(height: 14),
          TextFormField(
              controller: _libelle,
              validator: Validators.required,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Libellé')),
          const SizedBox(height: 14),
          TextFormField(
              controller: _rue,
              validator: Validators.required,
              decoration: const InputDecoration(labelText: 'Rue / N°')),
          const SizedBox(height: 14),
          TextFormField(
              controller: _ville,
              validator: Validators.required,
              decoration: const InputDecoration(labelText: 'Ville')),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _locate,
                icon: const Icon(Icons.my_location),
                label: const Text('Ma position'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _pickOnMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Sur la carte'),
              ),
            ),
          ]),
          if (_locating)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            )
          else if (_lat != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'Position : ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Adresse par défaut'),
            value: _defaut,
            onChanged: (v) => setState(() => _defaut = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Enregistrer')),
        ]),
      ),
    );
  }
}
