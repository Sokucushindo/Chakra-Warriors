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
	var rcm = MB.new()
	var cols: Array = []
	var white = Color(1, 1, 1)
	# ana kütle ölçüleri plana göre
	var w: float; var d: float
	match plan:
		"narrow": w = rng.randf_range(8.0, 10.0); d = rng.randf_range(9.0, 11.0)
		"row": w = rng.randf_range(20.0, 26.0); d = rng.randf_range(8.5, 10.0)
		"court", "porch": w = rng.randf_range(11.0, 14.0); d = rng.randf_range(9.0, 11.0)
		"twin": w = rng.randf_range(8.0, 10.0); d = rng.randf_range(9.0, 11.0)
		_: w = rng.randf_range(11.0, 15.0); d = rng.randf_range(9.5, 12.5)
	var h = 0.5 + floors * fh
	# kanatlar: [merkez x, merkez z, gen, der, kat] (ana kütlenin dışında)
	var wings: Array = []
	match plan:
		"L": wings.append([w * 0.5 + 3.0, d * 0.2, 6.0, d * 0.6 + 2.0, maxi(1, floors - 1)])
		"T": wings.append([0.0, -d * 0.5 - 2.5, w * 0.5, 5.0, maxi(1, floors - 1)])
		"twin": wings.append([w + 3.0, 0.0, w, d, floors])
		"tower_corner": pass
		"terrace": wings.append([0.0, -d * 0.5 - 3.0, w, 6.0, maxi(1, floors - 1)]); wings.append([0.0, -d * 0.5 - 8.5, w, 5.0, maxi(1, floors - 2)])
	# --- gövde
	det.add("box", Vector3(0, 0.25, 0), Vector3(w + 0.4, 0.5, d + 0.4), STONE)
	match plan:
		"setback":   # üst kat(lar) geri çekilir (önde teras)
			walls.add("box", Vector3(0, 0.5 + fh * 0.5, 0), Vector3(w, fh, d), white)
			var uh = (floors - 1) * fh
			walls.add("box", Vector3(0, 0.5 + fh + uh * 0.5, d * 0.15), Vector3(w * 0.85, uh, d * 0.7), white)
			det.add("box", Vector3(0, 0.5 + fh + 0.5, -d * 0.5 + 0.1), Vector3(w, 0.9, 0.15), WOOD_L)   # teras korkuluğu
		"overhang":  # üst kat öne taşar, altında dikmeler
			walls.add("box", Vector3(0, 0.5 + fh * 0.5, d * 0.1), Vector3(w, fh, d * 0.8), white)
			var uh2 = (floors - 1) * fh
			walls.add("box", Vector3(0, 0.5 + fh + uh2 * 0.5, -0.4), Vector3(w + 0.6, uh2, d + 0.8), white)
			for sx in [-1.0, 1.0]:
				det.add("box", Vector3(sx * (w * 0.5 - 0.2), 0.5 + fh * 0.5, -d * 0.5 - 0.6), Vector3(0.3, fh, 0.3), WOOD_D)
		_:
			walls.add("box", Vector3(0, 0.5 + (h - 0.5) * 0.5, 0), Vector3(w, h - 0.5, d), white)
	for wg in wings:
		var wh = 0.5 + int(wg[4]) * fh
		walls.add("box", Vector3(wg[0], wh * 0.5 + 0.25, wg[1]), Vector3(wg[2], wh - 0.5, wg[3]), white)
		det.add("box", Vector3(wg[0], 0.25, wg[1]), Vector3(wg[2] + 0.3, 0.5, wg[3] + 0.3), STONE)
		cols.append([Vector3(wg[0], wh * 0.5, wg[1]), Vector3(wg[2], wh, wg[3]), 0.0])
		_roof(roof, det, null, roof_t if roof_t != "saw" else "flat", wg[0], wg[1], wg[2], wg[3], wh, rng)
		cols.append([Vector3(wg[0], wh + 0.6, wg[1]), Vector3(wg[2] + 0.6, 1.2, wg[3] * 0.7), 0.0])
		_facade(det, face, wg[0], wg[1], wg[2], wg[3], int(wg[4]), fh, rng, false)
	if plan == "twin":   # iki blok arası kapalı köprü
		var by = 0.5 + (floors - 1) * fh
		walls.add("box", Vector3(w * 0.5 + 1.5, by + fh * 0.5, 0), Vector3(3.2, fh, d * 0.45), white)
		cols.append([Vector3(w * 0.5 + 1.5, by + fh * 0.5, 0), Vector3(3.2, fh, d * 0.45), 0.0])
	if plan == "tower_corner":   # sağ ön köşede yuvarlak kule, gövdeden bir kat yüksek
		var tr = 2.6
		var th = h + fh
		walls.add("cyl", Vector3(w * 0.5, th * 0.5, -d * 0.5), Vector3(tr * 2.0, th, tr * 2.0), white, Vector3.ZERO, 16)
		roof.add("cone", Vector3(w * 0.5, th + 1.3, -d * 0.5), Vector3(tr * 2.0 + 1.2, 2.6, tr * 2.0 + 1.2), white, Vector3.ZERO, 16)
		for f in floors + 1:
			HouseKit._window(det, Vector3(w * 0.5 + 0.2, 0.5 + f * fh + fh * 0.55, -d * 0.5 - tr - 0.02), 0.0, rng)
		cols.append([Vector3(w * 0.5, th * 0.5, -d * 0.5), Vector3(tr * 2.0, th, tr * 2.0), 0.0])
	if plan == "court":   # önde avlu duvarı + kapı (yarı açık)
		for sx in [-1.0, 1.0]:
			det.add("box", Vector3(sx * (w * 0.5 + 0.1), 1.1, -d * 0.5 - 2.6), Vector3(0.4, 2.2, 5.2), STONE_L)
			det.add("box", Vector3(sx * (w * 0.3 + 1.0), 1.1, -d * 0.5 - 5.2), Vector3(w * 0.4 - 1.6, 2.2, 0.4), STONE_L)
			cols.append([Vector3(sx * (w * 0.5 + 0.1), 1.1, -d * 0.5 - 2.6), Vector3(0.4, 2.2, 5.2), 0.0])
			cols.append([Vector3(sx * (w * 0.3 + 1.0), 1.1, -d * 0.5 - 5.2), Vector3(w * 0.4 - 1.6, 2.2, 0.4), 0.0])
		det.add("box", Vector3(0, 2.6, -d * 0.5 - 5.2), Vector3(3.6, 0.3, 1.0), DARK)   # kapı saçağı
	# --- ana çatı + cephe
	var top = h if plan != "setback" else h
	var tz = d * 0.15 if plan == "setback" else (-0.4 if plan == "overhang" else 0.0)
	var tw = w * 0.85 if plan == "setback" else (w + 0.6 if plan == "overhang" else w)
	var td = d * 0.7 if plan == "setback" else (d + 0.8 if plan == "overhang" else d)
	var roof_top = _roof(roof, det, rcm, roof_t, 0.0, tz, tw, td, top, rng)
	_facade(det, face, 0.0, 0.0, w, d, floors, fh, rng, true)
	# kapı
	var drng = RandomNumberGenerator.new()
	drng.seed = 7000 + i
	DoorKit.jp_template(det, -d * 0.5, 0.5, "a" in ext or "k" in ext, drng)
	# --- ekler
	if "b" in ext and floors >= 2:
		var by2 = 0.5 + fh
		det.add("box", Vector3(0, by2, -d * 0.5 - 0.7), Vector3(w * 0.6, 0.18, 1.4), WOOD)
		for k in 7:
			det.add("box", Vector3(-w * 0.3 + k * w * 0.1, by2 + 0.5, -d * 0.5 - 1.35), Vector3(0.08, 0.9, 0.08), WOOD_L)
		det.add("box", Vector3(0, by2 + 0.95, -d * 0.5 - 1.35), Vector3(w * 0.6, 0.1, 0.1), WOOD)
		cols.append([Vector3(0, by2, -d * 0.5 - 0.7), Vector3(w * 0.6, 0.25, 1.4), 0.0])
	if "w" in ext and floors >= 2:   # cumba (çıkma pencere)
		var wy = 0.5 + fh * 1.5
		det.add("box", Vector3(-w * 0.22, wy, -d * 0.5 - 0.6), Vector3(3.0, fh * 0.75, 1.2), Color(0.85, 0.83, 0.78))
		det.add("box", Vector3(-w * 0.22, wy, -d * 0.5 - 1.22), Vector3(2.4, fh * 0.5, 0.06), GLASS)
		det.add("box", Vector3(-w * 0.22, wy + fh * 0.42, -d * 0.5 - 0.6), Vector3(3.3, 0.18, 1.5), DARK)
	if "e" in ext:   # engawa veranda: önde ahşap döşeme + saçak + dikmeler
		det.add("box", Vector3(0, 0.6, -d * 0.5 - 1.0), Vector3(w - 0.4, 0.2, 2.0), WOOD_L)
		det.add("box", Vector3(0, 3.1, -d * 0.5 - 1.1), Vector3(w + 0.4, 0.16, 2.4), Color(0.3, 0.3, 0.32), Vector3(-12, 0, 0))
		for k in 4:
			det.add("box", Vector3(-w * 0.45 + k * w * 0.3, 1.8, -d * 0.5 - 1.9), Vector3(0.18, 2.6, 0.18), WOOD)
		cols.append([Vector3(0, 0.6, -d * 0.5 - 1.0), Vector3(w - 0.4, 0.25, 2.0), 0.0])
	if "a" in ext:   # dükkân tentesi + tezgâh
		var ac = [Color(0.85, 0.3, 0.25), Color(0.25, 0.5, 0.75), Color(0.95, 0.7, 0.3), Color(0.35, 0.6, 0.35)][i % 4]
		det.add("box", Vector3(0, 0.5 + 2.9, -d * 0.5 - 0.9), Vector3(w * 0.85, 0.12, 1.8), ac, Vector3(-14, 0, 0))
		det.add("box", Vector3(-w * 0.25, 0.5 + 0.5, -d * 0.5 - 0.5), Vector3(w * 0.35, 1.0, 0.7), WOOD_L)
	if "k" in ext:   # kepenkli dükkân cephesi (zemin katı sürgülü kepenk çizgileri)
		for k in 8:
			det.add("box", Vector3(w * 0.2, 0.7 + k * 0.28, -d * 0.5 - 0.06), Vector3(w * 0.35, 0.05, 0.05), Color(0.55, 0.56, 0.58))
	if "v" in ext:   # dikey tabela
		var vc = [Color(0.85, 0.2, 0.15), Color(0.95, 0.92, 0.8), Color(0.2, 0.3, 0.55), Color(0.95, 0.75, 0.2)][i % 4]
		det.add("box", Vector3(w * 0.5 + 0.35, 0.5 + fh * 1.5, -d * 0.5 + 1.0), Vector3(0.2, fh * 1.8, 1.1), vc)
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
	if "t" in ext and roof_t in ["flat", "saw"]:   # su tankı
		var txp = rng.randf_range(-w * 0.2, w * 0.2)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				det.add("box", Vector3(txp + sx * 0.8, h + 1.0, d * 0.15 + sz * 0.8), Vector3(0.15, 1.6, 0.15), DARK)
		det.add_grad("cyl", Vector3(txp, h + 2.6, d * 0.15), Vector3(2.6, 2.2, 2.6), Color(0.7, 0.74, 0.78), Color(0.5, 0.53, 0.58), Vector3.ZERO, 14)
		cols.append([Vector3(txp, h + 2.2, d * 0.15), Vector3(2.7, 3.6, 2.7), 0.0])
	if "g" in ext and roof_t == "flat":   # çatı bahçesi: saksı ağaçları + çit
		for k in 4:
			var gx = -w * 0.35 + k * w * 0.23
			det.add("box", Vector3(gx, h + 0.75, d * 0.3), Vector3(1.4, 0.6, 1.4), Color(0.5, 0.35, 0.25))
			det.add("sphere", Vector3(gx, h + 1.7, d * 0.3), Vector3(1.5, 1.4, 1.5), Color(0.32, 0.58, 0.3), Vector3.ZERO, 8)
	HouseKit._front_decor(det, w, d, 0, rng)
	# yerleşim ayak izi: kanatlar dahil
	var minx = -w * 0.5; var maxx = w * 0.5; var minz = -d * 0.5; var maxz = d * 0.5
	for wg in wings:
		minx = minf(minx, float(wg[0]) - float(wg[2]) * 0.5); maxx = maxf(maxx, float(wg[0]) + float(wg[2]) * 0.5)
		minz = minf(minz, float(wg[1]) - float(wg[3]) * 0.5); maxz = maxf(maxz, float(wg[1]) + float(wg[3]) * 0.5)
	if plan == "tower_corner":
		maxx = maxf(maxx, w * 0.5 + 2.6); minz = minf(minz, -d * 0.5 - 2.6)
	if plan == "court":
		minz = minf(minz, -d * 0.5 - 5.4)
	var fw = 2.0 * maxf(absf(minx), absf(maxx)) + 0.6
	var fdp = 2.0 * maxf(absf(minz), absf(maxz)) + 0.6
	var arch = 0
	if floors >= 4:
		arch = 4
	elif "a" in ext or "k" in ext or "v" in ext:
		arch = 3
	elif floors == 3:
		arch = 1
	var body = BoxShape3D.new()
	body.size = Vector3(w, h, d) if plan not in ["setback", "overhang"] else Vector3(w, 0.5 + fh, d * 0.8)
	var extra: Array = []
	if plan in ["setback", "overhang"]:
		var up = BoxShape3D.new()
		up.size = Vector3(tw, h - (0.5 + fh), td)
		cols.append([Vector3(0, 0.5 + fh + (h - 0.5 - fh) * 0.5, tz), Vector3(tw, h - 0.5 - fh, td), 0.0])
	return {"walls": walls.build(), "roof": roof.build(), "detail": det.build(), "w": fw, "d": fdp, "h": h, "roof_top": roof_top, "cols": cols,
		"arch": arch, "roof_shape": HouseKit._hull(rcm), "body_shape": body, "extra_shapes": extra, "variety": i % SPECS.size()}


