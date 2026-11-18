extends RefCounted
## Kunai Hasshaki (el kunai atarı) kombosu. Ref refs/kunai_hasshaki/using_kunai_launcher.png: iki elle göğüs önünde, namlu hedefte.
## 1 Sanpatsu, 2 Sanpatsu (öteki yana adım), 3 Nagi-uchi (gövdeyi çevirerek yelpaze), 4 Sōten (geri sıçrar, sol el şarjörü çeker),
## 5 Renpatsu (yana kayarak uzun seri), 6 Zendan (kalan bütün kunailer; geri tepme gövdeyi iter). Mermiler KunaiHasshakiFX'te.

const S = preload("res://scripts/combat/samehada_anim.gd")

const FWD := Vector3(0, 0, 1)
const UP_N := Vector3(0.1, 0.72, 0.68)
const R_AIM := {"RightUpperArm": Vector3(-0.32, -0.5, 0.8), "RightLowerArm": Vector3(0.3, 0.2, 0.93)}
const L_AIM := {"LeftUpperArm": Vector3(0.2, -0.55, 0.8), "LeftLowerArm": Vector3(-0.25, 0.15, 0.95)}
const R_KICK := {"RightUpperArm": Vector3(-0.36, -0.42, 0.72), "RightLowerArm": Vector3(0.28, 0.34, 0.9)}
const L_MAG := {"LeftUpperArm": Vector3(0.25, -0.3, 0.75), "LeftLowerArm": Vector3(-0.45, 0.72, 0.5)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.2, lean * 1.1, blade.normalized(), S._a(r, l), legs)


static func _burst(hit: float, end: float, yaw: float, legs: Dictionary) -> Array:
	return [
		_t(0.0, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
		_t(hit, 0.42, yaw, 4, FWD, R_AIM, L_AIM, legs),
		_t(hit + 0.05, 0.42, yaw, -3, Vector3(0, 0.1, 1), R_KICK, L_AIM, legs),
		_t(end - 0.14, 0.42, yaw, 2, FWD, R_AIM, L_AIM, legs),
		_t(end, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
	]


static func steps() -> Array:
	var LL = S.mirror(S.LEG_LUNGE)
	return [
		{"len": 0.5, "hit": 0.14, "keys": _burst(0.14, 0.5, -8, S.LEG_LUNGE)},
		{"len": 0.5, "hit": 0.14, "keys": _burst(0.14, 0.5, 8, LL)},
		{"len": 0.86, "hit": 0.2, "keys": [
			_t(0.0, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
			_t(0.2, 0.44, -34, 4, FWD, R_AIM, L_AIM, S.LEG_BACK),
			_t(0.6, 0.44, 34, 4, FWD, R_KICK, L_AIM, S.LEG_CROSS),
			_t(0.86, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
		]},
		{"len": 0.8, "hit": 0.4, "keys": [
			_t(0.0, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
			_t(0.2, 0.3, -6, -8, UP_N, R_AIM, L_MAG, S.LEG_STEP),
			_t(0.5, 0.42, -6, -4, UP_N, R_AIM, L_MAG, S.LEG_BACK),
			_t(0.8, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
		]},
		{"len": 1.1, "hit": 0.16, "keys": [
			_t(0.0, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
			_t(0.16, 0.44, -10, 4, FWD, R_KICK, L_AIM, S.LEG_STEP),
			_t(0.55, 0.46, 8, 4, FWD, R_AIM, L_AIM, S.LEG_CROSS),
			_t(0.9, 0.44, -6, 4, FWD, R_KICK, L_AIM, S.LEG_STEP),
			_t(1.1, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
		]},
		{"len": 1.2, "hit": 0.34, "keys": [
			_t(0.0, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
			_t(0.3, 0.56, -4, 12, FWD, R_AIM, L_AIM, S.LEG_LUNGE),
			_t(0.42, 0.54, -4, -6, Vector3(0, 0.16, 1), R_KICK, L_AIM, S.LEG_LUNGE),
			_t(0.86, 0.5, -2, -8, Vector3(0, 0.16, 1), R_KICK, L_AIM, S.LEG_BACK),
			_t(1.2, 0.38, 0, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
		]},
	]
