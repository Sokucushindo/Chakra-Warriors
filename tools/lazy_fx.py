"""Android açılış çökmesine karşı: oyun açılırken tek blokta derlenen betik miktarını küçük tutar.
Godot ana betiği yüklerken ona doğrudan bağlı bütün betikleri birlikte ayrıştırır; 2026-11-27'de bu ~2 GB tepe yapıp
Android bellek ayırıcısını taşırıyor ve oyun her telefonda açılışta ölüyordu. Çözüm: aşağıdaki sabit nokta.
Yeni betik / sınıf eklendikçe yayından önce çalıştır:  python tools/lazy_fx.py yaz  (sonra gdcheck; := hatası çıkarsa '=' yap).
Sabit nokta: açılış bloğunda (autoload + sahne betiklerinden doğrudan başvurularla ulaşılan) kalan dosyaların
bir sınıfa yalnız Sınıf.üye (çağrı / sabit) biçiminde eriştiği sınıflar tembel yüklenir.
  python fix.py          -> rapor
  python fix.py yaz      -> lazy_fx.gd PATHS + blok dosyalarındaki başvuruları çevir"""
import re, os, sys, collections
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'godot') if len(sys.argv) < 3 else sys.argv[2]
S = os.path.join(ROOT, 'scripts')
NOCHANGE = {'res://scripts/core/lazy_fx.gd'}
files = {}
for dp, _, fs in os.walk(S):
    for f in fs:
        if f.endswith('.gd'):
            p = os.path.join(dp, f)
            files['res://' + os.path.relpath(p, ROOT).replace(os.sep, '/')] = open(p, encoding='utf-8', newline='').read()
cls = {}
for r, s in files.items():
    m = re.search(r'^class_name\s+(\w+)', s, re.M)
    if m:
        cls[m.group(1)] = r
autoload_paths = set(re.findall(r'="\*(res://[^"]+\.gd)"', open(os.path.join(ROOT, 'project.godot'), encoding='utf-8').read()))
roots = list(autoload_paths)
for dp, _, fs in os.walk(os.path.join(ROOT, 'scenes')):
    for f in fs:
        if f.endswith('.tscn'):
            roots += re.findall(r'path="(res://[^"]+\.gd)"', open(os.path.join(dp, f), encoding='utf-8').read())
pat = re.compile(r'\b(' + '|'.join(cls) + r')\b')
def nfunc(s):
    return len(re.findall(r'^\s*(?:static\s+)?func\s', s, re.M)) + s.count('func(')
def code_of(ln):
    c = re.sub(r'"[^"]*"', '""', ln)
    c = re.sub(r"'[^']*'", "''", c)
    return c.split('#')[0]
# dosya başına: (sınıf, iyi mi, satır)
uses = {}
for r, s in files.items():
    me = re.search(r'^class_name\s+(\w+)', s, re.M)
    me = me.group(1) if me else None
    u = []
    for ln in s.split('\n'):
        code = code_of(ln)
        st = code.strip()
        if not st or st.startswith('class_name'):
            continue
        for m in pat.finditer(code):
            c = m.group(1)
            if c == me:
                continue
            nxt = code[m.end():]
            pre = code[:m.start()]
            ok = True
            if not nxt.startswith('.'):
                ok = False
            elif re.match(r'\.[A-Z][a-z]\w*', nxt):
                ok = False   # iç sınıf / enum adı
            elif re.match(r'\.\w+\s*(\+|-|\*|/)?=[^=]', nxt):
                ok = False   # statik değişkene atama
            elif re.match(r'\s*const\b', code):
                ok = False
            elif re.match(r'^\s*[\w.]+\s*(,\s*[\w.]+\s*)*:\s*$', code):
                ok = False   # match deseni
            elif re.search(r'\bextends\s+$', pre):
                ok = False
            elif re.match(r'\.(\w+)\s*\(', nxt) is None and re.match(r'\.[a-z_]\w*', nxt):
                ok = False   # küçük harfli üye okuması (statik değişken / işlev başvurusu): güvenli tarafta kal
            u.append((c, ok, st))
    uses[r] = u
def closure(lazy):
    seen = set(); st = [r for r in roots if r in files]
    while st:
        x = st.pop()
        if x in seen:
            continue
        seen.add(x)
        s = files[x]
        for c, ok, _ in uses[x]:
            if not (ok and c in lazy and x not in NOCHANGE):
                st.append(cls[c])
        for p in re.findall(r'(?:preload)\("(res://[^"]+\.gd)"\)', s):
            if p in files:
                st.append(p)
        m = re.search(r'^extends\s+"(res://[^"]+)"', s, re.M)
        if m and m.group(1) in files:
            st.append(m.group(1))
    return seen
lazy = {c for c, r in cls.items() if r not in autoload_paths and r not in NOCHANGE and r not in roots}
while True:
    blk = closure(lazy)
    badc = set()
    for x in blk:
        for c, ok, _ in uses[x]:
            if c in lazy and (not ok or x in NOCHANGE):
                badc.add(c)
    if not badc:
        break
    lazy -= badc
blk = closure(lazy)
tot = sum(nfunc(s) for s in files.values())
print('toplam işlev', tot, ' blok', sum(nfunc(files[x]) for x in blk), 'dosya', len(blk), ' tembel sınıf', len(lazy))
for x in sorted(blk, key=lambda x: -nfunc(files[x]))[:30]:
    c = re.search(r'^class_name\s+(\w+)', files[x], re.M)
    c = c.group(1) if c else '-'
    why = [(os.path.basename(y), st[:90]) for y in blk for cc, ok, st in uses[y] if cc == c and (not ok or y in NOCHANGE)][:2]
    print(nfunc(files[x]), x.replace('res://scripts/', ''), c, why)
if 'yaz' in sys.argv:
    paths = {c: cls[c] for c in lazy}
    old = files['res://scripts/core/lazy_fx.gd']
    body = '\r\n'.join('\t"%s": "%s",' % (c, paths[c]) for c in sorted(paths))
    new = re.sub(r'const PATHS := \{.*?\r?\n\}', lambda m: 'const PATHS := {\r\n' + body + '\r\n}', old, flags=re.S)
    open(os.path.join(S, 'core', 'lazy_fx.gd'), 'w', encoding='utf-8', newline='').write(new)
    rp = re.compile(r'(?<![\w."])\b(' + '|'.join(map(re.escape, sorted(lazy, key=len, reverse=True))) + r')\.(?=[A-Za-z_])')
    n = 0
    for x in blk:
        if x in NOCHANGE:
            continue
        s = files[x]
        lines = s.split('\n')
        ch = 0
        for i, ln in enumerate(lines):
            code = ln.split('#')[0] if '"' not in ln else ln
            if ln.lstrip().startswith('#'):
                continue
            # dizge içini değiştirme: dizgeleri yer tutucuyla sakla
            parts = re.split(r'("[^"]*")', ln)
            for k in range(0, len(parts), 2):
                cm = parts[k].find('#')
                seg, tail = (parts[k], '') if cm < 0 else (parts[k][:cm], parts[k][cm:])
                seg2, c2 = rp.subn(lambda m: 'LazyFx.g("%s").' % m.group(1), seg)
                if c2:
                    parts[k] = seg2 + tail
                    ch += c2
                if cm >= 0:
                    parts[k + 1:] = [''.join(parts[k + 1:])] if False else parts[k + 1:]
                    break
            lines[i] = ''.join(parts)
        if ch:
            open(os.path.join(ROOT, x[6:]), 'w', encoding='utf-8', newline='').write('\n'.join(lines))
            n += ch
    print('çevrilen başvuru', n)
