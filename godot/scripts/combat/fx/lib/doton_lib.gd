class_name DotonLib
extends RefCounted
## Toprak doğası malzeme / şekil kütüphanesi (Doton). Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları ve
## kendi ürettiği köşeli geometrisi:
##   kaya        : yontulmuş, yüzey yüzey düz gölgeli (cel) parça; koyu kontur (ters kabuk), katman şeritleri (strata), üstte
##                 o zeminin kendi örtüsü (çimen / kum / kar), leke ve benekler. İsteğe bağlı tuğla harcı.
##   biçimler    : yuvarlak kaya, sivri kıymık, köşeli blok, pahlı prizma (levha / sütun / tuğla), kubbe kabuğu (ağızlı)
##   Doton çamuru: parlak ıslak kahve topak (sert parlama bandı, kenar karartma, yavaş akan yüzey) — MudFX'ten bağımsız
##   zemin izi   : yarılan çatlak ağı (düz / sarmal), çukur, toprak dalgası (zemin su gibi), çamur gölü, çamur seli akışı
##   toz         : cel gölgeli, konturlu kabarık toz bulutu (anime toz topu), içinden delinerek dağılır
##   moloz       : fırlayıp yere düşen, yere gömülen parçalar; ince çakıl taneleri (parçacık)
##   renk        : zemin türüne göre (Game.biome_at / yol): çimen-toprak, kum, kar-taş, kaya
## Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası yalnız malzeme + yapı taşı verir.

static var _cache := {}

# ================================================================== shader parçaları
const DNOISE := """
float dh(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float dn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(dh(i), dh(i + vec2(1.0, 0.0)), f.x);
	float b = mix(dh(i + vec2(0.0, 1.0)), dh(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float df(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * dn(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}
"""

## Kaya: yüzey normaline göre üç tonlu cel; nesne uzayı yüksekliğine göre katman şeritleri, üst örtü, leke, benek, tuğla harcı.
## Köşe rengi (COLOR) çarpan olarak kullanılır (kabuğun içi koyu vb.).
const ROCK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

instance uniform vec3 body = vec3(0.55, 0.43, 0.31);
instance uniform vec3 topc = vec3(0.42, 0.55, 0.27);
instance uniform float top_y = 99.0;
instance uniform float strata = 0.0;
instance uniform float seed = 0.0;
instance uniform float brick = 0.0;

