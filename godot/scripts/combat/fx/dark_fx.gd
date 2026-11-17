class_name DarkFX
extends RefCounted
## Meiton (karanlık salımı / chakra emme): 10 tekniğin tam akışı + kendine ait görsel yapı taşları.
## Hazır / ortak efekt yardımcısı KULLANILMAZ: kendi gölgelendiricileri (mürekkep gövde, şerit, avuç mührü, ışık büken mercek,
## yer sisi, bacak sarmalı, kara gölcük, emilen saldırı kaplaması), kendi şerit / damla / iz düzeneği (Ticker).
## Görünüş: mürekkep siyahı + içte mor / çivit ışıltı + ince soluk leylak kenar (cel). Emme = içe akış (avuçtaki mühre çekilen
## iplikler, ışık mühre doğru bükülüp kararır, emilen saldırı küçülüp mühürde erir). Salım = dışa itilen kara-mor kütle.
## Şimşek, duman bulutu, düz halka dalgası yok.
## Oynanış PathJutsu'daki eski gövdelerden satır satır taşındı ("meiton_store" birikimi, emme kalkanı, yansıtma, bağ, emme).

const INK := Color(0.022, 0.008, 0.045)
const VIOLET := Color(0.40, 0.14, 0.70)
const INDIGO := Color(0.17, 0.07, 0.42)
const LILAC := Color(0.86, 0.75, 1.0)

static var _shaders := {}
static var _cache := {}


# ═════════════════════════════════════════ gölgelendiriciler ═════════════════════════════════════════

const SH_NOISE := """
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
"""

## Mürekkep gövde: koyu öz, içte gürültülü mor ışıltı (cel basamak), ince leylak kenar. invert=1: kenar kara, leylak bant
## siluetin hemen içinde (boşluk küresi). wobble: yüzey dalgalanır. dissolve: gürültüyle aşınır, aşınma kenarı leylak.
const SH_INK := """
uniform vec4 core : source_color = vec4(0.022, 0.008, 0.045, 1.0);
uniform vec4 glow : source_color = vec4(0.32, 0.11, 0.62, 1.0);
uniform vec4 rim : source_color = vec4(0.86, 0.75, 1.0, 1.0);
uniform float rim_w = 0.14;
uniform float glow_amt = 0.6;
uniform float dark_below = 0.0;
uniform float wobble = 0.0;
uniform float wob_freq = 2.5;
uniform float dissolve = 0.0;
uniform float fade = 1.0;
uniform float invert = 0.0;
uniform float spikes = 0.0;
uniform float spike_freq = 7.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	if (wobble > 0.0) {
		float w = n3(VERTEX * wob_freq + vec3(0.0, TIME * 1.6, TIME * 0.7));
		VERTEX += NORMAL * (w - 0.5) * wobble;
	}
	if (spikes > 0.0) {   // tüylü / dikenli mürekkep silueti (Yami Yami karanlığı gibi)
		float s = n3(lp * spike_freq + vec3(TIME * 0.8, -TIME * 1.1, TIME * 0.3));
		VERTEX += NORMAL * pow(s, 4.0) * spikes * 3.0 * COLOR.r;   // köşe rengi kırmızısı = diken payı (parmak uçları 0)
	}
}
void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	float n = n3(lp * 3.5 + vec3(0.0, -TIME * 0.9, TIME * 0.4));
	float d = n3(lp * 5.0 + vec3(7.3, 1.1, 3.7));
	if (d < dissolve) { discard; }
	if (h2(floor(FRAGCOORD.xy)) > fade) { discard; }
	vec3 col = core.rgb;
	// iç ışıltı iki cel basamak: geniş koyu çivit gölge + küçük mor çekirdek lekeleri (gövde mürekkep siyahı kalır)
	float g = (1.0 - fr) * (0.45 + 0.85 * n);
	col = mix(col, glow.rgb * 0.32, step(0.42, g) * glow_amt);
	col = mix(col, glow.rgb, step(0.66, g) * glow_amt * 0.85);
	// zemine / köke yakın taraf koyulaşır (dark_below: yerel y; 0 = kapalı)
	float db = step(0.0001, dark_below);
	col = mix(core.rgb * 0.6, col, mix(1.0, smoothstep(0.0, max(dark_below, 0.0001), lp.y), db));
	// leylak kenarın içinde ince kara kontur
	col = mix(col, core.rgb * 0.5, step(1.0 - rim_w - 0.1, fr) * (1.0 - invert));
	float band_n = step(1.0 - rim_w, fr);
	float band_i = step(0.6, fr) * (1.0 - step(0.6 + rim_w, fr));
	col = mix(col, rim.rgb, mix(band_n, band_i, invert));
	col = mix(col, vec3(0.0), invert * step(0.6 + rim_w, fr));
	col = mix(col, rim.rgb, step(d, dissolve + 0.07) * step(0.001, dissolve));
	ALBEDO = col;
}
"""

## Şerit (iplik / bağ / iz): ortası mürekkep, yanları mor, en kenar leylak; kenarı yırtık. flow>0: leylak atımlar UV.x=0
## ucuna (avuca) doğru akar. Saydamlık köşe renginden (COLOR.a).
const SH_STRIP := """
uniform vec4 core : source_color = vec4(0.022, 0.008, 0.045, 1.0);
uniform vec4 glow : source_color = vec4(0.40, 0.14, 0.70, 1.0);
uniform vec4 rim : source_color = vec4(0.86, 0.75, 1.0, 1.0);
uniform float flow = 0.0;
uniform float pulses = 5.0;
uniform float ragged = 1.0;
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	float w = 1.0 - ragged * 0.35 * n2(vec2(UV.x * 9.0 - TIME * 2.0, 0.5)) - ragged * 0.25 * step(0.6, h2(vec2(floor(UV.x * 40.0), 3.0)));
	if (e > w) { discard; }
	e /= w;
	vec3 col = core.rgb;
	col = mix(col, glow.rgb * 0.45, step(0.4, e));
	col = mix(col, glow.rgb, step(0.62, e) * 0.9);
	col = mix(col, rim.rgb, step(0.86, e));
	if (flow > 0.0) {
		float pl = step(0.8, fract(UV.x * pulses + TIME * flow));
		col = mix(col, rim.rgb, pl * (1.0 - step(0.5, e)));
	}
	ALBEDO = col;
	ALPHA = COLOR.a;
}
"""

## Mühür: daire + iç halka + dönen radyal çentikler + ters dönen dört kol + ortada dönen eşkenar dörtgen; arkasında kararan
## mürekkep diski (ışık mühre doğru kararır). reveal: halkalar merkezden açılır. bb=1: kameraya döner.
const SH_GLYPH := """
uniform vec4 ink : source_color = vec4(0.022, 0.008, 0.045, 1.0);
uniform vec4 glow : source_color = vec4(0.40, 0.14, 0.70, 1.0);
uniform vec4 rim : source_color = vec4(0.86, 0.75, 1.0, 1.0);
uniform float power = 1.0;
uniform float spin = 2.0;
uniform float reveal = 1.0;
uniform float outer = 0.0;
uniform float ticks = 12.0;
uniform float back = 0.55;
uniform float bb = 0.0;
void vertex() {
	if (bb > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || r > reveal * 1.05 + 0.02) { discard; }
	float a = atan(p.y, p.x);
	float rot = TIME * spin;
	float lw = fwidth(r) * 1.5 + 0.012;
	float ring_o = 1.0 - smoothstep(lw, lw * 2.0, abs(r - 0.88));
	float ring_m = 1.0 - smoothstep(lw, lw * 2.0, abs(r - 0.66));
	float ring_x = (1.0 - smoothstep(lw, lw * 2.0, abs(r - 0.97))) * step(0.5, outer);
	float rich = step(0.5, outer);
	float ta = fract((a + rot) / 6.2831853 * ticks);
	float tick = step(abs(ta - 0.5), 0.06) * step(mix(0.68, 0.81, rich), r) * step(r, 0.86);
	// zengin mühür (outer=1): nokta halkası, ince tarama kuşağı, sekiz köşeli yıldız, iç halka, halkalar arası yay yazıları
	float dc = fract((a - rot * 0.5) / 6.2831853 * 24.0) - 0.5;
	float dots = (1.0 - smoothstep(0.016, 0.024, length(vec2(dc * 0.2029, r - 0.745)))) * rich;
	float hc = fract((a - rot * 0.8) / 6.2831853 * 96.0);
	float hatch = step(abs(hc - 0.5), 0.14) * step(0.905, r) * step(r, 0.95) * rich;
	float ca2 = cos(rot * 0.3 + 0.3927);
	float sa2 = sin(rot * 0.3 + 0.3927);
	vec2 q2 = vec2(ca2 * p.x - sa2 * p.y, sa2 * p.x + ca2 * p.y);
	float sq1 = max(abs(q2.x), abs(q2.y));
	float sq2 = (abs(q2.x) + abs(q2.y)) * 0.7071;
	float star = max(1.0 - smoothstep(lw, lw * 2.0, abs(sq1 - 0.44)), 1.0 - smoothstep(lw, lw * 2.0, abs(sq2 - 0.44))) * rich * step(r, 0.65);
	float ring_i = (1.0 - smoothstep(lw, lw * 2.0, abs(r - 0.27))) * rich;
	float rc = fract((a + rot * 0.35) / 6.2831853 * 8.0);
	float runes = (1.0 - smoothstep(lw, lw * 2.0, abs(r - 0.72))) * step(0.15, rc) * step(rc, 0.4) * rich;
	tick = max(tick, max(max(dots, hatch), max(star, max(ring_i, runes))));
	float sa = fract((a - rot * 1.7) / 6.2831853 * 4.0);
	float spoke = step(abs(sa - 0.5), 0.035) * step(0.22, r) * step(r, 0.62);
	float cr = cos(rot * 0.6);
	float sr = sin(rot * 0.6);
	vec2 q = vec2(cr * p.x - sr * p.y, sr * p.x + cr * p.y);
	float diamond = 1.0 - smoothstep(lw, lw * 2.2, abs(abs(q.x) + abs(q.y) - 0.4));
	float dot_c = 1.0 - smoothstep(0.09, 0.11, r);
	float m = max(max(max(ring_o, ring_m), max(tick, spoke)), max(max(diamond, dot_c), ring_x));
	float hot = step(0.0, sin(TIME * 7.0 - r * 9.0));
	vec3 col = mix(glow.rgb, rim.rgb, 0.35 + 0.65 * hot);
	float bk = back * (1.0 - smoothstep(0.85, 1.0, r)) * (0.6 + 0.4 * (1.0 - r));
	// zemin dolgusu: halkalar arası koyu çivit, dışa doğru mor parıltı
	vec3 fill = mix(ink.rgb, glow.rgb * 0.45, rich * smoothstep(0.3, 0.95, r) * step(0.5, n2(p * 5.0 + vec2(TIME * 0.3, 0.0))));
	ALBEDO = mix(fill, col, m);
	ALPHA = clamp(max(m, bk) * power, 0.0, 1.0);
}
"""

## Mercek: kameraya dönük disk; arkasındaki görüntüyü merkeze doğru sıkıştırıp burar ve karartır (ışık mühre / boşluğa bükülür)
const SH_LENS := """
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.40, 0.14, 0.70, 1.0);
uniform float strength = 0.05;
uniform float dark = 0.6;
uniform float swirl = 2.5;
uniform float power = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float k = 1.0 - r;
	float ang = swirl * k * k * power;
	float ca = cos(ang);
	float sa = sin(ang);
	vec2 dirv = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
	vec3 bg = textureLod(scr, SCREEN_UV + dirv * strength * k * power, 0.0).rgb;
	float dk = dark * power * k * k;
	vec3 col = mix(bg, bg * tint.rgb, dk);
	col *= 1.0 - dk * 0.7;
	ALBEDO = col;
	ALPHA = smoothstep(1.0, 0.7, r) * clamp(power, 0.0, 1.0);
}
"""

