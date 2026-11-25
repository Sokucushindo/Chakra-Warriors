extends RefCounted
## Kusanagi no Tsurugi modeli (Sasuke'nin chokutō'su). Ref: refs/kin/Sword_of_Kusanagi_Sasuke_Uchiha_.png (yakın kesit
## _tmp/wref/kusa_hilt.png, kusa_tip.png). Ref özellikleri: tsuba YOK; koyu arduvaz renkli, köşeleri yuvarlatılmış dikdörtgen
## kesitli uzun sap (yüzünde boyuna oluk), sapın ağza bağlandığı yerde kısa açık gri metal bilezik (öne doğru pahlı, tek pim),
## ince düz tek ağızlı parlak çelik ağız; sırta yakın boyuna shinogi çizgisi, ucu keskin ağzın sırta doğru kalkmasıyla oluşan eğik uç.
## Oranlar ref'ten: ağız / sap ~3.5, sap kalınlığı ~ ağız eninin 1.3 katı. Ağızın kökü sapın içine girer (boşluk yok).
## Kabza 0 (yumruk), ağız +Z, yassı yüz X, keskin ağız +Y (elde +Y aşağı bakar: ağız aşağıda, sırt yukarıda).

const BL = preload("res://scripts/actors/blade_loft.gd")

const Z_POMMEL := -0.115
const Z_COLLAR := 0.14
const Z_BLADE := 0.178      # ağzın bilezikten çıktığı yer
const Z_TIP := 1.075
const TIP_LEN := 0.1


static func build(b: MB) -> void:
	var steel = Color(0.8, 0.82, 0.86)
	var steel_d = Color(0.6, 0.62, 0.67)
	var edge = Color(0.97, 0.98, 1.0)
	var mune = Color(0.5, 0.52, 0.57)
	var handle = Color(0.19, 0.2, 0.25)
	var metal = Color(0.74, 0.75, 0.78)
	_blade(b, steel, steel_d, edge, mune)
	_handle(b, handle)
	_collar(b, metal)


## Ağız: 7 köşeli kesit — keskin ağız (0), ağız şevi, ji yüzü, shinogi çizgisi, shinogi-ji, sırt köşesi; uçta keskin ağız sırta kalkar
static func _blade(b: MB, steel: Color, steel_d: Color, edge: Color, mune: Color) -> void:
	var secs := []
	var zs := []
	var z_tip0 := Z_TIP - TIP_LEN
	var zl := [0.12, Z_BLADE]
	var k := 1
	while Z_BLADE + k * 0.08 < z_tip0:
		zl.append(Z_BLADE + k * 0.08)
		k += 1
	for u in [0.0, 0.08, 0.18, 0.3, 0.45, 0.6, 0.75, 0.88, 0.96, 1.0]:
		zl.append(z_tip0 + u * TIP_LEN)
	for z in zl:
		var t_len := clampf((z - Z_BLADE) / (z_tip0 - Z_BLADE), 0.0, 1.0)
		var w := lerpf(0.0145, 0.0125, t_len)        # yarı en (sırttan ağza toplam 2w)
		var th := lerpf(0.0042, 0.0034, t_len)       # shinogi'de yarı kalınlık
		var u := clampf((z - z_tip0) / TIP_LEN, 0.0, 1.0)
		var ys := -w                                  # sırt düz
		var ye := -w + 2.0 * w * pow(1.0 - pow(u, 1.25), 0.75)   # keskin ağız uçta sırta kalkar (eğik kesik uç)
		var f := lerpf(0.34, 0.04, clampf(u / 0.3, 0.0, 1.0))      # shinogi çizgisi uçta sırta kavuşur
		th *= lerpf(1.0, 0.18, pow(u, 0.8))
		var span := ye - ys
		var y_sh := ys + span * f
		var y_bv := ys + span * 0.84
		secs.append(PackedVector2Array([
			Vector2(0.0, ye), Vector2(th * 0.32, y_bv), Vector2(th, y_sh), Vector2(th * 0.72, ys),
			Vector2(-th * 0.72, ys), Vector2(-th, y_sh), Vector2(-th * 0.32, y_bv)]))
		zs.append(z)
	# yüz renkleri: 0 ağız şevi, 1 ji, 2 shinogi-ji, 3 sırt, 4 shinogi-ji, 5 ji, 6 ağız şevi
	BL.loft(b, secs, zs, [edge, steel, steel_d, mune, steel_d, steel, edge], true, true, true)


## Sap: köşeleri yuvarlatılmış dikdörtgen kesit (en Y, kalınlık X), dipte hafif dudaklı kesik uç; iki yassı yüzde boyuna oluk
static func _handle(b: MB, col: Color) -> void:
	var secs := []
	var zs := []
	var zl := [Z_POMMEL, Z_POMMEL + 0.004, Z_POMMEL + 0.012, Z_POMMEL + 0.016]
	for k in 7:
		zl.append(lerpf(Z_POMMEL + 0.03, Z_COLLAR, k / 6.0))
	for z in zl:
		var s := 1.0
		if z < Z_POMMEL + 0.013:
			s = 1.07 if z > Z_POMMEL + 0.002 else 1.0   # dip dudağı
		else:
			s = lerpf(0.97, 1.0, clampf((z - Z_POMMEL) / 0.12, 0.0, 1.0))
		secs.append(BL.oval(0.0155 * s, 0.0186 * s, 20, 0.45))
		zs.append(z)
	BL.loft(b, secs, zs, [col], false, true, true)
	b.add("box", Vector3(0, 0, Z_POMMEL - 0.0005), Vector3(0.026, 0.031, 0.002), col.darkened(0.25))   # kesik uç yüzü (koyu)
	for sx in [-1.0, 1.0]:
		# boyuna oluk: koyu ince çizgi + üstünde açık kenar (ref: sap yüzünde iki paralel çizgi)
		b.add("box", Vector3(sx * 0.0153, -0.004, (Z_POMMEL + Z_COLLAR) * 0.5 + 0.008), Vector3(0.0012, 0.0035, Z_COLLAR - Z_POMMEL - 0.04), col.darkened(0.45))
		b.add("box", Vector3(sx * 0.0151, 0.0005, (Z_POMMEL + Z_COLLAR) * 0.5 + 0.008), Vector3(0.0012, 0.0012, Z_COLLAR - Z_POMMEL - 0.04), col.lightened(0.22))


## Bilezik (fuchi + habaki tek parça): sapla aynı kesitte başlar, öne doğru pahlanıp ağzı sarar; yassı yüzde tek pim
static func _collar(b: MB, col: Color) -> void:
	var secs := [
		BL.oval(0.0162, 0.0193, 20, 0.45),
		BL.oval(0.0164, 0.0195, 20, 0.45),
		BL.oval(0.0164, 0.0195, 20, 0.45),
		BL.oval(0.0075, 0.0162, 20, 0.6),
	]
	var zs := [Z_COLLAR - 0.004, Z_COLLAR + 0.002, Z_COLLAR + 0.024, Z_BLADE]
	BL.loft(b, secs, zs, [col], false, true, true)
	b.add("cyl", Vector3(0, 0, Z_COLLAR - 0.002), Vector3(0.034, 0.003, 0.04), col.darkened(0.35), Vector3(90, 0, 0), 20)   # sap birleşim çizgisi
	for sx in [-1.0, 1.0]:
		b.add("cyl", Vector3(sx * 0.0163, -0.002, Z_COLLAR + 0.012), Vector3(0.006, 0.0016, 0.006), Color(0.2, 0.2, 0.22), Vector3(0, 0, 90), 10)   # pim
