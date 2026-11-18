extends RefCounted
## Tsurukame (鶴亀; kanon: Iō yapımı, Kusune kullanır — refs/tsurukame): sol kolda kaplumbağa kabuğu kalkan; deliklerinden araç fırlatır. Blok kuralı Tate ile aynı sistem, daha dayanıklı, daha yavaş.
## 1 Kabuk Darbesi, 2 Hari Fubuki: delik sırasından senbon, 3 Kusari Nage: içinden manriki çıkar, bağlar, 4 Makimono Tsume: kabuk önde, arkaya parşömen sürülür (dolum, blok açık),
## 5 Bakudan: üç bomba yayla, 6 Renpatsu (bitiriş; kanon Rapid Fire): her yöne seri iğne.

const S = preload("res://scripts/combat/samehada_anim.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const FWD := Vector3(0, 0, 1)
const L_WALL := {"LeftUpperArm": Vector3(0.55, -0.45, 0.45), "LeftLowerArm": Vector3(-0.85, 0.3, 0.42)}
const L_PUSH := {"LeftUpperArm": Vector3(0.15, -0.15, 1.0), "LeftLowerArm": Vector3(-0.95, 0.1, 0.3)}
const L_COCK := {"LeftUpperArm": Vector3(0.62, -0.6, -0.42), "LeftLowerArm": Vector3(-0.72, 0.3, 0.62)}
const R_REST := {"RightUpperArm": Vector3(-0.42, -0.74, 0.5), "RightLowerArm": Vector3(0.22, 0.45, 0.86)}
const R_TRIG := {"RightUpperArm": Vector3(-0.2, -0.55, 0.81), "RightLowerArm": Vector3(0.78, 0.15, 0.6)}     # sağ el kabuğun arkasında tetikte
const R_LOAD := {"RightUpperArm": Vector3(-0.3, -0.7, -0.2), "RightLowerArm": Vector3(0.7, 0.55, 0.45)}      # parşömen sürer
const R_OUT := {"RightUpperArm": Vector3(-0.85, -0.25, 0.45), "RightLowerArm": Vector3(-0.7, -0.1, 0.7)}


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, FWD, S._a(r, l), legs)


static func steps() -> Array:
	var W = F.FIGHT
	var B = F.SHIFT
	var LO = F.LOW
	var PL = F.PIVOT_L
	return [
		{"len": 0.82, "hit": 0.34, "keys": [
			_t(0.0, 0.5, 16, 8, R_REST, L_WALL, W), _t(0.2, 0.58, 34, 0, R_REST, L_COCK, B),
			_t(0.34, 0.54, -14, 24, R_OUT, L_PUSH, PL), _t(0.52, 0.52, -10, 20, R_OUT, L_PUSH, PL), _t(0.82, 0.5, 16, 8, R_REST, L_WALL, W)]},
		{"len": 0.78, "hit": 0.3, "keys": [
			_t(0.0, 0.5, 16, 8, R_REST, L_WALL, W), _t(0.18, 0.56, 18, 6, R_TRIG, L_WALL, LO),
			_t(0.3, 0.56, 16, 2, R_TRIG, L_PUSH, LO), _t(0.5, 0.54, 16, 4, R_TRIG, L_PUSH, LO), _t(0.78, 0.5, 16, 8, R_REST, L_WALL, W)]},
		{"len": 0.92, "hit": 0.34, "keys": [
			_t(0.0, 0.5, 16, 8, R_REST, L_WALL, W), _t(0.2, 0.56, 26, 4, R_TRIG, L_COCK, B),
			_t(0.34, 0.52, -6, 18, R_TRIG, L_PUSH, PL), _t(0.64, 0.56, 14, -6, R_REST, L_COCK, B), _t(0.92, 0.5, 16, 8, R_REST, L_WALL, W)]},
		{"len": 1.06, "hit": 0.5, "keys": [
			_t(0.0, 0.5, 16, 8, R_REST, L_WALL, W), _t(0.16, 0.62, 18, 12, R_LOAD, L_WALL, LO),
			_t(0.5, 0.64, 18, 12, R_TRIG, L_WALL, LO), _t(0.8, 0.6, 18, 10, R_LOAD, L_WALL, LO), _t(1.06, 0.5, 16, 8, R_REST, L_WALL, W)]},
		{"len": 0.96, "hit": 0.36, "keys": [
			_t(0.0, 0.5, 16, 8, R_REST, L_WALL, W), _t(0.2, 0.6, 22, -6, R_TRIG, L_WALL, B),
			_t(0.36, 0.46, 8, -12, R_TRIG, L_PUSH, W), _t(0.6, 0.48, 10, -6, R_TRIG, L_PUSH, W), _t(0.96, 0.5, 16, 8, R_REST, L_WALL, W)]},
		{"len": 1.5, "hit": 0.5, "keys": [
			_t(0.0, 0.5, 16, 8, R_REST, L_WALL, W), _t(0.3, 0.68, 0, 18, R_TRIG, L_WALL, LO), _t(0.46, 0.7, 0, 20, R_TRIG, L_WALL, LO),
			_t(0.56, 0.5, 0, 0, R_OUT, L_WALL, LO), _t(1.1, 0.52, 0, 2, R_OUT, L_WALL, LO), _t(1.5, 0.5, 16, 8, R_REST, L_WALL, W)]},
	]
