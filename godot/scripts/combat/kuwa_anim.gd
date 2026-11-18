extends RefCounted
## Kuwa (鍬, çapa; Narutopedia kullanıcı listesi: Fū Yamanaka, sayfa Wikipedia'ya yönlenir): İKİ ELLE tarla çapası. Hareket toprak işinden: indir, çek, kazı, savur.
## 1 Uchikomi: tepeden indirme, 2 Kaeshi Uchi: ters yandan, 3 Kagi Hiki: ağız bileğe takılır, çeker, 4 Tsuchi Kake: toprağı rakibin yüzüne savurur, 5 Une Kiri: yerde karık açarak ilerler, 6 Ō-Tagayashi (bitiriş): tüm kiloyla iner, üç karık yelpaze açar.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.3, -0.84, 0.44), "RightLowerArm": Vector3(0.26, 0.05, 0.96)}
const R_HI := {"RightUpperArm": Vector3(-0.22, 0.9, 0.36), "RightLowerArm": Vector3(0.0, 0.9, -0.42)}
const R_DOWN := {"RightUpperArm": Vector3(-0.08, -0.38, 0.92), "RightLowerArm": Vector3(0.0, -0.6, 0.8)}
const R_SIDE := {"RightUpperArm": Vector3(-0.8, 0.3, -0.45), "RightLowerArm": Vector3(-0.35, 0.8, -0.45)}
const R_LOW := {"RightUpperArm": Vector3(-0.15, -0.9, 0.4), "RightLowerArm": Vector3(0.05, -0.8, 0.6)}
const R_PULL := {"RightUpperArm": Vector3(-0.52, -0.68, -0.5), "RightLowerArm": Vector3(-0.05, -0.3, 0.95)}
const R_FLING := {"RightUpperArm": Vector3(-0.1, 0.35, 0.93), "RightLowerArm": Vector3(0.05, 0.75, 0.66)}
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_ANY), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var B = S.LEG_BACK
	var R = Vector3(0.15, 0.55, 0.82)
	return [
		{"len": 0.96, "hit": 0.42, "two": true, "keys": [
			_t(0.0, 0.4, -5, 4, R, R_READY, W), _t(0.26, 0.32, -6, -16, Vector3(0, 0.74, -0.67), R_HI, B), _t(0.36, 0.3, -8, -20, Vector3(0, 0.7, -0.71), R_HI, B),
			_t(0.42, 0.64, 4, 30, Vector3(0, -0.62, 0.78), R_DOWN, L), _t(0.66, 0.66, 2, 32, Vector3(0, -0.66, 0.75), R_DOWN, L), _t(0.96, 0.4, -5, 4, R, R_READY, W)]},
		{"len": 0.9, "hit": 0.38, "two": true, "keys": [
			_t(0.0, 0.4, -5, 4, R, R_READY, W), _t(0.22, 0.38, -32, -8, Vector3(-0.5, 0.68, -0.53), R_SIDE, B), _t(0.32, 0.36, -36, -10, Vector3(-0.5, 0.65, -0.57), R_SIDE, B),
			_t(0.38, 0.56, 22, 22, Vector3(0.5, -0.5, 0.7), R_DOWN, LL), _t(0.6, 0.58, 26, 24, Vector3(0.55, -0.5, 0.67), R_DOWN, LL), _t(0.9, 0.4, -5, 4, R, R_READY, W)]},
		{"len": 0.92, "hit": 0.32, "two": true, "keys": [
			_t(0.0, 0.4, -5, 4, R, R_READY, W), _t(0.18, 0.66, -4, 26, Vector3(0, -0.5, 0.86), R_LOW, L), _t(0.32, 0.7, 0, 28, Vector3(0, -0.56, 0.83), R_LOW, L),
			_t(0.5, 0.56, 22, -10, Vector3(-0.1, -0.2, 0.97), R_PULL, B), _t(0.66, 0.54, 26, -12, Vector3(-0.1, -0.15, 0.98), R_PULL, B), _t(0.92, 0.4, -5, 4, R, R_READY, W)]},
		{"len": 0.94, "hit": 0.42, "two": true, "keys": [
			_t(0.0, 0.4, -5, 4, R, R_READY, W), _t(0.24, 0.74, -14, 30, Vector3(0, -0.85, 0.5), R_LOW, L), _t(0.36, 0.76, -10, 32, Vector3(0, -0.88, 0.46), R_LOW, L),
			_t(0.42, 0.42, 8, -8, Vector3(0, 0.62, 0.78), R_FLING, L), _t(0.62, 0.38, 10, -12, Vector3(0, 0.72, 0.69), R_FLING, L), _t(0.94, 0.4, -5, 4, R, R_READY, W)]},
		{"len": 1.12, "hit": 0.34, "two": true, "keys": [
			_t(0.0, 0.4, -5, 4, R, R_READY, W), _t(0.2, 0.62, -4, 24, Vector3(0, -0.72, 0.69), R_LOW, S.LEG_STEP), _t(0.34, 0.7, 0, 32, Vector3(0, -0.76, 0.65), R_DOWN, L),
			_t(0.7, 0.68, 2, 30, Vector3(0, -0.72, 0.69), R_PULL, L), _t(1.12, 0.4, -5, 4, R, R_READY, W)]},
		{"len": 1.5, "hit": 0.72, "two": true, "keys": [
			_t(0.0, 0.4, -5, 4, R, R_READY, W), _t(0.36, 0.26, -8, -24, Vector3(0, 0.72, -0.69), R_HI, B), _t(0.62, 0.24, -10, -30, Vector3(0, 0.66, -0.75), R_HI, B),
			_t(0.72, 0.8, 6, 42, Vector3(0, -0.7, 0.71), R_DOWN, L), _t(1.1, 0.82, 4, 44, Vector3(0, -0.74, 0.67), R_DOWN, L), _t(1.5, 0.4, -5, 4, R, R_READY, W)]},
	]
