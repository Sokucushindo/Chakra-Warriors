extends RefCounted
## Senbon Hasshaki (Shizune'nin bilek atarı) kombosu. Ref: refs/bilek_senbon/Senbon_Launcher.png: sağ ön kol göğüs önünde YATAY, namlular
## hedefe bakar; sol yumruk kolun üstünde, beş teli yukarı çekince iğneler çıkar. Vuruş anı = tel çekişi. Mermiler BilekSenbonFX'ten.
## 1 Hitotsu (tek namlu), 2 Futatsume (tek namlu), 3 Mitsu-uchi (kalan üç, yelpaze), 4 Tsumekae (geri sıçrar, sol el kol boyunca dolaşıp doldurur),
## 5 Renpatsu (beş namlu sırayla), 6 Gorenshi (hızlı dolum, beşi tek noktaya).

const S = preload("res://scripts/combat/samehada_anim.gd")

const FWD := Vector3(0, 0, 1)
const R_REST := {"RightUpperArm": Vector3(-0.25, -0.9, 0.3), "RightLowerArm": Vector3(0.1, -0.4, 0.9)}
const L_REST := {"LeftUpperArm": Vector3(0.25, -0.9, 0.3), "LeftLowerArm": Vector3(-0.1, -0.4, 0.9)}
const R_BAR := {"RightUpperArm": Vector3(-0.5, -0.55, 0.65), "RightLowerArm": Vector3(0.97, 0.08, 0.2)}
const L_SET := {"LeftUpperArm": Vector3(0.35, -0.4, 0.85), "LeftLowerArm": Vector3(-0.55, 0.45, 0.7)}    # telleri kavrar
const L_PULL := {"LeftUpperArm": Vector3(0.6, -0.1, 0.45), "LeftLowerArm": Vector3(-0.2, 0.9, 0.35)}      # yumruk yukarı-geri
const L_ELBOW := {"LeftUpperArm": Vector3(0.1, -0.6, 0.8), "LeftLowerArm": Vector3(-0.85, 0.05, 0.5)}     # dolum: dirsek tarafı
const L_WRIST := {"LeftUpperArm": Vector3(0.05, -0.5, 0.86), "LeftLowerArm": Vector3(-0.55, 0.0, 0.83)}   # dolum: bilek tarafı


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.2, FWD, S._a(r, l), legs)


static func _shot(set_t: float, hit: float, end: float, yaw: float, legs: Dictionary) -> Array:
	return [
		_t(0.0, 0.36, 0, 2, R_REST, L_REST, S.LEG_WIDE),
		_t(set_t, 0.4, yaw, 2, R_BAR, L_SET, legs),
		_t(hit - 0.03, 0.4, yaw, 2, R_BAR, L_SET, legs),
		_t(hit + 0.03, 0.42, yaw + 4, -5, R_BAR, L_PULL, legs),
		_t(hit + 0.2, 0.41, yaw, 0, R_BAR, L_PULL, legs),
		_t(end, 0.36, 0, 2, R_REST, L_REST, S.LEG_WIDE),
	]


static func steps() -> Array:
	var W = S.LEG_WIDE
	var BK = S.LEG_BACK
	var L = S.LEG_LUNGE
	return [
		{"len": 0.56, "hit": 0.22, "keys": _shot(0.12, 0.22, 0.56, 14, W)},
		{"len": 0.54, "hit": 0.2, "keys": _shot(0.1, 0.2, 0.54, 16, W)},
		{"len": 0.8, "hit": 0.34, "keys": _shot(0.2, 0.34, 0.8, 20, BK)},
		# Tsumekae: sol el dirsekten bileğe kayar, namlular tek tek dolar
		{"len": 0.85, "hit": 0.5, "keys": [
			_t(0.0, 0.4, 10, 4, R_BAR, L_SET, W),
			_t(0.15, 0.3, 14, -4, R_BAR, L_ELBOW, S.LEG_STEP),
			_t(0.55, 0.36, 14, 0, R_BAR, L_WRIST, BK),
			_t(0.85, 0.36, 0, 2, R_REST, L_REST, W),
		]},
		# Renpatsu: tel tel çekilir, yumruk üç kez iner kalkar
		{"len": 1.0, "hit": 0.26, "keys": [
			_t(0.0, 0.36, 0, 2, R_REST, L_REST, W),
			_t(0.16, 0.4, 18, 2, R_BAR, L_SET, BK),
			_t(0.3, 0.42, 20, -3, R_BAR, L_PULL, BK),
			_t(0.42, 0.42, 20, -1, R_BAR, L_SET, BK),
			_t(0.54, 0.42, 21, -4, R_BAR, L_PULL, BK),
			_t(0.8, 0.4, 16, 0, R_BAR, L_PULL, W),
			_t(1.0, 0.36, 0, 2, R_REST, L_REST, W),
		]},
		# Gorenshi: hızlı dolum, kısa bekleyiş, beş tel birden
		{"len": 1.4, "hit": 0.86, "keys": [
			_t(0.0, 0.36, 0, 2, R_REST, L_REST, W),
			_t(0.14, 0.42, 12, 6, R_BAR, L_ELBOW, BK),
			_t(0.55, 0.46, 18, 4, R_BAR, L_WRIST, BK),
			_t(0.72, 0.5, 22, 2, R_BAR, L_SET, L),
			_t(0.84, 0.5, 22, 2, R_BAR, L_SET, L),
			_t(0.9, 0.52, 28, -8, R_BAR, L_PULL, L),
			_t(1.15, 0.48, 24, -3, R_BAR, L_PULL, L),
			_t(1.4, 0.36, 0, 2, R_REST, L_REST, W),
		]},
	]
