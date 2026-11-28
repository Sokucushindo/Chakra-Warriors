class_name Outfits
extends RefCounted
## NPC kıyafet setleri: her arketip kendi parça havuzundan rastgele giyinir (kalabalıklar çeşitli, rütbeler/gruplar ayırt edilir).
## roll(arketip, köy) -> görünüm (look) üstüne yazılacak anahtarlar. Görev kayıtları için roll_hex (renkler html dizesi).
## Arketipler: genin, chunin, jonin, anbu, kok, rogue, bandit, samurai, akatsuki, org, civ, merchant, monk, farmer, worker,
## medic, elder, kid, student, guard, noble, traveler, sennin, hunter

## Köy üniformaları: yelek rengi, yelek stili, alt giysi tonları, alın bandı kumaşı
const VILLAGE := {
	"konoha": {"vest": Color(0.38, 0.48, 0.28), "vs": 0, "base": [Color(0.15, 0.2, 0.33), Color(0.13, 0.17, 0.27)], "band": Color(0.15, 0.22, 0.55)},
	"suna": {"vest": Color(0.72, 0.62, 0.45), "vs": 1, "base": [Color(0.45, 0.36, 0.26), Color(0.3, 0.3, 0.32), Color(0.55, 0.45, 0.32)], "band": Color(0.25, 0.25, 0.3)},
	"kiri": {"vest": Color(0.45, 0.52, 0.46), "vs": 2, "base": [Color(0.28, 0.33, 0.4), Color(0.22, 0.27, 0.33)], "band": Color(0.2, 0.22, 0.3)},
	"kumo": {"vest": Color(0.88, 0.88, 0.84), "vs": 3, "base": [Color(0.2, 0.22, 0.26), Color(0.15, 0.16, 0.2)], "band": Color(0.1, 0.1, 0.12)},
	"iwa": {"vest": Color(0.62, 0.18, 0.15), "vs": 4, "base": [Color(0.38, 0.3, 0.25), Color(0.3, 0.26, 0.24)], "band": Color(0.45, 0.15, 0.13)},
	"oto": {"vest": null, "vs": 0, "base": [Color(0.42, 0.38, 0.48), Color(0.3, 0.28, 0.33)], "band": Color(0.3, 0.3, 0.35)},
	"ame": {"vest": Color(0.45, 0.48, 0.52), "vs": 2, "base": [Color(0.3, 0.32, 0.36), Color(0.22, 0.24, 0.28)], "band": Color(0.25, 0.27, 0.32)},
	"kusa": {"vest": Color(0.3, 0.45, 0.25), "vs": 0, "base": [Color(0.25, 0.32, 0.22), Color(0.2, 0.25, 0.2)], "band": Color(0.2, 0.35, 0.2)},
	"taki": {"vest": Color(0.42, 0.55, 0.6), "vs": 2, "base": [Color(0.2, 0.3, 0.38)], "band": Color(0.2, 0.3, 0.45)},
}

const VIVID := [Color(0.95, 0.5, 0.12), Color(0.2, 0.35, 0.65), Color(0.75, 0.15, 0.18), Color(0.2, 0.5, 0.3), Color(0.55, 0.3, 0.6),
	Color(0.95, 0.8, 0.25), Color(0.15, 0.15, 0.18), Color(0.9, 0.9, 0.88), Color(0.25, 0.6, 0.7), Color(0.85, 0.45, 0.6)]
const EARTH := [Color(0.48, 0.38, 0.28), Color(0.55, 0.42, 0.3), Color(0.4, 0.34, 0.26), Color(0.5, 0.25, 0.18), Color(0.35, 0.33, 0.25),
	Color(0.6, 0.5, 0.32), Color(0.3, 0.26, 0.22), Color(0.45, 0.2, 0.15)]
## Haydutların uyumsuz, solgun ama farklı renkleri
const RAGS := [Color(0.55, 0.18, 0.15), Color(0.32, 0.4, 0.25), Color(0.28, 0.33, 0.45), Color(0.6, 0.5, 0.32), Color(0.45, 0.45, 0.42),
	Color(0.5, 0.25, 0.4), Color(0.7, 0.55, 0.3), Color(0.2, 0.2, 0.22), Color(0.48, 0.38, 0.28), Color(0.62, 0.35, 0.2)]
const SOFT := [Color(0.5, 0.6, 0.45), Color(0.6, 0.35, 0.3), Color(0.8, 0.75, 0.55), Color(0.4, 0.45, 0.6), Color(0.7, 0.55, 0.65),
	Color(0.85, 0.85, 0.85), Color(0.55, 0.3, 0.45), Color(0.9, 0.6, 0.3), Color(0.35, 0.5, 0.55), Color(0.75, 0.68, 0.5), Color(0.62, 0.42, 0.5)]
const KIMONO := [Color(0.25, 0.3, 0.55), Color(0.65, 0.2, 0.3), Color(0.3, 0.45, 0.35), Color(0.85, 0.65, 0.75), Color(0.5, 0.35, 0.6),
	Color(0.9, 0.85, 0.75), Color(0.75, 0.45, 0.2), Color(0.2, 0.2, 0.25)]


static func _p(a: Array):
	return a[randi() % a.size()]


static func _ch(p: float) -> bool:
	return randf() < p


## Tüm kıyafet anahtarlarını sıfırlayan temel (önceki rol görünümü sızmasın)
static func _blank() -> Dictionary:
	return {"vest": null, "vest_style": 0, "outer_style": null, "outer": null, "outer_pattern": 0, "outer_accent": null, "head_style": null, "headgear": null,
		"face_style": null, "facegear": null, "mask": null, "cloak": null, "guards": null, "acc": null, "back_item": null, "backc": null, "gloves": false, "arm_wraps": false,
		"hakama": false, "wear": 0.0, "rope_belt": false, "top_pattern": 0, "foot_style": "sandal", "band": null, "band_style": "none"}


