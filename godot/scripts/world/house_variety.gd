extends RefCounted
## Konoha konut çeşitliliği (2026-11-25, kullanıcı: "hepsi aynı, en az 50 çeşit ev olmalı"): 50 ayrı ev türü, her biri
## plan (kütle) + çatı + cephe malzemesi + kat sayısı + ekler birleşimi. HouseKit.ensure ilk 50 şablonu buradan üretir.
## Ön cephe -z (kapı). Duvarlar beyaz (yerleştiricide mahalle rengiyle boyanır), ahşap / taş / tuğla kaplamalar detay katmanında.
## Ana kütle merkezde (gövde çarpışması), kanatlar / kuleler / basamaklar "cols" ile kendi biçiminde çarpışır (görünmez duvar yok).

const WOOD := Color(0.42, 0.28, 0.18)
const WOOD_D := Color(0.3, 0.2, 0.13)
const WOOD_L := Color(0.6, 0.44, 0.28)
const DARK := Color(0.2, 0.15, 0.12)
const STONE := Color(0.55, 0.53, 0.5)
const STONE_L := Color(0.68, 0.66, 0.62)
const BRICK := Color(0.62, 0.32, 0.24)
const GLASS := Color(0.55, 0.72, 0.85)
const SHOJI := Color(0.95, 0.92, 0.82)
const CLOTHES := [Color(0.9, 0.9, 0.95), Color(0.3, 0.45, 0.75), Color(0.85, 0.35, 0.3), Color(0.95, 0.8, 0.4), Color(0.45, 0.7, 0.45)]

## plan: box L T setback overhang twin tower_corner narrow row court terrace porch
## çatı: gable hip barrel flat shed irimoya tiered saw
## cephe: timber lattice siding stone brick band plain
## ekler: b balkon, s dış merdiven, t su tankı, c baca, g çatı bahçesi, v tabela, w cumba, e veranda, l çamaşır, a tente, k kepenk
const SPECS := [
	["box", "gable", "timber", 2, "be"], ["box", "hip", "plain", 2, "w"], ["box", "barrel", "band", 3, "bl"], ["box", "flat", "brick", 4, "tsv"],
	["box", "shed", "siding", 2, "c"], ["box", "irimoya", "lattice", 2, "e"], ["box", "tiered", "plain", 3, "k"], ["box", "saw", "brick", 2, "a"],
	["L", "gable", "siding", 2, "e"], ["L", "hip", "timber", 2, "bw"], ["L", "flat", "plain", 3, "gt"], ["L", "irimoya", "stone", 2, "c"],
	["L", "barrel", "band", 3, "bl"], ["T", "gable", "timber", 2, "w"], ["T", "hip", "stone", 2, "e"], ["T", "flat", "band", 3, "tv"],
	["setback", "gable", "plain", 3, "b"], ["setback", "flat", "brick", 4, "gt"], ["setback", "hip", "timber", 3, "w"], ["setback", "barrel", "band", 3, "l"],
	["overhang", "flat", "siding", 2, "a"], ["overhang", "gable", "lattice", 2, "k"], ["overhang", "shed", "plain", 3, "b"], ["twin", "gable", "timber", 2, "b"],
	["twin", "flat", "brick", 3, "tl"], ["twin", "hip", "band", 2, "w"], ["tower_corner", "hip", "plain", 2, "b"], ["tower_corner", "flat", "stone", 3, "t"],
	["tower_corner", "gable", "siding", 2, "e"], ["narrow", "gable", "plain", 4, "vb"], ["narrow", "barrel", "band", 5, "l"], ["narrow", "flat", "brick", 5, "tv"],
	["narrow", "tiered", "timber", 4, "k"], ["row", "gable", "lattice", 2, "ak"], ["row", "flat", "band", 3, "bl"], ["row", "saw", "siding", 2, "a"],
	["row", "irimoya", "timber", 2, "e"], ["court", "irimoya", "lattice", 1, "e"], ["court", "hip", "stone", 1, "c"], ["court", "gable", "siding", 2, "w"],
	["terrace", "flat", "plain", 3, "g"], ["terrace", "flat", "stone", 3, "gt"], ["porch", "gable", "siding", 1, "ec"], ["porch", "hip", "timber", 2, "e"],
	["porch", "irimoya", "lattice", 1, "e"], ["box", "tiered", "lattice", 2, "e"], ["L", "shed", "brick", 2, "c"], ["T", "barrel", "plain", 3, "b"],
	["setback", "tiered", "stone", 3, "k"], ["twin", "irimoya", "lattice", 2, "e"],
]


## Duvar kütlesi: görüntü + aynı kutu çarpışma (görünen her duvar katı, görünmeyen yerde duvar yok)
static func _wall(walls: MB, cols: Array, p: Vector3, s: Vector3) -> void:
	walls.add("box", p, s, Color(1, 1, 1))
	cols.append([p, s, 0.0])


