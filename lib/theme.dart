import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kleuren en typografie van de app, los van de schermen zelf.
///
/// Bewust geen "seeded" Material 3-paars (dat is het standaard-thema van
/// elk vers Flutter-project en meteen herkenbaar). In plaats daarvan een
/// eigen, warm "planner"-kleurenpalet: bosgroen als hoofdkleur, terracotta
/// als accent op knoppen, en een creme achtergrond i.p.v. wit/grijs.
class AppKleuren {
  AppKleuren._();

  static const bosgroen = Color(0xFF1F6F5C);
  static const bosgroenDonker = Color(0xFF124A3D);
  static const terracotta = Color(0xFFE0704F);
  static const creme = Color(0xFFFBF6EC);
  static const inkt = Color(0xFF223328);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppKleuren.bosgroen,
      brightness: Brightness.light,
      primary: AppKleuren.bosgroen,
      secondary: AppKleuren.terracotta,
      surface: Colors.white,
    ).copyWith(
      // Achtergrond van de app zelf (Scaffold) i.p.v. de standaard
      // Material-grijstint.
      surfaceContainerLowest: AppKleuren.creme,
    );

    // Twee lettertypes: Fraunces (een sierlijk serif-lettertype) voor
    // titels/koppen, Work Sans (neutraal schreefloos) voor de rest — dat
    // contrast geeft de app een eigen, niet-generiek "planner"-gevoel.
    final tekstThema = GoogleFonts.workSansTextTheme().copyWith(
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppKleuren.inkt,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppKleuren.inkt,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppKleuren.creme,
      textTheme: tekstThema,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppKleuren.creme,
        foregroundColor: AppKleuren.inkt,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppKleuren.bosgroen.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppKleuren.bosgroen.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppKleuren.bosgroen, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppKleuren.terracotta,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
