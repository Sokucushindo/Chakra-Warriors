class_name FuinjutsuFXB
extends RefCounted
## Fūinjutsu grubu B: on mühür tekniğinin görselleri. Tüm görünüş bu dosyada sıfırdan üretilir:
##   kendini yazan fırça yazısı (kalem kalkmadan akan el yazısı glifleri; şerit / kâğıt / mühür formülü / alan diski),
##   çakra zinciri (gerçek halka geometrisi), canlı tüp (hayalet yılan, mürekkep dokunaç, bijū çakrası, mühür kolu, ışık ipi),
##   cel gölgeli katı şekil + koyu kontur (mürekkep balçığı, shuriken, kâğıt rulo), kara sis küpü, kameraya dönük parıltı.
## Kameraya yakın her yüzey noktalı eriyerek incelir (ekranı kaplamaz). Beden üstü mühür çizgileri karakterin kendi
## ten gölgelendiricisinden (Byakugō: beden sage_marks = 4, yüz seal_marks). Bijū rengi gerçek bijū verisinden (BeastModels).
## Oynanış (hasar, durum, süre, menzil, hedefleme, bedel) ana ağaçtaki işleyicilerden satır satır taşındı.

const INK := Color(0.05, 0.04, 0.06)
const PAPER := Color(0.94, 0.91, 0.82)
const STAMP := Color(0.66, 0.1, 0.12)
const FOG_PURPLE := Color(0.62, 0.32, 0.9)

static var _cache := {}


# ================================================================== gölgelendiriciler
const LIB := """
float qh(float n) { return fract(sin(n * 91.345 + 0.71) * 47453.531); }
float qh2(vec2 p) { return fract(sin(dot(p, vec2(41.37, 289.13))) * 23421.631); }
float qnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(qh2(i), qh2(i + vec2(1.0, 0.0)), f.x), mix(qh2(i + vec2(0.0, 1.0)), qh2(i + vec2(1.0, 1.0)), f.x), f.y);
}
bool cam_cut(vec3 vpos, vec2 fc, float nfar) {
	float k = smoothstep(nfar * 0.35, nfar, length(vpos));
	return k < qh2(floor(fc));
}
// el yazısı glifi: kalem kalkmadan 5 noktadan geçer (darbeler çoğunlukla yatay / dikey), sonda nokta; prog ile kendini çizer
float brush_glyph(vec2 q, float id, float prog) {
	float d = 1000.0;
	vec2 prev = vec2(0.15 + 0.7 * qh(id * 1.3), 0.15 + 0.7 * qh(id * 2.9));
	for (int k = 1; k < 5; k++) {
		float fk = float(k);
		float sp = clamp(prog * 4.6 - (fk - 1.0), 0.0, 1.0);
		if (sp <= 0.0) { break; }
		vec2 nxt = vec2(0.12 + 0.76 * qh(id * 3.7 + fk * 5.3), 0.12 + 0.76 * qh(id * 6.1 + fk * 2.2));
		if (qh(id + fk * 7.7) < 0.5) { nxt.y = mix(prev.y, nxt.y, 0.25); } else { nxt.x = mix(prev.x, nxt.x, 0.25); }
		vec2 e = mix(prev, nxt, sp);
		vec2 pa = q - prev;
		vec2 ba = e - prev;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
		float w = 0.055 * (1.25 - 0.6 * h) * (0.7 + 0.5 * qh(id * 9.1 + fk));
		d = min(d, length(pa - ba * h) - w);
		prev = nxt;
	}
	if (prog > 0.85) {
		vec2 dp = vec2(0.2 + 0.6 * qh(id * 4.4), 0.2 + 0.6 * qh(id * 8.8));
		d = min(d, length(q - dp) - 0.06);
	}
	return d;
}
"""

## Fırça yazısı. mode 0 şerit (hücreler U boyunca, soldan sağa yazılır; base.a > 0.5 ise kâğıt kenar çizgisi),
## 1 kâğıt tılsım (kenar + dikey yazı sütunu + kırmızı mühür damgası; cells.x = boy / en oranı), 2 mühür formülü (çift halka,
## yazı halkası, dört kol, orta sarmal), 3 alan diski (benekli ışık alanı, reveal = yarıçap)
const SCRIPT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float reveal = 1.0;
instance uniform float alpha = 1.0;
instance uniform float seed = 0.0;
instance uniform float mode = 0.0;
instance uniform float jag = 0.0;
instance uniform float nf = 1.5;
instance uniform vec2 cells = vec2(8.0, 1.0);
instance uniform vec4 ink : source_color = vec4(0.05, 0.04, 0.06, 1.0);
instance uniform vec4 halo : source_color = vec4(0.0, 0.0, 0.0, 0.0);
instance uniform vec4 base : source_color = vec4(0.0, 0.0, 0.0, 0.0);
instance uniform vec4 accent : source_color = vec4(0.66, 0.1, 0.12, 1.0);

FUIN_LIB

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	vec2 uv = UV;
	float d = 1000.0;
	float ln = 1000.0;
	float fillm = 0.0;
	float shk = 1.0;
	float stamp = 0.0;
	if (mode < 0.5) {
		vec2 cu = uv * cells;
		vec2 cell = floor(cu);
		vec2 q = fract(cu);
		q += vec2(sin(q.y * 37.0 + cell.x * 3.1), cos(q.x * 41.0 + cell.y)) * 0.035 * jag;
		float prog = clamp(reveal * (cells.x + 1.0) - cell.x - qh(cell.y + seed) * 0.8, 0.0, 1.0);
		float id = qh2(cell + vec2(seed * 3.1, seed)) * 113.0 + 1.0;
		if (qh(id * 0.37) > 0.14) { d = brush_glyph(q, id, prog); }
		fillm = 1.0;
		if (base.a > 0.5) { ln = min(abs(uv.y - 0.06) - 0.008, abs(uv.y - 0.94) - 0.008); }
	} else if (mode < 1.5) {
		fillm = 1.0;
		float m = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y) * cells.x);
		ln = abs(m - 0.07) - 0.014;
		vec2 cu = vec2((uv.x - 0.2) / 0.6, (uv.y - 0.08) / 0.64 * cells.y);
		if (cu.x > 0.0 && cu.x < 1.0 && cu.y > 0.0 && cu.y < cells.y) {
			vec2 cell = floor(cu);
			float prog = clamp(reveal * cells.y * 1.2 - cell.y, 0.0, 1.0);
			d = brush_glyph(fract(cu), qh2(cell + vec2(seed)) * 113.0 + 1.0, prog);
		}
		vec2 sp = (uv - vec2(0.5, 0.85)) * vec2(1.0, cells.x);
		if (reveal > 0.92 && length(sp) < 0.16) { stamp = 1.0; }
	} else if (mode < 2.5) {
		vec2 c = uv * 2.0 - 1.0;
		float r = length(c);
		if (r > 1.0) { discard; }
		fillm = 1.0 - smoothstep(0.9, 1.0, r);
		float an = atan(c.y, c.x) / 6.2831853 + 0.5;
		if (an < clamp(reveal * 1.6, 0.0, 1.0)) {
			ln = min(abs(r - 0.95) - 0.018, abs(r - 0.88) - 0.007);
			ln = min(ln, abs(r - 0.6) - 0.01);
		}
		float tr = (r - 0.63) / 0.22;
		if (tr > 0.0 && tr < 1.0) {
			vec2 cu = vec2(an * cells.x, tr);
			vec2 cell = floor(cu);
			float prog = clamp(reveal * 1.4 * cells.x - cell.x, 0.0, 1.0);
			d = brush_glyph(fract(cu), qh2(cell + vec2(seed)) * 113.0 + 1.0, prog);
		}
		if (r > 0.3 && r < 0.6 && r < 0.3 + reveal * 0.6) {
			ln = min(ln, abs(fract(an * 4.0) - 0.5) * 6.2831853 / 4.0 * r - 0.012);
		}
		if (r < 0.3 && r < reveal * 0.45) {
			float t = r / 0.3 * 3.0 - an;
			ln = min(ln, abs(fract(t + 0.5) - 0.5) * 0.1 - 0.01);
		}
	} else {
		vec2 c = uv * 2.0 - 1.0;
		float r = length(c);
		if (r > 1.0 || r > reveal) { discard; }
		float n = qnoise(uv * 9.0 + vec2(seed, TIME * 0.05)) * 0.6 + qnoise(uv * 23.0 - vec2(seed)) * 0.4;
		fillm = (0.55 + 0.45 * smoothstep(0.55, 1.0, r)) * (0.8 + 0.4 * n);
		shk = 0.85 + 0.3 * n;
		ln = abs(r - 0.975) - 0.008;
	}
	float aa = min(fwidth(d), 0.08) + 0.003;
	float core = 1.0 - smoothstep(-aa, aa, d);
	float wide = 1.0 - smoothstep(0.07 - aa, 0.07 + aa, d);
	float la = min(fwidth(ln), 0.05) + 0.002;
	core = max(core, 1.0 - smoothstep(-la, la, ln));
	wide = max(wide, 1.0 - smoothstep(0.03 - la, 0.03 + la, ln));
	vec3 col = base.rgb * shk;
	float a = base.a * fillm;
	col = mix(col, halo.rgb, wide * halo.a);
	a = max(a, wide * halo.a);
	col = mix(col, ink.rgb, core);
	a = max(a, core * ink.a);
	if (stamp > 0.5) { col = accent.rgb; a = 1.0; }
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Canlı enerji / madde tüpü. UV.x boy (reveal ile baştan uca), UV.y çevre. pat 0 çakra zinciri, 1 hayalet yılan (pul),
## 2 mühür kolu (nane ışığı, akan bant), 3 bijū çakrası (yarı saydam + kara damar + parlak kontur), 4 mürekkep dokunaç
## (parlak siyah + vantuz), 5 ışık ipi
const ENERGY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 c_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c_edge : source_color = vec4(0.5, 0.9, 0.8, 1.0);
instance uniform float alpha = 1.0;
instance uniform float reveal = 1.0;
instance uniform float pat = 0.0;
instance uniform float seed = 0.0;
instance uniform float links = 12.0;
instance uniform float nf = 1.5;

varying vec3 lp;

