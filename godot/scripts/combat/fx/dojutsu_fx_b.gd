class_name DojutsuFXB
extends RefCounted
## Dōjutsu grubu B: Rinnegan yolları (Rinbo Hengoku, Jigokudō, Gedō, Gakidō, Pein Rikudō, Jūbi Kyūin, Gedō Mazō, Tengai Shinsei),
## Mangekyō / Susanoo teknikleri (Susanoo, Kobushi, Kyōsō Enbu, Tsukuyomi, Kamuibashiri, Tensha Fūin: Amaterasu, Magen: Kyō Tenchi-ten).
## Oyunun gerçek sistemleri kullanılır (Susanoo.of, GedoMazo, Cehennem Kralı modeli, kara alıcılar, Jutsu.j_amaterasu);
## görünen her efekt burada, bu dosyanın kendi gölgelendiricileri ve geometrisiyle sıfırdan üretilir. Ortak / hazır efekt yok.
## Oynanış (hasar, durum, süre, menzil, hedefleme) ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}

const EARTH := Color(0.42, 0.34, 0.26)
const WOOD := Color(0.5, 0.36, 0.22)
const LAV := Color(0.8, 0.72, 1.0)


# ================================================================== gölgelendiriciler
## Yarı saydam dolgu + açık kontur (Limbo gölgeleri, ruhlar, hayalet ejder, Tsukuyomi kalabalığı, Susanoo yumruk izi)
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 body_col : source_color = vec4(0.1, 0.08, 0.16, 0.5);
instance uniform vec4 edge_col : source_color = vec4(0.9, 0.9, 1.0, 1.0);
instance uniform float fade = 1.0;
instance uniform float wob = 0.0;
instance uniform vec2 near_fade = vec2(1.0, 3.5);
void vertex() {
	VERTEX += NORMAL * sin(TIME * 9.0 + VERTEX.y * 7.0 + VERTEX.x * 5.0) * wob;
}
void fragment() {
	float f = abs(dot(normalize(NORMAL), VIEW));
	float e = 1.0 - smoothstep(0.2, 0.36, f);
	float nearf = smoothstep(near_fade.x, near_fade.y, -VERTEX.z);
	ALBEDO = mix(body_col.rgb, edge_col.rgb, e);
	ALPHA = clamp(mix(body_col.a, edge_col.a, e) * fade * nearf, 0.0, 1.0);
}
"""

## Cel alev dili (COLOR.r = boy oranı): iç açık, dış orta ton, koyu kontur; uç yalazlanarak kesilir
const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 c_core : source_color = vec4(1.0, 0.85, 0.95, 1.0);
instance uniform vec4 c_mid : source_color = vec4(0.85, 0.2, 0.65, 1.0);
instance uniform vec4 c_edge : source_color = vec4(0.3, 0.0, 0.3, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
varying float hu;
void vertex() {
	hu = COLOR.r;
	float t = TIME * 8.0 + seed * 6.28;
	VERTEX.x += (sin(t + VERTEX.y * 5.0) * 0.12 + sin(t * 1.7 + VERTEX.y * 11.0) * 0.05) * hu;
	VERTEX.z += cos(t * 1.3 + VERTEX.y * 6.0) * 0.08 * hu;
}
void fragment() {
	float f = abs(dot(normalize(NORMAL), VIEW));
	float lick = hu + sin(TIME * 11.0 + seed * 4.0 - hu * 10.0) * 0.07;
	float inner = (1.0 - step(0.42, lick)) * step(0.5, f);
	vec3 col = mix(c_mid.rgb, c_core.rgb, inner);
	float e = 1.0 - smoothstep(0.14, 0.26, f);
	col = mix(col, c_edge.rgb, e);
	float tip = 1.0 - smoothstep(0.82, 0.98, lick);
	float nearf = smoothstep(1.2, 4.5, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(fade * tip * nearf, 0.0, 1.0);
}
"""

## Görünmez vuruşun izi: genişleyen soluk halka + kara çökme + ışınsal çatlak (Limbo)
const DENT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float R = 0.25 + prog * 0.7;
	float band = 1.0 - smoothstep(0.0, 0.07, abs(r - R));
	float inner = (1.0 - smoothstep(R * 0.55, R * 0.8, r)) * (1.0 - prog) * 0.7;
	float s = abs(fract(ang / 6.2832 * 7.0 + seed) - 0.5);
	float rad = (1.0 - smoothstep(0.015, 0.04, s)) * step(r, R * 1.15) * step(0.15, r);
	ALBEDO = mix(vec3(0.07, 0.05, 0.13), vec3(0.88, 0.86, 1.0), band);
	ALPHA = clamp(max(band, max(inner, rad * 0.85)) * fade * step(r, 1.0), 0.0, 1.0);
}
"""

## Yerde tırtıklı kenarlı karanlık çukur (Cehennem Kralı'nın çıktığı yarık / alıcıların deldiği delik)
const PIT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 rim_col : source_color = vec4(0.85, 0.2, 0.7, 1.0);
instance uniform vec4 deep_col : source_color = vec4(0.05, 0.0, 0.07, 1.0);
instance uniform float prog = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float edge_r = (0.78 + 0.08 * sin(ang * 9.0 + seed) + 0.05 * sin(ang * 23.0 + seed * 2.0)) * prog;
	float inside = 1.0 - smoothstep(edge_r - 0.02, edge_r, r);
	float rim = 1.0 - smoothstep(0.0, 0.05, abs(r - edge_r));
	vec3 col = mix(deep_col.rgb, rim_col.rgb * 0.45, (1.0 - r / max(edge_r, 0.01)) * 0.5 * inside);
	col = mix(col, rim_col.rgb, rim);
	ALBEDO = col;
	ALPHA = clamp(max(inside * 0.92, rim) * fade, 0.0, 1.0);
}
"""

## Rinnegan dalgası: dışa koşan eş merkezli halkalar
const RIPPLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.72, 0.62, 1.0, 1.0);
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float rings = 0.0;
	for (int i = 0; i < 4; i++) {
		float rr = fract(prog + float(i) * 0.25);
		float w = 0.04 * (1.0 - rr * 0.5);
		rings = max(rings, (1.0 - smoothstep(w * 0.5, w, abs(r - rr))) * (1.0 - rr));
	}
	float dark = (1.0 - smoothstep(0.0, 0.012, abs(r - fract(prog + 0.12)))) * 0.6;
	ALBEDO = mix(tint.rgb, vec3(0.16, 0.1, 0.26), step(rings, dark));
	ALPHA = clamp(max(rings, dark) * fade * step(r, 1.0), 0.0, 1.0);
}
"""

## Gakidō emme mührü: çerçeve halka, yazı çentikleri, içe dönen sarmal, soluk bariyer zarı
const SEAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float ring = 1.0 - smoothstep(0.0, 0.035, abs(r - 0.88));
	float ring2 = 1.0 - smoothstep(0.0, 0.02, abs(r - 0.58));
	float ticks = step(0.62, r) * step(r, 0.82) * step(0.6, fract(ang / 6.2832 * 28.0 + TIME * 0.4)) * step(0.45, fract(r * 9.0));
	float sp = abs(fract(ang / 6.2832 * 2.0 + r * 1.6 - TIME * 1.2) - 0.5);
	float spiral = (1.0 - smoothstep(0.03, 0.07, sp)) * step(r, 0.56) * step(0.08, r);
	float outer = 1.0 - smoothstep(0.0, 0.02, abs(r - 0.95));
	float lines = max(max(ring, ring2), max(ticks * 0.9, spiral));
	float veil = step(r, 0.92) * 0.18;
	vec3 col = mix(vec3(0.8, 0.84, 0.72), vec3(0.98, 0.99, 1.0), lines);
	col = mix(col, vec3(0.2, 0.22, 0.14), outer);
	ALBEDO = col;
	ALPHA = clamp(max(max(lines, outer), veil) * fade, 0.0, 1.0);
}
"""

## On Kuyruk çekimi: çağırana doğru akan, yere oyulmuş lif lif oluklar
const FIBER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float f = abs(fract(ang / 6.2832 * 46.0 + sin(r * 6.0 + seed) * 0.18) - 0.5);
	float groove = 1.0 - smoothstep(0.05, 0.2, f);
	float flow = 0.6 + 0.4 * sin(r * 18.0 + TIME * 9.0);
	vec3 col = mix(vec3(0.36, 0.38, 0.3), vec3(0.08, 0.08, 0.06), groove * flow);
	float a = (groove * 0.85 + 0.12) * (1.0 - smoothstep(0.8, 1.0, r)) * smoothstep(0.03, 0.12, r);
	ALBEDO = col;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""

## On Kuyruk eti: cel tonlu, çağırana doğru dalga dalga şişen (yutkunma) lif
const FLESH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
instance uniform float seed = 0.0;
varying float hu;
void vertex() {
	hu = COLOR.r;
	VERTEX += NORMAL * max(0.0, sin(hu * 34.0 + TIME * 9.0 + seed)) * 0.22 * (0.3 + hu);
}
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 ld = normalize((VIEW_MATRIX * vec4(0.3, 1.0, 0.2, 0.0)).xyz);
	float l = dot(n, ld);
	vec3 base = vec3(0.5, 0.53, 0.45);
	vec3 col = mix(base * 0.6, base, step(0.0, l));
	float vein = step(0.94, fract(hu * 22.0 + sin(seed + hu * 5.0) * 0.3));
	col = mix(col, base * 0.4, vein * 0.6);
	float f = abs(dot(n, VIEW));
	col = mix(vec3(0.1, 0.1, 0.08), col, smoothstep(0.12, 0.24, f));
	ALBEDO = col;
}
"""

## Göktaşı krateri: derin çanak, açık dudak, ışınsal fırlamış toprak, çanakta halka yarıklar
const CRATER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float R = max(prog, 0.01);
	float bowl = 1.0 - smoothstep(0.52 * R, 0.58 * R, r);
	float rim = 1.0 - smoothstep(0.0, 0.06 * R, abs(r - 0.6 * R));
	float ej = step(0.6 * R, r) * (1.0 - smoothstep(0.6 * R, R, r));
	float spoke = step(0.55, fract(ang / 6.2832 * 23.0 + sin(ang * 3.0 + seed) * 0.2));
	float fr = step(0.9, fract(r * 9.0 / R + sin(ang * 5.0 + seed) * 0.25)) * bowl;
	vec3 col = vec3(0.24, 0.2, 0.17);
	col = mix(col, vec3(0.1, 0.08, 0.07), (1.0 - smoothstep(0.0, 0.35 * R, r)) * bowl);
	col = mix(col, vec3(0.06, 0.05, 0.04), fr);
	col = mix(col, vec3(0.62, 0.55, 0.45), rim);
	col = mix(col, vec3(0.34, 0.29, 0.23), ej * spoke * (1.0 - bowl));
	ALBEDO = col;
	ALPHA = clamp(max(bowl * 0.95, max(rim, ej * spoke * 0.75)) * fade, 0.0, 1.0);
}
"""

## Göktaşının önündeki sıkışmış hava: alt yarıda kara lekeler + kutba koşan ak sürtünme çizgileri (ref)
const PRESSURE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec3 p = normalize(lp);
	float low = 1.0 - smoothstep(-0.35, 0.1, p.y);
	float ang = atan(p.z, p.x);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float cells = sin(ang * 5.0 + sin(lat * 7.0) * 1.5) * sin(lat * 6.0 + ang * 2.0 + TIME * 0.5);
	float blot = smoothstep(0.15, 0.3, cells);
	float rim = 1.0 - smoothstep(0.0, 0.08, abs(cells - 0.2));
	float st = step(0.86, fract(ang / 6.2832 * 46.0 + sin(lat * 13.0) * 0.08)) * (1.0 - smoothstep(-0.6, -0.1, p.y));
	vec3 col = mix(vec3(0.32, 0.33, 0.31), vec3(0.05, 0.05, 0.05), blot);
	col = mix(col, vec3(0.75, 0.77, 0.78), rim * 0.8);
	col = mix(col, vec3(0.95, 0.97, 1.0), st * (1.0 - blot));
	ALBEDO = col;
	ALPHA = clamp(low * mix(0.55, 0.92, blot) * fade, 0.0, 1.0);
}
"""

## Yumuşak kenarlı zemin gölgesi (göktaşı yaklaşırken büyür)
const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.03, 0.03, 0.05);
	ALPHA = clamp((1.0 - smoothstep(0.55, 1.0, r)) * 0.7 * fade, 0.0, 1.0);
}
"""

## Cel toz yığını: iki ton + kontur, söndükçe gürültüyle dağılır
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.72, 0.66, 0.56, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
varying vec3 wp;
float h3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 ld = normalize((VIEW_MATRIX * vec4(0.3, 1.0, 0.25, 0.0)).xyz);
	float l = dot(n, ld);
	vec3 col = mix(tint.rgb * 0.62, tint.rgb, step(0.05, l));
	float f = abs(dot(n, VIEW));
	col = mix(tint.rgb * 0.38, col, smoothstep(0.12, 0.22, f));
	float nz = vn(wp * 0.9 + vec3(seed));
	float a = step(1.0 - fade, nz * 0.85 + 0.15);
	float nearf = smoothstep(1.5, 5.0, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(a * nearf * tint.a, 0.0, 1.0);
}
"""

## Gedō Mazō'nun yer yarığı: ışınsal ana yarıklar + kırık halkalar
const FISSURE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float s = abs(fract(ang / 6.2832 * 9.0 + sin(r * 14.0 + seed) * 0.05 + seed) - 0.5);
	float w = mix(0.07, 0.012, r);
	float mainc = (1.0 - smoothstep(w * 0.6, w, s)) * step(r, prog);
	float s2 = abs(fract(ang / 6.2832 * 23.0 + sin(r * 21.0 + seed * 3.0) * 0.08 + seed * 0.3) - 0.5);
	float sub = (1.0 - smoothstep(0.008, 0.018, s2)) * step(0.3, r) * step(r, prog * 0.85) * step(0.5, fract(r * 3.0 + seed));
	float ringc = (1.0 - smoothstep(0.0, 0.012, abs(fract(r * 4.0 + sin(ang * 7.0 + seed) * 0.06) - 0.5) - 0.48)) * step(r, prog * 0.7) * step(0.6, fract(ang / 6.2832 * 5.0 + seed));
	float k = max(mainc, max(sub * 0.8, ringc * 0.7));
	float hole = 1.0 - smoothstep(0.08, 0.14, r);
	ALBEDO = mix(vec3(0.05, 0.04, 0.04), vec3(0.4, 0.33, 0.27), step(k, 0.4) * (1.0 - hole));
	ALPHA = clamp(max(k, hole * 0.9) * fade, 0.0, 1.0);
}
"""

## Kuchiyose formülü: orta halka, sekiz yazılı ışın, mürekkep çentikleri (yayılarak açılır)
const KUCHI_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.6, 0.45, 0.75, 1.0);
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float reveal = step(r, prog);
	float c0 = 1.0 - smoothstep(0.0, 0.03, abs(r - 0.16));
	float c1 = 1.0 - smoothstep(0.0, 0.015, abs(r - 0.21));
	float s = abs(fract(ang / 6.2832 * 8.0) - 0.5);
	float dist = s * r * 6.2832 / 8.0;
	float spoke = (1.0 - smoothstep(0.012, 0.022, dist)) * step(0.21, r) * step(r, 0.95);
	float glyph = step(0.03, dist) * step(dist, 0.075) * step(fract(r * 14.0), 0.55) * step(0.26, r) * step(r, 0.9);
	float cmark = (1.0 - smoothstep(0.01, 0.02, min(abs(q.x), abs(q.y)))) * step(r, 0.12);
	float ink = max(max(c0, c1), max(spoke, max(glyph * 0.9, cmark)));
	ALBEDO = mix(vec3(0.05, 0.03, 0.06), tint.rgb, 0.18);
	ALPHA = clamp(ink * reveal * fade, 0.0, 1.0);
}
"""

## Kamui girdabı: kameraya dönük, arkasındaki görüntüyü kendi çevresinde büken sarmal; ortası kara
const SPIRAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform float twist = 1.0;
instance uniform float fade = 1.0;
instance uniform float spin = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float sw = twist * (1.0 - smoothstep(0.0, 1.0, r)) * 5.0;
	float a2 = ang + sw + TIME * spin * 6.0;
	vec2 off = vec2(cos(a2), sin(a2)) * r - q;
	vec3 col = texture(scr, SCREEN_UV + off * 0.06 * twist).rgb;
	float arms = sin(ang * 3.0 + log(max(r, 0.02)) * 7.0 * twist + TIME * spin * 10.0);
	col = mix(col, vec3(0.08, 0.07, 0.09), smoothstep(0.75, 0.95, arms) * 0.85 * twist);
	col = mix(col, vec3(0.85, 0.85, 0.9), (1.0 - smoothstep(0.0, 0.03, abs(arms + 0.85))) * 0.5 * twist);
	col = mix(col, vec3(0.02), 1.0 - smoothstep(0.08 * twist, 0.18 * twist, r));
	float mask = 1.0 - smoothstep(0.75, 1.0, r);
	float nearf = smoothstep(0.8, 2.5, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(mask * fade * nearf, 0.0, 1.0);
}
"""

## Susanoo yumruğunun yerde bıraktığı dört boğum çukuru (x: enine, y: yumruk yönü)
const KNUCKLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float dent = 0.0;
	float rimv = 0.0;
	for (int i = 0; i < 4; i++) {
		float cx = -0.6 + float(i) * 0.4;
		vec2 e = vec2((q.x - cx) / 0.17, (q.y + 0.1) / (0.75 - abs(cx) * 0.25));
		float rr = length(e);
		dent = max(dent, 1.0 - smoothstep(0.82, 0.95, rr));
		rimv = max(rimv, 1.0 - smoothstep(0.0, 0.12, abs(rr - 1.0)));
	}
	vec3 col = mix(vec3(0.6, 0.52, 0.42), vec3(0.14, 0.11, 0.09), dent);
	ALBEDO = col;
	ALPHA = clamp(max(dent * 0.9, rimv * 0.8) * fade, 0.0, 1.0);
}
"""

## Sharingan deseni: mode 0 üç tomoe, 1 Itachi Mangekyō (üç kavisli kanat), 2 mühür mürekkebi (yazı halkası + Mangekyō)
const EYE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float mode = 0.0;
instance uniform float fade = 1.0;
instance uniform float rot = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x) + rot;
	float disc = 1.0 - smoothstep(0.95, 0.98, r);
	float outline = 1.0 - smoothstep(0.0, 0.04, abs(r - 0.96));
	float pupil = 1.0 - smoothstep(0.12, 0.15, r);
	float blk = 0.0;
	if (mode < 0.5) {
		float ringl = 1.0 - smoothstep(0.0, 0.02, abs(r - 0.55));
		for (int i = 0; i < 3; i++) {
			float a = float(i) * 2.0944;
			vec2 hc = vec2(cos(a - rot), sin(a - rot)) * 0.55;
			float head = 1.0 - smoothstep(0.11, 0.135, length(q - hc));
			float da = mod(ang - a + 6.2832, 6.2832);
			float tail = step(da, 0.7) * (1.0 - smoothstep(0.0, 0.1 * (1.0 - da / 0.7), abs(r - 0.55 - da * 0.06)));
			blk = max(blk, max(head, tail));
		}
		blk = max(blk, ringl * 0.8);
	} else {
		float b = abs(fract((ang / 6.2832) * 3.0 + r * 0.9) - 0.5);
		float wing = (1.0 - smoothstep(0.1 * (1.0 - r) + 0.02, 0.12 * (1.0 - r) + 0.04, b)) * step(0.2, r) * step(r, 0.9);
		float hub = 1.0 - smoothstep(0.26, 0.29, r);
		blk = max(wing, hub);
	}
	blk = max(blk, max(pupil, outline));
	vec3 red = vec3(0.82, 0.08, 0.06);
	vec3 col = mix(red, vec3(0.03, 0.0, 0.0), blk);
	float a = disc;
	if (mode > 1.5) {
		col = vec3(0.03, 0.02, 0.04);
		a = blk * disc;
	}
	ALBEDO = col;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""

## Tensha mürekkebi: dışta yazı halkası (göze girerken dönen mühür)
const INKRING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float r1 = 1.0 - smoothstep(0.0, 0.025, abs(r - 0.95));
	float r2 = 1.0 - smoothstep(0.0, 0.02, abs(r - 0.72));
	float script = step(0.74, r) * step(r, 0.93) * step(0.45, fract(ang / 6.2832 * 32.0)) * step(0.35, fract(r * 22.0));
	ALBEDO = vec3(0.04, 0.02, 0.05);
	ALPHA = clamp(max(max(r1, r2), script) * fade, 0.0, 1.0);
}
"""

