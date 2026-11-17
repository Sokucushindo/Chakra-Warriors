class_name NinjutsuFXC
extends RefCounted
## Genel ninjutsu grubu C: on beş tekniğin görselleri — hepsi bu dosyada, sıfırdan (hazır efekt / ortak yapı yok).
## Yapı taşları: cel malzeme + kalın kontur (kanat çırpma örnek parametresiyle), kendi parçacık gölgelendiricisi
## (yumuşak kıvılcım / sert damla / yırtık mürekkep / kâğıt kırpıntısı), kameraya yaklaşınca sönen enerji, fırça izi şeridi,
## kâğıt yaprağı (kat çizgisi, patlayıcı etiket yazısı, yanan kenar, kâğıt denizi dalgası), canlı ip (kameraya dönük, sarkan),
## Rasengan küresi (sarmal çizgiler + dikenli hale), ses halkası, yer izleri (mürekkep, sümük, yanık, mühür, sarmal, çatlak),
## toon ateş topu, ayna camı, mühür yazısı ışınları, parşömen. Beden modu (Kyūbi Chakra Modu) gerçek bedenin derili örgüsünü
## kullanır (dinlenme pozuna bağlı kara mühür desenleri + alev kenarlı ikinci kabuk); kutu kabuk yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtan satır satır taşındı.

const INK := Color(0.035, 0.03, 0.045)
const PAPER_W := Color(0.97, 0.96, 0.99)
const PAPER_B := Color(0.8, 0.76, 0.9)
const PAPER_L := Color(0.32, 0.27, 0.42)
const STEEL := Color(0.62, 0.64, 0.7)
const STEEL_D := Color(0.17, 0.17, 0.2)
const CHAKRA := Color(0.55, 0.78, 1.0)
const GOLD := Color(1.0, 0.82, 0.3)
const FLAME := Color(1.0, 0.5, 0.1)
const SLIME := Color(0.86, 0.82, 0.62)
const LEECH := Color(0.07, 0.04, 0.1)
const SOUND := Color(0.85, 0.8, 1.0)
const MIRROR := Color(0.45, 0.95, 0.55)
const CROW := Color(0.05, 0.05, 0.07)
const SCRIPT := Color(0.78, 0.9, 1.0)
const DUST := Color(0.86, 0.8, 0.68)
const ROCK := Color(0.45, 0.4, 0.34)

static var _shaders := {}
static var _mats := {}
static var _meshes := {}


# ================================================================== gölgelendiriciler
const NOISE := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
"""

const BILL := """
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float bs = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mw * mat4(vec4(bs, 0.0, 0.0, 0.0), vec4(0.0, bs, 0.0, 0.0), vec4(0.0, 0.0, bs, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
"""

# cel: köşe rengi × tint, toon ışık, kenar parıltısı; flap > 0 iken |x| > 0.05 köşeler (kanat) çırpar
const CEL_SH := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;
uniform vec4 tint : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform vec4 glow_col : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float sheen = 0.0;
uniform vec4 sheen_col : source_color = vec4(0.35, 0.3, 0.6, 1.0);
uniform float flap = 0.0;
instance uniform float phase = 0.0;
void vertex() {
	if (flap > 0.0) {
		float w = max(abs(VERTEX.x) - 0.05, 0.0);
		VERTEX.y += w * flap * sin(TIME * 17.0 + phase);
	}
}
void fragment() {
	ALBEDO = COLOR.rgb * tint.rgb;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_col.rgb * glow * (0.4 + fr) + sheen_col.rgb * sheen * fr;
	ROUGHNESS = 1.0;
}
"""

const LINE_SH := """
shader_type spatial;
render_mode unshaded, cull_front, specular_disabled, shadows_disabled;
uniform vec4 line_col : source_color = vec4(0.05, 0.04, 0.05, 1.0);
uniform float width = 0.012;
uniform float flap = 0.0;
instance uniform float phase = 0.0;
void vertex() {
	if (flap > 0.0) {
		float w = max(abs(VERTEX.x) - 0.05, 0.0);
		VERTEX.y += w * flap * sin(TIME * 17.0 + phase);
	}
	VERTEX += normalize(NORMAL) * width;
}
void fragment() {
	ALBEDO = line_col.rgb;
}
"""

# parçacık (CPUParticles3D, kameraya dönük): 0 yumuşak kıvılcım, 1 sert damla + koyu kenar, 2 yırtık mürekkep lekesi, 3 kâğıt kırpıntısı
const PART_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_%s, shadows_disabled;
uniform int shape = 0;
uniform vec4 line_col : source_color = vec4(0.05, 0.04, 0.06, 1.0);
varying float camd;
varying float seedv;
%s
void vertex() {
%s
	seedv = hash(MODEL_MATRIX[3].xz * 7.13 + MODEL_MATRIX[3].yy);
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	vec3 c = COLOR.rgb;
	float a = 0.0;
	if (shape == 0) {
		a = 1.0 - smoothstep(0.15, 1.0, r);
		c = mix(vec3(1.0), c, smoothstep(0.0, 0.45, r));
	} else if (shape == 1) {
		if (r > 0.9) discard;
		a = 1.0;
		if (r > 0.68) c = line_col.rgb;
	} else if (shape == 2) {
		float ang = atan(q.y, q.x);
		float e = 0.6 + 0.3 * vnoise(vec2(ang * 1.7 + seedv * 40.0, seedv * 9.0));
		if (r > e) discard;
		a = 1.0;
		c += vec3(0.05, 0.04, 0.08) * smoothstep(e - 0.2, e, r);
	} else {
		float m = max(abs(q.x), abs(q.y * 1.3));
		if (m > 0.85) discard;
		a = 1.0;
		if (m > 0.68) c = line_col.rgb;
	}
	ALBEDO = c;
	ALPHA = a * COLOR.a * smoothstep(0.3, 1.2, camd);
}
"""

# enerji örgüsü: kenar parlar, gürültü akar, kameraya yakını söner; lick > 0: alev dili ucu (lp.y 0..1) parçalanır
const ENERGY_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_%s, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float amount = 1.0;
uniform float flow = 2.0;
uniform float near_fade = 1.6;
uniform float lick = 0.0;
%s
varying vec3 lp;
varying float camd;
void vertex() {
	lp = VERTEX;
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float n = vnoise(lp.xy * 4.0 + vec2(0.0, -TIME * flow)) * 0.6 + vnoise(lp.zy * 7.0 + vec2(TIME * flow * 0.6, 0.0)) * 0.4;
	if (lick > 0.0 && n < lp.y * lick - 0.15) discard;
	vec3 c = mix(core.rgb, col.rgb, clamp(fres + n * 0.4, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp(0.35 + fres * 0.5 + n * 0.35, 0.0, 1.0) * amount * COLOR.a * smoothstep(near_fade * 0.4, near_fade, camd);
}
"""

# Rasengan kabuğu: enlem-boylamda dönen beyaz sarmal çizgiler, açık mavi gövde, koyu mavi kontur
const RASEN_SH := """
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque, shadows_disabled;
uniform float amount = 1.0;
uniform float spin = 18.0;
%s
varying vec3 lp;
varying float camd;
void vertex() {
	lp = VERTEX;
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	vec3 p = normalize(lp);
	float ang = atan(p.z, p.x);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float sw = sin(ang * 5.0 + lat * 9.0 - TIME * spin + vnoise(vec2(ang * 3.0, lat * 4.0 - TIME * 4.0)) * 3.0);
	float sw2 = sin(ang * -3.0 + lat * 14.0 - TIME * spin * 1.3);
	float lines = smoothstep(0.8, 0.97, sw) + smoothstep(0.88, 0.99, sw2) * 0.7;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 c = mix(vec3(0.78, 0.92, 1.0), vec3(0.35, 0.62, 1.0), fres);
	c = mix(c, vec3(1.0), clamp(lines, 0.0, 1.0));
	c = mix(c, vec3(0.12, 0.32, 0.8), smoothstep(0.82, 0.98, fres));
	ALBEDO = c;
	ALPHA = clamp(0.78 + lines * 0.22, 0.0, 1.0) * amount * smoothstep(0.25, 0.8, camd);
}
"""

# hale: kameraya dönük dörtgen — ince halka + dışa taşan dikenler (Rasengan'ın chakra çiçeği)
const HALO_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 col : source_color = vec4(0.5, 0.75, 1.0, 1.0);
uniform float amount = 1.0;
uniform float spikes = 26.0;
%s
varying float camd;
void vertex() {
%s
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float ring = exp(-pow((r - 0.5) / 0.05, 2.0));
	float sp = pow(max(0.0, sin(ang * spikes + TIME * 3.0 + vnoise(vec2(ang * 4.0, TIME * 2.0)) * 2.0)), 14.0) * smoothstep(1.0, 0.5, r) * step(0.48, r);
	float soft = smoothstep(0.7, 0.25, r) * 0.22;
	ALBEDO = col.rgb;
	ALPHA = clamp(ring + sp * 0.8 + soft, 0.0, 1.0) * amount * smoothstep(0.4, 1.2, camd);
}
"""

# sarmal disk (Rasengan öğütmesi): dönen üç kol + dış kenar
const SWIRL_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 col : source_color = vec4(0.45, 0.72, 1.0, 1.0);
uniform vec4 core : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float amount = 1.0;
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) discard;
	float ang = atan(q.y, q.x);
	float arm = sin(ang * 3.0 + r * 11.0 - TIME * 26.0);
	float a = smoothstep(0.55, 1.0, arm) * smoothstep(1.0, 0.65, r) * (0.35 + r);
	a += exp(-pow((r - 0.9) / 0.05, 2.0)) * 0.6 + smoothstep(0.3, 0.0, r) * 0.5;
	ALBEDO = mix(core.rgb, col.rgb, r);
	ALPHA = clamp(a, 0.0, 1.0) * amount * smoothstep(0.5, 1.5, camd);
}
"""

# halka şeridi (UV.x çevre, UV.y yarıçap): ince parlak çizgi + gezinen parıltılar; iri > 0 gökkuşağı yanardöner (ses)
const RING_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 col : source_color = vec4(0.85, 0.8, 1.0, 1.0);
uniform float amount = 1.0;
uniform float iri = 0.0;
%s
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float t = abs(UV.y * 2.0 - 1.0);
	float line = 1.0 - smoothstep(0.15, 1.0, t);
	float hue = fract(UV.x * 2.0 + TIME * 0.8);
	vec3 rb = 0.5 + 0.5 * cos(6.2831 * (hue + vec3(0.0, 0.33, 0.67)));
	vec3 c = mix(col.rgb, rb, 0.4 * iri);
	float glint = pow(vnoise(vec2(UV.x * 48.0, TIME * 6.0)), 6.0) * 3.0;
	ALBEDO = c + vec3(glint);
	ALPHA = clamp(line * 0.85 + glint * line, 0.0, 1.0) * amount * smoothstep(0.4, 1.3, camd);
}
"""

# fırça izi şeridi (UV.x boy, UV.y en): yırtık kenar, kuru fırça kuyruğu, reveal ile çizilir
const STROKE_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 ink_col : source_color = vec4(0.035, 0.03, 0.045, 1.0);
uniform float reveal = 1.0;
uniform float tail = 0.0;
uniform float amount = 1.0;
%s
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	if (UV.x > reveal || UV.x < tail) discard;
	float across = abs(UV.y * 2.0 - 1.0);
	float taper = sin(clamp(UV.x, 0.0, 1.0) * 3.14159) * 0.6 + 0.4;
	float edge = taper * (0.72 + 0.28 * vnoise(vec2(UV.x * 34.0, UV.y * 3.0)));
	if (across > edge) discard;
	float dry = vnoise(vec2(UV.x * 5.0, UV.y * 38.0));
	if (UV.x > 0.7 && dry < 0.42 && across > 0.25) discard;
	ALBEDO = ink_col.rgb + vec3(0.07, 0.06, 0.1) * smoothstep(0.55, 1.0, across);
	ALPHA = amount * smoothstep(0.4, 1.4, camd);
}
"""

# mürekkep sisi öbeği: kameraya dönük yırtık kenarlı koyu leke, içte yavaş kaynar; kameraya yakını açılır (ekranı kapatmaz)
const CLOUD_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 ink_col : source_color = vec4(0.035, 0.03, 0.045, 1.0);
uniform float amount = 1.0;
%s
varying float camd;
varying float seedv;
void vertex() {
%s
	seedv = hash(MODEL_MATRIX[3].xz);
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float n = vnoise(q * 2.2 + vec2(seedv * 13.0 + TIME * 0.15, TIME * 0.1)) * 0.6 + vnoise(q * 5.0 - vec2(TIME * 0.2, seedv * 5.0)) * 0.4;
	float e = 0.58 + n * 0.38;
	float a = 1.0 - smoothstep(e - 0.22, e, r);
	if (a < 0.01) discard;
	ALBEDO = ink_col.rgb + vec3(0.05, 0.04, 0.09) * n;
	ALPHA = a * 0.86 * amount * smoothstep(1.6, 4.5, camd);
}
"""

# yer izi (yatay düzlem): 0 mürekkep lekesi + damlacıklar, 1 sümük gölü, 2 yanık, 3 kırmızı mühür halkası, 4 sarmal oyuk, 5 çatlak
const DECAL_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform int mode = 0;
uniform vec4 col : source_color = vec4(0.03, 0.03, 0.04, 0.95);
uniform float amount = 1.0;
uniform float heat = 0.0;
uniform float seed = 0.0;
uniform float grow = 1.0;
%s
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q) / max(grow, 0.001);
	float ang = atan(q.y, q.x);
	vec3 c = col.rgb;
	float a = 0.0;
	if (mode == 0) {
		float e = 0.55 + 0.25 * vnoise(vec2(ang * 2.5 + seed, seed));
		vec2 g = q * 6.0;
		vec2 f = fract(g) - 0.5;
		float h = hash(floor(g) + seed);
		float sat = step(length(f), 0.2 * h) * step(0.72, h) * step(r, 1.0);
		a = max(step(r, e), sat);
		c += vec3(0.07) * step(e - 0.05, r) * step(r, e);
	} else if (mode == 1) {
		float e = 0.6 + 0.22 * vnoise(vec2(ang * 2.0 + seed, seed));
		if (r > e) discard;
		float rimv = smoothstep(e - 0.14, e, r);
		c = mix(c, c * 0.62, rimv) + vec3(0.25) * step(0.86, vnoise(q * 4.0 + seed));
		a = 0.72 + rimv * 0.25;
	} else if (mode == 2) {
		float e = 0.7 + 0.25 * vnoise(vec2(ang * 3.0 + seed, seed));
		if (r > e) discard;
		float dk = smoothstep(e, 0.0, r);
		c = mix(c, vec3(0.02, 0.015, 0.01), dk * 0.6) + vec3(1.0, 0.45, 0.1) * heat * step(0.78, vnoise(q * 9.0 + seed)) * smoothstep(e, 0.2, r);
		a = 0.35 + 0.6 * dk;
	} else if (mode == 3) {
		float r1 = 1.0 - smoothstep(0.02, 0.045, abs(r - 0.9));
		float r2 = 1.0 - smoothstep(0.015, 0.035, abs(r - 0.72));
		float tick = step(0.72, r) * step(r, 0.9) * step(0.9, abs(sin(ang * 12.0)));
		float crs = max(step(abs(q.x), 0.05) * step(abs(q.y), 0.42), step(abs(q.y), 0.05) * step(abs(q.x), 0.3));
		a = max(max(r1, r2), max(tick, crs));
	} else if (mode == 4) {
		float s = sin(ang * 3.0 + r * 12.0);
		a = smoothstep(0.65, 1.0, s) * smoothstep(1.0, 0.3, r) + smoothstep(0.35, 0.0, r) * 0.6;
	} else {
		float sector = floor((ang + 3.14159) / 6.28318 * 9.0);
		float h = hash(vec2(sector, seed));
		float la = (sector + 0.5 + (h - 0.5) * 0.6) / 9.0 * 6.28318 - 3.14159;
		float jag = (vnoise(vec2(r * 9.0, sector * 3.1)) - 0.5) * 0.25;
		float da = abs(ang - la - jag);
		float w = 0.06 * (1.0 - r) + 0.012;
		float crk = step(da * r, w * 0.5) * step(r, 0.55 + h * 0.42);
		float pit = step(r, 0.22 + 0.05 * vnoise(vec2(ang * 3.0, seed)));
		a = max(crk, pit * 0.85);
	}
	if (a < 0.05) discard;
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0) * col.a * amount;
}
"""

# kâğıt yaprağı (PlaneMesh UV): ön beyaz / arka mor gölge, koyu kenar, patlayıcı etiket yazısı, yanan kenar, kâğıt denizi dalgası
const PAPER_SH := """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform vec4 front_col : source_color = vec4(0.97, 0.96, 0.99, 1.0);
uniform vec4 back_col : source_color = vec4(0.8, 0.76, 0.9, 1.0);
uniform vec4 edge_col : source_color = vec4(0.32, 0.27, 0.42, 1.0);
uniform float tag = 0.0;
uniform float burn = 0.0;
uniform float ignite = 0.0;
uniform float wave = 0.0;
uniform vec3 wave_center = vec3(0.0);
%s
varying float seedv;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seedv = hash(MODEL_MATRIX[3].xz * 3.7 + MODEL_MATRIX[3].yy);
	if (wave > 0.0) {
		float dd = length(wp.xz - wave_center.xz);
		float dy = wave * (sin(dd * 0.8 - TIME * 3.0) * 0.6 + sin(dd * 1.7 + TIME * 2.1 + seedv * 6.0) * 0.4 + 0.6);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(0.0, dy, 0.0);
	}
}
void fragment() {
	vec2 uv = UV;
	float bn = vnoise(uv * 6.0 + seedv * 17.0);
	if (burn > 0.0 && bn < burn) discard;
	vec3 c = FRONT_FACING ? front_col.rgb : back_col.rgb;
	float bd = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	if (bd < 0.045) c = edge_col.rgb;
	float tg = max(tag, ignite);
	if (tg > 0.0) {
		if (abs(uv.x - 0.5) < 0.07 && uv.y > 0.14 && uv.y < 0.86) c = mix(c, vec3(0.72, 0.1, 0.08), tg);
		vec2 cell = floor(vec2(uv.x * 7.0, uv.y * 9.0));
		if (abs(uv.x - 0.5) > 0.12 && abs(uv.x - 0.5) < 0.32 && uv.y > 0.16 && uv.y < 0.84 && hash(cell + seedv) > 0.55) c = mix(c, vec3(0.08, 0.06, 0.08), tg);
	}
	vec3 em = vec3(0.0);
	if (burn > 0.0 && bn < burn + 0.09) { c = vec3(1.0, 0.55, 0.12); em = vec3(1.0, 0.45, 0.08) * 2.0; }
	em += vec3(1.0, 0.5, 0.15) * ignite * 0.7 * smoothstep(0.14, 0.0, bd);
	ALBEDO = c;
	EMISSION = em;
}
"""

# sümük: bej yarı saydam, koyu kenar, sabit parlama noktası; reveal ile boyunca uzar, web > 0 delikli zar
const SLIME_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 col : source_color = vec4(0.86, 0.82, 0.62, 1.0);
uniform float reveal = 1.0;
uniform float amount = 1.0;
uniform float web = 0.0;
%s
void fragment() {
	if (UV.x > reveal) discard;
	if (web > 0.0) {
		vec2 g = UV * vec2(5.0, 9.0);
		vec2 f = fract(g) - 0.5;
		float h = hash(floor(g));
		if (length(f * vec2(1.0, 0.6)) < 0.32 * web * (0.6 + h * 0.6)) discard;
	}
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	vec3 c = mix(col.rgb, col.rgb * 0.55, smoothstep(0.5, 0.9, fres));
	float hl = step(0.93, dot(NORMAL, normalize(vec3(-0.3, 0.8, 0.5))));
	ALBEDO = c + vec3(0.45) * hl;
	ALPHA = 0.88 * amount;
}
"""

# ayna camı: gümüş-yeşil, kayan yansıma bantları, yeşil kenar, merkezden yayılan çatlaklar; oval = dörtgende oval kesim
const MIRROR_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform float amount = 1.0;
uniform float crack = 0.0;
uniform float oval = 1.0;
uniform vec4 tint : source_color = vec4(0.45, 0.95, 0.55, 1.0);
%s
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float rr = length(q);
	if (oval > 0.5 && rr > 1.0) discard;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float band = smoothstep(0.85, 1.0, sin((wp.x + wp.y) * 3.0 - TIME * 4.0)) + smoothstep(0.93, 1.0, sin((wp.x - wp.y * 0.5) * 7.0 + TIME * 2.0)) * 0.6;
	vec3 c = mix(vec3(0.6, 0.7, 0.68), vec3(0.92, 1.0, 0.96), band);
	c = mix(c, tint.rgb, 0.3 + fres * 0.4);
	float ang = atan(q.y, q.x);
	float cr = step(abs(sin(ang * 7.0 + vnoise(vec2(rr * 6.0, 1.0)) * 2.0)), 0.07) * step(rr, crack * 1.3);
	c = mix(c, vec3(0.04, 0.12, 0.07), cr);
	if (oval > 0.5) c = mix(c, vec3(0.08, 0.32, 0.15), smoothstep(0.86, 0.96, rr));
	ALBEDO = c;
	ALPHA = clamp(0.62 + band * 0.3 + cr * 0.3, 0.0, 1.0) * amount;
}
"""

# mühür yazısı: 0 düz parlayan kalem darbesi (köşe rengi), 1 karalanmış yazı şeridi (hücre başına rastgele çizgiler)
const GLYPH_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 col : source_color = vec4(0.78, 0.9, 1.0, 1.0);
uniform float amount = 1.0;
uniform int mode = 0;
%s
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float a = 1.0;
	if (mode == 1) {
		vec2 g = vec2(UV.x * 26.0, UV.y * 2.0);
		vec2 id = floor(g);
		vec2 f = fract(g);
		float stroke = 0.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float hh = hash(id + vec2(fi * 7.3, 0.0));
			vec2 p0 = vec2(0.2 + 0.6 * hash(id + vec2(fi, 1.0)), 0.2 + 0.6 * hash(id + vec2(fi, 2.0)));
			vec2 dir = vec2(cos(hh * 6.28), sin(hh * 6.28));
			vec2 rel = f - p0;
			float along = dot(rel, dir);
			float across = abs(dot(rel, vec2(-dir.y, dir.x)));
			stroke = max(stroke, step(across, 0.07) * step(abs(along), 0.32));
		}
		float flick = 0.7 + 0.3 * sin(TIME * 20.0 + id.x);
		a = stroke * flick + (1.0 - smoothstep(0.0, 0.5, abs(UV.y - 0.5))) * 0.22;
		a *= 1.0 - smoothstep(0.85, 1.0, UV.x);
	}
	ALBEDO = col.rgb * COLOR.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * amount * smoothstep(0.5, 1.5, camd);
}
"""

# Kyūbi Chakra Modu: bedenin derili örgüsü (dinlenme pozu CUSTOM0) — altın örtü, turuncu kenar, kara mühür desenleri
# (yakada altı magatama, omuz sarmalları, göğüs zinciri, boyundan inen sap + ters U çatal + bacaklara iki çizgi, karında
# sarmal mühür ve altında virgül); reveal: karındaki mühürden dışa yayılarak kaplar
const KCM_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;
uniform float amount = 0.0;
uniform float reveal = 3.0;
uniform vec4 gold : source_color = vec4(1.0, 0.86, 0.36, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 ink : source_color = vec4(0.08, 0.05, 0.03, 1.0);
uniform float grow = 0.012;
%s
varying vec3 rp;
varying float camd;
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float spiral(vec2 p, float rmax) {
	float r = length(p);
	if (r > rmax) return 0.0;
	float a = atan(p.y, p.x) / 6.28318;
	float s = fract(r / (rmax * 0.34) - a);
	return step(abs(s - 0.5), 0.17);
}
float marks(vec3 p) {
	if (p.z < 0.02) return 0.0;
	float m = 0.0;
	float ax = abs(p.x);
	for (int i = 0; i < 3; i++) {
		float fx = 0.05 + float(i) * 0.035;
		vec2 q = vec2(ax, p.y) - vec2(fx, 1.405 - fx * 0.35);
		if (length(q) < 0.011) m = 1.0;
		if (length(q - vec2(0.007, -0.014)) < 0.006) m = 1.0;
	}
	float ch = seg(vec2(ax, p.y), vec2(0.21, 1.37), vec2(0.035, 1.3));
	if (ch < 0.006) m = 1.0;
	if (ch < 0.016 && fract(ax / 0.03) < 0.22 && ax > 0.045 && ax < 0.2) m = 1.0;
	if (seg(p.xy, vec2(0.0, 1.31), vec2(0.0, 1.15)) < 0.007) m = 1.0;
	if (p.y > 1.06 && abs(length(vec2(p.x, p.y - 1.06)) - 0.09) < 0.007) m = 1.0;
	if (p.y < 1.06 && p.y > 0.5 && abs(ax - 0.09) < 0.007) m = 1.0;
	if (p.y < 0.98 && p.y > 0.86 && abs(ax - 0.09) < 0.016) m = 1.0;
	m = max(m, spiral(vec2(p.x, p.y - 0.99), 0.065));
	if (length(vec2(p.x - 0.012, p.y - 0.9)) < 0.012) m = 1.0;
	if (seg(p.xy, vec2(0.012, 0.9), vec2(-0.004, 0.865)) < 0.005) m = 1.0;
	if (ax > 0.2 && p.y > 1.3) m = max(m, spiral(vec2(ax - 0.26, p.y - 1.38), 0.05));
	return m;
}
void vertex() {
	rp = CUSTOM0.xyz;
	VERTEX += NORMAL * grow;
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float d = length(rp - vec3(0.0, 0.99, 0.1));
	if (d > reveal) discard;
	float rimv = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float fl = vnoise(vec2(rp.x * 9.0 + rp.z * 6.0, rp.y * 7.0 - TIME * 3.0));
	vec3 c = mix(gold.rgb, vec3(1.0, 0.97, 0.75), fl * 0.35);
	c = mix(c, edge.rgb, smoothstep(0.55, 0.9, rimv));
	float mk = marks(rp);
	c = mix(c, ink.rgb, mk);
	float head = smoothstep(1.5, 1.62, rp.y);
	float a = mix(0.6 + rimv * 0.32, 0.95, mk);
	a *= mix(1.0, 0.42, head * (1.0 - mk));
	c = mix(c, vec3(1.0, 1.0, 0.9), (1.0 - smoothstep(0.0, 0.08, reveal - d)) * step(reveal, 1.9));
	ALBEDO = c;
	ALPHA = clamp(a * amount, 0.0, 1.0) * smoothstep(0.35, 1.1, camd);
}
"""

