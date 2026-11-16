extends RefCounted
## Raikage no Kote kombosu (ref refs/weapons/raikage_kote_*: A'nın ön kola geçen kalın altın kollukları; Striker: chakra akışını
## Raiton'a çeviren düzenek). Kolluk hem kalkan hem çekiç: vuruşlar yumrukla değil çoğu kez KOLLUKLA iner, her temas şimşek atar.
## Yotsuki tarzından (Lariat / Liger Bomb) ayrı: burada silah kolluğun kendisi.
## 1 Kote Uchi: sol kolluk göğüs önünde yatay, kalkanla ezer.  2 Raiton Tsuki: sağ kolluk geri çekilir, şimşekli düz yumruk.
## 3 Aian Kurō (Iron Claw, kanon A): sağ el hedefin başını kavrar, sıkar, kolluktan şimşek akar.
## 4 Kōsa Tossin: iki kolluk X çaprazlanıp omuzla dalış.  5 Raitsui: iki yumruk başın üstünde birleşir, yere çekiç gibi iner.
## 6 Kote Raihō: kollar yana açılır, kolluklar birbirine çarpar (şimşek kıvılcımı), iki kol birden öne itilip şimşek boşalır.

const S = preload("res://scripts/combat/samehada_anim.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const R_GUARD := {"RightUpperArm": Vector3(-0.35, -0.75, 0.55), "RightLowerArm": Vector3(0.15, 0.75, 0.65)}
const L_GUARD := {"LeftUpperArm": Vector3(0.35, -0.75, 0.55), "LeftLowerArm": Vector3(-0.15, 0.75, 0.65)}
# kolluk kalkanı: ön kol göğüs önünde yatay (kolluk yüzü öne), ezerken öne itilir
const L_BAR0 := {"LeftUpperArm": Vector3(0.55, -0.45, 0.2), "LeftLowerArm": Vector3(-0.85, 0.3, 0.45)}
const L_BAR1 := {"LeftUpperArm": Vector3(0.15, -0.15, 1.0), "LeftLowerArm": Vector3(-0.95, 0.1, 0.3)}
const R_CHAMBER := {"RightUpperArm": Vector3(-0.45, -0.6, -0.7), "RightLowerArm": Vector3(-0.1, 0.3, 0.95)}
const R_PUNCH := {"RightUpperArm": Vector3(-0.05, 0.05, 1), "RightLowerArm": Vector3(0.0, 0.05, 1)}
const L_CHAMBER := {"LeftUpperArm": Vector3(0.45, -0.6, -0.7), "LeftLowerArm": Vector3(0.1, 0.3, 0.95)}
# Iron Claw: kol öne-yukarı, el hedefin başı hizasında
const R_CLAW0 := {"RightUpperArm": Vector3(-0.5, -0.3, -0.4), "RightLowerArm": Vector3(-0.2, 0.6, 0.7)}
const R_CLAW1 := {"RightUpperArm": Vector3(-0.1, 0.35, 0.93), "RightLowerArm": Vector3(0.0, 0.3, 0.95)}
# X çapraz: iki ön kol yüz önünde çaprazlanır
const R_CROSS := {"RightUpperArm": Vector3(-0.35, -0.2, 0.9), "RightLowerArm": Vector3(0.75, 0.55, 0.35)}
const L_CROSS := {"LeftUpperArm": Vector3(0.35, -0.2, 0.9), "LeftLowerArm": Vector3(-0.75, 0.6, 0.3)}
# çift yumruk çekiç
const R_UP := {"RightUpperArm": Vector3(-0.15, 0.95, -0.2), "RightLowerArm": Vector3(0.25, 0.9, -0.3)}
const L_UP := {"LeftUpperArm": Vector3(0.15, 0.95, -0.2), "LeftLowerArm": Vector3(-0.25, 0.9, -0.3)}
const R_DOWN := {"RightUpperArm": Vector3(-0.1, -0.35, 0.93), "RightLowerArm": Vector3(0.15, -0.8, 0.58)}
const L_DOWN := {"LeftUpperArm": Vector3(0.1, -0.35, 0.93), "LeftLowerArm": Vector3(-0.15, -0.8, 0.58)}
# kolluk çarpıştırma: yana açık -> önde kolluklar buluşur -> iki kol öne itilir
const R_OPEN := {"RightUpperArm": Vector3(-0.95, 0.1, -0.25), "RightLowerArm": Vector3(-0.6, 0.6, 0.5)}
const L_OPEN := {"LeftUpperArm": Vector3(0.95, 0.1, -0.25), "LeftLowerArm": Vector3(0.6, 0.6, 0.5)}
const R_CLANG := {"RightUpperArm": Vector3(-0.45, -0.3, 0.84), "RightLowerArm": Vector3(0.7, 0.35, 0.62)}
const L_CLANG := {"LeftUpperArm": Vector3(0.45, -0.3, 0.84), "LeftLowerArm": Vector3(-0.7, 0.35, 0.62)}
const R_PUSH := {"RightUpperArm": Vector3(-0.12, 0.1, 0.99), "RightLowerArm": Vector3(0.05, 0.12, 0.99)}
const L_PUSH := {"LeftUpperArm": Vector3(0.12, 0.1, 0.99), "LeftLowerArm": Vector3(-0.05, 0.12, 0.99)}


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.15, lean, Vector3(0, 0, 1), S._a(r, l), legs)