## Kyō Tenchi-ten aynası: gümüş yüz, kızıl çerçeve, yansıyan Sharingan, prog ile yayılan çatlak
const MIRROR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float frame = step(0.88, max(abs(q.x), abs(q.y)));
	vec3 col = mix(vec3(0.5, 0.53, 0.58), vec3(0.93, 0.95, 0.98), smoothstep(-1.0, 1.0, q.y + q.x * 0.5));
	col = mix(col, vec3(1.0), step(0.94, fract((q.x + q.y) * 1.5 + TIME * 0.6)) * 0.8);
	vec2 e = q * vec2(1.0, 0.7);
	float r = length(e);
	float ang = atan(e.y, -e.x);
	float iris = 1.0 - smoothstep(0.42, 0.45, r);
	vec3 eye = vec3(0.8, 0.07, 0.06);
	float blk = 1.0 - smoothstep(0.07, 0.09, r);
	for (int i = 0; i < 3; i++) {
		float a = float(i) * 2.0944 + TIME * 2.0;
		blk = max(blk, 1.0 - smoothstep(0.06, 0.08, length(e - vec2(-cos(a), sin(a)) * 0.26)));
	}
	blk = max(blk, (1.0 - smoothstep(0.0, 0.02, abs(r - 0.43))));
	col = mix(col, mix(eye, vec3(0.03), blk), iris);
	float ca = atan(q.y, q.x);
	float rr = length(q);
	float s = abs(fract(ca / 6.2832 * 5.0 + 0.13) - 0.5);
	float crack = (1.0 - smoothstep(0.004, 0.012, s * rr)) * step(rr, prog * 1.5);
	float s2 = abs(fract(ca / 6.2832 * 11.0 + 0.4) - 0.5);
	crack = max(crack, (1.0 - smoothstep(0.004, 0.01, s2 * rr)) * step(0.35, rr) * step(rr, prog * 1.3));
	col = mix(col, vec3(0.05), crack);
	col = mix(col, vec3(0.45, 0.03, 0.05), frame);
	ALBEDO = col;
	ALPHA = clamp(0.92 * fade, 0.0, 1.0);
}
"""

## Kılıç izi şeridi (COLOR.a = yaş, UV.y = uç tarafı): uçta ak çizgi
const RIBBON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.6, 0.4, 1.0, 1.0);
instance uniform float fade = 1.0;
void fragment() {
	float a = COLOR.a;
	float e = smoothstep(0.7, 1.0, UV.y);
	ALBEDO = mix(tint.rgb, vec3(1.0), e);
	ALPHA = clamp(a * a * (0.3 + 0.7 * e) * fade * smoothstep(1.0, 3.0, -VERTEX.z), 0.0, 1.0);
}
"""

## Gakidō akışı (COLOR.r = hedeften avuca): ak ve zeytin-gri çizgiler avuca doğru koşar, koyu kenar
const STREAM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
varying float hu;
void vertex() {
	hu = COLOR.r;
}
void fragment() {
	float f = abs(dot(normalize(NORMAL), VIEW));
	float s = fract(hu * 5.0 - TIME * 4.0 + seed);
	float streak = smoothstep(0.0, 0.15, s) * (1.0 - smoothstep(0.35, 0.6, s));
	vec3 col = mix(vec3(0.62, 0.62, 0.48), vec3(1.0), streak);
	col = mix(vec3(0.3, 0.3, 0.22), col, smoothstep(0.1, 0.25, f));
	ALBEDO = col;
	ALPHA = clamp((0.55 + streak * 0.45) * fade * smoothstep(1.0, 3.0, -VERTEX.z), 0.0, 1.0);
}
"""

## Tsukuyomi dünyası (ekran katmanı): koyular kara, açıklar gri-ak, gökyüzü kızıl; ORTASI hafif kalır (oyuncu okunur)
const TSUKI_SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float intro = 0.0;
void fragment() {
	vec3 s = texture(scr, SCREEN_UV).rgb;
	float l = dot(s, vec3(0.299, 0.587, 0.114));
	vec3 mono = vec3(smoothstep(0.06, 0.75, l)) * vec3(0.95, 0.92, 0.92);
	float sky = smoothstep(0.4, 0.7, l) * smoothstep(-0.02, 0.1, s.b - s.r);
	vec3 g = mix(mono, vec3(0.7, 0.18, 0.1), sky * 0.85);
	vec2 q = SCREEN_UV - 0.5;
	q.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(q);
	float keep = 1.0 - smoothstep(0.12, 0.5, r);
	float k = amount * mix(1.0, 0.5, keep);
	vec3 col = mix(s, g, k);
	col = mix(col, vec3(0.28, 0.0, 0.0), smoothstep(0.42, 0.85, r) * amount * 0.6);
	float ang = atan(q.y, q.x);
	float ln = step(0.9, fract(sin(floor(ang * 38.0) * 43.7) * 917.3)) * smoothstep(0.28, 0.6, r) * intro;
	col = mix(col, vec3(0.05, 0.0, 0.0), ln * 0.85);
	COLOR = vec4(col, 1.0);
}
"""


# ================================================================== yapı taşları
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _put(host: Node, n: Node3D, p: Vector3) -> Node3D:
	host.add_child(n)
	n.global_position = p
	return n


static func _pf(mi: GeometryInstance3D, pname: String) -> Callable:
	var w = weakref(mi)
	return func(x: float):
		var o = w.get_ref()
		if o != null and is_instance_valid(o):
			o.set_instance_shader_parameter(pname, x)


static func _host(pj) -> Node:
	return pj.get_tree().current_scene


## Düzlemin +Y'si normal yönüne
static func _orient(n: Node3D, normal: Vector3) -> void:
	var nn = normal.normalized()
	if nn.length() < 0.5:
		return
	if nn.dot(Vector3.UP) < -0.999:
		n.global_basis = Basis(Vector3.RIGHT, PI)
	else:
		n.global_basis = Basis(Quaternion(Vector3.UP, nn))


## -Z yönü d'ye (ölçek sıfırlanır; ölçek sonradan verilir)
static func _face_dir(n: Node3D, d: Vector3) -> void:
	if d.length() < 0.001:
		return
	var dd = d.normalized()
	var up = Vector3.UP if absf(dd.y) < 0.98 else Vector3.RIGHT
	n.global_basis = Basis.looking_at(dd, up)


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2, 2)
		_cache["plane"] = p
	return _cache["plane"]


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(2, 2)
		_cache["quad"] = q
	return _cache["quad"]


static func _sph() -> SphereMesh:
	if not _cache.has("sph"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 28
		s.rings = 14
		_cache["sph"] = s
	return _cache["sph"]


static func _flat_vc() -> StandardMaterial3D:
	if not _cache.has("flat_vc"):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		_cache["flat_vc"] = m
	return _cache["flat_vc"]


## Zemine yatık desen düzlemi (params: örnek gölgelendirici değerleri)
static func _decal(host: Node, key: String, code: String, pos: Vector3, r: float, params: Dictionary, normal := Vector3.UP) -> MeshInstance3D:
	var mi = _gi(_plane(), _mat(key, code))
	for k in params:
		mi.set_instance_shader_parameter(k, params[k])
	host.add_child(mi)
	mi.global_position = pos
	_orient(mi, normal)
	mi.scale = Vector3(r, 1.0, r)
	return mi


## Gecikmeyle sönüp silinme (örnek "fade" değeriyle)
static func _fade_free(mi: GeometryInstance3D, delay: float, dur: float) -> void:
	var tw = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, dur)
	tw.tween_callback(mi.queue_free)


## Kaya parçası ağı (renk başına önbellek)
static func _rock(v: int, col: Color) -> ArrayMesh:
	var key = "rock%d_%s" % [v, col.to_html(false)]
	if not _cache.has(key):
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3.ONE, col, Vector3.ZERO, v + 3)
		_cache[key] = b.build(Props.toon())
	return _cache[key]


## Balistik taş parçaları: gy zemin yüksekliğinde durur, sonra küçülüp gider
static func _chunks(host: Node, at: Vector3, gy: float, n: int, spd: float, size: float, col: Color, life := 1.4) -> void:
	for i in n:
		var mi = _gi(_rock(i % 4, col.darkened(float(i % 3) * 0.1)), null)
		_put(host, mi, at)
		var v = Vector3(randf_range(-1, 1), randf_range(0.6, 1.6), randf_range(-1, 1)).normalized() * spd * randf_range(0.5, 1.0)
		var sz = size * randf_range(0.5, 1.2)
		mi.scale = Vector3.ONE * sz
		var spin = Vector3(randf(), randf(), randf()) * 8.0
		var p0 = at
		var tw = mi.create_tween()
		tw.tween_method(func(x: float):
			if not is_instance_valid(mi):
				return
			var p = p0 + v * x + Vector3.DOWN * 9.0 * x * x
			if p.y < gy + sz * 0.3:
				p.y = gy + sz * 0.3
			mi.global_position = p
			mi.rotation = spin * minf(x, 0.8), 0.0, life, life)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.02, 0.4)
		tw.tween_callback(mi.queue_free)


## Kabarık toz yığını ağı (iç içe küreler: cel bulut)
static func _lump() -> ArrayMesh:
	if not _cache.has("lump"):
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(1.0, 0.85, 1.0), Color.WHITE, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0.38, 0.22, 0.1), Vector3(0.7, 0.65, 0.7), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(-0.35, 0.18, -0.15), Vector3(0.75, 0.7, 0.75), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.05, 0.42, -0.05), Vector3(0.6, 0.55, 0.6), Color.WHITE, Vector3.ZERO, 10)
		_cache["lump"] = b.build(null)
	return _cache["lump"]


## Tek toz yığını: büyüyerek vel yönünde kayar, sonra gürültüyle dağılır
static func _billow(host: Node, pos: Vector3, size: float, life: float, vel: Vector3, tint := Color(0.72, 0.66, 0.56)) -> void:
	var mi = _gi(_lump(), _mat("dust", DUST_SHADER))
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	_put(host, mi, pos)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3.ONE * size * 0.4
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * size, life * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", pos + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
	tw.chain().tween_callback(mi.queue_free)


## Cel alev dili ağı (+Y boyunca 0..1; COLOR.r = boy oranı); 3 eğrilik çeşidi
static func _tongue_mesh(v: int) -> ArrayMesh:
	var key = "tongue%d" % v
	if not _cache.has(key):
		var bend = [0.0, 0.14, -0.12][v % 3]
		var pts = []
		var rr = []
		var cols = []
		for j in 7:
			var u = j / 6.0
			pts.append(Vector3(sin(u * PI * 0.9) * bend + u * u * bend, u, 0))
			var w = 0.5 * pow(1.0 - u, 0.7) * (0.55 + 0.45 * sin(u * PI)) + 0.005
			rr.append(Vector2(w, w * 0.8))
			cols.append(Color(u, 0, 0))
		var b = MB.new()
		Loft.tube(b, pts, rr, cols, 10, 2, true, false)
		_cache[key] = b.build(null)
	return _cache[key]


## Tek alev dili: yükselir, incelip uzar, söner (dir: dilin uzandığı yön)
static func _flame_tongue(host: Node, pos: Vector3, w: float, h: float, life: float, core: Color, mid: Color, edge: Color, dir := Vector3.UP) -> MeshInstance3D:
	var mi = _gi(_tongue_mesh(randi() % 3), _mat("flame", FLAME_SHADER))
	mi.set_instance_shader_parameter("c_core", core)
	mi.set_instance_shader_parameter("c_mid", mid)
	mi.set_instance_shader_parameter("c_edge", edge)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	_put(host, mi, pos)
	_orient(mi, dir)
	mi.rotate_object_local(Vector3.UP, randf() * TAU)
	mi.scale = Vector3(w, h * 0.15, w)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(w, h, w), life * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(w * 0.3, h * 1.15, w * 0.3), life * 0.7).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.7)
	tw.tween_callback(mi.queue_free)
	return mi


## Düz renkli, saydamlıkla sönen küçük parça (kıymık, damla, çizgi)
static func _bit(host: Node, mesh: Mesh, p: Vector3, d: Vector3, dist: float, life: float, sz: float, grav := 0.0) -> void:
	var mi = _gi(mesh, _flat_vc())
	_put(host, mi, p)
	_face_dir(mi, d)
	mi.scale = Vector3.ONE * sz
	var p0 = p
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(func(x: float):
		if is_instance_valid(mi):
			mi.global_position = p0 + d.normalized() * dist * (1.0 - (1.0 - x) * (1.0 - x)) + Vector3.DOWN * grav * x * x, 0.0, 1.0, life)
	tw.tween_property(mi, "transparency", 1.0, life * 0.6).set_delay(life * 0.4)
	tw.chain().tween_callback(mi.queue_free)


static func _box_mesh(key: String, size: Vector3, col: Color) -> ArrayMesh:
	if not _cache.has(key):
		var b = MB.new()
		b.add("box", Vector3(0, 0, -size.z * 0.5), size, col)
		_cache[key] = b.build(null)
	return _cache[key]


static func _drop_mesh(key: String, col: Color) -> ArrayMesh:
	if not _cache.has(key):
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.6, 1.0, 0.6), col, Vector3.ZERO, 6)
		_cache[key] = b.build(null)
	return _cache[key]


# ------------------------------------------------------------------ göz
## Gözlerde parlayan desen (kafa kemiğine bağlı, dur sn); tear: gözden yanağa kan izi iner (Mangekyō bedeli, ref)
static func _eye_glint(pj, c: Node3D, col: Color, dur: float, tear := false) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb == null:
		return
	var b = MB.new()
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.032, 0.065, 0.095), Vector3(0.024, 0.017, 0.008), col)
		b.add("sphere", Vector3(sx * 0.032, 0.065, 0.0985), Vector3(0.007, 0.007, 0.004), col.darkened(0.75))
	hb.add_child(_gi(b.build(null), _flat_vc()))
	if tear:
		var tn = Node3D.new()
		hb.add_child(tn)
		tn.position = Vector3(-0.032, 0.054, 0.097)
		var tm = _gi(_box_mesh("tear", Vector3(0.007, 0.003, 1.0), Color(0.45, 0.02, 0.03)), _flat_vc())
		tn.add_child(tm)
		tm.rotation.x = -PI * 0.5   # kutu -Z boyunca; aşağı çevrilir
		tm.scale = Vector3(1, 1, 0.002)
		tm.create_tween().tween_property(tm, "scale", Vector3(1, 1, 0.07), minf(dur * 0.6, 1.2)).set_ease(Tween.EASE_OUT)
	pj.free_after(dur, hb)


# ------------------------------------------------------------------ silüetler
## Hayalet beden ağları (önü -Z): "limbo" Rikudō silueti (dik uzun yele, geniş cübbe), "cloak" yüksek yakalı pelerin + kılıç,
## "soul" kollarını yukarı uzatmış, kuyruğa incelen ruh
static func _figure_mesh(kind: String) -> ArrayMesh:
	var key = "fig_" + kind
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var W = Color.WHITE
	match kind:
		"limbo":
			Loft.tube(b, [Vector3(0, 1.46, 0), Vector3(0, 1.1, 0), Vector3(0, 0.6, 0.02), Vector3(0, 0.05, 0.04)], [Vector2(0.23, 0.14), Vector2(0.25, 0.16), Vector2(0.31, 0.2), Vector2(0.4, 0.27)], W, 10, 2)
			b.add("sphere", Vector3(0, 1.64, 0), Vector3(0.2, 0.25, 0.21), W, Vector3.ZERO, 10)
			for k in 11:
				var a = lerpf(-1.3, 1.3, k / 10.0)
				var L = 0.45 + (1.0 - absf(a) / 1.3) * 0.55
				var rx = 150.0 - absf(a) * 20.0
				var rz = rad_to_deg(a) * 0.9
				var dir = Basis.from_euler(Vector3(deg_to_rad(rx), 0, deg_to_rad(rz))) * Vector3.UP
				b.add("cone", Vector3(sin(a) * 0.12, 1.74, 0.07) + dir * L * 0.5, Vector3(0.13, L, 0.07), W, Vector3(rx, 0, rz), 4)
			for k in 5:   # alında dik kalkan tutamlar
				var a = lerpf(-0.6, 0.6, k / 4.0)
				b.add("cone", Vector3(sin(a) * 0.1, 1.86, -0.02), Vector3(0.07, 0.22, 0.06), W, Vector3(-15, 0, rad_to_deg(-a) * 0.8), 4)
			for sx in [-1.0, 1.0]:
				Loft.tube(b, [Vector3(sx * 0.2, 1.4, 0), Vector3(sx * 0.4, 1.08, -0.06), Vector3(sx * 0.48, 0.8, -0.12)], [0.07, 0.11, 0.15], W, 8, 2)
				b.add("sphere", Vector3(sx * 0.48, 0.66, -0.14), Vector3(0.08, 0.1, 0.08), W, Vector3.ZERO, 6)
		"cloak":
			Loft.tube(b, [Vector3(0, 1.42, 0), Vector3(0, 1.0, 0), Vector3(0, 0.5, 0.02), Vector3(0, 0.04, 0.03)], [Vector2(0.24, 0.16), Vector2(0.27, 0.18), Vector2(0.31, 0.21), Vector2(0.36, 0.24)], W, 10, 2)
			b.add("cyl", Vector3(0, 1.5, 0.01), Vector3(0.3, 0.24, 0.27), W, Vector3.ZERO, 12)
			b.add("sphere", Vector3(0, 1.66, 0), Vector3(0.19, 0.23, 0.2), W, Vector3.ZERO, 10)
			b.add("sphere", Vector3(0, 1.72, 0.03), Vector3(0.22, 0.2, 0.22), W, Vector3.ZERO, 10)
			for sx in [-1.0, 1.0]:
				Loft.tube(b, [Vector3(sx * 0.24, 1.38, 0), Vector3(sx * 0.3, 1.1, -0.04), Vector3(sx * 0.3, 0.85, -0.08)], [0.09, 0.11, 0.12], W, 8, 2)
			b.add("box", Vector3(0.32, 0.5, -0.32), Vector3(0.03, 0.06, 1.0), W, Vector3(-38, 0, 0))
		"soul":
			b.add("sphere", Vector3(0, 1.6, 0), Vector3(0.34, 0.4, 0.34), W, Vector3.ZERO, 10)
			Loft.tube(b, [Vector3(0, 1.42, 0), Vector3(0, 1.05, 0.02), Vector3(0, 0.7, 0.05), Vector3(0, 0.25, 0.12), Vector3(0.05, -0.1, 0.22)], [Vector2(0.19, 0.12), Vector2(0.17, 0.11), Vector2(0.14, 0.1), Vector2(0.08, 0.06), Vector2(0.01, 0.01)], W, 8, 2)
			for sx in [-1.0, 1.0]:
				Loft.tube(b, [Vector3(sx * 0.18, 1.36, 0), Vector3(sx * 0.32, 1.6, -0.05), Vector3(sx * 0.36, 1.92, -0.08)], [0.055, 0.045, 0.03], W, 6, 2)
	_cache[key] = b.build(null)
	return _cache[key]


