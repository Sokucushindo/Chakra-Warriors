class_name HidenFXA
extends RefCounted
## Hiden grubu A: örümcek ağı (Kidōmaru / Kumo), Nenkin altını, Jiongu iplikleri, Jashin ayini, pul tozu, taş iğne, lastik beden.
## Her şey bu dosyada sıfırdan üretilir: kendi gölgelendiricileri (ipek: kalınlık + parlama + sarkma + yapışkan boncuk;
## altın: ıslak/akışkan → sertleşmiş, çatlak ve leke; Jiongu lifi: çizgili kara iplik demeti; toon; ayin çemberi; parçacık; chakra şeridi),
## kendi mesh kurucuları (gerçek ağ geometrisi: ışınsal + sarmal, düzensiz hücre ağı, çiçek ağı, örümcek modeli, yay, ok, iğne).
## Kamera yakınında tüm katmanlar seyrelerek söner (ekranı kaplamaz). Oynanış ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}

const SILK_C := Color(0.96, 0.96, 0.92)
const BLOOD_C := Color(0.6, 0.03, 0.04)
const SKIN_C := Color(0.95, 0.78, 0.64)
const WHITE_V := Color(1, 1, 1)
const BOW_A := 1.05

const PARAMS := ["fade", "near_d", "reveal", "reveal_y", "sag", "wamp", "wfreq", "wob", "seed", "ow", "wet", "pulse", "braid", "tint", "olc"]
const DEF := {
	"silk": {"tint": Color(0.96, 0.96, 0.92), "olc": Color(0.3, 0.32, 0.4), "ow": 0.008, "near_d": 1.2},
	"gold": {"tint": Color(1, 1, 1), "olc": Color(0.3, 0.16, 0.04), "ow": 0.012, "near_d": 1.2},
	"fiber": {"tint": Color(1, 1, 1), "olc": Color(0.02, 0.02, 0.03), "ow": 0.12, "near_d": 1.5},
	"toon": {"tint": Color(1, 1, 1), "olc": Color(0.08, 0.07, 0.08), "ow": 0.01, "near_d": 1.0},
}

# ================================================================== gölgelendiriciler
## Ortak baş: örnek parametreleri (ana geçiş ve kontur aynı sırayla bildirir), sarkma / dalga / kıpırtı köşe deformasyonu
const HEAD := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float near_d = 1.2;
instance uniform float reveal = 2.0;
instance uniform float reveal_y = 1000.0;
instance uniform float sag = 0.0;
instance uniform float wamp = 0.0;
instance uniform float wfreq = 1.0;
instance uniform float wob = 0.0;
instance uniform float seed = 0.0;
instance uniform float ow = 0.0;
instance uniform float wet = 0.0;
instance uniform float pulse = 0.0;
instance uniform float braid = 0.0;
instance uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 olc = vec4(0.1, 0.1, 0.1, 1.0);

varying vec3 lp;
varying vec3 vn;
varying float along;

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

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void vertex() {
	lp = VERTEX;
	along = UV.y;
	float t = UV.y;
	VERTEX.y -= sag * 4.0 * t * (1.0 - t);
	VERTEX.x += sin(t * wfreq * 6.2832 + TIME * 6.0 + seed) * wamp * t;
	VERTEX.y += cos(t * wfreq * 4.5 + TIME * 5.0 + seed * 1.7) * wamp * 0.7 * t;
	VERTEX += NORMAL * (vn3(lp * 5.0 + vec3(TIME * 1.5)) - 0.5) * wob;
//GROW
	vn = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
"""

const GROW_LINE := "	VERTEX += NORMAL * ow * clamp(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z * 0.07, 0.7, 3.0);"

## Parça başı: büyüme kesimi, kamera yakını + sönme titreşimli seyreltme (saydamlık sıralaması yok), toon ışık yönü
const PRE := """
	if (along > reveal || lp.y > reveal_y) {
		discard;
	}
	float nfade = fade * smoothstep(near_d * 0.4, near_d, -VERTEX.z);
	if (nfade < 0.999 && nfade < ign(FRAGCOORD.xy)) {
		discard;
	}
	vec3 n = normalize(vn);
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	vec3 ld = normalize((VIEW_MATRIX * vec4(-0.35, 0.8, 0.45, 0.0)).xyz);
	float ndl = dot(n, ld);
	float fr = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	vec3 hv = normalize(ld + VIEW);
	float nh = dot(n, hv);
"""

## İpek: kirli beyaz, mavimsi gölge, koyu kenar, kayan parlama bandı, yapışkan boncuk parıltısı, örgü çizgisi
const SILK_F := """
	vec3 base = tint.rgb;
	vec3 col = mix(base * vec3(0.64, 0.66, 0.75), base, smoothstep(-0.08, 0.08, ndl));
	col = mix(col, base * vec3(0.48, 0.5, 0.6), smoothstep(0.7, 0.85, fr) * 0.55);
	float spec = smoothstep(0.86, 0.92, nh);
	float band = smoothstep(0.82, 1.0, sin(along * 14.0 - TIME * 2.5 + seed * 5.0)) * 0.45;
	float bq = fract(along * 34.0 + seed);
	float bead = step(0.82, h31(vec3(floor(along * 34.0 + seed), seed, 1.0))) * (1.0 - smoothstep(0.12, 0.3, abs(bq - 0.5))) * wet;
	float br = step(0.5, fract(UV.x * 3.0 + along * braid)) * step(0.01, braid);
	col *= 1.0 - br * 0.24;
	col = mix(col, vec3(1.0), clamp(spec * 0.7 + band * 0.4 + bead * 0.9, 0.0, 1.0));
	col = mix(col, vec3(1.0), pulse);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
}
"""

## Nenkin altını: ıslakken turuncu-parlak ve kıpır kıpır, sertleşince donuk koyu sarı + kahve çatlak çizgileri + lekeler (ref)
const GOLD_F := """
	float n1 = vn3(lp * vec3(7.0, 2.6, 7.0) + vec3(seed));
	float n2 = vn3(lp * 11.0 + vec3(seed * 2.0, 0.0, 0.0));
	float crack = (1.0 - smoothstep(0.0, 0.035, abs(n1 - 0.5))) * step(0.45, n2) * (1.0 - wet);
	float blot = step(0.74, vn3(lp * 4.5 + vec3(0.0, seed * 3.0, 0.0))) * 0.55;
	vec3 lt = mix(vec3(0.95, 0.76, 0.38), vec3(1.0, 0.7, 0.18), wet);
	vec3 md = mix(vec3(0.8, 0.56, 0.22), vec3(0.95, 0.5, 0.08), wet);
	vec3 dk = mix(vec3(0.52, 0.32, 0.12), vec3(0.66, 0.27, 0.04), wet);
	vec3 col = mix(md, lt, smoothstep(0.12, 0.22, ndl));
	col = mix(col, dk, 1.0 - smoothstep(-0.38, -0.28, ndl));
	col = mix(col, dk, blot * (1.0 - wet));
	col = mix(col, vec3(0.3, 0.16, 0.05), crack * 0.9);
	float spec = smoothstep(mix(0.94, 0.8, wet), mix(0.97, 0.86, wet), nh) * mix(0.35, 0.9, wet);
	col = mix(col, vec3(1.0, 0.97, 0.85), spec);
	col *= tint.rgb;
	col = mix(col, vec3(1.0, 0.95, 0.75), pulse);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
}
"""

## Jiongu lifi: kara-gri iplik demeti, boyunca uzanan açık gri lif çizgileri, koyu kenar
const FIBER_F := """
	float s1 = fract(UV.x * 8.0 + sin(along * 26.0 + seed) * 0.08 + along * 2.0);
	float line = smoothstep(0.36, 0.46, abs(s1 - 0.5));
	vec3 base = vec3(0.22, 0.22, 0.25) * tint.rgb;
	vec3 col = mix(base * 0.62, base * 1.2, smoothstep(-0.1, 0.1, ndl));
	col = mix(col, vec3(0.52, 0.52, 0.58), line * 0.75);
	col = mix(col, vec3(0.04, 0.04, 0.05), smoothstep(0.75, 0.9, fr) * 0.6);
	col = mix(col, vec3(0.8, 0.12, 0.1), pulse);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
}
"""

## Toon (köşe rengiyle): örümcek, taş iğne, deri halkası, çatlak, kaya
const TOON_F := """
	vec3 base = COLOR.rgb * tint.rgb;
	vec3 col = mix(base * vec3(0.6, 0.6, 0.68), base, smoothstep(-0.06, 0.06, ndl));
	float spec = smoothstep(0.9, 0.94, nh) * (0.2 + wet * 0.6);
	col = mix(col, vec3(1.0), spec);
	col = mix(col, vec3(1.0), pulse);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
}
"""

## Ters kabuk konturu: yalnız arkaya bakan kabuk parçaları çizilir (sarım yönünden bağımsız)
const OUT_F := """
void fragment() {
	if (ow <= 0.0 || along > reveal || lp.y > reveal_y) {
		discard;
	}
	float nfade = fade * smoothstep(near_d * 0.4, near_d, -VERTEX.z);
	if (nfade < 0.999 && nfade < ign(FRAGCOORD.xy)) {
		discard;
	}
	if (dot(normalize(vn), VIEW) > 0.0) {
		discard;
	}
	ALBEDO = pow(olc.rgb, vec3(2.2));
}
"""

## Jashin ayin çemberi: yere kanla çizilen daire + içinde üçgen; çizim ilerlemesi, ıslak parıltı, nabız dalgası
const RITUAL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float draw = 0.0;
instance uniform float pulse = 0.0;
instance uniform float seed = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float seg_d(vec2 p, vec2 a, vec2 b, out float s) {
	vec2 ab = b - a;
	s = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - a - ab * s);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x) / 6.2832 + 0.5;
	float wob = (vn2(p * 9.0 + vec2(seed)) - 0.5) * 0.025;
	float ring_prog = clamp(draw / 0.55, 0.0, 1.0);
	float ring_d = abs(r - 0.9 + wob);
	float ring = (1.0 - smoothstep(0.03, 0.045, ring_d)) * step(ang, ring_prog);
	float tri_prog = clamp((draw - 0.55) / 0.45, 0.0, 1.0) * 3.0;
	float tri = 0.0;
	float core_d = ring_d;
	for (int i = 0; i < 3; i++) {
		float a0 = 1.5708 + float(i) * 2.0944;
		vec2 A = vec2(cos(a0), sin(a0)) * 0.9;
		vec2 B = vec2(cos(a0 + 2.0944), sin(a0 + 2.0944)) * 0.9;
		float s = 0.0;
		float d = seg_d(p, A, B, s) + wob * 0.6;
		float vis = step(s, clamp(tri_prog - float(i), 0.0, 1.0)) * step(0.001, tri_prog - float(i));
		tri = max(tri, (1.0 - smoothstep(0.022, 0.036, d)) * vis);
		if (vis > 0.5) {
			core_d = min(core_d, d);
		}
	}
	float spl = step(0.84, vn2(p * 14.0 + vec2(seed * 3.0))) * (1.0 - smoothstep(0.0, 0.11, ring_d)) * step(ang, ring_prog);
	float line = max(max(ring, tri), spl * 0.9);
	float pr = 0.15 + (1.0 - pulse) * 0.8;
	float wave = (1.0 - smoothstep(0.0, 0.05, abs(r - pr))) * pulse * step(r, 0.95);
	vec3 col = vec3(0.42, 0.01, 0.02);
	col = mix(col, vec3(0.75, 0.06, 0.05), 1.0 - smoothstep(0.0, 0.016, core_d));
	float gl = step(0.9, vn2(p * 40.0 + vec2(seed * 5.0))) * (1.0 - smoothstep(0.0, 0.02, core_d));
	col = mix(col, vec3(1.0, 0.65, 0.6), gl * 0.7);
	col = mix(col, vec3(1.0, 0.25, 0.2), pulse * 0.55);
	float a = max(line, wave * 0.8) * fade;
	if (a < 0.01) {
		discard;
	}
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Parçacık: kind 0 pul tozu yıldızı, 1 toz, 2 kan damlası, 3 yonga (altın / taş), 4 pus, 5 iplik tüyü, 6 chakra zerresi
const PART_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float near_d = 1.5;
instance uniform float fade = 1.0;

varying float rnd;

void vertex() {
	rnd = fract(float(INSTANCE_ID) * 0.6180339);
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	vec3 col = COLOR.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		float ax = (1.0 - smoothstep(0.0, 0.08, abs(q.y))) * (1.0 - abs(q.x));
		float ay = (1.0 - smoothstep(0.0, 0.08, abs(q.x))) * (1.0 - abs(q.y));
		float core = 1.0 - smoothstep(0.1, 0.3, r);
		a = clamp(max(max(ax, ay), core), 0.0, 1.0);
		col = mix(col, vec3(1.0), core);
		a *= 0.35 + 0.65 * step(0.0, sin(TIME * 9.0 + rnd * 40.0));
	} else if (kind < 1.5) {
		a = (1.0 - smoothstep(0.35, 1.0, r)) * 0.55;
		col *= 0.85 + 0.15 * step(0.0, q.y);
	} else if (kind < 2.5) {
		vec2 p = q * vec2(1.0, 0.75) + vec2(0.0, 0.2);
		float d = length(p);
		a = 1.0 - smoothstep(0.55, 0.65, d);
		col = mix(col * 0.6, col, step(d, 0.42));
		col = mix(col, vec3(1.0, 0.75, 0.75), (1.0 - smoothstep(0.0, 0.12, length(p - vec2(-0.18, 0.18)))) * 0.8);
	} else if (kind < 3.5) {
		float ca = cos(rnd * 6.28);
		float sa = sin(rnd * 6.28);
		vec2 p = abs(vec2(q.x * ca - q.y * sa, q.x * sa + q.y * ca));
		float dia = p.x * 1.6 + p.y;
		a = 1.0 - smoothstep(0.82, 0.9, dia);
		col = mix(col * 0.55, col, step(dia, 0.62));
	} else if (kind < 4.5) {
		a = pow(max(0.0, 1.0 - r), 2.0);
	} else if (kind < 5.5) {
		float d = abs(length(q - vec2(0.35, 0.0)) - 0.55);
		a = (1.0 - smoothstep(0.03, 0.09, d)) * step(q.x, 0.5) * (1.0 - smoothstep(0.7, 1.0, r));
	} else {
		a = 1.0 - smoothstep(0.0, 1.0, r);
		a = a * a;
		col = mix(col, vec3(1.0), 1.0 - smoothstep(0.0, 0.3, r));
	}
	a *= COLOR.a * fade * smoothstep(near_d * 0.35, near_d, -VERTEX.z);
	if (a < 0.003) {
		discard;
	}
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Chakra şeridi (taş iğnenin mavi akımı): beyaz çekirdek, mavi gövde, titreşen kuyruk
const CHAKRA_SHADER := """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform vec4 tint = vec4(0.45, 0.7, 1.0, 1.0);

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float age = UV.x;
	float core = 1.0 - smoothstep(0.0, 0.35, across);
	float body = 1.0 - smoothstep(0.3, 1.0, across);
	float flick = 0.75 + 0.25 * sin(age * 40.0 - TIME * 30.0);
	vec3 col = mix(tint.rgb, vec3(1.0), core * 0.8);
	float a = (body * 0.8 + core * 0.4) * (1.0 - age) * flick * fade * smoothstep(0.3, 1.5, -VERTEX.z);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


