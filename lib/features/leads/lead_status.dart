import '../../core/widgets/widgets.dart';

/// Badge colour for a lead status. The label always comes from the server;
/// unknown statuses fall back to neutral.
Tone toneForStatus(String status) => switch (status) {
  'QUALIFIED' => Tone.success,
  'FOLLOW_UP' || 'CALLBACK' => Tone.warning,
  'ASSIGNED' || 'VISIT_SCHEDULED' || 'VISITED' || 'INTERESTED' || 'NEW' || 'CONTACT_ATTEMPTED' => Tone.accent,
  'NOT_QUALIFIED' || 'DROPPED' || 'NOT_INTERESTED' || 'UNREACHABLE' || 'JUNK' || 'NON_SERVICEABLE' => Tone.neutral,
  _ => Tone.neutral,
};
