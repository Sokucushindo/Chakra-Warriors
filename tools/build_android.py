"""Android APK derlemesi (yalnız `android` branch'i / D:\\Chakra Warriors Android).

    python tools/build_android.py          -> Android/ChakraWarriors_v<VERSION>.apk (imzalı, arm64)

PC sürümüne dokunmaz. Güncelleme sırası (PC "güncelle" sonrası):
    1) git merge main           (PC yenilikleri gelir; Android'e özel dosyalar korunur)
    2) köy önbelleği:           PC klasöründen godot/data/bake kopyalanır (git dışı)
    3) python tools/build_android.py
İmza anahtarı D:\\Android\\keys (git dışında; kaybolursa oyuncular güncellemeyi eskisinin üstüne kuramaz).
"""
import os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PC = r'D:\Naruto 3D Game'
GODOT = os.path.join(PC, 'tools', 'Godot_v4.7.2-stable_win64_console.exe')
SDK = r'D:\Android\Sdk'
JDK = r'C:\Program Files\Java\jdk-20'
KEYS = r'D:\Android\keys\keystore.txt'

version = open(os.path.join(ROOT, 'VERSION')).read().strip()
a, b, c = map(int, version.split('.'))

# sürüm kodu / adı preset'e yazılır (Android aynı paketin yenisini ancak daha büyük kodla kurar)
pp = os.path.join(ROOT, 'godot', 'export_presets.cfg')
s = open(pp, encoding='utf-8', newline='').read()
s = re.sub(r'version/code=\d+', 'version/code=%d' % (a * 100000 + b * 100 + c), s)
s = re.sub(r'version/name="[^"]*"', 'version/name="%s"' % version, s)
open(pp, 'w', encoding='utf-8', newline='').write(s)

# köy önbelleği PC klasöründen (git dışı)
src_bake = os.path.join(PC, 'godot', 'data', 'bake')
dst_bake = os.path.join(ROOT, 'godot', 'data', 'bake')
if os.path.isdir(src_bake):
    if os.path.isdir(dst_bake):
        shutil.rmtree(dst_bake)   # eski sürümün önbelleği kalmasın (iki kopya APK'yı şişiriyordu)
    shutil.copytree(src_bake, dst_bake)

kv = dict(l.strip().split('=', 1) for l in open(KEYS, encoding='utf-8') if '=' in l)
env = dict(os.environ)
env.update({
    'JAVA_HOME': JDK, 'ANDROID_HOME': SDK, 'ANDROID_SDK_ROOT': SDK,
    'GODOT_ANDROID_KEYSTORE_RELEASE_PATH': kv['keystore'],
    'GODOT_ANDROID_KEYSTORE_RELEASE_USER': kv['alias'],
    'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD': kv['password'],
})
out_dir = os.path.join(ROOT, 'Android')
os.makedirs(out_dir, exist_ok=True)
apk = os.path.join(out_dir, 'ChakraWarriors_v%s.apk' % version)
if os.path.exists(apk):
    os.remove(apk)
cmd = [GODOT, '--headless', '--path', os.path.join(ROOT, 'godot'), '--export-release', 'Android', apk,
       '--log-file', os.path.join(ROOT, '_tmp', 'android_export.log')]
r = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace')
tail = (r.stdout + r.stderr).strip().splitlines()[-15:]
if not os.path.exists(apk):
    print('\n'.join(tail))
    sys.exit('APK oluşmadı')
print('OK -> %s  (v%s, %d MB)' % (apk, version, os.path.getsize(apk) // 1048576))
