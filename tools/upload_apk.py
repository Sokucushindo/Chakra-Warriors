## APK'yı aynı sürümün (v<VERSION>) GitHub release dosyalarına ekler; PC zip'iyle yan yana. Sürüm notuna bir kez Android satırı ekler.
## python tools/upload_apk.py      (kimlik: git credential / Git Credential Manager — github_release.py ile aynı)
import subprocess, json, urllib.request, urllib.error, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n', capture_output=True, text=True).stdout
tok = dict(l.split('=', 1) for l in out.splitlines() if '=' in l).get('password')
if not tok:
    sys.exit('GitHub kimliği yok')
H = {'Authorization': 'token ' + tok, 'Accept': 'application/vnd.github+json'}
repo = 'Sokucushindo/Chakra-Warriors'
ver = open(os.path.join(ROOT, 'VERSION')).read().strip()
tag = 'v' + ver
apk = os.path.join(ROOT, 'Android', 'ChakraWarriors_v%s.apk' % ver)
if not os.path.exists(apk):
    sys.exit('APK yok: ' + apk)


def api(url, data=None, method='GET', headers=None, timeout=60):
    req = urllib.request.Request(url, data=data, headers=dict(H, **(headers or {})), method=method)
    return json.load(urllib.request.urlopen(req, timeout=timeout))


rel = api('https://api.github.com/repos/%s/releases/tags/%s' % (repo, tag))
name = os.path.basename(apk)
for a in rel.get('assets', []):
    if a['name'] == name:   # aynı adla eskisi varsa kaldır
        urllib.request.urlopen(urllib.request.Request(a['url'], headers=H, method='DELETE'))
up = rel['upload_url'].split('{')[0] + '?name=' + name
a = api(up, data=open(apk, 'rb').read(), method='POST', headers={'Content-Type': 'application/vnd.android.package-archive'}, timeout=3600)
note = ('\n\n### Android (test build)\nDownload **%s** and install it on your phone (Android 7.0+, 64-bit). '
        'Touch controls: joystick on the left (push it to the edge for the ninja run), drag anywhere free to turn the camera, '
        'pinch with two fingers to zoom, combat buttons on the right, tap the jutsu slots at the bottom to cast. '
        'The ••• button opens more actions (weapon, hand seals, Sage, beast, gates, inventory...); in seal mode tap the seals, then Cast. '
        'The phone back button pauses the game. Button size, visibility, camera sensitivity, vibration and a left-handed layout are in '
        'Settings > Controls > Touch. The first start uses phone-friendly graphics (you can raise them in Settings).' % name)
body = rel.get('body') or ''
tail = ''
if '### Android (test build)' in body:   # yalnız Android bölümü yenilenir; sonrasındaki satırlar (launcher indirme satırı) kalır
    i = body.index('### Android (test build)')
    j = body.find('\n\nDownload:', i)
    tail = body[j:] if j >= 0 else ''
    body = body[:i].rstrip()
api(rel['url'], data=json.dumps({'body': body + note + tail}).encode(), method='PATCH', headers={'Content-Type': 'application/json'})
print('OK', a['browser_download_url'], a['size'] // 1048576, 'MB')
