class_name WaterWaves
extends Node
## Su yüzeyi tepkisi (çevre sistemi, jutsuya özel efekt değil): suya değen her çarpma / patlama / alan vuruşu, suya inen dev beden,
## yüksekten düşüş ve su üstünde adım yüzeyde halka dalgaları açar. Boyut çarpmanın yarıçapı + gücüyle ölçeklenir.
##  - Dalga alanı: en çok 64 halka bir float dokuya (g_ripples) yazılır; tüm su gölgelendiricileri (deniz, göl, kanal, dere, gölet,
##    şelale havuzu) water_ripples.gdshaderinc ile aynı alanı örnekler: yüzey eğimi (ışık), köpüklü tepe çizgisi, çarpma çukuru.
##  - Büyük çarpma (R >= 4, açık su): yerinde ince bölünmüş bir "kabarma" yaması dalgaları gerçekten yükseltir (3B halkalar).
##  - Sıçrama: taç biçiminde fırlayan damlalar (+ büyükte orta sütun); ateş suya değerse buhar tütsüsü. Hepsi tek MultiMesh.
## Çağrılar: WorldDamage.impact (tüm jutsu / vuruş alanları), GroundMarks.ripple (su üstünde adım), yer efekti yardımcıları
## (çatlak / yanık / toz suya düşerse yer izi yerine su tepkisi: ground_on_water), kendi _process'inde düşüş + dev beden taraması.
## Yapay zekâ ve oyuncu aynı: hepsi dünyadaki gerçek çarpma yerinden gelir.

const MAX_RIPPLES := 64
const MAX_DROPS := 1400
const MAX_PATCHES := 3

static var inst: WaterWaves
static var enabled := true   # ölçüm için kapatılabilir (dbg_water_waves A/B FPS)
static var ripples: Array = []   # [x, y(su), z, yaş, R, ömür]

var _img: Image
var _tex: ImageTexture
var _last_n := -1
# damlalar / buhar: paket diziler (GDScript sözlükten hızlı)
var _dp := PackedVector3Array()
var _dv := PackedVector3Array()
var _dl := PackedFloat32Array()   # kalan ömür
var _dl0 := PackedFloat32Array()  # toplam ömür
var _ds := PackedFloat32Array()   # boy
var _dy := PackedFloat32Array()   # su yüzeyi (altına düşen damla söner)
var _dk := PackedByteArray()      # 0 damla, 1 buhar
var _mm_drop: MultiMeshInstance3D
var _mm_steam: MultiMeshInstance3D
var _patches: Array = []          # [MeshInstance3D, kalan ömür]
var _scan_t := 0.0
var _track := {}                  # fighter id -> [son konum, son dikey hız, son halka zamanı]
var _now := 0.0


static func _ensure() -> WaterWaves:
	if inst == null or not is_instance_valid(inst):
		var sc = VFX.scene()
		if sc == null:
			return null
		inst = WaterWaves.new()
		inst.name = "WaterWaves"
		sc.add_child.call_deferred(inst)
	return inst


## Bu noktada açık su yüzeyi var mı: varsa su y'si, yoksa NAN. margin: nokta suyun en çok bu kadar üstünde olabilir.
## Köprü / iskele / kaya üstü (zemin sudan yüksek) ve iç mekân sayılmaz. Oyuncunun su üstünde yürüme ölçütüyle aynı (su > arazi + 0.1).
static func surface_at(p: Vector3, margin := 1.5) -> float:
	if Game.world == null or (Interiors.inst and Interiors.inst.inside != ""):
		return NAN
	var terr = Game.terrain_height(p.x, p.z)
	var wl = Game.water_level(p.x, p.z, terr)
	if wl == -INF or wl <= terr + 0.1:
		return NAN
	if p.y > wl + margin or p.y < terr - 0.5:
		return NAN
	if p.y > wl + 0.7 and Game.jutsu_floor_at(p).y > wl + 0.15:   # köprü tabliyesi / iskele / kaya üstü: su değil
		return NAN
	return wl


