extends RefCounted
## Kusari Fūbō (Tenten, anime 162; ref refs/kusari_fubo/Chain_Wind_Staff.png): kısa sopa, iki ucunda zincirli ağırlık. Dönerek biçer, bumerang gibi atılır.
## 1 Migi-uchi, 2 Hidari-uchi, 3 Sōchō (iki uç birden), 4 Fūsha (önde hızlı çevirme), 5 Nage (atılıp döner), 6 Kaze-kudaki (atılır, hedefte dönüp zırh keser).

const S = preload("res://scripts/combat/samehada_anim.gd")

const HIT := [0.24, 0.24, 0.32, 0.26, 0.3, 0.46]
const R_G := {"RightUpperArm": Vector3(-0.3, -0.8, 0.52), "RightLowerArm": Vector3(0.25, 0.1, 0.96)}
const L_G := {"LeftUpperArm": Vector3(0.3, -0.85, 0.42), "LeftLowerArm": Vector3(-0.15, 0.0, 0.98)}
const R_BACK := {"RightUpperArm": Vector3(-0.8, 0.1, -0.5), "RightLowerArm": Vector3(-0.2, 0.75, -0.6)}
const R_OUT := {"RightUpperArm": Vector3(-0.2, 0.05, 0.98), "RightLowerArm": Vector3(0.1, 0.05, 1)}
const R_UP := {"RightUpperArm": Vector3(-0.35, 0.85, 0.35), "RightLowerArm": Vector3(0.1, 0.8, 0.58)}
const R_ACR := {"RightUpperArm": Vector3(0.1, -0.1, 0.99), "RightLowerArm": Vector3(0.85, 0.1, 0.5)}
const L_B := {"LeftUpperArm": Vector3(0.5, -0.65, -0.55), "LeftLowerArm": Vector3(0.25, -0.5, -0.8)}


static func _t(t: float, c: float, y: float, l: float, b: Vector3, r: Dictionary, lg: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.3, l * 1.2, b.normalized(), S._a(r, lg), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var F = Vector3(1, 0.2, 0.6)
	return [
		{"len": 0.6, "hit": HIT[0], "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.14, 0.42, -24, -4, F, R_BACK, L_G, B), _t(0.24, 0.48, 20, 12, F, R_OUT, L_B, L), _t(0.6, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.6, "hit": HIT[1], "keys": [_t(0, 0.44, 16, 8, F, R_OUT, L_B, W), _t(0.14, 0.42, 26, 2, F, R_ACR, L_G, B), _t(0.24, 0.48, -22, 12, F, R_OUT, L_G, L), _t(0.6, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.78, "hit": HIT[2], "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.2, 0.36, -12, -10, Vector3(1, 0.5, 0), R_UP, L_G, B), _t(0.32, 0.52, 10, 18, Vector3(1, -0.2, 0.3), R_OUT, L_B, L), _t(0.78, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.95, "hit": HIT[3], "extra_hits": [0.42, 0.58, 0.74], "extra_radius": 2.3, "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.16, 0.46, 0, 10, Vector3(1, 0, 0.1), R_OUT, L_B, L), _t(0.78, 0.46, 0, 10, Vector3(1, 0, 0.1), R_OUT, L_B, L), _t(0.95, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.2, "hit": HIT[4], "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.2, 0.42, -28, -6, F, R_BACK, L_G, B), _t(0.3, 0.5, 26, 14, F, R_OUT, L_B, L), _t(0.95, 0.44, 8, 6, F, R_OUT, L_G, W), _t(1.2, 0.4, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.85, "hit": HIT[5], "keys": [_t(0, 0.4, 0, 4, F, R_G, L_G, W), _t(0.34, 0.46, -34, -8, F, R_BACK, L_G, B), _t(0.46, 0.54, 30, 18, F, R_OUT, L_B, L), _t(1.55, 0.46, 8, 6, F, R_OUT, L_G, W), _t(1.85, 0.4, 0, 4, F, R_G, L_G, W)]},
	]
