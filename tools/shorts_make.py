"""Shorts kurgu aracı (fragman kiti): json sahne listesi -> 1080x1920 mp4 + müzik.
python tools/shorts_make.py plan.json
plan.json:
{"out": "video.mp4", "music": "song.mp3", "music_start": 105, "game_vol": 0.3, "music_vol": 0.95,
 "segments": [
   {"run": "run1.txt", "raw": "raw1.avi", "cut": "eye", "f0": 0.1, "f1": 1.0},        # dikey çekim (CUT a/b), oranla kırp
   {"ui": "ui1.txt", "raw": "ui.avi", "cut": "judge", "crop": [640, 520, 480, 190], "t1": "BAŞLIK", "t2": "alt yazı"},
   {"run": "...", "cut": "end", "disclaimer": true}
 ]}
Yollar plan dosyasının klasörüne göredir."""
import json, os, re, subprocess, sys
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
FPS = 30
FONT = "C\\:/Windows/Fonts/bahnschrift.ttf"
ENC = ['-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', str(FPS), '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-ac', '2']
_cache = {}


def cuts(path):
    if path not in _cache:
        c = {}
        for l in open(path, encoding='utf-8', errors='replace'):
            m = re.match(r'CUT (\S+) ([ab]) (\d+)', l.strip())
            if m:
                c.setdefault(m.group(1), {})[m.group(2)] = int(m.group(3))
        _cache[path] = c
    return _cache[path]


def ff(args):
    subprocess.run([FF, '-y', '-loglevel', 'error'] + args, check=True)


def txt(s):
    return s.replace(':', '\\:').replace("'", "’")


