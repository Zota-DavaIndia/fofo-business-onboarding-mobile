import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../icons/app_icon.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum ToastKind { success, error, info }

OverlayEntry? _current;
Timer? _timer;

/// A short message at the top of the screen in the app's own style: a flat card with a
/// toned icon. One at a time; a new one replaces the last. Tap to dismiss.
void showToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
  Duration? duration,
  VoidCallback? onTap,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _dismiss();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      kind: kind,
      action: onTap != null,
      onDismiss: () {
        if (_current == entry) _dismiss();
      },
      onTap: () {
        if (_current == entry) _dismiss();
        onTap?.call();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(duration ?? Duration(milliseconds: kind == ToastKind.error ? 4500 : 2800), _dismiss);
}

void _dismiss() {
  _timer?.cancel();
  _timer = null;
  _current?.remove();
  _current = null;
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.kind,
    required this.onDismiss,
    required this.onTap,
    this.action = false,
  });

  final String message;
  final ToastKind kind;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  /// Tapping opens something, so the toast shows a chevron.
  final bool action;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  @override
  void initState() {
    super.initState();
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, tone) = switch (widget.kind) {
      ToastKind.success => (AppIcons.check, c.success),
      ToastKind.error => (AppIcons.alert, c.danger),
      ToastKind.info => (AppIcons.bell, c.accent),
    };
    final still = MediaQuery.of(context).disableAnimations;
    final card = Semantics(
      liveRegion: true,
      container: true,
      label: widget.message,
      button: widget.action,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < 0) widget.onDismiss();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.lg, Space.md),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: c.tintOf(tone)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.tintOf(tone), borderRadius: BorderRadius.circular(Radii.tile)),
                child: AppIcon(icon, size: 16, color: tone),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                // "Title\nDetail": the first line reads as the title, the rest as detail.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, line) in widget.message.split('\n').indexed)
                      Text(
                        line,
                        style: i == 0 && widget.message.contains('\n')
                            ? context.text.bodyStrong.copyWith(color: c.textPrimary)
                            : i == 0
                            ? context.text.body.copyWith(color: c.textPrimary)
                            : context.text.label,
                      ),
                  ],
                ),
              ),
              if (widget.action) AppIcon(AppIcons.right, size: Sizes.iconSmall, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
    return Positioned(
      left: Space.screen,
      right: Space.screen,
      top: MediaQuery.paddingOf(context).top + Space.sm,
      child: Material(
        type: MaterialType.transparency,
        child: still
            ? card
            : FadeTransition(
                opacity: _anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.4),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut)),
                  child: card,
                ),
              ),
      ),
    );
  }
}
