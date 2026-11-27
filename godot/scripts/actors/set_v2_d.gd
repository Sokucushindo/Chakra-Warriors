extends RefCounted
## Temel setlere (Gear.SETS) gerçek 3B ayrıntı (hedef: res://scripts/actors/set_v2_d.gd). Yüzey yardımcıları set_v2_a içinden.
## Köy üniforması, Kage, ANBU ve Akatsuki kimliği korunur: yeleğin cepleri ve desenler değişmez, yalnız dikiş, arma, kenar eklenir.

const A = preload("res://scripts/actors/set_v2_a.gd")

const SETS := ["set_akatsuki", "set_ame", "set_anbu", "set_anbu_byakue", "set_anbu_kaptan", "set_anbu_kasumi", "set_anbu_konoha", "set_anbu_wakate", "set_anbu_yami",
	"set_chunin", "set_genin", "set_goken", "set_hokage", "set_iryonin", "set_iwa_chunin", "set_iwa_jonin", "set_joki", "set_jonin", "set_kage", "set_kage_no",
	"set_kazekage", "set_kenpo", "set_kenshi", "set_kiri_chunin", "set_kiri_jonin", "set_kumo_chunin", "set_kumo_jonin", "set_kurenai_kenpo", "set_matsuri", "set_mizukage",
	"set_ne", "set_raikage", "set_ronin", "set_samurai", "set_sengoku", "set_sennin_shugyo", "set_shinobi", "set_soryo", "set_suna", "set_suna_chunin",
	"set_suna_jonin", "set_tabibito", "set_tsuchikage", "set_uchiha", "set_yuki_tabi"]

const RED := Color(0.72, 0.14, 0.14)
const G_KAZE := [[-0.6, 0.85, 0.6, 0.85], [-0.6, 0.85, -0.75, -0.85], [0.6, 0.85, 0.75, -0.85], [0.75, -0.85, 0.92, -0.6], [-0.3, 0.52, 0.3, 0.42], [0.0, 0.47, 0.0, -0.4], [-0.3, 0.1, 0.3, 0.1], [-0.3, -0.35, 0.3, -0.35], [-0.3, 0.1, -0.3, -0.35], [0.3, 0.1, 0.3, -0.35]]
const G_MIZU := [[0.0, 0.9, 0.0, -0.85], [-0.75, 0.4, -0.1, 0.4], [-0.1, 0.4, -0.75, -0.6], [0.75, 0.55, 0.1, 0.05], [0.1, 0.05, 0.8, -0.7]]
const G_KAMI := [[-0.75, 0.85, 0.75, 0.85], [0.0, 0.85, 0.0, 0.2], [-0.75, 0.55, 0.75, 0.55], [-0.75, 0.55, -0.75, 0.2], [0.75, 0.55, 0.75, 0.2], [-0.55, 0.05, 0.55, 0.05], [-0.55, 0.05, -0.55, -0.85], [0.55, 0.05, 0.55, -0.85], [-0.55, -0.85, 0.55, -0.85], [-0.55, -0.4, 0.55, -0.4], [0.0, 0.05, 0.0, -0.85]]
const G_TSUCHI := [[-0.6, 0.35, 0.6, 0.35], [0.0, 0.85, 0.0, -0.8], [-0.85, -0.8, 0.85, -0.8]]

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
			mi.material_override = LazyFx.g("Props").toon()
		A._dangles(m, e[1])
		return
	var c = A._begin(m)
	if c.is_empty():
		return
	_recipe(c, sid)
	var made = m._sk_end(g)
	_cache[key] = [made.mesh if made != null else null, c["dg"]]
	A._dangles(m, c["dg"])


