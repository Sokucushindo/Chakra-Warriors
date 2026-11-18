extends RefCounted
## Jidanda (地団駄, "ayak vurma"; kanon: Iō yapımı, Tenten kullanır — refs/jidanda): dev dikenli demir gülle, uzayan sap, İKİ ELLE. Gülle uzakta iş görür, kullanıcı yerinde kalır ve el mührüyle etiketleri tetikler.
## 1 Tepeden Ezme, 2 Yan Savurma (dev gürz), 3 Korogashi: yerde yuvarlanır, 4 Bakuretsu: dikenler açılır, etiketler patlar, 5 Tobiage: patlama tepmesiyle havalanır, ipli gürz gibi iner,
## 6 Jidanda (bitiriş): gülle gökten ayak gibi üç kez yere basar, son basışta tüm etiketler. Hareket: JidandaFX.

const S = preload("res://scripts/combat/samehada_anim.gd")

const R_READY := {"RightUpperArm": Vector3(-0.3, -0.85, 0.42), "RightLowerArm": Vector3(0.28, 0.1, 0.95)}
const R_HI := {"RightUpperArm": Vector3(-0.22, 0.92, 0.32), "RightLowerArm": Vector3(0.0, 0.94, -0.33)}
const R_DOWN := {"RightUpperArm": Vector3(-0.08, -0.36, 0.93), "RightLowerArm": Vector3(0.0, -0.56, 0.83)}
const R_WIND := {"RightUpperArm": Vector3(-0.9, -0.2, -0.38), "RightLowerArm": Vector3(-0.62, 0.1, -0.78)}
const R_WIDE := {"RightUpperArm": Vector3(-0.2, -0.12, 0.97), "RightLowerArm": Vector3(0.48, 0.02, 0.88)}
const R_SEAL := {"RightUpperArm": Vector3(-0.3, -0.6, 0.74), "RightLowerArm": Vector3(0.65, 0.62, 0.44)}      # mühür (kaynak: eller göğüs önünde)
const L_ANY := {"LeftUpperArm": Vector3(0.3, -0.8, 0.45), "LeftLowerArm": Vector3(-0.1, -0.2, 0.97)}


static func _t(t: float, crouch: float, yaw: float, lean: float, blade: Vector3, r: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, blade.normalized(), S._a(r, L_ANY), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var B = S.LEG_BACK
	var CR = S.LEG_CROSS
	var R = Vector3(0.15, 0.5, 0.85)
	return [
		{"len": 1.32, "hit": 0.56, "two": true, "keys": [
			_t(0.0, 0.44, -6, 4, R, R_READY, W), _t(0.32, 0.34, -6, -20, Vector3(0, 0.74, -0.67), R_HI, B), _t(0.48, 0.32, -8, -26, Vector3(0, 0.68, -0.73), R_HI, B),
			_t(0.56, 0.72, 4, 34, Vector3(0, -0.5, 0.86), R_DOWN, L), _t(0.92, 0.72, 2, 30, Vector3(0, -0.5, 0.86), R_DOWN, L), _t(1.32, 0.44, -6, 4, R, R_READY, W)]},
		{"len": 1.44, "hit": 0.56, "two": true, "keys": [
			_t(0.0, 0.44, -6, 4, R, R_READY, W), _t(0.3, 0.54, -50, -3, Vector3(-0.86, 0.14, -0.48), R_WIND, B), _t(0.48, 0.56, -56, -4, Vector3(-0.86, 0.14, -0.5), R_WIND, B),
			_t(0.56, 0.58, 0, 14, Vector3(-0.2, 0.05, 0.97), R_WIDE, CR), _t(0.86, 0.56, 54, 12, Vector3(0.7, 0.05, 0.7), R_WIDE, L), _t(1.44, 0.44, -6, 4, R, R_READY, W)]},
		{"len": 1.3, "hit": 0.42, "two": true, "keys": [
			_t(0.0, 0.44, -6, 4, R, R_READY, W), _t(0.26, 0.66, -14, 20, Vector3(0, -0.5, -0.86), R_DOWN, B), _t(0.42, 0.62, 10, 26, Vector3(0, -0.2, 0.98), R_WIDE, L),
			_t(0.96, 0.54, 6, 10, Vector3(0, -0.1, 1), R_WIDE, L), _t(1.3, 0.44, -6, 4, R, R_READY, W)]},
		{"len": 1.2, "hit": 0.5, "two": true, "keys": [
			_t(0.0, 0.44, -6, 4, R, R_READY, W), _t(0.3, 0.5, 4, 6, Vector3(0.1, 0.2, 0.97), R_SEAL, W), _t(0.5, 0.52, 4, 8, Vector3(0.1, 0.2, 0.97), R_SEAL, W),
			_t(0.84, 0.48, 2, 4, Vector3(0.1, 0.2, 0.97), R_SEAL, W), _t(1.2, 0.44, -6, 4, R, R_READY, W)]},
		{"len": 1.62, "hit": 0.42, "two": true, "keys": [
			_t(0.0, 0.44, -6, 4, R, R_READY, W), _t(0.3, 0.52, 0, 4, Vector3(0.1, 0.2, 0.97), R_SEAL, W), _t(0.5, 0.36, -4, -20, Vector3(0, 0.9, 0.42), R_HI, B),
			_t(0.92, 0.34, -6, -24, Vector3(0, 0.9, 0.42), R_HI, B), _t(1.04, 0.72, 4, 32, Vector3(0, -0.4, 0.92), R_DOWN, L), _t(1.62, 0.44, -6, 4, R, R_READY, W)]},
		{"len": 2.3, "hit": 0.5, "two": true, "keys": [
			_t(0.0, 0.44, -6, 4, R, R_READY, W), _t(0.34, 0.5, 0, 4, Vector3(0.1, 0.2, 0.97), R_SEAL, W), _t(0.6, 0.34, 0, -20, Vector3(0, 0.95, 0.3), R_HI, B),
			_t(1.0, 0.7, 2, 26, Vector3(0, -0.3, 0.95), R_DOWN, L), _t(1.3, 0.36, 0, -18, Vector3(0, 0.95, 0.3), R_HI, B), _t(1.6, 0.74, 2, 30, Vector3(0, -0.3, 0.95), R_DOWN, L),
			_t(1.9, 0.72, 2, 28, Vector3(0, -0.3, 0.95), R_DOWN, L), _t(2.3, 0.44, -6, 4, R, R_READY, W)]},
	]