# Kyūbi alev kenarı: şişirilmiş ikinci derili kabuk, arka yüzleri çizilir (yalnız siluetin dışında görünür), dil dil yukarı yalar
const KCM_FLAME_SH := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, shadows_disabled;
uniform float amount = 0.0;
uniform float grow = 0.07;
%s
varying vec3 rp;
varying float camd;
void vertex() {
	rp = CUSTOM0.xyz;
	float lk = vnoise(vec2(rp.x * 6.0 + rp.z * 4.0, rp.y * 3.0 - TIME * 3.5));
	vec3 up = normalize(inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0));
	VERTEX += NORMAL * grow * (0.5 + lk * 1.2) + up * grow * lk * 1.6;
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float n = vnoise(vec2(rp.x * 7.0 + rp.z * 5.0, rp.y * 4.0 - TIME * 4.0));
	float n2 = vnoise(vec2(rp.x * 15.0 + rp.z * 9.0, rp.y * 10.0 - TIME * 7.0));
	float f = n * 0.65 + n2 * 0.35;
	if (f < 0.4) discard;
	ALBEDO = mix(vec3(1.0, 0.42, 0.06), vec3(1.0, 0.86, 0.38), smoothstep(0.45, 0.8, f));
	ALPHA = smoothstep(0.4, 0.55, f) * 0.85 * amount * smoothstep(0.45, 1.3, camd);
}
"""

# toon ateş topu (patlayıcı etiket): pürüzlü yüzey, basamaklı renk kuşakları, heat ile kömürleşir, amount ile delik delik dağılır
const FIRE_SH := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform float heat = 1.0;
uniform float amount = 1.0;
uniform float bumps = 0.22;
uniform float seed = 0.0;
%s
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	float n = vnoise(VERTEX.xy * 4.0 + vec2(seed, TIME * 1.5)) * 0.6 + vnoise(VERTEX.zy * 6.0 + vec2(-TIME * 2.0, seed)) * 0.4;
	VERTEX += NORMAL * n * bumps;
}
void fragment() {
	float n = vnoise(lp.xy * 6.0 + vec2(seed, -TIME * 3.0)) * 0.6 + vnoise(lp.zx * 9.0 + vec2(TIME, seed)) * 0.4;
	if (n > amount + 0.05) discard;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float t = fres * 0.8 + n * 0.4;
	vec3 hot = t < 0.35 ? vec3(1.0, 0.97, 0.82) : (t < 0.6 ? vec3(1.0, 0.82, 0.3) : (t < 0.85 ? vec3(1.0, 0.48, 0.1) : vec3(0.6, 0.12, 0.05)));
	vec3 cold = mix(vec3(0.16, 0.13, 0.13), vec3(0.32, 0.27, 0.25), step(0.5, t));
	ALBEDO = mix(cold, hot, heat);
}
"""

# parşömen: bej kâğıt, kızıl kenar, sütun sütun kara yazı, ortada mühür halkası; unroll ile yukarıdan aşağı açılır
const SCROLL_SH := """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform float unroll = 1.0;
%s
void fragment() {
	if (UV.y > unroll) discard;
	vec3 c = vec3(0.93, 0.87, 0.72);
	float bx = min(UV.x, 1.0 - UV.x);
	if (bx < 0.07) c = vec3(0.62, 0.1, 0.1);
	if (bx < 0.018) c = vec3(0.15, 0.04, 0.04);
	vec2 g = vec2(UV.x * 9.0, UV.y * 26.0);
	vec2 id = floor(g);
	vec2 f = fract(g);
	if (bx > 0.1 && hash(id) > 0.45 && abs(f.x - 0.5) < 0.22 && abs(f.y - 0.5) < 0.3) c = vec3(0.08, 0.06, 0.06);
	vec2 q = (UV - vec2(0.5, 0.5)) * vec2(1.0, 1.7);
	float r = length(q);
	if (r < 0.3) c = vec3(0.93, 0.87, 0.72);
	if (abs(r - 0.28) < 0.018 || abs(r - 0.2) < 0.01) c = vec3(0.62, 0.08, 0.08);
	if (r < 0.16 && (abs(q.x) < 0.02 || abs(q.y) < 0.02)) c = vec3(0.1, 0.05, 0.05);
	ALBEDO = c;
}
"""

# hız / çizgi izi: UV.x 0 baş → 1 kuyruk, ince uç, yumuşak kenar
const STREAK_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_%s, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float amount = 1.0;
varying float camd;
void vertex() {
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float w = mix(1.0, 0.15, UV.x);
	if (across > w) discard;
	ALBEDO = col.rgb;
	ALPHA = (1.0 - UV.x) * (1.0 - across / w * 0.6) * col.a * amount * smoothstep(0.4, 1.3, camd);
}
"""

# çizgi roman darbe yıldızı: kameraya dönük dikenli beyaz çekirdek, sıcak kuşak, koyu kontur
const STAR_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.8, 0.35, 1.0);
uniform float amount = 1.0;
uniform float seed = 0.0;
%s
varying float camd;
void vertex() {
%s
	camd = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float k = floor((ang + 3.14159) / 6.28318 * 10.0);
	float sp = 0.42 + 0.5 * pow(abs(sin(ang * 5.0 + seed)), 4.0) * (0.6 + 0.4 * hash(vec2(k, seed)));
	if (r > sp) discard;
	vec3 c = r < sp * 0.55 ? vec3(1.0, 1.0, 0.95) : col.rgb;
	if (r > sp - 0.06) c = vec3(0.08, 0.05, 0.04);
	ALBEDO = c;
	ALPHA = amount * smoothstep(0.5, 1.4, camd);
}
"""


