class_name NinjutsuFXG
extends RefCounted
## Genel ninjutsu grubu G (son grup): Dört Kara Yılan bariyeri, Öldürme Niyeti, Konan'ın kâğıt teknikleri, Rinnegan genjutsusu,
## Ibuse zehri, Susanoo Tsukumo, Asura Yolu (top / füze), Konbi Henge, duman klonları, mühür shuriken / hayalet shuriken,
## Ukon asalağı, Chiyo kukla teknikleri, Paraşüt, Alev Elleri, Asalak Klon, Ters Harem.
## Her görüntü bu dosyada sıfırdan üretilir: kendi cel / kontur / ışık / parıltı / bulut / sis / tarama / bariyer / ışın / alev /
## şerit gölgelendiricileri ve kendi parça yapı taşları. Oynanış ana ağaçtaki işleyicilerden satır satır taşındı; gerçek sistemler
## (Susanoo.of, ClanConstruct kuklaları, SummonModels Ibuse, mermi, gölge / duman klonu, yanıltıcı kopya, buff) olduğu gibi.
## Okunurluk: tüm gölgelendiricilerde kameraya yakın kısım yumuşakça söner (near); büyük kütlelerde 6–9 m.

const INK := Color(0.07, 0.05, 0.09, 1.0)
const PAPER := Color(0.97, 0.96, 0.99, 1.0)
const PAPER_INK := Color(0.32, 0.3, 0.42, 1.0)
const STEEL := Color(0.74, 0.76, 0.82, 1.0)
const STEEL_INK := Color(0.12, 0.13, 0.17, 1.0)
const CSTRING := Color(0.45, 0.75, 1.0, 1.0)
const RAZOR := Color(1.0, 0.72, 0.85, 1.0)
const PURPLE := Color(0.5, 0.3, 0.95, 1.0)
const SMOKE_LIT := Color(0.86, 0.83, 0.77, 1.0)
const SMOKE_SH := Color(0.64, 0.6, 0.55, 1.0)
const SMOKE_INK := Color(0.34, 0.3, 0.27, 1.0)
const FUR := Color(0.94, 0.55, 0.18, 1.0)
const FLESH := Color(0.8, 0.42, 0.37, 1.0)
const ZETSU := Color(0.93, 0.93, 0.89, 1.0)
const PINK := Color(1.0, 0.62, 0.8, 1.0)

static var _sh := {}
static var _cache := {}

# ================================================================== gölgelendiriciler
## Cel yüzey: köşe rengi × tint, iki ton; kameraya yakın söner.
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, CULLMODE, depth_draw_always, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float shade_k = 0.7;
uniform float fade = 1.0;
uniform float near = 1.5;

varying vec3 wn;