# ================================================================== malzemeler
static func _shader(key: String, code: String) -> Shader:
	var k = "shd:" + key
	if not _cache.has(k):
		var s = Shader.new()
		s.code = code
		_cache[k] = s
	return _cache[k]


static func _mat(kind: String) -> ShaderMaterial:
	var k = "mat:" + kind
	if _cache.has(k):
		return _cache[k]
	var bodies = {"silk": SILK_F, "gold": GOLD_F, "fiber": FIBER_F, "toon": TOON_F}
	var body: String = bodies[kind]
	var m = ShaderMaterial.new()
	m.shader = _shader(kind, HEAD.replace("//GROW", "") + "\nvoid fragment() {\n" + PRE + body)
	var o = ShaderMaterial.new()
	o.shader = _shader("outline", HEAD.replace("//GROW", GROW_LINE) + OUT_F)
	m.next_pass = o
	_cache[k] = m
	return m


static func _plain_mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _shader(key, code)
		_cache[k] = m
	return _cache[k]


static func _setp(gi: GeometryInstance3D, d: Dictionary) -> void:
	for k in d:
		if k in PARAMS:
			var v = d[k]
			if typeof(v) == TYPE_INT:
				v = float(v)
			gi.set_instance_shader_parameter(k, v)


static func _mi(mesh: Mesh, kind: String, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d: Dictionary = DEF[kind].duplicate()
	d["seed"] = randf() * 10.0
	d.merge(o, true)
	_setp(mi, d)
	return mi


## Örnek parametresini zamanla değiştir (gecikmeli)
static func _tp(gi: GeometryInstance3D, pname: String, a: float, b: float, dur: float, delay := 0.0) -> Tween:
	var tw = gi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): gi.set_instance_shader_parameter(pname, v), a, b, dur)
	return tw


static func _gis(n: Node) -> Array:
	var out = []
	if n is GeometryInstance3D:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_gis(ch))
	return out


## Titreşimli sönüp silinme (düğüm ve altındaki tüm geometriler)
static func _fade_free(n: Node3D, delay: float, dur: float) -> void:
	if not is_instance_valid(n):
		return
	var gl = _gis(n)
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		for g in gl:
			if is_instance_valid(g):
				g.set_instance_shader_parameter("fade", v), 1.0, 0.0, dur)
	tw.tween_callback(n.queue_free)


static func _aim(n: Node3D, d: Vector3) -> void:
	if d.length() > 0.001:
		var dn = d.normalized()
		n.look_at(n.global_position + dn, Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT)


## Birim tüp (0 → -Z 1) iki nokta arasına: yerel X/Y = kalınlık, Z = boy
static func _span(mi: Node3D, a: Vector3, b: Vector3, w: float) -> float:
	var d = b - a
	var L = d.length()
	if L < 0.02:
		mi.visible = false
		return L
	mi.visible = true
	var f = d / L
	var bz = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT)
	mi.global_transform = Transform3D(Basis(bz.x * w, bz.y * w, bz.z * L), a)
	return L


static func _span_local(mi: Node3D, a: Vector3, b: Vector3, w: float) -> void:
	var d = b - a
	var L = maxf(d.length(), 0.001)
	var f = d / L
	var bz = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT)
	mi.transform = Transform3D(Basis(bz.x * w, bz.y * w, bz.z * L), a)


# ------------------------------------------------------------------ izleyiciler (son bilinen konumu tutar)
static func _follow(n: Node3D, off: Vector3) -> Callable:
	var last = {"p": Vector3.ZERO}
	if is_instance_valid(n) and n.is_inside_tree():
		last["p"] = n.global_position + off
	var wr = weakref(n)
	return func() -> Vector3:
		var x = wr.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			last["p"] = x.global_position + off
		return last["p"]


static func _hand_fn(pj: PathJutsu, c: Node3D, right: bool) -> Callable:
	var last = {"p": pj.hand_pos(c, right)}
	return func() -> Vector3:
		if pj.live(c):
			last["p"] = pj.hand_pos(c, right)
		return last["p"]


static func _mouth_fn(pj: PathJutsu, c: Node3D) -> Callable:
	var last = {"p": pj._mouth_pos(c)}
	return func() -> Vector3:
		if pj.live(c):
			last["p"] = pj._mouth_pos(c)
		return last["p"]


# ================================================================== geometri
class G:
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var uv := PackedVector2Array()
	var cl := PackedColorArray()
	var ix := PackedInt32Array()

	## Paralel taşınan çerçeveli tüp; UV.y = boy boyunca 0..1. o: flat (yassılık), ridges/ramp/twist (sarmal sırt)
	func tube(pts: Array, radii: Array, sides: int, col: Color, o := {}) -> void:
		var n = pts.size()
		if n < 2:
			return
		var flat = float(o.get("flat", 1.0))
		var ridges = int(o.get("ridges", 0))
		var ramp = float(o.get("ramp", 0.0))
		var twist = float(o.get("twist", 0.0))
		var lens = [0.0]
		for i in range(1, n):
			lens.append(lens[i - 1] + (pts[i] - pts[i - 1]).length())
		var total = maxf(lens[n - 1], 0.00001)
		var t0: Vector3 = (pts[1] - pts[0]).normalized()
		var nr: Vector3 = t0.cross(Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT).normalized()
		var base = v.size()
		for i in n:
			var tn: Vector3
			if i == 0:
				tn = pts[1] - pts[0]
			elif i == n - 1:
				tn = pts[i] - pts[i - 1]
			else:
				tn = pts[i + 1] - pts[i - 1]
			tn = tn.normalized()
			var nr2: Vector3 = nr - tn * nr.dot(tn)
			if nr2.length() < 0.01:
				nr2 = tn.cross(Vector3.UP if absf(tn.y) < 0.9 else Vector3.RIGHT)
			nr = nr2.normalized()
			var bn: Vector3 = tn.cross(nr)
			var r = float(radii[mini(i, radii.size() - 1)])
			for s in sides + 1:
				var a = TAU * float(s) / sides
				var rr = r
				if ridges > 0:
					rr = r * (1.0 + ramp * sin(a * ridges + lens[i] * twist))
				var d: Vector3 = nr * cos(a) + bn * sin(a) * flat
				var dn: Vector3 = (nr * cos(a) + bn * sin(a) / maxf(flat, 0.05)).normalized()
				v.append(pts[i] + d * rr)
				nm.append(dn)
				uv.append(Vector2(float(s) / sides, lens[i] / total))
				cl.append(col)
		for i in n - 1:
			for s in sides:
				var a0 = base + i * (sides + 1) + s
				var b0 = a0 + sides + 1
				ix.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))

	## Elipsoit / topak (lump > 0: pürüzlü)
	func sphere(c: Vector3, sz: Vector3, col: Color, seg := 10, lump := 0.0, sd := 0.0) -> void:
		var rings = maxi(4, int(seg / 2.0))
		var base = v.size()
		for i in rings + 1:
			var th = PI * float(i) / rings
			for j in seg + 1:
				var ph = TAU * float(j) / seg
				var d = Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				var f = 1.0
				if lump > 0.0:
					f += lump * (sin(d.x * 4.1 + sd) * sin(d.y * 3.3 + sd * 1.7) + 0.6 * sin(d.z * 5.2 - sd * 0.9) * sin(d.x * 2.7 + sd))
				v.append(c + Vector3(d.x * sz.x, d.y * sz.y, d.z * sz.z) * 0.5 * f)
				nm.append(Vector3(d.x / maxf(sz.x, 0.001), d.y / maxf(sz.y, 0.001), d.z / maxf(sz.z, 0.001)).normalized())
				uv.append(Vector2(float(j) / seg, float(i) / rings))
				cl.append(col)
		for i in rings:
			for j in seg:
				var a0 = base + i * (seg + 1) + j
				var b0 = a0 + seg + 1
				ix.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))

	func build() -> ArrayMesh:
		var m = ArrayMesh.new()
		if v.is_empty():
			return m
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nm
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = cl
		arr[Mesh.ARRAY_INDEX] = ix
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static func _done(key: String, g: G) -> ArrayMesh:
	var m = g.build()
	_cache[key] = m
	return m


static func _helix(r: float, y0: float, y1: float, turns: float, n: int, ph := 0.0, wob := 0.0) -> Array:
	var pts = []
	for i in n:
		var f = float(i) / (n - 1)
		var a = ph + f * turns * TAU
		var rr = r + wob * sin(f * 17.0 + ph * 3.0)
		pts.append(Vector3(cos(a) * rr, lerpf(y0, y1, f), sin(a) * rr))
	return pts


static func _unit_tube(seg: int, sides: int) -> ArrayMesh:
	var key = "mesh:utube:%d:%d" % [seg, sides]
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var pts = []
	for i in seg + 1:
		pts.append(Vector3(0, 0, -float(i) / seg))
	g.tube(pts, [1.0], sides, WHITE_V)
	return _done(key, g)


## Pürüzlü topak (altın kabuk / damla / yumurta kesesi / yapışkan yumak)
static func _blob_mesh(vi: int) -> ArrayMesh:
	var key = "mesh:blob:%d" % vi
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	g.sphere(Vector3.ZERO, Vector3.ONE, WHITE_V, 16 if vi < 3 else 10, 0.09 if vi != 3 else 0.04, vi * 1.37 + 0.4)
	return _done(key, g)


static func _rock_mesh(vi: int) -> ArrayMesh:
	var key = "mesh:rock:%d" % vi
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	g.sphere(Vector3.ZERO, Vector3(1.0, 0.75, 0.9), Color(0.5, 0.42, 0.32), 7, 0.22, vi * 2.1 + 0.7)
	return _done(key, g)


