extends RefCounted
## Animeden eklenen kanon kıyafetlerin 3B ayrıntısı (hedef: res://scripts/actors/set_v2_e.gd). Kaynak görseller: refs/kiyafet/<tür>/.

const A = preload("res://scripts/actors/set_v2_a.gd")

const SETS := ["set_rengo", "set_keimu", "set_oto", "set_aburame", "set_shugonin", "set_kaguya", "set_oto_yonin", "set_taki", "set_uzushio", "set_jinmon", "set_kusa", "set_yu", "set_shimo", "set_tani", "set_yamanaka", "set_kurama", "set_chinoike", "set_iburi", "set_funato", "set_hagoromo", "set_oinin", "set_konoha_eski", "set_iwa_eski", "set_sansho", "set_kumo_uta", "set_kumo_kenshi", "set_kumo_kunoichi", "set_aogiri", "set_iwa_kunoichi", "set_kuro_iryo", "set_uzumaki_haha", "set_tetsu_sho", "set_taka_kunoichi", "set_taka_kenshi", "set_nidaime_koromo", "set_uzushio_hime", "set_kumo_kyodai", "set_kiri_kenshi", "set_kurosuki", "set_kiri_kunoichi", "set_kiri_atki", "set_suna_rojo", "set_kazekiri", "set_shakunetsu", "set_yogan", "set_awa", "set_nanao", "set_nekomata", "set_genso"]

const G_SHINOBI := [[-0.6, 0.8, 0.5, 0.8], [0.5, 0.8, 0.35, 0.15], [-0.1, 0.8, -0.55, 0.15], [0.05, 0.55, 0.2, 0.4], [-0.6, -0.35, -0.75, -0.75], [-0.25, -0.25, -0.1, -0.85], [-0.1, -0.85, 0.4, -0.85], [0.15, -0.2, 0.3, -0.4], [0.65, -0.35, 0.8, -0.7]]
const G_SHI := [[-0.8, 0.8, 0.8, 0.8], [-0.2, 0.8, -0.7, -0.1], [-0.35, 0.35, 0.1, 0.35], [0.1, 0.35, -0.5, -0.75], [-0.3, 0.2, 0.0, -0.1], [0.35, 0.8, 0.35, -0.6], [0.35, -0.6, 0.85, -0.75], [0.35, 0.2, 0.8, 0.4]]
const G_HI := [[0.0, 0.85, 0.0, 0.2], [0.0, 0.2, -0.7, -0.85], [0.0, 0.2, 0.7, -0.85], [-0.55, 0.55, -0.3, 0.2], [0.55, 0.55, 0.3, 0.2]]

static var _cache := {}


static func build(m, sid: String, g: Dictionary) -> void:
	if not sid in SETS:
		return
	var key = "%s|%s" % [sid, str(m.look.get("gender", "m"))]
	if _cache.has(key):
		var e: Array = _cache[key]
		if e[0] != null:
			var mi = MeshInstance3D.new()
			mi.mesh = e[0]
			m.skel.add_child(mi)
			mi.skin = m.body_mesh.skin
			mi.skeleton = mi.get_path_to(m.skel)
			mi.material_override = Props.toon()
		A._dangles(m, e[1])
		return
	var c = A._begin(m)
	if c.is_empty():
		return
	match sid:
		"set_rengo": _rengo(c)
		"set_keimu": _keimu(c)
		"set_oto": _oto(c)
		"set_aburame": _aburame(c)
		"set_shugonin": _shugonin(c)
		"set_kaguya": _kaguya(c)
		"set_oto_yonin": _yonin(c)
		"set_yamanaka": _yamanaka(c)
		"set_suna_rojo": _suna_rojo(c)
		"set_kazekiri": _kazekiri(c)
		"set_shakunetsu": _shakunetsu(c)
		"set_yogan": _yogan(c)
		"set_awa": _awa(c)
		"set_nanao": _nanao(c)
		"set_nekomata": _nekomata(c)
		"set_genso": _genso(c)
		"set_taka_kunoichi": _taka_kunoichi(c)
		"set_taka_kenshi": _taka_kenshi(c)
		"set_nidaime_koromo": _nidaime(c)
		"set_uzushio_hime": _uzushio_hime(c)
		"set_kumo_kyodai": _kumo_kyodai(c)
		"set_kiri_kenshi": _kiri_kenshi(c)
		"set_kurosuki": _kurosuki(c)
		"set_kiri_kunoichi": _kiri_kunoichi(c)
		"set_kiri_atki": _kiri_atki(c)
		"set_sansho": _sansho(c)
		"set_kumo_uta": _kumo_uta(c)
		"set_kumo_kenshi": _kumo_kenshi(c)
		"set_kumo_kunoichi": _kumo_kunoichi(c)
		"set_aogiri": _aogiri(c)
		"set_iwa_kunoichi": _iwa_kunoichi(c)
		"set_kuro_iryo": _kuro_iryo(c)
		"set_uzumaki_haha": _uzumaki_haha(c)
		"set_tetsu_sho": _tetsu_sho(c)
		"set_kurama": _kurama(c)
		"set_chinoike": _chinoike(c)
		"set_iburi": _iburi(c)
		"set_funato": _funato(c)
		"set_hagoromo": _hagoromo(c)
		"set_oinin": _oinin(c)
		"set_konoha_eski": _konoha_eski(c)
		"set_iwa_eski": _iwa_eski(c)
		"set_taki": _taki(c)
		"set_uzushio": _uzushio(c)
		"set_jinmon": _jinmon(c)
		"set_kusa": _koy(c, A.K("3f6a34"), A.K("dfe6c8"))
		"set_yu": _koy(c, A.K("a8503a"), A.K("f0dcc8"))
		"set_shimo": _koy(c, A.K("7f93a8"), A.K("e6eef4"))
		"set_tani": _koy(c, A.K("7a6248"), A.K("e4d8c0"))
	var made = m._sk_end(g)
	_cache[key] = [made.mesh if made != null else null, c["dg"]]
	A._dangles(m, c["dg"])


