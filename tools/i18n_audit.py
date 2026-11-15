"""Çeviri denetimi: tests/lang_audit.gd'nin döktüğü ekran yazılarından Türkçe kalanları ayıklar.
Kullanım: py tools/i18n_audit.py _tmp/i18n/audit_*.jsonl
Türkçe sayılır: Türkçe harf içeren ya da yalnız Türkçe kaynakta geçen (hiçbir çeviride geçmeyen) bir sözcük içeren yazı."""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
en = json.load(open(os.path.join(ROOT, 'godot', 'data', 'i18n', 'en.json'), encoding='utf-8'))
tok = re.compile(r"[A-Za-zçğıöşüÇĞİÖŞÜâîûōūĀŌŪ']{3,}")
en_words = set()
for v in en.values():
    en_words.update(w.lower() for w in tok.findall(v))
tr_words = {}
for k in en:
    for w in tok.findall(k):
        lw = w.lower()
        if lw not in en_words:
            tr_words[lw] = tr_words.get(lw, 0) + 1
tr_chars = re.compile('[çğıöşüÇĞİÖŞÜ]')
bad = {}
total = 0
files = []
for a in sys.argv[1:]:
    files += glob.glob(a)
for f in files:
    for line in open(f, encoding='utf-8'):
        line = line.strip()
        if not line:
            continue
        try:
            kind, text = json.loads(line)
        except Exception:
            continue
        total += 1
        text = re.sub(r'\[/?[a-z_]+(=[^\]]*)?\]', '', text)
        hits = [w for w in tok.findall(text) if w.lower() in tr_words]
        if tr_chars.search(text) or hits:
            bad.setdefault(text, set()).add(os.path.basename(f))
print('toplam yazı %d, Türkçe kalan %d' % (total, len(bad)))
for t in sorted(bad):
    print('  [%s] %s' % (','.join(sorted(x.replace('audit_', '').replace('.jsonl', '') for x in bad[t])), t.replace('\n', ' ⏎ ')[:300]))
