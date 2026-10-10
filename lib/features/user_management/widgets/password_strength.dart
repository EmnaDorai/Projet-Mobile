import 'package:flutter/material.dart';

/// Barre de force du mot de passe, mise à jour pendant la saisie.
class PasswordStrengthMeter extends StatelessWidget {
  final TextEditingController controller;
  const PasswordStrengthMeter({super.key, required this.controller});

  /// Score de 0 à 5 : longueur ≥ 8, ≥ 12, majuscule + minuscule,
  /// chiffre, caractère spécial.
  static int score(String p) {
    if (p.isEmpty) return 0;
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, __) {
          final s = score(value.text);
          if (value.text.isEmpty) return const SizedBox(height: 4);
          final (label, color) = switch (s) {
            <= 1 => ('Très faible', Colors.red),
            2 => ('Faible', Colors.deepOrange),
            3 => ('Moyen', Colors.orange),
            4 => ('Fort', Colors.lightGreen),
            _ => ('Très fort', Colors.green),
          };
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s / 5,
                    minHeight: 6,
                    color: color,
                    backgroundColor: color.withValues(alpha: .15),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          );
        },
      );
}
