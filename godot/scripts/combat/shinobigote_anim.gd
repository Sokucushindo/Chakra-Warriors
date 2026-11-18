extends RefCounted
## Shinobigote (忍小手, bilimsel ninja aleti; kanon: Katasuke, Boruto, Konohamaru — refs/shinobigote): sağ ön kolda düzenek. Kartuşlu tekniği, takan kolun eliyle yapılan TEK EL mührü salar;
## kullanıcının chakrası harcanmaz. Her adım önce el mührü (Kote hand seal şeması), sonra kol hedefe uzanır.
## 1 Katon Dan, 2 Suiton Dan (Shachi), 3 Raiton Dan (Ibuki), 4 Kamaitachi, 5 Kagemane, 6 Rasengan (eldivenle fırlatılabilir).

const S = preload("res://scripts/combat/samehada_anim.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const FWD := Vector3(0, 0, 1)
const R_REST := {"RightUpperArm": Vector3(-0.28, -0.82, 0.5), "RightLowerArm": Vector3(0.3, 0.1, 0.95)}
const R_SEAL := {"RightUpperArm": Vector3(-0.5, -0.65, 0.57), "RightLowerArm": Vector3(0.28, 0.9, 0.34)}     # el yüz önünde, parmaklar mühürde
const R_AIM := {"RightUpperArm": Vector3(-0.04, 0.03, 1), "RightLowerArm": Vector3(0.0, 0.03, 1)}
const R_KICK := {"RightUpperArm": Vector3(-0.1, 0.12, 0.98), "RightLowerArm": Vector3(0.02, 0.32, 0.95)}     # geri tepme
const R_LOW := {"RightUpperArm": Vector3(-0.08, -0.42, 0.9), "RightLowerArm": Vector3(0.0, -0.5, 0.86)}      # yere doğru
const L_REST := {"LeftUpperArm": Vector3(0.3, -0.8, 0.5), "LeftLowerArm": Vector3(-0.3, 0.2, 0.93)}
const L_BRACE := {"LeftUpperArm": Vector3(0.2, -0.45, 0.87), "LeftLowerArm": Vector3(-0.72, 0.2, 0.66)}      # sol el sağ kolu destekler


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, FWD, S._a(r, l), legs)


static func _shot(hit: float, end: float, aim: Dictionary, yaw: float, legs: Dictionary, brace := false) -> Array:
	var l = L_BRACE if brace else L_REST
	return [
		_t(0.0, 0.42, 8, 4, R_REST, L_REST, F.FIGHT),
		_t(hit * 0.55, 0.44, 12, -2, R_SEAL, L_REST, F.SHIFT),
		_t(hit - 0.03, 0.46, yaw, 8, aim, l, legs),
		_t(hit + 0.05, 0.46, yaw + 3, 2, R_KICK if aim == R_AIM else aim, l, legs),
		_t(hit + 0.2, 0.45, yaw, 5, aim, l, legs),
		_t(end, 0.42, 8, 4, R_REST, L_REST, F.FIGHT),
	]


static func steps() -> Array:
	return [
		{"len": 0.62, "hit": 0.26, "keys": _shot(0.26, 0.62, R_AIM, -14, F.PIVOT)},
		{"len": 0.74, "hit": 0.32, "keys": _shot(0.32, 0.74, R_AIM, -18, S.LEG_BACK, true)},
		{"len": 0.6, "hit": 0.24, "keys": _shot(0.24, 0.6, R_AIM, -12, F.PIVOT)},
		{"len": 0.72, "hit": 0.3, "keys": _shot(0.3, 0.72, R_AIM, -30, S.LEG_LUNGE)},
		{"len": 0.86, "hit": 0.36, "keys": _shot(0.36, 0.86, R_LOW, -6, F.LOW)},
		{"len": 1.14, "hit": 0.6, "keys": _shot(0.6, 1.14, R_AIM, -20, S.LEG_LUNGE, true)},
	]