static func _figure(kind: String, body: Color, edge: Color) -> MeshInstance3D:
	var mi = _gi(_figure_mesh(kind), _mat("ghost", GHOST_SHADER))
	mi.set_instance_shader_parameter("body_col", body)
	mi.set_instance_shader_parameter("edge_col", edge)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


# ================================================================== Rinbo: Hengoku
## Görünmez Limbo gölgeleri: Rinnegan'lı izleyen için kara dolgulu, açık konturlu Rikudō silüetleri bedenden sızıp
## hedefin çevresinde döner ve her vuruşta hamle eder; görmeyen için yalnız havada beliren çöküntü halkası ve kara kıymıklar.
static func rinbo_hengoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.6)
	if tt == null:
		if c is Player:
			Hud.msg("Rinbo: Hengoku: menzilde hedef yok.", Color(0.75, 0.65, 0.95))
		return
	var n = 4
	if c is Player:
		n = 4 if pj._player_eye_kinds().count(6) >= 2 else 1
	var viewer_sees = c is Player or (Game.player and 6 in pj._player_eye_kinds())
	var DUR = 4.0
	var host = _host(pj)
	_eye_glint(pj, c, LAV, DUR)
	for i in n:
		var shadow: MeshInstance3D = null
		if viewer_sees:
			shadow = _figure("limbo", Color(0.06, 0.05, 0.1, 0.42), Color(0.86, 0.84, 1.0, 0.85))
			shadow.set_instance_shader_parameter("wob", 0.012)
			_put(host, shadow, c.global_position)
			shadow.scale = Vector3(0.6, 0.05, 0.6)   # bedenden yere sızıp doğrulur
			shadow.create_tween().tween_property(shadow, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var phase = i * TAU / maxf(1.0, n)
		pj.every(DUR, 0.45, func(k, _u):
			if not (pj.live(c) and pj.live(tt)):
				return
			var a = phase + k * 0.9
			var from = tt.global_position + Vector3(cos(a), 0, sin(a)) * 1.3
			var dv = (tt.global_position - from).normalized()
			if is_instance_valid(shadow):
				_limbo_lunge(shadow, from, dv)
			_limbo_mark(host, tt.global_position + Vector3.UP * 1.1, dv)
			tt.take_hit(pj.inf(c, "rinbo_hengoku", 0.22, {"knock": 2.0, "launch": 0.0, "kind": "light", "pierce_guard": true, "dir": dv})), func():
			if is_instance_valid(shadow):
				var tw = shadow.create_tween()   # gölge bedene döner
				tw.tween_property(shadow, "global_position", c.global_position if is_instance_valid(c) else shadow.global_position, 0.3)
				tw.parallel().tween_method(_pf(shadow, "fade"), 1.0, 0.0, 0.3)
				tw.tween_callback(shadow.queue_free))
	if c is Player:
		Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Rinbo: %d gölge" % n, Color(0.75, 0.65, 0.95))
	Sfx.play("genjutsu", tt.global_position, 1.4)


## Gölge hamlesi: geriden çekilip hedefe atılır, vuruş noktasında durur
static func _limbo_lunge(shadow: MeshInstance3D, from: Vector3, dv: Vector3) -> void:
	var flat = Vector3(dv.x, 0, dv.z)
	shadow.global_position = from - flat * 0.9
	_face_dir(shadow, flat)
	var tw = shadow.create_tween()
	tw.tween_property(shadow, "global_position", from + flat * 0.25, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(shadow, "global_position", from, 0.18).set_ease(Tween.EASE_OUT)


## Görünmez vuruşun izi: havada çöken halka + vuruş yönünde kara kıymıklar
static func _limbo_mark(host: Node, p: Vector3, dv: Vector3) -> void:
	var mi = _gi(_quad(), _mat("dent", DENT_SHADER))
	mi.set_instance_shader_parameter("prog", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	_put(host, mi, p - dv * 0.35)
	_face_dir(mi, dv)
	mi.scale = Vector3.ONE * 0.5
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(_pf(mi, "prog"), 0.0, 1.0, 0.28).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.1, 0.28)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.2).set_delay(0.18)
	tw.chain().tween_callback(mi.queue_free)
	var sh = _box_mesh("limbo_shard", Vector3(0.025, 0.025, 0.3), Color(0.16, 0.1, 0.28))
	for q in 5:
		var d = (dv + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.6), randf_range(-0.6, 0.6))).normalized()
		_bit(host, sh, p, d, randf_range(0.8, 1.4), 0.25, 1.0)


