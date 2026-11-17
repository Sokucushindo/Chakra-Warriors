class_name YotonLib
extends RefCounted
## Lav doğası (Yōton) malzeme / şekil kütüphanesi. Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları:
##   lav      : sarı-turuncu, yapışkan, ağır akan erimiş kaya; üstünde yüzen koyu soğuyan kabuk plakaları, aralarında parlayan
##              çatlak damarları, koyu kızıl kontur. heat düştükçe kabuk büyür, damarlar kızarır, sonunda kara kaya kalır.
##              ASLA alev değildir (alev dili / alev topu yok).
##   hamur    : cel tonlu yoğun maddeler — Mei'nin bej aşındırıcı çamuru (kabarcık, buhar), lav lastiği (bej-ten, parlak,
##              gerilme çizgili), kül taşı (koyu kömür, kıvrım çizgili), sönmemiş kireç (beyaz, tanecikli, sertleşince çatlar)
##   yardımcı : ağır damla / yapışan leke, uzayıp kopan iplik, soğuyan lav gölü, kızgın zemin çatlağı, kabuk taşı, buhar, ısı halesi
## Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası yalnız malzeme + yapı taşı verir.

const K_GOO := 0.0
const K_RUBBER := 1.0
const K_ASH := 2.0
const K_LIME := 3.0

static var _cache := {}

# ================================================================== shader parçaları
const YNOISE := """
float yh(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float yn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(yh(i), yh(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(yh(i + vec3(0.0, 1.0, 0.0)), yh(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(yh(i + vec3(0.0, 0.0, 1.0)), yh(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(yh(i + vec3(0.0, 1.0, 1.0)), yh(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float yf(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * yn(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

vec3 ycell(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(yh(i + g), yh(i + g + vec3(7.1, 3.3, 1.9)), yh(i + g + vec3(2.7, 8.4, 5.6)));
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = yh(i + g + vec3(4.4, 1.2, 9.9));
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}

float ydith(vec2 fc) {
	return fract(52.9829189 * fract(dot(fc, vec2(0.06711056, 0.00583715))));
}
"""

## Erimiş lav (opak, cel): sarı-turuncu akan gövde + koyu kabuk plakaları + parlayan çatlak damarları + koyu kızıl kontur.
## heat 1.2 → 0: soğuma; crust: kabuk oranı; flow: akış hızı; nscale: desen sıklığı (büyük yüzeyde büyüt = ince desen);
## grow: yüzeyi normal boyunca şişirir (bedene giydirilen kaplama); near: kameraya yakın kısmı (x..y m) titreşimli silme
const LAVA_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float crust = 0.3;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float flow = 0.5;
instance uniform float wob = 0.05;
instance uniform float nscale = 1.6;
instance uniform float grow = 0.0;
instance uniform vec2 near = vec2(1.0, 2.5);

varying vec3 lp;

YNOISE

void vertex() {
	lp = VERTEX;
	float n = yn(VERTEX * 2.1 + vec3(seed, TIME * 0.6, seed * 0.5));
	VERTEX += NORMAL * (grow + (n - 0.5) * wob);
}

