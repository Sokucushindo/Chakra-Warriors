class_name FutonFXD
extends RefCounted
## Fūton grubu D: on beş rüzgâr tekniğinin görselleri. Malzeme / yapı taşları FutonLib'den (akım çizgisi, hava perdesi,
## kesici hilal, basınç bükülmesi, zemin izi, savrulan parçalar); bu gruba özgü dört gölgelendirici burada:
##   sarmal kollu Rasengan çekirdeği, vakum kabarcığı (Shinkū: içinde dönen duman, titrek kenar),
##   dev vakum girdabı (Shinkū Taigyoku: ince iç içe yay vuruşları, arkasını büken disk), Rasenshuriken kanat diski.
## Katı koni / kubbe / kabuk yok; geniş perdeler kameraya 6-9 m içinde söner, ekranı kaplamaz.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır
## taşındı; eski rüzgâr hamlelerinin saç/kumaş savurması (Dangle.gust) açıkça korunur.

const WHITE := Color(1.0, 1.0, 1.0, 0.85)
const AIR := Color(0.88, 0.96, 1.0, 0.8)
const PALE := Color(0.82, 0.92, 1.0, 0.7)
const CYAN := Color(0.6, 0.85, 1.0, 0.9)
const JADE := Color(0.5, 1.0, 0.62, 0.9)
const JADE_L := Color(0.8, 1.0, 0.84, 0.8)
const MINT := Color(0.78, 1.0, 0.86, 0.7)
const SMOKE := Color(0.6, 0.66, 0.74, 0.75)
const SAND := Color(0.9, 0.78, 0.55, 0.85)
const SAND_L := Color(0.98, 0.9, 0.72, 0.75)
const SAND_D := Color(0.72, 0.58, 0.38, 0.85)
const INK := Color(0.08, 0.08, 0.1, 1.0)
const STEEL := Color(0.62, 0.64, 0.7)

static var _cache := {}


# ================================================================== bu gruba özgü gölgelendiriciler
const BILL_VERTEX := """
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
"""

## Rasengan çekirdeği: koyu mavi gövdede dönen üç sarmal beyaz kol, parlak merkez, ince lacivert kontur
const RASEN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float near = 0.8;
varying vec3 lp;

FNOISE

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 n = normalize(lp);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float lon = atan(n.z, n.x);
	float arm = fract((lon + n.y * 2.6) / 6.2831853 * 3.0 - TIME * 3.2);
	float k = wn(vec2(lon * 2.0 + TIME * 6.0, n.y * 4.0));
	vec3 col = vec3(0.3, 0.58, 1.0);
	float a = 0.72;
	if (arm < 0.16) {
		col = vec3(0.93, 0.97, 1.0);
		a = 0.95;
	} else if (arm < 0.28) {
		col = vec3(0.6, 0.82, 1.0);
		a = 0.85;
	}
	if (k > 0.72) {
		col = mix(col, vec3(1.0), 0.4);
	}
	if (fr < 0.3) {
		col = mix(col, vec3(1.0), 0.5);
		a = 0.95;
	}
	if (fr > 0.88) {
		col = vec3(0.1, 0.24, 0.68);
		a = 0.9;
	}
	ALBEDO = col;
	ALPHA = a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Vakum kabarcığı (ref: Shinkū / Shinkūdama — arkasını büken saydam, kalp gibi titreşen hava kesesi; içinde dönen
## gri-mavi duman, yumuşak beyaz kenar, en dışta ince koyu kontur)
const BLOB_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float near = 2.0;

FNOISE

BILL_VERTEX

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = 0.78 + 0.1 * sin(ang * 2.0 + TIME * 9.0 + seed) + 0.06 * sin(ang * 3.0 - TIME * 7.0 + seed * 2.0);
	if (r > edge) {
		discard;
	}
	float k = r / edge;
	vec2 off = p * (1.0 - k) * 0.09;
	vec3 bg = textureLod(scr, SCREEN_UV + off, 0.0).rgb;
	float sm = wf(vec2(ang * 1.2 + TIME * 3.0 + seed, k * 3.0 - TIME * 2.0));
	vec3 col = mix(bg, vec3(0.78, 0.86, 0.95), 0.18);
	if (sm > 0.56) {
		col = mix(col, vec3(0.42, 0.48, 0.58), 0.35);
	} else if (sm < 0.3) {
		col = mix(col, vec3(1.0), 0.18);
	}
	float a = 0.9;
	if (k > 0.85) {
		col = mix(vec3(0.85, 0.93, 1.0), vec3(1.0), 0.4);
		a = 0.8;
	}
	if (k > 0.96) {
		col = vec3(0.3, 0.38, 0.5);
		a = 0.6;
	}
	ALBEDO = col;
	ALPHA = a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Dev vakum girdabı (ref: Shinkū Taigyoku — gökyüzünü büken dev daire, yüzeyi iç içe ince fırça yaylarıyla dolu)
const VORTEX_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float near = 6.0;

FNOISE

BILL_VERTEX

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float twist = ang * 0.5 + r * 3.0 - TIME * 4.0;
	float ring = r * 18.0 + (wn(vec2(ang * 2.0 + seed, r * 3.0)) - 0.5) * 2.0;
	float f = fract(ring);
	float stroke = 1.0 - smoothstep(0.0, 0.1, abs(f - 0.5));
	float gate = step(0.5, wn(vec2(floor(ring) * 1.7 + seed, twist * 2.0)));
	float rim = smoothstep(1.0, 0.82, r);
	vec2 off = vec2(-p.y, p.x) * (1.0 - r) * 0.06 + p * (1.0 - r) * 0.03;
	vec3 bg = textureLod(scr, SCREEN_UV - off, 0.0).rgb;
	vec3 col = mix(bg, vec3(0.86, 0.93, 1.0), 0.1 + 0.1 * (1.0 - r));
	float a = 0.8 * rim;
	if (stroke * gate > 0.5) {
		col = mix(col, vec3(1.0), 0.5);
		a = max(a, 0.75 * rim);
	}
	if (r < 0.12) {
		col = mix(col, vec3(0.5, 0.58, 0.68), 0.4);
	}
	ALBEDO = col;
	ALPHA = a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Rasenshuriken kanat diski (PlaneMesh, XZ): dört kıvrık beyaz kanat, ön kenarı parlak, arkasında soluk hız sürtmesi, ince dış halka
const SHURI_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float near = 1.2;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || r < 0.16) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float s = fract((ang + r * 1.6) / 6.2831853 * 4.0);
	float w = 0.34 * (1.0 - r) + 0.04;
	vec3 col = vec3(0.9, 0.97, 1.0);
	float a = 0.0;
	if (s < w) {
		float e = s / w;
		a = 0.88;
		if (e < 0.18) {
			col = vec3(1.0);
			a = 1.0;
		} else if (e > 0.7) {
			col = vec3(0.62, 0.84, 1.0);
			a = 0.55;
		}
	} else if (s < w + 0.12) {
		a = 0.28 * (1.0 - (s - w) / 0.12);
		col = vec3(0.75, 0.9, 1.0);
	}
	if (abs(r - 0.93) < 0.02) {
		a = max(a, 0.35);
		col = vec3(0.85, 0.95, 1.0);
	}
	if (a < 0.02) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""