static func _recipe(c: Dictionary, sid: String) -> void:
	match sid:
		"set_akatsuki": _akatsuki(c)
		"set_ame": _ame(c)
		"set_anbu": _anbu(c, A.K("d9d9d1"), 0.95, false)
		"set_anbu_kaptan": _anbu(c, A.K("d9d9d1"), 0.8, true)
		"set_anbu_konoha": _anbu_kol(c, A.K("d1d1cc"))
		"set_anbu_yami": _anbu_plaka(c, A.K("bdb8c7"), 0.008, false)
		"set_anbu_kasumi": _anbu_plaka(c, A.K("b8b2c2"), 0.01, true)
		"set_anbu_wakate": _anbu_plaka(c, A.K("b8b2c2"), 0.006, false)
		"set_anbu_byakue": _byakue(c)
		"set_chunin": _konoha(c, A.K("758f70"), false)
		"set_jonin": _konoha(c, A.K("617a5c"), true)
		"set_genin": _genin(c)
		"set_goken": _goken(c)
		"set_shinobi": _shinobi(c)
		"set_uchiha": _uchiha(c)
		"set_iryonin": _iryonin(c)
		"set_suna": _suna(c)
		"set_suna_chunin": _suna_v(c, A.K("755e47"), false)
		"set_suna_jonin": _suna_v(c, A.K("614c38"), true)
		"set_kiri_chunin": _kiri(c, A.K("8f87a8"), A.K("99b8e6"))
		"set_kiri_jonin": _kiri(c, A.K("756e8f"), A.K("85a3d6"))
		"set_kumo_chunin": _kumo(c, false)
		"set_kumo_jonin": _kumo(c, true)
		"set_iwa_chunin": _iwa(c, A.K("5c4530"), A.K("b82933"), false)
		"set_iwa_jonin": _iwa(c, A.K("4c3826"), A.K("a8242e"), true)
		"set_kage": _kage(c, A.K("cc3326"), A.G_KAGE)
		"set_hokage": _kage(c, A.K("cc241f"), A.G_HI)
		"set_kazekage": _kage(c, A.K("297361"), G_KAZE)
		"set_mizukage": _kage(c, A.K("2e61bf"), G_MIZU)
		"set_raikage": _kage(c, A.K("d8ae20"), G_KAMI)
		"set_tsuchikage": _kage(c, A.K("804c33"), G_TSUCHI)
		"set_joki": _yoroi(c, A.K("4c4c47"), A.K("521a1f"), 0.05)
		"set_samurai": _yoroi(c, A.K("52576b"), A.K("c8c4b0"), 0.035)
		"set_sengoku": _sengoku(c)
		"set_kage_no": _kage_no(c)
		"set_ne": _ne(c)
		"set_kenpo": _kenpo(c)
		"set_kenshi": _kenshi(c)
		"set_kurenai_kenpo": _kurenai(c)
		"set_matsuri": _matsuri(c)
		"set_ronin": _ronin(c)
		"set_sennin_shugyo": _sennin(c)
		"set_soryo": _soryo(c)
		"set_tabibito": _tabibito(c)
		"set_yuki_tabi": _yuki(c)


## Kol üstü arma (T duruşunda kolun önü)
static func _arm_mark(c: Dictionary, sx: float, col: Color, r := 0.022) -> void:
	A._spiral(c, sx * (float(c["UA"]) + 0.075), float(c["N"]) - 0.045, r, 1.6, 0.005, col, true)


static func _seams(c: Dictionary, x0: float, x1: float, col: Color, back := true) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * x0, n - 0.12), Vector2(s * x1, h + 0.06)], 0.0035, 0.002, col)
		if back:
			A._seam(c, [Vector2(s * x0, n - 0.1), Vector2(s * x1, h + 0.06)], 0.0035, 0.002, col, false)


static func _trouser(c: Dictionary, col: Color, cuff_y := 0.0) -> void:
	var h: float = c["H"]; var kn: float = c["Kn"]
	for s in [-1.0, 1.0]:
		A._mer(c, s * 1.57, h - 0.05, kn + 0.03, 0.004, 0.002, col, s)
		A._seam(c, [Vector2(s * 0.13, h + 0.0), Vector2(s * 0.08, h - 0.05)], 0.006, 0.003, col)
		if cuff_y != 0.0:
			A._ring(c, kn + cuff_y, 0.022, 0.004, col, -PI, PI, 0.004, s)


