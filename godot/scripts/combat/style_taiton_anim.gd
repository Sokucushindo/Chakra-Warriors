extends RefCounted
## Kan soyu tarzı — Taiton (Tayfun Salınımı, Nowaki). ORTA. Kanon: art arda patlayan güçlü rüzgârlar, dev kasırga, rüzgârlı
## shuriken. Tarz bundan türetildi: avuç itişiyle biçen rüzgâr yayları, dönen tekmeyle beden çevresinde girdap, avuçtan yürüyen
## küçük hortum, yere yakın boşluk halkası; bitiriş hedefin yerinde tayfun gözü (içe çeker, göğe fırlatır). Yakında zayıf.

const C = preload("res://scripts/combat/style_common.gd")
const F = preload("res://scripts/combat/style_legs.gd")


static func steps() -> Array:
	return [
		C.step(0.5, 0.24, C.R_BACK, C.L_GUARD, C.R_PALM, C.L_GUARD, F.SHIFT, F.PIVOT, -24.0, 18.0, 0.4, 10.0),
		C.step(0.5, 0.24, C.R_GUARD, C.L_BACK, C.R_GUARD, C.L_PALM, F.FIGHT, F.PIVOT_L, 24.0, -18.0, 0.4, 10.0),
		{"len": 0.75, "hit": 0.36, "keys": [   # 3 dönen tekme: tam tur (girdap bedenin çevresinde)
			C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.18, 0.42, -90, 0, C.R_SPREAD, C.L_SPREAD, F.SHIFT),
			C.t(0.36, 0.3, -200, -6, C.R_SPREAD, C.L_SPREAD, C.KICK_HIGH_R),
			C.t(0.52, 0.32, -320, -4, C.R_SPREAD, C.L_SPREAD, C.KICK_HIGH_R),
			C.t(0.75, 0.35, -360, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
		C.step(0.7, 0.34, C.R_SEAL, C.L_SEAL, C.R_PALM, C.L_PALM, F.SHIFT, F.STEPIN, 0.0, 0.0, 0.42, 14.0),
		C.step(0.7, 0.32, C.R_SEAL, C.L_SEAL, C.R_SPREAD, C.L_SPREAD, F.FIGHT, F.LOW, 0.0, 0.0, 0.6, 4.0),
		{"len": 1.2, "hit": 0.7, "keys": [   # 6 tayfun gözü: kollar göğe, çevirir, avuçlar hedefe iner
			C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.3, 0.3, -30, -10, C.R_SKY, C.L_SKY, F.FIGHT),
			C.t(0.5, 0.3, 30, -10, C.R_SPREAD, C.L_SPREAD, F.FIGHT),
			C.t(0.7, 0.45, 0, 16, C.R_PALM, C.L_PALM, F.STEPIN),
			C.t(0.95, 0.45, 0, 14, C.R_PALM, C.L_PALM, F.STEPIN),
			C.t(1.2, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
	]