static func roll(arch: String, village := "") -> Dictionary:
	if village == "" or not VILLAGE.has(village):
		village = "konoha" if village == "" else village
	var V: Dictionary = VILLAGE.get(village, VILLAGE["konoha"])
	var L = _blank()
	L["village"] = village
	match arch:
		"genin", "kid", "student":
			var t: Color = _p(VIVID)
			L["top_style"] = _p(["uzun", "tisort", "ceket", "ceket", "yakali", "kolsuz", "gi", "tek_kol", "yakali_uzun"])
			L["top"] = t; L["top2"] = _p(VIVID) if _ch(0.6) else t.darkened(0.3)
			L["top_pattern"] = _p([0, 0, 0, 2, 3, 3, 5, 6])
			L["pants"] = _p([Color(0.15, 0.15, 0.17), Color(0.2, 0.25, 0.4), Color(0.3, 0.3, 0.33), Color(0.35, 0.3, 0.25), t.darkened(0.45)])
			L["pants_style"] = _p(["ninja", "sort", "sort", "kapri", "kisa_sort", "bol"])
			L["foot_style"] = _p(["sandal", "sandal", "yuksek_sandal", "tabi"])
			L["sandal"] = _p([Color(0.15, 0.2, 0.32), Color(0.12, 0.12, 0.14), Color(0.35, 0.3, 0.28)])
			if arch == "genin":
				L["band"] = V["band"]; L["band_style"] = _p(["head", "head", "head", "neck", "bandana"]) if arch == "genin" else "none"
				if L["band_style"] == "bandana":
					L["head_style"] = "bandana"; L["headgear"] = V["band"]; L["band_style"] = "none"
				L["arm_wraps"] = _ch(0.3); L["gloves"] = _ch(0.25)
				L["back_item"] = _p([null, null, "kemer", "kemer_canta", "parsomen", "atki"])
				if L["back_item"] == "atki":
					L["back_item"] = null; L["outer_style"] = "atki"; L["outer"] = _p(VIVID)
				L["backc"] = Color(0.32, 0.26, 0.18)
			elif _ch(0.25):
				L["face_style"] = "goggles"; L["facegear"] = _p(VIVID)
		"chunin", "guard", "jonin", "hunter":
			var b: Color = _p(V["base"])
			L["top"] = b; L["top2"] = b; L["pants"] = b
			L["top_style"] = "uzun"
			if village == "kumo":
				L["top_style"] = _p(["uzun", "tek_kol", "kolsuz"])
			elif village == "suna" and _ch(0.3):
				L["top_style"] = "yakali_uzun"
			L["pants_style"] = _p(["ninja", "ninja", "ninja", "sargi"])
			L["vest"] = V["vest"]; L["vest_style"] = V["vs"]
			if V["vest"] == null:
				L["rope_belt"] = true; L["top_style"] = "yakali_uzun"
			L["band"] = V["band"]; L["band_style"] = _p(["head", "head", "head", "head", "neck"])
			if _ch(0.18):
				L["head_style"] = "bandana"; L["headgear"] = V["band"]; L["band_style"] = "none"
			L["sandal"] = _p([Color(0.15, 0.2, 0.32), Color(0.12, 0.12, 0.14)])
			L["foot_style"] = _p(["sandal", "sandal", "sandal", "tabi"])
			L["guards"] = _p([null, null, "kol", "bacak", "ikisi"]) if arch != "guard" else _p(["kol", "ikisi"])
			L["acc"] = Color(0.55, 0.58, 0.62)
			L["gloves"] = _ch(0.3)
			L["back_item"] = _p([null, "kemer", "kemer_canta", "parsomen", "bel_parsomen", "kin"])
			L["backc"] = _p([Color(0.32, 0.26, 0.18), Color(0.85, 0.78, 0.6)])
			if village == "suna" and _ch(0.35):
				L["head_style"] = "sarik"; L["headgear"] = Color(0.85, 0.76, 0.58)
				if _ch(0.5):
					L["face_style"] = "pece"; L["facegear"] = Color(0.82, 0.74, 0.58)
			if village == "kiri" and _ch(0.3):
				L["face_style"] = "cloth"; L["facegear"] = Color(0.2, 0.22, 0.28)
			if village == "ame" and _ch(0.5):
				L["outer_style"] = _p(["panco", "mino"]); L["outer"] = Color(0.35, 0.37, 0.42)
			if arch == "jonin":
				# jōnin: daha ağır teçhizat, bazen uzun haori / maske / koyu yelek
				L["gloves"] = _ch(0.6)
				if _ch(0.3):
					L["face_style"] = "cloth"; L["facegear"] = b.darkened(0.3)
				if _ch(0.25):
					L["outer_style"] = _p(["haori_uzun", "haori", "kisa"]); L["outer"] = _p([Color(0.42, 0.36, 0.3), Color(0.3, 0.38, 0.3), b.darkened(0.2)])   # beyaz + alev etek yalnız Kage'nin cübbesi
					L["outer_pattern"] = _p([0, 1]); L["outer_accent"] = _p([Color(0.75, 0.15, 0.12), V["band"]])
				if _ch(0.25):
					L["top_pattern"] = 1  # file ağ
			if arch == "hunter":
				L["face_style"] = _p(["anbu_kedi", "anbu_kurt", "anbu_kus"]); L["facegear"] = Color(0.95, 0.95, 0.94)
				L["outer_style"] = "kisa"; L["outer"] = b.darkened(0.2)
		"anbu", "kok":
			var dk = Color(0.1, 0.1, 0.13) if arch == "anbu" else Color(0.07, 0.07, 0.09)
			L["top"] = dk; L["top2"] = dk; L["pants"] = dk
			L["top_style"] = _p(["yakali_uzun", "kolsuz", "kolsuz"]) if arch == "anbu" else "yakali_uzun"
			L["pants_style"] = "ninja"
			L["vest"] = Color(0.78, 0.78, 0.8) if arch == "anbu" else Color(0.1, 0.1, 0.12)
			L["vest_style"] = 5 if arch == "anbu" else 7
			L["face_style"] = _p(["anbu_kedi", "anbu_kurt", "anbu_kus", "anbu_ayi", "anbu_tilki", "anbu_kaplan", "anbu_yilan", "anbu_maymun"]) if arch == "anbu" else "anbu_kus"
			L["facegear"] = Color(0.96, 0.96, 0.95) if arch == "anbu" else Color(0.88, 0.88, 0.86)
			L["guards"] = "ikisi"; L["acc"] = Color(0.8, 0.8, 0.82); L["gloves"] = true
			L["arm_wraps"] = arch == "kok"
			L["foot_style"] = "tabi"; L["sandal"] = Color(0.08, 0.08, 0.1)
			L["back_item"] = "kin"; L["backc"] = Color(0.12, 0.1, 0.1)
			if _ch(0.2):
				L["outer_style"] = "kisa"; L["outer"] = Color(0.15, 0.15, 0.18)
		"rogue":
			var b: Color = _p([Color(0.2, 0.2, 0.24), Color(0.3, 0.28, 0.26), Color(0.25, 0.22, 0.28), Color(0.18, 0.22, 0.2), Color(0.35, 0.15, 0.15)])
			L["top"] = b; L["top2"] = b.darkened(0.25); L["pants"] = _p([Color(0.18, 0.18, 0.2), b.darkened(0.3), Color(0.25, 0.22, 0.2)])
			L["top_style"] = _p(["uzun", "yakali", "yakali_uzun", "kolsuz", "tek_kol", "ceket"])
			L["top_pattern"] = _p([0, 0, 1, 4])
			L["pants_style"] = _p(["ninja", "sargi", "bol", "ninja"])
			L["band"] = V["band"].darkened(0.2); L["band_style"] = _p(["slashed", "slashed", "slashed", "neck"])
			L["wear"] = randf_range(0.35, 0.65)
			# eski köy yeleği, yıpranmış
			if _ch(0.35) and V["vest"] != null:
				L["vest"] = Color(V["vest"]).darkened(0.25); L["vest_style"] = V["vs"]
			elif _ch(0.3):
				L["vest"] = Color(0.32, 0.22, 0.14); L["vest_style"] = _p([9, 10])
			if _ch(0.55):
				L["outer_style"] = _p(["yirtik", "yirtik", "panco", "pelerin", "kisa", "org_pelerin"])
				L["outer"] = _p([Color(0.25, 0.22, 0.2), Color(0.18, 0.18, 0.2), Color(0.35, 0.3, 0.24), Color(0.3, 0.12, 0.12)])
				L["outer_pattern"] = 5 if L["outer_style"] != "org_pelerin" else 1
				L["outer_accent"] = Color(0.4, 0.12, 0.12)
			if _ch(0.35):
				L["head_style"] = _p(["kasa", "kapuson", "basortu", "hachimaki"]); L["headgear"] = _p([Color(0.48, 0.4, 0.28), Color(0.15, 0.15, 0.17), Color(0.4, 0.15, 0.12)])
			var fr = randf()
			if fr < 0.3:
				L["face_style"] = "cloth"; L["facegear"] = _p([Color(0.15, 0.15, 0.2), Color(0.4, 0.1, 0.1)])
			elif fr < 0.42:
				L["face_style"] = "goz_bandi"
			L["guards"] = _p([null, "kol", "omuz", "bacak", "ikisi"]); L["acc"] = Color(0.45, 0.47, 0.5)
			L["gloves"] = _ch(0.5); L["arm_wraps"] = _ch(0.4)
			L["foot_style"] = _p(["sandal", "cizme", "yuksek_sandal", "tabi"]); L["sandal"] = Color(0.18, 0.15, 0.12)
			L["back_item"] = _p([null, "kin", "ip_kangal", "canta", "sake", "shuriken"]); L["backc"] = Color(0.3, 0.24, 0.16)
		"bandit":
			var t: Color = _p(RAGS)
			L["top"] = t; L["top2"] = t.darkened(0.2)
			L["top_style"] = _p(["kolsuz", "atlet", "tisort", "uzun", "tek_kol", "kolsuz"])
			L["top_pattern"] = _p([4, 4, 4, 0, 2])
			L["pants"] = _p(RAGS).darkened(0.25)
			L["pants_style"] = _p(["sivil", "bol", "kapri", "bol", "kisa_sort"])
			L["wear"] = randf_range(0.55, 0.95)
			var vr = randf()
			if vr < 0.35:
				L["vest"] = Color(0.35, 0.24, 0.15); L["vest_style"] = 9
			elif vr < 0.55:
				L["vest"] = Color(0.42, 0.3, 0.2); L["vest_style"] = 10
			elif vr < 0.65:
				L["vest"] = Color(0.5, 0.52, 0.55); L["vest_style"] = 11
			var hr = randf()
			if hr < 0.45:
				L["head_style"] = "basortu"; L["headgear"] = _p([Color(0.55, 0.2, 0.15), Color(0.25, 0.3, 0.45), Color(0.6, 0.5, 0.3), Color(0.15, 0.15, 0.15)])
			elif hr < 0.6:
				L["head_style"] = "hachimaki"; L["headgear"] = _p([Color(0.85, 0.82, 0.75), Color(0.6, 0.15, 0.12)])
			elif hr < 0.72:
				L["head_style"] = "kasa"; L["headgear"] = Color(0.45, 0.38, 0.26)
			var fr = randf()
			if fr < 0.35:
				L["face_style"] = "cloth"; L["facegear"] = _p([Color(0.4, 0.3, 0.2), Color(0.15, 0.15, 0.15), Color(0.5, 0.15, 0.12)])
			elif fr < 0.5:
				L["face_style"] = "goz_bandi"
			L["guards"] = _p([null, null, "omuz", "dizlik", "kol", "bacak"]); L["acc"] = Color(0.4, 0.38, 0.36)
			L["arm_wraps"] = _ch(0.5); L["gloves"] = _ch(0.3)
			L["foot_style"] = _p(["cizme", "zori", "sandal", "cizme"]); L["sandal"] = Color(0.3, 0.22, 0.15); L["wraps"] = Color(0.75, 0.7, 0.6)
			L["back_item"] = _p([null, "ip_kangal", "sake", "canta", "kemer_canta"]); L["backc"] = _p([Color(0.7, 0.62, 0.45), Color(0.4, 0.3, 0.2)])
			if _ch(0.2):
				L["outer_style"] = "yirtik"; L["outer"] = Color(0.32, 0.27, 0.22); L["outer_pattern"] = 5
		"samurai":
			var lac: Color = _p([Color(0.55, 0.1, 0.1), Color(0.15, 0.15, 0.18), Color(0.2, 0.25, 0.4), Color(0.35, 0.22, 0.15)])
			L["top"] = _p([Color(0.22, 0.24, 0.3), Color(0.3, 0.3, 0.32), Color(0.85, 0.85, 0.8)]); L["top2"] = Color(0.85, 0.75, 0.45)
			L["top_style"] = _p(["kimono", "gi"])
			L["pants"] = _p([Color(0.2, 0.22, 0.28), Color(0.3, 0.28, 0.3)]); L["pants_style"] = "sivil"; L["hakama"] = true
			L["vest"] = lac; L["vest_style"] = 6
			if _ch(0.65):
				L["head_style"] = _p(["kabuto", "kabuto", "jingasa"]); L["headgear"] = lac.darkened(0.2)
			if _ch(0.45):
				L["face_style"] = "mempo"; L["facegear"] = lac.darkened(0.3)
			L["guards"] = _p(["agir", "kol", "ikisi", "omuz"]); L["acc"] = lac.lightened(0.1)
			L["gloves"] = true
			L["foot_style"] = _p(["cizme", "tabi"]); L["sandal"] = Color(0.12, 0.1, 0.1)
			L["back_item"] = _p([null, "sashimono", "kin", null]); L["backc"] = _p([Color(0.85, 0.85, 0.82), lac])
			if _ch(0.3):
				L["outer_style"] = "jinbaori"; L["outer"] = _p([Color(0.15, 0.15, 0.22), Color(0.85, 0.82, 0.75)]); L["outer_pattern"] = 1; L["outer_accent"] = Color(0.85, 0.68, 0.25)
		"akatsuki", "org":
			L["top"] = Color(0.12, 0.12, 0.14); L["top2"] = Color(0.12, 0.12, 0.14); L["pants"] = Color(0.12, 0.12, 0.14)
			L["top_style"] = "yakali_uzun"; L["pants_style"] = "ninja"
			L["outer_style"] = "org_pelerin"; L["outer"] = Color(0.13, 0.14, 0.26) if arch == "akatsuki" else Color(0.05, 0.05, 0.07)   # Akatsuki: oyuncu setiyle aynı lacivert
			L["outer_pattern"] = 6 if arch == "akatsuki" else 3
			L["outer_accent"] = Color(0.72, 0.07, 0.14) if arch == "akatsuki" else Color(0.78, 0.08, 0.1)
			L["band"] = V["band"]; L["band_style"] = "slashed"
			if _ch(0.25):
				L["head_style"] = "kasa"; L["headgear"] = Color(0.78, 0.66, 0.42)
			L["foot_style"] = "sandal"; L["sandal"] = Color(0.3, 0.3, 0.35)
			L["gloves"] = _ch(0.3)
		"monk":
			L["top"] = Color(0.9, 0.55, 0.15); L["top2"] = Color(0.7, 0.35, 0.1); L["top_style"] = "gi"
			L["pants"] = Color(0.85, 0.8, 0.7); L["pants_style"] = _p(["sivil", "bol"])
			var mr = randf()
			if mr < 0.5:
				L["outer_style"] = "kesa"; L["outer"] = _p([Color(0.85, 0.45, 0.12), Color(0.65, 0.2, 0.12)])
			else:
				L["outer_style"] = "cuppe"; L["outer"] = _p([Color(0.3, 0.28, 0.35), Color(0.25, 0.25, 0.25)]); L["outer_pattern"] = 1; L["outer_accent"] = Color(0.9, 0.55, 0.15)
			if _ch(0.4):
				L["head_style"] = "tengai"; L["headgear"] = Color(0.72, 0.6, 0.38)
			L["back_item"] = "tespih"; L["backc"] = Color(0.35, 0.22, 0.12)
			L["foot_style"] = "zori"; L["sandal"] = Color(0.78, 0.68, 0.45)
			L["rope_belt"] = _ch(0.5)
		"farmer":
			var t: Color = _p(EARTH + SOFT)
			L["top"] = t; L["top2"] = t.darkened(0.15); L["top_style"] = _p(["tisort", "uzun", "atlet", "gi"])
			L["top_pattern"] = _p([0, 4, 4])
			L["pants"] = _p([Color(0.35, 0.3, 0.28), Color(0.25, 0.28, 0.38)]); L["pants_style"] = _p(["kapri", "sivil", "bol"])
			L["wear"] = randf_range(0.2, 0.45)
			if _ch(0.65):
				L["head_style"] = "kasa"; L["headgear"] = Color(0.78, 0.66, 0.42)
			if _ch(0.2):
				L["outer_style"] = "mino"; L["outer"] = Color(0.68, 0.58, 0.36); L["outer_pattern"] = 4
			L["back_item"] = _p([null, "sepet", "sepet"]); L["backc"] = Color(0.7, 0.58, 0.35)
			L["foot_style"] = "zori"; L["sandal"] = Color(0.78, 0.68, 0.45); L["arm_wraps"] = _ch(0.3)
		"worker":
			var t: Color = _p(EARTH)
			L["top"] = t; L["top2"] = t; L["top_style"] = _p(["atlet", "tisort", "tisort"])
			L["pants"] = Color(0.3, 0.27, 0.24); L["pants_style"] = _p(["kapri", "bol", "sivil"])
			L["wear"] = 0.3
			L["head_style"] = _p(["hachimaki", "hachimaki", "basortu"]); L["headgear"] = Color(0.9, 0.88, 0.85)
			L["gloves"] = _ch(0.4); L["arm_wraps"] = _ch(0.4)
			L["foot_style"] = _p(["zori", "cizme"]); L["sandal"] = Color(0.3, 0.22, 0.15)
			L["back_item"] = _p([null, "ip_kangal", "kemer_canta"]); L["backc"] = Color(0.6, 0.5, 0.35)
		"merchant":
			var t: Color = _p(KIMONO)
			L["top"] = t; L["top2"] = _p(KIMONO); L["top_style"] = _p(["kimono", "uzun", "kimono"]); L["top_pattern"] = _p([0, 6, 2])
			L["pants"] = _p([Color(0.25, 0.22, 0.2), Color(0.3, 0.3, 0.35)]); L["pants_style"] = "sivil"; L["hakama"] = _ch(0.3)
			if _ch(0.45):
				L["outer_style"] = "haori"; L["outer"] = _p([Color(0.15, 0.15, 0.2), Color(0.35, 0.25, 0.18), Color(0.25, 0.3, 0.22)])
			if _ch(0.3):
				L["head_style"] = "kasa"; L["headgear"] = Color(0.78, 0.66, 0.42)
			L["back_item"] = _p([null, "sepet", "canta", "sake"]); L["backc"] = Color(0.7, 0.58, 0.35)
			L["foot_style"] = "zori"; L["sandal"] = Color(0.3, 0.22, 0.15)
		"noble":
			var t: Color = _p([Color(0.55, 0.12, 0.15), Color(0.2, 0.25, 0.5), Color(0.4, 0.15, 0.45), Color(0.9, 0.88, 0.82)])
			L["top"] = t; L["top2"] = Color(0.85, 0.7, 0.3); L["top_style"] = "kimono"; L["top_pattern"] = 6
			L["pants"] = t.darkened(0.35); L["pants_style"] = "sivil"; L["hakama"] = true
			L["outer_style"] = _p(["haori", "haori_uzun"]); L["outer"] = _p([Color(0.12, 0.12, 0.15), Color(0.85, 0.82, 0.75)]); L["outer_pattern"] = 1; L["outer_accent"] = Color(0.85, 0.7, 0.3)
			L["foot_style"] = "tabi"; L["sandal"] = Color(0.95, 0.95, 0.92)
		"medic":
			L["top"] = Color(0.96, 0.96, 0.97); L["top2"] = Color(0.85, 0.2, 0.2); L["top_style"] = _p(["uzun", "yakali_uzun"]); L["top_pattern"] = 6
			L["pants"] = Color(0.9, 0.9, 0.92); L["pants_style"] = "ninja"
			L["band"] = V["band"]; L["band_style"] = "head"
			L["foot_style"] = "sandal"; L["sandal"] = Color(0.85, 0.85, 0.88)
			L["back_item"] = "kemer_canta"; L["backc"] = Color(0.85, 0.85, 0.88)
		"elder":
			var t: Color = _p([Color(0.35, 0.3, 0.28), Color(0.3, 0.35, 0.3), Color(0.45, 0.38, 0.3), Color(0.25, 0.25, 0.35)])
			L["top"] = t; L["top2"] = t.darkened(0.2); L["top_style"] = _p(["kimono", "kimono", "uzun"])
			L["pants"] = t.darkened(0.3); L["pants_style"] = "sivil"; L["hakama"] = _ch(0.5)
			if _ch(0.5):
				L["outer_style"] = "haori"; L["outer"] = _p([Color(0.2, 0.2, 0.22), Color(0.4, 0.32, 0.24)])
			if _ch(0.3):
				L["head_style"] = "kasa"; L["headgear"] = Color(0.7, 0.6, 0.4)
			L["foot_style"] = "zori"; L["sandal"] = Color(0.78, 0.68, 0.45)
		"traveler":
			var t: Color = _p(EARTH + SOFT)
			L["top"] = t; L["top2"] = t.darkened(0.2); L["top_style"] = _p(["uzun", "tunik", "gi", "uzun"])
			if L["top_style"] == "tunik":
				L["top_style"] = "uzun"; L["top_pattern"] = 6
			L["pants"] = _p([Color(0.35, 0.3, 0.28), Color(0.3, 0.3, 0.33)]); L["pants_style"] = _p(["sivil", "bol", "kapri"])
			L["outer_style"] = _p(["pelerin", "panco", "mino", "pelerin", null]); L["outer"] = _p([Color(0.4, 0.32, 0.24), Color(0.5, 0.42, 0.3), Color(0.3, 0.32, 0.3)])
			L["outer_pattern"] = 4 if L["outer_style"] == "mino" else _p([0, 1])
			L["outer_accent"] = _p([Color(0.7, 0.3, 0.15), Color(0.25, 0.35, 0.55)])
			L["head_style"] = _p(["kasa", "kasa", "kapuson", null]); L["headgear"] = Color(0.78, 0.66, 0.42) if L["head_style"] == "kasa" else Color(0.35, 0.3, 0.25)
			L["back_item"] = _p(["canta", "sepet", "sake", "canta"]); L["backc"] = Color(0.45, 0.35, 0.22)
			L["foot_style"] = _p(["zori", "sandal", "cizme"]); L["sandal"] = Color(0.35, 0.25, 0.15)
		"sennin":
			L["top"] = Color(0.3, 0.45, 0.3); L["top2"] = Color(0.2, 0.3, 0.2); L["top_style"] = "gi"
			L["pants"] = Color(0.3, 0.45, 0.3); L["pants_style"] = "bol"
			L["outer_style"] = "haori_uzun"; L["outer"] = Color(0.88, 0.2, 0.15); L["outer_pattern"] = 2; L["outer_accent"] = Color(0.98, 0.85, 0.3)
			L["back_item"] = "parsomen"; L["backc"] = Color(0.85, 0.78, 0.6)
			L["foot_style"] = "yuksek_sandal"
			L["band"] = V["band"]; L["band_style"] = "head"
		_:  # civ: sivil halk, çok çeşitli
			var r = randf()
			var t: Color = _p(SOFT)
			L["top"] = t; L["top2"] = t.darkened(0.12)
			if r < 0.3:
				L["top_style"] = "kimono"; L["top"] = _p(KIMONO); L["top2"] = _p(KIMONO); L["top_pattern"] = _p([0, 2, 6])
				L["hakama"] = _ch(0.2)
			else:
				L["top_style"] = _p(["uzun", "tisort", "tisort", "gi", "atlet", "uzun"]); L["top_pattern"] = _p([0, 0, 0, 2, 6, 4])
			L["pants"] = _p([Color(0.35, 0.3, 0.28), Color(0.2, 0.22, 0.3), Color(0.4, 0.35, 0.25), Color(0.3, 0.3, 0.33)])
			L["pants_style"] = _p(["sivil", "sivil", "kapri", "bol", "kisa_sort"])
			L["foot_style"] = _p(["zori", "zori", "sandal"]); L["sandal"] = _p([Color(0.3, 0.22, 0.15), Color(0.78, 0.68, 0.45)])
			if _ch(0.15):
				L["head_style"] = _p(["kasa", "hachimaki", "basortu"]); L["headgear"] = _p([Color(0.78, 0.66, 0.42), Color(0.9, 0.88, 0.85), Color(0.3, 0.35, 0.5)])
			if _ch(0.15):
				L["outer_style"] = _p(["haori", "atki", "kisa"]); L["outer"] = _p(SOFT)
			if _ch(0.12):
				L["back_item"] = _p(["sepet", "canta", "sake"]); L["backc"] = Color(0.6, 0.5, 0.35)
	# köy ninjaları (chūnin/jōnin/muhafız) oyuncuyla aynı köy setlerini giyer; köylüler ve diğerleri aynı kalır
	if arch in ["chunin", "guard", "jonin", "hunter"] and village in ["konoha", "suna", "kiri", "kumo", "iwa"]:
		var vk = {"konoha": "", "suna": "suna_", "kiri": "kiri_", "kumo": "kumo_", "iwa": "iwa_"}[village]
		var sid = "set_%s%s" % [vk, "jonin" if arch in ["jonin", "hunter"] else "chunin"]
		for k in ["guards", "guard_stripes", "knee_wraps", "pants_flap", "gloves", "outer_style", "rope_belt"]:
			L[k] = null if not k in ["knee_wraps", "gloves", "rope_belt"] else false
		L["outer_style"] = null
		Gear.preview_set_look(L, sid)
		L["set_id"] = sid   # set bonusları (element güç/direnç) AI'da da
		L["thigh_holster"] = true
	_npc_band_wear(L, arch, village)
	_npc_face_paint(L, arch)
	L["sleeves"] = not L.get("top_style", "uzun") in ["tisort", "kolsuz", "atlet"]
	if L.get("top_style", "") in ["kimono"] and L["top_pattern"] == 0 and _ch(0.3):
		L["top_pattern"] = 6
	if arch == "anbu":
		return anbu_wear(L)
	return L


