class_name NinjutsuFXA
extends RefCounted
## Genel ninjutsu A grubu (tek bir doğaya bağlı olmayan teknikler): görseller sıfırdan, bu dosyanın kendi gölgelendiricileri ve
## yapı taşlarıyla (Rasengan çekirdek malzemesi, çakra iplikleri, tılsım / mühür parçaları, zemin izleri, parça yağmuru).
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hücum / mermi davranışı) ana ağaçtaki Jutsu / PathJutsu / ClanJutsu
## gövdelerinden satır satır taşındı. Dersler: hiçbir parça ekranı kaplamaz (kameraya yakın kısım söner), kenarlar okunur.

const RAS_CORE := Color(0.96, 0.99, 1.0)
const RAS_BODY := Color(0.42, 0.7, 1.0)
const RAS_LINE := Color(0.86, 0.95, 1.0)
const RAS_RIM := Color(0.16, 0.36, 0.82)
const BIJU_BODY := Color(0.05, 0.02, 0.08)
const BIJU_LINE := Color(0.36, 0.13, 0.56)
const BIJU_RIM := Color(0.72, 0.42, 1.0)
const BIJU_HOT := Color(1.0, 0.62, 0.34)
const BARYON_RED := Color(1.0, 0.3, 0.35)
const BARYON_EDGE := Color(1.0, 0.88, 0.78)
const ENMA_GOLD := Color(0.98, 0.72, 0.1)
const ENMA_BLACK := Color(0.12, 0.12, 0.14)
const SEAL_ORANGE := Color(0.86, 0.45, 0.16)
const PAPER := Color(0.94, 0.9, 0.78)
const INK := Color(0.1, 0.09, 0.1)
const TAG_RED := Color(0.78, 0.12, 0.1)
const CORAL := Color(0.9, 0.35, 0.3)
const CORAL_TIP := Color(1.0, 0.74, 0.64)
const EARTH := Color(0.46, 0.38, 0.29)
const LEAF := Color(0.4, 0.66, 0.27)
const LEAF_DARK := Color(0.2, 0.38, 0.14)
const VIOLET := Color(0.66, 0.36, 1.0)
const VIOLET_CORE := Color(0.96, 0.88, 1.0)
const BLOOD := Color(0.55, 0.03, 0.05)
const BLAST_PALE := Color(0.9, 0.95, 1.0)
const BLAST_SHADE := Color(0.55, 0.72, 0.92)

static var _sh := {}
static var _mesh := {}


# ═════════════════════════════════════════ gölgelendiriciler (bu dosyanın kendi kodu) ═════════════════════════════════════════

## Şerit: UV.x boy (0 kuyruk → 1 baş), UV.y en. Ortası core_col, kenarı edge_col (cel kontur); baş/kuyruk açılması, salınım,
## kameraya yakın kısım söner
const SRC_RIB := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, %BLEND%;
uniform vec4 core_col : source_color = vec4(1.0);
uniform vec4 edge_col : source_color = vec4(0.5, 0.75, 1.0, 1.0);
uniform float edge_w = 0.3;
uniform float asym = 0.0;
uniform float inner_fade = 0.0;
uniform float soft = 0.12;
uniform float head = 1.0;
uniform float tail = 0.0;
uniform float tip_fade = 0.0;
uniform float fade = 1.0;
uniform float near_a = 1.0;
uniform float near_b = 3.5;
uniform vec3 sway_dir = vec3(0.0);
uniform float sway_f = 3.0;
uniform float phase = 0.0;
void vertex() {
	VERTEX += sway_dir * sin(TIME * sway_f + UV.x * 5.0 + phase) * UV.x;
}
void fragment() {
	float v = UV.y;
	float d = mix(abs(v - 0.5) * 2.0, 1.0 - v, asym);
	float e = smoothstep(1.0 - edge_w - 0.04, 1.0 - edge_w + 0.04, d);
	vec3 c = mix(core_col.rgb, edge_col.rgb, e);
	float a = mix(core_col.a, edge_col.a, e);
	a *= 1.0 - smoothstep(1.0 - soft, 1.0, d);
	a *= 1.0 - inner_fade * smoothstep(0.25, 1.0, v);
	float x = UV.x;
	a *= step(x, head) * smoothstep(tail, tail + 0.08, x);
	a *= 1.0 - tip_fade * smoothstep(0.7, 1.0, x);
	a *= smoothstep(near_a, near_b, -VERTEX.z);
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(a * fade * COLOR.a, 0.0, 1.0);
}
"""

## Çakra küresi: nesne uzayında iki aileden sarmal çizgiler (zamanla döner), bakışa dönük parlak göbek, siluette kontur halkası
const SRC_ORB := """shader_type spatial;
render_mode unshaded, %CULL%, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 core_col : source_color = vec4(1.0);
uniform vec4 body_col : source_color = vec4(0.45, 0.72, 1.0, 0.9);
uniform vec4 line_col : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform vec4 rim_col : source_color = vec4(0.2, 0.4, 0.85, 1.0);
uniform float arms = 5.0;
uniform float twist = 2.5;
uniform float spin = 1.6;
uniform float lw = 0.18;
uniform float core_size = 0.45;
uniform float rim_w = 0.12;
uniform float fade = 1.0;
uniform float near_a = 0.8;
uniform float near_b = 2.5;
varying vec3 lp;
void vertex() { lp = VERTEX; }
float band(float x, float w) { float f = abs(fract(x) - 0.5) * 2.0; return smoothstep(1.0 - w, 1.0, f); }
void fragment() {
	vec3 p = normalize(lp + vec3(0.00001));
	float lon = atan(p.z, p.x);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float l1 = band(lon * arms / 6.2831853 + lat * twist + TIME * spin, lw);
	float lon2 = atan(p.y, p.x);
	float lat2 = asin(clamp(p.z, -1.0, 1.0));
	float l2 = band(lon2 * max(arms - 1.0, 1.0) / 6.2831853 - lat2 * twist * 0.8 - TIME * spin * 1.3, lw * 0.7);
	float lines = max(l1, l2 * 0.75) * step(0.001, lw);
	float fr = 1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float core = (1.0 - smoothstep(core_size * 0.5, core_size, fr)) * step(0.001, core_size);
	vec3 c = mix(body_col.rgb, line_col.rgb, lines);
	c = mix(c, core_col.rgb, core * core_col.a);
	float rim = smoothstep(1.0 - rim_w, 1.0 - rim_w * 0.4, fr);
	c = mix(c, rim_col.rgb, rim);
	float a = mix(body_col.a, 1.0, max(lines * line_col.a, core * core_col.a));
	a = mix(a, rim_col.a, rim);
	a *= smoothstep(near_a, near_b, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""

## Kameraya dönük ışınsal hale (Rasengan çevresindeki ince çakra çizgileri): titreyen boylu ince ışınlar + iç halka
const SRC_HALO := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 col : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float r0 = 0.55;
uniform float r1 = 0.95;
uniform float rays = 48.0;
uniform float spin = 0.6;
uniform float fade = 1.0;
uniform float near_a = 0.8;
uniform float near_b = 2.5;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
float hsh(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x) / 6.2831853 + 0.5 + TIME * spin * 0.05;
	float idx = floor(ang * rays);
	float f = fract(ang * rays);
	float ray = smoothstep(0.5, 0.15, abs(f - 0.5));
	float len = mix(r0, r1, hsh(idx + floor(TIME * 12.0) * 0.37));
	float a = ray * smoothstep(r0 * 0.8, r0, r) * (1.0 - smoothstep(len - 0.08, len, r));
	float ring = smoothstep(0.04, 0.0, abs(r - r0)) * 0.6;
	a = max(a * 0.7, ring);
	a *= smoothstep(near_a, near_b, -VERTEX.z);
	ALBEDO = col.rgb;
	ALPHA = clamp(a * col.a * fade, 0.0, 1.0);
}
"""

## Cel katı: köşe rengi × tint, iki tonlu ışık, isteğe bağlı parlama ve (alfa sürümünde) sönme
const SRC_CEL := """shader_type spatial;
render_mode cull_back, specular_disabled%MODE%;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fade = 1.0;
uniform float glow = 0.0;
uniform float shade = 0.55;
uniform float near_a = 1.5;
uniform float near_b = 5.0;
void fragment() {
	ALBEDO = COLOR.rgb * tint.rgb;
	EMISSION = COLOR.rgb * tint.rgb * glow;
	ROUGHNESS = 1.0;
	%ALPHA%
}
void light() {
	float k = mix(shade, 1.0, smoothstep(0.0, 0.08, dot(NORMAL, LIGHT)));
	DIFFUSE_LIGHT += k * ATTENUATION * LIGHT_COLOR / PI;
}
"""

## Ters kabuk kontur (anime koyu kenar)
const SRC_OUT := """shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, %MODE%;
uniform vec4 col : source_color = vec4(0.07, 0.06, 0.08, 1.0);
uniform float grow = 0.03;
uniform float fade = 1.0;
uniform float near_a = 1.5;
uniform float near_b = 5.0;
void vertex() { VERTEX += NORMAL * grow; }
void fragment() {
	ALBEDO = col.rgb;
	%ALPHA%
}
"""

## Zemin izi (PlaneMesh): dolu disk / halka / kare, tırtıklı kenar, dışa kırık çizgiler
const SRC_DISC := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, %BLEND%;
uniform vec4 col : source_color = vec4(0.1, 0.08, 0.07, 0.6);
uniform vec4 col2 : source_color = vec4(0.0);
uniform float ring_r = 0.0;
uniform float ring_w = 0.1;
uniform float disc_r = 1.0;
uniform float edge_soft = 0.25;
uniform float jag = 0.15;
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float spokes = 0.0;
uniform float square = 0.0;
float hsh(float n) { return fract(sin(n * 91.7 + seed * 13.3) * 43758.5453); }
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = mix(length(q), max(abs(q.x), abs(q.y)), square);
	float ang = atan(q.y, q.x);
	float wob = 1.0 - jag * (0.5 + 0.5 * sin(ang * 7.0 + seed * 5.0) * sin(ang * 3.0 - seed));
	float a = 0.0;
	if (ring_r > 0.0) {
		a = 1.0 - smoothstep(0.0, ring_w, abs(r - ring_r * wob));
	} else {
		a = 1.0 - smoothstep(disc_r * (1.0 - edge_soft) * wob, disc_r * wob, r);
	}
	vec3 c = mix(col.rgb, col2.rgb, col2.a * smoothstep(0.0, 0.7, r));
	if (spokes > 0.0) {
		float s = ang / 6.2831853 * spokes + seed + sin(r * 18.0 + seed) * 0.04;
		float idx = floor(s);
		float f = abs(fract(s) - 0.5) / spokes * 6.2831853 * r;
		float wid = 0.035 * (1.0 - r) + 0.006;
		float lim = 0.45 + 0.5 * hsh(idx);
		float sp = (1.0 - smoothstep(wid * 0.5, wid, f)) * step(r, lim);
		a = max(a, sp);
		c = mix(c, col.rgb * 0.7, sp);
	}
	a *= 1.0 - smoothstep(0.97, 1.0, r);
	ALBEDO = c;
	ALPHA = clamp(a * col.a * fade, 0.0, 1.0);
}
"""


# ═════════════════════════════════════════ altyapı ═════════════════════════════════════════

## Her kare fn(düğüm, dt, yaş) çağırır; false dönünce kendini siler
class Tick extends Node3D:
	var fn: Callable
	var age := 0.0

	func _process(dt: float) -> void:
		age += dt
		var keep = false
		if fn.is_valid():
			keep = fn.call(self, dt, age) == true
		if not keep:
			set_process(false)
			queue_free()


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _scene() -> Node:
	return _tree().current_scene


static func _cam() -> Vector3:
	var tr = _tree()
	if tr and tr.root:
		var cam = tr.root.get_camera_3d()
		if cam:
			return cam.global_position
	return Vector3(0, 500, 0)


static func _g(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z), p.z)


static func _rdir() -> Vector3:
	var v = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized() if v.length() > 0.05 else Vector3.UP


static func _height(e: Node3D) -> float:
	if e == null or not is_instance_valid(e):
		return 1.8
	var h = e.get("height")
	return float(h) if h != null else 1.8


static func _host(fn: Callable, at := Vector3.ZERO, parent: Node = null) -> Tick:
	var tk = Tick.new()
	tk.fn = fn
	var sc = _scene()
	if parent == null:
		parent = sc
	parent.add_child(tk)
	if parent == sc:
		tk.global_position = at
	else:
		tk.position = at
	return tk


static func _put(n: Node3D, at: Vector3) -> Node3D:
	_scene().add_child(n)
	n.global_position = at
	return n


## Düğümün (yerel ofsetli) dünya konumunu veren işlev; düğüm yoksa Vector3.INF
static func _follow(n: Node3D, off := Vector3.ZERO) -> Callable:
	var w = weakref(n)
	return func() -> Vector3:
		var x = w.get_ref()
		if x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return Vector3.INF
		return x.global_transform * off


static func _shader(kind: String) -> Shader:
	if _sh.has(kind):
		return _sh[kind]
	var src := ""
	match kind:
		"rib":
			src = SRC_RIB.replace("%BLEND%", "blend_mix")
		"rib_add":
			src = SRC_RIB.replace("%BLEND%", "blend_add")
		"orb":
			src = SRC_ORB.replace("%CULL%", "cull_back")
		"orb_ds":
			src = SRC_ORB.replace("%CULL%", "cull_disabled")
		"halo":
			src = SRC_HALO
		"cel":
			src = SRC_CEL.replace("%MODE%", "").replace("%ALPHA%", "")
		"cel_a":
			src = SRC_CEL.replace("%MODE%", ", depth_prepass_alpha").replace("%ALPHA%", "ALPHA = clamp(fade * tint.a * smoothstep(near_a, near_b, -VERTEX.z), 0.0, 1.0);")
		"out":
			src = SRC_OUT.replace("%MODE%", "depth_draw_opaque").replace("%ALPHA%", "")
		"out_a":
			src = SRC_OUT.replace("%MODE%", "depth_draw_never, blend_mix").replace("%ALPHA%", "ALPHA = clamp(fade * col.a * smoothstep(near_a, near_b, -VERTEX.z), 0.0, 1.0);")
		"disc":
			src = SRC_DISC.replace("%BLEND%", "blend_mix")
		"disc_add":
			src = SRC_DISC.replace("%BLEND%", "blend_add")
	var s = Shader.new()
	s.code = src
	_sh[kind] = s
	return s


