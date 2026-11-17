class_name KinginFX
extends RefCounted
## Altı Yolun Bilgesi'nin hazineleri (Kumo, Kinkaku–Ginkaku) — Narutopedia + ref refs/kingin:
##   Kōkinjō: kalın örgülü altın ip, sarı ışıltı; değdiği kişinin SÖZ RUHUNU çeker ("Bağla ve çek")
##   Shichiseiken: geniş yassı soluk mavi-gümüş kılıç, köşelerde kıvrımlar, çapraz uzun sap ucunda halka + kahve muska; söz ruhu
##     çekilmiş birini keserse LANETLER ("Lanet") — kurbanın en çok söylediği söz ağza yazılır (oyunda: en çok kullandığı teknik)
##   Benihisago: kırmızı bezli çift boğum su kabağı; "Kaydet" der — lanetli o sözü söylerse (o tekniği kullanırsa) ya da bir süre
##     hiç konuşmazsa (teknik kullanmazsa) içine çekilir, mühürlenir
##   Kohaku no Jōhei: ip dolanmış "雷" amblemli toprak küp; adını çağırınca CEVAP veren (dönüp bakan) mühürlenir
## Bedel (kanon): hepsi devasa chakra yer; normal insan kısa sürede ölür — jinchūriki / Uzumaki değilsen candan da gider.
## Oyuncu ve düşman (hazine sahibi) aynı fonksiyonlar. Görünen her şey bu dosyada sıfırdan.

static var _c := {}

const GOURD := Color(0.55, 0.36, 0.25)
const CLOTH := Color(0.66, 0.1, 0.16)
const POT := Color(0.82, 0.46, 0.18)
const WOOD := Color(0.6, 0.44, 0.27)
const ROPE_W := Color(0.95, 0.94, 0.9)
const GOLD := Color(0.98, 0.82, 0.3)
const BLADE := Color(0.84, 0.89, 0.95)
const INK := Color(0.07, 0.06, 0.08)


# ================================================================== modeller (MB; sırt eşyası, el silahı ve teknik görselleri aynı)
## Benihisago: alt büyük boğum, üst küçük boğum, kırmızı bez bel bandı, tepede küçük ağız. o: alt boğumun merkezi
static func build_gourd(mb: MB, o: Vector3, s := 1.0, rot := Vector3.ZERO) -> void:
	var b = Basis.from_euler(rot * PI / 180.0)
	mb.add("sphere", o, Vector3(0.28, 0.26, 0.28) * s, GOURD, rot, 14)
	mb.add("sphere", o + b * Vector3(0, 0.34, 0) * s, Vector3(0.2, 0.2, 0.2) * s, GOURD, rot, 12)
	mb.add("cyl", o + b * Vector3(0, 0.17, 0) * s, Vector3(0.24, 0.12, 0.24) * s, CLOTH, rot, 14)
	mb.add("cyl", o + b * Vector3(0, 0.53, 0) * s, Vector3(0.05, 0.06, 0.05) * s, GOURD.darkened(0.25), rot, 8)