## ANBU oyundaki gerçek ANBU takımlarını giyer (2026-11-27, kullanıcı: "bir sürü ANBU kıyafeti var, hiçbirini kullanmıyorlar"):
## Gece / Yami / Kasumi / Wakate, takım başı Kaptan. Maske ve kimlik korunur; kimlik anahtarı yoksa eklenmez (çağıranlar bu
## sözlüğü kişinin görünüşüyle birleştiriyor: saç / ten ezilmesin)
const ANBU_WEAR := ["set_anbu_konoha", "set_anbu_konoha", "set_anbu_yami", "set_anbu_kasumi", "set_anbu_wakate"]


static func anbu_wear(L: Dictionary, captain := false) -> Dictionary:
	var pool: Array = ANBU_WEAR.filter(func(sid): return not Gear.item(sid).is_empty() and not (Gear.item(sid).get("parts", []) as Array).is_empty())
	var sid := "set_anbu_kaptan" if captain and not Gear.item("set_anbu_kaptan").is_empty() else (String(_p(pool)) if not pool.is_empty() else "")
	if sid == "":
		return L
	var out := wear_set(L, sid)
	for k in LOOK_SELF:
		if not L.has(k):
			out.erase(k)
	out["face_style"] = L.get("face_style")
	out["facegear"] = L.get("facegear")
	out["village"] = L.get("village")
	return out


