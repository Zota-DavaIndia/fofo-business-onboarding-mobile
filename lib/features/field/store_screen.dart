import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/map_view.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/submit.dart';
import '../../core/widgets/widgets.dart';
import 'gps.dart';
import 'plan.dart';
import 'tickets_screen.dart';

/// A live store: contact and pin, check-in with GPS, tickets during the visit, and check-out with a summary.
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  bool _busy = false;
  final _clientId = newClientId();

  void _changed() {
    ref.invalidate(storeProvider(widget.id));
    ref.invalidate(dayPlanProvider);
    ref.invalidate(ticketsProvider);
  }

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    try {
      final p = await readFix(context);
      if (p == null) return;
      final res = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/stores/${widget.id}/checkin',
            body: {
              'latitude': p.latitude,
              'longitude': p.longitude,
              'accuracy_m': p.accuracy,
              'is_mock_location': p.isMocked,
              'client_uuid': _clientId,
            },
          );
      _changed();
      if (mounted) {
        final v = StoreVisitInfo.fromJson(res.data);
        showSaved(
          context,
          v.geoVerified ? 'Checked in at the store' : 'Checked in · ${v.distanceM ?? '?'} m from the store pin',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showSaveError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider(widget.id));
    final canTicket = ref.watch(sessionProvider).value?.can(Perm.ticketsRaise) ?? false;
    final s = store.value;
    final open = s?.openVisit;
    return PageBody(
      onRefresh: () => ref.refresh(storeProvider(widget.id).future),
      header: PageHeader('Store', onBack: () => Navigator.of(context).maybePop()),
      bottom: s == null
          ? null
          : ActionBar(
              children: [
                Row(
                  children: [
                    if (canTicket) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Raise ticket',
                          icon: AppIcons.alert,
                          kind: ButtonKind.secondary,
                          onPressed: () async {
                            final saved = await pushForm<bool>(context, RaiseTicketScreen(store: s));
                            if (saved == true) _changed();
                          },
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                    ],
                    Expanded(
                      child: open == null
                          ? AppButton(
                              label: 'Check in',
                              icon: AppIcons.locate,
                              loading: _busy,
                              onPressed: _busy ? null : _checkIn,
                            )
                          : AppButton(
                              label: 'Check out',
                              icon: AppIcons.check,
                              onPressed: () async {
                                final saved = await pushForm<bool>(context, StoreCheckOutScreen(visit: open, store: s));
                                if (saved == true) _changed();
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
      children: store.when(
        loading: () => [
          const SkeletonScope(child: Column(children: [SkeletonRows(count: 1), SkeletonCard(lines: 4)])),
        ],
        error: (_, _) => [
          MessageBlock(
            icon: AppIcons.alert,
            title: "Couldn't load this store",
            body: 'Check your connection and pull down to try again.',
          ),
        ],
        data: (s) => [
          Row(
            children: [
              Initials(s.name, size: 52),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: context.text.heading),
                    if (s.code != null) Text(s.code!, style: context.text.label),
                  ],
                ),
              ),
              StatusBadge(open == null ? 'Live' : 'Checked in', tone: open == null ? Tone.success : Tone.info),
            ],
          ),
          if (open != null)
            AppCard(
              child: Row(
                children: [
                  IconTile(
                    AppIcons.locate,
                    color: context.colors.info,
                    background: context.colors.tintOf(context.colors.info),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Checked in at ${formatTime(open.checkedInAt)}', style: context.text.bodyStrong),
                        Text(
                          open.geoVerified
                              ? 'Verified at the store${open.distanceM == null ? '' : ' · ${open.distanceM} m'}'
                              : 'Not at the store pin${open.distanceM == null ? '' : ' · ${open.distanceM} m away'}',
                          style: context.text.label,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (s.ownerMobile != null) ...[
            const SectionLabel('Contact'),
            GroupedList(
              children: [
                ListRow(
                  title: s.ownerName ?? s.ownerMobile!,
                  subtitle: s.ownerName == null ? 'Owner' : 'Owner · ${s.ownerMobile}',
                  leading: IconTile(
                    AppIcons.phone,
                    color: context.colors.accent,
                    background: context.colors.accentTint,
                  ),
                  onTap: () => launchUrl(Uri(scheme: 'tel', path: s.ownerMobile)),
                ),
              ],
            ),
          ],
          if (s.latitude != null && s.longitude != null) ...[
            const SectionLabel('On the map'),
            MapCard(
              pins: [MapPin(s.latitude!, s.longitude!, label: s.name, note: s.address)],
            ),
          ],
          if (s.tickets.isNotEmpty) ...[
            const SectionLabel('Tickets'),
            GroupedList(
              children: [
                for (final t in s.tickets)
                  ListRow(
                    title: t.subject,
                    subtitle: '${t.number} · ${t.categoryLabel}',
                    trailing: StatusBadge(t.statusLabel, tone: ticketTone(t.status)),
                    onTap: () => pushForm<void>(context, TicketScreen(id: t.id)),
                  ),
              ],
            ),
          ],
          if (s.recentVisits.isNotEmpty) ...[
            const SectionLabel('Recent visits'),
            GroupedList(
              children: [
                for (final v in s.recentVisits)
                  ListRow(
                    title: [formatDate(v.checkedInAt), ?v.by].join(' · '),
                    subtitle: v.summary ?? (v.isOpen ? 'In progress' : 'No summary'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Good bye": what was done at the store, and the user's feedback on it.
class StoreCheckOutScreen extends ConsumerStatefulWidget {
  const StoreCheckOutScreen({super.key, required this.visit, required this.store});

  final StoreVisitInfo visit;
  final StoreInfo store;

  @override
  ConsumerState<StoreCheckOutScreen> createState() => _StoreCheckOutScreenState();
}

class _StoreCheckOutScreenState extends ConsumerState<StoreCheckOutScreen> with FormSubmit {
  final _summary = TextEditingController();
  final _feedback = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _summary.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _save() {
    if (_summary.text.trim().length < 3) {
      setState(() => _err = 'Write what you did at the store.');
      return;
    }
    setState(() => _err = null);
    final fb = _feedback.text.trim();
    submit(
      (api) => api.post<Object?>(
        '/store-visits/${widget.visit.id}/checkout',
        body: {'summary': _summary.text.trim(), 'feedback': fb.isEmpty ? null : fb},
      ),
      done: 'Checked out',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Check out',
      submitLabel: 'Check out',
      submitIcon: AppIcons.check,
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text('${widget.store.name} · in since ${formatTime(widget.visit.checkedInAt)}', style: context.text.label),
        AppField(
          controller: _summary,
          label: 'Summary',
          hint: 'Stock checked, orders, issues, suggestions',
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          errorText: _err ?? fieldError('summary'),
        ),
        AppField(
          controller: _feedback,
          label: 'Your feedback on the store',
          hint: 'Optional',
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('feedback'),
        ),
      ],
    );
  }
}

/// Raise a ticket for a store: product, software, dispatch or accounts issue.
class RaiseTicketScreen extends ConsumerStatefulWidget {
  const RaiseTicketScreen({super.key, required this.store});

  final StoreInfo store;

  @override
  ConsumerState<RaiseTicketScreen> createState() => _RaiseTicketScreenState();
}

class _RaiseTicketScreenState extends ConsumerState<RaiseTicketScreen> with FormSubmit {
  String? _category;
  bool _high = false;
  final _subject = TextEditingController();
  final _description = TextEditingController();
  XFile? _photo;
  final _clientId = newClientId();
  final _err = <String, String>{};

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _e(String k) => _err[k] ?? fieldError(k);

  void _save() {
    setState(() {
      _err.clear();
      if (_category == null) _err['category'] = 'Choose what the issue is about.';
      if (_subject.text.trim().length < 3) _err['subject'] = 'Say what the problem is.';
    });
    if (_err.isNotEmpty) return;
    final desc = _description.text.trim();
    submit((api) async {
      String? photoId;
      if (_photo case final p?) {
        final up = await api.upload<Map<String, dynamic>>(
          '/uploads',
          filePath: p.path,
          fields: {'purpose': 'ticket_photo'},
        );
        photoId = '${up.data['id']}';
      }
      return api.post<Object?>(
        '/tickets',
        body: {
          'client_uuid': _clientId,
          'partner_id': widget.store.id,
          'category': _category,
          'priority': _high ? 'high' : 'normal',
          'subject': _subject.text.trim(),
          'description': desc.isEmpty ? null : desc,
          'photo_upload_id': ?photoId,
        },
      );
    }, done: 'Ticket raised');
  }

  @override
  Widget build(BuildContext context) {
    final cats = (ref.watch(appConfigProvider).value ?? const AppConfig()).field.ticketCategories;
    return FormPage(
      title: 'Raise ticket',
      submitLabel: 'Raise ticket',
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text(widget.store.name, style: context.text.label),
        ChoiceGroup<String>(
          label: 'About',
          options: cats,
          value: _category,
          onChanged: (v) => setState(() => _category = v),
          errorText: _e('category'),
        ),
        AppField(
          controller: _subject,
          label: 'Problem',
          hint: 'Short supply of paracetamol',
          maxLength: 150,
          textCapitalization: TextCapitalization.sentences,
          errorText: _e('subject'),
        ),
        AppField(
          controller: _description,
          label: 'Details',
          hint: 'Optional',
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('description'),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _high = !_high),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Urgent', style: context.text.body),
                    Text('The store can\'t sell or bill until it is fixed.', style: context.text.label),
                  ],
                ),
              ),
              Switch(
                value: _high,
                onChanged: (v) => setState(() => _high = v),
                activeTrackColor: context.colors.accent,
              ),
            ],
          ),
        ),
        const SectionLabel('Photo'),
        if (_photo case final p?)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: Image.file(File(p.path), height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: Space.sm,
                right: Space.sm,
                child: IconTile(
                  AppIcons.close,
                  semanticLabel: 'Remove photo',
                  background: context.colors.card,
                  color: context.colors.textPrimary,
                  onTap: () => setState(() => _photo = null),
                ),
              ),
            ],
          )
        else
          AppButton(
            label: 'Add a photo',
            icon: AppIcons.camera,
            kind: ButtonKind.secondary,
            onPressed: () async {
              try {
                final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
                if (f != null && mounted) setState(() => _photo = f);
              } catch (_) {
                final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
                if (f != null && mounted) setState(() => _photo = f);
              }
            },
          ),
      ],
    );
  }
}
