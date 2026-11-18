extends RefCounted
## Doriru Ude (matkap kol; refs/doriru_ude): sağ kolda dev gövde, sol el altından taşır (kaynak kare). Ağır; kuruluş uzun.
## 1 Tsuki, 2 Neji Komi (saplanıp döner), 3 Tobi Te (kablolu el fırlar), 4 Moguri (yere dalar, hedefin arkasından çıkar),
## 5 Mizo Kiri (yerde hendek açar), 6 Ikkan (uzun bekleyiş, tek öldürücü delme). Mekanik DoriruUdeFX.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_HOLD := {"RightUpperArm": Vector3(-0.2, -0.45, 0.87), "RightLowerArm": Vector3(0.1, 0.05, 0.99)}
const L_SUP := {"LeftUpperArm": Vector3(0.1, -0.7, 0.7), "LeftLowerArm": Vector3(-0.72, 0.1, 0.68)}
const R_BACK := {"RightUpperArm": Vector3(-0.5, -0.55, -0.66), "RightLowerArm": Vector3(-0.05, 0.05, 0.99)}
const R_FWD := {"RightUpperArm": Vector3(-0.03, 0.0, 1), "RightLowerArm": Vector3(0.0, 0.0, 1)}
const R_DOWN := {"RightUpperArm": Vector3(-0.08, -0.72, 0.68), "RightLowerArm": Vector3(0.0, -0.9, 0.42)}
const R_UP := {"RightUpperArm": Vector3(-0.08, 0.72, 0.68), "RightLowerArm": Vector3(0.0, 0.92, 0.36)}
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const B := Vector3(0, 0, 1)


static func _t(t: float, c: float, y: float, l: float, r: Dictionary, a: Dictionary, g: Dictionary) -> Dictionary:
	return S._k(t, c, y, l, B, S._a(r, a), g)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var BK = S.LEG_BACK
	return [
		{"len": 0.86, "hit": 0.34, "keys": [
			_t(0.0, 0.44, -8, 6, R_HOLD, L_SUP, W), _t(0.24, 0.5, -30, -8, R_BACK, L_SUP, BK), _t(0.34, 0.54, 20, 22, R_FWD, L_SUP, L),
			_t(0.56, 0.52, 16, 18, R_FWD, L_SUP, L), _t(0.86, 0.44, -8, 6, R_HOLD, L_SUP, W)]},
		{"len": 1.16, "hit": 0.3, "extra_hits": [0.5, 0.7], "extra_radius": 2.0, "keys": [
			_t(0.0, 0.44, -8, 6, R_HOLD, L_SUP, W), _t(0.2, 0.5, -24, -6, R_BACK, L_SUP, BK), _t(0.3, 0.58, 12, 26, R_FWD, L_SUP, L),
			_t(0.82, 0.6, 10, 28, R_FWD, L_SUP, L), _t(1.16, 0.44, -8, 6, R_HOLD, L_SUP, W)]},
		{"len": 1.2, "hit": 0.36, "keys": [
			_t(0.0, 0.44, -8, 6, R_HOLD, L_SUP, W), _t(0.26, 0.48, -26, -8, R_BACK, L_BACK, BK), _t(0.36, 0.5, 18, 14, R_FWD, L_BACK, L),
			_t(0.94, 0.5, 14, 12, R_FWD, L_BACK, L), _t(1.2, 0.44, -8, 6, R_HOLD, L_SUP, W)]},
		{"len": 1.5, "hit": 1.02, "keys": [
			_t(0.0, 0.44, -8, 6, R_HOLD, L_SUP, W), _t(0.22, 0.74, 0, 40, R_DOWN, L_SUP, L), _t(0.96, 0.74, 0, 36, R_DOWN, L_SUP, L),
			_t(1.02, 0.34, 8, -8, R_UP, L_BACK, L), _t(1.24, 0.32, 6, -10, R_UP, L_BACK, W), _t(1.5, 0.44, -8, 6, R_HOLD, L_SUP, W)]},
		{"len": 1.22, "hit": 0.42, "keys": [
			_t(0.0, 0.44, -8, 6, R_HOLD, L_SUP, W), _t(0.3, 0.5, -10, -4, R_BACK, L_SUP, BK), _t(0.42, 0.76, 4, 42, R_DOWN, L_SUP, L),
			_t(0.86, 0.74, 2, 38, R_DOWN, L_SUP, L), _t(1.22, 0.44, -8, 6, R_HOLD, L_SUP, W)]},
		{"len": 1.84, "hit": 0.98, "keys": [
			_t(0.0, 0.44, -8, 6, R_HOLD, L_SUP, W), _t(0.4, 0.56, -38, -14, R_BACK, L_SUP, BK), _t(0.9, 0.58, -42, -16, R_BACK, L_SUP, BK),
			_t(0.98, 0.6, 26, 32, R_FWD, L_BACK, L), _t(1.4, 0.58, 22, 28, R_FWD, L_BACK, L), _t(1.84, 0.44, -8, 6, R_HOLD, L_SUP, W)]},
	]
