class_name KurabuFXA
extends RefCounted
## Kurama (Yakumo'nun resim genjutsusu) + Aburame (kikaichū) grubu A:
## Raiga, Enga, Dangai, Ido, Ingen Shibari, Kokū Rakka, Hakuchūmu, Gakaku Hōkai, Mushi Bunshin, Kidaichū Mushikui,
## Mushi Kame (mushi_kabe), Mushiheki, Mushimayu, Kodoku, Dokujin.
## Kurama: şövaledeki tuvale fırça darbeleri sürülür (her teknikte kendi resmi), boya kurbana uçar, resim gerçek olur:
## tırtıklı fırça kenarlı, koyu mürekkep çizgili boyalı şimşek / yanan ev / uçurum / boşluk / sarmaşık / çerçeve / tuval.
## Yanılsama yalnız kurbanın çevresinde; kurbanın başında dönen boya lekeleri genjutsu altında olduğunu gösterir.
## Aburame: tek MultiMesh'li böcek sürüsü (BugSwarm: bulut / kabuk / beden / sürünme / duvar / örgü / akış / dağılma
## kipleri) + her tekniğin kendi kütlesi (taneli kara küre, tırtıklı duvar, ipek koza, mühür yazılı kubbe, zehir bulutu).
## Tüm görseller bu dosyada sıfırdan (kendi shader'ları, kendi geometri ve parçacık ayarları). Kameraya yakın kısımlar
## titreşimli (dither) söner, hiçbir parça ekranı kaplamaz.
## Oynanış ana ağaçtaki işleyicilerden satır satır taşındı: Eyes.genjutsu_land, durumlar, decoy, attach, Buffs, Enemy.fallen.

static var _cache := {}

const INK := Color(0.08, 0.06, 0.09)
const WOOD := Color(0.34, 0.21, 0.11)


# ================================================================== shader'lar
const NOISE := """
float kh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float kn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(kh(i), kh(i + vec2(1.0, 0.0)), f.x), mix(kh(i + vec2(0.0, 1.0)), kh(i + vec2(1.0, 1.0)), f.x), f.y);
}
float nearf(vec3 v, float a, float b) { return smoothstep(a, b, length(v)); }
"""

## Fırça darbesi: kılçıklı tırtıklı kenar, uçta kalkan fırça, mürekkep kenar çizgisi, boyanarak beliren ön
const SH_PAINT := """
uniform float u_reveal = 1.0;
uniform float u_ink = 0.85;
uniform float u_flow = 0.0;
uniform float u_wob = 0.0;
uniform float u_core = 0.0;
instance uniform float u_fade = 1.0;
void vertex() {
	if (u_wob > 0.0) {
		VERTEX.x += sin(TIME * 7.0 + VERTEX.y * 3.0) * u_wob * UV.x;
		VERTEX.z += cos(TIME * 6.0 + VERTEX.y * 2.5) * u_wob * UV.x;
	}
}
void fragment() {
	float br = kn(vec2(UV.x * 34.0 - TIME * u_flow, UV.y * 7.0));
	float edge = abs(UV.y - 0.5) * 2.0;
	float lim = 0.78 + br * 0.22 - smoothstep(0.85, 1.0, UV.x) * (1.0 - br) * 0.9;
	if (edge > lim) { discard; }
	float front = u_reveal * 1.15 - UV.x - kn(UV * vec2(5.0, 9.0)) * 0.15;
	if (front < 0.0) { discard; }
	vec3 col = COLOR.rgb * (0.82 + br * 0.3);
	col = mix(col, vec3(1.0, 0.98, 0.86), u_core * (1.0 - smoothstep(0.0, 0.45, edge)));
	float ink = smoothstep(lim - 0.22, lim - 0.04, edge) * u_ink;
	col = mix(col, vec3(0.08, 0.06, 0.09), ink);
	ALBEDO = col;
	if (kh(floor(FRAGCOORD.xy)) > u_fade * COLOR.a * nearf(VERTEX, 0.45, 1.8)) { discard; }
}
"""

## Cel kütle: toon ışık, kenarda mürekkep, yerden yükselerek (u_clip) ya da boy boyu (u_reveal) belirme
const SH_CEL := """
uniform float u_clip = 999.0;
uniform float u_reveal = 99.0;
uniform float u_ink = 0.9;
uniform float u_stripe = 0.0;
uniform vec4 u_emit : source_color = vec4(0.0, 0.0, 0.0, 0.0);
instance uniform float u_fade = 1.0;
varying vec3 op;
void vertex() { op = VERTEX; }
void fragment() {
	float rag = kn(op.xz * 6.0) * 0.25;
	if (op.y > u_clip + rag) { discard; }
	if (UV.x > u_reveal) { discard; }
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 col = COLOR.rgb;
	if (u_stripe > 0.0) { col = mix(col, col * 1.4, step(0.78, fract(UV.y * 2.0 + UV.x * u_stripe))); }
	col = mix(col, vec3(0.06, 0.04, 0.07), smoothstep(0.62, 0.8, fr) * u_ink);
	ALBEDO = col;
	float band = 1.0 - smoothstep(0.0, 0.2, u_clip + rag - op.y);
	EMISSION = u_emit.rgb * u_emit.a + vec3(0.55, 0.3, 0.8) * band * step(u_clip, 900.0);
	if (kh(floor(FRAGCOORD.xy)) > u_fade * nearf(VERTEX, 0.45, 1.8)) { discard; }
}
"""

## Kikaichū: koyu parlak kabuk, kenarda soğuk parıltı
const SH_BUG := """
uniform vec4 u_tint : source_color = vec4(0.07, 0.07, 0.06, 1.0);
uniform vec4 u_glint : source_color = vec4(0.4, 0.42, 0.46, 1.0);
instance uniform float u_fade = 1.0;
void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = mix(u_tint.rgb * COLOR.rgb, u_glint.rgb, pow(fr, 3.0) * 0.6);
	ROUGHNESS = 0.3;
	METALLIC = 0.2;
	if (kh(floor(FRAGCOORD.xy)) > u_fade * nearf(VERTEX, 0.3, 1.2)) { discard; }
}
"""

## Kokū Rakka: yırtık kâğıt kenarlı boşluk; içinde dönen fırça girdabı ve yıldız benekleri
const SH_VOID := """
instance uniform float u_fade = 1.0;
void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float sw = kn(vec2(a * 3.0 + log(r + 0.05) * 6.0 - TIME * 1.5, r * 4.0));
	vec3 col = mix(vec3(0.02, 0.01, 0.05), vec3(0.24, 0.13, 0.4), smoothstep(0.55, 0.9, sw) * smoothstep(0.0, 0.8, r));
	vec2 sq = q * 22.0;
	float st = kh(floor(sq));
	float star = step(0.93, st) * (1.0 - smoothstep(0.0, 0.2, length(fract(sq) - 0.5))) * (0.6 + 0.4 * sin(TIME * 6.0 + st * 40.0));
	float rim = smoothstep(0.86, 0.9, r);
	col += vec3(0.85, 0.8, 1.0) * star * (1.0 - r) * (1.0 - rim);
	col = mix(col, vec3(0.06, 0.04, 0.09), smoothstep(0.81, 0.85, r) * (1.0 - rim));
	col = mix(col, vec3(0.93, 0.88, 0.76) * (0.85 + kn(q * 30.0) * 0.2), rim);
	ALBEDO = col;
	if (kh(floor(FRAGCOORD.xy)) > u_fade * nearf(VERTEX, 0.45, 1.8)) { discard; }
}
"""

## Dangai: boyalı uçurum ağzı — kenarda kaya katmanları, ortada dipsiz karanlık
const SH_CHASM := """
instance uniform float u_fade = 1.0;
void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float strata = kn(vec2(a * 9.0, r * 6.0));
	vec3 rock = vec3(0.36, 0.38, 0.47) * (0.75 + strata * 0.35);
	vec3 col = mix(vec3(0.015, 0.012, 0.03), rock, smoothstep(0.25, 0.85, r));
	float ridge = smoothstep(0.86, 1.0, kn(vec2(a * 14.0 + r * 3.0, 1.7)));
	col = mix(col, vec3(0.05, 0.05, 0.08), ridge * smoothstep(0.3, 0.8, r));
	col = mix(col, vec3(0.06, 0.05, 0.08), smoothstep(0.88, 0.93, r));
	ALBEDO = col;
	if (kh(floor(FRAGCOORD.xy)) > u_fade * nearf(VERTEX, 0.45, 1.8)) { discard; }
}
"""

## Enga: alttan yanan shoji kâğıdı (kafes, kömürleşen kenar, kor çizgisi, açılan delikler)
const SH_PAPER := """
uniform float u_burn = 0.0;
instance uniform float u_fade = 1.0;
void fragment() {
	vec2 uv = UV;
	float grid = max(step(0.93, fract(uv.x * 3.0 + 0.035)), step(0.93, fract(uv.y * 4.0 + 0.035)));
	float n = kn(uv * vec2(6.0, 5.0)) * 0.6 + kn(uv * 17.0) * 0.4;
	float bf = u_burn * 1.5 - (1.0 - uv.y) - n * 0.45;
	if (bf > 0.12 + grid * 0.35) { discard; }
	vec3 col = mix(vec3(0.93, 0.86, 0.68), vec3(0.3, 0.17, 0.08), grid);
	float ch = smoothstep(-0.25, -0.03, bf);
	col = mix(col, vec3(0.16, 0.08, 0.04), ch);
	float hot = smoothstep(-0.03, 0.08, bf);
	col = mix(col, vec3(1.0, 0.55, 0.12), hot * (1.0 - grid * 0.5));
	ALBEDO = col;
	EMISSION = vec3(1.0, 0.45, 0.08) * hot * 1.5;
	ALPHA = mix(0.6, 1.0, max(grid, ch)) * u_fade * nearf(VERTEX, 0.5, 2.0);
}
"""

## Hakuchūmu: kurbanın üstüne binen donmuş resim (tuval dokusu + adım adım açılan çatlaklar)
const SH_FROZEN := """
uniform float u_crack = 0.0;
uniform float u_amt = 1.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(wp.x + wp.z, wp.y) * 3.0;
	float weave = 0.5 + 0.5 * sin(p.x * 40.0) * sin(p.y * 40.0);
	vec3 col = mix(vec3(0.94, 0.89, 0.75), vec3(0.84, 0.77, 0.6), weave * 0.5);
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int yy = -1; yy <= 1; yy++) {
		for (int xx = -1; xx <= 1; xx++) {
			vec2 g = vec2(float(xx), float(yy));
			vec2 o = vec2(kh(i + g), kh(i + g + 17.3));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	float edge = 1.0 - smoothstep(0.0, 0.07, d2 - d1);
	float show = step(kh(floor(p * 0.5) + 3.1), u_crack);
	col = mix(col, vec3(0.12, 0.08, 0.06), edge * show);
	ALBEDO = col;
	ALPHA = (0.42 + edge * show * 0.5) * u_amt;
}
"""

## Gakaku Hōkai: kurbanın çevresine çekilen panorama tuvali (gök, tepe, toprak fırça bantları) + çatlak ağı
const SH_PANO := """
uniform float u_rise = 0.0;
uniform float u_crack = 0.0;
instance uniform float u_fade = 1.0;
void fragment() {
	vec2 uv = UV;
	float h = 1.0 - uv.y;
	if (h > u_rise * 1.1 - kn(uv * vec2(30.0, 4.0)) * 0.1) { discard; }
	float br = kn(vec2(uv.x * 60.0, uv.y * 8.0));
	float hill = 0.38 + kn(vec2(uv.x * 9.0, 0.5)) * 0.2;
	vec3 col = mix(vec3(0.95, 0.82, 0.62), vec3(0.55, 0.62, 0.9), smoothstep(0.4, 1.0, h));
	if (h < hill) { col = mix(vec3(0.3, 0.5, 0.25), vec3(0.45, 0.65, 0.32), br); }
	if (h < 0.14) { col = mix(vec3(0.55, 0.42, 0.25), vec3(0.68, 0.55, 0.35), br); }
	col *= 0.88 + br * 0.2;
	vec2 p = vec2(uv.x * 14.0, uv.y * 3.5);
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int yy = -1; yy <= 1; yy++) {
		for (int xx = -1; xx <= 1; xx++) {
			vec2 g = vec2(float(xx), float(yy));
			vec2 o = vec2(kh(i + g), kh(i + g + 17.3));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	float edge = 1.0 - smoothstep(0.0, 0.05, d2 - d1);
	col = mix(col, vec3(0.06, 0.04, 0.08), edge * u_crack);
	ALBEDO = col;
	ALPHA = 0.82 * u_fade * nearf(VERTEX, 0.6, 2.5);
}
"""

## Mushi Kame: taneli, girdap çizgili kara böcek küresi; kenarda mor-gri dönüş halesi (referans)
const SH_JAR := """
uniform float u_cover = 1.0;
instance uniform float u_fade = 1.0;
varying vec3 op;
void vertex() {
	op = VERTEX;
	VERTEX += NORMAL * (kn(VERTEX.xz * 8.0 + TIME * 2.0) - 0.5) * 0.05;
}
void fragment() {
	vec3 d = normalize(op);
	float lon = atan(d.z, d.x);
	float streak = kn(vec2(lon * 6.0 + TIME * 3.0 + d.y * 4.0, d.y * 30.0));
	float grain = kh(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0));
	vec3 col = mix(vec3(0.05, 0.05, 0.05), vec3(0.32, 0.3, 0.3), streak * 0.6 + grain * 0.25);
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	col = mix(col, vec3(0.44, 0.34, 0.4), smoothstep(0.55, 0.95, fr) * 0.7);
	if (kh(floor(op.xy * 40.0) + floor(op.z * 40.0)) > u_cover) { discard; }
	ALBEDO = col;
	if (kh(floor(FRAGCOORD.xy) + 0.5) > u_fade * nearf(VERTEX, 0.6, 2.5)) { discard; }
}
"""

## Mushiheki: gri-kara kaynayan böcek tanesi (dünya konumuna yapışık, karede değişen benekler)
const SH_GRAIN := """
instance uniform float u_fade = 1.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 g = floor(wp * 18.0);
	float s = kh(g.xy * 1.7 + g.z * 3.1 + floor(TIME * 10.0) * 0.731);
	float s2 = kh(g.zy * 0.9 + g.x * 2.3);
	vec3 col = vec3(0.14, 0.14, 0.13);
	col += vec3(0.3, 0.3, 0.28) * step(0.84, s);
	col -= vec3(0.07) * step(s2, 0.35);
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	col *= 1.0 - fr * 0.35;
	ALBEDO = col;
	if (kh(floor(FRAGCOORD.xy) + 0.5) > u_fade * nearf(VERTEX, 0.6, 2.2)) { discard; }
}
"""

## Mushimayu: alttan örülen soluk mavi ipek koza (dikey iplik + çapraz sargı, örgü cephesi parlak)
const SH_COCOON := """
uniform float u_grow = 0.0;
uniform float u_h = 2.1;
instance uniform float u_fade = 1.0;
varying vec3 op;
void vertex() { op = VERTEX; }
void fragment() {
	float y01 = op.y / u_h + 0.5;
	float front = u_grow - y01 - kn(op.xz * 5.0) * 0.06;
	if (front < 0.0) { discard; }
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	float lon = atan(op.z, op.x);
	float silk = smoothstep(0.75, 1.0, sin(lon * 38.0 + sin(op.y * 6.0 + TIME) * 1.5)) * 0.5;
	float wrap = smoothstep(0.85, 1.0, sin(lon * 14.0 + op.y * 18.0 + TIME * 0.5)) * 0.3;
	float a = 0.1 + pow(fr, 2.0) * 0.55 + silk + wrap + (1.0 - smoothstep(0.0, 0.08, front)) * 0.6;
	ALBEDO = vec3(0.62, 0.82, 0.95) + vec3(0.3) * (silk + wrap);
	ALPHA = clamp(a, 0.0, 0.9) * u_fade * nearf(VERTEX, 0.5, 1.6);
}
"""

## Kodoku: mühür yazılı bariyer — sıra sıra parlayan pembe yazı hücreleri + mor-beyaz süs kıvrımları
const SH_SCRIPT := """
uniform float u_write = 0.0;
uniform float u_cols = 40.0;
uniform float u_rows = 8.0;
instance uniform float u_fade = 1.0;
float sg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float glyph(vec2 cell, vec2 f) {
	float g = 0.0;
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		float r1 = kh(cell + vec2(fk * 3.7, 1.1));
		float r2 = kh(cell + vec2(fk * 9.1, 1.3));
		float r3 = kh(cell + vec2(fk * 5.3, 7.7));
		vec2 a = vec2(0.2 + r1 * 0.55, 0.15 + r2 * 0.6);
		vec2 b = mix(a + vec2(0.3 + r2 * 0.3, 0.0), a + vec2(0.0, 0.3 + r1 * 0.35), step(0.5, r3));
		b = clamp(b, vec2(0.12), vec2(0.88));
		g = max(g, 1.0 - smoothstep(0.045, 0.085, sg(f, a, b)));
	}
	return g;
}
void fragment() {
	vec2 uv = vec2(UV.x * u_cols, UV.y * u_rows);
	float row = floor(uv.y);
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float rk = mod(row, 3.0);
	vec3 col = vec3(0.0);
	if (rk < 0.5) {
		col = vec3(1.0, 0.42, 0.72) * glyph(cell, f) * 2.2;
	} else if (rk < 1.5) {
		float w = 0.5 + 0.28 * sin(uv.x * 1.57 + row * 2.0);
		float lv = 1.0 - smoothstep(0.035, 0.07, abs(f.y - w));
		vec2 cq = vec2(fract(uv.x * 0.5) - 0.5, f.y - 0.5) * vec2(2.0, 1.0);
		float curl = (1.0 - smoothstep(0.03, 0.07, abs(length(cq) - 0.25))) * step(0.5, kh(vec2(floor(uv.x * 0.5), row)));
		col = vec3(0.85, 0.72, 1.0) * max(lv, curl) * 2.0;
	}
	col *= step(UV.x, u_write) * (0.85 + 0.15 * sin(TIME * 4.0 + UV.y * 10.0));
	col += vec3(0.02, 0.006, 0.024);
	ALBEDO = col * u_fade * nearf(VERTEX, 0.8, 3.0);
}
"""

