extends RefCounted
## Chūsha-jū (iğne tüfeği; Narutopedia "Injection Shot Sniper", Konoha tıp ninjaları — refs/igne_tufegi): metal boru, üstte dürbün, altta lazer. Sağ el ortadan tutar, SOL AVUÇ arka uca vurur: şırınga çıkar.
## 1 Hitode: tek atış, 2 Nidan: tek atış, 3 Sagari: geri sıçrayıp yakından atış, 4 Nerai: uzun nişan, tam doz, 5 Renda: iki hızlı avuç, 6 Fukai Nemuri (bitiriş): uyuyana ağır, uyanığa tam doz.

const S = preload("res://scripts/combat/samehada_anim.gd")

const AIM := Vector3(0.0, 0.02, 1.0)
const R_REST := {"RightUpperArm": Vector3(-0.28, -0.86, 0.42), "RightLowerArm": Vector3(0.25, -0.1, 0.96)}
const R_HOLD := {"RightUpperArm": Vector3(-0.42, -0.42, 0.8), "RightLowerArm": Vector3(0.42, 0.12, 0.9)}
const L_REST := {"LeftUpperArm": Vector3(0.3, -0.86, 0.4), "LeftLowerArm": Vector3(-0.2, -0.1, 0.97)}
const L_COCK := {"LeftUpperArm": Vector3(0.55, -0.55, -0.62), "LeftLowerArm": Vector3(-0.42, 0.18, 0.89)}   # avuç geride
const L_PALM := {"LeftUpperArm": Vector3(0.22, -0.42, 0.88), "LeftLowerArm": Vector3(-0.3, 0.16, 0.94)}     # avuç arka uca


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, AIM, S._a(r, l), legs)


static func _shot(hit: float, end: float, legs: Dictionary, crouch := 0.42) -> Array:
	return [
		_t(0.0, 0.36, 4, 3, R_REST, L_REST, S.LEG_WIDE),
		_t(hit * 0.6, crouch, 14, 4, R_HOLD, L_COCK, legs),
		_t(hit - 0.02, crouch, 14, 4, R_HOLD, L_COCK, legs),
		_t(hit + 0.04, crouch, 16, 0, R_HOLD, L_PALM, legs),
		_t(hit + 0.18, crouch, 14, 2, R_HOLD, L_PALM, legs),
		_t(end, 0.36, 4, 3, R_REST, L_REST, S.LEG_WIDE),
	]


static func steps() -> Array:
	var W = S.LEG_WIDE
	var B = S.LEG_BACK
	return [
		{"len": 0.74, "hit": 0.32, "keys": _shot(0.32, 0.74, W)},
		{"len": 0.7, "hit": 0.28, "keys": _shot(0.28, 0.7, W)},
		{"len": 0.82, "hit": 0.36, "keys": _shot(0.36, 0.82, B, 0.3)},
		{"len": 1.3, "hit": 0.86, "keys": _shot(0.86, 1.3, B, 0.56)},
		{"len": 0.96, "hit": 0.26, "keys": [
			_t(0.0, 0.36, 4, 3, R_REST, L_REST, W),
			_t(0.16, 0.44, 14, 4, R_HOLD, L_COCK, W),
			_t(0.3, 0.44, 16, 0, R_HOLD, L_PALM, W),
			_t(0.42, 0.44, 14, 4, R_HOLD, L_COCK, W),
			_t(0.54, 0.44, 16, 0, R_HOLD, L_PALM, W),
			_t(0.96, 0.36, 4, 3, R_REST, L_REST, W),
		]},
		{"len": 1.5, "hit": 1.02, "keys": _shot(1.02, 1.5, B, 0.6)},
	]
