extends RefCounted
## (class_name yok: menus/hud preload ile kullanır — SHOP_SELL)
## Dükkâna eşya satma: aynı eşyadan birikenler (ekipman kopyaları, sayılı sarf malzemeleri) gerçek bir dükkânın tezgâhında satılır.
## Her dükkân kendi işinin malını alır (terzi giysi, silahçı silah/alet, eczane ilaç); kara pazar her şeyi alır ama ucuza.
## Satılmayanlar: üstündeki eşya, aile yadigârı, efsanevi silah, makam / örgüt giysisi, görev eşyası, klan hapı,
## sınırsız aletler (bir kez alınır, sahiplik kalıcı), yasak parşömen (yalnız kara pazar).

const RATE := 0.5          # normal dükkân: alış fiyatının yarısı
const BLACK_RATE := 0.35   # kara pazar: her şeyi alır, soru sormaz, ucuza
const HEIRLOOMS := ["hakko_chakura_to", "shodai_kubikazari"]   # klan yadigârları (Progress.clan_starter_kit)
const REGALIA := ["set_akatsuki", "set_kage"]                   # + Gear.KAGE_SETS / KAGE_HATS


## Dükkân adından alıcı türü: "cloth" terzi, "weapon" silahçı, "general" eczane, "black" kara pazar; "" = bu dükkân mal almaz
static func buyer_of(title: String) -> String:
	if title.begins_with("Kara "):
		return "black"
	if title == "Terzi":
		return "cloth"
	if title in ["Silahçı", "Silah Dükkânı"]:
		return "weapon"
	if title == "Eczane":
		return "general"
	return ""


static func buyer_text(buyer: String) -> String:
	return {"cloth": "Terzi yalnız giysi, kafalık ve sırt eşyası alır.", "weapon": "Silahçı yalnız silah ve ninja aleti alır.",
		"general": "Eczacı yalnız ilaç ve sarf malzemesi alır.", "black": "Kara pazar her şeyi alır, ama ucuza."}.get(buyer, "")


static func _gear_cat(id: String) -> String:
	var sl = String(LazyFx.g("Gear").item(id).get("slot", ""))
	return "weapon" if sl in ["el", "sag", "sol"] or LazyFx.g("Gear").item(id).has("weapon") else "cloth"


static func _item_cat(it: Dictionary) -> String:
	return {"throw": "weapon", "use": "general", "scroll": "scroll"}.get(String(it.get("kind", "")), "misc")


## Ekipmanın satılamama nedeni (kopya sayısından bağımsız); satılabilirse ""
static func gear_block(id: String) -> String:
	var it = LazyFx.g("Gear").item(id)
	var b = LazyFx.g("Gear").base_id(id)
	if id in HEIRLOOMS or b in HEIRLOOMS:
		return "Aile yadigârı: satılmaz."
	if it.get("legend", false) or id in LazyFx.g("Gear").LEGENDARY or LazyFx.g("Gear").WH.INFO.has(id):
		return "Efsanevi eşya: hiçbir tüccar alamaz."
	if id in REGALIA or id in LazyFx.g("Gear").KAGE_SETS or id in LazyFx.g("Gear").KAGE_HATS:
		return "Makam / örgüt giysisi: satılmaz."
	return ""


static func item_block(id: String, buyer: String) -> String:
	if not Data.items.has(id):
		return "Görev eşyası: satılmaz."
	var it: Dictionary = Data.items[id]
	var k = String(it.get("kind", ""))
	if k == "quest":
		return "Görev eşyası: satılmaz."
	if k == "clan":
		return "Klan sırrı: dışarıya satılmaz."
	if LazyFx.g("Stats").unlimited(id):
		return "Sınırsız alet: bir kez alınır, sahipliği kalıcıdır — satılmaz."
	if k == "scroll" and buyer != "black" and String(Data.jutsu.get(String(it.get("jutsu", "")), {}).get("learn", "")).begins_with("kinjutsu"):
		return "Yasak parşömen: dürüst bir dükkân bunu almaz (kara pazar alır)."
	if int(it.get("price", 0)) <= 0:
		return "Değeri biçilemez: satılmaz."
	return ""


## Tek eşyanın satış fiyatı (alış fiyatının yarısı; kara pazarda daha az). Fiyatı bilinmeyen ekipman: rütbesine göre küçük değer
static func unit_price(base_price: int, rank: int, buyer: String) -> int:
	var p = float(base_price) if base_price > 0 else 40.0 + 60.0 * float(rank)
	return maxi(1, int(round(p * (BLACK_RATE if buyer == "black" else RATE))))


