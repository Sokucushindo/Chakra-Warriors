class_name MokutonLib
extends RefCounted
## Ahşap doğası (Mokuton) malzeme / şekil kütüphanesi. Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları ve
## kendi ürettiği geometrisi. Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası malzeme + yapı taşı verir.
##
## MALZEME
##   wood_mat()        : canlı ahşap. Sıcak kahve kabuk, üç tonlu cel, boyuna akan lif oluğu + ince tane (metre ölçekli: büyük
##                       yüzeyde de ince doku), budak halkası, kesik uçta açık turuncu yıllık halkalar, kenar karartma. Kameraya
##                       yakın kısım (nf metre) noktalı inceltmeyle silinir: hiçbir yapı ekranı kaplamaz.
##                       Örnek parametreleri: body (renk), grow (büyüme cephesi, metre), taper (uç sivrilmesi), seed, nf,
##                       fresh (büyüyen uçtaki taze açık ton), wither (kuruma / kararma 0..1).
##   outline           : koyu kontur (ters kabuk). inst() onu "ol" adlı çocuk olarak ekler; setp() iki katmana birlikte yazar.
##   skin_on/peel/off  : karakter modelinin üstüne ahşap kabuk örtüsü (klon / kaynaşma); aşağıdan yukarı soyulur.
##   dust / scar       : cel gölgeli konturlu toz topağı; zeminde yarık / çukur / halka izi (isteğe bağlı kor parıltısı).
##   chips / leaves / splinters : kabuk kıymığı ve yaprak parçacıkları, fırlayıp yere düşen iri ahşap kıymıkları.
##
## GEOMETRİ (hepsi Geo'ya eklenir, Geo.build() tek ArrayMesh verir)
##   tube(g, pts, radii, o)   : eğri boyunca kalınlığı değişen gövde. UV.y = kökten uzaklık (metre) → grow ile gerçek zamanlı
##                              büyür: cephe sivri bir tomurcuk gibi ilerler, geri çekilince köke döner. o: sides, hard (köşeli
##                              yontma yüzler), sx/sy (yassı kesit: tahta şerit), a0, gnarl, seed, s0 (dal başlangıç uzaklığı),
##                              tint, cap_end / cap_start (açık renk kesik uç), nfn (kesit yönü), cut_faces / face_tint / ring_c /
##                              ring_ax (köşeli gövdede yüzü kesik yüz yapmak: halkalar ring_ax çevresinde).
##   wander(from, dir, L, n, o): organik kıvrılan yol (o.hug: zemine yapışık kök, o.lift / o.arch).
##   tree(g, root, dir, L, r0, o): dallanan gövde (depth / kids / spread / tip). Çocuk dallar ana dalın uzaklığından devam
##                              eder: tek grow tüm ağacı kökten uca büyütür. Dönüş: {len, tips, tip_s}.
##   helix / bez               : sarmal ve ikinci derece eğri yolları.
##   beam(g, base, h, w, o)    : köşeli kare direk (kesik açık tepe). stump(g, base, r, h, o): kesik kütük (halkalı tepe).
##
## SAHNE / HAREKET
##   inst(host, mesh, pos, o) → MeshInstance3D (+ kontur). o: body, seed, grow, taper, nf, fresh, ow, ocol, shadow, parent
##   setp / pf / grow_to / life (büyü → bekle → geri çekil / gömül → sil) / wither_to / toss / put / kill / light
##
## Not: Godot ön yüzü saat yönünde; Geo.tri üçgeni köşe normallerine göre kendisi çevirir.

static var _cache := {}

const BARK := Color(0.52, 0.35, 0.21)
const BARK_DARK := Color(0.36, 0.24, 0.15)
const BARK_GREY := Color(0.5, 0.48, 0.38)
const FRESH := Color(0.93, 0.66, 0.4)
const OUTLINE := Color(0.1, 0.06, 0.035)
const LEAF := Color(0.36, 0.6, 0.24)
const SAP := Color(0.62, 0.9, 0.42)
const OL_KEYS := ["grow", "taper", "nf"]

# ================================================================== shader parçaları
const NOISE := """
float mh2(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float mh3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float mn3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mh3(i), mh3(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(mh3(i + vec3(0.0, 1.0, 0.0)), mh3(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(mh3(i + vec3(0.0, 0.0, 1.0)), mh3(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(mh3(i + vec3(0.0, 1.0, 1.0)), mh3(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float mf3(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * mn3(p);
		p = p * 2.07 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s / 0.875;
}

float near_cut(vec3 vpos, vec2 fc, float nfd) {
	float dist = length(vpos);
	return step(smoothstep(nfd * 0.4, nfd, dist), mh2(floor(fc)));
}
"""

## Canlı ahşap: kabuk (lif oluğu, tane, budak) / kesik yüz (yıllık halka, öz, kabuk kenarı); büyüme cephesi CUSTOM0 boyunca
## ekseni üstüne çöker (sivri tomurcuk). Köşe COLOR çarpan (yüz tonu).
const WOOD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

instance uniform vec3 body = vec3(0.52, 0.35, 0.21);
instance uniform float grow = 100000.0;
instance uniform float taper = 0.8;
instance uniform float seed = 0.0;
instance uniform float nf = 3.0;
instance uniform float fresh = 1.0;
instance uniform float wither = 0.0;
uniform vec3 cutc = vec3(0.93, 0.66, 0.4);

NOISE

varying vec2 vuv;
varying vec2 vuv2;
varying float vcap;
varying float vtip;