static func make(rng: RandomNumberGenerator, i: int) -> Dictionary:
	var sp: Array = SPECS[i % SPECS.size()]
	var plan: String = sp[0]
	var roof_t: String = sp[1]
	var face: String = sp[2]
	var floors: int = sp[3]
	var ext: String = sp[4]
	var fh = 3.5 if face != "lattice" else 3.3
	var walls = MB.new()
	var roof = MB.new()
	var det = MB.new()
	var cols: Array = []
	roof_prims.clear()
	roof_fill.clear()
	var white = Color(1, 1, 1)
	# ana kütle ölçüleri plana göre
	var w: float; var d: float
	match plan:
		"narrow": w = rng.randf_range(8.0, 10.0); d = rng.randf_range(9.0, 11.0)
		"row": w = rng.randf_range(20.0, 26.0); d = rng.randf_range(8.5, 10.0)
		"court": w = rng.randf_range(11.0, 13.0); d = rng.randf_range(7.5, 8.5)
		"porch": w = rng.randf_range(11.0, 14.0); d = rng.randf_range(8.5, 9.5)
		"twin": w = rng.randf_range(8.0, 10.0); d = rng.randf_range(9.0, 10.5)
		"T": w = rng.randf_range(11.0, 14.0); d = rng.randf_range(8.0, 9.0)
		"terrace": w = rng.randf_range(11.0, 14.0); d = rng.randf_range(6.5, 7.5)
		_: w = rng.randf_range(11.0, 15.0); d = rng.randf_range(9.0, 11.0)
	var h = 0.5 + floors * fh
	# kanatlar: [merkez x, merkez z, gen, der, kat] (ana kütlenin dışında)
	var wings: Array = []
	match plan:
		"L": wings.append([w * 0.5 + 3.0, d * 0.2, 6.0, d * 0.6 + 2.0, maxi(1, floors - 1)])
		"T": wings.append([0.0, -d * 0.5 - 1.75, w * 0.5, 3.5, maxi(1, floors - 1)])
		"twin": wings.append([w + 3.0, 0.0, w, d, floors])
		"tower_corner": pass
		"terrace": wings.append([0.0, -d * 0.5 - 1.75, w, 3.5, maxi(1, floors - 1)]); wings.append([0.0, -d * 0.5 - 5.0, w, 3.0, maxi(1, floors - 2)])
	# --- gövde
	det.add("box", Vector3(0, 0.25, 0), Vector3(w + 0.4, 0.5, d + 0.4), STONE)
	cols.append([Vector3(0, 0.25, 0), Vector3(w + 0.4, 0.5, d + 0.4), 0.0])
	match plan:
		"setback":   # üst kat(lar) geri çekilir (önde teras)
			_wall(walls, cols, Vector3(0, 0.5 + fh * 0.5, 0), Vector3(w, fh, d))
			var uh = (floors - 1) * fh
			_wall(walls, cols, Vector3(0, 0.5 + fh + uh * 0.5, d * 0.15), Vector3(w * 0.85, uh, d * 0.7))
			det.add("box", Vector3(0, 0.5 + fh + 0.5, -d * 0.5 + 0.1), Vector3(w, 0.9, 0.15), WOOD_L)   # teras korkuluğu
			det.add("box", Vector3(0, 0.5 + fh + 0.04, -d * 0.5 + d * 0.15 * 0.5 + 0.02), Vector3(w - 0.1, 0.08, d * 0.15 + 0.1), WOOD)   # teras ahşap döşeme
			for sx in [-1.0, 1.0]:
				det.add("box", Vector3(sx * (w * 0.5 - 0.08), 0.5 + fh + 0.5, -d * 0.5 + d * 0.15 * 0.5), Vector3(0.15, 0.9, d * 0.15), WOOD_L)
				cols.append([Vector3(sx * (w * 0.5 - 0.08), 0.5 + fh + 0.5, -d * 0.5 + d * 0.15 * 0.5), Vector3(0.15, 0.9, d * 0.15), 0.0])
			cols.append([Vector3(0, 0.5 + fh + 0.5, -d * 0.5 + 0.1), Vector3(w, 0.9, 0.15), 0.0])
		"overhang":  # üst kat öne taşar, altında dikmeler
			_wall(walls, cols, Vector3(0, 0.5 + fh * 0.5, d * 0.1), Vector3(w, fh, d * 0.8))
			var uh2 = (floors - 1) * fh
			_wall(walls, cols, Vector3(0, 0.5 + fh + uh2 * 0.5, -0.4), Vector3(w + 0.6, uh2, d + 0.8))
			for sx in [-1.0, 1.0]:
				det.add("box", Vector3(sx * (w * 0.5 - 0.2), 0.5 + fh * 0.5, -d * 0.5 - 0.6), Vector3(0.3, fh, 0.3), WOOD_D)
		_:
			_wall(walls, cols, Vector3(0, 0.5 + (h - 0.5) * 0.5, 0), Vector3(w, h - 0.5, d))
	for wg in wings:
		var wh = 0.5 + int(wg[4]) * fh
		_wall(walls, cols, Vector3(wg[0], wh * 0.5 + 0.25, wg[1]), Vector3(wg[2], wh - 0.5, wg[3]))
		det.add("box", Vector3(wg[0], 0.25, wg[1]), Vector3(wg[2] + 0.3, 0.5, wg[3] + 0.3), STONE)
		cols.append([Vector3(wg[0], 0.25, wg[1]), Vector3(wg[2] + 0.3, 0.5, wg[3] + 0.3), 0.0])
		_roof(roof, det, true, roof_t if roof_t not in ["saw", "tiered"] else "flat", wg[0], wg[1], wg[2], wg[3], wh, rng)
		_facade(det, face, wg[0], wg[1], wg[2], wg[3], int(wg[4]), fh, rng, false)
	if plan == "twin":   # iki blok arası kapalı köprü
		var by = 0.5 + (floors - 1) * fh
		_wall(walls, cols, Vector3(w * 0.5 + 1.5, by + fh * 0.5, 0), Vector3(3.2, fh, d * 0.45))
	if plan == "tower_corner":   # sağ ön köşede yuvarlak kule, gövdeden bir kat yüksek
		var tr = 2.6
		var th = h + fh
		walls.add("cyl", Vector3(w * 0.5, th * 0.5, -d * 0.5), Vector3(tr * 2.0, th, tr * 2.0), white, Vector3.ZERO, 16)
		roof.add("cone", Vector3(w * 0.5, th + 1.3, -d * 0.5), Vector3(tr * 2.0 + 1.2, 2.6, tr * 2.0 + 1.2), white, Vector3.ZERO, 16)
		roof_prims.append(["cone", Vector3(w * 0.5, th + 1.3, -d * 0.5), Vector3(tr * 2.0 + 1.2, 2.6, tr * 2.0 + 1.2), Vector3.ZERO, 12])
		for f in floors + 1:
			HouseKit._window(det, Vector3(w * 0.5 + 0.2, 0.5 + f * fh + fh * 0.55, -d * 0.5 - tr - 0.02), 0.0, rng)
		roof_prims.append(["cyl", Vector3(w * 0.5, th * 0.5, -d * 0.5), Vector3(tr * 2.0, th, tr * 2.0), Vector3.ZERO, 12])   # kule: kendi silindiri
	if plan == "court":   # önde avlu duvarı + kapı (yarı açık)
		# duvarlar toprağın içine iner (eğimde havada kalmasın); üstleri 2.2 m
		for sx in [-1.0, 1.0]:
			det.add("box", Vector3(sx * (w * 0.5 + 0.1), 0.6, -d * 0.5 - 1.8), Vector3(0.4, 3.2, 3.6), STONE_L)
			det.add("box", Vector3(sx * (w * 0.3 + 1.0), 0.6, -d * 0.5 - 3.6), Vector3(w * 0.4 - 1.6, 3.2, 0.4), STONE_L)
			det.add("box", Vector3(sx * (w * 0.3 + 1.0), 2.25, -d * 0.5 - 3.6), Vector3(w * 0.4 - 1.5, 0.12, 0.6), DARK)   # duvar başlığı
			cols.append([Vector3(sx * (w * 0.5 + 0.1), 1.1, -d * 0.5 - 1.8), Vector3(0.4, 2.2, 3.6), 0.0])
			cols.append([Vector3(sx * (w * 0.3 + 1.0), 1.1, -d * 0.5 - 3.6), Vector3(w * 0.4 - 1.6, 2.2, 0.4), 0.0])
		# avlu kapısı (2026-11-25, kullanıcı: "bina girişi uçuyor" — saçak 6 m'lik boşluğun ortasında direksiz asılıydı):
		# boşluğun iki ucunda direk, üstte kiriş + kiremit kapı çatısı; duvar uçlarına oturur
		var gh = w * 0.1 + 1.8
		var gz = -d * 0.5 - 3.6
		for sx in [-1.0, 1.0]:
			det.add("box", Vector3(sx * (gh - 0.15), 1.0, gz), Vector3(0.36, 3.6, 0.36), WOOD)
			cols.append([Vector3(sx * (gh - 0.15), 1.4, gz), Vector3(0.36, 2.8, 0.36), 0.0])
		det.add("box", Vector3(0, 2.75, gz), Vector3(gh * 2.0 + 0.3, 0.28, 0.3), WOOD)
		det.add("box", Vector3(0, 2.35, gz), Vector3(gh * 2.0 - 0.3, 0.14, 0.2), WOOD)
		roof.add("prism", Vector3(0, 3.24, gz), Vector3(1.8, 0.7, gh * 2.0 + 1.2), Color(1, 1, 1), Vector3(0, 90, 0), 4)   # sırt kapı boyunca
		roof_prims.append(["prism", Vector3(0, 3.24, gz), Vector3(1.8, 0.7, gh * 2.0 + 1.2), Vector3(0, 90, 0), 4])
		det.add("box", Vector3(0, 3.62, gz), Vector3(gh * 2.0 + 1.3, 0.16, 0.24), DARK)   # mahya
	# --- ana çatı + cephe
	var top = h if plan != "setback" else h
	var tz = d * 0.15 if plan == "setback" else (-0.4 if plan == "overhang" else 0.0)
	var tw = w * 0.85 if plan == "setback" else (w + 0.6 if plan == "overhang" else w)
	var td = d * 0.7 if plan == "setback" else (d + 0.8 if plan == "overhang" else d)
	var roof_top = _roof(roof, det, true, roof_t, 0.0, tz, tw, td, top, rng)
	for rf in roof_fill:
		_wall(walls, cols, rf[0], rf[1])
	roof_fill.clear()
	match plan:   # üst katlar kendi (geri çekilmiş / taşan) kütlesinin yüzünde
		"setback", "overhang":
			var gz = d * 0.1 if plan == "overhang" else 0.0
			var gd = d * 0.8 if plan == "overhang" else d
			_facade(det, face, 0.0, gz, w, gd, 1, fh, rng, true)
			_facade(det, face, 0.0, tz, tw, td, floors - 1, fh, rng, false, fh)
		_:
			_facade(det, face, 0.0, 0.0, w, d, floors, fh, rng, true)
	# kapı
	var drng = RandomNumberGenerator.new()
	drng.seed = 7000 + i
	var fz = -d * 0.5   # gerçek ön yüz (kapı buraya)
	match plan:
		"T": fz = -d * 0.5 - 3.5
		"terrace": fz = -d * 0.5 - 6.5
		"overhang": fz = -d * 0.3
	DoorKit.jp_template(det, fz, 0.5, "a" in ext or "k" in ext, drng)
	var front_wing = plan in ["T", "terrace"]
	# --- ekler
	if "b" in ext and floors >= 2 and not front_wing and plan != "setback":
		var by2 = 0.5 + fh
		var bz = -0.8 if plan == "overhang" else 0.0
		det.add("box", Vector3(0, by2, bz - d * 0.5 - 0.7), Vector3(w * 0.6, 0.18, 1.4), WOOD)
		for k in 7:
			det.add("box", Vector3(-w * 0.3 + k * w * 0.1, by2 + 0.5, bz - d * 0.5 - 1.35), Vector3(0.08, 0.9, 0.08), WOOD_L)
		det.add("box", Vector3(0, by2 + 0.95, bz - d * 0.5 - 1.35), Vector3(w * 0.6, 0.1, 0.1), WOOD)
		cols.append([Vector3(0, by2, bz - d * 0.5 - 0.7), Vector3(w * 0.6, 0.25, 1.4), 0.0])
	if "w" in ext and floors >= 2 and not front_wing and plan not in ["setback", "overhang"]:   # cumba (çıkma pencere)
		var wy = 0.5 + fh * 1.5
		cols.append([Vector3(-w * 0.22, wy, -d * 0.5 - 0.6), Vector3(3.0, fh * 0.75, 1.2), 0.0])
		det.add("box", Vector3(-w * 0.22, wy, -d * 0.5 - 0.6), Vector3(3.0, fh * 0.75, 1.2), Color(0.85, 0.83, 0.78))
		det.add("box", Vector3(-w * 0.22, wy, -d * 0.5 - 1.22), Vector3(2.4, fh * 0.5, 0.06), GLASS)
		det.add("box", Vector3(-w * 0.22, wy + fh * 0.42, -d * 0.5 - 0.6), Vector3(3.3, 0.18, 1.5), DARK)
	if "e" in ext:   # engawa veranda: önde ahşap döşeme + saçak + dikmeler
		var vw = w * 0.5 if plan == "T" else w   # T: önündeki kanadın genişliği
		det.add("box", Vector3(0, 0.6, fz - 1.0), Vector3(vw - 0.4, 0.2, 2.0), WOOD_L)
		det.add("box", Vector3(0, 3.1, fz - 1.1), Vector3(vw + 0.4, 0.16, 2.4), Color(0.3, 0.3, 0.32), Vector3(-12, 0, 0))
		for k in 4:
			det.add("box", Vector3(-vw * 0.45 + k * vw * 0.3, 1.8, fz - 1.9), Vector3(0.18, 2.6, 0.18), WOOD)
		cols.append([Vector3(0, 0.6, fz - 1.0), Vector3(vw - 0.4, 0.25, 2.0), 0.0])
		cols.append([Vector3(0, 3.1, fz - 1.1), Vector3(vw + 0.4, 0.2, 2.4), -12.0])
	if "a" in ext:   # dükkân tentesi + tezgâh
		var ac = [Color(0.85, 0.3, 0.25), Color(0.25, 0.5, 0.75), Color(0.95, 0.7, 0.3), Color(0.35, 0.6, 0.35)][i % 4]
		det.add("box", Vector3(0, 0.5 + 2.9, fz - 0.9), Vector3(w * 0.85, 0.12, 1.8), ac, Vector3(-14, 0, 0))
		det.add("box", Vector3(-w * 0.25, 0.5 + 0.5, fz - 0.5), Vector3(w * 0.35, 1.0, 0.7), WOOD_L)
		cols.append([Vector3(-w * 0.25, 0.5 + 0.5, fz - 0.5), Vector3(w * 0.35, 1.0, 0.7), 0.0])
		cols.append([Vector3(0, 0.5 + 2.9, fz - 0.9), Vector3(w * 0.85, 0.16, 1.8), -14.0])
	if "k" in ext:   # kepenkli dükkân cephesi (zemin katı sürgülü kepenk çizgileri)
		for k in 8:
			det.add("box", Vector3(w * 0.2, 0.7 + k * 0.28, fz - 0.06), Vector3(w * 0.35, 0.05, 0.05), Color(0.55, 0.56, 0.58))
	if "v" in ext:   # dikey tabela
		var vc = [Color(0.85, 0.2, 0.15), Color(0.95, 0.92, 0.8), Color(0.2, 0.3, 0.55), Color(0.95, 0.75, 0.2)][i % 4]
		det.add("box", Vector3(w * 0.5 + 0.35, 0.5 + fh * 1.5, -d * 0.5 + 1.0), Vector3(0.2, fh * 1.8, 1.1), vc)
		cols.append([Vector3(w * 0.5 + 0.35, 0.5 + fh * 1.5, -d * 0.5 + 1.0), Vector3(0.2, fh * 1.8, 1.1), 0.0])
		for k in 4:
			det.add("box", Vector3(w * 0.5 + 0.47, 0.5 + fh * 2.1 - k * fh * 0.38, -d * 0.5 + 1.0), Vector3(0.03, 0.5, 0.6), DARK)
	if "s" in ext and floors >= 2:   # yan dış merdiven (kat başına düz kol)
		for fl in floors - 1:
			var dirz = 1.0 if fl % 2 == 0 else -1.0
			for k in 10:
				det.add("box", Vector3(w * 0.5 + 0.7, 0.5 + fl * fh + k * fh / 10.0, dirz * (-d * 0.3 + k * d * 0.06)), Vector3(1.3, 0.16, 0.7), DARK.lightened(0.15))
			var run = d * 0.54; var rise = fh * 0.9
			cols.append([Vector3(w * 0.5 + 0.7, 0.5 + fl * fh + rise * 0.5, -d * 0.03 * dirz), Vector3(1.3, 0.25, sqrt(run * run + rise * rise)), -rad_to_deg(atan2(rise, run)) * dirz])
	if "l" in ext and floors >= 2:   # çamaşır ipi (yan cephe)
		var ly = 0.5 + fh * 1.6
		det.add("box", Vector3(-w * 0.5 - 0.9, ly, 0), Vector3(0.03, 0.03, d * 0.6), DARK)
		for k in 4:
			det.add("box", Vector3(-w * 0.5 - 0.9, ly - 0.4, -d * 0.24 + k * d * 0.16), Vector3(0.03, 0.75, 0.9), CLOTHES[(i + k) % CLOTHES.size()])
		for sz in [-1.0, 1.0]:
			det.add("box", Vector3(-w * 0.5 - 0.5, ly, sz * d * 0.3), Vector3(0.9, 0.06, 0.06), DARK)
	if "c" in ext:   # baca
		det.add("box", Vector3(w * 0.28, roof_top - 0.4, d * 0.2), Vector3(0.9, 2.4, 0.9), BRICK)
		det.add("box", Vector3(w * 0.28, roof_top + 0.85, d * 0.2), Vector3(1.15, 0.2, 1.15), DARK)
		cols.append([Vector3(w * 0.28, roof_top - 0.3, d * 0.2), Vector3(0.9, 2.6, 0.9), 0.0])
	if "t" in ext and roof_t in ["flat", "saw"]:   # su tankı
		var txp = rng.randf_range(-w * 0.2, w * 0.2)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				det.add("box", Vector3(txp + sx * 0.8, h + 1.0, d * 0.15 + sz * 0.8), Vector3(0.15, 1.6, 0.15), DARK)
		det.add_grad("cyl", Vector3(txp, h + 2.6, d * 0.15), Vector3(2.6, 2.2, 2.6), Color(0.7, 0.74, 0.78), Color(0.5, 0.53, 0.58), Vector3.ZERO, 14)
		cols.append([Vector3(txp, h + 2.2, d * 0.15), Vector3(2.7, 3.6, 2.7), 0.0])
	if "g" in ext and roof_t == "flat":   # çatı bahçesi: saksı ağaçları + çit
		# 2026-11-25 (kullanıcı: "süsler çok basic"): kutu + tek top yerine kenar başlıklı ahşap saksı, toprak, farklı tonlarda
		# yaprak kümeleri / gövdeli küçük ağaç / çiçek öbeği, saksıların arasında taş fener ve alçak bank
		var leaf = [Color(0.3, 0.55, 0.28), Color(0.24, 0.47, 0.25), Color(0.38, 0.62, 0.3)]
		var fl_c = [Color(0.95, 0.55, 0.65), Color(0.98, 0.95, 0.85), Color(0.95, 0.8, 0.3), Color(0.75, 0.45, 0.8)]
		for k in 4:
			var gx = -w * 0.35 + k * w * 0.23
			var gz = d * 0.3
			var py = h + 0.5
			det.add("box", Vector3(gx, py + 0.3, gz), Vector3(1.5, 0.6, 1.5), Color(0.46, 0.31, 0.2))
			for e in 3:   # yatay tahta derzleri
				det.add("box", Vector3(gx, py + 0.12 + e * 0.2, gz - 0.76), Vector3(1.5, 0.03, 0.03), Color(0.32, 0.21, 0.13))
			det.add("box", Vector3(gx, py + 0.63, gz), Vector3(1.66, 0.08, 1.66), Color(0.36, 0.24, 0.15))   # kenar başlığı
			det.add("box", Vector3(gx, py + 0.6, gz), Vector3(1.3, 0.04, 1.3), Color(0.3, 0.22, 0.15))   # toprak
			for sx in [-1.0, 1.0]:   # ayaklar
				for sz in [-1.0, 1.0]:
					det.add("box", Vector3(gx + sx * 0.62, py + 0.04, gz + sz * 0.62), Vector3(0.2, 0.1, 0.2), Color(0.3, 0.2, 0.12))
			var kind = (i + k) % 3
			if kind == 0:   # yuvarlak budanmış çalı: farklı boy ve tonda 4 küme
				for q in 4:
					var a = q * 1.7 + float(i)
					var r = 0.0 if q == 0 else 0.38
					var sc = 1.0 if q == 0 else 0.7
					det.add("sphere", Vector3(gx + cos(a) * r, py + 1.15 + (0.2 if q == 0 else -0.05), gz + sin(a) * r), Vector3(1.0, 0.85, 1.0) * sc, leaf[(q + k) % 3], Vector3.ZERO, 8)
			elif kind == 1:   # gövdeli küçük ağaç (taç 3 küme)
				det.add("cyl", Vector3(gx, py + 1.2, gz), Vector3(0.14, 1.2, 0.14), Color(0.4, 0.28, 0.18), Vector3.ZERO, 6)
				for q in 3:
					var a2 = q * 2.1 + float(k)
					det.add("sphere", Vector3(gx + cos(a2) * 0.32, py + 2.0 + q * 0.12, gz + sin(a2) * 0.32), Vector3(0.95, 0.75, 0.95), leaf[q], Vector3.ZERO, 8)
			else:   # çiçek öbeği: alçak yeşillik + renkli çiçek başları
				det.add("sphere", Vector3(gx, py + 0.8, gz), Vector3(1.2, 0.5, 1.2), leaf[1], Vector3.ZERO, 8)
				for q in 7:
					var a3 = q * 0.9 + float(i)
					var r3 = 0.15 + (q % 3) * 0.17
					det.add("sphere", Vector3(gx + cos(a3) * r3, py + 1.0 + (q % 2) * 0.06, gz + sin(a3) * r3), Vector3(0.18, 0.14, 0.18), fl_c[(q + k) % 4], Vector3.ZERO, 6)
		# taş fener (ortadaki iki saksının arası) + alçak bank (önde)
		var lx = -w * 0.35 + 1.5 * w * 0.23
		det.add("box", Vector3(lx, h + 0.6, d * 0.3), Vector3(0.5, 0.2, 0.5), Color(0.6, 0.6, 0.58))
		det.add("box", Vector3(lx, h + 0.95, d * 0.3), Vector3(0.2, 0.5, 0.2), Color(0.62, 0.62, 0.6))
		det.add("box", Vector3(lx, h + 1.32, d * 0.3), Vector3(0.42, 0.3, 0.42), Color(0.95, 0.88, 0.62))
		det.add("cone", Vector3(lx, h + 1.6, d * 0.3), Vector3(0.75, 0.28, 0.75), Color(0.58, 0.58, 0.56), Vector3.ZERO, 6)
		det.add("box", Vector3(0, h + 0.95, -d * 0.05), Vector3(2.4, 0.1, 0.5), Color(0.5, 0.35, 0.22))
		for sx in [-1.0, 1.0]:
			det.add("box", Vector3(sx * 1.0, h + 0.72, -d * 0.05), Vector3(0.12, 0.45, 0.45), Color(0.36, 0.24, 0.15))
	if plan not in ["T", "terrace", "overhang", "court"]:
		HouseKit._front_decor(det, w, d, 0, rng)
	# yerleşim ayak izi: bütün görünen parçaların gerçek kapladığı alan (kanat, veranda, avlu duvarı, saçak, merdiven);
	# ev bu alanın ortasına kaydırılır -> Placer'ın w/d dikdörtgeni evi tam sarar, hiçbir parça yola / komşuya taşmaz
	var lo = Vector3(1e9, 0, 1e9); var hi = Vector3(-1e9, 0, -1e9)
	for mb in [walls, roof, det]:
		for v in mb.verts:
			lo.x = minf(lo.x, v.x); lo.z = minf(lo.z, v.z); hi.x = maxf(hi.x, v.x); hi.z = maxf(hi.z, v.z)
	var off = Vector3(-(lo.x + hi.x) * 0.5, 0, -(lo.z + hi.z) * 0.5)
	for mb in [walls, roof, det]:
		for k in mb.verts.size():
			mb.verts[k] += off
	for c in cols:
		c[0] = c[0] + off
	var fw = hi.x - lo.x + 0.4
	var fdp = hi.z - lo.z + 0.4
	var hulls: Array = []
	for rp in roof_prims:
		var hm = MB.new()
		if rp[0] == "hip":
			_hip(hm, rp[1] + off, rp[2].x, rp[2].z, rp[2].y, Color(1, 1, 1))
		else:
			hm.add(rp[0], rp[1] + off, rp[2], Color(1, 1, 1), rp[3], rp[4])
		hulls.append(HouseKit._hull(hm))
	roof_prims.clear()
	var arch = 0
	if floors >= 4:
		arch = 4
	elif "a" in ext or "k" in ext or "v" in ext:
		arch = 3
	elif floors == 3:
		arch = 1
	# gövde çarpışması "cols" içinde (her duvar kütlesi kendi kutusu); Placer'ın zorunlu gövde şekli yalnız küçük iç çekirdek
	var body = BoxShape3D.new()
	body.size = Vector3(0.3, 0.3, 0.3)
	return {"walls": walls.build(), "roof": roof.build(), "detail": det.build(), "w": fw, "d": fdp, "h": h, "roof_top": roof_top, "cols": cols,
		"arch": arch, "roof_shape": hulls[0], "body_shape": body, "extra_shapes": hulls.slice(1), "variety": i % SPECS.size(), "plan": plan, "roof_t": roof_t}


