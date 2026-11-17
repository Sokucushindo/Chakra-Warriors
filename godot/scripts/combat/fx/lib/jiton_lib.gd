class_name JitonLib
extends RefCounted
## Mıknatıs doğası (Jiton) malzeme / şekil kütüphanesi: Sandaime Kazekage'nin demir kumu (Satetsu), Rasa'nın altın tozu (Sakin).
## Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları ve kendi ürettiği geometrisidir:
##   demir kumu  : neredeyse siyah, taneli kütle; gri-mor metalik parıltı bandı, ince tane benekleri (büyük yüzeyde de ince doku:
##                 tane boyu nesne ölçeğinden bağımsız), koyu kontur (ters kabuk), akış kaydırması, taneli dağılma (melt),
##                 kökten uca büyüme (reach / tail), kameraya çok yakın kısım noktalı inceltilir (ekranı kaplamaz)
##   altın tozu  : sarı-altın taneli kütle, kahve kontur, zamanla yanıp sönen ışıltı taneleri
##   biçimler    : kristal diken (piramit), yassı kıymık / tüy, pürüzlü topak, boru (akış kolu, parmak), sıradağ kaması,
##                 kıvrık dalga levhası, yıldız / leke (düz, dikenli kenar)
##   parçacık    : kendi çizdiğimiz tane / topak / ışıltı dokuları; toplanma (merkeze çekilen kabuk), bulut, saçılma, sürekli akış
##   çizgiler    : manyetik akış çizgisi (kesikli, akan), mühür yazısı bandı, manyetik ark, iz şeridi
##   zemin izi   : demir kumu serpintisi, altın tozu tabakası, dikenli darbe izi
##   mıknatıslama: hedefe iz bırakır; atanın mermileri ona çekilir (oyun kuralı aynen), görseli bu dosyada
## Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası yalnız malzeme + yapı taşı verir.

static var _cache := {}

const IRON := Color(0.07, 0.068, 0.085)
const IRON_MID := Color(0.2, 0.19, 0.245)
const SHEEN := Color(0.56, 0.52, 0.7)
const IRON_LINE := Color(0.015, 0.012, 0.03)
const GOLD := Color(0.95, 0.76, 0.25)
const GOLD_HI := Color(1.0, 0.9, 0.55)
const GOLD_DEEP := Color(0.62, 0.42, 0.1)
const GOLD_LINE := Color(0.32, 0.18, 0.04)
const GLINT := Color(1.0, 0.98, 0.82)
const FIELD := Color(0.62, 0.72, 1.0)
const STEEL := Color(0.46, 0.48, 0.54)

# ================================================================== shader parçaları
const JNOISE := """
float jh(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float jn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(jh(i), jh(i + vec2(1.0, 0.0)), f.x);
	float b = mix(jh(i + vec2(0.0, 1.0)), jh(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float jf(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * jn(p);
		p = p * 2.07 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return s;
}
"""

## Taneli kütle (demir kumu / altın tozu / çelik): cel iki ton, büyük leke, ince tane benekleri, kenarda metalik parıltı bandı,
## glitter > 0.5 iken yanıp sönen ışıltı. Tane boyu metre başına sabit (eksen ölçekleri hesaba katılır).
const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 c_base = vec3(0.07, 0.068, 0.085);
uniform vec3 c_mid = vec3(0.2, 0.19, 0.245);
uniform vec3 c_sheen = vec3(0.56, 0.52, 0.7);
uniform float glitter = 0.0;
uniform float grain = 10.0;
uniform float flow = 0.0;
instance uniform float seed = 0.0;
instance uniform float melt = 0.0;
instance uniform float reach = 2.0;
instance uniform float tail = -1.0;
instance uniform float near_fade = 3.0;

JNOISE

varying vec3 lp;
varying vec3 ln;

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * sc;
	ln = NORMAL;
}