## Halka ekle: at = su yüzeyinde nokta, R = dalga boyutu (m; adım 0.25, yumruk ~0.6, Katon topu ~3, bijū-dama 20+)
static func add(at: Vector3, R: float) -> void:
	if not enabled:
		return
	R = clampf(R, 0.15, 45.0)
	for r in ripples:
		if float(r[3]) < 0.2 and Vector2(r[0] - at.x, r[2] - at.z).length() < maxf(0.8, R * 0.4):
			r[4] = maxf(float(r[4]), R)   # aynı çarpmanın tekrar eden kareleri birleşir
			r[5] = 1.5 + sqrt(float(r[4])) * 1.5
			return
	ripples.append([at.x, at.y, at.z, 0.0, R, 1.5 + sqrt(R) * 1.5])
	if ripples.size() > MAX_RIPPLES:
		# en az kalanı (küçük ve sönmekte olan) at
		var wi = 0
		var wv = INF
		for i in ripples.size():
			var v = float(ripples[i][4]) * (float(ripples[i][5]) - float(ripples[i][3]))
			if v < wv:
				wv = v
				wi = i
		ripples.remove_at(wi)
	var w = _ensure()
	if w and R >= 4.0 and absf(at.y) < 0.5 and Game.terrain_height(at.x, at.z) < -0.5:   # kabarma yaması yalnız açık suda (deniz / göl): kanal kıyısına taşmasın
		w._patch.call_deferred(at, R)


## Jutsu / vuruş çarpması (WorldDamage.impact her alan vuruşunda çağırır)
static func impact(pos: Vector3, radius: float, info: Dictionary) -> void:
	var wl = surface_at(pos, 1.0 + radius * 0.6)
	if is_nan(wl):
		return
	var dmg = float(info.get("dmg", 0.0))
	var heavy = String(info.get("kind", "")) == "heavy"
	var R = radius * (0.55 + clampf(dmg / 220.0, 0.0, 1.6) * 0.45) * (1.15 if heavy else 0.85)
	var above = maxf(0.0, pos.y - wl)
	R *= clampf(1.0 - above / (radius * 0.6 + 2.0) * 0.6, 0.35, 1.0)   # suyun üstünde patlayan daha az iter
	var el = String(info.get("element", ""))
	var kind = "fire" if (el in ["katon", "yoton", "futton", "shakuton", "enton"] or info.has("burn")) else "water"
	react(Vector3(pos.x, wl, pos.z), R, kind)


## Halka + sıçrama / buhar
static func react(at: Vector3, R: float, kind := "water") -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	var fresh = true
	for r in ripples:
		if float(r[3]) < 0.25 and Vector2(r[0] - at.x, r[2] - at.z).length() < maxf(0.8, R * 0.4) and float(r[4]) >= R * 0.8:
			fresh = false   # aynı çarpmanın tekrarı: yeni sıçrama yok
			break
	add(at, R)
	if not fresh:
		return
	var w = _ensure()
	if w == null:
		return
	if kind == "fire":
		w._steam(at, R)
		w._splash(at, R * 0.45)
	elif kind != "quiet":
		w._splash(at, R)


## Yer efekti yardımcıları için: nokta sudaysa yer izi (çatlak, yanık, toz, çukur) koyma, yerine su tepkisi ver → true.
## kind: "rock" (taş / çatlak: sıçrama), "fire" (yanık: buhar), "dust" (toz: hafif serpinti), "decal" (yalnız halka)
static func ground_on_water(p: Vector3, r := 1.0, kind := "rock") -> bool:
	var wl = surface_at(p, 1.2)
	if is_nan(wl):
		return false
	var at = Vector3(p.x, wl, p.z)
	for rr in ripples:   # yer efektleri art arda çağrılır (alev izi, toz halkası): yakında taze halka varsa yenisi açılmaz
		if float(rr[3]) < 0.6 and Vector2(rr[0] - at.x, rr[2] - at.z).length() < maxf(2.5, r):
			return true
	match kind:
		"fire":
			react(at, r * 0.6, "fire")
		"dust":
			react(at, r * 0.35, "water")
		"decal":
			react(at, r * 0.5, "quiet")
		_:
			react(at, r * 0.6, "water")
	return true


# ------------------------------------------------------------------ düğüm
func _ready() -> void:
	process_priority = 50
	_img = Image.create(MAX_RIPPLES, 1, false, Image.FORMAT_RGBAF)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("g_ripples", _tex)
	_mm_drop = _make_mm(_drop_mat(), 6, 4)
	_mm_steam = _make_mm(_steam_mat(), 10, 6)
	tree_exiting.connect(func():
		RenderingServer.global_shader_parameter_set("g_ripple_n", 0.0)
		if inst == self:
			inst = null)


