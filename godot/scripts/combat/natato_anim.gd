extends RefCounted
## Natatō (Darui'nin katlanır satırı; refs/natato/cleaver-sword.png). İki elle: sağ el kısa sapta, sol el yassı gövdeyi taşır (kaynak kare).
## Duruşta katlıdır, ilk harekette açılır. Ağır silah ritmi: geri çek, dur, hızlı in, ağırlıkla devam, yavaş topla.
## 1 Hiraki Oroshi: inerken açılır, 2 Ō Nagi: geniş yatay, 3 Hira Uchi: yassı yüzle ezer (savunma kırar),
## 4 Kachi Age: alttan kaldırır, 5 Raiden Nagashi: chakrayı ağza akıtır, dönerek iki kesik,
## 6 Nata Nage (bitiriş): fırlatır, ağız yere saplanır; yüklü yıldırım elden çıkınca da kalır (kanon), sonra ele döner.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_SHLD := {"RightUpperArm": Vector3(-0.42, -0.72, 0.55), "RightLowerArm": Vector3(0.2, 0.78, 0.6)}
const R_LIFT := {"RightUpperArm": Vector3(-0.3, 0.72, 0.62), "RightLowerArm": Vector3(0.0, 0.9, -0.42)}
const R_DOWN := {"RightUpperArm": Vector3(-0.08, -0.4, 0.91), "RightLowerArm": Vector3(0.0, -0.62, 0.78)}
const R_WIND := {"RightUpperArm": Vector3(-0.92, -0.22, -0.32), "RightLowerArm": Vector3(-0.62, 0.1, -0.78)}
const R_WIDE := {"RightUpperArm": Vector3(-0.2, -0.12, 0.97), "RightLowerArm": Vector3(0.45, 0.02, 0.9)}
const R_BAR := {"RightUpperArm": Vector3(-0.42, -0.62, 0.66), "RightLowerArm": Vector3(0.82, 0.12, 0.55)}
const R_BAR_F := {"RightUpperArm": Vector3(-0.3, -0.18, 0.94), "RightLowerArm": Vector3(0.75, 0.08, 0.66)}
const R_LOW := {"RightUpperArm": Vector3(-0.45, -0.82, 0.35), "RightLowerArm": Vector3(-0.2, -0.75, 0.62)}
const R_UP := {"RightUpperArm": Vector3(0.2, 0.15, 0.97), "RightLowerArm": Vector3(0.62, 0.55, 0.55)}
const R_THROW := {"RightUpperArm": Vector3(-0.05, 0.1, 1), "RightLowerArm": Vector3(0.0, 0.05, 1)}
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}
const L_OPEN := {"LeftUpperArm": Vector3(0.7, -0.65, 0.1), "LeftLowerArm": Vector3(0.45, -0.75, 0.45)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary, l: Dictionary = L_ANY) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(-0.3, 0.62, -0.72)
	return [
		{"len": 1.08, "hit": 0.46, "two": true, "keys": [
			_t(0.0, 0.42, -8, 4, RDY, R_SHLD, W),
			_t(0.22, 0.34, -14, -16, Vector3(-0.1, 0.72, -0.68), R_LIFT, BK),
			_t(0.38, 0.32, -16, -20, Vector3(-0.1, 0.66, -0.74), R_LIFT, BK),
			_t(0.46, 0.68, 6, 32, Vector3(0, -0.6, 0.8), R_DOWN, L),
			_t(0.74, 0.7, 4, 34, Vector3(0, -0.66, 0.75), R_DOWN, L),
			_t(1.08, 0.42, -8, 4, RDY, R_SHLD, W),
		]},
		{"len": 1.16, "hit": 0.46, "two": true, "extra_hits": [0.6], "extra_radius": 2.8, "keys": [
			_t(0.0, 0.42, -8, 4, RDY, R_SHLD, W),
			_t(0.26, 0.52, -46, -2, Vector3(-0.88, 0.14, -0.45), R_WIND, BK),
			_t(0.4, 0.54, -50, -4, Vector3(-0.88, 0.12, -0.48), R_WIND, BK),
			_t(0.46, 0.56, -6, 14, Vector3(-0.3, 0.04, 0.95), R_WIDE, ST),
			_t(0.6, 0.58, 52, 16, Vector3(0.7, 0.02, 0.7), R_WIDE, CR),
			_t(0.84, 0.5, 44, 8, Vector3(0.62, 0.2, 0.72), R_WIDE, W),
			_t(1.16, 0.42, -8, 4, RDY, R_SHLD, W),
		]},
		{"len": 0.94, "hit": 0.38, "two": true, "keys": [
			_t(0.0, 0.42, -8, 4, RDY, R_SHLD, W),
			_t(0.22, 0.56, -14, -8, Vector3(0.96, 0.18, 0.2), R_BAR, BK),
			_t(0.32, 0.56, -16, -10, Vector3(0.96, 0.18, 0.2), R_BAR, BK),
			_t(0.38, 0.56, 8, 26, Vector3(0.95, 0.12, 0.28), R_BAR_F, L),
			_t(0.58, 0.54, 6, 22, Vector3(0.95, 0.12, 0.28), R_BAR_F, L),
			_t(0.94, 0.42, -8, 4, RDY, R_SHLD, W),
		]},
		{"len": 1.0, "hit": 0.42, "two": true, "keys": [
			_t(0.0, 0.42, -8, 4, RDY, R_SHLD, W),
			_t(0.24, 0.74, -30, 24, Vector3(-0.7, -0.56, 0.44), R_LOW, BK),
			_t(0.36, 0.76, -24, 26, Vector3(-0.5, -0.62, 0.6), R_LOW, ST),
			_t(0.42, 0.44, 20, 0, Vector3(0.5, 0.56, 0.66), R_UP, LL),
			_t(0.64, 0.36, 32, -8, Vector3(0.55, 0.7, 0.45), R_UP, LL),
			_t(1.0, 0.42, -8, 4, RDY, R_SHLD, W),
		]},
		{"len": 1.4, "hit": 0.62, "two": true, "extra_hits": [0.86], "extra_radius": 3.0, "keys": [
			_t(0.0, 0.42, -8, 4, RDY, R_SHLD, W),
			_t(0.3, 0.46, -12, 2, Vector3(0.1, 0.98, 0.1), R_LIFT, W, L_OPEN),
			_t(0.52, 0.5, -48, -2, Vector3(-0.88, 0.14, -0.45), R_WIND, BK),
			_t(0.62, 0.56, 8, 14, Vector3(-0.2, 0.04, 0.97), R_WIDE, ST),
			_t(0.74, 0.58, 110, 16, Vector3(0.7, 0.02, 0.7), R_WIDE, CR),
			_t(0.86, 0.58, 230, 14, Vector3(0.7, 0.02, 0.7), R_WIDE, CR),
			_t(1.04, 0.5, 340, 8, Vector3(0.5, 0.2, 0.8), R_WIDE, W),
			_t(1.4, 0.42, 352, 4, RDY, R_SHLD, W),
		]},
		{"len": 1.96, "hit": 0.6, "keys": [
			_t(0.0, 0.42, -8, 4, RDY, R_SHLD, W),
			_t(0.3, 0.42, -34, -16, Vector3(-0.72, 0.3, -0.62), R_WIND, BK, L_OPEN),
			_t(0.52, 0.42, -40, -20, Vector3(-0.76, 0.3, -0.58), R_WIND, BK, L_OPEN),
			_t(0.6, 0.56, 22, 24, Vector3(0.2, 0.0, 0.98), R_THROW, L, L_OPEN),
			_t(0.9, 0.5, 14, 14, Vector3(0.1, 0.1, 0.98), R_THROW, L, L_OPEN),
			_t(1.5, 0.46, 2, 4, Vector3(0.05, 0.3, 0.95), R_THROW, W, L_OPEN),
			_t(1.66, 0.5, -12, 10, RDY, R_SHLD, BK),
			_t(1.96, 0.42, -8, 4, RDY, R_SHLD, W),
		]},
	]
