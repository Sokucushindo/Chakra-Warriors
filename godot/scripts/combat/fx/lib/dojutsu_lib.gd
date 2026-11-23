class_name DojutsuLib
extends RefCounted
## Dōjutsu (göz teknikleri: Rinnegan yolları, Sharingan / Mangekyō genjutsuları) malzeme / yapı taşı kütüphanesi.
## Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları ve kendi ürettiği geometri / dokularıdır:
##   cel gövde   : düz iki ton (ışık / gölge), kenar bandı, koyu ters-kabuk kontur, piksel bloklu dağılma (fade),
##                 kameraya çok yakın kısım noktalı inceltilir (ekranı kaplamaz)
##   hayalet     : saydam, kenarı parlak gövde — düz / dokuma ağ (emme bariyeri) / ruh tülü / akan çizgi (bağ ışını)
##   bükülme     : ekran dokusunu kıran görünmez kuvvet — küre (itme / çekme) ve kamera yüzlü dalga halkası (uzay kıvrımı)
##   disk        : düz desenler — Rinnegan halkaları, genjutsu damarları, karga girdabı, çağırma mühür yazısı, çatlak / krater,
##                 Sharingan, Shisui Mangekyō'su, tutulma koronası, tırtıklı parlama, mürekkep lekesi
##   göz parıltısı: kullanıcının GERÇEK göz konumunda (kafa kemiği) parlayan Sharingan / Rinnegan / kararan göz
##   karga + tüy : tırtıklı kara karga silueti (kanat çırpar) ve kendi çizdiğimiz tüy dokusu
##   genjutsu katmanı: kurbanın altında dönen damar deseni + yükselen mürekkep tülleri (+ kurban oyuncuysa dünya rengi)
## Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası yalnız malzeme + yapı taşı verir.

static var _cache := {}

const RIN := Color(0.74, 0.66, 0.96)
const RIN_DEEP := Color(0.36, 0.26, 0.6)
const RIN_LINE := Color(0.13, 0.07, 0.24)
const SHA := Color(0.86, 0.06, 0.08)
const SHA_DARK := Color(0.1, 0.0, 0.02)
const INK := Color(0.035, 0.03, 0.045)
const SOUL := Color(0.9, 0.9, 1.0)
const SOUL_EDGE := Color(0.66, 0.52, 1.0)
const DUST := Color(0.62, 0.54, 0.43)
const ROCK := [Color(0.5, 0.43, 0.35), Color(0.45, 0.4, 0.36), Color(0.56, 0.48, 0.38), Color(0.4, 0.36, 0.33)]

# ================================================================== shader kodları
const NOISE := """
float dh(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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

float dfbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * dn(p);
		p = p * 2.03 + vec2(5.1, 1.7);
		a *= 0.5;
	}
	return s;
}
"""

## Cel gövde: köşe rengi × tint, düz iki ton, kenar bandı, piksel bloklu dağılma, kameraya yakın noktalı inceltme
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, CULLMODE;

uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 shade_mul = vec3(0.62, 0.6, 0.72);
uniform vec3 rim_col : source_color = vec3(0.0);
uniform float rim_amt = 0.0;
uniform float glow = 0.0;
uniform float use_vcol = 1.0;
uniform float near_fade = 1.4;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

NOISE

void fragment() {
	float dist = -VERTEX.z;
	if (dist < near_fade && dh(floor(FRAGCOORD.xy) + vec2(seed)) > dist / near_fade) {
		discard;
	}
	if (fade > 0.001 && dh(floor(FRAGCOORD.xy * 0.25) + vec2(seed, 3.0)) < fade) {
		discard;
	}
	vec3 vc = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	vec3 base = tint * mix(vec3(1.0), vc, use_vcol);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = dot(wn, normalize(vec3(0.4, 0.85, 0.35)));
	vec3 col = base;
	if (d < 0.08) {
		col *= shade_mul;
	}
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(col, rim_col, step(0.64, fr) * rim_amt);
	ALBEDO = col * (1.0 + glow);
}
"""

## Koyu kontur: ters kabuk (normal boyunca şişer, dünya kalınlığı ölçekten bağımsız); gövdeyle aynı dağılma
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec3 col : source_color = vec3(0.0);
uniform float width = 0.03;
uniform float near_fade = 1.4;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

NOISE

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += NORMAL * width / max(sc, vec3(0.001));
}

void fragment() {
	float dist = -VERTEX.z;
	if (dist < near_fade && dh(floor(FRAGCOORD.xy) + vec2(seed)) > dist / near_fade) {
		discard;
	}
	if (fade > 0.001 && dh(floor(FRAGCOORD.xy * 0.25) + vec2(seed, 3.0)) < fade) {
		discard;
	}
	ALBEDO = col;
}
"""

## Hayalet: saydam, kenarı parlak. pattern 0 düz, 1 dokuma ağ (emme bariyeri), 2 ruh tülü, 3 akan çizgiler (bağ ışını)
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 core : source_color = vec3(0.9, 0.9, 1.0);
uniform vec3 edge : source_color = vec3(0.6, 0.5, 1.0);
uniform float a_in = 0.15;
uniform float a_edge = 0.85;
uniform float pattern = 0.0;
uniform float flow = 0.6;
uniform float glow = 0.0;
instance uniform float fade = 0.0;
instance uniform float flare = 0.0;

