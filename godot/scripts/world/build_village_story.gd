class_name BuildVillageStory
extends RefCounted
const FacadeKit = preload("res://scripts/world/facade_kit.gd")
const GardenKit = preload("res://scripts/world/garden_kit.gd")
## Hikâyenin her büyük köyde oynanabilmesi için: Akademi, antrenman alanı, gözetleme kulesi, hastane, ANBU binası
## (Konoha dışındaki büyük köylerde, köyün hemen dışında bir yerleşke) + her büyük köyde Aranıyor Panosu (Bingo Kitabı).
## Konumlar köy merkezine göredir; dünya ölçeği değişse de çalışır.

const STYLE := {
	"suna": {"wall": Color(0.84, 0.72, 0.52), "roof": Color(0.72, 0.58, 0.4), "accent": Color(0.35, 0.55, 0.35), "label": "Suna"},
	"kiri": {"wall": Color(0.62, 0.68, 0.72), "roof": Color(0.3, 0.42, 0.55), "accent": Color(0.25, 0.45, 0.65), "label": "Kiri"},
	"kumo": {"wall": Color(0.88, 0.88, 0.86), "roof": Color(0.35, 0.5, 0.7), "accent": Color(0.85, 0.75, 0.3), "label": "Kumo"},
	"iwa": {"wall": Color(0.62, 0.52, 0.42), "roof": Color(0.5, 0.28, 0.22), "accent": Color(0.6, 0.3, 0.2), "label": "Iwa"},
}


static func build_all(parent: Node3D) -> void:
	# köyler akışla (yakına gelince) kurulabildiği için panolar görev masası belirince eklenir
	var w = BoardWatcher.new()
	w.name = "BountyBoards"
	w.parent3d = parent
	parent.add_child(w)
	for vid in ["konoha", "suna", "kiri", "kumo", "iwa"]:
		var v = Game.village(vid)
		if v.is_empty():
			continue
		if STYLE.has(vid):
			_compound(parent, v, STYLE[vid])


## Önemli yapılar köyün içine DAĞITILIR (tek yerleşkede kümelenmez): her biri kendi açısında ve uzaklığında, kapı yollarından
## uzak, birbirinden en az MIN_SEP m. Konumlar köy kimliğiyle tohumlanır (her açılışta aynı). Evler her yapının çevresine girmez.
const INSIDE := ["suna", "kiri", "kumo", "iwa"]
const MIN_SEP := 110.0
## yapı -> evlerin girmeyeceği yarıçap (avlu ve çevresi dahil)
const CLEAR := {"stadium": 92.0, "academy": 62.0, "training": 34.0, "lookout": 24.0, "hospital": 34.0, "anbu": 40.0}


static func _sites(v: Dictionary) -> Dictionary:
	var c = Vector2(float(v["x"]), float(v["y"]))
	var r = float(v.get("r", 250))
	var gates: Array = v.get("gates", [])
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(String(v.get("id", "")) + "_yapilar")
	var out = {}
	var taken: Array = []
	var inside = String(v.get("id", "")) in INSIDE
	var keys = []
	for key in ["stadium", "academy", "hospital", "anbu", "training", "lookout"]:
		var best = Vector2.INF
		var best_score = -1e9
		for k in 60:
			var a = rng.randf_range(0.0, 360.0)
			var ring = r * rng.randf_range(0.32, 0.72) if inside else r + rng.randf_range(60.0, 140.0)
			var gate_d = 180.0
			for g in gates:
				gate_d = minf(gate_d, absf(fmod(a - float(g) + 540.0, 360.0) - 180.0))
			if gate_d < 14.0:
				continue   # kapıdan merkeze giden ana cadde üstüne kurulmaz
			var rad = deg_to_rad(a)
			var p = c + Vector2(sin(rad), cos(rad)) * ring
			var h0 = Game.terrain_height(p.x, -p.y)
			if h0 < 1.0:
				continue
			var po = p - c
			if String(v.get("id", "")) == "kiri" and absf(po.x) < r * 0.8 and po.y > r * 0.15:
				continue   # Kiri'nin kuzey gölü
			var sep = 1e9
			var ok = true
			for qi in taken.size():
				var dq = p.distance_to(taken[qi])
				sep = minf(sep, dq)
				# yapıların kendi boşlukları birbirine girmesin (stadyum büyük)
				if dq < maxf(MIN_SEP, float(CLEAR[key]) + float(CLEAR[keys[qi]]) + 15.0):
					ok = false
			if not ok:
				continue
			var var_h = 0.0
			for o in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 30), Vector2(0, -30)]:
				var_h += absf(Game.terrain_height(p.x + o.x, -(p.y + o.y)) - h0)
			var score = minf(gate_d, 50.0) - var_h * 2.0 + minf(sep, 300.0) * 0.05 + rng.randf() * 10.0
			if score > best_score:
				best_score = score
				best = p
		if best == Vector2.INF:
			best = c + Vector2(r * 0.5, 0).rotated(taken.size() * 1.3)
		taken.append(best)
		keys.append(key)
		out[key] = best
	return out


