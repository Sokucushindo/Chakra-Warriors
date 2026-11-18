extends RefCounted
## Gariantō kombosu: üç çatallı kılıç, ağızlar telle ayrılıp urumi gibi uzar. Kol kısa işaret verir; uzanan parçaları GariandoFX yürütür.
## 1 Tsuki-nobi (uzayan saplama), 2 Muchi-nagi (kırbaç süpürme), 3 Maki-tsuki (dolayıp çeker), 4 Hon-giri (kılıç toplu sert kesik),
## 5 Sanja-mai (üç ağız etrafta döner), 6 Ryūgan (ağızlar ejderha olur).

const S = preload("res://scripts/combat/samehada_anim.gd")

const HIT := [0.3, 0.34, 0.34, 0.3, 0.3, 0.82]
const R_G := {"RightUpperArm": Vector3(-0.3, -0.8, 0.52), "RightLowerArm": Vector3(0.25, 0.25, 0.93)}
const L_G := {"LeftUpperArm": Vector3(0.28, -0.85, 0.44), "LeftLowerArm": Vector3(-0.18, 0.05, 0.98)}
const R_C := {"RightUpperArm": Vector3(-0.5, -0.55, -0.67), "RightLowerArm": Vector3(-0.05, 0.25, 0.97)}
const R_FW := {"RightUpperArm": Vector3(-0.08, 0.05, 1), "RightLowerArm": Vector3(0.0, 0.03, 1)}
const R_BK := {"RightUpperArm": Vector3(-0.85, 0.05, -0.5), "RightLowerArm": Vector3(-0.55, 0.4, -0.72)}
const R_AC := {"RightUpperArm": Vector3(0.12, -0.1, 0.98), "RightLowerArm": Vector3(0.9, 0.0, 0.42)}
const R_UP := {"RightUpperArm": Vector3(-0.3, 0.92, 0.2), "RightLowerArm": Vector3(0.05, 0.98, 0.15)}
const L_B := {"LeftUpperArm": Vector3(0.5, -0.65, -0.55), "LeftLowerArm": Vector3(0.25, -0.5, -0.8)}
const L_SEAL := {"LeftUpperArm": Vector3(0.25, -0.5, 0.82), "LeftLowerArm": Vector3(-0.72, 0.5, 0.48)}


static func _t(t: float, c: float, y: float, l: float, b: Vector3, r: Dictionary, lg: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.3, l * 1.2, b.normalized(), S._a(r, lg), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var F = Vector3(0.1, 0.35, 0.93)
	var FW = Vector3(0, 0.03, 1)
	var RT = Vector3(0.88, 0.05, 0.46)
	var BK = Vector3(-0.85, 0.3, -0.42)
	var UP = Vector3(0, 1, 0.1)
	return [
		{"len": 0.78, "hit": HIT[0], "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.2, 0.46, -24, -5, FW, R_C, L_G, B), _t(0.3, 0.52, 22, 14, FW, R_FW, L_B, L), _t(0.56, 0.5, 20, 12, FW, R_FW, L_B, L), _t(0.78, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.85, "hit": HIT[1], "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.22, 0.46, -30, -6, BK, R_BK, L_G, B), _t(0.34, 0.54, 28, 14, RT, R_AC, L_B, L), _t(0.85, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.95, "hit": HIT[2], "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.22, 0.46, -20, -4, FW, R_C, L_G, B), _t(0.34, 0.5, 18, 12, FW, R_FW, L_B, L), _t(0.6, 0.44, -18, -8, F, R_G, L_G, B), _t(0.95, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 0.72, "hit": HIT[3], "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.2, 0.46, -30, -6, BK, R_BK, L_G, B), _t(0.3, 0.56, 30, 16, RT, R_AC, L_B, L), _t(0.72, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.1, "hit": HIT[4], "extra_hits": [0.52, 0.74], "extra_radius": 3.3, "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.2, 0.44, 0, 0, UP, R_UP, L_B, W), _t(0.86, 0.44, 0, 0, UP, R_UP, L_B, W), _t(1.1, 0.42, 0, 4, F, R_G, L_G, W)]},
		{"len": 1.7, "hit": HIT[5], "keys": [_t(0, 0.42, 0, 4, F, R_G, L_G, W), _t(0.3, 0.5, 0, 2, UP, R_UP, L_SEAL, B), _t(0.72, 0.52, 0, 0, UP, R_UP, L_SEAL, B), _t(0.82, 0.56, 16, 16, FW, R_FW, L_SEAL, L), _t(1.4, 0.54, 12, 12, FW, R_FW, L_SEAL, L), _t(1.7, 0.42, 0, 4, F, R_G, L_G, W)]},
	]