FUIN_LIB

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	if (UV.x > reveal) { discard; }
	float fr = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 col = c_core.rgb;
	float a = 1.0;
	if (pat < 0.5) {
		col = mix(c_core.rgb, c_edge.rgb, smoothstep(0.25, 0.8, fr));
		if (fr > 0.86) { col = c_edge.rgb * 0.35; }
		col *= 0.9 + 0.2 * step(0.5, fract(UV.x * links * 0.5 + TIME * 0.6));
	} else if (pat < 1.5) {
		vec2 sp = vec2(UV.x * links, UV.y * 10.0);
		sp.x += mod(floor(sp.y), 2.0) * 0.5;
		vec2 cl = fract(sp) - 0.5;
		float sc = abs(cl.x) + abs(cl.y);
		col = mix(c_core.rgb, c_edge.rgb, smoothstep(0.45, 0.95, fr));
		if (sc > 0.44) { col = mix(col, c_edge.rgb, 0.55); }
		a = 0.55 + 0.4 * smoothstep(0.3, 0.9, fr);
		if (fr > 0.9) { col = c_edge.rgb * 0.45; a = 0.95; }
	} else if (pat < 2.5) {
		col = mix(c_core.rgb, c_edge.rgb, smoothstep(0.15, 0.75, fr));
		float fl = sin(UV.x * 18.0 - TIME * 4.0 + seed);
		col += vec3(0.12) * step(0.7, fl);
		a = 0.92 - 0.5 * smoothstep(0.75, 1.0, fr);
	} else if (pat < 3.5) {
		float st = sin(lp.y * 14.0 + sin(lp.x * 9.0 + lp.z * 7.0 + seed) * 2.0 - TIME * 4.0);
		col = c_core.rgb * (st > 0.55 ? 0.42 : 1.0);
		a = 0.45;
		if (fr > 0.72) { col = c_edge.rgb; a = 0.95; }
	} else if (pat < 4.5) {
		col = c_core.rgb;
		float v = UV.y;
		if (abs(v - 0.5) < 0.12) {
			vec2 q = vec2(fract(UV.x * links) - 0.5, (v - 0.5) * 4.0);
			if (length(q) < 0.3) { col = vec3(0.33, 0.28, 0.3); }
		}
		if (fr > 0.12 && fr < 0.26 && abs(v - 0.0) < 0.2) { col = mix(col, vec3(0.55, 0.52, 0.5), 0.7); }
		if (fr > 0.86) { col = vec3(0.0); }
	} else {
		col = mix(c_core.rgb, c_edge.rgb, fr);
		a = 1.0 - fr * 0.6;
	}
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Cel gölgeli katı şekil (iki ton, isteğe bağlı ıslak parlama). vc > 0.5: köşe rengi çarpılır. alpha noktalı erime.
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

instance uniform vec4 body : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 shade : source_color = vec4(0.6, 0.6, 0.6, 1.0);
instance uniform float alpha = 1.0;
instance uniform float nf = 1.5;
instance uniform float gloss = 0.0;
instance uniform float seed = 0.0;
instance uniform float vc = 0.0;

FUIN_LIB

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	if (qh2(floor(FRAGCOORD.xy) + vec2(seed)) > alpha) { discard; }
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float l = dot(wn, normalize(vec3(0.35, 0.85, 0.4)));
	vec3 col = l > -0.1 ? body.rgb : shade.rgb;
	if (vc > 0.5) { col *= COLOR.rgb; }
	if (gloss > 0.0) {
		float fv = abs(dot(normalize(NORMAL), normalize(VIEW)));
		if (l > 0.5 && fv > 0.55 && fv < 0.72) { col = mix(col, vec3(0.92, 0.9, 0.88), gloss); }
	}
	ALBEDO = col;
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

instance uniform float ow = 0.02;
instance uniform float alpha = 1.0;
instance uniform float nf = 1.5;
instance uniform float seed = 0.0;
instance uniform vec4 oc : source_color = vec4(0.03, 0.02, 0.04, 1.0);

FUIN_LIB

