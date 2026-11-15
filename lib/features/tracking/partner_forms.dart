import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/file_pick.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/submit.dart';
import '../../core/widgets/widgets.dart';
import '../onboarding/onboarding.dart';
import '../onboarding/step_details.dart';
import 'partner.dart';
import 'track_session.dart';

final _panRe = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

/// The form for the partner's current step.
Widget partnerFormFor(PartnerMe me, StepKey key) => switch (key) {
  StepKey.storeBasics => PartnerStoreScreen(me: me),
  StepKey.ownerDocuments => PartnerDocsScreen(me: me),
  StepKey.payment => const PartnerPaymentScreen(),
  StepKey.drugLicence => PartnerDrugLicenceScreen(me: me),
  StepKey.partnerVerification => const SizedBox.shrink(),
};

/// Customer-side submit: same flow, partner token.
mixin _PartnerSubmit<T extends ConsumerStatefulWidget> on FormSubmit<T> {
  @override
  ApiClient get submitApi => ref.read(trackApiProvider);
}

class _FixCard extends StatelessWidget {
  const _FixCard(this.me);

  final PartnerMe me;

  @override
  Widget build(BuildContext context) {
    if (me.rejectionReason == null) return const SizedBox.shrink();
    final c = context.colors;
    return AppCard(
      color: c.tintOf(c.danger),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Please correct this', style: context.text.bodyStrong.copyWith(color: c.danger)),
          Text(me.rejectionReason!, style: context.text.body),
        ],
      ),
    );
  }
}

class PartnerStoreScreen extends ConsumerStatefulWidget {
  const PartnerStoreScreen({super.key, required this.me});

  final PartnerMe me;

  @override
  ConsumerState<PartnerStoreScreen> createState() => _PartnerStoreState();
}

class _PartnerStoreState extends ConsumerState<PartnerStoreScreen> with FormSubmit, _PartnerSubmit {
  StoreDetails get _s => widget.me.store;
  late final _name = TextEditingController(text: _s.name ?? '');
  late final _pan = TextEditingController(text: _s.pan ?? '');
  late final _gst = TextEditingController(text: _s.gstin ?? '');
  late final _area = TextEditingController(text: _s.areaSqft?.toString() ?? '');
  late final _address = TextEditingController(text: _s.address ?? '');
  late final _pincode = TextEditingController(text: _s.pincode ?? '');
  late final _city = TextEditingController(text: _s.city ?? '');
  late final _state = TextEditingController(text: _s.state ?? '');
  late String? _format = _s.format;
  late double? _lat = _s.latitude;
  late double? _lng = _s.longitude;
  PickedFile? _photo;
  bool _locating = false;
  final _err = <String, String>{};

  bool _flagged(String f) => widget.me.rejectedFields.contains(f);
  String? _e(String f) =>
      _err[f] ??
      fieldError(f) ??
      (_flagged(f) && !(f == 'storefront' && _photo != null) ? 'Please correct this.' : null);

