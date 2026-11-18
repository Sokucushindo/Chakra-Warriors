extends RefCounted
## Kyodai Konbō (巨大棍棒, TOPUZ; kanon: Kotetsu Hagane'nin deniz kabuğu topuzu — refs/konbo): ince sargılı sapta dev BAŞ, baştan sap dibine zincir.
## Bütün ağırlık başta: baş bir sarkaç gibi gider, her darbe geri sekip bir sonrakini kurar. Gürzden (Kanabō) farkı: kaldıraç değil sarkaç + zincir.
## 1 Furiko Age: baş arkada aşağı sarkar (durur), alttan yukarı sarkaç, 2 Kaeshi Otoshi: tepede sekip kendi ağırlığıyla düşer (savunma kırar),
## 3 Sazae Guruma: gövde önünde dikey çark, iki iniş, 4 Kusari Nage: baş saptan kopar, zincirle fırlar, geri çekilir,
## 5 Hane Otoshi: başın dikenleri kanat olur, sol el yönetir, tepeden dalar (kanon: uçan biçim), 6 Chimoguri (bitiriş): yere çakılır,
## dikenlerini katlayıp toprağın altından gider, rakibin altından çıkar (kanon: toprak altı biçimi). Görsel ve hasar: KonboFX.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.32, -0.82, 0.46), "RightLowerArm": Vector3(0.2, 0.42, 0.88)}     # baş sağ omuz önünde yukarıda
const R_HANG := {"RightUpperArm": Vector3(-0.38, -0.88, -0.28), "RightLowerArm": Vector3(-0.16, -0.8, -0.56)}  # kol sarkık, baş geride aşağıda
const R_SWING := {"RightUpperArm": Vector3(-0.1, -0.25, 0.96), "RightLowerArm": Vector3(0.02, 0.5, 0.86)}      # sarkaç tepesi, öne-yukarı
const R_TOP := {"RightUpperArm": Vector3(-0.22, 0.88, 0.42), "RightLowerArm": Vector3(-0.02, 0.92, -0.38)}     # baş üstünde, ağırlık geride
const R_FALL := {"RightUpperArm": Vector3(-0.08, -0.42, 0.9), "RightLowerArm": Vector3(0.0, -0.66, 0.75)}      # düşüş sonu
const R_THROW := {"RightUpperArm": Vector3(-0.1, 0.1, 1), "RightLowerArm": Vector3(0.0, 0.1, 1)}               # sap öne uzatılmış (baş uçuyor)
const R_SLAM := {"RightUpperArm": Vector3(-0.08, -0.72, 0.68), "RightLowerArm": Vector3(0.02, -0.9, 0.42)}     # yere çakış
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}           # iki el: IK sapa götürür
const L_CHAIN := {"LeftUpperArm": Vector3(0.7, 0.5, 0.5), "LeftLowerArm": Vector3(0.3, 0.75, 0.6)}             # sol el zinciri yukarıda tutar (Kotetsu pozu)


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.22, 0.82, 0.52)
	return [
		# 1 Furiko Age: baş arkaya-aşağı bırakılır, kol sarkar (ağırlık bekler) -> kalçadan alttan öne-yukarı sarkaç -> baş gövdeyi öne çeker
		{"len": 1.06, "hit": 0.5, "two": true, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
			_t(0.24, 0.6, -24, 18, Vector3(-0.1, -0.74, -0.66), R_HANG, L_ANY, BK),
			_t(0.42, 0.62, -26, 20, Vector3(-0.1, -0.78, -0.62), R_HANG, L_ANY, BK),
			_t(0.5, 0.36, 10, -6, Vector3(0, 0.56, 0.83), R_SWING, L_ANY, L),
			_t(0.72, 0.3, 14, -14, Vector3(0, 0.74, 0.67), R_SWING, L_ANY, L),
			_t(1.06, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
		]},
		# 2 Kaeshi Otoshi: sarkaç tepede sekip başın arkasına geçer (kısa duraksama) -> düz düşer, dizler baş ile birlikte çöker
		{"len": 1.02, "hit": 0.44, "two": true, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
			_t(0.18, 0.26, -4, -20, Vector3(0, 0.72, -0.69), R_TOP, L_ANY, ST),
			_t(0.36, 0.24, -4, -24, Vector3(0, 0.66, -0.75), R_TOP, L_ANY, ST),
			_t(0.44, 0.74, 4, 36, Vector3(0, -0.76, 0.65), R_FALL, L_ANY, L),
			_t(0.7, 0.78, 2, 40, Vector3(0, -0.84, 0.54), R_FALL, L_ANY, L),
			_t(1.02, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
		]},
		# 3 Sazae Guruma: baş gövdenin yanında dikey çember çizer; öne inişte vurur, alttan geçip bir tur daha iner
		{"len": 1.34, "hit": 0.46, "two": true, "extra_hits": [0.92], "extra_radius": 2.3, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
			_t(0.16, 0.5, -16, 8, Vector3(0, -0.7, -0.71), R_HANG, L_ANY, BK),
			_t(0.32, 0.34, -10, -14, Vector3(0, 0.8, -0.6), R_TOP, L_ANY, ST),
			_t(0.46, 0.62, 10, 28, Vector3(0, -0.5, 0.87), R_FALL, L_ANY, L),
			_t(0.62, 0.62, 2, 20, Vector3(0, -0.92, -0.38), R_HANG, L_ANY, W),
			_t(0.78, 0.34, -10, -14, Vector3(0, 0.8, -0.6), R_TOP, L_ANY, ST),
			_t(0.92, 0.66, 12, 30, Vector3(0, -0.56, 0.83), R_FALL, L_ANY, L),
			_t(1.34, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
		]},
		# 4 Kusari Nage: tek el, sap ileri savrulur, baş kopup gider; sol el zinciri yukarı kaldırır, sonra çekip toplar
		{"len": 1.18, "hit": 0.38, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
			_t(0.22, 0.5, -30, -10, Vector3(0.1, 0.5, -0.86), R_TOP, S.L_BACK, BK),
			_t(0.38, 0.46, 24, 22, Vector3(0, 0.12, 1), R_THROW, L_CHAIN, L),
			_t(0.74, 0.44, 16, 12, Vector3(0, 0.15, 1), R_THROW, L_CHAIN, W),
			_t(0.92, 0.48, 2, 4, Vector3(0.1, 0.45, 0.88), R_READY, S.L_BACK, BK),
			_t(1.18, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
		]},
		# 5 Hane Otoshi: baş kanatlanıp kalkar; sol kol rakibi gösterip yönetir (kanonda el işaretiyle yönlendirilir), sağ el sapı geride tutar
		{"len": 1.42, "hit": 0.3, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
			_t(0.16, 0.54, -8, 6, Vector3(0, 0.8, 0.6), R_SWING, S.L_DOWN, W),
			_t(0.3, 0.28, 4, -16, Vector3(0, 0.96, 0.28), R_TOP, S.L_UP, ST),
			_t(0.62, 0.36, -18, -6, Vector3(0, 0.5, 0.86), R_THROW, S.L_FWD, W),
			_t(0.92, 0.4, -18, 4, Vector3(0, 0.3, 0.95), R_THROW, S.L_FWD, W),
			_t(1.42, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
		]},
		# 6 Chimoguri: baş üstünden tüm kiloyla yere; çömelmiş kalır, zincir elde gerilir, sonunda hızlı toplama
		{"len": 1.62, "hit": 0.56, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
			_t(0.26, 0.24, -8, -22, Vector3(0, 0.72, -0.69), R_TOP, L_CHAIN, ST),
			_t(0.46, 0.22, -8, -26, Vector3(0, 0.66, -0.75), R_TOP, L_CHAIN, ST),
			_t(0.56, 0.82, 4, 42, Vector3(0, -0.9, 0.42), R_SLAM, L_CHAIN, L),
			_t(1.08, 0.78, 8, 34, Vector3(0, -0.5, 0.86), R_THROW, L_CHAIN, CR),
			_t(1.3, 0.5, -10, 6, Vector3(0.12, 0.6, 0.79), R_READY, S.L_BACK, BK),
			_t(1.62, 0.42, -6, 4, RDY, R_READY, L_ANY, W),
		]},
	]