## Gerçek kırma çatı: dikdörtgen taban (w x d, taban merkezi b), uzun kenar boyunca mahya, kapalı alt yüz.
## (eski yol 4 dilimli koniyi ölçekleyip 45° döndürüyordu: kare olmayan evde çatı eğik eşkenar dörtgen oluyordu)
static func _hip(mb: MB, b: Vector3, w: float, d: float, h: float, col: Color) -> void:
	var hw = w * 0.5; var hd = d * 0.5
	var A = b + Vector3(-hw, 0, -hd); var B = b + Vector3(hw, 0, -hd); var C = b + Vector3(hw, 0, hd); var D = b + Vector3(-hw, 0, hd)
	var r0: Vector3; var r1: Vector3
	if w >= d:
		r0 = b + Vector3(-(hw - hd), h, 0); r1 = b + Vector3(hw - hd, h, 0)
	else:
		r0 = b + Vector3(0, h, -(hd - hw)); r1 = b + Vector3(0, h, hd - hw)
	var tris: Array
	if w >= d:
		tris = [[A, B, r1], [A, r1, r0], [C, D, r0], [C, r0, r1], [B, C, r1], [D, A, r0]]
	else:
		tris = [[A, B, r0], [B, C, r1], [B, r1, r0], [C, D, r1], [D, A, r0], [D, r0, r1]]
	tris.append_array([[A, C, B], [A, D, C]])   # alt yüz
	for t in tris:
		var a: Vector3 = t[0]; var bb: Vector3 = t[1]; var c: Vector3 = t[2]
		var nrm = (bb - a).cross(c - a)
		if nrm.length() < 1e-6:
			continue
		nrm = nrm.normalized()
		var cen = (a + bb + c) / 3.0
		var out = (cen - (b + Vector3(0, h * 0.3, 0))).normalized()
		if nrm.dot(out) < 0.0:   # dışa baksın
			var tmp = bb; bb = c; c = tmp
			nrm = -nrm
		var base = mb.verts.size()
		for v in [a, c, bb]:   # Godot ön yüz: dışarıdan saat yönü
			mb.verts.append(v)
			mb.normals.append(nrm)
			mb.colors.append(col)
			mb.uvs.append(Vector2(v.x, v.z) * 0.25)
		mb.idx.append_array([base, base + 1, base + 2])


