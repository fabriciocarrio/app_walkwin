import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand – Blues
  static const primary = Color(
    0xFF4A9BFF,
  ); // Deep blue – buttons, active states
  static const primaryContainer = Color(
    0xFF009CFF,
  ); // Electric Blue – progress, containers
  static const primaryLight = Color(
    0xFFA8D558,
  ); // Legacy – used by some screens
  static const primaryDarkMode = Color(
    0xFF009CFF,
  ); // Electric Blue for dark mode primary

  static const secondary = Color(0xFF476270); // Deep Navy – headings, icons
  static const tertiary = Color(0xFF356476); // Dark Teal – supporting info

  // Light mode – Kinetic Light
  static const bgLight = Color(0xFFF7FAF8); // Alpine White
  static const cardLight = Color(0xFFFFFFFF); // Pure white for elevated cards
  static const surfaceVariantLight = Color(0xFFE0E3E1);
  static const textPrimaryLight = Color(0xFF181C1B);
  static const textSecondaryLight = Color(0xFF3F4752);
  static const dividerLight = Color(0xFFBFC7D5); // outline-variant

  // Dark mode – Kinetic Energy (blue-based)
  static const bgDark = Color(0xFF0D1321);
  static const cardDark = Color(0xFF151B29);
  static const cardAltDark = Color(0xFF1E293B);
  static const textPrimaryDark = Color(0xFFEEF1EF);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const dividerDark = Color(0xFF1E293B);

  // Shared
  static const coinGold = Color(0xFFF5C535);
  static const coinGoldDark = Color(0xFFD4A017);
  static const danger = Color(0xFFBA1A1A);
  static const warning = Color(0xFFE8A020);
}

class AppTheme {
  // Border radius system (based on 0.25rem = 4px)
  static const radiusSm = 4.0;
  static const radiusMd = 6.0;
  static const radiusLg = 8.0;
  static const radiusXl = 12.0;
  static const radiusFull = 9999.0;

  // Spacing unit = 8px
  static const space = 8.0;