## Yeleğin üstüne binen işaretler yelek kalınlığı kadar dışarıda durur
const VL := 0.058


static func _round(c: Dictionary, x: float, y: float, r: float, d: float, col: Color, front := true, lift := VL) -> void:
	for k in 3:
		A._plate(c, x, y, r * 1.8, r * 1.8, d, col, front, k * PI / 6.0, lift)


## Dördüncü Savaş yeleği (ref Wartime_flak_jacket): çapraz kayış, yuvarlak toka, parşömen cepleri; sırtta 忍
static func _rengo(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var dk = A.K("1c1e22"); var metal = A.K("a0a4a8")
	A._seam(c, [Vector2(-0.135, n - 0.05), Vector2(-0.03, ch - 0.04), Vector2(0.125, h + 0.09)], 0.018, 0.005, dk, true, VL)
	_round(c, -0.03, ch - 0.04, 0.026, 0.005, metal)
	_round(c, -0.03, ch - 0.04, 0.012, 0.005, dk, true, VL + 0.005)
	A._belt(c, h + 0.04, 0.03, dk, metal, 0.04)
	A._glyph(c, 0.0, ch - 0.01, 0.065, G_SHINOBI, 0.011, A.K("d4d7da"), false, VL)
	A._cuff(c, 0.94, 0.022, 0.004, dk)


## Konoha Askeri Polisi (ref Fugaku-KMPFU): dik yakalı yelek, kolda arma, baldırda baklava dizisi; sırtta yelpaze
static func _keimu(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]
	var ves = A.K("4f5848"); var dk = A.K("262c2a"); var lt = A.K("cfc8ae")
	A._neck(c, 0.0, 0.06, 0.016, ves, 0.15)
	A._zip(c, n - 0.03, h + 0.07, dk)
	for s in [-1.0, 1.0]:
		var bx: float = s * (float(c["UA"]) + 0.075)
		_round(c, bx, n - 0.05, 0.03, 0.004, A.K("1d2748"), true, 0.006)
		A._plate(c, bx, n - 0.05, 0.026, 0.026, 0.005, A.K("c0302a"), true, PI * 0.25, 0.012)
		for k in 3:
			A._plate(c, s * float(c["LX"]) + (k - 1) * 0.044, kn - 0.14, 0.032, 0.032, 0.004, lt, true, PI * 0.25, 0.014)
			A._plate(c, s * float(c["LX"]) + (k - 1) * 0.044, kn - 0.14, 0.032, 0.032, 0.004, lt, false, PI * 0.25, 0.014)
	_round(c, 0.0, ch + 0.035, 0.06, 0.005, A.K("c0302a"), false)
	A._plate(c, 0.0, ch + 0.0, 0.11, 0.055, 0.005, A.K("efeadf"), false, 0.0, VL + 0.004)
	A._plate(c, 0.0, ch - 0.07, 0.018, 0.085, 0.005, A.K("efeadf"), false, 0.0, VL)
	A._belt(c, h + 0.035, 0.026, dk, A.K("8a8e96"), 0.034)


## Otogakure (ref TeamDosu, Zaku): 死 yazılı açık üst, kırmızı ip kuşak, düzensiz mor-gri lekeli pantolon
static func _blot(c: Dictionary, x: float, y: float, r: float, col: Color, front: bool, sd: int) -> void:
	for k in 4:
		var a = sd * 2.4 + k * 1.9
		A._disc(c, x + cos(a) * r * 0.75, y + sin(a) * r * 0.5, r * (0.42 + 0.13 * k), 0.003, col, front)


static func _oto(c: Dictionary) -> void:
	var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]
	var ink = A.K("3a2a24"); var cam = A.K("3d3850")
	for k in 3:
		A._glyph(c, 0.0, ch + 0.035 - k * 0.083, 0.034, G_SHI, 0.007, ink)
	A._ring(c, h + 0.035, 0.018, 0.009, A.K("a8322c"))
	var B = [[0.02, 0.06, 0.05], [-0.03, 0.2, 0.04], [0.035, 0.32, 0.046], [-0.02, 0.44, 0.034]]
	for s in [-1.0, 1.0]:
		var i = 0
		for b in B:
			i += 1
			var y: float = lerpf(h - 0.06, kn - 0.26, float(b[1]) / 0.5)
			_blot(c, s * float(c["LX"]) + s * float(b[0]), y, float(b[2]), cam, true, i)
			_blot(c, s * float(c["LX"]) - s * float(b[0]), y - 0.04, float(b[2]) * 0.85, cam, false, i + 3)
		A._ring(c, kn - 0.3, 0.02, 0.004, A.K("2c2a36"), -PI, PI, 0.004, s)


