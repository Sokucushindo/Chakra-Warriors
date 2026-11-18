extends RefCounted
## Sansetsukon (üç parçalı sopa; Tenten'in cephaneliği — kanonda kısa anlar; hareketler silahın fiziğinden): sağ elde birinci parça,
## kısa zincirle ortadaki parça ve ona bağlı üçüncü parça serbest savrulur (CharacterModel zincir fiziği). Nunchaku'dan ağır ve geniş:
## omuz kurulumlu büyük yaylar, tam tur dönüşler.
## 1 Ō Nagi: geniş yatay savuruş, 2 Kaeshi: ters yay, 3 Tenchi: baş üstünden yere çakma (sersemletir), 4 Senpū: tam tur dönüş,
## 5 Ashi Gari: alçak süpürme (yere serer), 6 Ryū Ranbu (bitiriş): iki tur savurup baş üstünden ağır iniş

const S = preload("res://scripts/combat/samehada_anim.gd")
const N = preload("res://scripts/combat/nunchaku_anim.gd")


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.4, lean * 1.25, Vector3(0, 0, 1), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	return [
		{"len": 0.8, "hit": 0.34, "keys": [
			_t(0.0, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
			_t(0.18, 0.42, 34, -8, N.R_BACK, N.L_OPEN, BK),
			_t(0.34, 0.48, -36, 16, N.R_LEFT, N.L_BACK, L),
			_t(0.5, 0.46, -44, 14, N.R_LEFT, N.L_BACK, L),
			_t(0.8, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
		]},
		{"len": 0.75, "hit": 0.32, "keys": [
			_t(0.0, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
			_t(0.16, 0.42, -30, -4, N.R_LEFT, N.L_GUARD, CR),
			_t(0.32, 0.48, 34, 14, N.R_RIGHT, N.L_OPEN, ST),
			_t(0.48, 0.46, 42, 12, N.R_RIGHT, N.L_OPEN, W),
			_t(0.75, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
		]},
		{"len": 0.95, "hit": 0.46, "keys": [
			_t(0.0, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
			_t(0.2, 0.3, 0, -14, N.R_HIGH, N.L_OPEN, BK),
			_t(0.36, 0.3, 0, -16, N.R_HIGH, N.L_OPEN, BK),
			_t(0.46, 0.6, 0, 30, N.R_DOWN, N.L_BACK, L),
			_t(0.66, 0.56, 0, 26, N.R_DOWN, N.L_BACK, L),
			_t(0.95, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
		]},
		{"len": 1.0, "hit": 0.36, "extra_hits": [0.62], "extra_radius": 2.2, "keys": [
			_t(0.0, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
			_t(0.16, 0.44, -40, -4, N.R_RIGHT, N.L_OPEN, CR),
			_t(0.38, 0.48, 130, 8, N.R_RIGHT, N.L_OPEN, W),
			_t(0.6, 0.48, 260, 8, N.R_RIGHT, N.L_OPEN, CR),
			_t(0.8, 0.46, 360, 6, N.R_RIGHT, N.L_OPEN, W),
			_t(1.0, 0.36, 360, 4, N.R_READY, N.L_GUARD, W),
		]},
		{"len": 0.9, "hit": 0.36, "keys": [
			_t(0.0, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
			_t(0.16, 0.72, -30, 18, N.R_RIGHT, N.L_OPEN, CR),
			_t(0.36, 0.76, 40, 20, N.R_LEFT, N.L_OPEN, W),
			_t(0.52, 0.74, 60, 18, N.R_LEFT, N.L_OPEN, W),
			_t(0.9, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
		]},
		{"len": 1.45, "hit": 1.0, "extra_hits": [0.3, 0.58], "extra_radius": 2.0, "keys": [
			_t(0.0, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
			_t(0.14, 0.42, 30, -6, N.R_BACK, N.L_OPEN, CR),
			_t(0.3, 0.46, -40, 14, N.R_LEFT, N.L_OPEN, L),
			_t(0.44, 0.46, 30, 12, N.R_RIGHT, N.L_OPEN, LL),
			_t(0.58, 0.46, -40, 14, N.R_LEFT, N.L_OPEN, L),
			_t(0.8, 0.28, 0, -16, N.R_HIGH, N.L_OPEN, ST),
			_t(1.0, 0.62, 0, 32, N.R_DOWN, N.L_BACK, L),
			_t(1.18, 0.58, 0, 28, N.R_DOWN, N.L_BACK, L),
			_t(1.45, 0.36, 0, 4, N.R_READY, N.L_GUARD, W),
		]},
	]
