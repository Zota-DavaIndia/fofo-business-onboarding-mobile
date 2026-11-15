import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/submit.dart';
import '../../core/widgets/widgets.dart';
import '../leads/lead.dart';
import 'visit.dart';
import '../../core/widgets/toast.dart';

/// Schedule a visit for [lead], or move [visit] to a new time.
class ScheduleVisitScreen extends ConsumerStatefulWidget {
  const ScheduleVisitScreen({super.key, required this.lead, this.visit});

  final Lead lead;
  final Visit? visit;

  @override
  ConsumerState<ScheduleVisitScreen> createState() => _ScheduleVisitScreenState();
}

class _ScheduleVisitScreenState extends ConsumerState<ScheduleVisitScreen> with FormSubmit {
  late DateTime? _at = widget.visit?.scheduledAt;
  late final _notes = TextEditingController(text: widget.visit?.notes ?? '');
  final _clientId = newClientId();
  String? _localError;

  bool get _moving => widget.visit != null;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (_at == null) {
      setState(() => _localError = 'Pick a day and time.');
      return;
    }
    final notes = _notes.text.trim();
    submit(
      (api) => _moving
          ? api.patch<dynamic>(
              '/visits/${widget.visit!.id}',
              body: {'scheduled_at': isoWithOffset(_at!), if (notes.isNotEmpty) 'notes': notes},
            )
          : api.post<dynamic>(
              '/leads/${widget.lead.id}/visits',
              body: {
                'kind': 'schedule',
                'client_uuid': _clientId,
                'captured_at': isoWithOffset(DateTime.now()),
                'scheduled_at': isoWithOffset(_at!),
                if (notes.isNotEmpty) 'notes': notes,
              },
            ),
      done: _moving ? 'Visit moved to ${formatPicked(_at!)}' : 'Visit scheduled for ${formatPicked(_at!)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: _moving ? 'Reschedule visit' : 'Schedule a visit',
      submitLabel: _moving ? 'Save new time' : 'Schedule visit',
      submitIcon: AppIcons.calendar,
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text(
          [widget.lead.name, ?(widget.lead.address ?? widget.visit?.address)].join(' · '),
          style: context.text.label,
        ),
        PickerField(
          label: 'When',
          value: _at == null ? null : formatPicked(_at!),
          hint: 'Pick a day and time',
          icon: AppIcons.calendar,
          errorText: _localError ?? fieldError('scheduled_at'),
          onTap: () async {
            final d = await pickDateTime(context, initial: _at);
            if (d != null) {
              setState(() {
                _at = d;
                _localError = null;
              });
            }
          },
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

/// Cancel a scheduled visit, with a reason.
class CancelVisitScreen extends ConsumerStatefulWidget {
  const CancelVisitScreen({super.key, required this.visit});

  final Visit visit;

  @override
  ConsumerState<CancelVisitScreen> createState() => _CancelVisitScreenState();
}

class _CancelVisitScreenState extends ConsumerState<CancelVisitScreen> with FormSubmit {
  final _reason = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.visit.scheduledAt;
    return FormPage(
      title: 'Cancel visit',
      submitLabel: 'Cancel visit',
      submitting: submitting,
      onSubmit: () {
        if (_reason.text.trim().isEmpty) {
          setState(() => _localError = 'Say why it is cancelled.');
          return;
        }
        submit(
          (api) => api.post<dynamic>('/visits/${widget.visit.id}/cancel', body: {'reason': _reason.text.trim()}),
          done: 'Visit cancelled',
        );
      },
      children: [
        Text([widget.visit.leadName, if (at != null) formatPicked(at)].join(' · '), style: context.text.label),
        AppField(
          controller: _reason,
          label: 'Reason',
          hint: 'Partner not available',
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          errorText: _localError ?? fieldError('reason'),
        ),
      ],
    );
  }
}

/// Where the phone is, or why we don't know.
sealed class _Fix {
  const _Fix();
}

class _Locating extends _Fix {
  const _Locating();
}

class _NoFix extends _Fix {
  const _NoFix(this.message, {this.openSettings = false, this.openLocation = false});

  final String message;
  final bool openSettings;
  final bool openLocation;
}

class _GotFix extends _Fix {
  const _GotFix(this.position);

  final Position position;
}

/// Check in at a lead's shop: GPS, a photo and the site assessment.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, required this.lead});

  final Lead lead;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> with FormSubmit {
  _Fix _fix = const _Locating();
  XFile? _photo;
  String? _footfall;
  late String? _investment = switch (widget.lead.investmentReady) {
    'yes' || 'no' || 'maybe' => widget.lead.investmentReady,
    _ => null,
  };
  late final _area = TextEditingController(text: widget.lead.shopAreaSqft?.toString() ?? '');
  final _frontage = TextEditingController();
  final _hospitals = TextEditingController();
  final _pharmacies = TextEditingController();
  final _notes = TextEditingController();
  // The store address starts from the enquiry address; GPS fills what is still empty.
  late final _storeAddress = TextEditingController(
    text: widget.lead.storeLocation?.address ?? widget.lead.address ?? '',
  );
  late final _storeLandmark = TextEditingController(text: widget.lead.storeLocation?.landmark ?? '');
  late final _storePincode = TextEditingController(
    text: widget.lead.storeLocation?.pincode ?? widget.lead.pincode ?? '',
  );

  /// Set when the address or pincode came from the GPS lookup.
  bool _filledFromGps = false;

  /// The proposed store is where the phone is now. Off when the store will
  /// be somewhere else; its pin then stays as it was.
  bool _storeHere = true;

  final _clientId = newClientId();
  String? _localError;

  static const _footfalls = [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')];

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    for (final c in [_area, _frontage, _hospitals, _pharmacies, _notes, _storeAddress, _storeLandmark, _storePincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _fix = const _Locating());
    final fix = await _readFix();
    if (!mounted) return;
    setState(() => _fix = fix);
    if (fix is _GotFix) _fillFromGps(fix.position);
  }

  /// Fills an empty store address or pincode from the street address at the
  /// phone's position. Optional: when the lookup fails the user types them.
  Future<void> _fillFromGps(Position p) async {
    if (!_storeHere || (_storeAddress.text.trim().isNotEmpty && _storePincode.text.trim().isNotEmpty)) return;
    try {
      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/geo/address', query: {'lat': p.latitude, 'lng': p.longitude});
      if (!mounted || !_storeHere) return;
      var filled = false;
      if (res.data['address'] case final String address when _storeAddress.text.trim().isEmpty) {
        _storeAddress.text = address;
        filled = true;
      }
      if (res.data['pincode'] case final String pincode when _storePincode.text.trim().isEmpty) {
        _storePincode.text = pincode;
        filled = true;
      }
      if (filled) setState(() => _filledFromGps = true);
    } catch (_) {
      // not set up on the server, or offline
    }
  }

  Future<_Fix> _readFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const _NoFix('Location is off. Turn it on to check in.', openLocation: true);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        return const _NoFix('Allow location so the visit can be verified.');
      }
      if (perm == LocationPermission.deniedForever) {
        return const _NoFix('Location is blocked for this app. Allow it in Settings.', openSettings: true);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)),
      );
      return _GotFix(p);
    } catch (_) {
      return const _NoFix("Couldn't get your location. Move to open sky and try again.");
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (file != null && mounted) setState(() => _photo = file);
    } catch (_) {
      if (!mounted) return;
      showToast(
        context,
        source == ImageSource.camera
            ? "Couldn't open the camera. Choose a photo instead."
            : "Couldn't open your photos.",
        kind: ToastKind.error,
      );
    }
  }

  void _save() {
    final fix = _fix;
    if (fix is! _GotFix) {
      setState(() => _localError = 'Wait for your location before checking in.');
      return;
    }
    setState(() => _localError = null);
    final p = fix.position;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    submit((api) async {
      String? photoId;
      if (_photo case final photo?) {
        final up = await api.upload<Map<String, dynamic>>(
          '/uploads',
          filePath: photo.path,
          fields: {'purpose': 'visit_photo'},
        );
        photoId = '${up.data['id']}';
      }
      return api.post<dynamic>(
        '/leads/${widget.lead.id}/visits',
        body: {
          'kind': 'checkin',
          'client_uuid': _clientId,
          'captured_at': isoWithOffset(p.timestamp),
          'latitude': p.latitude,
          'longitude': p.longitude,
          'gps_accuracy_m': p.accuracy,
          'is_mock_location': p.isMocked,
          'photo_upload_id': ?photoId,
          'shop_area_sqft': ?int.tryParse(_area.text.trim()),
          'frontage_ft': ?int.tryParse(_frontage.text.trim()),
          'footfall': ?_footfall,
          'nearby_hospitals': ?t(_hospitals),
          'competing_pharmacies': ?t(_pharmacies),
          'investment_confirmed': ?_investment,
          'notes': ?t(_notes),
          'store_address': ?t(_storeAddress),
          'store_landmark': ?t(_storeLandmark),
          'store_pincode': ?t(_storePincode),
          // The store pin is only ever the phone's real position.
          if (_storeHere) ...{'store_latitude': p.latitude, 'store_longitude': p.longitude},
        },
      );
    }, done: 'Checked in');
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider).value ?? const AppConfig();
    return FormPage(
      title: 'Check in',
      submitLabel: 'Check in',
      submitIcon: AppIcons.locate,
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text(widget.lead.name, style: context.text.label),
        _LocationCard(fix: _fix, lead: widget.lead, config: config, onRetry: _locate),
        if (_localError != null) Text(_localError!, style: context.text.label.copyWith(color: context.colors.danger)),
        const SectionLabel('Shop photo'),
        if (_photo case final photo?)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: Image.file(File(photo.path), height: 180, width: double.infinity, fit: BoxFit.cover),
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
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Take photo',
                  icon: AppIcons.camera,
                  kind: ButtonKind.secondary,
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: AppButton(
                  label: 'Choose',
                  icon: AppIcons.upload,
                  kind: ButtonKind.secondary,
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
        if (fieldError('photo_upload_id') case final e?)
          Text(e, style: context.text.label.copyWith(color: context.colors.danger)),
        const SectionLabel('Proposed store'),
        AppField(
          controller: _storeAddress,
          label: 'Store address',
          hint: 'Shop no., street, area',
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('store_address'),
        ),
        if (_filledFromGps)
          Text(
            'Filled from your location. Check the shop number and street.',
            style: context.text.label.copyWith(color: context.colors.textSecondary),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppField(
                controller: _storeLandmark,
                label: 'Landmark',
                hint: 'Near…',
                textCapitalization: TextCapitalization.sentences,
                errorText: fieldError('store_landmark'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              flex: 2,
              child: AppField(
                controller: _storePincode,
                label: 'Pincode',
                keyboardType: TextInputType.number,
                maxLength: 6,
                errorText: fieldError('store_pincode'),
              ),
            ),
          ],
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _storeHere = !_storeHere),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('The store is where I am now', style: context.text.body),
                    Text(
                      _storeHere ? 'Pins the store at your location.' : 'The store pin is left as it is.',
                      style: context.text.label,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _storeHere,
                onChanged: (v) => setState(() => _storeHere = v),
                activeTrackColor: context.colors.accent,
              ),
            ],
          ),
        ),
        const SectionLabel('Site'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _area,
                label: 'Area, sq ft',
                keyboardType: TextInputType.number,
                errorText: fieldError('shop_area_sqft'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(
                controller: _frontage,
                label: 'Frontage, ft',
                keyboardType: TextInputType.number,
                errorText: fieldError('frontage_ft'),
              ),
            ),
          ],
        ),
        ChoiceGroup<String>(
          label: 'Footfall',
          options: _footfalls,
          value: _footfall,
          errorText: fieldError('footfall'),
          onChanged: (v) => setState(() => _footfall = v),
        ),
        AppField(
          controller: _hospitals,
          label: 'Hospitals and clinics nearby',
          hint: 'Optional',
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('nearby_hospitals'),
        ),
        AppField(
          controller: _pharmacies,
          label: 'Other pharmacies nearby',
          hint: 'Optional',
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('competing_pharmacies'),
        ),
        ChoiceGroup<String>(
          label: 'Ready to invest?',
          options: const [('yes', 'Yes'), ('maybe', 'Maybe'), ('no', 'No')],
          value: _investment,
          errorText: fieldError('investment_confirmed'),
          onChanged: (v) => setState(() => _investment = v),
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.fix, required this.lead, required this.config, required this.onRetry});

  final _Fix fix;
  final Lead lead;
  final AppConfig config;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color tone, String title, String body, Widget? action) = switch (fix) {
      _Locating() => (c.textSecondary, 'Finding your location…', 'Stay near the shop.', null),
      _NoFix(:final message, :final openSettings, :final openLocation) => (
        c.danger,
        'No location yet',
        message,
        TextLink(
          label: openSettings ? 'Open Settings' : (openLocation ? 'Location settings' : 'Try again'),
          onTap: openSettings
              ? Geolocator.openAppSettings
              : openLocation
              ? Geolocator.openLocationSettings
              : onRetry,
        ),
      ),
      _GotFix(:final position) => _describe(context, position),
    };
    return AppCard(
      color: c.tintOf(tone),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(AppIcons.locate, color: tone, background: c.tintOf(tone)),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.bodyStrong.copyWith(color: tone)),
                const SizedBox(height: 2),
                Text(body, style: context.text.label),
                if (action != null) ...[const SizedBox(height: Space.xs), action],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, String, String, Widget?) _describe(BuildContext context, Position p) {
    final c = context.colors;
    final accuracy = 'GPS within ${p.accuracy.round()} m';
    final retry = TextLink(label: 'Refresh location', onTap: onRetry);
    if (p.isMocked) {
      return (c.danger, 'Mock location detected', 'Turn off any location faking app. This visit won\'t count.', retry);
    }
    final weak = p.accuracy > config.maxGpsAccuracyM;
    if (!lead.hasLocation) {
      return (
        weak ? c.warning : c.info,
        'First visit to this shop',
        "This check-in sets the shop's location. $accuracy.",
        weak ? retry : null,
      );
    }
    final d = Geolocator.distanceBetween(p.latitude, p.longitude, lead.latitude!, lead.longitude!).round();
    final far = d > config.geofenceRadiusM;
    if (!far && !weak) return (c.success, "You're at the shop", '$d m away · $accuracy', null);
    final why = far
        ? '$d m from the shop; it must be within ${config.geofenceRadiusM} m.'
        : 'GPS is only accurate to ${p.accuracy.round()} m; it needs ${config.maxGpsAccuracyM} m.';
    return (c.warning, "This visit won't be verified", '$why You can still check in.', retry);
  }
}

