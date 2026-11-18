extends RefCounted
## Animeden eklenen kanon kıyafetlerin 3B ayrıntısı (hedef: res://scripts/actors/set_v2_e.gd). Kaynak görseller: refs/kiyafet/<tür>/.

const A = preload("res://scripts/actors/set_v2_a.gd")

const SETS := ["set_rengo", "set_keimu", "set_oto", "set_aburame", "set_shugonin", "set_kaguya", "set_oto_yonin", "set_taki", "set_uzushio", "set_jinmon", "set_kusa", "set_yu", "set_shimo", "set_tani"]

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
