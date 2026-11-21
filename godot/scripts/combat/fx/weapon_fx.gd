class_name WeaponFX
extends RefCounted
## Silah / kukla teknikleri (15 teknik) — her tekniğin kendi görünüşü, ortak efekt kütüphanesi YOK.
## Kendi yapı taşlarım:
##   · çelik cel shader'ı (3 kademe ışık, koyu kenar, tek sert parlama çizgisi + bıçak boyunca kayan parıltı "shine")
##   · şerit shader'ı (baştan açılan / kuyruktan kapanan; beyaz öz, parlak kesici kenar, koyu mürekkep kenar, yırtık çizgi,
##     iplik boyunca akan chakra boncukları)
##   · dört kollu yıldız parıltısı (kameraya dönük, metal yansıması), kıvılcım (yerçekimli, hızına göre uzayan çizgi),
##     toz topağı (topaklı, iki tonlu, kenarı dağınık), kaya / tahta kıymığı (savrulur, düşer, toprağa gömülür)
##   · zemin oluğu (koyu oluk + iki yanda kabarık toprak dudak), zemin yarığı, yanık izi, basınç halkası
##   · canlı iz (her karede kaynaktan örneklenen kenar çiftinden süpürme izi), canlı eğri (tel / iplik), zincir (MultiMesh halka)
##   · kendi geometrim: kukla bıçağı, tüy, kusarigama başı, kuyruk boğumu, matkap dişi, dev topuz / satır, iğne
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermiler) eski işleyicilerden satır satır taşındı.

static var _cache := {}

const WHITE := Color(0.97, 0.98, 1.0, 0.95)
const STEEL := Color(0.8, 0.83, 0.9)
const IRON := Color(0.27, 0.28, 0.31)
const WIRE := Color(0.9, 0.94, 1.0, 0.95)
const CHAKRA := Color(0.45, 0.75, 1.0)
const SPARK := Color(1.0, 0.8, 0.42)
const DUSTC := Color(0.72, 0.64, 0.52)
const SOIL := Color(0.42, 0.32, 0.22)
const GROOVE := Color(0.19, 0.14, 0.1, 0.9)
const LIP := Color(0.55, 0.45, 0.33, 0.85)
const HANE := Color(0.9, 0.95, 1.0)
const POISON := Color(0.58, 0.26, 0.74)
const WOOD := Color(0.52, 0.37, 0.24)

# ------------------------------------------------------------------ shader'lar
const SOLID_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, ambient_light_disabled;

instance uniform vec4 tint = vec4(1.0);
instance uniform float metal = 0.0;
instance uniform float shine = -9.0;
instance uniform float glow = 0.0;
instance uniform float dis = 0.0;
instance uniform float seed = 0.0;

varying vec3 lp;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (dis > 0.001 && vn3(lp * 9.0 + vec3(seed * 3.0)) < dis) {
		discard;
	}
	vec3 base = pow(clamp(COLOR.rgb * tint.rgb, vec3(0.0), vec3(1.0)), vec3(2.2));
	float fres = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	// anime çeliği: tek sert parlama çizgisi + bıçak boyunca kayan parıltı
	vec3 rv = reflect(-VIEW, NORMAL);
	float hl = step(0.9, dot(rv, normalize(vec3(0.35, 0.8, 0.45)))) * metal;
	float diag = lp.x + lp.y * 0.6 + lp.z * 1.3;
	float sw = (1.0 - smoothstep(0.0, 0.08, abs(diag - shine))) * metal;
	base = mix(base, base * 0.28, step(0.8, fres));
	ALBEDO = base;
	EMISSION = base * glow + vec3(1.0) * (hl * 0.65 + sw * 2.4);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.3 ? 1.0 : (ndl > -0.1 ? 0.6 : 0.38);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
"""

const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, BLENDMODE;

instance uniform vec4 tint = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float head = 1.0;
instance uniform float tail = 0.0;
instance uniform float ends = 1.0;
instance uniform float core = 0.0;
instance uniform float rim = 0.0;
instance uniform float ink = 0.0;
instance uniform float tear = 0.0;
instance uniform float pulse = 0.0;
instance uniform float soft = 0.0;
instance uniform float seed = 0.0;

varying float camd;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	camd = length(wpos - CAMERA_POSITION_WORLD);
}

void fragment() {
	float u = UV.x;
	if (u > head || u < tail) {
		discard;
	}
	float v = abs(UV.y - 0.5) * 2.0;
	float a = COLOR.a * tint.a * fade;
	a *= mix(1.0, smoothstep(tail, tail + 0.05, u) * (1.0 - smoothstep(head - 0.04, head + 0.0001, u)), ends);
	float lane = floor(UV.y * 7.0);
	float nb = vn2(vec2(u * 9.0 + seed * 5.0, lane * 2.7 + seed));
	a *= mix(1.0, smoothstep(tear - 0.06, tear + 0.06, nb), step(0.001, tear));
	a *= mix(1.0, 1.0 - smoothstep(0.3, 1.0, v), soft);
	vec3 col = pow(clamp(COLOR.rgb * tint.rgb, vec3(0.0), vec3(1.0)), vec3(2.2));
	col = mix(col, vec3(1.0), (1.0 - smoothstep(0.0, 0.5, v)) * core);
	col = mix(col, vec3(1.0), smoothstep(0.7, 1.0, UV.y) * rim);
	float bead = smoothstep(0.75, 1.0, fract(u * 5.0 - TIME * pulse)) * step(0.001, pulse);
	col = mix(col, vec3(1.0), bead * 0.85);
	col = mix(col, col * 0.22, step(0.8, v) * ink);
	a *= smoothstep(0.6, 2.6, camd);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Metal parıltısı: kameraya dönük dört (+ dört kısa çapraz) kollu yıldız
const STAR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

instance uniform vec4 tint = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float spin = 0.0;
instance uniform float seed = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float cs = cos(spin);
	float sn = sin(spin);
	p = vec2(p.x * cs - p.y * sn, p.x * sn + p.y * cs);
	float r = length(p);
	float s1 = (1.0 - smoothstep(0.0, 0.07 * max(0.03, 1.0 - abs(p.x)), abs(p.y))) * max(0.0, 1.0 - abs(p.x));
	float s2 = (1.0 - smoothstep(0.0, 0.07 * max(0.03, 1.0 - abs(p.y)), abs(p.x))) * max(0.0, 1.0 - abs(p.y));
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071;
	float s3 = (1.0 - smoothstep(0.0, 0.035, abs(q.y))) * max(0.0, 1.0 - abs(q.x) * 2.4);
	float s4 = (1.0 - smoothstep(0.0, 0.035, abs(q.x))) * max(0.0, 1.0 - abs(q.y) * 2.4);
	float mid = 1.0 - smoothstep(0.04, 0.26, r);
	float a = max(max(max(s1, s2), max(s3, s4) * 0.7), mid);
	vec3 col = mix(pow(clamp(tint.rgb, vec3(0.0), vec3(1.0)), vec3(2.2)), vec3(1.0), clamp(mid + 0.35, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(a * fade * tint.a, 0.0, 1.0);
}
"""

## Toz topağı: iki tonlu (üstü açık), içte yavaş kabaran desen, kenarı dağınık; kameraya çok yakınken solar
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

instance uniform vec4 tint = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

varying vec3 lp;
varying vec3 wn;
varying float camd;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	lp = VERTEX;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	camd = length(wpos - CAMERA_POSITION_WORLD);
}

void fragment() {
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = vn3(lp * 3.0 + vec3(seed * 3.1, seed - TIME * 0.4, 0.0)) * 0.7 + vn3(lp * 7.0 + vec3(seed)) * 0.3;
	float a = 1.0 - smoothstep(0.35, 0.9, fres + (n - 0.5) * 0.5);
	a *= fade * tint.a * smoothstep(1.2, 4.0, camd);
	vec3 base = pow(clamp(tint.rgb, vec3(0.0), vec3(1.0)), vec3(2.2));
	float lit = step(0.0, wn.y + (n - 0.5) * 0.6 + 0.15);
	base *= mix(0.66, 1.0, lit);
	ALBEDO = base;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Patlama topağı: sıcaklık (heat) düştükçe beyaz-sarı → turuncu → kızıl → koyu duman; kenarı mürekkepli, gürültüyle aşınır
const BLAST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

instance uniform float heat = 1.0;
instance uniform float dis = 0.0;
instance uniform float seed = 0.0;

varying vec3 lp;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float n = vn3(lp * 2.5 + vec3(seed, seed - TIME * 1.5, 0.0)) * 0.65 + vn3(lp * 6.0 + vec3(seed * 2.0)) * 0.35;
	if (n < dis) {
		discard;
	}
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float t = heat + (n - 0.5) * 0.55 - fres * 0.35;
	vec3 c = vec3(0.13, 0.1, 0.1);
	if (t > 0.78) {
		c = vec3(1.0, 0.97, 0.75);
	} else if (t > 0.55) {
		c = vec3(1.0, 0.72, 0.18);
	} else if (t > 0.32) {
		c = vec3(0.92, 0.28, 0.08);
	} else if (t > 0.12) {
		c = vec3(0.35, 0.14, 0.1);
	}
	c = mix(c, c * 0.4, step(0.82, fres));
	vec3 lin = pow(c, vec3(2.2));
	ALBEDO = lin;
	EMISSION = lin * clamp(t * 1.8, 0.0, 1.6);
}
"""

## Sōshōryū parşömen şeridi: dış yüz kırmızı + ortada sarı bant (ince koyu ayraçla), iç yüz beyaz kâğıt; kenarlar mürekkep.
## reveal ile baştan uca açılır, dis ile kâğıt lif lif dağılır.
const SCROLL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

instance uniform float reveal = 1.0;
instance uniform float dis = 0.0;
instance uniform float flip = 0.0;
instance uniform float seed = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (UV.x > reveal) {
		discard;
	}
	if (dis > 0.001 && h21(floor(UV * vec2(220.0, 8.0)) + vec2(seed)) < dis) {
		discard;
	}
	float v = UV.y;
	float off = abs(v - 0.5);
	bool outer = FRONT_FACING != (flip > 0.5);
	vec3 c = vec3(0.97, 0.94, 0.88);
	if (outer) {
		c = vec3(0.84, 0.3, 0.36);
		if (off < 0.17) {
			c = vec3(0.98, 0.9, 0.46);
		}
		if (abs(off - 0.17) < 0.012) {
			c = vec3(0.45, 0.12, 0.15);
		}
	}
	c = mix(c, vec3(0.22, 0.08, 0.08), step(0.955, off * 2.0));
	float sh = 0.82 + 0.18 * abs(dot(NORMAL, VIEW));
	ALBEDO = pow(c * sh, vec3(2.2));
}
"""


# ------------------------------------------------------------------ malzemeler / örnekler
static func _sh(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var s = Shader.new()
	s.code = code
	var m = ShaderMaterial.new()
	m.shader = s
	_cache[key] = m
	return m


static func _solid_mat() -> ShaderMaterial:
	return _sh("solid", SOLID_SHADER)


static func _trail_mat(add := false) -> ShaderMaterial:
	if add:
		return _sh("trail_add", TRAIL_SHADER.replace("BLENDMODE", "blend_add"))
	return _sh("trail", TRAIL_SHADER.replace("BLENDMODE", "blend_mix"))


static func _star_mat() -> ShaderMaterial:
	return _sh("star", STAR_SHADER)


static func _dust_mat() -> ShaderMaterial:
	return _sh("dust", DUST_SHADER)


static func _blast_mat() -> ShaderMaterial:
	return _sh("blast", BLAST_SHADER)


static func _scroll_mat() -> ShaderMaterial:
	return _sh("scroll", SCROLL_SHADER)


static func _mi(mesh: Mesh, mat: Material, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	for k in o:
		mi.set_instance_shader_parameter(k, o[k])
	return mi


static func _pf(mi: GeometryInstance3D, pname: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(pname, v)


## Şerit animasyonu: baştan uca açılır (head), bekler; close ise kuyruk kapanırken söner, değilse yerinde söner; sonra silinir
static func _sweep(mi: GeometryInstance3D, t_in: float, hold: float, t_out: float, close := true) -> void:
	if mi == null or not is_instance_valid(mi):
		return
	if t_in > 0.0:
		mi.set_instance_shader_parameter("head", 0.0)
	var tw = mi.create_tween()
	if t_in > 0.0:
		tw.tween_method(_pf(mi, "head"), 0.0, 1.0, t_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(hold)
	if close:
		tw.tween_method(_pf(mi, "tail"), 0.0, 1.0, t_out).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, t_out)
	else:
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, t_out)
	tw.tween_callback(mi.queue_free)


## Bir parametreyi v0 → v1 götürüp siler (fade / dis)
static func _fade_free(n: GeometryInstance3D, delay: float, t: float, pname := "fade", v0 := 1.0, v1 := 0.0) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_pf(n, pname), v0, v1, t)
	tw.tween_callback(n.queue_free)


# ------------------------------------------------------------------ geometri
static func _qv(st: SurfaceTool, p: Vector3, uv: Vector2, col: Color) -> void:
	st.set_color(col)
	st.set_uv(uv)
	st.set_normal(Vector3.UP)
	st.add_vertex(p)


## Şerit: her noktada yan vektör + genişlik + renk; UV.x boyuna (u0..u1), UV.y enine (0..1). Noktalar o'ya göre yerele çevrilir
static func _strip_into(st: SurfaceTool, pts: Array, sides: Array, widths: Array, cols: Array, o: Vector3, u0 := 0.0, u1 := 1.0) -> void:
	var n = pts.size()
	for i in n - 1:
		var ua = lerpf(u0, u1, float(i) / (n - 1))
		var ub = lerpf(u0, u1, float(i + 1) / (n - 1))
		var pa: Vector3 = pts[i] - o
		var pb: Vector3 = pts[i + 1] - o
		var sa: Vector3 = sides[i] * float(widths[i]) * 0.5
		var sb: Vector3 = sides[i + 1] * float(widths[i + 1]) * 0.5
		_qv(st, pa - sa, Vector2(ua, 0.0), cols[i])
		_qv(st, pa + sa, Vector2(ua, 1.0), cols[i])
		_qv(st, pb + sb, Vector2(ub, 1.0), cols[i + 1])
		_qv(st, pa - sa, Vector2(ua, 0.0), cols[i])
		_qv(st, pb + sb, Vector2(ub, 1.0), cols[i + 1])
		_qv(st, pb - sb, Vector2(ub, 0.0), cols[i + 1])


static func _fill(n: int, v) -> Array:
	var out = []
	out.resize(n)
	out.fill(v)
	return out


## Düz şerit (yan vektörleri verilmiş)
static func _flat(pts: Array, sides: Array, widths: Array, cols: Array, o: Vector3) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip_into(st, pts, sides, widths, cols, o)
	return st.commit()


## Her açıdan görünen çizgi: yola dik iki şerit çaprazlanır
static func _cross(pts: Array, widths: Array, cols: Array, o: Vector3) -> ArrayMesh:
	var s1 = []
	var s2 = []
	var n = pts.size()
	for i in n:
		var tv: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tv.length() < 0.0001:
			tv = Vector3.FORWARD
		tv = tv.normalized()
		var rf = Vector3.UP if absf(tv.y) < 0.9 else Vector3.RIGHT
		var a = tv.cross(rf).normalized()
		s1.append(a)
		s2.append(tv.cross(a).normalized())
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip_into(st, pts, s1, widths, cols, o)
	_strip_into(st, pts, s2, widths, cols, o)
	return st.commit()


## Uçlara doğru incelen genişlik dizisi
static func _taper(n: int, w0: float, w1: float, ends := 5.0) -> Array:
	var out = []
	for i in n:
		var u = float(i) / maxi(1, n - 1)
		out.append(lerpf(w0, w1, u) * clampf(minf(u, 1.0 - u) * ends + 0.15, 0.0, 1.0))
	return out


static func _seg(a: Vector3, b: Vector3, n: int) -> Array:
	var out = []
	for i in n + 1:
		out.append(a.lerp(b, float(i) / n))
	return out


## Düzlemde yay noktaları (ax açı 0, ay açı 90°; açılar radyan)
static func _arc(ctr: Vector3, ax: Vector3, ay: Vector3, r: float, a0: float, a1: float, n: int) -> Array:
	var out = []
	for i in n + 1:
		var a = lerpf(a0, a1, float(i) / n)
		out.append(ctr + (ax * cos(a) + ay * sin(a)) * r)
	return out


## -Z boyunca birim çizgi (0 → -1): uçları her karede yeniden konumlanan iplik / kıvılcım için
static func _unit_line(w: float) -> ArrayMesh:
	var key = "uline%d" % int(w * 1000.0)
	if _cache.has(key):
		return _cache[key]
	var pts = _seg(Vector3.ZERO, Vector3(0, 0, -1), 6)
	var m = _cross(pts, _fill(pts.size(), w), _fill(pts.size(), Color.WHITE), Vector3.ZERO)
	_cache[key] = m
	return m


static func _aim_line(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var L = a.distance_to(b)
	if L < 0.01:
		mi.visible = false
		return
	mi.visible = true
	var f = (b - a) / L
	mi.global_transform = Transform3D(Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT) * Basis.from_scale(Vector3(1, 1, L)), a)


static func _quad() -> QuadMesh:
	if _cache.has("quad"):
		return _cache["quad"]
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	_cache["quad"] = q
	return q


static func _white_cols(arr: Array) -> void:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cs = PackedColorArray()
	cs.resize(vs.size())
	cs.fill(Color.WHITE)
	arr[Mesh.ARRAY_COLOR] = cs


## Topaklı küre (toz / patlama topağı): birkaç rastgele şişkinlik
static func _lump(v: int) -> ArrayMesh:
	var key = "lump%d" % v
	if _cache.has(key):
		return _cache[key]
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 8
	var arr = sm.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var rng = RandomNumberGenerator.new()
	rng.seed = 77 + v * 13
	var bumps = []
	for k in 5:
		bumps.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1.0), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.1, 0.2)])
	for i in vs.size():
		var dv = vs[i].normalized() if vs[i].length() > 0.0001 else Vector3.UP
		var r = 0.5
		for b in bumps:
			r += float(b[1]) * pow(maxf(0.0, dv.dot(b[0])), 3.0)
		vs[i] = dv * r
		ns[i] = dv
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	_white_cols(arr)
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache[key] = m
	return m


