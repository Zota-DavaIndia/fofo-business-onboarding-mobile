import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/partner_code.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/submit.dart';
import '../../core/widgets/widgets.dart';
import '../field/calendar_screen.dart';
import '../visits/visit_forms.dart';
import 'lead.dart';
import 'lead_form_screen.dart';

/// Shop and investment answers shared by the lead form and the call form.
const shopOwnershipOptions = [('owned', 'Owned'), ('rented', 'Rented'), ('none', 'No shop yet')];
const investmentOptions = [('yes', 'Yes'), ('maybe', 'Maybe'), ('no', 'No')];
const modelOptions = [('FOFO', 'FOFO'), ('COCO', 'COCO')];

/// The "More" sheet on a lead. Lists only what the user and the server
/// allow for this lead.
Future<void> showLeadActions(BuildContext context, WidgetRef ref, Lead lead) {
  final user = ref.read(sessionProvider).value;
  bool can(String p) => user?.can(p) ?? false;
  final items = <(AppIconData, String, Widget, bool)>[
    if (can(Perm.leadsCall)) (AppIcons.phone, 'Log a call', LogCallScreen(lead: lead), false),
    if (lead.allows(LeadAction.scheduleVisit) && can(Perm.visitsManage))
      (AppIcons.calendar, 'Schedule a visit', ScheduleVisitScreen(lead: lead), false),
    if (lead.allows(LeadAction.addNote)) (AppIcons.chat, 'Add a note', AddNoteScreen(lead: lead), false),
    if (can(Perm.dayplanManage))
      (AppIcons.clock, 'Schedule an activity', ActivityFormScreen(leadId: lead.id, leadName: lead.name), false),
    if (lead.allows(LeadAction.changeStatus) && can(Perm.leadsStatus) && lead.nextStatuses.isNotEmpty)
      (AppIcons.sync, 'Change status', ChangeStatusScreen(lead: lead), false),
    if (can(Perm.leadsUpdate)) (AppIcons.doc, 'Edit details', LeadFormScreen(lead: lead), false),
    if (lead.allows(LeadAction.reassign) && can(Perm.leadsAssign))
      (AppIcons.user, 'Reassign', ReassignScreen(lead: lead), false),
    if (lead.allows(LeadAction.changeStatus) && can(Perm.leadsStatus) && lead.nextStatuses.isNotEmpty)
      (AppIcons.close, 'Close lead', ChangeStatusScreen(lead: lead, closing: true), true),
  ];
  final codes = ref.read(appConfigProvider).value?.fieldIssuesCodes ?? false;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.colors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    builder: (sheet) => SheetBody(
      title: lead.name,
      children: [
        if (codes)
          ListRow(
            title: 'Give a sign-in code',
            subtitle: 'For the customer to track their enquiry',
            leading: IconTile(AppIcons.lock, color: sheet.colors.accent, background: sheet.colors.accentTint),
            onTap: () {
              Navigator.of(sheet).pop();
              showPartnerCode(context, ref, '/leads/${lead.id}/partner-code', name: lead.name);
            },
          ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.lg),
            child: Text('Nothing else you can do on this lead right now.', style: sheet.text.secondary),
          ),
        for (final (icon, label, screen, danger) in items)
          ListRow(
            title: label,
            leading: IconTile(
              icon,
              color: danger ? sheet.colors.danger : sheet.colors.accent,
              background: sheet.colors.tintOf(danger ? sheet.colors.danger : sheet.colors.accent),
            ),
            onTap: () async {
              Navigator.of(sheet).pop();
              final saved = await pushForm<bool>(context, screen);
              if (saved == true) leadChanged(ref);
            },
          ),
      ],
    ),
  );
}

class LogCallScreen extends ConsumerStatefulWidget {
  const LogCallScreen({super.key, required this.lead});

  final Lead lead;

  @override
  ConsumerState<LogCallScreen> createState() => _LogCallScreenState();
}

class _LogCallScreenState extends ConsumerState<LogCallScreen> with FormSubmit {
  String? _outcome;
  String? _disposition;
  DateTime? _nextCall;
  String? _reason;
  late String? _model = widget.lead.model;
  late String? _shop = widget.lead.shopOwnership;
  late String? _investment = widget.lead.investmentReady;
  late final _area = TextEditingController(text: widget.lead.shopAreaSqft?.toString() ?? '');
  late final _timeline = TextEditingController(text: widget.lead.timeline ?? '');
  final _summary = TextEditingController();
  String? _localError;

  static const _outcomes = [
    ('connected', 'Connected'),
    ('no_answer', 'No answer'),
    ('busy', 'Busy'),
    ('switched_off', 'Switched off'),
    ('wrong_number', 'Wrong number'),
  ];
  static const _dispositions = [
    ('interested', 'Interested'),
    ('callback', 'Call back'),
    ('not_interested', 'Not interested'),
    ('invalid', 'Invalid'),
  ];