  @override
  void dispose() {
    for (final c in [_name, _pan, _gst, _area, _address, _pincode, _city, _state]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    Position? p;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
        p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)),
        );
      }
    } catch (_) {}
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
    if (!_panRe.hasMatch(_pan.text.trim().toUpperCase())) _err['store_pan'] = 'PAN looks like ABCDE1234F.';
    if (_t(_address) == null) _err['address'] = 'Enter the shop address.';
    if (!RegExp(r'^\d{6}$').hasMatch(_pincode.text.trim())) _err['pincode'] = 'Pincode is 6 digits.';
    if (_lat == null) _err['latitude'] = 'Pin the shop location.';
    if (_flagged('storefront') && _photo == null) _err['storefront'] = 'Add a clear photo of the shop front.';
    setState(() {});
    if (_err.isNotEmpty) return;
    submit(
      (api) => api.multipart<dynamic>(
        '/partner/store-basics',
        fields: {
          'store_name': _t(_name),
          'store_format': _format,
          'store_pan': _pan.text.trim().toUpperCase(),
          'gstin': _t(_gst)?.toUpperCase(),
          'carpet_area_sqft': int.tryParse(_area.text.trim()),
          'latitude': _lat,
          'longitude': _lng,
          'address': _t(_address),
          'pincode': _pincode.text.trim(),
          'city': _t(_city),
          'state': _t(_state),
        },
        files: {if (_photo != null) 'storefront': _photo!.path},
      ),
      done: 'Store details sent',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Store details',
      submitLabel: 'Send',
      submitting: submitting,
      onSubmit: _save,
      children: [
        _FixCard(widget.me),
        AppField(
          controller: _name,
          label: 'Store name',
          textCapitalization: TextCapitalization.words,
          errorText: _e('store_name'),
        ),
        ChoiceGroup<String>(
          label: 'Format',
          options: const [('Standard', 'Standard'), ('Mini', 'Mini'), ('Mega', 'Mega')],
          value: _format,
          onChanged: (v) => setState(() => _format = v),
          errorText: _e('store_format'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _pan,
                label: 'Store PAN',
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _pincode,
                label: 'Pincode',
                keyboardType: TextInputType.number,
                maxLength: 6,
                errorText: _e('pincode'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(controller: _city, label: 'City', errorText: _e('city')),
            ),
          ],
        ),
        AppField(controller: _state, label: 'State', errorText: _e('state')),
        PickerField(
          label: 'Shop location',
          value: _lat == null ? null : 'Pinned · ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
          hint: _locating ? 'Finding your location…' : 'Pin where I am now',
          icon: AppIcons.locate,
          errorText: _e('latitude'),
          onTap: _locating ? () {} : _locate,
        ),
        FileSlot(
          label: 'Shop front photo',
          hint: 'Signboard visible',
          file: _photo,
          allowPdf: false,
          existingLabel: _s.name == null ? null : 'On file · add a new one to replace',
          onPick: (f) => setState(() => _photo = f),
          errorText: _e('storefront'),
        ),
      ],
    );
  }
}

class PartnerDocsScreen extends ConsumerStatefulWidget {
  const PartnerDocsScreen({super.key, required this.me});

  final PartnerMe me;

  @override
  ConsumerState<PartnerDocsScreen> createState() => _PartnerDocsState();
}

class _PartnerDocsState extends ConsumerState<PartnerDocsScreen> with FormSubmit, _PartnerSubmit {
  OwnerDetails get _o => widget.me.owner;
  late final _name = TextEditingController(text: _o.name ?? widget.me.name ?? '');
  late final _mobile = TextEditingController(text: _o.mobile ?? widget.me.mobile ?? '');
  late final _email = TextEditingController(text: _o.email ?? '');
  late final _address = TextEditingController(text: _o.address ?? '');
  late final _pan = TextEditingController(text: _o.pan ?? '');
  final _aadhaar = TextEditingController();
  late final _pharmacist = TextEditingController(text: _o.pharmacistName ?? '');
  late final _pharmacistReg = TextEditingController(text: _o.pharmacistRegNo ?? '');
  final _storeLicNo = TextEditingController();
  final _drugLicNo = TextEditingController();
  DateTime? _storeLicExpiry;
  DateTime? _drugLicExpiry;
  final _files = <String, PickedFile>{};
  final _err = <String, String>{};

  bool _onFile(String type) =>
      widget.me.documents.any((d) => (d.type == type || '${d.type}_file' == type) && !d.rejected);

