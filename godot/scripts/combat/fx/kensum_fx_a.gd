class_name KensumFXA
extends RefCounted
## Kenjutsu + kuchiyose A: Oborozukiyo, Kabutowari: Hakai, Shibuki Happa Rokujūshi, Ura Kasumigiri, Kusanagi Sora no Tachi,
## Hiken Fūsetsugiri, Zōfuku Kuchiyose, Yatai Kuzushi, Gamaguchi Shibari, Gama Mise, Gyaku Kuchiyose, Edo Tensei, Sanjū Rashōmon.
## Kenjutsu: temiz kenarlı kılıç yayı lekesi (koyu dış çizgi), hız çizgisi, kesik parıltısı, toz — her tekniğin sahnesi ayrı.
## Kuchiyose: oyunun GERÇEK çağrıları (Summon, SummonModels dev kurbağa, GamaMise, Edo tabutu + EdoWarrior, Rashōmon kapısı);
## bu dosya yalnız kendini yazan mürekkep formülünü, kendi cel "pof" bulutunu, iniş darbesini ve tozu üretir.
## Hazır / ortak görsel yok; hepsi bu dosyanın kendi gölgelendiricileri ve şekilleri. Kameraya yakın kısımlar söner.

static var _c := {}

const G := 20.0
const INK := Color(0.05, 0.04, 0.05)
const EARTH := Color(0.5, 0.42, 0.33)
const DUST := Color(0.82, 0.74, 0.6, 0.9)

# ================================================================== gölgelendiriciler
## Köşe rengi x tint (çizgi, kıvılcım, çatlak, kurdele); kameraya yakın söner
const INK_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 c = COLOR * tint;
	ALBEDO = c.rgb;
	ALPHA = clamp(c.a * fade * smoothstep(1.2, 3.4, -VERTEX.z), 0.0, 1.0);
}
"""

## Kılıç yayı lekesi: UV.x yay boyu (tail..head görünür), UV.y iç(0)-dış(1); dış kenarda renkli bant + koyu kontur, iç kenar yumuşak
const SMEAR_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float head = 1.0;
instance uniform float tail = 0.0;
instance uniform float fade = 1.0;
instance uniform float hair = 0.0;
instance uniform vec4 core_col : source_color = vec4(1.0);
instance uniform vec4 edge_col : source_color = vec4(0.55, 0.65, 0.9, 1.0);
void fragment() {
	if (UV.x > head || UV.x < tail) {
		discard;
	}
	float k = clamp((UV.x - tail) / max(head - tail, 0.001), 0.0, 1.0);
	float outl = step(0.92, UV.y);
	float band = step(0.64, UV.y) * (1.0 - outl);
	float streak = step(0.88, fract(UV.y * 5.0 + UV.x * 0.37)) * (1.0 - step(0.64, UV.y)) * hair;
	vec3 col = mix(core_col.rgb, edge_col.rgb, max(band, streak));
	col = mix(col, edge_col.rgb * 0.22, outl);
	ALBEDO = col;
	float a = mix(core_col.a, 1.0, max(band, outl)) * smoothstep(0.0, 0.22, UV.y);
	a *= mix(0.2, 1.0, smoothstep(0.0, 0.45, k));
	ALPHA = clamp(a * fade * smoothstep(1.2, 3.4, -VERTEX.z), 0.0, 1.0);
}
"""

## Cel bulut topağı (pof bulutu, toz, sis, asit kabarcığı): dünya normaline göre iki ton, siluette koyu kontur
const CLOUD_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform vec4 hi_col : source_color = vec4(1.0);
instance uniform vec4 lo_col : source_color = vec4(0.72, 0.72, 0.8, 1.0);
varying vec3 wn;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float l = dot(wn, normalize(vec3(0.25, 1.0, 0.3)));
	vec3 col = mix(lo_col.rgb, hi_col.rgb, step(0.05, l));
	float f = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	col = mix(col, lo_col.rgb * 0.3, step(f, 0.17));
	ALBEDO = col;
	ALPHA = clamp(hi_col.a * fade * smoothstep(1.2, 3.4, -VERTEX.z), 0.0, 1.0);
}
"""

## Katı cel nesne (taş, buz kristali, kurdele bıçağı): iki ton + parlak tepe + siluet konturu
const CEL_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, blend_mix;
instance uniform float fade = 1.0;
instance uniform vec4 base : source_color = vec4(0.5, 0.45, 0.4, 1.0);
varying vec3 wn;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float l = dot(wn, normalize(vec3(0.35, 1.0, 0.25)));
	vec3 col = mix(base.rgb * 0.6, base.rgb, step(0.0, l));
	col = mix(col, min(base.rgb * 1.25, vec3(1.0)), step(0.8, l));
	float f = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	col = mix(col, vec3(0.06, 0.05, 0.06), step(f, 0.22));
	ALBEDO = col;
	ALPHA = clamp(base.a * fade * smoothstep(0.8, 2.4, -VERTEX.z), 0.0, 1.0);
}
"""

## Kılıç ardıl görüntüsü (Oborozukiyo halkası): gri-çelik saydam, kenarı koyu
const GHOST_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	float f = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	vec3 col = mix(vec3(0.28, 0.33, 0.46), vec3(0.76, 0.82, 0.94), step(0.3, f));
	ALBEDO = col;
	ALPHA = clamp(0.72 * fade * smoothstep(1.0, 3.0, -VERTEX.z), 0.0, 1.0);
}
"""

## Düz halka (şok dalgası / yanık iz): prog yarıçap, width bant, fill iç dolgu; dış kenarda koyu dudak
const RING_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.2;
instance uniform float width = 0.12;
instance uniform float fade = 1.0;
instance uniform float fill = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float band = step(prog - width, r) * step(r, prog);
	float lip = step(prog - width * 0.25, r) * band;
	float inner = step(r, prog - width) * fill;
	vec3 col = mix(tint.rgb, tint.rgb * 0.3, lip);
	ALBEDO = mix(tint.rgb * 0.35, col, band);
	ALPHA = clamp(max(band * tint.a, inner * 0.55) * fade * smoothstep(1.2, 3.4, -VERTEX.z), 0.0, 1.0);
}
"""

## Kendini yazan mürekkep formülü (zemin). mode 0: avuçtan ışınsal yazı çizgileri, 1: Edo formülü (pürüzlü halkalar,
## iki mühür dairesi, ortada açılan kara çukur), 2: Rashōmon (kare mühür + kalın ışınlar), 3: Zōfuku (ışınlar + 3 büyüme halkası)
const SEAL_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 1.0;
instance uniform float fade = 1.0;
instance uniform float mode = 0.0;
instance uniform float seed = 0.0;
instance uniform float pit = 0.0;
instance uniform vec4 glow_col : source_color = vec4(1.0, 0.6, 0.2, 1.0);
const vec3 INKC = vec3(0.045, 0.035, 0.05);

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float sgm(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return 1.0 - smoothstep(w * 0.55, w, length(pa - ba * h));
}
float glyph(vec2 g, float id) {
	if (g.x < 0.0 || g.x > 1.0 || g.y < 0.0 || g.y > 1.0) {
		return 0.0;
	}
	float v = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float r1 = h21(vec2(id, fi + 0.5));
		float r2 = h21(vec2(fi + 1.3, id));
		float r3 = h21(vec2(id + fi, 9.1));
		vec2 a = vec2(0.0);
		vec2 b = vec2(0.0);
		if (r1 < 0.5) {
			a = vec2(0.15 + 0.2 * r3, 0.12 + 0.76 * r2);
			b = vec2(0.85 - 0.25 * r3 * r2, a.y + (r3 - 0.5) * 0.15);
		} else {
			a = vec2(0.12 + 0.76 * r2, 0.12 + 0.2 * r3);
			b = vec2(a.x + (r3 - 0.5) * 0.2, 0.88 - 0.3 * r3 * r2);
		}
		v = max(v, sgm(g, a, b, 0.11));
	}
	return v;
}
float ring_line(float r, float rr, float ang, float w, float s) {
	float wob = (vn(vec2(ang * 7.0 + s, rr * 13.0)) - 0.5) * 0.03;
	float hairy = (vn(vec2(ang * 90.0 + s, rr * 40.0)) - 0.5) * w * 0.9;
	return 1.0 - smoothstep(w * 0.5, w, abs(r - rr + wob) + hairy);
}
float band_glyphs(float r, float a01, float r0, float r1, float n, float s) {
	float gx = fract(a01 * n);
	float gy = (r - r0) / (r1 - r0);
	float id = floor(a01 * n);
	return glyph(vec2(gx * 1.2 - 0.1, gy), id + s) * step(0.25, h21(vec2(id, s)));
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float a01 = fract(ang / 6.28318 + 0.25 + seed * 0.13);
	float ink = 0.0;
	float rev = r;
	if (mode < 0.5 || mode > 2.5) {
		float n = mode > 2.5 ? 12.0 : 9.0;
		float sect = floor(a01 * n);
		float ca = (sect + 0.5) / n;
		float da = (a01 - ca) * 6.28318 * r;
		float reach = mode > 2.5 ? 0.96 : 0.62 + 0.36 * h21(vec2(seed, sect));
		float inside = step(r, reach) * step(0.07, r);
		float bend = (vn(vec2(r * 6.0, sect + seed)) - 0.5) * 0.03;
		float ln = (1.0 - smoothstep(0.008, 0.016, abs(da + bend))) * inside;
		vec2 g = vec2((da - 0.014) / 0.07, fract(r * 9.0));
		float gid = floor(r * 9.0);
		float gl = glyph(g, sect * 13.0 + gid + seed) * inside * step(0.14, r) * step(0.35, h21(vec2(gid, sect)));
		ink = max(ln, gl);
		ink = max(ink, ring_line(r, 0.075, ang, 0.018, seed));
		if (mode > 2.5) {
			ink = max(ink, ring_line(r, 0.42, ang, 0.014, seed));
			ink = max(ink, ring_line(r, 0.68, ang, 0.014, seed + 2.0));
			ink = max(ink, ring_line(r, 0.94, ang, 0.018, seed + 4.0));
			ink = max(ink, band_glyphs(r, a01, 0.71, 0.8, 30.0, seed));
		}
	} else if (mode < 1.5) {
		ink = ring_line(r, 0.3, ang, 0.022, seed);
		ink = max(ink, ring_line(r, 0.36, ang, 0.012, seed + 1.0));
		ink = max(ink, ring_line(r, 0.58, ang, 0.016, seed + 2.0) * step(0.15, fract(a01 * 3.0 + 0.1)));
		ink = max(ink, ring_line(r, 0.72, ang, 0.012, seed + 3.0) * step(0.35, fract(a01 * 2.0)));
		ink = max(ink, ring_line(r, 0.86, ang, 0.012, seed + 4.0) * step(0.55, fract(a01 * 2.0 + 0.3)));
		for (int i = 0; i < 2; i++) {
			float sa = 6.28318 * (0.2 + 0.45 * float(i)) + seed;
			vec2 sc = vec2(cos(sa), sin(sa)) * 0.47;
			float d2 = length(q - sc);
			ink = max(ink, ring_line(d2, 0.12, atan(q.y - sc.y, q.x - sc.x), 0.016, seed + float(i) * 5.0));
			ink = max(ink, glyph((q - sc) / 0.15 + 0.5, seed + float(i) * 7.0));
		}
		rev = a01 * 0.75 + r * 0.25;
		ink = max(ink, 1.0 - smoothstep(pit * 0.27 - 0.012, pit * 0.27, r));
	} else {
		float sq = max(abs(q.x), abs(q.y));
		ink = 1.0 - smoothstep(0.02, 0.035, abs(sq - 0.62 + (vn(q * 20.0 + seed) - 0.5) * 0.02));
		ink = max(ink, ring_line(r, 0.92, ang, 0.03, seed));
		ink = max(ink, ring_line(r, 0.84, ang, 0.012, seed + 1.0));
		float sect2 = floor(a01 * 8.0);
		float da2 = (a01 - (sect2 + 0.5) / 8.0) * 6.28318 * r;
		ink = max(ink, (1.0 - smoothstep(0.022, 0.036, abs(da2))) * step(0.12, r) * step(r, 0.84));
		ink = max(ink, band_glyphs(r, a01, 0.66, 0.8, 24.0, seed));
		ink = max(ink, ring_line(r, 0.1, ang, 0.03, seed + 3.0));
	}
	float shown = step(rev, prog);
	float front = shown * (1.0 - smoothstep(0.0, 0.07, prog - rev));
	ink = clamp(ink, 0.0, 1.0) * shown;
	ALBEDO = mix(INKC, glow_col.rgb, front * 0.85);
	ALPHA = clamp(ink * fade * smoothstep(1.0, 3.0, -VERTEX.z), 0.0, 1.0);
}
"""

## Dolunay diski (Oborozukiyo): soluk mavi-beyaz, benekli kraterler, ince koyu kenar + yumuşak hale
const MOON_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float disc = 1.0 - smoothstep(0.66, 0.68, r);
	float halo = (1.0 - smoothstep(0.68, 1.0, r)) * (1.0 - disc);
	float m = vn(q * 3.2 + seed) * 0.6 + vn(q * 7.5 + seed * 2.0) * 0.4;
	vec3 col = mix(vec3(0.94, 0.97, 1.0), vec3(0.6, 0.72, 0.87), step(0.56, m));
	col = mix(col, vec3(0.4, 0.5, 0.68), step(0.645, r) * disc);
	ALBEDO = mix(vec3(0.82, 0.89, 1.0), col, disc);
	float a = disc * 0.6 + halo * halo * 0.28;
	ALPHA = clamp(a * fade * smoothstep(2.0, 5.0, -VERTEX.z), 0.0, 1.0);
}
"""

