import 'dart:ui';

/// One icon from the custom set. Holds the function that draws it on a
/// 24 x 24 grid; the path is built once and reused.
class AppIconData {
  const AppIconData(this._build);

  final void Function(Path) _build;

  static final _cache = <void Function(Path), Path>{};

  Path get path => _cache.putIfAbsent(_build, () {
    final p = Path();
    _build(p);
    return p;
  });
}
