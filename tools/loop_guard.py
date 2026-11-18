"""Sonsuz tekrarlı Tween koruması. Yayın motorunda süre harcamayan tekrarlı Tween (hedefi silinmiş, süresi 0) oyunu kilitler.
Her `x.set_loops()` / hesaplanan sayılı `x.set_loops(n)` çağrısını `Game.safe_loops(x, n)` yapar. Tekrar çalıştırmak zararsızdır."""
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "godot", "scripts")
SKIP = {os.path.join("core", "game.gd")}
OPEN, CLOSE = "([{", ")]}"


def recv_start(t, i):
    """i = '.set_loops' noktası; alıcı ifadenin başı"""
    j = i
    while j > 0:
        c = t[j - 1]
        if c in CLOSE:
            d = 0
            while j > 0:
                j -= 1
                if t[j] in CLOSE:
                    d += 1
                elif t[j] in OPEN:
                    d -= 1
                    if d == 0:
                        break
        elif c.isalnum() or c in "_.$":
            j -= 1
        else:
            break
    return j


def args_end(t, i):
    d = 0
    while i < len(t):
        c = t[i]
        if c in OPEN:
            d += 1
        elif c in CLOSE:
            d -= 1
            if d == 0:
                return i
        i += 1
    return -1


def fix(t):
    out = 0
    pos = 0
    while True:
        i = t.find(".set_loops(", pos)
        if i < 0:
            return t, out
        pos = i + 1
        ls = t.rfind("\n", 0, i) + 1
        if "#" in t[ls:i]:
            continue
        o = i + len(".set_loops")
        e = args_end(t, o)
        a = t[o + 1:e].strip()
        if re.fullmatch(r"[1-9]\d*", a):
            continue
        s = recv_start(t, i)
        r = t[s:i]
        if not r:
            continue
        new = "Game.safe_loops(%s%s)" % (r, ", " + a if a and a != "0" else "")
        t = t[:s] + new + t[e + 1:]
        pos = s + len(new)
        out += 1


def main():
    n = 0
    for d, _, fs in os.walk(ROOT):
        for f in fs:
            if not f.endswith(".gd"):
                continue
            p = os.path.join(d, f)
            if os.path.relpath(p, ROOT) in SKIP:
                continue
            with open(p, encoding="utf8", newline="") as h:
                t = h.read()
            if ".set_loops(" not in t:
                continue
            u, c = fix(t)
            if c:
                with open(p, "w", encoding="utf8", newline="") as h:
                    h.write(u)
                n += c
    print("tekrarlı Tween koruması: %d yer" % n)


if __name__ == "__main__":
    sys.exit(main())
