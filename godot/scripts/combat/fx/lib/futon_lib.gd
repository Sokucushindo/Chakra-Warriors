class_name FutonLib
extends RefCounted
## Rüzgâr doğası malzeme / şekil kütüphanesi (Fūton). Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları.
## Rüzgâr görünmez havadır, okunur kılınır — asla katı koni / kubbe / kabuk değil:
##   akım çizgisi : ince, kıvrılan, uçları sivrilen beyaz cel çizgi (parlak çekirdek + soluk dış bant), arkadan kesik kesik kopar
##   hava perdesi : yarı saydam, kenarları sönen geniş akış; içinde boyuna akan ince çizgiler, iki tonlu cel gövde
##   kesici hilal : soluk saydam orak bıçağı; ön kenarı keskin beyaz, dışında ince koyu kontur, arkasında hız sürtmesi (isteğe göre tırtıklı)
##   basınç       : ekranı kıran görünmez hava (halka dalgası ya da sıkışmış vakum topu, girdap bükülmesi)
##   zemin izi    : süpürülmüş toz çizgileri, merkezden kaçan ışınsal izler, kesik yarıkları
##   savrulan     : toz (iki tonlu cel topak), yaprak, ot, çakıl, çiçek yaprağı, kaya parçası
## Kameraya yakın söner: çizgi / perde / hilal / basınç / hava küresi gölgelendiricileri kameraya `near` (2.6 m) içinde saydamlaşır
## (efekt ekranı kaplamaz). Tüm yapı taşları o["near"] ile bu mesafeyi değiştirebilir (geniş perdeler / fırtınalar için 6-9 m).
## Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası yalnız malzeme + yapı taşı verir.

const AIR := Color(0.88, 0.96, 1.0, 0.95)
const MINT := Color(0.84, 1.0, 0.93, 0.95)
const BLUE := Color(0.5, 0.78, 1.0, 0.95)
const LAV := Color(0.8, 0.76, 1.0, 0.95)
const PETAL := Color(1.0, 0.78, 0.86, 0.95)

static var _cache := {}

# ================================================================== shader parçaları
const FNOISE := """
float wh(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float wn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(wh(i), wh(i + vec2(1.0, 0.0)), f.x);
	float b = mix(wh(i + vec2(0.0, 1.0)), wh(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float wf(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * wn(p);
		p = p * 2.13 + vec2(1.7, 3.1);
		a *= 0.5;
	}
	return s;
}
"""

## İnce akım çizgisi (şerit: UV.x boy 0 kuyruk → 1 baş, UV.y en). head/tail ile akar; uçlar sivri, kuyruk kesik kesik kopar.
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float head = 1.0;
instance uniform float tail = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float flow = 3.0;
instance uniform float near = 2.6;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

FNOISE

