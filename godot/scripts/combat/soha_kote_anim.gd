extends RefCounted
## Sōha Kote (çift bıçaklı kolluk; refs/soha_kote): iki ön kolda. Yakın dövüş kolla kesilir: yumruk değil ön kol ağzı değer.
## 1 Migi Ude, 2 Hidari Ude, 3 Uke Nagashi (iki kol önde: gelen darbeyi ağıza alır), 4 Jūji (X kesik), 5 Hiji Age (dirsekle yukarı), 6 Hasami Kiri (iki kol dıştan içe).

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_G := {"RightUpperArm": Vector3(-0.35, -0.75, 0.55), "RightLowerArm": Vector3(0.15, 0.75, 0.65)}
const L_G := {"LeftUpperArm": Vector3(0.35, -0.75, 0.55), "LeftLowerArm": Vector3(-0.15, 0.75, 0.65)}
const R_OUT := {"RightUpperArm": Vector3(-0.95, -0.1, 0.25), "RightLowerArm": Vector3(-0.72, 0.1, 0.68)}
const L_OUT := {"LeftUpperArm": Vector3(0.95, -0.1, 0.25), "LeftLowerArm": Vector3(0.72, 0.1, 0.68)}
const R_IN := {"RightUpperArm": Vector3(0.15, -0.15, 0.98), "RightLowerArm": Vector3(0.88, 0.05, 0.46)}
const L_IN := {"LeftUpperArm": Vector3(-0.15, -0.15, 0.98), "LeftLowerArm": Vector3(-0.88, 0.05, 0.46)}
const R_BAR := {"RightUpperArm": Vector3(-0.45, -0.5, 0.72), "RightLowerArm": Vector3(0.85, 0.32, 0.4)}
const L_BAR := {"LeftUpperArm": Vector3(0.45, -0.42, 0.78), "LeftLowerArm": Vector3(-0.85, 0.42, 0.3)}
const R_UP := {"RightUpperArm": Vector3(-0.2, 0.55, 0.8), "RightLowerArm": Vector3(0.2, 0.95, -0.2)}
const B := Vector3(0, 0, 1)


static func _t(t: float, c: float, y: float, l: float, r: Dictionary, a: Dictionary, g: Dictionary) -> Dictionary:
	return S._k(t, c, y, l, B, S._a(r, a), g)


static func _s(ln: float, hit: float, r0: Dictionary, l0: Dictionary, r1: Dictionary, l1: Dictionary, y0: float, y1: float, g0: Dictionary, g1: Dictionary) -> Dictionary:
	return {"len": ln, "hit": hit, "keys": [
		_t(0.0, 0.4, -6, 6, R_G, L_G, S.LEG_WIDE),
		_t(hit * 0.65, 0.44, y0, -3, r0, l0, g0),
		_t(hit, 0.5, y1, 15, r1, l1, g1),
		_t(hit + (ln - hit) * 0.42, 0.48, y1 * 0.85, 11, r1, l1, g1),
		_t(ln, 0.4, -6, 6, R_G, L_G, S.LEG_WIDE),
	]}


static func steps() -> Array:
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	return [
		_s(0.5, 0.17, R_OUT, L_G, R_IN, L_G, -30, 30, BK, L),
		_s(0.5, 0.17, R_G, L_OUT, R_G, L_IN, 30, -30, BK, LL),
		_s(0.8, 0.2, R_BAR, L_BAR, R_BAR, L_BAR, 0, 0, S.LEG_WIDE, S.LEG_BACK),
		_s(0.62, 0.24, R_OUT, L_OUT, R_IN, L_IN, 0, 6, BK, L),
		_s(0.6, 0.2, R_G, L_G, R_UP, L_G, -20, 18, S.LEG_STEP, LL),
		_s(0.98, 0.42, R_OUT, L_OUT, R_IN, L_IN, 0, 10, BK, L),
	]