## Aburame (ref Shino, Shibi): boydan kapanan kapüşonlu uzun yeşil palto, yan cepler, biyeli etek ucu
static func _aburame(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var dk = A.K("3f4a30"); var lt = A.K("7d8a62")
	for s in [-1.0, 1.0]:
		A._plate(c, s * 0.115, h - 0.08, 0.075, 0.09, 0.005, dk.lightened(0.12), true, s * 0.12, 0.012)
		A._seam(c, [Vector2(s * 0.155, h - 0.035), Vector2(s * 0.08, h - 0.03)], 0.005, 0.003, dk, true, 0.016)
		A._seam(c, [Vector2(s * 0.14, n - 0.1), Vector2(s * 0.13, h + 0.05)], 0.005, 0.002, dk)
	A._stitch(c, Vector2(-0.14, n - 0.08), Vector2(0.14, n - 0.08), 16, lt)
	A._stitch(c, Vector2(-0.14, n - 0.08), Vector2(0.14, n - 0.08), 16, lt, false)
	A._cuff(c, 0.9, 0.03, 0.005, dk)


## On İki Muhafız Ninja (ref Loyal_Guardian_Ninja, Chiriku): keşiş giysisi, belden sarkan 火 kuşağı
static func _shugonin(c: Dictionary) -> void:
	var h: float = c["H"]
	var sash = A.K("d8d2c0"); var ink = A.K("23201c")
	A._ring(c, h + 0.03, 0.085, 0.009, sash)
	A._glyph(c, 0.0, h + 0.03, 0.033, G_HI, 0.008, ink, true, 0.014)
	A._glyph(c, 0.0, h + 0.03, 0.033, G_HI, 0.008, ink, false, 0.014)
	A._dg(c, "Hips", Vector3(0.11, h - 0.01, 0.125), Vector3(0.05, -1.0, 0.05).normalized(), 0.34, 0.075, sash, 0.25)
	for s in [-1.0, 1.0]:
		A._wraps(c, s, float(c["Kn"]) - 0.24, float(c["Kn"]) - 0.06, 5, 0.022, A.K("d8d2c0"))


## Kaguya (ref Kaguya_Men, Kimimaro): açık gri kimono, çapraz yaka, kalın mor burgu ip ve sarkan ucu
static func _kaguya(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var pur = A.K("5a4a86"); var lt = A.K("857ab0"); var ln = A.K("80828c")
	A._seam(c, [Vector2(-0.07, n - 0.01), Vector2(0.05, n - 0.22), Vector2(0.09, h + 0.08)], 0.01, 0.004, ln)
	A._seam(c, [Vector2(0.07, n - 0.01), Vector2(0.015, n - 0.11)], 0.01, 0.004, ln)
	A._ring(c, h + 0.05, 0.034, 0.015, pur)
	for k in 14:
		A._ring(c, h + 0.036 + 0.0021 * k, 0.003, 0.017, lt, -PI + k * 0.45, -PI + k * 0.45 + 0.2)
	A._dg(c, "Hips", Vector3(-0.14, h + 0.03, -0.1), Vector3(-0.1, -1.0, -0.12).normalized(), 0.5, 0.04, pur, 0.22)
	A._dg(c, "Hips", Vector3(-0.09, h + 0.03, -0.13), Vector3(0.0, -1.0, -0.1).normalized(), 0.38, 0.032, lt, 0.22)


## Oto Dörtlüsü (ref Full_Tayuya, Versus_Sound_Four): açık bej tunik, önü açık etek parçası, bilekte koyu kolluk
static func _yonin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var ln = A.K("9c9078")
	A._seam(c, [Vector2(-0.07, n - 0.01), Vector2(0.03, n - 0.16), Vector2(0.05, h + 0.12)], 0.009, 0.004, ln)
	A._seam(c, [Vector2(0.07, n - 0.01), Vector2(0.02, n - 0.1)], 0.009, 0.004, ln)
	A._stitch(c, Vector2(-0.13, h - 0.14), Vector2(0.13, h - 0.14), 14, ln)
	A._cuff(c, 0.92, 0.05, 0.006, A.K("2a2830"))


## Takigakure (ref Shibuki1): deniz mavisi üst, çapraz koyu kuşak, biyeli yaka ve manşet
static func _taki(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var dk = A.K("1f3a5a"); var lt = A.K("7fc0c4")
	A._neck(c, 0.0, 0.045, 0.01, lt, 0.14)
	A._seam(c, [Vector2(0.13, n - 0.05), Vector2(0.0, n - 0.2), Vector2(-0.125, h + 0.08)], 0.02, 0.005, dk, true, 0.012)
	A._seam(c, [Vector2(0.13, n - 0.05), Vector2(0.0, n - 0.2), Vector2(-0.125, h + 0.08)], 0.02, 0.005, dk, false, 0.012)
	A._belt(c, h + 0.035, 0.03, dk, A.K("9fb0b8"), 0.034)
	A._cuff(c, 0.94, 0.026, 0.004, lt)


## Uzushio / Uzumaki (ref Ashina_Uzumaki, Uzumaki-Senju_clans): koyu kahve zırh, sırtta kızıl girdap, omuzda burgu ip
static func _uzushio(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var red = A.K("b8322a"); var rope = A.K("d8cfb8")
	A._spiral(c, 0.0, ch + 0.0, 0.075, 2.0, 0.014, red, false)
	A._spiral(c, 0.0, ch - 0.06, 0.04, 1.7, 0.009, red, true)
	A._ring(c, h + 0.05, 0.03, 0.012, rope)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.14, n - 0.02), Vector2(s * 0.06, n - 0.14)], 0.016, 0.008, rope, true, VL * 0.6)


## Sorgu ve İşkence Birliği (ref Ibiki_Blazing): gri dik yakalı üniforma, kemer, uzun siyah palto
static func _jinmon(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var dk = A.K("24262c"); var m = A.K("8a8e96")
	A._neck(c, 0.0, 0.06, 0.014, A.K("555862"), 0.14)
	A._btns(c, 0.0, n - 0.08, h + 0.09, 5, 0.008, m)
	A._seam(c, [Vector2(0.0, n - 0.05), Vector2(0.0, h + 0.05)], 0.005, 0.002, dk)
	A._belt(c, h + 0.04, 0.03, dk, m, 0.042)


## Kendi üniforma kaynağı olmayan küçük köyler: köy renginde yelek, sırtta köy rengi arma, kolda bant
static func _koy(c: Dictionary, col: Color, lt: Color) -> void:
	var h: float = c["H"]; var ch: float = c["C"]
	_round(c, 0.0, ch + 0.01, 0.05, 0.005, lt, false)
	_round(c, 0.0, ch + 0.01, 0.028, 0.005, col, false, VL + 0.005)
	A._belt(c, h + 0.035, 0.026, A.K("23252a"), A.K("8a8e96"), 0.034)
	A._cuff(c, 0.94, 0.022, 0.004, col.darkened(0.25))
	for s in [-1.0, 1.0]:
		A._ring_x(c, s * (float(c["UA"]) + 0.08), 0.024, 0.004, col)


## Yamanaka (ref Inoichi_Full_Appearance): yelek üstüne kolsuz kızıl uzun üst, biyeli kenar
static func _yamanaka(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var lt = A.K("d8c07a"); var dk = A.K("1c2238")
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.085, n - 0.05), Vector2(s * 0.11, h + 0.05), Vector2(s * 0.12, h - 0.24)], 0.008, 0.003, lt, true, VL * 0.8)
	A._belt(c, h + 0.035, 0.024, dk, A.K("8a8e96"), 0.03)
	A._cuff(c, 0.94, 0.022, 0.004, dk)


