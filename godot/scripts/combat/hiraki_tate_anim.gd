extends RefCounted
## Hiraki-date (açılır kalkan; kanon film: Temujin, adı wiki'de yok — refs/hiraki_tate): kapalıyken kolluk, açılınca dilimli yuvarlak kalkan. Standart silahları geri çevirir, jutsuyu durdurmaz. Sağ kolda, yumruk ve kolluk dövüşü.
## 1 Kote Tsuki, 2 Hiraki Uchi: yumruk çıkarken açılır, 3 Fuchi Giri: açık kenarla yan, 4 Hane Kaeshi: bekler, gelen silahı çevirir, 5 Tojime: kapanırken kol içinden darbe, 6 Kaiten Tate: dönerek kenarla çarpar.

const S = preload("res://scripts/combat/samehada_anim.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const R_GUARD := {"RightUpperArm": Vector3(-0.35, -0.75, 0.55), "RightLowerArm": Vector3(0.15, 0.75, 0.65)}
const R_CHAMB := {"RightUpperArm": Vector3(-0.45, -0.6, -0.66), "RightLowerArm": Vector3(-0.1, 0.3, 0.95)}
const R_PUNCH := {"RightUpperArm": Vector3(-0.05, 0.05, 1), "RightLowerArm": Vector3(0.0, 0.05, 1)}
const R_WALL := {"RightUpperArm": Vector3(-0.55, -0.45, 0.45), "RightLowerArm": Vector3(0.85, 0.3, 0.42)}    # ön kol göğüs önünde, yüz önde
const R_OUT := {"RightUpperArm": Vector3(-0.92, -0.08, 0.38), "RightLowerArm": Vector3(-0.85, 0.02, 0.52)}
const R_IN := {"RightUpperArm": Vector3(0.22, -0.3, 0.93), "RightLowerArm": Vector3(0.92, 0.2, -0.3)}
const L_G := {"LeftUpperArm": Vector3(0.35, -0.75, 0.55), "LeftLowerArm": Vector3(-0.15, 0.75, 0.65)}
const L_B := {"LeftUpperArm": Vector3(0.5, -0.6, -0.6), "LeftLowerArm": Vector3(0.1, 0.3, 0.95)}
const FWD := Vector3(0, 0, 1)


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, FWD, S._a(r, l), legs)


static func steps() -> Array:
	var W = F.FIGHT
	var B = F.SHIFT
	var P = F.PIVOT
	var LO = F.LOW
	return [
		{"len": 0.46, "hit": 0.19, "keys": [_t(0.0, 0.45, 8, 8, R_GUARD, L_G, W), _t(0.1, 0.5, 24, 2, R_CHAMB, L_G, B), _t(0.19, 0.48, -20, 20, R_PUNCH, L_B, P), _t(0.28, 0.46, -16, 16, R_PUNCH, L_B, P), _t(0.46, 0.45, 8, 8, R_GUARD, L_G, W)]},
		{"len": 0.6, "hit": 0.24, "keys": [_t(0.0, 0.45, 8, 8, R_GUARD, L_G, W), _t(0.13, 0.52, 28, 0, R_CHAMB, L_G, B), _t(0.24, 0.5, -16, 22, R_WALL, L_B, P), _t(0.38, 0.48, -12, 18, R_WALL, L_B, P), _t(0.6, 0.45, 8, 8, R_GUARD, L_G, W)]},
		{"len": 0.68, "hit": 0.28, "keys": [_t(0.0, 0.45, 8, 8, R_GUARD, L_G, W), _t(0.15, 0.5, 40, 4, R_IN, L_G, B), _t(0.28, 0.5, -36, 14, R_OUT, L_B, P), _t(0.42, 0.48, -44, 10, R_OUT, L_B, P), _t(0.68, 0.45, 8, 8, R_GUARD, L_G, W)]},
		{"len": 0.94, "hit": 0.66, "keys": [_t(0.0, 0.45, 8, 8, R_GUARD, L_G, W), _t(0.1, 0.58, 16, 10, R_WALL, L_B, LO), _t(0.58, 0.58, 16, 10, R_WALL, L_B, LO), _t(0.66, 0.5, -14, 22, R_PUNCH, L_B, P), _t(0.94, 0.45, 8, 8, R_GUARD, L_G, W)]},
		{"len": 0.62, "hit": 0.26, "keys": [_t(0.0, 0.45, 8, 8, R_GUARD, L_G, W), _t(0.14, 0.52, -22, 2, R_OUT, L_G, B), _t(0.26, 0.5, 22, 18, R_IN, L_B, P), _t(0.4, 0.48, 26, 14, R_IN, L_B, P), _t(0.62, 0.45, 8, 8, R_GUARD, L_G, W)]},
		{"len": 1.06, "hit": 0.46, "keys": [_t(0.0, 0.45, 8, 8, R_GUARD, L_G, W), _t(0.2, 0.56, 40, 2, R_IN, L_G, LO), _t(0.36, 0.52, -70, 8, R_OUT, L_B, P), _t(0.5, 0.52, -200, 10, R_OUT, L_B, W), _t(0.68, 0.52, -340, 12, R_OUT, L_B, P), _t(1.06, 0.45, -352, 8, R_GUARD, L_G, W)]},
	]
