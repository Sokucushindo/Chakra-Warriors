class_name ShotonLib
extends RefCounted
## Shōton (kristal) doğası kütüphanesi: kendi kristal gölgelendiricisi + yapı taşları. Oyunun ortak efekt yardımcılarını,
## buz kütüphanesini kullanmaz. Görünüş (Guren kaynak görselleri): düzgün altıgen prizmalar, kalın parlak beyaz yüz kenarları,
## yüzün tamamını kaplayan parlak yüz yansıması, içten gelen ışıma, içinde yanıp sönen yıldız parıltıları, alt kısmı daha doygun
## "dolgu" (hapis kristalleri), kristal ayna yüzeyinde kayan ışık şeritleri.
## Palet: 0 pembe (Guren), 1 yeşim (ayna / klon), 2 mavi kristal kılıç, 3 gümüş-beyaz (mızrak, shuriken), 4 kızıl (Kızıl Meyve).
## Yapı taşları: altıgen prizma / jeodezik kabuk / altıgen levha / kar tanesi shuriken / kristal yonga meshleri + germe aracı;
## yıldız parıltısı, kristal tozu, yonga parçacıkları, yerde altıgen kristal halısı (büyüyerek yayılır) ve iç içe halka izleri.
## Kompozisyon (şekil, hareket, sahneleme) her tekniğin kendi dosyasındadır.

static var _cache := {}

const PINK := 0.0
const JADE := 1.0
const BLUE := 2.0
const SILVER := 3.0
const CRIMSON := 4.0

const C_PINK := Color(0.96, 0.62, 0.84)
const C_JADE := Color(0.62, 1.0, 0.55)

const KEYS := {"fade": "fade", "alpha": "alpha_k", "pal": "pal", "near": "near_d", "fill": "fill_h", "glow": "glow",
	"reveal": "reveal_d", "flash": "flash", "sheen": "sheen", "ow": "ow", "grow": "grow", "mode": "mode", "kind": "kind"}

# ------------------------------------------------------------------ gölgelendiriciler
const CRYSTAL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float alpha_k = 0.72;
instance uniform float pal = 0.0;
instance uniform float near_d = 2.5;
instance uniform float seed = 0.0;
instance uniform float fill_h = -1000.0;
instance uniform float glow = 0.0;
instance uniform float reveal_d = 100000.0;
instance uniform float flash = 0.0;
instance uniform float sheen = 0.0;

varying vec3 lp;
varying vec3 bc;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// sRGB: koyu yüz, orta, aydınlık, doygun dolgu, iç ışıma, kenar
void pal_cols(float p, out vec3 dk, out vec3 md, out vec3 lt, out vec3 sat, out vec3 gl, out vec3 ed) {
	dk = vec3(0.8, 0.4, 0.62);
	md = vec3(0.97, 0.7, 0.85);
	lt = vec3(1.0, 0.91, 0.97);
	sat = vec3(0.93, 0.32, 0.62);
	gl = vec3(1.0, 0.72, 0.9);
	ed = vec3(1.0, 0.98, 1.0);
	if (p > 0.5 && p < 1.5) {
		dk = vec3(0.32, 0.66, 0.3);
		md = vec3(0.7, 0.95, 0.6);
		lt = vec3(0.93, 1.0, 0.88);
		sat = vec3(0.42, 0.86, 0.32);
		gl = vec3(0.75, 1.0, 0.6);
		ed = vec3(0.86, 1.0, 0.76);
	} else if (p > 1.5 && p < 2.5) {
		dk = vec3(0.12, 0.24, 0.78);
		md = vec3(0.34, 0.54, 0.98);
		lt = vec3(0.84, 0.92, 1.0);
		sat = vec3(0.18, 0.36, 0.95);
		gl = vec3(0.55, 0.72, 1.0);
		ed = vec3(1.0, 1.0, 1.0);
	} else if (p > 2.5 && p < 3.5) {
		dk = vec3(0.6, 0.63, 0.7);
		md = vec3(0.85, 0.87, 0.92);
		lt = vec3(1.0, 1.0, 1.0);
		sat = vec3(0.74, 0.77, 0.85);
		gl = vec3(0.92, 0.95, 1.0);
		ed = vec3(1.0, 1.0, 1.0);
	} else if (p > 3.5) {
		dk = vec3(0.58, 0.1, 0.24);
		md = vec3(0.9, 0.34, 0.5);
		lt = vec3(1.0, 0.76, 0.82);
		sat = vec3(0.8, 0.14, 0.34);
		gl = vec3(1.0, 0.55, 0.65);
		ed = vec3(1.0, 0.9, 0.92);
	}
}