DNOISE

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 ld = normalize(vec3(0.42, 0.82, 0.38));
	float d = dot(wn, ld);
	vec3 col = body * COLOR.rgb;
	vec2 sp = lp.xz * 2.3 + vec2(lp.y * 1.7, seed * 3.1);
	float n = df(sp);
	if (strata > 0.01) {
		float sb = lp.y * strata + (df(lp.xz * 0.9 + vec2(seed)) - 0.5) * 1.2;
		float layer = floor(sb);
		col *= 0.86 + 0.2 * dh(vec2(layer, seed));
		float fb = fract(sb);
		col = mix(col, col * 0.5, 1.0 - smoothstep(0.04, 0.09, fb));
	}
	if (brick > 0.5) {
		float row = floor(lp.y / 0.2);
		float bx = (lp.x + lp.z) / 0.42 + mod(row, 2.0) * 0.5;
		float my = fract(lp.y / 0.2);
		float mx = fract(bx);
		float mortar = max(1.0 - smoothstep(0.03, 0.07, my), 1.0 - smoothstep(0.02, 0.05, min(mx, 1.0 - mx)));
		col *= 0.9 + 0.2 * dh(vec2(floor(bx), row + seed));
		col = mix(col, col * 0.35, mortar);
	}
	float bl = smoothstep(0.56, 0.64, df(sp * 1.6 + vec2(4.2, 1.3)));
	col *= 1.0 - 0.18 * bl;
	float spk = step(0.93, dh(floor(sp * 9.0)));
	col *= 1.0 - 0.25 * spk;
	float ty = top_y - 0.1 - n * 0.12;
	if (lp.y > ty) {
		col = topc * (0.88 + 0.24 * n) * COLOR.rgb;
	}
	float tone = 1.0;
	if (d < 0.38) {
		tone = 0.76;
	}
	if (d < -0.12) {
		tone = 0.56;
	}
	col *= tone;
	if (tone < 0.6) {
		col *= vec3(0.9, 0.92, 1.06);
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""

## Koyu kontur: ters kabuk (arka yüzler), düzgün yön (TANGENT'a gömülü ortalama normal) boyunca şişirilir
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform float ow = 0.03;
uniform vec3 ocol = vec3(0.09, 0.065, 0.05);

void vertex() {
	float sc = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	VERTEX += TANGENT * (ow / sc);
}

void fragment() {
	ALBEDO = pow(ocol, vec3(2.2));
}
"""

## Doton çamuru: ıslak, ağır kahve; iki tonlu cel + sert parlama bandı + kenar karartma; melt > 0 iken delinerek erir
const MUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

instance uniform vec3 mcol = vec3(0.36, 0.25, 0.16);
instance uniform float seed = 0.0;
instance uniform float melt = 0.0;

DNOISE

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vd = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 ld = normalize(vec3(0.42, 0.82, 0.38));
	float n = df(lp.xz * 3.0 + vec2(lp.y * 2.0 - TIME * 0.6, seed));
	if (melt > 0.0 && n < melt) {
		discard;
	}
	float d = dot(wn, ld) + (n - 0.5) * 0.3;
	vec3 col = mcol * COLOR.rgb;
	float tone = 1.0;
	if (d < 0.3) {
		tone = 0.72;
	}
	if (d < -0.2) {
		tone = 0.52;
	}
	col *= tone;
	vec3 hv = normalize(ld + vd);
	float sp = pow(max(dot(wn, hv), 0.0), 40.0);
	float hl = step(0.55, sp + (n - 0.5) * 0.25);
	col = mix(col, mcol * 1.9 + vec3(0.12), hl * 0.85);
	float rim = 1.0 - max(dot(wn, vd), 0.0);
	col = mix(col, col * 0.55, step(0.78, rim));
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""

## Anime toz topu: kameraya dönük, kabarık loblu kenar, sol üstten ışık / sağ alt gölge, ince koyu kontur; fade ile delinerek dağılır
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec3 dcol = vec3(0.84, 0.76, 0.6);
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

DNOISE

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float lobes = 0.8 + 0.09 * sin(ang * 5.0 + seed * 6.0) + 0.05 * sin(ang * 9.0 + seed * 3.1) + 0.08 * (dn(vec2(ang * 1.6, seed)) - 0.5);
	if (r > lobes) {
		discard;
	}
	float k = r / lobes;
	float hn = df(p * 2.4 + vec2(seed * 4.0, seed));
	float cut = fade * 1.25 - 0.15 + k * 0.25 * fade;
	if (hn < cut) {
		discard;
	}
	vec2 ldir = normalize(vec2(-0.55, -0.75));
	float sh = dot(p, -ldir) + (dn(p * 3.0 + vec2(seed)) - 0.5) * 0.55;
	vec3 col = dcol * 1.06;
	if (sh > 0.12) {
		col = dcol * vec3(0.72, 0.7, 0.72);
	}
	float inner = sin(ang * 3.0 + seed) * 0.5 + 0.5;
	if (k > 0.55 && k < 0.62 && inner > 0.6 && sh > -0.3) {
		col = dcol * 0.6;
	}
	if (k > 0.93 || hn < cut + 0.025) {
		col = dcol * 0.5;
	}
	float near = smoothstep(1.5, 6.0, -VERTEX.z);
	float soft = 1.0 - smoothstep(0.7, 1.0, k) * 0.35;
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
	ALPHA = 0.58 * near * soft;
}
"""

## Zemin izi: mode 0 çatlak ağı (twist: sarmal), 1 çukur, 2 toprak dalgası (zemin su gibi), 3 çamur gölü
const GROUND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float gmode = 0.0;
instance uniform float grow = 1.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform float twist = 0.0;
instance uniform float branches = 7.0;
instance uniform vec3 soil = vec3(0.6, 0.48, 0.34);
instance uniform float phase = 0.0;

DNOISE

vec4 crack(vec2 p, float gr, float sd, float tw, float br, vec3 sl) {
	float r = length(p);
	if (r > gr) {
		return vec4(0.0);
	}
	float ang = atan(p.y, p.x);
	float a = ang + tw * r + (dn(vec2(r * 5.0, sd * 3.0)) - 0.5) * 0.6;
	float sec = a * br / 6.2831853;
	float id = floor(sec);
	float ln = 0.55 + 0.45 * dh(vec2(mod(id, br), sd));
	float da = abs(fract(sec) - 0.5) * 6.2831853 / br * r;
	float w = mix(0.045, 0.006, clamp(r / max(ln, 0.01), 0.0, 1.0));
	float inside = step(r, ln * gr);
	float line = (1.0 - step(w, da)) * inside;
	float lip = (1.0 - step(w * 2.6, da)) * inside;
	float cn = df(p * 4.0 + vec2(sd * 5.0));
	float web = (1.0 - step(0.022 * (1.0 - r), abs(cn - 0.5))) * step(r, 0.75 * gr);
	line = max(line, web);
	float stain = 1.0 - smoothstep(0.0, 0.5, r);
	vec4 o = vec4(sl * 0.7, stain * 0.35);
	if (lip > 0.5) {
		o = vec4(sl * 1.15, 0.85);
	}
	if (line > 0.5) {
		o = vec4(vec3(0.07, 0.05, 0.04), 1.0);
	}
	return o;
}

vec4 pit(vec2 p, float gr, float sd, vec3 sl) {
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = (0.55 + 0.12 * dn(vec2(ang * 2.5 + sd, sd))) * gr;
	float rimr = edge + 0.18 * gr;
	if (r > rimr + 0.25) {
		return vec4(0.0);
	}
	if (r < edge) {
		float k = r / max(edge, 0.001);
		return vec4(mix(vec3(0.03, 0.025, 0.02), sl * 0.35, smoothstep(0.55, 1.0, k)), 1.0);
	}
	if (r < rimr) {
		float cl = step(0.5, df(p * 7.0 + vec2(sd)));
		return vec4(sl * (cl > 0.5 ? 1.12 : 0.85), 1.0);
	}
	float sec = ang * 9.0 / 6.2831853 + sd;
	float da = abs(fract(sec) - 0.5) * 0.7 * r;
	if (da < 0.012 && dh(vec2(floor(sec), sd)) > 0.4) {
		return vec4(vec3(0.08, 0.06, 0.05), 0.9);
	}
	return vec4(0.0);
}

vec4 ripple(vec2 p, float ph, float sd, vec3 sl) {
	float r = length(p);
	if (r > 1.0) {
		return vec4(0.0);
	}
	float w = sin(r * 7.0 - ph * 6.2831853 + (dn(p * 3.0 + vec2(sd)) - 0.5) * 1.2);
	float env = (1.0 - r) * smoothstep(0.0, 0.15, r);
	if (w > 0.72) {
		return vec4(sl * 1.18, 0.85 * env);
	}
	if (w < -0.8) {
		return vec4(sl * 0.55, 0.7 * env);
	}
	return vec4(0.0);
}

vec4 puddle(vec2 p, float gr, float sd, float t) {
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = (0.7 + 0.18 * dn(vec2(ang * 2.0 + sd, sd)) + 0.06 * sin(ang * 7.0 + sd)) * gr;
	if (r > edge) {
		return vec4(0.0);
	}
	vec3 mud = vec3(0.3, 0.21, 0.13);
	float k = r / max(edge, 0.001);
	vec3 col = mix(mud, mud * 0.75, smoothstep(0.75, 0.95, k));
	float hl = df(vec2(p.x * 3.0 + t * 0.15, p.y * 1.2) + vec2(sd));
	col = mix(col, vec3(0.62, 0.5, 0.38), step(0.7, hl) * (1.0 - k));
	vec2 cell = floor(p * 5.0);
	vec2 fc = fract(p * 5.0) - 0.5;
	float bt = fract(t * 0.5 + dh(cell + vec2(sd)));
	float brad = 0.25 * bt * step(0.7, dh(cell * 1.7));
	float ring = step(abs(length(fc) - brad), 0.04) * step(0.05, brad);
	col = mix(col, mud * 1.6, ring);
	if (k > 0.94) {
		col = mud * 0.45;
	}
	return vec4(col, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec4 o = vec4(0.0);
	if (gmode < 0.5) {
		o = crack(p, grow, seed, twist, branches, soil);
	} else if (gmode < 1.5) {
		o = pit(p, grow, seed, soil);
	} else if (gmode < 2.5) {
		o = ripple(p, phase + TIME * 0.8, seed, soil);
	} else {
		o = puddle(p, grow, seed, TIME);
	}
	if (o.a < 0.01) {
		discard;
	}
	ALBEDO = pow(clamp(o.rgb, 0.0, 1.0), vec3(2.2));
	ALPHA = o.a * (1.0 - fade);
}
"""

## Çamur seli gövdesi (UV.x enine 0..1, UV.y boyuna metre; ağ kabarık kesitli): ıslak koyu kahve, yüzey normaline göre cel
## gölge, ileri akan koyu çizgiler + hızlı ıslak parıltı şeritleri, kenarda ince kontur; head ilerledikçe açılır, fade ile kurur
const FLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

instance uniform float head = 0.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform vec3 base = vec3(0.46, 0.33, 0.2);

DNOISE

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = UV.y;
	float edge = 0.86 + 0.13 * dn(vec2(y * 0.7 + seed, seed));
	if (abs(x) > edge) {
		discard;
	}
	float xe = x / edge;
	float fy = head - 0.8 * (1.0 - sqrt(max(1.0 - xe * xe, 0.0)));
	if (y > fy) {
		discard;
	}
	float n = df(vec2(x * 4.0, y * 0.9) + vec2(seed));
	if (n < fade) {
		discard;
	}
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (wn.y < 0.0) {
		wn = -wn;
	}
	float d = dot(wn, normalize(vec3(0.42, 0.82, 0.38)));
	vec3 col = base;
	float s = df(vec2(x * 5.0 + seed, (y - abs(x) * 1.3) * 0.6 - TIME * 2.4));
	if (s > 0.6) {
		col = base * vec3(0.62, 0.55, 0.5);
	}
	float g = df(vec2(x * 9.0 - seed, (y - abs(x) * 0.8) * 1.4 - TIME * 4.2));
	if (g > 0.68 && d > 0.55) {
		col = base * 1.55 + vec3(0.06);
	}
	if (d < 0.5) {
		col *= 0.74;
	}
	if (d < 0.1) {
		col *= 0.78;
	}
	float ed = edge - abs(x);
	if (ed < 0.025 || n < fade + 0.025) {
		col = base * 0.35;
	}
	if (fade > 0.0) {
		col = mix(col, col * vec3(1.25, 1.18, 1.08), fade);
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""


# ================================================================== malzemeler
static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("DNOISE", DNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func outline_mat(ow: float, col := Color(0.09, 0.065, 0.05)) -> ShaderMaterial:
	var key = "ol_%.3f_%s" % [ow, col.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var base: ShaderMaterial = _shader_mat("ol_base", OUTLINE_SHADER)
	var m = ShaderMaterial.new()
	m.shader = base.shader
	m.set_shader_parameter("ow", ow)
	m.set_shader_parameter("ocol", Vector3(col.r, col.g, col.b))
	_cache[key] = m
	return m


## Kaya malzemesi (ow > 0: koyu konturlu)
static func rock_mat(ow := 0.035) -> ShaderMaterial:
	var key = "rock_%.3f" % ow
	if _cache.has(key):
		return _cache[key]
	var base: ShaderMaterial = _shader_mat("rock_base", ROCK_SHADER)
	var m = ShaderMaterial.new()
	m.shader = base.shader
	if ow > 0.0:
		m.next_pass = outline_mat(ow)
	_cache[key] = m
	return m


static func mud_mat(ow := 0.03) -> ShaderMaterial:
	var key = "mud_%.3f" % ow
	if _cache.has(key):
		return _cache[key]
	var base: ShaderMaterial = _shader_mat("mud_base", MUD_SHADER)
	var m = ShaderMaterial.new()
	m.shader = base.shader
	if ow > 0.0:
		m.next_pass = outline_mat(ow, Color(0.08, 0.05, 0.03))
	_cache[key] = m
	return m


static func dust_mat() -> ShaderMaterial:
	return _shader_mat("dust", DUST_SHADER)


static func ground_mat() -> ShaderMaterial:
	return _shader_mat("ground", GROUND_SHADER)


static func flow_mat() -> ShaderMaterial:
	return _shader_mat("flow", FLOW_SHADER)


## Çakıl tanesi parçacık malzemesi (parçacık rengi)
static func grit_mat() -> StandardMaterial3D:
	if _cache.has("grit"):
		return _cache["grit"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	_cache["grit"] = m
	return m


# ================================================================== zemin rengi
## Noktanın zemin paleti: top (üst örtü), body (toprak gövdesi), deep (derin katman), dust (toz), stone (sert kaya), mud (ıslak çamur)
static func pal(p: Vector3) -> Dictionary:
	var o = {"top": Color(0.42, 0.56, 0.27), "body": Color(0.56, 0.43, 0.3), "deep": Color(0.4, 0.3, 0.21),
		"dust": Color(0.86, 0.77, 0.6), "stone": Color(0.42, 0.42, 0.4), "mud": Color(0.36, 0.25, 0.16)}
	if Game.world == null:
		return o
	var it = Interiors.inst
	if it and it.inside != "":
		o["top"] = Color(0.5, 0.46, 0.4)
		o["body"] = Color(0.5, 0.46, 0.42)
		o["dust"] = Color(0.78, 0.74, 0.68)
		return o
	var b = Game.biome_at(p.x, p.z)
	if b in [1, 3, 13]:
		o["top"] = Color(0.9, 0.8, 0.58)
		o["body"] = Color(0.8, 0.66, 0.45)
		o["deep"] = Color(0.66, 0.5, 0.33)
		o["dust"] = Color(0.95, 0.86, 0.66)
		o["stone"] = Color(0.62, 0.52, 0.4)
		o["mud"] = Color(0.5, 0.38, 0.24)
	elif b in [8, 15]:
		o["top"] = Color(0.93, 0.95, 1.0)
		o["body"] = Color(0.52, 0.52, 0.56)
		o["deep"] = Color(0.4, 0.4, 0.45)
		o["dust"] = Color(0.92, 0.94, 0.98)
		o["stone"] = Color(0.46, 0.47, 0.52)
	elif b in [5, 9, 14]:
		o["top"] = Color(0.62, 0.6, 0.56)
		o["body"] = Color(0.53, 0.5, 0.46)
		o["deep"] = Color(0.4, 0.38, 0.36)
		o["dust"] = Color(0.8, 0.78, 0.74)
		o["stone"] = Color(0.4, 0.4, 0.4)
	elif Game.road_at(p.x, p.z) > 0.3:
		o["top"] = Color(0.66, 0.55, 0.4)
	return o


static func v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


# ================================================================== temel yardımcılar
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


static func flat(d: Vector3) -> Vector3:
	var f = Vector3(d.x, 0.0, d.z)
	if f.length() < 0.01:
		return Vector3.FORWARD
	return f.normalized()


static func look(n: Node3D, dirv: Vector3) -> void:
	if not is_instance_valid(n) or dirv.length() < 0.0001:
		return
	var f = dirv.normalized()
	n.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT)


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["quad"] = q
	return _cache["quad"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache["plane"] = p
	return _cache["plane"]


# ================================================================== geometri
## Köşeli yüzlü ağ: v köşeler, tris üçgen indeksleri (yön önemsiz: want(merkez) dışa bakan yönü verir, üçgen ona göre çevrilir).
## Düz (yüz yüz) normal; TANGENT'a ortalama normal gömülür (kontur şişirmesi için). smooth: yumuşak normal (çamur).
static func facet(v: PackedVector3Array, tris: PackedInt32Array, want: Callable, cols := PackedColorArray(), smooth := false) -> ArrayMesh:
	var nv = v.size()
	var acc = PackedVector3Array()
	acc.resize(nv)
	var order = PackedInt32Array()
	order.resize(tris.size())
	var fns = PackedVector3Array()
	for t in range(0, tris.size(), 3):
		var ia = tris[t]
		var ib = tris[t + 1]
		var ic = tris[t + 2]
		var a = v[ia]
		var b = v[ib]
		var c = v[ic]
		var nrm = (b - a).cross(c - a)
		var wv: Vector3 = want.call((a + b + c) / 3.0)
		if nrm.dot(wv) < 0.0:
			var tmp = ib
			ib = ic
			ic = tmp
			nrm = -nrm
		order[t] = ia
		order[t + 1] = ib
		order[t + 2] = ic
		var nn = nrm.normalized() if nrm.length() > 0.0000001 else Vector3.UP
		fns.append(nn)
		acc[ia] = acc[ia] + nn
		acc[ib] = acc[ib] + nn
		acc[ic] = acc[ic] + nn
	var pv = PackedVector3Array()
	var pn = PackedVector3Array()
	var pt = PackedFloat32Array()
	var pc = PackedColorArray()
	var has_c = cols.size() == nv
	for t in range(0, order.size(), 3):
		var fn: Vector3 = fns[t / 3]
		for k in [0, 2, 1]:   # Godot ön yüzü saat yönünde
			var idx = order[t + k]
			pv.append(v[idx])
			var sm: Vector3 = acc[idx]
			sm = sm.normalized() if sm.length() > 0.0001 else fn
			pn.append(sm if smooth else fn)
			pt.append_array([sm.x, sm.y, sm.z, 1.0])
			pc.append(cols[idx] if has_c else Color(1, 1, 1))
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_NORMAL] = pn
	arr[Mesh.ARRAY_TANGENT] = pt
	arr[Mesh.ARRAY_COLOR] = pc
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Girintili çember dış hattı (XZ)
static func jag_circle(r: float, n: int, jit: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var o = PackedVector2Array()
	for i in n:
		var a = TAU * (i + rng.randf_range(-0.25, 0.25)) / n
		var rr = r * (1.0 + rng.randf_range(-jit, jit))
		o.append(Vector2(cos(a), sin(a)) * rr)
	return o


## Kenarları yontulmuş dikdörtgen dış hattı (XZ): w en (x), d derinlik (z), per kenar başına ara nokta, jit kenar girintisi
static func jag_rect(w: float, d: float, per: int, jit: float, rng: RandomNumberGenerator, z0 := -999.0) -> PackedVector2Array:
	var o = PackedVector2Array()
	var hz0 = -d * 0.5 if z0 < -998.0 else z0
	var hz1 = hz0 + d
	var hx = w * 0.5
	var corners = [Vector2(-hx, hz0), Vector2(hx, hz0), Vector2(hx, hz1), Vector2(-hx, hz1)]
	var cen = Vector2(0.0, (hz0 + hz1) * 0.5)
	for s in 4:
		var a: Vector2 = corners[s]
		var b: Vector2 = corners[(s + 1) % 4]
		for i in per + 1:
			var k = float(i) / float(per + 1)
			var q = a.lerp(b, k)
			if i == 0:
				q = q.lerp(cen, rng.randf_range(0.03, 0.09))   # köşe yontuğu
			else:
				q += (q - cen).normalized() * rng.randf_range(-jit, jit * 0.4)
			o.append(q)
	return o


## Pahlı prizma: outline XZ dış hattı, y0 alt, y1 üst, bevel kenar pahı (boy oranı), jit üst yüz dalgası
static func prism_mesh(outline: PackedVector2Array, y0: float, y1: float, bevel := 0.15, jit := 0.08, sd := 0, smooth := false) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var n = outline.size()
	var v = PackedVector3Array()
	var bv = (y1 - y0) * bevel
	for ring in 4:
		for i in n:
			var o = outline[i]
			var y = y0
			var s = 0.86
			if ring == 1:
				y = y0 + bv
				s = 1.0
			elif ring == 2:
				y = y1 - bv + rng.randf_range(-jit, jit) * 0.5
				s = 1.0
			elif ring == 3:
				y = y1 + rng.randf_range(-jit, jit)
				s = 0.86 + rng.randf_range(-0.05, 0.05)
			v.append(Vector3(o.x * s, y, o.y * s))
	var cen2 = Vector2.ZERO
	for o in outline:
		cen2 += o
	cen2 /= maxf(1.0, float(n))
	var cb = v.size()
	v.append(Vector3(cen2.x, y0, cen2.y))
	var ct = v.size()
	v.append(Vector3(cen2.x + rng.randf_range(-0.05, 0.05), y1 + rng.randf_range(0.0, jit), cen2.y + rng.randf_range(-0.05, 0.05)))
	var tris = PackedInt32Array()
	for ring in 3:
		for i in n:
			var j = (i + 1) % n
			var a = ring * n + i
			var b = ring * n + j
			var c = (ring + 1) * n + j
			var d = (ring + 1) * n + i
			tris.append_array([a, b, c, a, c, d])
	for i in n:
		var j = (i + 1) % n
		tris.append_array([cb, j, i])
		tris.append_array([ct, 3 * n + i, 3 * n + j])
	var mid = Vector3(cen2.x, (y0 + y1) * 0.5, cen2.y)
	return facet(v, tris, func(cp: Vector3) -> Vector3: return cp - mid, PackedColorArray(), smooth)


## Birim parça ağları (önbellekli): kind 0 yuvarlak kaya, 1 sivri kıymık, 2 köşeli blok, 3 yumuşak çamur topağı. sc: ölçek
static func chunk_mesh(kind: int, variant: int, sc := 1.0) -> ArrayMesh:
	var key = "ch_%d_%d_%.3f" % [kind, variant % 6, sc]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7919 * (kind + 1) + 131 * (variant % 6) + 17
	var m: ArrayMesh
	if kind == 2:
		var ol = jag_circle(0.62 * sc, 5 + (variant % 2), 0.18, rng)
		m = prism_mesh(ol, -0.42 * sc, 0.42 * sc, 0.2, 0.1 * sc, rng.randi())
	else:
		var seg = 6 if kind != 3 else 8
		var elev = [-0.95, -0.32, 0.32, 0.95] if kind != 3 else [-1.1, -0.55, 0.0, 0.55, 1.1]
		var v = PackedVector3Array()
		v.append(Vector3(rng.randf_range(-0.1, 0.1), -1.0, rng.randf_range(-0.1, 0.1)))
		for e in elev:
			var off = rng.randf_range(0.0, TAU)
			for i in seg:
				var a = off + TAU * (i + rng.randf_range(-0.2, 0.2)) / seg
				var rr = rng.randf_range(0.82, 1.12) if kind != 3 else rng.randf_range(0.9, 1.06)
				v.append(Vector3(cos(a) * cos(e) * rr, sin(e) * rr, sin(a) * cos(e) * rr))
		v.append(Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12)))
		var nr = elev.size()
		var top = v.size() - 1
		var tris = PackedInt32Array()
		for i in seg:
			var j = (i + 1) % seg
			tris.append_array([0, 1 + j, 1 + i])
			tris.append_array([top, 1 + (nr - 1) * seg + i, 1 + (nr - 1) * seg + j])
		for r in nr - 1:
			for i in seg:
				var j = (i + 1) % seg
				var a = 1 + r * seg + i
				var b = 1 + r * seg + j
				var c = 1 + (r + 1) * seg + j
				var d = 1 + (r + 1) * seg + i
				tris.append_array([a, b, c, a, c, d])
		var ys = 0.78
		if kind == 1:
			ys = 1.5
		elif kind == 3:
			ys = 0.85
		for i in v.size():
			var q = v[i]
			q.y *= ys
			if kind == 1:
				q.x *= 0.62
				q.z *= 0.62
				if i == top:
					q = Vector3(q.x + 0.15, 2.1, q.z)
			v[i] = q * sc
		m = facet(v, tris, func(cp: Vector3) -> Vector3: return cp, PackedColorArray(), kind == 3)
	_cache[key] = m
	return m


## Ağızlı kubbe kabuğu: R dış yarıçap, thick kalınlık, squash dikey basık, açıklık yerel +Z yönünde (open_half yarım açı,
## open_h açıklığın tepe yüksekliği R oranı). Dış yüz yumrulu kaya, iç yüz koyu (köşe rengi), açıklık kenarında kesik yüzler.
static func shell_mesh(R: float, thick: float, squash: float, open_half: float, open_h: float, sd: int) -> ArrayMesh:
	var key = "shell_%.2f_%.2f_%.2f_%.2f_%.2f_%d" % [R, thick, squash, open_half, open_h, sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var nt = 22
	var ne = 7
	var v = PackedVector3Array()
	var cols = PackedColorArray()
	var ph = rng.randf_range(0.0, TAU)
	# dış ve iç ızgara köşeleri; e = 0..ne-1 halkalar, tepe ayrı
	for side in 2:
		for j in ne:
			var e = (PI * 0.5) * 0.93 * float(j) / float(ne - 1)
			for i in nt:
				var th = TAU * float(i) / float(nt)
				var dirv = Vector3(sin(th) * cos(e), sin(e), cos(th) * cos(e))
				var lump = 0.08 * sin(th * 3.0 + ph) * cos(e * 2.0 + ph) + 0.06 * sin(th * 7.0 + e * 4.0 + ph * 2.0) + rng.randf_range(-0.035, 0.035)
				var rr = R * (1.0 + lump) if side == 0 else (R - thick) * (1.0 + lump * 0.35)
				var q = dirv * rr
				q.y *= squash
				v.append(q)
				cols.append(Color(1, 1, 1) if side == 0 else Color(0.42, 0.4, 0.4))
	var top_o = v.size()
	v.append(Vector3(0, R * squash * 1.02, 0))
	cols.append(Color(1, 1, 1))
	var top_i = v.size()
	v.append(Vector3(0, (R - thick) * squash, 0))
	cols.append(Color(0.42, 0.4, 0.4))
	var base_i = ne * nt
	var removed = {}
	for j in ne - 1:
		for i in nt:
			var thc = TAU * (float(i) + 0.5) / float(nt)
			var dth = wrapf(thc, -PI, PI)
			var ec = (PI * 0.5) * 0.93 * (float(j) + 0.5) / float(ne - 1)
			var k = dth / open_half
			if absf(k) < 1.0 and sin(ec) < open_h * sqrt(1.0 - k * k):
				removed[Vector2i(i, j)] = true
	var tris = PackedInt32Array()
	var wants = []   # üçgen başına istenen yön türü: 0 dış, 1 iç, 2 kenar (açıklığa doğru)
	for j in ne - 1:
		for i in nt:
			if removed.has(Vector2i(i, j)):
				continue
			var i2 = (i + 1) % nt
			var a = j * nt + i
			var b = j * nt + i2
			var c = (j + 1) * nt + i2
			var d = (j + 1) * nt + i
			tris.append_array([a, b, c, a, c, d])
			wants.append_array([0, 0])
			tris.append_array([base_i + a, base_i + b, base_i + c, base_i + a, base_i + c, base_i + d])
			wants.append_array([1, 1])
	for i in nt:
		var i2 = (i + 1) % nt
		var a = (ne - 1) * nt + i
		var b = (ne - 1) * nt + i2
		tris.append_array([top_o, a, b])
		wants.append(0)
		tris.append_array([top_i, base_i + a, base_i + b])
		wants.append(1)
	# açıklık kenarı: kaldırılan hücrenin kalan komşusuyla ortak kenarına dış-iç arası yüz
	var rim_c = []
	for key2 in removed.keys():
		var cell: Vector2i = key2
		var i = cell.x
		var j = cell.y
		var i2 = (i + 1) % nt
		var edges = []
		if not removed.has(Vector2i((i - 1 + nt) % nt, j)):
			edges.append([j * nt + i, (j + 1) * nt + i])
		if not removed.has(Vector2i(i2, j)):
			edges.append([j * nt + i2, (j + 1) * nt + i2])
		if j + 1 < ne - 1 and not removed.has(Vector2i(i, j + 1)):
			edges.append([(j + 1) * nt + i, (j + 1) * nt + i2])
		if j + 1 >= ne - 1:
			edges.append([(j + 1) * nt + i, (j + 1) * nt + i2])
		var thc = TAU * (float(i) + 0.5) / float(nt)
		var ec = (PI * 0.5) * 0.93 * (float(j) + 0.5) / float(ne - 1)
		var cc = Vector3(sin(thc) * cos(ec), sin(ec) * squash, cos(thc) * cos(ec)) * (R - thick * 0.5)
		for ed in edges:
			var oa: int = ed[0]
			var ob: int = ed[1]
			tris.append_array([oa, ob, base_i + ob, oa, base_i + ob, base_i + oa])
			wants.append_array([2, 2])
			rim_c.append(cc)
			rim_c.append(cc)
	var ti = {"k": 0, "r": 0}
	var mesh = facet(v, tris, func(cp: Vector3) -> Vector3:
		var w: int = wants[ti["k"]]
		ti["k"] += 1
		if w == 0:
			return cp
		if w == 1:
			return -cp
		var c2: Vector3 = rim_c[ti["r"]]
		ti["r"] += 1
		return c2 - cp, cols)
	_cache[key] = mesh
	return mesh


## Zemini izleyen şerit ağı: pts orta hat (zemin üstünde), widths her noktada tam en, side yatay yan yön. UV.x 0..1 enine, UV.y metre.
## heights verilirse kesit kabarık (ortada o yükseklik, kenarda zemine iner; çamur seli gövdesi)
static func strip_mesh(pts: PackedVector3Array, widths: PackedFloat32Array, side: Vector3, lift := 0.07, heights := PackedFloat32Array()) -> ArrayMesh:
	var nc = 11 if heights.size() == pts.size() else 2
	var pv = PackedVector3Array()
	var nrm = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	var dist = 0.0
	for i in pts.size():
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var w = widths[i] * 0.5
		var H = heights[i] if nc > 2 else 0.0
		for j in nc:
			var x = -1.0 + 2.0 * float(j) / float(nc - 1)
			var q = pts[i] + side * w * x
			var pr = pow(maxf(1.0 - x * x, 0.0), 0.6)
			q.y = Game.jutsu_floor(q.x, q.z) + lift + H * pr
			pv.append(q)
			var xc = clampf(x, -0.97, 0.97)
			var dh = H * 0.6 * pow(1.0 - xc * xc, -0.4) * (-2.0 * xc) / maxf(w, 0.1)
			nrm.append((Vector3.UP - side * dh).normalized())
			uv.append(Vector2((x + 1.0) * 0.5, dist))
		if i > 0:
			var r0 = (i - 1) * nc
			var r1 = i * nc
			for j in nc - 1:
				idx.append_array([r0 + j, r0 + j + 1, r1 + j + 1, r0 + j, r1 + j + 1, r1 + j])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# ================================================================== yapı taşları: kütle
## Kaya düğümü: mesh + gövde rengi; o: top (üst örtü rengi), top_y (nesne uzayı üst sınır), strata (m başına şerit), brick, ow, shadow
static func rock(mesh: Mesh, body: Color, o := {}) -> MeshInstance3D:
	var mi = gi(mesh, rock_mat(float(o.get("ow", 0.035))))
	mi.set_instance_shader_parameter("body", v3(body))
	mi.set_instance_shader_parameter("seed", randf() * 30.0)
	if o.has("top"):
		mi.set_instance_shader_parameter("topc", v3(o["top"]))
		mi.set_instance_shader_parameter("top_y", float(o.get("top_y", 0.4)))
	mi.set_instance_shader_parameter("strata", float(o.get("strata", 0.0)))
	mi.set_instance_shader_parameter("brick", 1.0 if o.get("brick", false) else 0.0)
	if o.get("shadow", false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## Hazır parça: s boy, kind (0 yuvarlak, 1 kıymık, 2 blok), rastgele varyant ve yön
static func chunk(s: float, kind: int, col: Color, o := {}) -> MeshInstance3D:
	var mi = rock(chunk_mesh(kind, randi() % 6), col, o)
	mi.scale = Vector3.ONE * s
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU) if not o.get("upright", false) else Vector3(0, randf() * TAU, 0)
	return mi


## Doton çamur topağı (yumuşak, ıslak parlak)
static func mud_blob(s: float, col: Color, ow := 0.03) -> MeshInstance3D:
	var mi = gi(chunk_mesh(3, randi() % 6), mud_mat(ow))
	mi.set_instance_shader_parameter("mcol", v3(col))
	mi.set_instance_shader_parameter("seed", randf() * 30.0)
	mi.set_instance_shader_parameter("melt", 0.0)
	mi.scale = Vector3.ONE * s
	mi.rotation.y = randf() * TAU
	return mi


## Yerden fırlayıp (t_up) bekleyen (hold) ve geri gömülen (t_down) kütle; depth: başlangıç gömülme derinliği
static func rise(host: Node, mi: Node3D, p: Vector3, depth: float, t_up: float, hold: float, t_down: float, delay := 0.0) -> void:
	put(host, mi, p - Vector3.UP * depth)
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(mi, "global_position", p, t_up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(mi, "global_position", p - Vector3.UP * depth, t_down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Fırlayan parça: yerçekimiyle uçar, döner, yere değince durur; sink sn içinde toprağa gömülüp silinir
static func toss(host: Node, mi: Node3D, p0: Vector3, v: Vector3, life: float, g := 18.0, sink := 0.8) -> void:
	put(host, mi, p0)
	var spin = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	var r0 = mi.rotation
	var stt = {"land": false}
	var tw = mi.create_tween()
	tw.tween_method(func(tm: float) -> void:
		if not is_instance_valid(mi) or stt["land"]:
			return
		var pos = p0 + v * tm + Vector3.DOWN * 0.5 * g * tm * tm
		var fy = Game.jutsu_floor(pos.x, pos.z) + 0.04
		if pos.y < fy and tm > 0.06 and v.y - g * tm < 0.0:
			pos.y = fy
			stt["land"] = true
		mi.global_position = pos
		mi.rotation = r0 + spin * tm, 0.0, life, life)
	tw.tween_callback(func():
		if is_instance_valid(mi):
			var t2 = mi.create_tween()
			t2.tween_property(mi, "position", mi.position + Vector3.DOWN * 0.5, sink).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t2.tween_callback(mi.queue_free))


## Halka halinde dışa savrulan parçalar: n adet, s boy, hız aralığı, up dikey pay
static func burst_chunks(host: Node, p: Vector3, n: int, s: float, spd: float, col: Color, up := 0.8, kind := -1, life := 1.0) -> void:
	for i in n:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / maxf(1.0, float(n))
		var dv = Vector3(cos(a), up * randf_range(0.6, 1.4), sin(a)).normalized()
		var k = kind if kind >= 0 else (randi() % 3)
		var mi = chunk(s * randf_range(0.6, 1.3), k, col.darkened(randf_range(0.0, 0.18)), {"ow": 0.03})
		toss(host, mi, p + Vector3(cos(a), 0.1, sin(a)) * s * 0.6, dv * spd * randf_range(0.7, 1.15), life)


# ================================================================== yapı taşları: toz, çakıl
## Tek toz topu: s son çap, life ömür, vel sürüklenme (yavaşlayarak)
static func dust(host: Node, p: Vector3, s: float, life: float, vel := Vector3.ZERO, col := Color(0.86, 0.77, 0.6)) -> MeshInstance3D:
	s *= 0.6   # okunurluk: toz efekti örtmesin
	var cam = host.get_viewport().get_camera_3d() if host.is_inside_tree() else null
	if cam and cam.global_position.distance_to(p) < 2.5 + s * 0.5:
		return null
	var mi = gi(_quad(), dust_mat())
	mi.set_instance_shader_parameter("dcol", v3(col))
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	put(host, mi, p)
	mi.scale = Vector3.ONE * s * 0.35
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", p + vel * life * 0.6, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 0.0, 1.0, life * 0.62).set_delay(life * 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Dışa yayılan toz halkası (yer seviyesi): r0 → r1 yarıçap, n top
static func dust_ring(host: Node, c: Vector3, r0: float, r1: float, n: int, s: float, life: float, col: Color) -> void:
	var cam = host.get_viewport().get_camera_3d() if host.is_inside_tree() else null
	var tc = flat(cam.global_position - c) if cam else Vector3.ZERO
	for i in n:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / maxf(1.0, float(n))
		var dv = Vector3(cos(a), 0.0, sin(a))
		if dv.dot(tc) > 0.3 and randf() < 0.8:   # kamera tarafındaki toz efekti örtmesin
			continue
		var p = floor_at(c + dv * r0) + Vector3.UP * s * 0.35
		dust(host, p, s * randf_range(0.8, 1.2), life * randf_range(0.85, 1.15), dv * (r1 - r0) / maxf(0.1, life * 0.6) + Vector3.UP * randf_range(0.2, 0.8), col)


## İnce çakıl taneleri (GPU parçacık): n tane, o: dir, spread, vmin, vmax, g, r, life, size
static func grit(host: Node, p: Vector3, n: int, col: Color, o := {}) -> GPUParticles3D:
	var life = float(o.get("life", 0.9))
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 50.0))
	pm.initial_velocity_min = float(o.get("vmin", 3.0))
	pm.initial_velocity_max = float(o.get("vmax", 8.0))
	pm.gravity = Vector3(0, -float(o.get("g", 18.0)), 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, float(o.get("r", 0.3)))
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.color = col
	var ps = GPUParticles3D.new()
	ps.process_material = pm
	ps.amount = maxi(1, n)
	ps.lifetime = life
	ps.one_shot = true
	ps.explosiveness = float(o.get("burst", 1.0))
	ps.local_coords = false
	ps.draw_pass_1 = chunk_mesh(0, 1, float(o.get("size", 0.06)))
	ps.material_override = grit_mat()
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.visibility_aabb = AABB(Vector3(-10, -6, -10), Vector3(20, 16, 20))
	put(host, ps, p)
	ps.emitting = true
	kill(host, life + 0.4, ps)
	return ps


# ================================================================== yapı taşları: zemin izi
static func _decal(host: Node, p: Vector3, r: float, mode: float, sl: Color) -> MeshInstance3D:
	var mi = gi(_plane(), ground_mat())
	mi.set_instance_shader_parameter("gmode", mode)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	mi.set_instance_shader_parameter("soil", v3(sl))
	put(host, mi, floor_at(p) + Vector3.UP * 0.05)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r, 1.0, r)
	return mi


## Yarılan çatlak ağı: r yarıçap, life kalış, grow_t açılma, twist sarmal (0 düz), br kol sayısı
static func crack(host: Node, p: Vector3, r: float, life: float, grow_t := 0.25, twist := 0.0, br := 7.0) -> MeshInstance3D:
	var mi = _decal(host, p, r, 0.0, pal(p)["body"])
	mi.set_instance_shader_parameter("twist", twist)
	mi.set_instance_shader_parameter("branches", br)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, grow_t).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, life - grow_t - 1.0))
	tw.tween_method(pf(mi, "fade"), 0.0, 1.0, 1.0)
	tw.tween_callback(mi.queue_free)
	return mi


## Çukur / delik (sx, sz ile uzatılabilir)
static func pit(host: Node, p: Vector3, r: float, life: float, open_t := 0.2, stretch := Vector2.ONE) -> MeshInstance3D:
	var mi = _decal(host, p, r, 1.0, pal(p)["body"])
	mi.scale = Vector3(r * stretch.x, 1.0, r * stretch.y)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, open_t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, life - open_t - 0.8))
	tw.tween_method(pf(mi, "grow"), 1.0, 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Toprak dalgası: zemin su gibi halka halka dalgalanır
static func ripple(host: Node, p: Vector3, r: float, life: float) -> MeshInstance3D:
	var mi = _decal(host, p, r * 0.4, 2.0, pal(p)["body"])
	mi.set_instance_shader_parameter("grow", 1.0)
	mi.set_instance_shader_parameter("phase", randf())
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(r, 1.0, r), life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 0.0, 1.0, life * 0.6).set_delay(life * 0.4)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Doton çamur gölü: kabarcıklı ıslak çamur, sonra kuruyup söner
static func puddle(host: Node, p: Vector3, r: float, life: float) -> MeshInstance3D:
	var mi = _decal(host, p, r, 3.0, pal(p)["mud"])
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, life - 1.05))
	tw.tween_method(pf(mi, "fade"), 0.0, 1.0, 0.8)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== Doton B grubu eklemeleri (2026-11-17)
## Döner profil (lathe) ağı: prof = Vector2(r, y) noktaları, alttan dış kenardan başlayıp yukarı / içe doğru (sıra yüz yönünü verir).
## folds > 0: gövdeye o kadar dikey sırt / kıvrım (katlanmış toprak, oluklu yamaç), depth sırt payı (yarıçap oranı), jit pürüz.
## arc < TAU: yalnız o açı kadar gövde (+Z ekseni ortada), iki kesik yüz düz kapanır (yarım kubbe vb.). Önbellekli.
static func lathe_mesh(prof: PackedVector2Array, nt: int, folds := 0.0, depth := 0.0, jit := 0.03, sd := 0, arc := TAU) -> ArrayMesh:
	var key = "lathe_%d_%d_%.2f_%.2f_%.3f_%d_%.3f" % [hash(prof), nt, folds, depth, jit, sd, arc]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var full = arc >= TAU - 0.001
	var cols = nt if full else nt + 1
	var np = prof.size()
	var ph = rng.randf()
	var step_a = arc / float(nt)
	var ths = PackedFloat32Array()
	var fm = PackedFloat32Array()
	for i in cols:
		var th = step_a * float(i) - (0.0 if full else arc * 0.5)
		ths.append(th)
		var u = th * folds / TAU + ph + 0.12 * sin(th * 3.0 + ph * 6.0)
		fm.append(1.0 - 2.0 * absf(fposmod(u, 1.0) - 0.5))   # 0 oluk .. 1 sırt
	var v = PackedVector3Array()
	for j in np:
		var p = prof[j]
		for i in cols:
			var th = ths[i]
			var rr = p.x
			var yy = p.y
			if rr > 0.001:
				rr *= 1.0 + depth * (fm[i] - 0.5) + rng.randf_range(-jit, jit)
				yy += rng.randf_range(-jit, jit) * 0.5
			v.append(Vector3(sin(th) * rr, yy, cos(th) * rr))
	var tris = PackedInt32Array()
	var wants = []
	for j in np - 1:
		var dr = prof[j + 1].x - prof[j].x
		var dy = prof[j + 1].y - prof[j].y
		var n2 = Vector2(dy, -dr)
		for i in nt:
			var i2 = (i + 1) % cols
			var a = j * cols + i
			var b = j * cols + i2
			var c = (j + 1) * cols + i2
			var d = (j + 1) * cols + i
			var thc = ths[i] + step_a * 0.5
			var w = Vector3(n2.x * sin(thc), n2.y, n2.x * cos(thc))
			tris.append_array([a, b, c, a, c, d])
			wants.append(w)
			wants.append(w)
	if not full:
		var ax0 = v.size()
		for j in np:
			v.append(Vector3(0.0, prof[j].y, 0.0))
		for e in 2:
			var ci = 0 if e == 0 else nt
			var th = ths[ci]
			var tdir = Vector3(cos(th), 0.0, -sin(th))
			var w = -tdir if e == 0 else tdir
			for j in np - 1:
				var a = j * cols + ci
				var d = (j + 1) * cols + ci
				tris.append_array([a, d, ax0 + j + 1, a, ax0 + j + 1, ax0 + j])
				wants.append(w)
				wants.append(w)
	var ti = {"k": 0}
	var mesh = facet(v, tris, func(_cp: Vector3) -> Vector3:
		var w: Vector3 = wants[ti["k"]]
		ti["k"] += 1
		return w)
	_cache[key] = mesh
	return mesh


## Bataklık yüzeyi (düz disk, PlaneMesh ölçeğiyle): koyu ıslak kahve, yavaşça dönerek sürüklenen koyu hilal çizgiler + açık
## ıslak parıltı, girintili kenarda koyu kontur ve kabarık ıslak dudak; grow ile açılır, fade ile delinerek kurur
const SWAMP_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float grow = 1.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform vec3 mcol = vec3(0.42, 0.28, 0.16);

DNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = grow * (0.84 + 0.1 * dn(vec2(ang * 2.2 + seed, seed)) + 0.03 * sin(ang * 9.0 + seed));
	if (r > edge) {
		discard;
	}
	float k = r / max(edge, 0.001);
	float sw = TIME * 0.1 * (1.3 - k) + seed;
	float cs = cos(sw);
	float sn = sin(sw);
	vec2 q = vec2(p.x * cs - p.y * sn, p.x * sn + p.y * cs) * 3.2;
	q += vec2(dn(q * 0.7 + vec2(seed)), dn(q * 0.7 + vec2(seed + 3.0))) * 0.9;
	float s = df(vec2(q.x * 1.3, q.y * 5.5) + vec2(seed * 2.0, TIME * 0.05));
	vec3 col = mcol;
	if (s > 0.6) {
		col = mcol * 0.6;
	}
	if (s > 0.6 && s < 0.625) {
		col = mcol * 0.42;
	}
	float g = df(vec2(q.x * 2.1 - TIME * 0.08, q.y * 7.0) + vec2(seed * 5.0));
	if (g < 0.28 && s < 0.5) {
		col = mcol * 1.22 + vec3(0.03);
	}
	if (k > 0.9) {
		col = mcol * 1.1;
	}
	if (k > 0.96) {
		col = mcol * 0.4;
	}
	float hn = df(p * 4.0 + vec2(seed * 3.0));
	if (fade > 0.0 && hn < fade) {
		discard;
	}
	if (fade > 0.0) {
		col = mix(col, col * vec3(1.3, 1.22, 1.1), fade);
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""


static func swamp_mat() -> ShaderMaterial:
	return _shader_mat("swamp", SWAMP_SHADER)


## Düz zemin diski (PlaneMesh 2x2; ölçekle yarıçap verilir) — örn. bataklık yüzeyi
static func disc(host: Node, p: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi = gi(_plane(), mat)
	put(host, mi, floor_at(p) + Vector3.UP * 0.06)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r, 1.0, r)
	return mi


## Toprağa sızan / emilen chakra zerresi malzemesi: katkılı, gölgesiz düz renk (toprak dışı tek parlak öğe)
static func bead_mat(col: Color) -> StandardMaterial3D:
	var key = "bead_" + col.to_html(true)
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true   # parçacık rengi / saydamlık rampası çarpan olarak
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


# ================================================================== Doton C grubu eklemeleri (2026-11-17)
## Beden kaplaması (material_overlay): karakterin GERÇEK ağına yapışır, kabuk / kutu yok. Derili yerel konum uzayında 3B Voronoi
## hücreleri. smode 0 taş plaka (hücre başına ton, cel gölge, koyu yarık + aydınlık pah; spread: ayaktan yukarı kaplanan boy m),
## 1 kararmış sert deri (Domu: kömür karası, ince açık yarık, sert parlama şeridi; spread: göğüsten yayılan yarıçap m),
## 2 taş klon (yalnız yarık çizgileri; fill > 0 iken hücreler taş dolu, tek tek dökülür), 3 kuru toprak sıvası (drain
## yüksekliğinin üstü damla kenarla açılır). cell: m başına hücre sıklığı (ince doku: iri leke yok).
const SKIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float smode = 0.0;
uniform float spread = 9.0;
uniform float fill = 0.0;
uniform float drain = 9.0;
uniform vec3 tint = vec3(0.62, 0.66, 0.7);
uniform float cell = 7.0;

varying vec3 lp;

float sh31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec3 sh33(vec3 p) {
	return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}

vec4 vor(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	vec3 cid = vec3(0.0);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + sh33(i + g) - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					cid = i + g;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec4(sqrt(d1), sqrt(d2), sh31(cid), sh31(cid + vec3(7.1)));
}

void vertex() {
	float s = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	lp = VERTEX * s;
	VERTEX += NORMAL * 0.006 / s;
}

void fragment() {
	vec4 v = vor(lp * cell);
	float edge = v.y - v.x;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = dot(wn, normalize(vec3(0.42, 0.82, 0.38)));
	float wob = sin(lp.x * 23.0 + lp.z * 17.0) * 0.04 + (v.z - 0.5) * 0.08;
	vec3 col = tint;
	if (smode < 0.5) {
		if (lp.y > spread + wob) {
			discard;
		}
		col = tint * (0.86 + 0.24 * v.z);
		if (d < 0.3) {
			col *= 0.72;
		}
		if (d < -0.2) {
			col *= 0.82;
		}
		if (edge < 0.07) {
			col = tint * 0.28;
		} else if (edge < 0.13 && d > 0.3) {
			col = tint * 1.2;
		}
		if (lp.y > spread + wob - 0.035) {
			col = tint * 0.3;
		}
	} else if (smode < 1.5) {
		float r = length(lp - vec3(0.0, 1.25, 0.0));
		if (r > spread + wob * 2.0) {
			discard;
		}
		col = tint * (0.9 + 0.2 * v.z);
		float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		if (d < 0.2) {
			col *= 0.7;
		}
		if (edge < 0.055) {
			col = tint * 2.3 + vec3(0.05);
		}
		float band = step(0.94, sin((lp.y + lp.x * 0.4) * 26.0 + v.w * 6.0)) * step(0.35, d) * step(fr, 0.55);
		col = mix(col, vec3(0.6, 0.58, 0.56), band * 0.75);
		if (fr > 0.84) {
			col *= 0.5;
		}
	} else if (smode < 2.5) {
		bool stone = v.z < fill;
		if (!stone && edge > 0.045) {
			discard;
		}
		col = tint * 0.32;
		if (stone && edge >= 0.045) {
			col = tint * (0.85 + 0.25 * v.w);
			if (d < 0.3) {
				col *= 0.74;
			}
		}
	} else {
		float drip = sh31(floor(vec3(lp.x * 26.0, 0.0, lp.z * 26.0))) * 0.22;
		if (lp.y > drain - drip) {
			discard;
		}
		col = tint * (0.88 + 0.22 * v.z);
		if (d < 0.3) {
			col *= 0.74;
		}
		if (edge < 0.05) {
			col = tint * 0.45;
		}
		if (lp.y > drain - drip - 0.03) {
			col = tint * 0.55;
		}
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""


## Yeni beden kaplaması malzemesi (kişi başına ayrı: parametreleri ayrı ayrı tween'lenir; shader paylaşılır)
static func skin_mat(smode: int, tint: Color, cell := 7.0) -> ShaderMaterial:
	var base: ShaderMaterial = _shader_mat("skin_base", SKIN_SHADER)
	var m = ShaderMaterial.new()
	m.shader = base.shader
	m.set_shader_parameter("smode", float(smode))
	m.set_shader_parameter("tint", v3(tint))
	m.set_shader_parameter("cell", cell)
	return m


## Kaplamayı modelin kendi ağlarına giydir (zaten kaplaması olan / kemiğe iliştirilmiş ek ağlara dokunmaz); kapladıklarının listesi
static func skin_apply(model: Node, m: Material) -> Array:
	var out = []
	if model == null or not is_instance_valid(model):
		return out
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g: MeshInstance3D = mi
		if g.material_overlay != null or not g.visible:
			continue
		var p = g.get_parent()
		var attached = false
		while p != null and p != model:
			if p is BoneAttachment3D:
				attached = true
				break
			p = p.get_parent()
		if attached:
			continue
		g.material_overlay = m
		out.append(weakref(g))
	return out


## Kaplamayı kaldır (yalnız hâlâ bizimkiyse)
static func skin_clear(list: Array, m: Material) -> void:
	for w in list:
		var x = w.get_ref()
		if x != null and is_instance_valid(x) and x.material_overlay == m:
			x.material_overlay = null


## Sivri kaya mızrağı (gerçek boyutlu ağ: doku iri lekeye dönmez): h boy, r taban yarıçapı, sides yüz sayısı; taban y = -0.15h
static func spike_mesh(h: float, r: float, sides: int, sd: int) -> ArrayMesh:
	var key = "spike_%.2f_%.2f_%d_%d" % [h, r, sides, sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var rings = [[-0.15, 1.0], [0.3, 0.72], [0.62, 0.42], [0.86, 0.16]]
	var v = PackedVector3Array()
	var tw = rng.randf_range(-0.4, 0.4)
	var lean = Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08)) * h
	for ri in rings.size():
		var y: float = rings[ri][0] * h
		var rr: float = rings[ri][1] * r
		var k = clampf(rings[ri][0], 0.0, 1.0)
		for i in sides:
			var a = TAU * (i + rng.randf_range(-0.18, 0.18)) / sides + tw * k
			var q = rr * rng.randf_range(0.85, 1.12)
			v.append(Vector3(cos(a) * q + lean.x * k * k, y + rng.randf_range(-0.04, 0.04) * h * k, sin(a) * q + lean.y * k * k))
	var tip = v.size()
	v.append(Vector3(lean.x, h, lean.y))
	var bot = v.size()
	v.append(Vector3(0, -0.15 * h, 0))
	var tris = PackedInt32Array()
	var nr = rings.size()
	for ri in nr - 1:
		for i in sides:
			var j = (i + 1) % sides
			tris.append_array([ri * sides + i, ri * sides + j, (ri + 1) * sides + j, ri * sides + i, (ri + 1) * sides + j, (ri + 1) * sides + i])
	for i in sides:
		var j = (i + 1) % sides
		tris.append_array([tip, (nr - 1) * sides + i, (nr - 1) * sides + j])
		tris.append_array([bot, j, i])
	var m = facet(v, tris, func(cp: Vector3) -> Vector3:
		if cp.y < -0.14 * h:
			return Vector3.DOWN
		var kk = clampf(cp.y / h, 0.0, 1.0)
		var o = cp - Vector3(lean.x * kk * kk, cp.y, lean.y * kk * kk)
		return o + Vector3.UP * 0.25 * o.length())
	_cache[key] = m
	return m


## Uzun altıgen çift piramit kristal (birim: taban ucu y=0, tepe ucu y=1.6, bel yarıçapı ~0.42)
static func crystal_mesh(sd := 0) -> ArrayMesh:
	var key = "crystal_%d" % sd
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 991 + sd
	var v = PackedVector3Array()
	for ring in 2:
		var y = 0.45 if ring == 0 else 1.05
		for i in 6:
			var a = TAU * (i + rng.randf_range(-0.12, 0.12)) / 6.0
			var rr = 0.42 * rng.randf_range(0.85, 1.1) * (1.0 if ring == 0 else 0.86)
			v.append(Vector3(cos(a) * rr, y + rng.randf_range(-0.05, 0.05), sin(a) * rr))
	var bot = v.size()
	v.append(Vector3(0, 0, 0))
	var top = v.size()
	v.append(Vector3(rng.randf_range(-0.05, 0.05), 1.6, rng.randf_range(-0.05, 0.05)))
	var tris = PackedInt32Array()
	for i in 6:
		var j = (i + 1) % 6
		tris.append_array([i, j, 6 + j, i, 6 + j, 6 + i])
		tris.append_array([bot, j, i])
		tris.append_array([top, 6 + i, 6 + j])
	var m = facet(v, tris, func(cp: Vector3) -> Vector3: return cp - Vector3(0, clampf(cp.y, 0.3, 1.2), 0))
	_cache[key] = m
	return m


## Kristal: yüz yüz düz cel (açık / orta / koyu yüz), sert beyaz parlama yüzü ve yüzeyde çapraz açık iç çizgiler
const CRYSTAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

instance uniform vec3 ccol = vec3(0.9, 0.2, 0.15);

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vd = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 ld = normalize(vec3(0.42, 0.82, 0.38));
	float d = dot(wn, ld);
	vec3 col = ccol;
	if (d > 0.45) {
		col = ccol * 1.3 + vec3(0.08);
	} else if (d < -0.1) {
		col = ccol * 0.55;
	}
	float sp = pow(max(dot(wn, normalize(ld + vd)), 0.0), 18.0);
	if (sp > 0.45) {
		col = vec3(1.0, 0.94, 0.92);
	}
	float st = fract(lp.y * 2.6 + lp.x * 3.1 + lp.z * 1.7);
	if (st < 0.07 && d > -0.2) {
		col = mix(col, vec3(1.0, 0.9, 0.88), 0.65);
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""


static func crystal_mat() -> ShaderMaterial:
	return _shader_mat("crystal", CRYSTAL_SHADER)


## Dört kollu parıltı yıldızı (kameraya dönük, katkılı): glow 0..1
const STAR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float glow = 1.0;
instance uniform vec3 scol = vec3(1.0, 0.97, 0.95);

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ax = abs(p.x);
	float ay = abs(p.y);
	float arm = max(1.0 - ax * 9.0 - ay * 1.05, 0.0) + max(1.0 - ay * 9.0 - ax * 1.05, 0.0);
	float core = max(1.0 - length(p) * 3.2, 0.0);
	float a = clamp(arm * 1.6 + core * 2.0, 0.0, 1.0) * glow;
	if (a < 0.02) {
		discard;
	}
	ALBEDO = scol * a;
	ALPHA = a;
}
"""


static func star_mat() -> ShaderMaterial:
	return _shader_mat("star", STAR_SHADER)


## Kaya kenarı chakra parıltısı (katkılı; facet ağlarının TANGENT'ındaki ortalama normale göre kenarda yanar)
const EDGE_GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

instance uniform vec3 gcol = vec3(0.5, 0.85, 1.0);
instance uniform float gpow = 1.0;

varying vec3 sn;

void vertex() {
	float s = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	VERTEX += TANGENT * (0.012 / s);
	sn = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
}

void fragment() {
	float fr = 1.0 - clamp(abs(dot(normalize(sn), VIEW)), 0.0, 1.0);
	float k = smoothstep(0.4, 0.8, fr) * gpow;
	if (k < 0.01) {
		discard;
	}
	ALBEDO = gcol * k;
	ALPHA = k;
}
"""


static func edge_glow_mat() -> ShaderMaterial:
	return _shader_mat("edge_glow", EDGE_GLOW_SHADER)


## Yarık (zemini izleyen strip_mesh üstünde; UV.x enine, UV.y boyuna m): koyu derin iç, açık kırık toprak dudağı, girintili kenar;
## open (m) boyunca açılır, gape açıklık oranı, fade ile kapanır
const RIFT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float open = 0.0;
instance uniform float gape = 1.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform vec3 soil = vec3(0.56, 0.43, 0.3);

DNOISE

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = UV.y;
	if (y > open) {
		discard;
	}
	float w = (0.3 + 0.32 * dn(vec2(y * 1.4 + seed, seed)) + 0.08 * sin(y * 7.0 + seed)) * gape * (1.0 - fade);
	w *= clamp((open - y) * 1.2, 0.0, 1.0);
	float lip = w + (0.14 + 0.08 * dn(vec2(y * 3.0, seed + 4.0))) * (1.0 - fade);
	float ax = abs(x);
	if (ax > lip) {
		discard;
	}
	vec3 col = soil;
	if (ax < w) {
		float k = ax / max(w, 0.001);
		col = mix(vec3(0.03, 0.022, 0.018), soil * 0.3, smoothstep(0.6, 1.0, k));
	} else {
		float cl = step(0.5, df(vec2(x * 8.0, y * 3.0) + vec2(seed)));
		col = soil * (cl > 0.5 ? 1.12 : 0.82);
		if (ax > lip - 0.03) {
			col = soil * 0.4;
		}
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""


static func rift_mat() -> ShaderMaterial:
	return _shader_mat("rift", RIFT_SHADER)