# ------------------------------------------------------------------ örgüt ve ANBU
static func _akatsuki(c: Dictionary) -> void:
	var n: float = c["N"]; var kn: float = c["Kn"]
	var red = A.K("b81224")
	var dk = A.K("161830")
	A._btns(c, 0.03, n - 0.12, n - 0.36, 3, 0.009, red)
	A._neck(c, 0.05, 0.012, 0.004, red, 0.14, 0.008)
	A._cuff(c, 0.88, 0.012, 0.003, dk)
	var by = A._hem(c, "org_pelerin", kn - 0.15)
	A._ring(c, by + 0.035, 0.012, 0.003, dk)


static func _ame(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var dk = A.K("34383f")
	A._neck(c, 0.0, 0.05, 0.01, A.K("4c525c"), 0.14)
	A._seam(c, [Vector2(0.0, n - 0.04), Vector2(0.0, n - 0.2)], 0.008, 0.003, dk)
	A._btns(c, 0.014, n - 0.07, n - 0.18, 3, 0.007, A.K("8a9098"))
	A._stitch(c, Vector2(-0.14, n - 0.27), Vector2(0.14, n - 0.27), 14, A.K("767c86"))
	A._stitch(c, Vector2(-0.14, n - 0.25), Vector2(0.14, n - 0.25), 14, A.K("767c86"), false)
	A._belt(c, h + 0.05, 0.028, dk, A.K("8a9098"), 0.036)


static func _anbu(c: Dictionary, plate: Color, cuff: float, captain: bool) -> void:
	var h: float = c["H"]; var kn: float = c["Kn"]
	var dk = plate.darkened(0.4)
	A._belt(c, h + 0.055, 0.03, A.K("2c2c32"), A.K("9a9ca2"), 0.04)
	_arm_mark(c, 1.0, RED)
	A._cuff(c, cuff, 0.02, 0.004, A.K("2c2c32"))
	for s in [-1.0, 1.0]:
		A._ring(c, kn - 0.09, 0.02, 0.004, A.K("2c2c32"), -PI, PI, 0.005, s)
		A._mer(c, s * 1.57, h - 0.05, kn + 0.03, 0.004, 0.002, A.K("32323a"), s)
	if captain:
		A._plate(c, 0.09, float(c["N"]) - 0.11, 0.03, 0.012, 0.004, dk)
		A._plate(c, 0.09, float(c["N"]) - 0.13, 0.03, 0.012, 0.004, dk)


static func _anbu_kol(c: Dictionary, plate: Color) -> void:
	var h: float = c["H"]; var n: float = c["N"]
	A._belt(c, h + 0.055, 0.03, A.K("2c2c32"), plate, 0.04)
	_arm_mark(c, 1.0, RED, 0.026)   # çıplak omuzda ANBU dövmesi
	A._neck(c, 0.015, 0.03, 0.006, A.K("26262c"))
	A._cuff(c, 0.5, 0.014, 0.004, A.K("2c2c32"))
	A._seam(c, [Vector2(0.0, n - 0.05), Vector2(0.0, n - 0.1)], 0.006, 0.003, A.K("2c2c32"))
	_trouser(c, A.K("32323a"), -0.09)


static func _anbu_plaka(c: Dictionary, plate: Color, strap: float, scarf: bool) -> void:
	var h: float = c["H"]; var n: float = c["N"]
	var dk = plate.darkened(0.42)
	A._belt(c, h + 0.05, 0.026, A.K("26222e"), plate, 0.036)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.08, n - 0.015), Vector2(s * 0.1, n - 0.1)], strap * 2.0, 0.003, dk)
		A._seam(c, [Vector2(s * 0.08, n - 0.015), Vector2(s * 0.1, n - 0.1)], strap * 2.0, 0.003, dk, false)
	_arm_mark(c, 1.0, RED)
	if scarf:
		A._dg(c, "UpperChest", Vector3(0.05, n - 0.02, -0.11), Vector3(0.12, -1.0, -0.2), 0.2, 0.05, A.K("336b73"), 0.2)
	A._neck(c, 0.02, 0.028, 0.005, A.K("26222e"))


