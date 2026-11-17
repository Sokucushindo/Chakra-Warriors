class_name KinjutsuFXA
extends RefCounted
## Kinjutsu (yasak teknikler) grubu A: on iki tekniğin görselleri, hepsi bu dosyada kendi gölgelendiricileriyle sıfırdan.
## Sekiz Kapı teknikleri GERÇEK kapı durumunu (PathJutsu.gate_level) izleyen beden buharı kullanır: buhar karakterin kendi
## ağlarına kaplama (material_overlay) olarak giydirilir (kutu / küre kabuk yok), kapı yükseldikçe yeşil → mavi → kızıl olur.
## Klon teknikleri oyunun gerçek klon sistemini (decoy / ShadowClone) kullanır; Tajū'nun "yüzlerce" klonu ek olarak tek
## MultiMesh kalabalığıdır (performans dostu). Taijutsu tarafı ışık şovu değil: çarpma karesi, hız izi, toz, çatlak, kaya.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme) ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}

const UP := Vector3.UP
const DUST_C := Color(0.84, 0.76, 0.62)
const EARTH_C := Color(0.55, 0.43, 0.32)
const SAND_C := Color(0.8, 0.64, 0.42)
const GATE_RED := Color(1.0, 0.24, 0.18)
const FLESH_COLS := [Color(0.8, 0.53, 0.56), Color(0.88, 0.62, 0.64), Color(0.7, 0.45, 0.5)]
const SNAKE_C := Color(0.93, 0.91, 0.86)
const GOLD := Color(1.0, 0.84, 0.4)

# ================================================================== gölgelendiriciler
const NOISE := """
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnz(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x), mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

## Kameraya dönük düzlem; kameraya yaklaşınca küçülür (ekranı kaplamasın)
const BBV := """
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	VERTEX *= clamp(length(MODELVIEW_MATRIX[3].xyz) / 7.0, 0.35, 1.0);
"""

## Mürekkep şerit: hız çizgisi, çarpma dikeni, şok halkası. UV.x boyunca açılır (k_grow), kenarlarda koyu bant.
const INK := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 k_edge = vec4(0.12, 0.12, 0.15, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_grow = 1.0;
instance uniform float k_tail = 0.0;
void vertex() {
//BB
}
void fragment() {
	float age = k_grow - UV.x;
	if (age < 0.0) {
		discard;
	}
	float tl = clamp(1.0 - age * k_tail, 0.0, 1.0);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	vec3 col = mix(k_edge.rgb, k_col.rgb, smoothstep(0.22, 0.45, across));
	ALBEDO = col;
	ALPHA = clamp(k_a * tl * smoothstep(0.0, 0.15, across) * smoothstep(0.8, 3.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Cel toz: loblu kenar, iki ton + koyu kenar; k_a düştükçe kenardan içe dağılır
const DUST := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.84, 0.76, 0.62, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
NOISE
void vertex() {
//BB
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float lob = 0.74 + 0.14 * sin(ang * 4.0 + k_seed * 5.0) + 0.1 * (vnz(vec2(cos(ang) * 1.8 + k_seed, sin(ang) * 1.8)) - 0.5);
	if (r > lob) {
		discard;
	}
	float er = vnz(p * 3.2 + k_seed * 7.0);
	if (er * 0.85 + 0.15 > k_a + (1.0 - r / lob) * 0.4) {
		discard;
	}
	float lit = step(0.0, p.y * 0.6 + p.x * 0.4 + (er - 0.5) * 0.45);
	vec3 col = mix(k_col.rgb * 0.7, k_col.rgb, lit);
	if (r > lob - 0.08) {
		col *= 0.6;
	}
	ALBEDO = col;
	ALPHA = smoothstep(0.8, 3.0, length(VERTEX));
}
"""

