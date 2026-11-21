class_name NinjutsuFXE
extends RefCounted
## Genel ninjutsu grubu E: mürekkep canavarları (Chōjū / Chōshin Giga), kuyruklu canavar teknikleri (Chō Mini Bijūdama,
## Canavar Telepatisi), kurbağa teknikleri (Gamayudan, Kaeru Kaeru), Chōōdama Rasengan, Abusōbu Sufia, Gentōshin,
## Tōton, Kanashibari, Tenchū, Takoashi Bunshin, Zesshi Nensan, Shikomishindan.
## Her tekniğin görüntüsü bu dosyada sıfırdan üretilir (kendi cel / kontur / mürekkep / yağ / boşluk / spiral / hologram /
## kırılma / zemin mührü gölgelendiricileri ve kendi parça yapı taşları). Oynanış ana ağaçtaki işleyicilerden satır satır
## taşındı; gerçek sistemler (mürekkep yapıtı, gölge klon, buff, gizlenme, mermi) olduğu gibi kullanılır — yalnız görünüş yeni.
## Okunurluk: tüm gölgelendiricilerde kameraya yakın kısım yumuşakça söner (near_a → near_b); büyük kütlelerde 3–7 m.

const INK := Color(0.07, 0.05, 0.09, 1.0)
const SUMI := Color(0.03, 0.03, 0.04, 1.0)
const SUMI_HI := Color(0.93, 0.93, 0.96, 1.0)
const PAPER := Color(0.96, 0.93, 0.84, 1.0)
const PAPER_EDGE := Color(0.62, 0.52, 0.36, 1.0)
const WOOD := Color(0.45, 0.27, 0.14, 1.0)
const BIJU_RIM := Color(0.72, 0.45, 1.0, 1.0)
const BIJU_HOT := Color(0.97, 0.9, 1.0, 1.0)
const TELE := Color(1.0, 0.56, 0.18, 1.0)
const TELE_DARK := Color(0.55, 0.12, 0.05, 1.0)
const PARA := Color(0.62, 0.42, 0.75, 1.0)
const OIL_BASE := Color(0.8, 0.58, 0.16, 1.0)
const OIL_SPOT := Color(0.97, 0.86, 0.46, 1.0)
const OIL_DARK := Color(0.42, 0.26, 0.06, 1.0)
const FROG := Color(0.42, 0.68, 0.32, 1.0)
const FROG_DARK := Color(0.26, 0.46, 0.2, 1.0)
const FROG_BELLY := Color(0.9, 0.88, 0.62, 1.0)
const RASEN_CORE := Color(0.96, 0.99, 1.0, 1.0)
const RASEN_MID := Color(0.45, 0.76, 1.0, 1.0)
const RASEN_LINE := Color(0.1, 0.24, 0.58, 1.0)
const ABS_GLOW := Color(0.3, 0.56, 1.0, 1.0)
const ABS_HOT := Color(0.85, 0.95, 1.0, 1.0)
const HOLO := Color(0.45, 0.9, 1.0, 1.0)
const SEAL_RED := Color(0.62, 0.08, 0.06, 1.0)
const STEEL := Color(0.74, 0.77, 0.82, 1.0)
const GRIP := Color(0.14, 0.13, 0.16, 1.0)
const OCTO_SKIN := Color(0.44, 0.25, 0.36, 1.0)
const OCTO_SUCK := Color(0.9, 0.68, 0.74, 1.0)
const ACID := Color(0.86, 0.8, 0.22, 1.0)
const ACID_SPOT := Color(0.98, 0.96, 0.6, 1.0)
const ACID_DARK := Color(0.4, 0.42, 0.06, 1.0)
const VENOM := Color(0.45, 0.88, 0.35, 1.0)

static var _sh := {}
static var _mc := {}

# ================================================================== gölgelendiriciler
## Cel yüzey: köşe rengi × tint, iki ton, isteğe bağlı vurgu; grow: UV.x boyunca çizilerek açılma; kameraya yakın söner.
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, CULLMODE, DEPTHMODE, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float shade_k = 0.72;
uniform float hi = 0.0;
uniform float grow = 100000.0;
uniform float fade = 1.0;
uniform float near_a = 0.4;
uniform float near_b = 1.6;

varying vec3 wnrm;

