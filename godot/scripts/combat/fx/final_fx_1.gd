class_name FinalFX1
extends RefCounted
## Son karışık grup 1: on beş tekniğin görselleri. Tüm görünüş bu dosyada sıfırdan üretilir:
## kızgın duman bedeni (alt yüzü korlu cel bulut, yerde is halkası), parmak kemiği mermisi (kontürlü beyaz kemik, kırılan kıymık),
## mercan (çalı / geyik boynuzu / mızrak biçimli dallı mercan + deniz köpüğü), mahkûm mührü (tomoe yayı, göğse dağlanır),
## ikiz yılan mührü + kan çekimi, lanet alevi dilleri, Kubikiribōchō'nun geniş kesik hilali, tekme yıldızı + hız çizgisi,
## yer yarığı / krater + kalkan kaya levhaları, gölge şurikeni ve yerdeki gölge izi, gölge elleri + kara bantlar,
## Yamata molozu + bej toz, kabuk değiştirme sümüğü, Kusanagi'nin delici ışık çizgisi + hava yarılması.
## Gerçek oyun sistemleri: yılan modelleri (make_snake / VfxSerpent / yamata_head / spine_mesh), Kusanagi modeli,
## lanetli mühür ten deseni (skin_marks) + beden biçimleri (juin_forms), CharacterModel kabuğu, Kubikiribōchō kombo pozları,
## Nara gölge erimi (Jutsu.shadow_reach). Kameraya yakın kısımlar yumuşakça incelir (ekranı kaplamaz).
## Oynanış (hasar, durum, süre, menzil, hedefleme, bedel) ana ağaçtaki işleyicilerden satır satır taşındı.

const UP := Vector3.UP
const INK := Color(0.04, 0.03, 0.05)
const SHADOW := Color(0.05, 0.045, 0.06)
const CORAL := Color(0.93, 0.5, 0.47)
const CORAL_D := Color(0.64, 0.24, 0.26)
const CORAL_T := Color(1.0, 0.86, 0.8)
const FOAM := Color(0.94, 0.98, 1.0)
const FOAM_S := Color(0.66, 0.82, 0.93)
const FOAM_LN := Color(0.4, 0.55, 0.68)
const BONE := Color(0.98, 0.97, 0.94)
const BONE_S := Color(0.74, 0.74, 0.77)
const SMOKE_L := Color(0.66, 0.61, 0.57)
const SMOKE_S := Color(0.43, 0.38, 0.36)
const SMOKE_LN := Color(0.17, 0.13, 0.12)
const EMBER := Color(1.0, 0.52, 0.16)
const CURSE := Color(0.33, 0.07, 0.44)
const CURSE_L := Color(0.74, 0.45, 0.96)
const SEAL_R := Color(0.55, 0.1, 0.12)
const SEAL_HOT := Color(1.0, 0.36, 0.3)
const DUST_L := Color(0.8, 0.75, 0.62)
const DUST_S := Color(0.6, 0.54, 0.44)
const DUST_LN := Color(0.27, 0.23, 0.18)
const EARTH_C := Color(0.36, 0.29, 0.22)
const ROCK := Color(0.52, 0.55, 0.5)
const SNAKE_TAN := Color(0.66, 0.5, 0.33)
const SNAKE_TAN2 := Color(0.56, 0.41, 0.26)
const BLOOD := Color(0.5, 0.05, 0.09)
const SLIME := Color(0.93, 0.9, 0.62)
const SLIME_S := Color(0.74, 0.71, 0.42)
const SLIME_LN := Color(0.42, 0.38, 0.18)
const KUSA_W := Color(0.97, 0.99, 1.0)
const KUSA_B := Color(0.6, 0.74, 1.0)

const SMOKE_COLS := [Color(0.66, 0.61, 0.57), Color(0.43, 0.38, 0.36), Color(0.17, 0.13, 0.12)]
const FOAM_COLS := [Color(0.94, 0.98, 1.0), Color(0.66, 0.82, 0.93), Color(0.4, 0.55, 0.68)]
const DUST_COLS := [Color(0.8, 0.75, 0.62), Color(0.6, 0.54, 0.44), Color(0.27, 0.23, 0.18)]
const STEEL_ARC := [Color(1.0, 1.0, 1.0), Color(0.76, 0.84, 0.92), Color(0.12, 0.14, 0.2)]

static var _cache := {}


# ================================================================== gölgelendiriciler
const COMMON := """
float fh1(float n) { return fract(sin(n * 127.1 + 0.3) * 43758.5453); }
float fh2(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fh2(i), fh2(i + vec2(1.0, 0.0)), f.x), mix(fh2(i + vec2(0.0, 1.0)), fh2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float camk(vec3 vpos, float nfar) {
	return smoothstep(max(nfar - 3.0, 0.0), nfar, length(vpos));
}
"""

const BB_VERTEX := """
void vertex() {
	if (bb > 0.5) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		if (bb < 1.5) {
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * sc.x, 0.0), vec4(INV_VIEW_MATRIX[1].xyz * sc.y, 0.0), vec4(INV_VIEW_MATRIX[2].xyz * sc.z, 0.0), MODEL_MATRIX[3]);
		} else {
			vec3 org = MODEL_MATRIX[3].xyz;
			vec3 fw = INV_VIEW_MATRIX[3].xyz - org;
			fw.y = 0.0;
			fw = normalize(fw + vec3(0.0001, 0.0, 0.0));
			vec3 rt = normalize(cross(vec3(0.0, 1.0, 0.0), fw));
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rt * sc.x, 0.0), vec4(0.0, sc.y, 0.0, 0.0), vec4(fw * sc.z, 0.0), MODEL_MATRIX[3]);
		}
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}
"""

## Düz şekiller (dörtgen): 0 yer çatlağı, 1 is halkası + kor, 2 krater, 3 boyuna yarık, 4 mahkûm mührü (tomoe yayı),
## 5 ikiz yılan mührü, 6 gölge göleti / leke, 7 darbe yıldızı, 8 sümük birikintisi, 9 kılıç parıltısı, 10 şuriken gölgesi,
## 11 hız çizgisi patlaması, 12 üç tomoe (lanet mührü). bb: 0 sabit, 1 kameraya dönük, 2 dik eksenli dönük
const FLAT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform vec4 c1 : source_color = vec4(0.1, 0.08, 0.07, 1.0);
instance uniform vec4 c2 : source_color = vec4(0.6, 0.55, 0.5, 1.0);
instance uniform vec4 c3 : source_color = vec4(0.05, 0.04, 0.04, 1.0);
instance uniform float alpha = 1.0;
instance uniform float prog = 1.0;
instance uniform float seed = 0.0;
instance uniform float nf = 2.0;
instance uniform float bb = 0.0;

COMMON
BB_VERTEX

float tomoe(vec2 d, float rr) {
	if (length(d) < rr) { return 1.0; }
	vec2 o1 = vec2(rr * 0.15, -rr * 0.9);
	vec2 o2 = vec2(rr * 1.0, -rr * 0.55);
	if (length(d - o1) < rr * 1.45 && length(d - o2) > rr * 1.2 && d.y < 0.0 && d.x > -rr * 1.3) { return 1.0; }
	return 0.0;
}

void fragment() {
	float ck = camk(VERTEX, nf);
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	float an = atan(p.y, p.x);
	float a01 = an / 6.2831853 + 0.5;
	vec3 col = c1.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		float n = 11.0;
		float sec = floor(a01 * n);
		float fa = fract(a01 * n) - 0.5;
		float jag = 0.22 * (vn(vec2(r * 7.0, sec * 3.7 + seed)) - 0.5);
		float len_ = 0.5 + 0.5 * fh1(sec + seed);
		float w = 0.035 * (1.0 - r / len_) + 0.004;
		float pe = abs(fa - jag) * max(r, 0.06) * 6.2831853 / n;
		if (r < len_ * prog && pe < w) { col = c1.rgb; a = 1.0; }
		else if (r < len_ * prog && pe < w + 0.018) { col = c2.rgb; a = 0.6; }
		float cr = 0.15 * prog + vn(p * 5.0 + seed) * 0.06;
		if (r < cr) { col = c1.rgb; a = 1.0; }
		else if (r < cr + 0.035) { col = c2.rgb; a = 0.8; }
	} else if (kind < 1.5) {
		float wob = 0.08 * vn(vec2(an * 3.0, seed));
		float rr = (0.55 + 0.33 * prog) * (0.9 + wob);
		if (r < rr) { col = c1.rgb; a = 0.25 + 0.5 * smoothstep(0.1, 0.9, r / rr); }
		if (abs(r - rr) < 0.045) { col = c3.rgb; a = 0.9; }
		float em = vn(p * 11.0 + seed * 3.0);
		if (r < rr - 0.06 && em > 0.8) { col = c2.rgb; a = 1.0; }
	} else if (kind < 2.5) {
		float rim = (0.42 + 0.08 * vn(vec2(an * 4.0, seed))) * mix(0.3, 1.0, prog);
		if (r < rim) { col = mix(c1.rgb, c2.rgb, smoothstep(0.0, rim, r) * 0.6); a = 0.95; }
		if (abs(r - rim) < 0.035) { col = c3.rgb; a = 1.0; }
		float n = 14.0;
		float sec = floor(a01 * n);
		float fa = fract(a01 * n) - 0.5;
		float len_ = rim + (0.25 + 0.3 * fh1(sec + seed)) * prog;
		float jag = 0.2 * (vn(vec2(r * 9.0, sec + seed)) - 0.5);
		float pe = abs(fa - jag) * r * 6.2831853 / n;
		if (r > rim && r < len_ && pe < 0.025 * (1.0 - (r - rim) / max(len_ - rim, 0.01)) + 0.003) { col = c3.rgb; a = 1.0; }
	} else if (kind < 3.5) {
		float along = (p.y + 1.0) * 0.5;
		if (along <= prog) {
			float jag = 0.25 * (vn(vec2(p.y * 6.0, seed)) - 0.5) + 0.1 * (vn(vec2(p.y * 20.0, seed + 3.0)) - 0.5);
			float w = 0.12 * (1.0 - abs(p.y)) + 0.02;
			float d = abs(p.x - jag);
			if (d < w) { col = c1.rgb; a = 1.0; }
			else if (d < w + 0.06) { col = c2.rgb; a = 0.7; }
			float bs = floor(along * 9.0);
			float bf = fract(along * 9.0);
			float sd = fh1(bs + seed) > 0.5 ? 1.0 : -1.0;
			float bx = p.x - jag - sd * bf * 0.5;
			if (fh1(bs * 3.0 + seed) > 0.4 && bf < 0.8 && abs(bx) < 0.025 * (1.0 - bf) + 0.004) { col = c1.rgb; a = 1.0; }
		}
	} else if (kind < 4.5) {
		float m = tomoe(p, 0.17);
		for (int i = 0; i < 9; i++) {
			float fi = float(i);
			if ((fi + 1.0) / 9.0 > prog + 0.001) { continue; }
			float ang = -2.3 + fi * 0.62;
			vec2 q = vec2(cos(ang), sin(ang)) * 0.66;
			vec2 d = p - q;
			float ca = cos(-ang - 1.4);
			float sa = sin(-ang - 1.4);
			d = vec2(d.x * ca - d.y * sa, d.x * sa + d.y * ca);
			float sz = mod(fi, 2.0) < 0.5 ? 0.085 : 0.05;
			m = max(m, tomoe(d, sz));
		}
		if (m > 0.5) { col = c1.rgb; a = 1.0; }
		else if (r < 0.92 && r > 0.4) { col = c2.rgb; a = 0.3 * c2.a * prog; }
	} else if (kind < 5.5) {
		float ln = 0.0;
		if (abs(r - 0.93) < 0.018 || abs(r - 0.7) < 0.014 || abs(r - 0.5) < 0.02) { ln = 1.0; }
		float zz = abs(fract(a01 * 30.0) - 0.5) * 2.0;
		if (abs(r - (0.815 + 0.09 * (zz - 0.5))) < 0.016) { ln = 1.0; }
		vec2 q1 = p - vec2(0.0, 0.25);
		vec2 q2 = p + vec2(0.0, 0.25);
		if (abs(length(q1) - 0.25) < 0.02 && p.x > 0.0) { ln = 1.0; }
		if (abs(length(q2) - 0.25) < 0.02 && p.x < 0.0) { ln = 1.0; }
		if (length(q1) < 0.07 || length(q2) < 0.07) { ln = 1.0; }
		if (a01 > prog) { ln = 0.0; }
		if (ln > 0.5) { col = c1.rgb; a = 1.0; }
		else if (r < 0.5 && a01 <= prog) { col = c2.rgb; a = 0.35; }
	} else if (kind < 6.5) {
		float edge = (0.72 + 0.2 * vn(vec2(an * 1.6 + seed, TIME * 0.7))) * prog;
		if (r < edge) { col = c1.rgb; a = 0.9; }
		float dots = vn(p * 9.0 + seed);
		if (r > edge && r < edge + 0.2 * prog && dots > 0.78) { col = c1.rgb; a = 0.9; }
	} else if (kind < 7.5) {
		float n = 9.0;
		float sp = fh1(floor(a01 * n) + seed);
		float fa = abs(fract(a01 * n) - 0.5) * 2.0;
		float spike = mix(0.4, 0.98, sp) * (1.0 - fa) + 0.3 * fa;
		float rr = spike * (0.5 + 0.5 * prog);
		float hole = max(prog - 0.45, 0.0) / 0.55 * rr * 0.75;
		if (r < rr && r > hole) {
			col = r < rr * 0.55 ? c1.rgb : c2.rgb;
			a = 1.0;
			if (r > rr - 0.05) { col = c3.rgb; }
		}
	} else if (kind < 8.5) {
		float edge = (0.62 + 0.25 * vn(p * 2.2 + seed * 5.0)) * prog;
		if (r < edge) {
			col = c1.rgb;
			a = 0.92;
			if (r > edge - 0.06) { col = c3.rgb; }
			vec2 hp = p - vec2(-0.2, 0.25) * edge;
			if (length(hp * vec2(1.0, 2.2)) < 0.16 * edge) { col = vec3(1.0, 1.0, 0.94); }
			else if (vn(p * 7.0 + seed) > 0.72 && r < edge - 0.06) { col = c2.rgb; }
		}
		float dots = vn(p * 10.0 + seed * 2.0);
		if (r > edge && r < edge + 0.2 && dots > 0.8) { col = c1.rgb; a = 0.92; }
	} else if (kind < 9.5) {
		vec2 q = p / max(prog, 0.05);
		float qx = abs(q.x);
		float qy = abs(q.y);
		vec2 dq = vec2(q.x + q.y, q.x - q.y) * 0.7071;
		float m = min(min(qx * 12.0 + qy, qy * 12.0 + qx), min(abs(dq.x) * 12.0 + abs(dq.y) * 1.8, abs(dq.y) * 12.0 + abs(dq.x) * 1.8));
		if (m < 1.0) { col = m < 0.45 ? c1.rgb : c2.rgb; a = 1.0; }
		if (length(q) < 0.12) { col = c1.rgb; a = 1.0; }
	} else if (kind < 10.5) {
		float fa = fract(a01 * 4.0 + r * 0.22);
		float bw = 0.3 * (1.0 - r) + 0.03;
		if (r < 0.95 && fa < bw) { col = c1.rgb; a = 1.0; }
		if (r < 0.22) { col = c1.rgb; a = 1.0; }
		if (r < 0.07) { a = 0.0; }
	} else if (kind < 11.5) {
		float n = 28.0;
		float sec = floor(a01 * n);
		float fa = abs(fract(a01 * n) - 0.5);
		float g = fh1(sec + seed);
		float r0 = mix(0.25, 0.55, g) + prog * 0.3;
		float r1 = r0 + mix(0.15, 0.4, fh1(sec * 7.0 + seed));
		if (g > 0.25 && r > r0 && r < r1 && fa < 0.12 * (1.0 - (r - r0) / (r1 - r0))) { col = c1.rgb; a = 1.0; }
	} else {
		float m = 0.0;
		for (int i = 0; i < 3; i++) {
			float ang = float(i) * 2.0944 + TIME * 2.0;
			vec2 q = vec2(cos(ang), sin(ang)) * 0.45;
			vec2 d = p - q;
			float ca = cos(-ang - 1.3);
			float sa = sin(-ang - 1.3);
			d = vec2(d.x * ca - d.y * sa, d.x * sa + d.y * ca);
			m = max(m, tomoe(d, 0.16));
		}
		if (m > 0.5) { col = c1.rgb; a = 1.0; }
		else if (abs(r - 0.45) < 0.02) { col = c2.rgb; a = 0.6 * prog; }
	}
	a *= alpha * ck;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Cel bulut parçası (duman, köpük, toz): tırtıklı kenar, iki ton + koyu kontur; heat > 0 alt yüzü kor rengine boyar; dis ile delinerek dağılır
