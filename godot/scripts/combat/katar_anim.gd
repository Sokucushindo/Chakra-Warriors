extends RefCounted
## Katāru (katar, H kabzalı yumruk hançeri; Narutopedia: Tenten, Anko, Sasuke, Kankurō, Ibiki'nin "hançer" kaydı; biçim ve kullanım gerçek dünyadan — kanon görseli yok): İKİ EL.
## Ağız kolun doğrultusunda: temel saldırı yumrukla aynı düz itiş, bütün kilo arkasında; adı "kalkan yaran"dır. Muşta bıçağının boks kesiklerinden, pençenin yırtışından ayrı: DELER.
## 1 Oi Tsuki: sağ düz delme, 2 Gyaku Tsuki: kalça dönüp sol delme, 3 Ryō Zuki: iki ağız birden kaburgaya, zırh ve savunma yarar,
## 4 Ura Giri: tam tur, ağzın yan kenarıyla ters kesik, 5 Kuguri Tsuki: altından girip yukarı delme (kaldırır),
## 6 Tōshi (bitiriş): iki yumruk önde, bütün gövdeyle rakibin içinden geçer. Görsel, kanama, geçiş: KatarFX.

const S = preload("res://scripts/combat/samehada_anim.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const R_GUARD := {"RightUpperArm": Vector3(-0.3, -0.72, 0.62), "RightLowerArm": Vector3(0.22, 0.28, 0.93)}
const L_GUARD := {"LeftUpperArm": Vector3(0.3, -0.72, 0.62), "LeftLowerArm": Vector3(-0.22, 0.28, 0.93)}
const R_COCK := {"RightUpperArm": Vector3(-0.42, -0.62, -0.66), "RightLowerArm": Vector3(-0.04, 0.05, 1)}     # yumruk kalçada, ağız önde
const L_COCK := {"LeftUpperArm": Vector3(0.42, -0.62, -0.66), "LeftLowerArm": Vector3(0.04, 0.05, 1)}
const R_FWD := {"RightUpperArm": Vector3(-0.04, 0.02, 1), "RightLowerArm": Vector3(0.0, 0.02, 1)}
const L_FWD := {"LeftUpperArm": Vector3(0.04, 0.02, 1), "LeftLowerArm": Vector3(0.0, 0.02, 1)}
const R_RIB := {"RightUpperArm": Vector3(-0.3, -0.38, 0.87), "RightLowerArm": Vector3(0.3, -0.14, 0.94)}      # içe, kaburga hizası
const L_RIB := {"LeftUpperArm": Vector3(0.3, -0.38, 0.87), "LeftLowerArm": Vector3(-0.3, -0.14, 0.94)}
const R_WRAP := {"RightUpperArm": Vector3(0.3, -0.25, 0.92), "RightLowerArm": Vector3(0.92, 0.05, 0.38)}      # kol göğse sarılı (ters kesik kurulumu)
const R_OUT := {"RightUpperArm": Vector3(-0.98, 0.02, 0.2), "RightLowerArm": Vector3(-0.96, 0.05, 0.25)}      # yana açık, ağız dışa
const R_LOW := {"RightUpperArm": Vector3(-0.2, -0.92, 0.32), "RightLowerArm": Vector3(0.05, -0.2, 0.98)}
const R_UP := {"RightUpperArm": Vector3(-0.1, 0.42, 0.9), "RightLowerArm": Vector3(0.0, 0.95, 0.3)}           # yukarı delme


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, Vector3(0, 0, 1), S._a(r, l), legs)