# ================================================================== Jigokudō
## Cehennem Kralı (oyunun kendi modeli) mor-kara yarıktan yükselir; tabanında magenta alev perdesi dil dil yanar (ref).
## Sorgu: kurbanın ağzından ak damarlı pembe ruh-dil uzar, Kral'ın el-dili kavrar; yargıda dil parçalanıp savrulur.
## Onarım: kullanıcı yutulur, geri çıkarken pembe şeritler bedenini aşağıdan yukarı sarar.
static func jigokudo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 2.4)
	var fd: Vector3 = c.face_dir()
	var at = pj.gp(c.global_position + fd * (4.5 if tt else 5.0))
	if tt:   # yakala
		var tw0 = c.create_tween()
		tw0.tween_property(c, "global_position", pj.gp(tt.global_position - pj._face(c, tt) * 0.9), 0.2)
		at = pj.gp(tt.global_position + pj._face(c, tt) * 4.5)
	var host = _host(pj)
	var kh = pj._king_head()
	var head: Node3D = kh["root"]
	host.add_child(head)
	head.global_position = at - Vector3.UP * 8.0
	var face_to = (c.global_position if not tt else tt.global_position) - at
	face_to.y = 0
	head.rotation.y = atan2(face_to.x, face_to.z) + PI   # ön (-Z) çağırana/kurbana
	var pit = _decal(host, "pit", PIT_SHADER, at + Vector3.UP * 0.05, 3.4, {"prog": 0.1, "fade": 1.0, "seed": randf() * 10.0,
		"rim_col": Color(0.9, 0.25, 0.75), "deep_col": Color(0.06, 0.0, 0.08)})
	var ptw = pit.create_tween()
	ptw.tween_method(_pf(pit, "prog"), 0.1, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ptw.tween_interval(4.2)
	ptw.tween_method(_pf(pit, "fade"), 1.0, 0.0, 0.6)
	ptw.tween_callback(pit.queue_free)
	var flames = func():
		_hell_flames(host, at)
	flames.call()
	pj.every(4.0, 0.35, func(_i, _k): flames.call(), Callable())
	var tw = head.create_tween()
	tw.tween_property(head, "global_position", at - Vector3.UP * 0.6, 0.6).set_trans(Tween.TRANS_BACK)
	Sfx.play("roar", at, 0.5)
	var flap: Node3D = kh["flap"]
	if tt and pj.live(tt):
		tt.set_meta("gaki_hold", true)
		pj.st(tt, "bind", 3.0)
		if c is Player:
			c.input_locked = 2.4
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Sorgu: yalan söylersen dilin koparılır", Color(0.95, 0.5, 0.8))
		tw.tween_property(flap, "rotation:x", -1.4, 0.4)   # örtü kalkar
		tw.tween_callback(func():
			if not (pj.live(tt) and pj.live(c) and is_instance_valid(head)):
				return
			var mouth_w: Vector3 = head.global_transform * (kh["mouth"] as Vector3)
			var vm: Vector3 = tt.global_position + Vector3.UP * 1.45 + (mouth_w - tt.global_position).normalized() * 0.15
			var root = Node3D.new()
			host.add_child(root)
			# kurbanın ruhu ağzından pembe dil olarak uzar; Kral'ın el-dili onu kavrar
			var grip = vm.lerp(mouth_w, 0.45)
			pj._hand_tongue(root, mouth_w, grip)
			_soul_tongue(root, vm, grip)
			pj.after(1.2, func():   # yargı
				if is_instance_valid(root):
					root.queue_free()
				if is_instance_valid(tt):
					tt.remove_meta("gaki_hold")
				if not (pj.live(tt) and pj.live(c)):
					return
				var strong = tt is Player or tt.has_meta("boss") or tt is TailedBeast
				_soul_shred(host, grip, vm)
				if strong:
					pj.st(tt, "stun", 1.5)
					if tt is Player:
						tt.chakra = 0.0
						Buffs.add("jigoku_bitkin", 8.0, {"speed": 0.75, "_name": "Bitkin", "_desc": "Cehennem Kralı'nın sorgusu: ruhun yorgun"})
					tt.take_hit(pj.inf(c, "jigokudo", 0.0, {"dmg": float(tt.max_hp) * (0.2 if tt is Player else 0.1), "knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
					Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Bitkin düştü", Color(0.95, 0.6, 0.85))
				else:
					tt.take_hit(pj.inf(c, "jigokudo", 0.0, {"dmg": float(tt.max_hp) * 4.0, "no_blood": true, "knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
					Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Yalan — dili koparıldı", Color(0.95, 0.5, 0.8))))
		tw.tween_interval(1.4)
	else:
		# onarım: Kral kullanıcıyı yutar, onarıp geri çıkarır
		tw.tween_property(flap, "rotation:x", -1.4, 0.35)
		tw.tween_callback(func():
			if not pj.live(c) or not is_instance_valid(head):
				return
			var mouth_w: Vector3 = head.global_transform * (kh["mouth"] as Vector3)
			var back = c.global_position
			c.visible = false
			if c is Player:
				c.input_locked = 2.2
			c.set_meta("jigoku_inside", true)
			var tw2 = c.create_tween()
			tw2.tween_property(c, "global_position", mouth_w - Vector3.UP * 0.8, 0.25)
			tw2.tween_interval(1.8)
			tw2.tween_callback(func():
				if not is_instance_valid(c):
					return
				c.global_position = pj.gp(back)
				c.visible = true
				c.remove_meta("jigoku_inside")
				if c.get("statuses") != null:
					c.statuses.clear()
				pj.heal(c, float(c.max_hp) * 0.45)
				Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Beden onarıldı", Color(0.95, 0.6, 0.85))
				_mend_bands(host, c)))
		tw.tween_interval(2.4)
	tw.tween_property(flap, "rotation:x", 0.0, 0.3)
	tw.tween_property(head, "global_position", at - Vector3.UP * 8.0, 0.6)
	tw.tween_callback(head.queue_free)


## Kral'ın tabanında bir dalga magenta alev (elips halka)
static func _hell_flames(host: Node, at: Vector3) -> void:
	for k in 10:
		var ang = TAU * k / 10.0 + randf() * 0.25
		_flame_tongue(host, at + Vector3(cos(ang) * 2.6, 0.0, sin(ang) * 2.0), randf_range(0.7, 1.0), randf_range(1.5, 2.7), 0.9,
			Color(1.0, 0.62, 0.92), Color(0.86, 0.14, 0.66), Color(0.28, 0.0, 0.3))


## Ruh-dil: pembe kas, üstünde ak şimşek damarlar (ref)
static func _soul_tongue(root: Node3D, vm: Vector3, grip: Vector3) -> void:
	var sm = MB.new()
	var mid = vm.lerp(grip, 0.5) + Vector3.UP * 0.2
	Loft.tube(sm, [vm, mid, grip], [0.08, 0.13, 0.15], Color(0.92, 0.55, 0.72), 8, 3)
	var ax = (grip - vm).normalized()
	var side = ax.cross(Vector3.UP).normalized()
	for v in 3:
		var pts = []
		var off = side.rotated(ax, v * 2.1)
		for j in 7:
			var u = j / 6.0
			var p = vm.lerp(grip, u) + Vector3.UP * 0.2 * sin(u * PI)
			var rad = lerpf(0.085, 0.155, u)
			pts.append(p + off.rotated(ax, sin(u * 13.0 + v) * 0.5) * rad)
		Loft.tube(sm, pts, [0.012, 0.012, 0.01, 0.012, 0.01, 0.01, 0.006], Color(0.98, 0.96, 0.98), 4, 2)
	var soul = MeshInstance3D.new()
	soul.mesh = sm.build(Props.toon())
	root.add_child(soul)


## Yargı: ruh-dil parça parça kopup savrulur, ak damar kıvılcımları
static func _soul_shred(host: Node, grip: Vector3, vm: Vector3) -> void:
	var pink = _box_mesh("shred", Vector3(0.09, 0.025, 0.22), Color(0.92, 0.5, 0.72))
	var vein = _box_mesh("vein", Vector3(0.012, 0.012, 0.35), Color(1, 0.97, 1))
	for k in 9:
		var p = vm.lerp(grip, k / 8.0)
		var d = Vector3(randf_range(-1, 1), randf_range(0.4, 1.4), randf_range(-1, 1))
		_bit(host, pink, p, d, randf_range(0.6, 1.5), 0.6, randf_range(0.8, 1.3), 1.2)
	for k in 5:
		_bit(host, vein, grip, Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)), 0.7, 0.3, 1.0)


## Onarım: pembe şeritler ayaktan başa sararak yükselir
static func _mend_bands(host: Node, c: Node3D) -> void:
	if not _cache.has("band"):
		var b = MB.new()
		b.add("torus", Vector3.ZERO, Vector3(1.0, 0.6, 1.0), Color.WHITE, Vector3.ZERO, 24)
		_cache["band"] = b.build(null)
	for k in 4:
		var mi = _gi(_cache["band"], _mat("ghost", GHOST_SHADER))
		mi.set_instance_shader_parameter("body_col", Color(1.0, 0.55, 0.85, 0.55))
		mi.set_instance_shader_parameter("edge_col", Color(1.0, 0.92, 0.98, 0.95))
		mi.set_instance_shader_parameter("fade", 1.0)
		_put(host, mi, c.global_position + Vector3.UP * 0.1)
		mi.rotation = Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
		mi.scale = Vector3.ONE * 0.75
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.12)
		tw.tween_property(mi, "global_position", c.global_position + Vector3.UP * 2.0, 0.6).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.35, 0.6)
		tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.6)
		tw.tween_callback(mi.queue_free)


# ================================================================== Gedō
## Dış Yol: çağıranın sırtından yelpaze gibi kara alıcılar açılır (ref); hedefin çevresinde yer delinip alıcılar fışkırır,
## dibinde kırık çukur ve taş kıymıkları; saplanınca hedefin çevresinde bozulan çakranın mor dalgaları.
static func gedo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 24.0)
	if tt == null:
		if c is Player:
			Hud.msg("Gedō: menzilde hedef yok.", Color(0.75, 0.65, 0.95))
		return
	pj.anim(c, "cast", 1.2)
	var host = _host(pj)
	var at = pj.gp(tt.global_position)
	_eye_glint(pj, c, LAV, 1.4)
	_receiver_fan(pj, c)
	for k in 8:
		pj.after(0.15 + k * 0.04, func():
			if not pj.live(tt):
				return
			var a = k * TAU / 8.0 + randf() * 0.3
			var base = at + Vector3(cos(a), 0, sin(a)) * 1.6
			var tip = tt.global_position + Vector3.UP * randf_range(0.7, 1.5)
			var rod = pj._receiver_rod(base.distance_to(tip) + 0.4)
			host.add_child(rod)
			rod.global_position = base
			rod.look_at(tip + Vector3(0.001, 0, 0), Vector3.UP)
			rod.global_position = base.lerp(tip, 0.5)
			rod.scale = Vector3(1, 1, 0.05)
			var tw = rod.create_tween()
			tw.tween_property(rod, "scale", Vector3.ONE, 0.1)
			tw.tween_interval(2.6)
			tw.tween_property(rod, "scale", Vector3(1, 1, 0.02), 0.2)
			tw.tween_callback(rod.queue_free)
			_rod_breach(host, base))
	pj.after(0.5, func():
		if pj.live(tt) and pj.live(c):
			var boss = tt.has_meta("boss") or tt is TailedBeast
			pj.st(tt, "bind", 1.5 if boss else 2.8)
			pj._receiver_pierce(c, tt, 4.0)
			_chakra_scramble(host, tt)
			tt.take_hit(pj.inf(c, "gedo", 0.8, {"knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true})))
	Sfx.play("earth", at, 1.2)


## Sırttan açılan alıcı yelpazesi (çağırana bağlı, kısa)
static func _receiver_fan(pj, c: Node3D) -> void:
	var fd: Vector3 = c.face_dir()
	var side = fd.cross(Vector3.UP).normalized()
	for k in 7:
		var a = lerpf(-1.15, 1.15, k / 6.0)
		var out = (-fd * 0.45 + Vector3.UP * cos(a) + side * sin(a)).normalized()
		var L = 1.2 + (1.0 - absf(a) / 1.15) * 0.5
		var rod = pj._receiver_rod(L)
		c.add_child(rod)
		var root = c.global_position + Vector3.UP * 1.3 - fd * 0.12
		rod.global_position = root + out * L * 0.5
		rod.look_at(root + out * (L + 1.0), Vector3.UP if absf(out.y) < 0.98 else Vector3.RIGHT)
		rod.scale = Vector3(1, 1, 0.05)
		var tw = rod.create_tween()
		tw.tween_interval(k * 0.02)
		tw.tween_property(rod, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.75)
		tw.tween_property(rod, "scale", Vector3(1, 1, 0.02), 0.15)
		tw.tween_callback(rod.queue_free)


## Alıcının deldiği yer: kırık kenarlı çukur + fırlayan taş kıymıkları
static func _rod_breach(host: Node, base: Vector3) -> void:
	var hole = _decal(host, "pit", PIT_SHADER, base + Vector3.UP * 0.04, 0.45, {"prog": 1.0, "fade": 1.0, "seed": randf() * 10.0,
		"rim_col": Color(0.55, 0.47, 0.38), "deep_col": Color(0.06, 0.05, 0.05)})
	_fade_free(hole, 2.6, 0.4)
	_chunks(host, base + Vector3.UP * 0.1, base.y, 4, 4.0, 0.14, EARTH, 0.9)


## Bozulan çakra: hedefin belinde mor halkalar dışa çırpınır
static func _chakra_scramble(host: Node, tt: Node3D) -> void:
	for k in 3:
		var mi = _decal(host, "ripple", RIPPLE_SHADER, tt.global_position + Vector3.UP * (0.6 + k * 0.45), 1.4, {"tint": LAV, "prog": 0.0, "fade": 1.0},
			Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)))
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.08)
		tw.tween_method(_pf(mi, "prog"), 0.0, 0.75, 0.6)
		tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.6)
		tw.tween_callback(mi.queue_free)


# ================================================================== Gakidō
## Hedefin dibine atılıp kavrar; avuçta dönen ak emme mührü (yazı halkası + içe dönen sarmal, soluk zar) belirir,
## hedeften avuca ak ve zeytin-gri çizgili çakra akışı çekilir (ref). Bilge kurbanda çağıranın bedeni taş kabukla kaplanır.
static func gakido(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	if tt == null:
		if c is Player:
			Hud.msg("Gakidō: emmek için hedefe dokunman gerek (7 m).", Color(0.75, 0.9, 1.0))
		return
	pj.busy(c, 0.5)
	var dv = pj._face(c, tt)
	var grab_at = pj.gp(tt.global_position - dv * 1.0)
	var dtw = c.create_tween()   # atılış: hedefin dibine
	dtw.tween_property(c, "global_position", grab_at, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var host = _host(pj)
	pj.after(0.3, func():
		if not (pj.live(c) and pj.live(tt)) or c.global_position.distance_to(tt.global_position) > 3.2:
			if c is Player:
				Hud.msg("Kavrayamadın.", Color(0.75, 0.9, 1.0))
			return
		var sage = (tt is Player and Buffs.has("sage")) or tt.has_meta("sage")
		pj.anim(c, "interact", 1.0)
		var DUR = 3.0
		tt.set_meta("gaki_hold", true)
		pj.st(tt, "bind", DUR)
		if c is Player:
			c.input_locked = DUR
		var hp0 = float(c.hp)
		var seal = {"mi": _absorb_seal(pj, host, c, tt, DUR)}
		var drop_seal = func():
			var m = seal["mi"]
			if m != null and is_instance_valid(m):
				m.queue_free()
		_eye_glint(pj, c, LAV, DUR)
		pj.every(DUR, 0.5, func(_i, _k):
			if not (pj.live(c) and pj.live(tt)) or not tt.has_meta("gaki_hold"):
				return
			if float(c.hp) < hp0 - 0.5:   # emerken vuruldu: kavrayış koptu
				tt.remove_meta("gaki_hold")
				tt.statuses.erase("bind")
				if c is Player:
					c.input_locked = 0.0
				Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Kavrayış koptu!", Color(1, 0.6, 0.5))
				drop_seal.call()
				return
			var from = tt.global_position + Vector3.UP * 1.3
			var to = pj.hand_pos(c, true)
			_absorb_stream(host, from, to, 0.55)
			if sage:
				c.apply_status("stun", 3.0)
				c.take_hit({"dmg": float(c.max_hp) * 0.25, "knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true})
				Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Doğa enerjisi! Taşlaşıyor...", Color(0.75, 0.7, 0.6))
				_stone_crust(host, c)
				drop_seal.call()
				tt.remove_meta("gaki_hold")
				tt.statuses.erase("bind")
				return
			if tt is Player:
				tt.chakra = maxf(0.0, tt.chakra - 20.0)
			tt.take_hit(pj.inf(c, "gakido", 0.33, {"knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
			pj.heal(c, 13.0)
			pj.chakra_gain(c, 16.0), func():
			if is_instance_valid(tt):
				tt.remove_meta("gaki_hold")))
	Sfx.play("wind", c.global_position, 0.5)


## Avuçta, hedefe dönük, dönen emme mührü (el kemiğini izler)
static func _absorb_seal(pj, host: Node, c: Node3D, tt: Node3D, dur: float) -> MeshInstance3D:
	var mi = _gi(_quad(), _mat("seal", SEAL_SHADER))
	mi.set_instance_shader_parameter("fade", 1.0)
	host.add_child(mi)
	var spin = [0.0]
	var tw = mi.create_tween()
	tw.tween_method(func(x: float):
		if not (is_instance_valid(mi) and is_instance_valid(c)):
			return
		var hp = pj.hand_pos(c, true)
		var aim = (tt.global_position + Vector3.UP * 1.2 - hp) if is_instance_valid(tt) else c.face_dir()
		mi.global_position = hp + aim.normalized() * 0.12
		_face_dir(mi, aim)
		spin[0] += 0.05
		mi.rotate_object_local(Vector3.BACK, spin[0])
		mi.scale = Vector3.ONE * (0.55 * clampf(x * dur / 0.2, 0.05, 1.0)), 0.0, 1.0, dur)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.25)
	tw.tween_callback(mi.queue_free)
	return mi


## Hedeften avuca kıvrılan çizgili çakra akışı
static func _absorb_stream(host: Node, from: Vector3, to: Vector3, life: float) -> void:
	var ax = to - from
	var side = ax.cross(Vector3.UP).normalized()
	var pts = []
	var rr = []
	var cols = []
	var wig = randf_range(-1, 1)
	for j in 9:
		var u = j / 8.0
		pts.append(from.lerp(to, u) + side * sin(u * PI) * 0.35 * wig + Vector3.UP * sin(u * PI) * 0.25)
		var w = lerpf(0.24, 0.05, u)
		rr.append(Vector2(w, w))
		cols.append(Color(u, 0, 0))
	var b = MB.new()
	Loft.tube(b, pts, rr, cols, 8, 2, false, false)
	var mi = _gi(b.build(null), _mat("stream", STREAM_SHADER))
	mi.set_instance_shader_parameter("fade", 0.0)
	mi.set_instance_shader_parameter("seed", randf())
	host.add_child(mi)
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "fade"), 0.0, 1.0, 0.08)
	tw.tween_interval(life - 0.2)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


## Doğa enerjisi: çağıranın bedeninde gri taş pulları belirir, sonra dökülür
static func _stone_crust(host: Node, c: Node3D) -> void:
	for k in 12:
		var mi = _gi(_rock(k % 4, Color(0.55, 0.53, 0.5)), null)
		c.add_child(mi)
		var a = randf() * TAU
		mi.global_position = c.global_position + Vector3(cos(a) * 0.26, randf_range(0.2, 1.6), sin(a) * 0.26)
		mi.scale = Vector3.ONE * 0.01
		var sz = randf_range(0.08, 0.15)
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.05)
		tw.tween_property(mi, "scale", Vector3.ONE * sz, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.6)
		tw.tween_property(mi, "position:y", mi.position.y - 0.4, 0.3).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.01, 0.3)
		tw.tween_callback(mi.queue_free)


# ================================================================== Pein Rikudō
## Çağıranın elinden kara alıcılar yay çizerek cesetlere uçar ve saplanır; beden kalkarken ayağının altında Rinnegan
## dalgası açılır, yukarı doğru ince mor çakra iplikleri gerilir (kukla ipleri).
static func pein_rikudo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.2)
	var now = Time.get_ticks_msec() / 1000.0
	var bodies: Array = []
	for f in Enemy.fallen:
		if bodies.size() >= 6:
			break
		if now - float(f["t"]) < 120.0 and (f["pos"] as Vector3).distance_to(c.global_position) < 40.0 and float(f.get("size", 1.0)) < 2.5 and String(f["team"]) != String(c.team):   # kendi dostunun cesedi değil
			bodies.append(f)
	if bodies.is_empty():
		if c is Player:
			Hud.msg("Pein Rikudō: alıcı saplanacak ceset yok (yakında, son 2 dakikada ölmüş biri gerek).", Color(0.75, 0.65, 0.95))
		return
	pj.anim(c, "cast", 1.0)
	var host = _host(pj)
	_eye_glint(pj, c, LAV, 2.0)
	for i in bodies.size():
		var f: Dictionary = bodies[i]
		_rod_volley(pj, host, c, pj.gp(f["pos"]) + Vector3.UP * 1.3, i * 0.25)
		pj.after(0.2 + i * 0.25, func():
			if not pj.live(c):
				return
			var p: Vector3 = pj.gp(f["pos"])
			var e = Enemy.new()
			e.setup(f["arch"])
			e.team = c.team
			e.set_meta("respawn", false)
			if c is Player:
				e.set_meta("teammate", true)
			host.add_child(e)
			e.global_position = p
			Eyes.give_enemy_eyes(e, 6, 3)   # kontrol edilen bedenin gözleri çağıranınki gibi Rinnegan
			if e.nameplate:
				e.nameplate.modulate = Color(0.8, 0.7, 1.0)
			# yüz ve bedende delik delik alıcılar
			for k in 5:
				var rod = pj._receiver_rod(0.35)
				e.add_child(rod)
				rod.position = Vector3(randf_range(-0.15, 0.15), randf_range(1.0, 1.75), -0.12)
				rod.rotation = Vector3(randf_range(-0.3, 0.3), PI + randf_range(-0.4, 0.4), 0)
			_puppet_rise(host, p)
			Combat.popup_text(p + Vector3.UP * 2.6, "Pain bedeni", Color(0.8, 0.7, 1.0))
			Enemy.fallen.erase(f)
			pj.get_tree().create_timer(60.0).timeout.connect(func():
				if is_instance_valid(e) and not e.is_dead():
					e.set_meta("teammate", false)
					e.die({"execute": true})))
	Sfx.play("seal", c.global_position, 0.7)


## Elden cesede yay çizen beş alıcı (ucu önde), varınca söner
static func _rod_volley(pj, host: Node, c: Node3D, dest: Vector3, delay: float) -> void:
	pj.after(delay, func():
		if not is_instance_valid(c):
			return
		var from = pj.hand_pos(c, true)
		for k in 5:
			var rod = pj._receiver_rod(0.55)
			host.add_child(rod)
			rod.global_position = from
			var lift = Vector3.UP * randf_range(1.5, 3.0) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			var goal = dest + Vector3(randf_range(-0.2, 0.2), randf_range(-0.3, 0.4), randf_range(-0.2, 0.2))
			var prev = [from]
			var tw = rod.create_tween()
			tw.tween_method(func(x: float):
				if not is_instance_valid(rod):
					return
				var p = from.lerp(goal, x) + lift * sin(x * PI)
				var d = p - prev[0]
				rod.global_position = p
				if d.length() > 0.001:
					_face_dir(rod, -d)
				prev[0] = p, 0.0, 1.0, 0.2 + k * 0.012)
			tw.tween_property(rod, "scale", Vector3(1, 1, 0.05), 0.08)
			tw.tween_callback(rod.queue_free))


## Kukla kalkışı: ayakta Rinnegan dalgası + yukarı gerilen mor iplikler
static func _puppet_rise(host: Node, p: Vector3) -> void:
	var rp = _decal(host, "ripple", RIPPLE_SHADER, p + Vector3.UP * 0.05, 2.4, {"tint": LAV, "prog": 0.0, "fade": 1.0})
	var tw = rp.create_tween()
	tw.tween_method(_pf(rp, "prog"), 0.0, 1.0, 0.9)
	tw.parallel().tween_method(_pf(rp, "fade"), 1.0, 0.0, 0.9)
	tw.tween_callback(rp.queue_free)
	var th = _box_mesh("thread", Vector3(0.012, 0.012, 1.0), Color(0.78, 0.68, 1.0))
	for k in 5:
		var a = TAU * k / 5.0
		var base = p + Vector3(cos(a), 0, sin(a)) * 0.35 + Vector3.UP * 0.3
		var mi = _gi(th, _flat_vc())
		_put(host, mi, base)
		_face_dir(mi, Vector3.UP + Vector3(cos(a), 0, sin(a)) * 0.15)
		mi.scale = Vector3(1, 1, 0.01)
		var t2 = mi.create_tween()
		t2.tween_property(mi, "scale", Vector3(1, 1, 2.6), 0.25).set_ease(Tween.EASE_OUT)
		t2.tween_property(mi, "transparency", 1.0, 0.5)
		t2.tween_callback(mi.queue_free)


# ================================================================== Rikudō Jūbi Kyūin
## On Kuyruk'un etinden boz-yeşil lif kollar çağırana uzanıp dalga dalga yutkunarak akar; yerde çağırana yakınsayan
## lif oluklar (ref); canavar küçülüp bedene girince sırtında dokuz kara Arayış Topu belirir.
static func rikudo_jubi_kyuin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var jubi: Node3D = null
	for b in pj.get_tree().get_nodes_in_group("tailed_beasts"):
		if is_instance_valid(b) and String(b.get("id")) == "jubi" and b.global_position.distance_to(c.global_position) < 260.0:
			jubi = b
	if jubi == null:
		if c is Player:
			Hud.msg("Rikudō Jūbi Kyūin yalnız On Kuyruk'un yakınında yapılabilir.", Color(1.0, 0.5, 0.45))
		return
	if not WorldJubi.can_absorb(jubi, c):   # kanon: başkasının On Kuyruk'u boyun eğmeden çekilemez
		if c is Player:
			Hud.msg("On Kuyruk boyun eğmeden bedenine çekilemez. Önce diz çöktür.", Color(1.0, 0.5, 0.45))
		return
	pj.busy(c, 2.0)
	var host = _host(pj)
	var field = _decal(host, "fiber", FIBER_SHADER, pj.gp(c.global_position) + Vector3.UP * 0.05, 20.0, {"fade": 0.0, "seed": randf() * 10.0})
	var ftw = field.create_tween()
	ftw.tween_method(_pf(field, "fade"), 0.0, 1.0, 0.3)
	ftw.tween_interval(1.9)
	ftw.tween_method(_pf(field, "fade"), 1.0, 0.0, 0.6)
	ftw.tween_callback(field.queue_free)
	_jubi_tendrils(host, c, jubi, 1.8)
	var tw = jubi.create_tween()
	tw.tween_property(jubi, "scale", Vector3.ONE * 0.01, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(jubi, "global_position", c.global_position, 1.8)
	tw.tween_callback(func():
		jubi.dead = true
		jubi.queue_free()
		if c is Player:
			WorldJubi.absorbed()
		if is_instance_valid(c):
			_gudo_halo(host, c, 6.0))


## Canavardan çağırana uzanan, her karede yeniden örülen et kollar
static func _jubi_tendrils(host: Node, c: Node3D, jubi: Node3D, dur: float) -> void:
	for k in 8:
		var off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(3.0, 7.0) + Vector3.UP * randf_range(5.0, 14.0)
		var bend = Vector3(randf_range(-1, 1), randf_range(0.3, 1.0), randf_range(-1, 1)) * randf_range(2.0, 6.0)
		var mi = _gi(ArrayMesh.new(), _mat("flesh", FLESH_SHADER))
		mi.set_instance_shader_parameter("seed", randf() * 10.0)
		host.add_child(mi)
		mi.global_transform = Transform3D.IDENTITY
		var tw = mi.create_tween()
		tw.tween_method(func(x: float):
			if not (is_instance_valid(mi) and is_instance_valid(c) and is_instance_valid(jubi)):
				return
			var s = maxf(jubi.scale.x, 0.12)
			var a = jubi.global_position + off * s
			var b = c.global_position + Vector3.UP * 1.2 - c.face_dir() * 0.15
			var grow = clampf(x * 4.0, 0.0, 1.0)
			var pts = []
			var rr = []
			var cols = []
			for j in 10:
				var v = j / 9.0
				pts.append(a.lerp(b, v * grow) + bend * s * sin(v * PI) * grow + Vector3(0, sin(v * 9.0 + x * 20.0 + k) * 0.3, 0))
				var w = lerpf(0.9 * s + 0.15, 0.1, v)
				rr.append(Vector2(w, w))
				cols.append(Color(1.0 - v, 0, 0))
			var mb = MB.new()
			Loft.tube(mb, pts, rr, cols, 8, 2, false, true)
			mi.mesh = mb.build(null), 0.0, 1.0, dur)
		tw.tween_callback(mi.queue_free)


## Sırtta yay çizen dokuz kara Arayış Topu (çağıranı izler)
static func _gudo_halo(host: Node, c: Node3D, dur: float) -> void:
	var orbs = []
	for k in 9:
		var mi = _gi(_sph(), _mat("ghost", GHOST_SHADER))
		mi.set_instance_shader_parameter("body_col", Color(0.02, 0.02, 0.03, 1.0))
		mi.set_instance_shader_parameter("edge_col", Color(0.4, 0.4, 0.45, 1.0))
		mi.set_instance_shader_parameter("fade", 1.0)
		host.add_child(mi)
		mi.scale = Vector3.ONE * 0.001
		orbs.append(mi)
	var tw = host.create_tween()
	tw.tween_method(func(x: float):
		if not is_instance_valid(c):
			return
		var T = x * dur
		var fd: Vector3 = c.face_dir()
		var side = fd.cross(Vector3.UP).normalized()
		var ctr = c.global_position + Vector3.UP * 1.45 - fd * 0.55
		for k in orbs.size():
			var o = orbs[k]
			if not is_instance_valid(o):
				continue
			var a = lerpf(PI + 0.35, -0.35, k / 8.0)
			o.global_position = ctr + side * cos(a) * 0.85 + Vector3.UP * sin(a) * 0.85 + Vector3.UP * sin(T * 2.0 + k) * 0.04
			var g = clampf((T - k * 0.07) / 0.15, 0.0, 1.0) * clampf((dur - T) / 0.3, 0.0, 1.0)
			o.scale = Vector3.ONE * maxf(0.001, 0.13 * g), 0.0, 1.0, dur)
	tw.tween_callback(func():
		for o in orbs:
			if is_instance_valid(o):
				o.queue_free())


# ================================================================== Kuchiyose: Gedō Mazō
## Avuçlar yere: mürekkep Kuchiyose formülü yayılır; heykelin çevresinde zemin ışınsal yarılır, alçak toz perdesi kabarır,
## Gedō Mazō (oyunun kendi modeli) yükselip öne çöker; ellerin çarptığı yerde yarık + dışa koşan toz + taş.
## Hayalet ejderhalar (ref: mor yarı saydam, açık konturlu, dikenli, pembe gözlü) ağızdan çıkıp ruhu söker.
static func kuchiyose_gedo_mazo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 2.2)
	if c is Player:
		c.input_locked = 1.6
	for g in pj.get_tree().get_nodes_in_group("gedo_mazo"):   # tek heykel: önceki çağrı sona erer
		if is_instance_valid(g) and g.get_meta("owner_f", null) == c:
			g.set_meta("end", true)
	var host = _host(pj)
	var fd: Vector3 = c.face_dir()
	var at = pj.gp(c.global_position - fd * 28.0)
	var yaw = atan2(-fd.x, -fd.z)
	_kuchiyose_formula(host, pj.gp(c.global_position + fd * 1.0), 7.0, Color(0.6, 0.45, 0.75), 1.6)
	Sfx.play("poof", pj.gp(c.global_position + fd * 1.0), 0.8)
	# bedel türü
	var clan = String(Game.profile.get("clan", "")) if c is Player else String(c.get_meta("clan", ""))
	var senju_uchiha = c is Player and ((clan == "uchiha" and Progress.has_nature("mokuton")) or (clan == "senju" and pj._player_eye_kinds().any(func(k): return k in [1, 4, 5, 6])))
	var drain_rate = 0.0 if senju_uchiha else (0.012 if clan == "uzumaki" else 0.025)   # can/sn (oran)
	if senju_uchiha:
		c.hp = maxf(1.0, c.hp - c.max_hp * 0.05)   # kan sunusu
		Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Kan sunusu", Color(0.8, 0.2, 0.25))
	var eyes = TailedBeasts.jarred().size() if c is Player else int(c.get_meta("gedo_eyes", 0))
	# yükseliş: zemin yarılır, toz perdesi, heykel dimdik çıkar
	var g = GedoMazo.spawn(host, at - Vector3.UP * GedoMazo.H * 0.75, yaw, eyes)
	g.add_to_group("gedo_mazo")
	g.set_meta("owner_f", c)
	g.set_pose("rise", 0.0)
	_fissure(host, at, 30.0, 14.0)
	pj.every(2.4, 0.4, func(_i, _k):
		for k in 12:
			var ang = TAU * k / 12.0 + randf() * 0.3
			var dirv = Vector3(cos(ang), 0, sin(ang))
			_billow(host, at + dirv * randf_range(14.0, 22.0) + Vector3.UP * 1.5, randf_range(8.0, 12.0), 1.6, Vector3.UP * 3.0 + dirv * 2.0))
	pj.shake(1.2)
	Sfx.play("earth", at, 0.5)
	var tw = g.create_tween()
	tw.tween_property(g, "global_position", at - Vector3.UP * GedoMazo.H * 0.1, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if not is_instance_valid(g):
			return
		# zincirlerini kırar, öne atılıp dört ayak üstü çöker: yere çarpan eller
		g.set_pose("crouch", 0.7)
		g.open_mouth(0.6)
		g.shake = 0.6
		var land = g.create_tween()
		land.tween_property(g, "global_position", at, 0.7))
	tw.tween_interval(0.75)
	tw.tween_callback(func():
		if not is_instance_valid(g):
			return
		var front = pj.gp(at + fd * 34.0)
		pj.shake(2.0)
		_fissure(host, front, 22.0, 8.0)
		for k in 16:
			var ang = TAU * k / 16.0
			var dirv = Vector3(cos(ang), 0, sin(ang))
			_billow(host, front + dirv * 6.0 + Vector3.UP * 1.0, randf_range(5.0, 7.5), 1.4, dirv * 9.0 + Vector3.UP * 1.5)
		_chunks(host, front + Vector3.UP * 1.0, front.y, 18, 16.0, 1.1, EARTH, 1.8)
		if pj.live(c):
			pj.hit(c, front + Vector3.UP * 2.0, 26.0, pj.inf(c, "kuchiyose_gedo_mazo", 1.6, {"knock": 26.0, "launch": 8.0, "kind": "heavy"}))
		g.open_mouth(1.0)
		Sfx.play("roar", g.mouth_pos(), 0.35, 0.6))
	# kara alıcılar: heykelin göğsünden çağıranın sırtına (yaşam gücü bedeli varsa)
	var rods: Array = []
	if drain_rate > 0.0:
		for k in 4:
			var rod = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.07
			cm.bottom_radius = 0.07
			cm.height = 1.0
			cm.radial_segments = 6
			rod.mesh = cm
			var rm = StandardMaterial3D.new()
			rm.albedo_color = Color(0.04, 0.035, 0.05)
			rm.roughness = 0.4
			rod.material_override = rm
			host.add_child(rod)
			rod.visible = false
			rods.append(rod)
	var DUR = 16.0
	var dragon_cd = [3.0]
	var t0 = [0.0]
	var drained = [false]
	var tick = func(dt: float) -> bool:   # true: bitti
		t0[0] += dt
		if not is_instance_valid(g):
			return true
		if g.has_meta("end") or t0[0] >= DUR or not pj.live(c):
			return true
		# yaşam gücü bedeli: kara alıcılar sırta saplı, can akar
		if drain_rate > 0.0 and t0[0] > 2.6:
			c.hp = maxf(1.0, c.hp - c.max_hp * drain_rate * dt)
			if c.hp <= c.max_hp * 0.12:
				if c is Player:
					Hud.msg("Yaşam gücün tükeniyor — Gedō Mazō çözüldü.", Color(0.85, 0.6, 0.9))
				return true
			var back = c.global_position + Vector3.UP * 1.25 - c.face_dir() * 0.12
			var src = g.chest_pos()
			for k in rods.size():
				var rod: MeshInstance3D = rods[k]
				var off = Vector3((k - 1.5) * 0.12, (k % 2) * 0.15, 0)
				var a0 = back + c.global_transform.basis * off
				var mid = a0.lerp(src, 0.5) + Vector3.UP * (3.0 + k)
				var b0 = a0.lerp(mid, 0.5)
				var L = a0.distance_to(src)
				rod.visible = true
				rod.global_position = (a0 + b0) * 0.5 + (src - a0) * 0.25
				rod.look_at(rod.global_position + (src - a0), Vector3.UP if absf((src - a0).normalized().y) < 0.95 else Vector3.RIGHT)
				rod.rotate_object_local(Vector3.RIGHT, PI * 0.5)
				rod.scale = Vector3(1, L, 1)
				rod.global_position = a0.lerp(src, 0.5)
			if not drained[0]:
				drained[0] = true
				Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Yaşam gücü akıyor...", Color(0.75, 0.55, 0.9))
				_life_drip(host, c)
		# hayalet ejderhalar: ağızdan çıkar, hedefin ruhunu söker
		dragon_cd[0] -= dt
		if t0[0] > 2.8 and dragon_cd[0] <= 0.0:
			dragon_cd[0] = 1.7
			var foes = pj.enemies_near(c, c.global_position, 75.0)
			foes.sort_custom(func(x, y): return x.global_position.distance_to(c.global_position) < y.global_position.distance_to(c.global_position))
			for k in mini(2, foes.size()):
				_gm_dragon(pj, c, g, foes[k])
		return false
	var proc = Timer.new()
	proc.wait_time = 0.05
	proc.autostart = true
	g.add_child(proc)
	# dokuz göz açık: heykel On Kuyruk'a dönüştürülebilir (oyuncunun yolu)
	var rev := {}
	if c is Player and WorldJubi.can_revive():
		rev = {"pos": at, "radius": 60.0, "kind": "jubi_revive", "label": "Dirilt: Jūbi", "statue": g}
		Interact.add(rev)
		Hud.msg("Gedō Mazō'nun dokuz gözü de açık. Heykelin dibinde [F]: On Kuyruk'u dirilt.", Color(0.85, 0.7, 1.0), 6.0)
	proc.timeout.connect(func():
		if tick.call(0.05):
			proc.stop()
			if not rev.is_empty():
				Interact.items.erase(rev)
			for rod in rods:
				if is_instance_valid(rod):
					rod.queue_free()
			_gm_dismiss(host, g))
	Sfx.play("summon", c.global_position, 0.6)


## Mürekkep Kuchiyose formülü: avuçların altından yayılır, sonra söner
static func _kuchiyose_formula(host: Node, pos: Vector3, r: float, col: Color, dur: float) -> void:
	var mi = _decal(host, "kuchi", KUCHI_SHADER, pos + Vector3.UP * 0.04, r, {"tint": col, "prog": 0.0, "fade": 1.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "prog"), 0.0, 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.5)
	tw.tween_callback(mi.queue_free)


## Işınsal yer yarığı: hızla yayılır, uzun kalır
static func _fissure(host: Node, pos: Vector3, r: float, life: float) -> void:
	var mi = _decal(host, "fissure", FISSURE_SHADER, pos + Vector3.UP * 0.06, r, {"prog": 0.0, "fade": 1.0, "seed": randf() * 10.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "prog"), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 1.2)
	tw.tween_callback(mi.queue_free)


## Yaşam gücü bedeli: sırttan kara-kızıl damlalar süzülür
static func _life_drip(host: Node, c: Node3D) -> void:
	var dm = _drop_mesh("drip", Color(0.45, 0.03, 0.06))
	for k in 12:
		var p = c.global_position + Vector3.UP * randf_range(1.0, 1.5) - c.face_dir() * 0.2 + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
		_bit(host, dm, p, Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)), 0.4, 0.6, randf_range(0.05, 0.09), 1.6)


## Heykel geri gömülür (dağılan toz halkasıyla)
static func _gm_dismiss(host: Node, g: Node3D) -> void:
	if not is_instance_valid(g) or g.has_meta("leaving"):
		return
	g.set_meta("leaving", true)
	g.open_mouth(0.0)
	g.set_pose("rise", 0.6)
	var at = g.global_position
	for k in 10:
		var ang = TAU * k / 10.0
		var dirv = Vector3(cos(ang), 0, sin(ang))
		_billow(host, at + dirv * 14.0 + Vector3.UP * 1.0, randf_range(7.0, 10.0), 2.0, Vector3.UP * 2.5 + dirv * 1.5)
	var tw = g.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(g, "global_position", at - Vector3.UP * GedoMazo.H * 0.8, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(g.queue_free)


## Hayalet ejder başı (önü -Z): uzun kurt burnu, açık çene, iki sıra zikzak diş, sırt dikenleri ve yele
static func _dragon_head_mesh() -> ArrayMesh:
	if _cache.has("dragon_head"):
		return _cache["dragon_head"]
	var hb = MB.new()
	var W = Color.WHITE
	Loft.tube(hb, [Vector3(0, 0.05, 0.6), Vector3(0, 0.14, 0.0), Vector3(0, 0.1, -0.8), Vector3(0, 0.03, -1.45)], [Vector2(0.42, 0.3), Vector2(0.44, 0.32), Vector2(0.25, 0.15), Vector2(0.07, 0.05)], W, 12, 3)
	Loft.tube(hb, [Vector3(0, -0.12, 0.35), Vector3(0, -0.3, -0.45), Vector3(0, -0.42, -1.1)], [Vector2(0.32, 0.1), Vector2(0.22, 0.08), Vector2(0.06, 0.04)], W, 10, 3)
	for sx in [-1.0, 1.0]:
		for q in 7:
			var zz = -0.25 - q * 0.15
			hb.add("cone", Vector3(sx * (0.22 - q * 0.025), -0.05, zz), Vector3(0.05, 0.13, 0.04), W, Vector3(180, 0, 0), 4)
			hb.add("cone", Vector3(sx * (0.17 - q * 0.018), -0.26 - q * 0.02, zz - 0.07), Vector3(0.045, 0.11, 0.04), W, Vector3.ZERO, 4)
		hb.add("cone", Vector3(sx * 0.42, 0.12, 0.15), Vector3(0.12, 0.5, 0.1), W, Vector3(70, 0, sx * -60), 4)   # yanak dikeni
	for q in 5:   # sırt dikenleri
		hb.add("cone", Vector3(0, 0.36 + q * 0.02, 0.1 + q * 0.2), Vector3(0.1, 0.45 - q * 0.05, 0.08), W, Vector3(55, 0, 0), 4)
	for q in 4:   # yele
		Loft.tube(hb, [Vector3(0, 0.3, 0.2 + q * 0.12), Vector3((q % 2 - 0.5) * 0.4, 0.5, 0.6 + q * 0.2), Vector3((q % 2 - 0.5) * 0.7, 0.45, 1.1 + q * 0.2)], [0.08, 0.06, 0.01], W, 5, 2)
	_cache["dragon_head"] = hb.build(null)
	var eb = MB.new()
	for sx in [-1.0, 1.0]:
		eb.add("sphere", Vector3(sx * 0.27, 0.24, -0.32), Vector3(0.13, 0.08, 0.06), Color(1.0, 0.45, 0.78), Vector3(0, sx * 15, 0), 8)
		eb.add("sphere", Vector3(sx * 0.29, 0.24, -0.35), Vector3(0.05, 0.05, 0.03), Color(0.95, 0.9, 1.0), Vector3.ZERO, 6)
	_cache["dragon_eye"] = eb.build(null)
	return _cache["dragon_head"]


static func _dragon_mat_set(mi: GeometryInstance3D) -> void:
	mi.set_instance_shader_parameter("body_col", Color(0.62, 0.55, 0.86, 0.5))
	mi.set_instance_shader_parameter("edge_col", Color(0.96, 0.94, 1.0, 0.95))
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("near_fade", Vector2(8.0, 14.0))   # kameraya yaklaşınca yumuşakça söner (ekranı kaplamaz)


## Kamera konumu (yoksa çağıranın arkası)
static func _cam_pos(pj, c: Node3D) -> Vector3:
	var cam = pj.get_viewport().get_camera_3d()
	if cam:
		return cam.global_position
	return c.global_position - c.face_dir() * 5.0 + Vector3.UP * 2.0


## Noktayı kameranın çevresindeki güvenli kürenin (r) dışına iter
static func _off_cam(p: Vector3, cam: Vector3, r: float) -> Vector3:
	var d = p - cam
	if d.length() < r:
		return cam + (d.normalized() if d.length() > 0.01 else Vector3.UP) * r
	return p


## Gedō Mazō'nun hayalet ejderi: ağızdan kıvrılarak hedefe iner, ruhu söker, hedefi bir tur sarıp söner
static func _gm_dragon(pj, c: Node3D, g: Node3D, tt: Node3D) -> void:
	var host = _host(pj)
	var S = 4.6
	var head = Node3D.new()
	var hm = _gi(_dragon_head_mesh(), _mat("ghost", GHOST_SHADER))
	_dragon_mat_set(hm)
	head.add_child(hm)
	head.add_child(_gi(_cache["dragon_eye"], _flat_vc()))
	head.scale = Vector3.ONE * S
	host.add_child(head)
	var body = _gi(ArrayMesh.new(), _mat("ghost", GHOST_SHADER))
	_dragon_mat_set(body)
	host.add_child(body)
	body.global_transform = Transform3D.IDENTITY
	var rebuild = func(hist: Array) -> void:
		if hist.size() < 4 or not is_instance_valid(body):
			return
		var pts = []
		var rr = []
		var n = mini(26, hist.size() / 2)
		for k in n:
			var u = float(k) / maxf(1.0, n - 1.0)
			var w = S * (0.46 * (1.0 - u * 0.8) + 0.03)
			pts.append(hist[k * 2] + Vector3(0, sin(Time.get_ticks_msec() * 0.006 + k * 0.6) * S * 0.12 * u, 0))
			rr.append(Vector2(w, w * 0.6))
		var mb = MB.new()
		Loft.tube(mb, pts, rr, Color.WHITE, 8, 2, false, true)
		body.mesh = mb.build(null)
	var hist: Array = []
	var from: Vector3 = g.mouth_pos() if is_instance_valid(g) else c.global_position + Vector3.UP * 20.0
	head.global_position = from
	var side = randf_range(-1, 1)
	var T = clampf(from.distance_to(tt.global_position) / 34.0, 0.8, 2.2)
	var cleanup = func():
		if is_instance_valid(body):
			body.queue_free()
		if is_instance_valid(head):
			head.queue_free()
	var step = func(u: float) -> void:
		if not is_instance_valid(head):
			return
		var goal: Vector3 = tt.global_position + Vector3.UP * 1.0 if is_instance_valid(tt) else head.global_position
		var cam = _cam_pos(pj, c)
		var away = goal - cam
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else -c.face_dir()
		var sd = away.cross(Vector3.UP).normalized()
		var c1 = from + Vector3.UP * 22.0 + (goal - from) * 0.25 + sd * side * 12.0
		var c2 = goal + Vector3.UP * 18.0 + away * 14.0 - sd * side * 6.0   # hedefe kameranın öbür yanından, yukarıdan iner
		var q = 1.0 - u
		var pos = from * q * q * q + c1 * 3.0 * q * q * u + c2 * 3.0 * q * u * u + goal * u * u * u
		pos = _off_cam(pos, cam, 11.0)
		var prev = head.global_position
		head.global_position = pos
		if pos.distance_to(prev) > 0.01:
			var dv = (pos - prev).normalized()
			head.look_at(pos + dv, Vector3.UP if absf(dv.y) < 0.98 else Vector3.RIGHT)   # burun (-Z) gidiş yönünde
		hist.push_front(pos)
		if hist.size() > 64:
			hist.pop_back()
		rebuild.call(hist)
	var tw = head.create_tween()
	tw.tween_method(step, 0.0, 1.0, T)
	tw.tween_callback(func():
		if pj.live(tt) and pj.live(c):
			_gm_soul_rip(pj, c, tt, g))
	# hedefi bir tur sarıp ağza geri döner
	tw.tween_method(func(u: float):
		if not is_instance_valid(head):
			return
		var o: Vector3 = tt.global_position + Vector3.UP * 1.0 if is_instance_valid(tt) else head.global_position
		var cam = _cam_pos(pj, c)
		var away = o - cam
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else -c.face_dir()
		var sd = away.cross(Vector3.UP).normalized()
		var aa = lerpf(-PI * 0.5, PI * 0.5, u)   # yalnız uzak yarıda yay çizip yükselir
		var pos = _off_cam(o + (away * cos(aa) + sd * sin(aa)) * 3.0 + Vector3.UP * (1.0 + u * 4.0), cam, 11.0)
		var prev = head.global_position
		head.global_position = pos
		head.look_at(pos + (pos - prev) + Vector3(0.001, 0, 0), Vector3.UP)
		hist.push_front(pos)
		if hist.size() > 64:
			hist.pop_back()
		rebuild.call(hist), 0.0, 1.0, 0.45)
	tw.tween_property(head, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(cleanup)
	Sfx.play("wind", from, 0.5)


## Ruh sökme (mekanik ana ağaçtaki _soul_rip ile aynı): soluk mavi ruh bedenden çekilip heykelin ağzına süzülür
static func _gm_soul_rip(pj, c: Node3D, tt: Node3D, g: Node3D) -> void:
	var host = _host(pj)
	var boss = tt is Player or tt.has_meta("boss") or tt is TailedBeast
	var ghost = _figure("soul", Color(0.62, 0.8, 1.0, 0.45), Color(0.95, 0.98, 1.0, 0.95))
	_put(host, ghost, tt.global_position)
	ghost.rotation.y = randf() * TAU
	var dest: Vector3 = g.mouth_pos() if is_instance_valid(g) else tt.global_position + Vector3.UP * 20.0
	var tw = ghost.create_tween()
	tw.tween_property(ghost, "global_position", tt.global_position + Vector3.UP * 1.5, 0.35)
	tw.tween_property(ghost, "global_position", tt.global_position.lerp(dest, 0.45) + Vector3.UP * 6.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ghost, "rotation:z", randf_range(-1.2, 1.2), 1.1)
	tw.tween_property(ghost, "scale", Vector3.ONE * 0.05, 0.4)
	tw.tween_callback(ghost.queue_free)
	var wisp = _box_mesh("soul_wisp", Vector3(0.02, 0.02, 0.6), Color(0.8, 0.9, 1.0))
	for k in 7:
		_bit(host, wisp, tt.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.3, 1.4), randf_range(-0.4, 0.4)), Vector3.UP + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), randf_range(1.0, 2.0), 0.6, 1.0)
	Sfx.play("genjutsu", tt.global_position, 0.6)
	if boss:
		if tt is Player:
			tt.chakra = 0.0
		pj.st(tt, "stun", 1.6)
		tt.take_hit(pj.inf(c, "kuchiyose_gedo_mazo", 0.0, {"dmg": tt.max_hp * (0.2 if tt is Player else 0.08), "knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true, "attacker": c}))
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Çakra söküldü!", Color(0.7, 0.85, 1.0))
	else:
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Ruhu söküldü", Color(0.8, 0.9, 1.0))
		tt.take_hit(pj.inf(c, "kuchiyose_gedo_mazo", 0.0, {"dmg": tt.max_hp * 4.0, "no_blood": true, "knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true, "attacker": c}))


# ================================================================== Susanoo
## Gerçek Susanoo (Susanoo.of) belirirken çağıranın ayağından Susanoo renginde cel alev dilleri üç dalga halinde
## yükselir; bedeni çizen ince açık sarmal çakra çizgileri yukarı tırmanıp söner (ref: kızıl kütle üstünde sarmal çizgiler).
static func susanoo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var had = c == Game.player and c.combat and c.combat.modes and c.combat.modes.eyes and c.combat.modes.eyes.susanoo
	var sn = Susanoo.of(c, "susanoo")
	if sn == null:
		return
	if had:
		Hud.msg("Susanoo zaten açık.", Color(0.8, 0.85, 1.0), 1.2)
		return
	var H = sn.h()
	_susanoo_manifest(pj, c, sn.color(), H)
	MsArts._shake(0.3 + sn.tier * 0.15)


static func _susanoo_manifest(pj, c: Node3D, col: Color, H: float) -> void:
	var host = _host(pj)
	var R = 0.7 + H * 0.12
	var hh = maxf(1.6, H * 0.55)
	var core = col.lightened(0.6)
	var mid = col
	var edge = col.darkened(0.55)
	for wave in 3:
		pj.after(wave * 0.16, func():
			if not is_instance_valid(c):
				return
			var p0 = pj.gp(c.global_position)
			for k in 12:
				var a = TAU * k / 12.0 + wave * 0.26 + randf() * 0.2
				var rr = R * randf_range(0.7, 1.1)
				_flame_tongue(host, p0 + Vector3(cos(a), 0, sin(a)) * rr, R * randf_range(0.35, 0.5), hh * randf_range(0.6, 1.0) * (1.0 - wave * 0.15), 0.9, core, mid, edge))
	for s in 3:
		_chakra_helix(host, pj.gp(c.global_position), col.lightened(0.45), R * 0.9, H * 0.9 + 1.0, s * TAU / 3.0, 1.1)


## Yukarı tırmanan ince sarmal çakra çizgisi
static func _chakra_helix(host: Node, base: Vector3, col: Color, R: float, Hh: float, phase: float, life: float) -> void:
	var pts = []
	var rr = []
	for j in 30:
		var u = j / 29.0
		var a = phase + u * TAU * 1.6
		pts.append(Vector3(cos(a) * R * (1.0 - u * 0.4), u * Hh, sin(a) * R * (1.0 - u * 0.4)))
		rr.append(0.025 + Hh * 0.004)
	var b = MB.new()
	Loft.tube(b, pts, rr, Color.WHITE, 5, 2)
	var mi = _gi(b.build(null), _mat("ghost", GHOST_SHADER))
	mi.set_instance_shader_parameter("body_col", Color(col.r, col.g, col.b, 0.9))
	mi.set_instance_shader_parameter("edge_col", Color(1, 1, 1, 0.95))
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, base)
	mi.scale = Vector3(1, 0.05, 1)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, life * 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5)
	tw.tween_callback(mi.queue_free)


# ================================================================== Susanoo: Kobushi
## Gerçek Susanoo kolu geri çekip vurur; vuruşta yumruğun yarı saydam, konturlu çakra sureti (ref: boğumlarında halkalar)
## ileri fırlayıp büyüyerek söner, yumruk yolu boyunca ince basınç çizgileri; yere yakınsa dört boğum çukuru + taş.
static func susanoo_kobushi(_pj, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_kobushi")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 6.0 + H * 1.1)
	var aim = MsArts._aim_fn(c, tg, 4.0 + H * 0.45)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	MsArts._pj().busy(c, 0.7)
	MsArts._anim(c, "cross", 1.0)
	# geri çekiş: yumruk omuzun arkasında, gövde burulur
	sn.pose({"arms": Susanoo.arm(true, -d * 0.7 + side * 0.55 - Vector3.UP * 0.25, d * 0.25 + Vector3.UP * 0.55 + side * 0.25, d * 0.6 + Vector3.UP * 0.4), "spine": -8.0}, 1.0)
	MsArts._later(0.38, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad), "spine": 14.0}, 0.6, true)
		Sfx.play("whoosh", c.global_position, 0.6, 0.7))
	MsArts._later(0.5, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			return
		var fist = sn.hand(true)
		var to: Vector3 = aim.call()
		var p = fist.lerp(to, 0.4) if tg and fist.distance_to(to) < S * 0.9 + 3.0 else fist
		var inf = Jutsu._inf(c, "susanoo_kobushi", 2.4, {"knock": 24.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.12, "dir": d})
		Combat.hit_sphere(c, p, S * 0.45 + 2.0, inf)
		# yumruk basıncı: kolun ucundan ileri chakra şoku (kolun yetmediği mesafe)
		Combat.hit_zone(c, c.global_position, d, S * 1.2 + 6.0, 26.0, H * 0.8, inf)
		var host = MsArts._scene()
		var front = fist + d * (S * 0.6 + 3.0)
		_fist_phantom(host, fist, front, d, S, col)
		_fist_streaks(host, fist, d, S, col)
		var g = Jutsu._ground(p)
		if p.y - g.y < S * 0.8 + 2.0:
			_knuckle_gouge(host, g, d, S)
			_chunks(host, g + Vector3.UP * 0.5, g.y, 14, 8.0 + S, 0.4 + S * 0.05, Color(0.5, 0.42, 0.32), 1.4)
		Sfx.play("punch", p, 0.6)
		MsArts._shake(0.5 + sn.tier * 0.12))


## Yumruk sureti ağı (önü -Z): avuç bloğu, dört boğum, başparmak, bilek; boğum başlarında halka
static func _fist_mesh() -> ArrayMesh:
	if _cache.has("fist"):
		return _cache["fist"]
	var b = MB.new()
	var W = Color.WHITE
	b.add("box", Vector3(0, 0, 0), Vector3(0.9, 0.62, 0.7), W, Vector3.ZERO)
	for k in 4:
		var x = -0.33 + k * 0.22
		b.add("cyl", Vector3(x, 0.02, -0.42), Vector3(0.2, 0.36, 0.2), W, Vector3(90, 0, 0), 10)
		b.add("torus", Vector3(x, 0.02, -0.6), Vector3(0.16, 0.16, 0.16), W, Vector3(90, 0, 0), 12)
	Loft.tube(b, [Vector3(0.48, -0.15, 0.1), Vector3(0.5, -0.2, -0.25), Vector3(0.25, -0.25, -0.5)], [0.12, 0.11, 0.09], W, 8, 2)
	Loft.tube(b, [Vector3(0, 0, 0.3), Vector3(0, 0, 0.9)], [Vector2(0.36, 0.26), Vector2(0.3, 0.24)], W, 10, 2)
	_cache["fist"] = b.build(null)
	return _cache["fist"]


static func _fist_phantom(host: Node, fist: Vector3, front: Vector3, d: Vector3, S: float, col: Color) -> void:
	var mi = _gi(_fist_mesh(), _mat("ghost", GHOST_SHADER))
	mi.set_instance_shader_parameter("body_col", Color(col.r, col.g, col.b, 0.35))
	mi.set_instance_shader_parameter("edge_col", Color(col.lightened(0.6).r, col.lightened(0.6).g, col.lightened(0.6).b, 1.0))
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, fist)
	_face_dir(mi, d)
	var s0 = S * 0.5 + 0.6
	mi.scale = Vector3.ONE * s0
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "global_position", front, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * s0 * 1.7, 0.3)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.2).set_delay(0.12)
	tw.chain().tween_callback(mi.queue_free)


