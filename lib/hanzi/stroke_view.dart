import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'hanzi_data.dart';

/// Клетка «米» — привычная сетка китайских прописей.
void paintGrid(Canvas canvas, Size size, Color color) {
  final p = Paint()
    ..color = color
    ..strokeWidth = 1;
  final r = Offset.zero & size;
  canvas.drawRect(r, p..style = PaintingStyle.stroke);
  final dash = Paint()
    ..color = color.withValues(alpha: color.a * 0.6)
    ..strokeWidth = 1;
  void dashed(Offset a, Offset b) {
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (double t = 0; t < len; t += 10) {
      canvas.drawLine(a + dir * t, a + dir * min(t + 5, len), dash);
    }
  }

  dashed(Offset(size.width / 2, 0), Offset(size.width / 2, size.height));
  dashed(Offset(0, size.height / 2), Offset(size.width, size.height / 2));
  dashed(Offset.zero, Offset(size.width, size.height));
  dashed(Offset(size.width, 0), Offset(0, size.height));
}

/// Анимация порядка черт: черты появляются одна за другой.
class StrokeOrderView extends StatefulWidget {
  const StrokeOrderView(this.char, {super.key, this.size = 220});
  final String char;
  final double size;

  @override
  State<StrokeOrderView> createState() => _StrokeOrderViewState();
}

class _StrokeOrderViewState extends State<StrokeOrderView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  HanziStrokes? _strokes;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    _load();
  }

  @override
  void didUpdateWidget(StrokeOrderView old) {
    super.didUpdateWidget(old);
    if (old.char != widget.char) _load();
  }

  Future<void> _load() async {
    await HanziData.ensureLoaded();
    if (!mounted) return;
    setState(() => _strokes = HanziData.strokes(widget.char));
    if (_strokes != null) {
      _c.duration = Duration(milliseconds: 550 * _strokes!.count + 400);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _strokes;
    if (s == null) {
      return SizedBox.square(
          dimension: widget.size,
          child: Center(child: Text(widget.char, style: hanziStyle(widget.size * 0.7))));
    }
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _c.forward(from: 0),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _StrokePainter(
            s,
            // Последние 400 мс — пауза с готовым иероглифом.
            progress: (_c.value * (s.count + 400 / 550)).clamp(0, s.count.toDouble()),
            ink: scheme.onSurface,
            ghost: scheme.onSurface.withValues(alpha: 0.08),
            active: Palette.cinnabar,
            grid: Palette.cinnabar.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.s,
      {required this.progress,
      required this.ink,
      required this.ghost,
      required this.active,
      required this.grid});
  final HanziStrokes s;
  final double progress;
  final Color ink, ghost, active, grid;

  @override
  void paint(Canvas canvas, Size size) {
    paintGrid(canvas, size, grid);
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < s.count; i++) {
      canvas.drawPath(s.outlines[i], fill..color = ghost);
    }
    final done = progress.floor();
    for (var i = 0; i < done && i < s.count; i++) {
      canvas.drawPath(s.outlines[i], fill..color = ink);
    }
    if (done < s.count) {
      // Текущая черта «рисуется» вдоль средней линии внутри контура.
      final t = progress - done;
      canvas.save();
      canvas.clipPath(s.outlines[done]);
      final pts = s.medians[done];
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      final total = _length(pts);
      var left = total * t;
      for (var i = 1; i < pts.length && left > 0; i++) {
        final seg = pts[i] - pts[i - 1];
        final len = seg.distance;
        final take = min(len, left);
        final end = pts[i - 1] + seg * (len == 0 ? 0 : take / len);
        line.lineTo(end.dx, end.dy);
        left -= take;
      }
      canvas.drawPath(
          line,
          Paint()
            ..color = active
            ..style = PaintingStyle.stroke
            ..strokeWidth = 140
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokePainter old) => old.progress != progress || old.s != s;
}

double _length(List<Offset> pts) {
  var l = 0.0;
  for (var i = 1; i < pts.length; i++) {
    l += (pts[i] - pts[i - 1]).distance;
  }
  return l;
}
