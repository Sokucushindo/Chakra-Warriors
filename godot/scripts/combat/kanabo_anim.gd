extends RefCounted
## Kanabō (金砕棒, GÜRZ; kanon: Doki'nin dev gürzü, Gatai'nin Raiton: Kanasaibō'su, Tenten — refs/kanabo; gerçek dünyada samuray iki el demir sopası):
## ağırlık tüm boya yayılır, kalınlaşan uzun gövde, sırt-omuzdan çalışan KALDIRAÇ. Topuzdan (Kyodai Konbō) farkı: baş yok, sarkaç yok; alanı ve zırhı ezer.
## 1 Kata Oroshi: omuzdan düz indirme, 2 Ne Gaeshi: yerde kalan gövdeyi toprağı kazıyarak yukarı süpürür (taş savurur),
## 3 Mune Oshi: iki el arası gövdeyle göğüs itişi (zırh / savunma kırar), 4 Ō Nagi: kalçadan 270 derece geniş savuruş, gövdeyi sırtı dönene dek taşır,
## 5 Uchi Komi: kazık çakar gibi üç kısa iniş, 6 Oni Kudaki (bitiriş): baş üstünde uzun bekleyiş, yeri çizgi hâlinde yaran iniş;
## Raiton doğası varsa Kanasaibō: gürz yıldırım sarar, yarıktan şimşek koşar. Görsel ve hasar: KanaboFX.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_SHLD := {"RightUpperArm": Vector3(-0.42, -0.72, 0.55), "RightLowerArm": Vector3(0.2, 0.78, 0.6)}      # gürz sağ omuzda (Doki duruşu)
const R_LIFT := {"RightUpperArm": Vector3(-0.3, 0.72, 0.62), "RightLowerArm": Vector3(0.0, 0.9, -0.42)}       # omuzdan yukarı-arkaya
const R_DOWN := {"RightUpperArm": Vector3(-0.08, -0.4, 0.91), "RightLowerArm": Vector3(0.0, -0.62, 0.78)}     # öne-aşağı
const R_SCRAPE := {"RightUpperArm": Vector3(-0.45, -0.82, 0.35), "RightLowerArm": Vector3(-0.2, -0.75, 0.62)} # sağ yanda yerde
const R_SCOOP := {"RightUpperArm": Vector3(0.2, 0.15, 0.97), "RightLowerArm": Vector3(0.62, 0.55, 0.55)}      # sola-yukarı kalkış
const R_BAR := {"RightUpperArm": Vector3(-0.42, -0.62, 0.66), "RightLowerArm": Vector3(0.82, 0.12, 0.55)}     # gövde göğüs önünde yatay
const R_BAR_F := {"RightUpperArm": Vector3(-0.3, -0.18, 0.94), "RightLowerArm": Vector3(0.75, 0.08, 0.66)}    # yatay gövde ileri itilmiş
const R_WIND := {"RightUpperArm": Vector3(-0.92, -0.22, -0.32), "RightLowerArm": Vector3(-0.62, 0.1, -0.78)}  # sağ-arkada yatay
const R_WIDE := {"RightUpperArm": Vector3(-0.2, -0.12, 0.97), "RightLowerArm": Vector3(0.45, 0.02, 0.9)}      # kollar önde açık
const R_HI := {"RightUpperArm": Vector3(-0.2, 0.92, 0.32), "RightLowerArm": Vector3(0.0, 0.98, 0.15)}         # dik baş üstü
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}          # iki el: IK sapa götürür


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_ANY), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(-0.3, 0.62, -0.72)   # uç omuzun arkasında yukarı
	return [
		# 1 Kata Oroshi: omuzdan hafif kalkar, ağırlığı toplar (durur) -> tek hatta yere; uç toprağa gömülü kalır, sonra omza zorla kaldırılır
		{"len": 1.26, "hit": 0.54, "two": true, "keys": [
			_t(0.0, 0.44, -8, 4, RDY, R_SHLD, W),
			_t(0.24, 0.36, -16, -16, Vector3(-0.1, 0.7, -0.7), R_LIFT, BK),
			_t(0.46, 0.34, -18, -20, Vector3(-0.1, 0.64, -0.76), R_LIFT, BK),
			_t(0.54, 0.72, 6, 34, Vector3(0, -0.66, 0.75), R_DOWN, L),
			_t(0.86, 0.74, 4, 36, Vector3(0, -0.72, 0.69), R_DOWN, L),
			_t(1.26, 0.44, -8, 4, RDY, R_SHLD, W),
		]},
		# 2 Ne Gaeshi: gürz yerde sağda, öne çekilirken toprağı kazır -> kalça açılır, sola-yukarı süpürür (taşlar ileri)
		{"len": 1.08, "hit": 0.46, "two": true, "keys": [
			_t(0.0, 0.44, -8, 4, RDY, R_SHLD, W),
			_t(0.2, 0.74, -34, 26, Vector3(-0.72, -0.56, 0.42), R_SCRAPE, BK),
			_t(0.36, 0.76, -22, 26, Vector3(-0.5, -0.62, 0.6), R_SCRAPE, ST),
			_t(0.46, 0.44, 22, 2, Vector3(0.62, 0.42, 0.66), R_SCOOP, LL),
			_t(0.68, 0.38, 36, -6, Vector3(0.7, 0.56, 0.44), R_SCOOP, LL),
			_t(1.08, 0.44, -8, 4, RDY, R_SHLD, W),
		]},
		# 3 Mune Oshi: gürz gövdenin önüne yatar, omuz arkasına girer -> iki kol birden ileri, yatay gövde göğse çarpar
		{"len": 0.92, "hit": 0.36, "two": true, "keys": [
			_t(0.0, 0.44, -8, 4, RDY, R_SHLD, W),
			_t(0.2, 0.56, -14, -8, Vector3(0.97, 0.16, 0.18), R_BAR, BK),
			_t(0.3, 0.56, -16, -10, Vector3(0.97, 0.16, 0.18), R_BAR, BK),
			_t(0.36, 0.56, 8, 26, Vector3(0.96, 0.12, 0.25), R_BAR_F, L),
			_t(0.56, 0.54, 6, 22, Vector3(0.96, 0.12, 0.25), R_BAR_F, L),
			_t(0.92, 0.44, -8, 4, RDY, R_SHLD, W),
		]},
		# 4 Ō Nagi: sağ-arkada açılır (uzun bekleme) -> kalçadan 270 derece; ağırlık gövdeyi sırtı dönene dek taşır, ayak çaprazlanır
		{"len": 1.46, "hit": 0.58, "two": true, "extra_hits": [0.8], "extra_radius": 3.0, "keys": [
			_t(0.0, 0.44, -8, 4, RDY, R_SHLD, W),
			_t(0.28, 0.54, -50, -2, Vector3(-0.86, 0.14, -0.48), R_WIND, BK),
			_t(0.5, 0.56, -56, -4, Vector3(-0.86, 0.14, -0.52), R_WIND, BK),
			_t(0.58, 0.58, -4, 16, Vector3(-0.3, 0.02, 0.95), R_WIDE, ST),
			_t(0.7, 0.6, 62, 18, Vector3(0.62, 0.0, 0.78), R_WIDE, CR),
			_t(0.86, 0.58, 128, 14, Vector3(0.62, 0.02, 0.78), R_WIDE, CR),
			_t(1.08, 0.5, 118, 8, Vector3(0.55, 0.3, 0.78), R_WIDE, W),
			_t(1.46, 0.44, -8, 4, RDY, R_SHLD, W),
		]},
		# 5 Uchi Komi: kısa kaldır-indir, üç kez; her inişte dizler daha çok çöker (kazık çakma)
		{"len": 1.42, "hit": 0.32, "two": true, "extra_hits": [0.64, 0.96], "extra_radius": 2.2, "keys": [
			_t(0.0, 0.44, -8, 4, RDY, R_SHLD, W),
			_t(0.2, 0.4, 0, -6, Vector3(0, 0.75, 0.66), R_HI, ST),
			_t(0.32, 0.62, 2, 26, Vector3(0, -0.56, 0.83), R_DOWN, L),
			_t(0.52, 0.38, 0, -8, Vector3(0, 0.8, 0.6), R_HI, L),
			_t(0.64, 0.68, 2, 30, Vector3(0, -0.62, 0.78), R_DOWN, L),
			_t(0.84, 0.36, 0, -10, Vector3(0, 0.85, 0.52), R_HI, L),
			_t(0.96, 0.76, 2, 36, Vector3(0, -0.7, 0.71), R_DOWN, L),
			_t(1.42, 0.44, -8, 4, RDY, R_SHLD, W),
		]},
		# 6 Oni Kudaki: gürz dimdik başın üstünde, gövde geri kavisli uzun bekleyiş (yıldırım burada sarar) -> yere; gövde katlanır, yavaş doğrulur
		{"len": 1.86, "hit": 0.84, "two": true, "keys": [
			_t(0.0, 0.44, -8, 4, RDY, R_SHLD, W),
			_t(0.3, 0.34, -4, -14, Vector3(0, 0.98, -0.18), R_HI, W),
			_t(0.74, 0.3, -4, -24, Vector3(0, 0.9, -0.42), R_LIFT, BK),
			_t(0.84, 0.8, 4, 44, Vector3(0, -0.72, 0.69), R_DOWN, L),
			_t(1.3, 0.82, 2, 46, Vector3(0, -0.76, 0.64), R_DOWN, L),
			_t(1.86, 0.44, -8, 4, RDY, R_SHLD, W),
		]},
	]
