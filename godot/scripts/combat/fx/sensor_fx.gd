class_name SensorFX
extends RefCounted
## Algılama tekniklerinin KENDİ görselleri + ortak algılama mekaniği (Combat.start_sensing). Hazır efekt yok.
##  · kanchi: yerde içten dışa yayılan ince chakra dalgaları; menzildeki her rakibin göğsünde duvar ardından görünen,
##    nabız gibi atan soluk mavi chakra çekirdeği (12 sn)
##  · kagura_shingan (Karin): kapalı gözlerle; rakiplerin chakrası sıcak, dalgalanan alev biçimli bir aura olarak görünür —
##    güçlüsü büyük ve kızıl, zayıfı küçük ve sarı (Güç farkına göre); yerde altın halka
##  · kekkai_tengai_hojin: kullanıcının çevresinde yarı saydam, altıgen ızgaralı bariyer kubbesi kalır (25 sn); içine giren
##    rakibin olduğu yerde kubbe yüzeyinde dalga halkası açılır ve işaretlenir


static func _scene() -> Node:
	return Engine.get_main_loop().current_scene


static func _unshaded(col: Color, front := false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if front:
		m.no_depth_test = true   # duvar ardından görünür (algı)
		m.render_priority = 10
	return m


static func _ring_mesh(r: float, w: float, seg := 48) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 = TAU * i / seg
		var a1 = TAU * (i + 1) / seg
		var o0 = Vector3(cos(a0), 0, sin(a0))
		var o1 = Vector3(cos(a1), 0, sin(a1))
		st.add_vertex(o0 * (r - w))
		st.add_vertex(o0 * r)
		st.add_vertex(o1 * r)
		st.add_vertex(o0 * (r - w))
		st.add_vertex(o1 * r)
		st.add_vertex(o1 * (r - w))
	return st.commit()


static func _targets(c: Node3D, r: float) -> Array:
	var out = []
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and not f.is_dead() and f.global_position.distance_to(c.global_position) <= r:
			out.append(f)
	return out


## Kanchi: zemin dalgaları + rakiplerde atan chakra çekirdeği
static func kanchi(c: Node3D, r: float, dur: float, col: Color) -> void:
	Combat.start_sensing(c, r, dur)
	var at = Vector3(c.global_position.x, Game.ground_height(c.global_position.x, c.global_position.z) + 0.06, c.global_position.z)
	for k in 3:
		var mat = _unshaded(Color(col.r, col.g, col.b, 0.55))
		var mi = MeshInstance3D.new()
		mi.mesh = _ring_mesh(1.0, 0.04)
		mi.material_override = mat
		_scene().add_child(mi)
		mi.global_position = at
		mi.scale = Vector3.ONE * 0.5
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.35)
		tw.tween_property(mi, "scale", Vector3.ONE * r, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 1.6)
		tw.tween_callback(mi.queue_free)
	if c is Player:
		for f in _targets(c, r):
			_core(f, col, dur, 1.0)


## Rakibin göğsünde duvar ardından görünen nabız çekirdeği (iç küre + dış hale)
static func _core(f: Node3D, col: Color, dur: float, size: float) -> void:
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.22 * size, Color(1, 1, 1), Vector3.ZERO, 10)
	var core_m = _unshaded(Color(col.r, col.g, col.b, 0.9), true)
	var core = MeshInstance3D.new()
	core.mesh = b.build(core_m)
	core.material_override = core_m
	f.add_child(core)
	core.position = Vector3(0, float(f.get("height") if f.get("height") != null else 1.8) * 0.62, 0)
	var halo_m = _unshaded(Color(col.r, col.g, col.b, 0.35), true)
	var hb = MB.new()
	hb.add("sphere", Vector3.ZERO, Vector3.ONE * 0.5 * size, Color(1, 1, 1), Vector3.ZERO, 12)
	var halo = MeshInstance3D.new()
	halo.mesh = hb.build(halo_m)
	halo.material_override = halo_m
	core.add_child(halo)
	var tw = Game.safe_loops(halo.create_tween(), int(dur / 0.8))
	tw.tween_property(halo, "scale", Vector3.ONE * 1.5, 0.4)
	tw.parallel().tween_property(halo_m, "albedo_color:a", 0.05, 0.4)
	tw.tween_property(halo, "scale", Vector3.ONE, 0.4)
	tw.parallel().tween_property(halo_m, "albedo_color:a", 0.35, 0.4)
	f.get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(core):
			core.queue_free())


## Kagura Shingan: rakiplerin chakrası alev biçimli aura (Güç farkına göre boy ve renk), yerde altın halka
static func kagura(c: Node3D, r: float, dur: float) -> void:
	Combat.start_sensing(c, r, dur)
	var at = Vector3(c.global_position.x, Game.ground_height(c.global_position.x, c.global_position.z) + 0.06, c.global_position.z)
	var gm = _unshaded(Color(1.0, 0.8, 0.35, 0.7))
	var g = MeshInstance3D.new()
	g.mesh = _ring_mesh(2.2, 0.08)
	g.material_override = gm
	_scene().add_child(g)
	g.global_position = at
	var gt = g.create_tween()
	gt.tween_property(g, "rotation:y", TAU, 2.0)
	gt.parallel().tween_property(gm, "albedo_color:a", 0.0, 2.0)
	gt.tween_callback(g.queue_free)
	if not (c is Player):
		return
	var mine = float(Combat.power_of(c)) if Combat.has_method("power_of") else 1.0
	for f in _targets(c, r):
		var ratio = clampf(float(Combat.power_of(f)) / maxf(mine, 0.01), 0.3, 3.0) if Combat.has_method("power_of") else 1.0
		var col = Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.18, 0.12), clampf((ratio - 0.5) / 1.5, 0.0, 1.0))
		_flame_aura(f, col, dur, 0.7 + ratio * 0.5)