void vertex() {
	float f = clamp((grow - UV.y) / max(taper, 0.001), 0.0, 1.0);
	f = 1.0 - (1.0 - f) * (1.0 - f);
	VERTEX -= CUSTOM0.xyz * (1.0 - f);
	vuv = UV;
	vuv2 = UV2;
	vcap = CUSTOM0.w;
	vtip = 1.0 - f;
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) {
		discard;
	}
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = dot(wn, normalize(vec3(0.42, 0.82, 0.38)));
	vec3 base = body * COLOR.rgb;
	vec3 col = base;
	if (vcap > 0.5) {
		float rr = vuv2.y;
		float wob = mn3(vec3(rr * 1.3, vuv.y * 0.7, seed)) * 0.7;
		float rg = fract(rr * 7.0 + wob);
		col = cutc * mix(vec3(1.0, 1.0, 1.0), COLOR.rgb, 0.35) * (0.93 + 0.1 * mn3(vec3(rr * 9.0, vuv.x * 3.0, seed)));
		col = mix(col, col * 0.74, 1.0 - smoothstep(0.06, 0.16, rg));
		col = mix(col, col * 0.6, 1.0 - smoothstep(0.04, 0.08, rr));
		col = mix(col, base * 0.62, smoothstep(vuv2.x - 0.09, vuv2.x - 0.05, rr));
	} else {
		float a = vuv.x * 6.2831853;
		float r = max(vuv2.x, 0.05);
		vec3 bp = vec3(cos(a) * r * 2.6, sin(a) * r * 2.6, vuv.y * 0.45 + seed * 7.0);
		float fib = mf3(bp);
		float furrow = 1.0 - smoothstep(0.015, 0.055, abs(fib - 0.5));
		float grain = mn3(bp * vec3(3.2, 3.2, 5.0));
		col = base * (0.86 + 0.24 * grain);
		col = mix(col, col * 1.14, smoothstep(0.64, 0.74, fib));
		col = mix(col, col * 0.4, furrow);
		float kk = max(2.0, floor(6.2831853 * r / 1.1));
		vec2 cc = vec2(floor(vuv.x * kk), floor(vuv.y / 1.7));
		if (r > 0.12 && mh2(cc + vec2(seed * 3.7, 11.0)) > 0.8) {
			vec2 lc = vec2(fract(vuv.x * kk) - 0.5, fract(vuv.y / 1.7) - 0.5);
			float kd = length(lc / vec2(0.3, 0.2));
			float kring = smoothstep(0.62, 0.72, kd) * (1.0 - smoothstep(0.86, 0.98, kd));
			col = mix(col, col * 1.12, 1.0 - smoothstep(0.55, 0.65, kd));
			col = mix(col, col * 0.45, kring);
			col = mix(col, col * 0.35, 1.0 - smoothstep(0.18, 0.28, kd));
		}
	}
	col = mix(col, mix(col, vec3(0.9, 0.74, 0.46), 0.55), clamp(vtip * 1.8, 0.0, 1.0) * fresh);
	col = mix(col, col * vec3(0.55, 0.5, 0.47), wither);
	float tone = 1.0;
	if (d < 0.3) {
		tone = 0.78;
	}
	if (d < -0.18) {
		tone = 0.58;
	}
	col *= tone;
	if (tone < 0.6) {
		col *= vec3(0.9, 0.93, 1.06);
	}
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col *= 1.0 - 0.25 * (1.0 - smoothstep(0.1, 0.32, ndv));
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""

## Koyu kontur: ters kabuk, TANGENT'a gömülü düzgün yön boyunca şişer; büyüme cephesinde gövdeyle birlikte çöker
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

instance uniform float grow = 100000.0;
instance uniform float taper = 0.8;
instance uniform float nf = 3.0;
uniform float ow = 0.04;
uniform vec3 ocol = vec3(0.1, 0.06, 0.035);

NOISE

void vertex() {
	float f = clamp((grow - UV.y) / max(taper, 0.001), 0.0, 1.0);
	f = 1.0 - (1.0 - f) * (1.0 - f);
	VERTEX -= CUSTOM0.xyz * (1.0 - f);
	float sc = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	VERTEX += TANGENT * (ow * f / sc);
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) {
		discard;
	}
	ALBEDO = pow(ocol, vec3(2.2));
}
"""

## Karakter üstüne ahşap kabuk örtüsü (material_overlay). wsk_peel: 0 tam kaplı → 1 tamamen soyulmuş (aşağıdan yukarı);
## soyulma kenarında açık turuncu taze yarık. Parametre adları karakter shader'ıyla çakışmasın diye wsk_ önekli.
const SKIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

instance uniform vec3 wsk_body = vec3(0.6, 0.44, 0.27);
instance uniform float wsk_peel = 0.0;
instance uniform float wsk_base = 0.0;
instance uniform float wsk_span = 1.9;
uniform vec3 cutc = vec3(0.93, 0.66, 0.4);

NOISE

varying vec3 lp;
varying vec3 wp;

void vertex() {
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = (wp.y - wsk_base) / max(wsk_span, 0.01);
	float e = h + (mn3(lp * 5.0) - 0.5) * 0.22;
	float cut = wsk_peel * 1.3 - 0.15;
	if (e < cut) {
		discard;
	}
	vec3 bp = vec3(lp.x * 9.0, lp.y * 1.6, lp.z * 9.0);
	float fib = mf3(bp);
	vec3 col = wsk_body * (0.86 + 0.24 * mn3(bp * 3.0));
	col = mix(col, col * 0.45, 1.0 - smoothstep(0.02, 0.06, abs(fib - 0.5)));
	col = mix(col, cutc, 1.0 - smoothstep(0.0, 0.07, e - cut));
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = dot(wn, normalize(vec3(0.42, 0.82, 0.38)));
	float tone = 1.0;
	if (d < 0.3) {
		tone = 0.8;
	}
	if (d < -0.18) {
		tone = 0.6;
	}
	col *= tone;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(col * 0.35, col, smoothstep(0.08, 0.22, ndv));
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
"""

## Toz topağı: hafif kabartılmış yarı saydam açık bulut, kenarı yumuşak (kaya gibi koyu kontur yok); fade ile erir, kameraya
## yakınken yumuşakça silinir
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform vec3 col = vec3(0.78, 0.68, 0.52);
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform float nf = 6.0;

NOISE

varying vec3 lp;

void vertex() {
	lp = VERTEX;
	float n = mn3(VERTEX * 2.6 + vec3(seed, seed * 1.7, 0.0));
	VERTEX += NORMAL * (n - 0.5) * 0.3;
}