## Zemin izi: 0 yıldız çatlak, 1 uzun yarık (yerel z), 2 göçük, 3 sarmal oyuk, 4 kesikli halkalar, 5 is, 6 ıslak leke, 7 düz kesikler
const DECAL := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.08, 0.06, 0.05, 1.0);
instance uniform vec4 k_col2 = vec4(0.45, 0.36, 0.27, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_grow = 1.0;
instance uniform float k_mode = 0.0;
instance uniform float k_seed = 0.0;
instance uniform float k_n = 9.0;
NOISE
float crk(vec2 p, float n, float sd, float r0, float wid) {
	float r = length(p);
	float s = atan(p.y, p.x) / 6.2831853 * n;
	float id = floor(s);
	float wob = (vnz(vec2(r * 5.0 + sd, id * 1.7 + sd)) - 0.5) * 0.6 + (vnz(vec2(r * 15.0, id * 2.9 + sd)) - 0.5) * 0.18;
	float f = fract(s + wob) - 0.5;
	float d = abs(f) * 6.2831853 / n * r;
	float ln = 0.45 + 0.55 * hsh(vec2(id, sd));
	if (r < r0 || r > ln) {
		return 0.0;
	}
	float w = wid * (1.0 - r / ln) + 0.003;
	return 1.0 - smoothstep(w * 0.5, w, d);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	int md = int(k_mode + 0.5);
	vec3 col = k_col.rgb;
	float a = 0.0;
	float rev = r;
	if (md == 0) {
		a = max(crk(p, k_n, k_seed, 0.04, 0.035), crk(p, k_n * 2.0, k_seed + 4.0, 0.3, 0.02) * 0.8);
	} else if (md == 1) {
		float z = abs(p.y);
		float x = p.x + (vnz(vec2(p.y * 7.0, k_seed)) - 0.5) * 0.16;
		float w = 0.1 * pow(clamp(1.0 - z, 0.0, 1.0), 0.7) + 0.004;
		a = 1.0 - smoothstep(w * 0.6, w, abs(x));
		float lip = (1.0 - smoothstep(w, w * 2.6, abs(x))) * 0.6;
		if (lip > a) {
			a = lip;
			col = k_col2.rgb;
		}
		rev = (p.y + 1.0) * 0.5;
	} else if (md == 2) {
		if (r < 0.42) {
			col = k_col2.rgb * (0.45 + 0.4 * r / 0.42);
			a = 0.92;
			if (crk(p, 7.0, k_seed + 3.0, 0.02, 0.03) > 0.5) {
				col = k_col.rgb;
			}
		} else if (r < 0.5) {
			col = k_col.rgb;
			a = 0.9;
		} else {
			a = crk(p, k_n, k_seed, 0.48, 0.03);
		}
	} else if (md == 3) {
		float ang = atan(p.y, p.x);
		float sp = fract((ang / 6.2831853) * 3.0 + r * 2.6 + k_seed);
		float groove = 1.0 - smoothstep(0.06, 0.14, abs(sp - 0.5));
		a = groove * (1.0 - smoothstep(0.75, 1.0, r)) * 0.85;
		col = mix(k_col.rgb, k_col2.rgb, 0.3);
		if (r < 0.22) {
			a = 0.85;
			col = k_col2.rgb * 0.55;
		}
	} else if (md == 4) {
		float ang = atan(p.y, p.x) / 6.2831853;
		float rg = fract(r * k_n);
		float ln2 = 1.0 - smoothstep(0.03, 0.08, abs(rg - 0.5));
		float dash = step(0.42, fract(ang * (40.0 + floor(r * k_n) * 18.0)));
		a = ln2 * dash * (1.0 - smoothstep(0.85, 1.0, r));
	} else if (md == 5) {
		float n = vnz(p * 4.0 + k_seed);
		float ed = 0.62 + (n - 0.5) * 0.35;
		a = (1.0 - smoothstep(ed - 0.1, ed, r)) * 0.85;
		col = mix(k_col.rgb, k_col2.rgb, smoothstep(0.2, 0.6, r / ed) * 0.6);
	} else if (md == 6) {
		float n = vnz(p * 3.0 + k_seed) * 0.6 + vnz(p * 9.0 + k_seed) * 0.4;
		float ed = 0.55 + (n - 0.5) * 0.5;
		a = (1.0 - smoothstep(ed - 0.06, ed, r)) * 0.75;
		col = mix(k_col.rgb, k_col2.rgb, step(ed - 0.12, r));
	} else {
		float s = atan(p.y, p.x) / 6.2831853 * k_n;
		float d = abs(fract(s) - 0.5) * 6.2831853 / k_n * r;
		a = (1.0 - smoothstep(0.006, 0.016, d)) * step(0.12, r) * (1.0 - smoothstep(0.8, 1.0, r));
	}
	if (rev > k_grow) {
		a = 0.0;
	}
	ALBEDO = col;
	ALPHA = clamp(a * k_a, 0.0, 1.0);
}
"""

## Beden buharı (kaplama): karakterin kendi ağına yapışır; dünya uzayında yukarı akan dil dil cel buhar, kenarda yoğun
const STEAM_OV := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 col = vec4(0.45, 1.0, 0.45, 1.0);
uniform vec4 hot = vec4(0.9, 1.0, 0.9, 1.0);
uniform float amt = 1.0;
uniform float push = 0.03;
uniform float speed = 2.6;
varying vec3 wp;
NOISE
void vertex() {
	VERTEX += NORMAL * push;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = vnz(vec2(wp.x * 4.0 + wp.z * 3.0, wp.y * 3.0 - TIME * speed));
	float n2 = vnz(vec2(wp.x * 9.0 - wp.z * 7.0, wp.y * 7.0 - TIME * speed * 1.7));
	float f = fr * 1.25 + (n - 0.5) * 0.7 + (n2 - 0.5) * 0.35;
	float band = step(0.55, f);
	float core = step(0.85, f);
	ALBEDO = mix(col.rgb, hot.rgb, core);
	ALPHA = clamp(band * amt * (0.55 + 0.4 * core) * smoothstep(0.6, 2.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Buhar tutamı (parçacık): renk / saydamlık parçacığın renk rampasından
const WISP := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
varying float sdv;
NOISE
void vertex() {
	sdv = fract(MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.61 + MODEL_MATRIX[3].y * 0.11) * 10.0;
//BB
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float n = vnz(p * 2.2 + vec2(sdv, -TIME * 1.3));
	float r = length(p * vec2(1.15, 0.85));
	float shp = 0.55 + (n - 0.5) * 0.6;
	if (r > shp) {
		discard;
	}
	float lit = step(0.15, p.y * 0.7 + p.x * 0.2 + (n - 0.5) * 0.6);
	vec3 c = COLOR.rgb * mix(0.78, 1.12, lit);
	if (r > shp - 0.07) {
		c *= 0.7;
	}
	ALBEDO = c;
	ALPHA = clamp(COLOR.a * smoothstep(0.8, 3.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Işık zerresi (parçacık / tek): parlak çekirdek + yumuşak hale
const MOTE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
instance uniform vec4 k_col = vec4(1.0, 1.0, 1.0, 1.0);
void vertex() {
//BB
}
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	if (r > 1.0) {
		discard;
	}
	float core = 1.0 - smoothstep(0.0, 0.35, r);
	float halo = 1.0 - smoothstep(0.2, 1.0, r);
	ALBEDO = COLOR.rgb * k_col.rgb * (halo * 0.7 + core * 0.8) + vec3(core * 0.5);
	ALPHA = clamp(COLOR.a * k_col.a * halo * smoothstep(0.5, 2.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Klon "pon" bulutu (yalnız Gölge Klon kalabalığı; kanon belirme / dağılma): örnek rengi alfa = dağılma
const PON := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
varying float sd;
NOISE
void vertex() {
	sd = fract(MODEL_MATRIX[3].x * 0.31 + MODEL_MATRIX[3].z * 0.53) * 9.0;
//BB
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float lob = 0.72 + 0.16 * sin(ang * 5.0 + sd);
	if (r > lob) {
		discard;
	}
	float er = vnz(p * 3.0 + sd);
	if (er * 0.85 + 0.15 > COLOR.a + (1.0 - r / lob) * 0.4) {
		discard;
	}
	float lit = step(0.0, p.y * 0.6 + p.x * 0.3 + (er - 0.5) * 0.4);
	vec3 c = mix(vec3(0.78, 0.8, 0.86), vec3(1.0), lit);
	if (r > lob - 0.08) {
		c = vec3(0.55, 0.58, 0.66);
	}
	ALBEDO = c;
	ALPHA = smoothstep(0.8, 3.0, length(VERTEX));
}
"""

## Alev dili (Asakujaku): damla biçimli cel alev; k_round 1 = yuvarlak alev topu
const FLAME := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
instance uniform float k_round = 0.0;
NOISE
void vertex() {
//BB
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float fl = (vnz(vec2(p.y * 3.0 - TIME * 7.0, k_seed * 5.0)) - 0.5) * 0.5 * (p.y + 1.0);
	float x = p.x - fl * (1.0 - k_round);
	float y = p.y;
	float circ = sqrt(max(0.0, 0.5625 - (y + 0.25) * (y + 0.25)));
	float w = circ;
	if (y >= -0.25) {
		w = mix(0.75 * (1.0 - (y + 0.25) / 1.25), circ, k_round);
	}
	float tongue = vnz(vec2(x * 4.0 + k_seed, y * 3.0 - TIME * 9.0));
	if (w <= 0.001) {
		discard;
	}
	float d = abs(x) / w;
	if (d > 0.88 + tongue * 0.25) {
		discard;
	}
	float heat = d + (y + 0.25) * 0.45 * (1.0 - k_round) + (tongue - 0.5) * 0.4;
	vec3 c = vec3(1.0, 0.96, 0.62);
	if (heat > 0.42) {
		c = vec3(1.0, 0.68, 0.14);
	}
	if (heat > 0.8) {
		c = vec3(0.86, 0.26, 0.05);
	}
	ALBEDO = c;
	ALPHA = clamp(k_a * smoothstep(0.8, 3.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Hava basıncı sütunu (Sekizō): yarı saydam beyaz-gri, parlak kontur, boyunca akan çizgiler; kamera yakınında söner
const AIR := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
NOISE
void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	float streak = vnz(vec2(UV.x * 26.0, UV.y * 3.0 + TIME * 14.0));
	float rim = smoothstep(0.55, 0.8, fr);
	vec3 c = mix(vec3(0.76, 0.79, 0.82), vec3(1.0), clamp(rim + step(0.72, streak) * 0.5, 0.0, 1.0));
	float a = 0.26 + 0.55 * rim + 0.15 * step(0.6, streak);
	float ends = smoothstep(0.0, 0.06, UV.y) * smoothstep(1.0, 0.92, UV.y);
	ALBEDO = c;
	ALPHA = clamp(a * k_a * ends * smoothstep(1.5, 7.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Kızıl buhar ejderi (Yagai): koyu kızıl gövde, akan girdap çizgileri, pembe parlak kontur
const DRAGON := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
varying vec3 wp;
NOISE
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float n = vnz(wp.xz * 0.7 + vec2(wp.y * 0.9, -TIME * 2.5));
	float n2 = vnz(wp.xz * 2.1 - vec2(TIME * 3.0, wp.y * 1.7));
	vec3 c = mix(vec3(0.42, 0.06, 0.07), vec3(0.82, 0.2, 0.18), smoothstep(0.35, 0.7, n));
	float sw = abs(fract(n * 3.0 + n2 * 0.6) - 0.5);
	c = mix(c, vec3(1.0, 0.5, 0.48), (1.0 - smoothstep(0.02, 0.05, sw)) * 0.8);
	c = mix(c, vec3(1.0, 0.62, 0.58), smoothstep(0.72, 0.85, fr));
	float a = (0.5 + 0.35 * smoothstep(0.5, 0.85, fr) + 0.15 * n2) * k_a;
	ALBEDO = c;
	ALPHA = clamp(a * smoothstep(1.5, 6.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Uzay bükülmesi (Yagai): ekran görüntüsünü küre içinde merceklendirip kızıla çalar
const WARP := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform float k_a = 1.0;
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 off = NORMAL.xy * f * 0.07 * k_a;
	vec3 bg = textureLod(scr, SCREEN_UV - off, 0.0).rgb;
	bg = mix(bg, bg * vec3(1.2, 0.7, 0.7), 0.4 * k_a);
	ALBEDO = bg;
	ALPHA = clamp(k_a * smoothstep(0.0, 0.5, f) * smoothstep(1.5, 5.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Rasengan küresi: dönen sarmal çizgiler, açık çekirdek, koyu mavi kontur
const RASEN := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 n = normalize(lp);
	float ang = atan(n.z, n.x);
	float sw = sin(ang * 3.0 + n.y * 8.0 - TIME * 24.0);
	float sw2 = sin(ang * 5.0 - n.y * 6.0 - TIME * 31.0);
	float lines = max(smoothstep(0.8, 0.95, sw), smoothstep(0.85, 0.97, sw2) * 0.7);
	vec3 c = mix(vec3(0.3, 0.55, 1.0), vec3(0.88, 0.96, 1.0), smoothstep(0.45, 0.9, f));
	c = mix(c, vec3(1.0), lines * 0.75);
	if (f < 0.18) {
		c = vec3(0.12, 0.3, 0.8);
	}
	ALBEDO = c;
	ALPHA = clamp((0.5 + 0.35 * (1.0 - f) + lines * 0.3) * k_a * smoothstep(0.8, 3.0, length(VERTEX)), 0.0, 1.0);
}
"""

## Patlama küresi (Gōjō etiketleri): loblu cel ateş topu, k_t ile soğur ve delik delik dağılır
const BLAST := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_t = 0.0;
instance uniform float k_seed = 0.0;
varying vec3 lp;
NOISE
void vertex() {
	vec3 n = normalize(VERTEX);
	float bump = vnz(n.xy * 1.7 + k_seed) * 0.5 + vnz(n.yz * 1.9 + k_seed) * 0.5;
	VERTEX *= 0.85 + bump * 0.35;
	lp = VERTEX;
}
void fragment() {
	vec3 n = normalize(lp);
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float nz = vnz(n.xy * 3.0 + vec2(k_seed, TIME * 2.0)) * 0.5 + vnz(n.yz * 3.3 - vec2(TIME * 1.5, k_seed)) * 0.5;
	if (nz < k_t * 1.25 - 0.25) {
		discard;
	}
	float z = (1.0 - f) * 0.9 + (nz - 0.5) * 0.45 + k_t * 0.75;
	vec3 c = vec3(1.0, 0.97, 0.78);
	if (z > 0.3) {
		c = vec3(1.0, 0.74, 0.22);
	}
	if (z > 0.62) {
		c = vec3(0.93, 0.36, 0.08);
	}
	if (z > 0.95) {
		c = vec3(0.3, 0.12, 0.08);
	}
	ALBEDO = c;
	ALPHA = smoothstep(1.0, 4.0, length(VERTEX));
}
"""

## Patlayıcı etiket (MultiMesh): kâğıt, çerçeve, kırmızı halkalı mühür, yazı sütunları; özel veri x = yanma
const TAG := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
varying float burn;
float h1(float x) { return fract(sin(x * 91.7) * 43758.5); }
void vertex() {
	burn = INSTANCE_CUSTOM.x;
}
void fragment() {
	if (length(VERTEX) < 0.9) {
		discard;
	}
	vec2 p = UV;
	vec3 c = vec3(0.93, 0.89, 0.77);
	vec3 ink = vec3(0.1, 0.08, 0.08);
	float bd = min(min(p.x, 1.0 - p.x) * 3.0, min(p.y, 1.0 - p.y) * 8.0);
	if (bd < 0.12) {
		c = vec3(0.62, 0.5, 0.36);
	}
	vec2 gc = (p - vec2(0.5, 0.36)) * vec2(1.0, 2.6);
	float gr = length(gc);
	if (abs(gr - 0.3) < 0.04) {
		c = vec3(0.62, 0.1, 0.07);
	}
	if (gr < 0.24 && (abs(gc.x) < 0.035 || abs(gc.y) < 0.035 || abs(gc.x - gc.y * 0.8) < 0.03)) {
		c = ink;
	}
	for (int i = 0; i < 2; i++) {
		float cx = 0.2 + float(i) * 0.6;
		float row = floor(p.y * 16.0);
		if (abs(p.x - cx) < 0.035 && h1(row + float(i) * 7.0) > 0.35 && p.y > 0.08 && p.y < 0.92) {
			c = ink;
		}
	}
	if (p.y > 0.6 && p.y < 0.88 && abs(p.x - 0.5) < 0.12 && (abs(p.x - 0.5) < 0.025 || abs(fract(p.y * 9.0) - 0.5) < 0.09)) {
		c = ink;
	}
	float g = clamp(burn, 0.0, 1.0);
	float glow = abs(sin(p.y * 40.0 + p.x * 13.0));
	c = mix(c, mix(vec3(1.0, 0.55, 0.1), vec3(1.0, 0.95, 0.6), glow), g * 0.85);
	ALBEDO = c;
}
"""

## Katı cel (kaya, et kütlesi, şuriken, klon kalabalığı): köşe rengi × örnek tonu, iki ton ışık, isteğe parlak benek
const CEL := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
instance uniform vec4 k_tint = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float k_spec = 0.0;
instance uniform vec4 k_glow = vec4(1.0, 0.4, 0.2, 0.0);
void fragment() {
	if (length(VERTEX) < 1.2) {
		discard;
	}
	vec3 L = normalize((VIEW_MATRIX * vec4(0.35, 0.85, 0.4, 0.0)).xyz);
	float nl = dot(NORMAL, L);
	vec3 base = COLOR.rgb * k_tint.rgb;
	vec3 c = base * mix(0.6, 1.0, step(0.05, nl));
	float sp = pow(max(dot(reflect(-L, NORMAL), VIEW), 0.0), 20.0);
	c += vec3(0.9) * step(0.6, sp) * k_spec;
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	c = mix(c, k_glow.rgb, k_glow.a * smoothstep(0.35, 0.8, fr + max(0.0, -nl) * 0.4));
	ALBEDO = c;
}
"""

const OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float ow = 0.03;
uniform vec4 ocol = vec4(0.08, 0.06, 0.06, 1.0);
void vertex() {
	VERTEX += NORMAL * ow;
}
void fragment() {
	if (length(VERTEX) < 1.2) {
		discard;
	}
	ALBEDO = ocol.rgb;
}
"""

## Yumuşak çakra ışığı (Kishō Tensei avuç kubbesi, altın sütun, ejder gözü): düz cel ton + açık kenar
const GLOW := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.4, 0.65, 1.0, 1.0);
instance uniform float k_a = 1.0;
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float pulse = 0.9 + 0.1 * sin(TIME * 7.0);
	vec3 c = mix(k_col.rgb * 1.25, k_col.rgb * 0.75, smoothstep(0.25, 0.6, f));
	c = mix(c, vec3(1.0), smoothstep(0.85, 1.0, f) * 0.5);
	ALBEDO = c * pulse;
	ALPHA = clamp(k_a * (0.3 + 0.45 * (1.0 - f) + 0.25 * step(0.85, f)) * smoothstep(0.6, 2.5, length(VERTEX)), 0.0, 1.0);
}
"""

## Ceset teni (kaplama): gri-yeşil ölü ten, lekeler, kesikli dikiş izleri
const CORPSE_OV := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform float amt = 0.0;
varying vec3 wp;
NOISE
void vertex() {
	VERTEX += NORMAL * 0.006;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float n = vnz(wp.xz * 5.0 + vec2(wp.y * 3.0));
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(vec3(0.38, 0.44, 0.38), vec3(0.58, 0.63, 0.54), n);
	c *= mix(0.72, 1.0, step(0.35, vnz(wp.xz * 11.0 + vec2(wp.y * 7.0))));
	float sy = abs(fract(wp.y * 1.7 + n * 0.3) - 0.5);
	float seam = step(sy, 0.018) * step(0.5, fract((wp.x + wp.z) * 14.0));
	c = mix(c, vec3(0.16, 0.1, 0.1), seam);
	ALBEDO = c;
	ALPHA = clamp(amt * (0.62 + 0.3 * fr) * smoothstep(0.5, 1.8, length(VERTEX)), 0.0, 1.0);
}
"""

## Deri değiştirme (Fushi Tensei): bedeni saran ak pullu zar, tepeden aşağı soyulur (peel)
const SHED_OV := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform float peel = 0.0;
uniform float base_y = 0.0;
uniform float tall = 1.8;
uniform float amt = 1.0;
varying vec3 wp;
NOISE
void vertex() {
	VERTEX += NORMAL * 0.012;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float yy = (wp.y - base_y) / tall;
	float en = (vnz(wp.xz * 9.0 + vec2(wp.y * 3.0)) - 0.5) * 0.12;
	float cut = 1.0 - peel * 1.15 + en;
	if (yy > cut) {
		discard;
	}
	vec2 sc = vec2(wp.x * 7.0 + wp.z * 7.0, wp.y * 11.0);
	sc.x += step(1.0, mod(floor(sc.y), 2.0)) * 0.5;
	vec2 f = fract(sc) - 0.5;
	float sl = smoothstep(0.36, 0.48, max(abs(f.x), abs(f.y) * 1.2));
	vec3 c = mix(vec3(0.94, 0.93, 0.88), vec3(0.62, 0.6, 0.55), sl);
	c = mix(c, vec3(0.45, 0.42, 0.38), smoothstep(cut - 0.04, cut, yy));
	ALBEDO = c;
	ALPHA = clamp(amt * (0.85 - 0.25 * sl) * smoothstep(0.5, 1.8, length(VERTEX)), 0.0, 1.0);
}
"""


# ================================================================== malzemeler
static func _shd(key: String, code: String, bb := false) -> Shader:
	var k = "shd:" + key
	if _cache.has(k):
		return _cache[k]
	var s = Shader.new()
	s.code = code.replace("NOISE", NOISE).replace("//BB", BBV if bb else "")
	_cache[k] = s
	return s


## Paylaşılan malzeme (örnek parametreleriyle ayrışır)
static func _mat(key: String, code: String, bb := false) -> ShaderMaterial:
	var k = "mat:" + key
	if _cache.has(k):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shd(key, code, bb)
	_cache[k] = m
	return m


## Her çağrıda yeni malzeme (kaplamalar: düz uniform'larla canlandırılır)
static func _fresh(key: String, code: String) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shd(key, code)
	return m


static func _outline(key: String, w: float, col: Color) -> ShaderMaterial:
	var k = "mat:ol_" + key
	if _cache.has(k):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shd("outline", OUTLINE)
	m.set_shader_parameter("ow", w)
	m.set_shader_parameter("ocol", col)
	_cache[k] = m
	return m


static func _cel() -> ShaderMaterial:
	if _cache.has("mat:cel"):
		return _cache["mat:cel"]
	var m = ShaderMaterial.new()
	m.shader = _shd("cel", CEL)
	m.next_pass = _outline("dark", 0.025, Color(0.08, 0.06, 0.06))
	_cache["mat:cel"] = m
	return m


static func _flesh_mat() -> ShaderMaterial:
	if _cache.has("mat:flesh"):
		return _cache["mat:flesh"]
	var m = ShaderMaterial.new()
	m.shader = _shd("cel", CEL)
	m.next_pass = _outline("flesh", 0.03, Color(0.3, 0.1, 0.13))
	_cache["mat:flesh"] = m
	return m


# ================================================================== temel yardımcılar
static func _gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _put(pj: PathJutsu, n: Node3D, pos: Vector3) -> void:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = pos


static func _ipar(mi: GeometryInstance3D, vals: Dictionary) -> void:
	for k in vals:
		mi.set_instance_shader_parameter(k, vals[k])


## Örnek parametresini tween'leyen ayarlayıcı
static func _pf(mi: GeometryInstance3D, key: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(key, v)


static func _basis(d: Vector3) -> Basis:
	var f = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	return Basis.looking_at(f, UP if absf(f.y) < 0.97 else Vector3.RIGHT)


static func _rnd_dir() -> Vector3:
	var a = randf() * TAU
	return Vector3(cos(a), 0.0, sin(a))


static func _rnd3() -> Vector3:
	var v = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized() if v.length() > 0.01 else UP


static func _tri(idx: PackedInt32Array, a: int, b: int, c: int) -> void:
	idx.append(a)
	idx.append(b)
	idx.append(c)


static func _mk(v: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _gate_col(g: int) -> Color:
	if g >= 8:
		return GATE_RED
	if g >= 7:
		return Color(0.35, 0.72, 1.0)
	if g >= 6:
		return Color(0.42, 1.0, 0.78)
	return Color(0.45, 1.0, 0.45)


# ================================================================== geometri
static func _quad() -> QuadMesh:
	if not _cache.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_cache["mesh:quad"] = q
	return _cache["mesh:quad"]


static func _plane() -> PlaneMesh:
	if not _cache.has("mesh:plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(1, 1)
		_cache["mesh:plane"] = p
	return _cache["mesh:plane"]


static func _sphere() -> SphereMesh:
	if not _cache.has("mesh:sphere"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 24
		s.rings = 12
		_cache["mesh:sphere"] = s
	return _cache["mesh:sphere"]


## Çapraz iki şerit (her açıdan görünür): yerel -Z boyunca 0..1, UV.x kuyruk(0)→baş(1)
static func _xstrip() -> ArrayMesh:
	if _cache.has("mesh:xstrip"):
		return _cache["mesh:xstrip"]
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	for q in 2:
		var ax = Vector3(1, 0, 0) if q == 0 else Vector3(0, 1, 0)
		var b0 = v.size()
		for i in 2:
			for j in 2:
				v.append(ax * (float(j) - 0.5) + Vector3(0, 0, -float(i)))
				uv.append(Vector2(float(i), float(j)))
		_tri(idx, b0, b0 + 1, b0 + 3)
		_tri(idx, b0, b0 + 3, b0 + 2)
	var m = _mk(v, uv, idx)
	_cache["mesh:xstrip"] = m
	return m


## Çarpma karesi yıldızı: XY düzleminde düzensiz dikenler + dolu orta (UV.x merkezden uca)
static func _star(n: int) -> ArrayMesh:
	var key = "mesh:star%d" % n
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 1000 + n
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	var r0 = 0.14
	v.append(Vector3.ZERO)
	uv.append(Vector2(0.0, 0.5))
	for i in 16:
		var a = TAU * i / 16.0
		v.append(Vector3(cos(a), sin(a), 0) * r0)
		uv.append(Vector2(0.05, 0.5))
	for i in 16:
		_tri(idx, 0, 1 + i, 1 + (i + 1) % 16)
	for i in n:
		var a = TAU * (i + rng.randf_range(-0.25, 0.25)) / n
		var ln = rng.randf_range(0.5, 1.0)
		var wd = TAU / n * rng.randf_range(0.16, 0.3)
		var b0 = v.size()
		v.append(Vector3(cos(a - wd), sin(a - wd), 0) * r0)
		uv.append(Vector2(0.0, 0.0))
		v.append(Vector3(cos(a + wd), sin(a + wd), 0) * r0)
		uv.append(Vector2(0.0, 1.0))
		v.append(Vector3(cos(a), sin(a), 0) * ln)
		uv.append(Vector2(1.0, 0.5))
		_tri(idx, b0, b0 + 1, b0 + 2)
	var m = _mk(v, uv, idx)
	_cache[key] = m
	return m


## Yatay halka (XZ): iç yarıçap 1-w, dış 1; UV.x açı, UV.y enine
static func _ring(w: float) -> ArrayMesh:
	var key = "mesh:ring%.2f" % w
	if _cache.has(key):
		return _cache[key]
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	var seg = 48
	for i in seg + 1:
		var a = TAU * i / seg
		var d = Vector3(cos(a), 0, sin(a))
		v.append(d * (1.0 - w))
		uv.append(Vector2(float(i) / seg, 0.0))
		v.append(d)
		uv.append(Vector2(float(i) / seg, 1.0))
		if i > 0:
			var b = i * 2
			_tri(idx, b - 2, b - 1, b + 1)
			_tri(idx, b - 2, b + 1, b)
	var m = _mk(v, uv, idx)
	_cache[key] = m
	return m


## Sarmal şerit (Ura Renge'nin dönerek inişi): tepeden (UV.x 0) zemine (1); ağ yerel kökü bot
static func _helix_mesh(top: Vector3, bot: Vector3, r0: float, r1: float, turns: float, w: float, ph: float) -> ArrayMesh:
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	var seg = 64
	for i in seg + 1:
		var f = float(i) / seg
		var a = ph + f * turns * TAU
		var rd = Vector3(cos(a), 0, sin(a))
		var p = top.lerp(bot, f) - bot + rd * lerpf(r0, r1, f)
		v.append(p - rd * w * 0.5)
		uv.append(Vector2(f, 0.0))
		v.append(p + rd * w * 0.5 + UP * w * 0.3)
		uv.append(Vector2(f, 1.0))
		if i > 0:
			var b = i * 2
			_tri(idx, b - 2, b - 1, b + 1)
			_tri(idx, b - 2, b + 1, b)
	return _mk(v, uv, idx)


## Kaya parçası (MB boulder, beyaz köşe rengi → örnek tonu)
static func _chunk(s: float, col: Color) -> MeshInstance3D:
	var vi = randi() % 4
	var key = "mesh:boulder%d" % vi
	if not _cache.has(key):
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3.ONE, Color.WHITE, Vector3.ZERO, vi + 3)
		_cache[key] = b.build()
	var mi = _gi(_cache[key], _cel())
	mi.scale = Vector3(s, s * randf_range(0.6, 1.0), s * randf_range(0.7, 1.1))
	mi.rotation = Vector3(randf(), randf(), randf()) * TAU
	mi.set_instance_shader_parameter("k_tint", col)
	return mi


# ================================================================== yapı taşları (sahnelenen parçalar)
## Hız / ardıl iz şeridi: baştan açılır, kuyruktan söner
static func _streak(pj: PathJutsu, from: Vector3, dir: Vector3, ln: float, w: float, col: Color, edge: Color, life: float, grow := 0.08) -> void:
	var mi = _gi(_xstrip(), _mat("ink", INK))
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D(_basis(dir) * Basis.from_scale(Vector3(w, w, maxf(0.05, ln))), from)
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_a": 1.0, "k_grow": 0.0, "k_tail": 0.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, maxf(0.01, grow))
	tw.tween_method(_pf(mi, "k_tail"), 0.0, 1.6, life)
	tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, life)
	tw.tween_callback(mi.queue_free)


## Çarpma karesi: kameraya dönük düzensiz diken yıldızı, merkezden fışkırır
static func _impact(pj: PathJutsu, at: Vector3, s: float, col: Color, edge: Color, n := 12, life := 0.22) -> void:
	var mi = _gi(_star(n), _mat("ink_bb", INK, true))
	_put(pj, mi, at)
	mi.scale = Vector3.ONE * s
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_a": 1.0, "k_grow": 0.0, "k_tail": 0.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, 0.05)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Şok halkası: nrm eksenine dik, r0 → r1 açılır
static func _shock(pj: PathJutsu, at: Vector3, r0: float, r1: float, w: float, col: Color, edge: Color, life: float, nrm := Vector3.UP) -> void:
	var mi = _gi(_ring(w), _mat("ink", INK))
	pj.get_tree().current_scene.add_child(mi)
	var n = nrm.normalized() if nrm.length() > 0.01 else UP
	var q = Quaternion(UP, n) if UP.dot(n) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	mi.global_transform = Transform3D(Basis(q), at)
	mi.scale = Vector3.ONE * maxf(0.01, r0)
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_a": 1.0, "k_grow": 1.0, "k_tail": 0.0})
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Cel toz topağı (gecikmeli olabilir; zamanlayıcı ağaçtan, atan ölse de temizlenir)
static func _puff(pj: PathJutsu, p: Vector3, s: float, life: float, vel: Vector3, col: Color, delay := 0.0) -> void:
	var mi = _gi(_quad(), _mat("dust", DUST, true))
	_ipar(mi, {"k_col": col, "k_a": 1.0, "k_seed": randf() * 10.0})
	mi.scale = Vector3.ONE * s * 0.4
	var go = func():
		_put(pj, mi, p)
		var tw = mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "global_position", p + vel * life, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
	if delay > 0.0:
		pj.get_tree().create_timer(delay).timeout.connect(go)
	else:
		go.call()


static func _dust_ring(pj: PathJutsu, c: Vector3, r0: float, r1: float, n: int, s: float, life: float, col: Color, up := 0.3) -> void:
	for i in n:
		var a = TAU * i / n + randf() * 0.3
		var d = Vector3(cos(a), 0, sin(a))
		var lf = life * randf_range(0.8, 1.15)
		_puff(pj, c + d * r0 + UP * (0.3 * s), s * randf_range(0.8, 1.2), lf, d * (r1 - r0) / lf + UP * up, col)


## Zemin izi (bkz. DECAL modları); o: dir, w (en oranı), n, c1, c2, grow, lift
static func _decal(pj: PathJutsu, p: Vector3, r: float, mode: int, life: float, o := {}) -> void:
	var mi = _gi(_plane(), _mat("decal", DECAL))
	var d: Vector3 = o.get("dir", Vector3.FORWARD)
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3.FORWARD
	var wf = float(o.get("w", 1.0))
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at(d.normalized(), UP) * Basis.from_scale(Vector3(r * 2.0 * wf, 1.0, r * 2.0)), p + UP * float(o.get("lift", 0.05)))
	_ipar(mi, {"k_col": o.get("c1", Color(0.08, 0.06, 0.05)), "k_col2": o.get("c2", Color(0.45, 0.36, 0.27)), "k_mode": float(mode),
		"k_seed": randf() * 20.0, "k_n": float(o.get("n", 9.0)), "k_a": 1.0, "k_grow": 0.0})
	var gr = float(o.get("grow", 0.18))
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.5, gr).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.05, life - gr - 1.0))
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, 1.0)
	tw.tween_callback(mi.queue_free)


## Fırlatılan parça: parabol, zemine gömülmez, sonunda küçülüp silinir
static func _toss(pj: PathJutsu, mi: Node3D, p0: Vector3, v: Vector3, life: float, g := 20.0, spin := 8.0) -> void:
	_put(pj, mi, p0)
	var ax = (_rnd_dir() + UP * 0.4).normalized()
	var sc0 = mi.scale
	var fl = Game.jutsu_floor(p0.x, p0.z)
	var upd = func(u: float) -> void:
		if not is_instance_valid(mi):
			return
		var p = p0 + v * u + Vector3(0, -0.5 * g * u * u, 0)
		p.y = maxf(p.y, fl + 0.05)
		mi.global_position = p
		mi.rotate(ax, spin * 0.016)
	var tw = mi.create_tween()
	tw.tween_method(upd, 0.0, life, life)
	tw.parallel().tween_property(mi, "scale", sc0 * 0.05, 0.25).set_delay(maxf(0.0, life - 0.25))
	tw.tween_callback(mi.queue_free)


static func _debris(pj: PathJutsu, p: Vector3, n: int, s: float, spd: float, col: Color, up := 0.8, life := 1.0, g := 20.0) -> void:
	for i in n:
		var d = _rnd_dir()
		var v = d * spd * randf_range(0.4, 1.0) + UP * spd * up * randf_range(0.6, 1.2)
		_toss(pj, _chunk(s * randf_range(0.5, 1.2), col), p + d * randf_range(0.2, 0.8) + UP * 0.2, v, life * randf_range(0.8, 1.2), g)


## Zeminden kalkıp havada asılı kalan, sonra düşen kayalar (kapı açılışının basıncı)
static func _float_rocks(pj: PathJutsu, center: Vector3, n: int, r0: float, r1: float, hold: float, col := EARTH_C) -> void:
	for i in n:
		var d = _rnd_dir()
		var p = pj.gp(center + d * randf_range(r0, r1))
		var mi = _chunk(randf_range(0.22, 0.55), col)
		_put(pj, mi, p - UP * 0.2)
		var top = p + UP * randf_range(0.6, 2.2)
		var land = func():
			_puff(pj, p + UP * 0.2, 0.6, 0.5, UP * 0.4, DUST_C)
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", top, 0.4 + randf() * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(mi, "rotation", mi.rotation + _rnd3() * 1.5, 0.6)
		tw.tween_property(mi, "global_position", top + UP * 0.25, maxf(0.1, hold)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "global_position", p, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(land)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.02, 0.4)
		tw.tween_callback(mi.queue_free)


static func _light(pj: PathJutsu, p: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_put(pj, l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


## Yavaş çekim (oyunun zaman ölçeği; kendi kendine geri döner)
static func _slowmo(pj: PathJutsu, sc: float, real_dur: float) -> void:
	if Combat.base_time_scale < 0.99:
		return
	Combat.base_time_scale = sc
	Engine.time_scale = sc
	var back = func():
		if absf(Combat.base_time_scale - sc) < 0.001:
			Combat.base_time_scale = 1.0
	pj.get_tree().create_timer(real_dur, true, false, true).timeout.connect(back)


# ------------------------------------------------------------------ beden kaplaması + buhar parçacığı
## Kaplamayı karakterin kendi ağlarına giydir; önceki kaplama saklanır (geri gelir)
static func _ov_apply(c: Node3D, m: Material) -> Array:
	var out = []
	var mdl = c.get("model") if is_instance_valid(c) else null
	if mdl == null or not is_instance_valid(mdl):
		return out
	for n in (mdl as Node).find_children("*", "MeshInstance3D", true, false):
		var g = n as MeshInstance3D
		if g == null or not g.visible or g.material_overlay == m:
			continue
		out.append([weakref(g), g.material_overlay])
		g.material_overlay = m
	return out


static func _ov_clear(list: Array, m: Material) -> void:
	for e in list:
		var g = e[0].get_ref()
		if g != null and is_instance_valid(g) and g.material_overlay == m:
			g.material_overlay = e[1]


static func _ramp(col: Color) -> Gradient:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.65, 1.0])
	g.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, 0.85), Color(col.r, col.g, col.b, 0.5), Color(col.r, col.g, col.b, 0.0)])
	return g


## Yükselen buhar tutamları (sahneye eklenmeden döner)
static func _mk_steam(col: Color, amount: int, life: float, spd: float, size: float, ext: Vector3) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.mesh = _quad()
	p.material_override = _mat("wisp", WISP, true)
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3.UP
	p.spread = 22.0
	p.initial_velocity_min = spd * 0.5
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, 1.2, 0)
	p.damping_min = 0.8
	p.damping_max = 1.6
	p.scale_amount_min = size * 0.55
	p.scale_amount_max = size
	var sc = Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.5, 0.85))
	sc.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = sc
	p.color_ramp = _ramp(col)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Bedenden sürekli tüten buhar (karakterin çocuğu, dünya uzayında bırakır)