static func _smat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("FNOISE", FutonLib.FNOISE).replace("BILL_VERTEX", BILL_VERTEX)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _sph() -> SphereMesh:
	if not _cache.has("sph"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 28
		s.rings = 14
		_cache["sph"] = s
	return _cache["sph"]


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2.ONE
		_cache["quad"] = q
	return _cache["quad"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2.ONE
		_cache["plane"] = p
	return _cache["plane"]


## Köşe renkli, ışıksız malzeme (mürekkep izi, göz parıltısı)
static func _flat_mat(key: String, alpha: bool) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


static func _spin(n: Node3D, prop: String, period: float, loops: int, sgn := 1.0) -> void:
	var tw = Game.safe_loops(n.create_tween(), maxi(1, loops))
	tw.tween_property(n, prop, TAU * sgn, period).as_relative()


## fd'ye bakan disk tabanı (QuadMesh XY düzlemi fd'ye dik)
static func _face_basis(fd: Vector3) -> Basis:
	var x = FutonLib.side_of(fd)
	var y = FutonLib.up_of(fd)
	return Basis(x, y, x.cross(y))


## Kısa ışık parlaması
static func _flash(pj: PathJutsu, p: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = Color(col.r, col.g, col.b)
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	FutonLib.put(pj, l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


## Yakın dövüş vuruşu (eski ortak vuruşun oynanış kısmı: hasar + ekran sarsıntısı); görsel her teknikte kendisinin
static func _hit_shake(pj: PathJutsu, c: Node3D, pos: Vector3, r: float, info: Dictionary) -> Array:
	var hs = pj.hit(c, pos, r, info)
	if not hs.is_empty():
		var s = clampf(0.8 + float(info.get("knock", 4.0)) * 0.04 + absf(float(info.get("launch", 0.0))) * 0.03, 0.8, 1.8)
		var heavy = String(info.get("kind", "")) == "heavy"
		pj.shake(0.2 + 0.3 * (s if heavy else s * 0.7))
	return hs


## Rasengan: sarmal kollu çekirdek + çevresinde hızla dönen üç eğik yörünge çizgisi. parent null ise pos dünya konumu.
static func _rasengan(pj: PathJutsu, parent: Node, r: float, life: float, pos := Vector3.ZERO) -> Node3D:
	var root = Node3D.new()
	FutonLib.put(pj, root, pos, parent)
	var core = FutonLib.gi(_sph(), _smat("rasen", RASEN_SHADER))
	root.add_child(core)
	core.scale = Vector3.ONE * r * 0.2
	var tw = core.create_tween()
	tw.tween_property(core, "scale", Vector3.ONE * r, minf(0.18, life * 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in 3:
		var orb = Node3D.new()
		root.add_child(orb)
		orb.rotation = Vector3(k * 1.05, k * 0.7, 0.4 * k)
		var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, r * 1.3, r * 1.3, 0.0, 0.0, randf() * TAU, 0.7, 14)
		FutonLib.fixed(pj, pts, r * 0.07, "line", CYAN, {"parent": orb, "flow": 12.0, "near": 0.8})
		_spin(orb, "rotation:y", 0.12 + k * 0.03, int(maxf(life, 2.0) / 0.12) + 2)
	if life > 0.0:
		FutonLib.kill(pj, life, root)
	return root


## Madara'nın gunbai'si (ref: tek büyük yuvarlak kürek, sapa doğru hafif boğumlu boyun; siyah lake dış kenar, açık ten
## rengi ince iç kenar, koyu kızıl-kahve lake yüz, iki yüzde üç tomoe; kalın koyu sap, krem sargılı kabza, dipte topuz ve
## zincir halkası). Yerel eksenler oyunun tutuş düzeniyle aynı: sap +Z boyunca (kabza başlangıçta), yüz normali +X.
## Kürek boyu ≈ 1,4 m, toplam ≈ 2,2 m.
static func _gunbai_mesh() -> ArrayMesh:
	if _cache.has("gunbai"):
		return _cache["gunbai"]
	var b = MB.new()
	var lacquer = Color(0.07, 0.05, 0.05)
	var rimc = Color(0.8, 0.68, 0.48)
	var facec = Color(0.42, 0.11, 0.08)
	var wood = Color(0.22, 0.15, 0.11)
	var wrap = Color(0.86, 0.81, 0.68)
	var metal = Color(0.55, 0.56, 0.6)
	var cz = 1.2
	var cr = 0.62
	var z0 = 0.44
	var z1 = cz + cr
	# yarı genişlik: büyük daire ∪ boyun (boyun daireye bağlanırken hafif içe kıvrılır: tek kürek, iki lob değil)
	var wfn = func(z: float, inset: float) -> float:
		var rc = cr - inset
		var wc = sqrt(maxf(0.0, rc * rc - (z - cz) * (z - cz)))
		var wn = 0.0
		if z <= 0.86:
			var k = clampf((z - z0) / (0.86 - z0), 0.0, 1.0)
			wn = lerpf(0.075, 0.33, k * k * (3.0 - 2.0 * k)) - inset * 0.6
		return maxf(wc, wn)
	var outline = func(inset: float) -> PackedVector2Array:
		var za = z0 + inset * 0.6
		var zb = z1 - inset
		var right = []
		for i in 57:
			var u = 0.5 - 0.5 * cos(PI * i / 56.0)
			var z = lerpf(za, zb, u)
			right.append(Vector2(maxf(wfn.call(z, inset), 0.004), z))
		var o = PackedVector2Array()
		for q in right:
			o.append(q)
		for i in range(right.size() - 2, 0, -1):
			o.append(Vector2(-right[i].x, right[i].y))
		return o
	b.add_slab(outline.call(0.0), 0.05, lacquer)
	b.add_slab(outline.call(0.03), 0.058, rimc)
	b.add_slab(outline.call(0.06), 0.066, facec)
	# yüzün ortasında ince lake kaburga (sapın devamı) ve iki yüzde üç tomoe
	b.add("box", Vector3(0, 0, (z0 + cz) * 0.5), Vector3(0.072, 0.035, cz - z0), lacquer)
	for sx in [-1.0, 1.0]:
		for k in 3:
			var a = TAU * k / 3.0 + 0.5
			var hc = Vector3(sx * 0.036, cos(a) * 0.26, cz + 0.06 + sin(a) * 0.26)
			b.add("sphere", hc, Vector3(0.012, 0.085, 0.085), lacquer, Vector3.ZERO, 10)
			for q in 3:   # kuyruk: başın çevresinde incelerek kıvrılan virgül
				var ta = a + 0.55 + q * 0.32
				var tr = 0.26 + 0.05 + q * 0.012
				var tp = Vector3(sx * 0.036, cos(ta) * tr - cos(a) * 0.05, cz + 0.06 + sin(ta) * tr - sin(a) * 0.05)
				var ts = 0.06 - q * 0.016
				b.add("sphere", tp, Vector3(0.012, ts, ts), lacquer, Vector3.ZERO, 8)
	# sap: kalın koyu ahşap, krem sargılı kabza, metal bilezik, dipte topuz ve zincir halkası
	var p0 = -0.36
	b.add("cyl", Vector3(0, 0, (p0 + z0 + 0.1) * 0.5), Vector3(0.075, z0 + 0.1 - p0, 0.075), wood, Vector3(90, 0, 0), 12)
	for k in 7:
		var zz = -0.26 + k * 0.075
		b.add("cyl", Vector3(0, 0, zz), Vector3(0.085, 0.045, 0.085), wrap if k % 2 == 0 else wrap.darkened(0.25), Vector3(90, 30 * k, 0), 10)
	b.add("cyl", Vector3(0, 0, z0 - 0.02), Vector3(0.095, 0.05, 0.095), metal, Vector3(90, 0, 0), 12)
	b.add("sphere", Vector3(0, 0, p0), Vector3(0.1, 0.1, 0.1), metal.darkened(0.2), Vector3.ZERO, 12)
	var links = [[Vector3(0, 0, p0 - 0.1), 0.055, 0.0], [Vector3(0, 0, p0 - 0.22), 0.045, 90.0], [Vector3(0, 0, p0 - 0.32), 0.04, 0.0]]
	for L in links:
		var lc: Vector3 = L[0]
		var lr = float(L[1])
		var rot = float(L[2])
		for i in 12:
			var a = TAU * i / 12.0
			var off = Vector3(0, cos(a) * lr, sin(a) * lr * 1.3) if rot == 0.0 else Vector3(cos(a) * lr, 0, sin(a) * lr * 1.3)
			b.add("sphere", lc + off, Vector3(0.022, 0.022, 0.022), metal, Vector3.ZERO, 6)
	var m = b.build(Props.toon())
	_cache["gunbai"] = m
	return m


## Ters kabuk kontur (cel çizgisi)
static func _outline_mat() -> StandardMaterial3D:
	if _cache.has("outline"):
		return _cache["outline"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.03, 0.02, 0.02)
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = 0.012
	_cache["outline"] = m
	return m


## Elde tutulan gunbai'ye kendi modelini giydirir (tutuş / poz oyunun kendi sisteminde kalır); ölçek 1: boyutlar metre
static func _dress_gunbai(node: Node3D) -> void:
	if node == null or not is_instance_valid(node) or not (node is MeshInstance3D):
		return
	var mi := node as MeshInstance3D
	mi.mesh = _gunbai_mesh()
	mi.material_override = null
	mi.basis = mi.basis.orthonormalized()
	var ol = MeshInstance3D.new()
	ol.mesh = mi.mesh
	ol.material_override = _outline_mat()
	ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(ol)


## Uchiha kızıl gözleri: göz hizasında atan kırmızı parıltı
static func _eyes(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hb = pj.bone_attach(c, "Head")
	if hb == null:
		return
	var b = MB.new()
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.032, 0.065, 0.095), Vector3(0.022, 0.016, 0.008), Color(1.0, 0.1, 0.08))
	var mi = FutonLib.gi(b.build(_flat_mat("eye", false)), null)
	hb.add_child(mi)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.35, 0.08)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.2)
	pj.free_after(dur, hb)


# ================================================================== 1. Fūton: Kiryū Ranbu (Hortum Dansı)
## Kaynak yok, tasarım: üç küçük hortum — dört ince sarmal akım çizgisi + soluk sarmal perde, huni gibi yukarı açılır,
## kendi ekseninde döner ve sağa sola salınarak (dans) düşmana kayar; tabanında dönen toz ve yaprak, yer yer ışınsal toz izi.
static func futon_kiryu_ranbu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	for k in 3:
		var pos = {"p": pj.gp(c.global_position + Vector3(cos(k * TAU / 3.0), 0, sin(k * TAU / 3.0)) * 3.0)}
		var tw_node = _kiryu_twister(pj, pos["p"], k)
		pj.every(4.0, 1.0 / 15.0, func(i, _kk):
			var target = null
			var best = 20.0
			for e in pj.enemies_near(c, pos["p"], 20.0):
				if pj.live(e) and e.global_position.distance_to(pos["p"]) < best:
					best = e.global_position.distance_to(pos["p"])
					target = e
			if target:
				var v = target.global_position - pos["p"]
				v.y = 0
				pos["p"] = pj.gp(pos["p"] + v.normalized() * minf(v.length(), 0.6))
			if is_instance_valid(tw_node):
				tw_node.create_tween().tween_property(tw_node, "global_position", pos["p"], 1.0 / 15.0)
			if i % 6 == k * 2:
				_kiryu_gust(pj, pos["p"], i % 12 == 0)
			if i % 5 == 0:
				pj.hit(c, pos["p"] + Vector3.UP, 1.8, pj.inf(c, "futon_kiryu_ranbu", 0.18, {"knock": 3.0, "launch": 5.0, "kind": "light", "element": "fuuton"}))
		, func():
			_kiryu_end(pj, tw_node))
	Sfx.play("wind", c.global_position, 1.0)


static func _kiryu_twister(pj: PathJutsu, p: Vector3, k: int) -> Node3D:
	var root = Node3D.new()
	FutonLib.put(pj, root, p)
	var sp = Node3D.new()
	root.add_child(sp)
	for q in 4:
		var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 0.22, 1.15, 0.05, 3.2, TAU * q / 4.0, 1.8, 26)
		FutonLib.fixed(pj, pts, 0.035 + 0.012 * (q % 2), "line", AIR if q % 2 == 0 else PALE, {"parent": sp, "flow": 7.0, "near": 3.0})
	var shp = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 0.3, 1.0, 0.1, 2.8, 0.5, 1.2, 20)
	FutonLib.fixed(pj, shp, 0.28, "sheet", PALE, {"parent": sp, "opacity": 0.25, "lines": 3.0, "near": 4.0})
	_spin(sp, "rotation:y", 0.32 + k * 0.04, 15)
	# dans: gövde iki yana salınır
	var sw = sp.create_tween().set_loops(9)
	sw.tween_property(sp, "rotation:x", 0.16, 0.24 + k * 0.03).set_trans(Tween.TRANS_SINE)
	sw.tween_property(sp, "rotation:x", -0.16, 0.24 + k * 0.03).set_trans(Tween.TRANS_SINE)
	root.scale = Vector3(0.2, 0.1, 0.2)
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FutonLib.kill(pj, 5.0, root)
	return root


static func _kiryu_gust(pj: PathJutsu, p: Vector3, big: bool) -> void:
	FutonLib.bits(pj, p + Vector3.UP * 0.2, 6, "puff", {"cols": FutonLib.dust_cols(p, 0.7), "size": 0.5, "radius": 0.6, "dir": Vector3.UP, "spread": 60.0,
		"vmin": 1.0, "vmax": 3.0, "tang": 10.0, "g": Vector3(0, 0.6, 0), "life": 0.9, "damp": 1.5})
	if FutonLib.has_leaves(p):
		FutonLib.bits(pj, p + Vector3.UP * 0.4, 5, "leaf", {"cols": FutonLib.leaf_cols(p), "size": 0.14, "radius": 0.8, "dir": Vector3.UP, "spread": 30.0,
			"vmin": 3.0, "vmax": 6.0, "tang": 14.0, "g": Vector3(0, -2.0, 0), "life": 1.4})
	else:
		FutonLib.bits(pj, p + Vector3.UP * 0.4, 6, "grit", {"cols": FutonLib.dust_cols(p, 1.0), "size": 0.1, "radius": 0.6, "dir": Vector3.UP, "spread": 30.0,
			"vmin": 3.0, "vmax": 6.0, "tang": 14.0, "life": 1.0})
	if big:
		FutonLib.scour(pj, p, Vector3.FORWARD, 2.6, 2.6, 1.4, 1)


static func _kiryu_end(pj: PathJutsu, n: Node3D) -> void:
	if n == null or not is_instance_valid(n):
		return
	var p = n.global_position
	var tw = n.create_tween()
	tw.tween_property(n, "scale", Vector3(0.05, 1.4, 0.05), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)
	# dağılan hortumdan geriye süzülen yapraklar / toz
	if FutonLib.has_leaves(p):
		FutonLib.bits(pj, p + Vector3.UP * 2.0, 6, "leaf", {"cols": FutonLib.leaf_cols(p), "size": 0.14, "radius": 0.8, "vmin": 0.5, "vmax": 1.5, "g": Vector3(0, -1.2, 0), "life": 2.0, "damp": 2.0})
	FutonLib.bits(pj, p + Vector3.UP * 0.3, 4, "puff", {"cols": FutonLib.dust_cols(p, 0.5), "size": 0.6, "radius": 0.6, "vmin": 0.3, "vmax": 1.0, "g": Vector3(0, 0.2, 0), "life": 1.6})


# ================================================================== 2. Rasengan Shunki (Anlık Rasengan)
## Ref: Naruto'nun avucunda küçük mavi Rasengan; çevresinde dev, kıvrık, soluk hava yayları girdap gibi açılır.
## Görünüş: avuçta sarmal kollu Rasengan → göz açıp kapayıncaya: kalkış noktasında basınç sönmesi, yol boyunca ince
## mavi-beyaz hız çizgileri + soluk perde + yerde süpürülmüş toz → varışta girdap kolları açılır, büken basınç halkası,
## ışınsal toz izi, kısa mavi parlama.
static func rasengan_shunki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 14.0)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		_rasengan(pj, ba, 0.24, 0.7)
		pj.free_after(0.7, ba)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var a = c.global_position
		var b = (tt.global_position - (tt.global_position - a).normalized() * 1.2) if is_instance_valid(tt) else a + c.face_dir() * 10.0
		b = pj.gp(b)
		_shunki_flash(pj, a, b)
		c.global_position = b
		var at = b + Vector3.UP * 1.1 + c.face_dir() * 0.8
		_shunki_arrive(pj, at, c.face_dir())
		pj.shake(0.6)
		_hit_shake(pj, c, at, 2.2, pj.inf(c, "rasengan_shunki", 2.0, {"knock": 20.0, "launch": 4.0, "kind": "heavy", "element": "fuuton"}))
		Sfx.play("wind", at, 0.9))
	Sfx.play("rasengan", c.global_position, 1.4)