NOISE

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float dist = -VERTEX.z;
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float e = smoothstep(0.42, 0.9, fr);
	vec3 c = mix(core, edge, e);
	float a = mix(a_in, a_edge, e);
	if (pattern > 0.5 && pattern < 1.5) {
		vec2 uv = UV * vec2(56.0, 28.0) + vec2(TIME * flow, 0.0);
		float w1 = abs(sin(uv.x + uv.y + sin(uv.y * 0.31) * 2.0));
		float w2 = abs(sin(uv.x - uv.y + cos(uv.x * 0.27) * 2.0));
		float net = step(0.94, max(w1, w2));
		c = mix(c, vec3(1.0), net * 0.7);
		a += net * 0.3;
	} else if (pattern > 1.5 && pattern < 2.5) {
		float n = dfbm(vec2(lp.x * 4.0 + lp.z * 3.0, lp.y * 2.5 - TIME * flow));
		a *= 0.45 + n * 0.9;
		c = mix(c, edge, step(0.62, n) * 0.5);
	} else if (pattern > 2.5) {
		float s = fract(UV.y * 6.0 - TIME * flow * 4.0 + dh(floor(UV.xx * 5.0)) * 0.5);
		float band = smoothstep(0.0, 0.25, s) * (1.0 - smoothstep(0.55, 0.9, s));
		c = mix(c, vec3(1.0), band * 0.5);
		a *= 0.55 + band * 0.6;
	}
	c = mix(c, vec3(1.0), flare * 0.6);
	a = (a + flare * 0.4) * (1.0 - fade);
	a *= clamp((dist - 0.5) / 1.4, 0.0, 1.0);
	ALBEDO = c * (1.0 + glow);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Görünmez kuvvet küresi: arkasındaki dünyayı kenarda büker (itme > 0, çekme < 0); kenarda ince parıltı. İçeriden görünmez.
const FORCE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.04;
uniform vec3 edge_col : source_color = vec3(0.85, 0.95, 0.9);
uniform float edge_amt = 0.25;
uniform float rings = 0.0;
instance uniform float fade = 0.0;

void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float wave = fr * fr;
	if (rings > 0.0) {
		wave *= 0.55 + 0.45 * sin(fr * rings * 6.2832 - TIME * 14.0);
	}
	float dist = -VERTEX.z;
	float near = clamp((dist - 1.0) / 3.0, 0.0, 1.0);
	vec2 off = NORMAL.xy * vec2(1.0, -1.0) * wave * strength * (1.0 - fade) * near;
	vec3 bg = texture(scr, SCREEN_UV - off).rgb;
	float e = smoothstep(0.86, 0.985, fr) * edge_amt * (1.0 - fade) * near;
	ALBEDO = mix(bg, edge_col, e);
	ALPHA = 1.0;
}
"""

## Uzay kıvrımı: kamera yüzlü kare üstünde, prog yarıçapında halka biçimli ekran bükülmesi + ince çizgi
const RIPPLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_linear;
uniform float prog = 0.5;
uniform float width = 0.12;
uniform float strength = 0.035;
uniform vec3 line_col : source_color = vec3(0.8, 0.7, 1.0);
uniform float line_amt = 0.6;
uniform float fade = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float d = (r - prog) / width;
	float w = exp(-d * d * 2.5);
	float d2 = (r - prog * 0.62) / (width * 0.6);
	float w2 = exp(-d2 * d2 * 2.5) * 0.5;
	float ww = max(w, w2) * (1.0 - smoothstep(0.92, 1.0, r));
	if (ww < 0.01) {
		discard;
	}
	float dist = -VERTEX.z;
	float near = clamp((dist - 1.0) / 3.0, 0.0, 1.0);
	vec2 dir = q / max(r, 0.0001);
	vec2 off = dir * vec2(1.0, 1.0) * ww * strength * (1.0 - fade) * near;
	vec3 bg = texture(scr, SCREEN_UV + off).rgb;
	float ln = smoothstep(0.82, 1.0, w) * line_amt;
	ALBEDO = mix(bg, line_col, ln);
	ALPHA = clamp(smoothstep(0.0, 0.25, ww) * (1.0 - fade) * near, 0.0, 1.0);
}
"""

## Düz desen diski. mode: 0 Rinnegan halkaları, 1 genjutsu damarları, 2 karga girdabı, 3 çağırma mühür yazısı, 4 çatlak / krater,
## 5 Sharingan (üç tomoe), 6 Shisui Mangekyō (dört kanatlı fırıldak), 7 tutulma koronası, 8 tırtıklı parlama, 9 mürekkep lekesi
const DISC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform int mode = 0;
uniform vec3 c1 : source_color = vec3(1.0);
uniform vec3 c2 : source_color = vec3(0.0);
uniform vec3 c3 : source_color = vec3(0.0);
uniform float prog = 1.0;
uniform float alpha = 1.0;
uniform float spin = 0.0;
uniform float speed = 1.0;
uniform float count = 6.0;
uniform float bill = 0.0;
uniform float seed = 0.0;
uniform float near_cut = 1.5;

NOISE