## Kurbağa midesi: nefes alan etli duvar, üç ton pembe-kırmızı, koyu damar çizgileri
const FLESH_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_mix;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
varying vec3 wp;
varying vec3 wn;
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	VERTEX += NORMAL * sin(TIME * 2.4 + VERTEX.y * 1.3 + seed) * 0.06;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float l = abs(dot(wn, normalize(vec3(0.3, 0.9, 0.2))));
	vec3 col = l > 0.55 ? vec3(0.93, 0.6, 0.6) : (l > 0.2 ? vec3(0.74, 0.32, 0.34) : vec3(0.45, 0.1, 0.13));
	col = mix(col, vec3(0.74, 0.32, 0.34), 0.35 * vn(wp.xz * 0.6 + vec2(wp.y * 0.9, seed)));
	float vein = 1.0 - smoothstep(0.0, 0.035, abs(vn(wp.xz * 0.9 + wp.yy * 0.7 + seed) - 0.5));
	col = mix(col, vec3(0.35, 0.06, 0.1), vein * 0.8);
	ALBEDO = col;
	ALPHA = clamp(fade * smoothstep(0.8, 2.6, -VERTEX.z), 0.0, 1.0);
}
"""


# ================================================================== altyapı
static func _mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if _c.has(k):
		return _c[k]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_c[k] = m
	return m


static func _ink() -> ShaderMaterial:
	return _mat("ink", INK_SH)


static func _gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _put(pj, n: Node3D, p: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = p
	return n


static func _pf(mi: GeometryInstance3D, pname: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(pname, v)


static func _pc(mi: GeometryInstance3D, pname: String) -> Callable:
	return func(v: Color) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(pname, v)


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


## Yerel -Z → mid (yayın ortası), yerel +Y → n (yay düzleminin normali)
static func _plane_basis(mid: Vector3, n: Vector3) -> Basis:
	var y = n.normalized()
	var m = mid - y * mid.dot(y)
	if m.length() < 0.01:
		m = _perp(y)
	m = m.normalized()
	var z = -m
	return Basis(y.cross(z), y, z)


static func _cam_axes(pj) -> Array:
	var cam = pj.get_viewport().get_camera_3d()
	if cam:
		return [cam.global_basis.x, cam.global_basis.y, cam.global_position]
	return [Vector3.RIGHT, Vector3.UP, Vector3.ZERO]


static func _face_cam(pj, n: Node3D) -> void:
	var ax = _cam_axes(pj)
	var to: Vector3 = ax[2] - n.global_position
	if to.length() > 0.01:
		var sc = n.scale
		_orient(n, to)
		n.scale = sc


static func _rand_dir(up_min := -1.0, up_max := 1.0) -> Vector3:
	return Vector3(randf_range(-1, 1), randf_range(up_min, up_max), randf_range(-1, 1)).normalized()


static func _slowmo(pj, s: float, real_dur: float) -> void:
	if Combat.base_time_scale < 0.99:
		return
	Combat.base_time_scale = s
	Engine.time_scale = s
	pj.get_tree().create_timer(real_dur, true, false, true).timeout.connect(func():
		if absf(Combat.base_time_scale - s) < 0.001:
			Combat.base_time_scale = 1.0)


# ------------------------------------------------------------------ şekiller
static func _sphere() -> SphereMesh:
	if not _c.has("mesh:lump"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 12
		s.rings = 7
		_c["mesh:lump"] = s
	return _c["mesh:lump"]


static func _rock_mesh() -> SphereMesh:
	if not _c.has("mesh:rock"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 0.8
		s.radial_segments = 5
		s.rings = 3
		_c["mesh:rock"] = s
	return _c["mesh:rock"]


static func _plane() -> PlaneMesh:
	if not _c.has("mesh:plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2, 2)
		_c["mesh:plane"] = p
	return _c["mesh:plane"]


static func _quad() -> QuadMesh:
	if not _c.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_c["mesh:quad"] = q
	return _c["mesh:quad"]


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, cc: Vector3, ca: Color, cb: Color, ccol: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(ccol)
	st.add_vertex(cc)


## İğ: z=0 önde opak sivri uç, en geniş z=0.18, z=1 arkada sönük kuyruk (hız çizgisi, parıltı kolu)
static func _spindle() -> ArrayMesh:
	if _c.has("mesh:spindle"):
		return _c["mesh:spindle"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cf = Color(1, 1, 1, 1)
	var cm = Color(1, 1, 1, 0.95)
	var cb = Color(1, 1, 1, 0.0)
	var r = []
	for i in 4:
		var a = i * TAU / 4.0
		r.append(Vector3(cos(a) * 0.5, sin(a) * 0.5, 0.18))
	for i in 4:
		_tri(st, Vector3.ZERO, r[i], r[(i + 1) % 4], cf, cm, cm)
		_tri(st, r[i], Vector3(0, 0, 1), r[(i + 1) % 4], cm, cb, cm)
	_c["mesh:spindle"] = st.commit()
	return _c["mesh:spindle"]


## Düz baklava (kar tanesi): XY düzleminde, ortası açık kenarı buz mavisi
static func _diamond() -> ArrayMesh:
	if _c.has("mesh:diamond"):
		return _c["mesh:diamond"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cc = Color(1, 1, 1, 1)
	var ce = Color(0.55, 0.78, 0.98, 1)
	var pts = [Vector3(0, 0.5, 0), Vector3(0.28, 0, 0), Vector3(0, -0.5, 0), Vector3(-0.28, 0, 0)]
	for i in 4:
		_tri(st, Vector3.ZERO, pts[i], pts[(i + 1) % 4], cc, ce, ce)
	_c["mesh:diamond"] = st.commit()
	return _c["mesh:diamond"]


## Kül / mühür kâğıdı pulu (Edo kurbanı): düzensiz beşgen, açık gri iç, koyu kenar
static func _chip(i: int) -> ArrayMesh:
	var key = "mesh:chip_%d" % (i % 4)
	if _c.has(key):
		return _c[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 91 + i % 4
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ci = Color(0.86, 0.84, 0.82, 1)
	var ce = Color(0.18, 0.16, 0.17, 1)
	var pts = []
	for k in 5:
		var a = k * TAU / 5.0 + rng.randf_range(-0.3, 0.3)
		pts.append(Vector3(cos(a), sin(a), 0) * rng.randf_range(0.35, 0.55))
	for k in 5:
		_tri(st, Vector3.ZERO, pts[k], pts[(k + 1) % 5], ci, ci.lerp(ce, 0.7), ci.lerp(ce, 0.7))
	_c[key] = st.commit()
	return _c[key]


## Yay bandı: açı a → (sin a, 0, -cos a) (a=0 yerel -Z); profile 0 hilal, 1 süpürme (başa doğru kalınlaşır), 2 düz
static func _arc_mesh(r: float, w: float, a0: float, a1: float, profile: int, seg := 26) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_in = Vector3.ZERO
	var prev_out = Vector3.ZERO
	var prev_u = 0.0
	for i in seg + 1:
		var u = float(i) / seg
		var a = lerpf(a0, a1, u)
		var wid = w
		if profile == 0:
			wid = w * pow(sin(PI * u), 0.7)
		elif profile == 1:
			wid = w * (0.15 + 0.85 * pow(u, 0.7))
		var dir = Vector3(sin(a), 0, -cos(a))
		var p_out = dir * r
		var p_in = dir * maxf(0.02, r - maxf(wid, 0.004))
		if i > 0:
			st.set_color(Color.WHITE)
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


## Kırık çizgi şeridi (XZ düzleminde, uca doğru incelir)
static func _strip(st: SurfaceTool, pts: Array, w0: float, col: Color) -> void:
	for j in pts.size() - 1:
		var a: Vector3 = pts[j]
		var b: Vector3 = pts[j + 1]
		var dir = b - a
		dir.y = 0
		if dir.length() < 0.001:
			continue
		var s = Vector3(-dir.z, 0, dir.x).normalized()
		var wa = w0 * (1.0 - float(j) / (pts.size() - 1))
		var wb = w0 * (1.0 - float(j + 1) / (pts.size() - 1)) + 0.004
		_tri(st, a - s * wa, a + s * wa, b + s * wb, col, col, col)
		_tri(st, a - s * wa, b + s * wb, b - s * wb, col, col, col)


# ================================================================== yapı taşları
static func _line(pj, mesh: Mesh, p: Vector3, d: Vector3, w: float, l: float, col: Color) -> MeshInstance3D:
	var mi = _gi(mesh, _ink())
	_put(pj, mi, p)
	_orient(mi, d)
	mi.scale = Vector3(w, w, maxf(l, 0.01))
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


## Kılıç yayı lekesi: baş hızla yay boyunca koşar, kuyruk peşinden kapanır
static func _smear(pj, at: Vector3, mid: Vector3, n: Vector3, r: float, w: float, a0: float, a1: float, life: float, core: Color, edge: Color, hair := 0.0, profile := 0) -> MeshInstance3D:
	var mi = _gi(_arc_mesh(r, w, deg_to_rad(a0), deg_to_rad(a1), profile), _mat("smear", SMEAR_SH))
	_put(pj, mi, at)
	mi.global_basis = _plane_basis(mid, n)
	mi.set_instance_shader_parameter("core_col", core)
	mi.set_instance_shader_parameter("edge_col", edge)
	mi.set_instance_shader_parameter("hair", hair)
	mi.set_instance_shader_parameter("head", 0.0)
	mi.set_instance_shader_parameter("tail", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "head"), 0.0, 1.0, life * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "tail"), 0.0, 0.92, life * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Kesik parıltısı: kamera düzleminde 4 uzun + 4 kısa ışın, çıt diye açılıp incelerek söner
static func _glint(pj, p: Vector3, size: float, col: Color, life := 0.26) -> void:
	var ax = _cam_axes(pj)
	var rt: Vector3 = ax[0]
	var up: Vector3 = ax[1]
	var dirs = [rt, -rt, up, -up, (rt + up).normalized(), -(rt + up).normalized(), (rt - up).normalized(), -(rt - up).normalized()]
	var rot = randf_range(-0.4, 0.4)
	var nrm = rt.cross(up).normalized()
	for i in dirs.size():
		var dd: Vector3 = dirs[i].rotated(nrm, rot)
		var L = size * (1.0 if i < 4 else 0.42)
		var w = size * (0.08 if i < 4 else 0.055)
		var mi = _line(pj, _spindle(), p, dd, w, L * 0.2, col)
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(w, w, L), life * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(0.002, 0.002, L * 1.1), life * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


## Dışa fırlayan çizgiler: normal verilirse o düzlemde yelpaze, bias verilirse koni, yoksa küre
static func _burst_lines(pj, p: Vector3, n: int, r0: float, len_: float, life: float, col: Color, w := 0.07, normal := Vector3.ZERO, bias := Vector3.ZERO, spread := 180.0) -> void:
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
			var b = bias.normalized()
			var bu = _perp(b)
			var bv = b.cross(bu)
			var th = deg_to_rad(randf() * spread)
			var ph = randf() * TAU
			d = (b * cos(th) + (bu * cos(ph) + bv * sin(ph)) * sin(th)).normalized()
		else:
			d = _rand_dir()
		var L = len_ * randf_range(0.55, 1.0)
		var ww = w * randf_range(0.7, 1.25)
		var mi = _line(pj, _spindle(), p + d * r0, -d, ww, L * 0.15, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(ww * 0.4, ww * 0.4, L), life * 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", p + d * (r0 + L), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## İçe akan çizgiler (emme / çekilme)
static func _converge(pj, p: Vector3, n: int, r: float, life: float, col: Color, w := 0.06) -> void:
	for i in n:
		var d = _rand_dir(-0.3, 0.8)
		var L = r * randf_range(0.4, 0.7)
		var mi = _line(pj, _spindle(), p + d * r, -d, w, L, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + d * (r * 0.15), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mi, "scale", Vector3(w * 0.5, w * 0.5, L * 0.3), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.35).set_delay(life * 0.65)
		tw.chain().tween_callback(mi.queue_free)


## Hız çizgileri: d boyunca, yarıçapı rad olan bir demette; geriye kayıp söner
static func _speed_lines(pj, p: Vector3, d: Vector3, n: int, len_: float, rad: float, life: float, col: Color, w := 0.05) -> void:
	var dd = d.normalized()
	var u = _perp(dd)
	var v = dd.cross(u)
	for i in n:
		var a = randf() * TAU
		var off = (u * cos(a) + v * sin(a)) * rad * sqrt(randf()) + dd * randf_range(-0.5, 0.5) * len_
		var L = len_ * randf_range(0.5, 1.0)
		var mi = _line(pj, _spindle(), p + off, -dd, w * randf_range(0.6, 1.2), L, col)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + off - dd * len_ * 0.6, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
		tw.chain().tween_callback(mi.queue_free)


static func _lump(pj, p: Vector3, s: Vector3, hi: Color, lo: Color) -> MeshInstance3D:
	var mi = _gi(_sphere(), _mat("cloud", CLOUD_SH))
	_put(pj, mi, p)
	mi.scale = s
	mi.set_instance_shader_parameter("hi_col", hi)
	mi.set_instance_shader_parameter("lo_col", lo)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


## Kuchiyose "pof" bulutu (anime: beyaz, kabarık, gri alt gölgeli, konturlu topaklar): bir anda şişer, dağılıp söner
static func _pop(pj, p: Vector3, size: float, hi := Color(1, 1, 1, 0.97), lo := Color(0.72, 0.72, 0.8, 1), n := 9, life := 1.1) -> void:
	var core = _lump(pj, p, Vector3.ONE * size * 0.12, hi, lo)
	var tc = core.create_tween().set_parallel()
	tc.tween_property(core, "scale", Vector3.ONE * size * 0.95, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tc.tween_property(core, "global_position", p + Vector3.UP * size * 0.2, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tc.tween_method(_pf(core, "fade"), 1.0, 0.0, life * 0.4).set_delay(life * 0.45)
	tc.chain().tween_callback(core.queue_free)
	for i in n:
		var dir = _rand_dir(-0.35, 1.0)
		var s0 = size * randf_range(0.42, 0.68)
		var q1 = p + dir * size * randf_range(0.5, 0.75) + Vector3.UP * size * 0.12
		var mi = _lump(pj, p + dir * size * 0.2, Vector3.ONE * s0 * 0.15, hi, lo)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3.ONE * s0, 0.14 + i * 0.006).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", q1, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * s0 * 1.18, life * 0.45).set_delay(life * 0.55)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.45).set_delay(life * 0.5 + randf() * 0.08)
		tw.chain().tween_callback(mi.queue_free)
	for i in 4:   # kopan küçük kıvrımlar
		var dir = _rand_dir(0.1, 1.0)
		var s1 = size * 0.16
		var mi = _lump(pj, p + dir * size * 0.5, Vector3.ONE * s1, hi, lo)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + dir * size * 1.15, life * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.02, life * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
	_burst_lines(pj, p, 8, size * 0.6, size * 0.7, 0.3, Color(0.95, 0.95, 1.0, 0.9), 0.08 * size, Vector3.ZERO, Vector3.UP, 80.0)


## Zemin tozu: yassı topaklar ışınsal olarak yuvarlanıp söner
static func _dust(pj, p: Vector3, r: float, n: int, col: Color, life := 1.0) -> void:
	for i in n:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / n
		var dir = Vector3(cos(a), 0, sin(a))
		var s0 = r * randf_range(0.2, 0.32)
		var mi = _lump(pj, p + dir * r * 0.25 + Vector3.UP * s0 * 0.2, Vector3(s0, s0 * 0.6, s0) * 0.4, col, col.darkened(0.28))
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + dir * r + Vector3.UP * s0 * 0.45, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(s0 * 1.3, s0 * 0.85, s0 * 1.3), life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Sis: yarı saydam, yassı, yavaş açılan katmanlar (kaybolma / belirme)
static func _mist(pj, p: Vector3, r: float, n: int, life: float, col := Color(0.88, 0.91, 0.98, 0.5)) -> void:
	for i in n:
		var dir = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.5), randf_range(-1, 1)).normalized()
		var s0 = r * randf_range(0.5, 0.8)
		var mi = _lump(pj, p + dir * r * 0.3, Vector3(s0, s0 * 0.45, s0) * 0.5, col, col.darkened(0.12))
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + dir * r * 1.1 + Vector3.UP * 0.2, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(s0 * 1.4, s0 * 0.5, s0 * 1.4), life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
		tw.chain().tween_callback(mi.queue_free)


## Zemin şok halkası
static func _ring(pj, p: Vector3, r: float, life: float, col: Color, width := 0.12, fill := 0.0) -> void:
	var mi = _gi(_plane(), _mat("ring", RING_SH))
	_put(pj, mi, p + Vector3.UP * 0.05)
	mi.scale = Vector3(r, 1, r)
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("width", width)
	mi.set_instance_shader_parameter("fill", fill)
	mi.set_instance_shader_parameter("prog", 0.1)
	mi.set_instance_shader_parameter("fade", 1.0)
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(_pf(mi, "prog"), 0.1, 0.98, life * 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
	tw.chain().tween_callback(mi.queue_free)


## Işınsal yer çatlakları: kırık kollar + dallar, bir anda açılır, bekler, söner
static func _cracks(pj, p: Vector3, r: float, n: int, hold: float) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w0 = 0.09 * clampf(r / 4.0, 0.6, 2.0)
	for i in n:
		var a = TAU * (i + randf_range(-0.35, 0.35)) / n
		var L = r * randf_range(0.5, 1.0)
		var pts = [Vector3.ZERO]
		var cur = Vector3.ZERO
		for k in 5:
			var aa = a + randf_range(-0.5, 0.5)
			cur += Vector3(cos(aa), 0, sin(aa)) * L / 5.0
			pts.append(cur)
		_strip(st, pts, w0, Color(1, 1, 1, 1))
		if randf() < 0.6:
			var bp: Vector3 = pts[2]
			var ba = a + randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0)
			_strip(st, [bp, bp + Vector3(cos(ba), 0, sin(ba)) * L * 0.25, bp + Vector3(cos(ba + 0.3), 0, sin(ba + 0.3)) * L * 0.4], w0 * 0.6, Color(1, 1, 1, 1))
	var mi = _gi(st.commit(), _ink())
	_put(pj, mi, pj.gp(p) + Vector3.UP * 0.04)
	mi.set_instance_shader_parameter("tint", Color(0.09, 0.07, 0.06, 0.92))
	mi.scale = Vector3(0.1, 1, 0.1)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.7)
	tw.tween_callback(mi.queue_free)


## Düz hat boyunca çatlak (kapı tabanı): a→b kırık çizgi + kısa yan dallar
static func _crack_line(pj, a: Vector3, b: Vector3, w: float, hold: float) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o = pj.gp((a + b) * 0.5)
	var d = b - a
	d.y = 0
	var s = Vector3(-d.z, 0, d.x).normalized()
	var pts = []
	for k in 13:
		var pk = (a - o) + d * (k / 12.0) + s * randf_range(-0.25, 0.25)
		pk.y = 0.0
		pts.append(pk)
	for k in 12:
		_strip(st, [pts[k], pts[k + 1]], w, Color(1, 1, 1, 1))
		if k % 3 == 1:
			var sg = 1.0 if randf() < 0.5 else -1.0
			_strip(st, [pts[k], pts[k] + s * sg * randf_range(0.6, 1.4) + d.normalized() * randf_range(-0.4, 0.4)], w * 0.7, Color(1, 1, 1, 1))
	var mi = _gi(st.commit(), _ink())
	_put(pj, mi, o + Vector3.UP * 0.04)
	mi.set_instance_shader_parameter("tint", Color(0.09, 0.07, 0.06, 0.92))
	var tw = mi.create_tween()
	tw.tween_interval(hold)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.6)
	tw.tween_callback(mi.queue_free)


## Kaya parçaları: balistik yay, dönerek düşer, yerde söner
static func _rocks(pj, p: Vector3, n: int, spd: float, col: Color, size := 1.0, up_min := 0.6, life := 1.0) -> void:
	var floor_y = pj.gp(p).y
	for i in n:
		var v = Vector3(randf_range(-1, 1), randf_range(up_min, 1.5), randf_range(-1, 1)).normalized() * spd * randf_range(0.45, 1.0)
		var s = randf_range(0.12, 0.32) * size
		var mi = _gi(_rock_mesh(), _mat("cel", CEL_SH))
		_put(pj, mi, p)
		mi.scale = Vector3(s, s * randf_range(0.6, 1.0), s * randf_range(0.8, 1.2))
		mi.set_instance_shader_parameter("base", col.lerp(col.darkened(0.3), randf()))
		mi.set_instance_shader_parameter("fade", 1.0)
		var spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var lf = life * randf_range(0.7, 1.1)
		var tw = mi.create_tween()
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(mi):
				var q = p + v * t + Vector3.DOWN * 0.5 * G * t * t
				q.y = maxf(q.y, floor_y + s * 0.3)
				mi.global_position = q
				mi.rotation = spin * t, 0.0, lf, lf)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.3)
		tw.tween_callback(mi.queue_free)


## Kendini yazan mürekkep formülü: yazılır (write) → bekler (hold) → söner (out)
static func _seal(pj, p: Vector3, r: float, mode: int, glow: Color, write: float, hold: float, out := 0.6, yaw := 0.0) -> MeshInstance3D:
	var mi = _gi(_plane(), _mat("seal", SEAL_SH))
	var g = pj.gp(p)
	_put(pj, mi, Vector3(g.x, maxf(g.y, p.y - 0.4), g.z) + Vector3.UP * 0.05)
	mi.scale = Vector3(r, 1, r)
	mi.rotation.y = yaw
	mi.set_instance_shader_parameter("mode", float(mode))
	mi.set_instance_shader_parameter("seed", randf() * 50.0)
	mi.set_instance_shader_parameter("glow_col", glow)
	mi.set_instance_shader_parameter("prog", 0.0)
	mi.set_instance_shader_parameter("pit", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "prog"), 0.0, 1.08, write).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, out)
	tw.tween_callback(mi.queue_free)
	return mi


## Avuç yere iner: küçük çatlak yıldızı, yere yapışık halka, kısa toz
static func _palm_slam(pj, palm: Vector3, col: Color, k: float) -> void:
	_cracks(pj, palm, 1.3 * k, 6, 0.6)
	_ring(pj, palm, 1.6 * k, 0.4, col.lightened(0.2), 0.08)
	_dust(pj, palm, 1.2 * k, 6, DUST, 0.6)
	_burst_lines(pj, palm + Vector3.UP * 0.1, 7, 0.2, 0.7 * k, 0.22, Color(1, 0.95, 0.85, 0.9), 0.05, Vector3.UP)


## Kılıç kesiği vuruşu (eski kesikle aynı hacim ve bilgi) + isabette kendi parıltısı
static func _cut(pj, c: Node3D, at: Vector3, d: Vector3, r: float, id: String, mul: float, extra := {}, glint_col := Color(1, 1, 1, 0.95)) -> Array:
	var info = {"knock": 6.0, "kind": "heavy", "bleed": 3.0}
	info.merge(extra, true)
	var hs = pj.hit(c, at + d * r * 0.6, r * 0.9, pj.inf(c, id, mul, info))
	if not hs.is_empty() and is_instance_valid(hs[0]):
		_glint(pj, hs[0].global_position + Vector3.UP * 1.0, 1.1, glint_col)
	return hs


# ================================================================== KENJUTSU
## Oborozukiyo (Yūgao): havada asılı kalır; kılıcın ardıl görüntüleri ışınsal dizilip dolunay halkası çizer, arkasında soluk bir
## dolunay belirir; sonra ay ışığı sisi içinde hücum edip hilal biçimli tek kesik atar
static func oborozukiyo(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var tt = pj.tg(c, t, 12.0)
	pj._ensure_blade(c, 1.5)
	var d = pj.fwd(c, t)
	var base = c.global_position
	var top = base + Vector3.UP * 2.2
	pj.anim(c, "slash_c", 1.2)
	pj.every(0.62, 1.0 / 60.0, func(_i, k):
		if pj.live(c):
			c.global_position = base.lerp(top, sin(minf(1.0, k * 3.1) * PI * 0.5))
			if c is CharacterBody3D:
				c.velocity = Vector3.ZERO, Callable())
	var wm = CharacterModel.weapon_mesh(pj._held_or(c, "katana"))
	var side = d.cross(Vector3.UP).normalized()
	var center = top + Vector3.UP * 0.95
	# arkadaki dolunay (karakterin arkasında, kılıç halkasıyla eş merkezli)
	var moon = _gi(_quad(), _mat("moon", MOON_SH))
	_put(pj, moon, center - d * 1.4)
	_face_cam(pj, moon)
	moon.scale = Vector3.ONE * 0.4
	moon.set_instance_shader_parameter("seed", randf() * 20.0)
	moon.set_instance_shader_parameter("fade", 0.0)
	var tmo = moon.create_tween().set_parallel()
	tmo.tween_property(moon, "scale", Vector3.ONE * 4.6, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tmo.tween_method(_pf(moon, "fade"), 0.0, 1.0, 0.3)
	tmo.tween_method(_pf(moon, "fade"), 1.0, 0.0, 0.45).set_delay(0.75)
	tmo.chain().tween_callback(moon.queue_free)
	pj.every(1.2, 1.0 / 20.0, func(_i, _k):
		if is_instance_valid(moon):
			_face_cam(pj, moon), Callable())
	var n = 26
	for k in n:
		pj.after(0.12 + k * 0.012, func():
			if not pj.live(c) or wm == null:
				return
			var ang = TAU * k / n
			var out_dir = (side * cos(ang) + Vector3.UP * sin(ang)).normalized()
			var mi = MeshInstance3D.new()
			mi.mesh = wm
			mi.material_override = _mat("ghost", GHOST_SH)
			mi.set_meta("oboro_sword", true)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pj.get_tree().current_scene.add_child(mi)
			mi.global_position = center + out_dir * 0.75
			mi.global_transform.basis = Basis.looking_at(-out_dir, d).scaled(Vector3.ONE * 1.6)
			mi.set_instance_shader_parameter("fade", 1.0)
			var tw = mi.create_tween()
			tw.tween_interval(0.35)
			tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.35)
			tw.tween_callback(mi.queue_free))
	# ay halkası: dikey düzlemde tam tur, ince ay ışığı lekesi
	_smear(pj, center, Vector3.UP, d, 1.5, 0.32, -180.0, 180.0, 0.75, Color(0.92, 0.95, 1.0, 0.75), Color(0.55, 0.65, 0.88), 0.6, 2)
	_smear(pj, center, Vector3.UP, d, 1.95, 0.12, -180.0, 180.0, 0.9, Color(0.85, 0.9, 1.0, 0.45), Color(0.45, 0.52, 0.75), 0.0, 2)
	Sfx.play("whoosh", center, 1.6)
	var aim_p = pj.gp(base + d * 8.0)
	pj.after(0.55, func():
		if not pj.live(c):
			return
		var tp = tt.global_position if tt and pj.live(tt) else aim_p
		var s0 = c.global_position
		var e0 = pj.gp(tp - (tp - s0).normalized() * 1.2)
		var dash = (e0 - s0)
		if dash.length() > 0.1:
			_speed_lines(pj, s0.lerp(e0, 0.5) + Vector3.UP * 1.0, dash.normalized(), 10, maxf(2.0, dash.length() * 0.6), 0.7, 0.35, Color(0.8, 0.86, 1.0, 0.8), 0.06)
		_mist(pj, s0 + Vector3.UP * 0.6, 0.9, 4, 0.8)
		pj.every(0.16, 1.0 / 60.0, func(i, k):
			if pj.live(c):
				c.global_position = s0.lerp(e0, k)
				if i % 3 == 0:
					_mist(pj, c.global_position + Vector3.UP * 0.9, 0.45, 1, 0.5, Color(0.85, 0.9, 1.0, 0.35)), func():
			if pj.live(c):
				var tp2 = tt.global_position if tt and pj.live(tt) else aim_p
				var dd = (tp2 - c.global_position)
				dd.y = 0
				pj.anim(c, "slash_c", 1.7)
				var at = tp2 + Vector3.UP * 1.1
				var dn = dd.normalized()
				# hilal kesik: ortası kalın, uçları sivri, koyu mavi kenarlı ay ışığı
				_smear(pj, at, dn, Vector3.UP + dn.cross(Vector3.UP) * 0.25, 1.8, 0.75, -95.0, 95.0, 0.5, Color(0.97, 0.98, 1.0, 0.95), Color(0.48, 0.58, 0.86), 0.5, 0)
				_glint(pj, at + dn * 1.0, 1.6, Color(0.92, 0.96, 1.0, 1.0), 0.3)
				_cut(pj, c, at, dn, 1.8, "oborozukiyo", 2.2, {"knock": 6.0, "bleed": 3.0}, Color(0.9, 0.95, 1.0, 1.0))))


## Kabutowari: Hakai — balta önce tepeden saplanır (kalın, ağır dikey yay), çekiç hemen ardından aynı yere iner:
## krater, ışınsal çatlak, sıçrayan kaya, alçak toz halkası, ikinci vuruşta metalik çınlama
static func kabutowari_hakai(pj, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 2.5, 10.0 if tt else 2.0)
	pj.busy(c, 0.9)
	Sfx.play("whoosh", c.global_position, 0.8)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var fd = c.face_dir()
		var at = c.global_position + Vector3.UP + fd * 1.1
		var side = fd.cross(Vector3.UP).normalized()
		var g = pj.gp(at)
		# balta: tepeden öne-aşağı kalın süpürme yayı (dikey düzlem)
		_smear(pj, c.global_position + Vector3.UP * 1.1 + fd * 0.2, fd, side, 1.7, 0.6, -80.0, 65.0, 0.32, Color(0.95, 0.96, 1.0, 0.9), Color(0.32, 0.36, 0.46), 0.7, 1)
		_glint(pj, g + Vector3.UP * 0.3, 1.3, Color(1, 0.97, 0.88, 1), 0.2)
		_ring(pj, g, 2.8, 0.55, Color(0.62, 0.52, 0.4, 0.95), 0.18, 1.0)
		_cracks(pj, g, 4.5, 9, 2.2)
		_rocks(pj, g + Vector3.UP * 0.2, 14, 9.0, EARTH, 1.2, 0.8, 1.1)
		_dust(pj, g, 3.2, 10, DUST, 0.9)
		_burst_lines(pj, g + Vector3.UP * 0.3, 12, 0.4, 2.4, 0.25, Color(1, 0.95, 0.85, 0.95), 0.09, Vector3.UP)
		for e in pj.hit(c, at, 2.0, pj.inf(c, "kabutowari_hakai", 2.0, {"knock": 12.0, "kind": "heavy", "stun": 0.8})):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("armor_break", 8.0)
		pj.shake(0.45)
		Sfx.play("boom", at, 1.1)
		# çekiç: aynı noktaya ikinci ağır iniş — daha geniş halka + yukarı fırlayan çelik kıvılcım çizgileri
		pj.after(0.14, func():
			_ring(pj, g, 4.2, 0.5, Color(0.85, 0.82, 0.75, 0.85), 0.07)
			_burst_lines(pj, g + Vector3.UP * 0.5, 9, 0.2, 1.6, 0.22, Color(1.0, 0.9, 0.55, 1.0), 0.05, Vector3.ZERO, Vector3.UP, 55.0)
			_glint(pj, g + Vector3.UP * 0.6, 0.9, Color(1, 0.92, 0.7, 1), 0.18)))


## Shibuki: kılıcın patlayıcı etiketleri savuruşla önüne saçılır; etiketler sırayla tutuşup zincirleme patlar
## (beyaz çekirdek → kalın konturlu turuncu ateş topakları → kararan kurum), yerde yanık halkası
static func shibuki_happa_rokujushi(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	pj.anim(c, "slash_c", 1.3)
	_smear(pj, c.global_position + Vector3.UP * 1.0, d, Vector3.UP, 2.0, 0.55, -75.0, 75.0, 0.4, Color(1.0, 0.97, 0.9, 0.9), Color(0.75, 0.42, 0.18), 0.4, 1)
	var hand = pj.hand_pos(c, true)
	for k in 7:
		var q0 = pj.gp(c.global_position + d * (2.0 + k * 1.8)) + Vector3.UP * 0.6
		_fly_tag(pj, hand, q0, 0.17 + k * 0.08, k)
		pj.after(0.25 + k * 0.08, func():
			var q = pj.gp(c.global_position + d * (2.0 + k * 1.8)) + Vector3.UP * 0.6
			_blast(pj, q, 0.8 + k * 0.06, d)
			pj.hit(c, q, 2.2, pj.inf(c, "shibuki_happa_rokujushi", 0.45, {"knock": 8.0, "launch": 3.0, "kind": "heavy", "element": "bakuton"})))
	Sfx.play("boom", c.global_position, 1.0)


## Patlayıcı etiket kâğıdı: elden hedef noktaya dönerek uçar
static func _fly_tag(pj, from: Vector3, to: Vector3, dur: float, k: int) -> void:
	var key = "mesh:tag"
	if not _c.has(key):
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.12, 0.26, 0.008), Color(0.93, 0.88, 0.74))
		b.add("box", Vector3(0, 0.0, 0.005), Vector3(0.035, 0.2, 0.004), Color(0.75, 0.12, 0.1))
		b.add("box", Vector3(0, 0.1, 0.005), Vector3(0.09, 0.02, 0.004), Color(0.75, 0.12, 0.1))
		_c[key] = b.build(Props.toon())
	var mi = MeshInstance3D.new()
	mi.mesh = _c[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(pj, mi, from)
	var spin = Vector3(randf_range(-8, 8), randf_range(-12, 12), randf_range(-8, 8))
	var lift = 0.6 + (k % 3) * 0.3
	var tw = mi.create_tween()
	tw.tween_method(func(q: float) -> void:
		if is_instance_valid(mi):
			mi.global_position = from.lerp(to, q) + Vector3.UP * sin(q * PI) * lift
			mi.rotation = spin * q, 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)


## Etiket patlaması (yalnız Shibuki): beyaz çekirdek, konturlu ateş topakları kurum rengine döner, kıymık çizgileri, yanık halkası
static func _blast(pj, q: Vector3, s: float, d: Vector3) -> void:
	var g = pj.gp(q)
	var core = _lump(pj, q, Vector3.ONE * 0.2 * s, Color(1, 0.98, 0.82, 1), Color(1, 0.85, 0.4, 1))
	var tc = core.create_tween()
	tc.tween_property(core, "scale", Vector3.ONE * 1.6 * s, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tc.tween_method(_pf(core, "fade"), 1.0, 0.0, 0.14)
	tc.tween_callback(core.queue_free)
	for i in 6:
		var dir = (_rand_dir(-0.1, 1.0) + d * 0.35).normalized()
		var s0 = s * randf_range(0.55, 0.85)
		var mi = _lump(pj, q + dir * 0.2 * s, Vector3.ONE * s0 * 0.2, Color(1.0, 0.74, 0.22, 1), Color(0.88, 0.3, 0.08, 1))
		var q1 = q + dir * s * randf_range(0.7, 1.0)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3.ONE * s0, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", q1, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pc(mi, "hi_col"), Color(1.0, 0.74, 0.22, 1), Color(0.34, 0.3, 0.29, 0.9), 0.35).set_delay(0.12)
		tw.tween_method(_pc(mi, "lo_col"), Color(0.88, 0.3, 0.08, 1), Color(0.18, 0.16, 0.16, 1), 0.35).set_delay(0.12)
		tw.tween_property(mi, "global_position", q1 + Vector3.UP * s * 1.1, 0.6).set_delay(0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "scale", Vector3.ONE * s0 * 0.5, 0.6).set_delay(0.3)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.45).set_delay(0.4)
		tw.chain().tween_callback(mi.queue_free)
	_burst_lines(pj, q, 9, 0.3 * s, 1.8 * s, 0.24, Color(1.0, 0.85, 0.4, 1.0), 0.07, Vector3.ZERO, Vector3.UP, 85.0)
	_ring(pj, g, 1.5 * s, 2.2, Color(0.16, 0.12, 0.1, 0.85), 0.1, 1.0)
	_rocks(pj, g + Vector3.UP * 0.15, 4, 6.0, EARTH, 0.8, 0.8, 0.8)


## Ura Kasumigiri: yerinde soluk sis katmanları açılır, kullanıcı sisin içinde kaybolup hedefin arkasında yeni bir sis
## halkasıyla belirir ve çapraz, ince, keskin tek kesik atar
static func ura_kasumigiri(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 10.0)
	pj._ensure_blade(c, 0.8)
	_mist(pj, c.global_position + Vector3.UP * 0.7, 1.1, 9, 0.9)
	_mist(pj, c.global_position + Vector3.UP * 0.2, 1.6, 5, 1.1, Color(0.84, 0.88, 0.96, 0.4))
	if not tt:
		return
	pj.after(0.2, func():
		if pj.live(c) and pj.live(tt):
			c.global_position = pj.gp(tt.global_position - tt.global_transform.basis.z * -1.4)
			var v = tt.global_position - c.global_position
			c.facing = atan2(-v.x, -v.z)
			var vn = v.normalized()
			var flat = Vector3(v.x, 0, v.z).normalized()
			var at = c.global_position + Vector3.UP
			_mist(pj, c.global_position + Vector3.UP * 0.6, 0.8, 6, 0.6)
			# çapraz düzlemde ince, temiz kesik
			_smear(pj, at, flat, (Vector3.UP + flat.cross(Vector3.UP) * 0.8).normalized(), 1.6, 0.22, -50.0, 50.0, 0.3, Color(1, 1, 1, 0.95), Color(0.5, 0.55, 0.66), 0.0, 0)
			_speed_lines(pj, at + flat * 0.6, flat, 6, 1.6, 0.5, 0.22, Color(0.9, 0.92, 1.0, 0.85), 0.04)
			_cut(pj, c, at, vn, 1.6, "ura_kasumigiri", 1.6, {"stun": 0.4}))
	Sfx.play("whoosh", c.global_position, 1.7)


## Kusanagi: Sora no Tachi — kılıç elden fırlar; çakra ile uzamış soluk mavi parlak bıçak (ref) kendi başına hedefin
## çevresinde döner, arkasında ince bir kurdele iz bırakır; her geçişte kesik parıltısı
static func kusanagi_sora_no_tachi(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 24.0)
	var sword = Node3D.new()
	var b = MB.new()
	b.add("box", Vector3(0, 0, -0.5), Vector3(0.05, 0.012, 1.0), Color(0.88, 0.9, 0.95))
	b.add("box", Vector3(0, 0, 0.05), Vector3(0.14, 0.06, 0.04), Color(0.3, 0.25, 0.2))
	b.add("cyl", Vector3(0, 0, 0.25), Vector3(0.04, 0.35, 0.04), Color(0.15, 0.1, 0.1), Vector3(90, 0, 0), 6)
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	sword.add_child(mi)
	# çakra bıçağı: kılıçtan uzayan parlak çekirdek + yumuşak dış katman
	var gb = MB.new()
	gb.add("box", Vector3(0, 0, -0.85), Vector3(0.07, 0.035, 1.7), Color(1, 1, 1, 1))
	var glow_core = _gi(gb.build(), _ink())
	glow_core.set_instance_shader_parameter("tint", Color(0.92, 0.98, 1.0, 0.95))
	sword.add_child(glow_core)
	var go = MB.new()
	go.add("box", Vector3(0, 0, -0.85), Vector3(0.16, 0.1, 1.8), Color(1, 1, 1, 1))
	var glow_out = _gi(go.build(), _ink())
	glow_out.set_instance_shader_parameter("tint", Color(0.45, 0.72, 1.0, 0.4))
	sword.add_child(glow_out)
	pj.scene_add(sword, pj.hand_pos(c, true))
	_glint(pj, sword.global_position, 0.9, Color(0.85, 0.95, 1.0, 1.0), 0.22)
	# kurdele iz (dünya koordinatlı)
	var im = ImmediateMesh.new()
	var rib = _gi(im, _ink())
	pj.get_tree().current_scene.add_child(rib)
	rib.global_transform = Transform3D.IDENTITY
	rib.set_instance_shader_parameter("tint", Color(0.7, 0.88, 1.0, 0.8))
	var trail = []
	pj.every(2.4, 1.0 / 30.0, func(i, k):
		if not is_instance_valid(sword):
			return
		var center = (tt.global_position + Vector3.UP) if tt and pj.live(tt) else c.global_position + c.face_dir() * 8.0 + Vector3.UP
		var a = k * TAU * 3.0
		var p = center + Vector3(cos(a) * 1.6, sin(k * TAU * 2.0) * 0.6, sin(a) * 1.6)
		if k < 0.15:
			p = sword.global_position.lerp(p, k / 0.15)
		sword.look_at(p + (p - sword.global_position), Vector3.UP)
		sword.global_position = p
		trail.push_front([sword.to_global(Vector3(0, 0, -0.15)), sword.to_global(Vector3(0, 0, -1.6))])
		if trail.size() > 9:
			trail.pop_back()
		if is_instance_valid(rib):
			_ribbon_draw(im, trail)
		if i % 8 == 0 and tt and pj.live(tt):
			_glint(pj, tt.global_position + Vector3.UP + (p - center) * 0.4, 0.8, Color(0.85, 0.95, 1.0, 1.0), 0.2)
			pj.hit(c, tt.global_position + Vector3.UP, tt.radius + 0.5, pj.inf(c, "kusanagi_sora_no_tachi", 0.35, {"knock": 1.0, "kind": "light", "bleed": 2.0})), func():
		if is_instance_valid(sword):
			_glint(pj, sword.global_position, 1.0, Color(0.85, 0.95, 1.0, 1.0), 0.25)
			sword.queue_free()
		if is_instance_valid(rib):
			var tw = rib.create_tween()
			tw.tween_method(_pf(rib, "fade"), 1.0, 0.0, 0.25)
			tw.tween_callback(rib.queue_free))
	Sfx.play("whoosh", c.global_position, 1.6)


static func _ribbon_draw(im: ImmediateMesh, pts: Array) -> void:
	im.clear_surfaces()
	if pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size() - 1
	for i in n:
		var ka = 1.0 - float(i) / n
		var kb = 1.0 - float(i + 1) / n
		var a0: Vector3 = pts[i][0]
		var a1: Vector3 = pts[i][1]
		var b0: Vector3 = pts[i + 1][0]
		var b1: Vector3 = pts[i + 1][1]
		var ca0 = Color(1, 1, 1, ka * ka * 0.3)
		var ca1 = Color(1, 1, 1, ka * ka)
		var cb0 = Color(1, 1, 1, kb * kb * 0.3)
		var cb1 = Color(1, 1, 1, kb * kb)
		im.surface_set_color(ca0)
		im.surface_add_vertex(a0)
		im.surface_set_color(ca1)
		im.surface_add_vertex(a1)
		im.surface_set_color(cb1)
		im.surface_add_vertex(b1)
		im.surface_set_color(ca0)
		im.surface_add_vertex(a0)
		im.surface_set_color(cb1)
		im.surface_add_vertex(b1)
		im.surface_set_color(cb0)
		im.surface_add_vertex(b0)
	im.surface_end()


## Hiken: Fūsetsugiri — kullanıcının çevresinde dönen kar fırtınası (teğet yörüngeli baklava pullar), dört yöne buz mavisi
## kesik yayları; sonunda yerden buz kristalleri çıkar ve donmuş zemin kalır
static func hiken_fusetsugiri(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	pj._ensure_blade(c, 1.1)
	var at = c.global_position + Vector3.UP
	_snow(pj, at, 46, 4.0, 1.2)
	for k in 4:
		pj.after(0.15 + k * 0.15, func():
			if pj.live(c):
				var dk = c.face_dir().rotated(Vector3.UP, k * PI * 0.5)
				var cp = c.global_position + Vector3.UP
				_smear(pj, cp + Vector3.UP * (k % 2) * 0.25, dk, Vector3.UP + dk.cross(Vector3.UP) * (0.3 if k % 2 == 0 else -0.3), 3.0, 0.7, -60.0, 60.0, 0.42, Color(0.92, 0.98, 1.0, 0.85), Color(0.42, 0.68, 0.92), 0.8, 1)
				_cut(pj, c, cp, dk, 3.0, "hiken_fusetsugiri", 0.45, {"element": "hyoton"}, Color(0.85, 0.95, 1.0, 1.0))
				for e in pj.enemies_near(c, c.global_position, 3.4):
					if pj.live(e) and e.has_method("apply_status"):
						e.apply_status("chill", 2.0)
						e.apply_status("slow", 2.0))
	GroundFX.add(c.global_position, "frozen", 3.5, 4.0, c)
	var g = pj.gp(c.global_position)
	pj.after(0.75, func(): _ice_crystals(pj, g, 3.2, 12, 3.2))
	Sfx.play("whoosh", c.global_position, 1.1)


## Kar fırtınası: pullar teğet dönerek dışa açılır, yukarı-aşağı salınır
static func _snow(pj, center: Vector3, n: int, r: float, life: float) -> void:
	for i in n:
		var a0 = randf() * TAU
		var r0 = r * randf_range(0.15, 0.4)
		var r1 = r * randf_range(0.7, 1.05)
		var h0 = randf_range(-0.9, 1.3)
		var spin = randf_range(5.0, 8.0)
		var s = randf_range(0.07, 0.16)
		var mi = _gi(_diamond(), _ink())
		_put(pj, mi, center)
		mi.scale = Vector3.ONE * s
		mi.set_instance_shader_parameter("tint", Color(1, 1, 1, 0.95))
		var rot = Vector3(randf() * TAU, randf() * TAU, 0)
		var lf = life * randf_range(0.75, 1.0)
		var tw = mi.create_tween()
		tw.tween_method(func(q: float) -> void:
			if is_instance_valid(mi):
				var a = a0 + spin * q
				var rr = lerpf(r0, r1, sqrt(q))
				mi.global_position = center + Vector3(cos(a) * rr, h0 + sin(q * 9.0 + a0) * 0.25, sin(a) * rr)
				mi.rotation = rot + Vector3(q * 11.0, q * 7.0, 0), 0.0, 1.0, lf)
		tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, lf * 0.35).set_delay(lf * 0.65)
		tw.tween_callback(mi.queue_free)


## Buz kristalleri: halka üzerinde yerden çıkan ince altıgen sivri buzlar; kalır, sonra yere çekilir
static func _ice_crystals(pj, g: Vector3, r: float, n: int, hold: float) -> void:
	for i in n:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / n
		var rr = r * randf_range(0.55, 1.0)
		var p = pj.gp(g + Vector3(cos(a), 0, sin(a)) * rr)
		var cm = CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.5
		cm.height = 1.0
		cm.radial_segments = 6
		cm.rings = 1
		var mi = _gi(cm, _mat("cel", CEL_SH))
		_put(pj, mi, p)
		var h = randf_range(0.35, 0.9)
		var w = randf_range(0.1, 0.2)
		mi.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		mi.set_instance_shader_parameter("base", Color(0.72, 0.88, 1.0, 0.85))
		mi.set_instance_shader_parameter("fade", 1.0)
		mi.scale = Vector3(w, 0.01, w)
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(w, h, w), 0.12 + randf() * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(hold)
		tw.tween_property(mi, "scale", Vector3(w, 0.01, w), 0.4)
		tw.tween_callback(mi.queue_free)


# ================================================================== KUCHIYOSE
## Zōfuku Kuchiyose: avuçtan çağrının çıkacağı yere kadar yazılan mürekkep (12 ışın + üç büyüme halkası); halkalar kademe kademe
## dışa açılıp büyümeyi anlatır; gerçek çağrı hayvanı kendi cel pof bulutunun içinden çıkar (Contracts.summon akışı aynen)
static func zofuku_kuchiyose_no_jutsu(pj, c: Node3D, _t: Node3D) -> void:
	_summon_contract(pj, c, Data.jutsu.get("zofuku_kuchiyose_no_jutsu", {"id": "zofuku_kuchiyose_no_jutsu"}))


## Contracts.summon ile aynı oynanış (kademe, chakra, eski çağrıyı geri gönderme, yer, sayı, ustalık ölçeği); görsel bu dosyadan
static func _summon_contract(pj, c: Node3D, jd: Dictionary) -> void:
	var tree = c.get_tree()
	var id = "kurbağa"
	var tier = 1
	var giant = String(jd.get("id", "")).begins_with("zofuku")
	if c is Player:
		Contracts.ensure()
		id = Contracts.active()
		if id == "":
			Hud.msg("Hiçbir hayvanla sözleşmen yok. Gizli bilgelerin yerlerini bul ya da köy sözleşme ustalarına danış.", Color(1, 0.7, 0.5))
			return
		tier = Contracts.best_tier(id, c.chakra + float(jd.get("cost", 0)), giant)
		var pref = int(Contracts.p()["contracts"].get(id, {}).get("tier_pref", -1))
		if pref >= 0 and Contracts.DEFS[id]["tiers"].has(pref) and not giant:
			tier = mini(tier, pref)
		if giant and Contracts.DEFS[id]["tiers"].has(2) and int(Contracts.p()["level"]) >= Contracts.TIER_LEVEL[2]:
			tier = 2
		var extra = maxf(0.0, Contracts.TIER_COST[tier] - float(jd.get("cost", 0)))
		c.chakra = maxf(0.0, c.chakra - extra)
		for s in tree.get_nodes_in_group("summons"):
			if s.owner_f == c:
				s.dismiss()
	else:
		id = String(c.get_meta("contract", ["kurbağa", "yılan", "köpek"].pick_random()))
		tier = 1 if Contracts.DEFS[id]["tiers"].has(1) else Contracts.DEFS[id]["tiers"].keys()[0]
		if c.has_meta("contract_tier") and Contracts.DEFS[id]["tiers"].has(int(c.get_meta("contract_tier"))):
			tier = int(c.get_meta("contract_tier"))
	var sd: Dictionary = Contracts.DEFS[id]["tiers"][tier]
	var pos: Vector3
	if c is Player:
		pos = Jutsu._aim_ground(c, null, 3.0 + sd["h"] * 0.4, 6.0 + sd["h"] * 0.6)
	else:
		pos = c.global_position + c.face_dir() * (3.0 + sd["h"] * 0.4)
	pos.y = Game.ground_height(pos.x, pos.z)
	var palm = c.global_position + c.face_dir() * 0.75
	palm.y = Game.ground_height(palm.x, palm.z)
	var col: Color = Contracts.DEFS[id]["color"]
	var h = float(sd["h"])
	var k = clampf(0.6 + h * 0.08, 0.6, 2.5)
	_palm_slam(pj, palm, col, k)
	Sfx.play("earth", palm, 1.3, 0.6)
	if c == Game.player and Game.world:
		Game.world.env.add_shake(0.25 + h * 0.02)
	var reach = maxf(2.6, palm.distance_to(pos) + maxf(1.2, h * 0.45))
	_seal(pj, palm, reach, 3, col, 0.45, 1.5, 0.8)
	# büyüme: üç halka kademe kademe dışa açılır (her biri bir öncekinden büyük)
	for j in 3:
		pj.after(0.12 + j * 0.1, func():
			_ring(pj, pos, maxf(1.6, h * 0.5) * (1.0 + j * 0.55), 0.45, col.lightened(0.25 + j * 0.15), 0.06))
	var count = int(sd.get("count", 1))
	var t0 = tree.create_timer(0.35)
	t0.timeout.connect(func():
		if not is_instance_valid(c):
			return
		var ps = maxf(1.5, h * 0.35)
		_pop(pj, pos + Vector3.UP * h * 0.5, ps * 1.6, Color(1, 1, 1, 0.97), Color(0.74, 0.72, 0.84, 1), 10, 1.0 + h * 0.03)
		_dust(pj, pos, ps * 2.0, 10, DUST, 0.9)
		if Game.world:
			Game.world.env.add_shake(clampf(h * 0.08, 0.1, 2.0))
		Sfx.play("poof" if h < 3.0 else "boom", pos, clampf(1.6 - h * 0.04, 0.5, 1.6))
		for i in count:
			var s = Summon.new()
			s.contract = id
			s.tier = tier
			s.def = sd
			s.owner_f = c
			s.team = c.team
			s.scale_m = 1.0 + clampf(Contracts.mastery(id) / 600.0, 0.0, 0.15)
			tree.current_scene.add_child(s)
			var off = Vector3.ZERO if count == 1 else Vector3(cos(i * TAU / count), 0, sin(i * TAU / count)) * 1.6
			s.global_position = pos + off
			s.facing = c.facing
			if i == 0:
				s.say(sd["lines"].pick_random(), 3.0))


## Yatai Kuzushi: avuç altında küçük formül; gökyüzünde dev pof bulutu açılır, gerçek dev kurbağa (SummonModels toad_boss)
## dikey hız çizgileri içinde düşer; inişte kum seli gibi kabaran toz duvarı, krater, çatlak, kaya; kalkarken yine pof
static func kuchiyose_yatai_kuzushi_no_jutsu(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var orange = Color(1, 0.55, 0.15)
	_palm_slam(pj, pj.gp(c.global_position + c.face_dir() * 0.6), orange, 0.7)
	_seal(pj, c.global_position, 1.6, 0, orange, 0.25, 0.5, 0.4)
	Sfx.play("poof", pj.gp(c.global_position), 0.8)
	var toad: Node3D = SummonModels.build("toad_boss", 9.0, 9.0)["root"]
	pj.get_tree().current_scene.add_child(toad)
	var tf = c.global_position - at
	tf.y = 0
	if tf.length() > 0.1:
		toad.rotation.y = atan2(-tf.x, -tf.z)
	toad.global_position = at + Vector3.UP * 30.0
	_pop(pj, at + Vector3.UP * 32.0, 6.0, Color(1, 1, 1, 0.97), Color(0.74, 0.74, 0.82, 1), 11, 1.2)
	_ring(pj, at, 6.5, 0.75, Color(0.1, 0.08, 0.08, 0.5), 0.5, 1.0)   # büyüyen gölge
	var tw = toad.create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		_speed_lines(pj, at + Vector3.UP * 18.0, Vector3.DOWN, 14, 9.0, 4.5, 0.45, Color(0.95, 0.95, 1.0, 0.7), 0.12))
	tw.tween_property(toad, "global_position", at, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_ring(pj, at, 12.0, 0.7, Color(0.85, 0.78, 0.62, 0.9), 0.08)
		_cracks(pj, at, 12.0, 14, 2.6)
		_dust_billow(pj, at, 7.5, 16)
		_rocks(pj, at + Vector3.UP * 0.4, 20, 13.0, EARTH, 2.0, 0.7, 1.4)
		_burst_lines(pj, at + Vector3.UP * 0.6, 16, 5.0, 4.0, 0.3, Color(1, 0.95, 0.85, 0.9), 0.16, Vector3.UP)
		pj.hit(c, at + Vector3.UP, 7.0, pj.inf(c, "kuchiyose_yatai_kuzushi_no_jutsu", 2.6, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.12}))
		pj.shake(1.5))
	tw.tween_interval(1.4)
	tw.tween_callback(func(): _pop(pj, at + Vector3.UP * 3.0, 6.0, Color(1, 1, 1, 0.97), Color(0.74, 0.74, 0.82, 1), 12, 1.1))
	tw.tween_callback(toad.queue_free)
	Sfx.play("poof", c.global_position, 0.6)


## İnişin kum seli (ref): kalın, kabaran toz duvarı halka hâlinde dışa yuvarlanıp yükselir
static func _dust_billow(pj, at: Vector3, r: float, n: int) -> void:
	for i in n:
		var a = TAU * (i + randf_range(-0.25, 0.25)) / n
		var dir = Vector3(cos(a), 0, sin(a))
		for layer in 2:
			var s0 = r * randf_range(0.28, 0.4) * (1.0 - layer * 0.3)
			var p0 = at + dir * r * 0.45 + Vector3.UP * s0 * (0.3 + layer * 0.6)
			var p1 = at + dir * r * (1.25 + layer * 0.15) + Vector3.UP * s0 * (0.5 + layer * 1.1)
			var col = DUST.lerp(Color(0.9, 0.84, 0.7, 0.92), layer * 0.6)
			var mi = _lump(pj, p0, Vector3(s0, s0 * 0.7, s0) * 0.3, col, col.darkened(0.3))
			var tw = mi.create_tween().set_parallel()
			tw.tween_property(mi, "global_position", p1, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi, "scale", Vector3(s0 * 1.2, s0 * 0.95, s0 * 1.2), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.7).set_delay(0.9)
			tw.chain().tween_callback(mi.queue_free)


## Gamaguchi Shibari: avuç altında küçük formül; hedefin çevresinde yerden etli, damarlı, nefes alan kurbağa midesi yükselir
## (halka kıvrımlar + taban), içindekiler bağlanır; asit kabarcıkları tutulanların üzerinde kaynar
static func kuchiyose_gamaguchi_shibari(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 16.0)
	var center = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 6.0)
	var orange = Color(1, 0.55, 0.15)
	_palm_slam(pj, pj.gp(c.global_position + c.face_dir() * 0.6), orange, 0.7)
	_seal(pj, c.global_position, 2.0, 0, orange, 0.3, 0.6, 0.4)
	Sfx.play("poof", pj.gp(c.global_position), 0.8)
	_stomach(pj, center, 5.5, 7.0)
	pj.shake(0.5)
	Sfx.play("water", center, 0.5)
	pj.every(6.0, 0.5, func(_i, _k):
		for e in pj.enemies_near(c, center, 7.0):
			if not pj.live(e):
				continue
			pj.st(e, "bind", 0.6)
			_bubbles(pj, e.global_position + Vector3.UP * 0.3, 5)
			e.take_hit(pj.inf(c, "kuchiyose_gamaguchi_shibari", 0.12, {"knock": 0.0, "kind": "light"})), Callable())


## Kurbağa midesi tüneli (yalnız Gamaguchi): kendi et gölgelendiricisi, kıvrım halkaları, taban; zeminden yükselip kapanır
static func _stomach(pj, center: Vector3, hold: float, R: float) -> Node3D:
	var flesh = _mat("flesh", FLESH_SH)
	var root = Node3D.new()
	_put(pj, root, center)
	var cm = CylinderMesh.new()
	cm.top_radius = R * 0.86
	cm.bottom_radius = R
	cm.height = 7.0
	cm.radial_segments = 28
	cm.rings = 8
	cm.cap_top = false
	cm.cap_bottom = false
	var tube = _gi(cm, flesh)
	tube.position = Vector3.UP * 3.0
	tube.set_instance_shader_parameter("seed", randf() * 10.0)
	root.add_child(tube)
	for k in 10:
		var tm = TorusMesh.new()
		tm.inner_radius = R * 0.8 + (k % 2) * 0.3
		tm.outer_radius = R * 1.03
		tm.rings = 28
		tm.ring_segments = 8
		var fold = _gi(tm, flesh)
		fold.position = Vector3.UP * (0.3 + k * 0.65)
		fold.scale = Vector3(1, 0.35, 1)
		fold.set_instance_shader_parameter("seed", k * 1.7)
		root.add_child(fold)
	var fm = CylinderMesh.new()
	fm.top_radius = R
	fm.bottom_radius = R
	fm.height = 0.1
	fm.radial_segments = 28
	var floor_m = _gi(fm, flesh)
	root.add_child(floor_m)
	for k in 4:   # tabanda asit gölcükleri
		var pool = _gi(_plane(), _mat("ring", RING_SH))
		var a = randf() * TAU
		pool.position = Vector3(cos(a), 0, sin(a)) * R * randf_range(0.2, 0.6) + Vector3.UP * 0.07
		var pr = randf_range(0.6, 1.3)
		pool.scale = Vector3(pr, 1, pr)
		pool.set_instance_shader_parameter("tint", Color(0.78, 0.88, 0.35, 0.8))
		pool.set_instance_shader_parameter("prog", 0.95)
		pool.set_instance_shader_parameter("width", 0.12)
		pool.set_instance_shader_parameter("fill", 1.0)
		pool.set_instance_shader_parameter("fade", 1.0)
		root.add_child(pool)
	root.scale = Vector3(1, 0.05, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(hold)
	tw.tween_property(root, "scale", Vector3(1, 0.05, 1), 0.4)
	tw.tween_callback(root.queue_free)
	_burst_lines(pj, center + Vector3.UP * 0.3, 14, R * 0.9, 2.0, 0.3, Color(0.9, 0.5, 0.5, 0.9), 0.12, Vector3.UP)
	return root


## Asit kabarcıkları: sarı-yeşil küçük topaklar yükselip patlar
static func _bubbles(pj, p: Vector3, n: int) -> void:
	for i in n:
		var s = randf_range(0.1, 0.22)
		var q0 = p + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.5), randf_range(-0.4, 0.4))
		var mi = _lump(pj, q0, Vector3.ONE * s * 0.3, Color(0.86, 0.95, 0.45, 0.85), Color(0.55, 0.68, 0.2, 1))
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * s, 0.15 + randf() * 0.1)
		tw.parallel().tween_property(mi, "global_position", q0 + Vector3.UP * randf_range(0.3, 0.6), 0.4)
		tw.tween_property(mi, "scale", Vector3.ONE * s * 1.5, 0.06)
		tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.06)
		tw.tween_callback(mi.queue_free)


## Gama Mise: avuç altında küçük formül; gerçek kurbağa dükkânı (GamaMise) kendi pof bulutunda belirir; kapının önündekiler
## emme çizgileriyle içeri çekilir, dükkân kurbağaya dönüşürken yine pof; mide asidi kabarcıkları; sonunda tükürür
static func kuchiyose_gama_mise_no_jutsu(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	var tt = pj.tg(c, t, 14.0)
	var at = pj.gp((tt.global_position if tt else c.global_position + d * 6.0) + d * 1.8)
	var orange = Color(1, 0.55, 0.15)
	_palm_slam(pj, pj.gp(c.global_position + c.face_dir() * 0.6), orange, 0.6)
	_seal(pj, c.global_position, 1.4, 0, orange, 0.25, 0.4, 0.4)
	Sfx.play("poof", pj.gp(c.global_position), 0.8)
	_pop(pj, at + Vector3.UP * 2.2, 3.4, Color(1, 1, 1, 0.97), Color(0.72, 0.72, 0.8, 1), 10, 1.0)
	var shop = GamaMise.spawn(pj.get_tree().current_scene, at, atan2(d.x, d.z))
	Sfx.play("poof", at, 0.6)
	var caught = []
	pj.after(1.0, func():
		if not is_instance_valid(shop):
			return
		var door = at - d * 2.0
		_converge(pj, door + Vector3.UP * 1.2, 14, 6.0, 0.4, Color(0.95, 0.92, 0.85, 0.85), 0.07)
		for e in pj.enemies_near(c, door, 6.0):
			if not pj.live(e) or ClanJutsu.body_scale(e) > 1.5:
				continue
			caught.append(e)
			var p0: Vector3 = e.global_position
			_speed_lines(pj, p0.lerp(at, 0.5) + Vector3.UP, (at - p0).normalized(), 5, 2.0, 0.5, 0.35, Color(1, 1, 1, 0.8), 0.05)
			var tw = e.create_tween()
			tw.tween_method(func(q: float):
				if is_instance_valid(e):
					e.global_position = p0.lerp(at, q), 0.0, 1.0, 0.35)
			tw.tween_callback(func():
				if is_instance_valid(e):
					var m = e.get("model")
					if m:
						m.visible = false)
			pj.st(e, "bind", 4.0)
		pj.after(0.45, func():
			if is_instance_valid(shop):
				shop.morph(0.6)
				_pop(pj, at + Vector3.UP * 1.8, 2.6, Color(1, 1, 1, 0.95), Color(0.76, 0.74, 0.8, 1), 7, 0.8)
				Sfx.play("poof", at, 0.9)
				if not caught.is_empty():
					Combat.popup_text(at + Vector3.UP * 4.0, "Kurbağanın midesinde!", Color(1, 0.7, 0.3))))
	pj.every(4.5, 0.5, func(i, _k):
		if i < 4:
			return
		if not caught.is_empty() and is_instance_valid(shop):
			_bubbles(pj, at + Vector3.UP * 1.6, 3)
		for e in caught:
			if pj.live(e):
				e.take_hit(pj.inf(c, "kuchiyose_gama_mise_no_jutsu", 0.22, {"knock": 0.0, "kind": "light", "attacker": c})), Callable())
	pj.after(5.2, func():
		if is_instance_valid(shop):
			shop.shrink(0.6)
		pj.after(0.55, func():
			for e in caught:
				if is_instance_valid(e):
					var m = e.get("model")
					if m:
						m.visible = true
					if pj.live(e):
						e.take_hit(pj.inf(c, "kuchiyose_gama_mise_no_jutsu", 0.6, {"knock": 9.0, "launch": 4.0, "kind": "heavy", "dir": d, "attacker": c}))
			if is_instance_valid(shop):
				_pop(pj, at + Vector3.UP, 1.7, Color(1, 1, 1, 0.95), Color(0.74, 0.72, 0.8, 1), 7, 0.8)
				shop.queue_free()))


## Gyaku Kuchiyose: ayak altında hızla yazılan küçük formül; kullanıcı dikey sütun gibi yükselen pof bulutunda kaybolur
## (sözleşme diyarının renginde küçük kıvılcımlar yükselir) ve diyara taşınır (Contracts.reverse_summon akışı aynen)
static func reverse_summoning_technique(pj, c: Node3D, _t: Node3D) -> void:
	if not c is Player:
		return
	var id = Contracts.active()
	if id == "" or Contracts.DEFS[id]["realm"] == "":
		Hud.msg("Ters çağırma için gizli diyarı olan bir sözleşme gerekli (kurbağa, yılan, sümüklüböcek).", Color(1, 0.7, 0.5))
		return
	var rp = ContractRealms.realm_pos(id)
	if rp == Vector3.ZERO:
		return
	var pr = Contracts.p()
	pr["realm_return"] = [c.global_position.x, c.global_position.y, c.global_position.z]
	var col: Color = Contracts.DEFS[id]["color"]
	var p = c.global_position
	_seal(pj, p, 1.8, 0, col, 0.15, 0.3, 0.4)
	for k in 3:   # dikey sütun: üst üste üç pof
		_pop(pj, p + Vector3.UP * (0.6 + k * 0.9), 1.5 - k * 0.25, Color(1, 1, 1, 0.97), Color(0.72, 0.74, 0.78, 1), 6, 0.9 + k * 0.1)
	for i in 14:
		var s = randf_range(0.05, 0.1)
		var q0 = p + Vector3(randf_range(-0.8, 0.8), randf_range(0.2, 1.2), randf_range(-0.8, 0.8))
		var mi = _lump(pj, q0, Vector3.ONE * s, col.lightened(0.3), col.darkened(0.2))
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", q0 + Vector3.UP * randf_range(1.5, 3.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.4).set_delay(0.5)
		tw.chain().tween_callback(mi.queue_free)
	Sfx.play("poof", c.global_position)
	c.respawn(rp + Vector3(0, 0.5, 0))
	Hud.banner(Contracts.DEFS[id]["realm"], "Ters çağırma", Contracts.DEFS[id]["color"])


## Edo Tensei (ref): kurban bedeni kül-kâğıt pullarıyla sarılır; yerde kendini yazan Edo formülü (pürüzlü halkalar, mühür
## daireleri), ortasında kara çukur açılır; gerçek tabutlar toz halkası ve çatlakla yükselir, kapak devrilince pul kıvrımı
static func kuchiyose_edo_tensei(pj, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var names: Array = []
	if c is Player:
		var dna: Array = Game.profile.get("edo_dna", [])
		var vic = null
		for e in pj.enemies_near(c, c.global_position, 12.0):
			if e is Enemy and not e is Boss and e.hp <= e.max_hp * 0.35:
				vic = e
				break
		if dna.is_empty():
			Hud.msg("Edo Tensei: diriltecek bir ölünün DNA'sı yok — güçlü, isimli bir rakibi yen.", Color(0.85, 0.6, 0.45))
			return
		if vic == null:
			Hud.msg("Edo Tensei: canlı bir kurban gerek — 12 m içindeki bir düşmanı %35 canın altına indir.", Color(0.85, 0.6, 0.45))
			return
		names = dna.slice(maxi(0, dna.size() - 2))
		_flakes(pj, vic.global_position, float(vic.get("height")) if vic.get("height") != null else 1.8, 34)
		Combat.popup_text(vic.global_position + Vector3.UP * 2.5, "Kurban: mühür kâğıtları bedeni sardı", Color(0.85, 0.7, 0.5))
		vic.take_hit({"dmg": 99999.0, "kind": "heavy", "knock": 0.0, "attacker": c})
	pj.busy(c, 1.2)
	var fp = c.global_position + d * 4.0
	var seal = _seal(pj, fp, 5.0, 1, Color(0.62, 0.42, 0.3), 0.6, 1.3, 0.8, randf() * TAU)
	var ts = seal.create_tween()
	ts.tween_interval(0.35)
	ts.tween_method(_pf(seal, "pit"), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.shake(0.3)
	Sfx.play("earth", c.global_position, 0.5)
	for k in (names.size() if c is Player else 2):
		var pos = pj.gp(c.global_position + d * 4.0 + side * (k * 2.6 - 1.3))
		var coffin = pj._edo_coffin(k)
		pj.scene_add(coffin, pos - Vector3.UP * 2.8)
		coffin.look_at(coffin.global_position + d, Vector3.UP)
		var lid: Node3D = coffin.get_node("lid")
		_ring(pj, pos, 1.4, 0.9, Color(0.05, 0.04, 0.05, 0.9), 0.5, 1.0)   # tabutun çıktığı kara ağız
		_cracks(pj, pos, 2.2, 7, 1.6)
		_dust(pj, pos, 2.0, 8, Color(0.62, 0.56, 0.48, 0.9), 0.9)
		_rocks(pj, pos + Vector3.UP * 0.2, 7, 5.0, Color(0.42, 0.37, 0.32), 0.9, 0.9, 0.9)
		var tw = coffin.create_tween()
		tw.tween_property(coffin, "global_position", pos, 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.35)
		tw.tween_property(lid, "rotation:x", -PI * 0.5, 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			var front = pos + Vector3.UP * 0.2 + d * 1.2
			_dust(pj, front, 1.6, 7, Color(0.7, 0.66, 0.6, 0.9), 0.7)
			_rocks(pj, front, 6, 3.0, Color(0.55, 0.52, 0.5), 0.7, 0.6, 0.6)
			_flake_swirl(pj, pos + d * 1.2, 12)
			Sfx.play("earth", pos, 1.2)
			var w = EdoWarrior.new()
			w.team = c.team
			w.owner_f = c
			w.look = EdoWarrior.edo_look(k)
			w.power = (Stats.jutsu_mult(Game.profile) if c is Player else float(c.get("power") if c.get("power") != null else 1.0)) * 1.6
			pj.get_tree().current_scene.add_child(w)
			w.global_position = pos + d * 1.2
			if k < names.size():
				Combat.popup_text(pos + Vector3.UP * 3.0, "%s dirildi" % names[k], Color(0.85, 0.75, 0.6)))
		tw.tween_interval(28.0)
		tw.tween_callback(func(): _dust(pj, pos, 1.8, 7, Color(0.62, 0.56, 0.48, 0.9), 0.7))
		tw.tween_property(coffin, "global_position", pos - Vector3.UP * 3.0, 0.6)
		tw.tween_callback(coffin.queue_free)


## Kurban sarma (ref): kül-kâğıt pulları yerden sarmal çizerek bedene yapışır, sonra üstten koparak dağılır
static func _flakes(pj, feet: Vector3, h: float, n: int) -> void:
	var hh = clampf(h, 1.0, 3.5)
	for i in n:
		var a0 = randf() * TAU
		var y = hh * (float(i) / n) * 0.95 + 0.1
		var r0 = randf_range(1.2, 1.8)
		var r1 = randf_range(0.28, 0.42) * (hh / 1.8)
		var s = randf_range(0.14, 0.24)
		var mi = _gi(_chip(i), _ink())
		_put(pj, mi, feet + Vector3(cos(a0) * r0, 0.1, sin(a0) * r0))
		mi.scale = Vector3.ONE * s
		mi.set_instance_shader_parameter("tint", Color(1, 1, 1, 1))
		var rot = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var delay = float(i) / n * 0.25
		var out_dir = Vector3(cos(a0), 0, sin(a0))
		var tw = mi.create_tween()
		tw.tween_interval(delay)
		tw.tween_method(func(q: float) -> void:
			if is_instance_valid(mi):
				var a = a0 + q * 5.0
				var rr = lerpf(r0, r1, q)
				mi.global_position = feet + Vector3(cos(a) * rr, lerpf(0.1, y, q), sin(a) * rr)
				mi.rotation = rot + Vector3(q * 6.0, q * 4.0, 0), 0.0, 1.0, 0.4)
		tw.tween_interval(0.35 - delay)
		tw.tween_method(func(q: float) -> void:
			if is_instance_valid(mi):
				var p0 = feet + Vector3(cos(a0 + 5.0) * r1, y, sin(a0 + 5.0) * r1)
				mi.global_position = p0 + (out_dir * 1.5 + Vector3.UP * 2.5) * q
				mi.rotation = rot + Vector3(q * 9.0, q * 5.0, q * 3.0), 0.0, 1.0, 0.7)
		tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.5).set_delay(0.2)
		tw.tween_callback(mi.queue_free)


## Diriltilen ninja tabuttan adım atarken ayak çevresinde kısa pul kıvrımı
static func _flake_swirl(pj, p: Vector3, n: int) -> void:
	for i in n:
		var a0 = randf() * TAU
		var s = randf_range(0.1, 0.18)
		var mi = _gi(_chip(i + 1), _ink())
		_put(pj, mi, p)
		mi.scale = Vector3.ONE * s
		mi.set_instance_shader_parameter("tint", Color(0.95, 0.93, 0.9, 1))
		var rr = randf_range(0.5, 1.0)
		var tw = mi.create_tween()
		tw.tween_method(func(q: float) -> void:
			if is_instance_valid(mi):
				var a = a0 + q * 4.0
				mi.global_position = p + Vector3(cos(a) * rr * (0.5 + q), 0.2 + q * 2.0, sin(a) * rr * (0.5 + q))
				mi.rotation = Vector3(q * 8.0 + a0, q * 5.0, 0), 0.0, 1.0, 0.9)
		tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.4).set_delay(0.5)
		tw.tween_callback(mi.queue_free)


## Sanjū Rashōmon: yerde kırmızı mürekkepli kare Rashōmon mührü yazılır; üç gerçek Rashōmon kapısı sırayla, giderek büyüyerek
## yerden fırlar (taban boyunca çatlak hattı, iki yana kabaran toz duvarı, fırlayan kayalar); mermiler kapıda çınlayıp söner
static func kuchiyose_sanju_rashomon(pj, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	pj.busy(c, 1.0)
	var red = Color(0.85, 0.25, 0.2)
	_palm_slam(pj, pj.gp(c.global_position + d * 0.7), red, 1.0)
	_seal(pj, c.global_position + d * 6.0, 7.0, 2, red, 0.4, 1.4, 0.7, atan2(d.x, d.z))
	Sfx.play("poof", pj.gp(c.global_position + d * 6.0), 0.8)
	for k in 3:
		var pos = c.global_position + d * (5.0 + k * 3.2)
		var s = 1.0 + k * 0.25
		pj.after(0.15 + k * 0.28, func(): _gate(pj, c, pos, d, s, 10.0, "kuchiyose_sanju_rashomon"))
	pj.after(1.0, func(): _slowmo(pj, 0.5, 0.4))


## Rashōmon kapısı: oyunun gerçek kapı modeli (PathJutsu "rashomon" önbelleği, aynı yapı) + aynı engel / savurma / mermi yakalama;
## görseller bu dosyadan
static func _gate(pj, c: Node3D, pos: Vector3, d: Vector3, s: float, dur: float, id: String) -> Node3D:
	var mesh = pj.cached("rashomon", func(): return _rashomon_mb())
	var gate = MeshInstance3D.new()
	gate.mesh = mesh
	gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var root = Node3D.new()
	pj.scene_add(root, pj.gp(pos) - Vector3.UP * 13.0 * s)
	root.add_child(gate)
	gate.scale = Vector3.ONE * s
	pj.toward(root, d)
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	var cs = CollisionShape3D.new()
	var bx = BoxShape3D.new()
	bx.size = Vector3(12.0, 13.0, 1.6) * s
	cs.shape = bx
	cs.position = Vector3(0, 6.5, 0) * s
	sb.add_child(cs)
	root.add_child(sb)
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", pj.gp(pos), 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var base = pj.gp(pos)
	var side = d.cross(Vector3.UP).normalized()
	_crack_line(pj, base - side * 6.5 * s, base + side * 6.5 * s, 0.14 * s, 2.5)
	_dust_wall(pj, base, side, d, 6.0 * s, 1.4 * s)
	_rocks(pj, base + Vector3.UP * 0.3, 18, 12.0, Color(0.45, 0.38, 0.3), 1.6 * s, 0.9, 1.2)
	_burst_lines(pj, base + Vector3.UP * 3.0 * s, 10, 1.0, 4.0 * s, 0.3, Color(1, 0.95, 0.85, 0.85), 0.12, Vector3.ZERO, Vector3.UP, 30.0)
	pj.shake(0.7 * s)
	Sfx.play("earth", pos, 0.6)
	for e in pj.enemies_near(c, pos, 6.5 * s):
		pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.5, pj.inf(c, id, 0.6, {"knock": 10.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.06}))
	var catch_r = 7.0 * s
	pj.every(dur, 0.05, func(_i, _k):
		if not is_instance_valid(root):
			return
		for pr in pj.get_tree().get_nodes_in_group("projectiles"):
			if pr is Projectile and is_instance_valid(pr) and pr.shooter != c and pr.global_position.distance_to(root.global_position + Vector3.UP * 6.0 * s) < catch_r:
				_glint(pj, pr.global_position, 1.0, Color(1, 0.82, 0.45, 1), 0.22)
				_burst_lines(pj, pr.global_position, 6, 0.1, 0.8, 0.2, Color(1, 0.8, 0.4, 1), 0.05, Vector3.ZERO, -d, 60.0)
				pr.queue_free(), func():
		if is_instance_valid(root):
			_dust_wall(pj, pj.gp(root.global_position), side, d, 5.0 * s, 0.9 * s)
			var t2 = root.create_tween()
			t2.tween_property(root, "global_position", root.global_position - Vector3.UP * 14.0 * s, 0.5).set_ease(Tween.EASE_IN)
			t2.tween_callback(root.queue_free))
	return root


## Kapı tabanı boyunca iki yana kabaran toz duvarı
static func _dust_wall(pj, base: Vector3, side: Vector3, d: Vector3, half_w: float, h: float) -> void:
	var n = int(clampf(half_w * 0.9, 5.0, 9.0))
	for i in n:
		var k = lerpf(-1.0, 1.0, (i + 0.5) / n)
		for sg in [-1.0, 1.0]:
			var p0 = base + side * half_w * k + d * sg * 0.7
			var s0 = h * randf_range(0.8, 1.3)
			var mi = _lump(pj, p0 + Vector3.UP * s0 * 0.3, Vector3(s0, s0 * 0.7, s0) * 0.3, DUST, DUST.darkened(0.3))
			var tw = mi.create_tween().set_parallel()
			tw.tween_property(mi, "global_position", p0 + d * sg * h * 2.0 + Vector3.UP * s0 * 0.8, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi, "scale", Vector3(s0 * 1.2, s0, s0 * 1.2), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.55).set_delay(0.6)
			tw.chain().tween_callback(mi.queue_free)


## Rashōmon kapı modeli: PathJutsu.rashomon_gate içindeki yapının birebir kopyası (aynı "rashomon" önbellek anahtarı)
static func _rashomon_mb() -> MB:
	var b = MB.new()
	var wood = Color(0.55, 0.12, 0.1)
	b.add("box", Vector3(0, 5.0, 0), Vector3(9.0, 10.0, 1.1), Color(0.32, 0.3, 0.33))
	b.add("box", Vector3(0, 5.0, -0.1), Vector3(0.18, 10.0, 1.2), Color(0.15, 0.14, 0.16))
	for sx in [-1.0, 1.0]:
		b.add("box", Vector3(5.0 * sx, 6.0, 0), Vector3(1.1, 12.0, 1.6), wood)
		b.add("box", Vector3(5.0 * sx, 0.4, 0), Vector3(1.6, 0.8, 2.0), Color(0.25, 0.22, 0.2))
		for k in 4:
			b.add("sphere", Vector3(2.2 * sx, 1.6 + k * 2.3, -0.62), Vector3(0.32, 0.32, 0.25), Color(0.7, 0.6, 0.25), Vector3.ZERO, 6)
	b.add("box", Vector3(0, 12.3, 0), Vector3(12.5, 0.9, 2.2), wood)
	b.add("box", Vector3(0, 13.2, 0), Vector3(14.0, 0.5, 2.8), Color(0.18, 0.15, 0.15))
	var face = Color(0.3, 0.3, 0.33)
	b.add_grad("sphere", Vector3(0, 6.0, -0.6), Vector3(8.8, 9.6, 1.3), face.lightened(0.08), face.darkened(0.2), Vector3.ZERO, 16)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(1.35 * sx, 8.6, -1.25), Vector3(1.3, 1.1, 0.5), Color(0.95, 0.92, 0.78), Vector3.ZERO, 12)
		b.add("sphere", Vector3(1.3 * sx, 8.65, -1.5), Vector3(0.5, 0.5, 0.2), Color(0.55, 0.42, 0.15), Vector3.ZERO, 10)
		b.add("sphere", Vector3(1.3 * sx, 8.65, -1.58), Vector3(0.22, 0.22, 0.1), Color(0.05, 0.04, 0.04), Vector3.ZERO, 8)
		b.add("box", Vector3(1.4 * sx, 9.45, -1.2), Vector3(1.8, 0.4, 0.5), face.darkened(0.25), Vector3(0, 0, -16 * sx))
		b.add("sphere", Vector3(0.5 * sx, 6.75, -1.95), Vector3(0.55, 0.5, 0.3), Color(0.04, 0.03, 0.04), Vector3.ZERO, 8)
		b.add("sphere", Vector3(0.75 * sx, 6.95, -1.65), Vector3(0.8, 0.8, 0.7), face.darkened(0.1), Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, 7.4, -1.6), Vector3(1.9, 1.8, 1.0), face.darkened(0.3), Vector3.ZERO, 12)
	b.add("box", Vector3(0, 8.3, -1.55), Vector3(0.9, 1.0, 0.4), face.darkened(0.3), Vector3(-20, 0, 0))
	for k in 15:
		var tx = lerpf(-3.7, 3.7, k / 14.0)
		var ty = 4.6 + tx * tx * 0.11
		var tilt = rad_to_deg(atan(tx * 0.26))
		b.add("sphere", Vector3(tx, ty - 0.15, -1.36), Vector3(0.75, 1.1 - absf(tx) * 0.13, 0.3), Color(0.72, 0.28, 0.3), Vector3.ZERO, 8)
		b.add("sphere", Vector3(tx, ty + 0.12, -1.5), Vector3(0.52, 1.15 - absf(tx) * 0.12, 0.22), Color(0.95, 0.93, 0.8), Vector3(0, 0, tilt), 7)
	b.add("box", Vector3(0, 5.55, -1.46), Vector3(0.1, 0.1, 0.05), face)
	for sx in [-1.0, 1.0]:
		for k in 5:
			b.add("sphere", Vector3((0.6 + k * 0.38) * sx, 9.75 - k * 0.12, -1.45), Vector3(0.12, 0.12, 0.08), face.darkened(0.35), Vector3.ZERO, 5)
		b.add("cyl", Vector3(3.9 * sx, 4.3, -0.62), Vector3(0.9, 0.12, 0.9), Color(0.8, 0.65, 0.25), Vector3(90, 0, 0), 8)
	for k in 9:
		var fy = 1.5 + k * 1.2
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(5.75 * sx, fy, 0), Vector3(0.6, 1.5, 0.5), Color(0.85, 0.22, 0.12).lerp(Color(0.95, 0.5, 0.15), (k % 3) * 0.3), Vector3(0, 0, -70.0 * sx), 5)
	for k in 7:
		b.add("cone", Vector3(-5.4 + k * 1.8, 13.8, 0), Vector3(0.7, 1.6, 0.6), Color(0.85, 0.22, 0.12).lerp(Color(0.95, 0.5, 0.15), (k % 2) * 0.4), Vector3.ZERO, 5)
	for sx in [-1.0, 1.0]:
		for k in 8:
			b.add("torus", Vector3(3.6 * sx, 12.6 - k * 0.55, -1.2), Vector3(0.35, 0.35, 0.35), Color(0.25, 0.24, 0.26), Vector3(90 if k % 2 else 0, 90 * (k % 2), 0), 8)
	return b
