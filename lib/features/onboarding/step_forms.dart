import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/file_pick.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/signature_pad.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/submit.dart';
import '../../core/widgets/widgets.dart';
import 'onboarding.dart';

final _panRe = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
final _gstinRe = RegExp(r'^[0-9]{2}[A-Z0-9]{13}$');

String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

/// Best-effort current position; null if location is off or refused.
Future<Position?> _here() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)),
    );
  } catch (_) {
    return null;
  }
}

/// A card listing what the reviewer asked to change.
class _Rejection extends StatelessWidget {
  const _Rejection(this.step);

  final OnboardingStep? step;

  @override
  Widget build(BuildContext context) {
    final s = step;
    if (s == null || s.state != StepStatus.rejected) return const SizedBox.shrink();
    final c = context.colors;
    return AppCard(
      color: c.tintOf(c.danger),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [if (s.reviewedBy != null) s.reviewedBy!, 'sent this back'].join(' '),
            style: context.text.bodyStrong.copyWith(color: c.danger),
          ),
          if (s.rejectionReason != null) Text(s.rejectionReason!, style: context.text.body),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.value, required this.onChanged, required this.label, this.errorText});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: value ? c.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: value ? c.accent : (errorText != null ? c.danger : c.textTertiary),
                    width: 2,
                  ),
                ),
                child: value ? AppIcon(AppIcons.check, size: 14, color: c.onPrimary) : null,
              ),
              const SizedBox(width: Space.md),
              Expanded(child: Text(label, style: context.text.body)),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: Space.xs),
          Text(errorText!, style: context.text.label.copyWith(color: c.danger)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- step 1

class PartnerVerificationScreen extends ConsumerStatefulWidget {
  const PartnerVerificationScreen({super.key, required this.onboarding});

  final Onboarding onboarding;

  @override
  ConsumerState<PartnerVerificationScreen> createState() => _PartnerVerificationState();
}

class _PartnerVerificationState extends ConsumerState<PartnerVerificationScreen> with FormSubmit {
  bool _called = false;
  bool _declared = false;
  PickedFile? _photo;
  final _signature = SignatureController();
  final _clientId = newClientId();
  final _err = <String, String>{};

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  void _save() {
    _err.clear();
    if (!_called) _err['called'] = 'Call the partner on their registered mobile first.';
    if (_photo == null) _err['photo'] = 'Take a photo of the partner.';
    if (_signature.isEmpty) _err['signature'] = 'Ask the partner to sign.';
    if (!_declared) _err['declared'] = 'Confirm the declaration.';
    setState(() {});
    if (_err.isNotEmpty) return;
    final o = widget.onboarding;
    submit((api) async {
      final photoId = await uploadFile(api, _photo!, 'partner_photo');
      final dir = await getTemporaryDirectory();
      final sig = await _signature.savePng(
        '${dir.path}/signature-${o.id}-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final sigId = await uploadFile(api, PickedFile(sig.path, 'signature.png'), 'signature');
      final here = await _here();
      return api.post<dynamic>(
        '/onboardings/${o.id}/partner-verification',
        body: {
          'method': 'field_attested',
          'called_partner': true,
          'call_confirmed_at': isoWithOffset(DateTime.now()),
          'partner_photo_upload_id': photoId,
          'signature_upload_id': sigId,
          'declaration_accepted': true,
          'client_uuid': _clientId,
          'captured_at': isoWithOffset(DateTime.now()),
          if (here != null) ...{
            'latitude': here.latitude,
            'longitude': here.longitude,
            'gps_accuracy_m': here.accuracy,
          },
        },
      );
    }, done: 'Partner verified');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.onboarding;
    return FormPage(
      title: 'Verify partner',
      submitLabel: 'Verify partner',
      submitIcon: AppIcons.shield,
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text('${o.name} · ${o.number}', style: context.text.label),
        Text(
          'Meet the partner in person. This replaces an SMS code: you confirm who they are.',
          style: context.text.secondary,
        ),
        _Check(
          value: _called,
          onChanged: (v) => setState(() => _called = v),
          label: 'I called ${o.mobile ?? 'the partner'} and they confirmed the application.',
          errorText: _err['called'] ?? fieldError('called_partner'),
        ),
        FileSlot(
          label: 'Photo of the partner',
          file: _photo,
          allowPdf: false,
          onPick: (f) => setState(() => _photo = f),
          errorText: _err['photo'] ?? fieldError('partner_photo_upload_id'),
        ),
        const SectionLabel("Partner's signature"),
        SignaturePad(controller: _signature, errorText: _err['signature'] ?? fieldError('signature_upload_id')),
        _Check(
          value: _declared,
          onChanged: (v) => setState(() => _declared = v),
          label: 'I met this person, checked their ID, and they agree to the franchise terms.',
          errorText: _err['declared'] ?? fieldError('declaration_accepted'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- step 2

class StoreBasicsScreen extends ConsumerStatefulWidget {
  const StoreBasicsScreen({super.key, required this.onboarding});

  final Onboarding onboarding;

  @override
  ConsumerState<StoreBasicsScreen> createState() => _StoreBasicsState();
}

class _StoreBasicsState extends ConsumerState<StoreBasicsScreen> with FormSubmit {
  StoreDetails get _s => widget.onboarding.store;
  late final _name = TextEditingController(text: _s.name ?? '');
  late final _pan = TextEditingController(text: _s.pan ?? '');
  late final _gst = TextEditingController(text: _s.gstin ?? '');
  late final _area = TextEditingController(text: _s.areaSqft?.toString() ?? '');
  late final _address = TextEditingController(text: _s.address ?? '');
  late final _pincode = TextEditingController(text: _s.pincode ?? '');
  late final _city = TextEditingController(text: _s.city ?? '');
  late final _state = TextEditingController(text: _s.state ?? '');
  late String? _format = _s.format?.toLowerCase();
  late double? _lat = _s.latitude;
  late double? _lng = _s.longitude;
  bool _locating = false;
  PickedFile? _storefront;
  final _err = <String, String>{};

  OnboardingStep? get _step => widget.onboarding.step(StepKey.storeBasics);
  bool _flagged(String field) => _step?.rejectedFields.contains(field) ?? false;

  @override
  void dispose() {
    for (final c in [_name, _pan, _gst, _area, _address, _pincode, _city, _state]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _e(String field) =>
      _err[field] ??
      fieldError(field) ??
      (_flagged(field) && !(field == 'storefront' && _storefront != null) ? 'Ops asked you to fix this.' : null);

  Future<void> _locate() async {
    setState(() => _locating = true);
    final p = await _here();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (p != null) {
        _lat = p.latitude;
        _lng = p.longitude;
      }
    });
    if (p == null) showSaveError(context, "Couldn't get your location. Check that location is on.");
  }

  void _save() {
    _err.clear();
    if (_t(_name) == null) _err['store_name'] = 'Enter the store name.';
    if (_format == null) _err['store_format'] = 'Pick the store format.';
    if (!_panRe.hasMatch(_pan.text.trim().toUpperCase())) _err['store_pan'] = 'PAN looks like ABCDE1234F.';
    final g = _gst.text.trim().toUpperCase();
    if (g.isNotEmpty && !_gstinRe.hasMatch(g)) _err['gstin'] = 'GSTIN is 15 characters.';
    if (_t(_address) == null) _err['address'] = 'Enter the shop address.';
    if (!RegExp(r'^\d{6}$').hasMatch(_pincode.text.trim())) _err['pincode'] = 'Pincode is 6 digits.';
    if (_lat == null || _lng == null) _err['latitude'] = 'Pin the shop location.';
    if (_flagged('storefront') && _storefront == null) _err['storefront'] = 'Take a new photo of the shop front.';
    setState(() {});
    if (_err.isNotEmpty) return;
    final o = widget.onboarding;
    submit((api) async {
      String? photoId;
      if (_storefront != null) photoId = await uploadFile(api, _storefront!, 'storefront');
      return api.put<dynamic>(
        '/onboardings/${o.id}/store-basics',
        body: {
          'store_name': _t(_name),
          'store_format': _format,
          'store_pan': _pan.text.trim().toUpperCase(),
          if (g.isNotEmpty) 'gstin': g,
          'carpet_area_sqft': ?int.tryParse(_area.text.trim()),
          'latitude': _lat,
          'longitude': _lng,
          'address': _t(_address),
          'pincode': _pincode.text.trim(),
          'city': ?_t(_city),
          'state': ?_t(_state),
          'storefront_upload_id': ?photoId,
        },
      );
    }, done: 'Store details sent to ops');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.onboarding;
    final masters = ref.watch(onboardingMastersProvider(o.model ?? 'FOFO')).value;
    final dup = error?.code;
    return FormPage(
      title: 'Store details',
      submitLabel: 'Send to ops',
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text('${o.name} · ${o.number}', style: context.text.label),
        _Rejection(_step),
        if (dup == 'duplicate_pan' || dup == 'duplicate_location')
          AppCard(
            color: context.colors.tintOf(context.colors.danger),
            child: Text(error!.message, style: context.text.body.copyWith(color: context.colors.danger)),
          ),
        AppField(
          controller: _name,
          label: 'Store name',
          hint: 'Dava India …',
          textCapitalization: TextCapitalization.words,
          errorText: _e('store_name'),
        ),
        ChoiceGroup<String>(
          label: 'Format',
          options: [for (final f in masters?.storeFormats ?? const []) (f.value, f.label)],
          value: _format,
          required: true,
          errorText: _e('store_format'),
          onChanged: (v) => setState(() => _format = v),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _pan,
                label: 'Store PAN',
                hint: 'ABCDE1234F',
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                errorText: _e('store_pan'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(
                controller: _gst,
                label: 'GSTIN',
                hint: 'Optional',
                maxLength: 15,
                textCapitalization: TextCapitalization.characters,
                errorText: _e('gstin'),
              ),
            ),
          ],
        ),
        AppField(
          controller: _area,
          label: 'Carpet area, sq ft',
          keyboardType: TextInputType.number,
          errorText: _e('carpet_area_sqft'),
        ),
        AppField(
          controller: _address,
          label: 'Shop address',
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          errorText: _e('address'),
        ),
        AppField(
          controller: _pincode,
          label: 'Pincode',
          keyboardType: TextInputType.number,
          maxLength: 6,
          errorText: _e('pincode'),
          onChanged: (v) async {
            if (v.length != 6) return;
            final found = await lookupPincode(ref.read(apiClientProvider), v);
            if (!mounted || found == null) return;
            setState(() {
              if (_city.text.isEmpty && found.city != null) _city.text = found.city!;
              if (_state.text.isEmpty && found.state != null) _state.text = found.state!;
            });
          },
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(controller: _city, label: 'City', errorText: _e('city')),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(controller: _state, label: 'State', errorText: _e('state')),
            ),
          ],
        ),
        PickerField(
          label: 'Shop location',
          value: _lat == null ? null : 'Pinned · ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
          hint: _locating ? 'Finding your location…' : 'Pin where I am now',
          icon: AppIcons.locate,
          errorText: _e('latitude') ?? _e('longitude'),
          onTap: _locating ? () {} : _locate,
        ),
        Text(
          _lat == null ? 'Stand in the shop and tap to pin it.' : 'Tap again while standing in the shop to re-pin.',
          style: context.text.label,
        ),
        FileSlot(
          label: 'Shop front photo',
          hint: 'Signboard visible',
          file: _storefront,
          allowPdf: false,
          existingUrl: _s.storefrontUrl,
          onPick: (f) => setState(() => _storefront = f),
          errorText: _e('storefront') ?? _e('storefront_upload_id'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- step 3

class OwnerDocsScreen extends ConsumerStatefulWidget {
  const OwnerDocsScreen({super.key, required this.onboarding});

  final Onboarding onboarding;

  @override
  ConsumerState<OwnerDocsScreen> createState() => _OwnerDocsState();
}

class _DocInput {
  _DocInput(OnboardingDoc? existing)
    : number = TextEditingController(text: existing?.number ?? ''),
      expiry = existing?.expiryDate;

  PickedFile? file;
  final TextEditingController number;
  DateTime? expiry;
}

class _OwnerDocsState extends ConsumerState<OwnerDocsScreen> with FormSubmit {
  OwnerDetails get _o => widget.onboarding.owner;
  late final _name = TextEditingController(text: _o.name ?? widget.onboarding.name);
  late final _mobile = TextEditingController(text: _o.mobile ?? widget.onboarding.mobile ?? '');
  late final _email = TextEditingController(text: _o.email ?? '');
  late final _address = TextEditingController(text: _o.address ?? '');
  late final _pan = TextEditingController(text: _o.pan ?? '');
  final _aadhaar = TextEditingController();
  late final _pharmacist = TextEditingController(text: _o.pharmacistName ?? '');
  late final _pharmacistReg = TextEditingController(text: _o.pharmacistRegNo ?? '');
  final _docs = <String, _DocInput>{};
  final _err = <String, String>{};
  String _stage = '';

  OnboardingDoc? _existing(String type) => widget.onboarding.documents.where((d) => d.type == type).firstOrNull;

  _DocInput _doc(String type) => _docs.putIfAbsent(type, () => _DocInput(_existing(type)));

  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _address, _pan, _aadhaar, _pharmacist, _pharmacistReg]) {
      c.dispose();
    }
    for (final d in _docs.values) {
      d.number.dispose();
    }
    super.dispose();
  }

  bool _hasFile(String type) => _doc(type).file != null || (_existing(type) != null && !_existing(type)!.rejected);

  void _save(List<DocType> types) {
    _err.clear();
    if (_t(_name) == null) _err['owner_name'] = "Enter the owner's name.";
    final mobile = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) _err['owner_mobile'] = "Enter the owner's 10-digit mobile.";
    final pan = _pan.text.trim().toUpperCase();
    if (!_panRe.hasMatch(pan)) _err['owner_pan'] = 'PAN looks like ABCDE1234F.';
    final aadhaar = _aadhaar.text.replaceAll(' ', '');
    if (aadhaar.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(aadhaar)) _err['aadhaar'] = 'Aadhaar is 12 digits.';
    if (aadhaar.isEmpty && _o.aadhaarMasked == null) _err['aadhaar'] = 'Enter the Aadhaar number.';
    for (final t in types) {
      final d = _doc(t.type);
      final alt = t.alternative ?? t.alternativeFor;
      final altOk = alt != null && _hasFile(alt);
      if (t.required && !_hasFile(t.type)) _err['doc_${t.type}'] = 'Add this document.';
      if (t.alternative != null && !_hasFile(t.type) && !altOk) {
        _err['doc_${t.type}'] =
            'Add this, or the ${types.where((x) => x.type == alt).firstOrNull?.label ?? 'alternative'}.';
      }
      if (d.file != null && t.needsNumber && _t(d.number) == null) _err['num_${t.type}'] = 'Enter the number.';
      if (d.file != null && t.needsExpiry && d.expiry == null) _err['exp_${t.type}'] = 'Pick the expiry date.';
    }
    setState(() {});
    if (_err.isNotEmpty) return;
    final o = widget.onboarding;
    submit((api) async {
      setState(() => _stage = 'Saving owner details…');
      await api.put<dynamic>(
        '/onboardings/${o.id}/owner',
        body: {
          'owner_name': _t(_name),
          'owner_mobile': _mobile.text.replaceAll(RegExp(r'\D'), ''),
          'owner_email': ?_t(_email),
          'owner_address': ?_t(_address),
          'owner_pan': pan,
          if (aadhaar.isNotEmpty) 'aadhaar': aadhaar,
          'pharmacist_name': ?_t(_pharmacist),
          'pharmacist_reg_no': ?_t(_pharmacistReg),
        },
      );
      for (final t in types) {
        final d = _doc(t.type);
        if (d.file == null) continue;
        setState(() => _stage = 'Uploading ${t.label}…');
        final id = await uploadFile(api, d.file!, 'document');
        await api.post<dynamic>(
          '/onboardings/${o.id}/documents',
          body: {
            'type': t.type,
            'upload_id': id,
            'number': ?_t(d.number),
            if (d.expiry != null) 'expiry_date': isoDay(d.expiry!),
          },
        );
        d.file = null;
      }
      setState(() => _stage = 'Sending for review…');
      return api.post<dynamic>('/onboardings/${o.id}/owner-documents/submit');
    }, done: 'Owner documents sent for review');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.onboarding;
    final masters = ref.watch(onboardingMastersProvider(o.model ?? 'FOFO'));
    final types = masters.value?.documentTypes ?? const <DocType>[];
    return FormPage(
      title: 'Owner, KYC and licences',
      submitLabel: submitting && _stage.isNotEmpty ? _stage : 'Send for review',
      submitting: submitting,
      onSubmit: masters.hasValue ? () => _save(types) : null,
      children: [
        Text('${o.name} · ${o.number}', style: context.text.label),
        _Rejection(o.step(StepKey.ownerDocuments)),
        const SectionLabel('Owner'),
        AppField(
          controller: _name,
          label: 'Owner name',
          textCapitalization: TextCapitalization.words,
          errorText: _err['owner_name'] ?? fieldError('owner_name'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _mobile,
                label: 'Mobile',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                errorText: fieldError('owner_mobile'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(
                controller: _pan,
                label: 'PAN',
                hint: 'ABCDE1234F',
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                errorText: _err['owner_pan'] ?? fieldError('owner_pan'),
              ),
            ),
          ],
        ),
        AppField(
          controller: _email,
          label: 'Email',
          hint: 'Optional',
          keyboardType: TextInputType.emailAddress,
          errorText: fieldError('owner_email'),
        ),
        AppField(
          controller: _aadhaar,
          label: 'Aadhaar',
          hint: _o.aadhaarMasked ?? '12 digits',
          keyboardType: TextInputType.number,
          maxLength: 14,
          errorText: _err['aadhaar'] ?? fieldError('aadhaar'),
        ),
        if (_o.aadhaarMasked != null)
          Text('On file: ${_o.aadhaarMasked}. Leave blank to keep it.', style: context.text.label),
        AppField(
          controller: _address,
          label: 'Home address',
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('owner_address'),
        ),
        const SectionLabel('Pharmacist'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _pharmacist,
                label: 'Name',
                textCapitalization: TextCapitalization.words,
                errorText: fieldError('pharmacist_name'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(
                controller: _pharmacistReg,
                label: 'Registration no.',
                errorText: fieldError('pharmacist_reg_no'),
              ),
            ),
          ],
        ),
        const SectionLabel('Documents'),
        if (masters.isLoading)
          const SkeletonScope(
            label: 'Loading document list',
            child: SkeletonRows(count: 4, lead: BoneLead.tile),
          )
        else
          for (final t in types) ..._docFields(context, t),
      ],
    );
  }

  List<Widget> _docFields(BuildContext context, DocType t) {
    final d = _doc(t.type);
    final ex = _existing(t.type);
    final optional = !t.required && t.alternative == null && t.alternativeFor == null;
    return [
      FileSlot(
        label: [
          t.label,
          if (optional) '(optional)',
          if (t.alternativeFor != null) '(instead of the licence)',
        ].join(' '),
        file: d.file,
        locked: ex?.approved ?? false,
        existingLabel: ex == null
            ? null
            : ex.rejected
            ? 'Rejected${ex.remarks == null ? '' : ': ${ex.remarks}'}'
            : (ex.status == null ? 'Uploaded' : 'Uploaded · ${ex.status!.replaceAll('_', ' ')}'),
        onPick: (f) => setState(() {
          d.file = f;
          _err.remove('doc_${t.type}');
        }),
        errorText: _err['doc_${t.type}'] ?? (ex?.rejected == true && d.file == null ? 'Upload a new copy.' : null),
      ),
      if (d.file != null && (t.needsNumber || t.needsExpiry))
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.needsNumber)
              Expanded(
                child: AppField(
                  controller: d.number,
                  label: 'Number',
                  textCapitalization: TextCapitalization.characters,
                  errorText: _err['num_${t.type}'],
                ),
              ),
            if (t.needsNumber && t.needsExpiry) const SizedBox(width: Space.md),
            if (t.needsExpiry)
              Expanded(
                child: PickerField(
                  label: 'Valid till',
                  value: d.expiry == null ? null : formatDay(d.expiry!),
                  hint: 'Pick date',
                  icon: AppIcons.calendar,
                  errorText: _err['exp_${t.type}'],
                  onTap: () async {
                    final now = DateTime.now();
                    final v = await pickDate(
                      context,
                      initial: d.expiry ?? now.add(const Duration(days: 365)),
                      first: now,
                    );
                    if (v != null) setState(() => d.expiry = v);
                  },
                ),
              ),
          ],
        ),
    ];
  }
}

// ---------------------------------------------------------------- step 4

/// Fee, bank details and the transfers recorded so far, with a button to
/// record another.
class PaymentStepScreen extends ConsumerWidget {
  const PaymentStepScreen({super.key, required this.onboardingId});

  final int onboardingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ref.watch(onboardingProvider(onboardingId));
    final fee = ref.watch(franchiseFeeProvider(onboardingId));
    final o = ob.value;
    final f = fee.value ?? o?.fee;
    final step = o?.step(StepKey.payment);
    final canRecord = o != null && (step?.state.actionable ?? false) && (f == null || f.balance - f.paidPending > 0);
    Future<void> record([Payment? edit]) async {
      if (o == null) return;
      final saved = await pushForm<bool>(context, RecordPaymentScreen(onboarding: o, fee: f, payment: edit));
      if (saved == true) {
        ref.invalidate(onboardingProvider(onboardingId));
        ref.invalidate(franchiseFeeProvider(onboardingId));
        onboardingChanged(ref);
      }
    }

    return PageBody(
      bottom: canRecord
          ? ActionBar(
              children: [AppButton(label: 'Record a payment', icon: AppIcons.rupee, onPressed: record)],
            )
          : null,
      children: [
        PageHeader('Franchise fee', onBack: () => Navigator.of(context).maybePop()),
        if (o != null) Text('${o.name} · ${o.number}', style: context.text.label),
        if (step != null) _Rejection(step),
        if (f == null)
          const SkeletonScope(child: SkeletonCard(lines: 4))
        else ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AmountRow('Fee', rupees(f.amount)),
                _AmountRow('GST', rupees(f.gst)),
                Divider(height: Space.xl, color: context.colors.separator),
                _AmountRow('Total', rupees(f.total), strong: true),
                _AmountRow('Verified', rupees(f.paidVerified)),
                if (f.paidPending > 0) _AmountRow('With finance', rupees(f.paidPending)),
                _AmountRow('Left to pay', rupees(f.balance), strong: true),
              ],
            ),
          ),
          if (f.beneficiary != null || f.accountNo != null) ...[
            const SectionLabel('Pay to'),
            GroupedList(
              children: [
                if (f.beneficiary != null) _CopyLine('Beneficiary', f.beneficiary!),
                if (f.accountNo != null) _CopyLine('Account no.', f.accountNo!),
                if (f.ifsc != null) _CopyLine('IFSC', f.ifsc!),
                if (f.bank != null && f.bank!.isNotEmpty) _CopyLine('Bank', f.bank!),
              ],
            ),
          ],
        ],
        if (o != null && o.payments.isNotEmpty) ...[
          const SectionLabel('Transfers'),
          GroupedList(
            children: [
              for (final p in o.payments)
                ListRow(
                  title: '${rupees(p.amount)} · ${p.mode ?? ''}',
                  subtitle: [
                    if (p.utr != null) 'UTR ${p.utr}',
                    if (p.date != null) formatDay(p.date!),
                    if (p.rejectionReason != null) p.rejectionReason!.replaceAll('_', ' '),
                  ].join(' · '),
                  trailing: StatusBadge(
                    switch (p.state) {
                      'verified' => 'Verified',
                      'rejected' => 'Rejected',
                      'in_review' => 'In review',
                      _ => 'Sent',
                    },
                    tone: switch (p.state) {
                      'verified' => Tone.success,
                      'rejected' => Tone.danger,
                      'in_review' => Tone.info,
                      _ => Tone.accent,
                    },
                  ),
                  onTap: p.editable ? () => record(p) : null,
                ),
            ],
          ),
          if (o.payments.any((p) => p.editable))
            Text('Tap a transfer to correct it until finance picks it up.', style: context.text.label),
        ],
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? context.text.bodyStrong : context.text.secondary)),
        Text(value, style: strong ? context.text.bodyStrong : context.text.body),
      ],
    ),
  );
}

