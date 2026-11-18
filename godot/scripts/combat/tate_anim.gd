extends RefCounted
## Tate (盾, kalkan; kanon: Gamaken'in sakazuki kalkanı, Renga Kokubō'nun iki elle dayadığı kalkan, Temujin, Torifu Akimichi — refs/tate): SOL ÖN KOLDA,
## sağ el boş yumruk. Oyuncunun savunması blok ve kalkan vuruşu: yüzde indirim yok; karşılanan darbe tam durur, kalkanın dayanıklılığı azalır.
## 1 Hōshin Tsuki: göbekle (umbo) yumruk gibi itiş, 2 Fuchi Uchi: kenarla ters savuruş, 3 Oshi Taoshi: iki elle dayayıp yürüyerek devirir (Renga),
## 4 Mamori Kaeshi: kalkan önde bekler; darbe karşılarsa anında karşı vuruş, 5 Uwa Otoshi: kenar tepeden iner, savunma kırar,
## 6 Furi Tate (bitiriş): kalkan ipiyle çevrede savrulur, öne çarpar, kola döner (kanon: Gamaken kalkanını gürz gibi sallar). Blok ve görsel: TateFX.

const S = preload("res://scripts/combat/samehada_anim.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const L_WALL := {"LeftUpperArm": Vector3(0.55, -0.45, 0.45), "LeftLowerArm": Vector3(-0.85, 0.3, 0.42)}     # ön kol göğüs önünde: kalkan yüzü önde
const L_PUSH := {"LeftUpperArm": Vector3(0.15, -0.15, 1.0), "LeftLowerArm": Vector3(-0.95, 0.1, 0.3)}       # kalkan ileri itilmiş
const L_COCK := {"LeftUpperArm": Vector3(0.62, -0.6, -0.42), "LeftLowerArm": Vector3(-0.72, 0.3, 0.62)}     # dirsek geride, itişe kurulu
const L_IN := {"LeftUpperArm": Vector3(-0.2, -0.3, 0.93), "LeftLowerArm": Vector3(-0.92, 0.2, -0.3)}        # kol sağ omza kapanmış
const L_OUT := {"LeftUpperArm": Vector3(0.9, -0.08, 0.42), "LeftLowerArm": Vector3(0.82, 0.05, 0.56)}       # sola açılmış, kenar önde
const L_HIGH := {"LeftUpperArm": Vector3(0.42, 0.82, 0.38), "LeftLowerArm": Vector3(0.1, 0.92, -0.36)}      # başın üstü
const L_DROP := {"LeftUpperArm": Vector3(0.18, -0.22, 0.96), "LeftLowerArm": Vector3(-0.1, -0.84, 0.52)}    # aşağı inmiş
const R_FIST := {"RightUpperArm": Vector3(-0.42, -0.72, 0.42), "RightLowerArm": Vector3(0.2, 0.7, 0.68)}    # sağ yumruk gardda
const R_BACK := {"RightUpperArm": Vector3(-0.5, -0.62, -0.6), "RightLowerArm": Vector3(-0.1, 0.32, 0.94)}   # dengede geride
const R_BRACE := {"RightUpperArm": Vector3(-0.22, -0.5, 0.84), "RightLowerArm": Vector3(0.68, 0.22, 0.7)}   # sağ el kalkanın arkasına dayanır
const R_OPEN := {"RightUpperArm": Vector3(-0.9, -0.28, 0.2), "RightLowerArm": Vector3(-0.72, -0.2, 0.62)}   # sağa açık denge


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, Vector3(0, 0, 1), S._a(r, l), legs)