## NPC alın koruyucusunun takılışı: çoğu alında; kalanı köyün/rütbenin anime tarzlarından (oyuncunun Takılış seçenekleriyle aynı)
## Suna: Kankurō kapüşonu, Baki peçesi, Gaara kuşağı; Kiri: Zabuza, Kisame; Konoha: Yamato, Neji, Chōji, Shikamaru kolu, Ino beli;
## kaçak: Kakashi eğik, Zabuza, Kisame, Kakuzu; kadınlarda saç bandı/bel; nadir: Tobirama, Jiraiya, Hiruzen miğferi (yalnız jōnin+)
## Sıradan NPC nadiren yüz boyası taşır (klanınki ClanWorld.clan_look'ta: Inuzuka dişleri, Akimichi sarmalı...).
## Klan boyaları ve kostüm gibi yüzü kaplayanlar (İblis, Uçurtma, Balkabağı, Kahraman maskesi) sıradan NPC'de çıkmaz.
const NPC_PAINT_SKIP := ["fp1", "fp2", "fp13", "fp9", "x20", "x46", "x40", "x22", "x19", "x6", "x5", "x37", "x38", "x41", "x7", "x68"]
static func _npc_face_paint(L: Dictionary, arch: String) -> void:
	var p = 0.05 if arch in ["genin", "chunin", "jonin", "hunter", "guard", "rogue", "kid", "student"] else 0.025
	if not _ch(p):
		return
	var pool = CharacterModel.FACE_PAINTS.keys().filter(func(k): return k != "yok" and not k in NPC_PAINT_SKIP)
	L["face_paint"] = _p(pool)


