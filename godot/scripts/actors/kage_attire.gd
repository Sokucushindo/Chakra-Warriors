class_name KageAttire
extends RefCounted
## Köy liderinin (Kage) giysisi: beyaz uzun cüppe, köy renginde iç giysi, geniş Kage şapkası (üst yarı köy renginde,
## önde köyün kanjisi, arkada beyaz örtü). Kage NPC'leri (ofis, tören) bunu kullanır.

const KANJI := {"konoha": "火", "suna": "風", "kiri": "水", "kumo": "雷", "iwa": "土"}
const PB = preload("res://scripts/actors/head_v2_b.gd")
const COLOR := {"konoha": Color(0.8, 0.14, 0.12), "suna": Color(0.16, 0.45, 0.38), "kiri": Color(0.18, 0.38, 0.75),
	"kumo": Color(0.95, 0.78, 0.16), "iwa": Color(0.5, 0.3, 0.2)}
## Kage kişilikleri (kanon dışı): saç, sakal, yaş havası
const PERSONA := {
	"konoha": {"gender": "m", "hair": Color(0.82, 0.82, 0.84), "hair_style": "geriye", "beard": true, "skin": Color(0.95, 0.8, 0.66)},
	"suna": {"gender": "m", "hair": Color(0.62, 0.22, 0.14), "hair_style": "kısa", "beard": false, "skin": Color(0.9, 0.72, 0.56)},
	"kiri": {"gender": "f", "hair": Color(0.2, 0.25, 0.45), "hair_style": "uzun", "beard": false, "skin": Color(0.97, 0.86, 0.78)},
	"kumo": {"gender": "m", "hair": Color(0.92, 0.9, 0.82), "hair_style": "diken", "beard": true, "skin": Color(0.55, 0.38, 0.27)},
	"iwa": {"gender": "m", "hair": Color(0.7, 0.7, 0.72), "hair_style": "topuz", "beard": true, "skin": Color(0.92, 0.76, 0.62)},
}


static func look(vid: String) -> Dictionary:
	var c: Color = COLOR.get(vid, COLOR["konoha"])
	var pz: Dictionary = PERSONA.get(vid, PERSONA["konoha"])
	var lk = {"top_style": "kimono", "top": c.darkened(0.25), "top2": c.darkened(0.35), "pants": Color(0.92, 0.92, 0.9), "pants_style": "sivil",
		"outer_style": "palto", "outer": Color(0.97, 0.96, 0.93), "vest": null, "band": null, "hakama": true,
		"sandal": Color(0.25, 0.2, 0.16), "age": "adult", "face_mark": "kırışık", "head_style": null}
	lk.merge(pz, true)
	lk.merge(Kage.kage_persona(vid), true)
	if not lk.has("years"):
		lk["years"] = 46.0 + Aging._h(vid + String(lk.get("hair_style", "")), 2) * 26.0
		lk["age_seed"] = vid   # dinamik Kage: yeni liderin saçı/cinsiyeti
	if not CharacterModel.HAIR_STYLES.has(lk["hair_style"]):
		lk["hair_style"] = CharacterModel.HAIR_STYLES.keys()[0]
	return lk