## Gerçek örümcek ağı: ışınsal teller + hub'a doğru eğilen çokgen halkalar (anime) + dış bağ telleri; belly: ağın göbek çukuru
static func _orb_web_mesh(r: float, spokes: int, rings: int, th: float, belly: float, sd: int) -> ArrayMesh:
	var key = "mesh:orb:%.2f:%d:%d:%.3f:%.2f:%d" % [r, spokes, rings, th, belly, sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 1000 + sd
	var g = G.new()
	var angs = []
	var rim = []
	for s in spokes:
		angs.append((s + rng.randf_range(-0.22, 0.22)) * TAU / spokes)
		rim.append(r * rng.randf_range(0.86, 1.0))
	var at = func(s: int, f: float) -> Vector3:
		var rr = float(rim[s]) * f
		return Vector3(cos(angs[s]) * rr, sin(angs[s]) * rr, -belly * (1.0 - f * f))
	for s in spokes:
		var sp = []
		for i in 5:
			sp.append(at.call(s, lerpf(0.03, 1.0, float(i) / 4.0)))
		g.tube(sp, [th * 1.3, th * 1.1, th, th, th * 0.9], 5, WHITE_V)
		if s % 3 == 0:
			var e: Vector3 = at.call(s, 1.0)
			g.tube([e, e * 1.14 + Vector3(0, 0, belly * 0.1)], [th * 0.9, th * 0.6], 4, WHITE_V)
	for k in rings:
		var f = 0.1 + 0.88 * pow(float(k + 1) / rings, 1.12)
		for s in spokes:
			var s2 = (s + 1) % spokes
			var a: Vector3 = at.call(s, f)
			var b: Vector3 = at.call(s2, f)
			var mid = (a + b) * 0.5
			mid = Vector3(mid.x * 0.93, mid.y * 0.93, mid.z)
			g.tube([a, mid, b], [th * 0.85, th * 0.75, th * 0.85], 4, WHITE_V)
	g.sphere(Vector3(0, 0, -belly), Vector3.ONE * th * 7.0, WHITE_V, 8, 0.15, 1.0)
	return _done(key, g)


## Düzensiz hücreli ağ çarşafı (Kumo Sōkai): kalın yassı teller, düğümlerde topaklar, kenarlar dışa kavisli; üst kenar y=0, aşağı uzanır
static func _cell_sheet_mesh(W: float, H: float, nx: int, ny: int, th: float, curl: float, sd: int) -> ArrayMesh:
	var key = "mesh:sheet:%.2f:%.2f:%d:%d:%.3f:%.2f:%d" % [W, H, nx, ny, th, curl, sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 2000 + sd
	var g = G.new()
	var grid = []
	for j in ny + 1:
		var row = []
		for i in nx + 1:
			var x = -W * 0.5 + W * float(i) / nx
			var y = -H * float(j) / ny
			if i > 0 and i < nx:
				x += rng.randf_range(-0.32, 0.32) * W / nx
			if j > 0 and j < ny:
				y += rng.randf_range(-0.32, 0.32) * H / ny
			row.append(Vector3(x, y, -curl * pow(x / (W * 0.5), 2.0)))
		grid.append(row)
	var ctr = Vector3(0, -H * 0.5, 0)
	var edge = func(a: Vector3, b: Vector3, bd: bool) -> void:
		var mid = (a + b) * 0.5
		var ab = b - a
		var perp = Vector3(-ab.y, ab.x, 0).normalized()
		if bd:
			if perp.dot(mid - ctr) < 0.0:
				perp = -perp
			mid += perp * ab.length() * 0.2
		else:
			mid += perp * ab.length() * rng.randf_range(-0.12, 0.12)
		g.tube([a, mid, b], [th * 1.35, th, th * 1.35], 4, WHITE_V, {"flat": 0.55})
	for j in ny + 1:
		for i in nx + 1:
			var p0: Vector3 = grid[j][i]
			g.sphere(p0, Vector3.ONE * th * 2.8, WHITE_V, 5)
			if i < nx:
				edge.call(p0, grid[j][i + 1], j == 0 or j == ny)
			if j < ny:
				edge.call(p0, grid[j + 1][i], i == 0 or i == nx)
			if i < nx and j < ny and rng.randf() < 0.35:
				if rng.randf() < 0.5:
					edge.call(p0, grid[j + 1][i + 1], false)
				else:
					edge.call(grid[j][i + 1], grid[j + 1][i], false)
	return _done(key, g)


## Çiçek / kâse ağı (Kumo Sōka): halka halka düzensiz hücre, dış halka taç yaprağı gibi dalgalı; depth > 0 → kâse (ağzı -Z)
static func _cup_mesh(r: float, depth: float, rings: int, spokes: int, th: float, petals: int, sd: int) -> ArrayMesh:
	var key = "mesh:cup:%.2f:%.2f:%d:%d:%.3f:%d:%d" % [r, depth, rings, spokes, th, petals, sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 3000 + sd
	var g = G.new()
	var pts = []
	for k in rings:
		var row = []
		var f = float(k + 1) / rings
		for s in spokes:
			var a = (s + rng.randf_range(-0.22, 0.22)) * TAU / spokes
			var rr = r * f * rng.randf_range(0.9, 1.06)
			if k == rings - 1 and petals > 0:
				rr *= 1.0 + 0.22 * cos(a * petals)
			row.append(Vector3(cos(a) * rr, sin(a) * rr, -depth * f * f))
		pts.append(row)
	g.sphere(Vector3.ZERO, Vector3.ONE * th * 5.0, WHITE_V, 6)
	for s in spokes:
		g.tube([Vector3.ZERO, pts[0][s]], [th * 1.3, th], 4, WHITE_V, {"flat": 0.6})
	for k in rings:
		for s in spokes:
			var p0: Vector3 = pts[k][s]
			var p1: Vector3 = pts[k][(s + 1) % spokes]
			var mid = (p0 + p1) * 0.5
			var rad = Vector3(mid.x, mid.y, 0).normalized()
			if k == rings - 1:
				mid += rad * r * 0.08
			else:
				mid -= rad * r * 0.03
			g.tube([p0, mid, p1], [th, th * 0.8, th], 4, WHITE_V, {"flat": 0.6})
			if k < rings - 1:
				var s2 = s if rng.randf() < 0.7 else (s + 1) % spokes
				g.tube([p0, pts[k + 1][s2]], [th, th], 4, WHITE_V, {"flat": 0.6})
			g.sphere(p0, Vector3.ONE * th * 2.6, WHITE_V, 5)
	return _done(key, g)


## Rulo hâlinde sarılı ağ (X ekseni boyunca, çapraz sarımlar + iç yumak)
static func _roll_mesh() -> ArrayMesh:
	var key = "mesh:roll"
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	g.sphere(Vector3.ZERO, Vector3(0.64, 0.34, 0.34), WHITE_V, 10, 0.08, 2.0)
	for h in 4:
		var pts = []
		var dirn = 1.0 if h % 2 == 0 else -1.0
		for i in 40:
			var f = float(i) / 39.0
			var a = h * 1.3 + dirn * f * 6.0 * TAU
			pts.append(Vector3(lerpf(-0.32, 0.32, f), cos(a) * 0.19, sin(a) * 0.19))
		g.tube(pts, [0.016], 4, WHITE_V)
	return _done(key, g)


## Hedefe dolanan ipek sarmalı (+ dikine çapraz teller)
static func _wrap_mesh() -> ArrayMesh:
	var key = "mesh:wrap"
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	g.tube(_helix(0.44, 0.3, 1.5, 5.0, 90, 0.0, 0.04), [0.022], 4, WHITE_V)
	for k in 4:
		var a = k * TAU / 4.0 + 0.4
		var b = a + 0.9
		g.tube([Vector3(cos(a) * 0.46, 0.25, sin(a) * 0.46), Vector3(cos((a + b) * 0.5) * 0.5, 0.9, sin((a + b) * 0.5) * 0.5), Vector3(cos(b) * 0.46, 1.55, sin(b) * 0.46)], [0.016], 4, WHITE_V)
	return _done(key, g)


## Kapalı halka (XZ düzleminde, yarıçap 1)
static func _ring_mesh() -> ArrayMesh:
	var key = "mesh:ring"
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var pts = []
	for i in 29:
		var a = TAU * float(i) / 28.0
		pts.append(Vector3(cos(a), 0.0, sin(a)))
	g.tube(pts, [0.12], 6, WHITE_V)
	return _done(key, g)


## Açık yay (XY düzleminde, uçları incelen) — esneme çizgisi
static func _arc_mesh() -> ArrayMesh:
	var key = "mesh:arc"
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var pts = []
	var rad = []
	for i in 13:
		var f = float(i) / 12.0
		var a = lerpf(-1.2, 1.2, f)
		pts.append(Vector3(cos(a), sin(a), 0.0))
		rad.append(0.065 * sin(f * PI))
	g.tube(pts, rad, 5, WHITE_V)
	return _done(key, g)


## Jiongu iplik demeti: üç burgulu alt demet, uçta saçılır; -Z boyunca birim boy, taban yarıçapı ~1
static func _bundle_mesh(vi: int) -> ArrayMesh:
	var key = "mesh:bundle:%d" % vi
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 4000 + vi
	var g = G.new()
	var n = 16
	for s in 3:
		var ph = s * TAU / 3.0 + rng.randf()
		var pts = []
		var rad = []
		for i in n:
			var t = float(i) / (n - 1)
			var tw = ph + t * (4.0 + vi)
			var spread = 0.42 * (1.0 - 0.4 * t) + 1.8 * maxf(0.0, t - 0.8)
			pts.append(Vector3(cos(tw) * spread, sin(tw) * spread, -t))
			rad.append(0.55 * (1.0 - 0.8 * t) + 0.04)
		g.tube(pts, rad, 6, WHITE_V)
	for s in 2:
		var t0 = rng.randf_range(0.2, 0.5)
		var a = rng.randf() * TAU
		var o = Vector3(cos(a), sin(a), 0.0)
		g.tube([Vector3(0, 0, -t0) + o * 0.5, Vector3(0, 0, -t0 - 0.06) + o * 1.4, Vector3(0, 0, -t0 - 0.14) + o * 1.1], [0.16, 0.1, 0.0], 4, WHITE_V)
	return _done(key, g)


## Jiongu sarma bobini (hedef gövdesi çevresi)
static func _coil_mesh() -> ArrayMesh:
	var key = "mesh:coil"
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	g.tube(_helix(0.5, 0.35, 1.45, 3.2, 70, 0.0, 0.05), [0.07], 6, WHITE_V)
	g.tube(_helix(0.47, 1.4, 0.4, 2.1, 50, 1.7, 0.04), [0.045], 5, WHITE_V)
	return _done(key, g)


## Örümcek (önü -Z): karın + baş-göğüs, sırt deseni, kırmızı gözler, kıskaçlar, sekiz eklemli bacak
static func _spider_mesh(baby: bool) -> ArrayMesh:
	var key = "mesh:spider:%d" % int(baby)
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var blk = Color(0.13, 0.12, 0.14)
	var mark = Color(0.95, 0.52, 0.12) if not baby else Color(0.55, 0.14, 0.1)
	g.sphere(Vector3(0, 0.42, 0.42), Vector3(0.8, 0.62, 0.92), blk, 14, 0.04, 1.3)
	g.sphere(Vector3(0, 0.36, -0.14), Vector3(0.46, 0.34, 0.48), blk, 12)
	g.sphere(Vector3(0, 0.71, 0.4), Vector3(0.16, 0.05, 0.62), mark, 8)
	for sx in [-1.0, 1.0]:
		g.sphere(Vector3(0.22 * sx, 0.64, 0.46), Vector3(0.1, 0.05, 0.46), mark, 8)
		g.sphere(Vector3(0.09 * sx, 0.44, -0.36), Vector3(0.06, 0.06, 0.06), Color(0.85, 0.1, 0.08), 6)
		g.tube([Vector3(0.07 * sx, 0.3, -0.36), Vector3(0.08 * sx, 0.2, -0.44), Vector3(0.05 * sx, 0.12, -0.4)], [0.035, 0.025, 0.0], 5, blk)
		for k in 4:
			var a = deg_to_rad(-55.0 + k * 36.0)
			var hd = Vector3(sx * cos(a), 0.0, sin(a))
			var root = Vector3(0.16 * sx, 0.36, -0.14 + (k - 1.5) * 0.08)
			var knee = root + hd * 0.42 + Vector3.UP * 0.34
			var ankle = root + hd * 0.85 + Vector3.UP * 0.05
			var foot = root + hd * 1.0 + Vector3.DOWN * 0.34
			g.tube([root, knee, ankle, foot], [0.05, 0.042, 0.03, 0.01], 5, blk)
	return _done(key, g)


## Yay kolu noktası (YZ düzlemi; kabza 0'da, uçlar okçuya doğru +Z, uç kıvrımı)
static func _bow_pt(R: float, f: float, sgn: float) -> Vector3:
	var a = f * BOW_A
	var p = Vector3(0.0, R * sin(a) * sgn, R * (1.0 - cos(a)) * 0.8)
	if f > 0.82:
		p.z -= (f - 0.82) * R * 0.5
	return p


## Altın yay: kabzadan uca iki kol (UV.y kabzada 0 → altın kabzadan uçlara akar); büyükte pürüzlü düğümler ve sırt dikenleri
static func _bow_mesh(R: float, big: bool) -> ArrayMesh:
	var key = "mesh:bow:%.2f:%d" % [R, int(big)]
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var n = 14
	for sgn in [1.0, -1.0]:
		var pts = []
		var rad = []
		for i in n:
			var f = float(i) / (n - 1)
			pts.append(_bow_pt(R, f, sgn))
			var rr = R * (0.045 * (1.0 - f) + 0.012)
			if big and i % 3 == 1:
				rr *= 1.35
			rad.append(rr)
		g.tube(pts, rad, 6, WHITE_V)
		if big:
			for i in [3, 6, 9]:
				var b: Vector3 = pts[i]
				var outw = Vector3(0.0, 0.35 * sgn, -1.0).normalized()
				g.tube([b, b + outw * R * 0.14], [R * 0.025, 0.0], 4, WHITE_V)
	g.sphere(Vector3.ZERO, Vector3(R * 0.12, R * 0.22, R * 0.12), WHITE_V, 8, 0.1, 1.0)
	return _done(key, g)


## Nenkin oku: pürüzlü altın gövde, tırtıklı yassı yaprak uç, kuyrukta iki çentik (önü -Z, kuyruk z=+0.55)
static func _jag_arrow_mesh() -> ArrayMesh:
	var key = "mesh:jagarrow"
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var sh = []
	var sr = []
	for i in 9:
		var f = float(i) / 8.0
		sh.append(Vector3(0.0, 0.0, lerpf(0.55, -0.3, f)))
		sr.append(0.034 if i % 2 == 0 else 0.046)
	g.tube(sh, sr, 6, WHITE_V)
	var hd = []
	var hr = [0.04, 0.12, 0.07, 0.11, 0.05, 0.075, 0.03, 0.0]
	for i in hr.size():
		hd.append(Vector3(0.0, 0.0, lerpf(-0.28, -0.66, float(i) / (hr.size() - 1))))
	g.tube(hd, hr, 4, WHITE_V, {"flat": 0.3})
	for sx in [-1.0, 1.0]:
		g.tube([Vector3(0, 0, 0.45), Vector3(0.1 * sx, 0.0, 0.62)], [0.03, 0.0], 4, WHITE_V)
	return _done(key, g)


## Suzaku oku: uzun gövde boyunca sarmal sırt, matkap uç (üç sırtlı burgu), kuyrukta dört kanatçık (önü -Z, kuyruk z=+1.6)
static func _drill_arrow_mesh() -> ArrayMesh:
	var key = "mesh:drillarrow"
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var sh = []
	for i in 13:
		sh.append(Vector3(0.0, 0.0, lerpf(1.6, -0.4, float(i) / 12.0)))
	g.tube(sh, [0.06], 8, WHITE_V, {"ridges": 2, "ramp": 0.3, "twist": 6.0})
	var hd = []
	var hr = []
	for i in 10:
		var f = float(i) / 9.0
		hd.append(Vector3(0.0, 0.0, lerpf(-0.38, -1.05, f)))
		hr.append(0.17 * (1.0 - f) + 0.005)
	g.tube(hd, hr, 12, WHITE_V, {"ridges": 3, "ramp": 0.45, "twist": 14.0})
	for k in 4:
		var a = k * TAU / 4.0 + 0.4
		var o = Vector3(cos(a), sin(a), 0.0)
		g.tube([Vector3(0, 0, 1.15) + o * 0.05, Vector3(0, 0, 1.4) + o * 0.24, Vector3(0, 0, 1.58) + o * 0.08], [0.03, 0.02, 0.0], 4, WHITE_V, {"flat": 0.4})
	return _done(key, g)


## Altın kıymığı (önü -Z)
static func _shard_mesh(vi: int) -> ArrayMesh:
	var key = "mesh:shard:%d" % vi
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var L = 0.5 + vi * 0.15
	g.tube([Vector3.ZERO, Vector3(0.02 * vi, 0.0, -L * 0.35), Vector3(0.0, 0.0, -L * 0.7), Vector3(-0.02, 0.0, -L)], [0.05, 0.1 - vi * 0.015, 0.06, 0.0], 4, WHITE_V, {"flat": 0.45})
	return _done(key, g)


## Taş iğne (önü -Z): altıgen sivri gövde, arkada silindirik başlık ve iki oluk halkası (ref)
static func _needle_mesh(vi: int) -> ArrayMesh:
	var key = "mesh:needle:%d" % vi
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var stone = Color(0.62, 0.63, 0.67).darkened(vi * 0.06)
	var dark = Color(0.42, 0.43, 0.48)
	g.tube([Vector3(0, 0, 0.06), Vector3(0, 0, -0.12), Vector3(0, 0, -0.3), Vector3(0, 0, -0.44)], [0.022, 0.02, 0.012, 0.0], 6, stone)
	g.tube([Vector3(0, 0, 0.21), Vector3(0, 0, 0.04)], [0.05], 8, stone.lightened(0.08))
	g.tube([Vector3(0, 0, 0.18), Vector3(0, 0, 0.16)], [0.057], 8, dark)
	g.tube([Vector3(0, 0, 0.09), Vector3(0, 0, 0.07)], [0.057], 8, dark)
	g.sphere(Vector3(0, 0, 0.21), Vector3(0.1, 0.1, 0.03), stone, 8)
	return _done(key, g)


static func _needle_coil_mesh() -> ArrayMesh:
	var key = "mesh:ncoil"
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var pts = []
	for i in 30:
		var f = float(i) / 29.0
		var a = f * 2.5 * TAU
		pts.append(Vector3(cos(a) * 0.075, sin(a) * 0.075, lerpf(0.2, -0.3, f)))
	g.tube(pts, [0.012], 4, WHITE_V)
	return _done(key, g)


## Yerde çatlak ağı: merkezden kırık kırık yayılan yassı koyu yarıklar
static func _crack_mesh(vi: int) -> ArrayMesh:
	var key = "mesh:crack:%d" % vi
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 5000 + vi
	var g = G.new()
	var col = Color(0.22, 0.16, 0.11)
	for k in 7:
		var a = k * TAU / 7.0 + rng.randf_range(-0.3, 0.3)
		var p = Vector3(cos(a), 0, sin(a)) * 0.25
		var pts = [p]
		var rad = []
		for i in 5:
			a += rng.randf_range(-0.5, 0.5)
			p += Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 0.5)
			pts.append(p)
		for i in pts.size():
			rad.append(0.08 * (1.0 - float(i) / pts.size()) + 0.01)
		g.tube(pts, rad, 4, col, {"flat": 0.12})
	g.sphere(Vector3.ZERO, Vector3(0.9, 0.04, 0.9), col.lightened(0.15), 10, 0.12, vi * 1.0)
	return _done(key, g)


# ================================================================== parçacıklar
static func _quad() -> QuadMesh:
	var k = "mesh:quad"
	if not _cache.has(k):
		var q = QuadMesh.new()
		q.size = Vector2.ONE
		_cache[k] = q
	return _cache[k]


static func _curve(nm: String) -> CurveTexture:
	var k = "crv:" + nm
	if _cache.has(k):
		return _cache[k]
	var cv = Curve.new()
	match nm:
		"grow":
			cv.add_point(Vector2(0.0, 0.35))
			cv.add_point(Vector2(1.0, 1.0))
		"flat":
			cv.add_point(Vector2(0.0, 0.8))
			cv.add_point(Vector2(1.0, 1.0))
		_:
			cv.add_point(Vector2(0.0, 0.0))
			cv.add_point(Vector2(0.12, 1.0))
			cv.add_point(Vector2(0.7, 0.75))
			cv.add_point(Vector2(1.0, 0.0))
	var ct = CurveTexture.new()
	ct.curve = cv
	_cache[k] = ct
	return ct


static func _ramp(cols: Array) -> GradientTexture1D:
	var gr = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[i])
	gr.offsets = offs
	gr.colors = cs
	var t = GradientTexture1D.new()
	t.gradient = gr
	return t


## o: kind, n, life, dir, spread, vmin, vmax, g, damp, smin, smax, r | box | ring, cols, one_shot, burst, near, curve
static func _parts(o: Dictionary) -> GPUParticles3D:
	var p = GPUParticles3D.new()
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 180.0))
	pm.initial_velocity_min = float(o.get("vmin", 1.0))
	pm.initial_velocity_max = float(o.get("vmax", 3.0))
	pm.gravity = o.get("g", Vector3(0, -3.0, 0))
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0))
	pm.scale_min = float(o.get("smin", 0.1))
	pm.scale_max = float(o.get("smax", 0.25))
	pm.scale_curve = _curve(str(o.get("curve", "pop")))
	if o.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = o["box"]
	elif o.has("ring"):
		var rr = float(o["ring"])
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = rr
		pm.emission_ring_inner_radius = rr * 0.8
		pm.emission_ring_height = 0.05
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(o.get("r", 0.2))
	pm.color_ramp = _ramp(o.get("cols", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	p.process_material = pm
	p.draw_pass_1 = _quad()
	p.material_override = _plain_mat("part", PART_SHADER)
	p.amount = maxi(1, int(o.get("n", 12)))
	p.lifetime = float(o.get("life", 0.8))
	p.one_shot = bool(o.get("one_shot", true))
	p.explosiveness = float(o.get("burst", 0.92))
	p.randomness = 0.4
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	p.set_instance_shader_parameter("kind", float(o.get("kind", 0.0)))
	p.set_instance_shader_parameter("near_d", float(o.get("near", 1.5)))
	return p


static func _emit(pj: PathJutsu, o: Dictionary, pos: Vector3) -> GPUParticles3D:
	var p = _parts(o)
	pj.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	if p.one_shot:
		pj.free_after(p.lifetime + 0.5, p)
	return p


static func _blood(pj: PathJutsu, pos: Vector3, n: int, v: float) -> void:
	_emit(pj, {"kind": 2.0, "n": n, "life": 0.6, "vmin": v * 0.4, "vmax": v, "g": Vector3(0, -14.0, 0), "smin": 0.05, "smax": 0.12, "r": 0.15,
		"curve": "flat", "cols": [Color(0.8, 0.06, 0.06, 1.0), Color(0.6, 0.02, 0.03, 1.0), Color(0.45, 0.0, 0.02, 0.0)]}, pos)


static func _fluff(pj: PathJutsu, pos: Vector3, n: int, col := Color(0.97, 0.97, 0.93)) -> void:
	_emit(pj, {"kind": 5.0, "n": n, "life": 0.9, "vmin": 0.8, "vmax": 2.6, "g": Vector3(0, -1.2, 0), "damp": 1.5, "smin": 0.12, "smax": 0.24, "r": 0.3,
		"cols": [Color(col.r, col.g, col.b, 1.0), Color(col.r, col.g, col.b, 0.8), Color(col.r, col.g, col.b, 0.0)]}, pos)


# ================================================================== yapı taşları
## İki hareketli nokta arası kalınlıklı ip (ipek ya da altın): sarkma, uçtan uca uzama (grow), yapışkan boncuk, örgü
static func _rope(pj: PathJutsu, a_fn: Callable, b_fn: Callable, w: float, dur: float, o := {}) -> MeshInstance3D:
	var p = {"ow": 0.3, "near_d": 0.8}
	p.merge(o, true)
	var grow = float(p.get("grow", 0.0))
	if grow > 0.0:
		p["reveal"] = 0.0
	var mi = _mi(_unit_tube(int(p.get("seg", 10)), int(p.get("sides", 5))), str(p.get("kind", "silk")), p)
	mi.extra_cull_margin = 2.0
	pj.get_tree().current_scene.add_child(mi)
	var sag = float(p.get("sag", 0.0))
	var t0 = Game.now()
	var upd = func(_i, _k):
		if not is_instance_valid(mi):
			return
		var L = _span(mi, a_fn.call(), b_fn.call(), w)
		mi.set_instance_shader_parameter("sag", sag * clampf(L / 5.0, 0.15, 1.5) / w)
		if grow > 0.0:
			mi.set_instance_shader_parameter("reveal", clampf((Game.now() - t0) / grow, 0.0, 1.0) * 1.01)
	upd.call(0, 0.0)
	pj.every(dur, 1.0 / 30.0, upd, func():
		if is_instance_valid(mi):
			mi.queue_free())
	return mi


## Ağın kenar noktalarından yere bağ telleri (yerel noktalar düğümün ölçeksiz son hâline göre)
static func _pin(pj: PathJutsu, node: Node3D, locals: Array, dur: float, out_len: float, w := 0.016) -> void:
	var bas = node.global_transform.basis.orthonormalized()
	for l in locals:
		var lv: Vector3 = l
		var fin = node.global_position + bas * lv
		var ow = fin - node.global_position
		ow.y = 0.0
		var gpos = pj.gp(fin + (ow.normalized() * out_len if ow.length() > 0.01 else Vector3.ZERO))
		var wr = weakref(node)
		var last = {"p": fin}
		var fa = func() -> Vector3:
			var x = wr.get_ref()
			if x != null and is_instance_valid(x) and x.is_inside_tree():
				last["p"] = x.to_global(lv)
			return last["p"]
		var fb = func() -> Vector3:
			return gpos
		_rope(pj, fa, fb, w, dur, {"sag": 0.12, "grow": 0.22})


## Hedefin gövdesine dolanan ipek sarmalı (aşağıdan yukarı sarılır, hedefi izler)
static func _wrap(pj: PathJutsu, h: Node3D, dur: float) -> void:
	var wm = _mi(_wrap_mesh(), "silk", {"reveal": 0.0, "wet": 1.0, "ow": 0.01})
	pj.scene_add(wm, h.global_position)
	var hh = h.get("height")
	wm.scale = Vector3.ONE * clampf((float(hh) if hh != null else 1.8) / 1.8, 0.6, 4.0)
	var fh = _follow(h, Vector3.ZERO)
	var t0 = Game.now()
	var tick = func(_i, _k):
		if not is_instance_valid(wm):
			return
		wm.global_position = fh.call()
		wm.rotation.y += 0.02
		wm.set_instance_shader_parameter("reveal", clampf((Game.now() - t0) / 0.3, 0.0, 1.0) * 1.01)
	var fin = func():
		if is_instance_valid(wm):
			_fade_free(wm, 0.0, 0.2)
	pj.every(dur, 1.0 / 30.0, tick, fin)


# ================================================================== Nenkin no Yoroi
## Ref (Kidōmaru): yapışkan altın deriden sızar, uzuvları ve yüzü pürüzlü koyu sarı kabukla kaplar; kabuk kahve çatlak çizgili ve lekeli.
## Önce derinin her yerinde altın boncuklar şişer, kabuk aşağıdan yukarı ıslak-turuncu ve kıpır kıpır yayılır, sonra donuklaşıp
## çatlaklanarak sertleşir (sertleşme anında kısa parlama). Islakken ellerden yere altın damlar, yerde yassı birikintiye döner ve sertleşir.
## Süre bitince kabuk pul pul dökülür.
static func nenkin_no_yoroi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var spec = {
		"UpperChest": [Vector3(0, 0.1, 0.02), Vector3(0.5, 0.46, 0.4)],
		"Head": [Vector3(0, 0.11, 0.03), Vector3(0.29, 0.33, 0.31)],
		"LeftLowerArm": [Vector3(0, 0.13, 0), Vector3(0.15, 0.34, 0.15)],
		"RightLowerArm": [Vector3(0, 0.13, 0), Vector3(0.15, 0.34, 0.15)],
		"LeftUpperLeg": [Vector3(0, 0.21, 0), Vector3(0.21, 0.5, 0.21)],
		"RightUpperLeg": [Vector3(0, 0.21, 0), Vector3(0.21, 0.5, 0.21)],
	}
	var parts = []
	var shells = []
	var i = 0
	for bone in ["UpperChest", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "Head"]:
		var ba = pj.bone_attach(c, bone)
		if ba == null:
			continue
		var sp: Array = spec[bone]
		var ofs: Vector3 = sp[0]
		var sz: Vector3 = sp[1]
		var shell = _mi(_blob_mesh(i % 3), "gold", {"wet": 1.0, "wob": 0.05, "reveal_y": -0.6, "ow": 0.05})
		ba.add_child(shell)
		shell.position = ofs
		shell.scale = sz
		shells.append(shell)
		for k in 3:
			var bead = _mi(_blob_mesh(3), "gold", {"wet": 1.0, "ow": 0.0})
			ba.add_child(bead)
			bead.position = ofs + Vector3(randf_range(-0.5, 0.5) * sz.x, randf_range(-0.4, 0.4) * sz.y, randf_range(-0.5, 0.5) * sz.z)
			bead.scale = Vector3.ONE * 0.01
			var bt = bead.create_tween()
			bt.tween_interval(k * 0.05)
			bt.tween_property(bead, "scale", Vector3.ONE * randf_range(0.05, 0.08), 0.18).set_ease(Tween.EASE_OUT)
			bt.tween_interval(0.2)
			bt.tween_property(bead, "scale", Vector3.ONE * 0.01, 0.15)
			bt.tween_callback(bead.queue_free)
		_tp(shell, "reveal_y", -0.6, 0.65, 0.4, 0.08 + i * 0.03)
		_tp(shell, "wet", 1.0, 0.0, 0.45, 0.55)
		_tp(shell, "wob", 0.05, 0.0, 0.45, 0.55)
		_tp(shell, "pulse", 0.6, 0.0, 0.3, 1.0)
		parts.append(ba)
		i += 1
	for k in 4:
		var right = k % 2 == 1
		pj.after(0.2 + k * 0.12, func():
			if pj.live(c):
				_gold_drip(pj, pj.hand_pos(c, right)))
	if c is Player:
		Buffs.add("nenkin_yoroi", 15.0, {"armor": 0.68, "_name": "Altın Zırh", "_desc": "yapışkan altın zırh: gelen hasar çok azalır"})
	pj.after(14.5, func():
		for s2 in shells:
			if is_instance_valid(s2) and s2.is_inside_tree():
				_emit(pj, {"kind": 3.0, "n": 10, "life": 0.7, "vmin": 0.5, "vmax": 2.5, "g": Vector3(0, -9.0, 0), "smin": 0.05, "smax": 0.12, "r": 0.15,
					"curve": "flat", "cols": [Color(0.95, 0.76, 0.38, 1.0), Color(0.8, 0.56, 0.22, 1.0), Color(0.6, 0.4, 0.15, 0.0)]}, s2.global_position)
				_tp(s2, "fade", 1.0, 0.0, 0.45))
	pj.after(15.0, func():
		for pp in parts:
			if is_instance_valid(pp):
				pp.queue_free())
	Sfx.play("clink", c.global_position, 0.8)


static func _gold_drip(pj: PathJutsu, from: Vector3) -> void:
	var d = _mi(_blob_mesh(3), "gold", {"wet": 1.0, "ow": 0.02})
	pj.scene_add(d, from)
	d.scale = Vector3(0.05, 0.09, 0.05)
	var g = pj.gp(from)
	var tw = d.create_tween()
	tw.tween_property(d, "global_position", g + Vector3.UP * 0.02, maxf(0.12, sqrt(maxf(0.0, from.y - g.y) / 4.9))).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(d, "scale", Vector3(0.22, 0.025, 0.22) * randf_range(0.8, 1.3), 0.08)
	tw.tween_method(func(v: float): d.set_instance_shader_parameter("wet", v), 1.0, 0.0, 0.5)
	tw.tween_interval(4.0)
	tw.tween_method(func(v: float): d.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.6)
	tw.tween_callback(d.queue_free)


# ================================================================== Jujutsu: Shiji Hyōketsu
## Ref (Hidan): ayakla yere kanla çizilen daire + içinde üçgen. Daire uçtan uca çizilir, sonra üçgenin üç kenarı sırayla; çizgide
## ıslak parıltı ve yer yer sıçramış kan. Kullanıcıdan hedefe sarkan ince kan bağı (lanet bağı). Her acı nabzında çember kızarır,
## içinden halka dalgası geçer, iki bedenden kan fışkırır ve hedefin göğsünü kan halkası sıkar.
static func jujutsu_shiji_hyoketsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	# anime: lanet ancak hedefin kanı alınmışsa (tırpan/kazık) kurulur; çemberdeyken sana gelen her acı ona da gelir
	if c is Player and (tt == null or not tt.has_meta("jashin_kan") or Time.get_ticks_msec() - int(tt.get_meta("jashin_kan")) > 30000):
		Hud.msg("Lanet için önce hedefin kanını almalısın: Sanjin no Ōgama ya da Kaeri Yari ile yarala (30 sn).", Color(1, 0.5, 0.45))
		return
	pj.busy(c, 2.0)
	if tt == null:
		return
	if c is Player:
		c.set_meta("jashin_link", [tt, Time.get_ticks_msec() + 12000])
		Hud.msg("Lanet bağı kuruldu: 12 sn boyunca sana gelen her acı hedefe de gelir.", Color(0.9, 0.3, 0.3), 4.0)
	var at = pj.gp(c.global_position)
	var circ = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(4.0, 4.0)
	circ.mesh = pm
	circ.material_override = _plain_mat("ritual", RITUAL_SHADER)
	circ.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(circ, at + Vector3.UP * 0.03)
	circ.set_instance_shader_parameter("seed", randf() * 10.0)
	circ.set_instance_shader_parameter("draw", 0.0)
	_tp(circ, "draw", 0.0, 1.0, 0.5)
	_rope(pj, _follow(c, Vector3.UP * 1.1), _follow(tt, Vector3.UP * 1.1), 0.022, 2.2, {"tint": BLOOD_C, "olc": Color(0.2, 0.0, 0.0), "wet": 1.0, "sag": 0.3, "grow": 0.4})
	for k in 3:
		pj.after(0.5 + k * 0.45, func():
			if not (pj.live(c) and pj.live(tt)):
				return
			if is_instance_valid(circ):
				_tp(circ, "pulse", 1.0, 0.0, 0.4)
			_blood(pj, c.global_position + Vector3.UP * 1.2, 8, 4.0)
			_blood(pj, tt.global_position + Vector3.UP * 1.2, 16, 6.5)
			_curse_ring(pj, tt)
			tt.take_hit(pj.inf(c, "jujutsu_shiji_hyoketsu", 1.6, {"knock": 0.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.08}))
			if c is Player:
				c.hp = maxf(1.0, c.hp - c.max_hp * 0.03))
	var ct = circ.create_tween()
	ct.tween_interval(2.2)
	ct.tween_method(func(v: float): circ.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.35)
	ct.tween_callback(circ.queue_free)
	Sfx.play("blade", c.global_position, 0.5)


static func _curse_ring(pj: PathJutsu, tt: Node3D) -> void:
	var r = _mi(_ring_mesh(), "toon", {"tint": Color(0.72, 0.05, 0.06), "olc": Color(0.15, 0.0, 0.0), "ow": 0.06, "wet": 1.0})
	pj.scene_add(r, tt.global_position + Vector3.UP * 1.1)
	r.scale = Vector3.ONE * 0.95
	var tw = r.create_tween()
	tw.tween_property(r, "scale", Vector3.ONE * 0.36, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(v: float): r.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.15)
	tw.tween_callback(r.queue_free)


# ================================================================== Jiongu
## Ref (Kakuzu uzun menzil): bedenden her yöne dalgalanan kalın kara iplik demetleri (burgulu üç alt demet, açık gri lif çizgileri,
## uçta saçılan lifler). Hazırlıkta dikiş yerlerinden kopuk kara lif kırıntıları fırlar. Yakalanan her hedefe ayrı bir demet uzanır
## ve gövdesine bobin gibi dolanıp sıkar; kan fışkırır.
static func jiongu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var targets = pj.enemies_near(c, c.global_position, 12.0)
	var tt = pj.tg(c, t, 12.0)
	if tt and not targets.has(tt):
		targets.append(tt)
	var t0 = Game.now()
	for k in 22:   # ref: bedenden her yöne dalgalanarak uzanan kalın kara iplik dokunaçları (koni değil)
		var a = k * TAU / 22.0 + randf_range(-0.1, 0.1)
		var L = randf_range(3.5, 6.0)
		var dir = Vector3(cos(a), randf_range(-0.3, 0.7), sin(a)).normalized()
		var base_h = randf_range(0.8, 1.6)
		_tentacle(pj, c, base_h, dir, L, randf_range(0.12, 0.18), t0, randf_range(0.12, 0.25), k)
	_emit(pj, {"kind": 5.0, "n": 18, "life": 0.6, "vmin": 2.0, "vmax": 5.0, "g": Vector3(0, -4.0, 0), "smin": 0.15, "smax": 0.3, "r": 0.3,
		"cols": [Color(0.15, 0.15, 0.17, 1.0), Color(0.3, 0.3, 0.33, 1.0), Color(0.3, 0.3, 0.33, 0.0)]}, c.global_position + Vector3.UP * 1.2)
	for e in targets:
		pj.after(0.25, func():
			if not (pj.live(c) and pj.live(e)):
				return
			_grab(pj, c, e)
			_blood(pj, e.global_position + Vector3.UP, 7, 4.5)
			pj.st(e, "bind", 0.9)
			e.take_hit(pj.inf(c, "jiongu", 1.2, {"knock": 2.0, "kind": "heavy", "bleed": 4.0}))
			pj.heal(c, c.max_hp * 0.06))
	Sfx.play("blade", c.global_position, 0.6)


static func _tentacle(pj: PathJutsu, c: Node3D, base_h: float, dir: Vector3, L: float, w: float, t0: float, amp: float, k: int) -> void:
	var mi = _mi(_bundle_mesh(k % 3), "fiber", {"wamp": amp / w, "wfreq": randf_range(0.8, 1.6)})
	mi.extra_cull_margin = 4.0
	pj.get_tree().current_scene.add_child(mi)
	var fc = _follow(c, Vector3.ZERO)
	var upd = func(_i, _k):
		if not is_instance_valid(mi):
			return
		var u = Game.now() - t0
		var ext = clampf(u / 0.25, 0.0, 1.0) * (1.0 - clampf((u - 1.1) / 0.3, 0.0, 1.0))
		var b: Vector3 = fc.call() + Vector3.UP * base_h
		_span(mi, b, b + dir * L * maxf(0.05, ext), w)
	upd.call(0, 0.0)
	pj.every(1.4, 1.0 / 30.0, upd, func():
		if is_instance_valid(mi):
			mi.queue_free())


static func _grab(pj: PathJutsu, c: Node3D, e: Node3D) -> void:
	var w = 0.16
	var g = _mi(_bundle_mesh(3), "fiber", {"wamp": 0.6, "wfreq": 1.2, "reveal": 0.0})
	g.extra_cull_margin = 3.0
	pj.get_tree().current_scene.add_child(g)
	var coil = _mi(_coil_mesh(), "fiber", {"ow": 0.15, "reveal": 0.0})
	pj.scene_add(coil, e.global_position)
	var fa = _follow(c, Vector3.UP * 1.2)
	var fb = _follow(e, Vector3.UP * 1.0)
	var fe = _follow(e, Vector3.ZERO)
	var t0 = Game.now()
	var upd = func(_i, _k):
		var u = Game.now() - t0
		if is_instance_valid(g):
			_span(g, fa.call(), fb.call(), w)
			g.set_instance_shader_parameter("reveal", clampf(u / 0.12, 0.0, 1.0) * 1.01)
		if is_instance_valid(coil):
			coil.global_position = fe.call()
			var s = lerpf(1.35, 1.0, clampf((u - 0.1) / 0.15, 0.0, 1.0))
			coil.scale = Vector3(s, 1.0, s)
			coil.rotation.y += 0.05
			coil.set_instance_shader_parameter("reveal", clampf((u - 0.06) / 0.2, 0.0, 1.0) * 1.01)
	upd.call(0, 0.0)
	pj.every(0.9, 1.0 / 30.0, upd, func():
		if is_instance_valid(g):
			g.queue_free()
		if is_instance_valid(coil):
			_fade_free(coil, 0.0, 0.2))


# ================================================================== Nan no Kaizō
## Ref (lastik beden, uzuvlar uzayıp dolanır): kol ve bacak kemikleri boyunca omuzdan uca doğru akan ten rengi esneme halkaları
## (uzuv gerçekten uzar: poz katmanı), ellerde "boing" esneme yayları. Süre boyunca deri ara ara dalgalanır.
static func nan_no_kaizo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var bones = ["LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]
	var atts = []
	for i in bones.size():
		var ba = pj.bone_attach(c, bones[i])
		if ba == null:
			continue
		atts.append(ba)
		_skin_wave(ba, (i >> 1) * 0.06, 1.0)
	if c.get("model") and c.model.overlay:
		var ov = c.model.overlay
		var tw = c.create_tween()
		tw.tween_property(ov, "limb_scale", 1.35, 0.3).set_trans(Tween.TRANS_ELASTIC)
		pj.after(15.0, func():
			if is_instance_valid(c) and c.get("model") and c.model.overlay:
				c.model.overlay.limb_scale = 1.0)
	pj.after(0.18, func():
		if pj.live(c):
			_stretch_arcs(pj, c))
	var tick = func(_i, _k):
		for b2 in atts:
			if is_instance_valid(b2) and randf() < 0.5:
				_skin_wave(b2, 0.0, 0.55)
	var fin = func():
		for b2 in atts:
			if is_instance_valid(b2):
				b2.queue_free()
	pj.every(15.0, 2.5, tick, fin)
	if c is Player:
		Buffs.add("nan_no_kaizo", 15.0, {"reach": 1.8, "_name": "Lastik Beden", "_desc": "uzuvlar uzadı: yakın dövüş menzili +%80"})
	Sfx.play("whoosh", c.global_position, 0.7)


static func _skin_wave(ba: Node3D, delay: float, k: float) -> void:
	for j in 2:
		var r = _mi(_ring_mesh(), "toon", {"tint": SKIN_C, "olc": Color(0.45, 0.25, 0.18), "ow": 0.08})
		ba.add_child(r)
		r.position = Vector3(0, 0.02, 0)
		r.scale = Vector3.ONE * 0.01
		var tw = r.create_tween()
		tw.tween_interval(delay + j * 0.09)
		tw.tween_property(r, "scale", Vector3.ONE * 0.1 * k, 0.04)
		tw.tween_property(r, "position:y", 0.3, 0.35).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(r, "scale", Vector3.ONE * 0.14 * k, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float): r.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.18)
		tw.tween_callback(r.queue_free)


static func _stretch_arcs(pj: PathJutsu, c: Node3D) -> void:
	var cam = pj.get_viewport().get_camera_3d()
	for right in [true, false]:
		var hp = pj.hand_pos(c, right)
		for j in 3:
			var a = _mi(_arc_mesh(), "toon", {"tint": Color(1, 0.97, 0.92), "olc": Color(0.25, 0.15, 0.12), "ow": 0.1})
			pj.scene_add(a, hp)
			if cam and cam.global_position.distance_to(hp) > 0.2:
				a.look_at(cam.global_position, Vector3.UP)
			a.rotate_object_local(Vector3(0, 0, 1), randf() * TAU)
			var s = 0.18 + j * 0.1
			a.scale = Vector3.ONE * s * 0.6
			var tw = a.create_tween()
			tw.tween_property(a, "scale", Vector3.ONE * s * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(v: float): a.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.22)
			tw.tween_callback(a.queue_free)


# ================================================================== Kumo Shibari
## Ref (Kumo Shibari): elden yapışkan bir iplikle bağlı, dönen küçük örümcek ağı fırlar; çarptığı yerde ışınsal + çokgen halkalı
## büyük ağ geri sekerek açılır (göbeği hedefin itişiyle çukur), kenarlarından yere bağ telleri iner; yakalanan hedefe ipek dolanır.
static func kumo_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.5)
	var from = pj.hand_pos(c, true)
	var ball = Node3D.new()
	ball.add_child(_mi(_orb_web_mesh(0.5, 8, 4, 0.02, 0.0, 1), "silk", {"ow": 0.01}))
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 30.0, ball, pj.inf(c, "kumo_shibari", 0.3, {"knock": 0.0, "kind": "light"}), tt, false, 1.0, func(p, h):
		var away = (p - c.global_position).normalized() if is_instance_valid(c) else Vector3.FORWARD
		if away.length() < 0.1:
			away = Vector3.FORWARD
		var w = _mi(_orb_web_mesh(1.8, 12, 7, 0.028, 0.35, 2), "silk", {"wet": 1.0})
		pj.get_tree().current_scene.add_child(w)
		w.global_position = p
		_aim(w, away)
		var locs = []
		for k in 4:
			var a = (k + 0.5) * TAU / 4.0
			locs.append(Vector3(cos(a), sin(a), 0.0) * 1.7)
		_pin(pj, w, locs, 3.3, 1.0)
		w.scale = Vector3.ONE * 0.15
		var tw = w.create_tween()
		tw.tween_property(w, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.84)
		tw.tween_property(w, "scale", Vector3.ONE * 0.01, 0.3)
		tw.tween_callback(w.queue_free)
		_fluff(pj, p, 10)
		if h and pj.live(h):
			pj.st(h, "bind", 3.0)
			Combat.popup_text(h.global_position + Vector3.UP * 2.3, "Ağa takıldı!", PathJutsu.WEB)
			_wrap(pj, h, 3.0))
	ball.create_tween().set_loops().tween_property(ball, "rotation:z", TAU, 0.4).from(0.0)
	_rope(pj, _hand_fn(pj, c, true), _follow(pr, Vector3.ZERO), 0.018, 1.0, {"sag": 0.15})
	Sfx.play("whoosh", from, 1.6, 0.5)


