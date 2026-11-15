extends RefCounted
## Kan soyu tarzı — Kōton (Çelik Salınımı). YAKIN. Kanonda Kōton kullanıcıları (Metoro Konjiki, Hiruko) çeliği top, kalkan,
## beden ve silah olarak döver; tarz bundan türetildi: çelikle kaplanan ağır yumruklar, ön koldan dövülen çelik kılıç,
## yerden çelik mızraklar, çelik beden omuz hücumu; bitiriş yumruk çelik balyoza dönüp yere iner. Ağır ve biraz yavaş.

const C = preload("res://scripts/combat/style_common.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const L_HOOK := {"LeftUpperArm": Vector3(0.45, 0.15, 0.88), "LeftLowerArm": Vector3(-0.85, 0.1, 0.5)}


static func steps() -> Array:
	return [
		C.step(0.5, 0.24, C.R_COCK, C.L_GUARD, C.R_PUNCH, C.L_GUARD, F.SHIFT, F.PIVOT, -26.0, 24.0, 0.42, 14.0),
		C.step(0.55, 0.26, C.R_GUARD, C.L_COCK, C.R_GUARD, L_HOOK, F.FIGHT, F.PIVOT_L, 30.0, -36.0, 0.44, 12.0),
		C.step(0.7, 0.32, C.R_SWEEP_IN, C.L_GUARD, C.R_SWEEP_OUT, C.L_GUARD, F.SHIFT, F.PIVOT, 40.0, -50.0, 0.45, 8.0),
		C.step(0.65, 0.32, C.R_HIGH, C.L_GUARD, C.R_GROUND, C.L_GUARD, F.SHIFT, F.LOW, -10.0, 6.0, 0.62, 30.0),
		C.step(0.65, 0.3, C.R_GUARD, C.L_GUARD, C.R_GUARD, C.L_GUARD, F.SHIFT, F.STEPIN, -40.0, -55.0, 0.5, 22.0),
		{"len": 1.15, "hit": 0.62, "keys": [   # 6 çelik balyoz: kol göğe kalkar (yumruk ağırlaşır) -> tüm ağırlıkla yere iner
			C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.3, 0.3, -10, -14, C.R_SKY, C.L_GUARD, F.SHIFT),
			C.t(0.5, 0.32, -10, -18, C.R_SKY, C.L_GUARD, F.SHIFT),
			C.t(0.62, 0.7, 10, 36, C.R_GROUND, C.L_BACK, F.LOW),
			C.t(0.9, 0.65, 8, 30, C.R_GROUND, C.L_BACK, F.LOW),
			C.t(1.15, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
	]