void vertex() {
	lp = VERTEX;
	bc = CUSTOM0.xyz;
}

void fragment() {
	if (lp.y > reveal_d) {
		discard;
	}
	vec3 dk;
	vec3 md;
	vec3 lt;
	vec3 sat;
	vec3 gl;
	vec3 ed;
	pal_cols(pal, dk, md, lt, sat, gl, ed);
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	vec3 ld = normalize((VIEW_MATRIX * vec4(-0.35, 0.8, 0.45, 0.0)).xyz);
	float ndl = dot(fn, ld);
	float fr = 1.0 - clamp(dot(fn, VIEW), 0.0, 1.0);
	vec3 col = mix(md, lt, step(0.25, ndl));
	col = mix(col, dk, step(ndl, -0.3) * 0.7);
	// yüzün tamamı parlar: düz yüzde yansıma ya hep ya hiç (kristalin kesik yüz parıltısı)
	vec3 rf = reflect(-VIEW, fn);
	float band = step(0.8, dot(rf, ld));
	col = mix(col, vec3(1.0), band * 0.8);
	// alt kısım doygun dolgu (dalgalı yüzey)
	float fl = step(lp.y, fill_h + sin(lp.x * 3.1 + lp.z * 2.3 + seed * 4.0) * 0.07);
	col = mix(col, sat, fl * 0.85);
	// içten ışıma: yüze dik bakılan yerler ışıldar
	col += gl * (1.0 - fr) * (0.12 + glow * 0.6);
	// ayna yüzeyinde kayan çapraz ışık şeritleri
	float sh = step(0.86, fract(dot(lp, vec3(0.7, 0.7, 0.0)) * 0.8 - TIME * 0.35 + seed)) * sheen;
	col = mix(col, vec3(1.0), sh * 0.55);
	// içte yanıp sönen yıldız parıltıları
	vec3 cp = floor(lp * 7.0 + vec3(seed));
	float hh = h31(cp);
	vec3 fp = fract(lp * 7.0 + vec3(seed)) - 0.5;
	float star = step(0.975, hh) * (1.0 - smoothstep(0.0, 0.06, min(abs(fp.x), abs(fp.y)) + length(fp) * 0.18)) * step(0.0, sin(TIME * 5.0 + hh * 60.0));
	col = mix(col, vec3(1.0), star);
	// kalın parlak beyaz yüz kenarları + çevresinde hafif hale
	float e = min(min(bc.x, bc.y), bc.z);
	float ew = fwidth(e);
	float edge = 1.0 - smoothstep(ew * 1.0, ew * 2.6, e);
	float halo = (1.0 - smoothstep(ew * 2.6, ew * 6.0, e)) * 0.35;
	col = mix(col, ed, max(edge, halo));
	col = mix(col, vec3(1.0), flash);
	col *= COLOR.rgb;
	float a = alpha_k + fr * 0.18 + edge * 0.6 + halo * 0.3 + band * 0.25 + fl * 0.2 + star + sh * 0.3 + flash;
	a = clamp(a, 0.0, 1.0) * fade * COLOR.a;
	a *= smoothstep(near_d * 0.35, near_d, -VERTEX.z);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = a;
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_front, unshaded, shadows_disabled, depth_draw_always;

instance uniform float fade = 1.0;
instance uniform float near_d = 2.5;
instance uniform float ow = 0.035;
instance uniform float pal = 0.0;
instance uniform float reveal_d = 100000.0;

varying float ly;

void vertex() {
	ly = VERTEX.y;
	vec3 od = CUSTOM1.xyz;
	if (length(od) < 0.5) {
		od = NORMAL;
	}
	float vz = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += normalize(od) * ow * clamp(vz * 0.06, 0.5, 4.0);
}

void fragment() {
	if (ly > reveal_d) {
		discard;
	}
	vec3 c = vec3(0.42, 0.12, 0.3);
	if (pal > 0.5 && pal < 1.5) {
		c = vec3(0.1, 0.32, 0.1);
	} else if (pal > 1.5 && pal < 2.5) {
		c = vec3(0.04, 0.08, 0.32);
	} else if (pal > 2.5 && pal < 3.5) {
		c = vec3(0.3, 0.32, 0.38);
	} else if (pal > 3.5) {
		c = vec3(0.3, 0.02, 0.08);
	}
	ALBEDO = pow(c, vec3(2.2));
	ALPHA = clamp(fade * smoothstep(near_d * 0.35, near_d, -VERTEX.z) * step(0.001, ow), 0.0, 1.0);
}
"""

## Yerde kristal: mode 0 = merkezden dışa hücre hücre yayılan altıgen kristal halısı, 1 = iç içe tırtıklı halka izleri
const GROUND_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float grow = 1.0;
instance uniform float seed = 0.0;
instance uniform float pal = 0.0;
instance uniform float mode = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hex_d(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float d = length(q);
	vec3 base = vec3(0.97, 0.7, 0.86);
	vec3 deep = vec3(0.86, 0.38, 0.64);
	vec3 ed = vec3(1.0, 0.97, 1.0);
	if (pal > 0.5 && pal < 1.5) {
		base = vec3(0.72, 0.96, 0.62);
		deep = vec3(0.36, 0.72, 0.32);
		ed = vec3(0.9, 1.0, 0.82);
	} else if (pal > 1.5) {
		base = vec3(0.9, 0.92, 0.97);
		deep = vec3(0.66, 0.7, 0.8);
	}
	vec3 col = base;
	float a = 0.0;
	if (mode < 0.5) {
		vec2 uv = q * 6.0;
		vec2 r = vec2(1.0, 1.7320508);
		vec2 hr = r * 0.5;
		vec2 ga = mod(uv, r) - hr;
		vec2 gb = mod(uv - hr, r) - hr;
		vec2 gv = dot(ga, ga) < dot(gb, gb) ? ga : gb;
		vec2 id = uv - gv;
		float hid = h21(id + vec2(seed));
		float cd = length(id) / 6.0;
		float lim = grow * (0.78 + 0.3 * hid);
		if (cd > lim || cd > 1.0) {
			discard;
		}
		float hd = hex_d(gv);
		col = mix(base, deep, step(0.66, hid) * 0.7);
		// her hücre kendi yüz parıltısı: yarısı aydınlık
		col = mix(col, vec3(1.0), step(0.0, gv.x * 0.6 + gv.y) * step(0.5, h21(id + vec2(3.1, seed))) * 0.35);
		float edge = smoothstep(0.4, 0.47, hd);
		col = mix(col, ed, edge);
		float front = smoothstep(lim - 0.12, lim, cd);
		col = mix(col, vec3(1.0), front * 0.6);
		a = (0.62 + edge * 0.35 + front * 0.3) * (1.0 - smoothstep(0.88, 1.0, d));
		float tw = step(0.93, hid) * step(0.7, sin(TIME * 6.0 + hid * 70.0)) * (1.0 - smoothstep(0.0, 0.12, length(gv)));
		col = mix(col, vec3(1.0), tw);
		a = max(a, tw);
	} else {
		float ang = atan(q.y, q.x);
		float jag = h21(vec2(floor(ang * 9.0 + seed * 5.0), seed)) * 0.05;
		float rr = fract(d * 3.2 - grow * 1.6 + jag);
		float ring = (1.0 - smoothstep(0.0, 0.07, abs(rr - 0.5))) * step(d, grow * 1.05);
		float gap = step(0.18, h21(vec2(floor(ang * 5.0 + d * 3.0), seed + 2.0)));
		ring *= gap;
		if (ring < 0.05) {
			discard;
		}
		col = mix(vec3(0.42, 0.42, 0.46), vec3(0.85, 0.85, 0.88), step(0.5, rr));
		a = ring * 0.85 * (1.0 - smoothstep(0.85, 1.0, d));
	}
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0) * fade;
}
"""

## Kristal parıltısı parçacığı: kind 0 dört kollu yıldız (yanıp söner), 1 kristal tozu (köşeli pırıltı)
const SPARK_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float fade = 1.0;
instance uniform float near_d = 1.5;

varying float tw;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	tw = h31(floor(MODEL_MATRIX[3].xyz * 13.0));
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	vec3 col = COLOR.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		float ax = (1.0 - smoothstep(0.0, 0.07, abs(q.y))) * (1.0 - smoothstep(0.0, 1.0, abs(q.x)));
		float ay = (1.0 - smoothstep(0.0, 0.07, abs(q.x))) * (1.0 - smoothstep(0.0, 1.0, abs(q.y)));
		float core = 1.0 - smoothstep(0.08, 0.25, length(q));
		a = max(max(ax, ay), core);
		col = mix(col, vec3(1.0), max(core, 0.4));
		a *= 0.55 + 0.45 * sin(TIME * 11.0 + tw * 40.0);
	} else {
		vec2 p = abs(q);
		float dia = p.x * 0.8 + p.y;
		a = 1.0 - smoothstep(0.62, 0.72, dia);
		col = mix(col, vec3(1.0), step(q.x + q.y, -0.1) * 0.5);
	}
	a *= COLOR.a * fade * smoothstep(near_d * 0.3, near_d, -VERTEX.z);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