static func _shunki_flash(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	FutonLib.warp(pj, a + Vector3.UP * 1.1, 0.2, 1.6, 0.3, {"power": 1.4, "band": 0.14})
	var dv = b - a
	var L = dv.length()
	if L < 0.3:
		return
	var f = dv / L
	var sd = FutonLib.side_of(f)
	var up = FutonLib.up_of(f)
	for q in 6:
		var o = sd * randf_range(-0.55, 0.55) + up * randf_range(-0.5, 0.6)
		var bow = randf_range(-0.25, 0.25)
		var path = func(u: float) -> Vector3: return a.lerp(b, u) + Vector3.UP * 1.1 + o * (1.0 - u * 0.6) + sd * bow * sin(u * PI)
		FutonLib.line(pj, FutonLib.path_pts(path, 16), 0.03 + 0.015 * (q % 2), 0.32, CYAN if q % 3 == 0 else AIR, {"delay": q * 0.012, "grow": 0.15, "flow": 14.0, "near": 2.0})
	FutonLib.sheet(pj, FutonLib.path_pts(func(u: float) -> Vector3: return a.lerp(b, u) + Vector3.UP * 1.1, 12), 0.5, 0.45, PALE, {"opacity": 0.3, "lines": 4.0, "grow": 0.15, "near": 6.0})
	FutonLib.scour(pj, a, f, L, 1.4, 1.4, 0)


static func _shunki_arrive(pj: PathJutsu, at: Vector3, fd: Vector3) -> void:
	for k in 7:
		var pts = FutonLib.helix_pts(at, fd, 0.4, randf_range(2.2, 3.2), -0.4, 1.2, TAU * k / 7.0, 0.38, 18)
		FutonLib.line(pj, pts, 0.05 if k % 2 == 0 else 0.03, 0.5, AIR, {"delay": k * 0.015, "grow": 0.3, "flow": 9.0, "near": 2.4})
	_rasengan(pj, null, 0.32, 0.3, at)
	FutonLib.warp(pj, at, 0.3, 3.2, 0.42, {"power": 1.5, "swirl": 1.2, "band": 0.12})
	_flash(pj, at, CYAN, 4.0, 8.0, 0.25)
	var g = FutonLib.floor_at(at)
	if at.y - g.y < 2.5:
		FutonLib.scour(pj, g, fd, 5.0, 5.0, 1.6, 1)
		FutonLib.bits(pj, g + Vector3.UP * 0.2, 14, "puff", {"cols": FutonLib.dust_cols(g), "size": 0.7, "radius": 0.8, "dir": Vector3.UP, "spread": 80.0,
			"vmin": 2.0, "vmax": 5.0, "radial": 6.0, "g": Vector3(0, -0.5, 0), "life": 1.1, "damp": 2.0})


# ================================================================== 3. Fūton: Shinkū (Vakum Küresi)
## Ref: Danzō'nun ağzından fırlayan saydam, kalp gibi titreşen hava keseleri; içlerinde dönen gri duman, arkalarında uzun
## soluk hava şeritleri. Görünüş: her atışta ağız önünde yüz yüze basınç halkası + kısa nefes kıvrımları → titrek kenarlı
## vakum kabarcığı (arkasını büker), arkasında yarı saydam şerit + iki ince sarmal çizgi → çarpınca kese patlar: basınç
## halkası, savrulan küçük kesecikler, kıvrık hava kopuntuları, yerde toz.
static func fuuton_shinkuu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var m = Jutsu._mult(c) * Jutsu._elem_bonus(c, "fuuton")
	for i in 4:
		pj.get_tree().create_timer(i * 0.12).timeout.connect(func():
			if not is_instance_valid(c):
				return
			Sfx.play("wind", c.global_position, 1.6, 0.6)
			var pr = Projectile.new()
			pr.shooter = c
			pr.vel = Jutsu._aim(c, t).rotated(Vector3.UP, randf_range(-0.05, 0.05)) * 45.0
			pr.radius = 0.5
			pr.info = {"dmg": 7.0 * m, "element": "fuuton", "knock": 4.0, "kind": "light", "hitstop": 0.02}
			var blob = _blob(0.6)
			pr.add_child(blob)
			var vd: Vector3 = pr.vel.normalized()
			pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
				_blob_pop(pj, pos, vd)
			pj.get_tree().current_scene.add_child(pr)
			pr.global_position = Jutsu._mouth(c)
			FutonLib.follow(pj, pr, 0.4, 10, SMOKE, {"kind": "sheet", "opacity": 0.28, "lines": 3.0, "near": 4.0})
			for q in 2:
				FutonLib.follow(pj, pr, 0.025, 12, AIR, {"offset": Vector3(0.5, 0, 0).rotated(Vector3.FORWARD, PI * q), "spin": 14.0, "flow": 9.0})
			_breath_ring(pj, c, vd))


static func _blob(r: float) -> MeshInstance3D:
	var mi = FutonLib.gi(_quad(), _smat("blob", BLOB_SHADER))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.scale = Vector3.ONE * r * 2.0
	return mi


static func _breath_ring(pj: PathJutsu, c: Node3D, fd: Vector3) -> void:
	if not pj.live(c):
		return
	var mo = pj._mouth_pos(c)
	FutonLib.warp(pj, mo + fd * 0.4, 0.1, 0.9, 0.2, {"bill": false, "basis": _face_basis(fd), "power": 1.2, "band": 0.18})
	var sd = FutonLib.side_of(fd)
	for q in 3:
		var o = sd * (q - 1) * 0.18
		var curl = randf_range(-0.3, 0.3)
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return mo + o * (1.0 + u * 2.0) + fd * u * 1.8 + Vector3.UP * curl * sin(u * PI), 8), 0.02, 0.16, AIR, {"grow": 0.3, "flow": 12.0, "near": 1.0})


static func _blob_pop(pj: PathJutsu, pos: Vector3, dir: Vector3) -> void:
	FutonLib.warp(pj, pos, 0.2, 2.2, 0.3, {"power": 1.3, "band": 0.14})
	for q in 4:
		var b = _blob(randf_range(0.18, 0.3))
		FutonLib.put(pj, b, pos)
		var v = (Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized() + dir * 0.5) * randf_range(2.0, 4.0)
		var tw = b.create_tween().set_parallel()
		tw.tween_property(b, "global_position", pos + v * 0.35, 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_method(FutonLib.pf(b, "fade"), 1.0, 0.0, 0.35)
		tw.chain().tween_callback(b.queue_free)
	for q in 6:
		var w = Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
		var bend = FutonLib.side_of(w) * randf_range(-0.5, 0.5)
		var ln = randf_range(1.2, 1.9)
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return pos + w * u * ln + bend * u * u, 8), 0.03, 0.25, AIR, {"grow": 0.3, "flow": 10.0, "near": 1.5})
	var g = FutonLib.floor_at(pos)
	if pos.y - g.y < 2.0:
		FutonLib.bits(pj, g + Vector3.UP * 0.2, 8, "puff", {"cols": FutonLib.dust_cols(g, 0.7), "size": 0.5, "radius": 0.5, "dir": Vector3.UP, "spread": 70.0,
			"vmin": 1.5, "vmax": 4.0, "radial": 4.0, "life": 0.9, "damp": 2.0})


# ================================================================== 4. Kuchiyose: Kirikiri Mai (Biçme Dansı)
## Ref: Temari'nin yelpaze savuruşuyla gelen, gözü bantlı küçük orak gelincik Kamatari dev orağıyla dönerek rüzgârda
## uçar; arkasında yeşil-mavi rüzgâr, yoldaki her şey biçilir. Görünüş: yerde mürekkep çağırma mührü + toz → küçük sarmal
## açılış → gelinciğin çevresinde dönen akım çizgileri ve orak parıltıları (dönen hilaller) → yelpazeden 22 m dev,
## tırtıklı kesici hilaller + ince perdeler; yolda biçilen ot / yaprak, yerde kesik yarıkları; uçta gelincik rüzgârla
## sarmal çözülerek kaybolur.
static func kuchiyose_kirikiri_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP)
	var at = pj.gp(c.global_position + side * 2.0) + Vector3.UP * 2.0
	_kiri_seal(pj, c.global_position, 1.4, 0.5)
	# kanon: dev yelpaze üçüncü aya kadar açılır, savuruşla Kamatari gelir. Elinde Temari no Ōōgi varsa o açılır;
	# yoksa (yalnız NPC — oyuncu yelpazesiz atamaz) geçici yelpaze belirir
	var m = c.get("model")
	var own = m != null and m.get("weapons") != null and (m.weapons as Array).any(func(w): return String(w["id"]) == "temari_ogi")
	if own:
		preload("res://scripts/combat/keyed_combos.gd")._ogi_stage(c, 3, 1.1)
		pj.anim(c, "throw", 1.0)
	else:
		pj.jutsu_weapon(c, "tessen", 1.0)
	_kiri_pop(pj, at)
	# Kamatari: küçük orak gelincik yelpazenin rüzgârına binip dönerek ileri uçar. Model: SummonModels "weasel_trio"
	var fly = Node3D.new()
	pj.get_tree().current_scene.add_child(fly)
	fly.global_position = at + d * 0.8
	fly.look_at(fly.global_position + d, Vector3.UP)
	var weasel: Node3D = SummonModels.build("weasel_trio", 0.55, 1.0)["root"]
	fly.add_child(weasel)
	weasel.position = Vector3(0, -0.2, 0)
	var tw = fly.create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(fly, "global_position", at + d * 20.0 + Vector3.UP * 0.6, 0.65).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _kiri_vanish(pj, fly.global_position, d))
	tw.tween_callback(fly.queue_free)
	var spin = weasel.create_tween()
	spin.tween_property(weasel, "rotation:z", TAU * 7.0, 0.95)
	_kiri_ride(pj, fly)
	pj.after(0.4, func():
		_kiri_wave(pj, c, at, d)
		Dangle.gust(at + d * 11.0, d * 28.0, 13.2, 0.7)   # yoldaki saç/kumaş savrulur (eski akımın oyun etkisi)
		Combat.hit_zone(c, c.global_position, d, 22.0, 28.0, 4.0, pj.inf(c, "kuchiyose_kirikiri_mai", 1.6, {"knock": 20.0, "launch": 5.0, "kind": "heavy", "element": "fuuton", "bleed": 4.0, "dir": d}))
		pj.shake(0.7))
	Sfx.play("wind", c.global_position, 0.6)


## Yerde mürekkep çağırma mührü: dış ve iç halka + ışınsal çizgiler; çevresinde dışa kaçan toz
static func _kiri_seal(pj: PathJutsu, pos: Vector3, r: float, dur: float) -> void:
	var g = FutonLib.floor_at(pos)
	var b = MB.new()
	for ring in [[r, 30, 0.06], [r * 0.32, 14, 0.04]]:
		var rr = float(ring[0])
		var n = int(ring[1])
		for i in n:
			var a = TAU * i / n
			b.add("box", Vector3(cos(a), 0.0, sin(a)) * rr, Vector3(float(ring[2]), 0.012, TAU * rr / n * 1.08), INK, Vector3(0, rad_to_deg(-a), 0))
	for i in 8:
		var a = TAU * i / 8.0 + 0.2
		b.add("box", Vector3(cos(a), 0.0, sin(a)) * r * 0.64, Vector3(0.04, 0.012, r * 0.56), INK, Vector3(0, rad_to_deg(PI * 0.5 - a), 0))
	var mi = FutonLib.gi(b.build(_flat_mat("ink", false)), null)
	FutonLib.put(pj, mi, g + Vector3.UP * 0.03)
	mi.scale = Vector3(0.3, 1.0, 0.3)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(mi, "scale", Vector3(1.2, 1.0, 1.2) * 0.02, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	FutonLib.scour(pj, g, Vector3.FORWARD, r * 3.2, r * 3.2, 1.2, 1)
	FutonLib.bits(pj, g + Vector3.UP * 0.15, 10, "puff", {"cols": FutonLib.dust_cols(g, 0.6), "size": 0.35, "radius": r * 0.8, "dir": Vector3.UP, "spread": 40.0,
		"vmin": 0.5, "vmax": 1.5, "radial": 5.0, "life": 0.8, "damp": 2.0})
	Sfx.play("poof", g, 0.8)


## Havada çağırma açılışı: dışa çözülen küçük sarmal çizgiler + birkaç yaprak (duman bulutu yok)
static func _kiri_pop(pj: PathJutsu, at: Vector3) -> void:
	for q in 5:
		var pts = FutonLib.helix_pts(at, Vector3.UP, 0.1, 0.9, -0.3, 0.4, TAU * q / 5.0, 0.7, 12)
		FutonLib.line(pj, pts, 0.03, 0.3, MINT, {"delay": q * 0.02, "grow": 0.4, "flow": 9.0, "near": 1.6})
	FutonLib.warp(pj, at, 0.1, 1.0, 0.22, {"power": 1.0, "band": 0.16})
	if FutonLib.has_leaves(at):
		FutonLib.bits(pj, at, 6, "leaf", {"cols": FutonLib.leaf_cols(at), "size": 0.13, "radius": 0.3, "vmin": 2.0, "vmax": 4.0, "spread": 180.0, "g": Vector3(0, -2.0, 0), "life": 1.2})


## Gelinciğin çevresinde dönen akım çizgileri + orak parıltıları (dönen hilaller, uçuş eksenine dik düzlemde)
static func _kiri_ride(pj: PathJutsu, fly: Node3D) -> void:
	for q in 3:
		FutonLib.follow(pj, fly, 0.04, 12, MINT if q == 0 else AIR, {"offset": Vector3(0.55, 0, 0).rotated(Vector3.FORWARD, TAU * q / 3.0), "spin": 44.0, "flow": 10.0, "near": 2.0})
	FutonLib.follow(pj, fly, 0.45, 9, PALE, {"kind": "sheet", "opacity": 0.3, "lines": 3.0, "near": 5.0})
	for q in 4:
		FutonLib.blade(pj, Vector3.ZERO, FutonLib.blade_basis(Vector3.UP, Vector3.FORWARD), 1.6, 0.28, WHITE, {"parent": fly, "delay": 0.3 + q * 0.15, "spin": 30.0, "thick": 0.18, "wisp": 1.6, "near": 2.0})


static func _kiri_wave(pj: PathJutsu, c: Node3D, at: Vector3, d: Vector3) -> void:
	var side = FutonLib.side_of(d)
	# yelpazeden dev, tırtıklı kesici hilaller ileri biçer
	for q in 5:
		var tilt = [0.0, 0.35, -0.35, 0.18, -0.18][q]
		var nrm = (Vector3.UP + side * tilt).normalized()
		FutonLib.blade(pj, at + d * (1.0 + q * 0.6) + Vector3.UP * (q - 2) * 0.35, FutonLib.blade_basis(d, nrm), 7.0 + q * 0.8, 0.6, WHITE if q == 0 else AIR,
			{"delay": q * 0.05, "vel": d * 30.0, "thick": 0.16, "jag": 1.0, "wisp": 1.8, "near": 7.0, "grow": 0.2})
	# akış perdeleri: yelpaze ağzından açılan geniş, ince çizgili yarı saydam şeritler
	for q in 6:
		var o = side * (q - 2.5) * 1.6
		var dip = randf_range(-0.6, 0.4)
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return at + o * (0.3 + u * 0.9) + d * u * 22.0 + Vector3.UP * (dip * u - 0.8 * u), 14)
		FutonLib.sheet(pj, pts, 1.1, 0.7, PALE, {"delay": q * 0.03, "opacity": 0.32, "lines": 4.0, "grow": 0.35, "near": 8.0, "flow": 5.0})
	for q in 8:
		var o2 = side * randf_range(-4.5, 4.5) + Vector3.UP * randf_range(-1.2, 0.8)
		var wob = randf_range(-0.8, 0.8)
		var pts2 = FutonLib.path_pts(func(u: float) -> Vector3: return at + o2 * (0.4 + u * 0.8) + d * u * 21.0 + side * wob * sin(u * PI), 14)
		FutonLib.line(pj, pts2, 0.035, 0.55, MINT if q % 3 == 0 else AIR, {"delay": 0.04 + q * 0.02, "grow": 0.35, "flow": 10.0, "near": 3.0})
	# biçilen ot / yaprak, yerde kesik yarıkları ve süpürülmüş toz
	for q in 4:
		var gq = FutonLib.floor_at(c.global_position + d * (4.0 + q * 5.0))
		var kind = "leaf" if FutonLib.has_leaves(gq) else "grit"
		FutonLib.bits(pj, gq + Vector3.UP * 0.3, 10, kind, {"cols": FutonLib.leaf_cols(gq) if kind == "leaf" else FutonLib.dust_cols(gq, 1.0), "size": 0.14, "box": Vector3(3.0, 0.3, 3.0),
			"dir": (d + Vector3.UP * 0.5).normalized(), "spread": 30.0, "vmin": 6.0, "vmax": 14.0, "g": Vector3(0, -3.0, 0), "life": 1.4, "spin": 720.0})
		FutonLib.scour(pj, gq, d, 4.0, 3.5, 2.2, 2, Color(-1, 0, 0), {"delay": 0.05 * q})
	FutonLib.scour(pj, c.global_position + d * 1.5, d, 20.0, 8.0, 2.0, 0)