void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wn);
	if (!FRONT_FACING) {
		n = -n;
	}
	float l = dot(n, normalize(vec3(0.35, 1.0, 0.25)));
	vec3 c = tint.rgb * COLOR.rgb;
	if (l < 0.0) {
		c *= shade_k;
	}
	ALBEDO = c;
	ALPHA = clamp(tint.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Koyu kontur: arka yüzler normal boyunca şişirilir.
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.09, 1.0);
uniform float width = 0.02;
uniform float fade = 1.0;
uniform float near = 1.5;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
	ALPHA = clamp(ink.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Işık: toplamalı, kenara doğru yumuşar.
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float soft = 1.0;
uniform float fade = 1.0;
uniform float near = 2.0;

void fragment() {
	float f = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float k = mix(1.0, pow(f, 1.5), soft);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = clamp(tint.a * COLOR.a * k * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Parıltı dörtgeni: kind 0 yumuşak nokta, 1 dört uçlu yıldız, 2 tırtıklı patlama (cel, beyaz öz), 3 ince halka,
## 4 tomoeli Rinnegan, 5 mühür yazı halkası. bill = 1 kameraya döner.
const FLARE_SHADER := """
shader_type spatial;
render_mode unshaded, BLENDMODE, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float kind = 0.0;
uniform float p1 = 12.0;
uniform float spin = 0.0;
uniform float bill = 1.0;
uniform float fade = 1.0;
uniform float near = 2.0;

void vertex() {
	if (bill > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
}

float hsh(float x) {
	return fract(sin(x * 91.7 + 3.1) * 43758.5453);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float ca = cos(spin * TIME);
	float sa = sin(spin * TIME);
	q = vec2(q.x * ca - q.y * sa, q.x * sa + q.y * ca);
	float r = length(q);
	float ang = atan(q.y, q.x) / TAU + 0.5;
	vec3 c = tint.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		a = pow(clamp(1.0 - r, 0.0, 1.0), 2.0);
	} else if (kind < 1.5) {
		float cr = max(1.0 - abs(q.x) * 8.0 - abs(q.y) * 1.05, 0.0) + max(1.0 - abs(q.y) * 8.0 - abs(q.x) * 1.05, 0.0);
		a = clamp(cr + smoothstep(0.3, 0.0, r), 0.0, 1.0);
		c = mix(tint.rgb, vec3(1.0), smoothstep(0.25, 0.0, r));
	} else if (kind < 2.5) {
		float sp = abs(fract(ang * p1) - 0.5) * 2.0;
		float jag = hsh(floor(ang * p1));
		float edge = mix(0.38, 0.72 + 0.28 * jag, 1.0 - sp);
		a = step(r, edge);
		c = mix(tint.rgb, vec3(1.0, 1.0, 0.95), step(r, edge * 0.55));
	} else if (kind < 3.5) {
		a = smoothstep(0.78, 0.86, r) * smoothstep(1.0, 0.92, r);
	} else if (kind < 4.5) {
		float rings = step(0.8, fract(r * p1)) * step(r, 0.97);
		float pupil = step(r, 0.13);
		float tom = 0.0;
		for (int i = 0; i < 3; i++) {
			float ta = float(i) * TAU / 3.0;
			vec2 tp = vec2(cos(ta), sin(ta)) * 0.56;
			tom += step(length(q - tp), 0.09);
		}
		float tm = clamp(pupil + tom, 0.0, 1.0);
		a = clamp(max(rings + tm, 0.3), 0.0, 1.0) * step(r, 1.0);
		c = mix(tint.rgb, vec3(0.1, 0.05, 0.14), tm);
		c = mix(c, vec3(0.2, 0.12, 0.3), rings * (1.0 - tm));
	} else {
		float band = step(0.62, r) * step(r, 0.92);
		float ln = step(abs(r - 0.6), 0.015) + step(abs(r - 0.94), 0.02);
		float cell = floor(ang * 28.0);
		float gx = fract(ang * 28.0);
		float gy = (r - 0.62) / 0.3;
		float glyph = step(0.25, gx) * step(gx, 0.75) * step(0.15, gy) * step(gy, 0.85) * step(0.45, hsh(cell + floor(gy * 3.0) * 7.0));
		float spoke = step(abs(fract(ang * 8.0) - 0.5), 0.006) * step(r, 0.6) * step(0.18, r);
		a = clamp(ln + band * glyph + spoke, 0.0, 1.0) * step(r, 1.0);
	}
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(a * tint.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Cel bulut (anime duman / toz): kaynayan yüzey, iki ton, koyu kenar çizgisi; kameraya yakın söner.
const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 lit : source_color = vec4(0.86, 0.83, 0.77, 1.0);
uniform vec4 shade : source_color = vec4(0.64, 0.6, 0.55, 1.0);
uniform vec4 ink : source_color = vec4(0.34, 0.3, 0.27, 1.0);
uniform float boil = 0.08;
uniform float fade = 1.0;
uniform float near = 6.0;

varying vec3 wn;

void vertex() {
	float w = sin(VERTEX.x * 7.0 + TIME * 3.0) * sin(VERTEX.y * 6.0 + TIME * 2.3) * sin(VERTEX.z * 5.0 + TIME * 2.7);
	VERTEX += NORMAL * w * boil;
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wn);
	float l = dot(n, normalize(vec3(0.3, 1.0, 0.2)));
	vec3 c = l > 0.1 ? lit.rgb : shade.rgb;
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (f < 0.24) {
		c = ink.rgb;
	}
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(COLOR.a * fade * smoothstep(near * 0.35, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Zehir sisi: dünya uzayında kayan gürültü, bantlı iki ton, yumuşak siluet.
const MIST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 lit : source_color = vec4(0.62, 0.42, 0.7, 1.0);
uniform vec4 shade : source_color = vec4(0.36, 0.2, 0.42, 1.0);
uniform float density = 0.7;
uniform float fade = 1.0;
uniform float near = 7.0;

varying vec3 wp;

float hs(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hs(i), hs(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hs(i + vec3(0.0, 1.0, 0.0)), hs(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hs(i + vec3(0.0, 0.0, 1.0)), hs(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hs(i + vec3(0.0, 1.0, 1.0)), hs(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 q = wp * 0.5 + vec3(TIME * 0.22, TIME * 0.06, TIME * 0.15);
	float n = vn(q) * 0.6 + vn(q * 2.4) * 0.4;
	float band = step(0.52, n);
	vec3 c = mix(shade.rgb, lit.rgb, 0.3 + band * 0.7);
	float a = density * smoothstep(0.05, 0.55, f) * (0.6 + 0.4 * n);
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(a * COLOR.a * fade * smoothstep(near * 0.35, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Tarama (Öldürme Niyeti ölüm görüntüsü): siyah gövde, titreşen beyaz yatay tarama çizgileri, beyaz kenar.
const HATCH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.02, 0.01, 0.03, 0.78);
uniform vec4 line : source_color = vec4(0.92, 0.94, 1.0, 1.0);
uniform float dens = 26.0;
uniform float fade = 1.0;
uniform float near = 3.0;

varying vec3 wp;

float hsh(float x) {
	return fract(sin(x * 57.3 + 1.7) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float jit = floor(TIME * 10.0);
	float row = floor(wp.y * dens);
	float on = step(0.38, hsh(row * 1.3 + jit));
	float h = step(0.6, fract(wp.y * dens + sin(wp.x * 5.0 + wp.z * 4.0 + jit) * 0.15)) * on;
	vec3 c = mix(ink.rgb, line.rgb, h);
	float a = mix(ink.a, line.a, h);
	if (f < 0.26) {
		c = line.rgb;
		a = 0.95;
	}
	ALBEDO = c;
	ALPHA = clamp(a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Bariyer duvarı (dörtgen yüzler): kıvrılan mor chakra dumanı, açık mor kenar çizgisi.
const WALL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 deep : source_color = vec4(0.18, 0.07, 0.5, 1.0);
uniform vec4 lite : source_color = vec4(0.52, 0.32, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.86, 0.78, 1.0, 1.0);
uniform float fade = 1.0;
uniform float near = 6.0;

varying vec3 wp;

float hs(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hs(i), hs(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hs(i + vec3(0.0, 1.0, 0.0)), hs(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hs(i + vec3(0.0, 0.0, 1.0)), hs(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hs(i + vec3(0.0, 1.0, 1.0)), hs(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 q = wp * 0.6 + vec3(0.0, -TIME * 0.35, TIME * 0.1);
	float n = vn(q) * 0.55 + vn(q * 2.1 + vec3(TIME * 0.2)) * 0.3 + vn(q * 4.3) * 0.15;
	float wisp = step(0.88, fract(n * 5.0));
	vec3 c = mix(deep.rgb, lite.rgb, smoothstep(0.35, 0.7, n));
	c = mix(c, edge.rgb, wisp * 0.55);
	float a = 0.4 + 0.3 * n;
	vec2 e2 = min(UV, vec2(1.0) - UV);
	float ed = min(e2.x, e2.y);
	if (ed < 0.016) {
		c = edge.rgb;
		a = 0.95;
	}
	ALBEDO = c;
	ALPHA = clamp(a * fade * smoothstep(near * 0.35, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Chakra ışını (silindir, UV.y boy): beyaz öz, mavi kenar, akan bantlar, koyu mavi dış çizgi.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 rim : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform float flow = 6.0;
uniform float lenk = 10.0;
uniform float fade = 1.0;
uniform float near = 6.0;

void fragment() {
	float f = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float band = step(0.72, fract(UV.y * lenk - TIME * flow));
	vec3 c = mix(rim.rgb, core.rgb, smoothstep(0.35, 0.62, f));
	c = mix(c, vec3(1.0), band * 0.35);
	float a = mix(0.85, 1.0, smoothstep(0.2, 0.5, f));
	if (f < 0.12) {
		c = rim.rgb * 0.55;
	}
	ALBEDO = c;
	ALPHA = clamp(a * fade * smoothstep(near * 0.35, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Alev eli (On Kuyruk cinchūriki alevi): somon gövde, içte kıvrılan koyu kırmızı damar çizgileri, koyu kenar, kaynayan yüzey.
const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 base : source_color = vec4(0.95, 0.47, 0.43, 1.0);
uniform vec4 lite : source_color = vec4(1.0, 0.68, 0.6, 1.0);
uniform vec4 vein : source_color = vec4(0.72, 0.14, 0.13, 1.0);
uniform vec4 rimc : source_color = vec4(0.56, 0.08, 0.08, 1.0);
uniform float fade = 1.0;
uniform float near = 5.0;

varying vec3 wp;

float hs(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hs(i), hs(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hs(i + vec3(0.0, 1.0, 0.0)), hs(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hs(i + vec3(0.0, 0.0, 1.0)), hs(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hs(i + vec3(0.0, 1.0, 1.0)), hs(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	float w = sin(VERTEX.y * 5.0 + TIME * 6.0) * sin(VERTEX.x * 4.0 + TIME * 4.3);
	VERTEX += NORMAL * w * 0.05;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = vn(wp * 1.8 + vec3(0.0, -TIME * 1.4, TIME * 0.3));
	float v = step(abs(fract(n * 4.0) - 0.5), 0.06);
	vec3 c = mix(base.rgb, lite.rgb, smoothstep(0.6, 0.95, f));
	c = mix(c, vein.rgb, v);
	if (f < 0.25) {
		c = rimc.rgb;
	}
	ALBEDO = c;
	ALPHA = clamp(0.86 * COLOR.a * fade * smoothstep(near * 0.35, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Şerit (UV.x boy, UV.y en): kuyruk sönümü, kenar rengi, açılma (reveal), kesik çizgi akışı.
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge_col : source_color = vec4(1.0);
uniform float reveal = 1.0;
uniform float tail = 0.4;
uniform float dash = 0.0;
uniform float flow = 0.0;
uniform float fade = 1.0;
uniform float near = 3.0;

void fragment() {
	if (UV.x > reveal) {
		discard;
	}
	float t = UV.x / max(reveal, 0.001);
	float a = smoothstep(0.0, max(tail, 0.001), t);
	float side = abs(UV.y * 2.0 - 1.0);
	vec3 c = mix(tint.rgb, edge_col.rgb, step(0.55, side));
	a *= step(side, 0.98);
	if (dash > 0.0) {
		a *= step(0.35, fract(UV.x * dash - TIME * flow));
	}
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(a * tint.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""


# ================================================================== malzeme yapı taşları
static func _shader(key: String, code: String) -> Shader:
	if not _sh.has(key):
		var s := Shader.new()
		s.code = code
		_sh[key] = s
	return _sh[key]


static func cel(col := Color.WHITE, outline := 0.02, ink := INK, two_side := false, near := 1.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("cel2" if two_side else "cel", CEL_SHADER.replace("CULLMODE", "cull_disabled" if two_side else "cull_back"))
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("near", near)
	if outline > 0.0:
		var o := ShaderMaterial.new()
		o.shader = _shader("ol", OUTLINE_SHADER)
		o.set_shader_parameter("ink", ink)
		o.set_shader_parameter("width", outline)
		o.set_shader_parameter("near", near)
		o.render_priority = -1
		m.next_pass = o
	return m


static func glow(col: Color, near := 2.0, soft := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("glow", GLOW_SHADER)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("soft", soft)
	m.set_shader_parameter("near", near)
	return m


static func flare_mat(col: Color, kind := 0.0, add := true, bill := true, near := 2.0, p1 := 12.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("flare_a" if add else "flare_m", FLARE_SHADER.replace("BLENDMODE", "blend_add" if add else "blend_mix"))
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("bill", 1.0 if bill else 0.0)
	m.set_shader_parameter("near", near)
	m.set_shader_parameter("p1", p1)
	return m


static func cloud_mat(lit := SMOKE_LIT, shade := SMOKE_SH, ink := SMOKE_INK, near := 6.0, boil := 0.08) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("cloud", CLOUD_SHADER)
	m.set_shader_parameter("lit", lit)
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("ink", ink)
	m.set_shader_parameter("near", near)
	m.set_shader_parameter("boil", boil)
	return m


static func mist_mat(density := 0.7, near := 7.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("mist", MIST_SHADER)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("near", near)
	return m


static func hatch_mat(near := 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("hatch", HATCH_SHADER)
	m.set_shader_parameter("near", near)
	return m


static func wall_mat(near := 6.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("wall", WALL_SHADER)
	m.set_shader_parameter("near", near)
	return m


static func beam_mat(core: Color, rim: Color, lenk: float, near := 6.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("beam", BEAM_SHADER)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("lenk", lenk)
	m.set_shader_parameter("near", near)
	return m


static func flame_mat(near := 5.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("flame", FLAME_SHADER)
	m.set_shader_parameter("near", near)
	return m


static func streak_mat(col: Color, edge: Color, tail := 0.4, near := 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("streak", STREAK_SHADER)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("edge_col", edge)
	m.set_shader_parameter("tail", tail)
	m.set_shader_parameter("near", near)
	return m


static func set_fade(m: Material, v: float) -> void:
	var q := m
	while q != null:
		if q is ShaderMaterial:
			(q as ShaderMaterial).set_shader_parameter("fade", v)
		q = q.next_pass


## delay sonra dur sürede söner, sonra silinir
static func fade_out(n: Node, m: Material, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


## Malzemenin tek parametresini tween'le sürer
static func tween_param(n: Node, m: ShaderMaterial, key: String, a: float, b: float, dur: float) -> Tween:
	var tw := n.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter(key, v), a, b, maxf(dur, 0.01))
	return tw


# ================================================================== düğüm / geometri yapı taşları
static func put(pj: PathJutsu, n: Node3D, pos: Vector3, parent: Node = null) -> Node3D:
	(parent if parent else pj.get_tree().current_scene).add_child(n)
	n.global_position = pos
	preload("res://scripts/combat/fx/lib/ground_drape.gd").auto(n)   # yere serili düz efekt engebeli araziye oturur
	return n


static func mi(mesh: Mesh, m: Material) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.mesh = mesh
	x.material_override = m
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x


static func _cached(key: String, fn: Callable) -> Mesh:
	var k := "mesh:" + key
	if not _cache.has(k):
		_cache[k] = fn.call()
	return _cache[k]


static func _sphere(seg := 14) -> Mesh:
	return _cached("sphere%d" % seg, func():
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = seg
		s.rings = maxi(6, seg / 2)
		return s)


static func _quad() -> Mesh:
	return _cached("quad", func():
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		return q)


static func _cyl(seg := 8) -> Mesh:
	return _cached("cyl%d" % seg, func():
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 1.0
		cm.radial_segments = seg
		cm.rings = 1
		return cm)


static func _box() -> Mesh:
	return _cached("box", func():
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		return b)


## a→b arası birim silindir dönüşümü (w: çap)
static func _seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var d := b - a
	var L := maxf(d.length(), 0.001)
	var y := d / L
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * w, y * L, z * w), (a + b) * 0.5)


## Profil (x en, y boy) → yassı, boy -Z, kalınlık Y
static func _blade_xf(off := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)), off)


## Profil → XZ düzleminde yassı (kalınlık Y); dönüş (yansıma yok, kontur doğru yüzde kalır)
static func _flat_xf(off := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)), off)


## Şerit (iki yüzlü): UV.x boy, UV.y en. nrm yüz normali (ZERO: otomatik)
static func ribbon(pts: Array, w: float, nrm := Vector3.ZERO, taper := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nn: Vector3 = nrm
		if nn == Vector3.ZERO:
			nn = Vector3.UP if absf(tn.y) < 0.9 else Vector3.RIGHT
		var sd: Vector3 = tn.cross(nn)
		if sd.length() < 0.1:
			sd = tn.cross(Vector3.RIGHT)
		sd = sd.normalized()
		var u: float = float(i) / float(maxi(1, n - 1))
		var ww: float = w * ((0.25 + 0.75 * sin(PI * u)) if taper else 1.0)
		for s in [-1.0, 1.0]:
			st.set_uv(Vector2(u, (s + 1.0) * 0.5))
			st.set_normal(nn)
			st.add_vertex(p + sd * ww * 0.5 * s)
	for i in n - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	return st.commit()


static func _star2d(points: int, r_out: float, r_in: float, rot := 0.0) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in points * 2:
		var a := rot + TAU * i / (points * 2.0)
		o.append(Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return o


static func _heart2d(s: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		o.append(Vector2(x, y) * s / 32.0)
	return o


# ------------------------------------------------------------------ parça yağmuru (kendi CPU parçacık ayarı)
## o: r, dir, spread, vmin, vmax, g, damp, smin, smax, spin, expl, radial, hold, end_scale, align, emit (sürekli)
static func burst(pj: PathJutsu, pos: Vector3, mesh: Mesh, m: Material, n: int, life: float, o := {}, parent: Node = null) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, n)
	p.lifetime = life
	var cont: bool = o.get("emit", false)
	p.one_shot = not cont
	p.explosiveness = 0.0 if cont else float(o.get("expl", 0.95))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.3))
	var dv: Vector3 = o.get("dir", Vector3.UP)
	p.direction = dv.normalized() if dv.length() > 0.001 else Vector3.UP
	p.spread = float(o.get("spread", 180.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("g", Vector3(0, -6, 0))
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0))
	p.scale_amount_min = float(o.get("smin", 0.8))
	p.scale_amount_max = float(o.get("smax", 1.2))
	if o.get("align", false):
		p.particle_flag_align_y = true
	else:
		p.particle_flag_rotate_y = true
		p.angle_min = 0.0
		p.angle_max = 360.0
		var sp := float(o.get("spin", 120.0))
		p.angular_velocity_min = -sp
		p.angular_velocity_max = sp
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(float(o.get("hold", 0.65)), Color(1, 1, 1, 1))
	p.color_ramp = g
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, float(o.get("start_scale", 1.0))))
	cv.add_point(Vector2(1.0, float(o.get("end_scale", 0.6))))
	p.scale_amount_curve = cv
	if parent:
		parent.add_child(p)
		p.position = pos
	else:
		put(pj, p, pos)
	p.emitting = true
	if not cont:
		pj.free_after(life + 0.3, p)
	return p


## Parlama dörtgeni: büyüyüp söner
static func flash(pj: PathJutsu, pos: Vector3, col: Color, size: float, kind := 2.0, life := 0.3, add := true, grow := 1.4, near := 2.5, spin := 0.0) -> MeshInstance3D:
	var m := flare_mat(col, kind, add, true, near)
	m.set_shader_parameter("spin", spin)
	var q := mi(_quad(), m)
	put(pj, q, pos)
	q.scale = Vector3.ONE * size * 0.6
	var tw := q.create_tween()
	tw.set_parallel(true)
	tw.tween_property(q, "scale", Vector3.ONE * size * grow, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(q.queue_free)
	return q


## Yere yatık işaret (halka / mühür): sabit kalır, sonra söner
static func ground_sigil(pj: PathJutsu, pos: Vector3, col: Color, size: float, kind: float, hold: float, out := 0.4, add := true, spin := 0.0) -> MeshInstance3D:
	var m := flare_mat(col, kind, add, false, 5.0)
	m.set_shader_parameter("spin", spin)
	var q := mi(_quad(), m)
	put(pj, q, pj.gp(pos) + Vector3.UP * 0.05)
	q.rotation_degrees = Vector3(-90, randf() * 360.0, 0)
	q.scale = Vector3.ONE * size
	fade_out(q, m, hold, out)
	return q


## Yerde genişleyen ince halka
static func ground_ring(pj: PathJutsu, pos: Vector3, col: Color, r_end: float, life: float, add := true) -> void:
	var m := flare_mat(col, 3.0, add, false, 4.0)
	var q := mi(_quad(), m)
	put(pj, q, pj.gp(pos) + Vector3.UP * 0.06)
	q.rotation_degrees = Vector3(-90, 0, 0)
	q.scale = Vector3.ONE * 0.4
	var tw := q.create_tween()
	tw.set_parallel(true)
	tw.tween_property(q, "scale", Vector3.ONE * r_end * 2.0, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(q.queue_free)


## Zemin çatlakları: merkezden kırık çizgiler (kendi geometrisi), yavaş söner
static func cracks(pj: PathJutsu, pos: Vector3, r: float, n: int, col: Color, life := 3.0) -> void:
	var b := MB.new()
	for i in n:
		var a := TAU * i / n + randf_range(-0.3, 0.3)
		var p := Vector3.ZERO
		var seg := 4
		for s in seg:
			var aa := a + randf_range(-0.45, 0.45)
			var L := r / seg * randf_range(0.7, 1.2)
			var dv := Vector3(sin(aa), 0, cos(aa))
			var w := lerpf(0.16, 0.04, float(s) / seg) * (r / 4.0 + 0.5)
			b.add("box", p + dv * L * 0.5 + Vector3.UP * 0.02, Vector3(w, 0.03, L), col, Vector3(0, rad_to_deg(aa), 0), 1)
			p += dv * L
	var m := cel(Color.WHITE, 0.0, INK, true, 4.0)
	var x := mi(b.build(), m)
	put(pj, x, pj.gp(pos))
	fade_out(x, m, life, 0.8)


## Kaya / tahta parçaları
static func debris(pj: PathJutsu, pos: Vector3, col: Color, n: int, v: float, life := 1.1, sz := 0.25) -> void:
	burst(pj, pos, _box(), cel(col, 0.015, INK, false, 1.5), n, life, {"r": 0.6, "dir": Vector3.UP, "spread": 55.0, "vmin": v * 0.5, "vmax": v,
		"g": Vector3(0, -18, 0), "smin": sz * 0.6, "smax": sz * 1.4, "spin": 400.0, "hold": 0.85, "end_scale": 0.8})


## Cel toz halkası (çarpma tozu, kendi bulut gölgelendiricisi)
static func dust(pj: PathJutsu, pos: Vector3, n: int, sz: float, life := 0.9, lit := Color(0.84, 0.76, 0.62), shade := Color(0.64, 0.56, 0.44)) -> void:
	burst(pj, pj.gp(pos) + Vector3.UP * 0.2, _sphere(10), cloud_mat(lit, shade, shade.darkened(0.45), 5.0, 0.05), n, life,
		{"r": 0.5, "dir": Vector3.UP, "spread": 85.0, "vmin": 1.5, "vmax": 4.5, "g": Vector3(0, -1.5, 0), "damp": 3.0, "radial": 5.0,
		"smin": sz * 0.6, "smax": sz * 1.2, "start_scale": 0.5, "end_scale": 1.3, "hold": 0.6, "spin": 30.0})


## İki nokta arası kendi chakra ipi (her karede uçları yeniler)
static func thread(pj: PathJutsu, a_fn: Callable, b_fn: Callable, w: float, col: Color, dur: float) -> MeshInstance3D:
	var m := glow(col, 1.0, 0.25)
	var x := mi(_cyl(5), m)
	pj.get_tree().current_scene.add_child(x)
	var upd = func(_i, _k):
		if not is_instance_valid(x):
			return
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		if a.distance_to(b) < 0.05 or a == Vector3.ZERO or b == Vector3.ZERO:
			x.visible = false
			return
		x.visible = true
		x.global_transform = _seg_xf(a, b, w)
	upd.call(0, 0.0)
	pj.every(dur, 1.0 / 30.0, upd, func():
		if is_instance_valid(x):
			fade_out(x, m, 0.0, 0.2))
	return x


## Zemine yatık çizilen şerit (yol üzerinde açılır, bekler, söner)
static func ground_trace(pj: PathJutsu, pts: Array, w: float, col: Color, edge: Color, grow: float, hold: float, out := 0.4) -> MeshInstance3D:
	var m := streak_mat(col, edge, 0.05, 3.0)
	m.set_shader_parameter("reveal", 0.0)
	var x := mi(ribbon(pts, w, Vector3.UP, false), m)
	put(pj, x, Vector3.ZERO)
	tween_param(x, m, "reveal", 0.0, 1.0, grow)
	fade_out(x, m, grow + hold, out)
	return x


# ================================================================== 1) Dört Kara Yılan Düzeni
## Ref: hedefin üstünde yükselen dik, kutu biçimli mor bariyer; içinde kıvrılan duman, açık mor ince kenar çizgileri.
## Kurgu: zeminde dört kara yılan mürekkep izi çağırandan köşelere kıvrılır → köşelerde kara yılan başları → duvarlar
## yerden yükselir, içte mor chakra tanecikleri kıvrılır, zeminde mühür halkası; bitişte duvarlar yere çöker.
static func shikokujaijin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 1.0)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 7.0)
	var o: Vector3 = pj.gp(c.global_position)
	# kara yılan mürekkep izleri + baş
	for k in 4:
		var corner := at + Vector3(2.0 if k % 2 == 0 else -2.0, 0, 2.0 if k < 2 else -2.0)
		var dv := corner - o
		dv.y = 0.0
		var side := dv.normalized().cross(Vector3.UP) if dv.length() > 0.1 else Vector3.RIGHT
		var pts := []
		for i in 26:
			var u := i / 25.0
			var p := o.lerp(corner, u) + side * sin(u * TAU * 2.5 + k) * 0.35 * sin(u * PI)
			p.y = pj.gp(p).y + 0.04
			pts.append(p)
		ground_trace(pj, pts, 0.24, INK, Color(0.3, 0.12, 0.5), 0.3, 5.1, 0.4)
		var hm := cel(Color(0.08, 0.06, 0.1), 0.02, Color(0.4, 0.2, 0.7))
		var hb := MB.new()
		for q in 3:   # sarmal gövde
			var a := q * 2.2
			hb.add("sphere", Vector3(cos(a) * 0.22, 0.1 + q * 0.13, sin(a) * 0.22), Vector3(0.24, 0.2, 0.24), Color.WHITE, Vector3.ZERO, 8)
		hb.add("sphere", Vector3(0, 0.62, 0.05), Vector3(0.22, 0.18, 0.32), Color.WHITE, Vector3(-20, 0, 0), 8)
		hb.add("sphere", Vector3(0.07, 0.67, 0.18), Vector3(0.05, 0.04, 0.04), Color(1.0, 0.45, 1.0), Vector3.ZERO, 6)
		hb.add("sphere", Vector3(-0.07, 0.67, 0.18), Vector3(0.05, 0.04, 0.04), Color(1.0, 0.45, 1.0), Vector3.ZERO, 6)
		var head := mi(hb.build(), hm)
		put(pj, head, pj.gp(corner))
		head.look_at(head.global_position + (at - corner) * Vector3(1, 0, 1) + Vector3(0.001, 0, 0), Vector3.UP)
		head.rotate_object_local(Vector3.UP, PI)
		head.scale = Vector3.ONE * 0.05
		var htw := head.create_tween()
		htw.tween_interval(0.25)
		htw.tween_property(head, "scale", Vector3.ONE * 1.3, 0.2).set_trans(Tween.TRANS_BACK)
		fade_out(head, hm, 5.6, 0.3)
	# bariyer: dört duvar + tavan (her biri kendi dörtgeni; UV kenarı çizgi verir)
	var wm := wall_mat(6.0)
	var box := Node3D.new()
	put(pj, box, at)
	for k in 4:
		var w := mi(_quad(), wm)
		box.add_child(w)
		var ang := k * PI * 0.5
		w.position = Vector3(sin(ang) * 2.0, 3.0, cos(ang) * 2.0)
		w.rotation = Vector3(0, ang, 0)
		w.scale = Vector3(4.0, 6.0, 1.0)
	var top := mi(_quad(), wm)
	box.add_child(top)
	top.position = Vector3(0, 6.0, 0)
	top.rotation_degrees = Vector3(-90, 0, 0)
	top.scale = Vector3(4.0, 4.0, 1.0)
	# köşe dikmeleri: ince açık mor ışık
	var em := glow(Color(0.75, 0.6, 1.0, 0.9), 3.0, 0.2)
	for k in 4:
		var e := mi(_cyl(6), em)
		box.add_child(e)
		e.position = Vector3(2.0 if k % 2 == 0 else -2.0, 3.0, 2.0 if k < 2 else -2.0)
		e.scale = Vector3(0.08, 6.0, 0.08)
	box.scale = Vector3(1, 0.02, 1)
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(5.0)
	tw.tween_property(box, "scale", Vector3(1, 0.02, 1), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(box.queue_free)
	# zemin mühür halkası + içte kıvrılan mor tanecikler
	ground_sigil(pj, at, Color(0.55, 0.35, 1.0, 0.85), 5.2, 5.0, 5.4, 0.3, true, 0.4)
	var wisp := burst(pj, at + Vector3.UP * 3.0, _sphere(8), glow(Color(0.65, 0.45, 1.0, 0.8), 3.0), 26, 1.4,
		{"emit": true, "r": 1.7, "dir": Vector3.UP, "spread": 40.0, "vmin": 0.3, "vmax": 1.0, "g": Vector3(0, 0.4, 0), "smin": 0.12, "smax": 0.3, "hold": 0.5})
	pj.after(5.4, func():
		if is_instance_valid(wisp):
			wisp.emitting = false
			pj.free_after(1.6, wisp))
	pj.every(5.4, 0.2, func(_i, _k):
		for e in pj.enemies_near(c, at, 2.2):
			if not pj.live(e):
				continue
			pj.st(e, "bind", 0.3)
			if _i % 5 == 0:
				flash(pj, e.global_position + Vector3.UP * 1.2, Color(0.6, 0.4, 1.0), 0.9, 2.0, 0.2)
				e.take_hit(pj.inf(c, "shikokujaijin", 0.2, {"knock": 0.0, "kind": "light"})))
	Sfx.play("seal", at, 0.7)


# ================================================================== 2) Öldürme Niyeti
## Ref: siyah zemin üzerinde beyaz tarama çizgileriyle çizilmiş ölüm görüntüsü. Kurgu: gözlerde kızıl ışık → önündeki
## yelpazeye zeminden koyu kızıl "niyet" çizgileri yayılır → donan her düşmanın bedeni siyah-beyaz taramalı ölüm
## gölgesine bürünür, üç taramalı bıçak hayali bedene saplanır; iki saniyede söner.
static func satsui_no_shisen(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	_red_eyes(pj, c, 2.0)
	var fd: Vector3 = c.face_dir()
	fd.y = 0.0
	fd = fd.normalized() if fd.length() > 0.01 else Vector3.FORWARD
	var o: Vector3 = pj.gp(c.global_position)
	for k in 13:   # zemin niyet çizgileri: önündeki yelpazeye (±78°) kesik kızıl çizgiler koşar
		var a := lerpf(-1.36, 1.36, k / 12.0) + randf_range(-0.05, 0.05)
		var dv := fd.rotated(Vector3.UP, a)
		var pts := []
		for i in 12:
			var p := o + dv * (1.0 + i * 1.15) + dv.cross(Vector3.UP) * sin(i * 1.7 + k) * 0.12
			p.y = pj.gp(p).y + 0.05
			pts.append(p)
		var tr := ground_trace(pj, pts, 0.14, Color(0.25, 0.02, 0.06, 0.9), Color(0.05, 0.0, 0.02, 0.9), 0.22, 0.25, 0.3)
		(tr.material_override as ShaderMaterial).set_shader_parameter("dash", 6.0)
		(tr.material_override as ShaderMaterial).set_shader_parameter("flow", 3.0)
	for e in pj.enemies_near(c, c.global_position, 14.0):
		var v = e.global_position - c.global_position
		v.y = 0
		if v.normalized().dot(c.face_dir()) > 0.2:
			pj.st(e, "fear", 3.0)
			pj.st(e, "stun", 2.0)
			_death_vision(pj, c, e)
			Combat.popup_text(e.global_position + Vector3.UP * 2.4, "Korkudan donakaldı!", Color(0.85, 0.3, 0.35))
	Sfx.play("genjutsu", c.global_position, 0.3)


## Kızıl gözler: göz hizasında parlayan iki nokta + yana çekilen ince kızıl çizgiler
static func _red_eyes(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb == null:
		return
	var b := MB.new()
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.032, 0.065, 0.095), Vector3(0.024, 0.018, 0.01), Color.WHITE, Vector3.ZERO, 8)
		b.add("box", Vector3(sx * 0.07, 0.068, 0.085), Vector3(0.07, 0.005, 0.004), Color.WHITE, Vector3(0, 0, sx * 8.0), 1)
	var x := mi(b.build(), glow(Color(1.0, 0.08, 0.1), 0.3, 0.0))
	hb.add_child(x)
	pj.free_after(dur, hb)


## Ölüm görüntüsü: taramalı gölge kabuğu + bedene saplanan üç taramalı bıçak
static func _death_vision(pj: PathJutsu, c: Node3D, e: Node3D) -> void:
	var r: float = float(e.get("radius")) if e.get("radius") != null else 0.5
	var hm := hatch_mat(3.0)
	var shell := mi(_sphere(16), hm)
	e.add_child(shell)
	shell.position = Vector3.UP * 1.0
	shell.scale = Vector3(r * 2.4, 2.3, r * 2.4) * 0.6
	shell.create_tween().tween_property(shell, "scale", Vector3(r * 2.4, 2.3, r * 2.4), 0.15).set_trans(Tween.TRANS_BACK)
	fade_out(shell, hm, 1.6, 0.4)
	var from: Vector3 = c.global_position
	for k in 3:
		var bm := hatch_mat(2.5)
		var b := MB.new()
		b.add_slab(PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.05, 1.5), Vector2(0.0, 1.85), Vector2(-0.05, 1.5)]), 0.03, Color.WHITE, _blade_xf())
		b.add("box", Vector3(0, 0, 0.35), Vector3(0.05, 0.06, 0.7), Color.WHITE, Vector3.ZERO, 1)
		var blade := mi(b.build(), bm)
		var dv: Vector3 = (e.global_position - from)
		dv.y = 0.0
		dv = dv.normalized().rotated(Vector3.UP, (k - 1) * 0.7)
		var hit_p: Vector3 = e.global_position + Vector3.UP * (0.9 + k * 0.25)
		var start: Vector3 = hit_p - dv * 2.6 + Vector3.UP * (0.6 - k * 0.4)
		put(pj, blade, start)
		blade.look_at(hit_p, Vector3.UP)
		var tw := blade.create_tween()
		tw.tween_interval(0.05 + k * 0.12)
		tw.tween_property(blade, "global_position", hit_p - (hit_p - start).normalized() * 0.6, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		fade_out(blade, bm, 1.5, 0.4)


# ================================================================== 3) Kâğıt Sağanağı
## Ref: Konan kâğıt kanatlarla süzülür, yassı kâğıt bıçaklar eğik yağmur gibi iner ve zemine saplanır.
## Kurgu: sırtta kâğıt kanatlar açılır → ellerden yukarı akan yapraklar hedefin üstünde dönen kâğıt bulutunu örer →
## buluttan katlı kâğıt bıçaklar eğik iner, saplanır, kat yerinden çözülüp küçülür.
static func kami_shigure(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 1.0)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var sky := at + Vector3.UP * 7.0
	_paper_wings(pj, c, 1.9)
	for r in [true, false]:
		_paper_flight(pj, pj.hand_pos(c, r), sky, 18, 0.45, 1.5)
	var cloud := _paper_cloud()
	put(pj, cloud, sky)
	cloud.scale = Vector3.ONE * 0.05
	var ctw := cloud.create_tween()
	ctw.tween_property(cloud, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	ctw.tween_interval(1.2)
	ctw.tween_property(cloud, "scale", Vector3(1.4, 0.05, 1.4), 0.3)
	ctw.tween_callback(cloud.queue_free)
	pj.every(1.9, 1.0 / 30.0, func(_i, _k):
		if is_instance_valid(cloud):
			cloud.rotation.y += 0.05, Callable())
	var slant: Vector3 = (at - c.global_position)
	slant.y = 0
	slant = slant.normalized() * 2.0 if slant.length() > 0.1 else Vector3.ZERO
	var bm := _paper_blade_mesh()
	var pm := cel(PAPER, 0.012, PAPER_INK, true, 2.0)
	pj.every(1.6, 0.05, func(_i, _k):
		for k in 5:
			var p: Vector3 = sky + Vector3(randf_range(-3, 3), randf_range(-0.5, 0.5), randf_range(-3, 3)) - slant
			var g: Vector3 = pj.gp(p + slant + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)))
			var kn := mi(bm, pm)
			put(pj, kn, p)
			kn.look_at(g, Vector3.UP if absf((g - p).normalized().y) < 0.99 else Vector3.FORWARD)
			kn.rotate_object_local(Vector3.FORWARD, randf() * TAU)
			var tw := kn.create_tween()
			tw.tween_property(kn, "global_position", g + (g - p).normalized() * 0.15, 0.22)   # saplanır
			tw.tween_interval(0.5)
			tw.tween_property(kn, "scale", Vector3(1.6, 0.05, 0.3), 0.15)   # kat yerinden çözülüp yassılaşır
			tw.tween_callback(kn.queue_free)
		if _i % 3 == 0:
			for e in pj.enemies_near(c, at, 3.5):
				if pj.live(e):
					e.take_hit(pj.inf(c, "kami_shigure", 0.15, {"knock": 0.0, "kind": "light", "bleed": 1.0})))
	Sfx.play("whoosh", at, 1.4)


static func _paper_blade_mesh() -> Mesh:
	return _cached("paper_blade", func():
		var b := MB.new()
		b.add_slab(PackedVector2Array([Vector2(0, 0.0), Vector2(0.07, 0.22), Vector2(0.045, 0.62), Vector2(0, 0.7), Vector2(-0.045, 0.62), Vector2(-0.07, 0.22)]), 0.012, PAPER, _blade_xf())
		b.add("box", Vector3(0, 0.008, -0.34), Vector3(0.008, 0.006, 0.6), PAPER_INK, Vector3.ZERO, 1)   # kat çizgisi
		return b.build())


static func _sheet_mesh() -> Mesh:
	return _cached("sheet", func():
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.2, 0.008, 0.28), PAPER, Vector3.ZERO, 1)
		b.add("box", Vector3(0, 0.006, 0), Vector3(0.006, 0.004, 0.27), PAPER_INK, Vector3.ZERO, 1)
		return b.build())


## Yapraklar from → to arasında kıvrılarak uçar
static func _paper_flight(pj: PathJutsu, from: Vector3, to: Vector3, n: int, dur: float, spread: float) -> void:
	var m := cel(PAPER, 0.008, PAPER_INK, true, 1.5)
	for k in n:
		var s := mi(_sheet_mesh(), m)
		put(pj, s, from + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)))
		s.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var a: Vector3 = s.global_position
		var mid := a.lerp(to, 0.5) + Vector3(randf_range(-spread, spread), randf_range(0.0, spread), randf_range(-spread, spread))
		var b2 := to + Vector3(randf_range(-0.8, 0.8), randf_range(-0.3, 0.3), randf_range(-0.8, 0.8))
		var sp := Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var dly := randf() * dur * 0.4
		var tw := s.create_tween()
		tw.tween_interval(dly)
		tw.tween_method(func(u: float):
			if is_instance_valid(s):
				s.global_position = a.lerp(mid, u).lerp(mid.lerp(b2, u), u)
				s.rotation += sp * 0.016, 0.0, 1.0, dur)
		tw.tween_property(s, "scale", Vector3.ONE * 0.05, 0.1)
		tw.tween_callback(s.queue_free)


## Hedefin üstünde dönen kâğıt bulutu: iç içe halkalar halinde yaprak diski
static func _paper_cloud() -> Node3D:
	var root := Node3D.new()
	var b := MB.new()
	for ring in 4:
		var rad := 0.8 + ring * 0.8
		var n := 10 + ring * 7
		for k in n:
			var a := TAU * k / n + ring * 0.3
			b.add("box", Vector3(cos(a) * rad, randf_range(-0.25, 0.25), sin(a) * rad), Vector3(0.22, 0.01, 0.3), PAPER.darkened(randf() * 0.12),
				Vector3(randf_range(-25, 25), -rad_to_deg(a), randf_range(-25, 25)), 1)
	root.add_child(mi(b.build(), cel(Color.WHITE, 0.01, PAPER_INK, true, 4.0)))
	return root


## Sırtta açılan kâğıt kanatlar (ref: kat kat beyaz yaprak tüyleri)
static func _paper_wings(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "Chest")
	if ba == null:
		ba = pj.bone_attach(c, "Spine2")
	if ba == null:
		return
	var m := cel(PAPER, 0.01, PAPER_INK, true, 1.2)
	for sx in [-1.0, 1.0]:
		var b := MB.new()
		for row in 3:
			for k in 9:
				var u := k / 8.0
				var x: float = sx * (0.15 + u * 1.3)
				var y: float = 0.15 + sin(u * PI * 0.8) * 0.45 - row * 0.18 - u * 0.25
				b.add("box", Vector3(x, y, -0.18 - row * 0.03), Vector3(0.2, 0.32 + row * 0.08, 0.012), PAPER.darkened(row * 0.06),
					Vector3(0, 0, sx * (20.0 + u * 50.0)), 1)
		var w := mi(b.build(), m)
		ba.add_child(w)
		w.scale = Vector3(0.05, 1.0, 1.0)
		var tw := w.create_tween()
		tw.tween_property(w, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(maxf(0.1, dur - 0.5))
		tw.tween_property(w, "scale", Vector3(0.05, 0.6, 1.0), 0.25)
	pj.free_after(dur, ba)


# ================================================================== 4) Kâğıt Çakram
## Ref: başın üstünde yatay, tırtıklı dış kenarlı beyaz kâğıt halka, içinde dönen akım çizgileri.
## Hazırlık: ellerden yükselen yapraklar halkayı örer. Bırakış: halka dönerek hedefe uçar, keser, geri döner ve dağılır.
static func form_kami_chakuramu(pj: PathJutsu, c: Node3D, rt: float) -> void:
	var ring := _chakram()
	put(pj, ring, c.global_position + Vector3.UP * 2.5)
	ring.scale = Vector3.ONE * 0.05
	c.set_meta("pj_ring", ring)
	for r in [true, false]:
		_paper_flight(pj, pj.hand_pos(c, r), c.global_position + Vector3.UP * 2.5, 14, maxf(0.2, rt * 0.8), 0.9)
	var t0 := Game.now()
	pj.every(rt + 0.05, 1.0 / 30.0, func(_i, _k):
		if is_instance_valid(ring) and is_instance_valid(c):
			var f := clampf((Game.now() - t0) / maxf(0.1, rt), 0.0, 1.0)
			ring.scale = Vector3.ONE * lerpf(0.05, 1.0, f)
			ring.global_position = c.global_position + Vector3.UP * 2.5
			ring.rotation.y += 0.35, Callable())
	pj.after(rt + 1.0, func():
		if is_instance_valid(ring) and is_instance_valid(c) and c.has_meta("pj_ring") and c.get_meta("pj_ring") == ring:
			c.remove_meta("pj_ring")
			ring.queue_free())


static func kami_chakuramu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.8)
	var ring: Node3D = null
	if c.has_meta("pj_ring") and is_instance_valid(c.get_meta("pj_ring")):
		ring = c.get_meta("pj_ring")
		c.remove_meta("pj_ring")
		ring.scale = Vector3.ONE
	else:
		ring = _chakram()
		put(pj, ring, c.global_position + Vector3.UP * 2.5)
	var o: Vector3 = c.global_position + Vector3.UP * 2.5
	ring.global_position = o
	var dest: Vector3 = (tt.global_position + Vector3.UP if is_instance_valid(tt) else o + pj.fwd(c, t) * 18.0)
	var hit_ids = []
	var tw := ring.create_tween()
	tw.tween_property(ring, "global_position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "global_position", o, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(ring):
			_paper_flight(pj, ring.global_position, ring.global_position + Vector3.DOWN * 1.2, 12, 0.35, 0.5)
			ring.queue_free())
	pj.every(1.0, 1.0 / 30.0, func(_i, _k):
		if is_instance_valid(ring):
			ring.rotation.y += 0.55
			ring.rotation.z = 0.25   # hafif yatık dönüş
			if _i % 2 == 0:
				for e in pj.enemies_near(c, ring.global_position, 1.5):
					if not e in hit_ids and pj.live(e):
						hit_ids.append(e)
						_paper_cut(pj, e.global_position + Vector3.UP)
						e.take_hit(pj.inf(c, "kami_chakuramu", 1.1, {"knock": 6.0, "kind": "heavy", "bleed": 2.0})))
	Sfx.play("whoosh", c.global_position, 1.1)


## Kâğıt çakram: tırtıklı kenarlı yassı halka (koyu kontur halkası altında) + iç akım çizgileri
static func _chakram() -> Node3D:
	var root := Node3D.new()
	var mesh: Mesh = _cached("chakram", func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 64
		for layer in 2:
			var col: Color = PAPER if layer == 0 else PAPER_INK
			var y: float = 0.0 if layer == 0 else -0.012
			var grow: float = 0.0 if layer == 0 else 0.045
			var base := layer * (seg + 1) * 2
			for i in seg + 1:
				var a := TAU * i / seg
				var jag := 1.0 + (0.16 if i % 2 == 0 else 0.0) + 0.05 * sin(i * 2.7)
				var dv := Vector3(cos(a), 0, sin(a))
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(float(i) / seg, 0.0))
				st.add_vertex(dv * (0.62 - grow) + Vector3.UP * y)
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(float(i) / seg, 1.0))
				st.add_vertex(dv * (jag + grow) + Vector3.UP * y)
			for i in seg:
				var q := base + i * 2
				st.add_index(q)
				st.add_index(q + 1)
				st.add_index(q + 2)
				st.add_index(q + 1)
				st.add_index(q + 3)
				st.add_index(q + 2)
		return st.commit())
	root.add_child(mi(mesh, cel(Color.WHITE, 0.0, INK, true, 2.5)))
	# iç akım çizgileri: ince elips şeritler
	for k in 3:
		var pts := []
		var rr := 0.7 + k * 0.1
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(Vector3(cos(a) * rr, 0.02 + k * 0.004, sin(a) * rr * 0.93))
		var sm := streak_mat(Color(0.55, 0.55, 0.65, 0.9), Color(0.55, 0.55, 0.65, 0.9), 0.0, 2.5)
		sm.set_shader_parameter("dash", 3.0)
		sm.set_shader_parameter("flow", 1.5 + k)
		root.add_child(mi(ribbon(pts, 0.025, Vector3.UP, false), sm))
	return root


## Kâğıt kesiği: beyaz tırtıklı kısa parlama + saçılan kâğıt kırpıntıları
static func _paper_cut(pj: PathJutsu, p: Vector3) -> void:
	flash(pj, p, Color(0.95, 0.95, 1.0), 1.0, 2.0, 0.18, false, 1.3)
	burst(pj, p, _sheet_mesh(), cel(PAPER, 0.006, PAPER_INK, true, 1.0), 10, 0.7, {"r": 0.2, "vmin": 2.0, "vmax": 5.0, "g": Vector3(0, -4, 0), "damp": 2.0,
		"smin": 0.4, "smax": 0.8, "spin": 600.0})


# ================================================================== 5) Rinnegan Genjutsusu (tomoeli Rinnegan)
## Kurgu: gözde tomoeli Rinnegan işareti belirir, bakış önüne ince halkalar yayar → görüş alanındaki her kurbanın başında
## dönen Rinnegan izi, gözden başa uzanan ince mor bakış çizgisi, ayağında genişleyen mor dalga halkaları.
static func sharinnegan_genjutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var fd: Vector3 = c.face_dir()
	var eye: Vector3 = Jutsu._mouth(c) + Vector3.UP * 0.12
	var em := flare_mat(Color(0.78, 0.62, 1.0), 4.0, false, true, 1.2, 5.0)
	em.set_shader_parameter("spin", 2.5)
	var ef := mi(_quad(), em)
	put(pj, ef, eye + fd * 0.3)
	ef.scale = Vector3.ONE * 0.1
	var etw := ef.create_tween()
	etw.tween_property(ef, "scale", Vector3.ONE * 0.7, 0.15).set_trans(Tween.TRANS_BACK)
	fade_out(ef, em, 0.45, 0.25)
	for k in 3:
		var p: Vector3 = eye + fd * (1.5 + k * 1.6)
		pj.after(k * 0.06, func():
			flash(pj, p, Color(0.7, 0.5, 1.0, 0.8), 1.0 + k * 0.6, 3.0, 0.35, true, 1.6, 2.0))
	var n = 0
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if not Combat.hostile(c, f) or f.is_dead():
			continue
		var d = f.global_position - c.global_position
		if d.length() > 45.0 or fd.dot(d.normalized()) < 0.35:
			continue
		var gm = Eyes.genjutsu_land(c, f, true)
		if gm <= 0.0:
			continue
		n += 1
		var hold = (2.5 if (f.has_meta("boss") or f is TailedBeast) else 5.0) * gm
		pj.st(f, "stun", hold)
		_genjutsu_mark(pj, f, eye, float(hold))
		Combat.popup_text(f.global_position + Vector3.UP * 2.6, "Genjutsu", Color(0.8, 0.6, 1.0))
	if c is Player and n == 0:
		Hud.msg("Bakışının önünde genjutsuya düşecek kimse yok.", Color(0.8, 0.7, 1.0))
	Sfx.play("genjutsu", c.global_position, 1.0)


static func _genjutsu_mark(pj: PathJutsu, f: Node3D, eye: Vector3, hold: float) -> void:
	var top: Vector3 = f.global_position + Vector3.UP * 1.5
	var pts := [eye, eye.lerp(top, 0.5) + Vector3.UP * 0.3, top]
	var gm := streak_mat(Color(0.75, 0.55, 1.0, 0.85), Color(0.4, 0.2, 0.7, 0.85), 0.2, 2.0)
	gm.set_shader_parameter("reveal", 0.0)
	var ln := mi(ribbon(pts, 0.06, Vector3.ZERO, false), gm)
	put(pj, ln, Vector3.ZERO)
	tween_param(ln, gm, "reveal", 0.0, 1.0, 0.12)
	fade_out(ln, gm, 0.25, 0.2)
	# başın üstünde dönen Rinnegan izi (hedefe bağlı, tutulma süresince)
	var big: float = 1.0 + (2.0 if f is TailedBeast else 0.0)
	var sm := flare_mat(Color(0.78, 0.62, 1.0, 0.9), 4.0, false, true, 2.0, 5.0)
	sm.set_shader_parameter("spin", 1.2)
	var s := mi(_quad(), sm)
	f.add_child(s)
	s.position = Vector3.UP * (2.3 * big)
	s.scale = Vector3.ONE * 0.6 * big
	fade_out(s, sm, maxf(0.2, hold - 0.3), 0.3)
	for k in 3:
		var fp: Vector3 = f.global_position
		pj.after(k * 0.18, func():
			ground_ring(pj, fp, Color(0.7, 0.5, 1.0, 0.9), 2.0 * big, 0.6))


# ================================================================== 6) Çağırma: Ibuse Zehri
## Ref: dev semender Ibuse (pembe ağız içi, kahverengi deri). Oyunun gerçek Ibuse modeli (SummonModels "salamander").
## Kurgu: zeminde mürekkep sözleşme mührü yayılır → semender mühürden yükselerek belirir, etrafa mor mürekkep damlaları
## saçılır → ağzından yere çöken bantlı mor zehir sisi akar; bataklıkta 8 sn kalıcı sis yatakları ve köpüren kabarcıklar
## → semender mührün içine batarak çekilir.
static func kuchiyose_ibuse_dokukami(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var d: Vector3 = pj.fwd(c, t)
	var at: Vector3 = pj.gp(c.global_position + d * 15.0)   # 26 m'lik semender çağıranın önünde belirir (kuyruğu çağırana uzanır)
	_contract_seal(pj, at, 6.0, 1.2)
	var parts = SummonModels.build("salamander", 6.0, 26.0)
	var ib: Node3D = parts["root"]
	pj.scene_add(ib, at)
	ib.look_at(ib.global_position + d, Vector3.UP)   # model -Z'ye (başa) bakar
	ib.scale = Vector3.ONE * 0.05
	ib.create_tween().tween_property(ib, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	ib.global_position = at - Vector3.UP * 2.5
	ib.create_tween().tween_property(ib, "global_position", at, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst(pj, at + Vector3.UP * 0.5, _sphere(8), cel(Color(0.28, 0.18, 0.36), 0.015, INK), 40, 1.1, {"r": 3.5, "dir": Vector3.UP, "spread": 50.0,
		"vmin": 5.0, "vmax": 10.0, "g": Vector3(0, -16, 0), "smin": 0.15, "smax": 0.4, "hold": 0.8})
	ground_ring(pj, at, Color(0.55, 0.4, 0.75), 9.0, 0.6)
	pj.after(0.6, func():
		if not is_instance_valid(ib):
			return
		var mouth: Vector3 = ib.global_transform * (parts.get("mouth", Vector3(0, 5.7, -9.7)) as Vector3)
		for k in 8:
			pj.after(k * 0.12, func():
				_poison_gout(pj, mouth, d, k))
		var zc: Vector3 = mouth + d * 9.0
		zc.y = at.y
		_poison_bog(pj, zc, 9.0, 8.0)
		pj.every(8.0, 0.5, func(_i, _k):
			for e in pj.enemies_near(c, zc, 9.0):
				if not pj.live(e):
					continue
				pj.st(e, "slow", 0.6)
				e.take_hit(pj.inf(c, "kuchiyose_ibuse_dokukami", 0.15, {"knock": 0.0, "kind": "light", "poison": 4.0}))))
	pj.after(9.0, func():
		if is_instance_valid(ib):
			_contract_seal(pj, ib.global_position, 5.0, 0.6)
			var tw := ib.create_tween()
			tw.set_parallel(true)
			tw.tween_property(ib, "global_position", ib.global_position - Vector3.UP * 5.0, 0.45).set_ease(Tween.EASE_IN)
			tw.tween_property(ib, "scale", Vector3.ONE * 0.05, 0.45).set_ease(Tween.EASE_IN)
			tw.chain().tween_callback(ib.queue_free))
	Sfx.play("poof", at, 0.6)


## Sözleşme mührü: zeminde dönen yazı halkası + merkezden yayılan mürekkep çizgileri
static func _contract_seal(pj: PathJutsu, at: Vector3, r: float, hold: float) -> void:
	ground_sigil(pj, at, Color(0.12, 0.08, 0.16, 0.95), r * 2.0, 5.0, hold, 0.4, false, 0.6)
	ground_sigil(pj, at, Color(0.55, 0.4, 0.8, 0.7), r * 2.2, 3.0, hold, 0.4, true)
	for k in 8:
		var a := TAU * k / 8.0 + randf_range(-0.1, 0.1)
		var dv := Vector3(cos(a), 0, sin(a))
		var pts := []
		for i in 8:
			var p := at + dv * (0.6 + i * (r - 0.6) / 7.0) + dv.cross(Vector3.UP) * sin(i * 1.3 + k) * 0.15
			p.y = pj.gp(p).y + 0.05
			pts.append(p)
		ground_trace(pj, pts, 0.18, INK, Color(0.3, 0.2, 0.4), 0.25, hold, 0.4)


## Ağızdan çıkan zehir dalgası: yassı bantlı sis kütleleri öne akıp yere çöker
static func _poison_gout(pj: PathJutsu, mouth: Vector3, d: Vector3, k: int) -> void:
	for q in 2:
		var mm := mist_mat(0.75, 7.0)
		var b := mi(_sphere(14), mm)
		var p0 := mouth + d * (2.0 + k * 1.6) + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4), randf_range(-0.6, 0.6))
		put(pj, b, p0)
		var rad := 1.0 + k * 0.5
		b.scale = Vector3(rad, rad * 0.7, rad) * 0.4
		var g: Vector3 = pj.gp(p0 + d * 3.0) + Vector3.UP * rad * 0.4
		var tw := b.create_tween()
		tw.set_parallel(true)
		tw.tween_property(b, "scale", Vector3(rad * 1.6, rad * 0.75, rad * 1.6), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "global_position", g, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_out(b, mm, 2.2, 1.3)


## Bataklık: yere yatık kalıcı sis yatakları + leke + köpüren mor kabarcıklar
static func _poison_bog(pj: PathJutsu, zc: Vector3, r: float, dur: float) -> void:
	var stain := cel(Color(0.3, 0.16, 0.36, 0.55), 0.0, INK, true, 6.0)
	var s := mi(_cyl(28), stain)
	put(pj, s, pj.gp(zc) + Vector3.UP * 0.03)
	s.scale = Vector3(r * 0.3, 0.02, r * 0.3)
	s.create_tween().tween_property(s, "scale", Vector3(r * 2.0, 0.02, r * 2.0), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_out(s, stain, dur, 1.0)
	for k in 9:
		var a := TAU * k / 9.0 + randf_range(-0.3, 0.3)
		var p: Vector3 = zc + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.15, 0.75)
		p = pj.gp(p)
		var mm := mist_mat(0.6, 7.0)
		var b := mi(_sphere(14), mm)
		put(pj, b, p + Vector3.UP * 0.5)
		var sz := randf_range(3.0, 5.0)
		b.scale = Vector3(sz * 0.3, 0.4, sz * 0.3)
		b.create_tween().tween_property(b, "scale", Vector3(sz, 1.6, sz * randf_range(0.8, 1.2)), randf_range(0.8, 1.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_out(b, mm, dur - 0.5, 1.0)
	var bub := burst(pj, zc + Vector3.UP * 0.2, _sphere(8), cel(Color(0.62, 0.4, 0.75), 0.012, Color(0.2, 0.08, 0.25)), 30, 1.0,
		{"emit": true, "r": r * 0.7, "dir": Vector3.UP, "spread": 15.0, "vmin": 0.5, "vmax": 1.6, "g": Vector3.ZERO, "smin": 0.1, "smax": 0.3, "start_scale": 0.3, "end_scale": 1.4, "hold": 0.85})
	pj.after(dur, func():
		if is_instance_valid(bub):
			bub.emitting = false
			pj.free_after(1.2, bub))


# ================================================================== 7) Susanoo: Tsukumo
## Ref: Susanoo renginde uzun, ince, ışıklı chakra iğneleri yatay akım izleriyle uçar. Gerçek Susanoo (Susanoo.of) kollarını
## kaldırır; ellerin çevresinde yay biçiminde iğneler belirir (öz + ışık halesi + akım izi), sırayla hedefe yağar;
## çarpınca iğne kırıkları ve tırtıklı parlama.
static func susanoo_tsukumo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_tsukumo")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col: Color = sn.color()
	var tg = Jutsu._tg(c, t, 34.0 + H * 1.2)
	var aim = MsArts._aim_fn(c, tg, 20.0 + H * 0.6)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 1.2)
	MsArts._anim(c, "cast", 0.9)
	sn.hide_weapons(1.8)
	sn.pose({"arms": Susanoo.arm(true, d * 0.55 + Vector3.UP * 0.55 + side * 0.45, d * 0.75 + Vector3.UP * 0.55) + Susanoo.arm(false, d * 0.55 + Vector3.UP * 0.55 - side * 0.45, d * 0.75 + Vector3.UP * 0.55), "spine": -6.0}, 1.8)
	var spears = []
	var nmesh := _needle_mesh()
	var nmat := cel(col.lightened(0.45), 0.02, col.darkened(0.55), false, 3.0)
	var hmat := glow(Color(col.r, col.g, col.b, 0.55), 3.0, 1.0)
	for k in 16:
		MsArts._later(0.15 + k * 0.025, func():
			if not is_instance_valid(sn):
				return
			var u = (k / 15.0) * 2.0 - 1.0
			var base = sn.hand(true).lerp(sn.hand(false), 0.5) + side * u * S * 0.9 + Vector3.UP * (S * 0.25 + (1.0 - u * u) * S * 0.5)
			var sp := mi(nmesh, nmat)
			var halo := mi(_sphere(10), hmat)
			sp.add_child(halo)
			halo.scale = Vector3(0.3, 0.3, 1.9)
			MsArts._scene().add_child(sp)
			sp.global_transform = Transform3D(MsArts._zbasis(-(aim.call() - base).normalized()) * Basis.from_scale(Vector3.ONE * S * 0.45), base)
			sp.scale = Vector3.ONE * 0.05
			sp.create_tween().tween_property(sp, "scale", Vector3.ONE * S * 0.45, 0.2).set_trans(Tween.TRANS_BACK)
			flash(pj, base, col.lightened(0.3), 0.4 + S * 0.1, 0.0, 0.25)
			spears.append(sp))
	Sfx.play("chakra", c.global_position, 0.8)
	MsArts._later(0.75, func():
		if is_instance_valid(sn):
			sn.pose({"arms": Susanoo.arm(true, d * 0.9 + side * 0.25, d) + Susanoo.arm(false, d * 0.9 - side * 0.25, d), "spine": 10.0}, 0.8, true))
	MsArts._later(0.8, func():
		for k in spears.size():
			var sp: MeshInstance3D = spears[k]
			MsArts._later(k * 0.035, func():
				if not is_instance_valid(sp):
					return
				if not is_instance_valid(c):
					sp.queue_free()
					return
				var from = sp.global_position
				var to: Vector3 = aim.call() + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * (1.0 + S * 0.1)
				var dir = (to - from).normalized()
				sp.global_transform = Transform3D(MsArts._zbasis(-dir) * Basis.from_scale(Vector3.ONE * S * 0.45), from)
				_needle_trail(sp, col)
				var dur = clampf(from.distance_to(to) / 80.0, 0.12, 0.8)
				var tw = sp.create_tween()
				tw.tween_property(sp, "global_position", to, dur)
				tw.tween_callback(func():
					sp.queue_free()
					if is_instance_valid(c):
						Combat.hit_sphere(c, to, 1.6 + S * 0.08, Jutsu._inf(c, "susanoo_tsukumo", 0.3, {"knock": 3.0, "kind": "heavy"}))
						_needle_impact(pj, to, dir, col, S)))
		Sfx.play("whoosh", c.global_position, 1.3))


static func _needle_mesh() -> Mesh:
	return _cached("needle", func():
		var b := MB.new()
		b.add("cyl", Vector3.ZERO, Vector3(0.05, 1.1, 0.05), Color.WHITE, Vector3(90, 0, 0), 6)
		b.add("cone", Vector3(0, 0, -0.7), Vector3(0.11, 0.32, 0.11), Color.WHITE, Vector3(-90, 0, 0), 6)
		b.add("cone", Vector3(0, 0, 0.62), Vector3(0.07, 0.16, 0.07), Color.WHITE, Vector3(90, 0, 0), 6)
		return b.build())


## İğnenin arkasında çapraz iki akım şeridi (kuyrukta söner)
static func _needle_trail(sp: Node3D, col: Color) -> void:
	var m := streak_mat(Color(col.r, col.g, col.b, 0.75), col.lightened(0.5), 0.9, 3.0)
	var a := mi(_quad(), m)
	sp.add_child(a)
	a.position = Vector3(0, 0, 1.6)
	a.rotation_degrees = Vector3(0, 90, 0)
	a.scale = Vector3(3.2, 0.16, 1.0)
	var b := mi(_quad(), m)
	a.add_child(b)
	b.rotation_degrees = Vector3(90, 0, 0)


static func _needle_impact(pj: PathJutsu, to: Vector3, dir: Vector3, col: Color, S: float) -> void:
	flash(pj, to, col.lightened(0.35), 1.0 + S * 0.08, 2.0, 0.22, true, 1.3, 3.0)
	burst(pj, to, _box(), glow(col, 1.0, 0.2), 6, 0.35, {"r": 0.1, "dir": -dir, "spread": 60.0, "vmin": 4.0, "vmax": 9.0, "g": Vector3(0, -6, 0),
		"smin": 0.04, "smax": 0.08, "align": true, "end_scale": 0.3})
	if to.y - pj.gp(to).y < 0.8:
		ground_ring(pj, to, col, 1.4 + S * 0.08, 0.35)


# ================================================================== 8) Shura no Kō (Asura Saldırısı)
## Ref: önkola takılı, kat kat koyu gri, delik sıralı dev top; uçlarında beyaz topuzlu çatallar. Kurgu: top önkola açılır →
## mavi chakra namluya toplanır, ağızda ışık küresi şişer → beyaz özlü mavi kenarlı akan bantlı ışın + ışın boyunca
## ilerleyen şok halkaları → menzil sonunda tırtıklı beyaz patlama, yükselen ışık sütunları, iki halka, kaya parçaları,
## kalıcı kararmış iz ve çatlaklar.
static func shura_no_ko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 40.0)
	pj.busy(c, 1.6)
	if c is Player:
		c.input_locked = 1.4
	pj.anim(c, "cast", 0.8)
	var ba = pj.bone_attach(c, "RightLowerArm")
	var gun: Node3D = null
	if ba:
		gun = _asura_cannon()
		ba.add_child(gun)
		gun.scale = Vector3(1, 0.05, 1)
		gun.create_tween().tween_property(gun, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		pj._asura_hand(c, true)
	pj.after(0.2, func():
		if pj.live(c):
			var hp: Vector3 = pj.hand_pos(c, true)
			burst(pj, hp, _sphere(6), glow(Color(0.6, 0.85, 1.0, 0.9), 1.0, 0.5), 40, 0.5, {"expl": 0.2, "r": 1.6, "dir": Vector3.UP, "spread": 180.0,
				"vmin": 0.0, "vmax": 0.3, "g": Vector3.ZERO, "radial": -14.0, "smin": 0.06, "smax": 0.14, "end_scale": 0.3})
			var orb := mi(_sphere(14), glow(Color(0.8, 0.95, 1.0), 1.0, 0.6))
			if is_instance_valid(gun):
				gun.add_child(orb)
				orb.position = Vector3(0, 0.62, 0)
			else:
				put(pj, orb, hp)
			orb.scale = Vector3.ONE * 0.05
			var otw := orb.create_tween()
			otw.tween_property(orb, "scale", Vector3.ONE * 0.4, 0.55)
			otw.tween_callback(orb.queue_free))
	pj.after(0.75, func():
		if not pj.live(c):
			return
		var o: Vector3 = pj.hand_pos(c, true)
		var dir: Vector3 = pj.aim_at(c, tt, o)
		var L = 40.0
		var beam := Node3D.new()
		pj.get_tree().current_scene.add_child(beam)
		beam.global_position = o + dir * L * 0.5
		beam.look_at(o + dir * L + Vector3(0.001, 0, 0), Vector3.UP)
		beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		var bm := beam_mat(Color(1, 1, 1), Color(0.35, 0.65, 1.0), L * 0.25, 6.0)
		var outer := mi(_cyl(20), bm)
		beam.add_child(outer)
		outer.scale = Vector3(1.8, 1.0, 1.8)
		var inner := mi(_cyl(12), glow(Color(1.0, 1.0, 1.0, 0.9), 6.0, 0.2))
		beam.add_child(inner)
		inner.scale = Vector3(0.7, 1.0, 0.7)
		beam.scale = Vector3(0.2, L, 0.2)
		var btw := beam.create_tween()
		btw.tween_property(beam, "scale", Vector3(1.0, L, 1.0), 0.08)
		btw.tween_interval(0.35)
		btw.tween_property(beam, "scale", Vector3(0.02, L, 0.02), 0.25)
		btw.tween_callback(beam.queue_free)
		# ışın boyunca ilerleyen şok halkaları
		for k in 5:
			var rm := flare_mat(Color(0.7, 0.88, 1.0, 0.9), 3.0, true, false, 5.0)
			var rg := mi(_quad(), rm)
			put(pj, rg, o + dir * 2.0)
			rg.look_at(o + dir * 3.0 + Vector3(0.001, 0, 0), Vector3.UP)
			rg.scale = Vector3.ONE * 2.6
			var rtw := rg.create_tween()
			rtw.set_parallel(true)
			rtw.tween_property(rg, "global_position", o + dir * L, 0.4).set_ease(Tween.EASE_IN).set_delay(k * 0.07)
			rtw.tween_property(rg, "scale", Vector3.ONE * 4.2, 0.4).set_delay(k * 0.07)
			rtw.chain().tween_callback(rg.queue_free)
		flash(pj, o + dir * 0.6, Color(1, 1, 1), 2.4, 1.0, 0.2, true, 1.2, 4.0)
		for k in 8:
			pj.hit(c, o + dir * (3.0 + k * 4.6), 2.6, pj.inf(c, "shura_no_ko", 0.45, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "dir": dir}))
		var endp = o + dir * L
		var ground = pj.gp(endp)
		var ep = endp if endp.y - ground.y > 2.0 else ground
		_asura_blast(pj, ep, ground, endp.y - ground.y <= 2.0)
		pj.hit(c, ep, 9.0, pj.inf(c, "shura_no_ko", 1.6, {"knock": 26.0, "launch": 7.0, "kind": "heavy"}))
		pj.shake(1.4)
		Sfx.play("boom", ep, 0.5))
	pj.after(1.6, func():
		if is_instance_valid(gun):
			gun.queue_free()
		if pj.live(c):
			pj._asura_hand(c, false))
	Sfx.play("charge", c.global_position, 0.8)


## Asura topu (ref: kat kat genişleyen koyu gri gövde, delik sırası, beyaz topuzlu dört çatal)
static func _asura_cannon() -> Node3D:
	var mesh: Mesh = _cached("asura_cannon", func():
		var b := MB.new()
		var dk := Color(0.22, 0.22, 0.25)
		var dd := Color(0.13, 0.13, 0.15)
		b.add("cyl", Vector3(0, 0.12, 0), Vector3(0.2, 0.24, 0.2), dk, Vector3.ZERO, 14)
		b.add("cyl", Vector3(0, 0.27, 0), Vector3(0.25, 0.08, 0.25), dd, Vector3.ZERO, 14)
		b.add("cyl", Vector3(0, 0.38, 0), Vector3(0.3, 0.14, 0.3), dk, Vector3.ZERO, 14)
		b.add("cyl", Vector3(0, 0.5, 0), Vector3(0.36, 0.1, 0.36), dd, Vector3.ZERO, 14)
		b.add("cyl", Vector3(0, 0.6, 0), Vector3(0.3, 0.1, 0.3), dk, Vector3.ZERO, 14)
		b.add("cyl", Vector3(0, 0.66, 0), Vector3(0.2, 0.02, 0.2), Color(0.05, 0.05, 0.06), Vector3.ZERO, 14)   # namlu ağzı
		for k in 10:   # delik sırası
			var a := TAU * k / 10.0
			b.add("sphere", Vector3(cos(a) * 0.15, 0.38, sin(a) * 0.15), Vector3(0.04, 0.05, 0.04), Color(0.04, 0.04, 0.05), Vector3.ZERO, 6)
		for k in 16:   # dikey oluklar
			var a := TAU * k / 16.0
			b.add("box", Vector3(cos(a) * 0.125, 0.12, sin(a) * 0.125), Vector3(0.012, 0.22, 0.012), dd, Vector3(0, -rad_to_deg(a), 0), 1)
		for k in 4:   # beyaz topuzlu çatallar
			var a := TAU * k / 4.0 + 0.4
			var dv := Vector3(cos(a), 0, sin(a))
			b.add("cyl", dv * 0.2 + Vector3(0, 0.2, 0), Vector3(0.02, 0.18, 0.02), Color(0.9, 0.88, 0.84), Vector3(rad_to_deg(sin(a)) * 0.6, 0, -rad_to_deg(cos(a)) * 0.6), 6)
			b.add("sphere", dv * 0.27 + Vector3(0, 0.3, 0), Vector3(0.05, 0.08, 0.05), Color(0.95, 0.93, 0.9), Vector3.ZERO, 8)
		return b.build())
	return mi(mesh, cel(Color.WHITE, 0.01, INK, false, 0.8))


## Işın sonu patlaması
static func _asura_blast(pj: PathJutsu, ep: Vector3, ground: Vector3, on_ground: bool) -> void:
	flash(pj, ep, Color(0.82, 0.94, 1.0), 6.0, 2.0, 0.35, true, 1.3, 6.0)
	flash(pj, ep, Color(1, 1, 1), 3.0, 1.0, 0.18, true, 1.6, 6.0)
	for k in 7:   # yükselen ışık sütunları
		var a := TAU * k / 7.0
		var p: Vector3 = ep + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 2.5)
		var cm := glow(Color(0.7, 0.88, 1.0, 0.8), 6.0, 0.4)
		var cl := mi(_cyl(8), cm)
		put(pj, cl, p)
		cl.scale = Vector3(0.35, 0.1, 0.35)
		var h := randf_range(5.0, 9.0)
		var tw := cl.create_tween()
		tw.set_parallel(true)
		tw.tween_property(cl, "scale", Vector3(0.15, h, 0.15), 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(cl, "global_position", p + Vector3.UP * h * 0.5, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float): set_fade(cm, v), 1.0, 0.0, 0.45)
		tw.chain().tween_callback(cl.queue_free)
	if on_ground:
		ground_ring(pj, ground, Color(0.8, 0.92, 1.0), 10.0, 0.5)
		pj.after(0.1, func():
			ground_ring(pj, ground, Color(0.5, 0.75, 1.0), 7.0, 0.6))
		cracks(pj, ground, 10.0, 11, Color(0.12, 0.11, 0.13), 4.0)
		var scm := cel(Color(0.12, 0.12, 0.16, 0.75), 0.0, INK, true, 6.0)
		var sc := mi(_cyl(24), scm)
		put(pj, sc, ground + Vector3.UP * 0.025)
		sc.scale = Vector3(6.0, 0.02, 6.0)
		fade_out(sc, scm, 3.5, 1.0)
		debris(pj, ground, Color(0.45, 0.42, 0.4), 26, 12.0, 1.4, 0.35)
		dust(pj, ground, 14, 1.6, 1.2)
	else:
		burst(pj, ep, _box(), glow(Color(0.7, 0.9, 1.0), 2.0, 0.2), 20, 0.5, {"r": 0.5, "vmin": 6.0, "vmax": 14.0, "g": Vector3.ZERO, "damp": 4.0,
			"smin": 0.06, "smax": 0.14, "align": true})


# ================================================================== 9) Dantō no Hiya (Asura füzeleri)
## Ref: açılan elin bileğinden yelpaze gibi fırlayan gri kapsül füzeler, kuyruklarında tırtıklı ateş parıltısı.
## Kurgu: bilekte yelpaze füze yuvası açılır → her füze: gri kapsül + kuyrukta titreyen tırtıklı alev + arkasında
## küçülerek kaybolan beyaz cel duman boncukları → çarpınca turuncu tırtıklı patlama, alev kırıntıları, kara parça, yanık iz.
static func danto_no_hiya(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 32.0)
	pj.busy(c, 1.4)
	pj.anim(c, "cast", 1.0)
	pj._asura_hand(c, true)
	var ba = pj.bone_attach(c, "RightLowerArm")
	var rack: Node3D = null
	if ba:
		var rack_mesh: Mesh = _cached("missile_rack", func():
			var b := MB.new()
			b.add("cyl", Vector3(0, 0.12, 0), Vector3(0.16, 0.08, 0.16), Color(0.3, 0.3, 0.34), Vector3.ZERO, 12)
			for k in 7:   # yelpaze gibi açılan kapsüller
				var a := lerpf(-60.0, 60.0, k / 6.0)
				var off := Vector3(sin(deg_to_rad(a)) * 0.12, 0.3 + cos(deg_to_rad(a)) * 0.08, 0)
				b.add("cyl", off, Vector3(0.06, 0.3, 0.06), Color(0.32, 0.3, 0.34), Vector3(0, 0, -a), 8)
				b.add("sphere", off + Vector3(sin(deg_to_rad(a)), cos(deg_to_rad(a)), 0) * 0.16, Vector3(0.06, 0.07, 0.06), Color(0.62, 0.6, 0.66), Vector3.ZERO, 8)
			return b.build())
		rack = mi(rack_mesh, cel(Color.WHITE, 0.008, INK, false, 0.8))
		ba.add_child(rack)
		rack.scale = Vector3(0.05, 0.05, 0.05)
		rack.create_tween().tween_property(rack, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	var foes = pj.enemies_near(c, c.global_position, 32.0)
	var mmesh := _missile_mesh()
	var mmat := cel(Color.WHITE, 0.012, INK, false, 1.0)
	var smoke := cloud_mat(Color(0.96, 0.95, 0.93), Color(0.78, 0.77, 0.78), Color(0.5, 0.5, 0.52), 3.0, 0.03)
	for k in 9:
		pj.after(0.35 + k * 0.07, func():
			if not pj.live(c):
				return
			var o: Vector3 = pj.hand_pos(c, true)
			var tgt = tt if (tt and pj.live(tt) and k % 2 == 0) or foes.is_empty() else foes[k % foes.size()]
			var body := mi(mmesh, mmat)
			var jet := mi(_quad(), flare_mat(Color(1.0, 0.6, 0.2), 2.0, true, true, 1.5, 9.0))
			body.add_child(jet)
			jet.position = Vector3(0, 0, 0.36)
			jet.scale = Vector3.ONE * 0.4
			var aim = (pj.aim_at(c, tgt, o) + Vector3(randf_range(-0.25, 0.25), randf_range(0.1, 0.35), randf_range(-0.25, 0.25))).normalized()
			var pr = pj.shot(c, o, aim, 24.0, body, pj.inf(c, "danto_no_hiya", 0.45, {"knock": 8.0, "launch": 2.0, "kind": "heavy"}), tgt if tgt and pj.live(tgt) else null, false, 2.0, func(pp, _h):
				_missile_blast(pj, pp)
				pj.hit(c, pp, 2.5, pj.inf(c, "danto_no_hiya", 0.25, {"knock": 6.0, "kind": "light"})))
			flash(pj, o, Color(1.0, 0.75, 0.35), 0.6, 2.0, 0.12)
			if pr:
				var acc := {"t": 0.0, "f": 0}
				pr.on_tick = func(p, dt):
					acc["t"] += dt
					acc["f"] += 1
					if is_instance_valid(jet):
						jet.scale = Vector3.ONE * (0.32 + 0.14 * float(acc["f"] % 3))
					if acc["t"] >= 0.035:
						acc["t"] = 0.0
						_contrail_bead(pj, p.global_position + p.global_transform.basis.z * 0.4, smoke))
	pj.after(1.4, func():
		if is_instance_valid(rack):
			rack.queue_free()
		if pj.live(c):
			pj._asura_hand(c, false))
	Sfx.play("boom", c.global_position, 1.1)


static func _missile_mesh() -> Mesh:
	return _cached("missile", func():
		var b := MB.new()
		b.add("cyl", Vector3(0, 0, 0.05), Vector3(0.12, 0.42, 0.12), Color(0.34, 0.32, 0.37), Vector3(90, 0, 0), 10)
		b.add("sphere", Vector3(0, 0, -0.16), Vector3(0.12, 0.16, 0.12), Color(0.66, 0.64, 0.7), Vector3.ZERO, 10)
		b.add("cyl", Vector3(0, 0, 0.24), Vector3(0.13, 0.05, 0.13), Color(0.18, 0.17, 0.2), Vector3(90, 0, 0), 10)
		return b.build())


static func _contrail_bead(pj: PathJutsu, p: Vector3, m: Material) -> void:
	var b := mi(_sphere(8), m)
	put(pj, b, p + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05)))
	b.scale = Vector3.ONE * 0.12
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector3.ONE * 0.38, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector3.ONE * 0.02, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(b.queue_free)


static func _missile_blast(pj: PathJutsu, pp: Vector3) -> void:
	flash(pj, pp, Color(1.0, 0.6, 0.18), 2.4, 2.0, 0.25, true, 1.3, 3.0)
	flash(pj, pp, Color(1.0, 0.95, 0.7), 1.2, 1.0, 0.14, true, 1.5, 3.0)
	burst(pj, pp, _sphere(6), glow(Color(1.0, 0.55, 0.15), 1.5, 0.3), 12, 0.5, {"r": 0.3, "vmin": 3.0, "vmax": 7.0, "g": Vector3(0, -6, 0), "smin": 0.1, "smax": 0.25})
	debris(pj, pp, Color(0.22, 0.2, 0.2), 7, 6.0, 0.9, 0.18)
	if pp.y - pj.gp(pp).y < 0.8:
		var scm := cel(Color(0.12, 0.1, 0.1, 0.7), 0.0, INK, true, 4.0)
		var sc := mi(_cyl(16), scm)
		put(pj, sc, pj.gp(pp) + Vector3.UP * 0.025)
		sc.scale = Vector3(1.8, 0.02, 1.8)
		fade_out(sc, scm, 2.0, 0.8)


# ================================================================== 10) Konbi Henge
## Ref: turuncu, uzun kara çizgili kulaklı, açık ağızlı, pençeli, çok kuyruklu tilki canavarı. Kurgu: kurbağa ortağıyla birleşme:
## turuncu ve zeytin yeşili iki chakra şeridi çağıranı sarmal sarar → canavar şeridin içinden büyür, kuyrukları dalgalanır →
## pençe darbesi: hedefe üç dev beyaz-turuncu pençe izi iner, zeminde üç derin oluk, kaya parçaları → şeritlere dönüp kaybolur.
static func konbi_henge(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.4)
	var at: Vector3 = c.global_position
	_fusion_swirl(pj, at, 0.5)
	var beast := _fox_beast()
	pj.scene_add(beast, at)
	beast.look_at(at + pj.fwd(c, t), Vector3.UP)
	beast.scale = Vector3.ONE * 0.05
	beast.create_tween().tween_property(beast, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ground_ring(pj, at, Color(1.0, 0.6, 0.2), 6.0, 0.5)
	dust(pj, at, 12, 1.4, 1.0)
	if c.get("model"):
		c.model.visible = false
	var tails: Array = beast.get_meta("tails", [])
	pj.every(1.4, 1.0 / 30.0, func(_i, _k):
		var tm := Game.now()
		for q in tails.size():
			var tl = tails[q]
			if is_instance_valid(tl):
				var b0: Vector3 = tl.get_meta("rest")
				tl.rotation = b0 + Vector3(sin(tm * 3.0 + q) * 0.18, sin(tm * 2.2 + q * 1.7) * 0.22, 0.0), Callable())
	pj.after(0.55, func():
		if is_instance_valid(beast):
			var lt := beast.create_tween()
			lt.tween_property(beast, "global_position", at + pj.fwd(c, t) * 1.8 + Vector3.UP * 0.5, 0.15).set_ease(Tween.EASE_OUT)
			lt.tween_property(beast, "global_position", at + pj.fwd(c, t) * 1.8, 0.12).set_ease(Tween.EASE_IN))
	pj.after(0.7, func():
		var hit_at: Vector3 = (tt.global_position if is_instance_valid(tt) else at + pj.fwd(c, t) * 8.0)
		_claw_rake(pj, hit_at, pj.fwd(c, t))
		pj.shake(0.9)
		for h in pj.hit(c, hit_at + Vector3.UP, 4.5, pj.inf(c, "konbi_henge", 3.0, {"knock": 22.0, "launch": 5.0, "kind": "heavy"})):
			if is_instance_valid(h):
				flash(pj, h.global_position + Vector3.UP, Color(1.0, 0.7, 0.3), 1.8, 2.0, 0.22, true, 1.3, 3.0))
	pj.after(1.4, func():
		if is_instance_valid(beast):
			_fusion_swirl(pj, beast.global_position, 0.35)
			var tw := beast.create_tween()
			tw.tween_property(beast, "scale", Vector3.ONE * 0.05, 0.25).set_ease(Tween.EASE_IN)
			tw.tween_callback(beast.queue_free)
		if is_instance_valid(c) and c.get("model"):
			c.model.visible = true)
	Sfx.play("roar", at, 0.7)


## Birleşme sarmalı: turuncu + zeytin yeşili iki şerit yukarı dolanır
static func _fusion_swirl(pj: PathJutsu, at: Vector3, dur: float) -> void:
	for k in 2:
		var pts := []
		for i in 40:
			var u := i / 39.0
			var a := k * PI + u * TAU * 2.5
			var r := lerpf(2.6, 1.2, u)
			pts.append(Vector3(cos(a) * r, u * 8.0, sin(a) * r))
		var col: Color = Color(1.0, 0.55, 0.15) if k == 0 else Color(0.55, 0.62, 0.25)
		var m := streak_mat(col, col.darkened(0.45), 0.3, 4.0)
		m.set_shader_parameter("reveal", 0.0)
		var x := mi(ribbon(pts, 0.7, Vector3.ZERO, true), m)
		put(pj, x, at)
		tween_param(x, m, "reveal", 0.0, 1.0, dur * 0.6)
		var tw := x.create_tween()
		tw.tween_property(x, "rotation:y", PI * 1.5, dur + 0.2)
		fade_out(x, m, dur * 0.7, 0.3)


## Tilki canavarı (ref'ten): gövde, göğüs, baş, açık çene, uzun kara çizgili kulaklar, pençeli bacaklar, dalgalanan kuyruklar.
## Model -Z'ye bakar; yükseklik ≈ 8 m.
static func _fox_beast() -> Node3D:
	var root := Node3D.new()
	var mat := cel(Color.WHITE, 0.05, Color(0.24, 0.1, 0.03), false, 6.0)
	var body: Mesh = _cached("fox_body", func():
		var b := MB.new()
		var fur := FUR
		var lite := Color(0.98, 0.72, 0.36)
		b.add("sphere", Vector3(0, 3.6, 0.8), Vector3(3.4, 3.2, 5.4), fur, Vector3(-8, 0, 0), 14)
		b.add("sphere", Vector3(0, 3.6, -1.5), Vector3(3.0, 3.4, 3.0), lite, Vector3.ZERO, 14)
		b.add("sphere", Vector3(0, 5.6, -2.8), Vector3(2.6, 2.2, 2.4), fur, Vector3.ZERO, 14)
		b.add("sphere", Vector3(0, 5.15, -4.0), Vector3(1.3, 0.9, 1.7), fur, Vector3.ZERO, 12)
		b.add("box", Vector3(0, 4.8, -3.95), Vector3(1.0, 0.32, 1.3), Color(0.55, 0.1, 0.12), Vector3(12, 0, 0), 1)   # açık ağız
		b.add("sphere", Vector3(0, 4.55, -3.8), Vector3(1.0, 0.45, 1.3), fur, Vector3(18, 0, 0), 10)   # alt çene
		for k in 6:   # dişler
			var x := lerpf(-0.42, 0.42, k / 5.0)
			b.add("cone", Vector3(x, 4.95, -4.5 + absf(x) * 0.6), Vector3(0.12, 0.28, 0.12), Color(1, 1, 1), Vector3(180, 0, 0), 5)
		b.add("sphere", Vector3(0, 5.35, -4.85), Vector3(0.28, 0.2, 0.2), Color(0.1, 0.06, 0.05), Vector3.ZERO, 8)   # burun
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.95, 7.2, -2.5), Vector3(0.85, 2.4, 0.5), fur, Vector3(-10, 0, -sx * 16.0), 6)   # kulak
			b.add("cone", Vector3(sx * 0.98, 7.1, -2.78), Vector3(0.36, 2.0, 0.1), Color(0.14, 0.1, 0.14), Vector3(-10, 0, -sx * 16.0), 6)   # kara çizgi
			b.add("sphere", Vector3(sx * 0.6, 5.95, -3.85), Vector3(0.38, 0.18, 0.12), Color(0.9, 0.12, 0.1), Vector3(0, 0, sx * 18.0), 8)   # göz
			b.add("box", Vector3(sx * 0.6, 5.95, -3.92), Vector3(0.05, 0.16, 0.02), Color(0.05, 0.02, 0.02), Vector3.ZERO, 1)
			b.add("cyl", Vector3(sx * 1.55, 1.7, -1.9), Vector3(0.95, 3.4, 0.95), fur, Vector3(14, 0, 0), 10)   # ön bacak
			b.add("sphere", Vector3(sx * 1.55, 0.3, -2.5), Vector3(1.25, 0.65, 1.6), fur, Vector3.ZERO, 10)   # pati
			for q in 3:
				b.add("cone", Vector3(sx * 1.55 + (q - 1) * 0.36, 0.25, -3.35), Vector3(0.16, 0.55, 0.16), Color(0.98, 0.97, 0.93), Vector3(-80, 0, 0), 5)   # pençe
			b.add("cyl", Vector3(sx * 1.6, 1.5, 2.6), Vector3(1.1, 3.0, 1.1), fur, Vector3(-12, 0, 0), 10)   # arka bacak
			b.add("sphere", Vector3(sx * 1.6, 0.3, 2.3), Vector3(1.2, 0.6, 1.5), fur, Vector3.ZERO, 10)
		return b.build())
	root.add_child(mi(body, mat))
	var tail_mesh: Mesh = _cached("fox_tail", func():
		var b := MB.new()
		for i in 9:
			var u := i / 8.0
			var p := Vector3(0, sin(u * PI * 0.8) * 2.4 + u * 1.6, u * 7.0)
			var r := lerpf(1.1, 0.35, u)
			b.add("sphere", p, Vector3(r, r, 1.4), FUR if u < 0.8 else Color(0.98, 0.72, 0.36), Vector3.ZERO, 10)
		return b.build())
	var tails := []
	for k in 7:
		var tl := Node3D.new()
		root.add_child(tl)
		tl.position = Vector3(0, 4.0, 3.2)
		var rest := Vector3(deg_to_rad(-20.0 - absf(k - 3) * 6.0), deg_to_rad((k - 3) * 24.0), 0.0)
		tl.rotation = rest
		tl.set_meta("rest", rest)
		tl.add_child(mi(tail_mesh, mat))
		tails.append(tl)
	root.set_meta("tails", tails)
	return root


## Pençe tırmığı: üç dev pençe izi iner + zeminde üç oluk + kaya parçaları
static func _claw_rake(pj: PathJutsu, hit_at: Vector3, d: Vector3) -> void:
	var side := d.cross(Vector3.UP).normalized()
	for k in 3:
		var off := (Vector3.UP * 0.51 - side * 0.86) * (k - 1) * 0.8   # kesiğe dik paralel üç iz
		var pts := []
		for i in 16:
			var u := i / 15.0
			pts.append(hit_at + off + Vector3.UP * (4.2 - 4.4 * u) + side * (2.4 - 4.8 * u) * 0.55 - d * sin(u * PI) * 1.0)
		var m := streak_mat(Color(1.0, 0.98, 0.92), Color(1.0, 0.55, 0.15), 0.35, 3.0)
		m.set_shader_parameter("reveal", 0.0)
		var x := mi(ribbon(pts, 0.55, d, true), m)
		put(pj, x, Vector3.ZERO)
		tween_param(x, m, "reveal", 0.0, 1.0, 0.1)
		fade_out(x, m, 0.2, 0.25)
		# zemin oluğu
		var g: Vector3 = pj.gp(hit_at + d * (k - 1) * 0.85)
		var gm := cel(Color(0.18, 0.13, 0.1), 0.0, INK, true, 3.0)
		var gb := MB.new()
		gb.add("box", Vector3.ZERO, Vector3(0.32, 0.04, 4.0), Color.WHITE, Vector3.ZERO, 1)
		gb.add("box", Vector3(0.24, 0.05, 0), Vector3(0.12, 0.08, 3.6), Color(1.6, 1.4, 1.2), Vector3.ZERO, 1)
		var gx := mi(gb.build(), gm)
		put(pj, gx, g + Vector3.UP * 0.03)
		gx.look_at(gx.global_position + side + Vector3(0.001, 0, 0), Vector3.UP)
		fade_out(gx, gm, 3.0, 0.8)
	debris(pj, pj.gp(hit_at), Color(0.5, 0.42, 0.34), 20, 9.0, 1.2, 0.3)
	dust(pj, hit_at, 10, 1.3, 0.9)


# ================================================================== 11) Duman Klonu
## Ref: kahverengimsi kabarık cel duman bulutu, koyu kenar çizgisi. Kurgu: çağıranın bedeninden kopan kabarık duman topakları
## yandaki noktaya akıp insan boyu bir duman sütunu kurar, sütun incelirken içinden klon çıkar; klonun omuzlarından ömrü boyunca
## ince duman tütmesi (duman klonu olduğunu belli eder); vurulunca geniş, yavaş sönen duman bulutuna dağılır.
static func kemuri_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var side: Vector3 = pj.fwd(c, t).cross(Vector3.UP).normalized()
	var at: Vector3 = c.global_position + side * 1.6
	var sm := cloud_mat()
	for k in 12:   # bedenden kopan topaklar sütunu kurar
		var p := mi(_sphere(12), sm)
		put(pj, p, c.global_position + Vector3.UP * randf_range(0.4, 1.7) + side * 0.2)
		p.scale = Vector3.ONE * 0.2
		var dst := at + Vector3.UP * (0.25 + (k % 6) * 0.32) + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", dst, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(k * 0.012)
		tw.tween_property(p, "scale", Vector3.ONE * randf_range(0.7, 0.95), 0.18).set_delay(k * 0.012)
		tw.chain().tween_interval(0.12)
		tw.chain().tween_property(p, "scale", Vector3.ONE * 0.02, 0.4).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(p.queue_free)
	var cl = pj._quick_clone(c, at, 15.0)
	if is_instance_valid(cl):
		burst(pj, Vector3(0, 1.4, 0), _sphere(8), cloud_mat(SMOKE_LIT, SMOKE_SH, SMOKE_INK, 3.0, 0.04), 8, 1.2,
			{"emit": true, "r": 0.3, "dir": Vector3.UP, "spread": 30.0, "vmin": 0.4, "vmax": 0.9, "g": Vector3(0, 0.3, 0), "smin": 0.12, "smax": 0.22,
			"start_scale": 0.6, "end_scale": 1.6, "hold": 0.5}, cl)
	var smoke_burst := func(p: Vector3):
		var bm := cloud_mat(SMOKE_LIT, SMOKE_SH, SMOKE_INK, 6.0, 0.1)
		var holder := Node3D.new()
		put(pj, holder, p)
		for k in 14:
			var q := mi(_sphere(12), bm)
			holder.add_child(q)
			var a := randf() * TAU
			var r := randf_range(0.0, 2.2)
			q.position = Vector3.UP * 1.0
			q.scale = Vector3.ONE * 0.3
			var dst := Vector3(cos(a) * r, randf_range(0.4, 2.2), sin(a) * r)
			var sz := randf_range(1.1, 1.9)
			var tw := q.create_tween()
			tw.set_parallel(true)
			tw.tween_property(q, "position", dst, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(q, "scale", Vector3.ONE * sz, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.chain().tween_property(q, "position", dst + Vector3.UP * 0.6, 1.4)
		fade_out(holder, bm, 1.2, 0.8)
	if is_instance_valid(cl):
		cl.tree_exiting.connect(func():
			if is_instance_valid(c):
				var p: Vector3 = cl.global_position
				smoke_burst.call(p)
				for e in pj.enemies_near(c, p, 3.0):
					if not pj.live(e):
						continue
					pj.st(e, "slow", 2.0)
					e.take_hit(pj.inf(c, "kemuri_bunshin", 0.4, {"knock": 0.0, "kind": "light"})))
	Sfx.play("poof", at, 0.8)


# ================================================================== 12) Çoklu Duman Klonu
## Kurgu (tekliden ayrı): çağıran ayağından yere basık bir duman halkası dört yana yuvarlanır; her klon noktasında duman
## burgu gibi dönerek yükselir, sonra perde gibi iki yana açılır ve klon ortaya çıkar.
static func taju_kemuri_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d: Vector3 = pj.fwd(c, t)
	var ring_m := cloud_mat(SMOKE_LIT, SMOKE_SH, SMOKE_INK, 5.0, 0.06)
	var holder := Node3D.new()
	put(pj, holder, c.global_position)
	for k in 14:   # yere basık yuvarlanan halka
		var a := TAU * k / 14.0
		var q := mi(_sphere(10), ring_m)
		holder.add_child(q)
		q.position = Vector3(cos(a), 0.3, sin(a)) * 0.4
		q.scale = Vector3(0.5, 0.35, 0.5)
		var tw := q.create_tween()
		tw.set_parallel(true)
		tw.tween_property(q, "position", Vector3(cos(a) * 2.4, 0.35, sin(a) * 2.4), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(q, "scale", Vector3(1.1, 0.6, 1.1), 0.3)
	fade_out(holder, ring_m, 0.35, 0.4)
	for k in 4:
		var a = (k - 1.5) * 0.7
		var at = c.global_position + d.rotated(Vector3.UP, a + PI * 0.5 * (1 if k % 2 == 0 else -1)) * 2.0
		pj.after(k * 0.08, func():
			if pj.live(c):
				_smoke_spout(pj, at, d)
				pj._quick_clone(c, at, 15.0))
	Sfx.play("poof", c.global_position, 0.7)


## Burgu duman sütunu → iki yana açılan perde
static func _smoke_spout(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	var m := cloud_mat(SMOKE_LIT, SMOKE_SH, SMOKE_INK, 4.0, 0.08)
	var root := Node3D.new()
	put(pj, root, pj.gp(at))
	var side := d.cross(Vector3.UP).normalized()
	for i in 7:
		var q := mi(_sphere(10), m)
		root.add_child(q)
		var a := i * 1.3
		q.position = Vector3(cos(a) * 0.35, 0.1, sin(a) * 0.35)
		q.scale = Vector3.ONE * 0.3
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var tw := q.create_tween()
		tw.set_parallel(true)
		tw.tween_property(q, "position", Vector3(cos(a) * 0.3, 0.3 + i * 0.3, sin(a) * 0.3), 0.15).set_ease(Tween.EASE_OUT)
		tw.tween_property(q, "scale", Vector3.ONE * (0.85 - i * 0.04), 0.15)
		tw.chain().tween_property(q, "position", side * sgn * 1.1 + Vector3.UP * (0.4 + i * 0.3), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(q, "scale", Vector3.ONE * 0.05, 0.3).set_ease(Tween.EASE_IN)
	var rtw := root.create_tween()
	rtw.tween_property(root, "rotation:y", TAU * 0.6, 0.45)
	pj.free_after(0.9, root)


# ================================================================== 13) Mühür Çözme: Shuriken
## Ref (oyun içi): parşömen yüzünden mühür açılır, yelpaze dalgalar halinde shuriken ve kunai fırlar.
## Kurgu: parşömen yüzünde kara mürekkep yazı halkası dönerek genişler + kısa beyaz parıltı → her dalgada parşömenden
## öne beş beyaz hız çizgisi; kendi çelik shuriken (delikli dört kollu, konturlu) ve kunai modelleri.
static func kaifujutsu_shuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 1.2)
	var sc = pj._held(c)
	var fd: Vector3 = c.face_dir()
	fd.y = 0
	fd = fd.normalized()
	var o: Vector3 = (sc.global_position if sc else c.global_position + Vector3.UP * 1.3) + fd * 0.25
	if sc:
		pj.after(1.05, func():
			if is_instance_valid(sc):
				var stw: Tween = sc.create_tween()
				stw.tween_property(sc, "scale", sc.scale * 0.05, 0.2).set_ease(Tween.EASE_IN)
				stw.tween_callback(sc.queue_free))
	var gm := flare_mat(Color(0.08, 0.06, 0.05, 0.95), 5.0, false, false, 1.0)
	gm.set_shader_parameter("spin", 3.0)
	var gq := mi(_quad(), gm)
	put(pj, gq, o + fd * 0.05)
	gq.look_at(gq.global_position + fd, Vector3.UP)
	gq.scale = Vector3.ONE * 0.6
	gq.create_tween().tween_property(gq, "scale", Vector3.ONE * 1.6, 0.35).set_ease(Tween.EASE_OUT)
	fade_out(gq, gm, 0.25, 0.2)
	flash(pj, o, Color(1.0, 0.97, 0.85), 0.8, 1.0, 0.2, true, 1.4, 1.2)
	Sfx.play("poof", o, 1.4, 0.4)
	var side := fd.cross(Vector3.UP).normalized()
	var star := _star_mesh()
	var kunai := _kunai_mesh()
	var smat := cel(Color.WHITE, 0.01, STEEL_INK, true, 1.0)
	for wave in 4:   # dört dalga, her dalga yelpaze (sol→sağ) 9 shuriken + 3 kunai
		pj.after(0.06 + wave * 0.2, func():
			if pj.live(c):
				for q in 5:
					var f2 := (q / 4.0) - 0.5
					var dv := (fd + side * f2 * 0.7).normalized()
					var pts := [o + dv * 0.3, o + dv * 1.6, o + dv * 3.0]
					var lm := streak_mat(Color(1, 1, 1, 0.85), Color(0.8, 0.82, 0.9, 0.85), 0.6, 1.5)
					var ln := mi(ribbon(pts, 0.05, Vector3.UP, true), lm)
					put(pj, ln, Vector3.ZERO)
					fade_out(ln, lm, 0.0, 0.15))
		for k in 12:
			pj.after(0.06 + wave * 0.2 + k * 0.012, func():
				if not pj.live(c):
					return
				var f = (k / 11.0) - 0.5
				var aim: Vector3 = pj.aim_at(c, tt, o)
				var dir = (aim + side * f * 0.7 + Vector3.UP * randf_range(-0.05, 0.12)).normalized()
				var from = o + side * f * 0.4
				var is_kunai = k % 4 == 3
				var body: MeshInstance3D = mi(kunai, smat) if is_kunai else mi(star, smat)
				if not is_kunai:
					body.scale = Vector3.ONE * 0.85
				var pr = pj.shot(c, from, dir, 38.0, body, pj.inf(c, "kaifujutsu_shuriken", 0.12, {"knock": 1.0, "kind": "light", "bleed": 1.0}), tt if wave % 2 == 0 else null, false, 0.9)
				if pr and not is_kunai:
					pr.spin = Vector3(0, 32.0, 0))
	Sfx.play("throw_kunai", c.global_position, 1.3)


## Çelik shuriken: dört sivri kol, ortada delik (XZ düzleminde yassı)
static func _star_mesh() -> Mesh:
	return _cached("steel_star", func():
		var o := _star2d(4, 0.5, 0.12, PI * 0.25)
		o = MB.hole(o, Vector2.ZERO, 0.045, 10)
		var b := MB.new()
		b.add_slab(o, 0.025, STEEL, _flat_xf())
		b.add("cyl", Vector3.ZERO, Vector3(0.16, 0.03, 0.16), Color(0.45, 0.46, 0.52), Vector3.ZERO, 10)
		return b.build())


## Kunai: elmas bıçak (-Z uç), sargılı sap, halka
static func _kunai_mesh() -> Mesh:
	return _cached("kunai", func():
		var b := MB.new()
		b.add_slab(PackedVector2Array([Vector2(0, 0.32), Vector2(0.06, 0.08), Vector2(0.025, 0.0), Vector2(-0.025, 0.0), Vector2(-0.06, 0.08)]), 0.02, STEEL, _blade_xf(Vector3(0, 0, -0.02)))
		b.add("cyl", Vector3(0, 0, 0.08), Vector3(0.028, 0.16, 0.028), Color(0.18, 0.15, 0.13), Vector3(90, 0, 0), 6)
		b.add("cyl", Vector3(0, 0, 0.19), Vector3(0.07, 0.015, 0.07), Color(0.5, 0.5, 0.55), Vector3(0, 0, 90), 10)
		return b.build())


# ================================================================== 14) Hayalet Çoklu Shuriken
## Kurgu: elden tek gerçek çelik shuriken dönerek havaya fırlar → tepe noktasında dışa açılan hayalet shuriken halkası
## (bölünme anı) → on altı yarı saydam soluk mavi hayalet shuriken hedefin çevresine yağar, arkalarında sönen ardıl görüntüler.
static func genei_taju_shuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.8)
	var o: Vector3 = pj.hand_pos(c)
	var dest: Vector3 = (tt.global_position + Vector3.UP if is_instance_valid(tt) else o + pj.fwd(c, t) * 18.0)
	var mid: Vector3 = o.lerp(dest, 0.4) + Vector3.UP * 3.0
	var star := _star_mesh()
	var real := mi(star, cel(Color.WHITE, 0.012, STEEL_INK, true, 1.0))
	put(pj, real, o)
	real.scale = Vector3.ONE * 1.1
	var rtw := real.create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(real, "global_position", mid, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.tween_property(real, "rotation:y", TAU * 4.0, 0.3)
	rtw.chain().tween_callback(real.queue_free)
	var gmat := cel(Color(0.78, 0.86, 1.0, 0.55), 0.015, Color(0.3, 0.45, 0.85, 0.8), true, 1.0)
	pj.after(0.3, func():
		# bölünme: dışa açılan hayalet halka
		for q in 8:
			var a := TAU * q / 8.0
			var gh := mi(star, gmat)
			put(pj, gh, mid)
			gh.scale = Vector3.ONE * 0.9
			var gtw := gh.create_tween()
			gtw.set_parallel(true)
			gtw.tween_property(gh, "global_position", mid + Vector3(cos(a), sin(a) * 0.4, sin(a)) * 1.8, 0.25).set_ease(Tween.EASE_OUT)
			gtw.tween_property(gh, "scale", Vector3.ONE * 0.05, 0.25).set_ease(Tween.EASE_IN)
			gtw.chain().tween_callback(gh.queue_free)
		flash(pj, mid, Color(0.8, 0.88, 1.0), 1.3, 3.0, 0.25, true, 1.8, 2.0))
	for k in 16:
		pj.after(0.3 + k * 0.02, func():
			if not pj.live(c):
				return
			var body := mi(star, gmat)
			var target = dest + Vector3(randf_range(-2.0, 2.0), randf_range(-0.6, 0.6), randf_range(-2.0, 2.0))
			var pr = pj.shot(c, mid, (target - mid).normalized(), 30.0, body, pj.inf(c, "genei_taju_shuriken", 0.2, {"knock": 1.0, "kind": "light", "bleed": 1.0}), null, false, 0.8)
			if pr:
				pr.spin = Vector3(0, 30.0, 0)
				var acc := {"t": 0.0}
				pr.on_tick = func(p, dt):
					acc["t"] += dt
					if acc["t"] >= 0.05:
						acc["t"] = 0.0
						var ghost := mi(star, gmat)
						put(pj, ghost, p.global_position)
						ghost.rotation = p.rotation
						var tw := ghost.create_tween()
						tw.tween_property(ghost, "scale", Vector3.ONE * 0.1, 0.18).set_ease(Tween.EASE_IN)
						tw.tween_callback(ghost.queue_free))
	Sfx.play("throw_kunai", c.global_position, 1.2)


# ================================================================== 15) Asalak İblis Yıkım Tekniği
## Ref: hedefin omzunda Ukon'un kırmızı, boynuzlu, uzun beyaz saçlı, sivri dişli yüzü. Kurgu: kullanıcı kırmızımsı hücre
## taneciklerine ayrılıp kıvrılan bir akışla hedefe girer → omuzda yüz belirir → her vuruşta hedefin içinden kırmızı hücre
## kırıntıları patlar → süre sonunda hücreler kullanıcının yerine geri toplanıp bedeni kurar.
static func kisei_kikai_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 0.6)
	if tt == null:
		if c is Player:
			Hud.msg("Bitişikteki hedef yok (dokunarak girer).", Color(0.8, 0.8, 0.8))
		return
	var cm := cel(FLESH, 0.01, Color(0.35, 0.1, 0.1), false, 1.0)
	var a0: Vector3 = c.global_position + Vector3.UP
	var b0: Vector3 = tt.global_position + Vector3.UP * 1.5
	for k in 22:   # hücre akışı
		var cell := mi(_sphere(8), cm)
		var p0 := a0 + Vector3(randf_range(-0.35, 0.35), randf_range(-0.7, 0.7), randf_range(-0.35, 0.35))
		put(pj, cell, p0)
		cell.scale = Vector3(0.14, 0.1, 0.12) * randf_range(0.8, 1.4)
		var mid := p0.lerp(b0, 0.5) + Vector3.UP * randf_range(0.5, 1.5) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		var tw := cell.create_tween()
		tw.tween_interval(k * 0.012)
		tw.tween_method(func(u: float):
			if is_instance_valid(cell) and is_instance_valid(tt):
				var bb: Vector3 = tt.global_position + Vector3.UP * 1.5
				cell.global_position = p0.lerp(mid, u).lerp(mid.lerp(bb, u), u), 0.0, 1.0, 0.35)
		tw.tween_callback(cell.queue_free)
	Sfx.play("th_flesh", tt.global_position, 0.8)
	if c.get("model"):
		c.model.visible = false
		pj.after(5.2, func():
			if pj.live(c) and c.get("model"):
				c.model.visible = true
				burst(pj, c.global_position + Vector3.UP, _sphere(8), cel(FLESH, 0.01, Color(0.35, 0.1, 0.1)), 30, 0.35, {"expl": 0.6, "r": 1.4,
					"vmin": 0.0, "vmax": 0.2, "g": Vector3.ZERO, "radial": -16.0, "smin": 0.08, "smax": 0.14, "end_scale": 0.4}))
	if c is Player and c.get("combat"):
		c.combat.invuln = 5.0
	var ba = pj.bone_attach(tt, "LeftShoulder")
	if ba:
		var face := mi(_ukon_face(), cel(Color.WHITE, 0.012, Color(0.25, 0.06, 0.06), false, 0.8))
		ba.add_child(face)
		face.scale = Vector3.ONE * 0.05
		face.create_tween().tween_property(face, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		pj.free_after(5.0, ba)
	pj.st(tt, "slow", 5.0)
	var cb := cel(Color(0.85, 0.2, 0.18), 0.008, Color(0.3, 0.05, 0.05))
	pj.every(5.0, 0.5, func(_i, _k):
		if pj.live(tt):
			burst(pj, tt.global_position + Vector3.UP * 1.1, _sphere(6), cb, 8, 0.45, {"r": 0.35, "vmin": 1.5, "vmax": 3.5, "g": Vector3(0, -8, 0),
				"smin": 0.05, "smax": 0.1})
			tt.take_hit(pj.inf(c, "kisei_kikai_no_jutsu", 0.16, {"knock": 0.0, "kind": "light", "pierce_guard": true}))
			if randf() < 0.4:
				Combat.popup_text(tt.global_position + Vector3.UP * 2.3, "Hücreler yıkılıyor!", Color(0.85, 0.35, 0.35)), Callable())


## Ukon'un yüzü (ref): kırmızı uzun yüz, alından boynuz, sarı göz, sivri diş sırası ve iki aşağı bakan köpek dişi, uzun beyaz saç
static func _ukon_face() -> Mesh:
	return _cached("ukon_face", func():
		var b := MB.new()
		var red := Color(0.78, 0.36, 0.3)
		b.add("sphere", Vector3(0, 0.14, -0.04), Vector3(0.26, 0.38, 0.26), red, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0, 0.02, -0.12), Vector3(0.18, 0.16, 0.14), red, Vector3.ZERO, 10)   # çene
		b.add("cone", Vector3(0.02, 0.4, -0.06), Vector3(0.07, 0.24, 0.07), red, Vector3(-25, 0, -8), 6)   # boynuz
		b.add("box", Vector3(0, 0.06, -0.19), Vector3(0.15, 0.035, 0.02), Color(0.98, 0.98, 0.94), Vector3.ZERO, 1)   # diş sırası
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.06, 0.02, -0.19), Vector3(0.025, 0.07, 0.02), Color(0.98, 0.98, 0.94), Vector3(180, 0, 0), 4)   # köpek dişi
		b.add("sphere", Vector3(0.06, 0.2, -0.15), Vector3(0.055, 0.035, 0.03), Color(1.0, 0.82, 0.2), Vector3.ZERO, 8)   # göz
		b.add("sphere", Vector3(0.065, 0.2, -0.165), Vector3(0.02, 0.025, 0.01), Color(0.05, 0.03, 0.02), Vector3.ZERO, 6)
		for k in 8:   # uzun beyaz saç
			var x := lerpf(-0.13, 0.13, k / 7.0)
			b.add("box", Vector3(x, 0.02 - absf(x) * 0.5, 0.06 + absf(x) * 0.3), Vector3(0.05, 0.6, 0.03), Color(0.9, 0.9, 0.97), Vector3(12, 0, x * 60.0), 1)
		return b.build())


# ================================================================== 16) Kukla: Baba ve Anne
## Ref: iki kukladan çıkan pembe-beyaz, kıvrılan, halkalar çizen jilet teller. Kurgu: zeminde mühür halkası açılır, yukarı
## kâğıt şeritleri fırlar, gerçek kuklalar (ClanConstruct) belirir → parmaklardan kuklalara kendi mavi chakra iplerim →
## her dalgada kuklaların elinden hedefe kıvrımlı, ilmekli pembe jilet teller savrulur, açılır, söner; kesikte pembe kıvılcım.
static func kugutsu_chichi_to_haha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "cast", 1.1)
	var tt = pj.tg(c, t, 22.0)
	var up: Vector3 = c.global_position + c.face_dir() * 1.5
	ground_sigil(pj, up, Color(0.1, 0.08, 0.12, 0.95), 2.8, 5.0, 0.6, 0.3, false, 1.0)
	burst(pj, up + Vector3.UP * 0.3, _box(), cel(PAPER, 0.006, PAPER_INK, true, 1.0), 12, 0.7, {"r": 0.5, "dir": Vector3.UP, "spread": 25.0, "vmin": 3.0, "vmax": 6.0,
		"g": Vector3(0, -5, 0), "smin": 0.08, "smax": 0.14, "align": true})
	var list = ClanConstruct.spawn(c, "puppet", 2, Jutsu._jd("kugutsu_chichi_to_haha"))
	_puppet_strings(pj, c, list if list is Array else [], 14.0)
	Sfx.play("th_puppet", c.global_position, 0.9)
	var at: Vector3 = tt.global_position if tt else c.global_position + c.face_dir() * 8.0
	var hits = []
	for w in 6:
		pj.after(0.45 + w * 0.16, func():
			if not pj.live(c):
				return
			var a = list[w % maxi(1, list.size())] if list is Array and not list.is_empty() and is_instance_valid(list[w % list.size()]) else c
			var from: Vector3 = a.global_position + Vector3.UP * 1.3
			var sd := (at - from).normalized().cross(Vector3.UP).normalized()
			for q in 3:
				var off := sd * randf_range(-2.5, 2.5) + Vector3.UP * randf_range(-0.6, 1.2)
				var to := at + Vector3.UP * 1.0 + off
				_razor_wire(pj, from, to)
			hits.clear()
			for h in pj.hit(c, at + Vector3.UP, 2.6, pj.inf(c, "kugutsu_chichi_to_haha", 0.12, {"knock": 1.0, "kind": "light", "bleed": 2.0, "hitstop": 0.02}), hits):
				hits.append(h)
				if is_instance_valid(h):
					flash(pj, h.global_position + Vector3.UP * 1.1, RAZOR, 0.7, 1.0, 0.15)
			Sfx.play("slash", at, randf_range(1.0, 1.2), 0.5))


## Kendi chakra iplerim: her birime iki elden ince mavi ip
static func _puppet_strings(pj: PathJutsu, c: Node3D, units: Array, dur: float) -> void:
	for u in units:
		for k in 2:
			var side := k == 0
			thread(pj, func(): return pj.hand_pos(c, side) if is_instance_valid(c) else Vector3.ZERO,
				func(): return (u.global_position + Vector3.UP * 1.4) if is_instance_valid(u) else Vector3.ZERO, 0.018, CSTRING, dur)


## Jilet tel: kıvrımlı ve ilmekli pembe-beyaz şerit, hızla açılır ve söner
static func _razor_wire(pj: PathJutsu, from: Vector3, to: Vector3) -> void:
	var pts := []
	var dv := to - from
	var up := dv.cross(Vector3.UP).normalized().cross(dv.normalized())
	var sd := dv.normalized().cross(up).normalized()
	var loop_at := randf_range(0.45, 0.8)
	var lr := randf_range(0.35, 0.8)
	var ph := randf() * TAU
	for i in 40:
		var u := i / 39.0
		var p := from.lerp(to, u) + up * sin(u * PI) * randf_range(0.0, 0.05) + sd * sin(u * PI * 2.0 + ph) * 0.6
		var lk := clampf(1.0 - absf(u - loop_at) / 0.12, 0.0, 1.0)
		if lk > 0.0:
			var la := (u - loop_at + 0.12) / 0.24 * TAU
			p += (up * (1.0 - cos(la)) + sd * sin(la)) * lr * lk
		pts.append(p)
	var m := streak_mat(Color(1.0, 0.95, 0.98, 0.95), RAZOR, 0.15, 1.5)
	m.set_shader_parameter("reveal", 0.0)
	var x := mi(ribbon(pts, 0.05, Vector3.ZERO, false), m)
	put(pj, x, Vector3.ZERO)
	tween_param(x, m, "reveal", 0.0, 1.0, 0.08)
	fade_out(x, m, 0.12, 0.2)


# ================================================================== 17) Kukla: Bahar Cezası Darbesi
## Ref: chakralı yumruk kuklayı kahverengi parçalara ayırır, zemin çatlar, taş kırıntıları uçar.
## Kurgu: kendi mavi chakra iplerimle müttefik havaya savrulur, yumruğunda mavi chakra ışığı → inişte mavi-beyaz yıldız
## parıltısı, derin çatlaklar, uçan kaya ve kahverengi parça kırıntıları, yuvarlanan toz halkası.
static func kugutsu_haruchugeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 1.0)
	pj.anim(c, "cast", 1.1)
	if tt == null:
		if c is Player:
			Hud.msg("Hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var actor = pj._ally_for(c)
	if actor != c:
		_puppet_strings(pj, c, [actor], 1.6)
	var fist = pj.bone_attach(actor, "RightHand")
	if fist:
		var fm := glow(Color(0.55, 0.8, 1.0, 0.85), 0.8, 0.6)
		var fg := mi(_sphere(12), fm)
		fist.add_child(fg)
		fg.scale = Vector3.ONE * 0.32
		burst(pj, Vector3.ZERO, _sphere(6), glow(Color(0.6, 0.85, 1.0), 0.8, 0.5), 10, 0.4, {"emit": true, "r": 0.12, "dir": Vector3.UP, "spread": 60.0,
			"vmin": 0.3, "vmax": 1.0, "g": Vector3.ZERO, "smin": 0.04, "smax": 0.08}, fist)
		pj.free_after(1.0, fist)
	Sfx.play("th_puppet", c.global_position, 1.0)
	var a0: Vector3 = actor.global_position
	var land: Vector3 = pj.gp(tt.global_position)
	if actor is CharacterBody3D:
		actor.velocity = Vector3.ZERO
	if actor.get("model"):
		actor.model.play("jump", 0.05, 1.0, true)
	var tw = actor.create_tween()
	tw.tween_method(func(u: float):
		if pj.live(actor):
			actor.global_position = a0.lerp(land - (land - a0).normalized() * 0.8, u) + Vector3.UP * sin(u * PI) * 9.0, 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if not pj.live(c):
			return
		if actor.get("model"):
			actor.model.play("cross", 0.05, 1.4, true)
		cracks(pj, land, 3.5, 8, Color(0.2, 0.16, 0.13), 6.0)
		debris(pj, land, Color(0.5, 0.42, 0.34), 16, 8.0, 1.1, 0.3)
		debris(pj, land, Color(0.55, 0.32, 0.18), 8, 6.0, 1.0, 0.45)   # kahverengi kukla / tahta parçaları
		dust(pj, land, 14, 1.2, 1.0)
		flash(pj, land + Vector3.UP, Color(0.6, 0.85, 1.0), 2.0, 1.0, 0.22, true, 1.4, 2.5)
		ground_ring(pj, land, Color(0.7, 0.88, 1.0), 3.5, 0.4)
		for h in pj.hit(c, land + Vector3.UP, 2.4, pj.inf(c, "kugutsu_haruchugeki", 1.4, {"knock": 14.0, "launch": 5.0, "kind": "heavy", "armor_break": true, "pierce_guard": true, "hitstop": 0.12})):
			if h.has_method("apply_status"):
				h.apply_status("armor_break", 4.0)
		Sfx.play("hit_heavy", land, 0.75)
		pj.shake(0.8))


# ================================================================== 18) Kukla Gösterisi: İnsan Bedeniyle Ustalık
## Ref: kuklacının parmaklarından baş, gövde, iki kol, iki bacağa uzanan ince mavi chakra ipleri.
## Kurgu: altı ip; bağlandığı noktalarda küçük mavi düğüm ışıkları; bağlanırken her ipten elden bedene parlak bir boncuk koşar.
static func soen_hitomi_goku(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.0)
	var actor = pj._ally_for(c)
	var dur = 18.0
	var pts = [Vector3(0, 1.75, 0), Vector3(0, 1.25, 0), Vector3(0.45, 1.3, 0), Vector3(-0.45, 1.3, 0), Vector3(0.18, 0.4, 0), Vector3(-0.18, 0.4, 0)]
	var km := glow(Color(0.6, 0.85, 1.0, 0.9), 0.6, 0.4)
	for k in pts.size():
		var off: Vector3 = pts[k]
		var side = k % 2 == 0
		var a_fn := func(): return pj.hand_pos(c, side) if pj.live(c) else Vector3.ZERO
		var b_fn := func(): return (actor.global_position + off) if pj.live(actor) else (pj.hand_pos(c, side) if pj.live(c) else Vector3.ZERO)
		thread(pj, a_fn, b_fn, 0.012, CSTRING, dur)
		var knot := mi(_sphere(8), km)
		actor.add_child(knot)
		knot.position = off
		knot.scale = Vector3.ONE * 0.09
		pj.free_after(dur, knot)
		var bead := mi(_sphere(8), glow(Color(0.85, 0.95, 1.0), 0.6, 0.3))
		put(pj, bead, a_fn.call())
		bead.scale = Vector3.ONE * 0.12
		var btw := bead.create_tween()
		btw.tween_interval(k * 0.04)
		btw.tween_method(func(u: float):
			if is_instance_valid(bead):
				var a: Vector3 = a_fn.call()
				var b: Vector3 = b_fn.call()
				bead.global_position = a.lerp(b, u), 0.0, 1.0, 0.3)
		btw.tween_callback(bead.queue_free)
	var mods = {"speed": 1.2, "melee": 1.25, "armor": 0.85}
	if actor is Player:
		Buffs.add("soen_hitomi_goku", dur, mods)
	elif actor.has_method("add_buff"):
		actor.add_buff("soen_hitomi_goku", dur, mods)
	Combat.popup_text(actor.global_position + Vector3.UP * 2.4, "Kukla gösterisi!", CSTRING.lightened(0.3))
	Sfx.play("th_puppet", actor.global_position, 1.1)


# ================================================================== 19) Paraşüt
## Ref: klonlar havadaki rakibi bastırırken asıl beden dizle iner; kenarlarda ışınsal hız çizgileri.
## Kurgu: yukarı savuran yumrukta dikey hız çizgileri + tırtıklı parıltı → havada üç klon belirirken onlara doğru ışınsal
## hız çizgileri → dalışta yere doğru yoğun hız çizgileri; çarpmada zeminde ışınsal çizgi yıldızı, çatlak, toz.
static func rakkasan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 5.0)
	pj.busy(c, 1.3)
	if tt == null:
		return
	pj.anim(c, "hook", 1.4)
	tt.take_hit(pj.inf(c, "rakkasan", 0.4, {"knock": 0.0, "launch": 14.0, "kind": "heavy"}))
	flash(pj, tt.global_position + Vector3.UP, Color(1, 0.85, 0.5), 1.4, 2.0, 0.2, true, 1.3, 2.0)
	_speed_lines(pj, tt.global_position + Vector3.UP * 0.5, Vector3.UP, 8, 1.2, 4.0, Color(1, 1, 1, 0.9))
	Sfx.play("punch", tt.global_position, 0.9)
	pj.after(0.35, func():
		if not pj.live(tt):
			return
		var top: Vector3 = tt.global_position + Vector3.UP * 0.8
		for k in 3:
			var a = k * TAU / 3.0
			var q = top + Vector3(cos(a), 0.2, sin(a)) * 0.9
			_converge_lines(pj, q + Vector3.UP, 1.6)
			flash(pj, q + Vector3.UP, Color(1, 0.9, 0.6), 0.7, 1.0, 0.15)
			pj.decoy(c, pj.gp(q), 0.9)
		Combat.popup_text(top + Vector3.UP, "Rakkasan!", Color(1, 0.6, 0.2)))
	pj.after(0.7, func():
		if not pj.live(c) or not pj.live(tt):
			return
		c.global_position = tt.global_position + Vector3.UP * 1.6
		pj._kick_pose(c, 0.4)
		_speed_lines(pj, c.global_position + Vector3.UP * 2.5, Vector3.DOWN, 10, 1.0, 5.0, Color(1, 1, 1, 0.85))
		tt.take_hit(pj.inf(c, "rakkasan", 1.1, {"knock": 2.0, "launch": -20.0, "kind": "heavy"}))
		pj.after(0.3, func():
			if pj.live(tt):
				var g: Vector3 = pj.gp(tt.global_position)
				_ground_burst_lines(pj, g, 4.5)
				cracks(pj, g, 2.4, 7, Color(0.2, 0.16, 0.13), 3.0)
				dust(pj, g, 10, 1.0, 0.8)
				flash(pj, g + Vector3.UP * 0.4, Color(1.0, 0.9, 0.6), 1.6, 2.0, 0.2, true, 1.3, 2.0)
				Sfx.play("hit_heavy", tt.global_position, 0.8)))


## Hız çizgileri: dir yönünde akan ince beyaz şeritler (merkez çevresinde)
static func _speed_lines(pj: PathJutsu, at: Vector3, dir: Vector3, n: int, r: float, L: float, col: Color) -> void:
	var sd := dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.FORWARD).normalized()
	for k in n:
		var a := TAU * k / n + randf_range(-0.2, 0.2)
		var off := sd.rotated(dir, a) * r * randf_range(0.6, 1.1)
		var p0 := at + off - dir * L * 0.5
		var pts := [p0, p0 + dir * L * 0.5, p0 + dir * L]
		var m := streak_mat(col, col, 0.8, 2.0)
		var x := mi(ribbon(pts, 0.05, Vector3.ZERO, true), m)
		put(pj, x, Vector3.ZERO)
		var tw := x.create_tween()
		tw.tween_property(x, "position", dir * L * 0.6, 0.22)
		fade_out(x, m, 0.08, 0.15)


## Klon belirirken çevreden noktaya yakınsayan kısa çizgiler
static func _converge_lines(pj: PathJutsu, at: Vector3, r: float) -> void:
	for k in 8:
		var dv := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)).normalized()
		var pts := [at + dv * r * 1.6, at + dv * r * 1.1, at + dv * r * 0.5]
		var m := streak_mat(Color(1, 1, 1, 0.85), Color(1, 0.85, 0.5, 0.85), 0.5, 1.5)
		m.set_shader_parameter("reveal", 0.0)
		var x := mi(ribbon(pts, 0.04, Vector3.ZERO, true), m)
		put(pj, x, Vector3.ZERO)
		tween_param(x, m, "reveal", 0.0, 1.0, 0.1)
		fade_out(x, m, 0.12, 0.12)


## Zeminde ışınsal çizgi yıldızı (çarpma anı)
static func _ground_burst_lines(pj: PathJutsu, g: Vector3, r: float) -> void:
	for k in 14:
		var a := TAU * k / 14.0 + randf_range(-0.1, 0.1)
		var dv := Vector3(cos(a), 0, sin(a))
		var pts := []
		for i in 4:
			var p := g + dv * (0.5 + i * r * randf_range(0.22, 0.3))
			p.y = pj.gp(p).y + 0.06
			pts.append(p)
		var tr := ground_trace(pj, pts, 0.1, Color(1, 0.98, 0.9, 0.9), Color(1.0, 0.8, 0.45, 0.9), 0.08, 0.1, 0.2)
		(tr.material_override as ShaderMaterial).set_shader_parameter("tail", 0.0)


# ================================================================== 20) Alev Elleri
## Ref: cinchūriki dönüşümünün somon renkli, içi koyu kırmızı damarlı, kenarı koyu kırmızı alev kolları, pençeli eller.
## Kurgu: iki alev kolu omuzlardan kıvrılarak hedefe uzanır (kaynayan boğum zinciri + pençeli el) → eller hedefi iki
## yandan kavrar, kaldırır, yere çarpar → çatlak, parça, kızıl kor kıvılcımları.
static func hono_no_te(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 1.1)
	pj.anim(c, "push", 1.1)
	var d: Vector3 = pj.fwd(c, tt)
	var sd := d.cross(Vector3.UP).normalized()
	var goal: Vector3 = (tt.global_position + Vector3.UP * 1.0) if tt else c.global_position + Vector3.UP * 1.2 + d * 10.0
	var grab := {"on": false}
	for k in 2:
		var sx := 1.0 if k == 0 else -1.0
		var m := flame_mat(5.0)
		var hand := mi(_flame_hand_mesh(), m)
		var start: Vector3 = c.global_position + Vector3.UP * 1.4 + sd * sx * 0.8
		put(pj, hand, start)
		hand.scale = Vector3.ONE * 1.5
		burst(pj, Vector3.ZERO, _sphere(6), glow(Color(1.0, 0.5, 0.42, 0.9), 2.0, 0.4), 14, 0.6, {"emit": true, "r": 0.5, "dir": Vector3.UP, "spread": 50.0,
			"vmin": 0.5, "vmax": 1.6, "g": Vector3(0, 1.0, 0), "smin": 0.05, "smax": 0.12}, hand)
		var blobs := []
		for b in 7:
			var bm := mi(_sphere(12), m)
			put(pj, bm, start)
			blobs.append(bm)
		var mid: Vector3 = start.lerp(goal, 0.5) + Vector3.UP * 2.2 + sd * sx * 1.6
		var st := {"p": start}
		var tw := hand.create_tween()
		tw.tween_method(func(u: float):
			st["p"] = start.lerp(mid, u).lerp(mid.lerp(goal, u), u), 0.0, 1.0, 0.35)
		var upd := func(_i, _k):
			if not is_instance_valid(hand):
				return
			var p: Vector3 = st["p"]
			var look_d: Vector3 = d
			if grab["on"] and pj.live(tt):
				p = tt.global_position + Vector3.UP * 1.0 + sd * sx * 0.8
				look_d = -sd * sx + Vector3.UP * 0.2
			elif p.distance_to(start) > 0.1:
				look_d = (p - start).normalized()
			var root: Vector3 = (c.global_position + Vector3.UP * 1.4 + sd * sx * 0.5) if is_instance_valid(c) else start
			hand.global_position = p
			hand.look_at(p + look_d, Vector3.UP if absf(look_d.normalized().y) < 0.95 else Vector3.RIGHT)
			var tm := Game.now()
			for b in blobs.size():
				var u := (b + 1.0) / (blobs.size() + 1.0)
				var q: Vector3 = root.lerp(p, u) + Vector3.UP * sin(u * PI) * 1.2 + sd * sx * sin(u * PI) * 0.6
				var bn = blobs[b]
				if is_instance_valid(bn):
					bn.global_position = q
					bn.scale = Vector3.ONE * lerpf(0.7, 1.15, u) * (1.0 + 0.12 * sin(tm * 14.0 + b * 1.3))
		var done := func():
			if is_instance_valid(hand):
				fade_out(hand, m, 0.0, 0.3)
			for bn in blobs:
				pj.free_after(0.32, bn)
		pj.every(1.15, 1.0 / 30.0, upd, done)
	Sfx.play("fire", c.global_position, 0.8)
	pj.after(0.4, func():
		if not pj.live(c) or tt == null or not pj.live(tt):
			return
		grab["on"] = true
		flash(pj, tt.global_position + Vector3.UP, Color(1.0, 0.5, 0.42), 2.2, 2.0, 0.22, true, 1.3, 3.0)
		pj.st(tt, "bind", 0.8)
		var a0: Vector3 = tt.global_position
		var tw = tt.create_tween()
		tw.tween_property(tt, "global_position", a0 + Vector3.UP * 3.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tt, "global_position", pj.gp(a0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if pj.live(tt):
				tt.take_hit(pj.inf(c, "hono_no_te", 1.6, {"knock": 6.0, "launch": 2.0, "kind": "heavy", "burn": 4.0, "element": "katon", "hitstop": 0.1}))
				var g: Vector3 = pj.gp(a0)
				cracks(pj, g, 3.0, 8, Color(0.25, 0.06, 0.05), 5.0)
				debris(pj, g, Color(0.45, 0.38, 0.3), 12, 6.0, 1.0, 0.3)
				burst(pj, g + Vector3.UP * 0.3, _sphere(6), glow(Color(1.0, 0.45, 0.35), 2.0, 0.4), 22, 0.8, {"r": 0.8, "dir": Vector3.UP, "spread": 70.0,
					"vmin": 3.0, "vmax": 7.0, "g": Vector3(0, -6, 0), "smin": 0.06, "smax": 0.14})
				ground_ring(pj, g, Color(1.0, 0.45, 0.4), 3.0, 0.4)
				pj.shake(0.7)
				Sfx.play("hit_heavy", a0, 0.75)))


## Alev eli: avuç + dört pençeli parmak + başparmak (uç -Z)
static func _flame_hand_mesh() -> Mesh:
	return _cached("flame_hand", func():
		var b := MB.new()
		b.add("sphere", Vector3(0, 0, 0), Vector3(0.75, 0.42, 0.85), Color.WHITE, Vector3.ZERO, 12)
		for k in 4:
			var x := lerpf(-0.28, 0.28, k / 3.0)
			b.add("sphere", Vector3(x, 0.02, -0.55), Vector3(0.16, 0.16, 0.42), Color.WHITE, Vector3(-10, 0, 0), 8)
			b.add("cone", Vector3(x, -0.05, -0.88), Vector3(0.12, 0.34, 0.12), Color.WHITE, Vector3(-110, 0, 0), 6)
		b.add("sphere", Vector3(0.42, -0.02, -0.15), Vector3(0.16, 0.16, 0.38), Color.WHITE, Vector3(0, 40, 0), 8)
		b.add("cone", Vector3(0.6, -0.06, -0.38), Vector3(0.11, 0.3, 0.11), Color.WHITE, Vector3(-100, 40, 0), 6)
		b.add("sphere", Vector3(0, 0, 0.45), Vector3(0.5, 0.4, 0.6), Color.WHITE, Vector3.ZERO, 10)   # bilek
		return b.build())


# ================================================================== 21) Asalak Klon
## Ref: beyaz Zetsu bedenleri su / zeminden halka dalgaları içinde yükselir. Kurgu: her doğuş noktasında genişleyen soluk
## dalga halkaları + yukarı sıçrayan beyaz sıvı damlaları; klon yerden yükselir → biri hedefe yapışır: sırtında sırıtan,
## yeşil saç tutamlı beyaz kütle; her saniye hedeften kütleye mavi chakra tanecikleri emilir.
static func kisei_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "seal", 1.0)
	var tt = pj.tg(c, t, 20.0)
	var white = Color(0.92, 0.92, 0.88)
	var goo := cel(ZETSU, 0.01, Color(0.45, 0.45, 0.42), false, 1.0)
	for k in 3:
		var a = TAU * k / 3.0 + 0.5
		var q = pj.gp(c.global_position + Vector3(cos(a), 0, sin(a)) * 2.8)
		var d = ShadowClone.new()
		d.team = c.team
		var lk: Dictionary = c.model.look.duplicate() if c.get("model") else {}
		lk["skin"] = white
		lk["top"] = white
		lk["pants"] = white.darkened(0.15)
		lk["hair"] = Color(0.45, 0.6, 0.35)
		d.look = lk
		d.life = 20.0
		pj.get_tree().current_scene.add_child(d)
		d.global_position = q
		for e in pj.enemies_near(c, q, 30.0):
			if e is Enemy and randf() < 0.4:
				e.target = d
		if d:
			d.set_meta("hp_clone", true)
			d.global_position = q - Vector3.UP * 1.6
			var tw = d.create_tween()
			tw.tween_property(d, "global_position", q, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			for r in 3:
				var qq: Vector3 = q
				pj.after(r * 0.18, func():
					ground_ring(pj, qq, Color(0.85, 0.9, 0.88, 0.85), 1.4 + r * 0.5, 0.7, false))
			burst(pj, q + Vector3.UP * 0.1, _sphere(8), goo, 12, 0.8, {"r": 0.5, "dir": Vector3.UP, "spread": 35.0, "vmin": 2.0, "vmax": 4.5,
				"g": Vector3(0, -12, 0), "smin": 0.08, "smax": 0.18, "hold": 0.85})
	Sfx.play("th_flesh", c.global_position, 1.1, 0.6)
	if tt and pj.live(tt):
		pj.after(0.7, func():
			if not pj.live(tt):
				return
			var ba = pj.bone_attach(tt, "Chest")
			if ba:
				var blob := mi(_zetsu_blob(), cel(Color.WHITE, 0.014, Color(0.3, 0.32, 0.28), false, 0.8))
				ba.add_child(blob)
				blob.scale = Vector3.ONE * 0.1
				blob.create_tween().tween_property(blob, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
				pj.free_after(8.0, ba)
			Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Asalak yapıştı!", Color(0.9, 0.9, 0.85))
			var dm := glow(Color(0.5, 0.78, 1.0, 0.9), 1.0, 0.4)
			pj.every(8.0, 1.0, func(_i, _k):
				if pj.live(tt):
					if "chakra" in tt:
						tt.chakra = maxf(0.0, float(tt.chakra) - 6.0)
					burst(pj, tt.global_position + Vector3.UP * 1.2, _sphere(6), dm, 10, 0.45, {"expl": 0.5, "r": 0.9, "vmin": 0.0, "vmax": 0.2,
						"g": Vector3.ZERO, "radial": -10.0, "smin": 0.05, "smax": 0.09, "end_scale": 0.3})
					pj.st(tt, "slow", 1.1)
					tt.take_hit(pj.inf(c, "kisei_bunshin", 0.06, {"knock": 0.0, "kind": "light", "pierce_guard": true})), Callable()))


## Sırta yapışan beyaz Zetsu kütlesi: topaklı gövde, sırıtan ağız, yeşil saç tutamı (göğüs kemiğine göre, arkada)
static func _zetsu_blob() -> Mesh:
	return _cached("zetsu_blob", func():
		var b := MB.new()
		b.add("sphere", Vector3(0, 0.1, -0.24), Vector3(0.58, 0.66, 0.36), ZETSU, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0.18, -0.12, -0.26), Vector3(0.3, 0.3, 0.26), ZETSU, Vector3.ZERO, 10)
		b.add("sphere", Vector3(-0.2, 0.2, -0.27), Vector3(0.28, 0.3, 0.24), ZETSU, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0, 0.52, -0.26), Vector3(0.3, 0.32, 0.27), ZETSU, Vector3.ZERO, 10)
		b.add("box", Vector3(0, 0.46, -0.4), Vector3(0.16, 0.025, 0.02), Color(0.15, 0.15, 0.13), Vector3(0, 0, 0), 1)   # sırıtış
		for k in 5:
			b.add("box", Vector3(lerpf(-0.06, 0.06, k / 4.0), 0.46, -0.405), Vector3(0.005, 0.03, 0.01), Color(0.95, 0.95, 0.9), Vector3.ZERO, 1)
		b.add("sphere", Vector3(0.05, 0.56, -0.39), Vector3(0.04, 0.025, 0.02), Color(0.15, 0.15, 0.13), Vector3.ZERO, 6)
		for k in 5:
			var a := TAU * k / 5.0
			b.add("cone", Vector3(cos(a) * 0.07, 0.7, -0.26 + sin(a) * 0.07), Vector3(0.08, 0.16, 0.08), Color(0.45, 0.6, 0.35), Vector3(sin(a) * 25.0, 0, -cos(a) * 25.0), 5)
		return b.build())


# ================================================================== 22) Ters Harem
## Kurgu: her klon noktasında pembe kalp patlaması + dört uçlu parıltı → ortada süzülen pembe gül yaprakları ve parıltı
## yıldızları; bayılan kadın rakiplerin başından pembe kalpler yükselir.
static func oiroke_gyaku_haremu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	pj.anim(c, "seal", 1.2)
	var fw: Vector3 = c.face_dir()
	var sd := fw.cross(Vector3.UP).normalized()
	var at: Vector3 = c.global_position + fw * 3.0
	var hm := cel(PINK, 0.008, Color(0.6, 0.15, 0.35), true, 1.2)
	var heart := _heart_mesh()
	for k in 5:
		var q = pj.gp(at + sd * (k - 2) * 1.3 + fw * absf(k - 2) * -0.4)
		flash(pj, q + Vector3.UP, Color(1.0, 0.75, 0.9), 1.2, 1.0, 0.25, true, 1.4, 1.5)
		burst(pj, q + Vector3.UP, heart, hm, 6, 0.7, {"r": 0.3, "vmin": 1.5, "vmax": 3.0, "g": Vector3(0, 1, 0), "damp": 2.0, "smin": 0.6, "smax": 1.0, "spin": 90.0})
		var d = ShadowClone.new()
		d.team = c.team
		var lk: Dictionary = c.model.look.duplicate() if c.get("model") else {}
		lk["gender"] = "m"
		lk["top"] = lk.get("skin", Color(0.96, 0.8, 0.66))   # ref: üstsüz
		lk["hide_top"] = true
		lk["hair"] = [Color(0.85, 0.75, 0.35), Color(0.15, 0.12, 0.1), Color(0.75, 0.75, 0.82), Color(0.5, 0.25, 0.15), Color(0.2, 0.2, 0.3)][k]
		lk["hair_style"] = ["diken", "dağınık", "uzun", "kisa", "geriye"][k]
		d.look = lk
		d.life = 3.0
		pj.get_tree().current_scene.add_child(d)
		d.global_position = q
		d.set_meta("decoy_only", true)
	burst(pj, at + Vector3.UP * 2.0, _petal_mesh(), cel(Color(1.0, 0.55, 0.72), 0.0, INK, true, 1.5), 50, 1.8, {"r": 3.5, "dir": Vector3.UP, "spread": 80.0,
		"vmin": 0.3, "vmax": 1.2, "g": Vector3(0, -0.8, 0), "damp": 0.5, "smin": 0.7, "smax": 1.3, "spin": 240.0, "hold": 0.8})
	var sp := burst(pj, at + Vector3.UP * 1.6, _quad(), flare_mat(Color(1, 0.85, 0.95), 1.0, true, true, 1.5), 26, 1.0, {"r": 3.0, "vmin": 0.2, "vmax": 0.8,
		"g": Vector3.ZERO, "smin": 0.25, "smax": 0.55, "spin": 0.0})
	sp.particle_flag_rotate_y = false
	Sfx.play("poof", at, 1.1)
	pj.after(0.35, func():
		for e in pj.enemies_near(c, at, 14.0):
			if not pj.live(e):
				continue
			var lk2 = e.get("look")
			var female = lk2 is Dictionary and String(lk2.get("gender", "m")) == "f"
			var boss = e is Boss or e.has_meta("kage_of")
			var dur = 1.2 if boss else (4.0 if female else 1.8)
			pj.st(e, "stun", dur)
			Combat.popup_text(e.global_position + Vector3.UP * 2.4, "Bayıldı!" if female and not boss else "Dikkati dağıldı!", Color(1.0, 0.6, 0.8))
			if female and not boss:
				burst(pj, e.global_position + Vector3.UP * 1.9, heart, hm, 6, 1.2, {"r": 0.3, "dir": Vector3.UP, "spread": 30.0, "vmin": 0.6, "vmax": 1.4,
					"g": Vector3(0, 0.5, 0), "smin": 0.5, "smax": 0.8, "spin": 60.0}))


static func _heart_mesh() -> Mesh:
	return _cached("heart", func():
		var b := MB.new()
		b.add_slab(_heart2d(0.3), 0.04, PINK, Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3.ZERO))
		return b.build())


static func _petal_mesh() -> Mesh:
	return _cached("petal", func():
		var b := MB.new()
		b.add_slab(PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0.05), Vector2(0.045, 0.12), Vector2(0, 0.15), Vector2(-0.045, 0.12), Vector2(-0.05, 0.05)]), 0.01, Color.WHITE, _flat_xf())
		return b.build())