## Zehir bulutu: topak topak kabaran koyu mor cel bulut, yırtılarak dağılır
const SH_BILLOW := """
uniform vec4 u_col : source_color = vec4(0.2, 0.1, 0.26, 1.0);
uniform vec4 u_hi : source_color = vec4(0.38, 0.22, 0.46, 1.0);
instance uniform float u_fade = 1.0;
instance uniform float u_seed = 0.0;
varying vec3 op;
void vertex() {
	op = VERTEX;
	float n = kn(VERTEX.xy * 2.2 + u_seed) + kn(VERTEX.yz * 2.7 - u_seed + TIME * 0.3);
	VERTEX += NORMAL * (n - 0.8) * 0.35;
}
void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 col = mix(u_col.rgb, u_hi.rgb, smoothstep(0.1, 0.6, normalize(op).y * 0.5 + 0.5));
	col = mix(col, vec3(0.05, 0.02, 0.07), smoothstep(0.7, 0.85, fr));
	float dz = kn(op.xy * 3.0 + u_seed) * 0.6 + kn(op.yz * 7.0) * 0.4;
	if (dz > u_fade * 1.1) { discard; }
	ALBEDO = col;
	if (kh(floor(FRAGCOORD.xy)) > nearf(VERTEX, 1.0, 3.5)) { discard; }
}
"""


# ================================================================== malzeme / geometri yapı taşları
static func _shader(key: String, modes: String, body: String) -> Shader:
	var k = "sh:" + key
	if not _cache.has(k):
		var s = Shader.new()
		s.code = "shader_type spatial;\nrender_mode " + modes + ";\n" + NOISE + body
		_cache[k] = s
	return _cache[k]


static func _smat(key: String, modes: String, body: String) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader(key, modes, body)
	return m


static func _paint_mat(ink := 0.85) -> ShaderMaterial:
	var m = _smat("paint", "unshaded, cull_disabled", SH_PAINT)
	m.set_shader_parameter("u_ink", ink)
	return m


static func _cel_mat(ink := 0.9, cull_off := false) -> ShaderMaterial:
	var m: ShaderMaterial
	if cull_off:
		m = _smat("cel2", "diffuse_toon, specular_disabled, cull_disabled", SH_CEL)
	else:
		m = _smat("cel", "diffuse_toon, specular_disabled, cull_back", SH_CEL)
	m.set_shader_parameter("u_ink", ink)
	return m


static func _bug_mat(kind: String) -> ShaderMaterial:
	var k = "mat:bug_" + kind
	if _cache.has(k):
		return _cache[k]
	var m = _smat("bug", "cull_disabled", SH_BUG)
	if kind == "poison":
		m.set_shader_parameter("u_tint", Color(0.17, 0.07, 0.21))
		m.set_shader_parameter("u_glint", Color(0.62, 0.35, 0.78))
	elif kind == "giant":
		m.set_shader_parameter("u_tint", Color(1, 1, 1))
		m.set_shader_parameter("u_glint", Color(0.5, 0.52, 0.5))
	_cache[k] = m
	return m


## Parçacık lekesi malzemesi: düz, parçacık rengini alan, kameraya yakınken söner
static func _fleck_mat(key := "fleck", bb := BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var k = "mat:" + key
	if _cache.has(k):
		return _cache[k]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = bb
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = 0.4
	m.distance_fade_max_distance = 1.5
	_cache[k] = m
	return m


static func _curve_out() -> Curve:
	var k = "curve:out"
	if _cache.has(k):
		return _cache[k]
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(0.7, 0.8))
	cv.add_point(Vector2(1.0, 0.0))
	_cache[k] = cv
	return cv


static func _ramp(cols: Array) -> Gradient:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cc = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / float(cols.size()))
		cc.append(cols[i])
	g.offsets = offs
	g.colors = cc
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _arr_mesh(V: PackedVector3Array, N: PackedVector3Array, C: PackedColorArray, U: PackedVector2Array, I: PackedInt32Array) -> ArrayMesh:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_NORMAL] = N
	arr[Mesh.ARRAY_COLOR] = C
	arr[Mesh.ARRAY_TEX_UV] = U
	arr[Mesh.ARRAY_INDEX] = I
	var m = ArrayMesh.new()
	if V.size() > 2:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Catmull-Rom ile yumuşatılmış çizgi (fırça darbeleri köşeli görünmesin)
static func _smooth(p: PackedVector3Array, sub := 5) -> PackedVector3Array:
	if p.size() < 3:
		return p
	var out = PackedVector3Array()
	for i in p.size() - 1:
		var p0 = p[maxi(i - 1, 0)]
		var p1 = p[i]
		var p2 = p[i + 1]
		var p3 = p[mini(i + 2, p.size() - 1)]
		for s in sub:
			var t = float(s) / sub
			var t2 = t * t
			var t3 = t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(p[p.size() - 1])
	return out


## Şerit (fırça darbesi): UV.x boy, UV.y en. nrm sıfırsa her nokta merkezden dışa bakar (halka şeritler)
static func _ribbon(pts: PackedVector3Array, w: PackedFloat32Array, nrm: Vector3, cols: PackedColorArray) -> ArrayMesh:
	var V = PackedVector3Array()
	var N = PackedVector3Array()
	var C = PackedColorArray()
	var U = PackedVector2Array()
	var I = PackedInt32Array()
	var n = pts.size()
	var L = 0.0
	var acc = PackedFloat32Array([0.0])
	for i in range(1, n):
		L += pts[i].distance_to(pts[i - 1])
		acc.append(L)
	for i in n:
		var p: Vector3 = pts[i]
		var tng: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var nn = nrm
		if nn.length() < 0.01:
			nn = Vector3(p.x, 0.0, p.z)
			nn = nn.normalized() if nn.length() > 0.001 else Vector3.BACK
		var sd = tng.cross(nn)
		if sd.length() < 0.0001:
			sd = tng.cross(Vector3.UP if absf(tng.normalized().y) < 0.9 else Vector3.RIGHT)
		sd = sd.normalized() * w[mini(i, w.size() - 1)] * 0.5
		var u = acc[i] / maxf(L, 0.0001)
		var cc: Color = cols[mini(i, cols.size() - 1)]
		V.append(p - sd)
		V.append(p + sd)
		N.append(nn)
		N.append(nn)
		C.append(cc)
		C.append(cc)
		U.append(Vector2(u, 0.0))
		U.append(Vector2(u, 1.0))
	for i in n - 1:
		var a = i * 2
		I.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	return _arr_mesh(V, N, C, U, I)


## Tüp (sarmaşık, kol, sap): UV.x boy boyu (u_reveal ile uzayarak belirir), UV.y çevre
static func _tube(pts: PackedVector3Array, radii: PackedFloat32Array, cols: PackedColorArray, sides := 8) -> ArrayMesh:
	var V = PackedVector3Array()
	var N = PackedVector3Array()
	var C = PackedColorArray()
	var U = PackedVector2Array()
	var I = PackedInt32Array()
	var n = pts.size()
	if n < 2:
		return ArrayMesh.new()
	var L = 0.0
	var acc = PackedFloat32Array([0.0])
	for i in range(1, n):
		L += pts[i].distance_to(pts[i - 1])
		acc.append(L)
	var t0: Vector3 = (pts[1] - pts[0]).normalized()
	var nr = t0.cross(Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT).normalized()
	for i in n:
		var tg: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		nr = (nr - tg * nr.dot(tg))
		nr = nr.normalized() if nr.length() > 0.0001 else tg.cross(Vector3.RIGHT).normalized()
		var bn = tg.cross(nr)
		var r = radii[mini(i, radii.size() - 1)]
		var cc: Color = cols[mini(i, cols.size() - 1)]
		for s in sides + 1:
			var a = TAU * s / sides
			var d = nr * cos(a) + bn * sin(a)
			V.append(pts[i] + d * r)
			N.append(d)
			C.append(cc)
			U.append(Vector2(acc[i] / maxf(L, 0.0001), float(s) / sides))
	var row = sides + 1
	for i in n - 1:
		for s in sides:
			var a = i * row + s
			I.append_array([a, a + row, a + 1, a + 1, a + row, a + row + 1])
	return _arr_mesh(V, N, C, U, I)


## Düz disk (jag > 0: yırtık kenar); UV merkezde 0.5
static func _disc(R: float, seg: int, jag: float) -> ArrayMesh:
	var V = PackedVector3Array([Vector3.ZERO])
	var N = PackedVector3Array([Vector3.UP])
	var C = PackedColorArray([Color.WHITE])
	var U = PackedVector2Array([Vector2(0.5, 0.5)])
	var I = PackedInt32Array()
	for s in seg:
		var a = TAU * s / seg
		var rr = R * (1.0 - jag * randf())
		V.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
		N.append(Vector3.UP)
		C.append(Color.WHITE)
		U.append(Vector2(cos(a) * rr / R * 0.5 + 0.5, sin(a) * rr / R * 0.5 + 0.5))
	for s in seg:
		I.append_array([0, 1 + (s + 1) % seg, 1 + s])
	return _arr_mesh(V, N, C, U, I)


## İki nokta arası silindir parçası (bacak, sap, ayak)
static func _seg(b: MB, a: Vector3, b2: Vector3, r: float, col: Color) -> void:
	var d = b2 - a
	var L = d.length()
	if L < 0.001:
		return
	var y = d / L
	var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y)
	b.add_xf("cyl", Transform3D(Basis(x * 2.0 * r, y * L, z * 2.0 * r), (a + b2) * 0.5), col, 6)


## Dikey düzlemde (XY) kalınlığı Z olan levha: duvar, yaprak
static func _slab_xy(b: MB, outline: PackedVector2Array, thick: float, col: Color, at := Vector3.ZERO) -> void:
	var o = PackedVector2Array()
	for p in outline:
		o.append(Vector2(p.y, -p.x))
	b.add_slab(o, thick, col, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), at))


## Yatay düzlemde (XZ) kalınlığı Y olan levha: zemin lekesi, kaya dudağı, sivri parça
static func _slab_flat(b: MB, outline: PackedVector2Array, thick: float, col: Color, at := Vector3.ZERO) -> void:
	var o = PackedVector2Array()
	for p in outline:
		o.append(Vector2(-p.x, p.y))
	b.add_slab(o, thick, col, Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), at))


## Tırtıklı yıldız lekesi (yanık, boya sıçraması)
static func _splat_outline(r: float, n: int, spike: float) -> PackedVector2Array:
	var o = PackedVector2Array()
	for k in n:
		var a = TAU * k / n
		var rr = r * (1.0 + spike * randf() if k % 2 == 0 else 0.55 + 0.2 * randf())
		o.append(Vector2(cos(a), sin(a)) * rr)
	return o


## Ağacın tüm meshlerine u_fade (instance uniform) yumuşak geçişi
static func _fade(n: Node, a: float, b: float, dur: float, delay := 0.0) -> void:
	if n == null or not is_instance_valid(n):
		return
	var gs: Array = []
	if n is MeshInstance3D or n is MultiMeshInstance3D:
		gs.append(n)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if g is MeshInstance3D or g is MultiMeshInstance3D:
			gs.append(g)
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		for g in gs:
			if is_instance_valid(g):
				(g as GeometryInstance3D).set_instance_shader_parameter("u_fade", v), a, b, dur)


static func _fade_free(n: Node, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	_fade(n, 1.0, 0.0, dur, delay)
	var w = weakref(n)
	n.get_tree().create_timer(delay + dur + 0.05).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


## Tek atımlık leke sıçraması (boya, kıvılcım, toz, kan) — kendi parçacık ayarı
static func _flecks(pj: PathJutsu, pos: Vector3, cols: Array, n: int, spd: float, life: float, size: float, grav := 9.0, dir := Vector3.UP, spread := 180.0, radius := 0.1) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = maxi(1, n)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	var qm = QuadMesh.new()
	qm.size = Vector2(size, size * 0.62)
	p.mesh = qm
	p.material_override = _fleck_mat()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = spd * 0.35
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -grav, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _curve_out()
	p.color_initial_ramp = _ramp(cols)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(p, pos)
	p.emitting = true
	pj.free_after(life + 0.4, p)
	return p


## Sürekli akan leke kaynağı (kor, mürekkep damlası, dikey hız çizgisi); dur sonra söner ve silinir
static func _emitter(parent: Node3D, off: Vector3, cols: Array, amount: int, life: float, size: Vector2, grav: float, dir: Vector3, spd: float, box: Vector3, dur: float, key := "fleck") -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	var qm = QuadMesh.new()
	qm.size = size
	p.mesh = qm
	p.material_override = _fleck_mat("streak", BaseMaterial3D.BILLBOARD_FIXED_Y) if key == "streak" else _fleck_mat()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = dir
	p.spread = 20.0
	p.initial_velocity_min = spd * 0.5
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -grav, 0)
	if key != "streak":
		p.angle_min = 0.0
		p.angle_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curve_out()
	p.color_initial_ramp = _ramp(cols)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = off
	p.emitting = true
	var w = weakref(p)
	parent.get_tree().create_timer(maxf(0.05, dur)).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.emitting = false
			x.get_tree().create_timer(life + 0.2).timeout.connect(func():
				if is_instance_valid(x):
					x.queue_free()))
	return p


