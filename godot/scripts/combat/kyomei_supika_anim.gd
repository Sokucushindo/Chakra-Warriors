extends RefCounted
## Kyōmei Supīkā (Dosu Kinuta) kombosu: sağ ön koldaki delikli kolçak. Kolun her savruluşu ses üretir; yumruk ıskalasa da ses ulaşır.
## 1 Yokogiri (yatay savuruş), 2 Kaeshi (ters savuruş), 3 Uchinarashi (sol avuç kolçağa vurur), 4 Kyōmei-zuki (düz delici yumruk),
## 5 Hibiki-uke (kolçakla kunai / shuriken karşılar, titreşim biriktirir), 6 Kyōmei-hanachi (biriken sesi chakrayla hedefe yollar).

const S = preload("res://scripts/combat/samehada_anim.gd")

const FWD := Vector3(0, 0, 1)
const R_GUARD := {"RightUpperArm": Vector3(-0.35, -0.7, 0.6), "RightLowerArm": Vector3(0.3, 0.6, 0.74)}
const L_GUARD := {"LeftUpperArm": Vector3(0.3, -0.85, 0.42), "LeftLowerArm": Vector3(-0.2, -0.05, 0.98)}
const R_WIDE := {"RightUpperArm": Vector3(-0.92, -0.05, -0.38), "RightLowerArm": Vector3(-0.85, 0.15, -0.5)}   # sağa-geriye açık
const R_ACROSS := {"RightUpperArm": Vector3(0.1, -0.1, 0.99), "RightLowerArm": Vector3(0.9, 0.05, 0.42)}       # sola geçmiş
const R_BACKHAND := {"RightUpperArm": Vector3(-0.75, 0.0, 0.65), "RightLowerArm": Vector3(-0.92, 0.1, 0.38)}   # ters savuruş sonu
const R_BAR := {"RightUpperArm": Vector3(-0.45, -0.55, 0.7), "RightLowerArm": Vector3(0.95, 0.12, 0.25)}       # göğüs önünde yatay
const L_SLAP0 := {"LeftUpperArm": Vector3(0.75, -0.2, 0.6), "LeftLowerArm": Vector3(0.45, 0.55, 0.7)}
const L_SLAP1 := {"LeftUpperArm": Vector3(0.2, -0.4, 0.9), "LeftLowerArm": Vector3(-0.55, 0.05, 0.83)}
const R_CHAMBER := {"RightUpperArm": Vector3(-0.45, -0.6, -0.66), "RightLowerArm": Vector3(-0.08, 0.25, 0.96)}
const R_THRUST := {"RightUpperArm": Vector3(-0.05, 0.05, 1), "RightLowerArm": Vector3(0.0, 0.04, 1)}
const R_SHIELD := {"RightUpperArm": Vector3(-0.4, -0.25, 0.88), "RightLowerArm": Vector3(0.82, 0.48, 0.3)}     # kolçak yüzü öne, yüz hizasında
const L_BACK := {"LeftUpperArm": Vector3(0.5, -0.65, -0.55), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const L_AIM := {"LeftUpperArm": Vector3(0.4, -0.4, 0.82), "LeftLowerArm": Vector3(-0.72, 0.25, 0.64)}          # sol el sağ dirseği destekler


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.2, FWD, S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var C = S.LEG_CROSS
	return [
		{"len": 0.62, "hit": 0.26, "keys": [
			_t(0.0, 0.4, 0, 6, R_GUARD, L_GUARD, W),
			_t(0.16, 0.44, -28, 4, R_WIDE, L_GUARD, BK),
			_t(0.26, 0.48, 26, 12, R_ACROSS, L_BACK, L),
			_t(0.62, 0.4, 0, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 0.6, "hit": 0.24, "keys": [
			_t(0.0, 0.4, 20, 8, R_ACROSS, L_BACK, W),
			_t(0.14, 0.42, 30, 6, R_ACROSS, L_GUARD, C),
			_t(0.24, 0.46, -26, 10, R_BACKHAND, L_GUARD, ST),
			_t(0.6, 0.4, 0, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 0.78, "hit": 0.34, "keys": [
			_t(0.0, 0.4, 0, 6, R_GUARD, L_GUARD, W),
			_t(0.18, 0.44, 8, 2, R_BAR, L_SLAP0, BK),
			_t(0.29, 0.45, 8, 1, R_BAR, L_SLAP0, BK),
			_t(0.34, 0.5, 4, 12, R_BAR, L_SLAP1, W),
			_t(0.78, 0.4, 0, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 0.72, "hit": 0.3, "keys": [
			_t(0.0, 0.4, 0, 6, R_GUARD, L_GUARD, W),
			_t(0.18, 0.44, -30, -4, R_CHAMBER, L_AIM, BK),
			_t(0.3, 0.5, 26, 16, R_THRUST, L_BACK, L),
			_t(0.45, 0.5, 24, 14, R_THRUST, L_BACK, L),
			_t(0.72, 0.4, 0, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 0.9, "hit": 0.72, "keys": [
			_t(0.0, 0.4, 0, 6, R_GUARD, L_GUARD, W),
			_t(0.12, 0.5, 14, 8, R_SHIELD, L_GUARD, BK),
			_t(0.68, 0.5, 14, 8, R_SHIELD, L_GUARD, BK),
			_t(0.74, 0.46, -8, 14, R_THRUST, L_GUARD, W),
			_t(0.9, 0.4, 0, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 1.3, "hit": 0.72, "keys": [
			_t(0.0, 0.4, 0, 6, R_GUARD, L_GUARD, W),
			_t(0.25, 0.5, -34, -6, R_CHAMBER, L_AIM, BK),
			_t(0.62, 0.54, -36, -8, R_CHAMBER, L_AIM, BK),
			_t(0.72, 0.56, 30, 20, R_THRUST, L_AIM, L),
			_t(1.0, 0.54, 26, 16, R_THRUST, L_AIM, L),
			_t(1.3, 0.4, 0, 6, R_GUARD, L_GUARD, W),
		]},
	]