## Kurama (ref Unkai_Kurama): açık gri kimono, turuncu ve yeşil kat yaka
static func _kurama(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var o = A.K("c8782e"); var g = A.K("4f7a62")
	A._seam(c, [Vector2(-0.075, n), Vector2(0.05, n - 0.2), Vector2(0.09, h + 0.08)], 0.016, 0.004, o)
	A._seam(c, [Vector2(-0.058, n), Vector2(0.066, n - 0.2), Vector2(0.105, h + 0.08)], 0.009, 0.005, g)
	A._seam(c, [Vector2(0.075, n), Vector2(0.015, n - 0.11)], 0.016, 0.004, o)
	A._ring(c, h + 0.04, 0.06, 0.008, A.K("3c4a58"))


## Chinoike (ref Chinoike_Clan): gri yolcu giysisi, koyu sargılar, kan kırmızısı bel bağı
static func _chinoike(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var dk = A.K("2a2a30"); var red = A.K("8e1f2a")
	A._neck(c, 0.0, 0.06, 0.014, dk, 0.15)
	A._ring(c, h + 0.04, 0.026, 0.009, red)
	A._dg(c, "Hips", Vector3(0.1, h + 0.03, 0.12), Vector3(0.05, -1.0, 0.05).normalized(), 0.3, 0.04, red, 0.25)
	A._seam(c, [Vector2(0.0, n - 0.03), Vector2(0.0, h + 0.07)], 0.006, 0.003, dk)
	for s in [-1.0, 1.0]:
		for k in 3:
			A._ring(c, kn - 0.08 - k * 0.07, 0.022, 0.005, dk, -PI, PI, 0.004, s)


## Iburi (ref Iburi_Ichizoku): köylü giysisi, yamalar, ip kuşak
static func _iburi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var pt = A.K("6a5a44"); var st = A.K("c8b89a")
	A._plate(c, 0.08, n - 0.2, 0.07, 0.06, 0.004, pt, true, 0.15, 0.006)
	A._stitch(c, Vector2(0.045, n - 0.17), Vector2(0.115, n - 0.17), 6, st)
	A._plate(c, -0.06, h + 0.14, 0.06, 0.05, 0.004, pt, false, -0.2, 0.006)
	A._ring(c, h + 0.04, 0.014, 0.008, A.K("b0a07c"))


## Funato (ref Shizuku): beyaz deniz cübbesi, mavi biye, geniş bel
static func _funato(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var b = A.K("3f6f9e")
	A._neck(c, 0.0, 0.05, 0.012, b, 0.15)
	A._seam(c, [Vector2(0.0, n - 0.03), Vector2(0.0, h + 0.07)], 0.012, 0.003, b)
	A._ring(c, h + 0.04, 0.05, 0.008, b)
	A._cuff(c, 0.92, 0.03, 0.005, b)


## Hagoromo (ref Kagero_in_disguise): koyu gri pelerin, boyunda kızıl bağ
static func _hagoromo(c: Dictionary) -> void:
	var n: float = c["N"]
	var red = A.K("8c2a30")
	A._neck(c, -0.01, 0.04, 0.03, red, 0.18)
	A._dg(c, "UpperChest", Vector3(0.0, n - 0.05, 0.15), Vector3(0.0, -1.0, 0.08).normalized(), 0.2, 0.05, red, 0.3)


## Kiri Av Ninjası (ref Anbu_Haku): koyu kimono, göğüste çapraz krem kuşak, çizgili etek
static func _oinin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var cr = A.K("cfc6a4"); var dk = A.K("2c2a24")
	A._seam(c, [Vector2(0.12, n - 0.04), Vector2(0.0, n - 0.2), Vector2(-0.12, h + 0.06)], 0.024, 0.005, cr, true, 0.01)
	A._seam(c, [Vector2(0.12, n - 0.04), Vector2(0.0, n - 0.2), Vector2(-0.12, h + 0.06)], 0.024, 0.005, cr, false, 0.01)
	A._ring(c, h + 0.04, 0.05, 0.009, cr)
	for k in 12:
		A._mer(c, -PI + k * TAU / 12.0, h - 0.04, kn + 0.04, 0.005, 0.002, dk)


## Eski Konoha yeleği (ref Konoha_flak_jacket_older): açık haki yelek, önde beyaz akış çizgileri, kolda girdap
static func _konoha_eski(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var w = A.K("e8e6d6"); var navy = A.K("161c3c")
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.12, ch - 0.02), Vector2(s * 0.07, ch - 0.12), Vector2(s * 0.11, h + 0.1)], 0.007, 0.003, w, true, VL)
		A._spiral(c, s * (float(c["UA"]) + 0.075), n - 0.045, 0.02, 1.6, 0.005, A.K("c03028"), true)
	A._spiral(c, 0.0, ch + 0.03, 0.05, 1.7, 0.01, A.K("c03028"), false)
	A._belt(c, h + 0.03, 0.024, navy, A.K("8a8e96"), 0.03)


## Eski Iwa yeleği (ref Old_Iwa_Flak_Jacket): gri yelek, karında büyük cep, koyu kemer
static func _iwa_eski(c: Dictionary) -> void:
	var h: float = c["H"]; var ch: float = c["C"]
	var g = A.K("5a5a66"); var dk = A.K("2c2a30")
	A._plate(c, 0.0, ch - 0.17, 0.17, 0.085, 0.008, g, true, 0.0, VL)
	A._seam(c, [Vector2(-0.085, ch - 0.13), Vector2(0.085, ch - 0.13)], 0.006, 0.003, dk, true, VL + 0.008)
	A._belt(c, h + 0.035, 0.03, dk, A.K("8a8e96"), 0.036)


## Yağmur ülkesi savaş ustası (ref Hanzo_full_appearance): gri giysi, göğüs zırhında sarmal, kayışlar
static func _sansho(c: Dictionary) -> void:
	var h: float = c["H"]; var ch: float = c["C"]
	var dk = A.K("34363a")
	A._spiral(c, 0.0, ch - 0.03, 0.055, 2.0, 0.009, dk, true)
	A._spiral(c, 0.0, ch - 0.0, 0.055, 2.0, 0.009, dk, false)
	A._belt(c, h + 0.04, 0.034, dk, A.K("8a8e96"), 0.044)
	A._cuff(c, 0.9, 0.05, 0.006, dk)
	A._dg(c, "Hips", Vector3(-0.13, h + 0.02, -0.08), Vector3(-0.1, -1.0, -0.08).normalized(), 0.34, 0.07, A.K("4a4c50"), 0.25)


## Kumo'nun gösterişli savaşçısı (ref B_body): kolsuz üst, belde kalın kırmızı-beyaz burgu ip, uzun beyaz bel örtüsü
static func _kumo_uta(c: Dictionary) -> void:
	var h: float = c["H"]
	var r = A.K("c0302a"); var w = A.K("eeeae0")
	A._ring(c, h + 0.05, 0.04, 0.016, r)
	for k in 12:
		A._ring(c, h + 0.035 + 0.0025 * k, 0.004, 0.018, w, -PI + k * 0.52, -PI + k * 0.52 + 0.2)
	for s in [-1.0, 1.0]:
		A._dg(c, "Hips", Vector3(s * 0.14, h + 0.02, 0.05), Vector3(s * 0.12, -1.0, 0.03).normalized(), 0.46, 0.1, w, 0.22)


## Kumo kılıç ustası (ref Darui_full_body): kolsuz koyu üst, tek omuzdan inen beyaz örtü, belden sarkan bez
static func _kumo_kenshi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var w = A.K("e8e6dc"); var g = A.K("4a4a48")
	for fr in [true, false]:
		A._seam(c, [Vector2(0.12, n - 0.03), Vector2(0.03, n - 0.18), Vector2(-0.1, h + 0.07)], 0.04, 0.005, w, fr, 0.008)
	A._ring(c, h + 0.03, 0.05, 0.009, g)
	A._dg(c, "Hips", Vector3(0.0, h - 0.02, 0.14), Vector3(0.0, -1.0, 0.05).normalized(), 0.38, 0.2, g, 0.25)


## Kumo kunoichi (ref Samui_full_body): gri kısa elbise, geniş açık gri kuşak, kolda bant
static func _kumo_kunoichi(c: Dictionary) -> void:
	var h: float = c["H"]
	A._ring(c, h + 0.08, 0.06, 0.008, A.K("c8c8cc"))
	A._ring(c, h + 0.115, 0.012, 0.009, A.K("8a2a4a"))
	A._cuff(c, 0.86, 0.06, 0.006, A.K("8a2a4a"))


## Kiri kıdemlisi (ref Ao_s_Appearance): koyu boğazlı üst, uzun deniz yeşili palto, krem yaka şeridi
static func _aogiri(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var cr = A.K("d8cfa8")
	A._neck(c, 0.0, 0.07, 0.016, A.K("3a3a3e"), 0.14)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.075, n - 0.02), Vector2(s * 0.085, n - 0.2), Vector2(s * 0.1, h + 0.02), Vector2(s * 0.11, h - 0.3)], 0.022, 0.005, cr, true, VL * 0.7)
	A._side_box(c, h + 0.0, 1.9, 0.0, 0.08, 0.07, 0.03, A.K("6a5238"), 0.03)


