extends RefCounted
## Honō no Ken (Takumi ateş kılıcı; anime 217) kombosu: uzun ağır kılıç, her savuruş alev bırakır.
## 1 Hi-nagi, 2 Kaeshi-bi, 3 Hibashira (yere saplar, ileri alev sütunları), 4 Enrin (döner, alev halkası), 5 Kōsen (uçtaki yeşil küreden ışın), 6 Gōen-giri (bitiriş).

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_G := {"RightUpperArm": Vector3(-0.3, -0.8, 0.52), "RightLowerArm": Vector3(0.3, 0.2, 0.93)}
const L_G := {"LeftUpperArm": Vector3(0.25, -0.85, 0.46), "LeftLowerArm": Vector3(-0.2, 0.05, 0.98)}
const R_BK := {"RightUpperArm": Vector3(-0.85, 0.05, -0.5), "RightLowerArm": Vector3(-0.5, 0.45, -0.72)}
const R_AC := {"RightUpperArm": Vector3(0.15, -0.1, 0.98), "RightLowerArm": Vector3(0.9, -0.05, 0.42)}
const R_OUT := {"RightUpperArm": Vector3(-0.8, -0.05, 0.6), "RightLowerArm": Vector3(-0.72, 0.0, 0.69)}
const R_UP := {"RightUpperArm": Vector3(-0.3, 0.9, 0.3), "RightLowerArm": Vector3(0.1, 0.95, 0.3)}
const R_DN := {"RightUpperArm": Vector3(-0.1, -0.35, 0.93), "RightLowerArm": Vector3(0.1, -0.7, 0.7)}
const R_FW := {"RightUpperArm": Vector3(-0.08, 0.05, 1), "RightLowerArm": Vector3(0.0, 0.03, 1)}
const L_B := {"LeftUpperArm": Vector3(0.5, -0.65, -0.55), "LeftLowerArm": Vector3(0.25, -0.5, -0.8)}


static func _t(t: float, c: float, y: float, l: float, b: Vector3, r: Dictionary, lg: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.3, l * 1.2, b.normalized(), S._a(r, lg), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var ST = S.LEG_STEP
	var C = S.LEG_CROSS
	var F = Vector3(0.1, 0.45, 0.88)
	var BK = Vector3(-0.85, 0.3, -0.42)
	var RT = Vector3(0.88, 0.05, 0.46)
	var LF = Vector3(-0.88, 0.05, 0.46)
	var UP = Vector3(0, 0.92, -0.35)
	var DN = Vector3(0, -0.82, 0.56)
	var FW = Vector3(0, 0.02, 1)
	return [
		{"len": 0.82, "hit": 0.34, "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.2, 0.46, -30, -6, BK, R_BK, L_G, B), _t(0.27, 0.47, -32, -7, BK, R_BK, L_G, B), _t(0.34, 0.54, 28, 14, RT, R_AC, L_B, L), _t(0.82, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.76, "hit": 0.3, "keys": [_t(0, 0.5, 22, 10, RT, R_AC, L_B, W), _t(0.2, 0.48, 30, 4, RT, R_AC, L_G, B), _t(0.3, 0.54, -28, 14, LF, R_OUT, L_G, ST), _t(0.76, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.05, "hit": 0.42, "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.26, 0.36, -8, -14, UP, R_UP, L_G, B), _t(0.35, 0.36, -8, -15, UP, R_UP, L_G, B), _t(0.42, 0.68, 8, 30, DN, R_DN, L_B, L), _t(0.76, 0.64, 6, 24, DN, R_DN, L_B, L), _t(1.05, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.05, "hit": 0.46, "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.18, 0.5, 50, 8, RT, R_AC, L_B, C), _t(0.46, 0.54, 200, 10, RT, R_OUT, L_B, W), _t(0.66, 0.52, 310, 8, RT, R_OUT, L_B, C), _t(1.05, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.95, "hit": 0.36, "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.22, 0.44, -22, -4, FW, R_G, L_G, B), _t(0.36, 0.46, 14, 8, FW, R_FW, L_B, L), _t(0.68, 0.46, 12, 7, FW, R_FW, L_B, L), _t(0.95, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.75, "hit": 0.95, "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.4, 0.5, -34, -8, BK, R_BK, L_G, B), _t(0.86, 0.54, -38, -10, BK, R_BK, L_G, B), _t(0.95, 0.62, 34, 20, RT, R_AC, L_B, L), _t(1.35, 0.58, 28, 14, RT, R_AC, L_B, L), _t(1.75, 0.42, 0, 4, F, R_G, L_G, W)]},
	]