## Şapka: model iskeletinin kafasına takılır
static func hat(model: Node, vid: String) -> void:
	if model == null or not model.has_method("_mesh_on"):
		return
	if true:   # her köy/eşya yeni tek parça örtülü şapka (eski 5 şeritli yol parçalı görünüyordu); tanımsız köy kendi rengi/kanjisi ya da Konoha
		_hat_striker(model, vid)
		return

	var c: Color = COLOR.get(vid, COLOR["konoha"])
	var white = Color(0.97, 0.96, 0.93)
	var hc: Vector3 = model._head_center()
	var ab: AABB = model.head_ab
	var hw = clampf(ab.size.x, 0.16, 0.26) if ab.size.x > 0.05 else 0.2
	var hh = clampf(ab.size.y, 0.12, 0.26) if ab.size.y > 0.05 else 0.2
	var D = hw * 2.7   # kenar çapı (anime oranı: başın ~2.7 katı; eskiden 4.3 idi, fazla büyüktü)
	var H = 0.19
	var m = MB.new()
	m.add("cone", Vector3.ZERO, Vector3(D, H, D), white, Vector3.ZERO, 24)
	m.add("cone", Vector3(0, H * 0.25 + 0.004, 0), Vector3(D * 0.5, H * 0.5, D * 0.5), c, Vector3.ZERO, 24)
	m.add("cyl", Vector3(0, -H * 0.5 + 0.006, 0), Vector3(D * 1.01, 0.012, D * 1.01), white.darkened(0.12), Vector3.ZERO, 24)
	m.add("cyl", Vector3(0, -H * 0.5 - 0.02, 0), Vector3(hw * 1.08, 0.05, hw * 1.16), c.darkened(0.3), Vector3.ZERO, 14)
	m.add("sphere", Vector3(0, H * 0.5, 0), Vector3(0.025, 0.025, 0.025), c.darkened(0.2), Vector3.ZERO, 8)
	# önde: kanji çevresinde beyaz eşkenar dörtgen
	var slope = rad_to_deg(atan2(H, D * 0.5))
	var fy = H * 0.06
	var fz = D * 0.5 * (0.5 - fy / H) + 0.012
	m.add("box", Vector3(0, fy, fz), Vector3(0.075, 0.075, 0.006), white, Vector3(-(90.0 - slope), 0, 45))
	var top = hc.y + hh * 0.42
	var mi = model._mesh_on("Head", m.build(Props.toon()), Transform3D(Basis.IDENTITY, Vector3(hc.x, top + 0.05, hc.z)))
	# arkadan ve yanlardan sarkan beyaz örtü: rüzgârda/koşuda dalgalanan kumaş paneller (ikincil hareket)
	var brim_y = top + 0.05 - H * 0.5
	for k in 5:
		var a = deg_to_rad(110.0 + k * 35.0)
		var r = D * 0.36
		var out = Vector3(sin(a), 0, cos(a))
		model.dangle_strip("Head", Vector3(hc.x, brim_y - 0.01, hc.z) + out * r, (Vector3.DOWN + out * 0.12).normalized(), 0.19, 0.11, white.darkened(0.04), 0.22, out.cross(Vector3.UP).normalized(), 0.004)
	model.hair_mask_plane(Vector3.UP, Vector3(0, brim_y, 0))   # kenarın üstündeki saç şapkanın içinde kalır
	var l = Label3D.new()
	l.text = KANJI.get(vid, "影")
	l.font = _font()
	l.font_size = 64
	l.pixel_size = 0.0009
	l.modulate = c.darkened(0.1)
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD   # saydam sıralama yok (şapkayla sıra kavgası = bir görünüp bir kaybolma)
	l.rotation = Vector3(deg_to_rad(-(90.0 - slope)), 0, 0)
	# yüzey eğik (~55°): yalnız z'de 5 mm kaydırmak normal boyunca ~3 mm = kutunun yarı kalınlığı -> kanji kutunun içinde
	# kalıp derinlik çakışmasıyla titriyordu. Normal boyunca kutu yüzünün 8 mm önüne
	var nrm = Basis(Vector3.RIGHT, l.rotation.x) * Vector3(0, 0, 1)
	l.position = Vector3(0, fy, fz) + nrm * 0.011
	mi.add_child(l)


## Striker şapka tonları (ref ekran görüntülerinden; cüppe rengi COLOR ayrı)
const HAT_COLOR := {"konoha": Color(0.55, 0.08, 0.08), "kumo": Color(0.78, 0.6, 0.22), "kiri": Color(0.08, 0.13, 0.36), "iwa": Color(0.3, 0.17, 0.12), "suna": Color(0.08, 0.38, 0.2)}
const STRIKER_HATS := ["konoha", "kumo", "kiri", "iwa", "suna"]   # Striker Kage şapkaları (v2, ref büyütülerek)


