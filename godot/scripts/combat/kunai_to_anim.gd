extends RefCounted
## Kunai-tō (Kotetsu ve Izumo'nun kılıç boyu kunaisi; refs/kunai_to/kunai_blades.png): tek ağızlı kavisli ağız, sargılı sap, büyük halka.
## Hafif kılıç ritmi; sol el halkadaki zinciri ve ağırlığı yönetir.
## 1 Yoko Nagi: yatay kesik, 2 Kesa Kaeshi: ters çapraz, 3 Fundō Nage: halkadan ağırlık fırlar,
## 4 Ashi Dori: zincir savrulur, ağırlık bacaklara dolanır, 5 Hiki Yose: çekip yaklaşırken saplar,
## 6 Renkei (bitiriş): yanında aynı silahlı yoldaş varsa zincir ikisinin arasında gerilir; yoksa bütün bedenle düz saplama.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.2, -0.85, 0.45), "RightLowerArm": Vector3(0.2, -0.3, 0.93)}
const R_WIDE := {"RightUpperArm": Vector3(-0.95, 0.1, 0.25), "RightLowerArm": Vector3(-0.85, 0.15, 0.45)}
const R_LEFT := {"RightUpperArm": Vector3(0.2, 0.05, 0.97), "RightLowerArm": Vector3(0.9, 0.2, 0.3)}
const R_LOW := {"RightUpperArm": Vector3(-0.4, -0.85, 0.3), "RightLowerArm": Vector3(-0.3, -0.7, 0.65)}
const R_HIGH := {"RightUpperArm": Vector3(0.1, 0.8, 0.55), "RightLowerArm": Vector3(0.45, 0.85, 0.25)}
const R_CHAMBER := {"RightUpperArm": Vector3(-0.3, -0.6, -0.75), "RightLowerArm": Vector3(-0.05, -0.05, 1)}
const R_STAB := {"RightUpperArm": Vector3(-0.04, -0.03, 1), "RightLowerArm": Vector3(0.0, -0.02, 1)}
const R_OVER := {"RightUpperArm": Vector3(-0.3, 0.95, 0.05), "RightLowerArm": Vector3(0.5, 0.85, 0.1)}
const L_GUARD := {"LeftUpperArm": Vector3(0.3, -0.75, 0.55), "LeftLowerArm": Vector3(-0.2, 0.3, 0.93)}
const L_CAST := {"LeftUpperArm": Vector3(0.1, 0.1, 1), "LeftLowerArm": Vector3(0.0, 0.1, 1)}
const L_WIND := {"LeftUpperArm": Vector3(0.7, 0.3, -0.6), "LeftLowerArm": Vector3(0.3, 0.8, -0.4)}
const L_PULL := {"LeftUpperArm": Vector3(0.5, -0.6, -0.6), "LeftLowerArm": Vector3(-0.2, 0.2, 0.95)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.2, 0.3, 0.93)
	return [
		{"len": 0.56, "hit": 0.2, "keys": [
			_t(0.0, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
			_t(0.12, 0.42, -32, -2, Vector3(-0.9, 0.2, -0.3), R_WIDE, L_GUARD, BK),
			_t(0.2, 0.46, 26, 14, Vector3(0.85, 0.05, 0.5), R_LEFT, L_GUARD, L),
			_t(0.34, 0.44, 30, 12, Vector3(0.9, 0.05, 0.4), R_LEFT, L_GUARD, L),
			_t(0.56, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
		]},
		{"len": 0.6, "hit": 0.22, "keys": [
			_t(0.0, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
			_t(0.13, 0.5, 18, 8, Vector3(0.5, -0.7, 0.5), R_LOW, L_GUARD, CR),
			_t(0.22, 0.36, -24, 4, Vector3(-0.5, 0.75, 0.42), R_HIGH, L_GUARD, LL),
			_t(0.36, 0.34, -28, 0, Vector3(-0.55, 0.78, 0.3), R_HIGH, L_GUARD, LL),
			_t(0.6, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
		]},
		{"len": 0.78, "hit": 0.3, "keys": [
			_t(0.0, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
			_t(0.18, 0.42, 24, -6, Vector3(0.1, 0.5, 0.86), R_READY, L_WIND, BK),
			_t(0.3, 0.46, -24, 16, Vector3(0.1, 0.3, 0.95), R_READY, L_CAST, LL),
			_t(0.5, 0.44, -20, 12, Vector3(0.1, 0.3, 0.95), R_READY, L_CAST, LL),
			_t(0.78, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
		]},
		{"len": 0.96, "hit": 0.5, "keys": [
			_t(0.0, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
			_t(0.16, 0.34, 10, -6, Vector3(0.1, 0.5, 0.86), R_READY, L_WIND, ST),
			_t(0.34, 0.34, 40, -6, Vector3(0.1, 0.5, 0.86), R_READY, L_WIND, W),
			_t(0.5, 0.56, -18, 20, Vector3(0.1, 0.1, 0.99), R_READY, L_CAST, LL),
			_t(0.72, 0.54, -14, 16, Vector3(0.1, 0.1, 0.99), R_READY, L_CAST, LL),
			_t(0.96, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
		]},
		{"len": 0.84, "hit": 0.38, "keys": [
			_t(0.0, 0.54, -14, 16, Vector3(0.1, 0.1, 0.99), R_READY, L_CAST, LL),
			_t(0.2, 0.5, -40, -8, Vector3(0.0, 0.05, 1), R_CHAMBER, L_PULL, BK),
			_t(0.38, 0.52, 18, 20, Vector3(0.0, 0.0, 1), R_STAB, L_PULL, L),
			_t(0.56, 0.5, 14, 16, Vector3(0.0, 0.0, 1), R_STAB, L_PULL, L),
			_t(0.84, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
		]},
		{"len": 1.16, "hit": 0.52, "keys": [
			_t(0.0, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
			_t(0.22, 0.34, -6, -10, Vector3(0, 0.9, 0.4), R_OVER, L_WIND, ST),
			_t(0.42, 0.62, -34, -6, Vector3(0.0, 0.05, 1), R_CHAMBER, L_GUARD, BK),
			_t(0.52, 0.6, 22, 30, Vector3(0.0, -0.05, 1), R_STAB, L_CAST, L),
			_t(0.8, 0.6, 18, 28, Vector3(0.0, -0.05, 1), R_STAB, L_CAST, L),
			_t(1.16, 0.38, -8, 6, RDY, R_READY, L_GUARD, W),
		]},
	]