  @override
  void dispose() {
    _area.dispose();
    _timeline.dispose();
    _summary.dispose();
    super.dispose();
  }

  void _save() {
    if (_outcome == null) {
      setState(() => _localError = 'Pick how the call went.');
      return;
    }
    setState(() => _localError = null);
    final connected = _outcome == 'connected';
    submit(
      (api) => api.post<dynamic>(
        '/leads/${widget.lead.id}/calls',
        body: {
          'outcome': _outcome,
          if (connected && _disposition != null) 'disposition': _disposition,
          if (_nextCall != null) 'next_call_at': isoWithOffset(_nextCall!),
          if (_summary.text.trim().isNotEmpty) 'summary': _summary.text.trim(),
          if (connected && _reason != null) 'reason': _reason,
          if (connected && _disposition == 'interested') ...{
            'model': ?_model,
            'shop_ownership': ?_shop,
            'shop_area_sqft': ?int.tryParse(_area.text.trim()),
            'investment_ready': ?_investment,
            if (_timeline.text.trim().isNotEmpty) 'timeline': _timeline.text.trim(),
          },
        },
      ),
      done: 'Call logged',
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _outcome == 'connected';
    final statuses = ref.watch(statusesProvider).value ?? const {};
    final reasons = switch (_disposition) {
      'not_interested' => statuses['NOT_INTERESTED']?.reasons,
      'invalid' => statuses['JUNK']?.reasons,
      _ => null,
    };
    return FormPage(
      title: 'Log a call',
      submitLabel: 'Save call',
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text(widget.lead.name, style: context.text.label),
        ChoiceGroup<String>(
          label: 'How did it go?',
          options: _outcomes,
          value: _outcome,
          errorText: _localError ?? fieldError('outcome'),
          onChanged: (v) => setState(() {
            _outcome = v;
            _localError = null;
          }),
        ),
        if (connected)
          ChoiceGroup<String>(
            label: 'What did they say?',
            options: _dispositions,
            value: _disposition,
            errorText: fieldError('disposition'),
            onChanged: (v) => setState(() {
              _disposition = v;
              _reason = null;
            }),
          ),
        if (connected && reasons != null && reasons.isNotEmpty)
          ChoiceGroup<String>(
            label: 'Reason',
            options: [for (final r in reasons) (r, r)],
            value: _reason,
            errorText: fieldError('reason'),
            onChanged: (v) => setState(() => _reason = v),
          ),
        if (connected && _disposition == 'interested') ...[
          ChoiceGroup<String>(
            label: 'Model',
            options: modelOptions,
            value: _model,
            onChanged: (v) => setState(() => _model = v),
          ),
          ChoiceGroup<String>(
            label: 'Shop',
            options: shopOwnershipOptions,
            value: _shop,
            onChanged: (v) => setState(() => _shop = v),
          ),
          AppField(
            controller: _area,
            label: 'Shop area, sq ft',
            hint: '400',
            keyboardType: TextInputType.number,
            errorText: fieldError('shop_area_sqft'),
          ),
          ChoiceGroup<String>(
            label: 'Ready to invest?',
            options: investmentOptions,
            value: _investment,
            onChanged: (v) => setState(() => _investment = v),
          ),
          AppField(
            controller: _timeline,
            label: 'When do they want to start?',
            hint: 'Within 2 months',
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        PickerField(
          label: 'Next call',
          value: _nextCall == null ? null : formatPicked(_nextCall!),
          hint: 'Not planned',
          icon: AppIcons.calendar,
          errorText: fieldError('next_call_at'),
          onClear: () => setState(() => _nextCall = null),
          onTap: () async {
            final d = await pickDateTime(context, initial: _nextCall);
            if (d != null) setState(() => _nextCall = d);
          },
        ),
        AppField(
          controller: _summary,
          label: 'Summary',
          hint: 'What was said',
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('summary'),
        ),
      ],
    );
  }
}

class ChangeStatusScreen extends ConsumerStatefulWidget {
  const ChangeStatusScreen({super.key, required this.lead, this.closing = false});

  final Lead lead;

  /// Show only the statuses that close the lead.
  final bool closing;

  @override
  ConsumerState<ChangeStatusScreen> createState() => _ChangeStatusScreenState();
}

class _ChangeStatusScreenState extends ConsumerState<ChangeStatusScreen> with FormSubmit {
  String? _status;
  String? _reason;
  final _notes = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ref.watch(statusesProvider);
    final defs = statuses.value ?? const <String, StatusDef>{};
    String label(String code) => defs[code]?.label ?? code.replaceAll('_', ' ').toLowerCase();
    final options = [
      for (final code in widget.lead.nextStatuses)
        if (!widget.closing || (defs[code]?.isExit ?? false)) (code, label(code)),
    ];
    final picked = _status == null ? null : defs[_status!];
    final needsReason = picked?.isExit ?? false;
    return FormPage(
      title: widget.closing ? 'Close lead' : 'Change status',
      submitLabel: widget.closing ? 'Close lead' : 'Save status',
      submitting: submitting,
      onSubmit: () {
        if (_status == null || (needsReason && _reason == null)) {
          setState(() => _localError = _status == null ? 'Pick a status.' : 'Pick a reason.');
          return;
        }
        setState(() => _localError = null);
        submit(
          (api) => api.post<dynamic>(
            '/leads/${widget.lead.id}/status',
            body: {
              'status': _status,
              'reason': ?_reason,
              if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
            },
          ),
          done: 'Status changed to ${label(_status!)}',
        );
      },
      children: [
        Text('${widget.lead.name} · now ${widget.lead.statusLabel}', style: context.text.label),
        if (statuses.isLoading)
          const SkeletonScope(label: 'Loading statuses', child: SkeletonChips())
        else if (options.isEmpty)
          Text(
            widget.closing
                ? "This lead can't be closed from its current status."
                : 'No other status is open from here.',
            style: context.text.secondary,
          )
        else
          ChoiceGroup<String>(
            label: widget.closing ? 'How did it end?' : 'Move to',
            options: options,
            value: _status,
            required: true,
            errorText: _status == null ? (_localError ?? fieldError('status')) : fieldError('status'),
            onChanged: (v) => setState(() {
              _status = v;
              _reason = null;
            }),
          ),
        if (needsReason)
          ChoiceGroup<String>(
            label: 'Reason',
            options: [for (final r in picked!.reasons) (r, r)],
            value: _reason,
            required: true,
            errorText: _status != null && _reason == null ? _localError : fieldError('reason'),
            onChanged: (v) => setState(() => _reason = v),
          ),
        AppField(
          controller: _notes,
          label: 'Notes',
          hint: 'Optional',
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('notes'),
        ),
      ],
    );
  }
}

class AddNoteScreen extends ConsumerStatefulWidget {
  const AddNoteScreen({super.key, required this.lead});

