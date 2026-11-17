class_name FuinjutsuFXA
extends RefCounted
## Fūinjutsu grubu A: on beş mühür tekniğinin görselleri. Tüm görünüş bu dosyada sıfırdan üretilir: kendi kendini yazan
## mühür yazısı (fırça darbesi darbe darbe çizilir; şerit / çember / ışınsal düzen), kâğıt tılsım (fuda), çakra ipliği,
## amblem (dil mührü, lanet etiketi hedefi, kapı mührü, dört sembol sarmalı, beş element mührü), cel gölgeli katı şekiller
## (kumaş koza, aslan başı, mürekkep kaplan, ejder başı) + koyu kontur. Kameraya yakın kısımlar dağılarak incelir.
## Oynanış (hasar, durum, süre, menzil, hedefleme, bedel) ana ağaçtaki işleyicilerden satır satır taşındı.
## Gerçek oyun sistemleri: Shinigami (Shiki Fūjin), Buffs, Hud, Combat.popup_text, mermi (shot).

const INK := Color(0.06, 0.05, 0.07)
const PAPER := Color(0.95, 0.92, 0.84)
const SEAL_RED := Color(0.62, 0.12, 0.13)
const CLOTH := Color(0.95, 0.93, 0.86)
const BLUEFIRE := Color(0.35, 0.55, 1.0)

static var _cache := {}


# ================================================================== gölgelendiriciler
const COMMON := """
float fh1(float n) { return fract(sin(n * 127.1 + 0.3) * 43758.5453); }
float fh2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float near_cut(vec3 vpos, vec2 fc, float nfd) {
	return step(smoothstep(nfd * 0.4, nfd, length(vpos)), fh2(floor(fc)));
}
float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return length(pa - ba * h);
}
float sd_segp(vec2 p, vec2 a, vec2 b, float prog) {
	if (prog <= 0.0) { return 1000.0; }
	return sd_seg(p, a, mix(a, b, clamp(prog, 0.0, 1.0)));
}
"""

## Mühür yazısı: hücre başına rastgele kanji benzeri glif (3-5 darbe); her darbe sırayla, baştan uca kendini çizer
## (reveal). lay 0 = şerit / kâğıt (hücre ızgarası), 1 = çember mühür formülü (çift halka + yazı halkası + kollar + orta
## sarmal), 2 = ışınsal patlama (yazı sütunları merkezden dışa yayılır). style 0 = köşeli, 1 = tırtıklı el yazısı,
## 2 = karalama çizgi (Gansōkō tılsımı), 3/4 = tahta perdeli + 0/1, 5 = fırça kaplan çizimi.
const SCRIPT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float reveal = 1.0;
instance uniform float alpha = 1.0;
instance uniform float seed = 0.0;
instance uniform float nf = 1.5;
instance uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.07, 1.0);
instance uniform vec4 paper : source_color = vec4(0.95, 0.92, 0.84, 0.0);
instance uniform vec4 edge : source_color = vec4(0.0, 0.0, 0.0, 0.0);
instance uniform vec2 grid = vec2(1.0, 4.0);
instance uniform float lay = 0.0;
instance uniform float style = 0.0;
instance uniform float flap = 0.0;
instance uniform float inner = 0.3;

COMMON

float glyph(vec2 q, float id, float prog, float st) {
	float dmin = 1000.0;
	int n = 3 + int(fh1(id * 3.7) * 2.99);
	float fn = float(n);
	for (int k = 0; k < 5; k++) {
		if (k >= n) { break; }
		float fk = float(k);
		float lp = clamp(prog * fn - fk, 0.0, 1.0);
		if (lp <= 0.0) { break; }
		float r1 = fh1(id * 7.13 + fk * 1.91);
		float r2 = fh1(id * 3.31 + fk * 5.17);
		float r3 = fh1(id * 9.71 + fk * 2.43);
		float r4 = fh1(id * 1.17 + fk * 8.09);
		vec2 na = vec2(floor(r1 * 2.99), floor(r2 * 2.99)) * 0.5;
		vec2 a = na;
		vec2 b = na;
		if (r3 < 0.42) {
			a = vec2(r4 * 0.35, na.y);
			b = vec2(1.0 - fh1(id + fk * 3.3) * 0.35, na.y + (r4 - 0.5) * 0.15);
		} else if (r3 < 0.78) {
			a = vec2(na.x, r4 * 0.25);
			b = vec2(na.x + (r4 - 0.5) * 0.12, 1.0 - r1 * 0.2);
		} else if (r3 < 0.92) {
			b = vec2(1.0 - na.x, clamp(na.y + 0.5, 0.0, 1.0));
		} else {
			b = na + vec2(0.16, 0.14);
		}
		if (st > 0.5) {
			a += (vec2(r2, r4) - 0.5) * 0.3;
			b += (vec2(r1, r3) - 0.5) * 0.3;
		}
		a = 0.14 + a * 0.72;
		b = 0.14 + b * 0.72;
		vec2 e = mix(a, b, lp);
		vec2 pa = q - a;
		vec2 ba = e - a;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
		float d = length(pa - ba * h);
		float w = 0.07 * mix(1.3, 0.6, h * lp);
		if (st > 0.5) { w *= 0.5 + 0.9 * fh1(floor(h * lp * 7.0) + id * 3.0 + fk); }
		dmin = min(dmin, d - w);
	}
	return dmin;
}

float scribble(vec2 uv, float prog, float sd) {
	float d = 1000.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float lp = clamp(prog * 1.6 - fi * 0.1, 0.0, 1.0);
		float y = 0.12 + fi * 0.15 + sin(uv.x * 7.0 + fi * 2.1 + sd) * 0.04;
		if (uv.x < lp) { d = min(d, abs(uv.y - y) - 0.02); }
		float x = 0.1 + fi * 0.16 + sin(uv.y * 6.0 + fi * 1.3 + sd) * 0.04;
		if (uv.y < lp) { d = min(d, abs(uv.x - x) - 0.014); }
	}
	if (prog > 0.6) {
		d = min(d, abs(length((uv - vec2(0.3, 0.35)) * vec2(1.0, 0.6)) - 0.09) - 0.014);
		d = min(d, abs(length((uv - vec2(0.68, 0.7)) * vec2(1.0, 0.6)) - 0.07) - 0.014);
	}
	return d;
}

float tigerdraw(vec2 uv, float prog) {
	vec2 c = (uv - vec2(0.46, 0.55)) * vec2(1.0, 1.7);
	float body = length(c) - 0.33;
	float d = abs(body) - 0.014;
	d = min(d, abs(length((uv - vec2(0.82, 0.4)) * vec2(1.0, 1.4)) - 0.1) - 0.014);
	d = min(d, sd_seg(uv, vec2(0.14, 0.5), vec2(0.04, 0.22)) - 0.012);
	if (body < 0.0) {
		float s = sin(uv.x * 46.0 + sin(uv.y * 9.0) * 2.0);
		if (s > 0.55) { d = min(d, -0.01); }
	}
	if (uv.x > prog) { d = 1000.0; }
	return d;
}

void vertex() {
	if (flap > 0.0) {
		VERTEX.z += sin(UV.y * 5.0 + TIME * 11.0 + seed * 3.0) * flap * (0.3 + UV.y);
	}
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	vec2 uv = UV;
	float st = style;
	float planks = 0.0;
	if (st > 2.5 && st < 4.5) { planks = 1.0; st -= 3.0; }
	float pm = 0.0;
	float dk = 1000.0;
	float lines = 1000.0;
	if (lay < 0.5) {
		pm = 1.0;
		if (st > 1.5 && st < 2.5) {
			lines = scribble(uv, reveal, seed);
		} else if (st > 4.5) {
			lines = tigerdraw(uv, reveal);
		} else {
			vec2 cuv = uv * grid;
			vec2 cell = floor(cuv);
			float idx = cell.x * grid.y + cell.y;
			float prog = clamp(reveal * grid.x * grid.y - idx, 0.0, 1.0);
			float id = fh2(cell + vec2(seed, seed * 1.37)) * 97.0 + 1.0;
			dk = glyph(fract(cuv), id, prog, st);
		}
		if (paper.a > 0.01) {
			float m = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
			lines = min(lines, abs(m - 0.045) - 0.008);
		}
	} else if (lay < 1.5) {
		vec2 c = uv * 2.0 - 1.0;
		float r = length(c);
		if (r > 1.0) { discard; }
		float an = atan(c.y, c.x) / 6.2831853 + 0.5;
		if (an <= clamp(reveal * 2.0, 0.0, 1.0)) {
			lines = min(abs(r - 0.955) - 0.014, abs(r - 0.885) - 0.006);
			lines = min(lines, abs(r - inner) - 0.01);
		}
		float tr = (r - inner - 0.03) / (0.85 - inner - 0.03);
		if (tr > 0.0 && tr < 1.0) {
			vec2 cuv = vec2(an * grid.x, tr * grid.y);
			vec2 cell = floor(cuv);
			float prog = clamp(reveal * 1.25 * grid.x - cell.x - cell.y * 0.5, 0.0, 1.0);
			float id = fh2(cell + vec2(seed, seed * 1.37)) * 97.0 + 1.0;
			dk = glyph(fract(cuv), id, prog, st);
		}
		if (r < inner * 0.92) {
			float sp = (0.5 - abs(fract(an * 8.0) - 0.5)) / 8.0 * 6.2831853 * r;
			if (r > inner * 0.45 && r < reveal * inner * 1.2) { lines = min(lines, sp - 0.006); }
			float t = r / (inner * 0.11) - an;
			float sd = abs(fract(t + 0.5) - 0.5) * inner * 0.11;
			if (r < inner * 0.4 && r < reveal * inner) { lines = min(lines, sd - 0.006); }
		}
	} else {
		vec2 c = uv * 2.0 - 1.0;
		float r = length(c);
		if (r > 1.0) { discard; }
		float an = atan(c.y, c.x) / 6.2831853 + 0.5;
		float N = grid.x;
		float cs = 0.95 / grid.y;
		float sector = floor(an * N);
		float across = (fract(an * N) - 0.5) / N * 6.2831853 * r;
		float ring = floor(r / cs);
		float jit = fh2(vec2(sector, ring) + vec2(seed));
		if (abs(across) < cs * 0.5 && ring >= 1.0 && r < 0.95 && jit > 0.22) {
			vec2 q = vec2(across / cs + 0.5, fract(r / cs));
			float prog = clamp(reveal * grid.y * 1.1 - ring, 0.0, 1.0);
			dk = glyph(q, jit * 97.0 + 1.0, prog, st);
		}
		if (r < cs * 0.9 && reveal > 0.02) { lines = abs(r - cs * 0.55) - 0.012; }
		float sp = (0.5 - abs(fract(an * N) - 0.5)) / N * 6.2831853 * r;
		if (r > cs && r < reveal * 0.95 && fh1(sector + seed) > 0.5) { lines = min(lines, sp - 0.004); }
	}
	float aa = min(fwidth(dk), 0.08) + 0.004;
	float core = 1.0 - smoothstep(-aa, aa, dk);
	float wide = 1.0 - smoothstep(0.06 - aa, 0.06 + aa, dk);
	float la = min(fwidth(lines), 0.05) + 0.002;
	core = max(core, 1.0 - smoothstep(-la, la, lines));
	wide = max(wide, 1.0 - smoothstep(0.02 - la, 0.02 + la, lines));
	vec3 col = paper.rgb;
	float a = paper.a * pm;
	if (planks > 0.5) {
		float s = (0.5 - abs(fract(uv.x * grid.x * 0.5) - 0.5)) / (grid.x * 0.5);
		col = mix(col, ink.rgb, (1.0 - smoothstep(0.0012, 0.0025, s)) * 0.35);
	}
	col = mix(col, edge.rgb, wide * edge.a);
	a = max(a, wide * edge.a);
	col = mix(col, ink.rgb, core);
	a = max(a, core * ink.a);
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Amblem: yöntemle çizilen tek mühür işareti (kind). Darbeler sırayla çizilir (reveal). bb = kameraya dönük.
## 0 dil mührü, 1 lanet etiketi hedefi, 2 kapı (閉) elması, 3 dört sembol sarmalı, 4 beş element mührü,
## 5 ruh alevi (hitodama), 6 çakra ışık diski, 7 parmak ucu alevi, 8 avuç sarmalı, 9 mürekkep lekesi
const EMBLEM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float reveal = 1.0;
instance uniform float alpha = 1.0;
instance uniform float nf = 1.2;
instance uniform float bb = 1.0;
instance uniform float seed = 0.0;
instance uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.07, 1.0);
instance uniform vec4 fill : source_color = vec4(0.95, 0.93, 0.86, 1.0);
instance uniform vec4 accent : source_color = vec4(0.62, 0.12, 0.13, 1.0);

COMMON

