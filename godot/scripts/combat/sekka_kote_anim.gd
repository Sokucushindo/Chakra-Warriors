extends RefCounted
## Sekka Kote (Ishidate'nin taşlaştırma eldiveni) kombosu: 1-2 dokunuş, 3 Nigiri (kavrayıp tutar), 4 Ishi Okoshi (yerden kaya kaldırıp atar), 5 Ishi Ame (taş yağmuru), 6 Kudaki (taşlaşanı parçalar).

const O = preload("res://scripts/combat/oni_kote_anim.gd")
const S = preload("res://scripts/combat/samehada_anim.gd")


static func _s(ln: float, hit: float, r0: Dictionary, r1: Dictionary, l1: Dictionary, y: float, lean: float, g: Dictionary) -> Dictionary:
	return {"len": ln, "hit": hit, "keys": [
		O._t(0.0, 0.4, -8, 5, O.R_GUARD, O.L_GUARD, S.LEG_WIDE),
		O._t(hit * 0.7, 0.44, -y, -5, r0, O.L_FWD, S.LEG_BACK),
		O._t(hit, 0.48, y, lean, r1, l1, g),
		O._t(hit + (ln - hit) * 0.45, 0.46, y * 0.8, lean * 0.8, r1, l1, g),
		O._t(ln, 0.4, -8, 5, O.R_GUARD, O.L_GUARD, S.LEG_WIDE),
	]}


static func steps() -> Array:
	var L = S.LEG_LUNGE
	return [
		_s(0.5, 0.18, O.R_CHAMBER, O.R_PUNCH, O.L_BACK, 16.0, 14.0, L),
		_s(0.54, 0.2, O.R_OUT, O.R_ACROSS, O.L_BACK, 24.0, 12.0, L),
		_s(1.0, 0.26, O.R_CHAMBER, O.R_PUNCH, O.L_FWD, 10.0, 18.0, L),
		_s(0.96, 0.46, O.R_LOW, O.R_RISE, O.L_BACK, 8.0, -8.0, S.LEG_WIDE),
		_s(1.1, 0.36, O.R_RISE, O.R_OVER, O.L_FWD, 0.0, -6.0, S.LEG_WIDE),
		_s(1.14, 0.5, O.R_OVER, O.R_PUNCH, O.L_BACK, 18.0, 26.0, L),
	]
