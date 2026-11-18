extends RefCounted
## Yari (mızrak; Tenten'in parşömen cephaneliği — kanonda kısa anlar): İKİ ELLE, uç ileride. Mızrak = saplama silahı: uzun menzil,
## dürtmeler ve uçla süpürme. Bō ile aynı iki el tutuşu (KeyedCombos.TWO_OFF), farklı kombo.
## 1 Choku Tsuki: düz uzun saplama, 2 Nidan Tsuki: art arda iki saplama, 3 Harai: ağızla yatay süpürme, 4 Ashi Barai: alçak süpürme
## (yere serer), 5 Kaiten: çevirerek çoklu vuruş, 6 Sen'ei Tsuki (bitiriş): geri çekilip bütün bedenle ileri atılış — uzun saplama

const S = preload("res://scripts/combat/samehada_anim.gd")
const B = preload("res://scripts/combat/bo_anim.gd")


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.3, blade.normalized(), S._a(r, B.L_ANY), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.1, 0.05, 0.99)   # uç ileride, alçakça
	return [
		{"len": 0.62, "hit": 0.28, "two": true, "keys": [
			_t(0.0, 0.4, -10, 6, RDY, B.R_READY, W),
			_t(0.14, 0.44, -18, -8, Vector3(0, 0, 1), B.R_DRAW, BK),
			_t(0.28, 0.54, 12, 24, Vector3(0, 0, 1), B.R_THRUST, L),
			_t(0.4, 0.52, 10, 20, Vector3(0, 0, 1), B.R_THRUST, L),
			_t(0.62, 0.4, -10, 6, RDY, B.R_READY, W),
		]},
		{"len": 0.75, "hit": 0.2, "two": true, "extra_hits": [0.44], "extra_radius": 1.6, "keys": [
			_t(0.0, 0.4, -10, 6, RDY, B.R_READY, W),
			_t(0.1, 0.44, -16, -4, Vector3(0, 0, 1), B.R_DRAW, BK),
			_t(0.2, 0.5, 10, 18, Vector3(0, 0.05, 1), B.R_THRUST, ST),
			_t(0.32, 0.46, -12, -2, Vector3(0, 0, 1), B.R_DRAW, BK),
			_t(0.44, 0.54, 14, 22, Vector3(0, -0.05, 1), B.R_THRUST, L),
			_t(0.75, 0.4, -10, 6, RDY, B.R_READY, W),
		]},
		{"len": 0.7, "hit": 0.3, "two": true, "keys": [
			_t(0.0, 0.4, -10, 6, RDY, B.R_READY, W),
			_t(0.14, 0.44, -34, -4, Vector3(-0.9, 0.1, 0.3), B.R_WIDE, BK),
			_t(0.3, 0.5, 30, 14, Vector3(0.9, 0.05, 0.4), B.R_SIDE, LL),
			_t(0.44, 0.48, 36, 12, Vector3(0.9, 0.0, 0.35), B.R_SIDE, LL),
			_t(0.7, 0.4, -10, 6, RDY, B.R_READY, W),
		]},
		{"len": 0.72, "hit": 0.32, "two": true, "keys": [
			_t(0.0, 0.4, -10, 6, RDY, B.R_READY, W),
			_t(0.14, 0.72, -28, 18, Vector3(-0.8, -0.5, 0.3), B.R_LOW, BK),
			_t(0.32, 0.74, 34, 20, Vector3(0.8, -0.5, 0.3), B.R_LOW, CR),
			_t(0.46, 0.72, 40, 18, Vector3(0.8, -0.5, 0.3), B.R_LOW, CR),
			_t(0.72, 0.4, -10, 6, RDY, B.R_READY, W),
		]},
		{"len": 1.0, "hit": 0.24, "two": true, "extra_hits": [0.44, 0.64], "extra_radius": 2.2, "keys": [
			_t(0.0, 0.4, -10, 6, RDY, B.R_READY, W),
			_t(0.16, 0.42, 0, 8, Vector3(0, 1, 0.1), B.R_TWIRL, ST),
			_t(0.36, 0.42, 6, 8, Vector3(0, -0.1, 1), B.R_TWIRL, W),
			_t(0.56, 0.44, -6, 10, Vector3(0, -1, 0.1), B.R_TWIRL, ST),
			_t(0.76, 0.44, 6, 10, Vector3(0, 0.1, -1), B.R_TWIRL, W),
			_t(1.0, 0.4, -10, 6, RDY, B.R_READY, W),
		]},
		{"len": 1.15, "hit": 0.6, "two": true, "keys": [
			_t(0.0, 0.4, -10, 6, RDY, B.R_READY, W),
			_t(0.24, 0.5, -24, -16, Vector3(0, 0, 1), B.R_DRAW, BK),
			_t(0.5, 0.52, -26, -18, Vector3(0, 0, 1), B.R_DRAW, BK),
			_t(0.6, 0.6, 16, 34, Vector3(0, 0, 1), B.R_THRUST, L),
			_t(0.86, 0.58, 14, 30, Vector3(0, 0, 1), B.R_THRUST, L),
			_t(1.15, 0.4, -10, 6, RDY, B.R_READY, W),
		]},
	]