void fragment() {
	float u = UV.x;
	if (u > head || u < tail) {
		discard;
	}
	float span = max(head - tail, 0.0001);
	float lu = clamp((u - tail) / span, 0.0, 1.0);
	float taper = smoothstep(0.0, 0.4, lu) * (1.0 - 0.75 * smoothstep(0.86, 1.0, lu));
	float v = abs(UV.y * 2.0 - 1.0);
	float e = 1.0 - v / max(taper, 0.001);
	if (e <= 0.0) {
		discard;
	}
	float br = wn(vec2(u * 14.0 - TIME * flow + seed * 7.0, seed * 3.0));
	if (br < 0.32 * (1.0 - lu)) {
		discard;
	}
	vec3 col = tint.rgb;
	float a = 0.45;
	if (e > 0.42) {
		col = mix(tint.rgb, vec3(1.0), 0.75);
		a = 1.0;
	}
	ALBEDO = col;
	ALPHA = a * tint.a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Hava perdesi: yumuşak kenarlı, yarı saydam akış; içinde boyuna kıvrılan ince çizgiler, iki tonlu cel gövde
const SHEET_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float head = 1.0;
instance uniform float tail = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float flow = 2.0;
instance uniform float lines = 4.0;
instance uniform float opacity = 0.5;
instance uniform float near = 2.6;
instance uniform vec4 tint : source_color = vec4(0.88, 0.96, 1.0, 1.0);

FNOISE

void fragment() {
	float u = UV.x;
	if (u > head || u < tail) {
		discard;
	}
	float span = max(head - tail, 0.0001);
	float lu = clamp((u - tail) / span, 0.0, 1.0);
	float taper = smoothstep(0.0, 0.3, lu) * (1.0 - 0.6 * smoothstep(0.8, 1.0, lu));
	float v = UV.y * 2.0 - 1.0;
	float wob = (wn(vec2(u * 4.0 - TIME * flow * 0.5, seed)) - 0.5) * 0.35;
	float av = abs(v + wob);
	if (av > taper) {
		discard;
	}
	float edge = 1.0 - smoothstep(taper * 0.5, taper, av);
	float body = wf(vec2(u * 5.0 - TIME * flow + seed * 4.0, v * 2.0 + seed));
	float lv = (v + wob) * lines + body * 0.8;
	float ln = fract(lv);
	float stk = smoothstep(0.4, 0.5, ln) * (1.0 - smoothstep(0.5, 0.62, ln));
	float gate = step(0.42, wn(vec2(u * 9.0 - TIME * flow * 1.6 + seed, floor(lv) * 1.7)));
	vec3 col = tint.rgb;
	float a = edge * 0.28;
	if (body > 0.55) {
		col = tint.rgb * 0.86;
		a = edge * 0.42;
	}
	if (stk * gate > 0.5) {
		col = mix(tint.rgb, vec3(1.0), 0.85);
		a = max(a, edge * 0.85);
	}
	if (a < 0.02) {
		discard;
	}
	ALBEDO = col;
	ALPHA = clamp(a * opacity * 2.0, 0.0, 1.0) * tint.a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Kesici hilal (QuadMesh 1x1, yerel +Y ön kenar). thick: hilal kalınlığı, jag: tırtıklı ön kenar, wisp: arkadaki hız sürtmesi
const BLADE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float thick = 0.3;
instance uniform float jag = 0.0;
instance uniform float wisp = 1.0;
instance uniform float near = 2.6;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform vec4 tint : source_color = vec4(0.88, 0.96, 1.0, 1.0);

FNOISE

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec2 c1 = vec2(0.0, -0.1);
	vec2 c2 = vec2(0.0, -0.1 - thick);
	float d1 = length(p - c1);
	float d2 = length(p - c2);
	float ang = atan(p.x, p.y - c1.y);
	float saw = fract(ang * 5.0 + seed + TIME * 0.6);
	float eo = 1.0 - d1 + jag * (saw - 0.5) * 0.14 * smoothstep(0.0, 0.5, 1.0 - abs(p.x));
	float ei = d2 - 1.0;
	float horn = 1.0 - smoothstep(0.82, 1.0, abs(p.x));
	vec3 col = tint.rgb;
	float a = 0.0;
	if (ei > 0.0) {
		if (eo < 0.0 && eo > -0.03) {
			col = tint.rgb * 0.5;
			a = 0.7;
		} else if (eo >= 0.0 && eo < 0.04) {
			col = vec3(1.0);
			a = 1.0;
		} else if (eo >= 0.04) {
			float sl = wn(vec2(d1 * 34.0 + seed, ang * 2.0 - TIME * 3.0));
			col = sl > 0.62 ? mix(tint.rgb, vec3(1.0), 0.8) : tint.rgb;
			a = ei > thick * 0.45 ? 0.62 : 0.34;
			if (sl > 0.62) {
				a = 0.8;
			}
		}
	} else if (eo > 0.0 && ei > -0.3 * wisp) {
		float k = 1.0 + ei / max(0.3 * wisp, 0.001);
		float st = wn(vec2(d2 * 46.0 + seed * 5.0, ang * 3.0 + seed));
		if (st > 0.6) {
			col = mix(tint.rgb, vec3(1.0), 0.5);
			a = 0.45 * k;
		}
	}
	a *= horn * fade * tint.a;
	if (a < 0.02) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Basınç / vakum: arkasındaki görüntüyü kıran görünmez hava. ring >= 0 halka dalgası, ring < 0 disk (sıkışmış top).
## bill > 0.5 kameraya döner; değilse düğümün düzleminde (zemine yatırılır).
const WARP_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform float ring = 0.5;
instance uniform float band = 0.15;
instance uniform float power = 1.0;
instance uniform float swirl = 0.0;
instance uniform float fade = 1.0;
instance uniform float bill = 1.0;
instance uniform float glint = 0.3;
instance uniform float near = 2.6;

void vertex() {
	if (bill > 0.5) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float k = 0.0;
	if (ring < 0.0) {
		k = 1.0 - smoothstep(0.0, 1.0, r);
	} else {
		float q = (r - ring) / max(band, 0.001);
		k = exp(-q * q);
	}
	k *= fade;
	if (k < 0.01) {
		discard;
	}
	vec2 dir = r > 0.0001 ? p / r : vec2(0.0);
	vec2 off = dir * k * power * 0.04 + vec2(-p.y, p.x) * swirl * k * 0.05;
	vec3 bg = textureLod(scr, SCREEN_UV - off, 0.0).rgb;
	float lit = step(0.75, k) * glint;
	ALBEDO = mix(bg, vec3(1.0), lit * 0.3);
	ALPHA = clamp(k * 1.5, 0.0, 1.0) * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Zemin izi (PlaneMesh 1x1). kind 0: süpürülmüş toz çizgileri (UV.y boyunca), 1: merkezden kaçan ışınsal izler, 2: kesik yarıkları
const SCOUR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float fade = 1.0;
instance uniform float grow = 1.0;
instance uniform float seed = 0.0;
instance uniform vec4 tint : source_color = vec4(0.8, 0.74, 0.62, 0.7);

FNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = 0.0;
	vec3 col = tint.rgb;
	if (kind < 0.5) {
		float y = UV.y;
		if (y > grow) {
			discard;
		}
		float m = (1.0 - p.x * p.x) * smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.75, 1.0, y));
		float w = wn(vec2(p.x * 3.0 + seed, y * 2.0)) * 0.6;
		float lv = p.x * 9.0 + w;
		float stk = 1.0 - smoothstep(0.0, 0.14, abs(fract(lv) - 0.5));
		float gate = step(0.45, wn(vec2(floor(lv) * 3.1 + seed, y * 5.0)));
		float s = m * stk * gate;
		a = s > 0.45 ? 0.8 : (s > 0.15 ? 0.35 : 0.0);
	} else if (kind < 1.5) {
		float r = length(p);
		if (r > 1.0 || r > grow) {
			discard;
		}
		float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
		float w = wn(vec2(r * 3.0 + seed, ang * 4.0)) * 0.5;
		float lv = ang * 36.0 + w;
		float stk = 1.0 - smoothstep(0.0, 0.16, abs(fract(lv) - 0.5));
		float m = smoothstep(0.12, 0.35, r) * (1.0 - smoothstep(0.8, 1.0, r));
		float gate = step(0.4, wn(vec2(floor(lv) * 2.7 + seed, r * 4.0)));
		float s = m * stk * gate;
		a = s > 0.45 ? 0.8 : (s > 0.15 ? 0.35 : 0.0);
	} else {
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float cx = (wh(vec2(fi + 0.5, seed)) - 0.5) * 1.4;
			float len0 = 0.5 + wh(vec2(seed + 0.3, fi * 2.3)) * 0.45;
			float sl = (wh(vec2(fi * 1.7, seed + 1.0)) - 0.5) * 0.5;
			if (abs(p.y) < len0 * grow) {
				float wdt = 0.04 * (1.0 - abs(p.y) / len0);
				float dx = abs(p.x - cx - p.y * sl);
				if (dx < wdt) {
					a = 0.92;
					col = tint.rgb * 0.45;
				} else if (dx < wdt * 2.6 && a < 0.5) {
					a = 0.45;
					col = mix(tint.rgb, vec3(1.0), 0.35);
				}
			}
		}
	}
	if (a < 0.01) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a * tint.a * fade;
}
"""


## Hava küresi (sıkıştırılmış hava mermisi, QuadMesh 1x1, kameraya döner): arkasını mercek gibi büyüten saydam disk;
## kenarı yer yer kopuk soluk çizgi + koyu ince kontur, içinde dönen ince hava izleri. tear: kenarın kopukluğu (0 tam halka)
const ORB_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float tear = 0.5;
instance uniform float near = 2.6;
instance uniform vec4 tint : source_color = vec4(0.88, 0.96, 1.0, 1.0);

FNOISE

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = 0.9 + (wn(vec2(ang * 1.6 + seed, TIME * 2.5)) - 0.5) * 0.12;
	if (r > edge) {
		discard;
	}
	vec2 off = p * (1.0 - r) * 0.07;
	vec3 bg = textureLod(scr, SCREEN_UV + off, 0.0).rgb;
	vec3 col = mix(bg, tint.rgb, 0.16);
	float a = 0.92;
	float sw = wn(vec2(ang * 2.5 + r * 5.0 - TIME * 7.0 + seed, seed * 2.0));
	if (sw > 0.74 && r > 0.35) {
		col = mix(col, vec3(1.0), 0.3);
	}
	float gap = wn(vec2(ang * 1.3 + seed * 5.0, seed));
	float lip = smoothstep(edge - 0.13, edge - 0.04, r);
	if (lip > 0.5 && gap > tear * 0.62) {
		col = mix(tint.rgb, vec3(1.0), 0.65);
		a = 0.9;
	} else if (r > edge - 0.035) {
		col = tint.rgb * 0.5;
		a = 0.55;
	}
	ALBEDO = col;
	ALPHA = a * fade * tint.a * smoothstep(near * 0.35, near, length(VERTEX));
}
"""