static func _npc_band_wear(L: Dictionary, arch: String, village: String) -> void:
	if L.get("band") == null or not String(L.get("band_style", "none")) in ["head", "slashed"]:
		return
	if _ch(0.68):
		L["band_wear"] = "alin"
		return
	var pool = ["kakashi", "kol", "neji", "sakura", "sakura", "bel", "choji"]   # cinsiyet burada bilinmez: erkekte saç bandı CharacterModel'de alına döner
	if String(L.get("band_style")) == "slashed":
		pool = ["kakashi", "zabuza", "zabuza", "kisame", "kakuzu", "kol"]
	else:
		match village:
			"suna":
				pool.append_array(["kankuro", "kankuro", "baki", "baki", "kusak", "kusak"])
			"kiri":
				pool.append_array(["zabuza", "zabuza", "kisame", "kisame"])
			"konoha":
				pool.append_array(["yamato", "neji", "choji", "kol"])
			"kumo", "iwa":
				pool.append_array(["kol", "bel", "kusak"])
		if arch in ["jonin", "hunter"]:
			pool.append_array(["tobirama", "yamato"] if village == "konoha" else ["tobirama"])
			if _ch(0.08):
				pool = ["jiraiya", "hiruzen"] if village == "konoha" else ["hiruzen"]
	L["band_wear"] = _p(pool)


