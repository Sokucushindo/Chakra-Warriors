class_name KamishiroFXA
extends RefCounted
## Kamizuru (arı klanı) + Shirogane / kuklacı grubu A.
## Arılar: çizgili turuncu-siyah karınlı, kanat çırpan cel arılar (sürü = tek MultiMesh, kanatlar gölgelendiricide çırpar);
## bal / bal mumu: parlak kehribar sıvı → sertleşip petek desenli mat muma döner; dev arı (karnı kıvrılıp sokar).
## Kuklalar oyunun GERÇEK modelleriyle (ClanConstruct kuklası, _puppet_mesh, Karasu başı); parmak uçlarından mavi chakra
## iplikleri, Kuroari'nin bantlı yumurta gövdesi (kapıları açılıp kapanır), Karasu'nun bıçaklı eklemli kolları, demir bomba,
## mor zehir pusu, Chikamatsu'nun beyaz cüppeli kuklaları ve elmas desenli parşömeni, Kikō Junbū'nun çapraz tahta kolları.
## Her şey bu dosyada sıfırdan: kendi gölgelendiricileri (toon + kontur + kanat çırpma, bal, chakra ipliği, parçacık,
## zemin izi, patlama topu, bal örtüsü) ve mesh kurucuları. Kamera yakınında her katman titreşimli seyrelir (ekranı kaplamaz).
## Oynanış ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}

const HONEY_C := Color(1.0, 0.72, 0.15)
const THREAD_C := Color(0.5, 0.82, 1.0)
const WOOD_C := Color(0.82, 0.71, 0.6)
const WOOD_D := Color(0.55, 0.45, 0.38)
const STEEL_C := Color(0.8, 0.82, 0.87)
const POISON_C := Color(0.6, 0.28, 0.72)
const KURO_C := Color(0.8, 0.64, 0.48)
const FINGER_BONES := ["ThumbDistal", "IndexDistal", "MiddleDistal", "RingDistal", "LittleDistal"]
## Kukla (ClanConstruct görseli, model -Z'ye bakar) üzerinde iplik bağlanan noktalar: baş, omuzlar, kalça
const PUP_PTS := [Vector3(0, 1.78, -0.1), Vector3(-0.3, 1.36, -0.1), Vector3(0.3, 1.36, -0.1), Vector3(-0.14, 0.8, 0.0), Vector3(0.14, 0.8, 0.0)]

# ================================================================== gölgelendiriciler
## Toon (köşe rengi) + ters kabuk kontur; COLOR.a < 0.75 olan köşeler kanattır: gövde ekseni (Z) çevresinde çırpar
const TOON_HEAD := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float near_d = 1.0;
instance uniform float pulse = 0.0;
instance uniform float flap = 0.0;
instance uniform float ow = 0.012;
instance uniform float seed = 0.0;
instance uniform float wet = 0.0;
instance uniform float cut = 2.0;
instance uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 olc = vec4(0.07, 0.06, 0.07, 1.0);