static func _steam_on(c: Node3D, col: Color, amount: int, life: float, spd: float, size: float) -> CPUParticles3D:
	var p = _mk_steam(col, amount, life, spd, size, Vector3(0.3, 0.75, 0.22))
	c.add_child(p)
	p.position = Vector3(0, 1.0, 0)
	return p


## Tek seferlik buhar fışkırması
static func _steam_burst(pj: PathJutsu, pos: Vector3, col: Color, n: int, life: float, spd: float, size: float, ext: Vector3) -> void:
	var p = _mk_steam(col, n, life, spd, size, ext)
	p.one_shot = true
	p.explosiveness = 0.85
	p.spread = 60.0
	_put(pj, p, pos)
	pj.free_after(life + 0.6, p)


static func _stop_free(pj: PathJutsu, p: CPUParticles3D, t: float) -> void:
	var w = weakref(p)
	var stop = func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.emitting = false
			pj.free_after(1.5, x)
	pj.get_tree().create_timer(t).timeout.connect(stop)


## Kısa süreli beden buharı (Yagai hazırlığı, Kishō bedeli). Kapı aurası açıksa onu pompalar.
static func _body_steam(pj: PathJutsu, c: Node3D, col: Color, dur: float, amt := 1.0, wisp := 20) -> void:
	if not is_instance_valid(c):
		return
	var wp = _steam_on(c, col.lightened(0.2), wisp, 0.9, 2.6, 0.8)
	_stop_free(pj, wp, dur)
	if bool(c.get_meta("kfx_gate_on", false)):
		c.set_meta("kfx_gate_pump", 1.5)
		return
	var m = _fresh("steam_ov", STEAM_OV)
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("hot", col.lightened(0.55))
	m.set_shader_parameter("amt", 0.0)
	m.set_shader_parameter("push", 0.04)
	var list = _ov_apply(c, m)
	var setter = func(v: float) -> void:
		m.set_shader_parameter("amt", v)
	var clear = func():
		_ov_clear(list, m)
	var tw = pj.get_tree().create_tween()
	tw.tween_method(setter, 0.0, amt, 0.25)
	tw.tween_interval(maxf(0.05, dur - 0.6))
	tw.tween_method(setter, amt, 0.0, 0.35)
	tw.tween_callback(clear)


