extends RefCounted
## Kusari-fundo (鎖分銅, manriki; Narutopedia kullanıcıları: Gōzu, Meizu, Izumo, Kotetsu, Tenten, Obito, Furui; biçim Wikipedia): iki ucunda ağırlık olan kısa zincir,
## ağırlıklar İKİ AVUÇTA, zincir eller arasında sarkar. Bir ucu kırbaç gibi fırlatılır, gergin zincirle darbe karşılanır, dolanır, boğar/atar.
## 1 Fundo Uchi: sağ ağırlık düz çakar, 2 Gyaku Fundo: sol ağırlık, 3 Kusari Uke: eller açılır, gergin zincir darbeyi yakalar,
## 4 Furi Mawashi: baş üstünde çevirme, 5 Karami: ağırlık rakibin çevresine dolanır, bağlar (kanon: Izumo ve Kotetsu zincirle Kakuzu'yu sarar),
## 6 Shime Nage (bitiriş): zincirlenmiş rakip omuz üstünden arkaya çakılır; bağlı değilse iki ağırlık birden iner. Görsel ve mekanik: KusariFundoFX.

const S = preload("res://scripts/combat/samehada_anim.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const R_GUARD := {"RightUpperArm": Vector3(-0.32, -0.72, 0.6), "RightLowerArm": Vector3(0.3, 0.3, 0.9)}
const L_GUARD := {"LeftUpperArm": Vector3(0.32, -0.72, 0.6), "LeftLowerArm": Vector3(-0.3, 0.3, 0.9)}
const R_BACK := {"RightUpperArm": Vector3(-0.62, 0.1, -0.76), "RightLowerArm": Vector3(-0.1, 0.92, -0.2)}     # kulak yanına kurulu
const L_BACK := {"LeftUpperArm": Vector3(0.62, 0.1, -0.76), "LeftLowerArm": Vector3(0.1, 0.92, -0.2)}
const R_FLICK := {"RightUpperArm": Vector3(-0.1, 0.12, 0.99), "RightLowerArm": Vector3(0.0, 0.05, 1)}
const L_FLICK := {"LeftUpperArm": Vector3(0.1, 0.12, 0.99), "LeftLowerArm": Vector3(0.0, 0.05, 1)}
const R_TAUT := {"RightUpperArm": Vector3(-0.72, 0.15, 0.66), "RightLowerArm": Vector3(-0.72, 0.35, 0.6)}     # eller iki yana, zincir yüz önünde gergin
const L_TAUT := {"LeftUpperArm": Vector3(0.72, 0.15, 0.66), "LeftLowerArm": Vector3(0.72, 0.35, 0.6)}
const R_TWIRL := {"RightUpperArm": Vector3(-0.3, 0.9, 0.3), "RightLowerArm": Vector3(0.2, 0.95, 0.2)}         # baş üstünde çevirir
const R_PULL := {"RightUpperArm": Vector3(-0.5, -0.5, -0.7), "RightLowerArm": Vector3(0.0, 0.3, 0.95)}        # zinciri gövdeye çeker
const L_PULL := {"LeftUpperArm": Vector3(0.5, -0.5, -0.7), "LeftLowerArm": Vector3(0.0, 0.3, 0.95)}
const R_OVER := {"RightUpperArm": Vector3(-0.3, 0.86, -0.4), "RightLowerArm": Vector3(0.05, 0.75, -0.65)}     # omuz üstünden arkaya
const L_OVER := {"LeftUpperArm": Vector3(0.3, 0.86, -0.4), "LeftLowerArm": Vector3(-0.05, 0.75, -0.65)}


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, Vector3(0, 0, 1), S._a(r, l), legs)


