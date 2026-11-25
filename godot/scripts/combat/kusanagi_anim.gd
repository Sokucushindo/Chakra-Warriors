extends RefCounted
## Kusanagi no Tsurugi (Sasuke'nin chokutō'su): tek el, HIZLI kılıç. Uçma / uzama YOK (Orochimaru tekniği değil).
## Kaynak: Sasuke vs Samuraylar (Kage Zirvesi) + Sasuke vs Killer B, 20 fps kare kare tarif _tmp/ed/kusanagi_desc.md.
## Her vuruş: kurulma (geri çekiş, ağırlık arka ayakta) -> adım -> ağız ÖNDE şimşek kesik -> savuruş devamı -> toparlanma.
## Keskin ağız (silahın +Y'si) her anahtarda "edge" yönüne çevrilir (sap ekseni etrafında "roll"): kesikte ağız gidiş yönünde.
## Etkiler KeyedCombos (oyuncu + düşman aynı): 3 Shunshin saplama, 5 Chidori Nagashi (gövdeden boşalma), 6 Senkō geçişi.

const S = preload("res://scripts/combat/samehada_anim.gd")

# sağ kol (iskelet uzayı: +Z ön, +X karakterin solu, +Y yukarı)
const R_READY := {"RightUpperArm": Vector3(-0.2, -0.85, 0.45), "RightLowerArm": Vector3(0.2, -0.3, 0.93)}        # sağ kalça önü (bekleme)
const R_TRAIL := {"RightUpperArm": Vector3(-0.3, -0.8, -0.5), "RightLowerArm": Vector3(-0.15, -0.75, -0.65)}     # kalçanın arkasına sarkık, kılıç geri sürünür
const R_BACK := {"RightUpperArm": Vector3(-0.4, -0.45, -0.8), "RightLowerArm": Vector3(-0.35, -0.3, -0.88)}      # kol dümdüz geri (geçiş sonrası)
const R_SIDE := {"RightUpperArm": Vector3(-0.97, -0.15, 0.15), "RightLowerArm": Vector3(-0.85, -0.1, 0.5)}       # sağa yatay açık
const R_FRONT := {"RightUpperArm": Vector3(-0.15, -0.25, 0.96), "RightLowerArm": Vector3(0.25, -0.1, 0.96)}      # önde göğüs hizası
const R_ACROSS := {"RightUpperArm": Vector3(0.3, -0.4, 0.87), "RightLowerArm": Vector3(0.88, -0.15, 0.45)}       # sol önüne süpürülmüş
const R_LHIP := {"RightUpperArm": Vector3(0.25, -0.8, 0.55), "RightLowerArm": Vector3(0.85, -0.45, 0.28)}        # sol kalça önü (alçak)
const R_RISE := {"RightUpperArm": Vector3(-0.25, -0.35, 0.9), "RightLowerArm": Vector3(0.05, 0.55, 0.83)}        # göğüs önünden yükselir
const R_VERT := {"RightUpperArm": Vector3(-0.15, -0.6, 0.78), "RightLowerArm": Vector3(0.12, 0.7, 0.7)}          # el göğüs önü, kılıç dik
const R_EAR := {"RightUpperArm": Vector3(-0.45, -0.55, -0.7), "RightLowerArm": Vector3(0.05, 0.4, 0.92)}         # dirsek geride, el kulak altı (saplama kurulumu)
const R_STAB := {"RightUpperArm": Vector3(-0.04, -0.03, 1), "RightLowerArm": Vector3(0.0, -0.02, 1)}             # kol dümdüz ileri
const R_OVER := {"RightUpperArm": Vector3(-0.3, 0.93, 0.15), "RightLowerArm": Vector3(0.45, 0.88, 0.1)}          # başın üstünde (jōdan)
const R_LOWEND := {"RightUpperArm": Vector3(0.25, -0.5, 0.82), "RightLowerArm": Vector3(0.85, -0.3, 0.4)}        # sol dize inmiş
const R_LOWF := {"RightUpperArm": Vector3(0.0, -0.85, 0.52), "RightLowerArm": Vector3(0.3, -0.6, 0.74)}          # önde diz hizası (Nagashi)
const R_LOWR := {"RightUpperArm": Vector3(-0.45, -0.8, 0.4), "RightLowerArm": Vector3(-0.3, -0.6, 0.75)}         # sağ diz önü
const R_LSH := {"RightUpperArm": Vector3(0.2, -0.1, 0.97), "RightLowerArm": Vector3(0.9, 0.25, 0.3)}             # sol omuz önü
const R_HANG := {"RightUpperArm": Vector3(-0.3, -0.95, 0.1), "RightLowerArm": Vector3(-0.1, -0.85, 0.5)}         # yanda aşağı sarkık
# sol kol (kabzaya hiç gelmez)
const L_GUARD := {"LeftUpperArm": Vector3(0.3, -0.75, 0.55), "LeftLowerArm": Vector3(-0.2, 0.3, 0.93)}
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const L_OUT := {"LeftUpperArm": Vector3(0.95, -0.2, 0.2), "LeftLowerArm": Vector3(0.9, -0.15, 0.35)}             # karşı yana denge
const L_POINT := {"LeftUpperArm": Vector3(0.15, 0.05, 1), "LeftLowerArm": Vector3(0.05, 0.0, 1)}
const L_UP := {"LeftUpperArm": Vector3(0.4, 0.9, 0.15), "LeftLowerArm": Vector3(-0.35, 0.9, 0.2)}                # iki kol başın üstünde
const L_LOW := {"LeftUpperArm": Vector3(0.45, -0.8, -0.35), "LeftLowerArm": Vector3(0.3, -0.85, -0.4)}           # açık el geride-aşağı

