extends RefCounted
## Nunoboko no Ken (ぬのぼこの剣; kanon: Hagoromo, Obito — refs/nunoboko): arayış toplarından biçimlenmiş çift sarmal dev kılıç, İKİ ELLE. Ağırlıksız gibi süzülür ama vurduğunda dünya yarılır:
## yavaş kurulum, tek geniş hat, gövdeyi sürüklemez (kılıç kendi kendine uzanır).
## 1 Kesa, 2 Kaeshi, 3 Rasen Tsuki: sarmal uzar, döne döne saplanır, 4 Tenchi Oroshi: tepeden iniş, savunma kırar, 5 Ō Mawashi: uzayan kılıçla çevre, 6 Sōsei (bitiriş): ucu yere dikilir, yerden sarmal arayış topları ve yıldız izi çıkar.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.3, -0.85, 0.42), "RightLowerArm": Vector3(0.3, 0.05, 0.95)}
const R_HI_R := {"RightUpperArm": Vector3(-0.68, 0.55, -0.34), "RightLowerArm": Vector3(-0.2, 0.9, -0.3)}
const R_HI_L := {"RightUpperArm": Vector3(0.22, 0.45, 0.86), "RightLowerArm": Vector3(0.7, 0.65, -0.2)}
const R_DOWN_L := {"RightUpperArm": Vector3(0.15, -0.42, 0.9), "RightLowerArm": Vector3(0.68, -0.35, 0.64)}
const R_DOWN_R := {"RightUpperArm": Vector3(-0.58, -0.4, 0.71), "RightLowerArm": Vector3(-0.5, -0.4, 0.77)}
const R_THRUST := {"RightUpperArm": Vector3(-0.08, 0.02, 1), "RightLowerArm": Vector3(0.02, 0.02, 1)}
const R_COCK := {"RightUpperArm": Vector3(-0.5, -0.6, -0.62), "RightLowerArm": Vector3(0.05, 0.08, 1)}
const R_OVER := {"RightUpperArm": Vector3(-0.2, 0.94, 0.26), "RightLowerArm": Vector3(0.0, 0.92, -0.38)}
const R_FALL := {"RightUpperArm": Vector3(-0.08, -0.36, 0.93), "RightLowerArm": Vector3(0.0, -0.56, 0.83)}
const R_WIDE := {"RightUpperArm": Vector3(-0.2, -0.1, 0.97), "RightLowerArm": Vector3(0.45, 0.02, 0.9)}
const R_WIND := {"RightUpperArm": Vector3(-0.9, -0.2, -0.36), "RightLowerArm": Vector3(-0.6, 0.1, -0.79)}
const R_PLANT := {"RightUpperArm": Vector3(-0.15, -0.68, 0.72), "RightLowerArm": Vector3(0.0, -0.94, 0.34)}
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_ANY), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var B = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.2, 0.42, 0.88)
	return [
		{"len": 1.08, "hit": 0.48, "two": true, "keys": [
			_t(0.0, 0.4, -6, 3, RDY, R_READY, W),
			_t(0.3, 0.34, -30, -14, Vector3(-0.42, 0.72, -0.55), R_HI_R, B),
			_t(0.42, 0.33, -33, -16, Vector3(-0.42, 0.7, -0.58), R_HI_R, B),
			_t(0.48, 0.52, 20, 20, Vector3(0.56, -0.48, 0.67), R_DOWN_L, L),
			_t(0.7, 0.54, 24, 22, Vector3(0.6, -0.5, 0.62), R_DOWN_L, L),
			_t(1.08, 0.4, -6, 3, RDY, R_READY, W),
		]},
		{"len": 1.02, "hit": 0.42, "two": true, "keys": [
			_t(0.0, 0.4, -6, 3, RDY, R_READY, W),
			_t(0.26, 0.34, 30, -12, Vector3(0.48, 0.7, -0.52), R_HI_L, B),
			_t(0.36, 0.33, 33, -14, Vector3(0.48, 0.68, -0.55), R_HI_L, B),
			_t(0.42, 0.52, -22, 20, Vector3(-0.56, -0.48, 0.67), R_DOWN_R, LL),
			_t(0.64, 0.54, -26, 22, Vector3(-0.6, -0.5, 0.62), R_DOWN_R, LL),
			_t(1.02, 0.4, -6, 3, RDY, R_READY, W),
		]},
		{"len": 1.16, "hit": 0.5, "two": true, "keys": [
			_t(0.0, 0.4, -6, 3, RDY, R_READY, W),
			_t(0.3, 0.54, -30, -10, Vector3(0, 0.1, 1), R_COCK, B),
			_t(0.44, 0.56, -34, -12, Vector3(0, 0.1, 1), R_COCK, B),
			_t(0.5, 0.56, 16, 26, Vector3(0, 0.05, 1), R_THRUST, L),
			_t(0.8, 0.54, 12, 22, Vector3(0, 0.05, 1), R_THRUST, L),
			_t(1.16, 0.4, -6, 3, RDY, R_READY, W),
		]},
		{"len": 1.34, "hit": 0.66, "two": true, "keys": [
			_t(0.0, 0.4, -6, 3, RDY, R_READY, W),
			_t(0.34, 0.26, -6, -20, Vector3(0, 0.74, -0.67), R_OVER, ST),
			_t(0.58, 0.24, -8, -26, Vector3(0, 0.68, -0.73), R_OVER, ST),
			_t(0.66, 0.72, 6, 36, Vector3(0, -0.7, 0.71), R_FALL, L),
			_t(0.96, 0.74, 4, 38, Vector3(0, -0.74, 0.67), R_FALL, L),
			_t(1.34, 0.4, -6, 3, RDY, R_READY, W),
		]},
		{"len": 1.5, "hit": 0.6, "two": true, "extra_hits": [0.82], "extra_radius": 4.4, "keys": [
			_t(0.0, 0.4, -6, 3, RDY, R_READY, W),
			_t(0.32, 0.54, -50, -3, Vector3(-0.86, 0.14, -0.48), R_WIND, B),
			_t(0.52, 0.56, -56, -4, Vector3(-0.86, 0.14, -0.5), R_WIND, B),
			_t(0.6, 0.58, -2, 14, Vector3(-0.3, 0.02, 0.95), R_WIDE, ST),
			_t(0.74, 0.58, 66, 16, Vector3(0.62, 0.0, 0.78), R_WIDE, CR),
			_t(0.92, 0.56, 140, 12, Vector3(0.62, 0.02, 0.78), R_WIDE, CR),
			_t(1.16, 0.5, 300, 8, Vector3(0.5, 0.25, 0.83), R_WIDE, W),
			_t(1.5, 0.4, 354, 3, RDY, R_READY, W),
		]},
		{"len": 2.0, "hit": 0.78, "two": true, "keys": [
			_t(0.0, 0.4, -6, 3, RDY, R_READY, W),
			_t(0.4, 0.3, -2, -18, Vector3(0, 0.98, -0.1), R_OVER, W),
			_t(0.7, 0.28, -2, -22, Vector3(0, 0.96, -0.2), R_OVER, B),
			_t(0.78, 0.76, 2, 34, Vector3(0, -0.92, 0.38), R_PLANT, L),
			_t(1.5, 0.74, 2, 30, Vector3(0, -0.92, 0.38), R_PLANT, L),
			_t(2.0, 0.4, -6, 3, RDY, R_READY, W),
		]},
	]
