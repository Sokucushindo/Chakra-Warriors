class_name DojutsuFXD
extends RefCounted
## Dōjutsu grubu D: Tenseigan (Chakra Modu, Kinrin Tensei Baku, Inryoku, Gudōdama Ame), Jōgan (Jigen Kiri, Fūin Kai, Seisen),
## Itachi'nin Susanoo eşyaları (Totsuka no Tsurugi, Yata no Kagami), Magen: Karasu Bunshin, Susanoo: Kai, Kanseitai Susanoo: Kishin.
## Gerçek sistemler: Susanoo.of (kollar, eller, kendi malzemesi ve matkap kılıcı), MsArts testi / kılıç / karga modelleri,
## karakterin gerçek bedeni ve kemikleri (Tenseigan örtüsü bedenin kendi ağlarına kaplanır).
## Görünen her efekt bu dosyanın kendi gölgelendiricileri ve geometrisiyle sıfırdan üretilir; ortak / hazır efekt yok.
## Kameraya yakın kısımlar gölgelendiricide incelir (ekranı kaplamaz). Oynanış ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}

const TENSEI := Color(0.62, 0.86, 1.0)
const TENSEI_CORE := Color(0.95, 1.0, 1.0)
const CLOAK := Color(0.45, 0.95, 0.85)
const CLOAK_EDGE := Color(0.08, 0.42, 0.42)
const GOLD := Color(1.0, 0.8, 0.3)
const GOLD_CORE := Color(1.0, 0.97, 0.8)
const GOLD_EDGE := Color(0.5, 0.28, 0.03)
const JOGAN := Color(0.38, 0.62, 1.0)
const JOGAN_CORE := Color(0.9, 0.96, 1.0)
const JOGAN_EDGE := Color(0.06, 0.12, 0.42)
const VOIDC := Color(0.03, 0.02, 0.09)
const EARTH := Color(0.45, 0.38, 0.3)
const DUSTC := Color(0.72, 0.65, 0.54)
const CROW_RED := Color(0.85, 0.05, 0.05)


# ================================================================== gölgelendiriciler
## Cel enerji gövdesi (küre, damla, kıymık): iç açık, orta ton, koyu kontur; wob = yüzey dalgalanması
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 c_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c_mid : source_color = vec4(1.0, 0.8, 0.3, 1.0);
instance uniform vec4 c_edge : source_color = vec4(0.4, 0.25, 0.05, 1.0);
instance uniform float fade = 1.0;
instance uniform float wob = 0.0;
instance uniform float seed = 0.0;
void vertex() {
	float t = TIME * 7.0 + seed * 6.28;
	VERTEX += NORMAL * (sin(t + VERTEX.y * 9.0 + VERTEX.x * 5.0) + 0.5 * sin(t * 1.7 + VERTEX.z * 13.0)) * wob;
}
void fragment() {
	float f = abs(dot(normalize(NORMAL), VIEW));
	vec3 col = mix(c_mid.rgb, c_core.rgb, step(0.7, f));
	col = mix(c_edge.rgb, col, smoothstep(0.18, 0.28, f));
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(c_mid.a * fade * nearf, 0.0, 1.0);
}
"""

## Hız / ışık çizgisi (UV.x kuyruk 0 -> baş 1, UV.y enine): baş geniş, kuyruk incelir, ortası parlak
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float fade = 1.0;
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float w = mix(0.25, 1.0, UV.x);
	float body = 1.0 - smoothstep(w * 0.7, w, across);
	float core = 1.0 - smoothstep(0.0, w * 0.35, across);
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = mix(tint.rgb, c_core.rgb, core);
	ALPHA = clamp(body * tint.a * fade * nearf * smoothstep(0.0, 0.35, UV.x), 0.0, 1.0);
}
"""

## Alev dili (COLOR.r = boy oranı): Tenseigan örtüsü ve salınımı
const TONGUE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 c_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c_mid : source_color = vec4(0.45, 0.95, 0.85, 1.0);
instance uniform vec4 c_edge : source_color = vec4(0.08, 0.42, 0.42, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
varying float hu;
void vertex() {
	hu = COLOR.r;
	float t = TIME * 7.0 + seed * 6.28;
	VERTEX.x += (sin(t + VERTEX.y * 4.0) * 0.14 + sin(t * 1.9 + VERTEX.y * 9.0) * 0.05) * hu;
	VERTEX.z += cos(t * 1.4 + VERTEX.y * 5.0) * 0.1 * hu;
}
void fragment() {
	float f = abs(dot(normalize(NORMAL), VIEW));
	float lick = hu + sin(TIME * 10.0 + seed * 5.0 - hu * 9.0) * 0.06;
	vec3 col = mix(c_mid.rgb, c_core.rgb, step(0.62, f) * (1.0 - step(0.55, lick)));
	col = mix(c_edge.rgb, col, smoothstep(0.12, 0.24, f));
	float tip = 1.0 - smoothstep(0.8, 0.97, lick);
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(c_mid.a * fade * tip * nearf, 0.0, 1.0);
}
"""

## Tenseigan Chakra Modu örtüsü: karakterin GERÇEK ağlarına kaplama (material_overlay). Kenarda yukarı akan mavi-beyaz
## alev pürüzü, içte ince beyaz tül (ref: Toneri'nin bedenini saran turkuaz-beyaz chakra)
const CLOAK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform float tsg_cloak = 0.0;
uniform vec4 c_rim : source_color = vec4(0.42, 0.95, 0.85, 1.0);
uniform vec4 c_hot : source_color = vec4(0.92, 1.0, 1.0, 1.0);
uniform vec4 c_veil : source_color = vec4(0.78, 1.0, 0.97, 0.2);
varying vec3 wp;
float hsh(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hsh(i), hsh(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hsh(i + vec3(0.0, 1.0, 0.0)), hsh(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hsh(i + vec3(0.0, 0.0, 1.0)), hsh(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hsh(i + vec3(0.0, 1.0, 1.0)), hsh(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * 0.012 * (1.0 + sin(TIME * 6.0 + VERTEX.y * 30.0));
}
void fragment() {
	float f = abs(dot(normalize(NORMAL), VIEW));
	float fl = vn(wp * 5.0 + vec3(0.0, -TIME * 2.4, 0.0));
	float rim = 1.0 - smoothstep(0.3 + fl * 0.3, 0.42 + fl * 0.3, f);
	float hot = 1.0 - smoothstep(0.12, 0.2, f);
	vec3 col = mix(c_veil.rgb, c_rim.rgb, rim);
	col = mix(col, c_hot.rgb, hot * rim);
	float nearf = smoothstep(0.4, 1.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(mix(c_veil.a, 0.92, rim) * tsg_cloak * nearf, 0.0, 1.0);
}
"""

## Ortak gürültü işlevleri (aşağıdaki düzlem gölgelendiricilerine eklenir)
const NOISE2 := """
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x), mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}
float ln(float d, float w) { return 1.0 - smoothstep(w, w * 1.5, d); }
"""

## Genişleyen ince basınç halkası (kenarı tozlu pürüzlü), içinde sönen iz
const WAVE_BODY := """
instance uniform vec4 tint : source_color = vec4(0.6, 0.85, 1.0, 1.0);
instance uniform float prog = 0.5;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float n = vn(vec2(ang * 4.0 + seed, prog * 3.0));
	float w = 0.03 + 0.07 * (1.0 - prog);
	float R = prog * (0.94 + 0.06 * n);
	float band = 1.0 - smoothstep(w * 0.5, w, abs(r - R));
	float edge = 1.0 - smoothstep(w * 0.15, w * 0.35, abs(r - R - w * 0.4));
	float trail = (1.0 - smoothstep(0.0, max(prog, 0.01), R - r)) * step(r, R) * 0.25 * (1.0 - prog);
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = mix(tint.rgb, vec3(1.0), edge * 0.7);
	ALPHA = clamp(max(band * (0.55 + 0.45 * n), trail) * fade * nearf * tint.a, 0.0, 1.0);
}
"""

## Zemin yarası: çökük orta, kabarık kenar, ışınsal çatlaklar (rays adet, boyları rastgele)
const SCAR_BODY := """
instance uniform vec4 tint : source_color = vec4(0.3, 0.25, 0.2, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float rays = 10.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float n = vn(vec2(ang * 2.5 + seed, seed * 0.3));
	float pit = 1.0 - smoothstep(0.32 + 0.12 * n, 0.4 + 0.12 * n, r);
	float rim = 1.0 - smoothstep(0.0, 0.07, abs(r - (0.46 + 0.12 * n)));
	float a = ang / 6.2831853 * rays + (vn(vec2(r * 5.0, seed + 7.0)) - 0.5) * 0.6;
	float cid = floor(a);
	float clen = 0.5 + 0.45 * hsh(vec2(cid, seed));
	float da = abs(fract(a) - 0.5) / rays * 6.2831853 * r;
	float crack = (1.0 - smoothstep(0.004, 0.016 * (1.3 - r), da)) * step(r, clen) * step(0.3, r);
	vec3 col = tint.rgb * 0.5;
	col = mix(col, tint.rgb * 1.25, rim * (1.0 - pit));
	col = mix(col, vec3(0.05, 0.04, 0.04), crack);
	float al = max(max(pit * 0.8, rim * 0.6), crack);
	ALBEDO = col;
	ALPHA = clamp(al * fade * (1.0 - smoothstep(0.85, 1.0, r)), 0.0, 1.0);
}
"""

## Kinrin: altın tekerlek (dış diş halkası, iç halka, 12 parmaklık, göbek, nokta yazılar); kendi ekseninde döner
const WHEEL_BODY := """
instance uniform float fade = 1.0;
instance uniform float spd = 1.0;
uniform vec4 c_gold : source_color = vec4(1.0, 0.8, 0.28, 1.0);
uniform vec4 c_hot : source_color = vec4(1.0, 0.97, 0.78, 1.0);
uniform vec4 c_dark : source_color = vec4(0.42, 0.22, 0.02, 1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x) + TIME * spd;
	float fill = ln(abs(r - 0.93), 0.03);
	fill = max(fill, ln(abs(r - 0.84), 0.01));
	fill = max(fill, ln(abs(r - 0.6), 0.016));
	fill = max(fill, ln(abs(r - 0.18), 0.02));
	float sp = ln(abs(sin(ang * 6.0)) * r, 0.012) * step(0.18, r) * step(r, 0.6);
	fill = max(fill, sp);
	float tooth = step(0.55, fract(ang * 36.0 / 6.2831853)) * step(0.84, r) * step(r, 0.93);
	fill = max(fill, tooth * 0.9);
	float dots = ln(length(vec2((fract(ang * 12.0 / 6.2831853) - 0.5) * 0.6, (r - 0.72) * 3.0)), 0.09);
	fill = max(fill, dots);
	float outl = max(ln(abs(r - 0.93), 0.05), ln(abs(r - 0.6), 0.03));
	vec3 col = mix(c_dark.rgb, c_gold.rgb, step(0.5, fill));
	col = mix(col, c_hot.rgb, ln(abs(r - 0.93), 0.012));
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(max(fill, outl * 0.7) * fade * nearf * (1.0 - step(1.0, r)), 0.0, 1.0);
}
"""

## Jōgan mühür ağı: üçgen kafes; prog yarıçapında dalga bandı, disc yarıçapına kadar dolu, crack ile hücre hücre kırılır
const LATTICE_BODY := """
instance uniform float prog = 0.0;
instance uniform float disc = 0.0;
instance uniform float crack = 0.0;
instance uniform float fade = 1.0;
uniform vec4 c_line : source_color = vec4(0.5, 0.75, 1.0, 1.0);
uniform vec4 c_hot : source_color = vec4(0.92, 0.97, 1.0, 1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	vec2 p = q * 11.0;
	float a1 = p.x;
	float a2 = dot(p, vec2(0.5, 0.8660254));
	float a3 = dot(p, vec2(-0.5, 0.8660254));
	float l = max(max(abs(fract(a1) - 0.5), abs(fract(a2) - 0.5)), abs(fract(a3) - 0.5));
	float lines = smoothstep(0.42, 0.47, l);
	float cell = hsh(floor(vec2(a1, a2)) + vec2(floor(a3) * 0.37, 0.0));
	float keep = step(crack, cell);
	float band = 1.0 - smoothstep(0.0, 0.09, abs(r - prog));
	float inner = 1.0 - smoothstep(disc - 0.04, disc, r);
	float ring = (1.0 - smoothstep(0.004, 0.012, abs(r - prog - 0.05))) * step(0.02, prog);
	float ring2 = (1.0 - smoothstep(0.004, 0.012, abs(r - disc))) * step(0.01, disc);
	float m = lines * max(band, inner) * keep;
	vec3 col = mix(c_line.rgb, c_hot.rgb, max(ring, ring2));
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(max(m * 0.85, max(ring, ring2 * keep)) * fade * nearf * (1.0 - step(1.0, r)), 0.0, 1.0);
}
"""

## İçe kıvrılan çekim sarmalı (Inryoku avuç merceği)
const SPIRAL_BODY := """
instance uniform vec4 tint : source_color = vec4(0.62, 0.86, 1.0, 1.0);
instance uniform float fade = 1.0;
instance uniform float spd = 4.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float s = fract(ang / 6.2831853 * 4.0 + log(max(r, 0.02)) * 1.6 + TIME * spd);
	float w = 0.06 + 0.16 * r;
	float arm = 1.0 - smoothstep(w, w + 0.06, abs(s - 0.5));
	float hot = 1.0 - smoothstep(w * 0.2, w * 0.5, abs(s - 0.5));
	float core = 1.0 - smoothstep(0.08, 0.13, r);
	float m = max(arm * smoothstep(0.05, 0.25, r), core) * (1.0 - smoothstep(0.75, 1.0, r));
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = mix(tint.rgb, vec3(1.0), max(hot, core));
	ALPHA = clamp(m * fade * nearf, 0.0, 1.0);
}
"""

## Boyut yarığı: dikey, tırtıklı yırtık; içi yıldızlı karanlık boşluk, kenarı açık mavi-beyaz, dışında ince hale
const RIFT_BODY := """
instance uniform float open = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
uniform vec4 c_edge : source_color = vec4(0.78, 0.92, 1.0, 1.0);
uniform vec4 c_glow : source_color = vec4(0.3, 0.55, 1.0, 1.0);
uniform vec4 c_void : source_color = vec4(0.02, 0.01, 0.07, 1.0);
void fragment() {
	float y = UV.y * 2.0 - 1.0;
	float x = UV.x * 2.0 - 1.0;
	float prof = 1.0 - y * y;
	float jag = (hsh(vec2(floor(UV.y * 22.0), seed)) - 0.5) * 0.3 + (vn(vec2(UV.y * 9.0 + seed, TIME * 2.0)) - 0.5) * 0.25;
	float w = open * prof * 0.5;
	float cx = x - jag * prof * 0.4;
	float d = abs(cx) - w;
	float inside = 1.0 - step(0.0, d);
	float rim = 1.0 - smoothstep(0.0, 0.03 + 0.04 * open, abs(d));
	float halo = (1.0 - smoothstep(0.0, 0.3, d)) * step(0.0, d) * 0.4 * open;
	float stars = step(0.975, hsh(floor(UV * vec2(36.0, 80.0)) + seed));
	float swirl = vn(vec2(cx * 6.0 + TIME, y * 4.0 - TIME * 0.7)) * 0.25;
	vec3 col = c_void.rgb + vec3(0.1, 0.06, 0.3) * swirl + vec3(0.8, 0.9, 1.0) * stars;
	col = mix(col, c_glow.rgb, halo * (1.0 - inside));
	col = mix(col, c_edge.rgb, rim);
	float ends = 1.0 - smoothstep(0.86, 1.0, abs(y));
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(max(inside, max(rim, halo)) * ends * fade * nearf, 0.0, 1.0);
}
"""

## Seisen ruh ışını: eksen boyunca (yerel Y) akan bantlar; reach ile uç ilerler
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 c_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c_mid : source_color = vec4(0.45, 0.7, 1.0, 1.0);
instance uniform vec4 c_edge : source_color = vec4(0.1, 0.2, 0.6, 1.0);
instance uniform float fade = 1.0;
instance uniform float reach = 1.0;
instance uniform float span = 1.0;
instance uniform float wlen = 40.0;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	float u = ly / span;
	if (u > reach) { discard; }
	float f = abs(dot(normalize(NORMAL), VIEW));
	float bands = step(0.6, fract(u * wlen * 0.35 - TIME * 9.0));
	vec3 col = mix(c_mid.rgb, c_core.rgb, max(step(0.6, f), bands * step(0.3, f)));
	col = mix(c_edge.rgb, col, smoothstep(0.1, 0.22, f));
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(c_mid.a * fade * nearf, 0.0, 1.0);
}
"""

## Totsuka sıvı kılıcı: ağır, dalgalanan sıvı (yerel Z boyunca akan açık çizgiler), Susanoo renginde koyu kontur
const LIQUID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 c_core : source_color = vec4(1.0, 0.95, 0.85, 1.0);
instance uniform vec4 c_mid : source_color = vec4(1.0, 0.45, 0.3, 1.0);
instance uniform vec4 c_edge : source_color = vec4(0.45, 0.08, 0.05, 1.0);
instance uniform float fade = 1.0;
instance uniform float wob = 0.03;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	float t = TIME * 5.0;
	VERTEX += NORMAL * (sin(t + VERTEX.z * 14.0 + VERTEX.y * 6.0) * 0.5 + sin(t * 1.6 - VERTEX.z * 23.0 + VERTEX.x * 9.0) * 0.5) * wob;
}
void fragment() {
	float f = abs(dot(normalize(NORMAL), VIEW));
	float flow = fract(lp.z * 6.0 + lp.y * 2.0 - TIME * 1.8 + sin(lp.x * 20.0) * 0.1);
	float streak = step(0.82, flow) * step(0.45, f);
	vec3 col = mix(c_mid.rgb, c_core.rgb, max(step(0.78, f), streak));
	col = mix(c_edge.rgb, col, smoothstep(0.16, 0.3, f));
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp(c_mid.a * fade * nearf, 0.0, 1.0);
}
"""