## Yumruk yolunda ince basınç çizgileri (yönle paralel, uzayıp söner)
static func _fist_streaks(host: Node, fist: Vector3, d: Vector3, S: float, col: Color) -> void:
	var line = _box_mesh("press_line", Vector3(0.03, 0.03, 1.0), Color(1, 1, 1).lerp(col, 0.25))
	var side = d.cross(Vector3.UP).normalized()
	var up = side.cross(d).normalized()
	for k in 12:
		var a = randf() * TAU
		var rad = randf_range(0.3, 0.8) * (S * 0.6 + 0.8)
		var p = fist + (side * cos(a) + up * sin(a)) * rad - d * randf_range(0.0, 1.0)
		var mi = _gi(line, _flat_vc())
		_put(host, mi, p)
		_face_dir(mi, d)
		mi.scale = Vector3(1 + S * 0.05, 1 + S * 0.05, 0.1)
		var L = (S * 1.2 + 6.0) * randf_range(0.5, 1.0)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(1, 1, L), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", p + d * L * 0.4, 0.3)
		tw.tween_property(mi, "transparency", 1.0, 0.18).set_delay(0.12)
		tw.chain().tween_callback(mi.queue_free)


## Yerde yumruk yönüne uzanan dört boğum çukuru
static func _knuckle_gouge(host: Node, g: Vector3, d: Vector3, S: float) -> void:
	var mi = _gi(_plane(), _mat("knuckle", KNUCKLE_SHADER))
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, g + Vector3.UP * 0.06)
	var flat = Vector3(d.x, 0, d.z)
	if flat.length() > 0.01:
		mi.rotation.y = atan2(flat.x, flat.z)
	mi.scale = Vector3(S * 0.6 + 1.5, 1.0, S * 1.2 + 3.0)
	_fade_free(mi, 5.0, 1.2)