# ================================================================== Kumo Nenkin
## Ref (Kidōmaru): ağızdan altın iplikler ellere akar, elde pürüzlü kısa bir altın yaya döner (kabzadan uçlara akarak, ıslaktan
## donuğa sertleşir; ipek kirişi). Kirişe tırtıklı yaprak uçlu, lekeli altın ok takılır, gerilir ve fırlar (kiriş titrer);
## yolunda altın pulları saçar, çarptığı yerde altın kıymıklar dağılıp düşer.
static func kumo_nenkin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 0.8)
	var from = pj.hand_pos(c, true)
	var fm = _mouth_fn(pj, c)
	for right in [true, false]:
		_rope(pj, fm, _hand_fn(pj, c, right), 0.03, 0.35, {"kind": "gold", "wet": 1.0, "sag": 0.12, "grow": 0.12, "ow": 0.25})
	_bow(pj, c, tt, 0.8, false, 0.8, 0.35)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var arrow = Node3D.new()
		arrow.add_child(_mi(_jag_arrow_mesh(), "gold", {"ow": 0.02}))
		var tr = _parts({"kind": 3.0, "n": 24, "life": 0.35, "vmin": 0.2, "vmax": 0.8, "g": Vector3(0, -3.0, 0), "smin": 0.04, "smax": 0.08, "r": 0.06,
			"one_shot": false, "burst": 0.0, "curve": "flat", "cols": [Color(1.0, 0.85, 0.45, 1.0), Color(0.85, 0.6, 0.22, 1.0), Color(0.7, 0.45, 0.15, 0.0)]})
		arrow.add_child(tr)
		tr.emitting = true
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 60.0, arrow, pj.inf(c, "kumo_nenkin", 1.4, {"knock": 8.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.06}), null, true, 1.0, func(p, _h):
			_gold_burst(pj, p))
		Sfx.play("whoosh", from, 1.8, 0.6))