## Kohaku no Jōhei: turuncu toprak küp, tahta kapak + iki kulp, ağızda beyaz bükme ip (bir yandan sarkar), önde siyah baklava amblem
static func build_pot(mb: MB, o: Vector3, s := 1.0) -> void:
	mb.add("sphere", o, Vector3(0.3, 0.36, 0.3) * s, POT, Vector3.ZERO, 16)
	mb.add("cyl", o + Vector3(0, 0.33, 0) * s, Vector3(0.24, 0.06, 0.24) * s, POT.darkened(0.1), Vector3.ZERO, 14)
	mb.add("cyl", o + Vector3(0, 0.38, 0) * s, Vector3(0.25, 0.04, 0.25) * s, WOOD, Vector3.ZERO, 14)
	for sx in [-1.0, 1.0]:
		mb.add("box", o + Vector3(sx * 0.11, 0.44, 0) * s, Vector3(0.04, 0.08, 0.05) * s, WOOD)
	mb.add("torus", o + Vector3(0, 0.3, 0) * s, Vector3(0.27, 0.27, 0.27) * s, ROPE_W, Vector3.ZERO, 16)
	for k in 5:   # sağ yandan sarkan ip
		mb.add("sphere", o + Vector3(0.27, 0.26 - k * 0.08, 0.02) * s, Vector3(0.045, 0.05, 0.045) * s, ROPE_W, Vector3.ZERO, 8)
	# amblem: siyah baklava çerçeve + iç çizgiler (önde, yüzeye yaslı)
	var fz = 0.3 * s
	mb.add("box", o + Vector3(0, 0.0, fz), Vector3(0.2, 0.2, 0.01) * s, INK, Vector3(0, 0, 45))
	mb.add("box", o + Vector3(0, 0.0, fz + 0.004 * s), Vector3(0.16, 0.16, 0.01) * s, POT, Vector3(0, 0, 45))
	mb.add("box", o + Vector3(0, 0.03, fz + 0.008 * s), Vector3(0.012, 0.16, 0.01) * s, INK)
	mb.add("box", o + Vector3(0, -0.02, fz + 0.008 * s), Vector3(0.12, 0.012, 0.01) * s, INK)
	mb.add("box", o + Vector3(0, -0.06, fz + 0.008 * s), Vector3(0.09, 0.012, 0.01) * s, INK)


## Kōkinjō: üst üste altın ip halkaları (sırtta / omuzda dolu)
static func build_rope_coil(mb: MB, o: Vector3, s := 1.0, rot := Vector3(90, 0, 0)) -> void:
	for k in 4:
		mb.add("torus", o + Vector3(0, 0, -0.03 + k * 0.025) * s, Vector3(0.2 - k * 0.012, 0.2 - k * 0.012, 0.2) * s, GOLD.darkened(0.05 * (k % 2)), rot, 14)


## Shichiseiken: sap +Z boyunca (tutuş z=0), yassı ağız sapın üst kısmında; köşe kıvrımları, orta kat çizgisi, uçta halka + muska
static func build_shichiseiken(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.5), Vector3(0.022, 1.55, 0.022), BLADE.darkened(0.08), Vector3(90, 0, 0), 8)   # uzun sap
	for k in 10:   # sapın boğumları
		b.add("cyl", Vector3(0, 0, -0.15 + k * 0.13), Vector3(0.028, 0.012, 0.028), BLADE.darkened(0.2), Vector3(90, 0, 0), 8)
	b.add("torus", Vector3(0, 0, -0.3), Vector3(0.04, 0.04, 0.04), BLADE.darkened(0.15), Vector3(0, 90, 0), 10)
	b.add("box", Vector3(0, -0.06, -0.33), Vector3(0.008, 0.05, 0.035), Color(0.55, 0.38, 0.22), Vector3(20, 0, 0))   # muska
	# yassı ağız: sapın yanında (x+ yönüne açılır), sap ağzın ortasından geçer
	b.add("box", Vector3(0.0, 0.16, 0.71), Vector3(0.018, 0.46, 0.98), BLADE)   # yassı ağız: sap ağzın bir kenarından boydan boya geçer
	b.add("box", Vector3(0.0, 0.17, 0.71), Vector3(0.022, 0.006, 0.9), BLADE.darkened(0.3))   # orta kat çizgisi
	for c in [Vector2(0.37, 0.24), Vector2(0.37, 1.18), Vector2(-0.06, 0.24), Vector2(-0.06, 1.18)]:   # köşe kıvrımları
		b.add("torus", Vector3(0, c.x, c.y), Vector3(0.05, 0.05, 0.05), BLADE, Vector3(0, 0, 90), 10)


static func _mesh(key: String, fn: Callable) -> ArrayMesh:
	var k = "mesh:" + key
	if not _c.has(k):
		var mb = MB.new()
		fn.call(mb)
		_c[k] = mb.build(Props.toon())
	return _c[k]


static func gourd_mesh() -> ArrayMesh:
	return _mesh("gourd", func(mb): build_gourd(mb, Vector3.ZERO))


static func pot_mesh() -> ArrayMesh:
	return _mesh("pot", func(mb): build_pot(mb, Vector3.ZERO))


