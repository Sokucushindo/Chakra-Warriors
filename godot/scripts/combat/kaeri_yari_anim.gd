extends RefCounted
## Kaeri Yari (Hidan ve Ryūki'nin geri çekilir kara mızrağı; refs/kaeri_yari/retractable_pike.png). Tek elde kısa silindir, bir anda uzar.
## İlk üç adım silahın kendi dürtüşleri: 1 Hari Tsuki, 2 Ni no Tsuki, 3 Kaeshi Hiki (saplar ve geri çekerken hedefi sürükler).
## Son üç adım Jashin ayininin KENDİSİ: pozlar style_jashin_anim'den gelir (kopya yok), yalnız mızrağın yönü eklenir:
## 4 çemberi çiz, 5 bacağa sapla, 6 kalbe sapla. Hasar ve bağ KeyedCombos'un Jashin işlevleriyle.

const S = preload("res://scripts/combat/samehada_anim.gd")
const J = preload("res://scripts/combat/style_jashin_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.25, -0.85, 0.4), "RightLowerArm": Vector3(0.1, 0.1, 0.99)}
const R_CHAMBER := {"RightUpperArm": Vector3(-0.3, -0.6, -0.75), "RightLowerArm": Vector3(-0.05, -0.05, 1)}
const R_STAB := {"RightUpperArm": Vector3(-0.04, -0.03, 1), "RightLowerArm": Vector3(0.0, -0.02, 1)}
const R_HIGH := {"RightUpperArm": Vector3(-0.1, 0.45, 0.89), "RightLowerArm": Vector3(0.0, 0.2, 0.98)}
const L_GUARD := {"LeftUpperArm": Vector3(0.3, -0.75, 0.55), "LeftLowerArm": Vector3(-0.2, 0.3, 0.93)}
const L_BACK := {"LeftUpperArm": Vector3(0.55, -0.6, -0.6), "LeftLowerArm": Vector3(0.3, -0.5, -0.8)}
const FWD := Vector3(0.0, 0.02, 1)


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, l), legs)


## Ayin adımı: Jashin tarzının adımı + mızrak yönü (vuruştan önce pre, sonra post)
static func _ritual(src: Dictionary, pre: Vector3, post: Vector3) -> Dictionary:
	var st: Dictionary = src.duplicate(true)
	var hit = float(st["hit"])
	var last = float(st["len"])
	for k in st["keys"]:
		var t = float(k["t"])
		k["blade"] = (FWD if t <= 0.0 or t >= last else (pre if t < hit else post)).normalized()
	return st


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var js: Array = J.steps()
	return [
		{"len": 0.44, "hit": 0.15, "keys": [
			_t(0.0, 0.38, -10, 6, FWD, R_READY, L_GUARD, W),
			_t(0.09, 0.42, -28, -4, FWD, R_CHAMBER, L_GUARD, BK),
			_t(0.15, 0.48, 22, 18, FWD, R_STAB, L_BACK, L),
			_t(0.26, 0.46, 18, 14, FWD, R_STAB, L_BACK, L),
			_t(0.44, 0.38, -10, 6, FWD, R_READY, L_GUARD, W),
		]},
		{"len": 0.48, "hit": 0.17, "keys": [
			_t(0.0, 0.38, -10, 6, FWD, R_READY, L_GUARD, W),
			_t(0.1, 0.5, 20, 4, Vector3(0, 0.1, 1), R_CHAMBER, L_GUARD, LL),
			_t(0.17, 0.36, -20, 8, Vector3(0, 0.22, 1), R_HIGH, L_BACK, LL),
			_t(0.3, 0.36, -18, 6, Vector3(0, 0.22, 1), R_HIGH, L_BACK, LL),
			_t(0.48, 0.38, -10, 6, FWD, R_READY, L_GUARD, W),
		]},
		{"len": 0.74, "hit": 0.22, "keys": [
			_t(0.0, 0.38, -10, 6, FWD, R_READY, L_GUARD, W),
			_t(0.13, 0.44, -34, -6, FWD, R_CHAMBER, L_GUARD, BK),
			_t(0.22, 0.52, 26, 22, FWD, R_STAB, L_BACK, L),
			_t(0.36, 0.5, 22, 18, FWD, R_STAB, L_BACK, L),
			_t(0.54, 0.46, -30, -8, FWD, R_CHAMBER, L_GUARD, BK),
			_t(0.74, 0.38, -10, 6, FWD, R_READY, L_GUARD, W),
		]},
		_ritual(js[3], Vector3(0.1, -0.5, 0.86), Vector3(0.1, -0.5, 0.86)),
		_ritual(js[4], Vector3(0, 0.95, 0.3), Vector3(0.0, -0.95, 0.2)),
		_ritual(js[5], Vector3(0, 0.98, 0.15), Vector3(0.05, 0.1, -0.99)),
	]