## Suna Hastanesi (anime ref: refs/suna_hospital/suna_hospital.png, Narutopedia "Suna Hospital"): üst üste binmiş kerpiç
## silindirlerden kule — geniş kaide, şişkin yuvarlak bantlar, sıra sıra yuvarlak delikler, üst katta altın çerçeveli beyaz
## diskte kırmızı "医" arması, kubbe tepede iki küçük top; solda kare pencereli alçak yuvarlak ek bina. Kapı yerel -n (güney) yüzünde.
static func _suna_hospital(b: Builder, vn: String) -> void:
	# yer: kule + ek bina ~21 m yarıçap; hiçbir yol / sokak (yarı genişlik 8 m + 3 m pay) değmeyene kadar yoldan uzağa kayar
	# (2026-11-27, kullanıcı: "hastaneyi yolun ortasına koymuşsun": eski 18x12 kutunun yerine ölçmeden kondu)
	var rd = func(lp: Vector2) -> float:
		var wp = b.w(Vector3(lp.x, 0, lp.y))
		return Game.road_dist(wp.x, wp.z)
	var off = Vector2.ZERO
	for it in 60:
		var hit = false
		for k in 24:
			var a = TAU * k / 24.0
			for rr in [0.0, 11.0, 21.0]:
				if rd.call(off + Vector2(cos(a), sin(a)) * rr) < 11.0:
					hit = true
		if not hit:
			break
		var gx = rd.call(off + Vector2(3, 0)) - rd.call(off - Vector2(3, 0))
		var gn = rd.call(off + Vector2(0, 3)) - rd.call(off - Vector2(0, 3))
		var gdir = Vector2(gx, gn)
		off += (gdir.normalized() if gdir.length() > 0.01 else Vector2(0, 1)) * 2.0
	if off != Vector2.ZERO:
		var nw = b.w(Vector3(off.x, 0, off.y))
		b.origin = Vector3(nw.x, Game.terrain_height(nw.x, nw.z), nw.z)
	var body = Color(0.84, 0.62, 0.36)       # oker kerpiç
	var band = Color(0.9, 0.7, 0.44)         # açık, şişkin bantlar
	var dark = Color(0.86, 0.62, 0.36).darkened(0.12)
	var hole = Color(0.24, 0.15, 0.08)
	var gold = Color(0.8, 0.6, 0.3)
	# delik sırası: yarıçap R, yükseklik y, adet, faz (ön yüzde arma / kapı açıklığı bırakılır)
	var holes = func(R: float, y: float, cnt: int, ph: float, skip_front: float) -> void:
		for i in cnt:
			var a = 360.0 * (i + ph) / cnt
			var fd = absf(fmod(a + 540.0, 360.0) - 180.0)   # ön yüzden (yerel -n) açı farkı
			if fd < skip_front:
				continue
			var o = Builder.rot(0, -R, a)
			b.disc(Vector3(o.x, y, o.y), 0.95, 0.3, hole, a, 10)
	# kaide (yere gömülü: eğimde altı boş kalmasın) + yuvarlak kenarlı bant
	b.cyl(Vector3(0, 2.5, 0), 26.0, 13.0, body, true, 28)
	b.sphere(Vector3(0, 8.6, 0), Vector3(27.6, 2.2, 27.6), band, 28)
	holes.call(13.05, 5.4, 22, 0.5, 14.0)
	# orta gövde: iki sıra kaydırmalı delik
	b.cyl(Vector3(0, 13.4, 0), 21.0, 8.4, dark, true, 26)
	holes.call(10.55, 11.6, 16, 0.0, 0.0)
	holes.call(10.55, 14.8, 16, 0.5, 0.0)
	# şişkin bel bandı
	b.sphere(Vector3(0, 18.0, 0), Vector3(23.2, 2.6, 23.2), band, 26)
	# üst kat: arma kuşağı + tek sıra delik
	b.cyl(Vector3(0, 21.4, 0), 19.6, 5.6, body, true, 24)
	holes.call(9.85, 21.6, 14, 0.5, 26.0)
	b.sphere(Vector3(0, 24.4, 0), Vector3(21.6, 2.2, 21.6), band, 24)
	# kubbe + iki küçük top (animedeki "kulak"lar)
	b.dome(Vector3(0, 24.8, 0), 19.4, 6.4, body.lightened(0.04), 24)
	for sx in [-1.0, 1.0]:
		b.sphere(Vector3(sx * 3.4, 31.2, 0.6), Vector3(4.6, 4.4, 4.6), band, 14, true)
	# arma: üst katın önünde kuşak + altın çerçeve + beyaz disk + kırmızı 医
	b.box(Vector3(0, 21.6, -9.6), Vector3(9.5, 1.0, 0.6), dark.darkened(0.1), 0.0, false)
	b.disc(Vector3(0, 21.6, -10.0), 6.4, 0.5, gold, 0.0, 28)
	b.disc(Vector3(0, 21.6, -10.3), 5.4, 0.3, Color(0.96, 0.95, 0.91), 0.0, 28)
	b.kanji(Vector3(0, 21.55, -10.5), "医", 3.6, Color(0.66, 0.12, 0.14))
	# ek bina (solda): alçak yuvarlak gövde, bant, kare beyaz pencere, kubbe
	var ax = -14.5; var an = 3.0
	b.cyl(Vector3(ax, 3.0, an), 12.0, 12.0, body, true, 20)
	b.sphere(Vector3(ax, 7.6, an), Vector3(13.0, 1.6, 13.0), band, 20)
	b.dome(Vector3(ax, 8.2, an), 11.6, 3.6, body.lightened(0.04), 20)
	var wo = Builder.rot(0, -5.9, -35.0)
	b.box(Vector3(ax + wo.x, 6.0, an + wo.y), Vector3(2.9, 2.5, 0.4), gold, -35.0, false)
	b.box(Vector3(ax + wo.x * 1.02, 6.0, an + wo.y * 1.02), Vector3(2.3, 1.9, 0.3), Color(0.95, 0.95, 0.93), -35.0, false)
	for i in 6:
		var aa = -35.0 + 40.0 + i * 38.0
		var oo = Builder.rot(0, -6.05, aa)
		b.disc(Vector3(ax + oo.x, 4.4, an + oo.y), 0.8, 0.3, hole, aa, 10)
	# giriş: kaidede kemerli kapı (koyu oyuk + açık söve), önünde fenerler
	b.box(Vector3(0, 2.5, -13.05), Vector3(4.2, 5.0, 0.5), dark.darkened(0.2), 0.0, false)
	b.disc(Vector3(0, 5.0, -13.05), 4.2, 0.5, dark.darkened(0.2), 0.0, 16)
	b.box(Vector3(0, 2.1, -13.2), Vector3(3.0, 4.2, 0.3), Color(0.3, 0.22, 0.15), 0.0, false)
	b.interact(Vector3(0, 0, -14.5), 4, "enter", "[F] Gir: %s Hastanesi" % vn, {"room": "hospital", "vid": "suna", "out": b.w(Vector3(0, 0, -16.5))})
	for sx in [-1.0, 1.0]:
		b.lantern(sx * 5.0, -17.0)


