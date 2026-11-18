extends RefCounted
## Fujaku Hishō Shōken kombosu: iki elde ikiz jian, hızlı çapraz kesikler, rüzgâr. 1 Migi-kiri, 2 Hidari-kiri, 3 Kaze-kiri (uçan rüzgâr kesiği),
## 4 Kujaku Senpū (kasırgayla yükselir), 5 Kaze-gaeshi (mermileri geri çevirir), 6 Gattai-giri (iki kılıç birleşir, büyük kesik).

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_G := {"RightUpperArm": Vector3(-0.3, -0.75, 0.59), "RightLowerArm": Vector3(0.45, 0.25, 0.86)}
const L_G := {"LeftUpperArm": Vector3(0.3, -0.75, 0.59), "LeftLowerArm": Vector3(-0.45, 0.25, 0.86)}
const R_B := {"RightUpperArm": Vector3(-0.8, 0.1, -0.55), "RightLowerArm": Vector3(-0.4, 0.5, -0.76)}
const L_BK := {"LeftUpperArm": Vector3(0.8, 0.1, -0.55), "LeftLowerArm": Vector3(0.4, 0.5, -0.76)}
const R_A := {"RightUpperArm": Vector3(0.12, -0.1, 0.98), "RightLowerArm": Vector3(0.9, 0.0, 0.42)}
const L_A := {"LeftUpperArm": Vector3(-0.12, -0.1, 0.98), "LeftLowerArm": Vector3(-0.9, 0.0, 0.42)}
const R_O := {"RightUpperArm": Vector3(-0.95, 0.1, 0.25), "RightLowerArm": Vector3(-0.9, 0.2, 0.35)}
const L_O := {"LeftUpperArm": Vector3(0.95, 0.1, 0.25), "LeftLowerArm": Vector3(0.9, 0.2, 0.35)}
const R_X := {"RightUpperArm": Vector3(-0.3, 0.1, 0.95), "RightLowerArm": Vector3(0.72, 0.45, 0.53)}
const L_X := {"LeftUpperArm": Vector3(0.3, 0.1, 0.95), "LeftLowerArm": Vector3(-0.72, 0.45, 0.53)}
const R_UP := {"RightUpperArm": Vector3(-0.25, 0.95, 0.15), "RightLowerArm": Vector3(0.1, 0.98, 0.15)}
const R_DN := {"RightUpperArm": Vector3(-0.1, -0.3, 0.95), "RightLowerArm": Vector3(0.12, -0.65, 0.75)}


static func _t(t: float, c: float, y: float, l: float, b: Vector3, r: Dictionary, lg: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.3, l * 1.2, b.normalized(), S._a(r, lg), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var B = S.LEG_BACK
	var ST = S.LEG_STEP
	var F = Vector3(0.2, 0.55, 0.8)
	var RT = Vector3(0.88, 0.05, 0.46)
	var UP = Vector3(0, 0.95, -0.2)
	var DN = Vector3(0, -0.72, 0.68)
	return [
		{"len": 0.48, "hit": 0.18, "keys": [_t(0, 0.42, 0, 5, F, R_G, L_G, W), _t(0.1, 0.44, -20, 0, F, R_B, L_G, B), _t(0.18, 0.5, 20, 12, RT, R_A, L_G, L), _t(0.48, 0.42, 0, 5, F, R_G, L_G, W)]},
		{"len": 0.48, "hit": 0.18, "keys": [_t(0, 0.44, 8, 6, RT, R_G, L_G, W), _t(0.1, 0.44, 20, 0, F, R_G, L_BK, B), _t(0.18, 0.5, -20, 12, Vector3(-0.2, 0.3, 0.93), R_G, L_A, LL), _t(0.48, 0.42, 0, 5, F, R_G, L_G, W)]},
		{"len": 0.74, "hit": 0.3, "keys": [_t(0, 0.42, 0, 5, F, R_G, L_G, W), _t(0.18, 0.46, 0, -4, F, R_B, L_BK, B), _t(0.3, 0.5, 0, 12, RT, R_A, L_A, L), _t(0.74, 0.42, 0, 5, F, R_G, L_G, W)]},
		{"len": 1.1, "hit": 0.34, "keys": [_t(0, 0.5, 0, 12, F, R_G, L_G, W), _t(0.16, 0.34, 80, -4, RT, R_O, L_O, ST), _t(0.5, 0.3, 240, -6, RT, R_O, L_O, ST), _t(0.86, 0.34, 340, 0, RT, R_O, L_O, W), _t(1.1, 0.42, 0, 5, F, R_G, L_G, W)]},
		{"len": 0.9, "hit": 0.56, "keys": [_t(0, 0.42, 0, 5, F, R_G, L_G, W), _t(0.12, 0.5, 0, 8, F, R_X, L_X, B), _t(0.52, 0.5, 0, 8, F, R_X, L_X, B), _t(0.6, 0.48, 0, 12, RT, R_O, L_O, L), _t(0.9, 0.42, 0, 5, F, R_G, L_G, W)]},
		{"len": 1.55, "hit": 0.88, "keys": [_t(0, 0.42, 0, 5, F, R_G, L_G, W), _t(0.24, 0.46, 0, 2, F, R_X, L_X, W), _t(0.5, 0.42, -6, -10, UP, R_UP, L_X, B), _t(0.8, 0.4, -8, -14, UP, R_UP, L_X, B), _t(0.88, 0.66, 8, 28, DN, R_DN, L_O, L), _t(1.25, 0.62, 6, 22, DN, R_DN, L_O, L), _t(1.55, 0.42, 0, 5, F, R_G, L_G, W)]},
	]
