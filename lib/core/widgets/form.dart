import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../icons/app_icon.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'page.dart';
import 'widgets.dart';

/// Opens a full-screen form above the tabs. Resolves to what the form
/// pops with, usually `true` after a save.
Future<T?> pushForm<T>(BuildContext context, Widget form) =>
    Navigator.of(context, rootNavigator: true).push<T>(MaterialPageRoute(builder: (_) => form));

/// A form screen: close button and title at the top, one main button in a
/// solid bar at the bottom.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.submitting = false,
    this.submitIcon,
  });

  final String title;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool submitting;
  final AppIconData? submitIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PageBody(
        bottom: ActionBar(
          children: [AppButton(label: submitLabel, icon: submitIcon, loading: submitting, onPressed: onSubmit)],
        ),
        children: [
          PageHeader(title, onBack: () => Navigator.of(context).maybePop()),
          ...children,
        ],
      ),
    );
  }
}

/// Selectable pill, used for filters and single-choice answers.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onTap, this.height});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: Space.lg, vertical: height == null ? Space.md : 0),
          alignment: height == null ? null : Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accentTint : context.fieldFill,
            borderRadius: BorderRadius.circular(Radii.tile),
          ),
          child: Text(
            label,
            style: context.text.secondary.copyWith(
              color: selected ? c.accent : c.textSecondary,
              fontWeight: selected ? FontWeight.w500 : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled group of chips where one (or none) can be picked. Tapping
/// the picked chip again clears it unless [required].
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.errorText,
  });

  final String? label;
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final bool required;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[_FieldLabel(label!), const SizedBox(height: Space.xs)],
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final (v, l) in options)
              AppChip(label: l, selected: v == value, onTap: () => onChanged(v == value && !required ? null : v)),
          ],
        ),
        if (errorText case final e?) ...[
          const SizedBox(height: Space.xs),
          Text(e, style: context.text.label.copyWith(color: context.colors.danger)),
        ],
      ],
    );
  }
}

/// Looks like a text field; opens a picker when tapped.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.icon = AppIcons.right,
    this.errorText,
    this.onClear,
  });

  final String? label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final AppIconData icon;
  final String? errorText;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[_FieldLabel(label!), const SizedBox(height: Space.xs)],
        Semantics(
          button: true,
          label: label,
          value: value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: Sizes.field,
              padding: const EdgeInsets.only(left: Space.xl, right: Space.md),
              decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(Radii.field)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: value == null
                          ? context.text.secondary.copyWith(color: c.textTertiary, fontSize: 15)
                          : context.text.body,
                    ),
                  ),
                  if (value != null && onClear != null)
                    IconTile(
                      AppIcons.close,
                      onTap: onClear,
                      semanticLabel: 'Clear',
                      background: Colors.transparent,
                      size: 28,
                      iconSize: Sizes.iconSmall,
                    )
                  else
                    AppIcon(icon, size: Sizes.iconSmall, color: c.textTertiary),
                ],
              ),
            ),
          ),
        ),
        if (errorText case final e?) ...[
          const SizedBox(height: Space.xs),
          Text(e, style: context.text.label.copyWith(color: c.danger)),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.secondary.copyWith(fontWeight: FontWeight.w500, color: context.colors.textSecondary),
  );
}

/// Date, then time. Returns null if either is dismissed.
Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) async {
  final now = DateTime.now();
  final start = initial ?? now.add(const Duration(hours: 1));
  final day = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: first ?? DateTime(now.year, now.month, now.day),
    lastDate: last ?? now.add(const Duration(days: 365)),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// "Mon, 16 Nov · 11:00 am"
String formatPicked(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final day = formatDay(d);
  return '${days[d.weekday - 1]}, ${day.substring(0, day.length - 5)} · ${formatTime(d)}';
}

/// A bottom sheet listing options; resolves to the one tapped.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.colors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    builder: (ctx) => SheetBody(
      title: title,
      children: [
        for (final (v, l) in options)
          ListRow(
            title: l,
            trailing: v == selected ? AppIcon(AppIcons.check, size: Sizes.iconSmall, color: ctx.colors.accent) : null,
            onTap: () => Navigator.of(ctx).pop(v),
          ),
      ],
    ),
  );
}

/// Grab handle, title and rows for a bottom sheet. Scrolls when long.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, this.title, required this.children, this.footer});

  final String? title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Surface(
      level: SurfaceLevel.card,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: c.separator, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: Space.lg),
                if (title != null) ...[Text(title!, style: context.text.title), const SizedBox(height: Space.xs)],
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) Divider(height: 1, thickness: 1, color: c.separator),
                        children[i],
                      ],
                    ],
                  ),
                ),
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows why a save failed. Field errors are shown on the fields; this
/// covers the rest.
void showSaveError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : 'Something went wrong. Try again.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Snack bar confirming a save.
void showSaved(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