void vertex() {
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	if (UV.x > grow) {
		discard;
	}
	vec3 n = normalize(wnrm);
	if (!FRONT_FACING) {
		n = -n;
	}
	float l = dot(n, normalize(vec3(0.35, 1.0, 0.25)));
	vec3 c = tint.rgb * COLOR.rgb;
	if (l < 0.05) {
		c *= shade_k;
	}
	if (hi > 0.0 && l > 0.86) {
		c = mix(c, vec3(1.0), hi);
	}
	ALBEDO = c;
	ALPHA = clamp(tint.a * COLOR.a * fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Koyu kontur: ters kabuk (arka yüzler normal boyunca şişirilir)
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.09, 1.0);
uniform float width = 0.015;
uniform float grow = 100000.0;
uniform float fade = 1.0;
uniform float near_a = 0.4;
uniform float near_b = 1.6;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	if (UV.x > grow) {
		discard;
	}
	ALBEDO = ink.rgb;
	ALPHA = clamp(ink.a * COLOR.a * fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Sumi mürekkebi fırça darbesi (şerit): kıl izli kenar, kuru fırça kuyruğu, beyaz parlak damarlar; grow/tail ile çizilir / çekilir.
const INK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform vec4 hi_col : source_color = vec4(0.93, 0.93, 0.96, 1.0);
uniform float grow = 1.0;
uniform float tail = 0.0;
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float near_a = 0.5;
uniform float near_b = 2.0;

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1.0, 0.0)), f.x), mix(hs(i + vec2(0.0, 1.0)), hs(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	if (u > grow || u < tail) {
		discard;
	}
	float edge = abs(v - 0.5) * 2.0;
	float rough = vn(vec2(u * 38.0 + seed, v * 2.0));
	if (edge > 0.8 + 0.2 * rough) {
		discard;
	}
	float bristle = vn(vec2(u * 5.0 + seed, v * 30.0));
	if (u > 0.72 && bristle < (u - 0.72) * 2.6) {
		discard;
	}
	vec3 c = ink.rgb;
	float vein = step(0.74, vn(vec2(u * 7.0 - seed, v * 8.0 + seed)));
	if (edge < 0.55) {
		c = mix(c, hi_col.rgb, vein * 0.9);
	}
	ALBEDO = c;
	ALPHA = clamp(fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Kalın yapışkan sıvı (kurbağa yağı / asit): nesne uzayında benekler, cel iki ton, ıslak parlama, koyu kenar; fizz: kaynayan benek.
const OIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 base_col : source_color = vec4(0.8, 0.58, 0.16, 1.0);
uniform vec4 spot_col : source_color = vec4(0.97, 0.86, 0.46, 1.0);
uniform vec4 dark_col : source_color = vec4(0.42, 0.26, 0.06, 1.0);
uniform float spot_k = 3.0;
uniform float spot_t = 0.62;
uniform float fizz = 0.0;
uniform float seed = 0.0;
uniform float grow = 100000.0;
uniform float fade = 1.0;
uniform float near_a = 0.5;
uniform float near_b = 2.0;

varying vec3 op;
varying vec3 wnrm;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	op = VERTEX;
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	if (UV.x > grow) {
		discard;
	}
	vec3 n3 = normalize(wnrm);
	if (!FRONT_FACING) {
		n3 = -n3;
	}
	float l = dot(n3, normalize(vec3(0.35, 1.0, 0.25)));
	float nz = vn3(op * spot_k + vec3(seed, seed * 0.7, -TIME * fizz));
	vec3 c = base_col.rgb;
	if (nz > spot_t) {
		c = spot_col.rgb;
	}
	if (l < 0.0) {
		c = mix(c, dark_col.rgb, 0.5);
	}
	vec3 lv = normalize((VIEW_MATRIX * vec4(0.3, 1.0, 0.2, 0.0)).xyz);
	float sp = dot(reflect(-VIEW, NORMAL), lv);
	if (sp > 0.93) {
		c = mix(c, vec3(1.0, 0.98, 0.9), 0.85);
	}
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (fr > 0.9) {
		c = dark_col.rgb;
	}
	ALBEDO = c;
	ALPHA = clamp(base_col.a * COLOR.a * fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Boşluk küresi: zifiri öz, ince titreyen parlak kenar (Abusōbu küresi / Bijūdama çekirdeği)
const VOID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 body : source_color = vec4(0.02, 0.02, 0.06, 1.0);
uniform vec4 glow_col : source_color = vec4(0.3, 0.56, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float rim_w = 0.22;
uniform float wob = 1.0;
uniform float fade = 1.0;
uniform float near_a = 0.5;
uniform float near_b = 2.0;

void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fl = sin(atan(NORMAL.y, NORMAL.x) * 11.0 + TIME * 7.0) * 0.5 + 0.5;
	float ew = smoothstep(1.0 - rim_w - 0.06 * fl * wob, 1.0, fr);
	vec3 c = mix(body.rgb, glow_col.rgb, ew);
	c = mix(c, hot.rgb, smoothstep(0.8, 1.0, ew) * 0.75);
	ALBEDO = c;
	ALPHA = clamp(fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Yüze dönük ışıma halesi: iç halka + (flow > 0) içe / (flow < 0) dışa akan sarmal çizgiler
const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 col : source_color = vec4(0.3, 0.56, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float inner = 0.45;
uniform float arms = 7.0;
uniform float flow = 1.0;
uniform float fade = 1.0;
uniform float near_a = 0.5;
uniform float near_b = 2.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) {
		discard;
	}
	float a = atan(q.y, q.x);
	float sp = sin(a * arms + log(max(r, 0.01)) * 9.0 + TIME * flow * 6.0);
	float streak = smoothstep(0.55, 0.9, sp);
	float ring = 1.0 - smoothstep(0.0, 0.12, abs(r - inner - 0.03));
	float outer = 1.0 - smoothstep(inner, 1.0, r);
	float m = ring * 0.95 + streak * outer * 0.6 * step(inner, r);
	ALBEDO = mix(col.rgb, hot.rgb, ring);
	ALPHA = clamp(m * col.a * fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Rasengan topu: dönen sarmal bantlar, beyaz öz, koyu mavi cel kenar
const SPIRAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 core : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform vec4 mid : source_color = vec4(0.45, 0.76, 1.0, 1.0);
uniform vec4 line_col : source_color = vec4(0.1, 0.24, 0.58, 1.0);
uniform float arms = 5.0;
uniform float twist = 6.0;
uniform float spd = 9.0;
uniform float fade = 1.0;
uniform float near_a = 0.5;
uniform float near_b = 2.0;

varying vec3 op;

void vertex() {
	op = VERTEX;
}

void fragment() {
	vec3 p = normalize(op);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ang = atan(p.z, p.x);
	float s1 = sin(ang * arms + p.y * twist - TIME * spd);
	float s2 = sin(ang * (arms + 3.0) - p.y * twist * 1.7 - TIME * spd * 1.6);
	float band = clamp(step(0.55, s1) + step(0.78, s2) * 0.6, 0.0, 1.0);
	vec3 c = mix(mid.rgb, core.rgb, band);
	c = mix(c, core.rgb, (1.0 - fr) * 0.55);
	float a = 0.5 + 0.4 * band;
	if (fr > 0.84) {
		c = line_col.rgb;
		a = 0.95;
	}
	ALBEDO = c;
	ALPHA = clamp(a * fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Gürültüyle çözülen patlama kütlesi (Bijūdama): koyu öz, çözülme sınırında parlak çizgi
const DISSOLVE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 body : source_color = vec4(0.12, 0.04, 0.2, 1.0);
uniform vec4 edge_col : source_color = vec4(0.88, 0.72, 1.0, 1.0);
uniform vec4 line_col : source_color = vec4(0.04, 0.0, 0.08, 1.0);
uniform float cut = 0.0;
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float near_a = 3.0;
uniform float near_b = 7.0;

varying vec3 op;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	op = VERTEX;
}

void fragment() {
	float nz = vn3(op * 3.0 + vec3(seed, -TIME * 1.5, seed)) * 0.65 + vn3(op * 7.0 + vec3(seed)) * 0.35;
	if (nz < cut) {
		discard;
	}
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(body.rgb, edge_col.rgb, smoothstep(0.55, 0.9, fr) * 0.6);
	if (nz < cut + 0.06) {
		c = edge_col.rgb;
	}
	if (fr > 0.9) {
		c = line_col.rgb;
	}
	ALBEDO = c;
	ALPHA = clamp(fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Zemin mührü / desen diski (PlaneMesh UV): mode 0 kurbağa sözleşme yazısı, 1 Tenchū hedef mührü, 2 projektör dairesi,
## 3 zihin dünyası dalgaları + dokuz nokta, 4 içe akan felç çizgileri. prog: açı boyunca çizilerek açılır.
const GLYPH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 col : source_color = vec4(1.0);
uniform vec4 ink_col : source_color = vec4(0.07, 0.05, 0.09, 1.0);
uniform int mode = 0;
uniform float prog = 1.0;
uniform float fade = 1.0;
uniform float near_a = 0.5;
uniform float near_b = 2.0;

float hs(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float ring(float r, float at, float w) {
	return 1.0 - step(w, abs(r - at));
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) {
		discard;
	}
	float a = atan(q.y, q.x);
	float an = a / 6.2831853 + 0.5;
	if (an > prog) {
		discard;
	}
	float m = 0.0;
	float k = 0.0;
	float al = 1.0;
	if (mode == 0) {
		m = max(ring(r, 0.95, 0.035), ring(r, 0.87, 0.014));
		m = max(m, ring(r, 0.36, 0.02));
		float cell = floor(an * 48.0);
		float fc = fract(an * 48.0);
		float rr = (r - 0.44) / 0.38;
		float len = 0.3 + 0.7 * hs(cell);
		if (rr > 0.0 && rr < len && fc > 0.3 && fc < 0.7) {
			m = 1.0;
			k = 1.0;
		}
		float c2 = fract(an * 8.0);
		if (r < 0.34 && abs(c2 - 0.5) < 0.04 && r > 0.12) {
			m = 1.0;
		}
	} else if (mode == 1) {
		m = max(ring(r, 0.96, 0.03), ring(r, 0.6, 0.012));
		float fc = fract(an * 12.0);
		float w = (r - 0.62) / 0.3;
		if (r > 0.62 && r < 0.93 && abs(fc - 0.5) * 2.0 < w * 0.55) {
			m = 1.0;
			k = 1.0;
		}
		if ((abs(q.x) < 0.025 || abs(q.y) < 0.025) && r < 0.45) {
			m = 1.0;
		}
		if (ring(r, 0.2, 0.025) > 0.5) {
			m = 1.0;
			k = 1.0;
		}
	} else if (mode == 2) {
		m = ring(r, 0.96, 0.012);
		if (ring(r, 0.8, 0.02) > 0.5 && fract(an * 6.0 + TIME * 0.3) < 0.6) {
			m = 1.0;
			k = 1.0;
		}
		float sw = fract(an - TIME * 0.5);
		if (r < 0.78) {
			float s = (1.0 - smoothstep(0.0, 0.18, sw)) * 0.55;
			if (s > 0.02) {
				m = max(m, 1.0);
				al = max(s, 0.0);
				k = 1.0;
			}
		}
		vec2 g = fract(q * 6.0);
		if (r < 0.78 && length(g - 0.5) < 0.06) {
			m = 1.0;
			al = 0.8;
		}
	} else if (mode == 3) {
		float rp = fract(r * 5.0 - TIME * 0.8);
		if (rp < 0.12) {
			m = 1.0;
			al = 1.0 - r * 0.8;
			k = 1.0;
		}
		for (int i = 0; i < 9; i++) {
			float ai = float(i) / 9.0 * 6.2831853;
			if (length(q - vec2(cos(ai), sin(ai)) * 0.86) < 0.055) {
				m = 1.0;
				al = 1.0;
				k = 0.0;
			}
		}
	} else {
		float cell = floor(an * 40.0);
		float fc = fract(an * 40.0);
		float h = hs(cell);
		float wd = 0.12 + 0.3 * r;
		if (r > h * 0.4 && fract(r * 1.5 + TIME * 3.0 + h) < 0.45 && abs(fc - 0.5) < wd * 0.5) {
			m = 1.0;
			al = r;
		}
	}
	if (m < 0.5) {
		discard;
	}
	ALBEDO = mix(ink_col.rgb, col.rgb, k);
	ALPHA = clamp(al * col.a * fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Hız / iz şeridi: UV.x başta dolu, sona doğru söner (toplanan renk)
const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 head : source_color = vec4(1.0);
uniform vec4 tail_col : source_color = vec4(0.5, 0.6, 0.8, 1.0);
uniform float fade = 1.0;
uniform float near_a = 0.4;
uniform float near_b = 1.5;

void fragment() {
	float u = UV.x;
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float a = pow(1.0 - u, 1.6) * smoothstep(0.0, 0.5, across);
	ALBEDO = mix(head.rgb, tail_col.rgb, u);
	ALPHA = clamp(a * head.a * fade * smoothstep(near_a, near_b, length(VERTEX)), 0.0, 1.0);
}
"""

## Tōton: beden üzerine giydirilen kırılma katmanı — sweep yüksekliğinin altı saydamlaşır, sınırda parlak çizgi
const REFRACT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform vec4 edge : source_color = vec4(0.85, 0.97, 1.0, 1.0);
uniform float sweep = 1.0;
uniform float y0 = 0.0;
uniform float hgt = 1.8;
uniform float amt = 1.0;
uniform float fade = 1.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float hy = (wp.y - y0) / hgt;
	float band = 1.0 - smoothstep(0.0, 0.05, abs(hy - sweep));
	float inside = step(hy, sweep);
	vec2 off = NORMAL.xy * 0.03 * amt + vec2(sin(TIME * 8.0 + SCREEN_UV.y * 60.0), 0.0) * 0.004 * amt;
	vec3 bg = textureLod(scr, SCREEN_UV + off, 0.0).rgb;
	float line = clamp(band * 0.9 + step(0.84, fr) * step(fr, 0.94) * 0.4 * inside, 0.0, 1.0);
	ALBEDO = mix(bg, edge.rgb, line);
	ALPHA = clamp(max(inside, band) * fade, 0.0, 1.0);
}
"""

## Gentōshin: bedene giydirilen hologram katmanı — tarama çizgileri, gökkuşağı kenar, kesik kesik kayma
const HOLO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 col : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float fade = 1.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float scan = step(0.55, fract(wp.y * 22.0 - TIME * 3.0));
	float gl = step(0.9, fract(sin(floor(wp.y * 9.0) * 78.233 + floor(TIME * 12.0) * 12.9898) * 43758.5453));
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831853 * (fr * 1.5 + wp.y * 0.4 + TIME * 0.6 + vec3(0.0, 0.33, 0.67)));
	vec3 c = mix(col.rgb * 0.5, rainbow, smoothstep(0.55, 0.95, fr));
	float a = 0.16 * scan + smoothstep(0.6, 1.0, fr) * 0.9 + gl * 0.35;
	ALBEDO = c;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""


# ================================================================== malzeme yapı taşları
static func _shader(key: String, code: String) -> Shader:
	if not _sh.has(key):
		var s := Shader.new()
		s.code = code
		_sh[key] = s
	return _sh[key]


static func _smat(key: String, code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(key, code)
	return m


## Cel malzeme + koyu kontur (outline > 0). two: tek katlı yüzeyler için iki yüz. na/nb: kamera yakın sönümü
static func cel(col := Color.WHITE, outline := 0.015, ink := INK, two := false, hi := 0.0, na := 0.4, nb := 1.6, nodepth := false) -> ShaderMaterial:
	var key := ("cel2" if two else "cel") + ("_nd" if nodepth else "")
	var code := CEL_SHADER.replace("CULLMODE", "cull_disabled" if two else "cull_back").replace("DEPTHMODE", "depth_draw_never" if nodepth else "depth_draw_always")
	var m := _smat(key, code)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("hi", hi)
	m.set_shader_parameter("near_a", na)
	m.set_shader_parameter("near_b", nb)
	if outline > 0.0:
		var o := _smat("ol", OUTLINE_SHADER)
		o.set_shader_parameter("ink", ink)
		o.set_shader_parameter("width", outline)
		o.set_shader_parameter("near_a", na)
		o.set_shader_parameter("near_b", nb)
		o.render_priority = -1
		m.next_pass = o
	return m


static func ink_mat(seed := -1.0, na := 0.5, nb := 2.0) -> ShaderMaterial:
	var m := _smat("ink", INK_SHADER)
	m.set_shader_parameter("seed", seed if seed >= 0.0 else randf() * 60.0)
	m.set_shader_parameter("near_a", na)
	m.set_shader_parameter("near_b", nb)
	m.set_shader_parameter("grow", 0.0)
	return m


static func oil_mat(base: Color, spot: Color, dark: Color, spot_k := 3.0, fizz := 0.0, outline := 0.0) -> ShaderMaterial:
	var m := _smat("oil", OIL_SHADER)
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("spot_col", spot)
	m.set_shader_parameter("dark_col", dark)
	m.set_shader_parameter("spot_k", spot_k)
	m.set_shader_parameter("fizz", fizz)
	m.set_shader_parameter("seed", randf() * 40.0)
	if outline > 0.0:
		var o := _smat("ol", OUTLINE_SHADER)
		o.set_shader_parameter("ink", dark.darkened(0.4))
		o.set_shader_parameter("width", outline)
		o.render_priority = -1
		m.next_pass = o
	return m


static func void_mat(glow: Color, hotc: Color, rim_w := 0.22) -> ShaderMaterial:
	var m := _smat("void", VOID_SHADER)
	m.set_shader_parameter("glow_col", glow)
	m.set_shader_parameter("hot", hotc)
	m.set_shader_parameter("rim_w", rim_w)
	return m


static func halo_mat(col: Color, hotc: Color, inner := 0.45, arms := 7.0, flow := 1.0, na := 0.5, nb := 2.0) -> ShaderMaterial:
	var m := _smat("halo", HALO_SHADER)
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("hot", hotc)
	m.set_shader_parameter("inner", inner)
	m.set_shader_parameter("arms", arms)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("near_a", na)
	m.set_shader_parameter("near_b", nb)
	return m


static func glyph_mat(col: Color, inkc: Color, mode: int) -> ShaderMaterial:
	var m := _smat("glyph", GLYPH_SHADER)
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("ink_col", inkc)
	m.set_shader_parameter("mode", mode)
	return m


static func trail_mat(head: Color, tailc: Color) -> ShaderMaterial:
	var m := _smat("trail", TRAIL_SHADER)
	m.set_shader_parameter("head", head)
	m.set_shader_parameter("tail_col", tailc)
	return m


## Malzemenin (ve geçişlerinin) bir parametresi
static func setp(m: Material, p: String, v: Variant) -> void:
	var q := m
	while q != null:
		if q is ShaderMaterial:
			(q as ShaderMaterial).set_shader_parameter(p, v)
		q = q.next_pass


static func tw_param(n: Node, m: Material, p: String, a: float, b: float, dur: float, delay := 0.0) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): setp(m, p, v), a, b, maxf(dur, 0.01))


## delay sonra dur sürede söner, sonra silinir (mats: Material ya da Material dizisi)
static func fade_out(n: Node, mats: Variant, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var list: Array = mats if mats is Array else [mats]
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		for m in list:
			setp(m, "fade", v), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


# ================================================================== düğüm / geometri yapı taşları
static func put(pj: PathJutsu, n: Node3D, pos: Vector3, parent: Node = null) -> Node3D:
	(parent if parent else pj.get_tree().current_scene).add_child(n)
	n.global_position = pos
	return n


static func mi(mesh: Mesh, m: Material) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.mesh = mesh
	x.material_override = m
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x


static func _cam_pos(pj: PathJutsu) -> Vector3:
	var vp = pj.get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	return cam.global_position if cam else Vector3(0, 1000, 0)


## Düğümün -Z'si p'ye bakar
static func _aim(n: Node3D, p: Vector3) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var d := p - n.global_position
	if d.length() < 0.01:
		return
	n.look_at(p, Vector3.UP if absf(d.normalized().y) < 0.97 else Vector3.RIGHT)


## Yassı profil → yere yatık (profil x → X, profil y → -Z, kalınlık → Y)
static func _flat_b() -> Basis:
	return Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))


## Yassı profil → dik (profil x → X, profil y → Y, kalınlık → Z)
static func _up_b() -> Basis:
	return Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))


static func slab(o: PackedVector2Array, thick: float, col: Color, b: Basis, off := Vector3.ZERO) -> ArrayMesh:
	var m := MB.new()
	m.add_slab(o, thick, col, Transform3D(b, off))
	return m.build()


static func _sphere() -> Mesh:
	if not _mc.has("mesh:sph"):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 20
		s.rings = 10
		_mc["mesh:sph"] = s
	return _mc["mesh:sph"]


static func _sphere_lo() -> Mesh:
	if not _mc.has("mesh:sphlo"):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 8
		s.rings = 4
		_mc["mesh:sphlo"] = s
	return _mc["mesh:sphlo"]


static func _quad(sz: float) -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(sz, sz)
	return q


static func _chunk() -> Mesh:
	if not _mc.has("mesh:chunk"):
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.26, 0.18, 0.22), Color.WHITE, Vector3(18, 30, 9))
		b.add("box", Vector3(0.05, 0.06, 0.02), Vector3(0.15, 0.13, 0.14), Color(0.85, 0.85, 0.85), Vector3(-20, 10, 35))
		_mc["mesh:chunk"] = b.build()
	return _mc["mesh:chunk"]


## Şerit: pts boyunca, UV.x boy, UV.y en. nrm sıfırsa en yönü teğet × yukarı (yere / kameraya açık).
## prof 0: iki ucu incelir, 1: kökü kalın uca incelir (fırça), 2: sabit
static func ribbon(pts: Array, w: float, nrm := Vector3.ZERO, prof := 0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var sd: Vector3 = tn.cross(nrm if nrm.length() > 0.01 else Vector3.UP)
		if sd.length() < 0.05:
			sd = tn.cross(Vector3.RIGHT)
		sd = sd.normalized()
		var u := float(i) / float(n - 1)
		var ww := w
		if prof == 0:
			ww = w * (0.25 + 0.75 * sin(PI * u))
		elif prof == 1:
			ww = w * (1.0 - 0.8 * u) * (0.55 + 0.45 * minf(1.0, u * 6.0))
		var fn: Vector3 = sd.cross(tn).normalized()
		for s in [-1.0, 1.0]:
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(u, (s + 1.0) * 0.5))
			st.set_normal(fn)
			st.add_vertex(p + sd * ww * s * 0.5)
	for i in n - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	return st.commit()


## Tüp: pts boyunca r0 → r1 incelen, UV.x boy, UV.y çevre
static func tube(pts: Array, r0: float, r1: float, sides := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var prev_side := Vector3.ZERO
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(tn.y) < 0.9 else Vector3.RIGHT
		var side: Vector3 = tn.cross(ref).normalized()
		if prev_side.length() > 0.5 and side.dot(prev_side) < 0.0:
			side = -side
		prev_side = side
		var up2: Vector3 = side.cross(tn).normalized()
		var u := float(i) / float(n - 1)
		var r := lerpf(r0, r1, u)
		for j in sides + 1:
			var a := TAU * j / sides
			var dv: Vector3 = side * cos(a) + up2 * sin(a)
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(u, float(j) / sides))
			st.set_normal(dv)
			st.add_vertex(p + dv * r)
	var row := sides + 1
	for i in n - 1:
		for j in sides:
			var a := i * row + j
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + row)
			st.add_index(a + 1)
			st.add_index(a + row + 1)
			st.add_index(a + row)
	return st.commit()


## Duvar halka (kuşak): yarıçap r, yükseklik h, UV.x çevre
static func band_ring(r: float, h: float, seg := 28) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg + 1:
		var a := TAU * i / seg
		var dv := Vector3(cos(a), 0, sin(a))
		for s in [-0.5, 0.5]:
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(float(i) / seg, s + 0.5))
			st.set_normal(dv)
			st.add_vertex(dv * r + Vector3.UP * h * s)
	for i in seg:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	return st.commit()


## Düzensiz leke profili
static func blob(r: float, n := 18, rough := 0.25) -> PackedVector2Array:
	var o := PackedVector2Array()
	var ph := randf() * 10.0
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + rough * (sin(a * 3.0 + ph) * 0.5 + sin(a * 7.0 + ph * 2.0) * 0.3 + randf_range(-0.3, 0.3))
		o.append(Vector2(cos(a), sin(a)) * r * k)
	return o


static func star(points: int, r_out: float, r_in: float, rot := 0.0) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in points * 2:
		var a := rot + TAU * i / (points * 2.0)
		o.append(Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return o


## Sivri yaprak (sıçrama dili): kökü 0'da, ucu +y'de
static func petal(L: float, w: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in 9:
		var u := float(i) / 8.0
		o.append(Vector2(w * sin(PI * u) * (1.0 - u * 0.6), u * L))
	for i in range(7, 0, -1):
		var u := float(i) / 8.0
		o.append(Vector2(-w * sin(PI * u) * (1.0 - u * 0.6), u * L))
	return o


## Yere yatık leke (mürekkep / yağ / asit / krater). m verilmezse cel; döner: düğüm (meta "m" = malzeme)
static func ground_blot(pj: PathJutsu, at: Vector3, r: float, col: Color, life: float, rough := 0.3, m: Material = null, grow_t := 0.2, lift := 0.04) -> MeshInstance3D:
	var mat: Material = null
	if m is ShaderMaterial:
		var dm := (m as ShaderMaterial).duplicate() as ShaderMaterial
		dm.next_pass = null
		mat = dm
	elif m:
		mat = m
	else:
		mat = cel(col, 0.0, INK, true, 0.0, 0.5, 2.0)
	var x := mi(slab(blob(r, 20, rough), 0.02, Color.WHITE, _flat_b()), mat)
	put(pj, x, pj.gp(at) + Vector3.UP * lift)
	x.rotation.y = randf() * TAU
	x.scale = Vector3(0.2, 1.0, 0.2)
	x.create_tween().tween_property(x, "scale", Vector3.ONE, grow_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	x.set_meta("m", mat)
	fade_out(x, mat, maxf(0.0, life - 0.8), 0.8)
	return x


## Kameraya dönük yıldız parlaması (kısa)
static func flash_star(pj: PathJutsu, at: Vector3, col: Color, r: float, pts := 8, dur := 0.25) -> void:
	var m := cel(col, 0.02, INK, true, 0.0, 1.0, 3.0)
	var x := mi(slab(star(pts, r, r * 0.38, randf() * TAU), 0.02, Color.WHITE, _up_b()), m)
	put(pj, x, at)
	_aim(x, _cam_pos(pj))
	x.rotate_object_local(Vector3.UP, PI)
	x.scale = Vector3.ONE * 0.2
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3.ONE, dur * 0.4).set_ease(Tween.EASE_OUT)
	fade_out(x, m, dur * 0.4, dur * 0.6)


## Parça yağmuru (kendi CPU parçacık ayarı). o: r, dir, spread, vmin, vmax, g, damp, smin, smax, spin, expl, align, hold, tang, end_scale
static func burst(pj: PathJutsu, pos: Vector3, mesh: Mesh, m: Material, n: int, life: float, o := {}) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, n)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = float(o.get("expl", 0.95))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.3))
	var dv: Vector3 = o.get("dir", Vector3.UP)
	p.direction = dv.normalized() if dv.length() > 0.001 else Vector3.UP
	p.spread = float(o.get("spread", 180.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("g", Vector3(0, -9, 0))
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.tangential_accel_min = float(o.get("tang", 0.0))
	p.tangential_accel_max = float(o.get("tang", 0.0))
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
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(1.0, float(o.get("end_scale", 0.6))))
	p.scale_amount_curve = cv
	put(pj, p, pos)
	p.emitting = true
	pj.free_after(life + 0.6, p)
	return p


## Bedene geçici kaplama (material_overlay): var olan kaplamayı saklar, süre sonunda geri koyar
static func body_overlay(pj: PathJutsu, c: Node3D, m: Material, dur: float) -> void:
	var model = c.get("model")
	if model == null or not is_instance_valid(model):
		return
	var list: Array = []
	var prev: Array = []
	for g in (model as Node).find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh == null:
			continue
		list.append(gi)
		prev.append(gi.material_overlay)
		gi.material_overlay = m
	pj.after(dur, func():
		for i in list.size():
			var gi = list[i]
			if is_instance_valid(gi) and gi.material_overlay == m:
				gi.material_overlay = prev[i])


static func _flat_dir(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD


# ================================================================== CHŌJŪ GIGA — parşömene çizilen mürekkep canavarları
## Kâğıt parşömen yerde açılır, fırça darbeleri kâğıtta kıvrılır, mürekkep kâğıttan sıçrayıp canavarın yerine iner
static func choju_giga(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var fd := _flat_dir(c.face_dir())
	var side := fd.cross(Vector3.UP).normalized()
	var base: Vector3 = pj.gp(c.global_position + fd * 1.5) + Vector3.UP * 0.05
	_ink_scroll(pj, base, side, fd, 2.4, 1.3)
	var spots: Array = []
	for i in 3:
		spots.append(pj.gp(c.global_position + side * ((i - 1.0) * 2.4) + fd * 2.5))
	for i in 3:
		var s0: Vector3 = base + side * ((i - 1.0) * 0.72) + Vector3.UP * 0.035
		_ink_sketch(pj, s0, side, fd, 0.08 + i * 0.05)
		var to: Vector3 = spots[i]
		pj.after(0.24 + i * 0.07, func(): _ink_leap(pj, s0, to))
	ClanConstruct.spawn(c, "ink", 3, Jutsu._jd("choju_giga"))
	Sfx.play("poof", c.global_position, 0.8)


## Parşömen: sol makara yerinde, kâğıt sağa açılır, sağ makara yuvarlanır
static func _ink_scroll(pj: PathJutsu, base: Vector3, side: Vector3, fd: Vector3, L: float, life: float) -> void:
	var root := Node3D.new()
	put(pj, root, base - side * L * 0.5)
	root.global_basis = Basis(side, Vector3.UP, -fd)
	var pm := cel(Color.WHITE, 0.012, PAPER_EDGE, false, 0.0, 0.5, 2.0)
	var pb := MB.new()
	pb.add("box", Vector3(L * 0.5, 0.0, 0.0), Vector3(L, 0.02, 0.8), PAPER)
	pb.add("box", Vector3(L * 0.5, 0.011, 0.36), Vector3(L * 0.98, 0.004, 0.03), PAPER_EDGE)
	pb.add("box", Vector3(L * 0.5, 0.011, -0.36), Vector3(L * 0.98, 0.004, 0.03), PAPER_EDGE)
	var paper := mi(pb.build(), pm)
	root.add_child(paper)
	paper.scale = Vector3(0.03, 1, 1)
	var rm := cel(Color.WHITE, 0.012, INK, false, 0.0, 0.5, 2.0)
	var rb := MB.new()
	rb.add("cyl", Vector3.ZERO, Vector3(0.1, 0.96, 0.1), WOOD, Vector3(90, 0, 0), 10)
	rb.add("cyl", Vector3(0, 0, 0.5), Vector3(0.06, 0.06, 0.06), Color(0.2, 0.12, 0.06), Vector3(90, 0, 0), 8)
	rb.add("cyl", Vector3(0, 0, -0.5), Vector3(0.06, 0.06, 0.06), Color(0.2, 0.12, 0.06), Vector3(90, 0, 0), 8)
	var rmesh := rb.build()
	var r_left := mi(rmesh, rm)
	root.add_child(r_left)
	r_left.position = Vector3(0, 0.05, 0)
	var r_right := mi(rmesh, rm)
	root.add_child(r_right)
	r_right.position = Vector3(0.05, 0.05, 0)
	var tw := root.create_tween()
	tw.tween_property(paper, "scale:x", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r_right, "position:x", L, 0.18).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r_right, "rotation:z", -L / 0.05, 0.18)
	fade_out(root, [pm, rm], life, 0.3)


## Kâğıtta kıvrılan fırça darbesi (tomoe kıvrımı + hızlı çekiş)
static func _ink_sketch(pj: PathJutsu, at: Vector3, side: Vector3, fd: Vector3, delay: float) -> void:
	var pts: Array = []
	for k in 16:
		var ang := k * 0.5
		var r := 0.05 + k * 0.016
		pts.append(side * cos(ang) * r + fd * sin(ang) * r * 0.7)
	var m := ink_mat()
	var x := mi(ribbon(pts, 0.07, Vector3.UP, 1), m)
	put(pj, x, at)
	tw_param(x, m, "grow", 0.0, 1.0, 0.16, delay)
	var pts2: Array = []
	for k in 8:
		var u := k / 7.0
		pts2.append(side * (u * 0.5 - 0.25) + fd * (0.22 + sin(u * 3.0) * 0.06))
	var m2 := ink_mat()
	var x2 := mi(ribbon(pts2, 0.05, Vector3.UP, 1), m2)
	put(pj, x2, at)
	tw_param(x2, m2, "grow", 0.0, 1.0, 0.1, delay + 0.12)
	fade_out(x, m, 1.0, 0.3)
	fade_out(x2, m2, 1.0, 0.3)


## Mürekkep kâğıttan sıçrar: yay çizen fırça şeridi büyür, kuyruğu canavarın içine çekilir, yere sıçrar
static func _ink_leap(pj: PathJutsu, from: Vector3, to: Vector3) -> void:
	var pts: Array = []
	var side := (to - from).cross(Vector3.UP).normalized()
	for k in 18:
		var u := k / 17.0
		pts.append(from.lerp(to, u) + Vector3.UP * (sin(PI * u) * 1.5 + u * 0.4) + side * sin(TAU * u) * 0.3 - from)
	var m := ink_mat()
	var x := mi(ribbon(pts, 0.26, Vector3.ZERO, 1), m)
	put(pj, x, from)
	tw_param(x, m, "grow", 0.0, 1.0, 0.22)
	tw_param(x, m, "tail", 0.0, 1.0, 0.25, 0.32)
	pj.free_after(0.7, x)
	pj.after(0.2, func():
		var dm := cel(SUMI, 0.0, INK, false, 0.6, 0.5, 2.0)
		burst(pj, to + Vector3.UP * 0.3, _sphere_lo(), dm, 14, 0.7, {"r": 0.3, "dir": Vector3.UP, "spread": 70.0, "vmin": 2.0, "vmax": 4.5, "g": Vector3(0, -14, 0), "smin": 0.08, "smax": 0.18, "hold": 0.8})
		for k in 3:
			var off := Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7)) * (0.0 if k == 0 else 1.0)
			ground_blot(pj, to + off, (0.7 if k == 0 else randf_range(0.18, 0.35)), SUMI, 2.6, 0.35))


# ================================================================== CHŌSHIN GIGA — havada çizilen dev tanrı
## Dev kaslı tanrı figürü dik bir düzlemde fırça darbeleriyle çizilir, mürekkep damlayarak gerçek yapıta döner;
## çevreye mürekkep dalgası lekeleri yayılır
static func choshin_giga(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var fd := _flat_dir(c.face_dir())
	var side := fd.cross(Vector3.UP).normalized()
	var list = ClanConstruct.spawn(c, "ink", 1, Jutsu._jd("choshin_giga"))
	for u in list:
		u.vis.scale = Vector3.ONE * 2.4
		u.dmg *= 2.8
		u.max_hp *= 3.0
		u.hp = u.max_hp
		u.radius *= 2.0
	var at: Vector3 = pj.gp(c.global_position + fd * 2.5) + fd * 0.35
	_god_sketch(pj, at, side, fd)
	_ink_tide(pj, c.global_position)
	Sfx.play("roar", c.global_position, 0.8)


static func _god_sketch(pj: PathJutsu, at: Vector3, side: Vector3, fd: Vector3) -> void:
	var strokes: Array = []
	# baş
	var head: Array = []
	for k in 15:
		var a := PI * 0.5 + TAU * k / 14.0
		head.append(Vector2(cos(a) * 0.55, 5.0 + sin(a) * 0.62))
	strokes.append(head)
	# omuz + gövde dış hatları (sol / sağ)
	for sx in [-1.0, 1.0]:
		strokes.append([Vector2(sx * 0.45, 4.45), Vector2(sx * 1.6, 4.35), Vector2(sx * 2.45, 3.9), Vector2(sx * 2.6, 3.1),
			Vector2(sx * 2.05, 2.3), Vector2(sx * 1.35, 1.7), Vector2(sx * 1.15, 0.9), Vector2(sx * 1.0, 0.1)])
	# yukarı kalkmış sol kol + yumruk
	strokes.append([Vector2(-2.3, 4.1), Vector2(-3.0, 4.7), Vector2(-3.3, 5.4), Vector2(-3.25, 5.9)])
	var fist_l: Array = []
	for k in 11:
		var a := TAU * k / 10.0
		fist_l.append(Vector2(-3.25 + cos(a) * 0.38, 6.2 + sin(a) * 0.32))
	strokes.append(fist_l)
	# öne yumruk atan sağ kol
	strokes.append([Vector2(2.3, 4.0), Vector2(3.0, 3.6), Vector2(3.6, 3.75), Vector2(4.05, 3.9)])
	var fist_r: Array = []
	for k in 11:
		var a := TAU * k / 10.0
		fist_r.append(Vector2(4.35 + cos(a) * 0.36, 3.95 + sin(a) * 0.34))
	strokes.append(fist_r)
	# göğüs kası kavisleri + karın çizgisi
	for sx in [-1.0, 1.0]:
		strokes.append([Vector2(sx * 0.1, 3.9), Vector2(sx * 0.8, 3.75), Vector2(sx * 1.4, 3.3), Vector2(sx * 1.2, 2.95), Vector2(sx * 0.2, 3.0)])
	strokes.append([Vector2(0, 2.8), Vector2(0.05, 2.2), Vector2(-0.03, 1.5), Vector2(0, 0.9)])
	# göğüste girdap (Sai mürekkep imzası)
	var sw: Array = []
	for k in 14:
		var a := k * 0.55
		var r := 0.06 + k * 0.035
		sw.append(Vector2(cos(a) * r, 2.2 + sin(a) * r))
	strokes.append(sw)
	var i := 0
	for s in strokes:
		var pts: Array = []
		for p2 in s:
			var v: Vector2 = p2
			pts.append(side * v.x + Vector3.UP * v.y)
		var m := ink_mat(-1.0, 3.0, 7.0)
		var x := mi(ribbon(pts, 0.3 if i > 0 else 0.26, fd, 1), m)
		put(pj, x, at)
		tw_param(x, m, "grow", 0.0, 1.0, 0.16, 0.04 + i * 0.045)
		tw_param(x, m, "tail", 0.0, 1.0, 0.45, 1.0 + randf() * 0.25)
		pj.free_after(1.8, x)
		i += 1
	# çizim çözülürken mürekkep damlaları süzülür
	pj.after(1.0, func():
		var dm := cel(SUMI, 0.0, INK, false, 0.6, 1.0, 3.0)
		for k in 4:
			burst(pj, at + side * randf_range(-2.4, 2.4) + Vector3.UP * randf_range(2.0, 5.0), _sphere_lo(), dm, 10, 0.9,
				{"r": 0.6, "dir": Vector3.DOWN, "spread": 25.0, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -12, 0), "smin": 0.1, "smax": 0.22, "expl": 0.4}))


## Mürekkep dalgası: kullanıcıdan yayılan, yere yapışan ve sönen sumi lekeleri (6 m ile sınırlı)
static func _ink_tide(pj: PathJutsu, center: Vector3) -> void:
	for k in 14:
		var a := TAU * k / 14.0 + randf() * 0.2
		var dv := Vector3(cos(a), 0, sin(a))
		var x := ground_blot(pj, center + dv * 0.6, randf_range(0.4, 0.7), SUMI, 1.6, 0.4, null, 0.1)
		var tw := x.create_tween()
		tw.tween_property(x, "global_position", pj.gp(center + dv * randf_range(4.5, 6.0)) + Vector3.UP * 0.04, 0.45).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(x, "scale", Vector3(1.7, 1.0, 1.0), 0.45)
	var dm := cel(SUMI, 0.0, INK, false, 0.6, 0.5, 2.0)
	burst(pj, center + Vector3.UP * 0.2, _sphere_lo(), dm, 26, 0.7, {"r": 0.8, "dir": Vector3.UP, "spread": 80.0, "vmin": 3.0, "vmax": 6.0, "g": Vector3(0, -16, 0), "smin": 0.1, "smax": 0.22})


# ================================================================== CHŌ MINI BIJŪDAMA — parmak ucunda minik kara top
static func cho_mini_bijudama(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt := pj.tg(c, t, 30.0)
	var from := pj.hand_pos(c, true)
	_bj_gather(pj, from)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		pj.shot(c, from, pj.aim_at(c, tt, from), 42.0, _bj_ball(0.2, true), pj.inf(c, "cho_mini_bijudama", 2.2, {"knock": 18.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.08}), null, false, 1.2, func(p, _h):
			_bj_blast(pj, p)))
	Sfx.play("roar", from, 1.4)


## Kara top: zifiri öz + mor-beyaz kenar + yüze dönük dönen hale; tail: arkada mor-kara iz
static func _bj_ball(r: float, tail: bool) -> Node3D:
	var root := Node3D.new()
	var core := mi(_sphere(), void_mat(BIJU_RIM, BIJU_HOT, 0.3))
	core.scale = Vector3.ONE * r * 2.0
	root.add_child(core)
	var h := mi(_quad(r * 6.0), halo_mat(Color(0.6, 0.35, 0.95, 0.9), BIJU_HOT, 0.32, 5.0, 1.4, 0.3, 1.2))
	root.add_child(h)
	if tail:
		var tm := trail_mat(Color(0.75, 0.5, 1.0, 0.9), Color(0.2, 0.05, 0.3, 1.0))
		for k in 2:
			var q := mi(ribbon([Vector3.ZERO, Vector3(0, 0, 0.6), Vector3(0, 0, 1.2), Vector3(0, 0, 1.8)], r * 1.6, Vector3.UP if k == 0 else Vector3.RIGHT, 2), tm)
			root.add_child(q)
	return root


## Toplanma: kara ve beyaz chakra zerreleri sarmalla parmak ucuna akar, top orada büyür
static func _bj_gather(pj: PathJutsu, from: Vector3) -> void:
	var mb := cel(Color(0.04, 0.03, 0.06), 0.012, Color(0.75, 0.55, 1.0), false, 0.0, 0.4, 1.4)
	var mw := cel(Color(0.98, 0.96, 1.0), 0.012, Color(0.25, 0.1, 0.35), false, 0.0, 0.4, 1.4)
	for k in 14:
		var x := mi(_sphere_lo(), mb if k % 2 == 0 else mw)
		var off := Vector3(randf_range(-1, 1), randf_range(-0.6, 1.0), randf_range(-1, 1)).normalized() * randf_range(0.9, 1.5)
		put(pj, x, from + off)
		x.scale = Vector3.ONE * randf_range(0.07, 0.13)
		var spin := randf_range(2.0, 4.0) * (1.0 if k % 2 == 0 else -1.0)
		var tw := x.create_tween()
		tw.tween_method(func(u: float):
			if is_instance_valid(x):
				x.global_position = from + off.rotated(Vector3.UP, u * spin) * (1.0 - u), 0.0, 1.0, 0.3 + randf() * 0.04).set_ease(Tween.EASE_IN)
		tw.tween_callback(x.queue_free)
	var ball := _bj_ball(0.2, false)
	put(pj, ball, from)
	ball.scale = Vector3.ONE * 0.05
	ball.create_tween().tween_property(ball, "scale", Vector3.ONE, 0.33).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.free_after(0.35, ball)


## Çarpma: yıldız parlaması → gürültüyle çözülen mor-kara kütle → kara parçalar → yanık zemin ve yarıklar
static func _bj_blast(pj: PathJutsu, p: Vector3) -> void:
	flash_star(pj, p, BIJU_HOT, 1.4, 8, 0.3)
	var dm := _smat("dissolve", DISSOLVE_SHADER)
	dm.set_shader_parameter("seed", randf() * 30.0)
	var dome := mi(_sphere(), dm)
	put(pj, dome, p)
	dome.scale = Vector3.ONE * 0.5
	var tw := dome.create_tween()
	tw.tween_property(dome, "scale", Vector3.ONE * 4.4, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): dm.set_shader_parameter("cut", v), 0.0, 1.0, 0.55)
	tw.tween_callback(dome.queue_free)
	var cm := cel(Color(0.12, 0.06, 0.16), 0.01, BIJU_RIM, false, 0.0, 0.5, 2.0)
	burst(pj, p, _chunk(), cm, 16, 0.9, {"r": 0.4, "spread": 180.0, "vmin": 5.0, "vmax": 10.0, "g": Vector3(0, -14, 0), "smin": 0.6, "smax": 1.3, "spin": 400.0})
	var g: Vector3 = pj.gp(p)
	if p.y - g.y < 2.6:
		ground_blot(pj, g, 1.7, Color(0.1, 0.05, 0.13, 0.9), 3.5, 0.35)
		var km := cel(Color(0.05, 0.02, 0.07), 0.0, INK, true, 0.0, 0.5, 2.0)
		for k in 7:
			var a := TAU * k / 7.0 + randf() * 0.4
			var pts: Array = []
			var q := Vector3.ZERO
			for j in 5:
				pts.append(q + Vector3.UP * 0.05)
				q += Vector3(cos(a), 0, sin(a)).rotated(Vector3.UP, randf_range(-0.5, 0.5)) * randf_range(0.4, 0.6)
			var x := mi(ribbon(pts, 0.12, Vector3.UP, 1), km)
			put(pj, x, g)
			fade_out(x, km, 2.6, 0.8)


# ================================================================== CANAVAR TELEPATİSİ — zihin dünyasına bağlanma
## Ayak altında turuncu zihin dünyası dalgaları + dokuz nokta, çevrede dışa kıvrılan dokuz kuyruk alevi, başta yayın halesi
static func tailed_beast_telepathy(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("tailed_beast_telepathy", {})
	if d.is_empty():
		return
	var tier := int(d.get("tier", 2))
	var dur := 8.0 + tier * 2.0
	Buffs.add(String(d.get("id", "buff")), dur, {"speed": 1.1})
	var g: Vector3 = pj.gp(c.global_position)
	var gm := glyph_mat(TELE, TELE_DARK, 3)
	var disk := mi(_plane(8.4), gm)
	put(pj, disk, g + Vector3.UP * 0.04)
	tw_param(disk, gm, "fade", 0.0, 1.0, 0.3)
	fade_out(disk, gm, 2.0, 0.7)
	for k in 9:
		var a := TAU * k / 9.0
		var dv := Vector3(cos(a), 0, sin(a))
		var pp := dv.cross(Vector3.UP)
		var pts: Array = []
		for j in 10:
			var u := j / 9.0
			pts.append(dv * (1.2 + u * u * 1.5) + Vector3.UP * (u * 2.6) + pp * sin(u * 3.0) * 0.25)
		var holder := Node3D.new()
		put(pj, holder, g)
		var om := cel(TELE_DARK, 0.0, INK, true, 0.0, 0.6, 2.2, true)
		om.render_priority = -1
		var outline_r := mi(ribbon(pts, 0.5, dv, 1), om)
		holder.add_child(outline_r)
		var fm := cel(TELE, 0.0, INK, true, 0.5, 0.6, 2.2)
		fm.render_priority = 1
		var flame := mi(ribbon(pts, 0.36, dv, 1), fm)
		holder.add_child(flame)
		holder.scale = Vector3(1, 0.02, 1)
		var tw := holder.create_tween()
		tw.tween_interval(k * 0.04)
		tw.tween_property(holder, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "rotation:y", randf_range(-0.12, 0.12), 0.8).set_trans(Tween.TRANS_SINE)
		fade_out(holder, [om, fm], 1.6, 0.6)
	var hm := halo_mat(TELE, Color(1.0, 0.92, 0.7), 0.25, 9.0, -0.8, 0.6, 1.8)
	var h := mi(_quad(1.6), hm)
	put(pj, h, c.global_position + Vector3.UP * 1.9)
	fade_out(h, hm, 1.2, 0.5)
	if c is Player:
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], TELE.lightened(0.3))
	Sfx.play("seal", c.global_position, 0.8)


