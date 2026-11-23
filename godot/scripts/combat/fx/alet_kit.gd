extends RefCounted
## Atılan ninja araçlarının ORTAK İSKELETİ (hedef: res://scripts/combat/fx/alet_kit.gd).
## Yalnız altyapı: fırlatma, kare sayacı, kâğıt sarma geometrisi, kart kümesi, yapay zekâ seçimi.
## Görünen hiçbir efekt burada değil; her aracın gölgelendiricisi kendi dosyasında.

static var _c := {}


class Ticker extends Node3D:
	var fn: Callable
	func _physics_process(dt: float) -> void:
		if Game.paused or not fn.is_valid():
			return
		if bool(fn.call(dt)):
			queue_free()


static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func scene() -> Node:
	return tree().current_scene


static func fighters() -> Array:
	return tree().get_nodes_in_group("fighters")


## fn(dt) true döndürünce düğüm silinir; görseller bu düğümün çocuğu olur
static func ticker(at: Vector3, fn: Callable) -> Node3D:
	var n = Ticker.new()
	n.fn = fn
	scene().add_child(n)
	n.global_position = at
	return n


static func shader_mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _c.has(k):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[k] = m
	return _c[k]


static func cached_mesh(key: String, build: Callable) -> Mesh:
	var k = "mesh:" + key
	if not _c.has(k):
		_c[k] = build.call()
	return _c[k]


static func height_of(n: Node) -> float:
	var h = n.get("height")
	return float(h) if h != null else 1.8