## Totsuka sıvısının zemine sıçrayan lekesi (pürüzlü gövde + çevresinde damlalar)
const SPLAT_BODY := """
instance uniform vec4 c_mid : source_color = vec4(1.0, 0.45, 0.3, 1.0);
instance uniform vec4 c_edge : source_color = vec4(0.45, 0.08, 0.05, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float n = vn(vec2(ang * 3.0 + seed, seed));
	float R = 0.36 + 0.24 * n;
	float body = 1.0 - smoothstep(R - 0.02, R, r);
	float inner = 1.0 - smoothstep(R - 0.12, R - 0.1, r);
	vec2 g = q * 7.0 + seed;
	float h = hsh(floor(g));
	float drop = (1.0 - smoothstep(0.16 * h, 0.16 * h + 0.03, length(fract(g) - 0.5))) * step(0.72, h) * step(r, 0.95) * step(R + 0.05, r);
	vec3 col = mix(c_edge.rgb, c_mid.rgb, inner);
	ALBEDO = col;
	ALPHA = clamp(max(body, drop) * fade * 0.9, 0.0, 1.0);
}
"""

## Yata no Kagami ayna yüzü: eşmerkezli ince halkalar (ref), çapraz parıltı, darbede merkezden yayılan halka (ripple)
const MIRROR_BODY := """
instance uniform vec4 tint : source_color = vec4(1.0, 0.5, 0.4, 1.0);
instance uniform float ripple = 0.0;
instance uniform float fade = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) { discard; }
	float g = r * 3.5 - TIME * 0.15 - ripple * 2.0;
	float dl = abs(fract(g + 0.5) - 0.5) / 3.5;
	float lines = 1.0 - smoothstep(0.004, 0.01, dl);
	float rim = 1.0 - smoothstep(0.0, 0.05, 1.0 - r);
	float sheen = smoothstep(0.75, 0.95, sin((q.x + q.y) * 3.0 + 1.0)) * 0.5;
	float burst = (1.0 - smoothstep(0.0, 0.08, abs(r - ripple))) * step(0.001, ripple) * (1.0 - ripple);
	vec3 col = mix(tint.rgb * 0.55, vec3(1.0), clamp(lines * 0.7 + sheen + burst, 0.0, 1.0));
	col = mix(col, tint.rgb * 1.2, rim);
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = clamp((0.38 + lines * 0.45 + sheen * 0.3 + burst * 0.6 + rim * 0.5) * fade * nearf, 0.0, 1.0);
}
"""

## Kameraya dönük düzlem (yan ölçekleri korur)
const BILLBOARD := """
void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
"""

## Magen yanılsama işareti: kızıl iris, kara göz bebeği, dönen üç tomoe
const TOMOE_BODY := """
instance uniform float fade = 1.0;
instance uniform float spin = 0.0;
uniform vec4 c_red : source_color = vec4(0.85, 0.05, 0.05, 1.0);
uniform vec4 c_ink : source_color = vec4(0.05, 0.0, 0.0, 1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float tom = 0.0;
	for (int k = 0; k < 3; k++) {
		float a = float(k) * 2.0943951 + spin + TIME * 6.0;
		vec2 cc = vec2(cos(a), sin(a)) * 0.5;
		float blob = 1.0 - smoothstep(0.1, 0.125, length(q - cc));
		float da = mod(ang - a + 12.566371, 6.2831853);
		float tail = step(da, 0.9) * (1.0 - smoothstep(0.0, 0.1 * (1.0 - da / 0.9) + 0.01, abs(r - 0.5)));
		tom = max(tom, max(blob, tail));
	}
	float pupil = 1.0 - smoothstep(0.14, 0.17, r);
	float ring = 1.0 - smoothstep(0.0, 0.03, abs(r - 0.5));
	float outer = 1.0 - smoothstep(0.0, 0.035, abs(r - 0.82));
	float ink = max(max(tom, pupil), max(ring * 0.6, outer));
	vec3 col = mix(c_red.rgb, c_ink.rgb, ink);
	ALBEDO = col;
	ALPHA = clamp((1.0 - smoothstep(0.82, 0.86, r)) * fade, 0.0, 1.0);
}
"""

## Fūin Kai mühür kilidi (başın üstünde, mühür süresince): iki halka, dönen dört kol, merkez düğüm
const LOCK_BODY := """
instance uniform float fade = 1.0;
uniform vec4 c_line : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform vec4 c_hot : source_color = vec4(0.95, 0.98, 1.0, 1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x) + TIME * 1.2;
	float ring = ln(abs(r - 0.8), 0.04);
	float ring2 = ln(abs(r - 0.6), 0.015);
	float bars = ln(abs(sin(ang * 2.0)) * r, 0.03) * step(r, 0.6) * step(0.15, r);
	float knots = ln(length(vec2((fract(ang * 8.0 / 6.2831853) - 0.5) * 0.5, (r - 0.8) * 1.0)), 0.06);
	float center = 1.0 - smoothstep(0.12, 0.15, r);
	float m = max(max(ring, ring2), max(max(bars, knots), center));
	ALBEDO = mix(c_line.rgb, c_hot.rgb, max(center, ring));
	ALPHA = clamp(m * fade * (1.0 - step(1.0, r)), 0.0, 1.0);
}
"""

## Cel toz yığını: iki ton, kenarı koyu; fade düştükçe gürültüyle aşınarak dağılır
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.72, 0.65, 0.54, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
varying vec3 lp;
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x), mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { lp = VERTEX; }
void fragment() {
	float f = dot(normalize(NORMAL), VIEW);
	float n = vn(lp.xz * 3.0 + vec2(lp.y * 2.0 + seed, seed));
	vec3 col = mix(tint.rgb * 0.72, tint.rgb * 1.08, step(0.45, f + n * 0.2));
	col = mix(tint.rgb * 0.45, col, smoothstep(0.1, 0.22, f));
	float keep = step(n * 0.85 + 0.1, fade);
	float nearf = smoothstep(0.6, 2.6, -VERTEX.z);
	ALBEDO = col;
	ALPHA = keep * nearf * tint.a;
}
"""

const PLANE_HEAD := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
"""


# ================================================================== yapı taşları
static func _mat(key: String, code: String, prio := 0) -> ShaderMaterial:
	var k = "mat:" + key
	if _cache.has(k):
		return _cache[k]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	m.render_priority = prio
	_cache[k] = m
	return m


## Düzlem gölgelendiricisi: başlık + gürültü + gövde (billboard: kameraya dönük)
static func _pmat(key: String, body: String, billboard := false) -> ShaderMaterial:
	return _mat(key, PLANE_HEAD + NOISE2 + (BILLBOARD if billboard else "") + body)


static func _flat() -> StandardMaterial3D:
	var k = "mat:flat"
	if not _cache.has(k):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[k] = m
	return _cache[k]


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


## Düğümün +Y'si normal yönüne
static func _orient(n: Node3D, normal: Vector3) -> void:
	n.global_basis = _ybasis(normal)


static func _ybasis(normal: Vector3) -> Basis:
	var nn = normal.normalized()
	if nn.length() < 0.5:
		return Basis.IDENTITY
	if nn.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, nn))


## -Z yönü d'ye
static func _face_dir(n: Node3D, d: Vector3) -> void:
	if d.length() < 0.001:
		return
	var dd = d.normalized()
	var up = Vector3.UP if absf(dd.y) < 0.98 else Vector3.RIGHT
	n.global_basis = Basis.looking_at(dd, up)


static func _fade_free(mi: GeometryInstance3D, delay: float, dur: float, pname := "fade") -> void:
	var tw = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_pf(mi, pname), 1.0, 0.0, dur)
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ ağlar
static func _mesh_sph() -> SphereMesh:
	var k = "mesh:sph"
	if not _cache.has(k):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 24
		s.rings = 12
		_cache[k] = s
	return _cache[k]


static func _mesh_quad() -> QuadMesh:
	var k = "mesh:quad"
	if not _cache.has(k):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_cache[k] = q
	return _cache[k]


static func _mesh_plane() -> PlaneMesh:
	var k = "mesh:plane"
	if not _cache.has(k):
		var p = PlaneMesh.new()
		p.size = Vector2(2, 2)
		_cache[k] = p
	return _cache[k]


static func _mesh_thin_torus() -> TorusMesh:
	var k = "mesh:thin_torus"
	if not _cache.has(k):
		var t = TorusMesh.new()
		t.inner_radius = 0.95
		t.outer_radius = 1.0
		t.rings = 40
		t.ring_segments = 6
		_cache[k] = t
	return _cache[k]


## Çapraz iki şerit: z 0 (kuyruk, UV.x 0) -> z -1 (baş, UV.x 1)
static func _mesh_streak() -> ArrayMesh:
	var k = "mesh:streak"
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ax in [Vector3(0.5, 0, 0), Vector3(0, 0.5, 0)]:
		var a = -ax
		var b = ax
		var t1 = Vector3(0, 0, -1)
		var vs = [[a, Vector2(0, 0)], [b, Vector2(0, 1)], [t1 + b, Vector2(1, 1)], [a, Vector2(0, 0)], [t1 + b, Vector2(1, 1)], [t1 + a, Vector2(1, 0)]]
		for v in vs:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	_cache[k] = st.commit()
	return _cache[k]


## Alev dili (+Y boyunca 0..1, COLOR.r = boy oranı); 4 eğrilik çeşidi
static func _mesh_tongue(v: int) -> ArrayMesh:
	var k = "mesh:tongue%d" % v
	if _cache.has(k):
		return _cache[k]
	var bend = [0.0, 0.18, -0.15, 0.08][v % 4]
	var pts = []
	var rr = []
	var cols = []
	for j in 8:
		var u = j / 7.0
		pts.append(Vector3(sin(u * PI) * bend * 0.6 + u * u * bend, u, sin(u * 2.4) * bend * 0.3))
		var w = 0.42 * pow(1.0 - u, 0.8) * (0.6 + 0.4 * sin(u * PI + 0.3)) + 0.004
		rr.append(Vector2(w, w * 0.7))
		cols.append(Color(u, 0, 0))
	var b = MB.new()
	Loft.tube(b, pts, rr, cols, 9, 2, true, false)
	_cache[k] = b.build(null)
	return _cache[k]