static func steps() -> Array:
	var W = F.FIGHT
	var BK = F.SHIFT
	var PV = F.PIVOT
	var PL = F.PIVOT_L
	var LO = F.LOW
	var L = S.LEG_LUNGE
	var ML = S.mirror(S.LEG_LUNGE)
	return [
		# 1 Hōshin Tsuki: kısa geri yüklenip kalkanı düz iter
		{"len": 0.6, "hit": 0.26, "keys": [
			_t(0.0, 0.46, 18, 8, R_FIST, L_WALL, W),
			_t(0.13, 0.54, 34, 2, R_FIST, L_COCK, BK),
			_t(0.26, 0.5, -16, 22, R_BACK, L_PUSH, PL),
			_t(0.4, 0.48, -12, 18, R_BACK, L_PUSH, PL),
			_t(0.6, 0.46, 18, 8, R_FIST, L_WALL, W),
		]},
		# 2 Fuchi Uchi: kalkan sağ omza kapanır, gövde açılırken kenar yay çizer
		{"len": 0.74, "hit": 0.3, "keys": [
			_t(0.0, 0.46, 18, 8, R_FIST, L_WALL, W),
			_t(0.16, 0.52, 46, 4, R_FIST, L_IN, BK),
			_t(0.3, 0.5, -34, 14, R_OPEN, L_OUT, PV),
			_t(0.46, 0.48, -42, 10, R_OPEN, L_OUT, PV),
			_t(0.74, 0.46, 18, 8, R_FIST, L_WALL, W),
		]},
		# 3 Oshi Taoshi: omuz kalkanın arkasına girer, sağ el dayanır, adım adım yürür (Renga'nın alev karşısındaki duruşu)
		{"len": 0.96, "hit": 0.6, "keys": [
			_t(0.0, 0.46, 18, 8, R_FIST, L_WALL, W),
			_t(0.14, 0.62, 12, 26, R_BRACE, L_WALL, L),
			_t(0.3, 0.64, 8, 30, R_BRACE, L_WALL, ML),
			_t(0.46, 0.66, 12, 32, R_BRACE, L_WALL, L),
			_t(0.6, 0.6, 4, 36, R_BRACE, L_PUSH, L),
			_t(0.76, 0.54, 6, 24, R_BRACE, L_PUSH, L),
			_t(0.96, 0.46, 18, 8, R_FIST, L_WALL, W),
		]},
		# 4 Mamori Kaeshi: kalkan yukarıda, gövde arkasında sabit bekler; süre sonunda (ya da karşılayınca FX ile) kısa çarpış
		{"len": 1.02, "hit": 0.72, "keys": [
			_t(0.0, 0.46, 18, 8, R_FIST, L_WALL, W),
			_t(0.12, 0.58, 22, 12, R_BACK, L_WALL, LO),
			_t(0.62, 0.6, 22, 12, R_BACK, L_WALL, LO),
			_t(0.72, 0.5, -14, 24, R_BACK, L_PUSH, PL),
			_t(0.84, 0.48, -10, 18, R_BACK, L_PUSH, PL),
			_t(1.02, 0.46, 18, 8, R_FIST, L_WALL, W),
		]},
		# 5 Uwa Otoshi: kalkan başın üstüne, duraksar -> kenar köprücük hizasına iner, gövde üstüne çöker
		{"len": 0.98, "hit": 0.46, "keys": [
			_t(0.0, 0.46, 18, 8, R_FIST, L_WALL, W),
			_t(0.22, 0.34, 8, -14, R_BACK, L_HIGH, BK),
			_t(0.38, 0.32, 6, -18, R_BACK, L_HIGH, BK),
			_t(0.46, 0.68, -8, 32, R_OPEN, L_DROP, L),
			_t(0.66, 0.7, -6, 34, R_OPEN, L_DROP, L),
			_t(0.98, 0.46, 18, 8, R_FIST, L_WALL, W),
		]},
		# 6 Furi Tate: kol açılıp kalkanı bırakır, ip elde; gövde ipi izleyip tam tur döner, sonda sol kolla toplar
		{"len": 1.5, "hit": 0.34, "keys": [
			_t(0.0, 0.46, 18, 8, R_FIST, L_WALL, W),
			_t(0.2, 0.54, 50, 4, R_FIST, L_IN, BK),
			_t(0.34, 0.5, -20, 10, R_OPEN, L_OUT, PV),
			_t(0.62, 0.5, -130, 10, R_OPEN, L_OUT, PL),
			_t(0.9, 0.5, -250, 10, R_OPEN, L_OUT, PV),
			_t(1.08, 0.5, -350, 18, R_OPEN, L_PUSH, L),
			_t(1.3, 0.48, -360, 10, R_FIST, L_COCK, BK),
			_t(1.5, 0.46, -342, 8, R_FIST, L_WALL, W),
		]},
	]