## Kıymık / taş parçası (yassı köşeli)
static func _rock(v: int) -> ArrayMesh:
	var key = "rock%d" % v
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	b.add("boulder", Vector3.ZERO, Vector3(1.0, 0.7, 0.85), Color.WHITE, Vector3(0, v * 40, 0), v + 1)
	var m = b.build()
	_cache[key] = m
	return m


## Zincir halkası: oval simit, boyu -Z ekseninde
static func _link_mesh() -> ArrayMesh:
	if _cache.has("link"):
		return _cache["link"]
	var tm = TorusMesh.new()
	tm.inner_radius = 0.026
	tm.outer_radius = 0.05
	tm.rings = 12
	tm.ring_segments = 6
	var arr = tm.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in vs.size():
		vs[i] = Vector3(vs[i].x, vs[i].y, vs[i].z * 1.6)
	arr[Mesh.ARRAY_VERTEX] = vs
	_white_cols(arr)
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache["link"] = m
	return m


## Yassı halka (basınç dalgası) — yarıçap 1, en 0.12; kapalı
static func _ring_mesh() -> ArrayMesh:
	if _cache.has("ring"):
		return _cache["ring"]
	var pts = []
	var sides = []
	for i in 49:
		var a = i * TAU / 48.0
		var dv = Vector3(cos(a), 0, sin(a))
		pts.append(dv)
		sides.append(dv)
	var m = _flat(pts, sides, _fill(pts.size(), 0.12), _fill(pts.size(), Color.WHITE), Vector3.ZERO)
	_cache["ring"] = m
	return m


## Yassı disk (yanık izi / leke): merkez UV.y 0.5, kenar 1.0
static func _disc_mesh() -> ArrayMesh:
	if _cache.has("disc"):
		return _cache["disc"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 28
	for i in n:
		var a0 = i * TAU / n
		var a1 = (i + 1) * TAU / n
		var r0 = 1.0 + sin(a0 * 5.0) * 0.12 + sin(a0 * 3.0 + 1.0) * 0.08
		var r1 = 1.0 + sin(a1 * 5.0) * 0.12 + sin(a1 * 3.0 + 1.0) * 0.08
		_qv(st, Vector3.ZERO, Vector2(0.5, 0.5), Color.WHITE)
		_qv(st, Vector3(cos(a0), 0, sin(a0)) * r0, Vector2(0.5, 1.0), Color.WHITE)
		_qv(st, Vector3(cos(a1), 0, sin(a1)) * r1, Vector2(0.5, 1.0), Color.WHITE)
	var m = st.commit()
	_cache["disc"] = m
	return m


## Tüy: ortada sap, iki yanda asimetrik bayrak, uçta çentik; +Z uç. Gövde mavimsi, kenar beyaz
static func _feather_mesh() -> ArrayMesh:
	if _cache.has("feather"):
		return _cache["feather"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 10
	var cin = Color(0.74, 0.82, 0.96)
	var cout = Color(1.0, 1.0, 1.0)
	for i in n:
		var t0 = float(i) / n
		var t1 = float(i + 1) / n
		var z0 = lerpf(-0.5, 0.5, t0)
		var z1 = lerpf(-0.5, 0.5, t1)
		var w0 = 0.13 * sin(PI * pow(t0, 0.7)) * (0.55 if i == 6 else 1.0)
		var w1 = 0.13 * sin(PI * pow(t1, 0.7)) * (0.55 if i + 1 == 6 else 1.0)
		for sgn in [-1.0, 1.0]:
			var k = 0.8 if sgn < 0.0 else 1.0
			var c0 = Vector3(0, 0, z0)
			var c1 = Vector3(0, 0, z1)
			var e0 = Vector3(sgn * w0 * k, 0, z0 - 0.04)
			var e1 = Vector3(sgn * w1 * k, 0, z1 - 0.04)
			_qv(st, c0, Vector2(t0, 0.5), cin)
			_qv(st, e0, Vector2(t0, 1.0), cout)
			_qv(st, e1, Vector2(t1, 1.0), cout)
			_qv(st, c0, Vector2(t0, 0.5), cin)
			_qv(st, e1, Vector2(t1, 1.0), cout)
			_qv(st, c1, Vector2(t1, 0.5), cin)
	var m = st.commit()
	_cache["feather"] = m
	return m


static func _feather_mi(s := 1.0) -> MeshInstance3D:
	var mi = _mi(_feather_mesh(), _solid_mat(), {"tint": HANE, "glow": 0.6})
	mi.scale = Vector3.ONE * s
	return mi


## Kukla bıçağı: ince çelik, sivri uç, mor zehir oluğu; +Z uç
static func _blade_mi(L: float, w: float) -> MeshInstance3D:
	var b = MB.new()
	b.add("box", Vector3(0, 0, L * 0.42), Vector3(w, 0.016, L * 0.84), Color(0.8, 0.82, 0.88))
	b.add("prism", Vector3(0, 0, L * 0.92), Vector3(w, L * 0.16, 0.016), Color(0.9, 0.92, 0.96), Vector3(90, 0, 0), 3)
	b.add("box", Vector3(0, 0.01, L * 0.42), Vector3(w * 0.25, 0.004, L * 0.8), Color(0.45, 0.28, 0.55))
	return _mi(b.build(), _solid_mat(), {"metal": 1.0})


# ------------------------------------------------------------------ yapı taşları
## Uzayda tek çizgi: açılır, kapanır
static func _line(pj: PathJutsu, pts: Array, w0: float, w1: float, col: Color, t_in: float, hold: float, t_out: float, o := {}, add := false) -> MeshInstance3D:
	if pts.size() < 2:
		return null
	var mi = _mi(_cross(pts, _taper(pts.size(), w0, w1), _fill(pts.size(), col), pts[0]), _trail_mat(add), o)
	pj.scene_add(mi, pts[0])
	_sweep(mi, t_in, hold, t_out)
	return mi


## Kapalı tel halka (sabit en)
static func _loop(pj: PathJutsu, pts: Array, w: float, col: Color, t_in: float, hold: float, t_out: float, o := {}) -> MeshInstance3D:
	var oo = o.duplicate()
	oo["ends"] = 0.0
	var mi = _mi(_cross(pts, _fill(pts.size(), w), _fill(pts.size(), col), pts[0]), _trail_mat(false), oo)
	pj.scene_add(mi, pts[0])
	_sweep(mi, t_in, hold, t_out, false)
	return mi


## Düz hilal (bıçak izi): düzlemde yay; en ortada geniş, uçlarda sivri. Yan vektör = yarıçap yönü
static func _crescent(pj: PathJutsu, ctr: Vector3, ax: Vector3, ay: Vector3, r: float, a0: float, a1: float, w: float, col: Color, t_in: float, hold: float, t_out: float, o := {}, add := false) -> MeshInstance3D:
	var n = 20
	var pts = []
	var sides = []
	var ws = []
	for i in n + 1:
		var u = float(i) / n
		var a = lerpf(a0, a1, u)
		var dv = ax * cos(a) + ay * sin(a)
		pts.append(ctr + dv * r)
		sides.append(dv)
		ws.append(w * pow(sin(PI * clampf(u, 0.0, 1.0)), 0.6) + 0.002)
	var mi = _mi(_flat(pts, sides, ws, _fill(pts.size(), col), ctr), _trail_mat(add), o)
	pj.scene_add(mi, ctr)
	_sweep(mi, t_in, hold, t_out)
	return mi


## Katmanlı kesik: renkli gövde (mürekkep kenarlı) + dış kenarda beyaz kesici çizgi
static func _slash_arc(pj: PathJutsu, ctr: Vector3, ax: Vector3, ay: Vector3, r: float, a0: float, a1: float, w: float, col: Color, t_in: float, hold: float, t_out: float) -> void:
	_crescent(pj, ctr, ax, ay, r - w * 0.2, a0, a1, w, col, t_in, hold, t_out, {"ink": 0.6, "tear": 0.12})
	_crescent(pj, ctr, ax, ay, r + w * 0.22, a0, a1, w * 0.26, WHITE, t_in, hold * 0.8, t_out * 0.8, {"core": 1.0})


## Hedefin üstünde kısa kesik: saldırı yönüne dik düzlemde, rastgele eğik hilal
static func _nick(pj: PathJutsu, at: Vector3, from_dir: Vector3, size: float, col: Color) -> void:
	var fd = from_dir.normalized() if from_dir.length() > 0.01 else Vector3.FORWARD
	var rf = Vector3.UP if absf(fd.y) < 0.9 else Vector3.RIGHT
	var ax = fd.cross(rf).normalized()
	var ay = ax.cross(fd).normalized()
	var roll = randf() * TAU
	var bx = ax * cos(roll) + ay * sin(roll)
	var by = -ax * sin(roll) + ay * cos(roll)
	var ctr = at - by * size
	_slash_arc(pj, ctr, bx, by, size, PI * 0.5 - 0.9, PI * 0.5 + 0.9, size * 0.3, col, 0.05, 0.03, 0.14)


## Metal parıltısı: yıldız açılır, döner, söner
static func _glint(pj: PathJutsu, pos: Vector3, size: float, dur := 0.22, col := Color(0.85, 0.92, 1.0)) -> void:
	var mi = _mi(_quad(), _star_mat(), {"tint": col, "spin": randf_range(-0.3, 0.3)})
	pj.scene_add(mi, pos)
	mi.scale = Vector3.ONE * 0.02
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.02, dur * 0.65).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(mi, "spin"), 0.0, 0.6, dur * 0.65)
	tw.tween_callback(mi.queue_free)


## Kıvılcım: metal sürtünmesi; yerçekimiyle düşer, hızına göre uzayan parlak çizgi
static func _sparks(pj: PathJutsu, pos: Vector3, n: int, dir: Vector3, spread: float, spd: float, col := SPARK, life := 0.32) -> void:
	var dn = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	for k in n:
		var v: Vector3 = (dn + Vector3(randf_range(-1, 1), randf_range(-0.4, 1.0), randf_range(-1, 1)) * spread).normalized() * spd * randf_range(0.5, 1.2)
		var mi = _mi(_unit_line(0.035), _trail_mat(true), {"tint": col, "core": 0.9, "ends": 0.0})
		pj.scene_add(mi, pos)
		var lf = life * randf_range(0.6, 1.2)
		var stepf = func(q: float) -> void:
			if not is_instance_valid(mi):
				return
			var vel: Vector3 = v + Vector3.DOWN * 14.0 * q
			var p: Vector3 = pos + v * q + Vector3.DOWN * 7.0 * q * q
			var L = clampf(vel.length() * 0.03, 0.05, 0.45)
			_aim_line(mi, p, p - vel.normalized() * L)
			mi.set_instance_shader_parameter("fade", 1.0 - q / lf)
		var tw = mi.create_tween()
		tw.tween_method(stepf, 0.0, lf, lf)
		tw.tween_callback(mi.queue_free)


## Toz topağı: sürüklenerek yavaşlar, şişer, kenarından dağılır
static func _puff(pj: PathJutsu, pos: Vector3, vel: Vector3, s0: float, s1: float, life: float, col := DUSTC, drag := 2.5) -> void:
	var mi = _mi(_lump(randi() % 4), _dust_mat(), {"tint": col, "fade": 0.0})
	pj.scene_add(mi, pos)
	var sb = minf(s1, 2.0)
	mi.scale = Vector3.ONE * s0
	mi.rotation.y = randf() * TAU
	var stepf = func(q: float) -> void:
		if not is_instance_valid(mi):
			return
		var k = (1.0 - exp(-drag * q)) / drag
		mi.global_position = pos + vel * k + Vector3.UP * 0.3 * q
		var u = q / life
		var s = lerpf(s0, sb, 1.0 - pow(1.0 - u, 2.0))
		mi.scale = Vector3(s, s * 0.85, s)
		mi.set_instance_shader_parameter("fade", smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.4, 1.0, u)))
	var tw = mi.create_tween()
	tw.tween_method(stepf, 0.0, life, life)
	tw.tween_callback(mi.queue_free)


## Yerde dışa yayılan toz halkası
static func _dust_ring(pj: PathJutsu, g: Vector3, r0: float, spd: float, n: int, size: float, life: float, col := DUSTC) -> void:
	for k in n:
		var a = k * TAU / n + randf_range(-0.3, 0.3)
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + dv * r0 + Vector3.UP * size * 0.4, dv * spd * randf_range(0.7, 1.2) + Vector3.UP * spd * 0.2, size, size * 2.3, life * randf_range(0.8, 1.2), col)


## Uçan parça: atış eğrisi, yere oturur, bir süre kalır, toprağa gömülür
static func _fly(mi: MeshInstance3D, p0: Vector3, v0: Vector3, g: float, s: float, stay := 1.2) -> void:
	var stt = {"done": false}
	var spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	var stepf = func(q: float) -> void:
		if stt["done"] or not is_instance_valid(mi):
			return
		var p = p0 + v0 * q + Vector3.DOWN * 0.5 * g * q * q
		var fl = Game.jutsu_floor(p.x, p.z)
		if q > 0.05 and p.y <= fl:
			stt["done"] = true
			mi.global_position = Vector3(p.x, fl + s * 0.12, p.z)
			var tw2 = mi.create_tween()
			tw2.tween_interval(stay * randf_range(0.7, 1.3))
			tw2.tween_property(mi, "global_position", Vector3(p.x, fl - s * 0.8, p.z), 0.5).set_ease(Tween.EASE_IN)
			tw2.tween_callback(mi.queue_free)
			return
		mi.global_position = p
		mi.rotation = spin * q
	var tw = mi.create_tween()
	tw.tween_method(stepf, 0.0, 2.5, 2.5)
	tw.tween_callback(func() -> void:
		if not stt["done"] and is_instance_valid(mi):
			mi.queue_free())


## Saçılan toprak / taş / tahta kıymıkları
static func _chunks(pj: PathJutsu, pos: Vector3, n: int, spd: float, size: float, col := SOIL, up := 0.9, bias := Vector3.ZERO, o := {}) -> void:
	for k in n:
		var a = randf() * TAU
		var v = Vector3(cos(a), 0, sin(a)) * spd * randf_range(0.3, 1.0) + Vector3.UP * spd * up * randf_range(0.6, 1.2) + bias * randf_range(0.6, 1.2)
		var oo = o.duplicate()
		oo["tint"] = col
		var mi = _mi(_rock(randi() % 4), _solid_mat(), oo)
		var s = size * randf_range(0.6, 1.3)
		var p0 = pos + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.15), randf_range(-0.2, 0.2))
		pj.scene_add(mi, p0)
		mi.scale = Vector3.ONE * s
		_fly(mi, p0, v, 20.0, s)


## Hava / zemin basınç halkası: nrm düzlem normali; r0 → r1 genişleyip söner
static func _ring(pj: PathJutsu, pos: Vector3, nrm: Vector3, r0: float, r1: float, t: float, col: Color, add := false) -> void:
	var mi = _mi(_ring_mesh(), _trail_mat(add), {"tint": col, "ends": 0.0, "soft": 0.6, "ink": 0.0})
	pj.scene_add(mi, pos)
	var n = nrm.normalized()
	var rf = Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var x = n.cross(rf).normalized()
	mi.global_basis = Basis(x, n, x.cross(n))
	mi.scale = Vector3(r0, 1.0, r0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, 1.0, r1), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, t).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Araziye oturan nokta dizisi (a → b)
static func _ground_pts(a: Vector3, b: Vector3, n: int, lift := 0.04) -> Array:
	var out = []
	for i in n + 1:
		var p = a.lerp(b, float(i) / n)
		out.append(Vector3(p.x, Game.jutsu_floor(p.x, p.z) + lift, p.z))
	return out


## Arazi üstüne yatan şerit
static func _ground_strip(pj: PathJutsu, pts: Array, widths: Array, col: Color, o := {}) -> MeshInstance3D:
	var n = pts.size()
	var sides = []
	for i in n:
		var tv: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		tv.y = 0.0
		sides.append(Vector3(-tv.z, 0, tv.x).normalized() if tv.length() > 0.001 else Vector3.RIGHT)
	var mi = _mi(_flat(pts, sides, widths, _fill(n, col), pts[0]), _trail_mat(false), o)
	pj.scene_add(mi, pts[0])
	return mi


