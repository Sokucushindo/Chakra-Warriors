extends RefCounted
## Tenrō Doriru (iki kolda matkap): 1 sağ, 2 sol, 3 çift saplama, 4 Moguri (yere dalış), 5 Mai Age (dönerek yükselen delme), 6 Sōshin (iki matkap, uzun saplama).

const O = preload("res://scripts/combat/oni_kote_anim.gd")
const S = preload("res://scripts/combat/samehada_anim.gd")
const L_P := {"LeftUpperArm": Vector3(0.05, 0.05, 1), "LeftLowerArm": Vector3(0.0, 0.05, 1)}
const L_C := {"LeftUpperArm": Vector3(0.45, -0.6, -0.7), "LeftLowerArm": Vector3(0.1, 0.3, 0.95)}
const R_D := {"RightUpperArm": Vector3(-0.1, -0.7, 0.7), "RightLowerArm": Vector3(0.0, -0.9, 0.42)}
const L_D := {"LeftUpperArm": Vector3(0.1, -0.7, 0.7), "LeftLowerArm": Vector3(0.0, -0.9, 0.42)}


static func _s(ln: float, hit: float, r0: Dictionary, l0: Dictionary, r1: Dictionary, l1: Dictionary, y: float, g: Dictionary, extra := []) -> Dictionary:
	var d = {"len": ln, "hit": hit, "keys": [
		O._t(0.0, 0.42, -6, 6, O.R_GUARD, O.L_GUARD, S.LEG_WIDE),
		O._t(hit * 0.7, 0.46, -y, -6, r0, l0, S.LEG_BACK),
		O._t(hit, 0.52, y, 20, r1, l1, g),
		O._t(hit + (ln - hit) * 0.5, 0.5, y * 0.8, 16, r1, l1, g),
		O._t(ln, 0.42, -6, 6, O.R_GUARD, O.L_GUARD, S.LEG_WIDE),
	]}
	if not extra.is_empty():
		d["extra_hits"] = extra
		d["extra_radius"] = 2.0
	return d


static func steps() -> Array:
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	return [
		_s(0.6, 0.22, O.R_CHAMBER, O.L_GUARD, O.R_PUNCH, O.L_BACK, 18.0, L),
		_s(0.6, 0.22, O.R_GUARD, L_C, O.R_GUARD, L_P, -18.0, LL),
		_s(0.9, 0.28, O.R_CHAMBER, L_C, O.R_PUNCH, L_P, 4.0, L, [0.46, 0.62]),
		_s(1.46, 1.02, R_D, L_D, O.R_RISE, L_P, 6.0, L),
		_s(0.96, 0.3, O.R_LOW, L_D, O.R_RISE, O.L_BACK, 10.0, LL, [0.5]),
		_s(1.3, 0.58, O.R_CHAMBER, L_C, O.R_PUNCH, L_P, 2.0, L),
	]
