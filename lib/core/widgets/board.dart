import 'package:material_ui/material_ui.dart';

import '../icons/app_icon.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'page.dart';
import 'hscroll.dart';
import 'skeleton.dart';
import 'widgets.dart';

/// One column of a server board: `{key, title, total, cards[]}`.
class BoardColumn {
  const BoardColumn({required this.key, required this.title, required this.total, required this.cards});

  final String key;
  final String title;
  final int total;
  final List<Map<String, dynamic>> cards;

  factory BoardColumn.fromJson(Map<String, dynamic> j) => BoardColumn(
    key: '${j['key']}',
    title: '${j['title'] ?? j['key']}',
    total: (j['total'] as num?)?.toInt() ?? 0,
    cards: [
      for (final c in (j['cards'] as List? ?? const []))
        if (c is Map<String, dynamic>) c,
    ],
  );
}

/// "3d" for how long a card has sat in its column.
String ageOf(Object? since) {
  final d = since == null ? null : DateTime.tryParse('$since');
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inDays >= 1) return '${diff.inDays}d';
  if (diff.inHours >= 1) return '${diff.inHours}h';
  return '${diff.inMinutes.clamp(0, 59)}m';
}

/// A board: column tabs across the top in the server's order, the chosen
/// column's cards below. Easier on a phone than side-by-side columns.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.title,
    required this.columns,
    required this.cardBuilder,
    required this.onRefresh,
    this.initialKey,
  });

  final String title;
  final AsyncSnapshot<List<BoardColumn>> columns;
  final Widget Function(BuildContext context, Map<String, dynamic> card) cardBuilder;
  final Future<void> Function() onRefresh;
  final String? initialKey;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  String? _key;
  final _chipKeys = <String, GlobalKey>{};
  bool _revealed = false;

  /// Brings the chosen column's tab into view once the board has loaded.
  void _reveal() {
    if (_revealed || _key == null) return;
    _revealed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[_key]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 250));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cols = widget.columns.data;
    final header = PageHeader(widget.title, onBack: () => Navigator.of(context).maybePop());
    if (cols == null) {
      return PageBody(
        children: [
          header,
          if (widget.columns.hasError)
            const MessageBlock(icon: AppIcons.alert, title: "Couldn't load the board", body: 'Pull down to try again.')
          else ...[
            const SkeletonScope(child: SkeletonChips(widths: [90, 110, 96, 120])),
            const SkeletonScope(child: SkeletonRows(count: 4, lead: BoneLead.none)),
          ],
        ],
      );
    }
    _key ??= widget.initialKey ?? cols.where((x) => x.total > 0).firstOrNull?.key ?? cols.firstOrNull?.key;
    final current = cols.where((x) => x.key == _key).firstOrNull ?? cols.firstOrNull;
    _reveal();
    return PageBody(
      onRefresh: widget.onRefresh,
      children: [
        header,
        HScroll(
          spacing: Space.xs,
          children: List.generate(cols.length, (i) {
            final col = cols[i];
            final on = col.key == current?.key;
            return GestureDetector(
              key: _chipKeys.putIfAbsent(col.key, GlobalKey.new),
              onTap: () => setState(() => _key = col.key),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? c.accentTint : context.fieldFill,
                  borderRadius: BorderRadius.circular(Radii.tile),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${i + 1} · ${col.title} '),
                      TextSpan(
                        text: '${col.total}',
                        style: TextStyle(fontWeight: FontWeight.w600, color: on ? c.accent : c.textPrimary),
                      ),
                    ],
                  ),
                  style: context.text.secondary.copyWith(color: on ? c.accent : c.textSecondary),
                ),
              ),
            );
          }),
        ),
        if (current == null || current.cards.isEmpty)
          AppCard(child: Text('Nothing in this column.', style: context.text.secondary))
        else ...[
          for (final card in current.cards) widget.cardBuilder(context, card),
          if (current.total > current.cards.length)
            Text('Showing ${current.cards.length} of ${current.total}', style: context.text.label),
        ],
      ],
    );
  }
}

/// A board card: title, subtitle lines, chips, and the age (red when late).
class BoardCard extends StatelessWidget {
  const BoardCard({
    super.key,
    required this.title,
    this.lines = const [],
    this.chips = const [],
    this.age,
    this.late = false,
    this.onTap,
  });

  final String title;
  final List<String> lines;
  final List<Widget> chips;
  final String? age;
  final bool late;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: context.text.bodyStrong)),
                if (age != null && age!.isNotEmpty)
                  Text(
                    age!,
                    style: context.text.label.copyWith(
                      color: late ? c.danger : c.textTertiary,
                      fontWeight: late ? FontWeight.w600 : null,
                    ),
                  ),
              ],
            ),
            for (final l in lines)
              if (l.isNotEmpty) Text(l, style: context.text.label),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Wrap(spacing: Space.xs, runSpacing: Space.xs, children: chips),
            ],
          ],
        ),
      ),
    );
  }
}