## Köy ninjasına köyünün GERÇEK chūnin/jōnin setini giydirir (yelek modeli, üst/alt, koruyucular).
## Eskiden birçok yer yalnız L["vest"] = köy rengi yazıyordu: model Konoha yeleği kalıyordu (kullanıcı: "Kumo chūnini Konoha kıyafeti").
const MINOR_UNIFORM := {"kusa": "set_kusa", "taki": "set_taki", "yu": "set_yu", "shimo": "set_shimo", "tani": "set_tani", "ame": "set_ame", "oto": "set_oto"}


static func has_uniform(vid: String) -> bool:
	return vid in ["konoha", "suna", "kiri", "kumo", "iwa"] or MINOR_UNIFORM.has(vid)


## Sinematik / tören kalabalığı: rütbeli ninja köyünün gerçek üniformasını giyer (dünyadaki NPC'lerle aynı set; eskiden kabuk
## yelekle Konoha kalıbında giyiniyordu)
static func uniform(arch: String, vid: String) -> Dictionary:
	var L := roll(arch, vid)
	if arch in ["chunin", "jonin", "guard"] and has_uniform(vid):
		village_set(L, vid, arch == "jonin")
	return L


static func village_set(L: Dictionary, vid := "", jonin := false) -> void:
	if vid == "":
		vid = String(L.get("village", Progress.home()))
	var vk = {"konoha": "", "suna": "suna_", "kiri": "kiri_", "kumo": "kumo_", "iwa": "iwa_"}
	if vk.has(vid) or MINOR_UNIFORM.has(vid):
		var sid = String(MINOR_UNIFORM[vid]) if MINOR_UNIFORM.has(vid) else "set_%s%s" % [vk[vid], "jonin" if jonin else "chunin"]
		# görünüm önce sıfırlanır (wear_set): eskiden setin parçaları önceki görünümün üstüne yazılıyordu; Konoha tarzı yeleğin
		# ekleri (yaka, cepler, etek) Suna / Kiri setinin altından taşıyordu (iç içe kıyafet)
		var clean := wear_set(L, sid)
		L.clear()
		L.merge(clean, true)
	else:
		L["vest"] = Progress.HOME_VILLAGES.get(vid, Progress.HOME_VILLAGES["konoha"])["vest"]


## Kayda (JSON) girecek görünümler için: renkler html dizesi
static func roll_hex(arch: String, village := "") -> Dictionary:
	var L = roll(arch, village)
	for k in L:
		if L[k] is Color:
			L[k] = (L[k] as Color).to_html(false)
	return L