class _CopyLine extends StatelessWidget {
  const _CopyLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListRow(
    title: value,
    subtitle: label,
    trailing: IconTile(
      AppIcons.copy,
      semanticLabel: 'Copy $label',
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        showSaved(context, '$label copied');
      },
    ),
  );
}

class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, required this.onboarding, this.fee, this.payment});

  final Onboarding onboarding;
  final Fee? fee;

  /// Set when correcting a transfer.
  final Payment? payment;

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentState();
}

class _RecordPaymentState extends ConsumerState<RecordPaymentScreen> with FormSubmit {
  Payment? get _p => widget.payment;
  late final _utr = TextEditingController(text: _p?.utr ?? '');
  late final _amount = TextEditingController(
    text: _p != null
        ? _p!.amount.round().toString()
        : ((widget.fee?.balance ?? 0) - (widget.fee?.paidPending ?? 0)).clamp(0, double.infinity).round().toString(),
  );
  late final _payer = TextEditingController(text: _p?.payerName ?? widget.onboarding.name);
  final _account = TextEditingController();
  late final _bank = TextEditingController(text: _p?.payerBank ?? '');
  late DateTime? _date = _p?.date ?? DateTime.now();
  late String? _mode = _p?.mode ?? 'NEFT';
  PickedFile? _proof;
  final _clientId = newClientId();
  final _err = <String, String>{};