static func steps() -> Array:
	var W = F.FIGHT
	var BK = F.SHIFT
	var PV = F.PIVOT
	var PL = F.PIVOT_L
	var LO = F.LOW
	var L = S.LEG_LUNGE
	var ML = S.mirror(S.LEG_LUNGE)
	var CR = S.LEG_CROSS
	return [
		# 1 Oi Tsuki: yumruk kalçaya çekilir -> arka ayak iter, kol tam kilitlenir
		{"len": 0.42, "hit": 0.17, "keys": [
			_t(0.0, 0.46, 10, 8, R_GUARD, L_GUARD, W),
			_t(0.09, 0.52, 26, 2, R_COCK, L_GUARD, BK),
			_t(0.17, 0.5, -22, 22, R_FWD, L_COCK, PV),
			_t(0.26, 0.48, -18, 18, R_FWD, L_COCK, PV),
			_t(0.42, 0.46, 10, 8, R_GUARD, L_GUARD, W),
		]},
		# 2 Gyaku Tsuki: sağ geri gelirken kalça ters döner, sol kilitlenir
		{"len": 0.44, "hit": 0.18, "keys": [
			_t(0.0, 0.46, 10, 8, R_GUARD, L_GUARD, W),
			_t(0.09, 0.52, -24, 2, R_GUARD, L_COCK, BK),
			_t(0.18, 0.5, 24, 22, R_COCK, L_FWD, PL),
			_t(0.28, 0.48, 20, 18, R_COCK, L_FWD, PL),
			_t(0.44, 0.46, 10, 8, R_GUARD, L_GUARD, W),
		]},
		# 3 Ryō Zuki: iki yumruk birlikte geri, dizler kırılır -> iki ağız içe doğru kaburgalara girer
		{"len": 0.66, "hit": 0.3, "keys": [
			_t(0.0, 0.46, 10, 8, R_GUARD, L_GUARD, W),
			_t(0.18, 0.66, 0, -6, R_COCK, L_COCK, LO),
			_t(0.24, 0.68, 0, -8, R_COCK, L_COCK, LO),
			_t(0.3, 0.58, 0, 26, R_RIB, L_RIB, L),
			_t(0.44, 0.56, 0, 22, R_RIB, L_RIB, L),
			_t(0.66, 0.46, 10, 8, R_GUARD, L_GUARD, W),
		]},
		# 4 Ura Giri: sağ kol göğse sarılır, gövde tam tur; kol açılırken ağzın kenarı yatay geçer
		{"len": 0.66, "hit": 0.32, "keys": [
			_t(0.0, 0.46, 10, 8, R_GUARD, L_GUARD, W),
			_t(0.12, 0.5, 40, 6, R_WRAP, L_GUARD, CR),
			_t(0.22, 0.48, 150, 8, R_WRAP, L_GUARD, PV),
			_t(0.32, 0.5, 270, 12, R_OUT, L_COCK, PL),
			_t(0.44, 0.5, 350, 10, R_OUT, L_COCK, W),
			_t(0.66, 0.46, 370, 8, R_GUARD, L_GUARD, W),
		]},
		# 5 Kuguri Tsuki: gövde rakibin kolunun altına çöker -> bacaklarla kalkarken dik delme
		{"len": 0.7, "hit": 0.32, "keys": [
			_t(0.0, 0.46, 10, 8, R_GUARD, L_GUARD, W),
			_t(0.18, 0.84, -14, 30, R_LOW, L_GUARD, ML),
			_t(0.26, 0.86, -16, 32, R_LOW, L_GUARD, ML),
			_t(0.32, 0.3, 8, -14, R_UP, L_COCK, L),
			_t(0.46, 0.24, 10, -18, R_UP, L_COCK, L),
			_t(0.7, 0.46, 10, 8, R_GUARD, L_GUARD, W),
		]},
		# 6 Tōshi: iki yumruk kalçada, ağırlık en arkada, duraksar -> iki kol kilitli düz koşu; arkada ayaklar kayarak durur
		{"len": 1.12, "hit": 0.42, "keys": [
			_t(0.0, 0.46, 10, 8, R_GUARD, L_GUARD, W),
			_t(0.22, 0.7, 0, -10, R_COCK, L_COCK, BK),
			_t(0.36, 0.72, 0, -14, R_COCK, L_COCK, BK),
			_t(0.42, 0.56, 0, 36, R_FWD, L_FWD, L),
			_t(0.62, 0.58, 0, 34, R_FWD, L_FWD, L),
			_t(0.8, 0.62, 0, 12, R_RIB, L_RIB, LO),
			_t(1.12, 0.46, 10, 8, R_GUARD, L_GUARD, W),
		]},
	]