## Yere çöken mürekkep sisi katmanı (düz disk): dünya konumuna bağlı kayan gürültü, 3 cel yoğunluk basamağı, alt katmanda ince
## leylak kontur; zemine değdiği yerde yumuşak söner (derinlik).
const SH_FOG := """
uniform sampler2D dtex : hint_depth_texture, filter_nearest;
uniform vec4 ink : source_color = vec4(0.022, 0.008, 0.045, 1.0);
uniform vec4 glow : source_color = vec4(0.17, 0.07, 0.42, 1.0);
uniform vec4 rim : source_color = vec4(0.86, 0.75, 1.0, 1.0);
uniform float density = 1.0;
uniform float layer = 0.0;
uniform float soft = 0.5;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = n2(wp.xz * 0.45 + vec2(TIME * 0.25, -TIME * 0.18)) * 0.6 + n2(wp.xz * 1.3 - vec2(TIME * 0.4, TIME * 0.1)) * 0.4;
	float edge = smoothstep(1.0, 0.55 - 0.25 * n, r);
	float dens = edge * (n + 0.35 - layer * 0.45);
	float band = step(0.28, dens) * 0.55 + step(0.5, dens) * 0.3 + step(0.72, dens) * 0.15;
	vec3 col = mix(ink.rgb, glow.rgb, step(0.62, dens) * 0.7);
	col = mix(col, rim.rgb * 0.8, (step(0.28, dens) - step(0.32, dens)) * (1.0 - layer));
	float depth = texture(dtex, SCREEN_UV).r;
	vec4 vw = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vw.xyz /= vw.w;
	float sf = clamp((VERTEX.z - vw.z) / soft, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = band * density * sf;
}
"""

## Bacaklara sarılan sis: açık silindir, aşağıda yoğun, yukarı doğru yırtılarak incelir
const SH_WISP := """
uniform vec4 ink : source_color = vec4(0.022, 0.008, 0.045, 1.0);
uniform vec4 glow : source_color = vec4(0.40, 0.14, 0.70, 1.0);
uniform vec4 rim : source_color = vec4(0.86, 0.75, 1.0, 1.0);
uniform float power = 1.0;
varying float ly;
varying vec2 dv;
void vertex() { ly = VERTEX.y + 0.5; dv = normalize(VERTEX.xz + vec2(0.0001, 0.0)); }
void fragment() {
	float n = n2(dv * 2.2 + vec2(ly * 3.0 - TIME * 0.8, TIME * 0.5));
	float d = (1.0 - ly) * (0.55 + 0.7 * n) - ly * 0.2;
	float band = step(0.35, d) * 0.6 + step(0.6, d) * 0.3;
	vec3 col = mix(ink.rgb, glow.rgb, step(0.75, d) * 0.5);
	col = mix(col, rim.rgb * 0.85, step(0.35, d) - step(0.4, d));
	ALBEDO = col;
	ALPHA = band * power;
}
"""

## Kara gölcük: düzensiz kenarlı parlak mürekkep, içinde dönen mor akıntılar, kenarda leylak çizgi
const SH_POOL := """
uniform vec4 ink : source_color = vec4(0.022, 0.008, 0.045, 1.0);
uniform vec4 glow : source_color = vec4(0.40, 0.14, 0.70, 1.0);
uniform vec4 rim : source_color = vec4(0.86, 0.75, 1.0, 1.0);
uniform float open = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dirv = p / max(r, 0.0001);
	float er = open * (0.8 + 0.16 * n2(dirv * 2.5 + vec2(TIME * 0.4, -TIME * 0.3)));
	if (r > er) { discard; }
	float ang = TIME * 0.7 + r * 4.0;
	vec2 rd = vec2(cos(ang) * dirv.x - sin(ang) * dirv.y, sin(ang) * dirv.x + cos(ang) * dirv.y);
	float sw = n2(rd * 3.0 + vec2(r * 5.0, r * 3.0));
	vec3 col = ink.rgb;
	col = mix(col, glow.rgb * 0.8, step(0.7, sw) * step(0.15, r));
	col = mix(col, rim.rgb, step(er - 0.045, r));
	ALBEDO = col;
	ALPHA = 0.96;
}
"""

## Emilen saldırının üstüne binen kaplama: amt arttıkça saldırı mürekkebe döner (kenar leylak)
const SH_OVERLAY := """
uniform vec4 ink : source_color = vec4(0.022, 0.008, 0.045, 1.0);
uniform vec4 rim : source_color = vec4(0.86, 0.75, 1.0, 1.0);
uniform float amt = 0.0;
void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = mix(ink.rgb, rim.rgb, step(0.7, fr));
	ALPHA = amt;
}
"""

## Tüylü karanlık hâlesi (kameraya dönük): dikenli / tüylü mürekkep kenarı, içte çivit-mor ışınsal çizgiler. flow<0 çizgiler
## merkeze akar (emme girdabı), flow>0 dışa (salım). hollow=1: ortası boş (bir nesnenin çevresinde taç).
const SH_FUR := """
uniform vec4 ink : source_color = vec4(0.022, 0.008, 0.045, 1.0);
uniform vec4 glow : source_color = vec4(0.17, 0.07, 0.42, 1.0);
uniform vec4 rim : source_color = vec4(0.62, 0.55, 1.0, 1.0);
uniform float power = 1.0;
uniform float flow = -1.0;
uniform float inner = 0.55;
uniform float spike = 0.4;
uniform float hollow = 0.0;
uniform float cells = 64.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dirv = p / max(r, 0.0001);
	float a = atan(p.y, p.x);
	float cell = floor((a + 3.14159265) / 6.2831853 * cells);
	float sp = pow(n2(dirv * 7.0 + vec2(TIME * 0.6, -TIME * 0.4)), 2.0) * 0.6 + pow(h2(vec2(cell, 0.0)), 3.0) * 0.4;
	float er = min(1.0, inner + spike * sp * power);
	if (r > er) { discard; }
	float tt = clamp((r - inner) / max(er - inner, 0.001), 0.0, 1.0);
	float streak = step(0.55, h2(vec2(cell, 1.0))) * step(0.45, fract(r * 3.0 - TIME * flow + h2(vec2(cell, 2.0))));
	float outside = step(inner, r);
	vec3 col = ink.rgb;
	col = mix(col, glow.rgb, streak * outside * (1.0 - tt * 0.5));
	col = mix(col, rim.rgb, streak * outside * step(0.8, tt));
	col = mix(col, glow.rgb * 0.7, (1.0 - outside) * step(0.62, n2(p * 4.0 + vec2(TIME, -TIME * 0.7))) * 0.6);
	ALBEDO = col;
	ALPHA = power * mix(1.0 - hollow, 1.0, outside);
}
"""

const RENDER := {
	"fur": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"ink": "render_mode unshaded, cull_back, shadows_disabled;",
	"ink2": "render_mode unshaded, cull_disabled, shadows_disabled;",
	"strip": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"glyph": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"lens": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"fog": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"wisp": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"pool": "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;",
	"overlay": "render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;",
}


static func _shader(key: String) -> Shader:
	if _shaders.has(key):
		return _shaders[key]
	var body := ""
	match key:
		"ink", "ink2":
			body = SH_INK
		"strip":
			body = SH_STRIP
		"glyph":
			body = SH_GLYPH
		"lens":
			body = SH_LENS
		"fog":
			body = SH_FOG
		"wisp":
			body = SH_WISP
		"pool":
			body = SH_POOL
		"overlay":
			body = SH_OVERLAY
		"fur":
			body = SH_FUR
	var s = Shader.new()
	s.code = "shader_type spatial;\n" + String(RENDER[key]) + "\n" + SH_NOISE + "\n" + body
	_shaders[key] = s
	return s


static func _mat(key: String, params := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader(key)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Değişmeyen ortak malzeme (adına göre bir kez kurulur)
static func _shared(name: String, key: String, params := {}) -> ShaderMaterial:
	if not _cache.has("m_" + name):
		_cache["m_" + name] = _mat(key, params)
	return _cache["m_" + name]


# ═════════════════════════════════════════ altyapı ═════════════════════════════════════════

## Her karede fn(node, dt, age) çağıran düğüm; fn false dönünce silinir
class Ticker extends Node3D:
	var fn := Callable()
	var age := 0.0

	func _process(dt: float) -> void:
		age += dt
		if not fn.is_valid() or not fn.call(self, dt, age):
			queue_free()


static func _scene(pj: PathJutsu) -> Node:
	return pj.get_tree().current_scene


static func _tick(pj: PathJutsu, pos: Vector3, fn: Callable, parent: Node = null) -> Ticker:
	var n = Ticker.new()
	n.fn = fn
	if parent != null and is_instance_valid(parent):
		parent.add_child(n)
		n.position = pos
	else:
		_scene(pj).add_child(n)
		n.global_position = pos
	return n


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _sphere() -> SphereMesh:
	if not _cache.has("sphere"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 18
		s.rings = 10
		_cache["sphere"] = s
	return _cache["sphere"]


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


static func _tube_open() -> CylinderMesh:
	if not _cache.has("tube"):
		var c = CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.cap_top = false
		c.cap_bottom = false
		c.radial_segments = 18
		c.rings = 3
		_cache["tube"] = c
	return _cache["tube"]


static func _cam(n: Node3D) -> Vector3:
	var vp = n.get_viewport()
	var cam = vp.get_camera_3d() if vp else null
	return cam.global_position if cam else n.global_position + Vector3(0, 50, 0)


static func _height(n: Node3D) -> float:
	return float(n.get("height")) if n.get("height") != null else 1.8


static func _radius(n: Node3D) -> float:
	return float(n.get("radius")) if n.get("radius") != null else 0.38


## Atanın sol avucu (görünen poz, kemik eki); atan yok olursa son konum
static func _palm_fn(pj: PathJutsu, c: Node3D, push := 0.1) -> Callable:
	var cw = weakref(c)
	var mem = {"p": pj.hand_pos(c, false)}
	return func() -> Vector3:
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc) and cc.is_inside_tree():
			mem["p"] = pj.live_hand(cc, false) + cc.face_dir() * push
		return mem["p"]


## Bir düğümün konumu + kayma; düğüm yok olursa son konum
static func _follow_fn(n: Node3D, off: Vector3) -> Callable:
	var w = weakref(n)
	var mem = {"p": n.global_position + off}
	return func() -> Vector3:
		var x = w.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			mem["p"] = x.global_position + off
		return mem["p"]


## Hedefin göğsü; hedef öldü / silindiyse null (bağ kopar)
static func _chest_fn(n: Node3D, k := 0.6) -> Callable:
	var w = weakref(n)
	return func():
		var x = w.get_ref()
		if x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return null
		if x.has_method("is_dead") and x.is_dead():
			return null
		return x.global_position + Vector3.UP * _height(x) * k


static func _flare(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.set_meta("boost", 2.2)


# ───────────────────────── şerit düzeneği ─────────────────────────

## Kameraya dönük şerit: pts boyunca ws yarı genişlik, al saydamlık (UV.x 0 → 1 baştan sona)
static func _strip(im: ImmediateMesh, mat: Material, pts: Array, ws: Array, al: Array, cam: Vector3) -> void:
	var n = pts.size()
	if n < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var sd: Vector3 = tn.cross(cam - p)
		if sd.length_squared() < 0.000001:
			sd = tn.cross(Vector3.UP)
		if sd.length_squared() < 0.000001:
			sd = Vector3.RIGHT
		sd = sd.normalized() * float(ws[i])
		var u = float(i) / float(n - 1)
		var col = Color(1, 1, 1, float(al[i]))
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(u, 0.0))
		im.surface_add_vertex(p + sd)
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(u, 1.0))
		im.surface_add_vertex(p - sd)
	im.surface_end()


## Dünya koordinatında her kare yeniden çizilen şerit taşıyıcısı: fn(im, node, dt, age) -> bool
static func _strip_host(pj: PathJutsu, fn: Callable) -> Ticker:
	var im = ImmediateMesh.new()
	var mi = _mi(im, null)
	mi.extra_cull_margin = 16.0
	var n = _tick(pj, Vector3.ZERO, func(node, dt, age) -> bool:
		im.clear_surfaces()
		return fn.call(im, node, dt, age))
	n.add_child(mi)
	return n