# ================================================================== Tengai Shinsei
## Göğün üst katmanından dev göktaşı: üstü ufalanıp parça saçar, alt yarısı sıkışmış havayla kara lekeli ve ak sürtünme
## çizgili, kenarında savrulan rüzgâr yayları (ref); yerde büyüyen gölge yaklaşmayı haber verir. Çarpışta parlama, krater,
## dışa koşan toz dalgası, yükselen toz sütunu, kalkan kaya levhaları ve uçuşan taşlar. Aynı yörüngeden ikincisi gelir.
static func tengai_shinsei(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 40.0)
	var goal = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 20.0)
	var host = _host(pj)
	_eye_glint(pj, c, LAV, 2.6)
	var m1 = _meteor()
	var met: Node3D = m1["root"]
	host.add_child(met)
	# görünüş: göktaşı kameranın öbür yanından, görüş içinde iner; hedef kameraya yakınsa görsel boy küçülür (vuruş aynı)
	var cam = _cam_pos(pj, c)
	var away = goal - cam
	away.y = 0.0
	var cd = away.length()
	away = away.normalized() if cd > 0.1 else c.face_dir()
	var R1 = clampf(cd - 4.0, 4.0, 9.0)
	var R2 = clampf(cd - 3.0, 5.0, 12.0)
	var start = goal + Vector3.UP * 60.0 + away * 18.0
	met.global_position = start
	met.scale = Vector3.ONE * R1
	_meteor_shadow(host, goal, R1, 2.6)
	for k in 10:
		pj.after(k * 0.25, func():
			if is_instance_valid(met):
				_meteor_shed(host, met, R1))
	var tw = met.create_tween()
	tw.tween_property(met, "global_position", goal + Vector3.UP * R1 * 0.45, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m1["rock"], "rotation", Vector3(0.5, 0.8, 0.2), 2.6)
	tw.tween_callback(func():
		_meteor_land(m1)
		_meteor_impact(pj, host, goal, R1 / 9.0)
		if pj.live(c):
			pj.hit(c, goal + Vector3.UP, 14.0, pj.inf(c, "tengai_shinsei", 5.0, {"knock": 30.0, "launch": 12.0, "kind": "heavy", "hitstop": 0.2}))
		pj.shake(2.8))
	tw.tween_property(met, "scale", Vector3(R1, R1 * 0.22, R1), 0.6)
	tw.tween_interval(1.5)
	tw.tween_property(met, "scale", Vector3(R1, 0.05, R1), 0.6)
	tw.tween_callback(met.queue_free)
	# kanon: ilki durdurulsa bile ikincisi aynı yörüngeden gelip ona çarpar — iki göktaşı art arda
	pj.after(2.2, func():
		var m2d = _meteor()
		var m2: Node3D = m2d["root"]
		host.add_child(m2)
		m2.global_position = start + Vector3.UP * 20.0
		m2.scale = Vector3.ONE * R2
		_meteor_shadow(host, goal, R2, 2.4)
		for k in 9:
			pj.after(k * 0.25, func():
				if is_instance_valid(m2):
					_meteor_shed(host, m2, R2))
		var tw2 = m2.create_tween()
		tw2.tween_property(m2, "global_position", goal + Vector3.UP * R2 * 0.5, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_property(m2d["rock"], "rotation", Vector3(-0.4, 0.6, 0.3), 2.4)
		tw2.tween_callback(func():
			_meteor_land(m2d)
			_meteor_impact(pj, host, goal, R2 / 9.0)
			if pj.live(c):
				pj.hit(c, goal + Vector3.UP, 20.0, pj.inf(c, "tengai_shinsei", 5.0, {"knock": 36.0, "launch": 14.0, "kind": "heavy", "hitstop": 0.2}))
			pj.shake(3.2))
		tw2.tween_property(m2, "scale", Vector3(R2, R2 * 0.21, R2), 0.6)
		tw2.tween_interval(1.5)
		tw2.tween_property(m2, "scale", Vector3(R2, 0.05, R2), 0.6)
		tw2.tween_callback(m2.queue_free))
	Sfx.play("boom", goal, 0.3)


## Göktaşı kaya ağı (yarıçap 1): yosunlu koyu gri, pürüzlü yüzey, krater çukurları, üstte kopmakta olan iri parçalar
static func _meteor_rock_mesh() -> ArrayMesh:
	if _cache.has("meteor_rock"):
		return _cache["meteor_rock"]
	var mb = MB.new()
	mb.add("sphere", Vector3.ZERO, Vector3.ONE * 2.0, Color(0.26, 0.27, 0.24), Vector3.ZERO, 18)
	var rng = RandomNumberGenerator.new()
	rng.seed = 4417
	for q in 110:
		var dv = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var bs = rng.randf_range(0.25, 0.5)
		var eu = Basis(Quaternion(Vector3.UP, dv)).get_euler() * (180.0 / PI)
		var col = Color(0.36, 0.38, 0.33).lerp(Color(0.22, 0.24, 0.21), rng.randf())
		mb.add("boulder", dv * (0.98 + maxf(0.0, dv.y) * 0.08), Vector3(bs, bs * 0.3, bs * rng.randf_range(0.7, 1.0)), col, eu, q)
	for q in 18:   # tepede gevşeyen iri kabuk parçaları (ref: üstü dağılıyor)
		var dv = Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.5, 1.0), rng.randf_range(-0.8, 0.8)).normalized()
		var bs = rng.randf_range(0.18, 0.34)
		mb.add("boulder", dv * rng.randf_range(1.08, 1.22), Vector3(bs, bs, bs), Color(0.2, 0.22, 0.19), Vector3(rng.randf() * 360.0, rng.randf() * 360.0, 0), q + 200)
	for q in 8:   # krater çukurları: koyu halka + çukur
		var dv = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var eu = Basis(Quaternion(Vector3.UP, dv)).get_euler() * (180.0 / PI)
		var cs = rng.randf_range(0.15, 0.3)
		mb.add("torus", dv * 1.04, Vector3(cs, cs * 0.6, cs), Color(0.33, 0.33, 0.29), eu, 12)
		mb.add("sphere", dv * 1.0, Vector3(cs * 1.4, cs * 0.3, cs * 1.4), Color(0.12, 0.12, 0.1), eu, 8)
	_cache["meteor_rock"] = mb.build(Props.toon())
	return _cache["meteor_rock"]


## Rüzgâr yayı ağı: alt kenarı saran açık, kısa kavis
static func _arc_mesh() -> ArrayMesh:
	if _cache.has("wind_arc"):
		return _cache["wind_arc"]
	var b = MB.new()
	var pts = []
	var rr = []
	for j in 9:
		var u = j / 8.0
		var a = u * 1.3
		pts.append(Vector3(cos(a) * 1.14, -0.2 - u * 0.15, sin(a) * 1.14))
		rr.append(Vector2(0.018, 0.05) * sin(u * PI) + Vector2(0.002, 0.002))
	Loft.tube(b, pts, rr, Color.WHITE, 5, 2)
	_cache["wind_arc"] = b.build(null)
	return _cache["wind_arc"]


## Göktaşı düğümü: {"root", "rock", "cap", "arcs"} (kök taşınır / ölçeklenir; kaya kendi döner, basınç kabuğu altta kalır)
static func _meteor() -> Dictionary:
	var root = Node3D.new()
	var rock = _gi(_meteor_rock_mesh(), null)
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(rock)
	var cap = _gi(_sph(), _mat("pressure", PRESSURE_SHADER))
	cap.set_instance_shader_parameter("fade", 1.0)
	cap.scale = Vector3.ONE * 1.08
	root.add_child(cap)
	var arcs = Node3D.new()
	root.add_child(arcs)
	for k in 5:
		var a = _gi(_arc_mesh(), _mat("ghost", GHOST_SHADER))
		a.set_instance_shader_parameter("body_col", Color(0.95, 0.97, 1.0, 0.75))
		a.set_instance_shader_parameter("edge_col", Color(0.75, 0.8, 0.9, 0.9))
		a.set_instance_shader_parameter("fade", 1.0)
		arcs.add_child(a)
		a.rotation.y = k * TAU / 5.0 + randf() * 0.4
		a.position.y = -k * 0.04
	arcs.create_tween().set_loops(8).tween_property(arcs, "rotation:y", TAU, 0.7).as_relative()
	return {"root": root, "rock": rock, "cap": cap, "arcs": arcs}


## Çarpışta basınç kabuğu ve rüzgâr yayları söner
static func _meteor_land(md: Dictionary) -> void:
	var cap = md["cap"]
	if is_instance_valid(cap):
		var tw = cap.create_tween()
		tw.tween_method(_pf(cap, "fade"), 1.0, 0.0, 0.2)
	var arcs = md["arcs"]
	if is_instance_valid(arcs):
		arcs.visible = false


