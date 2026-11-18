extends RefCounted
## Ōyumi (arbalet) kombosu: omuzdan iki elle nişan, tek cıvata. Bir atış boşaltır; yeniden kurmak kombonun kendi adımıdır (ArbaletFX).
## KANONDA YAKIN ÇEKİM GÖRSELİ BULUNAMADI: duruş ve kurma hareketi gerçek arbaletten (üzengiye ayak basıp kirişi çekmek), kanon değil.
## 1 Ichi-ya (atış), 2 Ashi-gake (üzengiye bas + kur; basış tekme gibi vurur), 3 Bakufu-ya (patlayıcı etiketli cıvata), 4 Dai-uchi (dipçik
## darbesi, bu sırada kurulur), 5 Nawa-ya (halatlı cıvata), 6 Kunai-zume (hızlı kurma, üç kunai birden).

const S = preload("res://scripts/combat/samehada_anim.gd")

const FWD := Vector3(0, 0, 1)
const KICK := Vector3(0.0, 0.2, 0.98)
const NOSE_DOWN := Vector3(0.0, -0.9, 0.42)
const BUTT := Vector3(0.0, 0.25, -0.97)
const BACK_UP := Vector3(0.1, 0.5, 0.86)

const R_AIM := {"RightUpperArm": Vector3(-0.32, -0.5, 0.8), "RightLowerArm": Vector3(0.3, 0.2, 0.93)}
const L_AIM := {"LeftUpperArm": Vector3(0.2, -0.55, 0.8), "LeftLowerArm": Vector3(-0.25, 0.15, 0.95)}
const R_DOWN := {"RightUpperArm": Vector3(-0.2, -0.75, 0.62), "RightLowerArm": Vector3(0.1, -0.85, 0.5)}
const L_PULL := {"LeftUpperArm": Vector3(0.25, -0.7, 0.65), "LeftLowerArm": Vector3(-0.3, 0.35, 0.88)}
const R_WIND := {"RightUpperArm": Vector3(-0.55, -0.45, -0.7), "RightLowerArm": Vector3(0.2, 0.4, 0.9)}
const R_THRUST := {"RightUpperArm": Vector3(-0.2, -0.2, 0.96), "RightLowerArm": Vector3(0.2, 0.1, 0.97)}
const L_FREE := {"LeftUpperArm": Vector3(0.45, -0.75, -0.45), "LeftLowerArm": Vector3(0.3, -0.5, 0.8)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.2, blade.normalized(), S._a(r, l), legs)


## Nişan -> tetik -> geri tepme -> toparlanma
static func _fire(aim: float, end: float, yaw: float, legs: Dictionary) -> Array:
	return [
		_t(0.0, 0.38, yaw * 0.5, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
		_t(aim, 0.42, yaw, 4, FWD, R_AIM, L_AIM, legs),
		_t(aim + 0.05, 0.42, yaw - 4, -7, KICK, R_AIM, L_AIM, legs),
		_t(aim + 0.2, 0.41, yaw, 0, FWD, R_AIM, L_AIM, legs),
		_t(end, 0.38, yaw * 0.5, 2, FWD, R_AIM, L_AIM, S.LEG_WIDE),
	]


static func steps() -> Array:
	var W = S.LEG_WIDE
	var BK = S.LEG_BACK
	var L = S.LEG_LUNGE
	var ST = S.LEG_STEP
	return [
		{"len": 0.72, "hit": 0.28, "two": true, "keys": _fire(0.28, 0.72, -18, BK)},
		# Ashi-gake: burun aşağı, sağ ayak üzengiye iner (vuruş), iki el kirişi karna çeker
		{"len": 0.95, "hit": 0.34, "keys": [
			_t(0.0, 0.38, -10, 2, FWD, R_AIM, L_AIM, W),
			_t(0.2, 0.56, 0, 24, NOSE_DOWN, R_DOWN, L_PULL, ST),
			_t(0.3, 0.58, 0, 26, NOSE_DOWN, R_DOWN, L_PULL, ST),
			_t(0.34, 0.66, 0, 32, NOSE_DOWN, R_DOWN, L_PULL, L),
			_t(0.7, 0.5, 0, 12, NOSE_DOWN, R_DOWN, L_PULL, W),
			_t(0.95, 0.38, -10, 2, FWD, R_AIM, L_AIM, W),
		]},
		{"len": 0.8, "hit": 0.34, "two": true, "keys": _fire(0.34, 0.8, -18, BK)},
		# Dai-uchi: silah geri-yukarı kurulur, dipçik öne saplanır (ağır: geri çek, dur, hızlı vur, yavaş topla)
		{"len": 0.95, "hit": 0.36, "keys": [
			_t(0.0, 0.38, -10, 2, FWD, R_AIM, L_AIM, W),
			_t(0.18, 0.42, 26, -10, BACK_UP, R_WIND, L_FREE, BK),
			_t(0.29, 0.43, 28, -11, BACK_UP, R_WIND, L_FREE, BK),
			_t(0.36, 0.5, -30, 20, BUTT, R_THRUST, L_FREE, L),
			_t(0.62, 0.46, -24, 12, BUTT, R_THRUST, L_FREE, L),
			_t(0.95, 0.38, -10, 2, FWD, R_AIM, L_AIM, W),
		]},
		{"len": 0.9, "hit": 0.36, "two": true, "keys": _fire(0.36, 0.9, -22, W)},
		# Kunai-zume: ayak basmadan kaldıraçla hızlı kurma, uzun nişan, üç kunai
		{"len": 1.35, "hit": 0.82, "keys": [
			_t(0.0, 0.38, -10, 2, FWD, R_AIM, L_AIM, W),
			_t(0.22, 0.5, -6, 14, NOSE_DOWN, R_DOWN, L_PULL, BK),
			_t(0.5, 0.48, -14, 8, NOSE_DOWN, R_DOWN, L_PULL, BK),
			_t(0.7, 0.46, -22, 4, FWD, R_AIM, L_AIM, L),
			_t(0.82, 0.46, -22, 4, FWD, R_AIM, L_AIM, L),
			_t(0.88, 0.46, -26, -9, KICK, R_AIM, L_AIM, L),
			_t(1.35, 0.38, -10, 2, FWD, R_AIM, L_AIM, W),
		]},
	]