## Akan mürekkep ipliği: path(u) yolunda baş dur sn'de sona varır, arkasından tail uzunluğunda gövde gelir; iki ucu incelir
static func filament(pj: PathJutsu, path: Callable, dur: float, width: float, mat: Material, tail := 0.5, segs := 14) -> void:
	_strip_host(pj, func(im, node, _dt, age) -> bool:
		var s = age / dur
		if s > 1.0 + tail:
			return false
		var head = minf(s, 1.0)
		var tl = clampf(s - tail, 0.0, 1.0)
		if head - tl < 0.002:
			return true
		var pts = []
		var ws = []
		var al = []
		for k in segs + 1:
			var f = float(k) / segs
			pts.append(path.call(lerpf(tl, head, f)))
			ws.append(width * sin(PI * pow(f, 0.45)) + width * 0.04)   # damla biçimi: kuyruk ucunda dolgun, başa doğru sivri incelir
			al.append(1.0)
		_strip(im, mat, pts, ws, al, _cam(node))
		return true)


## Uca (end_fn, hareketli olabilir) doğru daralarak dönen sarmal yol: çekilen iplik
static func _spiral_path(start: Vector3, end_fn: Callable, turns: float, a0: float, rad := 0.3) -> Callable:
	return func(u: float) -> Vector3:
		var end: Vector3 = end_fn.call()
		var ax: Vector3 = end - start
		var L = ax.length()
		if L < 0.001:
			return end
		var dn: Vector3 = ax / L
		var s1: Vector3 = dn.cross(Vector3.UP)
		if s1.length_squared() < 0.0001:
			s1 = dn.cross(Vector3.RIGHT)
		s1 = s1.normalized()
		var s2: Vector3 = dn.cross(s1)
		var e = u * u * (3.0 - 2.0 * u)
		var r = L * rad * (1.0 - e)
		var a = a0 + u * turns * TAU
		return start.lerp(end, e) + (s1 * cos(a) + s2 * sin(a)) * r


## Hareketli bir düğümün arkasında incelen mürekkep izi (düğüm gidince kuyruk toplanır)
static func trail(pj: PathJutsu, target: Node3D, width: float, mat: Material, max_pts := 16, follow_for := 60.0, offset := Vector3.ZERO) -> void:
	var w = weakref(target)
	var hist = []
	_strip_host(pj, func(im, node, _dt, age) -> bool:
		var t = w.get_ref()
		if t != null and is_instance_valid(t) and t.is_inside_tree() and age < follow_for:
			var p: Vector3 = t.global_position + offset
			if hist.is_empty() or Vector3(hist[hist.size() - 1]).distance_to(p) > 0.05:
				hist.append(p)
			while hist.size() > max_pts:
				hist.pop_front()
		else:
			hist.pop_front()
			if not hist.is_empty():
				hist.pop_front()
			if hist.size() < 2:
				return false
		var n = hist.size()
		if n < 2:
			return true
		var ws = []
		var al = []
		for i in n:
			var f = float(i) / float(n - 1)
			ws.append(width * f)
			al.append(f)
		_strip(im, mat, hist, ws, al, _cam(node))
		return true)


## İki uç arasında dalgalanan mürekkep bağı; boncuklar hedef ucundan (b) avuca (a) akar. b_fn null dönerse bağ geri çekilir.
## fork > 0: hedef ucunda göğse kök salan kısa kollar.
static func cord(pj: PathJutsu, a_fn: Callable, b_fn: Callable, dur: float, width: float, amp: float, bead_dt: float, fork := 0, bead_size := 0.07) -> void:
	var mat = _mat("strip", {"flow": 1.6, "pulses": 7.0, "ragged": 0.6})
	var bm = _shared("bead", "ink", {"core": VIOLET, "glow": LILAC, "rim": Color(1, 1, 1), "glow_amt": 1.0, "rim_w": 0.3})
	var beads = []
	var stt = {"next": 0.0, "seed": randf() * 10.0}
	_strip_host(pj, func(im, node, dt, age) -> bool:
		var a: Vector3 = a_fn.call()
		var bv = b_fn.call()
		if bv is Vector3:
			stt["b"] = bv
		elif not stt.has("dead_at"):
			stt["dead_at"] = age
		if age > dur and not stt.has("dead_at"):
			stt["dead_at"] = age
		if not stt.has("b"):
			return false
		var out = 1.0
		if stt.has("dead_at"):
			out = 1.0 - (age - float(stt["dead_at"])) / 0.22
			if out <= 0.0:
				return false
		var b: Vector3 = stt["b"]
		var reach = clampf(age / 0.16, 0.0, 1.0) * out
		var t = age + float(stt["seed"])
		var cam = _cam(node)
		var N = 20
		var pts = []
		var ws = []
		var al = []
		for i in N + 1:
			var u = float(i) / N * reach
			pts.append(_cord_pt(a, b, u, t, amp))
			ws.append(width * (0.55 + 0.45 * sin(PI * u)))
			al.append(1.0)
		_strip(im, mat, pts, ws, al, cam)
		if fork > 0 and reach >= 0.99:
			var dn: Vector3 = (b - a).normalized()
			var s1: Vector3 = dn.cross(Vector3.UP)
			s1 = s1.normalized() if s1.length_squared() > 0.0001 else Vector3.RIGHT
			var s2: Vector3 = dn.cross(s1)
			var p0 = _cord_pt(a, b, 0.92, t, amp)
			for f in fork:
				var fa = float(f) / fork * TAU + t * 0.8
				var tip: Vector3 = b + (s1 * cos(fa) + s2 * sin(fa)) * 0.3 + dn * 0.12
				_strip(im, mat, [p0, b.lerp(tip, 0.5) + dn * 0.04, tip], [width * 0.6, width * 0.45, width * 0.1], [1.0, 1.0, 1.0], cam)
		if reach >= 0.99 and out >= 1.0 and age >= float(stt["next"]):
			stt["next"] = age + bead_dt
			var mi = _mi(_sphere(), bm)
			node.add_child(mi)
			mi.scale = Vector3.ONE * 0.01
			beads.append({"mi": mi, "u": 1.0})
		for bd in beads.duplicate():
			var u2 = float(bd["u"]) - dt * 2.2
			bd["u"] = u2
			var mi2: MeshInstance3D = bd["mi"]
			if u2 <= 0.0 or not is_instance_valid(mi2):
				if is_instance_valid(mi2):
					mi2.queue_free()
				beads.erase(bd)
				continue
			mi2.position = _cord_pt(a, b, u2 * reach, t, amp)
			mi2.scale = Vector3.ONE * bead_size * (0.7 + 0.5 * sin(u2 * PI))
		return true)


static func _cord_pt(a: Vector3, b: Vector3, u: float, t: float, amp: float) -> Vector3:
	var ax: Vector3 = b - a
	var side: Vector3 = ax.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	var env = sin(PI * u)
	return a.lerp(b, u) + Vector3.DOWN * env * ax.length() * 0.06 + side * sin(u * 7.0 + t * 6.0) * amp * env + Vector3.UP * cos(u * 5.0 + t * 4.3) * amp * 0.6 * env


# ───────────────────────── mühür / mercek ─────────────────────────

## Avuç mührü: sol avucun önünde, bakış yönüne dönük; açılır, nabız gibi atar, sonda söner. "boost" metası parlamayı büyütür.
static func palm_glyph(pj: PathJutsu, c: Node3D, dur: float, size := 0.36, spin := 2.5, outer := 0.0, push := 0.1) -> Ticker:
	var m = _mat("glyph", {"spin": spin, "outer": outer, "power": 0.0, "reveal": 0.0, "ticks": 12.0 if outer < 0.5 else 24.0})
	var cw = weakref(c)
	var n = _tick(pj, pj.hand_pos(c, false), func(node, dt, age) -> bool:
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc) or not cc.is_inside_tree() or age > dur:
			return false
		var fd: Vector3 = cc.face_dir()
		if fd.length_squared() < 0.0001:
			fd = Vector3.FORWARD
		node.global_position = pj.live_hand(cc, false) + fd * push
		node.global_basis = Basis.looking_at(fd, Vector3.UP)
		var b = float(node.get_meta("boost", 1.0))
		b = lerpf(b, 1.0, minf(1.0, dt * 5.0))
		node.set_meta("boost", b)
		var k = minf(1.0, age / 0.18) * clampf((dur - age) / 0.25, 0.0, 1.0)
		m.set_shader_parameter("power", k * minf(b, 1.6))
		m.set_shader_parameter("reveal", minf(1.0, age / 0.25))
		node.scale = Vector3.ONE * size * (1.0 + 0.05 * sin(age * 9.0)) * (1.0 + (b - 1.0) * 0.35)
		return true)
	n.add_child(_mi(_quad(), m))
	return n


## Hedefin göğsüne basılan mühür (atana dönük)
static func chest_glyph(pj: PathJutsu, x: Node3D, face_fn: Callable, dur: float, size := 0.55) -> void:
	var m = _mat("glyph", {"spin": 5.0, "power": 0.0, "reveal": 0.0, "back": 0.3, "ticks": 8.0})
	var chest = _chest_fn(x, 0.6)
	var n = _tick(pj, x.global_position, func(node, _dt, age) -> bool:
		var p = chest.call()
		if p == null or age > dur:
			return false
		var f: Vector3 = face_fn.call()
		var d: Vector3 = f - p
		d.y = 0.0
		if d.length_squared() < 0.0001:
			d = Vector3.FORWARD
		var r = _radius(x)
		node.global_position = p + d.normalized() * (r + 0.04)
		node.global_basis = Basis.looking_at(d.normalized(), Vector3.UP)
		node.scale = Vector3.ONE * size * (1.0 + 0.08 * sin(age * 11.0))
		m.set_shader_parameter("power", minf(1.0, age / 0.12) * clampf((dur - age) / 0.25, 0.0, 1.0))
		m.set_shader_parameter("reveal", minf(1.0, age / 0.2))
		return true)
	n.add_child(_mi(_quad(), m))


## Işık büken mercek (kameraya dönük): pos_fn konumu izler; parent verilirse onun çocuğu olur ve ölçeğini alır
static func lens(pj: PathJutsu, pos_fn: Callable, dur: float, size: float, strength: float, swirl: float, dark: float, parent: Node3D = null) -> Ticker:
	var m = _mat("lens", {"strength": strength, "swirl": swirl, "dark": dark, "power": 0.0})
	var start: Vector3 = Vector3.ZERO if parent != null else pos_fn.call()
	var n = _tick(pj, start, func(node, _dt, age) -> bool:
		if age > dur:
			return false
		if parent == null:
			node.global_position = pos_fn.call()
		m.set_shader_parameter("power", minf(1.0, age / 0.25) * clampf((dur - age) / 0.3, 0.0, 1.0))
		return true, parent)
	var mi = _mi(_quad(), m)
	mi.extra_cull_margin = size * 2.0
	n.add_child(mi)
	n.scale = Vector3.ONE * size
	return n


# ───────────────────────── emme / salım parçaları ─────────────────────────

