"""Hazır efekt denetimi (KURAL: hiçbir jutsu hazır efekte dayanmaz — CLAUDE.md 10).
Jutsunun işleyicisinde (p_/m_/c_/j_ + çağırdığı yerel c_/j_ ve fx/*.gd sınıflarındaki fonksiyonlar) yasak görsel çağrıları listeler.
  python tools/fx_lint.py deiton taiton meiton        # doğa(lar)
  python tools/fx_lint.py --ids deiton_kodei_kasen,kirin
  python tools/fx_lint.py --all                        # özet sayılar
Çıkış kodu: ihlal varsa 1.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
G = os.path.join(ROOT, 'godot')
BANNED = re.compile(r'\b(WaterArt\.\w+|FireArt\.\w+|IceArt\.\w+|WindFX\.\w+|FX\.\w+|VFX\.\w+|impact_fx|stream_fx|eshot|melee_fx|_water_jet|_gen|mesh_of|tether|smoke_puff|_sense_pulse|_cling_glow|_trail_ghost|JutsuEngine\.(?!info|power|base_dmg|_target_in_range)\w+)\b')


def load_funcs():
    funcs = {}
    files = [os.path.join(G, 'scripts', 'combat', f + '.gd') for f in ['path_jutsu', 'clan_jutsu', 'jutsu', 'ms_arts']]
    fxdir = os.path.join(G, 'scripts', 'combat', 'fx')
    if os.path.isdir(fxdir):
        files += [os.path.join(fxdir, f) for f in os.listdir(fxdir) if f.endswith('.gd')]
    for p in files:
        s = open(p, encoding='utf-8').read()
        cls = os.path.splitext(os.path.basename(p))[0]
        cm = re.search(r'^class_name (\w+)', s, re.M)
        if cm:
            cls = cm.group(1)
        for m in re.finditer(r'^(?:static )?func (\w+)\(.*?\n(?=^(?:static )?func |^const |^var |^class |\Z)', s, re.S | re.M):
            funcs.setdefault(m.group(1), m.group(0))
            funcs[cls + '.' + m.group(1)] = m.group(0)
    return funcs


def body_of(funcs, jid):
    body = ''
    for pre in ['p_', 'm_', 'c_', 'j_']:
        if pre + jid in funcs:
            body = funcs[pre + jid]
            break
    seen = set()
    todo = [body]
    out = ''
    while todo:
        b = todo.pop()
        out += b
        for w in re.findall(r'\b((?:[A-Z]\w+\.)?[a-z_]\w*)\(', b):
            if w in seen or w.split('.')[-1] in ('after', 'every', 'hit', 'inf', 'tg', 'gp', 'fwd', 'live'):
                continue
            # yalnız fx/ sınıflarının fonksiyonları ve yerel c_/j_ sarmalayıcıları izlenir
            if ('.' in w and w in funcs) or re.match(r'[cj]_', w):
                seen.add(w)
                todo.append(funcs.get(w, ''))
    return out


def main():
    d = json.load(open(os.path.join(G, 'data', 'jutsu.json'), encoding='utf-8'))
    funcs = load_funcs()
    args = sys.argv[1:]
    if '--ids' in args:
        ids = args[args.index('--ids') + 1].split(',')
    elif '--all' in args or not args:
        ids = [k for k, v in d.items() if isinstance(v, dict)]
    else:
        ids = [k for k, v in d.items() if isinstance(v, dict) and v.get('element', '') in args]
    bad = 0
    for jid in ids:
        hits = {}
        for ln in body_of(funcs, jid).splitlines():
            for m in BANNED.findall(ln):
                hits[m] = hits.get(m, 0) + 1
        if hits:
            bad += 1
            if '--all' not in args:
                print('IHLAL %-34s %s' % (jid, ', '.join('%s x%d' % kv for kv in sorted(hits.items()))))
        elif '--all' not in args:
            print('temiz %s' % jid)
    print('SONUC: %d / %d teknikte hazır efekt' % (bad, len(ids)))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
