"""Собирает данные о иероглифах для приложения из Make Me a Hanzi.

python3 tool/build_hanzi.py <путь к makemeahanzi>
Пишет assets/hanzi/strokes.json и assets/hanzi/parts.json для всех
иероглифов из assets/words.json. Компоненты без русского значения
перечисляются в tool/components_todo.txt.
"""
import json
import os
import re
import sys

src = sys.argv[1]
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
words = json.load(open(os.path.join(root, 'assets/words.json')))
chars = sorted({c for w in words for c in w['h'] if '一' <= c <= '鿿'})

# Русские значения: однослоговые слова словаря + глоссарий компонентов.
ru = {}
for w in words:
    if len(w['h']) == 1:
        ru.setdefault(w['h'], w['ru'].split(';')[0].split(',')[0].strip())
gloss_path = os.path.join(root, 'tool/components_ru.json')
if os.path.exists(gloss_path):
    for k, v in json.load(open(gloss_path)).items():
        ru.setdefault(k, v)

dictionary = {}
for line in open(os.path.join(src, 'dictionary.txt')):
    d = json.loads(line)
    dictionary[d['character']] = d

IDS = re.compile('[⿰-⿿？]')


def parts(c):
    d = dictionary.get(c)
    if not d:
        return []
    return [p for p in IDS.sub('', d.get('decomposition', '')) if p != c]


strokes, info, todo = {}, {}, set()
want = set(chars)
for line in open(os.path.join(src, 'graphics.txt')):
    g = json.loads(line)
    if g['character'] in want:
        strokes[g['character']] = {'s': g['strokes'], 'm': g['medians']}

for c in chars:
    d = dictionary.get(c)
    if not d:
        continue
    ps = parts(c)
    ety = d.get('etymology') or {}
    entry = {'p': ps, 'r': d.get('radical', '')}
    if ety.get('type') == 'pictophonetic':
        entry['sem'] = ety.get('semantic', '')
        entry['pho'] = ety.get('phonetic', '')
    elif ety.get('type'):
        entry['t'] = ety['type']
    info[c] = entry
    for p in ps + [entry['r']]:
        if p and p not in ru:
            todo.add(p)

meanings = {p: ru[p] for c in info for p in info[c]['p'] + [info[c]['r']] if p in ru}
os.makedirs(os.path.join(root, 'assets/hanzi'), exist_ok=True)
json.dump(strokes, open(os.path.join(root, 'assets/hanzi/strokes.json'), 'w'),
          ensure_ascii=False, separators=(',', ':'))
json.dump({'chars': info, 'ru': meanings},
          open(os.path.join(root, 'assets/hanzi/parts.json'), 'w'),
          ensure_ascii=False, separators=(',', ':'))
with open(os.path.join(root, 'tool/components_todo.txt'), 'w') as f:
    for p in sorted(todo):
        d = dictionary.get(p, {})
        f.write(f"{p}\t{d.get('definition', '')}\n")
print(len(chars), 'chars;', len(strokes), 'with strokes;', len(todo), 'components need ru')