void fragment() {
	float h = clamp(heat, 0.0, 1.3);
	vec3 q = lp * nscale + vec3(seed * 3.7, seed * 1.3 - TIME * flow, TIME * flow * 0.4);
	float w = yf(lp * nscale * 0.6 + vec3(seed, TIME * 0.25, 0.0));
	vec3 cl = ycell(q + vec3(w * 0.9));
	float edge = cl.y - cl.x;
	float cov = clamp(crust + (1.0 - min(h, 1.0)) * 0.8, 0.0, 0.97);
	float mott = yf(q * 1.9 + vec3(0.0, 0.0, seed));
	float tmp = mott + (h - 1.0) * 0.55;
	vec3 col = vec3(0.55, 0.08, 0.03);
	if (tmp > 0.32) {
		col = vec3(0.95, 0.36, 0.06);
	}
	if (tmp > 0.5) {
		col = vec3(1.0, 0.62, 0.14);
	}
	if (tmp > 0.66) {
		col = vec3(1.0, 0.82, 0.36);
	}
	float vw = 0.075 * (0.4 + 0.6 * min(h, 1.0));
	if (edge < vw) {
		col = h > 0.55 ? vec3(1.0, 0.95, 0.68) : vec3(1.0, 0.5, 0.1) * (0.35 + h);
	} else if (cl.z < cov) {
		vec3 rock = mix(vec3(0.15, 0.06, 0.045), vec3(0.27, 0.11, 0.07), step(0.55, yn(q * 4.0)));
		col = edge < vw + 0.045 ? vec3(0.6, 0.12, 0.04) * (0.5 + 0.5 * min(h, 1.0)) : rock;
	}
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	if (fr > 0.8) {
		col = mix(col, vec3(0.32, 0.05, 0.02), 0.85);
	}
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + 0.35 * max(h - 0.6, 0.0));
	float a = fade * smoothstep(near.x, near.y, -VERTEX.z);
	if (a < 0.995 && a < ydith(FRAGCOORD.xy)) {
		discard;
	}
}
"""

## Yoğun cel madde (opak): kind 0 Mei çamuru (bej, kabarcıklı, aşındırıcı), 1 lav lastiği (bej-ten, parlak, gerilme çizgili),
## 2 kül taşı (koyu kömür, kıvrım çizgili), 3 sönmemiş kireç (beyaz, tanecikli). stress: lastikte gerilme çizgisi,
## kül / kireçte sertleşme (taşlaşma, çatlak), çamurda aşınma kararması. bub: çamur kabarcık oranı
const PASTE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float wob = 0.04;
instance uniform float nscale = 1.0;
instance uniform float stress = 0.0;
instance uniform float bub = 0.0;
instance uniform vec2 near = vec2(1.0, 2.5);

varying vec3 lp;

YNOISE

void ypal(float k, out vec3 c0, out vec3 c1, out vec3 c2, out vec3 c3, out vec3 ln) {
	if (k < 0.5) {
		c0 = vec3(0.64, 0.49, 0.27);
		c1 = vec3(0.85, 0.72, 0.45);
		c2 = vec3(0.95, 0.87, 0.62);
		c3 = vec3(1.0, 0.98, 0.9);
		ln = vec3(0.45, 0.32, 0.15);
	} else if (k < 1.5) {
		c0 = vec3(0.8, 0.62, 0.42);
		c1 = vec3(0.92, 0.78, 0.57);
		c2 = vec3(0.97, 0.87, 0.7);
		c3 = vec3(1.0, 0.97, 0.9);
		ln = vec3(0.52, 0.38, 0.22);
	} else if (k < 2.5) {
		c0 = vec3(0.11, 0.1, 0.14);
		c1 = vec3(0.2, 0.19, 0.24);
		c2 = vec3(0.3, 0.29, 0.35);
		c3 = vec3(0.3, 0.29, 0.35);
		ln = vec3(0.04, 0.04, 0.06);
	} else {
		c0 = vec3(0.7, 0.71, 0.73);
		c1 = vec3(0.88, 0.88, 0.89);
		c2 = vec3(0.97, 0.97, 0.96);
		c3 = vec3(1.0, 1.0, 1.0);
		ln = vec3(0.52, 0.52, 0.55);
	}
}

void vertex() {
	lp = VERTEX;
	float sp = kind < 0.5 ? 0.45 : (kind < 1.5 ? 0.9 : 0.15);
	float n = yn(VERTEX * 1.8 + vec3(seed, TIME * sp, seed * 0.3));
	VERTEX += NORMAL * (n - 0.5) * wob;
}

void fragment() {
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 ln;
	ypal(kind, c0, c1, c2, c3, ln);
	vec3 q = lp * nscale;
	vec3 ld = normalize(vec3(0.35, 0.8, 0.5));
	float l = dot(NORMAL, ld) * 0.5 + 0.5;
	l += (yf(q * 2.4 + vec3(seed, -TIME * 0.12, 0.0)) - 0.5) * 0.3;
	vec3 col = l < 0.4 ? c0 : (l < 0.7 ? c1 : c2);
	if (kind < 1.5) {
		vec3 gq = kind < 0.5 ? q * 3.0 : q * vec3(2.0, 6.0, 2.0);
		if (l > 0.78 && yn(gq + vec3(seed)) > 0.58) {
			col = c3;
		}
	}
	if (kind < 0.5) {
		vec3 cb = ycell(q * 3.2 + vec3(0.0, TIME * 0.2, seed));
		if (cb.z < bub) {
			float rr = 0.2 + 0.12 * sin(TIME * 2.5 + cb.z * 40.0);
			float ring = abs(cb.x - rr);
			if (ring < 0.035) {
				col = ln;
			} else if (cb.x < rr) {
				col = mix(c1, c2, 0.6);
			}
		}
		col = mix(col, col * vec3(0.8, 0.68, 0.5), stress);
	} else if (kind < 1.5) {
		float sl = abs(fract(q.y * 2.6 + yf(q * 1.5) * 1.6) - 0.5);
		if (sl < 0.025 * stress) {
			col = c0 * 0.88;
		}
	} else if (kind < 2.5) {
		float cr = abs(yf(q * 1.8 + vec3(seed)) - 0.5);
		if (cr < 0.014) {
			col = ln;
		}
		col = mix(col, vec3(0.42, 0.41, 0.43) * (0.8 + 0.4 * l), stress * 0.7);
	} else {
		if (yh(floor(q * 34.0)) > 0.9) {
			col *= 0.84;
		}
		vec3 cc = ycell(q * 2.2 + vec3(seed));
		if (cc.y - cc.x < 0.04 * stress) {
			col = ln;
		}
		col = mix(col, col * vec3(0.86, 0.86, 0.88), stress * 0.6);
	}
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	if (fr > 0.8) {
		col = ln;
	}
	ALBEDO = pow(col, vec3(2.2));
	float a = fade * smoothstep(near.x, near.y, -VERTEX.z);
	if (a < 0.995 && a < ydith(FRAGCOORD.xy)) {
		discard;
	}
}
"""