## Alev biçimli chakra aurası: gövde çevresinde yukarı kıvrılan 7 ince dil, duvar ardından görünür, titreşir
static func _flame_aura(f: Node3D, col: Color, dur: float, size: float) -> void:
	var root = Node3D.new()
	f.add_child(root)
	var h = float(f.get("height") if f.get("height") != null else 1.8)
	for i in 7:
		var a = TAU * i / 7.0
		var L = h * size * randf_range(0.7, 1.05)
		var m = _unshaded(Color(col.r, col.g, col.b, 0.5), true)
		var mi = MeshInstance3D.new()
		mi.mesh = _tongue_mesh(L, 0.2 * size, randf_range(-0.35, 0.35))
		mi.material_override = m
		root.add_child(mi)
		mi.position = Vector3(cos(a) * 0.32, 0.1, sin(a) * 0.32)
		mi.rotation.y = -a
		var tw = Game.safe_loops(mi.create_tween(), int(dur / 0.5))
		tw.tween_property(mi, "scale", Vector3(1, randf_range(1.1, 1.3), 1), 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "scale", Vector3(1, randf_range(0.8, 0.95), 1), 0.25).set_trans(Tween.TRANS_SINE)
	f.get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free())


## Alev dili: tabanı geniş, uca doğru incelip S biçiminde kıvrılan düz şerit (8 dilim)
static func _tongue_mesh(L: float, w: float, bend: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 8
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in n + 1:
		var u = float(i) / n
		var x = sin(u * PI * 1.3) * bend * L * 0.35
		var y = u * L
		var hw = w * (1.0 - u) * (0.6 + 0.4 * sin(u * PI))
		var l = Vector3(x - hw, y, 0)
		var r = Vector3(x + hw, y, 0)
		if i > 0:
			st.add_vertex(prev_l); st.add_vertex(prev_r); st.add_vertex(r)
			st.add_vertex(prev_l); st.add_vertex(r); st.add_vertex(l)
		prev_l = l
		prev_r = r
	return st.commit()


## Kekkai Tengai Hōjin: kalıcı kubbe; içine giren rakip yüzeyde dalga halkasıyla bildirilir
static func kekkai_dome(c: Node3D, r: float, dur: float) -> void:
	Combat.start_sensing(c, r, dur)
	var center = c.global_position
	var sh = Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform float vis = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 h = vec2(atan(lp.z, lp.x) * 9.0, lp.y * 14.0);
	vec2 g = abs(fract(h + vec2(0.5 * floor(h.y), 0.0)) - 0.5);
	float hexl = 1.0 - smoothstep(0.0, 0.06, min(g.x, g.y));
	float fr = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float a = (hexl * 0.35 + fr * 0.5 + 0.03) * vis;
	ALBEDO = tint.rgb;
	ALPHA = a;
}"""
	var m = ShaderMaterial.new()
	m.shader = sh
	var dome = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.is_hemisphere = true
	sm.radial_segments = 48
	sm.rings = 16
	dome.mesh = sm
	dome.material_override = m
	_scene().add_child(dome)
	dome.global_position = Vector3(center.x, Game.ground_height(center.x, center.z), center.z)
	dome.scale = Vector3.ONE * 0.5
	var tw = dome.create_tween()
	tw.tween_property(dome, "scale", Vector3.ONE * r, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, dur - 1.5))
	tw.tween_method(func(v: float): m.set_shader_parameter("vis", v), 1.0, 0.0, 0.6)
	tw.tween_callback(dome.queue_free)
	# içeri giren rakip: yüzeyde dalga halkası + çekirdek işaret (oyuncu için)
	var seen := {}
	var tick = Timer.new()
	tick.wait_time = 0.3
	dome.add_child(tick)
	tick.timeout.connect(func():
		if not is_instance_valid(c):
			return
		for f in _targets(c, r):
			if seen.has(f.get_instance_id()):
				continue
			seen[f.get_instance_id()] = true
			var dir = (f.global_position - center)
			dir.y = 0.0
			var hit_at = center + dir.normalized() * r if dir.length() > 0.1 else center
			_surface_ripple(Vector3(hit_at.x, Game.ground_height(hit_at.x, hit_at.z) + 1.2, hit_at.z), (f.global_position - center).normalized())
			if c is Player:
				_core(f, Color(0.55, 0.75, 1.0), maxf(1.0, dur - 1.0), 1.0)
				Combat.popup_text(f.global_position + Vector3.UP * 2.4, "Bariyere girdi", Color(0.7, 0.85, 1.0)))
	tick.autostart = true


static func _surface_ripple(at: Vector3, normal: Vector3) -> void:
	for k in 2:
		var mat = _unshaded(Color(0.75, 0.9, 1.0, 0.8))
		var mi = MeshInstance3D.new()
		mi.mesh = _ring_mesh(1.0, 0.08)
		mi.material_override = mat
		_scene().add_child(mi)
		mi.global_position = at
		if normal.length() > 0.1:
			mi.look_at(at + normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT)
			mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		mi.scale = Vector3.ONE * 0.2
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.2)
		tw.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.7)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.7)
		tw.tween_callback(mi.queue_free)