## Iwa kunoichi (ref Kurotsuchi_Online): kahve yelek, kızıl dik yaka ve önlük
static func _iwa_kunoichi(c: Dictionary) -> void:
	var h: float = c["H"]
	var r = A.K("a83a30")
	A._neck(c, 0.0, 0.055, 0.014, r, 0.14)
	A._belt(c, h + 0.04, 0.028, A.K("3a2a20"), A.K("c8a040"), 0.034)
	A._dg(c, "Hips", Vector3(0.0, h - 0.01, 0.14), Vector3(0.0, -1.0, 0.04).normalized(), 0.42, 0.2, r, 0.25)


## Şifacı kimonosu (ref Shizune_full): siyah kimono, beyaz kat yaka
static func _kuro_iryo(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var w = A.K("ece8dc")
	A._seam(c, [Vector2(-0.075, n), Vector2(0.04, n - 0.17), Vector2(0.07, h + 0.13)], 0.018, 0.004, w)
	A._seam(c, [Vector2(0.075, n), Vector2(0.015, n - 0.09)], 0.018, 0.004, w)


## Uzumaki ev giysisi (ref Kushina_Uzumaki_full): krem bluz üstüne askılı uzun yeşil önlük elbise
static func _uzumaki_haha(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var g = A.K("4f6a3c")
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.07, n - 0.02), Vector2(s * 0.095, ch - 0.06)], 0.03, 0.005, g, true, 0.006)
		A._seam(c, [Vector2(s * 0.07, n - 0.02), Vector2(s * 0.095, ch - 0.06)], 0.03, 0.005, g, false, 0.006)
	A._plate(c, 0.0, (ch - 0.06 + h) * 0.5, 0.21, ch - 0.06 - h, 0.005, g, true, 0.0, 0.006)
	A._plate(c, 0.0, (ch - 0.06 + h) * 0.5, 0.21, ch - 0.06 - h, 0.005, g, false, 0.0, 0.006)
	A._ring(c, h + 0.03, 0.03, 0.008, g.darkened(0.2))