## Bu dükkânın satış listesi: [{type, id, name, desc, count (satılabilir), owned, equipped, price (tane), reason, rarity}]
## Dükkânın işine girmeyen mallar listelenmez; işine giren ama satılamayanlar nedeniyle gösterilir.
static func entries(pr: Dictionary, buyer: String) -> Array:
	var out = []
	if buyer == "":
		return out
	LazyFx.g("Gear").ensure(pr)
	var by := {}
	for g in pr.get("gear", []):
		var gid = String(g.get("id", ""))
		if g.get("_tmp", false) or LazyFx.g("Gear").is_eye(gid) or LazyFx.g("Gear").is_legacy_piece(gid) or LazyFx.g("Gear").item(gid).is_empty():
			continue   # geçici (çağrılan silah), göz (eşya değil), eski parça
		if buyer != "black" and _gear_cat(gid) != buyer:
			continue
		if not by.has(gid):
			by[gid] = {"owned": 0, "eq": 0}
		by[gid]["owned"] += 1
		if LazyFx.g("Gear").is_equipped(pr, g):
			by[gid]["eq"] += 1
	for gid in by:
		var it = LazyFx.g("Gear").item(gid)
		var free = int(by[gid]["owned"]) - int(by[gid]["eq"])
		var why = gear_block(gid)
		if why == "" and free <= 0:
			why = "Üstünde takılı: önce çıkar."
		out.append({"type": "gear", "id": gid, "name": String(it.get("name", gid)), "desc": String(it.get("desc", "")),
			"count": free if why == "" else 0, "owned": int(by[gid]["owned"]), "equipped": int(by[gid]["eq"]),
			"price": unit_price(int(it.get("price", 0)), int(it.get("rank", 0)), buyer), "reason": why, "rarity": LazyFx.g("UI").rarity_of_gear(gid)})
	var inv: Dictionary = pr.get("inventory", {})
	for id in inv.keys():
		var n = int(inv[id])
		if n <= 0:
			continue
		var it: Dictionary = Data.items.get(id, {})
		if buyer != "black" and _item_cat(it) != buyer:
			continue
		var why = item_block(String(id), buyer)
		out.append({"type": "item", "id": String(id), "name": String(it.get("name", id)), "desc": String(it.get("desc", "")),
			"count": n if why == "" else 0, "owned": n, "equipped": 0, "unlimited": LazyFx.g("Stats").unlimited(String(id)),
			"price": unit_price(int(it.get("price", 0)), 0, buyer), "reason": why, "rarity": 1 if String(it.get("kind", "")) == "scroll" else 0})
	# satılabilenler önce, sonra ada göre
	out.sort_custom(func(a, b):
		if (a["reason"] == "") != (b["reason"] == ""):
			return a["reason"] == ""
		return String(a["name"]) < String(b["name"]))
	return out


## n tane sat: eşyayı düşer, Ryō ekler; kazanılan Ryō (0 = satılmadı)
static func sell(pr: Dictionary, e: Dictionary, n: int) -> int:
	n = clampi(n, 0, int(e.get("count", 0)))
	if n <= 0 or String(e.get("reason", "")) != "":
		return 0
	var id = String(e["id"])
	var done := 0
	if e["type"] == "gear":
		# takılı olmayan kopyalar; önce ek bilgisi olmayan sade kopyalar gider
		var cand = []
		for g in pr.get("gear", []):
			if String(g.get("id", "")) == id and not LazyFx.g("Gear").is_equipped(pr, g) and not g.get("_tmp", false):
				cand.append(g)
		cand.sort_custom(func(a, b): return a.size() < b.size())
		for i in mini(n, cand.size()):
			pr["gear"].erase(cand[i])
			done += 1
	else:
		var inv: Dictionary = pr["inventory"]
		done = mini(n, int(inv.get(id, 0)))
		inv[id] = int(inv.get(id, 0)) - done
		if int(inv[id]) <= 0:
			inv.erase(id)
			if String(pr.get("throw_sel", "")) == id:
				pr["throw_sel"] = "kunai"
	var gain = done * int(e["price"])
	pr["ryo"] = int(pr.get("ryo", 0)) + gain   # satış geliri düz: Ryō yeteneği görev ödülünü artırır, tezgâh fiyatını değil
	return gain
