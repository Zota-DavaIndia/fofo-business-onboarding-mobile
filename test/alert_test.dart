import 'package:fofo_onboarding/features/alerts/alerts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> row(Object? canOpen, [String? note]) => {
    'id': 'a1',
    'type': 'lead.reassigned',
    'title': 'Lead moved to Bhanu',
    'entity': 'lead',
    'entity_id': 62,
    'can_open': canOpen,
    'note': note,
  };

  test('an alert about a lead moved away carries the note instead of opening', () {
    final a = Alert.fromJson(row(false, 'This lead is now with Bhanu.'));
    expect(a.canOpen, isFalse);
    expect(a.note, 'This lead is now with Bhanu.');
  });

  test('only an explicit can_open true opens the record', () {
    expect(Alert.fromJson(row(true)).canOpen, isTrue);
    expect(Alert.fromJson(row(null)).canOpen, isFalse);
  });
}
