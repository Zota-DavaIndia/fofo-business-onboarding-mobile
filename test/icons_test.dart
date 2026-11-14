import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../scripts/gen_icons.dart';

void main() {
  test('generated icons match the SVG sources', () {
    final expected = generate(Directory('assets/icons'));
    final actual = File('lib/core/icons/app_icons.g.dart').readAsStringSync();
    expect(actual, expected, reason: 'Run: dart run scripts/gen_icons.dart');
  });

  test('relative commands become absolute', () {
    expect(pathToCalls('M4 10.5 12 4l8 6.5V20h-5z'), [
      'p.moveTo(4, 10.5);',
      'p.lineTo(12, 4);',
      'p.lineTo(20, 10.5);',
      'p.lineTo(20, 20);',
      'p.lineTo(15, 20);',
      'p.close();',
    ]);
  });

  test('arcs keep their sweep direction', () {
    final calls = pathToCalls('M9 9.2a10 10 0 0 0 5.8 5.8');
    expect(calls.last, 'p.arcToPoint(Offset(14.8, 15), radius: const Radius.circular(10), clockwise: false);');
  });

  test('smooth curves reflect the previous control point', () {
    final calls = pathToCalls('M0 0C1 1 2 1 3 0S5 -1 6 0');
    expect(calls.last, 'p.cubicTo(4, -1, 5, -1, 6, 0);');
  });

  test('circles and rounded rects', () {
    expect(svgToCalls('<circle cx="12" cy="10" r="2.3"/>'), [
      'p.addOval(Rect.fromCircle(center: Offset(12, 10), radius: 2.3));',
    ]);
    expect(svgToCalls('<rect x="4" y="5.5" width="16" height="14.5" rx="2"/>'), [
      'p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(4, 5.5, 16, 14.5), const Radius.circular(2)));',
    ]);
  });
}