## Emilen saldırı: atışın görünen parçaları kopyalanır, mürekkebe dönerek sarmal çizip küçülür ve to_fn noktasında erir
static func swallow(pj: PathJutsu, p: Node3D, to_fn: Callable, dur := 0.38) -> void:
	var from_xf: Transform3D = p.global_transform
	var ov = _mat("overlay", {"amt": 0.0})
	var holder = Ticker.new()
	var ghosts = 0
	var stack = [p]
	while not stack.is_empty() and ghosts < 6:
		var nd = stack.pop_back()
		for ch in nd.get_children():
			if ch is Node3D:
				stack.append(ch)
			if ch is MeshInstance3D and ch.mesh != null and ch.visible and ghosts < 6:
				var g = MeshInstance3D.new()
				g.mesh = ch.mesh
				g.material_override = ch.material_override
				g.material_overlay = ov
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				g.transform = from_xf.affine_inverse() * ch.global_transform
				holder.add_child(g)
				ghosts += 1
	if ghosts == 0:   # görünen gövdesi olmayan atış: mürekkep damlası olarak emilir
		var bl = _mi(_sphere(), _shared("drop", "ink", {"glow_amt": 0.35, "rim_w": 0.22}))
		bl.scale = Vector3.ONE * 0.45
		holder.add_child(bl)
	var a0 = randf() * TAU
	var bas: Basis = from_xf.basis.orthonormalized()
	holder.fn = func(node, _dt, age) -> bool:
		var u = clampf(age / dur, 0.0, 1.0)
		if u >= 1.0:
			return false
		var end: Vector3 = to_fn.call()
		var e = u * u
		var a = a0 + u * 7.0
		var off = Vector3(cos(a), sin(a) * 0.6, sin(a)) * 0.45 * (1.0 - u)
		var s = maxf(0.02, pow(1.0 - u, 1.6))
		node.global_transform = Transform3D(Basis(Vector3.UP, age * 9.0) * bas * Basis.from_scale(Vector3.ONE * s), from_xf.origin.lerp(end, e) + off)
		ov.set_shader_parameter("amt", minf(1.0, u * 2.5))
		return true
	_scene(pj).add_child(holder)
	holder.global_transform = from_xf


## Mürekkep damlaları: hıza göre uzayan, yerçekimiyle düşen, küçülerek kaybolan küreler
static func splash(pj: PathJutsu, at: Vector3, n: int, speed: float, size: float, bias := Vector3.UP * 0.5, life := 0.8, grav := 14.0) -> void:
	var host = Ticker.new()
	var drops = []
	var m = _shared("drop", "ink", {"glow_amt": 0.35, "rim_w": 0.22})
	for i in n:
		var v: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized() + bias
		v = v.normalized() * speed * randf_range(0.5, 1.0)
		var mi = _mi(_sphere(), m)
		mi.scale = Vector3.ONE * 0.01
		host.add_child(mi)
		drops.append({"mi": mi, "v": v, "s": size * randf_range(0.6, 1.3)})
	host.fn = func(_node, dt, age) -> bool:
		if age > life:
			return false
		var k = 1.0 - age / life
		for d in drops:
			var v: Vector3 = d["v"]
			v.y -= grav * dt
			d["v"] = v
			var mi: MeshInstance3D = d["mi"]
			mi.position += v * dt
			var s = float(d["s"]) * k
			if v.length_squared() > 0.0001:
				var up = Vector3.UP if absf(v.normalized().y) < 0.98 else Vector3.RIGHT
				mi.basis = Basis.looking_at(v, up) * Basis.from_scale(Vector3(s, s, s * (1.0 + v.length() * 0.06)))
		return true
	_scene(pj).add_child(host)
	host.global_position = at


## Kabaran kara-mor kütle: r0 → r1 yarıçapa büyür, yüzeyi kaynar, sonra gürültüyle aşınıp erir
static func _mass(pj: PathJutsu, at: Vector3, r0: float, r1: float, dur: float, invert := 0.0) -> void:
	var m = _mat("ink", {"wobble": 0.18, "wob_freq": 2.2, "glow_amt": 0.7 * (1.0 - invert), "invert": invert, "rim_w": 0.16, "spikes": 0.05, "spike_freq": 6.0})
	var mi = _mi(_sphere_hi(), m)
	mi.scale = Vector3.ONE * r0 * 2.0
	var host = Ticker.new()
	host.add_child(mi)
	fur(pj, mi, 1.55, dur * 0.75, 1.2 if invert < 0.5 else -1.5, 0.6, 0.4)   # tüylü dikenli kenar, çizgiler dışa (salım) / içe (boşluk)
	host.fn = func(_node, _dt, age) -> bool:
		var u = age / dur
		if u >= 1.0:
			return false
		var e = 1.0 - (1.0 - u) * (1.0 - u)
		mi.scale = Vector3.ONE * lerpf(r0, r1, e) * 2.0
		m.set_shader_parameter("dissolve", clampf((u - 0.35) / 0.65, 0.0, 1.0))
		return true
	_scene(pj).add_child(host)
	host.global_position = at


## Kara-mor salım dalgası: yerde dışa yuvarlanan kalın mürekkep kabarması (sırtı leylak), açıldıkça aşınır
static func _wave_mesh() -> ArrayMesh:
	if _cache.has("wave"):
		return _cache["wave"]
	var prof = [Vector2(0.6, -0.05), Vector2(0.72, 0.2), Vector2(0.84, 0.5), Vector2(0.93, 0.64), Vector2(0.99, 0.48), Vector2(1.03, 0.18), Vector2(1.04, -0.05)]
	var seg = 56
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg + 1:
		var a = TAU * i / seg
		var hm = 0.75 + 0.22 * sin(a * 7.0) + 0.12 * sin(a * 3.0 + 1.0)
		for pr in prof:
			var v: Vector2 = pr
			st.add_vertex(Vector3(cos(a) * v.x, maxf(v.y * hm, -0.05), sin(a) * v.x))
	var np = prof.size()
	for i in seg:
		for k in np - 1:
			var a0 = i * np + k
			var b0 = (i + 1) * np + k
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	st.generate_normals()
	var mesh = st.commit()
	_cache["wave"] = mesh
	return mesh


static func ink_wave(pj: PathJutsu, at: Vector3, R: float, kp: float) -> void:
	var m = _mat("ink2", {"wobble": 0.12, "wob_freq": 3.0, "glow_amt": 0.55, "rim_w": 0.2})
	var mi = _mi(_wave_mesh(), m)
	var H = 0.55 + kp * 0.22
	mi.scale = Vector3(0.5, H, 0.5)
	var host = Ticker.new()
	host.add_child(mi)
	host.fn = func(_node, _dt, age) -> bool:
		var u = age / 0.6
		if u >= 1.0:
			return false
		var e = 1.0 - pow(1.0 - u, 3.0)
		var r = lerpf(0.5, R, e)
		mi.scale = Vector3(r, H * (1.0 - 0.6 * u), r)
		mi.rotation.y = age * 0.8
		m.set_shader_parameter("dissolve", clampf((u - 0.45) / 0.55, 0.0, 1.0))
		return true
	_scene(pj).add_child(host)
	host.global_position = at


## Yere çöken mürekkep sisi: üç katman (alt yoğun, üst yırtık), açılır, dur sn kalır, söner
static func mist(pj: PathJutsu, at: Vector3, R: float, dur: float) -> void:
	var host = Ticker.new()
	var mats = []
	for L in 3:
		var m = _mat("fog", {"layer": L / 2.0, "density": 0.0})
		var mi = _mi(_plane(), m)
		mi.position = Vector3(0, 0.12 + L * 0.32, 0)
		mi.scale = Vector3.ONE * R * (1.08 - L * 0.12)
		mi.extra_cull_margin = 2.0
		host.add_child(mi)
		mats.append(m)
	host.fn = func(_node, _dt, age) -> bool:
		if age > dur + 0.9:
			return false
		var k = clampf(age / 0.7, 0.0, 1.0) * clampf((dur + 0.9 - age) / 0.9, 0.0, 1.0)
		for q in mats.size():
			mats[q].set_shader_parameter("density", k * (1.0 - q * 0.22))
		return true
	_scene(pj).add_child(host)
	host.global_position = at