# ================================================================== gölgelendiriciler (kendi)
const GLOW_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 tint = vec4(1.0, 0.85, 0.3, 1.0);
instance uniform float fade_k = 1.0;
void fragment() {
	float v = abs(UV.y * 2.0 - 1.0);
	float m = (1.0 - smoothstep(0.0, 1.0, v));
	float braid = 0.75 + 0.25 * sin(UV.x * 90.0 - TIME * 6.0 + v * 6.0);
	ALBEDO = mix(tint.rgb * 0.85, vec3(1.0, 0.95, 0.7), (1.0 - v) * 0.15);
	ALPHA = clamp(m * m * braid * tint.a * fade_k, 0.0, 1.0);
}
"""

const SOUL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float m = 1.0 - smoothstep(0.55, 1.0, r);
	ALBEDO = mix(vec3(1.0, 0.98, 0.9), vec3(0.65, 0.75, 1.0), r);
	ALPHA = m * 0.85 * fade_k;
}
"""


static func _mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _c.has(k):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[k] = m
	return _c[k]


static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _fade(gi: GeometryInstance3D, delay: float, t: float) -> void:
	var tw = gi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter("fade_k", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)


## Canlı ip: iki uç her karede okunur, kalın örgülü altın ışıltılı şerit (kameraya dönük)
class Rope extends MeshInstance3D:
	var a_fn: Callable
	var b_fn: Callable
	var life := 1.0
	var t := 0.0
	var w := 0.09
	var sag := 0.3
	var im := ImmediateMesh.new()

	func _ready() -> void:
		mesh = im
		top_level = true
		global_transform = Transform3D.IDENTITY
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(dt: float) -> void:
		t += dt
		var a = a_fn.call() if a_fn.is_valid() else null
		var b = b_fn.call() if b_fn.is_valid() else null
		if t > life or a == null or b == null:
			queue_free()
			return
		var cam = get_viewport().get_camera_3d()
		var eye: Vector3 = cam.global_position if cam else a + Vector3.UP * 5.0
		var ab: Vector3 = b - a
		if ab.length() < 0.05:
			return
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n = 20
		for i in n + 1:
			var k = float(i) / n
			var p: Vector3 = a.lerp(b, k) + Vector3.DOWN * sag * sin(k * PI) + Vector3(sin(k * 18.0 + t * 9.0), cos(k * 14.0 + t * 7.0), 0.0) * 0.04 * sin(k * PI)
			var side: Vector3 = ab.normalized().cross((eye - p).normalized())
			side = (side.normalized() if side.length() > 0.001 else Vector3.RIGHT) * w
			im.surface_set_uv(Vector2(k * ab.length(), 0.0))
			im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(k * ab.length(), 1.0))
			im.surface_add_vertex(p + side)
		im.surface_end()
		set_instance_shader_parameter("fade_k", clampf((life - t) / 0.3, 0.0, 1.0))


static func _rope(a_fn: Callable, b_fn: Callable, life: float, w: float, col: Color, sag := 0.3) -> void:
	var root = _root()
	if root == null:
		return
	var r = Rope.new()
	r.a_fn = a_fn
	r.b_fn = b_fn
	r.life = life
	r.w = w
	r.sag = sag
	r.material_override = _mat("glow", GLOW_SH)
	root.add_child(r)
	r.set_instance_shader_parameter("tint", col)


static func _h(x: Node3D) -> float:
	return float(x.get("height")) if x.get("height") != null else 1.8


static func _chest(x: Node3D) -> Vector3:
	return x.global_position + Vector3.UP * _h(x) * 0.65


static func _fwd(x: Node3D) -> Vector3:
	var f: Vector3 = x.face_dir() if x.has_method("face_dir") else -x.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