static func _byakue(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var e = A.K("c8c2b6")
	A._seam(c, [Vector2(0.0, n - 0.09), Vector2(0.0, kn + 0.14)], 0.005, 0.002, e)
	A._btns(c, -0.016, n - 0.14, h + 0.02, 5, 0.007, e.darkened(0.2))
	A._cuff(c, 0.86, 0.03, 0.004, e)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.14, h + 0.0), Vector2(s * 0.08, h - 0.03)], 0.012, 0.003, e)
	A._ring(c, h + 0.05, 0.022, 0.004, e, -PI, PI, 0.003)


# ------------------------------------------------------------------ köy üniformaları
static func _konoha(c: Dictionary, vest: Color, jonin: bool) -> void:
	var h: float = c["H"]; var ch: float = c["C"]
	var navy = A.K("161c3c")
	A._spiral(c, 0.0, ch + 0.03, 0.05, 1.7, 0.01, A.K("c03028"), false)   # yelek sırtında Uzumaki girdabı
	_arm_mark(c, 1.0, A.K("c03028"))
	_arm_mark(c, -1.0, A.K("c03028"))
	A._belt(c, h + 0.03, 0.024, navy, A.K("8a8e96"), 0.03)
	A._cuff(c, 0.94, 0.022, 0.004, navy)
	_trouser(c, navy, -0.09)
	A._stitch(c, Vector2(-0.14, h + 0.1), Vector2(0.14, h + 0.1), 16, vest.lightened(0.2), false)
	if jonin:
		for s in [-1.0, 1.0]:
			A._side_box(c, h + 0.02, s * 2.3, 0.0, 0.06, 0.05, 0.016, vest.darkened(0.25), 0.006)


static func _genin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var blk = A.K("1f1f24")
	A._zip(c, n - 0.03, h + 0.05, A.K("e8e0d0"))
	A._ring(c, h + 0.03, 0.036, 0.005, blk, -PI, PI, 0.004)
	A._cuff(c, 0.94, 0.03, 0.005, blk)
	A._spiral(c, 0.0, ch + 0.0, 0.05, 1.7, 0.01, A.K("c8481e"), false)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.13, h + 0.11), Vector2(s * 0.09, h + 0.06)], 0.008, 0.003, blk)
	_trouser(c, A.K("1c2740"), -0.09)