## Zemin oluğu: koyu oluk + iki yanında kabarmış açık toprak dudak; hızla açılır, stay sn kalır, söner
static func _gouge(pj: PathJutsu, a: Vector3, b: Vector3, w: float, stay := 1.6) -> void:
	var L = Vector3(a.x, 0, a.z).distance_to(Vector3(b.x, 0, b.z))
	if L < 0.08:
		return
	var n = clampi(int(L / 0.35) + 2, 2, 40)
	var pts = _ground_pts(a, b, n, 0.035)
	var groove = _ground_strip(pj, pts, _taper(pts.size(), w, w, 9.0), GROOVE, {"tear": 0.22, "ink": 0.5})
	_sweep(groove, 0.08, stay, 0.8, false)
	var dv = b - a
	var sd = Vector3(-dv.z, 0, dv.x).normalized()
	for sgn in [-1.0, 1.0]:
		var lp = []
		for p in pts:
			var q: Vector3 = p + sd * sgn * w * 0.62
			lp.append(Vector3(q.x, Game.jutsu_floor(q.x, q.z) + 0.05, q.z))
		var lip = _ground_strip(pj, lp, _taper(lp.size(), w * 0.32, w * 0.32, 9.0), LIP, {"tear": 0.45})
		_sweep(lip, 0.08, stay, 0.8, false)


## Zemin yarığı: merkezden dışa yürüyen kırık koyu çizgiler
static func _scar(pj: PathJutsu, g: Vector3, R: float, n: int, stay := 2.0) -> void:
	for k in n:
		var a = k * TAU / n + randf_range(-0.3, 0.3)
		var dv = Vector3(cos(a), 0, sin(a))
		var sd = Vector3(-dv.z, 0, dv.x)
		var L = R * randf_range(0.6, 1.0)
		var pts = []
		var ws = []
		for i in 7:
			var q = i / 6.0
			var p = g + dv * L * q + sd * randf_range(-0.14, 0.14) * L * q
			pts.append(Vector3(p.x, Game.jutsu_floor(p.x, p.z) + 0.045, p.z))
			ws.append(lerpf(minf(0.3, R * 0.09), 0.015, q))
		var mi = _ground_strip(pj, pts, ws, GROOVE, {})
		_sweep(mi, 0.16, stay * randf_range(0.8, 1.2), 0.9, false)


## Yerde leke (yanık / zehir): yumuşak kenarlı yamalı disk
static func _ground_disc(pj: PathJutsu, g: Vector3, R: float, col: Color, stay: float) -> void:
	var mi = _mi(_disc_mesh(), _trail_mat(false), {"tint": col, "soft": 0.8, "tear": 0.25, "ends": 0.0})
	pj.scene_add(mi, Vector3(g.x, Game.jutsu_floor(g.x, g.z) + 0.03, g.z))
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(R * 0.4, 1.0, R * 0.4)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(R, 1.0, R), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_interval(stay)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 1.0)
	tw.tween_callback(mi.queue_free)


## Canlı süpürme izi: pair_fn her örnekte [a, b] kenar çifti verir (boş dizi = örnek yok). En yeni örnek u = 1.
static func _smear(pj: PathJutsu, pair_fn: Callable, dur: float, n: int, col: Color, o := {}, add := false, dt := 1.0 / 60.0) -> MeshInstance3D:
	var oo = o.duplicate()
	if not oo.has("ends"):
		oo["ends"] = 0.0
	var mi = _mi(null, _trail_mat(add), oo)
	pj.scene_add(mi, Vector3.ZERO)
	var hist = []
	var upd = func(_i, _k) -> void:
		if not is_instance_valid(mi):
			return
		var pr = pair_fn.call()
		if pr is Array and pr.size() == 2:
			hist.push_front(pr)
		while hist.size() > n:
			hist.pop_back()
		if hist.size() < 2:
			return
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var m = hist.size()
		for i in m - 1:
			var ua = 1.0 - float(i) / (n - 1)
			var ub = 1.0 - float(i + 1) / (n - 1)
			var ca = Color(col.r, col.g, col.b, col.a * ua)
			var cb = Color(col.r, col.g, col.b, col.a * ub)
			var a0: Vector3 = hist[i][0]
			var b0: Vector3 = hist[i][1]
			var a1: Vector3 = hist[i + 1][0]
			var b1: Vector3 = hist[i + 1][1]
			_qv(st, a0, Vector2(ua, 0.0), ca)
			_qv(st, b0, Vector2(ua, 1.0), ca)
			_qv(st, b1, Vector2(ub, 1.0), cb)
			_qv(st, a0, Vector2(ua, 0.0), ca)
			_qv(st, b1, Vector2(ub, 1.0), cb)
			_qv(st, a1, Vector2(ub, 0.0), cb)
		mi.mesh = st.commit()
	var fin = func() -> void:
		_fade_free(mi, 0.0, 0.2)
	pj.every(dur, dt, upd, fin)
	return mi


## Canlı eğri (tel / iplik / zincirsiz bağ): pts_fn her karede noktaları verir
static func _live_curve(pj: PathJutsu, pts_fn: Callable, dur: float, w: float, col: Color, o := {}, add := false, dt := 1.0 / 40.0) -> MeshInstance3D:
	var oo = o.duplicate()
	if not oo.has("ends"):
		oo["ends"] = 0.0
	var mi = _mi(null, _trail_mat(add), oo)
	pj.scene_add(mi, Vector3.ZERO)
	var upd = func(_i, _k) -> void:
		if not is_instance_valid(mi):
			return
		var pts: Array = pts_fn.call()
		if pts.size() < 2:
			mi.visible = false
			return
		mi.visible = true
		mi.mesh = _cross(pts, _fill(pts.size(), w), _fill(pts.size(), col), Vector3.ZERO)
	upd.call(0, 0.0)
	var fin = func() -> void:
		_fade_free(mi, 0.0, 0.25)
	pj.every(dur, dt, upd, fin)
	return mi


## Zincir: halkalar MultiMesh'te; _chain_set ile bir yol boyunca dizilir (ardışık halkalar 90° döner)
static func _chain(pj: PathJutsu, n: int, tint := IRON) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _link_mesh()
	mm.instance_count = n
	mm.visible_instance_count = 0
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _solid_mat()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_instance_shader_parameter("tint", tint)
	mmi.set_instance_shader_parameter("metal", 1.0)
	pj.scene_add(mmi, Vector3.ZERO)
	return mmi


static func _chain_set(mmi: MultiMeshInstance3D, pts: Array, gap := 0.13) -> void:
	if mmi == null or not is_instance_valid(mmi):
		return
	var mm = mmi.multimesh
	var cnt = 0
	var carry = 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var L = a.distance_to(b)
		if L < 0.0001:
			continue
		var f = (b - a) / L
		var bs = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT)
		var s = carry
		while s < L and cnt < mm.instance_count:
			var roll = Basis(f, PI * 0.5) if cnt % 2 == 1 else Basis.IDENTITY
			mm.set_instance_transform(cnt, Transform3D(roll * bs, a + f * s))
			cnt += 1
			s += gap
		carry = s - L
	mm.visible_instance_count = cnt


## Sarkık eğri: a'dan b'ye, ortası sag kadar aşağı (eksi = yukarı kavis)
static func _sag(a: Vector3, b: Vector3, sag: float, n := 14) -> Array:
	var out = []
	for i in n + 1:
		var u = float(i) / n
		out.append(a.lerp(b, u) + Vector3.DOWN * sin(u * PI) * sag)
	return out


## Chakra iplikleri: iki elin parmaklarından birime (kukla) uzanan ince mavi iplikler, içinde akan chakra boncukları
static func _strings(pj: PathJutsu, c: Node3D, unit: Node3D, dur: float, offs: Array) -> void:
	var cw = weakref(c)
	var uw = weakref(unit)
	var lines = []
	for k in offs.size():
		var mi = _mi(_unit_line(0.016), _trail_mat(true), {"tint": Color(CHAKRA.r, CHAKRA.g, CHAKRA.b, 0.9), "core": 0.7, "pulse": 2.5, "ends": 0.0, "head": 0.0})
		pj.scene_add(mi, c.global_position)
		lines.append(mi)
		mi.create_tween().tween_method(_pf(mi, "head"), 0.0, 1.0, 0.12)   # iplik parmaktan fırlar
	var upd = func(_i, _k) -> void:
		var cc = cw.get_ref()
		var u = uw.get_ref()
		for k in lines.size():
			var mi = lines[k]
			if not is_instance_valid(mi):
				continue
			if cc == null or u == null or not is_instance_valid(cc) or not is_instance_valid(u):
				mi.visible = false
				continue
			var a: Vector3 = pj.hand_pos(cc, k % 2 == 0) + Vector3(((k / 2) % 3 - 1) * 0.03, 0.0, 0.0)
			var b: Vector3 = u.global_transform * offs[k]
			_aim_line(mi, a, b)
	upd.call(0, 0.0)
	var fin = func() -> void:
		for mi in lines:
			_fade_free(mi, 0.0, 0.2)
	pj.every(dur, 1.0 / 30.0, upd, fin)


## Tahta kıymığı + ince toz: kukla açılıp kapanırken eklemlerden dökülür
static func _splinters(pj: PathJutsu, pos: Vector3, s: float) -> void:
	_chunks(pj, pos, 6, 4.0 * s, 0.07 * s, WOOD, 0.6)
	_dust_ring(pj, pj.gp(pos), 0.3 * s, 2.0, 6, 0.35 * s, 0.6)


## Kuklayı sahnede belirt: iplikler parmaklardan fırlar, kukla yaylanarak açılır; dur sn sonra katlanıp kaybolur
static func _hang(pj: PathJutsu, c: Node3D, at: Vector3, d: Vector3, dur: float, s := 1.0, dark := false) -> Node3D:
	var pup = pj._puppet_mesh(s, dark)
	pj.scene_add(pup, at)
	pup.rotation.y = atan2(d.x, d.z)
	pup.scale = Vector3(1.0, 0.75, 1.0)
	pup.create_tween().tween_property(pup, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_strings(pj, c, pup, dur, [Vector3(0.25, 1.45 * s, 0), Vector3(-0.25, 1.45 * s, 0), Vector3(0.1, 1.75 * s, 0), Vector3(-0.1, 1.75 * s, 0),
		Vector3(0.42, 1.05 * s, 0), Vector3(-0.42, 1.05 * s, 0)])
	_splinters(pj, at + Vector3.UP * s, s)
	var pw = weakref(pup)
	pj.after(dur, func():
		var p = pw.get_ref()
		if p != null:
			_splinters(pj, p.global_position + Vector3.UP, s * 0.8)
			var ftw = p.create_tween()
			ftw.tween_property(p, "scale", Vector3(1.0, 0.05, 1.0), 0.15).set_ease(Tween.EASE_IN)
			ftw.tween_callback(p.queue_free))
	return pup


# ================================================================== 1. Kugutsu: Kaijin Tensen
## ref: Karasu döner, kollarından bıçaklar dışa fırlar, çevresinde mor-pembe matkap çizgileri; sonunda içindeki patlayıcı
## turuncu-kızıl bir ateş topu olur (koyu duman topakları, savrulan bıçak kıymıkları).
static func kugutsu_kaijin_tensen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.25)
	var id = "kugutsu_kaijin_tensen"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.3)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var start: Vector3 = c.global_position + d * 1.8 + Vector3.UP * 0.5
	var pup = _hang(pj, c, start, d, 1.9, 1.0, false)
	var blades: Array = []
	for k in 6:   # bıçaklar: kollar hizasında dışa yaylanarak açılır, üstlerinden parıltı kayar
		var a = TAU * k / 6.0
		var bl = _blade_mi(1.25, 0.08)
		pup.add_child(bl)
		bl.position = Vector3(0, 1.0 + (k % 2) * 0.35, 0)
		bl.rotation = Vector3(0, a, 0)
		bl.scale = Vector3(1.0, 1.0, 0.04)
		var bt = bl.create_tween()
		bt.tween_interval(0.04 * k)
		bt.tween_property(bl, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bt.tween_method(_pf(bl, "shine"), -1.5, 2.5, 0.22)
		blades.append(bl)
	pj.after(0.32, func():
		for bl in blades:
			if is_instance_valid(bl):
				_glint(pj, bl.global_transform * Vector3(0, 0, 1.15), 0.7, 0.2, Color(0.9, 0.8, 1.0)))
	var pw = weakref(pup)
	var s = {"p": start, "done": false}
	Sfx.play("swing_blade", start, 1.2)
	for bi in [0, 3]:   # iki bıçağın süpürdüğü gümüş-lila disk izi
		var blr = weakref(blades[bi])
		var pair = func() -> Array:
			var b = blr.get_ref()
			if b == null or s["done"]:
				return []
			var xf: Transform3D = b.global_transform
			return [xf * Vector3(0, 0, 0.3), xf * Vector3(0, 0, 1.25)]
		_smear(pj, pair, 0.9, 4, Color(0.9, 0.84, 1.0, 0.7), {"rim": 1.0, "tear": 0.12}, false, 0.03)
	var spin = func(i, _k):
		var p = pw.get_ref()
		var cc = cw.get_ref()
		if p == null or cc == null or s["done"]:
			return
		var x = tw.get_ref() if tw else null
		var goal: Vector3 = (x.global_position + Vector3.UP * 0.3) if x != null and pj.live(x) else start + d * 12.0
		var v: Vector3 = goal - s["p"]
		s["p"] += v.normalized() * minf(v.length(), 30.0 * 0.03)
		p.global_position = s["p"]
		p.rotation.y += 0.9
		if i % 2 == 0:
			_drill_rings(pj, s["p"], p.rotation.y)
		if i % 3 == 1:   # alttan kalkan toz: kukla yere yakın döner
			var g = pj.gp(s["p"])
			_puff(pj, g + Vector3.UP * 0.2, Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)) * 2.5, 0.3, 0.9, 0.5)
		if i % 4 == 3 and i > 6:
			for e in pj.enemies_near(cc, s["p"], 2.2):
				e.take_hit(pj.inf(cc, id, 0.3, {"knock": 0.0, "kind": "light", "poison": 3.0, "bleed": 2.0, "hitstop": 0.02}))
				Sfx.play("slash", s["p"], 1.2)
				var ep: Vector3 = e.global_position + Vector3.UP * 1.0
				_sparks(pj, ep, 5, ep - s["p"], 0.7, 9.0)
				_glint(pj, ep, 0.5, 0.14)
	var boom = func():
		s["done"] = true
		var p = pw.get_ref()
		var cc = cw.get_ref()
		if p == null or cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, s["p"], 2.6):   # havaya savurur
			e.take_hit(pj.inf(cc, id, 0.5, {"knock": 0.0, "launch": 10.0, "kind": "heavy", "poison": 3.0}))
		for k in 3:   # yukarı savuran dikey bıçak yayları
			var a = k * TAU / 3.0 + randf() * 0.5
			var ax = Vector3(cos(a), 0, sin(a))
			_slash_arc(pj, s["p"] + Vector3.UP * 0.6, ax, Vector3.UP, 1.6, -0.8, 1.4, 0.45, Color(0.82, 0.6, 1.0, 0.85), 0.07, 0.03, 0.18)
		pj.after(0.28, func():
			var c2 = cw.get_ref()
			var p2 = pw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			var at: Vector3 = (p2.global_position if p2 != null else s["p"]) + Vector3.UP * 1.6
			_blast(pj, at, 1.5)
			pj.shake(0.6)
			Sfx.play("boom", at, 0.9)
			pj.hit(c2, at, 4.0, pj.inf(c2, id, 1.5, {"knock": 14.0, "launch": 2.0, "kind": "heavy", "element": "katon", "burn": 2.5, "hitstop": 0.08})))
	pj.every(0.9, 0.03, spin, boom)


## Matkap çizgileri: dönen kuklanın çevresinde eğik, mor + pembe yaylar (ref: Karasu'yu saran parlak çizgiler)
static func _drill_rings(pj: PathJutsu, q: Vector3, a0: float) -> void:
	for j in 2:
		var R = 1.5 if j == 0 else 1.95
		var h = 1.1 + randf_range(-0.35, 0.45)
		var tilt = randf_range(-0.3, 0.3)
		var c0 = q + Vector3.UP * h
		var pts = []
		for m in 11:
			var u = m / 10.0
			var a = a0 + u * 3.0 + j * PI
			pts.append(c0 + Vector3(cos(a) * R, sin(u * 3.0) * tilt * R, sin(a) * R))
		var col = Color(0.72, 0.38, 1.0, 0.9) if j == 0 else Color(1.0, 0.52, 0.84, 0.75)
		_line(pj, pts, 0.07 if j == 0 else 0.045, 0.02, col, 0.05, 0.0, 0.16, {"core": 0.45})