## Sis içindekinin bacaklarına sarılan sarmal; tekrar çağrıldıkça süresi uzar, sonra söner
static func leg_wisp(e: Node3D, hold: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if e.has_meta("dark_wisp"):
		var old = e.get_meta("dark_wisp")
		if is_instance_valid(old):
			old.set_meta("until", now + hold)
			return
	var h = _height(e)
	var r = _radius(e)
	var m = _mat("wisp", {"power": 0.0})
	var host = Ticker.new()
	host.set_meta("until", now + hold)
	var mi = _mi(_tube_open(), m)
	var wh = h * 0.5
	mi.scale = Vector3(r * 1.3, wh, r * 1.3)
	mi.position = Vector3(0, wh * 0.5, 0)
	host.add_child(mi)
	var stt = {"p": 0.0}
	host.fn = func(node, dt, age) -> bool:
		var left = float(node.get_meta("until")) - Time.get_ticks_msec() / 1000.0
		var want = 1.0 if left > 0.0 else 0.0
		stt["p"] = move_toward(float(stt["p"]), want, dt * 2.5)
		m.set_shader_parameter("power", stt["p"])
		node.rotation.y = age * 0.6
		return want > 0.0 or float(stt["p"]) > 0.0
	e.add_child(host)
	e.set_meta("dark_wisp", host)


## Kara gölcük: açılır, dur sn durur, kapanır
static func pool(pj: PathJutsu, at: Vector3, radius: float, dur: float) -> void:
	var m = _mat("pool", {"open": 0.0})
	var mi = _mi(_plane(), m)
	mi.scale = Vector3.ONE * radius
	mi.position = Vector3.UP * 0.04
	var host = Ticker.new()
	host.add_child(mi)
	host.fn = func(_node, _dt, age) -> bool:
		if age > dur:
			return false
		m.set_shader_parameter("open", minf(1.0, age / 0.25) * clampf((dur - age) / 0.3, 0.0, 1.0))
		return true
	_scene(pj).add_child(host)
	host.global_position = at


## Uca doğru incelen tüp (SurfaceTool'a eklenir); bi[0] köşe sayacı
static func _tube(st: SurfaceTool, pts0: Array, radii0: Array, sides: int, bi: Array, sub := 1, wt := 1.0) -> void:
	# sub: her aralığı böler (dikenli siluet için sık halka); wt: köşe rengi kırmızısı = diken payı
	var pts = []
	var radii = []
	for i in pts0.size() - 1:
		for s in sub:
			var f = float(s) / sub
			pts.append(Vector3(pts0[i]).lerp(pts0[i + 1], f))
			radii.append(lerpf(float(radii0[i]), float(radii0[i + 1]), f))
	pts.append(pts0[pts0.size() - 1])
	radii.append(radii0[radii0.size() - 1])
	var n = pts.size()
	var start = int(bi[0])
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var s1: Vector3 = tn.cross(Vector3.RIGHT if absf(tn.x) < 0.9 else Vector3.UP).normalized()
		var s2: Vector3 = tn.cross(s1)
		var w = wt * clampf(float(n - 1 - i) / 2.0, 0.0, 1.0)   # uçta diken söner
		for k in sides:
			var a = TAU * k / sides
			var nrm: Vector3 = s1 * cos(a) + s2 * sin(a)
			st.set_color(Color(w, 0, 0))
			st.set_normal(nrm)
			st.add_vertex(p + nrm * float(radii[i]))
	for i in n - 1:
		for k in sides:
			var a0 = start + i * sides + k
			var a1 = start + i * sides + (k + 1) % sides
			st.add_index(a0)
			st.add_index(a0 + sides)
			st.add_index(a1)
			st.add_index(a1)
			st.add_index(a0 + sides)
			st.add_index(a1 + sides)
	bi[0] = start + n * sides


## İnce mürekkep kolu: gölcükten S kıvrımıyla yükselen ön kol, dar bilek, uzun pençe parmaklar +Z'ye (içe) kıvrık
static func _arm_mesh(h: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi = [0]
	var wy = h * 0.82
	_tube(st, [Vector3(0, -0.15, -0.02), Vector3(0, h * 0.25, -0.06), Vector3(0.02, h * 0.5, -0.04), Vector3(0, h * 0.68, 0.0), Vector3(0, wy, 0.05)], [0.15, 0.13, 0.11, 0.09, 0.066], 12, bi, 6, 1.0)
	var pt = Vector3(0, wy + 0.13, 0.1)
	_tube(st, [Vector3(0, wy, 0.05), Vector3(0, wy + 0.07, 0.08), pt], [0.07, 0.085, 0.07], 10, bi, 2, 0.4)
	for f in 4:
		var x = (f - 1.5) * 0.045
		var sp = (f - 1.5) * 0.03
		var b0 = Vector3(x, pt.y - 0.01, pt.z)
		var L = 0.95 + 0.12 * (1.0 - absf(f - 1.5) / 1.5)
		_tube(st, [b0, b0 + Vector3(sp, 0.12, 0.03) * L, b0 + Vector3(sp * 1.6, 0.23, 0.11) * L, b0 + Vector3(sp * 1.9, 0.29, 0.22) * L, b0 + Vector3(sp * 2.0, 0.28, 0.32) * L], [0.026, 0.022, 0.018, 0.012, 0.003], 6, bi, 2, 0.0)
	var tb = Vector3(-0.07, wy + 0.06, 0.09)
	_tube(st, [tb, tb + Vector3(-0.08, 0.06, 0.06), tb + Vector3(-0.1, 0.12, 0.15), tb + Vector3(-0.08, 0.14, 0.22)], [0.026, 0.021, 0.014, 0.003], 6, bi, 2, 0.0)
	return st.commit()


static func _ink_arm(pj: PathJutsu, at: Vector3, face: Vector3, h: float) -> Node3D:
	var root = Node3D.new()
	# koyu mürekkep gövde, içte çivit ışıltı, gölcüğe yakın kısım koyulaşır, ön kolda tüylü diken (parmaklar düz, sivri)
	root.add_child(_mi(_arm_mesh(h), _mat("ink2", {"wobble": 0.01, "wob_freq": 6.0, "glow_amt": 0.75, "rim_w": 0.16, "spikes": 0.022, "spike_freq": 15.0, "dark_below": h * 0.55})))
	pj.scene_add(root, at)
	root.global_basis = Basis.looking_at(face, Vector3.UP)
	return root


## Yerden kopup boşluğa çekilen taş kırıntısı (toon taş)
static func _chip(pj: PathJutsu, from: Vector3, to: Vector3, dur: float) -> void:
	if not _cache.has("chip"):
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(1.0, 0.7, 0.85), Color(0.3, 0.26, 0.22))
		b.add("box", Vector3(0.2, 0.25, 0.1), Vector3(0.6, 0.5, 0.55), Color(0.24, 0.2, 0.17), Vector3(20, 30, 10))
		_cache["chip"] = b.build(Props.toon())
	var mi = _mi(_cache["chip"], null)
	var s0 = randf_range(0.12, 0.26)
	mi.scale = Vector3.ONE * s0
	var a0 = randf() * TAU
	var spinv = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	var host = Ticker.new()
	host.add_child(mi)
	host.fn = func(node, _dt, age) -> bool:
		var u = age / dur
		if u >= 1.0:
			return false
		var a = a0 + u * 5.0
		node.global_position = from.lerp(to, u * u) + Vector3.UP * sin(u * PI) * 0.8 + Vector3(cos(a), 0, sin(a)) * 0.6 * (1.0 - u)
		mi.rotation = spinv * age
		mi.scale = Vector3.ONE * s0 * (1.0 - u * u * u)
		return true
	_scene(pj).add_child(host)
	host.global_position = from


## Dikenli siluet için sık örgülü küre
static func _sphere_hi() -> SphereMesh:
	if not _cache.has("sphere_hi"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 40
		s.rings = 20
		_cache["sphere_hi"] = s
	return _cache["sphere_hi"]


## Tüylü karanlık hâlesi: parent'ın çocuğu (ölçeğini alır), dur sn sonra söner. flow<0 içe akan çizgiler.
static func fur(pj: PathJutsu, parent: Node3D, size: float, dur: float, flow := -1.0, inner := 0.55, spike := 0.4, hollow := 0.0) -> Ticker:
	var m = _mat("fur", {"flow": flow, "inner": inner, "spike": spike, "hollow": hollow, "power": 0.0})
	var n = _tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
		if age > dur:
			return false
		var k = minf(1.0, age / 0.2) * clampf((dur - age) / 0.3, 0.0, 1.0)
		m.set_shader_parameter("power", k)
		node.scale = Vector3.ONE * size * (1.0 + 0.04 * sin(age * 13.0))
		return true, parent)
	var mi = _mi(_quad(), m)
	mi.extra_cull_margin = size * 2.0
	n.add_child(mi)
	n.scale = Vector3.ONE * size
	return n


## İnce mürekkep zerreleri. to_fn verilirse sarmal çizerek ona çekilir (toplanma), yoksa sallanarak yükselip buharlaşır (kalıntı)
static func motes(pj: PathJutsu, at: Vector3, radius: float, n: int, life: float, to_fn := Callable(), size := 0.05) -> void:
	var host = Ticker.new()
	var ms = []
	var m = _shared("mote", "ink", {"glow_amt": 0.9, "rim_w": 0.3})
	for i in n:
		var a = randf() * TAU
		var p0 = Vector3(cos(a) * radius * sqrt(randf()), randf_range(0.0, 0.6) if not to_fn.is_valid() else randf_range(-0.8, 1.6), sin(a) * radius * sqrt(randf()))
		var mi = _mi(_sphere(), m)
		mi.position = p0
		mi.scale = Vector3.ONE * 0.001
		host.add_child(mi)
		ms.append({"mi": mi, "p0": p0, "d": randf() * life * 0.5, "s": size * randf_range(0.5, 1.4), "ph": randf() * TAU})
	host.fn = func(node, _dt, age) -> bool:
		if age > life * 1.5:
			return false
		for d in ms:
			var mi: MeshInstance3D = d["mi"]
			var u = clampf((age - float(d["d"])) / life, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				mi.visible = false
				continue
			mi.visible = true
			var p0: Vector3 = d["p0"]
			var ph = float(d["ph"])
			if to_fn.is_valid():   # sarmal çizerek toplanır
				var end: Vector3 = Vector3(to_fn.call()) - node.global_position
				var e = u * u
				var sw = Vector3(cos(ph + u * 6.0), 0, sin(ph + u * 6.0)) * 0.4 * (1.0 - u)
				mi.position = p0.lerp(end, e) + sw
				mi.scale = Vector3.ONE * float(d["s"]) * (1.0 - e * 0.7)
			else:   # buharlaşarak yükselir
				mi.position = p0 + Vector3(sin(ph + u * 5.0) * 0.25, u * 2.2, cos(ph + u * 4.0) * 0.25)
				mi.scale = Vector3(1.0, 1.0 + u * 1.5, 1.0) * float(d["s"]) * (1.0 - u)
		return true
	_scene(pj).add_child(host)
	host.global_position = at


## Yere basılan mühür izi: yavaş dönen, uzun sürede sönen soluk mühür (kalıntı ışıltısı)
static func ground_glyph(pj: PathJutsu, at: Vector3, size: float, dur: float, peak := 0.8) -> void:
	var m = _mat("glyph", {"spin": 0.6, "outer": 1.0, "ticks": 24.0, "back": 0.45, "power": 0.0, "reveal": 0.0})
	var mi = _mi(_quad(), m)
	mi.rotation = Vector3(-PI * 0.5, 0, 0)
	mi.extra_cull_margin = size
	var host = Ticker.new()
	host.add_child(mi)
	host.fn = func(node, _dt, age) -> bool:
		if age > dur:
			return false
		m.set_shader_parameter("reveal", minf(1.0, age / 0.4))
		m.set_shader_parameter("power", peak * minf(1.0, age / 0.2) * pow(clampf(1.0 - age / dur, 0.0, 1.0), 1.5))
		node.scale = Vector3.ONE * size
		return true
	_scene(pj).add_child(host)
	host.global_position = at + Vector3.UP * 0.05


## Sonrası: yerde sönen mühür izi + yukarı buharlaşan mürekkep zerreleri + kıvrılarak yükselen birkaç ince duman dili
static func residue(pj: PathJutsu, at: Vector3, radius: float, dur := 2.6) -> void:
	var g: Vector3 = pj.gp(at)
	ground_glyph(pj, g, radius * 1.4, dur, 0.55)
	motes(pj, g, radius, 10 + int(radius * 6.0), 1.4)
	for q in 4 + int(radius * 2.0):
		var a = randf() * TAU
		var b: Vector3 = g + Vector3(cos(a), 0, sin(a)) * radius * randf_range(0.2, 0.9)
		var ph = randf() * TAU
		var hgt = randf_range(1.2, 2.4)
		filament(pj, func(u: float) -> Vector3:
			return b + Vector3(sin(ph + u * 4.0) * 0.3 * u, u * hgt, cos(ph + u * 3.0) * 0.3 * u), randf_range(0.9, 1.4), 0.05, _wisp_mat(), 0.6, 10)


## Alev dili kaplaması (Black Clover kara ateşi gibi): gövdenin her yerinden yukarı kıvrılan kısa kara diller, dur sn
static func wisp_coat(pj: PathJutsu, c: Node3D, dur: float, rate := 26.0) -> void:
	var cw = weakref(c)
	_tick(pj, c.global_position, func(_node, dt, age) -> bool:
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc) or not cc.is_inside_tree() or age > dur:
			return false
		var h = _height(cc)
		var r = _radius(cc) * 1.05
		var cnt = int(rate * dt + randf())
		for q in cnt:
			var a = randf() * TAU
			var y = randf_range(0.05, 0.95) * h
			var rd = Vector3(cos(a), 0, sin(a))
			var fol = _follow_fn(cc, rd * r + Vector3.UP * y)
			var ph = randf() * TAU
			var L = randf_range(0.35, 0.7)
			filament(pj, func(u: float) -> Vector3:
				var b: Vector3 = fol.call()
				return b + rd * u * 0.18 + Vector3(sin(ph + u * 6.0) * 0.08, u * L, cos(ph + u * 5.0) * 0.08), randf_range(0.22, 0.32), 0.05, _wisp_mat(), 0.7, 8)
		return true)


## Toplanma (hazırlık): çevreden avuca / noktaya kısa sürede sarmal çizip yakınsayan iplikler + zerreler
static func gather(pj: PathJutsu, to_fn: Callable, radius: float, n: int, dur: float) -> void:
	var at: Vector3 = to_fn.call()
	for q in n:
		var dir = Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized()
		filament(pj, _spiral_path(at + dir * radius * randf_range(0.7, 1.0), to_fn, randf_range(0.4, 0.9), randf() * TAU, 0.25), dur * randf_range(0.8, 1.0), 0.07, _thread_mat(), 0.7, 14)
	motes(pj, at, radius, n * 2, dur * 0.8, to_fn, 0.04)


static func _wisp_mat() -> ShaderMaterial:
	return _shared("wisp_str", "strip", {"ragged": 1.0, "glow": INDIGO, "rim": Color(0.62, 0.55, 1.0)})


static func _thread_mat() -> ShaderMaterial:
	return _shared("thread", "strip", {"ragged": 0.6})


static func _drain_mat() -> ShaderMaterial:
	return _shared("drain", "strip", {"flow": 2.2, "pulses": 4.0, "ragged": 0.8})


static func _trail_mat() -> ShaderMaterial:
	return _shared("trail", "strip", {"ragged": 1.0, "glow": INDIGO})


# ═════════════════════════════════════════ teknikler ═════════════════════════════════════════

## Kyūin: avuç mührü + önünde ışığı mühre büken mercek; önden gelen atışlar mürekkebe dönüp sarmal çizerek mühürde erir,
## ortamdan ince iplikler mühre çekilir, yakın rakipten kavisli emme akımı
static func kyuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 2.4)
	var id = "meiton_kyuin"
	pj._face(c, t)
	pj.anim(c, "push", 1.0)
	var gl = palm_glyph(pj, c, 2.5, 0.5, 2.6, 1.0)
	var cw = weakref(c)
	var palm = _palm_fn(pj, c, 0.1)
	gather(pj, palm, 1.4, 6, 0.3)   # hazırlık: mühür tutuşurken mürekkep avuca toplanır
	var lz = lens(pj, func() -> Vector3:
		var cc = cw.get_ref()
		var p: Vector3 = palm.call()
		if cc != null and is_instance_valid(cc):
			return p + cc.face_dir() * 0.45
		return p, 2.45, 2.2, 0.06, 3.0, 0.55)
	fur(pj, lz, 1.0, 2.4, -1.6, 0.68, 0.32, 1.0)   # merceğin çevresinde içe akan çizgili tüylü girdap tacı (ortası boş)
	pj.after(2.4, func():   # sonrası: avuçtan buharlaşan kalıntı
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc) and cc.is_inside_tree():
			motes(pj, palm.call(), 0.3, 10, 1.1)
			ground_glyph(pj, pj.gp(cc.global_position), 1.6, 2.0, 0.45))
	Sfx.play("absorb", c.global_position, 0.7)
	var pull = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var hp: Vector3 = pj.hand_pos(cc, false)
		var fd: Vector3 = cc.face_dir()
		if i % 2 == 0:   # önden mühre çekilen ince iplikler (ortamın chakrası)
			var sd: Vector3 = fd.cross(Vector3.UP).normalized()
			for q in 2:
				var s0: Vector3 = hp + fd * randf_range(2.2, 4.0) + sd * randf_range(-1.5, 1.5) + Vector3.UP * randf_range(-0.6, 1.2)
				filament(pj, _spiral_path(s0, palm, randf_range(0.6, 1.1), randf() * TAU, 0.25), 0.5, 0.07, _thread_mat(), 0.6, 16)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):   # önden gelen atışlar işarete emilir
			if not is_instance_valid(p) or p.get("shooter") == cc:
				continue
			var v: Vector3 = p.global_position - hp
			if v.length() < 9.0 and Vector3(v.x, 0, v.z).normalized().dot(fd) > 0.35:
				var dmg = float(p.get("info").get("dmg", 20.0)) if p.get("info") is Dictionary else 20.0
				cc.set_meta("meiton_store", float(cc.get_meta("meiton_store", 0.0)) + dmg)
				var pp: Vector3 = p.global_position
				swallow(pj, p, palm)
				filament(pj, _spiral_path(pp, palm, 1.2, randf() * TAU, 0.2), 0.3, 0.07, _thread_mat(), 0.7)
				_flare(gl)
				p.queue_free()
				Sfx.play("absorb", hp, 1.3)
		if i % 5 == 0:   # yakındaki rakibin chakrası çekilir
			for e in pj.enemies_near(cc, cc.global_position + fd * 2.5, 3.2):
				e.take_hit(pj.inf(cc, id, 0.15, {"knock": 0.0, "kind": "light", "chakra_drain": 8.0, "hitstop": 0.0, "pierce_guard": true}))
				cc.set_meta("meiton_store", float(cc.get_meta("meiton_store", 0.0)) + 8.0)
				if "chakra" in cc:
					cc.chakra = minf(cc.max_chakra, cc.chakra + 6.0)
				var ep: Vector3 = e.global_position + Vector3.UP * 1.1
				filament(pj, func(u: float) -> Vector3:
					var hv: Vector3 = palm.call()
					return ep.lerp(hv, u) + Vector3.UP * sin(u * PI) * 0.4, 0.3, 0.05, _drain_mat(), 0.8)
	pj.every(2.4, 0.05, pull)


