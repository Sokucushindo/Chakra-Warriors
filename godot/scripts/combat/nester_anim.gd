extends RefCounted
## Mesu (neşter) kombosu: iki elde ince cerrahi bıçak; küçük, kesin hareketler, hedefin eklemlerine.
## 1 Tekubi (bilek), 2 Hiza (diz), 3 Ken-giri (kiriş, geçerken), 4 Nage-mesu (üç neşter atar), 5 Kubi-suji (boyun yanı), 6 Kaibō (altı neşter, kilit noktalar).

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_G := {"RightUpperArm": Vector3(-0.2, -0.8, 0.56), "RightLowerArm": Vector3(0.25, 0.55, 0.8)}
const L_G := {"LeftUpperArm": Vector3(0.2, -0.8, 0.56), "LeftLowerArm": Vector3(-0.25, 0.55, 0.8)}
const R_P := {"RightUpperArm": Vector3(-0.08, 0.0, 1), "RightLowerArm": Vector3(0.1, 0.02, 1)}
const R_L := {"RightUpperArm": Vector3(-0.1, -0.65, 0.75), "RightLowerArm": Vector3(0.05, -0.7, 0.72)}
const L_L := {"LeftUpperArm": Vector3(0.1, -0.65, 0.75), "LeftLowerArm": Vector3(-0.05, -0.7, 0.72)}
const R_C := {"RightUpperArm": Vector3(-0.6, 0.35, -0.7), "RightLowerArm": Vector3(-0.2, 0.7, 0.6)}
const L_C := {"LeftUpperArm": Vector3(0.6, 0.35, -0.7), "LeftLowerArm": Vector3(0.2, 0.7, 0.6)}
const R_O := {"RightUpperArm": Vector3(-0.95, 0.05, 0.3), "RightLowerArm": Vector3(-0.85, 0.0, 0.5)}
const L_O := {"LeftUpperArm": Vector3(0.95, 0.05, 0.3), "LeftLowerArm": Vector3(0.85, 0.0, 0.5)}
const R_N := {"RightUpperArm": Vector3(-0.1, 0.25, 0.96), "RightLowerArm": Vector3(0.35, 0.35, 0.87)}


static func _t(t: float, c: float, y: float, l: float, b: Vector3, r: Dictionary, lg: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.3, l * 1.2, b.normalized(), S._a(r, lg), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var B = S.LEG_BACK
	var F = Vector3(0, 0.1, 1)
	return [
		{"len": 0.44, "hit": 0.14, "keys": [_t(0, 0.4, 0, 6, F, R_G, L_G, W), _t(0.14, 0.46, 20, 12, F, R_P, L_G, L), _t(0.44, 0.4, 0, 6, F, R_G, L_G, W)]},
		{"len": 0.48, "hit": 0.18, "keys": [_t(0, 0.42, 8, 8, F, R_G, L_G, W), _t(0.18, 0.66, -18, 24, Vector3(0, -0.6, 0.8), R_G, L_L, LL), _t(0.48, 0.4, 0, 6, F, R_G, L_G, W)]},
		{"len": 0.62, "hit": 0.24, "keys": [_t(0, 0.4, 0, 6, F, R_G, L_G, W), _t(0.1, 0.48, -16, 10, F, R_G, L_G, B), _t(0.24, 0.6, 24, 22, Vector3(0, -0.5, 0.85), R_L, L_G, L), _t(0.62, 0.4, 0, 6, F, R_G, L_G, W)]},
		{"len": 0.66, "hit": 0.28, "keys": [_t(0, 0.4, 0, 6, F, R_G, L_G, W), _t(0.16, 0.42, -20, -6, F, R_C, L_G, B), _t(0.28, 0.44, 16, 12, F, R_P, L_G, L), _t(0.66, 0.4, 0, 6, F, R_G, L_G, W)]},
		{"len": 0.6, "hit": 0.22, "keys": [_t(0, 0.4, 0, 6, F, R_G, L_G, W), _t(0.12, 0.44, -14, 2, F, R_C, L_G, B), _t(0.22, 0.42, 22, 8, Vector3(0.1, 0.35, 0.93), R_N, L_G, L), _t(0.6, 0.4, 0, 6, F, R_G, L_G, W)]},
		{"len": 1.1, "hit": 0.52, "keys": [_t(0, 0.4, 0, 6, F, R_G, L_G, W), _t(0.3, 0.46, 0, -4, F, R_C, L_C, B), _t(0.44, 0.47, 0, -5, F, R_C, L_C, B), _t(0.52, 0.44, 0, 12, F, R_O, L_O, L), _t(1.1, 0.4, 0, 6, F, R_G, L_G, W)]},
	]