## Sıvı ipliği (+Y boyunca 0..1, uca doğru incelip damla ucu)
static func _mesh_drip(v: int) -> ArrayMesh:
	var k = "mesh:drip%d" % v
	if _cache.has(k):
		return _cache[k]
	var bend = [0.12, -0.1, 0.05][v % 3]
	var pts = []
	var rr = []
	for j in 9:
		var u = j / 8.0
		pts.append(Vector3(sin(u * 2.6) * bend, u, cos(u * 3.1) * bend * 0.5))
		var w = 0.12 * (1.0 - u * 0.75) + (0.07 * smoothstep(0.75, 1.0, u))
		rr.append(Vector2(w, w))
	var b = MB.new()
	Loft.tube(b, pts, rr, Color.WHITE, 8, 2)
	b.add("sphere", pts[8], Vector3(0.2, 0.26, 0.2), Color.WHITE, Vector3.ZERO, 8)
	_cache[k] = b.build(null)
	return _cache[k]


static func _mesh_lump() -> ArrayMesh:
	var k = "mesh:lump"
	if not _cache.has(k):
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(1.0, 0.8, 1.0), Color.WHITE, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0.4, 0.2, 0.12), Vector3(0.68, 0.62, 0.68), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(-0.36, 0.16, -0.18), Vector3(0.72, 0.66, 0.72), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.0, 0.4, -0.04), Vector3(0.58, 0.52, 0.58), Color.WHITE, Vector3.ZERO, 10)
		_cache[k] = b.build(null)
	return _cache[k]


static func _mesh_rock(v: int, col: Color, kind := "boulder") -> ArrayMesh:
	var k = "mesh:%s%d_%s" % [kind, v, col.to_html(false)]
	if not _cache.has(k):
		var b = MB.new()
		b.add(kind, Vector3(0, 0.5 if kind == "crag" else 0.0, 0), Vector3.ONE, col, Vector3.ZERO, v + 3)
		_cache[k] = b.build(Props.toon())
	return _cache[k]


## Karga tüyü: sap boyunca açık çizgi, tırtıklı kara bayrak (-Z boyunca 1 birim)
static func _mesh_feather() -> ArrayMesh:
	var k = "mesh:feather"
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ink = Color(0.04, 0.04, 0.06)
	var shaft = Color(0.2, 0.2, 0.25)
	var n = 7
	for side in [-1.0, 1.0]:
		for i in n:
			var z0 = -float(i) / n
			var z1 = -float(i + 1) / n
			var w0 = sin(float(i) / n * PI) * 0.16 + 0.02
			var w1 = sin(float(i + 1) / n * PI) * 0.16 + 0.02
			var pa = Vector3(0, 0, z0)
			var pb = Vector3(0, 0, z1)
			var pc = Vector3(side * w1, 0.0, z1 + 0.07)
			var pd = Vector3(side * w0, 0.0, z0 + 0.07)
			for v in [[pa, shaft], [pb, shaft], [pc, ink], [pa, shaft], [pc, ink], [pd, ink]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	_cache[k] = st.commit()
	return _cache[k]


## Kırık uzay / chakra kıymığı
static func _mesh_shard() -> ArrayMesh:
	var k = "mesh:shard"
	if not _cache.has(k):
		var b = MB.new()
		b.add("prism", Vector3.ZERO, Vector3(0.5, 1.0, 0.14), Color.WHITE)
		_cache[k] = b.build(null)
	return _cache[k]


## Birim silindir: y 0..1, yarıçap 1
static func _mesh_beam() -> ArrayMesh:
	var k = "mesh:beam"
	if not _cache.has(k):
		var b = MB.new()
		b.add("cyl", Vector3(0, 0.5, 0), Vector3(2, 1, 2), Color.WHITE, Vector3.ZERO, 14)
		_cache[k] = b.build(null)
	return _cache[k]


## Seisen ruh sarmalı: 40 m boyunda, yarıçap 0.45 (gerçek boyutta kurulur; ölçeklenmez)
static func _mesh_helix() -> ArrayMesh:
	var k = "mesh:helix"
	if not _cache.has(k):
		var pts = []
		var rr = []
		for j in 241:
			var u = j / 240.0
			var a = u * TAU * 16.0
			pts.append(Vector3(cos(a) * 0.45, u * 40.0, sin(a) * 0.45))
			rr.append(0.045)
		var b = MB.new()
		Loft.tube(b, pts, rr, Color.WHITE, 5, 1)
		_cache[k] = b.build(null)
	return _cache[k]


# ------------------------------------------------------------------ parça üreticiler
static func _cel(mesh: Mesh, core: Color, mid: Color, edge: Color, wob := 0.0) -> MeshInstance3D:
	var mi = _gi(mesh, _mat("cel", CEL_SHADER))
	mi.set_instance_shader_parameter("c_core", core)
	mi.set_instance_shader_parameter("c_mid", mid)
	mi.set_instance_shader_parameter("c_edge", edge)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("wob", wob)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	return mi


## İnce çizgi: from'dan d yönünde L boyunda uzar; travel verilirse o kadar ilerler; life sonunda söner
static func _streak(host: Node, from: Vector3, d: Vector3, L: float, w: float, life: float, tint: Color, core := Color.WHITE, travel := 0.0) -> MeshInstance3D:
	var mi = _gi(_mesh_streak(), _mat("streak", STREAK_SHADER))
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("c_core", core)
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, from)
	_face_dir(mi, d)
	mi.scale = Vector3(w, w, 0.01)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(w, w, L), life * 0.3).set_ease(Tween.EASE_OUT)
	if travel != 0.0:
		tw.tween_property(mi, "global_position", from + d.normalized() * travel, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Zemine yatık desen düzlemi
static func _decal(host: Node, key: String, body: String, pos: Vector3, r: float, params: Dictionary) -> MeshInstance3D:
	var mi = _gi(_mesh_plane(), _pmat(key, body))
	for p in params:
		mi.set_instance_shader_parameter(p, params[p])
	_put(host, mi, pos + Vector3.UP * 0.05)
	mi.scale = Vector3(r, 1.0, r)
	return mi


## Zemin yarası: hold sn durur, dur sn'de söner
static func _scar(host: Node, pos: Vector3, r: float, tint: Color, rays: float, hold: float, dur: float) -> MeshInstance3D:
	var mi = _decal(host, "scar", SCAR_BODY, pos, r, {"tint": tint, "fade": 1.0, "seed": randf() * 50.0, "rays": rays})
	mi.rotation.y = randf() * TAU
	_fade_free(mi, hold, dur)
	return mi


## Tek toz yığını: büyüyerek vel yönünde kayar, sonra aşınarak dağılır
static func _dust(host: Node, pos: Vector3, size: float, life: float, vel: Vector3, tint := DUSTC) -> void:
	var mi = _gi(_mesh_lump(), _mat("dust", DUST_SHADER))
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	_put(host, mi, pos)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3.ONE * size * 0.35
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * size, life * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", pos + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
	tw.chain().tween_callback(mi.queue_free)


## Balistik taş parçaları (gy zemininde durur, sonra küçülüp gider)
static func _chunks(host: Node, at: Vector3, gy: float, n: int, spd: float, size: float, col: Color, life := 1.3, up := 1.0) -> void:
	for i in n:
		var mi = _gi(_mesh_rock(i % 4, col.darkened(float(i % 3) * 0.1)), null)
		_put(host, mi, at)
		var v = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5) * up, randf_range(-1, 1)).normalized() * spd * randf_range(0.5, 1.0)
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


## Tek alev dili: yükselir, incelip uzar, söner
static func _tongue(host: Node, pos: Vector3, w: float, h: float, life: float, core: Color, mid: Color, edge: Color, dir := Vector3.UP) -> MeshInstance3D:
	var mi = _gi(_mesh_tongue(randi() % 4), _mat("tongue", TONGUE_SHADER))
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


## Uçuşan kıymık (kendi etrafında döner, saydamlaşır)
static func _shards(host: Node, at: Vector3, n: int, spd: float, size: float, life: float, core: Color, mid: Color, edge: Color, grav := 0.0) -> void:
	for i in n:
		var mi = _cel(_mesh_shard(), core, mid, edge)
		_put(host, mi, at)
		var v = Vector3(randf_range(-1, 1), randf_range(-0.4, 1.0), randf_range(-1, 1)).normalized() * spd * randf_range(0.5, 1.0)
		mi.scale = Vector3.ONE * size * randf_range(0.6, 1.3)
		mi.rotation = Vector3(randf(), randf(), randf()) * TAU
		var spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var p0 = at
		var r0 = mi.rotation
		var tw = mi.create_tween().set_parallel()
		tw.tween_method(func(x: float):
			if is_instance_valid(mi):
				mi.global_position = p0 + v * (x - 0.35 * x * x) + Vector3.DOWN * grav * x * x
				mi.rotation = r0 + spin * x, 0.0, life, life)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Karga tüyleri: patlayıp yayılır, salınarak süzülür, yerde kısa süre kalıp söner
static func _feathers(host: Node, at: Vector3, n: int, spread: float, life := 2.2) -> void:
	for i in n:
		var mi = _gi(_mesh_feather(), _flat())
		_put(host, mi, at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.6, 0.6), randf_range(-0.3, 0.3)))
		var s = randf_range(0.16, 0.3)
		mi.scale = Vector3.ONE * s
		mi.rotation = Vector3(randf_range(-1.2, 1.2), randf() * TAU, randf_range(-1.2, 1.2))
		var p0 = mi.global_position
		var out = Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized() * spread * randf_range(0.6, 1.4)
		var gy = p0.y - 1.6
		var ph = randf() * TAU
		var r0 = mi.rotation
		var lf = life * randf_range(0.8, 1.2)
		var tw = mi.create_tween().set_parallel()
		tw.tween_method(func(x: float):
			if not is_instance_valid(mi):
				return
			var burst = 1.0 - pow(1.0 - minf(x / 0.35, 1.0), 2.0)
			var p = p0 + out * burst + Vector3.DOWN * maxf(0.0, x - 0.25) * 1.1 + Vector3(sin(x * 7.0 + ph), 0.0, cos(x * 6.0 + ph)) * 0.25 * x
			p.y = maxf(p.y, gy)
			mi.global_position = p
			mi.rotation = r0 + Vector3(sin(x * 6.0 + ph) * 0.8, x * 2.0, cos(x * 5.0 + ph) * 0.6), 0.0, 1.0, lf)
		tw.tween_property(mi, "transparency", 1.0, lf * 0.35).set_delay(lf * 0.65)
		tw.chain().tween_callback(mi.queue_free)


## Göz parıltısı: Tenseigan iki göz mavi-beyaz, Jōgan yalnız sağ göz mavi (baş kemiğine bağlı); açılışta yatay göz parıltısı
static func _eye(pj, c: Node3D, jogan: bool, dur: float, big := 1.0) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb == null:
		return
	var sides = [-1.0] if jogan else [-1.0, 1.0]
	for sx in sides:
		var core = TENSEI_CORE if not jogan else JOGAN_CORE
		var mid = TENSEI if not jogan else JOGAN
		var e = _cel(_mesh_sph(), core, mid, mid.darkened(0.5))
		hb.add_child(e)
		e.position = Vector3(sx * 0.032, 0.065, 0.1)
		e.scale = Vector3(0.016, 0.011, 0.006) * big
		var gl = _streak(hb, Vector3.ZERO, Vector3.RIGHT, 0.45 * big, 0.025, 0.3, mid, core)
		gl.transform = Transform3D(Basis.looking_at(Vector3(sx, 0, 0), Vector3.UP) * Basis.from_scale(Vector3(0.025, 0.025, 0.01)), Vector3(sx * 0.032, 0.065, 0.105))
	pj.free_after(dur, hb)


# ================================================================== TENSEIGAN
## Tenseigan Chakra Modu (ref: Toneri'nin turkuaz-beyaz chakra örtüsü + çevresinde dönen altın arayış topları):
## hazırlık: zeminden bedene akan mavi-beyaz çizgiler; salınım: dışa yalazlanan alev halkası, zeminde soluk iz;
## kalıcı: GERÇEK bedenin ağlarına kaplanan alevli kenar + kemiklere bağlı, koşarken geriye savrulan alev dilleri (20 sn);
## sekiz altın top döner, yakına gelen mermiyi altın parıltıyla siler.
static func tenseigan_chakura_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	_eye(pj, c, false, 20.0)
	var host = _host(pj)
	_cloak_burst(pj, host, pj.gp(c.global_position))
	_body_cloak(pj, c, 20.0)
	var orbit = Node3D.new()
	c.add_child(orbit)
	orbit.position = Vector3(0, 1.4, 0)
	for k in 8:
		var o = _seeker(0.22)
		orbit.add_child(o)
		var a = k * TAU / 8.0
		o.position = Vector3(cos(a) * 1.2, sin(a * 2.0) * 0.2, sin(a) * 1.2)
		o.scale = Vector3.ONE * 0.01
		o.create_tween().tween_property(o, "scale", Vector3.ONE, 0.25).set_delay(0.35 + k * 0.05).set_trans(Tween.TRANS_BACK)
	var spin = orbit.create_tween().set_loops(40)
	spin.tween_property(orbit, "rotation:y", TAU, 1.0).as_relative()
	if c is Player:
		Buffs.add("tenseigan_modo", 20.0, {"melee": 1.3, "speed": 1.15, "armor": 0.75, "jutsu": 1.1, "_name": "Tenseigan Chakra Modu", "_desc": "altın örtü, toplar mermileri siler"})
	pj.every(20.0, 0.1, func(_i, _k):
		if not pj.live(c):
			return
		for pr in pj.get_tree().get_nodes_in_group("projectiles"):
			if pr.get("shooter") != c and pr.global_position.distance_to(c.global_position + Vector3.UP) < 2.5:
				_gold_pop(host, pr.global_position)
				pr.queue_free(), func():
		if is_instance_valid(orbit):
			orbit.queue_free())
	Sfx.play("chakra", c.global_position, 0.7)


## Altın arayış topu: cel altın küre + beyaz parıltı benekli üst + ince ekvator bandı
static func _seeker(size: float) -> Node3D:
	var root = Node3D.new()
	var body = _cel(_mesh_sph(), GOLD_CORE, GOLD, GOLD_EDGE, 0.015)
	body.scale = Vector3.ONE * size
	root.add_child(body)
	var glint = _cel(_mesh_sph(), Color.WHITE, Color(1, 1, 0.92), GOLD_CORE)
	glint.position = Vector3(-0.35, 0.45, 0.35) * size
	glint.scale = Vector3.ONE * size * 0.22
	root.add_child(glint)
	var band = _cel(_mesh_thin_torus(), GOLD_CORE, GOLD.darkened(0.15), GOLD_EDGE)
	band.scale = Vector3(1.0, 0.5, 1.0) * size * 1.02
	root.add_child(band)
	return root


