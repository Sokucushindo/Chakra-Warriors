"""Oyuncu rehberi üretici (İngilizce, Trello kartları için): oyunun kendi verisinden.
python tools/guide_gen.py  ->  Trello/clans_en.md, Trello/paths_en.md, Trello/jutsu_sources_en.md
Klanlar: data/clans.json + klan teknikleri (jutsu.json learn/clan). Yollar: scripts/core/legend_paths.gd PATHS.
Türkçe metinler data/i18n/en.json ile çevrilir (yoksa Türkçe kalır ve sonda listelenir)."""
import json, os, re, collections

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
G = os.path.join(ROOT, 'godot')
OUT = os.path.join(ROOT, 'Trello')
os.makedirs(OUT, exist_ok=True)
EN = json.load(open(os.path.join(G, 'data/i18n/en.json'), encoding='utf-8'))
J = {k: v for k, v in json.load(open(os.path.join(G, 'data/jutsu.json'), encoding='utf-8')).items() if not k.startswith('_')}
C = json.load(open(os.path.join(G, 'data/clans.json'), encoding='utf-8'))
missing = set()
VNAME = {'konoha': 'Konoha', 'suna': 'Suna', 'kiri': 'Kiri', 'kumo': 'Kumo', 'iwa': 'Iwa', 'ame': 'Ame', 'kusa': 'Kusa', 'taki': 'Taki',
         'oto': 'Oto', 'yu': 'Yu', 'shimo': 'Shimo', 'tani': 'Tani', 'nami': 'Nami', 'uzushio': 'Uzushio', 'tetsu': 'Land of Iron'}
NATURE = {'katon': 'Fire (Katon)', 'suiton': 'Water (Suiton)', 'fuuton': 'Wind (Fūton)', 'doton': 'Earth (Doton)', 'raiton': 'Lightning (Raiton)',
          'mokuton': 'Wood (Mokuton)', 'hyoton': 'Ice (Hyōton)', 'yoton': 'Lava (Yōton)', 'futton': 'Boil (Futton)', 'ranton': 'Storm (Ranton)',
          'shakuton': 'Scorch (Shakuton)', 'bakuton': 'Explosion (Bakuton)', 'jiton': 'Magnet (Jiton)', 'jinton': 'Dust (Jinton)',
          'koton': 'Steel (Kōton)', 'taiton': 'Typhoon (Taiton)', 'meiton': 'Dark (Meiton)', 'jinton_swift': 'Swift', 'deiton': 'Mud (Deiton)',
          'shoton': 'Crystal (Shōton)', 'senjutsu_beden': 'Sage Body'}
BONUS = {'melee': 'melee damage', 'jutsu': 'jutsu power', 'chakra': 'max chakra', 'hp': 'max health', 'def': 'defense', 'speed': 'speed',
         'genjutsu': 'genjutsu power', 'regen': 'regeneration', 'crit': 'critical chance', 'stamina': 'stamina', 'tools': 'tool damage'}


def tr(s):
    s = str(s or '')
    if not s:
        return ''
    if s in EN and EN[s]:
        return EN[s]
    if re.search(r'[çğıöşüÇĞİÖŞÜ]', s):
        missing.add(s)
    return s


def jname(jid):
    j = J.get(jid, {})
    n = j.get('name', jid)
    ne = j.get('name_en', '')
    return f"{n}" + (f" ({ne})" if ne and ne != n else '')


def bonus_txt(b):
    out = []
    for k, v in (b or {}).items():
        if isinstance(v, (int, float)):
            if abs(v) < 1.0:
                out.append(f"+{int(round(v * 100))}% {BONUS.get(k, k)}")
            else:
                out.append(f"+{int(v)} {BONUS.get(k, k)}")
    return ', '.join(out)


# ------------------------------------------------------------------ klanlar
lines = ['# Clans — Every Clan, Its Bloodline and How You Get It', '',
         'You pick your clan when you create your character (from the villages listed for that clan). Clan techniques are learned **automatically** '
         'when you reach the Power level shown — no teacher needed. "Family arts" are taught by your family at that Power level (no rank needed).', '']