# ------------------------------------------------------------------ Sekiz Kapı: gerçek kapı durumunu izleyen beden buharı
## Kapı açıkken (PathJutsu.gate_level) bedene buhar kaplaması + tüten buhar; kapı yükseldikçe renk değişir, kapanınca söner
static func _gate_aura(pj: PathJutsu, c: Node3D) -> void:
	if not is_instance_valid(c) or bool(c.get_meta("kfx_gate_on", false)):
		return
	var g = PathJutsu.gate_level(c)
	if g <= 0:
		return
	var gc = _gate_col(g)
	var m = _fresh("steam_ov", STEAM_OV)
	m.set_shader_parameter("col", gc)
	m.set_shader_parameter("hot", gc.lightened(0.6))
	m.set_shader_parameter("amt", 0.0)
	m.set_shader_parameter("push", 0.035)
	var list = _ov_apply(c, m)
	var wisps = _steam_on(c, gc.lightened(0.3), 22, 1.0, 2.2, 0.8)
	c.set_meta("kfx_gate_on", true)
	c.set_meta("kfx_gate_pump", 1.0)
	var st = {"g": g, "amt": 0.0, "off": false}
	var off = func():
		if st["off"]:
			return
		st["off"] = true
		_ov_clear(list, m)
		if is_instance_valid(wisps):
			wisps.emitting = false
			pj.free_after(1.2, wisps)
		if is_instance_valid(c):
			c.set_meta("kfx_gate_on", false)
	var tick = func(_i, _k):
		if st["off"]:
			return
		if not is_instance_valid(c) or c.is_dead() or PathJutsu.gate_level(c) == 0:
			off.call()
			return
		var gl = PathJutsu.gate_level(c)
		if gl != int(st["g"]):
			st["g"] = gl
			var nc = _gate_col(gl)
			m.set_shader_parameter("col", nc)
			m.set_shader_parameter("hot", nc.lightened(0.6))
			if is_instance_valid(wisps):
				wisps.color_ramp = _ramp(nc.lightened(0.3))
				wisps.amount = 22 + gl * 3
		var pump = float(c.get_meta("kfx_gate_pump", 0.0))
		c.set_meta("kfx_gate_pump", maxf(0.0, pump - 0.12))
		st["amt"] = move_toward(float(st["amt"]), 1.0, 0.2)
		m.set_shader_parameter("amt", float(st["amt"]) * (0.75 + 0.5 * minf(pump, 1.5)))
		m.set_shader_parameter("push", 0.03 + 0.03 * minf(pump, 1.5))
	pj.every(100.0, 0.12, tick, off)


## Kapının bedeli (ana ağaçtaki _gate_cost mekaniği aynen): kapı kapalıysa 1. kapı zorla açılır; görsel: kapı buharı
static func _gate_pay(pj: PathJutsu, c: Node3D, frac: float) -> void:
	if PathJutsu.gate_level(c) < 1:
		if c is Player:
			c.hp = maxf(1.0, c.hp - c.max_hp * frac)
		c.set_meta("gates", 1)
		c.set_meta("gates_until", Game.now() + 8.0)
	_gate_aura(pj, c)
	c.set_meta("kfx_gate_pump", 1.0)


## Kapı yükseltme anı (ana ağaçtaki _gate_burst mekaniği aynen): buhar patlaması, zemin çatlağı, havalanan taşlar
static func _gate_burst(pj: PathJutsu, c: Node3D, g: int) -> void:
	var col = _gate_col(g)
	pj.shake(0.5 + g * 0.08)
	var g0 = pj.gp(c.global_position)
	_gate_aura(pj, c)
	c.set_meta("kfx_gate_pump", 1.6)
	_decal(pj, g0, 3.0 + g * 0.6, 0, 4.0, {"n": 8.0 + g})
	_shock(pj, g0 + UP * 0.15, 0.6, 6.0 + g * 1.5, 0.1, col.lightened(0.5), col.darkened(0.55), 0.5)
	_steam_burst(pj, c.global_position + UP * 1.0, col.lightened(0.25), 18 + g * 2, 0.9, 5.0, 1.1, Vector3(0.4, 0.7, 0.4))
	_float_rocks(pj, g0, 4 + int(g / 2.0), 1.2, 3.5, 0.9)
	_dust_ring(pj, g0, 0.6, 3.5 + g * 0.3, 10, 1.3, 0.8, DUST_C, 0.3)
	Sfx.play("roar", c.global_position, 1.0, 0.5)
	Combat.popup_text(c.global_position + UP * 2.6, "%d. Kapı: %s Kapısı açıldı!" % [g, PathJutsu.GATE_NAMES[g]], col)
	if g >= 8:
		_steam_burst(pj, c.global_position + UP * 0.5, GATE_RED, 30, 1.4, 9.0, 1.4, Vector3(0.3, 0.3, 0.3))
		var until = float(c.get_meta("gates_until", 0.0))
		var cost = func():
			if pj.live(c):   # Ölüm Kapısı kapanınca beden tükenir (kanon: kullanıcı ölür; oyunda can 1, uzun yavaşlık)
				c.hp = 1.0
				pj.st(c, "slow", 15.0)
				Combat.popup_text(c.global_position + UP * 2.4, "Ölüm Kapısı'nın bedeli: beden tükendi", Color(1, 0.4, 0.35))
		pj.after(maxf(0.5, until - Game.now()), cost)


# ================================================================== 1) Ura Renge
## Arka Lotus: üçüncü kapı; hedef havaya fırlar (dikey hız çizgileri), altı vuruş ardıl izlerle zikzak çizer (her biri çarpma
## karesi + yön halkası), son yumrukta iki sarmal şerit dönerek iner, zeminde göçük + çatlak + üç şok halkası + kaya.
static func ura_renge(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	_gate_pay(pj, c, 0.1)
	pj.busy(c, 1.8)
	if tt == null or not pj._lotus_open(c, tt):   # Arka Lotus da havaya kaldırılmış rakibe (Ön Lotus ile aynı şart)
		return
	c.global_position = pj.gp(tt.global_position - pj.fwd(c, tt) * 1.0)
	tt.take_hit(pj.inf(c, "ura_renge", 0.2, {"launch": 16.0, "knock": 0.0, "kind": "heavy"}))
	var red = Color(0.95, 0.32, 0.22)
	var base = pj.gp(tt.global_position)
	for i in 8:   # fırlatış: hedefin çevresinden yukarı uzanan hız çizgileri
		var a = i * TAU / 8.0 + randf() * 0.4
		var o = Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 1.1)
		_streak(pj, base + o + UP * randf_range(0.2, 1.0), UP, randf_range(3.5, 6.0), 0.07, Color(1, 1, 1), Color(0.3, 0.3, 0.36), 0.35, 0.06)
	_dust_ring(pj, base, 0.5, 2.6, 8, 1.1, 0.7, DUST_C, 0.2)
	_decal(pj, base, 1.6, 0, 3.0, {"n": 7.0})
	var last = {"p": c.global_position}
	for k in 6:
		var strike = func():
			if not pj.live(tt) or not pj.live(c):
				return
			var side = Vector3(cos(k * 2.1), 0.4, sin(k * 2.1)) * 1.2
			var from: Vector3 = last["p"]
			c.global_position = tt.global_position + side
			last["p"] = c.global_position
			pj.anim(c, ["jab", "cross", "hook"][k % 3], 2.2)
			var hp = tt.global_position + UP * 0.8
			# ardıl iz: bedenin bir önceki yerinden yenisine
			_streak(pj, from + UP * 1.0, c.global_position - from, maxf(0.5, from.distance_to(c.global_position)), 0.55, Color(0.95, 0.95, 1.0), Color(0.35, 0.38, 0.5), 0.2, 0.03)
			_impact(pj, hp, 1.3 + k * 0.08, Color(1, 1, 0.92), red, 10 + k, 0.2)
			_shock(pj, hp, 0.3, 1.6, 0.25, Color(1, 1, 1), red, 0.2, hp - c.global_position - UP * 1.0)
			Sfx.play("punch", tt.global_position, 1.2 + k * 0.05)
			tt.take_hit(pj.inf(c, "ura_renge", 0.22, {"knock": 0.0, "launch": 2.0, "kind": "light", "hitstop": 0.03}))
		pj.after(0.25 + k * 0.13, strike)
	var finale = func():
		if not pj.live(c):
			return
		var p = pj.gp(tt.global_position if pj.live(tt) else c.global_position)
		var sky: Vector3 = tt.global_position if pj.live(tt) else p + UP * 4.0
		c.global_position = p + UP * 0.2
		if pj.live(tt):
			tt.global_position = p
		pj.anim(c, "cross", 1.4)
		_drill(pj, sky + UP * 0.8, p, red)
		_impact(pj, p + UP * 0.6, 3.2, Color(1, 1, 0.9), red, 16, 0.3)
		var gc2 = Color(0.42, 0.34, 0.26)
		_decal(pj, p, 4.5, 2, 7.0, {"n": 11.0, "c2": gc2})
		_decal(pj, p, 9.0, 0, 7.0, {"n": 13.0, "grow": 0.3})
		for j in 3:
			var r = [5.0, 9.0, 13.0][j]
			var ring = func():
				_shock(pj, p + UP * 0.15, 0.8, r, 0.08, Color(0.9, 0.86, 0.78), Color(0.35, 0.28, 0.2), 0.5)
			pj.get_tree().create_timer(j * 0.07).timeout.connect(ring)
		_dust_ring(pj, p, 1.0, 6.5, 14, 2.2, 1.2, DUST_C, 0.5)
		_debris(pj, p, 18, 0.45, 9.0, EARTH_C, 1.0, 1.3)
		pj.shake(1.3)
		Sfx.play("boom", p, 0.6)
		pj.hit(c, p + UP * 0.6, 4.0, pj.inf(c, "ura_renge", 1.8, {"knock": 12.0, "kind": "heavy"}), [tt] if pj.live(tt) else [])
		if pj.live(tt):   # hedefe kilitli: yere çakılan hedef kaymış olsa da son darbe onu bulur
			tt.take_hit(pj.inf(c, "ura_renge", 1.8, {"knock": 12.0, "kind": "heavy"}))
	pj.after(1.15, finale)


## Dönerek iniş: iki karşılıklı sarmal şerit gökten zemine sarılır, kuyruktan söner
static func _drill(pj: PathJutsu, top: Vector3, bot: Vector3, edge: Color) -> void:
	for h in 2:
		var mi = _gi(_helix_mesh(top, bot, 1.3, 0.35, 3.0, 0.45, h * PI), _mat("ink", INK))
		_put(pj, mi, bot)
		_ipar(mi, {"k_col": Color(1, 0.97, 0.94), "k_edge": edge, "k_a": 1.0, "k_grow": 0.0, "k_tail": 0.0})
		var tw = mi.create_tween()
		tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, 0.12)
		tw.tween_method(_pf(mi, "k_tail"), 0.0, 1.4, 0.45)
		tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, 0.45)
		tw.tween_callback(mi.queue_free)


# ================================================================== 2) Hachimon Tonkō no Jin
## Sekiz Kapı Açılışı: beden kendi ağı üzerinde yeşil buharla tüter (kapı yükseldikçe mavi / kızıl), ayak dibinde yıldız çatlak,
## basınç halkası, zeminden kopup havada asılı kalan taşlar, toz halkası ve yukarı fışkıran buhar sütunu.
static func hachimon_tonko_no_jin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	# kanon: kapılar sırayla açılır. İlk açılış Yaşam Kapısı'na (3) kadar; açıkken tekrar: 6. (Görüş), 7. (Hayret), 8. (Ölüm)
	var cur = PathJutsu.gate_level(c)
	var nxt = 3 if cur < 3 else (6 if cur < 6 else (7 if cur < 7 else 8))
	if cur >= 8:
		return
	if cur > 0:   # kapı yükseltme: kısa bekleme, aynı akış devam eder
		c.set_meta("gates", nxt)
		c.set_meta("gates_until", maxf(float(c.get_meta("gates_until", 0.0)), Game.now() + (14.0 if nxt == 8 else 10.0)))
		_gate_burst(pj, c, nxt)
		if c is Player:
			c.combat.cooldowns["hachimon_tonko_no_jin"] = 1.5
		elif c.get("jcd") is Dictionary:
			c.jcd["hachimon_tonko_no_jin"] = Game.now() + 1.5
		return
	c.set_meta("gates", nxt)
	c.set_meta("gates_until", Game.now() + 25.0)
	if c is Player:
		Combat.popup_text(c.global_position + UP * 2.6, "%d. Kapı: %s Kapısı açıldı!" % [nxt, PathJutsu.GATE_NAMES[nxt]], PathJutsu.GATE_GREEN)
	pj.busy(c, 0.8)
	pj.anim(c, "cast", 1.0)
	pj.shake(0.8)
	Sfx.play("roar", c.global_position, 1.2, 0.6)
	var gc = _gate_col(nxt)
	var g0 = pj.gp(c.global_position)
	_gate_aura(pj, c)
	c.set_meta("kfx_gate_pump", 1.5)
	_decal(pj, g0, 6.0, 0, 6.0, {"n": 10.0, "grow": 0.25})
	_shock(pj, g0 + UP * 0.12, 0.8, 11.0, 0.1, gc.lightened(0.5), gc.darkened(0.55), 0.55)
	_shock(pj, g0 + UP * 1.0, 0.5, 4.0, 0.2, Color(1, 1, 1), gc.darkened(0.4), 0.3)
	_dust_ring(pj, g0, 0.8, 5.5, 12, 1.6, 1.0, DUST_C, 0.35)
	_float_rocks(pj, g0, 12, 1.5, 4.5, 1.4)
	_steam_burst(pj, c.global_position + UP * 0.8, gc.lightened(0.3), 34, 1.2, 7.0, 1.2, Vector3(0.35, 0.6, 0.35))
	_light(pj, c.global_position + UP * 1.2, gc, 4.0, 8.0, 0.8)
	var mdl = c.get("model")
	var skin_mats = []
	if mdl:
		var ratio: Color = mdl._skin_ratio()
		for sm in mdl.materials:
			if sm is ShaderMaterial and sm.get_shader_parameter("tint") == ratio:
				skin_mats.append(sm)
				sm.set_shader_parameter("tint", ratio * Color(1.15, 0.78, 0.72))   # kapılar açıkken ten kızarır
	if c is Player:
		Buffs.add("hachimon", 25.0, {"melee": 1.55, "speed": 1.25, "_name": "Sekiz Kapı Açık", "_desc": "her sn canın %1.5'i erir"})
	var drain = func(_i, _k):
		if pj.live(c):
			var gl = PathJutsu.gate_level(c)
			if gl == 0:
				return
			# açık kapı başına can akışı (8. kapı: ölüm kapısı, hızla yakar)
			var dr = 0.0015 * gl + (0.01 if gl >= 8 else 0.0)
			c.hp = maxf(1.0, c.hp - c.max_hp * dr)
	var restore = func():
		if mdl and is_instance_valid(mdl):
			for sm in skin_mats:
				sm.set_shader_parameter("tint", mdl._skin_ratio())
	pj.every(25.0, 0.4, drain, restore)