static func _plane(sz: float) -> Mesh:
	var p := PlaneMesh.new()
	p.size = Vector2(sz, sz)
	return p


# ================================================================== KANASHIBARI — geçici felç
## Kullanıcının gözünde parıltı; hedefin çevresinde dikey baskı çizgileri içe kapanır ve titrer, üç ince kuşak sıkar,
## yerde içe akan koyu felç çizgileri
static func kanashibari_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt := pj.tg(c, t, 16.0)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.2)
	if tt == null:
		return
	var col := PARA
	var fd := _flat_dir(c.face_dir())
	var side := fd.cross(Vector3.UP).normalized()
	for sx in [-1.0, 1.0]:
		var sm := cel(Color(0.95, 0.85, 1.0), 0.008, Color(0.3, 0.1, 0.4), true, 0.0, 0.3, 1.0)
		var e := mi(slab(star(4, 0.12, 0.025), 0.01, Color.WHITE, _up_b()), sm)
		put(pj, e, c.global_position + Vector3.UP * 1.66 + fd * 0.22 + side * sx * 0.07)
		_aim(e, _cam_pos(pj))
		e.scale = Vector3.ONE * 0.1
		var et := e.create_tween()
		et.tween_property(e, "scale", Vector3.ONE, 0.1)
		et.tween_property(e, "scale", Vector3.ONE * 0.05, 0.2)
		et.tween_callback(e.queue_free)
	# baskı çizgileri + kuşaklar (hedefe bağlı, hedef boyunda)
	var holder := Node3D.new()
	tt.add_child(holder)
	ClanJutsu.fit_body(tt, holder)
	var inner := Node3D.new()
	holder.add_child(inner)
	var lm := cel(Color(0.08, 0.04, 0.1), 0.0, INK, true, 0.0, 0.5, 1.8)
	var lb := MB.new()
	for k in 26:
		var a := TAU * k / 26.0 + randf() * 0.1
		var hh := randf_range(1.2, 2.4)
		lb.add("box", Vector3(cos(a) * 1.0, hh * 0.5 + randf() * 0.3, sin(a) * 1.0), Vector3(0.025, hh, 0.025), Color.WHITE, Vector3(0, -rad_to_deg(a), 0), 4)
	var lines := mi(lb.build(), lm)
	inner.add_child(lines)
	var bm := cel(Color(col.r, col.g, col.b, 0.75), 0.0, INK, true, 0.3, 0.5, 1.8)
	for hgt in [0.55, 1.1, 1.65]:
		var band := mi(band_ring(0.95, 0.07, 28), bm)
		inner.add_child(band)
		band.position = Vector3(0, hgt, 0)
	inner.scale = Vector3(2.6, 1, 2.6)
	var tw := inner.create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(inner, "scale", Vector3(0.62, 1, 0.62), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.every(2.3, 0.05, func(_i, _k):
		if is_instance_valid(inner):
			inner.position = Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03)))
	fade_out(holder, [lm, bm], 2.2, 0.3)
	var gm := glyph_mat(Color(0.1, 0.05, 0.12, 0.85), INK, 4)
	var disk := mi(_plane(3.6), gm)
	put(pj, disk, pj.gp(tt.global_position) + Vector3.UP * 0.04)
	fade_out(disk, gm, 2.1, 0.4)
	pj.st(tt, "stun", 2.5)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.3, "Felç!", col)
	Sfx.play("genjutsu", tt.global_position, 1.2)