def main():
    plan_path = os.path.abspath(sys.argv[1])
    os.chdir(os.path.dirname(plan_path))
    plan = json.load(open(plan_path, encoding='utf-8'))
    os.makedirs('parts', exist_ok=True)
    parts = []
    sec_dur = {}   # bölüm -> süre (müzik geçişleri bölüm sınırına oturur)
    land = plan.get('landscape', False)   # yatay fragman: 1920x1080
    W, H = (1920, 1080) if land else (1080, 1920)
    for i, s in enumerate(plan['segments']):
        p = 'parts/%02d_%s.mp4' % (i, s['cut'])
        c = cuts(s.get('run') or s['ui'])[s['cut']]
        a, b = c['a'], c['b']
        a, b = a + int((b - a) * s.get('f0', 0.0)), a + int((b - a) * s.get('f1', 1.0))
        if 'max_s' in s:
            b = min(b, a + int(s['max_s'] * FPS))
        af = 'atrim=start=%.4f:end=%.4f,asetpts=PTS-STARTPTS' % (a / FPS, b / FPS)
        sec_dur[s.get('sec', '')] = sec_dur.get(s.get('sec', ''), 0.0) + (b - a) / FPS
        extra_txt = ''
        for t in s.get('texts', []):   # [metin, boyut, y, renk]
            extra_txt += ",drawtext=fontfile='%s':text='%s':fontsize=%d:fontcolor=%s:borderw=4:bordercolor=black:x=(w-tw)/2:y=%d" % (FONT, txt(t[0]), t[1], t[3] if len(t) > 3 else 'white', t[2])
        if 'ui' in s and land:   # yatay arayüz kaydı: tam kare + üst / alt yazı
            vf = 'trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS,scale=%d:%d:flags=lanczos' % (a, b, W, H)
            if s.get('t1'):
                vf += ",drawbox=y=0:w=iw:h=150:color=black@0.45:t=fill,drawtext=fontfile='%s':text='%s':fontsize=72:fontcolor=white:borderw=5:bordercolor=black:x=(w-tw)/2:y=40" % (FONT, txt(s['t1']))
            if s.get('t2'):
                vf += ",drawtext=fontfile='%s':text='%s':fontsize=44:fontcolor=0xffd36a:borderw=4:bordercolor=black:x=(w-tw)/2:y=h-100" % (FONT, txt(s['t2']))
            ff(['-i', s['raw'], '-vf', vf, '-af', af] + ENC + [p])
        elif 'ui' in s:
            cw, chh, cx, cy = s.get('crop', [1600, 900, 0, 0])
            vf = ('[0:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS,split[s1][s2];' % (a, b) +
                  '[s1]scale=-2:1920,crop=1080:1920,boxblur=24:2,eq=brightness=-0.18[bg];' +
                  '[s2]crop=%d:%d:%d:%d,scale=1040:-2:flags=lanczos[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2' % (cw, chh, cx, cy))
            if s.get('t1'):
                vf += ",drawtext=fontfile='%s':text='%s':fontsize=70:fontcolor=white:borderw=5:bordercolor=black:x=(w-tw)/2:y=470" % (FONT, txt(s['t1']))
            if s.get('t2'):
                vf += ",drawtext=fontfile='%s':text='%s':fontsize=44:fontcolor=0xffd36a:borderw=4:bordercolor=black:x=(w-tw)/2:y=1420" % (FONT, txt(s['t2']))
            ff(['-i', s['raw'], '-filter_complex', vf + '[v]', '-map', '[v]', '-af', af, '-map', '0:a'] + ENC + [p])
        else:
            vf = 'trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS,scale=%d:%d:flags=lanczos' % (a, b, W, H) + extra_txt
            if s.get('disclaimer'):
                y1 = 700 if land else 780
                vf += (",drawtext=fontfile='%s':text='Unofficial fan game':fontsize=42:fontcolor=white:borderw=4:bordercolor=black:x=(w-tw)/2:y=%d"
                       ",drawtext=fontfile='%s':text='Not affiliated with the Naruto creators':fontsize=36:fontcolor=0xeeeeee:borderw=4:bordercolor=black:x=(w-tw)/2:y=%d") % (FONT, y1, FONT, y1 + 56)
            ff(['-i', s['raw'], '-vf', vf, '-af', af] + ENC + [p])
        parts.append(p)
    with open('parts/list.txt', 'w') as f:
        for p in parts:
            f.write("file '%s'\n" % os.path.basename(p))
    ff(['-f', 'concat', '-safe', '0', '-i', 'parts/list.txt', '-c', 'copy', 'parts/sessiz.mp4'])
    d = subprocess.run([FF, '-i', 'parts/sessiz.mp4'], capture_output=True, text=True).stderr.split('Duration: ')[1].split(',')[0].split(':')
    dur = float(d[2]) + 60 * int(d[1])
    fo = max(0.0, dur - 2.0)
    # müzik: tek dosya ya da [{"file", "start", "len"}] listesi (aralarda 1.5 sn yumuşak geçiş)
    mus = plan['music'] if isinstance(plan['music'], list) else [{"file": plan['music'], "start": plan.get('music_start', 0.0), "len": dur + 5}]
    for k, m in enumerate(mus):   # bölüme bağlı parça: süresi bölüm süresi (+ geçiş payı)
        if 'sec' in m:
            m['len'] = sec_dur.get(m['sec'], 10.0) + (1.5 if k < len(mus) - 1 else 6.0)
            print('muzik', m['sec'], round(m['len'], 1))
    ins = ['-i', 'parts/sessiz.mp4']
    fc = '[0:a]volume=%.2f[g];' % plan.get('game_vol', 0.3)
    for k, m in enumerate(mus):
        ins += ['-i', m['file']]
        fc += '[%d:a]atrim=start=%.2f:duration=%.2f,asetpts=PTS-STARTPTS,aresample=48000,volume=%.2f[m%d];' % (k + 1, m['start'], m['len'], m.get('vol', plan.get('music_vol', 0.95)), k)
    cur = 'm0'
    for k in range(1, len(mus)):
        fc += '[%s][m%d]acrossfade=d=1.5:c1=tri:c2=tri[x%d];' % (cur, k, k)
        cur = 'x%d' % k
    fc += '[%s]afade=t=in:d=0.3[mm];[g][mm]amix=inputs=2:duration=first:normalize=0,afade=t=out:st=%.2f:d=2.5,alimiter=limit=0.95[a]' % (cur, max(0.0, dur - 2.5))
    ff(ins + ['-filter_complex', fc, '-map', '0:v', '-map', '[a]', '-c:v', 'copy',
              '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-movflags', '+faststart', '-shortest', plan['out']])
    print('OK', plan['out'], round(dur, 1), 'sn')


main()
