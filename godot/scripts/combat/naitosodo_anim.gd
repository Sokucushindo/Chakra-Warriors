extends RefCounted
## Naitosōdo (ナイトソード, Knight Sword; kanon film: Temujin — refs/naitosodo): TEK EL Avrupa kısa kılıcı; ağız boğumlarından uzayıp tam boy geniş kılıç olur. Şövalye kılıç oyunu: düz duruş, kol uzatışı, kabza vuruşu.
## 1 Tsuki (kısa), 2 Kaeshi Giri (kısa ters), 3 Nobi Tsuki: saplarken ağız uzar, 4 Ō Nagi: uzun ağızla yatay, 5 Tsuka Uchi: ağız toplanır, kabza topuzuyla yüze, 6 Hikari Giri: ağıza chakra, geniş ışık kesiği.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_GUARD := {"RightUpperArm": Vector3(-0.3, -0.75, 0.58), "RightLowerArm": Vector3(0.18, 0.4, 0.9)}
const R_BACK := {"RightUpperArm": Vector3(-0.6, -0.45, -0.66), "RightLowerArm": Vector3(0.0, 0.3, 0.95)}
const R_HI := {"RightUpperArm": Vector3(-0.3, 0.9, 0.3), "RightLowerArm": Vector3(-0.1, 0.92, -0.36)}
const R_SIDE := {"RightUpperArm": Vector3(-0.95, 0.0, -0.3), "RightLowerArm": Vector3(-0.7, 0.1, -0.7)}
const R_L := {"RightUpperArm": Vector3(0.3, -0.25, 0.92), "RightLowerArm": Vector3(0.92, 0.05, 0.38)}
const L_BAL := {"LeftUpperArm": Vector3(0.75, -0.55, -0.1), "LeftLowerArm": Vector3(0.5, -0.5, 0.7)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_BAL), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var CR = S.LEG_CROSS
	var R = Vector3(0.05, 0.62, 0.78)
	return [
		{"len": 0.54, "hit": 0.22, "keys": [_t(0.0, 0.36, -8, 3, R, R_GUARD, W), _t(0.12, 0.42, -24, -5, Vector3(0, 0.1, 1), R_BACK, B), _t(0.22, 0.5, 18, 16, Vector3(0, 0.05, 1), S.H_FWD, L), _t(0.34, 0.48, 14, 14, Vector3(0, 0.05, 1), S.H_FWD, L), _t(0.54, 0.36, -8, 3, R, R_GUARD, W)]},
		{"len": 0.58, "hit": 0.24, "keys": [_t(0.0, 0.36, -8, 3, R, R_GUARD, W), _t(0.13, 0.4, 28, 0, Vector3(0.6, 0.55, 0.58), R_L, CR), _t(0.24, 0.46, -24, 12, Vector3(-0.75, -0.1, 0.65), R_SIDE, L), _t(0.36, 0.44, -30, 10, Vector3(-0.8, -0.12, 0.58), R_SIDE, L), _t(0.58, 0.36, -8, 3, R, R_GUARD, W)]},
		{"len": 0.76, "hit": 0.3, "keys": [_t(0.0, 0.36, -8, 3, R, R_GUARD, W), _t(0.18, 0.46, -30, -8, Vector3(0, 0.1, 1), R_BACK, B), _t(0.3, 0.54, 22, 24, Vector3(0, 0.03, 1), S.H_FWD, L), _t(0.5, 0.52, 18, 20, Vector3(0, 0.03, 1), S.H_FWD, L), _t(0.76, 0.36, -8, 3, R, R_GUARD, W)]},
		{"len": 0.96, "hit": 0.4, "keys": [_t(0.0, 0.36, -8, 3, R, R_GUARD, W), _t(0.26, 0.44, -46, -4, Vector3(-0.85, 0.15, -0.5), R_SIDE, B), _t(0.34, 0.46, -50, -6, Vector3(-0.85, 0.15, -0.5), R_SIDE, B), _t(0.4, 0.5, 0, 12, Vector3(-0.1, 0.05, 1), S.H_FWD, CR), _t(0.56, 0.5, 46, 12, Vector3(0.85, 0.05, 0.5), R_L, L), _t(0.96, 0.36, -8, 3, R, R_GUARD, W)]},
		{"len": 0.68, "hit": 0.26, "keys": [_t(0.0, 0.36, -8, 3, R, R_GUARD, W), _t(0.14, 0.42, -18, -4, Vector3(0, 0.75, -0.66), R_HI, B), _t(0.26, 0.5, 14, 18, Vector3(0, 0.8, -0.6), S.H_FWD, L), _t(0.4, 0.48, 10, 14, Vector3(0, 0.8, -0.6), S.H_FWD, L), _t(0.68, 0.36, -8, 3, R, R_GUARD, W)]},
		{"len": 1.44, "hit": 0.74, "keys": [_t(0.0, 0.36, -8, 3, R, R_GUARD, W), _t(0.3, 0.3, -10, -14, Vector3(0, 0.98, 0.1), R_HI, W), _t(0.64, 0.28, -14, -22, Vector3(-0.2, 0.86, -0.46), R_HI, B), _t(0.74, 0.62, 18, 30, Vector3(0.45, -0.55, 0.7), R_L, L), _t(1.02, 0.6, 24, 26, Vector3(0.6, -0.5, 0.62), R_L, L), _t(1.44, 0.36, -8, 3, R, R_GUARD, W)]},
	]