const PUFF_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 lit : source_color = vec4(0.8, 0.75, 0.7, 1.0);
instance uniform vec4 shade : source_color = vec4(0.5, 0.45, 0.4, 1.0);
instance uniform vec4 line : source_color = vec4(0.2, 0.15, 0.12, 1.0);
instance uniform vec4 heat_c : source_color = vec4(1.0, 0.55, 0.2, 1.0);
instance uniform float heat = 0.0;
instance uniform float alpha = 1.0;
instance uniform float seed = 0.0;
instance uniform float dis = 0.0;
instance uniform float nf = 4.0;
instance uniform float bb = 1.0;

COMMON
BB_VERTEX

void fragment() {
	float ck = camk(VERTEX, nf);
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	float an = atan(p.y, p.x);
	float edge = 0.72 + 0.1 * sin(an * 5.0 + seed * 6.0) + 0.1 * vn(vec2(an * 2.0 + seed, TIME * 0.5));
	if (r > edge) { discard; }
	float hole = vn(p * 3.0 + vec2(seed * 4.0, TIME * 0.35));
	if (hole < dis) { discard; }
	float sh = dot(p / edge, normalize(vec2(-0.45, 0.8)));
	vec3 col = (sh > -0.2 - 0.15 * hole) ? lit.rgb : shade.rgb;
	if (heat > 0.0 && p.y < -0.2 + 0.25 * hole) { col = mix(col, heat_c.rgb, heat); }
	if (r > edge - 0.07 || hole < dis + 0.05) { col = line.rgb; }
	float a = alpha * ck;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Katı cel şekil (köşe rengi × tint, iki ton); glow_k ile parlama rengine çekilir; alpha ve kamera yakınlığı noktalı inceltir
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 glow : source_color = vec4(1.0, 0.4, 0.3, 1.0);
instance uniform float glow_k = 0.0;
instance uniform float alpha = 1.0;
instance uniform float seed = 0.0;
instance uniform float nf = 2.0;

COMMON

void fragment() {
	float ck = camk(VERTEX, nf);
	if (fh2(floor(FRAGCOORD.xy) + vec2(seed * 17.0)) > alpha * ck) { discard; }
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float sh = dot(wn, normalize(vec3(0.4, 0.85, 0.35))) > -0.05 ? 1.0 : 0.72;
	vec3 col = COLOR.rgb * tint.rgb * sh;
	col = mix(col, glow.rgb, glow_k);
	ALBEDO = col;
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

instance uniform float ow = 0.02;
instance uniform float alpha = 1.0;
instance uniform float nf = 2.0;
instance uniform float seed = 0.0;
instance uniform vec4 oc : source_color = vec4(0.06, 0.04, 0.05, 1.0);

COMMON

void vertex() {
	VERTEX += NORMAL * ow;
}

void fragment() {
	float ck = camk(VERTEX, nf);
	if (fh2(floor(FRAGCOORD.xy) + vec2(seed * 17.0)) > alpha * ck) { discard; }
	ALBEDO = oc.rgb;
}
"""

## Şerit: UV.x boy, UV.y en. pat 0 kesik hilali (iç kenar ince, dış kenar beyaz + koyu kontur), 2 sümük ipi,
## 3 lanet alevi dili (taban → uç), 4 kan çekim akışı (akan kesik çizgiler), 5 ince ışık çizgisi
const RIBBON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float pat = 0.0;
instance uniform vec4 c1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c2 : source_color = vec4(0.7, 0.8, 0.9, 1.0);
instance uniform vec4 c3 : source_color = vec4(0.05, 0.05, 0.08, 1.0);
instance uniform float alpha = 1.0;
instance uniform float reveal = 1.0;
instance uniform float tail = 0.0;
instance uniform float seed = 0.0;
instance uniform float nf = 2.0;

COMMON

void fragment() {
	float ck = camk(VERTEX, nf);
	float u = UV.x;
	float v = UV.y;
	float ac = abs(v - 0.5) * 2.0;
	if (u > reveal || u < tail) { discard; }
	float k = clamp((u - tail) / max(reveal - tail, 0.001), 0.0, 1.0);
	vec3 col = c1.rgb;
	float a = 1.0;
	if (pat < 0.5) {
		float th = pow(sin(k * 3.14159), 0.7);
		if (v > th) { discard; }
		col = v > th * 0.8 ? c1.rgb : c2.rgb;
		if (v > th * 0.94) { col = c3.rgb; }
		a = mix(0.5, 1.0, v / max(th, 0.01));
		if (fh1(floor(u * 48.0) + seed) > 0.8 && v < th * 0.7) { a *= 0.3; }
	} else if (pat < 2.5) {
		float w = 0.55 + 0.35 * sin(u * 17.0 + seed * 3.0);
		if (ac > w) { discard; }
		col = ac < w * 0.3 ? mix(c1.rgb, vec3(1.0), 0.5) : (ac < w * 0.75 ? c1.rgb : c2.rgb);
		if (ac > w * 0.88) { col = c3.rgb; }
		a = 0.94;
	} else if (pat < 3.5) {
		float fl = vn(vec2(u * 5.0 - TIME * 7.0, seed));
		float w = pow(max(1.0 - u, 0.0), 0.6) * (0.6 + 0.45 * fl);
		float sway = 0.25 * sin(u * 6.0 - TIME * 9.0 + seed) * u;
		float d = abs((v - 0.5) * 2.0 - sway);
		if (d > w) { discard; }
		col = d < w * 0.55 ? c1.rgb : c2.rgb;
		if (d > w * 0.85) { col = c3.rgb; }
	} else if (pat < 4.5) {
		float f = fract(u * 7.0 - TIME * 3.5 + seed);
		float w = 0.5 + 0.4 * sin(f * 3.14159);
		if (ac > w || f < 0.25) { discard; }
		col = ac < w * 0.45 ? c1.rgb : c2.rgb;
		a = 0.9;
	} else {
		float w = 0.9 * sin(k * 3.14159) + 0.1;
		if (ac > w) { discard; }
		col = ac < w * 0.35 ? c1.rgb : c2.rgb;
		a = ac < w * 0.35 ? 1.0 : 0.7;
	}
	a *= alpha * ck;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""


# ================================================================== malzeme / düğüm yardımcıları
static func _mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if _cache.has(k):
		return _cache[k]
	var sh = Shader.new()
	sh.code = code.replace("BB_VERTEX", BB_VERTEX).replace("COMMON", COMMON)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[k] = m
	return m


static func _ink_mat() -> StandardMaterial3D:
	if _cache.has("mat:ink"):
		return _cache["mat:ink"]
	var m = StandardMaterial3D.new()
	m.albedo_color = INK
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache["mat:ink"] = m
	return m


static func _shade_mat() -> StandardMaterial3D:
	if _cache.has("mat:shade"):
		return _cache["mat:shade"]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["mat:shade"] = m
	return m


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _params(mi: GeometryInstance3D, prm: Dictionary) -> void:
	for k in prm:
		mi.set_instance_shader_parameter(k, prm[k])


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
	tw.tween_method(func(v: float):
		if is_instance_valid(n):
			_all(n, key, v), a, b, maxf(dur, 0.01))
	return tw


static func _alpha_free(n: Node, delay: float, dur: float) -> void:
	var tw = _tp(n, "alpha", 1.0, 0.0, dur, delay)
	tw.tween_callback(n.queue_free)


## Düğümü delay sonra küçültüp siler (yılan başları, Yamata gövdesi)
static func _shrink_free(n: Node3D, delay: float, dur: float) -> void:
	if not is_instance_valid(n):
		return
	var s0: Vector3 = n.scale
	var tw = n.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(n, "scale", s0 * 0.05, maxf(dur, 0.01)).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


static func _kill_after(pj: Node, n: Node, sec: float) -> void:
	var w = weakref(n)
	pj.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func _later(pj: Node, sec: float, fn: Callable) -> void:
	pj.get_tree().create_timer(maxf(sec, 0.0)).timeout.connect(fn)


static func _add(pj: Node, n: Node3D, pos: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func _gp(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z), p.z)


static func _h(t: Node3D) -> float:
	return float(t.get("height")) if t.get("height") != null else 1.8


static func _fdir(c: Node3D) -> Vector3:
	if c.has_method("face_dir"):
		return c.face_dir()
	return -c.global_transform.basis.z


static func _flatv(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD


static func _bone_pos(c: Node3D, bone: String, fb: Vector3) -> Vector3:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.get("skel") != null and m.skel:
		var bi = m.skel.find_bone(bone)
		if bi >= 0:
			return (m.skel.global_transform * m.skel.get_bone_global_pose(bi)).origin
	return c.global_position + fb


static func _slowmo(pj: Node, s: float, real_dur: float) -> void:
	if Combat.base_time_scale < 0.99:
		return
	Combat.base_time_scale = s
	Engine.time_scale = s
	pj.get_tree().create_timer(real_dur, true, false, true).timeout.connect(func():
		if absf(Combat.base_time_scale - s) < 0.001:
			Combat.base_time_scale = 1.0)


static func _quad() -> QuadMesh:
	if not _cache.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2.ONE
		_cache["mesh:quad"] = q
	return _cache["mesh:quad"]


static func _drop_mesh() -> SphereMesh:
	if not _cache.has("mesh:drop"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		_cache["mesh:drop"] = sm
	return _cache["mesh:drop"]


static func _chip_mesh() -> BoxMesh:
	if not _cache.has("mesh:chip"):
		var bm = BoxMesh.new()
		bm.size = Vector3.ONE
		_cache["mesh:chip"] = bm
	return _cache["mesh:chip"]


static func _shard_mesh() -> PrismMesh:
	if not _cache.has("mesh:shard"):
		var pm = PrismMesh.new()
		pm.size = Vector3(0.4, 1.0, 0.14)
		_cache["mesh:shard"] = pm
	return _cache["mesh:shard"]


static func _tongue_mesh() -> PrismMesh:
	if not _cache.has("mesh:tongue"):
		var pm = PrismMesh.new()
		pm.size = Vector3(0.55, 1.0, 0.08)
		_cache["mesh:tongue"] = pm
	return _cache["mesh:tongue"]


static func _shrink_curve() -> Curve:
	if not _cache.has("curve:shrink"):
		var cv = Curve.new()
		cv.add_point(Vector2(0.0, 1.0))
		cv.add_point(Vector2(1.0, 0.0))
		_cache["curve:shrink"] = cv
	return _cache["curve:shrink"]


## Düz şekil dörtgeni (sahneye eklenmemiş)
static func _flat(kind: float, size: Vector2, prm: Dictionary, bb := 0.0) -> MeshInstance3D:
	var mi = _mi(_quad(), _mat("flat", FLAT_SHADER))
	var p = {"kind": kind, "bb": bb, "seed": randf() * 10.0}
	p.merge(prm, true)
	_params(mi, p)
	mi.scale = Vector3(size.x, size.y, 1.0)
	return mi


## Düz şekil: grow sn'de çizilir (prog 0→1), hold bekler, fade'de söner ve silinir
static func _pop(pj: Node, kind: float, pos: Vector3, size: Vector2, grow: float, hold: float, fade: float, prm := {}, bb := 1.0) -> MeshInstance3D:
	var mi = _flat(kind, size, prm, bb)
	_add(pj, mi, pos)
	mi.set_instance_shader_parameter("prog", 0.0)
	var a0 = float(prm.get("alpha", 1.0))
	var tw = _tp(mi, "prog", 0.0, 1.0, grow)
	tw.tween_interval(hold)
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("alpha", v), a0, 0.0, maxf(fade, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


## Yere yatırılmış düz şekil
static func _decal(pj: Node, kind: float, at: Vector3, r: float, grow: float, hold: float, fade: float, prm := {}) -> MeshInstance3D:
	var mi = _pop(pj, kind, at + UP * 0.04, Vector2(r * 2.0, r * 2.0), grow, hold, fade, prm, 0.0)
	mi.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
	return mi


## Yere yatırılmış, dir boyunca uzanan düz şekil (yarık, birikinti)
static func _decal_line(pj: Node, kind: float, from: Vector3, dir: Vector3, L: float, w: float, grow: float, hold: float, fade: float, prm := {}) -> MeshInstance3D:
	var mi = _pop(pj, kind, from + UP * 0.04, Vector2.ONE, grow, hold, fade, prm, 0.0)
	var f = _flatv(dir)
	var sd = f.cross(UP).normalized()
	mi.global_transform = Transform3D(Basis(sd * w, f * L, UP), from + f * L * 0.5 + UP * 0.04)
	return mi


static func _light(pj: Node, pos: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_add(pj, l, pos)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Cel bulut parçası: pos'tan vel yönüne kayar, büyür, delik delik dağılır. o: a, grow, nf, heat, heat_c
static func _puff(pj: Node, pos: Vector3, size: float, vel: Vector3, life: float, cols: Array, o := {}) -> MeshInstance3D:
	var mi = _mi(_quad(), _mat("puff", PUFF_SHADER))
	_params(mi, {"lit": cols[0], "shade": cols[1], "line": cols[2], "alpha": float(o.get("a", 1.0)), "seed": randf() * 10.0,
		"nf": float(o.get("nf", 4.0)), "dis": 0.0, "bb": 1.0, "heat": float(o.get("heat", 0.0)), "heat_c": o.get("heat_c", EMBER)})
	mi.scale = Vector3.ONE * size
	_add(pj, mi, pos)
	var grow = float(o.get("grow", 1.6))
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position", pos + vel * life, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi, "scale", Vector3.ONE * size * grow, life).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("dis", v), 0.0, 1.0, life * 0.55).set_delay(life * 0.45)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Kendi ayarlı parçacık püskürtmesi (kor, damla, kıymık, toprak topağı). parent verilirse onu izler.
static func _spray(pj: Node, pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	var one: bool = bool(o.get("one", true))
	p.one_shot = one
	p.amount = int(o.get("n", 16))
	p.lifetime = float(o.get("life", 0.8))
	p.explosiveness = float(o.get("expl", 0.9 if one else 0.0))
	var mesh = o.get("mesh", null)
	p.mesh = mesh if mesh is Mesh else _chip_mesh()
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = o.get("col", Color.WHITE)
	if o.has("ramp"):
		var cols: Array = o["ramp"]
		var g = Gradient.new()
		g.set_color(0, cols[0])
		g.set_color(1, cols[cols.size() - 1])
		for i in range(1, cols.size() - 1):
			g.add_point(float(i) / (cols.size() - 1), cols[i])
		p.color_ramp = g
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color.WHITE
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.15))
	p.direction = o.get("dir", UP)
	p.spread = float(o.get("spread", 60.0))
	p.initial_velocity_min = float(o.get("v0", 2.0))
	p.initial_velocity_max = float(o.get("v1", 5.0))
	p.gravity = Vector3(0, -float(o.get("grav", 9.8)), 0)
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.angular_velocity_min = -float(o.get("spin", 0.0))
	p.angular_velocity_max = float(o.get("spin", 0.0))
	p.scale_amount_min = float(o.get("s0", 0.05))
	p.scale_amount_max = float(o.get("s1", 0.1))
	p.scale_amount_curve = _shrink_curve()
	if bool(o.get("align", false)):
		p.particle_flag_align_y = true
	var parent = o.get("parent", null)
	if parent is Node3D:
		p.local_coords = false
		parent.add_child(p)
		p.position = o.get("off", Vector3.ZERO)
	else:
		_add(pj, p, pos)
	p.emitting = true
	if one:
		_kill_after(pj, p, p.lifetime + 0.5)
	return p


## Bir düğümün altındaki tüm püskürtmeleri durdurup düğümü siler
static func _stop_free(pj: Node, n: Node, wait := 1.0) -> void:
	if not is_instance_valid(n):
		return
	for ch in n.get_children():
		if ch is CPUParticles3D:
			ch.emitting = false
	_kill_after(pj, n, wait)


## Katı cel model + ters kabuk konturu
static func _solid(mesh: Mesh, ow: float, nf := 2.0, tint := Color.WHITE) -> Node3D:
	var root = Node3D.new()
	var body = _mi(mesh, _mat("cel", CEL_SHADER))
	_params(body, {"tint": tint, "nf": nf, "alpha": 1.0, "seed": randf() * 10.0, "glow_k": 0.0})
	root.add_child(body)
	if ow > 0.0:
		var ol = _mi(mesh, _mat("outline", OUTLINE_SHADER))
		_params(ol, {"ow": ow, "nf": nf, "alpha": 1.0, "seed": randf() * 10.0})
		root.add_child(ol)
	return root


## pts boyunca şerit: sides[i] yan yön (birim), ws[i] yarı en. UV.x boy, UV.y en (0 = -yan, 1 = +yan)
static func _strip(b: MB, pts: Array, sides: Array, ws: Array) -> void:
	var n = pts.size()
	var base = b.verts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var sd: Vector3 = sides[i]
		var w: float = ws[i]
		var u = float(i) / maxf(n - 1, 1)
		b.verts.append(p - sd * w)
		b.verts.append(p + sd * w)
		b.normals.append(UP)
		b.normals.append(UP)
		b.colors.append(Color.WHITE)
		b.colors.append(Color.WHITE)
		b.uvs.append(Vector2(u, 0.0))
		b.uvs.append(Vector2(u, 1.0))
	for i in n - 1:
		var a0 = base + i * 2
		b.idx.append_array(PackedInt32Array([a0, a0 + 2, a0 + 1, a0 + 1, a0 + 2, a0 + 3]))


static func _ribbon_node(mesh: Mesh, prm: Dictionary) -> MeshInstance3D:
	var mi = _mi(mesh, _mat("ribbon", RIBBON_SHADER))
	_params(mi, prm)
	return mi


## İki nokta arası kavisli çift şerit (her açıdan görünür); reveal ile akar, hold sonra söner
static func _arc_ribbon(pj: Node, a: Vector3, b: Vector3, lift: float, w: float, prm: Dictionary, grow: float, hold: float, fade: float) -> MeshInstance3D:
	var mb = MB.new()
	var dv = b - a
	var sd = dv.cross(UP)
	sd = sd.normalized() if sd.length() > 0.01 else Vector3.RIGHT
	var up2 = sd.cross(dv.normalized()).normalized()
	var pts = []
	var s1 = []
	var s2 = []
	var ws = []
	for k in 17:
		var u = k / 16.0
		pts.append(a.lerp(b, u) + UP * sin(u * PI) * lift)
		s1.append(sd)
		s2.append(up2)
		ws.append(w)
	_strip(mb, pts, s1, ws)
	_strip(mb, pts, s2, ws)
	var p = {"reveal": 0.0, "tail": 0.0, "alpha": 1.0, "seed": randf() * 10.0}
	p.merge(prm, true)
	var mi = _ribbon_node(mb.build(null), p)
	_add(pj, mi, Vector3.ZERO)
	var tw = _tp(mi, "reveal", 0.0, 1.0, grow)
	tw.tween_interval(hold)
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("alpha", v), 1.0, 0.0, maxf(fade, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


## Dikey çift şerit (alev dili): taban y=0, uç y=1
static func _tongue_strip() -> ArrayMesh:
	if _cache.has("mesh:tongue_strip"):
		return _cache["mesh:tongue_strip"]
	var b = MB.new()
	var pts = []
	var s1 = []
	var s2 = []
	var ws = []
	for k in 9:
		pts.append(Vector3(0, k / 8.0, 0))
		s1.append(Vector3.RIGHT)
		s2.append(Vector3.BACK)
		ws.append(0.5)
	_strip(b, pts, s1, ws)
	_strip(b, pts, s2, ws)
	var mesh = b.build(null)
	_cache["mesh:tongue_strip"] = mesh
	return mesh


## Toprak / kıymık topakları
static func _clods(pj: Node, at: Vector3, n: int, v: float, col: Color, s := 0.12) -> void:
	_spray(pj, at + UP * 0.2, {"n": n, "life": 0.9, "r": 0.4, "dir": UP, "spread": 55.0, "v0": v * 0.5, "v1": v, "grav": 20.0,
		"s0": s * 0.6, "s1": s * 1.3, "col": col, "spin": 8.0})


# ================================================================== IBURI — Kemuri Bakusan
## Iburi: Kemuri Bakusan* — bedenin bir anda kızgın bir duman patlamasına dağılır: çevrendekiler savrulup yanar, sen o an
## dokunulmazsın; duman toplanıp yeniden beden olursun. Görünüş: beden biçimli sütun kabarır, alt yüzü korlu duman halkası
## yerde dışa yuvarlanır, kor taneleri, yerde is halkası; sonra duman dört yandan içe akıp bedene toplanır.
static func iburi_kemuri_bakusan(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "iburi_kemuri_bakusan"
	var p: Vector3 = c.global_position
	var m = c.get("model")
	if m:
		m.visible = false
	c.set_meta("kemuri_tai_until", Time.get_ticks_msec() / 1000.0 + 0.8)
	if c is Player:
		Buffs.add("kemuri_tai", 0.8, {"armor": 0.05, "_name": "Duman Beden", "_desc": "fiziksel darbeler içinden geçer"})
	_kemuri_burst(pj, p)
	Sfx.play("boom", p, 0.8)
	pj.shake(0.35)
	for e in pj.enemies_near(c, p, 4.5):
		var v: Vector3 = e.global_position - p
		v.y = 0
		e.take_hit(pj.inf(c, id, 1.3, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "burn": 2.0, "element": "katon", "hitstop": 0.08, "dir": v.normalized() if v.length() > 0.1 else c.face_dir()}))
	var cw = weakref(c)
	pj.after(0.75, func():
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc):
			_kemuri_gather(pj, cc.global_position)
			if cc.get("model"):
				cc.model.visible = true)


static func _kemuri_burst(pj: Node, p: Vector3) -> void:
	var g = _gp(p)
	for k in 7:   # beden biçimli sütun yerinde kabarır
		var o = Vector3(randf_range(-0.15, 0.15), 0.25 + k * 0.24, randf_range(-0.15, 0.15))
		_puff(pj, g + o, 0.75, Vector3(randf_range(-1.0, 1.0), 0.6, randf_range(-1.0, 1.0)) * 2.2, 0.55, SMOKE_COLS, {"grow": 2.2, "heat": 0.35, "nf": 3.5})
	for k in 16:   # yerde dışa yuvarlanan kızgın halka
		var a = TAU * k / 16.0 + randf_range(-0.1, 0.1)
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + dv * 0.5 + UP * 0.45, randf_range(0.8, 1.1), dv * randf_range(7.0, 9.0) + UP * 0.4, randf_range(0.75, 0.95), SMOKE_COLS, {"grow": 1.9, "heat": 0.75, "nf": 3.5})
	for k in 8:   # üstte kabaran bulut
		var a = TAU * k / 8.0 + 0.2
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + UP * 1.3 + dv * 0.3, randf_range(1.0, 1.3), dv * 3.5 + UP * randf_range(2.5, 4.0), 1.0, SMOKE_COLS, {"grow": 1.7, "heat": 0.25, "nf": 4.0})
	_spray(pj, g + UP * 1.0, {"n": 30, "life": 0.9, "r": 0.5, "dir": UP, "spread": 180.0, "v0": 5.0, "v1": 11.0, "grav": 4.0, "damp": 3.0,
		"s0": 0.04, "s1": 0.09, "ramp": [Color(1.0, 0.92, 0.55), EMBER, Color(0.45, 0.1, 0.04)]})
	_decal(pj, 1, g, 4.5, 0.25, 1.2, 1.0, {"c1": Color(0.16, 0.13, 0.12), "c2": EMBER, "c3": Color(0.07, 0.05, 0.05), "alpha": 0.85})
	_light(pj, g + UP * 1.0, Color(1.0, 0.55, 0.25), 3.0, 8.0, 0.45)
	_later(pj, 0.35, func():   # yere çöken ağır duman, yavaş söner
		for k in 6:
			var a = randf() * TAU
			var dv = Vector3(cos(a), 0, sin(a))
			_puff(pj, g + dv * randf_range(1.5, 3.5) + UP * 0.35, 1.2, dv * 0.6, 2.2, SMOKE_COLS, {"grow": 1.4, "a": 0.75, "nf": 3.5}))


static func _kemuri_gather(pj: Node, pos: Vector3) -> void:
	var g = _gp(pos)
	for k in 12:
		var a = TAU * k / 12.0
		var from = g + Vector3(cos(a), 0, sin(a)) * 2.2 + UP * (0.3 + (k % 4) * 0.4)
		var to = g + UP * (0.5 + (k % 4) * 0.35)
		_puff(pj, from, 0.9, (to - from) / 0.35, 0.35, SMOKE_COLS, {"grow": 0.35, "heat": 0.2, "nf": 3.5})
	_spray(pj, g + UP * 1.0, {"n": 18, "life": 0.4, "r": 1.4, "dir": UP, "spread": 180.0, "v0": -4.0, "v1": -2.5, "grav": 0.0,
		"s0": 0.03, "s1": 0.06, "ramp": [Color(1.0, 0.85, 0.5), EMBER]})


# ================================================================== Teshi Sendan (jutsu.gd j_)
## Parmak uçlarından kemik mermiler (ref: iki boğumlu beyaz kemik, koyu kontur, gri gölge çizikleri): sekiz kemik art arda dönerek
## (matkap gibi) uçar; parmak ucunda kemik tozu, çarpınca kemik kıymıkları saçılır.
static func bone_bullets(jz, c: Node3D, t: Node3D) -> void:
	var m = jz._mult(c)
	jz._ticks(8, 0.07, func(_i):
		if not is_instance_valid(c):
			return
		var pr = Projectile.new()
		pr.shooter = c
		pr.vel = jz._aim(c, t).rotated(Vector3.UP, randf_range(-0.04, 0.04)) * 48.0
		pr.radius = 0.25
		pr.homing = t
		pr.homing_turn = 1.5
		pr.info = {"dmg": 6.0 * m, "knock": 2.0, "kind": "light", "hitstop": 0.02}
		pr.add_child(_bone_bullet())
		pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
			_bone_shatter(jz, pos)
		jz.get_tree().current_scene.add_child(pr)
		var from: Vector3 = jz._hand(c)
		pr.global_position = from
		var dv: Vector3 = pr.vel
		if dv.length() > 0.01:
			pr.look_at(from + dv, Vector3.UP if absf(dv.normalized().y) < 0.95 else Vector3.RIGHT)
		pr.spin = Vector3(0, 0, 25)
		_bone_dust(jz, pr)
		_bone_muzzle(jz, from, dv.normalized())
		Sfx.play("kunai", c.global_position, 0.8, 0.6))


## Kemik mermisi (ileri -Z): önde iri boğum, ince boyun, arkada düz kesik halka (ref)
static func _bone_bullet() -> Node3D:
	if not _cache.has("mesh:bone_bullet"):
		var b = MB.new()
		b.add_grad("sphere", Vector3(0, 0, -0.1), Vector3(0.3, 0.3, 0.34), BONE, BONE_S, Vector3.ZERO, 12)
		b.add_grad("cyl", Vector3(0, 0, 0.06), Vector3(0.17, 0.16, 0.17), BONE, BONE_S, Vector3(90, 0, 0), 10)
		b.add_grad("sphere", Vector3(0, 0, 0.14), Vector3(0.23, 0.23, 0.22), BONE, BONE_S, Vector3.ZERO, 10)
		b.add("cyl", Vector3(0, 0, 0.24), Vector3(0.2, 0.05, 0.2), BONE_S.lightened(0.15), Vector3(90, 0, 0), 12)
		for k in 3:   # gri çizik gölgeleri
			var a = k * 2.1
			b.add("box", Vector3(cos(a) * 0.14, sin(a) * 0.14, -0.1 + k * 0.05), Vector3(0.02, 0.012, 0.09), BONE_S.darkened(0.25), Vector3(0, 0, rad_to_deg(a)))
		_cache["mesh:bone_bullet"] = b.build(null)
	var n = _solid(_cache["mesh:bone_bullet"], 0.014, 1.2)
	n.scale = Vector3.ONE * 1.25
	return n


static func _bone_dust(pj: Node, pr: Node3D) -> void:
	_spray(pj, Vector3.ZERO, {"one": false, "parent": pr, "n": 14, "life": 0.25, "r": 0.08, "dir": UP, "spread": 180.0, "v0": 0.2, "v1": 0.8,
		"grav": 0.0, "s0": 0.03, "s1": 0.06, "col": Color(0.95, 0.94, 0.9)})


static func _bone_muzzle(pj: Node, at: Vector3, dir: Vector3) -> void:
	_spray(pj, at, {"n": 8, "life": 0.3, "r": 0.05, "dir": dir, "spread": 35.0, "v0": 2.0, "v1": 5.0, "grav": 6.0, "s0": 0.025, "s1": 0.05, "col": BONE})
	_pop(pj, 7, at + dir * 0.15, Vector2(0.45, 0.45), 0.06, 0.0, 0.08, {"c1": Color(1, 1, 1), "c2": BONE_S, "c3": INK, "nf": 1.0})


static func _bone_shatter(pj: Node, pos: Vector3) -> void:
	_pop(pj, 7, pos, Vector2(0.9, 0.9), 0.08, 0.02, 0.1, {"c1": Color(1, 1, 1), "c2": BONE, "c3": INK, "nf": 1.5})
	_spray(pj, pos, {"n": 9, "life": 0.6, "r": 0.1, "dir": UP, "spread": 120.0, "v0": 3.0, "v1": 7.0, "grav": 14.0,
		"s0": 0.06, "s1": 0.12, "col": BONE, "mesh": _shard_mesh(), "spin": 12.0})
	_puff(pj, pos, 0.35, UP * 0.6, 0.4, [BONE, BONE_S, Color(0.35, 0.34, 0.36)], {"grow": 1.8, "a": 0.8, "nf": 1.5})


# ================================================================== Mercan (Yagura)
## Mercan modeli (yükseklik 1): style 0 çalı (kısa gövde, çok çatallı yelpaze), 1 ağaç (kalın gövde, geyik boynuzu çatalları),
## 2 mızrak (kalın sivri gövde, kısa yumrular). Ref: somon pembesi dallar, uçları açık, koyu gölge
static func _coral_mesh(style: int, variant: int) -> ArrayMesh:
	var key = "mesh:coral_%d_%d" % [style, variant]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 9100 + style * 37 + variant * 11
	var b = MB.new()
	if style == 0:
		for s in 3:
			var a = rng.randf() * TAU + s * 2.1
			var o = Vector3(cos(a), 0, sin(a))
			_coral_branch(b, rng, o * 0.05, (UP + o * 0.35).normalized(), 0.3, 0.05, 3, style)
	elif style == 1:
		_coral_branch(b, rng, Vector3.ZERO, UP, 0.32, 0.075, 4, style)
	else:
		_coral_spear(b, rng)
	var mesh = b.build(null)
	_cache[key] = mesh
	return mesh


static func _coral_branch(b: MB, rng: RandomNumberGenerator, base: Vector3, dir: Vector3, L: float, r: float, depth: int, style: int) -> void:
	var pts = [base]
	var rad = [r]
	var d = dir.normalized()
	var bend = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * 0.16
	var p = base
	for k in 3:
		d = (d + bend + UP * 0.1).normalized()
		p += d * L / 3.0
		pts.append(p)
		rad.append(lerpf(r, r * 0.7, float(k + 1) / 3.0))
	var tip = depth == 0
	if tip:
		rad[3] = r * 0.42
	var dk = depth
	var cf = func(u: float, _a: float, _n: Vector3) -> Color:
		var lv = clampf((4.0 - float(dk) + u) / 4.0, 0.0, 1.0)
		var col = CORAL_D.lerp(CORAL, lv)
		if tip and u > 0.55:
			col = col.lerp(CORAL_T, (u - 0.55) / 0.45)
		return col
	Loft.tube(b, pts, rad, CORAL, 7, 2, true, tip, cf)
	if depth <= 0:
		return
	var nb = 2 if style == 0 else (3 if rng.randf() < 0.35 else 2)
	for q in nb:
		var rv = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		var ax = d.cross(rv)
		if ax.length() < 0.05:
			ax = d.cross(Vector3.RIGHT)
		ax = ax.normalized()
		var ang = deg_to_rad(rng.randf_range(22.0, 40.0)) * (1.0 if q % 2 == 0 else -1.0)
		var nd = (d.rotated(ax, ang) + UP * 0.22).normalized()
		_coral_branch(b, rng, p, nd, L * 0.8, r * 0.72, depth - 1, style)


static func _coral_spear(b: MB, rng: RandomNumberGenerator) -> void:
	var lean = Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
	var pts = []
	var rad = []
	for k in 6:
		var u = k / 5.0
		pts.append(UP * u + lean * u * u + Vector3(sin(u * 5.0 + rng.randf()) * 0.02, 0, 0))
		rad.append(lerpf(0.11, 0.012, pow(u, 0.8)))
	var cf = func(u: float, _a: float, _n: Vector3) -> Color:
		return CORAL_D.lerp(CORAL, clampf(u * 1.4, 0.0, 1.0)).lerp(CORAL_T, clampf((u - 0.75) * 4.0, 0.0, 1.0))
	Loft.tube(b, pts, rad, CORAL, 8, 2, true, true, cf)
	for k in 4:   # kısa yumru dallar
		var u = 0.22 + k * 0.15
		var bp = UP * u + lean * u * u
		var a = rng.randf() * TAU
		var o = Vector3(cos(a), 0, sin(a))
		var kcf = func(uu: float, _a2: float, _n2: Vector3) -> Color:
			return CORAL.lerp(CORAL_T, uu)
		Loft.tube(b, [bp, bp + o * 0.08 + UP * 0.06, bp + o * 0.12 + UP * 0.15], [0.035, 0.022, 0.008], CORAL, 6, 2, false, true, kcf)


## Yerden mercan fışkırır: büyür (dibinde köpük kabarır), dur sn durur, batar
static func _coral_up(pj: Node, at: Vector3, h: float, dur: float, delay: float, tilt: Vector3, style: int) -> void:
	var g = _gp(at)
	var co = _solid(_coral_mesh(style, randi() % 4), 0.02 / maxf(h, 0.5), 3.0)
	_add(pj, co, g - UP * 0.1)
	co.rotation = tilt + Vector3(0, randf() * TAU, 0)
	co.scale = Vector3(h * 0.4, h * 0.02, h * 0.4)
	co.visible = false
	var tw = co.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		co.visible = true
		_foam_spurt(pj, g, clampf(h * 0.35, 0.5, 1.6))
		_clods(pj, g, 4, 6.0, EARTH_C, 0.1))
	tw.tween_property(co, "scale", Vector3.ONE * h, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(co, "scale", Vector3(h * 0.4, h * 0.02, h * 0.4), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(co.queue_free)


## Mercanın dibinde kabaran deniz köpüğü (ref: beyaz-mavi köpük) + damlalar
static func _foam_spurt(pj: Node, at: Vector3, s: float) -> void:
	for k in 3:
		var dv = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
		_puff(pj, at + UP * 0.2 + dv * 0.2 * s, 0.55 * s, dv * 1.2 * s + UP * 1.6 * s, 0.5, FOAM_COLS, {"grow": 1.8, "nf": 3.0})
	_spray(pj, at + UP * 0.2, {"n": 8, "life": 0.6, "r": 0.2 * s, "dir": UP, "spread": 40.0, "v0": 3.0 * s, "v1": 6.0 * s, "grav": 14.0,
		"s0": 0.05, "s1": 0.1, "col": FOAM, "mesh": _drop_mesh()})


## Renshō sonu: yerde dışa yayılan köpük dalgası
static func _foam_ring(pj: Node, at: Vector3, r: float) -> void:
	for k in 14:
		var a = TAU * k / 14.0 + randf_range(-0.1, 0.1)
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, at + dv * 0.6 + UP * 0.35, randf_range(0.8, 1.05), dv * r * 2.6 + UP * 0.6, 0.7, FOAM_COLS, {"grow": 1.7, "nf": 4.0})
	_spray(pj, at + UP * 0.4, {"n": 26, "life": 0.8, "r": 0.8, "dir": UP, "spread": 70.0, "v0": 4.0, "v1": 9.0, "grav": 16.0,
		"s0": 0.06, "s1": 0.13, "col": FOAM, "mesh": _drop_mesh()})


## Shōgeki: hedefin altından dikine fışkıran köpük sütunu
static func _foam_geyser(pj: Node, at: Vector3) -> void:
	for k in 10:
		var dv = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)) * 0.6
		_puff(pj, at + UP * (0.3 + k * 0.15) + dv * 0.3, randf_range(0.7, 1.05), UP * randf_range(6.0, 12.0) + dv * 2.0, 0.7, FOAM_COLS, {"grow": 1.5, "nf": 4.0})
	_spray(pj, at + UP * 0.5, {"n": 28, "life": 1.1, "r": 0.5, "dir": UP, "spread": 18.0, "v0": 8.0, "v1": 13.0, "grav": 16.0,
		"s0": 0.07, "s1": 0.14, "col": FOAM, "mesh": _drop_mesh()})
	_light(pj, at + UP * 2.0, Color(0.85, 0.95, 1.0), 1.5, 6.0, 0.4)


const CRACK_PRM := {"c1": Color(0.12, 0.09, 0.07), "c2": Color(0.55, 0.47, 0.38), "alpha": 0.9, "nf": 2.0}


## Sango Renshō (ref: Yagura — sopasının ucunu yere vurur; yerden uzun bir mercan sırası yükselip rakibe ulaşır, ulaşınca
## altından iri mercan dikenleri saplanır). Görünüş: çalı mercan sırası köpükle yürür, sonunda mızrak mercanlar + köpük dalgası.
static func sango_rensho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.95)
	var id = "sango_rensho"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.6)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var start: Vector3 = c.global_position + d * 1.4
	var L = clampf(c.global_position.distance_to(tt.global_position) - 1.4, 4.0, 20.0) if tt else 12.0
	_decal(pj, 0, pj.gp(start), 1.0, 0.15, 1.6, 0.5, CRACK_PRM)
	_foam_spurt(pj, pj.gp(start), 1.0)
	Sfx.play("earth", c.global_position, 1.1)
	var n = int(L / 1.0)
	var sd = d.cross(Vector3.UP).normalized()
	for k in n:   # mercan sırası hedefe yürür
		var p = start + d * (k + 0.5) * (L / n) + sd * randf_range(-0.35, 0.35)
		_coral_up(pj, p, randf_range(1.0, 1.6), 0.6, k * 0.035, Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), 0)
		if k % 3 == 0:
			pj.after(k * 0.035, func():
				var cc = cw.get_ref()
				if cc != null and pj.live(cc):
					for e in pj.enemies_near(cc, pj.gp(p), 1.2):
						e.take_hit(pj.inf(cc, id, 0.15, {"knock": 1.0, "kind": "light", "hitstop": 0.0})))
	pj.after(n * 0.035 + 0.05, func():   # ulaşınca altından iri dikenler
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var at: Vector3 = pj.gp(x.global_position) if x != null and pj.live(x) else pj.gp(start + d * L)
		for k in 6:
			var a = TAU * k / 6.0
			var o = Vector3(cos(a), 0, sin(a))
			_coral_up(pj, at + o * 0.7, randf_range(3.2, 4.2), 0.9, k * 0.02, Vector3(-o.z, 0, o.x) * -0.35, 2)
		_coral_up(pj, at, 4.6, 0.9, 0.0, Vector3.ZERO, 2)
		_foam_ring(pj, at, 2.4)
		_clods(pj, at, 12, 9.0, CORAL_D, 0.14)
		_decal(pj, 0, at, 2.4, 0.2, 1.4, 0.6, CRACK_PRM)
		pj.shake(0.6)
		Sfx.play("th_bone", at, 0.8)
		pj.hit(cc, at + Vector3.UP, 2.4, pj.inf(cc, id, 2.6, {"knock": 3.0, "launch": 7.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.09})))


## Sango Shōgeki (ref: Yagura — elini yere koyar; rakibin altından mercan çıkıp onu havaya fırlatır). Görünüş: hedefin altında
## çatlak ve kaynayan köpük, sonra kalın geyik boynuzu mercan + dikine köpük sütunu.
static func sango_shogeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Sango Shōgeki: mercanın çıkacağı hedef yok", CORAL)
		return
	pj.busy(c, 0.7)
	var id = "sango_shogeki"
	pj._face(c, tt)
	pj.anim(c, "crouch", 1.8)
	var cw = weakref(c)
	var tw = weakref(tt)
	var at: Vector3 = pj.gp(tt.global_position)
	_decal(pj, 0, at, 1.3, 0.25, 2.0, 0.5, CRACK_PRM)
	for k in 3:   # hazırlık: çatlaktan köpük kaynar
		_later(pj, k * 0.09, func():
			var o = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			_puff(pj, at + o + UP * 0.15, 0.4, UP * 0.8, 0.4, FOAM_COLS, {"grow": 1.6, "nf": 3.0}))
	Sfx.play("earth", at, 1.0)
	pj.after(0.3, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var p: Vector3 = pj.gp(x.global_position) if x != null and pj.live(x) else at
		_coral_up(pj, p, 5.2, 0.8, 0.0, Vector3.ZERO, 1)
		for k in 4:
			var a = TAU * k / 4.0 + 0.4
			_coral_up(pj, p + Vector3(cos(a), 0, sin(a)) * 0.6, 2.6, 0.7, 0.03, Vector3(sin(a), 0, -cos(a)) * 0.4, 0)
		_foam_geyser(pj, p)
		_clods(pj, p, 12, 10.0, EARTH_C, 0.14)
		pj.shake(0.5)
		Sfx.play("th_bone", p, 0.9)
		for e in pj.enemies_near(cc, p, 1.8):
			e.take_hit(pj.inf(cc, id, 2.4, {"knock": 0.0, "launch": 15.0, "kind": "heavy", "hitstop": 0.08})))


# ================================================================== Shūjin Juin (Kagura)
## Shūjin Juin (ref: Kagura "Prisoner Cursed Seal" — tenin üstünde koyu kırmızı tomoe yayı + ortada iri tomoe). Avuçta mühür
## belirir, göğse basılınca tomoe'ler sırayla dağlanır; kaçmaya çalışınca mühür kızarıp kıvılcım saçar.
static func shujin_juin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 4.5)
	if tt == null:
		if c == Game.player:
			Hud.msg("Shūjin Juin: mühür basacak kadar yakın hedef yok", Color(0.75, 0.4, 0.9))
		return
	pj.busy(c, 0.8)
	var id = "shujin_juin"
	pj._face(c, tt)
	pj._jump_at(c, tt, 0.0, 9.0 if c.global_position.distance_to(tt.global_position) > 1.6 else 0.0)
	pj.anim(c, "jab", 1.6)
	_seal_palm(pj, c, 0.2)
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.2, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var DUR = 7.0
		pj.st(x, "sealed", DUR)
		pj.st(x, "slow", DUR)
		x.take_hit(pj.inf(cc, id, 0.6, {"knock": 1.0, "kind": "light", "hitstop": 0.06, "pierce_guard": true}))
		Combat.popup_text(x.global_position + Vector3.UP * 2.6, "Mahkûm mührü!", Color(0.75, 0.4, 0.9))
		Sfx.play("seal", x.global_position, 0.9)
		var mark = _seal_brand(pj, x, DUR)
		var p0 = {"p": x.global_position}
		var burn = func(i, _k):   # kaçmaya çalışırsa mühür yakar
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 == null or x2 == null or not pj.live(x2):
				return
			if i % 5 == 4:
				var moved = (x2.global_position - p0["p"]).length()
				p0["p"] = x2.global_position
				if moved > 1.2:
					x2.take_hit(pj.inf(c2, id, 0.25, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "pierce_guard": true}))
					_seal_sear(pj, x2, mark)
		pj.every(DUR, 0.1, burn))


static func _seal_palm(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var q = _flat(4, Vector2(0.38, 0.38), {"c1": SEAL_R, "c2": Color(1.0, 0.4, 0.35, 1.0), "prog": 0.0, "nf": 1.0}, 1.0)
	var ba = pj.bone_attach(c, "RightHand")
	if ba != null:
		ba.add_child(q)
		q.position = Vector3(0, 0.1, 0.06)
		pj.free_after(dur + 0.2, ba)
	else:
		_add(pj, q, pj.hand_pos(c))
		_kill_after(pj, q, dur + 0.2)
	_tp(q, "prog", 0.0, 1.0, dur)


## Göğse dağlanan mühür: kemiğe bağlı düz tomoe yayı + havada genişleyip sönen kızgın halka, koyu kırmızı kıvılcımlar
static func _seal_brand(pj: PathJutsu, x: Node3D, dur: float) -> MeshInstance3D:
	var holder: Node3D = pj.bone_attach(x, "Chest")
	if holder == null:
		holder = Node3D.new()
		x.add_child(holder)
		holder.position = UP * _h(x) * 0.72
	var q = _flat(4, Vector2(0.46, 0.46), {"c1": SEAL_R, "c2": Color(0, 0, 0, 0), "alpha": 1.0, "prog": 0.0, "nf": 1.2}, 0.0)
	holder.add_child(q)
	q.position = Vector3(0, 0.05, 0.17)
	_tp(q, "prog", 0.0, 1.0, 0.35)
	pj.free_after(dur, holder)
	var chest = x.global_position + UP * _h(x) * 0.72
	_pop(pj, 4, chest, Vector2(1.7, 1.7), 0.14, 0.05, 0.3, {"c1": SEAL_HOT, "c2": Color(0.9, 0.2, 0.25, 1.0), "alpha": 0.85, "nf": 2.0}, 1.0)
	_spray(pj, chest, {"n": 14, "life": 0.45, "r": 0.15, "dir": UP, "spread": 120.0, "v0": 1.5, "v1": 4.0, "grav": 3.0,
		"s0": 0.03, "s1": 0.06, "ramp": [SEAL_HOT, SEAL_R, Color(0.15, 0.02, 0.03)]})
	_light(pj, chest, Color(1.0, 0.3, 0.3), 1.6, 3.5, 0.35)
	return q


static func _seal_sear(pj: PathJutsu, x: Node3D, mark) -> void:
	if mark != null and is_instance_valid(mark):
		mark.set_instance_shader_parameter("c1", SEAL_HOT)
		var s0: Vector3 = mark.scale
		var tw = mark.create_tween()
		tw.tween_property(mark, "scale", s0 * 1.45, 0.06)
		tw.tween_property(mark, "scale", s0, 0.2)
		tw.tween_callback(func():
			if is_instance_valid(mark):
				mark.set_instance_shader_parameter("c1", SEAL_R))
	var chest = x.global_position + UP * _h(x) * 0.72
	_pop(pj, 7, chest, Vector2(0.8, 0.8), 0.07, 0.02, 0.12, {"c1": SEAL_HOT, "c2": SEAL_R, "c3": INK, "nf": 1.5})
	_spray(pj, chest, {"n": 10, "life": 0.4, "r": 0.12, "dir": UP, "spread": 90.0, "v0": 1.0, "v1": 3.0, "grav": 2.0,
		"s0": 0.03, "s1": 0.05, "ramp": [SEAL_HOT, SEAL_R]})


# ================================================================== Sōjasōsai (Anko / Orochimaru)
## Sōjasōsai: iki dev yılan seni ve hedefi sarar; canının yarısı karşılığında hedefe ölümcül darbe. Ref: benekli açık kahve iki dev
## yılan, sarmal halkalar. Görünüş: gerçek yılan modelleri (make_snake) sarmal tırmanır; ikinizin altında ikiz yılan mührü yazılır;
## darbe anında kızıl-kara yıldız, pul kıymıkları, yerde kan izi ve senden hedefe akan kan çekimi (bedel).
static func sojasosai_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	if tt == null:
		Hud.msg("Sōjasōsai: hedef en fazla 14 metrede olmalı", Color(0.85, 0.7, 1.0))
		return
	pj.busy(c, 1.6)
	if c is Player:
		c.combat.invuln = 1.6
	pj.st(tt, "bind", 1.6)
	_slowmo(pj, 0.35, 0.8)
	Sfx.play("genjutsu", c.global_position, 0.4)
	var cols = [SNAKE_TAN, SNAKE_TAN2]
	var who = [c, tt]
	for k in 2:
		var e: Node3D = who[k]
		var head = pj.make_snake(e.global_position + Vector3(2.5, 0.2, 0), cols[k], 1.4, 16)
		var center = e.global_position
		pj.every(1.4, 1.0 / 40.0, func(_i, kk):
			if not is_instance_valid(head) or not is_instance_valid(e):
				return
			var a = kk * TAU * 2.5 + k * PI
			head.global_position = center + Vector3(cos(a) * 1.6, 0.3 + kk * 3.0, sin(a) * 1.6)
			pj.toward(head, Vector3(-sin(a), 0.4, cos(a))), Callable())
		_shrink_free(head, 1.6, 0.2)
		_decal(pj, 5, pj.gp(center), 2.4 if k == 0 else 4.0, 0.6, 0.9, 0.4, {"c1": Color(0.1, 0.04, 0.05), "c2": Color(0.5, 0.08, 0.12), "alpha": 0.9, "nf": 2.0})
	pj.after(1.4, func():
		if not pj.live(tt):
			return
		var p = tt.global_position + Vector3.UP
		_sojasosai_strike(pj, c, tt, p)
		pj.shake(1.0)
		pj.hit(c, p, tt.radius + 1.0, pj.inf(c, "sojasosai_no_jutsu", 6.0, {"knock": 4.0, "kind": "heavy", "pierce_guard": true, "hitstop": 0.2}))
		if is_instance_valid(c):
			c.hp = maxf(1.0, c.hp * 0.5)
			Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Bedel: canının yarısı", Color(0.85, 0.55, 0.9)))


static func _sojasosai_strike(pj: PathJutsu, c: Node3D, tt: Node3D, p: Vector3) -> void:
	_pop(pj, 7, p, Vector2(2.6, 2.6), 0.1, 0.06, 0.25, {"c1": Color(1.0, 0.85, 0.8), "c2": BLOOD, "c3": INK, "nf": 3.0})
	_spray(pj, p, {"n": 26, "life": 0.8, "r": 0.4, "dir": UP, "spread": 160.0, "v0": 6.0, "v1": 12.0, "grav": 14.0,
		"s0": 0.08, "s1": 0.16, "mesh": _shard_mesh(), "spin": 10.0, "ramp": [SNAKE_TAN, SNAKE_TAN2, Color(0.3, 0.2, 0.12)]})
	_decal(pj, 6, pj.gp(tt.global_position), 2.0, 0.15, 1.6, 0.8, {"c1": Color(0.28, 0.02, 0.05), "alpha": 0.85, "nf": 2.0})
	_light(pj, p, Color(0.9, 0.2, 0.3), 2.6, 7.0, 0.5)
	if is_instance_valid(c):   # bedel: senden hedefe akan kan çekimi
		var a = c.global_position + UP * 1.1
		_arc_ribbon(pj, a, p, 1.2, 0.09, {"pat": 4.0, "c1": Color(0.85, 0.12, 0.18), "c2": BLOOD, "nf": 3.0}, 0.18, 0.5, 0.35)
		_spray(pj, a, {"n": 12, "life": 0.5, "r": 0.3, "dir": UP, "spread": 120.0, "v0": 0.8, "v1": 2.0, "grav": -1.0,
			"s0": 0.03, "s1": 0.06, "ramp": [Color(0.9, 0.15, 0.2), BLOOD]})


# ================================================================== Juin: Ni no Dankai
## 2. aşama: ten kararır, beden biçim değiştirir (JuinForms: her parça bedenin kendi kemiğinden); güç patlar, can hızla erir.
## Görünüş: ensede üç tomoe parlar, yerde kara-mor yarıklar, ayak çevresinden dışa yayılan lanet alevi dilleri, bedeni yalayan
## uzun dil sütunu; süre boyunca kemiklerden kara-mor alev dilleri tüter (bedenin kendi kemiklerine bağlı).
static func juin_ni_no_dankai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	if c.has_meta("fuja_until") and Time.get_ticks_msec() < int(c.get_meta("fuja_until")):   # Fūja Hōin bastırdı
		if c is Player:
			Hud.msg("Lanet mührü Fūja Hōin ile bastırılmış — şimdilik uyanmıyor.", Color(0.85, 0.3, 0.3))
		return
	var dur = 18.0
	pj.skin_marks(c, 5, "juin_marks", dur)
	var aura = _curse_aura(pj, c, dur)
	_slowmo(pj, 0.4, 0.5)
	pj.shake(0.8)
	Sfx.play("roar", c.global_position, 0.8)
	_curse_eruption(pj, c)
	# form: her kullanıcının mührü farklı uyanır (Sasuke tipi kanat, Tayuya tipi boynuz, Jirōbō tipi kaya deri, Kidōmaru tipi ek kollar)
	var form = "kanat"
	if c is Player:
		if not Game.profile.has("juin_form"):
			Game.profile["juin_form"] = ["kanat", "boynuz", "kaya", "orumcek"].pick_random()
		form = String(Game.profile["juin_form"])
	else:
		form = ["kanat", "boynuz", "kaya", "orumcek"][abs(c.get_instance_id()) % 4]
	var F = PathJutsu.JUIN_FORMS[form]
	var skin_mats = []
	var m = c.get("model")
	if m and is_instance_valid(m):
		var ratio: Color = m._skin_ratio()
		for sm in m.materials:
			if sm is ShaderMaterial:
				var tv = sm.get_shader_parameter("tint")
				if tv != null and tv is Color and tv == ratio:
					skin_mats.append(sm)
					sm.set_shader_parameter("tint", F["skin"])
	var built = preload("res://scripts/combat/juin_forms.gd").build(c, form, F["skin"])
	var wings: Array = built["nodes"]
	if c is Player:
		var mods: Dictionary = (F["mods"] as Dictionary).duplicate()
		mods["_name"] = "Lanetli Mühür II — %s" % F["name"]
		mods["_desc"] = F["desc"]
		Buffs.add("juin2", dur, mods)
		Buffs.remove("juin1")
		if form == "kanat":
			c.start_flight("juin", {"drain": 0.0, "speed": 18.0, "dur": dur})
		Hud.msg("İkinci aşama — %s! %s. Canın hızla eriyor!" % [F["name"], F["desc"]], Color(0.85, 0.55, 1.0))
	pj.every(dur, 1.0, func(_i, _k):
		if is_instance_valid(c) and c.hp > c.max_hp * 0.1:
			c.hp -= c.max_hp * 0.03, func():
		for a in aura:
			_stop_free(pj, a, 0.8)
		for sm in skin_mats:
			if is_instance_valid(m):
				sm.set_shader_parameter("tint", m._skin_ratio())
		for w in wings:
			if is_instance_valid(w):
				w.queue_free()
		if (built["undo"] as Callable).is_valid():
			(built["undo"] as Callable).call()
		if c is Player and is_instance_valid(c) and c.flight_source() == "juin":
			c.stop_flight())


## Kemiklere bağlı lanet alevi dilleri (süre boyunca tüter)
static func _curse_aura(pj: PathJutsu, c: Node3D, dur: float) -> Array:
	var out = []
	for bone in ["Neck", "UpperChest", "LeftLowerArm", "RightLowerArm", "Hips"]:
		var ba = pj.bone_attach(c, bone)
		if ba == null:
			continue
		_spray(pj, Vector3.ZERO, {"one": false, "parent": ba, "n": 9 if bone == "Neck" else 6, "life": 0.55, "r": 0.12, "dir": UP,
			"spread": 25.0, "v0": 0.8, "v1": 1.6, "grav": -1.5, "s0": 0.07, "s1": 0.14, "mesh": _tongue_mesh(), "align": true,
			"ramp": [CURSE_L, CURSE, INK]})
		pj.free_after(dur + 1.5, ba)
		out.append(ba)
	return out


static func _curse_eruption(pj: PathJutsu, c: Node3D) -> void:
	var g = _gp(c.global_position)
	_decal(pj, 0, g, 5.5, 0.3, 1.6, 1.0, {"c1": INK, "c2": CURSE, "alpha": 0.9, "nf": 2.5})
	var neck = _bone_pos(c, "Neck", UP * 1.5)
	_pop(pj, 12, neck, Vector2(0.5, 0.5), 0.12, 0.25, 0.3, {"c1": INK, "c2": CURSE_L, "nf": 0.8}, 1.0)
	var tg_prm = {"pat": 3.0, "c1": INK, "c2": CURSE, "c3": CURSE_L, "alpha": 1.0, "reveal": 1.0, "tail": 0.0, "nf": 3.0}
	for k in 14:   # ayak çevresinden dışa yayılan alev dilleri
		var a = TAU * k / 14.0 + randf_range(-0.1, 0.1)
		var dv = Vector3(cos(a), 0, sin(a))
		var tn = _ribbon_node(_tongue_strip(), tg_prm)
		_params(tn, {"seed": randf() * 10.0})
		_add(pj, tn, g + dv * 0.9)
		tn.scale = Vector3(0.5, 1.8, 0.5)
		var tw = tn.create_tween().set_parallel(true)
		tw.tween_property(tn, "global_position", g + dv * 3.8, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(tn, "scale", Vector3(0.35, 0.4, 0.35), 0.6).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(tn.queue_free)
	for k in 8:   # bedeni yalayan uzun dil sütunu
		var a = TAU * k / 8.0
		var tn = _ribbon_node(_tongue_strip(), tg_prm)
		_params(tn, {"seed": randf() * 10.0})
		_add(pj, tn, g + Vector3(cos(a), 0, sin(a)) * 0.38)
		tn.scale = Vector3(0.45, 0.3, 0.45)
		var tw = tn.create_tween()
		tw.tween_property(tn, "scale", Vector3(0.45, 2.6, 0.45), 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(tn, "scale", Vector3(0.2, 0.2, 0.2), 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(tn.queue_free)
	_spray(pj, g + UP * 1.0, {"n": 30, "life": 0.7, "r": 0.5, "dir": UP, "spread": 70.0, "v0": 3.0, "v1": 7.0, "grav": -1.0,
		"s0": 0.08, "s1": 0.16, "mesh": _tongue_mesh(), "align": true, "ramp": [CURSE_L, CURSE, INK]})
	_light(pj, g + UP * 1.2, Color(0.6, 0.25, 0.9), 2.4, 8.0, 0.6)


# ================================================================== Momochi (Zabuza; Kubikiribōchō)
## Kubikiribōchō'nun geniş kesik hilali: a0/a1 eşitse baş üstünden önden yere inen dikey yay (omuz pivotlu), değilse
## yatay süpürme. İç kenar ince, dış kenar beyaz + koyu kontur; ikinci dar şerit her açıdan görünürlüğü korur
static func _cleaver_arc(pj: Node, c: Node3D, a0: float, a1: float, h0: float, h1: float, r: float, w: float, tone: Array) -> void:
	var f: Vector3 = _flatv(_fdir(c))
	var sd = f.cross(UP).normalized()
	var o: Vector3 = c.global_position
	var vertical = absf(a1 - a0) < 0.01
	var pts = []
	var mids = []
	var sides = []
	var ws = []
	var s2 = []
	var w2 = []
	var N = 22
	for k in N + 1:
		var u = float(k) / N
		var p: Vector3
		var rd: Vector3
		if vertical:
			var bb = lerpf(1.5, -0.45, u)
			rd = UP * sin(bb) + f * cos(bb)
			p = o + UP * 1.2 + rd * r * lerpf(1.0, 1.08, u)
		else:
			var a = lerpf(a0, a1, u)
			rd = f * cos(a) - sd * sin(a)
			p = o + UP * lerpf(h0, h1, u) + rd * r
		pts.append(p - rd * w * 0.5)
		mids.append(p - rd * w * 0.15)
		sides.append(rd)
		ws.append(w * 0.5)
		s2.append(sd if vertical else UP)
		w2.append(w * 0.16)
	var b = MB.new()
	_strip(b, pts, sides, ws)
	_strip(b, mids, s2, w2)
	var mi = _ribbon_node(b.build(null), {"pat": 0.0, "c1": tone[0], "c2": tone[1], "c3": tone[2], "alpha": 1.0, "reveal": 0.0, "tail": 0.0, "seed": randf() * 10.0, "nf": 2.0})
	_add(pj, mi, Vector3.ZERO)
	var tw = _tp(mi, "reveal", 0.0, 1.0, 0.09)
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("tail", v), 0.0, 1.0, 0.24)
	tw.tween_callback(mi.queue_free)


## Tekme / yumruk isabeti: kontürlü darbe yıldızı + hız çizgisi halkası + vuruş yönünde toz
static func _kick_burst(pj: Node, p: Vector3, f: Vector3, big: bool) -> void:
	var s = 2.0 if big else 1.3
	_pop(pj, 7, p, Vector2(s, s), 0.07, 0.03, 0.14, {"c1": Color(1, 1, 1), "c2": Color(1.0, 0.92, 0.7), "c3": INK, "nf": 2.0})
	_pop(pj, 11, p, Vector2(s * 1.5, s * 1.5), 0.18, 0.0, 0.12, {"c1": Color(1, 1, 1), "nf": 2.5})
	for k in 3:
		var dv = (f + Vector3(randf_range(-0.4, 0.4), randf_range(-0.1, 0.3), randf_range(-0.4, 0.4))).normalized()
		_puff(pj, p + dv * 0.3, 0.45, dv * 4.0, 0.45, DUST_COLS, {"grow": 1.8, "a": 0.85, "nf": 3.0})
	_spray(pj, p, {"n": 10, "life": 0.25, "r": 0.15, "dir": f, "spread": 30.0, "v0": 10.0, "v1": 16.0, "grav": 0.0,
		"s0": 0.025, "s1": 0.04, "col": Color(1, 1, 1), "align": true, "mesh": _shard_mesh()})


## Küçük isabet (dirsek, ilk tekme)
static func _tap_burst(pj: Node, p: Vector3) -> void:
	_pop(pj, 7, p, Vector2(0.9, 0.9), 0.06, 0.02, 0.1, {"c1": Color(1, 1, 1), "c2": Color(1.0, 0.9, 0.65), "c3": INK, "nf": 1.5})
	_puff(pj, p, 0.3, UP * 0.5, 0.35, DUST_COLS, {"grow": 1.8, "a": 0.8, "nf": 2.0})


## Dönerek tekmede ayak çevresinde dönen toz
static func _spin_dust(pj: Node, c: Node3D) -> void:
	var g = _gp(c.global_position)
	for k in 8:
		var a = TAU * k / 8.0
		var dv = Vector3(cos(a), 0, sin(a))
		var tn = Vector3(-dv.z, 0, dv.x)
		_puff(pj, g + dv * 0.7 + UP * 0.25, 0.45, tn * 3.5 + dv * 1.0, 0.5, DUST_COLS, {"grow": 1.6, "a": 0.8, "nf": 3.0})


## Ryūbikyaku (ref: Zabuza — rakibi yatay biçer, ardından dönerek tekmeyle savurur)
static func ryubikyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 1.35)
	var id = "ryubikyaku"
	pj._jump_at(c, tt, 0.0, 10.0 if tt and tt.global_position.distance_to(c.global_position) > 2.6 else 1.5)
	var cw = weakref(c)
	var h = pj._kubi_step(c, 1, 1.25)
	pj.after(h, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		_cleaver_arc(pj, cc, -1.5, 1.5, 1.2, 1.25, 2.7, 0.8, STEEL_ARC)
		Sfx.play("swing_heavy", cc.global_position, 0.9)
		Combat.hit_zone(cc, pj.gp(cc.global_position), cc.face_dir(), 3.3, 75.0, 2.4, pj.inf(cc, id, 1.9, {"knock": 2.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.09})))
	pj.after(h + 0.3, func():   # gövde dönerek tekme
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc.get("model"):
			var mt = cc.model.create_tween()
			mt.tween_property(cc.model, "rotation:y", TAU, 0.22).from(0.0)
			mt.tween_callback(func(): cc.model.rotation.y = 0.0)
		pj._kick_pose(cc, 0.3)
		_spin_dust(pj, cc))
	pj.after(h + 0.46, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var f: Vector3 = cc.face_dir()
		var p = cc.global_position + Vector3.UP * 1.1 + f * 1.3
		pj.shake(0.5)
		Sfx.play("punch", p, 0.7)
		var hs = pj.hit(cc, p, 2.2, pj.inf(cc, id, 1.5, {"knock": 22.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.1, "dir": f}))
		_kick_burst(pj, p, f, not hs.is_empty()))


## Jikoku (ref: Zabuza — tekme, Kubikiribōchō ile art arda kesikler, dirsek ve yumruk; güçlü bir aşağı biçmeyle rakibi geri savurur).
## Sonda baş üstünden inen dikey yay yerde boyuna bir yarık açar; yarığın iki yanından toz duvarı kalkar.
static func jikoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 2.75)
	var id = "jikoku"
	pj._jump_at(c, tt, 0.0, 10.0 if tt and tt.global_position.distance_to(c.global_position) > 2.2 else 1.5)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	pj._kick_pose(c, 0.25)
	pj.after(0.16, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		Sfx.play("punch", cc.global_position, 1.0)
		var p = cc.global_position + Vector3.UP * 1.0 + cc.face_dir() * 1.2
		var hs = pj.hit(cc, p, 2.0, pj.inf(cc, id, 0.4, {"knock": 1.0, "kind": "light", "hitstop": 0.04, "stun": 0.5}))
		if not hs.is_empty():
			_tap_burst(pj, p))
	var close = func(cc: Node3D) -> void:
		var x = tw.get_ref() if tw else null
		if x != null and pj.live(x):
			pj._face(cc, x)
			if cc is CharacterBody3D:
				cc.velocity = cc.face_dir() * clampf((cc.global_position.distance_to(x.global_position) - 1.4) / 0.2, 0.0, 12.0)
	pj.after(0.3, func():   # dönen çift biçme (iki vuruş)
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		close.call(cc)
		var hh = pj._kubi_step(cc, 3, 1.3)
		for q in 2:
			pj.after(hh + q * 0.42, func():
				var c2 = cw.get_ref()
				if c2 == null or not pj.live(c2):
					return
				_cleaver_arc(pj, c2, 1.7 - q * 3.4, -1.7 + q * 3.4, 1.0, 1.1, 2.6, 0.7, STEEL_ARC)
				Sfx.play("swing_heavy", c2.global_position, 1.0)
				Combat.hit_zone(c2, pj.gp(c2.global_position), c2.face_dir(), 3.2, 80.0, 2.6, pj.inf(c2, id, 0.55, {"knock": 1.5, "kind": "heavy", "bleed": 3.0, "hitstop": 0.05}))))
	for q in 2:   # dirsek, yumruk (boş sol el)
		pj.after(1.35 + q * 0.2, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			close.call(cc)
			pj.anim(cc, "hook" if q == 0 else "jab", 2.2)
			var p = cc.global_position + Vector3.UP * 1.2 + cc.face_dir() * 1.1
			Sfx.play("punch", p, 1.1 - q * 0.1)
			var hs = pj.hit(cc, p, 1.9, pj.inf(cc, id, 0.4, {"knock": 1.0, "kind": "light", "hitstop": 0.04}))
			if not hs.is_empty():
				_tap_burst(pj, p))
	pj.after(1.85, func():   # baş üstünden ağır iniş
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		close.call(cc)
		var hh = pj._kubi_step(cc, 5, 1.25)
		pj.after(hh, func():
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			var f: Vector3 = c2.face_dir()
			var at: Vector3 = pj.gp(c2.global_position + f * 2.2)
			_cleaver_arc(pj, c2, 0.0, 0.0, 3.0, 0.2, 2.2, 0.75, STEEL_ARC)
			_fissure(pj, pj.gp(c2.global_position + f * 0.9), f, 6.0)
			pj.shake(0.7)
			Sfx.play("boom", at, 1.0)
			Combat.hit_zone(c2, pj.gp(c2.global_position), f, 3.6, 35.0, 3.0, pj.inf(c2, id, 1.7, {"knock": 24.0, "launch": 2.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.12, "dir": f}))))


## Boyuna yer yarığı: çizilerek uzar, boyunca topaklar fırlar, iki yanından toz duvarı yana açılır
static func _fissure(pj: Node, from: Vector3, f: Vector3, L: float) -> void:
	var fd = _flatv(f)
	var sd = fd.cross(UP).normalized()
	_decal_line(pj, 3, from, fd, L, 1.5, 0.18, 1.6, 0.8, {"c1": Color(0.1, 0.08, 0.06), "c2": Color(0.5, 0.42, 0.33), "alpha": 0.95, "nf": 2.0})
	for k in 6:
		var q = _gp(from + fd * (k + 0.5) * L / 6.0)
		_later(pj, k * 0.03, func():
			_clods(pj, q, 5, 7.0, EARTH_C, 0.12)
			for s in [-1.0, 1.0]:
				_puff(pj, q + sd * s * 0.3 + UP * 0.3, 0.55, sd * s * 3.2 + UP * 1.2, 0.6, DUST_COLS, {"grow": 1.7, "nf": 3.0}))


## Dankoku krater kenarından kalkan kaya levhası
static func _slab_mesh(v: int) -> ArrayMesh:
	var key = "mesh:slab_%d" % v
	if not _cache.has(key):
		var b = MB.new()
		b.add_grad("crag", Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.35), Color(0.6, 0.52, 0.42), Color(0.36, 0.3, 0.24), Vector3(0, 0, 0), v)
		_cache[key] = b.build(null)
	return _cache[key]


static func _slab_up(pj: Node, at: Vector3, out_dir: Vector3, s: float, delay: float, hold: float) -> void:
	var sl = _solid(_slab_mesh(randi() % 4 + 1), 0.03 / maxf(s, 0.4), 3.0)
	_add(pj, sl, _gp(at) - UP * 0.15)
	var yaw = atan2(out_dir.x, out_dir.z)
	sl.rotation = Vector3(0, yaw, 0)
	sl.scale = Vector3(s, 0.02, s)
	sl.visible = false
	var tilt = Vector3(deg_to_rad(randf_range(25.0, 50.0)), yaw, randf_range(-0.2, 0.2))
	var tw = sl.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): sl.visible = true)
	tw.tween_property(sl, "scale", Vector3.ONE * s, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sl, "rotation", tilt, 0.12)
	tw.tween_interval(hold)
	tw.tween_property(sl, "scale", Vector3(s, 0.02, s), 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(sl.queue_free)


## Dankoku (ref: Zabuza / Jūzō — Kubikiribōchō'yla rakibin önüne sıçrar ve kılıcı üstüne indirir; altındaki zemin ezilir).
## Sıçrayışta ayak altından toz halkası; inişte dikey dev yay, krater, kenarından ve yarık boyunca kalkan kaya levhaları,
## dışa yuvarlanan büyük toz halkası.
static func dankoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.6)
	var id = "dankoku"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var L = c.global_position.distance_to(tt.global_position) - 1.8 if tt else 6.0
	if c is CharacterBody3D:
		c.velocity = d * clampf(L / 0.62, 0.0, 22.0) + Vector3.UP * 9.0   # sıçrayış
	_leap_dust(pj, pj.gp(c.global_position))
	Sfx.play("leap", c.global_position, 0.9)
	var hh = pj._kubi_step(c, 5, 1.1)
	pj.after(minf(hh, 0.8), func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		if x != null and pj.live(x):
			pj._face(cc, x)
		if cc is CharacterBody3D:
			cc.velocity = Vector3.DOWN * 18.0
		var f: Vector3 = cc.face_dir()
		var at: Vector3 = pj.gp(cc.global_position + f * 2.3)
		_cleaver_arc(pj, cc, 0.0, 0.0, 3.4, 0.1, 2.3, 0.95, STEEL_ARC)
		_crater(pj, at, f)
		pj.shake(1.0)
		Sfx.play("boom", at, 0.7)
		var hz = Combat.hit_zone(cc, pj.gp(cc.global_position), f, 4.2, 30.0, 3.4, pj.inf(cc, id, 2.8, {"knock": 6.0, "launch": 2.5, "kind": "heavy", "stun": 1.0, "bleed": 4.0, "hitstop": 0.14}))
		for e in pj.enemies_near(cc, at, 3.4):   # ezilen zemin çevreyi de sarsar
			if e in hz:
				continue
			e.take_hit(pj.inf(cc, id, 0.6, {"knock": 8.0, "launch": 3.0, "kind": "heavy"})))


static func _leap_dust(pj: Node, g: Vector3) -> void:
	for k in 10:
		var a = TAU * k / 10.0
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + dv * 0.4 + UP * 0.2, 0.5, dv * 4.0 + UP * 0.3, 0.5, DUST_COLS, {"grow": 1.8, "nf": 3.0})
	_clods(pj, g, 6, 5.0, EARTH_C, 0.1)


static func _crater(pj: Node, at: Vector3, f: Vector3) -> void:
	var fd = _flatv(f)
	_decal(pj, 2, at, 3.5, 0.15, 2.4, 1.0, {"c1": Color(0.16, 0.12, 0.09), "c2": Color(0.42, 0.35, 0.27), "c3": Color(0.08, 0.06, 0.05), "alpha": 0.95, "nf": 2.0})
	for k in 8:   # krater kenarından dışa yatan levhalar
		var a = TAU * k / 8.0 + randf_range(-0.15, 0.15)
		var dv = Vector3(cos(a), 0, sin(a))
		_slab_up(pj, at + dv * randf_range(1.3, 1.8), dv, randf_range(0.9, 1.4), 0.0, 1.2)
	for k in 6:   # kılıcın açtığı yarık boyunca kalkan levhalar
		var q = at + fd * (k - 1) * 0.8 + fd.cross(UP) * randf_range(-0.3, 0.3)
		_slab_up(pj, q, fd, randf_range(0.6, 0.9), k * 0.04, 1.0)
	for k in 14:   # dışa yuvarlanan büyük toz halkası
		var a = TAU * k / 14.0
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, at + dv * 1.4 + UP * 0.4, randf_range(1.0, 1.3), dv * 7.0 + UP * 0.6, 0.85, DUST_COLS, {"grow": 1.9, "nf": 4.0})
	_clods(pj, at, 24, 12.0, EARTH_C, 0.16)


# ================================================================== Nara: Kagemane Shuriken
## Gölge Taklit Shuriken (ref: yere saplanan bıçak ve gölgesi): kontürlü koyu şuriken döner; altında yerde onunla kayan kara
## şuriken gölgesi (ikinci, saklı şuriken). Değince gölge hedefin ayağına saplanır, gölge göletine açılır ve senin gölgen ona bağlanır.
static func kagemane_shuriken_no_jutsu(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	var d = (tt.global_position + Vector3.UP - Jutsu._hand(c)).normalized() if tt else Jutsu._aim(c, t)
	var star = _kage_shuriken()
	var shade = _flat(10, Vector2(0.95, 0.95), {"c1": SHADOW, "alpha": 0.9, "nf": 1.0}, 0.0)
	_add(pj, shade, pj.gp(Jutsu._hand(c)) + UP * 0.04)
	shade.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_kill_after(pj, shade, 2.6)
	var pr = pj.shot(c, Jutsu._hand(c), d, 38.0, star, pj.inf(c, "kagemane_shuriken_no_jutsu", 0.6), tt, false, 1.6, func(pos, target):
		_shadow_pin(pj, target, pos, shade)
		if pj.live(target):
			_shadow_bind_line(pj, c, target, 3.0)
			pj.st(target, "bind", 3.0)
			Combat.popup_text(target.global_position + Vector3.UP * 2.4, "Gölge bağlandı!", Color(0.65, 0.6, 0.85)))
	pr.spin = Vector3(0, 25.0, 0)
	pr.on_tick = func(p: Node3D, _dt: float) -> void:
		if is_instance_valid(shade) and is_instance_valid(p):
			shade.global_position = pj.gp(p.global_position) + UP * 0.04
			shade.rotation.y = p.rotation.y
	Sfx.play("kunai", c.global_position)


static func _kage_shuriken() -> Node3D:
	if not _cache.has("mesh:kage_shuriken"):
		var b = MB.new()
		var steel = Color(0.36, 0.37, 0.42)
		var edge = Color(0.7, 0.72, 0.78)
		for k in 4:
			var a = k * 90.0
			var rr = deg_to_rad(a)
			var o = Vector3(cos(rr), 0, -sin(rr))
			b.add("box", o * 0.2, Vector3(0.36, 0.03, 0.1), steel, Vector3(0, a, 0))
			b.add("cone", o * 0.43, Vector3(0.1, 0.18, 0.03), edge, Vector3(0, a, -90), 4)
		b.add("cyl", Vector3.ZERO, Vector3(0.2, 0.04, 0.2), steel.darkened(0.2), Vector3.ZERO, 12)
		b.add("cyl", Vector3.ZERO, Vector3(0.07, 0.05, 0.07), INK, Vector3.ZERO, 8)
		_cache["mesh:kage_shuriken"] = b.build(null)
	var n = _solid(_cache["mesh:kage_shuriken"], 0.012, 1.2)
	n.scale = Vector3.ONE * 1.3
	return n


## Mermi bitince yerdeki gölge şurikeni hedefin ayağına saplanıp gölge göletine açılır (hedef yoksa söner)
static func _shadow_pin(pj: Node, target, pos: Vector3, shade) -> void:
	if shade == null or not is_instance_valid(shade):
		return
	var ok = target != null and is_instance_valid(target)
	var g = _gp(target.global_position if ok else pos)
	shade.global_position = g + UP * 0.04
	var tw = shade.create_tween()
	tw.tween_property(shade, "scale", Vector3(0.55, 0.55, 1.0), 0.06)
	tw.tween_interval(0.25)
	tw.tween_method(func(v: float):
		if is_instance_valid(shade):
			shade.set_instance_shader_parameter("alpha", v), 0.9, 0.0, 0.3)
	tw.tween_callback(shade.queue_free)
	if ok:
		_decal(pj, 6, g, 0.85, 0.25, 2.6, 0.3, {"c1": SHADOW, "alpha": 0.9, "nf": 1.5})


## Yerde gölge şeridi (uçlar fonksiyonla, her 0.05 sn yenilenir): kenarsız, parlamasız, sabit kıvrım; wob kalın şeritte kenar dalgası
static func _shadow_strip(pj: Node, a_fn: Callable, b_fn: Callable, dur: float, half_w: float, wob := 0.0, grow_t := 0.45) -> void:
	var mat = _shade_mat()
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.get_tree().current_scene.add_child(mi)
	var bend = randf_range(0.4, 0.9) * (1.0 if randf() < 0.5 else -1.0)
	var t0 = Time.get_ticks_msec() * 0.001
	var ph = randf() * TAU
	var upd = func():
		if not is_instance_valid(mi):
			return
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		var el = Time.get_ticks_msec() * 0.001 - t0
		var grow = ease(clampf(el / grow_t, 0.0, 1.0), 0.5)
		var full = maxf(0.2, Vector2(b.x - a.x, b.z - a.z).length())
		var fw = Vector3(b.x - a.x, 0, b.z - a.z).normalized() if full > 0.3 else Vector3.FORWARD
		var side = fw.cross(UP)
		var amp = bend * minf(1.2, full * 0.08)
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
		var n = 36
		for k in n + 1:
			var u = float(k) / n * grow
			var p = a + fw * full * u + side * amp * sin(u * TAU)
			p.y = Game.jutsu_floor(p.x, p.z) + 0.05
			var w = half_w * (1.0 + wob * 0.5 * sin(u * 23.0 + ph + el * 6.0))
			if grow < 0.99 and u > grow - 0.06:
				w *= 0.5
			im.surface_add_vertex(p + side * w)
			im.surface_add_vertex(p - side * w)
		im.surface_end()
	upd.call()
	var tw = mi.create_tween().set_loops(maxi(1, int(dur / 0.05)))
	tw.tween_interval(0.05)
	tw.tween_callback(upd)
	_kill_after(pj, mi, dur)


static func _shadow_bind_line(pj: Node, c: Node3D, target: Node3D, dur: float) -> void:
	var last = {"a": c.global_position, "b": target.global_position}
	var cw = weakref(c)
	var tw = weakref(target)
	_shadow_strip(pj, func():
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc):
			last["a"] = cc.global_position
		return last["a"], func():
		var x = tw.get_ref()
		if x != null and is_instance_valid(x):
			last["b"] = x.global_position
		return last["b"], dur, 0.36)


# ================================================================== Nara: Kage Onishibari
## Kage Onishibari no Jutsu (ref: Shikamaru, Storm — kalın, çok kollu gölge şeritleri hızla uzanır; küçük gölge eller bedeni
## baştan aşağı sarar, çapraz kara bantlar; sonra parmaklarıyla pencere kurup chakrayı sıkar: gölge ezer)
static func kage_onishibari_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, minf(24.0, Jutsu.shadow_reach()))
	if tt == null:
		if c == Game.player:
			Hud.msg("Kage Onishibari: gölgenin uzanacağı hedef yok", Color(0.8, 0.8, 0.9))
		return
	pj.busy(c, 2.1)
	var d = pj._face(c, tt)
	var side = d.cross(Vector3.UP)
	var last = {"a": c.global_position, "b": tt.global_position}
	var cw = weakref(c)
	var tw = weakref(tt)
	for k in 5:
		var off = (k - 2) * 0.45
		var a_fn = func():
			var cc = cw.get_ref()
			if cc != null and pj.live(cc):
				last["a"] = cc.global_position
			return last["a"] + side * off * 0.5
		var b_fn = func():
			var tb = tw.get_ref()
			if tb != null:
				last["b"] = tb.global_position
			return last["b"] + side * off * 0.35
		_shadow_strip(pj, a_fn, b_fn, 2.2, 0.26 if k == 2 else 0.2, 0.35, 0.3 + absf(k - 2) * 0.05)
	_decal(pj, 6, pj.gp(tt.global_position), 1.5, 0.35, 1.7, 0.3, {"c1": SHADOW, "alpha": 0.9, "nf": 1.5})
	Sfx.play("genjutsu", c.global_position, 0.5)
	var grip = {"n": null}
	var wrap = func():
		var x = tw.get_ref()
		if x == null or not pj.live(x):
			return
		pj.st(x, "bind", 2.2)
		grip["n"] = _onishi_grip(pj, x, 2.0)
		Combat.popup_text(x.global_position + Vector3.UP * 2.6, "Gölge elleri sardı!", Color(0.65, 0.6, 0.85))
	pj.after(0.3, wrap)
	var crush = func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		pj._yama_seal(cc)   # iki el öne: parmak penceresi
		var o = x.global_position + Vector3.UP * 1.0
		_onishi_crush(pj, x, grip["n"])
		x.take_hit(pj.inf(cc, "kage_onishibari_no_jutsu", 2.6, {"knock": 0.0, "kind": "heavy", "hitstop": 0.16, "stun": 0.8}))
		pj.shake(0.6)
		Sfx.play("hit_heavy", o, 0.6)
	pj.after(1.75, crush)


## Hedefin gölgesinden kalkan yedi gölge kol (ucu bedeni kavrayan el: avuç + dört parmak) + üç çapraz kara bant
static func _onishi_grip(pj: Node, x: Node3D, dur: float) -> Node3D:
	var root = Node3D.new()
	_add(pj, root, x.global_position)
	var mat = _ink_mat()
	var H = clampf(_h(x), 1.2, 1.8)
	var R = 0.3
	for k in 7:
		var ang = k * TAU / 7.0 + randf_range(-0.25, 0.25)
		var hy = H * lerpf(0.3, 0.85, float((k * 3) % 7) / 6.0)
		var ov = Vector3(cos(ang), 0, sin(ang))
		var tv = Vector3(-sin(ang), 0, cos(ang))
		var g = ov * R + UP * hy
		var b = MB.new()
		var base = ov * randf_range(0.9, 1.3)
		Loft.tube(b, [base, base * 0.75 + UP * hy * 0.35 + tv * 0.15, ov * (R + 0.18) + UP * (hy - 0.12), ov * (R + 0.06) + UP * hy],
			[Vector2(0.09, 0.07), Vector2(0.07, 0.06), Vector2(0.055, 0.05), Vector2(0.05, 0.045)], Color.WHITE, 7, 2, false, false)
		b.add_xf("sphere", Transform3D(Basis(tv, UP, -ov) * Basis.from_scale(Vector3(0.13, 0.15, 0.05)), g + ov * 0.03), Color.WHITE, 8)
		var spin = 1.0 if k % 2 == 0 else -1.0
		for fg in 4:   # parmaklar bedenin çevresine sarılır
			var fy = hy + (fg - 1.5) * 0.04 + 0.02
			var fp = []
			for s in 4:
				var aa = ang + spin * (0.08 + s * 0.17)
				var rr = R + 0.02 - s * 0.005
				fp.append(Vector3(cos(aa) * rr, fy - s * 0.01, sin(aa) * rr))
			Loft.tube(b, fp, [Vector2(0.024, 0.02), Vector2(0.022, 0.018), Vector2(0.02, 0.016), Vector2(0.01, 0.008)], Color.WHITE, 5, 1, true, true)
		var mi = MeshInstance3D.new()
		mi.mesh = b.build(null)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.scale = Vector3(1, 0.02, 1)
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.04)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for q in 3:   # çapraz kara bantlar bedeni sıkar (gevşekten sıkıya)
		var tilt = deg_to_rad([24.0, -28.0, 12.0][q])
		var yc = H * [0.55, 0.7, 0.4][q]
		var a0 = randf() * TAU
		var pts = []
		var rr = []
		for s in 25:
			var aa = a0 + s * TAU / 24.0
			pts.append(Vector3(cos(aa) * 0.36, yc + sin(aa) * tan(tilt) * 0.36, sin(aa) * 0.36))
			rr.append(Vector2(0.014, 0.075))
		var bb = MB.new()
		Loft.tube(bb, pts, rr, Color.WHITE, 6, 1, false, false)
		var bm = MeshInstance3D.new()
		bm.mesh = bb.build(null)
		bm.material_override = mat
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bm)
		bm.visible = false
		bm.scale = Vector3(1.5, 1.0, 1.5)
		var tw2 = bm.create_tween()
		tw2.tween_interval(0.35 + q * 0.12)
		tw2.tween_callback(func(): bm.visible = true)
		tw2.tween_property(bm, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT)
	var xw = weakref(x)
	var ft = root.create_tween().set_loops(maxi(1, int(dur / 0.05)))
	ft.tween_interval(0.05)
	ft.tween_callback(func():
		var xx = xw.get_ref()
		if xx != null and is_instance_valid(xx):
			root.global_position = xx.global_position)
	_later(pj, dur, func():
		if not is_instance_valid(root):
			return
		var st = root.create_tween()
		st.tween_property(root, "scale", Vector3(1, 0.02, 1), 0.3).set_ease(Tween.EASE_IN)
		st.tween_callback(root.queue_free))
	return root


## Sıkış: eller içe kapanır, kara mürekkep damlaları bedene çöker, kara darbe yıldızı, gölgede halka
static func _onishi_crush(pj: Node, x: Node3D, grip) -> void:
	var o = x.global_position + UP * 1.0
	if grip is Node3D and is_instance_valid(grip):
		var tw = grip.create_tween()
		tw.tween_property(grip, "scale", Vector3(0.82, 1.0, 0.82), 0.08)
		tw.tween_property(grip, "scale", Vector3(0.9, 1.0, 0.9), 0.15)
	_spray(pj, o, {"n": 22, "life": 0.45, "r": 0.95, "dir": UP, "spread": 180.0, "v0": -5.0, "v1": -2.0, "grav": 0.0,
		"s0": 0.05, "s1": 0.11, "col": INK, "mesh": _drop_mesh()})
	_pop(pj, 7, o, Vector2(1.6, 1.6), 0.08, 0.05, 0.18, {"c1": Color(0.14, 0.1, 0.18), "c2": INK, "c3": Color(0.55, 0.5, 0.7), "nf": 2.0})
	_decal(pj, 6, _gp(x.global_position), 2.2, 0.1, 0.4, 0.35, {"c1": SHADOW, "alpha": 0.9, "nf": 1.5})


# ================================================================== Yamata no Jutsu
## Yamata no Jutsu: sekiz başlı dev yılana dönüşürsün; başlar ayrı ayrı 40 m'ye kadar dalar, sen gövdeyle yürürsün.
## Ref (Eight Branches): beyaz dikenli yeleli başlar molozdan ve bej toz bulutundan yükselir. Görünüş: gerçek Yamata başı +
## yılan gövdesi; doğuşta yerde yarık, çevrede kontürlü moloz kayaları ve bej toz halkası; her baş indiği yerde toz, çatlak,
## toprak kaldırır; sonda gövde toza gömülür.
static func yamata_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var dur = 16.0
	var m = c.get("model")
	_slowmo(pj, 0.4, 0.6)
	pj.shake(1.2)
	Sfx.play("roar", c.global_position, 0.5)
	if m:
		m.visible = false
	if c is Player:
		Buffs.add("yamata", dur, {"armor": 0.7, "speed": 0.85})
		# dev beden: kamera geri çekilip yükselir (kamera gövdenin içinde kalıyordu)
		var cd0 = c.cam_dist
		c.cam_dist = 26.0
		pj.after(dur, func():
			if is_instance_valid(c):
				c.cam_dist = cd0)
	var col = Color(0.9, 0.9, 0.88)   # anime: beyaz pullu sekiz başlı yılan (mor değil)
	var mound = MB.new()
	mound.add_grad("sphere", Vector3(0, 1.5, 0), Vector3(9.0, 5.0, 10.0), col.lightened(0.1), col.darkened(0.3), Vector3.ZERO, 14)
	for k in 6:
		mound.add_grad("sphere", Vector3(cos(k) * 4.0, 0.8, sin(k) * 4.5), Vector3(4.0, 2.4, 5.0), col, col.darkened(0.35), Vector3(0, k * 50, 0), 10)
	var body = MeshInstance3D.new()
	body.mesh = mound.build(Props.toon())
	var bol = _mi(body.mesh, _mat("outline", OUTLINE_SHADER))
	_params(bol, {"ow": 0.08, "nf": 4.0, "alpha": 1.0, "seed": randf() * 10.0})
	body.add_child(bol)
	_add(pj, body, c.global_position)
	_yamata_rise(pj, c.global_position)
	var heads = []
	for k in 8:
		var ang = TAU * k / 8.0
		var h = Node3D.new()
		pj.scene_add(h, c.global_position + Vector3.UP * 3.0)
		h.add_child(pj.yamata_head(3.4))
		var sb = VfxSerpent.new()
		sb.thin = 0.95
		sb.head = h
		sb.count = 18
		sb.spacing = 0.42 * 2.6
		sb.radius = 0.4 * 2.6
		sb.mat = Props.toon_color(col)
		sb.spines = pj.spine_mesh()
		pj.get_tree().current_scene.add_child(sb)
		heads.append({"n": h, "ang": ang, "cd": 0.6 + k * 0.22, "busy": 0.0, "y": randf_range(9.0, 14.0)})
	var tick = func(_i, _k):
		if not is_instance_valid(c):
			return
		if is_instance_valid(body):
			body.global_position = c.global_position
		for hd in heads:
			var h: Node3D = hd["n"]
			if not is_instance_valid(h):
				continue
			hd["cd"] -= 1.0 / 30.0
			if hd["busy"] > 0.0:
				hd["busy"] -= 1.0 / 30.0
				continue
			var tt = Time.get_ticks_msec() * 0.001
			var rest = c.global_position + Vector3(cos(hd["ang"] + sin(tt * 0.7) * 0.2) * 6.0, hd["y"] + sin(tt * 1.3 + hd["ang"]) * 0.8, sin(hd["ang"] + sin(tt * 0.7) * 0.2) * 6.0)
			h.global_position = h.global_position.lerp(rest, 0.12)
			pj.toward(h, (rest - c.global_position).normalized() + Vector3.DOWN * 0.3)
			if hd["cd"] <= 0.0:
				var near = pj.enemies_near(c, c.global_position, 40.0)
				if not near.is_empty():
					var e = near[randi() % near.size()]
					hd["cd"] = randf_range(1.4, 2.2)
					hd["busy"] = 0.75
					var from = h.global_position
					var to = e.global_position + Vector3.UP * e.height * 0.5
					pj.slither(h, from, to, 0.28, 1.0, func():
						if pj.live(e):
							pj.hit(c, e.global_position + Vector3.UP, e.radius + 2.2, pj.inf(c, "yamata_no_jutsu", 1.1, {"knock": 14.0, "launch": 7.0, "kind": "heavy", "burn": 3.0, "hitstop": 0.08}))
							_yamata_slam(pj, pj.gp(e.global_position))
							pj.shake(0.35))
	pj.every(dur, 1.0 / 30.0, tick, func():
		for hd in heads:
			if is_instance_valid(hd["n"]):
				hd["n"].queue_free()
		if is_instance_valid(body):
			_shrink_free(body, 0.0, 0.5)
		if m and is_instance_valid(m):
			m.visible = true
		if is_instance_valid(c):
			_yamata_collapse(pj, c.global_position))


static func _rubble_mesh(v: int) -> ArrayMesh:
	var key = "mesh:rubble_%d" % v
	if not _cache.has(key):
		var b = MB.new()
		b.add_grad("boulder", Vector3(0, 0.35, 0), Vector3(1.0, 0.75, 0.9), ROCK.lightened(0.12), ROCK.darkened(0.35), Vector3.ZERO, v)
		_cache[key] = b.build(null)
	return _cache[key]


## Doğuş: yerde geniş yarık, yerden fırlayan kontürlü moloz kayaları, bej toz halkası (ref)
static func _yamata_rise(pj: Node, pos: Vector3) -> void:
	var g = _gp(pos)
	_decal(pj, 0, g, 9.0, 0.35, 2.5, 1.2, {"c1": Color(0.12, 0.1, 0.08), "c2": Color(0.5, 0.45, 0.38), "alpha": 0.95, "nf": 4.0})
	for k in 12:
		var a = TAU * k / 12.0 + randf_range(-0.2, 0.2)
		var dv = Vector3(cos(a), 0, sin(a))
		var s = randf_range(1.0, 2.0)
		var rk = _solid(_rubble_mesh(randi() % 5 + 1), 0.04 / s, 5.0)
		_add(pj, rk, g + dv * randf_range(5.0, 7.5) - UP * 0.6)
		rk.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		rk.scale = Vector3.ONE * s * 0.2
		var tw = rk.create_tween()
		tw.tween_interval(k * 0.025)
		tw.tween_property(rk, "scale", Vector3.ONE * s, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(rk, "global_position", rk.global_position + UP * 0.6, 0.18)
		tw.tween_interval(2.6)
		tw.tween_property(rk, "scale", Vector3(s, 0.02, s), 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(rk.queue_free)
	for k in 14:
		var a = TAU * k / 14.0
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + dv * 4.5 + UP * 0.8, randf_range(2.2, 3.0), dv * 3.0 + UP * 0.8, 1.6, DUST_COLS, {"grow": 1.6, "nf": 8.0})
	_clods(pj, g, 30, 14.0, EARTH_C, 0.3)


## Baş indiği yer: toz bulutu, çatlak, toprak
static func _yamata_slam(pj: Node, at: Vector3) -> void:
	for k in 5:
		var a = TAU * k / 5.0 + randf()
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, at + dv * 0.6 + UP * 0.5, randf_range(1.2, 1.6), dv * 3.5 + UP * 1.0, 0.9, DUST_COLS, {"grow": 1.7, "nf": 5.0})
	_decal(pj, 0, at, 2.2, 0.12, 1.4, 0.6, CRACK_PRM)
	_clods(pj, at, 10, 9.0, EARTH_C, 0.18)


## Sonda gövde toza gömülür
static func _yamata_collapse(pj: Node, pos: Vector3) -> void:
	var g = _gp(pos)
	for k in 12:
		var a = TAU * k / 12.0
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + dv * 2.5 + UP * 1.2, randf_range(2.0, 2.8), dv * 2.5 + UP * 0.5, 1.4, DUST_COLS, {"grow": 1.5, "nf": 6.0})
	_clods(pj, g, 18, 10.0, EARTH_C, 0.25)


# ================================================================== Orochimaru-Ryū no Kawarimi
## Kabuk değiştirme (ref: eski bedenin üstünü kaplayan açık sarı sümük iplikleri): eski beden griye dönüp sümüğe bulanır ve yarılır;
## ağzından sümük fışkırıp yepyeni beden çıkar (%45 can, durumlar temizlenir). Görünüş: kabuğa yapışık sarı sümük iplikleri,
## ağızdan öne sümük püskürmesi, iki beden arasında uzayıp kopan sümük ipi, yerde parlak birikinti, yeni bedenden damlalar.
static func orochimaru_ryu_no_kawarimi_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m):
		return
	var husk = CharacterModel.new()
	pj.get_tree().current_scene.add_child(husk)
	husk.setup(m.look.duplicate())
	husk.global_transform = m.global_transform
	husk.play("hit", 0.0, 0.2)
	for sm in husk.materials:
		if sm is ShaderMaterial:
			sm.set_shader_parameter("tint", Color(0.62, 0.6, 0.58))
	var tw = husk.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(husk, "scale", Vector3(1.15, 0.25, 1.15), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_interval(3.0)
	tw.tween_property(husk, "scale", Vector3(1.2, 0.02, 1.2), 0.6)
	tw.tween_callback(husk.queue_free)
	_slime_drape(husk)
	var head_p = _bone_pos(c, "Head", UP * 1.6)
	var old_p: Vector3 = c.global_position
	Sfx.play("water", c.global_position, 0.6)
	var d = c.face_dir()
	c.global_position = pj.gp(c.global_position + d * 2.0)
	_slime_birth(pj, head_p, d, old_p, c)
	m.scale = Vector3.ONE * 0.3 * m.age_scale
	var t2 = m.create_tween()
	t2.tween_property(m, "scale", Vector3.ONE * m.age_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.heal(c, c.max_hp * 0.45)
	for s in ["burn", "bind", "slow", "stun", "sealed", "poison", "marked", "fear", "frozen", "chilled", "shocked", "mud"]:
		if c.get("statuses") is Dictionary:
			c.statuses.erase(s)
	if c is Player:
		c.combat.invuln = 1.2
	Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Kabuk değiştirdi!", Color(0.85, 0.95, 0.8))


## Kabuğa yapışık sümük iplikleri (kabuğun yerel uzayında: kabukla birlikte çöker)
static func _slime_drape(husk: Node3D) -> void:
	var b = MB.new()
	for k in 12:
		var a = TAU * k / 12.0 + randf_range(-0.15, 0.15)
		var ov = Vector3(cos(a), 0, sin(a))
		var tv = Vector3(-sin(a), 0, cos(a))
		var y0 = randf_range(1.55, 1.72)
		var y1 = randf_range(0.55, 1.05)
		var pts = []
		var s1 = []
		var s2 = []
		var ws = []
		var w = randf_range(0.018, 0.034)
		var wig = randf() * TAU
		for s in 9:
			var u = s / 8.0
			var y = lerpf(y0, y1, u)
			var rr = 0.13 + 0.15 * smoothstep(1.62, 1.35, y)
			pts.append(ov * (rr + 0.015) + UP * y + tv * sin(u * 7.0 + wig) * 0.04)
			s1.append(tv)
			s2.append(ov)
			ws.append(w * (1.0 + 0.6 * u))
		_strip(b, pts, s1, ws)
		_strip(b, pts, s2, ws)
	var mi = _ribbon_node(b.build(null), {"pat": 2.0, "c1": SLIME, "c2": SLIME_S, "c3": SLIME_LN, "alpha": 1.0, "reveal": 1.0, "tail": 0.0, "seed": randf() * 10.0, "nf": 1.5})
	husk.add_child(mi)


static func _slime_birth(pj: PathJutsu, head_p: Vector3, d: Vector3, old_p: Vector3, c: Node3D) -> void:
	var fd = _flatv(d)
	_spray(pj, head_p + fd * 0.15, {"n": 24, "life": 0.8, "r": 0.1, "dir": (fd + UP * 0.3).normalized(), "spread": 35.0, "v0": 3.0, "v1": 7.0,
		"grav": 12.0, "s0": 0.05, "s1": 0.11, "col": SLIME, "mesh": _drop_mesh()})
	_decal_line(pj, 8, pj.gp(old_p), fd, 2.8, 1.5, 0.25, 2.6, 0.8, {"c1": SLIME, "c2": SLIME_S, "c3": SLIME_LN, "alpha": 0.95, "nf": 1.5})
	var new_head = c.global_position + UP * (head_p.y - old_p.y)
	_arc_ribbon(pj, head_p, new_head, 0.25, 0.06, {"pat": 2.0, "c1": SLIME, "c2": SLIME_S, "c3": SLIME_LN, "nf": 1.5}, 0.2, 0.3, 0.35)
	var dr = _spray(pj, Vector3.ZERO, {"one": false, "parent": c, "off": UP * 1.0, "n": 10, "life": 0.6, "r": 0.3, "dir": Vector3.DOWN,
		"spread": 60.0, "v0": 0.5, "v1": 1.5, "grav": 9.0, "s0": 0.04, "s1": 0.08, "col": SLIME, "mesh": _drop_mesh()})
	var dw = weakref(dr)
	_later(pj, 0.8, func():
		var x = dw.get_ref()
		if x != null and is_instance_valid(x):
			x.emitting = false
			_kill_after(pj, x, 0.8))


# ================================================================== Kusanagi no Tsurugi: Kuchiyose
## Ağızdan çıkan yılan (gerçek yılan modeli) dişlerinde Kusanagi'yi (gerçek kılıç modeli) tutar: kılıç 25 m'ye uzar.
## Görünüş: ağızda parıltı, uzama anında hat boyunca ince beyaz-mavi ışık çizgisi, her 5 m'de hattın etrafında açılan ince
## hava yarığı hilalleri, delinen hedefte çapraz parıltı + kıvılcım; elde kalan kılıçta parıltı.
static func kusanagi_kuchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = Jutsu._aim(c, t)
	pj.busy(c, 1.1)
	if c is Player and t:
		c.combat.face_to(t)
	var mouth = Jutsu._mouth(c)
	var head = pj.make_snake(mouth, Color(0.55, 0.45, 0.6), 0.45, 6)
	pj.slither(head, mouth, mouth + d * 1.6, 0.25, 0.1)
	var blade = pj.kusanagi_blade(1.0)
	head.add_child(blade)
	blade.position = Vector3(0, -0.05, -0.35)
	Sfx.play("clink", mouth, 0.7)
	_pop(pj, 9, mouth + d * 0.4, Vector2(0.7, 0.7), 0.12, 0.1, 0.1, {"c1": KUSA_W, "c2": KUSA_B, "nf": 1.0})
	var hits = []
	pj.after(0.28, func():
		if not is_instance_valid(blade):
			return
		_kusanagi_line(pj, mouth, d)
		_pop(pj, 9, mouth + d * 0.6, Vector2(2.5, 2.5), 0.08, 0.05, 0.15, {"c1": KUSA_W, "c2": KUSA_B, "nf": 1.5})
		var tw = blade.create_tween()
		tw.tween_property(blade, "scale", Vector3(1.6, 1.6, 25.0), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(blade, "scale", Vector3(1, 1, 0.6), 0.2)
		Sfx.play("whoosh", mouth, 1.4)
		pj.after(0.12, func():
			for k in 17:
				var p = mouth + d * (1.5 + k * 1.5)
				for h in pj.hit(c, p, 0.9, pj.inf(c, "kusanagi_kuchi", 1.6, {"knock": 6.0, "kind": "heavy", "pierce_guard": true, "burn": 2.0, "hitstop": 0.08}), hits):
					hits.append(h)
					_pierce_glint(pj, h.global_position + Vector3.UP)
			_air_split(pj, mouth, d)
			pj.shake(0.4)))
	_shrink_free(head, 1.0, 0.2)
	# kılıç 15 sn sağ elde: vuruşlar uzar ve güçlenir
	if c is Player:
		Buffs.add("kusanagi", 15.0, {"melee": 1.18, "reach": 1.6})
		var ba = pj.bone_attach(c, "RightHand")
		if ba:
			var hb = pj.kusanagi_blade(1.15)
			ba.add_child(hb)
			hb.position = Vector3(0, 0.05, 0)
			hb.rotation_degrees = Vector3(-90, 0, 0)
			pj.free_after(15.0, ba)
			_pop(pj, 9, pj.hand_pos(c), Vector2(0.8, 0.8), 0.1, 0.1, 0.15, {"c1": KUSA_W, "c2": KUSA_B, "nf": 1.0})


## Uzayan kılıcın hattı: ağızdan 26 m'ye çapraz ince ışık çizgisi, hızla akar, kısa durur, söner
static func _kusanagi_line(pj: Node, mouth: Vector3, d: Vector3) -> void:
	var dn = d.normalized()
	var s1 = dn.cross(UP)
	s1 = s1.normalized() if s1.length() > 0.01 else Vector3.RIGHT
	var s2 = dn.cross(s1).normalized()
	var b = MB.new()
	var pts = []
	var a1 = []
	var a2 = []
	var ws = []
	for k in 13:
		pts.append(mouth + dn * (0.4 + k * 26.0 / 12.0))
		a1.append(s1)
		a2.append(s2)
		ws.append(0.07)
	_strip(b, pts, a1, ws)
	_strip(b, pts, a2, ws)
	var mi = _ribbon_node(b.build(null), {"pat": 5.0, "c1": KUSA_W, "c2": KUSA_B, "alpha": 1.0, "reveal": 0.0, "tail": 0.0, "seed": randf() * 10.0, "nf": 2.0})
	_add(pj, mi, Vector3.ZERO)
	var tw = _tp(mi, "reveal", 0.0, 1.0, 0.16)
	tw.tween_interval(0.2)
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("tail", v), 0.0, 1.0, 0.22)
	tw.tween_callback(mi.queue_free)


## Hattın etrafında her 5 m'de açılan ince hava yarığı hilalleri (kılıcın yardığı hava)
static func _air_split(pj: Node, mouth: Vector3, d: Vector3) -> void:
	var dn = d.normalized()
	var s1 = dn.cross(UP)
	s1 = s1.normalized() if s1.length() > 0.01 else Vector3.RIGHT
	var s2 = dn.cross(s1).normalized()
	for k in 5:
		var o = mouth + dn * (4.0 + k * 5.0)
		for q in 2:
			var a0 = randf() * TAU + q * PI
			var b = MB.new()
			var pts = []
			var sd = []
			var ws = []
			for s in 11:
				var aa = a0 + s * 0.18
				var rv = s1 * cos(aa) + s2 * sin(aa)
				pts.append(rv * 0.55 - dn * s * 0.06)
				sd.append(dn)
				ws.append(0.05)
			_strip(b, pts, sd, ws)
			var mi = _ribbon_node(b.build(null), {"pat": 5.0, "c1": KUSA_W, "c2": KUSA_B, "alpha": 0.9, "reveal": 1.0, "tail": 0.0, "seed": randf() * 10.0, "nf": 2.0})
			_add(pj, mi, o)
			var tw = mi.create_tween().set_parallel(true)
			tw.tween_property(mi, "scale", Vector3.ONE * 2.2, 0.3).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(v: float):
				if is_instance_valid(mi):
					mi.set_instance_shader_parameter("alpha", v), 0.9, 0.0, 0.3)
			tw.chain().tween_callback(mi.queue_free)


static func _pierce_glint(pj: Node, at: Vector3) -> void:
	_pop(pj, 9, at, Vector2(1.6, 1.6), 0.06, 0.04, 0.12, {"c1": KUSA_W, "c2": KUSA_B, "nf": 1.5})
	_spray(pj, at, {"n": 10, "life": 0.3, "r": 0.1, "dir": UP, "spread": 180.0, "v0": 4.0, "v1": 8.0, "grav": 6.0,
		"s0": 0.02, "s1": 0.04, "col": KUSA_W, "align": true, "mesh": _shard_mesh()})