  @override
  void dispose() {
    for (final c in [
      _name,
      _mobile,
      _email,
      _address,
      _pan,
      _aadhaar,
      _pharmacist,
      _pharmacistReg,
      _storeLicNo,
      _drugLicNo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _err.clear();
    if (_t(_name) == null) _err['owner_name'] = 'Enter your name.';
    if (!_panRe.hasMatch(_pan.text.trim().toUpperCase())) _err['owner_pan'] = 'PAN looks like ABCDE1234F.';
    final aadhaar = _aadhaar.text.replaceAll(' ', '');
    if (aadhaar.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(aadhaar)) _err['aadhaar'] = 'Aadhaar is 12 digits.';
    for (final t in partnerDocTypes) {
      final has = _files.containsKey(t.type) || _onFile(t.type);
      if (t.required && !has) _err[t.type] = 'Add this.';
      if (t.alternative != null && !has && !(_files.containsKey(t.alternative) || _onFile(t.alternative!))) {
        _err[t.type] = 'Add the licence, or the fee receipt below.';
      }
    }
    if (_files.containsKey('store_licence') && (_t(_storeLicNo) == null || _storeLicExpiry == null)) {
      _err['store_licence_number'] = 'Enter the number and expiry date.';
    }
    if (_files.containsKey('drug_licence') && (_t(_drugLicNo) == null || _drugLicExpiry == null)) {
      _err['drug_licence_number'] = 'Enter the number and expiry date.';
    }
    setState(() {});
    if (_err.isNotEmpty) return;
    submit(
      (api) => api.multipart<dynamic>(
        '/partner/owner-documents',
        fields: {
          'owner_name': _t(_name),
          'owner_mobile': _t(_mobile),
          'owner_email': _t(_email),
          'owner_address': _t(_address),
          'owner_pan': _pan.text.trim().toUpperCase(),
          if (aadhaar.isNotEmpty) 'aadhaar': aadhaar,
          'pharmacist_name': _t(_pharmacist),
          'pharmacist_reg_no': _t(_pharmacistReg),
          'store_licence_number': _t(_storeLicNo),
          if (_storeLicExpiry != null) 'store_licence_expiry_date': isoDay(_storeLicExpiry!),
          'drug_licence_number': _t(_drugLicNo),
          if (_drugLicExpiry != null) 'drug_licence_expiry_date': isoDay(_drugLicExpiry!),
        },
        files: {for (final e in _files.entries) e.key: e.value.path},
      ),
      done: 'Documents sent',
    );
  }

  Widget _expiry(String label, DateTime? value, ValueChanged<DateTime> onPick) => PickerField(
    label: label,
    value: value == null ? null : formatDay(value),
    hint: 'Pick date',
    icon: AppIcons.calendar,
    onTap: () async {
      final now = DateTime.now();
      final d = await pickDate(context, initial: value ?? now.add(const Duration(days: 365)), first: now);
      if (d != null) onPick(d);
    },
  );

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Owner documents',
      submitLabel: 'Send',
      submitting: submitting,
      onSubmit: _save,
      children: [
        _FixCard(widget.me),
        const SectionLabel('About you'),
        AppField(
          controller: _name,
          label: 'Full name',
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
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                errorText: _err['owner_pan'] ?? fieldError('owner_pan'),
              ),
            ),
          ],
        ),
        AppField(
          controller: _aadhaar,
          label: 'Aadhaar',
          hint: _o.aadhaarMasked ?? '12 digits',
          keyboardType: TextInputType.number,
          maxLength: 14,
          errorText: _err['aadhaar'] ?? fieldError('aadhaar'),
        ),
        AppField(
          controller: _email,
          label: 'Email',
          hint: 'Optional',
          keyboardType: TextInputType.emailAddress,
          errorText: fieldError('owner_email'),
        ),
        AppField(
          controller: _address,
          label: 'Home address',
          minLines: 2,
          maxLines: 4,
          errorText: fieldError('owner_address'),
        ),
        const SectionLabel('Pharmacist'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(controller: _pharmacist, label: 'Name', errorText: fieldError('pharmacist_name')),
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
        for (final t in partnerDocTypes) ...[
          FileSlot(
            label: [t.label, if (t.alternativeFor != null) '(if the licence is still pending)'].join(' '),
            file: _files[t.type],
            existingLabel: _onFile(t.type) ? 'On file · add a new one to replace' : null,
            allowPdf: t.type != 'owner_photo',
            onPick: (f) => setState(() => _files[t.type] = f),
            errorText: _err[t.type] ?? fieldError(t.type),
          ),
          if (t.type == 'store_licence' && _files.containsKey('store_licence')) ...[
            AppField(controller: _storeLicNo, label: 'Store licence number', errorText: _err['store_licence_number']),
            _expiry('Store licence valid till', _storeLicExpiry, (d) => setState(() => _storeLicExpiry = d)),
          ],
          if (t.type == 'drug_licence' && _files.containsKey('drug_licence')) ...[
            AppField(controller: _drugLicNo, label: 'Drug licence number', errorText: _err['drug_licence_number']),
            _expiry('Drug licence valid till', _drugLicExpiry, (d) => setState(() => _drugLicExpiry = d)),
          ],
        ],
      ],
    );
  }
}

