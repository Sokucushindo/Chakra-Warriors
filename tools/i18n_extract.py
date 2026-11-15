"""Çeviri kataloğu: oyun betiklerindeki ekranda görünen Türkçe yazıları çıkarır, çevirisi olmayanları listeler.

Kullanım: py tools/i18n_extract.py [klasör/dosya ...]   (varsayılan: godot/scripts)
Çıktı: _tmp/i18n_eksik.json  -> {"Türkçe yazı": ""}  (çevrilip godot/data/i18n/en.json'a eklenir)
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(ROOT, "godot", "data", "i18n", "en.json")
STR = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
TR = re.compile(r"[çğıöşüÇĞİÖŞÜ]")
WORD = re.compile(r"[A-Za-zçğıöşüÇĞİÖŞÜ]{2,}")
CODE = re.compile(r"shader_type|[A-Za-z_]+\.[A-Za-z_]+\(|^[)\],]|\bif\b.*\belse\b")
SKIP = re.compile(r"^(res|user)://|^[a-z0-9_./:-]*$|^#|^[A-Z0-9_]+$|^%[^ ]*$")


def visible(s: str, line: str) -> bool:
    if SKIP.search(s) or not WORD.search(s) or CODE.search(s):
        return False
    if TR.search(s):
        return True
    # Türkçe karakteri olmayan yazılar: büyük harfle ya da boşluklu, kod çağrısının içinde değil
    if re.search(r'(get_node|has_method|call|emit|connect|Sfx\.|music\(|load\(|preload\(|\.get\(|has\(|meta|group|is_action)\s*\(?[^"]*"' + re.escape(s), line):
        return False
    return bool(re.match(r"^[A-ZÇĞİÖŞÜ]", s)) or " " in s


def main():
    targets = sys.argv[1:] or [os.path.join(ROOT, "godot", "scripts")]
    have = json.load(open(EN, encoding="utf-8")) if os.path.exists(EN) else {}
    found = {}
    for t in targets:
        files = [t] if t.endswith(".gd") else [os.path.join(d, f) for d, _, fs in os.walk(t) for f in fs if f.endswith(".gd")]
        for f in files:
            for line in open(f, encoding="utf-8"):
                code = line.split("##")[0]
                if code.lstrip().startswith("#"):
                    continue
                for m in STR.finditer(code):
                    s = m.group(1).encode().decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in m.group(1) else m.group(1)
                    if visible(s, code) and s not in have:
                        found[s] = ""
    os.makedirs(os.path.join(ROOT, "_tmp"), exist_ok=True)
    out = os.path.join(ROOT, "_tmp", "i18n_eksik.json")
    json.dump(found, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    # parçalar (çeviri için): _tmp/i18n_kod_NN.json
    for f in os.listdir(os.path.join(ROOT, "_tmp")):
        if f.startswith("i18n_kod_"):
            os.remove(os.path.join(ROOT, "_tmp", f))
    items = list(found.items())
    for i in range(0, len(items), 150):
        json.dump(dict(items[i:i + 150]), open(os.path.join(ROOT, "_tmp", "i18n_kod_%02d.json" % (i // 150)), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"{len(found)} çevrilmemiş yazı -> {out}  (katalogda {len(have)})")


if __name__ == "__main__":
    main()
