"""Godot projesini Windows exe olarak dışa aktarır.
  python build.py test   -> Test\\ShinobiYolu_TEST.exe  (her değişiklikten sonra)
  python build.py main   -> Oyun\\ChakraWarriors.exe    ("güncelle" denince, sürüm artar)
"""
import os
import sys
import json
import shutil
import subprocess

ROOT = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(ROOT, 'tools', 'Godot_v4.7.2-stable_win64_console.exe')
PROJ = os.path.join(ROOT, 'godot')
mode = sys.argv[1] if len(sys.argv) > 1 else 'test'
assert mode in ('test', 'main', 'arena')   # arena: bire bir dövüş arenası deneme exe'si (adı ARENA içerince arena kipi açılır)
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'loop_guard.py')], check=True)   # süre harcamayan tekrarlı Tween yayın motorunu kilitler

ver_file = os.path.join(ROOT, 'VERSION')
version = open(ver_file).read().strip() if os.path.exists(ver_file) else '0.2.0'
if mode == 'main' and '--no-bump' not in sys.argv:
    a, b, c = map(int, version.split('.'))
    version = f'{a}.{b + 1}.0'
    open(ver_file, 'w').write(version)

build_json = os.path.join(PROJ, 'data', 'build.json')
import hashlib
def _world_key():
    # godot/scripts/world/village_bake.gd key() ile aynı: res:// yolu + dosya md5, sıralı; md5 hex'in ilk 12'si
    files = []
    for d in ['scripts/world', 'data/world']:
        for f in os.listdir(os.path.join(PROJ, d)):
            if f.endswith(('.gd', '.json', '.bin', '.png')):
                files.append('res://%s/%s' % (d, f))
    files += ['res://scripts/actors/character_model.gd', 'res://scripts/actors/outfit_parts.gd']
    files.sort()
    acc = ''.join(f + hashlib.md5(open(os.path.join(PROJ, f[6:]), 'rb').read()).hexdigest() for f in files)
    return hashlib.md5(acc.encode('utf-8')).hexdigest()[:12]
def _el_key():
    # elle yapılmış kıyafet önbelleği anahtarı: kıyafet kurulum kodunun içerik özeti. Sürüm numarasına bağlı değil:
    # kıyafet kodu değişmeyen güncellemelerde oyuncunun diskteki kıyafetleri korunur (eskiden her sürümde hepsi
    # oyun sırasında yeniden kuruluyordu -> her yerde takılma)
    d = os.path.join(PROJ, 'scripts', 'actors')
    files = sorted(f for f in os.listdir(d) if (f.startswith('set_el') or f.startswith('set_v2')) and f.endswith('.gd'))
    files += ['loft.gd', 'mb.gd']
    acc = ''.join(f + hashlib.md5(open(os.path.join(d, f), 'rb').read()).hexdigest() for f in files if os.path.exists(os.path.join(d, f)))
    return hashlib.md5(acc.encode('utf-8')).hexdigest()[:12]
json.dump({'build': mode, 'version': version, 'world': _world_key(), 'el': _el_key()}, open(build_json, 'w'))

