extends RefCounted
## Çift ağızlı tırpan (Ryūki; ref refs/cift_tirpan/Double-Bladed_Scythe.png). Hidan'ın tırpanından hafif ve kablosuz: hızlı, iki elle kısa yaylar.
## 1 Nagi, 2 Kaeshi, 3 Hikkake (kanca, çeker), 4 Age-giri (kaldırır), 5 Kaiten-giri (dönerek), 6 Chimatsuri (toplanan kanla bitiriş).

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_G := {"RightUpperArm": Vector3(-0.3, -0.85, 0.42), "RightLowerArm": Vector3(0.25, 0.3, 0.92)}
const R_BK := {"RightUpperArm": Vector3(-0.75, -0.3, -0.58), "RightLowerArm": Vector3(-0.45, 0.2, 0.87)}
const R_FR := {"RightUpperArm": Vector3(0.05, -0.3, 0.95), "RightLowerArm": Vector3(0.75, -0.05, 0.65)}
const R_OUT := {"RightUpperArm": Vector3(-0.7, -0.3, 0.65), "RightLowerArm": Vector3(-0.3, -0.05, 0.95)}
const R_LOW := {"RightUpperArm": Vector3(-0.35, -0.9, 0.25), "RightLowerArm": Vector3(0.2, -0.55, 0.8)}
const R_HI := {"RightUpperArm": Vector3(-0.4, 0.75, 0.52), "RightLowerArm": Vector3(0.3, 0.8, 0.5)}
const L_S := {"LeftUpperArm": Vector3(0.3, -0.75, 0.58), "LeftLowerArm": Vector3(-0.4, 0.1, 0.9)}


static func _t(t: float, c: float, y: float, l: float, b: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.3, l * 1.2, b.normalized(), S._a(r, L_S), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var ST = S.LEG_STEP
	var C = S.LEG_CROSS
	var G = Vector3(0.2, 0.75, 0.6)
	var BK = Vector3(-0.8, 0.3, -0.5)
	var RT = Vector3(0.85, 0.05, 0.5)
	var UP = Vector3(-0.2, 0.9, -0.3)
	var DN = Vector3(0.1, -0.6, 0.8)
	var SP = Vector3(0.9, 0.05, 0.4)
	return [
		{"len": 0.66, "hit": 0.3, "two": true, "keys": [_t(0, 0.42, 0, 4, G, R_G, W), _t(0.18, 0.46, -30, -6, BK, R_BK, B), _t(0.24, 0.47, -32, -7, BK, R_BK, B), _t(0.3, 0.52, 28, 14, RT, R_FR, L), _t(0.66, 0.42, 0, 4, G, R_G, W)]},
		{"len": 0.6, "hit": 0.25, "two": true, "keys": [_t(0, 0.5, 22, 10, RT, R_FR, W), _t(0.25, 0.52, -26, 12, Vector3(-0.85, 0.1, 0.5), R_OUT, ST), _t(0.6, 0.42, 0, 4, G, R_G, W)]},
		{"len": 0.8, "hit": 0.32, "two": true, "keys": [_t(0, 0.42, 0, 4, G, R_G, W), _t(0.2, 0.44, -20, 2, Vector3(-0.4, 0.5, 0.75), R_OUT, B), _t(0.32, 0.5, 8, 16, Vector3(0, 0.1, 1), R_FR, L), _t(0.5, 0.44, -14, -8, Vector3(-0.2, 0.5, 0.8), R_G, B), _t(0.8, 0.42, 0, 4, G, R_G, W)]},
		{"len": 0.78, "hit": 0.32, "two": true, "keys": [_t(0, 0.42, 0, 4, G, R_G, W), _t(0.2, 0.62, -14, 14, Vector3(-0.3, -0.75, 0.55), R_LOW, B), _t(0.32, 0.38, 16, -10, Vector3(0.1, 0.92, 0.35), R_HI, L), _t(0.78, 0.42, 0, 4, G, R_G, W)]},
		{"len": 0.9, "hit": 0.34, "two": true, "keys": [_t(0, 0.42, 0, 4, G, R_G, W), _t(0.14, 0.46, 60, 6, SP, R_FR, C), _t(0.34, 0.5, 200, 8, SP, R_FR, W), _t(0.54, 0.48, 300, 6, SP, R_FR, C), _t(0.9, 0.42, 0, 4, G, R_G, W)]},
		{"len": 1.45, "hit": 0.82, "two": true, "keys": [_t(0, 0.42, 0, 4, G, R_G, W), _t(0.4, 0.4, -16, -14, UP, R_HI, B), _t(0.72, 0.38, -18, -16, UP, R_HI, B), _t(0.82, 0.66, 14, 30, DN, R_LOW, L), _t(1.1, 0.62, 10, 24, DN, R_LOW, L), _t(1.45, 0.42, 0, 4, G, R_G, W)]},
	]