# ================================================================== GAMAYUDAN — kurbağa yağı mermisi
## Ağızda yağ şişer, iri benekli amber yağ topakları ağır yay çizerek fışkırır, yere şap şap düşer,
## uçta parlak yağ gölü (kaynayıp patlayan kabarcıklar) — gölde yavaşlatma
static func gamayudan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var d := pj.fwd(c, t)
	var mouth := pj._mouth_pos(c)
	var om := oil_mat(OIL_BASE, OIL_SPOT, OIL_DARK, 3.0, 0.0, 0.012)
	var sw := mi(_sphere(), om)
	put(pj, sw, mouth + d * 0.15)
	sw.scale = Vector3.ONE * 0.05
	var st := sw.create_tween()
	st.tween_property(sw, "scale", Vector3.ONE * 0.42, 0.12).set_ease(Tween.EASE_OUT)
	st.tween_property(sw, "scale", Vector3.ONE * 0.05, 0.2)
	st.tween_callback(sw.queue_free)
	var dir := (d - Vector3.UP * 0.08).normalized()
	_oil_globs(pj, mouth, dir, om)
	var end := mouth + dir * 12.0
	pj.after(maxf(0.25, 0.45 * 0.65), func():
		_oil_splash(pj, end, om)
		_oil_pool(pj, c, end, 4.5, 8.0))
	Combat.hit_zone(c, c.global_position, d, 12.0, 18.0, 3.0, pj.inf(c, "gamayudan", 0.8, {"knock": 9.0, "kind": "heavy"}))
	Sfx.play("water", c.global_position, 0.7)