## Kuklanın gizli patlayıcısı: katmanlı ateş topu soğuyup kararır, koyu duman topakları yükselir, çelik kıymıkları ve
## kıvılcımlar saçılır, havada basınç halkası, yerde is lekesi
static func _blast(pj: PathJutsu, at: Vector3, s: float) -> void:
	for k in 5:
		var mi = _mi(_lump(k % 4), _blast_mat(), {"heat": 1.1})
		var off = Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.5), randf_range(-0.6, 0.6)) * s
		pj.scene_add(mi, at + off * 0.3)
		mi.scale = Vector3.ONE * 0.25 * s
		var big = s * randf_range(1.3, 2.0)
		var btw = mi.create_tween()
		btw.tween_property(mi, "scale", Vector3.ONE * big, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		btw.parallel().tween_property(mi, "global_position", at + off, 0.2)
		btw.tween_method(_pf(mi, "heat"), 1.0, 0.0, 0.7)
		btw.parallel().tween_property(mi, "global_position", at + off + Vector3.UP * 1.4 * s, 0.7).set_ease(Tween.EASE_IN)
		btw.parallel().tween_method(_pf(mi, "dis"), 0.0, 1.0, 0.75)
		btw.tween_callback(mi.queue_free)
	for k in 6:
		var dv = Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		_puff(pj, at + dv * 0.4 * s, dv * 4.0 * s, 0.4 * s, 1.3 * s, 1.1, Color(0.22, 0.18, 0.19))
	_chunks(pj, at, 7, 11.0, 0.12, IRON, 0.5, Vector3.ZERO, {"metal": 1.0})
	_sparks(pj, at, 14, Vector3.UP, 1.2, 14.0)
	_ring(pj, at, Vector3.UP, 0.5 * s, 4.2 * s, 0.35, Color(1.0, 0.75, 0.45, 0.7), true)
	_ground_disc(pj, pj.gp(at), 2.0 * s, Color(0.12, 0.1, 0.09, 0.75), 3.0)


# ================================================================== 2. Fūma Kaiten Yaiba
## Dev fūma shurikeniyle topaç gibi dönerek ilerlersin: kanatların süpürdüğü gümüş disk, kanat uçlarında çelik parıltısı,
## kanatların yere sürtündüğü yerde dairesel oluk ve savrulan toprak; isabette kıvılcım ve kısa kesik.
static func fuma_kaiten_yaiba(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.3)
	var id = "fuma_kaiten_yaiba"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var sh = pj._fuma_node(1.1)
	pj.scene_add(sh, c.global_position + Vector3.UP * 1.1)
	var f0 = c.facing if "facing" in c else 0.0
	var hitk = {}
	var gs = {"last": pj.gp(c.global_position)}
	for j in 2:   # iki karşıt kanat ucunun süpürdüğü bant
		var tip = Vector3(1.0, 0, 0) if j == 0 else Vector3(-1.0, 0, 0)
		var pair = func() -> Array:
			if not is_instance_valid(sh):
				return []
			var xf: Transform3D = sh.global_transform
			return [xf * (tip * 0.6), xf * (tip * 1.2)]
		_smear(pj, pair, 1.2, 5, Color(0.86, 0.9, 0.98, 0.65), {"rim": 1.0, "ink": 0.25}, false)
	var tick = func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = d * 7.0
		if "facing" in cc:
			cc.facing = f0 + k * TAU * 4.0
		if is_instance_valid(sh):
			sh.global_position = cc.global_position + Vector3.UP * 1.1
			sh.rotate_y(0.5)
		if i % 6 == 0:   # havayı kesen ince yay + yerde oluk
			var a0 = i * 0.3
			var ctr: Vector3 = cc.global_position + Vector3.UP * 1.1
			_line(pj, _arc(ctr, Vector3.RIGHT, Vector3.BACK, 1.7, a0, a0 + PI, 12), 0.07, 0.02, WHITE, 0.06, 0.0, 0.14, {"core": 1.0})
			Sfx.play("whoosh", cc.global_position, 1.3)
			var g = pj.gp(cc.global_position)
			_gouge(pj, gs["last"], g, 0.32, 1.4)
			gs["last"] = g
			var sd = Vector3(-d.z, 0, d.x) * (1.0 if (i / 6) % 2 == 0 else -1.0)
			_chunks(pj, g + sd * 1.2, 3, 4.0, 0.08, SOIL, 0.6, sd * 3.0)
			_puff(pj, g + sd * 1.2 + Vector3.UP * 0.2, sd * 3.0, 0.3, 1.0, 0.55)
		if i % 9 == 4 and is_instance_valid(sh):
			_glint(pj, sh.global_transform * Vector3(1.15, 0, 0), 0.55, 0.16)
		for e in pj.enemies_near(cc, cc.global_position, 1.9):
			var key = "%d_%d" % [e.get_instance_id(), i / 15]
			if hitk.has(key):
				continue
			hitk[key] = true
			e.take_hit(pj.inf(cc, id, 0.38, {"knock": 4.0, "kind": "heavy", "bleed": 1.5, "hitstop": 0.03}))
			var ep: Vector3 = e.global_position + Vector3.UP * 1.1
			_sparks(pj, ep, 6, ep - cc.global_position, 0.6, 10.0)
			_nick(pj, ep, ep - cc.global_position, 0.6, Color(0.8, 0.85, 0.95, 0.85))
	var fin = func():
		var cc = cw.get_ref()
		if is_instance_valid(sh):
			_glint(pj, sh.global_position, 1.0, 0.25)
			_dust_ring(pj, pj.gp(sh.global_position), 0.6, 3.0, 6, 0.4, 0.7)
			sh.queue_free()
		if cc != null and is_instance_valid(cc) and cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		if cc != null and is_instance_valid(cc):
			pj._face(cc, tt if tt != null and is_instance_valid(tt) else null)
	pj.every(1.2, 1.0 / 60.0, tick, fin)


# ================================================================== 3. Hagoromo: Tennyo no Mai
## Göksel kız dansı: dönerken iki koldan akan ipek-tüy kurdeleleri gövdeyi sarar, her dönüşte keskin chakra tüyleri dışa
## fırlar (arkalarında ince kesik çizgisi), sonra süzülerek yere iner ve dağılır; ayak dibinde hafif rüzgâr tozu.
static func hagoromo_tennyo_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.2)
	var id = "hagoromo_tennyo_no_mai"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var f0 = c.facing if "facing" in c else 0.0
	var hitk = {}
	for j in 2:
		var pair = func() -> Array:
			var cc = cw.get_ref()
			if cc == null or not is_instance_valid(cc):
				return []
			var fa: float = cc.facing if "facing" in cc else 0.0
			var a = -fa + j * PI
			var dv = Vector3(cos(a), 0, sin(a))
			var bob = sin(fa * 1.5 + j) * 0.18
			var base: Vector3 = cc.global_position
			return [base + dv * 0.7 + Vector3.UP * (0.8 + bob), base + dv * 1.25 + Vector3.UP * (1.5 + bob)]
		_smear(pj, pair, 1.1, 16, Color(0.86, 0.93, 1.0, 0.7), {"rim": 0.8, "soft": 0.3, "tear": 0.08}, false)
	_dust_ring(pj, pj.gp(c.global_position), 0.6, 2.5, 8, 0.35, 0.8, Color(0.85, 0.85, 0.8))
	var tick = func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if "facing" in cc:
			cc.facing = f0 + k * TAU * 3.0
		if cc is CharacterBody3D:
			cc.velocity = d * 6.0
		if i % 5 == 0:
			var a = randf() * TAU
			var p: Vector3 = cc.global_position + Vector3.UP * randf_range(0.7, 1.6)
			var dir = Vector3(cos(a), 0, sin(a))
			_line(pj, _seg(p, p + dir * 2.4, 6), 0.05, 0.012, Color(HANE.r, HANE.g, HANE.b, 0.85), 0.08, 0.0, 0.16, {"core": 0.6})
			_feather_shot(pj, p, dir, 2.4, 0.2)
		for e in pj.enemies_near(cc, cc.global_position, 2.4):
			var key = "%d_%d" % [e.get_instance_id(), i / 20]
			if hitk.has(key):
				continue
			hitk[key] = true
			e.take_hit(pj.inf(cc, id, 0.5, {"knock": 3.0, "kind": "heavy", "bleed": 1.0, "hitstop": 0.03}))
			var ep: Vector3 = e.global_position + Vector3.UP * 1.0
			_nick(pj, ep, ep - cc.global_position, 0.55, Color(0.75, 0.88, 1.0, 0.85))
			for m in 3:
				var fd = Vector3(randf_range(-1, 1), randf_range(0.0, 0.6), randf_range(-1, 1)).normalized()
				_feather_shot(pj, ep, fd, 1.2, 0.15)
	var fin = func():
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc) and cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
	pj.every(1.1, 1.0 / 60.0, tick, fin)
	Sfx.play("whoosh", c.global_position, 1.1)


## Fırlayan tüy: dist metreyi t sn'de keser, sonra salınarak süzülür, yere yatar, lif lif dağılır
static func _feather_shot(pj: PathJutsu, p: Vector3, dir: Vector3, dist: float, t: float) -> void:
	var fth = _feather_mi(0.75)
	pj.scene_add(fth, p)
	fth.look_at(p + dir + Vector3(0.001, 0, 0), Vector3.UP)
	fth.rotate_object_local(Vector3.UP, PI)   # tüyün ucu (+Z) gidiş yönüne
	var p1 = p + dir * dist
	var ph = randf() * TAU
	var sw = Vector3(-dir.z, 0, dir.x).normalized()
	var stt = {"done": false}
	var fall = func(q: float) -> void:
		if stt["done"] or not is_instance_valid(fth):
			return
		if q < t:
			fth.global_position = p.lerp(p1, q / t)
			return
		var u = q - t
		var pp = p1 + dir * (1.0 - exp(-2.0 * u)) * 0.6 + Vector3.DOWN * 0.9 * u + sw * sin(u * 4.0 + ph) * 0.35
		var fl = Game.jutsu_floor(pp.x, pp.z)
		if pp.y <= fl + 0.02:
			stt["done"] = true
			fth.global_position = Vector3(pp.x, fl + 0.02, pp.z)
			fth.rotation = Vector3(0, fth.rotation.y, 0)
			_fade_free(fth, randf_range(0.6, 1.2), 0.5, "dis", 0.0, 1.0)
			return
		fth.global_position = pp
		fth.rotation = Vector3(sin(u * 5.0 + ph) * 0.9, fth.rotation.y + 0.02, cos(u * 4.0 + ph) * 0.7)
	var ftw = fth.create_tween()
	ftw.tween_method(fall, 0.0, t + 3.5, t + 3.5)
	ftw.tween_callback(func() -> void:
		if not stt["done"] and is_instance_valid(fth):
			fth.queue_free())


# ================================================================== 4. Hagoromo: Sōki Giri
## Yan yan iki kişi: tüy izi bırakan ani atılış (yolda dökülen tüyler), yanıltıcı kopyanın çıktığı yerde tüy girdabı;
## elde tüy biçimli chakra kılıcı, hedefte çapraz X kesiği (mavi gövde + beyaz kesici kenar), ardından tüy kıymıkları
## saçılır ve yerde iki çapraz oyuk kalır.
static func hagoromo_soki_giri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 0.9)
	var id = "hagoromo_soki_giri"
	if tt == null:
		return
	var d = pj._face(c, tt)
	var sd = d.cross(Vector3.UP).normalized()
	var p1: Vector3 = pj.gp(tt.global_position - d * 1.3 + sd * 1.2)
	var p2: Vector3 = pj.gp(tt.global_position - d * 1.3 - sd * 1.2)
	_dash_trail(pj, c.global_position, p1)
	c.global_position = p1
	pj.decoy(c, p2, 0.8)
	for m in 6:   # kopyanın doğduğu yerde tüy girdabı
		var a = m * TAU / 6.0
		_feather_shot(pj, p2 + Vector3.UP * randf_range(0.5, 1.6), Vector3(cos(a), 0.15, sin(a)).normalized(), 1.0, 0.18)
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.2, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		pj._face(cc, x)
		_feather_blade(pj, cc, 0.4)
		pj.anim(cc, "slash_c", 2.4)
		var cen: Vector3 = x.global_position + Vector3.UP * 1.1
		for s in [-1.0, 1.0]:   # X kesiği
			var a = cen + sd * s * 1.1 + Vector3.UP * 0.9
			var b = cen - sd * s * 1.1 - Vector3.UP * 0.9
			var dv = (b - a).normalized()
			var bulge = d.cross(dv).normalized() * 0.25
			var pts = []
			for i in 13:
				var u = i / 12.0
				pts.append(a.lerp(b, u) + bulge * sin(u * PI))
			_line(pj, pts, 0.42, 0.42, Color(0.55, 0.78, 1.0, 0.85), 0.06, 0.08, 0.22, {"ink": 0.6, "tear": 0.1})
			_line(pj, pts, 0.12, 0.12, WHITE, 0.06, 0.06, 0.18, {"core": 1.0})
		_glint(pj, cen, 1.3, 0.24)
		_sparks(pj, cen, 6, -d, 0.9, 8.0, Color(0.75, 0.9, 1.0))
		pj.after(0.1, func():
			for m in 7:
				var fd = Vector3(randf_range(-1, 1), randf_range(0.0, 0.8), randf_range(-1, 1)).normalized()
				_feather_shot(pj, cen, fd, 1.6, 0.16)
			var g = pj.gp(cen)
			_gouge(pj, g + sd * 0.9 - d * 0.6, g - sd * 0.9 + d * 0.6, 0.12, 1.4)
			_gouge(pj, g - sd * 0.9 - d * 0.6, g + sd * 0.9 + d * 0.6, 0.12, 1.4))
		Sfx.play("swing_sword", cen, 1.2)
		x.take_hit(pj.inf(cc, id, 1.4, {"knock": 8.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1, "pierce_guard": true})))