mat2 rot(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

void vertex() {
	if (bill > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

float tomoe(vec2 q, float ang0) {
	vec2 cpos = vec2(cos(ang0), sin(ang0)) * 0.55;
	float head = 1.0 - step(0.13, length(q - cpos));
	float a = atan(q.y, q.x);
	float da = mod(a - ang0 + 6.2832, 6.2832);
	float tl = 0.0;
	if (da < 0.75) {
		float u = da / 0.75;
		float rr = 0.55 + 0.1 * u;
		tl = 1.0 - step(0.12 * (1.0 - u) + 0.008, abs(length(q) - rr));
	}
	return max(head, tl);
}

void fragment() {
	float dist = -VERTEX.z;
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	vec3 col = c1;
	float a = 0.0;
	if (mode == 0) {
		float rr = r / max(prog, 0.001);
		if (rr > 1.0) { discard; }
		float wave = fract(rr * count - TIME * speed);
		float ln = step(0.8, wave);
		col = mix(c1, c2, ln);
		col = mix(col, c2, 1.0 - step(0.12, rr));
		col = mix(col, c3, step(0.92, rr));
		a = alpha * (1.0 - smoothstep(0.97, 1.0, rr));
	} else if (mode == 1) {
		vec2 p = rot(r * 2.2 + TIME * 0.22 * speed + spin) * q;
		float n = dfbm(p * 2.6 + vec2(seed));
		float v = 1.0 - smoothstep(0.0, 0.045, abs(n - 0.5));
		float n2 = dfbm(p * 6.0 + vec2(seed + 11.0, 3.0));
		v = max(v, 1.0 - smoothstep(0.0, 0.03, abs(n2 - 0.5)));
		col = mix(c1, c2, v);
		col = mix(col, c3, (1.0 - smoothstep(0.0, 0.35, r)) * 0.5);
		a = alpha * mix(0.4, 0.95, v) * (1.0 - smoothstep(prog * 0.65, prog, r));
	} else if (mode == 2) {
		float b = sin(ang * 2.0 + r * 9.0 - TIME * speed * 2.0 + spin);
		col = mix(c1, c2, smoothstep(-0.25, 0.25, b));
		col = mix(col, c3, (1.0 - smoothstep(0.0, 0.3, r)) * 0.6);
		a = alpha * (1.0 - smoothstep(prog * 0.6, prog, r));
	} else if (mode == 3) {
		if (r > prog || r > 1.0) { discard; }
		float k = floor((ang + spin) / 6.2832 * count + 0.5);
		float sa = abs(fract((ang + spin) / 6.2832 * count + 0.5) - 0.5);
		float arc = sa * (6.2832 / count) * r;
		float dash = step(0.3, fract(r * 9.0 + dh(vec2(k, seed)) * 3.0));
		float spoke = (1.0 - step(0.022, arc)) * dash * step(0.26, r);
		float glyph = (1.0 - step(0.05, abs(arc - 0.05))) * step(0.5, fract(r * 13.0 + dh(vec2(k, 7.0)))) * step(0.3, r) * step(r, 0.9);
		float ring = (1.0 - step(0.018, abs(r - 0.22))) + (1.0 - step(0.012, abs(r - 0.27)));
		float m = clamp(spoke + glyph * 0.9 + ring, 0.0, 1.0);
		col = c1;
		a = alpha * m * (1.0 - smoothstep(prog - 0.04, prog, r));
	} else if (mode == 4) {
		if (r > prog || r > 1.0) { discard; }
		float j = dn(vec2(ang * 3.0 + seed, r * 4.0)) - 0.5;
		float aa = ang + j * 0.35;
		float sa = abs(fract(aa / 6.2832 * count + dh(vec2(seed, 1.0))) - 0.5);
		float arc = sa * (6.2832 / count) * r;
		float crk = 1.0 - step(0.012 + 0.03 * (1.0 - r), arc);
		crk *= step(0.12, r) * step(dn(vec2(ang * 9.0, r * 7.0 + seed)), 0.78);
		float pit = (1.0 - smoothstep(0.0, 0.55, r)) * 0.55;
		col = mix(c2, c1, crk);
		a = alpha * max(crk, pit) * (1.0 - smoothstep(prog * 0.8, prog, r));
	} else if (mode == 5) {
		if (r > 1.0) { discard; }
		vec2 p = rot(spin + TIME * speed) * q;
		col = c1;
		col = mix(col, c3, 1.0 - step(0.012, abs(r - 0.55)));
		float tm = max(tomoe(p, 0.0), max(tomoe(p, 2.0944), tomoe(p, 4.1888)));
		col = mix(col, c2, tm);
		col = mix(col, c2, 1.0 - step(0.16, r));
		col = mix(col, c2, step(0.9, r));
		a = alpha * (1.0 - smoothstep(0.97, 1.0, r)) * step(r, prog);
	} else if (mode == 6) {
		if (r > 1.0) { discard; }
		vec2 p = rot(spin + TIME * speed) * q;
		float pa = atan(p.y, p.x) + r * 1.6;
		float s = fract(pa / 6.2832 * 4.0);
		float blade = step(s, 0.42 * (1.0 - r * 0.45)) * step(0.12, r) * step(r, 0.9);
		col = mix(c1, c2, blade);
		col = mix(col, c2, step(0.9, r));
		col = mix(col, c3, 1.0 - step(0.1, r));
		a = alpha * (1.0 - smoothstep(0.97, 1.0, r)) * step(r, prog);
	} else if (mode == 7) {
		float rq = (r - 0.4) / 0.05;
		float ring = exp(-rq * rq);
		float gl = clamp(1.0 - (r - 0.4) / 0.55, 0.0, 1.0) * 0.55 * step(0.38, r);
		float ray = 0.0;
		float sa = abs(fract((ang + spin) / 6.2832 * count) - 0.5) * 2.0;
		float rl = 0.5 + dh(vec2(floor((ang + spin) / 6.2832 * count), seed)) * 0.5;
		ray = (1.0 - smoothstep(0.0, 0.18, sa)) * (1.0 - smoothstep(0.4, 0.4 + rl * 0.6, r)) * step(0.38, r);
		col = c1;
		a = alpha * clamp(ring + gl * gl + ray * 0.7, 0.0, 1.0);
	} else if (mode == 8) {
		float sp = fract((ang + spin) / 6.2832 * count + dn(vec2(ang * 2.0, seed)) * 0.4);
		float spike = pow(max(1.0 - abs(sp - 0.5) * 2.0, 0.0), 3.0);
		float R = mix(0.42, 1.0, spike) * prog;
		if (r > R) { discard; }
		float u = r / max(R, 0.001);
		col = mix(c2, c1, smoothstep(0.25, 0.7, u));
		col = mix(col, c3, step(0.9, u));
		a = alpha;
	} else {
		float R = 0.5 + 0.3 * (dn(vec2(ang * 1.6 + seed, seed)) - 0.5) * 2.0;
		vec2 cell = floor(q * 6.0);
		float drop = step(dh(cell + vec2(seed)), 0.12) * (1.0 - step(0.3, length(fract(q * 6.0) - 0.5))) * step(R, r) * step(r, 1.0);
		float m = max(1.0 - step(R * prog, r), drop * step(0.5, prog));
		if (m < 0.5) { discard; }
		col = c1;
		a = alpha;
	}
	if (dist < near_cut) {
		a *= clamp((dist - 0.4) / max(near_cut - 0.4, 0.01), 0.0, 1.0);
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


# ================================================================== malzemeler
static func _shader(key: String, code: String) -> Shader:
	var k = "sh_" + key
	if not _cache.has(k):
		var s = Shader.new()
		s.code = code.replace("NOISE", NOISE)
		_cache[k] = s
	return _cache[k]


static func line_mat(w: float, col: Color) -> ShaderMaterial:
	var k = "line_%.3f_%s" % [w, col.to_html()]
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _shader("line", LINE_SHADER)
		m.set_shader_parameter("width", w)
		m.set_shader_parameter("col", col)
		_cache[k] = m
	return _cache[k]


## Cel gövde malzemesi (ow > 0 ise koyu kontur next_pass). two_side: düz kanat / pul gibi yüzeyler için.
static func cel(key: String, tint: Color, o := {}) -> ShaderMaterial:
	var k = "cel_" + key
	if _cache.has(k):
		return _cache[k]
	var two = o.get("two_side", false)
	var m = ShaderMaterial.new()
	m.shader = _shader("cel2" if two else "cel", CEL_SHADER.replace("CULLMODE", "cull_disabled" if two else "cull_back"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("shade_mul", o.get("shade", Vector3(0.62, 0.6, 0.72)))
	m.set_shader_parameter("rim_col", o.get("rim", Color(0, 0, 0)))
	m.set_shader_parameter("rim_amt", float(o.get("rim_amt", 0.0)))
	m.set_shader_parameter("glow", float(o.get("glow", 0.0)))
	m.set_shader_parameter("use_vcol", 1.0 if o.get("vcol", true) else 0.0)
	var ow = float(o.get("ow", 0.03))
	if ow > 0.0:
		m.next_pass = line_mat(ow, o.get("ocol", INK))
	_cache[k] = m
	return m


static func ghost(key: String, core: Color, edge: Color, o := {}) -> ShaderMaterial:
	var k = "gh_" + key
	if _cache.has(k) and not o.get("unique", false):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shader("ghost", GHOST_SHADER)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("a_in", float(o.get("a_in", 0.15)))
	m.set_shader_parameter("a_edge", float(o.get("a_edge", 0.85)))
	m.set_shader_parameter("pattern", float(o.get("pattern", 0.0)))
	m.set_shader_parameter("flow", float(o.get("flow", 0.6)))
	m.set_shader_parameter("glow", float(o.get("glow", 0.0)))
	if not o.get("unique", false):
		_cache[k] = m
	return m


static func force_mat(strength: float, edge: Color, edge_amt := 0.25, rings := 0.0) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader("force", FORCE_SHADER)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("edge_col", edge)
	m.set_shader_parameter("edge_amt", edge_amt)
	m.set_shader_parameter("rings", rings)
	return m


## Yeni (paylaşılmayan) disk malzemesi: her disk kendi parametrelerini canlandırır
static func disc_mat(mode: int, c1: Color, c2 := Color(0, 0, 0), c3 := Color(0, 0, 0), o := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader("disc", DISC_SHADER)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("c1", c1)
	m.set_shader_parameter("c2", c2)
	m.set_shader_parameter("c3", c3)
	m.set_shader_parameter("prog", float(o.get("prog", 1.0)))
	m.set_shader_parameter("alpha", float(o.get("alpha", 1.0)))
	m.set_shader_parameter("spin", float(o.get("spin", 0.0)))
	m.set_shader_parameter("speed", float(o.get("speed", 1.0)))
	m.set_shader_parameter("count", float(o.get("count", 6.0)))
	m.set_shader_parameter("bill", 1.0 if o.get("bill", false) else 0.0)
	m.set_shader_parameter("seed", float(o.get("seed", randf() * 50.0)))
	m.set_shader_parameter("near_cut", float(o.get("near_cut", 1.5)))
	if o.has("prio"):
		m.render_priority = int(o["prio"])
	return m


# ================================================================== düğüm yardımcıları
static func put(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	host.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func kill(host: Node, sec: float, n: Node) -> void:
	var w = weakref(n)
	host.get_tree().create_timer(maxf(0.01, sec)).timeout.connect(func():
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


## Bir düğüm ağacındaki tüm gövdelerin örnek parametresini değiştiren fonksiyon (fade / flare)
static func pfn(root: Node, key := "fade") -> Callable:
	var list = []
	if root is GeometryInstance3D:
		list.append(root)
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		list.append(n)
	return func(v: float) -> void:
		for g in list:
			if is_instance_valid(g):
				g.set_instance_shader_parameter(key, v)


## Piksel bloklu dağılarak yok olma (cel / hayalet gövdeler)
static func dissolve(n: Node3D, delay: float, t: float) -> void:
	if not is_instance_valid(n):
		return
	var f = pfn(n)
	var tw = n.create_tween()
	tw.tween_interval(maxf(0.001, delay))
	tw.tween_method(f, 0.0, 1.0, t)
	tw.tween_callback(n.queue_free)


static func floor_at(p: Vector3) -> Vector3:
	return Game.jutsu_floor_at(p)


## Kare (düz) disk: ground = yere yatık, değilse kamera yüzlü (bill)
static func disc(host: Node, pos: Vector3, size: float, mat: ShaderMaterial, ground := true) -> MeshInstance3D:
	var qm = QuadMesh.new()
	qm.size = Vector2(size, size)
	if ground:
		qm.orientation = PlaneMesh.FACE_Y
	var mi = gi(qm, mat)
	put(host, mi, pos)
	return mi


static func sp(m: ShaderMaterial, key: String) -> Callable:
	return func(v: float) -> void:
		m.set_shader_parameter(key, v)


## Diski aç (prog 0→p1), tut, söndür (alpha → 0), sil
static func disc_life(mi: MeshInstance3D, t_in: float, hold: float, t_out: float, p1 := 1.0) -> void:
	var m: ShaderMaterial = mi.material_override
	var a0 = _sp0(m.get_shader_parameter("alpha"))
	var tw = mi.create_tween()
	tw.tween_method(sp(m, "prog"), 0.0, p1, maxf(0.01, t_in)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.001, hold))
	tw.tween_method(sp(m, "alpha"), a0, 0.0, maxf(0.01, t_out))
	tw.tween_callback(mi.queue_free)


## Uzay kıvrımı: kamera yüzlü halka bükülmesi. inward: halka dıştan merkeze çöker (yer değiştirme / emme)
static func ripple(host: Node, pos: Vector3, size: float, life: float, inward := false, col := RIN, strength := 0.035, line_amt := 0.6) -> MeshInstance3D:
	var m = ShaderMaterial.new()
	m.shader = _shader("ripple", RIPPLE_SHADER)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("line_col", col)
	m.set_shader_parameter("line_amt", line_amt)
	var qm = QuadMesh.new()
	qm.size = Vector2(size, size)
	var mi = gi(qm, m)
	put(host, mi, pos)
	var tw = mi.create_tween()
	tw.tween_method(sp(m, "prog"), 0.95 if inward else 0.05, 0.05 if inward else 0.92, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if inward else Tween.EASE_OUT)
	tw.parallel().tween_method(sp(m, "fade"), 0.0, 1.0, life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Görünmez kuvvet küresi: r0 → r1 büyür (itme) ya da küçülür (çekme); dünyayı kenarında büker
static func force_sphere(host: Node, pos: Vector3, r0: float, r1: float, life: float, strength := 0.05, edge := Color(0.85, 0.95, 0.92), rings := 0.0) -> MeshInstance3D:
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 40
	sm.rings = 20
	var mi = gi(sm, force_mat(strength, edge, 0.25, rings))
	put(host, mi, pos)
	mi.scale = Vector3.ONE * maxf(0.05, r0)
	var f = pfn(mi)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * maxf(0.05, r1), life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(f, 0.0, 1.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


static func light(host: Node, pos: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	put(host, l, pos)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## İki hareketli nokta arası ince bağ (silindir; her karede yeniden hizalanır). a_fn / b_fn: Vector3 döndüren Callable
static func beam(host: Node, a_fn: Callable, b_fn: Callable, width: float, life: float, mat: Material) -> MeshInstance3D:
	var cm = CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	var mi = gi(cm, mat)
	put(host, mi, a_fn.call())
	var tw = mi.create_tween()
	tw.tween_method(func(u: float):
		if not is_instance_valid(mi):
			return
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		var d = b - a
		var L = maxf(0.01, d.length())
		var y = d / L
		var ref = Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var x = ref.cross(y).normalized()
		var z = x.cross(y).normalized()
		var w = width * sin(clampf(u * 6.0, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.75, 1.0, u))
		mi.global_transform = Transform3D(Basis(x * w, y * L, z * w), a + d * 0.5), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== dokular + parçacık
static func _tex(kind: String) -> ImageTexture:
	var k = "tex_" + kind
	if _cache.has(k):
		return _cache[k]
	var S = 64
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 911
	for y in S:
		for x in S:
			var u = (x + 0.5) / S * 2.0 - 1.0
			var v = (y + 0.5) / S * 2.0 - 1.0
			var a = 0.0
			match kind:
				"mote":   # yumuşak nokta (kenarı sert çekirdek + hafif hale)
					var r = sqrt(u * u + v * v)
					a = clampf(1.0 - smoothstep(0.35, 0.45, r), 0.0, 1.0) + clampf(1.0 - r, 0.0, 1.0) * 0.3
				"feather":   # karga tüyü: uzun, uca sivrilen, tırtıklı kenar, ortada sap
					var t = (v + 1.0) * 0.5
					var w = sin(t * PI) * 0.42 * (1.0 - t * 0.35)
					var jag = 0.06 * sin(t * 40.0) * t
					a = 1.0 if absf(u) < w + jag else 0.0
					if absf(u) < 0.03 and t > 0.05:
						a = 0.55
				"glint":   # dört kollu parıltı yıldızı
					var r2 = sqrt(u * u + v * v)
					var arm = maxf(1.0 - smoothstep(0.0, 0.08, absf(u)) , 1.0 - smoothstep(0.0, 0.08, absf(v))) * (1.0 - r2)
					a = clampf(arm * 1.4 + (1.0 - smoothstep(0.0, 0.3, r2)), 0.0, 1.0)
				"dust":   # cel toz topağı: sert kenarlı, alt kısmı koyu
					var r3 = sqrt(u * u + v * v)
					var edge = 0.8 + 0.12 * sin(atan2(v, u) * 5.0)
					a = 1.0 if r3 < edge else 0.0
					if a > 0.0 and v > 0.25:
						a = 0.85
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var tex = ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex


static func pmat(kind: String, add := false) -> StandardMaterial3D:
	var k = "pm_%s_%s" % [kind, add]
	if _cache.has(k):
		return _cache[k]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _tex(kind)
	m.disable_receive_shadows = true
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.5
	m.distance_fade_max_distance = 2.0
	_cache[k] = m
	return m


static func _ramp(cols: Array) -> GradientTexture1D:
	var g = Gradient.new()
	g.set_color(0, cols[0])
	g.set_color(1, cols[cols.size() - 1])
	for i in range(1, cols.size() - 1):
		g.add_point(float(i) / (cols.size() - 1), cols[i])
	var gt = GradientTexture1D.new()
	gt.gradient = g
	return gt


static func _shrink() -> CurveTexture:
	if _cache.has("shrink"):
		return _cache["shrink"]
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 0.6))
	cv.add_point(Vector2(0.2, 1.0))
	cv.add_point(Vector2(1.0, 0.0))
	var ct = CurveTexture.new()
	ct.curve = cv
	_cache["shrink"] = ct
	return ct


## Parçacık patlaması / akışı (kendi dokularımız). o: amount life size vmin vmax dir spread gravity radius shell ring radial damp
## spin colors add tex loop(sn: süre boyunca sürekli) mesh(Mesh: 3B parça) explode
static func burst(host: Node, p: Vector3, o := {}) -> GPUParticles3D:
	var ps = GPUParticles3D.new()
	ps.amount = maxi(1, int(o.get("amount", 16)))
	ps.lifetime = float(o.get("life", 0.8))
	var loop = float(o.get("loop", 0.0))
	ps.one_shot = loop <= 0.0
	ps.explosiveness = float(o.get("explode", 0.0 if loop > 0.0 else 0.95))
	ps.local_coords = false
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm = ParticleProcessMaterial.new()
	var r = float(o.get("radius", 0.2))
	if o.get("ring", false):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = r
		pm.emission_ring_inner_radius = r * 0.85
		pm.emission_ring_height = 0.1
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE if o.get("shell", false) else ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = r
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 180.0))
	pm.initial_velocity_min = float(o.get("vmin", 1.0))
	pm.initial_velocity_max = float(o.get("vmax", 3.0))
	pm.gravity = o.get("gravity", Vector3.ZERO)
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0))
	pm.radial_accel_min = float(o.get("radial", 0.0))
	pm.radial_accel_max = float(o.get("radial", 0.0))
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var spn = float(o.get("spin", 0.0))
	pm.angular_velocity_min = -spn
	pm.angular_velocity_max = spn
	var s = float(o.get("size", 0.3))
	pm.scale_min = s * 0.6
	pm.scale_max = s
	pm.scale_curve = _shrink()
	pm.color_ramp = _ramp(o.get("colors", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	ps.process_material = pm
	if o.has("mesh"):
		ps.draw_pass_1 = o["mesh"]
	else:
		var qm = QuadMesh.new()
		qm.size = Vector2.ONE
		qm.material = pmat(String(o.get("tex", "mote")), o.get("add", false))
		ps.draw_pass_1 = qm
	var big = maxf(8.0, float(o.get("vmax", 3.0)) * ps.lifetime * 2.0 + r * 2.0)
	ps.visibility_aabb = AABB(Vector3.ONE * -big, Vector3.ONE * big * 2.0)
	put(host, ps, p)
	ps.emitting = true
	if loop > 0.0:
		var w = weakref(ps)
		host.get_tree().create_timer(loop).timeout.connect(func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x):
				x.emitting = false)
	kill(host, loop + ps.lifetime + 0.4, ps)
	return ps


## Toplanma: kabuktan merkeze çekilen tozlar (çekim kuvveti radyal ivmeyle; ömür sonunda merkezde)
static func gather(host: Node, p: Vector3, r: float, n: int, life: float, cols: Array, tex := "mote", add := true, size := 0.12) -> GPUParticles3D:
	return burst(host, p, {"amount": n, "life": life, "radius": r, "shell": true, "vmin": 0.0, "vmax": 0.2, "radial": -2.0 * r / (life * life) * 1.1,
		"size": size, "colors": cols, "tex": tex, "add": add, "explode": 0.3})


## 3B kaya kıymıkları (cel gövdeli, koyu konturlu); dir yönünde savrulur, yerçekimiyle düşer
static func chips(host: Node, p: Vector3, n: int, s: float, spd: float, dir := Vector3.UP, spread := 70.0, life := 1.2) -> void:
	burst(host, p, {"amount": n, "life": life, "radius": s, "vmin": spd * 0.5, "vmax": spd, "dir": dir, "spread": spread, "gravity": Vector3(0, -16, 0),
		"spin": 400.0, "size": s, "colors": [Color.WHITE, Color.WHITE], "mesh": rock_mesh(1.0, 3)})


# ================================================================== geometri
static func rock_mesh(s: float, sd := 0) -> ArrayMesh:
	var k = "rock_%.2f_%d" % [s, sd]
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	b.add("boulder", Vector3.ZERO, Vector3(s, s * 0.78, s), ROCK[sd % ROCK.size()], Vector3(sd * 37.0, sd * 71.0, 0), sd)
	var m = b.build(null)
	m.surface_set_material(0, cel("rock", Color.WHITE, {"ow": 0.04, "ocol": Color(0.12, 0.09, 0.07)}))
	_cache[k] = m
	return m


static func rock(s: float, tone: Color, sd := 0) -> MeshInstance3D:
	var b = MB.new()
	b.add("boulder", Vector3.ZERO, Vector3(s, s * 0.8, s), tone, Vector3(randf() * 360.0, randf() * 360.0, 0), sd % 8)
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(null)
	mi.material_override = cel("rock_big", Color.WHITE, {"ow": 0.07, "ocol": Color(0.12, 0.09, 0.07)})
	return mi


## Karga: tırtıklı kara silüet (gövde, gaga, yelpaze kuyruk, iki kanat düğümü — flap ile çırpar)
static func crow() -> Node3D:
	var root = Node3D.new()
	var body_m: ArrayMesh
	if _cache.has("crow_body"):
		body_m = _cache["crow_body"]
	else:
		var b = MB.new()
		b.add("sphere", Vector3(0, 0, 0), Vector3(0.16, 0.15, 0.36), INK, Vector3.ZERO, 8)
		b.add("sphere", Vector3(0, 0.05, -0.2), Vector3(0.12, 0.12, 0.13), INK, Vector3.ZERO, 8)
		b.add("cone", Vector3(0, 0.04, -0.3), Vector3(0.04, 0.12, 0.04), Color(0.12, 0.1, 0.12), Vector3(-90, 0, 0), 5)
		for k in 5:   # yelpaze kuyruk, tırtıklı
			b.add("box", Vector3((k - 2) * 0.03, -0.01, 0.27 + absf(k - 2) * -0.015), Vector3(0.035, 0.008, 0.2 - absf(k - 2) * 0.02), INK, Vector3(0, (k - 2) * 9.0, 0))
		body_m = b.build(null)
		_cache["crow_body"] = body_m
	var mat = cel("crow", Color.WHITE, {"ow": 0.0, "two_side": true, "rim": Color(0.3, 0.22, 0.45), "rim_amt": 0.6})
	root.add_child(gi(body_m, mat))
	var wing_m: ArrayMesh
	if _cache.has("crow_wing"):
		wing_m = _cache["crow_wing"]
	else:
		# düz kanat: önde düz kenar, arkada tırtıklı uçuş tüyleri (referans: keskin, yırtık kenarlı kara siluet)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_color(INK)
		st.set_normal(Vector3.UP)
		var pts = [Vector2(0.0, -0.06), Vector2(0.18, -0.09), Vector2(0.36, -0.06), Vector2(0.52, 0.02)]
		var back = []
		for k in 9:   # arka kenar: dişler
			var u = float(k) / 8.0
			var x = lerpf(0.52, 0.0, u)
			var z = lerpf(0.06, 0.14, u) + (0.09 if k % 2 == 1 else 0.0) * (1.0 - u * 0.5)
			back.append(Vector2(x, z))
		var poly = pts + back
		var c = Vector2(0.2, 0.03)
		for i in poly.size():
			var p0: Vector2 = poly[i]
			var p1: Vector2 = poly[(i + 1) % poly.size()]
			st.add_vertex(Vector3(c.x, 0, c.y))
			st.add_vertex(Vector3(p0.x, 0, p0.y))
			st.add_vertex(Vector3(p1.x, 0, p1.y))
		wing_m = st.commit()
		_cache["crow_wing"] = wing_m
	for sx in [-1.0, 1.0]:
		var w = Node3D.new()
		w.name = "WL" if sx < 0.0 else "WR"
		root.add_child(w)
		w.position = Vector3(sx * 0.06, 0.04, -0.04)
		var wm = gi(wing_m, mat)
		w.add_child(wm)
		wm.scale = Vector3(sx, 1, 1)
	return root


static func flap(cr: Node3D, t: float) -> void:
	var a = sin(t * TAU) * 0.9
	var l = cr.get_node_or_null("WL")
	var r = cr.get_node_or_null("WR")
	if l:
		l.rotation.z = -a
	if r:
		r.rotation.z = a


static func feathers(host: Node, p: Vector3, n: int, spread_r := 0.4) -> void:
	burst(host, p, {"amount": n, "life": 1.4, "radius": spread_r, "vmin": 0.5, "vmax": 2.2, "gravity": Vector3(0, -1.4, 0), "damp": 1.5, "spin": 260.0,
		"size": 0.24, "tex": "feather", "colors": [Color(0.06, 0.05, 0.08, 1), Color(0.06, 0.05, 0.08, 1), Color(0.06, 0.05, 0.08, 0)]})


# ================================================================== göz
## Gerçek göz konumu: kafa kemiğine iliştirilmiş düğüm (kemik yoksa ağız hizası). Sol / sağ göz ofsetleri kafa yerelinde.
static func head_attach(c: Node3D) -> Node3D:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or m.get("skel") == null or m.skel.find_bone("Head") < 0:
		return null
	var ba = BoneAttachment3D.new()
	ba.bone_name = "Head"
	m.skel.add_child(ba)
	return ba


static func eye_world(c: Node3D) -> Vector3:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.get("skel"):
		var hb = m.skel.find_bone("Head")
		if hb >= 0:
			var xf: Transform3D = m.skel.global_transform * m.skel.get_bone_global_pose(hb)
			return xf * Vector3(0, 0.065, 0.1)
	return Jutsu._mouth(c) + Vector3.UP * 0.12


## Göz parıltısı. kind: 0 Sharingan (kızıl yıldız + dönen tomoe), 1 Rinnegan (lila halka dalgası), 2 Mangekyō (kızıl fırıldak),
## 3 kararan göz (gri, yatay çizgiye kapanır). which: -1 sol, 1 sağ, 0 iki göz. Parlama kısa, sonra küçük ışıkla dur boyunca kalır.
static func eye_glint(host: Node, c: Node3D, kind: int, dur := 1.0, flare := 0.36, which := 0) -> void:
	if not is_instance_valid(c):
		return
	var ba = head_attach(c)
	var parent: Node3D = ba
	if ba == null:
		parent = Node3D.new()
		put(host, parent, Jutsu._mouth(c) + Vector3.UP * 0.12)
	var col = SHA if kind == 0 or kind == 2 else (RIN if kind == 1 else Color(0.75, 0.75, 0.78))
	var sides = [-1.0, 1.0] if which == 0 else [float(which)]
	for sx in sides:
		var e = Node3D.new()
		parent.add_child(e)
		e.position = Vector3(sx * 0.032, 0.065, 0.1) if ba else Vector3(sx * 0.035, 0, 0)
		# parıltı yıldızı (her zaman önde: derinliğe takılmaz)
		var qm = QuadMesh.new()
		qm.size = Vector2.ONE
		var gm = StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		gm.billboard_keep_scale = true
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.no_depth_test = true
		gm.albedo_texture = _tex("glint")
		gm.albedo_color = col.lightened(0.25)
		gm.render_priority = 4
		var star = gi(qm, gm)
		e.add_child(star)
		star.scale = Vector3.ONE * 0.02
		var tw = star.create_tween()
		tw.tween_property(star, "scale", Vector3.ONE * flare, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if kind == 3:   # göz kapanır: yıldız yatay çizgiye ezilir, söner
			tw.tween_property(star, "scale", Vector3(flare * 1.4, flare * 0.05, 1.0), 0.35)
			tw.tween_property(gm, "albedo_color:a", 0.0, 0.4)
		else:
			tw.tween_property(star, "scale", Vector3.ONE * flare * 0.25, 0.3)
			tw.tween_interval(maxf(0.05, dur - 0.6))
			tw.tween_property(gm, "albedo_color:a", 0.0, 0.25)
		# göz bebeği deseni: minicik disk (Sharingan / Rinnegan / Mangekyō), parlarken görünür
		if kind != 3:
			var mode = 5 if kind == 0 else (0 if kind == 1 else 6)
			var dm = disc_mat(mode, SHA if kind != 1 else RIN, SHA_DARK if kind != 1 else RIN_LINE, Color(0.2, 0.0, 0.02) if kind != 1 else RIN_DEEP,
				{"bill": true, "speed": 3.0 if kind != 1 else 0.6, "count": 5.0, "near_cut": 0.0, "prio": 5})
			dm.render_priority = 5
			var pq = QuadMesh.new()
			pq.size = Vector2.ONE * 0.05
			var pupil = gi(pq, dm)
			e.add_child(pupil)
			pupil.position = Vector3(0, 0, 0.01)
			var ptw = pupil.create_tween()
			ptw.tween_interval(maxf(0.1, dur))
			ptw.tween_method(sp(dm, "alpha"), 1.0, 0.0, 0.25)
	var life = dur + 0.6
	kill(host, life, parent)


# ================================================================== genjutsu katmanı
## Kurbanın yaşadığı yanılsama (izleyen de görür): altında dönen damar deseni (kurbanla yürür), bedeninden yükselen mürekkep
## tülleri; kurban oyuncuysa dünya rengi kayar (oyunun ortam katmanı). kind: 0 kızıl damar, 1 karga girdabı (pembe)
static func tint_layer(host: Node, tt: Node3D, dur: float, col: Color, kind := 0) -> void:
	if tt == null or not is_instance_valid(tt):
		return
	var h = float(tt.get("height")) if tt.get("height") != null else 1.8
	var R = clampf(h * 1.9, 3.2, 14.0)
	var m: ShaderMaterial
	if kind == 1:
		m = disc_mat(2, Color(0.86, 0.62, 0.62), Color(0.7, 0.36, 0.4), Color(0.55, 0.12, 0.16), {"alpha": 0.62, "speed": 1.2, "prog": 0.0})
	else:
		m = disc_mat(1, col.darkened(0.35), Color(0.03, 0.0, 0.01), col.lightened(0.1), {"alpha": 0.9, "speed": 1.0, "prog": 0.0})
	var qm = QuadMesh.new()
	qm.size = Vector2(R, R)
	qm.orientation = PlaneMesh.FACE_Y
	var d = gi(qm, m)
	tt.add_child(d)
	d.position = Vector3.UP * 0.06
	var tw = d.create_tween()
	tw.tween_method(sp(m, "prog"), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, dur - 0.7))
	tw.tween_method(sp(m, "alpha"), _sp0(m.get_shader_parameter("alpha")), 0.0, 0.35)
	tw.tween_callback(d.queue_free)
	# yükselen mürekkep tülleri (kurbanın çevresinden, kısa ömürlü)
	var ps = burst(host, tt.global_position + Vector3.UP * h * 0.4, {"amount": 14, "life": 0.9, "radius": h * 0.3, "vmin": 0.4, "vmax": 1.3, "dir": Vector3.UP, "spread": 25.0,
		"size": 0.35 * h / 1.8, "tex": "mote", "loop": maxf(0.3, dur), "gravity": Vector3(0, 0.6, 0),
		"colors": [Color(col.r, col.g, col.b, 0.0), Color(col.r * 0.5, col.g * 0.3, col.b * 0.3, 0.75), Color(0.02, 0.0, 0.01, 0.0)]})
	if ps:
		ps.local_coords = false
		var wr = weakref(tt)
		var pw = weakref(ps)
		var ttw = ps.create_tween()
		ttw.tween_method(func(_u: float):
			var n = wr.get_ref()
			var x = pw.get_ref()
			if n != null and x != null and is_instance_valid(n):
				x.global_position = n.global_position + Vector3.UP * h * 0.4, 0.0, 1.0, maxf(0.3, dur))
	if tt == Game.player and Game.world:
		Game.world.env.flash_tint(Color(col.r, col.g, col.b, 0.3), minf(dur, 2.0))


## atanmamış shader parametresi null gelir (float(null) çöker)
static func _sp0(v) -> float:
	return 1.0 if v == null else float(v)