## Çatı: türüne göre ana çatı (rcm verilirse çarpışma şekli de) + saçak / mahya ayrıntısı. Çatının en üst yüksekliğini döndürür.
static var roof_fill: Array = []   # _roof'un gövde rengiyle doldurulacak kutuları (tek eğimli çatının altı)
static var roof_prims: Array = []  # her çatı parçası ayrı dışbükey çarpışma (birleşik gövde vadileri doldurup görünmez duvar yapıyordu)
static func _roof(roof: MB, det: MB, collide: bool, t: String, cx: float, cz: float, w: float, d: float, y: float, rng: RandomNumberGenerator) -> float:
	var white = Color(1, 1, 1)
	var add = func(kind: String, p: Vector3, s: Vector3, rot := Vector3.ZERO, seg := 16) -> void:
		if kind == "hip":   # p: taban merkezi, s: (gen, yükseklik, der)
			_hip(roof, p, s.x, s.z, s.y, white)
		else:
			roof.add(kind, p, s, white, rot, seg)
		if collide:
			roof_prims.append([kind, p, s, rot, mini(seg, 12)])
	match t:
		"gable":
			var rh = 2.2 + d * 0.12
			add.call("prism", Vector3(cx, y + rh * 0.5, cz), Vector3(w + 1.8, rh, d + 1.8))
			det.add("box", Vector3(cx, y + rh + 0.1, cz), Vector3(0.45, 0.3, d + 2.0), DARK)
			det.add("box", Vector3(cx, y + 0.06, cz), Vector3(w + 2.0, 0.14, d + 2.0), DARK)
			return y + rh
		"hip":
			var rh2 = 2.0 + minf(w, d) * 0.14
			add.call("hip", Vector3(cx, y, cz), Vector3(w + 1.8, rh2, d + 1.8))
			det.add("box", Vector3(cx, y + 0.06, cz), Vector3(w + 2.0, 0.14, d + 2.0), DARK)
			return y + rh2
		"barrel":
			var rise = clampf(d * 0.16, 1.1, 1.9)
			add.call("halfcyl", Vector3(cx, y + 0.1, cz), Vector3(w + 0.8, rise * 2.0, d + 1.2))
			det.add("box", Vector3(cx, y + 0.05, cz), Vector3(w + 1.0, 0.2, d + 1.3), DARK)
			return y + 0.1 + rise
		"flat":
			add.call("box", Vector3(cx, y + 0.2, cz), Vector3(w + 0.5, 0.4, d + 0.5))
			for sx in [-1.0, 1.0]:
				det.add("box", Vector3(cx + sx * (w * 0.5 + 0.2), y + 0.75, cz), Vector3(0.18, 0.7, d + 0.5), STONE_L)
			for sz in [-1.0, 1.0]:
				det.add("box", Vector3(cx, y + 0.75, cz + sz * (d * 0.5 + 0.2)), Vector3(w + 0.5, 0.7, 0.18), STONE_L)
			return y + 0.4
		"shed":   # tek eğimli (arkaya yükselir)
			var ang = 14.0
			var rise2 = tan(deg_to_rad(ang)) * (d + 1.6)
			var sl = (d + 0.9) / cos(deg_to_rad(ang))
			add.call("box", Vector3(cx, y + rise2 * 0.5 + 0.35, cz), Vector3(w + 0.9, 0.55, sl), Vector3(-ang, 0, 0))
			# alın tahtası yalnız kenarlarda (eskiden çatının tamamını koyu levha örtüyordu)
			for sx in [-1.0, 1.0]:
				det.add("box", Vector3(cx + sx * (w * 0.5 + 0.47), y + rise2 * 0.5 + 0.35, cz), Vector3(0.12, 0.7, sl + 0.1), DARK, Vector3(-ang, 0, 0))
			det.add("box", Vector3(cx, y + 0.12, cz - (d + 0.9) * 0.5), Vector3(w + 1.0, 0.3, 0.14), DARK)
			det.add("box", Vector3(cx, y + rise2 + 0.55, cz + (d + 0.9) * 0.5), Vector3(w + 1.0, 0.3, 0.14), DARK)
			# çatının altı: eğimi izleyen basamaklı dolgu duvar (gövde rengiyle) — boşluk kalmasın, içine girilmesin
			# (kullanıcı 2026-11-25: çatı havada duruyordu, duvar tepesiyle çatı arasına girilebiliyordu)
			for k in 6:
				var zk = cz - d * 0.5 + (k + 0.5) * d / 6.0
				var hk = rise2 * (k + 1.0) / 6.0 + 0.3
				roof_fill.append([Vector3(cx, y + hk * 0.5, zk), Vector3(w, hk, d / 6.0 + 0.02)])
			return y + rise2 + 0.6
		"irimoya":   # alt kırma etek + üstte küçük beşik (kalkan duvarlı)
			var rh3 = 1.6 + d * 0.06
			add.call("hip", Vector3(cx, y, cz), Vector3(w + 2.4, rh3, d + 2.4))
			var gh = 1.8 + d * 0.05
			add.call("prism", Vector3(cx, y + rh3 * 0.75 + gh * 0.5, cz), Vector3(w * 0.55, gh, d * 0.75))
			det.add("box", Vector3(cx, y + rh3 * 0.75 + gh + 0.08, cz), Vector3(0.45, 0.3, d * 0.8), DARK)
			return y + rh3 * 0.75 + gh
		"tiered":   # kat kat saçak: gövde üstünde iki kademe kırma çatı
			var r1 = 1.4
			add.call("hip", Vector3(cx, y, cz), Vector3(w + 2.6, r1, d + 2.6))
			roof_fill.append([Vector3(cx, y + r1 * 0.7 + 1.0, cz), Vector3(w * 0.55, 2.0, d * 0.55)])   # üst kat: duvar rengi
			var r2 = 1.6
			add.call("hip", Vector3(cx, y + r1 * 0.7 + 2.0, cz), Vector3(w * 0.55 + 2.0, r2, d * 0.55 + 2.0))
			det.add("box", Vector3(cx, y + r1 * 0.7 + 2.0 + r2 + 0.4, cz), Vector3(0.3, 0.8, 0.3), DARK)
			return y + r1 * 0.7 + 2.0 + r2
		"saw":   # çoklu beşik: cepheye paralel üç kapalı beşik çatı yan yana (sıra ev / atölye çatısı)
			var rh4 = 1.9
			for k in 3:
				var zz = cz - d * 0.5 + (k + 0.5) * d / 3.0
				add.call("prism", Vector3(cx, y + rh4 * 0.5, zz), Vector3(d / 3.0 + 0.5, rh4, w + 1.0), Vector3(0, 90, 0), 4)
				det.add("box", Vector3(cx, y + rh4 + 0.06, zz), Vector3(w + 1.1, 0.22, 0.3), DARK)
			det.add("box", Vector3(cx, y + 0.06, cz), Vector3(w + 1.1, 0.14, d + 0.6), DARK)
			return y + rh4
	return y