## Mermi silinişi: kısa altın parıltı (sönen çekirdek + dışa altı ışın)
static func _gold_pop(host: Node, p: Vector3) -> void:
	var f = _cel(_mesh_sph(), Color.WHITE, GOLD, GOLD_EDGE)
	_put(host, f, p)
	f.scale = Vector3.ONE * 0.35
	var tw = f.create_tween()
	tw.tween_property(f, "scale", Vector3.ONE * 0.02, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(f.queue_free)
	for k in 6:
		var a = TAU * k / 6.0 + randf() * 0.4
		_streak(host, p, Vector3(cos(a), randf_range(-0.4, 0.6), sin(a)), 0.7, 0.07, 0.25, GOLD, GOLD_CORE, 0.6)


static func _cloak_burst(pj, host: Node, base: Vector3) -> void:
	# hazırlık: zeminden bedene akan çizgiler
	for k in 12:
		var a = TAU * k / 12.0
		var p = base + Vector3(cos(a), 0.15, sin(a)) * 3.2
		_streak(host, p, base + Vector3.UP * 1.0 - p, 1.4, 0.12, 0.35, CLOAK, TENSEI_CORE, 2.6)
	pj.after(0.3, func():
		for k in 14:
			var a = TAU * k / 14.0 + randf() * 0.2
			var dir = Vector3(cos(a), 0.6, sin(a)).normalized()
			_tongue(host, base + Vector3(cos(a), 0.0, sin(a)) * 0.5, 0.45, 1.9, 0.7, TENSEI_CORE, CLOAK, CLOAK_EDGE, dir)
		var ring = _decal(host, "wave", WAVE_BODY, base, 3.6, {"tint": CLOAK, "prog": 0.2, "fade": 1.0, "seed": randf() * 20.0})
		var tw = ring.create_tween()
		tw.tween_method(_pf(ring, "prog"), 0.2, 0.9, 0.4).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(ring, "fade"), 1.0, 0.0, 1.2)
		tw.tween_callback(ring.queue_free))


## Bedenin kendi ağlarına alevli kaplama + kemiklere bağlı alev dilleri (koşarken geriye savrulur)
static func _body_cloak(pj, c: Node3D, dur: float) -> void:
	var mdl = c.get("model")
	var keep = Node3D.new()
	c.add_child(keep)
	var base_m = _mat("cloak", CLOAK_SHADER)
	var meshes = []
	if mdl and is_instance_valid(mdl):
		for n in (mdl as Node).find_children("*", "MeshInstance3D", true, false):
			var g = n as MeshInstance3D
			if g == null or not g.visible:
				continue
			var prev = g.material_overlay
			var m: Material = base_m
			if prev != null:
				var dm = base_m.duplicate()
				dm.next_pass = prev   # var olan kaplama (dış çizgi) altta kalır
				m = dm
			g.material_overlay = m
			g.set_instance_shader_parameter("tsg_cloak", 0.0)
			meshes.append([g, m, prev])
	var holders = []
	var tongues = []
	for spec in [["Head", 0.5, 0.9], ["UpperChest", 0.65, 1.1], ["LeftLowerArm", 0.42, 0.75], ["RightLowerArm", 0.42, 0.75],
			["LeftHand", 0.28, 0.5], ["RightHand", 0.28, 0.5], ["Hips", 0.6, 0.85], ["LeftLowerLeg", 0.32, 0.55], ["RightLowerLeg", 0.32, 0.55]]:
		var ba = pj.bone_attach(c, spec[0])
		if ba == null:
			continue
		var hd = Node3D.new()
		ba.add_child(hd)
		for j in 2:
			var tg = _gi(_mesh_tongue(randi() % 4), _mat("tongue", TONGUE_SHADER))
			tg.set_instance_shader_parameter("c_core", TENSEI_CORE)
			tg.set_instance_shader_parameter("c_mid", Color(CLOAK.r, CLOAK.g, CLOAK.b, 0.85))
			tg.set_instance_shader_parameter("c_edge", CLOAK_EDGE)
			tg.set_instance_shader_parameter("fade", 0.0)
			tg.set_instance_shader_parameter("seed", randf() * 10.0)
			hd.add_child(tg)
			tg.position = Vector3(randf_range(-0.06, 0.06), 0.0, randf_range(-0.06, 0.06))
			tg.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
			tg.scale = Vector3(spec[1], spec[2], spec[1]) * randf_range(0.8, 1.1)
			tongues.append(tg)
		holders.append(hd)
		pj.free_after(dur + 1.0, ba)
	var wc = weakref(c)
	var upd = func(_x: float):
		var cc = wc.get_ref()
		var vel = Vector3.ZERO
		if cc != null and is_instance_valid(cc) and "velocity" in cc:
			vel = cc.velocity
		var up = (Vector3.UP * 2.0 - Vector3(vel.x, 0.0, vel.z) * 0.14).normalized()
		var q = _ybasis(up)
		for hd in holders:
			if is_instance_valid(hd) and hd.is_inside_tree():
				var sc = (hd.get_parent() as Node3D).global_basis.get_scale()
				hd.global_basis = q * Basis.from_scale(sc)
	var setf = func(x: float):
		for e in meshes:
			if is_instance_valid(e[0]):
				e[0].set_instance_shader_parameter("tsg_cloak", x)
		for tg in tongues:
			if is_instance_valid(tg):
				tg.set_instance_shader_parameter("fade", x)
	var fin = func():
		for e in meshes:
			if is_instance_valid(e[0]) and e[0].material_overlay == e[1]:
				e[0].material_overlay = e[2]
		if is_instance_valid(keep):
			keep.queue_free()
	var tw = keep.create_tween()
	tw.set_parallel(true)
	tw.tween_method(upd, 0.0, 1.0, dur)
	tw.tween_method(setf, 0.0, 1.0, 0.45).set_delay(0.25)
	tw.tween_method(setf, 1.0, 0.0, 0.6).set_delay(dur - 0.6)
	tw.chain().tween_callback(fin)


