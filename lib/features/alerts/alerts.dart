import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/sync/live_refresh.dart';
import '../leads/lead.dart' show date, str;

/// One message in the staff inbox, from `/notifications`.
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.entity,
    this.entityId,
    required this.canOpen,
    this.note,
    this.at,
    this.read = false,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final String? entity;
  final int? entityId;

  /// False when the record is no longer this user's (e.g. the lead moved to another RCM); [note] says why.
  final bool canOpen;
  final String? note;
  final DateTime? at;
  final bool read;

  /// Where tapping it should go, or null when it has nowhere to open.
  String? get route => switch (entity) {
    'lead' when entityId != null => '/leads/$entityId',
    'visit' => '/visits',
    'onboarding' when entityId != null => '/onboarding/$entityId',
    _ => null,
  };

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
    id: '${j['id']}',
    type: '${j['type'] ?? ''}',
    title: '${j['title'] ?? ''}',
    body: str(j['body']),
    entity: str(j['entity']),
    entityId: (j['entity_id'] as num?)?.toInt() ?? int.tryParse('${j['entity_id']}'),
    canOpen: j['can_open'] == true,
    note: str(j['note']),
    at: date(j['created_at']),
    read: j['read_at'] != null,
  );
}

typedef Inbox = ({List<Alert> items, int unread});

final alertsProvider = FutureProvider.autoDispose<Inbox>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.alerts));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/notifications');
  return (
    items: [for (final n in res.data) Alert.fromJson(n as Map<String, dynamic>)],
    unread: (res.meta?['unread_count'] as num?)?.toInt() ?? 0,
  );
});

/// Just the unread count, for the bell on Home.
final unreadAlertsProvider = Provider.autoDispose<int>((ref) => ref.watch(alertsProvider).value?.unread ?? 0);

Future<void> markAlertRead(WidgetRef ref, String id) async {
  await ref.read(apiClientProvider).post<dynamic>('/notifications/$id/read');
  refreshTopics(ref, const [LiveTopic.alerts]);
}

Future<void> markAllAlertsRead(WidgetRef ref) async {
  await ref.read(apiClientProvider).post<dynamic>('/notifications/read-all');
  refreshTopics(ref, const [LiveTopic.alerts]);
}
