extends RefCounted
## Tekkō kombosu: iki elde demir yumruk kemeri; kısa, sert, gövdeye yakın dövüş. KANON ZAYIF: wiki yalnız Tenten'i kullanıcı olarak yazar,
## biçim ve hareket gerçek Okinawa tekkō kullanımından. 1 Jun-zuki, 2 Gyaku-zuki, 3 Kagi-zuki, 4 Age-zuki (kaldırır), 5 Tettsui (çekiç yumruk, ezer),
## 6 Morote-zuki (iki yumruk birden, ağırlıkla).

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_G := {"RightUpperArm": Vector3(-0.25, -0.75, 0.6), "RightLowerArm": Vector3(0.15, 0.75, 0.64)}
const L_G := {"LeftUpperArm": Vector3(0.25, -0.75, 0.6), "LeftLowerArm": Vector3(-0.15, 0.75, 0.64)}
const R_P := {"RightUpperArm": Vector3(-0.05, 0.1, 1), "RightLowerArm": Vector3(0.0, 0.08, 1)}
const L_P := {"LeftUpperArm": Vector3(0.05, 0.1, 1), "LeftLowerArm": Vector3(0.0, 0.08, 1)}
const R_C := {"RightUpperArm": Vector3(-0.3, -0.7, -0.6), "RightLowerArm": Vector3(-0.05, 0.4, 0.92)}
const L_C := {"LeftUpperArm": Vector3(0.3, -0.7, -0.6), "LeftLowerArm": Vector3(0.05, 0.4, 0.92)}
const R_H0 := {"RightUpperArm": Vector3(-0.95, 0.0, 0.2), "RightLowerArm": Vector3(0.3, 0.05, 0.95)}
const R_H1 := {"RightUpperArm": Vector3(0.1, 0.05, 0.99), "RightLowerArm": Vector3(0.95, 0.05, 0.25)}
const L_U0 := {"LeftUpperArm": Vector3(0.3, -0.9, 0.2), "LeftLowerArm": Vector3(0.0, -0.2, 0.98)}
const L_U1 := {"LeftUpperArm": Vector3(0.1, 0.3, 0.95), "LeftLowerArm": Vector3(0.0, 0.98, 0.2)}
const R_T0 := {"RightUpperArm": Vector3(-0.4, 0.9, 0.1), "RightLowerArm": Vector3(0.1, 1, -0.05)}
const R_T1 := {"RightUpperArm": Vector3(-0.1, -0.35, 0.93), "RightLowerArm": Vector3(0.15, -0.8, 0.58)}


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.4, lean * 1.3, Vector3(0, 0.2, 1).normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	return [
		{"len": 0.46, "hit": 0.15, "keys": [_t(0.0, 0.42, 0, 6, R_G, L_G, W), _t(0.08, 0.44, -18, 2, R_C, L_G, BK), _t(0.15, 0.48, 20, 12, R_P, L_G, L), _t(0.46, 0.42, 0, 6, R_G, L_G, W)]},
		{"len": 0.46, "hit": 0.15, "keys": [_t(0.0, 0.42, 10, 6, R_G, L_G, W), _t(0.08, 0.44, 18, 2, R_G, L_C, BK), _t(0.15, 0.48, -22, 12, R_G, L_P, LL), _t(0.46, 0.42, 0, 6, R_G, L_G, W)]},
		{"len": 0.58, "hit": 0.24, "keys": [_t(0.0, 0.42, -6, 6, R_G, L_G, W), _t(0.15, 0.46, -30, 4, R_H0, L_G, BK), _t(0.24, 0.5, 30, 14, R_H1, L_G, L), _t(0.58, 0.42, 0, 6, R_G, L_G, W)]},
		{"len": 0.64, "hit": 0.26, "keys": [_t(0.0, 0.42, 10, 6, R_G, L_G, W), _t(0.17, 0.62, 22, 10, R_G, L_U0, BK), _t(0.26, 0.38, -24, -6, R_G, L_U1, LL), _t(0.64, 0.42, 0, 6, R_G, L_G, W)]},
		{"len": 0.74, "hit": 0.34, "keys": [_t(0.0, 0.42, 0, 6, R_G, L_G, W), _t(0.2, 0.36, -18, -10, R_T0, L_G, ST), _t(0.28, 0.36, -18, -11, R_T0, L_G, ST), _t(0.34, 0.6, 14, 26, R_T1, L_G, L), _t(0.74, 0.42, 0, 6, R_G, L_G, W)]},
		{"len": 1.0, "hit": 0.52, "keys": [_t(0.0, 0.42, 0, 6, R_G, L_G, W), _t(0.3, 0.56, 0, -8, R_C, L_C, BK), _t(0.44, 0.58, 0, -10, R_C, L_C, BK), _t(0.52, 0.52, 0, 20, R_P, L_P, L), _t(0.72, 0.5, 0, 16, R_P, L_P, L), _t(1.0, 0.42, 0, 6, R_G, L_G, W)]},
	]
