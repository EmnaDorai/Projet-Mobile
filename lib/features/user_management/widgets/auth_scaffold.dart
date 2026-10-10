import 'package:flutter/material.dart';

import '../../../core/theme/app_logo.dart';
import '../../../core/theme/app_theme.dart';

/// Mise en page commune des écrans d'authentification :
/// bandeau olive avec le logo, puis une feuille claire avec le formulaire.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  /// Grand logo (connexion) ou version compacte (autres écrans).
  final bool large;

  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBack = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.olive,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, showBack ? 4 : 24, 20, large ? 36 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .08)),
                    ),
                  SizedBox(height: large ? 28 : 12),
                  large
                      ? const BninLogo(markSize: 60, wordColor: Colors.white)
                      : const BninLogo(markSize: 40, wordColor: Colors.white),
                  if (large) ...[
                    const SizedBox(height: 14),
                    Text(AppTheme.tagline,
                        style: t.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: .72),
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: t.headlineMedium),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(subtitle!,
                                style: t.bodyLarge?.copyWith(color: AppColors.muted)),
                          ],
                          const SizedBox(height: 24),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
