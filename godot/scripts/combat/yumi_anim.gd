extends RefCounted
## Yumi (uzun yay) kombosu. SOL elde yay, SAĞ el oku tutup kirişi çeker (kyūdō düzeni; ref: refs/yumi/HikaruTsuki.png, Taruho.png,
## Spider_War_Bow_Terrible_Split.png). Gövde yana döner, sol kol hedefe uzanır, sağ el çeneye gelir; kiriş ve yay kolları sağ eli izler
## (YumiFX.Rig). Vuruş anı = bırakış. Okların hepsi YumiFX.strike'tan çıkar (oyuncu + düşman aynı).
## 1 Hayauchi, 2 Tsugi-ya, 3 Tsuranuki (tam çekiş, delip geçer), 4 Hiki-uchi (geri sıçrarken), 5 Ya-ame (ok yağmuru),
## 6 Ito-ya (chakra iple güdülen ok; kanon: Kidōmaru ipli oku, Fūma klanı okçuluk + chakra ipi).

const S = preload("res://scripts/combat/samehada_anim.gd")

const FWD := Vector3(0, 0, 1)
# sağ kol: bekle / sadaktan ok al / kirişe tak / tam çekiş (el çenede) / bırakış
const R_LOW := {"RightUpperArm": Vector3(-0.22, -0.92, 0.3), "RightLowerArm": Vector3(0.0, -0.45, 0.9)}
const R_QUIVER := {"RightUpperArm": Vector3(-0.8, 0.3, -0.45), "RightLowerArm": Vector3(0.3, 0.95, 0.1)}   # başın sağ arkası: sadaktaki oka uzanır
const R_NOCK := {"RightUpperArm": Vector3(-0.2, -0.1, 0.97), "RightLowerArm": Vector3(0.35, 0.05, 0.94)}
const R_FULL := {"RightUpperArm": Vector3(-0.58, 0.21, 0.78), "RightLowerArm": Vector3(0.93, 0.02, 0.37)}
const R_LOOSE := {"RightUpperArm": Vector3(-0.75, 0.2, 0.3), "RightLowerArm": Vector3(-0.3, 0.3, -0.9)}
# yukarı nişan (ok yağmuru)
const R_FULL_UP := {"RightUpperArm": Vector3(-0.58, 0.45, 0.68), "RightLowerArm": Vector3(0.85, 0.35, 0.38)}
const R_LOOSE_UP := {"RightUpperArm": Vector3(-0.75, 0.45, 0.2), "RightLowerArm": Vector3(-0.3, 0.55, -0.75)}
# sol kol: yay kolu
const L_REST := {"LeftUpperArm": Vector3(0.25, -0.9, 0.3), "LeftLowerArm": Vector3(0.1, -0.4, 0.9)}
const L_BOW := {"LeftUpperArm": Vector3(0.03, 0.02, 1), "LeftLowerArm": Vector3(0.0, 0.0, 1)}
const L_BOW_UP := {"LeftUpperArm": Vector3(0.03, 0.55, 0.83), "LeftLowerArm": Vector3(0.0, 0.58, 0.81)}