static func _sh(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var s = Shader.new()
		s.code = code
		_shaders[key] = s
	return _shaders[key]


static func _mat(key: String, code: String, params := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh(key, code)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Cel malzeme + kontur (flap: kanat çırpma, örnek parametresi "phase")
static func cel(tint := Color.WHITE, line := 0.012, glow := 0.0, glow_col := FLAME, flap := 0.0, sheen := 0.0) -> ShaderMaterial:
	var m = _mat("cel", CEL_SH, {"tint": tint, "glow": glow, "glow_col": glow_col, "flap": flap, "sheen": sheen})
	if line > 0.0:
		m.next_pass = _mat("line", LINE_SH, {"width": line, "flap": flap})
	return m


static func energy(col: Color, core: Color, add := true, flow := 2.0, near := 1.6, lick := 0.0) -> ShaderMaterial:
	var bl = "add" if add else "mix"
	return _mat("en_" + bl, ENERGY_SH % [bl, NOISE], {"col": col, "core": core, "flow": flow, "near_fade": near, "lick": lick})


static func _pmat(shape: int, add: bool) -> ShaderMaterial:
	var key = "p%d%s" % [shape, "a" if add else "m"]
	if not _mats.has(key):
		var bl = "add" if add else "mix"
		_mats[key] = _mat("part_" + bl, PART_SH % [bl, NOISE, BILL], {"shape": shape})
	return _mats[key]


static func _paper_mat(tag := 0.0, front := PAPER_W, back := PAPER_B, edge := PAPER_L) -> ShaderMaterial:
	return _mat("paper", PAPER_SH % NOISE, {"tag": tag, "front_col": front, "back_col": back, "edge_col": edge})


static func _streak_mat(col: Color, add := true) -> ShaderMaterial:
	var bl = "add" if add else "mix"
	return _mat("streak_" + bl, STREAK_SH % bl, {"col": col})


# ================================================================== genel yardımcılar
static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _put(pj: PathJutsu, n: Node3D, pos: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func _cam(pj: PathJutsu, fallback: Vector3) -> Vector3:
	var cam = pj.get_viewport().get_camera_3d()
	return cam.global_position if cam else fallback + Vector3(0, 4, 6)


## Malzemenin bir parametresini yumuşakça değiştirip (isteğe bağlı) düğümü siler
static func _fade(n: Node, m: ShaderMaterial, delay: float, dur: float, free := true, param := "amount", to := 0.0) -> void:
	if not is_instance_valid(n):
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(x: float): m.set_shader_parameter(param, x), _sp0(m.get_shader_parameter(param)), to, dur)
	if free:
		tw.tween_callback(n.queue_free)


static func _param(n: Node, m: ShaderMaterial, param: String, from: float, to: float, dur: float, delay := 0.0) -> void:
	if not is_instance_valid(n):
		return
	m.set_shader_parameter(param, from)
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(x: float): m.set_shader_parameter(param, x), from, to, dur)


static func _shrink(n: Node3D, delay: float, dur: float) -> void:
	if not is_instance_valid(n):
		return
	var tw = n.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(n, "scale", Vector3.ONE * 0.02, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


static func _pop_in(n: Node3D, to: Vector3, dur := 0.15) -> void:
	n.scale = to * 0.05
	n.create_tween().tween_property(n, "scale", to, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Balistik savrulma: yer çekimiyle yay çizer, döner, sonunda küçülüp silinir
static func _toss(n: Node3D, from: Vector3, vel: Vector3, life: float, spin := Vector3.ZERO, g := 9.8) -> void:
	var s0 = n.scale
	var tw = n.create_tween()
	tw.tween_method(func(x: float):
		if is_instance_valid(n):
			n.global_position = from + vel * x + Vector3.DOWN * 0.5 * g * x * x
			n.rotation = spin * x
			if x > life * 0.65:
				n.scale = s0 * maxf(0.03, 1.0 - (x - life * 0.65) / (life * 0.35)), 0.0, life, life)
	tw.tween_callback(n.queue_free)


static func _basis_look(d: Vector3) -> Basis:
	var f = d.normalized() if d.length() > 0.0001 else Vector3.FORWARD
	return Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT)


## d'ye dik düzlemde iki eksen
static func _perp(d: Vector3) -> Array:
	var f = d.normalized()
	var a = f.cross(Vector3.UP)
	if a.length() < 0.05:
		a = f.cross(Vector3.RIGHT)
	a = a.normalized()
	return [a, a.cross(f).normalized()]


## Tek atımlık / sürekli parçacık (kendi gölgelendiricimle); o: n, life, burst, dir, spread, vmin, vmax, grav, drag,
## smin, smax, grow [başta, sonda], cols, r, shape, add, radial, one_shot
static func _spray(pj: PathJutsu, pos: Vector3, o: Dictionary, parent: Node = null) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	var one = bool(o.get("one_shot", true))
	p.one_shot = one
	p.emitting = false
	p.amount = int(o.get("n", 20))
	p.lifetime = float(o.get("life", 1.0))
	p.explosiveness = float(o.get("burst", 0.9 if one else 0.0))
	p.randomness = 0.5
	p.local_coords = false
	var q = QuadMesh.new()
	q.size = Vector2.ONE
	p.mesh = q
	p.material_override = _pmat(int(o.get("shape", 0)), bool(o.get("add", false)))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 45.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("grav", Vector3(0, -9.8, 0))
	p.damping_min = float(o.get("drag", 0.0))
	p.damping_max = float(o.get("drag", 0.0))
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0))
	p.scale_amount_min = float(o.get("smin", 0.1))
	p.scale_amount_max = float(o.get("smax", 0.25))
	var gr: Array = o.get("grow", [1.0, 0.3])
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, gr[0]))
	cv.add_point(Vector2(1.0, gr[1]))
	p.scale_amount_curve = cv
	var cols: Array = o.get("cols", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([cols[0], cols[cols.size() - 1]])
	if cols.size() > 2:
		for i in range(1, cols.size() - 1):
			g.add_point(float(i) / (cols.size() - 1), cols[i])
	p.color_ramp = g
	var r = float(o.get("r", 0.1))
	if o.has("box"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = o["box"]
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = r
	(parent if parent else pj.get_tree().current_scene).add_child(p)
	p.global_position = pos
	p.emitting = true
	if one:
		pj.free_after(p.lifetime + 0.6, p)
	return p


## Yatay yer izi
static func _decal(pj: PathJutsu, pos: Vector3, r: float, mode: int, col: Color, dur: float, fade := 0.8) -> MeshInstance3D:
	var pm = PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0)
	var m = _mat("decal", DECAL_SH % NOISE, {"mode": mode, "col": col, "seed": randf() * 50.0})
	var mi = _mi(pm, m)
	_put(pj, mi, pj.gp(pos) + Vector3.UP * (0.04 + randf() * 0.02))
	mi.rotation.y = randf() * TAU
	_fade(mi, m, maxf(0.0, dur - fade), fade)
	return mi


## Canlı ip: iki uç her karede okunur, kameraya dönük ince şerit, ortası sarkar
static func _wire(pj: PathJutsu, a_fn: Callable, b_fn: Callable, dur: float, col: Color, w := 0.02, sag := 0.0, add := true) -> MeshInstance3D:
	var im = ImmediateMesh.new()
	var bl = "add" if add else "mix"
	var m = _mat("wire_" + bl, STREAK_SH % bl, {"col": col})
	var mi = _mi(im, m)
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var upd = func(_i, _k):
		if not is_instance_valid(mi):
			return
		im.clear_surfaces()
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		if a == Vector3.ZERO or b == Vector3.ZERO or a.distance_to(b) < 0.05:
			return
		var eye = _cam(pj, a)
		var td = (b - a).normalized()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n = 12
		for s in n + 1:
			var f = float(s) / n
			var p = a.lerp(b, f) + Vector3.DOWN * sag * 4.0 * f * (1.0 - f)
			var side = td.cross((eye - p).normalized())
			if side.length() < 0.01:
				side = Vector3.RIGHT
			side = side.normalized() * w * 0.5
			# UV.x = 0.25 sabit: şerit boyunca tek tonda kalır (STREAK uç incelmesi ip boyunca istenmez)
			im.surface_set_uv(Vector2(0.25, 0.0))
			im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(0.25, 1.0))
			im.surface_add_vertex(p + side)
		im.surface_end()
	upd.call(0, 0.0)
	pj.every(dur, 1.0 / 30.0, upd, func():
		if is_instance_valid(mi):
			mi.queue_free())
	return mi


## Boru örgüsü (UV.x boy, UV.y çevre)
static func _tube_mesh(pts: Array, radii: Array, sides := 6) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size()
	var prev_side = Vector3.ZERO
	var rings = []
	for i in n:
		var t: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side = t.cross(Vector3.UP)
		if side.length() < 0.05:
			side = prev_side if prev_side != Vector3.ZERO else t.cross(Vector3.RIGHT)
		side = side.normalized()
		prev_side = side
		var up = side.cross(t).normalized()
		var ring = []
		for s in sides + 1:
			var a = TAU * s / sides
			var nv = side * cos(a) + up * sin(a)
			ring.append([pts[i] + nv * float(radii[i]), nv, Vector2(float(i) / (n - 1), float(s) / sides)])
		rings.append(ring)
	for i in n - 1:
		for s in sides:
			var q = [rings[i][s], rings[i + 1][s], rings[i + 1][s + 1], rings[i][s], rings[i + 1][s + 1], rings[i][s + 1]]
			for v in q:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.set_color(Color.WHITE)
				st.add_vertex(v[0])
	return st.commit()


## Şerit örgüsü: her noktada genişlik yönü (ups) ve genişlik
static func _strip_mesh(pts: Array, ups: Array, widths: Array) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size()
	for i in n - 1:
		var a0: Vector3 = pts[i] - ups[i] * widths[i] * 0.5
		var a1: Vector3 = pts[i] + ups[i] * widths[i] * 0.5
		var b0: Vector3 = pts[i + 1] - ups[i + 1] * widths[i + 1] * 0.5
		var b1: Vector3 = pts[i + 1] + ups[i + 1] * widths[i + 1] * 0.5
		var u0 = float(i) / (n - 1)
		var u1 = float(i + 1) / (n - 1)
		for v in [[a0, Vector2(u0, 0)], [b0, Vector2(u1, 0)], [b1, Vector2(u1, 1)], [a0, Vector2(u0, 0)], [b1, Vector2(u1, 1)], [a1, Vector2(u0, 1)]]:
			st.set_uv(v[1])
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.add_vertex(v[0])
	return st.commit()


## XY düzleminde halka (normal +Z), UV.x çevre, UV.y iç→dış
static func _ring_mesh(inner: float, outer: float, seg := 48) -> ArrayMesh:
	var key = "ring_%.3f_%.3f_%d" % [inner, outer, seg]
	if _meshes.has(key):
		return _meshes[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 = TAU * i / seg
		var a1 = TAU * (i + 1) / seg
		var p = [Vector3(cos(a0), sin(a0), 0) * inner, Vector3(cos(a1), sin(a1), 0) * inner, Vector3(cos(a1), sin(a1), 0) * outer, Vector3(cos(a0), sin(a0), 0) * outer]
		var uv = [Vector2(float(i) / seg, 0), Vector2(float(i + 1) / seg, 0), Vector2(float(i + 1) / seg, 1), Vector2(float(i) / seg, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.BACK)
			st.set_uv(uv[k])
			st.set_color(Color.WHITE)
			st.add_vertex(p[k])
	var m = st.commit()
	_meshes[key] = m
	return m


## Alev dili: tabanı yuvarlak, yukarı (0..1) incelen ve öne kıvrılan koni
static func _tongue_mesh() -> ArrayMesh:
	if _meshes.has("tongue"):
		return _meshes["tongue"]
	var pts = []
	var radii = []
	for i in 9:
		var f = i / 8.0
		pts.append(Vector3(0, f, sin(f * PI * 0.5) * 0.25))
		radii.append(0.22 * (1.0 - f) * (0.6 + 0.4 * sin(f * PI + 0.4)) + 0.005)
	var m = _tube_mesh(pts, radii, 7)
	_meshes["tongue"] = m
	return m


## Kameraya dönük çapraz iki dörtgen: d boyunca uzanan hız izi; ileri kayar ve söner
static func _streak(pj: PathJutsu, from: Vector3, d: Vector3, L: float, w: float, col: Color, life: float, add := true, travel := 0.6) -> void:
	var root = Node3D.new()
	var m = _streak_mat(col, add)
	for k in 2:
		var q = QuadMesh.new()
		q.size = Vector2(L, w)
		q.center_offset = Vector3(L * 0.5, 0, 0)
		var mi = _mi(q, m)
		mi.rotation.x = k * PI * 0.5
		root.add_child(mi)
	_put(pj, root, from)
	# yerel +X = kuyruk (UV.x 0 baş → 1 kuyruk): baş öne (d), kuyruk geride
	var x = -d.normalized()
	var yv = _perp(d)[0]
	root.global_transform.basis = Basis(x, yv, x.cross(yv).normalized())
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", from + d.normalized() * L * travel, life).set_ease(Tween.EASE_OUT)
	_fade(root, m, life * 0.4, life * 0.6)


## Çizgi roman darbe yıldızı (kameraya dönük)
static func _star(pj: PathJutsu, at: Vector3, s: float, col := Color(1.0, 0.8, 0.35), life := 0.22) -> void:
	var q = QuadMesh.new()
	q.size = Vector2.ONE
	var m = _mat("star", STAR_SH % [NOISE, BILL], {"col": col, "seed": randf() * 20.0})
	var mi = _mi(q, m)
	_put(pj, mi, at)
	mi.scale = Vector3.ONE * s * 0.3
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * s * 1.25, 0.08).set_ease(Tween.EASE_OUT)
	_fade(mi, m, 0.08, life)


## Toz topağı (cel, konturlu): yere yakın, dışa ve yukarı kabarıp sönen kıvrık toz — duman değil, ayak altı kalkan toprak
static func _dust_clump(pj: PathJutsu, at: Vector3, out: Vector3, s: float, life := 0.6) -> void:
	if not _meshes.has("dust"):
		var b = MB.new()
		b.add("sphere", Vector3(0, 0.0, 0), Vector3(1.0, 0.7, 1.0), DUST, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.35, 0.15, 0.1), Vector3(0.7, 0.55, 0.7), DUST.lightened(0.08), Vector3.ZERO, 8)
		b.add("sphere", Vector3(-0.3, 0.12, -0.15), Vector3(0.65, 0.5, 0.65), DUST.darkened(0.06), Vector3.ZERO, 8)
		_meshes["dust"] = b.build()
	var mi = _mi(_meshes["dust"], cel(Color.WHITE, 0.03))
	_put(pj, mi, at)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3.ONE * s * 0.25
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", at + out * s * 1.2 + Vector3.UP * s * 0.3, life).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(mi, "scale", Vector3.ONE * 0.02, life * 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Yerden fırlayan taş parçaları
static func _rubble(pj: PathJutsu, at: Vector3, n: int, spd: float, size := 0.14) -> void:
	for i in n:
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(size, size * 0.7, size * 0.9) * randf_range(0.6, 1.3), ROCK.lerp(DUST, randf() * 0.4), Vector3(randf() * 90, randf() * 90, 0))
		var mi = _mi(b.build(), cel(Color.WHITE, 0.012))
		_put(pj, mi, at)
		var a = randf() * TAU
		_toss(mi, at, Vector3(cos(a), randf_range(0.8, 1.6), sin(a)) * spd * randf_range(0.5, 1.0), randf_range(0.6, 1.0), Vector3(randf() * 12, randf() * 12, 0))


# ================================================================== Sumigasumi (mürekkep sisi)
## ref: kara fırça kıvrımları gövdeyi sarmal sarar → ağızdan mürekkep fışkırır → önde mürekkep sisi; yerde leke
static func sumigasumi_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	_ink_coil(pj, c, 0.8)
	for k in 5:
		pj.after(k * 0.07, func():
			if pj.live(c):
				_ink_jet(pj, pj._mouth_pos(c) + d * (1.0 + k * 1.5), d, k))
	# c_sumigasumi_no_jutsu (taşındı)
	var center = c.global_position + d * 7.0
	_ink_cloud(pj, center, 7.0, 6.0)
	pj.every(6.0, 0.5, func(_i, _k):
		if not is_instance_valid(c):
			return
		for e in pj.enemies_near(c, center, 7.0):
			pj.st(e, "slow", 0.6)
			if e.has_method("lose_target"):
				e.lose_target(0.6))
	Sfx.play("wind", c.global_position, 0.7)


