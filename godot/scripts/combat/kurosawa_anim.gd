extends RefCounted
## Kurosawa (Mifune) kombosu: iaidō. Kılıç her adımda kınındadır; sağ el kabzada, sol el kında; bir anda çekilir, keser, geri girer.
## Çekip sokma KurosawaFX'te (HIT ve NOTO anlarına göre). 1 Nukitsuke (yatay), 2 Kaeshi (ters çapraz), 3 Kesa-giri (geçerek), 4 Uke-kamae (bekler,
## gelen darbeyi karşılar), 5 Nidan-giri (iki kesik), 6 Iaigiri (uzun duruş, tek uzak kesik; Ibuse'yi yaran vuruş).

const S = preload("res://scripts/combat/samehada_anim.gd")

const HIT := [0.3, 0.28, 0.36, 0.66, 0.3, 1.05]     # kılıcın çıktığı an
const NOTO := [0.58, 0.54, 0.7, 0.94, 0.68, 1.45]   # kına girdiği an

const R_HILT := {"RightUpperArm": Vector3(-0.08, -0.72, 0.69), "RightLowerArm": Vector3(0.86, -0.35, 0.36)}
const L_SAYA := {"LeftUpperArm": Vector3(0.35, -0.85, 0.38), "LeftLowerArm": Vector3(-0.25, -0.72, 0.64)}
const R_SIDE := {"RightUpperArm": Vector3(-0.72, 0.02, 0.69), "RightLowerArm": Vector3(-0.72, 0.08, 0.69)}
const R_HIGH := {"RightUpperArm": Vector3(-0.55, 0.42, 0.72), "RightLowerArm": Vector3(-0.42, 0.55, 0.72)}
const R_LOW := {"RightUpperArm": Vector3(-0.62, -0.5, 0.6), "RightLowerArm": Vector3(-0.6, -0.42, 0.68)}
const R_FWD := {"RightUpperArm": Vector3(-0.1, 0.0, 1), "RightLowerArm": Vector3(-0.05, 0.02, 1)}
const B_SIDE := Vector3(-0.92, 0.12, 0.36)
const B_UP := Vector3(-0.5, 0.75, 0.42)
const B_DOWN := Vector3(-0.68, -0.55, 0.48)
const B_FWD := Vector3(-0.2, 0.05, 0.98)
# Ağzın sap ekseni etrafındaki dönüşü (derece, key "roll"): 0 = keskin ağız yukarı (yükselen kesik), 90 = ağız sağa/geriye
# (yatay kesikte savuruş yönünde önde), 180 = ağız aşağı (inen kesik, ileri uzanmış duruş). Eskiden hep 0'dı: inen kesikte ve
# bitirişte kavisli ağız ters (sırt önde, ağız yukarı) duruyordu.
const ROLL_SIDE := 90.0
const ROLL_UP := 0.0
const ROLL_DOWN := 180.0


static func _t(t: float, crouch: float, yaw: float, lean: float, b: Vector3, r: Dictionary, legs: Dictionary, roll := ROLL_DOWN) -> Dictionary:
	var k = S._k(t, crouch, yaw * 1.3, lean * 1.2, b.normalized(), S._a(r, L_SAYA), legs)
	k["roll"] = roll
	return k


## kabzada bekle -> bir anda kes -> dur -> kabzaya dön
static func _cut(hit: float, noto: float, end: float, crouch: float, r: Dictionary, b: Vector3, legs: Dictionary, roll: float) -> Array:
	return [
		_t(0.0, 0.42, 14, 4, B_FWD, R_HILT, S.LEG_WIDE, roll),
		_t(hit - 0.05, crouch, 22, 8, B_FWD, R_HILT, S.LEG_BACK, roll),
		_t(hit + 0.03, crouch + 0.04, -34, 14, b, r, legs, roll),
		_t(noto - 0.12, crouch + 0.02, -30, 10, b, r, legs, roll),
		_t(noto, crouch, 12, 6, B_FWD, R_HILT, legs, roll),
		_t(end, 0.42, 14, 4, B_FWD, R_HILT, S.LEG_WIDE, roll),
	]


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var ST = S.LEG_STEP
	var BK = S.LEG_BACK
	return [
		{"len": 0.78, "hit": HIT[0], "keys": _cut(HIT[0], NOTO[0], 0.78, 0.48, R_SIDE, B_SIDE, L, ROLL_SIDE)},
		{"len": 0.72, "hit": HIT[1], "keys": _cut(HIT[1], NOTO[1], 0.72, 0.46, R_HIGH, B_UP, ST, ROLL_UP)},
		{"len": 0.95, "hit": HIT[2], "keys": _cut(HIT[2], NOTO[2], 0.95, 0.52, R_LOW, B_DOWN, L, ROLL_DOWN)},
		{"len": 1.15, "hit": HIT[3], "keys": [
			_t(0.0, 0.42, 14, 4, B_FWD, R_HILT, W, ROLL_SIDE),
			_t(0.14, 0.6, 26, 14, B_FWD, R_HILT, BK, ROLL_SIDE),
			_t(0.61, 0.62, 27, 15, B_FWD, R_HILT, BK, ROLL_SIDE),
			_t(0.69, 0.62, -34, 18, B_SIDE, R_SIDE, L, ROLL_SIDE),
			_t(0.82, 0.6, -30, 12, B_SIDE, R_SIDE, L, ROLL_SIDE),
			_t(0.94, 0.56, 12, 8, B_FWD, R_HILT, W, ROLL_SIDE),
			_t(1.15, 0.42, 14, 4, B_FWD, R_HILT, W, ROLL_SIDE),
		]},
		{"len": 0.85, "hit": HIT[4], "keys": [
			_t(0.0, 0.42, 14, 4, B_FWD, R_HILT, W, ROLL_SIDE),
			_t(0.25, 0.48, 22, 8, B_FWD, R_HILT, BK, ROLL_SIDE),
			_t(0.33, 0.52, -34, 14, B_SIDE, R_SIDE, L, ROLL_SIDE),
			_t(0.45, 0.54, 20, 16, B_UP, R_HIGH, ST, ROLL_UP),
			_t(0.56, 0.52, -18, 12, B_DOWN, R_LOW, L, ROLL_DOWN),
			_t(0.68, 0.48, 12, 6, B_FWD, R_HILT, W),
			_t(0.85, 0.42, 14, 4, B_FWD, R_HILT, W),
		]},
		# Iaigiri: en alçak duruş, uzun sessizlik, tek çekiş; kol ileri uzanmış kalır, sonra yavaşça kına
		{"len": 1.8, "hit": HIT[5], "keys": [
			_t(0.0, 0.42, 14, 4, B_FWD, R_HILT, W),
			_t(0.4, 0.72, 30, 20, B_FWD, R_HILT, BK),
			_t(1.0, 0.74, 32, 22, B_FWD, R_HILT, BK),
			_t(1.08, 0.7, -40, 24, B_FWD, R_FWD, L),
			_t(1.32, 0.68, -36, 20, B_FWD, R_FWD, L),
			_t(1.45, 0.6, 12, 10, B_FWD, R_HILT, L),
			_t(1.8, 0.42, 14, 4, B_FWD, R_HILT, W),
		]},
	]
