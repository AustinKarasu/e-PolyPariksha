import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF7C3AED);
  static const primaryDark = Color(0xFF5B21B6);
  static const primaryLight = Color(0xFFA78BFA);
  static const secondary = Color(0xFF14B8A6);
  static const accent = Color(0xFFF59E0B);
  static const ink = Color(0xFF1E1033);
  static const surface = Color(0xFFF8F5FF);
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);

  static const darkBg = Color(0xFF0F0A1A);
  static const darkSurface = Color(0xFF1A1128);
  static const darkCard = Color(0xFF231838);
  static const darkInk = Color(0xFFE8E0F0);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6), Color(0xFF4C1D95)],
  );
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFEDE9FE), Color(0xFFF5F3FF)],
  );

  static final softShadow = [BoxShadow(color: primary.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))];
  static final cardShadow = [BoxShadow(color: primary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))];

  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 24.0;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: secondary, tertiary: accent, surface: surface, error: error, brightness: Brightness.light);
    return _build(scheme, Brightness.light);
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: primary, primary: primaryLight, secondary: secondary, tertiary: accent, surface: darkSurface, error: error, brightness: Brightness.dark);
    return _build(scheme, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness b) {
    final isDark = b == Brightness.dark;
    final bg = isDark ? darkBg : surface;
    final card = isDark ? darkCard : surfaceWhite;
    final txt = isDark ? darkInk : ink;
    final brd = isDark ? primaryLight.withValues(alpha: 0.15) : primaryLight.withValues(alpha: 0.12);

    return ThemeData(
      useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: bg, fontFamily: 'Roboto', brightness: b,
      appBarTheme: AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 2, backgroundColor: isDark ? darkSurface : primary, foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.15, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(radiusMd)))),
      drawerTheme: DrawerThemeData(backgroundColor: isDark ? darkSurface : surfaceWhite),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: card, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: BorderSide(color: brd)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: BorderSide(color: brd)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: BorderSide(color: isDark ? primaryLight : primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: const BorderSide(color: error)),
        labelStyle: TextStyle(color: txt.withValues(alpha: 0.6)),
        floatingLabelStyle: TextStyle(color: isDark ? primaryLight : primary, fontWeight: FontWeight.w500)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: isDark ? primaryLight : primary, foregroundColor: isDark ? darkBg : Colors.white, disabledBackgroundColor: isDark ? darkCard : primaryLight.withValues(alpha: 0.35), disabledForegroundColor: isDark ? darkInk.withValues(alpha: 0.55) : ink.withValues(alpha: 0.45), elevation: 2, minimumSize: const Size.fromHeight(52), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: isDark ? primaryLight : primary, side: BorderSide(color: isDark ? primaryLight.withValues(alpha: 0.4) : primaryLight), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: isDark ? primaryLight : primary)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: isDark ? primaryLight : primary, foregroundColor: isDark ? darkBg : Colors.white, disabledBackgroundColor: isDark ? darkCard : primaryLight.withValues(alpha: 0.35), disabledForegroundColor: isDark ? darkInk.withValues(alpha: 0.55) : ink.withValues(alpha: 0.45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)))),
      cardTheme: CardThemeData(elevation: 0, color: card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg), side: BorderSide(color: brd)), margin: const EdgeInsets.symmetric(vertical: 4)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: isDark ? primaryLight : primary, foregroundColor: isDark ? darkBg : Colors.white, elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg))),
      chipTheme: ChipThemeData(backgroundColor: primaryLight.withValues(alpha: isDark ? 0.2 : 0.12), labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? primaryLight : primaryDark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)), side: BorderSide.none),
      dialogTheme: DialogThemeData(backgroundColor: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)), surfaceTintColor: Colors.transparent),
      tabBarTheme: const TabBarThemeData(labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: secondary, indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: brd),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)), backgroundColor: isDark ? darkCard : ink),
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: txt), headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: txt),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: txt), titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: txt),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: txt), titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: txt),
        bodyLarge: TextStyle(fontSize: 16, color: txt), bodyMedium: TextStyle(fontSize: 14, color: txt), bodySmall: TextStyle(fontSize: 12, color: txt),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: txt)),
    );
  }
}