## Striker Kage şapkası + anime (Hiruzen, Hashirama yakın çekim):
##  - alçak oturur: kenar burun üstü hizasında, gözler şapkanın altında; geniş, basık, hafif şişkin koni
##  - lake üst yüz, ince ışınsal kaburga ve tepe çevresinde koyu halka; tepede topuz ve iki metal halka
##  - kenarda dikişli kalın beyaz dudak, alt yüz çubuklu beyaz kafes, baş bandı
##  - önde ayrı katman beyaz yamuk (çerçeveli), içinde iri köy kanjisi
##  - örtü tek parça: kenarın altından omuza iner, pilili, etek bandı var; yan önler göğse uzun
static func _hat_striker(model: Node, vid: String) -> void:
	var c: Color = HAT_COLOR.get(vid, COLOR["konoha"])
	var white := Color(0.95, 0.95, 0.94)
	var hc: Vector3 = model._head_center()
	var ab: AABB = model.head_ab
	var hw: float = clampf(ab.size.x, 0.16, 0.26) if ab.size.x > 0.05 else 0.2
	var hh: float = clampf(ab.size.y, 0.12, 0.26) if ab.size.y > 0.05 else 0.2
	var eye_y: float = model.eye_center_model.y if model.get("eye_center_model") != null else hc.y
	var R: float = hw * 1.42
	var brim_y: float = eye_y + 0.004   # kenar göz üstü/burun kökü
	# koni kafatasının üstünden geçmeli; kafatası yuvarlak: r yarıçapında kafa yüksekliği top*sqrt(1-(r/rh)^2)
	var skull_top: float = hc.y + hh * 0.5
	for q in model._body_vs():   # gerçek kafatası tepesi (yüz kutusu tepeyi içermez)
		if absf(q.x - hc.x) < 0.05 and q.y > hc.y:
			skull_top = maxf(skull_top, q.y)
	var top: float = skull_top + 0.018 - brim_y
	var rh: float = hw * 0.55
	var H: float = R * 0.5
	for q in 11:
		var r: float = rh * q / 10.0
		var need: float = top * sqrt(maxf(0.0, 1.0 - pow(r / rh, 2.0)))
		H = maxf(H, need / maxf(0.05, 1.0 - r / R))
	var cen := Vector3(hc.x, brim_y, hc.z - 0.005)
	var apex_y: float = brim_y + H
	var bulge: float = H * 0.055
	var pt = func(a: float, t: float, off := 0.0) -> Vector3:
		var n := Vector3(sin(a) * H, R, cos(a) * H).normalized()   # koni yüzey normali (yaklaşık)
		return Vector3(cen.x + sin(a) * R * t, apex_y - H * t + bulge * sin(t * PI), cen.z + cos(a) * R * t) + n * off
	var mb := MB.new()
	var NA := 88
	var NT := 15
	var rib := c.darkened(0.16)
	var hi := c.lightened(0.07)
	var g_top = func(u: float, v: float) -> Vector3:
		return pt.call(u * TAU - PI, maxf(v, 0.012))
	PB._grid(mb, NA, NT, g_top, func(i: int, j: int, _u: float, _v: float) -> Color:
		if j >= NT - 1:
			return white
		if j == NT - 2:
			return white.darkened(0.22) if i % 2 == 0 else white.darkened(0.06)   # kenar dikişi
		if j == 2 or j == 3:
			return c.darkened(0.3)   # tepe halkası
		if j < 2:
			return c.darkened(0.12)
		if i % 11 == 0:
			return rib
		return hi if j == 7 or j == 8 else c, true)
	# dudak ve alt yüz: çubuklu beyaz kafes
	var e_prof := [Vector2(R, 0.0), Vector2(R + 0.005, -0.006), Vector2(R + 0.004, -0.017), Vector2(R - 0.004, -0.022), Vector2(R * 0.72, H * 0.2), Vector2(R * 0.44, H * 0.46), Vector2(0.012, H * 0.8)]
	PB._lathe(mb, cen, e_prof, 48, func(i: int, j: int, _u: float, _v: float) -> Color:
		if j < 3:
			return white if j < 2 else white.darkened(0.12)
		return white.darkened(0.2 if i % 3 == 0 else 0.1))
	# baş bandı
	var band_r: float = hw * 0.58
	PB._lathe(mb, cen, [Vector2(band_r, 0.035), Vector2(band_r + 0.002, 0.0), Vector2(band_r, -0.012)], 28, PB._flat(c.darkened(0.45)))
	# ön yamuk: taban kenarda (±21°), üst düz (t=0.46, ±12°), ayrı katman ve ince çerçeve
	var NS := 14
	var panel = func(uu: float, vv: float) -> Vector3:
		var t: float = lerpf(0.46, 0.925, vv)
		var half: float = deg_to_rad(lerpf(12.0, 21.0, vv))
		return pt.call(lerpf(-half, half, uu), t, 0.0028 + 0.001 * sin(vv * PI))
	var frame := c.darkened(0.1).lerp(white, 0.35)
	PB._grid(mb, NS, NS, panel, func(i: int, j: int, _u: float, _v: float) -> Color:
		return frame if i == 0 or i == NS - 1 or j == 0 else white)
	# tepe: topuz ve iki metal halka (anime yakın çekim)
	var metal := Color(0.62, 0.6, 0.56)
	PB._lathe(mb, Vector3(cen.x, apex_y + 0.001, cen.z), [Vector2(0.001, 0.021), Vector2(0.009, 0.019), Vector2(0.013, 0.01), Vector2(0.01, 0.004), Vector2(0.018, 0.0), Vector2(0.03, -0.012)], 14,
		func(_i: int, j: int, _u: float, _v: float) -> Color: return metal if j == 3 else c.darkened(0.35))
	for k in 2:
		var a: float = 0.62 + k * 0.3
		var t: float = 0.19 + k * 0.06
		var q0: Vector3 = pt.call(a - 0.13 / maxf(t * 2.0, 0.3), t)
		var q1: Vector3 = pt.call(a + 0.13 / maxf(t * 2.0, 0.3), t)
		var mid: Vector3 = (q0 + q1) * 0.5 + Vector3(0, 0.024, 0)
		PB._tube(mb, PB._cr([q0 - Vector3(0, 0.004, 0), q0 + Vector3(0, 0.016, 0), mid, q1 + Vector3(0, 0.016, 0), q1 - Vector3(0, 0.004, 0)], 3), 0.0024, 0.0024, PB._flat(metal), 5, 1.0, false)
	var mi: MeshInstance3D = model._mesh_on("Head", mb.build(Props.toon()), Transform3D.IDENTITY)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/toon.gdshader")
	mat.set_shader_parameter("rim_amount", 0.12)
	mi.material_override = mat
	# kanji: yamuğun ortasında, iri
	var kp: Vector3 = pt.call(0.0, 0.71, 0.0065)
	var slope: float = rad_to_deg(atan2(H, R))
	var l := Label3D.new()
	l.text = KANJI.get(vid, "影")
	l.font = _font()
	l.font_size = 96
	l.pixel_size = 0.00115
	l.modulate = c.darkened(0.3) if vid == "kumo" else c   # Raikage: sarı beyazda soluk kalıyor, ref turuncu-kahve
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.rotation = Vector3(deg_to_rad(-(90.0 - slope)), 0, 0)
	l.position = kp
	mi.add_child(l)
	_veil(model, Vector3(cen.x, brim_y - 0.004, cen.z), hw * 0.6, hh, white)
	model.hair_mask_plane(Vector3.UP, Vector3(0, brim_y + 0.01, 0))


