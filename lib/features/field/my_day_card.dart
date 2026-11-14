import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/hscroll.dart';
import '../../core/widgets/widgets.dart';
import 'day_tracker.dart';
import 'calendar_screen.dart';
import 'day_plan_screen.dart';
import 'expenses_screen.dart';
import 'field.dart';
import 'leave_screen.dart';
import 'plan.dart';
import 'tickets_screen.dart';
import '../../core/widgets/toast.dart';

/// "My day" on Home: start and end the working day, with what's been recorded.
class MyDayCard extends ConsumerStatefulWidget {
  const MyDayCard({super.key});

  @override
  ConsumerState<MyDayCard> createState() => _MyDayCardState();
}

class _MyDayCardState extends ConsumerState<MyDayCard> {
  bool _busy = false;
  bool _always = true;

  @override
  void initState() {
    super.initState();
    _checkAlways();
  }

  Future<void> _checkAlways() async {
    final p = await Geolocator.checkPermission();
    if (mounted) setState(() => _always = p == LocationPermission.always);
  }

  /// A real GPS fix, asking for location access first. Null with a message shown when there's none.
  Future<Position?> _fix() async {
    String? problem;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = 'Turn on location to start or end your day.';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        // Ask once more for "always", so the route keeps recording in the background.
        if (perm == LocationPermission.whileInUse) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          problem = 'Allow location for this app in Settings to start your day.';
        } else {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)),
          );
          await _checkAlways();
          return p;
        }
      }
    } catch (_) {
      problem = "Couldn't get your location. Move to open sky and try again.";
    }
    if (mounted) showToast(context, problem, kind: ToastKind.error);
    return null;
  }

  Future<void> _act(bool start) async {
    if (!start) {
      final ok = await showChoiceSheet<bool>(
        context,
        title: 'End your day?',
        options: const [(true, 'End day'), (false, 'Keep working')],
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final p = await _fix();
      if (p == null) return;
      if (!start) await ref.read(dayTrackerProvider).flush();
      final res = await ref
          .read(apiClientProvider)
          .post<Object?>(
            start ? '/attendance/start' : '/attendance/end',
            body: {
              'latitude': p.latitude,
              'longitude': p.longitude,
              'accuracy_m': p.accuracy,
              'is_mock_location': p.isMocked,
            },
          );
      ref.invalidate(todayProvider);
      if (!start) await ref.read(dayTrackerProvider).stop();
      if (mounted) {
        final t = parseToday(res.data);
        showSaved(context, start ? 'Day started' : 'Day ended · ${t.day?.distanceKm.toStringAsFixed(1) ?? 0} km');
      }
    } on ApiException catch (e) {
      if (mounted) showSaveError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dayTrackingProvider);
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final t = today.value;
    final day = t?.day;
    final state = t?.state ?? DayState.notStarted;
    final (badge, tone) = switch (state) {
      DayState.notStarted => ('Not started', Tone.neutral),
      DayState.started => ('Working', Tone.success),
      DayState.ended => ('Ended', Tone.info),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('My day', style: context.text.bodyStrong)),
              if (t != null) StatusBadge(badge, tone: tone),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (day != null)
            Row(
              children: [
                _Stat(label: 'Started', value: formatTime(day.startedAt)),
                _Stat(label: 'Travelled', value: '${day.distanceKm.toStringAsFixed(1)} km'),
                if (day.endedAt != null) _Stat(label: 'Ended', value: formatTime(day.endedAt!)),
              ],
            )
          else
            Text(
              today.hasError
                  ? "Couldn't load your day. Pull down to retry."
                  : 'Start your day when you begin field work.',
              style: context.text.secondary,
            ),
          if (state == DayState.started && !_always) ...[
            const SizedBox(height: Space.sm),
            GestureDetector(
              onTap: () => Geolocator.openAppSettings(),
              child: Text(
                'Allow location "all the time" so your route keeps recording when the app is closed. Open Settings',
                style: context.text.label.copyWith(color: c.warning),
              ),
            ),
          ],
          if (state != DayState.ended) ...[
            const SizedBox(height: Space.md),
            AppButton(
              label: state == DayState.started ? 'End day' : 'Start day',
              icon: state == DayState.started ? AppIcons.check : AppIcons.route,
              kind: state == DayState.started ? ButtonKind.secondary : ButtonKind.primary,
              loading: _busy,
              onPressed: t == null || _busy ? null : () => _act(state != DayState.started),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.label),
          Text(value, style: context.text.bodyStrong),
        ],
      ),
    );
  }
}

/// Expenses and Leave tiles under My day, each shown only with its permission.
class WorkTiles extends ConsumerWidget {
  const WorkTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    final expenses = user?.can(Perm.expensesClaim) ?? false;
    final leave = user?.can(Perm.leaveApply) ?? false;
    final plan = user?.can(Perm.dayplanManage) ?? false;
    final tickets = user?.can(Perm.ticketsRaise) ?? false;
    if (!expenses && !leave && !plan && !tickets) return const SizedBox.shrink();
    final month = monthKey(DateTime.now());
    final draft = expenses ? ref.watch(expensesProvider(month)).value?.totals[ExpenseStatus.draft] : null;
    final pending = leave ? ref.watch(leavesProvider).value?.pending : null;
    final stops = plan ? ref.watch(dayPlanProvider).value : null;
    final openTickets = tickets ? ref.watch(ticketsProvider(true)).value : null;
    final tiles = [
      if (plan)
        _Tile(
          icon: AppIcons.route,
          title: 'Day plan',
          caption: stops == null || stops.isEmpty
              ? 'Plan stores and leads'
              : '${stops.where((s) => s.status == StopStatus.done).length} of ${stops.length} visited',
          onTap: () => pushForm<void>(context, const DayPlanScreen()),
        ),
      if (plan)
        _Tile(
          icon: AppIcons.calendar,
          title: 'Calendar',
          caption: 'Visits, calls, activities',
          onTap: () => pushForm<void>(context, const CalendarScreen()),
        ),
      if (tickets)
        _Tile(
          icon: AppIcons.alert,
          title: 'Tickets',
          caption: openTickets == null
              ? 'Store issues'
              : (openTickets.isEmpty ? 'None open' : '${openTickets.length} open'),
          onTap: () => pushForm<void>(context, const TicketsScreen()),
        ),
      if (expenses)
        _Tile(
          icon: AppIcons.receipt,
          title: 'Expenses',
          caption: draft == null
              ? 'Claim travel and costs'
              : (draft > 0 ? '${formatRupees(draft)} to submit' : 'All submitted'),
          onTap: () => pushForm<void>(context, const ExpensesScreen()),
        ),
      if (leave)
        _Tile(
          icon: AppIcons.leave,
          title: 'Leave',
          caption: pending == null ? 'Apply and track' : (pending > 0 ? '$pending pending' : 'Apply and track'),
          onTap: () => pushForm<void>(context, const LeaveScreen()),
        ),
    ];
    // One sideways row that fades at the edge with more to scroll, like Today and the stage strip.
    return HScroll(children: tiles);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.caption, required this.onTap});

  final AppIconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 132),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(icon, size: Sizes.icon, color: context.colors.accent),
              const SizedBox(height: Space.sm),
              Text(title, style: context.text.bodyStrong, maxLines: 1, softWrap: false),
              Text(caption, style: context.text.label, maxLines: 1, softWrap: false),
            ],
          ),
        ),
      ),
    );
  }
}