static func _ink_coil(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var root = Node3D.new()
	c.add_child(root)
	root.position = Vector3.ZERO
	var m = _mat("stroke", STROKE_SH % NOISE, {"ink_col": INK, "reveal": 0.0})
	for k in 3:
		var pts = []
		var ups = []
		var ws = []
		var turns = 2.2 + k * 0.3
		var ph = k * TAU / 3.0
		for i in 48:
			var f = i / 47.0
			var a = ph + f * TAU * turns
			var rr = 0.5 + 0.12 * sin(f * 9.0 + k)
			pts.append(Vector3(cos(a) * rr, 0.1 + f * 2.0, sin(a) * rr))
			ups.append(Vector3(0, 1, 0).rotated(Vector3(cos(a), 0, sin(a)), 0.5))
			ws.append(0.16 + 0.06 * sin(f * 14.0))
		root.add_child(_mi(_strip_mesh(pts, ups, ws), m))
	_param(root, m, "reveal", 0.0, 1.0, dur * 0.4)
	var tw = root.create_tween().set_parallel(true)
	tw.tween_property(root, "rotation:y", TAU * 1.5, dur)
	tw.tween_property(root, "scale", Vector3(1.8, 1.15, 1.8), dur).set_ease(Tween.EASE_IN)
	_param(root, m, "tail", 0.0, 1.0, dur * 0.5, dur * 0.5)
	pj.free_after(dur + 0.05, root)


static func _ink_jet(pj: PathJutsu, at: Vector3, d: Vector3, k: int) -> void:
	_spray(pj, at, {"n": 14, "life": 1.3, "dir": d, "spread": 40.0, "vmin": 1.0, "vmax": 3.0, "grav": Vector3(0, -0.4, 0), "drag": 1.0,
		"smin": 0.7 + k * 0.15, "smax": 1.3 + k * 0.2, "grow": [0.5, 1.0], "r": 0.4 + k * 0.25, "shape": 2,
		"cols": [Color(INK, 0.95), Color(INK, 0.85), Color(INK, 0.0)]})
	_spray(pj, at, {"n": 10, "life": 0.9, "dir": d + Vector3.UP * 0.3, "spread": 30.0, "vmin": 4.0, "vmax": 8.0, "smin": 0.07, "smax": 0.14,
		"grow": [1.0, 0.6], "shape": 1, "cols": [Color(INK, 1.0), Color(INK, 0.0)]})


static func _ink_cloud(pj: PathJutsu, center: Vector3, r: float, dur: float) -> void:
	var root = Node3D.new()
	_put(pj, root, center)
	var m = _mat("cloud", CLOUD_SH % [NOISE, BILL], {"ink_col": INK, "amount": 0.0})
	var q = QuadMesh.new()
	q.size = Vector2.ONE
	for i in 26:
		var a = randf() * TAU
		var rr = sqrt(randf()) * r * 0.85
		var mi = _mi(q, m)
		root.add_child(mi)
		var p = Vector3(cos(a) * rr, randf_range(0.6, 3.2), sin(a) * rr)
		mi.position = p * 0.3
		var s = randf_range(3.0, 5.5)
		mi.scale = Vector3.ONE * s * 0.3
		var tw = mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position", p, randf_range(0.6, 1.2)).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * s, randf_range(0.6, 1.2)).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(mi, "position", p + Vector3(randf_range(-0.8, 0.8), randf_range(-0.2, 0.4), randf_range(-0.8, 0.8)), dur - 1.0)
	_param(root, m, "amount", 0.0, 1.0, 0.5)
	_fade(root, m, dur - 1.0, 1.0)
	_decal(pj, center, r, 0, Color(INK, 0.92), dur + 2.0, 1.5)


# ================================================================== Hiruma (sülük + sümük)
## ref: kara-mor sülük bej sümük ipinde kayıp hedefe yapışır; delikli sümük zarı hedefi sarar, damlar, yerde göl
static func hiruma(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.6)
	var from = pj._mouth_pos(c)
	var to = (tt.global_position + Vector3.UP if tt else from + c.face_dir() * 8.0)
	var curve = _slime_rope(pj, from, to)
	_leech_ride(pj, curve, tt)
	if tt:
		pj.after(0.25, func():
			if pj.live(tt):
				pj.st(tt, "slow", 5.0)
				pj.st(tt, "bind", 1.0)
				tt.take_hit(pj.inf(c, "hiruma", 0.3, {"knock": 0.0, "kind": "light"}))
				Combat.popup_text(tt.global_position + Vector3.UP * 2.3, "Yapıştı!", Color(0.85, 0.8, 0.6))
				_slime_coat(pj, tt, 5.0))
	else:
		pj.after(0.25, func():
			_decal(pj, to, 1.3, 1, Color(SLIME, 0.9), 3.0)
			_slime_drops(pj, to, 8))
	Sfx.play("water", from, 0.9)


## Ağızdan hedefe sarkık sümük ipi; eğri noktalarını döndürür
static func _slime_rope(pj: PathJutsu, from: Vector3, to: Vector3) -> Array:
	var pts = []
	var radii = []
	var n = 16
	for i in n:
		var f = float(i) / (n - 1)
		pts.append(from.lerp(to, f) + Vector3.DOWN * 0.6 * 4.0 * f * (1.0 - f))
		radii.append(0.07 + 0.06 * sin(f * PI) + 0.025 * sin(f * 23.0))
	var m = _mat("slime", SLIME_SH % NOISE, {"col": SLIME, "reveal": 0.0})
	var mi = _mi(_tube_mesh(pts, radii, 7), m)
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	_param(mi, m, "reveal", 0.0, 1.0, 0.25)
	var tw = mi.create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(mi, "position", Vector3.DOWN * 0.7, 0.45).set_ease(Tween.EASE_IN)
	_fade(mi, m, 0.5, 0.4)
	return pts


static func _leech_mesh() -> ArrayMesh:
	if _meshes.has("leech"):
		return _meshes["leech"]
	var b = MB.new()
	for i in 6:
		var f = i / 5.0
		var s = 0.1 + 0.05 * sin(f * PI)
		b.add("sphere", Vector3(0, sin(f * 5.0) * 0.02, -f * 0.32), Vector3(s, s * 0.85, s * 1.2), LEECH, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0.035, 0.035, 0.05), Vector3(0.03, 0.025, 0.02), Color(0.95, 0.95, 0.9))
	b.add("sphere", Vector3(-0.035, 0.035, 0.05), Vector3(0.03, 0.025, 0.02), Color(0.95, 0.95, 0.9))
	b.add("box", Vector3(0, -0.01, 0.075), Vector3(0.06, 0.012, 0.01), Color(0.95, 0.95, 0.9))
	var m = b.build()
	_meshes["leech"] = m
	return m


static func _leech_ride(pj: PathJutsu, curve: Array, tt: Node3D) -> void:
	var mi = _mi(_leech_mesh(), cel(Color.WHITE, 0.012, 0.0, FLAME, 0.0, 1.4))
	var root = Node3D.new()
	root.add_child(mi)
	_put(pj, root, curve[0])
	var n = curve.size()
	var tw = root.create_tween()
	tw.tween_method(func(f: float):
		if not is_instance_valid(root):
			return
		var x = f * (n - 1)
		var i = mini(int(x), n - 2)
		var p: Vector3 = curve[i].lerp(curve[i + 1], x - i) + Vector3.UP * 0.12
		var dir: Vector3 = curve[i + 1] - curve[i]
		root.global_position = p
		if dir.length() > 0.01:
			root.global_transform.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
		mi.rotation.y = sin(f * 30.0) * 0.4, 0.0, 1.0, 0.25)
	if tt == null:
		_shrink(root, 0.25, 0.2)
		return
	# hedefe yapışır: bağlı kaldığı süre göğsünde kıvranır
	tw.tween_callback(func():
		pj.every(1.0, 1.0 / 30.0, func(_i, k):
			if is_instance_valid(root) and is_instance_valid(tt):
				var to_c = _cam(pj, tt.global_position) - tt.global_position
				to_c.y = 0.0
				root.global_position = tt.global_position + Vector3.UP * 1.25 + to_c.normalized() * 0.32
				mi.rotation = Vector3(sin(k * 40.0) * 0.3, sin(k * 25.0) * 0.5, 0), func():
			if is_instance_valid(root):
				_shrink(root, 0.0, 0.25)))


## Hedefi saran delikli sümük zarı (hedefe bağlı), damlalar, ayak altında göl
static func _slime_coat(pj: PathJutsu, tt: Node3D, dur: float) -> void:
	var root = Node3D.new()
	tt.add_child(root)
	var h = float(tt.get("height")) if tt.get("height") != null else 1.8
	var m = _mat("slime", SLIME_SH % NOISE, {"col": SLIME, "web": 1.0})
	for k in 4:
		var a = k * TAU / 4.0 + randf() * 0.4
		var pts = []
		var radii = []
		var top = Vector3(cos(a) * 0.25, h * 0.7, sin(a) * 0.25)
		var bot = Vector3(cos(a + 0.5) * 0.75, 0.02, sin(a + 0.5) * 0.75)
		for i in 8:
			var f = i / 7.0
			pts.append(top.lerp(bot, f) + Vector3(cos(a), 0, sin(a)) * 0.15 * sin(f * PI))
			radii.append(0.05 + 0.04 * sin(f * PI))
		var st = _mi(_tube_mesh(pts, radii, 5), m)
		root.add_child(st)
	# zar perdeleri (delikli): gövdenin iki yanında
	for k in 2:
		var pm = QuadMesh.new()
		pm.size = Vector2(0.9, h * 0.75)
		var web = _mi(pm, m)
		root.add_child(web)
		web.position = Vector3(0, h * 0.42, 0)
		web.rotation.y = k * PI * 0.5 + 0.4
	# bağ süresi: bacaklarda iki kalın halka
	for k in 2:
		var ring = _mi(_tube_mesh(_circle_pts(0.36, 14, 0.25 + k * 0.35), _const_arr(15, 0.06), 5), m)
		root.add_child(ring)
		_shrink(ring, 1.0, 0.25)
	_decal(pj, tt.global_position, 1.5, 1, Color(SLIME, 0.92), dur, 1.0)
	for k in 6:
		pj.after(0.3 + k * 0.6, func():
			if is_instance_valid(tt):
				_slime_drops(pj, tt.global_position + Vector3(randf_range(-0.4, 0.4), h * 0.5, randf_range(-0.4, 0.4)), 2))
	_fade(root, m, dur - 0.8, 0.8)


static func _circle_pts(r: float, n: int, y: float) -> Array:
	var out = []
	for i in n + 1:
		var a = TAU * i / n
		out.append(Vector3(cos(a) * r, y, sin(a) * r))
	return out


static func _const_arr(n: int, v: float) -> Array:
	var out = []
	for i in n:
		out.append(v)
	return out


static func _slime_drops(pj: PathJutsu, at: Vector3, n: int) -> void:
	_spray(pj, at, {"n": n, "life": 0.7, "dir": Vector3.DOWN, "spread": 25.0, "vmin": 0.5, "vmax": 2.0, "smin": 0.08, "smax": 0.15,
		"grow": [0.7, 1.0], "shape": 1, "burst": 0.4, "cols": [Color(SLIME, 1.0), Color(SLIME, 0.8)]})


# ================================================================== Sōshūjin (iplerle yönlenen kunai)
## ref: sekiz kunai havada açılır, parmaklardan ince chakra ipleriyle bağlı; ipler fırlatınca da bağlı kalır (yön çevirir)
static func soshujin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.8)
	pj.anim(c, "cast", 1.3)
	var knives = []
	for k in 8:
		var kn = _kunai()
		pj.get_tree().current_scene.add_child(kn)
		var a = TAU * k / 8.0
		var q = c.global_position + Vector3(cos(a) * 1.6, 1.0 + sin(a * 2.0) * 0.4, sin(a) * 1.6)
		kn.global_position = c.global_position + Vector3.UP
		kn.create_tween().tween_property(kn, "global_position", q, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		knives.append(kn)
		var side = k % 2 == 0
		_wire(pj, func(): return pj.hand_pos(c, side) if pj.live(c) else Vector3.ZERO,
			func(): return kn.global_position if is_instance_valid(kn) else Vector3.ZERO, 0.55, Color(0.75, 0.88, 1.0, 0.8), 0.014, 0.05)
		pj.after(0.3, func():
			if is_instance_valid(kn):
				_glint(pj, kn.global_position))
	# havada asılı kunai uçları hedefe döner, hafifçe salınır
	pj.every(0.55, 1.0 / 30.0, func(i, _k):
		for n in knives.size():
			var kn = knives[n]
			if not is_instance_valid(kn):
				continue
			var aim = (tt.global_position + Vector3.UP if is_instance_valid(tt) else kn.global_position + c.face_dir() * 5.0 if is_instance_valid(c) else kn.global_position + Vector3.FORWARD)
			var dv = aim - kn.global_position
			if dv.length() > 0.1:
				kn.global_transform.basis = Basis.looking_at(dv.normalized(), Vector3.UP).rotated(dv.normalized(), sin(i * 0.4 + n) * 0.4))
	pj.after(0.55, func():
		for kn in knives:
			if not is_instance_valid(kn):
				continue
			var from = kn.global_position
			kn.queue_free()
			if pj.live(c):
				var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 34.0, _kunai(), pj.inf(c, "soshujin", 0.22, {"knock": 1.0, "kind": "light", "bleed": 2.0}), tt, false, 1.4, func(p, _h):
					_steel_hit(pj, p))
				pr.homing_turn = 7.0
				_tail(pr, Color(0.85, 0.92, 1.0, 0.85), 1.4, 0.07)
				var side = randf() < 0.5
				_wire(pj, func(): return pj.hand_pos(c, side) if pj.live(c) else Vector3.ZERO,
					func(): return pr.global_position if is_instance_valid(pr) else Vector3.ZERO, 0.5, Color(0.75, 0.88, 1.0, 0.7), 0.012))
	Sfx.play("kunai", c.global_position, 1.4)


## Kunai (uç -Z): yaprak bıçak, sargılı sap, halka; cel + kontur
static func _kunai() -> Node3D:
	if not _meshes.has("kunai"):
		var b = MB.new()
		var blade = PackedVector2Array([Vector2(0, -0.34), Vector2(0.05, -0.17), Vector2(0.035, -0.05), Vector2(-0.035, -0.05), Vector2(-0.05, -0.17)])
		b.add_slab(blade, 0.016, STEEL, Transform3D.IDENTITY, Callable(), STEEL.lightened(0.35))
		b.add("box", Vector3(0, 0, -0.19), Vector3(0.02, 0.005, 0.26), STEEL.lightened(0.25))
		b.add("cyl", Vector3(0, 0, 0.04), Vector3(0.028, 0.18, 0.028), STEEL_D, Vector3(90, 0, 0), 6)
		for i in 4:
			b.add("cyl", Vector3(0, 0, -0.03 + i * 0.045), Vector3(0.033, 0.012, 0.033), Color(0.32, 0.26, 0.22), Vector3(90, 0, 0), 6)
		b.add("torus", Vector3(0, 0, 0.165), Vector3(0.11, 0.11, 0.11), STEEL_D, Vector3(0, 0, 90), 10)
		_meshes["kunai"] = b.build()
	var root = Node3D.new()
	root.add_child(_mi(_meshes["kunai"], cel(Color.WHITE, 0.006)))
	return root


## Mermi kuyruğu: merminin ardında kameraya dönük çapraz hız izi (mermiyle birlikte silinir)
static func _tail(pr: Node3D, col: Color, L: float, w: float) -> void:
	var m = _streak_mat(col, true)
	for k in 2:
		var q = QuadMesh.new()
		q.size = Vector2(L, w)
		q.center_offset = Vector3(L * 0.5, 0, 0)
		var mi = _mi(q, m)
		pr.add_child(mi)
		# +X yerel → +Z (geride): UV.x 0 mermide, 1 kuyrukta
		mi.rotation = Vector3(k * PI * 0.5, -PI * 0.5, 0)


static func _glint(pj: PathJutsu, at: Vector3) -> void:
	_spray(pj, at, {"n": 3, "life": 0.25, "vmin": 0.0, "vmax": 0.1, "grav": Vector3.ZERO, "smin": 0.35, "smax": 0.5, "grow": [0.3, 1.0], "add": true,
		"cols": [Color(1, 1, 1, 1), Color(0.8, 0.9, 1.0, 0)]})


static func _steel_hit(pj: PathJutsu, p: Vector3) -> void:
	for k in 5:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		_streak(pj, p, dv, 0.45, 0.03, Color(1.0, 0.95, 0.8), 0.15, true, 1.0)
	_spray(pj, p, {"n": 8, "life": 0.35, "spread": 180.0, "vmin": 3.0, "vmax": 6.0, "smin": 0.05, "smax": 0.09, "add": true,
		"cols": [Color(1, 0.95, 0.75, 1), Color(1, 0.6, 0.2, 0)]})


