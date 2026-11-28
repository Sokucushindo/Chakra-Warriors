"""Trello rehber kartlarını panoya yazar (aynı adlı kart varsa açıklamasını günceller, yoksa oluşturur).
Anahtar: _tmp/trello.env (TRELLO_KEY, TRELLO_TOKEN). Kaynak: Trello/*.md ('## CARD: Başlık' blokları).
python tools/trello_push.py            -> yaz
python tools/trello_push.py --dry      -> yalnız ne yapacağını yazar"""
import json, os, re, sys, time, urllib.parse, urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
BOARD = 'UQ6NxrhU'
DRY = '--dry' in sys.argv
env = dict(l.strip().split('=', 1) for l in open(os.path.join(ROOT, '_tmp', 'trello.env'), encoding='utf-8') if '=' in l)
K, T = env['TRELLO_KEY'], env['TRELLO_TOKEN']


def api(method, path, **params):
    params.update(key=K, token=T)
    data = urllib.parse.urlencode(params).encode()
    url = 'https://api.trello.com/1/' + path
    req = urllib.request.Request(url + ('?' + data.decode() if method == 'GET' else ''), data=None if method == 'GET' else data, method=method)
    for _ in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode() or 'null')
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(2)
                continue
            raise RuntimeError('%s %s -> %s %s' % (method, path, e.code, e.read()[:200]))
    raise RuntimeError('rate limit')


def cards_of(md):
    txt = open(os.path.join(ROOT, 'Trello', md), encoding='utf-8').read()
    out = []
    for m in re.finditer(r'^## CARD: (.+?)\n(.*?)(?=^---\s*$|^## CARD: |\Z)', txt, re.M | re.S):
        out.append((m.group(1).strip(), m.group(2).strip()))
    return out


lists = {l['name']: l['id'] for l in api('GET', 'boards/%s/lists' % BOARD, fields='name')}
cards = api('GET', 'boards/%s/cards' % BOARD, fields='name,idList')


def lid(name):
    if name not in lists:
        if DRY:
            print('YENI LISTE', name)
            return 'DRY'
        l = api('POST', 'lists', name=name, idBoard=api('GET', 'boards/%s' % BOARD, fields='id')['id'], pos='bottom')
        lists[name] = l['id']
    return lists[name]


def put(list_name, title, desc, update_title=None):
    """update_title: bu listede bu adla duran kartın açıklamasını değiştir (adı korunur)"""
    desc = desc[:16000]
    L = lid(list_name)
    target = update_title or title
    ex = [c for c in cards if c['idList'] == L and c['name'] == target]
    if ex:
        print('GUNCELLE', list_name, '|', target)
        if not DRY:
            api('PUT', 'cards/%s' % ex[0]['id'], desc=desc)
    else:
        print('YENI     ', list_name, '|', title)
        if not DRY:
            c = api('POST', 'cards', idList=L, name=title, desc=desc, pos='bottom')
            cards.append({'id': c['id'], 'name': title, 'idList': L})


G = dict(cards_of('guides_en.md'))
put('08 · Tailed Beasts', 'Where every Tailed Beast lives', G['Tailed Beasts — Where They Are'])
put('08 · Tailed Beasts', '', G['Tailed Beasts — Sealing'], update_title='Finding and sealing a tailed beast')
put('08 · Tailed Beasts', '', G['Gedō Mazō and the Ten-Tails (your own path)'], update_title='Ten-Tails (late game)')
put('08 · Tailed Beasts', 'The Ten-Tails threat and Infinite Tsukuyomi', G['The Ten-Tails Threat (world event)'])
put('07 · Eyes (Dōjutsu)', '', G['Rinnegan — How to Awaken It'], update_title='Rinnegan')
put('07 · Eyes (Dōjutsu)', 'Every eye in detail (how to get each one)', G['Eyes (Dōjutsu) — How Each One Works and How to Get It'])
put('04 · Jutsu & Chakra', 'Kekkei genkai natures — every way to get one', G['Kekkei Genkai Natures — Every Way to Get One'])
put('09 · Special Paths', 'Puppets (Shirogane clan and Akasuna Path)', G['Puppets — How to Get Them'])
put('14 · Akatsuki & Rogues', 'Akatsuki — full guide', G['Akatsuki'])
put('17 · Tips & FAQ', 'Body is spent (forbidden power costs)', G['Body Is Spent (forbidden powers)'])
put('04 · Jutsu & Chakra', 'Summons — giving orders (J / U) and riding', G['Summons — Giving Orders'])
put('07 · Eyes (Dōjutsu)', 'Six Paths of Pain (Pein Rikudō)', G['Six Paths of Pain (Pein Rikudō)'])
put('14 · Akatsuki & Rogues', 'Rogue ninja — how villages react', G['Rogue Ninja — How Villages React'])
for t, d in cards_of('paths_en.md'):
    put('09 · Special Paths', t, d)
for t, d in cards_of('clans_en.md'):
    put('18 · Clans', t, d)
src = open(os.path.join(ROOT, 'Trello', 'jutsu_sources_en.md'), encoding='utf-8').read()
src = re.sub(r'^# .*\n', '', src, count=1).strip()
head, _, rest = src.partition('\n### ')
put('05 · Learning Jutsu', 'Every learning source (table)', head.strip())
# özel şartlı teknik listeleri: 15 bin karakterlik kartlara bölünür (Trello açıklama sınırı 16384)
parts, cur = [], ''
for blk in ('### ' + rest).split('\n### '):
    blk = blk if blk.startswith('### ') else '### ' + blk
    if len(cur) + len(blk) > 15000 and cur:
        parts.append(cur)
        cur = ''
    cur += blk.strip() + '\n\n'
if cur.strip():
    parts.append(cur)
for i, pt in enumerate(parts, 1):
    put('05 · Learning Jutsu', 'Techniques with special requirements (%d/%d)' % (i, len(parts)), pt.strip())
print('bitti')
