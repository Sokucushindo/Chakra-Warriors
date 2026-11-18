extends RefCounted
## Shakujō (keşiş asası; kanon: Hagoromo, Hamura, Asura, Kazuma — refs/shakujo): İKİ ELLE, halkalı altın baş ileride, dipte sivri demir.
## Bō gibi iki uç da vurur ama baş ağırdır: kısa dürtme, dipçikle karşılık, geniş süpürme, baştan aşağı iniş.
## 1 Kashira Tsuki: başla dürtme, 2 Ishizuki: geri dönüp dipçikle yukarı vuruş, 3 Harai: baş ile geniş süpürme,
## 4 Kabuto Otoshi: asa başın üstünde yatay (Kazuma pozu), tepeden iniş, 5 Senpū: başın üstünde çevirme (çoklu vuruş),
## 6 Shakujō Senpū (bitiriş): başın üstünde çevirip dipçiği yere vurur; rüzgâr doğası varsa kasırga ileri salınır (ShakujoFX).

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
	var RDY = Vector3(0.12, 0.42, 0.9)   # baş ileride, göz hizasına doğru
	return [
		{"len": 0.56, "hit": 0.24, "two": true, "keys": [
			_t(0.0, 0.36, -6, 4, RDY, B.R_READY, W),
			_t(0.12, 0.42, -16, -6, Vector3(0, 0.12, 1), B.R_DRAW, BK),
			_t(0.24, 0.5, 10, 20, Vector3(0, 0.08, 1), B.R_THRUST, L),
			_t(0.36, 0.48, 8, 16, Vector3(0, 0.08, 1), B.R_THRUST, L),
			_t(0.56, 0.36, -6, 4, RDY, B.R_READY, W),
		]},
		{"len": 0.62, "hit": 0.28, "two": true, "keys": [
			_t(0.0, 0.36, -6, 4, RDY, B.R_READY, W),
			_t(0.14, 0.56, 22, 10, Vector3(-0.2, 0.25, 0.95), B.R_LOW, CR),
			_t(0.28, 0.42, -24, 14, Vector3(0.15, 0.72, -0.68), B.R_THRUST, LL),
			_t(0.4, 0.4, -28, 10, Vector3(0.15, 0.78, -0.6), B.R_THRUST, LL),
			_t(0.62, 0.36, -6, 4, RDY, B.R_READY, W),
		]},
		{"len": 0.7, "hit": 0.32, "two": true, "keys": [
			_t(0.0, 0.36, -6, 4, RDY, B.R_READY, W),
			_t(0.16, 0.42, 30, -4, Vector3(0.92, 0.2, 0.3), B.R_SIDE, BK),
			_t(0.32, 0.5, -32, 14, Vector3(-0.92, 0.1, 0.38), B.R_WIDE, L),
			_t(0.46, 0.48, -38, 12, Vector3(-0.92, 0.08, 0.3), B.R_WIDE, L),
			_t(0.7, 0.36, -6, 4, RDY, B.R_READY, W),
		]},
		{"len": 0.82, "hit": 0.42, "two": true, "keys": [
			_t(0.0, 0.36, -6, 4, RDY, B.R_READY, W),
			_t(0.2, 0.24, -6, -18, Vector3(0.95, 0.18, -0.1), B.R_HIGH, ST),
			_t(0.32, 0.22, -4, -22, Vector3(0.9, 0.3, -0.2), B.R_HIGH, ST),
			_t(0.42, 0.6, 8, 28, Vector3(0, -0.62, 0.78), B.R_DOWN, L),
			_t(0.56, 0.58, 6, 24, Vector3(0, -0.66, 0.74), B.R_DOWN, L),
			_t(0.82, 0.36, -6, 4, RDY, B.R_READY, W),
		]},
		{"len": 1.0, "hit": 0.26, "two": true, "extra_hits": [0.44, 0.62, 0.8], "extra_radius": 2.4, "keys": [
			_t(0.0, 0.36, -6, 4, RDY, B.R_READY, W),
			_t(0.14, 0.26, 0, -8, Vector3(1, 0.12, 0), B.R_HIGH, ST),
			_t(0.32, 0.24, 20, -8, Vector3(0, 0.12, 1), B.R_HIGH, W),
			_t(0.5, 0.24, 40, -8, Vector3(-1, 0.12, 0), B.R_HIGH, ST),
			_t(0.68, 0.24, 20, -8, Vector3(0, 0.12, -1), B.R_HIGH, W),
			_t(0.84, 0.26, 0, -6, Vector3(1, 0.12, 0), B.R_HIGH, ST),
			_t(1.0, 0.36, -6, 4, RDY, B.R_READY, W),
		]},
		{"len": 1.35, "hit": 0.86, "two": true, "keys": [
			_t(0.0, 0.36, -6, 4, RDY, B.R_READY, W),
			_t(0.16, 0.24, 0, -10, Vector3(1, 0.12, 0), B.R_HIGH, W),
			_t(0.3, 0.22, 16, -12, Vector3(0, 0.12, 1), B.R_HIGH, W),
			_t(0.44, 0.22, 30, -12, Vector3(-1, 0.12, 0), B.R_HIGH, W),
			_t(0.58, 0.22, 16, -12, Vector3(0, 0.12, -1), B.R_HIGH, W),
			_t(0.72, 0.2, 0, -14, Vector3(1, 0.14, 0), B.R_HIGH, ST),
			_t(0.86, 0.66, 6, 22, Vector3(0, 0.96, 0.26), B.R_LOW, L),
			_t(1.06, 0.62, 4, 18, Vector3(0, 0.96, 0.26), B.R_LOW, L),
			_t(1.35, 0.36, -6, 4, RDY, B.R_READY, W),
		]},
	]