static func _mat(kind: String, p := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader(kind)
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


static func _orb(core: Color, body: Color, line: Color, rim: Color, o := {}, kind := "orb") -> ShaderMaterial:
	var p = {"core_col": core, "body_col": body, "line_col": line, "rim_col": rim}
	p.merge(o, true)
	return _mat(kind, p)


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Konturlu cel katı (malzemeler meta "mats": [gövde, kontur])
static func _solid(mesh: Mesh, fading := false, grow := 0.03, glow := 0.0, shade := 0.55) -> MeshInstance3D:
	var m = _mat("cel_a" if fading else "cel", {"glow": glow, "shade": shade})
	var ol = _mat("out_a" if fading else "out", {"grow": grow})
	m.next_pass = ol
	var mi = _mi(mesh, m)
	mi.set_meta("mats", [m, ol])
	return mi


## Malzemelerin "fade" değerini 1 → 0 indirir, sonra düğümü siler
static func _fade(n: Node, mats: Array, delay: float, dur: float, free := true) -> void:
	if n == null or not is_instance_valid(n):
		return
	var setf = func(v: float) -> void:
		for m in mats:
			if m:
				m.set_shader_parameter("fade", v)
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(setf, 1.0, 0.0, maxf(dur, 0.01))
	if free:
		tw.tween_callback(n.queue_free)


## Tek gölgelendirici değerini zamanla değiştir
static func _tp(n: Node, m: ShaderMaterial, key: String, a: float, b: float, dur: float, delay := 0.0) -> void:
	var f = func(v: float) -> void:
		m.set_shader_parameter(key, v)
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(f, a, b, dur)


static func _sphere(r: float, seg := 32) -> SphereMesh:
	var sm = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(4, seg / 2)
	return sm


static func _seg(a: Vector3, b: Vector3, n := 6) -> Array:
	var out = []
	for i in n:
		out.append(a.lerp(b, float(i) / float(n - 1)))
	return out


## Sol / sağ kenar noktalarından şerit mesh (UV.x boy, UV.y en)
static func _strip(L: Array, R: Array) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = L.size()
	for i in n - 1:
		var u0 = float(i) / float(n - 1)
		var u1 = float(i + 1) / float(n - 1)
		_sv(st, L[i], u0, 0.0)
		_sv(st, R[i], u0, 1.0)
		_sv(st, L[i + 1], u1, 0.0)
		_sv(st, R[i], u0, 1.0)
		_sv(st, R[i + 1], u1, 1.0)
		_sv(st, L[i + 1], u1, 0.0)
	return st.commit()


static func _sv(st: SurfaceTool, p: Vector3, u: float, v: float) -> void:
	st.set_uv(Vector2(u, v))
	st.set_normal(Vector3.UP)
	st.add_vertex(p)


static func _iv(im: ImmediateMesh, p: Vector3, u: float, v: float, c: Color) -> void:
	im.surface_set_color(c)
	im.surface_set_uv(Vector2(u, v))
	im.surface_add_vertex(p)


## Kırık çizgiyi kameraya dönük (ya da nrm verilmişse o düzleme yatık) şerit olarak yazar.
## tp: 0 düz, 1 iki uç incelir, 2 kuyruk ince → baş kalın, 3 baş kalın → kuyruk incelir
static func _emit(im: ImmediateMesh, pts: Array, w: float, a: float, cam: Vector3, tp: int, nrm: Vector3, col: Color) -> void:
	var n = pts.size()
	if n < 2:
		return
	var L = []
	var R = []
	for i in n:
		var p: Vector3 = pts[i]
		var tv: Vector3 = Vector3(pts[mini(i + 1, n - 1)]) - Vector3(pts[maxi(i - 1, 0)])
		var s: Vector3 = tv.cross(nrm) if nrm != Vector3.ZERO else tv.cross(cam - p)
		if s.length_squared() < 0.000001:
			s = Vector3.RIGHT
		s = s.normalized()
		var u = float(i) / float(n - 1)
		var k = 1.0
		if tp == 1:
			k = clampf(sin(PI * u) * 1.7, 0.0, 1.0)
		elif tp == 2:
			k = u
		elif tp == 3:
			k = 1.0 - u * 0.85
		L.append(p - s * w * k)
		R.append(p + s * w * k)
	var cc = Color(col.r, col.g, col.b, col.a * a)
	for i in n - 1:
		var u0 = float(i) / float(n - 1)
		var u1 = float(i + 1) / float(n - 1)
		_iv(im, L[i], u0, 0.0, cc)
		_iv(im, R[i], u0, 1.0, cc)
		_iv(im, L[i + 1], u1, 0.0, cc)
		_iv(im, R[i], u0, 1.0, cc)
		_iv(im, R[i + 1], u1, 1.0, cc)
		_iv(im, L[i + 1], u1, 0.0, cc)


## Canlı çizgiler: her kare fn(yaş) → [{"p": [noktalar], "w", "a", "tp", "n", "c"}]; null dönerse biter
static func _lines(fn: Callable, mat: Material, life: float, parent: Node = null) -> Tick:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16.0
	var upd = func(_n, _dt, age) -> bool:
		if age > life:
			return false
		im.clear_surfaces()
		var polys = fn.call(age)
		if not (polys is Array):
			return false
		var ok = false
		for pl in polys:
			if pl["p"].size() >= 2:
				ok = true
				break
		if ok:
			var cam = _cam()
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
			for pl in polys:
				_emit(im, pl["p"], float(pl.get("w", 0.05)), float(pl.get("a", 1.0)), cam, int(pl.get("tp", 1)), pl.get("n", Vector3.ZERO), pl.get("c", Color.WHITE))
			im.surface_end()
		return true
	var tk = _host(upd, Vector3.ZERO, parent)
	tk.add_child(mi)
	return tk


## Bir noktayı izleyen iz (son keep sn), rec sn kaydeder
static func _trail_fn(src: Callable, w: float, keep: float, rec: float, mat: Material, parent: Node = null) -> void:
	var hist = []
	var st = {"on": true}
	var fn = func(age):
		if age <= rec and st["on"]:
			var p: Vector3 = src.call()
			if p.is_finite():
				hist.append([p, age])
			else:
				st["on"] = false
		while hist.size() > 0 and age - float(hist[0][1]) > keep:
			hist.pop_front()
		if hist.is_empty() and (age > rec or not st["on"]):
			return null
		var pts = []
		for h in hist:
			pts.append(h[0])
		return [{"p": pts, "w": w, "a": 1.0, "tp": 2}]
	_lines(fn, mat, rec + keep + 0.1, parent)


## Çakra iplikleri: n iplik r0'dan merkeze sarmal çizerek dur sn içinde toplanır
static func _spiral_in(center: Callable, n: int, r0: float, dur: float, w: float, mat: Material, parent: Node = null) -> void:
	var seeds = []
	for i in n:
		seeds.append({"a": randf() * TAU, "e": randf_range(-0.9, 0.9), "d": randf_range(0.0, dur * 0.4), "s": randf_range(4.0, 7.0) * (1.0 if randf() < 0.8 else -1.0)})
	var fn = func(age):
		var c: Vector3 = center.call()
		if not c.is_finite():
			return null
		var out = []
		for sd in seeds:
			var span = maxf(0.05, dur - float(sd["d"]))
			var pts = []
			for j in 6:
				var tm = age - float(sd["d"]) - (5 - j) * 0.03
				if tm < 0.0:
					continue
				var k = clampf(tm / span, 0.0, 1.0)
				var rr = r0 * pow(1.0 - k, 1.4)
				var ang = float(sd["a"]) + float(sd["s"]) * k
				var e = float(sd["e"]) * (1.0 - k)
				pts.append(c + Vector3(cos(ang) * cos(e), sin(e), sin(ang) * cos(e)) * rr)
			out.append({"p": pts, "w": w, "a": 1.0, "tp": 2})
		return out
	_lines(fn, mat, dur + 0.05, parent)


## Eksene dik düzlemde r0 → r1 açılan çember çizgisi
static func _ring_line(at: Vector3, ax: Vector3, r0: float, r1: float, life: float, w: float, mat: Material, push := 0.0) -> void:
	var s1 = ax.cross(Vector3.UP)
	s1 = s1.normalized() if s1.length() > 0.01 else Vector3.RIGHT
	var s2 = ax.cross(s1).normalized()
	var fn = func(age):
		var k = clampf(age / life, 0.0, 1.0)
		var e = 1.0 - pow(1.0 - k, 2.0)
		var pts = []
		for i in 25:
			var a = TAU * i / 24.0
			pts.append(at + ax * push * e + (s1 * cos(a) + s2 * sin(a)) * lerpf(r0, r1, e))
		return [{"p": pts, "w": w * (1.0 - k * 0.7), "a": 1.0 - k, "tp": 0}]
	_lines(fn, mat, life)


## Parça yağmuru (tek MultiMesh): hız, yerçekimi, sürtünme, zeminde seker, dönerek küçülüp söner
static func _bits(at: Vector3, n: int, mesh: Mesh, mat: Material, vel: Callable, o := {}) -> void:
	var g = float(o.get("g", 14.0))
	var life = float(o.get("life", 1.0))
	var sz = float(o.get("size", 0.15))
	var spin = float(o.get("spin", 8.0))
	var drag = float(o.get("drag", 0.0))
	var floor_hit = bool(o.get("floor", true))
	var spread = float(o.get("r", 0.2))
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 20.0
	var gy = Game.jutsu_floor(at.x, at.z)
	var P = []
	var V = []
	var AX = []
	var AN = []
	var AV = []
	var S = []
	var LF = []
	for i in n:
		P.append(at + _rdir() * spread * randf())
		V.append(vel.call(i))
		AX.append(_rdir())
		AN.append(randf() * TAU)
		AV.append(randf_range(-spin, spin))
		S.append(sz * randf_range(0.6, 1.3))
		LF.append(life * randf_range(0.7, 1.0))
	var f = func(_n, dt, age) -> bool:
		if age > life:
			return false
		for i in n:
			var v: Vector3 = V[i]
			v.y -= g * dt
			v *= maxf(0.0, 1.0 - drag * dt)
			var p: Vector3 = Vector3(P[i]) + v * dt
			if floor_hit and p.y < gy + 0.02 and v.y < 0.0:
				p.y = gy + 0.02
				v = Vector3(v.x * 0.45, -v.y * 0.2, v.z * 0.45)
				AV[i] = float(AV[i]) * 0.5
			P[i] = p
			V[i] = v
			AN[i] = float(AN[i]) + float(AV[i]) * dt
			var k = age / float(LF[i])
			var s = float(S[i]) * (1.0 - smoothstep(0.65, 1.0, k))
			mm.set_instance_transform(i, Transform3D(Basis(AX[i], AN[i]).scaled(Vector3.ONE * maxf(s, 0.0001)), p))
		return true
	var tk = _host(f)
	tk.add_child(mmi)


## Rastgele yatay + dikey hız (isteğe bağlı yön eğilimi)
static func _vr(h0: float, h1: float, u0: float, u1: float, bias := Vector3.ZERO) -> Callable:
	return func(_i) -> Vector3:
		var a = randf() * TAU
		return Vector3(cos(a), 0.0, sin(a)) * randf_range(h0, h1) + Vector3.UP * randf_range(u0, u1) + bias * randf_range(0.5, 1.0)


## Zemin izi (sönerek kalır). o: ring_r, ring_w, jag, spokes, square, col2, disc_r, edge_soft, add, grow, yaw
static func _decal(at: Vector3, r: float, col: Color, life: float, o := {}) -> MeshInstance3D:
	var pm = PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0)
	var p = {"col": col, "seed": randf() * 10.0}
	for k in ["ring_r", "ring_w", "jag", "spokes", "square", "col2", "disc_r", "edge_soft"]:
		if o.has(k):
			p[k] = o[k]
	var m = _mat("disc_add" if o.get("add", false) else "disc", p)
	var mi = _mi(pm, m)
	_put(mi, at + Vector3.UP * (0.03 + randf() * 0.025))
	mi.rotation.y = float(o.get("yaw", randf() * TAU))
	var grow = float(o.get("grow", 0.0))
	if grow > 0.0:
		mi.scale = Vector3.ONE * 0.05
		mi.create_tween().tween_property(mi, "scale", Vector3.ONE, grow).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if life > 0.0:
		_fade(mi, [m], life * 0.55, life * 0.45)
	return mi


static func _light(at: Vector3, col: Color, e: float, rng: float, life: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = e
	l.omni_range = rng
	l.shadow_enabled = false
	_put(l, at)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)
	return l


## Düğümü kameraya çevir (-Z kameraya)
static func _bill(n: Node3D) -> void:
	var cp = _cam()
	var dv = cp - n.global_position
	if dv.length() < 0.05:
		return
	var up = Vector3.UP if absf(dv.normalized().y) < 0.97 else Vector3.FORWARD
	n.look_at(cp, up)


## Tırtıklı yıldız çokgeni (XY düzlemi); uçlar UV.y=0 → kenar rengi (cel kontur)
static func _star_mesh(n: int, r_in: float, r_out: float, jit: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts = []
	for i in n * 2:
		var a = TAU * i / float(n * 2) + randf_range(-jit, jit) * 0.3
		var r = r_out * randf_range(1.0 - jit, 1.0 + jit * 0.5) if i % 2 == 0 else r_in * randf_range(0.85, 1.1)
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for i in pts.size():
		var j = (i + 1) % pts.size()
		_sv(st, Vector3.ZERO, 0.5, 0.5)
		_sv(st, pts[i], 0.5, 0.0 if i % 2 == 0 else 0.3)
		_sv(st, pts[j], 0.5, 0.0 if j % 2 == 0 else 0.3)
	return st.commit()


static func _star_flash(at: Vector3, r: float, core: Color, edge: Color, life: float, pts := 14) -> void:
	var m = _mat("rib", {"core_col": core, "edge_col": edge, "edge_w": 0.3, "soft": 0.02})
	var mi = _mi(_star_mesh(pts, r * 0.62, r, 0.25), m)
	var f = func(n, _dt, age) -> bool:
		if age > life:
			return false
		_bill(n)
		var k = age / life
		n.scale = Vector3.ONE * (0.3 + 0.7 * minf(1.0, k * 6.0)) * (1.0 + 0.15 * sin(age * 60.0))
		m.set_shader_parameter("fade", 1.0 - smoothstep(0.6, 1.0, k))
		return true
	var tk = _host(f, at)
	tk.add_child(mi)


# ═════════════════════════════════════════ küçük mesh'ler ═════════════════════════════════════════

static func _rock_mesh() -> Mesh:
	if not _mesh.has("rock"):
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3.ONE, Color.WHITE, Vector3.ZERO, 3)
		_mesh["rock"] = b.build(null)
	return _mesh["rock"]


static func _rock_mat(col := EARTH) -> ShaderMaterial:
	return _mat("cel", {"tint": col, "shade": 0.55})