## Elde altın yay (sol el, nişan yönüne bakar): kabzadan uçlara akarak oluşur ve sertleşir; ipek kiriş geriye çekilir, okta takılı ok
## görünür; bırakışta kiriş titreyerek düzleşir. dur sonunda söner.
static func _bow(pj: PathJutsu, c: Node3D, tt: Node3D, R: float, big: bool, dur: float, rel_t: float) -> void:
	var root = Node3D.new()
	pj.scene_add(root, pj.hand_pos(c, false))
	var bow = _mi(_bow_mesh(R, big), "gold", {"wet": 1.0, "reveal": 0.0, "ow": 0.015})
	root.add_child(bow)
	var s1 = _mi(_unit_tube(6, 4), "silk", {"ow": 0.3, "near_d": 0.8})
	var s2 = _mi(_unit_tube(6, 4), "silk", {"ow": 0.3, "near_d": 0.8})
	root.add_child(s1)
	root.add_child(s2)
	var nk = _mi(_drill_arrow_mesh() if big else _jag_arrow_mesh(), "gold", {"ow": 0.015})
	root.add_child(nk)
	var tail = 1.6 if big else 0.55
	var tip_u = _bow_pt(R, 1.0, 1.0)
	var tip_d = _bow_pt(R, 1.0, -1.0)
	var fl = _hand_fn(pj, c, false)
	var t0 = Game.now()
	var form = rel_t * 0.55
	_tp(bow, "reveal", 0.0, 1.01, form)
	_tp(bow, "wet", 1.0, 0.0, rel_t * 0.4, form)
	var upd = func(_i, _k):
		if not is_instance_valid(root):
			return
		var hp: Vector3 = fl.call()
		root.global_position = hp
		var d = pj.aim_at(c, tt if is_instance_valid(tt) else null, hp) if pj.live(c) else -root.global_transform.basis.z
		_aim(root, d)
		var u = Game.now() - t0
		var pull = 0.0
		if u < rel_t:
			pull = clampf((u - form) / maxf(rel_t - form, 0.05), 0.0, 1.0)
		var nz = tip_u.z + 0.03 + R * 0.45 * pull
		if u >= rel_t:
			nz = tip_u.z + R * 0.08 * sin((u - rel_t) * 60.0) * exp(-(u - rel_t) * 12.0)
		var nock = Vector3(0, 0, nz)
		var vis = u > form * 0.8
		s1.visible = vis
		s2.visible = vis
		if vis:
			_span_local(s1, tip_u, nock, 0.012 * maxf(R, 0.8))
			_span_local(s2, tip_d, nock, 0.012 * maxf(R, 0.8))
		nk.visible = vis and u < rel_t
		nk.position = nock - Vector3(0, 0, tail)
	upd.call(0, 0.0)
	pj.every(dur, 1.0 / 30.0, upd, func():
		if is_instance_valid(root):
			_fade_free(root, 0.0, 0.15))


