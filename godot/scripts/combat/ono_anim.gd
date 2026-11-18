extends RefCounted
## Ono (斧, savaş baltası; kanon: Sabu'nun dev baltası, Tenten, Suna'nın yeniden diriltilen ninjası — refs/ono): İKİ ELLE, uzun sap, geniş kavisli ağız,
## sırtta kıvrık topuz. Oduncu ritmi (Sabu'nun Yosaku Giri'si adını oduncudan alır): önce iki çapraz çentik, sonra alçak kesik, en sonda ağaç devrilir.
## 1 Kesa Kiri: sağ omuzdan çapraz çentik, 2 Gyaku Kesa: ters çapraz (V çentiği), 3 Yosaku Giri: kanon alçak yatay kesik,
## 4 Kagi Hiki: ağzın sakalıyla savunmayı kancalayıp çeker, 5 Mine Uchi: bilek döner, kıvrık sırtla sersemletir,
## 6 Kyodai Kaiten Ono (bitiriş): balta dönerek uçar, keser, ele döner (kanon: Giant Spinning Axe); çentikli hedef devrilir. Görsel ve çentik: OnoFX.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.3, -0.84, 0.45), "RightLowerArm": Vector3(0.28, -0.05, 0.96)}      # sap bel önünde, baş önde-yukarı
const R_HIGH_R := {"RightUpperArm": Vector3(-0.72, 0.5, -0.42), "RightLowerArm": Vector3(-0.3, 0.86, -0.4)}      # sağ omuzun üstü-arkası
const R_HIGH_L := {"RightUpperArm": Vector3(0.22, 0.42, 0.88), "RightLowerArm": Vector3(0.72, 0.62, -0.3)}       # sol omuzun üstü
const R_CUT_L := {"RightUpperArm": Vector3(0.18, -0.48, 0.86), "RightLowerArm": Vector3(0.72, -0.42, 0.55)}      # sol kalçaya iniş
const R_CUT_R := {"RightUpperArm": Vector3(-0.62, -0.42, 0.66), "RightLowerArm": Vector3(-0.52, -0.46, 0.72)}    # sağ kalçaya iniş
const R_LOW_R := {"RightUpperArm": Vector3(-0.68, -0.68, -0.28), "RightLowerArm": Vector3(-0.55, -0.55, 0.62)}   # sağda alçak kurulum
const R_LOW_L := {"RightUpperArm": Vector3(0.12, -0.72, 0.68), "RightLowerArm": Vector3(0.82, -0.32, 0.46)}      # sola alçak geçiş
const R_REACH := {"RightUpperArm": Vector3(-0.12, 0.05, 0.99), "RightLowerArm": Vector3(0.02, 0.12, 0.99)}       # sakal ileri uzanır
const R_DRAG := {"RightUpperArm": Vector3(-0.55, -0.62, -0.55), "RightLowerArm": Vector3(0.05, -0.05, 1)}        # gövdeye çekiş
const R_OVER := {"RightUpperArm": Vector3(-0.22, 0.92, 0.3), "RightLowerArm": Vector3(-0.02, 0.9, -0.42)}        # baş üstü-arkası
const R_DOWN := {"RightUpperArm": Vector3(-0.08, -0.36, 0.93), "RightLowerArm": Vector3(0.0, -0.58, 0.81)}
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}             # iki el: IK sapa götürür


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary, roll := 0.0) -> Dictionary:
	var k = S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_ANY), legs)
	if roll != 0.0:
		k["roll"] = roll   # 180: ağız geride, kıvrık sırt önde
	return k


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var RDY = Vector3(0.18, 0.48, 0.86)
	return [
		# 1 Kesa Kiri: baş sağ omuzun arkasına kalkar, ağırlık bekler -> çapraz iner, ağız ağaçta kalmış gibi kısa takılır -> söküp toplar
		{"len": 1.12, "hit": 0.5, "two": true, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, W),
			_t(0.24, 0.38, -34, -14, Vector3(-0.42, 0.72, -0.55), R_HIGH_R, BK),
			_t(0.42, 0.36, -38, -16, Vector3(-0.42, 0.68, -0.6), R_HIGH_R, BK),
			_t(0.5, 0.56, 22, 26, Vector3(0.56, -0.52, 0.64), R_CUT_L, L),
			_t(0.68, 0.58, 24, 28, Vector3(0.58, -0.54, 0.6), R_CUT_L, L),
			_t(0.8, 0.54, 16, 18, Vector3(0.45, -0.3, 0.84), R_CUT_L, L),
			_t(1.12, 0.42, -6, 4, RDY, R_READY, W),
		]},
		# 2 Gyaku Kesa: sökülen baş sol omza gider, gövde ters burulur -> karşı çapraz, ilk kesikle V çizer
		{"len": 1.06, "hit": 0.46, "two": true, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, W),
			_t(0.22, 0.38, 32, -12, Vector3(0.48, 0.7, -0.52), R_HIGH_L, BK),
			_t(0.38, 0.36, 36, -14, Vector3(0.48, 0.66, -0.57), R_HIGH_L, BK),
			_t(0.46, 0.56, -24, 26, Vector3(-0.56, -0.52, 0.64), R_CUT_R, LL),
			_t(0.66, 0.58, -26, 28, Vector3(-0.58, -0.54, 0.6), R_CUT_R, LL),
			_t(1.06, 0.42, -6, 4, RDY, R_READY, W),
		]},
		# 3 Yosaku Giri (kanon: alçak yatay darbe): dizler kırılır, baş yerde sağda -> ayak hizasında tek süpürüş
		{"len": 1.1, "hit": 0.48, "two": true, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, W),
			_t(0.24, 0.74, -46, 16, Vector3(-0.88, -0.3, -0.36), R_LOW_R, BK),
			_t(0.4, 0.78, -52, 18, Vector3(-0.9, -0.28, -0.32), R_LOW_R, BK),
			_t(0.48, 0.8, 4, 22, Vector3(-0.1, -0.4, 0.91), R_LOW_L, ST),
			_t(0.6, 0.78, 50, 18, Vector3(0.84, -0.3, 0.45), R_LOW_L, CR),
			_t(0.76, 0.72, 56, 12, Vector3(0.86, -0.22, 0.45), R_LOW_L, CR),
			_t(1.1, 0.42, -6, 4, RDY, R_READY, W),
		]},
		# 4 Kagi Hiki: baş rakibin omzunun üstünden uzatılır, sakal takılır -> iki kol birden gövdeye çeker
		{"len": 0.94, "hit": 0.34, "two": true, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, W),
			_t(0.2, 0.46, -12, 18, Vector3(0.05, 0.42, 0.9), R_REACH, L),
			_t(0.34, 0.5, -8, 24, Vector3(0.05, 0.2, 0.98), R_REACH, L),
			_t(0.5, 0.56, 22, -14, Vector3(-0.18, 0.34, 0.92), R_DRAG, BK),
			_t(0.66, 0.54, 26, -16, Vector3(-0.18, 0.4, 0.9), R_DRAG, BK),
			_t(0.94, 0.42, -6, 4, RDY, R_READY, W),
		]},
		# 5 Mine Uchi: başın üstünde bilek döner, ağız arkaya geçer -> kıvrık sırt tepeden iner (kesmez, sersemletir)
		{"len": 1.08, "hit": 0.5, "two": true, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, W),
			_t(0.22, 0.3, -6, -16, Vector3(0, 0.74, -0.67), R_OVER, ST, 90.0),
			_t(0.42, 0.28, -8, -22, Vector3(0, 0.7, -0.71), R_OVER, ST, 180.0),
			_t(0.5, 0.64, 6, 30, Vector3(0, -0.6, 0.8), R_DOWN, L, 180.0),
			_t(0.72, 0.66, 4, 32, Vector3(0, -0.66, 0.75), R_DOWN, L, 180.0),
			_t(0.9, 0.52, 0, 14, Vector3(0.1, 0.1, 0.99), R_READY, W, 90.0),
			_t(1.08, 0.42, -6, 4, RDY, R_READY, W),
		]},
		# 6 Kyodai Kaiten Ono: gövde tam kurulur, balta yandan bırakılır; eller boş bekler, dönen balta tutulup ağırlığıyla gövdeyi çevirir
		{"len": 1.72, "hit": 0.52, "two": true, "keys": [
			_t(0.0, 0.42, -6, 4, RDY, R_READY, W),
			_t(0.26, 0.56, -56, -6, Vector3(-0.8, 0.3, -0.52), R_HIGH_R, BK),
			_t(0.44, 0.58, -58, -8, Vector3(-0.8, 0.26, -0.54), R_HIGH_R, BK),
			_t(0.52, 0.46, 24, 24, Vector3(0.3, 0.2, 0.93), R_REACH, L),
			_t(1.3, 0.44, 8, 8, Vector3(0.1, 0.3, 0.95), R_REACH, W),
			_t(1.46, 0.5, -30, 6, Vector3(-0.6, 0.3, 0.74), R_CUT_R, BK),
			_t(1.72, 0.42, -6, 4, RDY, R_READY, W),
		]},
	]