  // Light ColorScheme from Kinetic Light spec
  static const _lightColorScheme = ColorScheme.light(
    primary: Color(0xFF207AF5),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF009CFF),
    onPrimaryContainer: Color(0xFF003156),
    secondary: Color(0xFF476270),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFC7E4F4),
    onSecondaryContainer: Color(0xFF4B6674),
    tertiary: Color(0xFF356476),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF6F9EB1),
    onTertiaryContainer: Color(0xFF003543),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFF7FAF8),
    onSurface: Color(0xFF181C1B),
    surfaceContainerHighest: Color(0xFFE0E3E1),
    onSurfaceVariant: Color(0xFF3F4752),
    outline: Color(0xFF6F7884),
    outlineVariant: Color(0xFFBFC7D5),
    inverseSurface: Color(0xFF2D3130),
    inversePrimary: Color(0xFF9DCAFF),
    surfaceTint: Color(0xFF0061A2),
  );

  // Dark ColorScheme – blue-based complement
  static const _darkColorScheme = ColorScheme.dark(
    primary: Color(0xFF207AF5),
    onPrimary: Color(0xFF003156),
    primaryContainer: Color(0xFF0061A2),
    onPrimaryContainer: Color(0xFF9DCAFF),
    secondary: Color(0xFFAECBDB),
    onSecondary: Color(0xFF1A3542),
    secondaryContainer: Color(0xFF2F4A58),
    onSecondaryContainer: Color(0xFFCAE7F7),
    tertiary: Color(0xFF9ECEE1),
    onTertiary: Color(0xFF003543),
    tertiaryContainer: Color(0xFF194D5D),
    onTertiaryContainer: Color(0xFFBAEAFE),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF151B29),
    onSurface: Color(0xFFEEF1EF),
    surfaceContainerHighest: Color(0xFF1E293B),
    onSurfaceVariant: Color(0xFF94A3B8),
    outline: Color(0xFF6F7884),
    outlineVariant: Color(0xFF1E293B),
    inverseSurface: Color(0xFFEEF1EF),
    inversePrimary: Color(0xFF0061A2),
    surfaceTint: Color(0xFF009CFF),
  );

  // ── Typography ────────────────────────────────────────────────
  // montserrat: display & headlines (800, 700, 600)
  // Inter: body (400)
  // JetBrains Mono: labels (500)

  static TextTheme _buildTextTheme(Color textPrimary, Color textSecondary) {
    return GoogleFonts.soraTextTheme(
      const TextTheme(
        // ── Sora: Display & Headlines ──────────────────────────
        // Hero numbers / big moments — max authority
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -0.04,
        ),
        // Screen titles — commanding weight
        headlineLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: -0.02,
        ),
        // Section headers — bold presence
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        // Card / block headers
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        // Primary body titles
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        // Secondary titles / list items
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        // Small card titles / metadata headings
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),

        // ── Hanken Grotesk: Body ───────────────────────────────
        // Featured / lead paragraphs
        bodyLarge: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
        // Standard reading text
        bodyMedium: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        // Secondary / caption text
        bodySmall: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),

        // ── JetBrains Mono: Labels & Data ──────────────────────
        // Key metrics / stat values
        labelLarge: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.4,
          letterSpacing: 0.03,
        ),
        // Button labels / chip text / field labels
        labelMedium: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0.05,
        ),
        // Badges / timestamps / tiny metadata
        labelSmall: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0.05,
        ),
      ),
    );
  }

  // ── Themes ────────────────────────────────────────────────────

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightColorScheme,
    scaffoldBackgroundColor: _lightColorScheme.surface,

    // Typography
    textTheme: _buildTextTheme(
      _lightColorScheme.onSurface,
      _lightColorScheme.onSurfaceVariant,
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: _lightColorScheme.surface,
      foregroundColor: _lightColorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _lightColorScheme.onSurface,
      ),
    ),

    // Cards – white surface with 1px outline border
    cardTheme: CardThemeData(
      color: _lightColorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        side: BorderSide(color: _lightColorScheme.outlineVariant, width: 1),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightColorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(
          color: _lightColorScheme.outline.withAlpha(38), // 15% opacity
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(
          color: _lightColorScheme.outline.withAlpha(38),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: TextStyle(color: _lightColorScheme.onSurfaceVariant),
      labelStyle: TextStyle(color: _lightColorScheme.onSurfaceVariant),
    ),

    // Buttons – solid primary fill, no shadow
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightColorScheme.primary,
        foregroundColor: _lightColorScheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // Bottom nav
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _lightColorScheme.surface,
      selectedItemColor: _lightColorScheme.primary,
      unselectedItemColor: _lightColorScheme.onSurfaceVariant,
      selectedLabelStyle: GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.05,
      ),
      unselectedLabelStyle: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        letterSpacing: 0.05,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkColorScheme,
    scaffoldBackgroundColor: const Color(0xFF0D1321),

    // Typography
    textTheme: _buildTextTheme(
      _darkColorScheme.onSurface,
      _darkColorScheme.onSurfaceVariant,
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: _darkColorScheme.surface,
      foregroundColor: _darkColorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _darkColorScheme.onSurface,
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: _darkColorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        side: BorderSide(
          color: _darkColorScheme.outlineVariant.withAlpha(77), // 30% opacity
          width: 1,
        ),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkColorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(
          color: _darkColorScheme.outline.withAlpha(77),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(
          color: _darkColorScheme.outline.withAlpha(77),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(
          color: AppColors.primaryDarkMode,
          width: 2,
        ),
      ),
      hintStyle: TextStyle(color: _darkColorScheme.onSurfaceVariant),
      labelStyle: TextStyle(color: _darkColorScheme.onSurfaceVariant),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkColorScheme.primary,
        foregroundColor: _darkColorScheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // Bottom nav
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _darkColorScheme.surface,
      selectedItemColor: _darkColorScheme.primary,
      unselectedItemColor: _darkColorScheme.onSurfaceVariant,
      selectedLabelStyle: GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.05,
      ),
      unselectedLabelStyle: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        letterSpacing: 0.05,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