## Uçta gelincik rüzgârla çözülür: dışa açılan sarmal + yaprak
static func _kiri_vanish(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	for q in 6:
		var pts = FutonLib.helix_pts(p, d, 0.2, 1.4, 0.0, 1.5, TAU * q / 6.0, 0.6, 12)
		FutonLib.line(pj, pts, 0.03, 0.35, AIR, {"delay": q * 0.015, "grow": 0.4, "flow": 9.0, "near": 1.6})
	if FutonLib.has_leaves(p):
		FutonLib.bits(pj, p, 8, "leaf", {"cols": FutonLib.leaf_cols(p), "size": 0.13, "radius": 0.4, "dir": d, "spread": 60.0, "vmin": 3.0, "vmax": 7.0, "g": Vector3(0, -2.0, 0), "life": 1.4})


# ================================================================== 5. Uchihagaeshi (Uchiha Dönüşü)
## Ref: Madara'nın gunbai'si; çarpan saldırı yelpazenin yüzünde durur, çevresinde beyaz kâğıt gibi kırıntılar saçılır;
## savuruşta önde dev toz-kaya dalgası. Görünüş: kızıl göz parıltısı, gunbai yüzüne doğru sarmalla toplanan hava →
## bekleyişte yelpaze yüzünde basınç dalgalanması + yüzü saran kısa yaylar → yansıtmada beyaz kırıntılar, geri dönen
## mermi yönünde açılan sarmal + basınç halkası → kapanışta yatay geniş hilal süpürmesi, perdeler, kaya parçaları, toz dalgası.
static func uchihagaeshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_eyes(pj, c, 2.0)
	var d = pj.fwd(c, t)
	var dur = 2.4
	pj.busy(c, dur + 0.3)
	if c.get("model"):
		_dress_gunbai(c.model.hold_temp("gunbai", dur + 0.5, "Right", 2.2, PI * 0.5, false, true))
		c.model.play("block", 0.08, 1.0)
	if c is Player:
		c.facing = atan2(-d.x, -d.z)
	var center = func(): return c.global_position + Vector3.UP * 1.6 + (c.face_dir() if c.has_method("face_dir") else d) * 0.9
	Sfx.play("wind", c.global_position, 0.7)
	_gaeshi_raise(pj, center.call(), d)
	var reflected = [0]
	pj.every(dur, 1.0 / 30.0, func(i, _k):
		if not is_instance_valid(c):
			return
		var cp: Vector3 = center.call()
		var fd: Vector3 = c.face_dir() if c.has_method("face_dir") else d
		if i % 8 == 0:
			_gaeshi_face(pj, cp, fd)
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and n.shooter != c and Combat.hostile(c, n.shooter) and n.global_position.distance_to(cp) < 3.2:
				var back = n.shooter
				n.shooter = c
				n.hit_list.clear()
				n.vel = -n.vel * 1.3
				if is_instance_valid(back):
					n.homing = back
					n.homing_turn = 4.0
				reflected[0] += 1
				# emiş: saldırı yelpazenin yüzünde bir an durur, sarmal rüzgârla geri fırlar
				var rd: Vector3 = n.vel.normalized()
				_gaeshi_catch(pj, n.global_position, cp, rd)
				Dangle.gust(cp + rd * 3.0, rd * 28.0, 3.6, 0.7)   # yoldaki saç/kumaş savrulur (eski hamlenin oyun etkisi)
				pj.shake(0.15)
				Sfx.play("guard", cp, 0.8)
		for e in pj.enemies_near(c, cp, 2.2):
			pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "uchihagaeshi", 0.3, {"knock": 14.0, "launch": 3.0, "kind": "heavy"}))
	, func():
		# kapanış: yelpaze savrulur — önde rüzgâr dalgası, emilen saldırı sayısıyla güçlenir
		if not is_instance_valid(c):
			return
		pj.anim(c, "slash_b", 1.6)
		var cp: Vector3 = center.call()
		var fd: Vector3 = c.face_dir() if c.has_method("face_dir") else d
		var pw = 1.0 + 0.35 * reflected[0]
		var L = 12.0 * minf(pw, 2.0)
		var W = 6.0 * minf(pw, 2.0)
		_gaeshi_swing(pj, c, cp, fd, L, W)
		Dangle.gust(cp + fd * L * 0.5, fd * 28.0, maxf(L * 0.6, W), 0.7)   # yoldaki saç/kumaş savrulur
		for e in pj.enemies_near(c, cp + fd * 5.0, 6.5 * minf(pw, 1.6)):
			var v = (e.global_position - c.global_position).normalized()
			if v.dot(fd) > 0.2:
				pj.hit(c, e.global_position + Vector3.UP, 1.0, pj.inf(c, "uchihagaeshi", 0.9 + 0.25 * reflected[0], {"knock": 26.0, "launch": 6.0, "kind": "heavy", "dir": fd}))
		pj.shake(0.45)
		Sfx.play("wind", cp, 0.5))


## Gunbai kalkar: hava yelpaze yüzüne doğru sarmalla toplanır
static func _gaeshi_raise(pj: PathJutsu, cp: Vector3, fd: Vector3) -> void:
	for q in 6:
		var pts = FutonLib.helix_pts(cp, fd, 1.5, 0.25, -0.8, 0.0, TAU * q / 6.0, 0.55, 14)
		FutonLib.line(pj, pts, 0.03, 0.4, Color(1.0, 0.93, 0.9, 0.75), {"delay": q * 0.02, "grow": 0.5, "flow": 8.0, "near": 1.6})


## Bekleyiş: yelpaze yüzünde basınç dalgalanması + yüzü saran iki kısa yay
static func _gaeshi_face(pj: PathJutsu, cp: Vector3, fd: Vector3) -> void:
	FutonLib.warp(pj, cp + fd * 0.3, 0.5, 1.3, 0.3, {"bill": false, "basis": _face_basis(fd), "power": 0.8, "swirl": 0.6, "band": 0.2, "near": 1.6})
	for q in 2:
		var pts = FutonLib.helix_pts(cp + fd * 0.2, fd, 1.05, 1.15, 0.0, 0.1, randf() * TAU, 0.22, 10)
		FutonLib.line(pj, pts, 0.025, 0.26, Color(1.0, 0.94, 0.92, 0.6), {"grow": 0.4, "flow": 8.0, "near": 1.6})


## Yansıtma: beyaz kâğıt gibi kırıntılar, geri dönüş yönünde açılan sarmal, basınç halkası
static func _gaeshi_catch(pj: PathJutsu, p: Vector3, cp: Vector3, rd: Vector3) -> void:
	FutonLib.bits(pj, p, 14, "grit", {"cols": [Color(1, 1, 1, 1), Color(0.96, 0.96, 0.98, 1), Color(1, 1, 1, 0)], "size": 0.13, "radius": 0.5, "spread": 180.0,
		"vmin": 4.0, "vmax": 9.0, "g": Vector3(0, -5.0, 0), "life": 0.8, "spin": 900.0, "turb": false})
	FutonLib.warp(pj, p, 0.2, 1.8, 0.25, {"power": 1.4, "band": 0.14})
	for q in 4:
		var pts = FutonLib.helix_pts(cp, rd, 0.9, 0.2, 0.0, 4.0, TAU * q / 4.0, 0.9, 16)
		FutonLib.line(pj, pts, 0.035, 0.35, Color(1.0, 0.95, 0.9, 0.8), {"delay": 0.05 + q * 0.015, "grow": 0.35, "flow": 11.0, "near": 1.6})


## Kapanış savuruşu: yatay geniş hilal süpürmesi, perdeler, kaya parçaları, toz dalgası
static func _gaeshi_swing(pj: PathJutsu, c: Node3D, cp: Vector3, fd: Vector3, L: float, W: float) -> void:
	var side = FutonLib.side_of(fd)
	for q in 3:
		var nrm = (Vector3.UP + side * (q - 1) * 0.25).normalized()
		FutonLib.blade(pj, cp + fd * (0.8 + q * 0.4) - Vector3.UP * q * 0.3, FutonLib.blade_basis(fd, nrm), W * (0.9 - q * 0.12), 0.5, Color(1.0, 0.95, 0.9, 0.85),
			{"delay": q * 0.05, "vel": fd * L * 1.4, "thick": 0.22, "wisp": 2.0, "near": 6.0, "grow": 0.18})
	for q in 5:
		var o = side * (q - 2) * W * 0.18
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return cp + o * (0.4 + u) + fd * u * L - Vector3.UP * u * 1.0, 12)
		FutonLib.sheet(pj, pts, 0.9, 0.6, Color(1.0, 0.96, 0.92, 0.7), {"delay": q * 0.02, "opacity": 0.32, "lines": 4.0, "grow": 0.35, "near": 8.0})
	var g = FutonLib.floor_at(cp + fd * 4.0)
	FutonLib.chunks(pj, g, 14, 12.0, FutonLib.ground_col(g).darkened(0.35), 0.4, fd + Vector3.UP)
	for q in 4:
		var gq = FutonLib.floor_at(c.global_position + fd * (2.0 + q * L * 0.22))
		FutonLib.bits(pj, gq + Vector3.UP * 0.3, 8, "puff", {"cols": FutonLib.dust_cols(gq, 0.8), "size": 0.9 + q * 0.2, "box": Vector3(W * 0.3, 0.2, W * 0.3),
			"dir": (fd + Vector3.UP * 0.4).normalized(), "spread": 25.0, "vmin": 6.0, "vmax": 12.0, "g": Vector3(0, -0.4, 0), "damp": 2.0, "life": 1.3, "burst": 0.9})
	FutonLib.scour(pj, c.global_position + fd * 1.0, fd, L, W * 0.8, 2.0, 0)