/// Close an open check-in with its outcome.
class CheckOutScreen extends ConsumerStatefulWidget {
  const CheckOutScreen({super.key, required this.visit});

  final Visit visit;

  @override
  ConsumerState<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends ConsumerState<CheckOutScreen> with FormSubmit {
  String? _outcome;
  String? _reason;
  DateTime? _nextVisit;
  final _summary = TextEditingController();
  final _clientId = newClientId();
  String? _localError;
  String? _summaryError;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  void _save() {
    final err = switch (_outcome) {
      null => 'Pick how the visit ended.',
      'follow_up' when _nextVisit == null => 'Pick when to visit next.',
      'not_qualified' || 'dropped' when _reason == null => 'Pick a reason.',
      _ => null,
    };
    final summary = _summary.text.trim();
    setState(() {
      _localError = err;
      _summaryError = summary.isEmpty ? 'Add a short summary of the visit.' : null;
    });
    if (err != null || _summaryError != null) return;
    submit(
      (api) => api.post<dynamic>(
        '/leads/${widget.visit.leadId}/visits',
        body: {
          'kind': 'checkout',
          'client_uuid': _clientId,
          'captured_at': isoWithOffset(DateTime.now()),
          'visit_id': widget.visit.id,
          'outcome': _outcome,
          'summary': summary,
          if (_outcome == 'not_qualified' || _outcome == 'dropped') 'reason': _reason,
          if (_outcome == 'follow_up') 'next_visit_at': isoWithOffset(_nextVisit!),
        },
      ),
      done: 'Checked out',
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final statuses = ref.watch(statusesProvider).value ?? const {};
    final reasons = switch (_outcome) {
      'not_qualified' => statuses['NOT_QUALIFIED']?.reasons ?? const <String>[],
      'dropped' => statuses['DROPPED']?.reasons ?? const <String>[],
      _ => const <String>[],
    };
    final since = v.checkedInAt;
    final c = context.colors;
    final options = <(String, String, AppIconData, Color, String?)>[
      (
        'qualified',
        'Qualified',
        AppIcons.check,
        c.success,
        v.geoVerified ? 'Opens onboarding for this lead.' : 'Needs a verified check-in. ${v.checkResult}.',
      ),
      ('follow_up', 'Follow-up visit', AppIcons.followUp, c.warning, null),
      ('not_qualified', 'Not qualified', AppIcons.alert, c.textSecondary, null),
      ('dropped', 'Dropped', AppIcons.close, c.textSecondary, null),
    ];
    return FormPage(
      title: 'Check out',
      submitLabel: 'Check out',
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text(
          [
            v.leadName,
            if (since != null) 'checked in ${formatTime(since)} · ${DateTime.now().difference(since).inMinutes} min',
          ].join(' · '),
          style: context.text.label,
        ),
        const SectionLabel('Outcome'),
        GroupedList(
          children: [
            for (final (value, label, icon, tone, hint) in options)
              ListRow(
                title: label,
                subtitle: value == _outcome ? hint : null,
                leading: IconTile(icon, color: tone, background: c.tintOf(tone)),
                trailing: _Radio(selected: value == _outcome),
                onTap: () => setState(() {
                  _outcome = value;
                  _reason = null;
                  _localError = null;
                }),
              ),
          ],
        ),
        if (_outcome == 'follow_up')
          PickerField(
            label: 'Next visit',
            value: _nextVisit == null ? null : formatPicked(_nextVisit!),
            hint: 'Pick a day and time',
            icon: AppIcons.calendar,
            errorText: fieldError('next_visit_at'),
            onTap: () async {
              final d = await pickDateTime(context, initial: _nextVisit);
              if (d != null) setState(() => _nextVisit = d);
            },
          ),
        if (reasons.isNotEmpty)
          ChoiceGroup<String>(
            label: 'Reason',
            options: [for (final r in reasons) (r, r)],
            value: _reason,
            required: true,
            errorText: fieldError('reason'),
            onChanged: (r) => setState(() => _reason = r),
          ),
        if ((_localError ?? fieldError('outcome')) case final e?)
          Text(e, style: context.text.label.copyWith(color: c.danger)),
        AppField(
          controller: _summary,
          label: 'Summary',
          hint: 'What you found',
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          errorText: _summaryError ?? fieldError('summary'),
          onChanged: (_) {
            if (_summaryError != null) setState(() => _summaryError = null);
          },
        ),
      ],
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? c.accent : c.textTertiary.withValues(alpha: 0.5), width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent),
            )
          : null,
    );
  }
}