## Zeminde yaklaşmayı haber veren, büyüyüp koyulaşan gölge
static func _meteor_shadow(host: Node, goal: Vector3, R: float, dur: float) -> void:
	var mi = _decal(host, "mshadow", SHADOW_SHADER, goal + Vector3.UP * 0.07, R * 0.3, {"fade": 0.2})
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(R * 1.4, 1, R * 1.4), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(_pf(mi, "fade"), 0.2, 1.0, dur)
	tw.chain().tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.15)
	tw.chain().tween_callback(mi.queue_free)


## Düşerken tepesinden kopup geride kalan kaya parçaları
static func _meteor_shed(host: Node, met: Node3D, R: float) -> void:
	for k in 6:
		var dv = Vector3(randf_range(-1, 1), randf_range(0.3, 1.0), randf_range(-1, 1)).normalized()
		var mi = _gi(_rock(k % 4, Color(0.25, 0.27, 0.23)), null)
		var p = met.global_position + dv * R * 1.02
		_put(host, mi, p)
		var sz = R * randf_range(0.04, 0.1)
		mi.scale = Vector3.ONE * sz
		mi.rotation = Vector3(randf(), randf(), randf()) * TAU
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + Vector3.UP * randf_range(2.0, 6.0) + dv * R * 0.3, 1.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(2, 3, 1), 1.2)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.5).set_delay(0.7)
		tw.chain().tween_callback(mi.queue_free)


## Çarpış: parlama, krater, dışa koşan toz dalgası, toz sütunu, kalkan kaya levhaları, uçuşan taşlar (k: boy katsayısı)
static func _meteor_impact(pj, host: Node, goal: Vector3, k: float) -> void:
	var lt = OmniLight3D.new()
	lt.light_color = Color(1.0, 0.92, 0.8)
	lt.light_energy = 8.0
	lt.omni_range = 40.0 * k
	_put(host, lt, goal + Vector3.UP * 6.0)
	var ltw = lt.create_tween()
	ltw.tween_property(lt, "light_energy", 0.0, 0.5)
	ltw.tween_callback(lt.queue_free)
	var cr = _decal(host, "crater", CRATER_SHADER, goal + Vector3.UP * 0.08, 13.0 * k, {"prog": 0.0, "fade": 1.0, "seed": randf() * 10.0})
	var ctw = cr.create_tween()
	ctw.tween_method(_pf(cr, "prog"), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ctw.tween_interval(8.0)
	ctw.tween_method(_pf(cr, "fade"), 1.0, 0.0, 1.5)
	ctw.tween_callback(cr.queue_free)
	for q in 20:   # zemine yapışık dışa koşan toz dalgası
		var a = TAU * q / 20.0 + randf() * 0.2
		var dirv = Vector3(cos(a), 0, sin(a))
		_billow(host, goal + dirv * 3.0 * k + Vector3.UP * 1.5, randf_range(5.0, 7.0) * k, 1.8, dirv * 14.0 * k + Vector3.UP * 1.0, Color(0.68, 0.6, 0.5))
	for q in 8:   # yükselen toz sütunu
		var a = randf() * TAU
		_billow(host, goal + Vector3(cos(a), 0, sin(a)) * 2.0 + Vector3.UP * 3.0, randf_range(5.0, 7.0) * k, 2.4, Vector3.UP * randf_range(6.0, 10.0) * k + Vector3(cos(a), 0, sin(a)) * 2.0, Color(0.6, 0.55, 0.48))
	for q in 12:   # krater dudağında kalkan kaya levhaları
		var a = TAU * q / 12.0 + randf() * 0.2
		var dirv = Vector3(cos(a), 0, sin(a))
		var p = pj.gp(goal + dirv * 8.0 * k)
		var mi = _gi(_rock(q % 4, Color(0.4, 0.34, 0.28)), null)
		_put(host, mi, p)
		var sz = Vector3(randf_range(2.0, 3.5), randf_range(1.5, 3.0), randf_range(0.8, 1.4)) * k
		mi.rotation = Vector3(-0.6 + randf() * 0.3, atan2(dirv.x, dirv.z), randf_range(-0.3, 0.3))
		mi.scale = Vector3(sz.x, 0.01, sz.z)
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", sz, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(6.0)
		tw.tween_property(mi, "global_position", p - Vector3.UP * sz.y, 1.2)
		tw.tween_callback(mi.queue_free)
	_chunks(host, goal + Vector3.UP * 2.0, goal.y, 26, 16.0 * k, 1.2 * k, Color(0.36, 0.33, 0.29), 2.0)


# ================================================================== Tsukuyomi
## Mangekyō'da kanlı gözyaşı; göz göze gelince Tsukuyomi dünyası (ekran katmanı: koyular kara, açıklar gri-ak, gökyüzü kızıl,
## ortası hafif kalır), kurbanın arkasında ak çizgili kara çarmıh, çevresinde kara pelerinli, ak konturlu kalabalık (ref);
## kara kılıçlar art arda saplanır, her saplanışta ak kıvılcım ve kan damlası. Gerçek dünyada bir an geçer.
static func tsukuyomi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_eye_glint(pj, c, Color(1.0, 0.1, 0.1), 2.5, true)
	tsukuyomi_core(c, t)


## jutsu.gd j_tsukuyomi gövdesi (mekanik birebir)
static func tsukuyomi_core(c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 20.0)
	if tg == null:
		if c is Player: Hud.msg("Göz göze gelecek hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var gm = Eyes.genjutsu_land(c, tg, true)
	if gm <= 0.0:
		return
	Sfx.play("genjutsu", c.global_position, 0.5)
	var host = c.get_tree().current_scene
	# 1) Tsukuyomi dünyası (oyuncu kullanan ya da kurbansa)
	if c == Game.player or tg == Game.player:
		_tsuki_world(host)
	tg.apply_status("stun", 1.9)
	# 2) çarmıh: kurbanın arkasında kara haç, kurban üstüne gerilir
	var base: Vector3 = tg.global_position
	var back: Vector3 = (base - c.global_position)
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.FORWARD
	var cross = Node3D.new()
	cross.add_child(_gi(_tsuki_cross_mesh(), _flat_vc()))
	host.add_child(cross)
	cross.global_position = base + back * 0.35
	cross.look_at(cross.global_position + back, Vector3.UP)
	cross.scale = Vector3(1, 0.02, 1)
	cross.create_tween().tween_property(cross, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	if tg.get("model"):
		tg.model.play("hit", 0.05, 0.4, true)
	_tsuki_crowd(host, base, -back, 1.75)
	# 3) 72 saat: kara kılıçlar art arda saplanır (dışarıda yalnız bir an)
	var wr = weakref(tg)
	for k in 8:
		c.get_tree().create_timer(0.15 + k * 0.14).timeout.connect(func():
			var n = wr.get_ref()
			if n == null or not is_instance_valid(n):
				return
			var a = (k * 2.3) + randf_range(-0.3, 0.3)
			var side = back.cross(Vector3.UP).normalized()
			var dir = (-back * 0.8 + side * cos(a) * 0.7 + Vector3.UP * sin(a) * 0.4).normalized()   # önden ve yanlardan
			var hitp = n.global_position + Vector3.UP * randf_range(0.9, 1.6)
			var sw = _gi(_tsuki_sword_mesh(), _mat("ghost", GHOST_SHADER))
			sw.set_instance_shader_parameter("body_col", Color(0.02, 0.0, 0.0, 1.0))
			sw.set_instance_shader_parameter("edge_col", Color(0.92, 0.92, 0.92, 1.0))
			sw.set_instance_shader_parameter("fade", 1.0)
			host.add_child(sw)
			var from = hitp - dir * 2.6
			sw.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), from)
			var tw2 = sw.create_tween()
			tw2.tween_property(sw, "global_position", hitp - dir * 0.6, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw2.tween_callback(func():
				_tsuki_stab(host, hitp, dir)
				Sfx.play("throw_kunai", hitp, 0.7))
			tw2.tween_interval(1.5 - k * 0.12)
			tw2.tween_callback(sw.queue_free))
	Combat.popup_text(base + Vector3.UP * 2.8, "72 saat...", Color(0.95, 0.2, 0.2))
	# 4) gerçek dünyada bir an geçti: kurban çöker
	c.get_tree().create_timer(1.75).timeout.connect(func():
		if is_instance_valid(cross):
			var tw3 = cross.create_tween()
			tw3.tween_property(cross, "scale", Vector3(1, 0.02, 1), 0.2)
			tw3.tween_callback(cross.queue_free)
		var n = wr.get_ref()
		if n == null or not is_instance_valid(n) or n.is_dead():
			return
		n.apply_status("stun", 5.0 * gm)
		n.apply_status("fear", 7.0 * gm)
		n.take_hit(Jutsu._inf(c, "tsukuyomi", 2.2 * gm, {"knock": 0.0, "attacker": c, "dir": Vector3.ZERO}))
		if n.get("model"):
			n.model.play("crouch", 0.1, 0.8)
		Combat.popup_text(n.global_position + Vector3.UP * 2.4, "Zihni çöktü", Color(0.9, 0.3, 0.35)))


## Ekran katmanı: Tsukuyomi dünyası (0.12 sn açılır, 1.5 sn kalır, 0.3 sn söner); açılışta kenarlarda kara ışın çizgileri
static func _tsuki_world(host: Node) -> void:
	var cl = CanvasLayer.new()
	cl.layer = 6
	var rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh = Shader.new()
	sh.code = TSUKI_SHADER
	var sm = ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("amount", 0.0)
	sm.set_shader_parameter("intro", 1.0)
	rect.material = sm
	cl.add_child(rect)
	host.add_child(cl)
	var tw = rect.create_tween()
	tw.tween_method(func(x: float): sm.set_shader_parameter("amount", x), 0.0, 1.0, 0.12)
	tw.parallel().tween_method(func(x: float): sm.set_shader_parameter("intro", x), 1.0, 0.0, 0.6)
	tw.tween_interval(1.5)
	tw.tween_method(func(x: float): sm.set_shader_parameter("amount", x), 1.0, 0.0, 0.3)
	tw.tween_callback(cl.queue_free)


## Kara çarmıh (ön yüz +Z): direk + kol, yüzünde ak hız-çizgisi damarları, kenarlarda ince ak kontur (ref)
static func _tsuki_cross_mesh() -> ArrayMesh:
	if _cache.has("tsuki_cross"):
		return _cache["tsuki_cross"]
	var b = MB.new()
	var BLK = Color(0.02, 0.0, 0.0)
	var WH = Color(0.9, 0.9, 0.9)
	b.add("box", Vector3(0, 1.6, 0), Vector3(0.3, 3.4, 0.24), BLK)
	b.add("box", Vector3(0, 2.45, 0), Vector3(2.4, 0.3, 0.24), BLK)
	var rng = RandomNumberGenerator.new()
	rng.seed = 72
	for q in 14:   # direkte dikey çizgiler
		b.add("box", Vector3(rng.randf_range(-0.11, 0.11), rng.randf_range(0.3, 3.1), 0.123), Vector3(0.012, rng.randf_range(0.15, 0.45), 0.004), WH)
	for q in 12:   # kolda yatay çizgiler
		b.add("box", Vector3(rng.randf_range(-1.1, 1.1), 2.45 + rng.randf_range(-0.1, 0.1), 0.123), Vector3(rng.randf_range(0.15, 0.4), 0.012, 0.004), WH)
	for sx in [-1.0, 1.0]:   # kontur
		b.add("box", Vector3(sx * 0.152, 1.15, 0.122), Vector3(0.012, 2.5, 0.006), WH)
		b.add("box", Vector3(sx * 0.152, 3.0, 0.122), Vector3(0.012, 0.6, 0.006), WH)
		b.add("box", Vector3(sx * 0.7, 2.602, 0.122), Vector3(1.1, 0.012, 0.006), WH)
		b.add("box", Vector3(sx * 0.7, 2.298, 0.122), Vector3(1.1, 0.012, 0.006), WH)
		b.add("box", Vector3(sx * 1.202, 2.45, 0.122), Vector3(0.012, 0.3, 0.006), WH)
	_cache["tsuki_cross"] = b.build(null)
	return _cache["tsuki_cross"]


## Kara kılıç (önü -Z): uzun ince ağız + kabza siperi
static func _tsuki_sword_mesh() -> ArrayMesh:
	if _cache.has("tsuki_sword"):
		return _cache["tsuki_sword"]
	var bm = MB.new()
	bm.add("box", Vector3(0, 0, -0.75), Vector3(0.05, 0.12, 1.5), Color.WHITE)
	bm.add("box", Vector3(0, 0, 0.1), Vector3(0.22, 0.05, 0.05), Color.WHITE)
	bm.add("box", Vector3(0, 0, 0.32), Vector3(0.05, 0.05, 0.4), Color.WHITE)
	_cache["tsuki_sword"] = bm.build(null)
	return _cache["tsuki_sword"]


## Kurbanın çevresinde kara pelerinli, ak konturlu, kılıçlı suretler (çağırana bakan taraf boş: görüş kapanmaz)
static func _tsuki_crowd(host: Node, base: Vector3, to_c: Vector3, dur: float) -> void:
	var angs = [70.0, -70.0, 115.0, -115.0, 155.0, -155.0]
	for i in angs.size():
		var d = to_c.rotated(Vector3.UP, deg_to_rad(angs[i]))
		var p = base + d * randf_range(2.5, 3.1)
		var fig = _figure("cloak", Color(0.02, 0.02, 0.02, 0.94), Color(0.92, 0.92, 0.92, 1.0))
		_put(host, fig, p)
		var look = base - p
		look.y = 0.0
		_face_dir(fig, look)
		fig.scale = Vector3(1, 0.05, 1)
		var tw = fig.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(fig, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.1, dur - 0.35 - i * 0.05))
		tw.tween_method(_pf(fig, "fade"), 1.0, 0.0, 0.2)
		tw.tween_callback(fig.queue_free)


## Kılıç saplanışı: geri seken ak kıymıklar + düşen kan damlaları
static func _tsuki_stab(host: Node, hitp: Vector3, dir: Vector3) -> void:
	var sl = _box_mesh("tsuki_sliver", Vector3(0.015, 0.015, 0.4), Color(0.95, 0.95, 0.95))
	for k in 3:
		_bit(host, sl, hitp, -dir + Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.8), randf_range(-0.6, 0.6)), randf_range(0.5, 0.9), 0.25, 1.0)
	var dm = _drop_mesh("blood", Color(0.5, 0.0, 0.02))
	for k in 4:
		_bit(host, dm, hitp, Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)), randf_range(0.2, 0.5), 0.4, randf_range(0.04, 0.07), 1.5)


# ================================================================== Kamuibashiri
## Kamui girdabı (arkasındaki görüntüyü büken, ortası kara sarmal) çağıranı yutar; beden saydamlaşıp yolda küçük
## girdap izleri bırakarak süzülür, kolunda savrulan zincir (ref); varınca koldan sivri ağaç dalları fışkırıp hedefi deler.
static func kamuibashiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.9)
	var host = _host(pj)
	_kamui_vortex(host, c.global_position + Vector3.UP * 1.0, 1.0, 0.4)
	_eye_glint(pj, c, Color(1.0, 0.12, 0.1), 1.0)
	if c is Player:
		Buffs.add("kamuibashiri", 0.9, {"armor": 0.0, "_name": "Kamui Koşusu", "_desc": "saldırılar içinden geçer"})
		c.combat.invuln = maxf(c.combat.invuln, 0.6)
	var m = c.get("model")
	MsArts.ghost(m, 0.55)
	var d = pj.fwd(c, t)
	var dest = pj.gp(tt.global_position - (tt.global_position - c.global_position).normalized() * 1.6) if tt else pj.gp(c.global_position + d * 12.0)
	_kamui_chain(c, d, 0.5)
	pj.every(0.45, 0.09, func(_i, _k):
		if is_instance_valid(c):
			_kamui_vortex(host, c.global_position + Vector3.UP * 1.0, 0.6, 0.25), Callable())
	var tw = c.create_tween()
	tw.tween_property(c, "global_position", dest, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		MsArts.ghost(m, 0.0)
		if not pj.live(c):
			return
		if tt and pj.live(tt):
			pj._face(c, tt)
		pj.anim(c, "jab", 1.6)
		var hand = Jutsu._hand(c)
		var aim = (tt.global_position + Vector3.UP * 1.1) if tt and pj.live(tt) else hand + c.face_dir() * 4.0
		# koldan fışkıran sivri dallar: hedefi delip arkasına uzanır
		for k in 5:
			var dir = (aim - hand).normalized().rotated(Vector3.UP, randf_range(-0.25, 0.25))
			dir = (dir + Vector3.UP * randf_range(-0.15, 0.2)).normalized()
			var L = hand.distance_to(aim) + randf_range(1.0, 2.2)
			var br = _gi(_branch_mesh(dir, L), null)
			_put(host, br, hand)
			br.scale = Vector3.ONE * 0.05
			var tw2 = br.create_tween()
			tw2.tween_interval(k * 0.03)
			tw2.tween_property(br, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw2.tween_interval(0.9)
			tw2.tween_property(br, "scale", Vector3.ONE * 0.05, 0.25)
			tw2.tween_callback(br.queue_free)
		_splinters(host, aim, (aim - hand).normalized())
		pj.hit(c, aim, 2.0, pj.inf(c, "kamuibashiri", 1.8, {"knock": 10.0, "kind": "heavy", "stun": 0.6, "bleed": 3.0, "element": "mokuton"})))
	Sfx.play("wind", c.global_position, 1.8, 0.5)


## Kamui girdabı: açılır (büküm artar), döner, kapanır
static func _kamui_vortex(host: Node, pos: Vector3, r: float, dur: float) -> void:
	var mi = _gi(_quad(), _mat("spiral", SPIRAL_SHADER))
	mi.set_instance_shader_parameter("twist", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("spin", 1.0 if randf() < 0.5 else -1.0)
	_put(host, mi, pos)
	mi.scale = Vector3.ONE * r
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "twist"), 0.0, 1.0, dur * 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur * 0.35)
	tw.tween_method(_pf(mi, "twist"), 1.0, 0.0, dur * 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * r * 0.2, dur * 0.3)
	tw.tween_callback(mi.queue_free)


## Kolda savrulan zincir (çağırana bağlı; koşu boyunca arkaya dalgalanır, sonra toplanır)
static func _kamui_chain(c: Node3D, d: Vector3, dur: float) -> void:
	if not _cache.has("chain"):
		var b = MB.new()
		for k in 20:
			var z = k * 0.13
			var y = -sin(k / 19.0 * PI) * 0.35
			b.add("torus", Vector3(0, y, z), Vector3(0.07, 0.07, 0.13), Color(0.22, 0.22, 0.24), Vector3(0, 0, 90.0 * (k % 2)), 8)
		_cache["chain"] = b.build(Props.toon())
	var holder = Node3D.new()
	c.add_child(holder)
	holder.global_position = c.global_position + Vector3.UP * 1.25 + d.cross(Vector3.UP).normalized() * 0.35
	_face_dir(holder, d)   # zincir +Z boyunca: arkaya uzanır
	var mi = _gi(_cache["chain"], null)
	holder.add_child(mi)
	mi.scale = Vector3(1, 1, 0.1)
	var tw = holder.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "rotation:z", 0.6, dur * 0.5).as_relative()
	tw.tween_property(holder, "rotation:z", -1.0, dur * 0.5).as_relative()
	tw.tween_property(mi, "scale", Vector3(1, 1, 0.05), 0.15)
	tw.tween_callback(holder.queue_free)