# ------------------------------------------------------------------ malzemeler
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func crystal_mat(outline := false, two := false) -> ShaderMaterial:
	var key = "cry_%d_%d" % [int(outline), int(two)]
	if _cache.has(key):
		return _cache[key]
	var code = CRYSTAL_SHADER if not two else CRYSTAL_SHADER.replace("cull_back", "cull_disabled")
	var m = _mat(key + "_base", code).duplicate() as ShaderMaterial
	if outline:
		m.next_pass = _mat("cry_outline", OUTLINE_SHADER)
	_cache[key] = m
	return m


static func ground_mat() -> ShaderMaterial:
	return _mat("cry_ground", GROUND_SHADER)


static func spark_mat() -> ShaderMaterial:
	return _mat("cry_spark", SPARK_SHADER)


static func setp(gi: GeometryInstance3D, o: Dictionary) -> void:
	for k in o:
		if KEYS.has(k):
			gi.set_instance_shader_parameter(KEYS[k], float(o[k]))


## Kristal malzemeli mesh örneği. o: pal, alpha, fade, near, fill, glow, reveal, flash, sheen, ow, outline, two
static func cmi(mesh: Mesh, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = crystal_mat(bool(o.get("outline", false)), bool(o.get("two", false)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	if not o.has("ow"):
		mi.set_instance_shader_parameter("ow", 0.035 if bool(o.get("outline", false)) else 0.0)
	setp(mi, o)
	return mi


# ------------------------------------------------------------------ sahne yardımcıları
static func put(h: Node, n: Node3D, pos: Vector3) -> Node3D:
	h.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z), p.z)


static func later(h: Node, t: float, fn: Callable) -> void:
	h.get_tree().create_timer(t).timeout.connect(fn)


static func free_later(h: Node, n: Node, t: float) -> void:
	var w = weakref(n)
	h.get_tree().create_timer(t).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func fade_free(gi: GeometryInstance3D, delay: float, t: float) -> void:
	var tw = gi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): gi.set_instance_shader_parameter("fade", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)