  final Lead lead;

  @override
  ConsumerState<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends ConsumerState<AddNoteScreen> with FormSubmit {
  final _notes = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Add a note',
      submitLabel: 'Save note',
      submitting: submitting,
      onSubmit: () {
        if (_notes.text.trim().isEmpty) {
          setState(() => _localError = 'Write the note first.');
          return;
        }
        setState(() => _localError = null);
        submit(
          (api) => api.post<dynamic>('/leads/${widget.lead.id}/notes', body: {'notes': _notes.text.trim()}),
          done: 'Note added',
        );
      },
      children: [
        Text(widget.lead.name, style: context.text.label),
        AppField(
          controller: _notes,
          hint: 'What happened',
          minLines: 5,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          errorText: _localError ?? fieldError('notes'),
          onChanged: (_) {
            if (_localError != null) setState(() => _localError = null);
          },
        ),
      ],
    );
  }
}

class ReassignScreen extends ConsumerStatefulWidget {
  const ReassignScreen({super.key, required this.lead});

  final Lead lead;

  @override
  ConsumerState<ReassignScreen> createState() => _ReassignScreenState();
}

class _ReassignScreenState extends ConsumerState<ReassignScreen> with FormSubmit {
  String? _userId;
  String? _localError;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(fieldUsersProvider);
    return FormPage(
      title: 'Reassign',
      submitLabel: 'Reassign',
      submitting: submitting,
      onSubmit: () {
        if (_userId == null) {
          setState(() => _localError = 'Pick who takes this lead.');
          return;
        }
        submit(
          (api) => api.post<dynamic>('/leads/${widget.lead.id}/assign', body: {'user_id': int.parse(_userId!)}),
          done: 'Lead reassigned',
        );
      },
      children: [
        Text(
          [widget.lead.name, if (widget.lead.assignedTo != null) 'now with ${widget.lead.assignedTo}'].join(' · '),
          style: context.text.label,
        ),
        users.when(
          skipLoadingOnReload: true,
          loading: () => const SkeletonScope(label: 'Loading people', child: SkeletonRows(count: 4, badge: false)),
          error: (_, _) => Text("Couldn't load the list. Go back and try again.", style: context.text.secondary),
          data: (list) => GroupedList(
            children: [
              for (final u in list)
                ListRow(
                  title: u.label,
                  leading: Initials(u.label),
                  trailing: u.value == _userId
                      ? AppIcon(AppIcons.check, size: Sizes.iconSmall, color: context.colors.accent)
                      : null,
                  onTap: () => setState(() {
                    _userId = u.value;
                    _localError = null;
                  }),
                ),
            ],
          ),
        ),
        if ((_localError ?? fieldError('user_id')) case final e?)
          Text(e, style: context.text.label.copyWith(color: context.colors.danger)),
      ],
    );
  }
}
