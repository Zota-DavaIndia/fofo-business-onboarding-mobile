import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/submit.dart';
import '../../core/widgets/widgets.dart';
import 'field.dart';

Tone _tone(LeaveStatus s) => switch (s) {
  LeaveStatus.pending => Tone.warning,
  LeaveStatus.approved => Tone.success,
  LeaveStatus.rejected => Tone.danger,
  LeaveStatus.cancelled => Tone.neutral,
};

String _range(Leave l) {
  final same = l.from.year == l.to.year && l.from.month == l.to.month && l.from.day == l.to.day;
  final dates = same ? formatShortDay(l.from) : '${formatShortDay(l.from)} – ${formatShortDay(l.to)}';
  final days = l.halfDay ? 'half day' : '${formatDays(l.days)} ${l.days == 1 ? 'day' : 'days'}';
  return '$dates · $days';
}

/// Leave taken this year, the requests, and applying.
class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final saved = await pushForm<bool>(context, const ApplyLeaveScreen());
    if (saved == true) ref.invalidate(leavesProvider);
  }

  Future<void> _tap(BuildContext context, WidgetRef ref, Leave l) async {
    if (!l.canCancel) return;
    final pick = await showChoiceSheet<bool>(
      context,
      title: '${l.typeLabel} leave · ${_range(l)}',
      options: const [(true, 'Cancel this leave'), (false, 'Keep it')],
    );
    if (pick != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).post<Object?>('/leaves/${l.id}/cancel');
      ref.invalidate(leavesProvider);
      if (context.mounted) showSaved(context, 'Leave cancelled');
    } on ApiException catch (e) {
      if (context.mounted) showSaveError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(leavesProvider);
    return PageBody(
      onRefresh: () => ref.refresh(leavesProvider.future),
      header: Row(
        children: [
          IconTile(
            AppIcons.left,
            semanticLabel: 'Back',
            alignment: Alignment.centerLeft,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: Text('Leave', style: context.text.title)),
          IconTile(
            AppIcons.plus,
            semanticLabel: 'Apply for leave',
            color: context.colors.accent,
            background: context.colors.accentTint,
            alignment: Alignment.centerRight,
            onTap: () => _apply(context, ref),
          ),
        ],
      ),
      children: data.when(
        loading: () => [
          const SkeletonScope(
            label: 'Loading leave',
            child: Column(
              children: [
                SkeletonChips(widths: [70, 70, 70, 70]),
                SizedBox(height: Space.md),
                SkeletonRows(count: 3, lead: BoneLead.none),
              ],
            ),
          ),
        ],
        error: (_, _) => [
          MessageBlock(
            icon: AppIcons.alert,
            title: "Couldn't load your leave",
            body: 'Check your connection and pull down to try again.',
            action: AppButton(
              label: 'Try again',
              kind: ButtonKind.secondary,
              onPressed: () => ref.invalidate(leavesProvider),
            ),
          ),
        ],
        data: (y) => [
          SectionLabel('Taken in ${DateTime.now().year}'),
          Row(
            children: [
              for (var i = 0; i < y.taken.length; i++) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatDays(y.taken[i].days), style: context.text.bodyStrong),
                        Text(y.taken[i].label, style: context.text.label, maxLines: 1),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SectionLabel('Requests'),
          if (y.items.isEmpty)
            MessageBlock(
              icon: AppIcons.leave,
              title: 'No leave this year',
              body: 'Apply here; your manager approves it in the CRM and you get an alert.',
              action: AppButton(label: 'Apply for leave', onPressed: () => _apply(context, ref)),
            )
          else
            GroupedList(
              children: [
                for (final l in y.items)
                  ListRow(
                    title: _range(l),
                    subtitle: [l.typeLabel, l.reason, if (l.reviewNote != null) l.reviewNote!].join(' · '),
                    trailing: StatusBadge(l.status.label, tone: _tone(l.status)),
                    onTap: l.canCancel ? () => _tap(context, ref, l) : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> with FormSubmit {
  String? _type = 'casual';
  DateTime? _from;
  DateTime? _to;
  bool _half = false;
  final _reason = TextEditingController();
  final _clientId = newClientId();
  final _err = <String, String>{};

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? _e(String k) => _err[k] ?? fieldError(k);

  bool get _oneDay => _from != null && _to != null && isoDay(_from!) == isoDay(_to!);

  double get _days {
    if (_from == null || _to == null) return 0;
    if (_oneDay && _half) return 0.5;
    return (DateTime(
              _to!.year,
              _to!.month,
              _to!.day,
            ).difference(DateTime(_from!.year, _from!.month, _from!.day)).inDays +
            1)
        .toDouble();
  }

  void _save() {
    setState(() {
      _err.clear();
      if (_from == null) _err['from_date'] = 'Choose the first day.';
      if (_to == null) _err['to_date'] = 'Choose the last day.';
      if (_reason.text.trim().length < 3) _err['reason'] = 'Say why you need leave.';
    });
    if (_err.isNotEmpty) return;
    submit(
      (api) => api.post<Object?>(
        '/leaves',
        body: {
          'client_uuid': _clientId,
          'type': _type,
          'from_date': isoDay(_from!),
          'to_date': isoDay(_to!),
          'half_day': _oneDay && _half,
          'reason': _reason.text.trim(),
        },
      ),
      done: 'Leave requested',
    );
  }

  @override
  Widget build(BuildContext context) {
    final opts = (ref.watch(appConfigProvider).value ?? const AppConfig()).field;
    final now = DateTime.now();
    final first = now.subtract(const Duration(days: 7));
    return FormPage(
      title: 'Apply for leave',
      submitLabel: _days > 0 ? 'Apply · ${formatDays(_days)} ${_days == 1 ? 'day' : 'days'}' : 'Apply',
      submitting: submitting,
      onSubmit: _save,
      children: [
        ChoiceGroup<String>(
          label: 'Type',
          options: opts.leaveTypes,
          value: _type,
          onChanged: (v) => setState(() => _type = v ?? _type),
          errorText: fieldError('type'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PickerField(
                label: 'From',
                value: _from == null ? null : formatShortDay(_from!),
                hint: 'First day',
                icon: AppIcons.calendar,
                errorText: _e('from_date'),
                onTap: () async {
                  final d = await pickDate(
                    context,
                    initial: _from ?? now,
                    first: first,
                    last: now.add(const Duration(days: 365)),
                  );
                  if (d == null) return;
                  setState(() {
                    _from = d;
                    if (_to == null || _to!.isBefore(d)) _to = d;
                  });
                },
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: PickerField(
                label: 'To',
                value: _to == null ? null : formatShortDay(_to!),
                hint: 'Last day',
                icon: AppIcons.calendar,
                errorText: _e('to_date'),
                onTap: () async {
                  final start = _from ?? now;
                  final d = await pickDate(
                    context,
                    initial: _to ?? start,
                    first: start,
                    last: now.add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _to = d);
                },
              ),
            ),
          ],
        ),
        if (_oneDay)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _half = !_half),
            child: Row(
              children: [
                Expanded(child: Text('Half day', style: context.text.body)),
                Switch(
                  value: _half,
                  onChanged: (v) => setState(() => _half = v),
                  activeTrackColor: context.colors.accent,
                ),
              ],
            ),
          ),
        AppField(
          controller: _reason,
          label: 'Reason',
          hint: 'Family function, doctor…',
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          errorText: _e('reason'),
        ),
      ],
    );
  }
}
