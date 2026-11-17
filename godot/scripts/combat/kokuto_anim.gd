extends RefCounted
## Kokutō — Raidō Namiashi'nin kara kılıcı (Narutopedia + ref refs/kokuto: kokuto.png, Raid_attacking_Kakuzu.PNG; video _tmp/vid/raido).
## Kanon: yüzeyi kararmış, ışık yansıtmayan katana; suikast için ağır zehir sürülü. Tek kanon sahne: karga sürüsünün içinden çıkıp
## başa yatay kesik (Kakuzu'nun sertleşmiş derisinde kıvılcım). Kaynak az: kombo bu kanon özelliklerden türetildi — sessiz suikastçı,
## kısa geri çekiş, baş / bacak / sırt gibi hayati hedefler, zehir birikir (KeyedCombos.mods "burn"), görünmeyen ağız (KokutoFX).
## 1 Kubi Nagi: alçaktan baş hizasında yatay kesik (kanon sahne) — kaçınılamaz (kara ağız görünmez)
## 2 Gyaku Kesa: sağ alttan sol üste ters çapraz
## 3 Doku Tsuki: dirsek geride -> derin saplama, zehir damara
## 4 Ashi Barai: çömelip tam tur bacak kesiği (yere serer)
## 5 Kage Mawari: rakibin arkasına süzülüp sırtından kesik (KeyedCombos.on_start: arkaya geçiş)
## 6 Ansatsu (bitiriş): sıçrayıp yukarıdan omuza inen kesik, zehir patlar

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.2, -0.85, 0.45), "RightLowerArm": Vector3(0.2, -0.3, 0.93)}
const R_LOWBACK := {"RightUpperArm": Vector3(-0.45, -0.85, -0.25), "RightLowerArm": Vector3(-0.2, -0.6, -0.75)}    # ağız geride-aşağıda (gizli tutuş)
const R_LEFT_HI := {"RightUpperArm": Vector3(0.2, 0.05, 0.97), "RightLowerArm": Vector3(0.9, 0.3, 0.3)}          # sol omuz önü, baş hizası
const R_WIDE_HI := {"RightUpperArm": Vector3(-0.95, 0.15, 0.25), "RightLowerArm": Vector3(-0.85, 0.2, 0.45)}     # sağa açık, baş hizası
const R_LOW_R := {"RightUpperArm": Vector3(-0.4, -0.85, 0.3), "RightLowerArm": Vector3(-0.3, -0.7, 0.65)}        # sağ alt
const R_HIGH_L := {"RightUpperArm": Vector3(0.1, 0.8, 0.55), "RightLowerArm": Vector3(0.45, 0.85, 0.25)}         # sol üst
const R_CHAMBER := {"RightUpperArm": Vector3(-0.3, -0.6, -0.75), "RightLowerArm": Vector3(-0.05, -0.05, 1)}
const R_STAB := {"RightUpperArm": Vector3(-0.04, -0.03, 1), "RightLowerArm": Vector3(0.0, -0.02, 1)}
const R_SWEEP := {"RightUpperArm": Vector3(-0.95, -0.3, 0.1), "RightLowerArm": Vector3(-0.8, -0.55, 0.25)}       # alçak yana açık
const R_OVER := {"RightUpperArm": Vector3(-0.2, 0.95, -0.2), "RightLowerArm": Vector3(0.0, 0.9, -0.45)}         # baş üstü, ağız geride
const R_DOWN := {"RightUpperArm": Vector3(-0.15, -0.3, 0.94), "RightLowerArm": Vector3(0.0, -0.55, 0.83)}
const L_GUARD := {"LeftUpperArm": Vector3(0.3, -0.75, 0.55), "LeftLowerArm": Vector3(-0.2, 0.3, 0.93)}
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const L_LOW := {"LeftUpperArm": Vector3(0.4, -0.9, 0.2), "LeftLowerArm": Vector3(0.1, -0.95, 0.3)}               # yere dayanır (çömelik)
const L_FWD := {"LeftUpperArm": Vector3(0.15, 0.05, 1), "LeftLowerArm": Vector3(0.05, 0.0, 1)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.25, blade.normalized(), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.0, -0.6, -0.8)   # ağız geride-aşağı (suikastçı tutuşu: kara ağız gövdenin arkasında saklı)
	return [
		# 1 Kubi Nagi: alçak çömelikten kalkarken sol omuzdan sağa, baş hizasında yatay
		{"len": 0.55, "hit": 0.24, "keys": [
			_t(0.0, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
			_t(0.12, 0.62, 24, 18, Vector3(0.85, 0.1, 0.5), R_LEFT_HI, L_FWD, BK),
			_t(0.24, 0.4, -26, 6, Vector3(-0.9, 0.05, 0.4), R_WIDE_HI, L_BACK, L),
			_t(0.34, 0.4, -30, 4, Vector3(-0.95, 0.05, 0.3), R_WIDE_HI, L_BACK, L),
			_t(0.55, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
		]},
		# 2 Gyaku Kesa: sağ alttan sol üste
		{"len": 0.52, "hit": 0.22, "keys": [
			_t(0.0, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
			_t(0.1, 0.5, -20, 14, Vector3(-0.3, -0.8, 0.5), R_LOW_R, L_GUARD, CR),
			_t(0.22, 0.38, 22, -6, Vector3(0.4, 0.85, 0.3), R_HIGH_L, L_BACK, ST),
			_t(0.32, 0.38, 26, -8, Vector3(0.45, 0.85, 0.25), R_HIGH_L, L_BACK, ST),
			_t(0.52, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
		]},
		# 3 Doku Tsuki: dirsek geride kurulur -> uzun adımla derin saplama, bir an içeride tutar (zehir damara)
		{"len": 0.72, "hit": 0.3, "keys": [
			_t(0.0, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
			_t(0.14, 0.46, -16, -6, Vector3(0, 0.0, 1), R_CHAMBER, L_FWD, BK),
			_t(0.22, 0.46, -18, -8, Vector3(0, 0.0, 1), R_CHAMBER, L_FWD, BK),
			_t(0.3, 0.56, 14, 26, Vector3(0, -0.05, 1), R_STAB, L_BACK, L),
			_t(0.48, 0.56, 12, 24, Vector3(0, -0.05, 1), R_STAB, L_BACK, L),
			_t(0.72, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
		]},
		# 4 Ashi Barai: yere çöker (sol el yerde), tam tur bacak hizasında kesik
		{"len": 0.85, "hit": 0.42, "keys": [
			_t(0.0, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
			_t(0.14, 0.82, -30, 24, Vector3(-0.9, -0.4, 0.2), R_SWEEP, L_LOW, CR),
			_t(0.3, 0.86, 120, 26, Vector3(-0.9, -0.4, 0.2), R_SWEEP, L_LOW, W),
			_t(0.46, 0.86, 250, 26, Vector3(-0.9, -0.4, 0.2), R_SWEEP, L_LOW, CR),
			_t(0.62, 0.8, 360, 20, Vector3(-0.9, -0.4, 0.2), R_SWEEP, L_LOW, W),
			_t(0.85, 0.42, 360, 10, RDY, R_LOWBACK, L_GUARD, W),
		]},
		# 5 Kage Mawari: (arkaya süzülür) -> dönüp sırttan çapraz iniş
		{"len": 0.8, "hit": 0.4, "keys": [
			_t(0.0, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
			_t(0.16, 0.5, 40, 4, Vector3(-0.2, 0.8, -0.5), R_HIGH_L, L_BACK, CR),
			_t(0.3, 0.46, 30, -6, Vector3(-0.2, 0.85, -0.45), R_HIGH_L, L_BACK, BK),
			_t(0.4, 0.54, -10, 22, Vector3(0.5, -0.65, 0.55), R_DOWN, L_FWD, LL),
			_t(0.56, 0.52, -14, 20, Vector3(0.5, -0.65, 0.55), R_DOWN, L_FWD, LL),
			_t(0.8, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
		]},
		# 6 Ansatsu: sıçrayış (baş üstü kurulum) -> omuzdan göğse dik iniş, ağız içeride bekler
		{"len": 1.15, "hit": 0.62, "keys": [
			_t(0.0, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
			_t(0.2, 0.7, 0, 16, RDY, R_LOWBACK, L_LOW, W),
			_t(0.36, 0.2, 0, -16, Vector3(0, 0.6, -0.8), R_OVER, L_FWD, ST),
			_t(0.52, 0.18, 0, -18, Vector3(0, 0.65, -0.75), R_OVER, L_FWD, ST),
			_t(0.62, 0.62, 0, 34, Vector3(0, -0.75, 0.6), R_DOWN, L_BACK, L),
			_t(0.86, 0.6, 0, 30, Vector3(0, -0.75, 0.6), R_DOWN, L_BACK, L),
			_t(1.15, 0.42, 0, 10, RDY, R_LOWBACK, L_GUARD, W),
		]},
	]
