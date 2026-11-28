"""Ayak sesleri: sıfırdan sentez (hazır örnek yok), zemin başına 8 varyant.
Tek, yumuşak başlangıçlı vuruş (keskin "tak" ucu yok, ikinci vuruş yok) + zemine özgü doku.
  python tools/sfx_steps.py   -> godot/assets/sfx/step_<zemin>_vN.wav
Yalnız standart kütüphane (numpy gerekmez).
"""
import math
import os
import random
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'godot', 'assets', 'sfx')
SR = 44100
N_VAR = 8


def noise(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(x, fc):
    """iki kutuplu (iki kez tek kutup) alçak geçiren"""
    a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
    for _ in range(2):
        y = 0.0
        out = []
        for v in x:
            y += a * (v - y)
            out.append(y)
        x = out
    return x


def highpass(x, fc):
    lp = lowpass(x, fc)
    return [a - b for a, b in zip(x, lp)]


def bandpass(x, f0, q):
    """RBJ biquad bant geçiren (sabit tepe 0 dB)"""
    w = 2.0 * math.pi * f0 / SR
    al = math.sin(w) / (2.0 * q)
    b0, b1, b2 = al, 0.0, -al
    a0, a1, a2 = 1.0 + al, -2.0 * math.cos(w), 1.0 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for v in x:
        y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, y
        out.append(y)
    return out


def env(n, attack, tau, hold=0.0):
    """yumuşak başlangıç (sinüs rampası) + üstel sönüm"""
    out = []
    for i in range(n):
        t = i / SR
        if t < attack:
            e = math.sin(0.5 * math.pi * t / attack) ** 2
        elif t < attack + hold:
            e = 1.0
        else:
            e = math.exp(-(t - attack - hold) / tau)
        out.append(e)
    return out


def slow_mod(n, rng, rate, depth):
    """yavaş rastgele genlik dalgalanması (hışırtı / çıtırtı dokusu)"""
    pts = [rng.uniform(1.0 - depth, 1.0) for _ in range(int(n / SR * rate) + 3)]
    out = []
    for i in range(n):
        u = i / SR * rate
        k = int(u)
        f = u - k
        f = f * f * (3 - 2 * f)
        out.append(pts[k] * (1 - f) + pts[k + 1] * f)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def mul(a, b, g=1.0):
    return [x * y * g for x, y in zip(a, b)]


def finish(x, peak=0.6):
    # sonda kısa sönüm (kesik bitmesin) + tepe normalleme
    n = len(x)
    fade = int(0.02 * SR)
    for i in range(fade):
        x[n - 1 - i] *= i / fade
    m = max(abs(v) for v in x) or 1.0
    return [v / m * peak for v in x]


def grass(rng):
    """çim: yaprak hışırtısı (yüksek orta bant gürültü, dalgalı) + çok hafif yumuşak gövde"""
    d = rng.uniform(0.2, 0.26)
    n = int(SR * d)
    nz = noise(n, rng)
    rust = mix(bandpass(nz, rng.uniform(2600, 3400), 0.7), mul(bandpass(nz, rng.uniform(5200, 6800), 1.0), [1] * n, 0.6))
    rust = mul(rust, env(n, rng.uniform(0.014, 0.022), rng.uniform(0.05, 0.075)))
    rust = mul(rust, slow_mod(n, rng, rng.uniform(55, 80), 0.75))
    body = mul(lowpass(noise(n, rng), 160), env(n, 0.012, 0.035), 4.0)
    return finish(mix(rust, body), 0.5)


def dirt(rng):
    """toprak: boğuk tek gövde vuruşu + ince toprak/çakıl çıtırtısı (gövdeyle aynı zarfta)"""
    d = rng.uniform(0.2, 0.25)
    n = int(SR * d)
    body = mul(lowpass(noise(n, rng), rng.uniform(220, 300)), env(n, rng.uniform(0.007, 0.01), rng.uniform(0.03, 0.04)), 6.0)
    grit = highpass(noise(n, rng), 1800)
    grit = mul(grit, slow_mod(n, rng, rng.uniform(140, 200), 0.95))
    grit = mul(grit, env(n, 0.01, rng.uniform(0.035, 0.05)), 0.28)
    return finish(mix(body, grit), 0.55)


def stone(rng):
    """taş: yumuşak tabanlı boğuk vuruş + kısa sürtünme (keskin tık ucu yok)"""
    d = rng.uniform(0.16, 0.2)
    n = int(SR * d)
    body = mul(lowpass(noise(n, rng), rng.uniform(380, 480)), env(n, rng.uniform(0.006, 0.008), rng.uniform(0.022, 0.028)), 5.0)
    scuff = mul(bandpass(noise(n, rng), rng.uniform(2200, 2900), 0.8), env(n, 0.012, rng.uniform(0.03, 0.045)), 0.35)
    return finish(mix(body, scuff), 0.5)


def wood(rng):
    """tahta: kısa, sönümlü boş tahta tınısı (iki rezonans) + yumuşak vuruş"""
    d = rng.uniform(0.18, 0.22)
    n = int(SR * d)
    f1 = rng.uniform(150, 185)
    f2 = f1 * rng.uniform(2.3, 2.6)
    e1 = env(n, 0.006, rng.uniform(0.045, 0.06))
    e2 = env(n, 0.006, rng.uniform(0.025, 0.035))
    ph = rng.uniform(0, 6.28)
    res = [math.sin(2 * math.pi * f1 * i / SR + ph) * e1[i] * 0.7 + math.sin(2 * math.pi * f2 * i / SR) * e2[i] * 0.3 for i in range(n)]
    body = mul(lowpass(noise(n, rng), 350), env(n, 0.006, 0.02), 4.0)
    creak = mul(bandpass(noise(n, rng), rng.uniform(900, 1200), 2.0), env(n, 0.01, 0.04), 0.15)
    return finish(mix(res, body, creak), 0.5)


def tile(rng):
    """kiremit çatı: kısa, kuru seramik tıkırtısı. Boş gövde tınısı YOK (tahta sesi çatıda bidona basıyor gibiydi):
    çok kısa sönen yüksek tınılar (her varyantta ayrı perde) + kiremidin oynama tıkırtısı + ince kum sürtünmesi"""
    d = rng.uniform(0.13, 0.17)
    n = int(SR * d)
    body = mul(lowpass(noise(n, rng), rng.uniform(520, 700)), env(n, 0.004, rng.uniform(0.012, 0.016)), 4.0)
    f1 = rng.uniform(1150, 2100)
    f2 = f1 * rng.uniform(1.45, 1.9)
    e1 = env(n, 0.003, rng.uniform(0.009, 0.014))
    e2 = env(n, 0.003, rng.uniform(0.006, 0.009))
    clk = [math.sin(2 * math.pi * f1 * i / SR) * e1[i] * 0.3 + math.sin(2 * math.pi * f2 * i / SR) * e2[i] * 0.16 for i in range(n)]
    # ikinci, daha zayıf tık: basılan kiremidin komşusuna değmesi (20-45 ms sonra)
    off = int(SR * rng.uniform(0.02, 0.045))
    f3 = rng.uniform(1700, 2900)
    e3 = env(n, 0.002, rng.uniform(0.005, 0.008))
    rat = [0.0] * n
    for i in range(n - off):
        rat[i + off] = math.sin(2 * math.pi * f3 * i / SR) * e3[i] * rng.uniform(0.08, 0.16)
    scuff = mul(bandpass(noise(n, rng), rng.uniform(3000, 4200), 0.9), env(n, 0.008, rng.uniform(0.02, 0.03)), 0.22)
    return finish(mix(body, clk, rat, scuff), 0.42)


def write(path, x):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v)) * 32767)) for v in x))


def main():
    kinds = {'grass': grass, 'dirt': dirt, 'stone': stone, 'wood': wood, 'tile': tile}
    only = sys.argv[1:]
    kinds = {k: v for k, v in kinds.items() if not only or k in only}
    for k, fn in kinds.items():
        for i in range(N_VAR):
            rng = random.Random(hash((k, i)) & 0xffffffff if False else (len(k) * 1000 + i * 37 + 11))
            x = fn(rng)
            p = os.path.join(OUT, 'step_%s_v%d.wav' % (k, i))
            write(p, x)
            print(p)


if __name__ == '__main__':
    main()
