class_name FinalFX2
extends RefCounted
## Final karma grup 2: kurbağa bilgeleri, mühür, lanet mührü, silah çağırma ve Hashirama hücresi ahşap teknikleri — on altı
## tekniğin görselleri bu dosyada, sıfırdan: kendi gölgelendiricileri (cel + kalın kontur, enerji, düz iz, Rasengan girdabı,
## ışın halesi, ses halkası, dil yayı), kendi geometrisi ve kendi parçacık ayarları. Ortak efekt yardımcısı kullanılmaz.
## Oyunun gerçek sistemleri: Fukasaku / Shima modelleri (PathJutsu._elder_toad), gerçek kurbağa çağrı modeli (SummonModels),
## Tetsuzan topuzu ve silah modelleri (PathJutsu._tetsuzan_mesh / weapon_mesh), gerçek yılan gövdesi (SleeveSnake), ten desenleri /
## bilge gözü / ten rengi (CharacterModel toon parametreleri), ahşap doğası kütüphanesi (MokutonLib — yalnız Hashirama hücresi
## ahşap teknikleri). Ekranı kaplamasın: büyük yapılar 6-8 m'de, bedene yakın parçalar 1-2 m'de kameraya yaklaşınca söner.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme) ana ağaçtaki işleyicilerden satır satır taşındı.

const ML = preload("res://scripts/combat/fx/lib/mokuton_lib.gd")

const INK := Color(0.035, 0.03, 0.04)
const STEEL := Color(0.78, 0.8, 0.86)
const IRON := Color(0.26, 0.25, 0.28)
const ROCK := Color(0.42, 0.37, 0.31)
const DUSTC := Color(0.72, 0.64, 0.52)
const SUMMON_RED := Color(0.8, 0.16, 0.12)
const NAT := Color(1.0, 0.58, 0.14)
const NAT_HI := Color(1.0, 0.92, 0.55)
const RASEN := Color(0.38, 0.64, 1.0)
const RASEN_HI := Color(0.93, 0.97, 1.0)
const SONG := Color(0.62, 0.95, 0.3)
const SONG_HI := Color(1.0, 1.0, 0.86)
const HEAL := Color(0.38, 1.0, 0.42)
const HEAL_HI := Color(0.9, 1.0, 0.8)
const CURSE := Color(0.3, 0.05, 0.4)
const SNAKE_W := Color(0.92, 0.92, 0.88)
const SNAKE_B := Color(0.96, 0.9, 0.74)
const VENOM := Color(0.55, 0.18, 0.66)
const WIRE := Color(0.55, 0.85, 1.0)
const TONGUE := Color(0.62, 0.78, 0.95)
const BLOOD := Color(0.55, 0.03, 0.04)
const WIND := Color(0.86, 0.94, 1.0)

static var _shaders := {}
static var _cache := {}


# ================================================================== gölgelendiriciler
## Cel: köşe rengi × tint, toon ışık, kenar parıltısı; nf > 0 ise kameraya nf metreden yakın kısım noktalı silinir
const CEL_SH := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;
uniform vec4 tint : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform vec4 glow_col : source_color = vec4(1.0);
uniform float nf = 0.0;
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	if (nf > 0.0) {
		float k = smoothstep(nf * 0.55, nf, camd);
		float h = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
		if (h > k) { discard; }
	}
	ALBEDO = COLOR.rgb * tint.rgb;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_col.rgb * glow * (0.35 + fr);
	ROUGHNESS = 1.0;
}
"""

const LINE_SH := """
shader_type spatial;
render_mode unshaded, cull_front, specular_disabled, shadows_disabled;
uniform vec4 line_col : source_color = vec4(0.05, 0.04, 0.04, 1.0);
uniform float width = 0.012;
uniform float nf = 0.0;
varying float camd;
void vertex() {
	VERTEX += normalize(NORMAL) * width;
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	if (nf > 0.0) {
		float k = smoothstep(nf * 0.55, nf, camd);
		float h = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
		if (h > k) { discard; }
	}
	ALBEDO = line_col.rgb;
}
"""

## Enerji: kenarı parlak, akan gürültülü; kameraya yakın kısmı söner
const EN_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_%s, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.6, 0.15, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.92, 0.55, 1.0);
uniform float amount = 1.0;
uniform float flow = 2.0;
uniform float near_fade = 1.6;
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1, 0)), u.x), mix(hsh(i + vec2(0, 1)), hsh(i + vec2(1, 1)), u.x), u.y);
}
varying vec3 lp;
varying float camd;
void vertex() {
	lp = VERTEX;
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float n = vn(lp.xy * 5.0 + vec2(0.0, -TIME * flow)) * 0.6 + vn(lp.zy * 9.0 + vec2(TIME * flow * 0.7, 0.0)) * 0.4;
	vec3 c = mix(core.rgb, col.rgb, clamp(fres + n * 0.35, 0.0, 1.0));
	ALBEDO = c * COLOR.rgb;
	float a = clamp(0.3 + fres * 0.55 + n * 0.3, 0.0, 1.0) * amount * COLOR.a;
	ALPHA = clamp(a, 0.0, 1.0) * smoothstep(near_fade * 0.4, near_fade, camd);
}
"""

## Düz iz (mühür mürekkebi, yarık, toz eteği, gölge): köşe rengi × renk, amount ile söner
const FLAT_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_%s, shadows_disabled;
uniform vec4 col : source_color = vec4(0.05, 0.04, 0.04, 0.9);
uniform float amount = 1.0;
uniform float near_fade = 0.0;
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	ALBEDO = col.rgb * COLOR.rgb;
	float nfk = near_fade > 0.0 ? smoothstep(near_fade * 0.5, near_fade, camd) : 1.0;
	ALPHA = clamp(col.a * amount * COLOR.a * nfk, 0.0, 1.0);
}
"""

## Rasengan: beyaz çekirdek, mavi kenar; küre yüzeyinde dönen sarmal bantlar, ince koyu mavi kontur
const RASEN_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 rim_col : source_color = vec4(0.38, 0.64, 1.0, 1.0);
uniform vec4 core_col : source_color = vec4(0.93, 0.97, 1.0, 1.0);
uniform float amount = 1.0;
uniform float spin = 14.0;
uniform float near_fade = 6.0;
varying vec3 lp;
varying float camd;
void vertex() {
	lp = normalize(VERTEX);
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ang = atan(lp.z, lp.x);
	float b1 = sin(ang * 3.0 + lp.y * 7.0 - TIME * spin) * 0.5 + 0.5;
	float b2 = sin(ang * 5.0 - lp.y * 4.0 - TIME * spin * 1.3) * 0.5 + 0.5;
	float bands = smoothstep(0.6, 0.95, b1) * 0.6 + smoothstep(0.72, 1.0, b2) * 0.4;
	vec3 c = mix(core_col.rgb, rim_col.rgb, smoothstep(0.3, 0.85, fr));
	c = mix(c, vec3(1.0), bands * (1.0 - fr) * 0.55);
	c = mix(c, rim_col.rgb * 0.45, smoothstep(0.9, 0.98, fr));
	ALBEDO = c;
	ALPHA = clamp(mix(0.95, 0.8, fr) * amount, 0.0, 1.0) * smoothstep(near_fade * 0.5, near_fade, camd);
}
"""

## Işın halesi: kameraya dönük kart; merkezden dışa ince, boyları farklı titreşen dikenler (Rasengan / şifa ışığı)
const HALO_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 col : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float amount = 1.0;
uniform float rays = 44.0;
uniform float inner = 0.42;
uniform float near_fade = 6.0;
varying float camd;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float id = floor(a * rays);
	float sd = floor(TIME * 14.0);
	float hh = fract(sin(id * 12.9898 + sd * 3.17) * 43758.5453);
	float fa = fract(a * rays);
	float thin = 1.0 - smoothstep(0.0, 0.28, abs(fa - 0.5));
	float len = inner + 0.18 + hh * (0.98 - inner - 0.18);
	float ray = smoothstep(inner - 0.04, inner + 0.02, r) * (1.0 - smoothstep(len - 0.14, len, r)) * thin * step(0.3, hh);
	float soft = (1.0 - smoothstep(inner * 0.7, inner + 0.25, r)) * 0.3;
	ALBEDO = col.rgb;
	ALPHA = clamp(ray + soft, 0.0, 1.0) * amount * smoothstep(near_fade * 0.5, near_fade, camd);
}
"""

## Ses halkası: ince tüp; tam karşıdan beyaz öz, kenara doğru yeşil-sarı hale
const RING_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0, 1.0, 0.86, 1.0);
uniform vec4 halo : source_color = vec4(0.62, 0.95, 0.3, 1.0);
uniform float amount = 1.0;
uniform float near_fade = 2.0;
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float f = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = mix(halo.rgb, core.rgb, f);
	ALPHA = clamp((0.35 + 0.65 * f) * amount, 0.0, 1.0) * smoothstep(near_fade * 0.4, near_fade, camd);
}
"""