static func _gold_burst(pj: PathJutsu, p: Vector3) -> void:
	for k in 6:
		var s = _mi(_shard_mesh(k % 3), "gold", {"ow": 0.02})
		pj.scene_add(s, p)
		var d = Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized()
		_aim(s, d)
		s.scale = Vector3.ONE * 0.1
		var tw = s.create_tween()
		tw.tween_property(s, "scale", Vector3.ONE * randf_range(0.7, 1.1), 0.06)
		tw.parallel().tween_property(s, "global_position", p + d * randf_range(0.4, 0.8), 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "global_position", pj.gp(p + d) + Vector3.UP * 0.05, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_method(func(v: float): s.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
		tw.tween_callback(s.queue_free)
	_emit(pj, {"kind": 3.0, "n": 16, "life": 0.6, "vmin": 2.0, "vmax": 6.0, "g": Vector3(0, -9.0, 0), "smin": 0.06, "smax": 0.14, "curve": "flat",
		"cols": [Color(1.0, 0.9, 0.55, 1.0), Color(0.9, 0.62, 0.22, 1.0), Color(0.7, 0.45, 0.15, 0.0)]}, p)


# ================================================================== Kumo Senkyū: Suzaku
## Ref (Kidōmaru savaş yayı): sıvı altın damlaları sol ele toplanır, dev yay kabzadan uçlara akarak oluşur (pürüzlü düğümler, sırt
## dikenleri), uzun matkap uçlu ok kirişe takılıp gerilir. Bırakışta ok kendi ekseninde burgu gibi döner, yay elinden oka gergin
## ipek kılavuz ipliği uzanır (kanon: oku iple yönlendirir), ayakların dibinde toz halkası kalkar. Çarpmada ok ucu ileri doğru açılan
## dev altın kıymık yelpazesine yarılır; yere yakınsa uçuş yönünde altın kenarlı yarıklar açar.
static func kumo_senkyu_suzaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 40.0)
	_bow(pj, c, tt, 1.4, true, 1.2, 0.6)
	_gold_gather(pj, c)
	pj.after(0.6, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var ad = pj.aim_at(c, tt, from)
		var arrow = Node3D.new()
		var am = _mi(_drill_arrow_mesh(), "gold", {"ow": 0.015})
		arrow.add_child(am)
		am.create_tween().set_loops().tween_property(am, "rotation:z", TAU, 0.25).from(0.0)
		var pr = pj.shot(c, from, ad, 70.0, arrow, pj.inf(c, "kumo_senkyu_suzaku", 2.6, {"knock": 20.0, "kind": "heavy", "bleed": 5.0, "hitstop": 0.12}), null, true, 1.0, func(p, _h):
			_gold_split(pj, p, ad))
		pr.radius = 0.6
		_rope(pj, _hand_fn(pj, c, false), _follow(pr, Vector3.ZERO), 0.014, 1.0, {})
		_emit(pj, {"kind": 1.0, "n": 18, "life": 0.7, "ring": 0.7, "dir": Vector3.UP, "spread": 70.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -1.0, 0), "damp": 2.0,
			"smin": 0.4, "smax": 0.8, "curve": "grow", "cols": [Color(0.75, 0.66, 0.52, 0.8), Color(0.7, 0.62, 0.5, 0.5), Color(0.7, 0.62, 0.5, 0.0)]}, pj.gp(c.global_position) + Vector3.UP * 0.1)
		Sfx.play("whoosh", from, 1.2))