## Mavi kül taşı kristali (Kaisekifū): içi beyaz-mavi, kenarı doygun mavi, koyu mavi kontur
const CRYSTAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

instance uniform float fade = 1.0;

YNOISE

void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 col = vec3(0.86, 0.97, 1.0) * 1.5;
	if (fr > 0.45) {
		col = vec3(0.38, 0.78, 1.0) * 1.3;
	}
	if (fr > 0.85) {
		col = vec3(0.12, 0.38, 0.85);
	}
	ALBEDO = pow(col, vec3(2.2));
	if (fade < 0.995 && fade < ydith(FRAGCOORD.xy)) {
		discard;
	}
}
"""

## Kameraya dönük yumuşak ısı halesi (eklemeli)
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 tint = vec4(1.0, 0.6, 0.2, 1.0);
instance uniform float fade = 1.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = pow(max(1.0 - d, 0.0), 2.2) * tint.a * fade * smoothstep(0.6, 2.4, -VERTEX.z);
	ALBEDO = pow(tint.rgb, vec3(2.2)) * a;
	ALPHA = a;
}
"""

## Kameraya dönük tutam tutam buhar (lav soğurken / aşındırıcı çamur yakarken), cel kademeli saydamlık
const VAPOR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 tint = vec4(0.95, 0.93, 0.9, 0.55);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

YNOISE

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float n = yf(vec3(uv * 1.7 + vec2(seed, -TIME * 0.7), seed));
	float d = length(uv * vec2(1.0, 0.85)) + (n - 0.5) * 0.8;
	float a = 0.0;
	if (d < 0.75) {
		a = 0.45;
	}
	if (d < 0.45) {
		a = 0.8;
	}
	if (a <= 0.0) {
		discard;
	}
	vec3 col = d < 0.45 ? tint.rgb : tint.rgb * 0.9;
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = a * tint.a * fade * smoothstep(1.0, 3.0, -VERTEX.z);
}
"""

## Lav Çakra Modu ısı örtüsü: bedenin şişirilmiş kopyası; yalnız kenarlarda yukarı akan sarı-turuncu-kızıl ısı perdesi
const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float grow = 0.06;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

varying vec3 lp;

YNOISE

void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * grow * (0.6 + 0.8 * yn(VERTEX * 3.0 + vec3(0.0, -TIME * 2.2, seed)));
}

void fragment() {
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	float n = yf(vec3(lp.x * 3.0, lp.y * 2.2 - TIME * 1.7, lp.z * 3.0 + seed));
	float e = fr * 1.35 + (n - 0.5) * 0.9;
	if (e < 0.6) {
		discard;
	}
	vec3 col = vec3(1.0, 0.82, 0.38);
	if (e > 0.78) {
		col = vec3(1.0, 0.55, 0.12);
	}
	if (e > 0.98) {
		col = vec3(0.9, 0.24, 0.05);
	}
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = fade * (e > 0.98 ? 0.6 : 0.42) * smoothstep(0.5, 1.6, -VERTEX.z);
}
"""