static func _oil_globs(pj: PathJutsu, mouth: Vector3, dir: Vector3, om: Material) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	for k in 16:
		pj.after(k * 0.028, func():
			var L := randf_range(4.0, 12.0) if k % 4 != 0 else 12.0
			var tgt: Vector3 = pj.gp(mouth + dir * L + side * randf_range(-0.9, 0.9)) + Vector3.UP * 0.1
			var arc := randf_range(0.5, 1.2)
			var x := mi(_sphere(), om)
			put(pj, x, mouth)
			var s := randf_range(0.28, 0.55) * (1.3 if k % 4 == 0 else 1.0)
			x.scale = Vector3(s, s, s * 1.6)
			var dur := 0.18 + L * 0.016
			var last := [mouth]
			var tw := x.create_tween()
			tw.tween_method(func(u: float):
				if not is_instance_valid(x):
					return
				var p: Vector3 = mouth.lerp(tgt, u) + Vector3.UP * sin(PI * u) * arc
				if p.distance_to(last[0]) > 0.02:
					_aim(x, p + (p - last[0]))
				last[0] = p
				x.global_position = p, 0.0, 1.0, dur)
			tw.tween_callback(func():
				if is_instance_valid(x):
					x.queue_free()
				ground_blot(pj, tgt, s * randf_range(0.7, 1.2), Color.WHITE, randf_range(2.5, 4.0), 0.35, om, 0.12)))