## Ani atılış izi: gövde boyu birkaç paralel ince çizgi + yola dökülen tüyler
static func _dash_trail(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	for h in [0.5, 1.0, 1.5]:
		var off = Vector3(randf_range(-0.1, 0.1), h + randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
		_line(pj, _seg(a + off, b + off, 8), 0.02, 0.09, Color(0.85, 0.93, 1.0, 0.8), 0.05, 0.05, 0.25, {"core": 0.5})
	for m in 4:
		var p = a.lerp(b, randf()) + Vector3.UP * randf_range(0.6, 1.5)
		_feather_shot(pj, p, (b - a).normalized(), 0.3, 0.1)


## Tüy biçimli chakra kılıcı: sağ ele bağlanır, dur sn sonra lif lif dağılır
static func _feather_blade(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	var fb = _mi(_feather_mesh(), _solid_mat(), {"tint": Color(0.8, 0.9, 1.0), "glow": 0.9})
	ba.add_child(fb)
	fb.position = Vector3(0, 0, 0.55)
	fb.rotation = Vector3(0, 0, PI * 0.5)
	fb.scale = Vector3(1.4, 1.0, 1.0)
	var btw = fb.create_tween()
	btw.tween_interval(dur)
	btw.tween_method(_pf(fb, "dis"), 0.0, 1.0, 0.2)
	btw.tween_callback(ba.queue_free)


# ================================================================== 5. Nuibari: Jigumo Nui
## Dikiş: iğne kılıç ışık gibi hedeften hedefe geçer; arkasında gergin gümüş tel açılır, her hedefin gövdesinde tel ilmik
## olur (iğne girerken parıltı + kıvılcım). Tel bağ süresince gergin kalır, boyunca parıltılar kayar; sonra söner.
static func nuibari_jigumo_nui(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var o = c.global_position + Vector3.UP * 1.1
	var hits = []
	for e in pj.enemies_near(c, c.global_position + d * 9.0, 10.0):
		var v = e.global_position - c.global_position
		v.y = 0
		if pj.live(e) and v.normalized().dot(d) > 0.6:
			hits.append(e)
	var path: Array = [o]
	var radii: Array = [0.0]
	for e in hits:   # tel: hedeften hedefe dikilen ince parlak çizgi
		var p = e.global_position + Vector3.UP
		path.append(p)
		radii.append(e.radius)
		if e.has_method("apply_status"):
			e.apply_status("bind", 3.0)
		pj.hit(c, p, e.radius + 0.4, pj.inf(c, "nuibari_jigumo_nui", 1.0, {"knock": 0.0, "kind": "heavy", "bleed": 4.0}))
	if hits.is_empty():
		_needle_run(pj, [o, o + d * 16.0], [0.0, 0.0], 0.0)
	else:
		_needle_run(pj, path, radii, 3.0)
	Sfx.play("whoosh", c.global_position, 1.8)


static func _needle_run(pj: PathJutsu, path: Array, radii: Array, hold: float) -> void:
	var pts = []
	var times = [0.0]
	var tot = 0.0
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var n = clampi(int(a.distance_to(b) / 0.5) + 1, 1, 40)
		for j in n:
			pts.append(a.lerp(b, float(j) / n))
		tot += maxf(0.04, a.distance_to(b) / 70.0)
		times.append(tot)
	pts.append(path[path.size() - 1])
	var wire = _mi(_cross(pts, _fill(pts.size(), 0.024), _fill(pts.size(), WIRE), pts[0]), _trail_mat(false), {"core": 0.7, "ends": 0.0})
	pj.scene_add(wire, pts[0])
	if hold > 0.0:
		_sweep(wire, tot, hold, 0.5, false)
	else:
		_sweep(wire, tot, 0.08, 0.2, true)
	# iğne başı: kendi parlak iğnem yol boyunca koşar
	var nb = MB.new()
	nb.add("cyl", Vector3(0, 0, 0), Vector3(0.02, 0.9, 0.02), STEEL, Vector3(90, 0, 0), 5)
	nb.add("cone", Vector3(0, 0, -0.5), Vector3(0.025, 0.12, 0.025), Color(0.95, 0.96, 1.0), Vector3(-90, 0, 0), 5)
	var ndl = _mi(nb.build(), _solid_mat(), {"metal": 1.0, "glow": 0.4})
	pj.scene_add(ndl, path[0])
	var runf = func(q: float) -> void:
		if not is_instance_valid(ndl):
			return
		var k = 0
		while k < times.size() - 2 and q > times[k + 1]:
			k += 1
		var a: Vector3 = path[k]
		var b: Vector3 = path[k + 1]
		var span = maxf(0.001, times[k + 1] - times[k])
		var u = clampf((q - times[k]) / span, 0.0, 1.0)
		ndl.global_position = a.lerp(b, u)
		if a.distance_to(b) > 0.01:
			ndl.look_at(b + Vector3(0.0001, 0, 0), Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
	var ntw = ndl.create_tween()
	ntw.tween_method(runf, 0.0, tot, tot)
	ntw.tween_method(_pf(ndl, "dis"), 0.0, 1.0, 0.15)
	ntw.tween_callback(ndl.queue_free)
	for i in range(1, path.size()):   # ilmikler: iğne geçerken tel gövdeyi sarar
		var p: Vector3 = path[i]
		var r = float(radii[i]) + 0.14
		var tm = times[i]
		pj.after(tm, func():
			_glint(pj, p, 0.8, 0.18)
			_sparks(pj, p, 5, Vector3.UP, 1.0, 6.0, Color(0.9, 0.95, 1.0))
			if r > 0.15:
				for m in 2:
					var tilt = 0.35 if m == 0 else -0.35
					var lp = []
					for j in 17:
						var a = j * TAU / 16.0
						lp.append(p + Vector3(cos(a) * r, sin(a) * r * tilt + (m - 0.5) * 0.25, sin(a) * r))
					_loop(pj, lp, 0.02, WIRE, 0.08, maxf(0.1, hold - tm), 0.4, {"core": 0.6}))
	if hold > 0.0:   # gergin telde kayan parıltılar
		var gl = func(_i, _k):
			_glint(pj, pts[randi() % pts.size()], 0.45, 0.2)
		pj.every(hold, 0.35, gl)


# ================================================================== 6. Hiramekarei Kaihō
## Hazırlık: çevreden mavi chakra iplikleri kılıca akar, gövdede titrek chakra alevleri. Salınım: dev mavi chakra bıçağı
## 140° yay çizer (mürekkep kenarlı gövde + beyaz kesici kenar + arkasından yankı dalgası), önde rüzgâr çizgileri;
## yerde yelpaze biçimli oluklar, yarık, ileri savrulan toprak ve toz duvarı.
static func hiramekarei_kaiho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var blue = Color(0.45, 0.7, 1.0)
	_kaiho_gather(pj, c, 0.45)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_c", 1.3)
		var at = c.global_position + Vector3.UP * 1.2
		var sd = Vector3(-d.z, 0, d.x)
		var a0 = deg_to_rad(-70.0)
		var a1 = deg_to_rad(70.0)
		_crescent(pj, at - Vector3.UP * 0.2, d, sd, 4.4, a0, a1, 2.6, Color(blue.r, blue.g, blue.b, 0.6), 0.1, 0.12, 0.3, {"ink": 0.35, "tear": 0.15})
		_crescent(pj, at - Vector3.UP * 0.2, d, sd, 5.8, a0, a1, 0.5, WHITE, 0.1, 0.1, 0.25, {"core": 1.0})
		pj.after(0.06, func():
			_crescent(pj, at - Vector3.UP * 0.3, d, sd, 7.0, a0, a1, 0.35, Color(0.75, 0.88, 1.0, 0.45), 0.12, 0.0, 0.3, {"soft": 0.7}))
		for k in 8:   # ileri itilen hava çizgileri
			var a = lerpf(a0, a1, (k + 0.5) / 8.0) + randf_range(-0.08, 0.08)
			var dv = d * cos(a) + sd * sin(a)
			var h = Vector3.UP * randf_range(-0.8, 0.6)
			_line(pj, _seg(at + h + dv * 1.0, at + h + dv * 9.0, 8), 0.1, 0.02, Color(0.75, 0.88, 1.0, 0.7), 0.12, 0.0, 0.2, {"core": 0.4})
		var g0 = pj.gp(at)
		for k in 5:   # yelpaze oluklar
			var a = lerpf(a0 * 0.8, a1 * 0.8, k / 4.0)
			var dv = d * cos(a) + sd * sin(a)
			_gouge(pj, g0 + dv * 1.6, g0 + dv * 7.0, 0.45, 2.0)
			_chunks(pj, pj.gp(g0 + dv * 5.0), 3, 6.0, 0.13, SOIL, 0.7, dv * 5.0)
			_puff(pj, pj.gp(g0 + dv * 6.0) + Vector3.UP * 0.5, dv * 5.0 + Vector3.UP, 0.6, 1.8, 0.9)
		_scar(pj, pj.gp(at + d * 4.0), 4.0, 9, 2.2)
		Combat.hit_zone(c, c.global_position, d, 7.0, 140.0, 3.0, pj.inf(c, "hiramekarei_kaiho", 2.2, {"knock": 16.0, "launch": 3.0, "kind": "heavy", "dir": d}))
		pj.shake(0.9))
	Sfx.play("whoosh", c.global_position, 0.7)


## Hiramekarei'ye chakra akışı: çevreden ele akan ince mavi iplikler + gövdede titrek alev çizgileri + elde parıltı
static func _kaiho_gather(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var cw = weakref(c)
	var flow = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var hp: Vector3 = pj.hand_pos(cc)
		var a = randf() * TAU
		var from = cc.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 2.8) + Vector3.UP * randf_range(0.3, 2.2)
		var mid = from.lerp(hp, 0.5) + Vector3.UP * 0.4
		var pts = []
		for m in 9:
			var u = m / 8.0
			pts.append(from.lerp(mid, u).lerp(mid.lerp(hp, u), u))
		_line(pj, pts, 0.03, 0.08, Color(0.5, 0.78, 1.0, 0.85), 0.12, 0.0, 0.1, {"core": 0.6}, true)
		if i % 2 == 0:
			var b: Vector3 = cc.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.4), randf_range(-0.4, 0.4))
			var fl = []
			for m in 6:
				fl.append(b + Vector3(sin(m * 1.3 + i) * 0.06, m * 0.12, 0))
			_line(pj, fl, 0.1, 0.01, Color(0.45, 0.72, 1.0, 0.7), 0.06, 0.0, 0.12, {}, true)
	pj.every(dur, 0.04, flow)
	pj.after(dur - 0.06, func():
		var cc = cw.get_ref()
		if cc != null and pj.live(cc):
			_glint(pj, pj.hand_pos(cc), 1.1, 0.2, Color(0.6, 0.8, 1.0)))


# ================================================================== 7. Kugutsu: Hiruko
## Zırh kuklası: chakra iplikleri gövdeye çekilir, kabuk yaylanarak kapanır (ayak dibinde toz, tahta kıymığı);
## kuyruk: boğum boğum ahşap kuyruk sırttan kavis çizip zehirli bıçak ucuyla saplanır, geri toplanır; isabette mor zehir
## damlaları saçılır, yere zehir lekesi düşer. Süre bitince kabuk çöker.
static func kugutsu_hiruko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 0.8)
	var hm = pj._hiruko_mesh()
	var mdl = c.get("model")
	if mdl:   # model yönüyle döner (gövde düğümü dönmüyor; yüz arkada kalıyordu)
		mdl.add_child(hm)
		hm.rotation.y = PI if mdl.get_meta("fwd_neg_z", true) else 0.0
	else:
		c.add_child(hm)
	var old_tail = hm.get_node_or_null("tail")
	if old_tail:   # modelin kutu omurlu kuyruğu yerine: cilalı koyu ahşap, eklemli akrep kuyruğu
		old_tail.visible = false
	var rest = _mi(_rest_tail_mesh(), _solid_mat(), {"metal": 0.55})
	rest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hm.add_child(rest)
	hm.scale = Vector3(1.0, 0.6, 1.0)
	hm.create_tween().tween_property(hm, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_strings(pj, c, hm, 0.5, [Vector3(0.3, 1.3, 0), Vector3(-0.3, 1.3, 0), Vector3(0.2, 0.8, 0.3), Vector3(-0.2, 0.8, 0.3)])
	_splinters(pj, c.global_position + Vector3.UP * 0.6, 1.0)
	_dust_ring(pj, pj.gp(c.global_position), 0.5, 2.5, 8, 0.4, 0.7)
	if c is Player:
		Buffs.add("hiruko", 15.0, {"armor": 0.65, "speed": 0.7, "_name": "Hiruko", "_desc": "zırh kuklasının içindesin"})
	pj.after(15.0, func():
		if is_instance_valid(hm):
			_splinters(pj, hm.global_position + Vector3.UP, 0.9)
			_dust_ring(pj, pj.gp(hm.global_position), 0.5, 2.0, 7, 0.4, 0.7)
			hm.queue_free())
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var a = c.global_position + Vector3.UP * 1.6 - c.face_dir() * 0.6
		var b2 = (tt.global_position + Vector3.UP if is_instance_valid(tt) else a + pj.fwd(c, t) * 8.0)
		if is_instance_valid(rest):   # kuyruk sırttan açılır: duran kuyruk gizlenir, vuruş bitince yerine döner
			rest.visible = false
			var rw = weakref(rest)
			pj.after(0.75, func():
				var r = rw.get_ref()
				if r != null:
					r.visible = true)
		_hiruko_tail(pj, a, b2)
		pj.hit(c, b2, 1.6, pj.inf(c, "kugutsu_hiruko", 1.2, {"knock": 8.0, "kind": "heavy", "poison": 5.0})))
	Sfx.play("blade", c.global_position, 0.7)


const LAQ := Color(0.21, 0.13, 0.12)
const LAQ2 := Color(0.27, 0.17, 0.14)


## Kuyruk boğumu (birim): cilalı koyu ahşap yumurta gövde, arkada bir sonrakini örten koyu dudak, açık ahşap eklem
## halkası, sırtta geriye yatık diken. -Z ileri (uca doğru); en/boy örnek ölçeğiyle verilir.
static func _plate_into(b: MB, xf: Transform3D, alt: bool) -> void:
	b.add_xf("sphere", xf * Transform3D(Basis.from_scale(Vector3(1.0, 0.85, 1.3)), Vector3.ZERO), LAQ2 if alt else LAQ, 12)
	b.add_xf("sphere", xf * Transform3D(Basis.from_scale(Vector3(1.12, 0.95, 0.45)), Vector3(0, 0.04, 0.45)), Color(0.12, 0.08, 0.08), 12)
	b.add_xf("cyl", xf * Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)) * Basis.from_scale(Vector3(0.7, 0.12, 0.7)), Vector3(0, 0, 0.62)), Color(0.56, 0.39, 0.23), 10)
	b.add_xf("cone", xf * Transform3D(Basis.from_euler(Vector3(0.6, 0, 0)) * Basis.from_scale(Vector3(0.2, 0.42, 0.2)), Vector3(0, 0.48, 0.15)), Color(0.1, 0.07, 0.07), 5)


static func _tail_seg_mesh() -> ArrayMesh:
	if _cache.has("tailseg2"):
		return _cache["tailseg2"]
	var b = MB.new()
	_plate_into(b, Transform3D.IDENTITY, false)
	var m = b.build()
	_cache["tailseg2"] = m
	return m


## Zehirli uç: yassı çelik ok bıçak + ortasında mor zehir oluğu; yerel +Y uç
static func _sting_into(b: MB, xf: Transform3D) -> void:
	b.add_xf("prism", xf * Transform3D(Basis.from_scale(Vector3(0.32, 0.75, 0.05)), Vector3(0, 0.37, 0)), Color(0.82, 0.83, 0.88), 3)
	b.add_xf("box", xf * Transform3D(Basis.from_scale(Vector3(0.05, 0.55, 0.065)), Vector3(0, 0.3, 0)), Color(0.55, 0.24, 0.72))
	b.add_xf("cyl", xf * Transform3D(Basis.from_scale(Vector3(0.14, 0.12, 0.14)), Vector3(0, 0.0, 0)), Color(0.12, 0.08, 0.08), 8)


## Hiruko'nun duran kuyruğu: modeldeki eğriyle aynı (sırttan kalkıp başın üstünden öne kıvrılır), bindirmeli plakalarla
static func _rest_tail_mesh() -> ArrayMesh:
	if _cache.has("resttail"):
		return _cache["resttail"]
	var pts = []
	for k in 19:
		var f = k / 18.0
		var ang = lerpf(-0.3, PI * 0.78, f)
		pts.append(Vector3(0.35 * f * f, 1.1 + sin(ang) * 1.4, -0.4 - cos(ang) * 1.0 + f * 0.1))
	var b = MB.new()
	for k in 18:
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[k + 1]
		var dd = (p1 - p0).normalized()
		var w = lerpf(0.36, 0.17, k / 17.0)
		var xf = Transform3D(Basis(Quaternion(Vector3.FORWARD, dd)) * Basis.from_scale(Vector3(w, w, p0.distance_to(p1) * 1.35)), (p0 + p1) * 0.5)
		_plate_into(b, xf, k % 2 == 1)
	var td = (pts[18] - pts[17]).normalized()
	_sting_into(b, Transform3D(Basis(Quaternion(Vector3.UP, td)), pts[18]))
	var m = b.build()
	_cache["resttail"] = m
	return m


static func _sting_mesh() -> ArrayMesh:
	if _cache.has("sting"):
		return _cache["sting"]
	var b = MB.new()
	_sting_into(b, Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3.ZERO))   # uç -Z
	var m = b.build()
	_cache["sting"] = m
	return m


## Kuyruk: boğumlar a → b2 kavisinde ilerler (0.12 sn), saplanır, 0.3 sn sonra geri toplanır
static func _hiruko_tail(pj: PathJutsu, a: Vector3, b2: Vector3) -> void:
	var curve = func(q: float) -> Vector3: return a.lerp(b2, q) + Vector3.UP * sin(q * PI) * 2.5
	var n = 22
	var dq = 0.045
	var segs = []
	for j in n:
		var mi = _mi(_tail_seg_mesh(), _solid_mat(), {"metal": 0.55})
		pj.scene_add(mi, a)
		segs.append(mi)
	var tip = _mi(_sting_mesh(), _solid_mat(), {"metal": 1.0, "glow": 0.15})
	pj.scene_add(tip, a)
	tip.scale = Vector3.ONE * 1.3
	var T = 0.75
	var place = func(_i, k):
		var tm = k * T
		var hq = 0.0
		if tm < 0.12:
			hq = 1.0 - pow(1.0 - tm / 0.12, 2.0)
		elif tm < 0.42:
			hq = 1.0
		else:
			hq = clampf(1.0 - (tm - 0.42) / 0.3, 0.0, 1.0)
		for j in n:   # uçtan geriye: her boğum bir öncekinin arkasında, uca doğru incelir
			var mi = segs[j]
			if not is_instance_valid(mi):
				continue
			var q = hq - (j + 1) * dq
			if q < -dq * 0.5:
				mi.visible = false
				continue
			q = maxf(q, 0.0)
			var p: Vector3 = curve.call(q)
			var p2: Vector3 = curve.call(minf(1.0, q + dq))
			var L = p.distance_to(p2)
			if L < 0.001:
				mi.visible = false
				continue
			mi.visible = true
			var f = (p2 - p) / L
			var w = lerpf(0.2, 0.42, float(j) / (n - 1))
			mi.global_transform = Transform3D(Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT) * Basis.from_scale(Vector3(w, w, L * 1.35)), (p + p2) * 0.5)
		if is_instance_valid(tip):
			tip.visible = hq > 0.02
			var tp: Vector3 = curve.call(hq)
			var tp0: Vector3 = curve.call(maxf(0.0, hq - 0.03))
			if tp.distance_to(tp0) > 0.001:
				var tf = (tp - tp0).normalized()
				tip.global_transform = Transform3D(Basis.looking_at(tf, Vector3.UP if absf(tf.y) < 0.95 else Vector3.RIGHT) * Basis.from_scale(Vector3.ONE * 1.3), tp)
	var done = func():
		for mi in segs:
			if is_instance_valid(mi):
				mi.queue_free()
		if is_instance_valid(tip):
			tip.queue_free()
	pj.every(T, 1.0 / 60.0, place, done)
	var tipw = weakref(tip)
	var pair = func() -> Array:
		var tp = tipw.get_ref()
		if tp == null or not tp.visible:
			return []
		var xf: Transform3D = tp.global_transform
		return [xf * Vector3(0, 0, 0.0), xf * Vector3(0, 0, -0.75)]
	_smear(pj, pair, 0.2, 6, Color(0.6, 0.45, 0.75, 0.5), {"rim": 0.8}, false)
	pj.after(0.12, func():
		if is_instance_valid(tip):
			tip.create_tween().tween_method(_pf(tip, "shine"), -1.0, 2.0, 0.2)
		_glint(pj, b2, 0.9, 0.2)
		_sparks(pj, b2, 6, b2 - a, 0.8, 8.0)
		_poison_splash(pj, b2))