## Sivri dal ağı (yerel, elden dir boyunca L): kabuk çizgili gövde, yan filizler, açık uç
static func _branch_mesh(dir: Vector3, L: float) -> ArrayMesh:
	var mb = MB.new()
	var pts = []
	var rr = []
	var cols = []
	var bend = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)) * 0.25
	for j in 9:
		var u = j / 8.0
		pts.append(dir * L * u + bend * sin(u * PI))
		var w = lerpf(0.12, 0.008, u)
		rr.append(Vector2(w, w))
		cols.append(WOOD.darkened(0.25 if j % 2 == 0 else 0.0).lerp(Color(0.78, 0.66, 0.46), u * u))
	Loft.tube(mb, pts, rr, cols, 6, 2)
	for q in 3:   # yan filizler
		var u = randf_range(0.3, 0.75)
		var p = dir * L * u + bend * sin(u * PI)
		var sd = dir.cross(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))).normalized()
		Loft.tube(mb, [p, p + (sd * 0.6 + dir * 0.5).normalized() * randf_range(0.25, 0.5)], [0.035, 0.005], WOOD.darkened(0.15), 4, 1)
	return mb.build(Props.toon())


## Delinen yerden ileri savrulan kıymıklar
static func _splinters(host: Node, aim: Vector3, d: Vector3) -> void:
	var sp = _box_mesh("splinter", Vector3(0.03, 0.03, 0.28), WOOD.lightened(0.15))
	for k in 12:
		_bit(host, sp, aim, d + Vector3(randf_range(-0.7, 0.7), randf_range(-0.2, 0.9), randf_range(-0.7, 0.7)), randf_range(1.0, 2.4), 0.45, randf_range(0.7, 1.3), 1.4)


# ================================================================== Tensha Fūin: Amaterasu
## Mühür göze yerleşir: dönen mürekkep yazı halkası ve içinde Mangekyō deseni yüzün önünden göze çekilir; kanlı gözyaşı (ref).
## Hedef görüldüğü an gözün önünde Itachi Mangekyō deseni açılır, gözden hedefe kara alev dilleri fışkırır, ardından gerçek
## Amaterasu (Jutsu.j_amaterasu) tetiklenir.
static func tensha_fuin_amaterasu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_eye_glint(pj, c, Color(1.0, 0.12, 0.08), 1.5, true)
	tensha_core(c, t)


## jutsu.gd j_tensha_fuin_amaterasu gövdesi (mekanik birebir)
static func tensha_core(c: Node3D, t: Node3D) -> void:
	var mark = Jutsu._tg(c, t, 60.0)
	if mark == null:
		if c is Player:
			Hud.msg("Tensha Fūin: mühürlenecek hedef yok (kilitle ya da yakına gel).", Color(0.8, 0.8, 0.8))
		return
	Sfx.play("seal", c.global_position, 0.8)
	_tensha_seal(c)
	if c is Player:
		Hud.msg("Tensha Fūin: %s gözüne girdiği an Amaterasu kendiliğinden yanacak." % String(mark.get("display_name") if mark.get("display_name") != null else "hedef"), Color(0.8, 0.5, 1.0))
	var st = {"fired": false, "armed": false, "seen": false}
	var wr = weakref(mark)
	Jutsu._ticks(int(90.0 / 0.25), 0.25, func(i):
		if st["fired"] or not is_instance_valid(c):
			return
		var m = wr.get_ref()
		if m == null or m.is_dead():
			st["fired"] = true
			return
		var v: Vector3 = m.global_position - c.global_position
		var seen = v.length() < 30.0 and c.face_dir().dot(Vector3(v.x, 0, v.z).normalized()) > 0.45
		if not st["armed"]:
			# kurulma: 3 sn geçince ya da hedef bir kez görüşten çıkınca
			if i >= 12 or not seen:
				st["armed"] = true
			return
		if seen:
			st["fired"] = true
			Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Amaterasu!", Color(0.85, 0.35, 0.95))
			_tensha_burst(c, m)
			Jutsu.j_amaterasu(c, m))


static func _eye_pos(c: Node3D) -> Vector3:
	return c.global_position + Vector3.UP * 1.65 + c.face_dir() * 0.12


## Mührün göze girişi: yazı halkası + Mangekyō deseni yüzün önünden dönerek göze küçülür
static func _tensha_seal(c: Node3D) -> void:
	var host = c.get_tree().current_scene
	var fd: Vector3 = c.face_dir()
	var eye = _eye_pos(c)
	var holder = Node3D.new()
	_put(host, holder, eye + fd * 0.7)
	_face_dir(holder, -fd)   # desen yüzü (+Z) dışarı bakar
	var ring = _gi(_quad(), _mat("inkring", INKRING_SHADER))
	ring.set_instance_shader_parameter("fade", 1.0)
	holder.add_child(ring)
	var pat = _gi(_quad(), _mat("eye", EYE_SHADER))
	pat.set_instance_shader_parameter("mode", 2.0)
	pat.set_instance_shader_parameter("fade", 1.0)
	pat.scale = Vector3.ONE * 0.62
	holder.add_child(pat)
	holder.scale = Vector3.ONE * 0.05
	var tw = holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE * 0.45, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "rotation:z", TAU, 0.6).as_relative()
	tw.tween_interval(0.15)
	tw.tween_property(holder, "global_position", eye, 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(holder, "scale", Vector3.ONE * 0.02, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)


## Tetiklenme: Mangekyō deseni gözün önünde açılır + gözden hedefe kara alev dilleri
static func _tensha_burst(c: Node3D, m: Node3D) -> void:
	var host = c.get_tree().current_scene
	var fd: Vector3 = c.face_dir()
	var eye = _eye_pos(c)
	var pat = _gi(_quad(), _mat("eye", EYE_SHADER))
	pat.set_instance_shader_parameter("mode", 1.0)
	pat.set_instance_shader_parameter("fade", 1.0)
	pat.set_instance_shader_parameter("rot", 0.0)
	_put(host, pat, eye + fd * 0.35)
	_face_dir(pat, -fd)
	pat.scale = Vector3.ONE * 0.05
	var tw = pat.create_tween()
	tw.tween_property(pat, "scale", Vector3.ONE * 0.6, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(pat, "rot"), 0.0, 2.0, 0.35)
	tw.tween_interval(0.1)
	tw.tween_property(pat, "scale", Vector3.ONE * 0.02, 0.12)
	tw.tween_callback(pat.queue_free)
	var to = (m.global_position + Vector3.UP * 1.0 - eye)
	var dl = to.length()
	for k in 3:
		var d = (to.normalized() + Vector3(randf_range(-0.08, 0.08), randf_range(-0.05, 0.08), randf_range(-0.08, 0.08))).normalized()
		# gözden hedefe uzanan opak kara alev dili (Amaterasu kara paleti)
		var L = minf(dl, 6.0) * randf_range(0.6, 1.0)
		var tg = KatonLib.tongue_mi(L * 0.2, 0.3, d, KatonLib.PAL_BLACK, 2, 0.0, 1.15)
		_put(host, tg, eye + fd * 0.2)
		var b0 = tg.basis
		var tw2 = tg.create_tween()
		tw2.tween_property(tg, "basis", KatonLib.axis_basis(d) * Basis.from_scale(Vector3(0.36, L, 0.36)), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw2.tween_method(KatonLib.pf(tg, "heat"), 1.15, 0.0, 0.35)
		tw2.tween_callback(tg.queue_free)
		var _u = b0


# ================================================================== Magen: Kyō Tenchi-ten
## Kızıl Sharingan parıltısı; yüzün önünde kızıl çerçeveli gümüş ayna belirir (yansıyan Sharingan), ters döner — genjutsu
## yansıtılır — çatlayıp kırılır, parçaları saçılır. Kalkan süresince başın çevresinde üç kara tomoe döner.
static func magen_kyo_tenchi_ten(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var DUR = 6.0
	_eye_glint(pj, c, Color(1.0, 0.12, 0.12), DUR)
	if c is Player:
		Buffs.add("magen_kyo", DUR, {"_name": "Kyō Tenchi-ten", "_desc": "sana yapılan genjutsu saldırana geri döner"})
	else:
		c.set_meta("kyo_until", Time.get_ticks_msec() + int(DUR * 1000.0))
	var host = _host(pj)
	var face = Jutsu._mouth(c) + Vector3.UP * 0.12
	_kyo_mirror(host, face, c.face_dir())
	_tomoe_orbit(pj, c, DUR)
	Sfx.play("genjutsu", c.global_position, 1.2)


static func _kyo_mirror(host: Node, face: Vector3, fd: Vector3) -> void:
	var holder = Node3D.new()
	_put(host, holder, face + fd * 0.7)
	_face_dir(holder, -fd)   # ayna yüzü (+Z) dışarı
	var mi = _gi(_quad(), _mat("mirror", MIRROR_SHADER))
	mi.set_instance_shader_parameter("prog", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	holder.add_child(mi)
	mi.scale = Vector3(0.02, 0.55, 1)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.38, 0.55, 1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "rotation:y", PI, 0.3).as_relative().set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(_pf(mi, "prog"), 0.0, 1.0, 0.15)
	tw.tween_callback(func():
		var sh = _shard_mesh()
		var p0 = mi.global_position
		for k in 8:
			var d = fd + Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 0.8), randf_range(-0.8, 0.8))
			_bit(host, sh, p0 + Vector3(randf_range(-0.25, 0.25), randf_range(-0.4, 0.4), 0), d, randf_range(0.5, 1.1), 0.4, randf_range(0.12, 0.22), 1.0))
	tw.tween_callback(holder.queue_free)


static func _shard_mesh() -> ArrayMesh:
	if not _cache.has("mirror_shard"):
		var b = MB.new()
		b.add("prism", Vector3.ZERO, Vector3(0.8, 1.0, 0.05), Color(0.85, 0.88, 0.94))
		b.add("prism", Vector3(0, 0, 0.03), Vector3(0.5, 0.6, 0.02), Color(0.7, 0.08, 0.08))
		_cache["mirror_shard"] = b.build(null)
	return _cache["mirror_shard"]


## Kalkan süresince başın çevresinde dönen üç kara tomoe (kızıl konturlu)
static func _tomoe_orbit(pj, c: Node3D, dur: float) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb == null:
		return
	if not _cache.has("tomoe"):
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.06, 0.06, 0.06), Color.WHITE, Vector3.ZERO, 10)
		Loft.tube(b, [Vector3(0.0, 0.0, 0.0), Vector3(0.03, 0.0, 0.04), Vector3(0.0, 0.0, 0.085)], [0.026, 0.016, 0.003], Color.WHITE, 6, 2)
		_cache["tomoe"] = b.build(null)
	var ring = Node3D.new()
	hb.add_child(ring)
	ring.position = Vector3(0, 0.12, 0)
	for k in 3:
		var a = k * TAU / 3.0
		var mi = _gi(_cache["tomoe"], _mat("ghost", GHOST_SHADER))
		mi.set_instance_shader_parameter("body_col", Color(0.03, 0.0, 0.0, 1.0))
		mi.set_instance_shader_parameter("edge_col", Color(0.9, 0.1, 0.1, 1.0))
		mi.set_instance_shader_parameter("fade", 1.0)
		ring.add_child(mi)
		mi.position = Vector3(cos(a) * 0.3, 0, sin(a) * 0.3)
		mi.rotation.y = -a
	ring.create_tween().tween_property(ring, "rotation:y", TAU * dur * 0.8, dur)
	pj.free_after(dur, hb)


# ================================================================== Kyōsō Enbu
## Gerçek Susanoo kılıcı (Susanoo malzemesi) atılır: kılıcın arkasında Susanoo renginde, ucu ak çizgili kendi şerit izi;
## hedefte dönerek biçerken her vuruşta farklı açıda hilal kesik parlar.
static func kyoso_enbu(_pj, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "kyoso_enbu")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var aim = MsArts._aim_fn(c, tg, 22.0 + H * 0.6)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	MsArts._pj().busy(c, 1.2)
	MsArts._anim(c, "slash_c", 1.0)
	sn.hide_weapons(2.6)
	# kurulma: kılıç omuz arkasına çekilir
	sn.pose({"arms": Susanoo.arm(true, side * 0.6 - d * 0.6 + Vector3.UP * 0.4, -side * 0.5 + Vector3.UP * 0.6 - d * 0.3)}, 0.6)
	var mb = MB.new()
	mb.add("box", Vector3(0, 0, -0.85), Vector3(0.05, 0.14, 1.7), Color.WHITE)
	mb.add("cone", Vector3(0, 0, -1.8), Vector3(0.05, 0.25, 0.14), Color.WHITE, Vector3(-90, 0, 0), 4)
	mb.add("box", Vector3(0, 0, 0.05), Vector3(0.3, 0.06, 0.06), Color.WHITE)
	mb.add("cyl", Vector3(0, 0, 0.3), Vector3(0.05, 0.45, 0.05), Color.WHITE, Vector3(90, 0, 0), 8)
	var sw = sn.chakra_mesh(mb, 1.7)
	var host = MsArts._scene()
	host.add_child(sw)
	sw.global_position = sn.hand(true)
	sw.scale = Vector3.ONE * S * 1.2
	_blade_ribbon(host, sw, col, 3.2)
	MsArts._later(0.45, func():
		if not (is_instance_valid(c) and is_instance_valid(sw) and is_instance_valid(sn)):
			if is_instance_valid(sw):
				sw.queue_free()
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad)}, 0.5, true)
		var from = sw.global_position
		var to: Vector3 = aim.call()
		var dist = from.distance_to(to)
		var go = clampf(dist / 55.0, 0.2, 0.9)
		var hits = []
		var inf = Jutsu._inf(c, "kyoso_enbu", 0.6, {"knock": 10.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.05})
		var o = {"sw": sw}
		var tw = sw.create_tween()
		# git — hedefte dönerek biç — geri dön
		tw.tween_method(func(x: float):
			if is_instance_valid(o["sw"]):
				var p = from.lerp(to, x) + Vector3.UP * sin(x * PI) * S * 0.4
				o["sw"].global_position = p
				o["sw"].global_basis = Basis(Vector3.UP, x * TAU * 5.0) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3.ONE * S * 1.2)
				if is_instance_valid(c):
					for h in Combat.hit_sphere(c, p, 1.5 + S * 0.35, inf, hits):
						hits.append(h), 0.0, 1.0, go)
		tw.tween_method(func(x: float):
			if is_instance_valid(o["sw"]):
				o["sw"].global_basis = Basis(Vector3.UP, x * TAU * 4.0) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3.ONE * S * 1.2)
				if is_instance_valid(c) and int(x * 8.0) != int((x - 0.02) * 8.0):
					Combat.hit_sphere(c, to, 1.8 + S * 0.4, Jutsu._inf(c, "kyoso_enbu", 0.25, {"knock": 4.0, "kind": "heavy", "bleed": 2.0}))
					_crescent(host, to, S, col)
			, 0.0, 1.0, 0.6)
		tw.tween_method(func(x: float):
			if is_instance_valid(o["sw"]) and is_instance_valid(sn):
				o["sw"].global_position = to.lerp(sn.hand(true), x)
				o["sw"].global_basis = Basis(Vector3.UP, x * TAU * 4.0) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3.ONE * S * 1.2), 0.0, 1.0, go)
		tw.tween_callback(sw.queue_free)
		Sfx.play("blade", from, 0.6))


## Kılıcın kökü ile ucu arasında, her karede yeniden örülen, yaşla sönen şerit
static func _blade_ribbon(host: Node, sw: Node3D, col: Color, total: float) -> void:
	var im = ImmediateMesh.new()
	var mi = _gi(im, _mat("ribbon", RIBBON_SHADER))
	mi.set_instance_shader_parameter("tint", col.lightened(0.2))
	mi.set_instance_shader_parameter("fade", 1.0)
	host.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var hist: Array = []
	var tw = mi.create_tween()
	tw.tween_method(func(_x: float):
		if not is_instance_valid(mi):
			return
		if is_instance_valid(sw) and sw.is_inside_tree():
			var xf = sw.global_transform
			hist.push_front([xf * Vector3(0, 0, -0.2), xf * Vector3(0, 0, -1.9)])
			if hist.size() > 14:
				hist.pop_back()
		elif hist.size() > 0:
			hist.pop_back()
		im.clear_surfaces()
		if hist.size() < 2:
			return
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in hist.size():
			var u = float(i) / float(hist.size() - 1)
			im.surface_set_color(Color(1, 1, 1, 1.0 - u))
			im.surface_set_uv(Vector2(u, 0.0))
			im.surface_add_vertex(hist[i][0])
			im.surface_set_color(Color(1, 1, 1, 1.0 - u))
			im.surface_set_uv(Vector2(u, 1.0))
			im.surface_add_vertex(hist[i][1])
		im.surface_end(), 0.0, 1.0, total)
	tw.tween_callback(mi.queue_free)


## Hilal kesik ağı (XY düzleminde, ortası kalın uçları sivri; COLOR.a uçlarda söner, UV.y dış kenar)
static func _crescent_mesh() -> ArrayMesh:
	if _cache.has("crescent"):
		return _cache["crescent"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N = 24
	for i in N:
		var verts = []
		for j in [i, i + 1]:
			var u = float(j) / N
			var a = lerpf(-1.25, 1.25, u)
			var th = 0.2 * sin(u * PI)
			verts.append([Vector3(cos(a), sin(a), 0), Vector3(cos(a), sin(a), 0) * (1.0 - th), sin(u * PI), u])
		var A = verts[0]
		var B = verts[1]
		for tri in [[A, 0, A, 1, B, 0], [B, 0, A, 1, B, 1]]:
			for q in 3:
				var vv = tri[q * 2]
				var which = tri[q * 2 + 1]
				st.set_color(Color(1, 1, 1, vv[2]))
				st.set_uv(Vector2(vv[3], 1.0 if which == 0 else 0.0))
				st.add_vertex(vv[which])
	_cache["crescent"] = st.commit()
	return _cache["crescent"]


## Tek hilal kesik: rastgele açıda parlar, büyüyüp söner
static func _crescent(host: Node, to: Vector3, S: float, col: Color) -> void:
	var mi = _gi(_crescent_mesh(), _mat("ribbon", RIBBON_SHADER))
	mi.set_instance_shader_parameter("tint", col.lightened(0.3))
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, to)
	mi.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf() * TAU)
	var s0 = S * 0.4 + 1.5
	mi.scale = Vector3.ONE * s0
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * s0 * 1.3, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.22)
	tw.chain().tween_callback(mi.queue_free)