# ================================================================== Sōfūshasan no Tachi (iplere bağlı üç Fūma)
## ref: hız çizgileri; üç dev şuriken iplerle hedefin çevresinde daralarak döner, teller hedefe dolanır,
## sonunda ipler boyunca ateş akar (Ryūka — burn) ve teller sıkılır
static func sofushasan_no_tachi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt24 = pj.tg(c, t, 24.0)
	# c_sofushasan_no_tachi (taşındı)
	var tt = pj.tg(c, t, 22.0)
	if tt == null:
		return
	var sh = []
	var tails = []
	for k in 3:
		var s = _fuma(0.6)
		pj.get_tree().current_scene.add_child(s)
		s.global_position = pj.hand_pos(c, true)
		sh.append(s)
		var idx = k
		_wire(pj, func(): return pj.hand_pos(c, true) if is_instance_valid(c) else Vector3.ZERO,
			func(): return sh[idx].global_position if is_instance_valid(sh[idx]) else Vector3.ZERO, 2.0, Color(0.88, 0.9, 0.96, 0.9), 0.022, 0.0, false)
		tails.append({"prev": s.global_position})
	pj.st(tt, "bind", 2.6)
	var coil = _wire_coil(pj, tt)
	var fired = {"v": false}
	pj.every(2.0, 1.0 / 30.0, func(i, k):
		for n in sh.size():
			if not is_instance_valid(sh[n]):
				continue
			var a = i * 0.35 + n * TAU / 3.0
			var r = lerpf(6.0, 0.9, minf(1.0, k * 1.6))
			sh[n].global_position = tt.global_position + Vector3(cos(a) * r, 1.0 + n * 0.3, sin(a) * r) if pj.live(tt) else sh[n].global_position
			sh[n].rotation.y += 0.6
			var mv: Vector3 = sh[n].global_position - tails[n]["prev"]
			if i % 3 == 0 and mv.length() > 0.15:
				_streak(pj, sh[n].global_position, -mv.normalized(), minf(2.4, mv.length() * 4.0), 0.06, Color(1, 1, 1, 0.8), 0.18, true, 0.0)
			tails[n]["prev"] = sh[n].global_position
		if is_instance_valid(coil):
			var tight = clampf((k - 0.35) / 0.5, 0.0, 1.0)
			coil.visible = tight > 0.0
			coil.scale = Vector3(lerpf(1.8, 1.0, tight), lerpf(0.2, 1.0, tight), lerpf(1.8, 1.0, tight))
		if k >= 0.85 and not fired["v"]:
			fired["v"] = true
			if pj.live(c) and pj.live(tt):
				_wire_fire(pj, c, tt, coil if is_instance_valid(coil) else null), func():
		for s in sh:
			if is_instance_valid(s):
				_steel_hit(pj, s.global_position)
				s.queue_free()
		if is_instance_valid(coil):
			_shrink(coil, 0.6, 0.3)
		if pj.live(tt):
			pj.hit(c, tt.global_position + Vector3.UP, 1.3, pj.inf(c, "sofushasan_no_tachi", 1.6, {"knock": 2.0, "kind": "heavy", "burn": 2.0}))
			Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Teller sıkıldı!", Color(0.9, 0.9, 1)))
	Sfx.play("kunai", c.global_position, 0.8)
	# p_ eki: elden hedefe üç gergin tel
	if tt24:
		for k in 3:
			pj.after(0.1 + k * 0.08, func():
				if pj.live(c) and pj.live(tt24):
					_wire(pj, func(): return pj.hand_pos(c, true) if is_instance_valid(c) else Vector3.ZERO,
						func(): return tt24.global_position + Vector3.UP * (0.6 + k * 0.4) if is_instance_valid(tt24) else Vector3.ZERO, 1.6, Color(0.92, 0.94, 1.0, 0.9), 0.016))


## Fūma şuriken (yatay): dört kavisli kanat, göbek, delik halkası
static func _fuma(s: float) -> Node3D:
	if not _meshes.has("fuma"):
		var b = MB.new()
		var wing = PackedVector2Array([Vector2(0.06, -0.05), Vector2(0.2, -0.08), Vector2(0.38, -0.02), Vector2(0.52, 0.16), Vector2(0.36, 0.06), Vector2(0.2, 0.06), Vector2(0.07, 0.07)])
		for k in 4:
			var xf = Transform3D(Basis(Vector3.UP, k * PI * 0.5) * Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO)
			b.add_slab(wing, 0.035, STEEL, xf, Callable(), STEEL.lightened(0.3))
		b.add("cyl", Vector3.ZERO, Vector3(0.18, 0.06, 0.18), STEEL_D, Vector3.ZERO, 12)
		b.add("torus", Vector3(0, 0.035, 0), Vector3(0.12, 0.12, 0.12), STEEL.darkened(0.3), Vector3.ZERO, 12)
		_meshes["fuma"] = b.build()
	var root = Node3D.new()
	var mi = _mi(_meshes["fuma"], cel(Color.WHITE, 0.01))
	mi.scale = Vector3.ONE * s * 2.0
	root.add_child(mi)
	return root


## Hedefe dolanan tel sarmalı (hedefe bağlı; daraldıkça görünür)
static func _wire_coil(pj: PathJutsu, tt: Node3D) -> Node3D:
	var pts = []
	for i in 60:
		var f = i / 59.0
		var a = f * TAU * 5.0
		pts.append(Vector3(cos(a) * 0.45, 0.35 + f * 1.3, sin(a) * 0.45))
	var root = Node3D.new()
	root.add_child(_mi(_tube_mesh(pts, _const_arr(60, 0.018), 4), cel(Color(0.85, 0.87, 0.92), 0.0, 0.0)))
	tt.add_child(root)
	root.visible = false
	return root


## Ryūka: ateş üç tel boyunca elden hedefe akar, sarmal kızarır
static func _wire_fire(pj: PathJutsu, c: Node3D, tt: Node3D, coil: Node3D) -> void:
	if not (pj.live(c) and pj.live(tt)):
		return
	for k in 3:
		var bead = _mi(_tongue_mesh(), energy(FLAME, Color(1.0, 0.95, 0.6), false, 4.0, 1.4, 1.0))
		var from = pj.hand_pos(c, true)
		_put(pj, bead, from)
		bead.scale = Vector3.ONE * 0.9
		var tw = bead.create_tween()
		tw.tween_method(func(f: float):
			if is_instance_valid(bead) and is_instance_valid(tt) and is_instance_valid(c):
				var a = pj.hand_pos(c, true)
				var b = tt.global_position + Vector3.UP * (0.6 + k * 0.4)
				bead.global_position = a.lerp(b, f)
				if int(f * 20.0) % 3 == 0:
					_spray(pj, bead.global_position, {"n": 2, "life": 0.35, "vmin": 0.3, "vmax": 1.0, "grav": Vector3(0, 2, 0), "smin": 0.15, "smax": 0.25,
						"add": true, "cols": [Color(1, 0.8, 0.3, 1), Color(1, 0.35, 0.05, 0)]}), 0.0, 1.0, 0.28)
		tw.tween_callback(bead.queue_free)
	if is_instance_valid(coil):
		var fm = energy(FLAME, Color(1.0, 0.9, 0.5), true, 5.0)
		for ch in coil.get_children():
			if ch is MeshInstance3D:
				var glow = _mi(ch.mesh, fm)
				coil.add_child(glow)
				glow.scale = Vector3(1.6, 1.0, 1.6)
		pj.after(0.3, func():
			if is_instance_valid(tt):
				_spray(pj, tt.global_position + Vector3.UP, {"n": 24, "life": 0.6, "spread": 180.0, "vmin": 1.0, "vmax": 3.0, "grav": Vector3(0, 3, 0),
					"smin": 0.2, "smax": 0.4, "add": true, "box": Vector3(0.4, 0.7, 0.4), "cols": [Color(1, 0.85, 0.4, 1), Color(1, 0.4, 0.05, 0.6), Color(0.6, 0.1, 0.0, 0)]}))


# ================================================================== Sennō Sōsa (hafıza mühürleme)
## ref: hedefin başında parlayan "封" mühür yazısı, sekiz yönde ışıyan karalanmış yazı şeritleri; sonda yazılar mühre
## çekilir, mühür başa gömülür
static func senno_sosa_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.7)
	if tt == null:
		return
	_seal_glyph(pj, c, tt, 2.5)
	pj.st(tt, "stun", 2.5)
	if tt.has_method("lose_target"):
		tt.lose_target(5.0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Hafızası silindi!", SCRIPT)
	Sfx.play("genjutsu", tt.global_position, 1.2)


static func _fuin_mesh() -> ArrayMesh:
	if _meshes.has("fuin"):
		return _meshes["fuin"]
	var b = MB.new()
	# [x0, x1, y0, y1] 1×1 kutuda: sol 圭 (iki 土), sağ 寸
	var strokes = [[0.08, 0.42, 0.75, 0.81], [0.22, 0.28, 0.6, 0.94], [0.04, 0.46, 0.57, 0.63],
		[0.08, 0.42, 0.37, 0.43], [0.22, 0.28, 0.16, 0.52], [0.02, 0.48, 0.13, 0.19],
		[0.5, 0.98, 0.65, 0.71], [0.79, 0.85, 0.08, 0.9], [0.7, 0.82, 0.07, 0.13]]
	for s in strokes:
		var cx = (s[0] + s[1]) * 0.5 - 0.5
		var cy = (s[2] + s[3]) * 0.5 - 0.5
		b.add("box", Vector3(cx, cy, 0), Vector3(s[1] - s[0], s[3] - s[2], 0.02), Color.WHITE)
	b.add("box", Vector3(0.13, -0.04, 0), Vector3(0.06, 0.1, 0.02), Color.WHITE, Vector3(0, 0, 35))
	var m = b.build()
	_meshes["fuin"] = m
	return m


static func _seal_glyph(pj: PathJutsu, c: Node3D, tt: Node3D, dur: float) -> void:
	var root = Node3D.new()
	var h = float(tt.get("height")) if tt.get("height") != null else 1.8
	_put(pj, root, tt.global_position + Vector3.UP * (h + 0.35))
	var gm = _mat("glyph", GLYPH_SH % NOISE, {"col": Color(0.95, 0.98, 1.0), "mode": 0})
	var hm = _mat("glyph", GLYPH_SH % NOISE, {"col": Color(0.35, 0.55, 1.0), "mode": 0, "amount": 0.45})
	var glyph = _mi(_fuin_mesh(), gm)
	var halo = _mi(_fuin_mesh(), hm)
	halo.scale = Vector3(1.18, 1.18, 1.0)
	halo.position.z = -0.01
	var gnode = Node3D.new()
	gnode.add_child(halo)
	gnode.add_child(glyph)
	root.add_child(gnode)
	gnode.scale = Vector3.ONE * 0.05
	gnode.create_tween().tween_property(gnode, "scale", Vector3.ONE * 0.55, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sm = _mat("glyph", GLYPH_SH % NOISE, {"col": SCRIPT, "mode": 1})
	var rays = []
	for k in 8:
		var q = QuadMesh.new()
		q.size = Vector2(1.3, 0.16)
		q.center_offset = Vector3(0.65 + 0.32, 0, 0)
		var piv = Node3D.new()
		piv.rotation.z = k * TAU / 8.0 + randf_range(-0.12, 0.12)
		var ray = _mi(q, sm)
		piv.add_child(ray)
		root.add_child(piv)
		piv.scale = Vector3(0.02, 1, 1)
		var tw = piv.create_tween()
		tw.tween_interval(0.08 + k * 0.03)
		tw.tween_property(piv, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_interval(dur - 0.9 - k * 0.03)
		tw.tween_property(piv, "scale", Vector3(0.02, 1, 1), 0.3).set_ease(Tween.EASE_IN)
		rays.append(piv)
	# elden başa ince yazı akımı
	_wire(pj, func(): return pj.hand_pos(c, true) if pj.live(c) else Vector3.ZERO,
		func(): return tt.global_position + Vector3.UP * h if is_instance_valid(tt) else Vector3.ZERO, 0.4, Color(SCRIPT, 0.8), 0.05)
	pj.every(dur, 1.0 / 30.0, func(_i, k):
		if not (is_instance_valid(root) and is_instance_valid(tt)):
			return
		var sink = clampf((k - 0.82) / 0.18, 0.0, 1.0)
		var p = tt.global_position + Vector3.UP * lerpf(h + 0.35, h - 0.15, sink)
		root.global_position = p
		var eye = _cam(pj, p)
		var fwd_v = p - eye
		if fwd_v.length() > 0.1:
			root.global_transform.basis = Basis.looking_at(fwd_v.normalized(), Vector3.UP)
		if sink > 0.0:
			gnode.scale = Vector3.ONE * 0.55 * (1.0 - sink * 0.8), func():
		if is_instance_valid(root):
			_spray(pj, root.global_position, {"n": 14, "life": 0.4, "spread": 180.0, "vmin": 1.0, "vmax": 2.5, "grav": Vector3.ZERO, "smin": 0.08, "smax": 0.16,
				"add": true, "cols": [Color(1, 1, 1, 1), Color(0.5, 0.7, 1.0, 0)]})
			root.queue_free())


# ================================================================== Kyōmen Shūja (ayna yanılsaması)
## Hedefin arkasında yeşil kenarlı oval ayna belirir; içinden kopya çıkar ve ayna kırılıp parçalanır.
## Hedefin gözünde yeşil halka (yanılsama tuttu). Kopya dağılınca cam kırıkları (duman değil).
static func kyomen_shuja_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.5)
	if tt == null:
		return
	var at = tt.global_position + (c.global_position - tt.global_position).normalized() * -2.5
	var d = pj.decoy(c, pj.gp(at), 4.0)
	if d:
		d.set_meta("no_smoke", true)
		_mirror_pane(pj, d.global_position, tt.global_position)
		var scn = pj.get_tree().current_scene
		d.tree_exiting.connect(func():
			if is_instance_valid(d) and is_instance_valid(scn) and scn.is_inside_tree():
				_glass_burst.call_deferred(scn, d.global_position + Vector3.UP, 10, 0.7))
	_eye_ring(pj, tt)
	pj.st(tt, "slow", 4.0)
	if tt.has_method("lose_target"):
		tt.lose_target(3.0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.3, "Yanıldı!", MIRROR)
	Sfx.play("genjutsu", tt.global_position, 1.3)


static func _mirror_pane(pj: PathJutsu, at: Vector3, look: Vector3) -> void:
	var q = QuadMesh.new()
	q.size = Vector2(1.2, 2.2)
	var m = _mat("mirror", MIRROR_SH % NOISE, {"tint": MIRROR})
	var mi = _mi(q, m)
	_put(pj, mi, at + Vector3.UP * 1.1)
	var dv = look - at
	dv.y = 0.0
	if dv.length() > 0.1:
		mi.global_transform.basis = Basis.looking_at(-dv.normalized(), Vector3.UP)
	mi.scale = Vector3(0.05, 1.0, 1.0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_method(func(x: float): m.set_shader_parameter("crack", x), 0.0, 1.0, 0.12)
	tw.tween_callback(func():
		if is_instance_valid(mi):
			_glass_burst(pj.get_tree().current_scene, mi.global_position, 16, 1.0)
			mi.queue_free())
	# kenar parıltısı ve yerde ince yeşil çizgi
	_spray(pj, at + Vector3.UP * 1.1, {"n": 16, "life": 0.5, "box": Vector3(0.5, 1.0, 0.1), "vmin": 0.2, "vmax": 0.6, "grav": Vector3.ZERO,
		"smin": 0.1, "smax": 0.2, "add": true, "cols": [Color(0.8, 1.0, 0.85, 1), Color(MIRROR, 0)]})


## Cam kırıkları: üçgen parçalar dışa savrulur, döner, küçülür (sahne kökü verilir: kopya silinirken de çalışır)
static func _glass_burst(scn: Node, at: Vector3, n: int, s: float) -> void:
	if not is_instance_valid(scn) or not scn.is_inside_tree():
		return
	var m = _mat("mirror", MIRROR_SH % NOISE, {"tint": MIRROR, "oval": 0.0})
	for i in n:
		var b = MB.new()
		var tri = PackedVector2Array([Vector2(0, 0.12), Vector2(0.09, -0.07), Vector2(-0.08, -0.05)])
		b.add_slab(tri, 0.01, Color.WHITE)
		var mi = _mi(b.build(), m)
		scn.add_child(mi)
		mi.global_position = at
		mi.scale = Vector3.ONE * s * randf_range(0.7, 1.5)
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.4, 1.0), randf_range(-1, 1)).normalized()
		_toss(mi, at + dv * 0.2, dv * randf_range(2.0, 4.5), randf_range(0.5, 0.8), Vector3(randf() * 14, randf() * 14, randf() * 14))


static func _eye_ring(pj: PathJutsu, tt: Node3D) -> void:
	var h = float(tt.get("height")) if tt.get("height") != null else 1.8
	var m = _mat("ring", RING_SH % NOISE, {"col": MIRROR})
	var mi = _mi(_ring_mesh(0.92, 1.0), m)
	tt.add_child(mi)
	mi.position = Vector3.UP * (h * 0.92)
	mi.rotation.x = PI * 0.5
	mi.scale = Vector3.ONE * 0.2
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.9, 0.45).set_ease(Tween.EASE_OUT)
	_fade(mi, m, 0.2, 0.35)


