import 'package:material_ui/material_ui.dart';

import '../icons/app_icon.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

// Date and time pickers in the app's own style. Flutter's Material pickers draw their arrows and edit
// button from the Material icon font, which this app doesn't ship (icons are our own SVGs), so they
// showed empty boxes.

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: context.colors.card,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
  builder: (_) => SafeArea(
    top: false,
    child: Padding(padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.lg), child: child),
  ),
);

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(color: context.colors.separator, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// A month grid in a bottom sheet. Days outside [first]–[last] can't be picked. Null if dismissed.
Future<DateTime?> showDateSheet(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = 'Pick a day',
}) => _sheet<DateTime>(context, _DateSheet(initial: _day(initial), first: _day(first), last: _day(last), title: title));

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.initial, required this.first, required this.last, required this.title});

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String title;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  bool get _canBack => _month.isAfter(DateTime(widget.first.year, widget.first.month));
  bool get _canForward => _month.isBefore(DateTime(widget.last.year, widget.last.month));

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  /// Far-off dates (expiry, date of birth) are quicker to reach by year than month by month.
  Future<void> _pickYear() async {
    final years = [for (var y = widget.first.year; y <= widget.last.year; y++) y];
    if (years.length < 2) return;
    final y = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      builder: (ctx) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            children: [
              for (final y in years)
                ListRow(
                  title: '$y',
                  trailing: y == _month.year
                      ? AppIcon(AppIcons.check, size: Sizes.iconSmall, color: ctx.colors.accent)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(y),
                ),
            ],
          ),
        ),
      ),
    );
    if (y == null) return;
    var m = DateTime(y, _month.month);
    final firstMonth = DateTime(widget.first.year, widget.first.month);
    final lastMonth = DateTime(widget.last.year, widget.last.month);
    if (m.isBefore(firstMonth)) m = firstMonth;
    if (m.isAfter(lastMonth)) m = lastMonth;
    setState(() => _month = m);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = _day(DateTime.now());
    final lead = DateTime(_month.year, _month.month).weekday % 7; // Sunday first
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final multiYear = widget.last.year > widget.first.year;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        const SizedBox(height: Space.lg),
        Text(widget.title, style: context.text.title),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: multiYear ? _pickYear : null,
                child: Semantics(
                  button: multiYear,
                  label: multiYear ? 'Change year' : null,
                  child: Text('${_months[_month.month - 1]} ${_month.year}', style: context.text.bodyStrong),
                ),
              ),
            ),
            Opacity(
              opacity: _canBack ? 1 : 0.35,
              child: IconTile(
                AppIcons.left,
                semanticLabel: 'Previous month',
                onTap: _canBack ? () => _shift(-1) : null,
              ),
            ),
            const SizedBox(width: Space.sm),
            Opacity(
              opacity: _canForward ? 1 : 0.35,
              child: IconTile(AppIcons.right, semanticLabel: 'Next month', onTap: _canForward ? () => _shift(1) : null),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Text(d, textAlign: TextAlign.center, style: context.text.label),
              ),
          ],
        ),
        const SizedBox(height: Space.xs),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var n = 1; n <= days; n++)
              () {
                final date = DateTime(_month.year, _month.month, n);
                final enabled = !date.isBefore(widget.first) && !date.isAfter(widget.last);
                final selected = date == widget.initial;
                final isToday = date == today;
                return Semantics(
                  button: enabled,
                  selected: selected,
                  label: '$n ${_months[_month.month - 1]} ${_month.year}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => Navigator.of(context).pop(date) : null,
                    child: Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? c.primary : null,
                          border: isToday && !selected ? Border.all(color: c.accent, width: 1.5) : null,
                        ),
                        child: Text(
                          '$n',
                          style: context.text.body.copyWith(
                            color: selected
                                ? c.onPrimary
                                : (enabled ? c.textPrimary : c.textTertiary.withValues(alpha: 0.45)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
      ],
    );
  }
}

/// A time wheel in a bottom sheet, in 5-minute steps. Null if dismissed.
Future<TimeOfDay?> showTimeSheet(BuildContext context, {required TimeOfDay initial, String title = 'Pick a time'}) =>
    _sheet<TimeOfDay>(context, _TimeSheet(initial: initial, title: title));

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial, required this.title});

  final TimeOfDay initial;
  final String title;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  static const _minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  // Hour 1–12, minute on a 5-minute step, and am/pm, as wheel positions.
  late int _hour = (widget.initial.hour + 11) % 12; // 0 → "1"
  late int _minute = ((widget.initial.minute / 5).round()).clamp(0, 11);
  late int _pm = widget.initial.hour >= 12 ? 1 : 0;

  TimeOfDay get _value => TimeOfDay(hour: (_hour + 1) % 12 + (_pm == 1 ? 12 : 0), minute: _minutes[_minute]);

  Widget _wheel({required int initial, required List<String> labels, required ValueChanged<int> onChanged}) {
    final c = context.colors;
    return SizedBox(
      width: 72,
      child: ListWheelScrollView.useDelegate(
        controller: FixedExtentScrollController(initialItem: initial),
        itemExtent: 40,
        diameterRatio: 1.6,
        perspective: 0.004,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: labels.length,
          builder: (context, i) => Center(
            child: Text(labels[i], style: context.text.body.copyWith(color: c.textPrimary, fontSize: 21)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        const SizedBox(height: Space.lg),
        Text(widget.title, style: context.text.title),
        const SizedBox(height: Space.md),
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The band behind the selected row.
              Container(
                height: 40,
                decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(Radii.control)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wheel(initial: _hour, labels: [for (var h = 1; h <= 12; h++) '$h'], onChanged: (i) => _hour = i),
                  Text(':', style: context.text.body.copyWith(color: c.textPrimary, fontSize: 21)),
                  _wheel(
                    initial: _minute,
                    labels: [for (final m in _minutes) m.toString().padLeft(2, '0')],
                    onChanged: (i) => _minute = i,
                  ),
                  _wheel(initial: _pm, labels: const ['am', 'pm'], onChanged: (i) => _pm = i),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        AppButton(label: 'Done', onPressed: () => Navigator.of(context).pop(_value)),
      ],
    );
  }
}