## Kinrin Tensei Baku: zeminde 12 m'lik altın tekerlek dönerek sıkışır, çevre içeri sürüklenir (toz ve çekim çizgileri),
## havaya kalkan ellerin üstünde altın çekirdek şişer; patlamada tekerlek dışa fırlar, ışınsal itme çizgileri,
## göğe ışık sütunları, fırlayan taşlar; geride altın izli, çatlak dolu geniş krater.
static func kinrin_tensei_baku(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.4)
	_eye(pj, c, false, 1.4)
	var host = _host(pj)
	var at = c.global_position
	var g0 = pj.gp(at)
	var wheel = _decal(host, "wheel", WHEEL_BODY, g0, 12.0, {"fade": 1.0, "spd": 1.6})
	var tw = wheel.create_tween()
	tw.tween_property(wheel, "scale", Vector3(1.8, 1.0, 1.8), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(wheel.queue_free)
	var core = _cel(_mesh_sph(), GOLD_CORE, GOLD, GOLD_EDGE, 0.04)
	_put(host, core, at + Vector3.UP * 3.0)
	core.scale = Vector3.ONE * 0.05
	var ct = core.create_tween()
	ct.tween_property(core, "scale", Vector3.ONE * 0.55, 0.8).set_trans(Tween.TRANS_BACK)
	ct.tween_property(core, "scale", Vector3.ONE * 0.12, 0.06)
	ct.tween_callback(core.queue_free)
	for k in 14:
		pj.after(k * 0.045, func():
			var a = randf() * TAU
			var p = at + Vector3(cos(a) * randf_range(3.5, 5.5), randf_range(1.0, 5.0), sin(a) * randf_range(3.5, 5.5))
			var to = at + Vector3.UP * 3.0
			_streak(host, p, to - p, 1.6, 0.1, 0.3, GOLD, GOLD_CORE, p.distance_to(to) * 0.8))
	pj.every(0.8, 1.0 / 30.0, func(i, _k):
		for e in pj.enemies_near(c, at, 14.0):
			var v = at - e.global_position
			v.y = 0
			if v.length() > 1.5:
				e.global_position = pj.gp(e.global_position + v.normalized() * 0.35)
				if i % 6 == 0:
					_streak(host, e.global_position + Vector3.UP * randf_range(0.5, 1.5) - v.normalized() * 1.2, v, 1.4, 0.08, 0.25, GOLD, GOLD_CORE, 1.0)
		if i % 3 == 0:
			var rr = lerpf(12.0, 1.8, pow(float(i) / 24.0, 2.0))
			var a = randf() * TAU
			var p = g0 + Vector3(cos(a), 0.2, sin(a)) * rr
			_dust(host, p, randf_range(0.7, 1.1), 0.5, Vector3(-cos(a), 0.2, -sin(a)) * rr * 0.9, DUSTC.lerp(GOLD, 0.15)), Callable())
	pj.after(0.85, func():
		if not pj.live(c):
			return
		_kinrin_burst(pj, host, at, g0)
		pj.hit(c, at + Vector3.UP, 11.0, pj.inf(c, "kinrin_tensei_baku", 3.6, {"knock": 32.0, "launch": 10.0, "kind": "heavy", "hitstop": 0.18}))
		pj.shake(1.8))
	Sfx.play("boom", at, 0.5)


static func _kinrin_burst(_pj, host: Node, at: Vector3, g0: Vector3) -> void:
	var fl = _cel(_mesh_sph(), Color.WHITE, GOLD_CORE, GOLD)
	_put(host, fl, at + Vector3.UP * 3.0)
	fl.scale = Vector3.ONE * 0.3
	var ft = fl.create_tween()
	ft.tween_property(fl, "scale", Vector3.ONE * 1.5, 0.1).set_ease(Tween.EASE_OUT)
	ft.tween_property(fl, "scale", Vector3.ONE * 0.02, 0.18).set_ease(Tween.EASE_IN)
	ft.tween_callback(fl.queue_free)
	# tekerlek dışa fırlar
	var wheel = _decal(host, "wheel", WHEEL_BODY, g0, 1.5, {"fade": 1.0, "spd": -4.0})
	var wt = wheel.create_tween().set_parallel()
	wt.tween_property(wheel, "scale", Vector3(15.0, 1.0, 15.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wt.tween_method(_pf(wheel, "fade"), 1.0, 0.0, 0.5).set_delay(0.15)
	wt.chain().tween_callback(wheel.queue_free)
	# ışınsal itme çizgileri
	for k in 24:
		var a = TAU * k / 24.0 + randf() * 0.15
		var d = Vector3(cos(a), randf_range(-0.05, 0.15), sin(a))
		_streak(host, at + Vector3.UP * randf_range(0.6, 2.2) + d * 1.2, d, 3.5, 0.18, 0.45, GOLD, GOLD_CORE, 10.0)
	# göğe ışık sütunları
	for k in 10:
		var a = randf() * TAU
		var p = g0 + Vector3(cos(a), 0.0, sin(a)) * randf_range(2.0, 10.0)
		_streak(host, p, Vector3.UP, randf_range(5.0, 9.0), 0.3, 0.45, GOLD, GOLD_CORE)
	_chunks(host, g0 + Vector3.UP * 0.5, g0.y, 20, 14.0, 0.45, EARTH)
	for k in 12:
		var a = TAU * k / 12.0
		var p = g0 + Vector3(cos(a), 0.3, sin(a)) * randf_range(4.0, 8.0)
		_dust(host, p, randf_range(1.2, 1.8), 1.1, Vector3(cos(a), 0.15, sin(a)) * 5.0)
	_scar(host, g0, 14.0, Color(0.42, 0.32, 0.16), 16.0, 3.0, 1.5)


## Inryoku: iki avucun önünde dönerek içe kıvrılan çekim merceği; her düşman, göğsünden sana uzanan gerilmiş çekim
## ipiyle sürüklenir (ayağından toz); 0.45 sn'de itme: zeminde genişleyen mavi basınç halkası, göğüs hizasında dışa
## ışınsal çizgiler, savrulan toz ve çakıl.
static func tenseigan_inryoku(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	_eye(pj, c, false, 0.8)
	var host = _host(pj)
	var at = c.global_position
	var fd = c.face_dir()
	_gravity_lens(host, at + Vector3.UP * 1.25 + fd * 0.8, fd, 0.45)
	for e in pj.enemies_near(c, at, 14.0):
		var tw = e.create_tween()
		tw.tween_property(e, "global_position", pj.gp(at + (e.global_position - at).normalized() * 1.8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_pull_thread(host, e, c, 0.4)
		_dust(host, pj.gp(e.global_position) + Vector3.UP * 0.2, 0.6, 0.5, (at - e.global_position).normalized() * 2.0)
	pj.after(0.45, func():
		if pj.live(c):
			_inryoku_push(pj, host, c)
			pj.hit(c, c.global_position + Vector3.UP, 4.0, pj.inf(c, "tenseigan_inryoku", 1.6, {"knock": 26.0, "launch": 6.0, "kind": "heavy"}))
			pj.shake(0.7))
	Sfx.play("wind", at, 0.8)


static func _gravity_lens(host: Node, p: Vector3, fd: Vector3, life: float) -> void:
	for j in 2:
		var mi = _gi(_mesh_quad(), _pmat("spiral", SPIRAL_BODY))
		mi.set_instance_shader_parameter("tint", TENSEI if j == 0 else Color(0.85, 0.95, 1.0))
		mi.set_instance_shader_parameter("fade", 1.0)
		mi.set_instance_shader_parameter("spd", 4.0 if j == 0 else -2.5)
		_put(host, mi, p + fd * 0.02 * j)
		_face_dir(mi, fd)
		var s = 1.7 if j == 0 else 1.1
		mi.scale = Vector3.ONE * 0.1
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * s, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.05, life - 0.27))
		tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.12).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


## Hedefin göğsünden sahibin göğsüne gerilen, her kare güncellenen çekim ipi
static func _pull_thread(host: Node, e: Node3D, c: Node3D, life: float) -> void:
	var mi = _gi(_mesh_streak(), _mat("streak", STREAK_SHADER))
	mi.set_instance_shader_parameter("tint", TENSEI)
	mi.set_instance_shader_parameter("c_core", TENSEI_CORE)
	mi.set_instance_shader_parameter("fade", 1.0)
	host.add_child(mi)
	var we = weakref(e)
	var wc = weakref(c)
	var upd = func(x: float):
		var a = we.get_ref()
		var b = wc.get_ref()
		if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b) or not is_instance_valid(mi):
			return
		var p0 = (a as Node3D).global_position + Vector3.UP * 1.1
		var p1 = (b as Node3D).global_position + Vector3.UP * 1.2
		var v = p1 - p0
		if v.length() < 0.2:
			mi.visible = false
			return
		var dn = v.normalized()
		var up = Vector3.UP if absf(dn.y) < 0.98 else Vector3.RIGHT
		mi.global_transform = Transform3D(Basis.looking_at(dn, up) * Basis.from_scale(Vector3(0.09, 0.09, v.length())), p0)
		mi.set_instance_shader_parameter("fade", 1.0 - x * x)
	var tw = mi.create_tween()
	tw.tween_method(upd, 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


static func _inryoku_push(pj, host: Node, c: Node3D) -> void:
	var g = pj.gp(c.global_position)
	var ring = _decal(host, "wave", WAVE_BODY, g, 12.0, {"tint": TENSEI, "prog": 0.08, "fade": 1.0, "seed": randf() * 20.0})
	var tw = ring.create_tween()
	tw.tween_method(_pf(ring, "prog"), 0.08, 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(ring, "fade"), 1.0, 0.0, 0.25).set_delay(0.25)
	tw.tween_callback(ring.queue_free)
	for k in 16:
		var a = TAU * k / 16.0 + randf() * 0.2
		var d = Vector3(cos(a), randf_range(-0.05, 0.1), sin(a))
		_streak(host, c.global_position + Vector3.UP * randf_range(0.8, 1.6) + d * 0.8, d, 2.2, 0.14, 0.35, TENSEI, TENSEI_CORE, 7.0)
	for k in 8:
		var a = TAU * k / 8.0
		_dust(host, g + Vector3(cos(a), 0.25, sin(a)) * 1.8, 0.8, 0.7, Vector3(cos(a), 0.1, sin(a)) * 6.0)
	_chunks(host, g + Vector3.UP * 0.3, g.y, 8, 9.0, 0.18, EARTH, 0.9, 0.6)


## Gudōdama Ame: sahibinin ardında on altın top hale gibi belirir; her biri sırası gelince oradan fırlar (kuyruklu altın
## top, hedefe kıvrılır); çarpınca altın çöküş (sönen çekirdek + dışa kıymıklar) ve yerde küçük yanık izi.
static func tenseigan_gudodama_ame(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	_eye(pj, c, false, 1.0)
	var host = _host(pj)
	var targets = pj.enemies_near(c, c.global_position, 30.0)
	var tt = pj.tg(c, t, 30.0)
	if tt and not targets.has(tt):
		targets.push_front(tt)
	var offs = []
	var halo = []
	for k in 10:
		var o = Vector3(randf_range(-1.5, 1.5), randf_range(0, 1.2), randf_range(-1.5, 1.5))
		offs.append(o)
		var mote = _seeker(0.2)
		c.add_child(mote)
		mote.position = Vector3.UP * 1.8 + o
		mote.scale = Vector3.ONE * 0.01
		mote.create_tween().tween_property(mote, "scale", Vector3.ONE, 0.14).set_delay(k * 0.015).set_trans(Tween.TRANS_BACK)
		pj.free_after(1.4, mote)
		halo.append(mote)
	for k in 10:
		pj.after(0.2 + k * 0.07, func():
			if is_instance_valid(halo[k]):
				halo[k].queue_free()
			if not pj.live(c):
				return
			var e = targets[k % targets.size()] if not targets.is_empty() else null
			var from = c.global_position + Vector3.UP * 1.8 + offs[k]
			var ball = _seeker_shot()
			pj.shot(c, from, pj.aim_at(c, e, from), 30.0, ball, pj.inf(c, "tenseigan_gudodama_ame", 0.6, {"knock": 6.0, "kind": "heavy"}), e, false, 1.4, func(p, _h):
				_seeker_impact(pj, host, p)))
	Sfx.play("chakra", c.global_position, 0.9)


## Mermi gövdesi: altın top + arkasında (+Z) incelen altın kuyruk (mermi -Z'ye bakar)
static func _seeker_shot() -> Node3D:
	var root = _seeker(0.24)
	var tail = _gi(_mesh_streak(), _mat("streak", STREAK_SHADER))
	tail.set_instance_shader_parameter("tint", Color(GOLD.r, GOLD.g, GOLD.b, 0.85))
	tail.set_instance_shader_parameter("c_core", GOLD_CORE)
	tail.set_instance_shader_parameter("fade", 1.0)
	root.add_child(tail)
	tail.position = Vector3(0, 0, 1.6)
	tail.scale = Vector3(0.36, 0.36, 1.6)
	return root


static func _seeker_impact(pj, host: Node, p: Vector3) -> void:
	var f = _cel(_mesh_sph(), Color.WHITE, GOLD, GOLD_EDGE, 0.05)
	_put(host, f, p)
	f.scale = Vector3.ONE * 0.75
	var tw = f.create_tween()
	tw.tween_property(f, "scale", Vector3.ONE * 0.02, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(f.queue_free)
	_shards(host, p, 7, 4.0, 0.22, 0.45, GOLD_CORE, GOLD, GOLD_EDGE, 3.0)
	var g = pj.gp(p)
	if absf(p.y - g.y) < 1.6:
		_scar(host, g, 1.1, Color(0.3, 0.22, 0.1), 6.0, 1.5, 1.0)


# ================================================================== JŌGAN
## Jigen Kiri: önünde dikey, tırtıklı boyut yarığı açılır (içi yıldızlı karanlık, kenarı mavi-beyaz), bedenin içine
## çekilir; hedefin arkasında ikinci yarık açılır, oradan çıkarsın; vuruşta uzay cam gibi kesilir (parlak kesik +
## karanlık iz + kırık uzay kıymıkları). Yarıkların dibinde zeminde ince mavi dikiş kalır.
static func jogan_jigen_kiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.6)
	_eye(pj, c, true, 0.8)
	var host = _host(pj)
	_rift(pj, host, c.global_position + c.face_dir(), c.face_dir())
	for k in 6:
		var p = c.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.4, 1.7), randf_range(-0.3, 0.3))
		var to = c.global_position + c.face_dir() + Vector3.UP * 1.3
		_streak(host, p, to - p, 0.8, 0.07, 0.22, JOGAN, JOGAN_CORE, p.distance_to(to))
	if tt == null:
		return
	pj.after(0.2, func():
		if not (pj.live(c) and pj.live(tt)):
			return
		var behind = pj.gp(tt.global_position + (tt.global_position - c.global_position).normalized() * 1.4)
		_rift(pj, host, behind, (tt.global_position - behind).normalized())
		c.global_position = behind
		if c is Player:
			c.combat.face_to(tt)
		pj.after(0.1, func():
			if pj.live(c) and pj.live(tt):
				_space_cut(host, tt.global_position + Vector3.UP, tt.global_position - c.global_position)
				tt.take_hit(pj.inf(c, "jogan_jigen_kiri", 1.8, {"knock": 14.0, "kind": "heavy", "hitstop": 0.1}))))
	Sfx.play("seal", c.global_position, 1.6)


## Dikey yarık: 0.15 sn açılır, 0.25 sn durur, 0.15 sn kapanır; kenarından kıymıklar kopar, dibinde zemin dikişi
static func _rift(pj, host: Node, at: Vector3, d: Vector3) -> void:
	var mi = _gi(_mesh_quad(), _pmat("rift", RIFT_BODY))
	mi.set_instance_shader_parameter("open", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("seed", randf() * 30.0)
	_put(host, mi, at + Vector3.UP * 1.3)
	var dh = Vector3(d.x, 0.0, d.z)
	_face_dir(mi, dh if dh.length() > 0.01 else Vector3.FORWARD)
	mi.scale = Vector3(1.6, 2.7, 1.0)
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "open"), 0.0, 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_method(_pf(mi, "open"), 1.0, 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.12)
	tw.tween_callback(mi.queue_free)
	var side = dh.cross(Vector3.UP).normalized() if dh.length() > 0.01 else Vector3.RIGHT
	for k in 6:
		var p = at + Vector3.UP * randf_range(0.5, 2.3) + side * randf_range(-0.25, 0.25)
		_shards(host, p, 1, 1.2, 0.09, 0.6, JOGAN_CORE, Color(0.12, 0.1, 0.3), JOGAN)
	var g = pj.gp(at)
	_streak(host, g + Vector3.UP * 0.03 - side * 0.9, side, 1.8, 0.06, 1.4, JOGAN, JOGAN_CORE)


## Uzay kesiği: hedefin içinden geçen parlak çapraz çizgi + altında karanlık yarık izi + kırık uzay kıymıkları
static func _space_cut(host: Node, p: Vector3, dv: Vector3) -> void:
	var dh = Vector3(dv.x, 0.0, dv.z).normalized() if Vector3(dv.x, 0.0, dv.z).length() > 0.01 else Vector3.FORWARD
	var side = dh.cross(Vector3.UP).normalized()
	var cut = (side + Vector3.UP * 0.7).normalized()
	var a = p - cut * 1.6
	_streak(host, a, cut, 3.2, 0.2, 0.5, VOIDC, Color(0.1, 0.08, 0.3), 0.15)
	_streak(host, a + dh * -0.02, cut, 3.4, 0.07, 0.45, JOGAN, JOGAN_CORE, 0.15)
	_shards(host, p, 9, 2.4, 0.16, 0.7, JOGAN_CORE, Color(0.1, 0.08, 0.28), JOGAN, 1.0)


## Fūin Kai: ayak altında mühür kafesi parlar ve hücre hücre kırılır; kafesli dalga 16 m'ye yayılır. Her düşmanın
## çevresindeki üç mühür halkası sıkışıp kıymıklara dağılır (güçlendirmeler söner), başının üstünde mühür süresince
## dönen kilit işareti kalır. Oyuncuda olumsuz durumlar kara benekler halinde bedenden kopar.
static func jogan_fuin_kai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	_eye(pj, c, true, 0.8)
	var host = _host(pj)
	_seal_lattice(host, pj.gp(c.global_position))
	if c is Player:
		for s in ["burn", "poison", "slow", "bind", "sealed", "stun", "fear", "bleed"]:
			c.statuses.erase(s)
		_cleanse_motes(host, c)
	for e in pj.enemies_near(c, c.global_position, 16.0):
		if not pj.live(e):
			continue
		_seal_break(pj, host, e)
		if e.has_method("clear_buffs"):
			e.clear_buffs()
		pj.st(e, "sealed", 3.0)
		e.take_hit(pj.inf(c, "jogan_fuin_kai", 0.6, {"knock": 4.0, "kind": "light"}))
	Sfx.play("seal", c.global_position, 0.8)


static func _seal_lattice(host: Node, g: Vector3) -> void:
	var pad = _decal(host, "lattice", LATTICE_BODY, g, 2.6, {"prog": 0.0, "disc": 0.0, "crack": 0.0, "fade": 1.0})
	var tw = pad.create_tween()
	tw.tween_method(_pf(pad, "disc"), 0.0, 0.95, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_method(_pf(pad, "crack"), 0.0, 1.0, 0.5)
	tw.tween_callback(pad.queue_free)
	var wave = _decal(host, "lattice", LATTICE_BODY, g, 16.0, {"prog": 0.02, "disc": 0.0, "crack": 0.0, "fade": 1.0})
	var wt = wave.create_tween()
	wt.tween_method(_pf(wave, "prog"), 0.02, 0.97, 0.5).set_ease(Tween.EASE_OUT)
	wt.parallel().tween_method(_pf(wave, "crack"), 0.0, 0.7, 0.5)
	wt.tween_method(_pf(wave, "fade"), 1.0, 0.0, 0.25)
	wt.tween_callback(wave.queue_free)


static func _seal_break(pj, host: Node, e: Node3D) -> void:
	var R = maxf(0.5, float(e.get("radius")) if e.get("radius") != null else 0.5)
	var Hh = float(e.get("height")) if e.get("height") != null else 1.8
	for j in 3:
		var ring = _cel(_mesh_thin_torus(), JOGAN_CORE, JOGAN, JOGAN_EDGE)
		_put(host, ring, e.global_position + Vector3.UP * Hh * (0.25 + 0.3 * j))
		ring.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
		ring.scale = Vector3.ONE * R * 2.2
		var tw = ring.create_tween()
		tw.tween_interval(j * 0.05)
		tw.tween_property(ring, "scale", Vector3.ONE * R * 1.05, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		var hr = ring
		tw.tween_callback(func():
			if is_instance_valid(hr):
				_shards(host, hr.global_position, 6, 3.0, 0.1, 0.45, JOGAN_CORE, JOGAN, JOGAN_EDGE, 2.0)
				hr.queue_free())
	var lock = _gi(_mesh_quad(), _pmat("lock", LOCK_BODY, true))
	lock.set_instance_shader_parameter("fade", 0.0)
	e.add_child(lock)
	lock.position = Vector3.UP * (Hh + 0.55)
	lock.scale = Vector3.ONE * 0.6
	ClanJutsu.fit_body(e, lock)
	var lt = lock.create_tween()
	lt.tween_method(_pf(lock, "fade"), 0.0, 1.0, 0.2).set_delay(0.25)
	lt.tween_interval(2.4)
	lt.tween_method(_pf(lock, "fade"), 1.0, 0.0, 0.35)
	lt.tween_callback(lock.queue_free)


static func _cleanse_motes(host: Node, c: Node3D) -> void:
	for k in 10:
		var m = _cel(_mesh_sph(), Color(0.35, 0.25, 0.45), Color(0.12, 0.08, 0.18), Color(0.02, 0.0, 0.05), 0.02)
		var p = c.global_position + Vector3(randf_range(-0.35, 0.35), randf_range(0.3, 1.7), randf_range(-0.35, 0.35))
		_put(host, m, p)
		m.scale = Vector3.ONE * randf_range(0.05, 0.09)
		var out = Vector3(randf_range(-1, 1), randf_range(1.5, 2.5), randf_range(-1, 1))
		var tw = m.create_tween().set_parallel()
		tw.tween_property(m, "global_position", p + out, 0.8).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(m, "fade"), 1.0, 0.0, 0.5).set_delay(0.3)
		tw.chain().tween_callback(m.queue_free)


## Seisen: sağ göz 0.35 sn dolar (göze akan çizgiler); gözden 40 m'lik mavi-beyaz ruh ışını çakar — çekirdek, dış kılıf ve
## çevresinde dönen ruh sarmalı; ışın boyunca her 6 m'de duvarlardan geçerken çıkan dikey halka dalgaları; sonra incelerek söner.
static func jogan_seisen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	_eye(pj, c, true, 1.0, 1.6)
	var host = _host(pj)
	var tt = pj.tg(c, t, 40.0)
	var eye_p = c.global_position + Vector3.UP * 1.62 + c.face_dir() * 0.15
	for k in 8:
		var a = TAU * k / 8.0
		var p = eye_p + Vector3(cos(a), sin(a) * 0.7, 0.0).rotated(Vector3.UP, randf() * TAU) * 1.2
		_streak(host, p, eye_p - p, 0.6, 0.05, 0.3, JOGAN, JOGAN_CORE, 1.0)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var from = c.global_position + Vector3.UP * 1.62 + c.face_dir() * 0.3
		var d = pj.aim_at(c, tt, from)
		_soul_beam(host, from, d, 40.0)
		Combat.hit_zone(c, from - Vector3.UP * 1.6, d, 40.0, 6.0, 2.0, pj.inf(c, "jogan_seisen", 2.4, {"knock": 10.0, "kind": "heavy", "pierce_guard": true})))
	Sfx.play("chidori", c.global_position, 1.5)


static func _soul_beam(host: Node, from: Vector3, d: Vector3, L: float) -> void:
	var root = Node3D.new()
	_put(host, root, from)
	_orient(root, d)
	var parts = []
	var core = _gi(_mesh_beam(), _mat("beam", BEAM_SHADER))
	core.set_instance_shader_parameter("c_core", Color.WHITE)
	core.set_instance_shader_parameter("c_mid", JOGAN_CORE)
	core.set_instance_shader_parameter("c_edge", JOGAN)
	core.scale = Vector3(0.12, L, 0.12)
	parts.append(core)
	var sheath = _gi(_mesh_beam(), _mat("beam", BEAM_SHADER))
	sheath.set_instance_shader_parameter("c_core", JOGAN_CORE)
	sheath.set_instance_shader_parameter("c_mid", Color(JOGAN.r, JOGAN.g, JOGAN.b, 0.55))
	sheath.set_instance_shader_parameter("c_edge", JOGAN_EDGE)
	sheath.scale = Vector3(0.32, L, 0.32)
	parts.append(sheath)
	var helix = _gi(_mesh_helix(), _mat("beam", BEAM_SHADER))
	helix.set_instance_shader_parameter("c_core", Color.WHITE)
	helix.set_instance_shader_parameter("c_mid", Color(0.7, 0.85, 1.0, 0.9))
	helix.set_instance_shader_parameter("c_edge", JOGAN)
	helix.set_instance_shader_parameter("span", 40.0)
	helix.scale = Vector3.ONE * (L / 40.0)
	parts.append(helix)
	for p in parts:
		root.add_child(p)
		p.set_instance_shader_parameter("reach", 0.0)
		p.set_instance_shader_parameter("fade", 1.0)
		p.set_instance_shader_parameter("wlen", L)
		if p != helix:
			p.set_instance_shader_parameter("span", 1.0)
	var spin = helix.create_tween().set_loops(4)
	spin.tween_property(helix, "rotation:y", TAU, 0.3).as_relative()
	var tw = root.create_tween()
	tw.set_parallel(true)
	for p in parts:
		tw.tween_method(_pf(p, "reach"), 0.0, 1.0, 0.09)
		tw.tween_method(_pf(p, "fade"), 1.0, 0.0, 0.3).set_delay(0.32)
	tw.tween_property(sheath, "scale", Vector3(0.02, L, 0.02), 0.3).set_delay(0.32)
	tw.tween_property(core, "scale", Vector3(0.03, L, 0.03), 0.3).set_delay(0.32)
	tw.chain().tween_callback(root.queue_free)
	# geçtiği her 6 m'de dikey halka dalgası (duvarların içinden geçiş)
	for k in 6:
		var at = from + d * (k * 6.0 + 4.0)
		var rq = _gi(_mesh_quad(), _pmat("wave", WAVE_BODY))
		rq.set_instance_shader_parameter("tint", JOGAN)
		rq.set_instance_shader_parameter("prog", 0.15)
		rq.set_instance_shader_parameter("fade", 1.0)
		rq.set_instance_shader_parameter("seed", randf() * 20.0)
		_put(host, rq, at)
		_face_dir(rq, d)
		rq.scale = Vector3.ONE * 3.2
		var rt = rq.create_tween()
		rt.tween_interval(k * 0.014)
		rt.tween_method(_pf(rq, "prog"), 0.15, 0.95, 0.35).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_method(_pf(rq, "fade"), 1.0, 0.0, 0.35)
		rt.tween_callback(rq.queue_free)


# ================================================================== ITACHI: Susanoo eşyaları ve Karasu Bunshin
## Totsuka no Tsurugi (ref: manga'da ağır, akışkan, kenarlarından iplik iplik sarkan sıvı kılıç; anime'de Susanoo
## renginde): gerçek Susanoo sağ eli testiyi kaldırır (MsArts testisi, Susanoo malzemesi), sıvı kılıç ağzından akar;
## kılıçtan ağır sıvı iplikleri sarkar ve savrulur; saplamada sıvı taç halinde sıçrar, damlalar yere düşüp leke bırakır;
## ruh damlaları hedeften testiye akar. Hazırlıkta Susanoo renkli sıvı damlaları ele toplanır.
static func totsuka_no_tsurugi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "totsuka_no_tsurugi")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var host = _host(pj)
	var tg = Jutsu._tg(c, t, 10.0 + H * 1.3)
	var aim = MsArts._aim_fn(c, tg, H * 0.9)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 1.2)
	MsArts._anim(c, "cast_out", 0.8)
	sn.hide_weapons(2.9)
	var left_idle = Susanoo.arm(false, -side * 0.25 - Vector3.UP * 0.9 + d * 0.25, d * 0.7 - Vector3.UP * 0.5 - side * 0.2)
	# 1) testi omuz üstüne kalkar, kılıç ağzından göğe doğru akarak uzar
	sn.pose({"arms": Susanoo.arm(true, side * 0.55 + Vector3.UP * 0.5 - d * 0.15, Vector3.UP * 0.9 + d * 0.3, Vector3.UP * 0.5 + d * 0.85) + left_idle, "spine": -5.0}, 2.8)
	var gourd = MsArts._gourd(sn)
	host.add_child(gourd)
	var blade = Node3D.new()
	var outer = _liquid(MsArts._blade_mesh(), col, false)
	var inner = _liquid(MsArts._blade_mesh(), col, true)
	inner.scale = Vector3(0.38, 0.38, 1.0)
	blade.add_child(outer)
	blade.add_child(inner)
	host.add_child(blade)
	var drips = []
	for k in 6:
		var dm = _liquid(_mesh_drip(k % 3), col, false)
		host.add_child(dm)
		dm.visible = false
		drips.append(dm)
		pj.free_after(3.6, dm)
	var st = {"len": 0.0, "mode": 0, "gs": 0.05, "w": S * 0.5}
	var o = {"sn": sn, "g": gourd, "b": blade}   # düğümler sözlükte: serbest kalınca lambda yakalaması hata vermesin
	var upd = func(x: float):
		if not (is_instance_valid(o["sn"]) and is_instance_valid(o["g"]) and is_instance_valid(o["b"])):
			return
		var sn2: Susanoo = o["sn"]
		var gourd2: Node3D = o["g"]
		var blade2: Node3D = o["b"]
		var hp = sn2.hand(true)
		var dir: Vector3 = (Vector3.UP * 0.8 + d * 0.6).normalized() if st["mode"] == 0 else (aim.call() - hp).normalized()
		gourd2.global_transform = Transform3D(MsArts._zbasis(dir) * Basis.from_scale(Vector3.ONE * S * 0.75 * st["gs"]), hp - dir * S * 0.08)
		var mouth = gourd2.to_global(Vector3(0, 0, 0.5))
		blade2.global_transform = Transform3D(MsArts._zbasis(dir) * Basis.from_scale(Vector3(st["w"], st["w"], maxf(0.02, st["len"]))), mouth)
		# kılıçtan sarkan / savrulan ağır sıvı iplikleri
		var L: float = st["len"]
		for k in drips.size():
			var dm2 = drips[k]
			if not is_instance_valid(dm2):
				continue
			dm2.visible = L > S * 0.3
			if not dm2.visible:
				continue
			var f = 0.22 + 0.7 * float(k) / drips.size()
			var p = mouth + dir * L * f
			var sway = sin(x * 21.0 + k * 1.7)
			var hang = (Vector3.DOWN * 0.8 - dir * 0.6 + side * sway * 0.35).normalized()
			var lk = S * (0.45 + 0.25 * sin(k * 2.3 + x * 9.0))
			dm2.global_transform = Transform3D(_ybasis(hang) * Basis.from_scale(Vector3(S * 0.32, lk, S * 0.32)), p)
	var tw = blade.create_tween()
	tw.set_parallel(true)
	tw.tween_method(upd, 0.0, 1.0, 3.0)
	tw.tween_method(func(x: float): st["gs"] = x, 0.05, 1.0, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(x: float): st["len"] = x, 0.0, H * 0.55, 0.45).set_delay(0.25).set_trans(Tween.TRANS_SINE)
	_liquid_gather(host, sn.hand(true), col, S)
	Sfx.play("genjutsu", c.global_position, 0.6)
	MsArts._later(0.3, func(): Sfx.play("fire", c.global_position, 0.5, 0.6))
	# 2) saplama: kol hedefe uzanır, sıvı kılıç hedefe kadar akıp deler
	MsArts._later(0.8, func():
		if not (is_instance_valid(c) and is_instance_valid(sn)):
			return
		st["mode"] = 1
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad) + left_idle, "spine": 12.0}, 2.0, true)
		var reach = sn.hand(true).distance_to(aim.call()) + H * 0.06
		var tw2 = blade.create_tween()
		tw2.tween_method(func(x: float): st["len"] = x, st["len"], reach, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Sfx.play("whoosh", c.global_position, 0.5, 0.9))
	MsArts._later(0.93, func():
		if not is_instance_valid(c):
			return
		var p: Vector3 = aim.call()
		_totsuka_pierce(pj, host, p, d, col, H)
		MsArts._shake(0.7)
		var inf = Jutsu._inf(c, "totsuka_no_tsurugi", 2.4, {"knock": 2.0, "kind": "heavy", "hitstop": 0.14, "dir": d})
		if c != Game.player and is_instance_valid(Game.player):
			# oyuncu Totsuka'yla mühürlenip ölmez: hasar mevcut canının yarısıyla sınırlı, sersemletme kalır
			inf["dmg"] = minf(float(inf.get("dmg", 0.0)), maxf(1.0, float(Game.player.hp) * 0.5))
		var hs = Combat.hit_sphere(c, p, 2.4 + H * 0.04, inf)
		for h in hs:
			if not MsArts._alive(h):
				continue
			h.apply_status("stun", 3.0)
			var sealable = h.has_method("die") and not (h is Player) and not h.has_meta("boss") and float(h.hp) <= float(h.max_hp) * 0.4
			if sealable:
				_totsuka_seal(host, c, sn, h, gourd, col)
			else:
				Combat.popup_text(MsArts._chest(h) + Vector3.UP, "Mühüre direniyor!", Color(1, 0.65, 0.55))
				# ruh testiye doğru çekiştirilir (iz), ama beden kopmaz
				_soul_drops(host, h, gourd, col, 8))
	# 3) kılıç geri akar, testi kaybolur
	MsArts._later(2.2, func():
		if not is_instance_valid(blade):
			return
		var tw3 = blade.create_tween()
		tw3.set_parallel(true)
		tw3.tween_method(func(x: float): st["len"] = x, st["len"], 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		tw3.tween_method(func(x: float): st["gs"] = x, 1.0, 0.02, 0.35).set_delay(0.35)
		tw3.chain().tween_callback(func():
			blade.queue_free()
			for dm3 in drips:
				if is_instance_valid(dm3):
					dm3.queue_free()
			if is_instance_valid(gourd):
				gourd.queue_free()))


## Susanoo renginde sıvı malzemeli parça; core: açık iç çekirdek (dış sıvının üstünde çizilir)
static func _liquid(mesh: Mesh, col: Color, core: bool) -> MeshInstance3D:
	var mi = _gi(mesh, _mat("liquid_core", LIQUID_SHADER, 1) if core else _mat("liquid", LIQUID_SHADER))
	if core:
		mi.set_instance_shader_parameter("c_core", Color.WHITE)
		mi.set_instance_shader_parameter("c_mid", Color(1.0, 0.97, 0.9, 0.85))
		mi.set_instance_shader_parameter("c_edge", col.lightened(0.5))
		mi.set_instance_shader_parameter("wob", 0.01)
	else:
		mi.set_instance_shader_parameter("c_core", col.lightened(0.6))
		mi.set_instance_shader_parameter("c_mid", Color(col.lightened(0.15).r, col.lightened(0.15).g, col.lightened(0.15).b, 0.92))
		mi.set_instance_shader_parameter("c_edge", col.darkened(0.6))
		mi.set_instance_shader_parameter("wob", 0.03)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


static func _liquid_blob(col: Color) -> MeshInstance3D:
	return _liquid(_mesh_sph(), col, false)


static func _liquid_gather(host: Node, at: Vector3, col: Color, S: float) -> void:
	for k in 9:
		var b = _liquid_blob(col)
		var a = TAU * k / 9.0
		var p = at + Vector3(cos(a), randf_range(-0.6, 0.8), sin(a)) * (1.6 + S * 0.5)
		_put(host, b, p)
		var s = 0.12 + S * 0.05
		b.scale = Vector3(s, s, s * 1.8)
		_face_dir(b, at - p)
		b.scale = Vector3(s, s, s * 1.8)
		var tw = b.create_tween()
		tw.tween_interval(k * 0.02)
		tw.tween_property(b, "global_position", at, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(b.queue_free)


## Saplama: delinen noktada sıvı taç (dışa kıvrılan dikenler), etrafa saçılan ağır damlalar ve zeminde sıvı lekesi
static func _totsuka_pierce(pj, host: Node, p: Vector3, d: Vector3, col: Color, H: float) -> void:
	var side = d.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up = side.cross(d).normalized()
	for k in 8:
		var a = TAU * k / 8.0
		var dir = ((side * cos(a) + up * sin(a)) * 0.85 - d * 0.35).normalized()
		var sp = _liquid(_mesh_drip(k % 3), col, false)
		_put(host, sp, p)
		sp.global_basis = _ybasis(dir)
		var L = 1.0 + H * 0.07
		sp.scale = Vector3(0.5, 0.05, 0.5)
		var tw = sp.create_tween()
		tw.tween_property(sp, "scale", Vector3(0.6, L, 0.6), 0.1).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector3(0.15, L * 0.4, 0.15), 0.4).set_ease(Tween.EASE_IN)
		tw.tween_callback(sp.queue_free)
	var g = pj.gp(p)
	for k in 14:
		var b = _liquid_blob(col)
		_put(host, b, p)
		var s = randf_range(0.08, 0.18) * (1.0 + H * 0.02)
		b.scale = Vector3.ONE * s
		var v = (Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)) - d * 0.5).normalized() * randf_range(3.0, 6.5)
		var p0 = p
		var lf = randf_range(0.5, 0.8)
		var tw = b.create_tween()
		tw.tween_method(func(x: float):
			if not is_instance_valid(b):
				return
			var q = p0 + v * x + Vector3.DOWN * 9.0 * x * x
			q.y = maxf(q.y, g.y + 0.05)
			b.global_position = q
			b.scale = Vector3(s, s * (1.0 + x * 1.5), s), 0.0, lf, lf)
		tw.tween_callback(b.queue_free)
	var sp2 = _decal(host, "splat", SPLAT_BODY, g, 1.6 + H * 0.06, {"c_mid": col.lightened(0.1), "c_edge": col.darkened(0.55), "fade": 1.0, "seed": randf() * 30.0})
	sp2.rotation.y = randf() * TAU
	_fade_free(sp2, 2.5, 1.0)