## Oyuncunun bulunduğu (ya da verilen konuma) en yakın köy
static func village_near(pos = null) -> String:
	if pos == null:
		pos = Game.player.global_position if Game.player and is_instance_valid(Game.player) else null
	if pos == null or Game.world_info.is_empty():
		return "konoha"
	var m = Game.to_map(pos)
	var best = "konoha"
	var bd = 1e18
	for v in Game.world_info.get("villages", []):
		var d = Vector2(v["x"], v["y"]).distance_squared_to(m)
		if d < bd:
			bd = d; best = String(v["id"])
	return best if VILLAGE.has(best) else "konoha"


# ------------------------------------------------------------------ kaçak ninjaların setleri
## Kaçak ninja, karakterine uyan gerçek bir kıyafet seti giyer (oyuncunun gardırobundaki setlerle aynı): önce klanının,
## sonra kan soyunun / doğasının, sonra eski köyünün setleri; hiçbiri yoksa pelerinli / gezgin kaçak setleri.
## Plaj, pijama, eşofman, gelinlik, okul, kostüm gibi setler bu listelerde YOK (kaçağa yakışmaz).
const ROGUE_CLAN := {
	"uchiha": ["set_uchiha", "ss_yelpaze", "ss_yelpaze_kolsuz", "ss_yelpaze_takim", "ss_yelpaze_b", "ss_yelpaze_yirtik", "ss_yelpaze_kilic", "ss_yelpaze_zirh",
		"ss_kizil_fermuar", "ss_kizil_elbise", "ss_karga_tunik", "ss_karga_cubbe", "ss_savas_reisi3", "ss_savas_reisi"],
	"inuzuka": ["ss_inuzuka_ceket"], "nara": ["ss_golge_jonin", "ss_golge_genc"], "akimichi": ["ss_kizil_zirh", "ss_yemek"],
	"hyuga": ["ss_kader_genc", "ss_mor_uzun", "ss_mor_etek"], "sabaku": ["ss_kizil_palto", "ss_kizil_palto2", "ss_demir_kum", "ss_ruzgar_kimono", "ss_ruzgar_zirh", "ss_ruzgar_elbise2"],
	"shirogane": ["ss_kukla", "ss_kukla_genc", "ss_kizil_palto"], "momochi": ["ss_iblis"], "kurosuki": ["ss_iblis", "ss_kiri_genin"],
	"yuki": ["ss_buz_kimono", "ss_buz_kimono2"], "uzumaki": ["ss_turuncu_maske", "ss_kagit_melek"], "senju": ["ss_orman_zirh", "ss_orman_zirh_genc", "ss_su_zirh", "ss_kumarbaz"],
	"sarutobi": ["ss_sigara_jonin", "ss_ates_pelerin"], "hatake": ["ss_maskeli_gaiden", "ss_maskeli_jonin", "ss_ic_giysi"], "namikaze": ["ss_sari_simsek", "ss_sari_simsek_genc"],
	"yotsuki": ["set_kumo_uta"], "kaguya": ["set_kaguya", "ss_yilan_kimono"], "yuhi": ["set_genso"], "mitarashi": ["ss_tehlike_ceket"], "shimura": ["ss_kok_reisi", "set_ne"],
	"karatachi": ["set_kiri_atki"], "terumi": ["ss_su_elbise"], "tsuchigumo": ["set_awa"], "aburame": ["set_aburame", "set_anbu_byakue"], "gekko": ["set_kenshi"],
	"hozuki": ["ss_su_zirh", "ss_iblis"], "hoshigaki": ["ss_iblis", "ss_kiri_genin"], "jugo": ["ss_kabuk_yirtik"], "fuma": ["set_kage_no"]}
const ROGUE_NAT := {"hyoton": ["ss_buz_kimono", "ss_buz_kimono2"], "yoton": ["set_yogan"], "futton": ["set_joki"], "jiton": ["ss_demir_kum"], "mokuton": ["ss_orman_zirh"],
	"shakuton": ["ss_ates_pelerin"], "ranton": ["ss_simsek_kiyafet"]}
const ROGUE_EL := {"katon": ["ss_ates_pelerin"], "raiton": ["ss_simsek_kiyafet"], "suiton": ["ss_su_zirh"], "fuuton": ["ss_ruzgar_elbise2"], "doton": ["ss_kaya_paltosu"]}
const ROGUE_VILLAGE := {"konoha": ["ss_konoha_genin", "ss_son_savas"], "suna": ["ss_suna_genin", "ss_kum_striker", "set_suna"], "kiri": ["ss_kiri_genin", "ss_sis_striker_siyah", "ss_iblis"],
	"kumo": ["ss_kumo_genin", "set_kumo_uta"], "iwa": ["ss_iwa_genin", "ss_kaya_paltosu", "ss_kaya_striker"], "oto": ["ss_yilan_zirh", "ss_yilan_kimono", "ss_yilan_sanin", "ss_flut"],
	"ame": ["set_ame"]}
const ROGUE_ANY := ["set_oto", "set_oto", "set_anbu_byakue", "ss_kara_palto", "ss_karga_cubbe", "ss_maske_pelerin", "ss_kurucu_palto", "ss_gezgin_palto", "ss_kabuk_yirtik", "ss_bes_kalp", "ss_yilan_cubbe",
	"ss_kizil_kayis", "ss_siyah_tulum", "ss_genis_yaka", "set_ronin", "set_tabibito", "set_kage_no", "set_kenshi"]
## Görünüşün kimlik kısmı (set giyilince korunur)
const LOOK_SELF := ["gender", "hair", "hair_style", "skin", "eye", "face", "face_id", "face_cut", "face_v", "eye_art", "beard", "face_mark", "face_paint", "face_paint_col",
	"keep_hair", "own_hair", "age", "years", "age_seed", "fat", "mus", "band", "band_style", "band_wear", "village", "eye_l", "eye_r", "size"]


static func _fits(sid: String, female: bool) -> bool:
	var it: Dictionary = Gear.item(sid)
	if it.is_empty() or (it.get("parts", []) as Array).is_empty():
		return false
	var sx = String(it.get("sex", ""))
	return sx == "" or sx == ("f" if female else "m")