# ================================================================== Uzumaki Naruto Rendan (klon kombosu)
## ref: klonlar yerden toz kaldırarak çevreler, alttan tekmeyle havaya; havada üç darbe; tepeden topuk iner → çatlak + toz halkası
static func uzumaki_naruto_rendan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	pj.busy(c, 1.6)
	if tt == null:
		return
	var at = tt.global_position
	var clones = []
	for k in 4:
		var a = k * TAU / 4.0
		var q = pj.gp(at + Vector3(cos(a), 0, sin(a)) * 1.6)
		_skid(pj, q, Vector3(cos(a), 0, sin(a)))
		clones.append(pj.decoy(c, q, 1.8))
	tt.take_hit(pj.inf(c, "uzumaki_naruto_rendan", 0.4, {"knock": 0.0, "launch": 14.0, "kind": "heavy"}))
	_launch_hit(pj, tt.global_position + Vector3.UP * 0.6)
	for k in 3:
		pj.after(0.3 + k * 0.15, func():
			if pj.live(tt):
				_air_hit(pj, tt.global_position + Vector3.UP, k)
				tt.take_hit(pj.inf(c, "uzumaki_naruto_rendan", 0.3, {"knock": 0.0, "launch": 3.0, "kind": "light"}))
				Sfx.play("punch", tt.global_position, 1.1 + k * 0.1))
	pj.after(0.85, func():
		if not pj.live(c):
			return
		c.global_position = tt.global_position + Vector3.UP * 1.2 if pj.live(tt) else c.global_position
		pj._kick_pose(c, 0.3)
		Combat.popup_text(c.global_position + Vector3.UP * 2.0, "Uzumaki Naruto Rendan!", Color(1, 0.6, 0.2))
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "uzumaki_naruto_rendan", 1.2, {"knock": 4.0, "launch": -22.0, "kind": "heavy"}))
			for k in 7:
				var off = Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.0), randf_range(-0.6, 0.6))
				_streak(pj, c.global_position + off + Vector3.UP * 0.8, Vector3.DOWN, 2.2, 0.06, Color(1, 1, 1, 0.9), 0.25, true, 0.8)
			pj.after(0.3, func():
				if pj.live(tt):
					_slam_crater(pj, tt.global_position)
					pj.shake(0.6)))


## Klon inişi: kayarak duran ayakların önünde yassı toz kabarması + çakıl
static func _skid(pj: PathJutsu, q: Vector3, out: Vector3) -> void:
	for k in 3:
		var side = out.cross(Vector3.UP).normalized() * (k - 1) * 0.35
		_dust_clump(pj, q + side + Vector3.UP * 0.15, out, randf_range(0.5, 0.75), 0.55)
	_rubble(pj, q + Vector3.UP * 0.1, 3, 3.0, 0.08)


## Alttan tekme: darbe yıldızı + yukarı fırlayan hız çizgileri
static func _launch_hit(pj: PathJutsu, at: Vector3) -> void:
	_star(pj, at, 1.4)
	for k in 8:
		var off = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		_streak(pj, at + off, Vector3.UP, randf_range(1.6, 2.6), 0.05, Color(1, 1, 1, 0.9), 0.3, true, 1.2)
	_dust_clump(pj, at - Vector3.UP * 0.5, Vector3.ZERO, 0.8, 0.5)


## Havada darbe: dönüşümlü renkli yıldız + dört yöne kısa çizgiler
static func _air_hit(pj: PathJutsu, at: Vector3, k: int) -> void:
	var cols = [Color(1.0, 0.8, 0.35), Color(1.0, 0.62, 0.25), Color(1.0, 0.9, 0.5)]
	_star(pj, at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3)), 0.9 + k * 0.15, cols[k % 3], 0.18)
	for i in 5:
		var dv = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_streak(pj, at, dv, 0.9, 0.04, Color(1, 1, 1, 0.85), 0.14, true, 1.0)


## Topuk inişi: yer çatlağı, dışa yürüyen toz halkası, savrulan taşlar, büyük yıldız
static func _slam_crater(pj: PathJutsu, pos: Vector3) -> void:
	var g = pj.gp(pos)
	_star(pj, g + Vector3.UP * 0.4, 2.2, Color(1.0, 0.75, 0.3), 0.25)
	_decal(pj, g, 2.8, 5, Color(0.12, 0.1, 0.08, 0.95), 4.0, 1.0)
	for k in 12:
		var a = k * TAU / 12.0
		var dv = Vector3(cos(a), 0, sin(a))
		_dust_clump(pj, g + dv * 0.6 + Vector3.UP * 0.2, dv, randf_range(0.7, 1.0), 0.7)
	_rubble(pj, g + Vector3.UP * 0.2, 10, 6.0)


# ================================================================== Kyūbi Chakura Mōdo
## ref: altın parlayan gövde, turuncu alev dilli dış kenar, başta iki alev boynuz; kara mühür desenleri (yaka magatamaları,
## omuz sarmalları, göğüs zinciri, çatal çizgiler, karında sarmal). Dönüşüm: karındaki mühürden dışa yayılan altın,
## yerde altın halka, dışa savrulan alev dilleri. Süre boyunca gövdeden yükselen kıvılcımlar.
static func kyubi_chakura_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	_kcm_ignite(pj, c)
	var parts = _kcm_shroud(pj, c)
	if c is Player:
		Buffs.add("kyubi_chakura", 20.0, {"melee": 1.4, "speed": 1.25, "armor": 0.75, "_name": "Dokuz Kuyruk Çakra Modu", "_desc": "altın çakra örtüsü: hız, güç, dayanıklılık"})
	var em = _spray(pj, c.global_position + Vector3.UP, {"one_shot": false, "n": 26, "life": 0.8, "box": Vector3(0.35, 0.8, 0.25), "dir": Vector3.UP,
		"spread": 20.0, "vmin": 1.2, "vmax": 2.8, "grav": Vector3(0, 1.5, 0), "smin": 0.05, "smax": 0.13, "grow": [1.0, 0.2], "add": true,
		"cols": [Color(1, 0.92, 0.5, 1), Color(1, 0.55, 0.12, 0.8), Color(1, 0.3, 0.05, 0)]}, c)
	em.position = Vector3.UP * 1.0
	parts.append(em)
	pj.every(20.0, 0.25, func(_i, _k):
		pass, func():
		for pp in parts:
			if not is_instance_valid(pp):
				continue
			if pp is CPUParticles3D:
				pp.emitting = false
				pj.free_after(1.0, pp)
			elif pp is MeshInstance3D and pp.material_override is ShaderMaterial:
				_fade(pp, pp.material_override, 0.0, 0.6)
			else:
				_shrink(pp, 0.0, 0.3))
	pj.shake(0.6)
	Sfx.play("roar", c.global_position, 1.1)


static func _kcm_ignite(pj: PathJutsu, c: Node3D) -> void:
	var g = pj.gp(c.global_position)
	var rm = _mat("ring", RING_SH % NOISE, {"col": GOLD})
	var ring = _mi(_ring_mesh(0.9, 1.0), rm)
	_put(pj, ring, g + Vector3.UP * 0.08)
	ring.rotation.x = -PI * 0.5
	ring.scale = Vector3.ONE * 0.6
	ring.create_tween().tween_property(ring, "scale", Vector3.ONE * 7.0, 0.5).set_ease(Tween.EASE_OUT)
	_fade(ring, rm, 0.15, 0.35)
	for k in 14:
		var a = k * TAU / 14.0 + randf() * 0.2
		var dv = Vector3(cos(a), 0, sin(a))
		var tg = _mi(_tongue_mesh(), energy(FLAME, Color(1.0, 0.92, 0.55), false, 4.0, 1.4, 1.0))
		_put(pj, tg, c.global_position + Vector3.UP * 0.4 + dv * 0.3)
		tg.global_transform.basis = Basis(Vector3.UP.cross(dv).normalized(), 0.75)
		tg.scale = Vector3.ONE * 0.3
		var tw = tg.create_tween().set_parallel(true)
		tw.tween_property(tg, "scale", Vector3(1.2, 2.4, 1.2), 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(tg, "global_position", tg.global_position + dv * 1.4 + Vector3.UP * 0.4, 0.45).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(tg, "scale", Vector3(0.1, 0.4, 0.1), 0.2)
		tw.chain().tween_callback(tg.queue_free)
	_spray(pj, c.global_position + Vector3.UP, {"n": 40, "life": 0.9, "spread": 180.0, "vmin": 3.0, "vmax": 8.0, "grav": Vector3(0, 2, 0), "drag": 2.0,
		"smin": 0.08, "smax": 0.18, "add": true, "cols": [Color(1, 0.95, 0.6, 1), Color(1, 0.6, 0.15, 0.8), Color(1, 0.3, 0.05, 0)]})


## Gerçek bedenin derili örgüsünden iki katman (mühürlü altın örtü + alev kenarı) + başta iki alev boynuz
static func _kcm_shroud(pj: PathJutsu, c: Node3D) -> Array:
	var out = []
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or m.get("body_mesh") == null or m.get("skel") == null:
		return out
	var cm = ShaderMaterial.new()
	cm.shader = _sh("kcm", KCM_SH % NOISE)
	cm.set_shader_parameter("reveal", 0.0)
	cm.set_shader_parameter("amount", 1.0)
	var fm = ShaderMaterial.new()
	fm.shader = _sh("kcm_flame", KCM_FLAME_SH % NOISE)
	for mat in [cm, fm]:
		var sk = MeshInstance3D.new()
		sk.mesh = m.body_mesh.mesh
		m.skel.add_child(sk)
		sk.skin = m.body_mesh.skin
		sk.skeleton = sk.get_path_to(m.skel)
		sk.material_override = mat
		sk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(sk)
	_param(out[0], cm, "reveal", 0.0, 2.2, 0.55)
	_param(out[1], fm, "amount", 0.0, 1.0, 0.5, 0.3)
	var hd = pj.bone_attach(c, "Head")
	if hd:
		for sx in [-1.0, 1.0]:
			var hn = _mi(_tongue_mesh(), energy(FLAME, Color(1.0, 0.9, 0.45), false, 5.0, 1.0, 1.0))
			hd.add_child(hn)
			hn.position = Vector3(0.07 * sx, 0.2, -0.02)
			hn.rotation = Vector3(-0.35, 0, -0.35 * sx)
			_pop_in(hn, Vector3(0.35, 0.42, 0.35), 0.35)
		out.append(hd)
	return out


# ================================================================== Kami Bunshin (kâğıt klon)
## ref (Konan): gövdeden kâğıt yapraklar kopar, yanda sarmal sütun olup klona dönüşür; klon vurulunca patlayıcı
## etiketlere açılır — kenarları tutuşur, tek kompakt toon ateş topu, yanan kâğıt kırpıntıları, yerde yanık
static func kami_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var at = pj.gp(c.global_position + c.face_dir().cross(Vector3.UP) * 3.0)
	_paper_peel(pj, c, at)
	Sfx.play("whoosh", c.global_position, 1.6, 0.6)
	pj.after(0.5, func():
		if not pj.live(c):
			return
		var dk = pj.decoy(c, at, 8.0, func(pos):
			_tag_burst(pj, pos)
			pj.hit(c, pos + Vector3.UP, 3.0, pj.inf(c, "kami_bunshin", 0.7, {"knock": 10.0, "kind": "heavy", "element": "katon"})))
		if is_instance_valid(dk):
			dk.set_meta("no_smoke", true)   # kâğıda dağılır (duman değil)
		if c is Player:
			Buffs.add("stealth_kami", 2.5, {"_name": "Kâğıt Klon", "_desc": "düşmanlar klona yöneldi"}))


static func _sheet(m: Material, w := 0.22, h := 0.3) -> MeshInstance3D:
	var pm = PlaneMesh.new()
	pm.size = Vector2(w, h)
	return _mi(pm, m)


static func _paper_peel(pj: PathJutsu, c: Node3D, at: Vector3) -> void:
	var m = _paper_mat()
	for i in 40:
		var sh = _sheet(m)
		var from = c.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 1.7), randf_range(-0.3, 0.3))
		_put(pj, sh, from)
		var ph = randf() * TAU
		var hy = randf_range(0.1, 2.0)
		var mid = from.lerp(at, 0.5) + Vector3.UP * randf_range(1.0, 2.2)
		var spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var delay = randf() * 0.12
		var tw = sh.create_tween()
		tw.tween_interval(delay)
		tw.tween_method(func(f: float):
			if not is_instance_valid(sh):
				return
			var col = at + Vector3(cos(ph + f * 9.0), 0, sin(ph + f * 9.0)) * (0.7 * (1.0 - f * 0.6)) + Vector3.UP * hy
			var p = from.lerp(mid, f).lerp(mid.lerp(col, f), f)
			sh.global_position = p
			sh.rotation = spin * f, 0.0, 1.0, 0.45 - delay)
		tw.tween_property(sh, "global_position", at + Vector3.UP * clampf(hy, 0.3, 1.7), 0.1)
		tw.tween_property(sh, "scale", Vector3.ONE * 0.05, 0.08)
		tw.tween_callback(sh.queue_free)


