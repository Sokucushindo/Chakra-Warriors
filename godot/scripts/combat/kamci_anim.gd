extends RefCounted
## Kamçı (Tenten'in cephaneliği — kanonda kısa anlar; hareketler silahın kendi fiziğinden): deri saplı uzun örgü kamçı, ucu düğüm
## (oyunun fizikli ip sistemi; uç KeyedCombos._kg_weight ile yönlenir). Kamçı kolun tamamıyla geri kurulur, bilek ileri çakar,
## uç gecikip şaklar. 1 Ue Uchi: baş üstünden şaklatma, 2 Yoko Muchi: yandan savurup çevreyi biçer, 3 Kaeshi: ters şaklama,
## 4 Makitsuki: kamçı rakibe dolanır (bağlar), 5 Ashi Muchi: alçak savuruş (yere serer), 6 Hiki Taoshi (bitiriş): dolar, sert çeker

const S = preload("res://scripts/combat/samehada_anim.gd")
const Z = preload("res://scripts/combat/zkunai_anim.gd")

const R_LOW := {"RightUpperArm": Vector3(-0.4, -0.85, 0.3), "RightLowerArm": Vector3(-0.3, -0.75, 0.55)}
const R_CRACK := {"RightUpperArm": Vector3(-0.1, 0.2, 0.97), "RightLowerArm": Vector3(0.0, -0.25, 0.97)}   # kol önde, bilek aşağı çakmış


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.2, blade.normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var BK = S.LEG_BACK
	var CR = S.LEG_CROSS
	var ST = S.LEG_STEP
	var RDY = Vector3(0.0, -0.3, 0.95)
	return [
		{"len": 0.9, "hit": 0.3, "keys": [
			_t(0.0, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.34, -10, -14, Vector3(0, 0.6, -0.8), Z.R_HIGH, Z.L_POINT, BK),
			_t(0.24, 0.34, -12, -16, Vector3(0, 0.6, -0.8), Z.R_HIGH, Z.L_POINT, BK),
			_t(0.3, 0.46, 10, 18, Vector3(0, -0.5, 0.85), R_CRACK, Z.L_GUARD, L),
			_t(0.5, 0.44, 8, 14, Vector3(0, -0.5, 0.85), R_CRACK, Z.L_GUARD, L),
			_t(0.9, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		{"len": 1.0, "hit": 0.24, "keys": [
			_t(0.0, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.14, 0.38, 30, -4, Vector3(-0.9, 0.2, -0.3), Z.R_BACK, Z.L_WIDE, CR),
			_t(0.36, 0.42, -40, 8, Vector3(0.9, 0.0, 0.3), Z.R_SLASH, Z.L_WIDE, W),
			_t(0.6, 0.4, -50, 6, Vector3(0.9, 0.0, 0.3), Z.R_SLASH, Z.L_WIDE, W),
			_t(1.0, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		{"len": 0.85, "hit": 0.28, "keys": [
			_t(0.0, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.14, 0.36, -24, -6, Vector3(0.8, 0.4, -0.3), Z.R_SLASH, Z.L_POINT, ST),
			_t(0.28, 0.44, 22, 14, Vector3(0, -0.4, 0.9), R_CRACK, Z.L_GUARD, L),
			_t(0.46, 0.42, 20, 10, Vector3(0, -0.4, 0.9), R_CRACK, Z.L_GUARD, L),
			_t(0.85, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		{"len": 1.05, "hit": 0.3, "keys": [
			_t(0.0, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.38, -30, -10, Vector3(-0.3, 0.75, -0.6), Z.R_HIGH, Z.L_POINT, BK),
			_t(0.3, 0.44, 16, 18, Vector3(0, 0.3, 0.95), Z.R_REACH, Z.L_POINT, L),
			_t(0.62, 0.44, -6, -10, Vector3(0, 0.3, 0.95), Z.R_PULL, Z.L_HAUL, BK),
			_t(1.05, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		{"len": 1.0, "hit": 0.26, "keys": [
			_t(0.0, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.66, -30, 16, Vector3(-0.9, -0.2, 0.3), R_LOW, Z.L_WIDE, CR),
			_t(0.4, 0.7, 50, 18, Vector3(-0.9, -0.2, 0.3), R_LOW, Z.L_WIDE, W),
			_t(0.64, 0.7, 120, 18, Vector3(-0.9, -0.2, 0.3), R_LOW, Z.L_WIDE, CR),
			_t(1.0, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		{"len": 1.2, "hit": 0.3, "keys": [
			_t(0.0, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.38, -26, -10, Vector3(0, 0.3, -0.95), Z.R_BACK, Z.L_POINT, BK),
			_t(0.3, 0.46, 14, 18, Vector3(0, 0.2, 1), Z.R_REACH, Z.L_POINT, L),
			_t(0.62, 0.5, -10, -18, Vector3(0, 0.3, 0.95), Z.R_PULL, Z.L_HAUL, BK),
			_t(0.86, 0.5, -16, -20, Vector3(0, 0.3, 0.95), Z.R_PULL, Z.L_HAUL, BK),
			_t(1.2, 0.32, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
	]
