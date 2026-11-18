extends RefCounted
## Nunchaku (Tenten'in parşömen cephaneliği; kanonda yalnız kısa anlarda görünür — hareketler silahın kendi fiziğinden): sağ elde
## tek sopa, kısa zincirin ucunda ikinci sopa SERBEST sallanır (CharacterModel zincir fiziği: bilek savrulunca uç sopa gecikip kırbaç
## gibi çarpar). Kısa, hızlı bilek darbeleri; her vuruştan önce kısa geri çekiş.
## 1 Yoko Uchi: sağdan sola yatay bilek, 2 Kaeshi: geri dönüş, 3 Ue Kara: baş üstünden iniş (ağır), 4 Hachi no Ji: iki yana sekiz
## çizerek art arda, 5 Tsuki: sap ucuyla kısa dürtme, 6 Renda (bitiriş): art arda üç savuruş + sıçrayıp baş üstünden iniş

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.35, -0.7, 0.6), "RightLowerArm": Vector3(0.1, 0.35, 0.93)}
const R_BACK := {"RightUpperArm": Vector3(-0.85, 0.1, -0.5), "RightLowerArm": Vector3(-0.5, 0.6, -0.6)}
const R_LEFT := {"RightUpperArm": Vector3(0.3, -0.1, 0.95), "RightLowerArm": Vector3(0.9, 0.0, 0.4)}
const R_RIGHT := {"RightUpperArm": Vector3(-0.95, -0.1, 0.3), "RightLowerArm": Vector3(-0.85, -0.1, 0.5)}
const R_HIGH := {"RightUpperArm": Vector3(-0.25, 0.95, -0.1), "RightLowerArm": Vector3(0.05, 0.9, -0.4)}
const R_DOWN := {"RightUpperArm": Vector3(-0.15, -0.3, 0.94), "RightLowerArm": Vector3(0.0, -0.55, 0.83)}
const R_STAB := {"RightUpperArm": Vector3(-0.05, -0.05, 1), "RightLowerArm": Vector3(0.0, 0.0, 1)}
const R_CHAMBER := {"RightUpperArm": Vector3(-0.3, -0.6, -0.75), "RightLowerArm": Vector3(-0.05, -0.05, 1)}
const L_GUARD := {"LeftUpperArm": Vector3(0.3, -0.7, 0.6), "LeftLowerArm": Vector3(-0.25, 0.35, 0.9)}
const L_OPEN := {"LeftUpperArm": Vector3(0.9, -0.3, 0.3), "LeftLowerArm": Vector3(0.85, 0.2, 0.45)}
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.2, Vector3(0, 0, 1), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	return [
		# 1 Yoko Uchi
		{"len": 0.5, "hit": 0.22, "keys": [
			_t(0.0, 0.34, 0, 4, R_READY, L_GUARD, W),
			_t(0.12, 0.38, 24, -6, R_BACK, L_OPEN, BK),
			_t(0.22, 0.44, -26, 14, R_LEFT, L_BACK, L),
			_t(0.32, 0.42, -30, 12, R_LEFT, L_BACK, L),
			_t(0.5, 0.34, 0, 4, R_READY, L_GUARD, W),
		]},
		# 2 Kaeshi
		{"len": 0.48, "hit": 0.2, "keys": [
			_t(0.0, 0.34, 0, 4, R_READY, L_GUARD, W),
			_t(0.1, 0.38, -22, -4, R_LEFT, L_GUARD, CR),
			_t(0.2, 0.44, 24, 12, R_RIGHT, L_OPEN, ST),
			_t(0.3, 0.42, 28, 10, R_RIGHT, L_OPEN, W),
			_t(0.48, 0.34, 0, 4, R_READY, L_GUARD, W),
		]},
		# 3 Ue Kara: baş üstü -> iniş
		{"len": 0.62, "hit": 0.3, "keys": [
			_t(0.0, 0.34, 0, 4, R_READY, L_GUARD, W),
			_t(0.16, 0.3, 0, -12, R_HIGH, L_OPEN, BK),
			_t(0.24, 0.3, 0, -14, R_HIGH, L_OPEN, BK),
			_t(0.3, 0.54, 0, 26, R_DOWN, L_BACK, L),
			_t(0.42, 0.52, 0, 22, R_DOWN, L_BACK, L),
			_t(0.62, 0.34, 0, 4, R_READY, L_GUARD, W),
		]},
		# 4 Hachi no Ji: iki yana sekiz çizerek
		{"len": 0.85, "hit": 0.2, "extra_hits": [0.4, 0.6], "extra_radius": 1.5, "keys": [
			_t(0.0, 0.34, 0, 4, R_READY, L_GUARD, W),
			_t(0.1, 0.4, 20, 4, R_BACK, L_OPEN, CR),
			_t(0.2, 0.44, -24, 10, R_LEFT, L_OPEN, W),
			_t(0.3, 0.42, -10, 6, R_HIGH, L_OPEN, CR),
			_t(0.4, 0.44, 24, 10, R_RIGHT, L_OPEN, W),
			_t(0.5, 0.42, 10, 6, R_HIGH, L_OPEN, CR),
			_t(0.6, 0.44, -24, 10, R_LEFT, L_OPEN, W),
			_t(0.85, 0.34, 0, 4, R_READY, L_GUARD, W),
		]},
		# 5 Tsuki: sap ucuyla dürtme
		{"len": 0.5, "hit": 0.2, "keys": [
			_t(0.0, 0.34, 0, 4, R_READY, L_GUARD, W),
			_t(0.12, 0.4, -14, -6, R_CHAMBER, L_GUARD, BK),
			_t(0.2, 0.48, 12, 22, R_STAB, L_BACK, L),
			_t(0.3, 0.46, 10, 18, R_STAB, L_BACK, L),
			_t(0.5, 0.34, 0, 4, R_READY, L_GUARD, W),
		]},
		# 6 Renda: üç hızlı savuruş -> sıçrayıp baş üstünden iniş
		{"len": 1.2, "hit": 0.84, "extra_hits": [0.18, 0.36, 0.54], "extra_radius": 1.4, "keys": [
			_t(0.0, 0.34, 0, 4, R_READY, L_GUARD, W),
			_t(0.1, 0.4, 22, 6, R_BACK, L_OPEN, CR),
			_t(0.18, 0.44, -22, 12, R_LEFT, L_OPEN, L),
			_t(0.28, 0.44, 22, 10, R_RIGHT, L_OPEN, LL),
			_t(0.36, 0.44, -22, 12, R_LEFT, L_OPEN, L),
			_t(0.46, 0.44, 22, 10, R_RIGHT, L_OPEN, LL),
			_t(0.54, 0.44, -18, 10, R_LEFT, L_OPEN, L),
			_t(0.7, 0.2, 0, -16, R_HIGH, L_OPEN, ST),
			_t(0.84, 0.6, 0, 30, R_DOWN, L_BACK, L),
			_t(0.98, 0.56, 0, 26, R_DOWN, L_BACK, L),
			_t(1.2, 0.34, 0, 4, R_READY, L_GUARD, W),
		]},
	]
