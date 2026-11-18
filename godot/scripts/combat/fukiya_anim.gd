extends RefCounted
## Fukiya (üfleme borusu) kombosu. Ref: refs/fukiya/Blowpipe.png (Dōshu: bir el ağızda boruyu kavrar, öbür el ortada, boru öne-aşağı).
## Ağız hizası Hōmatsu Kiseru'dan: aynı üfleme pozu ve nefes yapısı (kiseru_anim, ağızlık-ağız taraması orada yapıldı); fukiya'nın
## üflenen ucu da aynı noktada (z -0.205) durur. Oklar FukiyaFX.strike'tan çıkar (oyuncu + düşman aynı).
## 1-2 Fukibari (iğne), 3 Nemuri-ya (uyku oku), 4 Hiki-fuki (geri kayıp üfler), 5 Sanren (bir nefeste üç), 6 Hitofuki (tek nefeste öldüren atış).

const S = preload("res://scripts/combat/samehada_anim.gd")
const K = preload("res://scripts/combat/kiseru_anim.gd")


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	return [
		{"len": 0.5, "hit": 0.2, "two": true, "keys": K._blow(0.0, 0.08, 0.14, 0, W, W, 0.5)},
		{"len": 0.5, "hit": 0.2, "two": true, "keys": K._blow(0.0, 0.08, 0.14, -10, W, L, 0.5)},
		{"len": 0.85, "hit": 0.4, "two": true, "keys": K._blow(0.0, 0.28, 0.2, 6, BK, L, 0.85)},
		{"len": 0.75, "hit": 0.36, "two": true, "keys": K._blow(0.0, 0.24, 0.16, -8, ST, BK, 0.75)},
		{"len": 0.95, "hit": 0.3, "two": true, "keys": K._blow(0.0, 0.18, 0.42, 0, BK, W, 0.95)},
		{"len": 1.45, "hit": 0.78, "two": true, "keys": K._blow(0.0, 0.66, 0.24, 0, BK, L, 1.45)},
	]