void fragment() {
	if (UV.x > reach || UV.x < tail) {
		discard;
	}
	float dist = -VERTEX.z;
	if (dist < near_fade && jh(floor(FRAGCOORD.xy) + vec2(seed)) > (dist - near_fade * 0.3) / (near_fade * 0.7)) {
		discard;
	}
	vec3 an = abs(normalize(ln));
	vec2 uvp = lp.xy;
	if (an.x > an.y && an.x > an.z) {
		uvp = lp.zy;
	} else if (an.y > an.z) {
		uvp = lp.xz;
	}
	uvp += vec2(seed * 3.7, seed * 1.3 - TIME * flow);
	float big = jf(uvp * 0.7);
	float med = jf(uvp * 2.6 + vec2(5.3, 1.1));
	float fq = grain * 6.0;
	float aa = clamp(1.4 - length(fwidth(uvp * fq)) * 1.6, 0.0, 1.0);
	float g = mix(0.5, jn(uvp * fq), aa);
	float g2 = jn(uvp * fq * 0.4 + vec2(17.0, 5.0));
	if (melt > 0.001) {
		float m = g2 * 0.45 + big * 0.55;
		if (m < melt) {
			discard;
		}
	}
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = dot(wn, normalize(vec3(0.4, 0.85, 0.35)));
	vec3 col = mix(c_base, c_mid, smoothstep(0.42, 0.72, big) * 0.5 + smoothstep(0.5, 0.75, med) * 0.25);
	if (d < 0.05) {
		col *= 0.66;
	}
	col = mix(col, c_mid * 1.3, smoothstep(0.7, 0.78, g) * 0.6);
	col = mix(col, c_base * 0.6, smoothstep(0.22, 0.15, g) * 0.5 * aa);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float band = step(0.6, fr + (g - 0.5) * 0.3);
	col = mix(col, c_sheen, band * 0.6);
	float sp = smoothstep(0.86, 0.9, g) * step(0.0, d) * aa;
	if (glitter > 0.5) {
		float tw = jh(floor(uvp * fq * 0.5) + vec2(floor(TIME * 7.0), 1.0));
		sp = max(sp, smoothstep(0.82, 0.87, g) * step(0.6, tw) * aa);
	}
	col = mix(col, c_sheen * (1.35 + glitter * 0.5), sp);
	if (melt > 0.001) {
		col = mix(col, c_mid * 1.2, step(g2 * 0.45 + big * 0.55, melt + 0.04));
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""

## Koyu kontur: ters kabuk, TANGENT'a gömülü ortalama normal boyunca şişer; gövdeyle aynı büyüme / dağılma / yakın kesme
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform float ow = 0.03;
uniform vec3 ocol = vec3(0.015, 0.012, 0.03);
instance uniform float seed = 0.0;
instance uniform float melt = 0.0;
instance uniform float reach = 2.0;
instance uniform float tail = -1.0;
instance uniform float near_fade = 3.0;

JNOISE

varying vec3 lp;

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * sc;
	VERTEX += TANGENT * (ow / max(sc.x, 0.0001));
}

void fragment() {
	if (UV.x > reach || UV.x < tail) {
		discard;
	}
	float dist = -VERTEX.z;
	if (dist < near_fade && jh(floor(FRAGCOORD.xy) + vec2(seed)) > (dist - near_fade * 0.3) / (near_fade * 0.7)) {
		discard;
	}
	if (melt > 0.001 && jf(lp.xz * 0.8 + vec2(seed * 3.7)) * 0.6 + 0.18 < melt) {
		discard;
	}
	ALBEDO = pow(ocol, vec3(2.2));
}
"""

## Şerit: rmode 0 kesikli akan manyetik akış çizgisi, 1 mühür yazısı bandı (nokta + kanca), 2 manyetik ark (parlak çekirdek),
## 3 iz şeridi (başta dolu, uca incelir)
const RIBBON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec3 rcol = vec3(0.62, 0.72, 1.0);
instance uniform float seed = 0.0;
instance uniform float rmode = 0.0;
instance uniform float fade = 0.0;
instance uniform float speed = 1.0;
instance uniform float reps = 6.0;

void fragment() {
	float dist = -VERTEX.z;
	float nearf = smoothstep(1.0, 3.5, dist);
	float u = UV.x;
	float v = UV.y * 2.0 - 1.0;
	float a = 0.0;
	vec3 col = rcol;
	if (rmode < 0.5) {
		float dash = step(0.42, fract(u * reps - TIME * speed));
		float body = 1.0 - smoothstep(0.5, 1.0, abs(v));
		a = body * dash * 0.85;
		col = mix(rcol, vec3(1.0), (1.0 - smoothstep(0.0, 0.45, abs(v))) * 0.5);
	} else if (rmode < 1.5) {
		vec2 q = vec2(fract(u * reps - TIME * speed) - 0.5, v * 0.5);
		float rr = length(q);
		float dotm = 1.0 - step(0.1, rr);
		float ang = atan(q.y, q.x);
		float hook = (1.0 - step(0.04, abs(rr - 0.25))) * step(0.1, sin(ang + 0.9));
		float tl = (1.0 - step(0.035, abs(q.y + 0.2 + q.x * 0.5))) * step(q.x, -0.08) * step(-0.46, q.x);
		a = max(dotm, max(hook, tl));
	} else if (rmode < 2.5) {
		float core = 1.0 - smoothstep(0.0, 0.3, abs(v));
		float glow = 1.0 - smoothstep(0.25, 1.0, abs(v));
		a = max(core, glow * 0.5);
		col = mix(rcol, vec3(1.0), core);
	} else {
		float body = 1.0 - smoothstep(0.4, 1.0, abs(v));
		a = body * (1.0 - u) * 0.8;
		col = mix(rcol, vec3(1.0), (1.0 - smoothstep(0.0, 0.5, abs(v))) * 0.4 * (1.0 - u));
	}
	a *= (1.0 - fade) * nearf;
	if (a < 0.03) {
		discard;
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Zemin izi: gmode 0 demir kumu serpintisi, 1 altın tozu tabakası (ışıltılı), 2 dikenli darbe izi. fade: taneli silinme
const PATCH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float gmode = 0.0;
instance uniform float fade = 0.0;
instance uniform float grow = 1.0;
instance uniform float seed = 0.0;

JNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p) / max(grow, 0.001);
	float ang = atan(p.y, p.x);
	vec2 gq = floor(UV * 110.0);
	float g = jn(UV * 140.0 + vec2(seed * 7.0));
	if (jn(UV * 60.0 + vec2(seed * 2.0, 3.0)) < fade) {
		discard;
	}
	vec3 col = vec3(0.05);
	if (gmode < 1.5) {
		float edge = 0.6 + 0.16 * jn(vec2(ang * 2.5 + seed, seed)) + 0.14 * jh(vec2(floor(ang * 7.0 + seed * 5.0), seed));
		if (r > edge) {
			if (g < 0.74 || r > edge + 0.3) {
				discard;
			}
		}
		if (gmode < 0.5) {
			col = mix(vec3(0.05, 0.05, 0.065), vec3(0.22, 0.21, 0.28), smoothstep(0.62, 0.7, g));
			col = mix(col, vec3(0.5, 0.48, 0.62), smoothstep(0.8, 0.84, g));
		} else {
			col = mix(vec3(0.78, 0.58, 0.18), vec3(1.0, 0.86, 0.42), smoothstep(0.55, 0.65, g));
			col = mix(col, vec3(1.0, 1.0, 0.85), smoothstep(0.84, 0.88, g) * step(0.6, jh(gq + vec2(floor(TIME * 6.0), seed))));
		}
		col *= 1.0 - smoothstep(edge - 0.08, edge, r) * 0.35;
	} else {
		float k = ang / 6.2831853 * 11.0;
		float id = floor(k);
		float sl = 0.45 + 0.5 * jh(vec2(id, seed));
		float w = (1.0 - r / sl) * 0.5;
		float inside = step(abs(fract(k) - 0.5), w) * step(r, sl);
		float core = step(r, 0.3 + 0.06 * jn(vec2(ang * 3.0, seed)));
		if (max(inside, core) < 0.5) {
			if (g < 0.77 || r > 0.95) {
				discard;
			}
		}
		col = mix(vec3(0.04, 0.04, 0.05), vec3(0.18, 0.17, 0.22), smoothstep(0.65, 0.72, g));
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
	ALPHA = 0.92;
}
"""

## Mıknatıs Rasengan küresi: dönen mavi çakra çizgileri, koyu mavi kenar, yüzeyde kara mühür işaretleri (nokta + kanca)
const RASEN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

instance uniform float seed = 0.0;
instance uniform float marks = 1.0;

JNOISE

varying vec3 on;

void vertex() {
	on = normalize(VERTEX);
}

void fragment() {
	float dist = -VERTEX.z;
	if (dist < 1.2 && jh(floor(FRAGCOORD.xy)) > (dist - 0.4) / 0.8) {
		discard;
	}
	vec3 n = normalize(on);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	float lon = atan(n.z, n.x);
	float sw = jf(vec2(lon * 3.0 + lat * 4.0 + TIME * 9.0, lat * 10.0 - TIME * 4.0));
	float fr = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(vec3(0.38, 0.62, 1.0), vec3(0.86, 0.95, 1.0), smoothstep(0.35, 0.8, sw));
	col = mix(col, vec3(1.0), smoothstep(0.8, 1.0, fr) * 0.55);
	col = mix(vec3(0.2, 0.36, 0.85), col, smoothstep(0.0, 0.35, fr));
	vec2 cell = vec2((lon + TIME * 1.3) / 6.2831853 * 9.0, (lat / 3.14159265 + 0.5) * 5.0);
	vec2 id = floor(cell);
	vec2 q = fract(cell) - 0.5;
	q.x += (jh(id + vec2(seed)) - 0.5) * 0.2;
	float rr = length(q);
	float dotm = 1.0 - step(0.1, rr);
	float ang = atan(q.y, q.x) + jh(id + vec2(3.0, seed)) * 6.28;
	float hook = (1.0 - step(0.045, abs(rr - 0.27))) * step(0.0, sin(ang));
	float m = max(dotm, hook) * marks;
	col = mix(col, vec3(0.04, 0.05, 0.13), m);
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""

## Rasengan çevresinde ışınsal çizgiler (kameraya bakan kart)
const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

instance uniform vec3 hcol = vec3(0.5, 0.75, 1.0);
instance uniform float seed = 0.0;
instance uniform float fade = 0.0;

JNOISE

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float k = (ang / 6.2831853 + 0.5) * 48.0;
	float id = floor(k);
	float lw = 1.0 - step(0.3, abs(fract(k) - 0.5));
	float ln = 0.62 + 0.36 * jh(vec2(id, floor(TIME * 14.0)));
	float a = lw * step(0.48, r) * (1.0 - smoothstep(ln - 0.1, ln, r));
	float nearf = smoothstep(1.0, 3.0, -VERTEX.z);
	a *= (1.0 - fade) * nearf * 0.85;
	if (a < 0.02) {
		discard;
	}
	ALBEDO = pow(hcol, vec3(2.2));
	ALPHA = a;
}
"""


# ================================================================== malzemeler
static func _shader(key: String, code: String) -> Shader:
	var k = "sh_" + key
	if _cache.has(k):
		return _cache[k]
	var sh = Shader.new()
	sh.code = code.replace("JNOISE", JNOISE)
	_cache[k] = sh
	return sh


static func line_mat(ow: float, col: Color) -> ShaderMaterial:
	var key = "ln_%.3f_%s" % [ow, col.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var m = ShaderMaterial.new()
	m.shader = _shader("line", LINE_SHADER)
	m.set_shader_parameter("ow", ow)
	m.set_shader_parameter("ocol", v3(col))
	_cache[key] = m
	return m


static func _body(key: String, base: Color, mid: Color, sheen: Color, glit: float, grain: float, flow: float, ow: float, ocol: Color) -> ShaderMaterial:
	var k = "%s_%.3f_%.2f" % [key, ow, flow]
	if _cache.has(k):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shader("body", BODY_SHADER)
	m.set_shader_parameter("c_base", v3(base))
	m.set_shader_parameter("c_mid", v3(mid))
	m.set_shader_parameter("c_sheen", v3(sheen))
	m.set_shader_parameter("glitter", glit)
	m.set_shader_parameter("grain", grain)
	m.set_shader_parameter("flow", flow)
	if ow > 0.0:
		m.next_pass = line_mat(ow, ocol)
	_cache[k] = m
	return m


## Demir kumu (flow > 0: yüzey taneleri akar)
static func iron_mat(ow := 0.035, flow := 0.0) -> ShaderMaterial:
	return _body("iron", IRON, IRON_MID, SHEEN, 0.0, 10.0, flow, ow, IRON_LINE)


## Altın tozu (yanıp sönen ışıltı)
static func gold_mat(ow := 0.035, flow := 0.0) -> ShaderMaterial:
	return _body("gold", GOLD, GOLD_HI, GLINT, 1.0, 9.0, flow, ow, GOLD_LINE)


## Mıknatısla taşınan çelik (yassı plaka)
static func steel_mat(ow := 0.02) -> ShaderMaterial:
	return _body("steel", STEEL, Color(0.66, 0.68, 0.74), Color(0.95, 0.97, 1.0), 0.0, 3.0, 0.0, ow, Color(0.1, 0.1, 0.13))


static func ribbon_mat() -> ShaderMaterial:
	if not _cache.has("ribbon"):
		var m = ShaderMaterial.new()
		m.shader = _shader("ribbon", RIBBON_SHADER)
		_cache["ribbon"] = m
	return _cache["ribbon"]


static func patch_mat() -> ShaderMaterial:
	if not _cache.has("patch"):
		var m = ShaderMaterial.new()
		m.shader = _shader("patch", PATCH_SHADER)
		_cache["patch"] = m
	return _cache["patch"]


static func rasen_mat() -> ShaderMaterial:
	if not _cache.has("rasen"):
		var m = ShaderMaterial.new()
		m.shader = _shader("rasen", RASEN_SHADER)
		m.next_pass = line_mat(0.02, Color(0.08, 0.14, 0.4))
		_cache["rasen"] = m
	return _cache["rasen"]


static func halo_mat() -> ShaderMaterial:
	if not _cache.has("halo"):
		var m = ShaderMaterial.new()
		m.shader = _shader("halo", HALO_SHADER)
		_cache["halo"] = m
	return _cache["halo"]


# ================================================================== temel yardımcılar
static func v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


static func put(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	host.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func kill(host: Node, sec: float, n: Node) -> void:
	var w = weakref(n)
	host.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	return mi


## Örnek shader parametresini tween'leyen ayarlayıcı
static func pf(mi: GeometryInstance3D, k: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(k, v)


static func floor_at(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z), p.z)


static func side_of(d: Vector3) -> Vector3:
	var s = d.cross(Vector3.UP)
	if s.length() < 0.01:
		return Vector3.RIGHT
	return s.normalized()


## Düğümün +Y eksenini dirv yönüne çevirir (diken / kıymık / boru +Y boyunca üretilir)
static func aim_y(n: Node3D, dirv: Vector3) -> void:
	if not is_instance_valid(n) or dirv.length() < 0.0001:
		return
	var y = dirv.normalized()
	var ref = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x = ref.cross(y).normalized()
	var z = x.cross(y).normalized()
	var sc = n.scale
	n.global_basis = Basis(x, y, z).scaled(sc)


static func cam_pos(host: Node) -> Vector3:
	var cam = host.get_viewport().get_camera_3d() if host.is_inside_tree() else null
	return cam.global_position if cam else Vector3(0, 1000, 0)


## Kameraya yakın inceltme mesafesi (büyük gövdeler: 8 m) — düğüm ağacındaki tüm gövdelere
static func near_fade(root: Node, dist: float) -> void:
	var list = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		list.append(root)
	for n in list:
		n.set_instance_shader_parameter("near_fade", dist)


## Büyüme açılışı: reach 0 → 1 (UV.x boyunca kökten uca)
static func grow_in(mi: GeometryInstance3D, t: float, delay := 0.0) -> void:
	mi.set_instance_shader_parameter("reach", 0.0)
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(pf(mi, "reach"), 0.0, 1.02, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Taneli dağılıp silinme: delay sonra melt 0 → 1, sonra düğüm silinir
static func crumble(mi: GeometryInstance3D, delay: float, t: float, node: Node = null) -> void:
	var tw = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(pf(mi, "melt"), 0.0, 1.0, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var target = node if node != null else mi
	tw.tween_callback(func():
		if is_instance_valid(target):
			target.queue_free())


# ================================================================== geometri
## Yüzlü ağ kurucu: üçgen başına "dışa" yön verilir, sargı ona göre düzeltilir. Düz (yüz) normal; TANGENT'a aynı
## konumdaki yüzlerin ortalama normali gömülür (kontur şişirmesi). UV.x: büyüme ekseni (reach / tail).
class G:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var want := PackedVector3Array()

	func pt(p: Vector3, u := 0.0) -> int:
		v.append(p)
		uv.append(Vector2(u, 0.0))
		return v.size() - 1

	func tri(a: int, b: int, c: int, w: Vector3) -> void:
		idx.append(a)
		idx.append(b)
		idx.append(c)
		want.append(w)

	func quad(a: int, b: int, c: int, d: int, w: Vector3) -> void:
		tri(a, b, c, w)
		tri(a, c, d, w)

	func mesh() -> ArrayMesh:
		var acc := {}
		var order := PackedInt32Array()
		var fns := PackedVector3Array()
		for t in range(0, idx.size(), 3):
			var ia = idx[t]
			var ib = idx[t + 1]
			var ic = idx[t + 2]
			var nrm = (v[ib] - v[ia]).cross(v[ic] - v[ia])
			if nrm.dot(want[t / 3]) < 0.0:
				var tmp = ib
				ib = ic
				ic = tmp
				nrm = -nrm
			order.append(ia)
			order.append(ib)
			order.append(ic)
			var nn = nrm.normalized() if nrm.length() > 0.0000001 else Vector3.UP
			fns.append(nn)
			for id in [ia, ib, ic]:
				var key = v[id].snapped(Vector3.ONE * 0.001)
				acc[key] = acc.get(key, Vector3.ZERO) + nn
		var pv = PackedVector3Array()
		var pn = PackedVector3Array()
		var ptg = PackedFloat32Array()
		var puv = PackedVector2Array()
		for t in range(0, order.size(), 3):
			var fn: Vector3 = fns[t / 3]
			for k in [0, 2, 1]:   # Godot ön yüzü saat yönünde
				var id = order[t + k]
				pv.append(v[id])
				pn.append(fn)
				var sm: Vector3 = acc.get(v[id].snapped(Vector3.ONE * 0.001), fn)
				sm = sm.normalized() if sm.length() > 0.0001 else fn
				ptg.append_array([sm.x, sm.y, sm.z, 1.0])
				puv.append(uv[id])
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pv
		arr[Mesh.ARRAY_NORMAL] = pn
		arr[Mesh.ARRAY_TANGENT] = ptg
		arr[Mesh.ARRAY_TEX_UV] = puv
		var m = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static func _rng(sd: int) -> RandomNumberGenerator:
	var r = RandomNumberGenerator.new()
	r.seed = sd
	return r


## Kristal diken (+Y boyunca): pürüzlü taban, yüzlü bel, eğik uç. UV.x = yükseklik oranı
static func spike_mesh(h: float, r: float, sides := 5, jit := 0.2, sd := 0, mid := 0.45) -> ArrayMesh:
	var key = "sp_%.2f_%.2f_%d_%.2f_%d_%.2f" % [h, r, sides, jit, sd, mid]
	if _cache.has(key):
		return _cache[key]
	var rng = _rng(sd + 11)
	var g = G.new()
	var base = []
	var mr = []
	for i in sides:
		var a = TAU * (i + rng.randf_range(-0.22, 0.22)) / sides
		var rr = r * rng.randf_range(1.0 - jit, 1.0 + jit)
		base.append(g.pt(Vector3(cos(a) * rr, -0.04 * h, sin(a) * rr), 0.0))
		var a2 = a + rng.randf_range(-0.18, 0.18)
		var r2 = rr * rng.randf_range(0.42, 0.6)
		mr.append(g.pt(Vector3(cos(a2) * r2, h * (mid + rng.randf_range(-0.06, 0.06)), sin(a2) * r2), mid))
	var tip = g.pt(Vector3(rng.randf_range(-0.06, 0.06) * r, h, rng.randf_range(-0.06, 0.06) * r), 1.0)
	var bc = g.pt(Vector3(0, -0.05 * h, 0), 0.0)
	for i in sides:
		var j = (i + 1) % sides
		var cen = (g.v[base[i]] + g.v[base[j]] + g.v[mr[i]] + g.v[mr[j]]) * 0.25
		g.quad(base[i], base[j], mr[j], mr[i], Vector3(cen.x, 0.0, cen.z))
		var c2 = (g.v[mr[i]] + g.v[mr[j]]) * 0.5
		g.tri(mr[i], mr[j], tip, Vector3(c2.x, r * 0.3 / maxf(h, 0.01), c2.z))
		g.tri(bc, base[j], base[i], Vector3.DOWN)
	var m = g.mesh()
	_cache[key] = m
	return m


## Yassı kıymık / tüy (+Y boyunca, genişlik X, kalınlık Z): taban dar, 0.3'te en geniş, uca sivrilir; jag kenar tırtığı
static func blade_mesh(L: float, w: float, th: float, sd := 0, jag := 0.15) -> ArrayMesh:
	var key = "bl_%.2f_%.2f_%.2f_%d_%.2f" % [L, w, th, sd, jag]
	if _cache.has(key):
		return _cache[key]
	var rng = _rng(sd + 23)
	var g = G.new()
	var st = [0.0, 0.18, 0.32, 0.5, 0.68, 0.84]
	var wf = [0.35, 0.85, 1.0, 0.82, 0.55, 0.28]
	var rings = []
	for i in st.size():
		var y = st[i] * L
		var ww = w * 0.5 * wf[i] * rng.randf_range(1.0 - jag, 1.0 + jag * 0.5)
		var ww2 = w * 0.5 * wf[i] * rng.randf_range(1.0 - jag, 1.0 + jag * 0.5)
		var t2 = th * 0.5 * wf[i]
		var cx = rng.randf_range(-0.05, 0.05) * w
		rings.append([g.pt(Vector3(cx + ww, y + rng.randf_range(-0.03, 0.03) * L, 0), st[i]), g.pt(Vector3(cx, y, t2), st[i]),
			g.pt(Vector3(cx - ww2, y + rng.randf_range(-0.03, 0.03) * L, 0), st[i]), g.pt(Vector3(cx, y, -t2), st[i])])
	var tip = g.pt(Vector3(rng.randf_range(-0.04, 0.04) * w, L, 0), 1.0)
	var bc = g.pt(Vector3(0, -0.02 * L, 0), 0.0)
	for i in st.size() - 1:
		var A = rings[i]
		var B = rings[i + 1]
		for k in 4:
			var k2 = (k + 1) % 4
			var cen = (g.v[A[k]] + g.v[A[k2]] + g.v[B[k]] + g.v[B[k2]]) * 0.25
			var axis = Vector3(0, cen.y, 0)
			g.quad(A[k], A[k2], B[k2], B[k], cen - axis + Vector3(0, 0.001, 0))
	var Lr = rings[st.size() - 1]
	for k in 4:
		var k2 = (k + 1) % 4
		var cen = (g.v[Lr[k]] + g.v[Lr[k2]]) * 0.5
		g.tri(Lr[k], Lr[k2], tip, Vector3(cen.x, 0.2, cen.z))
	var F = rings[0]
	for k in 4:
		g.tri(bc, F[(k + 1) % 4], F[k], Vector3.DOWN)
	var m = g.mesh()
	_cache[key] = m
	return m


## Pürüzlü topak (enlem-boylam küre, ışınsal gürültü). UV.x = 0.5 (büyüme yok)
static func lump_mesh(r: float, sd := 0, rough := 0.22, nu := 10, nv := 7) -> ArrayMesh:
	var key = "lm_%.2f_%d_%.2f_%d_%d" % [r, sd, rough, nu, nv]
	if _cache.has(key):
		return _cache[key]
	var rng = _rng(sd + 37)
	var g = G.new()
	var top = g.pt(Vector3(0, r * rng.randf_range(1.0 - rough, 1.0), 0), 0.5)
	var bot = g.pt(Vector3(0, -r * rng.randf_range(1.0 - rough, 1.0), 0), 0.5)
	var rows = []
	for j in range(1, nv):
		var th = PI * float(j) / nv
		var row = []
		for i in nu:
			var ph = TAU * (i + (0.5 if j % 2 == 0 else 0.0)) / nu
			var rr = r * rng.randf_range(1.0 - rough, 1.0 + rough * 0.4)
			row.append(g.pt(Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * rr, 0.5))
		rows.append(row)
	for i in nu:
		var i2 = (i + 1) % nu
		g.tri(top, rows[0][i], rows[0][i2], (g.v[rows[0][i]] + g.v[rows[0][i2]] + g.v[top]) / 3.0)
		var lr = rows[rows.size() - 1]
		g.tri(bot, lr[i2], lr[i], (g.v[lr[i]] + g.v[lr[i2]] + g.v[bot]) / 3.0)
	for j in rows.size() - 1:
		var A = rows[j]
		var B = rows[j + 1]
		for i in nu:
			var i2 = (i + 1) % nu
			var cen = (g.v[A[i]] + g.v[A[i2]] + g.v[B[i]] + g.v[B[i2]]) * 0.25
			g.quad(A[i], A[i2], B[i2], B[i], cen)
	var m = g.mesh()
	_cache[key] = m
	return m


## Boru: noktalar boyunca halka halka (yarıçap listesi), pürüzlü; son yarıçap küçükse sivri uç. UV.x = uzunluk oranı.
## Önbelleğe alınmaz (her çağrı kendi eğrisi).
static func tube_mesh(pts: Array, radii: Array, sides := 7, jit := 0.15, sd := 0) -> ArrayMesh:
	var rng = _rng(sd + 51)
	var g = G.new()
	var n = pts.size()
	var total = 0.0
	var cum = [0.0]
	for i in range(1, n):
		total += (pts[i] - pts[i - 1]).length()
		cum.append(total)
	total = maxf(total, 0.001)
	var rings = []
	var prev_n = Vector3.ZERO
	for i in n:
		var tg: Vector3
		if i == 0:
			tg = (pts[1] - pts[0])
		elif i == n - 1:
			tg = (pts[n - 1] - pts[n - 2])
		else:
			tg = (pts[i + 1] - pts[i - 1])
		tg = tg.normalized()
		var nx: Vector3
		if prev_n == Vector3.ZERO:
			var ref = Vector3.UP if absf(tg.y) < 0.9 else Vector3.RIGHT
			nx = tg.cross(ref).normalized()
		else:
			nx = (prev_n - tg * prev_n.dot(tg)).normalized()
		prev_n = nx
		var ny = tg.cross(nx).normalized()
		var ring = []
		var rr0 = float(radii[i])
		for k in sides:
			var a = TAU * k / sides
			var rr = rr0 * rng.randf_range(1.0 - jit, 1.0 + jit * 0.5)
			ring.append(g.pt(pts[i] + (nx * cos(a) + ny * sin(a)) * rr, cum[i] / total))
		rings.append(ring)
	for i in n - 1:
		var A = rings[i]
		var B = rings[i + 1]
		var mid = (pts[i] + pts[i + 1]) * 0.5
		for k in sides:
			var k2 = (k + 1) % sides
			var cen = (g.v[A[k]] + g.v[A[k2]] + g.v[B[k]] + g.v[B[k2]]) * 0.25
			g.quad(A[k], A[k2], B[k2], B[k], cen - mid)
	var t0 = (pts[1] - pts[0]).normalized()
	var c0 = g.pt(pts[0] - t0 * float(radii[0]) * 0.3, 0.0)
	for k in sides:
		g.tri(c0, rings[0][(k + 1) % sides], rings[0][k], -t0)
	var t1 = (pts[n - 1] - pts[n - 2]).normalized()
	var c1 = g.pt(pts[n - 1] + t1 * maxf(float(radii[n - 1]) * 0.6, 0.02), 1.0)
	for k in sides:
		var k2 = (k + 1) % sides
		var cen = (g.v[rings[n - 1][k]] + g.v[rings[n - 1][k2]]) * 0.5
		g.tri(rings[n - 1][k], rings[n - 1][k2], c1, t1 + (cen - pts[n - 1]))
	return g.mesh()


## Sıradağ kaması: X boyunca tepe / vadi silüeti, kesiti üçgen (keskin sırt, tabanda derinlik). UV.x = yükseklik oranı
static func ridge_mesh(width: float, hmax: float, depth: float, peaks: int, sd := 0) -> ArrayMesh:
	var rng = _rng(sd + 61)
	var g = G.new()
	var n = peaks * 2 + 1
	var tops = []
	var bf = []
	var bb = []
	for i in n:
		var x = lerpf(-width * 0.5, width * 0.5, float(i) / (n - 1))
		var edge = absf(x) / (width * 0.5)
		var y: float
		if i == 0 or i == n - 1:
			y = hmax * 0.18
		elif i % 2 == 1:
			y = hmax * rng.randf_range(0.6, 1.0) * (1.0 - edge * 0.45)
		else:
			y = hmax * rng.randf_range(0.25, 0.45) * (1.0 - edge * 0.3)
		var xj = x + (rng.randf_range(-0.25, 0.25) * width / n if i > 0 and i < n - 1 else 0.0)
		tops.append(g.pt(Vector3(xj, y, rng.randf_range(-0.08, 0.08) * depth), y / hmax))
		bf.append(g.pt(Vector3(x, -0.6, depth * 0.5 * rng.randf_range(0.85, 1.1)), 0.0))
		bb.append(g.pt(Vector3(x, -0.6, -depth * 0.5 * rng.randf_range(0.85, 1.1)), 0.0))
	for i in n - 1:
		g.quad(tops[i], tops[i + 1], bf[i + 1], bf[i], Vector3(0, 0.15, 1))
		g.quad(tops[i], bb[i], bb[i + 1], tops[i + 1], Vector3(0, 0.15, -1))
		g.quad(bf[i], bf[i + 1], bb[i + 1], bb[i], Vector3.DOWN)
	g.tri(tops[0], bf[0], bb[0], Vector3.LEFT)
	g.tri(tops[n - 1], bb[n - 1], bf[n - 1], Vector3.RIGHT)
	return g.mesh()


## Kıvrık dalga levhası: prof (z, y) noktaları boyunca, X genişliğinde, kalın levha; tepe kenarı tırtıklı. UV.x = profil oranı
static func curl_mesh(width: float, prof: Array, thick: Array, nx := 9, sd := 0, jag := 0.8) -> ArrayMesh:
	var rng = _rng(sd + 71)
	var g = G.new()
	var n = prof.size()
	var tans = []
	var nrms = []
	for i in n:
		var a: Vector2 = prof[maxi(i - 1, 0)]
		var b: Vector2 = prof[mini(i + 1, n - 1)]
		var t2 = (b - a).normalized()
		tans.append(t2)
		nrms.append(Vector2(t2.y, -t2.x))
	var F = []
	var B = []
	for i in n:
		F.append([])
		B.append([])
	for j in nx:
		var x = lerpf(-width * 0.5, width * 0.5, float(j) / (nx - 1))
		var ext = rng.randf_range(0.0, jag)
		for i in n:
			var p2: Vector2 = prof[i]
			if i == n - 1:
				p2 += tans[i] * ext
			var nn: Vector2 = nrms[i]
			var th = float(thick[i]) * 0.5 * rng.randf_range(0.8, 1.2)
			var xx = x + (rng.randf_range(-0.35, 0.35) if (j == 0 or j == nx - 1) else rng.randf_range(-0.1, 0.1))
			var base = Vector3(xx, p2.y, p2.x)
			var u = float(i) / (n - 1)
			F[i].append(g.pt(base + Vector3(0, nn.y, nn.x) * th, u))
			B[i].append(g.pt(base - Vector3(0, nn.y, nn.x) * th, u))
	for i in n - 1:
		var nn: Vector2 = (nrms[i] + nrms[i + 1]) * 0.5
		var w3 = Vector3(0, nn.y, nn.x)
		for j in nx - 1:
			g.quad(F[i][j], F[i][j + 1], F[i + 1][j + 1], F[i + 1][j], w3)
			g.quad(B[i][j], B[i + 1][j], B[i + 1][j + 1], B[i][j + 1], -w3)
		g.quad(F[i][0], F[i + 1][0], B[i + 1][0], B[i][0], Vector3.LEFT)
		g.quad(F[i][nx - 1], B[i][nx - 1], B[i + 1][nx - 1], F[i + 1][nx - 1], Vector3.RIGHT)
	var te: Vector2 = tans[n - 1]
	var t0: Vector2 = tans[0]
	for j in nx - 1:
		g.quad(F[n - 1][j], F[n - 1][j + 1], B[n - 1][j + 1], B[n - 1][j], Vector3(0, te.y, te.x))
		g.quad(F[0][j], B[0][j], B[0][j + 1], F[0][j + 1], -Vector3(0, t0.y, t0.x))
	return g.mesh()


## Düz yıldız / leke (XY düzleminde, Z kalınlık): n kol, iç / dış yarıçap, düzensizlik. UV.x = merkezden uzaklık oranı
static func star_mesh(n: int, rin: float, rout: float, th: float, sd := 0, irr := 0.35) -> ArrayMesh:
	var key = "st_%d_%.2f_%.2f_%.2f_%d_%.2f" % [n, rin, rout, th, sd, irr]
	if _cache.has(key):
		return _cache[key]
	var rng = _rng(sd + 83)
	var g = G.new()
	var cf = g.pt(Vector3(0, 0, th * 0.5), 0.0)
	var cb = g.pt(Vector3(0, 0, -th * 0.5), 0.0)
	var rim = []
	for i in n * 2:
		var a = TAU * (i + rng.randf_range(-irr, irr) * 0.5) / (n * 2)
		var rr = (rout * rng.randf_range(1.0 - irr, 1.0 + irr * 0.4)) if i % 2 == 0 else (rin * rng.randf_range(1.0 - irr * 0.5, 1.0 + irr * 0.5))
		rim.append(g.pt(Vector3(cos(a) * rr, sin(a) * rr, 0), rr / rout))
	var m2 = rim.size()
	for i in m2:
		var j = (i + 1) % m2
		g.tri(cf, rim[i], rim[j], Vector3.BACK)
		g.tri(cb, rim[j], rim[i], Vector3.FORWARD)
	var m = g.mesh()
	_cache[key] = m
	return m


# ================================================================== şeritler
## Kameraya bakan şerit ağı (yerel koordinat): pts boyunca, w genişlik; taper: uca incelir
static func ribbon_mesh(pts: Array, w: float, face: Vector3, taper := false) -> ArrayMesh:
	var pv = PackedVector3Array()
	var puv = PackedVector2Array()
	var n = pts.size()
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var tg = (b - a).normalized()
		var sd = tg.cross(face)
		if sd.length() < 0.001:
			sd = tg.cross(Vector3.UP if absf(tg.y) < 0.9 else Vector3.RIGHT)
		sd = sd.normalized() * w * 0.5 * ((1.0 - float(i) / n * 0.85) if taper else 1.0)
		var u = float(i) / maxf(1.0, n - 1)
		pv.append(pts[i] + sd)
		puv.append(Vector2(u, 0.0))
		pv.append(pts[i] - sd)
		puv.append(Vector2(u, 1.0))
	var idx = PackedInt32Array()
	for i in n - 1:
		var a0 = i * 2
		idx.append_array([a0, a0 + 1, a0 + 2, a0 + 1, a0 + 3, a0 + 2])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_TEX_UV] = puv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func ribbon(host: Node, pts: Array, w: float, col: Color, mode: float, life: float, o := {}) -> MeshInstance3D:
	if pts.size() < 2:
		return null
	var org: Vector3 = pts[0]
	var loc = []
	for p in pts:
		loc.append(p - org)
	var face = (cam_pos(host) - org).normalized()
	var mi = gi(ribbon_mesh(loc, w, face, bool(o.get("taper", false))), ribbon_mat())
	mi.set_instance_shader_parameter("rcol", v3(col))
	mi.set_instance_shader_parameter("rmode", mode)
	mi.set_instance_shader_parameter("fade", 0.0)
	mi.set_instance_shader_parameter("speed", float(o.get("speed", 1.5)))
	mi.set_instance_shader_parameter("reps", float(o.get("reps", 6.0)))
	put(host, mi, org)
	var tw = mi.create_tween()
	tw.tween_interval(life * 0.55)
	tw.tween_method(pf(mi, "fade"), 0.0, 1.0, life * 0.45)
	tw.tween_callback(mi.queue_free)
	return mi


## Manyetik ark: a → b arası kırık çizgi (parlak çekirdek)
static func arc(host: Node, a: Vector3, b: Vector3, w: float, life: float, col := FIELD) -> void:
	var pts = []
	var segs = 8
	var d = b - a
	var sd = side_of(d)
	var up = d.cross(sd).normalized()
	for i in segs + 1:
		var k = float(i) / segs
		var off = Vector3.ZERO
		if i > 0 and i < segs:
			var amp = d.length() * 0.08 * sin(PI * k)
			off = sd * randf_range(-amp, amp) + up * randf_range(-amp, amp)
		pts.append(a + d * k + off)
	ribbon(host, pts, w, col, 2.0, life)


## Dipol akış çizgileri: center çevresinde axis ekseninde n halka, dışa doğru akan kesikli çizgi
static func field_loops(host: Node, center: Vector3, axis: Vector3, R: float, n: int, life: float, col := FIELD, w := 0.06) -> void:
	var ax = axis.normalized()
	var b1 = side_of(ax) if absf(ax.y) < 0.95 else Vector3.RIGHT
	var b2 = ax.cross(b1).normalized()
	for i in n:
		var ph = TAU * (i + randf_range(-0.15, 0.15)) / n
		var rad = b1 * cos(ph) + b2 * sin(ph)
		var rr = R * randf_range(0.8, 1.15)
		var pts = []
		for s in 17:
			var th = lerpf(0.13 * PI, 0.87 * PI, float(s) / 16.0)
			var sn = sin(th)
			pts.append(center + rad * (rr * sn * sn * sn) + ax * (rr * sn * sn * cos(th)))
		ribbon(host, pts, w, col, 0.0, life, {"speed": 2.2, "reps": 5.0})


## İz şeridi: hedef düğümü dur sn izler (en çok seg nokta), hedef silinince geriden kısalıp söner
static func trail(host: Node, target: Node3D, dur: float, width: float, col: Color, seg := 10) -> void:
	var im = ImmediateMesh.new()
	var mi = gi(im, ribbon_mat())
	mi.set_instance_shader_parameter("rcol", v3(col))
	mi.set_instance_shader_parameter("rmode", 3.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	host.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var pts: Array = []
	var wt = weakref(target)
	var tw = mi.create_tween()
	tw.tween_method(func(_x: float) -> void:
		if not is_instance_valid(mi):
			return
		var tn = wt.get_ref()
		if tn != null and is_instance_valid(tn) and tn.is_inside_tree():
			pts.push_front(tn.global_position)
		elif pts.size() > 0:
			pts.pop_back()
		while pts.size() > seg:
			pts.pop_back()
		im.clear_surfaces()
		if pts.size() < 2:
			return
		var cp = cam_pos(mi)
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n = pts.size()
		for i in n:
			var a: Vector3 = pts[maxi(i - 1, 0)]
			var b: Vector3 = pts[mini(i + 1, n - 1)]
			var tg = (a - b)
			var sd = tg.cross(cp - pts[i])
			if sd.length() < 0.0001:
				sd = Vector3.UP
			sd = sd.normalized() * width * 0.5 * (1.0 - float(i) / n)
			var u = float(i) / (n - 1)
			im.surface_set_uv(Vector2(u, 0.0))
			im.surface_add_vertex(pts[i] + sd)
			im.surface_set_uv(Vector2(u, 1.0))
			im.surface_add_vertex(pts[i] - sd)
		im.surface_end(), 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)


# ================================================================== parçacıklar
## Kendi çizdiğimiz parçacık dokuları: 0 tane (küçük pürüzlü), 1 topak (büyük pürüzlü, koyu kenar), 2 ışıltı (dört kollu)
static func _tex(kind: int) -> ImageTexture:
	var key = "tex%d" % kind
	if _cache.has(key):
		return _cache[key]
	var S = 32
	var img = Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var rng = _rng(77 + kind)
	var lob = []
	for i in 12:
		lob.append(rng.randf_range(0.55, 1.0) if kind == 1 else rng.randf_range(0.78, 1.0))
	for y in S:
		for x in S:
			var p = Vector2(x + 0.5, y + 0.5) / S * 2.0 - Vector2.ONE
			var r = p.length()
			if kind == 2:
				var sx = absf(p.x)
				var sy = absf(p.y)
				var star = maxf(1.0 - (sx * 7.0 + sy * 1.15), 1.0 - (sy * 7.0 + sx * 1.15))
				var a = clampf(maxf(star, 1.0 - r * 3.2), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
			else:
				var ang = fposmod(atan2(p.y, p.x), TAU) / TAU * 12.0
				var i0 = int(ang) % 12
				var lr = lerpf(lob[i0], lob[(i0 + 1) % 12], ang - floorf(ang)) * 0.95
				var a2 = 1.0 if r < lr else 0.0
				var shade = 1.0 if (p.x + p.y) < 0.15 else 0.7
				if kind == 1 and r > lr * 0.8:
					shade = 0.4
				img.set_pixel(x, y, Color(shade, shade, shade, a2))
	var tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func grain_mat(kind: int) -> StandardMaterial3D:
	var key = "gm%d" % kind
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tex(kind)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if kind == 2:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = 0.8
	m.distance_fade_max_distance = 2.8
	m.disable_receive_shadows = true
	_cache[key] = m
	return m


static func _shrink_curve() -> CurveTexture:
	if not _cache.has("shrink"):
		var cv = Curve.new()
		cv.add_point(Vector2(0.0, 1.0))
		cv.add_point(Vector2(0.7, 0.85))
		cv.add_point(Vector2(1.0, 0.1))
		var ct = CurveTexture.new()
		ct.curve = cv
		_cache["shrink"] = ct
	return _cache["shrink"]


static func _ramp(cols: Array) -> GradientTexture1D:
	var gr = Gradient.new()
	gr.set_color(0, cols[0])
	gr.set_color(1, cols[cols.size() - 1])
	if cols.size() > 2:
		for i in range(1, cols.size() - 1):
			gr.add_point(float(i) / (cols.size() - 1), cols[i])
	var gt = GradientTexture1D.new()
	gt.gradient = gr
	return gt


## Tane parçacıkları (en çok 260). o: kind (0 tane / 1 topak / 2 ışıltı), gold, cols, dir, spread, vmin, vmax, g, r, shell,
## radial, swirl, damp, life, size, burst (1 = hepsi birden), loop (sürekli; parent'a eklenir)
static func grains(host: Node, p: Vector3, n: int, o := {}) -> GPUParticles3D:
	n = clampi(n, 1, 260)
	var kind = int(o.get("kind", 0))
	var gold = bool(o.get("gold", false))
	var life = float(o.get("life", 1.0))
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 60.0))
	pm.initial_velocity_min = float(o.get("vmin", 2.0))
	pm.initial_velocity_max = float(o.get("vmax", 6.0))
	pm.gravity = Vector3(0, -float(o.get("g", 9.0)), 0)
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0)) * 1.3
	pm.radial_accel_min = float(o.get("radial", 0.0))
	pm.radial_accel_max = float(o.get("radial", 0.0)) * 1.2
	pm.tangential_accel_min = float(o.get("swirl", 0.0))
	pm.tangential_accel_max = float(o.get("swirl", 0.0)) * 1.3
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE if bool(o.get("shell", false)) else ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, float(o.get("r", 0.3)))
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.scale_curve = _shrink_curve()
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var cols: Array = o.get("cols", [])
	if cols.is_empty():
		if kind == 2:
			cols = [GLINT, Color(1.0, 0.9, 0.5)] if gold else [Color(0.85, 0.85, 1.0), SHEEN]
		elif gold:
			cols = [GOLD_HI, GOLD, GOLD_DEEP]
		else:
			cols = [IRON, IRON_MID, Color(0.04, 0.04, 0.05)]
	pm.color_initial_ramp = _ramp(cols)
	var ps = GPUParticles3D.new()
	ps.process_material = pm
	ps.amount = n
	ps.lifetime = life
	var loop = bool(o.get("loop", false))
	ps.one_shot = not loop
	ps.explosiveness = float(o.get("burst", 1.0)) if not loop else 0.0
	ps.local_coords = false
	var q = QuadMesh.new()
	var sz = float(o.get("size", 0.1 if kind != 1 else 0.45))
	q.size = Vector2(sz, sz)
	ps.draw_pass_1 = q
	ps.material_override = grain_mat(kind)
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.visibility_aabb = AABB(Vector3(-14, -8, -14), Vector3(28, 22, 28))
	if loop:
		var par: Node3D = o.get("parent", null)
		if par != null and is_instance_valid(par):
			par.add_child(ps)
			ps.position = p
		else:
			put(host, ps, p)
	else:
		put(host, ps, p)
		kill(host, life + 0.5, ps)
	ps.emitting = true
	return ps


## Toplanma: r yarıçaplı kabuktan merkeze çekilen, dönerek gelen taneler (hazırlık)
static func gather(host: Node, p: Vector3, r: float, n: int, life: float, gold := false) -> void:
	var t = maxf(0.15, life * 0.75)
	grains(host, p, n, {"gold": gold, "shell": true, "r": r, "vmin": 0.0, "vmax": 0.3, "g": 0.0, "radial": -2.0 * r / (t * t),
		"swirl": r * 3.0, "damp": 0.0, "life": life, "size": 0.09, "burst": 0.6})
	grains(host, p, maxi(4, n / 5), {"gold": gold, "kind": 1, "shell": true, "r": r * 0.8, "vmin": 0.0, "vmax": 0.2, "g": 0.0,
		"radial": -1.6 * r / (t * t), "swirl": r * 2.0, "life": life, "size": 0.32, "burst": 0.7})
	if gold:
		grains(host, p, maxi(4, n / 4), {"gold": true, "kind": 2, "shell": true, "r": r, "vmin": 0.0, "vmax": 0.2, "g": 0.0,
			"radial": -2.0 * r / (t * t), "life": life, "size": 0.16, "burst": 0.5})


## Asılı yoğun bulut: topaklar + ince taneler; yavaş kıvrılır
static func cloud(host: Node, p: Vector3, r: float, n: int, life: float, gold := false) -> void:
	grains(host, p, n, {"gold": gold, "kind": 1, "r": r, "vmin": 0.1, "vmax": 0.6, "g": 0.0, "swirl": 0.8, "damp": 0.5,
		"life": life, "size": 0.75, "burst": 0.85, "spread": 180.0})
	grains(host, p, n * 2, {"gold": gold, "r": r * 1.15, "vmin": 0.2, "vmax": 1.0, "g": 0.0, "swirl": 1.4, "life": life,
		"size": 0.1, "burst": 0.7, "spread": 180.0})


## Fırlayan katı parça: yerçekimiyle uçar, döner, yere değince durur; sonra taneli dağılıp silinir
static func fling(host: Node, mi: GeometryInstance3D, p0: Vector3, v: Vector3, life: float, g := 18.0) -> void:
	put(host, mi, p0)
	var spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	var r0 = mi.rotation
	var stt = {"land": false}
	var tw = mi.create_tween()
	tw.tween_method(func(tm: float) -> void:
		if not is_instance_valid(mi) or stt["land"]:
			return
		var pos = p0 + v * tm + Vector3.DOWN * 0.5 * g * tm * tm
		var fy = Game.jutsu_floor(pos.x, pos.z) + 0.05
		if pos.y < fy and tm > 0.06 and v.y - g * tm < 0.0:
			pos.y = fy
			stt["land"] = true
		mi.global_position = pos
		mi.rotation = r0 + spin * tm, 0.0, life, life)
	tw.tween_method(pf(mi, "melt"), 0.0, 1.0, 0.5)
	tw.tween_callback(mi.queue_free)


## Saçılan topak parçalar (halka)
static func shards(host: Node, p: Vector3, n: int, s: float, spd: float, gold := false, up := 0.9, life := 1.0) -> void:
	for i in n:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / maxf(1.0, float(n))
		var dv = Vector3(cos(a), up * randf_range(0.6, 1.4), sin(a)).normalized()
		var mi = gi(lump_mesh(0.5, randi() % 6, 0.35, 6, 4), gold_mat(0.02) if gold else iron_mat(0.02))
		mi.scale = Vector3.ONE * s * randf_range(1.2, 2.4)
		fling(host, mi, p + Vector3(cos(a), 0.1, sin(a)) * s, dv * spd * randf_range(0.7, 1.15), life)


# ================================================================== zemin izi
## gmode 0 demir kumu serpintisi, 1 altın tozu tabakası, 2 dikenli darbe izi
static func patch(host: Node, p: Vector3, r: float, gmode: int, life: float, grow_t := 0.25) -> MeshInstance3D:
	if not _cache.has("plane"):
		var pm = PlaneMesh.new()
		pm.size = Vector2(2.0, 2.0)
		_cache["plane"] = pm
	var mi = gi(_cache["plane"], patch_mat())
	mi.set_instance_shader_parameter("gmode", float(gmode))
	mi.set_instance_shader_parameter("fade", 0.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	put(host, mi, floor_at(p) + Vector3.UP * (0.04 + gmode * 0.01))
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r, 1.0, r)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, grow_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, life - grow_t - 0.8))
	tw.tween_method(pf(mi, "fade"), 0.0, 1.0, 0.8)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== mıknatıslama (oyun kuralı aynen, görsel kendi)
## Hedef dur sn mıknatıslanır: atanın menzildeki (30 m) mermileri ona güdümlenir, engellenemez olur.
## style 0: göğsü saran dönen akış çizgileri; 1: göğüste / sırtta kara demir kumu lekesi
static func magnetize(pj: PathJutsu, c: Node3D, tt: Node3D, dur: float, text: String, style := 0) -> void:
	if not pj.live(tt):
		return
	if float(tt.get_meta("magnet_t", 0.0)) < Game.now():
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, text, Color(0.6, 0.75, 1.0))
	tt.set_meta("magnet_t", Game.now() + dur)
	pj.st(tt, "marked", dur)
	var mark = pj.bone_attach(tt, "UpperChest")
	if mark:
		if style == 1:
			for zz in [-0.17, 0.17]:
				var sp = gi(star_mesh(9, 0.13, 0.2, 0.025, randi() % 5, 0.5), iron_mat(0.008))
				mark.add_child(sp)
				sp.position = Vector3(0, 0.02, zz)
				sp.scale = Vector3.ONE * 1.5
				sp.create_tween().tween_property(sp, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var spin = Node3D.new()
			mark.add_child(spin)
			for k in 2:
				var pts = []
				for s in 25:
					var a = TAU * s / 24.0
					pts.append(Vector3(cos(a) * 0.42, sin(a * 2.0) * 0.05, sin(a) * 0.3))
				var rb = gi(ribbon_mesh(pts, 0.045, Vector3.UP.rotated(Vector3.RIGHT, 0.4 + k * 1.1)), ribbon_mat())
				rb.set_instance_shader_parameter("rcol", v3(FIELD))
				rb.set_instance_shader_parameter("rmode", 0.0)
				rb.set_instance_shader_parameter("speed", 1.6)
				rb.set_instance_shader_parameter("reps", 9.0)
				rb.rotation = Vector3(0.3 + k * 0.9, k * 1.2, 0)
				spin.add_child(rb)
			var tw = spin.create_tween().set_loops(int(dur / 1.2) + 1)
			tw.tween_property(spin, "rotation:y", TAU, 1.2).as_relative()
	var wt = weakref(tt)
	var wc = weakref(c)
	var wm = weakref(mark) if mark else null
	var tick = func(_i, _k):
		var e = wt.get_ref()
		var cc = wc.get_ref()
		if e == null or cc == null or not pj.live(e) or float(e.get_meta("magnet_t", 0.0)) < Game.now():
			return
		for q in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(q) and q.get("shooter") == cc and q.homing != e and q.global_position.distance_to(e.global_position) < 30.0:
				q.homing = e
				q.homing_turn = maxf(float(q.homing_turn), 7.0)
				q.blockable = false
		if randf() < 0.35:
			var o = e.global_position + Vector3.UP * randf_range(0.6, 1.5)
			if style == 1:
				grains(pj, o, 6, {"shell": true, "r": 0.7, "vmin": 0.0, "vmax": 0.1, "g": 0.0, "radial": -9.0, "life": 0.3, "size": 0.06})
			else:
				var a = randf() * TAU
				var r0 = Vector3(cos(a), 0, sin(a))
				ribbon(pj, [o + r0 * 0.25, o + r0 * 0.55 + Vector3.UP * 0.25, o + r0 * 0.7 + Vector3.UP * 0.6, o + r0 * 0.5 + Vector3.UP * 0.9],
					0.04, FIELD, 0.0, 0.3, {"reps": 3.0, "speed": 3.0})
	var done = func():
		var mk = wm.get_ref() if wm else null
		if mk != null:
			mk.queue_free()
	pj.every(dur, 0.1, tick, done)
