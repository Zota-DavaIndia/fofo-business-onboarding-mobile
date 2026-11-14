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
import '../leads/lead_detail_screen.dart';
import 'day_plan_screen.dart';
import 'field.dart' show monthKey;
import 'plan.dart';
import 'store_screen.dart';

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

(AppIconData, String) _look(CalendarKind k) => switch (k) {
  CalendarKind.visit => (AppIcons.visit, 'Visit'),
  CalendarKind.callback => (AppIcons.phone, 'Call back'),
  CalendarKind.followUp => (AppIcons.followUp, 'Follow up'),
  CalendarKind.activity => (AppIcons.check, 'Activity'),
  CalendarKind.plan => (AppIcons.route, 'Day plan'),
  CalendarKind.leave => (AppIcons.leave, 'Leave'),
};

/// "My activity": a month with a dot on every day that has something, and the chosen day's list.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _day = DateTime.now();

  Future<void> _addActivity() async {
    final saved = await pushForm<bool>(context, ActivityFormScreen(day: _day));
    if (saved == true) ref.invalidate(calendarProvider);
  }

  Future<void> _tap(CalendarItem i) async {
    if (i.kind == CalendarKind.activity && i.activityId != null) {
      final pick = await showChoiceSheet<String>(
        context,
        title: i.title,
        options: [
          (i.done ? 'undo' : 'done', i.done ? 'Mark as not done' : 'Mark as done'),
          if (i.leadId != null) ('lead', 'Open the lead'),
          if (i.partnerId != null) ('store', 'Open the store'),
          ('delete', 'Delete'),
        ],
      );
      if (!mounted || pick == null) return;
      final api = ref.read(apiClientProvider);
      try {
        switch (pick) {
          case 'done' || 'undo':
            await api.patch<Object?>('/activities/${i.activityId}', body: {'done': pick == 'done'});
          case 'delete':
            await api.delete<Object?>('/activities/${i.activityId}');
          case 'lead':
            await pushForm<void>(context, LeadDetailScreen(id: i.leadId!));
          case 'store':
            await pushForm<void>(context, StoreScreen(id: i.partnerId!));
        }
        ref.invalidate(calendarProvider);
      } on ApiException catch (e) {
        if (mounted) showSaveError(context, e);
      }
      return;
    }
    if (i.leadId != null) {
      await pushForm<void>(context, LeadDetailScreen(id: i.leadId!));
    } else if (i.kind == CalendarKind.plan) {
      await pushForm<void>(context, const DayPlanScreen());
    }
    ref.invalidate(calendarProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = ref.watch(calendarProvider(monthKey(_month)));
    final items = data.value ?? const <CalendarItem>[];
    final byDay = <String, List<CalendarItem>>{};
    for (final i in items) {
      (byDay[i.day] ??= []).add(i);
    }
    final first = DateTime(_month.year, _month.month);
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // weeks start on Sunday
    final today = isoDay(DateTime.now());
    final selected = isoDay(_day);
    final dayItems = byDay[selected] ?? const <CalendarItem>[];
    return PageBody(
      onRefresh: () => ref.refresh(calendarProvider(monthKey(_month)).future),
      header: Row(
        children: [
          IconTile(
            AppIcons.left,
            semanticLabel: 'Back',
            alignment: Alignment.centerLeft,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: Text('Calendar', style: context.text.title)),
          IconTile(
            AppIcons.plus,
            semanticLabel: 'Schedule an activity',
            color: c.accent,
            background: c.accentTint,
            alignment: Alignment.centerRight,
            onTap: _addActivity,
          ),
        ],
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  IconTile(
                    AppIcons.left,
                    semanticLabel: 'Previous month',
                    onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: context.text.bodyStrong,
                    ),
                  ),
                  IconTile(
                    AppIcons.right,
                    semanticLabel: 'Next month',
                    onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                    Expanded(
                      child: Text(d, textAlign: TextAlign.center, style: context.text.label),
                    ),
                ],
              ),
              const SizedBox(height: Space.xs),
              for (var week = 0; week * 7 < lead + daysIn; week++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final n = week * 7 + col - lead + 1;
                            if (n < 1 || n > daysIn) return const SizedBox(height: 44);
                            final d = DateTime(_month.year, _month.month, n);
                            final key = isoDay(d);
                            final on = key == selected;
                            final has = byDay[key]?.isNotEmpty ?? false;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _day = d),
                              child: Container(
                                height: 44,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: on ? c.accent : (key == today ? c.accentTint : null),
                                  borderRadius: BorderRadius.circular(Radii.tile),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$n',
                                      style: context.text.body.copyWith(
                                        color: on ? c.onPrimary : c.textPrimary,
                                        fontWeight: key == today ? FontWeight.w600 : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: has ? (on ? c.onPrimary : c.accent) : Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        SectionLabel(selected == today ? 'Today' : formatShortDay(_day)),
        if (data.isLoading && data.value == null)
          const SkeletonScope(child: SkeletonRows(count: 3))
        else if (data.hasError)
          MessageBlock(icon: AppIcons.alert, title: "Couldn't load the calendar", body: 'Pull down to try again.')
        else if (dayItems.isEmpty)
          AppCard(child: Text('Nothing on this day. Tap + to schedule an activity.', style: context.text.secondary))
        else
          GroupedList(
            children: [
              for (final i in dayItems)
                ListRow(
                  title: i.title,
                  dim: i.done,
                  subtitle: [if (i.at != null) formatTime(i.at!), ?i.subtitle].join(' · '),
                  leading: IconTile(
                    _look(i.kind).$1,
                    color: c.accent,
                    background: c.accentTint,
                    size: 36,
                    iconSize: 18,
                  ),
                  trailing: i.done ? StatusBadge('Done', tone: Tone.success) : null,
                  onTap: i.kind == CalendarKind.leave ? null : () => _tap(i),
                ),
            ],
          ),
      ],
    );
  }
}

