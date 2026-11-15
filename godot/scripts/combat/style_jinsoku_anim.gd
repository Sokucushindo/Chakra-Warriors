extends RefCounted
## Kan soyu tarzı — Jinton / Hız Salınımı (迅遁, Hiruko). YAKIN. Kanon: yalnız bir bulanıklık olacak hızda hareket; rakip yeterince
## hızlı değilse taijutsu etkisiz kalır. Tarz bundan türetildi: her vuruşta bulanık izle bir anda rakibin dibine, kısa hızlı
## sağ-sol, art arda dört yumruk, arkaya geçip dirsek, göğe tekme; bitiriş havadaki rakibin üstünde belirip topuk inişi. Hafif, en hızlı tarz.

const C = preload("res://scripts/combat/style_common.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const L_HOOK := {"LeftUpperArm": Vector3(0.45, 0.15, 0.88), "LeftLowerArm": Vector3(-0.85, 0.1, 0.5)}
const R_ELBOW := {"RightUpperArm": Vector3(-0.3, -0.2, -0.93), "RightLowerArm": Vector3(0.2, 0.3, 0.93)}


static func steps() -> Array:
	return [
		C.step(0.32, 0.14, C.R_COCK, C.L_GUARD, C.R_PUNCH, C.L_GUARD, F.SHIFT, F.PIVOT, -20.0, 18.0, 0.38, 12.0),
		C.step(0.32, 0.14, C.R_GUARD, C.L_COCK, C.R_GUARD, C.L_PUNCH, F.FIGHT, F.PIVOT_L, 20.0, -18.0, 0.38, 12.0),
		{"len": 0.6, "hit": 0.12, "keys": [   # 3 art arda dört yumruk
			C.t(0.0, 0.38, 0, 8, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.12, 0.4, -14, 14, C.R_PUNCH, C.L_COCK, F.PIVOT),
			C.t(0.2, 0.4, 14, 14, C.R_COCK, C.L_PUNCH, F.PIVOT_L),
			C.t(0.28, 0.4, -14, 14, C.R_PUNCH, C.L_COCK, F.PIVOT),
			C.t(0.36, 0.4, 14, 14, C.R_COCK, C.L_PUNCH, F.PIVOT_L),
			C.t(0.6, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
		C.step(0.45, 0.2, C.R_GUARD, C.L_GUARD, R_ELBOW, C.L_GUARD, F.SHIFT, F.STEPIN, 0.0, 160.0, 0.42, -8.0),
		{"len": 0.55, "hit": 0.22, "keys": [   # 5 alttan göğe tekme
			C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.12, 0.45, -10, 6, C.R_GUARD, C.L_GUARD, F.SHIFT),
			C.t(0.22, 0.3, -6, -14, C.R_BACK, C.L_BACK, C.KICK_UP_R),
			C.t(0.36, 0.3, -6, -12, C.R_BACK, C.L_BACK, C.KICK_UP_R),
			C.t(0.55, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
		{"len": 0.9, "hit": 0.4, "keys": [   # 6 üstten topuk: havada diz toplanır -> topuk iner
			C.t(0.0, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
			C.t(0.2, 0.3, 0, -10, C.R_HIGH, C.L_HIGH, F.HOP),
			C.t(0.4, 0.5, 0, 24, C.R_BACK, C.L_BACK, C.KICK_HIGH_R),
			C.t(0.6, 0.6, 0, 20, C.R_BACK, C.L_BACK, F.LOW),
			C.t(0.9, 0.35, 0, 4, C.R_GUARD, C.L_GUARD, F.FIGHT),
		]},
	]