static func _goken(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var org = A.K("f5992e")
	for k in 3:
		A._neck(c, -0.03 + k * 0.026, 0.03, 0.016, org.darkened(0.07 * (k % 2)), 0.15, 0.012)
	A._belt(c, h + 0.05, 0.03, A.K("b82a20"), A.GOLD, 0.05)
	A._seam(c, [Vector2(0.0, n - 0.09), Vector2(0.0, h + 0.03)], 0.005, 0.003, A.K("3a7a46"))
	A._arm_wraps(c, 0.45, 0.95, 8, 0.02, A.WRAP)
	for s in [-1.0, 1.0]:
		for y in [kn - 0.05, an + 0.14]:
			A._ring(c, y, 0.014, 0.004, org.darkened(0.3), -PI, PI, 0.004, s)


static func _shinobi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var dk = A.K("1c2640")
	A._neck(c, 0.012, 0.032, 0.006, dk)
	A._seam(c, [Vector2(0.0, n - 0.03), Vector2(0.0, n - 0.14)], 0.005, 0.002, dk)
	A._ring(c, h + 0.03, 0.03, 0.005, dk, -PI, PI, 0.004)
	_seams(c, 0.1, 0.12, dk)
	_trouser(c, A.K("181f34"), -0.09)


static func _uchiha(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var dk = A.K("171b30")
	A._neck(c, 0.03, 0.05, 0.008, A.K("212642"), 0.13)
	A._ring(c, h + 0.03, 0.03, 0.005, dk, -PI, PI, 0.004)
	A._cuff(c, 0.3, 0.014, 0.004, dk)
	_seams(c, 0.1, 0.12, dk, false)
	A._seam(c, [Vector2(0.0, n - 0.05), Vector2(0.0, h + 0.05)], 0.004, 0.002, dk)
	_trouser(c, A.K("bdb8aa"), -0.09)


static func _iryonin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var red = A.K("a63333")
	A._neck(c, 0.012, 0.03, 0.006, red)
	A._plate(c, 0.0, ch + 0.03, 0.05, 0.016, 0.003, red, false)
	A._plate(c, 0.0, ch + 0.03, 0.016, 0.05, 0.003, red, false)
	A._btns(c, 0.0, n - 0.08, ch + 0.0, 3, 0.007, A.K("b8b2a2"))
	A._pouch(c, 0.09, ch - 0.1, 0.07, 0.06, A.K("cfc9b8"), A.K("b8b2a2"), true, red)
	A._ring(c, h + 0.03, 0.026, 0.005, A.K("b8b2a2"), -PI, PI, 0.004)
	_trouser(c, A.K("262a38"), -0.09)


static func _suna(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]
	var br = A.K("664c38")
	A._neck(c, 0.015, 0.04, 0.008, br)
	A._belt(c, h + 0.05, 0.034, br, A.K("c8b080"), 0.045)
	A._stitch(c, Vector2(-0.13, n - 0.2), Vector2(0.13, n - 0.2), 12, A.K("b89a70"))
	for s in [-1.0, 1.0]:
		A._ring(c, an + 0.2, 0.036, 0.005, A.K("a8906a"), -PI, PI, 0.004, s)
		A._mer(c, s * 1.57, h - 0.06, an + 0.22, 0.005, 0.002, A.K("a8906a"), s)


static func _suna_v(c: Dictionary, vest: Color, jonin: bool) -> void:
	var h: float = c["H"]; var ch: float = c["C"]
	var dk = A.K("141420")
	A._belt(c, h + 0.03, 0.024, dk, vest.lightened(0.2), 0.03)
	A._cuff(c, 0.94, 0.022, 0.004, dk)
	A._stitch(c, Vector2(-0.13, ch + 0.08), Vector2(0.13, ch + 0.08), 14, vest.lightened(0.25), false)
	A._stitch(c, Vector2(-0.13, ch - 0.14), Vector2(0.13, ch - 0.14), 14, vest.lightened(0.25), false)
	_trouser(c, A.K("24243a"), -0.09)
	if jonin:
		A._cuff(c, 0.3, 0.018, 0.004, vest.darkened(0.15))


static func _kiri(c: Dictionary, vest: Color, band: Color) -> void:
	var h: float = c["H"]; var ch: float = c["C"]
	A._belt(c, h + 0.09, 0.024, A.K("24242c"), band, 0.03)
	for k in 3:
		A._stitch(c, Vector2(-0.13, ch + 0.06 - k * 0.09), Vector2(0.13, ch + 0.06 - k * 0.09), 14, vest.lightened(0.2), false)
	A._cuff(c, 0.3, 0.016, 0.004, A.K("2c2c34"))
	for s in [-1.0, 1.0]:
		A._mer(c, s * 1.57, h - 0.05, float(c["Kn"]) + 0.03, 0.004, 0.002, A.K("2c2c34"), s)


static func _kumo(c: Dictionary, jonin: bool) -> void:
	var h: float = c["H"]; var kn: float = c["Kn"]
	var w = A.K("e0e0db")
	A._belt(c, h + 0.04, 0.024, A.K("14182e"), A.K("a8aab0"), 0.032)
	A._cuff(c, 0.94, 0.024, 0.004, w)
	A._stitch(c, Vector2(-0.12, h + 0.14), Vector2(0.12, h + 0.14), 12, A.K("b8b8b2"), false)
	for s in [-1.0, 1.0]:
		A._mer(c, s * 1.57, h - 0.05, kn + 0.05, 0.004, 0.002, A.K("2a3054"), s)
	if jonin:
		A._cuff(c, 0.28, 0.02, 0.004, w)


static func _iwa(c: Dictionary, vest: Color, red: Color, jonin: bool) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	A._btns(c, 0.016, n - 0.09, ch + 0.0, 3, 0.008, A.K("c8b080"))
	A._ring(c, h + 0.05, 0.03, 0.006, vest.darkened(0.3), -PI, PI, 0.005)
	A._stitch(c, Vector2(-0.13, ch + 0.08), Vector2(0.13, ch + 0.08), 14, vest.lightened(0.28), false)
	A._cuff(c, 0.94, 0.024, 0.004, red.darkened(0.25))
	for s in [-1.0, 1.0]:
		A._mer(c, s * 1.57, h - 0.05, float(c["Kn"]) + 0.03, 0.005, 0.002, red.darkened(0.25), s)
	if jonin:
		A._plate(c, 0.0, h + 0.05, 0.05, 0.04, 0.006, A.K("c8b080"), true, 0.0, 0.011)


static func _kage(c: Dictionary, col: Color, glyph: Array) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var by = A._hem(c, "palto", kn - 0.05)
	A._ring(c, by + 0.055, 0.1, 0.004, col, -PI, PI, 0.004)
	A._ring(c, by + 0.118, 0.012, 0.003, col.lightened(0.25), -PI, PI, 0.004)
	A._neck(c, 0.0, 0.03, 0.006, col)
	A._cuff(c, 0.9, 0.05, 0.005, col)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.03, n - 0.04), Vector2(s * 0.078, h + 0.12)], 0.03, 0.004, col)
	A._ring(c, h + 0.1, 0.05, 0.006, col.darkened(0.2), -0.42, 0.42, 0.006)
	A._glyph(c, 0.0, h + 0.2, 0.085, glyph, 0.017, col, false, 0.011, 0.004)


