extends RefCounted
## Dakō (蛇行, "yılan gibi giden"; kanon: Iō yapımı, Gameru kullanır — refs/dako): TEK EL, kısa sap; gövdesi uzar, kısalır, havada yön değiştirir, taşı deler.
## 1 Sen Tsuki: düz uzanan saplama, 2 Dakō Uchi: S çizip yandan vuruş, 3 Maki: rakibe dolanır, sıkar, 4 Ushiro Sashi: rakibin üstünden aşıp sırtına, 5 Uzu: çevrede kırbaç halkası,
## 6 Hebi Tobi (bitiriş): uç ileri saplanır, gövde kısalıp seni rakibin içinden çeker (kanon: manevra). Gövde ve uç DakoFX'te.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_REST := {"RightUpperArm": Vector3(-0.3, -0.84, 0.44), "RightLowerArm": Vector3(0.22, 0.25, 0.94)}
const R_BACK := {"RightUpperArm": Vector3(-0.55, 0.05, -0.83), "RightLowerArm": Vector3(-0.1, 0.8, 0.58)}
const R_OUT := {"RightUpperArm": Vector3(-0.08, 0.08, 1), "RightLowerArm": Vector3(0.0, 0.05, 1)}
const R_SIDE := {"RightUpperArm": Vector3(-0.92, 0.1, 0.35), "RightLowerArm": Vector3(-0.8, 0.2, 0.55)}
const R_HIGH := {"RightUpperArm": Vector3(-0.2, 0.92, 0.32), "RightLowerArm": Vector3(0.0, 0.96, 0.25)}
const R_PULL := {"RightUpperArm": Vector3(-0.42, -0.5, -0.76), "RightLowerArm": Vector3(0.12, 0.35, 0.93)}
const L_BAL := {"LeftUpperArm": Vector3(0.72, -0.45, 0.45), "LeftLowerArm": Vector3(0.5, -0.2, 0.84)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_BAL), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var ST = S.LEG_STEP
	var CR = S.LEG_CROSS
	var R = Vector3(0.1, 0.5, 0.86)
	return [
		{"len": 0.78, "hit": 0.26, "keys": [
			_t(0.0, 0.38, -4, 4, R, R_REST, W), _t(0.15, 0.44, -28, -6, Vector3(0, 0.3, 0.95), R_BACK, B),
			_t(0.26, 0.5, 18, 20, Vector3(0, 0.05, 1), R_OUT, L), _t(0.56, 0.48, 14, 14, Vector3(0, 0.05, 1), R_OUT, L),
			_t(0.78, 0.38, -4, 4, R, R_REST, W)]},
		{"len": 0.84, "hit": 0.26, "keys": [
			_t(0.0, 0.38, -4, 4, R, R_REST, W), _t(0.15, 0.42, 26, 2, Vector3(0.7, 0.3, 0.65), R_OUT, CR),
			_t(0.26, 0.46, -26, 12, Vector3(-0.7, 0.1, 0.7), R_SIDE, ST), _t(0.6, 0.44, -34, 8, Vector3(-0.7, 0.1, 0.7), R_SIDE, W),
			_t(0.84, 0.38, -4, 4, R, R_REST, W)]},
		{"len": 1.08, "hit": 0.28, "keys": [
			_t(0.0, 0.38, -4, 4, R, R_REST, W), _t(0.16, 0.44, -20, -4, Vector3(0, 0.4, 0.92), R_BACK, B),
			_t(0.28, 0.48, 12, 14, Vector3(0, 0.1, 1), R_OUT, L), _t(0.62, 0.52, 6, -8, Vector3(0, 0.2, 0.98), R_PULL, B),
			_t(0.86, 0.5, 4, -10, Vector3(0, 0.2, 0.98), R_PULL, B), _t(1.08, 0.38, -4, 4, R, R_REST, W)]},
		{"len": 1.02, "hit": 0.3, "keys": [
			_t(0.0, 0.38, -4, 4, R, R_REST, W), _t(0.18, 0.34, -8, -12, Vector3(0, 0.9, 0.42), R_HIGH, ST),
			_t(0.3, 0.32, -4, -14, Vector3(0, 0.96, 0.25), R_HIGH, ST), _t(0.72, 0.46, 4, 12, Vector3(0, 0.1, 1), R_OUT, L),
			_t(1.02, 0.38, -4, 4, R, R_REST, W)]},
		{"len": 1.12, "hit": 0.24, "keys": [
			_t(0.0, 0.38, -4, 4, R, R_REST, W), _t(0.14, 0.42, 10, 0, Vector3(0, 0.9, 0.42), R_HIGH, W),
			_t(0.4, 0.4, 120, 0, Vector3(-0.3, 0.9, 0.3), R_HIGH, CR), _t(0.66, 0.4, 240, 0, Vector3(-0.3, 0.9, 0.3), R_HIGH, ST),
			_t(0.9, 0.42, 340, 2, R, R_REST, W), _t(1.12, 0.38, 356, 4, R, R_REST, W)]},
		{"len": 1.32, "hit": 0.34, "keys": [
			_t(0.0, 0.38, -4, 4, R, R_REST, W), _t(0.2, 0.46, -30, -8, Vector3(0, 0.3, 0.95), R_BACK, B),
			_t(0.34, 0.5, 14, 20, Vector3(0, 0.05, 1), R_OUT, L), _t(0.56, 0.3, 4, 26, Vector3(0, 0.05, 1), R_OUT, ST),
			_t(0.9, 0.34, 4, 24, Vector3(0, 0.05, 1), R_OUT, L), _t(1.32, 0.38, -4, 4, R, R_REST, W)]},
	]