static func steps() -> Array:
	var W = F.FIGHT
	var BK = F.SHIFT
	var PV = F.PIVOT
	var PL = F.PIVOT_L
	var LO = F.LOW
	var L = S.LEG_LUNGE
	return [
		# 1 Kote Uchi: sol kolluk kalkanı geri toplanır, gövde dönerek öne ezer
		{"len": 0.48, "hit": 0.2, "keys": [
			_t(0.0, 0.45, 0, 10, R_GUARD, L_GUARD, W),
			_t(0.1, 0.52, 28, 4, R_GUARD, L_BAR0, BK),
			_t(0.13, 0.52, 30, 4, R_GUARD, L_BAR0, BK),     # kısa duraklama
			_t(0.2, 0.5, -24, 22, R_GUARD, L_BAR1, PL),
			_t(0.3, 0.48, -20, 18, R_GUARD, L_BAR1, PL),
			_t(0.48, 0.45, 0, 10, R_GUARD, L_GUARD, W),
		]},
		# 2 Raiton Tsuki: sağ kolluk derin geri çekilir, düz yumruk
		{"len": 0.5, "hit": 0.22, "keys": [
			_t(0.0, 0.45, 0, 10, R_GUARD, L_GUARD, W),
			_t(0.11, 0.55, -30, 4, R_CHAMBER, L_GUARD, BK),
			_t(0.15, 0.56, -32, 4, R_CHAMBER, L_GUARD, BK),
			_t(0.22, 0.5, 26, 24, R_PUNCH, L_CHAMBER, PV),
			_t(0.32, 0.48, 22, 20, R_PUNCH, L_CHAMBER, PV),
			_t(0.5, 0.45, 0, 10, R_GUARD, L_GUARD, W),
		]},
		# 3 Aian Kurō: öne adım, el başı kavrar, sıkıp şimşek akıtır
		{"len": 0.7, "hit": 0.26, "keys": [
			_t(0.0, 0.45, 0, 10, R_GUARD, L_GUARD, W),
			_t(0.12, 0.5, -18, 8, R_CLAW0, L_GUARD, BK),
			_t(0.26, 0.42, 16, 16, R_CLAW1, L_GUARD, F.STEPIN),
			_t(0.42, 0.4, 14, 12, R_CLAW1, L_GUARD, F.STEPIN),   # sıkıyor
			_t(0.5, 0.42, 20, 20, R_CLAW1, L_GUARD, L),           # iter
			_t(0.7, 0.45, 0, 10, R_GUARD, L_GUARD, W),
		]},
		# 4 Kōsa Tossin: kolluklar X çapraz, çömelip omuzla dalış
		{"len": 0.56, "hit": 0.26, "keys": [
			_t(0.0, 0.45, 0, 10, R_GUARD, L_GUARD, W),
			_t(0.12, 0.66, 10, 6, R_CROSS, L_CROSS, LO),
			_t(0.16, 0.66, 10, 6, R_CROSS, L_CROSS, LO),
			_t(0.26, 0.5, 18, 34, R_CROSS, L_CROSS, L),
			_t(0.38, 0.5, 16, 30, R_CROSS, L_CROSS, L),
			_t(0.56, 0.45, 0, 10, R_GUARD, L_GUARD, W),
		]},
		# 5 Raitsui: iki yumruk başın üstünde birleşir, yere iner
		{"len": 0.72, "hit": 0.38, "keys": [
			_t(0.0, 0.45, 0, 10, R_GUARD, L_GUARD, W),
			_t(0.16, 0.32, 0, -16, R_UP, L_UP, F.HOP),
			_t(0.26, 0.3, 0, -18, R_UP, L_UP, F.HOP),
			_t(0.38, 0.85, 0, 42, R_DOWN, L_DOWN, LO),
			_t(0.52, 0.82, 0, 38, R_DOWN, L_DOWN, LO),
			_t(0.72, 0.45, 0, 10, R_GUARD, L_GUARD, W),
		]},
		# 6 Kote Raihō: kollar açılır, kolluklar çarpışır (0.3), iki kol öne itilip şimşek boşalır (0.6)
		{"len": 1.0, "hit": 0.6, "keys": [
			_t(0.0, 0.45, 0, 10, R_GUARD, L_GUARD, W),
			_t(0.18, 0.5, 0, -6, R_OPEN, L_OPEN, LO),
			_t(0.3, 0.55, 0, 8, R_CLANG, L_CLANG, LO),
			_t(0.46, 0.58, 0, 4, R_CLANG, L_CLANG, LO),     # şimşek toplanır
			_t(0.6, 0.48, 0, 26, R_PUSH, L_PUSH, L),
			_t(0.76, 0.48, 0, 24, R_PUSH, L_PUSH, L),
			_t(1.0, 0.45, 0, 10, R_GUARD, L_GUARD, W),
		]},
	]