## Demir Ülkesi komutanı (ref Mifune_full): koyu yeşil zırh ceketi, beyaz yaka, gri hakama
static func _tetsu_sho(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var w = A.K("e6e2d4")
	A._seam(c, [Vector2(-0.07, n + 0.005), Vector2(0.03, n - 0.15)], 0.022, 0.006, w, true, VL * 0.6)
	A._seam(c, [Vector2(0.07, n + 0.005), Vector2(0.01, n - 0.08)], 0.022, 0.006, w, true, VL * 0.6)
	A._ring(c, h + 0.04, 0.05, 0.01, A.K("d0ccba"))


## Taka kunoichi (ref Karin_full): boydan fermuarlı lavanta ceket, açık yeşil bel bağı
static func _taka_kunoichi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	A._neck(c, 0.0, 0.05, 0.012, A.K("8e7fa8"), 0.14)
	A._zip(c, n - 0.03, h - 0.02, A.K("e4e0ec"))
	A._ring(c, h + 0.05, 0.03, 0.008, A.K("a8b490"))


## Su kılıççısı (ref Suigetsu_body): kolsuz mor üst, kahve kemer, belden sarkan bej örtü
static func _taka_kenshi(c: Dictionary) -> void:
	var h: float = c["H"]
	A._belt(c, h + 0.03, 0.032, A.K("5a4430"), A.K("b09a60"), 0.04)
	A._dg(c, "Hips", Vector3(-0.1, h + 0.0, -0.12), Vector3(-0.12, -1.0, -0.1).normalized(), 0.55, 0.16, A.K("b0a282"), 0.2)


## Kiri büyüğü (ref Second_Mizukage-Full): boydan çizgili gri cübbe, koyu bel kuşağı, kocaman dik yaka
static func _nidaime(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var ln = A.K("8c8e94")
	A._neck(c, 0.015, 0.1, 0.03, A.K("c8b4b0"), 0.2, 0.006)
	A._ring(c, h + 0.05, 0.07, 0.012, A.K("34363c"))
	for k in 16:
		A._mer(c, -PI + k * TAU / 16.0, h - 0.04, kn - 0.1, 0.005, 0.003, ln, 0.0, 0.03)
		A._mer(c, -PI + k * TAU / 16.0, n - 0.1, h + 0.1, 0.004, 0.003, ln, 0.0, 0.02)


## Uzushio hanımı (ref Mito): beyaz kimono, deniz yeşili kat yaka, geniş kuşak
static func _uzushio_hime(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var g = A.K("2f8a86")
	A._seam(c, [Vector2(-0.075, n), Vector2(0.04, n - 0.17), Vector2(0.07, h + 0.13)], 0.018, 0.004, g)
	A._seam(c, [Vector2(0.075, n), Vector2(0.015, n - 0.09)], 0.018, 0.004, g)
	A._ring(c, h + 0.08, 0.09, 0.009, A.K("d8d2c0"))
	A._ring(c, h + 0.08, 0.014, 0.012, g)


## Kumo kardeşleri (ref Kinkaku_Tools): beyaz üst, mor yaka ve kuşak
static func _kumo_kyodai(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var m = A.K("4a3a78")
	A._seam(c, [Vector2(-0.08, n), Vector2(0.04, n - 0.17), Vector2(0.08, h + 0.1)], 0.03, 0.005, m)
	A._seam(c, [Vector2(0.08, n), Vector2(0.015, n - 0.09)], 0.03, 0.005, m)
	A._ring(c, h + 0.05, 0.06, 0.01, m)


## Kiri kılıççısı (ref Mangetsu_hozuki): kolsuz siyah üst, geniş kahve bel bağı
static func _kiri_kenshi(c: Dictionary) -> void:
	var h: float = c["H"]
	A._ring(c, h + 0.03, 0.075, 0.01, A.K("5a4632"))
	A._ring(c, h + 0.03, 0.014, 0.013, A.K("2a2018"))


## Kurosuki (ref Raiga-Ranmaru): boyunda sargı katları, koyu yelek
static func _kurosuki(c: Dictionary) -> void:
	var h: float = c["H"]
	for k in 3:
		A._neck(c, -0.012 + k * 0.022, 0.018, 0.012 + (2 - k) * 0.004, A.K("d4d0c4"), 0.15)
	A._belt(c, h + 0.03, 0.03, A.K("26262a"), A.K("8a8e96"), 0.036)


## Kiri kunoichi (ref Ameyuri_ringo): dikey çizgili zeytin tunik, krem yaka
static func _kiri_kunoichi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	A._neck(c, 0.0, 0.05, 0.012, A.K("d8cfa8"), 0.14)
	for k in 14:
		A._mer(c, -PI + k * TAU / 14.0, n - 0.08, h - 0.1, 0.005, 0.003, A.K("4a4426"), 0.0, 0.012)
	A._ring(c, h + 0.03, 0.03, 0.009, A.K("2c2a20"))


## Genç Kiri ustası (ref Yagura): kalın atkının altında sade üst, koyu kemer
static func _kiri_atki(c: Dictionary) -> void:
	A._belt(c, float(c["H"]) + 0.035, 0.026, A.K("26303a"), A.K("8a8e96"), 0.032)
	A._cuff(c, 0.94, 0.03, 0.005, A.K("26303a"))


## Suna büyüğü (ref Chiyo): koyu kuşak, önde dikiş; kalın krem boyunluk parçadan gelir
static func _suna_rojo(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	A._seam(c, [Vector2(0.0, n - 0.1), Vector2(0.0, h + 0.07)], 0.006, 0.003, A.K("6a6270"))
	A._ring(c, h + 0.045, 0.05, 0.009, A.K("5a4f60"))


## Rüzgâr kesici (ref Baki_Naruto_Mobile): yüksek yaka, sağ uylukta sargı
static func _kazekiri(c: Dictionary) -> void:
	var h: float = c["H"]; var kn: float = c["Kn"]
	A._neck(c, 0.0, 0.07, 0.018, A.K("3e4230"), 0.15)
	A._wraps(c, 1.0, h - 0.12, (h + kn) * 0.5, 4, 0.024, A.K("e6e2d6"))
	A._belt(c, h + 0.035, 0.028, A.K("2c2e24"), A.K("8a8e96"), 0.034)


## Kızgın sıcak ustası (ref Scorch_Release): boyun bağlı koyu üst, geniş gri kuşak
static func _shakunetsu(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	A._neck(c, 0.0, 0.05, 0.012, A.K("1c1c22"), 0.13)
	A._seam(c, [Vector2(0.0, n - 0.02), Vector2(0.0, n - 0.12)], 0.007, 0.003, A.K("8a8a94"))
	A._ring(c, h + 0.05, 0.07, 0.01, A.K("8a8a94"))
	A._dg(c, "Hips", Vector3(0.09, h + 0.02, 0.12), Vector3(0.04, -1.0, 0.04).normalized(), 0.3, 0.06, A.K("8a8a94"), 0.25)


## Lav ustası (ref Roshi_OL): koyu kuşak, bir yanda sarkan kahve deri önlük
static func _yogan(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var br = A.K("6e5230")
	A._seam(c, [Vector2(-0.075, n), Vector2(0.04, n - 0.17), Vector2(0.08, h + 0.09)], 0.02, 0.004, A.K("2e2024"))
	A._seam(c, [Vector2(0.075, n), Vector2(0.015, n - 0.09)], 0.02, 0.004, A.K("2e2024"))
	A._ring(c, h + 0.05, 0.05, 0.01, A.K("3a2a2c"))
	A._dg(c, "Hips", Vector3(0.13, h + 0.01, 0.06), Vector3(0.1, -1.0, 0.03).normalized(), 0.4, 0.15, br, 0.3)
	A._side_box(c, h + 0.0, -1.9, 0.0, 0.07, 0.07, 0.03, br, 0.03)


## Köpük gezgini (ref Utakata_full): açık mavi uzun giysi, koyu mavi yaka, turuncu kuşak ve sarkan uçları
static func _awa(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var o = A.K("e0802c"); var b = A.K("3c4f9a")
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.075, n - 0.01), Vector2(s * 0.03, n - 0.2)], 0.02, 0.005, b, true, VL * 0.6)
	A._ring(c, h + 0.05, 0.06, 0.014, o, -PI, PI, 0.045)
	A._dg(c, "Hips", Vector3(0.03, h + 0.03, 0.17), Vector3(0.03, -1.0, 0.05).normalized(), 0.62, 0.05, o, 0.22)
	A._dg(c, "Hips", Vector3(-0.04, h + 0.03, 0.17), Vector3(-0.03, -1.0, 0.05).normalized(), 0.5, 0.05, o, 0.22)


## Şelale kunoichisi (ref Fu_OL): göğüste çapraz kırmızı bant
static func _nanao(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var r = A.K("c0342c")
	for fr in [true, false]:
		A._seam(c, [Vector2(0.12, n - 0.03), Vector2(-0.12, ch - 0.1)], 0.015, 0.004, r, fr, 0.008)
		A._seam(c, [Vector2(-0.12, n - 0.03), Vector2(0.12, ch - 0.1)], 0.015, 0.004, r, fr, 0.012)
	A._ring(c, h + 0.0, 0.022, 0.008, r)


## Kumo jinchūriki kunoichisi (ref Yugito_Full): koyu mor üst, kırmızı bel bağı ve sarkan ucu
static func _nekomata(c: Dictionary) -> void:
	var h: float = c["H"]
	var r = A.K("9c2a3a")
	A._ring(c, h + 0.04, 0.04, 0.01, r)
	A._dg(c, "Hips", Vector3(-0.1, h + 0.02, 0.11), Vector3(-0.05, -1.0, 0.04).normalized(), 0.26, 0.05, r, 0.25)


## Genjutsu ustası (ref Kurenai_full): sargı elbisenin üstünde kırmızı bel ve yaka
static func _genso(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var r = A.K("a8323a")
	A._seam(c, [Vector2(-0.07, n), Vector2(0.03, n - 0.13)], 0.016, 0.004, r, true, 0.008)
	A._seam(c, [Vector2(0.07, n), Vector2(0.01, n - 0.08)], 0.016, 0.004, r, true, 0.008)
	A._ring(c, h + 0.08, 0.018, 0.008, r)