## Dil yayı: UV.x açısal ilerleme (head'e kadar açılır, kuyruğu söner), UV.y içten dışa; dış kenar beyaz
const ARC_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 col : source_color = vec4(0.62, 0.78, 0.95, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float head = 0.0;
uniform float tail = 0.45;
uniform float amount = 1.0;
uniform float near_fade = 1.5;
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float x = UV.x;
	float a = step(x, head) * smoothstep(head - tail, head, x);
	float r = UV.y;
	float band = smoothstep(0.0, 0.65, r) * (1.0 - smoothstep(0.93, 1.0, r));
	ALBEDO = mix(col.rgb, edge.rgb, smoothstep(0.7, 0.95, r));
	ALPHA = clamp(a * band * amount * 0.85, 0.0, 1.0) * smoothstep(near_fade * 0.4, near_fade, camd);
}
"""


static func _sh(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var s = Shader.new()
		s.code = code
		_shaders[key] = s
	return _shaders[key]


static func cel(tint := Color.WHITE, line := 0.012, nf := 0.0, glow := 0.0, glow_col := Color.WHITE) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh("cel", CEL_SH)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("glow_col", glow_col)
	m.set_shader_parameter("nf", nf)
	if line > 0.0:
		var o = ShaderMaterial.new()
		o.shader = _sh("line", LINE_SH)
		o.set_shader_parameter("width", line)
		o.set_shader_parameter("nf", nf)
		m.next_pass = o
	return m


static func energy(col: Color, core: Color, add := true, flow := 2.0, near := 1.6) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh("en_add" if add else "en_mix", EN_SH % ("add" if add else "mix"))
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("near_fade", near)
	return m


static func flat(col: Color, add := false, near := 0.0) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh("flat_add" if add else "flat_mix", FLAT_SH % ("add" if add else "mix"))
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("near_fade", near)
	return m


static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh(key, code)
	return m


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _amt(m: ShaderMaterial) -> float:
	var v = m.get_shader_parameter("amount")
	return 1.0 if v == null else float(v)


## Malzemenin "amount"unu söndürüp düğümü siler
static func _fade(n: Node, m: ShaderMaterial, delay: float, dur: float, free := true) -> void:
	if n == null or not is_instance_valid(n):
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	var a0 = _amt(m)
	tw.tween_method(func(x: float): m.set_shader_parameter("amount", x), a0, 0.0, dur)
	if free:
		tw.tween_callback(n.queue_free)


static func _shrink(n: Node3D, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(n, "scale", n.scale * 0.02, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


static func _basis_y(v: Vector3) -> Basis:
	var y = v.normalized() if v.length() > 0.0001 else Vector3.UP
	var x = y.cross(Vector3.UP)
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())


## -Z = d
static func _basis_look(d: Vector3) -> Basis:
	var f = d.normalized() if d.length() > 0.0001 else Vector3.FORWARD
	var up = Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT
	return Basis.looking_at(f, up)


## Düğümün son bilinen konumu (silinse de son yeri döner)
static func _track(n: Node3D, off: Vector3, fn := Callable()) -> Callable:
	var last = {"p": (n.global_position + off) if is_instance_valid(n) and n.is_inside_tree() else Vector3.ZERO}
	return func() -> Vector3:
		if is_instance_valid(n) and n.is_inside_tree():
			last["p"] = fn.call() if fn.is_valid() else n.global_position + off
		return last["p"]


static func _slowmo(pj: PathJutsu, s: float, real_dur: float) -> void:
	if Combat.base_time_scale < 0.99:
		return
	Combat.base_time_scale = s
	Engine.time_scale = s
	pj.get_tree().create_timer(real_dur, true, false, true).timeout.connect(func():
		if absf(Combat.base_time_scale - s) < 0.001:
			Combat.base_time_scale = 1.0)


# ================================================================== ağlar (önbellek anahtarları "mesh:" önekli)
static func _ring_mesh(inner: float, outer: float, seg := 40) -> ArrayMesh:
	var key = "mesh:ring_%.2f_%.2f_%d" % [inner, outer, seg]
	if _cache.has(key):
		return _cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 = TAU * i / seg
		var a1 = TAU * (i + 1) / seg
		var p = [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0) * outer, 0, sin(a0) * outer),
			Vector3(cos(a1) * outer, 0, sin(a1) * outer), Vector3(cos(a1) * inner, 0, sin(a1) * inner)]
		var cs = [Color(1, 1, 1, 0.2), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.2)]
		for q in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_color(cs[q])
			st.add_vertex(p[q])
	var m = st.commit()
	_cache[key] = m
	return m


## Dolu disk (merkez opak, kenar yumuşak)
static func _disc_mesh() -> ArrayMesh:
	var key = "mesh:disc"
	if _cache.has(key):
		return _cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 36
	for i in seg:
		var a0 = TAU * i / seg
		var a1 = TAU * (i + 1) / seg
		for v in [[Vector3.ZERO, 1.0], [Vector3(cos(a0), 0, sin(a0)), 0.0], [Vector3(cos(a1), 0, sin(a1)), 0.0]]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(1, 1, 1, 1.0 if float(v[1]) > 0.5 else 0.0))
			st.add_vertex(v[0])
	var m = st.commit()
	_cache[key] = m
	return m


## Yay (hilal) yüzeyi: XZ düzleminde, -Z ileri; UV.x = açısal ilerleme (a0 → a1), UV.y = içten dışa
static func _crescent_mesh(r0: float, r1: float, deg: float, seg := 36) -> ArrayMesh:
	var key = "mesh:cres_%.2f_%.2f_%.0f" % [r0, r1, deg]
	if _cache.has(key):
		return _cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var A0 = deg_to_rad(-deg * 0.5)
	var A1 = deg_to_rad(deg * 0.5)
	for i in seg:
		var u0 = float(i) / seg
		var u1 = float(i + 1) / seg
		var a0 = lerpf(A0, A1, u0)
		var a1 = lerpf(A0, A1, u1)
		# d.rotated(UP, a) ile aynı yön: (-sin a, 0, -cos a)
		var q = [[Vector3(-sin(a0), 0, -cos(a0)) * r0, Vector2(u0, 0)], [Vector3(-sin(a0), 0, -cos(a0)) * r1, Vector2(u0, 1)],
			[Vector3(-sin(a1), 0, -cos(a1)) * r1, Vector2(u1, 1)], [Vector3(-sin(a1), 0, -cos(a1)) * r0, Vector2(u1, 0)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(q[k][1])
			st.set_color(Color.WHITE)
			st.add_vertex(q[k][0])
	var m = st.commit()
	_cache[key] = m
	return m


## Kurbağa dili: -Z boyunca 1 m yassı, uca doğru incelen şerit; ortası açık (dil oluğu)
static func _tongue_mesh() -> ArrayMesh:
	var key = "mesh:tongue"
	if _cache.has(key):
		return _cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 16
	for i in n:
		var s0 = float(i) / n
		var s1 = float(i + 1) / n
		var w0 = 0.15 * (1.0 - pow(s0, 1.6)) + 0.012
		var w1 = 0.15 * (1.0 - pow(s1, 1.6)) + 0.012
		var rows = [[Vector3(-w0, 0, -s0), Vector3(0, 0.012, -s0), Vector3(w0, 0, -s0)], [Vector3(-w1, 0, -s1), Vector3(0, 0.012, -s1), Vector3(w1, 0, -s1)]]
		var cols = [Color(0.75, 0.75, 0.8), Color(1.25, 1.25, 1.2), Color(0.75, 0.75, 0.8)]
		for side in 2:
			var a = rows[0][side]
			var b = rows[0][side + 1]
			var c = rows[1][side + 1]
			var d = rows[1][side]
			var ca = cols[side]
			var cb = cols[side + 1]
			for v in [[a, ca], [b, cb], [c, cb], [a, ca], [c, cb], [d, ca]]:
				st.set_normal(Vector3.UP)
				st.set_color(v[1])
				st.add_vertex(v[0])
	var m = st.commit()
	_cache[key] = m
	return m


## Alev dili: +Y boyunca 1 m, kıvrık, uca doğru incelen yassı kart
static func _flame_mesh() -> ArrayMesh:
	var key = "mesh:flame"
	if _cache.has(key):
		return _cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 10
	for i in n:
		var s0 = float(i) / n
		var s1 = float(i + 1) / n
		var x0 = 0.16 * sin(s0 * 2.6)
		var x1 = 0.16 * sin(s1 * 2.6)
		var w0 = 0.13 * pow(1.0 - s0, 0.8) * (0.6 + 0.4 * sin(s0 * PI + 0.4))
		var w1 = 0.13 * pow(1.0 - s1, 0.8) * (0.6 + 0.4 * sin(s1 * PI + 0.4))
		var a = Vector3(x0 - w0, s0, 0)
		var b = Vector3(x0 + w0, s0, 0)
		var c = Vector3(x1 + w1, s1, 0)
		var d = Vector3(x1 - w1, s1, 0)
		var al0 = 1.0 - s0 * 0.5
		var al1 = 1.0 - s1 * 0.5
		for v in [[a, al0], [b, al0], [c, al1], [a, al0], [c, al1], [d, al1]]:
			st.set_normal(Vector3.BACK)
			st.set_color(Color(1, 1, 1, float(v[1])))
			st.add_vertex(v[0])
	var m = st.commit()
	_cache[key] = m
	return m


## Çağırma mürekkep formülü (birim yarıçap, XZ): dış çift halka, ışınsal fırça çizgileri, aralarda küçük işaretler, göbekte nokta
static func _seal_mesh() -> ArrayMesh:
	var key = "mesh:seal"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var w = Color.WHITE
	for k in 56:
		var a = TAU * k / 56.0
		b.add("box", Vector3(cos(a), 0, sin(a)) * 1.0, Vector3(TAU / 56.0 * 1.08, 0.004, 0.06), w, Vector3(0, 90.0 - rad_to_deg(a), 0))
		b.add("box", Vector3(cos(a), 0, sin(a)) * 0.9, Vector3(TAU * 0.9 / 56.0 * 1.08, 0.004, 0.022), w, Vector3(0, 90.0 - rad_to_deg(a), 0))
	for k in 14:
		var a = TAU * k / 14.0 + 0.1
		var L = 0.28 + 0.12 * float(k % 3)
		b.add("box", Vector3(cos(a), 0, sin(a)) * (0.84 - L * 0.5), Vector3(L, 0.004, 0.035 - 0.008 * float(k % 2)), w, Vector3(0, -rad_to_deg(a), 0))
		var a2 = a + TAU / 28.0
		for q in 3:
			b.add("box", Vector3(cos(a2), 0, sin(a2)) * (0.76 - q * 0.07), Vector3(0.05, 0.004, 0.018), w, Vector3(0, -rad_to_deg(a2) + 90.0 + q * 25.0, 0))
	for k in 24:
		var a = TAU * k / 24.0
		b.add("box", Vector3(cos(a), 0, sin(a)) * 0.34, Vector3(TAU * 0.34 / 24.0 * 0.7, 0.004, 0.03), w, Vector3(0, 90.0 - rad_to_deg(a), 0))
	b.add("cyl", Vector3.ZERO, Vector3(0.14, 0.004, 0.14), w, Vector3.ZERO, 14)
	var m = b.build()
	_cache[key] = m
	return m


## Tessō pençesi (ana ağaçtaki modelin aynısı): zincir halkalı göbek + üç kavisli kanca
static func _claw_mesh() -> ArrayMesh:
	var key = "mesh:tesso_claw"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	b.add("torus", Vector3(0, 0, 0.2), Vector3(0.14, 0.04, 0.14), IRON, Vector3(0, 90, 0), 10)
	Loft.blob(b, Vector3(0, 0, 0.12), Vector3(0, 0, -1), 0.32, [Vector2(0.06, 0.06), Vector2(0.13, 0.13), Vector2(0.12, 0.12), Vector2(0.08, 0.08)], IRON, 10)
	for k in 3:
		var a = k * TAU / 3.0 + PI * 0.5
		var r = Vector3(cos(a), sin(a), 0)
		Loft.tube(b, [r * 0.08 + Vector3(0, 0, -0.12), r * 0.2 + Vector3(0, 0, -0.26), r * 0.24 + Vector3(0, 0, -0.44), r * 0.16 + Vector3(0, 0, -0.58), r * 0.05 + Vector3(0, 0, -0.62)], [0.055, 0.05, 0.04, 0.025, 0.004], STEEL.darkened(0.15), 6, 4)
	var m = b.build()
	_cache[key] = m
	return m


## Zincir halkası (+Y boyunca uzun)
static func _link_mesh() -> ArrayMesh:
	var key = "mesh:link"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	b.add("torus", Vector3.ZERO, Vector3(0.11, 0.11, 0.2), Color(0.38, 0.37, 0.41), Vector3(90, 0, 0), 10)
	var m = b.build()
	_cache[key] = m
	return m


## Elde açılan küçük çağırma parşömeni
static func _hand_scroll_mesh() -> ArrayMesh:
	var key = "mesh:hand_scroll"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(0.6, 0.01, 0.2), Color(0.95, 0.92, 0.8))
	b.add("box", Vector3(0, 0.007, 0), Vector3(0.44, 0.01, 0.13), Color(0.7, 0.15, 0.12))
	for sx in [-1.0, 1.0]:
		b.add("cyl", Vector3(0.31 * sx, 0, 0), Vector3(0.06, 0.24, 0.06), Color(0.55, 0.4, 0.25), Vector3(90, 0, 0), 8)
	var m = b.build()
	_cache[key] = m
	return m


## Tekkōsen (ana ağaçtaki modelin aynısı): kesintisiz yelpaze yaprağı, kaburgalar, kırmızı şerit, metal çerçeve, pim
static func _fan_mesh() -> ArrayMesh:
	var key = "mesh:tekkosen"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var A0 = -78.0
	var A1 = 78.0
	var NS = 40
	for k in NS:
		var a = deg_to_rad(lerpf(A0, A1, (k + 0.5) / NS))
		var da = deg_to_rad((A1 - A0) / NS)
		var fold = 0.04 if k % 2 == 0 else -0.04
		for band in 3:
			var r0 = 1.0 + band * 1.15
			var r1 = r0 + 1.15
			var rm = (r0 + r1) * 0.5
			var col = Color(0.36, 0.37, 0.42).darkened(0.08 * (k % 2)) if band < 2 else Color(0.62, 0.12, 0.12).darkened(0.08 * (k % 2))
			b.add("box", Vector3(sin(a) * rm, cos(a) * rm, fold), Vector3(rm * da * 1.08, r1 - r0 + 0.02, 0.03), col, Vector3(0, 0, -rad_to_deg(a)))
	for k in 13:
		var a = deg_to_rad(lerpf(A0, A1, k / 12.0))
		for z in [0.05, -0.05]:
			b.add("box", Vector3(sin(a) * 2.3, cos(a) * 2.3, z), Vector3(0.07, 4.6, 0.03), Color(0.14, 0.13, 0.15), Vector3(0, 0, -rad_to_deg(a)))
	for k in 30:
		var a = deg_to_rad(lerpf(A0, A1, (k + 0.5) / 30.0))
		b.add("box", Vector3(sin(a) * 4.47, cos(a) * 4.47, 0), Vector3(4.47 * deg_to_rad((A1 - A0) / 30.0) * 1.05, 0.08, 0.07), Color(0.55, 0.55, 0.58), Vector3(0, 0, -rad_to_deg(a)))
	b.add("cyl", Vector3(0, 0, 0), Vector3(0.32, 0.2, 0.32), Color(0.75, 0.62, 0.3), Vector3(90, 0, 0), 12)
	var m = b.build()
	_cache[key] = m
	return m


## Fukasaku (erkek) / Shima (dişi): oyunun gerçek yaşlı kurbağa modeli, cel malzemeyle
static func _elder_mesh(pj: PathJutsu, female: bool) -> ArrayMesh:
	var key = "mesh:elder_%d" % (1 if female else 0)
	if _cache.has(key):
		return _cache[key]
	var b: MB = pj._elder_toad(female)
	var m = b.build()
	_cache[key] = m
	return m


## Yassı insan gölgesi (XZ, +Z baş yönü): gövde, baş, iki kol iki bacak — kâğıt inceliğinde
static func _silhouette_mesh() -> ArrayMesh:
	var key = "mesh:sil"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var w = Color.WHITE
	b.add("box", Vector3(0, 0.02, 1.05), Vector3(0.5, 0.01, 0.75), w)
	b.add("cyl", Vector3(0, 0.02, 1.62), Vector3(0.36, 0.01, 0.4), w, Vector3.ZERO, 14)
	for sx in [-1.0, 1.0]:
		b.add("box", Vector3(0.36 * sx, 0.02, 1.0), Vector3(0.13, 0.01, 0.7), w, Vector3(0, -14.0 * sx, 0))
		b.add("box", Vector3(0.14 * sx, 0.02, 0.38), Vector3(0.17, 0.01, 0.78), w, Vector3(0, 6.0 * sx, 0))
	b.add("cyl", Vector3(0, 0.02, 0.7), Vector3(1.0, 0.01, 1.9), Color(1, 1, 1, 0.35), Vector3.ZERO, 20)
	var m = b.build()
	_cache[key] = m
	return m


## Şifa parşömeni (XZ sayfa, +Y yüz, -Z sayfanın üstü): krem kâğıt, soluk yeşil iç alan, ortada daire içinde "仙" fırça
## çizgileri, kenarlarda kıvrık formül işaretleri, iki uçta rulo
static func _heal_scroll_mesh() -> ArrayMesh:
	var key = "mesh:heal_scroll"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var paper = Color(0.95, 0.93, 0.82)
	var panel = Color(0.72, 0.95, 0.7)
	var ink = Color(0.1, 0.36, 0.14)
	b.add("box", Vector3.ZERO, Vector3(0.84, 0.01, 0.52), paper)
	b.add("box", Vector3(0, 0.006, 0), Vector3(0.68, 0.01, 0.4), panel)
	for sx in [-1.0, 1.0]:
		b.add("cyl", Vector3(0.44 * sx, 0, 0), Vector3(0.07, 0.56, 0.07), Color(0.45, 0.3, 0.2), Vector3(90, 0, 0), 8)
	var y = 0.013
	# 亻
	b.add("box", Vector3(-0.115, y, -0.075), Vector3(0.026, 0.006, 0.12), ink, Vector3(0, 38, 0))
	b.add("box", Vector3(-0.1, y, 0.035), Vector3(0.026, 0.006, 0.19), ink)
	# 山
	b.add("box", Vector3(0.06, y, -0.02), Vector3(0.026, 0.006, 0.2), ink)
	b.add("box", Vector3(-0.025, y, 0.025), Vector3(0.024, 0.006, 0.11), ink)
	b.add("box", Vector3(0.145, y, 0.025), Vector3(0.024, 0.006, 0.11), ink)
	b.add("box", Vector3(0.06, y, 0.08), Vector3(0.2, 0.006, 0.024), ink)
	for k in 30:   # daire
		var a = TAU * k / 30.0
		b.add("box", Vector3(0.0 + cos(a) * 0.19, y, sin(a) * 0.17), Vector3(0.045, 0.006, 0.012), ink, Vector3(0, 90.0 - rad_to_deg(a), 0))
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	for k in 22:   # kenar formülleri
		var sx = -1.0 if k % 2 == 0 else 1.0
		var px = sx * rng.randf_range(0.22, 0.31)
		var pz = rng.randf_range(-0.17, 0.17)
		b.add("box", Vector3(px, y, pz), Vector3(rng.randf_range(0.03, 0.07), 0.006, 0.012), ink, Vector3(0, rng.randf_range(-70, 70), 0))
	for k in 10:
		var px = rng.randf_range(-0.2, 0.2)
		var pz = (-0.175 if k % 2 == 0 else 0.175)
		b.add("box", Vector3(px, y, pz), Vector3(rng.randf_range(0.03, 0.06), 0.006, 0.012), ink, Vector3(0, rng.randf_range(-40, 40), 0))
	var m = b.build()
	_cache[key] = m
	return m


## Şifa ışınları (XZ, merkezden dışa incelen, uca doğru sönen)
static func _rays_mesh(n: int) -> ArrayMesh:
	var key = "mesh:rays_%d" % n
	if _cache.has(key):
		return _cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a = TAU * i / n + (0.12 if i % 2 == 0 else -0.05)
		var L = 1.0 if i % 2 == 0 else 0.7
		var d = Vector3(cos(a), 0, sin(a))
		var s = Vector3(-sin(a), 0, cos(a))
		var w = 0.05 if i % 2 == 0 else 0.03
		for v in [[d * 0.15 - s * w, 1.0], [d * 0.15 + s * w, 1.0], [d * L, 0.0]]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(1, 1, 1, float(v[1])))
			st.add_vertex(v[0])
	var m = st.commit()
	_cache[key] = m
	return m


## Beyaz bilge yılanı başı (-Z ileri): uzun kafa, açık alt çene, sarı yarık göz, iki diş, gözden mor çizgi
static func _snake_head(s: float) -> Node3D:
	var key = "mesh:white_snake_head"
	var mesh: ArrayMesh
	if _cache.has(key):
		mesh = _cache[key]
	else:
		var b = MB.new()
		b.add("sphere", Vector3(0, 0, 0), Vector3(0.6, 0.42, 0.95), SNAKE_W, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0, 0.04, -0.4), Vector3(0.46, 0.24, 0.6), SNAKE_W.darkened(0.05), Vector3(-8, 0, 0), 9)
		b.add("sphere", Vector3(0, -0.15, -0.36), Vector3(0.4, 0.12, 0.56), SNAKE_B, Vector3(22, 0, 0), 8)
		for sx in [-1.0, 1.0]:
			b.add("sphere", Vector3(0.19 * sx, 0.15, -0.22), Vector3(0.13, 0.1, 0.15), Color(1.0, 0.85, 0.15), Vector3.ZERO, 6)
			b.add("box", Vector3(0.2 * sx, 0.16, -0.255), Vector3(0.02, 0.08, 0.03), INK)
			b.add("cone", Vector3(0.08 * sx, -0.1, -0.6), Vector3(0.04, 0.12, 0.04), Color.WHITE, Vector3(180, 0, 0), 5)
			b.add("box", Vector3(0.22 * sx, 0.13, -0.02), Vector3(0.03, 0.02, 0.3), VENOM)
		mesh = b.build()
		_cache[key] = mesh
	var root = Node3D.new()
	var mi = _mi(mesh, cel(Color.WHITE, 0.012))
	mi.scale = Vector3.ONE * s
	root.add_child(mi)
	return root


static func _bit_mesh(round_bit: bool) -> ArrayMesh:
	var key = "mesh:bit_%d" % (1 if round_bit else 0)
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	if round_bit:
		b.add("sphere", Vector3.ZERO, Vector3.ONE, Color.WHITE, Vector3.ZERO, 6)
	else:
		b.add("box", Vector3.ZERO, Vector3(1.0, 0.7, 0.85), Color.WHITE, Vector3(18, 30, 0))
	var m = b.build()
	_cache[key] = m
	return m


# ================================================================== yapı taşları
## Kırıntı: balistik uçuş, yere değince durur, sonra küçülüp kaybolur
class Bits extends Node3D:
	var items: Array = []
	var t := 0.0
	var life := 1.4
	var floor_y := 0.0
	var grav := 18.0

	func _process(dt: float) -> void:
		t += dt
		for b in items:
			var n = b[0]
			if not is_instance_valid(n):
				continue
			var v: Vector3 = b[1]
			if n.global_position.y > floor_y + 0.03 or v.y > 0.0:
				v.y -= grav * dt
				n.global_position += v * dt
				n.rotate(b[2], dt * 8.0)
				b[1] = v
			else:
				n.global_position.y = floor_y + 0.02
			if t > life:
				n.scale = n.scale * maxf(0.0, 1.0 - dt * 4.0)
		if t > life + 0.9:
			queue_free()


static func _bits(pj: PathJutsu, at: Vector3, n: int, spd: float, col: Color, size: float, up := 0.7, dir := Vector3.ZERO, life := 1.4, round_bit := false) -> void:
	var db = Bits.new()
	db.life = life
	pj.get_tree().current_scene.add_child(db)
	db.global_position = Vector3.ZERO
	db.floor_y = pj.gp(at).y
	var mat = cel(col, 0.006)
	var mesh = _bit_mesh(round_bit)
	for i in n:
		var mi = _mi(mesh, mat)
		db.add_child(mi)
		mi.global_position = at
		mi.scale = Vector3.ONE * size * randf_range(0.5, 1.2)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var h = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		if dir.length() > 0.01:
			h = (h * 0.5 + dir.normalized()).normalized()
		var v = (h * (1.0 - up) + Vector3.UP * up * randf_range(0.6, 1.2)).normalized() * spd * randf_range(0.5, 1.1)
		db.items.append([mi, v, Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()])


## Yer yarığı: kırık, dallanan, uca doğru incelen koyu çizgiler; yavaş söner
static func _cracks(pj: PathJutsu, at: Vector3, r: float, n: int, col: Color, hold: float, dir := Vector3.ZERO, spread := TAU) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ww = clampf(0.05 * r, 0.04, 0.24)
	var base_a = atan2(dir.z, dir.x) if dir.length() > 0.01 else randf() * TAU
	for i in n:
		var a = base_a + (randf_range(-0.5, 0.5) * spread if dir.length() > 0.01 else i * TAU / n + randf_range(-0.3, 0.3))
		_crack_line(st, Vector2.ZERO, a, r * randf_range(0.55, 1.0), ww, 2)
	var mat = flat(col)
	var mi = _mi(st.commit(), mat)
	pj.scene_add(mi, pj.gp(at) + Vector3.UP * (0.04 + r * 0.004))
	mi.scale = Vector3(0.3, 1, 0.3)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade(mi, mat, hold, 1.2)
	return mi


static func _crack_line(st: SurfaceTool, p: Vector2, a: float, L: float, w: float, depth: int) -> void:
	var steps = 6
	var q = p
	for s in steps:
		a += randf_range(-0.45, 0.45)
		var nq = q + Vector2(cos(a), sin(a)) * L / steps
		var w0 = w * (1.0 - float(s) / steps)
		var w1 = w * (1.0 - float(s + 1) / steps)
		var nr = Vector2(-sin(a), cos(a))
		var pts = [q + nr * w0, q - nr * w0, nq - nr * w1, nq + nr * w1]
		for k in [0, 1, 2, 0, 2, 3]:
			var v: Vector2 = pts[k]
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(v.x, 0, v.y))
		if depth > 0 and (s == 2 or s == 3) and randf() < 0.55:
			_crack_line(st, nq, a + randf_range(0.5, 1.0) * (1.0 if randf() < 0.5 else -1.0), L * 0.45, w0 * 0.6, depth - 1)
		q = nq


## Sarmal krater izi: merkezden dönerek açılan kollar (Rasengan'ın öğüttüğü zemin)
static func _spiral_scar(pj: PathJutsu, at: Vector3, r: float, hold: float) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arms = 5
	var n = 18
	var ph = randf() * TAU
	for k in arms:
		var a0 = ph + TAU * k / arms
		for i in n:
			var u0 = float(i) / n
			var u1 = float(i + 1) / n
			var p0 = Vector2(cos(a0 + u0 * 2.6), sin(a0 + u0 * 2.6)) * r * (0.15 + u0 * 0.85)
			var p1 = Vector2(cos(a0 + u1 * 2.6), sin(a0 + u1 * 2.6)) * r * (0.15 + u1 * 0.85)
			var tg = (p1 - p0).normalized()
			var nr = Vector2(-tg.y, tg.x)
			var w0 = r * 0.07 * (1.0 - u0 * 0.8)
			var w1 = r * 0.07 * (1.0 - u1 * 0.8)
			var q = [p0 + nr * w0, p0 - nr * w0, p1 - nr * w1, p1 + nr * w1]
			for j in [0, 1, 2, 0, 2, 3]:
				var v: Vector2 = q[j]
				st.set_normal(Vector3.UP)
				st.set_color(Color(1, 1, 1, 1.0 - u0 * 0.4))
				st.add_vertex(Vector3(v.x, 0, v.y))
	var mat = flat(Color(0.08, 0.07, 0.08, 0.85))
	var mi = _mi(st.commit(), mat)
	pj.scene_add(mi, pj.gp(at) + Vector3.UP * 0.07)
	var pit_m = flat(Color(0.12, 0.1, 0.1, 0.55))
	var pit = _mi(_disc_mesh(), pit_m)
	pj.scene_add(pit, pj.gp(at) + Vector3.UP * 0.06)
	pit.scale = Vector3(r * 0.55, 1, r * 0.55)
	_fade(mi, mat, hold, 1.2)
	_fade(pit, pit_m, hold, 1.2)


## Hız / rüzgâr çizgileri: ince uzun çubuklar d boyunca kayarak söner
static func _streaks(pj: PathJutsu, from: Vector3, d: Vector3, n: int, L: float, col: Color, spread := 0.5, rad := 0.6, life := 0.25, add := false, near := 1.4) -> void:
	var dn = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	var side = _basis_look(dn)
	for i in n:
		var mat = energy(col, col.lightened(0.3), add, 0.0, near)
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.025, 0.025, L * randf_range(0.6, 1.0)), Color.WHITE)
		var mi = _mi(b.build(), mat)
		var off = side.x * randf_range(-rad, rad) + side.y * randf_range(-rad, rad)
		var dir = (dn + side.x * randf_range(-spread, spread) + side.y * randf_range(-spread, spread)).normalized()
		pj.scene_add(mi, from + off)
		mi.basis = _basis_look(dir)
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", mi.global_position + dir * L * 1.6, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, life)
		tw.tween_callback(mi.queue_free)


## Metal kıvılcımı: beyaz-sarı kısa çizgiler + minik parlama
static func _spark(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	_streaks(pj, at, d if d.length() > 0.01 else Vector3.UP, 7, 0.35, Color(1.0, 0.92, 0.6), 0.9, 0.05, 0.14, true, 0.8)
	var m = energy(Color(1.0, 0.85, 0.5), Color.WHITE, true, 0.0, 0.8)
	var s = SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 5
	var mi = _mi(s, m)
	pj.scene_add(mi, at)
	mi.scale = Vector3.ONE * 0.25
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 0.5, 0.1)
	tw.parallel().tween_method(func(x: float): m.set_shader_parameter("amount", x), 1.0, 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


## Halka dalgası (yüzeye dik normal), genişleyip söner
static func _ripple(pj: PathJutsu, pos: Vector3, normal: Vector3, r0: float, r1: float, dur: float, col: Color, core: Color, thick := 0.75, add := true, near := 1.4) -> MeshInstance3D:
	var mat = energy(col, core, add, 4.0, near)
	var mi = _mi(_ring_mesh(thick, 1.0), mat)
	pj.scene_add(mi, pos)
	mi.basis = _basis_y(normal)
	mi.scale = Vector3.ONE * r0
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Yere yapışık toz eteği: genişleyen yumuşak halka
static func _dust_skirt(pj: PathJutsu, at: Vector3, r0: float, r1: float, dur: float, col: Color) -> void:
	var mat = flat(Color(col.r, col.g, col.b, 0.55), false, 3.0)
	var mi = _mi(_ring_mesh(0.5, 1.0), mat)
	pj.scene_add(mi, pj.gp(at) + Vector3.UP * 0.08)
	mi.scale = Vector3.ONE * r0
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, 1.0, r1), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(x: float): mat.set_shader_parameter("amount", x), 1.0, 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Mürekkep çağırma formülü: hızla açılır, döner, bekler, söner. normal: yüzey yönü (gökte aşağı bakan için DOWN)
static func _ink_seal(pj: PathJutsu, pos: Vector3, r: float, col: Color, hold: float, normal := Vector3.UP, add := false) -> MeshInstance3D:
	var mat = flat(col, add, 3.0)
	var mi = _mi(_seal_mesh(), mat)
	pj.scene_add(mi, pos)
	mi.basis = _basis_y(normal)
	mi.scale = Vector3.ONE * r * 0.15
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * r, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "rotation:y", mi.rotation.y + 0.6, hold + 0.6)
	_fade(mi, mat, hold, 0.5)
	return mi


## Canlı tüp: iki uç her kare okunur, arada sarkık eğri. deco: eğri boyunca dizili düğümler (zincir halkası; tek/çift 90°)
class Tube extends Node3D:
	var a_fn: Callable
	var b_fn: Callable
	var radius := 0.05
	var sag := 0.1
	var segs := 16
	var sides := 6
	var mat: Material
	var deco: Array = []
	var life := -1.0
	var pulse := 0.0
	var t := 0.0
	var _im: ImmediateMesh
	var _mi: MeshInstance3D

	func _ready() -> void:
		top_level = true
		global_transform = Transform3D.IDENTITY
		if radius > 0.0:
			_im = ImmediateMesh.new()
			_mi = MeshInstance3D.new()
			_mi.mesh = _im
			_mi.material_override = mat
			_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mi.extra_cull_margin = 40.0
			add_child(_mi)

	func add_deco(n: Node3D) -> void:
		deco.append(n)
		add_child(n)
		n.top_level = true

	func _process(dt: float) -> void:
		t += dt
		pulse = maxf(0.0, pulse - dt * 4.0)
		if (life > 0.0 and t > life) or not a_fn.is_valid() or not b_fn.is_valid():
			queue_free()
			return
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		var L = a.distance_to(b)
		var pts: Array = []
		for i in segs + 1:
			var k = float(i) / segs
			pts.append(a.lerp(b, k) + Vector3.DOWN * sag * L * 0.25 * sin(k * PI))
		var n = pts.size()
		var frames: Array = []
		var prev_up = Vector3.UP
		for i in n:
			var p1: Vector3 = pts[mini(i + 1, n - 1)]
			var p0: Vector3 = pts[maxi(i - 1, 0)]
			var tng = p1 - p0
			tng = tng.normalized() if tng.length() > 0.00001 else Vector3.FORWARD
			var bb = tng.cross(prev_up)
			if bb.length() < 0.05:
				bb = tng.cross(Vector3.RIGHT)
			bb = bb.normalized()
			var u = bb.cross(tng).normalized()
			prev_up = u
			frames.append([u, bb, tng])
		if _im:
			_im.clear_surfaces()
			if L > 0.05:
				var r = radius * (1.0 + pulse * 1.5)
				_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				for i in n - 1:
					for j in sides:
						for q in [[i, j], [i + 1, j], [i, j + 1], [i, j + 1], [i + 1, j], [i + 1, j + 1]]:
							var ii: int = q[0]
							var ang = TAU * float(q[1]) / sides
							var fr: Array = frames[ii]
							var nrm: Vector3 = fr[0] * cos(ang) + fr[1] * sin(ang)
							var pp: Vector3 = pts[ii]
							_im.surface_set_normal(nrm)
							_im.surface_add_vertex(pp + nrm * r)
				_im.surface_end()
		for j in deco.size():
			var dn = deco[j]
			if not is_instance_valid(dn):
				continue
			dn.visible = L > 0.3
			var u2 = (float(j) + 0.5) / deco.size() * (n - 1)
			var i0 = mini(int(u2), n - 2)
			var f = u2 - i0
			var fr2: Array = frames[i0]
			var bx: Vector3 = fr2[1]
			var bz: Vector3 = fr2[0]
			if j % 2 == 1:
				var tmp = bx
				bx = bz
				bz = -tmp
			var pa: Vector3 = pts[i0]
			var pb: Vector3 = pts[i0 + 1]
			dn.global_transform = Transform3D(Basis(bx, fr2[2], bz), pa.lerp(pb, f))


static func _tube(pj: PathJutsu, a_fn: Callable, b_fn: Callable, radius: float, mat: Material) -> Tube:
	var r = Tube.new()
	r.a_fn = a_fn
	r.b_fn = b_fn
	r.radius = radius
	r.mat = mat
	pj.get_tree().current_scene.add_child(r)
	return r


## Doğa enerjisi toplanışı: kabuktan içe çekilen parlak zerreler (kendi parçacık ayarı)
static func _gather(pj: PathJutsu, at: Vector3, r: float, n: int, dur: float, col: Color, core: Color) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = n
	p.lifetime = 0.55
	p.local_coords = false
	var sm = SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	p.material_override = energy(col, core, true, 0.0, 1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = r
	p.gravity = Vector3.ZERO
	p.radial_accel_min = -r * 7.5
	p.radial_accel_max = -r * 6.0
	p.tangential_accel_min = 1.5
	p.tangential_accel_max = 3.5
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.85, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = g
	pj.get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	var w = weakref(p)
	pj.get_tree().create_timer(dur).timeout.connect(func():
		var x = w.get_ref()
		if x:
			x.emitting = false)
	pj.free_after(dur + 0.9, p)
	return p


## Yükselen zerreler (şifa ışığı)
static func _motes(pj: PathJutsu, at: Vector3, r: float, n: int, dur: float, col: Color, core: Color) -> void:
	var p = CPUParticles3D.new()
	p.amount = n
	p.lifetime = 0.9
	p.local_coords = false
	var sm = SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	p.material_override = energy(col, core, true, 0.0, 1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = g
	pj.get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	var w = weakref(p)
	pj.get_tree().create_timer(dur).timeout.connect(func():
		var x = w.get_ref()
		if x:
			x.emitting = false)
	pj.free_after(dur + 1.2, p)


## Ten rengi (gerçek beden), süre sonunda geri
static func _tint_for(pj: PathJutsu, c: Node3D, col: Color, k: float, dur: float) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or not m.has_method("set_skin_tint"):
		return
	var until = Time.get_ticks_msec() + int(dur * 1000.0)
	c.set_meta("ffx2_tint_until", until)
	var tw = m.create_tween()
	tw.tween_method(func(x: float):
		if is_instance_valid(m):
			m.set_skin_tint(col, x), 0.0, k, 0.3)
	pj.get_tree().create_timer(dur).timeout.connect(func():
		if not is_instance_valid(c) or not is_instance_valid(m):
			return
		if int(c.get_meta("ffx2_tint_until", 0)) > Time.get_ticks_msec() + 50:
			return
		var tw2 = m.create_tween()
		tw2.tween_method(func(x: float):
			if is_instance_valid(m):
				m.set_skin_tint(col, x), k, 0.0, 0.5))


static func _pi(m: ShaderMaterial, key: String) -> int:
	var v = m.get_shader_parameter(key)
	return int(v) if v != null else 0


## Tene çizilen desen (toon sage_marks = kind; yüz parametresi): bitince önceki desene döner
static func _skin_marks(pj: PathJutsu, c: Node3D, kind: int, face_param: String, dur: float) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m):
		return
	var bm = m.get("body_mesh")
	var smat = bm.get_surface_override_material(0) if bm else null
	var prev = 0
	if smat is ShaderMaterial:
		prev = _pi(smat, "sage_marks")
		if prev == kind:
			prev = 0
		smat.set_shader_parameter("sage_marks", kind)
	var fmat = m.get("face_skin_mat")
	if fmat is ShaderMaterial and face_param != "":
		fmat.set_shader_parameter(face_param, 1.0)
	pj.get_tree().create_timer(dur).timeout.connect(func():
		if smat is ShaderMaterial and is_instance_valid(smat) and _pi(smat, "sage_marks") == kind:
			smat.set_shader_parameter("sage_marks", prev)
		if fmat is ShaderMaterial and is_instance_valid(fmat) and face_param != "":
			fmat.set_shader_parameter(face_param, 0.0))


## Bilge yüzü (CharacterModel.set_sage: 1 kurbağa, 2 yılan): göz + ten izi; gerçek bilge modu açıksa dokunulmaz
static func _sage_face(pj: PathJutsu, c: Node3D, kind: int, dur: float) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or not m.has_method("set_sage"):
		return
	var em = m.get("eye_mat")
	var bm = m.get("body_mesh")
	var smat = bm.get_surface_override_material(0) if bm else null
	if em is ShaderMaterial and _pi(em, "sage_eyes") > 0:
		return
	m.set_sage(kind)
	pj.get_tree().create_timer(dur).timeout.connect(func():
		if not is_instance_valid(m) or (is_instance_valid(c) and c is Player and Buffs.has("sage")):
			return
		if em is ShaderMaterial and is_instance_valid(em) and _pi(em, "sage_eyes") == kind:
			em.set_shader_parameter("sage_eyes", 0)
		if smat is ShaderMaterial and is_instance_valid(smat) and _pi(smat, "sage_marks") == kind:
			smat.set_shader_parameter("sage_marks", 0))


## Mürekkep halkası patlaması (küçük): çağırma / geri dönüş anı — duman yerine fırça halkası + damlalar
static func _ink_pop(pj: PathJutsu, at: Vector3, s: float, col := INK) -> void:
	var cam_ok = true
	var cam = pj.get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(at) < 1.2:
		cam_ok = false
	if cam_ok:
		var n = (cam.global_position - at).normalized() if cam else Vector3.BACK
		_ripple(pj, at, n, s * 0.2, s, 0.25, col, col.lightened(0.2), 0.7, false, 0.9)
	_bits(pj, at, 5, 2.5 * s, col, 0.05 * s, 0.6, Vector3.ZERO, 0.5, true)


# ================================================================== 1) Kuchiyose: Tessō Kusari
## Elde kırmızı mühürlü küçük parşömen açılır; ondan iki sıra halkalı demir zincir ve üç kancalı pençe fırlar (koyu hız
## çizgileri). Pençe hedefe kapanır (kıvılcım), zincir gerilip hedefi çeker; yerde sürüklenme izi kalır. Iskalarsa pençe
## zemine saplanır (çatlak + taş kırıntısı) ve zincir kullanıcıyı kendine çeker.
static func tesso_kusari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	var from = pj.hand_pos(c, true)
	var to = tt.global_position + Vector3.UP * tt.height * 0.5 if tt else pj.gp(Jutsu._aim_ground(c, t, 18.0, 26.0)) + Vector3.UP * 0.2
	pj.busy(c, 0.9)
	pj.anim(c, "throw", 1.4)
	var dv: Vector3 = (to - from).normalized() if (to - from).length() > 0.01 else c.face_dir()
	# parşömen
	var sc = _mi(_hand_scroll_mesh(), cel(Color.WHITE, 0.006))
	pj.scene_add(sc, from + dv * 0.25)
	sc.global_basis = _basis_look(dv) * Basis(Vector3.UP, PI * 0.5)
	sc.scale = Vector3(0.1, 1, 1)
	var stw = sc.create_tween()
	stw.tween_property(sc, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stw.tween_interval(0.35)
	stw.tween_property(sc, "scale", Vector3(0.05, 1, 1), 0.15)
	stw.tween_callback(sc.queue_free)
	# pençe
	var claw = _mi(_claw_mesh(), cel(Color.WHITE, 0.012, 0.0, 0.25, STEEL))
	pj.scene_add(claw, from)
	claw.global_basis = _basis_look(to - from)
	var chain = _tube(pj, func(): return pj.hand_pos(c, true) if is_instance_valid(c) else from, _track(claw, Vector3.ZERO), 0.0, null)
	chain.life = 1.25
	chain.sag = 0.05
	chain.segs = 20
	var lm = _link_mesh()
	var lmat = cel(Color.WHITE, 0.006)
	for k in 26:
		chain.add_deco(_mi(lm, lmat))
	_streaks(pj, from, dv, 6, 1.6, Color(0.22, 0.22, 0.26), 0.05, 0.18, 0.22, false)
	Sfx.play("clink", from, 1.2)
	var tw = claw.create_tween()
	tw.tween_property(claw, "global_position", to, 0.22)
	tw.tween_callback(func():
		if tt and pj.live(tt):
			pj.hit(c, to, tt.radius + 0.5, pj.inf(c, "tesso_kusari", 0.7, {"knock": 0.0, "kind": "heavy", "hitstop": 0.06}))
			pj.st(tt, "bind", 0.6)
			Combat.popup_text(to + Vector3.UP, "Zincirlendi!", Color(0.85, 0.85, 0.9))
			_spark(pj, to, -dv)
			if is_instance_valid(claw):   # kancalar kapanır
				var ct = claw.create_tween()
				ct.tween_property(claw, "scale", Vector3(0.7, 0.7, 1.15), 0.08)
			if is_instance_valid(chain):
				chain.sag = 0.0
			pj.after(0.15, func():
				if pj.live(tt):
					pj.pull_to(c, tt, 0.35, 1.4)
					pj.st(tt, "stun", 2.0)
					var g0 = pj.gp(tt.global_position)   # sürüklenme izi + toz
					var back = (c.global_position - tt.global_position)
					back.y = 0.0
					if back.length() > 0.1:
						_cracks(pj, g0, back.length() * 0.6, 2, Color(0.25, 0.2, 0.16, 0.6), 1.2, back, 0.15)
					_bits(pj, g0 + Vector3.UP * 0.1, 8, 3.0, DUSTC, 0.09, 0.5, -back, 0.8))
			pj.every(0.6, 1.0 / 30.0, func(_i, _k):
				if pj.live(tt) and is_instance_valid(claw):
					claw.global_position = tt.global_position + Vector3.UP * tt.height * 0.5, func():
				if is_instance_valid(claw):
					claw.queue_free())
		else:
			var g = pj.gp(to)
			_cracks(pj, g, 1.2, 6, Color(0.1, 0.08, 0.07, 0.85), 1.6)
			_bits(pj, g + Vector3.UP * 0.1, 9, 5.0, ROCK, 0.12, 0.75)
			_spark(pj, g + Vector3.UP * 0.15, Vector3.UP)
			# kanca: seni zincirin ucuna çeker
			var start = c.global_position
			if c is Player:
				c.combat.invuln = 0.4
			pj.every(0.35, 1.0 / 40.0, func(_i, k):
				if is_instance_valid(c):
					c.global_position = start.lerp(pj.gp(to), k) + Vector3.UP * sin(k * PI) * 2.0, func():
				if is_instance_valid(claw):
					claw.queue_free()))


# ================================================================== 2) Kuchiyose: Tekkōsen
## Dev demir yelpaze önde kanat gibi açılır (yere dikilirken toz eteği, menteşede metal parıltısı, yaprak boyunca çelik
## parlaması). Çarpan mermiler kıvılcımla düşer. Kapanırken yelpaze döner ve önüne yatay rüzgâr çizgileri + savrulan toz
## ve çakıl gönderir — kubbe / kabuk yok.
static func tekkosen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var fd = pj.fwd(c, t)
	pj.busy(c, 0.6)
	var fmat = cel(Color.WHITE, 0.03, 7.0, 0.0, Color(1.0, 0.95, 0.85))
	var fan = _mi(_fan_mesh(), fmat)
	fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var root = Node3D.new()
	pj.scene_add(root, pj.gp(c.global_position + fd * 2.4))
	pj.toward(root, -fd)
	root.add_child(fan)
	fan.position = Vector3(0, 0.4, 0)
	fan.scale = Vector3(0.05, 1, 1)
	var tw = fan.create_tween()
	tw.tween_property(fan, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): fmat.set_shader_parameter("glow", sin(x * PI) * 0.6), 0.0, 1.0, 0.35)
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	var cs = CollisionShape3D.new()
	var bx = BoxShape3D.new()
	bx.size = Vector3(8.0, 4.8, 0.8)
	cs.shape = bx
	cs.position = Vector3(0, 2.6, 0)
	sb.add_child(cs)
	root.add_child(sb)
	_dust_skirt(pj, root.global_position, 0.6, 4.0, 0.6, DUSTC)
	_bits(pj, root.global_position + Vector3.UP * 0.1, 8, 4.0, ROCK, 0.1, 0.6)
	_spark(pj, root.global_position + Vector3.UP * 0.4, Vector3.UP)
	Sfx.play("clink", root.global_position, 0.6)
	pj.every(6.0, 0.05, func(_i, _k):
		if not is_instance_valid(root):
			return
		for pr in pj.get_tree().get_nodes_in_group("projectiles"):
			if pr is Projectile and is_instance_valid(pr) and pr.shooter != c and pr.global_position.distance_to(root.global_position + Vector3.UP * 2.5) < 4.8:
				_spark(pj, pr.global_position, (pr.global_position - root.global_position - Vector3.UP * 2.5))
				var gt = fan.create_tween()   # isabet parıltısı
				gt.tween_method(func(x: float): fmat.set_shader_parameter("glow", x), 0.45, 0.0, 0.2)
				Sfx.play("clink", pr.global_position, 1.3, 0.6)
				pr.queue_free(), func():
		if not is_instance_valid(root):
			return
		var t2 = fan.create_tween()
		t2.tween_property(fan, "rotation:y", PI * 0.5, 0.2)
		t2.tween_callback(root.queue_free)
		var wd = fd
		if is_instance_valid(c):
			wd = c.face_dir()
		var o = root.global_position
		_streaks(pj, o + Vector3.UP * 1.6 + wd * 1.0, wd, 18, 3.6, WIND, 0.22, 2.6, 0.38, false, 3.0)
		_streaks(pj, o + Vector3.UP * 0.5 + wd * 1.5, wd, 8, 2.4, WIND, 0.12, 2.0, 0.3, false, 3.0)
		_bits(pj, o + wd * 1.5 + Vector3.UP * 0.2, 14, 9.0, DUSTC, 0.09, 0.35, wd, 0.9)
		_cracks(pj, o + wd * 3.0, 4.5, 5, Color(0.55, 0.48, 0.38, 0.35), 0.5, wd, 0.35)
		Sfx.play("wind", root.global_position, 0.9)
		for e in pj.enemies_near(c, root.global_position + wd * 6.0, 8.0):
			pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.5, pj.inf(c, "tekkosen", 0.9, {"knock": 24.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.05})))


# ================================================================== 3) Sōshōryū: Ito Arashi
## On silah çağrılıp kullanıcının çevresinde döner; her biri elinden çıkan ince mavi chakra teliyle bağlı (tel gerildikçe
## parlar). Yerde yörüngenin ince sürtünme izi. Saplanan silahın teli parlayıp titrer, ucunda kıvılcım. Süre bitince teller
## kopar, silahlar yere düşüp küçülerek kaybolur.
static func ito_buki_arashi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var dur = 7.0
	pj.busy(c, 0.5)
	var ws = []
	var wmat = cel(Color.WHITE, 0.008, 0.0, 0.15, STEEL)
	for k in 10:
		var w = Node3D.new()
		w.add_child(_mi(pj.weapon_mesh(PathJutsu.WEAPON_KINDS[k % PathJutsu.WEAPON_KINDS.size()]), wmat))
		pj.scene_add(w, c.global_position + Vector3.UP)
		var wn = w
		var right = k % 2 == 0
		var wire = _tube(pj, func(): return pj.hand_pos(c, right) if is_instance_valid(c) else Vector3.ZERO, func(): return wn.global_position if is_instance_valid(wn) else Vector3.ZERO, 0.016, energy(WIRE, Color.WHITE, true, 3.0, 1.0))
		wire.life = dur
		wire.sag = 0.06
		wire.segs = 10
		wire.sides = 4
		ws.append({"n": w, "a": TAU * k / 10.0, "busy": 0.0, "wire": wire})
	var track_m = flat(Color(0.35, 0.3, 0.26, 0.3), false, 3.0)   # yörünge izi
	var track = _mi(_ring_mesh(0.95, 1.0, 48), track_m)
	pj.scene_add(track, pj.gp(c.global_position) + Vector3.UP * 0.06)
	track.scale = Vector3.ONE * 3.2
	_fade(track, track_m, dur - 0.6, 0.6)
	_ripple(pj, c.global_position + Vector3.UP * 1.0, Vector3.UP, 0.5, 3.4, 0.35, WIRE, Color.WHITE, 0.92, true, 1.2)
	Sfx.play("whoosh", c.global_position, 0.9)
	var acc = {"t": 0.0}
	pj.every(dur, 1.0 / 30.0, func(_i, _kk):
		if not is_instance_valid(c):
			return
		acc["t"] += 1.0 / 30.0
		if is_instance_valid(track):
			track.global_position = pj.gp(c.global_position) + Vector3.UP * 0.06
		var tt = Time.get_ticks_msec() * 0.001
		for w in ws:
			var n: Node3D = w["n"]
			if not is_instance_valid(n):
				continue
			if w["busy"] > 0.0:
				w["busy"] -= 1.0 / 30.0
				continue
			var a = w["a"] + tt * 3.2
			var rest = c.global_position + Vector3(cos(a) * 3.2, 1.2 + sin(tt * 2.0 + w["a"]) * 0.5, sin(a) * 3.2)
			n.global_position = n.global_position.lerp(rest, 0.35)
			pj.toward(n, Vector3(-sin(a), 0, cos(a)))
			for e in pj.enemies_near(c, n.global_position, 0.9):
				pj.hit(c, n.global_position, 1.0, pj.inf(c, "ito_buki_arashi", 0.08, {"knock": 1.5, "kind": "light", "hitstop": 0.0}))
		if acc["t"] >= 0.45:
			acc["t"] = 0.0
			var near = pj.enemies_near(c, c.global_position, 16.0)
			if near.is_empty():
				return
			var sent = 0
			for w in ws:
				if sent >= 2 or w["busy"] > 0.0 or not is_instance_valid(w["n"]):
					continue
				var e = near[(sent + int(tt * 10.0)) % near.size()]
				var n: Node3D = w["n"]
				var wire = w["wire"]
				w["busy"] = 0.5
				sent += 1
				var from = n.global_position
				var to = e.global_position + Vector3.UP * e.height * 0.5
				var tw = n.create_tween()
				tw.tween_property(n, "global_position", to, 0.14)
				tw.tween_callback(func():
					if pj.live(e):
						pj.hit(c, to, e.radius + 0.5, pj.inf(c, "ito_buki_arashi", 0.32, {"knock": 2.0, "kind": "light", "hitstop": 0.03}))
						pj.st(e, "bind", 0.6)
						Sfx.play("kunai", to, 1.2, 0.5)
						_spark(pj, to, from - to)
						if is_instance_valid(wire):
							wire.pulse = 1.0)
				tw.tween_property(n, "global_position", from, 0.2), func():
		for w in ws:
			var n = w["n"]
			if is_instance_valid(w["wire"]):
				w["wire"].queue_free()
			if is_instance_valid(n):   # tel koptu: silah düşer, küçülür
				var g = pj.gp(n.global_position)
				var ft = n.create_tween()
				ft.tween_property(n, "global_position", g + Vector3.UP * 0.1, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				ft.parallel().tween_property(n, "rotation:x", n.rotation.x + 2.5, 0.35)
				ft.tween_interval(0.4)
				ft.tween_property(n, "scale", Vector3.ONE * 0.02, 0.3)
				ft.tween_callback(n.queue_free))


# ================================================================== 4) Kuchiyose: Tetsuzan
## Avuç yere: önde kırmızı kenarlı mürekkep çağırma formülü açılır; gökte aynı formül aşağı bakar, hedef zeminde kırmızı
## uyarı halkası daralır. Çivili dev topuz formülden düşer (üstünde dikey hız çizgileri); çarpınca kısa ağır çekim, dev
## yarıklı krater, çukur gölgesi, yayılan toz eteği, fırlayan taş parçaları. Sonra topuz yere açılan formülün içine yassılaşıp
## geri çağrılır (duman yok).
static func kuchiyose_tetsuzan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var center = pj.gp(Jutsu._aim_ground(c, t, 14.0, 32.0))
	pj.busy(c, 0.8)
	var sky = center + Vector3.UP * 28.0
	var palm = pj.gp(c.global_position + c.face_dir() * 1.2)
	_ink_seal(pj, palm + Vector3.UP * 0.06, 3.0, Color(0.06, 0.04, 0.05, 0.9), 1.0)
	_ripple(pj, palm + Vector3.UP * 0.1, Vector3.UP, 0.3, 3.2, 0.3, SUMMON_RED, Color(1, 0.6, 0.5), 0.85, false, 2.0)
	_bits(pj, palm + Vector3.UP * 0.1, 6, 3.0, DUSTC, 0.08, 0.6)
	_ink_seal(pj, sky, 6.0, Color(0.06, 0.04, 0.05, 0.95), 1.0, Vector3.DOWN)
	_ripple(pj, sky - Vector3.UP * 0.1, Vector3.DOWN, 1.0, 7.0, 0.4, SUMMON_RED, Color(1, 0.55, 0.45), 0.9, false, 6.0)
	var warn_m = flat(Color(1.0, 0.3, 0.22, 0.6), false, 3.0)   # hedef zemin uyarısı: daralan halka
	var warn = _mi(_ring_mesh(0.92, 1.0, 56), warn_m)
	pj.scene_add(warn, center + Vector3.UP * 0.08)
	warn.scale = Vector3.ONE * 10.0
	var wt = warn.create_tween()
	wt.tween_property(warn, "scale", Vector3.ONE * 8.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fade(warn, warn_m, 0.75, 0.25)
	Sfx.play("poof", sky, 0.6)
	var ball = _mi(pj._tetsuzan_mesh(), cel(Color.WHITE, 0.05, 8.0, 0.0, Color.WHITE))
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pj.scene_add(ball, sky)
	ball.scale = Vector3.ONE * 0.2
	var speed = Node3D.new()   # düşüş çizgileri (topuzun üstünde)
	ball.add_child(speed)
	for k in 8:
		var a = TAU * k / 8.0 + randf() * 0.4
		var sm = energy(WIND, Color.WHITE, false, 0.0, 6.0)
		var sb = MB.new()
		sb.add("box", Vector3.ZERO, Vector3(0.08, randf_range(5.0, 9.0), 0.08), Color.WHITE)
		var sl = _mi(sb.build(), sm)
		speed.add_child(sl)
		sl.position = Vector3(cos(a) * randf_range(2.6, 4.2), randf_range(5.0, 8.0), sin(a) * randf_range(2.6, 4.2))
		sm.set_shader_parameter("amount", 0.0)
		var st2 = sl.create_tween()
		st2.tween_interval(0.3)
		st2.tween_method(func(x: float): sm.set_shader_parameter("amount", x), 0.0, 0.8, 0.15)
	var tw = ball.create_tween()
	tw.tween_property(ball, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "global_position", center + Vector3.UP * 2.2, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(speed):
			speed.queue_free()
		_slowmo(pj, 0.5, 0.25)
		pj.shake(1.3)
		GroundFX.add(center, "cracked", 14.0 * 0.6, 5.0)   # yarık zemin: üstünden geçen yavaşlar
		_cracks(pj, center, 14.0, 14, Color(0.07, 0.055, 0.05, 0.92), 5.0)
		_cracks(pj, center, 6.0, 8, Color(0.07, 0.055, 0.05, 0.92), 5.0)
		var pit_m = flat(Color(0.1, 0.08, 0.07, 0.6))
		var pit = _mi(_disc_mesh(), pit_m)
		pj.scene_add(pit, center + Vector3.UP * 0.05)
		pit.scale = Vector3(5.5, 1, 5.5)
		_fade(pit, pit_m, 5.0, 1.2)
		_bits(pj, center + Vector3.UP * 0.5, 30, 18.0, ROCK, 0.45, 0.65, Vector3.ZERO, 1.6)
		_dust_skirt(pj, center, 3.0, 16.0, 1.1, DUSTC)
		_dust_skirt(pj, center, 2.0, 10.0, 0.7, DUSTC.darkened(0.15))
		_ripple(pj, center + Vector3.UP * 0.3, Vector3.UP, 4.0, 28.0, 0.5, Color(0.85, 0.75, 0.6), Color(1, 0.95, 0.85), 0.9, false, 6.0)
		Sfx.play("boom", center, 0.6)
		pj.hit(c, center + Vector3.UP, 8.5, pj.inf(c, "kuchiyose_tetsuzan", 2.4, {"knock": 18.0, "launch": 12.0, "kind": "heavy", "hitstop": 0.14})))
	tw.tween_interval(3.0)
	tw.tween_callback(func():
		if is_instance_valid(ball):
			_ink_seal(pj, center + Vector3.UP * 0.1, 4.5, Color(0.06, 0.04, 0.05, 0.9), 0.4))
	tw.tween_property(ball, "scale", Vector3(1.15, 0.02, 1.15), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ball, "global_position", center + Vector3.UP * 0.1, 0.3)
	tw.tween_callback(ball.queue_free)


# ================================================================== 5) Gamadaira — Kageayatsuri
## Kullanıcı kâğıt gibi yassılaşır; ayağının dibinden rakibe doğru yere yapışık bir mürekkep izi kayar ve rakibin gölgesi
## koyu, yavaşça nefes alır gibi zonklayan bir insan silüetine döner (kullanıcı içinde). Nefes bitince silüet yerden kâğıt
## gibi kalkıp söner, damlalar saçılır.
static func gamadaira_kageayatsuri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.6)
	if tt == null or not tt is Enemy or tt is Boss:
		if c is Player:
			Hud.msg("Gamadaira: sıradan bir düşmanın gölgesine karışabilirsin (boss'lar dirençli).", Color(0.8, 0.7, 1))
		return
	var dur = 6.0   # nefes tutma süresi
	if c.get("model"):
		var tw = c.model.create_tween()
		tw.tween_property(c.model, "scale", Vector3(1.2, 0.05, 1.2), 0.25)
	var g = pj.gp(tt.global_position)
	_ink_slide(pj, pj.gp(c.global_position), g, 0.3)
	var sh_m = flat(Color(INK.r, INK.g, INK.b, 0.88))
	var shadow = _mi(_silhouette_mesh(), sh_m)
	tt.add_child(shadow)
	shadow.scale = Vector3(0.2, 1, 0.2)
	var stw = shadow.create_tween()
	stw.tween_interval(0.25)
	stw.tween_property(shadow, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pulse = Game.safe_loops(shadow.create_tween())
	pulse.tween_method(func(x: float): sh_m.set_shader_parameter("amount", x), 1.0, 0.72, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_method(func(x: float): sh_m.set_shader_parameter("amount", x), 0.72, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	pj.after(0.3, func():
		if not pj.live(tt) or not pj.live(c):
			return
		if c.get("model"):
			c.model.visible = false
		c.global_position = g
		if c is Player and c.get("combat"):
			c.combat.invuln = dur
		if c is Player:
			c.input_locked = dur
			c.set_meta("shintenshin_t", tt)
			tt.set_meta("possessed_by", c)
		tt.team = c.team
		tt.target = null
		tt.state = "chase"
		_ripple(pj, g + Vector3.UP * 0.08, Vector3.UP, 0.4, 2.2, 0.4, INK, Color(0.2, 0.16, 0.24), 0.8, false, 2.0)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Gölgesine karıştı!", Color(0.75, 0.75, 0.85)))
	pj.every(dur + 0.3, 0.2, func(_i, _k):
		if pj.live(c) and pj.live(tt):
			c.global_position = pj.gp(tt.global_position), func():
		if is_instance_valid(shadow):
			shadow.queue_free()
		if pj.live(tt):
			Jutsu.shintenshin_release(c, tt)
			if tt.get("team") != "enemy" and not (c is Player):
				tt.team = "enemy"
		if pj.live(c) and c.get("model"):
			c.model.visible = true
			c.model.scale = Vector3.ONE * (float(c.model.age_scale) if "age_scale" in c.model else 1.0)
			_peel_up(pj, c)
			Combat.popup_text(c.global_position + Vector3.UP * 2.3, "Nefes bitti!", Color(0.85, 0.85, 0.95)))


## Yere yapışık mürekkep sürtmesi: a'dan b'ye uzayan şerit, sonra söner
static func _ink_slide(pj: PathJutsu, a: Vector3, b: Vector3, dur: float) -> void:
	var d = b - a
	d.y = 0.0
	var L = d.length()
	if L < 0.3:
		return
	var m = flat(Color(INK.r, INK.g, INK.b, 0.8))
	var bb = MB.new()
	bb.add("box", Vector3(0, 0, -0.5), Vector3(0.55, 0.01, 1.0), Color.WHITE)
	var mi = _mi(bb.build(), m)
	pj.scene_add(mi, a + Vector3.UP * 0.05)
	mi.global_basis = _basis_look(d)
	mi.scale = Vector3(1, 1, 0.05)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1, 1, L), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(0.3, 1, L), 0.6)
	tw.parallel().tween_method(func(x: float): m.set_shader_parameter("amount", x), 1.0, 0.0, 0.6)
	tw.tween_callback(mi.queue_free)


## Kâğıt silüet yerden kalkar (dikilir) ve söner; mürekkep damlaları
static func _peel_up(pj: PathJutsu, c: Node3D) -> void:
	var m = flat(Color(INK.r, INK.g, INK.b, 0.85), false, 1.5)
	var mi = _mi(_silhouette_mesh(), m)
	pj.scene_add(mi, pj.gp(c.global_position))
	mi.global_basis = Basis(Vector3.UP, atan2(-c.face_dir().x, -c.face_dir().z))
	var tw = mi.create_tween()
	tw.tween_property(mi, "rotation:x", -PI * 0.5, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): m.set_shader_parameter("amount", x), 1.0, 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	_bits(pj, c.global_position + Vector3.UP * 0.8, 7, 2.5, INK, 0.05, 0.6, Vector3.ZERO, 0.6, true)


# ================================================================== 6) Ten no Juin: Ichi no Dankai
## Ref (Sasuke 1. aşama): boyundaki mühürden kara alev desenleri GERÇEK tene yayılır (toon lanet deseni + yüz). Uyanışta
## boyundan başlayıp bedene doğru kara-mor alev dilleri kemiklerden fışkırır, ayakta koyu dalga; süre boyunca her saniye
## birkaç kara alev dili tüter (can erirken).
static func ten_no_juin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	if c.has_meta("fuja_until") and Time.get_ticks_msec() < int(c.get_meta("fuja_until")):   # Fūja Hōin bastırdı
		if c is Player:
			Hud.msg("Lanet mührü Fūja Hōin ile bastırılmış — şimdilik uyanmıyor.", Color(0.85, 0.3, 0.3))
		return
	var dur = 22.0
	_skin_marks(pj, c, 5, "juin_marks", dur)
	var bones = ["Neck", "UpperChest", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Head", "LeftUpperLeg", "RightUpperLeg"]
	for k in bones.size():
		_curse_lick(pj, c, bones[k], k * 0.06, 0.8)
	_ripple(pj, c.global_position + Vector3.UP * 0.08, Vector3.UP, 0.4, 4.5, 0.5, CURSE, Color(0.08, 0.02, 0.1), 0.7, false, 2.0)
	Sfx.play("genjutsu", c.global_position, 0.5)
	if c is Player:
		Buffs.add("juin1", dur, {"melee": 1.15, "jutsu": 1.12, "speed": 1.07, "_desc": "her sn canın %1'i erir"})
		Hud.msg("Lanetli mühür uyandı: güç akıyor... ama bedel ağır.", Color(0.8, 0.55, 0.95))
	pj.every(dur, 1.0, func(_i, _k):
		if is_instance_valid(c) and c.hp > c.max_hp * 0.15 and (not c is Player or Buffs.has("juin1")):
			c.hp -= c.max_hp * 0.01
			for q in 2:
				_curse_lick(pj, c, bones[randi() % bones.size()], q * 0.3, 0.6)
		elif c is Player:
			Buffs.remove("juin1"), Callable())


## Kemikten fışkıran kara-mor alev dili (kemiğe iliştirilir, beden boyunu izler)
static func _curse_lick(pj: PathJutsu, c: Node3D, bone: String, delay: float, s: float) -> void:
	pj.after(delay, func():
		if not pj.live(c):
			return
		var ba = pj.bone_attach(c, bone)
		if ba == null:
			return
		var m = energy(CURSE, Color(0.05, 0.01, 0.07), false, 3.0, 1.0)
		var mi = _mi(_flame_mesh(), m)
		ba.add_child(mi)
		mi.top_level = true
		mi.global_position = ba.global_position
		var cam = pj.get_viewport().get_camera_3d()
		var yaw = randf() * TAU
		if cam:
			var v = cam.global_position - ba.global_position
			yaw = atan2(v.x, v.z)
		mi.global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, randf_range(-0.5, 0.5))
		mi.scale = Vector3(0.3, 0.05, 0.3) * s
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(1.0, 0.55, 1.0) * s, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mi, "global_position", ba.global_position + Vector3.UP * 0.15, 0.5)
		tw.tween_method(func(x: float): m.set_shader_parameter("amount", x), 1.0, 0.0, 0.35)
		tw.tween_callback(ba.queue_free))


# ================================================================== 7) Senpō: Kawazu Naki
## Ref (Fukasaku + Shima): iki yaşlı kurbağa omuzlara oturur (mürekkep halkasıyla belirir), ağızlarından sırayla beyaz özlü,
## yeşil-sarı haleli uzun elips ses halkaları sarmal çizerek ileri yayılır. Duyanların başı çevresinde iki küçük ses halkası
## dönerek söner (genjutsuya hapsoldu).
static func senpo_kawazu_naki(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.6)
	pj.anim(c, "cast", 0.8)
	var elders = []
	var mouths = []
	var m = c.get("model")
	if m and m.skel:
		var sk: Skeleton3D = m.skel
		var chest_b = "UpperChest" if sk.find_bone("UpperChest") >= 0 else "Chest"
		for sx in [-1.0, 1.0]:
			var ua = "LeftUpperArm" if sx > 0 else "RightUpperArm"
			var sh_b = "LeftShoulder" if sx > 0 else "RightShoulder"
			if sk.find_bone(sh_b) < 0:
				sh_b = chest_b
			var p_ua: Vector3 = m._grest(sk.find_bone(ua)).origin
			var seat = p_ua + Vector3(sx * 0.035, 0.035, -0.01)
			var ba = m._attach(sh_b, Transform3D(Basis.IDENTITY, seat))
			var mi = _mi(_elder_mesh(pj, sx < 0), cel(Color.WHITE, 0.012))
			ba.get_child(0).add_child(mi)
			mi.scale = Vector3.ONE * 0.05
			mi.create_tween().tween_property(mi, "scale", Vector3.ONE * 0.62, 0.3).set_trans(Tween.TRANS_BACK)
			elders.append(ba)
			mouths.append(mi)
			var side = c.face_dir().cross(Vector3.UP) * -sx * 0.2
			_ink_pop(pj, c.global_position + Vector3.UP * 1.6 + side, 0.5, Color(0.2, 0.3, 0.12))
	Sfx.play("genjutsu", c.global_position, 0.5)
	for k in 16:
		pj.after(0.4 + k * 0.07, func():
			if not pj.live(c):
				return
			var fd: Vector3 = c.face_dir()
			fd.y = 0
			fd = fd.normalized()
			var o = c.global_position + Vector3.UP * 1.7 + fd * 0.4
			if mouths.size() == 2 and is_instance_valid(mouths[k % 2]):
				o = (mouths[k % 2] as Node3D).global_position + Vector3.UP * 0.12 + fd * 0.2
			var mm = _shader_mat("ring", RING_SH)
			mm.set_shader_parameter("core", SONG_HI)
			mm.set_shader_parameter("halo", SONG)
			mm.set_shader_parameter("near_fade", 1.6)
			var ring = _mi(_song_torus(), mm)
			pj.get_tree().current_scene.add_child(ring)
			ring.global_position = o
			var bas = Basis.looking_at(fd, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, randf_range(-0.25, 0.25))
			ring.global_basis = bas
			var ph = k * 0.9
			var tw = ring.create_tween()
			tw.tween_method(func(u: float):
				if is_instance_valid(ring):
					ring.global_position = o + fd * u * 22.0 + Vector3(cos(ph + u * 6.0), sin(ph + u * 6.0), 0).rotated(Vector3.UP, atan2(fd.x, fd.z)) * u * 0.8
					var s = 0.4 + u * 3.6
					ring.global_basis = bas.scaled_local(Vector3(s, s, s * 1.55))
					mm.set_shader_parameter("amount", 1.0 - u), 0.0, 1.0, 1.1)
			tw.tween_callback(ring.queue_free))
	pj.after(1.2, func():
		for e in pj.enemies_near(c, c.global_position, 26.0):
			pj.st(e, "stun", 6.0)
			_song_trap(pj, e)
			Combat.popup_text(e.global_position + Vector3.UP * 2.4, "Kurbağa şarkısı!", PathJutsu.SAGE))
	pj.after(6.0, func():
		for ba in elders:
			if is_instance_valid(ba):
				ba.queue_free())


static func _song_torus() -> Mesh:
	var key = "mesh:song_torus"
	if _cache.has(key):
		return _cache[key]
	var tm = TorusMesh.new()
	tm.inner_radius = 0.93
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	_cache[key] = tm
	return tm


## Duyanın başı çevresinde dönen iki küçük ses halkası
static func _song_trap(pj: PathJutsu, e: Node3D) -> void:
	if not is_instance_valid(e):
		return
	var h = float(e.get("height")) if e.get("height") != null else 1.8
	var root = Node3D.new()
	e.add_child(root)
	root.position = Vector3.UP * (h * 0.92)
	var mats = []
	for k in 2:
		var mm = _shader_mat("ring", RING_SH)
		mm.set_shader_parameter("core", SONG_HI)
		mm.set_shader_parameter("halo", SONG)
		mm.set_shader_parameter("near_fade", 1.2)
		var r = _mi(_song_torus(), mm)
		root.add_child(r)
		r.rotation = Vector3(0.5 if k == 0 else -0.6, 0, 0.3 if k == 0 else -0.2)
		r.scale = Vector3.ONE * (0.38 + k * 0.1) * maxf(1.0, h / 1.8)
		mats.append(mm)
	var setamt = func(x: float) -> void:
		for mm in mats:
			mm.set_shader_parameter("amount", x)
	var tw = root.create_tween()
	tw.tween_property(root, "rotation:y", TAU * 1.5, 1.8)
	tw.parallel().tween_method(setamt, 1.0, 0.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


# ================================================================== 8) Senpō: Ryōsei no Jutsu
## Ref (Jiraiya omuzlarında Fukasaku / Shima): yaşlı kurbağalar omuzlarda; ağızlarından altı yeşil ses dalgası ileri halka
## halka açılır. Hedefin çevresinde yeşil mürekkep sarmalı daralır, beden kaybolur ve yerine GERÇEK kurbağa çağrı modeli
## (zıplar gibi esneyerek) belirir; süre sonunda kurbağa basılıp kaybolur, beden mürekkep halkasıyla geri gelir.
static func senpo_ryosei_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 1.2)
	var parts = []
	var emat = cel(Color.WHITE, 0.012)
	for sx in [-1.0, 1.0]:
		var sh = pj.bone_attach(c, "LeftShoulder" if sx < 0 else "RightShoulder")
		if sh:
			var toad = _mi(_elder_mesh(pj, sx > 0), emat)
			sh.add_child(toad)
			toad.scale = Vector3.ONE * 0.18
			toad.position = Vector3(0, 0.08, 0)
			parts.append(toad)
	for k in 6:
		pj.after(k * 0.15, func():
			if pj.live(c):
				var fd = c.face_dir()
				var mm = _shader_mat("ring", RING_SH)
				mm.set_shader_parameter("core", Color(0.9, 1.0, 0.85))
				mm.set_shader_parameter("halo", Color(0.4, 0.9, 0.45))
				mm.set_shader_parameter("near_fade", 1.6)
				var ring = _mi(_song_torus(), mm)
				pj.scene_add(ring, c.global_position + Vector3.UP * 1.6 + fd * 0.4)
				var bas = _basis_look(fd) * Basis(Vector3.RIGHT, PI * 0.5)
				ring.global_basis = bas.scaled_local(Vector3.ONE * 0.4)
				var o = ring.global_position
				var r1 = 3.0 + k
				var tw = ring.create_tween()
				tw.tween_method(func(u: float):
					if is_instance_valid(ring):
						ring.global_position = o + fd * u * r1 * 0.8
						ring.global_basis = bas.scaled_local(Vector3.ONE * lerpf(0.4, r1 * 0.45, u))
						mm.set_shader_parameter("amount", 1.0 - u), 0.0, 1.0, 0.4)
				tw.tween_callback(ring.queue_free))
	pj.after(1.2, func():
		for pp in parts:
			if is_instance_valid(pp):
				pp.queue_free())
	if tt == null:
		return
	_ink_spiral(pj, tt, 0.9)
	pj.after(0.9, func():
		if not (pj.live(c) and pj.live(tt)):
			return
		var h = float(tt.get("height")) if tt.get("height") != null else 1.8
		var res: Dictionary = SummonModels.build("toad_mid", clampf(h * 0.6, 0.9, 1.4), clampf(h * 0.6, 0.9, 1.4))
		var toad: Node3D = res["root"]
		tt.add_child(toad)
		ClanJutsu.fit_body(tt, toad)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		toad.scale = Vector3(1.3, 0.3, 1.3)
		var bt = toad.create_tween()
		bt.tween_property(toad, "scale", Vector3(0.85, 1.25, 0.85), 0.12)
		bt.tween_property(toad, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_ink_pop(pj, tt.global_position + Vector3.UP, 1.2, Color(0.15, 0.35, 0.12))
		var m = tt.get("model")
		if m:
			m.visible = false
		pj.st(tt, "stun", 4.0)
		tt.take_hit(pj.inf(c, "senpo_ryosei_no_jutsu", 1.0, {"knock": 0.0, "kind": "heavy"}))
		pj.get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(toad):
				toad.queue_free()
			if is_instance_valid(tt):
				_ink_pop(pj, tt.global_position + Vector3.UP, 1.0, Color(0.15, 0.35, 0.12))
				if m and is_instance_valid(m):
					m.visible = true))
	Sfx.play("genjutsu", c.global_position, 1.1)


## Hedefin çevresinde yükselip daralan yeşil mürekkep sarmalı (dönüşüm anı)
static func _ink_spiral(pj: PathJutsu, tt: Node3D, dur: float) -> void:
	var h = float(tt.get("height")) if tt.get("height") != null else 1.8
	var bs = ClanJutsu.body_scale(tt)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 60
	for i in n:
		var u0 = float(i) / n
		var u1 = float(i + 1) / n
		var a0 = u0 * TAU * 3.0
		var a1 = u1 * TAU * 3.0
		var p0 = Vector3(cos(a0) * 0.75, u0 * h * 1.1, sin(a0) * 0.75)
		var p1 = Vector3(cos(a1) * 0.75, u1 * h * 1.1, sin(a1) * 0.75)
		var w = 0.07
		for v in [[p0, 0.0], [p0 + Vector3.UP * w * 2.0, 1.0], [p1 + Vector3.UP * w * 2.0, 1.0], [p0, 0.0], [p1 + Vector3.UP * w * 2.0, 1.0], [p1, 0.0]]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(1, 1, 1, 0.5 + 0.5 * float(v[1])))
			st.add_vertex(v[0])
	var m = flat(Color(0.25, 0.75, 0.25, 0.9), false, 1.5)
	var mi = _mi(st.commit(), m)
	tt.add_child(mi)
	mi.scale = Vector3(1.6 * bs, 0.2 * bs, 1.6 * bs)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.0 * bs, 1.0 * bs, 1.0 * bs), dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "rotation:y", PI * 2.0, dur)
	tw.tween_property(mi, "scale", Vector3(0.1 * bs, 1.1 * bs, 0.1 * bs), dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


# ================================================================== 9) Zessenzan
## Ref (Fukasaku): ağızdan dümdüz, açık mavi, yassı bıçak gibi uzun dil fırlar ve yatay süpürür; ardında beyaz kenarlı açık
## mavi kesik yayı açılıp söner, zeminde yay biçimli ince sıyrık kalır.
static func zessenzan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	var d = pj._face(c, tt)
	pj.busy(c, 0.5)
	var tm = flat(Color(TONGUE.r, TONGUE.g, TONGUE.b, 1.0), false, 1.0)
	var tongue = _mi(_tongue_mesh(), tm)
	pj.scene_add(tongue, pj._mouth_pos(c))
	tongue.global_basis = _basis_look(d.rotated(Vector3.UP, -1.2)).scaled_local(Vector3(1, 1, 0.1))
	pj.every(0.35, 1.0 / 30.0, func(_i, k):
		if not pj.live(c) or not is_instance_valid(tongue):
			return
		var a = lerpf(-1.2, 1.2, k)
		tongue.global_position = pj._mouth_pos(c)
		tongue.global_basis = _basis_look(d.rotated(Vector3.UP, a)).scaled_local(Vector3(1, 1, 6.5 * minf(1.0, k * 6.0 + 0.15))), func():
		if is_instance_valid(tongue):   # dil geri çekilir
			var rt = tongue.create_tween()
			rt.tween_property(tongue, "scale", Vector3(1, 1, 0.05), 0.1)
			rt.tween_callback(tongue.queue_free))
	var am = _shader_mat("arc", ARC_SH)
	am.set_shader_parameter("col", TONGUE)
	am.set_shader_parameter("near_fade", 1.5)
	var arc = _mi(_crescent_mesh(1.0, 6.5, 140.0), am)
	pj.scene_add(arc, pj._mouth_pos(c))
	arc.global_basis = _basis_look(d)
	var tw = arc.create_tween()
	tw.tween_method(func(x: float): am.set_shader_parameter("head", x), 0.0, 1.0, 0.35)
	tw.tween_method(func(x: float): am.set_shader_parameter("amount", x), 1.0, 0.0, 0.25)
	tw.tween_callback(arc.queue_free)
	var sm = _shader_mat("arc", ARC_SH)   # zeminde sıyrık
	sm.set_shader_parameter("col", Color(0.18, 0.15, 0.13))
	sm.set_shader_parameter("edge", Color(0.3, 0.26, 0.22))
	sm.set_shader_parameter("tail", 1.2)
	sm.set_shader_parameter("near_fade", 0.0)
	var scr = _mi(_crescent_mesh(5.6, 6.3, 140.0), sm)
	pj.scene_add(scr, pj.gp(c.global_position) + Vector3.UP * 0.06)
	scr.global_basis = _basis_look(d)
	var stw = scr.create_tween()
	stw.tween_method(func(x: float): sm.set_shader_parameter("head", x), 0.0, 1.0, 0.35)
	stw.tween_interval(1.0)
	stw.tween_method(func(x: float): sm.set_shader_parameter("amount", x), 1.0, 0.0, 0.8)
	stw.tween_callback(scr.queue_free)
	Combat.hit_zone(c, c.global_position, d, 6.5, 70.0, 2.5, pj.inf(c, "zessenzan", 1.0, {"knock": 8.0, "kind": "heavy", "bleed": 2.0}))
	Sfx.play("whoosh", c.global_position, 1.0)


# ================================================================== 10) Senpō: Chōōdama Rasen Tarengan
## Ref (dev Rasengan kümesi): kullanıcıya turuncu doğa enerjisi çekilir, gözünde kurbağa bilge izi belirir. Başının üstünde
## sekiz dev Rasengan (beyaz çekirdek, dönen sarmal bantlar, mavi kenar, titreşen diken halesi) büyür, hedefe dalar ve
## her biri ayrı noktaya sırayla iner: yeri sarmal çizerek öğütür, çakıl teğet savrulur, toz eteği; sonra söner.
static func senpo_choodama_rasen_tarengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 2.0)
	var tt = pj.tg(c, t, 28.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	_gather(pj, c.global_position + Vector3.UP * 1.0, 4.0, 60, 1.2, NAT, NAT_HI)
	_sage_face(pj, c, 1, 2.6)
	var cluster = Node3D.new()
	var balls = []
	for k in 8:
		var r = _rasengan(randf_range(1.2, 1.7))
		r.position = Vector3(randf_range(-3, 3), randf_range(-1.5, 2.5), randf_range(-3, 3))
		cluster.add_child(r)
		balls.append(r)
	pj.get_tree().current_scene.add_child(cluster)
	cluster.global_position = c.global_position + Vector3.UP * 6.0
	cluster.scale = Vector3.ONE * 0.1
	var tw = cluster.create_tween()
	tw.tween_property(cluster, "scale", Vector3.ONE, 0.6)
	tw.tween_property(cluster, "global_position", at + Vector3.UP * 3.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var scn = pj.get_tree().current_scene
		for k in balls.size():
			var b: Node3D = balls[k]
			if not is_instance_valid(b):
				continue
			var off = b.global_position - at
			b.reparent(scn)
			var land = pj.gp(at + Vector3(clampf(off.x, -5.0, 5.0), 0, clampf(off.z, -5.0, 5.0)))
			_rasen_land(pj, b, land, k * 0.05)
		GroundFX.add(at, "cracked", 12.0 * 0.6, 5.0)   # yarık zemin: üstünden geçen yavaşlar
		_cracks(pj, at, 12.0, 12, Color(0.08, 0.07, 0.08, 0.85), 4.0)
		pj.hit(c, at + Vector3.UP, 9.0, pj.inf(c, "senpo_choodama_rasen_tarengan", 3.5, {"knock": 24.0, "launch": 8.0, "kind": "heavy", "hitstop": 0.12}))
		pj.shake(1.6)
		cluster.queue_free())
	Sfx.play("wind", c.global_position, 0.4)


## Tek dev Rasengan: girdap küresi + diken halesi
static func _rasengan(r: float) -> Node3D:
	var root = Node3D.new()
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	var m = _shader_mat("rasen", RASEN_SH)
	m.set_shader_parameter("rim_col", RASEN)
	m.set_shader_parameter("core_col", RASEN_HI)
	m.set_shader_parameter("near_fade", 6.0)
	m.set_shader_parameter("spin", randf_range(12.0, 18.0))
	var core = _mi(sm, m)
	core.scale = Vector3.ONE * r
	root.add_child(core)
	var hm = _shader_mat("halo", HALO_SH)
	hm.set_shader_parameter("col", Color(0.55, 0.75, 1.0))
	hm.set_shader_parameter("near_fade", 6.0)
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	var halo = _mi(q, hm)
	halo.scale = Vector3.ONE * r * 2.7
	root.add_child(halo)
	root.set_meta("mats", [m, hm])
	root.set_meta("r", r)
	return root


## Rasengan iner, yeri sarmal öğütür ve söner
static func _rasen_land(pj: PathJutsu, b: Node3D, land: Vector3, delay: float) -> void:
	var r = float(b.get_meta("r", 1.4))
	var mats: Array = b.get_meta("mats", [])
	var tw = b.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(b, "global_position", land + Vector3.UP * r * 0.55, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_spiral_scar(pj, land, r * 1.9, 3.0)
		_dust_skirt(pj, land, r * 0.8, r * 3.2, 0.6, DUSTC)
		var db = Bits.new()   # teğet savrulan çakıl
		db.life = 1.0
		pj.get_tree().current_scene.add_child(db)
		db.global_position = Vector3.ZERO
		db.floor_y = land.y
		var rm = cel(ROCK, 0.006)
		var mesh = _bit_mesh(false)
		for i in 10:
			var a = randf() * TAU
			var rad = Vector3(cos(a), 0, sin(a))
			var tang = Vector3(-sin(a), 0, cos(a))
			var mi = _mi(mesh, rm)
			db.add_child(mi)
			mi.global_position = land + rad * r * 0.8 + Vector3.UP * 0.2
			mi.scale = Vector3.ONE * randf_range(0.12, 0.25)
			db.items.append([mi, (tang * 7.0 + rad * 2.5 + Vector3.UP * randf_range(2.0, 5.0)), Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()]))
	tw.tween_property(b, "scale", Vector3.ONE * 1.35, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "global_position", land + Vector3.UP * r * 0.35, 0.35)
	var setamt = func(x: float) -> void:
		for mm in mats:
			if is_instance_valid(mm):
				mm.set_shader_parameter("amount", x)
	tw.tween_method(setamt, 1.0, 0.0, 0.3)
	tw.tween_callback(b.queue_free)


# ================================================================== 11) Hakuja Sennin Mōdo
## Beyaz yılan bilge modu: ten soluk beyaza döner, yılan bilge izi (mor göz çizgisi + yarık göz) GERÇEK yüze çizilir; çevreden
## soluk lila doğa enerjisi çekilir, yerde yavaş genişleyen soluk dalga. Sezilen düşmanların ayağında soluk halka. Her
## tikte bedenden beyaz pul kıymıkları dökülür; en yakın düşmana oyunun gerçek yılan gövdesiyle beyaz yılan atılır, ısırır
## (mor zehir damlaları).
static func hakuja_sennin_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var dur = 30.0
	_tint_for(pj, c, SNAKE_W, 0.38, dur)
	_sage_face(pj, c, 2, dur)
	_gather(pj, c.global_position + Vector3.UP * 1.0, 3.5, 50, 1.0, Color(0.85, 0.82, 1.0), Color.WHITE)
	_ripple(pj, c.global_position + Vector3.UP * 0.2, Vector3.UP, 0.5, 14.0, 0.9, Color(0.9, 0.9, 1.0), Color.WHITE, 0.92, false, 3.0)
	Sfx.play("heal", c.global_position, 0.7)
	if c is Player:
		Buffs.add("hakuja", dur, {"melee": 1.12, "armor": 0.92, "jutsu": 1.08})
	for e in pj.enemies_near(c, c.global_position, 34.0):
		pj.st(e, "marked", dur)
		_ripple(pj, e.global_position + Vector3.UP * 0.1, Vector3.UP, 0.3, 1.4, 0.6, Color(0.92, 0.92, 1.0), Color.WHITE, 0.8, true, 2.0)
		Combat.popup_text(e.global_position + Vector3.UP * (e.height + 0.8), "Sezildi", Color(0.9, 0.9, 1.0))
	pj.every(dur, 1.4, func(i, _k):
		if not is_instance_valid(c) or (c is Player and not Buffs.has("hakuja")):
			return
		if i % 2 == 0:
			pj.heal(c, c.max_hp * 0.03)
		_scale_flakes(pj, c, 3)
		var near = pj.enemies_near(c, c.global_position, 13.0)
		if near.is_empty():
			return
		var e = near[i % near.size()]
		_white_snake(pj, c, e), Callable())


static func _scale_flakes(pj: PathJutsu, c: Node3D, n: int) -> void:
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(0.07, 0.07, 0.006), Color.WHITE, Vector3(0, 0, 45))
	var mesh = b.build()
	var m = cel(SNAKE_W, 0.004, 0.0, 0.4, Color(0.85, 0.8, 1.0))
	for k in n:
		var a = randf() * TAU
		var p = c.global_position + Vector3(cos(a) * 0.3, randf_range(0.5, 1.6), sin(a) * 0.3)
		var mi = _mi(mesh, m)
		pj.scene_add(mi, p)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", p + Vector3(cos(a) * 0.5, 0.6, sin(a) * 0.5), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mi, "rotation:y", mi.rotation.y + 4.0, 0.8)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.05, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


## Gövdeden atılan beyaz yılan (SleeveSnake): ısırır, zehir (ana ağaçtaki poison ile aynı hasar çağrısı)
static func _white_snake(pj: PathJutsu, c: Node3D, e: Node3D) -> void:
	var end = e.global_position + Vector3.UP * e.height * 0.6
	var sn = SleeveSnake.new()
	sn.back_col = SNAKE_W
	sn.belly_col = SNAKE_B
	sn.radius = 0.075
	sn.anchor = _track(c, Vector3.UP * 1.1)
	var dv = end - c.global_position
	sn.aim_dir = dv.normalized() if dv.length() > 0.01 else c.face_dir()
	sn.target = null
	sn.free_to = end
	sn.side = randf_range(-0.35, 0.35)
	sn.lift = 0.25
	sn.phase = randf() * 2.0
	pj.get_tree().current_scene.add_child(sn)
	sn.set_head(_snake_head(0.24))
	sn.extend(0.25, func():
		if pj.live(e):
			pj.hit(c, e.global_position + Vector3.UP * e.height * 0.6, e.radius + 0.6, pj.inf(c, "hakuja_sennin_modo", 0.35, {"knock": 1.0, "kind": "light", "burn": 3.0, "hitstop": 0.03}))
			_bits(pj, end, 7, 2.5, VENOM, 0.06, 0.5, -dv, 0.7, true))
	pj.get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(sn):
			sn.retract(0.25))


# ================================================================== 12) Gama no Hihō
## Ref (kurbağaların şifa mührü): önünde krem kâğıtlı, yeşil iç alanlı, ortada daire içinde "仙" yazılı parşömen açılır;
## arkasından dönen yeşil şifa ışınları yayılır, ayakta yeşil mühür çemberi parlar, bedenden yeşil zerreler yükselir.
## İyileşme anında yeşil halka ayaktan başa çıkar.
static func gama_no_hiho(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.2)
	var fd = c.face_dir()
	var o = c.global_position + Vector3.UP * 1.0 + fd * 0.5
	var sm = _mi(_heal_scroll_mesh(), cel(Color.WHITE, 0.006, 0.0, 0.5, HEAL))
	pj.scene_add(sm, o)
	sm.global_basis = _basis_look(fd) * Basis(Vector3.RIGHT, 0.9)
	sm.scale = Vector3(0.1, 1, 1)
	var st = sm.create_tween()
	st.tween_property(sm, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rm = flat(Color(HEAL.r, HEAL.g, HEAL.b, 0.75), true, 1.0)
	var rays = _mi(_rays_mesh(14), rm)
	sm.add_child(rays)
	rays.position = Vector3(0, -0.02, 0)
	rays.scale = Vector3.ONE * 0.1
	var rt = rays.create_tween()
	rt.tween_property(rays, "scale", Vector3.ONE * 1.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(rays, "rotation:y", 1.2, 1.2)
	_ink_seal(pj, pj.gp(c.global_position) + Vector3.UP * 0.07, 1.5, Color(HEAL.r, HEAL.g, HEAL.b, 0.8), 0.8, Vector3.UP, true)
	_motes(pj, c.global_position + Vector3.UP * 0.6, 0.5, 30, 1.0, HEAL, HEAL_HI)
	pj.after(0.6, func():
		if pj.live(c):
			pj.heal(c, c.max_hp * 0.35)
			var hm = energy(HEAL, HEAL_HI, true, 3.0, 1.0)
			var hr = _mi(_ring_mesh(0.8, 1.0), hm)
			pj.scene_add(hr, c.global_position + Vector3.UP * 0.1)
			hr.scale = Vector3.ONE * 0.8
			var ht = hr.create_tween()
			ht.tween_property(hr, "global_position", c.global_position + Vector3.UP * 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			ht.parallel().tween_property(hr, "scale", Vector3.ONE * 0.45, 0.45)
			ht.parallel().tween_method(func(x: float): hm.set_shader_parameter("amount", x), 1.0, 0.0, 0.45)
			ht.tween_callback(hr.queue_free))
	_fade(rays, rm, 0.9, 0.3, false)
	_shrink(sm, 1.2, 0.4)
	Sfx.play("heal", c.global_position, 1.0)


# ================================================================== 13) Ura Shishō Fūin
## Ref (Danzō'nun mühür formülü): göğse dört yönde üçlü kara çizgi sembolleri fırça darbesiyle sırayla çizilir; ortadan
## küçük ince mürekkep çizgileri dışa kıvrılarak açılıp söner. Yalnız mühür çizilir (asıl kara küre ölümde tetiklenir).
static func ura_shisho_fuin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.2)
	var ch = pj.bone_attach(c, "UpperChest")
	if ch:
		var groups = [Vector2(0, 0.11), Vector2(0.1, 0.01), Vector2(0, -0.09), Vector2(-0.1, 0.01)]
		var mat = cel(INK, 0.0)
		for gi in groups.size():
			var g: Vector2 = groups[gi]
			var gb = MB.new()
			for q in 3:
				var y = g.y + (q - 1) * 0.022
				if (int(g.x * 100) + q) % 2 == 0:
					gb.add("box", Vector3(0, 0.05 + y, 0.14), Vector3(0.07, 0.012, 0.006), Color.WHITE)
				else:
					for hx in [-1.0, 1.0]:
						gb.add("box", Vector3(hx * 0.021, 0.05 + y, 0.14), Vector3(0.028, 0.012, 0.006), Color.WHITE)
			var mi = _mi(gb.build(), mat)
			ch.add_child(mi)
			mi.position = Vector3(g.x, 0, 0)
			mi.scale = Vector3(0.02, 1, 1)
			var tw = mi.create_tween()
			tw.tween_interval(0.08 + gi * 0.18)
			tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var lm = flat(Color(INK.r, INK.g, INK.b, 0.9), false, 0.6)   # dışa açılan ince mürekkep çizgileri
		var lb = MB.new()
		for k in 16:
			var a = TAU * k / 16.0 + randf_range(-0.1, 0.1)
			var L = randf_range(0.12, 0.26)
			lb.add("box", Vector3(cos(a), sin(a), 0) * (0.05 + L * 0.5) + Vector3(0, 0.06, 0.145), Vector3(L, 0.006, 0.003), Color.WHITE, Vector3(0, 0, rad_to_deg(a)))
		var lines = _mi(lb.build(), lm)
		ch.add_child(lines)
		lines.scale = Vector3(0.2, 0.2, 1)
		var lt = lines.create_tween()
		lt.tween_interval(0.75)
		lt.tween_property(lines, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		lt.tween_method(func(x: float): lm.set_shader_parameter("amount", x), 1.0, 0.0, 0.35)
		pj.free_after(1.4, ch)
	c.set_meta("ura_shisho", true)
	if c is Player:
		Buffs.add("ura_shisho", 600.0, {"_name": "Ura Shishō Fūin", "_desc": "ölürsen çevrendekileri bedenine mühürlersin"})
		Hud.msg("Mühür göğsüne çizildi: ölürsen çevrendekileri de götürürsün.", Color(0.75, 0.75, 0.8), 3.0)
	elif c.has_method("add_buff"):
		c.add_buff("ura_shisho", 600.0, {})
	Sfx.play("seal", c.global_position, 0.5)


# ================================================================== 14) Taiju Kaihō (Hashirama hücresi, MokutonLib)
## Avuç yere: avucun dibinde yarık, beş ince kök zemine yapışık sürünerek ağacın yerine koşar. Orada dev ağaç gerçek zamanlı
## kökten tepeye büyür (dallanır, uçlarında yaprak savrulur), dibinden sekiz kalın kök dışa taşar; zeminde ışınsal yarık,
## kıymık ve toprak topakları, toz halkası. Ağaç durduğu sürece atılanları keser (kıymık sıçrar), sonra kuruyup gömülür.
static func taiju_kaiho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var id = "taiju_kaiho"
	var tt = pj.tg(c, t, 9.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.5)
	var q: Vector3 = pj.gp(c.global_position + d * 3.4)
	if tt and tt.global_position.distance_to(c.global_position) < 9.0:
		q = pj.gp(c.global_position + d * clampf(c.global_position.distance_to(tt.global_position), 2.8, 6.0))
	var cw = weakref(c)
	var hand_g = pj.gp(c.global_position + d * 0.5)
	ML.scar(pj, hand_g, 1.1, 1.6, {"lines": 7.0, "pit": 0.2})
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var L0 = maxf(0.5, q.distance_to(c.global_position) - 0.3)
	for k in 5:   # kökler elden ağacın yerine sürünür
		var a = (k - 2) * 0.22
		var g = ML.Geo.new()
		var res = ML.tree(g, Vector3(0, 0.08, 0), d.rotated(Vector3.UP, a), L0, 0.12, {"rng": rng, "hug": true, "org": hand_g, "lift": 0.06, "arch": 0.08,
			"bend": 0.3, "depth": 0, "tip": 0.3, "sides": 6, "seg_len": 0.5})
		var mi = ML.inst(pj, g.build(), hand_g, {"taper": 0.6, "ow": 0.02, "seed": k * 1.7, "nf": 2.0})
		ML.life(mi, float(res["len"]), 0.38, 0.6, 0.4, k * 0.02, {"out": "sink", "depth": 0.3, "taper": 0.6})
	Sfx.play("earth", c.global_position, 0.8)
	pj.after(0.38, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var g = ML.Geo.new()
		var res = ML.tree(g, Vector3.ZERO, Vector3.UP, 17.0, 1.6, {"rng": rng, "depth": 2, "kids": 3, "spread": 0.8, "tip": 0.14, "bend": 0.14,
			"seg_len": 1.6, "sides": 12, "gnarl": 0.12, "up": Vector3.UP * 0.12, "cap_end": false})
		var tree = ML.inst(pj, g.build(), q, {"taper": 2.0, "ow": 0.06, "nf": 7.0, "seed": rng.randf() * 10.0})
		ML.life(tree, float(res["len"]), 0.45, 2.2, 0.55, 0.0, {"out": "sink", "depth": 6.0, "taper": 2.0})
		var tips: Array = res["tips"]
		pj.after(0.45, func():
			for i in mini(tips.size(), 9):
				ML.leaves(pj, q + (tips[i] as Vector3), 9, 4.0, {"size": 0.5}))
		var g2 = ML.Geo.new()   # gövdenin dibinden dışa taşan kalın kökler
		var rl = 0.0
		for k in 8:
			var a = TAU * k / 8.0 + rng.randf() * 0.3
			var r2 = ML.tree(g2, Vector3(0, 0.2, 0), Vector3(cos(a), 0, sin(a)), rng.randf_range(3.5, 5.5), 0.45, {"rng": rng, "hug": true, "org": q,
				"lift": 0.15, "arch": 0.35, "bend": 0.3, "depth": 0, "tip": 0.2, "sides": 8, "seg_len": 0.7})
			rl = maxf(rl, float(r2["len"]))
		var roots = ML.inst(pj, g2.build(), q, {"taper": 1.0, "ow": 0.04, "nf": 4.0})
		ML.life(roots, rl, 0.3, 2.4, 0.5, 0.05, {"out": "sink", "depth": 1.0, "taper": 1.0})
		ML.scar(pj, q, 4.5, 3.6, {"lines": 12.0, "pit": 0.7})
		var soil = ML.soil_col(q)
		ML.chips(pj, q + Vector3.UP * 0.4, 18, 9.0, {"col": soil, "col2": soil.lightened(0.2), "size": 0.42})
		ML.splinters(pj, q + Vector3.UP * 0.6, 4, 1.0, 8.0, {"col": soil})
		ML.dust_ring(pj, q, 2.6, 10, 1.7, 1.4)
		pj.shake(0.7)
		Sfx.play("boom", q, 0.75)
		for e in pj.enemies_near(cc, q, 5.6):
			if not is_instance_valid(e) or e.is_dead():
				continue
			var v: Vector3 = e.global_position - q
			v.y = 0
			var dirv = v.normalized() if v.length() > 0.2 else d
			e.take_hit(pj.inf(cc, id, 2.3, {"knock": 26.0, "launch": 6.5, "kind": "heavy", "element": "mokuton", "hitstop": 0.08, "dir": dirv}))
		var guard = func(_i, _k):   # savunma: gövde atılanları keser
			var c2 = cw.get_ref()
			for p in pj.get_tree().get_nodes_in_group("projectiles"):
				if is_instance_valid(p) and p.get("shooter") != c2 and Vector2(p.global_position.x - q.x, p.global_position.z - q.z).length() < 2.2 and p.global_position.y < q.y + 14.0:
					ML.chips(pj, p.global_position, 6, 5.0, {"size": 0.25})
					p.queue_free()
		pj.every(3.2, 0.06, guard))


# ================================================================== 15) Bakuretsu Jusō (Hashirama hücresi, MokutonLib)
## Ref (Danzō): koldan dört kök birbirine sarmal dolanarak hedefe fışkırır (kökler gerçek zamanlı büyür); uçta sivri dallar
## her yöne patlar — tek parça kıymık yıldızı, kan damlaları, ahşap kıymıkları; sonra kola geri çekilir.
static func bakuretsu_juso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "bakuretsu_juso"
	var tt = pj.tg(c, t, 16.0)
	var _d = pj._face(c, tt)
	pj.anim(c, "push", 1.5)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	Sfx.play("earth", c.global_position, 1.2)
	pj.after(0.18, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var from = pj.hand_pos(cc)
		var to: Vector3 = from + cc.face_dir() * 11.0
		if x and pj.live(x):
			to = x.global_position + Vector3.UP * 1.0
		var dv = (to - from).normalized()
		var L = minf(from.distance_to(to), 16.0)
		to = from + dv * L
		var sd = dv.cross(Vector3.UP).normalized()
		if sd.length() < 0.1:
			sd = Vector3.RIGHT
		var up2 = sd.cross(dv).normalized()
		for k in 4:   # dört kök sarmal dolanarak aynı noktaya gider
			var ph = k * TAU / 4.0
			var pts: Array = []
			var radii: Array = []
			for i in 14:
				var u = float(i) / 13.0
				var tw2 = ph + u * TAU * 0.85
				var rad = 0.24 * sin(u * PI) + 0.04
				pts.append(dv * L * u + (sd * cos(tw2) + up2 * sin(tw2)) * rad)
				radii.append(lerpf(0.11, 0.05, u))
			var g = ML.Geo.new()
			var rlen = ML.tube(g, pts, radii, {"sides": 7, "gnarl": 0.1, "seed": k * 2.1, "cap_end": false})
			var mi = ML.inst(pj, g.build(), from, {"taper": 0.8, "ow": 0.025, "seed": k * 1.3, "nf": 2.5})
			ML.life(mi, rlen, 0.16, 0.9, 0.3, k * 0.03, {"taper": 0.8})
		ML.chips(pj, from, 5, 5.0, {"dir": dv, "spread": 40.0, "size": 0.2})
		for k in 3:   # saplanış: yol boyunca üç vuruş
			pj.after(0.08 + k * 0.05, func():
				var c2 = cw.get_ref()
				if c2 == null or not pj.live(c2):
					return
				Combat.hit_zone(c2, from, dv, L + 0.6, 12.0, 2.4, pj.inf(c2, id, 0.6, {"knock": 2.0, "kind": "heavy", "element": "mokuton", "bleed": 3.0, "hitstop": 0.03})))
		pj.after(0.34, func():   # uçta dallar patlar
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			var g = ML.Geo.new()
			var sl = 0.0
			for k in 12:
				var dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
				dir = (dir + dv * 0.35).normalized()
				var Ls = 1.9 * randf_range(0.7, 1.2)
				var pts: Array = [Vector3.ZERO, dir * Ls * 0.35, dir * Ls * 0.7, dir * Ls]
				sl = maxf(sl, ML.tube(g, pts, [0.09, 0.07, 0.04, 0.0], {"sides": 5, "hard": true, "cap_end": false}))
			var burst = ML.inst(pj, g.build(), to, {"taper": 0.3, "ow": 0.02, "nf": 2.5})
			ML.life(burst, sl, 0.07, 0.5, 0.25, 0.0, {"taper": 0.3})
			ML.splinters(pj, to, 5, 0.6, 7.0)
			ML.chips(pj, to, 12, 7.0, {"size": 0.3})
			_bits(pj, to, 8, 4.0, BLOOD, 0.05, 0.4, Vector3.ZERO, 0.8, true)
			pj.shake(0.4)
			Sfx.play("th_wood", to, 0.8)
			pj.hit(c2, to, 3.0, pj.inf(c2, id, 1.6, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "element": "mokuton", "bleed": 4.0, "hitstop": 0.07}))))


# ================================================================== 16) Ne Bakusō (Hashirama hücresi, MokutonLib)
## Koldan üç iri kök toprağa dalar (dalış yerinde yarık + toprak topağı); toprağın altındaki ilerleyiş yol boyunca kabaran
## toprakla görünür. Hedefin altından altı kalın kök yükselip tepede birbirine kapanır, içeride bir kök hedefe sarmal
## dolanır. 1.7 sn sonra kökler sıkışıp parçalanır: kıymık ve kabuk yağmuru, sonra kuruyup toprağa gömülür.
static func ne_bakuso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Ne Bakusō: köklerin yükseleceği hedef yok", Color(0.8, 0.7, 0.5))
		return
	pj.busy(c, 1.1)
	var id = "ne_bakuso"
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.5)
	var cw = weakref(c)
	var tw = weakref(tt)
	var hp = pj.hand_pos(c)
	var dig: Vector3 = pj.gp(c.global_position + d * 2.6)
	for k in 3:   # koldan çıkan kökler toprağa dalar
		var end = dig + d.cross(Vector3.UP) * (k - 1) * 0.45 - Vector3.UP * 0.3
		var mid = (hp + end) * 0.5 + Vector3.UP * 0.35
		var pts = ML.bez(Vector3.ZERO, mid - hp, end - hp, 10)
		var radii: Array = []
		for i in 10:
			radii.append(lerpf(0.09, 0.06, float(i) / 9.0))
		var g = ML.Geo.new()
		var rlen = ML.tube(g, pts, radii, {"sides": 7, "gnarl": 0.1, "seed": k * 1.9, "cap_end": false})
		var mi = ML.inst(pj, g.build(), hp, {"taper": 0.6, "ow": 0.025, "nf": 2.0})
		ML.life(mi, rlen, 0.2, 0.8, 0.3, k * 0.03, {"taper": 0.6})
	pj.after(0.12, func():
		var soil = ML.soil_col(dig)
		ML.chips(pj, dig + Vector3.UP * 0.2, 8, 6.0, {"col": soil, "col2": soil.lightened(0.2), "size": 0.3})
		ML.scar(pj, dig, 1.8, 2.0, {"lines": 7.0, "pit": 0.5}))
	Sfx.play("earth", c.global_position, 0.9)
	var L0 = c.global_position.distance_to(tt.global_position)
	for k in 6:   # toprağın altında ilerleyişin izi: yol boyunca kabaran toprak
		var u = (k + 1) / 7.0
		pj.after(0.14 + u * 0.3, func():
			var p = pj.gp(dig + d * (L0 - 2.6) * u)
			var soil = ML.soil_col(p)
			ML.dust(pj, p + Vector3.UP * 0.25, 0.9, 0.9, {"col": ML.dust_col(p)})
			ML.chips(pj, p + Vector3.UP * 0.15, 5, 4.5, {"col": soil, "col2": soil.lightened(0.2), "size": 0.26})
			ML.scar(pj, p, 0.8, 1.6, {"lines": 5.0, "pit": 0.6, "rings": 1.0}))
	pj.after(0.55, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var at: Vector3 = pj.gp(x.global_position)
		var bs = ClanJutsu.body_scale(x)
		var g = ML.Geo.new()
		var tl = 0.0
		for k in 6:   # kökler hedefin altından yükselir, tepede birbirine kapanır
			var a = TAU * k / 6.0 + 0.3
			var o = Vector3(cos(a), 0, sin(a))
			var p0 = o * 1.5 * bs - Vector3.UP * 0.5
			var p2 = o * 0.25 * bs + Vector3.UP * (3.4 + (k % 2) * 0.7) * bs
			var p1 = o * 1.45 * bs + Vector3.UP * 2.0 * bs
			var pts = ML.bez(p0, p1, p2, 10)
			var radii: Array = []
			for i in 10:
				radii.append(lerpf(0.26 * bs, 0.07 * bs, float(i) / 9.0))
			tl = maxf(tl, ML.tube(g, pts, radii, {"sides": 9, "gnarl": 0.12, "seed": k * 1.3, "cap_end": false}))
		var cage = ML.inst(pj, g.build(), at, {"taper": 1.0, "ow": 0.04, "nf": 4.0})
		ML.life(cage, tl, 0.3, 1.7, 0.45, 0.0, {"out": "sink", "depth": 1.5, "taper": 1.0})
		var g2 = ML.Geo.new()   # içeride hedefe sarmal dolanan kök
		var hpts = ML.helix(0.7 * bs, 0.55 * bs, 2.3 * bs, 2.2, 24, randf() * TAU)
		var hr: Array = []
		for i in hpts.size():
			hr.append(lerpf(0.13, 0.07, float(i) / (hpts.size() - 1)) * bs)
		var hl = ML.tube(g2, hpts, hr, {"sides": 7, "gnarl": 0.1, "cap_end": false})
		var wrap = ML.inst(pj, g2.build(), at, {"taper": 0.8, "ow": 0.03, "nf": 3.0})
		ML.life(wrap, hl, 0.35, 1.4, 0.3, 0.12, {"taper": 0.8})
		ML.scar(pj, at, 3.0 * bs, 3.0, {"lines": 10.0, "pit": 0.8})
		var soil = ML.soil_col(at)
		ML.chips(pj, at + Vector3.UP * 0.3, 12, 7.0, {"col": soil, "col2": soil.lightened(0.2), "size": 0.35})
		pj.shake(0.5)
		Sfx.play("boom", at, 0.9)
		x.take_hit(pj.inf(cc, id, 1.2, {"knock": 0.0, "launch": 1.5, "kind": "heavy", "element": "mokuton", "hitstop": 0.06}))
		pj.st(x, "bind", 2.0)
		Combat.popup_text(at + Vector3.UP * 3.2, "Kökler gömdü!", Color(0.8, 0.65, 0.4))
		for e in pj.enemies_near(cc, at, 2.8):
			if e != x and is_instance_valid(e) and not e.is_dead():
				e.take_hit(pj.inf(cc, id, 0.6, {"knock": 9.0, "launch": 3.0, "kind": "heavy", "element": "mokuton"}))
		pj.after(1.7, func():   # kökler sıkışıp parçalanır
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			var p2: Vector3 = at
			if x2 and pj.live(x2):
				p2 = x2.global_position
			ML.splinters(pj, p2 + Vector3.UP * 1.2, 8, 0.9, 9.0)
			ML.chips(pj, p2 + Vector3.UP * 1.2, 16, 9.0, {"size": 0.38})
			ML.leaves(pj, p2 + Vector3.UP * 2.5, 8, 3.0, {"size": 0.35})
			if is_instance_valid(cage):
				ML.wither_to(cage, 0.0, 0.7, 0.4)
			pj.shake(0.6)
			Sfx.play("th_wood", p2, 0.7)
			pj.hit(c2, p2 + Vector3.UP, 3.2, pj.inf(c2, id, 2.6, {"knock": 16.0, "launch": 5.0, "kind": "heavy", "element": "mokuton", "bleed": 3.0, "hitstop": 0.08}))))