static func _mote_mesh() -> Mesh:
	if not _mesh.has("mote"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		_mesh["mote"] = sm
	return _mesh["mote"]


## Yaprak: ince eşkenar dörtgen, orta damar boyunca UV (kenarı koyu yeşil kontur)
static func _leaf_mesh() -> Mesh:
	if not _mesh.has("leaf"):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tip = Vector3(0, 0, -0.5)
		var base = Vector3(0, 0, 0.5)
		var l = Vector3(-0.2, 0.03, 0.05)
		var r = Vector3(0.2, 0.03, 0.05)
		_sv(st, base, 0.05, 0.5)
		_sv(st, l, 0.5, 0.0)
		_sv(st, tip, 1.0, 0.5)
		_sv(st, base, 0.05, 0.5)
		_sv(st, tip, 1.0, 0.5)
		_sv(st, r, 0.5, 1.0)
		_mesh["leaf"] = st.commit()
	return _mesh["leaf"]


static func _leaf_mat() -> ShaderMaterial:
	return _mat("rib", {"core_col": LEAF, "edge_col": LEAF_DARK, "edge_w": 0.35, "soft": 0.03, "near_a": 0.5, "near_b": 1.5})


## Kunai (ileri = -Z): elmas kesitli ağız, sargılı sap, halka
static func _kunai_mesh() -> Mesh:
	if not _mesh.has("kunai"):
		var b = MB.new()
		b.add("cone", Vector3(0, 0, -0.17), Vector3(0.07, 0.22, 0.018), Color(0.66, 0.68, 0.72), Vector3(-90, 0, 0), 4)
		b.add("cyl", Vector3(0, 0, 0.0), Vector3(0.03, 0.12, 0.03), Color(0.16, 0.14, 0.14), Vector3(90, 0, 0), 6)
		b.add("torus", Vector3(0, 0, 0.1), Vector3(0.08, 0.08, 0.08), Color(0.55, 0.56, 0.6), Vector3(0, 0, 90), 10)
		_mesh["kunai"] = b.build(null)
	return _mesh["kunai"]


## Kâğıt tılsım (XY düzlemi, iki yüzü yazılı): "seal" kahve çerçeve + mürekkep yazı, "bomb" kırmızı yazılı patlayıcı etiket
static func _tag_mesh(kind: String) -> Mesh:
	var key = "tag_" + kind
	if _mesh.has(key):
		return _mesh[key]
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(0.2, 0.5, 0.008), PAPER)
	var frame = Color(0.4, 0.2, 0.12) if kind == "seal" else TAG_RED
	var ink = INK if kind == "seal" else TAG_RED
	for zf in [-1.0, 1.0]:
		var z = zf * 0.0055
		b.add("box", Vector3(0, 0.232, z), Vector3(0.2, 0.024, 0.002), frame)
		b.add("box", Vector3(0, -0.232, z), Vector3(0.2, 0.024, 0.002), frame)
		b.add("box", Vector3(0.09, 0, z), Vector3(0.016, 0.5, 0.002), frame)
		b.add("box", Vector3(-0.09, 0, z), Vector3(0.016, 0.5, 0.002), frame)
		b.add("box", Vector3(0, 0.02, z), Vector3(0.018, 0.3, 0.002), ink)
		for yy in [0.14, 0.07, -0.02]:
			b.add("box", Vector3(0, yy, z), Vector3(0.1, 0.014, 0.002), ink)
		b.add("box", Vector3(0.03, -0.1, z), Vector3(0.014, 0.1, 0.002), ink, Vector3(0, 0, 35))
		b.add("box", Vector3(-0.03, -0.1, z), Vector3(0.014, 0.1, 0.002), ink, Vector3(0, 0, -35))
		if kind == "bomb":
			b.add("box", Vector3(0, -0.17, z), Vector3(0.12, 0.03, 0.002), INK)
	var m = b.build(null)
	_mesh[key] = m
	return m

# ═════════════════════════════════════════ Rasengan / Ōdama Rasengan ═════════════════════════════════════════

## Rasengan küresi (diam = çap): yoğun mavi gövde + beyaz göbek + sarmal çizgiler, dışta iki eksende dönen yarı saydam çizgi
## kabuğu, çevresinde ışınsal ince hale (referans: avuçtaki top ve dış halka), mavi ışık
static func _ras_ball(diam: float, heavy := false) -> Node3D:
	var r = diam * 0.5
	var root = Node3D.new()
	var m_in = _orb(RAS_CORE, Color(RAS_BODY, 0.9), RAS_LINE, Color(RAS_RIM, 0.95),
		{"arms": 7.0 if heavy else 5.0, "twist": 3.0, "spin": 1.1 if heavy else 1.8, "lw": 0.22, "core_size": 0.5, "rim_w": 0.1})
	var inner = _mi(_sphere(r, 32), m_in)
	root.add_child(inner)
	var m_sh = _orb(Color(1, 1, 1, 0), Color(RAS_BODY, 0.12), Color(0.92, 0.98, 1.0, 0.85), Color(0.7, 0.88, 1.0, 0.35),
		{"arms": 9.0 if heavy else 6.0, "twist": -2.2, "spin": -2.6, "lw": 0.13, "core_size": 0.0, "rim_w": 0.25})
	var shell = _mi(_sphere(r * 1.14, 28), m_sh)
	root.add_child(shell)
	var q = QuadMesh.new()
	q.size = Vector2(diam * 2.3, diam * 2.3)
	var m_h = _mat("halo", {"col": Color(0.62, 0.86, 1.0, 0.85), "r0": 0.46, "r1": 0.97, "rays": 64.0 if heavy else 44.0, "spin": 1.0})
	root.add_child(_mi(q, m_h))
	var l = OmniLight3D.new()
	l.light_color = RAS_BODY
	l.light_energy = 1.6 if heavy else 1.0
	l.omni_range = maxf(3.0, diam * 5.0)
	l.shadow_enabled = false
	root.add_child(l)
	root.set_meta("mats", [m_in, m_sh, m_h])
	var spin = func(_n, dt, _a) -> bool:
		if not is_instance_valid(shell) or not is_instance_valid(inner):
			return false
		shell.rotate_x(dt * 3.1)
		shell.rotate_z(dt * 2.3)
		inner.rotate_y(dt * 1.7)
		return true
	_host(spin, Vector3.ZERO, root)
	return root


## Hücum izi: elin arkasında iki kollu sarmal (çift helis) çakra şeridi, geride kalan halka açılır
static func _ras_trail(hand: Node3D, heavy: bool) -> void:
	var f = _follow(hand)
	var rr = 0.55 if heavy else 0.16
	var hist = []
	var mat = _mat("rib_add", {"core_col": Color(0.9, 0.97, 1.0, 0.9), "edge_col": Color(0.3, 0.6, 1.0, 0.7), "edge_w": 0.5, "near_a": 1.2, "near_b": 3.5})
	var fn = func(age):
		var p: Vector3 = f.call()
		if p.is_finite() and age < 0.7:
			hist.append({"p": p, "t": age})
		while hist.size() > 0 and age - float(hist[0]["t"]) > 0.28:
			hist.pop_front()
		if hist.is_empty() and age > 0.1:
			return null
		var out = []
		for arm in 2:
			var pts = []
			for i in hist.size():
				var h = hist[i]
				var fw: Vector3 = Vector3(hist[mini(i + 1, hist.size() - 1)]["p"]) - Vector3(hist[maxi(i - 1, 0)]["p"])
				if fw.length() < 0.001:
					fw = Vector3.FORWARD
				fw = fw.normalized()
				var s1 = fw.cross(Vector3.UP)
				s1 = s1.normalized() if s1.length() > 0.01 else Vector3.RIGHT
				var s2 = fw.cross(s1).normalized()
				var ang = float(h["t"]) * 26.0 + arm * PI
				var grow = 1.0 + (age - float(h["t"])) * 4.0
				pts.append(Vector3(h["p"]) + (s1 * cos(ang) + s2 * sin(ang)) * rr * grow)
			out.append({"p": pts, "w": 0.06 if heavy else 0.025, "a": 0.9, "tp": 2})
		return out
	_lines(fn, mat, 1.2)


## Ōdama: dev kürenin rüzgârı yolda toprağı kazır (toprak sıçrar, iz noktaları kaydedilir)
static func _odama_drag(hand: Node3D, state: Dictionary) -> void:
	var g = _g(hand.global_position)
	var fur: Array = state["fur"]
	if fur.is_empty() or Vector3(fur[fur.size() - 1]).distance_to(g) > 0.35:
		fur.append(g)
		_bits(g + Vector3.UP * 0.1, 3, _rock_mesh(), _rock_mat(EARTH), _vr(1.0, 3.0, 2.5, 5.0), {"g": 18.0, "life": 0.8, "size": 0.14})


## Hücum yolunda kalan kazınmış toprak şeridi
static func _odama_furrow(fur: Array) -> void:
	if fur.size() < 2:
		return
	var o: Vector3 = fur[0]
	var L = []
	var R = []
	for i in fur.size():
		var p: Vector3 = fur[i]
		var dv: Vector3 = Vector3(fur[mini(i + 1, fur.size() - 1)]) - Vector3(fur[maxi(i - 1, 0)])
		dv.y = 0.0
		var sd = dv.cross(Vector3.UP).normalized() if dv.length() > 0.01 else Vector3.RIGHT
		var w = 0.75 * (0.4 + 0.6 * float(i) / float(fur.size() - 1))
		L.append(p - o - sd * w + Vector3.UP * 0.04)
		R.append(p - o + sd * w + Vector3.UP * 0.04)
	var m = _mat("rib", {"core_col": Color(0.22, 0.16, 0.12, 0.8), "edge_col": Color(0.4, 0.31, 0.22, 0.55), "edge_w": 0.35, "soft": 0.3})
	var mi = _mi(_strip(L, R), m)
	_put(mi, o)
	_fade(mi, [m], 3.5, 2.0)


