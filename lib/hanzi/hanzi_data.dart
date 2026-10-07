import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

/// Черты иероглифа в системе координат Make Me a Hanzi (1024×1024,
/// ось Y уже перевёрнута для экрана).
class HanziStrokes {
  final List<Path> outlines;
  final List<List<Offset>> medians;
  const HanziStrokes(this.outlines, this.medians);
  int get count => outlines.length;
}

/// Из чего состоит иероглиф.
class HanziParts {
  final List<String> parts;
  final String radical;
  final String? semantic;
  final String? phonetic;
  const HanziParts(this.parts, this.radical, this.semantic, this.phonetic);
}

/// Порядок черт и разбор на компоненты. Загружается по требованию.
class HanziData {
  HanziData._();

  static Map<String, dynamic>? _strokes;
  static Map<String, dynamic>? _parts;
  static Map<String, dynamic>? _ru;
  static final _cache = <String, HanziStrokes>{};

  static Future<void> ensureLoaded() async {
    if (_strokes != null) return;
    try {
      _strokes = jsonDecode(
          await rootBundle.loadString('assets/hanzi/strokes.json'));
      final p = jsonDecode(
          await rootBundle.loadString('assets/hanzi/parts.json'));
      _parts = p['chars'] as Map<String, dynamic>;
      _ru = p['ru'] as Map<String, dynamic>;
    } catch (_) {
      _strokes = {};
      _parts = {};
      _ru = {};
    }
  }

  /// Для тестов: подставить данные без загрузки ассетов.
  static void debugSet(Map<String, dynamic> strokes, Map<String, dynamic> parts,
      Map<String, dynamic> ru) {
    _strokes = strokes;
    _parts = parts;
    _ru = ru;
    _cache.clear();
  }

  static HanziStrokes? strokes(String c) {
    final raw = _strokes?[c] as Map<String, dynamic>?;
    if (raw == null) return null;
    return _cache.putIfAbsent(c, () {
      final outlines = [for (final s in raw['s'] as List) parseSvgPath(s as String)];
      final medians = [
        for (final m in raw['m'] as List)
          [
            for (final pt in m as List)
              Offset((pt[0] as num).toDouble(), 900 - (pt[1] as num).toDouble())
          ]
      ];
      return HanziStrokes(outlines, medians);
    });
  }

  static HanziParts? parts(String c) {
    final raw = _parts?[c] as Map<String, dynamic>?;
    if (raw == null) return null;
    return HanziParts(
      [for (final p in raw['p'] as List) p as String],
      (raw['r'] as String?) ?? '',
      raw['sem'] as String?,
      raw['pho'] as String?,
    );
  }

  /// Русское значение компонента, если известно.
  static String? meaning(String c) => _ru?[c] as String?;
}

/// Разбирает контур из Make Me a Hanzi (команды M, L, Q, C, Z) и
/// переворачивает ось Y: y' = 900 - y.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MLQCZ]|-?\d+(?:\.\d+)?').allMatches(d).map((m) => m[0]!).toList();
  var i = 0;
  double n() => double.parse(tokens[i++]);
  double y() => 900 - n();
  while (i < tokens.length) {
    switch (tokens[i++]) {
      case 'M':
        final x = n();
        path.moveTo(x, y());
      case 'L':
        final x = n();
        path.lineTo(x, y());
      case 'Q':
        final x1 = n(), y1 = y(), x = n(), yy = y();
        path.quadraticBezierTo(x1, y1, x, yy);
      case 'C':
        final x1 = n(), y1 = y(), x2 = n(), y2 = y(), x = n(), yy = y();
        path.cubicTo(x1, y1, x2, y2, x, yy);
      case 'Z':
        path.close();
    }
  }
  return path;
}