void vertex() {
	VERTEX += NORMAL * ow;
}

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	if (qh2(floor(FRAGCOORD.xy) + vec2(seed)) > alpha) { discard; }
	ALBEDO = oc.rgb;
}
"""

## Kara sis küpü (Shikokumujin). Birim kutu (yerel -0.5..0.5); fill yukarıdan aşağı dolar; yüzeyde aşağı akan sis
## gürültüsü, kenarlarda mor bariyer çizgisi. cull_back: kamera içerideyse hiçbir şey çizilmez (ekranı kaplamaz).
const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float alpha = 1.0;
instance uniform float fill = 1.0;
instance uniform float nf = 2.0;
instance uniform float seed = 0.0;
instance uniform vec4 edge : source_color = vec4(0.75, 0.5, 1.0, 1.0);

varying vec3 lp;

FUIN_LIB

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	vec3 q = abs(lp);
	vec2 fuv = q.x > 0.499 ? lp.zy : (q.z > 0.499 ? lp.xy : lp.xz);
	float n = qnoise(fuv * 5.0 + vec2(seed, TIME * 0.45)) * 0.65 + qnoise(fuv * 13.0 + vec2(TIME * 0.2, seed)) * 0.35;
	if (lp.y < 0.5 - fill * 1.12 + n * 0.12) { discard; }
	vec3 col = mix(vec3(0.03, 0.015, 0.05), vec3(0.2, 0.11, 0.26), smoothstep(0.35, 0.85, n));
	float a = 0.82 + 0.15 * n;
	vec3 m = vec3(0.5) - q;
	float e2 = max(min(m.x, m.y), min(max(m.x, m.y), m.z));
	if (e2 < 0.022) { col = edge.rgb; a = 1.0; }
	else if (e2 < 0.035) { col = vec3(0.02, 0.0, 0.04); a = 1.0; }
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Kameraya dönük parıltı. kind 0 elmas mühür (Byakugō), 1 dört kollu ışık çakması, 2 ince halka. Ölçek x / y ayrı.
const GLINT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 c_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c_edge : source_color = vec4(0.7, 0.3, 0.9, 1.0);
instance uniform float alpha = 1.0;
instance uniform float kind = 0.0;
instance uniform float nf = 0.6;

FUIN_LIB

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	vec2 q = UV * 2.0 - 1.0;
	float a = 0.0;
	vec3 col = c_edge.rgb;
	if (kind < 0.5) {
		float dd = abs(q.x) + abs(q.y) * 0.75;
		if (dd < 0.32) {
			col = dd > 0.24 ? mix(c_core.rgb, c_edge.rgb, 0.6) : c_core.rgb;
			a = 1.0;
		} else {
			a = (1.0 - smoothstep(0.32, 1.0, dd)) * 0.55;
		}
	} else if (kind < 1.5) {
		float hx = (1.0 - smoothstep(0.0, 1.0, abs(q.x))) * (1.0 - smoothstep(0.0, 0.16, abs(q.y)));
		float hy = (1.0 - smoothstep(0.0, 0.16, abs(q.x))) * (1.0 - smoothstep(0.0, 1.0, abs(q.y)));
		a = max(hx, hy);
		col = mix(c_edge.rgb, c_core.rgb, smoothstep(0.35, 0.85, a));
	} else {
		float r = length(q);
		a = 1.0 - smoothstep(0.0, 0.1, abs(r - 0.8));
		col = c_core.rgb;
	}
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""


# ================================================================== malzeme / düğüm yardımcıları
static func _mat(id: String, code: String) -> ShaderMaterial:
	var key = "mat:" + id
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("FUIN_LIB", LIB)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _script_mat() -> ShaderMaterial:
	return _mat("script", SCRIPT_SHADER)


static func _energy_mat() -> ShaderMaterial:
	return _mat("energy", ENERGY_SHADER)


static func _cel_mat() -> ShaderMaterial:
	return _mat("cel", CEL_SHADER)


static func _outline_mat() -> ShaderMaterial:
	return _mat("outline", OUTLINE_SHADER)


static func _fog_mat() -> ShaderMaterial:
	return _mat("fog", FOG_SHADER)


static func _glint_mat() -> ShaderMaterial:
	return _mat("glint", GLINT_SHADER)


static func _bit_mat(col: Color) -> StandardMaterial3D:
	var key = "smat:" + col.to_html()
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	_cache[key] = m
	return m


static func _mi(mesh: Mesh, mat: Material, prm := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in prm:
		mi.set_instance_shader_parameter(k, prm[k])
	return mi


## Düğüm ve altındaki tüm gölgelendirici örneklerine aynı parametre
static func _set_all(n: Node, key: String, val) -> void:
	if not is_instance_valid(n):
		return
	if n is MeshInstance3D:
		n.set_instance_shader_parameter(key, val)
	for ch in n.get_children():
		_set_all(ch, key, val)


static func _tp(n: Node, key: String, a: float, b: float, dur: float, delay := 0.0) -> Tween:
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(n):
			_set_all(n, key, v), a, b, maxf(dur, 0.01))
	return tw


static func _fade_free(n: Node, delay: float, dur: float) -> void:
	if not is_instance_valid(n):
		return
	var tw = _tp(n, "alpha", 1.0, 0.0, dur, delay)
	tw.tween_callback(n.queue_free)


static func _add(pj: Node, n: Node3D, pos: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD


static func _bone_pos(c: Node3D, bone: String, fb: Vector3) -> Vector3:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.get("skel") != null and m.skel:
		var bi = m.skel.find_bone(bone)
		if bi >= 0:
			return (m.skel.global_transform * m.skel.get_bone_global_pose(bi)).origin
	return c.global_position + fb


static func _bez(a: Vector3, m: Vector3, b: Vector3, u: float) -> Vector3:
	return a.lerp(m, u).lerp(m.lerp(b, u), u)


## +Z ekseni dir'e bakan taban
static func _basis_z(dir: Vector3) -> Basis:
	var d = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	return Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.97 else Vector3.RIGHT)


## Bijū çakra rengi gerçek bijū verisinden: kuyruklu canavar, jinchūriki düşman ya da köydeki taşıyıcı; yoksa fb
static func _beast_chakra(t: Node3D, fb: Color) -> Color:
	if t == null or not is_instance_valid(t):
		return fb
	var bid := ""
	if t is TailedBeast:
		bid = String(t.id)
	elif t.get("arch") is Dictionary:
		bid = String(t.arch.get("beast", ""))
	if bid == "" and t.has_meta("jinchuriki_of"):
		bid = String(t.get_meta("jinchuriki_of"))
	if bid != "" and BeastModels.INFO.has(bid):
		return BeastModels.INFO[bid]["chakra"]
	return fb


## Beden kemiğini kare kare izleyen tutucu: yerel +Z yüz yönü, +Y yukarı
static func _follow(pj: Node, c: Node3D, bone: String, fb: Vector3, fwd_off: float, up_off: float, dur: float) -> Node3D:
	var h = Node3D.new()
	pj.get_tree().current_scene.add_child(h)
	var upd = func():
		if not is_instance_valid(h) or not is_instance_valid(c):
			return
		var f = _flat(c.face_dir())
		var r = Vector3.UP.cross(f).normalized()
		h.global_transform = Transform3D(Basis(r, Vector3.UP, f), _bone_pos(c, bone, fb) + f * fwd_off + Vector3.UP * up_off)
	upd.call()
	var tw = h.create_tween()
	tw.tween_method(func(_v: float): upd.call(), 0.0, 1.0, maxf(dur, 0.01))
	tw.tween_callback(h.queue_free)
	return h


## Kendi ayarlı parçacık (mürekkep damlası, çakra zerresi, zehir zerresi)
static func _bits(pj: Node, pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	var one: bool = o.get("one_shot", true)
	p.one_shot = one
	p.amount = int(o.get("n", 16))
	p.lifetime = float(o.get("life", 0.8))
	p.explosiveness = float(o.get("expl", 0.9 if one else 0.0))
	if not _cache.has("mesh:bit"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		_cache["mesh:bit"] = sm
	p.mesh = _cache["mesh:bit"]
	p.material_override = _bit_mat(o.get("col", INK))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE if o.get("surface", false) else CPUParticles3D.EMISSION_SHAPE_SPHERE
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
	p.scale_amount_min = float(o.get("s0", 0.05))
	p.scale_amount_max = float(o.get("s1", 0.1))
	if not _cache.has("curve:shrink"):
		var cv = Curve.new()
		cv.add_point(Vector2(0.0, 1.0))
		cv.add_point(Vector2(1.0, 0.0))
		_cache["curve:shrink"] = cv
	p.scale_amount_curve = _cache["curve:shrink"]
	var parent: Node3D = o.get("parent", null)
	if parent and is_instance_valid(parent):
		p.local_coords = false
		parent.add_child(p)
		p.position = o.get("off", Vector3.ZERO)
	else:
		_add(pj, p, pos)
	p.emitting = true
	if one:
		var w = weakref(p)
		pj.get_tree().create_timer(p.lifetime + 0.6).timeout.connect(func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x):
				x.queue_free())
	return p


# ================================================================== geometri
static func _pack(v: PackedVector3Array, nr: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array) -> Array:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Tüp: pts boyunca radii; yan vektör eğri boyunca taşınır. UV.x boy (uo >= 0 ise sabit), UV.y çevre.
static func _tube(pts: Array, radii: Array, sides := 7, uo := -1.0) -> Array:
	var n = pts.size()
	if n < 2:
		return []
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var side := Vector3.ZERO
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tn.length_squared() < 1e-10:
			tn = Vector3.FORWARD
		tn = tn.normalized()
		if side == Vector3.ZERO:
			side = tn.cross(Vector3.UP if absf(tn.y) < 0.95 else Vector3.RIGHT).normalized()
		else:
			side = side - tn * side.dot(tn)
			if side.length_squared() < 1e-8:
				side = tn.cross(Vector3.RIGHT if absf(tn.x) < 0.95 else Vector3.UP).normalized()
			else:
				side = side.normalized()
		var bi = tn.cross(side)
		var rr = float(radii[i])
		var u = uo if uo >= 0.0 else float(i) / float(n - 1)
		for j in sides + 1:
			var a = TAU * j / sides
			var dn = side * cos(a) + bi * sin(a)
			v.append(p + dn * rr)
			nr.append(dn)
			uv.append(Vector2(u, float(j) / sides))
	for i in n - 1:
		for j in sides:
			var a0 = i * (sides + 1) + j
			var b0 = a0 + sides + 1
			idx.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))
	return _pack(v, nr, uv, idx)


static func _merge(list: Array) -> Array:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for arr in list:
		if arr.is_empty():
			continue
		var off = v.size()
		v.append_array(arr[Mesh.ARRAY_VERTEX])
		nr.append_array(arr[Mesh.ARRAY_NORMAL])
		uv.append_array(arr[Mesh.ARRAY_TEX_UV])
		for k in arr[Mesh.ARRAY_INDEX]:
			idx.append(k + off)
	return _pack(v, nr, uv, idx)


static func _mesh(arr: Array) -> ArrayMesh:
	var am = ArrayMesh.new()
	if not arr.is_empty() and (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func _quad(w: float, h: float) -> QuadMesh:
	var key = "mesh:quad:%.3f:%.3f" % [w, h]
	if not _cache.has(key):
		var qm = QuadMesh.new()
		qm.size = Vector2(w, h)
		_cache[key] = qm
	return _cache[key]


## Düz halka şerit (XZ): UV.x çevre boyunca, UV.y içten dışa
static func _annulus(r0: float, r1: float, segs: int) -> ArrayMesh:
	var key = "mesh:ann:%.3f:%.3f:%d" % [r0, r1, segs]
	if _cache.has(key):
		return _cache[key]
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in segs + 1:
		var a = TAU * i / segs
		var d = Vector3(cos(a), 0.0, sin(a))
		v.append(d * r0)
		v.append(d * r1)
		nr.append(Vector3.UP)
		nr.append(Vector3.UP)
		uv.append(Vector2(float(i) / segs, 0.0))
		uv.append(Vector2(float(i) / segs, 1.0))
	for i in segs:
		var a0 = i * 2
		idx.append_array(PackedInt32Array([a0, a0 + 1, a0 + 2, a0 + 2, a0 + 1, a0 + 3]))
	var am = _mesh(_pack(v, nr, uv, idx))
	_cache[key] = am
	return am


static func _box() -> BoxMesh:
	if not _cache.has("mesh:box"):
		var bm = BoxMesh.new()
		bm.size = Vector3.ONE
		_cache["mesh:box"] = bm
	return _cache["mesh:box"]


## Yere yatırılmış kare yüzey (formül, alan, kâğıt)
static func _flat_quad(w: float, h: float, prm: Dictionary) -> MeshInstance3D:
	var mi = _mi(_quad(w, h), _script_mat(), prm)
	mi.rotation.x = -PI * 0.5
	return mi


## Gerçek halkalardan çakra zinciri: +Z boyunca L uzunluğunda, halkalar sırayla dik düzlemde; UV.x = halkanın yeri
static func _chain_mesh(L: float, link: float, w: float, th: float) -> ArrayMesh:
	var parts = []
	var stp = link * 0.72
	var n = maxi(2, int(L / stp))
	for i in n:
		var zc = link * 0.5 + i * stp
		var pts = []
		var rr = []
		for j in 13:
			var a = TAU * j / 12.0
			var lat = sin(a) * w
			var lon = cos(a) * link * 0.5
			pts.append(Vector3(lat, 0.0, zc + lon) if i % 2 == 0 else Vector3(0.0, lat, zc + lon))
			rr.append(th)
		parts.append(_tube(pts, rr, 4, clampf(zc / L, 0.0, 1.0)))
	return _mesh(_merge(parts))


## Her kare yeniden kurulan tüp; build(t) -> tüp dizisi ([] = gizle)
static func _live(pj: Node, mat: Material, prm: Dictionary, dur: float, build: Callable) -> MeshInstance3D:
	var am = ArrayMesh.new()
	var mi = _mi(am, mat, prm)
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	mi.extra_cull_margin = 4.0
	var tw = mi.create_tween()
	tw.tween_method(func(tm: float):
		if not is_instance_valid(mi):
			return
		var arr: Array = build.call(tm)
		am.clear_surfaces()
		if arr.size() == Mesh.ARRAY_MAX and (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr), 0.0, dur, maxf(dur, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


## Cel katı şekil + koyu kontur kabuğu
static func _cel(mesh: Mesh, body: Color, shade: Color, ow: float, prm := {}) -> Node3D:
	var root = Node3D.new()
	var p = {"body": body, "shade": shade}
	p.merge(prm, true)
	root.add_child(_mi(mesh, _cel_mat(), p))
	if ow > 0.0:
		var q = {"ow": ow}
		for k in ["nf", "seed", "oc"]:
			if prm.has(k):
				q[k] = prm[k]
		root.add_child(_mi(mesh, _outline_mat(), q))
	return root


static func _glint(kind: float, w: float, h: float, core: Color, edge: Color, nf := 0.6) -> MeshInstance3D:
	var mi = _mi(_quad(1.0, 1.0), _glint_mat(), {"kind": kind, "c_core": core, "c_edge": edge, "nf": nf})
	mi.scale = Vector3(w, h, 1.0)
	return mi


## Hayalet yılan başı: üst çene (kafatası + burun + üst dişler) ve ayrı alt çene ("jaw"); burun +Z
static func _snake_head() -> Node3D:
	if not _cache.has("mesh:snake_up"):
		var b = MB.new()
		b.add("sphere", Vector3(0, 0.08, 0), Vector3(0.62, 0.34, 0.62), Color.WHITE, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0, 0.05, 0.3), Vector3(0.52, 0.26, 0.9), Color.WHITE, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0.2, 0.2, 0.12), Vector3(0.16, 0.1, 0.22), Color.WHITE, Vector3.ZERO, 8)
		b.add("sphere", Vector3(-0.2, 0.2, 0.12), Vector3(0.16, 0.1, 0.22), Color.WHITE, Vector3.ZERO, 8)
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.15, -0.12, 0.56), Vector3(0.07, 0.24, 0.07), Color.WHITE, Vector3(180, 0, 0), 6)
		_cache["mesh:snake_up"] = b.build(null)
		var j = MB.new()
		j.add("sphere", Vector3(0, -0.03, 0.3), Vector3(0.44, 0.12, 0.8), Color.WHITE, Vector3.ZERO, 12)
		for sx in [-1.0, 1.0]:
			j.add("cone", Vector3(sx * 0.13, 0.05, 0.56), Vector3(0.05, 0.16, 0.05), Color.WHITE, Vector3.ZERO, 6)
		_cache["mesh:snake_jaw"] = j.build(null)
	var root = Node3D.new()
	var up = Node3D.new()
	up.name = "up"
	root.add_child(up)
	up.add_child(_mi(_cache["mesh:snake_up"], _energy_mat()))
	var jaw = Node3D.new()
	jaw.name = "jaw"
	jaw.position = Vector3(0, -0.06, 0.02)
	root.add_child(jaw)
	jaw.add_child(_mi(_cache["mesh:snake_jaw"], _energy_mat()))
	return root


## Bijū çakra başı: kafa, burun, kulaklar, dişler; ayrı alt çene ("jaw"); burun +Z
static func _beast_head() -> Node3D:
	if not _cache.has("mesh:beast_up"):
		var b = MB.new()
		b.add("sphere", Vector3(0, 0, 0), Vector3(0.9, 0.8, 0.9), Color.WHITE, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0, -0.06, 0.55), Vector3(0.55, 0.4, 0.85), Color.WHITE, Vector3.ZERO, 12)
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.32, 0.52, -0.12), Vector3(0.24, 0.62, 0.14), Color.WHITE, Vector3(-20, 0, -sx * 25.0), 6)
			for k in 3:
				b.add("cone", Vector3(sx * (0.12 + k * 0.04), -0.26, 0.82 - k * 0.15), Vector3(0.06, 0.15, 0.06), Color.WHITE, Vector3(180, 0, 0), 5)
		_cache["mesh:beast_up"] = b.build(null)
		var j = MB.new()
		j.add("sphere", Vector3(0, -0.02, 0.42), Vector3(0.46, 0.18, 0.8), Color.WHITE, Vector3.ZERO, 10)
		for sx in [-1.0, 1.0]:
			j.add("cone", Vector3(sx * 0.14, 0.08, 0.7), Vector3(0.05, 0.14, 0.05), Color.WHITE, Vector3.ZERO, 5)
		_cache["mesh:beast_jaw"] = j.build(null)
	var root = Node3D.new()
	var up = Node3D.new()
	up.name = "up"
	root.add_child(up)
	up.add_child(_mi(_cache["mesh:beast_up"], _energy_mat()))
	var jaw = Node3D.new()
	jaw.name = "jaw"
	jaw.position = Vector3(0, -0.24, 0.05)
	root.add_child(jaw)
	jaw.add_child(_mi(_cache["mesh:beast_jaw"], _energy_mat()))
	return root


## Kaba shuriken: dört yassı bıçak + göbek halkası (XY düzleminde)
static func _shuriken_mesh() -> ArrayMesh:
	if not _cache.has("mesh:shuriken"):
		var b = MB.new()
		var steel = Color(0.36, 0.37, 0.4)
		for k in 4:
			var a = deg_to_rad(90.0 * k)
			b.add("cone", Vector3(-sin(a), cos(a), 0) * 0.2, Vector3(0.17, 0.34, 0.035), steel, Vector3(0, 0, 90.0 * k), 4)
		b.add("cyl", Vector3.ZERO, Vector3(0.17, 0.045, 0.17), steel.darkened(0.2), Vector3(90, 0, 0), 14)
		b.add("cyl", Vector3.ZERO, Vector3(0.09, 0.05, 0.09), PAPER, Vector3(90, 0, 0), 14)
		_cache["mesh:shuriken"] = b.build(null)
	return _cache["mesh:shuriken"]


## Mürekkep balçığı: bedeni saran topaklar (gövde) ve aşağı sarkan damlalar (ayrı mesh, aşağı uzar)
static func _goo_meshes() -> Array:
	if not _cache.has("mesh:goo"):
		var b = MB.new()
		for k in 8:
			var a = k * 0.85
			var s = 0.42 + 0.12 * float(k % 3)
			b.add("sphere", Vector3(cos(a) * 0.24, 0.75 + float(k % 4) * 0.24, sin(a) * 0.24), Vector3(s, s * 0.9, s), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.3, 1.38, 0.0), Vector3(0.5, 0.42, 0.5), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(-0.3, 1.4, 0.05), Vector3(0.46, 0.4, 0.5), Color.WHITE, Vector3.ZERO, 10)
		_cache["mesh:goo"] = b.build(null)
		var d = MB.new()
		for k in 9:
			var a = k * 0.7 + 0.3
			var ln = 0.45 + 0.35 * float((k * 7) % 4) / 3.0
			d.add("cone", Vector3(cos(a) * 0.33, -ln * 0.5 - float(k % 3) * 0.12, sin(a) * 0.33), Vector3(0.13, ln, 0.13), Color.WHITE, Vector3(180, 0, 0), 6)
		_cache["mesh:drips"] = d.build(null)
		var p = MB.new()
		p.add("cyl", Vector3.ZERO, Vector3(1.3, 0.03, 1.3), Color.WHITE, Vector3.ZERO, 18)
		p.add("cyl", Vector3(0.7, 0, 0.3), Vector3(0.3, 0.03, 0.3), Color.WHITE, Vector3.ZERO, 10)
		p.add("cyl", Vector3(-0.5, 0, -0.6), Vector3(0.22, 0.03, 0.22), Color.WHITE, Vector3.ZERO, 10)
		_cache["mesh:puddle"] = p.build(null)
	return [_cache["mesh:goo"], _cache["mesh:drips"], _cache["mesh:puddle"]]


## Tören bulutu topağı (yalnız kâğıt açılışında; kaynak görselde var)
static func _lobe_mesh() -> SphereMesh:
	if not _cache.has("mesh:lobe"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 12
		s.rings = 6
		_cache["mesh:lobe"] = s
	return _cache["mesh:lobe"]


## JutsuEngine "utility" biçiminin oynanışı birebir (Data'daki tier'den süre, hız modu, mesaj, ses)
static func _utility_buff(c: Node3D, id: String, col: Color) -> void:
	var d: Dictionary = Data.jutsu.get(id, {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 10.0 + tier * 3.0
	var mods = {"melee": 1.0 + 0.07 * (tier + 1)}
	var cat: String = d.get("category", "")
	var el: String = d.get("element", "")
	if cat == "senjutsu":
		mods = {"melee": 1.2 + 0.06 * tier, "armor": 0.85, "jutsu": 1.15 + 0.05 * tier}
	elif el == "raiton":
		mods = {"speed": 1.15 + 0.04 * tier, "melee": 1.1 + 0.05 * tier}
	elif el in ["doton", "shoton", "jiton"]:
		mods = {"armor": maxf(0.5, 0.9 - 0.06 * tier), "melee": 1.05 + 0.04 * tier}
	elif el in ["fuuton"]:
		mods = {"speed": 1.2 + 0.04 * tier}
	else:
		mods = {"speed": 1.1}
		dur = 8.0 + tier * 2.0
	Buffs.add(String(d.get("id", "buff")), dur, mods)
	if c is Player:
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], col.lightened(0.3))
	Sfx.play("seal", c.global_position, 0.8)


## Bedendeki gerçek mühür çizgileri: yüz derisi seal_marks grow sn'de 0 → 1 yayılır, ten sage_marks = 4; dur sonra temizlenir
static func _skin_seal(pj: Node, c: Node3D, dur: float, grow: float) -> void:
	var m = c.get("model")
	if m == null:
		return
	var bm = m.get("body_mesh")
	var smat = bm.get_surface_override_material(0) if bm else null
	var fmat = m.get("face_skin_mat")
	if fmat is ShaderMaterial:
		var tw = c.create_tween()
		tw.tween_method(func(v: float):
			if is_instance_valid(fmat):
				fmat.set_shader_parameter("seal_marks", v), 0.0, 1.0, maxf(grow, 0.01))
	if smat is ShaderMaterial:
		pj.get_tree().create_timer(grow * 0.4).timeout.connect(func():
			if is_instance_valid(smat):
				smat.set_shader_parameter("sage_marks", 4))
	pj.get_tree().create_timer(dur).timeout.connect(func():
		if smat is ShaderMaterial and is_instance_valid(smat) and int(smat.get_shader_parameter("sage_marks")) == 4:
			smat.set_shader_parameter("sage_marks", 0)
		if fmat is ShaderMaterial and is_instance_valid(fmat):
			fmat.set_shader_parameter("seal_marks", 0.0))


# ================================================================== Byakugō no In
## Biriken mühür açılır: önce dağınık mor çakra zerreleri her yönden alna çekilir, alında elmas parlar ve büyük bir ışık
## çakması; yüze ve bütün tene kara mühür çizgileri yayılır (gerçek ten gölgelendiricisi). Yerde ayaklardan kendi kendini
## yazan mor-kara fırça yazısı halkası dışa doğru genişleyip söner. Etki süresince alındaki küçük elmas kalır, her
## yenilenme vuruşunda nabız atar.
static func byakugo_no_in(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.8)
	var purple = Color(0.66, 0.3, 0.92)
	# birikimle orantılı: tam dolu mühür tam iyileşme ve 20 sn, yarım mühür yarı iyileşme ve 10 sn
	var store = clampf(float(Game.profile.get("byakugo_used", 100.0)) / 100.0, 0.5, 1.0) if c is Player else 1.0
	var dur = 20.0 * store
	var head = _bone_pos(c, "Head", Vector3.UP * 1.6)
	_bits(pj, head, {"n": 46, "life": 0.5, "r": 1.5, "surface": true, "radial": -12.0, "v0": 0.0, "v1": 0.3, "grav": 0.0,
		"col": purple.lightened(0.35), "s0": 0.03, "s1": 0.07, "expl": 0.6})
	# alındaki elmas (etki süresi boyunca)
	var ba = pj.bone_attach(c, "Head")
	var dia: MeshInstance3D = null
	if ba:
		dia = _glint(0.0, 0.07, 0.09, Color(1.0, 0.8, 1.0), purple, 0.3)
		ba.add_child(dia)
		dia.position = Vector3(0, 0.1, 0.1)
		dia.scale = Vector3(0.001, 0.001, 1.0)
		var dt = dia.create_tween()
		dt.tween_interval(0.3)
		dt.tween_property(dia, "scale", Vector3(0.07, 0.09, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pj.get_tree().create_timer(dur).timeout.connect(func():
			if is_instance_valid(ba):
				ba.queue_free())
	# açılış çakması + ten çizgileri
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var fd = _flat(c.face_dir())
		var fl = _glint(1.0, 1.4, 1.4, Color(1.0, 0.92, 1.0), purple, 0.8)
		_add(pj, fl, _bone_pos(c, "Head", Vector3.UP * 1.6) + fd * 0.18 + Vector3.UP * 0.08)
		var ft = fl.create_tween()
		ft.tween_property(fl, "scale", Vector3(0.2, 0.2, 1.0), 0.3).set_ease(Tween.EASE_IN)
		_fade_free(fl, 0.05, 0.25)
		# yerde dışa yayılan yazı halkası
		var ring = _mi(_annulus(0.8, 1.0, 72), _script_mat(), {"mode": 0.0, "cells": Vector2(38, 1), "jag": 0.7, "seed": 3.3,
			"ink": Color(0.12, 0.03, 0.16, 1.0), "halo": Color(0.7, 0.35, 0.95, 0.45), "reveal": 0.0, "nf": 1.0})
		_add(pj, ring, pj.gp(c.global_position) + Vector3.UP * 0.05)
		ring.scale = Vector3.ONE * 0.6
		var rt = ring.create_tween()
		rt.tween_property(ring, "scale", Vector3.ONE * 4.5, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tp(ring, "reveal", 0.0, 1.0, 0.5)
		_fade_free(ring, 0.6, 0.5))
	_skin_seal(pj, c, dur, 0.9)
	var hl = store
	pj.heal(c, c.max_hp * hl)
	if c is Player:
		Buffs.add("byakugo", 20.0 * store, {"armor": 0.8, "melee": 1.4, "_name": "Yüz Mühür Gücü", "_desc": "biriken chakra serbest: hızlı yenilenme"})
	pj.every(20.0, 1.0, func(_i, _k):
		if pj.live(c):
			pj.heal(c, c.max_hp * 0.05)
			if is_instance_valid(dia):
				var pt = dia.create_tween()
				pt.tween_property(dia, "scale", Vector3(0.12, 0.15, 1.0), 0.08)
				pt.tween_property(dia, "scale", Vector3(0.07, 0.09, 1.0), 0.25), Callable())
	Sfx.play("heal", c.global_position, 0.7)


# ================================================================== Infūin: Kai
## Kaynak (Tsunade, Yin Mührü Serbest): alındaki elmas eflatun parlar, kaşların üstünden iki yana kıvrılan kara mühür
## çizgileri taç gibi açılır ve tene çekilir; yüz / ten çizgileri anında belirir. Hücreler yenilendikçe her yarım saniyede
## ayaktan başa ince eflatun bir yenilenme halkası bedeni tarar.
static func infuin_kai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var mag = Color(0.85, 0.25, 0.75)
	var hold = _follow(pj, c, "Head", Vector3.UP * 1.6, 0.11, 0.08, 1.2)
	var fl = _glint(1.0, 0.9, 0.9, Color(1.0, 0.85, 1.0), mag, 0.6)
	hold.add_child(fl)
	var ft = fl.create_tween()
	ft.tween_property(fl, "scale", Vector3(0.12, 0.12, 1.0), 0.35).set_ease(Tween.EASE_IN)
	var dia = _glint(0.0, 0.08, 0.1, Color(1.0, 0.75, 1.0), mag, 0.3)
	hold.add_child(dia)
	# kıvrık taç çizgileri (alın düzleminde, yerel X sağ / Y yukarı)
	for k in 6:
		var sx = -1.0 if k % 2 == 0 else 1.0
		var lvl = floorf(k / 2.0)
		var pts = []
		var rr = []
		for i in 12:
			var u = float(i) / 11.0
			var x = sx * (0.02 + 0.13 * u + lvl * 0.03)
			var y = 0.01 + (0.05 + lvl * 0.03) * sin(u * PI * 0.8) - lvl * 0.04 * u
			if u > 0.65:
				var cu = (u - 0.65) / 0.35 * PI * 1.4
				x += sx * 0.03 * sin(cu)
				y -= 0.03 * (1.0 - cos(cu))
			pts.append(Vector3(x, y, -0.01 * u))
			rr.append(0.008 * (1.0 - u * 0.7))
		var tm = _mi(_mesh(_tube(pts, rr, 4)), _energy_mat(), {"pat": 5.0, "c_core": Color(0.08, 0.02, 0.08), "c_edge": Color(0.0, 0.0, 0.0), "reveal": 0.0, "nf": 0.3})
		hold.add_child(tm)
		_tp(tm, "reveal", 0.0, 1.0, 0.18, 0.05 + lvl * 0.04)
		_tp(tm, "alpha", 1.0, 0.0, 0.3, 0.8)
	_skin_seal(pj, c, 6.0, 0.15)
	pj.heal(c, c.max_hp * 0.5)
	if c is Player:
		Buffs.add("infuin_kai", 6.0, {"armor": 0.9, "_name": "Yin Mührü", "_desc": "hücreler anında yenilenir: her 0.5 sn can"})
	var ring_pts = []
	var ring_r = []
	for i in 25:
		var a = TAU * i / 24.0
		ring_pts.append(Vector3(cos(a), 0.0, sin(a)) * 0.48)
		ring_r.append(0.014)
	var ring_mesh = _mesh(_tube(ring_pts, ring_r, 4))
	pj.every(6.0, 0.5, func(_i, _k):
		if pj.live(c):
			pj.heal(c, c.max_hp * 0.06)
			var rg = _mi(ring_mesh, _energy_mat(), {"pat": 2.0, "c_core": Color(1.0, 0.85, 1.0), "c_edge": mag, "nf": 0.8})
			c.add_child(rg)
			rg.position = Vector3.UP * 0.1
			var rt = rg.create_tween()
			rt.tween_property(rg, "position:y", 1.9, 0.45)
			_fade_free(rg, 0.2, 0.25), Callable())
	Sfx.play("heal", c.global_position, 0.6)


# ================================================================== Isshi Tōjin
## Kaynak (Iruka / Kakashi gaiden ışık iplik dizilimi): yerde mavi bir ışık alanı ve üç iç içe halka halinde kara, titrek el
## yazısı mühür formülü kendini yazar; ardından alanın kenarından kenarına alçakta kemerlenen ışık ipleri ağ örer. Ağ yavaşça
## döner; alana giren her rakibe yerden bir ışık ipi uzanıp bağlar. Altı saniye sonra yazı ve ağ söner.
static func isshi_tojin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 20.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 7.0)
	var root = Node3D.new()
	_add(pj, root, at + Vector3.UP * 0.05)
	var field = _flat_quad(9.8, 9.8, {"mode": 3.0, "base": Color(0.14, 0.34, 0.8, 0.42), "ink": Color(0.04, 0.06, 0.14, 1.0), "seed": 2.1, "reveal": 1.0, "nf": 1.2})
	root.add_child(field)
	field.position = Vector3.UP * 0.02
	for k in 3:
		var rm = 2.05 + k * 1.3
		var ring = _mi(_annulus(rm - 0.24, rm + 0.24, 96), _script_mat(), {"mode": 0.0, "cells": Vector2(roundf(TAU * rm / 0.44), 1), "jag": 1.0,
			"seed": 5.0 + k * 1.7, "ink": INK, "halo": Color(0.75, 0.9, 1.0, 0.5), "reveal": 0.0, "nf": 1.2})
		root.add_child(ring)
		ring.position = Vector3.UP * (0.05 + k * 0.004)
		_tp(ring, "reveal", 0.0, 1.0, 0.5, 0.1 + k * 0.12)
	# ışık ipleri ağı
	var parts = []
	for k in 7:
		var a1 = k * TAU / 7.0
		var a2 = a1 + PI + 0.55
		var p1 = Vector3(cos(a1), 0.0, sin(a1)) * 4.6 + Vector3.UP * 0.1
		var p2 = Vector3(cos(a2), 0.0, sin(a2)) * 4.6 + Vector3.UP * 0.1
		var mid = (p1 + p2) * 0.5 + Vector3.UP * (0.7 + 0.25 * float(k % 3))
		var pts = []
		var rr = []
		for i in 12:
			pts.append(_bez(p1, mid, p2, float(i) / 11.0))
			rr.append(0.016)
		parts.append(_tube(pts, rr, 5))
	var web = _mi(_mesh(_merge(parts)), _energy_mat(), {"pat": 5.0, "c_core": Color(0.95, 0.98, 1.0), "c_edge": Color(0.45, 0.75, 1.0), "reveal": 0.0, "nf": 1.0})
	root.add_child(web)
	_tp(web, "reveal", 0.0, 1.0, 0.3, 0.5)
	root.scale = Vector3.ONE * 0.05
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.4)
	tw.parallel().tween_property(root, "rotation:y", TAU, 6.0)
	tw.tween_callback(root.queue_free)
	_fade_free(root, 5.5, 0.45)
	pj.every(6.0, 0.5, func(_i, _k):
		for e in pj.enemies_near(c, at, 4.8):
			pj.st(e, "bind", 0.6)
			var g = pj.gp(e.global_position) + Vector3(randf_range(-1.4, 1.4), 0.05, randf_range(-1.4, 1.4))
			var w = e.global_position + Vector3.UP * 0.9
			var pts = []
			var rr = []
			for i in 8:
				var u = float(i) / 7.0
				pts.append(_bez(g, (g + w) * 0.5 + Vector3.UP * 0.4, w, u))
				rr.append(0.018)
			var th = _mi(_mesh(_tube(pts, rr, 5)), _energy_mat(), {"pat": 5.0, "c_core": Color(0.95, 0.98, 1.0), "c_edge": Color(0.45, 0.75, 1.0), "reveal": 0.0, "nf": 1.0})
			_add(pj, th, Vector3.ZERO)
			_tp(th, "reveal", 0.0, 1.0, 0.08)
			_fade_free(th, 0.15, 0.3)
			pj.chakra_gain(c, 2.0), Callable())
	Sfx.play("seal", at, 0.9)


# ================================================================== Kaibi Hōin
## Kaynak (Akatsuki çekip çıkarma, Kurama çakra başı): hedefin altında çift halkalı mühür formülü yazılır, dört yandan
## yerden çakra zincirleri fırlayıp gövdeye kenetlenir. Hedefin göğsünden bijūnun kendi renginde (gerçek bijū verisi) yarı
## saydam, kara damarlı, parlak konturlu çakra sütunu yükselir; ucunda kükreyen bijū başı belirir ve çene açılıp kapanır.
## Çekiliş boyunca çakra parçaları göğüsten kopup yukarı akar; sonunda baş göğe dağılır, zincirler ve formül söner.
static func kaibi_hoin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.4)
	if tt == null:
		return
	var teal = Color(0.4, 0.95, 0.85)
	var s = ClanJutsu.body_scale(tt)
	var base = pj.gp(tt.global_position)
	var bc = _beast_chakra(tt, Color(0.95, 0.22, 0.12))
	var be = bc.lerp(Color(1.0, 0.65, 0.15), 0.6).lightened(0.15)
	var sr = minf(7.0 * s, 60.0)
	var seal = _flat_quad(sr, sr, {"mode": 2.0, "cells": Vector2(20, 1), "ink": Color(0.03, 0.12, 0.12, 1.0), "halo": Color(0.45, 1.0, 0.9, 0.55),
		"base": Color(0.2, 0.6, 0.55, 0.12), "seed": 7.7, "reveal": 0.0, "nf": 1.5})
	_add(pj, seal, base + Vector3.UP * 0.05)
	_tp(seal, "reveal", 0.0, 1.0, 0.45)
	_fade_free(seal, 2.4, 0.4)
	pj.st(tt, "bind", 2.6)
	var chest = func() -> Vector3:
		return tt.global_position + Vector3.UP * (float(tt.get("height")) * 0.55 if tt.get("height") != null else 1.0) if is_instance_valid(tt) else base + Vector3.UP
	# zincirler
	for k in 4:
		var a = PI * 0.25 + k * PI * 0.5
		var anchor = base + Vector3(cos(a), 0.0, sin(a)) * 3.0 * s + Vector3.UP * 0.05
		var L0 = anchor.distance_to(chest.call())
		var ch = _mi(_chain_mesh(L0, 0.26 * minf(s, 4.0), 0.08 * minf(s, 4.0), 0.025 * minf(s, 4.0)), _energy_mat(),
			{"pat": 0.0, "c_core": Color(0.85, 1.0, 0.97), "c_edge": teal, "links": 10.0, "reveal": 0.0, "nf": 1.2})
		_add(pj, ch, anchor)
		var aim = func(_v: float):
			if not is_instance_valid(ch):
				return
			var tp: Vector3 = chest.call()
			var dv = tp - anchor
			var bz = _basis_z(dv)
			bz.z *= dv.length() / maxf(L0, 0.01)
			ch.global_transform = Transform3D(bz, anchor)
		aim.call(0.0)
		var ctw = ch.create_tween()
		ctw.tween_method(aim, 0.0, 1.0, 2.6)
		ctw.tween_callback(ch.queue_free)
		_tp(ch, "reveal", 0.0, 1.0, 0.22, 0.15 + k * 0.06)
		_tp(ch, "alpha", 1.0, 0.0, 0.3, 2.3)
	# bijū çakra sütunu + baş
	var rise = 3.6 * s
	var head = _beast_head()
	_add(pj, head, chest.call())
	head.scale = Vector3.ONE * 0.01
	for mi in [head.get_node("up").get_child(0), head.get_node("jaw").get_child(0)]:
		_set_all(mi, "pat", 3.0)
		_set_all(mi, "c_core", bc)
		_set_all(mi, "c_edge", be)
		_set_all(mi, "nf", 1.5)
	var top_at = func(tm: float) -> Vector3:
		var g = clampf((tm - 0.25) / 0.6, 0.0, 1.0)
		var lift = maxf(0.0, tm - 2.1) * 3.0 * s
		return chest.call() + Vector3.UP * (rise * (1.0 - pow(1.0 - g, 2.0)) + lift) + Vector3(sin(tm * 2.3), 0.0, cos(tm * 1.7)) * 0.25 * s
	var plume = _live(pj, _energy_mat(), {"pat": 3.0, "c_core": bc, "c_edge": be, "seed": 1.3, "nf": 1.5}, 2.6, func(tm: float) -> Array:
		if tm < 0.25:
			return []
		var a: Vector3 = chest.call()
		var b: Vector3 = top_at.call(tm)
		var pts = []
		var rr = []
		for i in 14:
			var u = float(i) / 13.0
			var p = a.lerp(b, u) + Vector3(sin(u * 5.0 + tm * 5.0), 0.0, cos(u * 4.0 + tm * 4.0)) * 0.18 * s * u
			pts.append(p)
			rr.append((0.22 + 0.32 * u) * s)
		return _tube(pts, rr, 9))
	_tp(plume, "alpha", 1.0, 0.0, 0.35, 2.2)
	var htw = head.create_tween()
	htw.tween_method(func(tm: float):
		if not is_instance_valid(head):
			return
		var hp: Vector3 = top_at.call(tm)
		var dc = _flat(c.global_position - tt.global_position) if is_instance_valid(tt) and is_instance_valid(c) else Vector3.FORWARD
		head.global_transform = Transform3D(_basis_z(Vector3.UP * 0.75 + dc * 0.45), hp)
		var sc = clampf((tm - 0.3) / 0.35, 0.0, 1.0) * 1.1 * s
		head.scale = Vector3.ONE * maxf(sc, 0.01)
		var jaw: Node3D = head.get_node("jaw")
		jaw.rotation.x = 0.15 + 0.4 * absf(sin(tm * 5.0)), 0.0, 2.6, 2.6)
	htw.tween_callback(head.queue_free)
	_tp(head, "alpha", 1.0, 0.0, 0.35, 2.2)
	pj.every(2.4, 0.15, func(i, _k):
		if not (pj.live(c) and pj.live(tt)):
			return
		if i % 3 == 0:
			_bits(pj, chest.call(), {"n": 7, "life": 0.6, "r": 0.4 * s, "dir": Vector3.UP, "spread": 18.0, "v0": 5.0 * minf(s, 3.0),
				"v1": 9.0 * minf(s, 3.0), "grav": -2.0, "col": bc.lightened(0.2), "s0": 0.08 * minf(s, 4.0), "s1": 0.16 * minf(s, 4.0)})
		tt.take_hit(pj.inf(c, "kaibi_hoin", 0.15, {"knock": 0.0, "kind": "light", "chakra_drain": 8.0}))
		pj.chakra_gain(c, 3.0), Callable())
	Sfx.play("seal", tt.global_position, 0.6)


# ================================================================== Bijū Fūin
## Kaynak (bijūyu saran nane yeşili mühür kolları): hedefin altında yeşil-kara mühür formülü yazılır; formülden altı kalın,
## içi parlak nane yeşili çakra kolu kalkıp çaprazlama sarmal çizerek bedene dolanır ve sıkar (kuyruklu canavarda kendi
## boyunda). Başın üstünde 封 mührü belirir. Hedef bijū / jinchūriki ise kendi çakra renginde (gerçek bijū verisi) çakra
## damlaları formüle emilir. Süre sonunda kollar formüle geri çekilir, mühür söner.
static func biju_fuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.0)
	if tt == null:
		return
	var green = Color(0.45, 1.0, 0.6)
	var s = ClanJutsu.body_scale(tt)
	var h = float(tt.get("height")) if tt.get("height") != null else 1.8
	var rad = float(tt.get("radius")) if tt.get("radius") != null else 0.4
	var rc_end = maxf(rad * 1.35, 0.5)
	var seal_r = minf(2.6 * s, 40.0)
	var seal = _flat_quad(seal_r * 2.0, seal_r * 2.0, {"mode": 2.0, "cells": Vector2(18, 1), "ink": Color(0.02, 0.14, 0.06, 1.0), "halo": Color(0.55, 1.0, 0.7, 0.55),
		"base": Color(0.3, 0.9, 0.5, 0.1), "seed": 4.2, "reveal": 0.0, "nf": 1.5})
	_add(pj, seal, pj.gp(tt.global_position) + Vector3.UP * 0.05)
	_tp(seal, "reveal", 0.0, 1.0, 0.35)
	_fade_free(seal, 4.8, 0.4)
	for k in 6:
		var a0 = k * TAU / 6.0
		var sd = 1.0 if k % 2 == 0 else -1.0
		var arm_fn = func(tm: float) -> Array:
			if not is_instance_valid(tt):
				return []
			var o = tt.global_position
			var g = clampf(tm / 0.6, 0.0, 1.0)
			var rc = lerpf(rc_end * 2.8, rc_end, 1.0 - pow(1.0 - g, 3.0)) * (1.0 + 0.04 * sin(tm * 6.0 + k))
			var start = pj.gp(o + Vector3(cos(a0), 0.0, sin(a0)) * seal_r * 0.8) + Vector3.UP * 0.05
			var ca = a0 + 0.6 * sd
			var coil0 = o + Vector3(cos(ca), 0.0, sin(ca)) * rc + Vector3.UP * h * 0.12
			var pts = []
			var rr = []
			for i in 8:
				var u = float(i) / 8.0
				pts.append(_bez(start, start.lerp(coil0, 0.5) + Vector3.UP * h * 0.25, coil0, u))
			for i in 19:
				var u = float(i) / 18.0
				var an = ca + sd * u * TAU * 0.85
				pts.append(o + Vector3(cos(an), 0.0, sin(an)) * rc + Vector3.UP * h * lerpf(0.12, 0.88 - 0.05 * float(k % 3), u))
			for i in pts.size():
				var u = float(i) / float(pts.size() - 1)
				rr.append(lerpf(0.15, 0.07, u) * minf(s, 10.0) * (1.0 if i < pts.size() - 1 else 0.4))
			return _tube(pts, rr, 8)
		var arm = _live(pj, _energy_mat(), {"pat": 2.0, "c_core": Color(0.92, 1.0, 0.95), "c_edge": green, "seed": k * 1.9, "reveal": 0.0, "nf": 1.5}, 5.0, arm_fn)
		_tp(arm, "reveal", 0.0, 1.0, 0.35, k * 0.05)
		_tp(arm, "reveal", 1.0, 0.0, 0.4, 4.55)
	var lbl = Label3D.new()
	lbl.text = "封"
	lbl.font_size = 160
	lbl.pixel_size = 0.006 * minf(s, 8.0)
	lbl.modulate = Color(0.85, 1.0, 0.88)
	lbl.outline_modulate = Color(0.02, 0.2, 0.08)
	lbl.outline_size = 30
	lbl.shaded = false
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tt.add_child(lbl)
	lbl.position = Vector3.UP * (h + 0.7 * minf(s, 8.0))
	lbl.scale = Vector3.ONE * 0.05
	var lt = lbl.create_tween()
	lt.tween_interval(0.4)
	lt.tween_property(lbl, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_interval(4.0)
	lt.tween_property(lbl, "modulate:a", 0.0, 0.3)
	lt.tween_callback(lbl.queue_free)
	var bc = _beast_chakra(tt, Color(0, 0, 0, 0))
	if bc.a > 0.0:
		var drain = _bits(pj, tt.global_position, {"one_shot": false, "n": 24, "life": 0.7, "r": rc_end * 1.2, "dir": Vector3.DOWN, "spread": 40.0,
			"v0": 1.0, "v1": 3.0, "grav": 14.0, "col": bc, "s0": 0.06 * minf(s, 6.0), "s1": 0.12 * minf(s, 6.0), "parent": tt, "off": Vector3.UP * h * 0.55})
		var dw = weakref(drain)
		pj.get_tree().create_timer(4.5).timeout.connect(func():
			var d0 = dw.get_ref()
			if d0 != null and is_instance_valid(d0):
				d0.emitting = false)
		pj.get_tree().create_timer(5.5).timeout.connect(func():
			var d1 = dw.get_ref()
			if d1 != null and is_instance_valid(d1):
				d1.queue_free())
	pj.st(tt, "bind", 5.0)
	Sfx.play("seal", tt.global_position, 0.6)


# ================================================================== Kaija Hōin
## Kaynak (lanet mühründen fışkıran Orochimaru ruhu): kullananın ağzından yarı saydam, pullu, beyaz-mavi hayalet bir yılan
## kıvrılarak çıkar ve hedefe atılır; çenesi ardına kadar açılır, hedefin gövdesine kapanır. Dişlerin değdiği yerde üç ince
## hayalet yılan bedene dolanır; bağ boyunca hedeften mor zehir zerreleri kalkar. Sonunda ruh solup kaybolur.
static func kaija_hoin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var pale = Color(0.86, 0.92, 0.97)
	var dim = Color(0.32, 0.4, 0.58)
	var last = {"m": pj._mouth_pos(c), "b": tt.global_position + Vector3.UP * 1.1}
	var mouth = func() -> Vector3:
		if pj.live(c):
			last["m"] = pj._mouth_pos(c)
		return last["m"]
	var bite = func() -> Vector3:
		if is_instance_valid(tt):
			last["b"] = tt.global_position + Vector3.UP * (float(tt.get("height")) * 0.6 if tt.get("height") != null else 1.1)
		return last["b"]
	var head_at = func(tm: float) -> Vector3:
		var g = clampf(tm / 0.3, 0.0, 1.0)
		var m: Vector3 = mouth.call()
		var b: Vector3 = bite.call()
		var back = _flat(b - m) * -0.25
		return _bez(m, (m + b) * 0.5 + Vector3.UP * 1.6, b + back, 1.0 - pow(1.0 - g, 2.0))
	var body = _live(pj, _energy_mat(), {"pat": 1.0, "c_core": pale, "c_edge": dim, "links": 22.0, "seed": 0.4, "nf": 1.2}, 2.5, func(tm: float) -> Array:
		var m: Vector3 = mouth.call()
		var b: Vector3 = bite.call()
		var hp: Vector3 = head_at.call(tm)
		var mid = (m + hp) * 0.5 + Vector3.UP * 1.4
		var sw = _flat(b - m).cross(Vector3.UP)
		var pts = []
		var rr = []
		for i in 18:
			var u = float(i) / 17.0
			pts.append(_bez(m, mid, hp, u) + sw * sin(u * 9.0 - tm * 9.0) * 0.18 * sin(u * PI))
			rr.append(lerpf(0.08, 0.3, minf(u * 2.2, 1.0)) * (1.0 - 0.15 * u))
		return _tube(pts, rr, 9))
	_tp(body, "alpha", 1.0, 0.0, 0.3, 2.2)
	var head = _snake_head()
	_add(pj, head, mouth.call())
	for mi in [head.get_node("up").get_child(0), head.get_node("jaw").get_child(0)]:
		_set_all(mi, "pat", 1.0)
		_set_all(mi, "c_core", pale)
		_set_all(mi, "c_edge", dim)
		_set_all(mi, "links", 6.0)
		_set_all(mi, "nf", 1.2)
	var htw = head.create_tween()
	htw.tween_method(func(tm: float):
		if not is_instance_valid(head):
			return
		var hp: Vector3 = head_at.call(tm)
		var b: Vector3 = bite.call()
		var m0: Vector3 = mouth.call()
		var dir = (b - hp) if tm > 0.28 else (b - m0)
		head.global_transform = Transform3D(_basis_z(_flat(dir) + Vector3.DOWN * 0.15), hp)
		head.scale = Vector3.ONE * 1.25
		var op = clampf(tm / 0.22, 0.0, 1.0) if tm < 0.3 else clampf(1.0 - (tm - 0.3) / 0.1, 0.25, 1.0)
		var upj: Node3D = head.get_node("up")
		var jaw: Node3D = head.get_node("jaw")
		upj.rotation.x = -0.75 * op
		jaw.rotation.x = 0.6 * op, 0.0, 2.5, 2.5)
	htw.tween_callback(head.queue_free)
	_tp(head, "alpha", 1.0, 0.0, 0.3, 2.2)
	# dolanan küçük hayalet yılanlar
	for k in 3:
		var coil_fn = func(tm: float) -> Array:
			if not is_instance_valid(tt):
				return []
			var o = tt.global_position
			var hh = float(tt.get("height")) if tt.get("height") != null else 1.8
			var rr0 = (float(tt.get("radius")) if tt.get("radius") != null else 0.4) + 0.08
			var pts = []
			var rr = []
			for i in 20:
				var u = float(i) / 19.0
				var an = k * TAU / 3.0 + u * TAU * 1.3 + tm * 0.8
				pts.append(o + Vector3(cos(an), 0.0, sin(an)) * rr0 + Vector3.UP * hh * lerpf(0.15 + k * 0.08, 0.75 - k * 0.05, u))
				rr.append(0.055 * (1.0 - 0.6 * u))
			return _tube(pts, rr, 6)
		var coil = _live(pj, _energy_mat(), {"pat": 1.0, "c_core": pale, "c_edge": dim, "links": 30.0, "seed": k * 2.0, "reveal": 0.0, "nf": 1.0}, 2.2, coil_fn)
		_tp(coil, "reveal", 0.0, 1.0, 0.25, 0.3 + k * 0.05)
		_tp(coil, "alpha", 1.0, 0.0, 0.3, 1.9)
	pj.st(tt, "bind", 2.5)
	pj.every(2.5, 0.5, func(_i, _k):
		if pj.live(tt):
			_bits(pj, tt.global_position + Vector3.UP, {"n": 10, "life": 0.7, "r": 0.45, "dir": Vector3.UP, "spread": 50.0, "v0": 0.5, "v1": 1.6,
				"grav": -0.5, "col": Color(0.5, 0.22, 0.62), "s0": 0.04, "s1": 0.08})
			tt.take_hit(pj.inf(c, "kaija_hoin", 0.25, {"knock": 0.0, "kind": "light", "poison": 2.0})), Callable())
	Sfx.play("genjutsu", tt.global_position, 0.7)


# ================================================================== Kaifū no Jutsu
## Kaynak (parşömenden shuriken açılması): önde yere bir parşömen iki rulosundan açılır, üstündeki kara yazı ortadan dışa
## kendini yazar; yazının ortasından kısa bir beyaz tören bulutu halkası patlar ve mühürlü shuriken dönerek yükselip elinize
## uçar. Parşömen yeniden sarılıp kaybolur.
static func kaifu_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var fd = _flat(c.face_dir())
	var rt = Vector3.UP.cross(fd).normalized()
	var at = pj.gp(c.global_position + fd * 1.3) + Vector3.UP * 0.04
	var rig = Node3D.new()
	_add(pj, rig, at)
	rig.global_basis = Basis(rt, Vector3.UP, fd)
	var paper = _flat_quad(1.6, 0.6, {"mode": 0.0, "cells": Vector2(9, 2), "base": PAPER, "ink": INK, "seed": 8.1, "reveal": 0.0, "nf": 0.8})
	rig.add_child(paper)
	paper.scale = Vector3(0.04, 1, 1)
	var rolls = []
	for sx in [-1.0, 1.0]:
		var rl = _cel(_quad_roll(), PAPER, PAPER.darkened(0.25), 0.012, {"nf": 0.8})
		rig.add_child(rl)
		rl.position = Vector3(sx * 0.04, 0.05, 0)
		rl.rotation.x = PI * 0.5
		rolls.append(rl)
		var rtw = rl.create_tween()
		rtw.tween_property(rl, "position:x", sx * 0.82, 0.25).set_ease(Tween.EASE_OUT)
		rtw.tween_interval(0.8)
		rtw.tween_property(rl, "position:x", sx * 0.04, 0.22).set_ease(Tween.EASE_IN)
	var ptw = paper.create_tween()
	ptw.tween_property(paper, "scale:x", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	ptw.tween_interval(0.8)
	ptw.tween_property(paper, "scale:x", 0.04, 0.22).set_ease(Tween.EASE_IN)
	_tp(paper, "reveal", 0.0, 1.0, 0.3, 0.25)
	pj.free_after(1.35, rig)
	# tören bulutu + shuriken
	pj.after(0.55, func():
		for k in 9:
			var a = k * TAU / 9.0 + randf() * 0.3
			var lb = _cel(_lobe_mesh(), Color(0.97, 0.97, 0.99), Color(0.75, 0.74, 0.8), 0.015, {"nf": 0.8, "seed": k * 1.3})
			_add(pj, lb, at + (rt * cos(a) * 0.55 + fd * sin(a) * 0.22) + Vector3.UP * 0.12)
			lb.scale = Vector3.ONE * 0.05
			var sz = randf_range(0.3, 0.48)
			var ltw = lb.create_tween()
			ltw.tween_property(lb, "scale", Vector3(sz, sz * 0.75, sz), 0.15).set_ease(Tween.EASE_OUT)
			ltw.parallel().tween_property(lb, "global_position", lb.global_position + (rt * cos(a) + fd * sin(a)) * 0.35 + Vector3.UP * 0.15, 0.4)
			_fade_free(lb, 0.15, 0.3)
		var sh = _cel(_shuriken_mesh(), Color.WHITE, Color(0.6, 0.6, 0.65), 0.012, {"vc": 1.0, "nf": 0.6})
		_add(pj, sh, at + Vector3.UP * 0.05)
		sh.global_basis = Basis(rt, fd, -Vector3.UP).scaled(Vector3.ONE * 1.4)
		var stw = sh.create_tween()
		stw.tween_method(func(tm: float):
			if not is_instance_valid(sh):
				return
			var hand = pj.live_hand(c, true) if pj.live(c) else at + Vector3.UP
			var rise = at + Vector3.UP * 1.0
			var p = at.lerp(rise, minf(tm / 0.3, 1.0)) if tm < 0.3 else rise.lerp(hand, (tm - 0.3) / 0.2)
			var sc = 1.4 if tm < 0.38 else lerpf(1.4, 0.05, (tm - 0.38) / 0.12)
			sh.global_transform = Transform3D(Basis(Vector3.UP, tm * 22.0) * Basis(rt, fd, -Vector3.UP).scaled(Vector3.ONE * sc), p), 0.0, 0.5, 0.5)
		stw.tween_callback(sh.queue_free))
	_utility_buff(c, "kaifu_no_jutsu", Color(0.95, 0.92, 0.82))


static func _quad_roll() -> CylinderMesh:
	if not _cache.has("mesh:roll"):
		var cm = CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 0.66
		cm.radial_segments = 10
		_cache["mesh:roll"] = cm
	return _cache["mesh:roll"]


# ================================================================== Fūinjutsu: Kai
## Kaynak (göğüsteki mühür avuçla çözülür): göğsün önünde beyaz-camgöbeği ışıkla parlayan mühür formülü (halkalar, yazı
## halkası, dört kol, orta sarmal) kendini yazar. Çözülme anında formül genişleyip söner, yatay bir ışık çizgisi çakar ve
## mühür yazısının harfleri göğüsten dışa savrulup dağılır.
static func fuinjutsu_kai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var hold = _follow(pj, c, "UpperChest", Vector3.UP * 1.3, 0.22, 0.0, 1.3)
	var cyan = Color(0.35, 0.75, 1.0)
	var disc = _mi(_quad(0.6, 0.6), _script_mat(), {"mode": 2.0, "cells": Vector2(12, 1), "ink": Color(0.88, 0.98, 1.0, 1.0), "halo": Color(0.3, 0.7, 1.0, 0.6),
		"base": Color(0.55, 0.85, 1.0, 0.15), "seed": 2.6, "reveal": 0.0, "nf": 0.5})
	hold.add_child(disc)
	_tp(disc, "reveal", 0.0, 1.0, 0.55)
	pj.after(0.8, func():
		if not pj.live(c) or not is_instance_valid(hold):
			return
		var dtw = disc.create_tween()
		dtw.tween_property(disc, "scale", Vector3.ONE * 2.4, 0.35).set_ease(Tween.EASE_OUT)
		_fade_free(disc, 0.0, 0.35)
		var cp = hold.global_position
		var b = hold.global_basis
		var streak = _glint(1.0, 1.8, 0.35, Color(0.95, 1.0, 1.0), cyan, 0.6)
		_add(pj, streak, cp)
		_fade_free(streak, 0.05, 0.3)
		for k in 10:
			var a = k * TAU / 10.0 + randf() * 0.3
			var fl = _mi(_quad(0.13, 0.13), _script_mat(), {"mode": 0.0, "cells": Vector2(1, 1), "ink": Color(0.85, 0.97, 1.0, 1.0), "halo": Color(0.3, 0.7, 1.0, 0.5),
				"seed": 11.0 + k, "reveal": 1.0, "nf": 0.5})
			_add(pj, fl, cp)
			fl.global_basis = b
			var dir = (b.x * cos(a) + b.y * sin(a)) * 1.3 + b.z * 0.5
			var ftw = fl.create_tween()
			ftw.tween_property(fl, "global_position", cp + dir, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			_fade_free(fl, 0.25, 0.35))
	_utility_buff(c, "fuinjutsu_kai", Color(0.55, 0.85, 1.0))


# ================================================================== Fūinjutsu: Okutopasu Hōrudo
## Kaynak (Killer B'nin ahtapot mürekkebi): yere bir parşömen açılır ve yazısı yazılır; parşömenden parlak kara, vantuzlu
## mürekkep dokunaçları fışkırıp en yakın dört rakibe kemer çizerek atılır ve bedenlerine dolanır. Dokunaç değdiği an hedefin
## gövdesi topak topak kara-kahve mürekkep balçığıyla kaplanır; balçıktan sarkan damlalar zamanla yere uzar, altta mürekkep
## gölü yayılır. Bağ çözülünce balçık eriyip söner.
static func fuinjutsu_okutopasu_horudo(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	var center = pj.gp(Jutsu._aim_ground(c, t, 6.0, 16.0))
	var fd = _flat(center - c.global_position)
	var rt = Vector3.UP.cross(fd).normalized()
	# kullananın önünde mürekkep fışkırması
	_bits(pj, pj.gp(c.global_position + c.face_dir() * 2.0) + Vector3.UP * 0.2, {"n": 26, "life": 0.8, "r": 0.5, "dir": Vector3.UP, "spread": 50.0,
		"v0": 2.0, "v1": 5.0, "col": Color(0.04, 0.035, 0.045), "s0": 0.07, "s1": 0.16})
	# parşömen (3 x 1)
	var rig = Node3D.new()
	_add(pj, rig, center + Vector3.UP * 0.05)
	rig.global_basis = Basis(rt, Vector3.UP, fd)
	var paper = _flat_quad(3.0, 1.0, {"mode": 0.0, "cells": Vector2(14, 2), "base": PAPER, "ink": INK, "seed": 6.6, "reveal": 0.0, "nf": 1.0})
	rig.add_child(paper)
	_tp(paper, "reveal", 0.0, 1.0, 0.3)
	_fade_free(rig, 4.0, 0.3)
	var inkc = Color(0.05, 0.045, 0.05)
	var list = pj.enemies_near(c, center, 12.0).slice(0, 4)
	var meshes = _goo_meshes()
	for e in list:
		var ek = list.find(e)
		var from = center + Vector3.UP * 0.1 + rt * (float(ek) - 1.5) * 0.5
		var tent = _live(pj, _energy_mat(), {"pat": 4.0, "c_core": inkc, "c_edge": inkc, "links": 16.0, "reveal": 0.0, "nf": 1.2}, 3.5, func(tm: float) -> Array:
			var tgt = e.global_position if is_instance_valid(e) else center
			var hh = float(e.get("height")) if is_instance_valid(e) and e.get("height") != null else 1.8
			var r0 = (float(e.get("radius")) if is_instance_valid(e) and e.get("radius") != null else 0.4) + 0.14
			var dv = _flat(tgt - from)
			var a0 = atan2(-dv.z, -dv.x)
			var grab = tgt + Vector3(cos(a0), 0.0, sin(a0)) * r0 + Vector3.UP * hh * 0.65
			var sw = dv.cross(Vector3.UP)
			var pts = []
			var rr = []
			for i in 12:
				var u = float(i) / 12.0
				pts.append(_bez(from, (from + grab) * 0.5 + Vector3.UP * 2.4, grab, u) + sw * sin(u * 6.0 + tm * 5.0 + ek) * 0.2 * sin(u * PI))
			for i in 14:
				var u = float(i) / 13.0
				var an = a0 + u * TAU * 1.25
				pts.append(tgt + Vector3(cos(an), 0.0, sin(an)) * r0 + Vector3.UP * hh * lerpf(0.65, 0.3, u))
			for i in pts.size():
				rr.append(lerpf(0.24, 0.06, float(i) / float(pts.size() - 1)))
			return _tube(pts, rr, 8))
		_tp(tent, "reveal", 0.0, 1.0, 0.3, ek * 0.05)
		_tp(tent, "alpha", 1.0, 0.0, 0.3, 3.2)
		# balçık + damlalar + göl (hedefin kendisine bağlı)
		pj.after(0.28 + ek * 0.05, func():
			if not is_instance_valid(e):
				return
			var goo = _cel(meshes[0], Color(0.1, 0.075, 0.06), Color(0.035, 0.028, 0.025), 0.02, {"gloss": 0.55, "seed": ek * 1.7, "nf": 1.2})
			e.add_child(goo)
			var fs = ClanJutsu.body_scale(e)
			goo.scale = Vector3.ONE * 0.05
			var gtw = goo.create_tween()
			gtw.tween_property(goo, "scale", Vector3.ONE * fs, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var drips = _cel(meshes[1], Color(0.1, 0.075, 0.06), Color(0.035, 0.028, 0.025), 0.015, {"gloss": 0.4, "seed": ek * 2.3, "nf": 1.2})
			goo.add_child(drips)
			drips.position = Vector3.UP * 0.95
			drips.scale = Vector3(1, 0.3, 1)
			var dtw = drips.create_tween()
			dtw.tween_property(drips, "scale:y", 1.35, 3.0).set_ease(Tween.EASE_OUT)
			var pud = _cel(meshes[2], Color(0.08, 0.06, 0.05), Color(0.03, 0.025, 0.02), 0.0, {"gloss": 0.6, "seed": ek * 3.1, "nf": 1.2})
			_add(pj, pud, pj.gp(e.global_position) + Vector3.UP * 0.02)
			pud.scale = Vector3(0.2 * fs, 1, 0.2 * fs)
			var ptw = pud.create_tween()
			ptw.tween_property(pud, "scale", Vector3(fs, 1, fs), 1.2).set_ease(Tween.EASE_OUT)
			_fade_free(goo, 3.2, 0.4)
			_fade_free(pud, 3.6, 0.5))
		pj.st(e, "bind", 3.5)
		pj.every(3.5, 0.5, func(_i, _k):
			if pj.live(e):
				pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "fuinjutsu_okutopasu_horudo", 0.2, {"knock": 0.0})))
	_bits(pj, center + Vector3.UP, {"n": 40, "life": 0.6, "r": 0.4, "dir": Vector3.UP, "spread": 70.0, "v0": 3.0, "v1": 7.0, "col": Color(0.04, 0.04, 0.06), "s0": 0.08, "s1": 0.18})
	Sfx.play("water", center, 0.5)


# ================================================================== Shikokumujin
## Shikokumujin (Dört Kara Sis Savaş Dizilimi): hedefin dört köşesinde gökten kara sis sütunları iner, aralarını yukarıdan
## aşağı dolan kara-mor sis küpü kapatır (mor bariyer kenarları, yüzeyde aşağı akan sis). Hedef içeride yalıtılıp mühürlenir;
## çakrası kesildikçe yüzeyde mor çakra kıvılcımları çakar. Süre bitince küp aşağıdan eriyip dağılır. Kamera küpün
## içindeyse küp görünmez (ekranı kaplamaz).
static func shikokumujin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.8)
	pj.anim(c, "seal", 1.0)
	if tt == null:
		if c is Player:
			Hud.msg("Hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var fit = pj._tgt_fit(tt)
	var hw = 1.7 * fit
	var hh = 3.6 * fit
	var root = Node3D.new()
	_add(pj, root, pj.gp(tt.global_position))
	var edge = FOG_PURPLE.lightened(0.3)
	for k in 4:
		var a = PI * 0.25 + k * PI * 0.5
		var pil = _mi(_box(), _fog_mat(), {"fill": 0.0, "edge": edge, "seed": k * 3.3, "nf": 2.0})
		root.add_child(pil)
		pil.position = Vector3(cos(a), 0.0, sin(a)) * hw * 1.414 + Vector3.UP * (hh * 0.5 + 0.05)
		pil.scale = Vector3(0.45 * fit, hh + 0.1, 0.45 * fit)
		_tp(pil, "fill", 0.0, 1.0, 0.4, k * 0.04)
	var cube = _mi(_box(), _fog_mat(), {"fill": 0.0, "edge": edge, "seed": 9.1, "nf": 2.5})
	root.add_child(cube)
	cube.position = Vector3.UP * hh * 0.5
	cube.scale = Vector3(hw * 2.0, hh, hw * 2.0)
	_tp(cube, "fill", 0.0, 1.0, 0.45, 0.25)
	pj.free_after(6.0, root)
	Sfx.play("th_shadow", tt.global_position, 0.8)
	pj.after(0.45, func():
		if not pj.live(tt):
			_fade_free(root, 0.0, 0.3)
			return
		root.global_position = pj.gp(tt.global_position)
		var dur = 4.5
		pj.st(tt, "bind", dur)
		pj.st(tt, "sealed", dur)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Mühürlendi!", FOG_PURPLE.lightened(0.3))
		_tp(root, "fill", 1.0, 0.0, 0.5, dur)
		_fade_free(root, dur + 0.1, 0.5)
		pj.every(dur, 0.25, func(i, _k):
			if not pj.live(tt):
				return
			if i % 3 == 0:
				var a = randf() * TAU
				var sp = root.global_position + Vector3(cos(a) * hw, randf_range(0.4, hh - 0.4), sin(a) * hw)
				var gl = _glint(1.0, 0.7 * fit, 0.7 * fit, Color(0.95, 0.85, 1.0), FOG_PURPLE, 1.0)
				_add(pj, gl, sp)
				var gtw = gl.create_tween()
				gtw.tween_property(gl, "scale", Vector3(0.1, 0.1, 1.0), 0.2)
				_fade_free(gl, 0.05, 0.15)
			if "chakra" in tt:
				tt.chakra = maxf(0.0, float(tt.chakra) - 1.5)
			if i % 4 == 0:
				tt.take_hit(pj.inf(c, "shikokumujin", 0.08, {"knock": 0.0, "kind": "light", "pierce_guard": true})), Callable()))