## Kişinin verisinden (klan, kan soyu, doğa, köy, cinsiyet) setini seçer; aynı kişi hep aynı seti alır (tohum = kimliği)
static func rogue_set(clan: String, village: String, els: Array, nat: Array, female: bool, seed_s: String) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(seed_s)
	var pools: Array = []   # [ağırlık, liste]
	pools.append([6.0, ROGUE_CLAN.get(clan, [])])
	var nl: Array = []
	for n in nat:
		nl.append_array(ROGUE_NAT.get(String(n), []))
	pools.append([3.0, nl])
	var el_l: Array = []
	for e in els:
		el_l.append_array(ROGUE_EL.get(String(e), []))
	pools.append([1.0, el_l])
	pools.append([2.0, ROGUE_VILLAGE.get(village, [])])
	pools.append([2.0, ROGUE_ANY])
	var tot := 0.0
	var ok: Array = []
	for pw in pools:
		var lst: Array = (pw[1] as Array).filter(func(s): return _fits(String(s), female))
		if not lst.is_empty():
			ok.append([float(pw[0]), lst])
			tot += float(pw[0])
	if ok.is_empty():
		return ""
	var r = rng.randf() * tot
	for pw in ok:
		r -= float(pw[0])
		if r <= 0.0:
			return String((pw[1] as Array)[rng.randi() % (pw[1] as Array).size()])
	return String((ok[-1][1] as Array)[0])


## Türüne göre kanon kıyafet: kim giyer (klan, köy, rütbe 0 genin .. 3 jōnin), kişilerin ne kadarı. Striker setleri burada YOK (kullanıcı reddetti).
const TYPE_WEAR := [
	{"set": "set_aburame", "clan": "aburame", "rank": 0, "p": 0.8},
	{"set": "set_kaguya", "clan": "kaguya", "rank": 0, "p": 0.7},
	{"set": "set_keimu", "clan": "uchiha", "village": "konoha", "rank": 1, "p": 0.45},
	{"set": "set_shugonin", "village": "konoha", "rank": 3, "p": 0.05},
	{"set": "set_uzumaki_haha", "clan": "uzumaki", "rank": 0, "p": 0.2},
	{"set": "set_sansho", "village": "ame", "rank": 3, "p": 0.25},
	{"set": "set_kumo_uta", "village": "kumo", "rank": 3, "p": 0.12},
	{"set": "set_kumo_kenshi", "village": "kumo", "rank": 2, "p": 0.15},
	{"set": "set_kumo_kunoichi", "village": "kumo", "rank": 2, "p": 0.3},
	{"set": "set_aogiri", "village": "kiri", "rank": 3, "p": 0.12},
	{"set": "set_iwa_kunoichi", "village": "iwa", "rank": 2, "p": 0.3},
	{"set": "set_kuro_iryo", "rank": 2, "p": 0.03},
	{"set": "set_tetsu_sho", "village": "tetsu", "rank": 2, "p": 0.5},
	{"set": "set_uzushio_hime", "clan": "uzumaki", "rank": 1, "p": 0.2},
	{"set": "set_taka_kenshi", "clan": "hozuki", "rank": 1, "p": 0.4},
	{"set": "set_kurosuki", "clan": "kurosuki", "rank": 0, "p": 0.6},
	{"set": "set_nidaime_koromo", "village": "kiri", "rank": 3, "p": 0.08},
	{"set": "set_kiri_atki", "village": "kiri", "rank": 3, "p": 0.1},
	{"set": "set_kiri_kenshi", "village": "kiri", "rank": 2, "p": 0.15},
	{"set": "set_kiri_kunoichi", "village": "kiri", "rank": 2, "p": 0.25},
	{"set": "set_kumo_kyodai", "village": "kumo", "rank": 3, "p": 0.08},
	{"set": "set_suna_rojo", "village": "suna", "rank": 3, "p": 0.15},
	{"set": "set_kazekiri", "village": "suna", "rank": 3, "p": 0.15},
	{"set": "set_shakunetsu", "village": "suna", "rank": 2, "p": 0.25},
	{"set": "set_yogan", "village": "iwa", "rank": 3, "p": 0.15},
	{"set": "set_awa", "village": "kiri", "rank": 1, "p": 0.06},
	{"set": "set_nanao", "village": "taki", "rank": 1, "p": 0.35},
	{"set": "set_nekomata", "village": "kumo", "rank": 2, "p": 0.2},
	{"set": "set_genso", "village": "konoha", "rank": 2, "p": 0.12},
	{"set": "set_yamanaka", "clan": "yamanaka", "rank": 1, "p": 0.6},
	{"set": "set_kurama", "clan": "kurama", "rank": 0, "p": 0.65},
	{"set": "set_chinoike", "clan": "chinoike", "rank": 0, "p": 0.7},
	{"set": "set_iburi", "clan": "iburi", "rank": 0, "p": 0.7},
	{"set": "set_funato", "clan": "funato", "rank": 0, "p": 0.7},
	{"set": "set_hagoromo", "clan": "hagoromo", "rank": 0, "p": 0.6},
	{"set": "set_oinin", "village": "kiri", "rank": 2, "p": 0.15},
	{"set": "set_konoha_eski", "village": "konoha", "rank": 3, "p": 0.1},
	{"set": "set_iwa_eski", "village": "iwa", "rank": 2, "p": 0.15},
	{"set": "set_oto_yonin", "village": "oto", "rank": 2, "p": 0.35},
	{"set": "set_oto", "village": "oto", "rank": 0, "p": 0.75},
	{"set": "set_uzushio", "clan": "uzumaki", "rank": 1, "p": 0.3},
	{"set": "set_jinmon", "village": "konoha", "rank": 2, "p": 0.04},
	{"set": "set_taki", "village": "taki", "rank": 0, "p": 0.6},
	{"set": "set_rengo", "villages": ["konoha", "suna", "kiri", "kumo", "iwa"], "rank": 2, "p": 0.07},
]


## Kişiye türü uyan kanon set ("" = kendi kıyafeti); aynı kişi hep aynı sonucu alır
static func type_set(clan: String, village: String, rank: int, seed_s: String, female := false) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(seed_s + "|tip")
	for e in TYPE_WEAR:
		var roll = rng.randf()
		if String(e.get("clan", clan)) != clan or String(e.get("village", village)) != village or rank < int(e["rank"]):
			continue
		if e.has("villages") and not village in e["villages"]:
			continue
		if roll < float(e["p"]) and _fits(String(e["set"]), female):
			return String(e["set"])
	return ""


## Görünüşe seti giydirir: kimlik (saç, yüz, ten, yaş, alın koruyucu) kalır, kıyafetin tamamı setten gelir
static func wear_set(L: Dictionary, sid: String) -> Dictionary:
	var out = CharacterModel.default_look()
	for k in LOOK_SELF:
		if L.has(k):
			out[k] = L[k]
	Gear.preview_set_look(out, sid)
	out["set_id"] = sid
	return out
