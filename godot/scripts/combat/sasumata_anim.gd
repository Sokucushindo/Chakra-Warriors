extends RefCounted
## Sasumata (刺股, çatal kıskaç; kanon kullanıcı: Gamaken — refs/sasumata; gerçek dünyada Edo zaptiyesinin "adam yakalayan" sırığı): İKİ ELLE,
## uçta dikenli iki kol. Delmek için değil TUTMAK için: rakibi çatala alır, uzakta tutar, iter, yere ya da duvara kıstırır.
## 1 Mata Tsuki: çatalı göğse sürer, yakalar, 2 Oshi Komi: bütün gövdeyle yürüyüp iter (duvara kıstırırsa sersemletir),
## 3 Ashi Gari: çatal aşağı kayar, ayak bileğini kancalayıp çeker (yere serer), 4 Neji Age: koltuk altına girer, burup kaldırır,
## 5 Kubi Osae: yukarıdan boyna iner, yere çiviler, 6 Bakuha Tsuki (bitiriş): tutulan rakibe son itiş, çatalın ucunda chakra patlar (Gamaken, anime).
## Tutma ve patlama: SasumataFX (oyuncu ve düşman aynı).

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_GUARD := {"RightUpperArm": Vector3(-0.25, -0.82, 0.5), "RightLowerArm": Vector3(0.2, -0.15, 0.96)}    # sırık bel hizasında, çatal önde
const R_COCK := {"RightUpperArm": Vector3(-0.5, -0.62, -0.6), "RightLowerArm": Vector3(0.1, 0.12, 1)}         # dirsek geride
const R_DRIVE := {"RightUpperArm": Vector3(-0.1, -0.32, 0.94), "RightLowerArm": Vector3(0.05, -0.08, 1)}      # kollar öne kilitli
const R_BRACE := {"RightUpperArm": Vector3(-0.28, -0.72, 0.62), "RightLowerArm": Vector3(0.28, 0.25, 0.92)}   # sırık koltuk altında, gövde iter
const R_LOW := {"RightUpperArm": Vector3(-0.15, -0.92, 0.36), "RightLowerArm": Vector3(0.05, -0.82, 0.56)}    # çatal yerde
const R_YANK := {"RightUpperArm": Vector3(-0.52, -0.72, -0.45), "RightLowerArm": Vector3(-0.1, -0.5, 0.86)}   # geri çekiş
const R_RISE := {"RightUpperArm": Vector3(-0.35, 0.4, 0.85), "RightLowerArm": Vector3(0.22, 0.86, 0.46)}      # burup kaldırış
const R_OVER := {"RightUpperArm": Vector3(-0.25, 0.92, 0.3), "RightLowerArm": Vector3(0.0, 0.96, 0.28)}       # baş üstü
const R_PRESS := {"RightUpperArm": Vector3(-0.1, -0.55, 0.83), "RightLowerArm": Vector3(0.0, -0.72, 0.7)}     # aşağı bastırış
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}          # iki el: IK sapa götürür


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_ANY), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var RDY = Vector3(0.06, 0.2, 0.98)
	return [
		# 1 Mata Tsuki: geri yüklenir, çatal göğüs hizasında sürülür; çarpınca kollar kilitli kalır (rakip çatalda)
		{"len": 0.74, "hit": 0.3, "two": true, "keys": [
			_t(0.0, 0.42, -8, 6, RDY, R_GUARD, W),
			_t(0.16, 0.48, -22, -8, Vector3(0, 0.24, 0.97), R_COCK, BK),
			_t(0.3, 0.56, 14, 24, Vector3(0, 0.12, 1), R_DRIVE, L),
			_t(0.52, 0.54, 12, 22, Vector3(0, 0.12, 1), R_DRIVE, L),
			_t(0.74, 0.42, -8, 6, RDY, R_GUARD, W),
		]},
		# 2 Oshi Komi: sırık koltuk altına alınır, başı öne eğik adım adım yürür (FX gövdeyi ve tutulanı ileri taşır)
		{"len": 0.9, "hit": 0.54, "two": true, "keys": [
			_t(0.0, 0.42, -8, 6, RDY, R_GUARD, W),
			_t(0.14, 0.58, 6, 30, Vector3(0, 0.16, 1), R_BRACE, L),
			_t(0.3, 0.6, -6, 34, Vector3(0, 0.16, 1), R_BRACE, S.mirror(L)),
			_t(0.46, 0.62, 6, 36, Vector3(0, 0.16, 1), R_BRACE, L),
			_t(0.62, 0.62, 2, 38, Vector3(0, 0.12, 1), R_DRIVE, L),
			_t(0.9, 0.42, -8, 6, RDY, R_GUARD, W),
		]},
		# 3 Ashi Gari: çatal yere iner, öne süzülür, bileği alıp geri-yana sertçe çekilir
		{"len": 0.84, "hit": 0.34, "two": true, "keys": [
			_t(0.0, 0.42, -8, 6, RDY, R_GUARD, W),
			_t(0.16, 0.72, -6, 26, Vector3(0.08, -0.56, 0.82), R_LOW, L),
			_t(0.34, 0.76, 22, 22, Vector3(-0.22, -0.56, 0.8), R_LOW, L),
			_t(0.5, 0.58, 40, -8, Vector3(-0.42, -0.34, 0.84), R_YANK, BK),
			_t(0.84, 0.42, -8, 6, RDY, R_GUARD, W),
		]},
		# 4 Neji Age: alçaktan girer, sırık kendi ekseninde burulurken bacaklarla kalkar; rakip çatalın üstünde havalanır
		{"len": 0.96, "hit": 0.44, "two": true, "keys": [
			_t(0.0, 0.42, -8, 6, RDY, R_GUARD, W),
			_t(0.2, 0.74, -24, 22, Vector3(0.1, -0.2, 0.97), R_LOW, BK),
			_t(0.32, 0.76, -30, 24, Vector3(0.1, -0.16, 0.98), R_LOW, BK),
			_t(0.44, 0.34, 24, -16, Vector3(-0.1, 0.78, 0.62), R_RISE, ST),
			_t(0.66, 0.3, 32, -20, Vector3(-0.1, 0.86, 0.5), R_RISE, ST),
			_t(0.96, 0.42, -8, 6, RDY, R_GUARD, W),
		]},
		# 5 Kubi Osae: sırık başın üstüne çıkar (duraksar), çatal yukarıdan iner, tüm kilo üstüne bırakılır
		{"len": 1.12, "hit": 0.52, "two": true, "keys": [
			_t(0.0, 0.42, -8, 6, RDY, R_GUARD, W),
			_t(0.22, 0.26, -6, -16, Vector3(0, 0.6, 0.8), R_OVER, ST),
			_t(0.42, 0.24, -8, -20, Vector3(0, 0.54, 0.84), R_OVER, ST),
			_t(0.52, 0.7, 4, 38, Vector3(0, -0.74, 0.67), R_PRESS, L),
			_t(0.82, 0.74, 2, 42, Vector3(0, -0.8, 0.6), R_PRESS, L),
			_t(1.12, 0.42, -8, 6, RDY, R_GUARD, W),
		]},
		# 6 Bakuha Tsuki: uzun geri yükleniş, duraksama; bütün gövdeyle düz itiş, patlama kolları geri tepirir
		{"len": 1.32, "hit": 0.66, "two": true, "keys": [
			_t(0.0, 0.42, -8, 6, RDY, R_GUARD, W),
			_t(0.28, 0.56, -34, -14, Vector3(0, 0.2, 0.98), R_COCK, BK),
			_t(0.56, 0.58, -38, -16, Vector3(0, 0.2, 0.98), R_COCK, BK),
			_t(0.66, 0.6, 18, 32, Vector3(0, 0.1, 1), R_DRIVE, L),
			_t(0.8, 0.46, 10, 2, Vector3(0, 0.36, 0.93), R_BRACE, BK),
			_t(1.32, 0.42, -8, 6, RDY, R_GUARD, W),
		]},
	]