# ================================================================== 3) Asakujaku
## Sabah Tavuskuşu: kullanıcının arkasında tavuskuşu kuyruğu gibi yarım daire açan damla alev tüyleri (uçları dışa), arkada
## ışınsal hız çizgileri; sonra yumruklar o yelpazeden alev topu + ısı kuyruğu olarak hedefe yağar, değdiği yerde alev sıçrar.
static func asakujaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_gate_pay(pj, c, 0.12)
	pj.busy(c, 1.6)
	var d = pj.fwd(c, t)
	var right = d.cross(UP).normalized()
	var tt = pj.tg(c, t, 18.0)
	var aim_at = (tt.global_position + UP * 1.0) if tt else c.global_position + d * 12.0 + UP
	var fans: Array = []
	for k in 22:
		var a = lerpf(-1.35, 1.35, k / 21.0)   # yarım daire
		var r = 2.2 + (k % 3) * 0.6
		var off = (right * sin(a) + UP * cos(a)) * r - d * 0.6
		fans.append(off)
	for k in fans.size():
		var spawn = func():
			if not pj.live(c):
				return
			var q = c.global_position + UP * 1.3 + fans[k]
			_feather(pj, q, fans[k] + d * 0.6, d, 0.5 - k * 0.012)
		pj.after(0.015 * k, spawn)
	_light(pj, c.global_position + UP * 1.5, Color(1.0, 0.6, 0.2), 8.0, 14.0, 1.2)
	var lines = func():
		if not pj.live(c):
			return
		var ctr = c.global_position + UP * 1.3 - d * 0.8
		for i in 12:
			var a = randf_range(-1.6, 1.6)
			var od = (right * sin(a) + UP * cos(a)).normalized()
			_streak(pj, ctr + od * 3.6, od, randf_range(2.5, 4.5), 0.06, Color(0.86, 0.97, 1.0), Color(0.3, 0.6, 0.75), 0.45, 0.08)
	pj.after(0.1, lines)
	for k in fans.size():
		var punch = func():
			if not pj.live(c):
				return
			pj.anim(c, "jab" if k % 2 == 0 else "cross", 2.8)
			var from = c.global_position + UP * 1.3 + (fans[k] as Vector3) * 0.6
			# her yumruk atıldığı an hedefin ŞİMDİKİ yerine + kaçış yönüne nişan alır
			var aim_now = aim_at
			if pj.live(tt):
				var tv: Vector3 = tt.velocity if "velocity" in tt else Vector3.ZERO
				aim_now = tt.global_position + UP * 1.0 + Vector3(tv.x, 0, tv.z) * (from.distance_to(tt.global_position) / 44.0)
			var target = aim_now + right * randf_range(-0.9, 0.9) + UP * randf_range(-0.5, 0.8)
			var on_hit = func(hp, _h):
				_flare(pj, hp)
			pj.shot(c, from, (target - from).normalized(), 44.0, _fist_flame(), pj.inf(c, "asakujaku", 0.16, {"element": "katon", "burn": 1.5, "knock": 2.0, "kind": "light"}), null, false, 0.6, on_hit)
			if k % 4 == 0:
				Sfx.play("fire", from, 1.4, 0.4)
				_light(pj, from, Color(1.0, 0.55, 0.15), 3.0, 6.0, 0.25)
		pj.after(0.55 + k * 0.035, punch)


## Yelpazedeki tek alev tüyü: kameraya (arkaya) bakan damla alev, ucu merkezden dışa
static func _feather(pj: PathJutsu, q: Vector3, off: Vector3, d: Vector3, hold: float) -> void:
	var mi = _gi(_quad(), _mat("flame", FLAME))
	pj.get_tree().current_scene.add_child(mi)
	var z = -d.normalized()
	var y = off - z * off.dot(z)
	y = y.normalized() if y.length() > 0.01 else UP
	var x = y.cross(z).normalized()
	var bas = Basis(x, y, z)
	var full = Vector3(1.0, 1.9, 1.0) * randf_range(0.85, 1.15)
	mi.global_transform = Transform3D(bas * Basis.from_scale(full * 0.1), q)
	_ipar(mi, {"k_a": 1.0, "k_seed": randf() * 10.0, "k_round": 0.0})
	var setsc = func(u: float) -> void:
		if is_instance_valid(mi):
			mi.global_transform = Transform3D(bas * Basis.from_scale(full * u), q)
	var tw = mi.create_tween()
	tw.tween_method(setsc, 0.1, 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.05, hold))
	tw.tween_method(setsc, 1.0, 0.2, 0.2)
	tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, 0.2)
	tw.tween_callback(mi.queue_free)


## Yumruk mermisi: yuvarlak alev topu + arkasında incelen ısı kuyruğu (mermi -Z'ye bakar)
static func _fist_flame() -> Node3D:
	var root = Node3D.new()
	var ball = _gi(_quad(), _mat("flame_bb", FLAME, true))
	ball.scale = Vector3.ONE * 0.95
	ball.set_instance_shader_parameter("k_round", 1.0)
	ball.set_instance_shader_parameter("k_seed", randf() * 10.0)
	root.add_child(ball)
	var tail = _gi(_xstrip(), _mat("ink", INK))
	tail.position = Vector3(0, 0, 2.4)
	tail.scale = Vector3(0.5, 0.5, 2.4)
	tail.set_instance_shader_parameter("k_col", Color(1.0, 0.75, 0.2))
	tail.set_instance_shader_parameter("k_edge", Color(0.85, 0.22, 0.05))
	tail.set_instance_shader_parameter("k_tail", 1.0)
	root.add_child(tail)
	return root


## Yumruk değdiği yer: turuncu çarpma yıldızı + dört yana sıçrayan alev dilleri
static func _flare(pj: PathJutsu, hp: Vector3) -> void:
	_impact(pj, hp, 0.9, Color(1.0, 0.92, 0.55), Color(0.85, 0.25, 0.05), 9, 0.16)
	for i in 4:
		var mi = _gi(_quad(), _mat("flame_bb", FLAME, true))
		_ipar(mi, {"k_a": 1.0, "k_seed": randf() * 10.0, "k_round": 0.4})
		mi.scale = Vector3.ONE * randf_range(0.35, 0.6)
		_put(pj, mi, hp)
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", hp + _rnd3() * 1.2 + UP * 0.6, 0.3).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, 0.3)
		tw.tween_callback(mi.queue_free)


# ================================================================== 4) Sekizō
## Akşam Fili: beş yumruğun her biri öne uzanan, yumrukta dar uçta geniş beyaz hava basıncı sütunu (parlak kontur, akan
## çizgiler) atar; sütunlar çaprazlanıp X çizer. Yumrukta hava halkası + çarpma karesi, zeminde sütun boyunca yarık ve toz.
static func sekizo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_gate_pay(pj, c, 0.2)
	pj.busy(c, 2.0)
	var d = pj.fwd(c, t)
	var right = d.cross(UP).normalized()
	for k in 5:
		var punch = func():
			if not pj.live(c):
				return
			pj.anim(c, "cross" if k % 2 == 0 else "jab", 2.0)
			var o = c.global_position + UP * 1.3 + d * 0.8
			var yaw = [-11.0, 11.0, -5.0, 6.0, 0.0][k]
			var pitch = [5.0, -4.0, -7.0, 6.0, 0.0][k]
			var dd = d.rotated(UP, deg_to_rad(yaw)).rotated(right, deg_to_rad(pitch)).normalized()
			var L = 34.0 + k * 2.0
			var col = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.7
			cm.bottom_radius = 2.0
			cm.height = L
			cm.radial_segments = 18
			col.mesh = cm
			col.material_override = _mat("air", AIR)
			col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pj.get_tree().current_scene.add_child(col)
			# silindir ekseni (+Y) sütun yönüne; dar uç yumrukta, geniş uç ileride
			var yax = -dd
			var xax = yax.cross(UP).normalized()
			if xax.length() < 0.1:
				xax = Vector3.RIGHT
			var zax = xax.cross(yax).normalized()
			col.global_transform = Transform3D(Basis(xax, yax, zax), o + dd * L * 0.5)
			col.scale = Vector3(0.2, 1.0, 0.2)
			col.set_instance_shader_parameter("k_a", 0.9)
			var tw = col.create_tween()
			tw.tween_property(col, "scale", Vector3(1.0, 1.0, 1.0), 0.08)
			tw.tween_interval(0.25)
			tw.tween_property(col, "scale", Vector3(0.05, 1.0, 0.05), 0.5).set_ease(Tween.EASE_IN)
			tw.parallel().tween_method(_pf(col, "k_a"), 0.9, 0.0, 0.5)
			tw.tween_callback(col.queue_free)
			_impact(pj, o, 2.2, Color(1, 1, 1), Color(0.45, 0.48, 0.55), 14, 0.2)
			_shock(pj, o + dd * 0.6, 0.5, 3.2, 0.3, Color(1, 1, 1), Color(0.5, 0.55, 0.62), 0.25, dd)
			_shock(pj, o + dd * 3.0, 1.0, 4.5, 0.18, Color(0.95, 0.97, 1.0), Color(0.5, 0.55, 0.62), 0.3, dd)
			var fd = Vector3(dd.x, 0, dd.z).normalized()
			var gnd = pj.gp(c.global_position + fd * 9.0)
			_decal(pj, gnd, 8.0, 1, 5.0, {"dir": -fd, "w": 0.22, "grow": 0.12})
			for j in 4:
				var q = pj.gp(c.global_position + fd * (3.0 + j * 3.5))
				_puff(pj, q + UP * 0.3, 1.2 + j * 0.2, 0.7, fd * 3.0 + UP * 0.6, DUST_C, j * 0.03)
			_debris(pj, pj.gp(o + dd * 8.0), 8, 0.35, 8.0, EARTH_C, 0.9, 1.0)
			pj.shake(0.6 + k * 0.12)
			Sfx.play("boom", o, 1.2 - k * 0.08, 0.6)
			Combat.hit_zone(c, c.global_position + UP * 0.4, dd, L, 10.0, 5.0, pj.inf(c, "sekizo", 0.75, {"knock": 16.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.05}))
		pj.after(0.2 + k * 0.3, punch)


# ================================================================== 5) Yagai
## Gece Gayı: beden kızıl buharla tüter; tek tekmede kızıl buhar EJDER biçimini alır (sarı parlayan çekik gözler, boynuzlar,
## dişli ağız, akan girdap çizgileri), yol boyunca uzay merceklenip bükülür, kayalar havaya kalkar, zemin uzun yarıkla açılır.
## Bedeli: canın %10'a iner, 12 sn bitkin (yavaş)
static func yagai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 1.8)
	pj.anim(c, "crouch", 0.8)
	_body_steam(pj, c, GATE_RED, 2.1, 1.2, 30)
	var g0 = pj.gp(c.global_position)
	_decal(pj, g0, 2.5, 0, 4.0, {"n": 9.0, "grow": 0.6})
	_float_rocks(pj, g0, 8, 1.0, 3.0, 0.5, Color(0.5, 0.32, 0.3))
	Sfx.play("roar", c.global_position, 0.6)
	pj.shake(1.0)
	var kick = func():
		if not pj.live(c):
			return
		var d = pj.fwd(c, tt)
		var start = c.global_position
		var dist = 26.0 if tt == null else c.global_position.distance_to(tt.global_position) + 6.0
		var end = pj.gp(start + d * dist)
		_dragon(pj, start, end, d)
		for k in 5:   # uzay bükülmesi: yol boyunca merceklenen küreler
			_warp(pj, start.lerp(end, (k + 0.5) / 5.0) + UP * 1.6, 3.0 + k * 0.5, 0.15 + k * 0.05)
		var mid = pj.gp(start.lerp(end, 0.5))
		_decal(pj, mid, dist * 0.5, 1, 6.0, {"dir": d, "w": 0.1, "grow": 0.25, "c1": Color(0.12, 0.04, 0.03)})
		for k in 10:   # yol boyunca havaya kalkan kayalar
			var q = pj.gp(start.lerp(end, k / 9.0))
			_debris(pj, q, 3, 0.55, 3.5, Color(0.5, 0.3, 0.28), 2.6, 1.5, 9.0)
			if k % 3 == 0:
				_decal(pj, q, 2.5, 0, 5.0, {"n": 8.0, "c1": Color(0.15, 0.04, 0.03)})
		c.global_position = end
		pj.anim(c, "dash", 1.4)
		Combat.hit_zone(c, start, d, dist, 10.0, 4.0, pj.inf(c, "yagai", 6.0, {"knock": 30.0, "launch": 10.0, "kind": "heavy", "hitstop": 0.2}))
		_slowmo(pj, 0.35, 0.6)
		_shock(pj, end + UP * 0.2, 1.0, 16.0, 0.08, Color(1.0, 0.6, 0.55), Color(0.45, 0.06, 0.05), 0.6)
		_shock(pj, end + UP, 0.6, 7.0, 0.25, Color(1, 1, 1), GATE_RED, 0.35, d)
		_impact(pj, end + UP, 4.0, Color(1.0, 0.92, 0.88), Color(0.75, 0.1, 0.08), 18, 0.35)
		_dust_ring(pj, end, 1.0, 7.0, 12, 2.0, 1.1, Color(0.75, 0.55, 0.5), 0.6)
		_light(pj, end + UP * 1.5, Color(1.0, 0.35, 0.25), 6.0, 16.0, 0.8)
		pj.shake(2.0)
		Sfx.play("boom", end, 0.4)
		if c is Player:
			c.hp = minf(c.hp, c.max_hp * 0.1)
			pj.st(c, "slow", 12.0)
			Hud.msg("Gece Gayı'nın bedeli: bedenin tükendi.", Color(1, 0.4, 0.4))
	pj.after(0.9, kick)


