extends RefCounted
## Enmaku Kote (Kihō'nun sekiz namlulu bilek atarı) kombosu. Ref refs/enmaku_kote/wrist_launcher.png: yumruk öne uzanır, namlular yumruğun çevresinde.
## 1 Enmaku-dan, 2 Doku-fuki, 3 Nagi-fuki (gövde dönerek süpürür), 4 Hiki-dan (geri sıçrar, ayak dibine), 5 Kokuen-kyū (sıralı yaylım), 6 Enryū (duman ejderi). Efekt EnmakuKoteFX.

const S = preload("res://scripts/combat/samehada_anim.gd")

const FWD := Vector3(0, 0, 1)
const R_REST := {"RightUpperArm": Vector3(-0.3, -0.85, 0.42), "RightLowerArm": Vector3(0.1, -0.2, 0.97)}
const L_REST := {"LeftUpperArm": Vector3(0.3, -0.85, 0.3), "LeftLowerArm": Vector3(-0.15, -0.3, 0.94)}
const R_AIM := {"RightUpperArm": Vector3(-0.06, 0.02, 1), "RightLowerArm": Vector3(0.0, 0.02, 1)}
const R_LOW := {"RightUpperArm": Vector3(-0.1, -0.5, 0.86), "RightLowerArm": Vector3(0.0, -0.55, 0.83)}
const R_HIGH := {"RightUpperArm": Vector3(-0.1, 0.5, 0.86), "RightLowerArm": Vector3(0.0, 0.45, 0.89)}
const L_BRACE := {"LeftUpperArm": Vector3(0.1, -0.5, 0.86), "LeftLowerArm": Vector3(-0.72, 0.25, 0.64)}   # sağ kolu destekler
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.2, lean * 1.1, FWD, S._a(r, l), legs)


static func _shot(hit: float, end: float, yaw: float, r: Dictionary, legs: Dictionary) -> Array:
	return [
		_t(0.0, 0.38, 0, 3, R_REST, L_REST, S.LEG_WIDE),
		_t(hit * 0.7, 0.42, yaw - 8, -3, r, L_BRACE, S.LEG_BACK),
		_t(hit, 0.46, yaw, 8, r, L_BRACE, legs),
		_t(hit + (end - hit) * 0.5, 0.44, yaw, 5, r, L_BRACE, legs),
		_t(end, 0.38, 0, 3, R_REST, L_REST, S.LEG_WIDE),
	]


static func steps() -> Array:
	return [
		{"len": 0.62, "hit": 0.24, "keys": _shot(0.24, 0.62, 12, R_AIM, S.LEG_LUNGE)},
		{"len": 0.9, "hit": 0.26, "keys": _shot(0.26, 0.9, 10, R_AIM, S.LEG_LUNGE)},
		{"len": 0.98, "hit": 0.26, "keys": [
			_t(0.0, 0.38, 0, 3, R_REST, L_REST, S.LEG_WIDE),
			_t(0.26, 0.46, -44, 6, R_AIM, L_BACK, S.LEG_BACK),
			_t(0.68, 0.46, 44, 6, R_AIM, L_BACK, S.LEG_CROSS),
			_t(0.98, 0.38, 0, 3, R_REST, L_REST, S.LEG_WIDE),
		]},
		{"len": 0.72, "hit": 0.26, "keys": _shot(0.26, 0.72, 0, R_LOW, S.LEG_STEP)},
		{"len": 1.12, "hit": 0.28, "keys": _shot(0.28, 1.12, 8, R_HIGH, S.LEG_LUNGE)},
		{"len": 1.46, "hit": 0.42, "keys": [
			_t(0.0, 0.38, 0, 3, R_REST, L_REST, S.LEG_WIDE),
			_t(0.3, 0.5, -20, -4, R_LOW, L_BRACE, S.LEG_BACK),
			_t(0.42, 0.5, 14, 12, R_AIM, L_BRACE, S.LEG_LUNGE),
			_t(1.16, 0.48, 10, 10, R_HIGH, L_BRACE, S.LEG_LUNGE),
			_t(1.46, 0.38, 0, 3, R_REST, L_REST, S.LEG_WIDE),
		]},
	]