## Kristal yerel Y boyunca büyür (gerilmeden): görünen boy 0 → h
static func grow_up(gi: GeometryInstance3D, h: float, t: float, delay := 0.0) -> void:
	gi.set_instance_shader_parameter("reveal_d", -0.01)
	var tw = gi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): gi.set_instance_shader_parameter("reveal_d", v), -0.01, h, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)


## Oluşum anı: beyaz parlayıp normale döner
static func flash_in(gi: GeometryInstance3D, t := 0.25) -> void:
	gi.set_instance_shader_parameter("flash", 1.0)
	gi.create_tween().tween_method(func(v: float): gi.set_instance_shader_parameter("flash", v), 1.0, 0.0, t)


# ------------------------------------------------------------------ yüzlü mesh kurucu (kristal)
static func begin() -> SurfaceTool:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	return st


static func finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


## Düz yüzlü üçgen: ctr içerisi; hm gizli kenar maskesi (barisentrik +1)
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ctr: Vector3, hm := Vector3.ZERO) -> void:
	var cr = (b - a).cross(c - a)
	if cr.length() < 0.000001:
		return
	if cr.dot((a + b + c) / 3.0 - ctr) > 0.0:
		var t = b
		b = c
		c = t
		hm = Vector3(hm.x, hm.z, hm.y)
		cr = -cr
	var nrm = -cr.normalized()
	var vs = [a, b, c]
	var bs = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	for i in 3:
		var b3: Vector3 = bs[i] + hm
		var v: Vector3 = vs[i]
		var od = v - ctr
		od = od.normalized() if od.length() > 0.0001 else nrm
		st.set_normal(nrm)
		st.set_custom(0, Color(b3.x, b3.y, b3.z, 1.0))
		st.set_custom(1, Color(od.x, od.y, od.z, 1.0))
		st.add_vertex(v)