## Söz ruhu: göğüsten çıkan soluk ışık topu (hedefin başında asılı kalır)
static func _soul_orb(x: Node3D, life: float) -> void:
	var root = _root()
	if root == null or not is_instance_valid(x):
		return
	var q = QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var mi = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _mat("soul", SOUL_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	x.add_child(mi)
	mi.position = Vector3.UP * _h(x) * 0.65
	var tw = mi.create_tween()
	tw.tween_property(mi, "position", Vector3.UP * (_h(x) + 0.45), 0.5).set_ease(Tween.EASE_OUT)
	_fade(mi, life - 0.4, 0.4)


## Bedel: jinchūriki / Uzumaki değilsen hazine canını da yer (kanon: normal insan kısa sürede ölür)
static func _toll(c: Node3D) -> void:
	var strong = false
	if c is Player:
		strong = TailedBeasts.player_jinchuriki() != "" or String(Game.profile.get("clan", "")) == "uzumaki"
	elif c.get("arch") is Dictionary:
		strong = c.arch.has("beast") or String(c.arch.get("clan", "")) == "uzumaki"
	if strong or c.get("hp") == null:
		return
	c.hp = maxf(1.0, float(c.hp) - float(c.max_hp) * 0.12)
	Combat.popup_text(c.global_position + Vector3.UP * 2.5, "Hazine canını emiyor", Color(1.0, 0.5, 0.4))


## El tutamağında beliren araç (teknik sırasında): mesh + süre
static func _in_hand(pj: PathJutsu, c: Node3D, mesh: Mesh, dur: float, off := Vector3.ZERO, sc := 1.0) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	var ba = pj.bone_attach(c, "RightHand")
	if ba != null:
		ba.add_child(mi)
		mi.position = off
	else:
		c.add_child(mi)
		mi.position = Vector3(-0.35, 1.1, 0.35) + off
	mi.scale = Vector3.ONE * 0.05
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * sc, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(dur)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== KŌKINJŌ: Shibari ("Bağla ve çek")
static func kokinjo_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.8)
	pj._face(c, tt)
	pj.anim(c, "push", 1.3)
	_toll(c)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var hand = func():
		var x = cw.get_ref()
		return null if x == null else pj.hand_pos(x)
	var tgt = func():
		var y = tw.get_ref()
		return null if y == null else _chest(y)
	# kolda dolu ip + ana ip ve ışıltı aurasından iki ek ip (kanon: aura ek iplere dönüşür)
	_rope(hand, tgt, 2.2, 0.1, Color(1.0, 0.85, 0.3, 1.0), 0.25)
	_rope(hand, func():
		var y = tw.get_ref()
		return null if y == null else _chest(y) + Vector3.UP * 0.35, 1.8, 0.05, Color(1.0, 0.95, 0.55, 0.6), 0.5)
	_rope(hand, func():
		var y = tw.get_ref()
		return null if y == null else _chest(y) - Vector3.UP * 0.35, 1.8, 0.05, Color(1.0, 0.95, 0.55, 0.6), 0.1)
	Sfx.play("whoosh", c.global_position, 0.8)
	pj.after(0.25, func():
		var x = cw.get_ref()
		var y = tw.get_ref()
		if x == null or y == null or not pj.live(x) or not pj.live(y):
			return
		pj.st(y, "bind", 2.0)
		pj.hit(x, _chest(y), 1.0, pj.inf(x, "kokinjo_shibari", 0.4, {"knock": 0.0, "dir": Vector3.ZERO, "kind": "light"}))
		y.set_meta("kotodama_t", Game.now() + 15.0)
		_soul_orb(y, 15.0)
		Combat.popup_text(y.global_position + Vector3.UP * 2.6, "Söz ruhu çekildi", Color(1.0, 0.95, 0.7)))


# ================================================================== SHICHISEIKEN: lanet (kombo vuruşu)
## Söz ruhu çekilmiş hedefe değerse lanetler: kurbanın en çok kullandığı teknik "söz" olur, ağza yazılır (yüzen yazı)
static func curse_hit(who: Node3D) -> void:
	var tg = Combat.nearest_enemy(who, 3.2)
	if tg == null or not is_instance_valid(tg) or float(tg.get_meta("kotodama_t", 0.0)) < Game.now():
		return
	var word := ""
	if tg.get("arch") is Dictionary:
		var jl: Array = tg.arch.get("jutsu", [])
		if not jl.is_empty():
			word = String(jl[0])
	if tg is Player:
		var sl: Array = Game.profile.get("slots", [])
		for s in sl:
			if String(s) != "":
				word = String(s)
				break
	if word == "":
		word = "_sessiz"   # tekniksiz kurban: sessizlik kendisi tetikler
	tg.set_meta("kotodama_word", word)
	tg.set_meta("kotodama_t", 0.0)
	var nm = "…" if word == "_sessiz" else String(Data.jutsu.get(word, {}).get("name", word)).split(" (")[0]
	Combat.popup_text(tg.global_position + Vector3.UP * 2.8, "Lanet: «%s»" % nm, Color(0.75, 0.85, 1.0))
	Sfx.play("seal", tg.global_position, 1.1)