func _make_mm(mat: Material, seg: int, rings: int) -> MultiMeshInstance3D:
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = seg
	sm.rings = rings
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sm
	mm.instance_count = MAX_DROPS
	mm.visible_instance_count = 0
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1e5, -1e4, -1e5), Vector3(2e5, 2e4, 2e5))
	add_child(mi)
	return mi


func _process(dt: float) -> void:
	_now += dt
	# halkalar yaşlanır
	var i := 0
	while i < ripples.size():
		var r = ripples[i]
		r[3] = float(r[3]) + dt
		if float(r[3]) >= float(r[5]):
			ripples.remove_at(i)
		else:
			i += 1
	_write()
	_sim(dt)
	_tick_patches(dt)
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.1
		_scan_bodies()


func _write() -> void:
	var n = ripples.size()
	if n == 0:
		if _last_n != 0:
			RenderingServer.global_shader_parameter_set("g_ripple_n", 0.0)
			_last_n = 0
		return
	for k in n:
		var r = ripples[k]
		_img.set_pixel(k, 0, Color(r[0], r[2], r[3], r[4]))
	_tex.update(_img)
	if n != _last_n:
		RenderingServer.global_shader_parameter_set("g_ripple_n", float(n))
		_last_n = n


# ------------------------------------------------------------------ sıçrama + buhar
func _emit(p: Vector3, v: Vector3, life: float, s: float, wy: float, kind: int) -> void:
	if _dp.size() >= MAX_DROPS:
		return
	_dp.append(p)
	_dv.append(v)
	_dl.append(life)
	_dl0.append(life)
	_ds.append(s)
	_dy.append(wy)
	_dk.append(kind)


func _splash(at: Vector3, R: float) -> void:
	var cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam and cam.global_position.distance_to(at) > 260.0 + R * 6.0:
		return
	var sq = sqrt(R)
	var n = clampi(int(5 + R * 13.0), 5, 240)
	var ring = R * 0.32 + 0.08
	for k in n:
		var a = TAU * (k + randf_range(-0.4, 0.4)) / n
		var o = Vector3(cos(a), 0, sin(a))
		var col = R >= 2.5 and randf() < 0.3   # büyük çarpmada ortadan yükselen su sütunu
		var p = at + (o * randf_range(0.0, ring * 0.35) if col else o * ring * randf_range(0.7, 1.1)) + Vector3.UP * 0.05
		var up = sq * (randf_range(5.0, 8.5) if col else randf_range(2.4, 5.2)) + 0.6
		var out = sq * (randf_range(0.1, 0.6) if col else randf_range(0.8, 2.1)) + 0.3
		var s = clampf((0.045 + R * 0.028) * randf_range(0.6, 1.4), 0.03, 1.1)
		_emit(p, o * out + Vector3.UP * up, 4.0, s, at.y, 0)


func _steam(at: Vector3, R: float) -> void:
	var n = clampi(int(4 + R * 5.0), 4, 70)
	for k in n:
		var a = randf() * TAU
		var o = Vector3(cos(a), 0, sin(a))
		var p = at + o * randf_range(0.0, R * 0.55 + 0.3) + Vector3.UP * 0.1
		var s = clampf(0.35 + R * 0.22, 0.3, 5.0) * randf_range(0.6, 1.2)
		_emit(p, o * randf_range(0.2, 0.9) * (1.0 + R * 0.08) + Vector3.UP * randf_range(1.2, 2.8) * (1.0 + R * 0.05), randf_range(1.2, 2.4), s, at.y, 1)


