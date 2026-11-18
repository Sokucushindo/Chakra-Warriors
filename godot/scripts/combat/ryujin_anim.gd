extends RefCounted
## Ryūjin (ejder bıçağı) kombosu: beş adım beş doğa (Katon, Fūton, Raiton, Doton, Suiton), 6 Ryū Nage: bıçak fırlar, beş küre patlar, sahibine döner.

const A = preload("res://scripts/combat/kunai_to_anim.gd")
const S = preload("res://scripts/combat/samehada_anim.gd")
const RDY := Vector3(0.2, 0.3, 0.93)


static func _s(ln: float, hit: float, b0: Vector3, r0: Dictionary, b1: Vector3, r1: Dictionary, y: float, g: Dictionary) -> Dictionary:
	return {"len": ln, "hit": hit, "keys": [
		A._t(0.0, 0.38, -8, 6, RDY, A.R_READY, A.L_GUARD, S.LEG_WIDE),
		A._t(hit * 0.62, 0.42, -y, -3, b0, r0, A.L_GUARD, S.LEG_BACK),
		A._t(hit, 0.46, y, 14, b1, r1, A.L_GUARD, g),
		A._t(hit + (ln - hit) * 0.42, 0.44, y * 0.9, 11, b1, r1, A.L_GUARD, g),
		A._t(ln, 0.38, -8, 6, RDY, A.R_READY, A.L_GUARD, S.LEG_WIDE),
	]}


static func steps() -> Array:
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	return [
		_s(0.54, 0.2, Vector3(-0.9, 0.2, -0.3), A.R_WIDE, Vector3(0.85, 0.05, 0.5), A.R_LEFT, 26.0, L),
		_s(0.56, 0.2, Vector3(0.5, -0.7, 0.5), A.R_LOW, Vector3(-0.5, 0.75, 0.42), A.R_HIGH, -22.0, LL),
		_s(0.52, 0.2, Vector3(0, 0.05, 1), A.R_CHAMBER, Vector3(0, 0, 1), A.R_STAB, 16.0, L),
		_s(0.7, 0.28, Vector3(0, 0.9, 0.4), A.R_OVER, Vector3(0, -0.6, 0.8), A.R_LOW, 6.0, L),
		_s(0.64, 0.24, Vector3(0.9, 0.2, 0.3), A.R_LEFT, Vector3(-0.9, 0.1, 0.4), A.R_WIDE, -28.0, LL),
		_s(1.5, 0.46, Vector3(0, 0.6, -0.8), A.R_OVER, Vector3(0, 0.05, 1), A.R_STAB, 14.0, L),
	]
