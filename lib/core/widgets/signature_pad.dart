import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Holds the strokes of a [SignaturePad] and turns them into a PNG.
class SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  bool get isEmpty => _strokes.every((s) => s.length < 2);

  void _start(Offset p) {
    _strokes.add([p]);
    notifyListeners();
  }

  void _add(Offset p) {
    _strokes.last.add(p);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// Black ink on white, 2x the pad size, written to [path].
  Future<File> savePng(String path) async {
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    canvas.drawRect(Offset.zero & _size, Paint()..color = const Color(0xFFFFFFFF));
    _paint(canvas, const Color(0xFF1E1915));
    final image = await recorder.endRecording().toImage((_size.width * scale).round(), (_size.height * scale).round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return File(path).writeAsBytes(bytes!.buffer.asUint8List());
  }

  void _paint(Canvas canvas, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in _strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length - 1; i++) {
        final mid = Offset((s[i].dx + s[i + 1].dx) / 2, (s[i].dy + s[i + 1].dy) / 2);
        path.quadraticBezierTo(s[i].dx, s[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(s.last.dx, s.last.dy);
      canvas.drawPath(path, paint);
    }
  }
}

/// A box to sign in with a finger.
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller, this.height = 180, this.errorText});

  final SignatureController controller;
  final double height;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(Radii.field),
            border: Border.all(color: errorText != null ? c.danger : c.separator, width: errorText != null ? 1.5 : 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.field),
            child: LayoutBuilder(
              builder: (context, box) {
                controller._size = Size(box.maxWidth, box.maxHeight);
                return GestureDetector(
                  onPanStart: (d) => controller._start(d.localPosition),
                  onPanUpdate: (d) => controller._add(d.localPosition),
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (_, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _InkPainter(controller),
                      child: controller.isEmpty
                          ? Center(
                              child: Text(
                                'Sign here',
                                style: context.text.secondary.copyWith(color: const Color(0xFF9A8F84)),
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Row(
          children: [
            if (errorText != null)
              Expanded(
                child: Text(errorText!, style: context.text.label.copyWith(color: c.danger)),
              )
            else
              const Spacer(),
            TextLink(label: 'Clear', onTap: controller.clear),
          ],
        ),
      ],
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.controller) : super(repaint: controller);

  final SignatureController controller;

  @override
  void paint(Canvas canvas, Size size) => controller._paint(canvas, const Color(0xFF1E1915));

  @override
  bool shouldRepaint(_InkPainter old) => true;
}