## Yer çatlağı (düzlem, XZ): dallanan yarıklar; heat ile içleri sarı-turuncu parlar, soğuyunca kararır; grow merkezden açılır
const CRACK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float grow = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float dens = 3.2;

YNOISE

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float rn = yn(vec3(uv * 3.0, seed)) * 0.25;
	if (r > grow - rn || r > 0.98) {
		discard;
	}
	vec2 wq = uv + (vec2(yn(vec3(uv * 4.0, seed + 3.0)), yn(vec3(uv * 4.0, seed + 7.0))) - 0.5) * 0.18;
	vec3 cl = ycell(vec3(wq * dens, seed));
	float edge = cl.y - cl.x;
	float wd = 0.08 * (1.0 - r * 0.7);
	float h = clamp(heat, 0.0, 1.2);
	vec3 col = vec3(0.1, 0.07, 0.06);
	float a = 0.0;
	if (r < 0.85 - rn) {
		a = 0.28;
		col = vec3(0.16, 0.1, 0.08);
	}
	if (edge < wd) {
		a = 1.0;
		col = mix(vec3(0.08, 0.05, 0.04), vec3(0.75, 0.14, 0.04), min(h * 1.3, 1.0));
		if (edge < wd * 0.45 && h > 0.15) {
			col = h > 0.6 ? vec3(1.0, 0.86, 0.42) : vec3(1.0, 0.45, 0.08) * (0.4 + h);
		}
	}
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + 0.4 * max(h - 0.6, 0.0));
	ALPHA = a * fade;
}
"""


static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("YNOISE", YNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func lava_mat() -> ShaderMaterial:
	return _mat("lava", LAVA_SHADER)


static func paste_mat() -> ShaderMaterial:
	return _mat("paste", PASTE_SHADER)


static func crystal_mat() -> ShaderMaterial:
	return _mat("crystal", CRYSTAL_SHADER)


static func glow_mat() -> ShaderMaterial:
	return _mat("glow", GLOW_SHADER)


static func vapor_mat() -> ShaderMaterial:
	return _mat("vapor", VAPOR_SHADER)


static func haze_mat() -> ShaderMaterial:
	return _mat("haze", HAZE_SHADER)


static func crack_mat() -> ShaderMaterial:
	return _mat("crack", CRACK_SHADER)


# ================================================================== temel yardımcılar
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


static func gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Örnek shader parametresini tween'leyen ayarlayıcı
static func pf(mi: GeometryInstance3D, k: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(k, v)


static func floor_at(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z), p.z)


static func side_of(d: Vector3) -> Vector3:
	var s = d.cross(Vector3.UP)
	if s.length() < 0.01:
		return Vector3.RIGHT
	return s.normalized()


static func look(n: Node3D, dirv: Vector3) -> void:
	if not is_instance_valid(n) or dirv.length() < 0.0001:
		return
	var f = dirv.normalized()
	n.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT)


## Eski zemin çatlağının oyun tarafı: büyük yarık üstünden geçeni yavaşlatır (3-5 sn)
static func crack_zone(pos: Vector3, size: float, dur := 6.0) -> void:
	if size >= 1.5:
		GroundFX.add(floor_at(pos), "cracked", size * 0.6, clampf(dur, 3.0, 5.0))


static func _quad_c() -> QuadMesh:
	if not _cache.has("qc"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["qc"] = q
	return _cache["qc"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache["plane"] = p
	return _cache["plane"]


# ================================================================== geometri
## Birim yarıçaplı topak küre: variant'a göre kabarık şişkinlikler (önbellekli)
static func blob_mesh(variant: int, rough := 0.2, rings := 9, segs := 14) -> ArrayMesh:
	var key = "blob_%d_%d_%d_%d" % [variant, int(rough * 100.0), rings, segs]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 104729 * (variant + 5)
	var bumps = []
	for k in 7:
		var bd = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if bd.length() < 0.1:
			bd = Vector3.UP
		bumps.append([bd.normalized(), rng.randf_range(0.4, 1.0), rng.randf_range(2.0, 5.0)])
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings + 1:
		var v = float(r) / rings
		var phi = v * PI
		for s in segs + 1:
			var u = float(s) / segs
			var th = u * TAU
			var dir = Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var rad = 1.0 - rough * 0.4
			for b in bumps:
				rad += rough * float(b[1]) * pow(maxf(0.0, dir.dot(b[0])), float(b[2]))
			sf.set_uv(Vector2(u, v))
			sf.add_vertex(dir * rad)
	for r in rings:
		for s in segs:
			var a = r * (segs + 1) + s
			var b2 = a + segs + 1
			sf.add_index(a)
			sf.add_index(b2)
			sf.add_index(a + 1)
			sf.add_index(a + 1)
			sf.add_index(b2)
			sf.add_index(b2 + 1)
	sf.generate_normals()
	var m = sf.commit()
	_cache[key] = m
	return m


## Nokta dizisi boyunca tüp (yarıçap dizisi ile), uçları kapalı; rough: kesit dalgalanması
static func tube_mesh(pts: Array, radii: Array, sides := 8, rough := 0.12, sd := 0.0, tip := 0.6) -> ArrayMesh:
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size()
	var nn = Vector3.ZERO
	var t0 = Vector3.UP
	var tl = Vector3.UP
	for i in n:
		var p: Vector3 = pts[i]
		var tng: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		if tng.length() < 0.0001:
			tng = tl
		tng = tng.normalized()
		if i == 0:
			t0 = tng
			var rf = Vector3.RIGHT if absf(tng.y) > 0.9 else Vector3.UP
			nn = tng.cross(rf).normalized()
		else:
			var nn2 = nn - tng * nn.dot(tng)
			if nn2.length() > 0.0001:
				nn = nn2.normalized()
		tl = tng
		var bb = tng.cross(nn)
		for s in sides + 1:
			var a = s * TAU / sides
			var r = float(radii[i]) * (1.0 + rough * (0.6 * sin(a * 2.0 + i * 1.3 + sd) + 0.4 * sin(a * 3.0 - i * 0.7 + sd * 2.0)))
			sf.set_uv(Vector2(float(s) / sides, float(i) / maxf(1.0, n - 1)))
			sf.add_vertex(p + (nn * cos(a) + bb * sin(a)) * r)
	for i in n - 1:
		for s in sides:
			var a0 = i * (sides + 1) + s
			var u0 = a0 + sides + 1
			sf.add_index(a0)
			sf.add_index(u0)
			sf.add_index(a0 + 1)
			sf.add_index(a0 + 1)
			sf.add_index(u0)
			sf.add_index(u0 + 1)
	var tip_i = n * (sides + 1)
	sf.set_uv(Vector2(0.5, 1.0))
	sf.add_vertex(pts[n - 1] + tl * float(radii[n - 1]) * tip)
	var bot_i = tip_i + 1
	sf.set_uv(Vector2(0.5, 0.0))
	sf.add_vertex(pts[0] - t0 * float(radii[0]) * 0.3)
	var lb = (n - 1) * (sides + 1)
	for s in sides:
		sf.add_index(lb + s)
		sf.add_index(tip_i)
		sf.add_index(lb + s + 1)
		sf.add_index(bot_i)
		sf.add_index(s)
		sf.add_index(s + 1)
	sf.generate_normals()
	return sf.commit()


## a'dan b'ye yay çizen nokta dizisi (sarkma / kabarma: lift; yana dalga: wav)
static func arc_pts(a: Vector3, b: Vector3, n: int, lift: float, wav := Vector3.ZERO, wfreq := 2.0) -> Array:
	var out = []
	for i in n:
		var u = float(i) / maxf(1.0, n - 1)
		out.append(a.lerp(b, u) + Vector3.UP * sin(u * PI) * lift + wav * sin(u * PI * wfreq))
	return out


# ================================================================== malzeme örnekleri
static func lava_mi(mesh: Mesh, heat := 1.0, crust := 0.3, o := {}) -> MeshInstance3D:
	var mi = gi(mesh, lava_mat())
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("crust", crust)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("flow", float(o.get("flow", 0.5)))
	mi.set_instance_shader_parameter("wob", float(o.get("wob", 0.05)))
	mi.set_instance_shader_parameter("nscale", float(o.get("nscale", 1.6)))
	mi.set_instance_shader_parameter("grow", float(o.get("grow", 0.0)))
	mi.set_instance_shader_parameter("near", o.get("near", Vector2(1.0, 2.5)))
	return mi


static func paste_mi(mesh: Mesh, kind: float, o := {}) -> MeshInstance3D:
	var mi = gi(mesh, paste_mat())
	mi.set_instance_shader_parameter("kind", kind)
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("wob", float(o.get("wob", 0.04)))
	mi.set_instance_shader_parameter("nscale", float(o.get("nscale", 1.0)))
	mi.set_instance_shader_parameter("stress", float(o.get("stress", 0.0)))
	mi.set_instance_shader_parameter("bub", float(o.get("bub", 0.0)))
	mi.set_instance_shader_parameter("near", o.get("near", Vector2(1.0, 2.5)))
	return mi


static func crystal_mi(hl: float, w: float) -> MeshInstance3D:
	# uzun, sivri uçlu ince kristal: iki yana sivrilen tüp (ref: Kaisekifū mavi pul kristalleri)
	var pts = [Vector3(0, 0, 0), Vector3(0, hl * 0.35, 0), Vector3(0, hl * 0.7, 0), Vector3(0, hl, 0)]
	var rr = [w * 0.4, w, w * 0.8, w * 0.12]
	var mi = gi(tube_mesh(pts, rr, 4, 0.0, 0.0, 1.8), crystal_mat())
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3(1.0, 1.0, 0.35)
	return mi


## Lav topağı (birim topak mesh × r)
static func lava_blob(r: float, heat := 1.0, crust := 0.3, rough := 0.22, o := {}) -> MeshInstance3D:
	var oo = o.duplicate()
	if not oo.has("nscale"):
		oo["nscale"] = 1.4 + r * 1.2
	var mi = lava_mi(blob_mesh(randi() % 6, rough), heat, crust, oo)
	mi.scale = Vector3.ONE * r
	return mi


static func paste_blob(r: float, kind: float, rough := 0.22, o := {}) -> MeshInstance3D:
	var oo = o.duplicate()
	if not oo.has("nscale"):
		oo["nscale"] = 0.8 + r * 0.8
	var mi = paste_mi(blob_mesh(randi() % 6, rough), kind, oo)
	mi.scale = Vector3.ONE * r
	return mi


# ================================================================== yapı taşları
## Bir düğüme iliştirilecek kalıcı ısı halesi
static func glow_mi(col: Color, s: float) -> MeshInstance3D:
	var mi = gi(_quad_c(), glow_mat())
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3.ONE * s
	return mi


static func glow(host: Node, p: Vector3, s: float, col: Color, life: float) -> MeshInstance3D:
	var mi = gi(_quad_c(), glow_mat())
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("fade", 1.0)
	put(host, mi, p)
	mi.scale = Vector3.ONE * s
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


static func light(host: Node, p: Vector3, col: Color, energy: float, rng: float, life: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	put(host, l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	return l


## Yükselen buhar tutamı (lav soğurken / çamur yakarken)
static func vapor(host: Node, p: Vector3, s: float, life: float, vel := Vector3(0, 1.2, 0), tint := Color(0.95, 0.93, 0.9, 0.55)) -> MeshInstance3D:
	var mi = gi(_quad_c(), vapor_mat())
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	put(host, mi, p)
	mi.scale = Vector3.ONE * s * 0.4
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "global_position", p + vel * life, life).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * s, life).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Kızgın zemin çatlağı: merkezden grow_t'de açılır, heat0'dan soğur, sonra söner
static func cracks(host: Node, p: Vector3, R: float, dur: float, heat0 := 1.0, grow_t := 0.25, dens := 3.2) -> MeshInstance3D:
	var mi = gi(_plane(), crack_mat())
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	mi.set_instance_shader_parameter("heat", heat0)
	mi.set_instance_shader_parameter("grow", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("dens", dens)
	put(host, mi, floor_at(p) + Vector3.UP * 0.05)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(R, 1.0, R)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, grow_t).set_ease(Tween.EASE_OUT)
	var th = mi.create_tween()
	th.tween_method(pf(mi, "heat"), heat0, 0.0, dur * 0.75)
	tw.tween_interval(maxf(0.0, dur * 0.7 - grow_t))
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, dur * 0.3)
	tw.tween_callback(mi.queue_free)
	return mi


## Balistik parça: yerçekimiyle düşer, hız yönünde uzar (ağır damla), yere değince yassılaşıp yapışır (on_land(pos)),
## life sonunda titreşimle silinir
static func drop(host: Node, mi: MeshInstance3D, p: Vector3, v: Vector3, r: float, life: float, g := 22.0, on_land := Callable(), stretch := 1.0) -> void:
	put(host, mi, p)
	mi.scale = Vector3.ONE * r
	var stt = {"land": false}
	var tw = mi.create_tween()
	tw.tween_method(func(tm: float) -> void:
		if not is_instance_valid(mi) or stt["land"]:
			return
		var vel = v + Vector3.DOWN * g * tm
		var pos = p + v * tm + Vector3.DOWN * 0.5 * g * tm * tm
		var fy = Game.jutsu_floor(pos.x, pos.z) + 0.03
		if pos.y < fy and tm > 0.04:
			pos.y = fy
			stt["land"] = true
			mi.global_basis = Basis(Vector3.UP, randf() * TAU) * Basis.from_scale(Vector3(r * 2.3, r * 0.32, r * 2.3))
			mi.global_position = pos
			if on_land.is_valid():
				on_land.call(pos)
			return
		mi.global_position = pos
		var sp = vel.length()
		if sp > 0.5:
			var f = vel / sp
			var b = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT)
			mi.global_basis = b * Basis.from_scale(Vector3(r, r, r * (1.0 + minf(sp * 0.07, 1.3) * stretch))), 0.0, life, life)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, 0.45)
	tw.tween_callback(mi.queue_free)


## Ağır lav damlaları: koni içinde fırlar, düşer, yere yapışıp kabuklanarak soğur
static func lava_drops(host: Node, p: Vector3, n: int, spd: float, dirv := Vector3.UP, spread := 0.8, r := 0.12, heat := 1.0, life := 2.2) -> void:
	var dn = dirv.normalized() if dirv.length() > 0.01 else Vector3.UP
	for k in n:
		var rv = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * spread
		var v = (dn + rv).normalized() * spd * randf_range(0.55, 1.0)
		var rr = r * randf_range(0.6, 1.3)
		var mi = lava_mi(blob_mesh(randi() % 6, 0.15, 6, 9), heat, 0.12, {"wob": 0.0, "nscale": 2.6, "near": Vector2(0.4, 1.2)})
		drop(host, mi, p, v, rr, life * randf_range(0.8, 1.1), 24.0, func(_q: Vector3) -> void:
			if is_instance_valid(mi):
				mi.create_tween().tween_method(pf(mi, "heat"), heat, 0.08, 1.4))


## Hamur damlaları (çamur / lastik / kül / kireç)
static func paste_drops(host: Node, p: Vector3, n: int, spd: float, kind: float, dirv := Vector3.UP, spread := 0.8, r := 0.1, life := 1.8) -> void:
	var dn = dirv.normalized() if dirv.length() > 0.01 else Vector3.UP
	for k in n:
		var rv = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * spread
		var v = (dn + rv).normalized() * spd * randf_range(0.55, 1.0)
		var mi = paste_mi(blob_mesh(randi() % 6, 0.15, 6, 9), kind, {"wob": 0.0, "nscale": 2.0, "near": Vector2(0.4, 1.2)})
		drop(host, mi, p, v, r * randf_range(0.6, 1.3), life * randf_range(0.8, 1.1), 20.0)


## Soğumuş lav kabuğu taşı: koyu, ince kızıl damarlı, dönerek fırlar
static func crust_rock(host: Node, p: Vector3, v: Vector3, s: float, life := 1.8) -> void:
	var mi = lava_mi(blob_mesh(10 + randi() % 5, 0.5, 5, 7), 0.25, 0.92, {"wob": 0.0, "nscale": 3.0, "flow": 0.0, "near": Vector2(0.4, 1.2)})
	put(host, mi, p)
	mi.scale = Vector3.ONE * s
	var spin = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	var stt = {"land": false}
	var tw = mi.create_tween()
	tw.tween_method(func(tm: float) -> void:
		if not is_instance_valid(mi) or stt["land"]:
			return
		var pos = p + v * tm + Vector3.DOWN * 0.5 * 20.0 * tm * tm
		var fy = Game.jutsu_floor(pos.x, pos.z) + s * 0.5
		if pos.y < fy and tm > 0.05:
			pos.y = fy
			stt["land"] = true
		mi.global_position = pos
		mi.rotation = spin * tm, 0.0, life, life)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, 0.4)
	tw.tween_callback(mi.queue_free)


## Uzayıp kopan iplik: a ile b arasında sarkan iki yarım tüp; boyun incelir, kopar, iki uç kendi ucuna geri çekilir
## mk: Callable(mesh) -> MeshInstance3D (malzemeyi seçer)
static func strand(host: Node, a: Vector3, b: Vector3, r: float, life: float, mk: Callable, sag := 0.18) -> void:
	var L = a.distance_to(b)
	if L < 0.05:
		return
	var mid = (a + b) * 0.5 + Vector3.DOWN * L * sag
	for e_i in 2:
		var e0: Vector3 = a if e_i == 0 else b
		var root = Node3D.new()
		put(host, root, e0)
		var pts = []
		var rr = []
		for i in 6:
			var u = float(i) / 5.0
			var bz = e0.lerp(mid, u) + Vector3.DOWN * sin(u * PI * 0.5) * L * sag * 0.25
			pts.append(bz - e0)
			rr.append(r * lerpf(1.0, 0.3, u))
		var mi: MeshInstance3D = mk.call(tube_mesh(pts, rr, 6, 0.1))
		root.add_child(mi)
		var tw = root.create_tween()
		tw.tween_interval(life * 0.65)
		tw.tween_property(root, "scale", Vector3(0.6, 0.6, 0.6), life * 0.2)
		tw.tween_property(root, "scale", Vector3.ONE * 0.04, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(root.queue_free)


## Soğuyan lav gölü: alçak, düzensiz kenarlı; büyür, kabarcıklar patlar, kabuk yayılıp kararır, yavaş söner
static func lava_pool(host: Node, p: Vector3, r: float, dur: float, heat0 := 1.0, hgt := 0.09) -> MeshInstance3D:
	var mi = lava_mi(blob_mesh(20 + randi() % 5, 0.28, 7, 18), heat0, 0.12, {"nscale": 1.2 * r + 0.8, "wob": 0.0, "flow": 0.1, "near": Vector2(1.5, 3.5)})
	var g = floor_at(p)
	put(host, mi, g + Vector3.UP * 0.01)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r * 0.2, hgt, r * 0.2)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r, hgt, r), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, dur - 0.95))
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, 0.6)
	tw.tween_callback(mi.queue_free)
	mi.create_tween().tween_method(pf(mi, "heat"), heat0, 0.1, dur * 0.85)
	# kabarcıklar: yüzeyde kabarıp patlayan lav keseleri (soğudukça seyrelir)
	var nb = int(dur / 0.4)
	var bt = mi.create_tween()
	for i in nb:
		bt.tween_interval(0.4)
		bt.tween_callback(func():
			if not is_instance_valid(mi) or float(i) / nb > 0.6:
				return
			var a = randf() * TAU
			var q = g + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.1, 0.75) * r
			var bb = lava_blob(0.05, 1.0, 0.05, 0.1, {"wob": 0.0})
			put(host, bb, q)
			var bw = bb.create_tween()
			bw.tween_property(bb, "scale", Vector3(0.22, 0.16, 0.22) * minf(r, 2.0) * 0.6, 0.35).set_ease(Tween.EASE_OUT)
			bw.tween_callback(func():
				if is_instance_valid(bb):
					lava_drops(host, bb.global_position + Vector3.UP * 0.05, 3, 2.5, Vector3.UP, 0.6, 0.04, 1.0, 0.8))
			bw.tween_callback(bb.queue_free))
	return mi


## Aşındırıcı çamur birikintisi (Mei): bej, kabarcıklı, buhar tüter, zemine sinip söner
static func goo_pool(host: Node, p: Vector3, r: float, dur: float, hgt := 0.1) -> MeshInstance3D:
	var mi = paste_mi(blob_mesh(30 + randi() % 5, 0.3, 7, 18), K_GOO, {"nscale": 0.9 * r + 0.6, "wob": 0.0, "bub": 0.55, "near": Vector2(1.5, 3.5)})
	var g = floor_at(p)
	put(host, mi, g + Vector3.UP * 0.01)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r * 0.25, hgt, r * 0.25)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r, hgt, r), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, dur - 1.0))
	tw.tween_property(mi, "scale", Vector3(r * 1.1, 0.01, r * 1.1), 0.6)
	tw.tween_callback(mi.queue_free)
	mi.create_tween().tween_method(pf(mi, "stress"), 0.0, 0.7, dur)
	var nv = int(dur / 0.5)
	var vt = mi.create_tween()
	for i in nv:
		vt.tween_interval(0.5)
		vt.tween_callback(func():
			if not is_instance_valid(mi):
				return
			var a = randf() * TAU
			var q = g + Vector3(cos(a), 0.15, sin(a)) * randf_range(0.0, 0.8) * r
			vapor(host, q, randf_range(0.6, 1.1), randf_range(1.0, 1.5), Vector3(randf_range(-0.2, 0.2), 1.1, randf_range(-0.2, 0.2)), Color(0.96, 0.94, 0.86, 0.45)))
	return mi
