import 'package:material_ui/material_ui.dart';

/// Every color the app uses. Screens read these through `context.colors`,
/// never as literal hex values.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.card,
    required this.fieldOnCard,
    required this.fieldOnPage,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.separator,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentTint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.brandOrange,
    required this.brandGreen,
    required this.scrim,
  });

  final Color page;
  final Color card;
  final Color fieldOnCard;
  final Color fieldOnPage;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color separator;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color accentTint;
  final Color success;
  final Color warning;
  final Color danger;
  final Color brandOrange;
  final Color brandGreen;
  final Color scrim;

  static const light = AppColors(
    page: Color(0xFFF6F3EF),
    card: Color(0xFFFFFFFF),
    fieldOnCard: Color(0xFFF3EFEA),
    fieldOnPage: Color(0xFFEAE5DF),
    textPrimary: Color(0xFF1E1915),
    textSecondary: Color(0xFF50463D),
    textTertiary: Color(0xFF73675C),
    separator: Color(0x141E1915),
    primary: Color(0xFFA4441A),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFA4441A),
    accentTint: Color(0x14A4441A),
    success: Color(0xFF2E7A45),
    warning: Color(0xFF8A6A00),
    danger: Color(0xFFB3261E),
    brandOrange: Color(0xFFFC8448),
    brandGreen: Color(0xFF5A782A),
    scrim: Color(0x61000000),
  );

  static const dark = AppColors(
    page: Color(0xFF14110E),
    card: Color(0xFF1D1916),
    fieldOnCard: Color(0xFF29231F),
    fieldOnPage: Color(0xFF221D19),
    textPrimary: Color(0xFFF2ECE6),
    textSecondary: Color(0xFFC5B9AD),
    textTertiary: Color(0xFF998C80),
    separator: Color(0x17F2ECE6),
    primary: Color(0xFFA94A1E),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFF49A6A),
    accentTint: Color(0x1AF49A6A),
    success: Color(0xFF6CCB8A),
    warning: Color(0xFFE2C044),
    danger: Color(0xFFF07B70),
    brandOrange: Color(0xFFFC8448),
    brandGreen: Color(0xFF9BBE5C),
    scrim: Color(0x8A000000),
  );

  /// Background for a status badge: the status color at 14%.
  Color tintOf(Color c) => c.withValues(alpha: 0.14);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      page: l(page, other.page),
      card: l(card, other.card),
      fieldOnCard: l(fieldOnCard, other.fieldOnCard),
      fieldOnPage: l(fieldOnPage, other.fieldOnPage),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      separator: l(separator, other.separator),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      accentTint: l(accentTint, other.accentTint),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      brandOrange: l(brandOrange, other.brandOrange),
      brandGreen: l(brandGreen, other.brandGreen),
      scrim: l(scrim, other.scrim),
    );
  }
}

abstract final class Space {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;

  /// Left and right padding of every screen.
  static const double screen = 16;
}

abstract final class Radii {
  static const double card = 14;
  static const double control = 12;
  static const double field = 11;
  static const double tile = 10;
  static const double badge = 6;
  static const double sheet = 20;
}

abstract final class Sizes {
  static const double tile = 36;
  static const double icon = 22;
  static const double iconSmall = 18;
  static const double button = 46;
  static const double field = 44;
  static const double tabBar = 72;
  static const double minTouch = 48;
}

/// Colour families for the Home stat cards. Each is a top-to-bottom
/// gradient deep enough for white text in both themes.
enum StatTone { clay, olive, mustard, teal }

@immutable
class StatColors extends ThemeExtension<StatColors> {
  const StatColors(this._gradients);

  final Map<StatTone, (Color, Color)> _gradients;

  (Color, Color) of(StatTone tone) => _gradients[tone]!;

  static const light = StatColors({
    StatTone.clay: (Color(0xFFC9582B), Color(0xFF8E3612)),
    StatTone.olive: (Color(0xFF6F8E33), Color(0xFF43601B)),
    StatTone.mustard: (Color(0xFFA9780C), Color(0xFF6E4E00)),
    StatTone.teal: (Color(0xFF25887C), Color(0xFF0B524B)),
  });

  static const dark = StatColors({
    StatTone.clay: (Color(0xFF6E2F14), Color(0xFF3A1A0D)),
    StatTone.olive: (Color(0xFF3A4D20), Color(0xFF1E2911)),
    StatTone.mustard: (Color(0xFF5A4812), Color(0xFF2E250A)),
    StatTone.teal: (Color(0xFF1A4C47), Color(0xFF0D2725)),
  });

  @override
  StatColors copyWith() => this;

  @override
  StatColors lerp(StatColors? other, double t) => other == null || t < 0.5 ? this : other;
}
