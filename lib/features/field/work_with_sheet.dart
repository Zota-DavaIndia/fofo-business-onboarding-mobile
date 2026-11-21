import 'package:material_ui/material_ui.dart';

import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/widgets.dart';
import 'field.dart';

/// "Working with anyone today?" before the day starts. Resolves to the picked ids (empty to start alone),
/// or null when dismissed, which means don't start.
Future<List<int>?> pickWorkWith(BuildContext context, List<Colleague> team) {
  return showModalBottomSheet<List<int>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.colors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    builder: (_) => _WorkWithSheet(team: team),
  );
}

class _WorkWithSheet extends StatefulWidget {
  const _WorkWithSheet({required this.team});

  final List<Colleague> team;

  @override
  State<_WorkWithSheet> createState() => _WorkWithSheetState();
}

class _WorkWithSheetState extends State<_WorkWithSheet> {
  final _picked = <int>{};
  String _query = '';

  // A manager's list can run long; search only when it doesn't fit at a glance.
  bool get _searchable => widget.team.length > 8;

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? widget.team : widget.team.where((c) => c.name.toLowerCase().contains(q)).toList();
    final n = _picked.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetBody(
        title: 'Working with anyone today?',
        footer: Padding(
          padding: const EdgeInsets.only(top: Space.md),
          child: AppButton(
            label: n == 0 ? 'Start day' : 'Start day with $n',
            icon: AppIcons.start,
            onPressed: () => Navigator.of(context).pop(_picked.toList()),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Text("Pick who's with you, or start alone.", style: context.text.secondary),
          ),
          if (_searchable)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: AppField(
                hint: 'Search by name',
                leadingIcon: AppIcons.search,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Text('Nobody by that name in your team.', style: context.text.secondary),
            ),
          for (final c in shown)
            ListRow(
              leading: _TickBox(on: _picked.contains(c.id)),
              title: c.name,
              subtitle: [?c.designation, ?c.relation?.label].join(' · '),
              onTap: () => setState(() => _picked.contains(c.id) ? _picked.remove(c.id) : _picked.add(c.id)),
            ),
        ],
      ),
    );
  }
}

class _TickBox extends StatelessWidget {
  const _TickBox({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? c.primary : null,
        borderRadius: BorderRadius.circular(Radii.badge),
        border: Border.all(color: on ? c.primary : c.textTertiary, width: 1.5),
      ),
      child: on ? AppIcon(AppIcons.tick, size: 16, color: c.onPrimary) : null,
    );
  }
}