void fragment() {
	float nfa = smoothstep(nf * 0.35, nf, length(VERTEX));
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = dot(wn, normalize(vec3(0.42, 0.82, 0.38)));
	vec3 c = col * 1.06;
	if (d < 0.2) {
		c = col * 0.88;
	}
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = smoothstep(0.0, 0.55, ndv);
	float n = mn3(lp * 3.0 + vec3(seed * 2.0, 0.0, seed));
	float body = clamp(n * 0.6 + 0.55 - fade * 1.3, 0.0, 1.0);
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
	ALPHA = edge * body * nfa * 0.85;
}
"""

## Zemin izi (yatay düzlem): ışınsal yarıklar (lines), ortada çukur (pit), eş merkezli halka (rings, kabuk dalgası);
## glow > 0 ise yarık içi kor gibi parlar. open 0→1 açılır, fade 0→1 söner.
const SCAR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec3 soil = vec3(0.3, 0.22, 0.15);
instance uniform vec3 glow = vec3(0.0, 0.0, 0.0);
instance uniform float open = 1.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform float lines = 9.0;
instance uniform float pit = 1.0;
instance uniform float rings = 0.0;

NOISE

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.5)) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float m = 0.0;
	float hot = 0.0;
	if (lines > 0.5) {
		float wob = (mn3(vec3(r * 3.5, seed, 1.0)) - 0.5) * 0.9;
		float ln = a * lines + wob;
		float idx = floor(ln);
		float reach = (0.45 + 0.55 * mh2(vec2(idx, seed))) * open;
		float fx = abs(fract(ln) - 0.5) * 6.2831853 * r / lines;
		float w = 0.05 * max(0.0, 1.0 - r / max(reach, 0.001)) + 0.004;
		float inside = step(r, reach);
		m = max(m, (1.0 - smoothstep(w * 0.55, w, fx)) * inside);
		hot = max(hot, (1.0 - smoothstep(w * 0.15, w * 0.5, fx)) * inside);
	}
	float pr = 0.2 * open * pit;
	float pc = 1.0 - smoothstep(pr * 0.75, pr, r + (mn3(vec3(p * 5.0, seed)) - 0.5) * 0.05);
	m = max(m, pc * 0.9);
	if (rings > 0.5) {
		float rv = r / max(open, 0.001);
		float band = abs(fract(rv * rings + (mn3(vec3(p * 3.0, seed)) - 0.5) * 0.4) - 0.5);
		float rm = (1.0 - smoothstep(0.06, 0.14, band)) * step(rv, 1.0) * (1.0 - rv * 0.6);
		m = max(m, rm * 0.8);
	}
	vec3 c = soil * 0.32;
	c = mix(c, glow, hot * step(0.01, glow.r + glow.g + glow.b));
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
	ALPHA = clamp(m, 0.0, 1.0) * (1.0 - fade);
}
"""


