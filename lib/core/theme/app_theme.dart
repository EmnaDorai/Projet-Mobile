import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identité visuelle « Bnin ».
/// Olive profond (base), rouge harissa (actions), safran (accent).
class AppColors {
  static const olive = Color(0xFF1F2B1D); // texte fort, en-têtes
  static const oliveSoft = Color(0xFF3D5134);
  static const harissa = Color(0xFFD2402A); // action principale
  static const saffron = Color(0xFFF2A93B); // accent
  static const paper = Color(0xFFF7F8F3); // fond d'écran
  static const field = Color(0xFFECEEE4); // fond des champs
  static const line = Color(0xFFDADDCF);
  static const muted = Color(0xFF6E7466);
  static const success = Color(0xFF2E7D4F);
  static const danger = Color(0xFFC62828);
}

class AppTheme {
  static const appName = 'Bnin';
  static const tagline = 'Tes plats préférés, au goût d\'ici.';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.harissa,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.harissa,
      onPrimary: Colors.white,
      secondary: AppColors.saffron,
      onSecondary: AppColors.olive,
      tertiary: AppColors.oliveSoft,
      surface: Colors.white,
      onSurface: AppColors.olive,
      error: AppColors.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = GoogleFonts.bricolageGrotesqueTextTheme(base.textTheme).apply(
      bodyColor: AppColors.olive,
      displayColor: AppColors.olive,
    );

    final fieldRadius = BorderRadius.circular(14);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.olive,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: AppColors.muted),
        floatingLabelStyle: const TextStyle(
            color: AppColors.olive, fontWeight: FontWeight.w600),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide.none),
        enabledBorder:
            OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: fieldRadius,
            borderSide: const BorderSide(color: AppColors.olive, width: 1.6)),
        errorBorder: OutlineInputBorder(
            borderRadius: fieldRadius,
            borderSide: const BorderSide(color: AppColors.danger, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: fieldRadius,
            borderSide: const BorderSide(color: AppColors.danger, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.harissa,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.olive,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.line, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.harissa,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.olive,
        side: const BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(
            color: AppColors.olive, fontWeight: FontWeight.w600),
        secondaryLabelStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        checkmarkColor: AppColors.saffron,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.saffron.withValues(alpha: .28),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight:
                  s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.olive,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected)
                  ? AppColors.olive
                  : AppColors.muted,
            )),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.olive,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.olive,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.oliveSoft),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.success : null),
      ),
    );
  }
}