static func _gold_gather(pj: PathJutsu, c: Node3D) -> void:
	var hp = pj.hand_pos(c, false)
	for k in 10:
		var d = _mi(_blob_mesh(3), "gold", {"wet": 1.0, "ow": 0.0})
		var o = Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized() * randf_range(0.9, 1.6)
		pj.scene_add(d, hp + o)
		d.scale = Vector3.ONE * 0.06
		var tw = d.create_tween()
		tw.tween_interval(k * 0.025)
		tw.tween_property(d, "global_position", hp, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(d.queue_free)


static func _gold_split(pj: PathJutsu, p: Vector3, ad: Vector3) -> void:
	var fwd = ad.normalized() if ad.length() > 0.01 else Vector3.FORWARD
	var sd = fwd.cross(Vector3.UP).normalized()
	if sd.length() < 0.1:
		sd = Vector3.RIGHT
	var up = sd.cross(fwd).normalized()
	for k in 9:
		var a = k * TAU / 9.0 + randf_range(-0.2, 0.2)
		var d = (fwd * 0.9 + (sd * cos(a) + up * sin(a)) * randf_range(0.7, 1.1)).normalized()
		var s = _mi(_shard_mesh(2), "gold", {"ow": 0.02})
		pj.scene_add(s, p)
		_aim(s, d)
		s.scale = Vector3.ONE * 0.2
		var tw = s.create_tween()
		tw.tween_property(s, "scale", Vector3.ONE * randf_range(1.6, 2.4), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "global_position", p + d * 0.5, 0.08)
		tw.tween_interval(0.5)
		tw.tween_method(func(v: float): s.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.35)
		tw.tween_callback(s.queue_free)
	_emit(pj, {"kind": 3.0, "n": 26, "life": 0.8, "dir": fwd, "spread": 60.0, "vmin": 4.0, "vmax": 10.0, "g": Vector3(0, -9.0, 0), "smin": 0.08, "smax": 0.18, "curve": "flat",
		"cols": [Color(1.0, 0.9, 0.55, 1.0), Color(0.9, 0.62, 0.22, 1.0), Color(0.7, 0.45, 0.15, 0.0)]}, p)
	var g = pj.gp(p)
	if p.y - g.y < 1.6:
		var ff = Vector3(fwd.x, 0, fwd.z).normalized() if Vector3(fwd.x, 0, fwd.z).length() > 0.05 else Vector3.FORWARD
		for k in 3:
			var dir = ff.rotated(Vector3.UP, (k - 1) * 0.28)
			var L = randf_range(2.5, 4.0)
			var root = Node3D.new()
			pj.scene_add(root, g + Vector3.UP * 0.03)
			var pts = []
			for i in 6:
				pts.append(dir * L * float(i) / 5.0 + dir.cross(Vector3.UP) * randf_range(-0.08, 0.08))
			var gg = G.new()
			gg.tube(pts, [0.14, 0.12, 0.1, 0.07, 0.04, 0.0], 4, Color(0.18, 0.12, 0.07), {"flat": 0.12})
			var slit = _mi(gg.build(), "toon", {"ow": 0.0})
			root.add_child(slit)
			var g2 = G.new()
			g2.tube(pts, [0.2, 0.17, 0.14, 0.1, 0.06, 0.0], 4, WHITE_V, {"flat": 0.08})
			var rim = _mi(g2.build(), "gold", {"ow": 0.0})
			root.add_child(rim)
			rim.position = Vector3.DOWN * 0.01
			root.scale = Vector3(1, 1, 1) * 0.2
			var tw = root.create_tween()
			tw.tween_property(root, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
			_fade_free(root, 2.5, 0.6)
		_emit(pj, {"kind": 1.0, "n": 14, "life": 0.8, "dir": Vector3.UP, "spread": 50.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -1.0, 0), "damp": 2.0, "r": 0.6,
			"smin": 0.5, "smax": 1.0, "curve": "grow", "cols": [Color(0.7, 0.6, 0.45, 0.8), Color(0.65, 0.56, 0.44, 0.5), Color(0.65, 0.56, 0.44, 0.0)]}, g + Vector3.UP * 0.2)


# ================================================================== Kumo Sōkei
## Ref (Web Area): avuçlar yere değer, parmak uçlarından yerde ince gergin ipek teller yelpaze gibi fırlar; önde yerde ışınsal +
## halkalı, çiyli (yapışkan boncuk parıltılı) geniş ağ hızla yayılır, yayılma sonunda bir parıltı geçer. Süre bitince toplanır.
static func kumo_sokei(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var at = pj.gp(c.global_position + pj.fwd(c, t) * 4.0)
	var w = _mi(_orb_web_mesh(5.0, 18, 9, 0.03, 0.0, 3), "silk", {"wet": 1.0, "ow": 0.012})
	pj.get_tree().current_scene.add_child(w)
	w.global_position = at + Vector3.UP * 0.05
	w.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
	w.scale = Vector3.ONE * 0.05
	var tw = w.create_tween()
	tw.tween_property(w, "scale", Vector3.ONE, 0.4)
	tw.tween_interval(10.0)
	tw.tween_property(w, "scale", Vector3.ONE * 0.05, 0.3)
	tw.tween_callback(w.queue_free)
	_tp(w, "pulse", 0.5, 0.0, 0.4, 0.4)
	var side = c.face_dir().cross(Vector3.UP).normalized()
	for k in 10:
		var right = k % 2 == 0
		var off = side * (float(int(k / 2.0)) - 2.0) * 0.025
		var ang = k * 0.628 + 0.3
		var end = at + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(3.0, 4.6) + Vector3.UP * 0.05
		var hf = _hand_fn(pj, c, right)
		var fa = func() -> Vector3:
			return hf.call() + off
		var fb = func() -> Vector3:
			return end
		_rope(pj, fa, fb, 0.011, 0.6, {"grow": 0.25})
	pj.every(10.4, 0.25, func(_i, _k):
		for e in pj.enemies_near(c, at, 5.0):
			pj.st(e, "bind", 0.5)
			if randf() < 0.1:
				Combat.popup_text(e.global_position + Vector3.UP * 2.2, "Ağa bastı!", PathJutsu.WEB), Callable())
	Sfx.play("whoosh", at, 1.3)


# ================================================================== Kumo Sōka
## Ref (ağ çiçekleri): üç kâse biçimli düzensiz hücreli ağ, dönerek açılarak uçar; düştüğü yerde yere taç yapraklı çiçek ağı olarak
## yayılıp geri seker, ipek tüyleri savrulur.
static func kumo_soka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.7)
	pj.anim(c, "throw", 1.3)
	var from = pj.hand_pos(c, true)
	for k in 3:
		pj.after(k * 0.12, func():
			if not pj.live(c):
				return
			var w = Node3D.new()
			var cup = _mi(_cup_mesh(0.5, 0.35, 3, 8, 0.02, 0, k), "silk", {"ow": 0.01})
			w.add_child(cup)
			cup.create_tween().set_loops().tween_property(cup, "rotation:z", TAU, 0.5).from(0.0)
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, (k - 1) * 0.15), 26.0, w, pj.inf(c, "kumo_soka", 0.3, {"knock": 0.0, "kind": "light"}), null, false, 1.1, func(p, _h):
				var big = _mi(_cup_mesh(2.4, -0.12, 5, 10, 0.035, 5, 10 + k), "silk", {"wet": 1.0, "ow": 0.012})
				pj.get_tree().current_scene.add_child(big)
				big.global_position = pj.gp(p) + Vector3.UP * 0.05
				big.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
				big.scale = Vector3.ONE * 0.3
				var tw = big.create_tween()
				tw.tween_property(big, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_interval(3.3)
				tw.tween_property(big, "scale", Vector3.ONE * 0.01, 0.3)
				tw.tween_callback(big.queue_free)
				_fluff(pj, pj.gp(p) + Vector3.UP * 0.3, 8)
				if not is_instance_valid(c):
					return
				for e in pj.enemies_near(c, p, 2.8):
					pj.st(e, "bind", 3.5)
					Combat.popup_text(e.global_position + Vector3.UP * 2.3, "Ağa takıldı!", PathJutsu.WEB))
			w.create_tween().tween_property(w, "scale", Vector3.ONE * 3.0, 0.5))
	Sfx.play("whoosh", from, 1.1)


# ================================================================== Hiden: Rinpungakure
## Ref (Fū / pul tozu): ağızdan ışıltılı pul tozu püskürür; önündeki alanda yanıp sönen yanardöner pul parıltıları süzülür ve hava
## beyazlaşır (birkaç yumuşak, düşük yoğunluklu pus lekesi — kameraya yaklaşınca söner, ekranı kapatmaz). Bitince pullar yavaşça çöker.
static func hiden_rinpungakure_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var at = c.global_position + pj.fwd(c, t) * 4.0
	var glit = Color(0.6, 1.0, 0.6)
	var mo = pj._mouth_pos(c)
	var to = at + Vector3.UP * 1.2 - mo
	_emit(pj, {"kind": 0.0, "n": 70, "life": 0.9, "dir": to.normalized() if to.length() > 0.01 else Vector3.FORWARD, "spread": 14.0, "vmin": 4.0, "vmax": 8.0,
		"g": Vector3(0, -0.3, 0), "damp": 3.0, "smin": 0.05, "smax": 0.13, "r": 0.06, "burst": 0.0,
		"cols": [Color(1, 1, 1, 1), glit, Color(0.95, 0.8, 1.0, 0.9), Color(glit.r, glit.g, glit.b, 0.0)]}, mo)
	var cloud = _parts({"kind": 0.0, "n": 160, "life": 1.4, "box": Vector3(4.0, 1.3, 4.0), "vmin": 0.1, "vmax": 0.5, "g": Vector3(0, -0.25, 0),
		"smin": 0.06, "smax": 0.16, "one_shot": false, "burst": 0.0, "near": 2.5,
		"cols": [Color(1, 1, 1, 0.0), Color(0.85, 1.0, 0.85, 1.0), Color(0.8, 0.9, 1.0, 1.0), Color(1.0, 0.85, 0.95, 0.9), Color(glit.r, glit.g, glit.b, 0.0)]})
	pj.scene_add(cloud, at + Vector3.UP * 1.75)
	cloud.emitting = true
	pj.free_after(7.0, cloud)
	_emit(pj, {"kind": 4.0, "n": 9, "life": 4.6, "box": Vector3(3.5, 0.8, 3.5), "vmin": 0.05, "vmax": 0.2, "g": Vector3.ZERO, "smin": 2.5, "smax": 4.0,
		"burst": 0.85, "near": 6.0, "curve": "flat",
		"cols": [Color(0.92, 1.0, 0.94, 0.0), Color(0.92, 1.0, 0.94, 0.2), Color(0.95, 0.98, 1.0, 0.2), Color(0.92, 1.0, 0.94, 0.0)]}, at + Vector3.UP * 1.4)
	var settle = {"kind": 0.0, "n": 40, "life": 1.6, "box": Vector3(4.0, 1.0, 4.0), "vmin": 0.0, "vmax": 0.2, "g": Vector3(0, -1.2, 0), "smin": 0.05, "smax": 0.1,
		"burst": 0.6, "near": 2.5, "curve": "flat", "cols": [Color(1, 1, 1, 1), glit, Color(glit.r, glit.g, glit.b, 0.0)]}
	var tick = func(_i, _k):
		for e in pj.enemies_near(c, at, 6.0):
			pj.st(e, "slow", 0.5)
			if e.has_method("lose_target"):
				e.lose_target(1.0)
	var fin = func():
		if is_instance_valid(cloud):
			cloud.emitting = false
		_emit(pj, settle, at + Vector3.UP * 1.6)
	pj.every(4.0, 0.15, tick, fin)
	Sfx.play("wind", at, 1.5, 0.5)


# ================================================================== Hijutsu: Ishibari
## Ref (taş iğneler + mavi chakra): kolun çevresinde iki mavi chakra şeridi sarmal çizerek ele toplanır; silindirik başlıklı altıgen taş
## iğneler, çevrelerinde dönen mavi chakra sarmalıyla ve arkalarında mavi şerit izle fırlar. Çarpınca taş kırıntısı + mavi kıvılcım;
## yere / duvara saplanan iğne bir süre kalır, sonra ufalanır.
static func hijutsu_ishibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.5)
	var from = pj.hand_pos(c, true)
	_chakra_wind(pj, c)
	for k in 10:
		pj.after(0.1 + k * 0.035, func():
			var nd = Node3D.new()
			nd.add_child(_mi(_needle_mesh(k % 3), "toon", {"ow": 0.012}))
			var coil = _mi(_needle_coil_mesh(), "toon", {"tint": Color(0.55, 0.78, 1.0), "pulse": 0.35, "ow": 0.0})
			nd.add_child(coil)
			coil.create_tween().set_loops().tween_property(coil, "rotation:z", TAU, 0.15).from(0.0)
			var d = pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.06, 0.06))
			var pr = pj.shot(c, from, d, 50.0, nd, pj.inf(c, "hijutsu_ishibari", 0.12, {"knock": 0.6, "kind": "light", "bleed": 1.0}), null, false, 0.8, func(p, h):
				_needle_hit(pj, p, d, h))
			_ribbon(pj, pr, 0.06, 0.22, Color(0.45, 0.7, 1.0)))
	Sfx.play("kunai", from, 1.7, 0.4)


static func _needle_hit(pj: PathJutsu, p: Vector3, d: Vector3, h) -> void:
	_emit(pj, {"kind": 3.0, "n": 8, "life": 0.45, "vmin": 1.5, "vmax": 4.0, "g": Vector3(0, -10.0, 0), "smin": 0.04, "smax": 0.08, "curve": "flat",
		"cols": [Color(0.75, 0.76, 0.8, 1.0), Color(0.55, 0.56, 0.6, 1.0), Color(0.5, 0.5, 0.55, 0.0)]}, p)
	_emit(pj, {"kind": 6.0, "n": 6, "life": 0.25, "vmin": 0.5, "vmax": 2.0, "g": Vector3.ZERO, "smin": 0.15, "smax": 0.3,
		"cols": [Color(1, 1, 1, 1), Color(0.5, 0.75, 1.0, 0.9), Color(0.4, 0.6, 1.0, 0.0)]}, p)
	if h == null:
		var s = Node3D.new()
		s.add_child(_mi(_needle_mesh(0), "toon", {"ow": 0.012}))
		pj.scene_add(s, p - d.normalized() * 0.12)
		_aim(s, d)
		var grit = {"kind": 3.0, "n": 6, "life": 0.5, "vmin": 0.3, "vmax": 1.2, "g": Vector3(0, -8.0, 0), "smin": 0.03, "smax": 0.06, "curve": "flat",
			"cols": [Color(0.7, 0.7, 0.74, 1.0), Color(0.5, 0.5, 0.55, 0.0)]}
		var crumble = func():
			if is_instance_valid(s) and s.is_inside_tree():
				_emit(pj, grit, s.global_position)
		s.create_tween().tween_callback(crumble).set_delay(1.2)
		_fade_free(s, 1.2, 0.25)


static func _chakra_wind(pj: PathJutsu, c: Node3D) -> void:
	var hf = _hand_fn(pj, c, true)
	for j in 2:
		var sp = Node3D.new()
		pj.scene_add(sp, hf.call())
		var t0 = Game.now()
		var ph = j * PI
		var tick = func(_i, _k):
			if not is_instance_valid(sp):
				return
			var u = clampf((Game.now() - t0) / 0.4, 0.0, 1.0)
			var r = lerpf(0.7, 0.05, u)
			var a = ph + u * 9.0
			var fc = c.face_dir() if is_instance_valid(c) else Vector3.FORWARD
			var sd = fc.cross(Vector3.UP).normalized()
			sp.global_position = hf.call() + (sd * cos(a) + Vector3.UP * sin(a)) * r - fc * (1.0 - u) * 0.6
		var fin = func():
			if is_instance_valid(sp):
				pj.free_after(0.4, sp)
		pj.every(0.4, 1.0 / 60.0, tick, fin)
		_ribbon(pj, sp, 0.05, 0.25, Color(0.45, 0.7, 1.0))