## Zehir: mor damlalar savrulur, düştükleri yerde mor leke; kısa mor buğu
static func _poison_splash(pj: PathJutsu, at: Vector3) -> void:
	for k in 8:
		var v = Vector3(randf_range(-1, 1), randf_range(0.4, 1.2), randf_range(-1, 1)) * randf_range(2.5, 5.0)
		var mi = _mi(_lump(k % 4), _solid_mat(), {"tint": POISON, "glow": 0.5})
		pj.scene_add(mi, at)
		mi.scale = Vector3.ONE * randf_range(0.06, 0.11)
		var stt = {"done": false}
		var dropf = func(q: float) -> void:
			if stt["done"] or not is_instance_valid(mi):
				return
			var p = at + v * q + Vector3.DOWN * 9.0 * q * q
			var fl = Game.jutsu_floor(p.x, p.z)
			if q > 0.05 and p.y <= fl:
				stt["done"] = true
				_ground_disc(pj, Vector3(p.x, fl, p.z), randf_range(0.18, 0.32), Color(POISON.r * 0.7, POISON.g * 0.6, POISON.b * 0.7, 0.8), 2.0)
				mi.queue_free()
				return
			mi.global_position = p
		var dtw = mi.create_tween()
		dtw.tween_method(dropf, 0.0, 1.5, 1.5)
		dtw.tween_callback(func() -> void:
			if is_instance_valid(mi):
				mi.queue_free())
	for k in 3:
		_puff(pj, at + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1)), 0.25, 0.8, 0.7, Color(0.62, 0.42, 0.72, 0.7))


# ================================================================== 8. Kama no Mai: Rakko
## ref: kara saplı, beyaz sargılı, kanca biçimli kusarigama; zincir gökyüzüne uzanır. Orak zincirle havaya fırlar (gerçek
## halkalı zincir elden çıkıp yayı izler), tepede dikine dönerek alçalır (her turda çelik hilal + parıltı), sonra dimdik
## hedefe iner: yerde derin yarık oluk, çatlak, savrulan toprak, kıvılcım. Zincir gevşeyip sarkar, orak ele geri çekilir.
static func kama_no_mai_rakko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 1.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var o = pj.hand_pos(c)
	var top = at + Vector3.UP * 8.0
	var dd = at - c.global_position
	dd.y = 0.0
	var fd = dd.normalized() if dd.length() > 0.1 else pj.fwd(c, t)
	var sd = Vector3(-fd.z, 0, fd.x)
	var cw = weakref(c)
	var KS = Basis.from_scale(Vector3.ONE * 2.2)
	var kama = _kama_head()
	pj.scene_add(kama, o)
	var chain = _chain(pj, 160)
	var arcp = func(q: float) -> Vector3: return o.lerp(top, q) + Vector3.UP * sin(q * PI) * 2.0
	var stt = {"p": o, "stuck": false}
	var T = 1.55
	var drive = func(_i, k):
		if not is_instance_valid(kama):
			return
		var tm = k * T
		var hand: Vector3 = pj.hand_pos(cw.get_ref()) if cw.get_ref() != null and is_instance_valid(cw.get_ref()) else o
		var p: Vector3
		var pts: Array = []
		if tm < 0.3:   # yükseliş: zincir yayı izler
			var q = tm / 0.3
			p = arcp.call(q)
			for m in 17:
				pts.append(arcp.call(q * m / 16.0))
			pts[0] = hand
			kama.global_position = p
			kama.look_at(p + (p - arcp.call(maxf(0.0, q - 0.05))).normalized() + Vector3(0.0001, 0, 0), Vector3.UP)
			kama.rotate_object_local(Vector3.RIGHT, tm * 30.0)
		elif tm < 0.6:   # tepede dikine dönerek alçalır
			var u = (tm - 0.3) / 0.3
			var ang = u * TAU * 2.0
			var ctr = top - Vector3.UP * u * 5.5
			p = ctr + (sd * cos(ang) + Vector3.UP * sin(ang)) * 1.2
			pts = _sag(hand, p, -1.0, 16)
			kama.global_transform = Transform3D(Basis(fd, -ang) * KS, p)
		elif tm < 0.65:   # dikine dalış (isabet 0.65 sn)
			var u2 = (tm - 0.6) / 0.05
			var from = top - Vector3.UP * 5.5 + sd * 1.2
			p = from.lerp(at + Vector3.UP * 0.3, u2)
			pts = _sag(hand, p, 0.0, 16)
			kama.global_transform = Transform3D(Basis(fd, PI * 0.5) * KS, p)
		elif tm < 1.25:   # saplı: zincir gevşek sarkar
			p = at + Vector3.UP * 0.3
			var sl = clampf((tm - 0.65) / 0.2, 0.0, 1.0)
			pts = _sag(hand, p, hand.distance_to(p) * 0.12 * sl, 16)
			stt["stuck"] = true
		else:   # ele geri çekilir
			var u3 = clampf((tm - 1.25) / 0.28, 0.0, 1.0)
			p = (at + Vector3.UP * 0.3).lerp(hand, u3 * u3)
			pts = _sag(hand, p, hand.distance_to(p) * 0.1 * (1.0 - u3), 16)
			kama.rotate_object_local(Vector3.RIGHT, 0.5)
		kama.global_position = p
		stt["p"] = p
		_chain_set(chain, pts)
	var done = func():
		if is_instance_valid(kama):
			kama.queue_free()
		if is_instance_valid(chain):
			chain.queue_free()
	pj.every(T, 1.0 / 60.0, drive, done)
	var kw = weakref(kama)
	var pair = func() -> Array:
		var km = kw.get_ref()
		if km == null or stt["stuck"]:
			return []
		var xf: Transform3D = km.global_transform
		return [xf * Vector3(0.5, 0, -0.5), xf * Vector3(0.62, 0, -0.56)]
	_smear(pj, pair, 0.75, 7, Color(0.9, 0.92, 1.0, 0.8), {"core": 0.8}, false)
	for k in 6:   # tepede dönen orağın çelik hilalleri
		pj.after(0.3 + k * 0.05, func():
			var ctr = top - Vector3.UP * k * 1.0
			var a0 = deg_to_rad(k * 60.0)
			_slash_arc(pj, ctr, sd, Vector3.UP, 1.2, a0, a0 + deg_to_rad(120.0), 0.3, Color(0.85, 0.88, 0.95, 0.85), 0.05, 0.02, 0.16)
			if k % 2 == 0:
				_glint(pj, stt["p"], 0.7, 0.16))
	pj.after(0.6, func():
		_line(pj, _seg(top - Vector3.UP * 5.5 + sd * 1.2, at + Vector3.UP * 0.3, 10), 0.16, 0.06, WHITE, 0.05, 0.05, 0.2, {"core": 1.0}))
	pj.after(0.65, func():
		var g = at
		_gouge(pj, g - fd * 0.9, g + fd * 0.9, 0.35, 2.4)
		_scar(pj, g, 1.5, 7, 2.0)
		_chunks(pj, g, 8, 6.5, 0.12, SOIL, 1.0)
		_sparks(pj, g + Vector3.UP * 0.2, 10, Vector3.UP, 1.0, 9.0)
		_glint(pj, g + Vector3.UP * 0.4, 1.2, 0.22)
		_dust_ring(pj, g, 0.4, 3.5, 8, 0.45, 0.8)
		_ring(pj, g + Vector3.UP * 0.08, Vector3.UP, 0.3, 2.4, 0.3, Color(0.95, 0.92, 0.85, 0.6))
		pj.hit(c, at + Vector3.UP, 1.8, pj.inf(c, "kama_no_mai_rakko", 1.6, {"knock": 4.0, "kind": "heavy", "bleed": 4.0})))
	Sfx.play("blade", c.global_position, 0.8)


## Kusarigama başı (ref): kara sap, beyaz sargı halkaları, kancalı çelik ağız; -Z sap ucu (zincir), ağız +X'e kıvrık
static func _kama_head() -> MeshInstance3D:
	var b = MB.new()
	b.add("cyl", Vector3(0, 0, 0.0), Vector3(0.06, 0.7, 0.06), Color(0.12, 0.12, 0.14), Vector3(90, 0, 0), 8)
	for k in 6:
		b.add("cyl", Vector3(0, 0, 0.12 + k * 0.035), Vector3(0.068, 0.018, 0.068), Color(0.92, 0.92, 0.9), Vector3(90, 0, 0), 8)
	b.add("cone", Vector3(0, 0, 0.38), Vector3(0.06, 0.08, 0.06), Color(0.12, 0.12, 0.14), Vector3(90, 0, 0), 6)
	for k in 5:   # kanca ağız: sap başından +X'e doğru kıvrılan, incelen parçalar
		var u = k / 4.0
		var a = deg_to_rad(lerpf(-10.0, 70.0, u))
		var p = Vector3(0.08 + sin(a) * 0.32 * u + u * 0.12, 0, -0.33 - cos(a) * 0.1 * u - u * 0.12)
		b.add("box", p, Vector3(0.16, 0.02, lerpf(0.11, 0.035, u)), Color(0.88, 0.9, 0.95), Vector3(0, -rad_to_deg(a) - 20.0, 0))
	b.add("box", Vector3(0.0, 0, -0.33), Vector3(0.09, 0.05, 0.12), Color(0.12, 0.12, 0.14))
	var mi = _mi(b.build(), _solid_mat(), {"metal": 1.0})
	mi.scale = Vector3.ONE * 2.2
	return mi


# ================================================================== 9. Enbu: Ni no Dan
## Silah hortumu: zıplarken gövdeyi saran soluk rüzgâr sarmalları (döner, yükselir), içinde dönen shuriken / kunai halkası
## (çelik parıltıları yanıp söner), tabanda dönen toz ve zemin girdabı; sonunda hortum patlar (basınç halkası + dışa
## çizgiler) ve her silah ince bir izle hedefe savrulur.
static func enbu_ni_no_dan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 1.4)
	if c.get("velocity") != null:
		c.velocity.y = 12.0
	_twister(pj, c, 1.1)
	var g0 = pj.gp(c.global_position)
	var spiral = []
	for m in 25:   # yerde sarmal oyuk
		var u = m / 24.0
		var a = u * TAU * 1.6
		var q = g0 + Vector3(cos(a), 0, sin(a)) * lerpf(0.4, 2.4, u)
		spiral.append(Vector3(q.x, Game.jutsu_floor(q.x, q.z) + 0.04, q.z))
	var sw = _ground_strip(pj, spiral, _taper(spiral.size(), 0.18, 0.3, 6.0), Color(0.3, 0.24, 0.18, 0.75), {"tear": 0.3})
	_sweep(sw, 0.3, 1.6, 0.8, false)
	_dust_ring(pj, g0, 1.0, 3.0, 10, 0.45, 1.0)
	# hortumda dönen silah halkası
	var orbit = []
	for k in 16:
		var m = MeshInstance3D.new()
		m.mesh = pj.weapon_mesh("shuriken" if k % 2 == 0 else "kunai")
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.scale = Vector3.ONE * (1.5 if k % 2 == 0 else 1.2)
		pj.scene_add(m, c.global_position)
		orbit.append(m)
	var t0 = Game.now()
	var tick = func(i, _k):
		if not is_instance_valid(c):
			return
		var u = Game.now() - t0
		for k in orbit.size():
			var m = orbit[k]
			if not is_instance_valid(m):
				continue
			var a = k * TAU / orbit.size() + u * 11.0
			var h = 0.5 + fmod(k * 0.37, 1.0) * 2.4
			m.global_position = c.global_position + Vector3(cos(a), 0, sin(a)) * (1.1 + u * 0.6) + Vector3.UP * h
			m.look_at(m.global_position + Vector3(-sin(a), 0, cos(a)), Vector3.UP)
			m.rotate_object_local(Vector3.UP, u * 30.0)
		if i % 5 == 0:
			var gm = orbit[randi() % orbit.size()]
			if is_instance_valid(gm):
				_glint(pj, gm.global_position, 0.5, 0.14)
	var release = func():
		if is_instance_valid(c):
			_ring(pj, c.global_position + Vector3.UP * 1.2, Vector3.UP, 1.0, 5.0, 0.35, Color(0.94, 0.95, 1.0, 0.8))
			for m2 in 10:
				var a = m2 * TAU / 10.0 + randf_range(-0.2, 0.2)
				var dv = Vector3(cos(a), randf_range(-0.2, 0.4), sin(a)).normalized()
				var p0: Vector3 = c.global_position + Vector3.UP * 1.2
				_line(pj, _seg(p0 + dv * 1.4, p0 + dv * 4.5, 6), 0.12, 0.02, Color(0.94, 0.95, 1.0, 0.85), 0.08, 0.0, 0.16, {"core": 0.5})
		for k in orbit.size():   # savrulma: her silah bulunduğu yerden hedefe
			var m = orbit[k]
			if not is_instance_valid(m):
				continue
			var from = m.global_position
			m.queue_free()
			if not pj.live(c):
				continue
			var wm = MeshInstance3D.new()
			wm.mesh = pj.weapon_mesh("shuriken" if k % 2 == 0 else "kunai")
			wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.12, 0.12)), 36.0, wm, pj.inf(c, "enbu_ni_no_dan", 0.2, {"knock": 1.0, "kind": "light", "bleed": 1.0}), tt if k % 3 == 0 else null, false, 0.9)
			if pr and k % 2 == 0:
				pr.spin = Vector3(0, 30.0, 0)
			if pr:
				var prw = weakref(pr)
				var pair = func() -> Array:
					var x = prw.get_ref()
					if x == null or not is_instance_valid(x):
						return []
					var p: Vector3 = x.global_position
					return [p - Vector3.UP * 0.025, p + Vector3.UP * 0.025]
				_smear(pj, pair, 0.6, 6, Color(0.95, 0.96, 1.0, 0.7), {"core": 0.6}, false, 1.0 / 40.0)
	pj.every(0.75, 1.0 / 60.0, tick, release)
	Sfx.play("whoosh", c.global_position, 1.2)


## Hortum: gövdeyi takip eden, dönen, yükselirken açılan soluk sarmal çizgiler + üç kat yatay girdap
static func _twister(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var root = Node3D.new()
	pj.scene_add(root, c.global_position)
	var parts = []
	var gray = Color(0.94, 0.95, 1.0, 0.8)
	for k in 10:
		var ph = k * TAU / 10.0
		var pts = []
		for m in 23:
			var q = m / 22.0
			pts.append(Vector3(cos(ph + q * 9.0) * (0.7 + q * 0.9), q * 4.2, sin(ph + q * 9.0) * (0.7 + q * 0.9)))
		var mi = _mi(_cross(pts, _taper(pts.size(), 0.03, 0.08, 4.0), _fill(pts.size(), gray), Vector3.ZERO), _trail_mat(false), {"tear": 0.2, "head": 0.0})
		root.add_child(mi)
		parts.append(mi)
		var htw = mi.create_tween()
		htw.tween_interval(0.1 + k * 0.03)
		htw.tween_method(_pf(mi, "head"), 0.0, 1.0, 0.35)
	for L in 3:
		var pts2 = _arc(Vector3.UP * (0.2 + L * 0.6), Vector3.RIGHT, Vector3.BACK, 1.0 + L * 0.35, 0.0, TAU * 0.85, 24)
		var mi2 = _mi(_cross(pts2, _taper(pts2.size(), 0.16, 0.05, 4.0), _fill(pts2.size(), gray), Vector3.ZERO), _trail_mat(false), {"tear": 0.3, "ink": 0.25, "head": 0.0})
		root.add_child(mi2)
		parts.append(mi2)
		var htw2 = mi2.create_tween()
		htw2.tween_interval(L * 0.08)
		htw2.tween_method(_pf(mi2, "head"), 0.0, 1.0, 0.2)
	var cw = weakref(c)
	var follow = func(_i, k):
		var cc = cw.get_ref()
		if not is_instance_valid(root):
			return
		if cc != null and is_instance_valid(cc):
			root.global_position = cc.global_position
		root.rotate_y(0.35)
		root.scale = Vector3.ONE * (1.0 + k * 0.4)
	var fin = func():
		for mi in parts:
			if is_instance_valid(mi):
				var ftw = mi.create_tween()
				ftw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.3)
		if is_instance_valid(root):
			var rtw = root.create_tween()
			rtw.tween_interval(0.32)
			rtw.tween_callback(root.queue_free)
	pj.every(dur, 1.0 / 60.0, follow, fin)