## Kage örtüsü: pilili tek parça kumaş + zincirli ikincil hareket (önü açık, yan önler uzun, arkası omza)
static func _veil(model: Node, top: Vector3, r_in: float, hh: float, white: Color) -> void:
	var a0 := deg_to_rad(58.0)
	var a1 := deg_to_rad(302.0)
	var len_at = func(a: float) -> float:
		var d: float = absf(wrapf(rad_to_deg(a), -180.0, 180.0))
		return hh * lerpf(1.5, 1.08, smoothstep(70.0, 120.0, d))
	var flare_at = func(a: float) -> float:
		var d: float = absf(wrapf(rad_to_deg(a), -180.0, 180.0))
		return lerpf(0.06, 0.2, smoothstep(90.0, 180.0, d))
	var p_at = func(a: float, v: float) -> Vector3:
		var out := Vector3(sin(a), 0, cos(a))
		var L: float = len_at.call(a)
		var pleat: float = sin(a * 16.0) * 0.0045 * smoothstep(0.05, 0.45, v)
		return top + out * (r_in + float(flare_at.call(a)) * L * v * v + pleat) + Vector3(0, -L * v, 0)
	var mb := MB.new()
	var NU := 64
	var NV := 9
	var pos = func(u: float, v: float) -> Vector3: return p_at.call(lerpf(a0, a1, u), v)
	PB._plate(mb, NU, NV, pos, func(i: int, j: int, _u: float, _v: float) -> Color:
		if j == NV - 1:
			return white.darkened(0.17)   # etek bandı
		if j == NV - 2:
			return white.darkened(0.06)
		var ph: float = fmod(float(i) / NU * (a1 - a0) * 16.0 / TAU, 1.0)
		return white.darkened(0.1) if ph < 0.3 else white, 0.003, white.darkened(0.15))
	PB.curtain(model, mb, top, a0, a1, 9, p_at, len_at, 0.55, "KageVeil")


static var _f: SystemFont
static func _font() -> SystemFont:
	if _f == null:
		_f = SystemFont.new()
		_f.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans CJK JP", "Microsoft YaHei"])
		_f.font_weight = 800
	return _f