# ================================================================== BENIHISAGO: Kiroku ("Kaydet")
## Lanetli hedef 12 sn boyunca: o sözü söylerse (o tekniği kullanırsa) ya da 6 sn hiç konuşmazsa (teknik kullanmazsa) içine çekilir
static func benihisago_kiroku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.7)
	pj._face(c, tt)
	pj.anim(c, "push", 1.0)
	_toll(c)
	_in_hand(pj, c, gourd_mesh(), 1.0, Vector3(0, 0.05, 0.1), 0.8)
	if tt == null or not tt.has_meta("kotodama_word"):
		Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Önce söz ruhu çekilip lanetlenmeli", Color(0.8, 0.6, 0.6))
		return
	Combat.popup_text(c.global_position + Vector3.UP * 2.6, "«Kaydet!»", Color(1.0, 0.6, 0.55))
	tt.set_meta("beni_rec", Game.now() + 12.0)
	tt.set_meta("beni_by", c)
	tt.set_meta("jid_t", float(tt.get_meta("jid_t", 0.0)) if tt.has_meta("jid_t") else Time.get_ticks_msec() / 1000.0)
	var t0 = Time.get_ticks_msec() / 1000.0
	var tw = weakref(tt)
	pj.every(12.0, 0.25, func(_i, _k):
		var y = tw.get_ref()
		if y == null or not pj.live(y) or float(y.get_meta("beni_rec", 0.0)) < Game.now():
			return
		var last = maxf(float(y.get_meta("jid_t", 0.0)), t0)
		if Time.get_ticks_msec() / 1000.0 - last > 6.0:   # sessizlik da tetikler (kanon)
			suck(y))


## Jutsu.execute çağırır: kaydedilen hedef lanet sözünü (o tekniği) kullanırsa çekilir. true = teknik yerine çekildi
static func on_cast(caster: Node3D, id: String) -> bool:
	if not caster.has_meta("beni_rec") or float(caster.get_meta("beni_rec")) < Game.now():
		return false
	if String(caster.get_meta("kotodama_word", "")) != id:
		return false
	suck(caster)
	return true


## İçine çekilme: hedefin üstünde dev su kabağı belirir, girdap çizgileri, beden küçülüp ağza akar; mühür (güçlü hedef direnir)
static func suck(y: Node3D) -> void:
	if not is_instance_valid(y) or y.is_dead():
		return
	y.set_meta("beni_rec", 0.0)
	var by = y.get_meta("beni_by") if y.has_meta("beni_by") else null
	var root = _root()
	if root == null:
		return
	var g = MeshInstance3D.new()
	g.mesh = gourd_mesh()
	root.add_child(g)
	var top = y.global_position + Vector3.UP * (_h(y) + 1.6)
	g.global_position = top
	g.rotation_degrees = Vector3(180, 0, 0)   # ağız aşağıda
	g.scale = Vector3.ONE * 0.1
	var tw = g.create_tween()
	tw.tween_property(g, "scale", Vector3.ONE * 2.2, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.1)
	tw.tween_property(g, "scale", Vector3.ONE * 0.05, 0.3)
	tw.tween_callback(g.queue_free)
	var yw = weakref(y)
	for k in 6:
		var a0 = k * TAU / 6.0
		_rope(func():
			var z = yw.get_ref()
			return null if z == null else z.global_position + Vector3(cos(a0 + Game.now() * 4.0), 0.4, sin(a0 + Game.now() * 4.0)) * 1.2, func():
			return top + Vector3.DOWN * 0.9, 1.3, 0.05, Color(1.0, 0.55, 0.5, 0.7), -0.2)
	Combat.popup_text(y.global_position + Vector3.UP * 2.8, "Benihisago'ya çekildi!", Color(1.0, 0.5, 0.5))
	Sfx.play("seal", y.global_position, 0.8)
	var m = y.get("model")
	if m is Node3D:
		m.create_tween().tween_property(m, "scale", Vector3.ONE * 0.15, 1.2).set_ease(Tween.EASE_IN)
	var att = by if by != null and is_instance_valid(by) else y
	if y.has_method("take_hit"):
		var inf = {"dmg": float(y.max_hp) * 3.0, "attacker": att, "execute": true, "sure": true, "knock": 0.0, "kind": "light", "hitstop": 0.0}
		y.get_tree().create_timer(1.2).timeout.connect(func():
			var z = yw.get_ref()
			if z == null:
				return
			var zm = z.get("model")
			if zm is Node3D and not z.is_dead():
				zm.scale = Vector3.ONE   # güçlü hedef direndi: geri çıkar
			z.take_hit(Combat.cap_one_shot(z, inf)))