## kirişin parmağa takıldığı an (sn): YumiFX bu anda ipi ele bağlar (R_NOCK anahtarlarıyla aynı)
const HOOK := [0.14, 0.1, 0.32, 0.2, 0.3, 0.42]


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw * 1.3, lean * 1.2, FWD, S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var BK = S.LEG_BACK
	var ST = S.LEG_STEP
	var C = S.LEG_CROSS
	return [
		# 1 Hayauchi: kısa çekiş, çabuk bırakış
		{"len": 0.82, "hit": 0.44, "keys": [
			_t(0.0, 0.34, -10, 2, R_LOW, L_REST, W),
			_t(0.14, 0.36, -30, 0, R_NOCK, L_BOW, W),
			_t(0.36, 0.38, -50, -3, R_FULL, L_BOW, W),
			_t(0.44, 0.38, -50, -3, R_FULL, L_BOW, W),
			_t(0.5, 0.38, -54, -5, R_LOOSE, L_BOW, W),
			_t(0.82, 0.34, -20, 2, R_LOW, L_REST, W),
		]},
		# 2 Tsugi-ya: bir önceki bırakıştan doğrudan yeni ok (sadağa uzanmadan, çok kısa)
		{"len": 0.72, "hit": 0.36, "keys": [
			_t(0.0, 0.36, -30, 0, R_LOOSE, L_BOW, W),
			_t(0.1, 0.36, -36, 0, R_NOCK, L_BOW, W),
			_t(0.3, 0.38, -50, -3, R_FULL, L_BOW, W),
			_t(0.36, 0.38, -50, -3, R_FULL, L_BOW, W),
			_t(0.42, 0.38, -54, -5, R_LOOSE, L_BOW, W),
			_t(0.72, 0.34, -20, 2, R_LOW, L_REST, W),
		]},
		# 3 Tsuranuki: sadaktan ok, en geniş duruş, uzun bekleyiş; ok görülmeyecek kadar hızlı çıkar
		{"len": 1.25, "hit": 0.82, "keys": [
			_t(0.0, 0.34, -10, 2, R_LOW, L_REST, W),
			_t(0.16, 0.34, -20, -4, R_QUIVER, L_BOW, BK),
			_t(0.32, 0.4, -36, 0, R_NOCK, L_BOW, W),
			_t(0.62, 0.46, -56, -6, R_FULL, L_BOW, W),
			_t(0.82, 0.47, -57, -7, R_FULL, L_BOW, W),
			_t(0.87, 0.44, -62, -11, R_LOOSE, L_BOW, W),
			_t(1.25, 0.34, -20, 2, R_LOW, L_REST, W),
		]},
		# 4 Hiki-uchi: geriye sıçrar (YumiFX.start), havada çekip bırakır: yaklaşanı karşılar
		{"len": 0.95, "hit": 0.52, "keys": [
			_t(0.0, 0.5, -20, 8, R_NOCK, L_REST, ST),
			_t(0.2, 0.2, -36, -4, R_NOCK, L_BOW, ST),
			_t(0.44, 0.18, -52, -8, R_FULL, L_BOW, C),
			_t(0.52, 0.2, -52, -8, R_FULL, L_BOW, C),
			_t(0.58, 0.24, -56, -10, R_LOOSE, L_BOW, W),
			_t(0.95, 0.34, -20, 2, R_LOW, L_REST, W),
		]},
		# 5 Ya-ame: yay göğe kalkar, art arda yüksek yaylı oklar hedefin üstüne iner
		{"len": 1.2, "hit": 0.68, "keys": [
			_t(0.0, 0.34, -10, 2, R_LOW, L_REST, W),
			_t(0.14, 0.34, -20, -4, R_QUIVER, L_BOW_UP, BK),
			_t(0.3, 0.38, -36, -8, R_NOCK, L_BOW_UP, W),
			_t(0.56, 0.42, -52, -16, R_FULL_UP, L_BOW_UP, W),
			_t(0.68, 0.42, -52, -16, R_FULL_UP, L_BOW_UP, W),
			_t(0.74, 0.4, -56, -18, R_LOOSE_UP, L_BOW_UP, W),
			_t(0.95, 0.4, -54, -16, R_LOOSE_UP, L_BOW_UP, W),
			_t(1.2, 0.34, -20, 2, R_LOW, L_REST, W),
		]},
		# 6 Ito-ya (bitiriş): diz çöker, en uzun çekiş; bırakınca sağ el ipi tutar, oku yönlendirir
		{"len": 1.65, "hit": 1.0, "keys": [
			_t(0.0, 0.34, -10, 2, R_LOW, L_REST, W),
			_t(0.2, 0.42, -20, -4, R_QUIVER, L_BOW, BK),
			_t(0.42, 0.56, -38, 2, R_NOCK, L_BOW, BK),
			_t(0.8, 0.62, -58, -4, R_FULL, L_BOW, BK),
			_t(1.0, 0.63, -59, -5, R_FULL, L_BOW, BK),
			_t(1.06, 0.6, -60, -8, R_LOOSE, L_BOW, BK),
			_t(1.4, 0.56, -56, -6, R_LOOSE, L_BOW, BK),
			_t(1.65, 0.34, -20, 2, R_LOW, L_REST, W),
		]},
	]
