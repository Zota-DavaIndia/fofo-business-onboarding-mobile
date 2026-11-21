import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/widgets.dart';
import 'lead.dart';

/// "Filter leads": enquiry dates and, on the Leads tab, one status. Resolves to the new filter, or null when dismissed.
Future<LeadRefine?> showLeadFilterSheet(
  BuildContext context, {
  required LeadRefine current,
  required List<StatusDef> statuses,
}) {
  return showModalBottomSheet<LeadRefine>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.colors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    builder: (_) => _LeadFilterSheet(current: current, statuses: statuses),
  );
}

class _LeadFilterSheet extends StatefulWidget {
  const _LeadFilterSheet({required this.current, required this.statuses});

  final LeadRefine current;
  final List<StatusDef> statuses;

  @override
  State<_LeadFilterSheet> createState() => _LeadFilterSheetState();
}

class _LeadFilterSheetState extends State<_LeadFilterSheet> {
  late DateTime? _from = widget.current.from;
  late DateTime? _to = widget.current.to;
  late String? _status = widget.current.status;

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final d = await pickDate(
      context,
      initial: (from ? _from : _to) ?? now,
      first: from ? null : _from,
      last: from ? (_to ?? now) : now,
    );
    if (d != null) setState(() => from ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SheetBody(
      title: 'Filter leads',
      footer: Padding(
        padding: const EdgeInsets.only(top: Space.md),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Clear',
                kind: ButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(const LeadRefine()),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Apply',
                onPressed: () => Navigator.of(context).pop(LeadRefine(from: _from, to: _to, status: _status)),
              ),
            ),
          ],
        ),
      ),
      children: [
        // Dates and the "Status" heading share one block, so the sheet's row dividers only run between statuses.
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: PickerField(
                      label: 'From',
                      value: _from == null ? null : formatDay(_from!),
                      hint: 'Any day',
                      icon: AppIcons.calendar,
                      onTap: () => _pick(true),
                      onClear: () => setState(() => _from = null),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: PickerField(
                      label: 'To',
                      value: _to == null ? null : formatDay(_to!),
                      hint: 'Today',
                      icon: AppIcons.calendar,
                      onTap: () => _pick(false),
                      onClear: () => setState(() => _to = null),
                    ),
                  ),
                ],
              ),
              if (widget.statuses.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                Text('Status', style: context.text.label),
                const SizedBox(height: Space.xs),
              ] else
                const SizedBox(height: Space.md),
            ],
          ),
        ),
        if (widget.statuses.isNotEmpty) ...[
          for (final s in [null, ...widget.statuses])
            ListRow(
              title: s?.label ?? 'Any status',
              trailing: s?.code == _status ? AppIcon(AppIcons.tick, size: Sizes.iconSmall, color: c.accent) : null,
              onTap: () => setState(() => _status = s?.code),
            ),
        ],
      ],
    );
  }
}
