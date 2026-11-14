import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/sync/alert_pulse.dart';

void main() {
  test('first answer sets the baseline, then only unseen alerts are reported', () async {
    final answers = <Map<String, dynamic>>[
      {'unread_count': 2, 'items': <dynamic>[], 'server_time': 't1'},
      {
        'unread_count': 3,
        'items': [
          {'id': 'a', 'type': 'lead.assigned', 'title': 'New lead'},
        ],
        'server_time': 't2',
      },
      {
        'unread_count': 3,
        'items': [
          {'id': 'a', 'type': 'lead.assigned', 'title': 'New lead'},
        ],
        'server_time': 't3',
      },
      {'unread_count': 2, 'items': <dynamic>[], 'server_time': 't4'},
    ];
    final afters = <String?>[];
    final reported = <String>[];
    final pulse = AlertPulse(
      fetch: (after) async {
        afters.add(after);
        return answers.removeAt(0);
      },
      onNew: (items, unread) => reported.add('${[for (final i in items) i['id']].join(',')}/$unread'),
    );

    await pulse.tick(); // baseline: nothing reported
    await pulse.tick(); // a new alert
    await pulse.tick(); // the same alert again (overlap): skipped, count unchanged
    await pulse.tick(); // read elsewhere: count moved, no items

    expect(afters, [null, 't1', 't2', 't3']);
    expect(reported, ['a/3', '/2']);
  });
}
