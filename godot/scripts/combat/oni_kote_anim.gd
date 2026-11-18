extends RefCounted
## Oni no Kote (Oni Kyōdai'nin demir eldiveni; refs/oni_kote): TEK kolda dev kabuk, ucunda zehirli pençe, içinden dikenli zincir çıkar.
## 1 Tsume Harai: pençeyle yandan yırtar, 2 Kachi Age: alttan pençe, 3 Kusari Hanachi: yumruk ileri, zincir fırlar,
## 4 Maki Tsuke: kol başın üstünde döner, zincir hedefe dolanır (bağ), 5 Hiki Saki: gövdeyle geri çeker, zincir yırtar,
## 6 Kiri Hanashi (bitiriş): düzenek zinciri bırakır, boşalan kolla zehirli pençe dalışı. Zincir bir süre yoktur.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_GUARD := {"RightUpperArm": Vector3(-0.35, -0.75, 0.55), "RightLowerArm": Vector3(0.15, 0.75, 0.65)}
const L_GUARD := {"LeftUpperArm": Vector3(0.35, -0.75, 0.55), "LeftLowerArm": Vector3(-0.15, 0.75, 0.65)}
const R_CHAMBER := {"RightUpperArm": Vector3(-0.45, -0.6, -0.7), "RightLowerArm": Vector3(-0.1, 0.3, 0.95)}
const R_PUNCH := {"RightUpperArm": Vector3(-0.05, 0.05, 1), "RightLowerArm": Vector3(0.0, 0.05, 1)}
const R_OUT := {"RightUpperArm": Vector3(-0.95, -0.15, 0.2), "RightLowerArm": Vector3(-0.7, 0.05, 0.7)}
const R_ACROSS := {"RightUpperArm": Vector3(0.1, -0.15, 0.98), "RightLowerArm": Vector3(0.85, 0.05, 0.5)}
const R_LOW := {"RightUpperArm": Vector3(-0.3, -0.9, 0.3), "RightLowerArm": Vector3(-0.1, -0.75, 0.65)}
const R_RISE := {"RightUpperArm": Vector3(-0.1, 0.55, 0.83), "RightLowerArm": Vector3(0.05, 0.85, 0.5)}
const R_OVER := {"RightUpperArm": Vector3(-0.3, 0.95, 0.05), "RightLowerArm": Vector3(0.5, 0.85, 0.1)}
const R_OVER2 := {"RightUpperArm": Vector3(-0.3, 0.95, 0.05), "RightLowerArm": Vector3(-0.6, 0.75, -0.2)}
const R_YANK := {"RightUpperArm": Vector3(-0.55, -0.6, -0.6), "RightLowerArm": Vector3(0.2, 0.2, 0.95)}
const L_FWD := {"LeftUpperArm": Vector3(0.2, -0.1, 1), "LeftLowerArm": Vector3(0.05, 0.0, 1)}
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const BL := Vector3(0, 0, 1)


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, BL, S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	return [
		{"len": 0.62, "hit": 0.24, "keys": [
			_t(0.0, 0.4, -10, 6, R_GUARD, L_GUARD, W),
			_t(0.14, 0.44, -36, -4, R_OUT, L_FWD, BK),
			_t(0.24, 0.5, 34, 16, R_ACROSS, L_BACK, L),
			_t(0.38, 0.48, 30, 14, R_ACROSS, L_BACK, L),
			_t(0.62, 0.4, -10, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 0.66, "hit": 0.26, "keys": [
			_t(0.0, 0.4, -10, 6, R_GUARD, L_GUARD, W),
			_t(0.16, 0.62, -14, 18, R_LOW, L_GUARD, BK),
			_t(0.26, 0.34, 12, -10, R_RISE, L_BACK, LL),
			_t(0.4, 0.3, 10, -12, R_RISE, L_BACK, LL),
			_t(0.66, 0.4, -10, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 0.86, "hit": 0.3, "keys": [
			_t(0.0, 0.4, -10, 6, R_GUARD, L_GUARD, W),
			_t(0.2, 0.46, -30, -8, R_CHAMBER, L_FWD, BK),
			_t(0.3, 0.5, 24, 18, R_PUNCH, L_BACK, L),
			_t(0.56, 0.48, 20, 14, R_PUNCH, L_BACK, L),
			_t(0.86, 0.4, -10, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 1.02, "hit": 0.56, "keys": [
			_t(0.0, 0.4, -10, 6, R_GUARD, L_GUARD, W),
			_t(0.16, 0.36, 0, -6, R_OVER, L_FWD, ST),
			_t(0.3, 0.36, 8, -6, R_OVER2, L_FWD, W),
			_t(0.44, 0.36, 0, -6, R_OVER, L_FWD, W),
			_t(0.56, 0.48, 20, 16, R_PUNCH, L_BACK, L),
			_t(0.78, 0.46, 16, 12, R_PUNCH, L_BACK, L),
			_t(1.02, 0.4, -10, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 1.1, "hit": 0.26, "keys": [
			_t(0.0, 0.48, 16, 12, R_PUNCH, L_BACK, L),
			_t(0.26, 0.56, -46, -14, R_YANK, L_FWD, BK),
			_t(0.6, 0.58, -52, -16, R_YANK, L_FWD, BK),
			_t(0.8, 0.5, -30, -6, R_YANK, L_GUARD, W),
			_t(1.1, 0.4, -10, 6, R_GUARD, L_GUARD, W),
		]},
		{"len": 1.08, "hit": 0.44, "keys": [
			_t(0.0, 0.4, -10, 6, R_GUARD, L_GUARD, W),
			_t(0.2, 0.62, -40, -10, R_CHAMBER, L_FWD, BK),
			_t(0.36, 0.64, -44, -12, R_CHAMBER, L_FWD, BK),
			_t(0.44, 0.56, 30, 30, R_PUNCH, L_BACK, L),
			_t(0.68, 0.56, 26, 26, R_PUNCH, L_BACK, L),
			_t(1.08, 0.4, -10, 6, R_GUARD, L_GUARD, W),
		]},
	]
