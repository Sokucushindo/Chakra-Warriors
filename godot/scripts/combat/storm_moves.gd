extends RefCounted
## Arena dövüş kuralları (Combat.storm): temel silahsız kombo + yöne göre kombo dalları. Hepsi el yapımı anahtar animasyon
## (style_common / style_legs poz kütüphanesi): her vuruş kurulum → vuruş → kısa tutuş → duruşa dönüş, bir sonrakine akarak bağlanır.
##  düz    : sol direkt, sağ kroşe, gövdeye aparkat, yüksek döner tekme, ön tekme, adım atıp sert sağ direkt (geri savurur)
##  yukarı : çöküp dikey tekmeyle rakibi havaya kaldırır; peşinden sıçranır ve havada sürdürülür
##  hava   : ön tekme, döner tekme, iki elle yukarıdan aşağı çakma (rakip yere çakılır)
##  aşağı  : alçak süpürme (rakip yere serilir), yerdekine yukarıdan inen yumruk (yerden sektirir)

const C = preload("res://scripts/combat/style_common.gd")
const F = preload("res://scripts/combat/style_legs.gd")

static var _cache := {}


## Sağ-sol ayna: kemik adlarında Left/Right yer değiştirir, yönlerin x'i ters döner
static func mir(d: Dictionary) -> Dictionary:
	var o = {}
	for k in d:
		var nk = String(k)
		if nk.begins_with("Left"):
			nk = "Right" + nk.substr(4)
		elif nk.begins_with("Right"):
			nk = "Left" + nk.substr(5)
		var v: Vector3 = d[k]
		o[nk] = Vector3(-v.x, v.y, v.z)
	return o


static func _legs(a: Dictionary, b: Dictionary) -> Dictionary:
	var o = a.duplicate()
	o.merge(b, true)
	return o


