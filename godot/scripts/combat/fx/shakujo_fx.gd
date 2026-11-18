extends RefCounted
## Shakujō kombo görselleri ve rüzgâr mekaniği — kendi gölgelendiricileri ve şekilleri, ortak efekt kütüphanesi yok.
## Kanon (Kazuma, refs/shakujo): rüzgâr doğası olan kullanıcı chakrayı asaya akıtır (sapta akan mavi akım), asayı başının üstünde
## çevirir, dev kasırga açıp ileri salar. Kasırganın görünüşü: geniş, yırtık kenarlı, iki tonlu gri şeritler (Shakujo_Twister.png).
## Rüzgârı olmayan kullanıcı aynı komboyu saf silah olarak yapar; bitirişte dipçiği yere vurur, halkaların titreşimi yerde yayılır.
## Oyuncu ve düşman aynı kod (KeyedCombos.on_start / on_strike).

const STEP_COST := 0.012   # her adımda asaya akan chakra (azami chakranın oranı)
const TWISTER_COST := 0.09
const HOLD_TIME := 0.9      # kasırgaya kapılan bu kadar sürüklenir (sonra çıkabilir)
const DRAG_SPEED := 11.0    # sürüklenme hızı (kasırganın ilerleyişinden hızlı)

static var _c := {}

const GALE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
instance uniform float seed_k = 0.0;
uniform vec2 near_d = vec2(0.5, 1.8);
void fragment() {
	float x = UV.x;
	float s = seed_k * 6.283;
	// yırtık kenar: farklı sıklıkta testere dişleri, uçlara doğru dişler uzar
	float t1 = fract(x * 11.0 + s);
	float t2 = fract(x * 27.0 + s * 1.7);
	float t3 = fract(x * 5.0 + s * 0.6);
	float jag = 0.16 * t1 + 0.1 * t2 + 0.12 * t3;
	float body = smoothstep(0.0, 0.22, x) * (1.0 - smoothstep(0.62, 1.0, x));
	float top = 0.5 * body - jag * (0.35 + 0.65 * (1.0 - body));
	float t4 = fract(x * 17.0 - s * 1.3);
	float bot = 0.5 * body - (0.1 * t4 + 0.14 * t3) * (0.35 + 0.65 * (1.0 - body));
	float y = UV.y - 0.5;
	float m = y >= 0.0 ? step(y, top) : step(-y, bot);
	// iki ton: dış yüz açık, iç yüz koyu (kaynaktaki gibi düz boya)
	vec3 col = FRONT_FACING ? vec3(0.74, 0.76, 0.78) : vec3(0.33, 0.34, 0.37);
	ALBEDO = col;
	ALPHA = m * fade_k * smoothstep(near_d.x, near_d.y, -VERTEX.z);
	if (ALPHA < 0.02) discard;
}
"""

const FLOW_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float a = UV.x * 6.283;
	float v = UV.y * 7.0 + TIME * 5.5;
	float s = sin(v + sin(a * 2.0 + TIME * 3.0) * 1.3) * 0.5 + 0.5;
	float s2 = sin(v * 2.3 - a * 3.0) * 0.5 + 0.5;
	float m = smoothstep(0.45, 0.8, s * 0.7 + s2 * 0.3);
	float ends = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.92, 1.0, UV.y));
	ALBEDO = mix(vec3(0.2, 0.42, 0.95), vec3(0.72, 0.88, 1.0), m);
	ALPHA = m * ends * fade_k * 0.85;
}
"""

