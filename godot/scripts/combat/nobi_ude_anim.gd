extends RefCounted
## Nobi-ude (uzayan kablolu kol; kanon film: Mizore Fuyukuma, wiki adı Retractable Cable Arm — refs/nobi_ude): sağ kolda dev mekanik el. Buhar basıncı yumruğu güçlendirir, avuç deliğinden bağlama teli çıkar, el kabloyla uçar, tutar, yere çakar.
## 1 Jōki Tsuki, 2 Jōki Kaeshi, 3 Shō Sen: avuçtan tel, 4 Tobi Te: el uçup yakalar, çeker, 5 Tataki: yakalananı kaldırıp yere vurur, 6 Gōsō (bitiriş): buharla atılan dev yumruk.

const S = preload("res://scripts/combat/samehada_anim.gd")
const F = preload("res://scripts/combat/style_legs.gd")

const R_G := {"RightUpperArm": Vector3(-0.38, -0.72, 0.58), "RightLowerArm": Vector3(0.22, 0.62, 0.75)}
const R_C := {"RightUpperArm": Vector3(-0.52, -0.55, -0.65), "RightLowerArm": Vector3(-0.05, 0.25, 0.96)}
const R_P := {"RightUpperArm": Vector3(-0.05, 0.05, 1), "RightLowerArm": Vector3(0.0, 0.05, 1)}
const R_UP := {"RightUpperArm": Vector3(-0.15, 0.92, 0.35), "RightLowerArm": Vector3(0.0, 0.98, 0.18)}
const R_DN := {"RightUpperArm": Vector3(-0.08, -0.35, 0.93), "RightLowerArm": Vector3(0.05, -0.75, 0.66)}
const L_G := {"LeftUpperArm": Vector3(0.38, -0.72, 0.58), "LeftLowerArm": Vector3(-0.22, 0.62, 0.75)}
const L_BR := {"LeftUpperArm": Vector3(0.22, -0.5, 0.84), "LeftLowerArm": Vector3(-0.7, 0.15, 0.7)}
const FWD := Vector3(0, 0, 1)


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, FWD, S._a(r, l), legs)


static func steps() -> Array:
	var W = F.FIGHT
	var B = F.SHIFT
	var P = F.PIVOT
	var L = S.LEG_LUNGE
	var LO = F.LOW
	return [
		{"len": 0.66, "hit": 0.28, "keys": [_t(0.0, 0.46, 8, 8, R_G, L_G, W), _t(0.17, 0.54, 30, 0, R_C, L_G, B), _t(0.28, 0.5, -22, 24, R_P, L_G, P), _t(0.42, 0.48, -18, 20, R_P, L_G, P), _t(0.66, 0.46, 8, 8, R_G, L_G, W)]},
		{"len": 0.7, "hit": 0.3, "keys": [_t(0.0, 0.46, 8, 8, R_G, L_G, W), _t(0.18, 0.54, -24, 0, R_UP, L_G, B), _t(0.3, 0.56, 16, 24, R_DN, L_G, L), _t(0.46, 0.54, 12, 22, R_DN, L_G, L), _t(0.7, 0.46, 8, 8, R_G, L_G, W)]},
		{"len": 0.76, "hit": 0.3, "keys": [_t(0.0, 0.46, 8, 8, R_G, L_G, W), _t(0.18, 0.5, 10, 4, R_P, L_BR, LO), _t(0.3, 0.5, 8, -4, R_P, L_BR, LO), _t(0.5, 0.5, 10, 0, R_P, L_BR, LO), _t(0.76, 0.46, 8, 8, R_G, L_G, W)]},
		{"len": 1.0, "hit": 0.26, "keys": [_t(0.0, 0.46, 8, 8, R_G, L_G, W), _t(0.16, 0.54, 26, -2, R_C, L_BR, B), _t(0.26, 0.5, -14, 18, R_P, L_BR, L), _t(0.68, 0.52, -6, 6, R_P, L_BR, L), _t(1.0, 0.46, 8, 8, R_G, L_G, W)]},
		{"len": 1.12, "hit": 0.5, "keys": [_t(0.0, 0.46, 8, 8, R_G, L_G, W), _t(0.3, 0.4, 2, -14, R_UP, L_BR, W), _t(0.46, 0.38, 2, -18, R_UP, L_BR, W), _t(0.56, 0.68, 4, 32, R_DN, L_BR, L), _t(0.8, 0.68, 2, 30, R_DN, L_BR, L), _t(1.12, 0.46, 8, 8, R_G, L_G, W)]},
		{"len": 1.36, "hit": 0.66, "keys": [_t(0.0, 0.46, 8, 8, R_G, L_G, W), _t(0.3, 0.62, 38, -8, R_C, L_BR, B), _t(0.58, 0.64, 42, -10, R_C, L_BR, B), _t(0.66, 0.54, -24, 30, R_P, L_BR, L), _t(0.96, 0.52, -18, 26, R_P, L_BR, L), _t(1.36, 0.46, 8, 8, R_G, L_G, W)]},
	]