void vertex() {
	if (bb > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	vec2 p = (UV * 2.0 - 1.0) * vec2(1.0, -1.0);
	float r = length(p);
	float an = atan(p.y, p.x);
	float ar = an / 6.2831853 + 0.5;
	vec3 col = fill.rgb;
	float a = 0.0;
	float dk = 1000.0;
	float halo = 0.0;
	if (kind < 0.5) {
		float tl = length((p - vec2(0.0, -0.08)) * vec2(1.0, 0.9));
		a = (1.0 - smoothstep(0.9, 0.92, tl)) * fill.a * clamp(reveal * 4.0, 0.0, 1.0);
		if (tl > 0.8) { col = accent.rgb; }
		float rv = reveal * 7.5;
		float d = 1000.0;
		d = min(d, sd_segp(p, vec2(-0.2, 0.62), vec2(0.08, 0.4), rv * 2.0));
		d = min(d, sd_segp(p, vec2(0.08, 0.4), vec2(0.63, 0.22), rv * 2.0 - 1.0));
		d = min(d, sd_segp(p, vec2(-0.32, 0.45), vec2(0.0, 0.2), (rv - 1.0) * 2.0));
		d = min(d, sd_segp(p, vec2(0.0, 0.2), vec2(0.57, 0.02), (rv - 1.0) * 2.0 - 1.0));
		d = min(d, sd_segp(p, vec2(-0.42, 0.27), vec2(-0.08, 0.0), (rv - 2.0) * 2.0));
		d = min(d, sd_segp(p, vec2(-0.08, 0.0), vec2(0.5, -0.18), (rv - 2.0) * 2.0 - 1.0));
		d = min(d, sd_segp(p, vec2(-0.52, 0.07), vec2(-0.17, -0.23), rv - 3.0));
		d = min(d, sd_segp(p, vec2(-0.05, -0.28), vec2(0.42, -0.4), rv - 4.0));
		d = min(d, sd_segp(p, vec2(-0.62, -0.13), vec2(-0.28, -0.47), rv - 5.0));
		d = min(d, sd_segp(p, vec2(-0.15, -0.48), vec2(0.33, -0.63), rv - 6.0));
		dk = d - 0.065;
	} else if (kind < 1.5) {
		float g = max(clamp(reveal * 1.4, 0.0, 1.0), 0.01);
		vec2 q = p / g;
		float s = pow(abs(q.x), 0.66) + pow(abs(q.y), 0.66);
		a = (1.0 - smoothstep(0.88, 0.92, s)) * fill.a;
		dk = abs(s - 0.88) - 0.035;
		float rq = length(q);
		if (abs(rq - 0.27) < 0.065) { col = vec3(0.1, 0.52, 0.56); }
		dk = min(dk, abs(abs(rq - 0.27) - 0.065) - 0.01);
		if (length(q - vec2(0.0, -0.03)) < 0.085 || length(q - vec2(0.0, 0.07)) < 0.05) { col = accent.rgb; }
		if (length(q - vec2(0.0, 0.5)) < 0.035 || length(q - vec2(0.0, -0.5)) < 0.035) { col = accent.rgb; }
	} else if (kind < 2.5) {
		float g = max(clamp(reveal * 3.0, 0.0, 1.0), 0.01);
		float dd = (abs(p.x) + abs(p.y)) / g;
		a = (1.0 - smoothstep(0.88, 0.91, dd)) * fill.a;
		float d = abs(dd - 0.82) - 0.06;
		float rv = clamp(reveal * 1.5 - 0.5, 0.0, 1.0) * 11.0;
		d = min(d, sd_segp(p, vec2(-0.36, 0.42), vec2(-0.36, -0.42), rv) - 0.04);
		d = min(d, sd_segp(p, vec2(-0.36, 0.42), vec2(-0.07, 0.42), rv - 1.0) - 0.04);
		d = min(d, sd_segp(p, vec2(-0.07, 0.42), vec2(-0.07, 0.18), rv - 2.0) - 0.04);
		d = min(d, sd_segp(p, vec2(-0.36, 0.3), vec2(-0.07, 0.3), rv - 3.0) - 0.035);
		d = min(d, sd_segp(p, vec2(0.07, 0.42), vec2(0.36, 0.42), rv - 4.0) - 0.04);
		d = min(d, sd_segp(p, vec2(0.07, 0.42), vec2(0.07, 0.18), rv - 5.0) - 0.04);
		d = min(d, sd_segp(p, vec2(0.07, 0.3), vec2(0.36, 0.3), rv - 6.0) - 0.035);
		d = min(d, sd_segp(p, vec2(0.36, 0.42), vec2(0.36, -0.42), rv - 7.0) - 0.04);
		d = min(d, sd_segp(p, vec2(-0.2, 0.02), vec2(0.22, 0.02), rv - 8.0) - 0.04);
		d = min(d, sd_segp(p, vec2(0.07, 0.14), vec2(0.07, -0.34), rv - 9.0) - 0.04);
		d = min(d, sd_segp(p, vec2(0.07, -0.02), vec2(-0.18, -0.28), rv - 10.0) - 0.035);
		dk = d;
	} else if (kind < 4.5) {
		bool five = kind > 3.5;
		float d = 1000.0;
		float sr = five ? 0.32 : 0.5;
		float stp = five ? 0.08 : 0.13;
		float t = (r - 0.04) / stp - ar;
		float sp = abs(fract(t + 0.5) - 0.5) * stp;
		if (r < sr * clamp(reveal * 1.6, 0.0, 1.0) && r > 0.02) { d = min(d, sp - 0.022); }
		float rr = five ? 0.4 : 0.62;
		if (ar < clamp(reveal * 2.0 - 0.6, 0.0, 1.0)) { d = min(d, abs(r - rr) - 0.022); }
		float mp = clamp(reveal * 2.0 - 1.0, 0.0, 1.0);
		if (five) {
			if (ar < mp) { d = min(d, abs(r - 0.9) - 0.02); }
			for (int i = 0; i < 5; i++) {
				float ang = float(i) * 1.2566371 + 1.5707963;
				vec2 dir = vec2(cos(ang), sin(ang));
				vec2 tg = vec2(-dir.y, dir.x);
				vec2 cc = dir * 0.64;
				d = min(d, sd_segp(p, cc - tg * 0.1, cc + tg * 0.1, mp) - 0.02);
				d = min(d, sd_segp(p, cc - dir * 0.1, cc + dir * 0.1, mp) - 0.02);
				vec2 sd2 = vec2(cos(ang + 0.6283), sin(ang + 0.6283));
				d = min(d, sd_segp(p, sd2 * 0.42, sd2 * 0.88, mp) - 0.012);
			}
		} else {
			for (int i = 0; i < 4; i++) {
				float ang = float(i) * 1.5707963;
				vec2 dir = vec2(cos(ang), sin(ang));
				vec2 tg = vec2(-dir.y, dir.x);
				for (int j = 0; j < 2; j++) {
					vec2 cc = dir * (0.76 + float(j) * 0.1);
					d = min(d, sd_segp(p, cc - tg * 0.12, cc + tg * 0.12, mp) - 0.022);
				}
			}
		}
		dk = d;
		halo = 1.0;
	} else if (kind < 5.5 || (kind > 6.5 && kind < 7.5)) {
		bool flame = kind > 6.5;
		float yy = p.y + 0.4;
		float wy = 0.0;
		if (yy < 0.0) { wy = sqrt(max(0.1764 - yy * yy, 0.0)); }
		else { wy = 0.42 * pow(max(1.0 - yy / 1.3, 0.0), flame ? 1.2 : 1.6); }
		if (flame) { wy *= 0.85 + 0.15 * sin(TIME * 20.0 + seed); }
		float x = p.x - sin(TIME * 4.0 + p.y * 3.5 + seed) * 0.08 * max(yy, 0.0);
		float e = abs(x) / max(wy, 0.001);
		if (flame) {
			col = (e < 0.5 && yy < 0.55) ? fill.rgb : accent.rgb;
			a = 1.0 - smoothstep(0.9, 1.0, e);
		} else {
			col = mix(fill.rgb, accent.rgb, smoothstep(0.35, 0.9, e));
			a = (1.0 - smoothstep(0.85, 1.0, e)) * 0.85;
		}
	} else if (kind < 6.5) {
		col = r < 0.3 ? fill.rgb : (r < 0.6 ? mix(fill.rgb, accent.rgb, 0.5) : accent.rgb);
		a = r < 0.6 ? 0.9 : 0.55 * (1.0 - smoothstep(0.8, 1.0, r));
		if (abs(r - (0.2 + 0.75 * reveal)) < 0.05) { col = fill.rgb; a = 1.0; }
	} else if (kind < 8.5) {
		float arms = abs(fract(ar * 3.0 + r * 1.6 - TIME * 2.5) - 0.5);
		col = arms < 0.18 ? fill.rgb : accent.rgb;
		a = (1.0 - smoothstep(0.75, 0.95, r)) * (arms < 0.18 ? 1.0 : 0.6);
		if (r < 0.2) { col = fill.rgb; a = 1.0; }
	} else {
		float n = sin(an * 5.0 + seed) * 0.1 + sin(an * 11.0 + seed * 2.0) * 0.06 + sin(an * 23.0) * 0.03;
		float body = r - (0.5 + n) * clamp(reveal * 2.0, 0.0, 1.0);
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float ang = fh1(seed + fi) * 6.2831853;
			float rad = (0.68 + fh1(seed * 3.0 + fi) * 0.25) * clamp(reveal * 1.5, 0.0, 1.0);
			body = min(body, length(p - vec2(cos(ang), sin(ang)) * rad) - (0.03 + 0.06 * fh1(fi * 7.0 + seed)));
		}
		dk = body;
	}
	float aa = min(fwidth(dk), 0.05) + 0.003;
	float ik = 1.0 - smoothstep(-aa, aa, dk);
	if (halo > 0.5) {
		float hk = 1.0 - smoothstep(0.04 - aa, 0.04 + aa, dk);
		a = max(a, hk * fill.a * 0.8);
	}
	col = mix(col, ink.rgb, ik);
	a = max(a, ik * ink.a);
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Şerit / tüp ışığı. UV.x boy (reveal ile baştan uca çizilir), UV.y en / çevre.
## pat 0 çakra ipliği, 1 ejder gövdesi, 2 ruh, 3 lanet sarmaşığı, 4 kumaş şerit, 5 ölüm tanrısı kolu, 6 mürekkep bant, 7 bulut girdabı
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 c1 : source_color = vec4(1.0, 0.9, 0.9, 1.0);
instance uniform vec4 c2 : source_color = vec4(1.0, 0.3, 0.35, 1.0);
instance uniform float alpha = 1.0;
instance uniform float pat = 0.0;
instance uniform float nf = 1.5;
instance uniform float reveal = 1.0;
instance uniform float seed = 0.0;

COMMON

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	float u = UV.x;
	float v = UV.y;
	if (u > reveal) { discard; }
	float fres = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 col = c2.rgb;
	float a = 1.0;
	float ac = abs(v - 0.5) * 2.0;
	if (pat < 0.5) {
		col = mix(c2.rgb, c1.rgb, 1.0 - smoothstep(0.12, 0.4, ac));
		a = 1.0 - smoothstep(0.55, 1.0, ac);
	} else if (pat < 1.5) {
		float fl = sin(u * 26.0 - TIME * 9.0 + sin(v * 12.566) * 1.5 + seed);
		col = fl > 0.55 ? c1.rgb : c2.rgb;
		if (fres < 0.28) { col = c2.rgb * 0.35; }
		a = 0.95;
	} else if (pat < 2.5) {
		float sw = sin(u * 18.0 - TIME * 6.0 + v * 8.0 + seed);
		col = mix(c2.rgb, c1.rgb, step(0.3, sw) * 0.6 + 0.2);
		a = (1.0 - smoothstep(0.45, 1.0, ac)) * 0.7 * (1.0 - u * 0.6);
	} else if (pat < 3.5) {
		float w = (0.35 + 0.45 * fh1(floor(u * 34.0) + seed * 7.0)) * (1.0 - smoothstep(0.8, 1.0, u));
		if (ac < w) { col = c1.rgb; a = 1.0; }
		else if (ac < w + 0.25) { col = c2.rgb; a = 0.75; }
		else { a = 0.0; }
	} else if (pat < 4.5) {
		col = c1.rgb;
		if (min(v, 1.0 - v) < 0.08) { col = c2.rgb; }
		if (abs(fract(u * 14.0) - 0.5) < 0.02) { col = mix(col, c2.rgb, 0.5); }
	} else if (pat < 5.5) {
		col = c1.rgb;
		float ring = fract(u * 7.0);
		if (ring < 0.16 && abs(fract(v * 10.0 + u * 3.0) - 0.5) < 0.32) { col = c2.rgb; }
		if (fres < 0.3) { col = c2.rgb; }
	} else if (pat < 6.5) {
		col = ac > 0.7 ? c2.rgb : c1.rgb;
	} else {
		col = v < 0.32 ? c2.rgb : c1.rgb;
		if (ac > 0.88) { col = c2.rgb * 0.6; }
		a = 0.95 * (1.0 - smoothstep(0.85, 1.0, u));
	}
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Cel gölgeli katı şekil (iki ton). pat 0 düz, 1 kumaş koza (sargı + ip çaprazı + kırmızı mühür, reveal = alttan sarılma),
## 2 aslan başı halkaları, 3 kaplan çizgileri (seed>0.5 bacak), 4 burgulu ip, 5 parşömen kâğıdı (mor kenar), 6 kırmızı-beyaz rulo
const SHAPE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

instance uniform vec4 body : source_color = vec4(0.95, 0.93, 0.86, 1.0);
instance uniform vec4 line : source_color = vec4(0.06, 0.05, 0.07, 1.0);
instance uniform float pat = 0.0;
instance uniform float reveal = 100.0;
instance uniform float alpha = 1.0;
instance uniform float nf = 2.0;
instance uniform float seed = 0.0;

COMMON

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	if (fh2(floor(FRAGCOORD.xy) + vec2(seed)) > alpha) { discard; }
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float sh = dot(wn, normalize(vec3(0.42, 0.82, 0.38))) > -0.15 ? 1.0 : 0.74;
	vec3 col = body.rgb * COLOR.rgb;
	float ln = 0.0;
	if (pat > 0.5 && pat < 1.5) {
		if (lp.y + 0.5 > reveal) { discard; }
		float an = atan(lp.z, lp.x);
		if (abs(fract((lp.y + an * 0.006) / 0.072) - 0.5) > 0.46) { ln = 1.0; }
		float sg = fh1(floor((lp.y + 0.5) / 0.072) * 3.1 + floor(an * 3.0));
		if (sg > 0.5 && abs(fract(an * 0.477 + sg) - 0.5) < 0.008) { ln = 1.0; }
		float rope = min(abs(abs(lp.x) - abs(lp.y) * 0.62), abs(abs(lp.x) - 0.03));
		if (rope < 0.022) { col = line.rgb * (fract(lp.y * 40.0) < 0.5 ? 1.0 : 2.2); ln = 0.0; }
		if (lp.z > 0.0 && max(abs(lp.x), abs(lp.y)) < 0.06) { col = vec3(0.62, 0.12, 0.13); }
	} else if (pat > 1.5 && pat < 2.5) {
		float ang = acos(clamp(normalize(lp).z, -1.0, 1.0));
		if (abs(ang - 0.42) < 0.018 || abs(ang - 0.64) < 0.018 || abs(ang - 0.88) < 0.018) { ln = 1.0; }
		if (!FRONT_FACING) { col *= 0.4; }
	} else if (pat > 2.5 && pat < 3.5) {
		float s = sin(lp.z * 11.0 + sin(lp.y * 6.0 + lp.x * 3.0) * 1.4);
		if (seed > 0.5) {
			if (sin(lp.y * 18.0 + lp.x * 4.0) > 0.7) { ln = 1.0; }
		} else if (s > 0.55 && lp.y > 0.72) {
			ln = 1.0;
		}
	} else if (pat > 3.5 && pat < 4.5) {
		if (abs(fract(UV.x * 60.0 + UV.y) - 0.5) < 0.07) { ln = 1.0; }
	} else if (pat > 4.5 && pat < 5.5) {
		if (min(UV.x, 1.0 - UV.x) < 0.05 || min(UV.y, 1.0 - UV.y) < 0.025) { col = line.rgb; }
	} else if (pat > 5.5) {
		col = fract(lp.y * 5.0) < 0.5 ? vec3(0.58, 0.12, 0.14) : body.rgb;
	}
	if (ln > 0.5) { col = mix(col, line.rgb, 0.85); }
	ALBEDO = col * sh;
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

instance uniform float ow = 0.03;
instance uniform float alpha = 1.0;
instance uniform float nf = 2.0;
instance uniform float reveal = 100.0;
instance uniform float seed = 0.0;
instance uniform vec4 oc : source_color = vec4(0.04, 0.03, 0.05, 1.0);

COMMON

varying vec3 lp;

void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * ow;
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) { discard; }
	if (fh2(floor(FRAGCOORD.xy) + vec2(seed)) > alpha) { discard; }
	if (lp.y + 0.5 > reveal) { discard; }
	ALBEDO = oc.rgb;
}
"""


# ================================================================== malzeme / düğüm yardımcıları
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("COMMON", COMMON)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _script_mat() -> ShaderMaterial:
	return _mat("script", SCRIPT_SHADER)


static func _emblem_mat() -> ShaderMaterial:
	return _mat("emblem", EMBLEM_SHADER)


static func _glow_mat() -> ShaderMaterial:
	return _mat("glow", GLOW_SHADER)


static func _shape_mat(two_sided := false) -> ShaderMaterial:
	if two_sided:
		return _mat("shape2", SHAPE_SHADER.replace("cull_back", "cull_disabled"))
	return _mat("shape", SHAPE_SHADER)


static func _outline_mat() -> ShaderMaterial:
	return _mat("outline", OUTLINE_SHADER)


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _params(mi: GeometryInstance3D, prm: Dictionary) -> void:
	for k in prm:
		mi.set_instance_shader_parameter(k, prm[k])


## Düğüm ve altındaki tüm görsellere aynı örnek parametresini yazar
static func _all(n: Node, key: String, val) -> void:
	if not is_instance_valid(n):
		return
	if n is GeometryInstance3D:
		n.set_instance_shader_parameter(key, val)
	for ch in n.get_children():
		_all(ch, key, val)


## Örnek parametresini a → b arasında ilerletir (düğümle birlikte ölür)
static func _tp(n: Node, key: String, a: float, b: float, dur: float, delay := 0.0) -> Tween:
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(n):
			_all(n, key, v), a, b, maxf(dur, 0.01))
	return tw


static func _fade_free(n: Node, delay: float, dur: float) -> void:
	var tw = _tp(n, "alpha", 1.0, 0.0, dur, delay)
	tw.tween_callback(n.queue_free)


static func _add(pj: PathJutsu, n: Node3D, pos: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func _quad(size: Vector2, sub := false) -> QuadMesh:
	var key = "quad_%.3f_%.3f_%d" % [size.x, size.y, 1 if sub else 0]
	if not _cache.has(key):
		var qm = QuadMesh.new()
		qm.size = size
		if sub:
			qm.subdivide_width = 3
			qm.subdivide_depth = 8
		_cache[key] = qm
	return _cache[key]


## Mühür yazısı yüzeyi (kâğıt, şerit, formül)
static func _script_quad(size: Vector2, prm: Dictionary) -> MeshInstance3D:
	var mi = _mi(_quad(size, float(prm.get("flap", 0.0)) > 0.0), _script_mat())
	_params(mi, prm)
	return mi


## Yere çizilen mühür formülü
static func _ground_seal(pj: PathJutsu, at: Vector3, r: float, prm: Dictionary) -> MeshInstance3D:
	var mi = _script_quad(Vector2(r * 2.0, r * 2.0), prm)
	mi.rotation.x = -PI * 0.5
	_add(pj, mi, at + Vector3.UP * 0.04)
	return mi


static func _emblem(kind: float, size: float, prm: Dictionary) -> MeshInstance3D:
	var mi = _mi(_quad(Vector2(size, size)), _emblem_mat())
	var p = {"kind": kind}
	p.merge(prm, true)
	_params(mi, p)
	return mi


## Cel katı şekil + koyu kontur kabuğu
static func _cel(mesh: Mesh, body: Color, pat: float, ow: float, prm := {}, two_sided := false) -> Node3D:
	var root = Node3D.new()
	var m = _mi(mesh, _shape_mat(two_sided))
	var p = {"body": body, "pat": pat}
	p.merge(prm, true)
	_params(m, p)
	root.add_child(m)
	if ow > 0.0:
		var ol = _mi(mesh, _outline_mat())
		var q = {"ow": ow}
		for k in ["reveal", "nf", "seed"]:
			if prm.has(k):
				q[k] = prm[k]
		_params(ol, q)
		root.add_child(ol)
	return root


static func _sphere_mesh() -> SphereMesh:
	if not _cache.has("sphere"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 28
		s.rings = 14
		_cache["sphere"] = s
	return _cache["sphere"]


static func _h(t: Node3D) -> float:
	return float(t.get("height")) if t.get("height") != null else 1.8


static func _bone(c: Node3D, bone: String, fb: Vector3) -> Vector3:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.get("skel") != null and m.skel:
		var bi = m.skel.find_bone(bone)
		if bi >= 0:
			return (m.skel.global_transform * m.skel.get_bone_global_pose(bi)).origin
	return c.global_position + fb


static func _flat_dir(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD


static func _label(txt: String, px: float, col: Color, oc: Color) -> Label3D:
	var l = Label3D.new()
	l.text = txt
	l.font_size = 128
	l.pixel_size = px
	l.modulate = col
	l.outline_modulate = oc
	l.outline_size = 28
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	return l


static func _shrink_curve() -> Curve:
	if not _cache.has("shrink"):
		var cv = Curve.new()
		cv.add_point(Vector2(0.0, 1.0))
		cv.add_point(Vector2(1.0, 0.0))
		_cache["shrink"] = cv
	return _cache["shrink"]


## Kendi ayarlı parçacık püskürtmesi (mürekkep damlası, kâğıt kırpıntısı, kıvılcım). parent verilirse onu izler (iz).
static func _spray(pj: PathJutsu, pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	var one: bool = o.get("one_shot", true)
	p.one_shot = one
	p.amount = int(o.get("n", 16))
	p.lifetime = float(o.get("life", 0.8))
	p.explosiveness = float(o.get("expl", 0.9 if one else 0.0))
	var mesh: Mesh = o.get("mesh", null)
	if mesh == null:
		if not _cache.has("drop"):
			var sm = SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 6
			sm.rings = 3
			_cache["drop"] = sm
		mesh = _cache["drop"]
	p.mesh = mesh
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = o.get("col", INK)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if o.get("surface", false):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.15))
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 60.0))
	p.initial_velocity_min = float(o.get("v0", 2.0))
	p.initial_velocity_max = float(o.get("v1", 5.0))
	p.gravity = Vector3(0, -float(o.get("grav", 9.8)), 0)
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0))
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.angular_velocity_min = -float(o.get("spin", 0.0))
	p.angular_velocity_max = float(o.get("spin", 0.0))
	p.scale_amount_min = float(o.get("s0", 0.05))
	p.scale_amount_max = float(o.get("s1", 0.1))
	p.scale_amount_curve = _shrink_curve()
	var parent: Node3D = o.get("parent", null)
	if parent:
		p.local_coords = false
		parent.add_child(p)
		p.position = o.get("off", Vector3.ZERO)
	else:
		_add(pj, p, pos)
	p.emitting = true
	if one:
		pj.free_after(p.lifetime + 0.5, p)
	return p


# ================================================================== geometri
static func _arrays(v: PackedVector3Array, nr: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array) -> Array:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Tüp: pts boyunca yarıçap dizisi; UV.x boy (0..1), UV.y çevre. Yan vektör eğri boyunca taşınır (burulma yok).
static func _tube(pts: Array, radii: Array, sides := 8) -> Array:
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


## Şerit. nrms verilirse tek yüzey o normale dik yayılır (beden üstü bant); twist >= 0 ise tek burgulu şerit;
## ikisi de yoksa her açıdan görünen çapraz çift şerit. UV.x boy, UV.y en.
static func _ribbon(pts: Array, ws: Array, nrms: Array = [], twist := -1.0) -> Array:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var n = pts.size()
	var strips = 1 if (not nrms.is_empty() or twist >= 0.0) else 2
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
				if twist >= 0.0:
					nm = nm.rotated(tn, twist * PI * float(i) / maxf(n - 1, 1))
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


## İki hareketli uç arasında her kare yeniden kurulan şerit / tüp (iplik, kumaş, kol, ruh). o: n, w (sayı ya da
## Callable(u)), tube, sides, twist, bend Callable(u, t, a, b) -> Vector3, extra Callable(am, a, b, t)
static func _strand(pj: PathJutsu, mat: Material, prm: Dictionary, a_fn: Callable, b_fn: Callable, dur: float, o := {}) -> MeshInstance3D:
	var am = ArrayMesh.new()
	var mi = _mi(am, mat)
	_params(mi, prm)
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var n: int = int(o.get("n", 12))
	var tube: bool = o.get("tube", false)
	var tw = mi.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(mi):
			return
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		if a == Vector3.ZERO or b == Vector3.ZERO:
			mi.visible = false
			return
		mi.visible = true
		var pts: Array = []
		var ws: Array = []
		var wv = o.get("w", 0.05)
		for i in n:
			var u = float(i) / float(n - 1)
			var p = a.lerp(b, u)
			if o.has("bend"):
				p += o["bend"].call(u, t, a, b)
			pts.append(p)
			ws.append(wv.call(u) if wv is Callable else float(wv))
		am.clear_surfaces()
		if tube:
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _tube(pts, ws, int(o.get("sides", 6))))
		else:
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _ribbon(pts, ws, [], float(o.get("twist", -1.0))))
		if o.has("extra"):
			o["extra"].call(am, a, b, t), 0.0, dur, maxf(dur, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


## Hedef bedeni etrafında silindir yüzeyinde giden bant noktaları (açı radyan, +Z = yerel ön)
static func _wrap_pts(n: int, fn: Callable) -> Dictionary:
	var pts: Array = []
	var nrms: Array = []
	for i in n:
		var u = float(i) / float(n - 1)
		var q: Vector3 = fn.call(u)   # (açı, yükseklik, yarıçap)
		var dir = Vector3(sin(q.x), 0.0, cos(q.x))
		pts.append(dir * q.z + Vector3.UP * q.y)
		nrms.append(dir)
	return {"p": pts, "n": nrms}


# ================================================================== Kekkaifu: Gansōkō
## Ref (Shippūden): iki zeytin yeşili tılsım gözün üstüne çapraz yapışır, üstlerinde karalanmış mühür çizgileri; kunai
## tılsımda durur. Elden iki tılsım yüze uçar, çizgileri kendini yazar, önünde kısa süre yeşil-kara bir mühür çemberi
## açılıp tılsımlara çekilir; 8 sn yüzü izler, süre bitince soyulup savrularak düşer.
static func kekkaifu_gansoko(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var holder = Node3D.new()
	_add(pj, holder, pj.live_hand(c, true))
	var hand0 = holder.global_position
	for k in 2:
		var tag = _script_quad(Vector2(0.26, 0.13), {"ink": Color(0.16, 0.15, 0.07), "paper": Color(0.52, 0.5, 0.3, 1.0),
			"lay": 0.0, "style": 2.0, "seed": k * 4.7, "reveal": 0.0, "nf": 0.5})
		holder.add_child(tag)
		tag.position = Vector3(0.012 * (1 - 2 * k), 0.0, 0.004 * k)
		tag.rotation.z = deg_to_rad(28.0 if k == 0 else -24.0)
		_tp(tag, "reveal", 0.0, 1.0, 0.3, 0.16)
	var ring = _script_quad(Vector2(0.62, 0.62), {"lay": 1.0, "style": 0.0, "ink": Color(0.2, 0.2, 0.08), "edge": Color(0.85, 0.82, 0.45, 0.6),
		"grid": Vector2(14, 1), "inner": 0.55, "reveal": 0.0, "nf": 0.5})
	holder.add_child(ring)
	ring.position = Vector3(0, 0, 0.03)
	_tp(ring, "reveal", 0.0, 1.0, 0.22, 0.16)
	var rt = ring.create_tween()
	rt.tween_interval(0.45)
	rt.tween_property(ring, "scale", Vector3.ONE * 0.3, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	rt.tween_callback(ring.queue_free)
	var tw = holder.create_tween()
	tw.tween_method(func(tm: float):
		if not is_instance_valid(holder):
			return
		if not pj.live(c):
			holder.queue_free()
			return
		var fd = _flat_dir(c.face_dir())
		var eye = _bone(c, "Head", Vector3.UP * 1.62) + Vector3.UP * 0.06 + fd * 0.16
		var b = Basis.looking_at(-fd, Vector3.UP)
		if tm < 0.16:
			var u = tm / 0.16
			holder.global_transform = Transform3D(b, hand0.lerp(eye, u * u) + Vector3.UP * sin(u * PI) * 0.15)
		elif tm < 8.0:
			holder.global_transform = Transform3D(b, eye)
		else:
			var u = (tm - 8.0) / 0.7
			var ax = fd.cross(Vector3.UP).normalized()
			holder.global_transform = Transform3D(b.rotated(ax, u * 1.6), eye + Vector3.DOWN * u * u * 1.4 + fd * u * 0.3), 0.0, 8.7, 8.7)
	tw.tween_callback(holder.queue_free)
	_tp(holder, "alpha", 1.0, 0.0, 0.5, 8.2)
	if c is Player:
		Buffs.add("gansoko", 8.0, {"armor": 0.4, "_name": "Zırhlı Göz", "_desc": "tılsım plakaları gelen hasarı emiyor"})
	Sfx.play("seal", c.global_position, 1.2)


# ================================================================== Chakura Kontorōru: Baku
## Ref (Boruto): hedefin gövdesini çapraz kafes gibi saran ince, parlayan kırmızı çakra çizgileri. Avuçlarda kırmızı
## çakra toplanır, iki ince iplik dalgalanarak hedefe uzanır; varınca dört sağ + dört sol sarmal çizgi bedenin üstünde
## alttan üste kendini çizer ve kafes daralarak sıkar. Kesişimlerden kıvılcım saçılır.
static func chakura_kontororu_baku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.6)
	pj.anim(c, "push", 1.3)
	if tt == null:
		return
	var col = Color(1.0, 0.3, 0.35)
	var core = Color(1.0, 0.86, 0.88)
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba:
			var gl = _emblem(6.0, 0.3, {"fill": core, "accent": col, "reveal": 0.0, "nf": 0.6})
			ba.add_child(gl)
			_tp(gl, "reveal", 0.0, 1.0, 0.3)
			pj.free_after(0.45, ba)
	for k in 2:
		var right = k == 0
		var bend = func(u, tm, a, b):
			var sd = (b - a).cross(Vector3.UP).normalized()
			var damp = maxf(0.0, 1.0 - tm * 2.5)
			return (sd * sin(u * TAU * 1.5 - tm * 25.0 + k * 2.0) * 0.12 + Vector3.UP * 0.15) * sin(u * PI) * damp
		var th = _strand(pj, _glow_mat(), {"c1": core, "c2": col, "pat": 0.0, "reveal": 0.0, "nf": 0.8},
			func(): return pj.live_hand(c, right) if pj.live(c) else Vector3.ZERO,
			func(): return tt.global_position + Vector3.UP * 1.0 if pj.live(tt) else Vector3.ZERO, 0.5,
			{"n": 16, "w": func(u): return 0.05 * (1.0 - u * 0.4), "bend": bend})
		_tp(th, "reveal", 0.0, 1.0, 0.22)
	pj.after(0.3, func():
		if not pj.live(tt):
			return
		var root = Node3D.new()
		tt.add_child(root)
		pj.fit_body(tt, root)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		var inner = Node3D.new()
		root.add_child(inner)
		var surf: Array = []
		for k in 8:
			var ph = (k % 4) * TAU / 4.0
			var sg = 1.0 if k < 4 else -1.0
			var w = _wrap_pts(26, func(u): return Vector3(ph + sg * u * TAU * 0.9, 0.15 + u * 1.6, 0.44))
			var ws: Array = []
			for i in 26:
				ws.append(0.035)
			surf.append(_ribbon(w["p"], ws, w["n"]))
		var lat = _mi(_mesh(surf), _glow_mat())
		_params(lat, {"c1": core, "c2": col, "pat": 0.0, "reveal": 0.0, "nf": 1.0})
		inner.add_child(lat)
		inner.scale = Vector3(1.35, 1.0, 1.35)
		var it = inner.create_tween()
		it.tween_property(inner, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tp(lat, "reveal", 0.0, 1.0, 0.3)
		_tp(lat, "alpha", 1.0, 0.0, 0.3, 2.3)
		var tw = root.create_tween()
		tw.tween_interval(2.6)
		tw.tween_callback(root.queue_free)
		pj.st(tt, "bind", 2.6)
		_spray(pj, tt.global_position + Vector3.UP, {"n": 14, "col": core, "v0": 2.0, "v1": 5.0, "spread": 180.0, "grav": 0.0,
			"damp": 6.0, "s0": 0.04, "s1": 0.08, "life": 0.45, "r": 0.4}))
	Sfx.play("seal", tt.global_position, 1.2)


# ================================================================== Nunoshibari no Jutsu
## Ref: beyaz kumaştan yumurta biçimli koza; yatay sargı katları, iki kara ip çaprazı + çift dikey ip, ortada kırmızı
## mühür karesi. Ellerden üç kumaş şerit dalgalanıp burularak hedefe sarılır; koza alttan üste katlanarak kapanır,
## her sıkmada içeri çöker; süre bitince sargılar yukarıdan çözülür.
static func nunoshibari_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var edge = Color(0.55, 0.5, 0.42)
	for k in 3:
		var right = k % 2 == 0
		var hk = 0.5 + k * 0.5
		var bend = func(u, tm, a, b):
			var sd = (b - a).cross(Vector3.UP).normalized()
			return (Vector3.UP * 0.35 * (1.0 - tm) + sd * sin(u * TAU + tm * 12.0 + k) * 0.18) * sin(u * PI)
		var st = _strand(pj, _glow_mat(), {"c1": CLOTH, "c2": edge, "pat": 4.0, "reveal": 0.0, "nf": 1.0},
			func(): return pj.live_hand(c, right) if pj.live(c) else Vector3.ZERO,
			func(): return tt.global_position + Vector3.UP * hk if pj.live(tt) else Vector3.ZERO, 0.5,
			{"n": 18, "w": 0.16, "twist": 0.6, "bend": bend})
		_tp(st, "reveal", 0.0, 1.0, 0.25)
	pj.after(0.35, func():
		if not pj.live(tt):
			return
		var root = Node3D.new()
		tt.add_child(root)
		pj.fit_body(tt, root)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		var piv = Node3D.new()
		root.add_child(piv)
		var egg = _cel(_sphere_mesh(), CLOTH, 1.0, 0.022, {"reveal": 0.0, "line": Color(0.25, 0.2, 0.17), "nf": 1.5})
		egg.position = Vector3(0, 1.0, 0)
		egg.scale = Vector3(1.2, 2.4, 1.2)
		piv.add_child(egg)
		_tp(egg, "reveal", 0.0, 1.02, 0.3)
		_tp(egg, "reveal", 1.02, 0.0, 0.25, 2.55)
		piv.scale = Vector3(1.5, 1.0, 1.5)
		var pt = piv.create_tween()
		pt.tween_property(piv, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# sarılma anı: koza çevresinde alttan üste dolanan kumaş şerit
		var w = _wrap_pts(40, func(u): return Vector3(u * TAU * 3.0, 0.05 + u * 2.0, 0.66 + sin(u * PI) * 0.02))
		var ws: Array = []
		for i in 40:
			ws.append(0.22)
		var band = _mi(_mesh([_ribbon(w["p"], ws, w["n"])]), _glow_mat())
		_params(band, {"c1": CLOTH, "c2": edge, "pat": 4.0, "reveal": 0.0, "nf": 1.0})
		piv.add_child(band)
		_tp(band, "reveal", 0.0, 1.0, 0.3)
		_fade_free(band, 0.32, 0.2)
		var tw = root.create_tween()
		tw.tween_interval(2.8)
		tw.tween_callback(root.queue_free)
		pj.st(tt, "bind", 3.0)
		pj.every(3.0, 0.5, func(_i, _k):
			if pj.live(tt):
				tt.take_hit(pj.inf(c, "nunoshibari_no_jutsu", 0.2, {"knock": 0.0, "kind": "light"}))
				if is_instance_valid(piv):
					var sq = piv.create_tween()
					sq.tween_property(piv, "scale", Vector3(0.92, 1.03, 0.92), 0.06)
					sq.tween_property(piv, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK), Callable()))
	Sfx.play("whoosh", c.global_position, 0.9)


# ================================================================== Keiyaku Fūin
## Ref: avuç bedene bastırılır, kara tırtıklı mühür yazısı avuçtan dışa doğru halka halka yayılır. Kullanıcı hedefe
## atılır; göğüste avuç noktasından ışınsal yazı yayılır, sekiz yazı damarı bedeni sararak arkaya akar, yerde aynı
## sözleşme formülü çember olarak açılır; mürekkep sıçrar. 2.5 sn sonra yazı kuruyup söner.
static func keiyaku_fuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 5.0)
	pj.busy(c, 0.7)
	if tt == null:
		return
	pj._jump_at(c, tt, 0.0, 8.0)
	pj.after(0.2, func():
		if not pj.live(tt):
			return
		var to_c = _flat_dir((c.global_position if is_instance_valid(c) else tt.global_position + Vector3.FORWARD) - tt.global_position)
		var root = Node3D.new()
		tt.add_child(root)
		root.global_transform = Transform3D(Basis.looking_at(-to_c, Vector3.UP), tt.global_position)
		pj.fit_body(tt, root)   # hedef boyunda
		var edge = Color(0.3, 0.1, 0.35, 0.45)
		var palm = _script_quad(Vector2(1.5, 1.5), {"lay": 2.0, "style": 1.0, "grid": Vector2(9, 6), "ink": INK, "edge": edge,
			"reveal": 0.0, "seed": randf() * 50.0, "nf": 1.0})
		root.add_child(palm)
		palm.position = Vector3(0, 1.1, 0.4)
		_tp(palm, "reveal", 0.0, 1.0, 0.45)
		var surf: Array = []
		for k in 8:
			var sgn = 1.0 if k % 2 == 0 else -1.0
			var end_a = sgn * (0.7 + floorf(k / 2.0) * 0.55)
			var end_y = 0.2 + fmod(k * 0.53, 1.6)
			var w = _wrap_pts(18, func(u): return Vector3(end_a * u, lerpf(1.1, end_y, u) + sin(u * PI * 2.0 + k) * 0.08, 0.4))
			var ws: Array = []
			for i in 18:
				ws.append(0.12 * (1.0 - float(i) / 30.0))
			surf.append(_ribbon(w["p"], ws, w["n"]))
		var veins = _mi(_mesh(surf), _script_mat())
		_params(veins, {"lay": 0.0, "style": 1.0, "grid": Vector2(14, 1), "ink": INK, "edge": edge, "reveal": 0.0, "nf": 1.0})
		root.add_child(veins)
		_tp(veins, "reveal", 0.0, 1.0, 0.5, 0.1)
		var gs = _ground_seal(pj, pj.gp(tt.global_position), 2.0, {"lay": 1.0, "style": 1.0, "grid": Vector2(26, 2), "inner": 0.32,
			"ink": INK, "edge": Color(0.35, 0.1, 0.4, 0.35), "reveal": 0.0, "nf": 1.5, "seed": randf() * 50.0})
		_tp(gs, "reveal", 0.0, 1.0, 0.6)
		_fade_free(gs, 2.1, 0.4)
		_fade_free(root, 2.1, 0.4)
		_spray(pj, tt.global_position + Vector3.UP * 1.1 + to_c * 0.4, {"n": 14, "col": INK, "v0": 2.0, "v1": 5.0, "dir": to_c,
			"spread": 70.0, "s0": 0.04, "s1": 0.09, "grav": 12.0, "life": 0.6})
		pj.st(tt, "stun", 2.0)
		pj.st(tt, "slow", 4.0)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Sözleşme mühürlendi!", Color(0.9, 0.85, 0.7)))
	Sfx.play("seal", c.global_position, 1.1)


# ================================================================== Zekka Konzetsu no In
## Ref (Sai'nin dili): pembe dilin üstünde beş kalın kara çubuk — üç uzun kırık çubuk ve altta ikişer kısa çubuk. Kara
## mürekkep çizgileri başın üstünde toplanır, dil mührü pembe zemin üstünde çubuk çubuk yazılır; aynı çubuklar kara bant
## olarak bedeni yukarıdan aşağı sırayla sarıp daralır (felç).
static func zekka_konzetsu_no_in(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.5)
	if tt == null:
		return
	var top = Vector3.UP * maxf(2.2, _h(tt) + 0.45)
	if not _cache.has("dash_mat"):
		var dm = StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.albedo_color = INK
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache["dash_mat"] = dm
	for k in 9:
		var dash = _mi(_quad(Vector2(0.2, 0.045)), _cache["dash_mat"])
		tt.add_child(dash)
		var a = k * TAU / 9.0
		dash.position = top + Vector3(cos(a) * 1.5, sin(a * 2.0) * 0.5, sin(a) * 1.5)
		var dt = dash.create_tween()
		dt.tween_property(dash, "position", top, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dt.parallel().tween_property(dash, "scale", Vector3.ONE * 0.3, 0.32)
		dt.tween_callback(dash.queue_free)
	var emb = _emblem(0.0, 0.95, {"ink": INK, "fill": Color(0.78, 0.45, 0.52), "accent": Color(0.47, 0.25, 0.33), "reveal": 0.0, "nf": 1.0})
	tt.add_child(emb)
	emb.position = top
	emb.scale = Vector3.ONE * 1.3
	var et = emb.create_tween()
	et.tween_interval(0.3)
	et.tween_property(emb, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	_tp(emb, "reveal", 0.0, 1.0, 0.45, 0.3)
	_tp(emb, "alpha", 1.0, 0.0, 0.3, 3.7)
	pj.get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(emb):
			emb.queue_free())
	var root = Node3D.new()
	tt.add_child(root)
	pj.fit_body(tt, root)
	for i in 5:
		var y = 1.5 - i * 0.25
		var w = _wrap_pts(33, func(u): return Vector3(u * TAU, y - absf(sin(u * TAU * 1.0)) * 0.05, 0.42))
		var ws: Array = []
		for j in 33:
			ws.append(0.085)
		var band = _mi(_mesh([_ribbon(w["p"], ws, w["n"])]), _glow_mat())
		_params(band, {"c1": INK, "c2": Color(0.85, 0.5, 0.58), "pat": 6.0, "reveal": 0.0, "nf": 1.0})
		var bp = Node3D.new()
		root.add_child(bp)
		bp.add_child(band)
		bp.scale = Vector3(1.45, 1.0, 1.45)
		var bt = bp.create_tween()
		bt.tween_interval(0.35 + i * 0.07)
		bt.tween_property(bp, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		_tp(band, "reveal", 0.0, 1.0, 0.15, 0.35 + i * 0.07)
	_fade_free(root, 2.25, 0.25)
	pj.st(tt, "stun", 2.5)
	pj.st(tt, "slow", 4.0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.8, "Sustu!", Color(0.95, 0.55, 0.6))
	Sfx.play("seal", tt.global_position, 1.0)


# ================================================================== Fūkoku Hōin
## Ref (Shikokumujin bitmiş hali): kara kapaklı krem tahta perdeli silindir, üstünde kızıl mühür yazısı, kenarında
## kâğıt tılsımlar, tabanda kalın mor burgulu ip. Yerde kara-mor mühür çemberi açılır, silindir yerden yükselir, yazı
## çevresinde kendini yazar, tılsımlar sırayla yazılır; süre bitince yere geri çöker.
static func fukoku_hoin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var root = Node3D.new()
	_add(pj, root, at)
	var cm = CylinderMesh.new()
	cm.top_radius = 2.2
	cm.bottom_radius = 2.2
	cm.height = 2.4
	cm.radial_segments = 40
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var wall = _mi(cm, _script_mat())
	_params(wall, {"lay": 0.0, "style": 4.0, "grid": Vector2(30, 3), "ink": Color(0.55, 0.12, 0.12), "paper": Color(0.9, 0.86, 0.74, 1.0),
		"reveal": 0.0, "nf": 2.0, "seed": randf() * 40.0})
	wall.position = Vector3.UP * 1.2
	root.add_child(wall)
	_tp(wall, "reveal", 0.0, 1.0, 0.9, 0.35)
	var lid_m = CylinderMesh.new()
	lid_m.top_radius = 2.2
	lid_m.bottom_radius = 2.2
	lid_m.height = 0.04
	lid_m.radial_segments = 40
	var lid = _cel(lid_m, Color(0.05, 0.04, 0.06), 0.0, 0.0, {"nf": 2.0})
	lid.position = Vector3.UP * 2.39
	root.add_child(lid)
	for y in [2.4, 0.0]:
		var rim_m = TorusMesh.new()
		rim_m.inner_radius = 2.17
		rim_m.outer_radius = 2.26
		rim_m.rings = 48
		rim_m.ring_segments = 4
		var rim = _cel(rim_m, Color(0.08, 0.06, 0.08), 0.0, 0.0, {"nf": 2.0})
		rim.position = Vector3.UP * y
		root.add_child(rim)
	var rope_m = TorusMesh.new()
	rope_m.inner_radius = 2.2
	rope_m.outer_radius = 2.62
	rope_m.rings = 72
	rope_m.ring_segments = 10
	var rope = _cel(rope_m, Color(0.56, 0.5, 0.68), 4.0, 0.02, {"line": Color(0.3, 0.25, 0.4), "nf": 2.0})
	rope.position = Vector3.UP * 0.28
	root.add_child(rope)
	for k in 8:
		var a = k * TAU / 8.0 + 0.2
		var out = Vector3(cos(a), 0, sin(a))
		var tag = _script_quad(Vector2(0.3, 0.48), {"lay": 0.0, "style": 0.0, "grid": Vector2(1, 3), "ink": SEAL_RED,
			"paper": Color(0.93, 0.92, 0.95, 1.0), "reveal": 0.0, "seed": k * 3.3, "nf": 2.0})
		root.add_child(tag)
		tag.position = out * 2.24 + Vector3.UP * 2.3
		tag.basis = Basis.looking_at(-out, Vector3.UP).rotated(out, randf_range(-0.2, 0.2))
		_tp(tag, "reveal", 0.0, 1.0, 0.25, 0.5 + k * 0.05)
	root.scale = Vector3(1, 0.02, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(5.0)
	tw.tween_property(root, "scale", Vector3(1, 0.02, 1), 0.4)
	tw.tween_callback(root.queue_free)
	pj.st(tt, "bind", 5.5)
	var gs = _ground_seal(pj, at, 3.2, {"lay": 1.0, "style": 0.0, "grid": Vector2(30, 2), "inner": 0.72, "ink": Color(0.08, 0.04, 0.1),
		"edge": Color(0.45, 0.25, 0.6, 0.35), "reveal": 0.0, "nf": 2.0, "seed": randf() * 40.0})
	_tp(gs, "reveal", 0.0, 1.0, 0.3)
	_fade_free(gs, 0.6, 1.2)
	Combat.popup_text(at + Vector3.UP * 2.6, "Karanlık Mühür!", Color(0.7, 0.5, 0.9))
	Sfx.play("seal", at, 0.7)


# ================================================================== Shiki Fūjin
## Ref: yarı saydam Ölüm Tanrısı (oyunun Shinigami modeli) çağıranın arkasında; mavi-beyaz ruh kolları, havada süzülen
## soluk ruh alevleri (hitodama). Çağıranın ruhu bedeninden mavi kıvrımlı şeritlerle yarı ayrılır, ayağının altında kara
## mühür formülü yazılır; kara mühür halkalı mor ruh kolu hedefe uzanıp parmaklarıyla kavrar; sökülen ruh mavi bir alev
## olarak Ölüm Tanrısının karnına çekilir.
static func shiki_fujin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)   # kanon: Hiruzen hedefe yanaşmak zorundaydı
	pj.busy(c, 2.4)
	if c is Player:
		c.input_locked = 2.2
		Hud.msg("KİNJUTSU — Shiki Fūjin: Ölüm Tanrısı ruhunu da yutacak.", Color(0.85, 0.75, 1.0), 4.0)
	var d = pj.fwd(c, t)
	var sg = Shinigami.spawn(pj.get_tree().current_scene, c.global_position - d * 1.4, atan2(-d.x, -d.z))
	sg.fade(0.72, 0.6)
	_soul_wisps(pj, c, 0.5, 2.2)   # çağıranın ruhu bedeninden yarı ayrılır
	var gs = _ground_seal(pj, pj.gp(c.global_position), 1.7, {"lay": 1.0, "style": 0.0, "grid": Vector2(20, 2), "inner": 0.4,
		"ink": INK, "edge": Color(0.55, 0.45, 0.75, 0.4), "reveal": 0.0, "nf": 1.5, "seed": randf() * 40.0})
	_tp(gs, "reveal", 0.0, 1.0, 0.6)
	_fade_free(gs, 2.8, 0.6)
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.5
		var hd = _emblem(5.0, 0.42, {"fill": Color(0.9, 0.95, 1.0), "accent": Color(0.55, 0.7, 1.0), "alpha": 0.0, "seed": k * 1.7, "nf": 1.2})
		_add(pj, hd, c.global_position + Vector3(cos(a) * 2.4, 1.6 + (k % 3) * 0.6, sin(a) * 2.4))
		var ht = hd.create_tween()
		ht.tween_property(hd, "global_position", hd.global_position + Vector3.UP * 0.7, 3.2)
		_tp(hd, "alpha", 0.0, 0.8, 0.4, k * 0.1)
		_fade_free(hd, 2.7, 0.5)
	pj.after(0.8, func():
		if is_instance_valid(sg):
			sg.show_seal(true))   # lanet işaretleri kola yayılır
	if tt == null:
		pj.after(2.6, func():
			if is_instance_valid(sg):
				sg.fade(0.0, 0.5)
				pj.free_after(0.55, sg))
		return
	pj.after(1.0, func():   # kol çağıranın bedeninden çıkıp hedefin ruhunu kavrar
		if not (pj.live(c) and pj.live(tt)):
			return
		if c.global_position.distance_to(tt.global_position) > 9.0:   # mühür bitmeden uzaklaştı: kol boşa uzandı
			Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Kaçtı!", Color(0.8, 0.75, 1.0))
			tt.set_meta("shiki_escaped", true)
			return
		var fingers = func(am, a, b, _tm):   # kavrayan parmaklar
			var dd = (b - a).normalized()
			var s1 = dd.cross(Vector3.UP).normalized()
			var s2 = dd.cross(s1).normalized()
			for f in 4:
				var ang = f * TAU / 4.0 + 0.4
				var e = s1 * cos(ang) + s2 * sin(ang)
				var base = b - dd * 0.3
				var fp = [base + e * 0.1, base + e * 0.32 + dd * 0.15, base + e * 0.3 + dd * 0.4, base + e * 0.12 + dd * 0.55]
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _tube(fp, [0.055, 0.048, 0.038, 0.02], 5))
		var arm = _strand(pj, _glow_mat(), {"c1": Color(0.42, 0.33, 0.48), "c2": INK, "pat": 5.0, "reveal": 0.0, "nf": 1.5},
			func(): return c.global_position + Vector3.UP * 1.2 if is_instance_valid(c) else Vector3.ZERO,
			func(): return tt.global_position + Vector3.UP * 1.1 if is_instance_valid(tt) else Vector3.ZERO, 1.4,
			{"tube": true, "sides": 8, "n": 14, "w": func(u): return lerpf(0.17, 0.1, u),
			"bend": func(u, tm, _a, _b): return Vector3.UP * sin(u * PI) * (0.25 + sin(tm * 6.0) * 0.06), "extra": fingers})
		_tp(arm, "reveal", 0.0, 1.0, 0.25)
		pj.st(tt, "bind", 2.0)
		pj.st(tt, "sealed", 2.0)   # ruhu tutulurken jutsu yapamaz (kanon)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Ruhu yakalandı!", Color(0.8, 0.75, 1.0)))
	pj.after(2.0, func():
		if not (pj.live(c) and pj.live(tt)) or tt.has_meta("shiki_escaped"):
			if is_instance_valid(tt) and tt.has_meta("shiki_escaped"):
				tt.remove_meta("shiki_escaped")
			return   # ruh yakalanmadı: mühür (ve bedel) gerçekleşmez
		# kanon: sökülebilen ruh, çağıranın chakrasının hedefinkine oranına bağlı — tam söküm için o anki chakrada belirgin üstünlük
		var tc = float(tt.get("chakra")) if tt.get("chakra") != null else 100.0
		var full = float(c.get("chakra")) >= tc * 1.5 and not (tt is Boss) and not (tt is TailedBeast)
		_soul_wisps(pj, tt, 0.65, 0.5)   # sökülen ruh
		var soul = _emblem(5.0, 0.9, {"fill": Color(0.92, 0.96, 1.0), "accent": Color(0.45, 0.6, 1.0), "nf": 1.2})
		_add(pj, soul, tt.global_position + Vector3.UP)
		_spray(pj, Vector3.ZERO, {"parent": soul, "one_shot": false, "n": 24, "life": 0.4, "col": Color(0.7, 0.82, 1.0), "v0": 0.2, "v1": 0.6,
			"grav": 0.0, "s0": 0.06, "s1": 0.12, "r": 0.2})
		var tw2 = soul.create_tween()
		tw2.tween_property(soul, "global_position", sg.belly() if is_instance_valid(sg) else c.global_position + Vector3.UP * 3.0, 0.45)
		tw2.tween_property(soul, "scale", Vector3.ONE * 0.05, 0.25)
		tw2.tween_callback(soul.queue_free)
		if full:
			Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Ruhu mühürlendi", Color(0.85, 0.85, 1.0))
			pj._shiki_kill(tt, c)
		else:   # gücü yetmedi: yalnız ruhunun kolları kesilip mühürlenir (Orochimaru) — kolları felç, mühür yapamaz
			pj.st(tt, "sealed", 25.0)
			tt.take_hit(pj.inf(c, "shiki_fujin", 2.0, {"knock": 0.0, "kind": "heavy", "chakra_drain": 60.0, "hitstop": 0.2}))
			Combat.popup_text(tt.global_position + Vector3.UP * 2.8, "Kolları mühürlendi — mühür yapamaz!", Color(0.85, 0.75, 1.0))
		# bedel: Ölüm Tanrısı çağıranın ruhunu da yutar — 12 sn sonra ölür (kanon)
		if c is Player:
			Hud.banner("ÖLÜM TANRISININ MİDESİ", "Ruhun mühürle birlikte yutuluyor. Son işlerini bitirmek için birkaç saniyen var.", Color(0.7, 0.6, 0.85))
			Buffs.add("rinne_bedel", 12.0, {"speed": 0.7, "no_heal": 1.0, "_name": "Ölüm Tanrısının Midesi", "_desc": "ruhun yutuluyor: 12 sn sonra öleceksin"})
		pj.after(12.0, func():
			if pj.live(c):
				Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Ruhu yutuldu", Color(0.7, 0.6, 0.85))
				pj._shiki_kill(c, null)))
	pj.after(3.2, func():
		if is_instance_valid(sg):
			sg.fade(0.0, 0.6)
			pj.free_after(0.65, sg))
	Sfx.play("genjutsu", c.global_position, 0.4)


## Bedenden yükselen mavi-beyaz ruh şeritleri (ref: Shiki Fūjin'de ruhun bedenden ayrılışı)
static func _soul_wisps(pj: PathJutsu, n: Node3D, amax: float, dur: float) -> void:
	for k in 4:
		var off = Vector3(cos(k * 1.7) * 0.18, 0.75 + k * 0.18, sin(k * 1.7) * 0.18)
		var ws = _strand(pj, _glow_mat(), {"c1": Color(0.88, 0.95, 1.0), "c2": Color(0.45, 0.62, 0.95), "pat": 2.0, "alpha": 0.0, "nf": 1.2, "seed": k * 2.0},
			func(): return n.global_position + off if is_instance_valid(n) else Vector3.ZERO,
			func(): return n.global_position + off + Vector3.UP * 1.3 + Vector3(cos(k * 2.3), 0, sin(k * 2.3)) * 0.4 if is_instance_valid(n) else Vector3.ZERO, dur,
			{"n": 14, "w": func(u): return 0.3 * (1.0 - u * 0.5),
			"bend": func(u, tm, _a, _b): return Vector3(sin(u * 5.0 + tm * 8.0 + k), 0.0, cos(u * 4.0 + tm * 7.0 + k)) * 0.25 * u})
		_tp(ws, "alpha", 0.0, amax, 0.2)
		_tp(ws, "alpha", amax, 0.0, 0.3, maxf(dur - 0.3, 0.05))


# ================================================================== Fūnyū no Jutsu
## Ref: yere açılmış parşömen (mor kenar, kırmızı-beyaz rulo), ortadan dışa yayılan yazı ışınları, merkezde mavi
## çakra ışığı; nesne beyaz bulut girdabı olarak parşömenin içine çekilir. Parşömen yuvarlanarak açılır, yazı merkezden
## yayılır, burgulu bulut aşağı emilir ve parşömen geri sarılır.
static func funyu_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var fd = _flat_dir(c.face_dir())
	var at = pj.gp(c.global_position + fd * 1.2) + Vector3.UP * 0.03
	var root = Node3D.new()
	_add(pj, root, at)
	root.basis = Basis.looking_at(fd, Vector3.UP)
	var piv = Node3D.new()
	root.add_child(piv)
	var paper_n = _cel(_quad(Vector2(0.75, 1.6)), PAPER, 5.0, 0.0, {"line": Color(0.4, 0.3, 0.55), "nf": 1.0})
	paper_n.rotation.x = -PI * 0.5
	paper_n.position = Vector3(0, 0, -0.8)
	piv.add_child(paper_n)
	piv.scale = Vector3(1, 1, 0.01)
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = 0.82
	cyl.radial_segments = 12
	var roller = _cel(cyl, PAPER, 6.0, 0.012, {"nf": 1.0})
	roller.rotation.z = PI * 0.5
	roller.position = Vector3(0, 0.07, 0)
	root.add_child(roller)
	var rt = root.create_tween()
	rt.tween_property(piv, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(roller, "position", Vector3(0, 0.07, -1.6), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_interval(0.8)
	rt.tween_property(piv, "scale", Vector3(1, 1, 0.01), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rt.parallel().tween_property(roller, "position", Vector3(0, 0.07, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rt.tween_callback(root.queue_free)
	var center = Vector3(0, 0.012, -0.8)
	var rad = _script_quad(Vector2(0.72, 0.72), {"lay": 2.0, "style": 0.0, "grid": Vector2(12, 5), "ink": Color(0.1, 0.1, 0.18),
		"reveal": 0.0, "nf": 1.0, "seed": randf() * 30.0})
	rad.rotation.x = -PI * 0.5
	rad.position = center
	root.add_child(rad)
	_tp(rad, "reveal", 0.0, 1.0, 0.35, 0.25)
	var glow = _emblem(6.0, 0.55, {"fill": Color(0.95, 0.98, 1.0), "accent": Color(0.4, 0.65, 1.0), "reveal": 0.0, "bb": 0.0, "alpha": 0.0, "nf": 1.0})
	glow.rotation.x = -PI * 0.5
	glow.position = center + Vector3.UP * 0.008
	root.add_child(glow)
	_tp(glow, "alpha", 0.0, 1.0, 0.1, 0.3)
	_tp(glow, "reveal", 0.0, 1.0, 0.6, 0.3)
	pj.after(0.35, func():
		if not is_instance_valid(root):
			return
		var cw = root.to_global(center)
		for k in 3:
			var bend = func(u, tm, _a, _b):
				var ang = u * 7.0 + tm * 14.0 + k * 2.09
				return Vector3(cos(ang), 0.0, sin(ang)) * (0.05 + 0.7 * pow(u, 1.5)) * (1.0 - tm * 0.6)
			var v = _strand(pj, _glow_mat(), {"c1": Color(0.97, 0.97, 1.0), "c2": Color(0.7, 0.72, 0.85), "pat": 7.0, "reveal": 1.0, "nf": 1.2},
				func(): return cw, func(): return cw + Vector3.UP * 1.7, 0.6,
				{"n": 22, "w": func(u): return 0.36 * (0.25 + u), "bend": bend})
			_tp(v, "reveal", 1.0, 0.0, 0.3, 0.3))
	var d: Dictionary = Data.jutsu.get("funyu_no_jutsu", {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	Buffs.add(String(d.get("id", "buff")), dur, {"speed": 1.1})
	if c is Player:
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], Color(0.95, 0.92, 0.84))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== Gogyō Kaiin
## Ref (Jiraiya): beş parmak ucunda mavi alev, her alevde bir element yazısı. Parmak uçlarında beş mavi alev ve küçük
## element yazıları yanar; vuruşta karındaki kara beş element mührü (sarmal + beş işaret) parlayıp mürekkep kırıntılarına
## ayrılır, beş element yazısı beşgen halinde dışa savrulup söner.
static func gogyo_kaiin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var ba = pj.bone_attach(c, "RightHand")
	var kanji = ["火", "水", "木", "金", "土"]
	if ba:
		for k in 5:
			var fl = _emblem(7.0, 0.13, {"fill": Color(0.88, 0.95, 1.0), "accent": BLUEFIRE, "seed": k * 1.3, "nf": 0.5})
			fl.position = Vector3(-0.04 + k * 0.02, 0.1, 0.05)
			ba.add_child(fl)
			var lb = _label(kanji[k], 0.00045, Color(0.95, 0.98, 1.0), BLUEFIRE.darkened(0.3))
			lb.position = Vector3(-0.08 + k * 0.04, 0.17, 0.05)
			ba.add_child(lb)
		var li = OmniLight3D.new()
		li.light_color = BLUEFIRE
		li.light_energy = 1.2
		li.omni_range = 2.0
		ba.add_child(li)
		pj.free_after(0.6, ba)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var fd = _flat_dir(c.face_dir())
		var belly = c.global_position + Vector3.UP * 1.0 + fd * 0.3
		var seal = _emblem(4.0, 0.7, {"ink": INK, "fill": Color(0.85, 0.92, 1.0, 0.7), "nf": 1.0})
		_add(pj, seal, belly)
		var st = seal.create_tween()
		st.tween_property(seal, "scale", Vector3.ONE * 1.4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_fade_free(seal, 0.05, 0.3)
		_spray(pj, belly, {"mesh": _quad(Vector2(1, 1)), "n": 16, "col": INK, "v0": 2.0, "v1": 4.5, "dir": fd, "spread": 80.0,
			"grav": 3.0, "spin": 400.0, "s0": 0.05, "s1": 0.1, "life": 0.55})
		for k in 5:
			var a = k * TAU / 5.0 + PI * 0.5
			var side = fd.cross(Vector3.UP).normalized()
			var dir = side * cos(a) + Vector3.UP * sin(a)
			var lb = _label(kanji[k], 0.004, BLUEFIRE.lightened(0.2), Color(0.95, 0.98, 1.0))
			_add(pj, lb, belly + dir * 0.3)
			var lt = lb.create_tween()
			lt.tween_property(lb, "global_position", belly + dir * 1.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			lt.parallel().tween_property(lb, "modulate:a", 0.0, 0.45).set_delay(0.1)
			lt.parallel().tween_property(lb, "outline_modulate:a", 0.0, 0.45).set_delay(0.1)
			lt.tween_callback(lb.queue_free)
		if c.get("status") is Dictionary:
			for k in ["stun", "bind", "slow", "poison"]:
				c.status.erase(k)
		Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Mühür çözüldü!", BLUEFIRE))
	Sfx.play("seal", c.global_position, 1.2)


# ================================================================== Kinkoju no Fuda
## Ref: hedefin bedenine yapışan beyaz, dört köşesi içe kıvrık elmas tılsım; ortasında camgöbeği halka ve kızıl nokta.
## Elden dönerek uçan, kızıl yazılı kâğıt tılsım (arkasında kâğıt kırpıntısı); değince kızıl yazı halkası parlar,
## tılsım bedene çarpıp oturur, başın üstünde 禁 belirir.
static func kinkoju_no_fuda(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 24.0)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var tag = Node3D.new()
		var spinner = Node3D.new()
		tag.add_child(spinner)
		var q = _script_quad(Vector2(0.15, 0.42), {"lay": 0.0, "style": 0.0, "grid": Vector2(1, 3), "ink": SEAL_RED,
			"paper": Color(0.97, 0.96, 0.98, 1.0), "reveal": 1.0, "flap": 0.05, "seed": 9.0, "nf": 0.8})
		q.rotation.x = -PI * 0.5
		spinner.add_child(q)
		var sp = spinner.create_tween().set_loops()
		sp.tween_property(spinner, "rotation:z", TAU, 0.35).as_relative()
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 36.0, tag, pj.inf(c, "kinkoju_no_fuda", 0.6, {"knock": 0.0, "kind": "light"}), tt, false, 1.2, func(p, h):
			var fl = _emblem(6.0, 1.2, {"fill": Color(1.0, 0.92, 0.88), "accent": Color(0.85, 0.15, 0.15), "reveal": 0.0, "nf": 1.0})
			_add(pj, fl, p)
			_tp(fl, "reveal", 0.0, 1.0, 0.2)
			_fade_free(fl, 0.1, 0.18)
			if h and pj.live(h):
				pj.st(h, "bind", 4.5)
				var tg2 = _emblem(1.0, 0.6, {"ink": INK, "fill": Color(0.97, 0.97, 0.95), "accent": Color(0.82, 0.12, 0.14), "reveal": 0.0, "nf": 1.0})
				h.add_child(tg2)
				tg2.position = Vector3(0, 1.45, 0.25)
				tg2.scale = Vector3.ONE * 1.6
				var gt = tg2.create_tween()
				gt.tween_property(tg2, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK)
				_tp(tg2, "reveal", 0.0, 1.0, 0.2)
				var lbl = _label("禁", 0.006, Color(0.85, 0.1, 0.1), INK)
				lbl.font_size = 140
				lbl.position = Vector3.UP * 2.5
				h.add_child(lbl)
				pj.get_tree().create_timer(4.5).timeout.connect(func():
					if is_instance_valid(tg2):
						tg2.queue_free()
					if is_instance_valid(lbl):
						lbl.queue_free())
			else:
				_spray(pj, p, {"mesh": _quad(Vector2(1, 1)), "n": 10, "col": Color(0.95, 0.93, 0.9), "v0": 1.5, "v1": 3.5, "grav": 2.5,
					"spin": 300.0, "s0": 0.05, "s1": 0.09, "life": 0.8}))
		if pr:
			_spray(pj, Vector3.ZERO, {"parent": pr, "one_shot": false, "mesh": _quad(Vector2(1, 1)), "n": 14, "life": 0.35,
				"col": Color(0.95, 0.9, 0.88), "v0": 0.2, "v1": 0.8, "grav": 1.5, "spin": 200.0, "s0": 0.025, "s1": 0.05, "r": 0.05}))
	Sfx.play("throw", c.global_position, 1.2)


# ================================================================== Shishō Fūin
## Kaynak görsel yok: kanondaki dört sembol mührü — karında kara sarmal, çevresinde halka ve dört yönde ikişer işaret.
## Sağ avuçta dönen mavi çakra sarmalı; kullanıcı hedefe atılıp avucunu bastırır: sarmal merkezden dışa kendini çizer,
## halka ve dört sembol yazılır, dört yöne kara-mavi mühür çizgileri fırlar. Mühür 6 sn bedende kalır.
static func shisho_fuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.0)
	var blue = Color(0.4, 0.6, 1.0)
	for side in ["RightHand"]:
		var ba = pj.bone_attach(c, side)
		if ba:
			ba.add_child(_emblem(8.0, 0.32, {"fill": Color(0.9, 0.95, 1.0), "accent": blue, "nf": 0.5}))
			var li = OmniLight3D.new()
			li.light_color = blue
			li.light_energy = 1.0
			li.omni_range = 1.8
			ba.add_child(li)
			pj.free_after(0.9, ba)
	if tt == null:
		return
	pj._jump_at(c, tt, 0.5, 9.0)
	pj.after(0.35, func():
		if not (pj.live(c) and pj.live(tt)):
			return
		var seal = _emblem(3.0, 0.85, {"ink": Color(0.04, 0.04, 0.08), "fill": Color(0.85, 0.9, 1.0, 0.6), "reveal": 0.0, "nf": 1.0})
		seal.position = Vector3(0, 1.0, 0.3)
		tt.add_child(seal)
		pj.fit_body(tt, seal)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		_tp(seal, "reveal", 0.0, 1.0, 0.3)
		_tp(seal, "alpha", 1.0, 0.0, 0.4, 5.6)
		pj.get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(seal):
				seal.queue_free())
		var o = tt.global_position + Vector3.UP
		var surf: Array = []
		for k in 4:
			var a = k * TAU / 4.0
			var dir = Vector3(cos(a), 0, sin(a))
			var pts: Array = []
			var ws: Array = []
			for i in 8:
				var u = float(i) / 7.0
				pts.append(o + dir * (0.25 + u * 1.4) + Vector3.UP * sin(u * PI * 2.0 + k) * 0.06)
				ws.append(0.09 * (1.0 - u * 0.8))
			surf.append(_ribbon(pts, ws))
		var spokes = _mi(_mesh(surf), _glow_mat())
		_params(spokes, {"c1": Color(0.05, 0.05, 0.1), "c2": blue, "pat": 0.0, "reveal": 0.0, "nf": 1.0})
		_add(pj, spokes, Vector3.ZERO)
		_tp(spokes, "reveal", 0.0, 1.0, 0.12)
		_fade_free(spokes, 0.15, 0.3)
		pj.st(tt, "slow", 6.0)
		pj.st(tt, "stun", 1.2)
		tt.take_hit(pj.inf(c, "shisho_fuin", 1.4, {"knock": 0.0, "kind": "heavy", "chakra_drain": 45.0})))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== Fūinjutsu: Shishi Heikō
## Ref (Chiyo'nun kuklası Sasori'yi yakalar): krem rengi, yüzünde eş merkezli halkalar olan aslan başı; kapalı ağzın
## önünde kalın kara çerçeveli beyaz elmas içinde 閉; arkada çapraz giden kara mühür yazısı şeritleri. Aslan başı ağzı
## sonuna kadar açık belirir ve hedefin üstüne kapanır; yazı şeritleri X biçiminde kendini yazar. Süre bitince çene
## açılır, baş kâğıt kırpıntısına dağılır.
static func fuinjutsu_shishi_heiko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var to_c = _flat_dir(c.global_position - at)
	var pod = Node3D.new()
	_add(pj, pod, at)
	pod.basis = Basis.looking_at(-to_c, Vector3.UP)
	var cream = Color(0.93, 0.89, 0.76)
	var hinge = Vector3(0, 1.25, -0.95)
	var up_p = Node3D.new()
	var lo_p = Node3D.new()
	pod.add_child(up_p)
	pod.add_child(lo_p)
	up_p.position = hinge
	lo_p.position = hinge
	var hb = MB.new()
	hb.add("hemi", Vector3.ZERO, Vector3.ONE, Color(1, 1, 1), Vector3.ZERO, 24)
	var hemi = hb.build()
	var upper = _cel(hemi, cream, 2.0, 0.012, {"nf": 2.0}, true)
	upper.position = Vector3(0, 0, 0.95)
	upper.scale = Vector3(2.5, 2.9, 3.0)
	up_p.add_child(upper)
	var lower = _cel(hemi, cream.darkened(0.06), 2.0, 0.012, {"nf": 2.0}, true)
	lower.position = Vector3(0, 0, 0.95)
	lower.rotation.z = PI
	lower.scale = Vector3(2.4, 1.6, 2.9)
	lo_p.add_child(lower)
	var tb = MB.new()
	var lb = MB.new()
	for i in 9:
		var a = deg_to_rad(-70.0 + i * 17.5)
		var rp = Vector3(sin(a) * 1.15, 0.0, cos(a) * 1.38 + 0.95)
		tb.add("cone", rp + Vector3.DOWN * 0.1, Vector3(0.12, 0.24, 0.12), cream, Vector3(180, 0, 0), 5)
		lb.add("cone", rp + Vector3.UP * 0.08, Vector3(0.1, 0.18, 0.1), cream, Vector3.ZERO, 5)
	for s in [-1.0, 1.0]:
		tb.add("cone", Vector3(s * 0.75, 1.25, 0.6), Vector3(0.42, 0.6, 0.42), cream, Vector3(-15, 0, s * -20), 6)   # kulak
	for i in 7:
		var a = deg_to_rad(110.0 + i * 23.0)
		var dir = Vector3(sin(a), 0.0, cos(a))
		tb.add("cone", dir * 1.1 + Vector3(0, 0.35, 0.95), Vector3(0.3, 0.7, 0.3), cream.darkened(0.08),
			Vector3(70.0 * dir.z, 0, -70.0 * dir.x), 5)   # yele dikeni
	up_p.add_child(_cel(tb.build(), Color(1, 1, 1), 0.0, 0.01, {"nf": 2.0}))
	lo_p.add_child(_cel(lb.build(), Color(1, 1, 1), 0.0, 0.01, {"nf": 2.0}))
	var dia = _emblem(2.0, 0.95, {"ink": INK, "fill": Color(0.98, 0.98, 0.96), "reveal": 0.0, "bb": 0.0, "nf": 2.0})
	dia.position = Vector3(0, 0.62, 0.95 + 1.42)
	dia.rotation.x = -0.45
	up_p.add_child(dia)
	_tp(dia, "reveal", 0.0, 1.0, 0.5, 0.3)
	for s in [-1.0, 1.0]:
		var band = _script_quad(Vector2(7.0, 0.42), {"lay": 0.0, "style": 0.0, "grid": Vector2(36, 1), "ink": INK,
			"paper": Color(0.12, 0.1, 0.1, 0.25), "reveal": 0.0, "nf": 2.0, "seed": s * 7.0 + 20.0})
		band.position = Vector3(0, 1.5, -1.7)
		band.rotation.z = deg_to_rad(32.0 * s)
		pod.add_child(band)
		_tp(band, "reveal", 0.0, 1.0, 0.45, 0.2)
		_tp(band, "alpha", 1.0, 0.0, 0.3, 3.8)
	up_p.rotation.x = -0.95
	lo_p.rotation.x = 0.6
	pod.scale = Vector3.ONE * 0.3
	var tw = pod.create_tween()
	tw.tween_property(pod, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(up_p, "rotation:x", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(lo_p, "rotation:x", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(3.7)
	tw.tween_property(up_p, "rotation:x", -0.7, 0.15)
	tw.parallel().tween_property(lo_p, "rotation:x", 0.5, 0.15)
	tw.tween_interval(0.15)
	tw.tween_callback(pod.queue_free)
	_tp(pod, "alpha", 1.0, 0.0, 0.3, 4.0)
	pj.after(4.0, func():
		_spray(pj, at + Vector3.UP * 1.3, {"mesh": _quad(Vector2(1, 1)), "n": 24, "col": cream, "v0": 2.0, "v1": 5.0, "spread": 180.0,
			"grav": 3.0, "spin": 300.0, "s0": 0.08, "s1": 0.16, "life": 0.9, "r": 0.9}))
	var body = tt.get("model") if tt.get("model") else null
	if body:
		body.visible = false
		pj.after(4.3, func():
			if is_instance_valid(body):
				body.visible = true)
	pj.st(tt, "bind", 4.3)
	Combat.popup_text(at + Vector3.UP * 3.4, "Mühürlendi!", Color(0.95, 0.9, 0.8))
	Sfx.play("seal", at, 0.8)


# ================================================================== Fūinjutsu: Genryū Kyūfūjin
## Ref: Gedō heykelinin ağzından fışkıran dokuz mavi hayalet ejder — uzun burun, tırtıklı beyaz dişler, geriye yatık
## kulaklar, akışkan cel mavi gövde. Hedefin altında mavi-kara mühür formülü açılır; dokuz ejder gökten kavis çizip
## hedefe dalar (gövdeleri arkalarından akan tüp), değdiklerinde mavi çakra halkası parlar. Sonra hedeften gökyüzüne
## doğru burularak yükselen dokuz çakra akıntısı (emilen çakra).
static func fuinjutsu_genryu_kyufujin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 26.0)
	if tt == null:
		return
	var blue = Color(0.45, 0.75, 1.0)
	var gs = _ground_seal(pj, pj.gp(tt.global_position), 4.0, {"lay": 1.0, "style": 0.0, "grid": Vector2(36, 2), "inner": 0.36,
		"ink": Color(0.05, 0.08, 0.2), "edge": Color(0.45, 0.7, 1.0, 0.45), "reveal": 0.0, "nf": 2.0, "seed": randf() * 40.0})
	_tp(gs, "reveal", 0.0, 1.0, 0.5)
	_fade_free(gs, 3.6, 0.4)
	for k in 9:
		pj.after(0.3 + k * 0.08, func():
			if not (pj.live(c) and pj.live(tt)):
				return
			var a = k * TAU / 9.0
			var from = tt.global_position + Vector3(cos(a) * 10.0, 12.0, sin(a) * 10.0)
			var head = _cel(_dragon_head(), Color(1, 1, 1), 0.0, 0.02, {"nf": 1.5})
			pj.get_tree().current_scene.add_child(head)
			head.global_position = from
			head.scale = Vector3.ONE * 1.3
			var am = ArrayMesh.new()
			var bodym = _mi(am, _glow_mat())
			_params(bodym, {"c1": Color(0.78, 0.92, 1.0), "c2": Color(0.35, 0.6, 1.0), "pat": 1.0, "nf": 1.5, "seed": k * 1.1})
			_add(pj, bodym, Vector3.ZERO)
			var hist: Array = [from]
			var mid = tt.global_position + Vector3(cos(a + 1.2) * 4.0, 5.0, sin(a + 1.2) * 4.0)
			var tw = head.create_tween()
			tw.tween_method(func(u: float):
				if is_instance_valid(head) and is_instance_valid(tt):
					var p = from.lerp(mid, u).lerp(mid.lerp(tt.global_position + Vector3.UP, u), u)
					head.look_at(p + (p - head.global_position).normalized() * 0.1 + Vector3(0.001, 0, 0), Vector3.UP)
					head.global_position = p
					hist.push_front(p - head.global_transform.basis.z * -0.5)
					if hist.size() > 16:
						hist.pop_back()
					if hist.size() >= 3 and is_instance_valid(bodym):
						var rr: Array = []
						for i in hist.size():
							rr.append(lerpf(0.3, 0.03, float(i) / float(hist.size() - 1)))
						am.clear_surfaces()
						am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _tube(hist, rr, 8)), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(func():
				if pj.live(tt):
					var fl = _emblem(6.0, 2.2, {"fill": Color(0.9, 0.97, 1.0), "accent": blue, "reveal": 0.0, "nf": 1.2})
					_add(pj, fl, tt.global_position + Vector3.UP)
					_tp(fl, "reveal", 0.0, 1.0, 0.25)
					_fade_free(fl, 0.1, 0.2)
					tt.take_hit(pj.inf(c, "fuinjutsu_genryu_kyufujin", 0.35, {"knock": 0.0, "kind": "light", "chakra_drain": 15.0})))
			tw.tween_callback(head.queue_free)
			tw.tween_callback(func():
				if is_instance_valid(bodym):
					_fade_free(bodym, 0.0, 0.2)))
	pj.after(1.1, func():
		if pj.live(tt):
			pj.st(tt, "bind", 3.5)
			for k in 9:
				var y0 = 0.6 + k * 0.12
				var bend = func(u, tm, _a, _b):
					var ang = k * TAU / 9.0 + u * 4.0 - tm * 3.0
					return Vector3(cos(ang), 0.0, sin(ang)) * (0.35 + u * 0.9) * sin(u * PI * 0.9 + 0.2)
				var dr = _strand(pj, _glow_mat(), {"c1": Color(0.85, 0.95, 1.0), "c2": blue, "pat": 0.0, "alpha": 0.0, "nf": 1.5},
					func(): return tt.global_position + Vector3.UP * y0 if pj.live(tt) else Vector3.ZERO,
					func(): return tt.global_position + Vector3.UP * (3.4 + k * 0.15) if pj.live(tt) else Vector3.ZERO, 3.5,
					{"n": 16, "w": func(u): return 0.07 * (1.0 - u * 0.6), "bend": bend})
				_tp(dr, "alpha", 0.0, 1.0, 0.3)
				_tp(dr, "alpha", 1.0, 0.0, 0.3, 3.2))
	Sfx.play("roar", c.global_position, 1.3)


## Hayalet ejder başı (-Z ileri): kafatası, uzun burun, alt çene, geriye yatık kulaklar, göz yarıkları, beyaz dişler
static func _dragon_head() -> ArrayMesh:
	if _cache.has("dragon_head"):
		return _cache["dragon_head"]
	var b = MB.new()
	var cb = Color(0.5, 0.76, 1.0)
	var cd = Color(0.28, 0.48, 0.88)
	var wt = Color(0.96, 0.98, 1.0)
	b.add("sphere", Vector3.ZERO, Vector3(0.55, 0.45, 0.7), cb, Vector3.ZERO, 14)
	b.add("sphere", Vector3(0, -0.05, -0.45), Vector3(0.38, 0.26, 0.62), cb, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, -0.2, -0.35), Vector3(0.32, 0.12, 0.55), cd, Vector3.ZERO, 10)
	for s in [-1.0, 1.0]:
		b.add("cone", Vector3(s * 0.18, 0.2, 0.25), Vector3(0.12, 0.55, 0.12), cb, Vector3(60, 0, s * -15), 6)
		b.add("box", Vector3(s * 0.17, 0.08, -0.2), Vector3(0.1, 0.03, 0.14), Color(0.04, 0.07, 0.2), Vector3(0, s * 20, s * -15))
		for i in 4:
			b.add("cone", Vector3(s * 0.13, -0.13, -0.32 - i * 0.11), Vector3(0.05, 0.1, 0.05), wt, Vector3(180, 0, 0), 4)
	_cache["dragon_head"] = b.build()
	return _cache["dragon_head"]


# ================================================================== Fūinjutsu: Koshi Tandan
## Ref (Shin / Sai tarzı mürekkep): parşömene fırçayla çizilmiş beyaz, kalın kara çizgili kaplan; çizim kâğıttan
## fırlayıp hedefi pençeleriyle bastırır. Yere açılan parşömende kaplan çizgileri fırça darbeleriyle belirir, mürekkep
## kaplan kâğıttan sıçrar (koşarken bacaklar ve gövde salınır, arkasından mürekkep damlar); vurunca kara mürekkebe
## dağılır, yerde mürekkep lekesi kalır.
static func fuinjutsu_koshi_tandan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.8)
	var ink = Color(0.08, 0.08, 0.1)
	var fd = _flat_dir(c.face_dir())
	var scroll = Node3D.new()
	_add(pj, scroll, pj.gp(c.global_position + fd * 1.1) + Vector3.UP * 0.03)
	scroll.basis = Basis.looking_at(fd, Vector3.UP)
	var sp = _cel(_quad(Vector2(1.6, 0.9)), PAPER, 5.0, 0.0, {"line": Color(0.3, 0.2, 0.4), "nf": 1.0})
	sp.rotation.x = -PI * 0.5
	scroll.add_child(sp)
	var draw = _script_quad(Vector2(1.4, 0.75), {"lay": 0.0, "style": 5.0, "ink": ink, "reveal": 0.0, "nf": 1.0})
	draw.rotation.x = -PI * 0.5
	draw.position = Vector3.UP * 0.006
	scroll.add_child(draw)
	_tp(draw, "reveal", 0.0, 1.0, 0.15)
	_tp(draw, "alpha", 1.0, 0.0, 0.2, 0.2)
	_fade_free(scroll, 1.0, 0.3)
	var tiger = _ink_tiger()
	var from = c.global_position + Vector3.UP * 0.2 + c.face_dir() * 1.2
	_spray(pj, from + Vector3.UP * 0.6, {"n": 22, "col": ink, "v0": 1.5, "v1": 4.0, "spread": 70.0, "grav": 10.0, "s0": 0.05, "s1": 0.12, "life": 0.6, "r": 0.5})
	var dir = pj.aim_at(c, tt, from)
	dir.y = 0
	var pr = pj.shot(c, from, dir.normalized(), 22.0, tiger, pj.inf(c, "fuinjutsu_koshi_tandan", 0.6, {"knock": 2.0, "kind": "heavy"}), tt, false, 1.6, func(p, h):
		_spray(pj, p + Vector3.UP, {"n": 40, "col": ink, "v0": 3.0, "v1": 7.0, "spread": 100.0, "grav": 14.0, "s0": 0.07, "s1": 0.16, "life": 0.8, "r": 0.7})
		var splat = _emblem(9.0, 2.4, {"ink": ink, "reveal": 0.0, "bb": 0.0, "seed": randf() * 20.0, "nf": 1.5})
		splat.rotation.x = -PI * 0.5
		_add(pj, splat, pj.gp(p) + Vector3.UP * 0.035)
		_tp(splat, "reveal", 0.0, 1.0, 0.2)
		_fade_free(splat, 2.0, 0.6)
		if h and pj.live(h):
			pj.st(h, "bind", 4.0)
			var lbl = _label("封", 0.006, ink, Color(0.95, 0.93, 0.85))
			lbl.position = Vector3.UP * 1.2
			lbl.outline_size = 30
			h.add_child(lbl)
			pj.get_tree().create_timer(4.0).timeout.connect(func():
				if is_instance_valid(lbl):
					lbl.queue_free())
			Combat.popup_text(h.global_position + Vector3.UP * 2.6, "Mühürlendi!", Color(0.95, 0.93, 0.85)))
	pr.homing_turn = 4.0
	pr.radius = 0.9
	_spray(pj, Vector3.ZERO, {"parent": pr, "off": Vector3(0, 0.7, 0.6), "one_shot": false, "n": 30, "life": 0.5, "col": ink, "v0": 0.0, "v1": 0.6,
		"grav": 9.0, "s0": 0.05, "s1": 0.1, "r": 0.35})
	Sfx.play("seal", c.global_position, 1.0)


## Mürekkep kaplan (-Z ileri): gövde, göğüs, baş, ağız, kulak, çatık göz, S kuyruk + salınan dört bacak; beyaz zemin,
## fırça çizgileri gölgelendiricide, koyu kontur
static func _ink_tiger() -> Node3D:
	var wc = Color(0.97, 0.96, 0.93)
	if not _cache.has("tiger_body"):
		var b = MB.new()
		b.add("sphere", Vector3(0, 0.75, 0.1), Vector3(0.85, 0.75, 1.7), wc, Vector3.ZERO, 16)
		b.add("sphere", Vector3(0, 0.85, -0.55), Vector3(0.8, 0.75, 0.8), wc, Vector3.ZERO, 14)
		b.add("sphere", Vector3(0, 1.0, -1.0), Vector3(0.62, 0.58, 0.6), wc, Vector3.ZERO, 14)
		b.add("sphere", Vector3(0, 0.9, -1.28), Vector3(0.36, 0.28, 0.3), wc, Vector3.ZERO, 10)
		for s in [-1.0, 1.0]:
			b.add("cone", Vector3(s * 0.2, 1.3, -0.95), Vector3(0.16, 0.18, 0.1), wc, Vector3.ZERO, 5)
			b.add("box", Vector3(s * 0.13, 1.08, -1.27), Vector3(0.12, 0.035, 0.03), INK, Vector3(0, 0, s * -18))
		b.add("box", Vector3(0, 0.82, -1.43), Vector3(0.1, 0.06, 0.04), INK)
		for i in 6:
			b.add("sphere", Vector3(0, 0.95 + sin(i * 0.6) * 0.25 + i * 0.1, 0.95 + i * 0.17), Vector3(0.13, 0.13, 0.22), wc, Vector3.ZERO, 8)
		_cache["tiger_body"] = b.build()
		var lg = MB.new()
		lg.add("cyl", Vector3(0, -0.3, 0), Vector3(0.22, 0.6, 0.22), wc, Vector3.ZERO, 8)
		lg.add("sphere", Vector3(0, -0.6, -0.05), Vector3(0.26, 0.14, 0.32), wc, Vector3.ZERO, 8)
		_cache["tiger_leg"] = lg.build()
	var root = Node3D.new()
	var bob = Node3D.new()
	root.add_child(bob)
	bob.add_child(_cel(_cache["tiger_body"], Color(1, 1, 1), 3.0, 0.025, {"line": INK, "nf": 1.5}))
	var hips = [Vector3(-0.28, 0.65, -0.6), Vector3(0.28, 0.65, -0.6), Vector3(-0.28, 0.6, 0.55), Vector3(0.28, 0.6, 0.55)]
	for i in 4:
		var leg = _cel(_cache["tiger_leg"], Color(1, 1, 1), 3.0, 0.02, {"line": INK, "seed": 1.0, "nf": 1.5})
		leg.position = hips[i]
		bob.add_child(leg)
		var ph = 1.0 if (i == 0 or i == 3) else -1.0
		leg.rotation.x = 0.6 * ph
		var lt = leg.create_tween().set_loops()
		lt.tween_property(leg, "rotation:x", -0.6 * ph, 0.13).set_trans(Tween.TRANS_SINE)
		lt.tween_property(leg, "rotation:x", 0.6 * ph, 0.13).set_trans(Tween.TRANS_SINE)
	var bt = bob.create_tween().set_loops()
	bt.tween_property(bob, "position:y", 0.12, 0.13).set_trans(Tween.TRANS_SINE)
	bt.parallel().tween_property(bob, "rotation:x", 0.07, 0.13).set_trans(Tween.TRANS_SINE)
	bt.tween_property(bob, "position:y", 0.0, 0.13).set_trans(Tween.TRANS_SINE)
	bt.parallel().tween_property(bob, "rotation:x", -0.07, 0.13).set_trans(Tween.TRANS_SINE)
	root.scale = Vector3.ONE * 0.2
	var st = root.create_tween()
	st.tween_property(root, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


# ================================================================== Jigō Jubaku no In
## Kaynak görsel yok: gizli bilgi taşıyanın bedenine kazınan lanet. Kara mürekkep zerreleri boyuna toplanır; boynu
## kara yazılı bir mühür halkası sarar, oradan sekiz tırtıklı kara lanet sarmaşığı (mor kenarlı) bedenin üstünde
## aşağı doğru sarmal çizerek ayaklara iner ve bedeni kilitler; süre bitince solar.
static func jigo_jubaku_no_in(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.7)
	if tt == null:
		return
	_spray(pj, tt.global_position + Vector3.UP * 1.55, {"n": 26, "col": INK, "surface": true, "r": 1.4, "v0": 0.0, "v1": 0.2,
		"radial": -14.0, "grav": 0.0, "s0": 0.05, "s1": 0.09, "life": 0.45})
	var root = Node3D.new()
	tt.add_child(root)
	pj.fit_body(tt, root)   # hedef boyunda
	var neck_m = CylinderMesh.new()
	neck_m.top_radius = 0.2
	neck_m.bottom_radius = 0.22
	neck_m.height = 0.11
	neck_m.radial_segments = 24
	neck_m.cap_top = false
	neck_m.cap_bottom = false
	var neck = _mi(neck_m, _script_mat())
	_params(neck, {"lay": 0.0, "style": 0.0, "grid": Vector2(12, 1), "ink": INK, "edge": Color(0.5, 0.25, 0.6, 0.6), "reveal": 0.0, "nf": 1.0})
	neck.position = Vector3.UP * 1.6
	root.add_child(neck)
	_tp(neck, "reveal", 0.0, 1.0, 0.25, 0.25)
	var surf: Array = []
	for k in 8:
		var a = k * TAU / 8.0
		var yend = 0.2 + (k % 3) * 0.4
		var w = _wrap_pts(22, func(u): return Vector3(a + 0.6 * u + sin(u * PI * 2.0 + k) * 0.15, lerpf(1.55, yend, u), 0.37 + 0.03 * sin(u * 9.0 + k)))
		var ws: Array = []
		for i in 22:
			ws.append(0.08 * (1.0 - float(i) / 42.0))
		surf.append(_ribbon(w["p"], ws, w["n"]))
	var vines = _mi(_mesh(surf), _glow_mat())
	_params(vines, {"c1": INK, "c2": Color(0.45, 0.22, 0.55), "pat": 3.0, "reveal": 0.0, "nf": 1.0, "seed": randf() * 10.0})
	root.add_child(vines)
	_tp(vines, "reveal", 0.0, 1.0, 0.5, 0.35)
	_fade_free(root, 3.7, 0.3)
	pj.st(tt, "stun", 4.0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Lanet mühür!", Color(0.6, 0.5, 0.7))
	Sfx.play("seal", tt.global_position, 0.7)
