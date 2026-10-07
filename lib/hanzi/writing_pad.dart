import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'hanzi_data.dart';
import 'stroke_view.dart';

/// Проверка одной черты: начало, конец и направление близки к эталону.
/// Координаты в системе 1024×1024.
bool strokeMatches(List<Offset> drawn, List<Offset> median) {
  if (drawn.length < 2 || median.isEmpty) return false;
  final ds = drawn.first, de = drawn.last;
  final ms = median.first, me = median.last;
  const tol = 260.0;
  if ((ds - ms).distance > tol || (de - me).distance > tol) return false;
  final dv = de - ds, mv = me - ms;
  // Точки и короткие черты: направление не проверяем.
  if (mv.distance < 120 || dv.distance < 60) return true;
  final cos = (dv.dx * mv.dx + dv.dy * mv.dy) / (dv.distance * mv.distance);
  return cos > 0.5;
}

/// Прописи: пользователь пишет иероглиф пальцем черта за чертой,
/// каждая черта сразу проверяется.
class WritingPad extends StatefulWidget {
  const WritingPad(this.char,
      {super.key, this.size = 300, this.showOutline = true, this.onDone});
  final String char;
  final double size;
  final bool showOutline;

  /// Иероглиф написан: передаёт число ошибок.
  final void Function(int mistakes)? onDone;

  @override
  State<WritingPad> createState() => _WritingPadState();
}

class _WritingPadState extends State<WritingPad> {
  HanziStrokes? _s;
  int _next = 0;
  int _mistakes = 0;
  int _missesOnStroke = 0;
  List<Offset> _current = [];
  // Неверная черта ненадолго остаётся на экране красной.
  List<Offset> _wrongStroke = [];

  @override
  void initState() {
    super.initState();
    HanziData.ensureLoaded().then((_) {
      if (mounted) setState(() => _s = HanziData.strokes(widget.char));
    });
  }

  void reset() => setState(() {
        _next = 0;
        _mistakes = 0;
        _missesOnStroke = 0;
        _current = [];
      });

  Offset _toModel(Offset p) => p * (1024 / widget.size);

  void _end() {
    final s = _s;
    if (s == null || _next >= s.count) return;
    final drawn = _current.map(_toModel).toList();
    final ok = strokeMatches(drawn, s.medians[_next]);
    setState(() {
      if (!ok) _wrongStroke = _current;
      _current = [];
      if (ok) {
        _next++;
        _missesOnStroke = 0;
      } else {
        _mistakes++;
        _missesOnStroke++;
      }
    });
    if (!ok) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _wrongStroke = []);
      });
    }
    if (ok && _next == s.count) widget.onDone?.call(_mistakes);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final scheme = Theme.of(context).colorScheme;
    if (s == null) {
      return SizedBox.square(dimension: widget.size);
    }
    return GestureDetector(
      onPanStart: (d) => setState(() => _current = [d.localPosition]),
      onPanUpdate: (d) => setState(() => _current = [..._current, d.localPosition]),
      onPanEnd: (_) => _end(),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _PadPainter(
            s,
            next: _next,
            current: _current,
            showOutline: widget.showOutline,
            // После трёх промахов подсвечиваем нужную черту.
            hint: _missesOnStroke >= 3,
            wrongStroke: _wrongStroke,
            ink: scheme.onSurface,
            ghost: scheme.onSurface.withValues(alpha: 0.07),
            grid: Palette.cinnabar.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.s,
      {required this.next,
      required this.current,
      required this.showOutline,
      required this.hint,
      required this.wrongStroke,
      required this.ink,
      required this.ghost,
      required this.grid});
  final HanziStrokes s;
  final int next;
  final List<Offset> current, wrongStroke;
  final bool showOutline, hint;
  final Color ink, ghost, grid;

  @override
  void paint(Canvas canvas, Size size) {
    paintGrid(canvas, size, grid);
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    final fill = Paint();
    for (var i = 0; i < s.count; i++) {
      if (i < next) {
        canvas.drawPath(s.outlines[i], fill..color = ink);
      } else if (i == next && hint) {
        canvas.drawPath(
            s.outlines[i], fill..color = Palette.jade.withValues(alpha: 0.45));
      } else if (showOutline) {
        canvas.drawPath(s.outlines[i], fill..color = ghost);
      }
    }
    canvas.restore();
    _line(canvas, size, current, ink.withValues(alpha: 0.8));
    _line(canvas, size, wrongStroke, Palette.cinnabar);
  }

  void _line(Canvas canvas, Size size, List<Offset> pts, Color color) {
    if (pts.length < 2) return;
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width / 28
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}
