import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/session.dart';
import '../../core/sync/live_refresh.dart';
import '../../core/widgets/board.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/widgets.dart';
import 'onboarding_detail_screen.dart';

final onboardingBoardProvider = FutureProvider.autoDispose<List<BoardColumn>>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.onboarding));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/onboardings/board');
  return [for (final c in res.data) BoardColumn.fromJson(c as Map<String, dynamic>)];
});

Tone _waitingTone(String? key) => switch (key) {
  'partner' => Tone.accent,
  'done' => Tone.success,
  'ops' || 'finance' || 'compliance' => Tone.info,
  _ => Tone.neutral,
};

/// Onboardings by stage, with who has the next move as a chip.
class OnboardingBoardScreen extends ConsumerWidget {
  const OnboardingBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(onboardingBoardProvider);
    return BoardView(
      title: 'Onboarding board',
      columns: board.when(
        data: (d) => AsyncSnapshot.withData(ConnectionState.done, d),
        error: (e, _) => AsyncSnapshot.withError(ConnectionState.done, e),
        loading: () => const AsyncSnapshot.waiting(),
      ),
      onRefresh: () async {
        ref.invalidate(onboardingBoardProvider);
        await ref.read(onboardingBoardProvider.future);
      },
      cardBuilder: (context, c) {
        final waiting = c['waiting_on'] is Map ? c['waiting_on'] as Map : const {};
        return BoardCard(
          title: '${c['name'] ?? ''}',
          lines: [
            [c['onboarding_no'], c['store_name'] ?? c['city']].whereType<Object>().join(' · '),
            if (c['store_code'] != null) '${c['store_code']}',
          ],
          age: ageOf(c['in_status_since']),
          late: c['late'] == true,
          chips: [
            if (waiting['label'] != null) StatusBadge('${waiting['label']}', tone: _waitingTone('${waiting['key']}')),
            StatusBadge('${c['status_label'] ?? c['status']}', tone: Tone.neutral),
          ],
          onTap: () => pushForm<void>(context, OnboardingDetailScreen(id: (c['id'] as num).toInt())),
        );
      },
    );
  }
}