## İsabet — öğüten matkap: küre hedefte şişip ileri burgu yapar, eksen çevresinde dışa açılan sarmal rüzgâr çizgileri,
## zeminde öğütülmüş oyuk + kırık çizgiler, fırlayan kaya parçaları, basınç halkası, mavi ışık
static func _ras_grind(pj: PathJutsu, pt: Vector3, d: Vector3, heavy: bool) -> void:
	var diam = 2.4 if heavy else 1.0
	var sp = _ras_ball(diam, heavy)
	_put(sp, pt)
	var big = 2.2 if heavy else 3.0
	var tw = sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE * big, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sp, "global_position", pt + d * (1.6 if heavy else 0.8), 0.3)
	tw.tween_property(sp, "scale", Vector3.ONE * 0.05, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(sp.queue_free)
	var R = diam * 0.5 * big
	var s1 = d.cross(Vector3.UP)
	s1 = s1.normalized() if s1.length() > 0.01 else Vector3.RIGHT
	var s2 = d.cross(s1).normalized()
	var arms = 10 if heavy else 7
	var mat = _mat("rib_add", {"core_col": Color(0.95, 0.99, 1.0, 1.0), "edge_col": Color(0.35, 0.65, 1.0, 0.8), "edge_w": 0.5})
	var fn = func(age):
		var k = age / 0.55
		var out = []
		for a in arms:
			var pts = []
			for j in 10:
				var u = float(j) / 9.0
				var ang = TAU * a / arms + u * 2.4 + age * 14.0
				var rad = R * (0.5 + u * 0.9) * (0.4 + k)
				pts.append(pt + d * (u * 1.2 - 0.3) * R * 0.6 + (s1 * cos(ang) + s2 * sin(ang)) * rad)
			out.append({"p": pts, "w": 0.1 if heavy else 0.05, "a": maxf(0.0, 1.0 - k), "tp": 1})
		return out
	_lines(fn, mat, 0.55)
	var g = _g(pt)
	_decal(g, 2.4 if heavy else 1.5, Color(0.16, 0.12, 0.1, 0.78), 6.0, {"spokes": 9.0, "disc_r": 0.45, "jag": 0.25, "col2": Color(0.3, 0.24, 0.2, 0.6)})
	_decal(g, 4.0 if heavy else 2.6, Color(0.55, 0.8, 1.0, 0.8), 0.45, {"ring_r": 0.8, "ring_w": 0.12, "add": true, "grow": 0.3})
	_bits(g + Vector3.UP * 0.3, 14 if heavy else 9, _rock_mesh(), _rock_mat(EARTH), _vr(2.0, 5.0, 4.0, 9.0, d * 5.0), {"g": 22.0, "life": 1.4, "size": 0.22 if heavy else 0.16, "r": 0.5})
	_light(pt, RAS_BODY, 10.0, 16.0, 0.45)
	pj.shake(1.0)


## Elde hücum (Jutsu._hand_dash'in oynanışı birebir: hazırlık, koşu, her kare hedefe yön, 1 m küre isabeti, 0.6 sn sınır).
## Görsel: çift helis iz; Ōdama'da yerde kazıma izi; isabette öğüten matkap
static func _palm_dash(pj: PathJutsu, c: Node3D, t: Node3D, hand: Node3D, charge: float, speed: float, info: Dictionary, run: bool, heavy: bool) -> void:
	var tw = pj.create_tween()
	tw.tween_interval(charge)
	var state = {"t": 0.0, "done": false, "fur": []}
	var start = func():
		if not is_instance_valid(c):
			return
		var timer = Timer.new()
		timer.wait_time = 1.0 / 60.0
		c.add_child(timer)
		var tickf = func():
			state["t"] += 1.0 / 60.0
			if state["done"] or not is_instance_valid(c):
				timer.queue_free()
				return
			var d: Vector3
			if c is Player:
				d = Jutsu._aim_flat(c, t)
				c.facing = atan2(-d.x, -d.z)
			elif t and is_instance_valid(t) and not t.is_dead():
				d = (t.global_position - c.global_position)
				d.y = 0
				d = d.normalized()
			else:
				d = c.face_dir()
			c.velocity = d * speed
			if c is Player:
				c.combat.action = "cast"
				c.combat.t = -10.0
			if run and c.get("model"):
				state["ran"] = true
				c.model.play("run", 0.08, 1.9)
			if not state.has("trail") and is_instance_valid(hand):
				state["trail"] = true
				_ras_trail(hand, heavy)
			if heavy and is_instance_valid(hand):
				_odama_drag(hand, state)
			var pt = c.global_position + Vector3.UP * 1.1 + d * 1.0
			var hits = Combat.hit_sphere(c, pt, 1.0, info)
			if not hits.is_empty() or state["t"] > 0.6:
				state["done"] = true
				Jutsu._palm_release(c)
				if run and is_instance_valid(c) and c.get("model") and c.model.get("overlay"):
					c.model.overlay.set_pose("cast", 0.0)
				if c is Player:
					c.combat.action = ""
				c.velocity = Vector3.ZERO
				if heavy:
					_odama_furrow(state["fur"])
				if not hits.is_empty():
					_ras_grind(pj, pt, d, heavy)
					Sfx.play("boom", pt, 1.2)
				if is_instance_valid(hand):
					var tw2 = hand.create_tween()
					tw2.tween_property(hand, "scale", Vector3.ONE * 0.01, 0.2)
					tw2.tween_callback(hand.queue_free)
				timer.queue_free()
		timer.timeout.connect(tickf)
		timer.start()
	tw.tween_callback(start)


## Rasengan: avuçta büyüyen mavi-beyaz sarmal küre; hazırlıkta çakra iplikleri avuca sarmal çizerek toplanır,
## hedefe koşarak gidilir, isabette küre burgu gibi öğütür
static func rasengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var m = Jutsu._mult(c)
	var hand: Node3D = Node3D.new()
	Jutsu._palm(c, hand)
	var ras = _ras_ball(0.34)
	hand.add_child(ras)
	ras.scale = Vector3.ONE * 0.1
	ras.create_tween().tween_property(ras, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spiral_in(_follow(hand), 9, 1.2, 0.55, 0.02, _mat("rib_add", {"core_col": Color(0.88, 0.96, 1.0, 0.95), "edge_col": Color(0.35, 0.65, 1.0, 0.6), "edge_w": 0.5}), hand)
	Sfx.play("rasengan", c.global_position)
	# anime: Rasengan elde, hedefe KOŞARAK gidilir (kayarak değil) ve avuçla vurup öğütür
	_palm_dash(pj, c, t, hand, 0.6, 22.0, {"dmg": 42.0 * m, "knock": 32.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.16}, true, false)


## Ōdama Rasengan (Jutsu.j_odama_rasengan oynanışı): önde dev küre, daha çok çizgi + yavaş ağır dönüş; geniş çakra
## iplikleri toplanır, ayak dibinde basınç halkası ve küreye emilen toprak; hücumda yer kazınır
static func odama_core(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var m = Jutsu._mult(c)
	var hand: Node3D = Node3D.new()
	c.model.add_child(hand)
	hand.position = Vector3(0.35, 1.9, -1.2)
	var ras = _ras_ball(2.4, true)
	hand.add_child(ras)
	ras.scale = Vector3.ONE * 0.1
	ras.create_tween().tween_property(ras, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spiral_in(_follow(hand), 16, 3.2, 0.7, 0.05, _mat("rib_add", {"core_col": Color(0.88, 0.96, 1.0, 0.9), "edge_col": Color(0.35, 0.65, 1.0, 0.5), "edge_w": 0.5}), hand)
	var g = _g(c.global_position)
	_decal(g, 3.0, Color(0.55, 0.8, 1.0, 0.7), 1.0, {"ring_r": 0.75, "ring_w": 0.06, "add": true, "grow": 0.6})
	_bits(g + Vector3.UP * 0.1, 10, _rock_mesh(), _rock_mat(EARTH), _vr(0.2, 0.8, 3.0, 5.0), {"g": 2.0, "life": 0.7, "size": 0.1, "r": 1.2})
	Sfx.play("rasengan", c.global_position, 0.7)
	_palm_dash(pj, c, t, hand, 0.75, 24.0, {"dmg": 60.0 * m, "knock": 44.0, "launch": 12.0, "kind": "heavy", "hitstop": 0.2}, false, true)


## Büyük Top Rasengan (p_): çekirdek + varışta krater, basınç halkası ve dışa savrulan toz/toprak
static func odama_rasengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	odama_core(pj, c, t)
	var later = func():
		if pj.live(c):
			var g = pj.gp(c.global_position + c.face_dir() * 1.5)
			_decal(g, 3.5, Color(0.15, 0.12, 0.1, 0.8), 7.0, {"spokes": 12.0, "disc_r": 0.5, "jag": 0.3, "col2": Color(0.32, 0.26, 0.2, 0.7)})
			_decal(pj.gp(c.global_position), 12.0, Color(0.6, 0.85, 1.0, 0.7), 0.5, {"ring_r": 0.85, "ring_w": 0.05, "add": true, "grow": 0.5})
			_bits(g + Vector3.UP * 0.2, 18, _rock_mesh(), _rock_mat(Color(0.58, 0.5, 0.4)), _vr(4.0, 8.0, 0.5, 2.0), {"g": 6.0, "drag": 2.0, "life": 1.6, "size": 0.2, "r": 1.5})
	pj.after(0.8, later)


# ═════════════════════════════════════════ Kongō Rōheki ═════════════════════════════════════════

## Enma'nın kafesi (referans): siyah dikey parmaklıklar + kütük ev gibi kat kat çaprazlanan siyah yatay kütükler; köşeden
## taşan kütük uçları ve ayaklar parlak altın; tavanda üç kütük
static func _enma_cage() -> Mesh:
	if _mesh.has("enma"):
		return _mesh["enma"]
	var b = MB.new()
	var H = 4.0
	var W = 1.8
	for side in 4:
		for j in 4:
			var o = -1.35 + 0.9 * j
			var p: Vector3
			if side == 0:
				p = Vector3(o, 0, W)
			elif side == 1:
				p = Vector3(o, 0, -W)
			elif side == 2:
				p = Vector3(W, 0, o)
			else:
				p = Vector3(-W, 0, o)
			b.add("cyl", p + Vector3.UP * (H * 0.5 + 0.2), Vector3(0.22, H - 0.4, 0.22), ENMA_BLACK, Vector3.ZERO, 10)
			b.add("cyl", p + Vector3.UP * 0.2, Vector3(0.27, 0.4, 0.27), ENMA_GOLD, Vector3.ZERO, 10)
	var lv = 0
	for y in [0.7, 1.1, 1.5, 1.9, 2.3, 2.7, 3.1, 3.5, 3.9]:
		var along_x = lv % 2 == 0
		lv += 1
		for sgn in [-1.0, 1.0]:
			var off = W + 0.16
			var ctr = Vector3(0, y, sgn * off) if along_x else Vector3(sgn * off, y, 0)
			var rot = Vector3(0, 0, 90) if along_x else Vector3(90, 0, 0)
			var ax = Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
			b.add("cyl", ctr, Vector3(0.24, 2.0 * W + 0.1, 0.24), ENMA_BLACK, rot, 10)
			for e in [-1.0, 1.0]:
				b.add("cyl", ctr + ax * e * (W + 0.32), Vector3(0.3, 0.44, 0.3), ENMA_GOLD, rot, 10)
	for zz in [-0.9, 0.0, 0.9]:
		b.add("cyl", Vector3(0, H + 0.12, zz), Vector3(0.24, 2.0 * W + 0.1, 0.24), ENMA_BLACK, Vector3(0, 0, 90), 10)
		for e in [-1.0, 1.0]:
			b.add("cyl", Vector3(e * (W + 0.32), H + 0.12, zz), Vector3(0.3, 0.44, 0.3), ENMA_GOLD, Vector3(0, 0, 90), 10)
	var mesh = b.build(null)
	_mesh["enma"] = mesh
	return mesh


## Kafes yere oturur: kırık zemin, altın tozlu basınç halkası, fırlayan taşlar, altın kıvılcım, kısa ışık
static func _cage_slam(at: Vector3) -> void:
	_decal(at, 3.6, Color(0.2, 0.16, 0.12, 0.72), 6.0, {"spokes": 8.0, "disc_r": 0.35, "jag": 0.2})
	_decal(at, 6.0, Color(1.0, 0.82, 0.35, 0.8), 0.4, {"ring_r": 0.8, "ring_w": 0.08, "add": true, "grow": 0.35})
	_bits(at + Vector3.UP * 0.2, 14, _rock_mesh(), _rock_mat(EARTH), _vr(4.0, 8.0, 3.0, 7.0), {"g": 20.0, "life": 1.2, "size": 0.18, "r": 1.8})
	_bits(at + Vector3.UP * 0.4, 16, _mote_mesh(), _mat("cel", {"tint": ENMA_GOLD, "glow": 1.5}), _vr(3.0, 6.0, 2.0, 5.0), {"g": 9.0, "life": 0.6, "size": 0.07, "r": 1.8})
	_light(at + Vector3.UP, ENMA_GOLD, 4.0, 9.0, 0.35)


## Elmas Hapis Duvarı: hedefin altında altın kare işaret parlar, siyah-altın kafes gökten hız çizgileriyle iner, çarpar,
## hafifçe esneyip oturur; 5 sn sonra küçülerek kaybolur (bağlama 5.5 sn)
static func kongo_roheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	_decal(at, 2.6, Color(1.0, 0.8, 0.25, 0.9), 0.5, {"square": 1.0, "ring_r": 0.82, "ring_w": 0.06, "jag": 0.0, "add": true, "yaw": 0.0})
	var root = _solid(_enma_cage(), false, 0.035, 0.08, 0.5)
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_put(root, at + Vector3.UP * 10.0)
	var fr = _follow(root)
	var lm = _mat("rib_add", {"core_col": Color(1, 0.95, 0.8, 0.9), "edge_col": Color(1, 0.75, 0.2, 0.5), "edge_w": 0.5})
	var fall = func(age):
		var p: Vector3 = fr.call()
		if not p.is_finite() or age > 0.3:
			return null
		var out = []
		for k in 8:
			var a = TAU * k / 8.0
			var o = Vector3(cos(a) * 2.1, 0, sin(a) * 2.1)
			out.append({"p": _seg(p + o + Vector3.UP * 4.0, p + o + Vector3.UP * (7.0 + k % 3), 5), "w": 0.04, "a": 0.8, "tp": 1})
		return out
	_lines(fall, lm, 0.32)
	var slam = func():
		_cage_slam(at)
		pj.shake(0.6)
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", at, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(slam)
	tw.tween_property(root, "scale", Vector3(1.04, 0.94, 1.04), 0.06)
	tw.tween_property(root, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(4.82)
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.4)
	tw.tween_callback(root.queue_free)
	pj.st(tt, "bind", 5.5)
	Sfx.play("clink", at, 0.6)


# ═════════════════════════════════════════ Kekkai Hōjin ═════════════════════════════════════════

## Bariyer Formasyonu (referans: dört köşe tılsımı, aralarında turuncu kare saha; içerideki "yanar"):
## tılsımlar elden köşelere uçup dikilir, taban kare alan + kenar mühür çizgisi açılır; köşelerden ince ışık direkleri ve
## kenar boyunca yükselen seyrek çizgiler (duvar kabuğu yok); yakalanan hedefte sarı tırtıklı yıldız çakar
static func kekkai_hojin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 20.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 7.0)
	var root = Node3D.new()
	_put(root, at)
	var floor_root = Node3D.new()
	root.add_child(floor_root)
	floor_root.position = Vector3.UP * 0.04
	var specs = [
		[7.0, "disc", {"col": Color(SEAL_ORANGE, 0.4), "square": 1.0, "jag": 0.0, "disc_r": 0.97, "edge_soft": 0.03}],
		[7.3, "disc_add", {"col": Color(1.0, 0.72, 0.32, 0.95), "square": 1.0, "jag": 0.0, "ring_r": 0.95, "ring_w": 0.02}],
		[7.0, "disc", {"col": Color(0.45, 0.2, 0.08, 0.55), "square": 1.0, "jag": 0.0, "ring_r": 0.72, "ring_w": 0.012}]]
	var li = 0
	for spec in specs:
		var pm = PlaneMesh.new()
		pm.size = Vector2(spec[0], spec[0])
		var fm = _mi(pm, _mat(spec[1], spec[2]))
		floor_root.add_child(fm)
		li += 1
		fm.position.y = li * 0.008
	floor_root.scale = Vector3(0.02, 1, 0.02)
	var tw = floor_root.create_tween()
	tw.tween_property(floor_root, "scale", Vector3.ONE, 0.4)
	tw.tween_interval(7.0)
	tw.tween_property(floor_root, "scale", Vector3(0.02, 1, 0.02), 0.4)
	tw.tween_callback(root.queue_free)
	var hp = pj.hand_pos(c, true)
	var corners = []
	for k in 4:
		var q = Vector3((1 if k % 2 == 0 else -1) * 3.5, 0, (1 if k < 2 else -1) * 3.5)
		corners.append(q)
		var tag = _solid(_tag_mesh("seal"), false, 0.01, 0.1, 0.7)
		root.add_child(tag)
		tag.global_position = hp
		tag.rotation = Vector3(0, randf() * TAU, randf_range(-1.0, 1.0))
		var dt_ = 0.25 + k * 0.04
		var ttw = tag.create_tween()
		ttw.tween_property(tag, "position", q + Vector3.UP * 0.32, dt_).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ttw.parallel().tween_property(tag, "rotation", Vector3(-0.25, atan2(q.x, q.z), 0.0), dt_)
	var pm2 = _mat("rib_add", {"core_col": Color(1.0, 0.92, 0.7, 0.9), "edge_col": Color(1.0, 0.55, 0.15, 0.5), "edge_w": 0.5})
	var wall = func(age):
		if age < 0.32:
			return []
		var fa = clampf((7.8 - age) / 0.4, 0.0, 1.0) * clampf((age - 0.32) / 0.2, 0.0, 1.0)
		var out = []
		for q in corners:
			var b0 = at + Vector3(q)
			out.append({"p": _seg(b0 + Vector3.UP * 0.5, b0 + Vector3.UP * 5.0, 6), "w": 0.035, "a": fa * (0.75 + 0.25 * sin(age * 9.0 + q.x)), "tp": 1})
		for s in 28:
			var side = s % 4
			var u = (floorf(s / 4.0) + 0.5) / 7.0
			var e = lerpf(-3.5, 3.5, u)
			var base: Vector3
			if side == 0:
				base = at + Vector3(e, 0, 3.5)
			elif side == 1:
				base = at + Vector3(e, 0, -3.5)
			elif side == 2:
				base = at + Vector3(3.5, 0, e)
			else:
				base = at + Vector3(-3.5, 0, e)
			var h = fmod(age * 1.4 + s * 0.37, 1.0) * 4.6
			out.append({"p": _seg(base + Vector3.UP * h, base + Vector3.UP * (h + 0.55), 4), "w": 0.02, "a": fa * 0.5 * sin(PI * h / 4.6 + 0.01), "tp": 1})
		return out
	_lines(wall, pm2, 7.8, root)
	for e in pj.enemies_near(c, at, 4.5):
		if not pj.live(e):
			continue
		pj.st(e, "bind", 7.0)
		var eh = _height(e)
		_star_flash(e.global_position + Vector3.UP * eh * 0.55, eh * 0.75, Color(1.0, 0.92, 0.45), Color(0.95, 0.6, 0.15), 0.35, 16)
	Sfx.play("seal", at, 0.8)


# ═════════════════════════════════════════ Baryon Modo ═════════════════════════════════════════

## Alev yaprağı (yerel +Y boyunca uzar, XY düzleminde; bend yerel eğrilik): tabanı ince, ortası dolgun, ucu sivri
static func _petal(len: float, wid: float, bend: Vector3) -> ArrayMesh:
	var L = []
	var R = []
	var n = 12
	for i in n:
		var u = float(i) / float(n - 1)
		var p = Vector3(0, u * len, 0) + bend * u * u * len
		var tv = Vector3(0, len, 0) + bend * 2.0 * u * len
		var sd = tv.cross(Vector3(0, 0, 1)).normalized()
		var w = wid * pow(maxf(0.0, sin(PI * pow(u, 0.65))), 0.8)
		L.append(p - sd * w)
		R.append(p + sd * w)
	return _strip(L, R)


## Kızıl alev dili + içinde parlak öz (referans: Baryon pelerininin soluk parlayan kenarlı kızıl kuyrukları).
## dir / bend model uzayında; dönüş: malzemeler
static func _flame_petal(parent: Node3D, pos: Vector3, dir: Vector3, len: float, wid: float, bend: Vector3) -> Array:
	var y = dir.normalized()
	var x = y.cross(Vector3(0, 0, 1))
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var z = x.cross(y).normalized()
	var b = Basis(x, y, z)
	var bl = b.inverse() * bend
	bl.z = 0.0
	var ph = randf() * TAU
	var mo = _mat("rib", {"core_col": Color(BARYON_RED, 0.86), "edge_col": Color(BARYON_EDGE, 0.95), "edge_w": 0.22, "soft": 0.22, "tip_fade": 0.25,
		"sway_dir": Vector3(0.07, 0.0, 0.06), "sway_f": 4.0, "phase": ph, "near_a": 0.6, "near_b": 2.2})
	var outer = _mi(_petal(len, wid, bl), mo)
	outer.transform = Transform3D(b, pos)
	parent.add_child(outer)
	var mc = _mat("rib_add", {"core_col": Color(1.0, 0.85, 0.6, 0.55), "edge_col": Color(1.0, 0.5, 0.3, 0.0), "edge_w": 0.6, "soft": 0.5, "tip_fade": 0.6,
		"sway_dir": Vector3(0.07, 0.0, 0.06), "sway_f": 4.0, "phase": ph, "near_a": 0.6, "near_b": 2.2})
	var core = _mi(_petal(len * 0.85, wid * 0.35, bl * 0.85), mc)
	core.transform = Transform3D(b, pos + z * 0.01)
	parent.add_child(core)
	return [mo, mc]


## Yükselen kor parçacıkları (kendi ayarlı CPU parçacık)
static func _embers(parent: Node3D, col: Color) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 1.6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q = QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var sm = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	q.material = sm
	p.mesh = q
	var gr = Gradient.new()
	gr.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	gr.set_color(1, Color(col, 0.0))
	p.color_ramp = gr
	p.local_coords = false
	parent.add_child(p)
	p.emitting = true
	return p


## Ömür yakma: hedeften kısa bir kızıl alev dili yükselip söner
static func _life_burn(e: Node3D) -> void:
	var eh = _height(e)
	var root = Node3D.new()
	_put(root, e.global_position + Vector3.UP * eh * 0.5)
	var ms = _flame_petal(root, Vector3.ZERO, Vector3.UP, 0.7 * eh / 1.8, 0.1, Vector3(randf_range(-0.2, 0.2), 0, 0))
	root.create_tween().tween_property(root, "position", root.position + Vector3.UP * 0.7, 0.45)
	_fade(root, ms, 0.1, 0.35)


## Baryon Modu: doğuşta kızıl basınç halkası + çatlak; sırttan sekiz kızıl alev kuyruğu (yukarı / yana / aşağı savrulan,
## soluk kenarlı, parlak özlü, salınan), başta iki küçük alev kulağı, yükselen korlar; 12 sn, her 0.5 sn yakındaki
## düşmanların ömrü yanar (alev dili yükselir)
static func barion_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.8)
	var g = pj.gp(c.global_position)
	_decal(g, 10.0, Color(1.0, 0.45, 0.35, 0.85), 0.5, {"ring_r": 0.85, "ring_w": 0.05, "add": true, "grow": 0.5})
	_decal(g, 3.0, Color(0.18, 0.1, 0.08, 0.7), 6.0, {"spokes": 10.0, "disc_r": 0.3, "jag": 0.3})
	_light(c.global_position + Vector3.UP, BARYON_RED, 8.0, 12.0, 0.6)
	var parts = []
	var hb = pj.bone_attach(c, "Head")
	if hb:
		for sx in [-1.0, 1.0]:
			_flame_petal(hb, Vector3(sx * 0.14, 0.3, 0.0), Vector3(sx * 0.3, 1.0, 0.05), 0.45, 0.09, Vector3(sx * 0.15, 0, 0))
		parts.append(hb)
	var host: Node3D = c.model if c.get("model") else c
	var cloak = Node3D.new()
	host.add_child(cloak)
	cloak.position = Vector3(0, 1.25, 0.15)
	var specs = [
		[Vector3(0.3, 1.0, 0.35), 1.9, 0.3, Vector3(0.5, 0, 0.1)],
		[Vector3(0.8, 0.75, 0.4), 1.7, 0.28, Vector3(0.3, 0.45, 0)],
		[Vector3(0.9, -0.3, 0.35), 1.6, 0.26, Vector3(0.15, -0.5, 0)],
		[Vector3(0.45, -0.9, 0.3), 1.45, 0.22, Vector3(0.3, -0.15, 0.1)]]
	for sx in [-1.0, 1.0]:
		for sp in specs:
			var dv: Vector3 = sp[0]
			var bv: Vector3 = sp[3]
			_flame_petal(cloak, Vector3(sx * 0.12, 0.0, 0.0), Vector3(dv.x * sx, dv.y, dv.z), sp[1], sp[2], Vector3(bv.x * sx, bv.y, bv.z))
	cloak.scale = Vector3.ONE * 0.1
	cloak.create_tween().tween_property(cloak, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	parts.append(cloak)
	parts.append(_embers(cloak, BARYON_RED))
	if c is Player:
		Buffs.add("barion", 12.0, {"melee": 1.6, "speed": 1.2, "armor": 0.8, "_name": "Baryon Modu", "_desc": "yaşam gücü yanıyor: vuruşlar hedefin ömrünü yakar; can erir"})
	var tick = func(_i, _k):
		if not pj.live(c):
			return
		if c is Player:
			c.hp = maxf(1.0, c.hp - c.max_hp * 0.01)
		for e in pj.enemies_near(c, c.global_position, 3.0):
			if not pj.live(e):
				continue
			_life_burn(e)
			e.take_hit(pj.inf(c, "barion_modo", 0.2, {"knock": 0.0, "kind": "light", "burn": 2.0}))
	var done = func():
		for pp in parts:
			if is_instance_valid(pp):
				if pp is Node3D and not (pp is CPUParticles3D):
					var tw = pp.create_tween()
					tw.tween_property(pp, "scale", Vector3.ONE * 0.05, 0.25)
					tw.tween_callback(pp.queue_free)
				else:
					pp.queue_free()
	pj.every(12.0, 0.5, tick, done)
	pj.shake(0.8)
	Sfx.play("roar", c.global_position, 1.0)


# ═════════════════════════════════════════ Chigiri Tōhō: Honenuki ═════════════════════════════════════════

## Kristal çakra kılıcı parçası (ileri = -Z): uzun altıgen çift piramit, düz yüzlü
static func _shard_mesh() -> Mesh:
	if _mesh.has("shard"):
		return _mesh["shard"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ra = []
	var rb = []
	for i in 6:
		var a = TAU * i / 6.0
		ra.append(Vector3(cos(a) * 0.05, sin(a) * 0.05, -0.3))
		rb.append(Vector3(cos(a) * 0.045, sin(a) * 0.045, 0.36))
	var f = Vector3(0, 0, -0.5)
	var bk = Vector3(0, 0, 0.5)
	for i in 6:
		var j = (i + 1) % 6
		_ft(st, f, ra[j], ra[i])
		_ft(st, ra[i], ra[j], rb[j])
		_ft(st, ra[i], rb[j], rb[i])
		_ft(st, bk, rb[i], rb[j])
	var m = st.commit()
	_mesh["shard"] = m
	return m


static func _ft(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n = (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0) < 0.0:
		n = -n
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(p)


## Kesik çizgisi: hedefin içinden geçen ince kırmızı-beyaz çizgi bir anda uzanır
static func _bone_cut(p: Vector3, d: Vector3) -> void:
	var a = p - d * 1.5
	var b = p + d * 1.5
	var m = _mat("rib", {"core_col": Color(1.0, 0.92, 0.92, 1.0), "edge_col": Color(0.75, 0.08, 0.12, 0.95), "edge_w": 0.45, "soft": 0.1})
	var fn = func(age):
		var k = clampf(age / 0.06, 0.0, 1.0)
		return [{"p": _seg(a, a.lerp(b, maxf(k, 0.05)), 8), "w": 0.035, "a": 1.0 - smoothstep(0.12, 0.25, age), "tp": 1}]
	_lines(fn, m, 0.25)


## Kan damlaları + yerde kan lekesi
static func _blood(at: Vector3, d: Vector3, n: int) -> void:
	var v = func(_i) -> Vector3:
		return d * randf_range(1.5, 4.0) + _rdir() * 2.0 + Vector3.UP * randf_range(0.5, 2.5)
	_bits(at, n, _mote_mesh(), _mat("cel", {"tint": BLOOD, "shade": 0.6, "glow": 0.1}), v, {"g": 16.0, "life": 0.9, "size": 0.07, "r": 0.25})
	_decal(_g(at), 0.7, Color(0.4, 0.02, 0.04, 0.75), 4.0, {"jag": 0.45})


## Referans: bedenin içinden yan yana geçen, parlayan mavi kristal kılıç parçaları (kılıcın geçiş izi) — yukarıdan aşağı
## sırayla kayarak çıkar, bir an durur, söner
static func _bone_shards(tt: Node3D, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized()
	var sd = (d * 0.85 + side * 0.3 - Vector3.UP * 0.25).normalized()
	var eh = _height(tt)
	var m = _orb(Color(0.92, 0.99, 1.0, 1.0), Color(0.45, 0.82, 1.0, 0.85), Color(1, 1, 1, 0), Color(0.75, 0.95, 1.0, 0.7),
		{"core_size": 0.7, "rim_w": 0.3, "lw": 0.0, "near_a": 0.6, "near_b": 2.0}, "orb_ds")
	var root = Node3D.new()
	_put(root, tt.global_position)
	for k in 10:
		var h = (0.25 + 0.85 * float(k) / 9.0) * eh
		var o = side * randf_range(-0.35, 0.35) + d * randf_range(-0.2, 0.2)
		var ln = randf_range(1.1, 1.8) * maxf(1.0, eh / 1.8)
		var mi = _mi(_shard_mesh(), m)
		root.add_child(mi)
		var c0 = Vector3.UP * h + o - sd * 1.8
		var c1 = Vector3.UP * h + o + sd * 0.45
		mi.position = c0
		mi.basis = Basis.looking_at(sd, Vector3.UP) * Basis.from_scale(Vector3(1.3, 1.3, ln))
		var tw = mi.create_tween()
		tw.tween_interval((9 - k) * 0.012)
		tw.tween_property(mi, "position", c1, 0.1).set_ease(Tween.EASE_OUT)
	_fade(root, [m], 0.4, 0.25)
	_light(tt.global_position + Vector3.UP * eh * 0.5, Color(0.5, 0.85, 1.0), 3.0, 6.0, 0.4)


## c_chigiri_toho_honenuki oynanışı birebir (kılıç bedenden geçer: ağır kesik, sersemleme); görsel: kesik çizgisi + kan
static func chigiri_core(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	var d = pj.fwd(c, t)
	pj.busy(c, 0.5)
	pj.anim(c, "slash_b", 1.6)
	var cut = func():
		var p = (tt.global_position if pj.live(tt) else c.global_position + d * 2.0) + Vector3.UP
		_bone_cut(p, d)
		for h in pj.hit(c, p, 1.5, pj.inf(c, "chigiri_toho_honenuki", 2.2, {"knock": 2.0, "kind": "heavy", "burn": 6.0, "hitstop": 0.15})):
			if not pj.live(h):
				continue
			pj.st(h, "stun", 1.0)
			_blood(h.global_position + Vector3.UP, d, 14)
		Sfx.play("kunai", p, 0.8)
	pj.after(0.2, cut)


## Kemik Parçalama (p_): çekirdek + bedenden geçen mavi kristal kılıç parçaları ve kan
static func chigiri_toho_honenuki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	chigiri_core(pj, c, t)
	if tt:
		var d = pj.fwd(c, t)
		var vis = func():
			if pj.live(tt):
				_bone_shards(tt, d)
				_blood(tt.global_position + Vector3.UP, d, 10)
		pj.after(0.25, vis)


# ═════════════════════════════════════════ Bubitorappu ═════════════════════════════════════════

## Etiket tutuşur: kâğıt kızarıp parlar, kıvılcım saçar
static func _tag_fuse(tg: MeshInstance3D) -> void:
	if not is_instance_valid(tg):
		return
	var mats: Array = tg.get_meta("mats")
	var f = func(v: float) -> void:
		mats[0].set_shader_parameter("glow", v)
		mats[0].set_shader_parameter("tint", Color(1, 1, 1).lerp(Color(1.0, 0.6, 0.3), v / 2.0))
	tg.create_tween().tween_method(f, 0.0, 2.0, 0.25)
	_bits(tg.global_position + Vector3.UP * 0.05, 6, _mote_mesh(), _mat("cel", {"tint": Color(1.0, 0.7, 0.3), "glow": 2.0}), _vr(0.3, 1.2, 1.0, 2.5), {"g": 3.0, "life": 0.3, "size": 0.05, "floor": false})


## Küçük alev topağı: konturlu turuncu cel küreler bir anda şişer, yükselirken kahve-griye koyulaşıp söner
static func _fire_pop(at: Vector3, s: float) -> void:
	var root = Node3D.new()
	_put(root, at)
	var ms = []
	var cols = [Color(1.0, 0.85, 0.35), Color(1.0, 0.55, 0.15), Color(0.95, 0.4, 0.1)]
	for k in 3:
		var mi = _solid(_sphere(0.5, 14), true, 0.04, 1.2, 0.75)
		var mats: Array = mi.get_meta("mats")
		mats[0].set_shader_parameter("tint", cols[k])
		mats[1].set_shader_parameter("col", Color(0.35, 0.12, 0.05, 1.0))
		root.add_child(mi)
		mi.position = _rdir() * 0.35 * s + Vector3.UP * k * 0.2 * s
		mi.scale = Vector3.ONE * 0.1
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * s * randf_range(0.9, 1.3), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "position", mi.position + Vector3.UP * 0.8 * s, 0.6)
		var c0: Color = cols[k]
		var dk = func(v: float) -> void:
			mats[0].set_shader_parameter("tint", c0.lerp(Color(0.32, 0.27, 0.24), v))
			mats[0].set_shader_parameter("glow", 1.2 * (1.0 - v))
		mi.create_tween().tween_method(dk, 0.0, 1.0, 0.45).set_delay(0.08)
		ms.append_array(mats)
	_fade(root, ms, 0.25, 0.4)


## Etiket patlaması: her etikette alev topağı, ortada büyük topak + sekiz uçlu sarı-turuncu çakma, yanık izleri,
## savrulan toprak, turuncu ışık
static func _tag_blast(pj: PathJutsu, at: Vector3, tpos: Array) -> void:
	for q in tpos:
		_fire_pop(Vector3(q) + Vector3.UP * 0.3, randf_range(0.9, 1.2))
		_decal(_g(q), 0.9, Color(0.12, 0.09, 0.07, 0.8), 8.0, {"jag": 0.4})
	_fire_pop(at + Vector3.UP * 0.6, 1.6)
	_star_flash(at + Vector3.UP * 0.8, 2.0, Color(1.0, 0.95, 0.6), Color(1.0, 0.5, 0.12), 0.18, 8)
	_decal(at, 2.2, Color(0.14, 0.1, 0.08, 0.75), 8.0, {"spokes": 7.0, "disc_r": 0.5, "jag": 0.3})
	_bits(at + Vector3.UP * 0.3, 14, _rock_mesh(), _rock_mat(EARTH), _vr(3.0, 7.0, 4.0, 8.0), {"g": 20.0, "life": 1.2, "size": 0.15, "r": 1.2})
	_light(at + Vector3.UP, Color(1.0, 0.6, 0.25), 9.0, 14.0, 0.45)
	pj.shake(0.5)


## Tuzak (referans: dört yandan saplanan kunai): yere çapraz gerilmiş ince teller, uçlarında yere çakılı kunai kazıkları,
## yerde yatan patlayıcı etiketler; basan düşmana sekiz kunai tel parıltısıyla yağar, etiketler tutuşup patlar
static func bubitorappu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	pj.anim(c, "crouch", 1.6)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 4.0)
	var root = Node3D.new()
	_put(root, at)
	var wire_m = _mat("cel", {"tint": Color(0.86, 0.88, 0.9), "glow": 0.4, "shade": 0.8})
	var wire_mesh = CylinderMesh.new()
	wire_mesh.top_radius = 0.008
	wire_mesh.bottom_radius = 0.008
	wire_mesh.height = 4.0
	wire_mesh.radial_segments = 4
	wire_mesh.rings = 1
	var tags = []
	var tpos = []
	for k in 4:
		var a = k * TAU / 4.0 + 0.4
		var w = _mi(wire_mesh, wire_m)
		w.position = Vector3(0, 0.18, 0)
		w.rotation = Vector3(0, a, PI * 0.5)
		root.add_child(w)
		var wd = Vector3(cos(a), 0, -sin(a))
		for e in [-1.0, 1.0]:
			var stake = _solid(_kunai_mesh(), false, 0.01)
			root.add_child(stake)
			stake.position = wd * e * 2.0 + Vector3.UP * 0.16
			stake.rotation = Vector3(-PI * 0.5 + randf_range(-0.2, 0.2), randf() * TAU, 0)
		var tg_mi = _solid(_tag_mesh("bomb"), false, 0.008, 0.0, 0.7)
		root.add_child(tg_mi)
		tg_mi.position = Vector3(cos(a) * 1.8, 0.03, sin(a) * 1.8)
		tg_mi.rotation = Vector3(-PI * 0.5, randf() * TAU, 0)
		tags.append(tg_mi)
		tpos.append(at + tg_mi.position)
	_decal(at, 1.0, Color(0.25, 0.19, 0.13, 0.45), 20.0, {"jag": 0.35})
	var fired := {"v": false}
	var chk = func(_i, _k):
		if fired["v"] or not is_instance_valid(root):
			return
		if not pj.enemies_near(c, at, 2.0).is_empty():
			fired["v"] = true
			var glint = _mat("rib_add", {"core_col": Color(1, 1, 1, 0.8), "edge_col": Color(0.7, 0.75, 0.8, 0.3), "edge_w": 0.5})
			for k in 8:
				var a = k * TAU / 8.0
				var q = at + Vector3(cos(a) * 4.5, 1.2, sin(a) * 4.5)
				var pr = pj.shot(c, q, (at + Vector3.UP - q).normalized(), 40.0, _solid(_kunai_mesh(), false, 0.01), pj.inf(c, "bubitorappu", 0.2, {"knock": 1.0, "kind": "light", "bleed": 2.0}), null, false, 0.4)
				if pr:
					_trail_fn(_follow(pr), 0.012, 0.12, 0.4, glint)
			for tgm in tags:
				_tag_fuse(tgm)
			var boom = func():
				_tag_blast(pj, at, tpos)
				pj.hit(c, at + Vector3.UP, 3.8, pj.inf(c, "bubitorappu", 1.2, {"knock": 14.0, "launch": 9.0, "kind": "heavy", "element": "katon"}))
				if is_instance_valid(root):
					root.queue_free()
			pj.after(0.25, boom)
	var done = func():
		if is_instance_valid(root):
			root.queue_free()
	pj.every(20.0, 0.12, chk, done)


# ═════════════════════════════════════════ Bunshin Daibakuha ═════════════════════════════════════════

## Klon doğuşu: ayak dibinden yükselen kısa sıcak çakra çizgileri halkası
static func _clone_spark(at: Vector3) -> void:
	var m = _mat("rib_add", {"core_col": Color(1, 1, 0.95, 0.9), "edge_col": Color(1.0, 0.7, 0.35, 0.5), "edge_w": 0.5})
	var fn = func(age):
		var k = age / 0.35
		var out = []
		for i in 10:
			var a = TAU * i / 10.0
			var b = at + Vector3(cos(a) * 0.6, 0.1 + k * 1.8, sin(a) * 0.6)
			out.append({"p": _seg(b, b + Vector3.UP * 0.5, 4), "w": 0.03, "a": maxf(0.0, 1.0 - k), "tp": 1})
		return out
	_lines(fn, m, 0.35)


## Bomba klon: gövdesinde turuncu çakra damarları gittikçe hızlanarak nabız atar, içten turuncu ışık
static func _bomb_charge(d: Node3D) -> void:
	var m = _mat("rib_add", {"core_col": Color(1.0, 0.9, 0.6, 1.0), "edge_col": Color(1.0, 0.45, 0.1, 0.7), "edge_w": 0.5})
	var seeds = []
	for k in 6:
		seeds.append({"a": TAU * k / 6.0 + randf_range(-0.3, 0.3), "y0": randf_range(0.3, 0.7), "y1": randf_range(1.2, 1.7)})
	var f = _follow(d)
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.omni_range = 4.0
	l.shadow_enabled = false
	l.light_energy = 0.0
	d.add_child(l)
	l.position = Vector3.UP * 1.0
	var fn = func(age):
		var p: Vector3 = f.call()
		if not p.is_finite():
			return null
		var pulse = 0.5 + 0.5 * sin(age * (8.0 + age * 10.0))
		if is_instance_valid(l):
			l.light_energy = 0.6 + 1.6 * pulse
		var out = []
		for sd in seeds:
			var pts = []
			for j in 6:
				var u = float(j) / 5.0
				var ang = float(sd["a"]) + sin(u * 9.0 + float(sd["a"])) * 0.18
				var y = lerpf(float(sd["y0"]), float(sd["y1"]), u)
				var rr = 0.3 if y > 0.8 else 0.22
				pts.append(p + Vector3(cos(ang) * rr, y, sin(ang) * rr))
			out.append({"p": pts, "w": 0.025, "a": 0.35 + 0.65 * pulse, "tp": 1})
		return out
	_lines(fn, m, 6.0, d)


## Klon patlaması (referans: soluk, cel gölgeli, sivri alev tepeli dev patlama sütunu): ak-turuncu çekirdek çakması,
## sivri tepeli konik dilimlerden sütun bir anda yükselir, yerde dışa yuvarlanan topak halkası, fırlayan taş, krater, ışık
static func _clone_blast(pj: PathJutsu, pos: Vector3) -> void:
	var g = _g(pos)
	var core = _mi(_sphere(1.0, 20), _orb(Color(1, 1, 0.95, 1), Color(1.0, 0.75, 0.4, 0.9), Color(1, 1, 1, 0), Color(1.0, 0.55, 0.2, 0.8), {"core_size": 0.8, "rim_w": 0.3, "lw": 0.0, "near_a": 1.5, "near_b": 5.0}))
	_put(core, pos + Vector3.UP * 0.4)
	core.scale = Vector3.ONE * 0.2
	var tc = core.create_tween()
	tc.tween_property(core, "scale", Vector3.ONE * 2.2, 0.08)
	tc.tween_property(core, "scale", Vector3.ONE * 0.1, 0.25)
	tc.tween_callback(core.queue_free)
	var b = MB.new()
	for k in 9:
		var a = TAU * k / 9.0 + randf_range(-0.2, 0.2)
		var rr = randf_range(0.3, 1.5)
		var hgt = randf_range(3.2, 6.2) * (1.0 - rr * 0.25)
		var tilt = rr * 14.0 + randf_range(0.0, 6.0)
		var colk = BLAST_PALE if k % 3 != 0 else BLAST_SHADE.lerp(BLAST_PALE, 0.45)
		b.add("cone", Vector3(cos(a) * rr, hgt * 0.5, sin(a) * rr), Vector3(randf_range(1.4, 2.2), hgt, randf_range(1.4, 2.2)), colk, Vector3(tilt * sin(a), 0, -tilt * cos(a)), 10)
	for k in 10:
		var a = randf() * TAU
		var rr = randf_range(0.6, 2.0)
		b.add("sphere", Vector3(cos(a) * rr, randf_range(0.3, 1.2), sin(a) * rr), Vector3.ONE * randf_range(1.2, 2.0), BLAST_PALE if k % 2 == 0 else BLAST_SHADE.lerp(BLAST_PALE, 0.6), Vector3.ZERO, 10)
	var col_mi = _solid(b.build(null), true, 0.06, 0.35, 0.78)
	var cm: Array = col_mi.get_meta("mats")
	cm[1].set_shader_parameter("col", Color(0.22, 0.3, 0.45, 1.0))
	_put(col_mi, g)
	col_mi.scale = Vector3(0.5, 0.05, 0.5)
	var tw = col_mi.create_tween()
	tw.tween_property(col_mi, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(col_mi, "scale", Vector3(1.15, 0.35, 1.15), 0.7).set_ease(Tween.EASE_IN)
	_fade(col_mi, cm, 0.5, 0.6)
	var lm = _mat("cel_a", {"glow": 0.3, "shade": 0.78, "tint": BLAST_PALE})
	var lo = _mat("out_a", {"grow": 0.05, "col": Color(0.22, 0.3, 0.45, 1.0)})
	lm.next_pass = lo
	var sph = _sphere(0.5, 10)
	var lumps = []
	for k in 14:
		var mi = _mi(sph, lm)
		mi.scale = Vector3(0.9, 0.6, 0.9) * randf_range(0.8, 1.2)
		lumps.append([mi, TAU * k / 14.0])
	var roll = func(_n, _dt, age) -> bool:
		if age > 1.0:
			return false
		var k = minf(age / 0.7, 1.0)
		var r = 1.0 + 3.8 * (1.0 - pow(1.0 - k, 3.0))
		for lp in lumps:
			var mi: MeshInstance3D = lp[0]
			var a = float(lp[1])
			mi.position = Vector3(cos(a) * r, 0.25, sin(a) * r)
		return true
	var tk = _host(roll, g)
	for lp in lumps:
		tk.add_child(lp[0])
	_fade(tk, [lm, lo], 0.3, 0.6, false)
	_bits(g + Vector3.UP * 0.5, 18, _rock_mesh(), _rock_mat(EARTH), _vr(3.0, 8.0, 5.0, 11.0), {"g": 22.0, "life": 1.6, "size": 0.22, "r": 1.0})
	_decal(g, 3.4, Color(0.14, 0.11, 0.09, 0.8), 8.0, {"spokes": 10.0, "disc_r": 0.5, "jag": 0.3, "col2": Color(0.3, 0.24, 0.2, 0.6)})
	_light(pos + Vector3.UP * 1.5, Color(1.0, 0.8, 0.5), 14.0, 22.0, 0.6)


## Klon Büyük Patlaması: gölge klon doğar, içi turuncu çakra damarlarıyla dolup nabız atarak düşmana koşar, temasta
## dev patlama (oynanış p_bunshin_daibakuha birebir)
static func bunshin_daibakuha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 20.0)
	var at = pj.gp(c.global_position + c.face_dir() * 1.5)
	_clone_spark(at)
	var pop = func(pos):
		_clone_blast(pj, pos)
		pj.hit(c, pos + Vector3.UP, 5.0, pj.inf(c, "bunshin_daibakuha", 1.9, {"knock": 20.0, "launch": 8.0, "kind": "heavy", "element": "bakuton"}))
		pj.shake(1.0)
	var d = pj.decoy(c, at, 6.0, pop)
	if d:
		_bomb_charge(d)
	if d and tt:
		var tw = d.create_tween()
		tw.tween_property(d, "global_position", pj.gp(tt.global_position - (tt.global_position - at).normalized() * 0.8), 0.6)
		var fin = func():
			if is_instance_valid(d):
				d.queue_free()
		tw.tween_callback(fin)
	Sfx.play("poof", at, 1.0)


# ═════════════════════════════════════════ Kumo-ryū: Mikazukigiri ═════════════════════════════════════════

## Referans: aşağı savrulan dev beyaz hilal — dış kenarı mavi parlak, iç kenarı saydamlaşır; d + yukarı düzleminde
## arkadan-yukarıdan öne-aşağı doğru çizilerek açılır
static func _crescent_moon(center: Vector3, d: Vector3) -> void:
	var R = 2.3
	var n = 30
	var L = []
	var Rr = []
	var L2 = []
	var R2 = []
	for i in n:
		var u = float(i) / float(n - 1)
		var th = lerpf(deg_to_rad(150.0), deg_to_rad(-45.0), u)
		var dv = d * cos(th) + Vector3.UP * sin(th)
		var thick = 0.95 * pow(maxf(0.0, sin(PI * u)), 0.8)
		L.append(dv * (R + thick * 0.15))
		Rr.append(dv * (R - thick * 0.85))
		L2.append(dv * (R + thick * 0.35 + 0.08))
		R2.append(dv * (R - thick * 1.0))
	var m1 = _mat("rib", {"core_col": Color(1, 1, 1, 0.97), "edge_col": Color(0.55, 0.85, 1.0, 1.0), "edge_w": 0.28, "asym": 1.0, "inner_fade": 1.0, "soft": 0.1, "head": 0.0})
	var m2 = _mat("rib_add", {"core_col": Color(0.5, 0.8, 1.0, 0.0), "edge_col": Color(0.45, 0.75, 1.0, 0.55), "edge_w": 0.5, "asym": 1.0, "inner_fade": 1.0, "soft": 0.4, "head": 0.0})
	var root = Node3D.new()
	_put(root, center)
	root.add_child(_mi(_strip(L2, R2), m2))
	root.add_child(_mi(_strip(L, Rr), m1))
	_tp(root, m1, "head", 0.0, 1.0, 0.12)
	_tp(root, m2, "head", 0.0, 1.0, 0.12)
	var tw = root.create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(root, "scale", Vector3.ONE * 1.1, 0.3)
	_fade(root, [m1, m2], 0.2, 0.3)
	_light(center, Color(0.7, 0.88, 1.0), 4.0, 8.0, 0.35)


## Yerde ileri uzanan kesik yarığı (koyu öz, buz mavisi kenar) + çatlak + toz
static func _ground_slit(g: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized()
	var L = []
	var R = []
	for i in 10:
		var u = float(i) / 9.0
		var p = _g(g + d * lerpf(-0.6, 3.0, u)) - g + Vector3.UP * 0.035
		var w = 0.09 * maxf(0.0, sin(PI * pow(u, 0.7)))
		L.append(p - side * w)
		R.append(p + side * w)
	var m = _mat("rib", {"core_col": Color(0.12, 0.1, 0.1, 0.85), "edge_col": Color(0.85, 0.92, 1.0, 0.6), "edge_w": 0.3, "soft": 0.2})
	var mi = _mi(_strip(L, R), m)
	_put(mi, g)
	_fade(mi, [m], 2.0, 1.5)
	_decal(g, 1.5, Color(0.18, 0.15, 0.12, 0.6), 3.0, {"spokes": 6.0, "disc_r": 0.25, "jag": 0.3})
	_bits(g + Vector3.UP * 0.1, 6, _rock_mesh(), _rock_mat(EARTH), _vr(1.0, 3.0, 2.0, 4.0, d * 2.0), {"g": 16.0, "life": 0.9, "size": 0.1})


## İsabet: hedefin üstünden çapraz geçen kısa beyaz kesik + mavi kıvılcım
static func _moon_cut(p: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized()
	var cd = (side * 0.6 + Vector3.UP * 0.8).normalized()
	var m = _mat("rib_add", {"core_col": Color(1, 1, 1, 1), "edge_col": Color(0.5, 0.8, 1.0, 0.8), "edge_w": 0.4})
	var a = p + cd * 1.1
	var b = p - cd * 1.1
	var fn = func(age):
		return [{"p": _seg(a, a.lerp(b, clampf(age / 0.05, 0.05, 1.0)), 6), "w": 0.04, "a": 1.0 - smoothstep(0.1, 0.22, age), "tp": 1}]
	_lines(fn, m, 0.22)
	_bits(p, 10, _mote_mesh(), _mat("cel", {"tint": Color(0.7, 0.9, 1.0), "glow": 2.0}), _vr(2.0, 5.0, 0.5, 2.5, d * 3.0), {"g": 6.0, "life": 0.4, "size": 0.05, "floor": false})


## Bulut Stili Hilal Kesik: sıçrayıp takla atarken kılıç ucu havada beyaz yay çizer, sonra aşağı dev hilal
static func kumo_ryu_mikazukigiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	var d = pj._jump_at(c, tt, 9.0, 8.0 if tt else 3.0)
	pj.busy(c, 0.9)
	pj._kick_pose(c, 0.35)
	var hf = func() -> Vector3:
		return pj.hand_pos(c, true) if pj.live(c) else Vector3.INF
	_trail_fn(hf, 0.035, 0.22, 0.4, _mat("rib_add", {"core_col": Color(1, 1, 1, 0.9), "edge_col": Color(0.55, 0.8, 1.0, 0.5), "edge_w": 0.5}))
	var slash = func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_c", 1.6)
		var at = c.global_position + Vector3.UP * 0.5
		_crescent_moon(at + d * 0.8, d)
		var g = pj.gp(at + d * 1.5)
		_ground_slit(g, d)
		var hs = pj.hit(c, g + Vector3.UP, 2.6, pj.inf(c, "kumo_ryu_mikazukigiri", 1.6, {"knock": 8.0, "kind": "heavy", "bleed": 4.0}))
		if not hs.is_empty() and is_instance_valid(hs[0]):
			_moon_cut(hs[0].global_position + Vector3.UP, d)
			pj.shake(0.54)
		Sfx.play("clink", at, 0.8)
	pj.after(0.4, slash)


# ═════════════════════════════════════════ Renzoku Bijūdama ═════════════════════════════════════════

## Kuyruklu canavar topu (kendi görseli): siyah gövde, koyu mor sarmal çizgiler, mor parlayan kontur, içte kızgın turuncu göbek
## (referans: dumanın içinde kızıl parlayan toplar), dışta ters dönen mor korona, mor ışık
static func _biju_ball(diam: float) -> Node3D:
	var r = diam * 0.5
	var root = Node3D.new()
	var m1 = _orb(BIJU_HOT, Color(BIJU_BODY, 0.97), Color(BIJU_LINE, 0.9), Color(BIJU_RIM, 1.0),
		{"arms": 4.0, "twist": 4.0, "spin": 2.6, "lw": 0.25, "core_size": 0.28, "rim_w": 0.2})
	root.add_child(_mi(_sphere(r, 24), m1))
	var m2 = _orb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.6, 0.3, 0.9, 0.5), Color(0.78, 0.5, 1.0, 0.55),
		{"arms": 3.0, "twist": -3.0, "spin": -3.5, "lw": 0.1, "core_size": 0.0, "rim_w": 0.55})
	root.add_child(_mi(_sphere(r * 1.25, 20), m2))
	var l = OmniLight3D.new()
	l.light_color = Color(0.7, 0.35, 1.0)
	l.light_energy = 1.4
	l.omni_range = maxf(3.0, diam * 5.0)
	l.shadow_enabled = false
	root.add_child(l)
	root.set_meta("mats", [m1, m2])
	return root


## Toplanma: ağız önüne koyu mor ve kızıl çakra iplikleri sarmal çizerek akar; ağızda küçük top nabız atar
static func _biju_gather(src: Callable, dur: float, hold: float) -> void:
	_spiral_in(src, 14, 2.6, dur, 0.05, _mat("rib", {"core_col": Color(0.1, 0.03, 0.15, 0.95), "edge_col": Color(0.65, 0.35, 0.95, 0.9), "edge_w": 0.35}))
	_spiral_in(src, 8, 2.0, dur, 0.025, _mat("rib_add", {"core_col": Color(1.0, 0.55, 0.35, 0.9), "edge_col": Color(1.0, 0.2, 0.2, 0.3), "edge_w": 0.5}))
	var p0: Vector3 = src.call()
	if not p0.is_finite():
		return
	var ball = _biju_ball(0.6)
	_put(ball, p0)
	var f = func(_n, _dt, age) -> bool:
		if not is_instance_valid(ball):
			return false
		var p: Vector3 = src.call()
		if not p.is_finite() or age > hold:
			ball.queue_free()
			return false
		ball.global_position = p
		var k = minf(1.0, age / dur)
		ball.scale = Vector3.ONE * (0.2 + 0.8 * k) * (1.0 + 0.12 * sin(age * 30.0)) * (1.0 - smoothstep(hold - 0.2, hold, age))
		return true
	_host(f)


## Atış anında ağız önünde geriye açılan mor halka
static func _biju_dome(p: Vector3) -> void:
	var m = _orb(Color(0, 0, 0, 0), Color(0.12, 0.04, 0.2, 0.55), Color(0.55, 0.25, 0.85, 0.8), Color(0.95, 0.85, 1.0, 1.0),
		{"arms": 6.0, "twist": 2.0, "spin": 4.0, "lw": 0.15, "core_size": 0.0, "rim_w": 0.3, "near_a": 1.5, "near_b": 5.0})
	var dome = _mi(_sphere(1.0, 28), m)
	_put(dome, p)
	dome.scale = Vector3.ONE * 0.2
	var tw = dome.create_tween()
	tw.tween_property(dome, "scale", Vector3.ONE * 3.6, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(dome, "scale", Vector3.ONE * 0.1, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(dome.queue_free)
	var fl = _mi(_sphere(0.6, 16), _orb(Color(1, 0.95, 1, 1), Color(0.85, 0.6, 1.0, 0.9), Color(1, 1, 1, 0), Color(0.7, 0.4, 1.0, 0.6), {"core_size": 0.8, "lw": 0.0, "rim_w": 0.4}))
	_put(fl, p)
	var tf = fl.create_tween()
	tf.tween_property(fl, "scale", Vector3.ONE * 2.2, 0.1)
	tf.tween_property(fl, "scale", Vector3.ONE * 0.1, 0.15)
	tf.tween_callback(fl.queue_free)
	var g = _g(p)
	if p.y - g.y < 3.5:
		_decal(g, 3.2, Color(0.1, 0.04, 0.14, 0.8), 6.0, {"spokes": 11.0, "disc_r": 0.42, "jag": 0.3, "col2": Color(0.3, 0.12, 0.4, 0.6)})
		_decal(g, 7.5, Color(0.75, 0.5, 1.0, 0.8), 0.45, {"ring_r": 0.85, "ring_w": 0.05, "add": true, "grow": 0.4})
		_bits(g + Vector3.UP * 0.3, 10, _rock_mesh(), _rock_mat(Color(0.2, 0.14, 0.2)), _vr(3.0, 7.0, 4.0, 8.0), {"g": 20.0, "life": 1.2, "size": 0.18, "r": 0.8})
	_light(p, Color(0.7, 0.4, 1.0), 10.0, 18.0, 0.5)


## Ardışık Kuyruklu Canavar Topları: çakra ağızda toplanır, peş peşe beş kara-mor top koyu iz bırakarak fırlar,
## her biri kara içli, ak-mor kenarlı patlama kubbesi + yerde mor yanık bırakır (oynanış birebir)
static func renzoku_bijudama(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.8)
	var tt = pj.tg(c, t, 36.0)
	var mouth = func() -> Vector3:
		if not is_instance_valid(c):
			return Vector3.INF
		return pj._mouth_pos(c) + c.face_dir() * 1.2
	_biju_gather(mouth, 0.55, 1.5)
	var trail_m = _mat("rib", {"core_col": Color(0.15, 0.05, 0.25, 0.85), "edge_col": Color(0.7, 0.4, 1.0, 0.8), "edge_w": 0.35, "soft": 0.2})
	var ring_m = _mat("rib_add", {"core_col": Color(0.85, 0.65, 1.0, 0.9), "edge_col": Color(0.5, 0.2, 0.8, 0.4), "edge_w": 0.5})
	for k in 5:
		var fire = func():
			if not pj.live(c):
				return
			var from = pj._mouth_pos(c) + c.face_dir() * 1.2
			var d = pj.aim_at(c, tt, from)
			d = (d + c.face_dir().cross(Vector3.UP) * randf_range(-0.12, 0.12)).normalized()
			var on_hit = func(p, _h):
				_biju_dome(p)
				pj.hit(c, p, 5.0, pj.inf(c, "renzoku_bijudama", 0.6, {"knock": 14.0, "kind": "heavy"}))
				pj.shake(0.6)
			var pr = pj.shot(c, from, d, 32.0, _biju_ball(1.4), pj.inf(c, "renzoku_bijudama", 1.4, {"knock": 18.0, "launch": 6.0, "kind": "heavy"}), null, false, 1.6, on_hit)
			pr.radius = 0.8
			_trail_fn(_follow(pr), 0.35, 0.25, 1.6, trail_m)
			_ring_line(from, d, 0.4, 1.8, 0.22, 0.06, ring_m, -0.8)
		pj.after(0.5 + k * 0.22, fire)
	Sfx.play("roar", c.global_position, 0.7)


# ═════════════════════════════════════════ Sangoshō ═════════════════════════════════════════

static func _cyl_between(b: MB, a: Vector3, e: Vector3, r: float, col: Color) -> void:
	var v = e - a
	var ln = v.length()
	if ln < 0.001:
		return
	var y = v / ln
	var x = y.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z = x.cross(y).normalized()
	b.add_xf("cyl", Transform3D(Basis(x * r * 2.0, y * ln, z * r * 2.0), (a + e) * 0.5), col, 6)


## Mercan dalı: hafif kıvrılan üç parçalı kol, ucu açık pembe topuz, uçtan iki dala çatallanır
static func _coral_branch(b: MB, p: Vector3, dir: Vector3, ln: float, r: float, depth: int) -> void:
	var cur = p
	var dv = dir
	for s in 3:
		dv = (dv + _rdir() * 0.25 + Vector3.UP * 0.12).normalized()
		var nxt = cur + dv * ln / 3.0
		_cyl_between(b, cur, nxt, r * (1.0 - 0.18 * s), CORAL.darkened(randf() * 0.12))
		cur = nxt
	b.add("sphere", cur, Vector3.ONE * r * 2.2, CORAL_TIP, Vector3.ZERO, 8)
	if depth > 0:
		for j in 2:
			_coral_branch(b, cur, (dv + _rdir() * 0.7).normalized(), ln * 0.7, r * 0.7, depth - 1)


## Gövdeyi saran yumrulu mercan kabuğu + dışa / yukarı çatallanan dallar (konturlu cel)
static func _coral_mass() -> MeshInstance3D:
	var b = MB.new()
	for k in 9:
		var a = randf() * TAU
		b.add("sphere", Vector3(cos(a) * 0.3, randf_range(0.25, 1.6), sin(a) * 0.3), Vector3.ONE * randf_range(0.55, 0.8), CORAL.darkened(randf() * 0.15), Vector3.ZERO, 10)
	for k in 7:
		var a = TAU * k / 7.0 + randf_range(-0.2, 0.2)
		var base = Vector3(cos(a) * 0.4, randf_range(0.4, 1.5), sin(a) * 0.4)
		var dir = Vector3(cos(a), randf_range(0.2, 1.1), sin(a)).normalized()
		_coral_branch(b, base, dir, randf_range(0.55, 0.85), 0.11, 2)
	return _solid(b.build(null), false, 0.025, 0.05, 0.6)


## Avuç darbesi: hedef önünde mercan pembesi halka açılır, kireç kırıntıları saçılır
static func _coral_palm(c: Node3D, tt: Node3D) -> void:
	var p = tt.global_position + Vector3.UP * _height(tt) * 0.55
	var d = (tt.global_position - c.global_position) if is_instance_valid(c) else Vector3.FORWARD
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	_ring_line(p - d * 0.3, d, 0.2, 1.3, 0.25, 0.05, _mat("rib_add", {"core_col": Color(1.0, 0.8, 0.75, 0.9), "edge_col": Color(0.95, 0.4, 0.35, 0.5), "edge_w": 0.5}))
	_bits(p, 12, _mote_mesh(), _mat("cel", {"tint": CORAL_TIP, "glow": 0.3}), _vr(1.5, 4.0, 1.0, 3.5, -d * 2.0), {"g": 12.0, "life": 0.8, "size": 0.07})


## Süre bitince mercan kırılır: parçalar dökülür, yerde pembe kırıntı kalır
static func _coral_crumble(pos: Vector3, s: float) -> void:
	_bits(pos + Vector3.UP * 1.0 * s, 22, _rock_mesh(), _rock_mat(CORAL), _vr(0.5, 2.5, 0.5, 3.0), {"g": 14.0, "life": 1.3, "size": 0.14 * s, "r": 0.8 * s})
	_decal(_g(pos), 1.0 * s, Color(0.85, 0.45, 0.4, 0.55), 4.0, {"jag": 0.5})


## Mercan Avucu: avuçta pembe çakra toplanır, dokunulan hedef dallanan kırmızı mercana gömülür (oynanış birebir)
static func sangosho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 0.7)
	if tt == null:
		return
	pj._jump_at(c, tt, 0.0, 12.0)
	var hf = func() -> Vector3:
		return pj.hand_pos(c, true) if pj.live(c) else Vector3.INF
	_spiral_in(hf, 6, 0.6, 0.2, 0.02, _mat("rib_add", {"core_col": Color(1.0, 0.8, 0.75, 0.9), "edge_col": Color(0.95, 0.4, 0.35, 0.5), "edge_w": 0.5}))
	var grow = func():
		if not pj.live(tt):
			return
		var cr = _coral_mass()
		tt.add_child(cr)
		ClanJutsu.fit_body(tt, cr)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		cr.scale = Vector3.ONE * 0.1
		var tw = cr.create_tween()
		tw.tween_property(cr, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(3.5)
		var brk = func():
			if is_instance_valid(cr):
				_coral_crumble(cr.global_position, cr.scale.x)
				cr.queue_free()
		tw.tween_callback(brk)
		pj.st(tt, "bind", 4.0)
		_coral_palm(c, tt)
		pj.shake(0.56)
		tt.take_hit(pj.inf(c, "sangosho", 0.8, {"knock": 0.0, "kind": "heavy"}))
	pj.after(0.2, grow)
	Sfx.play("earth", c.global_position, 1.1)


# ═════════════════════════════════════════ Amanohabaya ═════════════════════════════════════════

## Hilal çakra kılıcı (yerel +Z boyunca 8 m, +X'e yay): yatay şerit + dikey çapraz şerit (hacim) + geniş parıltı şeridi
static func _habaya_meshes() -> Array:
	if _mesh.has("habaya"):
		return _mesh["habaya"]
	var n = 20
	var L = []
	var R = []
	var Lv = []
	var Rv = []
	var Lg = []
	var Rg = []
	for i in n:
		var u = float(i) / float(n - 1)
		var p = Vector3(0.9 * sin(PI * u), 0.0, lerpf(0.4, 8.2, u))
		var tv = Vector3(0.9 * PI * cos(PI * u), 0.0, 7.8)
		var sd = tv.cross(Vector3.UP).normalized()
		var w = 0.42 * pow(maxf(0.0, sin(PI * pow(u, 0.7))), 0.7)
		L.append(p - sd * w)
		R.append(p + sd * w)
		Lv.append(p - Vector3.UP * w * 0.45)
		Rv.append(p + Vector3.UP * w * 0.45)
		Lg.append(p - sd * w * 1.9)
		Rg.append(p + sd * w * 1.9)
	var out = [_strip(L, R), _strip(Lv, Rv), _strip(Lg, Rg)]
	_mesh["habaya"] = out
	return out


## Elden uzayan mor hilal kılıç yatay biçer (108°): arkasında süpürülen açıda ince yay çizgileri (dolu kama değil),
## sonra kılıç mor zerrelere dağılır, en uçta ince bir yay izi bir süre asılı kalır
static func _habaya_sweep(c: Node3D, d: Vector3) -> void:
	var th = atan2(d.x, d.z)
	var center = c.global_position + Vector3.UP * 1.3
	var root = Node3D.new()
	_put(root, center)
	var mb = _mat("rib", {"core_col": Color(VIOLET_CORE, 1.0), "edge_col": Color(VIOLET, 1.0), "edge_w": 0.45, "soft": 0.08})
	var mg = _mat("rib_add", {"core_col": Color(VIOLET, 0.35), "edge_col": Color(VIOLET, 0.0), "edge_w": 0.6, "soft": 0.6})
	var ms = _habaya_meshes()
	root.add_child(_mi(ms[2], mg))
	root.add_child(_mi(ms[0], mb))
	root.add_child(_mi(ms[1], mb))
	var a0 = th + PI * 0.3
	var a1 = th - PI * 0.3
	root.rotation.y = a0
	root.scale = Vector3(1, 1, 0.2)
	var angf = func(tm: float) -> float:
		var k = clampf(tm / 0.25, 0.0, 1.0)
		return lerpf(a0, a1, 1.0 - pow(1.0 - k, 2.0))
	var swing = func(_n, _dt, age) -> bool:
		if not is_instance_valid(root):
			return false
		root.rotation.y = angf.call(age)
		root.scale = Vector3(1, 1, minf(1.0, 0.2 + age / 0.07))
		return age < 0.3
	_host(swing, Vector3.ZERO, root)
	var mt = _mat("rib_add", {"core_col": Color(0.92, 0.8, 1.0, 0.9), "edge_col": Color(VIOLET, 0.5), "edge_w": 0.5})
	var fan = func(age):
		var out = []
		var fa = 1.0 - smoothstep(0.3, 0.6, age)
		if fa > 0.0:
			var A1 = angf.call(age)
			var A0 = angf.call(maxf(0.0, age - 0.12))
			for j in 7:
				var r = 2.0 + j
				var pts = []
				for i in 10:
					var ang = lerpf(A0, A1, float(i) / 9.0)
					pts.append(center + Vector3(sin(ang), 0, cos(ang)) * r + Vector3.UP * (j % 2) * 0.05)
				out.append({"p": pts, "w": 0.03 + 0.01 * j, "a": fa * (1.0 - j * 0.08), "tp": 2})
		if age > 0.25:
			var pts2 = []
			for i in 24:
				var ang2 = lerpf(a0, a1, float(i) / 23.0)
				pts2.append(center + Vector3(sin(ang2), 0, cos(ang2)) * 7.6)
			out.append({"p": pts2, "w": 0.04, "a": 0.6 * (1.0 - clampf((age - 0.25) / 0.95, 0.0, 1.0)), "tp": 1})
		return out
	_lines(fan, mt, 1.2)
	var dissolve = func():
		for i in 4:
			var p = center + Vector3(sin(a1), 0, cos(a1)) * (1.5 + i * 2.0)
			_bits(p, 5, _mote_mesh(), _mat("cel", {"tint": VIOLET, "glow": 2.0}), _vr(0.2, 0.8, 0.6, 1.6), {"g": -0.6, "life": 1.2, "size": 0.06, "floor": false, "r": 0.8})
	var tw = root.create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(dissolve)
	_fade(root, [mb, mg], 0.3, 0.25)
	_light(center + d * 3.0, VIOLET, 6.0, 14.0, 0.55)


## Amanohabaya: avuçta mor çakra toplanır, elden uzayan dev hilal kılıçla tek yatay biçme (oynanış birebir)
static func amanohabaya(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d = pj.fwd(c, t)
	var hf = func() -> Vector3:
		return pj.hand_pos(c, true) if pj.live(c) else Vector3.INF
	_spiral_in(hf, 10, 1.6, 0.35, 0.03, _mat("rib_add", {"core_col": Color(VIOLET_CORE, 0.95), "edge_col": Color(VIOLET, 0.6), "edge_w": 0.5}))
	var cut = func():
		if not pj.live(c):
			return
		_habaya_sweep(c, d)
		Combat.hit_zone(c, c.global_position, d, 8.0, 90.0, 3.0, pj.inf(c, "amanohabaya", 2.4, {"knock": 18.0, "kind": "heavy", "bleed": 5.0, "hitstop": 0.12}))
		pj.shake(0.7)
		Sfx.play("wind", c.global_position, 1.6, 0.6)
	pj.after(0.35, cut)


# ═════════════════════════════════════════ Akademi: Henge / Shunshin / Bunshin ═════════════════════════════════════════

## Henge çakması (duman bulutu değil): yedi kıvrık mürekkep fırça darbesi (krem gövde, koyu mürekkep kenar) merkezden
## virgül gibi dışa açılıp silinir, ortada dört köşeli ak yıldız, savrulan yapraklar, yerde ince halka
static func henge_pop(at: Vector3, s := 1.0, reverse := false) -> void:
	var dirn = -1.0 if reverse else 1.0
	for k in 7:
		var yaw = TAU * k / 7.0 + randf_range(-0.2, 0.2)
		var tilt = randf_range(-0.45, 0.45)
		var bs = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		var nrm = bs * Vector3(0, 0, 1)
		var pts = []
		var m = 14
		for i in m:
			var u = float(i) / float(m - 1)
			var ang = (1.0 - u) * 4.0 * dirn
			var rad = (0.12 + 0.42 * u) * s
			pts.append(bs * Vector3(cos(ang) * rad, sin(ang) * rad, u * 0.75 * s))
		var L = []
		var R = []
		for i in m:
			var tv: Vector3 = Vector3(pts[mini(i + 1, m - 1)]) - Vector3(pts[maxi(i - 1, 0)])
			var sd = tv.cross(nrm)
			sd = sd.normalized() if sd.length() > 0.0001 else Vector3.UP
			var u = float(i) / float(m - 1)
			var w = 0.14 * s * pow(u, 0.6) * (1.0 - pow(u, 6.0))
			L.append(Vector3(pts[i]) - sd * w)
			R.append(Vector3(pts[i]) + sd * w)
		var mat = _mat("rib", {"core_col": Color(0.99, 0.98, 0.94, 1.0), "edge_col": Color(0.3, 0.3, 0.36, 1.0), "edge_w": 0.26, "soft": 0.06, "head": 0.0, "near_a": 0.6, "near_b": 2.0})
		var mi = _mi(_strip(L, R), mat)
		_put(mi, at)
		_tp(mi, mat, "head", 0.0, 1.0, 0.14)
		_tp(mi, mat, "tail", 0.0, 1.0, 0.3, 0.16)
		var tw = mi.create_tween()
		tw.tween_interval(0.12)
		tw.tween_property(mi, "scale", Vector3.ONE * 1.6, 0.36).set_ease(Tween.EASE_OUT)
		tw.tween_callback(mi.queue_free)
	_star_flash(at, 0.9 * s, Color(1, 1, 1, 1), Color(0.75, 0.75, 0.8, 1.0), 0.16, 4)
	_bits(at, 10, _leaf_mesh(), _leaf_mat(), _vr(2.5, 5.0, 1.0, 4.0), {"g": 2.5, "drag": 1.6, "life": 1.6, "size": 0.18, "spin": 9.0})
	_decal(_g(at), 1.3 * s, Color(0.9, 0.9, 0.85, 0.5), 0.6, {"ring_r": 0.8, "ring_w": 0.08, "grow": 0.25})


## Gövde renkleri (saç / üst / alt) — kaçışta bedenin renkli çizgilere bulanması için
static func _look_cols(c: Node3D) -> Array:
	var hair = Color(0.2, 0.18, 0.16)
	var top = Color(0.3, 0.32, 0.3)
	var low = Color(0.2, 0.2, 0.22)
	var md = c.get("model")
	if md and md.get("look") is Dictionary:
		var lk: Dictionary = md.look
		if lk.get("hair") is Color:
			hair = lk["hair"]
		if lk.get("top") is Color:
			top = lk["top"]
		if lk.get("pants") is Color:
			low = lk["pants"]
	return [hair, top, low]


## Shunshin bulanması (referans: Shisui'nin çizgilere çekilen bedeni): gövde yüksekliğinde, bedenin kendi renklerinde
## yatay şeritler — kalkışta ileri çekilip incelir, varışta arkadan gelip gövdede toplanır
static func _smear(at: Vector3, cols: Array, dir: Vector3, arrive: bool) -> void:
	var fw = Vector3(dir.x, 0, dir.z)
	fw = fw.normalized() if fw.length() > 0.01 else Vector3.FORWARD
	var side = fw.cross(Vector3.UP).normalized()
	var m = _mat("rib", {"core_col": Color(1, 1, 1, 0.95), "edge_col": Color(0.55, 0.55, 0.6, 0.95), "edge_w": 0.25, "soft": 0.15})
	var st = []
	for i in 16:
		var y = randf_range(0.1, 1.85)
		var col: Color = cols[0] if y > 1.5 else (cols[1] if y > 0.85 else cols[2])
		st.append({"y": y, "o": randf_range(-0.28, 0.28), "L": randf_range(0.8, 2.2), "c": col.lightened(0.1), "w": randf_range(0.03, 0.07)})
	var fn = func(age):
		var k = clampf(age / 0.24, 0.0, 1.0)
		var out = []
		for s in st:
			var b = at + Vector3.UP * float(s["y"]) + side * float(s["o"])
			var ln = float(s["L"])
			var a0: Vector3
			var a1: Vector3
			if arrive:
				a0 = b + fw * ln * (1.0 - k)
				a1 = b + fw * ln * (1.0 - k) * 0.1
			else:
				a0 = b + fw * ln * k * k
				a1 = b + fw * ln * (0.25 + k)
			out.append({"p": _seg(a0, a1, 5), "w": float(s["w"]), "a": 1.0 - k * 0.7, "tp": 1, "c": s["c"]})
		return out
	_lines(fn, m, 0.24)


## Yaprak girdabı: yapraklar dönerek yükselir, sonra dışa savrulup süzülerek düşer
static func _leaf_whirl(at: Vector3, n: int) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _leaf_mesh()
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _leaf_mat()
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 10.0
	var sd = []
	for i in n:
		var o = _rdir()
		sd.append({"a": randf() * TAU, "y": randf_range(0.0, 0.6), "r": randf_range(0.35, 0.7), "s": randf_range(7.0, 11.0), "sp": randf() * TAU, "out": Vector3(o.x, o.y * 0.3, o.z)})
	var fn = func(_n, _dt, age) -> bool:
		if age > 1.3:
			return false
		for i in n:
			var q = sd[i]
			var p: Vector3
			if age < 0.45:
				var k = age / 0.45
				var ang = float(q["a"]) + float(q["s"]) * age
				p = at + Vector3(cos(ang) * float(q["r"]) * (1.0 + k * 0.5), float(q["y"]) + k * 1.6, sin(ang) * float(q["r"]) * (1.0 + k * 0.5))
			else:
				var ang2 = float(q["a"]) + float(q["s"]) * 0.45
				var base = at + Vector3(cos(ang2) * float(q["r"]) * 1.5, float(q["y"]) + 1.6, sin(ang2) * float(q["r"]) * 1.5)
				var tm = age - 0.45
				p = base + Vector3(q["out"]) * tm * 2.0 + Vector3.DOWN * tm * tm * 1.2
			var s = 0.2 * (1.0 - smoothstep(1.0, 1.3, age))
			var bs = Basis(Vector3(0.3, 1, 0.2).normalized(), age * 8.0 + float(q["sp"]))
			mm.set_instance_transform(i, Transform3D(bs.scaled(Vector3.ONE * maxf(s, 0.001)), p))
		return true
	var tk = _host(fn)
	tk.add_child(mmi)


## Yol boyunca bir an beliren ince hız çizgileri
static func _speed_lines(from: Vector3, to: Vector3) -> void:
	var dv = to - from
	dv.y = 0.0
	if dv.length() < 0.5:
		return
	var side = dv.normalized().cross(Vector3.UP)
	var m = _mat("rib_add", {"core_col": Color(1, 1, 1, 0.8), "edge_col": Color(0.7, 0.85, 0.7, 0.3), "edge_w": 0.5})
	var ln = []
	for i in 7:
		ln.append({"o": side * randf_range(-0.7, 0.7) + Vector3.UP * randf_range(0.25, 1.7), "w": randf_range(0.015, 0.035)})
	var fn = func(age):
		var k = clampf(age / 0.22, 0.0, 1.0)
		var out = []
		for q in ln:
			var a = from.lerp(to, k * 0.9) + Vector3(q["o"])
			var b = to + Vector3(q["o"])
			out.append({"p": _seg(a, b, 8), "w": float(q["w"]), "a": 1.0 - k * 0.6, "tp": 2})
		return out
	_lines(fn, m, 0.22)


## Varışta yerde iki kısa kayma izi + toz
static func _skid(to: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized()
	var m = _mat("rib", {"core_col": Color(0.25, 0.2, 0.15, 0.6), "edge_col": Color(0.35, 0.28, 0.2, 0.3), "edge_w": 0.4, "soft": 0.4})
	for sx in [-1.0, 1.0]:
		var L = []
		var R = []
		for i in 6:
			var u = float(i) / 5.0
			var p = _g(to - d * 1.3 * (1.0 - u) + side * sx * 0.16) - to + Vector3.UP * 0.035
			var w = 0.06 * (0.3 + 0.7 * u)
			L.append(p - side * w)
			R.append(p + side * w)
		var mi = _mi(_strip(L, R), m)
		_put(mi, to)
		_fade(mi, [m], 1.5, 1.0)
	_bits(to + Vector3.UP * 0.1, 6, _rock_mesh(), _rock_mat(Color(0.55, 0.47, 0.36)), _vr(0.5, 1.5, 1.0, 2.5, d * 1.5), {"g": 12.0, "life": 0.7, "size": 0.07})


## Shunshin (j_shunshin oynanışı birebir: nişan yönünde 14 m ya da hedefin 2 m önü, duvara çarpmaz, zemine iner)
static func shunshin(_pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = Jutsu._aim(c, t)
	d.y = 0
	d = d.normalized()
	var from = c.global_position
	var to = from + d * 14.0
	if t:
		to = t.global_position - d * 2.0
	var space = c.get_world_3d().direct_space_state
	var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP, to + Vector3.UP, 1))
	if not hit.is_empty():
		to = hit["position"] - d * 0.8
	to.y = Game.jutsu_floor(to.x, to.z)
	var cols = _look_cols(c)
	_smear(from, cols, to - from, false)
	_leaf_whirl(from + Vector3.UP * 0.1, 12)
	c.global_position = to
	_smear(to, cols, from - to, true)
	_leaf_whirl(to + Vector3.UP * 0.1, 8)
	_speed_lines(from, to)
	_skid(to, d)
	Sfx.play("whoosh", to, 1.4)


## Klon yanılsama titremesi: birkaç kare görünüp kaybolur, sonra oturur; çevresinden yatay beyaz çakra şeritleri savrulup
## dağılır (referans: Tobirama'nın klonlarını saran şeritler)
static func _clone_shimmer(cl: Node3D, side: Vector3) -> void:
	var w = weakref(cl)
	var flick = func(_n, _dt, age) -> bool:
		var x = w.get_ref()
		if x == null or not is_instance_valid(x):
			return false
		if age > 0.32:
			x.visible = true
			return false
		x.visible = int(age / 0.045) % 2 == 0
		return true
	_host(flick)
	var cpos = cl.global_position
	var sd = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var m = _mat("rib", {"core_col": Color(0.97, 0.97, 0.95, 0.9), "edge_col": Color(0.6, 0.62, 0.66, 0.9), "edge_w": 0.3, "soft": 0.1})
	var fn = func(age):
		var k = age / 0.6
		var out = []
		for j in 6:
			var h = 0.35 + j * 0.3
			var r = 0.7 + 0.25 * (j % 3)
			var a0 = j * 1.1 + age * 5.0 * (1.0 if j % 2 == 0 else -1.0)
			var pts = []
			for q in 9:
				var u = float(q) / 8.0
				var ang = a0 + u * 1.6
				pts.append(cpos + Vector3(cos(ang) * r * (1.0 + k * 0.8), h + u * 0.25 + k * 0.4, sin(ang) * r * (1.0 + k * 0.8)) + sd * k * 0.6)
			out.append({"p": pts, "w": 0.07 * (1.0 - k * 0.5), "a": maxf(0.0, 1.0 - k), "tp": 1})
		return out
	_lines(fn, m, 0.6)


## Kage Bunshin (j_bunshin oynanışı birebir: iki yanda iki gölge klon, ayrı karelerde kurulur)
static func bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	for i in 2:
		if i > 0:   # iki gövde aynı karede kurulmasın (ilk atışta takılma)
			await pj.get_tree().process_frame
			await pj.get_tree().process_frame
			if not is_instance_valid(c):
				return
		var off = c.global_transform.basis.x * (2.5 if i == 0 else -2.5)
		var cl = ShadowClone.new()
		cl.team = c.team
		cl.look = c.model.look.duplicate()
		pj.get_tree().current_scene.add_child(cl)
		cl.global_position = c.global_position + off
		_clone_shimmer(cl, off)
	Hud.msg("Kage Bunshin no Jutsu!", Color(1, 1, 1))
