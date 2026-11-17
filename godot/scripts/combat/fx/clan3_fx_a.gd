class_name Clan3FXA
extends RefCounted
## Klan grubu 3A: Fūma (dev yel değirmeni shurikeni, tel, çelik), Tsuchigumo (doğa enerjisi, örümcek ipeği, toprak kapanı,
## zehirli örümcekler), Uzumaki (Kongō Fūsa altın zincirleri, Hakke / Shikoku göbek mühürleri, Fūka Hōin parşömeni,
## Uzumaki mühür girdabı, Chiyu Kōshō ısırık şifası). Tüm görünüş bu dosyada sıfırdan üretilir: kendi gölgelendiricilerim
## (cel katı + koyu kontur, mühür / yazı / ağ / çatlak / yanık / dönme bulanıklığı çizimleri, enerji şeridi, patlama küresi,
## altın hale), kendi geometrim (tüp, şerit, MultiMesh zincir halkaları) ve kendi parçacık ayarlarım.
## Fūma shurikeni oyunun kendi silah modelidir (CharacterModel._fuma). Kameraya yakın parçalar noktalı olarak incelir.
## Oynanış (hasar, durum, süre, menzil, hedefleme, mermi) ana ağaçtaki işleyicilerden satır satır taşındı.

const STEEL_L := Color(0.84, 0.85, 0.88)
const STEEL_D := Color(0.2, 0.2, 0.23)
const SILK := Color(0.97, 0.96, 0.9)
const EARTH_C := Color(0.5, 0.38, 0.26)
const EARTH_D := Color(0.24, 0.17, 0.11)
const NATURE := Color(1.0, 0.8, 0.36)
const NATURE_HOT := Color(1.0, 0.42, 0.12)
const GOLD := Color(1.0, 0.86, 0.38)
const GOLD_D := Color(0.42, 0.26, 0.05)
const INK := Color(0.05, 0.04, 0.06)
const SEAL_BLUE := Color(0.4, 0.66, 1.0)
const HEAL_G := Color(0.5, 1.0, 0.6)
const PAPER := Color(0.97, 0.95, 0.88)

static var _cache := {}


# ================================================================== gölgelendiriciler
const COMMON := """
float h11(float n) { return fract(sin(n * 127.1 + 0.3) * 43758.5453); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nearcut(vec3 vp, vec2 fc, float nfd) {
	float kf = smoothstep(nfd * 0.35, nfd, length(vp));
	return step(kf, h21(floor(fc)));
}
float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return length(pa - ba * h);
}
float glyph(vec2 q, float id) {
	float d = 10.0;
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		vec2 a = floor(vec2(h11(id * 3.1 + fk * 7.3), h11(id * 5.7 + fk * 2.9)) * 2.99) * 0.5;
		vec2 b = floor(vec2(h11(id * 1.3 + fk * 4.1), h11(id * 8.9 + fk * 6.1)) * 2.99) * 0.5;
		if (k == 3 && h11(id + 9.0) > 0.5) { b = a + vec2(0.12, 0.1); }
		a = 0.15 + a * 0.7;
		b = 0.15 + b * 0.7;
		d = min(d, sd_seg(q, a, b));
	}
	return d;
}
float ring_glyphs(float r, float a01, float r0, float r1, float n, float sd) {
	if (r < r0 || r > r1) { return 10.0; }
	float cell = floor(fract(a01) * n);
	vec2 q = vec2(fract(fract(a01) * n), (r - r0) / (r1 - r0));
	if (h11(cell * 1.7 + sd) > 0.88) { return 10.0; }
	return glyph(q, cell + sd);
}
float spiral(float r, float an, float b) {
	float n = r / b - (an + PI) / TAU;
	return abs(fract(n + 0.5) - 0.5) * b;
}
float trigram(vec2 p, float rad, float sd) {
	float an = atan(p.y, p.x);
	float s = floor((an + PI) / TAU * 8.0 + 0.5);
	float ac = s / 8.0 * TAU - PI;
	vec2 rd = vec2(cos(ac), sin(ac));
	vec2 tg = vec2(-rd.y, rd.x);
	vec2 q = vec2(dot(p, tg), dot(p, rd) - rad);
	float d = 10.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float y = (fi - 1.0) * 0.065;
		float bar = max(abs(q.x) - 0.085, abs(q.y - y) - 0.016);
		if (h11(s * 3.0 + fi + sd) > 0.5) { bar = max(bar, 0.022 - abs(q.x)); }
		d = min(d, bar);
	}
	return d;
}
"""

## Cel katı (iki ton + çelik parıltı bandı), köşe rengi × tint; alpha noktalı dağılma
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 glow_col : source_color = vec4(1.0, 0.8, 0.3, 1.0);
instance uniform float alpha = 1.0;
instance uniform float nf = 1.2;
instance uniform float metal = 0.0;
instance uniform float glow = 0.0;
instance uniform float seed = 0.0;

COMMON