## Kızıl buhar ejderi: kıvrılan gövde tüpü + kafatası, burun, açık çene, boynuz, diş; sarı çekik gözler
static func _dragon(pj: PathJutsu, start: Vector3, end: Vector3, d: Vector3) -> void:
	var side = d.cross(UP).normalized()
	var pts: Array = []
	var rads: Array = []
	for k in 12:
		var f = k / 11.0
		pts.append(start.lerp(end, f) + UP * (1.4 + sin(f * 7.0) * 1.2 + f * 1.5) + side * sin(f * 5.5) * 2.2)
		rads.append(lerpf(0.4, 1.6, f))
	var b = MB.new()
	Loft.tube(b, pts, rads, Color(1, 1, 1), 14, 3, false, false)
	var head: Vector3 = pts[-1]
	var hd = ((pts[-1] as Vector3) - (pts[-2] as Vector3)).normalized()
	var hs = hd.cross(UP).normalized()
	Loft.blob(b, head + hd * 0.6, hd, 3.6, [1.6, 1.85, 1.5, 0.9], Color(1, 1, 1), 14)   # kafatası
	Loft.blob(b, head + hd * 2.4 - UP * 0.2, hd, 2.0, [1.1, 1.0, 0.7], Color(1, 1, 1), 12)   # burun
	Loft.blob(b, head + hd * 2.0 - UP * 1.2, (hd - UP * 0.35).normalized(), 2.2, [0.8, 0.85, 0.5], Color(1, 1, 1), 12)   # açık alt çene
	var hb = _basis(hd)
	for sx in [-1.0, 1.0]:
		b.add("cone", head + UP * 1.6 + hs * sx * 0.9 - hd * 0.6, Vector3(0.45, 2.4, 0.45), Color(1, 1, 1), Vector3(-30, 0, sx * 25), 6)   # boynuz
		b.add("cone", head + UP * 0.6 + hs * sx * 1.5 - hd * 0.2, Vector3(0.3, 1.4, 0.3), Color(1, 1, 1), Vector3(0, 0, sx * 70), 5)   # yan diken
		for f in 3:   # dişler
			var tp = head + hd * (2.2 + f * 0.35) + hs * sx * (0.55 - f * 0.12) - UP * 0.6
			b.add_xf("cone", Transform3D(hb * Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(0.18, 0.55, 0.18)), tp), Color(1, 1, 1), 5)
	var mi = _gi(b.build(), _mat("dragon", DRAGON))
	pj.get_tree().current_scene.add_child(mi)
	mi.set_instance_shader_parameter("k_a", 0.0)
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_a"), 0.0, 1.0, 0.1)
	tw.tween_interval(0.7)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, 0.6)
	tw.tween_callback(mi.queue_free)
	for sx in [-1.0, 1.0]:   # sarı parlayan çekik gözler
		var e = _gi(_sphere(), _mat("glow", GLOW))
		_put(pj, e, head + hd * 1.6 + UP * 0.7 + hs * sx * 0.75)
		e.global_basis = hb * Basis(Vector3.BACK, sx * 0.35) * Basis.from_scale(Vector3(0.8, 0.32, 0.4))
		_ipar(e, {"k_col": Color(1.0, 0.85, 0.25), "k_a": 1.0})
		var et = e.create_tween()
		et.tween_interval(1.0)
		et.tween_method(_pf(e, "k_a"), 1.0, 0.0, 0.4)
		et.tween_callback(e.queue_free)


static func _warp(pj: PathJutsu, p: Vector3, r: float, delay: float) -> void:
	var go = func():
		var mi = _gi(_sphere(), _mat("warp", WARP))
		_put(pj, mi, p)
		mi.scale = Vector3.ONE * r * 0.5
		mi.set_instance_shader_parameter("k_a", 1.0)
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * r * 2.0, 0.5).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	pj.get_tree().create_timer(delay).timeout.connect(go)


# ================================================================== 6) Shihōhappō Shuriken
## Her Yöne Şuriken: klonlar hedefin çevresine yukarıdan düşen hız çizgileri ve toz halkasıyla iner; her biri çelik dört
## kanatlı dev şuriken (etrafında dönen rüzgâr halkası) fırlatır; ortada çelik çarpışma kıvılcımları, altı yönlü kesik izi.
static func shihohappo_shuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 20.0)
	if tt == null:
		return
	var at = tt.global_position
	for k in 6:
		var a = k * TAU / 6.0
		var q = pj.gp(at + Vector3(cos(a), 0, sin(a)) * 6.0)
		_clone_drop(pj, q)
		pj.decoy(c, q, 1.6)
		var throw = func():
			if not pj.live(c):
				return
			var from = q + UP * 1.4
			var dir = (at + UP - from).normalized()
			var pr = pj.shot(c, from, dir, 26.0, _shuriken(), pj.inf(c, "shihohappo_shuriken", 0.6, {"knock": 4.0, "kind": "heavy", "element": "fuuton", "bleed": 2.0}), null, false, 0.5)
			pr.spin = Vector3(0, 30, 0)
			_streak(pj, from - dir * 0.6, dir, 1.6, 0.35, Color(0.9, 0.97, 1.0), Color(0.4, 0.55, 0.65), 0.2, 0.04)
		pj.after(0.5, throw)
	var clash = func():
		_clash(pj, at + UP)
		pj.hit(c, at + UP, 4.0, pj.inf(c, "shihohappo_shuriken", 1.2, {"knock": 10.0, "kind": "heavy", "element": "fuuton", "bleed": 3.0}))
		pj.shake(0.8)
	pj.after(0.75, clash)
	Sfx.play("wind", c.global_position, 1.0)


## Klon inişi: yukarıdan düşen hız çizgileri, ayak dibinde toz halkası
static func _clone_drop(pj: PathJutsu, q: Vector3) -> void:
	for i in 4:
		var o = _rnd_dir() * randf_range(0.2, 0.6)
		_streak(pj, q + o + UP * randf_range(3.0, 4.5), -UP, randf_range(2.0, 3.0), 0.06, Color(1, 1, 1), Color(0.35, 0.38, 0.45), 0.25, 0.05)
	_dust_ring(pj, q, 0.3, 1.8, 6, 0.9, 0.5, DUST_C, 0.15)


## Dev çelik şuriken: dört sivri kanat + koyu göbek (yerel XZ düzleminde; mermi Y çevresinde döner) + rüzgâr halkası
static func _shuriken() -> Node3D:
	var root = Node3D.new()
	if not _cache.has("mesh:shuriken"):
		var b = MB.new()
		var steel = Color(0.6, 0.63, 0.7)
		for j in 4:
			var yaw = j * 90.0
			var dv = Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
			b.add("cone", dv * 0.45, Vector3(0.36, 0.75, 0.07), steel, Vector3(90, yaw, 0), 4)
			b.add("cone", dv * 0.2 + dv.cross(UP) * 0.12, Vector3(0.2, 0.35, 0.06), steel.darkened(0.2), Vector3(90, yaw + 35.0, 0), 4)
		b.add("cyl", Vector3.ZERO, Vector3(0.34, 0.1, 0.34), Color(0.3, 0.32, 0.36), Vector3.ZERO, 10)
		b.add("cyl", Vector3.ZERO, Vector3(0.14, 0.12, 0.14), Color(0.1, 0.1, 0.12), Vector3.ZERO, 8)
		_cache["mesh:shuriken"] = b.build()
	var body = _gi(_cache["mesh:shuriken"], _cel())
	body.scale = Vector3.ONE * 1.3
	body.set_instance_shader_parameter("k_spec", 1.0)
	root.add_child(body)
	var wind = _gi(_ring(0.35), _mat("ink", INK))
	wind.scale = Vector3.ONE * 1.25
	wind.set_instance_shader_parameter("k_col", Color(0.88, 0.97, 1.0))
	wind.set_instance_shader_parameter("k_edge", Color(0.45, 0.65, 0.78))
	wind.set_instance_shader_parameter("k_a", 0.45)
	root.add_child(wind)
	return root


## Altı şurikenin ortada buluşması: kıvılcım çizgileri, çarpma yıldızı, rüzgâr halkası, kesik izi, çelik kırıntıları
static func _clash(pj: PathJutsu, p: Vector3) -> void:
	for i in 16:
		var dv = _rnd3()
		_streak(pj, p + dv * 0.3, dv, randf_range(1.2, 2.6), 0.05, Color(1.0, 0.97, 0.75), Color(0.95, 0.55, 0.15), 0.25, 0.04)
	_impact(pj, p, 2.6, Color(1, 1, 1), Color(0.35, 0.55, 0.75), 14, 0.25)
	_shock(pj, p, 0.5, 5.5, 0.12, Color(0.88, 0.97, 1.0), Color(0.4, 0.6, 0.75), 0.4)
	var g = pj.gp(p)
	_decal(pj, g, 4.5, 7, 5.0, {"n": 6.0, "grow": 0.1})
	_debris(pj, p, 8, 0.12, 6.0, Color(0.55, 0.58, 0.64), 0.6, 0.8)
	_dust_ring(pj, g, 0.5, 4.0, 8, 1.2, 0.6, DUST_C, 0.2)


# ================================================================== 7) Ōdama Rasen Tairengan
## Büyük Toplu Seri Rasengan: klonlar çakra kıvılcımıyla belirir, ellerinde dönen sarmal çizgili dev Rasengan (yörünge
## halkaları); bölgeye dalıp yere sürterler: dönen öğütme kubbesi, zeminde sarmal oyuk, kum rengi toz, kaya.
static func odama_rasen_tairengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.8)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	for k in 10:
		var a = k * TAU / 10.0
		var q = pj.gp(c.global_position + Vector3(cos(a), 0, sin(a)) * 3.0)
		_clone_flicker(pj, q + UP)
		var cl = pj.decoy(c, q, 2.0)
		if cl:
			var r = _rasen_ball()
			cl.add_child(r)
			r.position = UP * 1.2 + Vector3(0, 0, 0.6)
			_rasen_live(r)
			var land = at + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			var tw = cl.create_tween()
			tw.tween_interval(0.5 + k * 0.08)
			tw.tween_property(cl, "global_position", land + UP * 4.0, 0.3)
			tw.tween_property(cl, "global_position", pj.gp(land), 0.2)
			var boom = func():
				_rasen_grind(pj, pj.gp(land))
				pj.hit(c, pj.gp(land) + UP, 3.5, pj.inf(c, "odama_rasen_tairengan", 0.8, {"knock": 14.0, "launch": 5.0, "kind": "heavy"}))
				cl.queue_free()
			tw.tween_callback(boom)
	Sfx.play("wind", c.global_position, 0.6)


## Klon belirişi (duman yok): mavi-beyaz çakra yıldızı + dikey halka
static func _clone_flicker(pj: PathJutsu, p: Vector3) -> void:
	_impact(pj, p, 1.1, Color(0.9, 0.96, 1.0), Color(0.3, 0.5, 0.9), 8, 0.18)
	_shock(pj, p - UP * 0.9, 0.2, 1.4, 0.2, Color(0.85, 0.94, 1.0), Color(0.3, 0.5, 0.9), 0.3)


## Rasengan: sarmal küre + iki çapraz yörünge halkası (dönüş _rasen_live ile, ağaca girdikten sonra)
static func _rasen_ball() -> Node3D:
	var root = Node3D.new()
	var core = _gi(_sphere(), _mat("rasen", RASEN))
	core.scale = Vector3.ONE * 1.0
	root.add_child(core)
	for i in 2:
		var ring = _gi(_ring(0.12), _mat("ink", INK))
		ring.name = "orbit%d" % i
		ring.scale = Vector3.ONE * 0.62
		ring.rotation = Vector3(0.6 if i == 0 else -0.7, 0.0, 0.4 if i == 0 else -0.5)
		ring.set_instance_shader_parameter("k_col", Color(0.92, 0.97, 1.0))
		ring.set_instance_shader_parameter("k_edge", Color(0.25, 0.45, 0.95))
		ring.set_instance_shader_parameter("k_a", 0.85)
		root.add_child(ring)
	return root


static func _rasen_live(r: Node3D) -> void:
	for i in 2:
		var ring = r.get_node_or_null("orbit%d" % i) as Node3D
		if ring == null or not ring.is_inside_tree():
			continue
		var tw = ring.create_tween().set_loops()
		tw.tween_property(ring, "rotation:y", TAU * (1.0 if i == 0 else -1.0), 0.22).as_relative()


## Yere sürtme: genişleyip dönen öğütme kubbesi, sarmal oyuk, kum tozu, kaya, yatay şok
static func _rasen_grind(pj: PathJutsu, p: Vector3) -> void:
	var dome = _gi(_sphere(), _mat("rasen", RASEN))
	_put(pj, dome, p + UP * 0.3)
	dome.scale = Vector3.ONE * 0.5
	dome.set_instance_shader_parameter("k_a", 1.0)
	var tw = dome.create_tween()
	tw.tween_property(dome, "scale", Vector3(3.4, 2.6, 3.4), 0.15).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(dome, "rotation:y", TAU, 0.45).as_relative()
	tw.tween_interval(0.2)
	tw.tween_property(dome, "scale", Vector3(4.0, 0.4, 4.0), 0.25).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(dome, "k_a"), 1.0, 0.0, 0.25)
	tw.tween_callback(dome.queue_free)
	_decal(pj, p, 3.2, 3, 6.0, {"c1": Color(0.12, 0.09, 0.07), "c2": Color(0.5, 0.4, 0.3), "grow": 0.3})
	_shock(pj, p + UP * 0.15, 1.0, 5.5, 0.1, Color(0.85, 0.94, 1.0), Color(0.3, 0.45, 0.85), 0.4)
	for i in 5:
		var dv = _rnd_dir()
		_puff(pj, p + dv * 1.2 + UP * 0.6, randf_range(1.6, 2.4), 1.1, dv * 3.0 + UP * 0.8, SAND_C, 0.12)
	_debris(pj, p, 6, 0.35, 7.0, EARTH_C, 1.1, 1.0)
	pj.shake(0.35)


