extends RefCounted
## Katoringu (火吐輪具, Fire Gatling; kanon: Ao, Boruto — refs/katoringu): İKİ ELLE kalçadan tutulan döner namlulu silah. Mermisi depolanmış Katon, kullanıcının chakrası harcanmaz.
## Ağır ve sabit: geri teper, ayak açık. 1 Isınma serisi, 2 yelpaze süpürme, 3 Dipçik (yakına tek yakın vuruş), 4 yeri tarama, 5 uzun seri, 6 Hanetsu: namlular kızarana dek boşaltır, silah tutukluk yapar.

const S = preload("res://scripts/combat/samehada_anim.gd")

const AIM := Vector3(0.0, 0.04, 1.0)
const R_HIP := {"RightUpperArm": Vector3(-0.32, -0.82, 0.3), "RightLowerArm": Vector3(0.18, -0.02, 0.98)}
const R_HIGH := {"RightUpperArm": Vector3(-0.35, -0.6, 0.72), "RightLowerArm": Vector3(0.2, 0.2, 0.96)}
const R_LOW := {"RightUpperArm": Vector3(-0.28, -0.88, 0.32), "RightLowerArm": Vector3(0.12, -0.45, 0.88)}
const R_BACK := {"RightUpperArm": Vector3(-0.5, -0.6, -0.62), "RightLowerArm": Vector3(0.25, 0.1, 0.96)}
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_ANY), legs)


static func _hold(hit: float, end: float, yaw0: float, yaw1: float, r: Dictionary, blade: Vector3, crouch := 0.5) -> Array:
	var W = S.LEG_WIDE
	var B = S.LEG_BACK
	var mid = lerpf(hit, end, 0.72)
	return [
		_t(0.0, 0.42, -8, 4, AIM, R_HIP, W),
		_t(hit - 0.08, crouch, yaw0, 8, blade, r, B),
		_t(hit, crouch, yaw0, 2, blade, r, B),
		_t(mid, crouch + 0.03, yaw1, -4, blade, r, B),
		_t(end, 0.42, -8, 4, AIM, R_HIP, W),
	]


static func steps() -> Array:
	return [
		{"len": 0.86, "hit": 0.3, "two": true, "keys": _hold(0.3, 0.86, -6, -2, R_HIP, AIM)},
		{"len": 1.08, "hit": 0.26, "two": true, "keys": _hold(0.26, 1.08, -32, 32, R_HIP, AIM)},
		{"len": 0.84, "hit": 0.36, "two": true, "keys": [
			_t(0.0, 0.42, -8, 4, AIM, R_HIP, S.LEG_WIDE),
			_t(0.2, 0.5, -36, -8, Vector3(0.1, 0.25, 0.96), R_BACK, S.LEG_BACK),
			_t(0.3, 0.5, -40, -10, Vector3(0.1, 0.25, 0.96), R_BACK, S.LEG_BACK),
			_t(0.36, 0.54, 30, 22, Vector3(0, 0.3, -0.95), R_HIGH, S.LEG_LUNGE),
			_t(0.54, 0.52, 26, 18, Vector3(0, 0.3, -0.95), R_HIGH, S.LEG_LUNGE),
			_t(0.84, 0.42, -8, 4, AIM, R_HIP, S.LEG_WIDE),
		]},
		{"len": 1.02, "hit": 0.3, "two": true, "keys": _hold(0.3, 1.02, -16, 16, R_LOW, Vector3(0, -0.32, 0.95), 0.66)},
		{"len": 1.3, "hit": 0.3, "two": true, "keys": _hold(0.3, 1.3, -5, 5, R_HIGH, AIM, 0.56)},
		{"len": 1.9, "hit": 0.46, "two": true, "keys": _hold(0.46, 1.9, -12, 12, R_HIGH, AIM, 0.62)},
	]