# ================================================================== 10. Sōgu: Tensasai
## Parşömen göğe fırlar, hedefin üstünde açılır; açıldığı an aşağı doğru parlak hız çizgileri boşalır. Silahlar beyaz
## düşüş çizgileriyle iner (değdiği yerde kıvılcım); dev topuz ve satırlar gerçek zincirle parşömenden sarkıp çöker:
## yerde yarık, toz halkası, savrulan toprak, kıvılcım ve çelik parıltısı.
static func sogu_tensasai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 1.4)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var tpos = func() -> Vector3: return pj.gp(tt.global_position) if tt and pj.live(tt) else at
	# anime: elde açılan parşömen göğe fırlatılır, düşmanın tam üstünde açık durur; silahlar parlak beyaz çizgilerle düşmana iner
	var sky = at + Vector3(0, 15.0, 0) - pj.fwd(c, t) * 1.5
	var scr = pj._held(c)
	if scr == null:
		scr = pj.scroll_node(0.42, 0.7)
		pj.scene_add(scr, pj.live_hand(c, true))
		pj.scroll_len(scr, 0.5)
	var yaw = atan2(pj.fwd(c, t).x, pj.fwd(c, t).z)
	var goal = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-55), yaw, 0)).scaled(Vector3.ONE * 6.0), sky)   # kâğıt yüzü aşağı, atana dönük
	var l0 = scr.get_node("paper").scale.y * 0.7
	var ftw = scr.create_tween().set_parallel()
	ftw.tween_property(scr, "global_transform", goal, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ftw.tween_method(func(v): pj.scroll_len(scr, v), l0, 0.7, 0.38)
	Sfx.play("whoosh", pj.hand_pos(c, true), 1.3)
	pj.fade_free(scr, 1.9, 0.3)
	pj.after(0.38, func():   # parşömen açıldı: aşağı boşalan hız çizgileri
		_glint(pj, sky, 2.2, 0.3)
		for m in 12:
			var a = m * TAU / 12.0
			var from = sky + Vector3(cos(a), 0, sin(a)) * 1.6
			var to = at + Vector3(cos(a), 0, sin(a)) * 3.5 + Vector3.UP * 3.0
			_line(pj, _seg(from, to, 8), 0.06, 0.16, Color(1, 1, 1, 0.7), 0.12, 0.05, 0.2, {"core": 0.6}))
	for k in 26:
		pj.after(0.42 + k * 0.035, func():
			var from = sky + Vector3(randf_range(-2.0, 2.0), randf_range(-0.5, 0.5), randf_range(-2.0, 2.0))
			var to = tpos.call() + Vector3(randf_range(-0.9, 0.9), 0.1, randf_range(-0.9, 0.9))   # düşmanın tam üstüne
			_line(pj, _seg(from, to, 10), 0.1, 0.03, WHITE, 0.08, 0.05, 0.25, {"core": 1.0})
			var pr = pj.throw_weapon(c, "sogu_tensasai", PathJutsu.WEAPON_KINDS[k % PathJutsu.WEAPON_KINDS.size()], from, to, 60.0, 0.04, tt if tt and pj.live(tt) else null)
			pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
				pj.hit(c, pos, 1.2, pj.inf(c, "sogu_tensasai", 0.04, {"knock": 1.5, "kind": "light"}))
				_sparks(pj, pos, 3, Vector3.UP, 1.0, 5.0)
			if k % 5 == 0:
				Sfx.play("throw_kunai", from, randf_range(0.8, 1.2), 0.6))
	for k in 7:
		pj.after(0.5 + k * 0.1, func():
			var p = tpos.call() + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
			var w = _heavy_weapon(k % 2 == 0)
			pj.scene_add(w, p + Vector3.UP * 14.0)
			w.rotation.y = randf() * TAU
			var src = sky
			var ch = _chain(pj, 150)
			var hang = func(_i, _k):
				if is_instance_valid(w):
					_chain_set(ch, _seg(src, w.global_position + Vector3.UP * (0.5 if k % 2 == 0 else 1.3), 6), 0.13)
			var unhook = func():
				if is_instance_valid(ch):
					ch.queue_free()
			pj.every(0.6, 1.0 / 40.0, hang, unhook)
			var wtw = w.create_tween()
			wtw.tween_property(w, "global_position", p + Vector3.UP * 0.4, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			wtw.tween_callback(func():
				_scar(pj, p, 1.6, 7, 1.8)
				_dust_ring(pj, p, 0.5, 3.5, 8, 0.45, 0.7)
				_chunks(pj, p, 6, 6.0, 0.11, SOIL, 1.0)
				_sparks(pj, p + Vector3.UP * 0.3, 8, Vector3.UP, 1.0, 8.0)
				_glint(pj, p + Vector3.UP * 0.8, 1.0, 0.2)
				pj.hit(c, p + Vector3.UP, 1.6, pj.inf(c, "sogu_tensasai", 0.25, {"knock": 8.0, "kind": "heavy"})))
			wtw.tween_method(_pf(w, "shine"), -2.0, 3.0, 0.3)
			wtw.tween_interval(0.5)
			wtw.tween_property(w, "global_position", p - Vector3.UP * 0.6, 0.25).set_ease(Tween.EASE_IN)
			wtw.tween_callback(w.queue_free))
	Sfx.play("earth", at, 1.0)


## Dev topuz (dikenli demir küre) ya da dev satır; kendi çelik malzememle
static func _heavy_weapon(mace: bool) -> MeshInstance3D:
	var b = MB.new()
	if mace:
		b.add("sphere", Vector3.ZERO, Vector3(0.9, 0.9, 0.9), Color(0.36, 0.36, 0.4), Vector3.ZERO, 12)
		for s in 8:
			var a = s * TAU / 8.0
			var dv = Vector3(cos(a), sin(a * 2.0) * 0.4, sin(a)).normalized()
			b.add_xf("cone", Transform3D(Basis(Quaternion(Vector3.UP, dv)) * Basis.from_scale(Vector3(0.16, 0.4, 0.16)), dv * 0.5), Color(0.5, 0.5, 0.55), 5)
		b.add("cone", Vector3(0, 0.55, 0), Vector3(0.16, 0.35, 0.16), Color(0.5, 0.5, 0.55), Vector3.ZERO, 5)
		b.add("torus", Vector3(0, 0.5, 0), Vector3(0.22, 0.22, 0.22), Color(0.3, 0.3, 0.33), Vector3(90, 0, 0), 10)
	else:
		b.add("box", Vector3(0, 0.9, 0), Vector3(0.12, 2.0, 0.6), Color(0.62, 0.63, 0.68))
		b.add("box", Vector3(0, 0.9, 0.31), Vector3(0.06, 2.0, 0.06), Color(0.95, 0.96, 1.0))
		b.add("box", Vector3(0, -0.15, 0), Vector3(0.3, 0.1, 0.75), Color(0.3, 0.26, 0.2))
		b.add("cyl", Vector3(0, -0.55, 0), Vector3(0.1, 0.7, 0.1), Color(0.16, 0.14, 0.13), Vector3.ZERO, 8)
	return _mi(b.build(), _solid_mat(), {"metal": 1.0})


# ================================================================== 11. Sō Shuriken no Jutsu
## ref: shurikenler gökte ince beyaz tellerle kavis çizer. Üç shuriken elden telle fırlar, kavisle hedefin çevresine varır,
## daralan çemberle dolanırken teli gövdeye sarar (sarım izi); tel çekilince üç tel halka gövdeyi sıkar (parıltı + kıvılcım),
## elden hedefe gergin teller bağ süresince kalır.
static func soshuriken_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.0)
	if tt == null:
		return
	var o = pj.hand_pos(c)
	for k in 3:
		var a = k * TAU / 3.0
		var t0 = 0.15 + k * 0.08
		pj.after(t0, func():
			if not (pj.live(c) and pj.live(tt)):
				return
			_wire_star(pj, c, tt, o, a, 0.6 - t0, 2.5))
	pj.after(0.6, func():
		if pj.live(tt):
			pj.st(tt, "bind", 2.5)
			Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Tellerle bağlandı!", Color(0.85, 0.85, 0.9))
			tt.take_hit(pj.inf(c, "soshuriken_no_jutsu", 0.8, {"knock": 0.0, "kind": "heavy", "bleed": 2.0}))
			_cinch(pj, tt, 2.5))
	Sfx.play("throw_kunai", c.global_position, 1.1)


## Telli shuriken: kavisli uçuş → hedef çevresinde daralan dolanma; elden gelen tel (kavisliyken gevşek, sonra gergin)
static func _wire_star(pj: PathJutsu, c: Node3D, tt: Node3D, o: Vector3, a: float, until: float, hold: float) -> void:
	var sm = MeshInstance3D.new()
	sm.mesh = pj.weapon_mesh("shuriken")
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sm.scale = Vector3.ONE * 1.6
	pj.scene_add(sm, o)
	var fly = 0.16
	var T = maxf(until, fly + 0.05)
	var stt = {"p": o, "taut": 0.0}
	var cw = weakref(c)
	var tw = weakref(tt)
	var move = func(_i, k):
		var x = tw.get_ref()
		if not is_instance_valid(sm) or x == null or not is_instance_valid(x):
			return
		var tm = k * T
		var ctr: Vector3 = x.global_position + Vector3.UP * 1.0
		var p: Vector3
		if tm < fly:
			var q = tm / fly
			var p1 = ctr + Vector3(cos(a), 0, sin(a)) * 1.2
			p = o.lerp(p1, q) + Vector3.UP * sin(q * PI) * 1.6   # ref: gökte kavis
		else:
			var q2 = (tm - fly) / maxf(0.01, T - fly)
			var aa = a + q2 * TAU * 1.25
			var r = lerpf(1.2, 0.45, q2)
			p = ctr + Vector3(cos(aa) * r, lerpf(0.0, -0.3, q2), sin(aa) * r)
		stt["p"] = p
		sm.global_position = p
		sm.rotate_y(0.6)
	var stick = func():
		stt["taut"] = 1.0
		if is_instance_valid(sm):   # telin ucunda saplı kalır, bağ bitince küçülüp kaybolur
			var stw = sm.create_tween()
			stw.tween_interval(hold)
			stw.tween_property(sm, "scale", Vector3.ONE * 0.05, 0.2).set_ease(Tween.EASE_IN)
			stw.tween_callback(sm.queue_free)
	pj.every(T, 1.0 / 60.0, move, stick)
	var wire_pts = func() -> Array:
		var cc = cw.get_ref()
		var hand: Vector3 = pj.hand_pos(cc) if cc != null and is_instance_valid(cc) else o
		var b: Vector3 = stt["p"]
		var out = []
		var lift = hand.distance_to(b) * 0.12 * (1.0 - float(stt["taut"]))
		for m in 13:
			var u = m / 12.0
			out.append(hand.lerp(b, u) + Vector3.UP * sin(u * PI) * lift)
		return out
	_live_curve(pj, wire_pts, T + hold, 0.016, WIRE, {"core": 0.6})
	var pair = func() -> Array:   # sarım izi: dolanırken arkada kalan tel
		var p: Vector3 = stt["p"]
		return [p - Vector3.UP * 0.008, p + Vector3.UP * 0.008]
	_smear(pj, pair, T, 40, WIRE, {"core": 0.5}, false)


## Tel sıkma: gövdeyi üç tel halka sarar, daralarak oturur; düğümde parıltı + kıvılcım; bağ süresince kalır
static func _cinch(pj: PathJutsu, tt: Node3D, hold: float) -> void:
	var ctr: Vector3 = tt.global_position
	var r = float(tt.get("radius")) + 0.08 if tt.get("radius") != null else 0.5
	for m in 3:   # halka merkezinde kurulur: 1.6 kat genişten gövdeye daralır
		var cp = ctr + Vector3.UP * (0.6 + m * 0.38)
		var pts = []
		for j in 25:
			var a = j * TAU / 24.0 + m
			pts.append(cp + Vector3(cos(a) * r, sin(a * 2.0) * 0.03, sin(a) * r))
		var lp = _mi(_cross(pts, _fill(pts.size(), 0.022), _fill(pts.size(), WIRE), cp), _trail_mat(false), {"core": 0.6, "ends": 0.0})
		pj.scene_add(lp, cp)
		lp.scale = Vector3.ONE * 1.6
		lp.create_tween().tween_property(lp, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_IN)
		_sweep(lp, 0.06, hold, 0.4, false)
	var knot = ctr + Vector3.UP * 1.0
	_glint(pj, knot, 1.0, 0.24)
	_sparks(pj, knot, 6, Vector3.UP, 1.0, 5.0, Color(0.9, 0.95, 1.0))


# ================================================================== 12. Sōshōryū
## ref: iki dev parşömen (dış yüz kırmızı, ortada sarı bant; iç yüz beyaz) çift sarmal çizerek göğe açılır, Tenten ortada
## kollarını açıp topaç gibi döner, iki elinden silah yağdırır. Burada: kendi sarmal parşömen şeridim + ucunda dönen rulo,
## yükselişte dikine hız çizgileri, her atışta beyaz atış çizgisi, değdiği yerde kıvılcım + toz; sonunda silahlarla dolu
## zeminde parıltılar, toz halkası ve basınç halkası.
static func soshoryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 34.0)
	var aim0 = pj.gp(Jutsu._aim_ground(c, t, 12.0, 30.0))
	var tpos = func() -> Vector3: return tt.global_position + Vector3.UP * tt.height * 0.4 if tt and pj.live(tt) else aim0
	pj.busy(c, 3.2)
	if c is Player:
		c.combat.invuln = 3.2
	var base = c.global_position
	if Combat.base_time_scale >= 0.99:   # kısa ağır çekim (0.6 hız, 0.5 gerçek sn)
		Combat.base_time_scale = 0.6
		Engine.time_scale = 0.6
		pj.get_tree().create_timer(0.5, true, false, true).timeout.connect(func():
			if absf(Combat.base_time_scale - 0.6) < 0.001:
				Combat.base_time_scale = 1.0)
	Sfx.play("poof", base, 0.8)
	for m in 14:   # yükselişte dikine hız çizgileri
		var a = m * TAU / 14.0 + randf_range(-0.1, 0.1)
		var p0 = base + Vector3(cos(a), 0, sin(a)) * randf_range(3.4, 4.4)
		_line(pj, _seg(p0 + Vector3.UP * randf_range(0.0, 2.0), p0 + Vector3.UP * randf_range(9.0, 14.0), 8), 0.03, 0.07, Color(0.92, 0.96, 1.0, 0.7), 0.3, 0.1, 0.35, {"core": 0.5})
	for k in 2:
		var ph = k * PI
		var band = _mi(_scroll_band(ph), _scroll_mat(), {"reveal": 0.0, "dis": 0.0})
		pj.scene_add(band, base)
		var head = pj.scroll_node(0.5, 0.35)
		pj.scene_add(head, base)
		head.scale = Vector3.ONE * 3.0
		var unroll = func(_i, kk):
			var rv = 1.0 - pow(1.0 - kk, 2.0)   # hızlı açılır, tepede yavaşlar
			if is_instance_valid(band):
				band.set_instance_shader_parameter("reveal", rv)
			if is_instance_valid(head):
				head.global_position = base + _hx(rv, ph)
				head.look_at(base + _hx(minf(1.0, rv + 0.02), ph) + Vector3(0.001, 0, 0), Vector3.UP)
				head.rotate_object_local(Vector3.RIGHT, kk * 40.0)
		var roll_end = func():
			if is_instance_valid(head):
				head.queue_free()
		pj.every(1.0, 1.0 / 40.0, unroll, roll_end)
		_fade_free(band, 2.2, 0.5, "dis", 0.0, 1.0)
	# iki elde kunai
	var held: Array = []
	for bn in ["RightHand", "LeftHand"]:
		var at = pj.bone_attach(c, bn)
		if at:
			var km = MeshInstance3D.new()
			km.mesh = pj.weapon_mesh("kunai")
			km.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			at.add_child(km)
			km.rotation_degrees = Vector3(90, 0, 0)
			km.scale = Vector3.ONE * 1.2
			held.append(at)
	var TOP = 15.0
	var spin = {"a": 0.0}
	# yükseliş (sarmal açılırken ortadan), sonra tepede dönerek atış, sonra serbest düşüş
	var rise = func(_i, kk):
		if not pj.live(c):
			return
		var tsec = kk * 2.6
		var h = TOP * (1.0 - pow(1.0 - clampf(tsec / 0.85, 0.0, 1.0), 3.0)) + sin(tsec * 5.0) * 0.25 * clampf(tsec - 0.85, 0.0, 1.0)
		c.global_position = base + Vector3.UP * h
		if "velocity" in c:
			c.velocity = Vector3.ZERO
		# dönüş: yükselirken hızlanır, tepede sürekli (anime: kollar açık topaç gibi döner)
		spin["a"] += (6.0 + 8.0 * clampf(tsec / 0.85, 0.0, 1.0)) / 60.0
		if "facing" in c:
			c.facing = spin["a"]
		elif c.get("model"):
			c.model.rotation.y = spin["a"]
	var fall = func():
		if pj.live(c) and "velocity" in c:
			c.velocity = Vector3(0, -4.0, 0)
		for at in held:
			if is_instance_valid(at):
				at.queue_free()
	pj.every(2.6, 1.0 / 60.0, rise, fall)
	# atışlar: tepeye varınca, dönüşün her yarım turunda öndeki el fırlatır (sağ/sol sırayla)
	for k in 30:
		pj.after(0.85 + k * 0.055, func():
			if not pj.live(c):
				return
			var right = k % 2 == 0
			var from = pj.live_hand(c, right)
			var to = tpos.call() + Vector3(randf_range(-0.7, 0.7), randf_range(-0.3, 0.3), randf_range(-0.7, 0.7))
			_line(pj, _seg(from, to, 10), 0.08, 0.02, WHITE, 0.07, 0.03, 0.22, {"core": 1.0})
			var pr = pj.throw_weapon(c, "soshoryu", PathJutsu.WEAPON_KINDS[k % PathJutsu.WEAPON_KINDS.size()], from, to, 58.0, 0.1, tt if tt and pj.live(tt) else null)
			pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
				pj.hit(c, pos, 1.2, pj.inf(c, "soshoryu", 0.1, {"knock": 2.0, "kind": "light"}))
				_sparks(pj, pos, 3, Vector3.UP, 1.0, 5.0)
				_puff(pj, pos, Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)), 0.2, 0.6, 0.45)
			if k % 4 == 0:
				Sfx.play("throw_kunai", from, randf_range(0.9, 1.3), 0.7))
	pj.after(2.55, func():
		var g = pj.gp(tpos.call())
		_ring(pj, g + Vector3.UP * 0.1, Vector3.UP, 0.8, 6.0, 0.5, Color(0.95, 0.9, 0.8, 0.7))
		_dust_ring(pj, g, 1.0, 4.0, 12, 0.5, 0.9)
		for m in 7:
			_glint(pj, g + Vector3(randf_range(-2.0, 2.0), 0.2, randf_range(-2.0, 2.0)), 0.6, 0.25)
		pj.shake(0.4))