# ================================================================== 8) Tajū Kage Bunshin no Jutsu
## Çoklu Gölge Klonu: gerçek klonlar "pon" bulutuyla belirir; çevreyi yüzlerce klondan bir kalabalık (tek MultiMesh, dövüş
## duruşunda siluetler) dalga dalga, sıçrayarak doldurur, birkaç saniye sonra hepsi pon diye dağılır.
static func taju_kage_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var at = c.global_position
	for k in 16:
		var a = k * TAU / 16.0 + randf() * 0.3
		var r = randf_range(2.5, 7.0)
		var q = pj.gp(at + Vector3(cos(a) * r, 0, sin(a) * r))
		var spawn = func():
			_pon(pj, q + UP)
			pj.decoy(c, q, 8.0)
		pj.after(k * 0.03, spawn)
	_crowd(pj, pj.gp(at))
	for e in pj.enemies_near(c, at, 14.0):
		pj.st(e, "slow", 3.0)
	Sfx.play("poof", at, 0.8)


## Kanon "pon": küçük ak bulut + çevreye seken kısa çizgiler
static func _pon(pj: PathJutsu, p: Vector3) -> void:
	_puff(pj, p, 1.5, 0.45, UP * 0.6, Color(0.96, 0.97, 1.0))
	for i in 6:
		var dv = (_rnd_dir() + UP * randf_range(-0.3, 0.6)).normalized()
		_streak(pj, p + dv * 0.7, dv, 0.8, 0.05, Color(1, 1, 1), Color(0.45, 0.48, 0.55), 0.18, 0.04)


static func _figure_mesh() -> ArrayMesh:
	if _cache.has("mesh:figure"):
		return _cache["mesh:figure"]
	var b = MB.new()
	var suit = Color(0.2, 0.23, 0.32)
	var vest = Color(0.36, 0.42, 0.3)
	var skin = Color(0.94, 0.78, 0.66)
	var hair = Color(0.14, 0.11, 0.1)
	var metal = Color(0.72, 0.74, 0.78)
	b.add("cyl", Vector3(-0.16, 0.44, 0.08), Vector3(0.16, 0.9, 0.16), suit, Vector3(14, 0, -8), 6)
	b.add("cyl", Vector3(0.16, 0.44, -0.12), Vector3(0.16, 0.9, 0.16), suit, Vector3(-18, 0, 8), 6)
	b.add("box", Vector3(-0.17, 0.03, 0.14), Vector3(0.15, 0.08, 0.28), suit)
	b.add("box", Vector3(0.17, 0.03, -0.2), Vector3(0.15, 0.08, 0.28), suit)
	b.add("box", Vector3(0, 0.9, 0), Vector3(0.42, 0.16, 0.26), suit)
	b.add("box", Vector3(0, 1.17, 0), Vector3(0.5, 0.5, 0.3), vest, Vector3(-8, 0, 0))
	b.add("sphere", Vector3(0, 1.62, -0.03), Vector3(0.32, 0.36, 0.33), skin, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, 1.71, 0.03), Vector3(0.36, 0.26, 0.36), hair, Vector3.ZERO, 10)
	for k in 5:
		b.add("cone", Vector3(-0.14 + k * 0.07, 1.78, 0.1), Vector3(0.1, 0.24, 0.1), hair, Vector3(-40 + k * 3, 0, -30 + k * 15), 5)
	b.add("box", Vector3(0, 1.66, -0.17), Vector3(0.3, 0.07, 0.03), metal)
	# kollar: sol yumruk önde, sağ geri çekilmiş (dövüş duruşu)
	b.add("cyl", Vector3(-0.32, 1.22, -0.22), Vector3(0.12, 0.55, 0.12), suit, Vector3(-75, 0, 10), 6)
	b.add("sphere", Vector3(-0.34, 1.26, -0.5), Vector3(0.14, 0.14, 0.14), skin, Vector3.ZERO, 6)
	b.add("cyl", Vector3(0.33, 1.1, 0.08), Vector3(0.12, 0.55, 0.12), suit, Vector3(30, 0, -20), 6)
	b.add("sphere", Vector3(0.4, 0.88, 0.2), Vector3(0.14, 0.14, 0.14), skin, Vector3.ZERO, 6)
	var m = b.build()
	_cache["mesh:figure"] = m
	return m


## Yüzlerce klonluk kalabalık: siluetler + belirme / dağılma bulutları (iki MultiMesh, ~24 Hz güncelleme)
static func _crowd(pj: PathJutsu, center: Vector3) -> void:
	var n = 110
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _figure_mesh()
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _cel()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm = MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.use_colors = true
	pm.mesh = _quad()
	pm.instance_count = n
	var pmi = MultiMeshInstance3D.new()
	pmi.multimesh = pm
	pmi.material_override = _mat("pon", PON, true)
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sc = pj.get_tree().current_scene
	sc.add_child(mmi)
	sc.add_child(pmi)
	mmi.global_transform = Transform3D.IDENTITY
	pmi.global_transform = Transform3D.IDENTITY
	var pos = []
	var bas = []
	var tin = []
	var tout = []
	var sz = []
	for i in n:
		var a = randf() * TAU
		var r = randf_range(8.0, 18.0)
		pos.append(pj.gp(center + Vector3(cos(a) * r, 0, sin(a) * r)))
		var o = Vector3(cos(a), 0, sin(a)).rotated(UP, randf_range(-0.6, 0.6))
		bas.append(Basis.looking_at(o, UP))
		tin.append(0.05 + (r - 8.0) / 10.0 * 0.45 + randf() * 0.15)
		tout.append(3.2 + randf() * 0.9)
		sz.append(randf_range(0.92, 1.08))
	var t0 = Time.get_ticks_msec()
	var tick = func(_i, _k):
		if not is_instance_valid(mmi) or not is_instance_valid(pmi):
			return
		var T = (Time.get_ticks_msec() - t0) / 1000.0
		for i in n:
			var ti = float(tin[i])
			var to = float(tout[i])
			var a_in = clampf((T - ti) / 0.14, 0.0, 1.0)
			var a_out = clampf((T - to) / 0.08, 0.0, 1.0)
			var s = a_in * (1.0 - a_out) * float(sz[i])
			var hop = sin(clampf((T - ti) / 0.4, 0.0, 1.0) * PI) * 0.7
			var b: Basis = bas[i]
			var p: Vector3 = pos[i]
			mm.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3.ONE * maxf(s, 0.001)), p + UP * hop))
			var ps = 0.001
			var pa = 0.0
			for ev in [ti, to]:
				var u = (T - float(ev)) / 0.35
				if u >= 0.0 and u <= 1.0:
					ps = 1.3 + u * 0.9
					pa = 1.0 - u
			pm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * ps), p + UP * 1.0))
			pm.set_instance_color(i, Color(1, 1, 1, pa))
	var done = func():
		if is_instance_valid(mmi):
			mmi.queue_free()
		if is_instance_valid(pmi):
			pmi.queue_free()
	tick.call(0, 0.0)
	pj.every(4.6, 1.0 / 24.0, tick, done)


# ================================================================== 9) Gōjō Kibaku Fuda
## Çoğalan Patlayıcı Etiketler: elden çıkan etiket uçarken ikiye, dörde... bölünür (her yeni etiket atasının havadaki
## yerinden doğar), bölgeyi halı gibi kaplar, dış halkada dikilip duvar olur; etiketler mühür yanarak tutuşur, her
## patlama loblu cel ateş topu + yatay şok + is izi + kâğıt külü.
static func gojo_kibaku_fuda(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	var tags = _tag_swarm(pj, pj.hand_pos(c, true), at)
	for k in 18:
		var blast = func():
			var q = pj.gp(at + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
			_tag_blast(pj, q, tags, k % 3 == 0)
			if k % 4 == 0:
				pj.shake(0.8)
			pj.hit(c, q + UP, 3.5, pj.inf(c, "gojo_kibaku_fuda", 0.4, {"knock": 12.0, "launch": 5.0, "kind": "heavy", "element": "katon"}))
		pj.after(0.9 + k * 0.06, blast)
	Sfx.play("wind", c.global_position, 1.2)


static func _tag_mesh() -> QuadMesh:
	if not _cache.has("mesh:tag"):
		var q = QuadMesh.new()
		q.size = Vector2(0.3, 0.76)
		_cache["mesh:tag"] = q
	return _cache["mesh:tag"]


static func _tag_swarm(pj: PathJutsu, hand: Vector3, at: Vector3) -> Dictionary:
	var n = 140
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _tag_mesh()
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat("tag", TAG)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.get_tree().current_scene.add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY
	var st = {"t0": Time.get_ticks_msec(), "te": [], "fl": [], "land": [], "start": [], "began": [], "mid": [], "pos": [], "burn": [], "spin": [], "rest": []}
	var lg = log(float(n)) / log(2.0)
	for i in n:
		st["te"].append(0.02 + 0.62 * (log(float(i + 1)) / log(2.0)) / lg)   # nesil nesil ikiye bölünme
		st["fl"].append(randf_range(0.38, 0.52))
		var a = randf() * TAU
		var rr = sqrt(randf()) * 6.5
		var upright = rr > 5.0 and randf() < 0.7   # dış halkada dikilen etiketler: kâğıt duvar
		var L = pj.gp(at + Vector3(cos(a) * rr, 0, sin(a) * rr)) + UP * (0.38 if upright else 0.04)
		st["land"].append(L)
		st["start"].append(hand)
		st["began"].append(false)
		st["mid"].append(Vector3.ZERO)
		st["pos"].append(hand)
		st["burn"].append(-1.0)
		st["spin"].append(Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))
		var rb: Basis
		if upright:
			var inw = Vector3(at.x - L.x, 0, at.z - L.z)
			rb = Basis.looking_at(inw.normalized() if inw.length() > 0.01 else Vector3.FORWARD, UP) * Basis(Vector3.RIGHT, deg_to_rad(randf_range(-12, 12)))
		else:
			rb = Basis(UP, randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(-90.0 + randf_range(-12, 12)))
		st["rest"].append(rb)
	var tick = func(_i, _k):
		if not is_instance_valid(mmi):
			return
		var T = (Time.get_ticks_msec() - int(st["t0"])) / 1000.0
		for i in n:
			var te = float(st["te"][i])
			var burn = 0.0
			var xf = Transform3D(Basis.from_scale(Vector3.ONE * 0.001), hand)
			if T >= te:
				if not bool(st["began"][i]):
					st["began"][i] = true
					var par = int((i - 1) / 2.0)
					var sp: Vector3 = hand
					if i > 0 and float(st["te"][par]) <= T and T < float(st["te"][par]) + float(st["fl"][par]):
						sp = st["pos"][par]
					st["start"][i] = sp
					var L0: Vector3 = st["land"][i]
					st["mid"][i] = (sp + L0) * 0.5 + UP * randf_range(1.2, 3.0) + _rnd_dir() * randf_range(0.0, 1.5)
				var u = clampf((T - te) / float(st["fl"][i]), 0.0, 1.0)
				var s0: Vector3 = st["start"][i]
				var m0: Vector3 = st["mid"][i]
				var L1: Vector3 = st["land"][i]
				var p = s0.lerp(m0, u).lerp(m0.lerp(L1, u), u)
				st["pos"][i] = p
				var b: Basis = st["rest"][i]
				if u < 1.0:
					var sv: Vector3 = st["spin"][i]
					b = Basis.from_euler(sv * (T - te))
				var vis = 1.0
				var bt = float(st["burn"][i])
				if bt >= 0.0 and T >= bt:
					burn = clampf((T - bt) / 0.12, 0.0, 1.0)
					if T - bt > 0.14:
						vis = 0.001
				xf = Transform3D(b * Basis.from_scale(Vector3.ONE * vis), p)
			mm.set_instance_transform(i, xf)
			mm.set_instance_custom_data(i, Color(burn, 0, 0, 0))
		if T > 2.05:   # patlamadan kalan etiketler de tutuşup kaybolur
			for i in n:
				if float(st["burn"][i]) < 0.0:
					st["burn"][i] = T + randf() * 0.15
	var done = func():
		if is_instance_valid(mmi):
			mmi.queue_free()
	tick.call(0, 0.0)
	pj.every(2.5, 1.0 / 30.0, tick, done)
	return st


static func _tag_blast(pj: PathJutsu, q: Vector3, st: Dictionary, lit: bool) -> void:
	var T = (Time.get_ticks_msec() - int(st["t0"])) / 1000.0
	var lands: Array = st["land"]
	for i in lands.size():
		if float(st["burn"][i]) < 0.0 and (lands[i] as Vector3).distance_to(q) < 3.2:
			st["burn"][i] = T + randf() * 0.06
	var s = randf_range(1.4, 1.9)
	var p = q + UP * 0.6
	var mi = _gi(_sphere(), _mat("blast", BLAST))
	_put(pj, mi, p)
	mi.scale = Vector3.ONE * s * 0.3
	_ipar(mi, {"k_t": 0.0, "k_seed": randf() * 30.0})
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * s * 2.4, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * s * 2.9, 0.45)
	tw.parallel().tween_method(_pf(mi, "k_t"), 0.0, 1.0, 0.45).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mi, "global_position", p + UP * 0.9, 0.45)
	tw.tween_callback(mi.queue_free)
	_shock(pj, q + UP * 0.12, 0.6, s * 3.2, 0.14, Color(1.0, 0.85, 0.5), Color(0.55, 0.2, 0.06), 0.35)
	_decal(pj, q, s * 1.5, 5, 6.0, {"c1": Color(0.07, 0.05, 0.04), "c2": Color(0.25, 0.16, 0.1), "grow": 0.1})
	_debris(pj, p, 4, 0.12, 6.0, Color(0.2, 0.17, 0.15), 1.0, 0.9)
	if lit:
		_light(pj, p, Color(1.0, 0.6, 0.2), 5.0, 9.0, 0.35)