# ================================================================== malzemeler
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("FNOISE", FNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func line_mat() -> ShaderMaterial:
	return _mat("line", LINE_SHADER)


static func sheet_mat() -> ShaderMaterial:
	return _mat("sheet", SHEET_SHADER)


static func blade_mat() -> ShaderMaterial:
	return _mat("blade", BLADE_SHADER)


static func warp_mat() -> ShaderMaterial:
	return _mat("warp", WARP_SHADER)


static func scour_mat() -> ShaderMaterial:
	return _mat("scour", SCOUR_SHADER)


static func orb_mat() -> ShaderMaterial:
	return _mat("orb", ORB_SHADER)


## Köşe renkli toon (kaya parçası, küçük katı parçalar)
static func rock_mat() -> Material:
	if not _cache.has("rock"):
		_cache["rock"] = Props.toon()
	return _cache["rock"]


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["quad"] = q
	return _cache["quad"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(1.0, 1.0)
		_cache["plane"] = p
	return _cache["plane"]


# ================================================================== temel yardımcılar
static func put(host: Node, n: Node3D, pos: Vector3, parent: Node = null) -> Node3D:
	if parent != null and is_instance_valid(parent):
		parent.add_child(n)
		n.position = pos
	else:
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


## d'ye dik "yukarı" (d yatayken dünya yukarısı)
static func up_of(d: Vector3) -> Vector3:
	return side_of(d).cross(d.normalized()).normalized()


## Zemin tozu rengi: çölde/sahilde kum, karda beyaz, kayalıkta gri, diğer yerde açık toprak
static func ground_col(p: Vector3) -> Color:
	var b = Game.biome_at(p.x, p.z)
	if b in [1, 3]:
		return Color(0.94, 0.85, 0.66)
	if b == 8:
		return Color(0.95, 0.97, 1.0)
	if b in [5, 9]:
		return Color(0.78, 0.76, 0.72)
	return Color(0.84, 0.77, 0.64)


## Yaprak rengi: karda/çölde yaprak yok (ot/çakıl); diğer yerde yeşil-sarı
static func has_leaves(p: Vector3) -> bool:
	var b = Game.biome_at(p.x, p.z)
	return not (b in [1, 3, 8, 5, 9])


# ================================================================== geometri
## fn(u: 0..1) -> Vector3 yolundan n nokta
static func path_pts(fn: Callable, n: int) -> PackedVector3Array:
	var out = PackedVector3Array()
	for i in n:
		out.append(fn.call(float(i) / float(maxi(n - 1, 1))))
	return out


## Sarmal: center etrafında ax ekseninde, yarıçap r0→r1, yükseklik h0→h1, a0'dan turns tur
static func helix_pts(center: Vector3, ax: Vector3, r0: float, r1: float, h0: float, h1: float, a0: float, turns: float, n: int) -> PackedVector3Array:
	var y = ax.normalized()
	var x = side_of(y) if absf(y.y) < 0.95 else Vector3.RIGHT
	var z = x.cross(y).normalized()
	var out = PackedVector3Array()
	for i in n:
		var u = float(i) / float(maxi(n - 1, 1))
		var a = a0 + u * turns * TAU
		var r = lerpf(r0, r1, u)
		out.append(center + y * lerpf(h0, h1, u) + (x * cos(a) + z * sin(a)) * r)
	return out


## Şerit örgüsü: twin → iki dik düzlem (her açıdan okunur); hint verilirse ilk düzlem hint'e dik (yere yatık için UP)
static func strip(pts: PackedVector3Array, w: float, hint := Vector3.ZERO, twin := true, widths := PackedFloat32Array()) -> ArrayMesh:
	var n = pts.size()
	if n < 2:
		return ArrayMesh.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tans: Array = []
	for i in n:
		var tv = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		tans.append(tv.normalized() if tv.length() > 0.00001 else Vector3.FORWARD)
	var planes = 2 if twin else 1
	for pl in planes:
		for i in n - 1:
			var w0 = w * (widths[i] if widths.size() == n else 1.0)
			var w1 = w * (widths[i + 1] if widths.size() == n else 1.0)
			var s0: Vector3 = _side(tans[i], pl, hint) * w0
			var s1: Vector3 = _side(tans[i + 1], pl, hint) * w1
			var u0 = float(i) / (n - 1)
			var u1 = float(i + 1) / (n - 1)
			st.set_uv(Vector2(u0, 0.0))
			st.add_vertex(pts[i] - s0)
			st.set_uv(Vector2(u0, 1.0))
			st.add_vertex(pts[i] + s0)
			st.set_uv(Vector2(u1, 1.0))
			st.add_vertex(pts[i + 1] + s1)
			st.set_uv(Vector2(u0, 0.0))
			st.add_vertex(pts[i] - s0)
			st.set_uv(Vector2(u1, 1.0))
			st.add_vertex(pts[i + 1] + s1)
			st.set_uv(Vector2(u1, 0.0))
			st.add_vertex(pts[i + 1] - s1)
	return st.commit()


static func _side(tv: Vector3, pl: int, hint: Vector3) -> Vector3:
	if hint != Vector3.ZERO:
		var s = tv.cross(hint)
		if s.length() < 0.0001:
			s = tv.cross(Vector3.RIGHT)
		s = s.normalized()
		return s if pl == 0 else tv.cross(s).normalized()
	var rf = Vector3.UP if absf(tv.y) < 0.9 else Vector3.RIGHT
	var s2 = tv.cross(rf).normalized()
	return s2 if pl == 0 else tv.cross(s2).normalized()


# ================================================================== yapı taşları: akım
## Akan şerit (çizgi ya da perde): baş life*grow'da ileri akar, kuyruk arkadan toplanır.
## o: delay, parent (noktalar yerel), hint, twin, widths, flow, grow (0..1), lines, opacity (perde)
static func _flowing(host: Node, mat: ShaderMaterial, pts: PackedVector3Array, w: float, life: float, tint: Color, o: Dictionary) -> MeshInstance3D:
	var mi = gi(strip(pts, w, o.get("hint", Vector3.ZERO), bool(o.get("twin", true)), o.get("widths", PackedFloat32Array())), mat)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("flow", float(o.get("flow", 3.0)))
	mi.set_instance_shader_parameter("head", 0.0)
	mi.set_instance_shader_parameter("tail", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	if o.has("lines"):
		mi.set_instance_shader_parameter("lines", float(o["lines"]))
	if o.has("opacity"):
		mi.set_instance_shader_parameter("opacity", float(o["opacity"]))
	if o.has("near"):
		mi.set_instance_shader_parameter("near", float(o["near"]))
	put(host, mi, Vector3.ZERO, o.get("parent", null))
	var dl = float(o.get("delay", 0.0))
	var gr = clampf(float(o.get("grow", 0.4)), 0.05, 0.95)
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(pf(mi, "head"), 0.0, 1.0, life * gr).set_delay(dl).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "tail"), 0.0, 1.0, life * (1.0 - gr * 0.6)).set_delay(dl + life * gr * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.3).set_delay(dl + life * 0.7)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## İnce parlak akım çizgisi
static func line(host: Node, pts: PackedVector3Array, w: float, life: float, tint := AIR, o := {}) -> MeshInstance3D:
	return _flowing(host, line_mat(), pts, w, life, tint, o)


## Geniş yarı saydam hava perdesi
static func sheet(host: Node, pts: PackedVector3Array, w: float, life: float, tint := AIR, o := {}) -> MeshInstance3D:
	return _flowing(host, sheet_mat(), pts, w, life, tint, o)


## Bir düğümü izleyen canlı çizgi (mermi izi): her karede geçmiş konumlardan kameraya dönük şerit; düğüm yok olunca kuyruk toplanır.
## o: offset (düğümün yerel uzayında), spin (offset'in düğüm Z ekseninde dönüş hızı rad/sn), lead (baş genişliği çarpanı)
## kind: "line" (varsayılan) ya da "sheet" (geniş yarı saydam perde gövde; opacity, lines), near
static func follow(host: Node, target: Node3D, w: float, n: int, tint := AIR, o := {}) -> MeshInstance3D:
	var im = ImmediateMesh.new()
	var mi = gi(im, sheet_mat() if str(o.get("kind", "line")) == "sheet" else line_mat())
	if o.has("opacity"):
		mi.set_instance_shader_parameter("opacity", float(o["opacity"]))
	if o.has("lines"):
		mi.set_instance_shader_parameter("lines", float(o["lines"]))
	if o.has("near"):
		mi.set_instance_shader_parameter("near", float(o["near"]))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("flow", float(o.get("flow", 6.0)))
	mi.set_instance_shader_parameter("head", 1.0)
	mi.set_instance_shader_parameter("tail", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	put(host, mi, Vector3.ZERO)
	var tree = host.get_tree()
	var off: Vector3 = o.get("offset", Vector3.ZERO)
	var spin = float(o.get("spin", 0.0))
	var st = {"hist": [], "t": 0.0, "cb": Callable()}
	st["cb"] = func():
		var hist: Array = st["hist"]
		if not is_instance_valid(mi):
			tree.process_frame.disconnect(st["cb"])
			return
		st["t"] = float(st["t"]) + tree.root.get_process_delta_time()
		if is_instance_valid(target) and target.is_inside_tree():
			var lo = off.rotated(Vector3.FORWARD, float(st["t"]) * spin) if spin != 0.0 else off
			hist.push_front(target.global_transform * lo)
			if hist.size() > n:
				hist.pop_back()
		else:
			if hist.size() > 0:
				hist.pop_back()
			if hist.size() > 0:
				hist.pop_back()
			if hist.size() < 2:
				tree.process_frame.disconnect(st["cb"])
				mi.queue_free()
				return
		im.clear_surfaces()
		if hist.size() < 2:
			return
		var cam = mi.get_viewport().get_camera_3d()
		var cp: Vector3 = cam.global_position if cam else Vector3.UP * 100.0
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var m = hist.size()
		for i in m:
			var p: Vector3 = hist[i]
			var tv: Vector3 = hist[maxi(i - 1, 0)] - hist[mini(i + 1, m - 1)]
			if tv.length() < 0.0001:
				tv = Vector3.FORWARD
			var sd = tv.cross(cp - p)
			sd = sd.normalized() * w if sd.length() > 0.0001 else Vector3.UP * w
			var u = 1.0 - float(i) / float(maxi(n - 1, 1))
			im.surface_set_uv(Vector2(u, 0.0))
			im.surface_add_vertex(p - sd)
			im.surface_set_uv(Vector2(u, 1.0))
			im.surface_add_vertex(p + sd)
		im.surface_end()
	tree.process_frame.connect(st["cb"])
	return mi


# ================================================================== yapı taşları: kesici hilal
## Hilal bıçağı: pos'ta, bas (yerel +Y = ön kenar yönü, yerel Z = düzlem normali), size en (m). Büyüyerek belirir, söner.
## o: delay, vel (m/sn dünya), spin (rad/sn, düzlem normali etrafında), thick, jag, wisp, grow (0..1 süre oranı), parent, hold
static func blade(host: Node, pos: Vector3, bas: Basis, size: float, life: float, tint := AIR, o := {}) -> MeshInstance3D:
	var mi = gi(_quad(), blade_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("thick", float(o.get("thick", 0.3)))
	mi.set_instance_shader_parameter("jag", float(o.get("jag", 0.0)))
	mi.set_instance_shader_parameter("wisp", float(o.get("wisp", 1.0)))
	mi.set_instance_shader_parameter("fade", 1.0)
	if o.has("near"):
		mi.set_instance_shader_parameter("near", float(o["near"]))
	var parent = o.get("parent", null)
	put(host, mi, pos, parent)
	var b0 = bas.orthonormalized()
	if parent != null and is_instance_valid(parent):
		mi.basis = b0 * Basis.from_scale(Vector3(size, size, 1.0))
	else:
		mi.global_basis = b0 * Basis.from_scale(Vector3(size, size, 1.0))
	mi.scale = Vector3(size * 0.25, size * 0.25, 1.0)
	mi.visible = false
	var dl = float(o.get("delay", 0.0))
	var vel: Vector3 = o.get("vel", Vector3.ZERO)
	var spin = float(o.get("spin", 0.0))
	var gr = float(o.get("grow", 0.25))
	var p0 = mi.position
	var tw = mi.create_tween()
	if dl > 0.0:
		tw.tween_interval(dl)
	tw.tween_callback(func(): mi.visible = true)
	tw.tween_method(func(k: float):
		if not is_instance_valid(mi):
			return
		var s = size * lerpf(0.25, 1.0, minf(1.0, k / maxf(gr, 0.01)))
		var bb = b0
		if spin != 0.0:
			bb = b0.rotated(b0.z, spin * k * life)
		mi.basis = bb * Basis.from_scale(Vector3(s, s, 1.0))
		if vel != Vector3.ZERO:
			mi.position = p0 + vel * k * life
		mi.set_instance_shader_parameter("fade", 1.0 - smoothstep(0.6, 1.0, k)), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


## Hilal tabanı: ön kenar fwd yönünde, düzlem normali nrm
static func blade_basis(fwd: Vector3, nrm: Vector3) -> Basis:
	var y = fwd.normalized()
	var z = (nrm - y * nrm.dot(y))
	if z.length() < 0.001:
		z = side_of(y)
	z = z.normalized()
	var x = y.cross(z).normalized()
	return Basis(x, y, z)


# ================================================================== yapı taşları: basınç
## Basınç halkası / vakum: r0→r1 büyür. o: ring (bool, halka; false = disk), power, swirl, bill (kameraya dön), basis (bill değilse),
## parent, delay, band, glint
static func warp(host: Node, p: Vector3, r0: float, r1: float, life: float, o := {}) -> MeshInstance3D:
	var mi = gi(_quad(), warp_mat())
	var is_ring = bool(o.get("ring", true))
	var bill = bool(o.get("bill", true))
	mi.set_instance_shader_parameter("ring", 0.55 if is_ring else -1.0)
	mi.set_instance_shader_parameter("band", float(o.get("band", 0.16)))
	mi.set_instance_shader_parameter("power", float(o.get("power", 1.0)))
	mi.set_instance_shader_parameter("swirl", float(o.get("swirl", 0.0)))
	mi.set_instance_shader_parameter("bill", 1.0 if bill else 0.0)
	mi.set_instance_shader_parameter("glint", float(o.get("glint", 0.3)))
	mi.set_instance_shader_parameter("fade", 1.0)
	if o.has("near"):
		mi.set_instance_shader_parameter("near", float(o["near"]))
	var parent = o.get("parent", null)
	put(host, mi, p, parent)
	var bas: Basis = o.get("basis", Basis.IDENTITY)
	var asp: Vector3 = o.get("aspect", Vector3.ONE)
	var setb = func(s: float):
		if not is_instance_valid(mi):
			return
		if bill:
			mi.scale = Vector3.ONE * s * 2.0
		else:
			mi.basis = bas.orthonormalized() * Basis.from_scale(asp * s * 2.0)
	setb.call(r0)
	mi.visible = false
	var dl = float(o.get("delay", 0.0))
	var gfr = clampf(float(o.get("grow", 1.0)), 0.01, 1.0)
	var ff = clampf(float(o.get("fade_from", 0.45)), 0.0, 0.99)
	var tw = mi.create_tween()
	if dl > 0.0:
		tw.tween_interval(dl)
	tw.tween_callback(func(): mi.visible = true)
	tw.tween_method(func(k: float):
		var kg = minf(1.0, k / gfr)
		setb.call(lerpf(r0, r1, 1.0 - pow(1.0 - kg, 2.2)))
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("fade", 1.0 - smoothstep(ff, 1.0, k)), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


## Zemine yatık basınç halkası tabanı
static func flat_basis() -> Basis:
	return Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)


# ================================================================== yapı taşları: zemin izi
## kind 0: dir boyunca süpürülmüş toz çizgileri (length x width), 1: ışınsal (width = çap), 2: kesik yarıkları
static func scour(host: Node, p: Vector3, dir: Vector3, length: float, width: float, life: float, kind := 0, tint := Color(-1, 0, 0), o := {}) -> MeshInstance3D:
	var g = floor_at(p)
	var col = tint
	if col.r < 0.0:
		col = ground_col(g).darkened(0.18)
		col.a = 0.75
	var mi = gi(_plane(), scour_mat())
	mi.set_instance_shader_parameter("kind", float(kind))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	put(host, mi, g + Vector3.UP * 0.04)
	var f = Vector3(dir.x, 0.0, dir.z)
	if f.length() < 0.01:
		f = Vector3.FORWARD
	f = f.normalized()
	var x = f.cross(Vector3.UP).normalized()
	mi.global_basis = Basis(x * width, Vector3.UP, f * length)
	if kind == 0:
		mi.global_position = g + Vector3.UP * 0.04 + f * length * 0.5
	var dl = float(o.get("delay", 0.0))
	var tw = mi.create_tween()
	if dl > 0.0:
		tw.tween_interval(dl)
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, float(o.get("grow_t", 0.25))).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life * 0.6)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.4)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== yapı taşları: savrulan
static func _tex(key: String) -> ImageTexture:
	if _cache.has("tx_" + key):
		return _cache["tx_" + key]
	var s = 32 if key != "puff" else 64
	var img = Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var px = (x + 0.5) / s * 2.0 - 1.0
			var py = (y + 0.5) / s * 2.0 - 1.0
			img.set_pixel(x, y, _texel(key, px, py))
	var tx = ImageTexture.create_from_image(img)
	_cache["tx_" + key] = tx
	return tx


## Doku pikseli: koyu cel kontur + açık iç (renk parçacık rengiyle çarpılır)
static func _texel(key: String, px: float, py: float) -> Color:
	match key:
		"leaf":
			# sivri uçlu badem yaprak + orta damar
			var w = 0.55 * (1.0 - py * py)
			var e = 1.0 - absf(px) / maxf(w, 0.001)
			if e <= 0.0 or absf(py) > 0.95:
				return Color(1, 1, 1, 0)
			if e < 0.22:
				return Color(0.45, 0.45, 0.45, 1)
			if absf(px) < 0.05 and py > -0.8:
				return Color(0.7, 0.7, 0.7, 1)
			return Color(1, 1, 1, 1) if px > 0.0 else Color(0.85, 0.85, 0.85, 1)
		"petal":
			# yuvarlak kiraz yaprağı, uçta çentik
			var r = Vector2(px, py * 0.85 + 0.1).length()
			var notch = py < -0.55 and absf(px) < 0.18
			if r > 0.8 or notch:
				return Color(1, 1, 1, 0)
			if r > 0.68:
				return Color(0.78, 0.66, 0.7, 1)
			return Color(1, 1, 1, 1) if r < 0.4 else Color(0.93, 0.9, 0.92, 1)
		"grass":
			# ince ot yaprağı
			var w2 = 0.16 * (1.0 - (py + 1.0) * 0.5)
			if absf(px + py * 0.2) > w2 or py > 0.95:
				return Color(1, 1, 1, 0)
			return Color(1, 1, 1, 1) if absf(px + py * 0.2) < w2 * 0.5 else Color(0.6, 0.6, 0.6, 1)
		"grit":
			# düzensiz çakıl
			var a = atan2(py, px)
			var rr = 0.62 + 0.18 * sin(a * 3.0 + 1.3) + 0.1 * sin(a * 5.0)
			var r2 = Vector2(px, py).length()
			if r2 > rr:
				return Color(1, 1, 1, 0)
			if r2 > rr - 0.2:
				return Color(0.42, 0.42, 0.42, 1)
			return Color(0.9, 0.9, 0.9, 1)
		_:
			# puff: topaklı iki tonlu cel toz
			var a3 = atan2(py, px)
			var rr3 = 0.84 + 0.07 * sin(a3 * 5.0 + 0.7) + 0.05 * sin(a3 * 9.0 + 2.1)
			var r3 = Vector2(px, py).length()
			if r3 > rr3:
				return Color(1, 1, 1, 0)
			if r3 > rr3 - 0.06:
				return Color(0.74, 0.74, 0.74, 0.85)
			if r3 > 0.55 or (px + py) > 0.45:
				return Color(0.86, 0.86, 0.86, 0.9)
			return Color(1, 1, 1, 0.9)


static func _bit_mat(key: String) -> StandardMaterial3D:
	if _cache.has("bm_" + key):
		return _cache["bm_" + key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _tex(key)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["bm_" + key] = m
	return m


## Parçacık yayıcı. kind: leaf / petal / grass / grit / puff. o: life, size, dir, spread, vmin, vmax, g, damp, radius, box (Vector3),
## basis, burst, cols (Array[Color]), spin (der/sn), tang (teğet ivme, g ekseni etrafında), radial, grow ([baş, son] boy), parent
static func bits(host: Node, p: Vector3, n: int, kind: String, o := {}) -> GPUParticles3D:
	var life = float(o.get("life", 1.2))
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 45.0))
	pm.initial_velocity_min = float(o.get("vmin", 2.0))
	pm.initial_velocity_max = float(o.get("vmax", 6.0))
	pm.gravity = o.get("g", Vector3(0, -4.0, 0))
	pm.damping_min = float(o.get("damp", 1.0))
	pm.damping_max = float(o.get("damp", 1.0)) * 1.4
	if o.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = o["box"]
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = maxf(0.01, float(o.get("radius", 0.5)))
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var sp = float(o.get("spin", 360.0))
	pm.angular_velocity_min = -sp
	pm.angular_velocity_max = sp
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	if o.has("tang"):
		pm.tangential_accel_min = float(o["tang"]) * 0.7
		pm.tangential_accel_max = float(o["tang"])
	if o.has("radial"):
		pm.radial_accel_min = float(o["radial"]) * 0.7
		pm.radial_accel_max = float(o["radial"])
	pm.turbulence_enabled = bool(o.get("turb", kind != "grit"))
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 3.0
	var cols: Array = o.get("cols", [Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var pc = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / float(maxi(cols.size() - 1, 1)))
		pc.append(cols[i])
	g.offsets = offs
	g.colors = pc
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var gw: Array = o.get("grow", [1.0, 1.0])
	var cv = Curve.new()
	cv.max_value = maxf(1.0, maxf(float(gw[0]), float(gw[1])))
	cv.add_point(Vector2(0.0, float(gw[0])))
	cv.add_point(Vector2(1.0, float(gw[1])))
	var ct = CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	var gpp = GPUParticles3D.new()
	gpp.amount = maxi(1, n)
	gpp.lifetime = life
	gpp.one_shot = true
	gpp.explosiveness = float(o.get("burst", 0.8))
	gpp.randomness = 0.5
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * float(o.get("size", 0.15))
	q.material = _bit_mat(kind)
	gpp.draw_pass_1 = q
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	put(host, gpp, p, o.get("parent", null))
	if o.has("basis"):
		gpp.global_basis = o["basis"]
	gpp.emitting = true
	kill(host, life + 0.8, gpp)
	return gpp


## Yaprak / ot rengi listesi (biyoma göre); karlı / çöl / kayalıkta çakıl
static func leaf_cols(_p: Vector3) -> Array:
	return [Color(0.55, 0.78, 0.32, 1), Color(0.78, 0.82, 0.3, 1), Color(0.45, 0.65, 0.25, 0.0)]


## Toz rengi listesi (iki tonlu, sönen)
static func dust_cols(p: Vector3, a := 0.85) -> Array:
	var c = ground_col(p)
	return [Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, a), Color(c.r * 0.95, c.g * 0.95, c.b * 0.95, a * 0.7), Color(c.r, c.g, c.b, 0.0)]