static func _light(pj: PathJutsu, pos: Vector3, col: Color, energy: float, rng: float, life: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	pj.scene_add(l, pos)
	var tw = l.create_tween()
	tw.tween_interval(life * 0.4)
	tw.tween_property(l, "light_energy", 0.0, life * 0.6)
	tw.tween_callback(l.queue_free)
	return l


# ================================================================== Kurama yapı taşları
## Tuvaldeki resim (tuval yerel koordinatı x ±0.6, y ±0.42): [nokta dizisi, fırça eni, renk]
static func _motif(motif: String, col: Color) -> Array:
	var out = []
	match motif:
		"bolt":   # kara bulut + zikzak şimşek + çatallanma + yer çizgisi
			out.append([PackedVector2Array([Vector2(-0.5, 0.3), Vector2(-0.25, 0.38), Vector2(0.0, 0.3), Vector2(0.25, 0.38), Vector2(0.5, 0.3)]), 0.1, Color(0.28, 0.28, 0.38)])
			out.append([PackedVector2Array([Vector2(-0.05, 0.28), Vector2(0.08, 0.08), Vector2(-0.08, 0.0), Vector2(0.1, -0.22), Vector2(0.0, -0.36)]), 0.08, col])
			out.append([PackedVector2Array([Vector2(0.08, 0.08), Vector2(0.25, -0.05), Vector2(0.2, -0.2)]), 0.04, col.lightened(0.3)])
			out.append([PackedVector2Array([Vector2(-0.45, -0.4), Vector2(0.0, -0.37), Vector2(0.45, -0.4)]), 0.05, INK])
		"flame":   # ev çatısı + iki kıvrık alev dili
			out.append([PackedVector2Array([Vector2(-0.32, -0.38), Vector2(-0.32, 0.02), Vector2(0.0, 0.3), Vector2(0.32, 0.02), Vector2(0.32, -0.38)]), 0.06, WOOD])
			out.append([PackedVector2Array([Vector2(-0.15, -0.38), Vector2(-0.22, -0.15), Vector2(-0.1, 0.05), Vector2(-0.18, 0.25)]), 0.11, col])
			out.append([PackedVector2Array([Vector2(0.12, -0.38), Vector2(0.2, -0.1), Vector2(0.08, 0.12), Vector2(0.16, 0.36)]), 0.1, col.lightened(0.25)])
			out.append([PackedVector2Array([Vector2(-0.02, -0.38), Vector2(0.03, -0.18), Vector2(-0.03, 0.0)]), 0.06, Color(1.0, 0.9, 0.45)])
		"cliff":   # uçurum kenarı + dik kaya çizgileri + düşen siluet
			out.append([PackedVector2Array([Vector2(-0.58, 0.05), Vector2(-0.3, 0.08), Vector2(-0.12, 0.0), Vector2(-0.1, -0.4)]), 0.07, col])
			out.append([PackedVector2Array([Vector2(0.58, 0.1), Vector2(0.28, 0.06), Vector2(0.14, -0.02), Vector2(0.13, -0.4)]), 0.07, col])
			out.append([PackedVector2Array([Vector2(-0.35, 0.02), Vector2(-0.33, -0.35)]), 0.03, INK])
			out.append([PackedVector2Array([Vector2(0.35, 0.03), Vector2(0.36, -0.33)]), 0.03, INK])
			out.append([PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.01, -0.22)]), 0.05, INK])
		"vine":   # yerden kıvrılan sap + yapraklar
			var sp = PackedVector2Array()
			for q in 12:
				var a = q * 0.75
				var r = 0.04 + q * 0.018
				sp.append(Vector2(cos(a) * r * 0.8, -0.38 + q * 0.06 + sin(a) * r * 0.25))
			out.append([sp, 0.06, col])
			out.append([PackedVector2Array([Vector2(-0.05, -0.1), Vector2(-0.2, -0.05), Vector2(-0.24, 0.05)]), 0.09, col.lightened(0.2)])
			out.append([PackedVector2Array([Vector2(0.06, 0.08), Vector2(0.2, 0.12), Vector2(0.26, 0.22)]), 0.09, col.lightened(0.2)])
			out.append([PackedVector2Array([Vector2(-0.5, -0.4), Vector2(0.5, -0.4)]), 0.04, WOOD])
		"void":   # içe dönen girdap + yıldız benekleri
			var vp = PackedVector2Array()
			for q in 16:
				var a = q * 0.62
				var r = 0.36 * exp(-q * 0.13)
				vp.append(Vector2(cos(a), sin(a)) * r)
			out.append([vp, 0.09, col])
			for s in 3:
				var c2 = Vector2(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3))
				out.append([PackedVector2Array([c2, c2 + Vector2(0.03, 0.02)]), 0.035, Color(0.9, 0.85, 1.0)])
		"frame":   # altın çerçeve + donmuş siluet
			out.append([PackedVector2Array([Vector2(-0.45, -0.36), Vector2(-0.45, 0.36), Vector2(0.45, 0.36), Vector2(0.45, -0.36), Vector2(-0.45, -0.36)]), 0.07, Color(0.85, 0.65, 0.25)])
			out.append([PackedVector2Array([Vector2(0.0, -0.3), Vector2(0.0, 0.08)]), 0.08, INK])
			out.append([PackedVector2Array([Vector2(-0.05, 0.16), Vector2(0.0, 0.22), Vector2(0.05, 0.16), Vector2(0.0, 0.11), Vector2(-0.05, 0.16)]), 0.05, INK])
			out.append([PackedVector2Array([Vector2(-0.2, -0.05), Vector2(0.2, 0.0)]), 0.05, col])
		"shatter":   # merkezden dağılan renkli ışınlar + çatlak
			var cl = [Color(0.85, 0.3, 0.3), Color(0.3, 0.55, 0.85), Color(0.95, 0.8, 0.3), Color(0.4, 0.75, 0.4), col]
			for s in 5:
				var a = TAU * s / 5.0 + 0.3
				out.append([PackedVector2Array([Vector2(cos(a), sin(a)) * 0.06, Vector2(cos(a + 0.15), sin(a + 0.15)) * 0.22, Vector2(cos(a), sin(a)) * 0.4]), 0.07, cl[s]])
			out.append([PackedVector2Array([Vector2(-0.4, 0.3), Vector2(-0.15, 0.1), Vector2(-0.2, -0.05), Vector2(0.1, -0.3)]), 0.03, INK])
	return out


## Kurama hazırlığı: şövale + tuval; fırça tuvale tekniğin kendi resmini çizer, boya kurbana uçar, tuval söner
static func _canvas(pj: PathJutsu, c: Node3D, col: Color, motif: String, dur: float, tt: Node3D = null) -> void:
	var fd: Vector3 = c.face_dir()
	fd.y = 0.0
	fd = fd.normalized() if fd.length() > 0.01 else Vector3.FORWARD
	var root = Node3D.new()
	pj.scene_add(root, c.global_position + fd * 0.9 + Vector3.UP * 1.3)
	root.global_basis = Basis.looking_at(fd, Vector3.UP)   # +Z büyücüye (kameraya) döner: resim görünür
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(1.3, 0.95, 0.03), Color(0.94, 0.9, 0.79))
	b.add("box", Vector3(0, 0.5, 0), Vector3(1.4, 0.06, 0.06), WOOD)
	b.add("box", Vector3(0, -0.5, 0), Vector3(1.4, 0.06, 0.06), WOOD)
	_seg(b, Vector3(-0.45, -0.5, -0.02), Vector3(-0.62, -1.3, 0.25), 0.025, WOOD)
	_seg(b, Vector3(0.45, -0.5, -0.02), Vector3(0.62, -1.3, 0.25), 0.025, WOOD)
	_seg(b, Vector3(0.0, 0.45, -0.04), Vector3(0.0, -1.3, -0.55), 0.025, WOOD)
	root.add_child(_mi(b.build(), _cel_mat(0.7)))
	# fırça: sap + madeni bilezik + boyalı uç
	var bb = MB.new()
	bb.add("cyl", Vector3(0, 0.2, 0), Vector3(0.025, 0.34, 0.025), WOOD, Vector3.ZERO, 6)
	bb.add("cyl", Vector3(0, 0.02, 0), Vector3(0.032, 0.05, 0.032), Color(0.7, 0.7, 0.72), Vector3.ZERO, 6)
	bb.add("cone", Vector3(0, -0.04, 0), Vector3(0.04, 0.09, 0.04), col, Vector3(180, 0, 0), 6)
	var brush = _mi(bb.build(), _cel_mat(0.6))
	root.add_child(brush)
	brush.position = Vector3(0.0, 0.0, 0.25)
	brush.rotation = Vector3(0.5, 0.0, -0.3)
	var strokes = _motif(motif, col)
	var st_t = 0.3 / maxf(1.0, strokes.size())
	var btw = brush.create_tween()
	for j in strokes.size():
		var s2: PackedVector2Array = strokes[j][0]
		var p3 = PackedVector3Array()
		for p in s2:
			p3.append(Vector3(p.x, p.y, 0.03))
		p3 = _smooth(p3, 4)
		var w = PackedFloat32Array()
		for i in p3.size():
			var u = float(i) / maxf(1.0, p3.size() - 1)
			w.append(float(strokes[j][1]) * (1.0 - 0.45 * u) * (0.6 + 0.4 * minf(1.0, u * 6.0)))
		var m = _paint_mat(0.75)
		m.set_shader_parameter("u_reveal", 0.0)
		root.add_child(_mi(_ribbon(p3, w, Vector3.BACK, PackedColorArray([strokes[j][2]])), m))
		var tw = root.create_tween()
		tw.tween_interval(0.04 + j * st_t)
		tw.tween_method(func(v: float): m.set_shader_parameter("u_reveal", v), 0.0, 1.05, st_t * 0.9)
		btw.tween_property(brush, "position", p3[0] + Vector3(0, 0.06, 0.06), 0.03)
		btw.tween_property(brush, "position", p3[p3.size() - 1] + Vector3(0, 0.06, 0.06), st_t * 0.9)
	btw.tween_property(brush, "position", Vector3(0.5, 0.2, 0.3), 0.08)
	# resim gerçek olur: boya lekeleri kurbana doğru savrulur
	if tt != null and is_instance_valid(tt):
		var tw2 = weakref(tt)
		var rw = weakref(root)
		pj.after(0.32, func():
			var x = tw2.get_ref()
			var r = rw.get_ref()
			if x == null or r == null or not is_instance_valid(x):
				return
			var from: Vector3 = (r as Node3D).global_position
			var to: Vector3 = x.global_position + Vector3.UP * 1.2
			var dist = from.distance_to(to)
			_flecks(pj, from, [col, col.lightened(0.25), INK], 18, clampf(dist / 0.32, 6.0, 60.0), 0.4, 0.13, 1.0, (to - from).normalized(), 7.0, 0.3))
	_fade_free(root, maxf(0.1, dur - 0.25), 0.25)


## Genjutsu altında: kurbanın başında dönen beş boya lekesi (kendi rengi + mürekkep)
static func _mark(pj: PathJutsu, x: Node3D, col: Color, dur: float) -> void:
	if not pj.live(x):
		return
	var root = Node3D.new()
	for k in 5:
		var a0 = k * TAU / 5.0
		var pts = PackedVector3Array()
		for q in 6:
			var a = a0 + q * 0.16
			pts.append(Vector3(cos(a) * 0.48, sin(q * 0.9) * 0.04, sin(a) * 0.48))
		var w = PackedFloat32Array([0.05, 0.11, 0.13, 0.12, 0.09, 0.03])
		root.add_child(_mi(_ribbon(pts, w, Vector3.ZERO, PackedColorArray([col if k % 2 == 0 else col.darkened(0.45)])), _paint_mat(0.9)))
	pj.attach(x, root, dur, Vector3.UP * 2.3)
	var tw = Game.safe_loops(root.create_tween(), int(dur / 0.9) + 1)
	tw.tween_property(root, "rotation:y", TAU, 0.9).as_relative()
	_fade(root, 1.0, 0.0, 0.3, maxf(0.0, dur - 0.35))


## Gerçeklik genjutsusu isabeti (ortak kapı: göz teması + Sharingan direnci); tutarsa iz + oyuncu kurbansa ekran rengi
static func _land(pj: PathJutsu, c: Node3D, x: Node3D, col: Color) -> float:
	var gm = Eyes.genjutsu_land(c, x, true)
	if gm > 0.0:
		_mark(pj, x, col, 2.0)
		if x == Game.player and Game.world:
			Game.world.env.flash_tint(Color(0.35, 0.1, 0.4, 0.22), 1.2)
	return gm


## Raiga: boyalı fırtına bulutu (topak kütle + altında mürekkep girdabı)
static func _storm_cloud(pj: PathJutsu, pos: Vector3, life: float) -> void:
	var root = Node3D.new()
	pj.scene_add(root, pos)
	var b = MB.new()
	for k in 7:
		var a = k * TAU / 7.0
		b.add("sphere", Vector3(cos(a) * 1.4, randf_range(-0.2, 0.3), sin(a) * 1.4), Vector3(2.0, 1.0, 1.8) * randf_range(0.8, 1.2), Color(0.24, 0.24, 0.32), Vector3.ZERO, 10)
	b.add("sphere", Vector3.ZERO, Vector3(2.8, 1.3, 2.8), Color(0.18, 0.17, 0.25), Vector3.ZERO, 12)
	root.add_child(_mi(b.build(), _cel_mat(0.9)))
	for k in 3:
		var pts = PackedVector3Array()
		var w = PackedFloat32Array()
		for q in 14:
			var a = k * TAU / 3.0 + q * 0.32
			var r = 1.9 - q * 0.11
			pts.append(Vector3(cos(a) * r, -0.62, sin(a) * r))
			w.append(0.32 - q * 0.018)
		var m = _paint_mat(0.6)
		m.set_shader_parameter("u_core", 0.25 if k == 0 else 0.0)
		root.add_child(_mi(_ribbon(pts, w, Vector3.UP, PackedColorArray([Color(0.95, 0.85, 0.35) if k == 0 else Color(0.14, 0.13, 0.2)])), m))
	root.scale = Vector3.ONE * 0.3
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rt = root.create_tween()
	rt.tween_property(root, "rotation:y", 1.2, life + 0.4).as_relative()
	_fade_free(root, life, 0.4)


## Raiga: boyalı şimşek — çapraz iki kalın zikzak fırça darbesi, beyaz öz, mürekkep kenar; yukarıdan aşağı boyanır
static func _painted_bolt(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var root = Node3D.new()
	pj.scene_add(root, b)
	var dv = a - b
	var pts = PackedVector3Array()
	var w = PackedFloat32Array()
	var n = 10
	for i in n + 1:
		var u = float(i) / n
		var jit = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)) * sin(PI * u)
		pts.append(dv * (1.0 - u) + jit)
		w.append(lerpf(0.42, 0.3, u) + (0.2 if i == n else 0.0))
	var fork = PackedVector3Array()
	var fw = PackedFloat32Array()
	var fo: Vector3 = pts[4]
	var fdir = Vector3(randf_range(-1, 1), -1.4, randf_range(-1, 1)).normalized()
	for i in 5:
		fork.append(fo + fdir * i * 0.7 + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)))
		fw.append(0.2 - i * 0.035)
	var m = _paint_mat(0.9)
	m.set_shader_parameter("u_core", 0.75)
	m.set_shader_parameter("u_reveal", 0.0)
	var cols = PackedColorArray([Color(0.98, 0.85, 0.25)])
	for nrm in [Vector3.RIGHT, Vector3.BACK]:
		root.add_child(_mi(_ribbon(pts, w, nrm, cols), m))
		root.add_child(_mi(_ribbon(fork, fw, nrm, cols), m))
	var tw = root.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("u_reveal", v), 0.0, 1.05, 0.06)
	_light(pj, b + Vector3.UP * 0.5, Color(1.0, 0.9, 0.5), 6.0, 9.0, 0.3)
	_fade_free(root, 0.16, 0.22)


## Raiga: yerde kalan boyalı yanık lekesi + sıçrayan sarı kıvılcım lekeleri
static func _scorch(pj: PathJutsu, at: Vector3, r: float) -> void:
	var b = MB.new()
	_slab_flat(b, _splat_outline(r, 14, 0.6), 0.03, Color(0.12, 0.08, 0.06))
	_slab_flat(b, _splat_outline(r * 0.45, 10, 0.4), 0.032, Color(0.5, 0.38, 0.12), Vector3.UP * 0.004)
	var mi = _mi(b.build(), _cel_mat(0.0, true))
	pj.scene_add(mi, at + Vector3.UP * 0.03)
	mi.rotation.y = randf() * TAU
	_fade_free(mi, 1.6, 0.5)
	_flecks(pj, at + Vector3.UP * 0.2, [Color(1.0, 0.92, 0.5), Color(0.98, 0.8, 0.25), INK], 14, 7.0, 0.5, 0.14, 12.0, Vector3.UP, 70.0)


## Halka şeklinde boyanan fırça darbesi (yere yatık)
static func _brush_ring(pj: PathJutsu, pos: Vector3, R: float, col: Color, w0: float) -> void:
	var root = Node3D.new()
	pj.scene_add(root, pos)
	var pts = PackedVector3Array()
	var w = PackedFloat32Array()
	for q in 41:
		var a = TAU * q / 40.0 * 0.95
		pts.append(Vector3(cos(a), 0.0, sin(a)) * R * (1.0 + 0.05 * sin(q * 1.7)))
		w.append(w0 * sin(PI * clampf(q / 40.0, 0.05, 0.95)))
	var m = _paint_mat(0.8)
	m.set_shader_parameter("u_reveal", 0.0)
	root.add_child(_mi(_ribbon(pts, w, Vector3.UP, PackedColorArray([col])), m))
	root.rotation.y = randf() * TAU
	root.scale = Vector3.ONE * 0.6
	var tw = root.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("u_reveal", v), 0.0, 1.05, 0.14)
	tw.parallel().tween_property(root, "scale", Vector3.ONE * 1.3, 0.4).set_ease(Tween.EASE_OUT)
	_fade_free(root, 0.2, 0.3)


# ================================================================== Kurama teknikleri
## Kurama Genjutsu: Raiga — tuvale şimşek çizer; kurbanın üstünde boyalı fırtına bulutu, üç boyalı şimşek iner
static func kurama_genjutsu_raiga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.9)
	var id = "kurama_genjutsu_raiga"
	pj._face(c, tt)
	var col = Color(0.95, 0.85, 0.3)
	_canvas(pj, c, col, "bolt", 1.0, tt)
	Sfx.play("genjutsu", c.global_position, 1.1)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.4, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var gm = _land(pj, cc, x, col)
		if gm <= 0.0:
			return
		var sky: Vector3 = x.global_position + Vector3.UP * 9.0
		_storm_cloud(pj, sky, 0.9)
		for k in 3:   # gökten inen şimşekler
			pj.after(k * 0.14, func():
				var c2 = cw.get_ref()
				var x2 = tw.get_ref()
				if c2 == null or x2 == null or not pj.live(x2):
					return
				var p: Vector3 = x2.global_position + Vector3.UP * 1.0
				_painted_bolt(pj, sky + Vector3(randf_range(-1.2, 1.2), -0.5, randf_range(-1.2, 1.2)), p)
				_scorch(pj, pj.gp(p), 0.9 + k * 0.25)
				Sfx.play("thunder", p, 1.0 + k * 0.1)
				x2.take_hit(pj.inf(c2, id, 1.25 * gm, {"knock": 2.0, "kind": "heavy", "element": "raiton", "stun": 0.6, "pierce_guard": true, "hitstop": 0.06}))))