  @override
  void dispose() {
    for (final c in [_utr, _amount, _payer, _account, _bank]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _err.clear();
    final utr = cleanUtr(_utr.text);
    if (!isUtr(utr)) _err['utr'] = 'The UTR is 10 to 22 letters or digits, from the bank advice.';
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) _err['amount'] = 'Enter the amount transferred.';
    if (_date == null) _err['payment_date'] = 'Pick the transfer date.';
    if (_t(_payer) == null) _err['payer_name'] = 'Enter who paid.';
    if (_p == null && _proof == null) _err['proof'] = 'Add the payment advice or a screenshot.';
    setState(() {});
    if (_err.isNotEmpty) return;
    final o = widget.onboarding;
    submit((api) async {
      String? proofId;
      if (_proof != null) proofId = await uploadFile(api, _proof!, 'payment_proof');
      final body = {
        if (_p == null) 'client_uuid': _clientId,
        'utr': utr,
        'payment_date': isoDay(_date!),
        'amount': amount,
        'mode': _mode,
        'payer_name': _t(_payer),
        'payer_account': ?_t(_account),
        'payer_bank': ?_t(_bank),
        'proof_upload_id': ?proofId,
        'captured_at': isoWithOffset(DateTime.now()),
      };
      return _p == null
          ? api.post<dynamic>('/onboardings/${o.id}/payments', body: body)
          : api.patch<dynamic>('/onboardings/${o.id}/payments/${_p!.id}', body: body);
    }, done: _p == null ? 'Payment sent to finance' : 'Payment updated');
  }

