import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../core/widgets/toast.dart';

const _monthNames = [
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

Tone _tone(ExpenseStatus s) => switch (s) {
  ExpenseStatus.draft => Tone.neutral,
  ExpenseStatus.submitted => Tone.info,
  ExpenseStatus.approved => Tone.success,
  ExpenseStatus.rejected => Tone.danger,
};

void _changed(WidgetRef ref) {
  ref.invalidate(expensesProvider);
}

/// The month's claims with totals; drafts can be edited, deleted and submitted.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  bool _submitting = false;

  Future<void> _submitDrafts(List<Expense> drafts) async {
    final total = drafts.fold<double>(0, (s, e) => s + e.amount);
    final ok = await showChoiceSheet<bool>(
      context,
      title: 'Submit ${drafts.length} ${drafts.length == 1 ? 'claim' : 'claims'} for ${formatRupees(total)}?',
      options: const [(true, 'Submit for approval'), (false, 'Not yet')],
    );
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(apiClientProvider)
          .post<Object?>(
            '/expenses/submit',
            body: {
              'ids': [for (final e in drafts) e.id],
            },
          );
      _changed(ref);
      if (mounted) showSaved(context, 'Sent for approval');
    } on ApiException catch (e) {
      if (mounted) showSaveError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(expenseMonthProvider);
    final now = DateTime.now();
    final isThisMonth = month.year == now.year && month.month == now.month;
    final data = ref.watch(expensesProvider(monthKey(month)));
    final drafts = data.value?.items.where((e) => e.canEdit).toList() ?? const <Expense>[];
    return PageBody(
      onRefresh: () => ref.refresh(expensesProvider(monthKey(month)).future),
      header: PageHeader(
        'Expenses',
        onBack: () => Navigator.of(context).maybePop(),
        trailing: IconTile(
          AppIcons.plus,
          semanticLabel: 'Add an expense',
          color: context.colors.accent,
          background: context.colors.accentTint,
          alignment: Alignment.centerRight,
          onTap: () async {
            final saved = await pushForm<bool>(context, const ExpenseFormScreen());
            if (saved == true) _changed(ref);
          },
        ),
      ),
      bottom: drafts.isEmpty
          ? null
          : ActionBar(
              children: [
                AppButton(
                  label:
                      'Submit ${drafts.length} ${drafts.length == 1 ? 'claim' : 'claims'} · '
                      '${formatRupees(drafts.fold<double>(0, (s, e) => s + e.amount))}',
                  loading: _submitting,
                  onPressed: _submitting ? null : () => _submitDrafts(drafts),
                ),
              ],
            ),
      children: [
        Row(
          children: [
            IconTile(
              AppIcons.left,
              semanticLabel: 'Previous month',
              onTap: () => ref.read(expenseMonthProvider.notifier).shift(-1),
            ),
            Expanded(
              child: Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: context.text.bodyStrong,
              ),
            ),
            IconTile(
              AppIcons.right,
              semanticLabel: 'Next month',
              color: isThisMonth ? context.colors.textTertiary : null,
              onTap: isThisMonth ? null : () => ref.read(expenseMonthProvider.notifier).shift(1),
            ),
          ],
        ),
        ...data.when(
          loading: () => [
            const SkeletonScope(
              label: 'Loading expenses',
              child: Column(
                children: [
                  SkeletonChips(widths: [100, 100, 100]),
                  SizedBox(height: Space.md),
                  SkeletonRows(count: 4),
                ],
              ),
            ),
          ],
          error: (_, _) => [
            MessageBlock(
              icon: AppIcons.alert,
              title: "Couldn't load expenses",
              body: 'Check your connection and pull down to try again.',
              action: AppButton(
                label: 'Try again',
                kind: ButtonKind.secondary,
                onPressed: () => ref.invalidate(expensesProvider),
              ),
            ),
          ],
          data: (m) => [
            Row(
              children: [
                _Total(label: 'To submit', value: m.totals[ExpenseStatus.draft] ?? 0),
                const SizedBox(width: Space.sm),
                _Total(label: 'Submitted', value: m.totals[ExpenseStatus.submitted] ?? 0),
                const SizedBox(width: Space.sm),
                _Total(label: 'Approved', value: m.totals[ExpenseStatus.approved] ?? 0, good: true),
              ],
            ),
            if (m.items.isEmpty)
              const MessageBlock(
                icon: AppIcons.receipt,
                title: 'No claims this month',
                body: 'Add travel, food, lodging and other work costs here, then submit them for approval.',
              )
            else
              GroupedList(
                children: [
                  for (final e in m.items)
                    ListRow(
                      title: '${e.categoryLabel} · ${formatRupees(e.amount)}',
                      subtitle: [
                        formatShortDay(e.date),
                        if (e.travelModeLabel != null)
                          [e.travelModeLabel!, if (e.distanceKm != null) '${formatDays(e.distanceKm!)} km'].join(' '),
                        e.stationLabel,
                        if (e.status == ExpenseStatus.rejected && e.reviewNote != null) e.reviewNote!,
                      ].join(' · '),
                      leading: IconTile(
                        AppIcons.receipt,
                        color: context.colors.accent,
                        background: context.colors.accentTint,
                        size: 36,
                        iconSize: 18,
                      ),
                      trailing: StatusBadge(
                        e.status == ExpenseStatus.approved && (e.approvedAmount ?? e.amount) < e.amount
                            ? '${formatRupees(e.approvedAmount!)} OK'
                            : e.status.label,
                        tone: _tone(e.status),
                      ),
                      onTap: () => _open(e),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _open(Expense e) async {
    if (e.canEdit) {
      final saved = await pushForm<bool>(context, ExpenseFormScreen(expense: e));
      if (saved == true) _changed(ref);
      return;
    }
    if (e.receiptUrl != null) {
      final pick = await showChoiceSheet<String>(
        context,
        title: '${e.categoryLabel} · ${formatRupees(e.amount)}',
        options: const [('receipt', 'View receipt')],
      );
      if (pick == 'receipt') await launchUrl(Uri.parse(e.receiptUrl!), mode: LaunchMode.externalApplication);
    }
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, this.good = false});

  final String label;
  final double value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.label, maxLines: 1),
            Text(
              formatRupees(value),
              maxLines: 1,
              style: context.text.bodyStrong.copyWith(color: good && value > 0 ? context.colors.success : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit a draft claim.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expense});

  final Expense? expense;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> with FormSubmit {
  late DateTime _date = widget.expense?.date ?? DateTime.now();
  late String? _station = widget.expense?.station ?? 'hq';
  late String? _category = widget.expense?.category ?? 'travel';
  late String? _mode = widget.expense?.travelMode;
  late final _km = TextEditingController(
    text: widget.expense?.distanceKm == null ? '' : formatDays(widget.expense!.distanceKm!),
  );
  late final _amount = TextEditingController(text: widget.expense == null ? '' : formatDays(widget.expense!.amount));
  late final _note = TextEditingController(text: widget.expense?.description ?? '');
  XFile? _receipt;
  final _clientId = newClientId();
  final _err = <String, String>{};

  @override
  void dispose() {
    _km.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _e(String k) => _err[k] ?? fieldError(k);

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (f != null && mounted) setState(() => _receipt = f);
    } catch (_) {
      if (mounted) {
        showToast(context, "Couldn't open the camera or photos.", kind: ToastKind.error);
      }
    }
  }

  void _save(FieldOptions opts) {
    final amount = double.tryParse(_amount.text.trim());
    setState(() {
      _err.clear();
      if (amount == null || amount <= 0) _err['amount'] = 'Enter the amount.';
      if (_category == 'travel' && _mode == null) _err['travel_mode'] = 'Choose how you travelled.';
      final hasReceipt = _receipt != null || widget.expense?.receiptUrl != null;
      if (amount != null && amount > opts.receiptOver && !hasReceipt) {
        _err['receipt'] = 'Add a receipt photo for claims above ${formatRupees(opts.receiptOver)}.';
      }
    });
    if (_err.isNotEmpty) return;
    final note = _note.text.trim();
    final fields = <String, Object?>{
      if (widget.expense == null) 'client_uuid': _clientId,
      'date': isoDay(_date),
      'station': _station,
      'category': _category,
      if (_category == 'travel') 'travel_mode': _mode,
      if (_category == 'travel' && _km.text.trim().isNotEmpty) 'distance_km': _km.text.trim(),
      'amount': amount,
      'description': note.isEmpty ? null : note,
    };
    submit((api) async {
      String? receiptId;
      if (_receipt case final r?) {
        final up = await api.upload<Map<String, dynamic>>(
          '/uploads',
          filePath: r.path,
          fields: {'purpose': 'expense_receipt'},
        );
        receiptId = '${up.data['id']}';
      }
      final body = {...fields, 'receipt_upload_id': ?receiptId};
      return widget.expense == null
          ? api.post<Object?>('/expenses', body: body)
          : api.patch<Object?>('/expenses/${widget.expense!.id}', body: body);
    }, done: widget.expense == null ? 'Expense saved' : 'Expense updated');
  }

  Future<void> _delete() async {
    final ok = await showChoiceSheet<bool>(
      context,
      title: 'Delete this claim?',
      options: const [(true, 'Delete'), (false, 'Keep')],
    );
    if (ok != true || !mounted) return;
    submit((api) => api.delete<Object?>('/expenses/${widget.expense!.id}'), done: 'Expense deleted');
  }

  @override
  Widget build(BuildContext context) {
    final opts = (ref.watch(appConfigProvider).value ?? const AppConfig()).field;
    final now = DateTime.now();
    return FormPage(
      title: widget.expense == null ? 'Add expense' : 'Edit expense',
      submitLabel: 'Save',
      submitting: submitting,
      onSubmit: () => _save(opts),
      children: [
        PickerField(
          label: 'Date',
          value: formatShortDay(_date),
          hint: 'Choose a date',
          icon: AppIcons.calendar,
          onTap: () async {
            final d = await pickDate(context, initial: _date, first: now.subtract(const Duration(days: 60)), last: now);
            if (d != null) setState(() => _date = d);
          },
          errorText: fieldError('date'),
        ),
        ChoiceGroup<String>(
          label: 'Station',
          options: opts.stations,
          value: _station,
          onChanged: (v) => setState(() => _station = v ?? _station),
          errorText: fieldError('station'),
        ),
        ChoiceGroup<String>(
          label: 'Type',
          options: opts.categories,
          value: _category,
          onChanged: (v) => setState(() => _category = v ?? _category),
          errorText: fieldError('category'),
        ),
        if (_category == 'travel') ...[
          ChoiceGroup<String>(
            label: 'Travelled by',
            options: opts.travelModes,
            value: _mode,
            onChanged: (v) => setState(() => _mode = v),
            errorText: _e('travel_mode'),
          ),
          AppField(
            controller: _km,
            label: 'Distance, km',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: fieldError('distance_km'),
          ),
        ],
        AppField(
          controller: _amount,
          label: 'Amount, ₹',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          errorText: _e('amount'),
        ),
        AppField(
          controller: _note,
          label: 'Note',
          hint: 'Where and why',
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          errorText: fieldError('description'),
        ),
        SectionLabel('Receipt${opts.receiptOver > 0 ? ' · needed above ${formatRupees(opts.receiptOver)}' : ''}'),
        if (_receipt case final r?)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: Image.file(File(r.path), height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: Space.sm,
                right: Space.sm,
                child: IconTile(
                  AppIcons.close,
                  semanticLabel: 'Remove receipt',
                  background: context.colors.card,
                  color: context.colors.textPrimary,
                  onTap: () => setState(() => _receipt = null),
                ),
              ),
            ],
          )
        else ...[
          if (widget.expense?.receiptUrl != null)
            Text('A receipt is attached. Add a new photo to replace it.', style: context.text.label),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Take photo',
                  icon: AppIcons.camera,
                  kind: ButtonKind.secondary,
                  onPressed: () => _pickReceipt(ImageSource.camera),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: AppButton(
                  label: 'Choose',
                  icon: AppIcons.upload,
                  kind: ButtonKind.secondary,
                  onPressed: () => _pickReceipt(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
        if (_e('receipt') ?? fieldError('receipt_upload_id') case final err?)
          Text(err, style: context.text.label.copyWith(color: context.colors.danger)),
        if (widget.expense != null) ...[
          const SizedBox(height: Space.md),
          AppButton(label: 'Delete this claim', icon: AppIcons.close, kind: ButtonKind.danger, onPressed: _delete),
        ],
      ],
    );
  }
}
