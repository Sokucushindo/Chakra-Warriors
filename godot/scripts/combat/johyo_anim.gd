extends RefCounted
## Jōhyō (ipli dart; Narutopedia + ref refs/tenten_w/Johyo__Johyo2.png): bambu tüp sap, içinde sarılı uzun ip, ucunda kırmızı
## püsküllü konik metal dart. Kanon (Gaara -> Matsuri, Suna Destek Görevi): "Uçtaki diş saldırmaktan çok rakibi YAKLAŞTIRMAMAK için;
## sonra iple saldıramaz hâle getir." Elde bıçak yok — bütün vuruşlar ipin ucundaki darttan (oyunun fizikli ip/zincir sistemi,
## KeyedCombos._kg_weight). Oyuncu ve düşman aynı kombo.
## 1 Nage: dart düz fırlar, gövdeye dolanır (sersemletir), 2 Mawashi: baş üstünde döndürüp yaklaşanı uzak tutar,
## 3 Shibari: ip rakibe dolanır (bağlar), 4 Hiki: dolayıp sana çeker, 5 Ashi Kake: alçak döndürüp bacaklara (yere serer),
## 6 Tsuri Age (bitiriş): dolayıp havaya savurur

const S = preload("res://scripts/combat/samehada_anim.gd")
const Z = preload("res://scripts/combat/zkunai_anim.gd")

const R_LOW := {"RightUpperArm": Vector3(-0.4, -0.85, 0.3), "RightLowerArm": Vector3(-0.3, -0.75, 0.55)}
const R_UP := {"RightUpperArm": Vector3(-0.2, 0.75, 0.6), "RightLowerArm": Vector3(0.0, 0.95, 0.3)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.2, blade.normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var BK = S.LEG_BACK
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.0, 0.3, 0.95)
	return [
		# 1 Nage: kol geri -> dart düz fırlar, hedefe dolanır -> ip sarılır
		{"len": 1.1, "hit": 0.32, "keys": [
			_t(0.0, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.38, -28, -10, Vector3(0, 0.3, -0.95), Z.R_BACK, Z.L_POINT, BK),
			_t(0.26, 0.4, -32, -12, Vector3(0, 0.3, -0.95), Z.R_BACK, Z.L_POINT, BK),
			_t(0.32, 0.44, 16, 18, Vector3(0, 0.1, 1), Z.R_REACH, Z.L_POINT, L),
			_t(0.66, 0.4, 4, -6, Vector3(0, 0.1, 1), Z.R_PULL, Z.L_HAUL, BK),
			_t(1.1, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		# 2 Mawashi: baş üstünde döndürür — yaklaşan rakibi uzakta tutar
		{"len": 1.15, "hit": 0.22, "keys": [
			_t(0.0, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.34, -16, -6, Vector3(0, 0.95, 0.2), Z.R_OVER, Z.L_WIDE, W),
			_t(0.4, 0.36, 22, -4, Vector3(0, 0.95, 0.2), Z.R_OVER, Z.L_WIDE, CR),
			_t(0.64, 0.38, -24, 2, Vector3(0, 0.95, 0.2), Z.R_OVER, Z.L_WIDE, W),
			_t(0.88, 0.38, 22, 2, Vector3(0, 0.95, 0.2), Z.R_OVER, Z.L_WIDE, CR),
			_t(1.15, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		# 3 Shibari: yandan yay çizerek atış, ip rakibin gövdesine dolanır; iki el ipi gerer
		{"len": 1.0, "hit": 0.3, "keys": [
			_t(0.0, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.14, 0.38, -34, -6, Vector3(-0.8, 0.3, -0.4), Z.R_HIGH, Z.L_POINT, CR),
			_t(0.3, 0.44, 20, 16, Vector3(0, 0.3, 0.95), Z.R_REACH, Z.L_POINT, L),
			_t(0.6, 0.44, 6, -8, Vector3(0, 0.3, 0.95), Z.R_PULL, Z.L_HAUL, BK),
			_t(1.0, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		# 4 Hiki: dolar -> iki kolla kalçaya sert çekiş, rakip sürüklenir
		{"len": 1.15, "hit": 0.3, "keys": [
			_t(0.0, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.4, -30, -12, Vector3(-0.3, 0.75, -0.6), Z.R_HIGH, Z.L_POINT, BK),
			_t(0.3, 0.46, 16, 20, Vector3(0, 0.3, 0.95), Z.R_REACH, Z.L_POINT, L),
			_t(0.6, 0.48, -10, -16, Vector3(0, 0.3, 0.95), Z.R_PULL, Z.L_HAUL, BK),
			_t(0.86, 0.46, -14, -18, Vector3(0, 0.3, 0.95), Z.R_PULL, Z.L_HAUL, BK),
			_t(1.15, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		# 5 Ashi Kake: çömelip alçakta döndürür, dart bacak hizasında
		{"len": 1.1, "hit": 0.26, "keys": [
			_t(0.0, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.7, -30, 16, Vector3(-0.9, -0.2, 0.3), R_LOW, Z.L_WIDE, CR),
			_t(0.42, 0.74, 60, 18, Vector3(-0.9, -0.2, 0.3), R_LOW, Z.L_WIDE, W),
			_t(0.7, 0.74, 150, 18, Vector3(-0.9, -0.2, 0.3), R_LOW, Z.L_WIDE, CR),
			_t(1.1, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
		# 6 Tsuri Age: dolar -> ip yukarı savrulur, rakip havaya kalkar
		{"len": 1.25, "hit": 0.32, "keys": [
			_t(0.0, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
			_t(0.16, 0.4, -24, -10, Vector3(0, 0.3, -0.95), Z.R_BACK, Z.L_POINT, BK),
			_t(0.32, 0.46, 14, 18, Vector3(0, 0.2, 1), Z.R_REACH, Z.L_POINT, L),
			_t(0.66, 0.36, 0, -18, Vector3(0, 0.95, 0.3), R_UP, Z.L_HAUL, BK),
			_t(0.9, 0.34, 0, -20, Vector3(0, 0.95, 0.3), R_UP, Z.L_HAUL, BK),
			_t(1.25, 0.3, 0, 4, RDY, Z.R_READY, Z.L_GUARD, W),
		]},
	]