static func _tag_burst(pj: PathJutsu, pos: Vector3) -> void:
	var c0 = pos + Vector3.UP
	var tm = _paper_mat(1.0)
	for i in 12:
		var sh = _sheet(tm, 0.2, 0.42)
		_put(pj, sh, c0)
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
		sh.global_transform.basis = Basis.looking_at(dv, Vector3.UP if absf(dv.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)
		sh.create_tween().tween_property(sh, "global_position", c0 + dv * 1.1, 0.15).set_ease(Tween.EASE_OUT)
		pj.free_after(0.24, sh)
	_param(pj.get_tree().current_scene, tm, "burn", 0.0, 0.6, 0.2)
	pj.after(0.2, func():
		_fireball(pj, c0, 1.0)
		_decal(pj, pos, 2.4, 2, Color(0.12, 0.09, 0.07, 0.9), 4.0, 1.2)
		var bm = _paper_mat(1.0)
		bm.set_shader_parameter("burn", 0.35)
		for i in 14:
			var sh = _sheet(bm, 0.12, 0.18)
			var dv = Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
			_put(pj, sh, c0)
			_toss(sh, c0, dv * randf_range(4.0, 8.0), randf_range(0.8, 1.3), Vector3(randf() * 15, randf() * 15, randf() * 15), 5.0))


## Kompakt toon ateş topu (üç iç içe pürüzlü küre): şişer, kömürleşir, delik delik dağılır
static func _fireball(pj: PathJutsu, at: Vector3, s: float) -> void:
	for k in 3:
		var sp = SphereMesh.new()
		sp.radius = 1.0
		sp.height = 2.0
		sp.radial_segments = 20
		sp.rings = 10
		var m = _mat("fire", FIRE_SH % NOISE, {"seed": randf() * 30.0})
		var mi = _mi(sp, m)
		var off = Vector3(randf_range(-0.4, 0.4), randf_range(-0.1, 0.5), randf_range(-0.4, 0.4)) * s * (0.0 if k == 0 else 1.0)
		_put(pj, mi, at + off)
		mi.scale = Vector3.ONE * 0.2 * s
		var r = [1.5, 1.1, 0.9][k] * s
		mi.create_tween().tween_property(mi, "scale", Vector3.ONE * r, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_param(mi, m, "heat", 1.0, 0.35, 0.6, 0.15)
		_fade(mi, m, 0.4, 0.45)
	_spray(pj, at, {"n": 30, "life": 0.9, "spread": 180.0, "vmin": 3.0, "vmax": 9.0, "drag": 2.0, "grav": Vector3(0, 1, 0), "smin": 0.08, "smax": 0.18,
		"add": true, "cols": [Color(1, 0.9, 0.5, 1), Color(1, 0.45, 0.1, 0.8), Color(0.5, 0.1, 0.0, 0)]})


# ================================================================== Kami no Shisha no Jutsu (kâğıt deniz)
## ref: kollardan akan kâğıt seli hedef alana dalgalı kâğıt denizi serer, gökten yapraklar yağar; deniz etiket yazılarıyla
## tutuşur ve tek tek yükselen ateş sütunlarıyla patlar (sütun başına kâğıt fıskiyesi + yanık); deniz yanarak söner
static func kami_no_shisha_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.8)
	pj.anim(c, "cast", 0.8)
	var tt = pj.tg(c, t, 40.0)
	var center = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 18.0)
	var sm = _paper_mat()
	sm.set_shader_parameter("wave", 0.12)
	sm.set_shader_parameter("wave_center", center)
	var holder = Node3D.new()
	_put(pj, holder, center)
	for ring in 4:
		_paper_ring(pj, holder, center, ring, sm)
	_param(holder, sm, "ignite", 0.0, 1.0, 0.6, 1.4)
	_param(holder, sm, "burn", 0.0, 1.0, 0.6, 3.0)
	pj.free_after(3.7, holder)
	# kollardan alana kâğıt seli
	var fm = _paper_mat()
	for k in 26:
		pj.after(k * 0.04, func():
			if not pj.live(c):
				return
			var from = pj.hand_pos(c, k % 2 == 0)
			var goal = center + Vector3(randf_range(-9, 9), 0.3, randf_range(-9, 9))
			var sh = _sheet(fm)
			_put(pj, sh, from)
			var mid = from.lerp(goal, 0.5) + Vector3.UP * randf_range(2.0, 4.0)
			var spin = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
			var tw = sh.create_tween()
			tw.tween_method(func(f: float):
				if is_instance_valid(sh):
					sh.global_position = from.lerp(mid, f).lerp(mid.lerp(goal, f), f)
					sh.rotation = spin * f, 0.0, 1.0, 0.9)
			tw.tween_callback(sh.queue_free))
	# gökten yağan yapraklar (sallanarak)
	for k in 80:
		pj.after(randf() * 1.4, func():
			var sh = _sheet(fm, 0.3, 0.42)
			var q = center + Vector3(randf_range(-11, 11), 0, randf_range(-11, 11))
			_put(pj, sh, q + Vector3.UP * randf_range(12, 20))
			var land = pj.gp(q) + Vector3.UP * 0.2
			var top = sh.global_position
			var sway = randf_range(0.6, 1.4)
			var ph = randf() * TAU
			var dur = randf_range(0.8, 1.4)
			var tw2 = sh.create_tween()
			tw2.tween_method(func(f: float):
				if is_instance_valid(sh):
					sh.global_position = top.lerp(land, f) + Vector3(sin(ph + f * 9.0), 0, cos(ph + f * 7.0)) * sway * (1.0 - f)
					sh.rotation = Vector3(sin(ph + f * 11.0) * 0.9, f * 4.0, cos(ph + f * 8.0) * 0.7) * (1.0 - f * 0.8), 0.0, 1.0, dur)
			tw2.tween_interval(0.6)
			tw2.tween_callback(sh.queue_free))
	Sfx.play("wind", center, 0.6)
	for k in 16:
		pj.after(2.0 + k * 0.08, func():
			var q = pj.gp(center + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)))
			_tag_pillar(pj, q)
			if k % 4 == 0:
				pj.shake(1.0)
			pj.hit(c, q + Vector3.UP, 4.5, pj.inf(c, "kami_no_shisha_no_jutsu", 0.55, {"knock": 14.0, "launch": 6.0, "kind": "heavy", "element": "katon"})))


## Kâğıt denizinin bir halkası (MultiMesh yapraklar, yere serili); sırayla dışa açılır
static func _paper_ring(pj: PathJutsu, holder: Node3D, center: Vector3, ring: int, m: Material) -> void:
	var r0 = ring * 3.0
	var r1 = (ring + 1) * 3.0
	var n = int(60 + ring * 80)
	var pm = PlaneMesh.new()
	pm.size = Vector2(0.32, 0.44)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pm
	mm.instance_count = n
	for i in n:
		var a = randf() * TAU
		var rr = sqrt(lerpf(r0 * r0, r1 * r1, randf()))
		var wp = pj.gp(center + Vector3(cos(a) * rr, 0, sin(a) * rr))
		var b = Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, randf_range(-0.35, 0.35)) * Basis.from_scale(Vector3.ONE * randf_range(0.8, 1.3))
		mm.set_instance_transform(i, Transform3D(b, wp - center + Vector3.UP * randf_range(0.05, 0.16)))
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mmi)
	mmi.visible = false
	mmi.scale = Vector3(0.82, 1.0, 0.82)
	var tw = mmi.create_tween()
	tw.tween_interval(ring * 0.2)
	tw.tween_callback(func(): mmi.visible = true)
	tw.tween_property(mmi, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT)


## Tek patlama: yere serili etiketlerden yükselen toon ateş sütunu + kâğıt fıskiyesi + yanık
static func _tag_pillar(pj: PathJutsu, q: Vector3) -> void:
	var cy = CylinderMesh.new()
	cy.top_radius = 0.55
	cy.bottom_radius = 1.0
	cy.height = 1.0
	cy.radial_segments = 14
	cy.rings = 6
	var m = _mat("fire", FIRE_SH % NOISE, {"seed": randf() * 30.0, "bumps": 0.3})
	var mi = _mi(cy, m)
	_put(pj, mi, q)
	mi.scale = Vector3(0.6, 0.2, 0.6)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.5, 5.5, 1.5), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", q + Vector3.UP * 2.75, 0.28).set_ease(Tween.EASE_OUT)
	_param(mi, m, "heat", 1.0, 0.35, 0.5, 0.2)
	_fade(mi, m, 0.35, 0.4)
	var bm = _paper_mat(1.0)
	bm.set_shader_parameter("burn", 0.3)
	for i in 7:
		var sh = _sheet(bm, 0.18, 0.26)
		_put(pj, sh, q + Vector3.UP * 0.3)
		var a = randf() * TAU
		_toss(sh, q + Vector3.UP * 0.3, Vector3(cos(a) * randf_range(1, 3), randf_range(6, 10), sin(a) * randf_range(1, 3)), randf_range(1.0, 1.5), Vector3(randf() * 12, randf() * 12, 0), 7.0)
	_decal(pj, q, 2.0, 2, Color(0.12, 0.09, 0.07, 0.9), 3.5, 1.0)


# ================================================================== Kami Shuriken
## ref (Konan): avuçta yapraklar katlanıp yıldız olur; beş katlı kâğıt yıldız yelpaze gibi açılır, dönerek uçar,
## ardında kâğıt kırpıntıları; değince kırpıntı saçar
static func kami_shuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.45)
	var tt = pj.tg(c, t, 30.0)
	var d = pj.fwd(c, t)
	if tt:
		d = (tt.global_position + Vector3.UP - c.global_position - Vector3.UP * 1.3).normalized()
	var from = pj.hand_pos(c, true)
	Sfx.play("whoosh", from, 1.8, 0.5)
	_fold_gather(pj, from)
	for k in 5:
		pj.after(k * 0.05, func():
			if not pj.live(c):
				return
			var dir = d.rotated(Vector3.UP, deg_to_rad((k - 2) * 7.0))
			var pr = pj.shot(c, from, dir, 38.0, _paper_star(), pj.inf(c, "kami_shuriken", 0.35, {"knock": 1.5, "kind": "light", "bleed": 2.0}), tt, false, 1.4, func(p, _h):
				_paper_cut(pj, p))
			pr.spin = Vector3(0, 28.0, 0)
			_spray(pj, from, {"one_shot": false, "n": 14, "life": 0.35, "spread": 30.0, "vmin": 0.2, "vmax": 0.8, "grav": Vector3(0, -2, 0),
				"smin": 0.05, "smax": 0.08, "shape": 3, "cols": [Color(PAPER_W, 1.0), Color(PAPER_B, 0.0)]}, pr))


static func _paper_star() -> Node3D:
	if not _meshes.has("pstar"):
		var b = MB.new()
		var xf = Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO)
		for k in 4:
			var a = k * TAU / 4.0
			var tip = Vector2(cos(a), sin(a)) * 0.23
			var l = Vector2(cos(a - 0.6), sin(a - 0.6)) * 0.07
			var r = Vector2(cos(a + 0.6), sin(a + 0.6)) * 0.07
			# (x,z) → slab profili (u = -x, v = z): yatay düzlem
			b.add_slab(PackedVector2Array([Vector2.ZERO, Vector2(-l.x, l.y), Vector2(-tip.x, tip.y)]), 0.008, PAPER_W, xf)
			b.add_slab(PackedVector2Array([Vector2.ZERO, Vector2(-tip.x, tip.y), Vector2(-r.x, r.y)]), 0.008, PAPER_B, xf)
		b.add("box", Vector3(0, 0.006, 0), Vector3(0.1, 0.004, 0.1), PAPER_W.darkened(0.06), Vector3(0, 45, 0))
		_meshes["pstar"] = b.build()
	var root = Node3D.new()
	root.add_child(_mi(_meshes["pstar"], cel(Color.WHITE, 0.006)))
	return root


static func _fold_gather(pj: PathJutsu, at: Vector3) -> void:
	var m = _paper_mat()
	for i in 6:
		var sh = _sheet(m, 0.16, 0.22)
		var a = randf() * TAU
		var from = at + Vector3(cos(a), randf_range(-0.2, 0.5), sin(a)) * 0.8
		_put(pj, sh, from)
		var tw = sh.create_tween().set_parallel(true)
		tw.tween_property(sh, "global_position", at, 0.18).set_ease(Tween.EASE_IN)
		tw.tween_property(sh, "rotation", Vector3(randf() * 6, randf() * 6, 0), 0.18)
		tw.tween_property(sh, "scale", Vector3(0.3, 1, 0.3), 0.18)
		tw.chain().tween_callback(sh.queue_free)


static func _paper_cut(pj: PathJutsu, p: Vector3) -> void:
	_spray(pj, p, {"n": 12, "life": 0.6, "spread": 180.0, "vmin": 2.0, "vmax": 4.0, "grav": Vector3(0, -3, 0), "drag": 2.0, "smin": 0.06, "smax": 0.1,
		"shape": 3, "grow": [1.0, 0.8], "cols": [Color(PAPER_W, 1.0), Color(PAPER_B, 0.0)]})
	for k in 3:
		_streak(pj, p, Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized(), 0.6, 0.03, Color(0.95, 0.92, 1.0, 0.9), 0.12, true, 1.0)


# ================================================================== Wakusei Rasengan
## ref: elde tek büyük Rasengan (dönen beyaz sarmal çizgiler, dikenli mavi hale) + üç ayrı yörüngede küçük Rasengan
## (yörünge izleriyle); dalış: her darbede büyüyen öğütme diski + beyaz kavis şeritleri, sonda yerde sarmal oyuk
static func wakusei_rasengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	pj.busy(c, 1.2)
	var ba = pj.bone_attach(c, "RightHand")
	var sys = Node3D.new()
	sys.add_child(_rasen_ball(0.45))
	var pivots = []
	for k in 3:
		var pv = Node3D.new()
		pv.rotation = Vector3(deg_to_rad([20.0, -35.0, 70.0][k]), k * TAU / 3.0, deg_to_rad([10.0, 30.0, -15.0][k]))
		var spin = Node3D.new()
		pv.add_child(spin)
		var moon = _rasen_ball(0.18)
		moon.position = Vector3(0.9, 0, 0)
		spin.add_child(moon)
		var om = _mat("ring", RING_SH % NOISE, {"col": CHAKRA, "amount": 0.35})
		var orbit = _mi(_ring_mesh(0.88, 0.92, 64), om)
		orbit.rotation.x = PI * 0.5
		pv.add_child(orbit)
		sys.add_child(pv)
		pivots.append(spin)
	if ba:
		ba.add_child(sys)
		sys.position = Vector3.UP * 0.5
	else:
		sys.queue_free()
	if ba:
		_spray(pj, pj.hand_pos(c, true) + Vector3.UP * 0.5, {"n": 30, "life": 0.45, "r": 1.4, "vmin": 0.0, "vmax": 0.2, "radial": -14.0, "grav": Vector3.ZERO,
			"smin": 0.05, "smax": 0.1, "burst": 0.0, "add": true, "cols": [Color(CHAKRA, 0.0), Color(0.85, 0.95, 1.0, 1.0), Color(CHAKRA, 0.0)]})
	pj.every(1.2, 1.0 / 30.0, func(_i, k):
		for j in pivots.size():
			if is_instance_valid(pivots[j]):
				pivots[j].rotation.y = k * 20.0 + j * TAU / 3.0, func():
		if is_instance_valid(ba):
			ba.queue_free())
	pj.after(0.5, func():
		if not pj.live(c):
			return
		var d = pj._jump_at(c, tt, 0.0, 14.0 if tt else 4.0)
		for k in 4:
			pj.after(0.12 + k * 0.1, func():
				if pj.live(c):
					var at = c.global_position + Vector3.UP * 1.3 + d * 1.3
					_planet_grind(pj, at, d, 1.0 + k * 0.2, k == 3)
					pj.hit(c, at, 2.2, pj.inf(c, "wakusei_rasengan", 0.6, {"knock": 6.0 + k * 6.0, "launch": 2.0, "kind": "heavy"}))))
	Sfx.play("wind", c.global_position, 1.3)


## Rasengan küresi: sarmal çizgili kabuk + parlak çekirdek + dikenli hale
static func _rasen_ball(r: float) -> Node3D:
	var root = Node3D.new()
	var sp = SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.0
	sp.radial_segments = 24
	sp.rings = 12
	root.add_child(_mi(sp, _mat("rasen", RASEN_SH % NOISE)))
	var cs = SphereMesh.new()
	cs.radius = r * 0.5
	cs.height = r
	cs.radial_segments = 12
	cs.rings = 6
	root.add_child(_mi(cs, energy(Color(0.6, 0.85, 1.0), Color(1, 1, 1), true, 6.0, 0.8)))
	var q = QuadMesh.new()
	q.size = Vector2.ONE * r * 4.4
	root.add_child(_mi(q, _mat("halo", HALO_SH % [NOISE, BILL], {"col": Color(0.45, 0.72, 1.0)})))
	return root


static func _planet_grind(pj: PathJutsu, at: Vector3, d: Vector3, s: float, last: bool) -> void:
	var q = QuadMesh.new()
	q.size = Vector2.ONE
	var m = _mat("swirl", SWIRL_SH)
	var disk = _mi(q, m)
	_put(pj, disk, at)
	disk.global_transform.basis = _basis_look(-d)
	disk.scale = Vector3.ONE * 0.6 * s
	var tw = disk.create_tween()
	tw.tween_property(disk, "scale", Vector3.ONE * 2.6 * s, 0.3).set_ease(Tween.EASE_OUT)
	_fade(disk, m, 0.12, 0.25)
	# beyaz kavis şeritleri (ref): d ekseni çevresinde, rastgele eğik
	var ax = _perp(d)
	for i in 5:
		var pts = []
		var ups = []
		var ws = []
		var a0 = randf() * TAU
		var tilt = randf_range(-0.5, 0.5)
		var rr = randf_range(0.9, 1.4) * s
		for j in 14:
			var f = j / 13.0
			var a = a0 - f * 2.2
			var radial = (ax[0] * cos(a) + ax[1] * sin(a)).rotated(ax[0], tilt)
			pts.append(radial * rr + d * (f - 0.5) * 0.4)
			ups.append(radial)
			ws.append(0.16 * s * (1.0 - f * 0.8))
		var sm = _streak_mat(Color(0.95, 0.98, 1.0, 0.95), false)
		var arc = _mi(_strip_mesh(pts, ups, ws), sm)
		_put(pj, arc, at)
		var tw2 = arc.create_tween().set_parallel(true)
		tw2.tween_property(arc, "scale", Vector3.ONE * 1.6, 0.35).set_ease(Tween.EASE_OUT)
		tw2.tween_property(arc, "rotation", d * 1.4, 0.35)
		_fade(arc, sm, 0.12, 0.25)
	_spray(pj, at, {"n": 18, "life": 0.4, "spread": 180.0, "vmin": 4.0, "vmax": 9.0, "drag": 3.0, "grav": Vector3.ZERO, "smin": 0.05, "smax": 0.12,
		"add": true, "cols": [Color(1, 1, 1, 1), Color(CHAKRA, 0.0)]})
	var g = pj.gp(at)
	if at.y - g.y < 2.2:
		_rubble(pj, g + Vector3.UP * 0.1, 3 + int(s * 2.0), 4.0 + s * 2.0, 0.1)
	if last:
		var hq = QuadMesh.new()
		hq.size = Vector2.ONE * 4.0 * s
		var hm = _mat("halo", HALO_SH % [NOISE, BILL], {"col": Color(0.55, 0.8, 1.0)})
		var halo = _mi(hq, hm)
		_put(pj, halo, at)
		_fade(halo, hm, 0.1, 0.4)
		_decal(pj, g, 2.4 * s, 4, Color(0.1, 0.12, 0.16, 0.85), 3.0, 1.0)