static func eye(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * height_of(n) * 0.9


static func chest(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * height_of(n) * 0.55


static func clan_of(n: Node) -> String:
	if n is Player:
		return str(Game.profile.get("clan", ""))
	return str(n.arch.get("clan", "")) if n.get("arch") is Dictionary else ""


## Oyuncunun atış çarpanı (Projectile.tool ile aynı formül); düşmanda 1
static func tool_mult(who: Node, tag_bonus := false) -> float:
	if not who is Player:
		return 1.0
	var p = Game.profile
	return Stats.melee_mult(p) * (1.0 + Stats.skill(p, "throw_dmg") + (Stats.skill(p, "tag_dmg") if tag_bonus else 0.0) + Mastery.get_v(p, "shurikenjutsu") * 0.02)


## Ortak fırlatma: oyunun kendi mermisi (çarpışma, kalkan, vuruş kuralları aynı kalır)
static func launch(who: Node3D, start: Vector3, dir: Vector3, kind: String, speed: float, grav: float, body: Mesh, dmg: float, spin := Vector3.ZERO) -> Projectile:
	var pr = Projectile.new()
	pr.shooter = who
	pr.vel = dir * speed
	pr.gravity = grav
	pr.radius = 0.16
	pr.spin = spin
	pr.info = {"dmg": dmg, "knock": 0.4, "kind": "light", "hitstop": 0.0, "melee": true, "tool": kind}
	var mi = MeshInstance3D.new()
	mi.mesh = body
	pr.add_child(mi)
	who.get_tree().current_scene.add_child(pr)
	pr.global_position = start
	return pr


# ------------------------------------------------------------------ geometri
## Küreye oturan kâğıt / ip parçası. c: merkez yönü (birim), t: uzunluk yönü, l ve w radyan cinsinden.
static func patch(b: MB, c: Vector3, t: Vector3, l: float, w: float, r: float, col: Color, nu := 6, nv := 1) -> void:
	var s: Vector3 = c.cross(t).normalized()
	var base := b.verts.size()
	for i in nu + 1:
		for j in nv + 1:
			var u = (float(i) / nu - 0.5) * l
			var v = (float(j) / nv - 0.5) * w
			var d: Vector3 = (c.rotated(s, u) + s * v).normalized()
			b.verts.append(d * r)
			b.normals.append(d)
			b.colors.append(col)
			b.uvs.append(Vector2(float(i) / nu, float(j) / nv))
	for i in nu:
		for j in nv:
			var a0 = base + i * (nv + 1) + j
			var b0 = a0 + nv + 1
			b.idx.append_array([a0, b0 + 1, b0, a0, a0 + 1, b0 + 1])


## Küre üstünde fırça darbesi: F yüz yönü, U yukarısı; p0-p1 yüz düzleminde (radyan)
static func stroke(b: MB, f: Vector3, u: Vector3, p0: Vector2, p1: Vector2, w: float, r: float, col: Color) -> void:
	var rt: Vector3 = u.cross(f).normalized()
	var m: Vector2 = (p0 + p1) * 0.5
	var c: Vector3 = (f + rt * m.x + u * m.y).normalized()
	var d: Vector2 = p1 - p0
	var t: Vector3 = (rt * d.x + u * d.y).normalized()
	t = (t - c * t.dot(c)).normalized()
	patch(b, c, t, maxf(d.length(), 0.02), w, r, col, 2, 1)


## Tek çizimlik kart kümesi: kartın 4 köşesi kendi merkezinde durur, açılmayı köşe gölgelendiricisi yapar.
## items: [[merkez: Vector3, veri: Color], ...]
static func card_mesh(items: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var corners = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for it in items:
		var base := v.size()
		for k in 4:
			v.append(it[0])
			n.append(Vector3.UP)
			c.append(it[1])
			uv.append(corners[k])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func cards(parent: Node3D, mesh: Mesh, m: Material, half: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(-half, half * 2.0)
	mi.ignore_occlusion_culling = true
	parent.add_child(mi)
	return mi


static func quad(parent: Node3D, size: float, m: Material) -> MeshInstance3D:
	var q = QuadMesh.new()
	q.size = Vector2.ONE * size
	var mi = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = size
	parent.add_child(mi)
	return mi


static func tween_param(gi: GeometryInstance3D, pname: String, a: float, b: float, t: float, free_after := false) -> Tween:
	gi.set_instance_shader_parameter(pname, a)
	var tw = gi.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter(pname, v), a, b, t)
	if free_after:
		tw.tween_callback(gi.queue_free)
	return tw


## Tam ekran katmanı (yalnız oyuncunun gözü: kör olma, dumanın içi, yanan göz). Gölgelendirici aracın kendi dosyasında.
static var _scr_guard_on := false


static func screen(key: String, code: String) -> MeshInstance3D:
	var k = "scr:" + key
	var old = _c.get(k)
	if old != null and is_instance_valid(old):
		old.set_meta("touch", Time.get_ticks_msec())
		_scr_guard_start()
		return old
	var m = shader_mat("scr_" + key, code)
	m.render_priority = 121   # kenar çizgisi katmanının (120) üstünde
	var mi = MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = m
	mi.extra_cull_margin = 16384
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	scene().add_child(mi)
	_c[k] = mi
	mi.set_meta("touch", Time.get_ticks_msec())
	_scr_guard_start()
	return mi


## Ekran perdesi bekçisi: perdeyi yöneten kod 10 sn boyunca ona hiç dokunmadıysa (sahibi silindi / sayacı durdu) perde kapanır.
## Eskiden düşmanın duman / zehir / kör eden aracı yarıda kalınca perde ekranda sonsuza dek kalıyordu.
static func _scr_guard_start() -> void:
	if _scr_guard_on:
		return
	var tr = tree()
	if tr == null:
		return
	_scr_guard_on = true
	tr.create_timer(1.0, false).timeout.connect(_scr_guard)


static func _scr_guard() -> void:
	_scr_guard_on = false
	var now = Time.get_ticks_msec()
	var any := false
	for k in _c.keys():
		if not String(k).begins_with("scr:"):
			continue
		var mi = _c[k]
		if mi == null or not is_instance_valid(mi) or not mi.visible:
			continue
		if now - int(mi.get_meta("touch", now)) > 10000:
			mi.visible = false
		else:
			any = true
	if any:
		_scr_guard_start()


# ------------------------------------------------------------------ yapay zekâ
## Düşmanın duruma göre eline aldığı araçlar (bekleme süresi süzgeci Enemy._ready_tools içinde, oyuncuyla aynı 30 sn)
static func ai_tools(e: Node3D) -> Array:
	var out := []
	if not e._is_ninja() or e.target == null or not is_instance_valid(e.target):
		return out
	var d: float = e.global_position.distance_to(e.target.global_position)
	var sk: float = float(e.skill)
	var hurt: bool = float(e.hp) < float(e.max_hp) * 0.55
	if sk >= 0.2 and d < 14.0:
		out.append("makibishi")
	if sk >= 0.3 and hurt:
		out.append("smoke")   # kanon: kendini örtüp sıyrılmak
	if sk >= 0.35 and d > 9.0 and d < 30.0 and e.target.has_method("face_dir"):
		var to_e: Vector3 = e.global_position - e.target.global_position
		to_e.y = 0.0
		if e.target.face_dir().dot(to_e.normalized()) > 0.3:   # hedef bana bakıyorsa işe yarar
			out.append("hikaridama")
	if sk >= 0.3 and d > 4.0 and d < 22.0:
		out.append("kosen")
	if sk >= 0.25 and d < 3.8:
		out.append("sode_kunai")
	if sk >= 0.3 and d < 15.0 and load("res://scripts/combat/fx/nuno_maki_fx.gd").has_roll(e):
		out.append("nuno_maki")
	if sk >= 0.35 and d > 4.0 and d < 18.0:
		out.append("suzu")
	if d > 20.0 and load("res://scripts/combat/fx/boenkyo_fx.gd").has_scope(e):
		out.append("boenkyo")
	if sk >= 0.4 and d > 5.0 and d < 20.0:
		out.append("toge_dama")
	if sk >= 0.35 and hurt and d < 22.0:
		out.append("kemuri_fuda")
	if sk >= 0.35 and d > 6.0 and d < 24.0 and e.target.has_method("has_status") and not e.target.has_status("stun"):
		out.append("chusha_bari")
	if sk >= 0.3 and d < 5.0:
		out.append("raizutsu")
	if sk >= 0.45 and d > 5.0 and d < 24.0:
		out.append("hyodama")
	if sk >= 0.35 and d > 4.0 and d < 18.0:
		out.append("mushu_dokugiri")
	if d < 3.2 and hurt:
		out.append("kosho_mimikazari")
	if sk >= 0.6 and d > 10.0 and d < 26.0 and e.get_instance_id() % 10 == 0:   # nadir düzenek: her ninjada yok
		out.append("hiko_tsubasa")
	if d > 10.0 and load("res://scripts/combat/fx/yuki_ita_fx.gd").on_snow(e.global_position):
		out.append("yuki_ita")
	if sk >= 0.45 and d > 7.0 and d < 28.0:
		out.append("kibaku_dama")
	if sk >= 0.5 and d > 5.0 and d < 24.0:
		out.append("bakusaidama")
	if sk >= 0.4 and d > 3.0 and d < 18.0:
		out.append("kibaku_fuda")   # yere ya da rakibe yapıştırır, rakip yanına gelince kendisi patlatır
	if sk >= 0.3 and d < 11.0:
		out.append("agiz_kozu")
	if sk >= 0.4 and d > 6.0 and d < 22.0:
		out.append("aobiko")
	if float(e.hp) < float(e.max_hp) * 0.3 and not e.has_meta("kare_yedi"):
		out.append("inochi_kare")
	if sk >= 0.35:
		for f in fighters():
			if not Combat.hostile(e, f) and not f.is_dead() and e.global_position.distance_to(f.global_position) < 7.0 and f.has_method("has_status") and (f.has_status("fear") or f.has_status("kokuangyo")):
				out.append("genjutsu_kosui")
				break
	if sk >= 0.6 and d < 2.4:
		out.append("genjutsu_yaku")
	if sk >= 0.3:
		for f in fighters():
			if f != e and not f.is_dead() and not Combat.hostile(e, f) and e.global_position.distance_to(f.global_position) < 11.0:
				out.append("okarina")   # yanında yoldaş varken çalar
				break
	if sk >= 0.7 and float(e.hp) < float(e.max_hp) * 0.35 and not e.has_meta("eiyu_ictim") and str(e.arch.get("kind", "")) == "rogue":
		out.append("eiyu_mizu")   # çaresiz usta ömrünü yakar
	if sk >= 0.45 and d > 9.0 and d < 26.0:   # kendi yoldaşları da etkilenir: yanında kimse yokken ve hedef yakınında yoldaş yokken
		var clear = true
		for f in fighters():
			if f != e and not f.is_dead() and not Combat.hostile(e, f) and (f.global_position.distance_to(e.target.global_position) < 14.0):
				clear = false
				break
		if clear:
			out.append("kemuri_senkodan")
	var dk = load("res://scripts/combat/fx/doku_fx.gd")
	if sk >= 0.35 and d < 12.0 and dk.can_coat(e) and not dk.coated(e):
		out.append("doku")
	if dk.left(e) > 2.0 or load("res://scripts/combat/fx/gedokuyaku_fx.gd").ally_in_need(e) != null:
		out.append("gedokuyaku")
	if sk >= 0.35 and d < 20.0 and load("res://scripts/combat/fx/fuin_fuda_fx.gd").ai_wants(e):
		out.append("fuin_fuda")
	if sk >= 0.4 and load("res://scripts/combat/fx/kekkai_fuda_fx.gd").ai_wants(e, d):
		out.append("kekkai_fuda")
	if Game.now() >= float(e.tool_cd.get("togarashi_dama", 0.0)):
		for f in fighters():
			if f != e and f.has_method("has_status") and not Combat.hostile(e, f) and not f.is_dead() and e.global_position.distance_to(f.global_position) < 14.0 and (f.has_status("fear") or f.has_status("kokuangyo")):
				out.append("togarashi_dama")   # genjutsuya düşen yoldaşını uyandırır
				break
	return out