# Başlangıç köylerini pakete hazır koy: oyuncunun ilk açılışı ~20 sn kısalır (village_bake.gd try_load res://data/bake yedeği).
# Önbellek bu dünya anahtarıyla yoksa oyun bir kez gizli masaüstünde kurulup köyler pişirilir (tests/test_bake_villages.gd).
import shutil, re
_wk = _world_key()
_bdir = os.path.join(ROOT, '_tmp', 'bake_dev')
_pk = os.path.join(PROJ, 'data', 'bake')
shutil.rmtree(_pk, ignore_errors=True)
os.makedirs(_pk, exist_ok=True)
if mode != 'test':
    # BÜTÜN köyler pakete pişmiş girer (kullanıcı: boyut önemli değil, oyun sırasında köy kurulumu takılması olmasın)
    _vids = [v['id'] for v in json.load(open(os.path.join(PROJ, 'data', 'world', 'world.json'), encoding='utf8'))['villages']]
    # build.json'da dünya anahtarı varken oyun kendi kayıt klasörüne (user://bake) pişirir; geliştirme koşusu _tmp/bake_dev'e
    _pj = open(os.path.join(PROJ, 'project.godot'), encoding='utf8').read()
    _cu = re.search(r'custom_user_dir_name="([^"]+)"', _pj)   # oyunun kayıt klasörü (project.godot'ta sabit; yeniden adlandırmada değişir)
    _ud = os.path.join(os.environ.get('APPDATA', ''), *(_cu.group(1).split('/') if _cu else ['Godot', 'app_userdata', 'Shinobi Yolu']), 'bake')
    def _find(vid):
        for d in (_bdir, _ud):
            c = [os.path.join(d, '%s_%s.%s' % (vid, _wk, e)) for e in ('scn', 'dat')]
            if all(os.path.exists(p) for p in c):
                return c
        return None
    if not all(_find(v) for v in _vids):
        print('Köy önbelleği eksik, pişiriliyor (~10 dk)...')
        _env = dict(os.environ)
        _env.pop('BAKE_ANY', None)
        subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'hd.py'), '2400', os.path.join(ROOT, '_tmp', 'bake_run.txt'), '--log-file',
                        os.path.join(ROOT, '_tmp', 'test_godot.log'), '--path', PROJ, '--resolution', '1280x720', '--',
                        '--test=res://tests/test_bake_villages.gd'], cwd=PROJ, env=_env)
    _mb = 0
    for v in _vids:
        c = _find(v)
        if c:
            for p in c:
                shutil.copy(p, _pk)
                _mb += os.path.getsize(p)
        else:
            print('UYARI: %s önbelleği pişirilemedi, pakete konmadı' % v)
    print('Köy önbelleği pakete konuyor: %s, %d MB' % (', '.join(_vids), _mb // 1048576))

name = {'test': 'ShinobiYolu_TEST', 'arena': 'ShinobiYolu_ARENA'}.get(mode, 'ChakraWarriors')
out_dir = os.path.join(ROOT, {'test': 'Test', 'arena': 'Arena'}.get(mode, 'Oyun'))
os.makedirs(out_dir, exist_ok=True)
for f in os.listdir(out_dir):  # eski (Python sürümü) exe'leri temizle
    if f.endswith('.exe') or f.endswith('.pck'):
        os.remove(os.path.join(out_dir, f))
exe = os.path.join(out_dir, name + '.exe')


def used_sketchfab():
    """Kodda kullanılan hayran modeli klasörleri (sf_models.gd + sf_props.gd içindeki "file": "...")."""
    import re
    used = set()
    for rel in ('scripts/actors/sf_models.gd', 'scripts/actors/sf_props.gd'):
        f = os.path.join(PROJ, rel)
        if os.path.exists(f):
            src = open(f, encoding='utf8').read()
            if 'const USE_FAN := false' in src:   # hayran silah/aksesuar modelleri kapalı: pakete girmesin
                continue
            used |= set(re.findall(r'"file":\s*"([^"]+)"', src))
    # yerler için doğrudan yolla yüklenen modeller (ör. Sonun Vadisi: res://assets/sketchfab/valley_of_end/...)
    f = os.path.join(PROJ, 'scripts/world/build_sites.gd')
    if os.path.exists(f):
        used |= set(re.findall(r'res://assets/sketchfab/([^/"]+)/', open(f, encoding='utf8').read()))
    return used


# kullanılmayan Sketchfab modellerini paketten çıkar (assets/sketchfab ~1.4 GB)
presets = os.path.join(PROJ, 'export_presets.cfg')
presets_orig = open(presets, encoding='utf8', newline='').read()
sf_dir = os.path.join(PROJ, 'assets', 'sketchfab')
excl = ['tests/*']
if os.path.isdir(sf_dir):
    used = used_sketchfab()
    unused = sorted(d for d in os.listdir(sf_dir) if os.path.isdir(os.path.join(sf_dir, d)) and d not in used)
    excl += ['assets/sketchfab/%s/*' % d for d in unused]
    print(f'Sketchfab: {len(used & set(os.listdir(sf_dir)))} model pakette, {len(unused)} dışarıda')
open(presets, 'w', encoding='utf8', newline='').write(presets_orig.replace('exclude_filter="tests/*"', 'exclude_filter="%s"' % ', '.join(excl), 1))
try:
    subprocess.run([GODOT, '--log-file', os.path.join(ROOT, '_tmp', 'test_godot.log'), '--headless', '--path', PROJ, '--import'], capture_output=True)
    r = subprocess.run([GODOT, '--log-file', os.path.join(ROOT, '_tmp', 'test_godot.log'), '--headless', '--path', PROJ, '--export-release', 'Windows', exe], capture_output=True, text=True)
finally:
    open(presets, 'w', encoding='utf8', newline='').write(presets_orig)
json.dump({'build': 'dev', 'version': version}, open(build_json, 'w'))
errors = [l for l in (r.stdout + r.stderr).splitlines() if 'ERROR' in l and 'leaked' not in l and 'still in use' not in l]
if not os.path.exists(exe):
    print('\n'.join(errors[-30:]))
    sys.exit('EXPORT BASARISIZ')
print(f'OK -> {exe}  (v{version}, {os.path.getsize(exe) // 1048576} MB)')
if mode == 'main':   # beceri deneme exe'si: aynı oyun, adı SKILLTEST içerince menüsüz deneme modu açılır
    import shutil
    sk = os.path.join(ROOT, 'SkillTest')
    os.makedirs(sk, exist_ok=True)
    shutil.copy2(exe, os.path.join(sk, 'ShinobiYolu_SKILLTEST.exe'))
    print('OK -> SkillTest\ShinobiYolu_SKILLTEST.exe')