static func steps() -> Array:
	var W = F.FIGHT
	var BK = F.SHIFT
	var PV = F.PIVOT
	var PL = F.PIVOT_L
	var LO = F.LOW
	var L = S.LEG_LUNGE
	return [
		# 1 Fundo Uchi: sağ el kulak yanında, bilek çırpılır, ağırlık gider ve zincirle döner
		{"len": 0.52, "hit": 0.2, "keys": [
			_t(0.0, 0.44, 8, 6, R_GUARD, L_GUARD, W),
			_t(0.11, 0.5, 26, -4, R_BACK, L_GUARD, BK),
			_t(0.2, 0.48, -18, 18, R_FLICK, L_GUARD, PV),
			_t(0.32, 0.46, -14, 14, R_FLICK, L_GUARD, PV),
			_t(0.52, 0.44, 8, 6, R_GUARD, L_GUARD, W),
		]},
		# 2 Gyaku Fundo: dönen sağ yakalanırken sol çıkar
		{"len": 0.54, "hit": 0.21, "keys": [
			_t(0.0, 0.44, 8, 6, R_GUARD, L_GUARD, W),
			_t(0.11, 0.5, -24, -4, R_GUARD, L_BACK, BK),
			_t(0.21, 0.48, 20, 18, R_GUARD, L_FLICK, PL),
			_t(0.33, 0.46, 16, 14, R_GUARD, L_FLICK, PL),
			_t(0.54, 0.44, 8, 6, R_GUARD, L_GUARD, W),
		]},
		# 3 Kusari Uke: eller birden açılır, zincir yüz önünde çat diye gerilir; kısa bekler
		{"len": 0.72, "hit": 0.42, "keys": [
			_t(0.0, 0.44, 8, 6, R_GUARD, L_GUARD, W),
			_t(0.1, 0.54, 0, 2, R_TAUT, L_TAUT, LO),
			_t(0.38, 0.54, 0, 2, R_TAUT, L_TAUT, LO),
			_t(0.46, 0.48, 0, 18, R_FLICK, L_FLICK, L),
			_t(0.72, 0.44, 8, 6, R_GUARD, L_GUARD, W),
		]},
		# 4 Furi Mawashi: sağ el başın üstünde, sol el zinciri besler; ağırlık çevrede döner
		{"len": 1.02, "hit": 0.3, "extra_hits": [0.52, 0.74], "extra_radius": 3.0, "keys": [
			_t(0.0, 0.44, 8, 6, R_GUARD, L_GUARD, W),
			_t(0.14, 0.4, 16, -4, R_TWIRL, L_GUARD, BK),
			_t(0.42, 0.4, -14, -6, R_TWIRL, L_GUARD, W),
			_t(0.7, 0.4, 14, -6, R_TWIRL, L_GUARD, W),
			_t(0.86, 0.44, 0, 4, R_FLICK, L_GUARD, PV),
			_t(1.02, 0.44, 8, 6, R_GUARD, L_GUARD, W),
		]},
		# 5 Karami: kol yandan savrulur, sol el zinciri gerer; ağırlık hedefin çevresinde dolaşırken iki el gövdeye çeker
		{"len": 1.0, "hit": 0.3, "keys": [
			_t(0.0, 0.44, 8, 6, R_GUARD, L_GUARD, W),
			_t(0.16, 0.5, 34, -2, R_BACK, L_GUARD, BK),
			_t(0.3, 0.48, -16, 18, R_FLICK, L_GUARD, PV),
			_t(0.62, 0.5, -4, 8, R_FLICK, L_PULL, W),
			_t(0.8, 0.56, 10, -12, R_PULL, L_PULL, BK),
			_t(1.0, 0.44, 8, 6, R_GUARD, L_GUARD, W),
		]},
		# 6 Shime Nage: sırtını döner, zincir omuzda, belden öne katlanır: rakip üstünden geçer
		{"len": 1.3, "hit": 0.46, "keys": [
			_t(0.0, 0.44, 8, 6, R_GUARD, L_GUARD, W),
			_t(0.2, 0.62, 40, -4, R_PULL, L_PULL, LO),
			_t(0.42, 0.66, 60, -10, R_OVER, L_OVER, LO),
			_t(0.66, 0.74, 60, 44, R_FLICK, L_FLICK, L),
			_t(0.92, 0.72, 44, 38, R_FLICK, L_FLICK, L),
			_t(1.3, 0.44, 8, 6, R_GUARD, L_GUARD, W),
		]},
	]