## Kaynağı izleyen kameraya dönük şerit (konum geçmişinden, yaşla incelir)
static func _ribbon(pj: PathJutsu, src: Node3D, w: float, life: float, col: Color) -> void:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _plain_mat("chakra", CHAKRA_SHADER)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16.0
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	mi.set_instance_shader_parameter("tint", col)
	var hist = []
	var ws = weakref(src)
	var upd = func(_i, _k):
		if not is_instance_valid(mi):
			return
		var now = Game.now()
		var s = ws.get_ref()
		if s != null and is_instance_valid(s) and s.is_inside_tree():
			hist.push_front([s.global_position, now])
		while hist.size() > 0 and now - float(hist[-1][1]) > life:
			hist.pop_back()
		im.clear_surfaces()
		if hist.size() < 2:
			return
		var cam = pj.get_viewport().get_camera_3d()
		var cp = cam.global_position if cam else Vector3.ZERO
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in hist.size():
			var p: Vector3 = hist[i][0]
			var td: Vector3 = hist[maxi(i - 1, 0)][0] - hist[mini(i + 1, hist.size() - 1)][0]
			if td.length() < 0.0001:
				td = Vector3.FORWARD
			var side = td.normalized().cross((cp - p).normalized())
			if side.length() < 0.01:
				side = Vector3.UP
			side = side.normalized()
			var age = clampf((now - float(hist[i][1])) / life, 0.0, 1.0)
			var ww = w * (1.0 - age * 0.7)
			im.surface_set_uv(Vector2(age, 0.0))
			im.surface_add_vertex(p - side * ww)
			im.surface_set_uv(Vector2(age, 1.0))
			im.surface_add_vertex(p + side * ww)
		im.surface_end()
	pj.every(life + 1.2, 1.0 / 60.0, upd, func():
		if is_instance_valid(mi):
			mi.queue_free())


# ================================================================== Amagumo
## Ref (örümcek yağmuru): hedefin 11 m üstünde dev ağ geri sekerek açılır (göbeği aşağı sarkar), kenarlarından yere beş bağ teli
## iner; ağın altında ters asılı turuncu desenli ana örümcek ve altında ipek yumurta kesesi. Kese şişip patlar (ipek tüyleri),
## kırk kara yavru her biri arkasında ipek bırakarak yere iner.
static func amagumo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "seal", 1.0)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + c.face_dir() * 10.0)
	var top = at + Vector3.UP * 11.0
	var web = _mi(_orb_web_mesh(6.0, 16, 8, 0.045, 0.6, 5), "silk", {"ow": 0.02, "wet": 1.0})
	pj.scene_add(web, top)
	web.rotation.x = -PI * 0.5
	web.scale = Vector3.ONE * 0.08
	var wt = web.create_tween()
	wt.tween_property(web, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_free(web, 2.6, 0.5)
	for k in 5:
		var a = k * TAU / 5.0 + 0.3
		var rim = top + Vector3(cos(a), 0, sin(a)) * 5.6
		var gnd = pj.gp(at + Vector3(cos(a), 0, sin(a)) * 8.0)
		var fa = func() -> Vector3:
			return rim
		var fb = func() -> Vector3:
			return gnd
		_rope(pj, fa, fb, 0.03, 2.9, {"grow": 0.3})
	var mom = _mi(_spider_mesh(false), "toon", {"ow": 0.011, "wet": 0.6})
	pj.scene_add(mom, top + Vector3.DOWN * 0.15)
	mom.rotation.x = PI
	mom.scale = Vector3.ONE * 0.05
	mom.create_tween().tween_property(mom, "scale", Vector3.ONE * 1.6, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_free(mom, 2.6, 0.4)
	var sac = _mi(_blob_mesh(4), "silk", {"wet": 1.0, "ow": 0.02})
	pj.scene_add(sac, top + Vector3.DOWN * 1.5)
	sac.scale = Vector3(0.9, 1.15, 0.9)
	var st = sac.create_tween()
	st.tween_interval(0.3)
	st.tween_property(sac, "scale", Vector3(1.15, 1.4, 1.15), 0.08)
	st.tween_callback(func(): _fluff(pj, sac.global_position, 16))
	st.tween_property(sac, "scale", Vector3.ONE * 0.01, 0.12)
	st.tween_callback(sac.queue_free)
	Sfx.play("th_bugs", at, 0.7)
	var hits = []
	for k in 40:
		pj.after(0.4 + k * 0.03, func():
			var land = pj.gp(at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.0, 6.0))
			var sp = _mi(_spider_mesh(true), "toon", {"ow": 0.02, "wet": 0.6})
			pj.scene_add(sp, top + Vector3(randf_range(-2, 2), -0.5, randf_range(-2, 2)))
			sp.scale = Vector3.ONE * 0.22
			sp.rotation.y = randf() * TAU
			var start = sp.global_position
			var tw = sp.create_tween()
			tw.tween_property(sp, "global_position", land + Vector3.UP * 0.15, randf_range(0.5, 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(sp, "rotation:y", sp.rotation.y + randf_range(-3.0, 3.0), 0.6)
			tw.tween_interval(0.8)
			tw.tween_property(sp, "scale", Vector3.ONE * 0.01, 0.3)
			tw.tween_callback(sp.queue_free)
			# her yavru iplik bırakarak düşer
			var fs = func() -> Vector3:
				return start
			_rope(pj, fs, _follow(sp, Vector3.UP * 0.08), 0.012, 1.4, {"ow": 0.35})
			if k % 3 == 0:
				pj.after(0.55, func():
					for h in pj.hit(c, land + Vector3.UP * 0.6, 1.8, pj.inf(c, "amagumo", 0.06, {"knock": 0.0, "kind": "light"}), hits):
						hits.append(h)
						pj.st(h, "bind", 2.8)
						Combat.popup_text(h.global_position + Vector3.UP * 2.3, "İplere sarıldı!", Color(0.95, 0.95, 0.9))))


# ================================================================== Kumo Sōkai
## Ref (ağ çarşafı açılması): sarılı bir ağ rulosu dönerek uçar; çarptığı yerde tepeden aşağı açılan, kalın yassı telli düzensiz
## hücreli dev ağ çarşafı olur (açılırken rulo aşağı yuvarlanıp küçülür), dört köşesinden yere bağ telleri iner; yakalananlar asılı kalır.
static func kumosokai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.5)
	pj.anim(c, "throw", 1.3)
	var from = pj.hand_pos(c, true)
	var ball = Node3D.new()
	var rl = _mi(_roll_mesh(), "silk", {"ow": 0.01})
	ball.add_child(rl)
	rl.create_tween().set_loops().tween_property(rl, "rotation:x", TAU, 0.3).from(0.0)
	pj.shot(c, from, pj.aim_at(c, tt, from), 28.0, ball, pj.inf(c, "kumosokai", 0.2, {"knock": 0.0, "kind": "light"}), tt, false, 1.0, func(p, h):
		var away = (p - c.global_position).normalized() if is_instance_valid(c) else Vector3.FORWARD
		if away.length() < 0.1:
			away = Vector3.FORWARD
		var root = Node3D.new()
		pj.get_tree().current_scene.add_child(root)
		root.global_position = p + Vector3.UP * 1.6
		_aim(root, away)
		var sheet = _mi(_cell_sheet_mesh(3.2, 3.2, 7, 7, 0.045, 0.5, 7), "silk", {"wet": 1.0, "ow": 0.015})
		root.add_child(sheet)
		sheet.scale = Vector3(1.0, 0.05, 1.0)
		var roll = _mi(_roll_mesh(), "silk", {"ow": 0.01})
		root.add_child(roll)
		roll.scale = Vector3(5.0, 1.0, 1.0)
		_pin(pj, root, [Vector3(-1.6, 0, -0.5), Vector3(1.6, 0, -0.5), Vector3(-1.6, -3.2, -0.5), Vector3(1.6, -3.2, -0.5)], 3.7, 0.8, 0.02)
		var tw = root.create_tween()
		tw.tween_method(func(v: float):
			if is_instance_valid(sheet) and is_instance_valid(roll):
				sheet.scale = Vector3(1.0, maxf(v, 0.02), 1.0)
				roll.position = Vector3(0, -3.2 * v, 0)
				roll.scale = Vector3(5.0, maxf(1.0 - v * 0.8, 0.05), maxf(1.0 - v * 0.8, 0.05))
				roll.rotation.x = -v * 14.0, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(roll.queue_free)
		tw.tween_interval(3.2)
		tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.3)
		tw.tween_callback(root.queue_free)
		_fluff(pj, p, 12)
		if not is_instance_valid(c):
			return
		for e in pj.enemies_near(c, p, 3.0):
			pj.st(e, "bind", 3.4)
			if e is CharacterBody3D:
				e.velocity = Vector3.ZERO
			Combat.popup_text(e.global_position + Vector3.UP * 2.3, "Ağa asıldı!", Color(0.95, 0.95, 0.9)))
	Sfx.play("whoosh", from, 1.4, 0.5)


# ================================================================== Kumonendo
## (Kaynak görsel yok; açıklama: ağızdan kalın yapışkan ağ halatı tükürülür, hedefe yapışır, hedef savrularak yere çarpılır.)
## Ağızdan arkasından ince iplik uzanan, kıpır kıpır yapışkan ipek yumağı fırlar; yapıştığı hedefin gövdesine ipek dolanır ve ağızdan
## hedefe kalın örgülü (çizgili) halat gerilir. Hedef yay çizerek savrulup yere çarpınca yerde kırık kırık çatlak ağı açılır,
## toz halkası kalkar ve toprak parçaları seker.
static func kumonendo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.9)
	var mo = pj._mouth_pos(c)
	var ball = Node3D.new()
	var glob = _mi(_blob_mesh(4), "silk", {"wet": 1.0, "wob": 0.12, "ow": 0.03})
	glob.scale = Vector3.ONE * 0.3
	ball.add_child(glob)
	var tails = G.new()
	for k in 3:
		var a = k * TAU / 3.0
		var o = Vector3(cos(a), sin(a), 0.0)
		tails.tube([o * 0.06, o * 0.14 + Vector3(0, -0.04, 0.25), o * 0.1 + Vector3(0, -0.12, 0.5)], [0.025, 0.015, 0.0], 4, WHITE_V)
	ball.add_child(_mi(tails.build(), "silk", {"wet": 1.0, "ow": 0.01}))
	var pr = pj.shot(c, mo, pj.aim_at(c, tt, mo), 34.0, ball, pj.inf(c, "kumonendo", 0.25, {"knock": 0.0, "kind": "light"}), tt, false, 0.8, func(p, h):
		if h == null or not pj.live(h) or not pj.live(c):
			return
		pj.st(h, "bind", 1.2)
		# halat: ağızdan hedefe kalın örgülü ip
		_rope(pj, _mouth_fn(pj, c), _follow(h, Vector3.UP * 1.1), 0.06, 1.3, {"braid": 30.0, "wet": 1.0, "ow": 0.25})
		_wrap(pj, h, 1.3)
		_fluff(pj, p, 8)
		pj.after(0.35, func():
			if not pj.live(h) or not pj.live(c):
				return
			# savur: yana yay çizerek kaldır, yere çarp
			var side = c.face_dir().cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
			var a0 = h.global_position
			var land = pj.gp(c.global_position + side * 4.0 + c.face_dir() * 2.0)
			var tw = h.create_tween()
			tw.tween_method(func(u: float):
				if pj.live(h):
					h.global_position = a0.lerp(land, u) + Vector3.UP * sin(u * PI) * 5.0, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(func():
				if pj.live(h):
					h.take_hit(pj.inf(c, "kumonendo", 0.55, {"knock": 4.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.06}))
					_slam(pj, land)
					pj.shake(0.4))))
	_rope(pj, _mouth_fn(pj, c), _follow(pr, Vector3.ZERO), 0.025, 0.8, {"wet": 1.0})
	Sfx.play("th_ink", mo, 0.8, 0.6)


static func _slam(pj: PathJutsu, land: Vector3) -> void:
	var cr = _mi(_crack_mesh(randi() % 3), "toon", {"ow": 0.0})
	pj.scene_add(cr, land + Vector3.UP * 0.02)
	cr.rotation.y = randf() * TAU
	cr.scale = Vector3.ONE * 0.4
	cr.create_tween().tween_property(cr, "scale", Vector3.ONE * 1.1, 0.08).set_ease(Tween.EASE_OUT)
	_fade_free(cr, 3.0, 0.6)
	_emit(pj, {"kind": 1.0, "n": 16, "life": 0.9, "ring": 0.6, "dir": Vector3.UP, "spread": 70.0, "vmin": 1.5, "vmax": 3.5, "g": Vector3(0, -1.0, 0), "damp": 2.0,
		"smin": 0.5, "smax": 1.0, "curve": "grow", "cols": [Color(0.62, 0.53, 0.42, 0.8), Color(0.58, 0.5, 0.4, 0.5), Color(0.58, 0.5, 0.4, 0.0)]}, land + Vector3.UP * 0.15)
	for k in 7:
		var rk = _mi(_rock_mesh(k % 3), "toon", {"ow": 0.03})
		pj.scene_add(rk, land)
		rk.scale = Vector3.ONE * randf_range(0.12, 0.22)
		var to = pj.gp(land + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.8, 1.8))
		var pk = randf_range(0.6, 1.3)
		var spin = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var tw = rk.create_tween()
		tw.tween_method(func(u: float):
			if is_instance_valid(rk):
				rk.global_position = land.lerp(to, u) + Vector3.UP * (sin(u * PI) * pk + 0.05)
				rk.rotation = spin * u, 0.0, 1.0, 0.5)
		tw.tween_interval(0.8)
		tw.tween_method(func(v: float): rk.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.4)
		tw.tween_callback(rk.queue_free)