static func _oil_splash(pj: PathJutsu, end: Vector3, om: Material) -> void:
	var g: Vector3 = pj.gp(end)
	burst(pj, g + Vector3.UP * 0.3, _sphere_lo(), om, 18, 0.8, {"r": 0.6, "dir": Vector3.UP, "spread": 60.0, "vmin": 2.5, "vmax": 5.5, "g": Vector3(0, -16, 0), "smin": 0.12, "smax": 0.3, "hold": 0.85})
	for k in 7:
		var a := TAU * k / 7.0 + randf() * 0.3
		var x := mi(slab(petal(randf_range(0.6, 1.1), 0.16), 0.03, Color.WHITE, _up_b()), om)
		put(pj, x, g + Vector3.UP * 0.05)
		x.rotation = Vector3(-randf_range(0.5, 1.1), a, 0)
		x.scale = Vector3.ONE * 0.2
		var tw := x.create_tween()
		tw.tween_property(x, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(x, "scale", Vector3(1.0, 0.05, 1.0), 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(x.queue_free)


## Yağ gölü: düzensiz parlak benekli amber lekeler yavaşça yayılır, üstünde kabarcıklar şişip patlar; gölde düşman yavaşlar
static func _oil_pool(pj: PathJutsu, c: Node3D, at: Vector3, r: float, dur: float) -> void:
	at = pj.gp(at)
	var pm := oil_mat(OIL_BASE, OIL_SPOT, OIL_DARK, 1.6, 0.15, 0.0)
	var blots: Array = []
	for k in 5:
		var a := randf() * TAU
		var p := at + Vector3(cos(a), 0, sin(a)) * (0.0 if k == 0 else randf_range(0.4, 0.75) * r)
		var sz := r * (1.6 if k == 0 else randf_range(0.7, 1.0))
		var x := mi(slab(blob(sz * 0.5, 22, 0.3), 0.03, Color.WHITE, _flat_b()), pm)
		put(pj, x, pj.gp(p) + Vector3.UP * (0.05 + k * 0.006))
		x.rotation.y = randf() * TAU
		x.scale = Vector3.ONE * 0.3
		x.create_tween().tween_property(x, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		blots.append(x)
	var bm := oil_mat(OIL_SPOT, Color(1.0, 0.95, 0.75), OIL_DARK, 4.0, 0.0, 0.006)
	pj.every(dur, 0.15, func(i, _k):
		var b := at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * r * 0.7
		var bub := mi(_sphere(), bm)
		put(pj, bub, pj.gp(b) + Vector3.UP * 0.06)
		bub.scale = Vector3.ONE * 0.02
		var s := randf_range(0.14, 0.3)
		var tw := bub.create_tween()
		tw.tween_property(bub, "scale", Vector3(s, s * 0.8, s), randf_range(0.2, 0.4)).set_ease(Tween.EASE_OUT)
		tw.tween_property(bub, "scale", Vector3(s * 1.3, s * 0.3, s * 1.3), 0.05)
		tw.tween_callback(bub.queue_free)
		if i % 3 == 0:
			for e in pj.enemies_near(c, at, r):
				if is_instance_valid(e) and not (e.has_method("is_dead") and e.is_dead()):
					pj.st(e, "slow", 1.0), func():
		for x in blots:
			if is_instance_valid(x):
				fade_out(x, pm, 0.0, 1.0))


# ================================================================== TŌTON — saydam kaçış
## Ayaktan başa kırılma bandı süpürür, beden saydamlaşıp kaybolur; gizliyken yalnız ince ışık kırılması kalır,
## dönüşte bant baştan ayağa geri iner
static func toton_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("toton_jutsu", {})
	if d.is_empty():
		return
	var tier := int(d.get("tier", 2))
	var dur := 8.0 + tier * 2.0
	Buffs.add("stealth_" + String(d.get("id", "")), dur, {"stealth": 1.0})
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(c.global_position) < 30 and f.has_method("lose_target"):
			f.lose_target(dur * 0.5)
	if c.get("model"):
		var hide_t := minf(dur, 4.0)
		var rm := _smat("refract", REFRACT_SHADER)
		rm.set_shader_parameter("y0", c.global_position.y - 0.05)
		rm.set_shader_parameter("hgt", 1.9)
		rm.set_shader_parameter("sweep", 0.0)
		body_overlay(pj, c, rm, 0.32)
		tw_param(c, rm, "sweep", 0.0, 1.1, 0.3)
		pj.after(0.3, func():
			if is_instance_valid(c) and c.get("model"):
				c.model.visible = false)
		# gizliyken: bedeni izleyen hafif kırılma (ışık bükülmesi + ince kontur)
		var hm := _smat("refract", REFRACT_SHADER)
		hm.set_shader_parameter("y0", 1000.0)
		hm.set_shader_parameter("amt", 0.45)
		hm.set_shader_parameter("fade", 0.0)
		var cap := CapsuleMesh.new()
		cap.radius = 0.36
		cap.height = 1.8
		var haze := mi(cap, hm)
		c.add_child(haze)
		haze.position = Vector3(0, 0.9, 0)
		tw_param(haze, hm, "fade", 0.0, 0.7, 0.3, 0.25)
		tw_param(haze, hm, "fade", 0.7, 0.0, 0.3, hide_t - 0.35)
		pj.free_after(hide_t, haze)
		pj.after(hide_t, func():
			if is_instance_valid(c) and c.get("model"):
				c.model.visible = true
				var bm := _smat("refract", REFRACT_SHADER)
				bm.set_shader_parameter("y0", c.global_position.y - 0.05)
				bm.set_shader_parameter("hgt", 1.9)
				bm.set_shader_parameter("sweep", 1.1)
				body_overlay(pj, c, bm, 0.36)
				tw_param(c, bm, "sweep", 1.1, -0.1, 0.34))
	Sfx.play("poof", c.global_position)


# ================================================================== KAERU KAERU — kurbağaya çevirme
## Hedefin altında yeşil kurbağa sözleşme yazısı dönerek yazılır, yeşil chakra sarmalı bedeni sarar, beden ezilip
## yaylanarak kurbağaya döner (boğazı şişip iner); süre bitince kurbağa uzayıp yeşil damlalarla eski hâline döner
static func kaeru_kaeru_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt := pj.tg(c, t, 14.0)
	pj.busy(c, 0.6)
	pj.anim(c, "push", 1.2)
	if tt == null:
		return
	var col := Color(0.5, 0.85, 0.4)
	var gpos: Vector3 = pj.gp(tt.global_position)
	var gm := glyph_mat(Color(0.55, 0.95, 0.45), Color(0.1, 0.3, 0.1), 0)
	var disk := mi(_plane(maxf(1.6, 1.4 * 1.1) * 2.0), gm)
	put(pj, disk, gpos + Vector3.UP * 0.04)
	tw_param(disk, gm, "prog", 0.0, 1.0, 0.25)
	fade_out(disk, gm, 0.7, 0.4)
	Sfx.play("poof", gpos, 0.8)
	var sm := cel(Color(0.6, 1.0, 0.5, 0.9), 0.0, INK, true, 0.4, 0.5, 1.8)
	for k in 3:
		var pts: Array = []
		for j in 24:
			var u := j / 23.0
			var a := TAU * k / 3.0 + u * TAU * 1.4
			pts.append(Vector3(cos(a) * (0.85 - u * 0.25), u * 2.1, sin(a) * (0.85 - u * 0.25)))
		var x := mi(ribbon(pts, 0.14, Vector3.ZERO, 0), sm)
		put(pj, x, tt.global_position)
		tw_param(x, sm, "grow", 0.0, 1.0, 0.25)
		pj.free_after(0.45, x)
	pj.after(0.3, func():
		if not pj.live(tt):
			return
		_frog_pop(pj, tt.global_position + Vector3.UP, 1.0)
		var body = tt.get("model") if tt.get("model") else null
		var frog := _frog_mesh()
		tt.add_child(frog)
		ClanJutsu.fit_body(tt, frog)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		var inner := frog.get_child(0) as Node3D
		inner.scale = Vector3(1.5, 0.3, 1.5)
		var it := inner.create_tween()
		it.tween_property(inner, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if body:
			body.visible = false
		pj.st(tt, "stun", 4.0)
		Combat.popup_text(tt.global_position + Vector3.UP * 1.5, "Vrak!", col)
		pj.after(3.8, func():
			if is_instance_valid(inner):
				var rt := inner.create_tween()
				rt.tween_property(inner, "scale", Vector3(0.55, 1.7, 0.55), 0.18).set_ease(Tween.EASE_IN))
		pj.after(4.0, func():
			if is_instance_valid(frog):
				frog.queue_free()
			if is_instance_valid(body):
				body.visible = true
			if pj.live(tt):
				_frog_pop(pj, tt.global_position + Vector3.UP, 0.7)))
	Sfx.play("poof", tt.global_position, 1.0)


## Kurbağa modeli: kök (boy uyumu) → iç (ezilme/yaylanma) → gövde + boğaz kesesi (nefes alır)
static func _frog_mesh() -> Node3D:
	var root := Node3D.new()
	var inner := Node3D.new()
	root.add_child(inner)
	var b := MB.new()
	b.add("sphere", Vector3(0, 0.28, -0.02), Vector3(0.64, 0.46, 0.72), FROG, Vector3.ZERO, 14)
	b.add("sphere", Vector3(0, 0.2, 0.1), Vector3(0.5, 0.3, 0.52), FROG_BELLY, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.42, 0.2), Vector3(0.52, 0.3, 0.42), FROG, Vector3.ZERO, 12)
	for ex in [-1.0, 1.0]:
		b.add("sphere", Vector3(ex * 0.15, 0.6, 0.21), Vector3(0.19, 0.1, 0.17), FROG_DARK, Vector3.ZERO, 10)
		b.add("sphere", Vector3(ex * 0.15, 0.56, 0.24), Vector3(0.16, 0.16, 0.16), Color(0.98, 0.9, 0.3), Vector3.ZERO, 10)
		b.add("box", Vector3(ex * 0.15, 0.56, 0.318), Vector3(0.1, 0.032, 0.02), Color(0.04, 0.04, 0.04))
		b.add("cyl", Vector3(ex * 0.2, 0.12, 0.26), Vector3(0.07, 0.24, 0.07), FROG, Vector3(15, 0, ex * 10.0), 8)
		b.add("sphere", Vector3(ex * 0.23, 0.015, 0.31), Vector3(0.14, 0.035, 0.13), FROG_DARK, Vector3.ZERO, 8)
		b.add("sphere", Vector3(ex * 0.29, 0.13, -0.12), Vector3(0.23, 0.2, 0.38), FROG, Vector3.ZERO, 10)
		b.add("sphere", Vector3(ex * 0.34, 0.02, 0.06), Vector3(0.17, 0.04, 0.22), FROG_DARK, Vector3.ZERO, 8)
	b.add("box", Vector3(0, 0.37, 0.418), Vector3(0.34, 0.012, 0.02), Color(0.12, 0.2, 0.08))
	for k in 9:
		var a := randf() * TAU
		b.add("sphere", Vector3(cos(a) * 0.2, 0.47 + randf() * 0.04, -0.05 + sin(a) * 0.22), Vector3.ONE * randf_range(0.04, 0.07), FROG_DARK, Vector3.ZERO, 6)
	var m := cel(Color.WHITE, 0.012, Color(0.08, 0.16, 0.06), false, 0.25, 0.3, 1.0)
	inner.add_child(mi(b.build(), m))
	var throat := mi(_sphere(), cel(FROG_BELLY, 0.01, Color(0.3, 0.3, 0.1), false, 0.0, 0.3, 1.0))
	inner.add_child(throat)
	throat.position = Vector3(0, 0.27, 0.3)
	throat.scale = Vector3(0.26, 0.15, 0.18)
	var tw := Game.safe_loops(throat.create_tween())
	tw.tween_property(throat, "scale", Vector3(0.36, 0.22, 0.26), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(throat, "scale", Vector3(0.26, 0.15, 0.18), 0.45).set_trans(Tween.TRANS_SINE)
	return root


## Dönüşüm patlaması: duman yok — yeşil-beyaz parlama + saçılan yeşil damlalar + yerde yeşil halka damlaları
static func _frog_pop(pj: PathJutsu, at: Vector3, s: float) -> void:
	flash_star(pj, at, Color(0.85, 1.0, 0.75), 0.8 * s, 6, 0.22)
	var dm := cel(Color(0.55, 0.95, 0.45), 0.008, Color(0.1, 0.3, 0.1), false, 0.5, 0.4, 1.4)
	burst(pj, at, _sphere_lo(), dm, int(18 * s), 0.7, {"r": 0.4, "dir": Vector3.UP, "spread": 100.0, "vmin": 2.5, "vmax": 5.0, "g": Vector3(0, -12, 0), "smin": 0.07, "smax": 0.15})
	var lm := cel(Color(0.4, 0.75, 0.3), 0.008, Color(0.1, 0.25, 0.08), true, 0.0, 0.4, 1.4)
	var leaf := slab(petal(0.22, 0.09), 0.01, Color.WHITE, _up_b())
	burst(pj, at, leaf, lm, int(8 * s), 0.9, {"r": 0.3, "dir": Vector3.UP, "spread": 120.0, "vmin": 1.5, "vmax": 3.5, "g": Vector3(0, -5, 0), "smin": 0.8, "smax": 1.2, "spin": 300.0, "damp": 1.5})


# ================================================================== CHŌŌDAMA RASENGAN — dev Rasengan
## Elde dönen sarmal bantlı dev mavi küre içe çekilen rüzgâr çizgileriyle büyür; dalışta 3,2 m küre zemine
## öğütülerek genişler, rüzgâr yayları döner, kayalar teğet savrulur, krater ve yarıklar kalır
static func choodama_rasengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt := pj.tg(c, t, 8.0)
	pj.busy(c, 1.2)
	var ba := pj.bone_attach(c, "RightHand")
	if ba:
		var r := _rasen_ball(0.7, 0.4, 1.5)
		ba.add_child(r)
		r.position = Vector3(0, 0.2, 0.6)
		r.scale = Vector3.ONE * 0.15
		r.create_tween().tween_property(r, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		pj.free_after(1.0, ba)
	pj.after(0.5, func():
		if not pj.live(c):
			return
		var d := pj._jump_at(c, tt, 3.0, 14.0 if tt else 4.0)
		pj.after(0.2, func():
			if not pj.live(c):
				return
			var at: Vector3 = c.global_position + Vector3.UP * 1.0 + d * 1.6
			_rasen_slam(pj, at)
			var hs := pj.hit(c, at, 3.2, pj.inf(c, "choodama_rasengan", 2.6, {"knock": 26.0, "launch": 6.0, "kind": "heavy", "hitstop": 0.1}))
			for h in hs:
				if is_instance_valid(h):
					_rasen_grind(pj, (h as Node3D).global_position + Vector3.UP * 1.0)
			pj.shake(0.9)))
	Sfx.play("wind", c.global_position, 0.9)


## Rasengan topu: sarmal küre + içe akan rüzgâr halesi
static func _rasen_ball(r: float, na: float, nb: float) -> Node3D:
	var root := Node3D.new()
	var sm := _smat("spiral", SPIRAL_SHADER)
	sm.set_shader_parameter("near_a", na)
	sm.set_shader_parameter("near_b", nb)
	var ball := mi(_sphere(), sm)
	ball.scale = Vector3.ONE * r * 2.0
	root.add_child(ball)
	var core := mi(_sphere(), cel(RASEN_CORE, 0.0, INK, false, 0.0, na, nb))
	core.scale = Vector3.ONE * r * 0.9
	root.add_child(core)
	var h := mi(_quad(r * 4.2), halo_mat(Color(0.5, 0.8, 1.0, 0.85), RASEN_CORE, 0.48, 6.0, 1.5, na, nb))
	root.add_child(h)
	root.set_meta("m", sm)
	return root


## İsabet edilen bedende öğütme: dönen beyaz-mavi rüzgâr kıymıkları teğet savrulur
static func _rasen_grind(pj: PathJutsu, at: Vector3) -> void:
	var m := cel(RASEN_CORE, 0.01, RASEN_LINE, true, 0.0, 0.5, 2.0)
	var shard := slab(petal(0.4, 0.08), 0.01, Color.WHITE, _up_b())
	burst(pj, at, shard, m, 12, 0.45, {"r": 0.4, "dir": Vector3.UP, "spread": 180.0, "vmin": 4.0, "vmax": 7.0, "g": Vector3.ZERO, "tang": 30.0, "damp": 6.0, "smin": 0.8, "smax": 1.3, "align": true})


static func _rasen_slam(pj: PathJutsu, at: Vector3) -> void:
	var big := _rasen_ball(1.0, 3.0, 7.0)
	put(pj, big, at)
	big.scale = Vector3.ONE * 0.5
	var tw := big.create_tween()
	tw.tween_property(big, "scale", Vector3.ONE * 3.2, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(big, "scale", Vector3.ONE * 3.35, 0.14)
	tw.tween_property(big, "scale", Vector3.ONE * 0.05, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(big.queue_free)
	# öğüten rüzgâr yayları (kubbe değil: ayrık, dönen şeritler)
	var wm := cel(Color(0.9, 0.97, 1.0, 0.9), 0.0, INK, true, 0.0, 3.0, 7.0)
	var spin := Node3D.new()
	put(pj, spin, at)
	for k in 6:
		var a0 := TAU * k / 6.0
		var hgt := randf_range(-1.6, 1.6)
		var rr := sqrt(maxf(0.3, 3.4 * 3.4 - hgt * hgt))
		var pts: Array = []
		for j in 12:
			var a := a0 + j * 0.13
			pts.append(Vector3(cos(a) * rr, hgt, sin(a) * rr))
		spin.add_child(mi(ribbon(pts, 0.16, Vector3.UP, 0), wm))
	spin.scale = Vector3.ONE * 0.2
	var st := spin.create_tween()
	st.tween_property(spin, "scale", Vector3.ONE, 0.26).set_ease(Tween.EASE_OUT)
	st.parallel().tween_property(spin, "rotation:y", TAU * 1.6, 0.6)
	fade_out(spin, wm, 0.35, 0.25)
	var g: Vector3 = pj.gp(at)
	var rk := cel(Color(0.55, 0.5, 0.45), 0.012, INK, false, 0.0, 0.5, 2.0)
	burst(pj, g + Vector3.UP * 0.4, _chunk(), rk, 26, 1.1, {"r": 2.4, "dir": Vector3.UP, "spread": 60.0, "vmin": 4.0, "vmax": 9.0, "g": Vector3(0, -18, 0), "tang": 14.0, "smin": 0.7, "smax": 1.6, "spin": 300.0})
	# krater: koyu çukur + yukarıdan bakınca çatlak ışınları
	ground_blot(pj, g, 2.6, Color(0.24, 0.2, 0.16, 0.9), 6.0, 0.2, null, 0.25)
	ground_blot(pj, g, 1.5, Color(0.12, 0.1, 0.08, 0.9), 6.0, 0.25, null, 0.25, 0.05)
	var km := cel(Color(0.08, 0.06, 0.05), 0.0, INK, true, 0.0, 0.5, 2.0)
	for k in 10:
		var a := TAU * k / 10.0 + randf() * 0.3
		var pts: Array = []
		var q := Vector3(cos(a), 0, sin(a)) * 1.3
		for j in 6:
			pts.append(q + Vector3.UP * 0.06)
			q += Vector3(cos(a), 0, sin(a)).rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(0.45, 0.7)
		var x := mi(ribbon(pts, 0.14, Vector3.UP, 1), km)
		put(pj, x, g)
		fade_out(x, km, 5.2, 0.8)


# ================================================================== ABUSŌBU SUFİA — emme küreleri
## İki zifiri küre (mavi parlak kenar + içe akan sarmal hale) avuçların önünde; gelen mermi küreye doğru sarmalla
## çekilip yutulur (küre şişer), süre bitince küreler içine çöker
static func abusobu_sufia(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var orbs: Array = []
	for sx in [-1.0, 1.0]:
		var o := Node3D.new()
		var core := mi(_sphere(), void_mat(ABS_GLOW, ABS_HOT, 0.18))
		o.add_child(core)
		var h := mi(_quad(2.3), halo_mat(Color(0.3, 0.56, 1.0, 0.95), ABS_HOT, 0.42, 7.0, 1.0, 0.4, 1.4))
		o.add_child(h)
		c.add_child(o)
		o.position = Vector3(sx * 0.8, 1.4, 1.2)
		o.scale = Vector3.ONE * 0.05
		o.create_tween().tween_property(o, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var bob := Game.safe_loops(o.create_tween())
		bob.tween_property(o, "position:y", 1.48, 0.7).set_trans(Tween.TRANS_SINE)
		bob.tween_property(o, "position:y", 1.32, 0.7).set_trans(Tween.TRANS_SINE)
		orbs.append(o)
	pj.every(8.0, 0.1, func(_i, _k):
		if not pj.live(c):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and p.global_position.distance_to(c.global_position + Vector3.UP * 1.3 + c.face_dir()) < 3.0:
				_abs_suck(pj, p.global_position, orbs)
				p.queue_free()
				pj.chakra_gain(c, 6.0), func():
		for o in orbs:
			if is_instance_valid(o):
				var ct = o.create_tween()
				ct.tween_property(o, "scale", Vector3.ONE * 1.2, 0.08)
				ct.tween_property(o, "scale", Vector3.ONE * 0.02, 0.16).set_ease(Tween.EASE_IN)
				ct.tween_callback(o.queue_free))
	if c is Player:
		Buffs.add("abusobu", 8.0, {"armor": 0.5, "_name": "Emici Küre", "_desc": "gelen ninjutsu emilip chakraya döner"})
	Sfx.play("seal", c.global_position, 0.8)


## Yutma: mermi yerinden en yakın küreye sarmalla akan mavi zerreler; küre şişip iner
static func _abs_suck(pj: PathJutsu, from: Vector3, orbs: Array) -> void:
	var best: Node3D = null
	var bd := 1e9
	for o in orbs:
		if is_instance_valid(o) and (o as Node3D).is_inside_tree():
			var dd := from.distance_to((o as Node3D).global_position)
			if dd < bd:
				bd = dd
				best = o
	if best == null:
		return
	var tgt := best
	var m := cel(ABS_HOT, 0.0, INK, false, 0.0, 0.4, 1.4)
	for k in 8:
		var x := mi(_sphere_lo(), m)
		put(pj, x, from)
		x.scale = Vector3(0.05, 0.05, 0.2)
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0.2, 0.6)
		var tw := x.create_tween()
		tw.tween_interval(k * 0.02)
		tw.tween_method(func(u: float):
			if is_instance_valid(x) and is_instance_valid(tgt):
				var to: Vector3 = tgt.global_position
				var p := from.lerp(to, u) + off.rotated((to - from).normalized() if to.distance_to(from) > 0.01 else Vector3.UP, u * 6.0) * (1.0 - u)
				_aim(x, p + (p - x.global_position))
				x.global_position = p, 0.0, 1.0, 0.22).set_ease(Tween.EASE_IN)
		tw.tween_callback(x.queue_free)
	var pt := best.create_tween()
	pt.tween_interval(0.2)
	pt.tween_property(best, "scale", Vector3.ONE * 1.3, 0.06)
	pt.tween_property(best, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)


# ================================================================== GENTŌSHİN — fener bedeni (hologram)
## Ayak altında dönen projektör dairesi; beden tarama çizgili, gökkuşağı kenarlı, kesik kesik kayan hologram olur;
## göz hizasında iki halkalı göz ışığı
static func gentoshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("gentoshin_no_jutsu", {})
	if d.is_empty():
		return
	var tier := int(d.get("tier", 2))
	var dur := 8.0 + tier * 2.0
	Buffs.add(String(d.get("id", "buff")), dur, {"speed": 1.1})
	var gm := glyph_mat(HOLO, Color(0.1, 0.3, 0.45), 2)
	var disk := mi(_plane(3.6), gm)
	put(pj, disk, pj.gp(c.global_position) + Vector3.UP * 0.04)
	tw_param(disk, gm, "prog", 0.0, 1.0, 0.3)
	fade_out(disk, gm, 2.4, 0.5)
	var hm := _smat("holo", HOLO_SHADER)
	body_overlay(pj, c, hm, 3.0)
	tw_param(c, hm, "fade", 0.0, 1.0, 0.25)
	tw_param(c, hm, "fade", 1.0, 0.0, 0.5, 2.5)
	var fd := _flat_dir(c.face_dir())
	var side := fd.cross(Vector3.UP).normalized()
	for sx in [-1.0, 1.0]:
		var em := halo_mat(Color(0.75, 0.55, 1.0, 0.95), Color(0.95, 0.9, 1.0), 0.3, 0.0, 0.6, 0.3, 1.0)
		var e := mi(_quad(0.22), em)
		c.add_child(e)
		e.global_position = c.global_position + Vector3.UP * 1.66 + fd * 0.2 + side * sx * 0.075
		fade_out(e, em, 2.2, 0.4)
	if c is Player:
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], HOLO.lightened(0.3))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== TENCHŪ — gökten kunai yağmuru
## Alanda koyu kırmızı hedef mührü yazılır; gökte mühür kâğıtları savrulur; çelik kunailer ince ışık iziyle iner,
## yere saplanıp toprak sıçratır ve bir süre saplı kalır
static func tenchu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt := pj.tg(c, t, 24.0)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var gm := glyph_mat(SEAL_RED, Color(0.12, 0.04, 0.03), 1)
	var disk := mi(_plane(8.4), gm)
	put(pj, disk, at + Vector3.UP * 0.04)
	tw_param(disk, gm, "prog", 0.0, 1.0, 0.3)
	fade_out(disk, gm, 1.6, 0.5)
	Sfx.play("poof", at, 0.8)
	_tenchu_tags(pj, at + Vector3.UP * 10.0)
	var km := _kunai_mat()
	var trm := trail_mat(Color(1, 1, 1, 0.8), Color(0.7, 0.75, 0.8, 1))
	var dm := cel(Color(0.5, 0.42, 0.32), 0.0, INK, false, 0.0, 0.5, 2.0)
	for k in 60:
		pj.after(0.3 + randf() * 0.9, func():
			var q := at + Vector3(randf_range(-4, 4), 10.0, randf_range(-4, 4))
			var g2: Vector3 = pj.gp(q) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			var dir := (g2 - q).normalized()
			pj.shot(c, q, dir, 38.0, _kunai(km, trm), pj.inf(c, "tenchu", 0.08, {"knock": 0.5, "kind": "light", "bleed": 1.0}), null, false, 0.5)
			var land := pj.gp(g2)
			pj.after(q.distance_to(land) / 38.0, func():
				var stuck := MeshInstance3D.new()
				stuck.mesh = _kunai_mesh()
				stuck.material_override = km
				stuck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				put(pj, stuck, land + dir * -0.12)
				_aim(stuck, land + dir)
				var sw := stuck.create_tween()
				sw.tween_interval(randf_range(2.0, 3.0))
				sw.tween_property(stuck, "global_position", land + dir * 0.25, 0.3)
				sw.tween_callback(stuck.queue_free)
				if k % 3 == 0:
					burst(pj, land + Vector3.UP * 0.05, _chunk(), dm, 4, 0.45, {"r": 0.05, "dir": Vector3.UP, "spread": 50.0, "vmin": 1.5, "vmax": 3.0, "g": Vector3(0, -14, 0), "smin": 0.2, "smax": 0.4})))
	Sfx.play("throw_kunai", at, 1.1)


static func _kunai_mat() -> ShaderMaterial:
	if not _mc.has("mat:kunai"):
		_mc["mat:kunai"] = cel(Color.WHITE, 0.008, INK, false, 0.55, 0.3, 1.0)
	return _mc["mat:kunai"]


static func _kunai_mesh() -> Mesh:
	if not _mc.has("mesh:kunai"):
		var b := MB.new()
		b.add_slab(PackedVector2Array([Vector2(0, -0.36), Vector2(0.055, -0.13), Vector2(0.02, -0.02), Vector2(-0.02, -0.02), Vector2(-0.055, -0.13)]), 0.018, STEEL)
		b.add("cyl", Vector3(0, 0, 0.07), Vector3(0.028, 0.14, 0.028), GRIP, Vector3(90, 0, 0), 6)
		for j in 3:
			b.add("cyl", Vector3(0, 0, 0.025 + j * 0.04), Vector3(0.034, 0.012, 0.034), Color(0.55, 0.5, 0.42), Vector3(90, 0, 0), 6)
		b.add("sphere", Vector3(0, 0, 0.17), Vector3(0.07, 0.07, 0.025), STEEL, Vector3(0, 90, 0), 8)
		_mc["mesh:kunai"] = b.build()
	return _mc["mesh:kunai"]


static func _kunai(km: Material, trm: Material) -> Node3D:
	var root := Node3D.new()
	var k := MeshInstance3D.new()
	k.mesh = _kunai_mesh()
	k.material_override = km
	k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(k)
	root.add_child(mi(ribbon([Vector3(0, 0, 0.1), Vector3(0, 0, 0.7), Vector3(0, 0, 1.3)], 0.06, Vector3.RIGHT, 2), trm))
	return root


## Göğün mühür kâğıtları: halka hâlinde açılıp savrulur, alt uçtan küle döner
static func _tenchu_tags(pj: PathJutsu, top: Vector3) -> void:
	var pm := cel(Color.WHITE, 0.01, INK, true, 0.0, 1.0, 3.0)
	for k in 10:
		var a := TAU * k / 10.0
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.32, 0.9, 0.01), Color(0.95, 0.9, 0.78))
		b.add("box", Vector3(0, 0.05, 0.007), Vector3(0.05, 0.6, 0.004), SEAL_RED)
		b.add("box", Vector3(0, 0.25, 0.007), Vector3(0.18, 0.04, 0.004), SEAL_RED)
		b.add("box", Vector3(0, -0.15, 0.007), Vector3(0.16, 0.04, 0.004), SEAL_RED)
		var x := mi(b.build(), pm)
		put(pj, x, top)
		x.rotation.y = -a
		var to := top + Vector3(cos(a), 0, sin(a)) * 4.5 + Vector3.DOWN * randf_range(0.5, 1.5)
		var tw := x.create_tween()
		tw.tween_property(x, "global_position", to, 0.5).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(x, "rotation:z", randf_range(-0.8, 0.8), 0.5)
		tw.tween_property(x, "scale", Vector3(1, 0.02, 1), 0.4).set_ease(Tween.EASE_IN)
		tw.tween_callback(x.queue_free)


# ================================================================== TAKOASHİ BUNSHİN — ahtapot kolu klonu
## Sırttan vantuzlu ahtapot kolu klonun yerine uzanır, kopan uç yerde kıvrılıp bedene dönüşür (ıslak damlalar);
## klon vurulunca yine yerde çırpınan ahtapot koluna döner
static func takoashi_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var at := pj.gp(c.global_position + c.face_dir().cross(Vector3.UP) * 3.0)
	var a0: Vector3 = c.global_position + Vector3.UP * 1.2 - c.face_dir() * 0.3
	_tako_reach(pj, a0, at + Vector3.UP, 0.4)
	pj.after(0.35, func():
		if pj.live(c):
			_tako_curl(pj, at)
			var cl = pj.decoy(c, at, 12.0, func(pos):
				_tako_drop(pj, pos))
			if cl:
				cl.set_meta("no_smoke", true))
	Sfx.play("water", at, 0.9)


## Ahtapot kolu: incelen tüp + alt yüzde iki sıra vantuz. Döner: kök (meta "mats")
static func _tentacle(pts: Array, r0: float, r1: float, grow := false) -> Node3D:
	var root := Node3D.new()
	var bm := cel(OCTO_SKIN, 0.014, Color(0.12, 0.04, 0.1), false, 0.2, 0.4, 1.6)
	if grow:
		setp(bm, "grow", 0.0)
	root.add_child(mi(tube(pts, r0, r1, 10), bm))
	var sb := MB.new()
	var n := pts.size()
	for i in range(1, n - 1):
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[i + 1] - pts[i - 1]).normalized()
		var side: Vector3 = tn.cross(Vector3.UP if absf(tn.y) < 0.9 else Vector3.RIGHT).normalized()
		var dn: Vector3 = tn.cross(side).normalized()
		if dn.y > 0.0:
			dn = -dn
		var r := lerpf(r0, r1, float(i) / (n - 1))
		for sx in [-0.45, 0.45]:
			var q: Vector3 = p + dn * r * 0.9 + side * r * sx
			var s := r * 0.55
			sb.add("sphere", q, Vector3(s, s * 0.45, s), OCTO_SUCK, Vector3.ZERO, 6)
	var sm := cel(Color.WHITE, 0.006, Color(0.35, 0.15, 0.25), false, 0.0, 0.4, 1.6)
	var suck := mi(sb.build(), sm)
	root.add_child(suck)
	root.set_meta("mats", [bm, sm])
	root.set_meta("suck", suck)
	return root


static func _tako_reach(pj: PathJutsu, a: Vector3, b: Vector3, life: float) -> void:
	var pts: Array = []
	var side := (b - a).cross(Vector3.UP).normalized()
	for k in 14:
		var u := k / 13.0
		pts.append(a.lerp(b, u) + Vector3.UP * sin(PI * u) * 0.9 + side * sin(TAU * u) * 0.25 - a)
	var root := _tentacle(pts, 0.17, 0.05, true)
	put(pj, root, a)
	var mats: Array = root.get_meta("mats")
	var suck: Node3D = root.get_meta("suck")
	suck.scale = Vector3.ONE * 0.01
	tw_param(root, mats[0], "grow", 0.0, 1.0, 0.18)
	var st := suck.create_tween()
	st.tween_interval(0.14)
	st.tween_property(suck, "scale", Vector3.ONE, 0.06)
	fade_out(root, mats, life - 0.1, 0.1)


## Kopan uç: yerde kıvrılıp döner, uzayıp bedene dönüşür; pembe ıslak damlalar + ıslak leke
static func _tako_curl(pj: PathJutsu, at: Vector3) -> void:
	var pts: Array = []
	for k in 16:
		var u := k / 15.0
		var a := u * TAU * 1.3
		var r := 0.55 * (1.0 - u * 0.75)
		pts.append(Vector3(cos(a) * r, u * 1.1, sin(a) * r))
	var stub := _tentacle(pts, 0.17, 0.04)
	put(pj, stub, at + Vector3.UP * 0.1)
	stub.rotation = Vector3(0.2, randf() * TAU, 0.15)
	var sw := stub.create_tween()
	sw.tween_property(stub, "scale", Vector3(0.6, 1.4, 0.6), 0.15)
	sw.parallel().tween_property(stub, "rotation:y", stub.rotation.y + 2.5, 0.27)
	sw.tween_property(stub, "scale", Vector3(0.05, 0.05, 0.05), 0.12)
	sw.tween_callback(stub.queue_free)
	var wm := cel(Color(0.92, 0.7, 0.78, 0.9), 0.006, Color(0.4, 0.15, 0.3), false, 0.6, 0.4, 1.4)
	burst(pj, at + Vector3.UP * 0.8, _sphere_lo(), wm, 16, 0.7, {"r": 0.5, "dir": Vector3.UP, "spread": 90.0, "vmin": 2.0, "vmax": 4.0, "g": Vector3(0, -14, 0), "smin": 0.06, "smax": 0.14})
	ground_blot(pj, at, 0.9, Color(0.3, 0.16, 0.24, 0.5), 2.2, 0.35)


## Klon dağılınca: yerde çırpınan kopuk ahtapot kolu (0,8 sn sonra 0,3 sn'de söner)
static func _tako_drop(pj: PathJutsu, pos: Vector3) -> void:
	var pts: Array = []
	for k in 14:
		var u := k / 13.0
		pts.append(Vector3(u * 1.4 - 0.7, 0.0, 0.0) + (Vector3(0, sin(u * 5.0) * 0.12, cos(u * 4.0) * 0.2) if u > 0.6 else Vector3.ZERO))
	var root := _tentacle(pts, 0.15, 0.04)
	put(pj, root, pos + Vector3.UP * 0.3)
	root.rotation.y = randf() * TAU
	var tw := root.create_tween()
	for j in 3:
		tw.tween_property(root, "rotation:z", 0.3 * (1.0 if j % 2 == 0 else -1.0), 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(root, "rotation:z", 0.0, 0.2)
	fade_out(root, root.get_meta("mats"), 0.8, 0.3)
	var wm := cel(Color(0.92, 0.7, 0.78, 0.9), 0.006, Color(0.4, 0.15, 0.3), false, 0.6, 0.4, 1.4)
	burst(pj, pos + Vector3.UP * 0.4, _sphere_lo(), wm, 8, 0.6, {"r": 0.4, "dir": Vector3.UP, "spread": 80.0, "vmin": 1.5, "vmax": 3.0, "g": Vector3(0, -14, 0), "smin": 0.05, "smax": 0.1})


# ================================================================== ZESSHİ NENSAN — yapışkan aşındırıcı asit
## Ağızdan hedefe uzanan kalın, kaynayan sarı asit ipi; ipte topaklar akar, ipten damlalar süzülür; uçta sivri dilli
## yıldız sıçraması; yerde kenarı sarı, ortası koyulaşan aşınma lekesi ve cızırdayan minik kabarcıklar
static func zesshi_nensan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt := pj.tg(c, t, 18.0)
	var from := pj._mouth_pos(c)
	var to: Vector3 = (tt.global_position + Vector3.UP if tt else from + c.face_dir() * 10.0)
	_acid_rope(pj, from, to)
	pj.after(maxf(0.25, 0.5 * 0.65), func(): _acid_burst(pj, to))
	if tt:
		pj.after(0.3, func():
			if pj.live(tt):
				pj.st(tt, "slow", 3.0)
				tt.take_hit(pj.inf(c, "zesshi_nensan", 0.9, {"knock": 4.0, "kind": "heavy", "poison": 4.0})))
	Sfx.play("water", from, 0.8)


static func _acid_rope(pj: PathJutsu, from: Vector3, to: Vector3) -> void:
	var L := from.distance_to(to)
	var side := (to - from).cross(Vector3.UP).normalized()
	var pts: Array = []
	for k in 16:
		var u := k / 15.0
		pts.append(from.lerp(to, u) + Vector3.DOWN * sin(PI * u) * minf(0.6, L * 0.04) + side * sin(u * 9.0) * 0.05 - from)
	var am := oil_mat(ACID, ACID_SPOT, ACID_DARK, 4.0, 1.6, 0.0)
	setp(am, "grow", 0.0)
	var rope := mi(tube(pts, 0.12, 0.17, 8), am)
	put(pj, rope, from)
	tw_param(rope, am, "grow", 0.0, 1.0, 0.28)
	fade_out(rope, am, 0.5, 0.25)
	var gm := oil_mat(ACID, ACID_SPOT, ACID_DARK, 4.0, 1.6, 0.008)
	for k in 5:
		var x := mi(_sphere(), gm)
		put(pj, x, from)
		x.scale = Vector3.ONE * randf_range(0.26, 0.38)
		var gt := x.create_tween()
		gt.tween_interval(k * 0.06)
		gt.tween_method(func(u: float):
			if is_instance_valid(x):
				x.global_position = from + (pts[mini(int(u * 15.0), 15)] as Vector3), 0.0, 1.0, 0.26)
		gt.tween_callback(x.queue_free)
	var dm := oil_mat(ACID, ACID_SPOT, ACID_DARK, 6.0, 0.0, 0.0)
	pj.after(0.25, func():
		for k in 3:
			burst(pj, from + (pts[4 + k * 4] as Vector3), _sphere_lo(), dm, 4, 0.6, {"r": 0.1, "dir": Vector3.DOWN, "spread": 15.0, "vmin": 0.2, "vmax": 1.0, "g": Vector3(0, -12, 0), "smin": 0.06, "smax": 0.12, "expl": 0.3}))


static func _acid_burst(pj: PathJutsu, p: Vector3) -> void:
	var sm := cel(ACID_SPOT, 0.012, Color(0.45, 0.4, 0.05), false, 0.3, 0.6, 2.0)
	for k in 14:
		var dv := Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
		var x := mi(slab(petal(randf_range(0.7, 1.5), 0.2), 0.04, Color.WHITE, _up_b()), sm)
		put(pj, x, p)
		_aim(x, p + dv)
		x.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		x.scale = Vector3.ONE * 0.15
		var tw := x.create_tween()
		tw.tween_property(x, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(x, "global_position", p + dv * 0.4, 0.15)
		tw.tween_property(x, "scale", Vector3(0.4, 1.2, 0.4), 0.25)
		tw.tween_callback(x.queue_free)
	var dm := cel(ACID, 0.008, ACID_DARK, false, 0.4, 0.5, 2.0)
	burst(pj, p, _sphere_lo(), dm, 20, 0.8, {"r": 0.3, "spread": 180.0, "vmin": 3.0, "vmax": 6.0, "g": Vector3(0, -14, 0), "smin": 0.07, "smax": 0.16})
	var g: Vector3 = pj.gp(p)
	ground_blot(pj, g, 1.35, ACID, 3.8, 0.4)
	var core := ground_blot(pj, g, 0.8, Color(0.24, 0.26, 0.04, 0.95), 3.8, 0.45, null, 0.2, 0.05)
	core.create_tween().tween_property(core, "scale", Vector3(1.5, 1, 1.5), 3.0).set_delay(0.3)
	var bm := cel(ACID_SPOT, 0.005, ACID_DARK, false, 0.0, 0.5, 2.0)
	pj.every(3.0, 0.12, func(_i, _k):
		for j in 2:
			var b := mi(_sphere_lo(), bm)
			var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 1.0
			put(pj, b, g + off + Vector3.UP * 0.06)
			b.scale = Vector3.ONE * 0.01
			var s := randf_range(0.05, 0.11)
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector3.ONE * s, 0.1)
			tw.parallel().tween_property(b, "global_position:y", g.y + 0.06 + randf_range(0.05, 0.25), 0.18)
			tw.tween_property(b, "scale", Vector3.ONE * 0.01, 0.05)
			tw.tween_callback(b.queue_free))


# ================================================================== SHİKOMİSHİNDAN — bilekten zehirli iğneler
## Bilek düzeneği tık diye açılır (metal halka + kıvılcım), ince gümüş, ucu yeşil zehirli iğneler yeşil-beyaz çizgiyle
## uçar; isabette minik yeşil zehir damlaları ve yaprak sıçraması
static func shikomishindan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt := pj.tg(c, t, 20.0)
	pj.busy(c, 0.4)
	pj.anim(c, "push", 1.8)
	var from := pj.hand_pos(c, true)
	_wrist_click(pj, from, pj.aim_at(c, tt, from))
	for k in 6:
		pj.after(k * 0.05, func():
			pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.05, 0.05)), 55.0, _needle(), pj.inf(c, "shikomishindan", 0.12, {"knock": 0.2, "kind": "light", "poison": 4.0}), null, false, 0.8, func(p, _h):
				_venom_pop(pj, p)))
	Sfx.play("throw_kunai", from, 1.6, 0.4)


static func _wrist_click(pj: PathJutsu, at: Vector3, dir: Vector3) -> void:
	var m := cel(STEEL, 0.006, INK, false, 0.6, 0.3, 1.0)
	var o := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		o.append(Vector2(cos(a), sin(a)) * 0.09)
	var ring := mi(slab(MB.hole(o, Vector2.ZERO, 0.055, 12), 0.02, Color.WHITE, _up_b()), m)
	put(pj, ring, at)
	_aim(ring, at + dir)
	ring.rotate_object_local(Vector3.UP, PI)
	ring.scale = Vector3.ONE * 0.3
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 1.2, 0.08)
	tw.tween_property(ring, "scale", Vector3.ONE * 0.05, 0.12)
	tw.tween_callback(ring.queue_free)
	var sm := cel(Color(1.0, 0.97, 0.85), 0.0, INK, false, 0.0, 0.3, 1.0)
	burst(pj, at, _sphere_lo(), sm, 6, 0.2, {"r": 0.03, "dir": dir, "spread": 35.0, "vmin": 3.0, "vmax": 6.0, "g": Vector3.ZERO, "smin": 0.02, "smax": 0.04, "align": true})