# ================================================================== malzemeler
static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("NOISE", NOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func wood_mat() -> ShaderMaterial:
	return _shader_mat("wood", WOOD_SHADER)


## Kameraya yakın kısmı noktalı değil düzgün saydamlıkla silen eş (inst varsayılanı). Saydam olduğundan gölge düşürmez.
static func _softify(code: String) -> String:
	code = code.replace("render_mode unshaded, cull_back;", "render_mode unshaded, cull_back, depth_draw_always;")
	code = code.replace("render_mode unshaded, cull_front, shadows_disabled;", "render_mode unshaded, cull_front, shadows_disabled, depth_draw_always;")
	return code.replace("if (near_cut(VERTEX, FRAGCOORD.xy, nf) > 0.5) {",
		"float nfa = smoothstep(nf * 0.35, nf, length(VERTEX));\n\tALPHA = nfa;\n\tif (nfa < 0.004) {")


static func wood_soft_mat() -> ShaderMaterial:
	return _shader_mat("wood_soft", _softify(WOOD_SHADER))


static func outline_mat(ow: float, col := OUTLINE, soft := false) -> ShaderMaterial:
	var key = "ol_%.3f_%s_%d" % [ow, col.to_html(false), 1 if soft else 0]
	if _cache.has(key):
		return _cache[key]
	var base: ShaderMaterial = _shader_mat("ol_soft", _softify(OUTLINE_SHADER)) if soft else _shader_mat("ol_base", OUTLINE_SHADER)
	var m = ShaderMaterial.new()
	m.shader = base.shader
	m.set_shader_parameter("ow", ow)
	m.set_shader_parameter("ocol", Vector3(col.r, col.g, col.b))
	_cache[key] = m
	return m


static func skin_mat() -> ShaderMaterial:
	return _shader_mat("skin", SKIN_SHADER)


static func dust_mat() -> ShaderMaterial:
	return _shader_mat("dust", DUST_SHADER)


static func scar_mat() -> ShaderMaterial:
	return _shader_mat("scar", SCAR_SHADER)


## Düz renk (köşe rengi × parçacık rengi): kıymık, yaprak, diş
static func plain_mat(double := false) -> StandardMaterial3D:
	var key = "plain_%d" % (1 if double else 0)
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	if double:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## Parlayan düz renk (göz, emilen chakra)
static func glow_mat(col: Color, e := 2.0) -> StandardMaterial3D:
	var key = "glow_%s_%.2f" % [col.to_html(true), e]
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = e
	_cache[key] = m
	return m


static func v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## Noktadaki toprak rengi (kum / kar / kaya / çimen-toprak)
static func soil_col(p: Vector3) -> Color:
	var c = Color(0.45, 0.34, 0.23)
	if Game.world == null:
		return c
	var b = Game.biome_at(p.x, p.z)
	if b in [1, 3, 13]:
		return Color(0.72, 0.6, 0.42)
	if b in [8, 15]:
		return Color(0.7, 0.72, 0.78)
	if b in [5, 9, 14]:
		return Color(0.5, 0.48, 0.44)
	return c


static func dust_col(p: Vector3) -> Color:
	return soil_col(p).lightened(0.35)


# ================================================================== geometri birleştirici
class Geo:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var tg := PackedFloat32Array()
	var vc := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cu := PackedFloat32Array()
	var idx := PackedInt32Array()

	## Köşe: p konum, nrm gölge normali, tan kontur yönü, col yüz tonu, u (çevre 0..1, eksen boyu m), u2 (yarıçap, halka uzaklığı),
	## coll büyüme çöküş vektörü (eksenden köşeye), cap 1 = kesik yüz
	func add(p: Vector3, nrm: Vector3, tan: Vector3, col: Color, u: Vector2, u2: Vector2, coll: Vector3, cap := 0.0) -> int:
		v.append(p)
		var nn = nrm.normalized() if nrm.length() > 0.00001 else Vector3.UP
		n.append(nn)
		var tt = tan.normalized() if tan.length() > 0.00001 else nn
		tg.append_array(PackedFloat32Array([tt.x, tt.y, tt.z, 1.0]))
		vc.append(col)
		uv.append(u)
		uv2.append(u2)
		cu.append_array(PackedFloat32Array([coll.x, coll.y, coll.z, cap]))
		return v.size() - 1

	## Üçgen: köşe normallerine göre dışa bakacak şekilde çevrilir (Godot ön yüzü saat yönünde)
	func tri(a: int, b: int, c: int) -> void:
		var gn = (v[b] - v[a]).cross(v[c] - v[a])
		if gn.dot(n[a] + n[b] + n[c]) > 0.0:
			idx.append_array(PackedInt32Array([a, c, b]))
		else:
			idx.append_array(PackedInt32Array([a, b, c]))

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(c, b, d)

	func build() -> ArrayMesh:
		var m = ArrayMesh.new()
		if v.size() < 3 or idx.size() < 3:
			return m
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TANGENT] = tg
		arr[Mesh.ARRAY_COLOR] = vc
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_CUSTOM0] = cu
		arr[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		return m


static func _gn(ang: float, i: int, sd: float, gnarl: float) -> float:
	return 1.0 + gnarl * (sin(ang * 3.0 + i * 0.9 + sd * 5.0) * 0.6 + sin(ang * 5.0 - i * 1.7 + sd * 3.0) * 0.4)


## Eğri boyunca gövde (açıklama dosya başında). Dönüş: uç noktanın kökten uzaklığı (grow hedefi).
static func tube(g: Geo, pts: Array, radii: Array, o := {}) -> float:
	var np = pts.size()
	if np < 2 or radii.size() < np:
		return 0.0
	var sides: int = int(o.get("sides", 10))
	var s0: float = float(o.get("s0", 0.0))
	var tint: Color = o.get("tint", Color(1, 1, 1))
	var gnarl: float = float(o.get("gnarl", 0.07))
	var sd: float = float(o.get("seed", 0.0))
	var hard: bool = bool(o.get("hard", false))
	var sx: float = float(o.get("sx", 1.0))
	var sy: float = float(o.get("sy", 1.0))
	var a0: float = float(o.get("a0", 0.0))
	var nfn: Callable = o.get("nfn", Callable())
	var cut_faces: Array = o.get("cut_faces", [])
	var face_tint: Array = o.get("face_tint", [])
	var ring_c: Vector3 = o.get("ring_c", Vector3.ZERO)
	var ring_ax: Vector3 = o.get("ring_ax", Vector3.ZERO)
	if hard:
		gnarl = 0.0
	var T: Array = []
	for i in np:
		var pa: Vector3 = pts[maxi(i - 1, 0)]
		var pb: Vector3 = pts[mini(i + 1, np - 1)]
		var tv = pb - pa
		T.append(tv.normalized() if tv.length() > 0.00001 else Vector3.UP)
	var N: Array = []
	var t0: Vector3 = T[0]
	var rv = Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT
	var prev: Vector3 = (rv - t0 * rv.dot(t0)).normalized()
	for i in np:
		var ti: Vector3 = T[i]
		var nn: Vector3 = prev
		if nfn.is_valid():
			nn = nfn.call(i, pts[i], ti)
		nn = nn - ti * nn.dot(ti)
		if nn.length() < 0.001:
			var alt = Vector3.RIGHT if absf(ti.x) < 0.9 else Vector3.FORWARD
			nn = alt - ti * alt.dot(ti)
		nn = nn.normalized()
		N.append(nn)
		prev = nn
	var S: Array = [s0]
	for i in range(1, np):
		var pa2: Vector3 = pts[i]
		var pb2: Vector3 = pts[i - 1]
		S.append(float(S[i - 1]) + pa2.distance_to(pb2))
	var base = g.v.size()
	if not hard:
		for i in np:
			var p: Vector3 = pts[i]
			var ti: Vector3 = T[i]
			var ni: Vector3 = N[i]
			var bi: Vector3 = ti.cross(ni)
			var r0: float = float(radii[i])
			for j in sides + 1:
				var ang = a0 + TAU * j / sides
				var cs = cos(ang)
				var sn = sin(ang)
				var r = r0 * _gn(ang, i, sd, gnarl)
				var off = ni * cs * sx + bi * sn * sy
				var nrm = (ni * cs / sx + bi * sn / sy).normalized()
				g.add(p + off * r, nrm, nrm, tint, Vector2(float(j) / sides, float(S[i])), Vector2(r0 * maxf(sx, sy), 0.0), off * r)
		for i in np - 1:
			for j in sides:
				var a = base + i * (sides + 1) + j
				g.quad(a, a + sides + 1, a + 1, a + sides + 2)
	else:
		for j in sides:
			var am = a0 + TAU * (j + 0.5) / sides
			var is_cut = cut_faces.has(j)
			var ft: Color = tint
			if j < face_tint.size():
				ft = tint * (face_tint[j] as Color)
			for i in np:
				var p: Vector3 = pts[i]
				var ti: Vector3 = T[i]
				var ni: Vector3 = N[i]
				var bi: Vector3 = ti.cross(ni)
				var r0: float = float(radii[i])
				var fnrm = (ni * cos(am) / sx + bi * sin(am) / sy).normalized()
				for e in 2:
					var ang = a0 + TAU * (j + e) / sides
					var off = ni * cos(ang) * sx + bi * sin(ang) * sy
					var sm = (ni * cos(ang) / sx + bi * sin(ang) / sy).normalized()
					var pos = p + off * r0
					var u2 = Vector2(r0 * maxf(sx, sy), 0.0)
					if is_cut:
						var rc = pos - ring_c
						if ring_ax.length() > 0.001:
							rc -= ring_ax * rc.dot(ring_ax)
						u2 = Vector2(999.0, rc.length())
					g.add(pos, fnrm, sm, ft, Vector2(float(j + e) / sides, float(S[i])), u2, off * r0, 1.0 if is_cut else 0.0)
			var fb = base + j * np * 2
			for i in np - 1:
				var a = fb + i * 2
				g.quad(a, a + 2, a + 1, a + 3)
	var cap_end: bool = bool(o.get("cap_end", float(radii[np - 1]) > 0.04))
	var cap_start: bool = bool(o.get("cap_start", false))
	if cap_end:
		_cap(g, pts[np - 1], T[np - 1], T[np - 1], N[np - 1], float(radii[np - 1]), float(S[np - 1]), sides, sx, sy, a0, gnarl, sd, np - 1, tint)
	if cap_start:
		_cap(g, pts[0], -(T[0] as Vector3), T[0], N[0], float(radii[0]), float(S[0]), sides, sx, sy, a0, gnarl, sd, 0, tint)
	return float(S[np - 1])


## Kesik uç: açık turuncu yıllık halkalı yüz (ax: yüz normali, ti: gövde ekseni)
static func _cap(g: Geo, p: Vector3, ax: Vector3, ti: Vector3, ni: Vector3, r0: float, s: float, sides: int, sx: float, sy: float,
		a0: float, gnarl: float, sd: float, ir: int, tint: Color) -> void:
	var bi = ti.cross(ni)
	var c0 = g.add(p, ax, ax, tint, Vector2(0.5, s), Vector2(r0, 0.0), Vector3.ZERO, 1.0)
	var first = g.v.size()
	for j in sides + 1:
		var ang = a0 + TAU * j / sides
		var r = r0 * _gn(ang, ir, sd, gnarl)
		var off = ni * cos(ang) * sx + bi * sin(ang) * sy
		var sm = (ni * cos(ang) / sx + bi * sin(ang) / sy).normalized()
		g.add(p + off * r, ax, sm, tint, Vector2(float(j) / sides, s), Vector2(r0, r * maxf(sx, sy)), off * r, 1.0)
	for j in sides:
		g.tri(c0, first + j, first + j + 1)


## Organik kıvrılan yol. o: rng, bend (kıvrım), up (her adımda eklenen yön), hug (zemine yapışık), lift (zeminden yükseklik),
## arch (kök kabarması genliği), org (zemin sorgusu için ağın dünya kökeni)
static func wander(from: Vector3, dir: Vector3, L: float, n: int, o := {}) -> Array:
	var rng: RandomNumberGenerator = o.get("rng", null)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var bend: float = float(o.get("bend", 0.35))
	var up: Vector3 = o.get("up", Vector3.ZERO)
	var hug: bool = bool(o.get("hug", false))
	var lift: float = float(o.get("lift", 0.2))
	var arch: float = float(o.get("arch", 0.0))
	var org: Vector3 = o.get("org", Vector3.ZERO)
	var pts: Array = [from]
	var d = dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	var flat0 = Vector3(d.x, 0.0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.01 else Vector3.FORWARD
	var turn = Vector3.ZERO
	var seg = L / float(maxi(n - 1, 1))
	var p = from
	var ph = rng.randf() * TAU
	for i in range(1, n):
		var rnd = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		rnd -= d * rnd.dot(d)
		turn = turn * 0.55 + rnd * 0.45
		d = (d + turn * bend + up).normalized()
		if hug:
			d.y = 0.0
			d = d.normalized() if d.length() > 0.01 else flat0
		p = p + d * seg
		if hug:
			var w = org + p
			var q = float(i) / float(maxi(n - 1, 1))
			p.y = Game.jutsu_floor(w.x, w.z) - org.y + lift + maxf(0.0, sin(ph + i * 1.3)) * arch * (1.0 - q * 0.6)
		pts.append(p)
	return pts


## Dallanan gövde: kök + çocuk dallar (her çocuk ana dalın o noktadaki uzaklığından devam eder → tek grow ile büyür).
## o: rng, depth, kids, spread, tip (uç yarıçap oranı), seg_len + tube / wander seçenekleri. Dönüş {len, tips, tip_s}.
static func tree(g: Geo, root: Vector3, dir: Vector3, L: float, r0: float, o := {}) -> Dictionary:
	var oo = o.duplicate()
	if oo.get("rng", null) == null:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		oo["rng"] = rng
	var out = {"len": 0.0, "tips": [], "tip_s": []}
	_tree_rec(g, root, dir, L, r0, float(oo.get("s0", 0.0)), int(oo.get("depth", 1)), oo, out)
	return out


static func _tree_rec(g: Geo, root: Vector3, dir: Vector3, L: float, r0: float, s0: float, depth: int, o: Dictionary, out: Dictionary) -> void:
	var rng: RandomNumberGenerator = o["rng"]
	var segs: int = maxi(4, int(L / float(o.get("seg_len", 1.2))) + 1)
	var pts = wander(root, dir, L, segs, o)
	var tip_r: float = float(o.get("tip", 0.12))
	var radii: Array = []
	for i in segs:
		var tt = float(i) / float(segs - 1)
		radii.append(lerpf(r0, r0 * tip_r, pow(tt, 0.8)))
	var o2 = o.duplicate()
	o2["s0"] = s0
	o2["seed"] = rng.randf() * 10.0
	o2["cap_end"] = bool(o.get("cap_end", false))
	var send = tube(g, pts, radii, o2)
	out["len"] = maxf(float(out["len"]), send)
	(out["tips"] as Array).append(pts[segs - 1])
	(out["tip_s"] as Array).append(send)
	if depth <= 0:
		return
	var kids: int = int(o.get("kids", 2))
	var spread: float = float(o.get("spread", 0.7))
	var S: Array = [s0]
	for i in range(1, segs):
		var pa: Vector3 = pts[i]
		var pb: Vector3 = pts[i - 1]
		S.append(float(S[i - 1]) + pa.distance_to(pb))
	for k in kids:
		var ki = clampi(int(rng.randf_range(0.3, 0.8) * (segs - 1)), 1, segs - 2)
		var kp: Vector3 = pts[ki]
		var pn: Vector3 = pts[ki + 1]
		var pp: Vector3 = pts[ki - 1]
		var kd = (pn - pp).normalized()
		var ax = kd.cross(Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
		if ax.length() < 0.01:
			ax = kd.cross(Vector3.UP if absf(kd.y) < 0.9 else Vector3.RIGHT)
		var cd = kd.rotated(ax.normalized(), spread * rng.randf_range(0.6, 1.2))
		_tree_rec(g, kp, cd, L * rng.randf_range(0.4, 0.65), float(radii[ki]) * 0.6, float(S[ki]), depth - 1, o, out)


## Sarmal yol (yerel: y yukarı)
static func helix(r0: float, r1: float, h: float, turns: float, n: int, ph := 0.0, sgn := 1.0, y0 := 0.0) -> Array:
	var pts: Array = []
	for i in n:
		var q = float(i) / float(maxi(n - 1, 1))
		var a = ph + sgn * q * turns * TAU
		var r = lerpf(r0, r1, q)
		pts.append(Vector3(cos(a) * r, y0 + q * h, sin(a) * r))
	return pts


## İkinci derece Bezier
static func bez(p0: Vector3, p1: Vector3, p2: Vector3, n: int) -> Array:
	var pts: Array = []
	for i in n:
		var q = float(i) / float(maxi(n - 1, 1))
		pts.append(p0.lerp(p1, q).lerp(p1.lerp(p2, q), q))
	return pts


## Kare kesitli yontma direk (tepe kesik, açık renk). o.dir: eğik direk yönü
static func beam(g: Geo, base: Vector3, h: float, w: float, o := {}) -> float:
	var dirv: Vector3 = o.get("dir", Vector3.UP)
	var o2 = o.duplicate()
	o2["sides"] = 4
	o2["hard"] = true
	o2["a0"] = PI * 0.25
	o2["cap_end"] = true
	var n = int(maxf(2.0, h / 0.8)) + 1
	var pts: Array = []
	var radii: Array = []
	for i in n:
		pts.append(base + dirv.normalized() * h * float(i) / float(n - 1))
		radii.append(w * 0.7071)
	return tube(g, pts, radii, o2)


## Kesik kütük: kabuklu yan yüz + halkalı açık tepe
static func stump(g: Geo, base: Vector3, r: float, h: float, o := {}) -> float:
	var o2 = o.duplicate()
	o2["sides"] = int(o.get("sides", 30))
	o2["gnarl"] = float(o.get("gnarl", 0.03))
	o2["cap_end"] = true
	return tube(g, [base, base + Vector3.UP * h * 0.5, base + Vector3.UP * h], [r * 1.06, r, r * 0.98], o2)


# ================================================================== sahne yardımcıları
static func put(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	host.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func kill(host: Node, sec: float, n: Node) -> void:
	var w = weakref(n)
	host.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


## Etkin kameranın konumu (yoksa çok uzak bir nokta)
static func cam_pos(host: Node) -> Vector3:
	if host == null or not host.is_inside_tree():
		return Vector3(1e9, 1e9, 1e9)
	var cam = host.get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3(1e9, 1e9, 1e9)


static func near_cam(host: Node, p: Vector3, r: float) -> bool:
	return cam_pos(host).distance_to(p) < r


## Kameradan p'ye doğru yatay yön (parça kameraya değil uzağa savrulsun)
static func away_dir(host: Node, p: Vector3) -> Vector3:
	var a = p - cam_pos(host)
	a.y = 0.0
	return a.normalized() if a.length() > 0.01 and a.length() < 1e8 else Vector3.ZERO


static func floor_at(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z), p.z)


## Ahşap ağ örneği (+ "ol" kontur çocuğu). o: body, seed, grow, taper, nf, fresh, ow (0 = kontursuz), ocol, parent,
## soft (varsayılan true: kameraya yakın düzgün saydam silinme; false: opak + noktalı silinme, shadow ile gölge düşürür)
static func inst(host: Node, mesh: Mesh, pos: Vector3, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	var soft: bool = bool(o.get("soft", true))
	mi.material_override = wood_soft_mat() if soft else wood_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(o.get("shadow", false)) and not soft else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ow: float = float(o.get("ow", 0.04))
	if ow > 0.0:
		var ol = MeshInstance3D.new()
		ol.name = "ol"
		ol.mesh = mesh
		ol.material_override = outline_mat(ow, o.get("ocol", OUTLINE), soft)
		ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(ol)
	var parent: Node = o.get("parent", null)
	if parent != null:
		parent.add_child(mi)
		mi.position = pos
	else:
		put(host, mi, pos)
	var bc: Color = o.get("body", BARK)
	mi.set_instance_shader_parameter("body", v3(bc))
	mi.set_instance_shader_parameter("seed", float(o.get("seed", randf() * 10.0)))
	mi.set_instance_shader_parameter("fresh", float(o.get("fresh", 1.0)))
	mi.set_instance_shader_parameter("wither", 0.0)
	setp(mi, "grow", float(o.get("grow", 100000.0)))
	setp(mi, "taper", float(o.get("taper", 0.8)))
	setp(mi, "nf", float(o.get("nf", 3.0)))
	return mi


## Örnek parametresi (grow / taper / nf konturla birlikte)
static func setp(mi, key: String, val) -> void:
	if mi == null or not is_instance_valid(mi):
		return
	mi.set_instance_shader_parameter(key, val)
	if key in OL_KEYS:
		var ol = mi.get_node_or_null("ol")
		if ol:
			ol.set_instance_shader_parameter(key, val)


## Tween ayarlayıcısı
static func pf(mi, key: String) -> Callable:
	return func(val: float) -> void:
		setp(mi, key, val)


static func grow_to(mi: Node, a: float, b: float, dur: float, delay := 0.0, trans: Tween.TransitionType = Tween.TRANS_SINE, ease: Tween.EaseType = Tween.EASE_OUT) -> Tween:
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(pf(mi, "grow"), a, b, dur).set_trans(trans).set_ease(ease)
	return tw


## Yaşam döngüsü: delay → kökten uca büyü (t_in) → bekle → geri çekil ("retract") ya da kuruyup gömül ("sink") → sil.
## o: out ("retract" | "sink"), depth (gömülme), taper
static func life(mi: Node3D, L: float, t_in: float, hold: float, t_out: float, delay := 0.0, o := {}) -> Tween:
	var top = L + float(o.get("taper", 0.8)) + 0.05
	setp(mi, "grow", 0.0)
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(pf(mi, "grow"), 0.0, top, t_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	if String(o.get("out", "retract")) == "sink":
		tw.tween_method(pf(mi, "wither"), 0.0, 0.8, t_out * 0.5)
		tw.tween_property(mi, "position", mi.position - Vector3.UP * float(o.get("depth", 1.0)), t_out).set_ease(Tween.EASE_IN)
	else:
		tw.tween_method(pf(mi, "grow"), top, 0.0, t_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return tw


static func wither_to(mi: Node, a: float, b: float, dur: float, delay := 0.0) -> void:
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(pf(mi, "wither"), a, b, dur)


## Fırlatma: balistik yol, dönme, zemine oturma, küçülüp silinme
static func toss(n: Node3D, p0: Vector3, v: Vector3, life_t: float, grav := 18.0) -> void:
	var spin = Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
	var r0 = n.rotation
	var s0 = n.scale
	var st = {"tr": 0.0}
	var tw = n.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(n):
			return
		var q = p0 + v * t + Vector3.DOWN * 0.5 * grav * t * t
		var fl = Game.jutsu_floor(q.x, q.z) + 0.05
		if q.y >= fl:
			st["tr"] = t
		q.y = maxf(q.y, fl)
		n.global_position = q
		n.rotation = r0 + spin * float(st["tr"]), 0.0, life_t, life_t)
	tw.tween_property(n, "scale", s0 * 0.05, 0.35)
	tw.tween_callback(n.queue_free)


## Kısa süreli sıcak ışık
static func light(host: Node, p: Vector3, col: Color, energy: float, rng: float, life_t: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	put(host, l, p)
	var tw = l.create_tween()
	tw.tween_interval(life_t * 0.6)
	tw.tween_property(l, "light_energy", 0.0, life_t * 0.4)
	tw.tween_callback(l.queue_free)
	return l


# ================================================================== parçacık / kıymık
static func _shrink_curve() -> Curve:
	if _cache.has("shrink"):
		return _cache["shrink"]
	var c = Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.75, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	_cache["shrink"] = c
	return c


## Üç yüzlü yassı kıymık (bir yüz açık, iki yüz koyu: cel)
static func _chip_mesh() -> ArrayMesh:
	if _cache.has("chip"):
		return _cache["chip"]
	var g = Geo.new()
	tube(g, [Vector3(-0.5, 0, 0), Vector3(-0.1, 0, 0), Vector3(0.5, 0, 0)], [0.05, 0.16, 0.02], {"sides": 3, "hard": true, "cap_end": false,
		"sy": 0.45, "face_tint": [Color(1, 1, 1), Color(0.72, 0.72, 0.72), Color(0.5, 0.5, 0.5)]})
	var m = g.build()
	_cache["chip"] = m
	return m


## Yaprak: orta damarlı baklava (iki yüz)
static func _leaf_mesh() -> ArrayMesh:
	if _cache.has("leaf"):
		return _cache["leaf"]
	var g = Geo.new()
	var z = Vector3.ZERO
	var a = g.add(Vector3(0, 0.5, 0), Vector3.BACK, Vector3.BACK, Color(1, 1, 1), Vector2.ZERO, Vector2.ZERO, z)
	var b = g.add(Vector3(0.24, 0.05, 0.03), Vector3.BACK, Vector3.BACK, Color(1, 1, 1), Vector2.ZERO, Vector2.ZERO, z)
	var c = g.add(Vector3(0, -0.5, 0), Vector3.BACK, Vector3.BACK, Color(0.85, 0.85, 0.85), Vector2.ZERO, Vector2.ZERO, z)
	var d = g.add(Vector3(-0.24, 0.05, 0.03), Vector3.BACK, Vector3.BACK, Color(0.72, 0.72, 0.72), Vector2.ZERO, Vector2.ZERO, z)
	var e = g.add(Vector3(0, 0.0, -0.04), Vector3.BACK, Vector3.BACK, Color(0.6, 0.6, 0.6), Vector2.ZERO, Vector2.ZERO, z)
	g.tri(a, b, e)
	g.tri(b, c, e)
	g.tri(c, d, e)
	g.tri(d, a, e)
	var m = g.build()
	_cache["leaf"] = m
	return m


## Kabuk kıymığı patlaması. o: col, life, burst, dir, spread, g (yerçekimi), size, rad
static func chips(host: Node, p: Vector3, n: int, spd: float, o := {}) -> CPUParticles3D:
	var cp = CPUParticles3D.new()
	cp.mesh = _chip_mesh()
	cp.material_override = plain_mat()
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cp.amount = maxi(n, 1)
	var lt: float = float(o.get("life", 1.0))
	cp.lifetime = lt
	cp.one_shot = true
	cp.explosiveness = float(o.get("burst", 0.92))
	cp.randomness = 0.4
	cp.local_coords = false
	var cdir: Vector3 = o.get("dir", Vector3.UP)
	if bool(o.get("away", true)):
		cdir = (cdir.normalized() + away_dir(host, p) * 0.7).normalized()
	cp.direction = cdir
	cp.spread = float(o.get("spread", 65.0))
	cp.initial_velocity_min = spd * 0.45
	cp.initial_velocity_max = spd
	cp.gravity = Vector3(0, -float(o.get("g", 18.0)), 0)
	cp.damping_min = 0.3
	cp.damping_max = 1.2
	cp.particle_flag_rotate_y = true
	cp.angle_max = 360.0
	cp.angular_velocity_min = -720.0
	cp.angular_velocity_max = 720.0
	var s: float = float(o.get("size", 0.35))
	cp.scale_amount_min = s * 0.5
	cp.scale_amount_max = s * 1.3
	cp.scale_amount_curve = _shrink_curve()
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = float(o.get("rad", 0.4))
	var cb: Color = o.get("col", BARK)
	var ga = Gradient.new()
	ga.set_color(0, cb.darkened(0.2))
	ga.set_color(1, FRESH if not o.has("col2") else (o["col2"] as Color))
	ga.add_point(0.55, cb)
	cp.color_initial_ramp = ga
	put(host, cp, p)
	cp.emitting = true
	kill(host, lt + 0.6, cp)
	return cp


## Yaprak savrulması (hafif yerçekimi, çok sönüm, dönerek). o: col, life, dir, spread, size, rad
static func leaves(host: Node, p: Vector3, n: int, spd: float, o := {}) -> CPUParticles3D:
	var cp = CPUParticles3D.new()
	cp.mesh = _leaf_mesh()
	cp.material_override = plain_mat(true)
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cp.amount = maxi(n, 1)
	var lt: float = float(o.get("life", 1.8))
	cp.lifetime = lt
	cp.one_shot = true
	cp.explosiveness = float(o.get("burst", 0.85))
	cp.randomness = 0.5
	cp.local_coords = false
	cp.direction = o.get("dir", Vector3.UP)
	cp.spread = float(o.get("spread", 80.0))
	cp.initial_velocity_min = spd * 0.4
	cp.initial_velocity_max = spd
	cp.gravity = Vector3(0, -3.0, 0)
	cp.damping_min = 2.0
	cp.damping_max = 3.5
	cp.particle_flag_rotate_y = true
	cp.angle_max = 360.0
	cp.angular_velocity_min = -400.0
	cp.angular_velocity_max = 400.0
	var s: float = float(o.get("size", 0.3))
	cp.scale_amount_min = s * 0.7
	cp.scale_amount_max = s * 1.3
	cp.scale_amount_curve = _shrink_curve()
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = float(o.get("rad", 0.5))
	var cl: Color = o.get("col", LEAF)
	var ga = Gradient.new()
	ga.set_color(0, cl.darkened(0.25))
	ga.set_color(1, cl.lightened(0.25))
	cp.color_initial_ramp = ga
	put(host, cp, p)
	cp.emitting = true
	kill(host, lt + 0.6, cp)
	return cp


## İğ biçimli iri kıymık (kabuklu, iki ucu sivri)
static func _splinter_mesh(variant: int) -> ArrayMesh:
	var key = "spl_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var g = Geo.new()
	var bend = [0.0, 0.12, -0.1][variant % 3]
	tube(g, [Vector3(0, 0, -0.5), Vector3(bend, 0.03, -0.15), Vector3(bend * 0.5, 0, 0.2), Vector3(0, -0.02, 0.5)], [0.02, 0.14, 0.11, 0.015],
		{"sides": 5, "hard": true, "cap_end": false, "sy": 0.6, "a0": variant * 0.4})
	var m = g.build()
	_cache[key] = m
	return m


## İri ahşap kıymıkları fırlar (kameradan uzağa), yere oturur, küçülüp silinir. o: col, up (dikey ağırlık), life, g, away
static func splinters(host: Node, p: Vector3, n: int, s: float, spd: float, o := {}) -> void:
	var col: Color = o.get("col", BARK)
	var upw: float = float(o.get("up", 0.9))
	var lt: float = float(o.get("life", 1.1))
	var aw = away_dir(host, p) if bool(o.get("away", true)) else Vector3.ZERO
	for k in n:
		var mi = inst(host, _splinter_mesh(k % 3), p + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.3), randf_range(-0.3, 0.3)) * s,
			{"body": col, "ow": 0.018, "nf": 1.5})
		mi.scale = Vector3.ONE * s * randf_range(0.6, 1.3)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var hd = (Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() + aw * 1.4).normalized()
		var v = (hd + Vector3.UP * upw * randf_range(0.6, 1.4)).normalized() * spd * randf_range(0.5, 1.0)
		toss(mi, mi.global_position, v, lt * randf_range(0.8, 1.2), float(o.get("g", 18.0)))


static func _ball() -> SphereMesh:
	if _cache.has("ball"):
		return _cache["ball"]
	var s = SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 14
	s.rings = 7
	_cache["ball"] = s
	return s


static func _plane() -> PlaneMesh:
	if _cache.has("plane"):
		return _cache["plane"]
	var p = PlaneMesh.new()
	p.size = Vector2(2.0, 2.0)
	_cache["plane"] = p
	return p


## Tek örnek parametresi ayarlayıcısı (kontursuz düğüm)
static func pi_set(mi, key: String) -> Callable:
	return func(val: float) -> void:
		if mi != null and is_instance_valid(mi):
			mi.set_instance_shader_parameter(key, val)


## Cel toz topağı: şişer, kayar, noktalı dağılır. o: col, vel, nf
static func dust(host: Node, p: Vector3, s: float, life_t: float, o := {}) -> MeshInstance3D:
	if near_cam(host, p, s * 0.8 + 3.0):
		return null
	var mi = MeshInstance3D.new()
	mi.mesh = _ball()
	mi.material_override = dust_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(host, mi, p)
	var c: Color = o.get("col", Color(0.8, 0.7, 0.54))
	mi.set_instance_shader_parameter("col", v3(c))
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	mi.set_instance_shader_parameter("nf", maxf(float(o.get("nf", 6.0)), 6.0))
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	mi.scale = Vector3.ONE * s * 0.35
	var vel: Vector3 = o.get("vel", Vector3.UP * 0.6)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * s, life_t * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", p + vel * life_t, life_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(pi_set(mi, "fade"), 0.0, 1.0, life_t * 0.6).set_delay(life_t * 0.4)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Halka biçiminde dışa yayılan toz topakları
static func dust_ring(host: Node, c: Vector3, r: float, n: int, s: float, life_t: float, o := {}) -> void:
	var col: Color = o.get("col", dust_col(c))
	var spd: float = float(o.get("spd", r * 0.8))
	for k in n:
		var a = TAU * k / n + randf_range(-0.2, 0.2)
		var d = Vector3(cos(a), 0.0, sin(a))
		var q = floor_at(c + d * r) + Vector3.UP * s * 0.3
		dust(host, q, s * randf_range(0.75, 1.25), life_t * randf_range(0.85, 1.15), {"col": col, "vel": d * spd + Vector3.UP * 0.5, "nf": float(o.get("nf", 3.0))})


## Zemin izi. o: soil, glow (Color), lines, pit, rings, t_open, y (sabit yükseklik), parent
static func scar(host: Node, p: Vector3, r: float, life_t: float, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _plane()
	mi.material_override = scar_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node = o.get("parent", null)
	if parent != null:
		parent.add_child(mi)
		mi.position = p
	else:
		var fl = Vector3(p.x, Game.jutsu_floor(p.x, p.z) + 0.05 + r * 0.004, p.z)
		if o.has("y"):
			fl.y = float(o["y"])
		put(host, mi, fl)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r, 1.0, r)
	var sl: Color = o.get("soil", soil_col(p))
	var gl: Color = o.get("glow", Color(0, 0, 0))
	mi.set_instance_shader_parameter("soil", v3(sl))
	mi.set_instance_shader_parameter("glow", v3(gl))
	mi.set_instance_shader_parameter("lines", float(o.get("lines", 9.0)))
	mi.set_instance_shader_parameter("pit", float(o.get("pit", 1.0)))
	mi.set_instance_shader_parameter("rings", float(o.get("rings", 0.0)))
	mi.set_instance_shader_parameter("seed", randf() * 30.0)
	mi.set_instance_shader_parameter("open", 0.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	var tw = mi.create_tween()
	tw.tween_method(pi_set(mi, "open"), 0.0, 1.0, float(o.get("t_open", 0.25))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life_t * 0.65)
	tw.tween_method(pi_set(mi, "fade"), 0.0, 1.0, life_t * 0.35)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== karakter üstü ahşap örtü
## Modelin tüm ağlarına ahşap kabuk örtüsü koyar; eski örtüleri döndürür (skin_off geri yükler)
static func skin_on(model: Node, body: Color, base_y: float, span := 1.9, peel := 0.0) -> Array:
	var out: Array = []
	if model == null or not is_instance_valid(model):
		return out
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		out.append([mi, mi.material_overlay])
		mi.material_overlay = skin_mat()
		mi.set_instance_shader_parameter("wsk_body", v3(body))
		mi.set_instance_shader_parameter("wsk_base", base_y)
		mi.set_instance_shader_parameter("wsk_span", span)
		mi.set_instance_shader_parameter("wsk_peel", peel)
	return out


## Örtü soyulma değeri (base_y verilirse taban da güncellenir: hareket eden beden)
static func skin_peel(list: Array, val: float, base_y := -99999.0) -> void:
	for e in list:
		var mi = e[0]
		if mi != null and is_instance_valid(mi):
			mi.set_instance_shader_parameter("wsk_peel", val)
			if base_y > -99990.0:
				mi.set_instance_shader_parameter("wsk_base", base_y)


static func skin_off(list: Array) -> void:
	for e in list:
		var mi = e[0]
		if mi != null and is_instance_valid(mi) and mi.material_overlay == skin_mat():
			mi.material_overlay = e[1]