varying vec3 vn;
varying vec3 lpos;
varying float wing;

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void vertex() {
	lpos = VERTEX;
	wing = 1.0 - step(0.75, COLOR.a);
	if (wing > 0.5 && flap > 0.0) {
		float sx = sign(VERTEX.x);
		float ang = (sin(TIME * flap + seed + float(INSTANCE_ID) * 1.7) * 0.8 + 0.2) * sx;
		float ca = cos(ang);
		float sa = sin(ang);
		vec2 p = vec2(VERTEX.x, VERTEX.y - 0.14);
		VERTEX = vec3(p.x * ca - p.y * sa, p.x * sa + p.y * ca + 0.14, VERTEX.z);
		NORMAL = vec3(NORMAL.x * ca - NORMAL.y * sa, NORMAL.x * sa + NORMAL.y * ca, NORMAL.z);
	}
//GROW
	vn = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
"""

const GROW_LINE := "	VERTEX += NORMAL * ow * clamp(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z * 0.07, 0.7, 3.0);"

const TOON_F := """
void fragment() {
	if (cut < 1.5 && atan(lpos.x, lpos.z) * 0.1591549 + 0.5 > cut) {
		discard;
	}
	float nf = fade * smoothstep(near_d * 0.4, near_d, -VERTEX.z);
	if (nf < 0.999 && nf < ign(FRAGCOORD.xy)) {
		discard;
	}
	if (wing > 0.5 && 0.62 < ign(FRAGCOORD.xy + vec2(7.0, 3.0))) {
		discard;
	}
	vec3 n = normalize(vn);
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	vec3 ld = normalize((VIEW_MATRIX * vec4(-0.35, 0.8, 0.45, 0.0)).xyz);
	float ndl = dot(n, ld);
	vec3 base = COLOR.rgb * tint.rgb;
	vec3 col = mix(base * vec3(0.58, 0.58, 0.68), base, smoothstep(-0.05, 0.05, ndl));
	float spec = smoothstep(0.9, 0.94, dot(n, normalize(ld + VIEW))) * (0.12 + wet * 0.75);
	col = mix(col, vec3(1.0), spec);
	col = mix(col, vec3(1.0), wing * 0.3);
	col = mix(col, vec3(1.0, 0.95, 0.8), pulse);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
}
"""

const TOON_OUT := """
void fragment() {
	if (ow <= 0.0) {
		discard;
	}
	if (cut < 1.5 && atan(lpos.x, lpos.z) * 0.1591549 + 0.5 > cut) {
		discard;
	}
	float nf = fade * smoothstep(near_d * 0.4, near_d, -VERTEX.z);
	if (nf < 0.999 && nf < ign(FRAGCOORD.xy)) {
		discard;
	}
	if (wing > 0.5 && 0.62 < ign(FRAGCOORD.xy + vec2(7.0, 3.0))) {
		discard;
	}
	if (dot(normalize(vn), VIEW) > 0.0) {
		discard;
	}
	ALBEDO = pow(olc.rgb, vec3(2.2));
}
"""

## Bal: koyu kehribar gövde, kenarda derin turuncu, keskin beyaz parlama; wax 1'e giderken soluk sarı mat muma ve petek
## çizgilerine döner; sıvıyken köşeler kıpırdar ve alt yüzey sarkar (damlayacakmış gibi)
const HONEY_HEAD := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float near_d = 1.0;
instance uniform float wax = 0.0;
instance uniform float wob = 0.04;
instance uniform float seed = 0.0;
instance uniform float pulse = 0.0;
instance uniform float ow = 0.02;
instance uniform vec4 olc = vec4(0.36, 0.17, 0.02, 1.0);

varying vec3 vn;
varying vec3 lpos;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float hexd(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 hh = r * 0.5;
	vec2 a = mod(p, r) - hh;
	vec2 b = mod(p - hh, r) - hh;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, vec2(0.5, 0.8660254)), q.x);
}

void vertex() {
	lpos = VERTEX;
	float w = wob * (1.0 - wax);
	float nz = vn3(VERTEX * 4.0 + vec3(TIME * 0.7 + seed, seed, 0.0)) - 0.5;
	VERTEX += NORMAL * nz * w;
	float hang = 0.5 + 0.5 * sin(TIME * 1.8 + seed + VERTEX.x * 5.0);
	VERTEX.y -= w * 0.8 * hang * (1.0 - step(0.0, VERTEX.y));
//GROW
	vn = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
"""

const HONEY_F := """
void fragment() {
	float nf = fade * smoothstep(near_d * 0.4, near_d, -VERTEX.z);
	if (nf < 0.999 && nf < ign(FRAGCOORD.xy)) {
		discard;
	}
	vec3 n = normalize(vn);
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	vec3 ld = normalize((VIEW_MATRIX * vec4(-0.35, 0.8, 0.45, 0.0)).xyz);
	float ndl = dot(n, ld);
	float fr = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	float nh = dot(n, normalize(ld + VIEW));
	vec3 col = mix(vec3(0.97, 0.56, 0.07), vec3(1.0, 0.8, 0.26), smoothstep(0.2, 0.3, ndl));
	col = mix(col, vec3(0.6, 0.26, 0.02), smoothstep(0.58, 0.68, fr));
	col = mix(col, vec3(1.0, 0.86, 0.4), smoothstep(0.9, 0.97, fr) * 0.7);
	float spec = smoothstep(0.93, 0.95, nh);
	float spec2 = smoothstep(0.975, 0.985, dot(n, normalize(vec3(0.35, 0.45, 1.0))));
	float hx = 1.0 - smoothstep(0.02, 0.06, hexd(lpos.xz * 5.0 + vec2(lpos.y * 2.0, 0.0)));
	vec3 wc = mix(vec3(0.84, 0.62, 0.26), vec3(1.0, 0.87, 0.5), smoothstep(-0.05, 0.05, ndl));
	wc = mix(wc, vec3(0.58, 0.38, 0.12), hx * 0.75);
	col = mix(col, wc, wax);
	col = mix(col, vec3(1.0, 0.98, 0.9), clamp(spec + spec2 * 0.8, 0.0, 1.0) * (1.0 - wax * 0.8));
	col = mix(col, vec3(1.0, 0.95, 0.7), pulse);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
}
"""

const HONEY_OUT := """
void fragment() {
	if (ow <= 0.0) {
		discard;
	}
	float nf = fade * smoothstep(near_d * 0.4, near_d, -VERTEX.z);
	if (nf < 0.999 && nf < ign(FRAGCOORD.xy)) {
		discard;
	}
	if (dot(normalize(vn), VIEW) > 0.0) {
		discard;
	}
	ALBEDO = pow(mix(olc.rgb, vec3(0.45, 0.33, 0.15), wax), vec3(2.2));
}
"""

## Chakra ipliği: dünya uzayında köşe; kalınlık kameraya uzaklıkla büyür (uzakta okunur, yakında incecik), hafif sarkma,
## parmaktan dışa uzama (reveal), boyunca akan parlak boncuklar, beyaz çekirdek
const THREAD_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled, world_vertex_coords;

instance uniform float fade = 1.0;
instance uniform float sag = 0.0;
instance uniform float thick = 0.011;
instance uniform float seed = 0.0;
instance uniform float reveal = 1.01;
instance uniform vec4 tint = vec4(0.5, 0.82, 1.0, 1.0);

varying float along;

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void vertex() {
	along = UV.y;
	float t = UV.y;
	VERTEX.y -= sag * 4.0 * t * (1.0 - t);
	float dc = length(VERTEX - CAMERA_POSITION_WORLD);
	VERTEX += normalize(NORMAL) * thick * clamp(dc * 0.09, 0.6, 4.0);
	VERTEX += vec3(sin(t * 19.0 + TIME * 7.0 + seed), cos(t * 15.0 + TIME * 6.0 + seed), 0.0) * 0.006 * sin(t * 3.14159);
}

void fragment() {
	if (along > reveal) {
		discard;
	}
	float nf = fade * smoothstep(0.3, 0.9, -VERTEX.z);
	if (nf < 0.999 && nf < ign(FRAGCOORD.xy)) {
		discard;
	}
	float facing = abs(dot(normalize(NORMAL), VIEW));
	float bead = smoothstep(0.9, 1.0, sin(along * 22.0 - TIME * 9.0 + seed));
	vec3 col = mix(tint.rgb * 0.7, mix(tint.rgb, vec3(1.0), 0.65), smoothstep(0.35, 0.8, facing));
	col = mix(col, vec3(1.0), bead * 0.6);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
}
"""

## Parçacık (kameraya dönük kare): 0 damla (bal / zehir / kan), 1 zehir pusu (iki tonlu kabarık bulut, koyu kenar),
## 2 kıymık / şarapnel, 3 kıvılcım, 4 alev topağı, 5 toz, 6 kâğıt / kumaş parçası, 7 kor
const PART_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float near_d = 1.5;
instance uniform float fade = 1.0;

varying float rnd;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	rnd = fract(float(INSTANCE_ID) * 0.6180339);
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float ra = rnd * 6.2832 + TIME * (rnd - 0.5) * 3.0;
	vec2 rq = vec2(q.x * cos(ra) - q.y * sin(ra), q.x * sin(ra) + q.y * cos(ra));
	float r = length(q);
	vec3 col = COLOR.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		float d = length(q * vec2(1.0, 0.85) + vec2(0.0, 0.12));
		a = 1.0 - step(0.62, d);
		col = mix(col, col * 0.45, step(0.48, d));
		col = mix(col, vec3(1.0), 1.0 - step(0.13, length(q - vec2(-0.18, 0.2))));
	} else if (kind < 1.5) {
		float n = vn2(rq * 2.2 + vec2(rnd * 17.0, TIME * 0.25)) * 0.5 + vn2(rq * 5.0 - vec2(TIME * 0.4, rnd * 9.0)) * 0.25;
		float d = r + (n - 0.38) * 0.6;
		float rim = smoothstep(0.5, 0.6, d);
		col = mix(col * 0.72, col * 1.12, step(0.5, n + q.y * 0.3));
		col = mix(col, col * 0.4, rim);
		a = 1.0 - smoothstep(0.62, 0.68, d);
	} else if (kind < 2.5) {
		vec2 p = abs(rq);
		a = 1.0 - step(0.85, p.x * 2.6 + p.y);
		col = mix(col * 0.5, col, step(0.0, rq.x));
	} else if (kind < 3.5) {
		float ax = (1.0 - smoothstep(0.0, 0.1, abs(rq.y))) * (1.0 - abs(rq.x));
		float ay = (1.0 - smoothstep(0.0, 0.1, abs(rq.x))) * (1.0 - abs(rq.y)) * 0.6;
		float core = 1.0 - smoothstep(0.08, 0.25, r);
		a = clamp(max(max(ax, ay), core), 0.0, 1.0);
		col = mix(col, vec3(1.0), core);
	} else if (kind < 4.5) {
		float n = vn2(rq * 3.0 + vec2(rnd * 11.0, -TIME * 2.0));
		float d = r + (n - 0.5) * 0.35;
		a = 1.0 - step(0.7, d);
		col = mix(vec3(1.0, 0.95, 0.7), col, step(0.3, d));
		col = mix(col, col * 0.45, step(0.58, d));
	} else if (kind < 5.5) {
		float n = vn2(rq * 2.5 + vec2(rnd * 13.0));
		float d = r + (n - 0.5) * 0.4;
		a = (1.0 - smoothstep(0.55, 0.7, d)) * 0.8;
		col = mix(col * 0.78, col, step(0.0, q.y + (n - 0.5) * 0.3));
	} else if (kind < 6.5) {
		vec2 p = abs(rq * vec2(1.0, 1.6));
		float m = max(p.x, p.y) + (h21(floor(rq * 6.0) + vec2(rnd)) - 0.5) * 0.1;
		a = 1.0 - step(0.6, m);
		col = mix(col, col * 0.35, step(0.45, m));
	} else {
		a = 1.0 - smoothstep(0.0, 0.5, r);
		col = mix(col, vec3(1.0, 0.95, 0.75), 1.0 - smoothstep(0.0, 0.2, r));
	}
	a *= COLOR.a * fade * smoothstep(near_d * 0.35, near_d, -VERTEX.z);
	if (a < 0.01) {
		discard;
	}
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Zemin izi (yere yatık düzlem): 0 çatlak + ezik çukur, 1 is lekesi + sönen kor kenar, 2 petek mührü (merkezden dışa çizilir),
## 3 mor zehir lekesi (ıslak, kabarcıklı)
const DECAL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float fade = 1.0;
instance uniform float draw = 1.0;
instance uniform float seed = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float hexd(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 hh = r * 0.5;
	vec2 a = mod(p, r) - hh;
	vec2 b = mod(p - hh, r) - hh;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, vec2(0.5, 0.8660254)), q.x);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (kind < 0.5) {
		float k = ang * 1.5915494 + 5.0;
		float j = vn2(vec2(r * 5.0, floor(k) + seed)) - 0.5;
		float d = abs(fract(k + j * 0.35) - 0.5) * r * 0.63;
		float w = 0.025 * (1.0 - r) + 0.004;
		float crack = (1.0 - smoothstep(w * 0.6, w, d)) * step(0.12, r) * (1.0 - smoothstep(0.7 + h21(vec2(floor(k), seed)) * 0.25, 1.0, r));
		float ring = 1.0 - smoothstep(0.0, 0.018, abs(r - 0.42 - (vn2(vec2(ang * 3.0, seed)) - 0.5) * 0.12));
		float pit = 1.0 - smoothstep(0.18, 0.3, r + (vn2(p * 6.0 + vec2(seed)) - 0.5) * 0.1);
		col = mix(vec3(0.27, 0.2, 0.14), vec3(0.07, 0.05, 0.04), max(crack, ring));
		a = max(max(crack, ring * 0.9 * step(r, 0.5)), pit * 0.55);
	} else if (kind < 1.5) {
		float n = vn2(p * 3.0 + vec2(seed)) * 0.35 + vn2(p * 9.0 - vec2(seed)) * 0.15;
		float rr = r + n - 0.25;
		float body = 1.0 - smoothstep(0.55, 0.75, rr);
		float edge = body * (1.0 - smoothstep(0.0, 0.12, abs(rr - 0.62)));
		col = mix(vec3(0.07, 0.06, 0.06), vec3(1.0, 0.45, 0.08), edge * draw);
		a = body * 0.85;
	} else if (kind < 2.5) {
		float hx = 1.0 - smoothstep(0.03, 0.07, hexd(p * 4.0));
		float ring = max(1.0 - smoothstep(0.015, 0.03, abs(r - 0.94)), 1.0 - smoothstep(0.01, 0.022, abs(r - 0.86)));
		float show = 1.0 - smoothstep(draw - 0.08, draw, r);
		col = mix(vec3(0.75, 0.42, 0.04), vec3(1.0, 0.86, 0.36), 0.5 + 0.5 * sin(TIME * 4.0 - r * 8.0));
		a = max(hx * step(r, 0.84), ring) * show;
	} else {
		float n = vn2(p * 2.5 + vec2(seed)) * 0.4 + vn2(p * 7.0) * 0.15;
		float rr = r + n - 0.3;
		float body = 1.0 - smoothstep(0.6, 0.66, rr);
		float rim = body * smoothstep(0.48, 0.6, rr);
		float bub = step(0.86, vn2(p * 14.0 + vec2(TIME * 0.3, seed))) * body;
		col = mix(vec3(0.34, 0.12, 0.42), vec3(0.16, 0.04, 0.2), rim);
		col = mix(col, vec3(0.75, 0.5, 0.85), bub);
		a = body * 0.8;
	}
	a *= fade;
	if (a < 0.01) {
		discard;
	}
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Patlama topu: köşeleri kaynayan küre; merkez beyaz-sarı → turuncu → kızıl kenar konturu, gürültüyle yanıp delinerek söner.
## hue 0: demir bomba (sarı-beyaz, iri), 1: patlayıcı etiket (kızıl-turuncu dil)
const BLAST_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled;

instance uniform float burn = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float hue = 0.0;

varying vec3 lpos;
varying vec3 vn;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void vertex() {
	lpos = VERTEX;
	VERTEX += NORMAL * (vn3(VERTEX * 3.0 + vec3(seed, TIME * 2.0, 0.0)) - 0.5) * 0.28;
	vn = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float nf = fade * smoothstep(0.8, 2.2, -VERTEX.z);
	if (nf < 0.999 && nf < ign(FRAGCOORD.xy)) {
		discard;
	}
	float n = vn3(lpos * 4.0 + vec3(seed)) * 0.7 + vn3(lpos * 9.0 - vec3(seed)) * 0.3;
	if (n < burn) {
		discard;
	}
	vec3 nn = normalize(vn);
	if (dot(nn, VIEW) < 0.0) {
		nn = -nn;
	}
	float fr = 1.0 - clamp(dot(nn, VIEW), 0.0, 1.0);
	float edge = smoothstep(burn, burn + 0.08, n);
	vec3 c0 = mix(vec3(1.0, 0.98, 0.82), vec3(1.0, 0.9, 0.6), hue);
	vec3 c1 = mix(vec3(1.0, 0.84, 0.22), vec3(1.0, 0.55, 0.12), hue);
	vec3 c2 = mix(vec3(0.98, 0.5, 0.08), vec3(0.85, 0.18, 0.05), hue);
	float s = fr + burn * 0.45;
	vec3 col = mix(c0, c1, step(0.32, s));
	col = mix(col, c2, step(0.62, s));
	col = mix(col, vec3(0.3, 0.08, 0.03), step(0.86, fr));
	col = mix(vec3(0.22, 0.1, 0.07), col, edge);
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
}
"""

## Bal örtüsü (bal klonunun gövdesine bindirilen katman): taban çizgisinin altı tamamen bal (yükselen bal), üstünde
## parlak kehribar zar ve aşağı süzülen bal damarları
const VEIL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

instance uniform float cover = 0.0;
instance uniform float rise = 10.0;
instance uniform float base_y = 0.0;

varying vec3 wp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float hgt = wp.y - base_y;
	float below = 1.0 - smoothstep(rise - 0.08, rise, hgt + (vn2(wp.xz * 9.0) - 0.5) * 0.12);
	float drip = smoothstep(0.62, 0.8, vn2(vec2((wp.x + wp.z) * 7.0, hgt * 1.2 + TIME * 0.35)));
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 ld = normalize((VIEW_MATRIX * vec4(-0.3, 0.85, 0.4, 0.0)).xyz);
	float spec = smoothstep(0.93, 0.96, dot(reflect(-VIEW, NORMAL), ld));
	vec3 col = mix(vec3(1.0, 0.68, 0.12), vec3(0.7, 0.32, 0.03), smoothstep(0.4, 0.8, fr));
	col = mix(col, vec3(1.0, 0.97, 0.88), spec);
	float a = max(below, cover * (0.3 + drip * 0.45));
	a = max(a, spec * cover);
	if (a < 0.01) {
		discard;
	}
	ALBEDO = pow(clamp(col, vec3(0.0), vec3(1.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 0.95);
}
"""


# ================================================================== malzemeler
static func _shader(key: String, code: String) -> Shader:
	var k = "shd:" + key
	if not _cache.has(k):
		var s = Shader.new()
		s.code = code
		_cache[k] = s
	return _cache[k]


static func _outlined(key: String, head: String, body: String, out: String) -> ShaderMaterial:
	var k = "mat:" + key
	if _cache.has(k):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shader(key, head.replace("//GROW", "") + body)
	var o = ShaderMaterial.new()
	o.shader = _shader(key + "_out", head.replace("//GROW", GROW_LINE) + out)
	m.next_pass = o
	_cache[k] = m
	return m


static func _toon() -> ShaderMaterial:
	return _outlined("toon", TOON_HEAD, TOON_F, TOON_OUT)


static func _honey() -> ShaderMaterial:
	return _outlined("honey", HONEY_HEAD, HONEY_F, HONEY_OUT)


static func _plain(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _shader(key, code)
		_cache[k] = m
	return _cache[k]


static func _setp(gi: GeometryInstance3D, d: Dictionary) -> void:
	for k in d:
		var v = d[k]
		if typeof(v) == TYPE_INT:
			v = float(v)
		gi.set_instance_shader_parameter(k, v)


static func _mi(mesh: Mesh, mat: Material, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d := {"seed": randf() * 10.0}
	d.merge(o, true)
	_setp(mi, d)
	return mi


static func _tp(gi: GeometryInstance3D, pname: String, a: float, b: float, dur: float, delay := 0.0) -> Tween:
	var tw = gi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter(pname, v), a, b, dur)
	return tw


static func _gis(n: Node) -> Array:
	var out = []
	if n is GeometryInstance3D:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_gis(ch))
	return out


## Titreşimli sönüp silinme (düğüm ve altındaki kendi gölgelendiricili tüm geometriler)
static func _vanish(n: Node3D, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var gl = _gis(n)
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		for g in gl:
			if is_instance_valid(g):
				g.set_instance_shader_parameter("fade", v), 1.0, 0.0, dur)
	tw.tween_callback(n.queue_free)


## Hazır model (oyunun kukla modeli, kendi malzemesi): küçülüp silinir
static func _shrink(n: Node3D, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(n, "scale", n.scale * 0.04, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


## Birim tüp (0 → -Z 1) iki nokta arasına
static func _span(mi: Node3D, a: Vector3, b: Vector3, w: float) -> float:
	var dv = b - a
	var L = dv.length()
	if L < 0.02:
		mi.visible = false
		return L
	mi.visible = true
	var f = dv / L
	var bz = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT)
	mi.global_transform = Transform3D(Basis(bz.x * w, bz.y * w, bz.z * L), a)
	return L


# ------------------------------------------------------------------ izleyiciler (son bilinen konumu tutar)
static func _follow(n: Node3D, off: Vector3) -> Callable:
	var last = {"p": Vector3.ZERO}
	if n != null and is_instance_valid(n) and n.is_inside_tree():
		last["p"] = n.global_position + off
	var wr = weakref(n)
	return func() -> Vector3:
		var x = wr.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			last["p"] = x.global_position + off
		return last["p"]


## Düğümün yerel noktası (dönüş + ölçek dahil)
static func _local_pt(n: Node3D, lp: Vector3) -> Callable:
	var last = {"p": Vector3.ZERO}
	if n != null and is_instance_valid(n) and n.is_inside_tree():
		last["p"] = n.to_global(lp)
	var wr = weakref(n)
	return func() -> Vector3:
		var x = wr.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			last["p"] = x.to_global(lp)
		return last["p"]


## Parmak ucu: iskelette uç boğum kemiği varsa ondan, yoksa elden yelpaze biçiminde
static func _finger_fn(pj: PathJutsu, c: Node3D, right: bool, k: int) -> Callable:
	var last = {"p": pj.hand_pos(c, right)}
	var wc = weakref(c)
	var nm: String = ("Right" if right else "Left") + String(FINGER_BONES[k % 5])
	return func() -> Vector3:
		var x = wc.get_ref()
		if x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return last["p"]
		var got = false
		var m = x.get("model")
		if m != null and is_instance_valid(m) and m.get("skel") != null:
			var sk: Skeleton3D = m.skel
			var bi = sk.find_bone(nm)
			if bi >= 0:
				last["p"] = (sk.global_transform * sk.get_bone_global_pose(bi)).origin
				got = true
		if not got:
			var h: Vector3 = pj.hand_pos(x, right)
			var fd: Vector3 = x.face_dir() if x.has_method("face_dir") else -x.global_transform.basis.z
			var sd = fd.cross(Vector3.UP).normalized()
			last["p"] = h + fd * 0.1 + sd * ((k % 5 - 2) * 0.03 * (1.0 if right else -1.0)) + Vector3.UP * 0.02
		return last["p"]


# ================================================================== geometri
class G:
	extends RefCounted
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var uv := PackedVector2Array()
	var cl := PackedColorArray()
	var ix := PackedInt32Array()

	## Paralel taşınan çerçeveli tüp; UV.y = boy boyunca 0..1; flat < 1 yassı şerit; cols: halka başına renk
	func tube(pts: Array, radii: Array, sides: int, col: Color, flat := 1.0, cols: Array = []) -> void:
		var n = pts.size()
		if n < 2:
			return
		var lens = [0.0]
		for i in range(1, n):
			lens.append(lens[i - 1] + (pts[i] - pts[i - 1]).length())
		var total = maxf(lens[n - 1], 0.00001)
		var t0: Vector3 = (pts[1] - pts[0]).normalized()
		var nr: Vector3 = t0.cross(Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT).normalized()
		var base = v.size()
		for i in n:
			var tn: Vector3
			if i == 0:
				tn = pts[1] - pts[0]
			elif i == n - 1:
				tn = pts[i] - pts[i - 1]
			else:
				tn = pts[i + 1] - pts[i - 1]
			if tn.length() < 0.000001:
				tn = t0
			tn = tn.normalized()
			var nr2: Vector3 = nr - tn * nr.dot(tn)
			if nr2.length() < 0.01:
				nr2 = tn.cross(Vector3.UP if absf(tn.y) < 0.9 else Vector3.RIGHT)
			nr = nr2.normalized()
			var bn: Vector3 = tn.cross(nr)
			var r = float(radii[mini(i, radii.size() - 1)])
			var cc: Color = col
			if not cols.is_empty():
				cc = cols[mini(i, cols.size() - 1)]
			for s in sides + 1:
				var a = TAU * float(s) / sides
				var d: Vector3 = nr * cos(a) + bn * sin(a) * flat
				var dn: Vector3 = (nr * cos(a) + bn * sin(a) / maxf(flat, 0.05)).normalized()
				v.append(pts[i] + d * r)
				nm.append(dn)
				uv.append(Vector2(float(s) / sides, lens[i] / total))
				cl.append(cc)
		for i in n - 1:
			for s in sides:
				var a0 = base + i * (sides + 1) + s
				var b0 = a0 + sides + 1
				ix.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))

	## Elipsoit / topak (lump > 0: pürüzlü)
	func sphere(c: Vector3, sz: Vector3, col: Color, seg := 10, lump := 0.0, sd := 0.0) -> void:
		var rings = maxi(4, int(seg / 2.0))
		var base = v.size()
		for i in rings + 1:
			var th = PI * float(i) / rings
			for j in seg + 1:
				var ph = TAU * float(j) / seg
				var d = Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				var f = 1.0
				if lump > 0.0:
					f += lump * (sin(d.x * 4.1 + sd) * sin(d.y * 3.3 + sd * 1.7) + 0.6 * sin(d.z * 5.2 - sd * 0.9) * sin(d.x * 2.7 + sd))
				v.append(c + Vector3(d.x * sz.x, d.y * sz.y, d.z * sz.z) * 0.5 * f)
				nm.append(Vector3(d.x / maxf(sz.x, 0.001), d.y / maxf(sz.y, 0.001), d.z / maxf(sz.z, 0.001)).normalized())
				uv.append(Vector2(float(j) / seg, float(i) / rings))
				cl.append(col)
		for i in rings:
			for j in seg:
				var a0 = base + i * (seg + 1) + j
				var b0 = a0 + seg + 1
				ix.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))

	## Düz elips (u, w yarı eksenler); n = 4 → elmas
	func disc(c: Vector3, u: Vector3, w: Vector3, n: int, col: Color) -> void:
		var nn = u.cross(w).normalized()
		var base = v.size()
		v.append(c)
		nm.append(nn)
		uv.append(Vector2(0.5, 0.5))
		cl.append(col)
		for i in n + 1:
			var a = TAU * float(i) / n
			v.append(c + u * cos(a) + w * sin(a))
			nm.append(nn)
			uv.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
			cl.append(col)
		for i in n:
			ix.append_array(PackedInt32Array([base, base + 1 + i, base + 2 + i]))

	func box(c: Vector3, sz: Vector3, col: Color, b := Basis()) -> void:
		var h = sz * 0.5
		var ax = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		for k in 3:
			for sg in [-1.0, 1.0]:
				var nn: Vector3 = ax[k] * sg
				var u: Vector3 = ax[(k + 1) % 3]
				var w: Vector3 = ax[(k + 2) % 3]
				var fc: Vector3 = c + b * Vector3(nn.x * h.x, nn.y * h.y, nn.z * h.z)
				var uu: Vector3 = b * Vector3(u.x * h.x, u.y * h.y, u.z * h.z)
				var ww: Vector3 = b * Vector3(w.x * h.x, w.y * h.y, w.z * h.z)
				var base = v.size()
				for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					v.append(fc + uu * q.x + ww * q.y)
					nm.append((b * nn).normalized())
					uv.append(q * 0.5 + Vector2(0.5, 0.5))
					cl.append(col)
				ix.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

	## Parametrik yüzey: fn(u, w) -> [konum, renk]; normal sonlu farkla; radial: rc ekseninden dışa çevrilir
	func surf(nu: int, nw: int, fn: Callable, radial := true, rc := Vector3.ZERO) -> void:
		var base = v.size()
		var e = 0.002
		for j in nw + 1:
			for i in nu + 1:
				var u = float(i) / nu
				var w = float(j) / nw
				var r: Array = fn.call(u, w)
				var p: Vector3 = r[0]
				var pu: Vector3 = fn.call(minf(u + e, 1.0), w)[0] - fn.call(maxf(u - e, 0.0), w)[0]
				var pw: Vector3 = fn.call(u, minf(w + e, 1.0))[0] - fn.call(u, maxf(w - e, 0.0))[0]
				var n: Vector3 = pu.cross(pw)
				var rad = Vector3(p.x - rc.x, 0.0, p.z - rc.z)
				if n.length() < 0.0000001:
					n = rad if rad.length() > 0.0001 else Vector3.UP
				n = n.normalized()
				if radial and n.dot(rad) < 0.0:
					n = -n
				v.append(p)
				nm.append(n)
				uv.append(Vector2(u, w))
				cl.append(r[1])
		for j in nw:
			for i in nu:
				var a0 = base + j * (nu + 1) + i
				var b0 = a0 + nu + 1
				ix.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))

	func build() -> ArrayMesh:
		var m = ArrayMesh.new()
		if v.is_empty():
			return m
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nm
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = cl
		arr[Mesh.ARRAY_INDEX] = ix
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static func _done(key: String, g: G) -> ArrayMesh:
	var m = g.build()
	_cache[key] = m
	return m


static func _quad() -> QuadMesh:
	var k = "mesh:quad"
	if not _cache.has(k):
		var q = QuadMesh.new()
		q.size = Vector2.ONE
		_cache[k] = q
	return _cache[k]


static func _plane() -> PlaneMesh:
	var k = "mesh:plane"
	if not _cache.has(k):
		var q = PlaneMesh.new()
		q.size = Vector2(2.0, 2.0)
		_cache[k] = q
	return _cache[k]


static func _utube() -> ArrayMesh:
	var k = "mesh:utube"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	var pts = []
	var rr = []
	for i in 13:
		pts.append(Vector3(0, 0, -float(i) / 12.0))
		rr.append(1.0)
	g.tube(pts, rr, 4, Color.WHITE)
	return _done(k, g)


## Bal teli: uçlarda kalın, ortada incelen (yapışkan çekilme)
static func _strand_mesh() -> ArrayMesh:
	var k = "mesh:strand"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.tube([Vector3(0, 0, 0), Vector3(0, 0, -0.15), Vector3(0, 0, -0.5), Vector3(0, 0, -0.85), Vector3(0, 0, -1.0)], [1.0, 0.5, 0.32, 0.5, 1.0], 6, Color.WHITE)
	return _done(k, g)


static func _glob_mesh(vi: int) -> ArrayMesh:
	var k = "mesh:glob:%d" % vi
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.sphere(Vector3.ZERO, Vector3.ONE, Color.WHITE, 14, 0.16, vi * 2.3 + 0.7)
	return _done(k, g)


static func _pool_mesh() -> ArrayMesh:
	var k = "mesh:pool"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.sphere(Vector3.ZERO, Vector3(2.0, 0.14, 2.0), Color.WHITE, 26, 0.2, 1.9)
	return _done(k, g)


static func _blast_mesh() -> ArrayMesh:
	var k = "mesh:blast"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.sphere(Vector3.ZERO, Vector3.ONE, Color.WHITE, 18)
	return _done(k, g)


# ------------------------------------------------------------------ arı
## Cel arı (+ baş -Z, bel orijinde): kara baş, iri kızıl-kahve bileşik gözler, anten, çene; kahverengi tüylü göğüs ve
## sırtta turuncu leke; ince bel; keskin turuncu-siyah bantlı sivrilen karın + iğne; iki çift beyaz yarı saydam kanat
## (COLOR.a = 0.5 → gölgelendiricide çırpar); detail: daha yuvarlak + bacaklar. part: all / front / abd / head / wing
static func _bee_mesh(part := "all", detail := false) -> ArrayMesh:
	var key = "mesh:bee:%s:%d" % [part, int(detail)]
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var blk = Color(0.09, 0.07, 0.06)
	var org = Color(1.0, 0.6, 0.1)
	var brn = Color(0.34, 0.19, 0.07)
	var sg = 12 if detail else 8
	if part in ["all", "front", "head"]:
		g.sphere(Vector3(0, 0.03, -0.46), Vector3(0.24, 0.23, 0.2), blk, sg)
		for sx in [-1.0, 1.0]:
			g.sphere(Vector3(0.085 * sx, 0.06, -0.5), Vector3(0.09, 0.15, 0.1), Color(0.52, 0.16, 0.05), sg)
			g.tube([Vector3(0.04 * sx, 0.12, -0.54), Vector3(0.1 * sx, 0.24, -0.66), Vector3(0.17 * sx, 0.27, -0.73)], [0.014, 0.011, 0.008], 4, blk)
			g.tube([Vector3(0.045 * sx, -0.06, -0.55), Vector3(0.02 * sx, -0.12, -0.6)], [0.026, 0.006], 4, org.darkened(0.35))
	if part in ["all", "front"]:
		g.sphere(Vector3(0, 0.04, -0.2), Vector3(0.32, 0.3, 0.36), brn, sg, 0.06 if detail else 0.0, 1.3)
		g.sphere(Vector3(0, 0.14, -0.22), Vector3(0.18, 0.08, 0.2), org.darkened(0.12), sg)
		for sx in [-1.0, 1.0]:
			_wing(g, sx, true)
			_wing(g, sx, false)
			if detail:
				for k in 3:
					var z = -0.3 + k * 0.1
					g.tube([Vector3(0.1 * sx, -0.08, z), Vector3(0.24 * sx, -0.16, z + 0.04 * (k - 1)), Vector3(0.2 * sx, -0.36, z + 0.1 * (k - 0.5))], [0.024, 0.018, 0.008], 5, blk)
	if part in ["all", "abd"]:
		g.tube([Vector3(0, 0.0, -0.05), Vector3(0, -0.01, 0.05)], [0.055, 0.055], 6, blk)
		var nb = 5
		var pts = []
		var rads = []
		var cols = []
		for b in nb:
			var cb = org if b % 2 == 0 else blk
			for q in 3:
				var tt = (b + q * 0.5) / nb
				pts.append(Vector3(0, -0.02 - 0.1 * tt * tt, lerpf(0.03, 0.66, tt)))
				rads.append(0.2 * pow(sin(PI * clampf(0.12 + tt * 0.86, 0.0, 1.0)), 0.6))
				cols.append(cb)
		g.tube(pts, rads, 12 if detail else 8, org, 1.0, cols)
		g.tube([Vector3(0, -0.12, 0.65), Vector3(0, -0.16, 0.8)], [0.03, 0.003], 5, blk)
	if part == "wing":
		_wing(g, 1.0, true)
	return _done(key, g)


static func _wing(g: G, sx: float, front: bool) -> void:
	var wc = Color(0.94, 0.97, 1.0, 0.5)
	if front:
		g.disc(Vector3(0.3 * sx, 0.17, -0.1), Vector3(0.28 * sx, 0.03, 0.12), Vector3(-0.03 * sx, 0.0, 0.08), 12, wc)
	else:
		g.disc(Vector3(0.21 * sx, 0.155, 0.04), Vector3(0.19 * sx, 0.02, 0.13), Vector3(-0.02 * sx, 0.0, 0.055), 10, wc)


## Tek arı düğümü (kök ölçeksiz; ölçek mesh'te)
static func _bee_node(sc: float, detail := false) -> Node3D:
	var root = Node3D.new()
	var mi = _mi(_bee_mesh("all", detail), _toon(), {"flap": randf_range(55.0, 75.0), "ow": 0.035, "near_d": 1.2})
	mi.scale = Vector3.ONE * sc
	root.add_child(mi)
	return root


## Dev arı: ön gövde + bel ekleminde dönen karın (sokarken kıvrılır); kök ölçeksiz
static func _giant_bee(sc: float) -> Node3D:
	var root = Node3D.new()
	var body = Node3D.new()
	body.scale = Vector3.ONE * sc
	root.add_child(body)
	body.add_child(_mi(_bee_mesh("front", true), _toon(), {"flap": 38.0, "ow": 0.016, "near_d": 2.0}))
	var abd = Node3D.new()
	abd.add_child(_mi(_bee_mesh("abd", true), _toon(), {"ow": 0.016, "near_d": 2.0, "wet": 0.3}))
	body.add_child(abd)
	root.set_meta("abd", abd)
	return root


# ------------------------------------------------------------------ arı sürüsü (MultiMesh)
class Swarm:
	extends RefCounted
	var mmi: MultiMeshInstance3D
	var n := 0
	var p: Array = []
	var v: Array = []
	var ph: Array = []
	var centers: Array = []
	var slots: Array = []
	var rad := 1.0
	var sc := 0.17
	var speed := 10.0
	var pull := 9.0
	var t := 0.0

	func alive() -> bool:
		return mmi != null and is_instance_valid(mmi)

	func kick(i: int, dv: Vector3) -> void:
		if i < n:
			v[i] += dv

	## Her arı kendi eğik yörüngesinde merkeze çekilir (ya da sabit yuvasına); burnu hız yönüne döner
	func step(dt: float) -> void:
		if not alive():
			return
		t += dt
		var mm: MultiMesh = mmi.multimesh
		var mid := Vector3.ZERO
		for i in n:
			var a: float = ph[i]
			var goal: Vector3
			if not slots.is_empty():
				goal = slots[i % slots.size()]
				goal += Vector3(sin(t * 7.0 + a * 40.0), cos(t * 9.0 + a * 30.0), 0.0) * 0.06
			else:
				var cc: Vector3 = centers[i % centers.size()]
				var rr = rad * (0.35 + 0.65 * fposmod(a * 7.31, 1.0))
				goal = cc + Vector3(cos(t * (1.6 + a) + a * 37.0) * rr, sin(t * (2.3 + a * 0.7) + a * 51.0) * rr * 0.55, sin(t * (1.4 + a * 0.8) + a * 23.0) * rr)
			var acc: Vector3 = (goal - p[i]) * pull - v[i] * 2.2
			acc += Vector3(sin(t * 23.0 + a * 90.0), sin(t * 19.0 + a * 70.0), cos(t * 21.0 + a * 50.0)) * 6.0
			v[i] = (v[i] + acc * dt).limit_length(speed)
			p[i] += v[i] * dt
			mid += p[i]
		mid /= maxf(1.0, float(n))
		mmi.global_position = mid
		var R = rad + 5.0
		mmi.custom_aabb = AABB(Vector3(-R, -R, -R), Vector3(R, R, R) * 2.0)
		for i in n:
			var f: Vector3 = v[i]
			var bs := Basis()
			if f.length() > 0.05:
				var fn = f.normalized()
				bs = Basis.looking_at(fn, Vector3.UP if absf(fn.y) < 0.95 else Vector3.RIGHT)
			mm.set_instance_transform(i, Transform3D(bs.scaled(Vector3.ONE * sc), p[i] - mid))


static func _swarm(pj: PathJutsu, at: Vector3, n: int, sc: float, spread := 0.3, from: Array = []) -> Swarm:
	var s = Swarm.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _bee_mesh("all", false)
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _toon()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_setp(mmi, {"flap": 70.0, "ow": 0.045, "near_d": 1.3, "seed": randf() * 10.0})
	pj.get_tree().current_scene.add_child(mmi)
	mmi.global_position = at
	s.mmi = mmi
	s.n = n
	s.sc = sc
	s.centers = [at]
	for i in n:
		var o: Vector3 = at
		if not from.is_empty():
			o = from[i % from.size()]
		s.p.append(o + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread)
		s.v.append(Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)) * 3.0)
		s.ph.append(randf())
	s.step(0.0)
	return s


## Sürü dağılır: yukarı-ileri savrulup söner
static func _disperse(s: Swarm, dir: Vector3, dur := 0.7) -> void:
	if not s.alive():
		return
	var c0: Vector3 = s.mmi.global_position
	s.slots = []
	s.pull = 3.0
	s.speed = 14.0
	var tw = s.mmi.create_tween()
	tw.tween_method(func(k: float):
		if s.alive():
			s.centers = [c0 + dir * k * 6.0 + Vector3.UP * k * 3.0]
			s.rad = 1.0 + k * 3.0
			s.step(1.0 / 60.0)
			s.mmi.set_instance_shader_parameter("fade", 1.0 - k), 0.0, 1.0, dur)
	tw.tween_callback(s.mmi.queue_free)


## Sürüyü dur saniye 30 Hz sür: fn(k) merkezleri ayarlar; bitince (ya da atan ölünce) dağılır
static func _drive(pj: PathJutsu, s: Swarm, dur: float, fn: Callable, out_dir: Vector3) -> void:
	var upd = func(_i, k):
		if s.alive():
			if fn.is_valid():
				fn.call(k)
			s.step(1.0 / 30.0)
	var fin = func():
		_disperse(s, out_dir)
	pj.every(dur, 1.0 / 30.0, upd, fin)
	pj.free_after(dur + 3.0, s.mmi)


# ------------------------------------------------------------------ Kuroari (ref: bantlı yumurta gövde, ortada yuvalı dikiş,
## önü iki kapı gibi açılır; tepede yuvarlak baş, kara diken saç, kızıl küçük boynuzlar; sırtta yırtık koyu pelerin;
## yanlarda eklemli tahta kollar). +Z ön.
static func _kuro_r(y: float) -> float:
	return maxf(0.22, 0.84 * sqrt(maxf(0.0, 1.0 - pow((y - 1.22) / 1.1, 2.0))))


static func _kuro_rows(light: Color, seam: Color) -> Array:
	var rows = []
	var seams = [0.45, 0.7, 0.95, 1.2, 1.45, 1.7, 1.95]
	var y = 0.15
	var si = 0
	while y <= 2.31:
		if si < seams.size() and y >= float(seams[si]) - 0.03:
			var s: float = seams[si]
			rows.append([s - 0.013, light])
			rows.append([s - 0.013, seam])
			rows.append([s + 0.013, seam])
			rows.append([s + 0.013, light])
			si += 1
			y = s + 0.06
			continue
		rows.append([y, light])
		y += 0.07
	return rows


## rows: [[y, renk]...]; a: 0 = +Z ön
static func _lathe(g: G, rows: Array, a0: float, a1: float, nu: int, rmul: float, off: Vector3) -> void:
	var nw = rows.size() - 1
	var fn = func(u: float, w: float) -> Array:
		var fj = w * nw
		var j0 = clampi(int(floor(fj)), 0, nw)
		var j1 = mini(j0 + 1, nw)
		var f = fj - j0
		var yy = lerpf(float(rows[j0][0]), float(rows[j1][0]), f)
		var a = lerpf(a0, a1, u)
		var r = _kuro_r(yy) * rmul
		return [Vector3(sin(a) * r, yy, cos(a) * r) + off, rows[j0 if f < 0.5 else j1][1]]
	g.surf(nu, nw, fn, true, off)


static func _kuro_mesh(part: String) -> ArrayMesh:
	var key = "mesh:kuro:" + part
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var light = KURO_C
	var seam = Color(0.33, 0.24, 0.18)
	var slate = Color(0.32, 0.36, 0.42)
	var inner = Color(0.1, 0.08, 0.08)
	var rows = _kuro_rows(light, seam)
	var dark_rows = []
	for r in rows:
		dark_rows.append([r[0], inner])
	var seam_rows = []
	for r in rows:
		seam_rows.append([r[0], seam])
	match part:
		"back":
			_lathe(g, rows, PI * 0.5, PI * 1.5, 18, 1.0, Vector3.ZERO)
			_lathe(g, dark_rows, PI * 0.5, PI * 1.5, 12, 0.93, Vector3.ZERO)
			var hc = Vector3(0, 2.52, 0.04)
			g.sphere(hc, Vector3(0.44, 0.48, 0.42), light, 12)
			for sx in [-1.0, 1.0]:
				g.sphere(hc + Vector3(0.09 * sx, 0.05, 0.19), Vector3(0.07, 0.05, 0.03), Color(0.08, 0.06, 0.05), 6)
				g.tube([hc + Vector3(0.19 * sx, 0.1, 0.0), hc + Vector3(0.28 * sx, 0.2, 0.0), hc + Vector3(0.3 * sx, 0.3, -0.02)], [0.05, 0.035, 0.0], 5, Color(0.62, 0.12, 0.1))
			g.box(hc + Vector3(0, -0.11, 0.2), Vector3(0.16, 0.025, 0.02), Color(0.25, 0.1, 0.08))
			for k in 13:
				var a = PI * 0.2 + k * (PI * 1.6 / 12.0)
				var d = Vector3(sin(a) * 0.8, 0.55 + 0.25 * sin(k * 2.3), cos(a) * 0.8 - 0.2).normalized()
				g.tube([hc + d * 0.18, hc + d * 0.38 + Vector3(0, 0.04, 0)], [0.06, 0.0], 4, Color(0.13, 0.1, 0.1))
			g.tube([Vector3(0, 2.22, 0), Vector3(0, 2.34, 0)], [0.24, 0.2], 10, Color(0.2, 0.19, 0.2))
			var cloak = Color(0.22, 0.23, 0.27)
			var cfn = func(u: float, w: float) -> Array:
				var a = lerpf(PI * 0.5 - 0.35, PI * 1.5 + 0.35, u)
				var bot = 0.3 + 0.28 * absf(sin(u * 23.0)) * smoothstep(0.85, 1.0, w)
				var yy = lerpf(2.32, bot, w)
				var r = lerpf(0.5, 1.12, pow(w, 0.8)) * (1.0 + 0.05 * sin(a * 6.0 + w * 2.0))
				var cc = cloak.darkened(0.25) if sin(a * 6.0 + w * 2.0) < -0.6 else cloak
				return [Vector3(sin(a) * r, yy, cos(a) * r - 0.12), cc]
			g.surf(20, 8, cfn, true, Vector3(0, 0, -0.12))
			for sx in [-1.0, 1.0]:
				var sh = Vector3(0.8 * sx, 2.02, 0.05)
				var tip = Vector3(1.02 * sx, 0.45, 0.22)
				for k in 5:
					var a0 = sh.lerp(tip, k / 5.0)
					var a1 = sh.lerp(tip, (k + 1) / 5.0)
					g.tube([a0.lerp(a1, 0.06), a1.lerp(a0, 0.06)], [0.1, 0.09], 8, WOOD_C)
					g.sphere(a1, Vector3.ONE * 0.13, WOOD_D, 6)
		"door_r", "door_l":
			var rs = 1.0 if part == "door_r" else -1.0
			var off = Vector3(-0.84 * rs, 0, 0)
			var a0 = 0.0 if rs > 0.0 else -PI * 0.5
			var a1 = PI * 0.5 if rs > 0.0 else 0.0
			_lathe(g, rows, a0, a1, 10, 1.0, off)
			_lathe(g, dark_rows, a0, a1, 8, 0.93, off)
			var sa = 0.0 if rs > 0.0 else -0.013
			_lathe(g, seam_rows, sa, sa + 0.013, 1, 1.006, off)
			for y in [0.58, 0.83, 1.08, 1.33, 1.58, 1.83]:
				var sl = [[y - 0.035, slate], [y + 0.035, slate]]
				var b0 = 0.02 if rs > 0.0 else -0.14
				_lathe(g, sl, b0, b0 + 0.12, 2, 1.012, off)
	return _done(key, g)


## Kuroari düğümü: gövde + iki kapı (meta "dl"/"dr": y ekseninde döner; 0 kapalı, ~1.9 açık)
static func _kuro(open := 1.9) -> Node3D:
	var root = Node3D.new()
	var prm = {"ow": 0.014, "near_d": 1.6}
	root.add_child(_mi(_kuro_mesh("back"), _toon(), prm))
	var dr = Node3D.new()
	dr.position = Vector3(0.84, 0, 0)
	dr.add_child(_mi(_kuro_mesh("door_r"), _toon(), prm))
	dr.rotation.y = open
	root.add_child(dr)
	var dl = Node3D.new()
	dl.position = Vector3(-0.84, 0, 0)
	dl.add_child(_mi(_kuro_mesh("door_l"), _toon(), prm))
	dl.rotation.y = -open
	root.add_child(dl)
	root.set_meta("dr", dr)
	root.set_meta("dl", dl)
	return root


static func _doors(kuro: Node3D, ang: float, dur: float, delay := 0.0, trans := Tween.TRANS_EXPO) -> void:
	if kuro == null or not is_instance_valid(kuro):
		return
	var dr: Node3D = kuro.get_meta("dr")
	var dl: Node3D = kuro.get_meta("dl")
	var tw = kuro.create_tween().set_parallel(true)
	tw.tween_property(dr, "rotation:y", ang, dur).set_trans(trans).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(dl, "rotation:y", -ang, dur).set_trans(trans).set_ease(Tween.EASE_OUT).set_delay(delay)


# ------------------------------------------------------------------ kukla silahları ve parçaları
## Karasu'nun eklemli tahta kolu (ref: dört boğum, eklem topları, uçta sivri bıçak); -Z boyunca, uç -2.85
static func _karasu_arm_mesh() -> ArrayMesh:
	var k = "mesh:karm"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	var jt = Color(0.45, 0.36, 0.3)
	g.sphere(Vector3.ZERO, Vector3.ONE * 0.16, jt, 8)
	for s in 4:
		var z0 = -0.05 - s * 0.48
		var z1 = z0 - 0.44
		g.tube([Vector3(0, 0, z0), Vector3(0, 0, z1)], [0.075, 0.064], 8, WOOD_C)
		g.tube([Vector3(0, 0, (z0 + z1) * 0.5 + 0.02), Vector3(0, 0, (z0 + z1) * 0.5 - 0.02)], [0.082, 0.082], 8, WOOD_D)
		g.sphere(Vector3(0, 0, z1 - 0.02), Vector3.ONE * 0.12, jt, 8)
	g.sphere(Vector3(0, 0, -2.02), Vector3(0.14, 0.1, 0.16), WOOD_C, 8)
	g.tube([Vector3(0, 0, -2.08), Vector3(0, 0, -2.5), Vector3(0, 0, -2.85)], [0.06, 0.045, 0.0], 6, STEEL_C, 0.2)
	g.tube([Vector3(0, 0, -2.06), Vector3(0, 0, -2.1)], [0.09, 0.09], 6, Color(0.15, 0.12, 0.12))
	return _done(k, g)


## Düz kukla bıçağı (-Z boyunca 1 m): çelik, ortada mor zehir oluğu
static func _blade_mesh() -> ArrayMesh:
	var k = "mesh:nblade"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.tube([Vector3(0, 0, 0.05), Vector3(0, 0, -0.7), Vector3(0, 0, -1.0)], [0.07, 0.06, 0.0], 6, STEEL_C, 0.18)
	g.tube([Vector3(0, 0, -0.05), Vector3(0, 0, -0.65)], [0.02, 0.016], 4, Color(0.45, 0.25, 0.52), 1.0)
	return _done(k, g)


## Tırpan halkası: göbekten çıkan sap ve 1 m yarıçaplı kavisli bıçak (yatay)
static func _sickle_mesh() -> ArrayMesh:
	var k = "mesh:sickle"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.tube([Vector3(0, 0, 0), Vector3(1.0, 0, 0)], [0.05, 0.04], 6, WOOD_D)
	var pts = []
	var rr = []
	for i in 10:
		var a = i * 0.2
		pts.append(Vector3(cos(a) * 1.0, 0, -sin(a) * 1.0))
		rr.append(lerpf(0.1, 0.0, i / 9.0))
	g.tube(pts, rr, 6, STEEL_C, 0.16)
	return _done(k, g)


## Kabukta yırtık (+Z'ye bakan düzlem): tırtıklı koyu yarık, solgun kıymık kenar
static func _tear_mesh() -> ArrayMesh:
	var k = "mesh:tear"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	var base = g.v.size()
	g.v.append(Vector3.ZERO)
	g.nm.append(Vector3.BACK)
	g.uv.append(Vector2(0.5, 0.5))
	g.cl.append(Color(0.06, 0.05, 0.05))
	for i in 15:
		var a = TAU * i / 14.0
		var r = (0.2 if i % 2 == 0 else 0.07) * (0.8 + 0.4 * fposmod(i * 0.618, 1.0))
		g.v.append(Vector3(cos(a) * r * 1.4, sin(a) * r, 0.0))
		g.nm.append(Vector3.BACK)
		g.uv.append(Vector2(0.5, 0.5))
		g.cl.append(Color(0.06, 0.05, 0.05))
	for i in 14:
		g.ix.append_array(PackedInt32Array([base, base + 1 + i, base + 2 + i]))
	for i in 5:
		var a = TAU * i / 5.0 + 0.3
		g.tube([Vector3(cos(a) * 0.12, sin(a) * 0.08, 0.0), Vector3(cos(a) * 0.3, sin(a) * 0.2, 0.06)], [0.025, 0.0], 3, KURO_C.lightened(0.25))
	return _done(k, g)


## Patlayıcı etiket (ref: krem kâğıt, mor-kızıl çerçeve, kara mürekkep işaretleri); pivot üstte, aşağı sarkar
static func _tag_mesh() -> ArrayMesh:
	var k = "mesh:tag"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	var paper = Color(0.95, 0.92, 0.82)
	var frame = Color(0.62, 0.12, 0.3)
	var ink = Color(0.08, 0.06, 0.06)
	g.tube([Vector3(0, 0, 0), Vector3(0, -0.04, 0)], [0.006, 0.006], 3, ink)
	g.disc(Vector3(0, -0.17, 0), Vector3(0.068, 0, 0), Vector3(0, 0.135, 0), 4, frame)
	g.box(Vector3(0, -0.17, 0), Vector3(0.11, 0.24, 0.006), frame)
	for sz in [-1.0, 1.0]:
		g.box(Vector3(0, -0.17, 0.004 * sz), Vector3(0.09, 0.22, 0.002), paper)
		for q in 4:
			var b = Basis(Vector3.BACK, 0.5 * sin(q * 2.1 + sz))
			g.box(Vector3(0.012 * (q % 2 * 2 - 1), -0.1 - q * 0.045, 0.006 * sz), Vector3(0.05, 0.012, 0.002), ink, b)
	return _done(k, g)


## Demir bomba (ref: gri yuvarlak): koyu demir küre, bant, fitil
static func _bomb_mesh() -> ArrayMesh:
	var k = "mesh:bomb"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.sphere(Vector3.ZERO, Vector3.ONE * 0.32, Color(0.33, 0.32, 0.35), 12)
	var pts = []
	for i in 13:
		var a = TAU * i / 12.0
		pts.append(Vector3(cos(a) * 0.162, 0.0, sin(a) * 0.162))
	g.tube(pts, [0.018], 4, Color(0.2, 0.19, 0.22))
	g.tube([Vector3(0, 0.15, 0), Vector3(0.03, 0.24, 0), Vector3(0.07, 0.28, 0)], [0.02, 0.018, 0.016], 4, Color(0.72, 0.58, 0.36))
	return _done(k, g)


## Arı iğnesi mermisi (-Z uç): kara-kehribar iğne, uçta sarı-yeşil zehir damlası, arkada ince açık hız izi
static func _needle_mesh(trail: bool) -> ArrayMesh:
	var k = "mesh:needle:%d" % int(trail)
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	var blk = Color(0.1, 0.08, 0.06)
	g.tube([Vector3(0, 0, 0.3), Vector3(0, 0, 0.1), Vector3(0, 0, -0.1), Vector3(0, 0, -0.38)], [0.035, 0.032, 0.026, 0.0], 6, blk, 1.0, [blk, Color(1.0, 0.6, 0.1), blk, blk])
	g.sphere(Vector3(0, 0, -0.36), Vector3.ONE * 0.045, Color(0.82, 0.92, 0.3), 6)
	if trail:
		g.tube([Vector3(0, 0, 0.32), Vector3(0, 0, 1.5)], [0.014, 0.0], 4, Color(1.0, 0.95, 0.75))
	return _done(k, g)


## Zehirli sivri (Karasu ağzından; +Z boyunca 1 m): çelik gövde, mor uç
static func _spike_mesh() -> ArrayMesh:
	var k = "mesh:spike"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.tube([Vector3(0, 0, 0.0), Vector3(0, 0, 0.7), Vector3(0, 0, 1.0)], [0.045, 0.035, 0.0], 6, STEEL_C, 1.0, [STEEL_C, Color(0.5, 0.3, 0.56), Color(0.4, 0.15, 0.5)])
	return _done(k, g)


## Kikō Junbū tahta kolu (+Y boyunca L): omuz topu, boğumlu kalın kol, açık el (avuç +Z), dört parmak, başparmak
static func _kiko_arm_mesh(L: float) -> ArrayMesh:
	var key = "mesh:kiko:%d" % int(L * 100.0)
	if _cache.has(key):
		return _cache[key]
	var g = G.new()
	var wood = Color(0.86, 0.82, 0.74)
	var dk = Color(0.6, 0.55, 0.48)
	g.sphere(Vector3.ZERO, Vector3.ONE * 0.36, dk, 10)
	var nseg = 3 if L > 2.5 else 2
	var sl = (L - 0.5) / nseg
	for k in nseg:
		var y0 = 0.08 + k * sl
		var y1 = y0 + sl - 0.06
		g.tube([Vector3(0, y0, 0), Vector3(0, y1, 0)], [0.17 - k * 0.012, 0.155 - k * 0.012], 10, wood)
		g.tube([Vector3(0, (y0 + y1) * 0.5 - 0.03, 0), Vector3(0, (y0 + y1) * 0.5 + 0.03, 0)], [0.18 - k * 0.012, 0.18 - k * 0.012], 10, dk)
		g.sphere(Vector3(0, y1 + 0.03, 0), Vector3.ONE * 0.26, dk, 8)
	var py = L - 0.22
	g.sphere(Vector3(0, py, 0), Vector3(0.42, 0.4, 0.15), wood, 10)
	for f in 4:
		var x = -0.13 + f * 0.087
		var top = 0.32 + 0.04 * (1.5 - absf(f - 1.5))
		g.tube([Vector3(x, py + 0.16, 0.0), Vector3(x * 1.05, py + 0.16 + top * 0.55, 0.02), Vector3(x * 1.12, py + 0.16 + top, 0.0)], [0.04, 0.035, 0.026], 6, wood)
		g.sphere(Vector3(x * 1.05, py + 0.16 + top * 0.55, 0.02), Vector3.ONE * 0.065, dk, 6)
	g.tube([Vector3(0.19, py - 0.06, 0.02), Vector3(0.3, py + 0.06, 0.05), Vector3(0.36, py + 0.19, 0.06)], [0.045, 0.04, 0.03], 6, wood)
	return _done(key, g)


## Gizli bıçak (+Z boyunca): kısa geniş çelik
static func _kblade_mesh() -> ArrayMesh:
	var k = "mesh:kblade"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	g.tube([Vector3(0, 0, 0), Vector3(0, 0, 0.55), Vector3(0, 0, 0.82)], [0.06, 0.05, 0.0], 6, STEEL_C, 0.15)
	return _done(k, g)


## Chikamatsu kuklası cüppesi (ref: yüksek yakalı geniş beyaz cüppe, kıvrımlar; alında elmas mühür). Kukla -Z'ye bakar.
static func _robe_mesh() -> ArrayMesh:
	var k = "mesh:robe"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	var wh = Color(0.95, 0.95, 0.93)
	var sh = Color(0.76, 0.77, 0.82)
	var rfn = func(u: float, w: float) -> Array:
		var a = u * TAU
		var r = lerpf(0.28, 0.78, pow(w, 0.7))
		var fold = sin(a * 7.0 + w * 2.0)
		r *= 1.0 + 0.07 * fold * w
		var yy = lerpf(1.6, 0.1, w) + 0.04 * sin(a * 13.0) * smoothstep(0.92, 1.0, w)
		return [Vector3(sin(a) * r, yy, cos(a) * r * 0.86 + 0.05), sh if fold < -0.55 else wh]
	g.surf(28, 10, rfn, true, Vector3(0, 0, 0.05))
	var cfn = func(u: float, w: float) -> Array:
		var a = lerpf(PI + 0.45, PI * 3.0 - 0.45, u)
		var r = lerpf(0.25, 0.37, w)
		return [Vector3(sin(a) * r, lerpf(1.48, 1.92, w), cos(a) * r * 0.9 + 0.02), wh if w < 0.9 else sh]
	g.surf(16, 3, cfn, true, Vector3(0, 0, 0.02))
	g.disc(Vector3(0, 1.84, -0.262), Vector3(0, 0.06, 0), Vector3(0.05, 0, 0), 4, Color(0.06, 0.06, 0.07))
	g.disc(Vector3(0, 1.84, -0.268), Vector3(0, 0.035, 0), Vector3(0.028, 0, 0), 4, wh)
	g.disc(Vector3(0, 1.84, -0.272), Vector3(0, 0.014, 0), Vector3(0.012, 0, 0), 4, Color(0.06, 0.06, 0.07))
	return _done(k, g)


## Chikamatsu parşömeni (ref: beyaz bant, kara elmas desenler, ince kara kenarlar): r = 1.45 halka
static func _scroll_mesh() -> ArrayMesh:
	var k = "mesh:scroll"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	var paper = Color(0.95, 0.94, 0.9)
	var ink = Color(0.06, 0.06, 0.07)
	var fn = func(u: float, w: float) -> Array:
		var a = u * TAU
		var r = 1.45 + 0.03 * sin(a * 3.0)
		return [Vector3(sin(a) * r, lerpf(-0.16, 0.16, w), cos(a) * r), ink if (w < 0.05 or w > 0.95) else paper]
	g.surf(64, 12, fn, true)
	for i in 14:
		var a = TAU * (i + 0.5) / 14.0
		var r = 1.45 + 0.03 * sin(a * 3.0)
		var rd = Vector3(sin(a), 0, cos(a))
		var tg = Vector3(cos(a), 0, -sin(a))
		g.disc(rd * (r + 0.008), Vector3(0, 0.11, 0), tg * 0.09, 4, ink)
		g.disc(rd * (r + 0.013), Vector3(0, 0.07, 0), tg * 0.055, 4, paper)
		g.disc(rd * (r + 0.017), Vector3(0, 0.028, 0), tg * 0.022, 4, ink)
	return _done(k, g)


## Kukla sargı bezi: kukla çevresinde sarmal şerit
static func _bandage_mesh() -> ArrayMesh:
	var k = "mesh:bandage"
	if _cache.has(k):
		return _cache[k]
	var g = G.new()
	var cloth = Color(0.93, 0.9, 0.8)
	var fn = func(u: float, w: float) -> Array:
		var th = u * 5.0 * TAU
		var R = 0.62 - 0.12 * sin(u * PI)
		var yy = lerpf(0.1, 1.95, u) + (w - 0.5) * 0.14
		return [Vector3(cos(th) * R, yy, sin(th) * R), cloth.darkened(0.12) if fposmod(u * 37.0, 1.0) < 0.1 else cloth]
	g.surf(90, 1, fn, true)
	return _done(k, g)


# ================================================================== parçacık / ışık / iz
static func _curve(nm: String) -> CurveTexture:
	var k = "crv:" + nm
	if _cache.has(k):
		return _cache[k]
	var cv = Curve.new()
	match nm:
		"grow":
			cv.add_point(Vector2(0.0, 0.35))
			cv.add_point(Vector2(1.0, 1.0))
		"flat":
			cv.add_point(Vector2(0.0, 0.85))
			cv.add_point(Vector2(1.0, 1.0))
		_:
			cv.add_point(Vector2(0.0, 0.0))
			cv.add_point(Vector2(0.12, 1.0))
			cv.add_point(Vector2(0.7, 0.75))
			cv.add_point(Vector2(1.0, 0.0))
	var ct = CurveTexture.new()
	ct.curve = cv
	_cache[k] = ct
	return ct


static func _ramp(cols: Array) -> GradientTexture1D:
	var gr = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[i])
	gr.offsets = offs
	gr.colors = cs
	var t = GradientTexture1D.new()
	t.gradient = gr
	return t


## o: kind, n, life, dir, spread, vmin, vmax, g, damp, smin, smax, r | box | ring, cols, one_shot, burst, near, curve
static func _parts(o: Dictionary) -> GPUParticles3D:
	var p = GPUParticles3D.new()
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 180.0))
	pm.initial_velocity_min = float(o.get("vmin", 1.0))
	pm.initial_velocity_max = float(o.get("vmax", 3.0))
	pm.gravity = o.get("g", Vector3(0, -3.0, 0))
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0))
	pm.scale_min = float(o.get("smin", 0.1))
	pm.scale_max = float(o.get("smax", 0.25))
	pm.scale_curve = _curve(str(o.get("curve", "pop")))
	if o.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = o["box"]
	elif o.has("ring"):
		var rr = float(o["ring"])
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = rr
		pm.emission_ring_inner_radius = rr * 0.8
		pm.emission_ring_height = 0.05
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(o.get("r", 0.2))
	pm.color_ramp = _ramp(o.get("cols", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	p.process_material = pm
	p.draw_pass_1 = _quad()
	p.material_override = _plain("part", PART_SHADER)
	p.amount = maxi(1, int(o.get("n", 12)))
	p.lifetime = float(o.get("life", 0.8))
	p.one_shot = bool(o.get("one_shot", true))
	p.explosiveness = float(o.get("burst", 0.92 if p.one_shot else 0.0))
	p.randomness = 0.4
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-14, -14, -14), Vector3(28, 28, 28))
	p.set_instance_shader_parameter("kind", float(o.get("kind", 0.0)))
	p.set_instance_shader_parameter("near_d", float(o.get("near", 1.5)))
	return p


static func _emit(pj: PathJutsu, o: Dictionary, pos: Vector3) -> GPUParticles3D:
	var p = _parts(o)
	pj.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	if p.one_shot:
		pj.free_after(p.lifetime + 0.6, p)
	return p


## Sürekli yayıcıyı sec sonra durdur, ömrü bitince sil (atandan bağımsız)
static func _stop_after(pj: PathJutsu, p: GPUParticles3D, sec: float) -> void:
	var w = weakref(p)
	pj.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.emitting = false)
	pj.free_after(sec + p.lifetime + 0.5, p)


static func _flash(pj: PathJutsu, pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	pj.scene_add(l, pos)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


static func _decal(pj: PathJutsu, pos: Vector3, r: float, kind: float, draw := 1.0) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _plane()
	mi.material_override = _plain("decal", DECAL_SHADER)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(mi, pj.gp(pos) + Vector3.UP * (0.03 + randf() * 0.02))
	mi.scale = Vector3(r, 1.0, r)
	mi.rotation.y = randf() * TAU
	_setp(mi, {"kind": kind, "seed": randf() * 10.0, "draw": draw, "fade": 1.0})
	return mi


## Yonga / kıymık (kind 2)
static func _chips(pj: PathJutsu, at: Vector3, n: int, col: Color, v := 6.0) -> void:
	_emit(pj, {"kind": 2.0, "n": n, "life": 0.7, "vmin": v * 0.4, "vmax": v, "g": Vector3(0, -14.0, 0), "smin": 0.06, "smax": 0.14, "r": 0.2,
		"curve": "flat", "cols": [Color(col.r, col.g, col.b, 1.0), Color(col.r, col.g, col.b, 1.0), Color(col.r, col.g, col.b, 0.0)]}, at)


static func _blood(pj: PathJutsu, at: Vector3, n: int) -> void:
	_emit(pj, {"kind": 0.0, "n": n, "life": 0.55, "vmin": 1.5, "vmax": 4.5, "g": Vector3(0, -14.0, 0), "smin": 0.05, "smax": 0.1, "r": 0.15,
		"curve": "flat", "cols": [Color(0.78, 0.06, 0.06, 1.0), Color(0.55, 0.02, 0.03, 1.0), Color(0.45, 0.0, 0.02, 0.0)]}, at)


static func _drips(pj: PathJutsu, at: Vector3, n: int, spread := 0.3) -> void:
	_emit(pj, {"kind": 0.0, "n": n, "life": 0.9, "dir": Vector3.DOWN, "spread": 25.0, "vmin": 0.3, "vmax": 1.6, "g": Vector3(0, -9.0, 0), "smin": 0.05, "smax": 0.1,
		"r": spread, "burst": 0.4, "curve": "flat", "cols": [Color(1.0, 0.74, 0.16, 1.0), Color(0.95, 0.55, 0.06, 1.0), Color(0.9, 0.5, 0.05, 0.0)]}, at)


## Toz halkası (kind 5, halka yayımı)
static func _dust_ring(pj: PathJutsu, at: Vector3, r: float, col := Color(0.62, 0.52, 0.4)) -> void:
	_emit(pj, {"kind": 5.0, "n": 18, "life": 0.9, "dir": Vector3.UP, "spread": 70.0, "vmin": 1.0, "vmax": 3.5, "g": Vector3(0, -1.5, 0), "damp": 2.0,
		"smin": 0.5 * r, "smax": 0.9 * r, "ring": r, "near": 2.5, "cols": [Color(col.r, col.g, col.b, 0.85), Color(col.r, col.g, col.b, 0.6), Color(col.r, col.g, col.b, 0.0)]}, pj.gp(at) + Vector3.UP * 0.2)


# ================================================================== yapı taşları — chakra iplikleri
## İki hareketli nokta arası chakra ipliği: parmaktan dışa uzar, sarkar, ışık boncukları akar; bitince parmağa geri çekilir.
## o: sag, thick, tint, alive (Callable -> bool: görünür mü), until (Callable -> bool: bitsin mi)
static func _thread(pj: PathJutsu, a_fn: Callable, b_fn: Callable, dur: float, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _utube()
	mi.material_override = _plain("thread", THREAD_SHADER)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	_setp(mi, {"seed": randf() * 10.0, "thick": float(o.get("thick", 0.011)), "reveal": 0.0, "tint": o.get("tint", THREAD_C)})
	pj.get_tree().current_scene.add_child(mi)
	var sag = float(o.get("sag", 0.25))
	var alive: Callable = o.get("alive", Callable())
	var until: Callable = o.get("until", Callable())
	var st = {"t": 0.0, "done": false}
	var upd = func(_i, _k):
		if not is_instance_valid(mi) or st["done"]:
			return
		if until.is_valid() and bool(until.call()):
			st["done"] = true
			_retract(mi)
			return
		st["t"] += 1.0 / 30.0
		var L = _span(mi, a_fn.call(), b_fn.call(), 0.002)
		mi.set_instance_shader_parameter("sag", sag * clampf(L / 6.0, 0.1, 1.2))
		mi.set_instance_shader_parameter("reveal", clampf(st["t"] / 0.14, 0.0, 1.01))
		if alive.is_valid() and not bool(alive.call()):
			mi.visible = false
	upd.call(0, 0.0)
	var fin = func():
		if is_instance_valid(mi) and not st["done"]:
			st["done"] = true
			_retract(mi)
	pj.every(dur, 1.0 / 30.0, upd, fin)
	pj.free_after(dur + 1.0, mi)
	return mi


static func _retract(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi):
		return
	var tw = mi.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("reveal", v), 1.0, 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


## Kukla (ClanConstruct) yönetilemiyorsa (ip koptu, menzil aşıldı, kuklacı sersem / bağlı / mühürlü) iplikler görünmez
static func _pup_lost(u) -> bool:
	if u == null or not is_instance_valid(u) or u.dead:
		return true
	var o = u.owner_f
	if o == null or not is_instance_valid(o):
		return true
	if u.limp_t > 0.0 or o.global_position.distance_to(u.global_position) > 30.0:
		return true
	if o.has_method("has_status") and (o.has_status("stun") or o.has_status("bind") or o.has_status("sealed")):
		return true
	return false


## Kuklanın kendi tek-renk ışık çubuklarını kaldır (yerini parmak uçlarından gelen bu iplikler alır)
static func _own_threads(u) -> void:
	if u == null or not is_instance_valid(u) or u.get("threads") == null:
		return
	for th in u.threads:
		if is_instance_valid(th):
			th.queue_free()
	u.threads.clear()


static func _vis_pt(u, lp: Vector3) -> Callable:
	var last = {"p": Vector3.ZERO}
	var wr = weakref(u)
	if u != null and is_instance_valid(u) and u.is_inside_tree():
		last["p"] = u.global_position + Vector3.UP * lp.y
	return func() -> Vector3:
		var x = wr.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			var vis = x.get("vis")
			if vis != null and is_instance_valid(vis):
				last["p"] = vis.to_global(lp)
			else:
				last["p"] = x.global_position + Vector3.UP * lp.y
		return last["p"]


## Parmak uçlarından ClanConstruct kuklasına iplikler: kukla yaşadıkça sürer, yönetilemezken görünmez
static func _pup_threads(pj: PathJutsu, c: Node3D, u, fingers: Array, pts: Array) -> void:
	var life = clampf(float(u.life) + 0.5, 1.0, 45.0)
	var alive_fn = func() -> bool:
		return not _pup_lost(u)
	var until_fn = func() -> bool:
		return u == null or not is_instance_valid(u) or u.dead
	for j in fingers.size():
		var fg: Array = fingers[j]
		_thread(pj, _finger_fn(pj, c, bool(fg[0]), int(fg[1])), _vis_pt(u, pts[j % pts.size()]), life, {"sag": 0.3, "alive": alive_fn, "until": until_fn})


## Sahnede asılı kukla (oyunun gerçek kukla modeli): önce iplikler uzanır, kukla ipliklerle çekilip açılır; dur sonra geri sarılır
static func _hang(pj: PathJutsu, c: Node3D, at: Vector3, d: Vector3, dur: float, s := 1.0, dark := false) -> Node3D:
	var pup: Node3D = pj._puppet_mesh(s, dark)
	pj.scene_add(pup, at)
	pup.rotation.y = atan2(d.x, d.z)
	pup.scale = Vector3.ONE * 0.15
	var tw = pup.create_tween()
	tw.tween_property(pup, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chips(pj, at + Vector3.UP * s, 8, WOOD_C, 4.0)
	for k in 3:
		var right = k != 1
		var lp = [Vector3(0, 1.85 * s, 0.1 * s), Vector3(-0.32 * s, 1.45 * s, 0.1 * s), Vector3(0.32 * s, 1.45 * s, 0.1 * s)][k]
		_thread(pj, _finger_fn(pj, c, right, 1 + k), _local_pt(pup, lp), dur, {"sag": 0.15})
	var pw = weakref(pup)
	pj.after(dur, func():
		var p = pw.get_ref()
		if p != null:
			_chips(pj, p.global_position + Vector3.UP * s, 6, WOOD_C, 3.0)
			_shrink(p, 0.0, 0.22))
	pj.free_after(dur + 1.0, pup)
	return pup


# ================================================================== yapı taşları — bal
static func _glob(size: float, o := {}) -> MeshInstance3D:
	var d := {"wob": 0.07, "ow": 0.04, "near_d": 0.9}
	d.merge(o, true)
	var mi = _mi(_glob_mesh(randi() % 3), _honey(), d)
	mi.scale = Vector3.ONE * size
	return mi


## Yere yayılan yapışkan bal gölü: hızla yayılır, harden saniyede petekli muma sertleşir, dur sonunda çöküp söner
static func _pool(pj: PathJutsu, pos: Vector3, r: float, dur: float, harden: float) -> MeshInstance3D:
	var mi = _mi(_pool_mesh(), _honey(), {"wob": 0.025, "ow": 0.01, "near_d": 0.8, "wax": 0.0})
	pj.scene_add(mi, pj.gp(pos) + Vector3.UP * 0.02)
	mi.scale = Vector3(r * 0.15, 1.0, r * 0.15)
	mi.rotation.y = randf() * TAU
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r, 1.0, r), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tp(mi, "wax", 0.0, 0.92, harden, 0.4)
	_vanish(mi, maxf(0.1, dur - 0.45), 0.45)
	pj.free_after(dur + 0.6, mi)
	return mi


## Bal sıçraması: damlalar + uçuşan küçük bal topakları
static func _splat(pj: PathJutsu, at: Vector3, s: float) -> void:
	_emit(pj, {"kind": 0.0, "n": int(14 * s), "life": 0.7, "vmin": 2.0 * s, "vmax": 5.0 * s, "g": Vector3(0, -12.0, 0), "smin": 0.06, "smax": 0.13, "r": 0.2,
		"curve": "flat", "cols": [Color(1.0, 0.78, 0.2, 1.0), Color(0.95, 0.55, 0.06, 1.0), Color(0.9, 0.5, 0.05, 0.0)]}, at + Vector3.UP * 0.3)
	for k in int(3 * s):
		var g = _glob(0.16 * s)
		pj.scene_add(g, at + Vector3.UP * 0.3)
		var dv = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.8, 1.8) * s
		var tw = g.create_tween()
		tw.tween_property(g, "global_position", at + dv + Vector3.UP * 0.6, 0.14).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "global_position", pj.gp(at + dv * 1.3), 0.18).set_ease(Tween.EASE_IN)
		tw.tween_property(g, "scale", Vector3(0.28, 0.05, 0.28) * s, 0.08)
		_vanish(g, 1.4, 0.4)


## Hedefin kemiğine yapışan, sertleşen bal topağı
static func _stick(pj: PathJutsu, x: Node3D, bone: String, size: float, dur: float) -> void:
	if x == null or not is_instance_valid(x):
		return
	var bs = ClanJutsu.body_scale(x)
	var ba = pj.bone_attach(x, bone)
	var g = _glob(size * bs)
	g.scale = Vector3(1.0, 0.75, 1.0) * size * bs
	if ba != null:
		ba.add_child(g)
		pj.free_after(dur + 0.5, ba)
	else:
		x.add_child(g)
		g.position = Vector3.UP * 0.9 * bs
	_tp(g, "wax", 0.0, 0.85, dur * 0.7, 0.2)
	_vanish(g, maxf(0.1, dur - 0.3), 0.3)


## Yerdeki noktalardan hedefin gövdesine gerilen yapışkan bal telleri
static func _strands(pj: PathJutsu, _from: Vector3, x: Node3D, n: int, dur: float) -> void:
	if x == null or not is_instance_valid(x):
		return
	var bs = ClanJutsu.body_scale(x)
	for k in n:
		var a = TAU * k / n + randf() * 0.6
		var g0: Vector3 = pj.gp(x.global_position + Vector3(cos(a), 0, sin(a)) * 0.7 * bs) + Vector3.UP * 0.05
		var b_fn = _follow(x, Vector3(cos(a) * 0.15, (0.35 + k * 0.3) * bs, sin(a) * 0.15))
		var mi = _mi(_strand_mesh(), _honey(), {"wob": 0.0, "ow": 0.0, "near_d": 0.8})
		mi.extra_cull_margin = 2.0
		pj.get_tree().current_scene.add_child(mi)
		var w = 0.045 * bs
		var upd = func(_i, kk):
			if is_instance_valid(mi):
				_span(mi, g0, b_fn.call(), w * (1.0 - kk * 0.4))
				mi.set_instance_shader_parameter("wax", kk * 0.8)
		upd.call(0, 0.0)
		pj.every(dur, 1.0 / 30.0, upd, func():
			if is_instance_valid(mi):
				_vanish(mi, 0.0, 0.25))
		pj.free_after(dur + 0.8, mi)


# ================================================================== yapı taşları — patlamalar / zemin
## Demir bomba patlaması (ref: sarı-beyaz iri top): üç kaynayan ateş topu, gri şarapnel, kıvılcım, toz halkası, is izi
static func _bomb_blast(pj: PathJutsu, pp: Vector3, s: float) -> void:
	for q in 3:
		var b = _mi(_blast_mesh(), _plain("blast", BLAST_SHADER), {"hue": 0.0, "burn": 0.0})
		var off = Vector3.ZERO if q == 0 else Vector3(randf_range(-0.6, 0.6), randf_range(0.1, 0.6), randf_range(-0.6, 0.6)) * s
		pj.scene_add(b, pp + off + Vector3.UP * 0.3 * s)
		var r = (1.6 if q == 0 else 0.95) * s
		b.scale = Vector3.ONE * r * 0.2
		var tw = b.create_tween()
		if q > 0:
			tw.tween_interval(0.04 * q)
		tw.tween_property(b, "scale", Vector3.ONE * r, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float):
			if is_instance_valid(b):
				b.set_instance_shader_parameter("burn", v), 0.0, 1.0, 0.34)
		tw.parallel().tween_property(b, "position:y", b.position.y + 0.6 * s, 0.34)
		tw.tween_callback(b.queue_free)
	_emit(pj, {"kind": 2.0, "n": 14, "life": 0.6, "vmin": 6.0 * s, "vmax": 12.0 * s, "g": Vector3(0, -16.0, 0), "smin": 0.08, "smax": 0.16, "r": 0.2,
		"curve": "flat", "cols": [Color(0.42, 0.4, 0.44, 1.0), Color(0.3, 0.29, 0.32, 1.0), Color(0.3, 0.29, 0.32, 0.0)]}, pp + Vector3.UP * 0.3)
	_emit(pj, {"kind": 3.0, "n": 10, "life": 0.35, "vmin": 4.0, "vmax": 9.0, "g": Vector3(0, -6.0, 0), "smin": 0.12, "smax": 0.25, "r": 0.3,
		"cols": [Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.6, 0.15, 0.0)]}, pp + Vector3.UP * 0.4)
	_dust_ring(pj, pp, 1.2 * s, Color(0.5, 0.45, 0.4))
	var sc = _decal(pj, pp, 1.7 * s, 1.0, 1.0)
	_tp(sc, "draw", 1.0, 0.0, 1.4)
	_vanish(sc, 2.0, 0.8)
	pj.free_after(3.2, sc)
	_flash(pj, pp + Vector3.UP * 0.8, Color(1.0, 0.8, 0.4), 5.0, 7.0 * s, 0.22)


## Patlayıcı etiket patlaması: kâğıt parlar, kızıl alev dilleri yükselir, yanık kâğıt parçaları süzülür, korlar uçar
static func _tag_blast(pj: PathJutsu, pp: Vector3, s: float) -> void:
	_emit(pj, {"kind": 3.0, "n": 1, "life": 0.14, "vmin": 0.0, "vmax": 0.0, "g": Vector3.ZERO, "smin": 1.8 * s, "smax": 1.8 * s, "r": 0.0, "curve": "flat",
		"cols": [Color(1.0, 0.95, 0.85, 1.0), Color(1.0, 0.5, 0.3, 0.0)]}, pp)
	for q in 3:
		var b = _mi(_blast_mesh(), _plain("blast", BLAST_SHADER), {"hue": 1.0, "burn": 0.0})
		var a = TAU * q / 3.0 + randf()
		pj.scene_add(b, pp + Vector3(cos(a), 0, sin(a)) * 0.25 * s)
		var fs = Vector3(0.5, 1.35, 0.5) * s * (1.0 if q == 0 else 0.75)
		b.scale = fs * 0.15
		var tw = b.create_tween()
		tw.tween_property(b, "scale", fs, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "position:y", b.position.y + 0.7 * s, 0.32)
		tw.tween_method(func(v: float):
			if is_instance_valid(b):
				b.set_instance_shader_parameter("burn", v), 0.0, 1.0, 0.24)
		tw.tween_callback(b.queue_free)
	_emit(pj, {"kind": 6.0, "n": 12, "life": 1.5, "vmin": 1.5, "vmax": 4.0, "g": Vector3(0, -1.2, 0), "damp": 2.0, "smin": 0.08, "smax": 0.16, "r": 0.3, "curve": "flat",
		"cols": [Color(0.95, 0.9, 0.78, 1.0), Color(0.5, 0.36, 0.25, 1.0), Color(0.15, 0.12, 0.1, 0.0)]}, pp)
	_emit(pj, {"kind": 7.0, "n": 14, "life": 0.9, "dir": Vector3.UP, "spread": 60.0, "vmin": 2.0, "vmax": 5.0, "g": Vector3(0, 1.0, 0), "damp": 1.0, "smin": 0.05, "smax": 0.1, "r": 0.4,
		"cols": [Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.4, 0.1, 0.0)]}, pp)
	if pp.y - pj.gp(pp).y < 1.2:
		var sc = _decal(pj, pp, 1.2 * s, 1.0, 1.0)
		_tp(sc, "draw", 1.0, 0.0, 0.9)
		_vanish(sc, 1.4, 0.6)
		pj.free_after(2.4, sc)
	_flash(pj, pp, Color(1.0, 0.55, 0.3), 3.5, 5.0 * s, 0.18)


## Çatlak + kaya parçaları + toz (dev arının bıraktığı hedefin çakılması)
static func _slam(pj: PathJutsu, at: Vector3) -> void:
	var ck = _decal(pj, at, 4.5, 0.0)
	_vanish(ck, 2.6, 0.6)
	pj.free_after(3.6, ck)
	_emit(pj, {"kind": 2.0, "n": 14, "life": 0.9, "dir": Vector3.UP, "spread": 55.0, "vmin": 5.0, "vmax": 10.0, "g": Vector3(0, -20.0, 0), "smin": 0.14, "smax": 0.3, "r": 0.6,
		"curve": "flat", "cols": [Color(0.55, 0.42, 0.3, 1.0), Color(0.42, 0.32, 0.22, 1.0), Color(0.42, 0.32, 0.22, 0.0)]}, pj.gp(at) + Vector3.UP * 0.2)
	_dust_ring(pj, at, 1.8)


# ================================================================== KAMİZURU
## Arı Sürüsü (ref: Kamizuru — kollardan dökülen gerçek arılar): iki elden fışkıran 70 arılık sürü hedefin peşinde
## dolanır, sokarken sıkışıp hedefin üstüne çöker (iğne parıltısı + zehir damlaları), 5 sn sonra savrulup dağılır
static func kamizuru_bees(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	var d: Vector3 = pj.fwd(c, t)
	var start: Vector3 = c.global_position + Vector3.UP * 1.5
	var pos = {"p": start, "sting": 0.0, "v": start}
	var sw = _swarm(pj, start, 70, 0.17, 0.15, [pj.hand_pos(c, true), pj.hand_pos(c, false)])
	sw.rad = 0.5
	sw.speed = 12.0
	for i in sw.n:
		sw.v[i] = (d + Vector3(randf_range(-0.8, 0.8), randf_range(-0.2, 0.9), randf_range(-0.8, 0.8))).normalized() * randf_range(4.0, 9.0)
	for right in [true, false]:
		_emit(pj, {"kind": 3.0, "n": 6, "life": 0.3, "vmin": 1.0, "vmax": 3.0, "g": Vector3.ZERO, "smin": 0.06, "smax": 0.12, "r": 0.1,
			"cols": [Color(1, 0.85, 0.35, 1), Color(1, 0.7, 0.2, 0)]}, pj.hand_pos(c, right))
	var tick = func(i, _k):
		var goal = tt.global_position + Vector3.UP * 1.2 if pj.live(tt) else pos["p"]
		pos["p"] = pos["p"].lerp(goal, 0.12)
		if i % 5 == 0:
			for e in pj.enemies_near(c, pos["p"], 2.2):
				pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "kamizuru_bees", 0.14, {"knock": 0.0, "burn": 2.0}))
				pj.st(e, "slow", 1.0)
				pos["sting"] = 0.35
				if is_instance_valid(e):
					_stings(pj, e.global_position + Vector3.UP * 1.2)
	pj.every(5.0, 0.1, tick)
	var steer = func(_k):
		pos["v"] = pos["v"].lerp(pos["p"], 0.25)
		pos["sting"] = maxf(0.0, pos["sting"] - 1.0 / 30.0)
		sw.centers = [pos["v"]]
		sw.rad = lerpf(1.25, 0.5, clampf(pos["sting"] / 0.35, 0.0, 1.0))
	_drive(pj, sw, 5.0, steer, d)
	Sfx.play("wind", c.global_position, 2.6, 0.5)


static func _stings(pj: PathJutsu, at: Vector3) -> void:
	_emit(pj, {"kind": 3.0, "n": 5, "life": 0.25, "vmin": 0.5, "vmax": 2.0, "g": Vector3.ZERO, "smin": 0.1, "smax": 0.18, "r": 0.45,
		"cols": [Color(1, 1, 0.85, 1), Color(1, 0.8, 0.3, 0)]}, at)
	_emit(pj, {"kind": 0.0, "n": 6, "life": 0.6, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -8, 0), "smin": 0.04, "smax": 0.07, "r": 0.4, "curve": "flat",
		"cols": [Color(0.85, 0.9, 0.3, 1), Color(0.7, 0.75, 0.2, 0)]}, at)


## Bal Mumu: ağızda kabaran bal topağından üç kuyruklu bal topu tükürülür; değdiği hedef yere bal telleriyle yapışır,
## gövdesinde sertleşen topak kalır; yerde hızla yayılan, beş saniyede petekli muma sertleşen göl
static func kamizuru_wax(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 25.0)
	var mouth: Vector3 = Jutsu._mouth(c)
	var mg = _glob(0.05)
	pj.scene_add(mg, mouth)
	var mt = mg.create_tween()
	mt.tween_property(mg, "scale", Vector3.ONE * 0.32, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mt.tween_property(mg, "scale", Vector3.ONE * 0.02, 0.22)
	mt.tween_callback(mg.queue_free)
	_drips(pj, mouth - Vector3.UP * 0.1, 6, 0.1)
	for k in 3:
		var d = Jutsu._aim(c, t).rotated(Vector3.UP, (k - 1) * 0.12)
		var on_hit = func(pos, target):
			if pj.live(target):
				pj.st(target, "bind", 3.0)
				_stick(pj, target, "Hips", 0.42, 3.0)
				_strands(pj, pos, target, 3, 3.0)
			_splat(pj, pj.gp(pos), 1.0)
			_pool(pj, pos, 2.4, 5.0, 3.5)
			pj.every(5.0, 0.3, func(_i, _k):
				for e in pj.enemies_near(c, pos, 2.4):
					pj.st(e, "slow", 0.5))
		var pr = pj.shot(c, Jutsu._mouth(c), d, 22.0, _wax_shot(), pj.inf(c, "kamizuru_wax", 0.3, {"knock": 0.0}), tt, false, 1.6, on_hit)
		pr.gravity = 6.0
	Sfx.play("water", c.global_position, 0.7)


## Bal topu mermisi: kıpır kıpır topak + arkada uzayan damla kuyruğu + yol boyunca düşen damlalar
static func _wax_shot() -> Node3D:
	var root = Node3D.new()
	var g = _glob(0.38, {"wob": 0.1})
	root.add_child(g)
	var tail = _glob(1.0, {"wob": 0.05, "ow": 0.02})
	tail.scale = Vector3(0.2, 0.2, 0.55)
	tail.position = Vector3(0, 0, 0.3)
	root.add_child(tail)
	var p = _parts({"kind": 0.0, "n": 10, "life": 0.6, "one_shot": false, "dir": Vector3.DOWN, "spread": 20.0, "vmin": 0.2, "vmax": 0.8, "g": Vector3(0, -9.0, 0),
		"smin": 0.05, "smax": 0.09, "r": 0.1, "curve": "flat", "cols": [Color(1.0, 0.75, 0.18, 1.0), Color(0.9, 0.5, 0.05, 0.0)]})
	root.add_child(p)
	p.emitting = true
	return root


## Hachi Bakudan no Jutsu (ref: Jibachi — karnına iple patlayıcı etiket bağlı arılar): sürü kollardan dökülür, etiketli
## on arı sallanan kâğıtlarıyla hedeflere uçar, etiketin mürekkebi kızarır; çarpınca kâğıt alev dili + yanık kâğıt patlaması
static func hachi_bakudan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "hachi_bakudan_no_jutsu"
	var tt = pj.tg(c, t, 28.0)
	var d = pj._face(c, tt)
	pj.anim(c, "cast", 1.4)
	var cw = weakref(c)
	var list = pj.enemies_near(c, c.global_position, 28.0)
	var origin: Vector3 = c.global_position + Vector3.UP * 2.0
	var sw = _swarm(pj, origin, 26, 0.16, 0.2, [pj.hand_pos(c, true), pj.hand_pos(c, false)])
	sw.rad = 0.9
	_drive(pj, sw, 1.0, Callable(), d)
	Sfx.play("wind", origin, 2.4, 0.5)
	for k in 10:
		pj.after(0.12 + k * 0.06, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var target = tt if (k % 2 == 0 or list.is_empty()) else list[k % list.size()]
			var dk = (pj.aim_at(cc, target, origin) + Vector3(randf_range(-0.5, 0.5), randf_range(0.15, 0.6), randf_range(-0.5, 0.5))).normalized()
			var bee = _tag_bee(0.42)
			var hitf = func(pp, _h):
				_tag_blast(pj, pp, 1.0)
				Sfx.play("boom", pp, 1.4, 0.55)
				var c2 = cw.get_ref()
				if c2 != null and pj.live(c2):
					pj.hit(c2, pp, 2.3, pj.inf(c2, id, 0.52, {"knock": 5.0, "launch": 1.0, "kind": "heavy", "element": "katon", "burn": 2.0}))
			var pr = pj.shot(cc, origin, dk, 24.0, bee, pj.inf(cc, id, 0.08, {"knock": 0.0, "kind": "light"}), target if pj.live(target) else null, false, 2.2, hitf)
			pr.radius = 0.4)


## Etiketli arı: karnının altından ipe bağlı sallanan patlayıcı etiket; etiket mürekkebi uçuşta kızarır
static func _tag_bee(sc: float) -> Node3D:
	var root = _bee_node(sc, true)
	var piv = Node3D.new()
	piv.position = Vector3(0, -0.12, 0.2) * sc
	root.add_child(piv)
	var tag = _mi(_tag_mesh(), _toon(), {"ow": 0.004, "near_d": 1.0})
	tag.scale = Vector3.ONE * sc * 2.1
	piv.add_child(tag)
	var sw = Game.safe_loops(piv.create_tween())
	sw.tween_property(piv, "rotation:x", 0.5, 0.16).set_trans(Tween.TRANS_SINE)
	sw.tween_property(piv, "rotation:x", -0.15, 0.16).set_trans(Tween.TRANS_SINE)
	_tp(tag, "pulse", 0.0, 0.55, 0.6)
	return root


## Hachimitsu no Jutsu (ref: Kurobachi — sokan arı ezilip parçalanır, karnından bal saçılır): dokuz arı hedefin çevresinde
## döner; her sokuşta bir arı başı / kanadı / karnı savrularak parçalanır, gövdeye kıpır kıpır bal topağı yapışır;
## beşinci balda topaklar sertleşir, ayak altında bal gölü
static func hachimitsu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Hachimitsu no Jutsu: sürünün saracağı hedef yok", HONEY_C)
		return
	pj.busy(c, 0.8)
	var id = "hachimitsu_no_jutsu"
	pj._face(c, tt)
	pj.anim(c, "cast", 1.4)
	var cw = weakref(c)
	var tw = weakref(tt)
	var bees = []
	var from: Vector3 = c.global_position + Vector3.UP * 1.8
	for k in 9:
		var bee = _bee_node(0.36, true)
		pj.scene_add(bee, from)
		bees.append(bee)
	Sfx.play("wind", from, 2.6, 0.5)
	var s = {"honey": 0, "p": from}
	var blobs = []
	var globs = []
	var fin = func():
		for b in bees:
			if is_instance_valid(b):
				_vanish(b, 0.0, 0.25)
	var tick = func(i, _k):
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			for b in bees:
				if is_instance_valid(b):
					b.visible = false
			return
		var bs = ClanJutsu.body_scale(x)
		s["p"] = s["p"].lerp(x.global_position + Vector3.UP * 1.1 * bs, 0.2)
		for q in bees.size():
			var b = bees[q]
			if not is_instance_valid(b):
				continue
			var a = i * 0.32 + q * TAU / bees.size()
			var r = (0.9 + 0.3 * sin(i * 0.2 + q)) * bs
			var np: Vector3 = s["p"] + Vector3(cos(a) * r, sin(i * 0.25 + q * 1.7) * 0.6 * bs, sin(a) * r)
			var dv: Vector3 = np - b.global_position
			if dv.length() > 0.02:
				b.global_basis = Basis.looking_at(dv.normalized(), Vector3.UP if absf(dv.normalized().y) < 0.95 else Vector3.RIGHT)
			b.global_position = np
		if i % 8 == 7 and s["p"].distance_to(x.global_position + Vector3.UP * 1.1 * bs) < 1.5 * bs:
			x.take_hit(pj.inf(cc, id, 0.17, {"knock": 0.0, "kind": "light", "poison": 1.5, "hitstop": 0.0}))
			s["honey"] += 1
			var bone = ["Chest", "Hips", "LeftUpperArm", "RightUpperLeg", "RightUpperArm", "LeftUpperLeg", "UpperChest"][s["honey"] % 7]
			var ba = pj.bone_attach(x, bone)
			if ba != null:
				var g = _glob(0.34 * bs)
				g.scale = Vector3(1.0, 0.7, 1.0) * 0.34 * bs
				ba.add_child(g)
				blobs.append(ba)
				globs.append(g)
			if is_instance_valid(x):
				_crush(pj, x.global_position + Vector3.UP * 1.0 * bs, bs)
				_drips(pj, x.global_position + Vector3.UP * 1.0 * bs, 6, 0.4)
			if s["honey"] == 2:
				pj.st(x, "slow", 6.0)
			elif s["honey"] == 5:
				pj.st(x, "bind", 3.0)
				Combat.popup_text(x.global_position + Vector3.UP * 2.8, "Bala saplandı!", HONEY_C)
				Sfx.play("water", x.global_position, 0.6)
				for g in globs:
					if is_instance_valid(g):
						_tp(g, "wax", 0.0, 0.75, 0.8)
				if is_instance_valid(x):
					_pool(pj, x.global_position, 1.1 * bs, 3.0, 1.2)
	pj.every(6.0, 0.05, tick, func():
		fin.call()
		for ba in blobs:
			if is_instance_valid(ba):
				_vanish(ba, 0.0, 0.3))


## Ezilen arı: baş, karın, kanat ayrı ayrı dönerek savrulup düşer
static func _crush(pj: PathJutsu, at: Vector3, bs: float) -> void:
	var parts = ["head", "abd", "wing", "wing"]
	for k in parts.size():
		var mi = _mi(_bee_mesh(parts[k], true), _toon(), {"ow": 0.03, "near_d": 1.0})
		mi.scale = Vector3.ONE * 0.36 * bs
		pj.scene_add(mi, at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3)) * bs)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dv = Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized() * 0.7 * bs
		var tw = mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "global_position", mi.global_position + dv, 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", pj.gp(at + dv * 1.5) + Vector3.UP * 0.05, 0.4).set_ease(Tween.EASE_IN).set_delay(0.18)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(randf_range(4, 9), randf_range(4, 9), 0), 0.58)
		_vanish(mi, 0.9, 0.35)
	_emit(pj, {"kind": 0.0, "n": 8, "life": 0.6, "vmin": 1.5, "vmax": 3.5, "g": Vector3(0, -10.0, 0), "smin": 0.06, "smax": 0.11, "r": 0.15,
		"curve": "flat", "cols": [Color(1.0, 0.78, 0.2, 1.0), Color(0.95, 0.55, 0.06, 0.0)]}, at)


## Ōbachi Rakka: dev arı (kanat çırpan, eklemli karnı) tepeden dalar, karnını kıvırıp hedefi sokar ve kavrar, kanat
## rüzgârı yerde toz çevirir, ardında küçük arılar uçar; bırakınca hedef çatlak + kaya + toz ile çakılır, arı göğe uzaklaşıp söner
static func obachi_rakka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Ōbachi Rakka: arının kapacağı hedef yok", HONEY_C)
		return
	pj.busy(c, 0.9)
	var id = "obachi_rakka"
	var d = pj._face(c, tt)
	pj.anim(c, "cast", 1.4)
	var cw = weakref(c)
	var tw = weakref(tt)
	var bs = ClanJutsu.body_scale(tt)
	var bee = _giant_bee(1.7 * maxf(1.0, bs * 0.8))
	var start: Vector3 = tt.global_position - d * 7.0 + Vector3.UP * 9.0
	pj.scene_add(bee, start)
	var fd: Vector3 = (tt.global_position - start).normalized()
	bee.global_basis = Basis.looking_at(fd, Vector3.UP)
	var bw = weakref(bee)
	var abd: Node3D = bee.get_meta("abd")
	var body: Node3D = bee.get_child(0)
	var bsc: Vector3 = body.scale
	body.scale = bsc * 0.3
	var bt = body.create_tween()
	bt.tween_property(body, "scale", bsc, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sw = _swarm(pj, start, 16, 0.15, 0.6)
	sw.rad = 1.2
	_drive(pj, sw, 2.6, func(_k):
		var b = bw.get_ref()
		if b != null:
			sw.centers = [b.global_position - b.global_basis.z * -1.6 + Vector3.UP * 0.4], -d)
	Sfx.play("wind", start, 2.2, 0.7)
	var s = {"grab": false, "t": 0.0}
	var fly = func(i, _k):
		var b = bw.get_ref()
		var x = tw.get_ref()
		var cc = cw.get_ref()
		if b == null or cc == null:
			return
		var tm = i * 0.03
		if x == null or not pj.live(x):
			b.global_position += Vector3.UP * 0.5
			return
		var grip: Vector3 = Vector3.UP * (1.9 * bs + 0.5)
		if tm < 0.4:
			b.global_position = start.lerp(x.global_position + grip, tm / 0.4)
		elif tm < 1.25:
			if not s["grab"]:
				s["grab"] = true
				pj.st(x, "bind", 1.6)
				x.take_hit(pj.inf(cc, id, 0.5, {"knock": 0.0, "kind": "light", "poison": 3.0, "hitstop": 0.04}))
				Combat.popup_text(x.global_position + Vector3.UP * 3.0, "Dev arı kaptı!", HONEY_C)
				if is_instance_valid(abd):
					var at = abd.create_tween()
					at.tween_property(abd, "rotation:x", 0.95, 0.1).set_trans(Tween.TRANS_BACK)
					at.tween_interval(0.5)
					at.tween_property(abd, "rotation:x", 0.35, 0.25)
				_stings(pj, x.global_position + Vector3.UP * 1.6 * bs)
			var np: Vector3 = b.global_position + (Vector3.UP * 9.0 + d * 2.0) * 0.03
			b.global_basis = Basis.looking_at(d, Vector3.UP)
			b.global_position = np
			x.global_position = np - grip
			if x is CharacterBody3D:
				x.velocity = Vector3.ZERO
		else:
			b.global_position += (Vector3.UP * 6.0 - d * 8.0) * 0.03
			if s["grab"]:
				s["grab"] = false
				s["t"] = 1.0
				if is_instance_valid(abd):
					abd.create_tween().tween_property(abd, "rotation:x", 0.0, 0.2)
			if s["t"] > 0.0:
				var gy: float = pj.gp(x.global_position).y
				var ny: float = maxf(gy, x.global_position.y - 34.0 * 0.03)
				x.global_position.y = ny
				if x is CharacterBody3D:
					x.velocity = Vector3.ZERO
				if ny <= gy + 0.02:
					s["t"] = 0.0
					var at: Vector3 = pj.gp(x.global_position)
					_slam(pj, at)
					pj.shake(0.7)
					Sfx.play("boom", at, 0.8)
					pj.hit(cc, at + Vector3.UP * 0.5, 3.0, pj.inf(cc, id, 2.4, {"knock": 6.0, "kind": "heavy", "stun": 1.2, "hitstop": 0.1}))
		if tm >= 0.4 and i % 3 == 0:
			_downwash(pj, b.global_position)
	pj.every(2.6, 0.03, fly, func():
		var b = bw.get_ref()
		if b != null:
			var et = b.create_tween()
			et.tween_property(b, "global_position", b.global_position + Vector3.UP * 3.0 - d * 2.0, 0.4)
			_vanish(b, 0.0, 0.4))
	pj.free_after(4.0, bee)


## Kanat rüzgârı: altındaki zeminde dönen toz, arıdan dökülen ince pullar
static func _downwash(pj: PathJutsu, bp: Vector3) -> void:
	var gy = pj.gp(bp)
	if bp.y - gy.y < 7.0:
		_emit(pj, {"kind": 5.0, "n": 5, "life": 0.7, "dir": Vector3.UP, "spread": 80.0, "vmin": 1.0, "vmax": 2.5, "g": Vector3(0, -1.0, 0), "damp": 2.0,
			"smin": 0.5, "smax": 0.9, "ring": 1.4, "near": 2.5, "cols": [Color(0.66, 0.58, 0.46, 0.7), Color(0.66, 0.58, 0.46, 0.0)]}, gy + Vector3.UP * 0.15)
	_emit(pj, {"kind": 7.0, "n": 3, "life": 0.6, "dir": Vector3.DOWN, "spread": 50.0, "vmin": 1.0, "vmax": 2.5, "g": Vector3(0, -3.0, 0), "smin": 0.04, "smax": 0.08, "r": 0.6,
		"cols": [Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.7, 0.2, 0.0)]}, bp)


## Arı Çağırma: yere merkezden dışa çizilen bal sarısı petek mührü; sürü mühürden sarmal yükselip üç dev arının
## gövdesine toplanır (ClanConstruct dev arıları)
static func kamizuru_hachi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var fd: Vector3 = c.face_dir()
	var at: Vector3 = pj.gp(c.global_position + fd * 2.0)
	var seal = _decal(pj, at, 2.4, 2.0, 0.0)
	_tp(seal, "draw", 0.0, 1.05, 0.45)
	_vanish(seal, 1.1, 0.6)
	pj.free_after(2.0, seal)
	var list = ClanConstruct.spawn(c, "bee", 3, Jutsu._jd("kamizuru_hachi"))
	Sfx.play("wind", c.global_position, 2.0, 0.6)
	var goals = []
	for u in (list if list is Array else []):
		goals.append(weakref(u))
	var sw = _swarm(pj, at + Vector3.UP * 0.2, 54, 0.15, 0.6)
	sw.rad = 1.6
	sw.speed = 14.0
	var steer = func(k):
		if k < 0.35:
			sw.centers = [at + Vector3.UP * (0.3 + k * 6.0)]
			sw.rad = 1.6 - k
		else:
			var cs = []
			for w in goals:
				var u = w.get_ref()
				if u != null and is_instance_valid(u):
					cs.append(u.global_position + Vector3.UP * 0.5)
			if cs.is_empty():
				cs = [at + Vector3.UP * 2.5]
			sw.centers = cs
			sw.rad = maxf(0.15, 1.2 - (k - 0.35) * 1.6)
			sw.pull = 16.0
	var upd = func(_i, k):
		if sw.alive():
			steer.call(k)
			sw.step(1.0 / 30.0)
	pj.every(1.1, 1.0 / 30.0, upd, func():
		if sw.alive():
			var ft = sw.mmi.create_tween()
			ft.tween_method(func(v: float):
				if sw.alive():
					sw.mmi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.15)
			ft.tween_callback(sw.mmi.queue_free))
	pj.free_after(2.5, sw.mmi)


## Arı İğnesi Yağmuru: on iki arı başın üstünde yay biçiminde dizilir; her biri iğnesini fırlatırken geri teper; kara-kehribar
## iğneler hız iziyle kıvrılarak hedeflere gider, saplanır (zehir damlası), ıskalayan yere saplanıp kalır
static func kamizuru_hari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var list = pj.enemies_near(c, c.global_position, 28.0)
	var origin: Vector3 = c.global_position + Vector3.UP * 2.2
	var ad: Vector3 = Jutsu._aim(c, t)
	var fl = Vector3(ad.x, 0.0, ad.z)
	fl = fl.normalized() if fl.length() > 0.01 else c.face_dir()
	var sd = fl.cross(Vector3.UP).normalized()
	var sw = _swarm(pj, origin, 12, 0.24, 0.6)
	var slots = []
	for k in 12:
		var a = (k - 5.5) / 5.5
		slots.append(origin + sd * a * 1.6 - fl * 0.4 + Vector3.UP * (0.35 - a * a * 0.45))
	sw.slots = slots
	sw.pull = 30.0
	sw.speed = 18.0
	_drive(pj, sw, 1.3, Callable(), fl)
	for k in 12:
		var target = list[k % list.size()] if not list.is_empty() else null
		var dk = (Jutsu._aim(c, t) + Vector3(randf_range(-0.6, 0.6), randf_range(0.1, 0.6), randf_range(-0.6, 0.6))).normalized()
		pj.after(k * 0.04, func():
			if sw.alive():
				sw.kick(k, -dk * 7.0)
			var nd = Node3D.new()
			nd.add_child(_mi(_needle_mesh(true), _toon(), {"ow": 0.01, "near_d": 1.0}))
			pj.shot(c, origin, dk, 30.0, nd, pj.inf(c, "kamizuru_hari", 0.12, {"knock": 0.5, "kind": "light", "burn": 2.5}), target, false, 1.6, func(hp, tgt):
				pj.st(tgt, "slow", 2.0)
				_needle_stick(pj, hp, tgt, dk)))
	Sfx.play("throw_kunai", c.global_position, 1.6)


static func _needle_stick(pj: PathJutsu, hp: Vector3, tgt, dk: Vector3) -> void:
	var mi = _mi(_needle_mesh(false), _toon(), {"ow": 0.01, "near_d": 1.0})
	if tgt != null and is_instance_valid(tgt) and tgt is Node3D:
		tgt.add_child(mi)
		mi.global_position = hp
		mi.global_basis = Basis.looking_at(dk, Vector3.UP if absf(dk.y) < 0.95 else Vector3.RIGHT)
		_emit(pj, {"kind": 0.0, "n": 4, "life": 0.5, "vmin": 0.5, "vmax": 1.5, "g": Vector3(0, -8, 0), "smin": 0.04, "smax": 0.07, "r": 0.1, "curve": "flat",
			"cols": [Color(0.85, 0.92, 0.3, 1), Color(0.7, 0.75, 0.2, 0)]}, hp)
		_vanish(mi, 1.4, 0.3)
	else:
		pj.scene_add(mi, hp)
		mi.global_basis = Basis.looking_at(dk, Vector3.UP if absf(dk.y) < 0.95 else Vector3.RIGHT)
		_vanish(mi, 1.0, 0.3)
	pj.free_after(2.2, mi)


## Bal Klonu (ref: Kamizuru — baldan kopya): elden yere bal dökülür, kopya ayak altındaki bal gölünden bal yükselerek
## belirir, gövdesinde parlak bal zarı ve süzülen bal damarları; sürekli damlar. Vurulunca erir: büyük bal sıçraması,
## 5 m bal gölü petekli muma sertleşir, çevredekiler ayaklarından bal telleriyle yere yapışır
static func kamizuru_mitsu_bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var at: Vector3 = c.global_position + c.global_transform.basis.x * 2.5
	_pour(pj, pj.hand_pos(c, true), pj.gp(at))
	var on_pop = func(p: Vector3):
		_melt(pj, p)
		for e in pj.enemies_near(c, p, 5.0):
			pj.st(e, "bind", 3.0)
			if is_instance_valid(e):
				_stick(pj, e, "LeftFoot", 0.3, 3.0)
				_strands(pj, p, e, 2, 3.0)
	var dec = pj.decoy(c, at, 12.0, on_pop)
	_veil(pj, dec, pj.gp(at).y)
	var puddle = _pool(pj, at, 0.75, 12.0, 6.0)
	var dw = weakref(dec)
	var pw = weakref(puddle)
	pj.every(12.0, 0.6, func(_i, _k):
		var x = dw.get_ref()
		if x == null or not is_instance_valid(x):
			var pd = pw.get_ref()
			if pd != null and is_instance_valid(pd):
				pd.queue_free()
			return
		_drips(pj, x.global_position + Vector3.UP * randf_range(0.6, 1.4), 3, 0.3))


## Elden yere kavisli bal akıntısı (uzayıp incelerek kopar)
static func _pour(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var mi = _mi(_strand_mesh(), _honey(), {"wob": 0.04, "ow": 0.02, "near_d": 0.8})
	mi.extra_cull_margin = 2.0
	pj.get_tree().current_scene.add_child(mi)
	var upd = func(_i, k):
		if is_instance_valid(mi):
			var e = a.lerp(b, clampf(k * 3.0, 0.05, 1.0))
			_span(mi, a, e, 0.06 * (1.0 - k * 0.8))
	var fin = func():
		if is_instance_valid(mi):
			mi.queue_free()
	pj.every(0.5, 1.0 / 30.0, upd, fin)
	pj.free_after(1.2, mi)
	_drips(pj, b + Vector3.UP * 0.2, 8, 0.3)


## Kopyanın tüm görünür geometrisine bal örtüsü: tabandan bal yükselir, sonra parlak zar kalır
static func _veil(pj: PathJutsu, dec: Node3D, base_y: float) -> void:
	if dec == null or not is_instance_valid(dec):
		return
	var mat = _plain("veil", VEIL_SHADER)
	var apply = func():
		if not is_instance_valid(dec):
			return
		for g in _gis(dec):
			if g is MeshInstance3D and g.material_overlay == null:
				g.material_overlay = mat
				_setp(g, {"cover": 1.0, "rise": 0.0, "base_y": base_y})
				var tw = g.create_tween()
				tw.tween_method(func(v: float):
					if is_instance_valid(g):
						g.set_instance_shader_parameter("rise", v), 0.0, 2.3, 0.55)
				tw.tween_method(func(v: float):
					if is_instance_valid(g):
						g.set_instance_shader_parameter("cover", v), 1.0, 0.45, 0.6)
	apply.call()
	pj.get_tree().create_timer(0.1).timeout.connect(apply)


## Bal kopyası erir: büyük sıçrama, 5 m bal gölü (3 sn, petekli muma sertleşir)
static func _melt(pj: PathJutsu, p: Vector3) -> void:
	_splat(pj, p, 2.0)
	_emit(pj, {"kind": 0.0, "n": 24, "life": 0.9, "dir": Vector3.UP, "spread": 70.0, "vmin": 3.0, "vmax": 8.0, "g": Vector3(0, -14.0, 0), "smin": 0.08, "smax": 0.16, "r": 0.5,
		"curve": "flat", "cols": [Color(1.0, 0.8, 0.25, 1.0), Color(0.95, 0.55, 0.06, 1.0), Color(0.9, 0.5, 0.05, 0.0)]}, p + Vector3.UP * 1.0)
	_pool(pj, p, 5.0, 3.0, 2.2)


# ================================================================== SHIROGANE / KUKLACILAR
## Kurohigi Kiki Ippatsu (ref: Kankurō — Kuroari'nin bantlı gövdesi hedefi içine kapatır, Karasu'nun bıçaklı eklemli kolları
## çevresinde halka olup yuvalardan saplanır; tepede Karasu'nun başı). Kuroari yerden yükselip kapılarını hedefin üstüne çarpar;
## parmak uçlarından iplikler Kuroari'ye ve kollara uzanır
static func kurohigi_kiki_ippatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	if tt == null:
		return
	var rig = Node3D.new()
	var kuro = _kuro(1.9)
	rig.add_child(kuro)
	pj.attach(tt, rig, 2.6, Vector3.ZERO)
	kuro.position = Vector3(0, -1.6, 0)
	var kt = kuro.create_tween()
	kt.tween_property(kuro, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_doors(kuro, 0.0, 0.2, 0.06)
	_dust_ring(pj, tt.global_position, 1.1)
	var arms = []
	for k in 6:
		var a = TAU * k / 6.0 + 0.3
		var arm = Node3D.new()
		arm.add_child(_mi(_karasu_arm_mesh(), _toon(), {"ow": 0.012, "near_d": 1.4}))
		var h = 0.8 + (k % 3) * 0.5
		var dir = Vector3(cos(a), 0, sin(a))
		rig.add_child(arm)
		arm.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), dir * 5.5 + Vector3.UP * h)
		var at = arm.create_tween()
		at.tween_property(arm, "position", dir * 4.1 + Vector3.UP * h, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.04 * k)
		arm.set_meta("dir", dir)
		arm.set_meta("h", h)
		arms.append(arm)
	var head: Node3D = pj._karasu_head(1.0)
	rig.add_child(head)
	head.position = Vector3(0, 3.5, 0)
	for k in 5:
		_thread(pj, _finger_fn(pj, c, true, k), _local_pt(kuro, Vector3(0.12 * (k - 2), 2.75, 0)), 2.2, {"sag": 0.15})
		_thread(pj, _finger_fn(pj, c, false, k), _local_pt(arms[k], Vector3.ZERO), 2.2, {"sag": 0.2})
	pj.st(tt, "bind", 2.2)
	Sfx.play("block", tt.global_position, 0.6)
	var tick = func(i, _k):
		if not pj.live(tt):
			return
		var arm: Node3D = arms[i % 6]
		if is_instance_valid(arm):
			var dir: Vector3 = arm.get_meta("dir")
			var h: float = arm.get_meta("h")
			var th = arm.create_tween()
			th.tween_property(arm, "position", dir * 3.0 + Vector3.UP * h, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			th.tween_interval(0.1)
			th.tween_property(arm, "position", dir * 4.1 + Vector3.UP * h, 0.12)
			var sp: Vector3 = rig.to_global(dir * 0.86 + Vector3.UP * h)
			_blood(pj, sp, 5)
			_chips(pj, sp, 3, KURO_C, 3.0)
		pj.hit(c, tt.global_position + Vector3.UP, 0.9, pj.inf(c, "kurohigi_kiki_ippatsu", 0.3, {"knock": 0.0, "kind": "light", "burn": 2.0}))
		Sfx.play("throw_kunai", tt.global_position, 1.4, 0.5)
	pj.every(1.6, 0.2, tick)
	pj.after(0.6, func():
		if pj.live(tt):
			_blood(pj, tt.global_position + Vector3.UP * 1.2, 12))
	var rw = weakref(rig)
	var kw = weakref(kuro)
	pj.get_tree().create_timer(2.2).timeout.connect(func():
		var k2 = kw.get_ref()
		if k2 != null:
			_doors(k2, 1.6, 0.14)
		var r2 = rw.get_ref()
		if r2 != null:
			_vanish(r2, 0.12, 0.25))


## Kurohigi Kiki Nihatsu (ref: Kuroari'nin bantlı gövdesi; içeriden dışarı saplanan bıçaklar kabuğu yırtar): Kuroari hedefin
## arkasında yerden yükselir, iki kapısı ardına kadar açık; göğsünden iplikler hedefi sarıp içeri çeker, kapılar çarpar;
## bıçaklar içeriden dışarı fırlayıp kabukta yırtık bırakır, son darbede tırpan döner, kapılar patlayarak açılır
static func kurohigi_kiki_nihatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Kurohigi Kiki Nihatsu: Kuroari'nin yutacağı hedef yok", Color(0.75, 0.8, 0.95))
		return
	pj.busy(c, 1.3)
	var id = "kurohigi_kiki_nihatsu"
	var d = pj._face(c, tt)
	pj.anim(c, "cross", 1.3)
	var cw = weakref(c)
	var tw = weakref(tt)
	var bs = ClanJutsu.body_scale(tt)
	var back: Vector3 = pj.gp(tt.global_position + d * 1.9 * bs)
	var ks = 1.2 * bs
	var pup = _kuro(1.9)
	pj.scene_add(pup, back - Vector3.UP * 2.6 * ks)
	pup.global_basis = Basis.looking_at(d, Vector3.UP)
	pup.scale = Vector3.ONE * ks
	var ut = pup.create_tween()
	ut.tween_property(pup, "global_position", back, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dust_ring(pj, back, 1.3 * ks)
	for k in 3:
		_thread(pj, _finger_fn(pj, c, k != 1, 1 + k), _local_pt(pup, Vector3(0.3 * (k - 1), 2.7, 0)), 2.6, {"sag": 0.2})
	var pw = weakref(pup)
	Sfx.play("clink", back, 0.8)
	for k in 4:
		var off = Vector3(0, 0.5 + k * 0.35, 0)
		_thread(pj, _follow(pup, Vector3.UP * 1.5), _follow(tt, off), 0.55, {"sag": 0.04, "thick": 0.016})
	pj.st(tt, "bind", 2.3)
	pj.after(0.3, func():
		var x = tw.get_ref()
		var p = pw.get_ref()
		if x == null or p == null or not pj.live(x):
			return
		var xt = x.create_tween()
		xt.tween_property(x, "global_position", p.global_position + Vector3.UP * 0.05, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Combat.popup_text(p.global_position + Vector3.UP * 3.2, "Kuroari yuttu!", Color(0.75, 0.8, 0.95))
		_doors(p, 0.0, 0.1, 0.2))
	for k in 6:
		pj.after(0.62 + k * 0.17, func():
			var cc = cw.get_ref()
			var x = tw.get_ref()
			var p = pw.get_ref()
			if cc == null or p == null or not pj.live(cc):
				return
			var a = k * 1.05 + 0.4
			var o = Vector3(cos(a), 0, sin(a))
			var h = 0.55 + (k % 3) * 0.42
			var last = k == 5
			var cen: Vector3 = p.global_position + Vector3.UP * h * bs
			var bl = _mi(_blade_mesh(), _toon(), {"ow": 0.01, "wet": 0.7, "near_d": 1.2})
			pj.scene_add(bl, cen - o * 0.2)
			bl.global_basis = Basis.looking_at(o, Vector3.UP)
			var L = 2.6 * bs * 0.85
			bl.scale = Vector3(1.6 * bs, 1.6 * bs, 0.05)
			var bt = bl.create_tween()
			bt.tween_property(bl, "scale", Vector3(1.6 * bs, 1.6 * bs, L), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			bt.tween_interval(0.45)
			bt.tween_property(bl, "scale", Vector3(1.6 * bs, 1.6 * bs, 0.05), 0.12)
			bt.tween_callback(bl.queue_free)
			var ex: Vector3 = cen + o * (_kuro_r(h * bs / ks) * ks + 0.02)
			var tr = _mi(_tear_mesh(), _toon(), {"ow": 0.0, "near_d": 1.0})
			p.add_child(tr)
			tr.global_position = ex
			tr.global_basis = Basis.looking_at(-o, Vector3.UP)
			tr.scale = Vector3.ONE * 1.3
			_chips(pj, ex, 5, KURO_C, 4.0)
			Sfx.play("slash", p.global_position, 1.0 + k * 0.06)
			if last:
				var sk = _mi(_sickle_mesh(), _toon(), {"ow": 0.012, "wet": 0.6, "near_d": 1.2})
				pj.scene_add(sk, p.global_position + Vector3.UP * 1.0 * bs)
				sk.scale = Vector3.ONE * 1.25 * ks
				var st = sk.create_tween()
				st.tween_property(sk, "rotation:y", TAU * 1.5, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				st.tween_callback(sk.queue_free)
				_doors(p, 2.3, 0.12, 0.0, Tween.TRANS_BACK)
				_chips(pj, p.global_position + Vector3.UP * 1.2 * ks, 16, KURO_C, 8.0)
			if x != null and pj.live(x):
				x.take_hit(pj.inf(cc, id, 1.5 if last else 0.55, {"knock": 14.0 if last else 0.0, "launch": 3.0 if last else 0.0, "kind": "heavy" if last else "light", "bleed": 3.0, "hitstop": 0.07 if last else 0.02, "dir": -o}))
				_blood(pj, ex, 5))
	pj.get_tree().create_timer(2.6).timeout.connect(func():
		var p = pw.get_ref()
		if p != null:
			_vanish(p, 0.0, 0.3))
	pj.free_after(3.4, pup)


## Kugutsu: Samidare (ref: Kankurō — iki kukla rakibin üstünde asılı, gri demir bombalar yağar, sarı-beyaz patlama):
## kuklalar ipliklerle havaya çekilip açılır, her bomba bırakışta öne yalpalar; fitili kıvılcımlı bombalar düşer, iri ateş topu,
## şarapnel, toz halkası ve yerde sönen kor kenarlı is izi
static func kugutsu_samidare(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var id = "kugutsu_samidare"
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	pj.anim(c, "cross", 1.3)
	var cen: Vector3 = tt.global_position if tt else c.global_position + d * 10.0
	var sd = d.cross(Vector3.UP).normalized()
	var cw = weakref(c)
	var pups = []
	for k in 2:
		var at = cen - d * 3.5 + sd * (4.0 if k == 0 else -4.0) + Vector3.UP * 7.0
		pups.append(weakref(_hang(pj, c, at, (cen - at).normalized() * Vector3(1, 0, 1), 2.4, 1.0, k == 1)))
	Sfx.play("clink", c.global_position, 0.9)
	for k in 16:
		pj.after(0.3 + k * 0.1, func():
			var cc = cw.get_ref()
			var p = pups[k % 2].get_ref()
			if cc == null or p == null or not pj.live(cc):
				return
			var from: Vector3 = p.global_position + Vector3.UP * 1.0
			var aim: Vector3 = pj.gp(cen + Vector3(randf_range(-3.2, 3.2), 0, randf_range(-3.2, 3.2)))
			if k % 4 == 0:
				aim = pj.gp(cen)
			var yt = p.create_tween()
			yt.tween_property(p, "rotation:x", 0.25, 0.04)
			yt.tween_property(p, "rotation:x", 0.0, 0.08)
			var hitf = func(pp, _h):
				_bomb_blast(pj, pp, 0.75)
				var c2 = cw.get_ref()
				if c2 != null and pj.live(c2):
					pj.hit(c2, pp + Vector3.UP * 0.5, 2.5, pj.inf(c2, id, 0.5, {"knock": 5.0, "launch": 1.5, "kind": "heavy", "element": "katon", "burn": 2.0}))
				Sfx.play("boom", pp, 1.3, 0.6)
			var pr = pj.shot(cc, from, (aim - from).normalized(), 19.0, _bomb_node(), pj.inf(cc, id, 0.1, {"knock": 0.0, "kind": "light"}), null, false, 1.6, hitf)
			pr.gravity = 5.0)


## Bomba mermisi: demir küre + fitil ucunda sürekli kıvılcım
static func _bomb_node() -> Node3D:
	var root = Node3D.new()
	var mi = _mi(_bomb_mesh(), _toon(), {"ow": 0.012, "wet": 0.4, "near_d": 1.0})
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	root.add_child(mi)
	var p = _parts({"kind": 7.0, "n": 8, "life": 0.25, "one_shot": false, "dir": Vector3.UP, "spread": 60.0, "vmin": 0.5, "vmax": 2.0, "g": Vector3.ZERO,
		"smin": 0.05, "smax": 0.1, "r": 0.05, "cols": [Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.0)]})
	mi.add_child(p)
	p.position = Vector3(0.07, 0.29, 0)
	p.emitting = true
	return root


## Kugutsu: Fundan (ref: Kankurō — Karasu'nun başı gövdeden ayrılır, ağzından sivri fışkırır): baş parmak ipliklerine bağlı
## kavisle hedefin yanına dolanır, çene açılır, mor uçlu sivri saplanırken ağızdan mor zehir püskürür; baş ipliklerle geri sarılır
static func kugutsu_fundan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.75)
	var id = "kugutsu_fundan"
	var tt = pj.tg(c, t, 9.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.6)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var from: Vector3 = pj.hand_pos(c) + d * 0.4
	var head: Node3D = pj._karasu_head(1.25)
	pj.scene_add(head, from)
	head.global_basis = Basis.looking_at(-d, Vector3.UP)
	for k in 3:
		_thread(pj, _finger_fn(pj, c, true, 1 + k), _local_pt(head, Vector3((k - 1) * 0.12, 0.25, -0.1)), 0.9, {"sag": 0.08})
	var hw = weakref(head)
	var stop: Vector3 = from + d * 4.0 + Vector3.UP * 0.25
	if tt:
		var sd = d.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
		stop = tt.global_position + sd * 1.5 - d * 0.3 + Vector3.UP * 1.4
	var mid: Vector3 = from.lerp(stop, 0.5) + Vector3.UP * 1.2
	var ht = head.create_tween()
	ht.tween_property(head, "global_position", mid, 0.08)
	ht.tween_property(head, "global_position", stop, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.play("clink", from, 1.2)
	pj.after(0.17, func():
		var h = hw.get_ref()
		var cc = cw.get_ref()
		if h == null or cc == null or not pj.live(cc):
			return
		var jaw: Node3D = h.get_meta("jaw")
		jaw.rotation.x = 0.75
		var x = tw.get_ref() if tw else null
		var dv: Vector3 = d
		if x != null and pj.live(x):
			dv = (x.global_position + Vector3.UP * 1.1 - h.global_position).normalized()
			h.global_basis = Basis.looking_at(-dv, Vector3.UP)
		var sp = _mi(_spike_mesh(), _toon(), {"ow": 0.01, "wet": 0.7, "near_d": 1.0})
		pj.scene_add(sp, h.global_position - Vector3.UP * 0.08)
		sp.global_basis = Basis.looking_at(-dv, Vector3.UP)
		sp.scale = Vector3(1.3, 1.3, 0.1)
		var stw = sp.create_tween()
		stw.tween_property(sp, "scale", Vector3(1.3, 1.3, 2.3), 0.07)
		stw.tween_interval(0.3)
		stw.tween_property(sp, "scale", Vector3(1.3, 1.3, 0.1), 0.12)
		stw.tween_callback(sp.queue_free)
		_emit(pj, {"kind": 1.0, "n": 6, "life": 0.7, "dir": dv, "spread": 25.0, "vmin": 2.0, "vmax": 5.0, "g": Vector3(0, 0.3, 0), "damp": 3.0, "smin": 0.3, "smax": 0.6,
			"r": 0.1, "near": 2.5, "curve": "grow", "cols": [Color(0.66, 0.34, 0.8, 0.9), Color(0.5, 0.22, 0.6, 0.6), Color(0.4, 0.15, 0.48, 0.0)]}, h.global_position - Vector3.UP * 0.1)
		_emit(pj, {"kind": 0.0, "n": 6, "life": 0.5, "dir": dv, "spread": 30.0, "vmin": 3.0, "vmax": 6.0, "g": Vector3(0, -10, 0), "smin": 0.04, "smax": 0.07, "r": 0.05,
			"curve": "flat", "cols": [Color(0.62, 0.3, 0.75, 1.0), Color(0.45, 0.18, 0.55, 0.0)]}, h.global_position - Vector3.UP * 0.1)
		Sfx.play("slash", h.global_position, 1.4)
		Combat.hit_zone(cc, h.global_position - Vector3.UP * 1.4, dv, 2.6, 30.0, 2.6, pj.inf(cc, id, 2.1, {"knock": 6.0, "kind": "heavy", "poison": 5.0, "stun": 0.9, "pierce_guard": true, "hitstop": 0.08, "dir": dv})))
	pj.after(0.75, func():
		var h = hw.get_ref()
		var cc = cw.get_ref()
		if h != null:
			var back: Vector3 = pj.hand_pos(cc) if cc != null and is_instance_valid(cc) else h.global_position
			var rt = h.create_tween()
			rt.tween_property(h, "global_position", back, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			rt.parallel().tween_property(h, "scale", Vector3.ONE * 0.1, 0.16)
			rt.tween_callback(h.queue_free))
	pj.free_after(1.4, head)


## Kikō Junbū (ref: Kankurō / Sasori kuklaları — biri dikey, biri yatay iki kalın tahta kol çaprazlanır, açık avuç kesişimde):
## dikey kol yerden fırlar, yatay kol yandan dönerek kilitlenir (tahta yongaları); parmak uçlarından eklemlere iplikler.
## Gelen mermiler kıvılcım + beyaz kesik çizgisiyle biçilir; yaklaşan olursa kollardan gizli bıçaklar fırlar. 6 sn sonra katlanır
static func kiko_junbu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var root = Node3D.new()
	pj.scene_add(root, pj.gp(c.global_position + d * 1.6))
	root.look_at(root.global_position - d, Vector3.UP)
	var prm = {"ow": 0.014, "near_d": 1.6}
	var va = Node3D.new()
	va.add_child(_mi(_kiko_arm_mesh(3.0), _toon(), prm))
	root.add_child(va)
	va.position = Vector3(0, -0.15, 0)
	va.scale = Vector3(1, 0.05, 1)
	var vt = va.create_tween()
	vt.tween_property(va, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var hp = Node3D.new()
	root.add_child(hp)
	hp.position = Vector3(1.75, 1.55, 0.12)
	var ha = Node3D.new()
	ha.add_child(_mi(_kiko_arm_mesh(1.75), _toon(), prm))
	ha.rotation.z = PI * 0.5
	hp.add_child(ha)
	hp.rotation.y = -1.5
	var htw = hp.create_tween()
	htw.tween_interval(0.08)
	htw.tween_property(hp, "rotation:y", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.after(0.24, func():
		if is_instance_valid(root):
			_chips(pj, root.to_global(Vector3(0, 1.55, 0.2)), 10, WOOD_C, 5.0)
			_dust_ring(pj, root.global_position, 1.0))
	var blades = []
	var bdefs = [[va, Vector3(0.16, 0.9, 0), Vector3(90, 0, 0)], [va, Vector3(-0.16, 1.9, 0), Vector3(-90, 0, 0)], [ha, Vector3(0.16, 0.8, 0), Vector3(90, 0, 0)], [va, Vector3(0, 1.3, 0.16), Vector3(0, 0, 0)]]
	for bd in bdefs:
		var bl = _mi(_kblade_mesh(), _toon(), {"ow": 0.01, "wet": 0.6, "near_d": 1.0})
		var par: Node3D = bd[0]
		par.add_child(bl)
		bl.position = bd[1]
		bl.rotation_degrees = Vector3(0, float(bd[2].x), 0)
		bl.scale = Vector3(1, 1, 0.02)
		blades.append(bl)
	for k in 3:
		var tgt: Node3D = va if k != 1 else ha
		var lp = [Vector3(0, 1.0, 0.1), Vector3(0, 0.9, 0.1), Vector3(0, 2.4, 0.1)][k]
		_thread(pj, _finger_fn(pj, c, true, k + 1), _local_pt(tgt, lp), 6.0, {"sag": 0.12})
		_thread(pj, _finger_fn(pj, c, false, k + 1), _local_pt(tgt, lp + Vector3(0, 0.3, 0)), 6.0, {"sag": 0.12})
	var rw = weakref(root)
	var tick = func(i, _k):
		var r = rw.get_ref()
		if r == null:
			return
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and Combat.hostile(c, n.shooter) and n.global_position.distance_to(r.global_position + Vector3.UP * 1.5) < 2.8:
				_parry(pj, n.global_position)
				Sfx.play("block", n.global_position, 1.2, 0.5)
				n.queue_free()
		if i % 6 == 0:
			var near = pj.enemies_near(c, r.global_position, 2.6)
			if not near.is_empty():
				for bl in blades:
					if is_instance_valid(bl):
						var bt = bl.create_tween()
						bt.tween_property(bl, "scale", Vector3.ONE * 1.3, 0.05).set_trans(Tween.TRANS_EXPO)
						bt.tween_interval(0.18)
						bt.tween_property(bl, "scale", Vector3(1, 1, 0.02), 0.1)
			for e in near:
				pj.hit(c, e.global_position + Vector3.UP, 0.9, pj.inf(c, "kiko_junbu", 0.3, {"knock": 8.0, "kind": "heavy", "burn": 1.5}))
	pj.every(6.0, 0.1, tick, func():
		var r = rw.get_ref()
		if r == null:
			return
		if is_instance_valid(hp):
			hp.create_tween().tween_property(hp, "rotation:y", -1.5, 0.2)
		if is_instance_valid(va):
			va.create_tween().tween_property(va, "scale", Vector3(1, 0.05, 1), 0.25).set_delay(0.05)
		_vanish(r, 0.1, 0.25))
	pj.free_after(7.0, root)
	Sfx.play("clink", c.global_position, 0.8)


## Mermi biçilir: kıvılcım yıldızı + kısa beyaz kesik çizgisi + metal kırıntısı
static func _parry(pj: PathJutsu, at: Vector3) -> void:
	_emit(pj, {"kind": 3.0, "n": 8, "life": 0.25, "vmin": 2.0, "vmax": 6.0, "g": Vector3(0, -4.0, 0), "smin": 0.1, "smax": 0.22, "r": 0.1,
		"cols": [Color(1.0, 1.0, 0.9, 1.0), Color(1.0, 0.85, 0.5, 0.0)]}, at)
	var sl = _mi(_utube(), _toon(), {"ow": 0.0, "tint": Color(1, 1, 1), "pulse": 1.0, "near_d": 1.0})
	pj.get_tree().current_scene.add_child(sl)
	var dd = Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)).normalized()
	_span(sl, at - dd * 0.6, at + dd * 0.6, 0.02)
	_vanish(sl, 0.05, 0.12)
	_chips(pj, at, 4, STEEL_C, 4.0)


## Kugutsu no Jutsu (ref: Kankurō — sargı bezine sarılı kukla açılır, beş parmaktan mavi iplikler baş, omuz ve kalçaya):
## sargı bezi sarmal açılıp savrulur, iplikler kukla yaşadıkça sürer; kukla yönetilemezken (ip yenmiş, sersem) görünmez
static func kugutsu_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var list = ClanConstruct.spawn(c, "puppet", 1, Jutsu._jd("kugutsu_no_jutsu"))
	var units: Array = list if list is Array else []
	for u in units:
		_own_threads(u)
		_unwrap(pj, u)
		_pup_threads(pj, c, u, [[true, 0], [true, 1], [true, 2], [true, 3], [true, 4]], [PUP_PTS[0], PUP_PTS[1], PUP_PTS[2], PUP_PTS[3], PUP_PTS[4]])
	Sfx.play("clink", c.global_position, 0.9)


## Sargı bezi sarmal açılır: genişleyip dönerek düşer, söner; kumaş parçaları uçuşur
static func _unwrap(pj: PathJutsu, u) -> void:
	if u == null or not is_instance_valid(u):
		return
	var mi = _mi(_bandage_mesh(), _toon(), {"ow": 0.008, "near_d": 1.2})
	pj.scene_add(mi, u.global_position)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.6, 0.45, 2.6), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:y", 4.0, 0.5)
	_vanish(mi, 0.3, 0.3)
	_emit(pj, {"kind": 6.0, "n": 10, "life": 1.2, "vmin": 1.5, "vmax": 4.0, "g": Vector3(0, -2.0, 0), "damp": 1.5, "smin": 0.1, "smax": 0.2, "r": 0.5, "curve": "flat",
		"cols": [Color(0.94, 0.91, 0.82, 1.0), Color(0.94, 0.91, 0.82, 0.0)]}, u.global_position + Vector3.UP * 1.0)


## Shirohigi Jikki Chikamatsu no Shū (ref: Chiyo — yüksek yakalı beyaz cüppeli, alnında elmas mühürlü kuklalar; çevresinde
## kara elmas desenli beyaz parşömen): parşömen kuklacının çevresinde halka olup açılır, kuklalara beyaz cüppe ve mühür;
## on parmağın her birinden bir iplik kuklalara dağılır
static func shirohigi_jikki_chikamatsu_no_shu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_scroll_ring(pj, c)
	var list = ClanConstruct.spawn(c, "puppet", 4, Jutsu._jd("shirohigi_jikki_chikamatsu_no_shu"))
	var units: Array = list if list is Array else []
	for u in units:
		_own_threads(u)
		if u.get("vis") != null and is_instance_valid(u.vis):
			u.vis.add_child(_mi(_robe_mesh(), _toon(), {"ow": 0.012, "near_d": 1.2}))
		_emit(pj, {"kind": 6.0, "n": 8, "life": 1.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -2.0, 0), "damp": 1.5, "smin": 0.1, "smax": 0.2, "r": 0.4, "curve": "flat",
			"cols": [Color(0.96, 0.96, 0.94, 1.0), Color(0.96, 0.96, 0.94, 0.0)]}, u.global_position + Vector3.UP * 1.2)
	if not units.is_empty():
		for j in 10:
			var u = units[j % units.size()]
			var pt: Vector3 = PUP_PTS[(j / units.size()) % 3]
			_pup_threads(pj, c, u, [[j < 5, j % 5]], [pt])
	Sfx.play("clink", c.global_position, 0.7)


## Elmas desenli parşömen: kuklacının çevresinde bel hizasında halka olarak açılır, yavaşça döner, söner
static func _scroll_ring(pj: PathJutsu, c: Node3D) -> void:
	var mi = _mi(_scroll_mesh(), _toon(), {"ow": 0.006, "near_d": 1.2, "cut": 0.0})
	pj.scene_add(mi, c.global_position + Vector3.UP * 0.95)
	_tp(mi, "cut", 0.0, 1.01, 0.35)
	var tw = mi.create_tween()
	tw.tween_property(mi, "rotation:y", 1.4, 1.8)
	_vanish(mi, 1.4, 0.4)
	pj.free_after(2.2, mi)


## Shirogane Doku Kiri: savaş kuklası (gerçek kukla modeli) ipliklerle önde açılır; ağzından dalga dalga mor zehir pusu
## (iki tonlu, koyu kenarlı kabarık bulutlar) ileri yuvarlanır, önde 3 sn alçak mor sis + yerde kabarcıklı mor leke kalır
static func shirogane_doku_kiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var pup = _hang(pj, c, pj.gp(c.global_position + d * 1.8), d, 2.2, 1.0, false)
	pj.after(0.3, func():
		for k in 6:
			pj.after(k * 0.08, func():
				var base: Vector3 = (pup.global_position + Vector3.UP * 1.6 + d * (1.0 + k * 1.5)) if is_instance_valid(pup) else c.global_position
				_mist_wave(pj, base, d, k))
		_haze(pj, c.global_position + d * 6.0)
		pj.every(3.0, 0.5, func(_i, _k):
			for e in pj.enemies_near(c, c.global_position + d * 6.0, 5.0):
				if is_instance_valid(e) and not e.is_dead():
					e.take_hit(pj.inf(c, "shirogane_doku_kiri", 0.2, {"knock": 0.0, "kind": "light", "poison": 3.0})), Callable()))
	Sfx.play("smoke", c.global_position, 0.8)


static func _mist_wave(pj: PathJutsu, base: Vector3, d: Vector3, k: int) -> void:
	_emit(pj, {"kind": 1.0, "n": 7, "life": 1.8, "dir": d, "spread": 40.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, 0.2, 0), "damp": 0.8,
		"smin": 0.7 + k * 0.1, "smax": 1.3 + k * 0.15, "r": 0.6 + k * 0.3, "near": 3.0, "curve": "grow", "burst": 0.7,
		"cols": [Color(0.66, 0.34, 0.8, 0.0), Color(0.62, 0.3, 0.75, 0.88), Color(0.5, 0.22, 0.6, 0.6), Color(0.38, 0.14, 0.46, 0.0)]}, base)
	if k % 2 == 0:
		_emit(pj, {"kind": 0.0, "n": 4, "life": 0.8, "dir": d, "spread": 40.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -6.0, 0), "smin": 0.04, "smax": 0.07, "r": 0.4,
			"curve": "flat", "cols": [Color(0.62, 0.3, 0.75, 1.0), Color(0.45, 0.18, 0.55, 0.0)]}, base)


static func _haze(pj: PathJutsu, at: Vector3) -> void:
	var g = pj.gp(at)
	var p = _emit(pj, {"kind": 1.0, "n": 26, "life": 2.2, "one_shot": false, "dir": Vector3.UP, "spread": 180.0, "vmin": 0.1, "vmax": 0.5, "g": Vector3.ZERO,
		"smin": 1.4, "smax": 2.4, "box": Vector3(4.0, 0.3, 4.0), "near": 3.5, "curve": "grow",
		"cols": [Color(0.55, 0.26, 0.66, 0.0), Color(0.52, 0.24, 0.62, 0.6), Color(0.42, 0.16, 0.5, 0.0)]}, g + Vector3.UP * 0.5)
	_stop_after(pj, p, 3.0)
	var st = _decal(pj, g, 4.6, 3.0)
	_vanish(st, 3.2, 0.8)
	pj.free_after(4.4, st)