## Hōshutsu: mühür ters döner ve parlar; avuçtan kaynayan kara-mor kütle fırlar (birikimle büyür), arkasında mürekkep izi
## ve damlayan mürekkep; çarpınca kütle kabarıp aşınır, damlalar ve fırlayan mürekkep dilleri saçılır
static func hoshutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "meiton_hoshutsu"
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.6)
	var gl = palm_glyph(pj, c, 0.8, 0.42, -6.0)
	_flare(gl)
	var store = float(c.get_meta("meiton_store", 0.0))
	c.set_meta("meiton_store", 0.0)
	var k_pow = clampf(0.6 + store / 120.0, 0.6, 3.5)
	var from: Vector3 = pj.hand_pos(c, false) + d * 0.4
	gather(pj, _palm_fn(pj, c, 0.15), 1.2 + k_pow * 0.3, 5 + int(k_pow * 2.0), 0.18)   # biriken chakra avuçta toplanır
	var core = Node3D.new()
	var sz = 0.6 + k_pow * 0.25
	var blob = _mi(_sphere_hi(), _mat("ink", {"wobble": 0.22, "wob_freq": 2.0, "glow_amt": 0.8, "rim_w": 0.12, "spikes": 0.06, "spike_freq": 5.0}))
	blob.scale = Vector3.ONE * sz
	core.add_child(blob)
	fur(pj, blob, 1.6, 1.8, 1.0, 0.6, 0.42)   # tüylü dikenli kara kenar, çivit çizgiler dışa
	Sfx.play("genjutsu", from, 0.6)
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 30.0, core, pj.inf(c, id, 1.4 * k_pow, {"knock": 10.0 + k_pow * 4.0, "launch": 2.0, "kind": "heavy", "element": "meiton", "hitstop": 0.08, "pierce_guard": k_pow > 2.0}), null, k_pow > 2.0, 1.6, func(p, _h):
		_ink_burst(pj, p, k_pow)
		Sfx.play("boom", p, 1.0))
	pr.radius = 0.5 + k_pow * 0.2
	trail(pj, core, 0.22 + k_pow * 0.1, _trail_mat(), 16)
	var cow = weakref(core)
	_tick(pj, from, func(_node, dt, _age) -> bool:   # kütleden damlayan mürekkep
		var co = cow.get_ref()
		if co == null or not is_instance_valid(co) or not co.is_inside_tree():
			return false
		if randf() < dt * 18.0:
			splash(pj, co.global_position, 1, 1.5, 0.08 * (0.6 + k_pow * 0.3), Vector3.DOWN * 0.6, 0.5)
		return true)
	if c == Game.player:
		Hud.msg("Salınan chakra: %d" % int(store), Color(0.7, 0.45, 0.95))


static func _ink_burst(pj: PathJutsu, p: Vector3, k: float) -> void:
	_mass(pj, p, 0.3 + k * 0.12, minf(1.2 + k * 0.4, 2.2), 0.45)
	pj.after(0.3, func(): residue(pj, p, 0.9 + k * 0.4, 2.4))
	splash(pj, p, 12 + int(k * 4.0), 6.0 + k * 2.0, 0.12 + k * 0.03, Vector3.UP * 0.4, 0.8)
	for q in 8:   # fırlayıp yere düşen mürekkep dilleri
		var a = q * TAU / 8.0 + randf() * 0.4
		var dir = Vector3(cos(a), 0, sin(a))
		var L = 2.0 + k + randf()
		var hgt = randf_range(0.6, 1.3)
		filament(pj, func(u: float) -> Vector3:
			return p + dir * u * L + Vector3.UP * (sin(u * PI) * hgt - u * u * 0.8), 0.3, 0.06, _thread_mat(), 0.55)


## Kyūin Shō: mürekkep izi bırakan süzülüş; avuç rakibin göğsüne basılır: göğüste dönen mühür, gövdeden mühre koşan kara
## damarlar, göğüsten avuca kalın dalgalanan bağ ve içinden akan boncuklar
static func kyuin_sho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 2.0)
	var id = "meiton_kyuin_sho"
	if tt == null:
		return
	palm_glyph(pj, c, 2.0, 0.38, 3.0)
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.anim(c, "dash", 1.6)
	trail(pj, c, 0.32, _trail_mat(), 14, 0.4, Vector3.UP * 1.0)
	wisp_coat(pj, c, 2.0, 30.0)   # kara alev dilleri bedeni sarar
	pj.every(0.32, 1.0 / 60.0, func(_i, _k):   # karanlık bir süzülüşle rakibin dibine
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x) or not cc is CharacterBody3D:
			return
		var v: Vector3 = x.global_position - cc.global_position
		v.y = 0
		cc.velocity = v.normalized() * clampf((v.length() - 1.3) / 0.05, 0.0, 28.0))
	pj.after(0.34, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		if cc.global_position.distance_to(x.global_position) > 3.0 + x.radius:
			return   # ıska: kavrayamadı
		pj.anim(cc, "push", 0.8)
		Sfx.play("absorb", x.global_position, 0.6)
		pj.st(x, "bind", 1.6)
		x.take_hit(pj.inf(cc, id, 0.3, {"knock": 0.0, "kind": "heavy", "element": "meiton", "hitstop": 0.08, "pierce_guard": true}))
		var palm = _palm_fn(pj, cc, 0.05)
		chest_glyph(pj, x, _follow_fn(cc, Vector3.UP), 1.6, 0.55)
		cord(pj, palm, _chest_fn(x, 0.6), 1.6, 0.09, 0.1, 0.1, 0, 0.09)
		var xw = _follow_fn(x, Vector3.ZERO)
		pj.after(1.6, func(): residue(pj, xw.call(), 0.8, 2.2))   # sonrası: hedefin üstünden buharlaşan kalıntı
		pj.every(1.6, 0.2, func(i, _k):
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2):
				return
			if c2 is CharacterBody3D:
				c2.velocity = Vector3.ZERO
			var hp0 = x2.hp
			x2.take_hit(pj.inf(c2, id, 0.18, {"knock": 0.0, "kind": "light", "element": "meiton", "chakra_drain": 7.0, "hitstop": 0.0, "pierce_guard": true}))
			var got = maxf(0.0, hp0 - x2.hp)
			if got > 0.0:
				pj.heal(c2, got * 0.6)
			pj._mei_store(c2, 9.0)
			if "chakra" in c2:
				c2.chakra = minf(c2.max_chakra, c2.chakra + 5.0)
			var ch: Vector3 = x2.global_position + Vector3.UP * 1.1   # gövdeden göğüs mührüne koşan kara damarlar
			var r = _radius(x2) * 1.15
			for q in 3:
				var a = randf() * TAU
				var rd = Vector3(cos(a), 0, sin(a))
				var sp: Vector3 = x2.global_position + rd * r + Vector3.UP * randf_range(0.1, 1.7)
				filament(pj, func(u: float) -> Vector3:
					return sp.lerp(ch, u) + rd * sin(u * PI) * 0.12, 0.22, 0.022, _thread_mat(), 0.7, 8)))


## Kokumu: avuçtan kavis çizen ince akımla yere dökülen mürekkep sisi; yerde üç katmanlı çöker, içindekilerin bacaklarına
## sarılır, emilen chakra sisin içine çekilir
static func kokumu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "meiton_kokumu"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "cast", 1.2)
	palm_glyph(pj, c, 1.0, 0.36, 2.0)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	var R = 5.0
	var DUR = 6.0
	Sfx.play("genjutsu", at, 0.5)
	var palm = _palm_fn(pj, c, 0.1)
	for q in 3:   # avuçtan sisin yerine dökülen akım
		var off = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		filament(pj, func(u: float) -> Vector3:
			var a: Vector3 = palm.call()
			return a.lerp(at + off, u) + Vector3.UP * sin(u * PI) * 2.0, 0.35 + q * 0.06, 0.08, _thread_mat(), 0.8)
	mist(pj, at, R, DUR)
	ground_glyph(pj, at, R * 1.6, DUR + 1.0, 0.35)   # sisin altında yavaş dönen büyük mühür
	pj.after(DUR, func(): residue(pj, at, R * 0.6, 2.4))
	pj.every(DUR, 0.3, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if i % 4 == 0:   # sisin içinde kıpırdayan mürekkep zerreleri
			motes(pj, at, R * 0.8, 6, 1.2)
		for e in pj.enemies_near(cc, at, R):
			pj.st(e, "sealed", 0.7)
			pj.st(e, "slow", 0.7)
			leg_wisp(e, 0.7)
			if i % 3 == 0:
				e.take_hit(pj.inf(cc, id, 0.18, {"knock": 0.0, "kind": "light", "element": "meiton", "chakra_drain": 6.0, "hitstop": 0.0}))
				pj._mei_store(cc, 5.0)
				var ep: Vector3 = e.global_position + Vector3.UP * 1.0   # chakra sisin dibine çekilir
				for q in 2:
					var gpnt: Vector3 = e.global_position + Vector3(randf_range(-0.8, 0.8), 0.1, randf_range(-0.8, 0.8))
					filament(pj, _spiral_path(ep, func() -> Vector3: return gpnt, 0.7, randf() * TAU, 0.25), 0.35, 0.03, _drain_mat(), 0.6, 10))


