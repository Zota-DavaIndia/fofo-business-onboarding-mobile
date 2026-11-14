import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Text styles, all in Montserrat (bundled in assets/fonts, SIL Open Font
/// License).
@immutable
class AppText extends ThemeExtension<AppText> {
  const AppText(this.c);

  final AppColors c;

  static const family = 'Montserrat';

  TextStyle get title =>
      TextStyle(fontFamily: family, fontSize: 22, fontWeight: FontWeight.w600, height: 1.25, color: c.textPrimary);
  TextStyle get pageTitle =>
      TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w600, height: 1.3, color: c.textPrimary);
  TextStyle get heading =>
      TextStyle(fontFamily: family, fontSize: 18, fontWeight: FontWeight.w600, height: 1.3, color: c.textPrimary);
  TextStyle get number =>
      TextStyle(fontFamily: family, fontSize: 22, fontWeight: FontWeight.w600, height: 1.2, color: c.textPrimary);
  TextStyle get body =>
      TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: c.textPrimary);
  TextStyle get bodyStrong =>
      TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimary);
  TextStyle get secondary =>
      TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: c.textSecondary);
  TextStyle get label =>
      TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w400, height: 1.35, color: c.textTertiary);
  TextStyle get caption =>
      TextStyle(fontFamily: family, fontSize: 11, fontWeight: FontWeight.w400, height: 1.3, color: c.textTertiary);
  TextStyle get button => const TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w500, height: 1.2);

  @override
  AppText copyWith() => this;

  @override
  AppText lerp(AppText? other, double t) => other == null ? this : AppText(c.lerp(other.c, t));
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppText get text => Theme.of(this).extension<AppText>()!;
  StatColors get stats => Theme.of(this).extension<StatColors>()!;
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, StatColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, StatColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, StatColors stats, Brightness brightness) {
    const noBorder = OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.all(Radius.circular(Radii.field)),
    );
    final text = AppText(c);

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: AppText.family,
      scaffoldBackgroundColor: c.page,
      canvasColor: c.page,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        secondary: c.accent,
        onSecondary: c.onPrimary,
        error: c.danger,
        onError: c.onPrimary,
        surface: c.card,
        onSurface: c.textPrimary,
      ),
      extensions: [c, text, stats],

      // No ripple, splash, hover, focus or pressed overlays anywhere.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.25),
        selectionHandleColor: c.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.fieldOnPage,
        hintStyle: text.secondary.copyWith(color: c.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: noBorder,
        enabledBorder: noBorder,
        focusedBorder: noBorder,
        errorBorder: noBorder,
        focusedErrorBorder: noBorder,
        disabledBorder: noBorder,
        errorStyle: text.label.copyWith(color: c.danger),
      ),
    );
  }
}