## Enga: yanan ahşap ev — direkler, kirişler, çatı makası; üç yanda alttan yanan shoji kâğıdı, kıvrık boyalı alev dilleri
static func _burning_house(pj: PathJutsu, at: Vector3, hold: float, face: Vector3) -> Node3D:
	var root = Node3D.new()
	pj.scene_add(root, at)
	root.global_basis = Basis.looking_at(face, Vector3.UP)   # -Z büyücüden uzağa; büyücüye bakan yüz açık
	var posts = []
	var wm = _cel_mat(0.8)
	wm.set_shader_parameter("u_emit", Color(1.0, 0.35, 0.05, 0.12))
	var corners = [Vector3(-1.2, 0, -1.2), Vector3(1.2, 0, -1.2), Vector3(1.2, 0, 1.2), Vector3(-1.2, 0, 1.2)]
	for k in 4:
		var pb = MB.new()
		pb.add("box", Vector3(0, 1.4, 0), Vector3(0.18, 2.8, 0.18), WOOD.darkened(0.1))
		var post = _mi(pb.build(), wm)
		root.add_child(post)
		post.position = corners[k]
		posts.append(post)
	var bm = MB.new()
	for k in 4:   # tepe kirişleri
		var a: Vector3 = corners[k]
		var b2: Vector3 = corners[(k + 1) % 4]
		_seg(bm, a + Vector3.UP * 2.75, b2 + Vector3.UP * 2.75, 0.08, WOOD)
	for sx in [-1.2, 1.2]:   # çatı makası (beşik çatı iskeleti)
		_seg(bm, Vector3(sx, 2.75, -1.2), Vector3(0, 3.7, -1.2), 0.07, WOOD)
		_seg(bm, Vector3(sx, 2.75, 1.2), Vector3(0, 3.7, 1.2), 0.07, WOOD)
	_seg(bm, Vector3(0, 3.7, -1.25), Vector3(0, 3.7, 1.25), 0.08, WOOD)
	_seg(bm, Vector3(-1.2, 0.3, -1.2), Vector3(1.2, 2.6, -1.2), 0.06, WOOD)   # arka çapraz destek
	var beams = _mi(bm.build(), wm)
	root.add_child(beams)
	# kâğıt duvarlar: arka + iki yan (büyücüye bakan ön açık: kurban görünür)
	var pm = _smat("paper", "unshaded, cull_disabled", SH_PAPER)
	pm.set_shader_parameter("u_burn", 0.0)
	var walls = [[Vector3(0, 1.3, -1.2), 0.0], [Vector3(-1.2, 1.3, 0), PI * 0.5], [Vector3(1.2, 1.3, 0), -PI * 0.5]]
	for wv in walls:
		var q = MeshInstance3D.new()
		var qm = QuadMesh.new()
		qm.size = Vector2(2.3, 2.5)
		q.mesh = qm
		q.material_override = pm
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(q)
		q.position = wv[0]
		q.rotation.y = wv[1]
	var ptw = root.create_tween()
	ptw.tween_method(func(v: float): pm.set_shader_parameter("u_burn", v), 0.0, 1.0, maxf(0.4, hold))
	# alev dilleri: çapraz iki kıvrık şerit, dipte koyu turuncu, uçta sarı; dalgalanır, fırça dokusu yukarı akar
	var spots = [Vector3(-1.2, 0, -1.2), Vector3(1.2, 0, -1.2), Vector3(-1.2, 0, 1.2), Vector3(1.2, 0, 1.2), Vector3(0, 0, -1.25), Vector3(-1.25, 0, 0), Vector3(1.25, 0, 0), Vector3(-0.6, 0, -1.25), Vector3(0.6, 0, -1.25), Vector3(0, 3.6, 0)]
	for k in spots.size():
		var fr = Node3D.new()
		root.add_child(fr)
		fr.position = spots[k]
		var hh = randf_range(1.4, 2.6) if k < 9 else 1.2
		var pts = PackedVector3Array()
		var w = PackedFloat32Array()
		var cols = PackedColorArray()
		var ph = randf() * TAU
		for i in 9:
			var u = i / 8.0
			pts.append(Vector3(sin(u * 5.0 + ph) * 0.18 * u, u * hh, 0.0))
			w.append(lerpf(0.75, 0.04, pow(u, 0.8)))
			cols.append(Color(0.9, 0.25, 0.04).lerp(Color(1.0, 0.62, 0.12), minf(1.0, u * 1.6)).lerp(Color(1.0, 0.92, 0.45), maxf(0.0, u - 0.6) * 2.5))
		var m = _paint_mat(0.55)
		m.set_shader_parameter("u_wob", 0.14)
		m.set_shader_parameter("u_flow", 2.5)
		m.set_shader_parameter("u_core", 0.3)
		m.set_shader_parameter("u_reveal", 0.0)
		var rib = _ribbon(pts, w, Vector3.BACK, cols)
		for r in 2:
			var fm = _mi(rib, m)
			fr.add_child(fm)
			fm.rotation.y = r * PI * 0.5 + 0.4
		var ft = fr.create_tween()
		ft.tween_interval(k * 0.04)
		ft.tween_method(func(v: float): m.set_shader_parameter("u_reveal", v), 0.0, 1.05, 0.35)
		var fl = Game.safe_loops(fr.create_tween(), int(hold / 0.5) + 2)
		fl.tween_property(fr, "scale", Vector3(1.0, 1.15, 1.0), 0.22 + randf() * 0.1)
		fl.tween_property(fr, "scale", Vector3(1.0, 0.85, 1.0), 0.22 + randf() * 0.1)
	# yerde kömürleşen halka
	var gb = MB.new()
	_slab_flat(gb, _splat_outline(2.1, 18, 0.25), 0.03, Color(0.1, 0.06, 0.04))
	root.add_child(_mi(gb.build(), _cel_mat(0.0, true)))
	# ateş ışığı, kor ve kül
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.5
	l.omni_range = 7.0
	root.add_child(l)
	l.position = Vector3.UP * 1.5
	var lt = Game.safe_loops(l.create_tween(), int(hold / 0.3) + 2)
	lt.tween_property(l, "light_energy", 3.2, 0.15)
	lt.tween_property(l, "light_energy", 2.0, 0.15)
	_emitter(root, Vector3.UP * 1.2, [Color(1.0, 0.75, 0.3), Color(1.0, 0.45, 0.1), Color(0.2, 0.15, 0.12)], 26, 1.1, Vector2(0.09, 0.09), -1.5, Vector3.UP, 2.5, Vector3(1.2, 1.0, 1.2), hold)
	# sonda çöküş: direkler devrilir, ev söner
	var pw = []
	for p in posts:
		pw.append(weakref(p))
	var bw = weakref(beams)
	var tree = root.get_tree()
	tree.create_timer(maxf(0.1, hold - 0.35)).timeout.connect(func():
		for w2 in pw:
			var p2 = w2.get_ref()
			if p2 != null and is_instance_valid(p2):
				(p2 as Node3D).create_tween().tween_property(p2, "rotation", Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), 0.4).set_ease(Tween.EASE_IN)
		var b3 = bw.get_ref()
		if b3 != null and is_instance_valid(b3):
			(b3 as Node3D).create_tween().tween_property(b3, "position:y", -0.8, 0.4).set_ease(Tween.EASE_IN))
	_fade_free(root, maxf(0.1, hold - 0.1), 0.5)
	return root


## Kurama Genjutsu: Enga — kurbanı yanan bir evin içine hapseder; alevler gerçek gibi yakar
static func kurama_genjutsu_enga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.9)
	var id = "kurama_genjutsu_enga"
	pj._face(c, tt)
	var col = Color(0.95, 0.4, 0.1)
	_canvas(pj, c, col, "flame", 1.0, tt)
	Sfx.play("genjutsu", c.global_position, 1.0)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.4, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var gm = _land(pj, cc, x, col)
		if gm <= 0.0:
			return
		var at: Vector3 = pj.gp(x.global_position)
		var face: Vector3 = at - cc.global_position
		face.y = 0.0
		face = face.normalized() if face.length() > 0.1 else Vector3.FORWARD
		var hold = 2.6 * gm
		_burning_house(pj, at, hold, face)
		pj.st(x, "bind", hold)
		Combat.popup_text(at + Vector3.UP * 3.2, "Yanan evde!", Color(1.0, 0.5, 0.2))
		pj.every(hold, 0.2, func(i, _k):
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 == null or x2 == null or not pj.live(x2) or i % 2 == 1:
				return
			x2.take_hit(pj.inf(c2, id, 0.7 * gm, {"knock": 0.0, "kind": "light", "element": "katon", "burn": 1.5, "pierce_guard": true, "hitstop": 0.0}))))


## Dangai: yerde açılan boyalı uçurum ağzı; kenar kaya dudakları içe devrilir, taşlar boşluğa düşer
static func _chasm(pj: PathJutsu, at: Vector3, life: float) -> Node3D:
	var root = Node3D.new()
	pj.scene_add(root, at + Vector3.UP * 0.03)
	var hole = _mi(_disc(1.9, 36, 0.12), _smat("chasm", "unshaded, cull_disabled", SH_CHASM))
	root.add_child(hole)
	hole.scale = Vector3(0.2, 1, 0.2)
	hole.create_tween().tween_property(hole, "scale", Vector3.ONE, 0.22).set_ease(Tween.EASE_OUT)
	var rm = _cel_mat(0.5, true)
	var lips = []
	for k in 7:
		var a = TAU * k / 7.0 + randf() * 0.3
		var pv = Node3D.new()
		root.add_child(pv)
		pv.position = Vector3(cos(a), 0, sin(a)) * 2.0
		pv.basis = Basis.looking_at(-Vector3(cos(a), 0, sin(a)), Vector3.UP)   # -Z merkeze
		var o = PackedVector2Array([Vector2(-0.55, 0.0), Vector2(-0.4, -0.45 - randf() * 0.2), Vector2(-0.1, -0.75), Vector2(0.25, -0.6 - randf() * 0.2), Vector2(0.55, -0.3), Vector2(0.5, 0.0)])
		var lb = MB.new()
		_slab_flat(lb, o, 0.32, Color(0.44, 0.45, 0.52), Vector3.UP * 0.12)
		pv.add_child(_mi(lb.build(), rm))
		var tw = pv.create_tween()
		tw.tween_interval(0.08 + k * 0.03)
		tw.tween_property(pv, "rotation:x", -randf_range(0.35, 0.6), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		lips.append(pv)
	for k in 10:   # boşluğa yuvarlanan taşlar
		var a = randf() * TAU
		var rb = MB.new()
		rb.add("boulder", Vector3.ZERO, Vector3.ONE * randf_range(0.18, 0.32), Color(0.4, 0.41, 0.48), Vector3.ZERO, k % 4)
		var rk = _mi(rb.build(), rm)
		root.add_child(rk)
		rk.position = Vector3(cos(a), 0.15, sin(a)) * 1.8
		var tw2 = rk.create_tween()
		tw2.tween_interval(0.1 + randf() * 0.4)
		tw2.tween_property(rk, "position", Vector3(cos(a) * 0.5, -1.4, sin(a) * 0.5), 0.55).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_property(rk, "scale", Vector3.ONE * 0.05, 0.55)
	_flecks(pj, at + Vector3.UP * 0.2, [Color(0.55, 0.5, 0.45), Color(0.4, 0.38, 0.36), Color(0.7, 0.65, 0.58)], 22, 2.0, 0.9, 0.22, 1.5, Vector3.UP, 60.0, 1.6)
	# yanılsama kırılır: dudaklar düzleşir, hepsi söner
	var lw = []
	for pv in lips:
		lw.append(weakref(pv))
	root.get_tree().create_timer(maxf(0.1, life - 0.35)).timeout.connect(func():
		for w in lw:
			var pv2 = w.get_ref()
			if pv2 != null and is_instance_valid(pv2):
				(pv2 as Node3D).create_tween().tween_property(pv2, "rotation:x", 0.0, 0.2))
	_fade_free(root, maxf(0.1, life - 0.3), 0.35)
	return root


## Dangai darbesi: yerde dışa yarılan mürekkep çatlakları + yere vuran toz
static func _cliff_impact(pj: PathJutsu, at: Vector3) -> void:
	var root = Node3D.new()
	pj.scene_add(root, at + Vector3.UP * 0.05)
	var m = _paint_mat(0.4)
	m.set_shader_parameter("u_reveal", 0.0)
	for k in 7:
		var a = TAU * k / 7.0 + randf_range(-0.2, 0.2)
		var pts = PackedVector3Array()
		var w = PackedFloat32Array()
		var L = randf_range(1.5, 2.6)
		for i in 7:
			var u = i / 6.0
			var aa = a + randf_range(-0.18, 0.18)
			pts.append(Vector3(cos(aa), 0, sin(aa)) * (0.3 + u * L))
			w.append(lerpf(0.2, 0.03, u))
		root.add_child(_mi(_ribbon(pts, w, Vector3.UP, PackedColorArray([Color(0.1, 0.08, 0.12)])), m))
	root.create_tween().tween_method(func(v: float): m.set_shader_parameter("u_reveal", v), 0.0, 1.05, 0.12)
	_fade_free(root, 1.2, 0.4)
	_flecks(pj, at + Vector3.UP * 0.15, [Color(0.6, 0.55, 0.48), Color(0.45, 0.42, 0.4)], 26, 5.0, 0.7, 0.3, 4.0, Vector3.UP, 80.0, 0.5)


## Kurama Genjutsu: Dangai — kurbanın ayağının altında uçurum açılır; düştüğüne inanan beden darbeyi gerçekten alır
static func kurama_genjutsu_dangai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.9)
	var id = "kurama_genjutsu_dangai"
	pj._face(c, tt)
	var col = Color(0.45, 0.55, 0.75)
	_canvas(pj, c, col, "cliff", 1.0, tt)
	Sfx.play("genjutsu", c.global_position, 0.9)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.4, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var gm = _land(pj, cc, x, col)
		if gm <= 0.0:
			return
		var at: Vector3 = pj.gp(x.global_position)
		_chasm(pj, at, 1.4 + 0.3)
		pj.st(x, "bind", 1.4)
		Combat.popup_text(at + Vector3.UP * 3.0, "Uçurumdan düşüyor!", Color(0.6, 0.65, 0.9))
		if x.get("model"):   # beden düşer gibi yere çöker (yalnız görüntü: genjutsu)
			var mm = x.model
			var t2 = mm.create_tween()
			t2.tween_property(mm, "position:y", mm.position.y - 1.2, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t2.tween_property(mm, "position:y", mm.position.y, 0.25)
		pj.after(0.55, func():
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 == null or x2 == null or not pj.live(x2):
				return
			pj.shake(0.6)
			Sfx.play("boom", x2.global_position, 0.8)
			_cliff_impact(pj, pj.gp(x2.global_position))
			x2.take_hit(pj.inf(c2, id, 2.6 * gm, {"knock": 0.0, "kind": "heavy", "stun": 1.4, "pierce_guard": true, "hitstop": 0.12}))))