## Chūnin Sınavı 2. aşamasının alanı (köy dışı, sabit): kapı yollarından uzak, karada, köy kenarından ~550 m
static func exam_ground(v: Dictionary) -> Vector2:
	var c = Vector2(float(v["x"]), float(v["y"]))
	var r = float(v.get("r", 250))
	var gates: Array = v.get("gates", [])
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(String(v.get("id", "")) + "_sinav_alani")
	var best = c + Vector2(0, r + 550.0)
	var best_score = -1e9
	for k in 48:
		var a = rng.randf_range(0.0, 360.0)
		var gate_d = 180.0
		for g in gates:
			gate_d = minf(gate_d, absf(fmod(a - float(g) + 540.0, 360.0) - 180.0))
		var p = c + Vector2(sin(deg_to_rad(a)), cos(deg_to_rad(a))) * (r + rng.randf_range(450.0, 650.0))
		var h0 = Game.terrain_height(p.x, -p.y)
		if h0 < 2.0:
			continue
		var var_h = 0.0
		for o2 in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
			var_h += absf(Game.terrain_height(p.x + o2.x, -(p.y + o2.y)) - h0)
		var score = minf(gate_d, 40.0) - var_h * 3.0 + rng.randf() * 5.0
		if score > best_score:
			best_score = score
			best = p
	return best