# ================================================================== 6. Fūton: Rasen Shōheki (Sarmal Bariyer)
## Ref (manga): Konohamaru avucundaki Rasengan'ı dağıtır; elin çevresinde iç içe sarmal hava yayları dışa açılır.
## Görünüş: avuçta Rasengan → patlamada avucun önünde ileri bakan düz sarmal kollar dışa açılır, yüz yüze basınç
## halkası, yerde ışınsal toz izi ve dışa kaçan toz/yaprak → 1,3 sn bedeni saran yükselen sarmal çizgiler;
## gelen mermi bariyere girince kısa sıkı sarmal + basınçla dağılır.
static func futon_rasen_shoheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "futon_rasen_shoheki"
	var d = pj.fwd(c, t)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		_rasengan(pj, ba, 0.34, 0.3)
		pj.free_after(0.3, ba)
	pj.anim(c, "push", 1.6)
	Sfx.play("rasengan", c.global_position, 1.2)
	var cw = weakref(c)
	var burst = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var o = cc.global_position + Vector3.UP * 1.1 + d * 0.9
		_shoheki_burst(pj, o, d, pj.gp(cc.global_position))
		Sfx.play("wind", o, 0.8)
		if cc is Player:
			Buffs.add("rasen_shoheki", 1.4, {"armor": 0.2, "_name": "Rasen Shōheki", "_desc": "rüzgâr bariyeri: gelen darbeler kesilir"})
		elif cc.has_method("add_buff"):
			cc.add_buff("rasen_shoheki", 1.4, {"armor": 0.2})
		var pushed = []
		var guard = func(i, _k):
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			var g = c2.global_position
			if i % 3 == 0:
				_shoheki_spin(pj, g, i)
			for p in pj.get_tree().get_nodes_in_group("projectiles"):
				if is_instance_valid(p) and p.get("shooter") != c2 and p.global_position.distance_to(g + Vector3.UP) < 3.3:
					_shoheki_shred(pj, p.global_position)
					p.queue_free()
			for e in pj.enemies_near(c2, g, 3.0):
				if e in pushed:
					continue
				pushed.append(e)
				var v: Vector3 = e.global_position - g
				v.y = 0.0
				e.take_hit(pj.inf(c2, id, 0.9, {"knock": 18.0, "launch": 3.0, "kind": "heavy", "element": "fuuton", "hitstop": 0.06, "stun": 0.6, "dir": v.normalized()}))
		pj.every(1.3, 0.05, guard, Callable())
	pj.after(0.25, burst)


static func _shoheki_burst(pj: PathJutsu, o: Vector3, d: Vector3, g: Vector3) -> void:
	for q in 7:
		var pts = FutonLib.helix_pts(o, d, 0.2, 3.4, 0.0, 0.3, TAU * q / 7.0, 0.6, 22)
		FutonLib.line(pj, pts, 0.06 if q % 2 == 0 else 0.035, 0.5, AIR if q % 3 else WHITE, {"delay": q * 0.01, "grow": 0.3, "flow": 10.0, "near": 2.0})
	var sp = FutonLib.helix_pts(o, d, 0.4, 2.6, 0.0, 0.2, 0.7, 0.8, 18)
	FutonLib.sheet(pj, sp, 0.5, 0.45, PALE, {"opacity": 0.28, "lines": 3.0, "grow": 0.3, "near": 6.0, "hint": d, "twin": false})
	FutonLib.warp(pj, o, 0.3, 3.4, 0.35, {"bill": false, "basis": _face_basis(d), "power": 1.4, "swirl": 1.5, "band": 0.14})
	_rasengan(pj, null, 0.34, 0.18, o)
	FutonLib.scour(pj, g, d, 6.8, 6.8, 1.6, 1)
	FutonLib.bits(pj, g + Vector3.UP * 0.2, 12, "puff", {"cols": FutonLib.dust_cols(g, 0.7), "size": 0.55, "radius": 1.0, "dir": Vector3.UP, "spread": 50.0,
		"vmin": 1.0, "vmax": 3.0, "radial": 9.0, "tang": 6.0, "life": 1.0, "damp": 2.0})
	if FutonLib.has_leaves(g):
		FutonLib.bits(pj, g + Vector3.UP * 0.5, 10, "leaf", {"cols": FutonLib.leaf_cols(g), "size": 0.14, "radius": 1.2, "spread": 60.0, "vmin": 3.0, "vmax": 6.0,
			"radial": 8.0, "tang": 8.0, "g": Vector3(0, -2.0, 0), "life": 1.4})


## Bariyer: bedeni saran, yükselen sarmal çizgi (her seferinde farklı başlangıç), arada soluk bant
static func _shoheki_spin(pj: PathJutsu, g: Vector3, i: int) -> void:
	var pts = FutonLib.helix_pts(g, Vector3.UP, 2.6, 2.4, 0.4, 2.8, randf() * TAU, 0.38, 14)
	FutonLib.line(pj, pts, 0.05, 0.3, AIR, {"grow": 0.35, "flow": 10.0, "near": 2.4})
	if i % 6 == 0:
		var band = FutonLib.helix_pts(g, Vector3.UP, 2.5, 2.5, 1.0, 1.6, randf() * TAU, 0.45, 14)
		FutonLib.sheet(pj, band, 0.35, 0.35, PALE, {"opacity": 0.25, "lines": 3.0, "grow": 0.35, "near": 4.0})


## Bariyere giren mermi: kısa sıkı sarmal + basınç + kırıntı
static func _shoheki_shred(pj: PathJutsu, p: Vector3) -> void:
	for q in 3:
		var ax = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		FutonLib.line(pj, FutonLib.helix_pts(p, ax, 0.6, 0.1, 0.0, 0.2, randf() * TAU, 1.2, 14), 0.03, 0.22, WHITE, {"grow": 0.4, "flow": 12.0, "near": 1.4})
	FutonLib.warp(pj, p, 0.2, 1.1, 0.22, {"power": 1.2, "swirl": 1.0, "band": 0.16})
	FutonLib.bits(pj, p, 6, "grit", {"cols": FutonLib.dust_cols(p, 1.0), "size": 0.08, "radius": 0.2, "spread": 180.0, "vmin": 3.0, "vmax": 6.0, "tang": 12.0, "life": 0.6})


# ================================================================== 7. Fūton: Shinkūjin (Vakum Bıçağı)
## Ref: Danzō'nun kunaisi; bıçak boyunca ve ucunun ötesine uzanan yeşil-beyaz düz girdap diskleri (spiral), kenarlarında
## ince beyaz kıvrımlar. Görünüş: kunai etrafında ileri doğru büyüyen yeşil düz spiraller (döner) → savuruşta yeşil çapraz
## hilal + yankısı, kesikten ileri savrulan küçük yeşil spiraller, yerde kısa kesik yarıkları, isabet edenlerde çizik.
static func futon_shinkujin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	var d = pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	pj.busy(c, 0.6)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		# kunai + girdaplar elin konumunu izler, yönü her karede bakış yönü (el kemiğinin ekseni beklemede geriye bakıyordu)
		var blade = Node3D.new()
		ba.add_child(blade)
		blade.top_level = true
		var kb = MB.new()
		CharacterModel._kunai_mesh(kb)
		var km = MeshInstance3D.new()
		km.mesh = kb.build(Props.toon())
		blade.add_child(km)
		var rings = Node3D.new()
		blade.add_child(rings)
		_shinkujin_rings(pj, rings)
		var rtw = rings.create_tween().set_loops(12)
		rtw.tween_property(rings, "rotation:z", TAU, 0.12).as_relative()
		var follow = func():
			if is_instance_valid(blade) and is_instance_valid(ba) and pj.live(c):
				var fd = c.face_dir()
				blade.global_transform = Transform3D(Basis.looking_at(-fd, Vector3.UP), ba.global_position)
		pj.get_tree().process_frame.connect(follow)
		pj.after(0.75, func():
			if pj.get_tree().process_frame.is_connected(follow):
				pj.get_tree().process_frame.disconnect(follow))
		pj.free_after(0.7, ba)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_a", 1.8)
		_shinkujin_cut(pj, c, c.global_position + Vector3.UP * 1.2 + d * 0.6, d)
		_hit_shake(pj, c, c.global_position + Vector3.UP + d * 1.4, 1.8, pj.inf(c, "futon_shinkujin", 1.2, {"knock": 6.0, "kind": "heavy", "element": "fuuton", "bleed": 4.0}))
		Sfx.play("wind", c.global_position, 1.8, 0.5))


## Bıçak ekseni yerel +Z: bıçaktan ucun ötesine doğru büyüyen yeşil düz spiraller (çizgi + soluk dolgu)
static func _shinkujin_rings(pj: PathJutsu, rings: Node3D) -> void:
	for q in 5:
		var rr = 0.1 + q * 0.055
		var cz = Vector3(0, 0, 0.14 + q * 0.12)
		var pts = FutonLib.helix_pts(cz, Vector3.BACK, rr * 0.15, rr, 0.0, 0.0, q * 1.3, 1.7, 22)
		FutonLib.fixed(pj, pts, 0.012 + q * 0.002, "line", JADE, {"parent": rings, "flow": 9.0, "near": 0.6, "hint": Vector3.BACK})
		var fill = FutonLib.helix_pts(cz, Vector3.BACK, rr * 0.4, rr * 0.9, 0.0, 0.0, q * 1.3 + 0.8, 0.9, 14)
		FutonLib.fixed(pj, fill, rr * 0.22, "sheet", JADE_L, {"parent": rings, "opacity": 0.3, "lines": 2.0, "near": 0.6, "hint": Vector3.BACK, "twin": false})


static func _shinkujin_cut(pj: PathJutsu, c: Node3D, o: Vector3, d: Vector3) -> void:
	var side = FutonLib.side_of(d)
	var nrm = (Vector3.UP + side * 0.6).normalized()   # çapraz kesik
	FutonLib.blade(pj, o + d * 0.4, FutonLib.blade_basis(d, nrm), 2.8, 0.3, JADE, {"vel": d * 5.0, "thick": 0.22, "wisp": 1.4, "near": 1.6})
	FutonLib.blade(pj, o + d * 0.2, FutonLib.blade_basis(d, nrm), 2.2, 0.26, JADE_L, {"delay": 0.03, "vel": d * 4.0, "thick": 0.12, "near": 1.6})
	for q in 3:
		var p0 = o + d * (1.0 + q * 0.7) + side * randf_range(-0.4, 0.4)
		var ax = (d + Vector3.UP * randf_range(-0.3, 0.3)).normalized()
		var pts = FutonLib.helix_pts(p0, ax, 0.05, 0.35 + q * 0.08, 0.0, 0.0, randf() * TAU, 1.7, 18)
		FutonLib.line(pj, pts, 0.025, 0.4, JADE, {"delay": 0.04 + q * 0.04, "grow": 0.4, "flow": 9.0, "near": 1.2, "hint": ax})
	for e in pj.enemies_near(c, c.global_position + d * 1.4, 2.4):
		if pj.live(e):
			var p = e.global_position + Vector3.UP * 1.1
			FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return p + side * lerpf(-0.7, 0.7, u) + Vector3.UP * lerpf(0.6, -0.5, u) - d * 0.3, 8), 0.03, 0.22, JADE_L, {"delay": 0.06, "grow": 0.25})
	FutonLib.scour(pj, c.global_position + d * 0.8, d, 2.4, 1.2, 1.2, 2)


# ================================================================== 8. Fūton: Shinkū Taigyoku (Dev Vakum Küresi)
## Ref: Danzō'nun önünde gökyüzünü büken dev daire; yüzeyi iç içe ince fırça yaylarıyla dolu, kenarı keskin.
## Görünüş: ağız önünde her yönden merkeze emilen koyu / açık hız çizgileri + içe çöken basınç + içe çekilen kırıntı →
## fırlayan dev girdap diski (arkasını büker, yayları döner), kenarından kopan sarmal çizgiler, soluk iz perdesi,
## altında zemini kazıyan toz izleri → çarpınca dev basınç halkası, dışa açılan yaylar, ışınsal iz, kaya ve toz.
static func futon_shinku_taigyoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var cen = pj._mouth_pos(c) + c.face_dir() * 1.5
	_taigyoku_inhale(pj, cen, c.face_dir())
	var tt2 = pj.tg(c, t, 28.0)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var from = pj._mouth_pos(c) + c.face_dir() * 1.2
		var core = Node3D.new()
		var pr = pj.shot(c, from, pj.aim_at(c, tt2, from), 24.0, core, pj.inf(c, "futon_shinku_taigyoku", 1.8, {"knock": 24.0, "launch": 6.0, "kind": "heavy", "element": "fuuton", "hitstop": 0.05}), null, false, 1.6, func(p, _h):
			_taigyoku_blast(pj, p)
			pj.shake(0.75))
		pr.radius = 1.4
		_taigyoku_body(pj, core, pr))
	Sfx.play("wind", c.global_position, 0.5)


static func _taigyoku_inhale(pj: PathJutsu, cen: Vector3, fw: Vector3) -> void:
	var sd = FutonLib.side_of(fw)
	var upv = FutonLib.up_of(fw)
	for k in 30:
		var a = TAU * k / 30.0 + randf_range(-0.08, 0.08)
		var dirr = sd * cos(a) + upv * sin(a)
		var r0 = randf_range(5.0, 8.0)
		var col = Color(0.3, 0.33, 0.36, 0.7) if k % 3 != 0 else Color(0.86, 0.92, 0.95, 0.7)
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return cen + dirr * lerpf(r0, 0.4, u), 8), 0.03, 0.32, col, {"delay": randf() * 0.12, "grow": 0.55, "flow": 12.0, "near": 2.4})
	FutonLib.warp(pj, cen, 2.6, 0.3, 0.4, {"ring": false, "power": 1.4, "swirl": 0.8, "fade_from": 0.7})
	FutonLib.bits(pj, cen, 16, "grit", {"cols": FutonLib.dust_cols(cen, 1.0), "size": 0.08, "radius": 3.5, "spread": 180.0, "vmin": 0.0, "vmax": 0.5, "radial": -14.0, "g": Vector3.ZERO, "life": 0.4})