## Cephe kaplaması (detay katmanı, sabit renk): pencereler + malzeme. main: ana kütle mi (kapı açıklığı bırakılır)
static func _facade(det: MB, face: String, cx: float, cz: float, w: float, d: float, floors: int, fh: float, rng: RandomNumberGenerator, main: bool, yb := 0.0) -> void:
	if floors <= 0:
		return
	for f in floors:
		var y0 = 0.5 + yb + f * fh
		# kat kirişi
		det.add("box", Vector3(cx, y0 + fh - 0.1, cz), Vector3(w + 0.2, 0.22, d + 0.2), WOOD if face != "brick" else BRICK.darkened(0.2))
		var nw = maxi(1, int(w / 3.2))
		for k in nw:
			var x = cx - w * 0.5 + (k + 0.5) * w / nw
			if main and f == 0 and absf(x - cx) < 1.8:
				continue
			HouseKit._window(det, Vector3(x, y0 + fh * 0.55, cz - d * 0.5), 0.0, rng)
			if rng.randf() < 2.0:   # arka cephe hep pencereli (2026-11-25: arkası düz kutu kalan evler "bu ne?")
				HouseKit._window(det, Vector3(x, y0 + fh * 0.55, cz + d * 0.5), 180.0, rng)
		for sx in [-1.0, 1.0]:
			if rng.randf() < 0.7:
				HouseKit._window(det, Vector3(cx + sx * w * 0.5, y0 + fh * 0.55, cz + rng.randf_range(-d * 0.2, d * 0.2)), 90.0 * sx, rng)
	var H = floors * fh
	var B = 0.5 + yb   # bu kütlenin taban yüksekliği
	match face:
		"timber":   # köşe ve ara dikmeler (yarı ahşap)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					det.add("box", Vector3(cx + sx * w * 0.5, B + H * 0.5, cz + sz * d * 0.5), Vector3(0.26, H, 0.26), WOOD)
			for k in int(w / 4.0):
				det.add("box", Vector3(cx - w * 0.5 + (k + 1) * w / (int(w / 4.0) + 1), B + H * 0.5, cz - d * 0.5 - 0.03), Vector3(0.18, H, 0.08), WOOD)
		"lattice" when yb == 0.0:   # zemin katı koyu ahşap kafes (koshi), üstü sıva
			det.add("box", Vector3(cx, B + fh * 0.5, cz - d * 0.5 - 0.04), Vector3(w, fh, 0.06), WOOD_D)
			for k in int(w / 0.3):
				var lx = cx - w * 0.5 + (k + 0.5) * 0.3
				if main and absf(lx - cx) < 1.4:
					continue
				det.add("box", Vector3(lx, B + fh * 0.45, cz - d * 0.5 - 0.1), Vector3(0.08, fh * 0.8, 0.08), WOOD)
		"siding":   # yatay ahşap kaplama (bütün yüzler, ön cephe ağırlıklı)
			for k in int(H / 0.55):
				var yy = B + 0.3 + k * 0.55
				det.add("box", Vector3(cx, yy, cz - d * 0.5 - 0.03), Vector3(w + 0.04, 0.06, 0.05), WOOD_D)
				det.add("box", Vector3(cx, yy, cz + d * 0.5 + 0.03), Vector3(w + 0.04, 0.06, 0.05), WOOD_D)
			det.add("box", Vector3(cx, B + H * 0.5, cz - d * 0.5 - 0.015), Vector3(w, H, 0.02), WOOD_L)
		"stone" when yb == 0.0:   # taş kaide (zemin katın alt yarısı) + köşe taşları
			det.add("box", Vector3(cx, 0.5 + 0.9, cz), Vector3(w + 0.16, 1.8, d + 0.16), STONE)
			for k in int(w / 1.2):
				det.add("box", Vector3(cx - w * 0.5 + (k + 0.5) * 1.2, 0.5 + 0.9, cz - d * 0.5 - 0.1), Vector3(0.05, 1.8, 0.04), STONE.darkened(0.25))
			for sx in [-1.0, 1.0]:
				for k in int(H / 0.9):
					det.add("box", Vector3(cx + sx * (w * 0.5 + 0.02), B + 0.45 + k * 0.9, cz - d * 0.5 + 0.4), Vector3(0.12, 0.6, 0.9), STONE_L)
		"brick":   # tuğla bantlar (her kat ortasında ve altında)
			for f in floors:
				for k in 3:
					det.add("box", Vector3(cx, B + f * fh + 0.2 + k * 0.22, cz - d * 0.5 - 0.04), Vector3(w + 0.04, 0.14, 0.06), BRICK)
			for sx in [-1.0, 1.0]:
				det.add("box", Vector3(cx + sx * w * 0.5, B + H * 0.5, cz - d * 0.5), Vector3(0.6, H, 0.3), BRICK)
		"band":   # renkli kat bandı (Konoha apartman şeridi)
			var bc = [Color(0.85, 0.35, 0.25), Color(0.3, 0.5, 0.75), Color(0.35, 0.6, 0.4), Color(0.9, 0.65, 0.25)][rng.randi() % 4]
			for f in floors:
				det.add("box", Vector3(cx, B + f * fh + 0.25, cz), Vector3(w + 0.12, 0.4, d + 0.12), bc)
