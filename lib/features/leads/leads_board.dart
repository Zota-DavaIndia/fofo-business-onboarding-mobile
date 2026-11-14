import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/sync/live_refresh.dart';
import '../../core/widgets/board.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/widgets.dart';
import 'lead.dart' show date;
import 'lead_detail_screen.dart';
import 'lead_status.dart';

final leadsBoardProvider = FutureProvider.autoDispose<List<BoardColumn>>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.leads));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/leads/board', query: {'per_column': 20});
  return [for (final c in res.data) BoardColumn.fromJson(c as Map<String, dynamic>)];
});

/// Leads by stage, in the server's column order. A late card (open lead
/// untouched for 2+ days) shows its age in red.
class LeadsBoardScreen extends ConsumerWidget {
  const LeadsBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leadsBoardProvider);
    return BoardView(
      title: 'Leads board',
      columns: board.when(
        data: (d) => AsyncSnapshot.withData(ConnectionState.done, d),
        error: (e, _) => AsyncSnapshot.withError(ConnectionState.done, e),
        loading: () => const AsyncSnapshot.waiting(),
      ),
      onRefresh: () async {
        ref.invalidate(leadsBoardProvider);
        await ref.read(leadsBoardProvider.future);
      },
      cardBuilder: (context, c) {
        final nextVisit = date(c['next_visit_at']);
        final nextCall = date(c['next_call_at']);
        return BoardCard(
          title: '${c['name'] ?? ''}',
          lines: [
            [c['lead_no'], c['model'], c['city']].whereType<Object>().join(' · '),
            '${c['source_label'] ?? ''}',
          ],
          age: ageOf(c['in_status_since']),
          late: c['late'] == true,
          chips: [
            StatusBadge('${c['status_label'] ?? c['status']}', tone: toneForStatus('${c['status']}')),
            if (nextVisit != null) StatusBadge('Visit ${formatDay(nextVisit)}', tone: Tone.info),
            if (nextCall != null) StatusBadge('Call ${formatDay(nextCall)}', tone: Tone.warning),
          ],
          onTap: () => pushForm<void>(context, LeadDetailScreen(id: (c['id'] as num).toInt())),
        );
      },
    );
  }
}