static func _taigyoku_body(pj: PathJutsu, core: Node3D, pr: Projectile) -> void:
	var vx = FutonLib.gi(_quad(), _smat("vortex", VORTEX_SHADER))
	vx.set_instance_shader_parameter("seed", randf() * 10.0)
	core.add_child(vx)
	vx.scale = Vector3.ONE * 1.2
	vx.create_tween().tween_property(vx, "scale", Vector3.ONE * 6.4, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for q in 4:
		FutonLib.follow(pj, pr, 0.06, 12, AIR, {"offset": Vector3(3.0, 0, 0).rotated(Vector3.FORWARD, TAU * q / 4.0), "spin": 9.0, "flow": 9.0, "near": 3.0})
	FutonLib.follow(pj, pr, 2.2, 10, PALE, {"kind": "sheet", "opacity": 0.22, "lines": 5.0, "near": 8.0})
	var cnt = {"t": 0.0}
	pr.on_tick = func(p: Projectile, dt: float) -> void:
		cnt["t"] = float(cnt["t"]) + dt
		if float(cnt["t"]) < 0.12:
			return
		cnt["t"] = 0.0
		var g = FutonLib.floor_at(p.global_position)
		if p.global_position.y - g.y < 4.5:
			FutonLib.scour(pj, g, p.vel, 3.5, 4.0, 1.8, 0)
			FutonLib.bits(pj, g + Vector3.UP * 0.2, 5, "puff", {"cols": FutonLib.dust_cols(g, 0.7), "size": 0.7, "radius": 1.2, "dir": Vector3.UP, "spread": 50.0,
				"vmin": 2.0, "vmax": 5.0, "tang": 6.0, "life": 0.9, "damp": 2.0})


static func _taigyoku_blast(pj: PathJutsu, p: Vector3) -> void:
	FutonLib.warp(pj, p, 0.5, 6.0, 0.5, {"power": 1.6, "swirl": 0.8, "band": 0.12})
	FutonLib.warp(pj, p, 0.3, 3.5, 0.35, {"ring": false, "power": 1.0, "delay": 0.05})
	for k in 12:
		var ax = Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		var pts = FutonLib.helix_pts(p, ax, 1.0, randf_range(4.0, 6.0), 0.0, 0.0, randf() * TAU, 0.3, 14)
		FutonLib.line(pj, pts, 0.06 if k % 3 == 0 else 0.035, 0.45, AIR, {"delay": k * 0.01, "grow": 0.3, "flow": 10.0, "near": 3.0})
	_flash(pj, p, AIR, 3.0, 12.0, 0.3)
	var g = FutonLib.floor_at(p)
	if p.y - g.y < 4.0:
		FutonLib.scour(pj, g, Vector3.FORWARD, 9.0, 9.0, 2.4, 1)
		FutonLib.chunks(pj, g, 10, 11.0, FutonLib.ground_col(g).darkened(0.35), 0.4)
		FutonLib.bits(pj, g + Vector3.UP * 0.3, 18, "puff", {"cols": FutonLib.dust_cols(g, 0.8), "size": 1.0, "radius": 1.5, "dir": Vector3.UP, "spread": 60.0,
			"vmin": 2.0, "vmax": 5.0, "radial": 12.0, "life": 1.5, "damp": 2.5, "g": Vector3(0, -0.3, 0)})
		if FutonLib.has_leaves(g):
			FutonLib.bits(pj, g + Vector3.UP * 0.5, 14, "leaf", {"cols": FutonLib.leaf_cols(g), "size": 0.15, "radius": 1.5, "spread": 70.0, "vmin": 6.0, "vmax": 12.0,
				"radial": 6.0, "g": Vector3(0, -3.0, 0), "life": 1.8})


# ================================================================== 9. Fūton: Shinkū Renpa (Vakum Dizisi)
## Ref: farklı açılarda ekrandan kesip geçen uzun, ince, yarı saydam hava dilimleri. Görünüş: her atış başın savruluş
## açısına göre farklı eğimde (sağa / sola yatık) uzun ince dilim: yarı saydam perde + öndeki ince hilal kenar + iki uçtan
## kopan ince izler → çarpınca aynı eğimde kısa keskin hilal kesiği, basınç ve kırıntı.
static func futon_shinku_renpa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 26.0)
	for k in 5:
		pj.after(k * 0.12, func():
			if not pj.live(c):
				return
			var from = pj._mouth_pos(c)
			var dk = pj.aim_at(c, tt, from).rotated(Vector3.UP, [0.0, -0.22, 0.22, -0.11, 0.11][k])
			var roll = [0.25, -0.9, 0.95, -0.5, 0.55][k]
			var core = Node3D.new()
			var pr = pj.shot(c, from, dk, 40.0, core, pj.inf(c, "futon_shinku_renpa", 0.6, {"knock": 6.0, "kind": "heavy", "element": "fuuton", "bleed": 1.0}), null, false, 1.0, func(pp, _h):
				_renpa_cut(pj, pp, dk, roll)
				pj.shake(0.4))
			_renpa_body(pj, core, pr, roll))
	Sfx.play("wind", c.global_position, 1.2)


static func _renpa_body(pj: PathJutsu, core: Node3D, pr: Projectile, roll: float) -> void:
	var lat = Vector3(cos(roll), sin(roll), 0.0)
	var nrm = Vector3(-sin(roll), cos(roll), 0.0)
	var pts = FutonLib.path_pts(func(u: float) -> Vector3: return Vector3(0, 0, (1.0 - u) * 3.6) + nrm * 0.12 * sin(u * PI), 10)
	FutonLib.fixed(pj, pts, 0.8, "sheet", PALE, {"parent": core, "hint": nrm, "twin": false, "opacity": 0.42, "lines": 3.0, "near": 3.0, "flow": 6.0})
	var edge = FutonLib.path_pts(func(u: float) -> Vector3: return lat * (u * 2.0 - 1.0) * 0.85 + Vector3(0, 0, 0.35 * pow(u * 2.0 - 1.0, 2.0)), 10)
	FutonLib.fixed(pj, edge, 0.03, "line", WHITE, {"parent": core, "flow": 10.0, "near": 2.0})
	FutonLib.blade(pj, Vector3.ZERO, FutonLib.blade_basis(Vector3.FORWARD, nrm), 1.8, 1.0, AIR, {"parent": core, "thick": 0.14, "wisp": 1.2, "near": 2.4, "grow": 0.1})
	for s in [-1.0, 1.0]:
		FutonLib.follow(pj, pr, 0.025, 10, AIR, {"offset": lat * 0.8 * s, "flow": 10.0, "near": 2.0})


static func _renpa_cut(pj: PathJutsu, pp: Vector3, dk: Vector3, roll: float) -> void:
	var s = FutonLib.side_of(dk)
	var up = FutonLib.up_of(dk)
	var nrm_w = -s * sin(roll) + up * cos(roll)
	FutonLib.blade(pj, pp, FutonLib.blade_basis(dk, nrm_w), 2.4, 0.25, WHITE, {"vel": dk * 6.0, "thick": 0.12, "jag": 0.7, "near": 2.0})
	FutonLib.warp(pj, pp, 0.2, 1.4, 0.22, {"power": 1.0, "band": 0.16})
	FutonLib.bits(pj, pp, 8, "grit", {"cols": FutonLib.dust_cols(pp, 1.0), "size": 0.08, "radius": 0.3, "dir": dk, "spread": 70.0, "vmin": 4.0, "vmax": 8.0, "life": 0.6})


# ================================================================== 10. Fūton: Shinkūha (Vakum Dalgası)
## Ref: yerden yukarı kesip geçen, yeşil-beyaz parlak, uzun ve ince ışın gibi vakum dalgaları; yoldakiler kesilir.
## Görünüş: derin nefeste ağza çekilen hava → üç dalga: önde yatay açılan geniş saydam hilal cephesi, arkasında yelpaze
## gibi açılan uzun ince nane yeşili çizgiler, ilk dalgada yere yatık geniş soluk perde; yerde uzun süpürülmüş toz + kesik yarıkları.
static func futon_shinkuha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 30.0)
	var from = pj._mouth_pos(c)
	var d = pj.aim_at(c, tt, from)
	var sd = d.cross(Vector3.UP).normalized()
	_shinkuha_breath(pj, from, d)
	for k in 3:
		pj.after(k * 0.08, func():
			if not pj.live(c):
				return
			var core = Node3D.new()
			var pr = pj.shot(c, from, d, 42.0, core, pj.inf(c, "futon_shinkuha", 0.37, {"knock": 5.0, "kind": "heavy", "element": "fuuton", "bleed": 2.0}), null, true, 0.75)
			pr.radius = 1.3
			_shinkuha_wave(pj, core, c, from, d, sd, k))
	Sfx.play("wind", from, 0.9)


static func _shinkuha_breath(pj: PathJutsu, from: Vector3, d: Vector3) -> void:
	var sd = FutonLib.side_of(d)
	for q in 8:
		var a = TAU * q / 8.0
		var dirr = sd * cos(a) + FutonLib.up_of(d) * sin(a)
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return from + d * 0.3 + dirr * lerpf(1.6, 0.15, u) - d * 0.4 * (1.0 - u), 6), 0.02, 0.16, MINT, {"grow": 0.6, "flow": 12.0, "near": 1.0})


static func _shinkuha_wave(pj: PathJutsu, core: Node3D, c: Node3D, from: Vector3, d: Vector3, sd: Vector3, k: int) -> void:
	FutonLib.blade(pj, Vector3.ZERO, FutonLib.blade_basis(Vector3.FORWARD, Vector3.UP), 3.6 + k * 0.6, 0.75, MINT, {"parent": core, "thick": 0.18, "wisp": 1.4, "near": 3.0, "grow": 0.15})
	for q in 7:
		var o2 = from + sd * (q - 3) * 0.3
		var spread = sd * (q - 3) * 0.04
		var bend = randf_range(-0.4, 0.4)
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return o2 + (d + spread) * u * 30.0 + Vector3.UP * bend * sin(u * PI), 12), 0.035, 0.55, MINT if q % 2 == 0 else Color(0.9, 1.0, 0.94, 0.6),
			{"delay": q * 0.01, "grow": 0.35, "flow": 12.0, "near": 2.4})
	if k == 0:
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return from + d * u * 28.0 - Vector3.UP * u * 0.8, 12)
		FutonLib.sheet(pj, pts, 1.6, 0.6, MINT, {"opacity": 0.25, "lines": 6.0, "grow": 0.3, "near": 8.0, "hint": Vector3.UP, "twin": false})
		var g = FutonLib.floor_at(c.global_position)
		FutonLib.scour(pj, g + d * 1.0, d, 26.0, 3.0, 1.8, 0)
		for q in 3:
			FutonLib.scour(pj, g + d * (6.0 + q * 7.0), d, 4.0, 3.0, 2.0, 2, Color(-1, 0, 0), {"delay": 0.05 + q * 0.06})


# ================================================================== 11. Fūton: Shinkū Reppū: Hitoe
## Kaynak (anime görsel yok; Storm Generations): geri sıçrarken vakum küresi, hedef sersemken vakum dalgası. Tasarım:
## sıçrayışta ayak altından geri savrulan toz + yarık izi → sıkı, ters dönen iki halkayla sarılmış küçük vakum küresi →
## çarpınca önce içe çöken (çizgiler merkeze akar), sonra patlayan basınç (sersemletme okunur) → dalgada üç DİKEY hilal
## art arda uçar, arkasında dar yelpaze çizgileri ve dik soluk perde.
static func futon_shinku_reppu_hitoe(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.95)
	var id = "futon_shinku_reppu_hitoe"
	var tt = pj.tg(c, t, 26.0)
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	if c is CharacterBody3D:
		c.velocity = -d * 10.0 + Vector3.UP * 5.5   # geri sıçrayış
	_hitoe_kick(pj, pj.gp(c.global_position), d)
	Sfx.play("wind", c.global_position, 1.3)
	pj.after(0.14, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var from = pj._mouth_pos(cc) + cc.face_dir() * 0.5
		var core = Node3D.new()
		var pr = pj.shot(cc, from, pj.aim_at(cc, x, from), 44.0, core, pj.inf(cc, id, 0.8, {"knock": 3.0, "kind": "heavy", "element": "fuuton", "stun": 1.3, "hitstop": 0.05}), null, false, 1.2, func(p, _h):
			_hitoe_implode(pj, p))
		pr.radius = 0.7
		_hitoe_ball(pj, core, pr))
	pj.after(0.6, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var from = pj._mouth_pos(cc)
		var dd = pj.aim_at(cc, x, from)
		var sd = dd.cross(Vector3.UP).normalized()
		pj.anim(cc, "cast", 1.6)
		for k in 3:
			pj.after(k * 0.07, func():
				var c2 = cw.get_ref()
				if c2 == null or not pj.live(c2):
					return
				var core = Node3D.new()
				var pr = pj.shot(c2, from, dd, 46.0, core, pj.inf(c2, id, 0.5, {"knock": 6.0, "kind": "heavy", "element": "fuuton", "bleed": 2.0}), null, true, 0.75)
				pr.radius = 1.3
				_hitoe_wave(pj, core, from, dd, sd, k))
		Sfx.play("wind", from, 0.9))


