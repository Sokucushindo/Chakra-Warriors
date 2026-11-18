extends RefCounted
## Shichiseiken (Altı Yolun Bilgesi hazinesi; ref refs/kingin/The_Shichiseiken.png, Rikudo_Sennin_no_Hogu.png): Kinkaku tek elle,
## uzun sapından tutup geniş yassı ağzı ağır ağır savurur. Ağır silah ritmi: geri çek -> dur -> hızlı vur -> ağırlıkla devam -> yavaş topla.
## Söz ruhu çekilmiş (Kōkinjō) hedefe değen her kesik onu LANETLER (KeyedCombos.on_strike -> KinginFX.curse_hit).
## 1 Yoko Nagi: sağdan sola geniş yatay, 2 Kaeshi: geri dönüş yatayı, 3 Uchi Oroshi: baş üstünden yassı ağızla ezme (yere serer),
## 4 Tsuki: sap ucuyla uzun itiş, 5 Senkai: tam tur süpürme, 6 Noroi (bitiriş): ağız göğe kalkar «Lanet!» -> dik iniş

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.3, -0.75, 0.55), "RightLowerArm": Vector3(0.0, 0.3, 0.95)}       # ağız dik, önde
const R_BACK_R := {"RightUpperArm": Vector3(-0.85, -0.2, -0.45), "RightLowerArm": Vector3(-0.6, 0.2, -0.75)}     # sağ arkaya kurulu
const R_END_L := {"RightUpperArm": Vector3(0.35, -0.2, 0.9), "RightLowerArm": Vector3(0.9, -0.1, 0.4)}           # sola savrulmuş
const R_START_L := {"RightUpperArm": Vector3(0.3, 0.1, 0.92), "RightLowerArm": Vector3(0.85, 0.3, -0.2)}         # sol omuz önünde kurulu
const R_END_R := {"RightUpperArm": Vector3(-0.95, -0.1, 0.25), "RightLowerArm": Vector3(-0.85, -0.2, 0.45)}
const R_OVER := {"RightUpperArm": Vector3(-0.25, 0.95, -0.15), "RightLowerArm": Vector3(-0.05, 0.85, -0.5)}
const R_SLAM := {"RightUpperArm": Vector3(-0.15, -0.35, 0.92), "RightLowerArm": Vector3(0.0, -0.6, 0.8)}
const R_CHAMBER := {"RightUpperArm": Vector3(-0.35, -0.55, -0.75), "RightLowerArm": Vector3(-0.05, 0.0, 1)}
const R_STAB := {"RightUpperArm": Vector3(-0.05, -0.02, 1), "RightLowerArm": Vector3(0.0, 0.0, 1)}
const R_WIDE := {"RightUpperArm": Vector3(-0.98, 0.0, 0.15), "RightLowerArm": Vector3(-0.95, 0.05, 0.3)}
const R_SKY := {"RightUpperArm": Vector3(-0.2, 0.97, 0.05), "RightLowerArm": Vector3(-0.05, 1.0, 0.05)}
const L_GUARD := {"LeftUpperArm": Vector3(0.35, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.3, 0.95)}
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const L_OUT := {"LeftUpperArm": Vector3(0.95, -0.2, 0.2), "LeftLowerArm": Vector3(0.9, -0.1, 0.4)}
const L_SIGN := {"LeftUpperArm": Vector3(0.2, -0.5, 0.85), "LeftLowerArm": Vector3(-0.55, 0.75, 0.35)}             # tek el mühür (Lanet!)


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.35, lean * 1.25, blade.normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.0, 0.95, 0.3)
	return [
		# 1 Yoko Nagi: sağ arkaya kurulur, durur -> sola geniş yatay, ağırlıkla devam
		{"len": 0.85, "hit": 0.4, "keys": [
			_t(0.0, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
			_t(0.18, 0.44, 30, -8, Vector3(-0.9, 0.1, -0.4), R_BACK_R, L_OUT, BK),
			_t(0.32, 0.44, 32, -9, Vector3(-0.9, 0.1, -0.4), R_BACK_R, L_OUT, BK),
			_t(0.4, 0.5, -28, 16, Vector3(0.95, 0.05, 0.3), R_END_L, L_BACK, L),
			_t(0.56, 0.5, -36, 14, Vector3(0.95, 0.0, 0.2), R_END_L, L_BACK, L),
			_t(0.85, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
		]},
		# 2 Kaeshi: sol omuzdan geri dönüş yatayı sağa
		{"len": 0.8, "hit": 0.36, "keys": [
			_t(0.0, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
			_t(0.16, 0.44, -26, -4, Vector3(0.9, 0.2, -0.3), R_START_L, L_GUARD, CR),
			_t(0.28, 0.44, -28, -5, Vector3(0.9, 0.2, -0.3), R_START_L, L_GUARD, CR),
			_t(0.36, 0.5, 26, 14, Vector3(-0.95, 0.0, 0.3), R_END_R, L_OUT, ST),
			_t(0.52, 0.48, 32, 12, Vector3(-0.95, 0.0, 0.25), R_END_R, L_OUT, W),
			_t(0.8, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
		]},
		# 3 Uchi Oroshi: baş üstüne kalkar, uzun bekleyiş -> yassı ağızla ezme, ağız yerde bir an kalır
		{"len": 1.05, "hit": 0.56, "keys": [
			_t(0.0, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
			_t(0.22, 0.32, 0, -14, Vector3(0, 0.5, -0.85), R_OVER, L_OUT, W),
			_t(0.46, 0.3, 0, -16, Vector3(0, 0.45, -0.9), R_OVER, L_OUT, W),
			_t(0.56, 0.62, 0, 32, Vector3(0, -0.7, 0.7), R_SLAM, L_BACK, L),
			_t(0.8, 0.6, 0, 28, Vector3(0, -0.75, 0.65), R_SLAM, L_BACK, L),
			_t(1.05, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
		]},
		# 4 Tsuki: sap geride -> uzun adımla sap ucu ileri (itiş)
		{"len": 0.75, "hit": 0.32, "keys": [
			_t(0.0, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
			_t(0.16, 0.44, -18, -6, Vector3(0, 0.05, 1), R_CHAMBER, L_OUT, BK),
			_t(0.24, 0.44, -20, -8, Vector3(0, 0.05, 1), R_CHAMBER, L_OUT, BK),
			_t(0.32, 0.54, 16, 24, Vector3(0, 0.0, 1), R_STAB, L_BACK, L),
			_t(0.5, 0.52, 14, 20, Vector3(0, 0.0, 1), R_STAB, L_BACK, L),
			_t(0.75, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
		]},
		# 5 Senkai: kol açık tam tur süpürme
		{"len": 1.0, "hit": 0.38, "extra_hits": [0.62], "extra_radius": 2.6, "keys": [
			_t(0.0, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
			_t(0.16, 0.46, -40, -6, Vector3(-0.9, 0.1, 0.3), R_WIDE, L_OUT, CR),
			_t(0.38, 0.5, 130, 8, Vector3(-0.9, 0.1, 0.3), R_WIDE, L_OUT, W),
			_t(0.6, 0.5, 260, 8, Vector3(-0.9, 0.1, 0.3), R_WIDE, L_OUT, CR),
			_t(0.8, 0.48, 360, 8, Vector3(-0.9, 0.1, 0.3), R_WIDE, L_OUT, W),
			_t(1.0, 0.38, 360, 4, RDY, R_READY, L_GUARD, W),
		]},
		# 6 Noroi: ağız göğe, sol el tek el mühür (bekleyiş) -> dik iniş
		{"len": 1.4, "hit": 0.86, "keys": [
			_t(0.0, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
			_t(0.26, 0.3, 0, -12, Vector3(0, 1, 0.05), R_SKY, L_SIGN, W),
			_t(0.76, 0.3, 0, -14, Vector3(0, 1, 0.05), R_SKY, L_SIGN, W),
			_t(0.86, 0.6, 0, 30, Vector3(0, -0.55, 0.83), R_SLAM, L_BACK, LL),
			_t(1.1, 0.58, 0, 26, Vector3(0, -0.55, 0.83), R_SLAM, L_BACK, LL),
			_t(1.4, 0.38, 0, 4, RDY, R_READY, L_GUARD, W),
		]},
	]