/// Bank details, what's left to pay, past transfers and a form to report one.
class PartnerPaymentScreen extends ConsumerWidget {
  const PartnerPaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fee = ref.watch(partnerFeeProvider);
    final payments = ref.watch(partnerPaymentsProvider).value ?? const <Payment>[];
    final f = fee.value;
    // Paying needs the real figures from the CRM: nothing is offered until it says what is left.
    final canPay = (f?.toReport ?? 0) > 0;
    return PageBody(
      bottom: canPay
          ? ActionBar(
              children: [
                AppButton(
                  label: 'I have paid',
                  icon: AppIcons.rupee,
                  onPressed: () async {
                    final saved = await pushForm<bool>(context, PartnerReportPaymentScreen(fee: f));
                    if (saved == true) ref.read(partnerRevisionProvider.notifier).bump();
                  },
                ),
              ],
            )
          : null,
      children: [
        PageHeader('Franchise fee', onBack: () => Navigator.of(context).maybePop()),
        if (f == null && fee.hasError)
          MessageBlock(
            icon: AppIcons.alert,
            title: "Couldn't load the fee",
            body: 'Check your connection and try again.',
            action: AppButton(
              label: 'Try again',
              kind: ButtonKind.secondary,
              onPressed: () => ref.invalidate(partnerFeeProvider),
            ),
          )
        else if (f == null)
          const SkeletonScope(child: SkeletonCard(lines: 4))
        else if (!f.set)
          AppCard(child: Text('The franchise fee shows here once Dava India sets it.', style: context.text.secondary))
        else ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Left to pay', style: context.text.secondary),
                Text(rupees(f.balance!), style: context.text.title),
                Text(
                  [
                    'Total ${rupees(f.total!)} incl. GST',
                    if (f.paidVerified > 0) '${rupees(f.paidVerified)} received',
                    if (f.paidPending > 0) '${rupees(f.paidPending)} being checked',
                  ].join(' · '),
                  style: context.text.label,
                ),
              ],
            ),
          ),
          if (f.accountNo != null) ...[
            const SectionLabel('Transfer to'),
            GroupedList(
              children: [
                if (f.beneficiary != null) _Copy('Beneficiary', f.beneficiary!),
                _Copy('Account no.', f.accountNo!),
                if (f.ifsc != null) _Copy('IFSC', f.ifsc!),
                if (f.bank != null && f.bank!.isNotEmpty) _Copy('Bank', f.bank!),
              ],
            ),
            Text('Pay by NEFT, RTGS, IMPS or UPI, then tap "I have paid".', style: context.text.label),
          ],
        ],
        if (payments.isNotEmpty) ...[
          const SectionLabel('Your transfers'),
          GroupedList(
            children: [
              for (final p in payments)
                ListRow(
                  title: '${rupees(p.amount)} · ${p.mode ?? ''}',
                  subtitle: [if (p.utr != null) 'UTR ${p.utr}', if (p.date != null) formatDay(p.date!)].join(' · '),
                  trailing: StatusBadge(
                    switch (p.state) {
                      'verified' => 'Received',
                      'rejected' => 'Not found',
                      _ => 'Checking',
                    },
                    tone: switch (p.state) {
                      'verified' => Tone.success,
                      'rejected' => Tone.danger,
                      _ => Tone.info,
                    },
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy(this.label, this.value);

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

class PartnerReportPaymentScreen extends ConsumerStatefulWidget {
  const PartnerReportPaymentScreen({super.key, this.fee});

  final Fee? fee;

  @override
  ConsumerState<PartnerReportPaymentScreen> createState() => _PartnerReportPaymentState();
}

class _PartnerReportPaymentState extends ConsumerState<PartnerReportPaymentScreen> with FormSubmit, _PartnerSubmit {
  final _utr = TextEditingController();
  late final _amount = TextEditingController(text: widget.fee?.toReport?.round().toString() ?? '');
  final _payer = TextEditingController();
  final _account = TextEditingController();
  final _bank = TextEditingController();
  DateTime? _date = DateTime.now();
  String? _mode = 'NEFT';
  PickedFile? _proof;
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
    if (!isUtr(cleanUtr(_utr.text))) _err['utr'] = 'The UTR is 10 to 22 letters or digits, from your bank advice.';
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) _err['payment_amount'] = 'Enter the amount you sent.';
    if (_proof == null) _err['proof'] = 'Add the payment advice or a screenshot.';
    setState(() {});
    if (_err.isNotEmpty) return;
    submit(
      (api) => api.multipart<dynamic>(
        '/partner/payment',
        fields: {
          'utr': cleanUtr(_utr.text),
          'payment_date': isoDay(_date!),
          'payment_amount': amount,
          'payment_mode': _mode,
          'payer_name': _t(_payer),
          'payer_account': _t(_account),
          'payer_bank': _t(_bank),
        },
        files: {'proof': _proof!.path},
      ),
      done: "Thanks. We'll confirm once the transfer is checked.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Report a transfer',
      submitLabel: 'Send',
      submitting: submitting,
      onSubmit: _save,
      children: [
        AppField(
          controller: _utr,
          label: 'UTR / reference',
          hint: 'From your bank or UPI app',
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
                errorText: _err['payment_amount'] ?? fieldError('payment_amount'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: PickerField(
                label: 'Paid on',
                value: _date == null ? null : formatDay(_date!),
                hint: 'Pick date',
                icon: AppIcons.calendar,
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
          options: const [('NEFT', 'NEFT'), ('RTGS', 'RTGS'), ('IMPS', 'IMPS'), ('UPI', 'UPI')],
          value: _mode,
          required: true,
          onChanged: (v) => setState(() => _mode = v),
        ),
        AppField(
          controller: _payer,
          label: 'Paid by',
          hint: 'Account holder name',
          textCapitalization: TextCapitalization.words,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _account,
                label: 'From account',
                hint: 'Optional',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(controller: _bank, label: 'Bank', hint: 'Optional'),
            ),
          ],
        ),
        FileSlot(
          label: 'Payment advice or screenshot',
          file: _proof,
          onPick: (f) => setState(() => _proof = f),
          errorText: _err['proof'] ?? fieldError('proof'),
        ),
      ],
    );
  }
}

class PartnerDrugLicenceScreen extends ConsumerStatefulWidget {
  const PartnerDrugLicenceScreen({super.key, required this.me});

  final PartnerMe me;

  @override
  ConsumerState<PartnerDrugLicenceScreen> createState() => _PartnerDrugLicenceState();
}

class _PartnerDrugLicenceState extends ConsumerState<PartnerDrugLicenceScreen> with FormSubmit, _PartnerSubmit {
  late final _number = TextEditingController(text: widget.me.drugLicence.number ?? '');
  late String? _form = widget.me.drugLicence.form;
  late DateTime? _validTill = widget.me.drugLicence.validTill;
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
    submit(
      (api) => api.multipart<dynamic>(
        '/partner/drug-licence',
        fields: {'dl_number': _t(_number), 'dl_form': _form, 'dl_valid_till': isoDay(_validTill!)},
        files: {'file': _file!.path},
      ),
      done: 'Drug licence sent',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Drug licence',
      submitLabel: 'Send',
      submitting: submitting,
      onSubmit: _save,
      children: [
        _FixCard(widget.me),
        AppField(
          controller: _number,
          label: 'Licence number',
          textCapitalization: TextCapitalization.characters,
          errorText: _err['dl_number'] ?? fieldError('dl_number'),
        ),
        ChoiceGroup<String>(
          label: 'Form',
          options: const [('Form 20', 'Form 20'), ('Form 21', 'Form 21'), ('Form 20/21', 'Form 20/21')],
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
          errorText: _err['file'] ?? fieldError('file'),
        ),
      ],
    );
  }
}

/// The customer's inbox: approvals, corrections, visits, store live.
class CustomerInboxScreen extends ConsumerWidget {
  const CustomerInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(customerInboxProvider);
    return PageBody(
      onRefresh: () async {
        ref.invalidate(customerInboxProvider);
        await ref.read(customerInboxProvider.future);
      },
      children: [
        PageHeader(
          'Updates',
          onBack: () => Navigator.of(context).maybePop(),
          trailing: (inbox.value?.unread ?? 0) > 0
              ? TextLink(
                  label: 'Mark all read',
                  onTap: () async {
                    await ref.read(trackApiProvider).post<dynamic>('/partner/notifications/read-all');
                    ref.invalidate(customerInboxProvider);
                  },
                )
              : null,
        ),
        ...inbox.when(
          skipLoadingOnReload: true,
          loading: () => [const SkeletonScope(child: SkeletonRows(count: 4, lead: BoneLead.tile, badge: false))],
          error: (_, _) => [
            const SizedBox(height: Space.xl),
            const MessageBlock(icon: AppIcons.alert, title: "Couldn't load updates", body: 'Pull down to try again.'),
          ],
          data: (d) => d.items.isEmpty
              ? [
                  const SizedBox(height: Space.xl),
                  const MessageBlock(
                    icon: AppIcons.bell,
                    title: 'No updates yet',
                    body: "We'll let you know here when something changes.",
                  ),
                ]
              : [
                  GroupedList(
                    children: [
                      for (final n in d.items)
                        ListRow(
                          title: n.title,
                          subtitle: [if (n.body != null) n.body!, if (n.at != null) formatDate(n.at!)].join(' · '),
                          leading: IconTile(
                            AppIcons.bell,
                            color: n.read ? context.colors.textTertiary : context.colors.accent,
                            background: n.read ? context.fieldFill : context.colors.accentTint,
                          ),
                          onTap: n.read
                              ? null
                              : () async {
                                  await ref.read(trackApiProvider).post<dynamic>('/partner/notifications/${n.id}/read');
                                  ref.invalidate(customerInboxProvider);
                                },
                        ),
                    ],
                  ),
                ],
        ),
      ],
    );
  }
}

/// What the partner has sent for one step, read-only.
class CustomerDetailsScreen extends ConsumerWidget {
  const CustomerDetailsScreen({super.key, required this.step});

  final StepKey step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(partnerMeProvider).value;
    final mine = me?.myTurn == step;
    return PageBody(
      onRefresh: () async => ref.read(partnerRevisionProvider.notifier).bump(),
      bottom: me != null && mine
          ? ActionBar(
              children: [
                AppButton(
                  label: me.fixing ? 'Correct' : 'Continue',
                  onPressed: () async {
                    final saved = await pushForm<bool>(context, partnerFormFor(me, step));
                    if (saved == true) ref.read(partnerRevisionProvider.notifier).bump();
                  },
                ),
              ],
            )
          : null,
      children: [
        PageHeader(step.title, onBack: () => Navigator.of(context).maybePop()),
        if (me == null)
          const SkeletonScope(child: SkeletonCard(lines: 5))
        else
          ...switch (step) {
            StepKey.storeBasics => storeDetails(me.store),
            StepKey.ownerDocuments => ownerDetails(me.owner, me.documents),
            StepKey.drugLicence => drugLicenceDetails(me.drugLicence),
            _ => const <Widget>[],
          },
      ],
    );
  }
}