func _sim(dt: float) -> void:
	var i := 0
	while i < _dp.size():
		var life = _dl[i] - dt
		var p = _dp[i] + _dv[i] * dt
		var dead = life <= 0.0
		if _dk[i] == 0:
			_dv[i] = _dv[i] + Vector3.DOWN * 15.0 * dt
			if p.y < _dy[i] and _dv[i].y < 0.0:
				dead = true
		else:
			_dv[i] = _dv[i] * (1.0 - 0.9 * dt)
		if dead:
			var last = _dp.size() - 1
			_dp[i] = _dp[last]; _dv[i] = _dv[last]; _dl[i] = _dl[last]; _dl0[i] = _dl0[last]
			_ds[i] = _ds[last]; _dy[i] = _dy[last]; _dk[i] = _dk[last]
			_dp.resize(last); _dv.resize(last); _dl.resize(last); _dl0.resize(last)
			_ds.resize(last); _dy.resize(last); _dk.resize(last)
			continue
		_dp[i] = p
		_dl[i] = life
		i += 1
	var nd := 0
	var ns := 0
	var mmd = _mm_drop.multimesh
	var mms = _mm_steam.multimesh
	for k in _dp.size():
		var s = _ds[k]
		if _dk[k] == 0:
			# damla hız yönünde uzar
			var v = _dv[k]
			var sp = v.length()
			var y = v / sp if sp > 0.01 else Vector3.UP
			var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
			var z = x.cross(y)
			var st = clampf(1.0 + sp * 0.08, 1.0, 2.6)
			mmd.set_instance_transform(nd, Transform3D(Basis(x * s, y * s * st, z * s), _dp[k]))
			mmd.set_instance_color(nd, Color(1, 1, 1, 0.9))
			nd += 1
		else:
			var f = 1.0 - _dl[k] / _dl0[k]
			var sc = s * (1.0 + f * 2.2)
			mms.set_instance_transform(ns, Transform3D(Basis.IDENTITY.scaled(Vector3(sc, sc * 0.8, sc)), _dp[k]))
			mms.set_instance_color(ns, Color(1, 1, 1, sin(f * PI) * 0.85))
			ns += 1
	mmd.visible_instance_count = nd
	mms.visible_instance_count = ns


# ------------------------------------------------------------------ büyük çarpma: kabaran su yaması (yalnız açık su: deniz / göl)
func _patch(at: Vector3, R: float) -> void:
	if not is_inside_tree():
		return
	if _patches.size() >= MAX_PATCHES:
		var old = _patches.pop_front()
		if is_instance_valid(old[0]):
			old[0].queue_free()
	var life = 1.5 + sqrt(R) * 1.5
	var reach = clampf((1.4 + sqrt(R) * 2.3) * life * 0.75 + R, 12.0, 150.0)
	var pm = PlaneMesh.new()
	pm.size = Vector2(reach * 2.0, reach * 2.0)
	var sub = clampi(int(reach * 2.0 / maxf(0.25, (0.32 + R * 0.17) * 0.25)), 48, 160)
	pm.subdivide_width = sub
	pm.subdivide_depth = sub
	var mi = MeshInstance3D.new()
	mi.mesh = pm
	var m = ShaderMaterial.new()
	m.shader = _patch_shader()
	m.set_shader_parameter("edge_r", reach)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-reach, -R, -reach), Vector3(reach * 2.0, R * 2.0 + 4.0, reach * 2.0))
	add_child(mi)
	mi.global_position = Vector3(at.x, at.y + 0.02, at.z)
	_patches.append([mi, life])


func _tick_patches(dt: float) -> void:
	var i := 0
	while i < _patches.size():
		_patches[i][1] = float(_patches[i][1]) - dt
		if float(_patches[i][1]) <= 0.0 or not is_instance_valid(_patches[i][0]):
			if is_instance_valid(_patches[i][0]):
				_patches[i][0].queue_free()
			_patches.remove_at(i)
		else:
			i += 1


# ------------------------------------------------------------------ bedenler: yüksekten suya düşüş, suda yürüyen dev
func _scan_bodies() -> void:
	var cam = get_viewport().get_camera_3d()
	if cam == null or ripples.size() >= MAX_RIPPLES - 4:
		return
	var cp = cam.global_position
	var seen := {}
	for f in get_tree().get_nodes_in_group("fighters"):
		if not (f is Node3D) or not is_instance_valid(f):
			continue
		var p: Vector3 = f.global_position
		if p.distance_squared_to(cp) > 220.0 * 220.0:
			continue
		var id = f.get_instance_id()
		seen[id] = true
		var tr = _track.get(id)
		if tr == null:
			_track[id] = [p, 0.0, -9.0]
			continue
		var vel: Vector3 = (p - (tr[0] as Vector3)) / 0.1
		var prev_vy: float = tr[1]
		tr[0] = p
		tr[1] = vel.y
		var h = float(f.get("height")) if f.get("height") != null else 1.8
		var terr = Game.terrain_height(p.x, p.z)
		var wl = Game.water_level(p.x, p.z, terr)
		if wl == -INF or wl <= terr + 0.1 or p.y > wl + 0.8 or p.y < wl - h:
			continue
		# yüksekten suya iniş / dalış: düşüş hızına göre sıçrama
		if prev_vy < -7.0 and vel.y > prev_vy * 0.4:
			react(Vector3(p.x, wl, p.z), clampf(-prev_vy * 0.07, 0.4, 4.0) * maxf(1.0, h / 1.8), "water")
			tr[2] = _now
			continue
		# dev beden (bijū, dev çağrı, Susanoo'lu dev): yürürken bacak bacak dalga, dururken yavaş kabarma
		if h >= 4.5:
			var spd = Vector2(vel.x, vel.z).length()
			var gap = 0.45 if spd > 1.0 else 1.6
			if _now - float(tr[2]) >= gap:
				tr[2] = _now
				react(Vector3(p.x, wl, p.z), h * (0.12 if spd > 1.0 else 0.06), "quiet" if spd < 1.0 else "water")
	if _track.size() > seen.size() + 16:
		for k in _track.keys():
			if not seen.has(k):
				_track.erase(k)