## Eski kayıtların / başka kodların beklediği tek nokta: akademi
static func _site(v: Dictionary) -> Vector2:
	return _sites(v)["academy"]


static func _compound(parent: Node3D, v: Dictionary, sty: Dictionary) -> void:
	var sites = _sites(v)
	var wall: Color = sty["wall"]; var roof: Color = sty["roof"]; var acc: Color = sty["accent"]
	var vn: String = v["name"]
	# --- Akademi binası + avlu kuklaları
	var p: Vector2 = sites["academy"]
	var base = Game.terrain_height(p.x, -p.y)
	var b = Builder.new(parent, p.x, p.y, base, "Story_%s_akademi" % v["id"])
	var ay = Game.terrain_height(p.x, -p.y) - base
	b.box(Vector3(0, ay + 1.0, 0), Vector3(30, 2.0 + 4.0, 15), wall.darkened(0.25))  # temel
	b.box(Vector3(0, ay + 6.5, 0), Vector3(28, 9, 13), wall)
	b.roof(Vector3(0, ay + 11.0, 0), Vector3(31, 4.5, 16), roof)
	b.box(Vector3(0, ay + 3.5, -6.6), Vector3(3.2, 5.0, 0.4), Color(0.3, 0.22, 0.15), 0.0, false)
	b.disc(Vector3(0, ay + 9.0, -6.7), 3.2, 0.3, acc)
	for i in 6:
		b.box(Vector3(-11 + i * 4.4, ay + 7.5, -6.6), Vector3(2.0, 1.6, 0.3), Color(0.55, 0.72, 0.85), 0.0, false)
	# arka + yan yüzler (2026-11-25: düz duvardı): ön cepheyle aynı pencereler + ahşap çerçeve, arka kapı + saçak, kat kuşağı,
	# yağmur boruları, dipte sandık / fıçı / odun
	var ao = {"floors": 1, "win_y": ay + 7.5, "win": Vector2(2.0, 1.6), "pitch": 4.4, "frame": Color(0.3, 0.22, 0.15),
		"glass": Color(0.55, 0.72, 0.85), "band": roof.darkened(0.2), "pipes": roof.darkened(0.25), "margin": 2.0}
	var ab = ao.duplicate()
	ab.merge({"door": -7.0, "door_w": 2.2, "door_h": 3.2, "awning": roof, "props": "service", "seed": hash(v["id"]) % 1000})
	FacadeKit.dress(b, 0.0, 6.5, 0.0, 28.0, ay + 4.0, 7.0, ab)
	for sx in [-1.0, 1.0]:
		var asd = ao.duplicate()
		asd.merge({"seed": hash(v["id"]) % 1000 + 3 + int(sx), "margin": 2.6})
		FacadeKit.dress(b, sx * 14.0, 0.0, 90.0 if sx > 0.0 else 270.0, 13.0, ay + 4.0, 7.0, asd)
	b.interact(Vector3(0, ay, -8.0), 4, "enter", "[F] Gir: %s Ninja Akademisi" % vn, {"room": "academy", "alias": "academy", "vid": v["id"], "out": b.w(Vector3(0, ay, -9.5))})
	var arng = RandomNumberGenerator.new()
	arng.seed = hash(v["id"] + "_akademi")
	AcademyGrounds.dress(b, 0.0, -6.5, 30.0, 44.0, arng, {"vid": v["id"], "climate": {"suna": "desert", "iwa": "dry", "kumo": "dry"}.get(v["id"], "green"),
		"flag": acc, "roof": roof, "bw": 28.0, "scale": 0.6, "flag_kanji": {"suna": "砂", "kiri": "霧", "kumo": "雲", "iwa": "岩"}.get(v["id"], "忍")})
	for i in 4:
		b.lantern(-12 + i * 8, -12)
	# arka bahçe: antrenman köşesi + öğrenci bahçesi (iklime göre); köy evleri yerleşkenin CLEAR çemberinin dışında kalır
	GardenKit.build(b, {"vid": v["id"], "name": "akademi", "x": 0.0, "n": 6.5, "w": 28.0, "side": 6.0, "doors": [Vector2(-7.0, 0.0)],
		"d0": 2.0, "dmax": 34.0, "style": "academy", "limit": [Vector2.ZERO, float(CLEAR["academy"]) - 14.0]})
	b.finish()
	# --- antrenman alanı (ayrı yerde)
	p = sites["training"]
	base = Game.terrain_height(p.x, -p.y)
	b = Builder.new(parent, p.x, p.y, base, "Story_%s_antrenman" % v["id"])
	var g = func(x: float, n: float) -> float:
		return Game.terrain_height(p.x + x, -(p.y + n)) - base
	for i in 10:
		var a = TAU * i / 10.0
		b.cyl(Vector3(cos(a) * 13, g.call(cos(a) * 13, sin(a) * 13) + 1.0, sin(a) * 13), 0.5, 2.0 + 4.0, Color(0.45, 0.33, 0.2), true, 6)
	for i in 3:
		Spawner.dummy(b.w(Vector3(-5 + i * 5, g.call(-5 + i * 5, 0), 0)))
	b.interact(Vector3(0, g.call(0, -12), -12), 6, "training", "[F] Antrenman yap (chakra kontrolü)")
	b.finish()
	# --- gözetleme kulesi (duvar koşusuyla tırmanılır, 40 m)
	p = sites["lookout"]
	base = Game.terrain_height(p.x, -p.y)
	b = Builder.new(parent, p.x, p.y, base, "Story_%s_kule" % v["id"])
	b.cyl(Vector3(0, 19.0, 0), 9.0, 42.0, wall.darkened(0.15), true, 14)
	b.cyl(Vector3(0, 40.6, 0), 14.0, 1.2, roof, true, 16)
	for k in 8:
		var a = TAU * k / 8.0
		b.box(Vector3(cos(a) * 6.6, 41.8, sin(a) * 6.6), Vector3(1.2, 1.2, 1.2), roof.darkened(0.2), rad_to_deg(a), true)
	b.interact(Vector3(0, 41.3, 0), 8, "lookout", "[F] Köyü seyret (kayıt)")
	b.finish()
	# --- hastane
	p = sites["hospital"]
	base = Game.terrain_height(p.x, -p.y)
	b = Builder.new(parent, p.x, p.y, base, "Story_%s_hastane" % v["id"])
	if v["id"] == "suna":
		_suna_hospital(b, vn)   # animedeki Suna hastanesi: üst üste kerpiç silindir kule
	else:
		b.box(Vector3(0, 0.5, 0), Vector3(18, 3.0, 12), wall.darkened(0.25))
		b.box(Vector3(0, 4.5, 0), Vector3(17, 7, 11), Color(0.92, 0.92, 0.9))
		b.roof(Vector3(0, 8.0, 0), Vector3(19, 3.0, 13), Color(0.75, 0.2, 0.2))
		b.disc(Vector3(0, 5.5, -5.6), 2.4, 0.3, Color(0.85, 0.15, 0.15))
		var ho = {"floors": 1, "win_y": 4.6, "win": Vector2(1.8, 1.6), "pitch": 3.6, "frame": Color(0.75, 0.2, 0.2),
			"glass": Color(0.62, 0.8, 0.86), "pipes": Color(0.6, 0.62, 0.66), "margin": 1.8}
		var hb = ho.duplicate()
		hb.merge({"door": 4.5, "door_w": 2.0, "door_h": 2.8, "door_col": Color(0.85, 0.88, 0.9), "awning": Color(0.75, 0.2, 0.2), "props": "clinic",
			"seed": hash(v["id"]) % 1000 + 10})
		FacadeKit.dress(b, 0.0, 5.5, 0.0, 17.0, 2.0, 6.0, hb)
		for sx in [-1.0, 1.0]:
			var hs = ho.duplicate()
			hs.merge({"seed": hash(v["id"]) % 1000 + 12 + int(sx)})
			FacadeKit.dress(b, sx * 8.5, 0.0, 90.0 if sx > 0.0 else 270.0, 11.0, 2.0, 6.0, hs)
		b.box(Vector3(0, 2.4, -5.6), Vector3(3.0, 4.4, 0.4), Color(0.3, 0.22, 0.15), 0.0, false)   # kapı
		b.interact(Vector3(0, 0, -7.0), 4, "enter", "[F] Gir: %s Hastanesi" % vn, {"room": "hospital", "vid": v["id"], "out": b.w(Vector3(0, 0, -9.0))})
		for i in 3:
			b.lantern(-6 + i * 6, -10)
		GardenKit.build(b, {"vid": v["id"], "name": "hastane", "x": 0.0, "n": 5.5, "w": 17.0, "side": 5.0, "doors": [Vector2(4.5, 0.0)],
			"d0": 2.0, "dmax": 20.0, "style": "hospital", "limit": [Vector2.ZERO, float(CLEAR["hospital"]) - 10.0], "min_d": 5.0})
	b.finish()
	# --- Chūnin Sınavı final stadyumu (köyün renginde)
	p = sites["stadium"]
	base = Game.terrain_height(p.x, -p.y)
	b = Builder.new(parent, p.x, p.y, base, "Story_%s_stadyum" % v["id"])
	var srng = RandomNumberGenerator.new()
	srng.seed = hash(v["id"] + "_stadyum")
	var kdir = rad_to_deg(atan2(float(v["x"]) - p.x, float(v["y"]) - p.y))   # Kage locası köy merkezine bakan tarafta
	Stadium.build(b, 0.0, 0.0, 0.0, Stadium.style_for(String(v["id"])), srng, kdir)
	b.finish()
	# --- Chūnin Sınavı 2. aşama alanı: köyün dışında, köy tarzında kule (Konoha'daki Ölüm Ormanı kulesinin karşılığı)
	var eg: Vector2 = exam_ground(v)
	var eb = Game.terrain_height(eg.x, -eg.y)
	Roadside._add_clear(eg.x, eg.y, 70.0)
	b = Builder.new(parent, eg.x, eg.y, eb, "Story_%s_sinav_kulesi" % v["id"])
	b.view_dist = 3000.0
	var tsty = {"suna": [Color(0.8, 0.64, 0.42), Color(0.58, 0.42, 0.28), "砂"], "kiri": [Color(0.4, 0.5, 0.58), Color(0.78, 0.84, 0.86), "霧"],
		"kumo": [Color(0.86, 0.86, 0.84), Color(0.3, 0.46, 0.7), "雲"], "iwa": [Color(0.55, 0.36, 0.26), Color(0.72, 0.6, 0.46), "岩"]}.get(String(v["id"]), [Color(0.62, 0.24, 0.18), Color(0.9, 0.84, 0.66), "天"])
	BuildSites.exam_tower(b, tsty[0], tsty[1], tsty[2])
	b.finish()
	# --- ANBU / Kage muhafızları karargâhı
	p = sites["anbu"]
	base = Game.terrain_height(p.x, -p.y)
	b = Builder.new(parent, p.x, p.y, base, "Story_%s_anbu" % v["id"])
	SecretUnits.build_hq(b, String(v["id"]), 0.0, 0.0, 0.0)   # köyün gizli birliği: kendi mimarisinde karargâh + iç mekân
	b.finish()