static func _hitoe_kick(pj: PathJutsu, g: Vector3, d: Vector3) -> void:
	FutonLib.bits(pj, g + Vector3.UP * 0.15, 12, "puff", {"cols": FutonLib.dust_cols(g, 0.75), "size": 0.5, "radius": 0.4, "dir": (-d + Vector3.UP * 0.6).normalized(), "spread": 35.0,
		"vmin": 2.0, "vmax": 5.0, "life": 0.9, "damp": 2.0, "g": Vector3(0, -0.5, 0)})
	FutonLib.scour(pj, g, -d, 3.0, 1.4, 1.4, 0)
	var sd = FutonLib.side_of(d)
	for q in 3:
		var o = sd * (q - 1) * 0.35
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return g + o + Vector3.UP * (0.2 + sin(u * PI) * 0.6) - d * u * 2.4, 8), 0.03, 0.3, AIR, {"grow": 0.4, "flow": 10.0, "near": 1.6})


static func _hitoe_ball(pj: PathJutsu, core: Node3D, pr: Projectile) -> void:
	FutonLib.orb(pj, Vector3.ZERO, 0.6, AIR, {"parent": core, "tear": 0.25, "near": 2.0})
	var spinner = Node3D.new()
	core.add_child(spinner)
	for q in 2:
		var hold = Node3D.new()
		spinner.add_child(hold)
		hold.rotation = Vector3(0.5 if q == 0 else -0.5, 0.0, 0.0)
		var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 0.85, 0.85, 0.0, 0.0, q * PI, 0.8, 16)
		FutonLib.fixed(pj, pts, 0.035, "line", WHITE if q == 0 else CYAN, {"parent": hold, "flow": 12.0, "near": 1.6})
		_spin(hold, "rotation:y", 0.1, 14, 1.0 if q == 0 else -1.0)
	FutonLib.follow(pj, pr, 0.45, 9, PALE, {"kind": "sheet", "opacity": 0.3, "lines": 3.0, "near": 4.0})


static func _hitoe_implode(pj: PathJutsu, p: Vector3) -> void:
	FutonLib.warp(pj, p, 1.8, 0.15, 0.16, {"ring": false, "power": 1.5, "swirl": 1.2, "fade_from": 0.8})
	for q in 8:
		var w = Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized()
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return p + w * lerpf(2.0, 0.2, u), 6), 0.03, 0.16, AIR, {"grow": 0.6, "flow": 14.0, "near": 1.4})
	FutonLib.warp(pj, p, 0.2, 2.6, 0.3, {"power": 1.4, "band": 0.14, "delay": 0.15})
	for q in 6:
		var w2 = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return p + w2 * lerpf(0.3, 2.2, u), 6), 0.035, 0.25, WHITE, {"delay": 0.16, "grow": 0.3, "flow": 12.0, "near": 1.4})


static func _hitoe_wave(pj: PathJutsu, core: Node3D, from: Vector3, dd: Vector3, sd: Vector3, k: int) -> void:
	FutonLib.blade(pj, Vector3.ZERO, FutonLib.blade_basis(Vector3.FORWARD, Vector3.RIGHT), 2.4 + k * 0.4, 0.75, AIR, {"parent": core, "thick": 0.16, "jag": 0.4, "wisp": 1.2, "near": 3.0, "grow": 0.15})
	for q in 5:
		var o2 = from + sd * (q - 2) * 0.22
		var spread = sd * (q - 2) * 0.025
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return o2 + (dd + spread) * u * 32.0 + Vector3.UP * 0.3 * sin(u * PI * 2.0 + q), 12), 0.03, 0.5, MINT,
			{"delay": q * 0.012, "grow": 0.35, "flow": 12.0, "near": 2.4})
	if k == 0:
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return from + dd * u * 26.0, 10)
		FutonLib.sheet(pj, pts, 1.0, 0.5, PALE, {"opacity": 0.24, "lines": 4.0, "grow": 0.3, "near": 7.0, "hint": sd, "twin": false})


# ================================================================== 12. Fūma Kaze Guruma (Rüzgâr Çarkı)
## Kaynak yok, tasarım: kıvrık dört kanatlı dev çelik fūma shuriken, kanat uçlarından kopan sarmal akım çizgileri ve
## yörüngesinde kalan soluk hava şeridi; kullanıcının çevresinde 7,6 m'de dönen kesik yay çizgileri; yörünge altında
## savrulan toz, ara ara kum / ot savruntusu.
static func fuma_kaze_guruma(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_guruma_ring(pj, c)
	pj.every(3.0, 0.3, func(_i, _k):
		if pj.live(c):
			_guruma_sand(pj, pj.gp(c.global_position) + Vector3.UP * 0.3, 7.0), Callable())
	var sh = _fuma_body(2.2)
	pj.get_tree().current_scene.add_child(sh)
	sh.global_position = c.global_position + Vector3(8.0, 1.4, 0.0)   # ilk karedeki yörünge noktası (iz dünya merkezinden başlamasın)
	_guruma_wrap(pj, sh)
	var hit_t = {}
	pj.every(3.0, 1.0 / 30.0, func(i, _k):
		if not is_instance_valid(c):
			return
		var a = i * 0.16
		sh.global_position = c.global_position + Vector3(cos(a) * 8.0, 1.4, sin(a) * 8.0)
		sh.rotation.y += 0.7
		for e in pj.enemies_near(c, sh.global_position, 2.2):
			var key = e.get_instance_id()
			if Time.get_ticks_msec() - int(hit_t.get(key, 0)) > 600:
				hit_t[key] = Time.get_ticks_msec()
				pj.hit(c, e.global_position + Vector3.UP, 1.0, pj.inf(c, "fuma_kaze_guruma", 0.6, {"knock": 9.0, "kind": "heavy", "element": "fuuton"}))
		if i % 4 == 0:
			_guruma_dust(pj, pj.gp(sh.global_position)), func():
		sh.queue_free())
	Sfx.play("wind", c.global_position, 0.8)


## Dev fūma shuriken: göbek + dört kıvrık kanat (düz, Y ekseninde döner). Yarıçap ≈ 1,45 × size
static func _fuma_body(size: float) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(0.5, 0.14, 0.5), Color(0.24, 0.22, 0.2), Vector3.ZERO, 12)
	b.add("cyl", Vector3.ZERO, Vector3(0.16, 0.18, 0.16), Color(0.8, 0.8, 0.84), Vector3.ZERO, 8)
	var xf = Transform3D(Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)), Vector3.ZERO)
	for k in 4:
		var a0 = TAU * k / 4.0
		var outline = PackedVector2Array()
		var n = 8
		for s in n + 1:
			var u = float(s) / n
			var r = lerpf(0.22, 1.45, u)
			var ac = a0 + 0.6 * pow(u, 1.5)
			var wa = (0.36 * (1.0 - u) + 0.015) / r
			outline.append(Vector2(cos(ac + wa), sin(ac + wa)) * r)
		for s in range(n, -1, -1):
			var u = float(s) / n
			var r = lerpf(0.22, 1.45, u)
			var ac = a0 + 0.6 * pow(u, 1.5)
			var wa = (0.36 * (1.0 - u) + 0.015) / r
			outline.append(Vector2(cos(ac - wa), sin(ac - wa)) * r)
		b.add_slab(outline, 0.06, STEEL, xf, Callable(), STEEL.darkened(0.4))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	root.add_child(mi)
	mi.scale = Vector3.ONE * size
	return root


## Kanat uçlarından kopan sarmal çizgiler (shuriken döndükçe uçlar döner) + yörüngede kalan soluk şerit
static func _guruma_wrap(pj: PathJutsu, sh: Node3D) -> void:
	var tip = 1.45 * 2.2
	for q in 4:
		var a = TAU * q / 4.0
		FutonLib.follow(pj, sh, 0.05, 8, AIR, {"offset": Vector3(cos(a), 0.0, sin(a)) * tip, "flow": 10.0, "near": 3.0})
	FutonLib.follow(pj, sh, 1.2, 14, PALE, {"kind": "sheet", "opacity": 0.24, "lines": 4.0, "near": 7.0})


static func _guruma_ring(pj: PathJutsu, c: Node3D) -> void:
	var root = Node3D.new()
	c.add_child(root)
	root.position = Vector3.UP * 1.2
	for q in 5:
		var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 7.6, 7.6, -0.2 + q * 0.1, 0.2 - q * 0.1, TAU * q / 5.0, 0.16, 14)
		FutonLib.fixed(pj, pts, 0.05, "line", AIR if q % 2 == 0 else PALE, {"parent": root, "flow": 9.0, "near": 3.0})
	var band = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 7.6, 7.6, 0.0, 0.0, 0.3, 0.3, 20)
	FutonLib.fixed(pj, band, 0.5, "sheet", PALE, {"parent": root, "opacity": 0.2, "lines": 3.0, "near": 7.0, "hint": Vector3.UP, "twin": false})
	var tw = root.create_tween()
	tw.tween_property(root, "rotation:y", TAU * 6.0, 3.0)
	tw.tween_callback(root.queue_free)


static func _guruma_sand(pj: PathJutsu, g: Vector3, r: float) -> void:
	for q in 3:
		var a = randf() * TAU
		var p = FutonLib.floor_at(g + Vector3(cos(a), 0.0, sin(a)) * r * randf_range(0.8, 1.05))
		var tg_dir = Vector3(-sin(a), 0.0, cos(a))
		FutonLib.bits(pj, p + Vector3.UP * 0.2, 4, "puff", {"cols": FutonLib.dust_cols(p, 0.6), "size": 0.6, "radius": 0.5, "dir": (tg_dir + Vector3.UP * 0.3).normalized(), "spread": 30.0,
			"vmin": 3.0, "vmax": 6.0, "life": 0.9, "damp": 2.0})
		if q == 0:
			FutonLib.scour(pj, p, tg_dir, 3.0, 1.2, 1.4, 0)


static func _guruma_dust(pj: PathJutsu, g: Vector3) -> void:
	FutonLib.bits(pj, g + Vector3.UP * 0.15, 5, "puff", {"cols": FutonLib.dust_cols(g, 0.7), "size": 0.55, "radius": 0.8, "dir": Vector3.UP, "spread": 70.0,
		"vmin": 1.5, "vmax": 3.5, "radial": 4.0, "life": 0.8, "damp": 2.0})
	var kind = "grass" if FutonLib.has_leaves(g) else "grit"
	FutonLib.bits(pj, g + Vector3.UP * 0.3, 4, kind, {"cols": FutonLib.leaf_cols(g) if kind == "grass" else FutonLib.dust_cols(g, 1.0), "size": 0.13, "radius": 0.6,
		"spread": 60.0, "vmin": 3.0, "vmax": 6.0, "radial": 4.0, "g": Vector3(0, -4.0, 0), "life": 1.0})


# ================================================================== 13. Fūton: Shinkūgyoku (Vakum Saçması)
## Ref: Shinkū ile aynı vakum keseleri ama çok sayıda ve küçük. Görünüş: nefeste ağız önünde tek basınç halkası →
## dokuz küçük, kenarı kopuksuz sıkı hava boncuğu saçılır; arkalarında uzun ince iğne izi; her saplanmada küçük delik
## halkası ve hedefin içinden geçip devam eden iğne çizgileri.
static func futon_shinkugyoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 26.0)
	if pj.live(c):
		var mo = pj._mouth_pos(c)
		FutonLib.warp(pj, mo + c.face_dir() * 0.4, 0.1, 1.1, 0.35, {"bill": false, "basis": _face_basis(c.face_dir()), "power": 1.3, "band": 0.2})
	for k in 9:
		pj.after(0.05 + k * 0.03, func():
			if not pj.live(c):
				return
			var from = pj._mouth_pos(c)
			var dk = pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.22, 0.22))
			dk = (dk + Vector3.UP * randf_range(-0.05, 0.05)).normalized()
			var core = Node3D.new()
			var pr = pj.shot(c, from, dk, 50.0, core, pj.inf(c, "futon_shinkugyoku", 0.28, {"knock": 2.0, "kind": "light", "element": "fuuton", "bleed": 2.0}), null, true, 0.8, func(pp, _h):
				_pellet_hit(pj, pp, dk))
			pr.radius = 0.55
			FutonLib.orb(pj, Vector3.ZERO, 0.22, AIR, {"parent": core, "tear": 0.0, "near": 1.2})
			FutonLib.follow(pj, pr, 0.022, 8, AIR, {"flow": 12.0, "near": 1.5})
			FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return from + dk * u * 1.6, 5), 0.02, 0.12, AIR, {"grow": 0.4, "flow": 14.0, "near": 1.0}))
	Sfx.play("wind", c.global_position, 1.4)


