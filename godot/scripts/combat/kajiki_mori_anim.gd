extends RefCounted
## Kajiki Mori (Isari'nin marlin zıpkını; refs/kajiki_mori): uzun kızıl sap, iki elle. Uçta kemik balık başı.
## 1 Tsuki, 2 Hiki Gaeshi (kancayla geri çeker), 3 Harai, 4 Mori Nage (halatla fırlatır, geri sarar), 5 Nomi Komi (saplayıp chakra içer),
## 6 Oyogi (uyanmışsa balık kendi yüzer; uyanmamışsa bütün bedenle saplama). Mekanik KajikiMoriFX.

const S = preload("res://scripts/combat/samehada_anim.gd")
const B = preload("res://scripts/combat/bo_anim.gd")


static func _t(t: float, c: float, y: float, l: float, d: Vector3, r: Dictionary, g: Dictionary) -> Dictionary:
	return S._k(t, c, y * 1.25, l * 1.25, d.normalized(), S._a(r, B.L_ANY), g)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var RDY = Vector3(0.1, 0.32, 0.94)
	var FW = Vector3(0, 0.08, 1)
	return [
		{"len": 0.6, "hit": 0.24, "two": true, "keys": [
			_t(0.0, 0.38, -6, 4, RDY, B.R_READY, W), _t(0.14, 0.42, -18, -6, FW, B.R_DRAW, BK), _t(0.24, 0.52, 12, 20, FW, B.R_THRUST, L),
			_t(0.38, 0.5, 10, 16, FW, B.R_THRUST, L), _t(0.6, 0.38, -6, 4, RDY, B.R_READY, W)]},
		{"len": 0.72, "hit": 0.3, "two": true, "keys": [
			_t(0.0, 0.5, 10, 16, FW, B.R_THRUST, L), _t(0.14, 0.5, 8, 14, FW, B.R_THRUST, L), _t(0.3, 0.44, -26, -10, Vector3(0, 0.25, 0.97), B.R_DRAW, BK),
			_t(0.46, 0.42, -24, -8, Vector3(0, 0.25, 0.97), B.R_DRAW, BK), _t(0.72, 0.38, -6, 4, RDY, B.R_READY, W)]},
		{"len": 0.78, "hit": 0.34, "two": true, "keys": [
			_t(0.0, 0.38, -6, 4, RDY, B.R_READY, W), _t(0.2, 0.42, 30, -4, Vector3(0.92, 0.2, 0.3), B.R_SIDE, BK), _t(0.34, 0.5, -32, 14, Vector3(-0.92, 0.1, 0.38), B.R_WIDE, L),
			_t(0.5, 0.48, -38, 12, Vector3(-0.92, 0.08, 0.3), B.R_WIDE, L), _t(0.78, 0.38, -6, 4, RDY, B.R_READY, W)]},
		{"len": 1.28, "hit": 0.42, "two": true, "keys": [
			_t(0.0, 0.38, -6, 4, RDY, B.R_READY, W), _t(0.3, 0.3, -22, -16, Vector3(0, 0.5, -0.86), B.R_HIGH, BK), _t(0.42, 0.52, 18, 24, FW, B.R_THRUST, L),
			_t(0.95, 0.46, 8, 8, FW, B.R_DRAW, W), _t(1.28, 0.38, -6, 4, RDY, B.R_READY, W)]},
		{"len": 1.06, "hit": 0.3, "two": true, "extra_hits": [0.56, 0.78], "extra_radius": 2.2, "keys": [
			_t(0.0, 0.38, -6, 4, RDY, B.R_READY, W), _t(0.18, 0.44, -18, -6, FW, B.R_DRAW, BK), _t(0.3, 0.56, 12, 24, FW, B.R_THRUST, L),
			_t(0.82, 0.58, 10, 26, FW, B.R_THRUST, L), _t(1.06, 0.38, -6, 4, RDY, B.R_READY, W)]},
		{"len": 1.9, "hit": 0.62, "keys": [
			_t(0.0, 0.38, -6, 4, RDY, B.R_READY, W), _t(0.34, 0.3, -6, -12, Vector3(0, 0.9, 0.4), B.R_HIGH, ST), _t(0.56, 0.5, -20, -6, FW, B.R_DRAW, BK),
			_t(0.62, 0.58, 16, 28, FW, B.R_THRUST, L), _t(1.5, 0.46, 6, 10, FW, B.R_READY, W), _t(1.9, 0.38, -6, 4, RDY, B.R_READY, W)]},
	]
