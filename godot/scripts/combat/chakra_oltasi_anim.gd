extends RefCounted
## Chakra oltası (Urashiki; ref refs/chakra_oltasi) kombosu: tek elle ince kızıl olta, bilek hareketiyle atılır.
## 1 Nage-zuri (düz atış), 2 Yoko-zuri (yandan süpürür), 3 Sao-uke (oltayla karşılar), 4 Hiki-zuri (takıp çeker), 5 Amenosubaru (iğne yağmuru), 6 Chakra-zuri (delip chakra çeker).

const S = preload("res://scripts/combat/samehada_anim.gd")

const HIT := [0.26, 0.3, 0.5, 0.3, 0.36, 0.72]
const R_G := {"RightUpperArm": Vector3(-0.3, -0.85, 0.42), "RightLowerArm": Vector3(0.05, -0.55, 0.83)}
const L_G := {"LeftUpperArm": Vector3(0.45, -0.75, 0.48), "LeftLowerArm": Vector3(0.25, 0.35, 0.9)}
const R_UP := {"RightUpperArm": Vector3(-0.35, 0.55, 0.75), "RightLowerArm": Vector3(-0.1, 0.92, -0.35)}
const R_FW := {"RightUpperArm": Vector3(-0.15, 0.0, 0.99), "RightLowerArm": Vector3(0.0, 0.08, 1)}
const R_BK := {"RightUpperArm": Vector3(-0.85, -0.1, -0.5), "RightLowerArm": Vector3(-0.55, 0.15, -0.8)}
const R_AC := {"RightUpperArm": Vector3(0.1, -0.1, 0.99), "RightLowerArm": Vector3(0.9, 0.0, 0.42)}
const R_BL := {"RightUpperArm": Vector3(-0.35, -0.3, 0.88), "RightLowerArm": Vector3(0.75, 0.55, 0.35)}
const L_P := {"LeftUpperArm": Vector3(0.45, -0.1, 0.88), "LeftLowerArm": Vector3(-0.1, 0.25, 0.96)}


static func _t(t: float, c: float, y: float, l: float, b: Vector3, r: Dictionary, lg: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.3, l * 1.2, b.normalized(), S._a(r, lg), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var F = Vector3(0.15, -0.55, 0.82)
	var UP = Vector3(0, 0.9, -0.42)
	var FW = Vector3(0, 0.2, 0.98)
	return [
		{"len": 0.66, "hit": HIT[0], "keys": [_t(0, 0.36, 0, 2, F, R_G, L_G, W), _t(0.16, 0.36, -14, -6, UP, R_UP, L_G, B), _t(0.26, 0.4, 12, 8, FW, R_FW, L_G, L), _t(0.66, 0.36, 0, 2, F, R_G, L_G, W)]},
		{"len": 0.7, "hit": HIT[1], "keys": [_t(0, 0.36, 0, 2, F, R_G, L_G, W), _t(0.18, 0.4, -24, -2, Vector3(-0.85, 0.2, -0.45), R_BK, L_G, B), _t(0.3, 0.44, 22, 8, Vector3(0.88, 0.1, 0.45), R_AC, L_G, L), _t(0.7, 0.36, 0, 2, F, R_G, L_G, W)]},
		{"len": 0.85, "hit": HIT[2], "keys": [_t(0, 0.36, 0, 2, F, R_G, L_G, W), _t(0.1, 0.42, 8, 4, Vector3(0.7, 0.7, 0.1), R_BL, L_G, B), _t(0.52, 0.42, 8, 4, Vector3(0.7, 0.7, 0.1), R_BL, L_G, B), _t(0.85, 0.36, 0, 2, F, R_G, L_G, W)]},
		{"len": 0.85, "hit": HIT[3], "keys": [_t(0, 0.36, 0, 2, F, R_G, L_G, W), _t(0.18, 0.36, -12, -6, UP, R_UP, L_G, B), _t(0.3, 0.42, 12, 8, FW, R_FW, L_G, L), _t(0.5, 0.4, -14, -10, UP, R_UP, L_G, B), _t(0.85, 0.36, 0, 2, F, R_G, L_G, W)]},
		{"len": 0.95, "hit": HIT[4], "keys": [_t(0, 0.36, 0, 2, F, R_G, L_G, W), _t(0.24, 0.36, 0, -6, UP, R_UP, L_P, B), _t(0.36, 0.42, 6, 8, FW, R_FW, L_P, L), _t(0.95, 0.36, 0, 2, F, R_G, L_G, W)]},
		{"len": 1.5, "hit": HIT[5], "keys": [_t(0, 0.36, 0, 2, F, R_G, L_G, W), _t(0.5, 0.34, -14, -8, UP, R_UP, L_P, B), _t(0.72, 0.44, 14, 10, FW, R_FW, L_P, L), _t(1.15, 0.4, -16, -10, UP, R_UP, L_P, B), _t(1.5, 0.36, 0, 2, F, R_G, L_G, W)]},
	]