## Dörtgen: diag=false köşegen gizli (düz kristal yüzü), true görünür (jeodezik üçgen ağı)
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ctr: Vector3, diag := false) -> void:
	if c.distance_to(d) < 0.0001:
		tri(st, a, b, c, ctr)
		return
	if a.distance_to(b) < 0.0001:
		tri(st, a, c, d, ctr)
		return
	tri(st, a, b, c, ctr, Vector3.ZERO if diag else Vector3(0, 1, 0))
	tri(st, a, c, d, ctr, Vector3.ZERO if diag else Vector3(0, 0, 1))


## Halkalar boyunca yüzlü gövde. rings: [{"p", "rx", "ry", "rot", "up"}]
static func loft(st: SurfaceTool, rings: Array, sides: int, jit := 0.0, sd := 0, cap0 := true, cap1 := true, diag := false) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var n = rings.size()
	if n < 2:
		return
	var pts: Array = []
	var fs: Array = []
	for i in n:
		var r: Dictionary = rings[i]
		var p: Vector3 = r["p"]
		var pa: Vector3 = rings[maxi(i - 1, 0)]["p"]
		var pb: Vector3 = rings[mini(i + 1, n - 1)]["p"]
		var f = pb - pa
		f = f.normalized() if f.length() > 0.0001 else Vector3.FORWARD
		fs.append(f)
		var upr: Vector3 = r.get("up", Vector3.UP)
		if absf(f.dot(upr.normalized())) > 0.97:
			upr = Vector3.FORWARD if absf(f.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var sv = f.cross(upr).normalized()
		var u = sv.cross(f).normalized()
		var rx: float = float(r.get("rx", 0.0))
		var ry: float = float(r.get("ry", rx))
		var rot: float = float(r.get("rot", 0.0))
		var ring: Array = []
		for k in sides:
			var an = k * TAU / sides + rot
			var j = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * jit * maxf(rx, ry)
			ring.append(p + sv * cos(an) * rx + u * sin(an) * ry + j)
		pts.append(ring)
	for i in n - 1:
		var c0: Vector3 = (rings[i]["p"] + rings[i + 1]["p"]) * 0.5
		for k in sides:
			var k1 = (k + 1) % sides
			quad(st, pts[i][k], pts[i][k1], pts[i + 1][k1], pts[i + 1][k], c0, diag)
	if cap0 and float(rings[0].get("rx", 0.0)) > 0.0001:
		var p0: Vector3 = rings[0]["p"]
		for k in sides:
			tri(st, p0, pts[0][k], pts[0][(k + 1) % sides], p0 + fs[0] * 0.2, Vector3(0, 1, 1))
	if cap1 and float(rings[n - 1].get("rx", 0.0)) > 0.0001:
		var p1: Vector3 = rings[n - 1]["p"]
		for k in sides:
			tri(st, p1, pts[n - 1][k], pts[n - 1][(k + 1) % sides], p1 - fs[n - 1] * 0.2, Vector3(0, 1, 1))


# ------------------------------------------------------------------ hazır şekiller
## Altıgen kristal prizma: tabanı y=0, gövde boyu L, yarıçap r, piramit uç boyu tip (gerçek boyda kur)
static func prism_mesh(L: float, r: float, tip: float, variant := 0, sides := 6) -> ArrayMesh:
	var key = "prism_%.2f_%.2f_%.2f_%d_%d" % [L, r, tip, variant, sides]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 2207 + variant * 41
	var rot = rng.randf() * TAU
	var off = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)) * r
	var st = begin()
	loft(st, [
		{"p": Vector3(0, -0.05, 0), "rx": r, "ry": r, "rot": rot},
		{"p": Vector3(0, L - tip, 0), "rx": r * rng.randf_range(0.94, 1.0), "ry": r * rng.randf_range(0.94, 1.0), "rot": rot},
		{"p": Vector3(0, L, 0) + off, "rx": 0.0}], sides, 0.0, 1, true, false)
	var m = finish(st)
	_cache[key] = m
	return m


