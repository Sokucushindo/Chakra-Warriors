extends RefCounted
## Amagasa (Amegakure savaş şemsiyesi; kanon: Shigure, Baiu, Midare, Aoi Rokushō, Shura — refs/amagasa): TEK EL, hafif, açılıp kapanır.
## Kapalıyken eskrim kılıcı gibi dürter; açılınca önden gelen darbeyi karşılar; kaburgalarındaki yaylar senbon atar; sapında kılıç saklıdır.
## 1 Kasa Tsuki: kapalı uçla eskrim dürtüşü, 2 Hiraki Uke: yüzüne doğru pat diye açılır (karşılama penceresi + itiş),
## 3 Kasa Guruma: açık şemsiye yana yatık, gövdeyle döner, kenar keser, 4 Samidare Kekka: uç geriye, açık iç yüz rakibe, kaburgalardan senbon,
## 5 Shikomi Nuki: gövde sol ele geçer, sağ el saptan gizli kılıcı çeker (Shura), 6 Jōro Senbon (bitiriş): açık şemsiye havaya atılır, Tora mührüyle
## yönetilen senbon yağmuru iner, şemsiye ele döner. Görsel ve hasar: AmagasaFX (oyuncu ve düşman aynı).

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_REST := {"RightUpperArm": Vector3(-0.3, -0.85, 0.42), "RightLowerArm": Vector3(0.25, 0.1, 0.96)}      # göğüs önünde, uç yukarı-ileri
const R_FENCE := {"RightUpperArm": Vector3(-0.42, -0.72, -0.55), "RightLowerArm": Vector3(0.1, 0.05, 1)}      # dirsek geride, dürtüşe kurulu
const R_SHOW := {"RightUpperArm": Vector3(-0.08, -0.12, 1), "RightLowerArm": Vector3(0.02, 0.12, 1)}          # kol ileri, şemsiye rakibe açık
const R_TILT := {"RightUpperArm": Vector3(-0.72, 0.3, 0.62), "RightLowerArm": Vector3(-0.35, 0.72, 0.6)}      # sağ üstte, kenar dışa yatık
const R_UNDER := {"RightUpperArm": Vector3(-0.3, -0.25, 0.92), "RightLowerArm": Vector3(0.1, 0.55, 0.83)}     # el önde, uç omuzun üstünden geriye
const R_DRAW := {"RightUpperArm": Vector3(0.28, -0.72, 0.62), "RightLowerArm": Vector3(0.85, -0.3, 0.42)}     # el sol kalçada, gizli kılıca
const R_CUT := {"RightUpperArm": Vector3(-0.92, -0.05, 0.38), "RightLowerArm": Vector3(-0.9, 0.05, 0.42)}     # çekişin sonu, sağa açık
const R_HURL := {"RightUpperArm": Vector3(-0.2, 0.96, 0.15), "RightLowerArm": Vector3(-0.04, 1, 0.08)}        # başın üstüne fırlatış
const R_SIGN := {"RightUpperArm": Vector3(-0.2, -0.62, 0.76), "RightLowerArm": Vector3(0.72, 0.42, 0.55)}     # Tora mührü: el göğüs önünde
const L_SIGN := {"LeftUpperArm": Vector3(0.2, -0.62, 0.76), "LeftLowerArm": Vector3(-0.72, 0.42, 0.55)}
const L_SHEATH := {"LeftUpperArm": Vector3(0.32, -0.88, 0.32), "LeftLowerArm": Vector3(-0.3, -0.5, 0.82)}     # sol elde şemsiye gövdesi, uç geride


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.08, 0.72, 0.68)
	return [
		# 1 Kasa Tsuki: yan duruş, sol kol dengede geride, kapalı uç düz gider
		{"len": 0.56, "hit": 0.24, "keys": [
			_t(0.0, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
			_t(0.13, 0.4, -32, -6, Vector3(0, 0.08, 1), R_FENCE, S.L_BACK, BK),
			_t(0.24, 0.5, 26, 16, Vector3(0, 0.02, 1), S.H_FWD, S.L_BACK, L),
			_t(0.36, 0.48, 24, 14, Vector3(0, 0.02, 1), S.H_FWD, S.L_BACK, L),
			_t(0.56, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
		]},
		# 2 Hiraki Uke: bilek geri, sonra kol ileri ve şemsiye rakibin yüzünde açılır; kısa süre önünde tutulur (karşılama)
		{"len": 0.78, "hit": 0.24, "keys": [
			_t(0.0, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
			_t(0.1, 0.42, -10, -8, Vector3(0, 0.5, 0.85), R_REST, S.L_BENT, BK),
			_t(0.24, 0.46, 4, 12, Vector3(0, 0.1, 1), R_SHOW, S.L_DOWN, ST),
			_t(0.56, 0.46, 2, 10, Vector3(0, 0.12, 1), R_SHOW, S.L_DOWN, W),
			_t(0.78, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
		]},
		# 3 Kasa Guruma: açık şemsiye sağ üstte yana yatar, ayak çaprazlanır, gövde dönerken kenar çevresini keser
		{"len": 0.98, "hit": 0.28, "extra_hits": [0.46, 0.66], "extra_radius": 2.1, "keys": [
			_t(0.0, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
			_t(0.14, 0.4, -40, 2, Vector3(-0.72, 0.58, 0.38), R_TILT, S.L_SIDE, CR),
			_t(0.28, 0.42, 30, 6, Vector3(-0.72, 0.58, 0.38), R_TILT, S.L_SIDE, ST),
			_t(0.46, 0.42, 100, 6, Vector3(-0.72, 0.58, 0.38), R_TILT, S.L_SIDE, CR),
			_t(0.66, 0.42, 170, 6, Vector3(-0.72, 0.58, 0.38), R_TILT, S.L_SIDE, ST),
			_t(0.82, 0.38, 60, 4, Vector3(-0.3, 0.68, 0.66), R_TILT, S.L_BENT, W),
			_t(0.98, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
		]},
		# 4 Samidare Kekka: şemsiye çevrilir, uç omuzun üstünden geriye; kaburgaların açık iç yüzü rakibe bakar, yaylar boşalır
		{"len": 0.76, "hit": 0.32, "keys": [
			_t(0.0, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
			_t(0.16, 0.52, 8, 2, Vector3(0.08, 0.5, -0.86), R_UNDER, S.L_DOWN, BK),
			_t(0.32, 0.54, 4, -10, Vector3(0.05, 0.36, -0.93), R_SHOW, S.L_DOWN, BK),
			_t(0.46, 0.5, 2, -6, Vector3(0.05, 0.4, -0.92), R_UNDER, S.L_DOWN, BK),
			_t(0.76, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
		]},
		# 5 Shikomi Nuki: sağ el sol kalçaya iner, gövde sol elde kalır; sap çekilir, tek geçişte yatay kesik
		{"len": 0.86, "hit": 0.34, "keys": [
			_t(0.0, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
			_t(0.16, 0.56, 34, 12, Vector3(0.72, -0.2, 0.66), R_DRAW, L_SHEATH, CR),
			_t(0.24, 0.58, 38, 14, Vector3(0.74, -0.18, 0.64), R_DRAW, L_SHEATH, CR),
			_t(0.34, 0.52, -30, 16, Vector3(-0.88, 0.08, 0.46), R_CUT, L_SHEATH, LL),
			_t(0.5, 0.5, -44, 12, Vector3(-0.95, 0.12, 0.08), R_CUT, L_SHEATH, LL),
			_t(0.86, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
		]},
		# 6 Jōro Senbon: çömel, başın üstüne fırlat; eller Tora mührüne gelir, yağmur boyunca mühür tutulur, sonda şemsiye ele iner
		{"len": 1.5, "hit": 0.36, "keys": [
			_t(0.0, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
			_t(0.2, 0.68, 0, 16, Vector3(0, 0.75, 0.66), R_REST, S.L_DOWN, W),
			_t(0.36, 0.2, 0, -14, Vector3(0, 1, 0.05), R_HURL, S.L_DOWN, ST),
			_t(0.56, 0.4, 0, 2, Vector3(0.3, 0.3, 0.9), R_SIGN, L_SIGN, W),
			_t(1.18, 0.42, 0, 4, Vector3(0.3, 0.3, 0.9), R_SIGN, L_SIGN, W),
			_t(1.32, 0.3, 0, -6, Vector3(0, 0.95, 0.3), R_HURL, S.L_DOWN, W),
			_t(1.5, 0.32, -6, 3, RDY, R_REST, S.L_BENT, W),
		]},
	]