const CHIME_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float m = 0.0;
	for (int i = 0; i < 3; i++) {
		float c = prog * 0.95 - float(i) * 0.14;
		if (c > 0.02) {
			float w = 0.012 + 0.012 * (1.0 - prog);
			float wob = 0.008 * sin(atan(UV.y - 0.5, UV.x - 0.5) * 18.0 + float(i) * 2.0);
			m = max(m, 1.0 - smoothstep(w * 0.5, w, abs(r + wob - c)));
		}
	}
	ALBEDO = mix(vec3(1.0, 0.86, 0.45), vec3(0.85, 0.62, 0.2), prog);
	ALPHA = m * (1.0 - smoothstep(0.55, 1.0, prog)) * (1.0 - smoothstep(0.96, 1.0, r));
	if (ALPHA < 0.01) discard;
}
"""


static func _mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _c.has(k):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[k] = m
	return _c[k]


static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _fade(gi: GeometryInstance3D, delay: float, t: float) -> void:
	var tw = gi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter("fade_k", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)


## Kanon şartı: rüzgâr doğası (oyuncu: öğrendiği doğalar; düşman: kendi doğası)
static func windy(who: Node3D) -> bool:
	if who is Player:
		return "fuuton" in (Game.profile.get("elements", []) as Array)
	return String(who.get("element")) == "fuuton" if who.get("element") != null else false


## Chakra öder; yetmezse sessizce false (kombo saf silah olarak sürer)
static func _pay(who: Node3D, frac: float) -> bool:
	if who.get("chakra") == null:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if float(who.chakra) < mx * frac:
		return false
	who.chakra = float(who.chakra) - mx * frac
	return true


static func _staff(who: Node3D) -> Node3D:
	var m = who.get("model")
	if m == null or not (m is CharacterModel):
		return null
	for w in m.weapons:
		if String(w["id"]) == "shakujo" and is_instance_valid(w["node"]):
			return w["node"]
	return null


static func _chime(p: Vector3, vol := 0.4) -> void:
	Sfx.play("chain", p, randf_range(1.75, 2.15), vol)   # halkaların şıngırtısı


static func _axes(who: Node3D) -> Array:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	return [f, Vector3.UP.cross(f).normalized()]


static func _height(who: Node3D) -> float:
	return float(who.get("height")) if who.get("height") != null else 1.8


## Sapta akan chakra (Kazuma_Channels_Chakra_to_Shakujo.png): asayı saran ince mavi akım
static func _flow(who: Node3D, dur: float) -> void:
	var n = _staff(who)
	if n == null:
		return
	if not _c.has("mesh:flow"):
		var cm = CylinderMesh.new()
		cm.top_radius = 0.034
		cm.bottom_radius = 0.034
		cm.height = 1.58
		cm.radial_segments = 8
		cm.rings = 1
		_c["mesh:flow"] = cm
	var mi = MeshInstance3D.new()
	mi.mesh = _c["mesh:flow"]
	mi.material_override = _mat("flow", FLOW_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	mi.position = Vector3(0, 0, 0.07)
	mi.rotation = Vector3(PI * 0.5, 0, 0)
	_fade(mi, dur * 0.7, dur * 0.3)


## Yırtık rüzgâr şeridi (yay): merkez, başlangıç ekseni a, dik eksen b
static func gale_arc(center: Vector3, a: Vector3, b: Vector3, r: float, a0: float, a1: float, w: float, life := 0.32) -> void:
	var root = _root()
	if root == null:
		return
	var n_ax = a.cross(b).normalized()
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n = 26
	for i in n + 1:
		var k = float(i) / n
		var ang = lerpf(a0, a1, k)
		var dir = (a * cos(ang) + b * sin(ang)).normalized()
		var rr = r * (0.94 + 0.06 * k)
		var across = (dir * 0.3 + n_ax * 0.85).normalized() * w * 0.5
		im.surface_set_uv(Vector2(k, 0.0))
		im.surface_add_vertex(center + dir * rr - across)
		im.surface_set_uv(Vector2(k, 1.0))
		im.surface_add_vertex(center + dir * rr + across)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _mat("gale", GALE_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	mi.set_instance_shader_parameter("seed_k", randf())
	_fade(mi, life * 0.45, life * 0.55)


## Kasırganın tek şeridi (birim): yükselerek dönen, 300 derecelik geniş bant
static func _twist_mesh() -> ArrayMesh:
	if _c.has("mesh:twist"):
		return _c["mesh:twist"]
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var nr = PackedVector3Array()
	var idx = PackedInt32Array()
	var n = 40
	for i in n + 1:
		var k = float(i) / n
		var a = k * 5.24
		var d = Vector3(cos(a), 0.0, sin(a))
		var rise = (k - 0.5) * 0.9
		for s in 2:
			var e = float(s) - 0.5
			v.append(d * (1.0 + e * 0.16) + Vector3.UP * (rise + e))
			uv.append(Vector2(k, float(s)))
			nr.append(d)
	for i in n:
		var q = i * 2
		idx.append_array(PackedInt32Array([q, q + 1, q + 2, q + 1, q + 3, q + 2]))
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_c["mesh:twist"] = m
	return m


## Shakujō Senpū: dipçiğin önünden doğan, ileri giden kasırga; içine aldıklarını çeker, kaldırır ve keser
static func twister(who: Node3D, start: Vector3, f: Vector3, dmg: float) -> void:
	var root = _root()
	if root == null:
		return
	var H = 6.5
	var base = Node3D.new()
	base.name = "ShakujoSenpu"
	root.add_child(base)
	base.global_position = start
	var spin = Node3D.new()
	base.add_child(spin)
	var bands = 9
	for k in bands:
		var u = float(k) / float(bands - 1)
		var mi = MeshInstance3D.new()
		mi.mesh = _twist_mesh()
		mi.material_override = _mat("gale", GALE_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spin.add_child(mi)
		var rr = lerpf(0.55, 3.3, pow(u, 1.15))
		mi.position = Vector3.UP * (0.35 + u * H)
		mi.scale = Vector3(rr, lerpf(0.75, 1.5, u), rr)
		mi.rotation.y = randf() * TAU
		mi.set_instance_shader_parameter("seed_k", randf())
	var life = 2.0
	var dist = 12.0
	var st = {"tick": 0, "k": 0.0, "held": {}}
	var hit_at = func(c: Vector3) -> void:
		if not is_instance_valid(who):
			return
		var info = {"dmg": dmg * 0.22, "element": "fuuton", "knock": 0.4, "launch": 2.6, "kind": "light", "hitstop": 0.01}
		for h in Combat.hit_sphere(who, c + Vector3.UP * 1.2, 3.0, info):
			(st["held"] as Dictionary)[h] = float(st["k"]) + HOLD_TIME / life   # girdaba kapıldı: kısa süre sürüklenir
	spin.scale = Vector3(0.1, 0.25, 0.1)
	var tw = base.create_tween()
	tw.tween_method(func(k: float):
		if not is_instance_valid(base):
			return
		var q = start + f * dist * k
		q.y = Game.ground_height(q.x, q.z) + 0.02
		base.global_position = q
		spin.rotation.y = k * TAU * 7.0
		# kapılanlar girdabın merkezine doğru sürüklenir (duvardan geçirmez); süre dolunca bırakılır
		var dt_k = (k - float(st["k"])) * life
		st["k"] = k
		var held: Dictionary = st["held"]
		for h in held.keys():
			if not is_instance_valid(h) or h.is_dead() or k > float(held[h]):
				held.erase(h)
				continue
			var hp: Vector3 = h.global_position
			var to = Vector3(q.x, hp.y, q.z)
			h.global_position = PlayerCombat.safe_dest(h, hp, hp.move_toward(to, DRAG_SPEED * dt_k))
		var g = minf(k / 0.12, 1.0) * (1.0 - smoothstep(0.82, 1.0, k))
		spin.scale = Vector3(lerpf(0.1, 1.0, g), lerpf(0.25, 1.0, g), lerpf(0.1, 1.0, g))
		var tick = int(k * life / 0.25)
		if tick > int(st["tick"]) and k < 0.9:
			st["tick"] = tick
			hit_at.call(q)
			Dangle.gust(q + Vector3.UP, Vector3.UP * 6.0, 7.0, 0.3), 0.0, 1.0, life)
	tw.tween_callback(base.queue_free)
	Sfx.play("wind", start, 0.85, 0.9)


## Rüzgârsız bitiriş: dipçik yere iner, halkaların titreşimi yerde altın çizgilerle yayılır
static func chime_ring(p: Vector3, r: float) -> void:
	var root = _root()
	if root == null:
		return
	if not _c.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2(2, 2)
		q.orientation = PlaneMesh.FACE_Y
		_c["mesh:quad"] = q
	var mi = MeshInstance3D.new()
	mi.mesh = _c["mesh:quad"]
	mi.material_override = _mat("chime", CHIME_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_position = p + Vector3.UP * 0.05
	mi.scale = Vector3.ONE * r
	var tw = mi.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("prog", v), 0.0, 1.0, 0.55)
	tw.tween_callback(mi.queue_free)


## Adım başı: rüzgârlı kullanıcı chakrayı asaya akıtır; çevirmede başın üstünde şeritler döner
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var w = windy(who) and _pay(who, STEP_COST)
	who.set_meta("shk_wind", w)
	if not w:
		return
	_flow(who, 1.25 if i == 5 else (1.0 if i == 4 else 0.55))
	if i == 4 or i == 5:
		var n = 4 if i == 4 else 5
		var gap = 0.2
		for k in n:
			who.get_tree().create_timer(0.08 + k * gap).timeout.connect(func():
				if not is_instance_valid(who):
					return
				var c = who.global_position + Vector3.UP * (_height(who) + 0.12 + k * 0.05)
				var a0 = randf() * TAU
				for s in 3:   # birbirinden kopuk ince şeritler (dolu disk değil)
					var a1 = a0 + s * 2.1 + randf() * 0.5
					gale_arc(c + Vector3.UP * (s - 1) * 0.1, Vector3.RIGHT, Vector3.BACK, 1.05 + s * 0.2 + k * 0.08, a1, a1 + 1.5, 0.16, 0.26)
				_chime(c, 0.22))


## Kombo vuruş anı (oyuncu ve düşman aynı)
static func strike(who: Node3D, i: int, dmg: float) -> void:
	var ax = _axes(who)
	var f: Vector3 = ax[0]
	var side: Vector3 = ax[1]
	var p = who.global_position
	var h = _height(who)
	_chime(p + Vector3.UP * h * 0.7, 0.42 if i < 5 else 0.6)
	var w = bool(who.get_meta("shk_wind", false))
	if i == 5:
		var gp = p + f * 1.0
		gp.y = Game.ground_height(gp.x, gp.z) + 0.02
		if w and _pay(who, TWISTER_COST):
			twister(who, p + f * 1.8, f, dmg)
		else:
			chime_ring(gp, 3.6)
			Combat.hit_sphere(who, gp + Vector3.UP * 0.6, 3.2, {"dmg": dmg * 0.55, "knock": 6.0, "launch": 2.5, "kind": "heavy", "hitstop": 0.03})
		return
	if not w:
		return
	# rüzgâr akan asa: savuruş havayı keser, vuruş menzilin ötesine uzanır
	var c = p + Vector3.UP * h * 0.62
	match i:
		0:
			gale_arc(c, f, side, 2.6, -0.2, 0.2, 0.2)
			gale_arc(c + Vector3.UP * 0.14, f, side, 2.9, -0.14, 0.16, 0.13)
		1:
			gale_arc(c, (f - Vector3.UP * 0.6).normalized(), Vector3.UP, 2.0, -0.2, 1.2, 0.2)
			gale_arc(c, (f - Vector3.UP * 0.6).normalized(), Vector3.UP, 2.35, 0.0, 1.0, 0.12)
		2:
			gale_arc(c, -side, f, 2.5, -0.5, 2.6, 0.24)
			gale_arc(c + Vector3.UP * 0.16, -side, f, 2.15, -0.2, 2.2, 0.14)
		3:
			gale_arc(c + Vector3.UP * 0.3, Vector3.UP, f, 2.4, -0.2, 1.9, 0.24)
			gale_arc(c + Vector3.UP * 0.3 + side * 0.15, Vector3.UP, f, 2.05, 0.1, 1.7, 0.14)
		4:
			return
	Combat.hit_sphere(who, p + f * 3.0 + Vector3.UP * 1.0, 1.25, {"dmg": dmg * 0.3, "element": "fuuton", "knock": 3.0, "kind": "light", "hitstop": 0.01})
