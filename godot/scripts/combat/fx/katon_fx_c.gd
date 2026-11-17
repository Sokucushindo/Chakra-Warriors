class_name KatonFXC
extends RefCounted
## Katon grubu C: on beş tekniğin görselleri. Ateş malzemesi / yapı taşı KatonLib'den; şekil, hareket ve sahne her tekniğin kendisinin.
## Kanon ayrımları: Amaterasu / Enton KARA alev (bu dosyanın kendi kara alev gölgelendiricileri; KatonLib alevinin renk değişimi değil),
## Gudōdama / Gudōkasa Arayış Topu (ateş değil: kendi mat-siyah sıvı küre gölgelendiricisi + silinen madde kırıntısı),
## Susanoo: Kaien gerçek Susanoo'nun matkabını kullanır, alev sargısı burada. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.

const FIRE_L := Color(1.0, 0.58, 0.2)
const CRIM_L := Color(1.0, 0.28, 0.16)
const DARK_L := Color(0.55, 0.12, 0.35)

static var _cache := {}


# ================================================================== kendi gölgelendiricileri
## Amaterasu kara alevi (eksenli billboard yaprağı, taban orijinde): üç kalın, ağır yuvarlanan, kanca uçlu mürekkep dili;
## gövde zifiri siyah, içte koyu mor parıltı bandı, dış kenarda ince için için yanan kızıl-mor çizgi. Parlamaz, ışık saçmaz.
const BLACKFIRE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;

KNOISE

void vertex() {
	vec3 ax = MODEL_MATRIX[1].xyz;
	float sy = max(length(ax), 0.0001);
	ax /= sy;
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 tocam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	vec3 rt = cross(ax, tocam);
	float rl = length(rt);
	rt = rl > 0.0001 ? rt / rl : vec3(1.0, 0.0, 0.0);
	vec3 fw = cross(rt, ax);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rt * sx, 0.0), vec4(ax * sy, 0.0), vec4(fw * sx, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = TIME;
	float y = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float e = -1.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float r1 = kh(vec2(seed + fi * 1.7, 3.3));
		float cx = (fi - 1.0) * 0.36 + (r1 - 0.5) * 0.12;
		float ht = (0.6 + 0.4 * r1) * (1.0 - abs(cx) * 0.3) * (0.86 + 0.14 * sin(t * 2.6 + fi * 2.0 + seed));
		float yy = y / max(ht, 0.05);
		if (yy < 1.3) {
			float hook = sin(yy * 3.4 - t * 2.0 + fi * 2.3 + seed) * 0.24 * yy * yy + (kf(vec2(fi + seed, yy * 2.0 - t * 1.3)) - 0.5) * 0.4 * yy;
			float w = (0.25 + 0.09 * r1) * pow(max(1.0 - yy, 0.0), 0.6) * smoothstep(-0.1, 0.22, yy);
			e = max(e, 1.0 - abs(x - cx - hook) / max(w, 0.0001));
		}
	}
	float bw = 0.78 * max(1.0 - y * 1.8, 0.0);
	e = max(e, (1.0 - abs(x) / max(bw, 0.0001)) * max(1.0 - y * 1.6, 0.0));
	e *= heat * (0.8 + 0.4 * kf(vec2(x * 2.5 + seed, y * 3.0 - t * 1.8)));
	if (e < 0.06) {
		discard;
	}
	// zifiri gövde; dışta ince saf siyah kontur, onun hemen içinde çok koyu kızıl-mor bant (iç kenar)
	vec3 col = vec3(0.006, 0.004, 0.006);
	if (e < 0.13) {
		col = vec3(0.0, 0.0, 0.0);
	} else if (e < 0.24) {
		col = vec3(0.05, 0.006, 0.022);
	}
	float sh = kn(vec2(x * 4.0 + seed, y * 5.0 - t * 2.6));
	if (e > 0.55 && sh > 0.78) {
		col = vec3(0.025, 0.006, 0.02);
	}
	ALBEDO = col;
	ALPHA = fade * smoothstep(1.0, 5.0, -VERTEX.z);
}
"""

## Kara alev kütlesi (küre / koni mesh): yüzey yukarı akan gürültüyle kabarır, siluet yalayan dillerle yırtılır;
## zifiri gövde, ince mor-kızıl kenar. wob: yüzey kabarması (koni dikende düşük).
const BLACKMASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float wob = 0.3;

varying vec3 lp;

KNOISE

void vertex() {
	lp = VERTEX;
	float n = kf(VERTEX.xz * 2.0 + VERTEX.yy * 1.4 + vec2(seed * 3.0, -TIME * 1.1));
	VERTEX += NORMAL * (n - 0.5) * wob;
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = kf(lp.xz * 2.6 + vec2(seed, lp.y * 2.0 - TIME * 1.8));
	float edge = fv + (n - 0.5) * 0.45;
	if (edge < 0.14 * (2.0 - min(heat, 1.0))) {
		discard;
	}
	vec3 col = vec3(0.006, 0.004, 0.006);
	if (edge < 0.24) {
		col = vec3(0.0, 0.0, 0.0);
	} else if (edge < 0.36) {
		col = vec3(0.05, 0.006, 0.022);
	}
	float sh = kn(lp.xy * 5.0 + vec2(seed, -TIME * 2.2));
	if (fv > 0.6 && sh > 0.8) {
		col = vec3(0.025, 0.006, 0.02);
	}
	ALBEDO = col;
	ALPHA = fade * smoothstep(1.0, 4.0, -VERTEX.z);
}
"""

## Arayış Topu (Gudōdama): ateş değil — mat zifiri sıvı küre; ince gri cel kenar ışığı, keskin dış mürekkep konturu,
## tek parlak benek. wob: yüzeyin sıvı gibi dalgalanması (biçim değiştirirken artar).
const TSB_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

instance uniform float wob = 0.04;
instance uniform float seed = 0.0;

KNOISE

void vertex() {
	float n = kn(VERTEX.xy * 3.0 + VERTEX.zz * 2.0 + vec2(seed, TIME * 1.5));
	VERTEX += NORMAL * (n - 0.5) * wob;
}

void fragment() {
	vec3 nn = normalize(NORMAL);
	float fv = clamp(dot(nn, VIEW), 0.0, 1.0);
	vec3 col = vec3(0.026, 0.026, 0.032);
	if (fv < 0.3) {
		col = vec3(0.12, 0.12, 0.13);
	}
	if (fv < 0.12) {
		col = vec3(0.008, 0.008, 0.01);
	}
	vec3 lv = normalize(vec3(-0.45, 0.7, 0.55));
	float sp = dot(normalize(lv + VIEW), nn);
	if (sp > 0.965) {
		col = vec3(0.36, 0.36, 0.38);
	}
	ALBEDO = col;
}
"""

## Yağ seli (şerit mesh; UV.x boy, UV.y en): koyu amber, akan parlak yağ çizgileri; ignite ilerledikçe yağ uçtan uca alev
## rampasına döner (tutuşma cephesi akıntı boyunca koşar).
const OIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float head = 1.0;
instance uniform float ignite = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float tiles = 10.0;

KNOISE

void fragment() {
	float u = UV.x;
	float v = UV.y * 2.0 - 1.0;
	if (u > head) {
		discard;
	}
	// gürültü metre ölçeğinde ince (tiles = şeridin metre boyu): dev mesh'te kocaman leke olmasın
	float n = kn(vec2(u * tiles * 1.6 - TIME * 3.0, v * 3.0 + seed));
	float edge = 1.0 - abs(v + (n - 0.5) * 0.18);
	if (edge < 0.02) {
		discard;
	}
	// yuvarlak, parlak amber akış: kenara doğru koyulaşır, ortada akan ince parlak çizgi
	vec3 col = mix(vec3(0.36, 0.2, 0.04), vec3(0.62, 0.4, 0.09), smoothstep(0.15, 0.6, edge));
	float gl = kn(vec2(u * tiles * 3.0 - TIME * 4.5, seed * 3.0));
	float band = 1.0 - smoothstep(0.0, 0.12, abs(v + 0.3));
	col = mix(col, vec3(0.92, 0.78, 0.42), band * smoothstep(0.45, 0.75, gl) * 0.85);
	float burn = ignite * 1.2 - u - (n - 0.5) * 0.08;
	if (burn > 0.0) {
		// tutuşan yağ: kararır, içinde kızgın kor damarları (asıl alev üstündeki dillerde)
		float f = kn(vec2(u * tiles * 2.2 - TIME * 2.0, v * 4.0 + seed));
		col = mix(vec3(0.16, 0.06, 0.02), vec3(0.95, 0.38, 0.06), smoothstep(0.55, 0.8, f) * smoothstep(0.2, 0.6, edge));
	}
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = 0.92 * fade * smoothstep(0.02, 0.35, edge) * smoothstep(1.0, 5.0, -VERTEX.z);
}
"""

## Yer halkası (PlaneMesh 2x2). kind 0: kuchiyose mühür çemberi (fırça izli çift halka + yazı çentikleri, mürekkep);
## kind 1: Arayış Topu silme dalgası (koyu, kenarı dağınık halka).
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float grow = 1.0;
instance uniform float seed = 0.0;
instance uniform float kind = 0.0;

KNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p) / max(grow, 0.001);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	float br = kn(vec2(a * 6.0 + seed, r * 9.0));
	float m = 0.0;
	vec3 col = vec3(0.05, 0.04, 0.04);
	if (kind < 0.5) {
		m = step(0.86, r + (br - 0.5) * 0.03) * step(r, 0.95);
		m = max(m, step(0.56, r) * step(r, 0.6 + (br - 0.5) * 0.02));
		float sec = fract(a / 6.2831853 * 14.0 + seed);
		m = max(m, step(0.63, r) * step(r, 0.82) * step(abs(sec - 0.5), 0.06 + br * 0.04));
		m *= step(0.18, br);
	} else {
		m = smoothstep(0.7, 0.9, r + (br - 0.5) * 0.12) * (1.0 - smoothstep(0.95, 1.0, r));
		col = vec3(0.02, 0.02, 0.025);
	}
	float al = m * fade;
	if (al < 0.01) {
		discard;
	}
	ALBEDO = col;
	ALPHA = al;
}
"""


static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("KNOISE", KatonLib.KNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _sphere_mesh() -> SphereMesh:
	if not _cache.has("sph"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 24
		s.rings = 12
		_cache["sph"] = s
	return _cache["sph"]


# ================================================================== yapı taşları: kara alev
## Kalıcı kara alev dili (düğüme iliştirmek için)
static func _black_tongue_mi(h: float, w: float, ax: Vector3, heat := 1.0) -> MeshInstance3D:
	var mi = KatonLib.gi(KatonLib._quad_base(), _mat("bfire", BLACKFIRE_SHADER))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.basis = KatonLib.axis_basis(ax) * Basis.from_scale(Vector3(w, h, w))
	return mi


## Sahnede yaşayan kara alev dili: doğar, ağır ağır kabarır, ısısı düşüp kısalır, söner
static func _black_tongue(host: Node, p: Vector3, h: float, w: float, life: float, ax := Vector3.UP, vel := Vector3.ZERO) -> MeshInstance3D:
	var mi = _black_tongue_mi(h * 0.3, w * 0.6, ax, 1.1)
	KatonLib.put(host, mi, p)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(w, h, w), life * 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(KatonLib.pf(mi, "heat"), 1.1, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Kara alev kütlesi örneği (küre): yarıçap r
static func _black_mass_mi(r: float, wob := 0.3) -> MeshInstance3D:
	var mi = KatonLib.gi(_sphere_mesh(), _mat("bmass", BLACKMASS_SHADER))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", 1.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("wob", wob)
	mi.scale = Vector3.ONE * r
	return mi


## Kara alev küresi: kütle + tepesinden kalkan üç ağır kara dil (çocuk düğüm, birlikte ölçeklenir)
static func _black_orb(r: float) -> Node3D:
	var root = Node3D.new()
	root.add_child(_black_mass_mi(r, 0.28))
	for k in 3:
		var a = k * TAU / 3.0 + randf() * 0.5
		var tg = _black_tongue_mi(r * 2.2, r * 1.6, Vector3(cos(a) * 0.35, 1.0, sin(a) * 0.35), 1.0)
		tg.position = Vector3(cos(a) * r * 0.3, r * 0.35, sin(a) * r * 0.3)
		root.add_child(tg)
	return root


## Kara alev patlaması: dışa / yukarı savrulan ağır kara diller + yere çöken koyu leke (ışık yok)
static func _black_burst(host: Node, p: Vector3, s: float) -> void:
	for k in 7:
		var a = k * TAU / 7.0 + randf() * 0.4
		var ax = Vector3(cos(a), randf_range(0.6, 1.4), sin(a)).normalized()
		_black_tongue(host, p, randf_range(1.2, 2.0) * s, randf_range(0.8, 1.2) * s, randf_range(0.45, 0.7), ax, ax * 1.5 * s)
	var core = _black_mass_mi(0.3 * s, 0.4)
	KatonLib.put(host, core, p)
	var tw = core.create_tween().set_parallel()
	tw.tween_property(core, "scale", Vector3.ONE * 1.1 * s, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(KatonLib.pf(core, "heat"), 1.0, 0.0, 0.6).set_delay(0.1)
	tw.chain().tween_callback(core.queue_free)


# ================================================================== yapı taşları: Arayış Topu
static func _tsb_mi(mesh: Mesh, wob := 0.04) -> MeshInstance3D:
	var mi = KatonLib.gi(mesh, _mat("tsb", TSB_SHADER))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("wob", wob)
	return mi


static func _tsb_ball(r: float) -> MeshInstance3D:
	var mi = _tsb_mi(_sphere_mesh(), 0.05)
	mi.scale = Vector3.ONE * r
	return mi


## Arayış Topundan şakujō / mızrak (ileri = -Z): ince sap, ucunda yaprak biçimli ağız, arkada halka düğüm
static func _tsb_staff() -> Node3D:
	if not _cache.has("staff_mesh"):
		var b = MB.new()
		var k = Color(0.05, 0.05, 0.06)
		b.add("cyl", Vector3(0, 0, 0.1), Vector3(0.09, 2.6, 0.09), k, Vector3(90, 0, 0), 8)
		b.add("sphere", Vector3(0, 0, -1.35), Vector3(0.26, 0.1, 0.55), k, Vector3.ZERO, 10)
		b.add("cone", Vector3(0, 0, -1.8), Vector3(0.16, 0.5, 0.06), k, Vector3(-90, 0, 0), 6)
		b.add("sphere", Vector3(0, 0, 1.35), Vector3(0.16, 0.16, 0.16), k, Vector3.ZERO, 8)
		_cache["staff_mesh"] = b.build(null)
	var root = Node3D.new()
	root.add_child(_tsb_mi(_cache["staff_mesh"], 0.02))
	return root


## Silinen madde kırıntıları (anime: Arayış Topunun değdiği şey gri-beyaz pul pul dağılıp yok olur): yavaş sarmal savrulma
static func _erase_flakes(host: Node, p: Vector3, n: int, spread: float, bias := Vector3.ZERO) -> void:
	if not _cache.has("flake_mesh"):
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.12, 0.16, 0.02), Color(0.82, 0.83, 0.85))
		b.add("box", Vector3(0.05, -0.05, 0.0), Vector3(0.07, 0.09, 0.02), Color(0.6, 0.61, 0.63), Vector3(0, 0, 30))
		_cache["flake_mesh"] = b.build(KatonLib.flat_mat())
	for i in n:
		var mi = KatonLib.gi(_cache["flake_mesh"], null)
		var dirv = (Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized() + bias).normalized()
		var p0 = p + dirv * randf_range(0.1, 0.5)
		KatonLib.put(host, mi, p0)
		mi.scale = Vector3.ONE * randf_range(0.6, 1.5)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var life = randf_range(0.6, 1.2)
		var swirl = randf_range(-2.5, 2.5)
		var dist = spread * randf_range(0.5, 1.0)
		var tw = mi.create_tween()
		tw.tween_method(func(x: float) -> void:
			if not is_instance_valid(mi):
				return
			var off = dirv.rotated(Vector3.UP, swirl * x) * dist * (1.0 - pow(1.0 - x, 2.0))
			mi.global_position = p0 + off + Vector3.UP * x * 0.6
			mi.rotation += Vector3(0.2, 0.3, 0.1)
			mi.scale = Vector3.ONE * maxf(0.02, 1.0 - x * x) * 1.1, 0.0, 1.0, life)
		tw.tween_callback(mi.queue_free)


## Silme anı: madde Arayış Topuna çekilir gibi içe çöken siyah nokta + dağınık koyu halka + kırıntılar
static func _tsb_erase(host: Node, p: Vector3, s: float) -> void:
	var dot = _tsb_ball(0.15 * s)
	KatonLib.put(host, dot, p)
	var tw = dot.create_tween()
	tw.tween_property(dot, "scale", Vector3.ONE * 0.75 * s, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(dot, "scale", Vector3.ONE * 0.02, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(dot.queue_free)
	_ring(host, p, 1.6 * s, 0.35, 1.0, Vector3.ZERO)
	_erase_flakes(host, p, int(14 * s) + 4, 2.2 * s)


## Yer / hava halkası: kind 0 mühür, 1 silme dalgası. nrm sıfırsa kameraya bakar (silme dalgası), değilse o düzlemde yatar
static func _ring(host: Node, p: Vector3, r: float, life: float, kind: float, nrm: Vector3) -> MeshInstance3D:
	var mi = KatonLib.gi(KatonLib._plane(), _mat("ring", RING_SHADER))
	mi.set_instance_shader_parameter("kind", kind)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("grow", 0.2)
	KatonLib.put(host, mi, p)
	var n = nrm
	if n == Vector3.ZERO:
		var cam = host.get_viewport().get_camera_3d()
		n = (cam.global_position - p).normalized() if cam else Vector3.UP
	mi.global_basis = KatonLib.axis_basis(n) * Basis.from_scale(Vector3(r, 1.0, r))
	var tw = mi.create_tween()
	tw.tween_method(KatonLib.pf(mi, "grow"), 0.2, 1.0, life * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(KatonLib.pf(mi, "fade"), 1.0, 0.0, life * 0.55)
	tw.tween_callback(mi.queue_free)
	return mi


# ================================================================== ortak oynanış (eski görsel çağrıların oyun etkisi)
## Eski ateş patlamasının oyun tarafı: saç/kumaş savrulur, zemine yakınsa yanan zemin, sarsıntı
static func _blast_marks(pos: Vector3, s: float) -> void:
	Dangle.blast(pos, 40.0 * s, 6.0 * s)
	var g = KatonLib.floor_at(pos)
	if pos.y - g.y < 3.0 * s:
		GroundFX.add(g + Vector3.UP * 0.12, "burning", 1.2 * s + 0.8, 4.0)
	if Game.world:
		Game.world.env.add_shake(0.7 * s)
	Sfx.play("boom", pos, 1.3)


## Eski sinematik geri çekilmenin karşılığı: oyuncu kamerası kısa süre geri çekilir
static func _cam_pull(c: Node3D, extra: float, hold: float) -> void:
	if not "cam_dist" in c or c.has_meta("cine"):
		return
	var base: float = c.cam_dist
	c.set_meta("cine", true)
	var tw = c.create_tween().set_ignore_time_scale(true)
	tw.tween_property(c, "cam_dist", base + extra, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(c, "cam_dist", base, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): c.remove_meta("cine"))


static func _eye_mat() -> StandardMaterial3D:
	if not _cache.has("eye"):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.08, 0.08)
		_cache["eye"] = m
	return _cache["eye"]


## Sharingan anı: iki gözde kızıl parıltı (baş kemiğine bağlı), şakaktan geriye kısa kızıl çizgi
static func _eyes(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb == null:
		return
	for sx in [-1.0, 1.0]:
		var mi = KatonLib.gi(_sphere_mesh(), _eye_mat())
		mi.position = Vector3(sx * 0.032, 0.065, 0.095)
		mi.scale = Vector3(0.011, 0.008, 0.004)
		hb.add_child(mi)
		var gl = KatonLib.glow_mi(Color(1.0, 0.12, 0.1), 0.05)
		gl.position = Vector3(sx * 0.034, 0.065, 0.1)
		hb.add_child(gl)
		var tw = gl.create_tween()
		tw.tween_property(gl, "scale", Vector3.ONE * 0.16, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(gl, "scale", Vector3.ONE * 0.06, 0.3)
	pj.free_after(dur, hb)


# ================================================================== 1) Bakufu Ranbu
## Patlama Dalgası Çılgın Dansı (ref): ağızdan çıkan alev kullanıcının önünde üç kollu kalın bir spirale sarılır; kolların
## kenarı koyu kızıl yırtık, içi turuncu-sarı. Spiral dönerek açılır, ileri savrulur; ardında yerde sarmal yanık kalır.
static func katon_bakufu_ranbu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var d = pj.fwd(c, t)
	KatonLib.spiral_in(pj, pj._mouth_pos(c), 0.0, 0.25, 8, 1.0)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var mo = pj._mouth_pos(c)
		var root = Node3D.new()
		KatonLib.put(pj, root, mo + d * 1.2)
		root.global_basis = Basis.looking_at(d, Vector3.UP)
		var spin = Node3D.new()
		root.add_child(spin)
		var arms: Array = []
		for a in 3:
			var pts = PackedVector3Array()
			var wid = PackedFloat32Array()
			for i in 26:
				var u = i / 25.0
				var ang = a * TAU / 3.0 + u * TAU * 1.25
				var r = 0.25 + u * 2.4
				pts.append(Vector3(cos(ang) * r, sin(ang) * r, -u * 1.1 + u * u * 0.5))
				wid.append(0.3 + 0.7 * u)
			var rb = KatonLib.ribbon_mi(pts, 0.6, 0.0, {"hint": Vector3(0, 0, 1), "twin": true, "flow": 3.5, "tiles": 5.0, "rag": 0.5, "widths": wid, "heat": 1.0})
			rb.set_instance_shader_parameter("head", 0.0)
			spin.add_child(rb)
			arms.append(rb)
		spin.scale = Vector3.ONE * 0.2
		var tw = root.create_tween()
		for rb in arms:
			tw.parallel().tween_method(KatonLib.pf(rb, "head"), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(spin, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(spin, "rotation:z", -TAU * 1.6, 1.3)
		tw.parallel().tween_property(root, "global_position", mo + d * 15.0, 1.3).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(spin, "scale", Vector3.ONE * 1.35, 1.0).set_delay(0.35)
		for rb in arms:
			tw.parallel().tween_method(KatonLib.pf(rb, "tail"), 0.0, 1.0, 0.45).set_delay(1.0)
			tw.parallel().tween_method(KatonLib.pf(rb, "heat"), 1.0, 0.2, 0.45).set_delay(1.0)
		tw.tween_callback(root.queue_free)
		var light = OmniLight3D.new()
		light.light_color = FIRE_L
		light.light_energy = 5.0
		light.omni_range = 24.0
		root.add_child(light)
		# ağızdan spirale beslenen alev: dönen spiralin merkezine akan kısa diller
		pj.every(0.45, 0.05, func(i, _k):
			if not pj.live(c):
				return
			var m2 = pj._mouth_pos(c)
			KatonLib.tongue(pj, m2 + d * 0.3, 2.2, 0.8, 0.28, d + Vector3.UP * 0.1, d * 7.0, 0.0, 4, 1.0)
			if i % 3 == 0:
				KatonLib.embers(pj, m2 + d * 1.5, 6, 0.6, 0.0, {"dir": d, "spread": 50.0, "vmin": 3.0, "vmax": 7.0, "life": 0.7}))
		pj.after(0.6, func():
			if is_instance_valid(root):
				KatonLib.embers(pj, root.global_position, 26, 2.2, 0.0, {"dir": d, "spread": 80.0, "vmin": 4.0, "vmax": 10.0, "life": 1.0}))
		KatonLib.scorch(pj, c.global_position + d * 7.0, 4.5, 6.0, 1.0, 0.0, 0.8)
		pj.after(0.45, func():
			if pj.live(c):
				Combat.hit_zone(c, c.global_position, d, 18.0, 22.0, 4.0, pj.inf(c, "katon_bakufu_ranbu", 1.6, {"knock": 12.0, "kind": "heavy", "element": "katon", "burn": 3.0})))
		pj.shake(0.7))
	Sfx.play("fire", c.global_position, 0.5)


# ================================================================== 2) Gōka Mekkyaku
## Büyük Ateş Yok Ediş (ref): derin nefes (göğüste kabaran ısı, sıcak hava titrer, kor zerreleri ağza çekilir); ağızdan
## kesintisiz alev ileri akar, önünde 46 m'ye açılan kemerli bir alev cephesi yürür (ortası önde), cephenin dibinde
## yuvarlanan alev topakları, arkasında alev denizi, yerde kavrulmuş şeritler.
static func katon_goka_mekkyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_eyes(pj, c, 2.0)
	var m0 = pj._mouth_pos(c)
	KatonLib.glow(pj, m0, 1.4, FIRE_L, 0.5)
	KatonLib.shimmer(pj, c.global_position + Vector3.UP * 1.4, 2.6, 3.2, 1.0)
	for k in 8:
		var a = k * TAU / 8.0
		var rp = m0 + Vector3(cos(a), randf_range(-0.6, 0.4), sin(a)) * 2.4
		KatonLib.embers(pj, rp, 3, 0.2, 0.0, {"dir": (m0 - rp).normalized(), "spread": 8.0, "vmin": 4.0, "vmax": 5.0, "g": Vector3.ZERO, "life": 0.45, "damp": 0.0})
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 2.2)
	pj.anim(c, "cast_out", 0.8)
	_cam_pull(c, 0.6, 0.5)
	var mo: Vector3 = Jutsu._mouth(c) + d * 0.8
	Sfx.play("fire", mo, 0.5, 1.6)
	var start: Vector3 = pj.gp(c.global_position)
	var root = Node3D.new()
	KatonLib.put(pj, root, Vector3(mo.x, start.y, mo.z))
	root.global_basis = Basis.looking_at(d, Vector3.UP)
	var front: Array = []
	var NF = 16
	for n in NF:
		var tm = KatonLib.tongue_mi(1.0, 1.0, Vector3.UP, 0.0, 7, 0.0, 1.0)
		tm.visible = false
		root.add_child(tm)
		front.append(tm)
	var light = OmniLight3D.new()
	light.light_color = FIRE_L
	light.light_energy = 5.0
	light.omni_range = 40.0
	root.add_child(light)
	var hits = []
	pj.every(2.0, 0.05, func(i, k):
		var reach = 6.0 + minf(1.0, k * 1.3) * 40.0
		var w = lerpf(4.0, 46.0, minf(1.0, k * 1.5))
		var h = lerpf(3.0, 12.0, minf(1.0, k * 1.8))
		var cen = pj.gp(start + d * reach * 0.8)
		light.global_position = cen + Vector3.UP * 4.0
		# kemerli cephe: ortadaki diller önde ve yüksek, kanatlar geride ve alçak
		for n in NF:
			var tm: MeshInstance3D = front[n]
			if not is_instance_valid(tm):
				continue
			var u = float(n) / (NF - 1) - 0.5
			var edge = 1.0 - absf(u) * 0.9
			var hh = h * edge * (0.75 + 0.3 * sin(i * 0.7 + n * 1.9))
			var ww = w / NF * 2.3
			tm.visible = true
			tm.position = Vector3(u * w, 0.0, -reach + absf(u) * w * 0.3)
			tm.basis = KatonLib.axis_basis(Vector3(u * 0.5, 1.0, -0.45)) * Basis.from_scale(Vector3(ww, hh, ww))
		# cephenin dibinde ileri yuvarlanan topaklar
		for q in 2:
			var uq = randf_range(-0.42, 0.42)
			var gpq = root.to_global(Vector3(uq * w, h * 0.22, -reach + absf(uq) * w * 0.3 + 1.0))
			KatonLib.mass(pj, gpq, h * 0.14, h * 0.3, 0.6, d * 7.0 + Vector3.UP * 1.5, 0.0, 1.0, 2.0, 0.8)
		# arkadaki alev denizi
		if i % 2 == 0:
			for q in 3:
				var dz = randf() * reach
				var lx = randf_range(-0.5, 0.5) * lerpf(4.0, w, dz / maxf(reach, 0.01))
				var sp = KatonLib.floor_at(root.to_global(Vector3(lx, 0.0, -dz)))
				KatonLib.tongue(pj, sp, h * randf_range(0.2, 0.38), randf_range(1.4, 2.6), 0.55, Vector3(0, 1, 0) + d * 0.3, d * 2.0, 0.0, 6, 1.0)
			if is_instance_valid(c):
				KatonLib.tongue(pj, Jutsu._mouth(c), 3.5, 1.6, 0.3, d - Vector3.UP * 0.25, d * 12.0, 0.0, 5, 1.0)
		if i % 3 == 0:
			for n in 5:
				var pq = cen + side * (n - 2) * w * 0.2
				GroundFX.add(pq, "cracked", 2.1, 5.0)
				KatonLib.scorch(pj, pq, 3.5, 8.0)
				WorldDamage.impact(pq, 4.0, {"dmg": 30.0, "element": "katon", "kind": "light"})
		for n in 7:
			var hp = cen + Vector3.UP * 1.5 + side * (n - 3) * w * 0.15
			for e in pj.hit(c, hp, 3.8, pj.inf(c, "katon_goka_mekkyaku", 0.6, {"knock": 9.0, "kind": "heavy", "element": "katon", "burn": 3.0}), hits):
				hits.append(e)
		if i % 6 == 0:
			pj.shake(0.35)
	, func():
		for row in 3:
			for n in 5:
				GroundFX.add(pj.gp(start + d * (12.0 + row * 12.0) + side * (n - 2) * 8.0), "burning", 5.5, 6.0, c)
		var tw = root.create_tween().set_parallel()
		for tm in front:
			if is_instance_valid(tm):
				tw.tween_method(KatonLib.pf(tm, "heat"), 1.0, 0.0, 0.7)
		tw.tween_property(light, "light_energy", 0.0, 0.7)
		tw.chain().tween_callback(root.queue_free))


# ================================================================== 3) Gōen no Jutsu
## Büyük Alev (ref: dikey alev perdesi): ağızdan 1.5 sn, bakılan yönü izleyen alev seli; sel ilerledikçe önünde yükselen
## yan yana dikey alev sütunları uzaktan bir perde gibi görünür (uzaktaki sütunlar daha yüksek); yerde yanık şeritleri.
static func katon_goen_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var d = pj.fwd(c, t)
	KatonLib.glow(pj, pj._mouth_pos(c), 0.9, FIRE_L, 0.5)
	pj.anim(c, "push", 1.5)
	var light = OmniLight3D.new()
	light.light_color = FIRE_L
	light.light_energy = 4.0
	light.omni_range = 26.0
	KatonLib.put(pj, light, c.global_position + d * 8.0 + Vector3.UP * 3.0)
	pj.every(1.5, 0.05, func(i, _k):
		var fd = c.face_dir() if pj.live(c) else d
		var sd = fd.cross(Vector3.UP).normalized()
		var base_p = c.global_position if is_instance_valid(c) else light.global_position
		if is_instance_valid(light):
			light.global_position = base_p + fd * 9.0 + Vector3.UP * 3.0
		for q in 3:
			var u = randf()
			var dist = 2.0 + u * 18.0
			var lat = randf_range(-1.0, 1.0) * dist * 0.25
			var at = KatonLib.floor_at(base_p + fd * dist + sd * lat)
			KatonLib.tongue(pj, at, 2.5 + u * 5.5, 1.3 + u * 1.6, 0.45, Vector3.UP + fd * 0.35, fd * 3.0, 0.0, 5, 0.95)
		if pj.live(c):
			var mo = pj._mouth_pos(c)
			KatonLib.tongue(pj, mo + fd * 0.3, 3.5, 1.4, 0.3, fd, fd * 10.0, 0.0, 4, 1.0)
			if i % 4 == 0:
				KatonLib.embers(pj, mo + fd * 6.0, 8, 2.0, 0.0, {"dir": fd + Vector3.UP * 0.4, "spread": 40.0, "vmin": 3.0, "vmax": 8.0, "life": 0.8})
	, func():
		if is_instance_valid(light):
			var tw = light.create_tween()
			tw.tween_property(light, "light_energy", 0.0, 0.5)
			tw.tween_callback(light.queue_free))
	pj.every(1.5, 0.25, func(_i, _k):
		if pj.live(c):
			Combat.hit_zone(c, c.global_position, c.face_dir(), 20.0, 30.0, 4.5, pj.inf(c, "katon_goen_no_jutsu", 0.4, {"knock": 3.0, "kind": "light", "element": "katon", "burn": 1.5})), Callable())
	for k in 4:
		pj.after(0.4 + k * 0.15, func():
			if pj.live(c):
				KatonLib.scorch(pj, c.global_position + c.face_dir() * (5.0 + k * 3.5), 2.2 + k * 0.4, 4.0))
	Sfx.play("fire", c.global_position, 0.7)


# ================================================================== 4) Haijingakure no Jutsu
## Küle Saklanma (ref): ağızdan savrulan kül topak topak kabaran gri bir buluta döner; topakların arasındaki yarıklarda
## turuncu kor damarları parlar, yarıklardan kısa alev dilleri yalar, kor zerreleri sürüklenir. Kullanıcı bulutta kaybolur.
static func katon_haijingakure_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var cp = c.global_position
	var fd = pj.fwd(c, t)
	var mo = pj._mouth_pos(c)
	for k in 4:
		KatonLib.ash_puff(pj, mo + fd * 0.4, 0.25, 0.9, 0.7, (fd * 3.5 + Vector3(randf_range(-1, 1), randf_range(0.0, 0.8), randf_range(-1, 1))), 0.1, 0.3)
	for k in 16:
		var a = k * TAU / 16.0 + randf() * 0.3
		var rr = randf_range(0.8, 4.4)
		var p = cp + Vector3(cos(a) * rr, randf_range(0.4, 2.8), sin(a) * rr)
		var vel = Vector3(cos(a), randf_range(0.1, 0.3), sin(a)) * randf_range(0.3, 0.8)
		KatonLib.ash_puff(pj, p, 0.5, randf_range(1.5, 2.5), randf_range(2.8, 3.6), vel, randf_range(0.1, 0.35), 0.45)
	# yerde ışınsal kor yarıkları (ref: topakların arasındaki turuncu damarlar)
	var seams: Array = []
	for s in 7:
		var a = s * TAU / 7.0 + randf_range(-0.2, 0.2)
		var pts = PackedVector3Array()
		var dirv = Vector3(cos(a), 0, sin(a))
		var sd = dirv.cross(Vector3.UP)
		for i in 10:
			var u = i / 9.0
			var q = cp + dirv * (0.6 + u * 4.8) + sd * sin(u * 7.0 + s) * 0.35
			pts.append(KatonLib.floor_at(q) + Vector3.UP * 0.07)
		seams.append(pts)
		var wid = PackedFloat32Array()
		for i in 10:
			wid.append(1.0 - absf(i / 9.0 - 0.4) * 0.9)
		KatonLib.ribbon(pj, pts, 0.18, 3.2, 0.0, {"hint": Vector3.UP, "twin": false, "travel": false, "flow": 1.2, "tiles": 3.0, "rag": 0.4, "widths": wid, "heat": 0.95, "delay": 0.15})
	pj.every(3.0, 0.15, func(i, _k):
		var pts: PackedVector3Array = seams[i % seams.size()]
		var at = pts[randi_range(1, pts.size() - 2)]
		KatonLib.tongue(pj, at, randf_range(0.4, 0.8), 0.45, 0.4, Vector3(randf_range(-0.2, 0.2), 1, randf_range(-0.2, 0.2)), Vector3.ZERO, 0.0, 3, 1.0)
		if i % 4 == 0:
			KatonLib.embers(pj, cp + Vector3(randf_range(-3, 3), randf_range(0.5, 2.5), randf_range(-3, 3)), 6, 1.2, 0.0, {"vmin": 0.4, "vmax": 1.4, "life": 1.6, "spread": 120.0}))
	# oynanış (c_katon_haijingakure_no_jutsu)
	for e in pj.enemies_near(c, c.global_position, 22.0):
		if e.has_method("lose_target"):
			e.lose_target(4.0)
	if c.get("model"):
		c.model.visible = false
		pj.after(4.0, func():
			if is_instance_valid(c):
				c.model.visible = true)
	if c is Player:
		Buffs.add("henge_ash", 4.0, {"speed": 1.2})
	Sfx.play("poof", c.global_position, 0.6)


# ================================================================== 5) Hōsenka Tsumabeni
## Ateş topu: küçük alev çekirdeği + çevresine açılmış beş taç yaprağı dili (ref: her shuriken bir alev çiçeğinin içinde)
static func _flower_ball(s: float) -> Node3D:
	var root = Node3D.new()
	root.add_child(KatonLib.mass_mi(0.32 * s, 0.0, 1.0, 2.0))
	for k in 5:
		var a = k * TAU / 5.0
		var ax = Vector3(cos(a) * 0.9, sin(a) * 0.9, 0.55)
		var pt = KatonLib.tongue_mi(0.9 * s, 0.55 * s, ax, 0.0, 3, 0.2, 0.95)
		root.add_child(pt)
	return root


static func _petal_pop(pj: PathJutsu, p: Vector3) -> void:
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.4
		var ax = Vector3(cos(a), 0.7, sin(a)).normalized()
		KatonLib.tongue(pj, p, 1.1, 0.6, 0.35, ax, ax * 2.5, 0.0, 3, 1.0)
	KatonLib.glow(pj, p, 1.6, FIRE_L, 0.35)
	KatonLib.embers(pj, p, 10, 0.3, 0.0, {"vmin": 2.0, "vmax": 5.0, "life": 0.6})


## Hōsenka Tsumabeni (ref, Itachi): ağızdan yelpaze gibi alev çiçekleri yağar; her çiçeğin ortasında bir shuriken, shuriken
## alevden sıyrılıp ardında alev kuyruğuyla hedefe kıvrılır. Hazırlıkta ağızda dönen küçük taç yaprakları.
static func katon_hosenka_tsumabeni(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_eyes(pj, c, 1.5)
	var m0 = pj._mouth_pos(c)
	for k in 5:
		var a = k * TAU / 5.0
		var pt = KatonLib.tongue_mi(0.35, 0.22, Vector3(cos(a), 0.4, sin(a)), 0.0, 2, 0.0, 1.0)
		KatonLib.put(pj, pt, m0 + Vector3(cos(a), 0, sin(a)) * 0.5)
		var tw = pt.create_tween()
		tw.tween_method(func(x: float) -> void:
			if is_instance_valid(pt):
				var aa = a + x * 4.0
				pt.global_position = m0 + Vector3(cos(aa), 0.1, sin(aa)) * 0.5 * (1.0 - x), 0.0, 1.0, 0.3)
		tw.tween_callback(pt.queue_free)
	var tt = pj.tg(c, t, 34.0)
	pj.busy(c, 0.9)
	pj.anim(c, "cast_out", 1.3)
	Sfx.play("fire", c.global_position, 1.1)
	var aim = pj._aim_tt(c, t, tt, Jutsu._mouth(c))
	for k in 6:
		pj.after(k * 0.07, func():
			if not is_instance_valid(c):
				return
			var d = (aim.rotated(Vector3.UP, (k - 2.5) * 0.17) + Vector3.UP * randf_range(0.0, 0.12)).normalized()
			var mo = Jutsu._mouth(c) + d * 0.6
			var fpr = pj.shot(c, mo, d, 20.0, _flower_ball(1.0), pj.inf(c, "katon_hosenka_tsumabeni", 0.18, {"knock": 3.0, "element": "katon", "burn": 2.0}), null, false, 1.6, func(p, _h):
				_petal_pop(pj, p)
				_blast_marks(p, 0.5))
			fpr.gravity = 4.0
			fpr.radius = 0.6
			KatonLib.tongue(pj, mo, 1.2, 0.6, 0.22, d, d * 6.0, 0.0, 3, 1.0)
			# içindeki shuriken: alevle birlikte gider, sonra sıyrılıp alev kuyruğuyla hedefe kıvrılır
			var b = MB.new()
			for n in 4:
				var bs = Basis(Vector3.UP, n * PI * 0.5)
				b.add_xf("cone", Transform3D(bs * Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(0.1, 0.3, 0.02)), bs * Vector3(0.15, 0, 0)), Color(0.32, 0.32, 0.38), 4)
			b.add("cyl", Vector3.ZERO, Vector3(0.07, 0.03, 0.07), Color(0.2, 0.2, 0.24), Vector3.ZERO, 8)
			var sh = Node3D.new()
			var smi = MeshInstance3D.new()
			smi.mesh = b.build(Props.toon())
			sh.add_child(smi)
			var wrap = KatonLib.tongue_mi(0.45, 0.4, Vector3.UP, 0.0, 3, 0.0, 0.9)
			sh.add_child(wrap)
			var spr = pj.shot(c, mo, d, 20.0, sh, pj.inf(c, "katon_hosenka_tsumabeni", 0.3, {"knock": 4.0, "element": "katon", "burn": 4.0}), null, false, 2.0, func(p, _h):
				KatonLib.embers(pj, p, 8, 0.2, 0.0, {"vmin": 2.0, "vmax": 4.0, "life": 0.6})
				KatonLib.scorch(pj, p, 0.5, 3.0))
			spr.spin = Vector3(0, 35, 0)
			spr.radius = 0.35
			pj.after(0.28, func():
				if is_instance_valid(spr) and not spr.dead:
					spr.homing = tt
					spr.homing_turn = 7.0
					spr.vel = spr.vel.normalized() * 38.0
					var cnt = {"n": 0}
					spr.on_tick = func(pr, _dt):
						cnt["n"] += 1
						if cnt["n"] % 2 == 0 and is_instance_valid(pr):
							KatonLib.tongue(pj, pr.global_position, 0.9, 0.35, 0.18, -pr.vel.normalized(), Vector3.ZERO, 0.0, 2, 1.0)))


# ================================================================== 6) Uchiha Kaenjin
## Uchiha Alev Düzeni (ref: kızıl alev sütunu): parmak uçlarında kızıl alev, avuç yere: alev halka hâlinde dışa koşar, zemin
## çatlar; kullanıcının çevresinde kızıl, yoğun iki katlı alev perdesi yükselir (dış halka uzun diller, iç halka sık perde).
## Bariyer: dışarıdan gelen mermiler duvarda kızıl parlamayla yanar, değen düşman tutuşup dışarı savrulur.
static func uchiha_kaenjin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_eyes(pj, c, 2.0)
	var r = 4.6
	var H = 6.5
	var DUR = 7.0
	var PAL = KatonLib.PAL_CRIMSON
	pj.busy(c, 1.0)
	pj.anim(c, "cast", 1.4)
	pj.every(0.45, 0.05, func(_i, _k):
		if is_instance_valid(c):
			KatonLib.tongue(pj, Jutsu._hand(c), 0.35, 0.18, 0.22, Vector3.UP, Vector3.UP * 0.5, PAL, 3, 1.0))
	Sfx.play("fire", c.global_position, 1.4, 0.5)
	pj.after(0.45, func():
		if not is_instance_valid(c):
			return
		pj.anim(c, "crouch", 2.0)
		var center = pj.gp(c.global_position)
		GroundFX.add(center, "cracked", r * 0.8 * 0.6, 5.0)
		KatonLib.scorch(pj, center, r * 1.15, DUR + 2.0, 0.0, PAL, 0.4)
		# avuçtan dışa koşan alev halkası
		for k in 12:
			var a = k * TAU / 12.0
			var ov = Vector3(cos(a), 0, sin(a))
			KatonLib.tongue(pj, center + ov * 0.5, 1.4, 0.9, 0.35, ov * 0.6 + Vector3.UP, ov * (r / 0.35), PAL, 4, 1.05)
		pj.shake(0.45)
		Sfx.play("fire", center, 0.6)
		var root = Node3D.new()
		KatonLib.put(pj, root, center)
		var tongues: Array = []
		var rings = [[44, r, 1.0, 6], [26, r - 0.45, 0.8, 9]]
		for ring in rings:
			var N: int = ring[0]
			for k in N:
				var a = TAU * k / N + randf_range(-0.05, 0.05)
				var rr = float(ring[1]) + randf_range(-0.25, 0.2)
				var h = H * float(ring[2]) * (randf_range(0.6, 1.05) if k % 4 != 0 else randf_range(1.0, 1.25))
				var w = randf_range(1.0, 1.5)
				var tg = KatonLib.tongue_mi(1.0, 1.0, Vector3(randf_range(-0.08, 0.08), 1.0, randf_range(-0.08, 0.08)), PAL, int(ring[3]), randf_range(-0.15, 0.15), 1.0)
				root.add_child(tg)
				tg.position = Vector3(cos(a) * rr, -0.1, sin(a) * rr)
				var bs = tg.basis.orthonormalized()
				tg.basis = bs * Basis.from_scale(Vector3(w, 0.05, w))
				tongues.append(tg)
				var tw = tg.create_tween()
				tw.tween_interval(absf(sin(a * 0.5)) * 0.12)
				tw.tween_property(tg, "scale", Vector3(w, h, w), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_callback(func():
					if not is_instance_valid(tg):
						return
					var per = randf_range(0.22, 0.42)
					var fl = tg.create_tween().set_loops()
					fl.tween_property(tg, "scale", Vector3(w * 0.9, h * 1.1, w * 0.9), per).set_trans(Tween.TRANS_SINE)
					fl.tween_property(tg, "scale", Vector3(w * 1.05, h * 0.85, w * 1.05), per).set_trans(Tween.TRANS_SINE))
		var light = OmniLight3D.new()
		light.light_color = CRIM_L
		light.light_energy = 4.0
		light.omni_range = r * 3.0
		root.add_child(light)
		light.position.y = 3.0
		pj.every(DUR, 0.1, func(i, _k):
			# kamera perdenin içinde kalmasın: kameraya yakın diller 4-8 m arasında söner, kamera tarafındaki yay
			# alçak ve ince kalır (kullanıcı perdenin içinden görünür)
			var cam = pj.get_viewport().get_camera_3d()
			var cdir = Vector3.ZERO
			if cam:
				cdir = cam.global_position - center
				cdir.y = 0.0
				cdir = cdir.normalized() if cdir.length() > 0.1 else Vector3.ZERO
				for tg in tongues:
					if not is_instance_valid(tg):
						continue
					var off = tg.global_position - center
					off.y = 0.0
					var f = clampf(off.normalized().dot(cdir), 0.0, 1.0) if off.length() > 0.01 else 0.0
					var dist = cam.global_position.distance_to(tg.global_position + Vector3.UP * 1.5)
					tg.set_instance_shader_parameter("fade", smoothstep(4.0, 8.0, dist) * (1.0 - 0.5 * f))
					tg.set_instance_shader_parameter("heat", 1.0 - 0.55 * f)
			# duvarın tepesinden kopup yükselen kızıl diller (kamera tarafında değil)
			if i % 2 == 0:
				var a = randf() * TAU
				if Vector3(cos(a), 0, sin(a)).dot(cdir) > 0.2:
					a += PI
				KatonLib.tongue(pj, center + Vector3(cos(a) * r, H * randf_range(0.8, 1.0), sin(a) * r), randf_range(1.2, 2.0), 0.9, 0.5, Vector3.UP, Vector3.UP * 3.0, PAL, 3, 0.95)
			if i % 5 == 0:
				KatonLib.embers(pj, center + Vector3.UP * H * 0.6, 8, r, PAL, {"vmin": 1.0, "vmax": 3.0, "life": 1.2, "spread": 40.0})
			# dışarıdan gelen mermiler duvarda yanar
			for n in pj.get_tree().current_scene.get_children():
				if n is Projectile and not n.dead and n.shooter != c and Combat.hostile(c, n.shooter):
					var v = n.global_position - center
					var hd = Vector2(v.x, v.z).length()
					if hd > r - 1.2 and hd < r + 1.2 and v.y < H + 1.0:
						KatonLib.glow(pj, n.global_position, 1.6, CRIM_L, 0.3)
						KatonLib.embers(pj, n.global_position, 12, 0.3, PAL, {"vmin": 2.0, "vmax": 5.0, "life": 0.6})
						n.block()
			# duvara değen ya da içeri giren düşman tutuşur ve dışarı savrulur
			for e in pj.enemies_near(c, center, r + 1.3):
				var v = e.global_position - center
				v.y = 0.0
				if v.length() < 0.1:
					v = Vector3.FORWARD
				pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "uchiha_kaenjin", 0.25, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "element": "katon", "burn": 3.0, "dir": v.normalized()}))
				e.global_position = pj.gp(center + v.normalized() * (r + 2.2))
				var vp = center + v.normalized() * r + Vector3.UP * 1.2
				for q in 3:
					KatonLib.tongue(pj, vp, 1.4, 0.8, 0.35, v.normalized() + Vector3.UP * randf_range(0.2, 0.8), v.normalized() * 4.0, PAL, 3, 1.05)
		, func():
			var tw = root.create_tween().set_parallel()
			for tg in tongues:
				if is_instance_valid(tg):
					tw.tween_method(KatonLib.pf(tg, "heat"), 1.0, 0.0, 0.6)
			tw.tween_property(light, "light_energy", 0.0, 0.6)
			pj.get_tree().create_timer(0.7).timeout.connect(func(): if is_instance_valid(root): root.queue_free())))


# ================================================================== 7) Uchiha Ryū: Higasa no Mai (MsArts)
## Uchiha Tarzı Hale Dansı (ref, Storm): tantō alev alır (bıçak boyunca yalayan diller); tek hızlı savuruşla öne doğru
## açılan güneş halesi yayı salınır: kalın alev yayı + dışında ince parlak korona çizgisi; yayın kenarından alev
## dilleri kopar, ardında kor kalır.
static func uchiha_ryu_higasa_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 24.0)
	var d = MsArts._turn(c, MsArts._aim_fn(c, tg, 12.0).call())
	pj.busy(c, 0.85)
	MsArts._anim(c, "slash_a", 1.5)
	var hand = c.global_position + Vector3.UP * 1.2 + d * 0.5
	var sd = d.cross(Vector3.UP).normalized()
	for k in 5:
		KatonLib.tongue(pj, hand + sd * (k - 2) * 0.12 + Vector3.UP * k * 0.05, 0.55, 0.3, 0.3, Vector3.UP + d * 0.3, Vector3.UP * 0.6, 0.0, 3, 1.0)
	KatonLib.glow(pj, hand, 0.9, FIRE_L, 0.3)
	Sfx.play("fire", c.global_position, 1.3)
	MsArts._later(0.22, func():
		if not MsArts._alive(c):
			return
		var from = c.global_position + Vector3.UP * 1.1 + d * 1.0
		var arcs: Array = []
		for spec in [[MsArts._arc_mesh(1.0, 2.6, 0.5, 28), 1.0, 0.45, 1.0], [MsArts._arc_mesh(1.0, 3.2, 0.08, 32), 1.14, 0.2, 1.1]]:
			var mi = KatonLib.gi(spec[0], KatonLib.ribbon_mat())
			mi.set_instance_shader_parameter("seed", randf() * 10.0)
			mi.set_instance_shader_parameter("pal", 0.0)
			mi.set_instance_shader_parameter("heat", float(spec[3]))
			mi.set_instance_shader_parameter("head", 1.0)
			mi.set_instance_shader_parameter("tail", 0.0)
			mi.set_instance_shader_parameter("flow", 4.0)
			mi.set_instance_shader_parameter("tiles", 6.0)
			mi.set_instance_shader_parameter("rag", float(spec[2]))
			mi.set_instance_shader_parameter("fade", 1.0)
			MsArts._scene().add_child(mi)
			arcs.append([mi, float(spec[1]), float(spec[3])])
		var bas = MsArts._zbasis(d) * Basis(Vector3(0, 0, 1), 0.18)
		var inf = MsArts._inf(c, "uchiha_ryu_higasa_no_mai", 1.0, {"knock": 7.0, "kind": "heavy", "element": "katon", "burn": 4.0, "dir": d})
		var hit: Array = []
		var cnt = {"n": 0}
		var tw = MsArts._tw()
		tw.tween_method(func(x: float):
			var R = 1.6 + x * 5.5   # hale ilerledikçe açılır
			var pos = from + d * x * 20.0
			for ar in arcs:
				var mi: MeshInstance3D = ar[0]
				if not is_instance_valid(mi):
					continue
				var RR = R * float(ar[1])
				mi.global_transform = Transform3D(bas * Basis.from_scale(Vector3(RR, 1.0, RR * 0.55)), pos)
				mi.set_instance_shader_parameter("heat", float(ar[2]) * (1.0 - maxf(0.0, x - 0.65) * 2.6))
				mi.set_instance_shader_parameter("tail", maxf(0.0, x - 0.75) * 3.0)
			cnt["n"] += 1
			if cnt["n"] % 2 == 0:
				var a = randf_range(-1.2, 1.2)
				var ep = pos + bas * Vector3(sin(a) * R, 0.0, cos(a) * R * 0.55)
				KatonLib.tongue(pj, ep, 0.9, 0.5, 0.3, Vector3.UP + d * 0.2, -d * 2.0, 0.0, 3, 1.0)
			if MsArts._alive(c):
				for f in Combat.hit_sphere(c, pos + d * R * 0.5, R * 0.75, inf, hit):
					hit.append(f)
					var cp = MsArts._chest(f)
					KatonLib.embers(pj, cp, 14, 0.4, 0.0, {"vmin": 3.0, "vmax": 7.0, "life": 0.6})
					KatonLib.tongue(pj, cp, 1.3, 0.7, 0.35, d + Vector3.UP, d * 2.0, 0.0, 4, 1.05), 0.0, 1.0, 0.55)
		tw.tween_callback(func():
			for ar in arcs:
				if is_instance_valid(ar[0]):
					ar[0].queue_free())
		Sfx.play("whoosh", from, 0.8))


# ================================================================== 8) Gamayu Endan
## Kuchiyose mühür çemberi: mürekkep halkası yerde açılır, söner
static func _seal_circle(pj: PathJutsu, p: Vector3, r: float, life: float) -> void:
	_ring(pj, KatonLib.floor_at(p) + Vector3.UP * 0.06, r, life, 0.0, Vector3.UP)
	Sfx.play("poof", p, 0.8)


## Kurbağa Yağı Alev Mermisi (anime: Jiraiya + Gamabunta): arkada mühür çemberinden dev kurbağa kabarır, ağzından kalın
## amber yağ seli yere akar; kullanıcı alev üfler — tutuşma cephesi yağ boyunca koşar, sel alev tufanına döner, yer yanan
## yağ gölüyle kaplanır.
static func gamayu_endan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.8)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var toad_at = pj.gp(c.global_position - d * 3.5 + side * 1.2)
	_seal_circle(pj, toad_at, 3.0, 1.2)
	pj.shake(0.3)   # eski çağırma iniş sarsıntısı
	var toad = MeshInstance3D.new()
	toad.mesh = pj._elder_toad(false).build(Props.toon())
	KatonLib.put(pj, toad, toad_at)
	toad.rotation.y = atan2(d.x, d.z)
	toad.scale = Vector3.ONE * 0.3
	var ttw = toad.create_tween()
	ttw.tween_property(toad, "scale", Vector3.ONE * 6.5, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var mouth = toad_at + Vector3.UP * 2.0 + d * 2.0
	var dd = (d - Vector3.UP * 0.08).normalized()
	# yağ: ağızdan inen ince koyu amber döküntü + yerde alçak, yuvarlak kenarlı, parlak akış (dikey duvar yok)
	var pour_pts = PackedVector3Array()
	var pour_w = PackedFloat32Array()
	var land = KatonLib.floor_at(mouth + dd * 4.0)
	for i in 10:
		var u = i / 9.0
		var q = mouth.lerp(land, u) + dd * sin(u * PI) * 0.6
		q.y = maxf(lerpf(mouth.y, land.y, u * u), land.y) + 0.05
		pour_pts.append(q)
		pour_w.append(0.6 + 0.4 * u)
	var pts = PackedVector3Array()
	var wid = PackedFloat32Array()
	for i in 24:
		var u = i / 23.0
		var q = land + d * 22.0 * u + side * sin(u * 5.0) * 0.6
		pts.append(KatonLib.floor_at(q) + Vector3.UP * 0.06)
		wid.append(0.45 + 0.55 * minf(1.0, u * 3.0))
	var oils: Array = []
	for spec in [[pour_pts, 0.28, true, pour_w, 6.0], [pts, 1.1, false, wid, 22.0]]:
		var om = KatonLib.gi(KatonLib.strip(spec[0], float(spec[1]), Vector3.UP, bool(spec[2]), spec[3]), _mat("oil", OIL_SHADER))
		om.set_instance_shader_parameter("seed", randf() * 10.0)
		om.set_instance_shader_parameter("head", 0.0)
		om.set_instance_shader_parameter("ignite", 0.0)
		om.set_instance_shader_parameter("fade", 1.0)
		om.set_instance_shader_parameter("tiles", float(spec[4]))
		KatonLib.put(pj, om, Vector3.ZERO)
		oils.append(om)
	var oil: MeshInstance3D = oils[1]
	pj.after(0.35, func():
		var otw = oil.create_tween() if is_instance_valid(oil) else null
		if otw:
			if is_instance_valid(oils[0]):
				otw.tween_method(KatonLib.pf(oils[0], "head"), 0.0, 1.0, 0.12)
			otw.tween_method(KatonLib.pf(oil, "head"), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Sfx.play("water", toad_at, 0.5))
	pj.after(0.75, func():
		if not pj.live(c):
			return
		pj.anim(c, "push", 1.3)
		# kullanıcının üflediği alev yağa değer
		var mo = pj._mouth_pos(c)
		for k in 6:
			KatonLib.tongue(pj, mo + d * 0.3, 2.4, 1.0, 0.3, d, d * 9.0, 0.0, 4, 1.0)
		for om in oils:
			if is_instance_valid(om):
				var itw = om.create_tween()
				itw.tween_method(KatonLib.pf(om, "ignite"), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				itw.tween_interval(0.9)
				itw.tween_method(KatonLib.pf(om, "fade"), 1.0, 0.0, 0.6)
				itw.tween_callback(om.queue_free)
		# yağ tufanı: tutuşma cephesinin arkasında yağ boyunca yükselen büyük diller ve yuvarlanan topaklar
		pj.every(1.1, 0.05, func(i, k):
			var lim = minf(1.0, k * 2.2 + 0.1)
			for q in 3:
				var u = randf() * lim
				var idx = clampi(int(u * 23.0), 0, 23)
				var bp: Vector3 = pts[idx] + side * randf_range(-1.0, 1.0) * 1.1
				KatonLib.tongue(pj, KatonLib.floor_at(bp), randf_range(1.8, 3.6) * (0.6 + u * 0.6), randf_range(1.2, 2.0), 0.5, Vector3.UP + d * 0.4, d * 3.0, 0.0, 6, 0.95)
			if i % 3 == 0:
				var u2 = randf() * lim
				KatonLib.mass(pj, pts[clampi(int(u2 * 23.0), 0, 23)] + Vector3.UP * 0.7, 0.5, 1.3, 0.6, d * 6.0 + Vector3.UP * 1.5, 0.0, 1.0, 1.6, 0.75))
		KatonLib.light(pj, c.global_position + d * 14.0 + Vector3.UP * 4.0, FIRE_L, 7.0, 36.0, 1.6)
		Combat.hit_zone(c, c.global_position, d, 30.0, 34.0, 5.0, pj.inf(c, "gamayu_endan", 2.4, {"knock": 14.0, "kind": "heavy", "element": "katon", "burn": 5.0}))
		for k in 3:
			GroundFX.add(c.global_position + d * (8.0 + k * 7.0), "burning", 5.5, 6.0, c)
			KatonLib.burn_patch(pj, c.global_position + d * (8.0 + k * 7.0), 3.5, 6.0, 0.0, 0.14, 1.6)
		pj.shake(1.2)
		Sfx.play("fire", c.global_position, 0.5))
	pj.after(2.2, func():
		if is_instance_valid(toad):
			_seal_circle(pj, toad.global_position, 2.4, 0.8)
			var xt = toad.create_tween()
			xt.tween_property(toad, "scale", Vector3.ONE * 0.2, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			xt.tween_callback(toad.queue_free))


# ================================================================== 9) Bashōsen: Hi no Maki
## Bashōsen (kuşanılan silah modeli) elde açılır; sırttaki gizlenir, chakra emilir (bashosen_fan'ın oynanışı birebir).
## Savuruşta yelpaze tüylerinden kor saçılır.
static func _fan(pj: PathJutsu, c: Node3D) -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = CharacterModel.weapon_mesh("bashosen")
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	pj.after(0.2, func():
		if is_instance_valid(root):
			var fp = root.global_position + Vector3.UP * 0.8
			KatonLib.embers(pj, fp, 20, 0.8, 0.0, {"vmin": 2.0, "vmax": 5.0, "life": 0.5, "spread": 90.0})
			KatonLib.glow(pj, fp, 1.4, FIRE_L, 0.3))
	var md = c.get("model")
	var hidden = []
	if md and "weapons" in md:
		for w in md.weapons:
			if String(w.get("id", "")) == "bashosen" and is_instance_valid(w["node"]) and w["node"].visible:
				w["node"].visible = false
				hidden.append(w["node"])
	pj.after(1.9, func():
		for n in hidden:
			if is_instance_valid(n):
				n.visible = true)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(root)
		root.rotation_degrees = Vector3(-90, 0, 0)
	else:
		pj.scene_add(root, pj.hand_pos(c, true))
	root.scale = Vector3.ONE * 0.05
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(ba):
			ba.queue_free()
		elif is_instance_valid(root):
			root.queue_free())
	if c is Player:
		c.chakra = maxf(0.0, c.chakra - c.max_chakra * 0.15)
		Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Bashōsen chakranı emiyor!", Color(0.95, 0.85, 0.5))
	pj.busy(c, 1.1)
	pj.anim(c, "slash_a", 1.0)
	return root


## Bashōsen Ateş Sargısı (ref: yeri kaplayan geniş sarı-turuncu alev ırmağı, içinde damar damar akış): yelpaze savrulur,
## 22 m genişliğinde üç katlı kıvrılan alev sargısı (alt kat kalın, üst katlar geriye yatık) ileri yuvarlanır; sırtında
## kemer gibi yükselen diller, geçtiği yer kavrulur.
static func bashosen_hi_no_maki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	_fan(pj, c)
	pj.after(0.35, func():
		var wall = Node3D.new()
		var start = pj.gp(c.global_position + d * 4.0)
		pj.scene_add(wall, start)
		wall.global_basis = Basis.looking_at(d, Vector3.UP)
		var parts: Array = []
		var rows = [[1.2, 2.4, 0.0, 1.0], [3.1, 2.0, 0.7, 0.95], [4.8, 1.4, 1.5, 0.9]]
		for ri in rows.size():
			var row = rows[ri]
			var pts = PackedVector3Array()
			var wid = PackedFloat32Array()
			for i in 23:
				var x = (i / 22.0 - 0.5) * 22.0
				var arch = 1.0 - pow(x / 11.0, 2.0) * 0.45
				pts.append(Vector3(x, float(row[0]) * arch + sin(x * 0.55 + ri * 1.7) * 0.5, float(row[2]) + cos(x * 0.4 + ri) * 0.4))
				wid.append(0.55 + 0.45 * arch)
			var rb = KatonLib.ribbon_mi(pts, float(row[1]), 0.0, {"twin": true, "flow": 3.0 + ri, "tiles": 9.0, "rag": 0.5, "widths": wid, "heat": float(row[3])})
			wall.add_child(rb)
			parts.append(rb)
		for n in 11:
			var hh = 8.0 - absf(n - 5) * 0.55
			var tg = KatonLib.tongue_mi(1.0, 1.0, Vector3(0, 1.0, 0.3), 0.0, 6, 0.0, 0.95)
			tg.position = Vector3((n - 5) * 2.1, 0.0, 0.6 + absf(n - 5) * 0.35)
			var bs = tg.basis.orthonormalized()
			tg.basis = bs * Basis.from_scale(Vector3(3.0, 0.1, 3.0))
			wall.add_child(tg)
			parts.append(tg)
			var ct = tg.create_tween()
			ct.tween_interval(absf(n - 5) * 0.03)
			ct.tween_property(tg, "scale", Vector3(3.0, hh, 3.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		wall.scale = Vector3(1.0, 0.1, 1.0)
		wall.create_tween().tween_property(wall, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var light = OmniLight3D.new()
		light.light_color = FIRE_L
		light.light_energy = 5.0
		light.omni_range = 30.0
		light.position = Vector3(0, 4.0, 0)
		wall.add_child(light)
		Sfx.play("fire", start, 0.6)
		pj.shake(0.7)
		var hits = {}
		pj.every(2.4, 1.0 / 30.0, func(i, k):
			if not is_instance_valid(wall):
				return
			var p = pj.gp(start + d * (k * 36.0))
			wall.global_position = p
			if i % 3 == 0:
				KatonLib.embers(pj, p + side * randf_range(-10, 10) + Vector3.UP * 2.0, 10, 1.5, 0.0, {"dir": Vector3.UP + d * 0.3, "vmin": 2.0, "vmax": 6.0, "life": 0.9})
				if i % 9 == 0:
					KatonLib.scorch(pj, p - d * 1.5 + side * randf_range(-9, 9), randf_range(2.0, 3.2), 6.0)
			for e in pj.enemies_near(c, p + Vector3.UP, 11.5):
				var rel = e.global_position - p
				if absf(rel.dot(d)) < 2.5 and not hits.has(e):
					hits[e] = true
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.6, pj.inf(c, "bashosen_hi_no_maki", 1.6, {"element": "katon", "burn": 6.0, "knock": 12.0, "launch": 5.0, "kind": "heavy"}))
		, func():
			if is_instance_valid(wall):
				var tw = wall.create_tween().set_parallel()
				for pp in parts:
					if is_instance_valid(pp):
						tw.tween_method(KatonLib.pf(pp, "heat"), 1.0, 0.0, 0.4)
				tw.tween_property(light, "light_energy", 0.0, 0.4)
				tw.chain().tween_callback(wall.queue_free)))


# ================================================================== 10) Gudōdama
## Arayış Topu (ref: zifiri siyah, mat, sıvı gibi biçim değiştiren küreler; değdiği şey pul pul silinir): sırtta dokuz küre
## sıvı gibi damlayarak belirir; her biri sırayla fırlar, üçte biri yolda şakujō mızrağına uzar. Ardında koyu damlacık izi;
## çarptığı yerde madde içe çöküp gri-beyaz pullara dağılır (ateş değil, şimşek değil).
static func gudodama(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 30.0)
	var balls = []
	for k in 9:
		var bb = _tsb_ball(0.01)
		bb.set_instance_shader_parameter("wob", 0.25)
		c.add_child(bb)
		var a = PI + (k - 4) * 0.3
		bb.position = Vector3(sin(a) * 1.0, 1.5 + cos(k * 0.7) * 0.25, cos(a) * 0.8 - 0.4)
		var gtw = bb.create_tween()
		gtw.tween_interval(k * 0.025)
		gtw.tween_property(bb, "scale", Vector3.ONE * 0.225, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		gtw.tween_method(KatonLib.pf(bb, "wob"), 0.25, 0.04, 0.2)
		balls.append(bb)
	for k in 9:
		pj.after(0.4 + k * 0.09, func():
			if not pj.live(c):
				return
			var bb = balls[k]
			if not is_instance_valid(bb):
				return
			var from = bb.global_position
			bb.queue_free()
			var proj: Node3D
			if k % 3 == 1:
				proj = _tsb_staff()
				proj.scale = Vector3(1.0, 1.0, 0.2)
			else:
				proj = Node3D.new()
				proj.add_child(_tsb_ball(0.5))
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 36.0, proj, pj.inf(c, "gudodama", 0.55, {"knock": 6.0, "kind": "heavy"}), null, false, 1.2, func(p, _h):
				_tsb_erase(pj, p, 1.3))
			if k % 3 == 1:
				proj.create_tween().tween_property(proj, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # top yolda mızrağa uzar
			var cnt = {"n": 0}
			pr.on_tick = func(prj, _dt):
				cnt["n"] += 1
				if cnt["n"] % 3 != 0 or not is_instance_valid(prj):
					return
				var drop = _tsb_ball(0.12)
				KatonLib.put(pj, drop, prj.global_position + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)))
				var dtw = drop.create_tween()
				dtw.tween_property(drop, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				dtw.tween_callback(drop.queue_free))
	Sfx.play("chakra", c.global_position, 0.5)


# ================================================================== 11) Gudōkasa
## Arayış Şemsiyesi mesh'i: tepe +Y, düzensiz dalgalı kenarlı basık kubbe (çift yüz)
static func _umbrella_mesh() -> ArrayMesh:
	if _cache.has("umb"):
		return _cache["umb"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NA = 40
	var NR = 6
	var ring = func(ri: int, ai: int) -> Vector3:
		var u = float(ri) / NR
		var a = TAU * ai / NA
		var rr = 2.4 * u * (1.0 + (0.08 * sin(a * 7.0) + 0.05 * sin(a * 3.0 + 1.3) + 0.04 * sin(a * 11.0)) * u * u)
		var y = 0.45 * (1.0 - u * u) - 0.12 * u * u * absf(sin(a * 5.0))
		return Vector3(cos(a) * rr, y, sin(a) * rr)
	for ri in NR:
		for ai in NA:
			var p00: Vector3 = ring.call(ri, ai)
			var p01: Vector3 = ring.call(ri, ai + 1)
			var p10: Vector3 = ring.call(ri + 1, ai)
			var p11: Vector3 = ring.call(ri + 1, ai + 1)
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				var nrm = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				for v in tri:
					st.set_normal(nrm)
					st.add_vertex(v)
	var m = st.commit()
	_cache["umb"] = m
	return m


## Arayış Şemsiyesi (ref: avuçtan uzanan sapın ucunda dalgalı kenarlı siyah kalkan): küre önde sıvı gibi yayılıp şemsiyeye
## açılır; gelen mermi yüzeyine değince içe çöker, pul pul silinir ve yüzey dalgalanır. Kapanırken şemsiye küreye
## büzülür, önüne koyu silme dalgası ve pullar savrulur.
static func gudokasa(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var um = Node3D.new()
	c.add_child(um)
	um.position = Vector3(0, 1.4, 1.4)
	um.rotation.x = PI * 0.5
	um.scale = Vector3.ONE * 0.05
	var disc = _tsb_mi(_umbrella_mesh(), 0.25)
	um.add_child(disc)
	var shaft = _tsb_mi(_sphere_mesh(), 0.01)
	shaft.scale = Vector3(0.05, 0.8, 0.05)
	shaft.position = Vector3(0, -0.6, 0)
	um.add_child(shaft)
	var tw = um.create_tween()
	tw.tween_property(um, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_method(KatonLib.pf(disc, "wob"), 0.25, 0.05, 0.35)
	pj.every(5.0, 0.06, func(_i, _k):
		if not (pj.live(c) and is_instance_valid(um)):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and p.global_position.distance_to(um.global_position) < 2.8:
				_tsb_erase(pj, p.global_position, 0.7)
				var rw = disc.create_tween()
				rw.tween_method(KatonLib.pf(disc, "wob"), 0.3, 0.05, 0.3)
				p.queue_free(), func():
		if is_instance_valid(um):
			var at = um.global_position
			var fd = c.face_dir()
			var blob = _tsb_ball(1.2)
			KatonLib.put(pj, blob, at)
			var bt = blob.create_tween()
			bt.tween_property(blob, "scale", Vector3.ONE * 0.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			bt.tween_callback(blob.queue_free)
			for q in 3:
				_ring(pj, at + fd * (1.0 + q * 1.8), 1.6 + q * 1.2, 0.35 + q * 0.08, 1.0, fd)
			_erase_flakes(pj, at + fd * 1.0, 22, 6.0, fd * 1.2)
			if pj.live(c):
				Combat.hit_zone(c, c.global_position, c.face_dir(), 7.0, 80.0, 3.0, pj.inf(c, "gudokasa", 1.0, {"knock": 14.0, "kind": "heavy"}))
			um.queue_free())
	if c is Player:
		Buffs.add("gudokasa", 5.0, {"armor": 0.7, "_name": "Arayış Şemsiyesi", "_desc": "önden gelen her şey engellenir"})


# ================================================================== 12) Senpō: Gokashin Ensen
## Bilge Sanatı Beş Ateş Tanrısı Yelpazesi (ref: kullanıcının arkasında göğe yükselen sarı-turuncu alev duvarı): ayak
## çevresinden doğa enerjisi alev zerreleri olarak ağza tırmanır; ağızdan beş kalın alev kolu yelpaze gibi açılır, her
## kolun ucunda gökyüzüne uzanan bir alev tanrısı sütunu yükselir; yerde beş kavruk iz.
static func senpo_gokashin_ensen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var d = pj.fwd(c, t)
	var from = pj._mouth_pos(c)
	var feet = KatonLib.floor_at(c.global_position)
	for k in 10:
		var a = k * TAU / 10.0
		var p0 = feet + Vector3(cos(a), 0.1, sin(a)) * 2.2
		var mt = KatonLib.tongue_mi(0.6, 0.35, Vector3.UP, 0.0, 3, 0.0, 1.0)
		KatonLib.put(pj, mt, p0)
		var tw = mt.create_tween()
		tw.tween_method(func(x: float) -> void:
			if is_instance_valid(mt):
				var q = p0.lerp(from, x * x) + Vector3.UP * sin(x * PI) * 0.6
				mt.global_position = q
				mt.scale = Vector3.ONE * (1.0 - x * 0.6), 0.0, 1.0, 0.35)
		tw.tween_callback(mt.queue_free)
	KatonLib.glow(pj, from, 1.6, FIRE_L, 0.45)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var mo = pj._mouth_pos(c)
		for k in 5:
			var dk = d.rotated(Vector3.UP, deg_to_rad((k - 2) * 16.0))
			var pts = PackedVector3Array()
			var wid = PackedFloat32Array()
			for i in 14:
				var u = i / 13.0
				var q = mo + dk * (0.6 + u * 17.0) + Vector3.UP * sin(u * PI) * 1.6
				q.y = maxf(q.y, Game.jutsu_floor(q.x, q.z) + 0.6)
				pts.append(q)
				wid.append(0.3 + 0.7 * u)
			KatonLib.ribbon(pj, pts, 1.6, 1.3, 0.0, {"flow": 4.0, "tiles": 6.0, "rag": 0.5, "widths": wid, "heat": 1.0})
			pj.after(0.18 + k * 0.04, func():
				var base = KatonLib.floor_at(c.global_position + dk * 16.0) if is_instance_valid(c) else KatonLib.floor_at(mo + dk * 16.0)
				for q in 5:
					var off = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
					KatonLib.tongue(pj, base + off, randf_range(6.0, 9.0), randf_range(2.0, 3.0), 1.0, Vector3(off.x * 0.1, 1.0, off.z * 0.1), Vector3.UP * 1.5, 0.0, 6, 0.95)
				KatonLib.mass(pj, base + Vector3.UP * 2.0, 1.0, 2.4, 0.8, Vector3.UP * 5.0, 0.0, 1.0, 1.4, 1.3)
				KatonLib.embers(pj, base + Vector3.UP * 3.0, 14, 1.5, 0.0, {"vmin": 3.0, "vmax": 8.0, "life": 1.2, "spread": 30.0}))
		for k in 6:
			pj.after(0.15 + k * 0.08, func():
				if is_instance_valid(c):
					var q = pj.gp(c.global_position + d.rotated(Vector3.UP, deg_to_rad(randf_range(-35, 35))) * randf_range(6, 18))
					KatonLib.scorch(pj, q, randf_range(1.8, 2.6), 4.5))
		KatonLib.light(pj, c.global_position + d * 10.0 + Vector3.UP * 5.0, FIRE_L, 7.0, 34.0, 1.3)
		Combat.hit_zone(c, c.global_position, d, 18.0, 75.0, 4.0, pj.inf(c, "senpo_gokashin_ensen", 2.4, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "element": "katon", "burn": 5.0}))
		pj.shake(0.9))
	Sfx.play("fire", c.global_position, 0.5)


# ================================================================== 13) Enton: Honoikazuchi (MsArts)
## Enton: Honoikazuchi (ref: gövdeden her yöne saplanan kırık kenarlı kara dikenler): Amaterasu kara alevi bedeni sarar
## (ağır kara diller), sonra on iki kara alev dikenine dönüşüp çevreyi deler; diken uçlarından kara diller yalar.
static func enton_honoikazuchi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.1)
	MsArts._anim(c, "cast", 1.1)
	Amaterasu.focus_flash(c)
	var wrap = Node3D.new()
	c.add_child(wrap)
	wrap.position = Vector3(0, 0.1, 0)
	for k in 7:
		var a = k * TAU / 7.0
		var tg = _black_tongue_mi(randf_range(1.3, 2.3), randf_range(0.9, 1.3), Vector3(cos(a) * 0.2, 1.0, sin(a) * 0.2), 1.0)
		tg.position = Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45)
		wrap.add_child(tg)
	wrap.scale = Vector3(1.0, 0.1, 1.0)
	wrap.create_tween().tween_property(wrap, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	MsArts._later(1.0, func():
		if is_instance_valid(wrap):
			wrap.queue_free())
	Sfx.play("fire", c.global_position, 0.6)
	MsArts._later(0.38, func():
		if not MsArts._alive(c):
			return
		MsArts._anim(c, "cast_out", 1.5)
		var ctr = c.global_position + Vector3.UP * 0.9
		var R = 5.2
		# Amaterasu dikenleri: düz koni değil — gövdeden dışa fırlayan uzun, dalgalı kara alev dilleri (kanca uçlu)
		for k in 12:
			var a = k * TAU / 12.0 + randf_range(-0.12, 0.12)
			var dir = (Vector3(sin(a), 0, cos(a)) + Vector3.UP * randf_range(0.05, 0.45)).normalized()
			var len = R * randf_range(0.8, 1.1)
			var sp = _black_tongue_mi(1.0, 1.0, dir, 1.15)
			MsArts._scene().add_child(sp)
			var y = dir
			var x = y.cross(Vector3.UP).normalized()
			var z = x.cross(y)
			var place = func(l: float, w: float):
				if is_instance_valid(sp):
					sp.global_transform = Transform3D(Basis(x * w, y * l, z * w), ctr + dir * 0.3)
			place.call(0.05, 1.1)
			var tw = sp.create_tween()
			tw.tween_method(func(v: float): place.call(v * len, 1.1), 0.05, 1.0, 0.09).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func():
				if k % 2 == 0:
					_black_tongue(pj, ctr + dir * (0.3 + len * 0.85), 1.0, 0.7, 0.5, dir + Vector3.UP * 0.4, dir * 0.8))
			tw.tween_interval(0.45)
			tw.tween_method(KatonLib.pf(sp, "heat"), 1.15, 0.0, 0.25)
			tw.tween_callback(sp.queue_free)
		var small = MsArts._inf(c, "enton_honoikazuchi", 0.08, {"knock": 0.0, "launch": 0.0, "kind": "light", "hitstop": 0.0, "element": "katon"})
		for f in Combat.hit_sphere(c, ctr, R, MsArts._inf(c, "enton_honoikazuchi", 1.0, {"knock": 10.0, "launch": 2.0, "kind": "heavy", "element": "katon", "bleed": 3.0, "hitstop": 0.09, "pierce_guard": true})):
			if MsArts._alive(f):
				Amaterasu.ignite(c, f, f.global_position, 6.0, small)
		MsArts._shake(0.7)
		Sfx.play("hit_blade", ctr, 0.7))


# ================================================================== 14) Amaterasu: Zanka (MsArts)
## Amaterasu Kalıntı Ateşi (ref: Susanoo'nun elinde kara alev küresi; etrafa saçılan kara alev tuzakları): gerçek Susanoo
## eli yukarı kalkar, avucunda kara alev küresi kabarır; küreden kopan küçük kara alev küreleri yay çizip yere iner,
## yerinde salınarak bekler, yaklaşana kara alev patlamasıyla Amaterasu bulaştırır.
static func amaterasu_zanka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "amaterasu_zanka")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 30.0 + H)
	var aim = MsArts._aim_fn(c, tg, 12.0 + H * 0.4)
	var d = MsArts._turn(c, aim.call())
	pj.busy(c, 1.2)
	MsArts._anim(c, "cast", 1.0)
	sn.hide_weapons(1.6)
	var ad = (d + Vector3.UP * 0.25).normalized()
	sn.pose({"arms": Susanoo.arm(true, ad, ad, Vector3.UP), "spine": 6.0}, 1.4, true)
	Amaterasu.focus_flash(c)
	var big = _black_orb(S * 0.3)
	MsArts._scene().add_child(big)
	big.scale = Vector3.ONE * 0.1
	big.create_tween().tween_property(big, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	sn.follow_fx(big, 1.3, func(): return sn.hand(true) + Vector3.UP * S * 0.35)
	MsArts._later(1.3, func():
		if is_instance_valid(big):
			_black_burst(pj, big.global_position, S * 0.4)
			big.queue_free())
	Sfx.play("fire", c.global_position, 0.5)
	var boom = MsArts._inf(c, "amaterasu_zanka", 0.3, {"knock": 6.0, "launch": 2.0, "kind": "heavy", "element": "katon", "hitstop": 0.05})
	var small = MsArts._inf(c, "amaterasu_zanka", 0.06, {"knock": 0.0, "launch": 0.0, "kind": "light", "hitstop": 0.0, "element": "katon"})
	for k in 5:
		MsArts._later(0.45 + k * 0.14, func():
			if not (MsArts._alive(c) and is_instance_valid(big)):
				return
			var ctr: Vector3 = aim.call()
			var a = k * TAU / 4.0 + 0.4
			var spot = Jutsu._ground(ctr + (Vector3(sin(a), 0, cos(a)) * 3.2 if k > 0 else Vector3.ZERO)) + Vector3.UP * 0.9
			var from = big.global_position
			var orb = _black_orb(0.5)
			MsArts._scene().add_child(orb)
			orb.global_position = from
			var stt = {"live": true, "t": 0.0}
			var pop = func():
				if not stt["live"] or not is_instance_valid(orb):
					return
				stt["live"] = false
				var p = orb.global_position
				orb.queue_free()
				_black_burst(pj, p, 1.2)
				Sfx.play("fire", p, 1.2, 0.7)
				if MsArts._alive(c):
					for f in Combat.hit_sphere(c, p, 3.0, boom):
						if MsArts._alive(f):
							Amaterasu.ignite(c, f, f.global_position, 6.0, small)
			var tw = orb.create_tween()
			tw.tween_method(func(x: float):
				if is_instance_valid(orb):
					orb.global_position = from.lerp(spot, x) + Vector3.UP * sin(x * PI) * 3.0, 0.0, 1.0, 0.45)
			# tuzak: 8 sn bekler, yaklaşana patlar
			tw.tween_method(func(x: float):
				if not stt["live"] or not is_instance_valid(orb):
					return
				orb.global_position = spot + Vector3.UP * sin(x * 40.0) * 0.12
				if x * 8.0 - stt["t"] >= 0.15 and is_instance_valid(c):
					stt["t"] = x * 8.0
					if not MsArts._foes(c, spot, 1.7).is_empty():
						pop.call(), 0.0, 1.0, 8.0)
			tw.tween_callback(func():
				if stt["live"] and is_instance_valid(orb):
					stt["live"] = false
					orb.queue_free()))


# ================================================================== 15) Susanoo: Kaien (MsArts)
## Susanoo: Kaien (Storm 4): GERÇEK Susanoo'nun matkap mızrağı (Susanoo malzemesi) — üzerine iki sarmal alev şeridi
## sarılır, gövdesinden geriye alev dilleri akar; mızrak dönerek saplanır, her dönüşte ucunda dışa açılan alev halkası.
static func susanoo_kaien(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_kaien")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 16.0 + H * 1.5)
	var aim = MsArts._aim_fn(c, tg, 6.0 + H * 0.8)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 1.7)
	MsArts._anim(c, "cast", 0.9)
	sn.hide_weapons(2.0)
	sn.pose({"arms": Susanoo.arm(true, -d * 0.5 + Vector3.UP * 0.3 + side * 0.5, d * 0.4 + Vector3.UP * 0.2), "spine": -14.0}, 0.5, true)   # geri çekiş
	# matkap: Susanoo'nun kendi mızrağı ve malzemesi
	var mb = MB.new()
	Susanoo._drill(mb, Vector3.ZERO, Vector3(0, 0, -1), 2.6, 0.34, Color.WHITE)
	var dr = sn.chakra_mesh(mb, 1.5)
	MsArts._scene().add_child(dr)
	dr.scale = Vector3.ONE * S * 0.55
	# alev sargısı: iki sarmal şerit (matkapla birlikte döner) + geriye akan diller
	for s in 2:
		var pts = PackedVector3Array()
		var wid = PackedFloat32Array()
		for i in 22:
			var u = i / 21.0
			var a = s * PI + u * TAU * 2.2
			var rr = lerpf(0.5, 0.08, u)
			pts.append(Vector3(cos(a) * rr, sin(a) * rr, -u * 2.6))
			wid.append(1.0 - u * 0.7)
		var rb = KatonLib.ribbon_mi(pts, 0.16, 0.0, {"flow": 5.0, "tiles": 5.0, "rag": 0.45, "widths": wid, "heat": 1.0})
		dr.add_child(rb)
	for i in 5:
		var a = i * TAU / 5.0
		var tgm = KatonLib.tongue_mi(1.1, 0.5, Vector3(cos(a) * 0.4, sin(a) * 0.4, 1.0), 0.0, 4, 0.0, 0.95)
		tgm.position = Vector3(cos(a) * 0.3, sin(a) * 0.3, -0.4 - i * 0.35)
		dr.add_child(tgm)
	var L = 2.6 * S * 0.55   # matkabın boyu
	var st = {"spin": 0.0, "reach": 0.0}
	sn.follow_fx(dr, 1.75, func(): return sn.hand(true) + d * st["reach"] * S, func(): return aim.call() - dr.global_position)
	var spin_tw = MsArts._tw()
	spin_tw.tween_method(func(x: float):
		if is_instance_valid(dr):
			dr.rotate_object_local(Vector3(0, 0, 1), 0.55), 0.0, 1.0, 1.7)
	Sfx.play("fire", c.global_position, 0.8)
	MsArts._later(0.5, func():
		if not is_instance_valid(sn) or not MsArts._alive(c):
			return
		sn.pose({"arms": Susanoo.arm(true, d * 0.95 + Vector3.UP * 0.05, d), "spine": 16.0}, 1.1, true)   # saplama
		var rt = MsArts._tw()
		rt.tween_method(func(x: float): st["reach"] = x, 0.0, 0.5, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		MsArts._shake(0.5))
	var inf = MsArts._inf(c, "susanoo_kaien", 0.14, {"knock": 0.6, "kind": "heavy", "element": "katon", "burn": 3.0, "hitstop": 0.02})
	for k in 7:
		MsArts._later(0.62 + k * 0.12, func():
			if not is_instance_valid(dr) or not MsArts._alive(c):
				return
			var ax: Vector3 = (aim.call() - dr.global_position).normalized()
			var tip: Vector3 = dr.global_position + ax * L
			var got: Array = []   # gövde boyunca: matkabın değdiği herkes (aynı vuruşta bir kez)
			for u in [0.35, 0.65, 0.95]:
				for f in Combat.hit_sphere(c, dr.global_position + ax * L * u, 1.2 + S * 0.3, inf.merged({"dir": d, "knock": 12.0 if k == 6 else 0.6}, true), got):
					got.append(f)
			KatonLib.embers(pj, tip, 12, 0.4, 0.0, {"dir": -ax, "spread": 70.0, "vmin": 4.0, "vmax": 9.0, "life": 0.5})
			if k % 2 == 0:
				var bs = KatonLib.axis_basis(ax)
				for q in 8:
					var a = q * TAU / 8.0 + k
					var ov = (bs.x * cos(a) + bs.z * sin(a)).normalized()
					KatonLib.tongue(pj, tip, (1.2 + S * 0.4), 0.7 + S * 0.2, 0.3, ov - ax * 0.3, ov * (3.0 + S), 0.0, 3, 1.0)
				KatonLib.glow(pj, tip, 2.0 + S, FIRE_L, 0.25)
				Sfx.play("fire", tip, 1.4, 0.5))
	MsArts._later(1.75, func():
		if is_instance_valid(dr):
			dr.queue_free())
