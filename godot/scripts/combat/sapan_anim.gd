extends RefCounted
## Pachinko (sapan) kombosu. SOL elde çatal, SAĞ el taşı / biber topunu kesede çeker. Lastik ve kese SapanFX.Rig'de gerçekten gerilir.
## Kanonda duruş görseli YOK (Tanishi yalnız yüz görseli): tutuş gerçek sapan kullanımından, kol pozları yayla aynı mantıkta.
## 1-2 Tsubute (taş), 3 Futatsu (iki taş), 4 Mizukiri (yerde seken taş), 5 Tōgarashi-dama (biber topu), 6 Ō-tsubute (tam gerilim).

const S = preload("res://scripts/combat/samehada_anim.gd")

const FWD := Vector3(0, 0, 1)
const R_LOW := {"RightUpperArm": Vector3(-0.22, -0.92, 0.3), "RightLowerArm": Vector3(0.0, -0.45, 0.9)}
const R_POUCH := {"RightUpperArm": Vector3(-0.32, -0.75, 0.57), "RightLowerArm": Vector3(0.05, -0.6, 0.8)}   # bele uzanıp taş alır
const R_NOCK := {"RightUpperArm": Vector3(-0.2, -0.15, 0.97), "RightLowerArm": Vector3(0.3, 0.05, 0.95)}
const R_PULL := {"RightUpperArm": Vector3(-0.55, 0.15, 0.82), "RightLowerArm": Vector3(0.9, 0.02, 0.43)}
const R_FAR := {"RightUpperArm": Vector3(-0.72, 0.2, 0.42), "RightLowerArm": Vector3(0.96, 0.08, 0.26)}     # kulak arkasına kadar
const R_LOOSE := {"RightUpperArm": Vector3(-0.72, 0.1, 0.4), "RightLowerArm": Vector3(-0.2, 0.25, -0.9)}
const L_REST := {"LeftUpperArm": Vector3(0.25, -0.9, 0.3), "LeftLowerArm": Vector3(0.1, -0.4, 0.9)}
const L_FORK := {"LeftUpperArm": Vector3(0.05, 0.02, 1), "LeftLowerArm": Vector3(0.0, 0.03, 1)}
const L_FORK_DOWN := {"LeftUpperArm": Vector3(0.05, -0.3, 0.95), "LeftLowerArm": Vector3(0.0, -0.32, 0.95)}
const L_FORK_UP := {"LeftUpperArm": Vector3(0.05, 0.4, 0.92), "LeftLowerArm": Vector3(0.0, 0.42, 0.9)}

const HOOK := [0.1, 0.1, 0.16, 0.16, 0.24, 0.34]


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.2, FWD, S._a(r, l), legs)


static func _shot(nock: float, hit: float, end: float, crouch: float, yaw: float, rp: Dictionary, lp: Dictionary, legs: Dictionary) -> Array:
	return [
		_t(0.0, 0.34, -8, 2, R_LOW, L_REST, S.LEG_WIDE),
		_t(nock * 0.55, 0.34, -12, 2, R_POUCH, lp, S.LEG_WIDE),
		_t(nock, crouch, -24, 0, R_NOCK, lp, legs),
		_t(hit - 0.05, crouch + 0.02, yaw, -3, rp, lp, legs),
		_t(hit, crouch + 0.02, yaw, -3, rp, lp, legs),
		_t(hit + 0.06, crouch, yaw - 4, -5, R_LOOSE, lp, legs),
		_t(end, 0.34, -12, 2, R_LOW, L_REST, S.LEG_WIDE),
	]


static func steps() -> Array:
	var W = S.LEG_WIDE
	var BK = S.LEG_BACK
	var L = S.LEG_LUNGE
	return [
		{"len": 0.6, "hit": 0.3, "keys": _shot(0.1, 0.3, 0.6, 0.36, -44, R_PULL, L_FORK, W)},
		{"len": 0.6, "hit": 0.3, "keys": _shot(0.1, 0.3, 0.6, 0.36, -44, R_PULL, L_FORK, W)},
		{"len": 0.78, "hit": 0.42, "keys": _shot(0.16, 0.42, 0.78, 0.38, -46, R_PULL, L_FORK, W)},
		{"len": 0.82, "hit": 0.45, "keys": _shot(0.16, 0.45, 0.82, 0.5, -46, R_PULL, L_FORK_DOWN, BK)},
		{"len": 1.0, "hit": 0.6, "keys": _shot(0.24, 0.6, 1.0, 0.36, -48, R_PULL, L_FORK_UP, W)},
		{"len": 1.45, "hit": 0.95, "keys": _shot(0.34, 0.95, 1.45, 0.48, -58, R_FAR, L_FORK, L)},
	]