## Hansha Fūin: avucun önünde büyük, hızlı dönen çift halkalı mühür; kenarından içe kıvrılan iplikler. Gelen atış mürekkebe
## dönüp mühürde erir, mühür parlar ve üstünde mühür halkası taşıyan kara küre atanına döner; çarptığı yerde mühür basılır
static func hansha_fuin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 2.5)
	var id = "meiton_hansha_fuin"
	pj.anim(c, "push", 0.9)
	palm_glyph(pj, c, 2.6, 0.3, -3.0)
	var seal = palm_glyph(pj, c, 2.5, 1.5, 4.0, 1.0, 0.55)
	fur(pj, seal, 1.3, 2.5, -1.4, 0.78, 0.22, 1.0)   # mührün kenarında içe akan tüylü karanlık tacı
	var cw = weakref(c)
	var seal_fn = _palm_fn(pj, c, 0.55)
	gather(pj, seal_fn, 1.6, 7, 0.3)
	pj.after(2.5, func():
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc) and cc.is_inside_tree():
			motes(pj, seal_fn.call(), 0.6, 12, 1.2)
			ground_glyph(pj, pj.gp(cc.global_position), 1.8, 2.0, 0.45))
	Sfx.play("absorb", c.global_position, 0.5)
	pj.every(2.5, 0.04, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		var hp: Vector3 = pj.hand_pos(cc, false)
		var fd: Vector3 = cc.face_dir()
		if i % 6 == 0:   # mühür kenarından merkeze kıvrılan iplikler
			var cen: Vector3 = seal_fn.call()
			var sd: Vector3 = fd.cross(Vector3.UP).normalized()
			for q in 2:
				var a0 = randf() * TAU
				filament(pj, func(u: float) -> Vector3:
					var a = a0 + u * 2.5
					return cen + (sd * cos(a) + Vector3.UP * sin(a)) * 0.75 * (1.0 - u * u), 0.3, 0.03, _thread_mat(), 0.5, 12)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if not is_instance_valid(p) or p.get("shooter") == cc or p.has_meta("mei_ref"):
				continue
			var v: Vector3 = p.global_position - hp
			if v.length() < 4.0 and Vector3(v.x, 0, v.z).normalized().dot(fd) > 0.2:
				var sh = p.get("shooter")
				var dmg = float(p.get("info").get("dmg", 20.0)) if p.get("info") is Dictionary else 20.0
				swallow(pj, p, seal_fn, 0.22)
				p.queue_free()
				_flare(seal)
				Sfx.play("absorb", hp, 1.4)
				var orb = Node3D.new()
				var ob = _mi(_sphere(), _shared("hansha_orb", "ink", {"glow_amt": 0.2, "rim_w": 0.25}))
				ob.scale = Vector3.ONE * 0.7
				orb.add_child(ob)
				var og = _mi(_quad(), _shared("hansha_ring", "glyph", {"bb": 1.0, "spin": 9.0, "outer": 1.0, "ticks": 16.0, "back": 0.0}))
				og.scale = Vector3.ONE * 1.1
				orb.add_child(og)
				var aim: Vector3 = ((sh.global_position + Vector3.UP) - hp).normalized() if sh != null and is_instance_valid(sh) else fd
				var info = pj.inf(cc, id, 0.6, {"knock": 10.0, "launch": 2.0, "kind": "heavy", "element": "meiton", "hitstop": 0.08})
				info["dmg"] = maxf(float(info.get("dmg", 0.0)), dmg * 1.5)
				var pr = pj.shot(cc, hp + fd * 0.5, aim, 36.0, orb, info, sh if sh != null and is_instance_valid(sh) and sh is Node3D else null, false, 2.0, func(q, _h):
					_seal_stamp(pj, q)
					Sfx.play("boom", q, 1.2, 0.7))
				pr.set_meta("mei_ref", true)
				pr.radius = 0.5
				trail(pj, orb, 0.12, _trail_mat(), 10))


static func _seal_stamp(pj: PathJutsu, q: Vector3) -> void:
	var m = _mat("glyph", {"bb": 1.0, "spin": -8.0, "outer": 1.0, "ticks": 24.0, "back": 0.4, "power": 1.0, "reveal": 1.0})
	var mi = _mi(_quad(), m)
	mi.extra_cull_margin = 3.0
	var host = Ticker.new()
	host.add_child(mi)
	host.fn = func(node, _dt, age) -> bool:
		var u = age / 0.4
		if u >= 1.0:
			return false
		node.scale = Vector3.ONE * lerpf(0.5, 2.8, 1.0 - (1.0 - u) * (1.0 - u))
		m.set_shader_parameter("power", 1.0 - u)
		return true
	_scene(pj).add_child(host)
	host.global_position = q
	for k in 8:   # mühür kapanır: iplikler merkeze çakılır
		var dir = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		filament(pj, func(u: float) -> Vector3: return q + dir * 1.6 * (1.0 - u), 0.2, 0.04, _thread_mat(), 0.6, 8)
	splash(pj, q, 6, 4.0, 0.08, Vector3.UP * 0.3, 0.5)


## Yami no Te: rakibin altında kara gölcük açılır, içinden altı ince mürekkep kolu yükselip içe kapanır; emilen chakra
## kollardan gölcüğe akar; sonda kollar sıkıp gölcüğe batar
static func yami_no_te(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "meiton_yami_no_te"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.4)
	palm_glyph(pj, c, 1.0, 0.36, 2.0)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var bs = ClanJutsu.body_scale(tt) if tt else 1.0
	pool(pj, at, 1.9 * bs, 2.9)
	ground_glyph(pj, at, 4.2 * bs, 3.6, 0.6)   # gölcüğün çevresinde mühür; kollar battıktan sonra da söner
	motes(pj, at, 1.6 * bs, 18, 2.0)   # gölcükten kalkan zerreler
	pj.after(2.5, func(): residue(pj, at, 1.2 * bs, 2.4))
	var hands = []
	for k in 6:
		var a = k * TAU / 6.0 + 0.3
		var p: Vector3 = pj.gp(at + Vector3(cos(a), 0, sin(a)) * 1.1 * bs)
		var hnd = _ink_arm(pj, p, (at - p).normalized() * -1.0 + Vector3.UP * 0.01, 1.6 * bs * randf_range(0.85, 1.1))
		hnd.scale = Vector3(1, 0.05, 1)
		var ht = hnd.create_tween()
		ht.tween_interval(k * 0.05)
		ht.tween_property(hnd, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ht.tween_property(hnd, "rotation:x", hnd.rotation.x + 0.5, 0.2)   # içe kapanır
		hands.append(hnd)
	Sfx.play("genjutsu", at, 0.6)
	var caught = []
	pj.after(0.35, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 2.0 * bs):
			caught.append(weakref(e))
			pj.st(e, "bind", 2.2)
			e.take_hit(pj.inf(cc, id, 0.4, {"knock": 0.0, "kind": "heavy", "element": "meiton", "hitstop": 0.06})))
	pj.every(2.2, 0.25, func(_i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for hnd in hands:   # kollardan kopup kıvrılarak yükselen kara alev dilleri (ikincil hareket)
			if is_instance_valid(hnd) and hnd.is_inside_tree() and randf() < 0.75:
				var hb: Vector3 = hnd.global_transform * Vector3(0, randf_range(0.25, 1.2), 0)
				var ph = randf() * TAU
				filament(pj, func(u: float) -> Vector3:
					return hb + Vector3(sin(ph + u * 5.0) * 0.12, u * 0.7, cos(ph + u * 4.0) * 0.12), 0.35, 0.05, _wisp_mat(), 0.7, 8)
		for w in caught:
			var e = w.get_ref()
			if e != null and pj.live(e):
				e.take_hit(pj.inf(cc, id, 0.1, {"knock": 0.0, "kind": "light", "element": "meiton", "chakra_drain": 5.0, "hitstop": 0.0}))
				pj._mei_store(cc, 4.0)
				var ep: Vector3 = e.global_position + Vector3.UP * 0.8
				filament(pj, _spiral_path(ep, func() -> Vector3: return at + Vector3.UP * 0.05, 0.5, randf() * TAU, 0.3), 0.3, 0.035, _drain_mat(), 0.6, 10), func():
		var cc = cw.get_ref()
		for hnd in hands:
			if is_instance_valid(hnd):
				var t2 = hnd.create_tween()
				t2.tween_property(hnd, "rotation:x", hnd.rotation.x + 0.4, 0.1)
				t2.tween_property(hnd, "scale", Vector3(1, 0.02, 1), 0.3).set_ease(Tween.EASE_IN)
				t2.tween_callback(hnd.queue_free)
		if cc == null or not pj.live(cc):
			return
		for w in caught:
			var e = w.get_ref()
			if e != null and pj.live(e):
				e.take_hit(pj.inf(cc, id, 1.2, {"knock": 2.0, "launch": 2.0, "kind": "heavy", "element": "meiton", "hitstop": 0.1, "pierce_guard": true})))


## Kokuyōdan: avuçtan çıkan altı obsidyen boncuk (içte mor iris, leylak kenar) kuyruklu yörüngede döner, sonra birer birer
## süzülür; değen boncuk mürekkep damlasına dağılır, emdiği chakra ince bir iplikle sana döner
static func kokuyodan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "meiton_kokuyodan"
	var tt = pj.tg(c, t, 28.0)
	pj._face(c, tt)
	pj.anim(c, "cast", 1.3)
	palm_glyph(pj, c, 1.4, 0.36, 3.5)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var orbs = []
	var om = _shared("kokuyo_orb", "ink", {"glow_amt": 0.8, "rim_w": 0.18})
	for k in 6:
		var o = Node3D.new()
		var mi = _mi(_sphere(), om)
		mi.scale = Vector3.ONE * 0.42
		o.add_child(mi)
		pj.scene_add(o, c.global_position + Vector3.UP * 1.4)
		mi.scale = Vector3.ONE * 0.05
		var otw = mi.create_tween()
		otw.tween_interval(k * 0.04)
		otw.tween_property(mi, "scale", Vector3.ONE * 0.42, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fur(pj, mi, 1.5, 3.0, 0.8, 0.62, 0.36)   # boncuğun tüylü kara kenarı
		trail(pj, o, 0.09, _trail_mat(), 4)   # kısa kuyruk: yörüngede hızlı dönen boncuğun izi köşeli çizgi olmasın
		orbs.append(o)
	Sfx.play("genjutsu", c.global_position, 0.8)
	pj.every(0.6, 1.0 / 30.0, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		for q in orbs.size():
			var o = orbs[q]
			if is_instance_valid(o) and not o.has_meta("gone"):
				var a = q * TAU / 6.0 + i * 0.25
				o.global_position = cc.global_position + Vector3(cos(a) * 1.4, 1.3 + sin(a * 2.0) * 0.25, sin(a) * 1.4) * minf(1.0, k * 3.0 + 0.2))
	for q in 6:
		pj.after(0.6 + q * 0.09, func():
			var cc = cw.get_ref()
			var o: Node3D = orbs[q]
			if not is_instance_valid(o):
				return
			if cc == null or not pj.live(cc):
				o.queue_free()
				return
			o.set_meta("gone", true)
			var from: Vector3 = o.global_position
			var x = tw.get_ref() if tw else null
			o.get_parent().remove_child(o)
			o.position = Vector3.ZERO
			var dir: Vector3 = ((x.global_position + Vector3.UP) - from).normalized() if x != null and pj.live(x) else cc.face_dir()
			var pr = pj.shot(cc, from, dir, 22.0, o, pj.inf(cc, id, 0.32, {"knock": 2.0, "kind": "light", "element": "meiton", "chakra_drain": 6.0, "hitstop": 0.03}), x if x != null and pj.live(x) else null, false, 2.0, func(p, h):
				var c2 = cw.get_ref()
				splash(pj, p, 6, 3.5, 0.07, Vector3.UP * 0.3, 0.45)
				motes(pj, p, 0.4, 6, 1.0)
				if c2 != null and pj.live(c2) and h and is_instance_valid(h):
					pj._mei_store(c2, 6.0)
					if "chakra" in c2:
						c2.chakra = minf(c2.max_chakra, c2.chakra + 4.0)
					var back = _follow_fn(c2, Vector3.UP * 1.2)
					var pv: Vector3 = p
					filament(pj, func(u: float) -> Vector3:
						var e2: Vector3 = back.call()
						return pv.lerp(e2, u) + Vector3.UP * sin(u * PI) * 0.6, 0.35, 0.04, _drain_mat(), 0.5))
			pr.radius = 0.35)


## Meikū Hō: mühür ters döner; hedefte kara bir boşluk açılır (simsiyah küre, leylak bandı siluetin içinde, çevresinde ışığı
## içine büken mercek); sarmal iplikler ve yerden kopan taşlar içine çekilir; sonunda nokta olup çöker ve kara dikenlerle patlar
static func meiku_ho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "meiton_meiku_ho"
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.2)
	palm_glyph(pj, c, 1.0, 0.4, -4.0)
	var store = float(c.get_meta("meiton_store", 0.0))
	c.set_meta("meiton_store", 0.0)
	var kp = clampf(0.7 + store / 150.0, 0.7, 2.5)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 9.0) + Vector3.UP * 1.6
	var R = 5.0 + kp * 2.0
	var DUR = 1.6 + kp * 0.6
	var core = _mi(_sphere(), _mat("ink", {"core": Color(0, 0, 0), "invert": 1.0, "glow_amt": 0.0, "rim_w": 0.12, "wobble": 0.03, "wob_freq": 3.0}))
	pj.scene_add(core, at)
	core.scale = Vector3.ONE * 0.05
	lens(pj, Callable(), DUR + 1.0, 3.6, 0.09, 4.0, 0.75, core)
	fur(pj, core, 2.1, DUR + 1.0, -2.2, 0.48, 0.5)   # girdap tacı: tüylü kara kenar, çivit-mor çizgiler içe akar
	gather(pj, func() -> Vector3: return at, 3.0, 8, 0.3)
	var ct = core.create_tween()
	ct.tween_property(core, "scale", Vector3.ONE * (0.9 + kp * 0.4), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("absorb", at, 0.4)
	var center = func() -> Vector3: return at
	pj.every(DUR, 0.05, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if i % 2 == 0:   # içe kıvrılan sarmal iplikler + yerden kopup çekilen taşlar
			for q in 3:
				var a0 = randf() * TAU
				var el = randf_range(-0.6, 0.8)
				var r0 = R * randf_range(0.5, 0.9)
				var s0: Vector3 = at + Vector3(cos(a0) * cos(el) * r0, sin(el) * r0, sin(a0) * cos(el) * r0)
				filament(pj, _spiral_path(s0, center, 0.6, a0, 0.3), 0.4, 0.14, _thread_mat(), 0.7, 18)   # kalın damla biçimli mürekkep, boşluğa sivrilerek akar
			var gpt: Vector3 = pj.gp(at + Vector3(randf_range(-R, R), 0, randf_range(-R, R)) * 0.7)
			for q in 2:
				_chip(pj, gpt + Vector3(randf_range(-0.3, 0.3), 0.05, randf_range(-0.3, 0.3)), at, randf_range(0.6, 0.9))
		for e in pj.enemies_near(cc, at, R):
			var v: Vector3 = at - e.global_position
			v.y = 0
			if e is CharacterBody3D and v.length() > 0.8:
				e.velocity = v.normalized() * (9.0 + kp * 3.0)
			if i % 5 == 0:
				e.take_hit(pj.inf(cc, id, 0.07 * kp, {"knock": 0.0, "kind": "light", "element": "meiton", "chakra_drain": 4.0, "hitstop": 0.0}))
		for p in pj.get_tree().get_nodes_in_group("projectiles"):   # atışlar boşluğa düşer
			if is_instance_valid(p) and p.get("shooter") != cc and p.global_position.distance_to(at) < R:
				var pv: Vector3 = at - p.global_position
				if pv.length() < 1.0:
					p.queue_free()
				else:
					p.vel = Vector3(p.vel).lerp(pv.normalized() * Vector3(p.vel).length(), 0.3)
		if is_instance_valid(core):
			core.scale = Vector3.ONE * (0.9 + kp * 0.4) * (1.0 + sin(i * 0.8) * 0.06), func():
		var cc = cw.get_ref()
		if is_instance_valid(core):
			var t2 = core.create_tween()
			t2.tween_property(core, "scale", Vector3.ONE * 0.05, 0.12).set_ease(Tween.EASE_IN)
			t2.tween_callback(core.queue_free)
		pj.after(0.12, func():
			_void_burst(pj, at, R)
			pj.shake(0.5)
			Sfx.play("boom", at, 0.7))
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 3.5 + kp):
			e.take_hit(pj.inf(cc, id, 0.5 * kp, {"knock": 14.0, "launch": 5.0, "kind": "heavy", "element": "meiton", "hitstop": 0.1, "pierce_guard": kp > 1.6, "dir": (e.global_position - at).normalized()})))
	if c == Game.player and store > 0.0:
		Hud.msg("Harcanan chakra: %d" % int(store), Color(0.7, 0.45, 0.95))


