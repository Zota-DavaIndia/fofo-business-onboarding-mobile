import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/submit.dart';
import '../../core/widgets/widgets.dart';
import 'lead.dart';
import 'lead_actions.dart';

/// Add a lead (no [lead]) or edit one. Adding pops with the new lead's id;
/// editing pops with `true`. Mobile and source are fixed once created.
class LeadFormScreen extends ConsumerStatefulWidget {
  const LeadFormScreen({super.key, this.lead});

  final Lead? lead;

  @override
  ConsumerState<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends ConsumerState<LeadFormScreen> with FormSubmit {
  Lead? get _l => widget.lead;
  bool get _adding => _l == null;

  late final _name = TextEditingController(text: _l?.name ?? '');
  late final _mobile = TextEditingController(text: _l?.mobile ?? '');
  late final _email = TextEditingController(text: _l?.email ?? '');
  late final _pincode = TextEditingController(text: _l?.pincode ?? '');
  late final _city = TextEditingController(text: _l?.city ?? '');
  late final _state = TextEditingController(text: _l?.state ?? '');
  late final _address = TextEditingController(text: _l?.address ?? '');
  late final _area = TextEditingController(text: _l?.shopAreaSqft?.toString() ?? '');
  late final _timeline = TextEditingController(text: _l?.timeline ?? '');
  late final _notes = TextEditingController(text: _l?.notes ?? '');
  late final _campaign = TextEditingController(text: _l?.campaign ?? '');
  late final _adSet = TextEditingController(text: _l?.adSet ?? '');
  late final _utmSource = TextEditingController(text: _l?.utmSource ?? '');
  late final _utmMedium = TextEditingController(text: _l?.utmMedium ?? '');
  late final _utmCampaign = TextEditingController(text: _l?.utmCampaign ?? '');

  late String? _source = _l?.source ?? 'walk_in';
  late String? _model = _l?.model ?? 'FOFO';
  late String? _shop = _l?.shopOwnership;
  late String? _investment = _l?.investmentReady;
  late bool _consent = _l?.consent ?? false;
  late DateTime? _enquiryAt = _l?.enquiryAt;
  late bool _showCampaign = _l?.campaign != null || _l?.utmSource != null;
  String? _pincodeNote;
  final _local = <String, String>{};

  List<TextEditingController> get _controllers => [
    _name,
    _mobile,
    _email,
    _pincode,
    _city,
    _state,
    _address,
    _area,
    _timeline,
    _notes,
    _campaign,
    _adSet,
    _utmSource,
    _utmMedium,
    _utmCampaign,
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String? _err(String field) => _local[field] ?? fieldError(field);

  Future<void> _onPincode(String v) async {
    if (v.length != 6) {
      if (_pincodeNote != null) setState(() => _pincodeNote = null);
      return;
    }
    final found = await lookupPincode(ref.read(apiClientProvider), v);
    if (!mounted || _pincode.text != v) return;
    setState(() {
      if (found == null) {
        _pincodeNote = 'This pincode isn\'t in the list.';
        return;
      }
      if (_city.text.isEmpty && found.city != null) _city.text = found.city!;
      if (_state.text.isEmpty && found.state != null) _state.text = found.state!;
      _pincodeNote = found.serviceable ? null : 'Not a serviceable pincode yet.';
    });
  }

  bool _check() {
    _local.clear();
    if (_name.text.trim().isEmpty) _local['name'] = 'Enter the name.';
    if (_adding && !RegExp(r'^[6-9]\d{9}$').hasMatch(_mobile.text.trim())) {
      _local['mobile'] = 'Enter a 10-digit mobile number.';
    }
    if (_adding && _source == null) _local['source'] = 'Pick where the lead came from.';
    final pin = _pincode.text.trim();
    if (pin.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(pin)) _local['pincode'] = 'Pincode is 6 digits.';
    final email = _email.text.trim();
    if (email.isNotEmpty && !email.contains('@')) _local['email'] = 'Enter a valid email.';
    setState(() {});
    return _local.isEmpty;
  }

  Map<String, Object?> _values() {
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return {
      'name': _name.text.trim(),
      'model': _model,
      'email': t(_email),
      'pincode': t(_pincode),
      'city': t(_city),
      'state': t(_state),
      'address': t(_address),
      'shop_ownership': _shop,
      'shop_area_sqft': int.tryParse(_area.text.trim()),
      'investment_ready': _investment,
      'timeline': t(_timeline),
      'notes': t(_notes),
      'consent': _consent,
      'campaign': t(_campaign),
      'ad_set': t(_adSet),
      'utm_source': t(_utmSource),
      'utm_medium': t(_utmMedium),
      'utm_campaign': t(_utmCampaign),
      'enquiry_at': _enquiryAt == null ? null : isoWithOffset(_enquiryAt!),
    };
  }

  /// New lead: every filled field. Edit: only what changed, with a cleared
  /// field sent as null.
  Map<String, Object?> _body() {
    final now = _values();
    if (_adding) {
      return {'mobile': _mobile.text.trim(), 'source': _source, ...now}..removeWhere((_, v) => v == null);
    }
    final l = _l!;
    final before = <String, Object?>{
      'name': l.name,
      'model': l.model,
      'email': l.email,
      'pincode': l.pincode,
      'city': l.city,
      'state': l.state,
      'address': l.address,
      'shop_ownership': l.shopOwnership,
      'shop_area_sqft': l.shopAreaSqft,
      'investment_ready': l.investmentReady,
      'timeline': l.timeline,
      'notes': l.notes,
      'consent': l.consent ?? false,
      'campaign': l.campaign,
      'ad_set': l.adSet,
      'utm_source': l.utmSource,
      'utm_medium': l.utmMedium,
      'utm_campaign': l.utmCampaign,
      'enquiry_at': l.enquiryAt == null ? null : isoWithOffset(l.enquiryAt!),
    };
    return {
      for (final e in now.entries)
        if (e.value != before[e.key]) e.key: e.value,
    };
  }

  void _save() {
    if (!_check()) return;
    submit(
      (api) async {
        if (_adding) {
          final res = await api.post<Map<String, dynamic>>('/leads', body: _body());
          return (res.data['id'] as num).toInt();
        }
        final body = _body();
        if (body.isNotEmpty) await api.patch<dynamic>('/leads/${_l!.id}', body: body);
        return null;
      },
      done: _adding ? 'Lead added' : 'Lead updated',
      result: (saved) => _adding ? saved : true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final duplicate = error?.code == 'duplicate_lead';
    return FormPage(
      title: _adding ? 'Add a lead' : 'Edit lead',
      submitLabel: _adding ? 'Add lead' : 'Save changes',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (duplicate)
          AppCard(
            color: context.colors.tintOf(context.colors.danger),
            child: Text(error!.message, style: context.text.body.copyWith(color: context.colors.danger)),
          ),
        const SectionLabel('Contact'),
        AppField(
          controller: _name,
          label: 'Name',
          hint: 'Full name',
          textCapitalization: TextCapitalization.words,
          errorText: _err('name'),
        ),
        if (_adding)
          AppField(
            controller: _mobile,
            label: 'Mobile',
            hint: '98XXXXXXXX',
            keyboardType: TextInputType.phone,
            maxLength: 10,
            errorText: _err('mobile'),
          )
        else if (_l!.mobile != null)
          _Fixed(label: 'Mobile', value: _l!.mobile!),
        AppField(
          controller: _email,
          label: 'Email',
          hint: 'Optional',
          keyboardType: TextInputType.emailAddress,
          errorText: _err('email'),
        ),
        if (_adding)
          ChoiceGroup<String>(
            label: 'Source',
            options: [for (final s in sources) (s.value, s.label)],
            value: _source,
            required: true,
            errorText: _err('source'),
            onChanged: (v) => setState(() => _source = v),
          )
        else if (_l!.sourceLabel != null)
          _Fixed(label: 'Source', value: _l!.sourceLabel!),
        ChoiceGroup<String>(
          label: 'Model',
          options: modelOptions,
          value: _model,
          errorText: _err('model'),
          onChanged: (v) => setState(() => _model = v),
        ),
        const SectionLabel('Location'),
        AppField(
          controller: _pincode,
          label: 'Pincode',
          hint: '313001',
          keyboardType: TextInputType.number,
          maxLength: 6,
          errorText: _err('pincode') ?? _pincodeNote,
          onChanged: _onPincode,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                controller: _city,
                label: 'City',
                textCapitalization: TextCapitalization.words,
                errorText: _err('city'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppField(
                controller: _state,
                label: 'State',
                textCapitalization: TextCapitalization.words,
                errorText: _err('state'),
              ),
            ),
          ],
        ),
        AppField(
          controller: _address,
          label: 'Address',
          hint: 'Shop or home address',
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          errorText: _err('address'),
        ),
        const SectionLabel('Shop and investment'),
        ChoiceGroup<String>(
          label: 'Shop',
          options: shopOwnershipOptions,
          value: _shop,
          errorText: _err('shop_ownership'),
          onChanged: (v) => setState(() => _shop = v),
        ),
        AppField(
          controller: _area,
          label: 'Shop area, sq ft',
          hint: '400',
          keyboardType: TextInputType.number,
          errorText: _err('shop_area_sqft'),
        ),
        ChoiceGroup<String>(
          label: 'Ready to invest?',
          options: investmentOptions,
          value: _investment,
          errorText: _err('investment_ready'),
          onChanged: (v) => setState(() => _investment = v),
        ),
        AppField(
          controller: _timeline,
          label: 'When do they want to start?',
          hint: 'Within 2 months',
          textCapitalization: TextCapitalization.sentences,
          errorText: _err('timeline'),
        ),
        AppField(
          controller: _notes,
          label: 'Notes',
          hint: 'Optional',
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          errorText: _err('notes'),
        ),
        _ConsentRow(value: _consent, onChanged: (v) => setState(() => _consent = v)),
        if (!_showCampaign)
          TextLink(label: 'Add campaign details', onTap: () => setState(() => _showCampaign = true))
        else ...[
          const SectionLabel('Campaign'),
          AppField(controller: _campaign, label: 'Campaign', errorText: _err('campaign')),
          AppField(controller: _adSet, label: 'Ad set', errorText: _err('ad_set')),
          AppField(controller: _utmSource, label: 'UTM source', errorText: _err('utm_source')),
          AppField(controller: _utmMedium, label: 'UTM medium', errorText: _err('utm_medium')),
          AppField(controller: _utmCampaign, label: 'UTM campaign', errorText: _err('utm_campaign')),
          PickerField(
            label: 'Enquired on',
            value: _enquiryAt == null ? null : formatPicked(_enquiryAt!),
            hint: _adding ? 'Now' : 'Not set',
            icon: AppIcons.calendar,
            errorText: _err('enquiry_at'),
            onTap: () async {
              final now = DateTime.now();
              final d = await pickDateTime(
                context,
                initial: _enquiryAt ?? now,
                first: now.subtract(const Duration(days: 365)),
                last: now,
              );
              if (d != null) setState(() => _enquiryAt = d);
            },
          ),
        ],
      ],
    );
  }
}

/// A value shown read-only in the form, styled like a field.
class _Fixed extends StatelessWidget {
  const _Fixed({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.secondary.copyWith(fontWeight: FontWeight.w500, color: context.colors.textSecondary),
        ),
        const SizedBox(height: Space.xs),
        Container(
          height: Sizes.field,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: Space.xl, right: Space.lg),
          decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(Radii.field)),
          child: Row(
            children: [
              Expanded(
                child: Text(value, style: context.text.body.copyWith(color: context.colors.textSecondary)),
              ),
              AppIcon(AppIcons.lock, size: Sizes.iconSmall, color: context.colors.textTertiary),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            Expanded(child: Text('Agreed to be contacted', style: context.text.body)),
            Switch(value: value, onChanged: onChanged, activeTrackColor: context.colors.accent),
          ],
        ),
      ),
    );
  }
}
