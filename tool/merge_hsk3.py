"""Собирает assets/words.json по уровням HSK 3.0 (1–6).

python3 tool/merge_hsk3.py <complete.json> <hsk3-dir>
complete.json — github.com/drkameleon/complete-hsk-vocabulary,
hsk3-dir — rows.json и out_N.jsonl с русскими переводами новых слов.
"""
import glob, json, sys

complete, d = sys.argv[1], sys.argv[2]
info = {}
for e in json.load(open(complete, encoding='utf8')):
    lv = [int(x[7:]) for x in e['level'] if x.startswith('newest-') and int(x[7:]) <= 6]
    info[e['simplified']] = (min(lv) if lv else None, e.get('frequency', 10**6))

words = json.load(open('assets/words.json', encoding='utf8'))
have = {w['h'] for w in words}
for w in words:
    lv, _ = info.get(w['h'], (None, 0))
    if lv:
        w['l'] = lv

rows = {r[1]: r for r in json.load(open(f'{d}/rows.json', encoding='utf8'))}
added = 0
for f in sorted(glob.glob(f'{d}/out_*.jsonl')):
    for line in open(f, encoding='utf8'):
        if not line.strip():
            continue
        o = json.loads(line)
        r = rows.get(o['h'])
        if r is None or o['h'] in have:
            continue
        have.add(o['h'])
        words.append({'h': o['h'], 't': r[2], 'p': o['p'], 'ru': o['ru'],
                      'en': r[4], 'l': r[0], 'ex': o['ex'], 'exp': o['exp'],
                      'exru': o['exru']})
        added += 1

order = {w['h']: i for i, w in enumerate(words)}
words.sort(key=lambda w: (w['l'], info.get(w['h'], (0, 10**6))[1], order[w['h']]))
json.dump(words, open('assets/words.json', 'w', encoding='utf8'),
          ensure_ascii=False, separators=(',', ':'))
from collections import Counter
print('added', added, 'total', len(words), sorted(Counter(w['l'] for w in words).items()))