# ================================================================== 10) Kishō Tensei
## Kendi Yaşamıyla Diriltme: yerde yeşil-sarı kesikli halkalar dalga dalga açılır, avuçlarda saydam mavi çakra kubbesi;
## diriliş anında düşmüş dostun yerinde altın ışık sütunu, kullanıcıdan ona akan altın yaşam zerreleri, kullanıcının
## bedeninden yaşam buharı çekilir.
static func kisho_tensei(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.8)
	var green = Color(0.45, 0.95, 0.55)
	var at = pj.gp(c.global_position)
	for k in 4:
		var ring = func():
			_decal(pj, at, 3.0 + k * 1.5, 4, 2.6, {"c1": Color(0.78, 1.0, 0.32), "n": 3.0, "grow": 0.6, "lift": 0.06 + k * 0.01})
		pj.after(k * 0.3, ring)
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba:
			_palm_glow(ba, 1.6)
			pj.free_after(1.6, ba)
	# kanon (Chiyo): kendi yaşam gücünü verip yakında düşen BİR dostu diriltir — kendini iyileştirmez
	var now = Time.get_ticks_msec() / 1000.0
	var tgt = null
	for f in Enemy.fallen:
		if String(f["team"]) == String(c.team) and now - float(f["t"]) < 120.0 and (f["pos"] as Vector3).distance_to(c.global_position) < 70.0:
			tgt = f
			break
	if tgt == null:
		if c is Player:
			Hud.msg("Diriltecek düşmüş bir dost yok.", Color(1, 0.7, 0.5))
			c.combat.cooldowns.erase("kisho_tensei")   # boşa harcanmasın
		return
	var revive = func():
		if not pj.live(c):
			return
		var e = Enemy.new()
		e.setup(tgt["arch"])
		e.team = tgt["team"]
		e.set_meta("respawn", false)
		if tgt["teammate"]:
			e.set_meta("teammate", true)
			if String(tgt["friend_id"]) != "":
				e.set_meta("friend_id", tgt["friend_id"])
		pj.get_tree().current_scene.add_child(e)
		e.global_position = pj.gp(tgt["pos"])
		_life_column(pj, e.global_position)
		_life_thread(pj, c.global_position + UP * 1.1, e.global_position + UP * 1.0)
		_body_steam(pj, c, GOLD, 1.6, 0.8, 16)
		Combat.popup_text(e.global_position + UP * 2.6, "Dirildi", green)
		Enemy.fallen.erase(tgt)
		if c is Player:   # bedel: yaşam gücü verildi
			c.hp = 1.0
			Buffs.add("rinne_bedel", 60.0, {"speed": 0.7, "melee": 0.7, "no_heal": 1.0, "_name": "Yaşam Bedeli", "_desc": "yaşam gücünü verdin: iyileşemezsin"})
		else:
			c.hp = 1.0
	pj.after(1.4, revive)
	Sfx.play("heal", c.global_position, 0.5)


## Avuçta saydam mavi çakra kubbesi (kemiğe iliştirilir, kemikle birlikte silinir)
static func _palm_glow(ba: Node3D, life: float) -> void:
	var mi = _gi(_sphere(), _mat("glow", GLOW))
	ba.add_child(mi)
	mi.scale = Vector3.ONE * 0.1
	_ipar(mi, {"k_col": Color(0.35, 0.6, 1.0), "k_a": 0.9})
	if not mi.is_inside_tree():
		mi.scale = Vector3.ONE * 0.7
		return
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 0.75, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.05, life - 0.65))
	tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.3)


## Dirilen dostun yerinde altın ışık sütunu + yükselen zerreler + altın halka
static func _life_column(pj: PathJutsu, p: Vector3) -> void:
	var cm = CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.7
	cm.height = 7.0
	cm.radial_segments = 20
	cm.cap_top = false
	cm.cap_bottom = false
	var mi = _gi(cm, _mat("glow", GLOW))
	_put(pj, mi, p + UP * 3.5)
	mi.scale = Vector3(0.2, 1.0, 0.2)
	_ipar(mi, {"k_col": GOLD, "k_a": 0.0})
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "k_a"), 0.0, 0.85, 0.25)
	tw.tween_interval(0.8)
	tw.tween_property(mi, "scale", Vector3(0.05, 1.2, 0.05), 0.6).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(mi, "k_a"), 0.85, 0.0, 0.6)
	tw.tween_callback(mi.queue_free)
	var mp = CPUParticles3D.new()
	mp.mesh = _quad()
	mp.material_override = _mat("mote", MOTE, true)
	mp.amount = 28
	mp.lifetime = 1.4
	mp.one_shot = true
	mp.explosiveness = 0.6
	mp.local_coords = false
	mp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mp.emission_sphere_radius = 0.9
	mp.direction = Vector3.UP
	mp.spread = 20.0
	mp.initial_velocity_min = 1.5
	mp.initial_velocity_max = 4.0
	mp.gravity = Vector3(0, 0.5, 0)
	mp.scale_amount_min = 0.12
	mp.scale_amount_max = 0.25
	mp.color_ramp = _ramp(GOLD)
	mp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(pj, mp, p + UP * 0.4)
	pj.free_after(2.2, mp)
	_decal(pj, p, 2.6, 4, 2.4, {"c1": GOLD, "n": 2.0, "grow": 0.4})


## Yaşam akışı: kullanıcıdan dosta kavis çizerek akan altın zerreler
static func _life_thread(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var mid = (a + b) * 0.5 + UP * clampf(a.distance_to(b) * 0.15, 1.0, 5.0)
	for i in 14:
		var mi = _gi(_quad(), _mat("mote", MOTE, true))
		mi.set_instance_shader_parameter("k_col", GOLD)
		mi.scale = Vector3.ONE * randf_range(0.18, 0.3)
		var jit = _rnd3() * 0.35
		var fly = func():
			_put(pj, mi, a)
			var path = func(u: float) -> void:
				if is_instance_valid(mi):
					mi.global_position = a.lerp(mid, u).lerp(mid.lerp(b, u), u) + jit * sin(u * PI)
			var tw = mi.create_tween()
			tw.tween_method(path, 0.0, 1.0, 0.6).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(mi, "scale", Vector3.ONE * 0.02, 0.15)
			tw.tween_callback(mi.queue_free)
		pj.get_tree().create_timer(i * 0.05).timeout.connect(fly)


# ================================================================== 11) Fushi Tensei
## Yaşayan Ceset Reenkarnasyonu: kullanıcının çevresinde zeminden pembe, parlak, topak topak et kütleleri kabarır; aralarından
## et dilleri ve ak yılanlar yükselip kıvrılır; bedeni saran ak pullu deri tepeden aşağı soyulur (yeni beden), sonra kütleler
## toprağa geri çekilir. Mekanik: dönüşüm güçlendirmesi (jutsu motorunun aynı formülü).
static func fushi_tensei(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("fushi_tensei", {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 10.0 + tier * 3.0
	var mods = {"armor": maxf(0.5, 0.9 - 0.06 * tier), "melee": 1.05 + 0.04 * tier}
	Buffs.add(String(d.get("id", "buff")), dur, mods)
	_flesh_mass(pj, c)
	_shed_skin(pj, c)
	_decal(pj, pj.gp(c.global_position), 2.6, 6, 4.0, {"c1": Color(0.3, 0.12, 0.15), "c2": Color(0.5, 0.3, 0.32), "grow": 0.4})
	if c is Player:
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], Color(0.9, 0.7, 0.75))
	Sfx.play("seal", c.global_position, 0.8)


static func _flesh_mass(pj: PathJutsu, c: Node3D) -> void:
	var cp = pj.gp(c.global_position)
	var fm = _flesh_mat()
	for k in 11:
		var a = k * TAU / 11.0 + randf_range(-0.2, 0.2)
		var rr = randf_range(1.0, 2.0)
		var base = pj.gp(cp + Vector3(cos(a), 0, sin(a)) * rr)
		var b = MB.new()
		var nl = randi_range(3, 5)
		for j in nl:
			var o = Vector3(randf_range(-0.35, 0.35), j * 0.35 + randf() * 0.15, randf_range(-0.35, 0.35))
			var s = randf_range(0.55, 0.9) * (1.0 - j * 0.12)
			b.add("sphere", o, Vector3(s, s * 0.85, s), FLESH_COLS[randi() % 3], Vector3.ZERO, 12)
		if k % 3 == 0:   # et dili ya da ak yılan
			var pts = []
			var rad = []
			var wd = _rnd_dir()
			for s in 6:
				var f = s / 5.0
				pts.append(Vector3(0, 0.6 + f * 2.0, 0) + wd * sin(f * 2.5) * 0.7)
				rad.append(lerpf(0.22, 0.09, f))
			var white = (k % 2 == 0)
			Loft.tube(b, pts, rad, SNAKE_C if white else FLESH_COLS[1], 10, 3, false, true)
			if white:
				var tip: Vector3 = pts[-1]
				b.add("sphere", tip + wd * 0.12, Vector3(0.26, 0.18, 0.34), SNAKE_C, Vector3(0, rad_to_deg(atan2(wd.x, wd.z)), 0), 10)
				for sx in [-1.0, 1.0]:
					b.add("sphere", tip + wd * 0.2 + wd.cross(UP) * sx * 0.09 + UP * 0.06, Vector3(0.05, 0.05, 0.05), Color(0.7, 0.15, 0.1), Vector3.ZERO, 6)
		var mi = _gi(b.build(), fm)
		mi.set_instance_shader_parameter("k_spec", 1.0)
		_put(pj, mi, base - UP * 0.2)
		mi.rotation.y = randf() * TAU
		mi.scale = Vector3(0.8, 0.02, 0.8)
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.03)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(1.06, 0.95, 1.06), 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "scale", Vector3(0.97, 1.04, 0.97), 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.6)
		tw.tween_property(mi, "scale", Vector3(0.9, 0.02, 0.9), 0.4).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


static func _shed_skin(pj: PathJutsu, c: Node3D) -> void:
	var m = _fresh("shed_ov", SHED_OV)
	m.set_shader_parameter("peel", 0.0)
	m.set_shader_parameter("base_y", c.global_position.y)
	m.set_shader_parameter("tall", 1.9)
	m.set_shader_parameter("amt", 0.0)
	var list = _ov_apply(c, m)
	var amt = func(v: float) -> void:
		m.set_shader_parameter("amt", v)
	var peel = func(v: float) -> void:
		m.set_shader_parameter("peel", v)
	var clear = func():
		_ov_clear(list, m)
	var flakes = func():
		if is_instance_valid(c):
			_debris(pj, c.global_position + UP * 1.2, 10, 0.1, 2.5, SNAKE_C, 0.6, 1.0)
	var tw = pj.get_tree().create_tween()
	tw.tween_method(amt, 0.0, 1.0, 0.3)
	tw.tween_interval(0.3)
	tw.tween_callback(flakes)
	tw.tween_method(peel, 0.0, 1.0, 1.0)
	tw.tween_callback(clear)


# ================================================================== 12) Shikabane Bunshin no Jutsu
## Ceset Klonu: önde zemin ıslak lekeyle kararır, toprak kesekleri fırlar; senin kılığındaki ceset (gerçek klon) topraktan
## yükselir, teni gri-yeşil ölü ten ve dikiş izleriyle kaplıdır, parmaklarından ona ince çakra iplikleri uzanır. Vurulunca
## duman yerine çöker: gri-yeşil pullar dökülür, yerde leke kalır.
static func shikabane_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var at = pj.gp(c.global_position + c.face_dir() * 2.0)
	_decal(pj, at, 1.7, 6, 8.0, {"c1": Color(0.1, 0.12, 0.09), "c2": Color(0.26, 0.28, 0.21), "grow": 0.35})
	_decal(pj, at, 1.4, 0, 6.0, {"n": 7.0})
	_debris(pj, at, 8, 0.18, 3.0, EARTH_C, 1.2, 0.8)
	_dust_ring(pj, at, 0.3, 1.6, 5, 0.8, 0.6, Color(0.55, 0.58, 0.5), 0.2)
	var pop = func(pos):
		_corpse_fall(pj, pos)
	var dc = pj.decoy(c, at, 10.0, pop)
	if dc:
		dc.set_meta("no_smoke", true)   # ceset dumana dönüşmez, çöker
		var mdl = dc.get("model")
		if mdl and is_instance_valid(mdl) and mdl.is_inside_tree():
			var y0 = mdl.position.y
			mdl.position.y = y0 - 1.5
			var tw = mdl.create_tween()
			tw.tween_property(mdl, "position:y", y0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_corpse_skin(pj, dc, 10.0)
		_corpse_threads(pj, c, dc, 1.4)
	Sfx.play("poof", at, 0.9)


## Ölü ten kaplaması (model parça parça kurulabilir: iki kez giydirilir)
static func _corpse_skin(pj: PathJutsu, dc: Node3D, dur: float) -> void:
	var m = _fresh("corpse_ov", CORPSE_OV)
	m.set_shader_parameter("amt", 0.85)
	var lists = []
	var wear = func():
		if is_instance_valid(dc):
			lists.append_array(_ov_apply(dc, m))
	var clear = func():
		_ov_clear(lists, m)
	wear.call()
	pj.get_tree().create_timer(0.4).timeout.connect(wear)
	pj.get_tree().create_timer(dur).timeout.connect(clear)


## Parmaklardan cesede uzanan ince çakra iplikleri (her karede iki uç yenilenir)
static func _corpse_threads(pj: PathJutsu, c: Node3D, dc: Node3D, dur: float) -> void:
	var strands = []
	for i in 3:
		var mi = _gi(_xstrip(), _mat("ink", INK))
		pj.get_tree().current_scene.add_child(mi)
		_ipar(mi, {"k_col": Color(0.78, 0.92, 1.0), "k_edge": Color(0.4, 0.6, 0.8), "k_a": 0.9, "k_grow": 1.0, "k_tail": 0.0})
		strands.append(mi)
	var upd = func(_i, k):
		if not is_instance_valid(c) or not is_instance_valid(dc):
			return
		var a = pj.hand_pos(c, true)
		var b = dc.global_position + UP * 1.3
		for j in strands.size():
			var mi = strands[j]
			if not is_instance_valid(mi):
				continue
			var off = Vector3(0, (j - 1) * 0.18, 0)
			var dv = b + off - a
			mi.global_transform = Transform3D(_basis(dv) * Basis.from_scale(Vector3(0.025, 0.025, maxf(0.05, dv.length()))), a)
			mi.set_instance_shader_parameter("k_a", 0.9 * (1.0 - float(k)))
	var done = func():
		for mi in strands:
			if is_instance_valid(mi):
				mi.queue_free()
	upd.call(0, 0.0)
	pj.every(dur, 1.0 / 30.0, upd, done)


## Ceset çöküşü: gri-yeşil pullar, alçak mezar tozu, ıslak leke
static func _corpse_fall(pj: PathJutsu, pos: Vector3) -> void:
	var g = pj.gp(pos)
	_debris(pj, pos + UP * 0.8, 12, 0.12, 2.2, Color(0.5, 0.56, 0.48), 0.5, 0.9)
	_dust_ring(pj, g, 0.2, 1.4, 5, 0.9, 0.7, Color(0.5, 0.54, 0.46), 0.1)
	_decal(pj, g, 1.3, 6, 6.0, {"c1": Color(0.1, 0.12, 0.09), "c2": Color(0.24, 0.27, 0.2)})
