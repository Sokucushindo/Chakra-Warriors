class_name TaijutsuFXB
extends RefCounted
## Taijutsu / kenjutsu B: Chōdan Kōro, Shishi Rendan, Sennen Goroshi, Gekitō Yōkaku, Gōken, Gamadosuzan, Aian Kurō, Issen,
## Tsukikage, Konoha Otoshi, Sōshūga, Daburu Dainamikku Entorī, Uzumaki Nisen Rendan, Tetsuzankō, Kassokuken: Isshiki.
## Işık şovu değil: anime çarpma karesi (ışınsal çizgiler), hız çizgisi, silik görüntü, toz, çatlak, moloz, kılıç yayı lekesi.
## Hepsi bu dosyanın kendi gölgelendiricileri ve şekilleriyle; her teknik kendi kompozisyonu (çarpma, leke şekli, sarsıntı).
## Kameraya yakın kısımlar gölgelendiricide incelir (ekranı kaplamaz). Hazır / ortak görsel yok.

static var _c := {}

const DUST := Color(0.8, 0.72, 0.6, 0.92)
const ROCK := Color(0.46, 0.39, 0.31)

## Çizgi / leke / iz: köşe rengi x tint, kameraya yakınken söner
const INK_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 c = COLOR * tint;
	ALBEDO = c.rgb;
	float nearf = smoothstep(1.3, 3.6, -VERTEX.z);
	ALPHA = clamp(c.a * fade * nearf, 0.0, 1.0);
}
"""

## Düz halka (şok dalgası / krater): prog yarıçap, width bant, jag tırtık, fill iç dolgu; dış kenarda koyu çizgi
const RING_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.2;
instance uniform float width = 0.15;
instance uniform float fade = 1.0;
instance uniform float jag = 0.0;
instance uniform float seed = 0.0;
instance uniform float fill = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec4 tint2 : source_color = vec4(0.1, 0.08, 0.06, 1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float e = prog * (1.0 + jag * (0.6 * sin(a * 9.0 + seed * 3.1) + 0.4 * sin(a * 23.0 + seed * 7.3)));
	float band = step(e - width, r) * step(r, e);
	float outer = step(e - width * 0.28, r) * band;
	float inner = step(r, e - width) * fill;
	vec3 col = mix(tint.rgb, tint2.rgb, outer);
	ALBEDO = mix(tint2.rgb, col, band);
	float al = max(band * tint.a, inner * tint2.a);
	float nearf = smoothstep(1.3, 3.6, -VERTEX.z);
	ALPHA = clamp(al * fade * nearf, 0.0, 1.0);
}
"""

## Kılıç / tekme yayı lekesi: UV.x yay boyu (tail..head görünür), UV.y iç(0)-dış(1); dış kenar bandı + hız kılları
const SMEAR_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float head = 1.0;
instance uniform float tail = 0.0;
instance uniform float fade = 1.0;
instance uniform float edge_w = 0.3;
instance uniform float hair = 0.0;
instance uniform vec4 core_col : source_color = vec4(1.0);
instance uniform vec4 edge_col : source_color = vec4(0.5, 0.6, 0.8, 1.0);
void fragment() {
	if (UV.x > head || UV.x < tail) {
		discard;
	}
	float k = clamp((UV.x - tail) / max(head - tail, 0.001), 0.0, 1.0);
	float e = step(1.0 - edge_w, UV.y);
	float hl = step(0.86, fract(UV.y * 4.0 + 0.3)) * (1.0 - e) * hair;
	vec3 col = mix(core_col.rgb, edge_col.rgb, max(e, hl));
	ALBEDO = col;
	float a = mix(core_col.a, edge_col.a, e) * mix(0.2, 1.0, smoothstep(0.0, 0.4, k));
	float nearf = smoothstep(1.3, 3.6, -VERTEX.z);
	ALPHA = clamp(a * fade * nearf, 0.0, 1.0);
}
"""

## Cel toz topağı: dünya normaline göre iki ton, kenarda koyu kontur
const CLOUD_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform vec4 base_col : source_color = vec4(0.8, 0.75, 0.65, 1.0);
varying vec3 wn;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float l = dot(wn, normalize(vec3(0.3, 1.0, 0.2)));
	vec3 col = mix(base_col.rgb * 0.7, base_col.rgb, step(0.12, l));
	float f = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	col = mix(col, base_col.rgb * 0.38, step(f, 0.2));
	ALBEDO = col;
	float nearf = smoothstep(1.3, 3.6, -VERTEX.z);
	ALPHA = clamp(base_col.a * fade * nearf, 0.0, 1.0);
}
"""

## Katı cel nesne (kabuk, boynuz, kılıç, kol, moloz): köşe rengi, iki ton + parlak tepe
const CEL_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, blend_mix;
instance uniform float fade = 1.0;
varying vec3 wn;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 base = COLOR.rgb;
	float l = dot(wn, normalize(vec3(0.35, 1.0, 0.25)));
	vec3 col = mix(base * 0.62, base, step(0.0, l));
	col = mix(col, min(base * 1.22, vec3(1.0)), step(0.78, l));
	ALBEDO = col;
	float nearf = smoothstep(0.9, 2.6, -VERTEX.z);
	ALPHA = clamp(fade * nearf, 0.0, 1.0);
}
"""

## Ters kabuk kontur (anime koyu kenar)
const OUTLINE_SH := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, blend_mix;
instance uniform float fade = 1.0;
uniform float thick = 0.03;
void vertex() {
	VERTEX += NORMAL * thick;
}
void fragment() {
	ALBEDO = vec3(0.06, 0.05, 0.06);
	float nearf = smoothstep(0.9, 2.6, -VERTEX.z);
	ALPHA = clamp(fade * nearf, 0.0, 1.0);
}
"""