## Ido: büyücünün arkasında yerden mürekkep gibi yükselen dev yanılsama canavarı (kambur gövde, kemik boynuzlar,
## dişli ağız, sarı gözler, yere sarkan pençeli uzun kollar); kollarından mürekkep damlar, tepesinden mürekkep tüter
static func _ido_beast(pj: PathJutsu, c: Node3D, life: float) -> Node3D:
	var fd: Vector3 = c.face_dir()
	fd.y = 0.0
	fd = fd.normalized() if fd.length() > 0.01 else Vector3.FORWARD
	var root = Node3D.new()
	pj.scene_add(root, pj.gp(c.global_position - fd * 2.0))
	root.global_basis = Basis.looking_at(-fd, Vector3.UP)   # +Z büyücünün baktığı yöne
	var dk = Color(0.1, 0.05, 0.13)
	var b = MB.new()
	b.add_grad("sphere", Vector3(0, 3.0, 0), Vector3(2.5, 3.4, 1.7), Color(0.2, 0.1, 0.24), dk, Vector3(12, 0, 0), 14)   # kambur gövde
	b.add("sphere", Vector3(0, 4.2, -0.25), Vector3(2.9, 1.6, 1.6), dk, Vector3.ZERO, 12)   # omuz kütlesi
	b.add_grad("sphere", Vector3(0, 5.3, 0.45), Vector3(1.4, 1.25, 1.3), Color(0.18, 0.09, 0.22), dk, Vector3.ZERO, 12)   # baş
	b.add("sphere", Vector3(0, 4.95, 0.95), Vector3(0.9, 0.35, 0.4), Color(0.02, 0.0, 0.03), Vector3.ZERO, 10)   # açık ağız
	for k in 5:   # dişler
		var x = -0.32 + k * 0.16
		b.add("cone", Vector3(x, 5.08, 1.08), Vector3(0.08, 0.2, 0.08), Color(0.9, 0.86, 0.75), Vector3(180, 0, 0), 5)
		b.add("cone", Vector3(x + 0.08, 4.82, 1.08), Vector3(0.07, 0.16, 0.07), Color(0.9, 0.86, 0.75), Vector3.ZERO, 5)
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(sx * 0.5, 6.2, 0.2), Vector3(0.28, 1.3, 0.28), Color(0.86, 0.82, 0.74), Vector3(-15, 0, -sx * 28), 6)   # boynuz
		b.add("sphere", Vector3(sx * 0.5, 1.0, 0.1), Vector3(0.9, 2.0, 0.9), dk, Vector3.ZERO, 8)   # bacak kütlesi
	var bm = _cel_mat(0.9)
	bm.set_shader_parameter("u_clip", -0.5)
	root.add_child(_mi(b.build(), bm))
	var mats = [[bm, 0.0]]
	# gözler (yükseliş bitince yanar)
	var eb = MB.new()
	for sx in [-1.0, 1.0]:
		eb.add("sphere", Vector3(sx * 0.36, 5.5, 1.02), Vector3(0.26, 0.13, 0.08), Color(1.0, 0.85, 0.2), Vector3(0, 0, sx * 12), 8)
	var em = StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.vertex_color_use_as_albedo = true
	em.emission_enabled = true
	em.emission = Color(1.0, 0.8, 0.2)
	em.emission_energy_multiplier = 2.0
	var eyes = _mi(eb.build(), em)
	eyes.visible = false
	root.add_child(eyes)
	# kollar: omuz pivotundan sarkan uzun tüp + üç pençe; hafifçe sallanır
	for sx in [-1.0, 1.0]:
		var pv = Node3D.new()
		root.add_child(pv)
		pv.position = Vector3(sx * 1.25, 4.3, 0.1)
		var pts = PackedVector3Array([Vector3.ZERO, Vector3(sx * 0.9, -1.2, 0.6), Vector3(sx * 1.2, -2.6, 1.3), Vector3(sx * 0.95, -3.7, 1.9), Vector3(sx * 0.8, -4.05, 2.15)])
		var ab = MB.new()
		for k in 3:
			var base = Vector3(sx * 0.8 + (k - 1) * 0.15, -4.05, 2.15)
			_seg(ab, base, base + Vector3((k - 1) * 0.12, -0.25, 0.45), 0.05, Color(0.85, 0.8, 0.72))
		var am = _cel_mat(0.9, true)
		am.set_shader_parameter("u_clip", -0.5 - 4.3)
		var arm = _mi(_tube(pts, PackedFloat32Array([0.5, 0.42, 0.34, 0.24, 0.16]), PackedColorArray([dk]), 9), am)
		pv.add_child(arm)
		var claws = _mi(ab.build(), am)
		pv.add_child(claws)
		mats.append([am, -4.3])
		var sw = Game.safe_loops(pv.create_tween(), int(life / 1.4) + 1)
		sw.tween_property(pv, "rotation", Vector3(0.18, 0, sx * 0.08), 0.7).set_trans(Tween.TRANS_SINE)
		sw.tween_property(pv, "rotation", Vector3(-0.1, 0, -sx * 0.05), 0.7).set_trans(Tween.TRANS_SINE)
	var set_clip = func(v: float):
		for mm in mats:
			(mm[0] as ShaderMaterial).set_shader_parameter("u_clip", v + float(mm[1]))
	var tw = root.create_tween()
	tw.tween_method(set_clip, -0.5, 7.6, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_callback(eyes.show)
	tw.tween_interval(maxf(0.1, life - 1.0))
	tw.tween_callback(eyes.hide)
	tw.tween_method(set_clip, 7.6, -0.5, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	# mürekkep damlaları (kollardan) + tepeden tüten mürekkep
	_emitter(root, Vector3(0, 2.5, 1.0), [Color(0.14, 0.06, 0.18), Color(0.3, 0.12, 0.36), INK], 24, 0.8, Vector2(0.12, 0.16), 9.0, Vector3.DOWN, 0.5, Vector3(2.0, 1.2, 0.8), life - 0.5)
	_emitter(root, Vector3(0, 6.0, 0.2), [Color(0.2, 0.08, 0.26), Color(0.1, 0.04, 0.12)], 16, 1.2, Vector2(0.3, 0.3), -1.2, Vector3.UP, 0.8, Vector3(1.0, 0.3, 0.6), life - 0.5)
	return root


## Ido pençesi: kurbanın üstüne çekilen üç mor mürekkep yırtığı
static func _ink_claw(pj: PathJutsu, e: Node3D, from: Vector3) -> void:
	var root = Node3D.new()
	pj.scene_add(root, e.global_position + Vector3.UP * 1.1)
	var d: Vector3 = from - e.global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else Vector3.BACK
	root.global_basis = Basis.looking_at(-d, Vector3.UP)   # +Z saldırana
	var m = _paint_mat(0.9)
	m.set_shader_parameter("u_reveal", 0.0)
	m.set_shader_parameter("u_core", 0.2)
	for k in 3:
		var o = (k - 1) * 0.22
		var pts = _smooth(PackedVector3Array([Vector3(-0.55 + o, 0.65, 0.45), Vector3(o * 0.6, 0.0, 0.5), Vector3(0.5 + o, -0.6, 0.45)]), 5)
		var w = PackedFloat32Array()
		for i in pts.size():
			w.append(0.16 * sin(PI * clampf(float(i) / (pts.size() - 1), 0.08, 0.92)))
		root.add_child(_mi(_ribbon(pts, w, Vector3.BACK, PackedColorArray([Color(0.45, 0.13, 0.55)])), m))
	root.create_tween().tween_method(func(v: float): m.set_shader_parameter("u_reveal", v), 0.0, 1.05, 0.08)
	_fade_free(root, 0.3, 0.3)
	_flecks(pj, e.global_position + Vector3.UP * 1.1, [Color(0.45, 0.13, 0.55), INK], 12, 4.0, 0.5, 0.14, 6.0, d, 50.0)


## Ido — bilinçaltının ikinci kişiliği salınır: arkanda dev kara yanılsama canavarı; bakışını yakalayan herkes korkuyla
## sersemler ve ezilir. Bedel: Ido sahibinin canından da yer
static func kurama_ido(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.4)
	var id = "kurama_ido"
	var cw = weakref(c)
	pj._yama_seal(c)
	_ido_beast(pj, c, 4.2)
	Sfx.play("roar", c.global_position, 0.6)
	if c == Game.player and Game.world:
		Game.world.env.flash_tint(Color(0.3, 0.05, 0.35, 0.25), 1.5)
	var hit_once = {}
	pj.every(3.6, 0.3, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if i % 4 == 0 and "hp" in cc:   # bedel: Ido sahibinden de yer
			cc.hp = maxf(1.0, cc.hp - cc.max_hp * 0.015)
		for e in pj.enemies_near(cc, cc.global_position, 14.0):
			var key = e.get_instance_id()
			if hit_once.has(key):
				continue
			if Eyes.genjutsu_land(cc, e, true) <= 0.0:
				hit_once[key] = true
				continue
			hit_once[key] = true
			_mark(pj, e, Color(0.5, 0.2, 0.55), 2.0)
			pj.st(e, "fear", 2.0)
			_ink_claw(pj, e, cc.global_position)
			e.take_hit(pj.inf(cc, id, 1.8, {"knock": 6.0, "launch": 2.0, "kind": "heavy", "stun": 1.6, "pierce_guard": true, "hitstop": 0.08})))


## Ingen Shibari sarmaşığı (referans: koyu yeşil, açık çizgili kalın sap; bedene sıkı sarmal sarılır; yürek yapraklar;
## uçta kıvrık filiz). Yerden boy boyu uzayarak belirir; malzemeyi döndürür (söndürmek için)
static func _vine(root: Node3D, a0: float, bs: float, turns: float, hh: float, r0: float, grow_t: float, delay: float) -> ShaderMaterial:
	var pts = PackedVector3Array()
	var rad = PackedFloat32Array()
	var cols = PackedColorArray()
	var N = 30
	for q in N:
		var u = q / float(N - 1)
		var a = a0 + u * TAU * turns
		var rr = (r0 - u * 0.12) * bs * (1.0 + 0.1 * sin(u * 17.0))
		pts.append(Vector3(cos(a) * rr, (0.02 + u * hh) * bs, sin(a) * rr))
		rad.append(lerpf(0.085, 0.04, u) * bs)
		cols.append(Color(0.22, 0.42, 0.2).lerp(Color(0.36, 0.6, 0.32), u))
	var last: Vector3 = pts[N - 1]
	var la = a0 + TAU * turns
	for q in 8:   # kıvrık filiz
		var a = la + q * 0.9
		var r = 0.14 * (1.0 - q / 8.0) * bs
		pts.append(last + Vector3(cos(a) * r, q * 0.03 * bs, sin(a) * r) + Vector3(cos(la), 0, sin(la)) * 0.12 * bs)
		rad.append(0.03 * bs * (1.0 - q / 9.0))
		cols.append(Color(0.4, 0.66, 0.34))
	var m = _cel_mat(0.85, true)
	m.set_shader_parameter("u_reveal", 0.0)
	m.set_shader_parameter("u_stripe", 3.0)
	root.add_child(_mi(_tube(pts, rad, cols, 7), m))
	var tw = root.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float): m.set_shader_parameter("u_reveal", v), 0.0, 1.02, grow_t).set_ease(Tween.EASE_OUT)
	# yürek yapraklar: sap geçtikçe açılır
	var heart = PackedVector2Array()
	for s in 16:
		var th = TAU * s / 16.0
		heart.append(Vector2(16.0 * pow(sin(th), 3.0), 13.0 * cos(th) - 5.0 * cos(2.0 * th) - 2.0 * cos(3.0 * th) - cos(4.0 * th)) * 0.011 * bs)
	for q in range(3, N - 1, 4):
		var u = q / float(N - 1)
		var p: Vector3 = pts[q]
		var out = Vector3(p.x, 0, p.z).normalized()
		var lb = MB.new()
		_slab_xy(lb, heart, 0.012, Color(0.42, 0.7, 0.36))
		var leaf = _mi(lb.build(), _cel_mat(0.7, true))
		root.add_child(leaf)
		leaf.position = p + out * rad[q]
		leaf.basis = Basis.looking_at(-out, Vector3.UP).rotated(out, randf_range(-0.6, 0.6))
		leaf.scale = Vector3.ONE * 0.01
		var lt = leaf.create_tween()
		lt.tween_interval(delay + u * grow_t)
		lt.tween_property(leaf, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return m


## Kurama Genjutsu: Ingen Shibari — kurbanın çevresinden fasulye sarmaşıkları büyüyüp onu sıkıca sarar; arkasında
## dev fasulye sapı yükselir (referans 2)
static func kurama_ingen_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.9)
	var id = "kurama_ingen_shibari"
	pj._face(c, tt)
	var col = Color(0.35, 0.7, 0.25)
	_canvas(pj, c, col, "vine", 1.0, tt)
	Sfx.play("genjutsu", c.global_position, 1.0)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.4, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var gm = _land(pj, cc, x, col)
		if gm <= 0.0:
			return
		var at: Vector3 = pj.gp(x.global_position)
		var bs = ClanJutsu.body_scale(x)
		var root = Node3D.new()
		pj.scene_add(root, at)
		var hold = 2.0 * gm
		var mats = []
		for k in 5:   # bedene sarmal sarılan sarmaşıklar
			mats.append(_vine(root, k * TAU / 5.0, bs, 1.6 + k * 0.12, 1.9 + (k % 2) * 0.25, 0.5, 0.35, k * 0.05))
		# arkada dev fasulye sapı: S kıvrımlı kalın sap, iki dev yaprak, kabuk
		var back: Vector3 = at - cc.global_position
		back.y = 0.0
		back = back.normalized() if back.length() > 0.1 else Vector3.BACK
		var sp = PackedVector3Array()
		var sr = PackedFloat32Array()
		for q in 12:
			var u = q / 11.0
			sp.append(back * (0.9 + sin(u * 3.0) * 0.4) * bs + back.cross(Vector3.UP) * sin(u * 5.0) * 0.35 * bs + Vector3.UP * u * 3.8 * bs)
			sr.append(lerpf(0.22, 0.08, u) * bs)
		var sm = _cel_mat(0.85, true)
		sm.set_shader_parameter("u_reveal", 0.0)
		sm.set_shader_parameter("u_stripe", 2.0)
		root.add_child(_mi(_tube(sp, sr, PackedColorArray([Color(0.33, 0.58, 0.33)]), 9), sm))
		mats.append(sm)
		root.create_tween().tween_method(func(v: float): sm.set_shader_parameter("u_reveal", v), 0.0, 1.02, 0.4).set_ease(Tween.EASE_OUT)
		var pb = MB.new()
		var top: Vector3 = sp[11]
		pb.add_grad("sphere", top + Vector3(0, -0.3, 0) * bs - back * 0.3 * bs, Vector3(0.4, 1.3, 0.34) * bs, Color(0.5, 0.75, 0.45), Color(0.3, 0.55, 0.3), Vector3(0, 0, 14), 10)   # kabuk
		for s in 3:
			pb.add("sphere", top + Vector3(0, -0.75 + s * 0.42, 0) * bs - back * 0.42 * bs, Vector3(0.3, 0.34, 0.24) * bs, Color(0.46, 0.72, 0.42), Vector3.ZERO, 8)
		for s in 2:
			var lp: Vector3 = sp[4 + s * 4]
			var side = back.cross(Vector3.UP) * (1.0 if s == 0 else -1.0)
			pb.add_grad("sphere", lp + side * 0.55 * bs, Vector3(0.9, 0.08, 0.55) * bs, Color(0.45, 0.72, 0.4), Color(0.3, 0.52, 0.3), Vector3(0, 0, 25 if s == 0 else -25), 10)
		var pod = _mi(pb.build(), _cel_mat(0.85))
		root.add_child(pod)
		pod.scale = Vector3.ONE * 0.01
		var pt = pod.create_tween()
		pt.tween_interval(0.35)
		pt.tween_property(pod, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_flecks(pj, at + Vector3.UP * 0.1, [Color(0.45, 0.35, 0.22), Color(0.3, 0.5, 0.25)], 16, 3.0, 0.6, 0.16, 6.0, Vector3.UP, 60.0, 0.6)
		# sarmaşıklar geri çekilir, söner
		var rt = root.create_tween()
		rt.tween_interval(0.4 + hold)
		rt.tween_method(func(v: float):
			for m in mats:
				(m as ShaderMaterial).set_shader_parameter("u_reveal", v), 1.02, 0.0, 0.3)
		rt.parallel().tween_property(pod, "scale", Vector3.ONE * 0.01, 0.3)
		rt.tween_callback(root.queue_free)
		pj.st(x, "bind", 2.2 * gm)
		x.take_hit(pj.inf(cc, id, 0.6 * gm, {"knock": 0.0, "kind": "heavy", "hitstop": 0.05, "sure": true})))


## Kurama Genjutsu: Kokū Rakka — yer yıldızlı bir boşluğa açılır: yırtık kâğıt kenarlı girdap, kurbanın çevresinde
## yukarı akan düşüş çizgileri, boşluğa dönerek çekilen kâğıt parçaları; sonra "yere çarpma" fırça halkası
static func kurama_koku_rakka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.9)
	var id = "kurama_koku_rakka"
	pj._face(c, tt)
	var col = Color(0.2, 0.15, 0.35)
	_canvas(pj, c, col, "void", 1.0, tt)
	Sfx.play("genjutsu", c.global_position, 0.8)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.4, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var gm = _land(pj, cc, x, col)
		if gm <= 0.0:
			return
		var at: Vector3 = pj.gp(x.global_position)
		var root = Node3D.new()
		pj.scene_add(root, at + Vector3.UP * 0.03)
		var hole = _mi(_disc(1.8, 40, 0.1), _smat("void", "unshaded, cull_disabled", SH_VOID))
		root.add_child(hole)
		hole.scale = Vector3(0.1, 1, 0.1)
		var ht = hole.create_tween()
		ht.tween_property(hole, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
		ht.parallel().tween_property(hole, "rotation:y", -2.0, 1.4 * gm + 0.25).as_relative()
		ht.tween_property(hole, "scale", Vector3(0.05, 1, 0.05), 0.2).set_ease(Tween.EASE_IN)
		ht.tween_callback(root.queue_free)
		# düşüş hissi: kurbanın çevresinde yukarı fırlayan ince çizgiler
		var sp = _emitter(root, Vector3.UP * 0.4, [Color(0.85, 0.82, 1.0), Color(0.6, 0.5, 0.9)], 22, 0.35, Vector2(0.04, 1.1), 0.0, Vector3.UP, 13.0, Vector3(1.1, 0.3, 1.1), 1.4 * gm, "streak")
		sp.spread = 2.0
		# boşluğa dönerek çekilen kâğıt parçaları
		var pp = _emitter(root, Vector3.UP * 0.15, [Color(0.93, 0.88, 0.76), Color(0.8, 0.74, 0.62)], 18, 1.0, Vector2(0.14, 0.1), -0.3, Vector3.UP, 0.4, Vector3(2.2, 0.05, 2.2), 1.4 * gm)
		pp.radial_accel_min = -6.0
		pp.radial_accel_max = -4.0
		pp.tangential_accel_min = 3.0
		pp.tangential_accel_max = 5.0
		pj.st(x, "bind", 1.4 * gm)
		pj.after(1.4 * gm, func():
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2):
				return
			var gp2: Vector3 = pj.gp(x2.global_position)
			_brush_ring(pj, gp2 + Vector3.UP * 0.06, 1.3, Color(0.6, 0.45, 0.85), 0.35)
			_flecks(pj, x2.global_position + Vector3.UP * 0.4, [Color(0.9, 0.85, 1.0), Color(0.6, 0.45, 0.85), Color(0.3, 0.2, 0.45)], 18, 5.0, 0.5, 0.12, 6.0, Vector3.UP, 85.0)
			Sfx.play("boom", x2.global_position, 0.7)
			pj.shake(0.3)
			x2.take_hit(pj.inf(c2, id, 1.6 * gm, {"knock": 0.0, "launch": -3.0, "kind": "heavy", "stun": 0.8, "hitstop": 0.12, "sure": true}))))