## İki uçlu kristal yonga (küçük kırıntı, savrulan parça)
static func gem_mesh(s: float, variant := 0) -> ArrayMesh:
	var key = "gem_%.2f_%d" % [s, variant]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 6100 + variant * 7
	var rot = rng.randf() * TAU
	var st = begin()
	loft(st, [
		{"p": Vector3(0, -s, 0), "rx": 0.0},
		{"p": Vector3(0, -s * 0.35, 0), "rx": s * 0.55, "rot": rot},
		{"p": Vector3(0, s * 0.35, 0), "rx": s * 0.55, "rot": rot},
		{"p": Vector3(0, s, 0), "rx": 0.0}], 6, 0.0, 1)
	var m = finish(st)
	_cache[key] = m
	return m


## Jeodezik kristal kabuk (Kızıl Meyve hapsi gibi): yarıçap r, boy h, tabanı y=0; tüm üçgen kenarları görünür
static func shell_mesh(r: float, h: float, sides := 8) -> ArrayMesh:
	var key = "shell_%.2f_%.2f_%d" % [r, h, sides]
	if _cache.has(key):
		return _cache[key]
	var half = PI / sides
	var st = begin()
	loft(st, [
		{"p": Vector3(0, 0.0, 0), "rx": r * 0.72, "rot": 0.0},
		{"p": Vector3(0, h * 0.3, 0), "rx": r, "rot": half},
		{"p": Vector3(0, h * 0.66, 0), "rx": r * 0.97, "rot": 0.0},
		{"p": Vector3(0, h * 0.92, 0), "rx": r * 0.66, "rot": half},
		{"p": Vector3(0, h, 0), "rx": r * 0.2, "rot": 0.0}], sides, 0.0, 1, true, true, true)
	var m = finish(st)
	_cache[key] = m
	return m


## Altıgen levha (ayna camı): XY düzleminde yarıçap r, Z kalınlığı t
static func hexplate_mesh(r: float, t: float) -> ArrayMesh:
	var key = "hexplate_%.2f_%.2f" % [r, t]
	if _cache.has(key):
		return _cache[key]
	var st = begin()
	loft(st, [{"p": Vector3(0, 0, t * 0.5), "rx": r, "rot": PI / 6.0, "up": Vector3.UP},
		{"p": Vector3(0, 0, -t * 0.5), "rx": r, "rot": PI / 6.0, "up": Vector3.UP}], 6, 0.0, 1, true, true)
	var m = finish(st)
	_cache[key] = m
	return m


## Kar tanesi kristal shuriken: XZ düzleminde ince disk, altı kol + yan dişler (kenar çizgileri deseni çizer)
static func shuriken_mesh(r: float) -> ArrayMesh:
	var key = "shuri_%.2f" % r
	if _cache.has(key):
		return _cache[key]
	var st = begin()
	var t = r * 0.035
	var ctr = Vector3.ZERO
	for k in 6:
		var a = k * TAU / 6.0
		var dv = Vector3(cos(a), 0, sin(a))
		var sv = Vector3(-sin(a), 0, cos(a))
		# kol: sivri baklava (üst ve alt yüz)
		var tip = dv * r
		var root = dv * r * 0.12
		var w = r * 0.13
		var m0 = dv * r * 0.45 + sv * w
		var m1 = dv * r * 0.45 - sv * w
		for sy in [1.0, -1.0]:
			var up = Vector3.UP * t * sy
			tri(st, root + up, m0 + up * 0.5, tip, ctr + Vector3.DOWN * sy * 0.05)
			tri(st, root + up, tip, m1 + up * 0.5, ctr + Vector3.DOWN * sy * 0.05)
		# yan dişler
		for sd in [-1.0, 1.0]:
			var b0 = dv * r * 0.55
			var bt = b0 + (dv * 0.5 + sv * sd).normalized() * r * 0.28
			for sy in [1.0, -1.0]:
				var up = Vector3.UP * t * 0.6 * sy
				tri(st, b0 - dv * r * 0.06 + up, b0 + dv * r * 0.06 + up, bt, ctr + Vector3.DOWN * sy * 0.05)
	# ortadaki altıgen göbek + çevreleyen ince disk halkası
	for k in 6:
		var a0 = k * TAU / 6.0 + PI / 6.0
		var a1 = (k + 1) * TAU / 6.0 + PI / 6.0
		var p0 = Vector3(cos(a0), 0, sin(a0)) * r * 0.22
		var p1 = Vector3(cos(a1), 0, sin(a1)) * r * 0.22
		for sy in [1.0, -1.0]:
			tri(st, Vector3.UP * t * 1.6 * sy, p0 + Vector3.UP * t * sy, p1 + Vector3.UP * t * sy, Vector3.DOWN * sy * 0.05, Vector3(0, 1, 1))
	var m = finish(st)
	_cache[key] = m
	return m