by_clan = collections.defaultdict(list)
for jid, j in J.items():
    lr = str(j.get('learn', ''))
    cl = lr[5:] if lr.startswith('clan:') else (j.get('clan') if lr == 'clan' else '')
    if cl:
        by_clan[cl].append((int(j.get('level', 1)), jid))
# oyundaki klan sekmesiyle aynı kural (ClanWorld.clan_jutsu_ids): klan etiketi + klanın kan soyu / gözü / silahı / yolu + imza teknikleri
_cw = open(os.path.join(G, 'scripts/core/clan_world.gd'), encoding='utf-8').read()
def _gd_dict(name):
    m = re.search(r'const ' + name + r' := (\{.*?\})\s*\n(?:##|static|const|var)', _cw, re.S)
    return eval(m.group(1)) if m else {}
CLAN_LEARN = _gd_dict('CLAN_LEARN')
CLAN_SIGNATURE = _gd_dict('CLAN_SIGNATURE')
SAND_LINES = _gd_dict('SAND_LINES')
SAND_LINE_NAMES = {'suna': "Sand (Gaara) — Shukaku's sand, no Magnet Release", 'sakin': 'Gold Dust (Rasa) — Magnet Release', 'satetsu': 'Iron Sand (Third Kazekage) — Magnet Release'}
EXTRA_HOW = {'kg': "needs your clan's kekkei genkai nature (awakens at the Power level above)", 'eye': "needs your clan's eye",
             'weapon': "learned when you obtain the clan's special weapon", 'path': "taught on the clan's Legendary Path"}
for cid, c in C.items():
    if cid == 'none':
        continue
    name = tr(c.get('name', cid))
    lines.append(f'---\n\n## CARD: Clan — {name}')
    lines.append('')
    lines.append(tr(c.get('desc', '')))
    lines.append('')
    if c.get('kg') and c.get('kg') != 'Yok':
        kgt = re.sub(r';\s*strong\s*$', '', tr(c['kg']).strip()).strip()
        lines.append(f"- **Bloodline:** {kgt}")
    if c.get('dojutsu'):
        lines.append(f"- **Eye (dōjutsu):** {str(c['dojutsu']).capitalize()}")
    kn = c.get('kg_natures', [])
    if kn:
        lines.append(f"- **Kekkei genkai nature:** {', '.join(NATURE.get(n, n) for n in kn)} (awakens at Power {int(c.get('kg_level', 1))})")
    bt = bonus_txt(c.get('bonus'))
    if bt:
        lines.append(f"- **Clan bonus:** {bt}")
    vs = c.get('villages', [])
    if vs:
        lines.append(f"- **Available in:** {', '.join(VNAME.get(v, v) for v in vs)}")
    fam = c.get('family_arts', [])
    if cid == 'sabaku' and SAND_LINES:
        lines.append('- **Sand lineage (choose ONE at character creation, under the clan):** each lineage learns only its own techniques by Power level; enemies of this clan also use a single lineage.')
        for ln in ('suna', 'sakin', 'satetsu'):
            ex = sorted((int(J[j].get('level', 1)), j) for j in SAND_LINES.get(ln, []) if j in J)
            lines.append(f"- **{SAND_LINE_NAMES[ln]} ({len(ex)} techniques):**")
            for lv, jid in ex:
                rk = str(J[jid].get('canon_rank', ''))
                lines.append(f"  - Power {lv}: {jname(jid)}" + (' — **S-rank**' if rk == 'S' else ''))
        lines.append('')
        continue
    tech = sorted(by_clan.get(cid, []))
    if tech:
        lines.append('- **Clan techniques (Power level → technique):**')
        for lv, jid in tech:
            lines.append(f"  - Power {lv}: {jname(jid)}" + (' — family art' if jid in fam else ''))
    for tag in CLAN_LEARN.get(cid, []):
        ex = sorted((int(j.get('level', 1)), jid) for jid, j in J.items() if str(j.get('learn', '')) == tag)
        if ex:
            lines.append(f"- **Bloodline techniques ({EXTRA_HOW.get(tag.split(':')[0], tag)}):**")
            for lv, jid in ex:
                lines.append(f"  - Power {lv}: {jname(jid)}")
    sig = sorted((int(J[j].get('level', 1)), j) for j in CLAN_SIGNATURE.get(cid, []) if j in J)
    if sig:
        lines.append('- **Signature techniques of this clan (learned from their usual source):**')
        for lv, jid in sig:
            lines.append(f"  - Power {lv}: {jname(jid)}")
    lines.append('')