# ------------------------------------------------------------------ zırh ve gezgin takımları
static func _yoroi(c: Dictionary, armor: Color, cord: Color, lace: float) -> void:
	var h: float = c["H"]; var an: float = c["A"]
	A._ring(c, h + 0.09, 0.05, 0.006, cord, -PI, PI, 0.006)
	A._plate(c, 0.0, h + 0.09, 0.06, 0.05, 0.008, armor.lightened(0.15), true, 0.0, 0.012)
	for k in 14:
		A._mer(c, -PI + (k + 0.5) * TAU / 14.0, h + 0.03, an + 0.14, 0.006, 0.003, armor.darkened(0.45))
	for s in [-1.0, 1.0]:
		A._dg(c, "Hips", Vector3(s * 0.05, h + 0.07, 0.15), Vector3(s * 0.08, -1.0, 0.08), 0.18, lace, cord, 0.28)


static func _sengoku(c: Dictionary) -> void:
	var h: float = c["H"]; var an: float = c["A"]; var n: float = c["N"]
	var gold = A.GOLD
	A._ring(c, h + 0.09, 0.03, 0.005, gold.darkened(0.2), -PI, PI, 0.008)
	for k in 14:
		A._mer(c, -PI + (k + 0.5) * TAU / 14.0, h - 0.2, an + 0.14, 0.006, 0.003, A.K("6e1414"))
	A._disc(c, 0.0, n - 0.2, 0.024, 0.004, gold)
	A._disc(c, 0.0, n - 0.2, 0.012, 0.003, A.K("6e1414"))
	A._dg(c, "UpperChest", Vector3(0.0, n - 0.1, -0.13), Vector3(0.05, -1.0, -0.1), 0.22, 0.05, gold.darkened(0.3), 0.24)


