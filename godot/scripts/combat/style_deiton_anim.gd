extends RefCounted
## Kan soyu tarzı — Deiton (Çamur Salınımı, Ameyuki). ORTA. Kanon: su ve toprak tek chakrada çamura döner; bırakılan çamur
## zamanla kurur, kile döner. Tarz bundan türetildi: avuçtan çamur topağı (yavaşlatır), çamur şaplağı, yerde sürükleyen çamur
## akıntısı, hedefin dibinden çamur elleri, sertleşen topak; bitiriş çamur seli bir an sonra kile dönüp kilitler ve ezer.

const C = preload("res://scripts/combat/style_common.gd")
const F = preload("res://scripts/combat/style_legs.gd")


static func steps() -> Array:
	return [
		C.step(0.5, 0.24, C.R_THROW_BACK, C.L_GUARD, C.R_THROW, C.L_GUARD, F.SHIFT, F.PIVOT, -20.0, 14.0, 0.4, 10.0),
		C.step(0.5, 0.24, C.R_SWEEP_IN, C.L_GUARD, C.R_SWEEP_OUT, C.L_GUARD, F.FIGHT, F.PIVOT, 30.0, -40.0, 0.42, 8.0),
		C.step(0.7, 0.34, C.R_HIGH, C.L_HIGH, C.R_GROUND, C.L_GROUND, F.SHIFT, F.LOW, 0.0, 0.0, 0.65, 30.0),
		C.step(0.65, 0.3, C.R_SEAL, C.L_SEAL, C.R_GROUND, C.L_GUARD, F.FIGHT, F.LOW, 0.0, 6.0, 0.6, 22.0),
		C.step(0.55, 0.26, C.R_THROW_BACK, C.L_GUARD, C.R_THROW, C.L_GUARD, F.SHIFT, F.PIVOT, -20.0, 14.0, 0.4, 10.0),
		{"len": 1.2, "hit": 0.66, "keys": [   # 6 çamur seli: iki el yere, sonra avuçlar kalkar (çamur kile döner)
			C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.3, 0.6, 0, 24, C.R_GROUND, C.L_GROUND, F.LOW),
			C.t(0.66, 0.62, 0, 26, C.R_GROUND, C.L_GROUND, F.LOW),
			C.t(0.9, 0.4, 0, 6, C.R_SKY, C.L_SKY, F.FIGHT),
			C.t(1.2, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
	]