## Hakuchūmu çerçevesi: kurbanın çevresinde dikilen altın resim çerçevesi (dört ayrı çıta: son darbede dağılır)
static func _frame(pj: PathJutsu, x: Node3D, face: Vector3) -> Array:
	var root = Node3D.new()
	pj.scene_add(root, x.global_position + Vector3.UP * 1.25)
	root.global_basis = Basis.looking_at(-face, Vector3.UP)   # +Z büyücüye
	var gold = Color(0.84, 0.64, 0.24)
	var dark = Color(0.5, 0.34, 0.12)
	var m = _cel_mat(0.6)
	m.set_shader_parameter("u_emit", Color(1.0, 0.8, 0.4, 0.1))
	var bars = []
	var spec = [[Vector3(0, 1.35, 0), Vector3(1.9, 0.16, 0.12)], [Vector3(0, -1.35, 0), Vector3(1.9, 0.16, 0.12)], [Vector3(-0.87, 0, 0), Vector3(0.16, 2.86, 0.12)], [Vector3(0.87, 0, 0), Vector3(0.16, 2.86, 0.12)]]
	for s in spec:
		var b = MB.new()
		var sz: Vector3 = s[1]
		b.add("box", Vector3.ZERO, sz, gold)
		b.add("box", Vector3(0, 0, 0.05), Vector3(maxf(0.05, sz.x - 0.08), maxf(0.05, sz.y - 0.08), 0.04), dark)
		for e in [-1.0, 1.0]:   # köşe gülleri
			var ep = Vector3(e * sz.x * 0.5, 0, 0) if sz.x > sz.y else Vector3(0, e * sz.y * 0.5, 0)
			b.add("sphere", ep + Vector3(0, 0, 0.04), Vector3(0.2, 0.2, 0.1), gold.lightened(0.15), Vector3.ZERO, 8)
		var mi = _mi(b.build(), m)
		root.add_child(mi)
		mi.position = s[0]
		bars.append(mi)
	root.scale = Vector3.ONE * 1.3
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.free_after(3.0, root)
	return [root, bars]


## Kurama Genjutsu: Hakuchūmu — kurbanın gözünde dünya donmuş bir resme döner (tuval dokusu üstüne biner, altın çerçeve
## dikilir); art arda üç darbe: her birinde resim biraz daha çatlar, üçüncüde çerçeve dağılır
static func kurama_hakuchumu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.3)
	var id = "kurama_hakuchumu"
	pj._face(c, tt)
	var col = Color(0.95, 0.92, 0.8)
	_canvas(pj, c, col, "frame", 0.9, tt)
	Sfx.play("genjutsu", c.global_position, 1.3)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.35, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var gm = _land(pj, cc, x, col)
		if gm <= 0.0:
			return
		pj.st(x, "bind", 1.2)
		var ov = _smat("frozen", "unshaded, cull_back", SH_FROZEN)   # rakip donmuş bir tuval resmine bürünür
		ov.set_shader_parameter("u_crack", 0.0)
		var xm = x.get("model")
		var mats = []
		if xm and is_instance_valid(xm):
			for mi in (xm as Node).find_children("*", "MeshInstance3D", true, false):
				var g = mi as MeshInstance3D
				if g.material_overlay == null:
					g.material_overlay = ov
					mats.append(weakref(g))
		var face: Vector3 = cc.global_position - x.global_position
		face.y = 0.0
		face = face.normalized() if face.length() > 0.1 else Vector3.BACK
		var fr = _frame(pj, x, face)
		var froot: Node3D = fr[0]
		var bars: Array = fr[1]
		var fw = weakref(froot)
		for k in 3:
			pj.after(0.15 + k * 0.32, func():
				var c2 = cw.get_ref()
				var x2 = tw.get_ref()
				if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2):
					return
				var v: Vector3 = x2.global_position - c2.global_position
				v.y = 0
				if v.length() > 1.6:   # dibine
					c2.global_position = pj.gp(x2.global_position - v.normalized() * 1.2)
				pj._face(c2, x2)
				pj.anim(c2, ["jab", "hook", "cross"][k], 2.4)
				ov.set_shader_parameter("u_crack", (k + 1) / 3.0)   # resim çatlar
				var hp: Vector3 = x2.global_position + Vector3.UP * 1.2
				_flecks(pj, hp, [Color(0.95, 0.9, 0.78), Color(0.85, 0.78, 0.6), INK], 6 + k * 4, 4.0, 0.6, 0.14, 8.0, v.normalized() if v.length() > 0.1 else Vector3.UP, 60.0, 0.2)
				var fo = fw.get_ref()
				if fo != null and is_instance_valid(fo):
					var jt = (fo as Node3D).create_tween()
					var base: Vector3 = (fo as Node3D).global_position
					jt.tween_property(fo, "global_position", base + Vector3(randf_range(-0.08, 0.08), randf_range(-0.05, 0.05), randf_range(-0.08, 0.08)), 0.04)
					jt.tween_property(fo, "global_position", base, 0.06)
					if k == 2:   # çerçeve dağılır, tuval parçaları savrulur
						for bar in bars:
							if is_instance_valid(bar):
								var bt = (bar as Node3D).create_tween()
								var dir = (bar as Node3D).position.normalized()
								bt.tween_property(bar, "position", (bar as Node3D).position + dir * 1.6 + Vector3(0, 0, -0.8), 0.45).set_ease(Tween.EASE_OUT)
								bt.parallel().tween_property(bar, "rotation", Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), 0.45)
						_fade_free(fo, 0.2, 0.3)
						_flecks(pj, hp, [Color(0.95, 0.9, 0.78), Color(0.9, 0.84, 0.66), Color(0.84, 0.64, 0.24)], 26, 7.0, 0.9, 0.24, 7.0, Vector3.UP, 180.0, 0.6)
				Sfx.play("punch", x2.global_position, 1.0 + k * 0.1)
				x2.take_hit(pj.inf(c2, id, (0.5 if k < 2 else 1.0) * gm, {"knock": 2.0 if k < 2 else 10.0, "kind": "heavy", "hitstop": 0.06, "pierce_guard": true}))
				if k == 2:
					for w in mats:
						var g = w.get_ref()
						if g != null and is_instance_valid(g):
							g.material_overlay = null))


## Kurama Genjutsu: Gakaku Hōkai — kurbanın çevresine panorama tuvali çekilir, çatlak ağı yayılır; tuval keskin renkli
## boya parçalarına bölünüp her yönden ona saplanır; yerde renkli boya sıçramaları kalır
static func kurama_gakaku_hokai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.0)
	var id = "kurama_gakaku_hokai"
	pj._face(c, tt)
	var col = Color(0.55, 0.35, 0.85)
	_canvas(pj, c, col, "shatter", 1.1, tt)
	Sfx.play("genjutsu", c.global_position, 0.9)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.45, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var gm = _land(pj, cc, x, col)
		if gm <= 0.0:
			return
		var at: Vector3 = x.global_position + Vector3.UP * 1.0
		# panorama tuvali (alttan boyanarak yükselir, çatlar)
		var cyl = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 3.0
		cm.bottom_radius = 3.0
		cm.height = 3.2
		cm.radial_segments = 40
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		cyl.mesh = cm
		var pm = _smat("pano", "unshaded, cull_disabled", SH_PANO)
		pm.set_shader_parameter("u_rise", 0.0)
		pm.set_shader_parameter("u_crack", 0.0)
		cyl.material_override = pm
		cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pj.scene_add(cyl, pj.gp(x.global_position) + Vector3.UP * 1.6)
		var ct = cyl.create_tween()
		ct.tween_method(func(v: float): pm.set_shader_parameter("u_rise", v), 0.0, 1.0, 0.18)
		ct.tween_method(func(v: float): pm.set_shader_parameter("u_crack", v), 0.0, 1.0, 0.17)
		ct.tween_callback(cyl.queue_free)
		var cols = [Color(0.85, 0.3, 0.3), Color(0.3, 0.55, 0.85), Color(0.95, 0.8, 0.3), Color(0.4, 0.75, 0.4), Color(0.6, 0.4, 0.85)]
		var shards = []
		var sm = _cel_mat(0.7, true)
		for k in 14:   # havada asılı boya parçaları (renkli, sivri) — tuvalin kırıkları
			var a = randf() * TAU
			var el = randf_range(-0.4, 0.8)
			var p: Vector3 = at + Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el)) * 3.0
			var b = MB.new()
			_slab_flat(b, PackedVector2Array([Vector2(0.0, -0.5), Vector2(0.12 + randf() * 0.06, 0.12), Vector2(0.02, 0.2), Vector2(-0.13 - randf() * 0.05, 0.1)]), 0.04, cols[k % cols.size()])
			var s = _mi(b.build(), sm)
			pj.scene_add(s, p)
			s.global_basis = Basis.looking_at((at - p).normalized(), Vector3.UP)
			s.rotate_object_local(Vector3.BACK, randf() * TAU)
			s.visible = false
			shards.append(s)
		pj.after(0.35, func():
			var x2 = tw.get_ref()
			for s in shards:
				if is_instance_valid(s):
					s.visible = true
					var st_ = s.create_tween()
					st_.tween_property(s, "global_position", at, 0.18).set_ease(Tween.EASE_IN)
					st_.tween_callback(s.queue_free)
			pj.after(0.18, func():
				var c2 = cw.get_ref()
				var x3 = tw.get_ref()
				if c2 == null or x3 == null or not pj.live(c2) or not pj.live(x3):
					return
				_flecks(pj, at, cols, 26, 7.0, 0.7, 0.16, 8.0, Vector3.UP, 180.0, 0.3)
				var gb = MB.new()   # yerde renkli boya sıçramaları
				for q in 6:
					var aa = randf() * TAU
					_slab_flat(gb, _splat_outline(randf_range(0.25, 0.5), 10, 0.7), 0.02, cols[q % cols.size()], Vector3(cos(aa), 0.0, sin(aa)) * randf_range(0.4, 1.5) + Vector3.UP * q * 0.003)
				var gm2 = _mi(gb.build(), _cel_mat(0.0, true))
				pj.scene_add(gm2, pj.gp(x3.global_position) + Vector3.UP * 0.03)
				_fade_free(gm2, 1.8, 0.5)
				Sfx.play("clink", at, 1.6)
				x3.take_hit(pj.inf(c2, id, 1.6 * gm, {"knock": 4.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1, "sure": true})))))


# ================================================================== Aburame: kikaichū sürüsü
## Tek MultiMesh ile yüzlerce böcek; her karede hedef konuma kayar, gittiği yöne döner, sonda küçülerek kaybolur.
## Kipler: cloud (bulut), shell (küre kabuk), body (insan silueti), crawl (bedende sürünme), wall (duvar yüzeyi),
## weave (koza örgüsü), stream (A'dan B'ye akış; bitince "next" kipine geçer), scatter (dağılma, yavaş düşüş)
class BugSwarm extends MultiMeshInstance3D:
	var n := 0
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var sd := PackedFloat32Array()
	var buf := PackedFloat32Array()
	var mode := "cloud"
	var prm := {}
	var anchor: WeakRef = null
	var off := Vector3.ZERO
	var center := Vector3.ZERO
	var t := 0.0
	var mt := 0.0
	var life := 3.0
	var size := 0.06
	var rate := 7.0
	var jit := 1.2

	func begin(count: int, mesh: Mesh, mat: Material, sz: float, lf: float, start: Vector3, spread: float) -> void:
		n = count
		size = sz
		life = lf
		center = start
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = n
		multimesh = mm
		material_override = mat
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
		pos.resize(n)
		vel.resize(n)
		sd.resize(n)
		buf.resize(n * 12)
		for i in n:
			pos[i] = start + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread
			vel[i] = Vector3.ZERO
			sd[i] = randf()
		_write(true)

	func go(m: String, p := {}) -> void:
		mode = m
		mt = 0.0
		for k in p:
			prm[k] = p[k]
		if m == "scatter":
			var cen := _cen()
			var sp := float(prm.get("burst", 4.0))
			for i in n:
				var d: Vector3 = pos[i] - cen
				if d.length() < 0.01:
					d = Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1))
				vel[i] = d.normalized() * sp * (0.4 + sd[i]) + Vector3.UP * randf() * sp * 0.3

	func end_in(sec: float) -> void:
		life = minf(life, t + sec)

	func _cen() -> Vector3:
		if anchor != null:
			var a = anchor.get_ref()
			if a != null and is_instance_valid(a):
				center = (a as Node3D).global_position + off
			elif prm.get("die_with_anchor", false) and mode != "scatter":
				go("scatter", {"burst": 2.5})
				end_in(1.0)
		return center

	func _goal(i: int, s: float, cen: Vector3) -> Vector3:
		var R := float(prm.get("r", 1.0))
		var H := float(prm.get("h", 1.0))
		var spin := float(prm.get("spin", 1.5))
		var s2 := fmod(s * 13.73, 1.0)
		var s3 := fmod(s * 31.31, 1.0)
		match mode:
			"cloud":
				var a := s * TAU * 7.0 + mt * spin * (0.6 + s2)
				var rr := R * (0.3 + 0.7 * s2)
				var y := (s3 - 0.5) * H + sin(mt * 2.0 + s * 30.0) * 0.15 * H
				return cen + Vector3(cos(a) * rr, y, sin(a) * rr)
			"shell":
				var yy := 1.0 - 2.0 * (float(i) + 0.5) / float(n)
				var rad := sqrt(maxf(0.0, 1.0 - yy * yy))
				var th := float(i) * 2.39996 + mt * spin * (1.0 if i % 2 == 0 else 0.75)
				var rr := R * (1.22 if s > 0.88 else 1.0) * (1.0 + 0.05 * sin(mt * 7.0 + s * 50.0))
				return cen + Vector3(cos(th) * rad, yy, sin(th) * rad) * rr
			"body":
				var y := s2 * H
				var rr := 0.12
				var lx := 0.0
				if s2 < 0.46:   # bacaklar
					lx = 0.11 if s3 < 0.5 else -0.11
					rr = 0.08
				elif s2 < 0.8:   # gövde + kollar
					rr = 0.2
					if s3 >= 0.78:
						lx = 0.3 if s3 < 0.89 else -0.3
						rr = 0.05
				elif s2 < 0.84:   # boyun
					rr = 0.06
				var a := s * TAU * 11.0 + mt * spin
				return cen + Vector3(lx + cos(a) * rr * R, y, sin(a) * rr * R)
			"crawl":
				var a := s * TAU * 5.0 + mt * spin * (0.5 + s) * (1.0 if s2 > 0.5 else -1.0)
				var rr := R * (1.6 if s > 0.9 else 1.0)
				var y := H * (0.12 + 0.8 * s3)
				return cen + Vector3(cos(a) * rr, y, sin(a) * rr)
			"wall":
				var b: Basis = prm.get("b", Basis.IDENTITY)
				var W := float(prm.get("w", 10.0))
				var x := (s2 - 0.5) * W
				var top := H * (1.0 - absf(s2 - 0.5) * 0.45)
				var y := s3 * top + sin(mt * 3.0 + s * 40.0) * 0.25
				var z := (fmod(s * 7.7, 1.0) - 0.5) * float(prm.get("th", 1.4))
				if s > 0.9:   # tepeden kopup dönen böcekler
					y = top + 0.4 + fmod(mt * 0.8 + s * 5.0, 1.0) * 2.0
					x += sin(mt * 2.0 + s * 20.0) * 0.8
				return cen + b * Vector3(x, y, z)
			"weave":
				var y := fmod(s2 + mt * 0.35 * (0.5 + s), 1.0) * H
				var rr := R * (0.25 + 0.85 * sin(3.14159 * clampf(y / H, 0.05, 0.95)))
				var a := s * TAU * 3.0 + mt * spin * 3.0
				return cen + Vector3(cos(a) * rr, y, sin(a) * rr)
			"stream":
				var from: Vector3 = prm.get("from", cen)
				var to: Vector3 = prm.get("to", cen)
				if prm.get("to_anchor", false):
					to = cen + prm.get("to_off", Vector3.ZERO)
				var u := clampf((mt - s * float(prm.get("spread", 0.3))) / maxf(0.05, float(prm.get("dur", 0.4))), 0.0, 1.0)
				var dv := to - from
				var side := dv.cross(Vector3.UP)
				side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
				var bump := sin(3.14159 * u)
				return from.lerp(to, u) + Vector3.UP * bump * float(prm.get("arc", 0.5)) + side * sin(s * 40.0 + mt * 5.0) * 0.45 * bump + Vector3.UP * cos(s * 23.0 + mt * 6.0) * 0.3 * bump
		return cen

	func _process(dt: float) -> void:
		t += dt
		mt += dt
		if t >= life:
			queue_free()
			return
		var cen := _cen()
		if mode == "stream" and prm.has("next") and mt > float(prm.get("dur", 0.4)) + float(prm.get("spread", 0.3)) + 0.1:
			var nx := String(prm["next"])
			prm.erase("next")
			go(nx)
		var k := 1.0 - exp(-rate * dt)
		var shrink := clampf((life - t) / 0.4, 0.0, 1.0)
		for i in n:
			var s: float = sd[i]
			var p: Vector3 = pos[i]
			var old := p
			if mode == "scatter":
				var v: Vector3 = vel[i]
				v.y -= float(prm.get("grav", 1.5)) * dt
				v *= maxf(0.0, 1.0 - 1.2 * dt)
				vel[i] = v
				p += v * dt
			else:
				var g := _goal(i, s, cen)
				if mode == "stream":
					p = p.lerp(g, minf(1.0, k * 3.0))
				else:
					p = p.lerp(g, minf(1.0, k * (0.5 + s)))
				p += Vector3(sin(t * 23.0 + s * 91.0), sin(t * 19.0 + s * 57.0), cos(t * 21.0 + s * 33.0)) * jit * dt
			pos[i] = p
			_put(i, p, p - old, s, size * (0.8 + 0.4 * s) * shrink)
		multimesh.buffer = buf

	func _put(i: int, p: Vector3, d: Vector3, s: float, sc: float) -> void:
		var z: Vector3
		if d.length_squared() > 1e-8:
			z = -d.normalized()
		else:
			z = Vector3(cos(s * 40.0), 0.0, sin(s * 40.0))
		var x := Vector3.UP.cross(z)
		if x.length_squared() < 1e-4:
			x = Vector3.RIGHT
		x = x.normalized()
		var y := z.cross(x)
		var o := i * 12
		buf[o] = x.x * sc
		buf[o + 1] = y.x * sc
		buf[o + 2] = z.x * sc
		buf[o + 3] = p.x
		buf[o + 4] = x.y * sc
		buf[o + 5] = y.y * sc
		buf[o + 6] = z.y * sc
		buf[o + 7] = p.y
		buf[o + 8] = x.z * sc
		buf[o + 9] = y.z * sc
		buf[o + 10] = z.z * sc
		buf[o + 11] = p.z

	func _write(_first: bool) -> void:
		for i in n:
			_put(i, pos[i], Vector3.ZERO, sd[i], size * (0.8 + 0.4 * sd[i]))
		multimesh.buffer = buf


