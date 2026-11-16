extends RefCounted
## Kan soyu tarzı — Meiton (Karanlık Salınımı, Hiruko). YAKIN-ORTA. Kanon: sol avuçtaki işaretten chakra emer (Rasenshuriken'i
## bile yutar) ve geri salar. Tarz bundan türetildi: işaretli avuç darbeleri chakra emer, kara bağ hedefi dibine çeker, avuçtan
## emen kara küre, emme duruşu; bitiriş biriken chakrayı avuçtan dalga olarak salmak (ne kadar emdiysen o kadar güçlü).

const C = preload("res://scripts/combat/style_common.gd")
const F = preload("res://scripts/combat/style_legs.gd")


static func steps() -> Array:
	return [
		C.step(0.5, 0.24, C.R_GUARD, C.L_COCK, C.R_GUARD, C.L_PALM, F.SHIFT, F.PIVOT_L, 20.0, -18.0, 0.4, 12.0),
		C.step(0.5, 0.24, C.R_COCK, C.L_GUARD, C.R_PALM, C.L_GUARD, F.FIGHT, F.PIVOT, -20.0, 18.0, 0.4, 12.0),
		C.step(0.65, 0.3, C.R_GUARD, C.L_REACH, C.R_GUARD, C.L_BACK, F.STEPIN, F.SHIFT, 10.0, -20.0, 0.42, -6.0),
		C.step(0.6, 0.28, C.R_GUARD, C.L_BACK, C.R_GUARD, C.L_REACH, F.SHIFT, F.STEPIN, 20.0, -10.0, 0.42, 12.0),
		C.step(0.75, 0.36, C.R_SEAL, C.L_SEAL, C.R_SPREAD, C.L_REACH, F.FIGHT, F.LOW, 0.0, -10.0, 0.6, 2.0),
		{"len": 1.15, "hit": 0.66, "keys": [   # 6 salma: sol avuç göğse çekilir (chakra toplanır) -> işaret öne patlar
			C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.3, 0.5, 20, -12, C.R_GUARD, C.L_COCK, F.SHIFT),
			C.t(0.52, 0.52, 25, -14, C.R_GUARD, C.L_COCK, F.SHIFT),
			C.t(0.66, 0.42, -20, 18, C.R_BACK, C.L_PALM, F.STEPIN),
			C.t(0.92, 0.42, -18, 14, C.R_BACK, C.L_PALM, F.STEPIN),
			C.t(1.15, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
	]