## Fırlayan kaya parçaları (katı, düşer, döner). speed: çıkış hızı
static func chunks(host: Node, p: Vector3, n: int, speed: float, col: Color, size := 0.3, dir := Vector3.UP) -> void:
	for i in n:
		var b = MB.new()
		var s = size * randf_range(0.6, 1.3)
		b.add("box", Vector3.ZERO, Vector3(s, s * randf_range(0.5, 0.9), s * randf_range(0.6, 1.1)), col.darkened(randf_range(0.0, 0.25)), Vector3(randf() * 40.0, randf() * 90.0, randf() * 40.0))
		var mi = gi(b.build(rock_mat()), null)
		put(host, mi, p + Vector3(randf_range(-0.4, 0.4), 0.1, randf_range(-0.4, 0.4)))
		var v = (dir.normalized() + Vector3(randf_range(-0.7, 0.7), randf_range(0.2, 0.9), randf_range(-0.7, 0.7))).normalized() * speed * randf_range(0.6, 1.1)
		var p0 = mi.global_position
		var spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var life = randf_range(0.8, 1.3)
		var gy = Game.jutsu_floor(p0.x, p0.z)
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if not is_instance_valid(mi):
				return
			var q = p0 + v * t + Vector3.DOWN * 9.0 * t * t
			q.y = maxf(q.y, gy + s * 0.3)
			mi.global_position = q
			mi.rotation = spin * t, 0.0, life, life)
		tw.tween_interval(0.6)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.35)
		tw.tween_callback(mi.queue_free)


