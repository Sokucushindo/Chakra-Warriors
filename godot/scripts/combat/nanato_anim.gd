extends RefCounted
## Nanatō — Killer B'nin Akurobatto (Acrobat) kılıç stili. Kaynak: Naruto Shippūden B–Sasuke dövüşü (_tmp/vid/bee/sasbee.mp4,
## 0:00 duruş, 0:22-0:58 dans, 1:57-2:10 bitiriş) + Narutopedia "Acrobat": yedi kılıç ELDE DEĞİL — ağız, boynun sağı, sol koltuk
## altı, iki dirsek, sağ diz arkası ve karında tutulur (CharacterModel._nanato_attach). Kılıçları gövdenin dansı savurur:
## hip-hop omuz atışı, baş savurma, yerde süpürme, breakdance dönüşü; açık bulunca birkaç ağız birden saplanır.
## 1 Kuchi Giri: baş ve gövde sertçe yana savrulur — ağızdaki kılıç yatay keser
## 2 Hiji Uchi: sağ dirsek öne fırlar (dirsek kılıcı saplanır), omuz atışıyla sol dirsek
## 3 Hiza Barai: yere çöküp sağ bacak yana açık tam tur — diz arkasındaki kılıç yerden biçer
## 4 Senpū Akurobatto: kollar açık iki tur dönüş, bütün ağızlar çember çizer, sonda havaya savurur
## 5 Nage Ken: boyundaki iki kılıcı kapıp orta menzile fırlatır (KeyedCombos.on_strike)
## 6 Hachi no Hari (bitiriş, "kelebek gibi süzül, arı gibi sok"): sağa-sola ritim salınımı, sonra öne patlayan atılış —
##   dirsekler, diz ve ağız aynı anda saplanır

const S = preload("res://scripts/combat/samehada_anim.gd")

# kollar (model uzayı: +Z ön, +X karakterin solu)
const R_GUARD := {"RightUpperArm": Vector3(-0.85, 0.1, 0.35), "RightLowerArm": Vector3(-0.1, 0.95, 0.25)}     # dirsek yanda-yukarı, ön kol dik
const L_GUARD := {"LeftUpperArm": Vector3(0.85, 0.1, 0.35), "LeftLowerArm": Vector3(0.1, 0.95, 0.25)}
const R_ELBOW := {"RightUpperArm": Vector3(-0.15, 0.15, 0.98), "RightLowerArm": Vector3(0.25, 0.25, -0.93)}    # dirsek öne, yumruk omza katlı
const L_ELBOW := {"LeftUpperArm": Vector3(0.15, 0.15, 0.98), "LeftLowerArm": Vector3(-0.25, 0.25, -0.93)}
const R_COCK := {"RightUpperArm": Vector3(-0.6, -0.2, -0.75), "RightLowerArm": Vector3(0.1, 0.4, 0.9)}        # dirsek geride kurulu
const L_COCK := {"LeftUpperArm": Vector3(0.6, -0.2, -0.75), "LeftLowerArm": Vector3(-0.1, 0.4, 0.9)}
const R_WIDE := {"RightUpperArm": Vector3(-0.98, 0.05, 0.15), "RightLowerArm": Vector3(-0.95, 0.1, 0.3)}
const L_WIDE := {"LeftUpperArm": Vector3(0.98, 0.05, 0.15), "LeftLowerArm": Vector3(0.95, 0.1, 0.3)}
const R_HIGH := {"RightUpperArm": Vector3(-0.4, 0.9, 0.15), "RightLowerArm": Vector3(0.3, 0.9, -0.3)}         # el başın üstünde (ref Acrobat.PNG)
const L_LOW := {"LeftUpperArm": Vector3(0.45, -0.85, 0.3), "LeftLowerArm": Vector3(-0.3, -0.4, 0.86)}
const R_NECK := {"RightUpperArm": Vector3(-0.35, 0.6, 0.7), "RightLowerArm": Vector3(0.55, 0.75, -0.35)}      # sağ el boynundaki kılıca
const L_NECK := {"LeftUpperArm": Vector3(0.35, 0.6, 0.7), "LeftLowerArm": Vector3(-0.55, 0.75, -0.35)}
const R_FLING := {"RightUpperArm": Vector3(-0.15, 0.25, 0.96), "RightLowerArm": Vector3(-0.05, 0.1, 1)}       # fırlatış: kol öne savrulmuş
const L_FLING := {"LeftUpperArm": Vector3(0.15, 0.25, 0.96), "LeftLowerArm": Vector3(0.05, 0.1, 1)}

# bacaklar
const KNEE_UP := {"RightUpperLeg": Vector3(-0.25, -0.05, 0.97), "RightLowerLeg": Vector3(-0.1, -0.95, 0.25), "RightFoot": Vector3(-0.1, -0.4, 0.9),
	"LeftUpperLeg": Vector3(0.25, -0.95, 0.12), "LeftLowerLeg": Vector3(0.05, -0.97, -0.15), "LeftFoot": Vector3(0.05, -0.45, 0.9)}   # duruş: sağ diz yüksek
const SWEEP := {"RightUpperLeg": Vector3(-0.95, -0.3, 0.1), "RightLowerLeg": Vector3(-0.97, -0.2, 0.1), "RightFoot": Vector3(-0.7, -0.2, 0.7),
	"LeftUpperLeg": Vector3(0.3, -0.5, 0.8), "LeftLowerLeg": Vector3(0.1, -0.97, -0.2), "LeftFoot": Vector3(0.05, -0.4, 0.9)}       # yerde süpürme
