import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/theme.dart';
import 'hanzi_data.dart';
import 'stroke_view.dart';

/// Равномерно расставляет [n] точек вдоль ломаной.
List<Offset> resample(List<Offset> pts, int n) {
  if (pts.length < 2) return List.filled(n, pts.isEmpty ? Offset.zero : pts.first);
  final seg = <double>[0];
  for (var i = 1; i < pts.length; i++) {
    seg.add(seg.last + (pts[i] - pts[i - 1]).distance);
  }
  final total = seg.last;
  if (total == 0) return List.filled(n, pts.first);
  final out = <Offset>[];
  var j = 1;
  for (var k = 0; k < n; k++) {
    final d = total * k / (n - 1);
    while (j < pts.length - 1 && seg[j] < d) {
      j++;
    }
    final a = pts[j - 1], b = pts[j];
    final len = seg[j] - seg[j - 1];
    final t = len == 0 ? 0.0 : ((d - seg[j - 1]) / len).clamp(0.0, 1.0);
    out.add(Offset.lerp(a, b, t)!);
  }
  return out;
}

double _pathLength(List<Offset> pts) {
  var l = 0.0;
  for (var i = 1; i < pts.length; i++) {
    l += (pts[i] - pts[i - 1]).distance;
  }
  return l;
}

/// Проверка одной черты в координатах 1024×1024: черта должна начинаться
/// и заканчиваться рядом с эталоном, идти в ту же сторону и в целом
/// повторять его форму. Допуски намеренно мягкие — пальцем пишут неровно.
bool strokeMatches(List<Offset> drawn, List<Offset> median) {
  if (drawn.length < 2 || median.isEmpty) return false;
  final mLen = _pathLength(median);
  final dLen = _pathLength(drawn);
  if (dLen < 25) return false; // случайное касание
  const tol = 330.0;
  if ((drawn.first - median.first).distance > tol ||
      (drawn.last - median.last).distance > tol) {
    return false;
  }
  // Точки и совсем короткие черты: достаточно попасть в место.
  if (mLen < 150) return true;
  final dv = drawn.last - drawn.first, mv = median.last - median.first;
  if (dv.distance > 40 && mv.distance > 40) {
    final cos = (dv.dx * mv.dx + dv.dy * mv.dy) / (dv.distance * mv.distance);
    if (cos < 0.3) return false;
  }
  // Начало должно быть ближе к началу эталона, чем к его концу.
  if ((drawn.first - median.first).distance >
      (drawn.first - median.last).distance + 40) {
    return false;
  }
  // Форма: средний разрыв между соответствующими точками.
  final a = resample(drawn, 16), b = resample(median, 16);
  var sum = 0.0;
  for (var i = 0; i < 16; i++) {
    sum += (a[i] - b[i]).distance;
  }
  return sum / 16 < 230 && dLen > mLen * 0.3;
}

/// Распознаватель, который сразу забирает касание себе: без задержки
/// на старте и без конкуренции с прокруткой и жестом «назад».
class _InstantPan extends OneSequenceGestureRecognizer {
  _InstantPan({required this.onStart, required this.onMove, required this.onEnd});
  final void Function(Offset local) onStart, onMove;
  final VoidCallback onEnd;
  int? _pointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return; // второй палец игнорируем
    _pointer = event.pointer;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onStart(event.localPosition);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      onMove(event.localPosition);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      onEnd();
      _pointer = null;
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) => _pointer = null;

  @override
  String get debugDescription => 'instant pan';
}

/// Прописи: пользователь пишет иероглиф пальцем черта за чертой,
/// каждая черта сразу проверяется.
class WritingPad extends StatefulWidget {
  const WritingPad(this.char,
      {super.key, this.size = 300, this.showOutline = true, this.onDone, this.onProgress});
  final String char;
  final double size;
  final bool showOutline;

  /// Иероглиф написан: передаёт число ошибок.
  final void Function(int mistakes)? onDone;

  /// Сколько черт уже написано и сколько всего.
  final void Function(int done, int total)? onProgress;

  @override
  State<WritingPad> createState() => WritingPadState();
}

