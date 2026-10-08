import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'theme.dart';
import 'word_card.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  int? _level;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final plainQ = _stripTones(q);
    final list = widget.state.words.where((w) {
      if (_level != null && w.level != _level) return false;
      if (q.isEmpty) return true;
      return w.hanzi.contains(q) ||
          _stripTones(w.pinyin.toLowerCase()).replaceAll(' ', '').contains(
              plainQ.replaceAll(' ', '')) ||
          w.ru.toLowerCase().contains(q) ||
          w.en.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SearchBar(
            hintText: 'Иероглиф, пиньинь или перевод',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _chip('Все', null),
              for (var l = 1; l <= 6; l++) _chip('HSK $l', l),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final w = list[i];
              final c = widget.state.cards[w.id];
              return ListTile(
                leading: SizedBox(
                  width: 64,
                  child: Text(w.hanzi,
                      style: hanziStyle(w.hanzi.length > 2 ? 22 : 28),
                      textAlign: TextAlign.center),
                ),
                title: Text(w.pinyin),
                subtitle: Text(w.meaning,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: c == null
                    ? null
                    : Icon(
                        c.isMature
                            ? Icons.check_circle_rounded
                            : Icons.timelapse_rounded,
                        color: c.isMature ? Palette.jade : Palette.level(3),
                        size: 20),
                onTap: () => openWord(context, w),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, int? level) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _level == level,
          onSelected: (_) => setState(() => _level = level),
        ),
      );
}

const _toneMap = {
  'āáǎà': 'a',
  'ēéěè': 'e',
  'īíǐì': 'i',
  'ōóǒò': 'o',
  'ūúǔù': 'u',
  'ǖǘǚǜü': 'v',
};

String _stripTones(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    var out = ch;
    for (final e in _toneMap.entries) {
      if (e.key.contains(ch)) out = e.value;
    }
    b.write(out);
  }
  return b.toString();
}
