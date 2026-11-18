extends RefCounted
## Flail (Rensa-tsuchi) kombosu. Tek el sap; baş zincirle gecikir (zincir_uc). Ağır ritim: geri al, dur, savur, ağırlığa bırak, yavaş topla.
## 1 Yoko-nagi, 2 Kaeshi-nagi, 3 Tsuchi-otoshi (tepeden çakış), 4 Maki-tsuke (dolayıp çeker), 5 Kaiten (baş üstünde döner), 6 Daichi-uchi (bitiriş).

const S = preload("res://scripts/combat/samehada_anim.gd")

const HIT := [0.42, 0.38, 0.52, 0.42, 0.34, 1.05]
const R_G := {"RightUpperArm": Vector3(-0.35, -0.8, 0.45), "RightLowerArm": Vector3(0.1, 0.1, 0.99)}
const L_G := {"LeftUpperArm": Vector3(0.3, -0.85, 0.42), "LeftLowerArm": Vector3(-0.15, 0.1, 0.98)}
const R_BACK := {"RightUpperArm": Vector3(-0.85, -0.2, -0.48), "RightLowerArm": Vector3(-0.7, 0.25, -0.66)}
const R_ACR := {"RightUpperArm": Vector3(0.15, -0.1, 0.98), "RightLowerArm": Vector3(0.9, 0.05, 0.42)}
const R_OUT := {"RightUpperArm": Vector3(-0.8, 0.0, 0.6), "RightLowerArm": Vector3(-0.75, 0.05, 0.66)}
const R_UP := {"RightUpperArm": Vector3(-0.35, 0.92, 0.1), "RightLowerArm": Vector3(0.05, 0.98, 0.15)}
const R_DOWN := {"RightUpperArm": Vector3(-0.15, -0.3, 0.94), "RightLowerArm": Vector3(0.05, -0.7, 0.7)}
const R_FWD := {"RightUpperArm": Vector3(-0.1, 0.05, 1), "RightLowerArm": Vector3(0.0, 0.05, 1)}
const L_B := {"LeftUpperArm": Vector3(0.5, -0.65, -0.55), "LeftLowerArm": Vector3(0.25, -0.5, -0.8)}


static func _t(t: float, c: float, y: float, l: float, b: Vector3, r: Dictionary, lg: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.3, l * 1.2, b.normalized(), S._a(r, lg), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var ST = S.LEG_STEP
	var F = Vector3(0, 0.3, 1)
	var BK = Vector3(-0.8, 0.3, -0.5)
	var UP = Vector3(0, 0.9, -0.3)
	var DN = Vector3(0, -0.6, 0.8)
	var TOP = Vector3(0, 1, 0.1)
	return [
		{"len": 0.95, "hit": HIT[0], "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.24, 0.44, -34, -6, BK, R_BACK, L_G, B), _t(0.32, 0.45, -36, -7, BK, R_BACK, L_G, B), _t(0.42, 0.52, 30, 14, Vector3(0.8, 0.1, 0.6), R_ACR, L_B, L), _t(0.95, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.9, "hit": HIT[1], "keys": [_t(0, 0.46, 24, 8, Vector3(0.8, 0.1, 0.6), R_ACR, L_B, W), _t(0.24, 0.46, 34, 2, Vector3(0.8, 0.2, 0.5), R_ACR, L_G, B), _t(0.38, 0.52, -30, 14, Vector3(-0.85, 0.1, 0.5), R_OUT, L_G, ST), _t(0.9, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.15, "hit": HIT[2], "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.3, 0.34, -10, -14, UP, R_UP, L_G, B), _t(0.42, 0.34, -10, -15, UP, R_UP, L_G, B), _t(0.52, 0.62, 8, 28, DN, R_DOWN, L_B, L), _t(0.8, 0.6, 6, 24, DN, R_DOWN, L_B, L), _t(1.15, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.0, "hit": HIT[3], "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.26, 0.44, -24, -4, BK, R_BACK, L_G, B), _t(0.42, 0.5, 22, 12, Vector3(0, 0.1, 1), R_FWD, L_G, L), _t(0.62, 0.46, -18, -8, Vector3(0, 0.3, 0.9), R_G, L_G, B), _t(1.0, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.15, "hit": HIT[4], "extra_hits": [0.58, 0.82], "extra_radius": 2.7, "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.2, 0.42, 0, 0, TOP, R_UP, L_G, W), _t(0.9, 0.42, 0, 0, TOP, R_UP, L_G, W), _t(1.15, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.75, "hit": HIT[5], "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.3, 0.44, 0, -2, TOP, R_UP, L_G, W), _t(0.86, 0.36, -8, -16, UP, R_UP, L_B, B), _t(0.96, 0.36, -8, -17, UP, R_UP, L_B, B), _t(1.05, 0.68, 10, 32, DN, R_DOWN, L_B, L), _t(1.4, 0.64, 8, 26, DN, R_DOWN, L_B, L), _t(1.75, 0.4, 0, 4, F, R_G, L_G, W)]},
	]