static func _void_burst(pj: PathJutsu, at: Vector3, R: float) -> void:
	_mass(pj, at, 0.15, R * 0.45, 0.4, 1.0)
	var sm = _shared("spike", "strip", {"ragged": 0.3})
	for q in 18:   # boşluktan fırlayan kara dikenler
		var dir = Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
		var L = R * randf_range(0.6, 0.95)
		filament(pj, func(u: float) -> Vector3: return at + dir * (0.4 + u * L), 0.22, 0.16, sm, 0.5, 12)
	splash(pj, at, 16, 9.0, 0.11, Vector3.ZERO, 0.7)
	motes(pj, at + Vector3.DOWN * 0.5, R * 0.4, 16, 1.6)
	residue(pj, at, R * 0.35, 2.8)


## Kyūin Kōsen: avuçtan en yakın üç rakibe ince, yılan gibi dalgalanan mürekkep bağları uzanır; uçları göğse kök salar,
## içlerinden leylak boncuklar avuca akar
static func kyuin_kosen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 2.2)
	var id = "meiton_kyuin_kosen"
	pj._face(c, pj.tg(c, t, 14.0))
	pj.anim(c, "push", 0.8)
	palm_glyph(pj, c, 2.3, 0.42, 3.0)
	var cw = weakref(c)
	var foes = pj.enemies_near(c, c.global_position, 14.0)
	foes.sort_custom(func(a, b): return a.global_position.distance_to(c.global_position) < b.global_position.distance_to(c.global_position))
	foes = foes.slice(0, 3)
	Sfx.play("absorb", c.global_position, 0.5)
	var palm = _palm_fn(pj, c, 0.05)
	wisp_coat(pj, c, 2.2, 12.0)   # emilen chakra kollarda kara alev dili olarak kıvrılır
	for e in foes:
		cord(pj, palm, _chest_fn(e, 0.61), 2.2, 0.035, 0.22, 0.16, 3, 0.055)
		motes(pj, e.global_position, 0.6, 10, 1.6, palm, 0.035)   # hedeften avuca süzülen zerreler
	pj.every(2.2, 0.2, func(_i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		for e in foes:
			if not is_instance_valid(e) or not pj.live(e) or e.global_position.distance_to(cc.global_position) > 18.0:
				continue
			pj.st(e, "slow", 0.4)
			var hp0 = e.hp
			e.take_hit(pj.inf(cc, id, 0.14, {"knock": 0.0, "kind": "light", "element": "meiton", "chakra_drain": 5.0, "hitstop": 0.0}))
			pj.heal(cc, maxf(0.0, hp0 - e.hp) * 0.5)
			pj._mei_store(cc, 5.0))


## Ankoku Kaihō: çevreden sarmal iplikler bedene çekilir, ayaklardan mürekkep dilleri yükselir; sonra bedenden kara-mor kütle
## kabarır, yerde dışa yuvarlanan kalın mürekkep dalgası (sırtı leylak) yayılır, mürekkep kavisleri ve damlalar saçılır
static func ankoku_kaiho(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "meiton_ankoku_kaiho"
	pj.anim(c, "crouch", 1.5)
	var store = float(c.get_meta("meiton_store", 0.0))
	c.set_meta("meiton_store", 0.0)
	var kp = clampf(0.5 + store / 100.0, 0.5, 3.5)
	var cw = weakref(c)
	var cen: Vector3 = c.global_position
	var R = 4.0 + kp * 1.6
	Sfx.play("absorb", cen, 0.3)
	var chest = _follow_fn(c, Vector3.UP * 1.1)
	wisp_coat(pj, c, 0.9, 45.0)   # hazırlıkta beden kara alev dilleriyle kaplanır
	motes(pj, cen, R * 0.7, 20, 0.4, chest, 0.05)
	pj.every(0.4, 0.04, func(i, _k):   # içe çekilen kara chakra
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for q in 2:
			var a = randf() * TAU
			var p0 = cc.global_position + Vector3(cos(a) * R * 0.6, randf_range(0.3, 2.4), sin(a) * R * 0.6)
			filament(pj, _spiral_path(p0, chest, 0.5, randf() * TAU, 0.2), 0.3, 0.06, _thread_mat(), 0.6)
		if i % 3 == 0:   # ayaklardan yükselen mürekkep dilleri
			var base: Vector3 = cc.global_position
			var b0 = randf() * TAU
			filament(pj, func(u: float) -> Vector3:
				var a2 = b0 + u * 1.5
				return base + Vector3(cos(a2) * 0.45 * (1.0 - u * 0.5), u * 2.3, sin(a2) * 0.45 * (1.0 - u * 0.5)), 0.45, 0.07, _thread_mat(), 0.6, 10))
	pj.after(0.45, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		pj.anim(cc, "cross", 2.0)
		var p: Vector3 = cc.global_position + Vector3.UP * 1.0
		ink_wave(pj, pj.gp(p), R, kp)
		_mass(pj, p, 0.4, minf(R * 0.3, 2.2), 0.5)
		for q in 10:   # dışa savrulan mürekkep kavisleri
			var a = q * TAU / 10.0 + randf() * 0.3
			var dir = Vector3(cos(a), 0, sin(a))
			var L = R * randf_range(0.7, 1.0)
			var hgt = randf_range(1.0, 2.2)
			filament(pj, func(u: float) -> Vector3:
				return p + dir * u * L + Vector3.UP * (sin(u * PI) * hgt - u * 0.9), 0.3, 0.08, _thread_mat(), 0.5)
		splash(pj, p, 20, 8.0 + kp * 2.0, 0.13, Vector3.UP * 0.6, 0.8)
		var pg: Vector3 = pj.gp(p)
		pj.after(0.4, func(): residue(pj, pg, R * 0.55, 3.0))   # sonrası: dalganın ardında buharlaşan kalıntı + mühür izi
		pj.shake(0.3 + kp * 0.15)
		Sfx.play("boom", p, 0.7)
		for e in pj.enemies_near(cc, cc.global_position, R):
			var v: Vector3 = e.global_position - cc.global_position
			v.y = 0
			e.take_hit(pj.inf(cc, id, 0.9 * kp, {"knock": 10.0 + kp * 5.0, "launch": 3.0 + kp, "kind": "heavy", "element": "meiton", "hitstop": 0.1, "pierce_guard": kp > 2.0, "dir": v.normalized() if v.length() > 0.1 else cc.face_dir()})))
	if c == Game.player:
		Hud.msg("Salınan chakra: %d" % int(store), Color(0.7, 0.45, 0.95))