const DOWN := Vector3(0, -1, 0)


## Keskin ağzın (+Y) istenen yöne bakması için sap ekseni etrafındaki dönüş (derece).
## CharacterModel._key_blade_sk çerçevesi: x = UP × z (dikse RIGHT), y = z × x; roll R: y' = -sin R x + cos R y.
static func edge_roll(blade: Vector3, edge: Vector3) -> float:
	var z = blade.normalized()
	var x = Vector3.UP.cross(z)
	if x.length() < 0.1:
		x = Vector3.RIGHT
	x = x.normalized()
	var y0 = z.cross(x).normalized()
	var e = edge - z * edge.dot(z)
	if e.length() < 0.05:
		return 0.0
	e = e.normalized()
	return rad_to_deg(atan2(-e.dot(x), e.dot(y0)))


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, edge: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	var k = S._k(t, crouch, yaw * 1.4, lean * 1.3, blade.normalized(), S._a(r, l), legs)
	k["roll"] = edge_roll(blade, edge)
	return k


## roll süreklilik: anahtarlar arası 180°'den büyük sıçrama olmasın (Catmull-Rom tam tur döndürmesin)
static func _unwrap(keys: Array) -> Array:
	var prev = 0.0
	for i in keys.size():
		var r = float(keys[i]["roll"])
		if i > 0:
			while r - prev > 180.0:
				r -= 360.0
			while r - prev < -180.0:
				r += 360.0
		keys[i]["roll"] = r
		prev = r
	return keys


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.1, -0.35, 0.93)
	var out = [
		# 1 Yoko Nagi (S 2:01.05-2:01.70): kılıç sağ kalçanın arkasında geri sürünür, gövde sağa kurulur ->
		#   adım + yatay süpürme sağ-arkadan öne ve sola, ağız önde; sol kol karşı yana denge
		{"len": 0.55, "hit": 0.24, "keys": [
			_t(0.0, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
			_t(0.1, 0.46, -22, 14, Vector3(-0.3, -0.45, -0.85), Vector3(-1, 0, 0.2), R_TRAIL, L_POINT, BK),
			_t(0.16, 0.48, -26, 16, Vector3(-0.35, -0.4, -0.85), Vector3(-1, 0, 0.2), R_TRAIL, L_POINT, BK),
			_t(0.2, 0.44, -14, 18, Vector3(-0.95, -0.05, 0.1), Vector3(0, 0, 1), R_SIDE, L_OUT, ST),
			_t(0.24, 0.42, 6, 20, Vector3(-0.35, -0.05, 0.93), Vector3(1, 0, 0), R_FRONT, L_OUT, L),
			_t(0.3, 0.42, 22, 18, Vector3(0.75, -0.15, 0.6), Vector3(0.5, 0, -0.8), R_ACROSS, L_BACK, L),
			_t(0.38, 0.4, 24, 16, Vector3(0.8, -0.2, 0.5), Vector3(0.5, 0, -0.8), R_ACROSS, L_BACK, L),
			_t(0.55, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
		]},
		# 2 Gyaku Kiriage (S 2:01.75-2:02.35): sol-alttan çapraz yükselen ters kesik, sonda kılıç dik yüzün önünde (tutar)
		{"len": 0.5, "hit": 0.2, "keys": [
			_t(0.0, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
			_t(0.1, 0.5, 22, 18, Vector3(0.6, -0.6, 0.5), Vector3(-0.5, 0.8, 0.2), R_LHIP, L_GUARD, CR),
			_t(0.14, 0.52, 24, 18, Vector3(0.6, -0.62, 0.48), Vector3(-0.5, 0.8, 0.2), R_LHIP, L_GUARD, CR),
			_t(0.2, 0.4, -4, 4, Vector3(-0.25, 0.55, 0.8), Vector3(-0.4, 0.8, 0), R_RISE, L_BACK, ST),
			_t(0.26, 0.32, -14, -6, Vector3(-0.2, 0.88, 0.42), Vector3(0, 0.3, 1), R_VERT, L_BACK, LL),
			_t(0.34, 0.32, -14, -6, Vector3(-0.2, 0.88, 0.42), Vector3(0, 0.3, 1), R_VERT, L_BACK, LL),
			_t(0.5, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
		]},
		# 3 Chidori-gatana Tsuki (B 0:24.35 kurulma, 0:25.05 + 1:31.00 saplama): dirsek geride el kulak altında, ağırlık arkada ->
		#   Shunshin hamle, kol dümdüz ileri; sol kol geriye savrulur
		{"len": 0.7, "hit": 0.32, "keys": [
			_t(0.0, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
			_t(0.14, 0.44, -20, -8, Vector3(0.05, 0.12, 1), DOWN, R_EAR, L_POINT, BK),
			_t(0.26, 0.46, -22, -10, Vector3(0.05, 0.12, 1), DOWN, R_EAR, L_POINT, BK),
			_t(0.32, 0.54, 12, 24, Vector3(0, -0.02, 1), DOWN, R_STAB, L_BACK, L),
			_t(0.48, 0.52, 10, 20, Vector3(0, -0.04, 1), DOWN, R_STAB, L_BACK, L),
			_t(0.7, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
		]},
		# 4 Jōdan Kabuto-wari (S 2:05.25-2:05.50): iki kol başın üstünde, kılıç tepede yatay, sağ diz göğse kalkık (kurulur, bekler) ->
		#   ayak yere vurur, tepeden çapraz iniş sol dize kadar, ağız aşağı-önde
		{"len": 0.75, "hit": 0.42, "keys": [
			_t(0.0, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
			_t(0.16, 0.2, -12, -14, Vector3(-0.8, 0.15, -0.55), Vector3(0, 1, 0), R_OVER, L_UP, ST),
			_t(0.32, 0.18, -14, -16, Vector3(-0.8, 0.18, -0.55), Vector3(0, 1, 0), R_OVER, L_UP, ST),
			_t(0.38, 0.3, -6, 2, Vector3(-0.3, 0.75, 0.6), Vector3(0, 0.4, 1), R_OVER, L_POINT, L),
			_t(0.42, 0.5, 14, 22, Vector3(0.45, -0.45, 0.77), Vector3(0.3, -1, 0.3), R_LOWEND, L_BACK, L),
			_t(0.5, 0.56, 18, 26, Vector3(0.6, -0.65, 0.45), Vector3(0.3, -1, 0.3), R_LOWEND, L_BACK, L),
			_t(0.75, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
		]},
		# 5 Chidori Nagashi (B 1:28-1:29): alçak çömelme, kılıç önde-alçakta, akım GÖVDEDEN çevreye boşalır (vuruş anı) ->
		#   ardından iki kısa çapraz kesik (X): sağ üstten sol alta, sol omuzdan sağ alta
		{"len": 1.1, "hit": 0.3, "extra_hits": [0.6, 0.82], "extra_radius": 1.6, "keys": [
			_t(0.0, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
			_t(0.16, 0.6, -6, 22, Vector3(0.3, -0.55, 0.78), DOWN, R_LOWF, L_LOW, BK),
			_t(0.3, 0.66, 0, 26, Vector3(0.3, -0.58, 0.76), DOWN, R_LOWF, L_LOW, W),
			_t(0.42, 0.62, 0, 24, Vector3(0.3, -0.58, 0.76), DOWN, R_LOWF, L_LOW, W),
			_t(0.52, 0.42, -16, 6, Vector3(-0.5, 0.65, 0.57), Vector3(0.6, -0.3, 0.5), R_SIDE, L_GUARD, ST),
			_t(0.6, 0.46, 16, 18, Vector3(0.6, -0.6, 0.5), Vector3(0.4, -1, 0.2), R_LOWEND, L_GUARD, L),
			_t(0.7, 0.44, 20, 10, Vector3(0.6, 0.6, 0.5), Vector3(-0.6, -0.3, 0.5), R_LSH, L_GUARD, L),
			_t(0.82, 0.48, -18, 18, Vector3(-0.6, -0.6, 0.5), Vector3(-0.4, -1, 0.2), R_LOWR, L_OUT, LL),
			_t(0.92, 0.48, -20, 16, Vector3(-0.62, -0.62, 0.45), Vector3(-0.4, -1, 0.2), R_LOWR, L_OUT, LL),
			_t(1.1, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
		]},
		# 6 Senkō (bitiriş; S 2:01.05-2:01.45 + B 0:40.55, 0:41.55): kılıç kalçanın arkasında geri sürünür, çömelip bekler ->
		#   şimşek geçiş (5 m, KeyedCombos._kusa_iai) -> rakibin arkasında geniş çömelme, kol dümdüz geri, kılıç yatay arkada (bekler) ->
		#   ağır ağır doğrulur, kılıç yanda aşağı sarkık; kesik gecikmeli açılır
		{"len": 1.1, "hit": 0.44, "keys": [
			_t(0.0, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
			_t(0.16, 0.56, -10, 22, Vector3(-0.3, -0.45, -0.85), DOWN, R_TRAIL, L_POINT, BK),
			_t(0.38, 0.6, -12, 26, Vector3(-0.32, -0.42, -0.85), DOWN, R_TRAIL, L_POINT, BK),
			_t(0.44, 0.64, 10, 30, Vector3(-0.35, 0.0, -0.94), Vector3(1, 0, 0), R_BACK, L_OUT, L),
			_t(0.74, 0.66, 12, 30, Vector3(-0.35, -0.02, -0.94), Vector3(1, 0, 0), R_BACK, L_OUT, L),
			_t(0.9, 0.46, 4, 12, Vector3(-0.1, -0.75, 0.65), DOWN, R_HANG, L_OUT, W),
			_t(1.1, 0.34, 0, 4, RDY, DOWN, R_READY, L_GUARD, W),
		]},
	]
	for st in out:
		_unwrap(st["keys"])
	return out