static func _kage_no(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var dk = A.K("34343a")
	A._neck(c, 0.02, 0.04, 0.007, dk)
	A._seam(c, [Vector2(0.0, n - 0.04), Vector2(0.0, h + 0.1)], 0.005, 0.002, dk)
	A._cuff(c, 0.93, 0.03, 0.004, dk)
	A._side_box(c, h + 0.03, 1.2, 0.0, 0.06, 0.07, 0.022, A.K("403329"), 0.008)
	A._side_box(c, h + 0.03, -1.2, 0.0, 0.06, 0.07, 0.022, A.K("403329"), 0.008)
	_trouser(c, dk, -0.09)


static func _ne(c: Dictionary) -> void:
	var h: float = c["H"]; var ch: float = c["C"]
	var g = A.K("54545c")
	A._belt(c, h + 0.05, 0.026, A.K("26262c"), g, 0.034)
	A._stitch(c, Vector2(-0.12, ch + 0.05), Vector2(0.12, ch + 0.05), 14, g, false)
	A._stitch(c, Vector2(-0.12, ch - 0.12), Vector2(0.12, ch - 0.12), 14, g, false)
	A._btns(c, 0.0, ch + 0.06, ch - 0.1, 3, 0.007, g)
	_trouser(c, A.K("2a2a30"), -0.09)


static func _kenpo(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]
	var blk = A.K("262629")
	var w = A.K("d8d4ca")
	A._seam(c, [Vector2(0.05, n - 0.04), Vector2(-0.07, h + 0.13)], 0.02, 0.004, w)
	A._seam(c, [Vector2(-0.05, n - 0.04), Vector2(0.0, n - 0.17)], 0.02, 0.004, w)
	A._plate(c, 0.0, h + 0.09, 0.05, 0.05, 0.01, blk, true, 45.0, 0.01)
	for s in [-1.0, 1.0]:
		A._dg(c, "Hips", Vector3(s * 0.016, h + 0.07, 0.15), Vector3(s * 0.2, -1.0, 0.1), 0.2, 0.034, blk, 0.3)
		A._ring(c, an + 0.14, 0.03, 0.004, w, -PI, PI, 0.004, s)
	A._cuff(c, 0.62, 0.012, 0.003, w)


static func _kenshi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]
	var dk = A.K("1e1e28")
	for k in 12:
		A._mer(c, -PI + (k + 0.5) * TAU / 12.0, h + 0.02, an + 0.14, 0.006, 0.003, dk)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.02, n - 0.04), Vector2(s * 0.085, h + 0.17)], 0.018, 0.004, A.K("d4c8ac"))
	A._plate(c, 0.03, h + 0.1, 0.07, 0.03, 0.01, A.K("a89a80"), true, 12.0, 0.012)
	A._dg(c, "Hips", Vector3(0.06, h + 0.08, 0.15), Vector3(0.1, -1.0, 0.06), 0.2, 0.04, A.K("a89a80"), 0.3)


static func _kurenai(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var blk = A.K("1f1f24")
	A._zip(c, n - 0.03, h + 0.06, A.K("c8c8cc"))
	A._ring(c, h + 0.03, 0.036, 0.005, blk, -PI, PI, 0.004)
	A._cuff(c, 0.93, 0.03, 0.004, blk)
	for s in [-1.0, 1.0]:
		A._mer(c, s * 0.55, n - 0.08, h + 0.05, 0.008, 0.003, blk)
		A._seam(c, [Vector2(s * 0.13, h + 0.12), Vector2(s * 0.09, h + 0.07)], 0.008, 0.003, blk)
	_trouser(c, A.K("2e2e36"), -0.09)


static func _matsuri(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var ob = A.K("e6dbc7")
	A._ring(c, h + 0.1, 0.075, 0.008, ob, -PI, PI, 0.005)
	A._ring(c, h + 0.1, 0.01, 0.003, A.K("475c9e"), -PI, PI, 0.0125)
	A._plate(c, 0.0, h + 0.1, 0.12, 0.06, 0.018, ob.darkened(0.05), false, 0.0, 0.011)
	A._plate(c, 0.0, h + 0.1, 0.03, 0.074, 0.022, ob.darkened(0.16), false, 0.0, 0.012)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.015, n - 0.03), Vector2(s * 0.07, h + 0.14)], 0.018, 0.003, A.K("33384c"))


static func _ronin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var p = A.K("4c4233")
	A._plate(c, 0.09, ch - 0.1, 0.07, 0.06, 0.003, p, true, 7.0)
	A._plate(c, -0.08, h + 0.03, 0.06, 0.07, 0.003, p.lightened(0.1), true, -9.0)
	A._plate(c, 0.05, ch - 0.02, 0.08, 0.06, 0.003, p.darkened(0.12), false, 5.0)
	A._stitch(c, Vector2(0.055, ch - 0.07), Vector2(0.125, ch - 0.07), 5, A.K("a89878"))
	A._stitch(c, Vector2(0.055, ch - 0.13), Vector2(0.125, ch - 0.13), 5, A.K("a89878"))
	A._ring(c, h + 0.05, 0.016, 0.01, A.K("8a7858"), -PI, PI, 0.006)
	A._dg(c, "Hips", Vector3(0.06, h + 0.04, 0.15), Vector3(0.1, -1.0, 0.06), 0.16, 0.012, A.K("8a7858"), 0.3)
	A._neck(c, 0.0, 0.03, 0.01, A.K("594c42"), 0.14)
	A._seam(c, [Vector2(0.0, n - 0.08), Vector2(0.015, ch + 0.0)], 0.004, 0.002, p)