static func _pellet_hit(pj: PathJutsu, pp: Vector3, dk: Vector3) -> void:
	FutonLib.warp(pj, pp, 0.1, 0.7, 0.15, {"power": 1.2, "band": 0.2})
	var sd = FutonLib.side_of(dk)
	for q in 3:
		var o = sd * (q - 1) * 0.08 + Vector3.UP * randf_range(-0.08, 0.08)
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return pp + o + dk * u * 1.6, 5), 0.018, 0.14, WHITE, {"grow": 0.35, "flow": 14.0, "near": 1.0})


# ================================================================== 14. Mini Rasenshuriken
## Ref: avuç önünde küçük, soluk camgöbeği-beyaz parlayan top. Görünüş: avuca sarmal çizgilerle akan chakra, küçük
## Rasengan belirir → avuç boyu Rasenshuriken: sarmal kollu mavi çekirdek + dört kıvrık beyaz kanatlı dönen disk,
## arkasında kanat ucu izleri → çarpınca kabuk değil: hedefi saran yüzlerce mikro rüzgâr kesiği (küçük hilaller),
## eğik dönen ince halkalar, büken basınç küresi, ortada sönen çekirdek; tabanda dışa kaçan toz, ışınsal iz, kaya.
static func mini_rasenshuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 26.0)
	var from = pj.hand_pos(c, true)
	_mini_gather(pj, from)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var core = _mini_body(pj)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 28.0, core, pj.inf(c, "mini_rasenshuriken", 0.6, {"knock": 4.0, "kind": "heavy", "element": "fuuton"}), tt, false, 1.6, func(p, _h):
			_mini_burst(pj, p, 3.0, 0.7)
			pj.every(0.8, 0.1, func(_i, _k):
				pj.hit(c, p, 3.0, pj.inf(c, "mini_rasenshuriken", 0.2, {"knock": 0.0, "kind": "light", "element": "fuuton", "bleed": 1.0})), Callable())
			pj.shake(0.5))
		pr.homing_turn = 3.0
		FutonLib.follow(pj, pr, 0.3, 10, CYAN, {"kind": "sheet", "opacity": 0.28, "lines": 3.0, "near": 3.0})
		for q in 2:
			FutonLib.follow(pj, pr, 0.025, 10, AIR, {"offset": Vector3(0.6, 0, 0).rotated(Vector3.FORWARD, PI * q), "spin": 22.0, "flow": 10.0, "near": 1.6}))
	Sfx.play("wind", from, 1.6, 0.5)


static func _mini_gather(pj: PathJutsu, from: Vector3) -> void:
	for q in 8:
		var pts = FutonLib.helix_pts(from, Vector3.UP, 1.2, 0.05, 0.6, 0.0, TAU * q / 8.0, 0.8, 14)
		FutonLib.line(pj, pts, 0.025, 0.35, CYAN if q % 2 == 0 else AIR, {"delay": q * 0.02, "grow": 0.6, "flow": 10.0, "near": 1.0})
	_rasengan(pj, null, 0.14, 0.35, from)


static func _mini_body(pj: PathJutsu) -> Node3D:
	var root = Node3D.new()
	_rasengan(pj, root, 0.15, 0.0)
	var spinner = Node3D.new()
	root.add_child(spinner)
	var disc = FutonLib.gi(_plane(), _smat("shuri", SHURI_SHADER))
	spinner.add_child(disc)
	disc.scale = Vector3(0.2, 1.0, 0.2)
	disc.create_tween().tween_property(disc, "scale", Vector3(1.3, 1.0, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spin(spinner, "rotation:y", 0.09, 24)
	return root


## Genişleme (hasar ayrı): mikro kesikler, eğik dönen halkalar, basınç küresi, çekirdek, taban tozu
static func _mini_burst(pj: PathJutsu, pos: Vector3, rad: float, hold: float) -> void:
	var life = 0.3 + hold + 0.45
	FutonLib.warp(pj, pos, 0.3, rad, life, {"ring": false, "power": 1.2, "swirl": 1.4, "grow": 0.25, "fade_from": 0.7})
	FutonLib.warp(pj, pos, 0.3, rad * 1.8, 0.4, {"power": 1.5, "band": 0.12})
	for q in 26:
		var p = pos + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * rad * randf_range(0.2, 0.95)
		var fwd = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var nrm = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		FutonLib.blade(pj, p, FutonLib.blade_basis(fwd, nrm), randf_range(0.5, 0.9), 0.25, WHITE if q % 3 == 0 else AIR, {"delay": 0.05 + randf() * hold, "thick": 0.12, "wisp": 1.0, "near": 2.4})
	for q in 3:
		var hold_n = Node3D.new()
		FutonLib.put(pj, hold_n, pos)
		hold_n.rotation = Vector3(randf_range(-0.9, 0.9), randf() * TAU, randf_range(-0.9, 0.9))
		var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, rad * 0.95, rad * 0.95, 0.0, 0.0, randf() * TAU, 0.85, 26)
		FutonLib.line(pj, pts, 0.04, 0.3 + hold, AIR, {"parent": hold_n, "grow": 0.25, "flow": 12.0, "near": 3.0})
		_spin(hold_n, "rotation:y", 0.25, 6)
		FutonLib.kill(pj, life, hold_n)
	var core = _rasengan(pj, null, 0.4, 0.0, pos)
	var ct = core.create_tween()
	ct.tween_interval(0.3 + hold)
	ct.tween_property(core, "scale", Vector3.ONE * 0.05, 0.3)
	ct.tween_callback(core.queue_free)
	_flash(pj, pos, CYAN, 6.0, rad * 4.0, 0.6)
	var g = FutonLib.floor_at(pos)
	if pos.y - g.y < rad + 1.0:
		FutonLib.scour(pj, g, Vector3.FORWARD, rad * 2.6, rad * 2.6, 2.4, 1)
		FutonLib.chunks(pj, g, 8, 10.0, FutonLib.ground_col(g).darkened(0.35), 0.3)
		FutonLib.bits(pj, g + Vector3.UP * 0.2, 16, "puff", {"cols": FutonLib.dust_cols(g, 0.75), "size": 0.7, "radius": rad * 0.9, "dir": Vector3.UP, "spread": 40.0,
			"vmin": 1.0, "vmax": 3.0, "radial": 10.0, "life": 1.3, "damp": 2.0})
	pj.shake(1.0)
	Sfx.play("wind", pos, 0.6)
	Sfx.play("rasengan", pos, 0.7)


# ================================================================== 15. Fūton: Mugen Sajin Daitoppa (Sonsuz Kum Bulutu Atılımı)
## Kanon: Ōnoki dönemi Kazahana / Iwa tekniği — rüzgâra karışan kum-toz ile ileri yuvarlanan dev bir toz dalgası, rakibi
## savurur ve görüşünü kapatır (kör eder). Kaynak görsel yok, tasarım: ağızdan çıkan kum taneleri → yere yakın yuvarlanan
## iki tonlu cel kum bulutu cephesi (giderek genişler) + kumlu yarı saydam perdeler + ince kum çizgileri; yolda kalkan
## çakıl / küçük taşlar, yerde uzun süpürülmüş kum izi; geride yavaşça çöken, görüşü kapatan kum pusu.
static func futon_mugen_sajin_daitoppa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var mo = Jutsu._mouth(c)
	_sajin_wave(pj, c, mo, d)
	# eski rüzgâr hamlelerinin saç/kumaş savurması (akış + koni)
	var hand_o = c.global_position + Vector3.UP * 1.2 + d
	Dangle.gust(hand_o + d * 9.0, d * 28.0, 10.8, 0.7)
	pj.after(0.27, func(): Dangle.gust(hand_o + d * 9.0, d * 28.0, 10.8, 0.7))
	Dangle.gust(mo + d * 12.0, d * 28.0, 14.4, 0.7)
	for e in pj.enemies_near(c, c.global_position + d * 12.0, 13.0):
		var v = e.global_position - c.global_position
		v.y = 0
		if v.normalized().dot(d) > 0.4:
			pj.hit(c, e.global_position + Vector3.UP, 1.0, pj.inf(c, "futon_mugen_sajin_daitoppa", 1.0, {"knock": 26.0, "launch": 5.0, "kind": "heavy", "element": "fuuton"}))
			if e.has_method("lose_target"):
				e.lose_target(2.0)
	Sfx.play("wind", c.global_position, 0.5)


static func _sajin_wave(pj: PathJutsu, c: Node3D, mo: Vector3, d: Vector3) -> void:
	var side = FutonLib.side_of(d)
	var base = c.global_position
	var sand_cols = [Color(SAND.r, SAND.g, SAND.b, 0.0), Color(SAND_L.r, SAND_L.g, SAND_L.b, 0.9), Color(SAND.r, SAND.g, SAND.b, 0.85), Color(SAND_D.r, SAND_D.g, SAND_D.b, 0.0)]
	# ağızdan saçılan kum taneleri
	FutonLib.bits(pj, mo + d * 0.4, 30, "grit", {"cols": [SAND_L, SAND, Color(SAND_D.r, SAND_D.g, SAND_D.b, 0.0)], "size": 0.07, "radius": 0.2, "dir": d, "spread": 18.0,
		"vmin": 18.0, "vmax": 30.0, "g": Vector3(0, -3.0, 0), "life": 0.8, "damp": 0.5})
	# yuvarlanan kum bulutu cephesi: yere yakın, giderek genişleyen iki tonlu topaklar
	for k in 8:
		var p = c.global_position + d * (2.0 + k * 2.6)
		var g = FutonLib.floor_at(p)
		var w = 1.0 + k * 0.7
		var bx = Basis(side, Vector3.UP, side.cross(Vector3.UP))
		var ld = bx.inverse() * (d + Vector3.UP * 0.25).normalized()   # yayıcı döndürülmüş: yön yerel uzayda
		var ld2 = bx.inverse() * (d + Vector3.UP * 0.4).normalized()
		pj.after(k * 0.06, func():
			FutonLib.bits(pj, g + Vector3.UP * (0.6 + k * 0.12), 10, "puff", {"cols": sand_cols, "size": 1.4 + k * 0.15, "box": Vector3(w, 0.4, 0.6), "basis": bx,
				"dir": ld, "spread": 20.0, "vmin": 8.0, "vmax": 16.0, "g": Vector3(0, -0.5, 0), "damp": 2.2, "life": 1.4, "burst": 0.9, "spin": 120.0})
			FutonLib.bits(pj, g + Vector3.UP * 0.4, 8, "grit", {"cols": [SAND_D, SAND, Color(SAND.r, SAND.g, SAND.b, 0.0)], "size": 0.09, "box": Vector3(w, 0.3, 0.5), "basis": bx,
				"dir": ld2, "spread": 25.0, "vmin": 8.0, "vmax": 15.0, "g": Vector3(0, -6.0, 0), "life": 1.0, "turb": false}))
	# kumlu perdeler ve ince kum çizgileri
	for q in 5:
		var o = side * (q - 2) * 1.5
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return mo + o * (0.2 + u) + d * u * 24.0 - Vector3.UP * u * 1.0, 14)
		FutonLib.sheet(pj, pts, 1.2, 0.9, Color(0.9, 0.78, 0.55, 0.8), {"delay": q * 0.03, "opacity": 0.45, "lines": 5.0, "grow": 0.35, "near": 8.0, "flow": 4.0})
	for q in 10:
		var o2 = side * randf_range(-3.5, 3.5) + Vector3.UP * randf_range(-0.9, 0.5)
		var wob = randf_range(-0.6, 0.6)
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return mo + o2 * u + d * u * 22.0 + side * wob * sin(u * PI), 12), 0.035, 0.6, SAND_L,
			{"delay": 0.03 + q * 0.02, "grow": 0.35, "flow": 10.0, "near": 3.0})
	# zemin: uzun kum izi, kalkan çakıl
	var g0 = FutonLib.floor_at(c.global_position)
	FutonLib.scour(pj, g0 + d * 1.0, d, 24.0, 9.0, 3.0, 0, Color(SAND_D.r, SAND_D.g, SAND_D.b, 0.7))
	FutonLib.chunks(pj, FutonLib.floor_at(c.global_position + d * 8.0), 6, 9.0, SAND_D.darkened(0.2), 0.18, d + Vector3.UP * 0.6)
	# geride yavaşça çöken, görüşü kapatan kum pusu
	pj.after(0.5, func():
		for k in 4:
			var gh = FutonLib.floor_at(base + d * (6.0 + k * 4.0))
			FutonLib.bits(pj, gh + Vector3.UP * 1.0, 8, "puff", {"cols": [Color(SAND.r, SAND.g, SAND.b, 0.0), Color(SAND_L.r, SAND_L.g, SAND_L.b, 0.55), Color(SAND.r, SAND.g, SAND.b, 0.0)],
				"size": 2.2, "box": Vector3(3.0 + k, 0.8, 2.0), "dir": d, "spread": 60.0, "vmin": 0.5, "vmax": 1.5, "g": Vector3(0, -0.15, 0), "damp": 1.0, "life": 2.6, "burst": 0.6, "spin": 30.0}))