# ================================================================== KOHAKU NO JŌHEI: Yobikake (çağrı)
## Adını çağırır; hedef cevap verirse (sana dönüp bakarsa — 1.2 sn içinde) küpe mühürlenir
static func kohaku_yobikake(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.9)
	pj._face(c, tt)
	pj.anim(c, "push", 1.0)
	_toll(c)
	var pot = _in_hand(pj, c, pot_mesh(), 1.6, Vector3(0, 0.05, 0.12), 0.75)
	if tt == null:
		return
	var nm = String(tt.get("display_name")) if tt.get("display_name") != null and String(tt.get("display_name")) != "" else ("Sen" if tt is Player else "Hey")
	Combat.popup_text(c.global_position + Vector3.UP * 2.7, "«%s!»" % nm.split(" — ")[0].split(" (")[0], Color(1.0, 0.75, 0.4))
	var cw = weakref(c)
	var tw = weakref(tt)
	var done := [false]
	pj.every(1.2, 0.1, func(_i, _k):
		var x = cw.get_ref()
		var y = tw.get_ref()
		if done[0] or x == null or y == null or not pj.live(x) or not pj.live(y):
			return
		var to_c: Vector3 = x.global_position - y.global_position
		to_c.y = 0.0
		if to_c.length() < 0.1:
			return
		if _fwd(y).dot(to_c.normalized()) > 0.55:   # cevap verdi: çağırana döndü
			done[0] = true
			_seal_pot(x, y, pot))
	pj.after(1.3, func():
		var y = tw.get_ref()
		if not done[0] and y != null and is_instance_valid(y):
			Combat.popup_text(y.global_position + Vector3.UP * 2.6, "Cevap vermedi", Color(0.75, 0.75, 0.8)))


static func _seal_pot(x: Node3D, y: Node3D, pot: Node3D) -> void:
	var yw = weakref(y)
	var pw = weakref(pot) if pot != null else null
	Combat.popup_text(y.global_position + Vector3.UP * 2.8, "Kohaku no Jōhei'ye mühürlendi!", Color(1.0, 0.7, 0.35))
	Sfx.play("seal", y.global_position, 0.7)
	# hedeften küpe akan koyu sıvı: kalın kara-kehribar ip
	_rope(func():
		var z = yw.get_ref()
		return null if z == null else _chest(z), func():
		var p = pw.get_ref() if pw else null
		return (p as Node3D).global_position + Vector3.UP * 0.2 if p != null and is_instance_valid(p) else null, 1.1, 0.16, Color(0.55, 0.3, 0.08, 0.9), -0.3)
	var m = y.get("model")
	if m is Node3D:
		m.create_tween().tween_property(m, "scale", Vector3(0.2, 0.05, 0.2), 1.0).set_ease(Tween.EASE_IN)
	var inf = {"dmg": float(y.max_hp) * 3.0, "attacker": x, "execute": true, "sure": true, "knock": 0.0, "kind": "light", "hitstop": 0.0}
	y.get_tree().create_timer(1.0).timeout.connect(func():
		var z = yw.get_ref()
		if z == null:
			return
		z.take_hit(Combat.cap_one_shot(z, inf))
		var zm = z.get("model")
		if zm is Node3D and not z.is_dead():
			zm.scale = Vector3.ONE)