## Temel silahsız kombo (KeyedCombos "style_temel"): oyuncu ve düşman aynı adımları kullanır
static func steps() -> Array:
	if _cache.has("base"):
		return _cache["base"]
	var st = [
		C.step(0.36, 0.13, C.R_GUARD, C.L_COCK, C.R_GUARD, C.L_PUNCH, F.SHIFT, F.STEPIN, 10.0, -16.0, 0.36, 8.0),            # 1 sol direkt
		C.step(0.4, 0.15, C.R_COCK, C.L_GUARD, C.R_PUNCH, C.L_GUARD, F.SHIFT, F.PIVOT, -24.0, 30.0, 0.38, 14.0),             # 2 sağ kroşe (arka topuk döner)
		C.step(0.44, 0.17, C.R_LOW, C.L_GUARD, C.R_UPPER, C.L_COCK, F.LOW, F.STEPIN, -18.0, 24.0, 0.46, 6.0),                # 3 çöküp gövdeye aparkat
		C.step(0.5, 0.2, C.R_GUARD, C.L_GUARD, C.R_SPREAD, C.L_GUARD, F.PIVOT, C.KICK_HIGH_R, 35.0, -75.0, 0.32, -10.0),     # 4 yüksek döner tekme
		C.step(0.46, 0.18, C.R_GUARD, C.L_GUARD, C.R_BACK, C.L_GUARD, F.SHIFT, C.KICK_FRONT_R, -8.0, 0.0, 0.34, -14.0),      # 5 ön tekme
		{"len": 0.72, "hit": 0.3, "keys": [   # 6 geri çekilip adım atarak sert sağ direkt
			C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.17, 0.5, -42, -8, C.R_COCK, C.L_REACH, F.SHIFT),
			C.t(0.3, 0.4, 42, 22, C.R_PUNCH, C.L_COCK, F.STEPIN),
			C.t(0.48, 0.4, 36, 18, C.R_PUNCH, C.L_COCK, F.STEPIN),
			C.t(0.72, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
	]
	_cache["base"] = st
	return st


# ---- silahlı dallar: kesici / ezici silah elde (bıçak yönü anahtarlarda; silah modeli ucu bu yöne çevrilir) ----
const S = preload("res://scripts/combat/samehada_anim.gd")
const W_RDY := Vector3(0.2, 0.5, 0.85)
const WR_READY := {"RightUpperArm": Vector3(-0.2, -0.75, 0.62), "RightLowerArm": Vector3(0.25, 0.1, 0.96)}
const WR_HIP_L := {"RightUpperArm": Vector3(0.3, -0.85, 0.42), "RightLowerArm": Vector3(0.7, -0.5, 0.5)}       # sol kalçada (alttan çekiş)
const WR_RISE := {"RightUpperArm": Vector3(-0.5, 0.72, 0.48), "RightLowerArm": Vector3(-0.35, 0.88, 0.32)}     # sağ üstte bitmiş
const WR_WIDE := {"RightUpperArm": Vector3(-0.95, -0.05, 0.3), "RightLowerArm": Vector3(-0.85, -0.1, 0.5)}     # sağa açık
const WR_LEFT := {"RightUpperArm": Vector3(0.2, -0.05, 0.97), "RightLowerArm": Vector3(0.9, 0.15, 0.35)}       # gövdenin soluna geçmiş
const WR_HIGH := {"RightUpperArm": Vector3(-0.2, 0.95, -0.2), "RightLowerArm": Vector3(0.0, 0.95, 0.3)}        # başın üstünde
const WR_CLEAVE := {"RightUpperArm": Vector3(-0.05, -0.5, 0.86), "RightLowerArm": Vector3(0.0, -0.72, 0.69)}   # aşağı-öne inmiş
const WR_LOW_R := {"RightUpperArm": Vector3(-0.7, -0.68, 0.2), "RightLowerArm": Vector3(-0.6, -0.75, 0.3)}     # sağ altta (süpürme kurulumu)
const WR_LOW_L := {"RightUpperArm": Vector3(0.25, -0.62, 0.74), "RightLowerArm": Vector3(0.75, -0.55, 0.36)}   # sol altta (süpürme bitişi)
const WR_STAB_UP := {"RightUpperArm": Vector3(-0.25, 0.85, 0.45), "RightLowerArm": Vector3(0.05, 0.6, 0.8)}    # ters tutuş, uç aşağı, yumruk baş hizasında
const WR_STAB_DN := {"RightUpperArm": Vector3(-0.1, -0.45, 0.88), "RightLowerArm": Vector3(0.0, -0.95, 0.3)}   # yere saplanmış
const WL_GUARD := {"LeftUpperArm": Vector3(0.3, -0.75, 0.55), "LeftLowerArm": Vector3(-0.2, 0.3, 0.93)}
const WL_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const WL_OUT := {"LeftUpperArm": Vector3(0.9, 0.1, -0.2), "LeftLowerArm": Vector3(0.85, 0.3, 0.2)}             # denge kolu yana açık


static func _w(tm: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(tm, crouch, yaw, lean, blade.normalized(), S._a(r, l), legs)


##  yukarı : çöküp sol kalçadan sağ omuz üstüne yükselen kesik (rakibi havaya kaldırır)
##  hava   : sağdan sola yatay kesik, soldan sağa ters kesik, baş üstünden dikey biçme (yere çakar)
##  aşağı  : dizlere alçak süpürme kesiği (yere serer), yerdekine ters tutuşla yukarıdan saplama
static func _armed(branch: String) -> Array:
	var tuck_l := {"LeftUpperLeg": F.HOP["LeftUpperLeg"], "LeftLowerLeg": F.HOP["LeftLowerLeg"], "LeftFoot": F.HOP["LeftFoot"]}
	var air_arch := {"LeftUpperLeg": Vector3(0.2, -0.75, -0.63), "LeftLowerLeg": Vector3(0.05, -0.3, -0.95), "LeftFoot": Vector3(0.05, -0.9, -0.4),
		"RightUpperLeg": Vector3(-0.2, -0.75, -0.63), "RightLowerLeg": Vector3(-0.05, -0.3, -0.95), "RightFoot": Vector3(-0.05, -0.9, -0.4)}
	var air_split = _legs({"RightUpperLeg": Vector3(-0.15, -0.55, 0.82), "RightLowerLeg": Vector3(-0.05, -0.95, 0.3), "RightFoot": Vector3(-0.05, -0.6, 0.8)},
		{"LeftUpperLeg": Vector3(0.2, -0.8, -0.56), "LeftLowerLeg": Vector3(0.05, -0.5, -0.86), "LeftFoot": Vector3(0.05, -0.9, -0.3)})   # havada adım: sağ diz önde, sol bacak geride
	match branch:
		"up":
			return [{"len": 0.62, "hit": 0.3, "dmg": 6.0, "reach": 1.9, "lunge": 4.5, "knock": 1.0, "launch": 11.0, "heavy": true, "keys": [
				_w(0.0, 0.38, 0, 6, W_RDY, WR_READY, WL_GUARD, F.FIGHT),
				_w(0.16, 0.66, 34, 18, Vector3(0.6, -0.75, 0.3), WR_HIP_L, WL_GUARD, F.LOW),          # çöker, ağız sol altta
				_w(0.3, 0.24, -30, -12, Vector3(-0.35, 0.9, 0.25), WR_RISE, WL_BACK, F.STEPIN),       # yükselen kesik
				_w(0.44, 0.22, -34, -14, Vector3(-0.4, 0.9, 0.1), WR_RISE, WL_BACK, F.STEPIN),
				_w(0.62, 0.44, 0, 6, Vector3(-0.2, 0.9, 0.4), WR_HIGH, WL_OUT, F.HOP),                # sıçramaya toplanır
			]}]
		"air":
			return [
				{"len": 0.34, "hit": 0.14, "dmg": 4.5, "reach": 2.0, "lunge": 5.0, "knock": 1.0, "float": 4.0, "keys": [
					_w(0.0, 0.3, 0, 4, W_RDY, WR_READY, WL_GUARD, F.HOP),
					_w(0.07, 0.3, -34, 0, Vector3(-0.9, 0.15, 0.35), WR_WIDE, WL_GUARD, air_split),
					_w(0.14, 0.3, 40, 8, Vector3(0.85, 0.05, 0.5), WR_LEFT, WL_OUT, air_split),         # sağdan sola yatay kesik
					_w(0.24, 0.3, 44, 8, Vector3(0.9, 0.0, 0.4), WR_LEFT, WL_OUT, air_split),
					_w(0.34, 0.3, 20, 4, Vector3(0.85, 0.1, 0.45), WR_LEFT, WL_GUARD, F.HOP),
				]},
				{"len": 0.36, "hit": 0.14, "dmg": 5.0, "reach": 2.0, "lunge": 5.0, "knock": 1.0, "float": 4.0, "keys": [
					_w(0.0, 0.3, 20, 4, Vector3(0.85, 0.1, 0.45), WR_LEFT, WL_GUARD, F.HOP),
					_w(0.14, 0.3, -42, 8, Vector3(-0.9, 0.2, 0.35), WR_WIDE, WL_BACK, S.mirror(air_split)),   # soldan sağa ters kesik
					_w(0.25, 0.3, -46, 8, Vector3(-0.95, 0.25, 0.2), WR_WIDE, WL_BACK, S.mirror(air_split)),
					_w(0.36, 0.3, 0, 4, W_RDY, WR_READY, WL_GUARD, F.HOP),
				]},
				{"len": 0.62, "hit": 0.27, "dmg": 9.0, "reach": 2.1, "lunge": 5.0, "knock": 3.0, "spike": 26.0, "heavy": true, "two": true, "keys": [
					_w(0.0, 0.3, 0, 4, W_RDY, WR_READY, WL_GUARD, F.HOP),
					_w(0.15, 0.3, 0, -28, Vector3(0, 0.9, -0.45), WR_HIGH, WL_GUARD, air_arch),          # baş üstüne kaldırır, gövde geriye gerilir
					_w(0.27, 0.3, 0, 38, Vector3(0, -0.75, 0.65), WR_CLEAVE, WL_BACK, _legs(F.HOP, tuck_l)),   # dikey biçme
					_w(0.42, 0.3, 0, 32, Vector3(0, -0.85, 0.5), WR_CLEAVE, WL_BACK, F.HOP),
					_w(0.62, 0.3, 0, 4, W_RDY, WR_READY, WL_GUARD, F.HOP),
				]},
			]
		"down":
			return [
				{"len": 0.58, "hit": 0.25, "dmg": 5.5, "reach": 2.1, "lunge": 4.0, "knock": 2.0, "launch": 3.2, "down": true, "heavy": true, "keys": [
					_w(0.0, 0.38, 0, 6, W_RDY, WR_READY, WL_GUARD, F.FIGHT),
					_w(0.13, 0.72, -42, 14, Vector3(-0.85, -0.45, 0.25), WR_LOW_R, WL_GUARD, F.LOW),     # yere iner, ağız sağ altta
					_w(0.25, 0.76, 52, 18, Vector3(0.8, -0.5, 0.35), WR_LOW_L, WL_OUT, F.LOW),           # dizlere süpürme kesiği
					_w(0.4, 0.76, 56, 16, Vector3(0.85, -0.45, 0.25), WR_LOW_L, WL_OUT, F.LOW),
					_w(0.58, 0.45, 0, 6, W_RDY, WR_READY, WL_GUARD, F.FIGHT),
				]},
				{"len": 0.66, "hit": 0.31, "dmg": 8.0, "reach": 1.8, "lunge": 4.0, "knock": 3.0, "launch": 6.0, "down": true, "heavy": true, "keys": [
					_w(0.0, 0.45, 0, 6, W_RDY, WR_READY, WL_GUARD, F.FIGHT),
					_w(0.16, 0.28, -14, -14, Vector3(0, -0.95, 0.3), WR_STAB_UP, WL_GUARD, F.SHIFT),     # ters tutuş: uç aşağı, yumruk baş hizasında
					_w(0.31, 0.8, 10, 42, Vector3(0, -1, 0.15), WR_STAB_DN, WL_BACK, F.LOW),             # yere saplar
					_w(0.47, 0.8, 10, 38, Vector3(0, -1, 0.15), WR_STAB_DN, WL_BACK, F.LOW),
					_w(0.66, 0.38, 0, 6, W_RDY, WR_READY, WL_GUARD, F.FIGHT),
				]},
			]
	return []


## Kombo dalı adımları: anahtarlar + dövüş değerleri (dmg yumruk kombosu ölçeğinde; oyuncu silah / ustalık çarpanını ekler)
##  launch : rakibi havaya kaldırır   float : havadaki rakibi asılı tutar   spike : rakibi yere çakar   down : yere serer
static func moves(branch: String, armed := false) -> Array:
	if armed:
		if not _cache.has(branch + "_w"):
			_cache[branch + "_w"] = _armed(branch)
		return _cache[branch + "_w"]
	if _cache.has(branch):
		return _cache[branch]
	var tuck_l := {"LeftUpperLeg": F.HOP["LeftUpperLeg"], "LeftLowerLeg": F.HOP["LeftLowerLeg"], "LeftFoot": F.HOP["LeftFoot"]}
	var tuck_r := {"RightUpperLeg": F.HOP["RightUpperLeg"], "RightLowerLeg": F.HOP["RightLowerLeg"], "RightFoot": F.HOP["RightFoot"]}
	var air_front_r = _legs(C.KICK_FRONT_R, tuck_l)                 # havada sağ ön tekme, sol diz toplu
	var air_round_l = _legs(mir(C.KICK_HIGH_R), tuck_r)             # havada sol döner tekme, sağ diz toplu
	var air_arch := {"LeftUpperLeg": Vector3(0.2, -0.75, -0.63), "LeftLowerLeg": Vector3(0.05, -0.3, -0.95), "LeftFoot": Vector3(0.05, -0.9, -0.4),
		"RightUpperLeg": Vector3(-0.2, -0.75, -0.63), "RightLowerLeg": Vector3(-0.05, -0.3, -0.95), "RightFoot": Vector3(-0.05, -0.9, -0.4)}   # gövde geriye kavis, topuklar arkada
	var l_down = mir(C.R_DOWN)
	var mv: Array = []
	match branch:
		"up":
			mv = [{"len": 0.62, "hit": 0.3, "dmg": 6.0, "reach": 1.7, "lunge": 4.5, "knock": 1.0, "launch": 11.0, "heavy": true, "keys": [
				C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
				C.t(0.15, 0.6, -12, 12, C.R_LOW, C.L_LOW, F.LOW),                       # çök
				C.t(0.3, 0.22, 0, -18, C.R_SPREAD, C.L_SPREAD, C.KICK_UP_R),            # dikey tekme
				C.t(0.44, 0.22, 0, -16, C.R_SPREAD, C.L_SPREAD, C.KICK_UP_R),
				C.t(0.62, 0.42, 0, 6, C.R_HIGH, C.L_HIGH, F.HOP),                       # sıçramaya toplanır
			]}]
		"air":
			mv = [
				{"len": 0.34, "hit": 0.14, "dmg": 4.5, "reach": 1.8, "lunge": 5.0, "knock": 1.0, "float": 4.0, "keys": [
					C.t(0.0, 0.3, 0, 4, C.R_GUARD, C.L_GUARD, F.HOP),
					C.t(0.14, 0.3, -20, -14, C.R_BACK, C.L_GUARD, air_front_r),
					C.t(0.24, 0.3, -16, -12, C.R_BACK, C.L_GUARD, air_front_r),
					C.t(0.34, 0.3, 0, 4, C.R_GUARD, C.L_GUARD, F.HOP),
				]},
				{"len": 0.38, "hit": 0.16, "dmg": 5.0, "reach": 1.8, "lunge": 5.0, "knock": 1.0, "float": 4.0, "keys": [
					C.t(0.0, 0.3, 0, 4, C.R_GUARD, C.L_GUARD, F.HOP),
					C.t(0.08, 0.3, -40, 0, C.R_GUARD, C.L_COCK, F.HOP),
					C.t(0.16, 0.3, 80, -10, C.R_GUARD, C.L_SPREAD, air_round_l),
					C.t(0.27, 0.3, 70, -8, C.R_GUARD, C.L_SPREAD, air_round_l),
					C.t(0.38, 0.3, 0, 4, C.R_GUARD, C.L_GUARD, F.HOP),
				]},
				{"len": 0.62, "hit": 0.27, "dmg": 9.0, "reach": 1.9, "lunge": 5.0, "knock": 3.0, "spike": 26.0, "heavy": true, "keys": [
					C.t(0.0, 0.3, 0, 4, C.R_GUARD, C.L_GUARD, F.HOP),
					C.t(0.15, 0.3, 0, -26, C.R_SKY, C.L_SKY, air_arch),                 # eller başın üstünde kenetli, gövde geriye gerilir
					C.t(0.27, 0.3, 0, 36, C.R_DOWN, l_down, F.HOP),                    # aşağı çakar
					C.t(0.42, 0.3, 0, 30, C.R_DOWN, l_down, F.HOP),
					C.t(0.62, 0.3, 0, 4, C.R_GUARD, C.L_GUARD, F.HOP),
				]},
			]
		"down":
			mv = [
				{"len": 0.56, "hit": 0.24, "dmg": 5.5, "reach": 1.9, "lunge": 4.0, "knock": 2.0, "launch": 3.2, "down": true, "heavy": true, "keys": [
					C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
					C.t(0.12, 0.7, -40, 10, C.R_LOW, C.L_LOW, F.LOW),                  # yere iner
					C.t(0.24, 0.74, 70, 16, C.R_GROUND, C.L_LOW, C.KICK_LOW_L),         # alçak süpürme
					C.t(0.38, 0.74, 60, 14, C.R_GROUND, C.L_LOW, C.KICK_LOW_L),
					C.t(0.56, 0.45, 0, 6, C.R_GUARD, C.L_GUARD, F.FIGHT),
				]},
				{"len": 0.64, "hit": 0.3, "dmg": 8.0, "reach": 1.6, "lunge": 4.0, "knock": 3.0, "launch": 6.0, "down": true, "heavy": true, "keys": [
					C.t(0.0, 0.45, 0, 6, C.R_GUARD, C.L_GUARD, F.FIGHT),
					C.t(0.15, 0.3, -30, -12, C.R_SKY, C.L_GUARD, F.SHIFT),              # yumruk başın üstüne
					C.t(0.3, 0.78, 26, 40, C.R_DOWN, C.L_BACK, F.LOW),                 # yere iner
					C.t(0.46, 0.78, 22, 36, C.R_DOWN, C.L_BACK, F.LOW),
					C.t(0.64, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
				]},
			]
	_cache[branch] = mv
	return mv