/// Rows on the partner's home for each step they have sent.
class PartnerDetailsList extends ConsumerWidget {
  const PartnerDetailsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(partnerMeProvider).value;
    if (me == null) return const SizedBox.shrink();
    final rows = <(StepKey, String)>[
      if (me.store.name != null) (StepKey.storeBasics, me.store.name!),
      if (me.owner.name != null || me.documents.isNotEmpty)
        (StepKey.ownerDocuments, '${me.documents.length} ${me.documents.length == 1 ? 'document' : 'documents'}'),
      if (me.payment case final pay? when pay.required)
        (
          StepKey.payment,
          !pay.set ? 'Fee not set yet' : (pay.balance! <= 0 ? 'Paid in full' : '${rupees(pay.balance!)} left'),
        ),
      if (!me.drugLicence.isEmpty) (StepKey.drugLicence, me.drugLicence.number!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Your details'),
        GroupedList(
          children: [
            for (final (k, sub) in rows)
              ListRow(
                title: k.title,
                subtitle: sub,
                trailing: AppIcon(AppIcons.right, size: Sizes.iconSmall, color: context.colors.textTertiary),
                onTap: () => pushForm<void>(
                  context,
                  k == StepKey.payment ? const PartnerPaymentScreen() : CustomerDetailsScreen(step: k),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