## Silik görüntü / gölge: tek renk, kenarı koyu
const GHOST_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.6, 0.8, 1.0, 0.5);
instance uniform float fade = 1.0;
void fragment() {
	float f = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float body = step(0.32, f);
	ALBEDO = mix(tint.rgb * 0.45, tint.rgb, body);
	float nearf = smoothstep(1.3, 3.6, -VERTEX.z);
	ALPHA = clamp(tint.a * fade * nearf * mix(1.0, 0.65, body), 0.0, 1.0);
}
"""


# ================================================================== altyapı
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _c.has(key):
		return _c[key]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_c[key] = m
	return m


static func _ink() -> ShaderMaterial:
	return _mat("ink", INK_SH)


static func _cel(thick := 0.025) -> ShaderMaterial:
	var key = "cel_%d" % int(thick * 1000.0)
	if _c.has(key):
		return _c[key]
	var m = _mat("cel_base", CEL_SH).duplicate() as ShaderMaterial
	var o = _mat("outl_base", OUTLINE_SH).duplicate() as ShaderMaterial
	o.set_shader_parameter("thick", thick)
	m.next_pass = o
	_c[key] = m
	return m


static func _host(pj) -> Node:
	return pj.get_tree().current_scene


static func _pf(mi: GeometryInstance3D, pname: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(pname, v)


static func _gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _put(host: Node, mi: Node3D, p: Vector3) -> void:
	host.add_child(mi)
	mi.global_position = p


static func _perp(v: Vector3) -> Vector3:
	var n = v.normalized()
	var a = Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	return n.cross(a).normalized()


## Yerel +Z → d
static func _orient(n: Node3D, d: Vector3) -> void:
	var dd = d.normalized()
	if dd.length() < 0.01:
		dd = Vector3.FORWARD
	var up = Vector3.UP if absf(dd.y) < 0.95 else Vector3.RIGHT
	n.global_basis = Basis.looking_at(-dd, up)


## Yerel +Y → normal
static func _orient_y(n: Node3D, normal: Vector3) -> void:
	var y = normal.normalized()
	var x = _perp(y)
	var z = x.cross(y)
	n.global_basis = Basis(x, y, z)


static func _cone_dir(axis: Vector3, deg: float) -> Vector3:
	var a = axis.normalized()
	var u = _perp(a)
	var v = a.cross(u)
	var th = deg_to_rad(randf() * deg)
	var ph = randf() * TAU
	return (a * cos(th) + (u * cos(ph) + v * sin(ph)) * sin(th)).normalized()


static func _face_cam(pj, n: Node3D) -> void:
	var cam = pj.get_viewport().get_camera_3d()
	if cam:
		var to = cam.global_position - n.global_position
		if to.length() > 0.01:
			_orient(n, to)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, cc: Vector3, ca: Color, cb: Color, ccol: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(ccol)
	st.add_vertex(cc)


# ------------------------------------------------------------------ şekiller
## Kama: z=0'da sivri iç uç, z=1'de geniş dış uç (anime çarpma çizgisi)
static func _wedge() -> ArrayMesh:
	if _c.has("wedge"):
		return _c["wedge"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w = Color(1, 1, 1, 1)
	var tip = Vector3.ZERO
	var r = []
	for i in 4:
		var a = i * TAU / 4.0 + PI * 0.25
		r.append(Vector3(cos(a) * 0.5, sin(a) * 0.5, 1.0))
	for i in 4:
		_tri(st, tip, r[i], r[(i + 1) % 4], w, w, w)
	_tri(st, r[0], r[1], r[2], w, w, w)
	_tri(st, r[0], r[2], r[3], w, w, w)
	_c["wedge"] = st.commit()
	return _c["wedge"]


## İğ: z=0 önde opak sivri uç, en geniş z=0.25, z=1 arkada sönük kuyruk (hız çizgisi)
static func _spindle() -> ArrayMesh:
	if _c.has("spindle"):
		return _c["spindle"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cf = Color(1, 1, 1, 1)
	var cm = Color(1, 1, 1, 0.9)
	var cb = Color(1, 1, 1, 0.0)
	var r = []
	for i in 4:
		var a = i * TAU / 4.0 + PI * 0.25
		r.append(Vector3(cos(a) * 0.5, sin(a) * 0.5, 0.25))
	for i in 4:
		var a = r[i]
		var b = r[(i + 1) % 4]
		_tri(st, Vector3.ZERO, a, b, cf, cm, cm)
		_tri(st, a, Vector3(0, 0, 1), b, cm, cb, cm)
	_c["spindle"] = st.commit()
	return _c["spindle"]


static func _plane() -> PlaneMesh:
	if not _c.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2, 2)
		_c["plane"] = p
	return _c["plane"]


static func _lump() -> SphereMesh:
	if not _c.has("lump"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 6
		_c["lump"] = s
	return _c["lump"]


static func _rock(i: int) -> ArrayMesh:
	var key = "rock_%d" % i
	if not _c.has(key):
		var b = MB.new()
		var cols = [ROCK, ROCK.lightened(0.15), ROCK.darkened(0.2)]
		b.add("boulder", Vector3.ZERO, Vector3.ONE, cols[i % 3], Vector3.ZERO, 3 + i)
		_c[key] = b.build()
	return _c[key]


## Yay bandı (XZ düzleminde, açı a → (cos a, 0, -sin a)); profile 0 hilal (ortası geniş), 1 süpürme (başa doğru kalınlaşır), 2 düz
static func _arc_mesh(r: float, w: float, a0: float, a1: float, profile: int, seg := 28) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_in = Vector3.ZERO
	var prev_out = Vector3.ZERO
	var prev_u = 0.0
	var col = Color(1, 1, 1, 1)
	for i in seg + 1:
		var u = float(i) / seg
		var a = lerpf(a0, a1, u)
		var wid = w
		match profile:
			0:
				wid = w * pow(sin(PI * u), 0.75)
			1:
				wid = w * (0.12 + 0.88 * pow(u, 0.8)) * (1.0 - pow(u, 8.0) * 0.6)
		var dir = Vector3(cos(a), 0, -sin(a))
		var p_out = dir * r
		var p_in = dir * maxf(0.02, r - maxf(wid, 0.005))
		if i > 0:
			st.set_color(col)
			st.set_uv(Vector2(prev_u, 0))
			st.add_vertex(prev_in)
			st.set_uv(Vector2(prev_u, 1))
			st.add_vertex(prev_out)
			st.set_uv(Vector2(u, 1))
			st.add_vertex(p_out)
			st.set_uv(Vector2(prev_u, 0))
			st.add_vertex(prev_in)
			st.set_uv(Vector2(u, 1))
			st.add_vertex(p_out)
			st.set_uv(Vector2(u, 0))
			st.add_vertex(p_in)
		prev_in = p_in
		prev_out = p_out
		prev_u = u
	return st.commit()


# ------------------------------------------------------------------ yapı taşları
static func _line(host: Node, mesh: Mesh, p: Vector3, d: Vector3, w: float, l: float, col: Color) -> MeshInstance3D:
	var mi = _gi(mesh, _ink())
	_put(host, mi, p)
	_orient(mi, d)
	mi.scale = Vector3(w, w, maxf(l, 0.01))
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


## Çarpma karesi çizgileri: merkezden dışa fırlayan kamalar. normal verilirse o düzlemde yelpaze, bias verilirse koni
static func _burst(host: Node, p: Vector3, n: int, r0: float, len_: float, life: float, col: Color, w := 0.07, normal := Vector3.ZERO, bias := Vector3.ZERO, spread := 180.0) -> void:
	var u = Vector3.ZERO
	var v = Vector3.ZERO
	if normal != Vector3.ZERO:
		u = _perp(normal)
		v = normal.normalized().cross(u)
	for i in n:
		var d: Vector3
		if normal != Vector3.ZERO:
			var a = TAU * (i + randf_range(-0.3, 0.3)) / n
			d = u * cos(a) + v * sin(a)
		elif bias != Vector3.ZERO:
			d = _cone_dir(bias, spread)
		else:
			d = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var L = len_ * randf_range(0.55, 1.0)
		var ww = w * randf_range(0.7, 1.25)
		var mi = _line(host, _wedge(), p + d * r0, d, ww, L * 0.12, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(ww * 0.35, ww * 0.35, L), life * 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", p + d * (r0 + L * 0.45), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Sıkıştırma çizgileri: dıştan merkeze kayan kamalar (kavrama / sıkma)
static func _lines_in(host: Node, p: Vector3, n: int, r: float, life: float, col: Color, w := 0.06) -> void:
	for i in n:
		var d = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var L = r * randf_range(0.5, 0.8)
		var mi = _line(host, _wedge(), p + d * r, d, w, L, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + d * (r * 0.25), life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(w * 0.5, w * 0.5, L * 0.3), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.4).set_delay(life * 0.6)
		tw.chain().tween_callback(mi.queue_free)


## Hız çizgileri: d boyunca, yarıçapı rad olan bir silindirde; arkaya kayıp söner
static func _speed(host: Node, p: Vector3, d: Vector3, n: int, len_: float, rad: float, life: float, col: Color, w := 0.05, drift := 1.0) -> void:
	var dd = d.normalized()
	var u = _perp(dd)
	var v = dd.cross(u)
	for i in n:
		var a = randf() * TAU
		var rr = rad * (0.35 + 0.65 * sqrt(randf()))
		var off = (u * cos(a) + v * sin(a)) * rr + dd * randf_range(-len_ * 0.4, len_ * 0.3)
		var L = len_ * randf_range(0.5, 1.0)
		var mi = _line(host, _spindle(), p + off, -dd, w * randf_range(0.7, 1.2), L * 0.3, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale:z", L, life * 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", p + off - dd * len_ * drift, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
		tw.chain().tween_callback(mi.queue_free)


## Şok halkası (düz düzlem; normal yönüne bakar). p0→p1 yarıçap oranı; oval için sz (yerel x, z ölçeği)
static func _ring(host: Node, p: Vector3, normal: Vector3, r: float, life: float, col: Color, width := 0.12, jag := 0.0, p0 := 0.08, p1 := 0.92, rim := Color(0, 0, 0, 0), sz := Vector2.ONE) -> MeshInstance3D:
	var mi = _gi(_plane(), _mat("ring", RING_SH))
	_put(host, mi, p)
	_orient_y(mi, normal)
	mi.scale = Vector3(r * sz.x, 1.0, r * sz.y)
	mi.set_instance_shader_parameter("prog", p0)
	mi.set_instance_shader_parameter("width", width)
	mi.set_instance_shader_parameter("jag", jag)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fill", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("tint2", rim if rim.a > 0.0 else Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, col.a))
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(_pf(mi, "prog"), p0, p1, life * 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "width"), width, width * 0.3, life)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Krater izi: koyu çukur + açık kenar, tırtıklı; uzun süre yerde kalır
static func _crater(host: Node, p: Vector3, r: float, life: float) -> void:
	var mi = _gi(_plane(), _mat("ring", RING_SH))
	_put(host, mi, p + Vector3.UP * 0.035)
	_orient_y(mi, Vector3.UP)
	mi.scale = Vector3(r, 1.0, r)
	mi.set_instance_shader_parameter("prog", 0.3)
	mi.set_instance_shader_parameter("width", 0.22)
	mi.set_instance_shader_parameter("jag", 0.14)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fill", 0.62)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("tint", Color(0.62, 0.53, 0.42, 0.8))
	mi.set_instance_shader_parameter("tint2", Color(0.16, 0.12, 0.09, 0.85))
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "prog"), 0.3, 0.88, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 1.0)
	tw.tween_callback(mi.queue_free)


## Yerde çatlak: tırtıklı kollar ve alt dallar; align verilirse kollar o yöne hizalı (artı biçimi)
static func _cracks(host: Node, p: Vector3, r: float, arms: int, life: float, align := Vector3.ZERO) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_a = randf() * TAU
	if align != Vector3.ZERO:
		base_a = atan2(align.z, align.x)
	for b in arms:
		var a = base_a + TAU * b / arms + (randf_range(-0.35, 0.35) if align == Vector3.ZERO else randf_range(-0.08, 0.08))
		_crack_arm(st, Vector2.ZERO, a, r * randf_range(0.65, 1.0), 0.11, 0)
	var mi = _gi(st.commit(), _ink())
	_put(host, mi, p + Vector3.UP * 0.045)
	mi.set_instance_shader_parameter("tint", Color(1, 1, 1, 1))
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3(0.15, 1.0, 0.15)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 1.0)
	tw.tween_callback(mi.queue_free)


static func _crack_arm(st: SurfaceTool, s: Vector2, a: float, L: float, w: float, depth: int) -> void:
	var col = Color(0.1, 0.08, 0.06, 0.92)
	var steps = 6
	var p = s
	var ang = a
	for i in steps:
		var k0 = float(i) / steps
		var k1 = float(i + 1) / steps
		ang += randf_range(-0.5, 0.5)
		var q = p + Vector2(cos(ang), sin(ang)) * (L / steps)
		var n = Vector2(-sin(ang), cos(ang))
		var w0 = w * (1.0 - k0 * 0.85)
		var w1 = w * (1.0 - k1 * 0.85)
		var A = Vector3(p.x + n.x * w0, 0, p.y + n.y * w0)
		var B = Vector3(p.x - n.x * w0, 0, p.y - n.y * w0)
		var C = Vector3(q.x + n.x * w1, 0, q.y + n.y * w1)
		var D = Vector3(q.x - n.x * w1, 0, q.y - n.y * w1)
		_tri(st, A, B, C, col, col, col)
		_tri(st, B, D, C, col, col, col)
		if depth < 2 and i > 0 and randf() < 0.35:
			_crack_arm(st, q, ang + randf_range(0.6, 1.1) * (1.0 if randf() < 0.5 else -1.0), L * 0.4, w0 * 0.6, depth + 1)
		p = q


## Cel toz topakları: halka hâlinde dışa ve yukarı kabarır, söner. dir verilirse o yöne savrulur
static func _dust(host: Node, p: Vector3, n: int, r: float, rise: float, life: float, col: Color, sz := 0.6, out := 1.6, dir := Vector3.ZERO) -> void:
	for i in n:
		var a = TAU * (i + randf() * 0.5) / n
		var o = Vector3(cos(a), 0, sin(a))
		if dir != Vector3.ZERO:
			var dd = Vector3(dir.x, 0, dir.z).normalized()
			o = (o * 0.45 + dd).normalized()
		var mi = _gi(_lump(), _mat("cloud", CLOUD_SH))
		var c2 = col.lightened(randf_range(-0.06, 0.08))
		c2.a = col.a
		_put(host, mi, p + o * r * randf_range(0.5, 1.0) + Vector3.UP * sz * 0.25)
		mi.set_instance_shader_parameter("base_col", c2)
		mi.set_instance_shader_parameter("fade", 1.0)
		var s0 = sz * randf_range(0.6, 1.1)
		mi.scale = Vector3(s0, s0 * 0.75, s0) * 0.4
		var lf = life * randf_range(0.8, 1.15)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(s0, s0 * 0.8, s0) * 2.1, lf).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", mi.global_position + o * out * randf_range(0.6, 1.0) + Vector3.UP * rise * randf_range(0.5, 1.0), lf).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, lf * 0.5).set_delay(lf * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Klon pof'u: küçük beyaz topaklar, çok kısa
static func _poof(host: Node, p: Vector3, s: float) -> void:
	for i in 5:
		var d = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		var mi = _gi(_lump(), _mat("cloud", CLOUD_SH))
		_put(host, mi, p + d * 0.15 * s)
		mi.set_instance_shader_parameter("base_col", Color(0.96, 0.96, 0.98, 0.95))
		mi.set_instance_shader_parameter("fade", 1.0)
		mi.scale = Vector3.ONE * 0.2 * s
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3.ONE * s * randf_range(0.7, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", p + d * 0.55 * s, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.16).set_delay(0.2)
		tw.chain().tween_callback(mi.queue_free)


## Moloz: balistik yayla uçan kaya parçaları, yere düşüp bir süre kalır
static func _debris(host: Node, p: Vector3, n: int, spd: float, sz := 0.22, up := 1.0) -> void:
	for i in n:
		var mi = _gi(_rock(i % 3), _cel(0.012))
		var s = sz * randf_range(0.5, 1.3)
		_put(host, mi, p + Vector3(randf_range(-0.4, 0.4), 0.1, randf_range(-0.4, 0.4)))
		mi.scale = Vector3.ONE * s
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		mi.set_instance_shader_parameter("fade", 1.0)
		var h = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * spd * randf_range(0.35, 1.0)
		var vy = spd * randf_range(0.5, 1.1) * up
		var g = 24.0
		var tf = clampf(2.0 * vy / g, 0.25, 1.3)
		var p0 = mi.global_position
		var tw = mi.create_tween()
		tw.tween_method(func(k: float) -> void:
			if is_instance_valid(mi):
				mi.global_position = p0 + h * k + Vector3.UP * maxf(0.0, vy * k - 0.5 * g * k * k), 0.0, tf, tf)
		tw.parallel().tween_property(mi, "rotation", mi.rotation + Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)), tf)
		tw.tween_interval(randf_range(0.9, 1.6))
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.5)
		tw.tween_callback(mi.queue_free)


## Yay lekesi: center etrafında, axis normalli düzlemde ref yönünden a0→a1 (derece). reveal'de açılır, hold bekler, out'ta kuyruk kovalar
static func _smear(host: Node, center: Vector3, axis: Vector3, ref: Vector3, a0: float, a1: float, r: float, w: float, reveal: float, hold: float, out: float, core: Color, edge: Color, profile := 1, edge_w := 0.3, hair := 0.0) -> MeshInstance3D:
	var mi = _gi(_arc_mesh(r, w, deg_to_rad(a0), deg_to_rad(a1), profile), _mat("smear", SMEAR_SH))
	_put(host, mi, center)
	var n = axis.normalized()
	var x = (ref - n * ref.dot(n)).normalized()
	mi.global_basis = Basis(x, n, x.cross(n))
	mi.set_instance_shader_parameter("head", 0.0)
	mi.set_instance_shader_parameter("tail", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("edge_w", edge_w)
	mi.set_instance_shader_parameter("hair", hair)
	mi.set_instance_shader_parameter("core_col", core)
	mi.set_instance_shader_parameter("edge_col", edge)
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "head"), 0.0, 1.0, reveal).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_method(_pf(mi, "tail"), 0.0, 0.97, out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, out)
	tw.tween_callback(mi.queue_free)
	return mi


## İz şeridi: kaynağın arkasından sürüklenen, eski ucu genişleyip sönen düz şerit (kabuğun toz kuyruğu)
static func _ribbon(host: Node, src: Node3D, pos_fn: Callable, dur: float, width: float, col: Color, keep := 0.5) -> void:
	var im = ImmediateMesh.new()
	var mi = _gi(im, _ink())
	host.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	mi.set_instance_shader_parameter("tint", Color(1, 1, 1, 1))
	mi.set_instance_shader_parameter("fade", 1.0)
	var pts: Array = []
	var tw = mi.create_tween()
	tw.tween_method(func(_k: float) -> void:
		if is_instance_valid(src) and src.is_inside_tree():
			pts.append(pos_fn.call())
			if pts.size() > 42:
				pts.pop_front()
		_ribbon_build(im, pts, width, col), 0.0, 1.0, dur)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, keep)
	tw.tween_callback(mi.queue_free)


static func _ribbon_build(im: ImmediateMesh, pts: Array, width: float, col: Color) -> void:
	im.clear_surfaces()
	var n = pts.size()
	if n < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var p: Vector3 = pts[i]
		var tg: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var side = tg.cross(Vector3.UP)
		if side.length() < 0.001:
			side = Vector3.RIGHT
		side = side.normalized()
		var k = float(i) / (n - 1)
		var w = width * lerpf(1.9, 0.45, k)
		var cc = Color(col.r, col.g, col.b, col.a * pow(k, 0.6))
		im.surface_set_color(cc)
		im.surface_set_uv(Vector2(k, 0))
		im.surface_add_vertex(p - side * w * 0.5)
		im.surface_set_color(cc)
		im.surface_set_uv(Vector2(k, 1))
		im.surface_add_vertex(p + side * w * 0.5)
	im.surface_end()


## Modelin o anki pozunu bir kez pişir: [[mesh, c'ye göre dönüşüm, malzemeler], ...]
static func _bake(c: Node3D) -> Array:
	var out = []
	var m = c.get("model")
	if m == null or not is_instance_valid(m):
		return out
	var inv = c.global_transform.affine_inverse()
	for node in m.find_children("*", "MeshInstance3D", true, false):
		var src = node as MeshInstance3D
		if src == null or src.mesh == null or not src.is_visible_in_tree():
			continue
		var mesh: Mesh = src.mesh
		if src.skin != null or src.get_node_or_null(src.skeleton) is Skeleton3D:
			var bk = src.bake_mesh_from_current_skeleton_pose()
			if bk:
				mesh = bk
		var mats = []
		for si in mesh.get_surface_count():
			mats.append(src.get_active_material(si))
		out.append([mesh, inv * src.global_transform, mats])
	return out


## Pişmiş pozu xf'de göster: real=false tek renk silik görüntü (tint), real=true gerçek malzemeli klon. life>0 ise söner
static func _echo(host: Node, baked: Array, xf: Transform3D, tint: Color, life: float, real := false) -> Node3D:
	var root = Node3D.new()
	host.add_child(root)
	root.global_transform = xf
	for e in baked:
		var mi = MeshInstance3D.new()
		mi.mesh = e[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if real:
			for si in e[2].size():
				if e[2][si]:
					mi.set_surface_override_material(si, e[2][si])
		else:
			mi.material_override = _mat("ghost", GHOST_SH)
			mi.set_instance_shader_parameter("tint", tint)
			mi.set_instance_shader_parameter("fade", 1.0)
		root.add_child(mi)
		mi.transform = e[1]
	if life > 0.0:
		_echo_fade(root, life, real)
	return root


static func _echo_fade(root: Node3D, life: float, real: bool) -> void:
	var kids = root.get_children()
	var tw = root.create_tween()
	tw.tween_method(func(v: float) -> void:
		for k in kids:
			if is_instance_valid(k):
				if real:
					k.transparency = 1.0 - v
				else:
					k.set_instance_shader_parameter("fade", v), 1.0, 0.0, life)
	tw.tween_callback(root.queue_free)


## c'nin bakışını dir'e çeviren dönüşüm (konum pos)
static func _xf_facing(c: Node3D, pos: Vector3, dir: Vector3) -> Transform3D:
	var f = c.face_dir()
	var a = atan2(f.cross(dir).y, f.dot(dir))
	return Transform3D(Basis(Vector3.UP, a) * c.global_basis, pos)


# ================================================================== Chōdan Kōro
## Dev kabuk: mor-gri, iki tonlu, üstünde koyu tarama çizgileri (anime karesi)
static func _shell_mesh() -> ArrayMesh:
	if _c.has("shell"):
		return _c["shell"]
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(2.2, 1.8, 2.2), Color(0.5, 0.47, 0.55), Vector3.ZERO, 18)
	b.add("sphere", Vector3(0.18, 0.22, 0.1), Vector3(1.7, 1.45, 1.75), Color(0.66, 0.63, 0.7), Vector3.ZERO, 16)
	for k in 16:
		var a = k * TAU / 16.0 + randf_range(-0.2, 0.2)
		var y = randf_range(-0.6, 0.6)
		var rr = sqrt(maxf(0.05, 1.0 - y * y / 0.81)) * 1.1
		var pos = Vector3(cos(a) * rr, y, sin(a) * rr)
		b.add("box", pos, Vector3(0.05, 0.3, 0.05), Color(0.22, 0.2, 0.26), Vector3(0, -rad_to_deg(a), randf_range(-25, 25)))
	_c["shell"] = b.build()
	return _c["shell"]


static func chodan_koro(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	var d = pj._jump_at(c, tt, 14.0, 8.0 if tt else 2.0)
	pj.busy(c, 1.4)
	var host = _host(pj)
	var shell = _gi(_shell_mesh(), _cel(0.035))
	c.add_child(shell)
	shell.position = Vector3.UP * 1.0
	shell.set_instance_shader_parameter("fade", 1.0)
	shell.scale = Vector3.ONE * 0.35
	shell.create_tween().tween_property(shell, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Game.safe_loops(shell.create_tween()).tween_property(shell, "rotation:x", TAU, 0.4).from(0.0)
	# kalkış: ayak altında toz halkası
	var g0 = pj.gp(c.global_position)
	_dust(host, g0, 8, 0.6, 0.4, 0.7, DUST, 0.5, 1.4)
	_ring(host, g0 + Vector3.UP * 0.05, Vector3.UP, 3.0, 0.4, Color(0.92, 0.86, 0.74, 0.8), 0.1, 0.12)
	# kabuğun arkasında iki kıvrık toz kuyruğu (referanstaki çift şerit)
	var side = d.cross(Vector3.UP).normalized()
	for sgn in [-1.0, 1.0]:
		_ribbon(host, shell, func() -> Vector3: return shell.global_position + side * 0.55 * sgn - d * 0.4, 0.86, 0.6, Color(0.74, 0.68, 0.56, 0.85), 0.55)
	pj.after(0.7, func():
		if not pj.live(c):
			return
		if c is CharacterBody3D:
			c.velocity = d * 4.0 + Vector3.DOWN * 30.0
		_speed(host, c.global_position + Vector3.UP * 1.2, Vector3.DOWN, 10, 2.8, 1.4, 0.28, Color(0.95, 0.92, 0.86, 0.8), 0.07)
		pj.after(0.15, func():
			if is_instance_valid(shell):
				shell.queue_free()
			if not is_instance_valid(c):
				return
			var at = pj.gp(c.global_position)
			# iniş: krater + geniş çatlak ağı + dev toz kabarması + yassı şok halkası + yerde çarpma çizgileri + moloz
			_crater(host, at, 3.2, 3.5)
			_cracks(host, at, 9.0, 9, 3.5)
			_ring(host, at + Vector3.UP * 0.08, Vector3.UP, 8.0, 0.5, Color(0.96, 0.9, 0.78, 0.85), 0.09, 0.15)
			_burst(host, at + Vector3.UP * 0.15, 18, 1.2, 4.5, 0.38, Color(0.3, 0.24, 0.18, 0.9), 0.14, Vector3.UP)
			_dust(host, at, 16, 1.4, 1.8, 1.4, DUST, 1.1, 3.6)
			_debris(host, at, 16, 9.0, 0.3)
			pj.hit(c, at + Vector3.UP, 6.0, pj.inf(c, "chodan_koro", 2.2, {"knock": 16.0, "launch": 7.0, "kind": "heavy", "hitstop": 0.1}))
			pj.shake(1.2)))
	Sfx.play("whoosh", c.global_position, 0.6)


# ================================================================== Shishi Rendan
## Havadaki tek tekme: hedefin etrafında küçük dikey yay + mini çarpma karesi (her tekmede açı döner)
static func _air_kick(host: Node, c: Node3D, tt: Node3D, k: int) -> void:
	var f = c.face_dir()
	var p = tt.global_position + Vector3.UP
	var ax = f.cross(Vector3.UP).normalized().rotated(f, deg_to_rad((k - 1) * 40.0))
	_smear(host, p, ax, Vector3.DOWN, -20.0, 130.0, 0.9, 0.28, 0.05, 0.0, 0.16, Color(1, 1, 0.95, 0.9), Color(1, 0.75, 0.5, 0.9), 1, 0.35)
	_burst(host, p + f * 0.2, 6 + k * 2, 0.2, 0.7 + k * 0.15, 0.16, Color(1, 0.95, 0.82, 0.95), 0.05)


## Yere çakış: referanstaki yassı açık renkli sıçrama dikenleri + krater, çatlak, moloz
static func _shishi_ground(pj: PathJutsu, host: Node, p: Vector3, f: Vector3) -> void:
	var g = pj.gp(p)
	for i in 13:
		var a = deg_to_rad(lerpf(-80.0, 80.0, i / 12.0) + randf_range(-6, 6))
		var dir = (f.rotated(Vector3.UP, a) * (1.0 if i % 2 == 0 else -1.0) + Vector3.UP * randf_range(0.12, 0.35)).normalized()
		var L = randf_range(1.2, 2.4)
		var mi = _line(host, _wedge(), g + Vector3.UP * 0.1 + dir * 0.3, dir, 0.16, L * 0.1, Color(0.93, 0.95, 0.78, 0.95))
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(0.05, 0.05, L), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.16).set_delay(0.16)
		tw.chain().tween_callback(mi.queue_free)
	_crater(host, g, 1.6, 2.5)
	_cracks(host, g, 3.0, 6, 2.5)
	_dust(host, g, 9, 0.8, 0.5, 0.8, DUST, 0.6, 1.8)
	_debris(host, g, 18, 7.0, 0.2)


static func shishi_rendan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 5.0)
	pj.busy(c, 1.6)
	pj._face(c, tt)
	pj._kick_pose(c, 0.25)
	if tt == null:
		return
	tt.take_hit(pj.inf(c, "shishi_rendan", 0.4, {"knock": 0.0, "launch": 14.0, "kind": "heavy"}))
	var host = _host(pj)
	var p0 = tt.global_position
	# yukarı tekme: yukarı koni çarpma çizgileri + yukarı akan hız çizgileri + ayak dibinde toz
	_burst(host, p0 + Vector3.UP * 0.9, 8, 0.25, 1.0, 0.22, Color(1, 1, 0.92, 0.95), 0.06, Vector3.ZERO, Vector3.UP, 50.0)
	_speed(host, p0 + Vector3.UP * 2.0, Vector3.UP, 9, 2.4, 0.7, 0.4, Color(0.9, 0.95, 1.0, 0.7), 0.045)
	_dust(host, pj.gp(p0), 7, 0.5, 0.4, 0.6, DUST, 0.45, 1.0)
	pj.after(0.3, func():
		if not pj.live(c) or not pj.live(tt):
			return
		var from = c.global_position
		c.global_position = tt.global_position - c.face_dir() * 0.8 - Vector3.UP * 0.4
		# Kage Buyō: yaprağın gölgesi gibi peşinden çıkar — aradaki yolda iki koyu gölge
		var bk = _bake(c)
		for q in [0.35, 0.7]:
			var xf = c.global_transform
			xf.origin = from.lerp(c.global_position, q)
			_echo(host, bk, xf, Color(0.08, 0.1, 0.16, 0.55), 0.22)
		for k in 3:
			pj.after(k * 0.12, func():
				if pj.live(tt):
					pj._kick_pose(c, 0.1)
					tt.take_hit(pj.inf(c, "shishi_rendan", 0.35, {"knock": 0.0, "launch": 2.0, "kind": "light"}))
					if is_instance_valid(c):
						_air_kick(host, c, tt, k))
		pj.after(0.45, func():
			if pj.live(tt):
				pj.anim(c, "hook", 1.4)
				tt.take_hit(pj.inf(c, "shishi_rendan", 1.4, {"knock": 4.0, "launch": -22.0, "kind": "heavy"}))
				Combat.popup_text(tt.global_position + Vector3.UP * 2.0, "Shishi Rendan!", Color(1, 0.6, 0.3))
				# aşağı çakış: aşağı koni çizgiler + düşüş hız çizgileri
				_burst(host, tt.global_position + Vector3.UP * 1.0, 10, 0.3, 1.4, 0.22, Color(1, 0.92, 0.75, 0.95), 0.07, Vector3.ZERO, Vector3.DOWN, 35.0)
				_speed(host, tt.global_position + Vector3.UP * 0.6, Vector3.DOWN, 12, 3.0, 0.8, 0.35, Color(0.95, 0.95, 1.0, 0.75), 0.05)
				var f = c.face_dir() if is_instance_valid(c) else Vector3.FORWARD
				pj.after(0.3, func():
					if pj.live(tt):
						_shishi_ground(pj, host, tt.global_position, f)
						pj.shake(0.6)
						Sfx.play("hit_heavy", tt.global_position, 0.8))))


# ================================================================== Sennen Goroshi
## Komik "pat!" yıldızı: kameraya bakan pembe beş köşe, koyu konturlu
static func _star_mesh() -> ArrayMesh:
	if _c.has("star"):
		return _c["star"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 2:
		var rs = 1.14 if layer == 0 else 1.0
		var z = -0.02 if layer == 0 else 0.0
		var col = Color(0.2, 0.08, 0.12, 1) if layer == 0 else Color(1, 1, 1, 1)
		for i in 10:
			var a0 = PI * 0.5 + i * TAU / 10.0
			var a1 = PI * 0.5 + (i + 1) * TAU / 10.0
			var r0 = rs * (1.0 if i % 2 == 0 else 0.45)
			var r1 = rs * (1.0 if (i + 1) % 2 == 0 else 0.45)
			_tri(st, Vector3(0, 0, z), Vector3(cos(a0) * r0, sin(a0) * r0, z), Vector3(cos(a1) * r1, sin(a1) * r1, z), col, col, col)
	_c["star"] = st.commit()
	return _c["star"]


static func _pow_star(pj: PathJutsu, host: Node, p: Vector3, col: Color, s: float) -> void:
	var mi = _gi(_star_mesh(), _ink())
	_put(host, mi, p)
	_face_cam(pj, mi)
	mi.rotate_object_local(Vector3(0, 0, 1), randf_range(-0.4, 0.4))
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3.ONE * 0.05
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * s, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.16)
	tw.tween_property(mi, "scale", Vector3.ONE * s * 0.2, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


static func sennen_goroshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	if tt == null:
		if c is Player:
			Hud.msg("Arkasına geçecek hedef yok", Color(1, 0.7, 0.5))
		return
	pj.busy(c, 0.8)
	var host = _host(pj)
	_poof(host, c.global_position + Vector3.UP, 0.6)
	var away = (tt.global_position - c.global_position)
	away.y = 0
	c.global_position = pj.gp(tt.global_position + away.normalized() * 1.1)
	if c is Player:
		c.combat.face_to(tt)
	pj.anim(c, "crouch", 1.5)
	Combat.popup_text(c.global_position + Vector3.UP * 2.2, "Bin Yıllık Ölüm!!", Color(1, 0.6, 0.7))
	_poof(host, c.global_position + Vector3.UP * 0.9, 0.45)
	# kenetlenen parmaklara doğru toplanan ince pembe çizgiler (komik hazırlık)
	_lines_in(host, c.global_position + Vector3.UP * 0.85 + c.face_dir() * 0.45, 6, 0.7, 0.4, Color(1, 0.8, 0.88, 0.9), 0.035)
	pj.after(0.45, func():
		if not pj.live(tt) or not pj.live(c):
			return
		pj.anim(c, "jab", 1.6)
		tt.take_hit(pj.inf(c, "sennen_goroshi", 0.8, {"knock": 2.0, "launch": 14.0, "kind": "heavy"}))
		pj.st(tt, "stun", 1.5)
		var pp = tt.global_position + Vector3.UP * 0.9
		_pow_star(pj, host, pp, Color(1, 0.62, 0.78, 1), 0.5)
		_burst(host, pp, 9, 0.2, 0.55, 0.24, Color(1, 0.75, 0.86, 0.95), 0.045)
		# roket gibi fırlar: altında yeşil hız çizgileri (referans)
		for k in 4:
			pj.after(0.05 + k * 0.09, func():
				if pj.live(tt):
					_speed(host, tt.global_position + Vector3.UP * 0.3, Vector3.UP, 5, 1.4, 0.35, 0.3, Color(0.72, 1.0, 0.58, 0.8), 0.035))
		Sfx.play("punch", tt.global_position, 1.4))


# ================================================================== Gekitō Yōkaku
## Kavisli, sivrilen gri boynuz (+Z boyunca, ucu hafif yukarı kıvrık); koyu konturlu
static func _horn_mesh() -> ArrayMesh:
	if _c.has("horn"):
		return _c["horn"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings = 10
	var sides = 8
	var pts = []
	for i in rings + 1:
		var u = float(i) / rings
		var cen = Vector3(0, 0.2 * u * u, u * 1.25)
		var rad = 0.14 * pow(1.0 - u, 0.8) + 0.004
		var ring = []
		for j in sides:
			var a = j * TAU / sides
			ring.append(cen + Vector3(cos(a) * rad, sin(a) * rad, 0))
		pts.append(ring)
	for i in rings:
		var u = float(i) / rings
		var c0 = Color(0.3, 0.3, 0.33).lerp(Color(0.66, 0.66, 0.7), u)
		var c1 = Color(0.3, 0.3, 0.33).lerp(Color(0.66, 0.66, 0.7), float(i + 1) / rings)
		for j in sides:
			var a = pts[i][j]
			var b = pts[i][(j + 1) % sides]
			var cc = pts[i + 1][j]
			var dd = pts[i + 1][(j + 1) % sides]
			_tri(st, a, cc, b, c0, c1, c0)
			_tri(st, b, cc, dd, c0, c1, c1)
	st.generate_normals()
	_c["horn"] = st.commit()
	return _c["horn"]


static func gekito_yokaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 0.7)
	var host = _host(pj)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var horn = _gi(_horn_mesh(), _cel(0.02))
		ba.add_child(horn)
		horn.set_instance_shader_parameter("fade", 1.0)
		horn.scale = Vector3.ONE * 0.1
		horn.create_tween().tween_property(horn, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		pj.free_after(0.8, ba)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var d = pj._jump_at(c, tt, 0.0, 26.0 if tt else 12.0)
		# referanstaki koyu yağmur gibi düşüş çizgileri: hamle yönüne paralel ince koyu çizgiler + birkaç açık rüzgâr çizgisi
		_speed(host, c.global_position + Vector3.UP * 1.1, d, 12, 3.5, 1.0, 0.35, Color(0.12, 0.13, 0.16, 0.85), 0.03, 1.5)
		_speed(host, c.global_position + Vector3.UP * 1.1, d, 5, 2.5, 0.6, 0.28, Color(0.92, 0.94, 1.0, 0.65), 0.05)
		pj.after(0.12, func():
			if pj.live(c):
				var hs = pj.hit(c, c.global_position + Vector3.UP * 1.1 + d * 1.4, 1.6, pj.inf(c, "gekito_yokaku", 1.6, {"knock": 14.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.08}))
				if not hs.is_empty():
					# delip geçiş: hedefin arkasından dar koni koyu çizgiler + hamleye dik gri halka
					var hp = hs[0].global_position + Vector3.UP * 1.0
					_burst(host, hp, 12, 0.2, 2.4, 0.26, Color(0.14, 0.14, 0.17, 0.9), 0.06, Vector3.ZERO, d, 22.0)
					_ring(host, hp, d, 1.4, 0.25, Color(0.82, 0.84, 0.88, 0.8), 0.14)
					pj.shake(0.25)))
	Sfx.play("whoosh", c.global_position, 1.0)


# ================================================================== Gōken
static func goken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._jump_at(c, tt, 0.0, 16.0 if tt else 4.0)
	pj.busy(c, 0.5)
	var host = _host(pj)
	_speed(host, c.global_position + Vector3.UP, d, 10, 2.2, 0.8, 0.3, Color(0.86, 1.0, 0.86, 0.75), 0.05)
	pj.after(0.18, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.8)
		var fist = c.global_position + Vector3.UP * 1.2 + d * 1.3
		# yumruk havası: yumruğun önünde küçük sıkışma halkası (ıskalasa da)
		_ring(host, fist, d, 0.9, 0.18, Color(1, 1, 1, 0.75), 0.18)
		var hs = pj.hit(c, fist, 1.8, pj.inf(c, "goken", 1.5, {"knock": 16.0, "kind": "heavy", "hitstop": 0.08}))
		if not hs.is_empty():
			# referanstaki yeşil ışınsal fon: hedefin arkasında, yumruğa dik düzlemde yeşil-beyaz geniş kamalar
			var hp = hs[0].global_position + Vector3.UP * 1.2
			_burst(host, hp + d * 0.6, 14, 0.6, 3.2, 0.32, Color(0.62, 1.0, 0.55, 0.5), 0.3, d)
			_burst(host, hp + d * 0.5, 8, 0.5, 2.4, 0.26, Color(1, 1, 0.95, 0.7), 0.12, d)
			# yumruk göçüğü: iç içe iki halka + öne dar çizgiler
			_ring(host, hp, d, 1.3, 0.24, Color(1, 1, 1, 0.85), 0.16)
			_ring(host, hp + d * 0.3, d, 2.2, 0.32, Color(0.7, 1.0, 0.65, 0.7), 0.1)
			_burst(host, hp, 8, 0.3, 2.0, 0.22, Color(1, 1, 0.95, 0.9), 0.05, Vector3.ZERO, d, 18.0)
			pj.shake(0.35)
		Sfx.play("punch", c.global_position, 0.9))


# ================================================================== Gamadosuzan
## Gamabunta'nın kılıcı: çelik gövde, açık ağız çizgisi, koyu sırt, kırmızı sap, altın siper (+Z boyunca)
static func _toad_sword() -> ArrayMesh:
	if _c.has("toad_sword"):
		return _c["toad_sword"]
	var b = MB.new()
	b.add("box", Vector3(0, 0, 3.4), Vector3(0.12, 0.52, 5.8), Color(0.8, 0.82, 0.86))
	b.add("box", Vector3(0, -0.24, 3.4), Vector3(0.13, 0.08, 5.8), Color(0.97, 0.98, 1.0))
	b.add("box", Vector3(0, 0.25, 3.4), Vector3(0.14, 0.06, 5.8), Color(0.5, 0.53, 0.58))
	b.add("cone", Vector3(0, 0, 6.55), Vector3(0.36, 0.7, 0.13), Color(0.85, 0.87, 0.9), Vector3(90, 0, 0), 4)
	b.add("cyl", Vector3(0, 0, -0.3), Vector3(0.17, 1.2, 0.17), Color(0.55, 0.13, 0.1), Vector3(90, 0, 0), 8)
	for k in 4:
		b.add("box", Vector3(0, 0, -0.75 + k * 0.28), Vector3(0.19, 0.06, 0.06), Color(0.2, 0.06, 0.05), Vector3(0, 0, 45))
	b.add("cyl", Vector3(0, 0, 0.35), Vector3(0.55, 0.08, 0.55), Color(0.8, 0.62, 0.24), Vector3(90, 0, 0), 12)
	_c["toad_sword"] = b.build()
	return _c["toad_sword"]


## Kendi çağırma mührü: yerde mürekkep halka + dışa açılan siyah fırça darbeleri + turuncu çerçeve
static func _summon_seal(pj: PathJutsu, host: Node, p: Vector3, r: float) -> void:
	var g = pj.gp(p)
	_ring(host, g + Vector3.UP * 0.05, Vector3.UP, r * 1.4, 0.9, Color(1, 0.55, 0.15, 0.9), 0.08, 0.0, 0.5, 0.9, Color(0.1, 0.05, 0.02, 1))
	_burst(host, g + Vector3.UP * 0.06, 8, r * 0.3, r * 1.1, 0.8, Color(0.06, 0.05, 0.05, 0.9), 0.12, Vector3.UP)
	_poof(host, g + Vector3.UP * 2.0, 0.8)
	Sfx.play("poof", g, 0.8)


static func gamadosuzan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var host = _host(pj)
	_summon_seal(pj, host, c.global_position, 1.4)
	var root = Node3D.new()
	var sword = _gi(_toad_sword(), _cel(0.03))
	root.add_child(sword)
	host.add_child(root)
	sword.set_instance_shader_parameter("fade", 1.0)
	root.global_position = c.global_position + Vector3.UP * 1.3
	var base_yaw = atan2(d.x, d.z)
	root.rotation.y = base_yaw + 1.6
	root.scale = Vector3(1, 1, 0.05)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.05)
	tw.tween_property(root, "rotation:y", base_yaw - 1.6, 0.25).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.3)
	tw.tween_property(root, "scale", Vector3(0.6, 0.6, 0.02), 0.14).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	pj.after(0.35, func():
		if not is_instance_valid(c):
			return
		var o = c.global_position
		# dev yatay süpürme lekesi (çelik beyaz, mavi-gri kenar, hız kılları) + dışında ince ikinci kesik
		_smear(host, o + Vector3.UP * 1.3, Vector3.UP, d, 95.0, -95.0, 6.3, 1.7, 0.14, 0.05, 0.4, Color(0.95, 0.97, 1.0, 0.92), Color(0.45, 0.55, 0.7, 0.9), 1, 0.22, 0.6)
		_smear(host, o + Vector3.UP * 1.45, Vector3.UP, d, 90.0, -90.0, 6.75, 0.14, 0.16, 0.0, 0.3, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), 2, 0.0)
		# yerde yay biçiminde oyuk + yay boyunca sırayla fışkıran toz
		var g = pj.gp(o)
		_smear(host, g + Vector3.UP * 0.05, Vector3.UP, d, 92.0, -92.0, 5.8, 0.4, 0.2, 2.2, 0.9, Color(0.16, 0.12, 0.09, 0.85), Color(0.42, 0.35, 0.27, 0.8), 2, 0.3)
		for i in 7:
			var a = deg_to_rad(lerpf(85.0, -85.0, i / 6.0))
			var q = pj.gp(o + d.rotated(Vector3.UP, a) * 5.6)
			pj.after(i * 0.025, func():
				_dust(host, q, 4, 0.3, 0.9, 0.7, DUST, 0.45, 0.8, d.rotated(Vector3.UP, a))
				_debris(host, q, 2, 5.0, 0.15))
		Combat.hit_zone(c, c.global_position, d, 7.0, 90.0, 3.0, pj.inf(c, "gamadosuzan", 2.0, {"knock": 18.0, "kind": "heavy", "bleed": 4.0}))
		pj.shake(0.6))
	Sfx.play("clink", c.global_position, 0.6)


# ================================================================== Aian Kurō
## Her sıkışta: kafaya doğru kapanan koyu kırmızı çizgiler + daralan mengene halkası
static func _squeeze(host: Node, p: Vector3, k: int) -> void:
	_lines_in(host, p, 10, 1.1 + k * 0.15, 0.18, Color(0.3, 0.05, 0.05, 0.9), 0.06)
	_ring(host, p, Vector3.UP, 1.0, 0.2, Color(1, 0.92, 0.85, 0.8), 0.18, 0.0, 0.9, 0.35)


static func aian_kuro(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 5.0)
	pj._jump_at(c, tt, 0.0, 12.0 if tt else 2.0)
	pj.busy(c, 1.2)
	if tt == null:
		return
	var host = _host(pj)
	pj.after(0.2, func():
		if not pj.live(tt) or not pj.live(c):
			return
		pj.st(tt, "stun", 1.4)
		var y0 = tt.global_position
		# kaldırış: hedefin altından yukarı çekilen çizgiler + ayak dibinde kopan toz
		_speed(host, y0 + Vector3.UP * 1.4, Vector3.UP, 7, 1.6, 0.5, 0.3, Color(0.92, 0.95, 1.0, 0.7), 0.04)
		_dust(host, pj.gp(y0), 5, 0.4, 0.2, 0.5, DUST, 0.35, 0.7)
		var tw = tt.create_tween()
		tw.tween_property(tt, "global_position", y0 + Vector3.UP * 1.2, 0.2)
		for k in 3:
			tw.tween_callback(func():
				if pj.live(tt):
					_squeeze(host, tt.global_position + Vector3.UP * 1.6, k)
					tt.take_hit(pj.inf(c, "aian_kuro", 0.25, {"knock": 0.0, "kind": "light"}))
					Sfx.play("punch", tt.global_position, 0.8))
			tw.tween_interval(0.2)
		tw.tween_property(tt, "global_position", pj.gp(y0 + c.face_dir() * 1.2), 0.1)
		tw.tween_callback(func():
			if pj.live(tt):
				# yere çarpış: yassı halka + krater + toz + yerde çarpma çizgileri + az moloz
				var g = pj.gp(tt.global_position)
				_crater(host, g, 1.3, 2.0)
				_ring(host, g + Vector3.UP * 0.06, Vector3.UP, 3.5, 0.4, Color(0.9, 0.84, 0.72, 0.85), 0.1, 0.1)
				_burst(host, g + Vector3.UP * 0.12, 12, 0.6, 2.0, 0.3, Color(0.25, 0.2, 0.16, 0.9), 0.1, Vector3.UP)
				_dust(host, g, 8, 0.6, 0.6, 0.8, DUST, 0.55, 1.4)
				_debris(host, g, 8, 6.0, 0.18)
				pj.shake(0.35)
				tt.take_hit(pj.inf(c, "aian_kuro", 1.2, {"knock": 3.0, "kind": "heavy"}))))


# ================================================================== Issen
## Elde kısa bıçak (+Z boyunca)
static func _hand_knife(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	if not _c.has("knife"):
		var b = MB.new()
		b.add("box", Vector3(0, 0, 0.5), Vector3(0.025, 0.07, 0.9), Color(0.84, 0.87, 0.92))
		b.add("box", Vector3(0, -0.03, 0.5), Vector3(0.027, 0.015, 0.9), Color(0.97, 0.98, 1.0))
		b.add("cyl", Vector3(0, 0, -0.06), Vector3(0.03, 0.18, 0.03), Color(0.15, 0.12, 0.1), Vector3(90, 0, 0), 8)
		_c["knife"] = b.build()
	var mi = _gi(_c["knife"], _cel(0.008))
	ba.add_child(mi)
	mi.set_instance_shader_parameter("fade", 1.0)
	pj.free_after(dur, ba)


## Tırtıklı kesik izi (referanstaki gri zikzak): XY düzleminde, iki katman (koyu kontur + açık gri)
static func _jag_mesh(L: float, h: float, w: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 8
	var pts = []
	for i in n + 1:
		var x = lerpf(-L * 0.5, L * 0.5, float(i) / n)
		var y = 0.0 if i == 0 or i == n else (h if i % 2 == 0 else -h) * randf_range(0.5, 1.0)
		pts.append(Vector2(x, y))
	for layer in 2:
		var col = Color(0.15, 0.16, 0.2, 0.9) if layer == 0 else Color(0.86, 0.87, 0.9, 1.0)
		var ww = w * (1.9 if layer == 0 else 1.0)
		var z = -0.01 if layer == 0 else 0.0
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var dir = (b - a).normalized()
			var nn = Vector2(-dir.y, dir.x)
			var t0 = sin(PI * float(i) / n) * 0.85 + 0.15
			var t1 = sin(PI * float(i + 1) / n) * 0.85 + 0.15
			var A = Vector3(a.x + nn.x * ww * t0, a.y + nn.y * ww * t0, z)
			var B = Vector3(a.x - nn.x * ww * t0, a.y - nn.y * ww * t0, z)
			var C = Vector3(b.x + nn.x * ww * t1, b.y + nn.y * ww * t1, z)
			var D = Vector3(b.x - nn.x * ww * t1, b.y - nn.y * ww * t1, z)
			_tri(st, A, B, C, col, col, col)
			_tri(st, B, D, C, col, col, col)
	return st.commit()


static func issen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.4)
	if tt == null:
		return
	var host = _host(pj)
	var start = c.global_position
	var away = tt.global_position - start
	away.y = 0
	var end = pj.gp(tt.global_position + away.normalized() * 1.5)
	# başlangıçta mavi silik görüntü kalır
	_echo(host, _bake(c), c.global_transform, Color(0.45, 0.7, 1.0, 0.5), 0.3)
	# yol boyunca mavi bulanık şerit (referans): uzun mavi iğler + beyaz çekirdek, incelip söner
	var a = start + Vector3.UP
	var b = end + Vector3.UP
	var L = a.distance_to(b)
	var dirp = (b - a).normalized()
	for i in 4:
		var off = _perp(dirp) * randf_range(-0.25, 0.25) + Vector3.UP * randf_range(-0.25, 0.25)
		var col = Color(1, 1, 1, 0.9) if i == 0 else Color(0.35, 0.62, 1.0, 0.7)
		var w = 0.08 if i == 0 else randf_range(0.18, 0.32)
		var mi = _line(host, _spindle(), b + off, -dirp, w, L, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(w * 0.15, w * 0.15, L * 0.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.3)
		tw.chain().tween_callback(mi.queue_free)
	c.global_position = end
	if c is Player:
		c.combat.face_to(tt)
	# varış: küçük mavi dikey halka
	_ring(host, end + Vector3.UP, away, 1.2, 0.22, Color(0.55, 0.78, 1.0, 0.8), 0.16)
	_hand_knife(pj, c, 0.4)
	pj.after(0.1, func():
		if pj.live(tt):
			# hedefin üstünde üç tırtıklı gri kesik: çizilir, bekler, ikiye ayrılıp söner
			var hp = tt.global_position + Vector3.UP
			var ad = away.normalized()
			for i in 3:
				var mi = _gi(_jag_mesh(2.4, 0.18, 0.06), _ink())
				_put(host, mi, hp + Vector3.UP * (i - 1) * 0.25)
				_orient(mi, ad)
				mi.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(-35.0 + i * 30.0 + randf_range(-8, 8)))
				mi.set_instance_shader_parameter("tint", Color(1, 1, 1, 1))
				mi.set_instance_shader_parameter("fade", 1.0)
				mi.scale = Vector3(0.05, 1, 1)
				var tw = mi.create_tween()
				tw.tween_interval(i * 0.03)
				tw.tween_property(mi, "scale", Vector3.ONE, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
				tw.tween_interval(0.22)
				tw.tween_property(mi, "scale", Vector3(1.15, 0.2, 1), 0.2)
				tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.2)
				tw.tween_callback(mi.queue_free)
			_burst(host, hp, 6, 0.3, 1.2, 0.2, Color(0.85, 0.92, 1.0, 0.9), 0.04)
			tt.take_hit(pj.inf(c, "issen", 1.6, {"knock": 6.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1})))
	Sfx.play("whoosh", end, 2.2, 0.5)


# ================================================================== Tsukikage
## Elde katana (silah tutmuyorsa): eski davranışla aynı yerleşim (sap avuçta, ağız +Y, kök -90° X)
static func _own_katana(pj: PathJutsu, c: Node3D, dur: float) -> void:
	if c is Player and not Gear.held_ids(Game.profile).is_empty():
		return
	if not _c.has("katana"):
		var b = MB.new()
		b.add("box", Vector3(0, 0.65, 0), Vector3(0.05, 1.0, 0.012), Color(0.85, 0.88, 0.92))
		b.add("box", Vector3(0.024, 0.65, 0), Vector3(0.01, 1.0, 0.014), Color(0.98, 0.99, 1.0))
		b.add("box", Vector3(0, 0.12, 0), Vector3(0.16, 0.03, 0.1), Color(0.25, 0.2, 0.12))
		b.add("cyl", Vector3(0, -0.08, 0), Vector3(0.045, 0.32, 0.045), Color(0.15, 0.1, 0.1), Vector3.ZERO, 6)
		_c["katana"] = b.build()
	var root = Node3D.new()
	var mi = _gi(_c["katana"], _cel(0.006))
	root.add_child(mi)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(root)
		root.rotation_degrees = Vector3(-90, 0, 0)
	else:
		pj.scene_add(root, pj.hand_pos(c, true))
	mi.set_instance_shader_parameter("fade", 1.0)
	root.scale = Vector3.ONE * 0.05
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, dur - 0.4))
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(func():
		if is_instance_valid(ba):
			ba.queue_free()
		elif is_instance_valid(root):
			root.queue_free())


static func tsukikage(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	_own_katana(pj, c, 1.0)
	pj.busy(c, 0.6)
	var d = pj.fwd(c, t)
	var start = c.global_position
	var end = pj.gp((tt.global_position + d * 1.6) if tt else start + d * 9.0)
	pj.anim(c, "slash_c", 1.7)
	Sfx.play("whoosh", start, 1.5)
	var host = _host(pj)
	var hold = {"bk": null}
	pj.every(0.18, 1.0 / 60.0, func(i, k):
		if not pj.live(c):
			return
		c.global_position = pj.gp(start.lerp(end, k))
		if i % 2 == 0:
			# ay ışığı tonunda silik görüntüler (poz bir kez pişirilir)
			if hold["bk"] == null:
				hold["bk"] = _bake(c)
			_echo(host, hold["bk"], c.global_transform, Color(0.72, 0.8, 1.0, 0.4), 0.35), func():
		if not pj.live(c):
			return
		var at = (tt.global_position if tt and pj.live(tt) else end) + Vector3.UP * 1.1
		var sd = d.cross(Vector3.UP).normalized() * -1.0
		# hilal ay kesiği: eğik düzlemde ortası kalın soluk sarı hilal, açık mavi kenar; dışında ince ikinci hilal
		var ax = Vector3.UP.rotated(d, deg_to_rad(28.0))
		_smear(host, at, ax, sd, -95.0, 95.0, 1.9, 0.75, 0.07, 0.25, 0.35, Color(1.0, 0.97, 0.8, 0.95), Color(0.74, 0.8, 1.0, 0.85), 0, 0.28, 0.4)
		_smear(host, at, ax, sd, -80.0, 80.0, 2.25, 0.1, 0.1, 0.18, 0.3, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), 0, 0.0)
		var hs = pj.hit(c, at + sd * 1.9 * 0.6, 1.9 * 0.9, pj.inf(c, "tsukikage", 1.4, {"knock": 7.0, "kind": "heavy", "bleed": 3.0}))
		if not hs.is_empty():
			_burst(host, hs[0].global_position + Vector3.UP, 8, 0.2, 0.9, 0.2, Color(1, 0.97, 0.82, 0.9), 0.05)
		Sfx.play("clink", at, 0.9))


# ================================================================== Konoha Otoshi
## Uçuşan yapraklar (Konoha): küçük yeşil eşkenar dörtgenler savrulup yavaşça düşer
static func _leaves(host: Node, p: Vector3, n: int) -> void:
	if not _c.has("leaf"):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var w = Color(1, 1, 1, 1)
		_tri(st, Vector3(0, 0, -0.5), Vector3(0.22, 0, 0), Vector3(0, 0, 0.5), w, w, w)
		_tri(st, Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), Vector3(-0.22, 0, 0), w, w, w)
		_c["leaf"] = st.commit()
	for i in n:
		var mi = _gi(_c["leaf"], _ink())
		_put(host, mi, p + Vector3.UP * 0.3)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		mi.scale = Vector3.ONE * randf_range(0.18, 0.3)
		mi.set_instance_shader_parameter("tint", Color(0.42, 0.68, 0.3, 1).lightened(randf_range(-0.1, 0.15)))
		mi.set_instance_shader_parameter("fade", 1.0)
		var h = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.2, 3.0)
		var vy = randf_range(2.5, 4.5)
		var p0 = mi.global_position
		var lf = randf_range(1.0, 1.5)
		var tw = mi.create_tween().set_parallel()
		tw.tween_method(func(k: float) -> void:
			if is_instance_valid(mi):
				var tt = k * lf
				mi.global_position = p0 + h * (1.0 - exp(-tt * 2.0)) * 0.6 + Vector3.UP * (vy * (1.0 - exp(-tt * 3.0)) / 3.0 - tt * 0.9) + Vector3(sin(tt * 9.0), 0, cos(tt * 7.0)) * 0.12, 0.0, 1.0, lf)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), lf)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, lf * 0.4).set_delay(lf * 0.6)
		tw.chain().tween_callback(mi.queue_free)


static func konoha_otoshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._face(c, tt)
	pj.busy(c, 0.8)
	if c is CharacterBody3D:
		c.velocity = d * 4.0 + Vector3.UP * 9.0
	pj._kick_pose(c, 0.7)
	var host = _host(pj)
	_dust(host, pj.gp(c.global_position), 6, 0.4, 0.3, 0.5, DUST, 0.4, 0.9)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		if c is CharacterBody3D:
			c.velocity = d * 3.0 + Vector3.DOWN * 22.0
		# topuk yayı: başın arkasından öne-aşağı inen dikey leke (beyaz, yaprak yeşili kenar) + düşüş çizgileri
		_smear(host, c.global_position + Vector3.UP * 1.3 + d * 0.3, Vector3.UP.cross(d), Vector3.UP, -50.0, 170.0, 1.35, 0.5, 0.12, 0.04, 0.2, Color(1, 1, 0.95, 0.9), Color(0.5, 0.78, 0.38, 0.9), 1, 0.32, 0.5)
		_speed(host, c.global_position + Vector3.UP * 0.8 + d * 0.6, Vector3.DOWN, 7, 2.0, 0.6, 0.25, Color(0.95, 1.0, 0.92, 0.75), 0.05)
		pj.after(0.15, func():
			if not is_instance_valid(c):
				return
			var at = pj.gp(c.global_position + d * 0.8)
			# yassı çift halka + topuk altında artı biçimli düz çatlak + yaprak savrulması + moloz
			_ring(host, at + Vector3.UP * 0.06, Vector3.UP, 4.0, 0.4, Color(0.92, 0.86, 0.66, 0.85), 0.1, 0.05)
			_ring(host, at + Vector3.UP * 0.07, Vector3.UP, 2.6, 0.3, Color(1, 1, 0.95, 0.85), 0.14)
			_cracks(host, at, 2.8, 4, 2.5, d)
			_burst(host, at + Vector3.UP * 0.5, 9, 0.3, 1.3, 0.22, Color(1, 0.95, 0.8, 0.95), 0.07, Vector3.ZERO, Vector3.UP, 70.0)
			_leaves(host, at, 10)
			_debris(host, at, 16, 6.0, 0.2)
			_dust(host, at, 8, 0.6, 0.4, 0.7, DUST, 0.5, 1.5)
			pj.shake(0.6)
			for e in pj.hit(c, at + Vector3.UP, 2.4, pj.inf(c, "konoha_otoshi", 1.5, {"knock": 4.0, "kind": "heavy"})):
				pj.st(e, "stun", 1.0)
			Sfx.play("hit_heavy", at, 0.9)))


# ================================================================== Sōshūga
## Çift nunçaku (referans: iki elde nunçaku): sap avuçta, zincirle bağlı ikinci sopa sürekli döner
static func _nunchaku(pj: PathJutsu, c: Node3D, dur: float) -> void:
	if not _c.has("nun_stick"):
		var b = MB.new()
		b.add("cyl", Vector3(0, 0, 0.22), Vector3(0.07, 0.46, 0.07), Color(0.42, 0.27, 0.18), Vector3(90, 0, 0), 8)
		b.add("cyl", Vector3(0, 0, 0.02), Vector3(0.078, 0.04, 0.078), Color(0.6, 0.6, 0.62), Vector3(90, 0, 0), 8)
		b.add("cyl", Vector3(0, 0, 0.42), Vector3(0.078, 0.04, 0.078), Color(0.6, 0.6, 0.62), Vector3(90, 0, 0), 8)
		_c["nun_stick"] = b.build()
		var ch = MB.new()
		for k in 3:
			ch.add("sphere", Vector3(0, 0, 0.03 + k * 0.035), Vector3(0.025, 0.025, 0.035), Color(0.55, 0.55, 0.58), Vector3.ZERO, 6)
		_c["nun_chain"] = ch.build()
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba == null:
			continue
		var h = _gi(_c["nun_stick"], _cel(0.01))
		ba.add_child(h)
		h.position = Vector3(0, 0, -0.1)
		h.set_instance_shader_parameter("fade", 1.0)
		var piv = Node3D.new()
		ba.add_child(piv)
		piv.position = Vector3(0, 0, 0.34)
		var chain = _gi(_c["nun_chain"], _cel(0.005))
		piv.add_child(chain)
		chain.set_instance_shader_parameter("fade", 1.0)
		var s2 = _gi(_c["nun_stick"], _cel(0.01))
		piv.add_child(s2)
		s2.position = Vector3(0, 0, 0.12)
		s2.set_instance_shader_parameter("fade", 1.0)
		Game.safe_loops(piv.create_tween()).tween_property(piv, "rotation:x", TAU * (1.0 if side == "RightHand" else -1.0), 0.16).from(0.0)
		pj.free_after(dur, ba)


## Nunçaku girdabı: hedefin önünde iki eğik daire leke (ikiz sopa = sekiz çizen iki yarım), koyu ahşap çekirdek + krem kenar
static func _whirl(host: Node, p: Vector3, d: Vector3, k: int) -> void:
	var side = d.cross(Vector3.UP).normalized()
	for s in [-1.0, 1.0]:
		var ax = side.rotated(d, deg_to_rad(35.0 * s + k * 20.0))
		var a0 = -140.0 + k * 60.0
		_smear(host, p + side * 0.35 * s, ax, Vector3.UP, a0, a0 + 290.0 * s, 0.8, 0.38, 0.09, 0.0, 0.16, Color(0.42, 0.28, 0.18, 0.75), Color(0.96, 0.9, 0.78, 0.85), 1, 0.3, 0.7)


static func soshuga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 0.9)
	_nunchaku(pj, c, 0.9)
	var host = _host(pj)
	var d = pj._jump_at(c, tt, 0.0, 18.0 if tt else 6.0)
	_speed(host, c.global_position + Vector3.UP, d, 9, 2.0, 0.8, 0.28, Color(0.9, 0.88, 0.8, 0.7), 0.045)
	for k in 2:
		pj.after(0.15 + k * 0.15, func():
			if not pj.live(c):
				return
			pj.anim(c, "slash_a" if k == 0 else "slash_b", 2.0)
			_whirl(host, c.global_position + Vector3.UP * 1.1 + d, d, k)
			var hs = pj.hit(c, c.global_position + Vector3.UP + d * 1.3, 1.8, pj.inf(c, "soshuga", 0.8, {"knock": 6.0, "kind": "heavy", "bleed": 2.0}))
			if not hs.is_empty():
				# sopa çarpması: kısa sert "tak" çizgileri
				_burst(host, hs[0].global_position + Vector3.UP * 1.1, 7, 0.15, 0.8, 0.15, Color(1, 0.94, 0.82, 0.95), 0.05))
	pj.after(0.55, func():
		if pj.live(c):
			pj._kick_pose(c, 0.25)
			# bitiriş tekmesi: yatay tekme lekesi + hedefte dikey halka ve öne çizgiler
			_smear(host, c.global_position + Vector3.UP * 1.2, Vector3.UP, d, -100.0, 30.0, 1.3, 0.45, 0.08, 0.0, 0.18, Color(1, 0.98, 0.92, 0.85), Color(0.9, 0.78, 0.6, 0.9), 1, 0.3)
			var hs = pj.hit(c, c.global_position + Vector3.UP * 1.2 + d * 1.2, 1.8, pj.inf(c, "soshuga", 0.9, {"knock": 16.0, "launch": 4.0, "kind": "heavy"}))
			if not hs.is_empty():
				var hp = hs[0].global_position + Vector3.UP
				_ring(host, hp, d, 1.6, 0.25, Color(1, 0.96, 0.85, 0.85), 0.14)
				_burst(host, hp, 10, 0.3, 1.8, 0.24, Color(1, 0.93, 0.78, 0.95), 0.07, Vector3.ZERO, d, 30.0)
				pj.shake(0.3))
	Sfx.play("clink", c.global_position, 1.2)


# ================================================================== Daburu Dainamikku Entorī
static func daburu_dainamikku_entori(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 0.8)
	var host = _host(pj)
	var side = c.face_dir().cross(Vector3.UP)
	_poof(host, c.global_position + side * 1.5 + Vector3.UP, 0.8)
	var bk = _bake(c)
	pj._jump_at(c, tt, 2.0, 16.0 if tt else 4.0)
	var f = c.face_dir()
	side = f.cross(Vector3.UP)
	# gölge klon: gerçek malzemeli kopya yanında belirir ve birlikte uçar
	var clone = _echo(host, bk, _xf_facing(c, c.global_position + side * 1.5, f), Color.WHITE, 0.0, true)
	pj.free_after(0.62, clone)
	clone.create_tween().tween_method(func(k: float) -> void:
		if is_instance_valid(c) and is_instance_valid(clone):
			clone.global_position = c.global_position + side * lerpf(1.5, 1.0, k), 0.0, 1.0, 0.3)
	# iki gövdenin çevresinde dalgalı rüzgâr çizgileri (referans)
	for s in [0.0, 1.0]:
		_speed(host, c.global_position + Vector3.UP * 1.0 + side * s, f, 6, 2.2, 0.55, 0.32, Color(0.95, 0.97, 1.0, 0.7), 0.045)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var at = c.global_position + Vector3.UP + c.face_dir() * 1.0
		var at2 = at + c.face_dir().cross(Vector3.UP) * 1.0
		var fd = c.face_dir()
		# iki tekme izi: yan yana iki çarpma karesi + önde iki yatay rüzgâr hilali + yere tek çatlak
		_burst(host, at, 12, 0.3, 2.2, 0.26, Color(1, 0.96, 0.85, 0.95), 0.08)
		_burst(host, at2, 9, 0.25, 1.5, 0.22, Color(1, 0.96, 0.85, 0.9), 0.06)
		_smear(host, at - fd * 0.6, Vector3.UP, fd, -60.0, 60.0, 1.5, 0.3, 0.07, 0.0, 0.2, Color(1, 1, 1, 0.75), Color(0.85, 0.9, 1.0, 0.8), 0, 0.3)
		_smear(host, at2 - fd * 0.6, Vector3.UP, fd, -50.0, 50.0, 1.3, 0.25, 0.07, 0.03, 0.2, Color(1, 1, 1, 0.7), Color(0.85, 0.9, 1.0, 0.75), 0, 0.3)
		_ring(host, at + fd * 0.4, fd, 1.8, 0.26, Color(1, 1, 1, 0.8), 0.12)
		var g = pj.gp(at)
		if at.y - g.y < 2.5:
			_cracks(host, g, 3.3, 5, 2.0)
			_dust(host, g, 6, 0.5, 0.5, 0.7, DUST, 0.5, 1.3, fd)
		pj.shake(0.375)
		pj.shake(0.25)
		var hs = pj.hit(c, at, 2.2, pj.inf(c, "daburu_dainamikku_entori", 1.6, {"knock": 20.0, "launch": 3.0, "kind": "heavy"}))
		if not hs.is_empty():
			_ring(host, hs[0].global_position + Vector3.UP, fd, 2.4, 0.3, Color(1, 0.94, 0.8, 0.8), 0.1)
		Sfx.play("punch", at, 0.8)
		pj.after(0.25, func():
			if is_instance_valid(clone):
				_poof(host, clone.global_position + Vector3.UP, 0.7)
				clone.queue_free()))


# ================================================================== Uzumaki Nisen Rendan
## Tek klon dalışı: halkadan çıkıp hedefe atılır (arkasında turuncu hız çizgileri), varınca pof + kısa çarpma çizgileri
static func _clone_rush(pj: PathJutsu, host: Node, c: Node3D, bk: Array, p: Vector3, at: Vector3) -> void:
	_poof(host, p + Vector3.UP, 0.5)
	var dir = at - p
	dir.y = 0
	var dn = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var stop = at - dn * 0.7
	var body: Node3D
	var real = not bk.is_empty() and is_instance_valid(c)
	if real:
		body = _echo(host, bk, _xf_facing(c, p, dn), Color.WHITE, 0.0, true)
	else:
		body = _line(host, _spindle(), p + Vector3.UP, -dn, 0.35, 1.2, Color(1, 0.6, 0.2, 0.9))
	_speed(host, p.lerp(stop, 0.5) + Vector3.UP * 1.0, dn, 3, dir.length() * 0.6, 0.4, 0.3, Color(1, 0.7, 0.35, 0.75), 0.06)
	var tw = body.create_tween()
	tw.tween_property(body, "global_position", stop + (Vector3.ZERO if real else Vector3.UP), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var hp = at + Vector3.UP + Vector3(randf_range(-0.6, 0.6), randf_range(0, 0.8), randf_range(-0.6, 0.6))
		_poof(host, hp, 0.4)
		_burst(host, hp, 5, 0.15, 0.7, 0.14, Color(1, 0.88, 0.6, 0.95), 0.05)
		body.queue_free())
	pj.free_after(0.6, body)


static func uzumaki_nisen_rendan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 18.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + c.face_dir() * 8.0)
	var host = _host(pj)
	var bk = _bake(c)
	for k in 16:
		pj.after(k * 0.06, func():
			var a = randf() * TAU
			var p = pj.gp(at + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 8.0))
			_clone_rush(pj, host, c, bk, p, at)
			pj.hit(c, at + Vector3.UP, 1.8, pj.inf(c, "uzumaki_nisen_rendan", 0.2, {"knock": 1.5, "kind": "light"})))
	pj.after(1.0, func():
		# üst üste yığılma bitişi: turuncu-beyaz büyük çarpma karesi + yer halkası + toz + çatlak
		var hp = at + Vector3.UP
		_burst(host, hp, 18, 0.4, 2.6, 0.32, Color(1, 0.86, 0.5, 0.95), 0.12)
		_burst(host, hp, 8, 0.3, 1.6, 0.24, Color(1, 1, 1, 0.9), 0.06)
		_ring(host, at + Vector3.UP * 0.06, Vector3.UP, 3.4, 0.4, Color(1, 0.9, 0.7, 0.85), 0.1, 0.12)
		_cracks(host, at, 3.5, 7, 2.5)
		_dust(host, at, 10, 0.8, 0.8, 0.9, DUST, 0.6, 1.6)
		pj.shake(0.4))
	Sfx.play("whoosh", c.global_position, 1.2)


# ================================================================== Tetsuzankō
static func tetsuzanko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 5.0)
	pj._jump_at(c, tt, 0.0, 10.0 if tt else 2.0)
	pj.busy(c, 0.6)
	var host = _host(pj)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var f = c.face_dir()
		var at = c.global_position + Vector3.UP * 1.1 + f * 0.9
		var g = pj.gp(c.global_position)
		# ayak basışı: ayağın altında çatlak + küçük krater, toz geriye savrulur
		_cracks(host, g, 3.0, 6, 2.5)
		_crater(host, g, 1.1, 2.0)
		_dust(host, g, 7, 0.4, 0.25, 0.6, DUST, 0.5, 1.6, -f)
		# omuz darbesi: yatay basık oval şok + gecikmeli ikinci büyük oval + öne geniş koni çizgiler
		_ring(host, at, f, 1.6, 0.26, Color(1, 0.97, 0.9, 0.9), 0.2, 0.0, 0.08, 0.92, Color(0, 0, 0, 0), Vector2(1.0, 0.62))
		_ring(host, at + f * 0.5, f, 2.6, 0.36, Color(0.95, 0.9, 0.8, 0.7), 0.1, 0.08, 0.2, 0.92, Color(0, 0, 0, 0), Vector2(1.0, 0.62))
		_burst(host, at + f * 0.3, 14, 0.4, 2.8, 0.28, Color(1, 0.95, 0.85, 0.95), 0.1, Vector3.ZERO, f, 35.0)
		pj.shake(0.4)
		pj.hit(c, at, 1.8, pj.inf(c, "tetsuzanko", 1.8, {"knock": 22.0, "launch": 3.0, "kind": "heavy", "stun": 0.6}))
		Sfx.play("boom", at, 1.2))


# ================================================================== Kassokuken: Isshiki
## Jūgo'nun jet kolu: piston gövde + kutu + dört egzoz deliği (kendi modeli, konturlu)
static func _jet_arm_mesh() -> ArrayMesh:
	if _c.has("jet_arm"):
		return _c["jet_arm"]
	var b = MB.new()
	b.add("cyl", Vector3(0, 0.15, 0), Vector3(0.34, 0.5, 0.34), Color(0.58, 0.5, 0.44), Vector3.ZERO, 10)
	b.add("box", Vector3(0, 0.45, 0), Vector3(0.44, 0.24, 0.44), Color(0.5, 0.44, 0.38))
	b.add("torus", Vector3(0, 0.02, 0), Vector3(0.4, 0.4, 0.4), Color(0.4, 0.34, 0.3), Vector3.ZERO, 12)
	for k in 4:
		b.add("cyl", Vector3(cos(k * PI * 0.5) * 0.17, -0.12, sin(k * PI * 0.5) * 0.17), Vector3(0.09, 0.14, 0.09), Color(0.22, 0.2, 0.18), Vector3.ZERO, 8)
	_c["jet_arm"] = b.build()
	return _c["jet_arm"]


## Jet itişi: geriye fışkıran beyaz-açık mavi jet çizgileri + memede sıkışma halkası + uzayan buhar topakları
static func _jet_burst(host: Node, p: Vector3, back: Vector3, k: int) -> void:
	for i in 5:
		var dd = _cone_dir(back, 8.0)
		var L = randf_range(2.0, 2.8) + k * 0.8
		var col = Color(1, 1, 1, 0.95) if i < 2 else Color(0.7, 0.88, 1.0, 0.8)
		var w = 0.12 if i < 2 else 0.2
		var mi = _line(host, _spindle(), p + dd * 0.1, dd, w, 0.3, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(w * 0.4, w * 0.4, L), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.2).set_delay(0.1)
		tw.chain().tween_callback(mi.queue_free)
	_ring(host, p, back, 0.7, 0.18, Color(1, 1, 1, 0.85), 0.25)
	_dust(host, p + back * 0.6, 6, 0.2, 0.15, 0.6, Color(0.93, 0.94, 0.96, 0.75), 0.45, 2.2, back)


static func kassokuken_isshiki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.0)
	var host = _host(pj)
	var arm = _gi(_jet_arm_mesh(), _cel(0.02))
	var ba = pj.bone_attach(c, "RightLowerArm")
	if ba == null:
		arm.queue_free()
	else:
		ba.add_child(arm)
		arm.set_instance_shader_parameter("fade", 1.0)
		arm.scale = Vector3.ONE * 0.2
		arm.create_tween().tween_property(arm, "scale", Vector3.ONE * 1.4, 0.2).set_trans(Tween.TRANS_BACK)
		pj.free_after(1.0, ba)
	for k in 2:
		pj.after(0.3 + k * 0.3, func():
			if not pj.live(c):
				return
			var d = pj._face(c, tt)
			pj._jump_at(c, tt, 0.0, 6.0)
			var nz = c.global_position + Vector3.UP * 1.2 - d * 0.5
			if is_instance_valid(arm) and arm.is_inside_tree():
				nz = arm.global_position - d * 0.3
			_jet_burst(host, nz, -d, k)
			var at = c.global_position + Vector3.UP * 1.2 + d * 2.0
			# pistonlu yumruk: iç içe sıkışma halkaları + öne koni çizgiler; ikinci vuruşta yer çatlar
			var s = 1.2
			_ring(host, at, d, 1.3 * s + k * 0.6, 0.22, Color(1, 1, 1, 0.9), 0.2)
			_ring(host, at + d * 0.4, d, 2.0 * s + k * 0.8, 0.3, Color(0.8, 0.86, 0.92, 0.75), 0.1)
			_burst(host, at, 10 + k * 4, 0.3, 2.0 + k * 0.8, 0.26, Color(1, 0.96, 0.88, 0.95), 0.08 + k * 0.03, Vector3.ZERO, d, 30.0)
			var g = pj.gp(at)
			if k == 1 and at.y - g.y < 2.5:
				_cracks(host, g, 2.2 * s, 6, 2.5)
				_dust(host, g, 7, 0.5, 0.6, 0.8, DUST, 0.55, 1.4)
			pj.shake(0.25 * s)
			pj.hit(c, at, 2.4, pj.inf(c, "kassokuken_isshiki", 1.4, {"knock": 14.0 + k * 14.0, "launch": 3.0 * k, "kind": "heavy", "hitstop": 0.1}))
			Sfx.play("boom", at, 1.1))
