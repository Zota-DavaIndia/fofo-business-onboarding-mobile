import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// A row that scrolls sideways. It runs edge to edge (cancelling the page's side padding, then putting it
/// back inside) and fades its content out on whichever side still has more to scroll, so the cut-off card
/// reads as "more this way". An end that's reached stays sharp, so the first card sits crisp on the padding.
class HScroll extends StatefulWidget {
  const HScroll({super.key, required this.children, this.spacing = Space.sm, this.inset = Space.screen});

  final List<Widget> children;
  final double spacing;

  /// The page's side padding, cancelled so the row can bleed to the edges.
  final double inset;

  /// How far the fade reaches from the screen edge: the side padding and well into the row.
  static const fadeWidth = 56.0;

  @override
  State<HScroll> createState() => _HScrollState();
}

class _HScrollState extends State<HScroll> {
  final _controller = ScrollController();
  bool _left = false;
  bool _right = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!_controller.hasClients || !mounted) return;
    final p = _controller.position;
    final left = p.pixels > 1;
    final right = p.pixels < p.maxScrollExtent - 1;
    if (left != _left || right != _right) {
      setState(() {
        _left = left;
        _right = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final fade = HScroll.fadeWidth / (box.maxWidth + widget.inset * 2);
        return _Bleed(
          inset: widget.inset,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              colors: [
                _left ? const Color(0x00000000) : const Color(0xFF000000),
                const Color(0xFF000000),
                const Color(0xFF000000),
                _right ? const Color(0x00000000) : const Color(0xFF000000),
              ],
              stops: [0, fade, 1 - fade, 1],
            ).createShader(rect),
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                _update();
                return false;
              },
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: widget.inset),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < widget.children.length; i++) ...[
                      if (i > 0) SizedBox(width: widget.spacing),
                      widget.children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lays its child out [inset] wider on each side than the space it's given,
/// keeps the child's height, and shifts it left by [inset], so the child
/// reaches the screen edges past the page padding.
class _Bleed extends SingleChildRenderObjectWidget {
  const _Bleed({required this.inset, super.child});

  final double inset;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBleed(inset);

  @override
  void updateRenderObject(BuildContext context, _RenderBleed renderObject) => renderObject.inset = inset;
}

class _RenderBleed extends RenderShiftedBox {
  _RenderBleed(this._inset) : super(null);

  double _inset;
  set inset(double v) {
    if (v == _inset) return;
    _inset = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final width = constraints.maxWidth + _inset * 2;
    child.layout(constraints.copyWith(minWidth: width, maxWidth: width), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(-_inset, 0);
    size = constraints.constrain(Size(constraints.maxWidth, child.size.height));
  }
}