## Ruh damlaları: hedeften testinin ağzına yay çizerek akan, beyaz çekirdekli küçük sıvı damlaları
static func _soul_drops(host: Node, h: Node3D, gourd: Node3D, col: Color, n: int) -> void:
	for k in n:
		MsArts._later(k * 0.07, func():
			if not (is_instance_valid(h) and is_instance_valid(gourd)):
				return
			var w = _cel(_mesh_sph(), Color.WHITE, col.lightened(0.45), col.darkened(0.3), 0.05)
			host.add_child(w)
			var from = MsArts._chest(h) + Vector3(randf_range(-0.5, 0.5), randf_range(-0.6, 0.6), randf_range(-0.5, 0.5))
			w.global_position = from
			w.scale = Vector3.ONE * randf_range(0.15, 0.3)
			var tw = w.create_tween()
			var o = {"g": gourd, "w": w}
			tw.tween_method(func(x: float):
				if is_instance_valid(o["g"]) and is_instance_valid(o["w"]):
					var w2: Node3D = o["w"]
					var to = o["g"].to_global(Vector3(0, 0, 0.5))
					var mid = from.lerp(to, 0.5) + Vector3.UP * 2.0
					w2.global_position = from.lerp(mid, x).lerp(mid.lerp(to, x), x)
					w2.scale = Vector3.ONE * lerpf(0.25, 0.06, x), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(w.queue_free))


static func _totsuka_seal(host: Node, c: Node3D, sn: Susanoo, h: Node3D, gourd: Node3D, col: Color) -> void:
	Combat.popup_text(MsArts._chest(h) + Vector3.UP, "Totsuka: mühürlendi", col.lightened(0.4))
	Sfx.play("genjutsu", h.global_position, 0.5)
	_soul_drops(host, h, gourd, col, 18)
	var sh = sn.h()
	var m = h.get("model")
	if m:
		var tw = m.create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "scale", m.scale * Vector3(0.05, 1.4, 0.05), 1.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	MsArts._later(1.15, func():
		if not MsArts._alive(h):
			return
		h.die({"execute": true, "attacker": c, "dmg": 9999.0, "sealed": true})
		if is_instance_valid(h) and h.get("model"):
			h.model.visible = false
		if is_instance_valid(gourd):
			# testinin ağzı kapanır: sıvı içe çöker, ağızdan kısa sıvı dilleri
			var mouth = gourd.to_global(Vector3(0, 0, 0.5))
			var f = _cel(_mesh_sph(), Color.WHITE, col.lightened(0.5), col.darkened(0.4))
			_put(host, f, mouth)
			f.scale = Vector3.ONE * (0.8 + sh * 0.04)
			var ft = f.create_tween()
			ft.tween_property(f, "scale", Vector3.ONE * 0.02, 0.25).set_ease(Tween.EASE_IN)
			ft.tween_callback(f.queue_free)
			_shards(host, mouth, 6, 2.0 + sh * 0.05, 0.12 + sh * 0.005, 0.4, Color.WHITE, col.lightened(0.4), col.darkened(0.4)))


## Yata no Kagami (ref: Susanoo'nun önünde, Susanoo renginde eşmerkezli ince halkalarla dolu ayna kalkan): gerçek Susanoo
## sol kolu kalkanı göğsün önünde tutar; çerçeve Susanoo malzemesiyle, yüz kendi ayna gölgelendiricimiz; açılışta merkezden
## halka yayılır, her darbede ayna dalgalanır ve saldırı ışık çizgileri halinde öne geri yansır.
static func yata_no_kagami(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var sn = Susanoo.of(c, "yata_no_kagami")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var host = _host(pj)
	var DUR = 6.0
	var d = c.face_dir()
	var side = d.cross(Vector3.UP).normalized()
	MsArts._anim(c, "block", 1.0)
	# sol kol kalkanı göğsün önünde tutar
	sn.pose({"arms": Susanoo.arm(false, -side * 0.55 + d * 0.65 - Vector3.UP * 0.35, side * 0.8 + d * 0.45 + Vector3.UP * 0.3), "spine": 6.0}, DUR)
	var shield = Node3D.new()
	var mb = MB.new()
	mb.add("torus", Vector3.ZERO, Vector3(1.0, 0.16, 1.0), Color.WHITE, Vector3(90, 0, 0), 28)
	mb.add("torus", Vector3.ZERO, Vector3(0.62, 0.06, 0.62), Color.WHITE, Vector3(90, 0, 0), 24)
	for k in 12:   # kenar boncukları (aynanın süslü çerçevesi)
		var a = TAU * k / 12.0
		mb.add("sphere", Vector3(cos(a), sin(a), 0) * 0.5, Vector3(0.08, 0.08, 0.08), Color.WHITE, Vector3.ZERO, 8)
	mb.add("sphere", Vector3(0, 0, 0.02), Vector3(0.12, 0.12, 0.06), Color.WHITE, Vector3.ZERO, 10)
	shield.add_child(sn.chakra_mesh(mb, 1.4))
	var face = _gi(_mesh_quad(), _pmat("mirror", MIRROR_BODY))
	face.set_instance_shader_parameter("tint", col.lightened(0.25))
	face.set_instance_shader_parameter("ripple", 0.0)
	face.set_instance_shader_parameter("fade", 1.0)
	face.scale = Vector3(0.98, 0.98, 1.0)
	shield.add_child(face)
	host.add_child(shield)
	var stt = {"s": 0.05}
	var o = {"sn": sn, "sh": shield, "c": c, "f": face}
	var upd = func(_x: float):
		if not (is_instance_valid(o["sn"]) and is_instance_valid(o["sh"]) and is_instance_valid(o["c"])):
			return
		var fd = o["c"].face_dir()
		var at = o["sn"].bone_at("LeftLowerArm").lerp(o["sn"].bone_at("LeftHand"), 0.55) + fd * S * 0.12
		o["sh"].global_transform = Transform3D(MsArts._zbasis(fd) * Basis.from_scale(Vector3.ONE * S * 1.05 * stt["s"]), at)
	var tw = shield.create_tween()
	tw.set_parallel(true)
	tw.tween_method(upd, 0.0, 1.0, DUR + 0.4)
	tw.tween_method(func(x: float): stt["s"] = x, 0.05, 1.0, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(x: float): stt["s"] = x, 1.0, 0.02, 0.35).set_delay(DUR)
	tw.chain().tween_callback(shield.queue_free)
	_mirror_ripple(face, 0.6)
	Sfx.play("chakra", c.global_position, 0.6)
	if c is Player:
		Buffs.add("yata", DUR, {"armor": 0.05, "_name": "Yata no Kagami", "_desc": "ayna kalkan: gelen hasar %95 azalır"})
	else:
		c.set_meta("yata_until", Time.get_ticks_msec() + int(DUR * 1000.0))
	var inf = Jutsu._inf(c, "yata_no_kagami", 0.3, {"knock": 20.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.04})
	var last = {"hp": float(c.hp)}
	Jutsu._ticks(int(DUR / 0.25), 0.25, func(i):
		if not (is_instance_valid(o["c"]) and is_instance_valid(o["sh"])):
			return
		var shield2: Node3D = o["sh"]
		var fd = c.face_dir()
		# darbe aldıysa ayna dalgalanır ve saldırganları geri savurur (niteliğini değiştirip yansıtır)
		if float(c.hp) < last["hp"] - 0.01 or i % 2 == 0:
			var struck = float(c.hp) < last["hp"] - 0.01
			var hs = Combat.hit_sphere(c, c.global_position + fd * H * 0.3 + Vector3.UP * H * 0.2, H * 0.22 + 2.0, inf)
			if struck or not hs.is_empty():
				if is_instance_valid(o["f"]):
					_mirror_ripple(o["f"], 0.35)
				_mirror_reflect(host, shield2.global_position + fd * S * 0.1, fd, col, S)
		last["hp"] = float(c.hp))


static func _mirror_ripple(face: MeshInstance3D, dur: float) -> void:
	var tw = face.create_tween()
	tw.tween_method(_pf(face, "ripple"), 0.0, 1.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(face, "ripple"), 0.0, 0.0, 0.01)


## Yansıma: aynanın yüzünden öne, koni biçiminde açılan Susanoo renkli ışık çizgileri + merkezde kısa beyaz parıltı
static func _mirror_reflect(host: Node, at: Vector3, fd: Vector3, col: Color, S: float) -> void:
	var side = fd.cross(Vector3.UP).normalized()
	for k in 9:
		var a = TAU * k / 9.0 + randf() * 0.3
		var off = (side * cos(a) + Vector3.UP * sin(a)) * S * randf_range(0.15, 0.45)
		var dir = (fd + off.normalized() * 0.45).normalized()
		_streak(host, at + off, dir, 1.0 + S * 0.4, 0.08 + S * 0.03, 0.3, col.lightened(0.45), Color.WHITE, 2.0 + S)
	var gl = _cel(_mesh_sph(), Color.WHITE, col.lightened(0.7), col)
	_put(host, gl, at)
	gl.scale = Vector3.ONE * S * 0.2
	var tw = gl.create_tween()
	tw.tween_property(gl, "scale", Vector3.ONE * 0.02, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(gl.queue_free)


## Magen: Karasu Bunshin (ref: beden kenarlarından yırtılıp karga kanatlarına dönüşür, kara tüyler savrulur):
## gerçek model gizlenir, kargalar bedenin hacminden fırlar (küçükten büyüyerek), tüy patlaması; kıvrılarak hedefin
## arkasına uçar, orada toplanıp tüylere dağılır ve beden belirir; hedefte kızıl tomoe yanılsama işareti döner,
## sersemlik boyunca başının çevresinde üç karga tur atar.
static func magen_karasu_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 35.0)
	var from = c.global_position
	var dest: Vector3 = (tg.global_position + (tg.global_position - from).normalized() * 2.0) if tg else Jutsu._ground(from + Jutsu._aim_flat(c, t) * 14.0)
	dest = Jutsu._ground(dest)
	var host = _host(pj)
	Sfx.play("genjutsu", from, 0.9)
	if c.get("model"):
		c.model.visible = false
	_feathers(host, from + Vector3.UP, 16, 0.9)
	_crow_flight(host, from + Vector3.UP, dest + Vector3.UP, 26, 0.7, func():
		if not is_instance_valid(c):
			return
		c.global_position = dest
		if c.has_method("reset_physics_interpolation"):
			c.reset_physics_interpolation()
		if c.get("model"):
			c.model.visible = true
		_feathers(host, dest + Vector3.UP, 14, 0.7)
		if tg and is_instance_valid(tg) and not tg.is_dead():
			tg.apply_status("stun", 2.2)
			tg.take_hit(Jutsu._inf(c, "magen_karasu_bunshin", 1.0, {"knock": 6.0, "attacker": c, "dir": (tg.global_position - dest).normalized()}))
			_genjutsu_mark(host, tg, 2.2))


## Karga sürüsü (MsArts karga modeli): bedenin hacminden fırlar, kıvrılarak hedefe uçar, varınca tüye dağılır
static func _crow_flight(host: Node, from: Vector3, to: Vector3, n: int, dur: float, on_arrive := Callable()) -> void:
	var cs = []
	for i in n:
		var cr = MsArts._crow()
		host.add_child(cr)
		cr.global_position = from + Vector3(randf_range(-0.35, 0.35), randf_range(-0.9, 0.8), randf_range(-0.35, 0.35))
		var sc = randf_range(1.0, 1.5)
		cr.scale = Vector3.ONE * 0.05
		cr.create_tween().tween_property(cr, "scale", Vector3.ONE * sc, 0.1).set_delay(randf() * 0.08)
		cs.append([cr, cr.global_position, Vector3(randf_range(-4, 4), randf_range(1.5, 5.0), randf_range(-4, 4)), randf() * 0.25,
			Vector3(randf_range(-0.35, 0.35), randf_range(-0.9, 0.8), randf_range(-0.35, 0.35))])
	var tw = MsArts._tw()
	tw.tween_method(func(x: float):
		for e in cs:
			var cr: Node3D = e[0]
			if not is_instance_valid(cr):
				continue
			var k = clampf((x - float(e[3])) / (1.0 - float(e[3])), 0.0, 1.0)
			var p0: Vector3 = e[1]
			var dst: Vector3 = to + e[4]
			var mid: Vector3 = (p0 + dst) * 0.5 + e[2]
			var p = p0.lerp(mid, k).lerp(mid.lerp(dst, k), k)
			if p.distance_to(cr.global_position) > 0.01:
				cr.look_at(p + (p - cr.global_position), Vector3.UP)
			cr.global_position = p
			MsArts._flap(cr, x * dur + float(e[3]) * 10.0), 0.0, 1.0, dur)
	tw.tween_callback(func():
		var j = 0
		for e in cs:
			if is_instance_valid(e[0]):
				if j % 3 == 0:
					_feathers(host, e[0].global_position, 1, 0.5, 1.4)
				e[0].queue_free()
			j += 1
		if on_arrive.is_valid():
			on_arrive.call())


## Yanılsama işareti: hedefin göğsünde kameraya dönük kızıl tomoe döner; başının çevresinde sersemlik boyunca üç karga
static func _genjutsu_mark(host: Node, tg: Node3D, dur: float) -> void:
	var mk = _gi(_mesh_quad(), _pmat("tomoe", TOMOE_BODY, true))
	mk.set_instance_shader_parameter("fade", 1.0)
	mk.set_instance_shader_parameter("spin", randf() * TAU)
	_put(host, mk, MsArts._chest(tg))
	mk.scale = Vector3.ONE * 0.2
	var tw = mk.create_tween()
	tw.tween_property(mk, "scale", Vector3.ONE * 1.6, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mk, "fade"), 1.0, 0.0, 0.45)
	tw.tween_callback(mk.queue_free)
	var crows = []
	for k in 3:
		var cr = MsArts._crow()
		host.add_child(cr)
		cr.scale = Vector3.ONE * 1.1
		crows.append(cr)
	var wt = weakref(tg)
	var ph = randf() * TAU
	var ct = MsArts._tw()
	ct.tween_method(func(x: float):
		var n = wt.get_ref()
		for k in crows.size():
			var cr: Node3D = crows[k]
			if not is_instance_valid(cr):
				continue
			if n == null or not is_instance_valid(n):
				cr.visible = false
				continue
			var a = ph + k * TAU / 3.0 + x * dur * 3.2
			var top = (n as Node3D).global_position + Vector3.UP * (float(n.get("height")) if n.get("height") != null else 1.8)
			var p = top + Vector3(cos(a), 0.25 + 0.15 * sin(x * 20.0 + k), sin(a)) * 0.9
			var nx = top + Vector3(cos(a + 0.2), 0.25, sin(a + 0.2)) * 0.9
			cr.global_position = p
			if nx.distance_to(p) > 0.01:
				cr.look_at(nx, Vector3.UP)
			MsArts._flap(cr, x * dur + k), 0.0, 1.0, dur)
	ct.tween_callback(func():
		for cr in crows:
			if is_instance_valid(cr):
				if cr.visible:
					_feathers(host, cr.global_position, 3, 0.5, 1.3)
				cr.queue_free())


# ================================================================== Susanoo: Kai / Kanseitai Susanoo: Kishin
## Susanoo: Kai (ref Narutopedia "Susanoo: Crush"): gerçek Susanoo eli uzanır, kavrar, yumruğunda ezer; her sıkışta
## yumruğa doğru çöken basınç çizgileri ve dışa fırlayan chakra kıymıkları; fırlatışta hedefin yere çarptığı yerde
## savrulma yönünde uzanan çukur, öne püsküren toz ve taş.
static func susanoo_kai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_kai")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var host = _host(pj)
	var tg = Jutsu._tg(c, t, 6.0 + H * 1.2)
	if tg == null:
		if c is Player:
			Hud.msg("Hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var aim = MsArts._aim_fn(c, tg, 4.0 + H * 0.45)
	var d = MsArts._turn(c, aim.call())
	pj.busy(c, 1.4)
	MsArts._anim(c, "push", 1.0)
	# uzan: el rakibe açık uzanır
	var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
	sn.pose({"arms": Susanoo.arm(true, ad, ad, ad), "spine": 10.0}, 0.9)
	Sfx.play("whoosh", c.global_position, 0.6, 0.7)
	MsArts._later(0.35, func():
		if not (is_instance_valid(c) and is_instance_valid(sn) and is_instance_valid(tg)) or tg.is_dead():
			return
		# kavra: hedef yumruğun içine alınır, havaya kaldırılır
		if tg.has_method("apply_status"):
			tg.apply_status("bind", 1.6)
		var hold = sn.hand(true)
		sn.pose({"arms": Susanoo.arm(true, (d + Vector3.UP * 0.6).normalized(), (d + Vector3.UP * 0.9).normalized(), Vector3.UP), "spine": 4.0}, 1.0)
		for k in 4:
			MsArts._later(0.15 + k * 0.25, func():
				if is_instance_valid(sn) and is_instance_valid(tg) and not tg.is_dead():
					tg.global_position = sn.hand(true) - Vector3.UP * 0.9
					if tg is CharacterBody3D:
						tg.velocity = Vector3.ZERO
					tg.take_hit(Jutsu._inf(c, "susanoo_kai", 0.45, {"knock": 0.0, "launch": 0.0, "kind": "crush", "pierce_guard": true}))
					_crush_pulse(host, sn.hand(true), col, S)
					Sfx.play("hit_heavy", tg.global_position, 0.7, 0.6))
		Combat.popup_text(hold + Vector3.UP * 1.5, "Susanoo: Kai!", col.lightened(0.3)))
	# fırlat: el aşağı savrulur, hedef yere çarpar
	MsArts._later(1.4, func():
		if not (is_instance_valid(c) and is_instance_valid(sn) and is_instance_valid(tg)) or tg.is_dead():
			return
		sn.pose({"arms": Susanoo.arm(true, (d - Vector3.UP * 0.5).normalized(), d, d)}, 0.5, true)
		tg.take_hit(Jutsu._inf(c, "susanoo_kai", 1.2, {"knock": 18.0, "launch": -10.0, "kind": "heavy", "dir": d, "hitstop": 0.1}))
		var g = Jutsu._ground(tg.global_position)
		_slam(host, g, d, S)
		MsArts._shake(0.6))


static func _crush_pulse(host: Node, at: Vector3, col: Color, S: float) -> void:
	for k in 10:
		var dir = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var p = at + dir * (1.2 + S * 0.6)
		_streak(host, p, at - p, 0.8 + S * 0.3, 0.07 + S * 0.02, 0.18, col.lightened(0.4), Color.WHITE, (1.2 + S * 0.6) * 0.8)
	_shards(host, at, 6, 1.5 + S * 0.4, 0.1 + S * 0.03, 0.35, col.lightened(0.6), col.lightened(0.2), col.darkened(0.5), 2.0)


## Fırlatılan bedenin çarptığı yer: savrulma yönünde uzanan çukur, öne püsküren toz ve taş
static func _slam(host: Node, g: Vector3, d: Vector3, S: float) -> void:
	var r = S * 0.6 + 2.2
	var sc = _decal(host, "scar", SCAR_BODY, g, 1.0, {"tint": EARTH, "fade": 1.0, "seed": randf() * 50.0, "rays": 7.0})
	var dh = Vector3(d.x, 0.0, d.z).normalized() if Vector3(d.x, 0.0, d.z).length() > 0.01 else Vector3.FORWARD
	sc.global_basis = Basis.looking_at(dh, Vector3.UP) * Basis.from_scale(Vector3(r * 0.75, 1.0, r * 1.35))
	_fade_free(sc, 2.5, 1.2)
	_chunks(host, g + Vector3.UP * 0.4, g.y, 12, 7.0, 0.35, EARTH, 1.1)
	for k in 7:
		var side = dh.cross(Vector3.UP) * randf_range(-1.0, 1.0)
		_dust(host, g + Vector3.UP * 0.3 + side * r * 0.4, randf_range(0.9, 1.4), 0.9, (dh * randf_range(2.0, 4.5) + side * 1.5 + Vector3.UP * 0.6))


## Kanseitai Susanoo: Kishin (Shinobi Striker): mükemmel Susanoo göğe sıçrar (sıçrama yerinde toz halkası, taş, yükselen
## chakra çizgileri), matkap kılıcını (Susanoo'nun kendi matkap geometrisi ve malzemesi) aşağı çevirip dönerek iner
## (ardında sarmal hava çizgileri); indiği yer çöker: geniş krater, dışa yatmış kaya levhaları zeminden fırlar,
## dairesel toz duvarı, savrulan taşlar; matkap toprağa gömülerek söner.
static func kanseitai_susanoo_kishin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "kanseitai_susanoo_kishin")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var host = _host(pj)
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var land: Vector3 = Jutsu._ground(tg.global_position if tg else c.global_position + c.face_dir() * (14.0 + H * 0.5))
	var d = MsArts._turn(c, land)
	var from = c.global_position
	pj.busy(c, 2.1)
	MsArts._flicker_guard(c, 2.0)
	MsArts._anim(c, "jump", 1.0)
	sn.hide_weapons(2.3)
	sn.pose({"arms": Susanoo.arm(true, Vector3.UP * 0.9 + d * 0.2, Vector3.UP) + Susanoo.arm(false, Vector3.UP * 0.9 + d * 0.2, Vector3.UP), "spine": -8.0}, 1.1, true)
	var mb = MB.new()
	Susanoo._drill(mb, Vector3.ZERO, Vector3(0, 0, -1), 2.6, 0.34, Color.WHITE)
	var dr = sn.chakra_mesh(mb, 1.5)
	host.add_child(dr)
	dr.scale = Vector3.ONE * S * 1.25
	sn.follow_fx(dr, 2.2, func(): return sn.hand(true).lerp(sn.hand(false), 0.5), func(): return Vector3.DOWN * 4.0 + d * 0.4, d)
	var apex = from.lerp(land, 0.55) + Vector3.UP * (10.0 + H * 0.9)
	_takeoff(host, Jutsu._ground(from), col, S)
	Sfx.play("whoosh", from, 0.6)
	var tw = MsArts._tw()
	tw.tween_method(func(x: float):
		if MsArts._alive(c):
			MsArts._blink(c, from.lerp(apex, x)), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_callback(func():
		if is_instance_valid(sn):
			sn.pose({"arms": Susanoo.arm(true, Vector3.DOWN * 0.8 + d * 0.3, Vector3.DOWN) + Susanoo.arm(false, Vector3.DOWN * 0.8 + d * 0.3, Vector3.DOWN), "spine": 22.0}, 1.0, true))
	var trail = {"n": 0}
	var fall = (land - apex).normalized()
	tw.tween_method(func(x: float):
		if MsArts._alive(c):
			MsArts._blink(c, apex.lerp(land + Vector3.UP * 0.1, x))
			if is_instance_valid(dr):
				dr.rotate_object_local(Vector3(0, 0, 1), 0.7)
				trail["n"] += 1
				if trail["n"] % 2 == 0:
					var a = trail["n"] * 1.3
					var s1 = fall.cross(Vector3.RIGHT).normalized()
					var s2 = fall.cross(s1)
					var off = (s1 * cos(a) + s2 * sin(a)) * S * 0.9
					var lt = 3.0 + S * 1.5
					_streak(host, dr.global_position + off - fall * lt, fall, lt, 0.12 + S * 0.05, 0.3, col.lightened(0.5), Color.WHITE), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not MsArts._alive(c):
			return
		var R = 5.0 + S * 2.2
		Combat.hit_sphere(c, land + Vector3.UP, R, MsArts._inf(c, "kanseitai_susanoo_kishin", 1.0, {"knock": 16.0, "kind": "heavy", "hard_down": true, "hitstop": 0.1}))
		_kishin_impact(host, land, R, col)
		MsArts._shake(1.6)
		Sfx.play("boom", land, 0.7))
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if is_instance_valid(dr):
			dr.queue_free())


static func _takeoff(host: Node, g: Vector3, col: Color, S: float) -> void:
	var r = 2.5 + S
	for k in 10:
		var a = TAU * k / 10.0 + randf() * 0.3
		_dust(host, g + Vector3(cos(a), 0.3, sin(a)) * r * 0.5, randf_range(1.0, 1.6), 0.9, Vector3(cos(a), 0.1, sin(a)) * r * 1.4)
	_chunks(host, g + Vector3.UP * 0.4, g.y, 10, 8.0, 0.35, EARTH, 1.1)
	for k in 8:
		var a = TAU * k / 8.0
		_streak(host, g + Vector3(cos(a), 0.2, sin(a)) * r * 0.6, Vector3.UP, 6.0 + S * 2.0, 0.2 + S * 0.05, 0.45, col.lightened(0.35), Color.WHITE, 4.0)
	_scar(host, g, r * 1.2, EARTH, 9.0, 2.0, 1.0)


static func _kishin_impact(host: Node, land: Vector3, R: float, col: Color) -> void:
	_scar(host, land, R * 1.6, EARTH.darkened(0.1), 14.0, 4.0, 1.5)
	# dışa yatmış kaya levhaları zeminden fırlar, sonra geri gömülür
	for k in 10:
		var a = TAU * k / 10.0 + randf() * 0.3
		var rr = R * randf_range(0.55, 0.95)
		var p = land + Vector3(cos(a), 0.0, sin(a)) * rr
		var sl = _gi(_mesh_rock(k % 4, EARTH.darkened(randf() * 0.15), "crag"), null)
		var hgt = R * randf_range(0.25, 0.45)
		var wd = R * randf_range(0.12, 0.2)
		_put(host, sl, p - Vector3.UP * hgt)
		var outv = Vector3(cos(a), 0.0, sin(a))
		sl.global_basis = Basis(outv.cross(Vector3.UP).normalized(), -deg_to_rad(randf_range(25.0, 45.0))) * Basis(Vector3.UP, randf() * TAU) * Basis.from_scale(Vector3(wd, hgt, wd * 0.7))
		var tw = sl.create_tween()
		tw.tween_property(sl, "global_position", p - Vector3.UP * hgt * 0.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(3.0 + randf() * 0.5)
		tw.tween_property(sl, "global_position", p - Vector3.UP * hgt * 1.1, 0.8).set_ease(Tween.EASE_IN)
		tw.tween_callback(sl.queue_free)
	# dairesel toz duvarı
	for k in 16:
		var a = TAU * k / 16.0
		_dust(host, land + Vector3(cos(a), 0.4, sin(a)) * R * 0.6, randf_range(1.6, 2.4), 1.3, Vector3(cos(a), 0.25, sin(a)) * R * 0.9)
	_chunks(host, land + Vector3.UP * 0.5, land.y, 26, 16.0, 0.5, EARTH, 1.4)
	for k in 6:
		var a = randf() * TAU
		_streak(host, land + Vector3(cos(a), 0.3, sin(a)) * R * 0.3, Vector3(cos(a), 1.2, sin(a)), R * 0.8, 0.3, 0.35, col.lightened(0.4), Color.WHITE, R * 0.5)
