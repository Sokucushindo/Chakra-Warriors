"""Veri dosyalarındaki (jutsu, eşya, klan, yetenek) çevrilecek yazıları çıkarır -> _tmp/i18n_veri_NN.json parçaları.
Jutsu adları ve jutsunun anlamı alınmaz (ad romaji kalır, anlam İngilizcede name_en'dir)."""
import json, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "godot", "data")
EN = os.path.join(D, "i18n", "en.json")
have = json.load(open(EN, encoding="utf-8"))
L = re.compile(r"[A-Za-zçğıöşüÇĞİÖŞÜ]{2,}")
F = {"jutsu": ["desc"], "items": ["name", "desc"], "clans": ["name", "desc", "kg"]}
out = {}
def add(s):
    if isinstance(s, str) and re.match(r"^(Parşömen: |[SABCDE] — )", s):
        s = re.sub(r"^(Parşömen: |[SABCDE] — )", "", s)   # şablonla çevrilir; yalnız iç kısım
        if not re.search(r"[çğıöşüÇĞİÖŞÜ]", s):
            return
    if isinstance(s, str) and s.strip() and L.search(s) and s not in have:
        out[s] = ""
for t, fs in F.items():
    for k, e in json.load(open(os.path.join(D, t + ".json"), encoding="utf-8")).items():
        if isinstance(e, dict):
            for f in fs:
                if re.search(r"[çğıöşüÇĞİÖŞÜ]", str(e.get(f, ""))) or f == "desc":
                    add(e.get(f))
sk = json.load(open(os.path.join(D, "skills.json"), encoding="utf-8"))
for e in list(sk.get("nodes", {}).values()) + sk.get("branches", []):
    if isinstance(e, dict):
        add(e.get("name")); add(e.get("desc"))
items = list(out.items())
for f in os.listdir(os.path.join(ROOT, "_tmp")):
    if f.startswith("i18n_veri_"):
        os.remove(os.path.join(ROOT, "_tmp", f))
N = 140
for i in range(0, len(items), N):
    json.dump(dict(items[i:i + N]), open(os.path.join(ROOT, "_tmp", "i18n_veri_%02d.json" % (i // N)), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(items), "yazı,", (len(items) + N - 1) // N, "parça")