/// Schedule a reminder, optionally for a lead.
class ActivityFormScreen extends ConsumerStatefulWidget {
  const ActivityFormScreen({super.key, this.day, this.leadId, this.leadName});

  final DateTime? day;
  final int? leadId;
  final String? leadName;

  @override
  ConsumerState<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends ConsumerState<ActivityFormScreen> with FormSubmit {
  final _topic = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _at;
  final _err = <String, String>{};

  @override
  void initState() {
    super.initState();
    final d = widget.day;
    final now = DateTime.now();
    if (d != null && !DateTime(d.year, d.month, d.day).isBefore(DateTime(now.year, now.month, now.day))) {
      _at = DateTime(d.year, d.month, d.day, isoDay(d) == isoDay(now) ? (now.hour + 1).clamp(0, 23) : 10);
    }
  }

  @override
  void dispose() {
    _topic.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _e(String k) => _err[k] ?? fieldError(k);

  void _save() {
    setState(() {
      _err.clear();
      if (_topic.text.trim().length < 2) _err['topic'] = 'Say what to do.';
      if (_at == null) _err['due_at'] = 'Choose when.';
    });
    if (_err.isNotEmpty) return;
    final notes = _notes.text.trim();
    submit(
      (api) => api.post<Object?>(
        '/activities',
        body: {
          'topic': _topic.text.trim(),
          'due_at': isoWithOffset(_at!),
          'notes': notes.isEmpty ? null : notes,
          'lead_id': ?widget.leadId,
        },
      ),
      done: 'Activity scheduled',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Schedule activity',
      submitLabel: 'Schedule',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (widget.leadName != null) Text('For ${widget.leadName}', style: context.text.label),
        AppField(
          controller: _topic,
          label: 'Activity',
          hint: 'Bring the ROI sheet',
          maxLength: 150,
          textCapitalization: TextCapitalization.sentences,
          errorText: _e('topic'),
        ),
        PickerField(
          label: 'When',
          value: _at == null ? null : formatPicked(_at!),
          hint: 'Date and time',
          icon: AppIcons.calendar,
          errorText: _e('due_at'),
          onTap: () async {
            final d = await pickDateTime(context, initial: _at);
            if (d != null) setState(() => _at = d);
          },
        ),
        AppField(
          controller: _notes,
          label: 'Notes',
          hint: 'Optional',
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('notes'),
        ),
      ],
    );
  }
}