static func _needle() -> Node3D:
	if not _mc.has("mesh:needle"):
		var b := MB.new()
		b.add("cyl", Vector3(0, 0, 0.02), Vector3(0.014, 0.3, 0.014), Color(0.82, 0.85, 0.88), Vector3(90, 0, 0), 4)
		b.add("cone", Vector3(0, 0, -0.16), Vector3(0.018, 0.06, 0.018), VENOM, Vector3(-90, 0, 0), 4)
		_mc["mesh:needle"] = b.build()
	if not _mc.has("mat:needle"):
		_mc["mat:needle"] = cel(Color.WHITE, 0.004, INK, false, 0.6, 0.3, 1.0)
	if not _mc.has("mat:needle_tr"):
		_mc["mat:needle_tr"] = trail_mat(Color(0.85, 1.0, 0.8, 0.9), VENOM)
	var root := Node3D.new()
	var n := MeshInstance3D.new()
	n.mesh = _mc["mesh:needle"]
	n.material_override = _mc["mat:needle"]
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(n)
	root.add_child(mi(ribbon([Vector3(0, 0, 0.15), Vector3(0, 0, 0.9), Vector3(0, 0, 1.6)], 0.035, Vector3.RIGHT, 2), _mc["mat:needle_tr"]))
	return root


static func _venom_pop(pj: PathJutsu, p: Vector3) -> void:
	var dm := cel(VENOM, 0.006, Color(0.1, 0.3, 0.08), false, 0.5, 0.4, 1.4)
	burst(pj, p, _sphere_lo(), dm, 10, 0.6, {"r": 0.1, "spread": 180.0, "vmin": 1.0, "vmax": 2.6, "g": Vector3(0, -9, 0), "smin": 0.04, "smax": 0.09})
	flash_star(pj, p, Color(0.8, 1.0, 0.7), 0.25, 5, 0.16)
