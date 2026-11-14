import 'package:material_ui/material_ui.dart';

import '../icons/app_icon.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'surface.dart';

export 'surface.dart';

/// Borderless card. Separates from the page by shade only.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.lg), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color ?? context.colors.card, borderRadius: BorderRadius.circular(Radii.card)),
      child: Surface(
        level: SurfaceLevel.card,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A card holding rows with inset separators between them.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xxs),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: context.colors.separator),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A row inside a [GroupedList]: optional leading widget, title, subtitle
/// and trailing widget.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dim = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Greys the title, for rows that can't be used yet.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Space.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: dim ? context.text.body.copyWith(color: context.colors.textTertiary) : context.text.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) Text(subtitle!, style: context.text.label),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

/// Square tile holding an icon. Used for nav, row leads and icon buttons.
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.color,
    this.background,
    this.size = Sizes.tile,
    this.iconSize,
    this.onTap,
    this.semanticLabel,
    this.alignment = Alignment.center,
  });

  final AppIconData icon;
  final Color? color;
  final Color? background;
  final double size;
  final double? iconSize;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Where the tile sits inside its 48 px touch area. Use
  /// [Alignment.centerLeft] at the start of a row to keep the screen edge.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? context.fieldFill,
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
      child: AppIcon(
        icon,
        size: iconSize ?? (size >= Sizes.tile ? Sizes.icon : Sizes.iconSmall),
        color: color ?? context.colors.textSecondary,
        semanticLabel: semanticLabel,
      ),
    );
    if (onTap == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: Sizes.minTouch,
        child: Align(alignment: alignment, child: tile),
      ),
    );
  }
}

enum ButtonKind { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = ButtonKind.primary,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final AppIconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (kind) {
      ButtonKind.primary => (c.primary, c.onPrimary),
      ButtonKind.danger => (c.danger, c.onPrimary),
      ButtonKind.secondary => (context.fieldFill, c.textPrimary),
    };
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: Container(
            height: Sizes.button,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.control)),
            alignment: Alignment.center,
            child: loading
                ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        AppIcon(icon!, size: Sizes.iconSmall, color: fg),
                        const SizedBox(width: Space.sm),
                      ],
                      Text(label, style: context.text.button.copyWith(color: fg)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Text link with an arrow, the tertiary button style.
class TextLink extends StatelessWidget {
  const TextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xxs),
        child: Text(
          '$label ›',
          style: context.text.label.copyWith(color: context.colors.accent, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Borderless text field. Fill follows the layer it sits on.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.leadingIcon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.trailing,
    this.minLines,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final AppIconData? leadingIcon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final Widget? trailing;
  final int? minLines;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: context.text.secondary.copyWith(fontWeight: FontWeight.w500, color: c.textSecondary),
          ),
          const SizedBox(height: Space.xs),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autofillHints: autofillHints,
          minLines: minLines,
          maxLines: obscure ? 1 : maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: context.text.body,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            fillColor: context.fieldFill,
            prefixIcon: leadingIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: Space.lg, right: Space.sm),
                    child: AppIcon(leadingIcon!, size: Sizes.iconSmall, color: c.textTertiary),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: trailing,
          ),
        ),
        // Drawn here rather than through the decoration, which would indent
        // it to the text inside the box; this keeps it on the left edge.
        if (errorText case final error?) ...[
          const SizedBox(height: Space.xs),
          Text(error, style: context.text.label.copyWith(color: c.danger)),
        ],
      ],
    );
  }
}

enum Tone { accent, success, warning, danger, info, neutral }

/// Small status label: tone color on the same color at 14%.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = Tone.accent});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (tone) {
      Tone.accent => c.accent,
      Tone.success => c.success,
      Tone.warning => c.warning,
      Tone.danger => c.danger,
      Tone.info => c.info,
      Tone.neutral => c.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.tintOf(color), borderRadius: BorderRadius.circular(Radii.badge)),
      child: Text(label, style: context.text.caption.copyWith(color: color)),
    );
  }
}

/// Dim label above a group of content, with an optional link on the right.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.action});

  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.label)),
          ?action,
        ],
      ),
    );
  }
}

/// Circle with initials, for people.
class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.size = Sizes.tile});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Words that start with a letter or digit, so "Demo · Shop" gives "DS".
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => RegExp(r'^[\p{L}\p{N}]', unicode: true).hasMatch(p))
        .toList();
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: context.colors.accentTint, shape: BoxShape.circle),
      child: Text(
        letters,
        style: context.text.bodyStrong.copyWith(color: context.colors.accent, fontSize: size * 0.36),
      ),
    );
  }
}

/// Header for pushed screens: back tile and title, left aligned.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          IconTile(
            AppIcons.left,
            onTap: onBack,
            semanticLabel: 'Back',
            alignment: Alignment.centerLeft,
            background: Colors.transparent,
            color: context.colors.textPrimary,
            size: 24,
            iconSize: Sizes.icon,
          ),
        ],
        Expanded(child: Text(title, style: context.text.pageTitle)),
        ?trailing,
      ],
    );
  }
}

/// Left-aligned message for empty, error and blocking states.
class MessageBlock extends StatelessWidget {
  const MessageBlock({super.key, required this.icon, required this.title, required this.body, this.action});

  final AppIconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTile(icon, size: 48, color: context.colors.accent, background: context.colors.accentTint),
        const SizedBox(height: Space.lg),
        Text(title, style: context.text.title),
        const SizedBox(height: Space.xs),
        Text(body, style: context.text.secondary.copyWith(fontSize: 14)),
        if (action != null) ...[const SizedBox(height: Space.xl), action!],
      ],
    );
  }
}

/// Solid bar pinned to the bottom of a screen for its main actions.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.card,
      child: Surface(
        level: SurfaceLevel.card,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: Space.lg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.lg, Space.screen, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: Space.sm), children[i]],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