## Parşömen sarmalı: göğe doğru 2.2 tur, yarıçap hafif açılır
static func _hx(s: float, ph: float) -> Vector3:
	var a = ph + s * TAU * 2.2
	var r = 2.4 + s * 0.6
	return Vector3(cos(a) * r, s * 16.5 - 0.3, sin(a) * r)


## Parşömen şeridi: yüzü dışa bakan bant (dış = ön yüz)
static func _scroll_band(ph: float) -> ArrayMesh:
	var key = "band%d" % int(ph * 100.0)
	if _cache.has(key):
		return _cache[key]
	var n = 110
	var pts = []
	var sides = []
	for i in n:
		var s = float(i) / (n - 1)
		var p = _hx(s, ph)
		var tv = (_hx(minf(1.0, s + 0.005), ph) - _hx(maxf(0.0, s - 0.005), ph)).normalized()
		var rd = Vector3(p.x, 0, p.z).normalized()
		pts.append(p)
		sides.append(rd.cross(tv).normalized())
	var m = _flat(pts, sides, _fill(n, 0.95), _fill(n, Color.WHITE), Vector3.ZERO)
	_cache[key] = m
	return m


# ================================================================== 13. Shiranui: Kuchibari Kaeshi
## Ağızdaki senbonla savuşturma: bekleyişte dudakta senbon parıltısı; gelen her mermiye ağızdan ince bir iğne çizgisi
## uzanır, değdiği yerde çelik çınlaması (kıvılcım + yıldız parıltısı); karşılık iğnesi kendi ince iziyle atana döner.
static func shiranui_kuchibari_kaeshi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 2.0)
	var id = "shiranui_kuchibari_kaeshi"
	pj.anim(c, "guard", 1.0)
	var cw = weakref(c)
	var watch = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		var mouth: Vector3 = cc.global_position + Vector3.UP * 1.55
		if i % 14 == 0:
			_glint(pj, mouth + Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.05, 0.05)), 0.35, 0.16)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if not is_instance_valid(p) or p.get("shooter") == cc or p.has_meta("shira_ref"):
				continue
			if p.global_position.distance_to(mouth) < 3.5:
				var sh = p.get("shooter")
				var pp: Vector3 = p.global_position
				_line(pj, _seg(mouth, pp, 6), 0.03, 0.012, Color(0.9, 0.93, 1.0, 0.9), 0.03, 0.02, 0.1, {"core": 1.0})
				_glint(pj, pp, 0.7, 0.16, Color(1.0, 0.95, 0.8))
				_sparks(pj, pp, 6, pp - mouth, 0.8, 7.0)
				Sfx.play("clink", pp, 1.6)
				p.queue_free()
				if sh != null and is_instance_valid(sh) and sh is Node3D and pj.live(sh):   # karşılık iğnesi
					var dir = ((sh.global_position + Vector3.UP * 1.2) - mouth).normalized()
					_senbon(pj, cc, mouth, dir, pj.inf(cc, id, 0.7, {"knock": 1.0, "kind": "light", "bleed": 1.5, "hitstop": 0.03, "pierce_guard": true}), sh)
	pj.every(2.0, 0.03, watch)


## Senbon atışı (mermi aynı: 60 m/sn, 1 sn ömür, 0.25 yarıçap); kendi ince gümüş izim
static func _senbon(pj: PathJutsu, c: Node3D, from: Vector3, dir: Vector3, info: Dictionary, homing: Node3D) -> Projectile:
	var pr = pj.shot(c, from, dir, 60.0, pj._senbon_node(), info, homing, false, 1.0)
	pr.radius = 0.25
	_line(pj, _seg(from, from + dir * 3.0, 4), 0.012, 0.03, Color(0.9, 0.93, 1.0, 0.7), 0.04, 0.0, 0.12, {"core": 0.8})
	var prw = weakref(pr)
	var pair = func() -> Array:
		var x = prw.get_ref()
		if x == null or not is_instance_valid(x):
			return []
		var p: Vector3 = x.global_position
		return [p - Vector3.UP * 0.01, p + Vector3.UP * 0.01]
	_smear(pj, pair, 0.5, 5, Color(0.92, 0.95, 1.0, 0.7), {"core": 0.8}, false, 1.0 / 40.0)
	return pr


# ================================================================== 14. Daburu Nikudan Sensha
## İki insan topu yan yana yuvarlanır: topların çevresinde dönen kalın hız yayları, arkalarında kesintisiz zemin hendeği
## (kabarık toprak dudaklı), savrulan toprak parçaları, yükselen toz; çarpışmada basınç halkası. Sonunda top açılırken
## toz patlaması ve halka.
static func daburu_nikudan_sensha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var partner: Node3D = null
	var best = 21.0
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if f == c or f.is_dead() or Combat.hostile(c, f) or f is TailedBeast or f.get("team") != c.get("team"):
			continue
		var dd = f.global_position.distance_to(c.global_position)
		if dd < best:
			best = dd
			partner = f
	if partner == null:
		if c is Player:
			Hud.msg("Daburu Nikudan Sensha iki kişilik tekniktir: yakında bir ortak (takım arkadaşı, gölge klon, çağrı) olmalı.", Color(1.0, 0.7, 0.4))
		return
	pj.busy(c, 1.6)
	var tt = pj.tg(c, t, 24.0)
	var goal = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	var users = [c, partner]
	for i in 2:
		var u: Node3D = users[i]
		var ball = pj._aki_ball(u, 1.6)
		pj.get_tree().current_scene.add_child(ball)
		var side = (goal - c.global_position).cross(Vector3.UP).normalized() * (1.0 if i == 0 else -1.0)
		var start = pj.gp(u.global_position) + Vector3.UP * 1.6
		var mid = goal + side * 1.7 + Vector3.UP * 1.6
		ball.global_position = start
		if u.get("model"):
			u.model.visible = false
		var hitd = {}
		var gs = {"last": pj.gp(start)}
		_dust_ring(pj, pj.gp(start), 1.2, 3.5, 8, 0.5, 0.8)
		var roll = func(k, kk):
			if not is_instance_valid(ball):
				return
			var p = start.lerp(mid, minf(1.0, kk * 1.6)) if kk < 0.62 else mid + (goal - c.global_position).normalized() * (kk - 0.62) * 14.0
			ball.global_position = pj.gp(p) + Vector3.UP * 1.6
			ball.rotate_object_local(Vector3.RIGHT, -0.5)
			if is_instance_valid(u):
				u.global_position = pj.gp(ball.global_position)
			var bp: Vector3 = ball.global_position
			if k % 3 == 0:   # top altında hendek
				var g = pj.gp(bp)
				_gouge(pj, gs["last"], g, 1.1, 1.8)
				gs["last"] = g
			if k % 4 == 0:   # dönen hız yayları
				var fwd2 = Vector3(goal.x - start.x, 0, goal.z - start.z).normalized()
				var sd2 = Vector3(-fwd2.z, 0, fwd2.x)
				var a0 = randf() * TAU
				_line(pj, _arc(bp, fwd2, Vector3.UP, 1.9, a0, a0 + 1.8, 12), 0.14, 0.03, Color(0.96, 0.96, 0.94, 0.8), 0.05, 0.0, 0.14, {"ink": 0.4})
				_line(pj, _arc(bp + sd2 * randf_range(-0.5, 0.5), fwd2, Vector3.UP, 2.1, a0 + PI, a0 + PI + 1.4, 10), 0.08, 0.02, Color(0.96, 0.96, 0.94, 0.7), 0.05, 0.0, 0.12, {})
			if k % 6 == 0:
				var g2 = pj.gp(bp)
				_chunks(pj, g2, 4, 6.0, 0.13, SOIL, 0.8)
				_puff(pj, g2 + Vector3.UP * 0.4, Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)), 0.6, 1.8, 0.8)
			for e in pj.enemies_near(c, ball.global_position, 2.2):
				if pj.live(e) and Time.get_ticks_msec() - int(hitd.get(e.get_instance_id(), 0)) > 400:
					hitd[e.get_instance_id()] = Time.get_ticks_msec()
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "daburu_nikudan_sensha", 0.6, {"knock": 6.0, "launch": 2.0, "kind": "heavy", "pierce_guard": true}))
					_ring(pj, e.global_position + Vector3.UP, (e.global_position - bp).normalized(), 0.6, 2.6, 0.25, Color(1, 1, 1, 0.8))
					_chunks(pj, pj.gp(e.global_position), 3, 5.0, 0.1, SOIL, 1.0)
		var unroll = func():
			if is_instance_valid(ball):
				var bp2: Vector3 = ball.global_position
				_dust_ring(pj, pj.gp(bp2), 0.8, 3.5, 10, 0.55, 0.9)
				for m in 4:
					_puff(pj, bp2 + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.6), randf_range(-0.6, 0.6)), Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1)) * 1.5, 0.7, 1.8, 0.8)
				_ring(pj, pj.gp(bp2) + Vector3.UP * 0.1, Vector3.UP, 0.8, 3.2, 0.3, Color(0.95, 0.92, 0.85, 0.6))
				ball.queue_free()
			if is_instance_valid(u) and u.get("model"):
				u.model.visible = true
		pj.every(1.4, 1.0 / 30.0, roll, unroll)
	Sfx.play("whoosh", c.global_position, 0.6)


# ================================================================== 15. Gatsūga / Ōiga Gatenga
## ref: Kiba + Akamaru ikiz kurt dişi — beyaz-mavi, yırtık kenarlı, delip geçen kalın bir girdap; çevresinde mavi chakra
## çıtırtıları. Burada: iç içe ters dönen iki kat sarmal diş (dış beyaz, iç gri-mavi, yırtık kenarlı şeritler), arkasında
## yatay + dikey beyaz yırtık iz, önünde mavi chakra kıvılcımları; geçtiği zeminde geniş hendek, yarık, savrulan toprak.
static func ooiga_gatenga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var tt = pj.tg(c, t, 26.0)
	var d = pj.fwd(c, t)
	var start = c.global_position + Vector3.UP * 2.6
	var goal = (tt.global_position + Vector3.UP * 2.6 + d * 6.0) if tt else start + d * 22.0
	var ball = Node3D.new()
	pj.get_tree().current_scene.add_child(ball)
	ball.global_position = start
	ball.look_at(goal + Vector3(0.001, 0, 0), Vector3.UP)
	var outer = _mi(_drill_mesh(2.6, 5.0, 7, 1.3, 0.3, Color(0.98, 0.99, 1.0, 0.85), Color(0.8, 0.86, 0.95, 0.4)), _trail_mat(false), {"tear": 0.25, "ink": 0.35, "ends": 0.0})
	var inner = _mi(_drill_mesh(1.6, 4.2, 5, -1.0, 0.32, Color(0.62, 0.72, 0.88, 0.9), Color(0.5, 0.6, 0.8, 0.4)), _trail_mat(false), {"tear": 0.2, "ink": 0.4, "ends": 0.0})
	ball.add_child(outer)
	ball.add_child(inner)
	var wolf = c.get_meta("inu_wolf") if c.has_meta("inu_wolf") else null
	if is_instance_valid(wolf):
		wolf.visible = false
	var hitd = {}
	var gs = {"last": pj.gp(start)}
	var dh = Vector3(d.x, 0, d.z).normalized()
	var sdh = Vector3(-dh.z, 0, dh.x)
	var bw = weakref(ball)
	var ow = weakref(outer)
	for j in 4:   # arkada kalan ince sarmal izler: dişin kenarından kopan beyaz-mavi lifler
		var ph = j * TAU / 4.0
		var pair = func() -> Array:
			var b = bw.get_ref()
			var od = ow.get_ref()
			if b == null or od == null:
				return []
			var xf: Transform3D = od.global_transform
			var p: Vector3 = xf * Vector3(cos(ph) * 2.3, sin(ph) * 2.3, 1.8)
			var q: Vector3 = xf * Vector3(cos(ph) * 2.0, sin(ph) * 2.0, 1.8)
			return [p, q]
		_smear(pj, pair, 1.3, 12, Color(0.9, 0.95, 1.0, 0.7), {"tear": 0.3, "rim": 0.6}, false, 1.0 / 30.0)
	var drill = func(k, kk):
		if not is_instance_valid(ball):
			return
		ball.global_position = start.lerp(goal, kk)
		outer.rotate_object_local(Vector3.BACK, 0.8)
		inner.rotate_object_local(Vector3.BACK, -0.55)
		if pj.live(c):
			c.global_position = pj.gp(ball.global_position)
		var bp: Vector3 = ball.global_position
		if k % 2 == 0:
			var g = pj.gp(bp)
			_gouge(pj, gs["last"], g, 1.6, 2.2)
			gs["last"] = g
		if k % 3 == 0:   # önde mavi chakra çıtırtısı
			var front = bp + dh * 2.4
			_sparks(pj, front + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.8, 3, dh + Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)), 0.9, 7.0, Color(0.6, 0.85, 1.0), 0.22)
		if k % 4 == 0:
			var g2 = pj.gp(bp)
			_chunks(pj, g2, 4, 7.0, 0.14, SOIL, 0.9, dh * 2.0)
			_puff(pj, g2 + Vector3.UP * 0.5, Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)) * 1.5, 0.7, 1.9, 0.8)
		if k % 8 == 4:
			_scar(pj, pj.gp(bp), 3.0, 7, 1.8)
		for e in pj.enemies_near(c, ball.global_position, 3.4):
			if pj.live(e) and Time.get_ticks_msec() - int(hitd.get(e.get_instance_id(), 0)) > 250:
				hitd[e.get_instance_id()] = Time.get_ticks_msec()
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.5, pj.inf(c, "ooiga_gatenga", 0.5, {"knock": 12.0, "launch": 5.0, "kind": "heavy", "bleed": 3.0, "pierce_guard": true}))
				var ep: Vector3 = e.global_position + Vector3.UP
				_nick(pj, ep, dh, 0.8, Color(0.85, 0.92, 1.0, 0.85))
				_sparks(pj, ep, 5, dh, 0.8, 8.0, Color(0.6, 0.85, 1.0))
	var fin = func():
		if is_instance_valid(ball):
			var bp2: Vector3 = ball.global_position
			_ring(pj, bp2, dh, 1.0, 4.0, 0.3, Color(0.92, 0.96, 1.0, 0.8))
			_dust_ring(pj, pj.gp(bp2), 1.0, 4.0, 10, 0.55, 0.9)
			ball.queue_free()
		if is_instance_valid(wolf):
			wolf.visible = true
	pj.every(1.3, 1.0 / 30.0, drill, fin)
	pj.shake(0.8)
	Sfx.play("roar", c.global_position, 0.8)


## Sarmal diş: -Z ucu sivri, arkaya doğru açılan iğ biçimli yüzeyde sarmal şeritler; yüzü dışa bakar
static func _drill_mesh(R: float, L: float, strands: int, turns: float, w: float, col: Color, col2: Color) -> ArrayMesh:
	var key = "drill_%d_%d_%d_%d" % [int(R * 100), int(L * 100), strands, int(turns * 100)]
	if _cache.has(key):
		return _cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 25
	for j in strands:
		var pts = []
		var ws = []
		var cs = []
		var sides = []
		for i in n:
			var u = float(i) / (n - 1)
			var z = lerpf(-L * 0.5, L * 0.5, u)
			var r = R * (0.12 + 0.88 * pow(sin(u * PI * 0.62), 0.8))
			var a = j * TAU / strands + u * TAU * turns
			pts.append(Vector3(cos(a) * r, sin(a) * r, z))
			ws.append(w * (0.25 + 0.75 * u) * R * 0.6)
			var cc = col.lerp(col2, u)
			cs.append(Color(cc.r, cc.g, cc.b, cc.a * (1.0 - smoothstep(0.8, 1.0, u))))
		for i in n:
			var tv: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var p: Vector3 = pts[i]
			var rd = Vector3(p.x, p.y, 0).normalized()
			sides.append(rd.cross(tv).normalized())
		_strip_into(st, pts, sides, ws, cs, Vector3.ZERO)
	var m = st.commit()
	_cache[key] = m
	return m