## Çatı: türüne göre ana çatı (rcm verilirse çarpışma şekli de) + saçak / mahya ayrıntısı. Çatının en üst yüksekliğini döndürür.
static func _roof(roof: MB, det: MB, rcm, t: String, cx: float, cz: float, w: float, d: float, y: float, rng: RandomNumberGenerator) -> float:
	var white = Color(1, 1, 1)
	var add = func(kind: String, p: Vector3, s: Vector3, rot := Vector3.ZERO, seg := 16) -> void:
		roof.add(kind, p, s, white, rot, seg)
		if rcm != null:
			rcm.add(kind, p, s, white, rot, mini(seg, 12))
	match t:
		"gable":
			var rh = 2.2 + d * 0.12
			add.call("prism", Vector3(cx, y + rh * 0.5, cz), Vector3(w + 1.8, rh, d + 1.8))
			det.add("box", Vector3(cx, y + rh + 0.1, cz), Vector3(0.45, 0.3, d + 2.0), DARK)
			det.add("box", Vector3(cx, y + 0.06, cz), Vector3(w + 2.0, 0.14, d + 2.0), DARK)
			return y + rh
		"hip":
			var rh2 = 2.0 + minf(w, d) * 0.14
			add.call("cone", Vector3(cx, y + rh2 * 0.5, cz), Vector3((w + 1.8) * 1.414, rh2, (d + 1.8) * 1.414), Vector3(0, 45, 0), 4)
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
			det.add("box", Vector3(cx, y + rise2 * 0.5 + 0.35, cz), Vector3(w + 1.0, 0.65, sl + 0.1), DARK, Vector3(-ang, 0, 0))
			# yan üçgen duvarlar (eğimin altı boş kalmasın)
			for sx in [-1.0, 1.0]:
				det.add("box", Vector3(cx + sx * w * 0.5, y + rise2 * 0.25, cz + d * 0.2), Vector3(0.2, rise2 * 0.5, d * 0.6), Color(0.85, 0.83, 0.78))
			return y + rise2 + 0.6
		"irimoya":   # alt kırma etek + üstte küçük beşik (kalkan duvarlı)
			var rh3 = 1.6 + d * 0.06
			add.call("cone", Vector3(cx, y + rh3 * 0.5, cz), Vector3((w + 2.4) * 1.414, rh3, (d + 2.4) * 1.414), Vector3(0, 45, 0), 4)
			var gh = 1.8 + d * 0.05
			add.call("prism", Vector3(cx, y + rh3 * 0.75 + gh * 0.5, cz), Vector3(w * 0.55, gh, d * 0.75))
			det.add("box", Vector3(cx, y + rh3 * 0.75 + gh + 0.08, cz), Vector3(0.45, 0.3, d * 0.8), DARK)
			return y + rh3 * 0.75 + gh
		"tiered":   # kat kat saçak: gövde üstünde iki kademe kırma çatı
			var r1 = 1.4
			add.call("cone", Vector3(cx, y + r1 * 0.5, cz), Vector3((w + 2.6) * 1.414, r1, (d + 2.6) * 1.414), Vector3(0, 45, 0), 4)
			roof.add("box", Vector3(cx, y + r1 * 0.7 + 1.0, cz), Vector3(w * 0.55, 2.0, d * 0.55), white)
			var r2 = 1.6
			add.call("cone", Vector3(cx, y + r1 * 0.7 + 2.0 + r2 * 0.5, cz), Vector3((w * 0.55 + 2.0) * 1.414, r2, (d * 0.55 + 2.0) * 1.414), Vector3(0, 45, 0), 4)
			det.add("box", Vector3(cx, y + r1 * 0.7 + 2.0 + r2 + 0.4, cz), Vector3(0.3, 0.8, 0.3), DARK)
			return y + r1 * 0.7 + 2.0 + r2
		"saw":   # testere dişi: üç tek eğimli şerit
			for k in 3:
				var zz = cz - d * 0.5 + (k + 0.5) * d / 3.0
				add.call("box", Vector3(cx, y + 0.9, zz), Vector3(w + 0.6, 0.3, d / 3.0 / cos(deg_to_rad(28.0))), Vector3(-28, 0, 0))
				det.add("box", Vector3(cx, y + 0.9, zz + d / 6.0 - 0.1), Vector3(w + 0.4, 1.6, 0.12), GLASS)
			return y + 1.8
	return y