void fragment() {
	if (nearcut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	if (h21(floor(FRAGCOORD.xy) + vec2(seed * 13.0)) > alpha) { discard; }
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 ld = normalize(vec3(0.4, 0.85, 0.35));
	float nl = dot(wn, ld);
	vec3 base = COLOR.rgb * tint.rgb;
	vec3 col = base * (nl > -0.1 ? 1.0 : 0.6);
	if (metal > 0.0) {
		vec3 wv = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		float sp = dot(reflect(-ld, wn), wv);
		col += step(0.8, sp) * metal * vec3(0.85);
		float fr = 1.0 - abs(dot(NORMAL, VIEW));
		col = mix(col, col * 0.5, step(0.72, fr) * metal * 0.6);
	}
	col = mix(col, glow_col.rgb, clamp(glow, 0.0, 1.0));
	ALBEDO = col;
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

instance uniform vec4 oc : source_color = vec4(0.04, 0.03, 0.05, 1.0);
instance uniform float ow = 0.02;
instance uniform float alpha = 1.0;
instance uniform float nf = 1.2;
instance uniform float seed = 0.0;

COMMON

void vertex() {
	VERTEX += NORMAL * ow;
}

void fragment() {
	if (nearcut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	if (h21(floor(FRAGCOORD.xy) + vec2(seed * 13.0)) > alpha) { discard; }
	ALBEDO = oc.rgb;
}
"""

## Altın chakra halesi: şişirilmiş kabuk, kenarda yoğun, eklemeli
const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

instance uniform vec4 hc : source_color = vec4(1.0, 0.85, 0.4, 1.0);
instance uniform float puff = 0.04;
instance uniform float alpha = 1.0;
instance uniform float nf = 1.5;

COMMON

void vertex() {
	VERTEX += NORMAL * puff;
}

void fragment() {
	if (nearcut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = hc.rgb * (0.25 + 0.75 * fr) * alpha * (0.85 + 0.15 * sin(TIME * 7.0));
}
"""

## Patlama / alev küresi: dalgalı yüzey, üç ton bant, prog ile çözülür ve kararır
const BLAST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

instance uniform vec4 c1 : source_color = vec4(1.0, 0.95, 0.6, 1.0);
instance uniform vec4 c2 : source_color = vec4(1.0, 0.55, 0.12, 1.0);
instance uniform vec4 c3 : source_color = vec4(0.75, 0.15, 0.05, 1.0);
instance uniform vec4 c4 : source_color = vec4(0.18, 0.12, 0.1, 1.0);
instance uniform float prog = 0.0;
instance uniform float nf = 1.5;
instance uniform float seed = 0.0;

COMMON

void vertex() {
	float n = sin(VERTEX.x * 7.0 + seed) * sin(VERTEX.y * 6.0 + seed * 2.0 + TIME * 4.0) * sin(VERTEX.z * 8.0 + seed * 3.0);
	VERTEX += NORMAL * n * 0.1;
}

void fragment() {
	if (nearcut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	float n2 = 0.5 + 0.5 * sin(UV.x * 31.0 + seed) * sin(UV.y * 19.0 + TIME * 3.0 + seed);
	if (n2 < prog * 1.25 - 0.25) { discard; }
	float fr = abs(dot(NORMAL, VIEW));
	vec3 col = fr > 0.62 ? c1.rgb : (fr > 0.32 ? c2.rgb : c3.rgb);
	col = mix(col, c4.rgb, smoothstep(0.35, 0.9, prog) * step(fr, 0.7 + prog * 0.3));
	ALBEDO = col;
}
"""

## Enerji / iplik şeridi. UV.x boy (reveal ile baştan uca), UV.y en. pat 0 düz bant, 1 akan nabız, 2 alev dili, 3 tırtıklı
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 c1 : source_color = vec4(1.0, 1.0, 0.95, 1.0);
instance uniform vec4 c2 : source_color = vec4(1.0, 0.8, 0.3, 1.0);
instance uniform vec4 c3 : source_color = vec4(0.4, 0.2, 0.05, 1.0);
instance uniform float alpha = 1.0;
instance uniform float nf = 1.5;
instance uniform float reveal = 1.0;
instance uniform float tail = 0.0;
instance uniform float pat = 0.0;
instance uniform float seed = 0.0;
instance uniform float spd = 1.0;
instance uniform float fade = 0.0;

COMMON

void fragment() {
	if (nearcut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	float u = UV.x;
	float v = UV.y;
	if (u > reveal || u < tail) { discard; }
	float ac = abs(v - 0.5) * 2.0;
	float w = 1.0;
	if (pat > 0.5 && pat < 1.5) {
		float f = fract(u * 5.0 - TIME * spd + seed);
		w = 0.45 + 0.55 * smoothstep(0.0, 0.25, f) * (1.0 - smoothstep(0.45, 0.9, f));
	} else if (pat > 1.5 && pat < 2.5) {
		w = (1.0 - u * 0.8) * (0.75 + 0.25 * sin(u * 22.0 - TIME * 15.0 + seed));
	} else if (pat > 2.5) {
		w = 0.4 + 0.6 * h11(floor(u * 28.0) + seed * 7.0);
	}
	if (ac > w) { discard; }
	float rr = ac / max(w, 0.001);
	vec3 col = rr < 0.4 ? c1.rgb : (rr < 0.78 ? c2.rgb : c3.rgb);
	float a = alpha * mix(1.0, u, fade);
	if (a < 0.02) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Düz çizimler (dörtgen üstünde). kind:
## 0 Tenchi Kaibyaku lav formül çemberi, 1 Uzumaki girdap + tırtıklı mürekkep halkası, 2 yazı sütunu (şerit),
## 3 Hakke göbek mührü (sarmal + sekiz trigram + alev halkası), 4 Shikoku oyma mührü (mavi), 5 Fūka parşömen kâğıdı,
## 6 Hakke trigram sunağı (yer), 7 örümcek ağı, 8 çatlak, 9 yanık izi, 10 dönme bulanıklığı (Fūma), 13 darbe yıldızı,
## 14 düşüş gölgesi + nişan halkası, 15 patlayıcı kâğıt, 16 şok halkası, 17 Tsuchigumo sırt mührü, 18 hız çizgileri,
## 19 çukur, 20 doğa halkası
const SEAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 c1 : source_color = vec4(1.0, 0.9, 0.5, 1.0);
instance uniform vec4 c2 : source_color = vec4(1.0, 0.4, 0.1, 1.0);
instance uniform vec4 c3 : source_color = vec4(0.05, 0.04, 0.06, 1.0);
instance uniform float kind = 0.0;
instance uniform float reveal = 1.0;
instance uniform float alpha = 1.0;
instance uniform float nf = 1.5;
instance uniform float seed = 0.0;
instance uniform float glow = 0.0;
instance uniform float aspect = 1.0;
instance uniform float bill = 0.0;
instance uniform float flap = 0.0;

COMMON

void vertex() {
	if (flap > 0.0) {
		VERTEX.z += sin(UV.y * 6.0 + TIME * 12.0 + seed * 3.0) * flap * UV.y;
	}
	if (bill > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	if (nearcut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float an = atan(p.y, p.x);
	float a01 = an / TAU + 0.5;
	vec3 col = c1.rgb;
	float a = 0.0;
	float k = kind;
	if (k < 0.5) {
		float d = min(min(abs(r - 0.93) - 0.012, abs(r - 0.86) - 0.008), min(abs(r - 0.6) - 0.01, abs(r - 0.54) - 0.007));
		float g1 = ring_glyphs(r, a01, 0.62, 0.84, 34.0, seed);
		float g2 = ring_glyphs(r, a01 + 0.03, 0.3, 0.52, 18.0, seed + 40.0);
		float sa = fract(a01 * 8.0) - 0.5;
		float tooth = (r > 0.92 && r < 0.995 - abs(sa) * 0.55) ? 1.0 : 0.0;
		float st = 10.0;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float a0 = fi * TAU / 5.0 + seed;
			float a1 = (fi + 2.0) * TAU / 5.0 + seed;
			st = min(st, sd_seg(p, vec2(cos(a0), sin(a0)) * 0.54, vec2(cos(a1), sin(a1)) * 0.54));
		}
		float ink = step(min(d, st - 0.008), 0.0) + step(min(g1, g2), 0.075) + tooth;
		if (a01 > reveal) { ink = 0.0; }
		float fl = 0.6 + 0.4 * sin(TIME * 9.0 + r * 30.0 + an * 4.0);
		if (ink > 0.5) {
			col = mix(c2.rgb, c1.rgb, fl);
			a = 1.0;
		} else {
			col = c2.rgb;
			a = (1.0 - smoothstep(0.85, 0.95, r)) * 0.16 * min(reveal, 1.0);
		}
	} else if (k < 1.5) {
		float spl = r < 0.36 ? spiral(r, an, 0.09) - 0.02 : 10.0;
		float wob = r - 0.8 - 0.035 * sin(an * 23.0 + seed) - 0.02 * sin(an * 57.0 + seed * 3.0);
		float ring = abs(wob) - (0.012 + 0.014 * h11(floor(a01 * 90.0) + seed));
		float g = ring_glyphs(r, a01, 0.86, 0.97, 44.0, seed + 7.0);
		float ink = 0.0;
		if (spl < 0.0 && r < reveal * 0.6) { ink = 1.0; }
		if ((ring < 0.0 || g < 0.07) && a01 < reveal) { ink = 1.0; }
		col = mix(c3.rgb, c1.rgb, clamp(glow, 0.0, 1.0) * (0.55 + 0.45 * sin(TIME * 10.0 + r * 12.0)));
		a = ink;
		if (ink < 0.5 && glow > 0.0) {
			col = c1.rgb;
			a = glow * 0.22 * (1.0 - smoothstep(0.75, 0.95, r));
		}
	} else if (k < 2.5) {
		float id = floor(UV.x * aspect);
		vec2 q = vec2(fract(UV.x * aspect), UV.y);
		float g = h11(id * 2.3 + seed) > 0.9 ? 10.0 : glyph(q, id + seed);
		a = (g < 0.085 && UV.x < reveal) ? 1.0 : 0.0;
		col = mix(c3.rgb, c1.rgb, clamp(glow, 0.0, 1.0));
	} else if (k < 3.5) {
		float sp = r < 0.3 ? spiral(r, an, 0.07) - 0.016 : 10.0;
		float ring = abs(r - 0.38) - 0.012;
		float tri = trigram(p, 0.6, seed);
		float wob = r - 0.86 - 0.04 * sin(an * 31.0 + seed) * sin(an * 7.0);
		float fl = abs(wob) - 0.01 - 0.02 * step(0.8, h11(floor(a01 * 70.0) + seed));
		float d = min(min(sp, ring), min(tri, fl));
		if (r > reveal * 1.05) { d = 10.0; }
		col = mix(c3.rgb, c1.rgb, clamp(glow, 0.0, 1.0));
		a = step(d, 0.0);
		if (a < 0.5 && glow > 0.0) {
			col = c1.rgb;
			a = glow * 0.5 * (1.0 - smoothstep(0.0, 0.06, d));
		}
	} else if (k < 4.5) {
		float d = min(abs(r - 0.86) - 0.014, abs(r - 0.55) - 0.01);
		for (int i = 0; i < 4; i++) {
			float aa = float(i) * PI * 0.25 + seed;
			vec2 dv = vec2(cos(aa), sin(aa));
			d = min(d, sd_seg(p, -dv * 0.55, dv * 0.55) - 0.008);
		}
		float g = ring_glyphs(r, a01, 0.59, 0.82, 16.0, seed);
		d = min(d, g * 0.23 - 0.016);
		vec2 qc = p / 0.36 * 0.5 + 0.5;
		if (r < 0.32) { d = min(d, glyph(qc, seed + 3.0) * 0.72 - 0.03); }
		if (a01 > reveal) { d = 10.0; }
		col = d < -0.004 ? c1.rgb : c2.rgb;
		a = step(d, 0.0);
		if (a < 0.5) {
			a = (1.0 - smoothstep(0.0, 0.07, d)) * 0.55 * glow;
			col = c2.rgb;
		}
	} else if (k < 5.5) {
		float u = UV.x;
		float v = UV.y;
		col = c1.rgb;
		a = 1.0;
		if (v < 0.1 || v > 0.9) { col = c2.rgb; }
		if (abs(v - 0.1) < 0.008 || abs(v - 0.9) < 0.008 || u < 0.006 || u > 0.994) { col = c3.rgb; }
		bool lz = u > 0.04 && u < 0.32;
		bool rz = u > 0.68 && u < 0.96;
		if ((lz || rz) && v > 0.12 && v < 0.88) {
			float cw = 0.045;
			float cx = floor((u - 0.04) / cw);
			float ch = cw * aspect;
			float cy = floor((v - 0.12) / ch);
			vec2 q = vec2(fract((u - 0.04) / cw), fract((v - 0.12) / ch));
			float id = cx * 17.0 + cy * 3.0 + seed;
			if (h11(id) < 0.84 && glyph(q, id) < 0.09) { col = c3.rgb; }
		}
		vec2 pc = vec2((u - 0.5) * aspect, v - 0.5);
		float rc = length(pc);
		float ac = atan(pc.y, pc.x) - reveal;
		float arr = 10.0;
		for (int i = 0; i < 3; i++) {
			float base = float(i) * TAU / 3.0;
			float rel = mod(ac - base + PI, TAU) - PI;
			if (rel > -0.6 && rel < 0.6) { arr = min(arr, abs(rc - 0.25) - 0.022); }
			float ae = base + 0.6 + reveal;
			vec2 tip = vec2(cos(ae), sin(ae)) * 0.25;
			vec2 tdir = vec2(-sin(ae), cos(ae));
			vec2 nrm = vec2(cos(ae), sin(ae));
			arr = min(arr, sd_seg(pc, tip, tip - tdir * 0.07 + nrm * 0.06) - 0.02);
			arr = min(arr, sd_seg(pc, tip, tip - tdir * 0.07 - nrm * 0.06) - 0.02);
		}
		if (arr < 0.0) { col = c3.rgb; }
		if (glow > 0.0) {
			float gr = ring_glyphs(rc / 0.45, atan(pc.y, pc.x) / TAU + 0.5 + TIME * 0.05, 0.7, 0.95, 22.0, seed + 5.0);
			float halo = (1.0 - smoothstep(0.2, 0.46, rc)) * glow;
			col = mix(col, vec3(0.55, 0.78, 1.0), halo * 0.55);
			if (gr < 0.09) { col = mix(col, vec3(0.12, 0.25, 0.75), glow); }
		}
	} else if (k < 6.5) {
		float ang8 = mod(an + PI / 8.0, TAU / 8.0) - PI / 8.0;
		float oct = abs(r * cos(ang8) - 0.92) - 0.014;
		float d = min(oct, abs(r - 0.45) - 0.012);
		d = min(d, trigram(p, 0.7, seed));
		d = min(d, r < 0.3 ? spiral(r, an, 0.08) - 0.014 : 10.0);
		if (r > reveal * 1.05) { d = 10.0; }
		col = mix(c3.rgb, c1.rgb, clamp(glow, 0.0, 1.0) * step(d, 0.0));
		a = step(d, 0.0);
		if (a < 0.5 && r * cos(ang8) < 0.92 && r < reveal) {
			col = c3.rgb;
			a = 0.28;
		}
	} else if (k < 7.5) {
		float sa = abs(fract(a01 * 10.0 + 0.5) - 0.5) * TAU / 10.0 * r;
		float d = sa - 0.012;
		for (int i = 0; i < 5; i++) {
			float rr = (0.2 + float(i) * 0.18) * (1.0 - 0.07 * sin(fract(a01 * 10.0) * PI));
			d = min(d, abs(r - rr) - 0.009);
		}
		d = min(d, r - 0.07);
		if (r > 0.97 || r > reveal) { d = 10.0; }
		a = step(d, 0.0);
		col = d < -0.005 ? c1.rgb : c2.rgb;
	} else if (k < 8.5) {
		float d = 10.0;
		for (int i = 0; i < 9; i++) {
			float fi = float(i);
			float ai = fi / 9.0 * TAU + h11(fi + seed) * 0.5;
			float jag = sin(r * 23.0 + fi * 3.1) * 0.07 + sin(r * 51.0 + fi) * 0.03;
			float da = abs(mod(an - ai - jag + PI, TAU) - PI) * r;
			float len = 0.55 + 0.42 * h11(fi * 2.7 + seed);
			if (r < len) { d = min(d, da - 0.03 * (1.0 - r / len)); }
		}
		float crater = r - 0.16 - 0.03 * sin(an * 9.0 + seed);
		if (r > reveal) { d = 10.0; crater = 10.0; }
		col = c3.rgb;
		a = max(step(d, 0.0), step(crater, 0.0) * 0.6);
	} else if (k < 9.5) {
		float edge = 0.72 + 0.12 * sin(an * 7.0 + seed) + 0.06 * sin(an * 17.0 + seed * 2.0);
		a = (1.0 - smoothstep(edge - 0.2, edge, r)) * 0.75;
		col = c3.rgb;
		if (glow > 0.0 && r < edge - 0.1 && h21(floor(p * 22.0) + seed) > 0.93) {
			col = mix(c3.rgb, c2.rgb, glow * (0.6 + 0.4 * sin(TIME * 8.0 + p.x * 20.0)));
			a = 1.0;
		}
	} else if (k < 10.5) {
		float sw = fract(a01 * 4.0 - TIME * 7.0 + seed);
		float inten = pow(1.0 - sw, 3.0);
		float band = (r > 0.22 && r < 0.97) ? 1.0 : 0.0;
		col = mix(c2.rgb, c1.rgb, step(0.6, inten));
		a = band * (0.18 + 0.6 * inten);
		if (abs(r - 0.95) < 0.015) { col = c1.rgb; a = 0.7; }
	} else if (k < 13.5) {
		float sid = floor(a01 * 8.0 + 0.5);
		float spk = pow(abs(cos(an * 4.0)), 6.0);
		float rs = mix(0.28, 0.6 + 0.4 * h11(sid + seed), spk) * reveal;
		if (r < rs) {
			col = r < rs * 0.55 ? c1.rgb : c2.rgb;
			if (r > rs - 0.07) { col = c3.rgb; }
			a = 1.0;
		}
	} else if (k < 14.5) {
		a = (1.0 - smoothstep(0.4, 1.0, r)) * 0.45;
		col = c3.rgb;
		float rg = abs(r - 0.82) - 0.018;
		float cr = min(abs(p.x), abs(p.y)) - 0.012;
		if (rg < 0.0 || (cr < 0.0 && r > 0.6 && r < 1.0)) { col = c2.rgb; a = 0.9; }
		if (r > reveal) { a = 0.0; }
	} else if (k < 15.5) {
		float u = UV.x;
		float v = UV.y;
		col = c1.rgb;
		a = 1.0;
		if (u < 0.08 || u > 0.92 || v < 0.04 || v > 0.96) { col = c2.rgb; }
		float id = floor(v * 3.0);
		vec2 q = vec2((u - 0.15) / 0.7, fract(v * 3.0));
		if (u > 0.15 && u < 0.85 && glyph(q, id * 5.0 + seed) < 0.1) { col = id == 1.0 ? c2.rgb : c3.rgb; }
		if (glow > 0.0) {
			float bn = h21(floor(UV * vec2(8.0, 20.0)) + seed);
			if (bn < glow * 1.2 - 0.3) { discard; }
			if (bn < glow * 1.2 - 0.1) { col = vec3(1.0, 0.55, 0.12); }
			col = mix(col, vec3(1.0, 0.3, 0.08), glow * 0.35);
		}
	} else if (k < 16.5) {
		float rd = abs(r - 0.88);
		if (rd < 0.08) {
			col = rd < 0.035 ? c1.rgb : c3.rgb;
			a = 1.0;
		} else if (r < 0.88) {
			col = c2.rgb;
			a = smoothstep(0.4, 0.88, r) * 0.3;
		}
	} else if (k < 17.5) {
		float d = min(r - 0.08, abs(r - 0.15) - 0.012);
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float aa = (fi < 3.0 ? 0.0 : PI) + (mod(fi, 3.0) - 1.0) * 0.75 + PI * 0.5;
			vec2 dv = vec2(cos(aa), sin(aa));
			vec2 m = dv * 0.45 + vec2(-dv.y, dv.x) * 0.08 * (mod(fi, 2.0) * 2.0 - 1.0);
			d = min(d, sd_seg(p, dv * 0.18, m) - 0.028 * (1.0 - r));
			d = min(d, sd_seg(p, m, m + dv * 0.25 - vec2(0.0, 0.12)) - 0.02 * (1.0 - r));
			d = min(d, sd_seg(p, m, m + vec2(-dv.y, dv.x) * 0.1) - 0.012);
		}
		if (r > reveal) { d = 10.0; }
		col = mix(c3.rgb, c1.rgb, clamp(glow, 0.0, 1.0));
		a = step(d, 0.0);
		if (a < 0.5 && glow > 0.0) {
			col = c2.rgb;
			a = (1.0 - smoothstep(0.0, 0.07, d)) * glow * 0.7;
		}
	} else if (k < 18.5) {
		float id = floor(a01 * 44.0);
		float hh = h11(id + seed);
		float ln = abs(fract(a01 * 44.0) - 0.5);
		if (ln < 0.12 * hh && r > 0.4 + 0.35 * hh && r < 0.98) {
			col = c1.rgb;
			a = 1.0 - smoothstep(0.7, 0.98, r);
		}
	} else if (k < 19.5) {
		float edge = 0.78 + 0.07 * sin(an * 11.0 + seed) + 0.04 * sin(an * 29.0);
		if (r < edge) {
			col = mix(c3.rgb, c2.rgb, smoothstep(0.1, edge, r) * 0.5);
			a = 1.0;
		} else if (r < edge + 0.12) {
			col = c2.rgb;
			a = 1.0 - smoothstep(edge + 0.04, edge + 0.12, r);
		}
	} else {
		float d = min(abs(r - 0.92) - 0.014, abs(r - 0.8) - 0.01);
		float lc = fract(a01 * 24.0) - 0.5;
		vec2 lq = vec2(lc * 2.2, (r - 0.86) / 0.05);
		d = min(d, (length(lq) - 1.0) * 0.03);
		for (int i = 0; i < 3; i++) {
			float base = float(i) * TAU / 3.0 + seed;
			float rel = mod(an - base + PI, TAU) - PI;
			if (rel > 0.0 && rel < 1.6) { d = min(d, abs(r - 0.3 - rel * 0.18) - 0.012); }
		}
		if (a01 > reveal) { d = 10.0; }
		float fl = 0.7 + 0.3 * sin(TIME * 8.0 + an * 3.0);
		col = mix(c2.rgb, c1.rgb, fl);
		a = step(d, 0.0);
	}
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""


# ================================================================== malzeme / düğüm yardımcıları
static func _mat(key: String, code: String) -> ShaderMaterial:
	var mk = "mat:" + key
	if _cache.has(mk):
		return _cache[mk]
	var sh = Shader.new()
	sh.code = code.replace("COMMON", COMMON)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[mk] = m
	return m


static func _cel_mat() -> ShaderMaterial:
	return _mat("cel", CEL_SHADER)


static func _outline_mat() -> ShaderMaterial:
	return _mat("outline", OUTLINE_SHADER)


static func _halo_mat() -> ShaderMaterial:
	return _mat("halo", HALO_SHADER)


static func _blast_mat() -> ShaderMaterial:
	return _mat("blast", BLAST_SHADER)


static func _glow_mat() -> ShaderMaterial:
	return _mat("glow", GLOW_SHADER)


static func _seal_mat() -> ShaderMaterial:
	return _mat("seal", SEAL_SHADER)


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _prm(n: GeometryInstance3D, prm: Dictionary) -> void:
	for k in prm:
		n.set_instance_shader_parameter(k, prm[k])


## Düğüm ve altındaki tüm görsellere aynı örnek parametresi
static func _all(n: Node, key: String, val) -> void:
	if not is_instance_valid(n):
		return
	if n is GeometryInstance3D:
		n.set_instance_shader_parameter(key, val)
	for ch in n.get_children():
		_all(ch, key, val)


static func _tp(n: Node, key: String, a: float, b: float, dur: float, delay := 0.0) -> Tween:
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	var fn = func(v: float):
		if is_instance_valid(n):
			_all(n, key, v)
	tw.tween_method(fn, a, b, maxf(dur, 0.01))
	return tw


static func _fade_free(n: Node, delay: float, dur: float) -> void:
	if not is_instance_valid(n):
		return
	var tw = _tp(n, "alpha", 1.0, 0.0, dur, delay)
	tw.tween_callback(n.queue_free)


static func _quad(size: Vector2) -> QuadMesh:
	var key = "mesh:quad_%.3f_%.3f" % [size.x, size.y]
	if not _cache.has(key):
		var qm = QuadMesh.new()
		qm.size = size
		_cache[key] = qm
	return _cache[key]


static func _seal_quad(size: Vector2, prm: Dictionary) -> MeshInstance3D:
	var mi = _mi(_quad(size), _seal_mat())
	_prm(mi, prm)
	return mi


## Yere serilen çizim (mühür, çatlak, çukur, yanık)
static func _decal(pj: PathJutsu, at: Vector3, size: float, prm: Dictionary) -> MeshInstance3D:
	var mi = _seal_quad(Vector2(size, size), prm)
	mi.rotation.x = -PI * 0.5
	pj.scene_add(mi, pj.gp(at) + Vector3.UP * (0.04 + float(prm.get("lift", 0.0))))
	return mi


## Kameraya dönük çizim (darbe yıldızı, hız çizgileri, şok halkası)
static func _bill(pj: PathJutsu, at: Vector3, size: float, prm: Dictionary) -> MeshInstance3D:
	var p = {"bill": 1.0}
	p.merge(prm, true)
	var mi = _seal_quad(Vector2(size, size), p)
	pj.scene_add(mi, at)
	return mi


## Kısa ömürlü darbe çizimi: büyür, söner
static func _pop(pj: PathJutsu, at: Vector3, size: float, prm: Dictionary, life: float, grow := 1.4) -> void:
	var mi = _bill(pj, at, size, prm)
	mi.scale = Vector3.ONE * 0.5
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * grow, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_fade_free(mi, life * 0.4, life * 0.6)


## Yerde genişleyen şok halkası
static func _ground_ring(pj: PathJutsu, at: Vector3, r: float, c1: Color, c2: Color, c3: Color, life: float) -> void:
	var mi = _decal(pj, at, 2.0, {"kind": 16.0, "c1": c1, "c2": c2, "c3": c3, "lift": 0.03})
	mi.scale = Vector3.ONE * 0.2
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * r, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fade_free(mi, life * 0.45, life * 0.55)


static func _h(t: Node3D) -> float:
	return float(t.get("height")) if t.get("height") != null else 1.8


static func _rad(t: Node3D) -> float:
	return float(t.get("radius")) if t.get("radius") != null else 0.38


static func _bone(c: Node3D, bone: String, fb: Vector3) -> Vector3:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.get("skel") != null and m.skel:
		var bi = m.skel.find_bone(bone)
		if bi >= 0:
			return (m.skel.global_transform * m.skel.get_bone_global_pose(bi)).origin
	return fb


static func _front(t: Node3D) -> Vector3:
	var d := Vector3.FORWARD
	if t.has_method("face_dir"):
		d = t.face_dir()
	else:
		d = -t.global_basis.z
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


static func _chest(t: Node3D) -> Vector3:
	return t.global_position + Vector3.UP * _h(t) * 0.6


## Gerçek bedene yapışan yüzey: omurga kemiğinin önünde (ya da arkasında), bedenin yönüne bakar, süre boyunca izler
static func _stick(pj: PathJutsu, t: Node3D, n: Node3D, dur: float, bone := "Spine", depth := 0.2, back := false, yoff := 0.0) -> void:
	pj.scene_add(n, t.global_position)
	var s = ClanJutsu.body_scale(t)
	var tw_ref = weakref(t)
	var upd = func(_v: float):
		if not is_instance_valid(n):
			return
		var x = tw_ref.get_ref()
		if x == null or not is_instance_valid(x):
			n.queue_free()
			return
		var d: Vector3 = _front(x)
		if back:
			d = -d
		var p: Vector3 = _bone(x, bone, x.global_position + Vector3.UP * _h(x) * 0.52) + Vector3.UP * yoff * s
		n.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP) * Basis.from_scale(Vector3.ONE * s), p + d * depth * s)
	upd.call(0.0)
	var tw = n.create_tween()
	tw.tween_method(upd, 0.0, 1.0, maxf(dur, 0.05))
	tw.tween_callback(n.queue_free)


static func _shrink() -> Curve:
	if not _cache.has("curve:shrink"):
		var cv = Curve.new()
		cv.add_point(Vector2(0.0, 1.0))
		cv.add_point(Vector2(1.0, 0.0))
		_cache["curve:shrink"] = cv
	return _cache["curve:shrink"]


static func _grad(cols: Array) -> Gradient:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cc = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, float(cols.size() - 1)))
		cc.append(cols[i])
	g.offsets = offs
	g.colors = cc
	return g


static func _pmesh(kind: String) -> Mesh:
	var key = "mesh:p_" + kind
	if _cache.has(key):
		return _cache[key]
	var m: Mesh
	if kind == "chip":
		var bm = BoxMesh.new()
		bm.size = Vector3(1.0, 0.6, 0.8)
		m = bm
	elif kind == "streak":
		var bs = BoxMesh.new()
		bs.size = Vector3(0.1, 1.0, 0.1)
		m = bs
	elif kind == "flake":
		var qm = QuadMesh.new()
		qm.size = Vector2(1.0, 0.6)
		m = qm
	else:
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		m = sm
	_cache[key] = m
	return m


static func _pmat(add: bool) -> StandardMaterial3D:
	var key = "mat:part_add" if add else "mat:part"
	if not _cache.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if add:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_cache[key] = m
	return _cache[key]


## Kendi ayarlı parçacık püskürtmesi (kıvılcım, toprak parçası, zerre, kâğıt kırıntısı). parent verilirse onu izler.
static func _burst(pj: PathJutsu, pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	var one: bool = o.get("one", true)
	p.one_shot = one
	p.amount = int(o.get("n", 16))
	p.lifetime = float(o.get("life", 0.8))
	p.explosiveness = float(o.get("expl", 0.9 if one else 0.0))
	p.mesh = _pmesh(String(o.get("mesh", "mote")))
	p.material_override = _pmat(bool(o.get("add", false)))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if o.has("ring"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = float(o["ring"])
		p.emission_ring_inner_radius = float(o.get("ring_in", float(o["ring"]) * 0.8))
		p.emission_ring_height = 0.05
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = float(o.get("r", 0.2))
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 45.0))
	p.initial_velocity_min = float(o.get("v0", 2.0))
	p.initial_velocity_max = float(o.get("v1", 4.0))
	p.gravity = Vector3(0, -float(o.get("g", 9.8)), 0)
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0))
	p.scale_amount_min = float(o.get("s0", 0.06))
	p.scale_amount_max = float(o.get("s1", 0.12))
	p.scale_amount_curve = _shrink()
	p.particle_flag_align_y = bool(o.get("align", false))
	p.color_ramp = _grad(o.get("cols", [Color.WHITE, Color(1, 1, 1, 0)]))
	var parent: Node3D = o.get("parent", null)
	if parent:
		p.local_coords = false
		parent.add_child(p)
		p.position = o.get("off", Vector3.ZERO)
	else:
		pj.scene_add(p, pos)
	p.emitting = true
	if one:
		pj.free_after(p.lifetime + 0.5, p)
	return p


## Çelik kıvılcımları (Fūma çarpması)
static func _steel_sparks(pj: PathJutsu, pos: Vector3, n := 14, s := 1.0) -> void:
	_burst(pj, pos, {"n": n, "mesh": "streak", "align": true, "v0": 5.0 * s, "v1": 10.0 * s, "g": 14.0, "life": 0.32, "spread": 180.0,
		"s0": 0.18 * s, "s1": 0.32 * s, "add": true, "cols": [Color(1, 1, 0.92), Color(1, 0.82, 0.4), Color(1, 0.5, 0.1, 0)]})


## Toprak parçaları (yerden fırlayan kesek)
static func _clods(pj: PathJutsu, pos: Vector3, n := 12, v := 6.0, s := 1.0) -> void:
	_burst(pj, pos, {"n": n, "mesh": "chip", "v0": v * 0.5, "v1": v, "g": 16.0, "life": 0.9, "spread": 55.0, "r": 0.4 * s,
		"s0": 0.1 * s, "s1": 0.22 * s, "cols": [EARTH_C, EARTH_C.darkened(0.25), EARTH_D]})


# ================================================================== geometri
static func _arrays(v: PackedVector3Array, nr: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array) -> Array:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Tüp: pts boyunca yarıçaplar; UV.x boy, UV.y çevre (yan vektör eğri boyunca taşınır)
static func _tube(pts: Array, radii: Array, sides := 6) -> Array:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var n = pts.size()
	var prev := Vector3.ZERO
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tn.length() < 1e-5:
			tn = Vector3.FORWARD
		tn = tn.normalized()
		var s1: Vector3 = tn.cross(Vector3.UP if absf(tn.y) < 0.9 else Vector3.RIGHT).normalized()
		if prev != Vector3.ZERO:
			var pt = prev - tn * prev.dot(tn)
			if pt.length() > 1e-3:
				s1 = pt.normalized()
		prev = s1
		var s2 = tn.cross(s1).normalized()
		for j in sides + 1:
			var a = TAU * j / sides
			var dn = s1 * cos(a) + s2 * sin(a)
			v.append(p + dn * float(radii[i]))
			nr.append(dn)
			uv.append(Vector2(float(i) / maxf(n - 1, 1), float(j) / sides))
	for i in n - 1:
		for j in sides:
			var a0 = i * (sides + 1) + j
			var b0 = a0 + sides + 1
			idx.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))
	return _arrays(v, nr, uv, idx)


## Şerit. nrms verilirse tek yüzey (o normale dik yayılır); yoksa her açıdan görünen çapraz çift şerit. UV.x boy, UV.y en.
static func _ribbon(pts: Array, ws: Array, nrms: Array = []) -> Array:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var n = pts.size()
	var strips = 1 if not nrms.is_empty() else 2
	for s in strips:
		var base = v.size()
		for i in n:
			var p: Vector3 = pts[i]
			var tn: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			if tn.length() < 1e-5:
				tn = Vector3.FORWARD
			tn = tn.normalized()
			var nm: Vector3
			if not nrms.is_empty():
				nm = nrms[i]
			else:
				nm = tn.cross(Vector3.UP if absf(tn.y) < 0.9 else Vector3.RIGHT).normalized()
				if s == 1:
					nm = tn.cross(nm).normalized()
			var side = tn.cross(nm).normalized() * float(ws[i]) * 0.5
			v.append(p - side)
			v.append(p + side)
			nr.append(nm)
			nr.append(nm)
			var u = float(i) / maxf(n - 1, 1)
			uv.append(Vector2(u, 0.0))
			uv.append(Vector2(u, 1.0))
		for i in n - 1:
			var a0 = base + i * 2
			idx.append_array(PackedInt32Array([a0, a0 + 2, a0 + 1, a0 + 1, a0 + 2, a0 + 3]))
	return _arrays(v, nr, uv, idx)


static func _mesh(surfaces: Array) -> ArrayMesh:
	var am = ArrayMesh.new()
	for arr in surfaces:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## Her karede noktaları yeniden kurulan şerit / tüp (iplik, tel, chakra akışı, iz). pts_fn() -> Array (boşsa gizlenir).
## o: w (sayı ya da Callable(u)), tube, sides, flat (normal yukarı tek şerit)
static func _live_strand(pj: PathJutsu, mat: Material, prm: Dictionary, pts_fn: Callable, dur: float, o := {}) -> MeshInstance3D:
	var am = ArrayMesh.new()
	var mi = _mi(am, mat)
	_prm(mi, prm)
	pj.scene_add(mi, Vector3.ZERO)
	mi.global_transform = Transform3D.IDENTITY
	var tube: bool = o.get("tube", false)
	var flat: bool = o.get("flat", false)
	var upd = func(_v: float):
		if not is_instance_valid(mi):
			return
		var pts: Array = pts_fn.call()
		am.clear_surfaces()
		if pts.size() < 2:
			return
		var ws: Array = []
		var nrms: Array = []
		var wv = o.get("w", 0.05)
		for i in pts.size():
			var u = float(i) / float(pts.size() - 1)
			ws.append(wv.call(u) if wv is Callable else float(wv))
			if flat:
				nrms.append(Vector3.UP)
		if tube:
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _tube(pts, ws, int(o.get("sides", 5))))
		else:
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _ribbon(pts, ws, nrms))
	upd.call(0.0)
	var tw = mi.create_tween()
	tw.tween_method(upd, 0.0, 1.0, maxf(dur, 0.05))
	tw.tween_callback(mi.queue_free)
	return mi


## İki uç arasında sarkan eğri (iplik / tel): sag sarkma, n nokta
static func _sag_pts(a: Vector3, b: Vector3, sag: float, n := 10) -> Array:
	var out: Array = []
	for i in n:
		var u = float(i) / float(n - 1)
		out.append(a.lerp(b, u) - Vector3.UP * sin(u * PI) * sag)
	return out


static func _bez(a: Vector3, c1: Vector3, c2: Vector3, b: Vector3, n: int) -> Array:
	var out: Array = []
	for i in n:
		var u = float(i) / float(n - 1)
		var iu = 1.0 - u
		out.append(a * iu * iu * iu + c1 * 3.0 * iu * iu * u + c2 * 3.0 * iu * u * u + b * u * u * u)
	return out


## Cel katı + kontur (MB modelleri: kaya çene, örümcek, kök, uç)
static func _cel(mesh: Mesh, ow: float, prm := {}) -> Node3D:
	var root = Node3D.new()
	var m = _mi(mesh, _cel_mat())
	_prm(m, prm)
	root.add_child(m)
	if ow > 0.0:
		var ol = _mi(mesh, _outline_mat())
		var q = {"ow": ow}
		for k in ["nf", "seed", "alpha"]:
			if prm.has(k):
				q[k] = prm[k]
		if prm.has("oc"):
			q["oc"] = prm["oc"]
		_prm(ol, q)
		root.add_child(ol)
	return root


# ================================================================== Fūma yapı taşları
## Oyunun kendi Fūma shuriken modeli (CharacterModel._fuma): göbek halkası + dört kavisli orak bıçak
static func _fuma_mesh() -> ArrayMesh:
	if not _cache.has("mesh:fuma"):
		var b = MB.new()
		CharacterModel._fuma(b, false)
		_cache["mesh:fuma"] = b.build(null)
	return _cache["mesh:fuma"]


## Dev Fūma düğümü: yatay (XZ) düzlemde, göbek merkezde; size 1 ≈ 2.8 m çap. blur: dönme bulanıklığı diski
static func _fuma(size: float, blur := true) -> Node3D:
	var root = Node3D.new()
	var piv = Node3D.new()
	piv.rotation.x = -PI * 0.5
	piv.position = Vector3(0, -0.09, 0)
	root.add_child(piv)
	var body = _cel(_fuma_mesh(), 0.012, {"metal": 1.0, "nf": 1.2})
	piv.add_child(body)
	if blur:
		var d = _seal_quad(Vector2(1.3, 1.3), {"kind": 10.0, "c1": Color(0.95, 0.96, 1.0), "c2": Color(0.45, 0.46, 0.5), "nf": 1.5, "seed": randf() * 4.0})
		d.rotation.x = -PI * 0.5
		root.add_child(d)
	root.scale = Vector3.ONE * size * 2.4
	return root


## Uçuşan shurikenin ardında kalan yatay kesik izi (son konumlardan şerit)
static func _wake(pj: PathJutsu, src: Node3D, dur: float, w: float, c2: Color, keep := 12) -> void:
	var trail: Array = []
	var srcw = weakref(src)
	var fn = func() -> Array:
		var s = srcw.get_ref()
		if s != null and is_instance_valid(s) and s.is_inside_tree():
			trail.append(s.global_position)
		elif not trail.is_empty():
			trail.remove_at(0)
		while trail.size() > keep:
			trail.remove_at(0)
		return trail.duplicate()
	var wf = func(u: float) -> float:
		return w * (0.2 + 0.8 * u)
	_live_strand(pj, _glow_mat(), {"c1": Color(1, 1, 1), "c2": c2, "c3": c2.darkened(0.45), "alpha": 0.75, "fade": 1.0, "nf": 2.0}, fn, dur,
		{"w": wf, "flat": true})


# ================================================================== Fūma: Senpū Fūsha
## Dev shuriken yatay döner: ardında yatay kesik izi bırakarak kavisle gider ve döner; çarpınca çelik kıvılcımı + kesik
## yıldızı; ele dönüşte kısa parıltı
static func fuma_senpu_fusha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "fuma_senpu_fusha"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.5)
	var cw = weakref(c)
	var sh = _fuma(1.2)
	var start: Vector3 = c.global_position + Vector3.UP * 1.2 + d * 0.8
	pj.scene_add(sh, start)
	var end: Vector3 = (tt.global_position + Vector3.UP * 1.0) if tt else start + d * 16.0
	var sd = d.cross(Vector3.UP).normalized()
	var hits = {}
	Sfx.play("whoosh", start, 0.9)
	_wake(pj, sh, 1.7, 1.6, Color(0.78, 0.82, 0.9))
	# atış anında elden açılan yarım ay hava kesiği
	_pop(pj, start + d * 0.6, 1.4, {"kind": 18.0, "c1": Color(1, 1, 1), "nf": 1.0}, 0.25, 1.6)
	var tick = func(_i, k):
		var cc = cw.get_ref()
		if not is_instance_valid(sh):
			return
		var a = k * PI
		var mid: Vector3 = start.lerp(end, sin(a)) + sd * sin(a * 2.0) * 3.0
		sh.global_position = mid
		sh.rotate_y(0.9)
		if cc == null or not pj.live(cc):
			return
		var leg = 0 if k < 0.5 else 1
		for e in pj.enemies_near(cc, mid, 1.6):
			var key = "%d_%d" % [e.get_instance_id(), leg]
			if hits.has(key):
				continue
			hits[key] = true
			_steel_sparks(pj, mid, 16)
			_pop(pj, mid, 1.1, {"kind": 13.0, "c1": Color(1, 1, 0.95), "c2": Color(0.75, 0.8, 0.9), "c3": INK, "seed": randf() * 9.0, "nf": 1.0}, 0.18)
			Sfx.play("kunai", mid, 0.8)
			e.take_hit(pj.inf(cc, id, 1.0, {"knock": 6.0, "kind": "heavy", "bleed": 2.0, "hitstop": 0.06}))
	var done = func():
		if is_instance_valid(sh):
			var cc2 = cw.get_ref()
			if cc2 != null and is_instance_valid(cc2):
				_burst(pj, pj.hand_pos(cc2), {"n": 6, "mesh": "streak", "align": true, "v0": 2.0, "v1": 4.0, "g": 0.0, "life": 0.25, "spread": 180.0,
					"s0": 0.12, "s1": 0.2, "add": true, "cols": [Color(1, 1, 1), Color(0.7, 0.8, 1.0, 0)]})
			sh.queue_free()
	pj.every(1.4, 1.0 / 30.0, tick, done)


# ================================================================== Fūma: Shuriken Rōheki
## Sekiz shuriken hedefin çevresinde döner, halka daralır: aralarında akan çelik parıltı şeridi bir kesik kafesi çizer,
## yerde çizik halkası belirir; kapanışta çelik çatırtısı yıldızı, kırık çelik parçaları ve yerde ışınsal oyuk kalır
static func fuma_shuriken_roheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "fuma_shuriken_roheki"
	var tt = pj.tg(c, t, 18.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0) + Vector3.UP * 1.0
	var shs = []
	for k in 8:
		var s = _fuma(0.55)
		pj.scene_add(s, at)
		shs.append(s)
	Sfx.play("whoosh", at, 1.1)
	var scar = _decal(pj, at, 6.6, {"kind": 8.0, "c3": Color(0.16, 0.12, 0.1), "reveal": 0.0, "seed": randf() * 7.0, "alpha": 0.8})
	_tp(scar, "reveal", 0.0, 1.0, 1.6)
	_fade_free(scar, 3.2, 1.0)
	var cage_fn = func() -> Array:
		var pts: Array = []
		for s in shs:
			if is_instance_valid(s):
				pts.append(s.global_position)
		if pts.size() > 2:
			pts.append(pts[0])
		return pts
	var cage = _live_strand(pj, _glow_mat(), {"c1": Color(1, 1, 1), "c2": Color(0.7, 0.8, 0.95), "c3": Color(0.25, 0.28, 0.4), "pat": 1.0, "spd": 4.0, "alpha": 0.8, "nf": 2.0},
		cage_fn, 1.8, {"w": 0.07})
	var tick = func(i, k):
		var cc = cw.get_ref()
		var r = lerpf(3.0, 0.4, k * k)
		for q in shs.size():
			var s = shs[q]
			if is_instance_valid(s):
				var a = q * TAU / 8.0 + k * 9.0
				s.global_position = at + Vector3(cos(a) * r, sin(a * 2.0 + k * 5.0) * 0.4, sin(a) * r)
				s.rotate_y(0.7)
		if i % 9 == 0 and cc != null and pj.live(cc):
			for e in pj.enemies_near(cc, at, r + 0.5):
				_steel_sparks(pj, e.global_position + Vector3.UP, 6, 0.7)
				e.take_hit(pj.inf(cc, id, 0.25, {"knock": 0.0, "kind": "light", "bleed": 1.0, "hitstop": 0.0}))
				pj.st(e, "slow", 0.4)
	var done = func():
		var cc = cw.get_ref()
		for s in shs:
			if is_instance_valid(s):
				s.queue_free()
		if is_instance_valid(cage):
			cage.queue_free()
		_pop(pj, at, 2.6, {"kind": 13.0, "c1": Color(1, 1, 1), "c2": Color(0.72, 0.78, 0.92), "c3": INK, "seed": randf() * 9.0, "nf": 1.2}, 0.28)
		_burst(pj, at, {"n": 16, "mesh": "chip", "v0": 4.0, "v1": 8.0, "g": 14.0, "life": 0.8, "spread": 180.0, "s0": 0.05, "s1": 0.11,
			"cols": [STEEL_L, Color(0.5, 0.52, 0.56), Color(0.3, 0.3, 0.33, 0)]})
		_steel_sparks(pj, at, 20, 1.2)
		var gouge = _decal(pj, at, 3.4, {"kind": 8.0, "c3": Color(0.1, 0.08, 0.07), "seed": randf() * 5.0, "reveal": 1.0})
		_fade_free(gouge, 2.5, 1.0)
		Sfx.play("clink", at, 0.8)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 1.6):
			e.take_hit(pj.inf(cc, id, 1.2, {"knock": 4.0, "launch": 3.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1}))
	pj.every(1.8, 1.0 / 30.0, tick, done)


# ================================================================== Fūma: Kazaguruma Rendan
## Dört shuriken yelpaze gibi açılarak fırlar: elden dört yay çizgisi açılır, her shurikenin ardında ince mavi-çelik rüzgâr
## kılçıkları; çarpınca çelik kıvılcımı + kısa kesik yıldızı
static func fuma_kazaguruma_rendan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "fuma_kazaguruma_rendan"
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	var cw = weakref(c)
	for k in 4:
		var throw_one = func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			pj.anim(cc, "throw", 2.4)
			var from: Vector3 = cc.global_position + Vector3.UP * 1.2 + d * 0.6
			var dir: Vector3 = pj.aim_at(cc, tt, from).rotated(Vector3.UP, (k - 1.5) * 0.22)
			var sh = _fuma(0.75)
			var on_hit = func(p, _hn):
				_steel_sparks(pj, p, 12)
				_pop(pj, p, 0.9, {"kind": 13.0, "c1": Color(1, 1, 1), "c2": Color(0.6, 0.75, 0.95), "c3": INK, "seed": randf() * 9.0, "nf": 1.0}, 0.16)
				Sfx.play("clink", p, 1.0)
			var pr = pj.shot(cc, from, dir, 26.0, sh, pj.inf(cc, id, 0.55, {"knock": 3.0, "kind": "heavy", "bleed": 2.0, "hitstop": 0.04}), tt, false, 1.4, on_hit)
			pr.homing_turn = 2.2
			pr.radius = 0.7
			pr.spin = Vector3(0, 18.0, 0)
			# yelpaze açılış yayı: elden atış yönüne kısa kıvrık çizgi
			var arc: Array = []
			var side = dir.cross(Vector3.UP).normalized() * (k - 1.5)
			for q in 8:
				var u = float(q) / 7.0
				arc.append(from + dir * (0.3 + u * 2.2) + side * sin(u * PI) * 0.35)
			var arc_mi = _mi(_mesh([_ribbon(arc, [0.02, 0.06, 0.1, 0.12, 0.12, 0.1, 0.06, 0.02])]), _glow_mat())
			_prm(arc_mi, {"c1": Color(1, 1, 1), "c2": Color(0.7, 0.85, 1.0), "c3": Color(0.3, 0.4, 0.6), "reveal": 0.0, "nf": 1.5})
			pj.scene_add(arc_mi, Vector3.ZERO)
			arc_mi.global_transform = Transform3D.IDENTITY
			_tp(arc_mi, "reveal", 0.0, 1.0, 0.12)
			_fade_free(arc_mi, 0.1, 0.2)
			# rüzgâr kılçıkları: shurikenin ardından akan ince çizgiler
			_burst(pj, from, {"one": false, "n": 14, "life": 0.3, "mesh": "streak", "align": true, "v0": 0.5, "v1": 1.5, "g": 0.0, "spread": 180.0,
				"r": 0.5, "s0": 0.25, "s1": 0.45, "add": false, "parent": sh, "cols": [Color(0.92, 0.96, 1.0, 0.9), Color(0.6, 0.72, 0.9, 0)]})
			Sfx.play("whoosh", from, 1.2 + k * 0.1)
		pj.after(k * 0.14, throw_one)


# ================================================================== Fūma: Tenrai Shuriken
## Dik göğe tekerlek gibi dönerek çıkar (dikey iz), tepede parlar; hedefin yerinde nişan gölgesi büyür; dönerek iner,
## yere yarıya kadar saplanır: ışınsal çatlak, toprak parçaları, yerde toz halkası
static func fuma_tenrai_shuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "fuma_tenrai_shuriken"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.6)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var sh = _fuma(1.4)
	var start: Vector3 = c.global_position + Vector3.UP * 1.6
	pj.scene_add(sh, start)
	sh.rotation.x = PI * 0.5   # dikey (tekerlek gibi) döner
	Sfx.play("whoosh", start, 0.9)
	var hold = {"at": pj.gp(tt.global_position if tt else c.global_position + d * 8.0), "glint": false}
	var mark = _decal(pj, hold["at"], 3.6, {"kind": 14.0, "c2": Color(0.85, 0.88, 0.95), "c3": Color(0.05, 0.05, 0.08), "reveal": 0.0, "nf": 1.5})
	var trail: Array = []
	var trail_fn = func() -> Array:
		if is_instance_valid(sh):
			trail.append(sh.global_position)
		while trail.size() > 9:
			trail.remove_at(0)
		return trail.duplicate()
	var trail_w = func(u: float) -> float:
		return 0.15 + 0.9 * u
	_live_strand(pj, _glow_mat(), {"c1": Color(1, 1, 1), "c2": Color(0.75, 0.8, 0.92), "c3": Color(0.3, 0.32, 0.45), "alpha": 0.7, "fade": 1.0, "nf": 2.0},
		trail_fn, 1.0, {"w": trail_w})
	var tick = func(_i, k):
		if not is_instance_valid(sh):
			return
		var x = tw.get_ref() if tw else null
		if x != null and is_instance_valid(x) and k < 0.6:
			hold["at"] = pj.gp(x.global_position)
		var at: Vector3 = hold["at"]
		var top = at + Vector3.UP * 16.0
		sh.global_position = start.lerp(top, k / 0.6) if k < 0.6 else top.lerp(at + Vector3.UP * 0.6, (k - 0.6) / 0.4)
		sh.rotate_object_local(Vector3.UP, 0.8)
		if is_instance_valid(mark):
			mark.global_position = at + Vector3.UP * 0.05
			mark.set_instance_shader_parameter("reveal", clampf(k * 1.3, 0.0, 1.0))
		if k >= 0.6 and not hold["glint"]:
			hold["glint"] = true
			_pop(pj, top, 2.2, {"kind": 13.0, "c1": Color(1, 1, 1), "c2": Color(0.8, 0.88, 1.0), "c3": Color(0.3, 0.35, 0.5), "seed": 3.0, "nf": 2.0}, 0.3)
	var done = func():
		var cc = cw.get_ref()
		var at: Vector3 = hold["at"]
		if is_instance_valid(mark):
			mark.queue_free()
		var cr = _decal(pj, at, 5.0, {"kind": 8.0, "c3": Color(0.12, 0.09, 0.07), "seed": randf() * 6.0, "reveal": 0.0})
		_tp(cr, "reveal", 0.0, 1.0, 0.12)
		_fade_free(cr, 3.0, 0.8)
		_clods(pj, at + Vector3.UP * 0.2, 14, 7.0)
		_burst(pj, at + Vector3.UP * 0.1, {"n": 18, "ring": 0.6, "dir": Vector3.UP, "spread": 80.0, "v0": 3.0, "v1": 6.0, "g": 2.0, "damp": 4.0,
			"radial": 6.0, "life": 0.8, "s0": 0.2, "s1": 0.4, "cols": [Color(0.78, 0.7, 0.58, 0.9), Color(0.6, 0.52, 0.42, 0)]})
		_steel_sparks(pj, at + Vector3.UP * 0.3, 18, 1.2)
		Sfx.play("clink", at, 0.6)
		pj.shake(0.35)
		if is_instance_valid(sh):
			var t2 = sh.create_tween()
			t2.tween_interval(1.2)
			t2.tween_property(sh, "scale", Vector3.ONE * 0.05, 0.3)
			t2.tween_callback(sh.queue_free)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 2.0):
			e.take_hit(pj.inf(cc, id, 2.0, {"knock": 3.0, "launch": -3.0, "kind": "heavy", "bleed": 3.0, "stun": 0.6, "hitstop": 0.12, "pierce_guard": true}))
	pj.every(1.0, 1.0 / 30.0, tick, done)


# ================================================================== Fūma: Ito Fūsha
## Shurikenin göbeğine bağlı çelik tel: shuriken hedefin çevresinde üç tur atarken tel gerçekten hedefe dolanır (telin yolu
## shurikenin geçtiği noktalardan); sonunda dolanmış sarmal tel bedende sıkışır, kesik kıvılcımı ve kan damlaları
static func fuma_ito_fusha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "fuma_ito_fusha"
	var tt = pj.tg(c, t, 18.0)
	pj._face(c, tt)
	pj.anim(c, "throw", 1.6)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var sh = _fuma(0.7)
	pj.scene_add(sh, pj.hand_pos(c))
	var coil: Array = []
	var wire_fn = func() -> Array:
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc) or not is_instance_valid(sh):
			return []
		var pts: Array = [pj.hand_pos(cc)]
		pts.append_array(coil)
		pts.append(sh.global_position)
		return pts
	var wire = _live_strand(pj, _cel_mat(), {"tint": STEEL_L, "metal": 1.0, "nf": 1.0}, wire_fn, 1.05, {"tube": true, "w": 0.014, "sides": 4})
	var tick = func(i, k):
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if not is_instance_valid(sh) or cc == null or x == null or not is_instance_valid(x):
			return
		var a = k * TAU * 3.0
		var r = lerpf(2.0, 0.6, k)
		var p: Vector3 = x.global_position + Vector3(cos(a) * r, 1.0 + sin(k * 6.0) * 0.3, sin(a) * r)
		sh.global_position = pj.hand_pos(cc).lerp(p, minf(1.0, k * 4.0))
		sh.rotate_y(0.8)
		if k > 0.25 and i % 3 == 0:
			coil.append(sh.global_position)
	var done = func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if is_instance_valid(sh):
			sh.queue_free()
		if is_instance_valid(wire):
			wire.queue_free()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		# rakibe dolanmış sarmal tel: üç tur, sıkışarak daralır
		var hp: Array = []
		var hr: Array = []
		for q in 46:
			var u = float(q) / 45.0
			var a = u * TAU * 3.0
			hp.append(Vector3(cos(a) * 0.42, 0.6 + u * 0.75, sin(a) * 0.42))
			hr.append(0.016)
		var helix = _cel(_mesh([_tube(hp, hr, 4)]), 0.008, {"tint": STEEL_L, "metal": 1.0, "nf": 1.0})
		pj.attach(x, helix, 1.5)
		var s0: Vector3 = helix.scale
		helix.scale = s0 * Vector3(1.5, 1.0, 1.5)
		var ht = helix.create_tween()
		ht.tween_property(helix, "scale", s0 * Vector3(0.85, 1.0, 0.85), 0.12).set_ease(Tween.EASE_IN)
		var cpos: Vector3 = x.global_position + Vector3.UP * 1.0
		_steel_sparks(pj, cpos, 20, 1.0)
		_burst(pj, cpos, {"n": 10, "v0": 1.5, "v1": 3.5, "g": 12.0, "life": 0.6, "spread": 120.0, "r": 0.35, "s0": 0.04, "s1": 0.08,
			"cols": [Color(0.75, 0.05, 0.05), Color(0.45, 0.0, 0.0, 0)]})
		pj.st(x, "bind", 1.5)
		Sfx.play("clink", x.global_position, 1.3)
		x.take_hit(pj.inf(cc, id, 1.4, {"knock": 0.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.08, "pierce_guard": true}))
	pj.every(1.0, 1.0 / 30.0, tick, done)


# ================================================================== Fūma: Bakufū Shuriken
## Kollarına patlayıcı kâğıt sarılı shuriken: kâğıtlar uçuşta çırpınır, fitil kıvılcımı saçar; saplanınca shuriken yerinde
## kalır, kâğıtlar kızarıp yanarak delinir; sonra cel ateş topu patlaması, şok halkası, yanık iz, yanan kâğıt kırıntıları
static func _tagged_fuma(size: float, blur := true) -> Node3D:
	var sh = _fuma(size, blur)
	var tags = Node3D.new()
	tags.name = "tags"
	sh.add_child(tags)
	for k in 4:
		var a = k * PI * 0.5 + 0.35
		var tag = _seal_quad(Vector2(0.11, 0.24), {"kind": 15.0, "c1": Color(0.93, 0.89, 0.76), "c2": Color(0.72, 0.1, 0.08), "c3": INK, "seed": k * 3.0,
			"flap": 0.03, "nf": 1.0})
		tag.position = Vector3(sin(a) * 0.3, 0.03, cos(a) * 0.3)
		tag.rotation = Vector3(-PI * 0.5, a, 0)
		tags.add_child(tag)
	return sh


static func fuma_bakufu_shuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "fuma_bakufu_shuriken"
	var tt = pj.tg(c, t, 24.0)
	pj._face(c, tt)
	pj.anim(c, "throw", 1.6)
	var cw = weakref(c)
	var from: Vector3 = pj.hand_pos(c)
	var sh = _tagged_fuma(0.9)
	_burst(pj, from, {"one": false, "n": 18, "life": 0.35, "mesh": "streak", "align": true, "v0": 1.0, "v1": 3.0, "g": 4.0, "spread": 180.0,
		"r": 0.4, "s0": 0.1, "s1": 0.18, "add": true, "parent": sh, "cols": [Color(1, 0.95, 0.6), Color(1, 0.55, 0.15), Color(0.8, 0.2, 0.05, 0)]})
	var on_hit = func(p, _hn):
		# saplanan shuriken + kızaran kâğıtlar
		var stuck = _tagged_fuma(0.9, false)
		pj.scene_add(stuck, p)
		stuck.rotation = Vector3(0.9, randf() * TAU, 0.3)
		_tp(stuck.get_node("tags"), "glow", 0.0, 1.0, 0.45)
		_burst(pj, p, {"n": 10, "mesh": "streak", "align": true, "v0": 1.0, "v1": 3.0, "g": 6.0, "life": 0.45, "spread": 180.0, "s0": 0.1, "s1": 0.16,
			"add": true, "cols": [Color(1, 0.9, 0.5), Color(1, 0.4, 0.1, 0)]})
		var boom = func():
			if is_instance_valid(stuck):
				stuck.queue_free()
			_blast(pj, p, 2.6)
			Sfx.play("boom", p, 0.9)
			pj.shake(0.35)
			var c2 = cw.get_ref()
			if c2 != null and pj.live(c2):
				for e in pj.enemies_near(c2, p, 3.2):
					var v: Vector3 = e.global_position - p
					v.y = 0
					e.take_hit(pj.inf(c2, id, 1.4, {"knock": 12.0, "launch": 4.0, "kind": "heavy", "burn": 2.0, "element": "katon", "hitstop": 0.08, "dir": v.normalized() if v.length() > 0.1 else Vector3.UP}))
		pj.after(0.45, boom)
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 28.0, sh, pj.inf(c, id, 0.6, {"knock": 2.0, "kind": "heavy", "hitstop": 0.04}), tt, false, 1.4, on_hit)
	pr.radius = 0.7
	pr.spin = Vector3(0, 18.0, 0)
	Sfx.play("whoosh", from, 1.0)


## Patlayıcı kâğıt patlaması: cel ateş küresi (kontur) büyüyüp kararır ve çözülür, şok halkası, kıvılcım, yanık iz,
## yanan kâğıt kırıntıları, kısa ışık
static func _blast(pj: PathJutsu, p: Vector3, r: float) -> void:
	var sm: SphereMesh
	if _cache.has("mesh:blast"):
		sm = _cache["mesh:blast"]
	else:
		sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 24
		sm.rings = 12
		_cache["mesh:blast"] = sm
	var root = Node3D.new()
	pj.scene_add(root, p + Vector3.UP * 0.3)
	var sd = randf() * 10.0
	for q in 3:
		var off = Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.5), randf_range(-0.4, 0.4)) * r * 0.4 if q > 0 else Vector3.ZERO
		var ball = _mi(sm, _blast_mat())
		_prm(ball, {"seed": sd + q * 2.0, "nf": 1.8})
		var ol = _mi(sm, _outline_mat())
		_prm(ol, {"ow": 0.06, "oc": Color(0.25, 0.06, 0.02), "nf": 1.8})
		var holder = Node3D.new()
		holder.add_child(ball)
		holder.add_child(ol)
		root.add_child(holder)
		holder.position = off
		holder.scale = Vector3.ONE * 0.2
		var sz = r * (1.0 if q == 0 else 0.65)
		var tw = holder.create_tween()
		tw.tween_property(holder, "scale", Vector3.ONE * sz, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(holder, "position", off + Vector3.UP * r * 0.35, 0.6)
		var pt = func(v: float):
			if is_instance_valid(ball):
				ball.set_instance_shader_parameter("prog", v)
			if is_instance_valid(ol):
				ol.set_instance_shader_parameter("alpha", 1.0 - v)
		var tp = holder.create_tween()
		tp.tween_method(pt, 0.0, 1.0, 0.8)
	pj.free_after(0.85, root)
	var li = OmniLight3D.new()
	li.light_color = Color(1.0, 0.6, 0.25)
	li.light_energy = 4.0
	li.omni_range = r * 3.0
	pj.scene_add(li, p + Vector3.UP)
	var lt = li.create_tween()
	lt.tween_property(li, "light_energy", 0.0, 0.4)
	lt.tween_callback(li.queue_free)
	_ground_ring(pj, p, r * 1.6, Color(1, 0.9, 0.6), Color(1, 0.6, 0.2), Color(0.5, 0.15, 0.05), 0.4)
	_steel_sparks(pj, p + Vector3.UP * 0.5, 16, 1.4)
	_burst(pj, p + Vector3.UP * 0.6, {"n": 14, "mesh": "flake", "v0": 3.0, "v1": 7.0, "g": 3.0, "damp": 1.5, "life": 1.6, "spread": 150.0,
		"s0": 0.06, "s1": 0.12, "cols": [Color(1, 0.7, 0.3), Color(0.25, 0.12, 0.08), Color(0.1, 0.08, 0.07, 0)]})
	var sc = _decal(pj, p, r * 1.4, {"kind": 9.0, "c2": Color(1.0, 0.45, 0.1), "c3": Color(0.09, 0.07, 0.06), "glow": 1.0, "seed": sd})
	_tp(sc, "glow", 1.0, 0.0, 1.5, 0.3)
	_fade_free(sc, 3.0, 1.0)


# ================================================================== Fūma: Kaeshi Fūsha
## Yere yarı saplı üç shuriken (dibinde çatlak), her birinden ele uzanan hafif sarkık çelik tel; tetiklenince teller gerilir,
## shurikenler toprağı koparıp yerden fırlar (kesek), rakibe kapanır; yerde oyuk kalır
static func fuma_kaeshi_fusha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "fuma_kaeshi_fusha"
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.4)
	var cw = weakref(c)
	var spots = []
	var wires = []
	var fired = {"v": false}
	for k in 3:
		var p: Vector3 = pj.gp(c.global_position + d * (3.0 + k * 1.5) + d.cross(Vector3.UP) * (k - 1) * 1.8)
		var sh = _fuma(0.6, false)
		pj.scene_add(sh, p + Vector3.UP * 0.25)
		sh.rotation = Vector3(PI * 0.5, randf() * TAU, 0.2)   # yere yarı saplı
		spots.append([sh, p])
		var base = _decal(pj, p, 1.6, {"kind": 8.0, "c3": Color(0.15, 0.11, 0.08), "seed": k * 2.3, "reveal": 1.0, "alpha": 0.85})
		pj.free_after(6.5, base)
		_clods(pj, p, 6, 3.0, 0.6)
		var shw = weakref(sh)
		var wfn = func() -> Array:
			var cc = cw.get_ref()
			var s2 = shw.get_ref()
			if cc == null or not is_instance_valid(cc) or s2 == null or not is_instance_valid(s2):
				return []
			return _sag_pts(pj.hand_pos(cc), s2.global_position, 0.0 if fired["v"] else 0.35, 8)
		wires.append(_live_strand(pj, _cel_mat(), {"tint": STEEL_L, "metal": 1.0, "nf": 1.0}, wfn, 6.2, {"tube": true, "w": 0.012, "sides": 4}))
	Sfx.play("clink", c.global_position, 0.9)
	var tick = func(_i, _k):
		var cc = cw.get_ref()
		if fired["v"] or cc == null or not pj.live(cc):
			return
		var foe = null
		for s in spots:
			var near = pj.enemies_near(cc, s[1], 2.6)
			if not near.is_empty():
				foe = near[0]
				break
		if foe == null:
			return
		fired["v"] = true
		Sfx.play("whoosh", foe.global_position, 1.3)
		for s in spots:
			var sh: Node3D = s[0]
			if not is_instance_valid(sh):
				continue
			_clods(pj, s[1] + Vector3.UP * 0.1, 10, 6.0, 0.8)
			var gouge = _decal(pj, s[1], 1.2, {"kind": 19.0, "c2": EARTH_C, "c3": EARTH_D, "seed": randf() * 5.0})
			_fade_free(gouge, 2.0, 0.8)
			var p0: Vector3 = sh.global_position
			var fw = weakref(foe)
			var mv = func(u: float):
				var x = fw.get_ref()
				if is_instance_valid(sh) and x != null and is_instance_valid(x):
					sh.global_position = p0.lerp(x.global_position + Vector3.UP, u) + Vector3.UP * sin(u * PI) * 1.2
					sh.rotate_y(0.6)
			var tw2 = sh.create_tween()
			tw2.tween_method(mv, 0.0, 1.0, 0.25)
			tw2.tween_callback(sh.queue_free)
		var fw2 = weakref(foe)
		var strike = func():
			for w in wires:
				if is_instance_valid(w):
					w.queue_free()
			var c2 = cw.get_ref()
			var f2 = fw2.get_ref()
			if c2 != null and pj.live(c2) and f2 != null and pj.live(f2):
				var hp: Vector3 = f2.global_position + Vector3.UP
				_steel_sparks(pj, hp, 22, 1.2)
				_pop(pj, hp, 1.6, {"kind": 13.0, "c1": Color(1, 1, 1), "c2": Color(0.75, 0.8, 0.92), "c3": INK, "seed": randf() * 9.0, "nf": 1.0}, 0.22)
				f2.take_hit(pj.inf(c2, id, 1.8, {"knock": 6.0, "launch": 4.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1, "pierce_guard": true}))
		pj.after(0.25, strike)
	var done = func():
		if not fired["v"]:
			for s in spots:
				if is_instance_valid(s[0]):
					s[0].queue_free()
			for w in wires:
				if is_instance_valid(w):
					w.queue_free()
	pj.every(6.0, 0.1, tick, done)


# ================================================================== Tsuchigumo yapı taşları
## Doğa enerjisi zerresi: uzaktan hedef noktaya kıvrılarak akan altın kılçık
static func _mote_to(pj: PathJutsu, from: Vector3, to_fn: Callable, dur: float, col: Color) -> void:
	var mk = "mat:mote_" + col.to_html()
	if not _cache.has(mk):
		var sm = StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = col
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_cache[mk] = sm
	var m = _mi(_pmesh("streak"), _cache[mk])
	pj.scene_add(m, from)
	m.scale = Vector3(1.6, 3.0, 1.6) * 0.12
	var sway = Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1))
	var mv = func(u: float):
		if not is_instance_valid(m):
			return
		var to: Vector3 = to_fn.call()
		var p = from.lerp(to, u * u) + sway * sin(u * PI) * 0.8
		var dv = p - m.global_position
		m.global_position = p
		if dv.length() > 0.001:
			m.global_basis = Basis.looking_at(dv.normalized(), Vector3.UP if absf(dv.normalized().y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.6, 3.0 * (1.0 - u * 0.6), 1.6) * 0.12)
	var tw = m.create_tween()
	tw.tween_method(mv, 0.0, 1.0, dur)
	tw.tween_callback(m.queue_free)


## Örümcek modeli (iki bacak pozu: koşarken sırayla değişir): kara gövde, kırmızı kum saati deseni, sekiz eklemli bacak
static func _spider_mesh(pose: int) -> ArrayMesh:
	var key = "mesh:spider%d" % pose
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var body = Color(0.12, 0.1, 0.09)
	b.add("sphere", Vector3(0, 0.12, 0.1), Vector3(0.2, 0.15, 0.24), body, Vector3.ZERO, 8)
	b.add("sphere", Vector3(0, 0.1, -0.08), Vector3(0.12, 0.1, 0.13), body.lightened(0.08), Vector3.ZERO, 6)
	b.add("cone", Vector3(0, 0.2, 0.08), Vector3(0.05, 0.05, 0.03), Color(0.85, 0.12, 0.08), Vector3(0, 0, 180), 4)
	b.add("cone", Vector3(0, 0.2, 0.13), Vector3(0.05, 0.05, 0.03), Color(0.85, 0.12, 0.08), Vector3.ZERO, 4)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.03, 0.12, -0.14), Vector3(0.025, 0.025, 0.025), Color(0.9, 0.2, 0.15), Vector3.ZERO, 4)
	for q in 8:
		var s = -1.0 if q < 4 else 1.0
		var row = q % 4
		var ph = 1.0 if (row + pose + (0 if s < 0 else 1)) % 2 == 0 else -1.0
		var z = (row - 1.5) * 0.06 - 0.06
		var yaw = (row - 1.5) * 22.0 + ph * 10.0
		var root = Vector3(s * 0.05, 0.1, z)
		var knee = root + Basis(Vector3.UP, deg_to_rad(-s * yaw)) * Vector3(s * 0.12, 0.09, 0)
		var foot = root + Basis(Vector3.UP, deg_to_rad(-s * yaw)) * Vector3(s * 0.24, -0.1, 0)
		for seg in [[root, knee], [knee, foot]]:
			var a: Vector3 = seg[0]
			var e: Vector3 = seg[1]
			var mid = (a + e) * 0.5
			var dv = e - a
			var bs = Basis.looking_at(dv.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			b.add_xf("cyl", Transform3D(bs * Basis.from_scale(Vector3(0.022, dv.length(), 0.022)), mid), body.lightened(0.04), 4)
	var am = b.build(null)
	_cache[key] = am
	return am


## Toprak çene (Tsuchigumo Ana): kalın kaya levha + üstte sivri dişler
static func _jaw_mesh() -> ArrayMesh:
	if _cache.has("mesh:jaw"):
		return _cache["mesh:jaw"]
	var b = MB.new()
	b.add("box", Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.35), EARTH_C, Vector3(0, 0, 2.0))
	b.add("box", Vector3(0.1, 0.2, 0.06), Vector3(1.75, 0.4, 0.4), EARTH_C.darkened(0.15), Vector3(0, 0, -3.0))
	for q in 5:
		b.add("cone", Vector3((q - 2.0) * 0.32, 1.02, 0.04), Vector3(0.2, 0.34, 0.18), EARTH_C.lightened(0.12), Vector3(0, 0, (q - 2.0) * 4.0), 5)
	var am = b.build(null)
	_cache["mesh:jaw"] = am
	return am


## Kaya sütunu (Shizen Kōsoku): MB pürüzlü kaya
static func _crag_mesh(v: int) -> ArrayMesh:
	var key = "mesh:crag%d" % v
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	b.add_grad("crag", Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.5), EARTH_C.lightened(0.15), EARTH_D, Vector3.ZERO, v)
	var am = b.build(null)
	_cache[key] = am
	return am


static func _silk_prm() -> Dictionary:
	return {"tint": SILK, "nf": 1.0}


# ================================================================== Tsuchigumo: Tenchi Kaibyaku
## Ref: kullanıcının ayakları altında lav kırmızısı yazılı formül çemberi (iç içe halkalar, yazı kuşakları, dışa dönük
## dişler), çemberin kenarından yukarı süzülen turuncu ışık çizgileri, sırtta Tsuchigumo mührü. Dört saniye boyunca çevreden
## altın doğa enerjisi zerreleri kullanıcıya akar, yerdeki taş kırıntıları havalanır. Bozulursa çember kararır; başarıda
## yerde genişleyen altın halka + yukarı fışkıran zerreler, çember yavaşça söner.
static func tsuchigumo_tenchi_kaibyaku(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 4.0)
	pj.anim(c, "seal", 0.6)
	var hp0 = float(c.get("hp"))
	var at = pj.gp(c.global_position)
	var circ = _decal(pj, at, 7.0, {"kind": 0.0, "c1": Color(1.0, 0.82, 0.35), "c2": Color(0.9, 0.18, 0.06), "reveal": 0.0, "seed": randf() * 3.0, "nf": 1.2})
	_tp(circ, "reveal", 0.0, 1.0, 0.8)
	# kenardan yükselen ışık çizgileri (ref: dikey turuncu ışınlar)
	var rays = Node3D.new()
	pj.scene_add(rays, at)
	for q in 16:
		var a = q * TAU / 16.0 + randf() * 0.2
		var h = randf_range(1.4, 3.0)
		var pts: Array = [Vector3(cos(a) * 3.2, 0.0, sin(a) * 3.2), Vector3(cos(a) * 3.2, h, sin(a) * 3.2)]
		var ray = _mi(_mesh([_ribbon(pts, [0.22, 0.1])]), _glow_mat())
		_prm(ray, {"c1": Color(1.0, 0.9, 0.55), "c2": Color(1.0, 0.45, 0.12), "c3": Color(0.75, 0.12, 0.05), "alpha": 0.55, "fade": 0.0, "reveal": 0.0,
			"pat": 1.0, "spd": 1.5, "seed": q * 0.7, "nf": 1.5})
		rays.add_child(ray)
		_tp(ray, "reveal", 0.0, 1.0, 0.6, 0.3 + q * 0.03)
	# sırt mührü: kullanıcının gerçek sırtında
	var back = _seal_quad(Vector2(0.42, 0.42), {"kind": 17.0, "c1": Color(1.0, 0.7, 0.3), "c2": Color(1.0, 0.4, 0.1), "c3": INK, "reveal": 0.0, "glow": 0.0, "nf": 1.0})
	_stick(pj, c, back, 4.6, "Chest", 0.17, true, 0.05)
	_tp(back, "reveal", 0.0, 1.0, 0.4)
	_tp(back, "glow", 0.0, 1.0, 3.6, 0.4)
	# havalanan taş kırıntıları
	var pebbles = _burst(pj, at, {"one": false, "n": 22, "life": 2.2, "mesh": "chip", "ring": 2.6, "ring_in": 0.6, "v0": 0.4, "v1": 1.0, "g": -0.6,
		"spread": 15.0, "s0": 0.06, "s1": 0.14, "cols": [EARTH_C.lightened(0.1), EARTH_C, Color(EARTH_C.r, EARTH_C.g, EARTH_C.b, 0)]})
	pj.free_after(4.8, pebbles)
	var cw = weakref(c)
	var chest_fn = func() -> Vector3:
		var cc = cw.get_ref()
		return cc.global_position + Vector3.UP * 1.1 if cc != null and is_instance_valid(cc) else at + Vector3.UP
	var tick = func(i, _k):
		if not pj.live(c):
			return
		for q in 2:
			var a = randf() * TAU
			var p = at + Vector3(cos(a), 0.1, sin(a)) * randf_range(2.0, 5.0)
			_mote_to(pj, p, chest_fn, randf_range(0.6, 0.9), Color(1.0, 0.75, 0.3) if q == 0 else Color(1.0, 0.92, 0.55))
		if i % 6 == 0 and pebbles != null and is_instance_valid(pebbles):
			pebbles.emitting = pj.live(c)
	var done = func():
		if is_instance_valid(pebbles):
			pebbles.emitting = false
		if not pj.live(c):
			_fade_free(circ, 0.0, 0.3)
			_fade_free(rays, 0.0, 0.3)
			return
		if float(c.get("hp")) < hp0 - 1.0:
			if c is Player:
				Hud.msg("Toplama bozuldu — vuruldun.", Color(1, 0.6, 0.45))
			# bozulan çember: kararır, hızla söner
			_all(circ, "c1", Color(0.35, 0.1, 0.06))
			_fade_free(circ, 0.1, 0.4)
			_fade_free(rays, 0.0, 0.25)
			_fade_free(back, 0.0, 0.3)
			return
		c.set_meta("dohatsuten_until", Time.get_ticks_msec() / 1000.0 + 60.0)
		_ground_ring(pj, at, 6.0, Color(1.0, 0.95, 0.65), Color(1.0, 0.7, 0.25), Color(0.6, 0.25, 0.05), 0.5)
		_burst(pj, at + Vector3.UP * 0.3, {"n": 36, "ring": 1.2, "ring_in": 0.2, "dir": Vector3.UP, "spread": 12.0, "v0": 5.0, "v1": 10.0, "g": -1.0,
			"damp": 2.0, "life": 1.1, "mesh": "streak", "align": true, "add": true, "s0": 0.3, "s1": 0.6,
			"cols": [Color(1.0, 0.95, 0.7), Color(1.0, 0.7, 0.25), Color(1.0, 0.4, 0.1, 0)]})
		_fade_free(circ, 0.8, 1.2)
		_fade_free(rays, 0.3, 0.8)
		if c is Player:
			Hud.msg("Doğa enerjisi toplandı: Dohatsuten 60 sn hazır.", Color(1.0, 0.85, 0.5), 5.0)
	pj.every(4.0, 0.12, tick, done)
	Sfx.play("wind", c.global_position, 0.6)


# ================================================================== Tsuchigumo: Kumo Ito Tsuri
## Avuçtan ipek tel: önce sarkık uçar, rakibin göğsüne ağ lekesiyle yapışır, çekişte gerilip titrer; çekilen rakibin
## ayağından toz izi; diz darbesinde beyaz darbe yıldızı + ışınsal hız çizgileri + toz
static func tsuchigumo_kumo_ito_tsuri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "tsuchigumo_kumo_ito_tsuri"
	var tt = pj.tg(c, t, 18.0)
	pj._face(c, tt)
	pj.anim(c, "throw", 1.6)
	if tt == null:
		return
	var nk = pj._tg_nature(c)
	var cw = weakref(c)
	var tw = weakref(tt)
	var t0 = Time.get_ticks_msec()
	var thread_fn = func() -> Array:
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not is_instance_valid(cc) or not is_instance_valid(x):
			return []
		var a: Vector3 = pj.hand_pos(cc)
		var b: Vector3 = x.global_position + Vector3.UP * 1.1
		var el = (Time.get_ticks_msec() - t0) / 1000.0
		var pts = _sag_pts(a, b, maxf(0.0, 0.5 - el * 2.5), 12)
		for i in pts.size():
			var u = float(i) / float(pts.size() - 1)
			pts[i] += Vector3.UP * sin(u * PI * 3.0 + el * 40.0) * 0.04 * sin(u * PI)   # gerili telin titreşimi
		return pts
	_live_strand(pj, _cel_mat(), _silk_prm(), thread_fn, 0.62, {"tube": true, "w": 0.02, "sides": 4})
	var web = _seal_quad(Vector2(0.6, 0.6), {"kind": 7.0, "c1": SILK, "c2": Color(0.7, 0.7, 0.66), "reveal": 0.0, "nf": 1.0})
	_stick(pj, tt, web, 0.65, "Chest", 0.2)
	_tp(web, "reveal", 0.0, 1.0, 0.1)
	var tick = func(i, _k):
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		if x is CharacterBody3D:
			var v: Vector3 = cc.global_position - x.global_position
			v.y = 0
			x.velocity = v.normalized() * clampf((v.length() - 1.2) / 0.1, 0.0, 26.0)
		if i % 3 == 0:
			_burst(pj, pj.gp(x.global_position) + Vector3.UP * 0.1, {"n": 4, "v0": 0.5, "v1": 1.5, "g": 1.0, "life": 0.5, "spread": 60.0, "r": 0.25,
				"s0": 0.14, "s1": 0.26, "cols": [Color(0.75, 0.68, 0.56, 0.8), Color(0.6, 0.53, 0.43, 0)]})
	var done = func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		pj._kick_pose(cc, 0.25)
		var hp: Vector3 = x.global_position + Vector3.UP * 1.0
		_pop(pj, hp, 1.5, {"kind": 13.0, "c1": Color(1, 1, 0.95), "c2": Color(0.95, 0.88, 0.7), "c3": EARTH_D, "seed": randf() * 9.0, "nf": 1.0}, 0.18)
		_pop(pj, hp, 2.6, {"kind": 18.0, "c1": Color(1, 0.98, 0.9), "seed": randf() * 9.0, "nf": 1.2}, 0.22, 1.2)
		_burst(pj, pj.gp(x.global_position) + Vector3.UP * 0.1, {"n": 12, "ring": 0.4, "v0": 2.0, "v1": 4.0, "g": 1.0, "radial": 5.0, "damp": 3.0, "life": 0.6,
			"s0": 0.2, "s1": 0.35, "cols": [Color(0.78, 0.7, 0.58, 0.85), Color(0.6, 0.52, 0.42, 0)]})
		Sfx.play("punch", x.global_position, 0.8)
		x.take_hit(pj.inf(cc, id, 1.3 * nk, {"knock": 10.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.08, "dir": cc.face_dir()}))
	pj.every(0.4, 1.0 / 30.0, tick, done)
	Sfx.play("whoosh", c.global_position, 1.5)


# ================================================================== Tsuchigumo: Tsuchigumo Ana
## Kapan örümceği: rakibin altında karanlık çukur açılır, iki cel kaya çene (dişli) yerden kalkıp içe kapanır; kesek,
## ışınsal çatlak; çeneler toprağa geri gömülünce çukur yavaşça kapanır
static func tsuchigumo_ana(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "tsuchigumo_ana"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.4)
	var nk = pj._tg_nature(c)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var sd = d.cross(Vector3.UP).normalized()
	var pit = _decal(pj, at, 2.6, {"kind": 19.0, "c2": EARTH_C, "c3": Color(0.05, 0.035, 0.03), "seed": randf() * 6.0})
	pit.scale = Vector3.ONE * 0.2
	pit.create_tween().tween_property(pit, "scale", Vector3.ONE, 0.12)
	_fade_free(pit, 2.2 * nk + 0.3, 0.5)
	for s in [-1.0, 1.0]:   # iki toprak çene: yerden kalkıp kapanır
		var jaw = Node3D.new()
		jaw.add_child(_cel(_jaw_mesh(), 0.03, {"nf": 1.2, "oc": Color(0.12, 0.08, 0.05)}))
		pj.scene_add(jaw, at + sd * s * 0.9)
		jaw.global_basis = Basis.looking_at(-sd * s, Vector3.UP)
		jaw.rotation.x = 0.0
		jaw.scale = Vector3(1, 0.05, 1)
		var jt = jaw.create_tween()
		jt.tween_property(jaw, "scale", Vector3.ONE, 0.12)
		jt.tween_property(jaw, "rotation:x", -0.9, 0.1).set_ease(Tween.EASE_IN)   # içe kapanır
		jt.tween_interval(1.8 * nk)
		jt.tween_property(jaw, "scale", Vector3(1, 0.02, 1), 0.3)
		jt.tween_callback(jaw.queue_free)
	var cr = _decal(pj, at, 4.2, {"kind": 8.0, "c3": Color(0.12, 0.09, 0.07), "seed": randf() * 6.0, "reveal": 0.0, "alpha": 0.9})
	_tp(cr, "reveal", 0.0, 1.0, 0.15)
	_fade_free(cr, 2.0, 0.8)
	_clods(pj, at, 12, 6.0)
	Sfx.play("earth", at, 0.9)
	var snap = func():
		_burst(pj, at + Vector3.UP * 0.9, {"n": 10, "mesh": "chip", "v0": 1.5, "v1": 3.5, "g": 14.0, "life": 0.6, "spread": 70.0, "r": 0.3,
			"s0": 0.06, "s1": 0.12, "cols": [EARTH_C.lightened(0.1), EARTH_D]})
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 1.6):
			pj.st(e, "bind", 1.8 * nk)
			e.take_hit(pj.inf(cc, id, 1.2 * nk, {"knock": 0.0, "kind": "heavy", "bleed": 2.0, "hitstop": 0.08}))
	pj.after(0.22, snap)


# ================================================================== Tsuchigumo: Shizen Kōsoku
## Doğa enerjisi toprağa akar: kullanıcıdan hedefe yerde sürünen üç altın damar, hedefin altında yapraklı altın halka;
## çevresinden altı pürüzlü kaya sütunu ve dört kök içe eğilerek yükselir, rakibi kenetler; altın zerreler yükselir
static func tsuchigumo_shizen_kosoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "tsuchigumo_shizen_kosoku"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var nk = pj._tg_nature(c)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var from: Vector3 = pj.gp(c.global_position + d * 0.6)
	var sd = d.cross(Vector3.UP).normalized()
	for v in 3:   # yerde sürünen altın damarlar
		var pts: Array = []
		var ws: Array = []
		var nrm: Array = []
		for q in 18:
			var u = float(q) / 17.0
			var p = from.lerp(at, u) + sd * sin(u * PI * (2.0 + v) + v * 1.7) * 0.5 * sin(u * PI)
			p.y = Game.jutsu_floor(p.x, p.z) + 0.06
			pts.append(p)
			ws.append(0.14 * (1.0 - u * 0.4))
			nrm.append(Vector3.UP)
		var vein = _mi(_mesh([_ribbon(pts, ws, nrm)]), _glow_mat())
		_prm(vein, {"c1": Color(1.0, 0.97, 0.75), "c2": NATURE, "c3": Color(0.6, 0.35, 0.08), "pat": 3.0, "seed": v * 3.0, "reveal": 0.0, "nf": 1.5})
		pj.scene_add(vein, Vector3.ZERO)
		vein.global_transform = Transform3D.IDENTITY
		_tp(vein, "reveal", 0.0, 1.0, 0.25)
		_fade_free(vein, 0.6, 0.6)
	var ring = _decal(pj, at, 4.4, {"kind": 20.0, "c1": Color(1.0, 0.95, 0.65), "c2": Color(1.0, 0.65, 0.2), "reveal": 0.0, "seed": randf() * 3.0})
	_tp(ring, "reveal", 0.0, 1.0, 0.3, 0.15)
	_fade_free(ring, 1.3, 0.6)
	var hold = 2.0 * nk
	for k in 6:   # yükselen kaya sütunları halkası (içe eğik)
		var a = k * TAU / 6.0
		var rise = func():
			var rock = _cel(_crag_mesh(k + 1), 0.03, {"nf": 1.2, "oc": Color(0.12, 0.08, 0.05), "seed": k * 1.0})
			pj.scene_add(rock, at + Vector3(cos(a), 0, sin(a)) * 1.1)
			rock.global_basis = Basis.looking_at(Vector3(-cos(a), 0, -sin(a)), Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(-20.0))
			var sc = Vector3(0.9, 1.8 * nk, 0.9)
			rock.scale = Vector3(sc.x, 0.05, sc.z)
			var rt = rock.create_tween()
			rt.tween_property(rock, "scale", sc, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			rt.tween_interval(hold)
			rt.tween_property(rock, "scale", Vector3(sc.x, 0.02, sc.z), 0.35).set_ease(Tween.EASE_IN)
			rt.tween_callback(rock.queue_free)
			_clods(pj, at + Vector3(cos(a), 0, sin(a)) * 1.1, 4, 4.0, 0.7)
		pj.after(0.05 * k, rise)
	for k in 4:   # kökler: yerden çıkıp hedefin üstüne kıvrılır
		var a = k * TAU / 4.0 + 0.4
		var b0 = at + Vector3(cos(a), 0, sin(a)) * 1.6
		var top = at + Vector3(cos(a), 0, sin(a)) * 0.35 + Vector3.UP * 1.3
		var pts = _bez(b0 - Vector3.UP * 0.2, b0 + Vector3.UP * 1.4, top + Vector3(cos(a), 0, sin(a)) * 0.6, top, 10)
		var rs: Array = []
		for q in 10:
			rs.append(0.09 * (1.0 - float(q) / 10.0) + 0.015)
		var root = _cel(_mesh([_tube(pts, rs, 6)]), 0.02, {"tint": Color(0.5, 0.36, 0.22), "nf": 1.2, "oc": Color(0.12, 0.07, 0.04)})
		var holder = Node3D.new()
		pj.scene_add(holder, at)
		holder.add_child(root)
		root.position = -at
		holder.scale = Vector3(1, 0.02, 1)
		var ht = holder.create_tween()
		ht.tween_interval(0.12 + k * 0.04)
		ht.tween_property(holder, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT)
		ht.tween_interval(hold - 0.2)
		ht.tween_property(holder, "scale", Vector3(1, 0.02, 1), 0.35)
		ht.tween_callback(holder.queue_free)
	_burst(pj, at + Vector3.UP * 0.3, {"n": 18, "r": 1.2, "dir": Vector3.UP, "spread": 25.0, "v0": 1.5, "v1": 3.0, "g": -0.5, "life": 1.0, "add": true,
		"mesh": "streak", "align": true, "s0": 0.15, "s1": 0.3, "cols": [Color(1.0, 0.95, 0.65), NATURE, Color(1.0, 0.55, 0.15, 0)]})
	Sfx.play("earth", at, 0.8)
	var clamp_fn = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 1.8):
			pj.st(e, "bind", 2.0 * nk)
			e.take_hit(pj.inf(cc, id, 0.8 * nk, {"knock": 0.0, "kind": "heavy", "hitstop": 0.06}))
	pj.after(0.3, clamp_fn)


# ================================================================== Tsuchigumo: Dokugumo no Mure
## Avucun bastığı yerde küçük çatlak açılır, on kara örümcek (kırmızı kum saati deseni, iki bacak pozuyla koşar) rakibe
## koşup bacaklarından tırmanır; ısırıkta mor zehir damlaları ve bedende mor zehir zerreleri işler
static func tsuchigumo_dokugumo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "tsuchigumo_dokugumo"
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.4)
	var nk = pj._tg_nature(c)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var start: Vector3 = pj.gp(c.global_position + d * 0.8)
	var hole = _decal(pj, start, 1.4, {"kind": 8.0, "c3": Color(0.1, 0.07, 0.05), "seed": randf() * 5.0, "reveal": 1.0, "alpha": 0.9})
	_fade_free(hole, 1.2, 0.6)
	_clods(pj, start, 6, 2.5, 0.6)
	for k in 10:
		var sp = Node3D.new()
		var pose_a = _cel(_spider_mesh(0), 0.012, {"nf": 0.8, "oc": Color(0.02, 0.02, 0.02)})
		var pose_b = _cel(_spider_mesh(1), 0.012, {"nf": 0.8, "oc": Color(0.02, 0.02, 0.02)})
		pose_b.visible = false
		sp.add_child(pose_a)
		sp.add_child(pose_b)
		sp.scale = Vector3.ONE * 1.3
		var o = Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		pj.scene_add(sp, start + o)
		var spw = weakref(sp)
		var dl = k * 0.04
		var run = func(i, kk):
			var s2 = spw.get_ref()
			var x = tw.get_ref() if tw else null
			if s2 == null or not is_instance_valid(s2):
				return
			if i % 2 == 0:
				pose_a.visible = not pose_a.visible
				pose_b.visible = not pose_a.visible
			var end: Vector3 = (x.global_position + o * 0.3) if x != null and is_instance_valid(x) else start + d * 8.0 + o
			var u = clampf((kk * 0.7 - dl) / 0.6, 0.0, 1.0)
			var p: Vector3 = pj.gp((start + o).lerp(end, u))
			if u >= 1.0 and x != null and is_instance_valid(x):
				p = x.global_position + Vector3(o.x * 0.3, 0.3 + fmod(kk * 8.0 + k, 1.2), o.z * 0.3)   # bacaklardan tırmanır
			s2.global_position = p
			if u < 1.0:
				s2.look_at(p + d, Vector3.UP)
		pj.every(0.7, 1.0 / 30.0, run)
		pj.free_after(1.6, sp)
	Sfx.play("whoosh", start, 1.8)
	var bite = func():
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		Sfx.play("bite", x.global_position, 1.3)
		# zehir (PathJutsu.poison mekaniği: bedene yanma süresiyle hasar), görünüş burada
		var bp: Vector3 = x.global_position + Vector3.UP * _h(x) * 0.6
		pj.hit(cc, bp, _rad(x) + 0.6, pj.inf(cc, id, 1.0 * nk, {"knock": 1.0, "kind": "light", "burn": 5.0, "hitstop": 0.03}))
		_burst(pj, bp, {"n": 12, "v0": 1.0, "v1": 2.5, "g": 9.0, "life": 0.6, "spread": 160.0, "r": 0.3, "s0": 0.05, "s1": 0.1,
			"cols": [Color(0.75, 0.35, 0.95), Color(0.45, 0.12, 0.6), Color(0.3, 0.05, 0.4, 0)]})
		var px = _burst(pj, Vector3.ZERO, {"one": false, "n": 10, "life": 0.8, "v0": 0.3, "v1": 0.8, "g": -1.0, "spread": 40.0, "r": 0.3, "s0": 0.05, "s1": 0.09,
			"parent": x, "off": Vector3.UP * _h(x) * 0.5, "cols": [Color(0.7, 0.3, 0.9, 0.9), Color(0.35, 0.6, 0.2, 0)]})
		pj.free_after(2.5, px)
		pj.st(x, "slow", 2.5)
		x.take_hit(pj.inf(cc, id, 0.7 * nk, {"knock": 0.0, "kind": "heavy", "hitstop": 0.05}))
	pj.after(0.75, bite)


# ================================================================== Tsuchigumo: Hassoku Ken
## Örümceğin sekiz bacağı: her darbede rakibe sekiz ayrı yönden saplanan eklemli bacak izi (kehribar, koyu kenarlı), küçük
## darbe yıldızı; son darbe toprağı çatlatır, altın doğa tozu yükselir, arkada sekiz bacaklı siluet bir an açılır
static func _leg_arc(pj: PathJutsu, from: Vector3, to: Vector3, k: int) -> void:
	var side = (to - from).cross(Vector3.UP).normalized()
	var ang = k * TAU / 8.0
	var off = side * cos(ang) * 0.9 + Vector3.UP * (sin(ang) * 0.7 + 0.3)
	var knee = from.lerp(to, 0.45) + off
	var pts: Array = []
	for q in 10:
		var u = float(q) / 9.0
		pts.append(from.lerp(knee, u * 2.0) if u < 0.5 else knee.lerp(to, (u - 0.5) * 2.0))
	var ws: Array = []
	for q in 10:
		ws.append(0.13 * (1.0 - float(q) / 11.0))
	var leg = _mi(_mesh([_ribbon(pts, ws)]), _glow_mat())
	_prm(leg, {"c1": Color(1.0, 0.92, 0.7), "c2": Color(0.85, 0.6, 0.3), "c3": Color(0.3, 0.18, 0.08), "reveal": 0.0, "alpha": 0.9, "nf": 1.5})
	pj.scene_add(leg, Vector3.ZERO)
	leg.global_transform = Transform3D.IDENTITY
	_tp(leg, "reveal", 0.0, 1.0, 0.05)
	_tp(leg, "tail", 0.0, 0.95, 0.16, 0.05).tween_callback(leg.queue_free)


static func tsuchigumo_hassoku_ken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	pj.busy(c, 1.3)
	var id = "tsuchigumo_hassoku_ken"
	if tt == null:
		return
	var nk = pj._tg_nature(c)
	var cw = weakref(c)
	var tw = weakref(tt)
	pj._jump_at(c, tt, 0.0, 10.0 if tt.global_position.distance_to(c.global_position) > 2.2 else 1.0)
	for k in 8:
		var strike = func():
			var cc = cw.get_ref()
			var x = tw.get_ref()
			if cc == null or x == null or not pj.live(cc) or not pj.live(x):
				return
			var f: Vector3 = pj._face(cc, x)
			if cc is CharacterBody3D:
				cc.velocity = f * clampf((cc.global_position.distance_to(x.global_position) - 1.3) / 0.1, 0.0, 12.0)
			var last = k == 7
			if k % 4 < 2:
				pj.anim(cc, ["jab", "cross"][k % 2], 3.2)
			else:
				pj._kick_pose(cc, 0.1)
			Sfx.play("punch", x.global_position, 1.0 + k * 0.04)
			var hitp: Vector3 = x.global_position + Vector3.UP * (1.0 if k % 4 < 2 else 0.6)
			_leg_arc(pj, cc.global_position + Vector3.UP * 1.1, hitp, k)
			_pop(pj, hitp, 0.8, {"kind": 13.0, "c1": Color(1, 0.98, 0.88), "c2": Color(0.95, 0.75, 0.4), "c3": Color(0.25, 0.14, 0.05), "seed": k * 1.7, "nf": 1.0}, 0.12)
			if last:
				var g: Vector3 = pj.gp(x.global_position)
				var cr = _decal(pj, g, 5.2, {"kind": 8.0, "c3": Color(0.12, 0.09, 0.07), "seed": randf() * 6.0, "reveal": 0.0})
				_tp(cr, "reveal", 0.0, 1.0, 0.1)
				_fade_free(cr, 2.5, 0.8)
				_burst(pj, g + Vector3.UP * 0.3, {"n": 16, "r": 0.6, "dir": Vector3.UP, "spread": 50.0, "v0": 2.0, "v1": 4.0, "g": -0.5, "life": 0.8, "add": true,
					"mesh": "streak", "align": true, "s0": 0.15, "s1": 0.3, "cols": [Color(1.0, 0.92, 0.6), NATURE, Color(0.9, 0.55, 0.2, 0)]})
				_clods(pj, g, 12, 6.0)
				_ground_ring(pj, g, 3.0, Color(0.95, 0.88, 0.72), Color(0.8, 0.7, 0.5), Color(0.35, 0.25, 0.15), 0.35)
				# sekiz bacaklı siluet: kullanıcının arkasında bir an açılır
				var back: Vector3 = cc.global_position + Vector3.UP * 1.2
				for q in 8:
					var a = (q - 3.5) * 0.36
					var dv = (-f).rotated(Vector3.UP, a)
					_leg_arc(pj, back, back + dv * 1.6 + Vector3.UP * (0.6 - absf(q - 3.5) * 0.25), q)
				pj.shake(0.35)
			x.take_hit(pj.inf(cc, id, (0.8 if last else 0.17) * nk, {"knock": 2.0 if last else 0.3, "launch": -6.0 if last else 0.0, "stun": 0.5 if last else 0.1, "kind": "heavy" if last else "light", "hitstop": 0.1 if last else 0.02, "pierce_guard": last}))
		pj.after(0.2 + k * 0.11, strike)


# ================================================================== Tsuchigumo: Ito Tobi Otoshi
## Göğe ipek tel atılır, tepede küçük ağ yumağına tutunur; kullanıcı telle sarkarak süzülür (ardında ince hız izi), iki
## topukla iner: çukur + çatlak, genişleyen toz halkası, kesek; tel kopar, ağ söner
static func tsuchigumo_ito_tobi_otoshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 1.2)
	var id = "tsuchigumo_ito_tobi_otoshi"
	var d = pj._face(c, tt)
	var nk = pj._tg_nature(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	var p0: Vector3 = c.global_position
	var anchor: Vector3 = p0.lerp(at, 0.5) + Vector3.UP * 10.0
	var cw = weakref(c)
	pj.anim(c, "throw", 1.4)
	var thread_fn = func() -> Array:
		var cc = cw.get_ref()
		var h: Vector3 = pj.hand_pos(cc) if cc != null and is_instance_valid(cc) else anchor
		return [h, h.lerp(anchor, 0.5), anchor]
	_live_strand(pj, _cel_mat(), _silk_prm(), thread_fn, 0.75, {"tube": true, "w": 0.022, "sides": 4})
	var webb = _bill(pj, anchor, 1.3, {"kind": 7.0, "c1": SILK, "c2": Color(0.72, 0.72, 0.68), "reveal": 0.0, "nf": 2.0})
	_tp(webb, "reveal", 0.0, 1.0, 0.12)
	_fade_free(webb, 0.75, 0.3)
	var trail: Array = []
	var trail_fn = func() -> Array:
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc):
			trail.append(cc.global_position + Vector3.UP * 1.0)
		while trail.size() > 10:
			trail.remove_at(0)
		return trail.duplicate()
	var swing_w = func(u: float) -> float:
		return 0.05 + 0.35 * u
	_live_strand(pj, _glow_mat(), {"c1": Color(1, 1, 1), "c2": Color(0.9, 0.88, 0.8), "c3": Color(0.5, 0.45, 0.4), "alpha": 0.6, "fade": 1.0, "nf": 2.5},
		trail_fn, 0.85, {"w": swing_w})
	var swing = func(_i, k):   # telle sarkaç gibi yükselip hedefin üstüne iner
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var p: Vector3
		if k < 0.6:
			var u = k / 0.6
			p = p0.lerp(at, u * 0.6) + Vector3.UP * sin(u * PI * 0.5) * 5.0
		else:
			var u = (k - 0.6) / 0.4
			var top = p0.lerp(at, 0.6) + Vector3.UP * 5.0
			p = top.lerp(at, u * u)
		cc.global_position = p
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
	var land = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		pj._kick_pose(cc, 0.3)
		var pit = _decal(pj, at, 2.0, {"kind": 19.0, "c2": EARTH_C, "c3": Color(0.1, 0.07, 0.05), "seed": randf() * 5.0})
		_fade_free(pit, 2.6, 0.8)
		var cr = _decal(pj, at, 6.0, {"kind": 8.0, "c3": Color(0.12, 0.09, 0.07), "seed": randf() * 6.0, "reveal": 0.0})
		_tp(cr, "reveal", 0.0, 1.0, 0.12)
		_fade_free(cr, 3.0, 0.8)
		_clods(pj, at, 14, 8.0)
		_ground_ring(pj, at, 4.5, Color(0.95, 0.9, 0.78), Color(0.82, 0.74, 0.6), Color(0.35, 0.27, 0.18), 0.4)
		_burst(pj, at + Vector3.UP * 0.1, {"n": 20, "ring": 0.8, "v0": 3.0, "v1": 6.0, "g": 1.5, "radial": 7.0, "damp": 4.0, "life": 0.8,
			"s0": 0.25, "s1": 0.45, "cols": [Color(0.8, 0.72, 0.6, 0.9), Color(0.62, 0.54, 0.44, 0)]})
		Sfx.play("boom", at, 0.8)
		pj.shake(0.45)
		for e in pj.enemies_near(cc, at, 2.6):
			e.take_hit(pj.inf(cc, id, 1.6 * nk, {"knock": 6.0, "launch": -4.0, "kind": "heavy", "stun": 0.6, "hitstop": 0.1}))
	pj.every(0.8, 1.0 / 60.0, swing, land)


# ================================================================== Uzumaki yapı taşları
## Kongō Fūsa halkası: oval chakra halkası (TorusMesh, boyuna uzatılmış)
static func _link_mesh() -> TorusMesh:
	if not _cache.has("mesh:link"):
		var tm = TorusMesh.new()
		tm.inner_radius = 0.05
		tm.outer_radius = 0.085
		tm.rings = 12
		tm.ring_segments = 6
		_cache["mesh:link"] = tm
	return _cache["mesh:link"]


static func _tip_mesh() -> ArrayMesh:
	if not _cache.has("mesh:tip"):
		var b = MB.new()
		b.add("cone", Vector3(0, 0.14, 0), Vector3(0.13, 0.28, 0.05), Color.WHITE, Vector3.ZERO, 4)
		b.add("box", Vector3(0, -0.02, 0), Vector3(0.05, 0.08, 0.05), Color.WHITE, Vector3.ZERO)
		_cache["mesh:tip"] = b.build(null)
	return _cache["mesh:tip"]


## Çoklu doğru boyunca eşit aralıklı [konum, teğet] örnekleri
static func _resample(pts: Array, step: float) -> Array:
	var out: Array = []
	var carry := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var L = a.distance_to(b)
		if L < 0.0001:
			continue
		var dv = (b - a) / L
		var s = carry
		while s < L:
			out.append([a + dv * s, dv])
			s += step
		carry = s - L
	return out


## Altın chakra zinciri (ref: Kongō Fūsa — soluk altın, birbirine geçmiş kalın oval halkalar, yumuşak ışıma): halkalar
## MultiMesh, cel altın + koyu kontur + eklemeli hale; tabandan uca doğru büyür. tip: ucunda sivri zincir başı.
static func _chain(pj: PathJutsu, parent: Node3D, pts: Array, grow: float, delay: float, tip := false) -> Node3D:
	var smp = _resample(pts, 0.19)
	var holder = Node3D.new()
	parent.add_child(holder)
	holder.global_transform = Transform3D.IDENTITY
	var n = smp.size()
	if n == 0:
		return holder
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _link_mesh()
	mm.instance_count = n
	for i in n:
		var pos: Vector3 = smp[i][0]
		var tdir: Vector3 = smp[i][1]
		var bz = Basis.looking_at(tdir, Vector3.UP if absf(tdir.y) < 0.95 else Vector3.RIGHT)
		if i % 2 == 1:
			bz = bz * Basis(Vector3(0, 0, 1), PI * 0.5)
		mm.set_instance_transform(i, Transform3D(bz * Basis.from_scale(Vector3(1.0, 1.0, 1.7)), pos))
	mm.visible_instance_count = 0
	var layers = [[_cel_mat(), {"tint": GOLD, "metal": 0.55, "nf": 1.2}], [_outline_mat(), {"ow": 0.012, "oc": GOLD_D, "nf": 1.2}],
		[_halo_mat(), {"hc": Color(1.0, 0.82, 0.35), "puff": 0.035, "alpha": 0.55, "nf": 1.5}]]
	for ly in layers:
		var mi = MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = ly[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_prm(mi, ly[1])
		holder.add_child(mi)
	var head: Node3D = null
	if tip:
		head = _cel(_tip_mesh(), 0.012, {"tint": GOLD, "metal": 0.6, "nf": 1.2, "oc": GOLD_D})
		holder.add_child(head)
		var last: Vector3 = smp[n - 1][1]
		head.global_transform = Transform3D(Basis.looking_at(last, Vector3.UP if absf(last.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI * 0.5), smp[n - 1][0])
		head.visible = false
	var gw = func(v: float):
		var cnt = clampi(int(v * n), 0, n)
		mm.visible_instance_count = cnt
		if head != null and is_instance_valid(head):
			head.visible = cnt >= n
	var tw = holder.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(gw, 0.0, 1.0, maxf(grow, 0.02))
	return holder


## Bağlanma anı: tüm zincirlerin halesi parlayıp söner
static func _halo_flash(root: Node3D) -> void:
	if not is_instance_valid(root):
		return
	for h in root.get_children():
		for g in h.get_children():
			if g is MultiMeshInstance3D and g.material_override == _halo_mat():
				_tp(g, "alpha", 1.8, 0.55, 0.45)


## Gövdeyi saran kapalı zincir halkası (hedefin yerel uzayında değil, dünyada; hedef bağlı kaldığı için yerinde durur)
static func _loop_pts(cen: Vector3, R: float, tilt: float, a0: float) -> Array:
	var pts: Array = []
	for q in 25:
		var a = a0 + q * TAU / 24.0
		pts.append(cen + Vector3(cos(a) * R, sin(a + tilt) * 0.12, sin(a) * R))
	return pts


## Parmak ucu mavi chakra alevi (ref: işaret parmağının ucunda yanan soluk mavi alev): kemiğe bağlı cel alev dili
static func _finger_flame(pj: PathJutsu, c: Node3D, bone: String, size: float, dur: float, light := true) -> void:
	var ba = pj.bone_attach(c, bone)
	if ba == null:
		ba = pj.bone_attach(c, "RightHand" if bone.begins_with("Right") else "LeftHand")
	if ba == null:
		return
	var pts: Array = []
	for q in 6:
		pts.append(Vector3(0, 0.02 + q * size * 0.035, 0))
	var fl = _mi(_mesh([_ribbon(pts, [size * 0.05, size * 0.07, size * 0.065, size * 0.05, size * 0.03, size * 0.01])]), _glow_mat())
	_prm(fl, {"c1": Color(0.95, 0.98, 1.0), "c2": SEAL_BLUE, "c3": Color(0.15, 0.3, 0.8), "pat": 2.0, "alpha": 0.95, "seed": randf() * 5.0, "nf": 0.6})
	ba.add_child(fl)
	if light:
		var li = OmniLight3D.new()
		li.light_color = SEAL_BLUE
		li.light_energy = 0.6
		li.omni_range = 1.2
		ba.add_child(li)
	pj.free_after(dur, ba)


## Mühürlenen hedef: chakra noktaları kapanır (ClanJutsu.seal_points mekaniği), görünüş: gövdede yanıp sönen küçük kilit yazıları
static func _seal_points(pj: PathJutsu, t: Node3D, dur: float, col: Color) -> void:
	if not pj.live(t):
		return
	pj.st(t, "sealed", dur)
	Combat.popup_text(t.global_position + Vector3.UP * (_h(t) + 1.0), "Chakra noktaları kapandı!", col)
	var band = _seal_quad(Vector2(0.9, 0.12), {"kind": 2.0, "aspect": 7.5, "c3": INK, "c1": col, "glow": 0.6, "seed": randf() * 9.0, "nf": 1.0})
	_stick(pj, t, band, dur, "Chest", 0.2, false, 0.05)
	_tp(band, "glow", 0.6, 0.0, minf(dur, 3.0))


## Bedeni saran yazı halkası (dönen mühür şeridi)
static func _script_band(pj: PathJutsu, t: Node3D, r: float, dur: float, col: Color, ink: Color) -> void:
	var pts: Array = []
	var ws: Array = []
	var nr: Array = []
	for q in 33:
		var a = q * TAU / 32.0
		pts.append(Vector3(cos(a) * r, sin(a * 2.0) * 0.04, sin(a) * r))
		ws.append(0.16)
		nr.append(Vector3(cos(a), 0, sin(a)))
	var band = _mi(_mesh([_ribbon(pts, ws, nr)]), _seal_mat())
	_prm(band, {"kind": 2.0, "aspect": 26.0, "c3": ink, "c1": col, "glow": 0.0, "reveal": 0.0, "seed": randf() * 9.0, "nf": 1.0})
	var holder = Node3D.new()
	holder.add_child(band)
	pj.attach(t, holder, dur, Vector3(0, _h(t) * 0.5, 0), 2)
	_tp(band, "reveal", 0.0, 1.0, 0.35)
	var spin = holder.create_tween().set_loops(int(dur / 2.0) + 1)
	spin.tween_property(holder, "rotation:y", TAU, 2.0).from(0.0)
	_fade_free(band, dur - 0.4, 0.35)


# ================================================================== Uzumaki: Kongō Fūsa (chakra zincirleri)
## Ref: soluk altın, kalın, birbirine geçmiş halkalardan zincirler, yumuşak ışıma. Üç zincir kullanıcının sırtından
## kavislenerek, iki zincir hedefin çevresinde yerden (çatlak + altın kıvılcım) fışkırır, sivri başlarıyla hedefe saplanır;
## gövdeye üç zincir halkası dolanır, bağlanma anında hale parlar; süre bitince altın zerrelere dağılır
static func chakra_chains(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var m = Jutsu._mult(c)
	if t == null or c.global_position.distance_to(t.global_position) > 28.0:
		Hud.msg("Chakra zincirleri: hedef çok uzak", Color(1, 0.85, 0.4))
		return
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	var center = Jutsu._ground(t.global_position)
	var fd: Vector3 = c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD
	var back = c.global_position + Vector3.UP * 1.3 - fd * 0.3
	var side = fd.cross(Vector3.UP).normalized()
	# kanon: birkaç zincir kullanıcının sırtından çıkar, ötekiler yere dalıp hedefin çevresinden fışkırır; hepsi hedefe dolanır
	for k in 5:
		var a = k * TAU / 5.0 + 0.4
		var top = t.global_position + Vector3.UP * (0.8 + k * 0.25)
		var pts: Array
		if k < 3:
			var base = back + (side * cos(a) + Vector3.UP * sin(a) * 0.6) * 0.3
			var lift = base - fd * 0.8 + Vector3.UP * (1.6 + k * 0.4) + side * (k - 1) * 1.2
			pts = _bez(base, lift, top + Vector3.UP * 2.0 + side * (k - 1) * 0.8, top, 22)
			_burst(pj, base, {"n": 8, "v0": 1.0, "v1": 2.5, "g": 0.0, "damp": 3.0, "life": 0.5, "spread": 180.0, "add": true, "mesh": "streak", "align": true,
				"s0": 0.1, "s1": 0.2, "cols": [Color(1, 0.97, 0.75), GOLD, Color(1, 0.7, 0.2, 0)]})
		else:
			var base2 = center + Vector3(cos(a), 0, sin(a)) * 3.5
			pts = _bez(base2 - Vector3.UP * 0.3, base2 + Vector3.UP * 2.2, top + Vector3(cos(a), 0, sin(a)) * 1.2 + Vector3.UP * 0.8, top, 20)
			var cr = _decal(pj, base2, 1.6, {"kind": 8.0, "c3": Color(0.14, 0.1, 0.07), "seed": k * 2.0, "reveal": 1.0, "alpha": 0.85})
			_fade_free(cr, 4.4, 0.6)
			_clods(pj, base2, 8, 4.0, 0.7)
			_burst(pj, base2 + Vector3.UP * 0.2, {"n": 10, "v0": 2.0, "v1": 4.0, "g": 2.0, "life": 0.5, "spread": 30.0, "add": true, "mesh": "streak", "align": true,
				"s0": 0.12, "s1": 0.22, "cols": [Color(1, 0.97, 0.75), GOLD, Color(1, 0.7, 0.2, 0)]})
		_chain(pj, root, pts, 0.25, 0.0, true)
	# gövdeye dolanan zincir halkaları (referans: Dokuz Kuyruk'u saran zincirler)
	for wv in 3:
		var hy = 0.7 + wv * 0.35
		_chain(pj, root, _loop_pts(t.global_position + Vector3.UP * hy, 0.45, wv * 1.3, wv * 1.3), 0.15, 0.22 + wv * 0.05)
	# bağlanma anı: hale parlar, altın kıvılcım halkası
	var tpos: Vector3 = t.global_position + Vector3.UP * 1.2
	var flash = func():
		_halo_flash(root)
		_burst(pj, tpos, {"n": 18, "ring": 0.6, "ring_in": 0.4, "v0": 2.0, "v1": 4.0, "g": 0.0, "radial": 4.0, "damp": 3.0, "life": 0.5, "add": true,
			"mesh": "streak", "align": true, "s0": 0.15, "s1": 0.3, "cols": [Color(1, 1, 0.85), GOLD, Color(1, 0.7, 0.2, 0)]})
	pj.after(0.3, flash)
	Sfx.play("clink", center, 0.7)
	if t.has_method("apply_status"):
		t.apply_status("bind", 5.0)
	Combat.hit_sphere(c, t.global_position + Vector3.UP, 1.4, {"dmg": 12.0 * m, "knock": 0.0, "kind": "light"})
	Combat.popup_text(t.global_position + Vector3.UP * 2.6, "Mühürlendi!", Color(1, 0.85, 0.4))
	# dağılış: zincirler noktalı söner, altın zerreler
	var rw = weakref(root)
	var dissolve = func():
		var r2 = rw.get_ref()
		if r2 == null or not is_instance_valid(r2):
			return
		for h in r2.get_children():
			for g in h.get_children():
				if g is MultiMeshInstance3D and g.material_override == _halo_mat():
					g.visible = false
				else:
					_tp(g, "alpha", 1.0, 0.0, 0.4)
		_burst(pj, tpos, {"n": 24, "r": 1.0, "v0": 0.5, "v1": 1.5, "g": -1.5, "life": 0.9, "add": true, "s0": 0.05, "s1": 0.1,
			"cols": [Color(1, 0.95, 0.7), GOLD, Color(1, 0.75, 0.3, 0)]})
	pj.get_tree().create_timer(4.6).timeout.connect(dissolve)
	pj.get_tree().create_timer(5.0).timeout.connect(root.queue_free)


# ================================================================== Uzumaki: Hakke no Fūin Shiki
## Ref (anahtar sahnesi): beş parmak ucunda mavi alev, karında girdap + çevresinde tırtıklı yazı; sunak: sekizgen taş üstünde
## trigram düzeni. İki elin beş parmağında mavi alev dilleri; hedefin ayakları altında sekizgen trigram sunağı çizilir;
## avuç karna iner: gerçek bedenin karnında (omurga kemiği önü) girdap + sekiz trigram + alev halkası mührü mavi parlayarak
## yazılır, sonra mürekkep karasına döner ve süre boyunca kalır; karından mavi şok halkası yayılır
static func hakke_no_fuin_shiki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	for side in ["Right", "Left"]:
		for f in ["ThumbDistal", "IndexDistal", "MiddleDistal", "RingDistal", "LittleDistal"]:
			_finger_flame(pj, c, side + f, 0.9, 1.0, f == "IndexDistal")
	var tt = pj.tg(c, t, 6.0)
	if tt == null:
		Hud.msg("Sekiz Trigram Mühürü: hedefe 6 metre içinde dokunmalısın", Color(0.9, 0.8, 0.6))
		return
	var altar = _decal(pj, tt.global_position, 7.0, {"kind": 6.0, "c1": SEAL_BLUE, "c3": Color(0.08, 0.08, 0.12), "reveal": 0.0, "glow": 0.6, "seed": randf() * 4.0})
	_tp(altar, "reveal", 0.0, 1.0, 0.3)
	_fade_free(altar, 0.9, 0.3)
	pj.anim(c, "cross", 1.2)
	var press = func():
		if not pj.live(tt):
			return
		var seal = _seal_quad(Vector2(0.62, 0.62), {"kind": 3.0, "c1": Color(0.55, 0.78, 1.0), "c3": Color(0.1, 0.1, 0.16), "reveal": 0.0, "glow": 1.0,
			"seed": randf() * 4.0, "nf": 0.8})
		_stick(pj, tt, seal, 15.0, "Spine", 0.2)
		_tp(seal, "reveal", 0.0, 1.0, 0.35)
		_tp(seal, "glow", 1.0, 0.0, 1.2, 0.4)
		_tp(seal, "alpha", 1.0, 0.0, 0.6, 14.3)
		_seal_points(pj, tt, 15.0, Color(0.9, 0.9, 1.0))
		if tt.get("power") != null:
			tt.power = float(tt.power) * 0.5
			var restore = func():
				if is_instance_valid(tt):
					tt.power = float(tt.power) * 2.0
			pj.after(15.0, restore)
		var bp: Vector3 = _bone(tt, "Spine", tt.global_position + Vector3.UP) + _front(tt) * 0.25
		_pop(pj, bp, 1.6, {"kind": 16.0, "c1": Color(0.85, 0.93, 1.0), "c2": SEAL_BLUE, "c3": Color(0.15, 0.25, 0.6), "nf": 1.0}, 0.3, 2.2)
		_burst(pj, bp, {"n": 14, "v0": 1.5, "v1": 3.5, "g": 0.0, "damp": 3.0, "life": 0.45, "spread": 180.0, "add": true, "mesh": "streak", "align": true,
			"s0": 0.1, "s1": 0.2, "cols": [Color(0.9, 0.95, 1.0), SEAL_BLUE, Color(0.2, 0.4, 1.0, 0)]})
		Combat.popup_text(tt.global_position + Vector3.UP * 2.8, "Mühürlendi: güç yarıya indi", Color(0.9, 0.9, 1))
		Sfx.play("seal", tt.global_position, 0.7)
	pj.after(0.25, press)


# ================================================================== Uzumaki: Shikoku Fūin
## Ref: işaret parmağının ucunda soluk mavi alev. Kullanıcı hedefin önüne geçer, alevli parmakla karna oyma mühür çizer:
## mavi çizgiler (dış/iç çember, çapraz oyma hatları, yazı kuşağı, ortada tek glif) açı açı kazınır, parmaktan mavi
## kıvılcımlar; mühür 10 sn soluk mavi kalır; belin çevresinde dönen yazı halkası 4 sn
static func shikoku_fuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt8 = pj.tg(c, t, 8.0)
	_finger_flame(pj, c, "RightIndexDistal", 1.3, 1.0)
	var tt = pj.tg(c, t, 6.0)
	if tt == null:
		Hud.msg("Mühür için hedefe dokunacak kadar yaklaş (6 m)", Color(0.9, 0.8, 0.6))
	else:
		c.global_position = pj.gp(tt.global_position - (tt.global_position - c.global_position).normalized() * (tt.radius + 0.9))
		pj.anim(c, "cross", 1.4)
		var carve = func():
			if not pj.live(tt):
				return
			var seal = _seal_quad(Vector2(0.56, 0.56), {"kind": 4.0, "c1": Color(0.92, 0.97, 1.0), "c2": SEAL_BLUE, "reveal": 0.0, "glow": 1.0,
				"seed": randf() * 4.0, "nf": 0.8})
			_stick(pj, tt, seal, 10.0, "Spine", 0.2)
			_tp(seal, "reveal", 0.0, 1.0, 0.45)
			_tp(seal, "glow", 1.0, 0.25, 1.5, 0.5)
			_tp(seal, "alpha", 1.0, 0.0, 0.6, 9.3)
			var fp: Vector3 = _bone(tt, "Spine", tt.global_position + Vector3.UP) + _front(tt) * 0.25
			_burst(pj, fp, {"n": 12, "v0": 1.0, "v1": 2.5, "g": 3.0, "life": 0.5, "spread": 120.0, "add": true, "mesh": "streak", "align": true,
				"s0": 0.08, "s1": 0.14, "dir": _front(tt), "cols": [Color(0.95, 0.98, 1.0), SEAL_BLUE, Color(0.2, 0.4, 1.0, 0)]})
			_seal_points(pj, tt, 10.0, Color(0.55, 0.8, 1.0))
			pj.st(tt, "slow", 10.0)
			Sfx.play("seal", tt.global_position)
		pj.after(0.2, carve)
	if tt8:
		var ring = func():
			if pj.live(tt8):
				_script_band(pj, tt8, 0.7, 4.0, SEAL_BLUE, Color(0.08, 0.06, 0.05))
		pj.after(0.4, ring)


# ================================================================== Uzumaki: Fūka Hōin
## Ref: ak kâğıt, iki kenarda lacivert bant, yanlarda mürekkep yazı sütunları, ortası boş — üç kıvrık ok girdap çizer;
## ateş mühürlenince ortada mavi ışıklı yazı halkası içinde kırmızı "火" belirir. Parşömen önünde açılır, oklar ateş
## çektikçe döner; emilen her ateşte turuncu sarmal dil ortaya akar. Salınımda ortadan konturlu cel alev topları sarmal
## bir akıntı hâlinde hedefe döker
static func fuka_hoin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var fd = c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD
	var scroll = Node3D.new()
	pj.get_tree().current_scene.add_child(scroll)
	scroll.global_position = c.global_position + Vector3.UP * 1.25 + fd * 0.65
	scroll.look_at(scroll.global_position + fd, Vector3.UP)
	var paper = _seal_quad(Vector2(1.5, 0.42), {"kind": 5.0, "c1": PAPER, "c2": Color(0.2, 0.22, 0.42), "c3": INK, "aspect": 1.5 / 0.42, "reveal": 0.0,
		"glow": 0.0, "seed": randf() * 7.0, "nf": 0.8})
	scroll.add_child(paper)
	paper.rotation.y = PI
	var rb = MB.new()
	rb.add("cyl", Vector3.ZERO, Vector3(0.09, 0.5, 0.09), Color(0.92, 0.9, 0.84), Vector3.ZERO, 10)
	rb.add("cyl", Vector3(0, 0.27, 0), Vector3(0.06, 0.05, 0.06), Color(0.35, 0.22, 0.12), Vector3.ZERO, 8)
	rb.add("cyl", Vector3(0, -0.27, 0), Vector3(0.06, 0.05, 0.06), Color(0.35, 0.22, 0.12), Vector3.ZERO, 8)
	var rmesh = rb.build(null)
	for sx in [-1.0, 1.0]:   # iki uçta rulolar
		var rl = _cel(rmesh, 0.01, {"nf": 0.8})
		scroll.add_child(rl)
		rl.position = Vector3(sx * 0.77, 0, 0)
	scroll.scale = Vector3(0.05, 1, 1)
	scroll.create_tween().tween_property(scroll, "scale", Vector3.ONE, 0.2)
	var store = {"fire": 0, "spin": 0.0}
	pj.busy(c, 3.0)
	var tick = func(_i, _k):
		if not is_instance_valid(scroll):
			return
		store["spin"] = float(store["spin"]) + 0.08 + 0.12 * minf(3.0, float(store["fire"]))
		paper.set_instance_shader_parameter("reveal", store["spin"])
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and n.shooter != c and Combat.hostile(c, n.shooter) and String(n.info.get("element", "")) in ["katon", "yoton", "enton"]:
				var v = scroll.global_position - n.global_position
				if v.length() < 1.0:
					store["fire"] += 1
					_swirl_in(pj, scroll, n.global_position)
					n.queue_free()
				elif v.length() < 14.0:
					n.vel = v.normalized() * maxf(n.vel.length(), 18.0)   # ateş parşömene çekilir
		# Amaterasu dahil: yakındaki yanan hedefin/yerin ateşi de çekilir
		for e in pj.get_tree().get_nodes_in_group("fighters"):
			if e != c and e.has_method("has_status") and e.has_status("burn") and e.global_position.distance_to(c.global_position) < 8.0:
				e.statuses.erase("burn")
				store["fire"] += 1
				_swirl_in(pj, scroll, e.global_position + Vector3.UP)
	var done = func():
		if is_instance_valid(scroll) and store["fire"] > 0:
			var mark = Label3D.new()
			mark.text = "火"
			mark.font_size = 140
			mark.pixel_size = 0.0032
			mark.modulate = Color(0.9, 0.12, 0.08)
			mark.outline_modulate = Color(0.35, 0.02, 0.02)
			mark.outline_size = 18
			mark.shaded = false
			scroll.add_child(mark)
			mark.position = Vector3(0, 0, 0.012)
			var mark2 = mark.duplicate()
			scroll.add_child(mark2)
			mark2.position = Vector3(0, 0, -0.012)
			mark2.rotation.y = PI
			_tp(paper, "glow", 0.0, 1.0, 0.25)
			Combat.popup_text(scroll.global_position + Vector3.UP * 0.6, "Ateş mühürlendi", Color(1, 0.8, 0.5))
			_fire_release(pj, c, t, scroll, 1.0 + store["fire"] * 0.3, 4.0 * pj.mult(c) * store["fire"])
		if is_instance_valid(scroll):
			var sw = weakref(scroll)
			var fold = func():
				var s2 = sw.get_ref()
				if s2 == null or not is_instance_valid(s2):
					return
				var tw = s2.create_tween()
				tw.tween_property(s2, "scale", Vector3(0.05, 1, 1), 0.3).set_ease(Tween.EASE_IN)
				tw.tween_callback(s2.queue_free)
			pj.after(0.6 if store["fire"] == 0 else 1.0 + store["fire"] * 0.3, fold)
	pj.every(3.0, 1.0 / 20.0, tick, done)
	Sfx.play("seal", c.global_position, 0.8)


## Emilen ateş: turuncu alev dili parşömenin ortasına sarmalla akar
static func _swirl_in(pj: PathJutsu, scroll: Node3D, from: Vector3) -> void:
	var to: Vector3 = scroll.global_position
	var ax: Vector3 = (to - from).normalized()
	var s1: Vector3 = ax.cross(Vector3.UP if absf(ax.y) < 0.95 else Vector3.RIGHT).normalized()
	var s2: Vector3 = ax.cross(s1)
	var pts: Array = []
	var ws: Array = []
	for q in 16:
		var u = float(q) / 15.0
		var a = u * TAU * 1.5
		pts.append(from.lerp(to, u) + (s1 * cos(a) + s2 * sin(a)) * 0.5 * (1.0 - u))
		ws.append(0.28 * (1.0 - u * 0.7))
	var lick = _mi(_mesh([_ribbon(pts, ws)]), _glow_mat())
	_prm(lick, {"c1": Color(1.0, 0.95, 0.6), "c2": Color(1.0, 0.55, 0.12), "c3": Color(0.7, 0.15, 0.05), "pat": 2.0, "reveal": 0.0, "nf": 1.0})
	pj.scene_add(lick, Vector3.ZERO)
	lick.global_transform = Transform3D.IDENTITY
	_tp(lick, "reveal", 0.0, 1.0, 0.15)
	_tp(lick, "tail", 0.0, 1.0, 0.25, 0.15).tween_callback(lick.queue_free)


## Mühürlenmiş ateşin salınımı (Jutsu akıntı mekaniği: 0.15 sn'de bir dört hasar küresi, katon, yanma, element çarpışması);
## görünüş: parşömenin ortasından sarmal akan konturlu cel alev topları
static func _fire_release(pj: PathJutsu, c: Node3D, t: Node3D, scroll: Node3D, dur: float, tick_dmg: float) -> void:
	var el = "katon"
	Sfx.play("fire", c.global_position)
	var sm: SphereMesh
	if _cache.has("mesh:flameball"):
		sm = _cache["mesh:flameball"]
	else:
		sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 14
		sm.rings = 7
		_cache["mesh:flameball"] = sm
	var state = {"stopped": false, "n": 0}
	var ticks = int(dur / 0.15)
	var tw = pj.create_tween()
	for i in ticks:
		var fire_tick = func():
			if not is_instance_valid(c) or state["stopped"]:
				return
			var d: Vector3 = Jutsu._aim(c, t)
			var src: Vector3 = scroll.global_position if is_instance_valid(scroll) else c.global_position + Vector3.UP * 1.3
			# görünüş: üç alev topu sarmal yolda
			for q in 3:
				state["n"] = int(state["n"]) + 1
				var ball = Node3D.new()
				var core = _mi(sm, _blast_mat())
				_prm(core, {"seed": float(state["n"]) * 1.3, "nf": 1.8})
				var ol = _mi(sm, _outline_mat())
				_prm(ol, {"ow": 0.05, "oc": Color(0.4, 0.08, 0.02), "nf": 1.8})
				ball.add_child(core)
				ball.add_child(ol)
				pj.scene_add(ball, src)
				ball.scale = Vector3.ONE * 0.3
				var s1: Vector3 = d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
				var s2: Vector3 = d.cross(s1)
				var ph = float(state["n"]) * 0.9 + q * TAU / 3.0
				var mv = func(u: float):
					if not is_instance_valid(ball):
						return
					var a = ph + u * 5.0
					ball.global_position = src + d * (0.3 + u * 10.0) + (s1 * cos(a) + s2 * sin(a)) * (0.15 + u * 0.9)
					ball.scale = Vector3.ONE * (0.3 + u * 1.6)
					core.set_instance_shader_parameter("prog", u * u)
					ol.set_instance_shader_parameter("alpha", 1.0 - u)
				var bt = ball.create_tween()
				bt.tween_method(mv, 0.0, 1.0, 0.55 + q * 0.05)
				bt.tween_callback(ball.queue_free)
			for pr in pj.get_tree().get_nodes_in_group("projectiles"):
				if pr.dead or pr.element() == "" or pr.shooter == null or not is_instance_valid(pr.shooter) or not Combat.hostile(c, pr.shooter):
					continue
				var rel: Vector3 = pr.global_position - (c.global_position + Vector3.UP * 1.2)
				var along = rel.dot(d)
				if along < 0.5 or along > 10.0 or (rel - d * along).length() > 1.2 + along * 0.2 + pr.radius:
					continue
				var r = Elements.clash({"el": el, "pow": tick_dmg * 6.0}, {"el": pr.element(), "pow": pr.power()})
				_burst(pj, pr.global_position, {"n": 8, "v0": 2.0, "v1": 4.0, "g": 2.0, "life": 0.35, "spread": 180.0, "add": true, "mesh": "streak", "align": true,
					"s0": 0.1, "s1": 0.2, "cols": [Color(1, 0.95, 0.6), Color(1, 0.5, 0.1, 0)]})
				pr.apply_clash(r["b_alive"], r["b_scale"])
				if not r["a_alive"]:
					state["stopped"] = true
					return
			for k in 4:
				Combat.hit_sphere(c, c.global_position + Vector3.UP * 1.2 + d * (2.0 + k * 2.2), 1.2 + k * 0.4,
					{"dmg": tick_dmg, "element": el, "knock": 3.0, "kind": "light", "burn": 1.0 if el == "katon" else 0.0})
		tw.tween_callback(fire_tick)
		tw.tween_interval(0.15)


# ================================================================== Uzumaki: Uzumaki Fūinjutsu
## Ref (Ashina Uzumaki): el yere iner, avuçtan hedefe uzanan dikey mürekkep yazı sütunu; hedefin altında Uzumaki girdabı
## ve tırtıklı yazı halkası açılır. Mühür çalışınca girdap soluk mavi parlar, yerden mürekkep zerreleri yükselir; mühürlenen
## her rakibin gövdesine dönen mürekkep yazı halkası sarılır; alana giren mermiler mürekkep lekesine dağılır
static func uzumaki_fuinjutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	var cen: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var from = pj.gp(c.global_position + d * 0.7)
	# yazı sütunu: elden hedefe zemine yapışık şerit
	var L = from.distance_to(cen)
	var pts: Array = []
	var ws: Array = []
	var nr: Array = []
	var nseg = maxi(2, int(L / 0.5) + 1)
	for q in nseg:
		var p = from.lerp(cen - d * 3.0, float(q) / float(nseg - 1)) if L > 3.5 else from.lerp(cen, float(q) / float(nseg - 1))
		p.y = Game.jutsu_floor(p.x, p.z) + 0.05
		pts.append(p)
		ws.append(0.5)
		nr.append(Vector3.UP)
	var col_len = maxf(0.5, L - 3.0 if L > 3.5 else L)
	var column = _mi(_mesh([_ribbon(pts, ws, nr)]), _seal_mat())
	_prm(column, {"kind": 2.0, "aspect": col_len / 0.5, "c3": INK, "c1": Color(0.7, 0.82, 1.0), "reveal": 0.0, "glow": 0.0, "seed": randf() * 9.0, "nf": 1.2})
	pj.scene_add(column, Vector3.ZERO)
	column.global_transform = Transform3D.IDENTITY
	_tp(column, "reveal", 0.0, 1.0, 0.45)
	pj.free_after(2.4, column)
	var swirl = _decal(pj, cen, 7.2, {"kind": 1.0, "c1": Color(0.75, 0.86, 1.0), "c3": INK, "reveal": 0.0, "glow": 0.0, "seed": randf() * 6.0})
	_tp(swirl, "reveal", 0.0, 1.0, 0.45, 0.35)
	_fade_free(swirl, 1.9, 0.5)
	pj.anim(c, "hook", 1.2)
	Sfx.play("genjutsu", c.global_position, 0.9)
	var seal_it = func():
		if not pj.live(c):
			return
		_tp(swirl, "glow", 1.0, 0.0, 0.8)
		_tp(column, "glow", 1.0, 0.0, 0.6)
		var spin = swirl.create_tween()
		spin.tween_property(swirl, "rotation:y", swirl.rotation.y + PI * 0.6, 0.9).set_ease(Tween.EASE_OUT)
		var li = OmniLight3D.new()
		li.light_color = Color(0.75, 0.85, 1.0)
		li.light_energy = 3.0
		li.omni_range = 7.0
		pj.scene_add(li, cen + Vector3.UP * 0.5)
		var lt = li.create_tween()
		lt.tween_property(li, "light_energy", 0.0, 0.4)
		lt.tween_callback(li.queue_free)
		# mühür yukarı doğru çeker: yerden kalkan mürekkep zerreleri
		_burst(pj, cen + Vector3.UP * 0.1, {"n": 50, "r": 3.0, "dir": Vector3.UP, "spread": 12.0, "v0": 1.0, "v1": 4.0, "g": -0.5, "life": 0.9,
			"mesh": "flake", "s0": 0.08, "s1": 0.16, "cols": [Color(0.03, 0.02, 0.05, 1.0), Color(0.03, 0.02, 0.05, 0.9), Color(0.03, 0.02, 0.05, 0.0)]})
		for e in pj.enemies_near(c, cen, 3.3):
			e.take_hit(pj.inf(c, "uzumaki_fuinjutsu", 1.7, {"knock": 0.0, "kind": "heavy", "hitstop": 0.08}))
			pj.st(e, "bind", 2.5)
			pj.st(e, "sealed", 6.0)
			_seal_points(pj, e, 6.0, Color(0.8, 0.85, 1.0))
			_script_band(pj, e, 0.6, 2.5, Color(0.75, 0.85, 1.0), INK)
			Combat.popup_text(e.global_position + Vector3.UP * 2.6, "Mühürlendi!", Color(0.8, 0.85, 1.0))
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != c and Vector2(p.global_position.x - cen.x, p.global_position.z - cen.z).length() < 3.3:
				_burst(pj, p.global_position, {"n": 10, "v0": 1.0, "v1": 3.0, "g": 6.0, "life": 0.5, "spread": 180.0, "mesh": "flake", "s0": 0.06, "s1": 0.12,
					"cols": [INK, Color(INK.r, INK.g, INK.b, 0)]})
				p.queue_free()
		Sfx.play("genjutsu", cen, 1.6)
	pj.after(0.9, seal_it)


# ================================================================== Uzumaki: Chiyu Kōshō
## Ref (Karin): yaralı, Uzumaki'nin kolunu ısırır; chakra ısırık yerinden ona akar. Kolda iki diş izi ve kan damlası;
## ısırık yerinden hastanın göğsüne yeşil-beyaz chakra akıntısı (çapraz şerit, akan nabız; kendini iyileştirirken bedeni
## saran yükselen sarmal); her iyileşmede hastanın üstünde yeşil zerreler, kullanıcıdan kola mavi chakra zerreleri çekilir
static func chiyu_kosho(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.2)
	# yanında yaralı bir dost varsa o ısırır; yoksa kendi kolunu ısırır
	var who: Node3D = c
	var worst := 1.0
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if f != c and is_instance_valid(f) and not f.is_dead() and f.get("team") == c.get("team") and f.global_position.distance_to(c.global_position) < 2.8:
			var frac: float = f.hp / maxf(1.0, f.max_hp)
			if frac < worst and frac < c.hp / maxf(1.0, c.max_hp):
				worst = frac
				who = f
	Sfx.play("heal", c.global_position, 0.8)
	var arm = pj.hand_pos(c, false) - Vector3.UP * 0.1
	# ısırık: iki diş izi + kan damlaları
	for s in [-1.0, 1.0]:
		var dot = _bill(pj, arm + Vector3(s * 0.035, 0.03, 0), 0.07, {"kind": 19.0, "c2": Color(0.55, 0.05, 0.05), "c3": Color(0.25, 0.0, 0.0), "nf": 0.4})
		pj.free_after(1.2, dot)
	_burst(pj, arm, {"n": 8, "v0": 0.5, "v1": 1.5, "g": 9.8, "life": 0.5, "spread": 180.0, "s0": 0.03, "s1": 0.06,
		"cols": [Color(0.7, 0.05, 0.05, 1.0), Color(0.5, 0.0, 0.0, 0.0)]})
	var cw = weakref(c)
	var wr = weakref(who)
	var self_heal = who == c
	var flow_fn = func() -> Array:
		var cc = cw.get_ref()
		var x = wr.get_ref()
		if cc == null or x == null or not is_instance_valid(cc) or not is_instance_valid(x):
			return []
		var a: Vector3 = pj.hand_pos(cc, false)
		if self_heal:
			var pts: Array = []
			var base: Vector3 = cc.global_position
			for q in 18:
				var u = float(q) / 17.0
				var ang = u * TAU * 2.0 + Time.get_ticks_msec() / 300.0
				pts.append(a.lerp(base + Vector3(cos(ang) * 0.5, 0.2 + u * 1.6, sin(ang) * 0.5), minf(1.0, u * 4.0)))
			return pts
		var b: Vector3 = _chest(x)
		var out: Array = []
		for q in 12:
			var u = float(q) / 11.0
			out.append(a.lerp(b, u) + Vector3.UP * sin(u * PI) * 0.35)
		return out
	_live_strand(pj, _glow_mat(), {"c1": Color(0.95, 1.0, 0.95), "c2": HEAL_G, "c3": Color(0.1, 0.5, 0.25), "pat": 1.0, "spd": 3.0, "alpha": 0.85, "nf": 1.0},
		flow_fn, 1.0, {"w": 0.12})
	var flow = func(i, _k):
		var x = wr.get_ref()
		if x == null or not pj.live(x) or not pj.live(c):
			return
		if i % 3 == 0:
			pj.heal(x, x.max_hp * 0.055)
			if "chakra" in c:
				c.chakra = maxf(0.0, c.chakra - c.max_chakra * 0.03)   # chakrası hızla erir
			_burst(pj, x.global_position + Vector3.UP * 1.0, {"n": 8, "r": 0.5, "dir": Vector3.UP, "spread": 25.0, "v0": 0.6, "v1": 1.8, "g": -0.5, "life": 0.8,
				"add": true, "mesh": "streak", "align": true, "s0": 0.1, "s1": 0.18, "cols": [Color(0.85, 1.0, 0.88), HEAL_G, Color(0.4, 1.0, 0.5, 0.0)]})
			var cc = cw.get_ref()
			if cc != null and is_instance_valid(cc):
				var arm_fn = func() -> Vector3:
					var c3 = cw.get_ref()
					return pj.hand_pos(c3, false) if c3 != null and is_instance_valid(c3) else arm
				for q in 2:
					_mote_to(pj, cc.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.6, 1.6), randf_range(-0.4, 0.4)), arm_fn, 0.35,
						Color(0.45, 0.7, 1.0))
	pj.every(1.0, 0.055, flow)