  @override
  Widget build(BuildContext context) {
    final modes =
        ref.watch(onboardingMastersProvider(widget.onboarding.model ?? 'FOFO')).value?.paymentModes ??
        const ['NEFT', 'RTGS', 'IMPS', 'UPI'];
    final code = error?.code;
    return FormPage(
      title: _p == null ? 'Record a payment' : 'Correct payment',
      submitLabel: _p == null ? 'Send to finance' : 'Save changes',
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text(widget.onboarding.name, style: context.text.label),
        if (code == 'payment_locked' || code == 'step_under_review' || code == 'duplicate_utr')
          AppCard(
            color: context.colors.tintOf(context.colors.danger),
            child: Text(error!.message, style: context.text.body.copyWith(color: context.colors.danger)),
          ),
        AppField(
          controller: _utr,
          label: 'UTR / reference',
          hint: 'From the bank or UPI app',
          textCapitalization: TextCapitalization.characters,
          errorText: _err['utr'] ?? fieldError('utr'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _amount,
                label: 'Amount, ₹',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                errorText: _err['amount'] ?? fieldError('amount'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: PickerField(
                label: 'Paid on',
                value: _date == null ? null : formatDay(_date!),
                hint: 'Pick date',
                icon: AppIcons.calendar,
                errorText: _err['payment_date'] ?? fieldError('payment_date'),
                onTap: () async {
                  final now = DateTime.now();
                  final d = await pickDate(
                    context,
                    initial: _date,
                    first: now.subtract(const Duration(days: 180)),
                    last: now,
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
          ],
        ),
        ChoiceGroup<String>(
          label: 'Mode',
          options: [for (final m in modes) (m, m)],
          value: _mode,
          required: true,
          errorText: fieldError('mode'),
          onChanged: (v) => setState(() => _mode = v),
        ),
        AppField(
          controller: _payer,
          label: 'Paid by',
          textCapitalization: TextCapitalization.words,
          errorText: _err['payer_name'] ?? fieldError('payer_name'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _account,
                label: 'From account',
                hint: _p?.payerAccountMasked ?? 'Optional',
                keyboardType: TextInputType.number,
                errorText: fieldError('payer_account'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(
                controller: _bank,
                label: 'Bank',
                hint: 'Optional',
                textCapitalization: TextCapitalization.words,
                errorText: fieldError('payer_bank'),
              ),
            ),
          ],
        ),
        FileSlot(
          label: 'Payment advice or screenshot',
          file: _proof,
          existingLabel: _p == null ? null : 'On file · add to replace',
          onPick: (f) => setState(() => _proof = f),
          errorText: _err['proof'] ?? fieldError('proof_upload_id'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- step 5

class DrugLicenceScreen extends ConsumerStatefulWidget {
  const DrugLicenceScreen({super.key, required this.onboarding});

  final Onboarding onboarding;

  @override
  ConsumerState<DrugLicenceScreen> createState() => _DrugLicenceState();
}

class _DrugLicenceState extends ConsumerState<DrugLicenceScreen> with FormSubmit {
  DrugLicence get _d => widget.onboarding.drugLicence;
  late final _number = TextEditingController(text: _d.number ?? '');
  late String? _form = _d.form;
  late DateTime? _validTill = _d.validTill;
  PickedFile? _file;
  final _err = <String, String>{};

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _save() {
    _err.clear();
    if (_t(_number) == null) _err['dl_number'] = 'Enter the licence number.';
    if (_form == null) _err['dl_form'] = 'Pick the form.';
    if (_validTill == null) _err['dl_valid_till'] = 'Pick the expiry date.';
    if (_file == null) _err['file'] = 'Add the licence.';
    setState(() {});
    if (_err.isNotEmpty) return;
    final o = widget.onboarding;
    submit((api) async {
      final id = await uploadFile(api, _file!, 'drug_licence');
      return api.post<dynamic>(
        '/onboardings/${o.id}/drug-licence',
        body: {'dl_number': _t(_number), 'dl_form': _form, 'dl_valid_till': isoDay(_validTill!), 'upload_id': id},
      );
    }, done: 'Drug licence sent to compliance');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.onboarding;
    final forms =
        ref.watch(onboardingMastersProvider(o.model ?? 'FOFO')).value?.dlForms ??
        const ['Form 20', 'Form 21', 'Form 20/21'];
    return FormPage(
      title: 'Drug licence',
      submitLabel: 'Send to compliance',
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text('${o.name} · ${o.number}', style: context.text.label),
        _Rejection(o.step(StepKey.drugLicence)),
        AppField(
          controller: _number,
          label: 'Licence number',
          textCapitalization: TextCapitalization.characters,
          errorText: _err['dl_number'] ?? fieldError('dl_number'),
        ),
        ChoiceGroup<String>(
          label: 'Form',
          options: [for (final f in forms) (f, f)],
          value: _form,
          required: true,
          errorText: _err['dl_form'] ?? fieldError('dl_form'),
          onChanged: (v) => setState(() => _form = v),
        ),
        PickerField(
          label: 'Valid till',
          value: _validTill == null ? null : formatDay(_validTill!),
          hint: 'Pick date',
          icon: AppIcons.calendar,
          errorText: _err['dl_valid_till'] ?? fieldError('dl_valid_till'),
          onTap: () async {
            final now = DateTime.now();
            final d = await pickDate(
              context,
              initial: _validTill ?? now.add(const Duration(days: 365 * 5)),
              first: now,
            );
            if (d != null) setState(() => _validTill = d);
          },
        ),
        FileSlot(
          label: 'Drug licence',
          file: _file,
          onPick: (f) => setState(() => _file = f),
          errorText: _err['file'] ?? fieldError('upload_id'),
        ),
      ],
    );
  }
}