## Kikaichū (birim boy ~1, ileri = -Z): yuvarlak karın, kanat kını çizgisi, küçük baş, enine bacak çubukları
static func _bug_mesh() -> ArrayMesh:
	var k = "mesh:bug"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	b.add("sphere", Vector3(0, 0, 0.12), Vector3(0.55, 0.4, 0.85), Color(1, 1, 1), Vector3.ZERO, 6)
	b.add("sphere", Vector3(0, 0.03, -0.42), Vector3(0.36, 0.3, 0.32), Color(0.75, 0.75, 0.75), Vector3.ZERO, 6)
	b.add("box", Vector3(0, 0.2, 0.15), Vector3(0.03, 0.04, 0.7), Color(0.4, 0.4, 0.4))
	for z in [-0.15, 0.08, 0.3]:
		b.add("box", Vector3(0, -0.12, z), Vector3(0.95, 0.04, 0.05), Color(0.55, 0.55, 0.55))
	var m = b.build()
	_cache[k] = m
	return m


static func _swarm(pj: PathJutsu, n: int, size: float, kind: String, life: float, start: Vector3, spread: float) -> BugSwarm:
	var sw = BugSwarm.new()
	sw.begin(n, _bug_mesh(), _bug_mat(kind), size, life, start, spread)
	pj.get_tree().current_scene.add_child(sw)
	return sw


## Bedende sürünen böcekler (yalnız görüntü)
static func _crawl(pj: PathJutsu, e: Node3D, dur: float, kind: String, n := 60) -> BugSwarm:
	var h = float(e.get("height")) if e.get("height") != null else 1.8
	var r = float(e.get("radius")) if e.get("radius") != null else 0.38
	var sw = _swarm(pj, n, 0.05, kind, dur, e.global_position + Vector3.UP * h * 0.5, 0.6)
	sw.anchor = weakref(e)
	sw.go("crawl", {"h": h, "r": r * 1.05, "spin": 1.4, "die_with_anchor": true})
	return sw


## Kikaichū yapışması: bedende sürünen kara böcekler + yavaşlatma (kanon: chakrayı yer)
static func _cling(pj: PathJutsu, e: Node3D, dur: float) -> void:
	_crawl(pj, e, dur, "kikai")
	pj.st(e, "slow", dur)


## Böceklerin mermiyi yutması: kapanan kara benek kümesi
static func _gulp(pj: PathJutsu, pos: Vector3) -> void:
	_flecks(pj, pos, [Color(0.06, 0.06, 0.05), Color(0.16, 0.16, 0.15)], 12, 2.5, 0.4, 0.07, 0.0, Vector3.UP, 180.0, 0.25)


# ================================================================== Aburame teknikleri
## Böcek Klonu (referans: kara böcek bulutu beden şeklini alır): kollardan akan kikaichū yan tarafta insan silueti örer;
## klonun üstünde böcekler sürünür; vurulunca kara kütle böceklere ufalanır, yakındakilere yapışır
static func mushi_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var at = c.global_position + c.global_transform.basis.x * 2.5
	var src: Vector3 = pj.hand_pos(c, true).lerp(pj.hand_pos(c, false), 0.5)
	var sw = _swarm(pj, 220, 0.055, "kikai", 1.4, src, 0.25)
	sw.go("stream", {"from": src, "to": at + Vector3.UP * 0.9, "dur": 0.35, "spread": 0.3, "arc": 0.6, "next": "body", "h": 1.75, "r": 1.0, "spin": 2.0})
	sw.center = pj.gp(at)
	Sfx.play("th_bugs", c.global_position, 1.1)
	var d = pj.decoy(c, at, 12.0, func(p: Vector3):
		var crumb = _swarm(pj, 150, 0.055, "kikai", 1.3, p + Vector3.UP * 0.9, 0.5)
		crumb.go("scatter", {"burst": 4.0, "grav": 0.8})
		_flecks(pj, p + Vector3.UP * 1.0, [Color(0.06, 0.06, 0.05), Color(0.12, 0.12, 0.1)], 30, 2.5, 0.8, 0.09, 6.0, Vector3.UP, 120.0, 0.5)
		if not is_instance_valid(c):
			return
		for e in pj.enemies_near(c, p, 5.0):
			_cling(pj, e, 5.0))
	if d != null and is_instance_valid(d):   # klon böceklerden: üstünde sürünen kikaichū
		var cr = _swarm(pj, 45, 0.045, "kikai", 12.0, at + Vector3.UP, 0.5)
		cr.anchor = weakref(d)
		cr.go("crawl", {"h": 1.75, "r": 0.32, "spin": 1.1, "die_with_anchor": true})


## Kidaichū (referans: kalın koyu gri kabuklu, bölüm çizgili, ince uzun eklemli bacaklı dev böcek). İleri = -Z, sırt = +Y;
## phase 0/1: çapraz bacak çiftleri sırayla kalkar
static func _kida_mesh(phase: int) -> ArrayMesh:
	var key = "mesh:kida%d" % phase
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var DK = Color(0.12, 0.13, 0.12)
	var MD = Color(0.26, 0.28, 0.26)
	var LT = Color(0.36, 0.38, 0.35)
	b.add_grad("sphere", Vector3(0, 0.04, 0.2), Vector3(0.5, 0.36, 0.7), MD, DK, Vector3.ZERO, 12)   # karın
	for k in 4:   # bölüm halkaları
		var z = 0.04 + k * 0.11
		var w = sqrt(maxf(0.05, 1.0 - pow((z - 0.2) / 0.35, 2.0)))
		b.add("sphere", Vector3(0, 0.05, z), Vector3(0.51 * w, 0.37 * w, 0.03), DK, Vector3.ZERO, 10)
	b.add_grad("sphere", Vector3(0, 0.08, -0.18), Vector3(0.42, 0.3, 0.32), LT, DK, Vector3.ZERO, 10)   # göğüs kalkanı
	b.add("box", Vector3(0, 0.22, -0.18), Vector3(0.03, 0.03, 0.26), DK)   # kalkan çizgisi
	b.add_grad("sphere", Vector3(0, 0.02, -0.38), Vector3(0.22, 0.18, 0.18), MD, DK, Vector3.ZERO, 8)   # baş
	for sx in [-1.0, 1.0]:
		_seg(b, Vector3(sx * 0.05, 0.08, -0.44), Vector3(sx * 0.2, 0.3, -0.7), 0.012, DK)   # anten
		_seg(b, Vector3(sx * 0.05, -0.04, -0.45), Vector3(sx * 0.0, -0.08, -0.56), 0.02, DK)   # çene
		for k in 3:
			var z = -0.2 + k * 0.17
			var lift = 1.0 if ((k + (0 if sx > 0 else 1) + phase) % 2 == 0) else 0.0
			var hip = Vector3(sx * 0.18, -0.02, z)
			var knee = hip + Vector3(sx * 0.24, 0.2 + lift * 0.06, (k - 1) * 0.08 - lift * 0.05)
			var foot = knee + Vector3(sx * 0.12, -0.46 + lift * 0.1, (k - 1) * 0.09)
			_seg(b, hip, knee, 0.022, DK)
			_seg(b, knee, foot, 0.016, DK)
	var m = b.build()
	_cache[key] = m
	return m


## Kidaichū — Mushikui (kanon: temas!): avuçtan fışkıran kikaichū rakibe akar, dev böcekler bedenine bırakılır;
## kemiklere bağlı deride sürünür, yedikçe büyür; ısırık yerlerinden kan lekeleri sıçrar
static func kidaichu_mushikui(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 3.2)
	if tt == null or tt.global_position.distance_to(c.global_position) > 3.2 + tt.radius:
		if c is Player:
			Hud.msg("Kidaichū için düşmana dokunmalısın (yakın mesafe).", Color(0.85, 0.85, 0.7))
		return
	var palm: Vector3 = pj.hand_pos(c, true)
	var flow = _swarm(pj, 90, 0.06, "kikai", 1.6, palm, 0.15)
	flow.anchor = weakref(tt)
	var th = float(tt.height)
	flow.go("stream", {"from": palm, "dur": 0.25, "spread": 0.15, "arc": 0.2, "to_anchor": true, "to_off": Vector3.UP * th * 0.6, "next": "crawl", "h": th, "r": float(tt.radius) * 1.05, "spin": 1.6, "die_with_anchor": true})
	var mA = _kida_mesh(0)
	var mB = _kida_mesh(1)
	var gmat = _cel_mat(0.8)
	var bones = ["Hips", "Spine", "Chest", "UpperChest", "RightUpperArm", "LeftUpperArm", "RightUpperLeg", "LeftUpperLeg"]
	var bugs = []
	for k in 5:
		var mi = _mi(mA, gmat)
		pj.get_tree().current_scene.add_child(mi)
		mi.global_position = tt.global_position + Vector3.UP * th * 0.6
		mi.scale = Vector3.ONE * 0.01
		bugs.append({"mi": mi, "bone": bones[(k * 3) % bones.size()], "a": randf() * TAU, "sp": randf_range(0.6, 1.2) * (1.0 if k % 2 == 0 else -1.0), "ph": randf() * TAU})
	var dur = 8.0
	var tm = tt.get("model")
	var sk: Skeleton3D = tm.skel if tm and is_instance_valid(tm) else null
	pj.every(dur, 1.0 / 30.0, func(i, k):
		if not pj.live(tt):
			return
		for bg in bugs:
			var mi: MeshInstance3D = bg["mi"]
			if not is_instance_valid(mi):
				continue
			var bxf: Transform3D
			var bi = sk.find_bone(bg["bone"]) if sk and is_instance_valid(sk) else -1
			if bi >= 0:
				bxf = sk.global_transform * sk.get_bone_global_pose(bi)
			else:
				bxf = Transform3D(Basis.IDENTITY, tt.global_position + Vector3.UP * float(tt.height) * 0.6)
			bg["a"] = float(bg["a"]) + float(bg["sp"]) * 0.06
			var r = 0.16 if String(bg["bone"]).contains("Arm") or String(bg["bone"]).contains("Leg") else 0.2
			var ax: Vector3 = bxf.basis.y.normalized()   # kemik ekseni etrafında dolaş
			var px: Vector3 = bxf.basis.x.normalized()
			var pz: Vector3 = bxf.basis.z.normalized()
			var off = (px * cos(float(bg["a"])) + pz * sin(float(bg["a"]))) * r
			var slide = ax * sin(i * 0.05 + float(bg["ph"])) * 0.12
			var pos = bxf.origin + off + slide
			var tang = (px * -sin(float(bg["a"])) + pz * cos(float(bg["a"]))) * signf(float(bg["sp"]))
			mi.global_position = pos
			if tang.length() > 0.01 and off.length() > 0.01:
				mi.global_basis = Basis.looking_at(tang, off.normalized()).scaled(Vector3.ONE * (0.3 + k * 0.1))   # önkol boyunu geçmez
			if i % 3 == 0:
				mi.mesh = mB if mi.mesh == mA else mA   # tripod yürüyüş: bacak fazları değişir
		if i % 15 == 0:
			pj.hit(c, tt.global_position + Vector3.UP, 1.0, pj.inf(c, "kidaichu_mushikui", 0.08 + k * 0.3, {"knock": 0.0, "kind": "light", "chakra_drain": 4.0 + k * 8.0, "bleed": 0.5}))
			if i % 60 == 0:   # ısırık: kan lekeleri
				_flecks(pj, tt.global_position + Vector3.UP * float(tt.height) * 0.6, [Color(0.55, 0.05, 0.05), Color(0.32, 0.02, 0.02)], 8, 3.0, 0.4, 0.08, 9.0, Vector3.UP, 90.0, 0.25), func():
		for bg in bugs:
			if is_instance_valid(bg["mi"]):
				bg["mi"].queue_free())
	Sfx.play("wind", c.global_position, 1.6, 0.6)


## Mushi Kame no Jutsu (referans: girdap çizgili taneli kara küre, kenarında mor-gri dönüş halkaları, yüzeyde uçuşan
## böcekler): bedenden fışkıran kikaichū çevrende hızla dönen kubbe olur; mermileri yutar, değenin chakrasını emer.
## Yeterli patlama gücü kubbeyi dağıtır
static func mushi_kabe(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var dome = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 32
	sm.rings = 16
	dome.mesh = sm
	var m = _smat("jar", "unshaded, cull_back", SH_JAR)
	m.set_shader_parameter("u_cover", 0.0)
	dome.material_override = m
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.scale = Vector3.ONE * 6.0
	pj.attach(c, dome, 8.0, Vector3.UP * 1.0)
	dome.create_tween().tween_method(func(v: float): m.set_shader_parameter("u_cover", v), 0.0, 1.0, 0.45)
	var bs = ClanJutsu.body_scale(c)
	# dönüş haleleri: kürenin çevresinde iki eğik mor-gri fırça bandı
	var halo = Node3D.new()
	for k in 2:
		var pts = PackedVector3Array()
		var w = PackedFloat32Array()
		for q in 30:
			var a = q * 0.2 + k * PI
			pts.append(Vector3(cos(a), 0.0, sin(a)) * (3.35 + q * 0.012))
			w.append(0.42 * sin(PI * clampf(q / 29.0, 0.05, 0.95)))
		var rib = Node3D.new()
		halo.add_child(rib)
		rib.rotation = Vector3(0.35 if k == 0 else -0.55, 0.0, 0.25 if k == 0 else -0.2)
		rib.add_child(_mi(_ribbon(pts, w, Vector3.ZERO, PackedColorArray([Color(0.46, 0.36, 0.42)])), _paint_mat(0.4)))
	pj.attach(c, halo, 8.0, Vector3.UP * 1.0)
	halo.create_tween().set_loops(10).tween_property(halo, "rotation:y", TAU, 0.8).as_relative()
	# böcekler bedenden fışkırıp kabuğa dizilir
	var sw = _swarm(pj, 200, 0.06, "kikai", 8.0, c.global_position + Vector3.UP, 0.3)
	sw.anchor = weakref(c)
	sw.off = Vector3.UP * 1.0 * bs
	sw.go("shell", {"r": 3.08 * bs, "spin": 2.6})
	var taken = [0.0]
	var cap = 140.0 * Jutsu._mult(c)
	pj.every(8.0, 0.1, func(_i, _k):
		if not is_instance_valid(c) or not is_instance_valid(dome):
			return
		dome.rotation.y += 0.45
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and n.shooter != c and Combat.hostile(c, n.shooter) and n.global_position.distance_to(c.global_position + Vector3.UP) < 3.4:
				taken[0] += float(n.info.get("dmg", 10.0))
				_gulp(pj, n.global_position)
				n.queue_free()
		if taken[0] > cap:   # yeterince güçlü saldırı: kubbe dağılır
			if is_instance_valid(sw):
				sw.go("scatter", {"burst": 7.0, "grav": 1.0})
				sw.end_in(1.2)
			_flecks(pj, c.global_position + Vector3.UP, [Color(0.06, 0.06, 0.05), Color(0.2, 0.18, 0.2)], 40, 9.0, 1.0, 0.1, 3.0, Vector3.UP, 180.0, 2.0)
			if is_instance_valid(halo):
				halo.queue_free()
			dome.queue_free()
			return
		if _i % 5 == 0:
			for e in pj.enemies_near(c, c.global_position, 3.6):
				pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "mushi_kabe", 0.12, {"knock": 5.0, "chakra_drain": 4.0}))
				pj.chakra_gain(c, 2.0))
	Sfx.play("wind", c.global_position, 2.2, 0.6)