none = C.get('none', {})
lines.append('---\n\n## CARD: Clan — No Clan')
lines.append('')
lines.append(tr(none.get('desc', '')))
open(os.path.join(OUT, 'clans_en.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

# ------------------------------------------------------------------ efsane yolları
src = open(os.path.join(G, 'scripts/core/legend_paths.gd'), encoding='utf-8').read()
drills_src = src[:src.index('const PATHS')]
paths_src = src[src.index('const PATHS'):]
ids = re.findall(r'^\t"([a-z_]+)": \{\s*$', paths_src, re.M)
DTYPE = {'hits': 'Land {n} hits in {time:.0f} s on the training dummies', 'throws': 'Hit {n} throws in {time:.0f} s',
         'survive': 'Survive {n} s', 'collect': 'Collect {n} items in {time:.0f} s', 'tend': 'Work {n} stations ({dwell:.0f} s each)'}
lines = ['# Legendary Paths — Every Path, Where It Is and What It Teaches', '',
         'Legendary Paths are mentors hidden around the world. First you hear a **rumor** (at a Power level), then you can **join** (at a higher Power level). '
         'Each technique is learned through a hands-on training at the mentor\'s place; some need a special quest. Paths give a passive bonus while you follow them.', '']
for pid in ids:
    m = re.search(r'^\t"%s": \{\s*$(.*?)^\t\},' % pid, paths_src, re.M | re.S)
    if not m:
        continue
    b = m.group(1)

    def f(key):
        mm = re.search(r'"%s":\s*"([^"]*)"' % key, b)
        return mm.group(1) if mm else ''

    def fi(key):
        mm = re.search(r'"%s":\s*(\d+)' % key, b)
        return int(mm.group(1)) if mm else None
    name = tr(f('name'))
    place = tr(f('place'))
    mentor = re.search(r'"mentor":\s*\{"name":\s*"([^"]*)",\s*"title":\s*"([^"]*)"', b)
    order = re.search(r'"order":\s*\[([^\]]*)\]', b)
    order = re.findall(r'"([a-z_0-9]+)"', order.group(1)) if order else []
    quest = dict(re.findall(r'"([a-z_0-9]+)":\s*"([a-z_]+)"', (re.search(r'"quest":\s*\{([^}]*)\}', b) or [None, ''])[1] if re.search(r'"quest":\s*\{([^}]*)\}', b) else ''))
    dark = re.findall(r'"([a-z_0-9]+)":\s*\d+', (re.search(r'"dark":\s*\{([^}]*)\}', b).group(1) if re.search(r'"dark":\s*\{([^}]*)\}', b) else ''))
    lines.append(f'---\n\n## CARD: Path — {name}')
    lines.append('')
    if f('style'):
        lines.append(f"*{tr(f('style'))}*")
        lines.append('')
    if f('rumor'):
        lines.append(f"> {tr(f('rumor'))}")
        lines.append('')
    rl, jl = fi('rumor_level'), fi('join_level')
    if rl is not None:
        lines.append(f"- **Rumor:** Power {rl}" + (f"  •  **Join:** Power {jl}" if jl is not None else ''))
    if place:
        lines.append(f"- **Where:** {place} (after the rumor: Tab > Paths > 'Go to the search area' marks the area near it on your map; find the exact spot yourself)")
    if mentor:
        lines.append(f"- **Mentor:** {mentor.group(1)} — {tr(mentor.group(2))}")
    if f('passive_desc'):
        lines.append(f"- **Passive while on the path:** {tr(f('passive_desc'))}")
    if order:
        lines.append('- **Techniques in order:**')
        for i, jid in enumerate(order, 1):
            how = ''
            dm = re.search(r'^\t"%s":\s*\{"type":\s*"([a-z]+)"(.*?)\},?\s*$' % re.escape(jid), drills_src, re.M)
            if jid in quest:
                how = f"special quest ({quest[jid]})"
            elif dm:
                t = dm.group(1)
                vals = {k: float(v) for k, v in re.findall(r'"(n|time|dwell)":\s*([\d.]+)', dm.group(2))}
                vals.setdefault('n', 0); vals.setdefault('time', 0); vals.setdefault('dwell', 0)
                vals['n'] = int(vals['n'])
                how = DTYPE.get(t, 'training').format(**vals)
            else:
                how = 'training at the path site'
            lines.append(f"  {i}. {jname(jid)} — {how}" + (' — *dark technique*' if jid in dark else ''))
    lines.append('')
open(os.path.join(OUT, 'paths_en.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

# ------------------------------------------------------------------ teknik kaynakları
HOW = {
    'academy': 'Learned at the Academy.',
    'scroll': 'Buy the scroll from the village Scroll Seller (only if it matches your nature).',
    'clan': 'Clan technique: clan members learn it automatically at the Power level.',
    'kinjutsu': 'Forbidden technique: buy a lead from the Underground Broker, then recover the scroll from where it is hidden. Never sold for money.',
    'element': 'First element technique: after graduation, the teacher\'s chakra paper test at the Training Ground (you must have that nature).',
    'trainer': 'Taught by a village trainer (some also as a scroll at the Scroll Seller); hospital trainer for medical ninjutsu; Chūnin+ for jōnin-level and sealing trainers.',
    'quest': 'Unlocked through a special quest.',
    'path': 'Taught by a Legendary Path mentor.',
    'kg': 'Needs the matching kekkei genkai nature.',
    'eye': 'Needs the matching eye (dōjutsu).',
    'sage': 'Needs Sage Mode (nature energy training in a summoning contract realm).',
    'weapon': 'Learned when you obtain that special weapon.',
    'beast': 'Taught by your Tailed Beast once you are its jinchūriki (at the Power level).',
    'contract': 'Taught by the sage after signing that summoning contract (at the Power level).',
    'shrine': 'At the Uzumaki mask shrine in the Uzushio ruins (Uzumaki clan or a Kage).',
    'locked': 'Not obtainable yet.',
}
cnt = collections.Counter()
groups = collections.defaultdict(list)
for jid, j in J.items():
    lr = str(j.get('learn', ''))
    t = lr.split(':')[0] if lr else 'other'
    cnt[t] += 1
    groups[lr].append(jid)
lines = ['# How Techniques Are Learned', '', f'There are {len(J)} techniques in the game. Every technique has one learning source:', '',
         '| Source | Count | How |', '|---|---|---|']
for t, n in cnt.most_common():
    lines.append(f"| {t} | {n} | {HOW.get(t, '')} |")
lines.append('')
for key in sorted(groups):
    if not key.split(':')[0] in ('eye', 'kg', 'weapon', 'beast', 'contract', 'sage', 'quest', 'kinjutsu', 'shrine'):
        continue
    lines.append(f'### {key}')
    lines.append(', '.join(jname(x) for x in sorted(groups[key], key=lambda x: (int(J[x].get("level", 1)), x))))
    lines.append('')
open(os.path.join(OUT, 'jutsu_sources_en.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('yazildi: clans_en.md, paths_en.md, jutsu_sources_en.md | cevirisi eksik:', len(missing))
open(os.path.join(ROOT, '_tmp', 'guide_missing.txt'), 'w', encoding='utf-8').write('\n'.join(sorted(missing)))