# ------------------------------------------------------------------ malzemeler
static var _flat: Dictionary = {}


## Düz renkli göl / dere suyu (eski StandardMaterial görünüşü: renk, saydamlık, parlaklık) + dalga alanı
static func flat_water_mat(col: Color) -> ShaderMaterial:
	var key = col.to_html()
	if _flat.has(key):
		return _flat[key]
	var sh = Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, specular_schlick_ggx, depth_draw_opaque;
#include "res://shaders/water_ripples.gdshaderinc"
uniform vec4 col : source_color = vec4(0.22, 0.5, 0.62, 0.82);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 rf = ripple_field(wpos.xz);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(-rf.y, 0.0, -rf.z, 0.0)).xyz);
	ALBEDO = mix(col.rgb, vec3(0.93, 0.98, 1.0), rf.w * 0.8);
	ALPHA = clamp(col.a + rf.w * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
"""
	var m = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", col)
	_flat[key] = m
	return m


static var _dmat: ShaderMaterial
static var _smat: ShaderMaterial
static var _psh: Shader


static func _drop_mat() -> ShaderMaterial:
	if _dmat == null:
		var sh = Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon, depth_draw_opaque;
void fragment() {
	// su damlası: açık mavi gövde, kenarda beyaz parıltı (Storm cel tonu)
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(vec3(0.55, 0.82, 0.96), vec3(0.96, 0.99, 1.0), step(0.55, rim) * 0.8 + step(0.5, NORMAL.y) * 0.25);
	ALBEDO = c;
	ALPHA = COLOR.a * (0.75 + rim * 0.25);
	ROUGHNESS = 0.15;
	SPECULAR = 0.8;
}
"""
		_dmat = ShaderMaterial.new()
		_dmat.shader = sh
	return _dmat


static func _steam_mat() -> ShaderMaterial:
	if _smat == null:
		var sh = Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
void fragment() {
	// buhar: kenarı yumuşak sönen beyaz tütsü (kabuk görünmesin diye bakış açısıyla incelir)
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = vec3(0.93, 0.95, 0.97);
	ALPHA = COLOR.a * pow(f, 2.2) * 0.5;
}
"""
		_smat = ShaderMaterial.new()
		_smat.shader = sh
	return _smat


static func _patch_shader() -> Shader:
	if _psh == null:
		_psh = Shader.new()
		_psh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_schlick_ggx, depth_draw_opaque;
#include "res://shaders/water_ripples.gdshaderinc"
uniform float edge_r = 40.0;
varying vec3 wp;
varying float edge;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge = 1.0 - smoothstep(0.7, 1.0, length(VERTEX.xz) / edge_r);
	VERTEX.y += ripple_field(wp.xz).x * edge;
}
void fragment() {
	vec4 f = ripple_field(wp.xz);
	vec3 n = normalize(vec3(-f.y, 1.0, -f.z));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float lift = smoothstep(0.06, 0.35, f.x * edge);
	vec3 c = mix(vec3(0.12, 0.42, 0.58), vec3(0.3, 0.7, 0.8), clamp(f.x * 0.6 + 0.4, 0.0, 1.0));
	ALBEDO = mix(c, vec3(0.95, 0.99, 1.0), f.w);
	ALPHA = clamp(max(lift * 0.92, f.w * 0.9 * edge), 0.0, 1.0);
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
}
"""
	return _psh