## Hijutsu: Mushiheki (referans: insanın birkaç katı yüksek, kenarları sivri dişli, gri-kara taneli dev duvar): uzatılan
## avuçtan akan böcekler önünde duvar olur; yüzeyinde böcekler kaynar, tepeden kopup döner; mermileri yutar
static func hijutsu_mushiheki(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var d = c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD
	d.y = 0
	d = d.normalized()
	var at = pj.gp(c.global_position + d * 3.0)
	var wall = Node3D.new()
	pj.get_tree().current_scene.add_child(wall)
	wall.global_position = at
	wall.look_at(at + d, Vector3.UP)
	var wb = Basis.looking_at(d, Vector3.UP)
	# tırtıklı siluet: düz taban, iki yanda yana-yukarı sivri dişler, tümsekli tepe
	var o = PackedVector2Array([Vector2(-5.2, 0.0), Vector2(5.2, 0.0)])
	var y = 0.6
	while y < 8.6:
		o.append(Vector2(5.3 + randf_range(-0.2, 0.3), y))
		o.append(Vector2(6.6 + randf_range(-0.3, 0.6), y + 0.5))
		y += randf_range(1.2, 1.7)
	for q in 12:
		var xx = 5.2 - q * (10.4 / 11.0)
		o.append(Vector2(xx, 10.0 - absf(xx) * 0.3 + randf_range(-0.5, 0.6)))
	y = 8.4
	while y > 1.0:
		o.append(Vector2(-6.6 - randf_range(-0.3, 0.6), y))
		o.append(Vector2(-5.3 - randf_range(-0.2, 0.3), y - 0.5))
		y -= randf_range(1.2, 1.7)
	var b = MB.new()
	_slab_xy(b, o, 1.4, Color(1, 1, 1))
	for k in 18:   # yüzey tümsekleri (üst üste binen böcek kütleleri)
		var lx = randf_range(-4.4, 4.4)
		var ly = randf_range(0.6, 9.0 - absf(lx) * 0.3)
		b.add("sphere", Vector3(lx, ly, (0.55 if k % 2 == 0 else -0.55)), Vector3(randf_range(2.0, 3.4), randf_range(1.6, 2.8), 0.9), Color(1, 1, 1), Vector3(0, 0, randf_range(-30, 30)), 10)
	var gm = _mi(b.build(), _smat("grain", "diffuse_toon, specular_disabled, cull_disabled", SH_GRAIN))
	wall.add_child(gm)
	gm.set_instance_shader_parameter("u_fade", 0.0)
	wall.scale = Vector3(1, 0.05, 1)
	var tw = wall.create_tween()
	tw.tween_property(wall, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_method(func(v: float):
		if is_instance_valid(gm):
			gm.set_instance_shader_parameter("u_fade", v), 0.0, 1.0, 0.3)
	tw.tween_interval(6.0)
	tw.tween_method(func(v: float):
		if is_instance_valid(gm):
			gm.set_instance_shader_parameter("u_fade", v), 1.0, 0.0, 0.6)
	tw.tween_callback(wall.queue_free)
	# avuçtan akan böcekler duvara yayılıp yüzeyinde kaynar
	var hand: Vector3 = pj.hand_pos(c, true)
	var sw = _swarm(pj, 220, 0.07, "kikai", 7.0, hand, 0.2)
	sw.center = at
	sw.go("stream", {"from": hand, "to": at + Vector3.UP * 3.0, "dur": 0.35, "spread": 0.35, "arc": 1.0, "next": "wall", "b": wb, "w": 11.0, "h": 9.5, "th": 1.8, "spin": 1.0})
	_emitter(wall, Vector3.UP * 9.5, [Color(0.1, 0.1, 0.09), Color(0.2, 0.2, 0.19)], 14, 1.6, Vector2(0.35, 0.25), -0.8, Vector3.UP, 1.2, Vector3(4.5, 0.4, 0.5), 6.2)
	pj.every(6.5, 0.05, func(_i, _k):
		if not is_instance_valid(wall):
			return
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and n.shooter != c and Combat.hostile(c, n.shooter):
				var rel: Vector3 = n.global_position - at
				if absf(rel.dot(d)) < 1.2 and absf(rel.dot(d.cross(Vector3.UP))) < 6.0 and rel.y < 8.5:
					_gulp(pj, n.global_position)
					n.queue_free())
	Sfx.play("wind", at, 1.8, 0.7)


## Hijutsu: Mushimayu (referans: diz çökmüş, mühürdeki kullanıcıyı saran soluk mavi, yarı saydam parlayan koza):
## böcekler çevresinde sarmal dönerek alttan yukarı ipek örer; sonunda koza açılır, böcekler dağılır
static func hijutsu_mushimayu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var DUR = 5.0
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.95
	sm.height = 2.1
	sm.radial_segments = 40
	sm.rings = 24
	mi.mesh = sm
	var mat = _smat("cocoon", "unshaded, cull_disabled, depth_draw_never", SH_COCOON)
	mat.set_shader_parameter("u_grow", 0.0)
	mat.set_shader_parameter("u_h", 2.1)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1.0, 1.0, 0.92)
	pj.attach(c, mi, DUR + 0.6, Vector3.UP * 0.75)
	var tw = mi.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("u_grow", v), 0.0, 1.05, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(DUR - 1.2)
	tw.tween_method(func(v: float): mat.set_shader_parameter("u_grow", v), 1.05, 0.0, 0.5)
	var lt = OmniLight3D.new()
	lt.light_color = Color(0.6, 0.82, 1.0)
	lt.light_energy = 1.2
	lt.omni_range = 3.5
	pj.attach(c, lt, DUR + 0.3, Vector3.UP * 1.0)
	var bs = ClanJutsu.body_scale(c)
	var sw = _swarm(pj, 140, 0.05, "kikai", DUR + 0.4, c.global_position + Vector3.UP, 0.4)
	sw.anchor = weakref(c)
	sw.off = Vector3.UP * (0.75 - 1.05) * bs
	sw.go("weave", {"h": 2.1 * bs, "r": 1.05 * bs, "spin": 1.4, "die_with_anchor": true})
	pj.every(DUR, 0.1, func(_i, _k):
		if pj.live(c) and c.get("model"):   # koza boyunca diz çökük + eller mühürde (anime)
			c.set_meta("kneel", true)
			c.model.overlay.charge_k = 1.0
			c.model.overlay.set_pose("seal", 1.0), Callable())
	pj.busy(c, DUR)
	if c is Player:
		c.input_locked = DUR
		Buffs.add("mushimayu", DUR, {"speed": 0.0, "armor": 1.3})   # savunmasız: aldığı hasar artar
	var sww = weakref(sw)
	pj.after(DUR, func():
		var s2 = sww.get_ref()
		if s2 != null and is_instance_valid(s2):   # koza açılır: böcekler dışa dağılır
			s2.go("scatter", {"burst": 5.0, "grav": 0.6})
			s2.end_in(1.0)
		if not pj.live(c):
			return
		if c.get("model"):
			c.model.overlay.charge_k = 0.0
			c.model.overlay.set_pose("seal", 0.0)
		if c.has_meta("kneel"):
			c.remove_meta("kneel")
		_flecks(pj, c.global_position + Vector3.UP, [Color(0.62, 0.82, 0.95), Color(0.85, 0.95, 1.0)], 24, 3.0, 0.8, 0.12, 1.0, Vector3.UP, 180.0, 0.8)
		if c is Player:
			Game.profile["kikaichu"] = ClanMech.KOLONI_MAX
			Buffs.add("mushi_buyume", 40.0, {"jutsu": 1.25, "_name": "Büyümüş Kikaichū", "_desc": "böcek teknikleri güçlü"})
			Hud.msg("Koza açıldı: kikaichū kolonin doldu ve böceklerin güçlendi.", Color(0.75, 0.85, 0.6))
		elif c.has_method("add_buff"):
			c.add_buff("mushi_buyume", 40.0, {"jutsu": 1.25}))


## Zehir bulutu topağı: büyüyerek kabarır, sürüklenir, yırtılarak söner
static func _billow(pj: PathJutsu, pos: Vector3, s: float, life: float, grow_t: float, drift: Vector3) -> MeshInstance3D:
	var mk = "mesh:billow"
	if not _cache.has(mk):
		var sp = SphereMesh.new()
		sp.radial_segments = 20
		sp.rings = 10
		_cache[mk] = sp
	var ck = "mat:billow"
	if not _cache.has(ck):
		_cache[ck] = _smat("billow", "diffuse_toon, specular_disabled, cull_back", SH_BILLOW)
	var mi = _mi(_cache[mk], _cache[ck])
	pj.scene_add(mi, pos)
	mi.set_instance_shader_parameter("u_seed", randf() * 50.0)
	mi.set_instance_shader_parameter("u_fade", 1.0)
	mi.scale = Vector3.ONE * s * 0.3
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * s, grow_t).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "position", pos + drift, life).set_ease(Tween.EASE_OUT)
	var ft = mi.create_tween()
	ft.tween_interval(life * 0.55)
	ft.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("u_fade", v), 1.0, 0.0, life * 0.45)
	ft.tween_callback(mi.queue_free)
	return mi


## Kodoku no Jutsu (referans: ceset yığınının üstünde pembe yazı halkaları + mor-beyaz süs kıvrımlı mühür kubbesi; içinde
## rinkaichū çoğalır, patlayınca koyu mor kabaran bulut ve dışa akan zehirli sürü) — YASAK
static func kodoku_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	# kanon: ceset gerekir (çok sayıda) — yakında en az iki ölü beden
	var corpses = []
	var now_t = Time.get_ticks_msec() / 1000.0
	for fe in Enemy.fallen:
		var fp: Vector3 = fe["pos"]
		if now_t - float(fe["t"]) < 180.0 and fp.distance_to(c.global_position) < 22.0:
			corpses.append(fp)
	if corpses.size() < 2:
		if c is Player:
			Hud.msg("Kodoku için yakında en az iki ceset olmalı (kanon: kavanoz cesetle beslenir).", Color(0.9, 0.55, 1.0))
		return
	pj.busy(c, 1.0)
	pj.anim(c, "seal", 1.0)
	var cen = Vector3.ZERO
	for fp in corpses:
		cen += fp
	cen = pj.gp(cen / corpses.size())
	var R = 5.0
	var root = Node3D.new()
	pj.scene_add(root, cen)
	var dm = MeshInstance3D.new()   # mühür yazılı kubbe
	var hs = SphereMesh.new()
	hs.radius = R
	hs.height = R
	hs.is_hemisphere = true
	hs.radial_segments = 48
	hs.rings = 16
	dm.mesh = hs
	var sm = _smat("script", "unshaded, blend_add, cull_disabled, depth_draw_never", SH_SCRIPT)
	sm.set_shader_parameter("u_write", 0.0)
	dm.material_override = sm
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dm)
	var rpts = PackedVector3Array()   # yerde mühür yazılı taban halkası
	for q in 65:
		var a = TAU * q / 64.0
		rpts.append(Vector3(cos(a), 0.05, sin(a)) * R)
	var rm = _smat("script", "unshaded, blend_add, cull_disabled, depth_draw_never", SH_SCRIPT)
	rm.set_shader_parameter("u_write", 0.0)
	rm.set_shader_parameter("u_cols", 72.0)
	rm.set_shader_parameter("u_rows", 3.0)
	root.add_child(_mi(_ribbon(rpts, PackedFloat32Array([1.0]), Vector3.UP, PackedColorArray([Color.WHITE])), rm))
	var wt = root.create_tween()
	wt.tween_method(func(v: float):
		sm.set_shader_parameter("u_write", v)
		rm.set_shader_parameter("u_write", v), 0.0, 1.02, 0.7)
	root.scale = Vector3.ONE * 0.05
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	Game.safe_loops(root.create_tween()).tween_property(root, "rotation:y", TAU, 6.0).as_relative()
	var lt = OmniLight3D.new()
	lt.light_color = Color(0.95, 0.45, 0.85)
	lt.light_energy = 2.0
	lt.omni_range = 10.0
	root.add_child(lt)
	lt.position = Vector3.UP * 2.0
	Sfx.play("th_bugs", cen, 0.6)
	# kavanozun içinde çoğalan rinkaichū
	var sw = _swarm(pj, 300, 0.06, "poison", 9.5, cen + Vector3.UP * 1.0, 1.0)
	sw.center = cen + Vector3.UP * 1.5
	sw.go("cloud", {"r": R * 0.7, "h": 3.0, "spin": 1.2})
	sw.multimesh.visible_instance_count = 20
	pj.every(2.6, 0.1, func(_i, _k):
		if is_instance_valid(sw):
			sw.multimesh.visible_instance_count = clampi(20 + int(_k * 300.0), 20, 300), func():
		if is_instance_valid(root):
			root.queue_free()
		# patlama: koyu mor kabaran bulut geniş alana yayılır, sürü dışa akar
		if is_instance_valid(sw):
			sw.multimesh.visible_instance_count = -1
			sw.rate = 2.5
			sw.go("cloud", {"r": 10.0, "h": 5.0, "spin": 0.5})
		for k in 16:
			var a = TAU * k / 16.0 + randf_range(-0.2, 0.2)
			var dist = randf_range(1.0, 5.5)
			var p: Vector3 = cen + Vector3(cos(a) * dist, randf_range(0.6, 3.6), sin(a) * dist)
			_billow(pj, p, randf_range(1.6, 2.6), 6.5, 0.6, Vector3(cos(a), 0.15, sin(a)) * randf_range(2.0, 4.5))
		_flecks(pj, cen + Vector3.UP * 1.5, [Color(0.18, 0.08, 0.22), Color(0.1, 0.04, 0.12), Color(0.5, 0.3, 0.6)], 40, 10.0, 1.2, 0.18, 2.0, Vector3.UP, 180.0, 1.5)
		pj.shake(0.7)
		Sfx.play("boom", cen, 0.6)
		pj.every(6.0, 0.5, func(_i2, _k2):
			for e in pj.enemies_near(c, cen, 13.0):
				e.take_hit(pj.inf(c, "kodoku_no_jutsu", 0.16, {"knock": 0.0, "kind": "light", "pierce_guard": true, "kikai": true}))
				pj.st(e, "slow", 0.8), Callable()))


## Dokujin no Jutsu (referans: avuçlar arasında zehirli küre, üflenince önde büyüyen kara-mor bulut): küre içinde dönen
## mor böcekler; üflenince ileri doğru yuvarlanarak genişleyen bulut konisi, önünde akan sürü; zehirlenenin bedeninde
## mor böcekler sürünür
static func dokujin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	pj.anim(c, "seal", 1.0)
	var d = pj.fwd(c, t)
	var orb_at: Vector3 = pj.hand_pos(c, true).lerp(pj.hand_pos(c, false), 0.5) + d * 0.3
	var ball = _billow(pj, orb_at, 0.6, 0.5, 0.25, Vector3.ZERO)
	var orbs = _swarm(pj, 36, 0.04, "poison", 1.9, orb_at, 0.3)
	orbs.go("cloud", {"r": 0.42, "h": 0.4, "spin": 4.0})
	Sfx.play("th_bugs", c.global_position, 0.8)
	pj.after(0.45, func():
		if is_instance_valid(ball):
			ball.queue_free()
		if not pj.live(c):
			return
		Sfx.play("wind", c.global_position, 0.8)
		if is_instance_valid(orbs):
			orbs.go("stream", {"from": orb_at, "to": c.global_position + Vector3.UP * 1.2 + d * 18.0, "dur": 1.0, "spread": 0.3, "arc": 0.4})
		var hits = {}
		pj.every(1.4, 0.07, func(_i, k):
			var p = c.global_position + Vector3.UP * 1.2 + d * (1.5 + k * 13.0)
			var r = 0.8 + k * 3.2
			if _i % 2 == 0:
				var side = d.cross(Vector3.UP) * randf_range(-0.4, 0.4) * r
				_billow(pj, p + side + Vector3.UP * randf_range(-0.2, 0.3) * r, minf(0.7 + r * 0.42, 2.6), 1.8, 0.3, d * 2.0 + Vector3.UP * 0.4)
			for e in pj.enemies_near(c, p, r + 0.5):
				if not hits.has(e):
					hits[e] = true
					Combat.popup_text(e.global_position + Vector3.UP * 2.3, "Zehirlendi!", Color(0.75, 0.45, 0.85))
					_crawl(pj, e, 6.0, "poison", 36)
					var ee = e
					pj.every(6.0, 0.5, func(_i2, _k2):
						if pj.live(ee):
							ee.take_hit(pj.inf(c, "dokujin_no_jutsu", 0.14, {"knock": 0.0, "kind": "light", "pierce_guard": true}))
							pj.st(ee, "slow", 0.6), Callable()), Callable()))
