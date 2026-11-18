extends RefCounted
## Hasami Kote (Kamikiri'nin dev makası; refs/hasami_kote): sağ kola bağlı, elle tutulan iplerle açılıp kapanır. Ağır, kol boyunca ileri uzanır.
## 1 Hiraki Nagi: açık ağızla yatay, 2 Kiri Komi: inip kapanır, 3 Tsuki: kapalı dürtüş, 4 Hasami Tori: atılıp kıskaca alır,
## 5 Nejiri: kıskaçtakini sıkıp yana savurur, 6 Iwa Wari (bitiriş): kol baş üstünde, yere iner, kayayı yarar. Mekanik HasamiKoteFX.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_REST := {"RightUpperArm": Vector3(-0.3, -0.75, 0.58), "RightLowerArm": Vector3(0.1, 0.05, 0.99)}
const L_REST := {"LeftUpperArm": Vector3(0.35, -0.8, 0.45), "LeftLowerArm": Vector3(-0.2, 0.15, 0.96)}
const R_BACK := {"RightUpperArm": Vector3(-0.92, -0.2, -0.3), "RightLowerArm": Vector3(-0.72, 0.05, -0.68)}
const R_FRONT := {"RightUpperArm": Vector3(-0.05, -0.05, 1), "RightLowerArm": Vector3(0.1, 0.0, 1)}
const R_ACROSS := {"RightUpperArm": Vector3(0.2, -0.1, 0.97), "RightLowerArm": Vector3(0.85, 0.02, 0.52)}
const R_HIGH := {"RightUpperArm": Vector3(-0.2, 0.92, 0.3), "RightLowerArm": Vector3(0.0, 0.97, 0.22)}
const R_DOWN := {"RightUpperArm": Vector3(-0.08, -0.35, 0.93), "RightLowerArm": Vector3(0.0, -0.62, 0.78)}
const R_CHAMBER := {"RightUpperArm": Vector3(-0.42, -0.6, -0.68), "RightLowerArm": Vector3(-0.05, 0.1, 0.99)}
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const L_FWD := {"LeftUpperArm": Vector3(0.2, -0.1, 1), "LeftLowerArm": Vector3(0.05, 0.0, 1)}
const B := Vector3(0, 0, 1)


static func _t(t: float, c: float, y: float, l: float, r: Dictionary, a: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, c, y, l, B, S._a(r, a), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	return [
		{"len": 0.92, "hit": 0.36, "keys": [
			_t(0.0, 0.42, -8, 5, R_REST, L_REST, W),
			_t(0.24, 0.5, -44, -4, R_BACK, L_FWD, BK),
			_t(0.32, 0.5, -48, -6, R_BACK, L_FWD, BK),
			_t(0.36, 0.54, 30, 14, R_ACROSS, L_BACK, L),
			_t(0.58, 0.52, 40, 10, R_ACROSS, L_BACK, L),
			_t(0.92, 0.42, -8, 5, R_REST, L_REST, W),
		]},
		{"len": 0.86, "hit": 0.34, "keys": [
			_t(0.0, 0.42, -8, 5, R_REST, L_REST, W),
			_t(0.22, 0.34, -6, -14, R_HIGH, L_FWD, ST),
			_t(0.3, 0.32, -6, -16, R_HIGH, L_FWD, ST),
			_t(0.34, 0.6, 8, 28, R_DOWN, L_BACK, L),
			_t(0.56, 0.58, 6, 24, R_DOWN, L_BACK, L),
			_t(0.86, 0.42, -8, 5, R_REST, L_REST, W),
		]},
		{"len": 0.7, "hit": 0.24, "keys": [
			_t(0.0, 0.42, -8, 5, R_REST, L_REST, W),
			_t(0.16, 0.46, -28, -8, R_CHAMBER, L_FWD, BK),
			_t(0.24, 0.5, 20, 20, R_FRONT, L_BACK, L),
			_t(0.42, 0.48, 16, 16, R_FRONT, L_BACK, L),
			_t(0.7, 0.42, -8, 5, R_REST, L_REST, W),
		]},
		{"len": 0.98, "hit": 0.4, "keys": [
			_t(0.0, 0.42, -8, 5, R_REST, L_REST, W),
			_t(0.26, 0.56, -16, -6, R_CHAMBER, L_FWD, BK),
			_t(0.4, 0.56, 12, 24, R_FRONT, L_BACK, L),
			_t(0.72, 0.54, 10, 20, R_FRONT, L_BACK, L),
			_t(0.98, 0.42, -8, 5, R_REST, L_REST, W),
		]},
		{"len": 1.12, "hit": 0.2, "keys": [
			_t(0.0, 0.54, 10, 20, R_FRONT, L_BACK, L),
			_t(0.2, 0.56, 4, 16, R_FRONT, L_FWD, W),
			_t(0.66, 0.56, -10, 12, R_FRONT, L_FWD, W),
			_t(0.84, 0.54, 54, 12, R_ACROSS, L_BACK, CR),
			_t(1.12, 0.42, -8, 5, R_REST, L_REST, W),
		]},
		{"len": 1.5, "hit": 0.72, "keys": [
			_t(0.0, 0.42, -8, 5, R_REST, L_REST, W),
			_t(0.34, 0.32, -4, -18, R_HIGH, L_FWD, ST),
			_t(0.64, 0.3, -4, -24, R_HIGH, L_FWD, BK),
			_t(0.72, 0.76, 6, 40, R_DOWN, L_BACK, L),
			_t(1.08, 0.74, 4, 38, R_DOWN, L_BACK, L),
			_t(1.5, 0.42, -8, 5, R_REST, L_REST, W),
		]},
	]