static func _sennin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var blk = A.K("1f1f24")
	var red = A.K("b82e26")
	A._zip(c, n - 0.03, h + 0.04, blk)
	A._neck(c, 0.0, 0.04, 0.008, blk)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.1, n - 0.03), Vector2(s * 0.12, kn + 0.08)], 0.014, 0.003, red.darkened(0.25))
	A._ring(c, h + 0.06, 0.028, 0.005, blk, -0.9, 0.9, 0.006)
	A._cuff(c, 0.5, 0.016, 0.004, red.darkened(0.25))


static func _soryo(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var or2 = A.K("b86626")
	A._disc(c, 0.06, ch + 0.02, 0.022, 0.005, A.GOLD)   # kesa halkası
	A._disc(c, 0.06, ch + 0.02, 0.011, 0.003, or2)
	A._ring(c, h + 0.1, 0.05, 0.007, A.K("262422"), -PI, PI, 0.006)
	A._dg(c, "Hips", Vector3(0.05, h + 0.07, 0.15), Vector3(0.08, -1.0, 0.08), 0.2, 0.04, A.K("262422"), 0.3)
	for s in [-1.0, 1.0]:
		A._seam(c, [Vector2(s * 0.02, n - 0.04), Vector2(s * 0.08, h + 0.14)], 0.014, 0.003, A.K("b8ad90"))
	A._cuff(c, 0.5, 0.012, 0.003, A.K("b8ad90"))


static func _tabibito(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var br = A.K("4c3829")
	A._neck(c, -0.01, 0.05, 0.012, A.K("6b5c47"), 0.15)
	A._plate(c, 0.0, n - 0.08, 0.04, 0.024, 0.006, A.K("a8906a"), true, 0.0, 0.01)
	A._seam(c, [Vector2(0.0, n - 0.1), Vector2(0.0, kn + 0.12)], 0.005, 0.002, br)
	A._ring(c, h + 0.08, 0.03, 0.006, br, -PI, PI, 0.006)
	A._side_box(c, h + 0.05, 1.0, 0.0, 0.08, 0.09, 0.03, br.lightened(0.1), 0.01)
	A._cuff(c, 0.9, 0.024, 0.004, br)


static func _yuki(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var fur = A.K("d8d4c8")
	var r = A._prof_y(c, n - 0.015, 0.0, 0.17)
	if not r.is_empty():
		var ct: Vector2 = r["c"]
		for lay in 2:
			var cnt = 20 + lay * 4
			for k in cnt:
				var a = TAU * (k + lay * 0.5) / cnt
				var o = Vector3(sin(a), 0.0, cos(a))
				var t = Vector3(cos(a), 0.0, -sin(a))
				var up: Vector3 = (Vector3.UP * (0.6 - lay * 0.6) + o * 0.6).normalized()
				A._box(c, Vector3(ct.x, n + 0.01 - lay * 0.025, ct.y) + o * (A._rad(r["r"], a) + 0.028 + lay * 0.012), t * 0.016, up * 0.032, up.cross(t).normalized() * 0.007, fur.darkened(0.05 * (k % 3)))
	A._btns(c, 0.03, n - 0.12, h + 0.1, 4, 0.009, A.K("a8a090"))
	A._btns(c, -0.03, n - 0.12, h + 0.1, 4, 0.009, A.K("a8a090"))
	A._ring(c, h + 0.08, 0.03, 0.006, A.K("262a3a"), -PI, PI, 0.006)
	A._cuff(c, 0.88, 0.04, 0.008, fur)