# ================================================================== Akahigi: Hyakki no Sōen (yüz kukla)
## ref (Sasori): havada dev kızıl kenarlı parşömen açılır; kuklalar ondan ipler sarkarak iner (ayak altında kızıl mühür
## halkası, düşen kızıl kumaş şeritleri); sonra iki elin parmaklarından her kuklaya mavi chakra ipleri
static func akahigi_hyakki_no_soen(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var scroll_at = _scroll_unfurl(pj, c)
	var list = ClanConstruct.spawn(c, "puppet", 6, Jutsu._jd("akahigi_hyakki_no_soen"))
	if list is Array:
		for u in list:
			u.global_position += Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			u.dmg *= 0.3   # denge: 6 kukla aynı rütbenin ~10 katı vuruyordu (ölçüldü) -> ~3 kat
			_puppet_drop(pj, u, scroll_at)
		_puppet_strings(pj, c, list, 20.0)
	Hud.msg("Yüz Kukla Gösterisi!", Color(0.9, 0.45, 0.45))
	Sfx.play("clink", c.global_position, 0.5)


static func _scroll_unfurl(pj: PathJutsu, c: Node3D) -> Vector3:
	var fd: Vector3 = c.face_dir()
	var at = c.global_position + fd * 3.2 + Vector3.UP * 5.0
	var root = Node3D.new()
	_put(pj, root, at)
	root.global_transform.basis = Basis.looking_at(fd, Vector3.UP)
	var H = 3.6
	var q = QuadMesh.new()
	q.size = Vector2(2.4, H)
	var m = _mat("scroll", SCROLL_SH % NOISE, {"unroll": 0.0})
	var paper = _mi(q, m)
	root.add_child(paper)
	var rb = MB.new()
	rb.add("cyl", Vector3.ZERO, Vector3(0.2, 2.8, 0.2), Color(0.5, 0.12, 0.1), Vector3(0, 0, 90), 12)
	rb.add("cyl", Vector3(1.45, 0, 0), Vector3(0.12, 0.12, 0.12), Color(0.85, 0.7, 0.35), Vector3(0, 0, 90), 10)
	rb.add("cyl", Vector3(-1.45, 0, 0), Vector3(0.12, 0.12, 0.12), Color(0.85, 0.7, 0.35), Vector3(0, 0, 90), 10)
	var rmesh = rb.build()
	var top = _mi(rmesh, cel(Color.WHITE, 0.015))
	var bot = _mi(rmesh, cel(Color.WHITE, 0.015))
	root.add_child(top)
	root.add_child(bot)
	top.position = Vector3.UP * H * 0.5
	bot.position = Vector3.UP * H * 0.5
	root.scale = Vector3.ONE * 0.2
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(f: float):
		m.set_shader_parameter("unroll", f)
		if is_instance_valid(bot):
			bot.position = Vector3.UP * (H * 0.5 - H * f)
			bot.rotation.x = f * 14.0, 0.0, 1.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_method(func(f: float):
		m.set_shader_parameter("unroll", f)
		if is_instance_valid(bot):
			bot.position = Vector3.UP * (H * 0.5 - H * f)
			bot.rotation.x = f * 14.0, 1.0, 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.15)
	tw.tween_callback(root.queue_free)
	return at


static func _puppet_drop(pj: PathJutsu, u: Node3D, from: Vector3) -> void:
	var g = pj.gp(u.global_position)
	_decal(pj, g, 1.1, 3, Color(0.75, 0.1, 0.08, 0.95), 1.8, 0.6)
	_wire(pj, func(): return from, func(): return u.global_position + Vector3.UP * 1.4 if is_instance_valid(u) else Vector3.ZERO, 0.5, Color(CHAKRA, 0.9), 0.02)
	var cm = _paper_mat(0.0, Color(0.62, 0.14, 0.12), Color(0.42, 0.08, 0.07), Color(0.2, 0.04, 0.04))
	for i in 4:
		var sh = _sheet(cm, 0.12, 0.5)
		var p0 = g + Vector3(randf_range(-0.6, 0.6), randf_range(2.2, 3.2), randf_range(-0.6, 0.6))
		_put(pj, sh, p0)
		var ph = randf() * TAU
		var tw = sh.create_tween()
		tw.tween_method(func(f: float):
			if is_instance_valid(sh):
				sh.global_position = p0.lerp(g + Vector3.UP * 0.05, f) + Vector3(sin(ph + f * 8.0), 0, cos(ph + f * 6.0)) * 0.35 * (1.0 - f)
				sh.rotation = Vector3(sin(ph + f * 10.0) * 1.2, f * 3.0, cos(ph + f * 7.0)), 0.0, 1.0, randf_range(0.9, 1.3))
		tw.tween_interval(0.4)
		tw.tween_property(sh, "scale", Vector3.ONE * 0.05, 0.2)
		tw.tween_callback(sh.queue_free)


## İki elden kuklalara mavi chakra ipleri (kukla silinince ip söner)
static func _puppet_strings(pj: PathJutsu, c: Node3D, units: Array, dur: float) -> void:
	for u in units:
		for k in 2:
			var side = k == 0
			_wire(pj, func(): return pj.hand_pos(c, side) if (is_instance_valid(c) and is_instance_valid(u)) else Vector3.ZERO,
				func(): return (u.global_position + Vector3.UP * (1.4 + k * 0.15)) if is_instance_valid(u) else Vector3.ZERO, dur, Color(CHAKRA, 0.75), 0.016, 0.15)


# ================================================================== Kyōmeisen (ses delgisi)
## ref (Dosu): ön kolda delikli metal ses kolçağı; vuruşta ince yanardöner ses halkaları ileri dizilir, merkeze çekilen
## ışınsal çizgiler; vurulanın başında dönen iki halka (iç kulak — denge bozuldu)
static func kyomeisen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	pj.busy(c, 0.6)
	_sound_gauntlet(pj, c, 1.1)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var at = c.global_position + Vector3.UP * 1.2 + d * 1.0
		for k in 5:
			pj.after(k * 0.05, func():
				_sound_ring(pj, at + d * k * 0.6, d, 1.2 + k * 0.9))
		_sound_lines(pj, at, d)
		for e in pj.hit(c, at, 2.0, pj.inf(c, "kyomeisen", 0.6, {"knock": 4.0, "kind": "heavy"})):
			pj.st(e, "stun", 1.2)
			pj.st(e, "slow", 4.0)
			Combat.popup_text(e.global_position + Vector3.UP * 2.3, "Denge bozuldu!", SOUND)
			_ear_wobble(pj, e, 1.2)
		Sfx.play("genjutsu", at, 1.6))


static func _sound_gauntlet(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightLowerArm")
	if ba == null:
		return
	if not _meshes.has("gauntlet"):
		var b = MB.new()
		b.add("cyl", Vector3(0, 0.13, 0), Vector3(0.13, 0.26, 0.13), Color(0.7, 0.7, 0.68), Vector3.ZERO, 14)
		b.add("cyl", Vector3(0, 0.005, 0), Vector3(0.145, 0.03, 0.145), Color(0.9, 0.88, 0.82), Vector3.ZERO, 14)
		b.add("cyl", Vector3(0, 0.26, 0), Vector3(0.145, 0.03, 0.145), Color(0.9, 0.88, 0.82), Vector3.ZERO, 14)
		for i in 6:
			var a = i * TAU / 6.0 + (0.5 if i % 2 else 0.0)
			b.add("sphere", Vector3(cos(a) * 0.063, 0.07 + (i % 3) * 0.06, sin(a) * 0.063), Vector3(0.035, 0.035, 0.035), Color(0.08, 0.08, 0.09), Vector3.ZERO, 8)
		_meshes["gauntlet"] = b.build()
	var mi = _mi(_meshes["gauntlet"], cel(Color.WHITE, 0.008))
	ba.add_child(mi)
	_pop_in(mi, Vector3.ONE, 0.12)
	var tw = mi.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(ba.queue_free)


static func _sound_ring(pj: PathJutsu, at: Vector3, d: Vector3, r: float) -> void:
	var m = _mat("ring", RING_SH % NOISE, {"col": SOUND, "iri": 1.0})
	var mi = _mi(_ring_mesh(0.95, 1.0, 56), m)
	_put(pj, mi, at)
	mi.global_transform.basis = _basis_look(d)
	mi.scale = Vector3.ONE * r * 0.25
	mi.create_tween().tween_property(mi, "scale", Vector3.ONE * r, 0.3).set_ease(Tween.EASE_OUT)
	_fade(mi, m, 0.12, 0.25)


static func _sound_lines(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	var ax = _perp(d)
	for i in 16:
		var a = i * TAU / 16.0 + randf() * 0.2
		var radial = ax[0] * cos(a) + ax[1] * sin(a)
		_streak(pj, at + radial * randf_range(2.2, 3.0), -radial, randf_range(1.0, 1.6), 0.035, Color(0.92, 0.9, 1.0, 0.8), 0.2, true, 1.0)
	_spray(pj, at, {"n": 16, "life": 0.4, "r": 1.0, "vmin": 0.0, "vmax": 0.3, "grav": Vector3.ZERO, "smin": 0.06, "smax": 0.12, "add": true,
		"cols": [Color(1, 1, 1, 1), Color(SOUND, 0.0)]})


static func _ear_wobble(pj: PathJutsu, e: Node3D, dur: float) -> void:
	if not is_instance_valid(e):
		return
	var h = float(e.get("height")) if e.get("height") != null else 1.8
	var root = Node3D.new()
	e.add_child(root)
	root.position = Vector3.UP * (h * 0.92)
	var m = _mat("ring", RING_SH % NOISE, {"col": SOUND, "iri": 1.0, "amount": 0.8})
	for k in 2:
		var mi = _mi(_ring_mesh(0.92, 1.0), m)
		mi.scale = Vector3.ONE * 0.38
		mi.rotation = Vector3(PI * 0.5 + (0.5 if k == 0 else -0.5), 0, 0)
		root.add_child(mi)
	var tw = root.create_tween()
	tw.tween_property(root, "rotation:y", TAU * 3.0, dur)
	_fade(root, m, dur - 0.3, 0.3)


# ================================================================== Sanzengarasu (bin karga)
## Karga sürüsü gövdeden kopar (kanat çırparak), hedefin çevresinde girdap olur, onu gözden saklar; sürü dağılırken
## kara tüyler salınarak düşer
static func sanzengarasu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.2)
	if tt == null:
		return
	var birds = []
	var m = cel(Color.WHITE, 0.008, 0.0, FLAME, 0.8, 0.7)
	for k in 50:
		var bird = _mi(_crow_mesh(), m)
		bird.set_instance_shader_parameter("phase", randf() * TAU)
		pj.get_tree().current_scene.add_child(bird)
		bird.global_position = c.global_position + Vector3.UP * 1.5 + Vector3(randf_range(-0.4, 0.4), randf_range(-0.5, 0.4), randf_range(-0.4, 0.4))
		bird.scale = Vector3.ONE * randf_range(0.85, 1.15)
		birds.append(bird)
	pj.every(3.2, 1.0 / 30.0, func(i, _k):
		if not pj.live(tt):
			return
		for n in birds.size():
			if not is_instance_valid(birds[n]):
				continue
			var a = i * 0.22 + n * 0.7
			var r = 1.2 + (n % 6) * 0.35
			var tgt = tt.global_position + Vector3(cos(a) * r, 0.3 + (n % 8) * 0.35, sin(a) * r)
			birds[n].global_position = birds[n].global_position.lerp(tgt, 0.25)
			birds[n].rotation.y = -a, func():
		for bd in birds:
			if is_instance_valid(bd):
				var out = bd.global_position - (tt.global_position if is_instance_valid(tt) else bd.global_position) + Vector3.UP * 0.5
				out.y = absf(out.y) + 0.6
				var tw = bd.create_tween().set_parallel(true)
				tw.tween_property(bd, "global_position", bd.global_position + out.normalized() * randf_range(5.0, 8.0), 0.6).set_ease(Tween.EASE_IN)
				tw.tween_property(bd, "scale", Vector3.ONE * 0.05, 0.6).set_ease(Tween.EASE_IN)
				tw.chain().tween_callback(bd.queue_free))
	_feathers(pj, tt, 22, 3.2)
	pj.st(tt, "stun", 3.0)
	if tt.has_method("lose_target"):
		tt.lose_target(3.0)
	Sfx.play("genjutsu", tt.global_position, 1.0)


## Karga (+Z ileri): gövde, baş, gaga, kanatlar (|x| > 0.05 → çırpar), yelpaze kuyruk, soluk göz
static func _crow_mesh() -> ArrayMesh:
	if _meshes.has("crow"):
		return _meshes["crow"]
	var b = MB.new()
	b.add("sphere", Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.28), CROW, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, 0.04, 0.16), Vector3(0.085, 0.085, 0.095), CROW, Vector3.ZERO, 10)
	b.add("cone", Vector3(0, 0.035, 0.24), Vector3(0.032, 0.09, 0.028), Color(0.14, 0.14, 0.16), Vector3(90, 0, 0), 5)
	b.add("sphere", Vector3(0.036, 0.055, 0.19), Vector3(0.018, 0.018, 0.018), Color(0.75, 0.72, 0.68))
	b.add("sphere", Vector3(-0.036, 0.055, 0.19), Vector3(0.018, 0.018, 0.018), Color(0.75, 0.72, 0.68))
	var xf = Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		var wing = PackedVector2Array()
		for p in [Vector2(0.05, 0.07), Vector2(0.22, 0.08), Vector2(0.4, 0.02), Vector2(0.5, -0.06), Vector2(0.44, -0.08), Vector2(0.38, -0.06),
				Vector2(0.32, -0.1), Vector2(0.24, -0.08), Vector2(0.17, -0.12), Vector2(0.05, -0.07)]:
			wing.append(Vector2(-p.x * sx, p.y))
		b.add_slab(wing, 0.012, CROW.lightened(0.04), xf)
	var tail = PackedVector2Array([Vector2(0.06, -0.12), Vector2(-0.06, -0.12), Vector2(-0.1, -0.34), Vector2(0.0, -0.3), Vector2(0.1, -0.34)])
	b.add_slab(tail, 0.01, CROW, xf)
	var m = b.build()
	_meshes["crow"] = m
	return m


static func _feathers(pj: PathJutsu, tt: Node3D, n: int, dur: float) -> void:
	if not _meshes.has("feather"):
		var b = MB.new()
		var xf = Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO)
		b.add_slab(PackedVector2Array([Vector2(0, 0.12), Vector2(0.03, 0.04), Vector2(0.025, -0.08), Vector2(0, -0.12), Vector2(-0.025, -0.08), Vector2(-0.03, 0.04)]), 0.006, CROW, xf)
		_meshes["feather"] = b.build()
	var m = cel(Color.WHITE, 0.004, 0.0, FLAME, 0.0, 0.6)
	for i in n:
		pj.after(randf() * dur, func():
			if not is_instance_valid(tt):
				return
			var f = _mi(_meshes["feather"], m)
			var top = tt.global_position + Vector3(randf_range(-1.6, 1.6), randf_range(1.6, 3.0), randf_range(-1.6, 1.6))
			_put(pj, f, top)
			var land = pj.gp(top) + Vector3.UP * 0.05
			var ph = randf() * TAU
			var fall = randf_range(1.6, 2.4)
			var tw = f.create_tween()
			tw.tween_method(func(x: float):
				if is_instance_valid(f):
					f.global_position = top.lerp(land, x) + Vector3(sin(ph + x * 10.0), 0, cos(ph + x * 8.0)) * 0.3
					f.rotation = Vector3(sin(ph + x * 12.0) * 0.8, x * 5.0, cos(ph + x * 9.0) * 0.6), 0.0, 1.0, fall)
			tw.tween_property(f, "scale", Vector3.ONE * 0.05, 0.4)
			tw.tween_callback(f.queue_free))


## atanmamış shader parametresi null gelir (float(null) çöker)
static func _sp0(v) -> float:
	return 1.0 if v == null else float(v)