static func quad_mesh() -> QuadMesh:
	if _cache.has("quad"):
		return _cache["quad"]
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	_cache["quad"] = q
	return q


# ------------------------------------------------------------------ parçacıklar
static func _curve(key: String, pts: Array) -> CurveTexture:
	if _cache.has(key):
		return _cache[key]
	var cv = Curve.new()
	for p in pts:
		cv.add_point(p)
	var ct = CurveTexture.new()
	ct.curve = cv
	_cache[key] = ct
	return ct


static func _ramp(cols: Array) -> GradientTexture1D:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	var t = GradientTexture1D.new()
	t.gradient = g
	return t


## o: n, life, dir, spread, vmin, vmax, g, damp, smin, smax, r, box, align, mesh, mat, one_shot, burst, local, cols, kind
static func particles(o: Dictionary) -> GPUParticles3D:
	var p = GPUParticles3D.new()
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 180.0))
	pm.initial_velocity_min = float(o.get("vmin", 1.0))
	pm.initial_velocity_max = float(o.get("vmax", 3.0))
	pm.gravity = o.get("g", Vector3(0, -2.0, 0))
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0))
	pm.scale_min = float(o.get("smin", 0.12))
	pm.scale_max = float(o.get("smax", 0.3))
	pm.scale_curve = _curve("twk", [Vector2(0.0, 0.0), Vector2(0.15, 1.0), Vector2(0.6, 0.7), Vector2(1.0, 0.0)])
	if o.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = o["box"]
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(o.get("r", 0.3))
	pm.particle_flag_align_y = bool(o.get("align", false))
	pm.color_ramp = _ramp(o.get("cols", [Color(1, 1, 1, 1), Color(1.0, 0.85, 0.95, 1.0), Color(1.0, 0.7, 0.9, 0.0)]))
	p.process_material = pm
	p.draw_pass_1 = o.get("mesh", quad_mesh())
	p.material_override = o.get("mat", spark_mat())
	p.amount = maxi(1, int(o.get("n", 16)))
	p.lifetime = float(o.get("life", 0.8))
	p.one_shot = bool(o.get("one_shot", true))
	p.explosiveness = float(o.get("burst", 0.9))
	p.randomness = 0.5
	p.local_coords = bool(o.get("local", false))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-16, -16, -16), Vector3(32, 32, 32))
	p.set_instance_shader_parameter("kind", float(o.get("kind", 0.0)))
	p.set_instance_shader_parameter("seed", randf() * 10.0)
	setp(p, o)
	return p


static func _emit(h: Node, p: GPUParticles3D, pos: Vector3) -> GPUParticles3D:
	put(h, p, pos)
	p.emitting = true
	if p.one_shot:
		free_later(h, p, p.lifetime + 0.4)
	return p


static func _tint(pal: float) -> Color:
	if pal > 0.5 and pal < 1.5:
		return Color(0.7, 1.0, 0.6)
	if pal > 1.5 and pal < 2.5:
		return Color(0.6, 0.75, 1.0)
	if pal > 2.5 and pal < 3.5:
		return Color(0.9, 0.93, 1.0)
	if pal > 3.5:
		return Color(1.0, 0.5, 0.6)
	return Color(1.0, 0.72, 0.9)


## Dört kollu yanıp sönen yıldız parıltıları
static func sparkles(h: Node, pos: Vector3, o := {}) -> GPUParticles3D:
	var tc = _tint(float(o.get("pal", PINK)))
	var d = {"n": 16, "life": 0.9, "spread": 180.0, "vmin": 0.3, "vmax": 1.6, "g": Vector3.ZERO, "damp": 1.0, "smin": 0.2, "smax": 0.45,
		"r": 0.8, "kind": 0.0, "cols": [Color(1, 1, 1, 1), tc, Color(tc.r, tc.g, tc.b, 0.0)]}
	d.merge(o, true)
	return _emit(h, particles(d), pos)