## Görev masasının yanında Aranıyor panosu
static func _bounty_board(parent: Node3D, v: Dictionary) -> void:
	var c = Vector2(float(v["x"]), float(v["y"]))
	var best = {}
	var bd = float(v.get("r", 250)) * 1.2
	for it in Interact.items:
		if (it["kind"] != "mission_board" and it.get("alias", "") != "mission_board") or it.get("interior", false):
			continue
		var d = Game.to_map(it["pos"]).distance_to(c)
		if d < bd:
			bd = d; best = it
	var at: Vector2
	if best.is_empty():
		at = c + Vector2(12, -20)
	else:
		at = Game.to_map(best["pos"]) + Vector2(16, -13)  # Kage meydanında merdivenin yanı
	var base = Game.terrain_height(at.x, -at.y)
	var b = Builder.new(parent, at.x, at.y, base, "Bounty_%s" % v["id"])
	b.cyl(Vector3(-1.4, 1.4, 0), 0.22, 2.8 + 1.0, Color(0.35, 0.25, 0.15), true, 6)
	b.cyl(Vector3(1.4, 1.4, 0), 0.22, 2.8 + 1.0, Color(0.35, 0.25, 0.15), true, 6)
	b.box(Vector3(0, 2.1, 0), Vector3(3.4, 1.8, 0.2), Color(0.5, 0.38, 0.24), 0.0, true)
	b.roof(Vector3(0, 3.1, 0), Vector3(3.9, 0.6, 0.9), Color(0.3, 0.2, 0.15))
	for i in 4:
		b.box(Vector3(-1.1 + i * 0.75, 2.15, -0.12), Vector3(0.55, 0.75, 0.02), Color(0.92, 0.88, 0.76), 0.0, false)
		b.box(Vector3(-1.1 + i * 0.75, 2.3, -0.135), Vector3(0.3, 0.25, 0.01), Color(0.7, 0.15, 0.12), 0.0, false)
	b.interact(Vector3(0, 0, -1.5), 4, "bounty_board", "[F] Aranıyor Panosu (Bingo Kitabı)")
	b.finish()


## Görev masası etkileşimi ortaya çıkınca (köy akışla yüklenince) yanına Aranıyor panosu kurar
class BoardWatcher extends Node:
	var parent3d: Node3D
	var done := {}
	var t := 0.0

	func _process(dt: float) -> void:
		t -= dt
		if t > 0.0:
			return
		t = 2.0
		for vid in ["konoha", "suna", "kiri", "kumo", "iwa"]:
			if done.has(vid):
				continue
			var v = Game.village(vid)
			if v.is_empty():
				done[vid] = true
				continue
			var c = Vector2(float(v["x"]), float(v["y"]))
			for it in Interact.items:
				if (it["kind"] == "mission_board" or it.get("alias", "") == "mission_board") and not it.get("interior", false) and Game.to_map(it["pos"]).distance_to(c) < float(v.get("r", 250)) * 1.2:
					BuildVillageStory._bounty_board(parent3d, v)
					done[vid] = true
					break
