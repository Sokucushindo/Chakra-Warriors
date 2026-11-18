"""Arayüz fırça dokuları (sumi-e): beyaz + alfa maske üretir, oyunda renge boyanır.
Referans: Ghost of Tsushima / Sekiro menüleri (interfaceingame.com) — kör başlayan, sağa doğru kuru fırça
lifleriyle dağılan mürekkep darbesi, yırtık kenarlı mürekkep panel.
kullanım: python tools/make_ui_brush.py   -> godot/assets/ui/*.png"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'ui')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def noise1(n, scale, octaves=3, seed=0):
    """düzgün 1B değer gürültüsü, -1..1"""
    r = np.random.default_rng(seed)
    out = np.zeros(n)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        k = max(2, int(n / scale * (2 ** o)) + 2)
        pts = r.uniform(-1, 1, k)
        xs = np.linspace(0, k - 1, n)
        i = np.floor(xs).astype(int).clip(0, k - 2)
        f = xs - i
        f = f * f * (3 - 2 * f)
        out += amp * (pts[i] * (1 - f) + pts[i + 1] * f)
        tot += amp
        amp *= 0.5
    return out / tot


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def stroke(W, H, seed, thick=0.36, tail=0.3, dry=1.0):
    """yatay fırça darbesi: solda eğik kör baş, gövdede kıl izleri, sağda boyu farklı kuru lifler"""
    x = np.arange(W)[None, :].astype(float)
    y = np.arange(H)[:, None].astype(float)
    u = x / (W - 1)
    yc = H * 0.5 + noise1(W, W * 0.7, 2, seed)[None, :] * H * 0.04
    half0 = H * thick
    d = y - yc
    v = d / half0                                   # -1..1 kalınlık içinde
    # kalınlık: gövde boyunca hafif şişip incelir, sağda daralır
    body = (1 + 0.08 * noise1(W, W * 0.35, 2, seed + 1)[None, :]) * (1 - 0.25 * smooth(1 - tail, 1.0, u))
    top = half0 * body * (1 + 0.05 * noise1(W, 60, 2, seed + 2)[None, :] + 0.03 * noise1(W, 7, 1, seed + 12)[None, :])
    bot = half0 * body * (1 + 0.05 * noise1(W, 60, 2, seed + 3)[None, :] + 0.03 * noise1(W, 7, 1, seed + 13)[None, :])
    edge = np.where(d < 0, -d - top, d - bot)
    m = 1 - smooth(-1.0, 1.0, edge)
    # baş: eğik, kör, hafif yuvarlak (fırça açılı bastırılmış)
    x0 = W * (0.012 + 0.018 * (v * v) + 0.012 * v) + 2.0 * noise1(H, 4, 2, seed + 9)[:, None]
    m *= smooth(x0 - 1.5, x0 + 1.5, x)
    # kıl izleri: her satırın kendi mürekkep yükü
    load = 0.5 + 0.5 * noise1(H, 1.7, 3, seed + 4)[:, None]          # 0..1
    load = np.clip(load + 0.1 * noise1(W, W * 0.2, 2, seed + 5)[None, :], 0, 1)
    # kuruma: az yüklü kıllar sağa doğru erken biter, kenar kılları daha erken
    rel = np.clip(np.abs(v), 0, 1)
    endu = 1 - tail * (1 - load) * 1.3 - 0.06 * rel * rel
    endu = np.clip(endu, 1 - tail * 0.92, 0.985)
    m *= 1 - smooth(endu - 0.025, endu + 0.005, u)
    # gövdede ince boşluklar (kuru fırça)
    gaps = smooth(0.08, 0.22, load + 0.25 - dry * 0.25 * smooth(0.4, 1.0, u) - 0.2 * smooth(0.6, 1.0, rel))
    m *= gaps
    ink = 0.78 + 0.22 * load
    return np.clip(m * ink, 0, 1)


def panel(W, H, seed, inset=12, rough=7.0):
    """yırtık kenarlı mürekkep yıkama panel"""
    x = np.arange(W)[None, :].astype(float)
    y = np.arange(H)[:, None].astype(float)
    def side(n, sd):
        return rough * (0.5 + 0.35 * noise1(n, 40, 2, sd) + 0.15 * noise1(n, 5, 2, sd + 50))
    l = inset + side(H, seed)[:, None]
    r = W - 1 - inset - side(H, seed + 1)[:, None]
    t = inset + side(W, seed + 2)[None, :]
    b = H - 1 - inset - side(W, seed + 3)[None, :]
    dist = np.minimum(np.minimum(x - l, r - x), np.minimum(y - t, b - y))
    m = smooth(-1.0, 1.5, dist)
    # kenarda kuru fırça lifleri (yatay kenarlarda yatay, dikeyde dikey)
    hr = noise1(H, 2.5, 2, seed + 4)[:, None]
    vr = noise1(W, 2.5, 2, seed + 5)[None, :]
    near_v = 1 - smooth(0, 10, np.minimum(x - l, r - x))
    near_h = 1 - smooth(0, 10, np.minimum(y - t, b - y))
    m *= 1 - near_h * (1 - smooth(-0.3, 0.1, vr + 0.55)) * 0.8
    m *= 1 - near_v * (1 - smooth(-0.3, 0.1, hr + 0.55)) * 0.8
    # iç: washi lifi + mürekkep birikintisi
    fib = 0.93 + 0.07 * (0.5 + 0.5 * noise1(W, 6, 3, seed + 6)[None, :] * noise1(H, 60, 2, seed + 7)[:, None])
    return np.clip(m * fib, 0, 1)


def seal(N, seed):
    """hanko mühür zemini: aşınmış kenarlı kare, içte mürekkebin tutmadığı küçük benekler"""
    m = panel(N, N, seed, inset=5, rough=4.0)
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    for _ in range(14):
        cx, cy, rad = r.uniform(8, N - 8), r.uniform(8, N - 8), r.uniform(0.8, 2.6)
        m *= 1 - 0.85 * smooth(rad, rad * 0.4, np.hypot(xx - cx, yy - cy))
    # kenara yakın aşınma: köşelerde daha çok
    edge = np.minimum(np.minimum(xx, N - 1 - xx), np.minimum(yy, N - 1 - yy))
    wear = 0.5 + 0.5 * noise1(N, 9, 2, seed + 9)[None, :] * noise1(N, 9, 2, seed + 10)[:, None]
    m *= 1 - 0.55 * (1 - smooth(5, 14, edge)) * smooth(0.55, 0.8, wear)
    return np.clip(m, 0, 1)


def noise2(W, H, scale, octaves=3, seed=0):
    """2B değer gürültüsü, -1..1"""
    r = np.random.default_rng(seed)
    out = np.zeros((H, W))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        kx = max(2, int(W / scale * 2 ** o) + 2)
        ky = max(2, int(H / scale * 2 ** o) + 2)
        g = r.uniform(-1, 1, (ky, kx))
        xs = np.linspace(0, kx - 1.001, W)
        ys = np.linspace(0, ky - 1.001, H)
        xi = np.floor(xs).astype(int); yi = np.floor(ys).astype(int)
        fx = xs - xi; fy = ys - yi
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
        a = g[yi][:, xi]; b = g[yi][:, xi + 1]; c = g[yi + 1][:, xi]; d = g[yi + 1][:, xi + 1]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy)[:, None] + (c * (1 - fx) + d * fx) * fy[:, None])
        tot += amp
        amp *= 0.5
    return out / tot


def enso(N, seed):
    """ensō: tek darbe fırça halkası; kalın başlangıç, kıl izleri, sona doğru kuruyup dağılan lifler"""
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    c = N * 0.5
    dx, dy = xx - c, yy - c
    rho = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    a0 = -1.05
    span = 2 * np.pi * 0.93
    t = np.mod(th - a0, 2 * np.pi) / span          # 0..1 darbe boyunca (>1: boşluk)
    R = N * 0.37
    wob = 1 + 0.015 * np.sin(t * 7.0) + 0.01 * np.sin(t * 19.0 + 1.0)
    head = np.clip(t / 0.05, 0, 1) ** 0.5
    prof = head * (1 - 0.55 * smooth(0.55, 1.0, t)) * (1 + 0.12 * np.sin(t * 3.1 + 0.5))
    hw = N * 0.075 * prof
    u = (rho - R * wob) / np.maximum(hw, 0.5)       # -1..1 kalınlık içinde
    m = 1 - smooth(0.92, 1.08, np.abs(u) + 0.04 * noise2(N, N, 6, 2, seed))
    m *= (t <= 1.0)
    # kıl yükü: u boyunca gürültü, t boyunca yavaş kayar
    uu = np.clip((u + 1) * 0.5, 0, 1)
    load = np.zeros_like(u)
    k = 48
    pts = np.random.default_rng(seed + 1).uniform(0, 1, k + 2)
    xi = np.clip((uu * k).astype(int), 0, k)
    f = uu * k - xi
    load = pts[xi] * (1 - f) + pts[xi + 1] * f
    load = np.clip(load + 0.12 * noise2(N, N, 40, 2, seed + 2), 0, 1)
    dry = smooth(0.5, 1.0, t) * 1.3 + smooth(0.6, 1.0, np.abs(u)) * 0.45
    m *= smooth(0.0, 0.12, load + 0.35 - dry * 0.75)
    # uç: kılların boyu farklı
    endt = 1 - 0.08 * (1 - load)
    m *= 1 - smooth(endt - 0.01, endt + 0.005, t)
    ink = 0.82 + 0.18 * load
    # başlangıçta birkaç mürekkep sıçraması
    r = np.random.default_rng(seed + 3)
    for _ in range(7):
        a = a0 + r.uniform(-0.25, 0.08)
        rr = R + r.uniform(-1.6, 1.6) * N * 0.07
        px, py = c + np.cos(a) * rr, c + np.sin(a) * rr
        sz = r.uniform(0.8, 2.6)
        m = np.maximum(m, (1 - smooth(sz * 0.6, sz, np.hypot(xx - px, yy - py))) * 0.9)
    return np.clip(m * ink, 0, 1)


def ink_disc(N, seed):
    """kâğıda yayılmış mürekkep lekesi: dalgalı kenar, kenarda sızma, içte bulutlu yoğunluk"""
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    c = N * 0.5
    rho = np.hypot(xx - c, yy - c)
    th = np.arctan2(yy - c, xx - c)
    edge_n = np.zeros_like(th)
    r = np.random.default_rng(seed)
    for k, amp in [(3, 0.035), (7, 0.02), (17, 0.012), (41, 0.006)]:
        ph = r.uniform(0, 6.3)
        edge_n += amp * np.sin(th * k + ph)
    R = N * 0.43 * (1 + edge_n)
    core = 1 - smooth(R - 2.5, R + 0.5, rho)
    bleed = (1 - smooth(R - 1, R + N * 0.035, rho)) * (0.45 + 0.35 * noise2(N, N, 5, 2, seed + 1))
    m = np.maximum(core, np.clip(bleed, 0, 1) * 0.6)
    cloud = 0.86 + 0.14 * noise2(N, N, 50, 3, seed + 2)
    return np.clip(m * cloud, 0, 1)


def washi(W, H, seed):
    """washi kâğıt şerit (renkli RGBA): lifli yırtık kenarlar, kâğıt dokusu, kenarlarda hafif eskime"""
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    top = 6 + 3.0 * (0.5 + 0.5 * noise1(W, 30, 3, seed)) + 1.5 * noise1(W, 3, 1, seed + 9)
    bot = H - 7 - 3.0 * (0.5 + 0.5 * noise1(W, 30, 3, seed + 1)) - 1.5 * noise1(W, 3, 1, seed + 10)
    lft = 10 + 6.0 * (0.5 + 0.5 * noise1(H, 12, 3, seed + 2))
    rgt = W - 11 - 6.0 * (0.5 + 0.5 * noise1(H, 12, 3, seed + 3))
    d = np.minimum(np.minimum(yy - top[None, :], bot[None, :] - yy), np.minimum(xx - lft[:, None], rgt[:, None] - xx))
    # yırtık kenarda dışarı taşan lifler
    fib = noise2(W, H, 2.0, 2, seed + 4)
    a = smooth(-1.2, 1.0, d + 2.2 * np.clip(fib, 0, 1) * (d > -4))
    a = np.clip(a, 0, 1)
    paper = np.array([0.94, 0.90, 0.81])
    grain = 0.035 * noise2(W, H, 3, 2, seed + 5) + 0.03 * noise2(W, H, 40, 2, seed + 6)
    # uzun ince lifler
    r = np.random.default_rng(seed + 7)
    fl = np.zeros((H, W))
    for _ in range(90):
        x0, y0 = r.uniform(0, W), r.uniform(0, H)
        ang = r.uniform(-0.6, 0.6)
        ln = r.uniform(8, 30)
        ts = np.linspace(0, 1, int(ln * 2))
        px = (x0 + np.cos(ang) * ln * ts).astype(int)
        py = (y0 + np.sin(ang) * ln * ts + 3 * np.sin(ts * 3)).astype(int)
        ok = (px >= 0) & (px < W) & (py >= 0) & (py < H)
        fl[py[ok], px[ok]] += r.uniform(-0.05, 0.06)
    age = 0.10 * (1 - smooth(0, 14, d))   # kenarlar hafif kararır
    col = paper[None, None, :] * (1 + grain + fl)[:, :, None] - age[:, :, None] * np.array([0.25, 0.32, 0.45])
    rgba = np.dstack([np.clip(col, 0, 1), a])
    return rgba


def save_rgba(name, rgba):
    Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name))
    print(name, rgba.shape[1::-1])


def line(W, H, seed):
    """başlık altı ince fırça çizgisi"""
    return stroke(W, H, seed, thick=0.32, tail=0.5, dry=1.3)


def save(name, a):
    a8 = (a * 255).astype(np.uint8)
    rgba = np.dstack([np.full_like(a8, 255)] * 3 + [a8])
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, name))
    print(name, a.shape[::-1])


save('brush_a.png', stroke(384, 64, 11, tail=0.32))
save('brush_b.png', stroke(384, 64, 23, thick=0.38, tail=0.34))
save('brush_s.png', stroke(160, 48, 53, thick=0.37, tail=0.3))
save('brush_line.png', line(256, 20, 31))
save('ink_panel.png', panel(256, 256, 41))
save('seal.png', seal(96, 61))
save('enso.png', enso(256, 71))
save('ink_disc.png', ink_disc(256, 83))
save_rgba('washi.png', washi(512, 80, 91))