## Kristal tozu: köşeli küçük pırıltılar (savrulan bulut)
static func dust(h: Node, pos: Vector3, o := {}) -> GPUParticles3D:
	var tc = _tint(float(o.get("pal", PINK)))
	var d = {"n": 30, "life": 1.0, "spread": 50.0, "vmin": 2.0, "vmax": 6.0, "g": Vector3(0, -0.5, 0), "damp": 2.0, "smin": 0.08, "smax": 0.2,
		"r": 0.5, "kind": 1.0, "cols": [Color(1, 1, 1, 1), tc, Color(tc.r, tc.g, tc.b, 0.0)]}
	d.merge(o, true)
	return _emit(h, particles(d), pos)


## Kristal yongaları: hıza hizalı küçük altıgen kristaller
static func chips(h: Node, pos: Vector3, o := {}) -> GPUParticles3D:
	var d = {"n": 16, "life": 0.7, "spread": 180.0, "vmin": 3.0, "vmax": 8.0, "g": Vector3(0, -12.0, 0), "smin": 0.7, "smax": 1.3,
		"r": 0.3, "align": true, "mesh": gem_mesh(0.14, 2), "mat": crystal_mat(), "cols": [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.0)],
		"alpha": 0.85, "near": 1.2}
	d.merge(o, true)
	return _emit(h, particles(d), pos)


static func trail(parent: Node3D, o := {}) -> GPUParticles3D:
	var tc = _tint(float(o.get("pal", PINK)))
	var d = {"n": 24, "life": 0.5, "spread": 30.0, "dir": Vector3(0, 0, 1), "vmin": 0.2, "vmax": 0.8, "g": Vector3.ZERO, "smin": 0.12, "smax": 0.28,
		"r": 0.15, "one_shot": false, "burst": 0.0, "kind": 0.0, "cols": [Color(1, 1, 1, 1), tc, Color(tc.r, tc.g, tc.b, 0.0)]}
	d.merge(o, true)
	var p = particles(d)
	parent.add_child(p)
	p.emitting = true
	return p


## Yerde kristal: mode 0 altıgen hücre halısı, 1 iç içe halka izi. life sonra söner
static func carpet(h: Node, pos: Vector3, r: float, life: float, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0)
	mi.mesh = pm
	mi.material_override = ground_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("mode", float(o.get("mode", 0.0)))
	mi.set_instance_shader_parameter("pal", float(o.get("pal", PINK)))
	mi.set_instance_shader_parameter("grow", 0.0)
	put(h, mi, ground(pos) + Vector3.UP * float(o.get("lift", 0.05)))
	mi.rotation.y = randf() * TAU
	var tw = mi.create_tween()
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("grow", v), 0.0, float(o.get("to", 1.0)), float(o.get("t", 0.4))).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(maxf(0.0, life))
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, float(o.get("out", 0.6)))
	tw.tween_callback(mi.queue_free)
	return mi


## Kristal kırılması: n parça döne döne savrulur, yere düşüp parlayarak söner + yıldız parıltısı
static func shatter(h: Node, pos: Vector3, o := {}) -> void:
	var n = int(o.get("n", 10))
	var s = float(o.get("s", 0.25))
	var spd = float(o.get("v", 5.0))
	var pal = float(o.get("pal", PINK))
	var life = float(o.get("life", 1.0))
	var flo = Game.jutsu_floor(pos.x, pos.z)
	for i in n:
		var mi = cmi(gem_mesh(s * randf_range(0.6, 1.4), i % 4), {"pal": pal, "alpha": 0.85, "near": 1.5})
		put(h, mi, pos + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * float(o.get("r", 0.5)))
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var v = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * spd * randf_range(0.4, 1.0) + Vector3.UP * float(o.get("up", 4.0)) * randf_range(0.5, 1.2)
		var p0 = mi.global_position
		var spin = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		var r0 = mi.rotation
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if not is_instance_valid(mi):
				return
			var p = p0 + v * t + Vector3.DOWN * 8.0 * t * t
			if p.y < flo + 0.06:
				p.y = flo + 0.06
			mi.global_position = p
			mi.rotation = r0 + spin * minf(t, 0.5), 0.0, life, life)
		tw.parallel().tween_method(func(f: float): mi.set_instance_shader_parameter("fade", f), 1.0, 0.0, life * 0.3).set_delay(life * 0.7)
		tw.tween_callback(mi.queue_free)
	sparkles(h, pos, {"n": int(n * 1.5), "r": float(o.get("r", 0.5)) + 0.4, "pal": pal})