const SQUAT := {"RightUpperLeg": Vector3(-0.45, -0.35, 0.82), "RightLowerLeg": Vector3(-0.1, -0.97, -0.2), "RightFoot": Vector3(-0.15, -0.4, 0.9),
	"LeftUpperLeg": Vector3(0.45, -0.35, 0.82), "LeftLowerLeg": Vector3(0.1, -0.97, -0.2), "LeftFoot": Vector3(0.15, -0.4, 0.9)}     # geniş çömelik (ritim)


static func _t(t: float, crouch: float, yaw: float, lean: float, r: Dictionary, l: Dictionary, legs: Dictionary) -> Dictionary:
	return S._k(t, crouch, yaw, lean, Vector3(0, 0, 1), S._a(r, l), legs)


static func steps() -> Array:
	var W = S.LEG_WIDE
	var L = S.LEG_LUNGE
	var LL = S.mirror(S.LEG_LUNGE)
	var BK = S.LEG_BACK
	var CR = S.LEG_CROSS
	var KU = KNEE_UP
	var KUL = S.mirror(KNEE_UP)
	return [
		# 1 Kuchi Giri: sola kurulma (baş geride) -> gövde ve baş sağa savrulur, ağız kılıcı yatay keser; ritimle geri
		{"len": 0.62, "hit": 0.26, "keys": [
			_t(0.0, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
			_t(0.12, 0.46, 55, -12, R_GUARD, L_WIDE, BK),
			_t(0.2, 0.46, 60, -14, R_GUARD, L_WIDE, BK),
			_t(0.26, 0.52, -55, 14, R_WIDE, L_GUARD, L),
			_t(0.38, 0.5, -62, 12, R_WIDE, L_GUARD, L),
			_t(0.62, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
		]},
		# 2 Hiji Uchi: sağ dirsek geride kurulu -> öne fırlar (saplanır), omuz atışı -> sol dirsek
		{"len": 0.78, "hit": 0.22, "extra_hits": [0.48], "extra_radius": 1.5, "keys": [
			_t(0.0, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
			_t(0.12, 0.48, 28, -6, R_COCK, L_GUARD, BK),
			_t(0.22, 0.54, -24, 22, R_ELBOW, L_COCK, L),
			_t(0.34, 0.5, -10, 10, R_GUARD, L_COCK, CR),
			_t(0.48, 0.56, 26, 22, R_COCK, L_ELBOW, LL),
			_t(0.6, 0.52, 22, 16, R_GUARD, L_ELBOW, LL),
			_t(0.78, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
		]},
		# 3 Hiza Barai: yere çöker, sağ bacak yana açık tam tur — diz kılıcı yerden biçer
		{"len": 0.9, "hit": 0.4, "extra_hits": [0.6], "extra_radius": 2.2, "keys": [
			_t(0.0, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
			_t(0.14, 0.78, -20, 18, R_WIDE, L_LOW, SQUAT),
			_t(0.28, 0.86, 80, 22, R_WIDE, L_LOW, SWEEP),
			_t(0.46, 0.86, 200, 22, R_WIDE, L_LOW, SWEEP),
			_t(0.64, 0.86, 330, 20, R_WIDE, L_LOW, SWEEP),
			_t(0.76, 0.7, 360, 12, R_GUARD, L_GUARD, SQUAT),
			_t(0.9, 0.42, 360, 4, R_GUARD, L_GUARD, KU),
		]},
		# 4 Senpū Akurobatto: kollar açık iki tur — bütün ağızlar çember çizer, sonda rakip havaya
		{"len": 1.0, "hit": 0.3, "extra_hits": [0.55, 0.78], "extra_radius": 2.6, "keys": [
			_t(0.0, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
			_t(0.12, 0.5, -40, -6, R_WIDE, L_WIDE, CR),
			_t(0.3, 0.52, 140, 8, R_WIDE, L_WIDE, W),
			_t(0.48, 0.5, 320, 6, R_HIGH, L_WIDE, KU),
			_t(0.66, 0.52, 500, 8, R_WIDE, L_WIDE, CR),
			_t(0.84, 0.5, 690, 14, R_WIDE, L_WIDE, W),
			_t(1.0, 0.42, 720, 4, R_GUARD, L_GUARD, KU),
		]},
		# 5 Nage Ken: iki el boynundaki / koltuk altındaki kılıçlara -> öne savurup fırlatır (orta menzil)
		{"len": 0.8, "hit": 0.34, "keys": [
			_t(0.0, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
			_t(0.14, 0.44, 18, -14, R_NECK, L_NECK, BK),
			_t(0.26, 0.44, 22, -16, R_NECK, L_NECK, BK),
			_t(0.34, 0.54, -10, 24, R_FLING, L_FLING, L),
			_t(0.5, 0.52, -6, 20, R_FLING, L_FLING, L),
			_t(0.8, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
		]},
		# 6 Hachi no Hari (bitiriş): sağa-sola ritim salınımı -> öne patlayan atılış, dirsekler + diz + ağız birden saplanır
		{"len": 1.35, "hit": 0.86, "keys": [
			_t(0.0, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
			_t(0.16, 0.6, 30, 6, R_HIGH, L_GUARD, SQUAT),
			_t(0.32, 0.62, -30, 6, R_GUARD, L_WIDE, SQUAT),
			_t(0.48, 0.6, 30, 6, R_HIGH, L_GUARD, SQUAT),
			_t(0.68, 0.7, 0, -14, R_COCK, L_COCK, BK),
			_t(0.78, 0.72, 0, -16, R_COCK, L_COCK, BK),
			_t(0.86, 0.58, 0, 34, R_ELBOW, L_ELBOW, KUL),
			_t(1.08, 0.56, 0, 30, R_ELBOW, L_ELBOW, KUL),
			_t(1.35, 0.42, 0, 4, R_GUARD, L_GUARD, KU),
		]},
	]