# ================================================================== yapı taşları: hava küresi / sabit çizgi
## Sıkıştırılmış hava küresi (mermi gövdesi): pos'ta, size yarıçap. o: parent, tear, life (verilirse büyüyerek belirir ve söner)
static func orb(host: Node, pos: Vector3, size: float, tint := AIR, o := {}) -> MeshInstance3D:
	var mi = gi(_quad(), orb_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("tear", float(o.get("tear", 0.5)))
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("fade", 1.0)
	if o.has("near"):
		mi.set_instance_shader_parameter("near", float(o["near"]))
	put(host, mi, pos, o.get("parent", null))
	mi.scale = Vector3.ONE * size * 2.0
	if o.has("life"):
		var life = float(o["life"])
		mi.scale = Vector3.ONE * size * 0.4
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * size * 2.0, life * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.7).set_delay(0.0)
		tw.tween_callback(mi.queue_free)
	return mi


## Akmayan sabit çizgi / perde (mermiye, silaha bağlı kalıcı gövde): baş ve kuyruk sabit; ömrü sahibi belirler.
## kind: "line" ya da "sheet"; o: parent, hint, twin, widths, flow, opacity, lines
static func fixed(host: Node, pts: PackedVector3Array, w: float, kind := "line", tint := AIR, o := {}) -> MeshInstance3D:
	var mi = gi(strip(pts, w, o.get("hint", Vector3.ZERO), bool(o.get("twin", true)), o.get("widths", PackedFloat32Array())), sheet_mat() if kind == "sheet" else line_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("flow", float(o.get("flow", 5.0)))
	mi.set_instance_shader_parameter("head", 1.0)
	mi.set_instance_shader_parameter("tail", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	if o.has("opacity"):
		mi.set_instance_shader_parameter("opacity", float(o["opacity"]))
	if o.has("lines"):
		mi.set_instance_shader_parameter("lines", float(o["lines"]))
	if o.has("near"):
		mi.set_instance_shader_parameter("near", float(o["near"]))
	put(host, mi, Vector3.ZERO, o.get("parent", null))
	return mi