## Cephe kaplaması (detay katmanı, sabit renk): pencereler + malzeme. main: ana kütle mi (kapı açıklığı bırakılır)
static func _facade(det: MB, face: String, cx: float, cz: float, w: float, d: float, floors: int, fh: float, rng: RandomNumberGenerator, main: bool) -> void:
	for f in floors:
		var y0 = 0.5 + f * fh
		# kat kirişi
		det.add("box", Vector3(cx, y0 + fh - 0.1, cz), Vector3(w + 0.2, 0.22, d + 0.2), WOOD if face != "brick" else BRICK.darkened(0.2))
		var nw = maxi(1, int(w / 3.2))
		for k in nw:
			var x = cx - w * 0.5 + (k + 0.5) * w / nw
			if main and f == 0 and absf(x - cx) < 1.8:
				continue
			HouseKit._window(det, Vector3(x, y0 + fh * 0.55, cz - d * 0.5), 0.0, rng)
			if rng.randf() < 0.6:
				HouseKit._window(det, Vector3(x, y0 + fh * 0.55, cz + d * 0.5), 180.0, rng)
		for sx in [-1.0, 1.0]:
			if rng.randf() < 0.7:
				HouseKit._window(det, Vector3(cx + sx * w * 0.5, y0 + fh * 0.55, cz + rng.randf_range(-d * 0.2, d * 0.2)), 90.0 * sx, rng)
	var H = floors * fh
	match face:
		"timber":   # köşe ve ara dikmeler (yarı ahşap)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					det.add("box", Vector3(cx + sx * w * 0.5, 0.5 + H * 0.5, cz + sz * d * 0.5), Vector3(0.26, H, 0.26), WOOD)
			for k in int(w / 4.0):
				det.add("box", Vector3(cx - w * 0.5 + (k + 1) * w / (int(w / 4.0) + 1), 0.5 + H * 0.5, cz - d * 0.5 - 0.03), Vector3(0.18, H, 0.08), WOOD)
		"lattice":   # zemin katı koyu ahşap kafes (koshi), üstü sıva
			det.add("box", Vector3(cx, 0.5 + fh * 0.5, cz - d * 0.5 - 0.04), Vector3(w, fh, 0.06), WOOD_D)
			for k in int(w / 0.3):
				var lx = cx - w * 0.5 + (k + 0.5) * 0.3
				if main and absf(lx - cx) < 1.4:
					continue
				det.add("box", Vector3(lx, 0.5 + fh * 0.45, cz - d * 0.5 - 0.1), Vector3(0.08, fh * 0.8, 0.08), WOOD)
		"siding":   # yatay ahşap kaplama (bütün yüzler, ön cephe ağırlıklı)
			for k in int(H / 0.55):
				var yy = 0.5 + 0.3 + k * 0.55
				det.add("box", Vector3(cx, yy, cz - d * 0.5 - 0.03), Vector3(w + 0.04, 0.06, 0.05), WOOD_D)
				det.add("box", Vector3(cx, yy, cz + d * 0.5 + 0.03), Vector3(w + 0.04, 0.06, 0.05), WOOD_D)
			det.add("box", Vector3(cx, 0.5 + H * 0.5, cz - d * 0.5 - 0.015), Vector3(w, H, 0.02), WOOD_L)
		"stone":   # taş kaide (zemin katın alt yarısı) + köşe taşları
			det.add("box", Vector3(cx, 0.5 + 0.9, cz), Vector3(w + 0.16, 1.8, d + 0.16), STONE)
			for k in int(w / 1.2):
				det.add("box", Vector3(cx - w * 0.5 + (k + 0.5) * 1.2, 0.5 + 0.9, cz - d * 0.5 - 0.1), Vector3(0.05, 1.8, 0.04), STONE.darkened(0.25))
			for sx in [-1.0, 1.0]:
				for k in int(H / 0.9):
					det.add("box", Vector3(cx + sx * (w * 0.5 + 0.02), 0.5 + 0.45 + k * 0.9, cz - d * 0.5 + 0.4), Vector3(0.12, 0.6, 0.9), STONE_L)
		"brick":   # tuğla bantlar (her kat ortasında ve altında)
			for f in floors:
				for k in 3:
					det.add("box", Vector3(cx, 0.5 + f * fh + 0.2 + k * 0.22, cz - d * 0.5 - 0.04), Vector3(w + 0.04, 0.14, 0.06), BRICK)
			for sx in [-1.0, 1.0]:
				det.add("box", Vector3(cx + sx * w * 0.5, 0.5 + H * 0.5, cz - d * 0.5), Vector3(0.6, H, 0.3), BRICK)
		"band":   # renkli kat bandı (Konoha apartman şeridi)
			var bc = [Color(0.85, 0.35, 0.25), Color(0.3, 0.5, 0.75), Color(0.35, 0.6, 0.4), Color(0.9, 0.65, 0.25)][rng.randi() % 4]
			for f in floors:
				det.add("box", Vector3(cx, 0.5 + f * fh + 0.25, cz), Vector3(w + 0.12, 0.4, d + 0.12), bc)