class WritingPadState extends State<WritingPad>
    with SingleTickerProviderStateMixin {
  HanziStrokes? _s;
  int _next = 0;
  int _mistakes = 0;
  int _missesOnStroke = 0;
  bool _hintRequested = false;
  List<Offset> _current = [];
  // Неверная черта ненадолго остаётся на экране и гаснет.
  List<Offset> _wrongStroke = [];
  late final AnimationController _fade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    HanziData.ensureLoaded().then((_) {
      if (mounted) setState(() => _s = HanziData.strokes(widget.char));
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// Подсветить следующую черту.
  void showHint() => setState(() => _hintRequested = true);

  Offset _toModel(Offset p) => p * (1024 / widget.size);

  void _end() {
    final s = _s;
    if (s == null || _next >= s.count) return;
    final drawn = _current.map(_toModel).toList();
    final ok = strokeMatches(drawn, s.medians[_next]);
    setState(() {
      if (!ok && _pathLength(drawn) >= 25) {
        _wrongStroke = _current;
        _mistakes++;
        _missesOnStroke++;
        _fade.forward(from: 0);
      }
      _current = [];
      if (ok) {
        _next++;
        _missesOnStroke = 0;
        _hintRequested = false;
      }
    });
    if (ok) {
      HapticFeedback.selectionClick();
      widget.onProgress?.call(_next, s.count);
      if (_next == s.count) {
        HapticFeedback.mediumImpact();
        widget.onDone?.call(_mistakes);
      }
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final scheme = Theme.of(context).colorScheme;
    if (s == null) {
      return SizedBox.square(dimension: widget.size);
    }
    final finished = _next >= s.count;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _InstantPan: GestureRecognizerFactoryWithHandlers<_InstantPan>(
          () => _InstantPan(
            onStart: (p) {
              if (!finished) setState(() => _current = [p]);
            },
            onMove: (p) {
              if (finished || _current.isEmpty) return;
              // Отбрасываем микродвижения — линия получается ровнее.
              if ((p - _current.last).distance < 1.5) return;
              setState(() => _current = [..._current, p]);
            },
            onEnd: _end,
          ),
          (_) {},
        ),
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AnimatedBuilder(
            animation: _fade,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _PadPainter(
                s,
                next: _next,
                current: _current,
                showOutline: widget.showOutline,
                // Подсказка: по кнопке или после двух промахов подряд.
                hint: _hintRequested || _missesOnStroke >= 2,
                wrongStroke: _wrongStroke,
                wrongAlpha: 1 - _fade.value,
                ink: scheme.onSurface,
                ghost: scheme.onSurface.withValues(alpha: 0.09),
                grid: Palette.cinnabar.withValues(alpha: 0.22),
              ),
            ),
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
      required this.wrongAlpha,
      required this.ink,
      required this.ghost,
      required this.grid});
  final HanziStrokes s;
  final int next;
  final List<Offset> current, wrongStroke;
  final bool showOutline, hint;
  final double wrongAlpha;
  final Color ink, ghost, grid;

  @override
  void paint(Canvas canvas, Size size) {
    paintGrid(canvas, size, grid);
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    final fill = Paint()..isAntiAlias = true;
    for (var i = 0; i < s.count; i++) {
      if (i < next) {
        canvas.drawPath(s.outlines[i], fill..color = ink);
      } else if (i == next && hint) {
        canvas.drawPath(
            s.outlines[i], fill..color = Palette.jade.withValues(alpha: 0.4));
      } else if (showOutline) {
        canvas.drawPath(s.outlines[i], fill..color = ghost);
      }
    }
    if (hint && next < s.count) {
      // Точка — откуда начинать черту.
      final start = s.medians[next].first;
      canvas.drawCircle(start, 34, Paint()..color = Palette.jade);
      canvas.drawCircle(start, 14, Paint()..color = Colors.white);
    }
    canvas.restore();
    _line(canvas, size, current, ink.withValues(alpha: 0.85));
    if (wrongAlpha > 0) {
      _line(canvas, size, wrongStroke,
          Palette.cinnabar.withValues(alpha: 0.9 * wrongAlpha));
    }
  }

  // Плавная линия через середины отрезков.
  void _line(Canvas canvas, Size size, List<Offset> pts, Color color) {
    if (pts.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(6, size.width / 24)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (pts.length == 1) {
      canvas.drawPoints(PointMode.points, pts, paint);
      return;
    }
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      p.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    p.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}
