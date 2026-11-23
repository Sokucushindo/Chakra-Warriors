extends RefCounted
## Kekkai Fuda (結 etiketi; kanonda adsız, hedef: res://scripts/combat/fx/kekkai_fuda_fx.gd). Kanon (Narutopedia "Barrier Tag", Naruto 503): 結 yazılı kâğıt, kunaiyle çakılır;
## çevrilen alanın içini korur ("muhtemelen"), başında bekleyen ninjalar gördüğü için sürdürülmesi gerekiyor olabilir. Görünüş refs/kekkai_fuda: gri kâğıt, koyu çerçeve, ortada 結, üç üç yazı şeridi.
## Oyunda: tek atış, inen kunaiden dört etiket çevreye saplanır, yerde yazı halkası oluşur. Dışarıdaki düşman mermisi ve bedeni içeri giremez (değdiği yerde yalnız kısa dalga görünür; kabuk yok).
## Bedel: kuran yakında kalmalı, chakra akıtır. Alan etkili jutsuları durdurmaz. İçeride kalan düşman etiketi söker; 3'ten az etiket kalırsa bariyer düşer. Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")

const R := 5.0
const LIFE := 14.0
const LEASH := 6.0        # kuran alanın bu kadar dışına çıkarsa düşer
const DRAIN := 0.012      # sn başına azami chakra payı
const BLOCK_COST := 0.01
const HEIGHT := 6.0
const TEAR_R := 1.0
const TEAR_T := 1.2

const RING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
float h(float x) { return fract(sin(x * 57.3) * 24634.6); }
void fragment() {
	float c = floor(UV.x * 150.0);
	float fx = fract(UV.x * 150.0);
	float a = step(abs(UV.y - (0.3 + 0.4 * h(c))), 0.16) + step(abs(fx - h(c + 5.0)), 0.18);
	if (a < 0.5 || fx > 0.82) discard;
	ALBEDO = vec3(0.07, 0.07, 0.09);
	ALPHA = fade_k * 0.9;
}
"""

const RIPPLE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float prog = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float gap = step(0.25, fract(a * 2.2 + prog));
	float m = (1.0 - smoothstep(0.0, 0.05, abs(r - prog * 0.9))) * gap * (1.0 - prog);
	ALBEDO = vec3(0.72, 0.82, 0.9);
	ALPHA = m;
	if (ALPHA < 0.01) discard;
}
"""


static func _tag(b: MB, xf: Transform3D) -> void:
	var t = MB.new()
	var ink = Color(0.05, 0.05, 0.06)
	t.add("box", Vector3.ZERO, Vector3(0.11, 0.22, 0.003), Color(0.18, 0.18, 0.2))
	t.add("box", Vector3(0, 0, 0.002), Vector3(0.095, 0.2, 0.001), Color(0.56, 0.56, 0.56))
	t.add("torus", Vector3(0, 0, 0.003), Vector3(0.07, 0.07, 0.004), ink, Vector3(90, 0, 0), 14)
	t.add("box", Vector3(-0.012, 0, 0.004), Vector3(0.006, 0.04, 0.001), ink)   # 結'ün sade biçimi
	t.add("box", Vector3(0.012, 0.012, 0.004), Vector3(0.026, 0.005, 0.001), ink)
	t.add("box", Vector3(0.012, -0.004, 0.004), Vector3(0.02, 0.005, 0.001), ink)
	t.add("box", Vector3(0.012, -0.014, 0.004), Vector3(0.018, 0.012, 0.001), ink)
	for x in [-0.03, 0.0, 0.03]:   # üstte ve altta üç yazı şeridi
		for s in [-1.0, 1.0]:
			for k in 4:
				t.add("box", Vector3(x * (1.0 - k * 0.12), s * (0.056 + k * 0.012), 0.003), Vector3(0.008, 0.008, 0.001), ink, Vector3(0, 0, 30.0 * (1 - 2 * (k % 2))))
	b.add_mesh(t, xf)


## Kunai ucu aşağı, etiket gövdesinde
static func _stake() -> Mesh:
	return Yk.mesh("kekkai_kazik", func():
		var b = MB.new()
		var k = MB.new()
		CharacterModel._kunai_mesh(k)
		b.add_mesh(k, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.22, 0)))
		_tag(b, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0.02)))
		return b.build(Props.toon()))


static func _thrown() -> Mesh:
	return Yk.mesh("kekkai_atis", func():
		var b = MB.new()
		var k = MB.new()
		CharacterModel._kunai_mesh(k)
		b.add_mesh(k, Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))
		_tag(b, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.02, 0.1)))
		return b.build(Props.toon()))


## Oyuncu atar, indiği yer merkez olur; düşman kendini korur (ayağının dibine kurar)
static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	if not who is Player:
		raise(who, who.global_position)
		return null
	var pr = Kit.launch(who, start, dir, "kekkai_fuda", 34.0, 9.0, _thrown(), 1.0)
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		raise(who, pos)
	return pr


static func _ring(c: Vector3) -> MeshInstance3D:
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n = 72
	for i in n + 1:
		var a = float(i) / n * TAU
		var d = Vector3(cos(a), 0, sin(a))
		for s in [-1.0, 1.0]:
			var p: Vector3 = c + d * (R + s * 0.11)
			p.y = Game.jutsu_floor_at(p).y + 0.04
			im.surface_set_uv(Vector2(float(i) / n, 0.5 + s * 0.5))
			im.surface_add_vertex(p)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Yk.mat("kekkai_halka", RING_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.scene().add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


static func _ripple(at: Vector3, n: Vector3) -> void:
	var holder = Node3D.new()
	Kit.scene().add_child(holder)
	var q = Kit.quad(holder, 1.8, Yk.mat("kekkai_dalga", RIPPLE_SH))
	var nn = n.normalized() if n.length() > 0.01 else Vector3.FORWARD
	holder.global_transform = Transform3D(Basis.looking_at(-nn, Vector3.UP if absf(nn.y) < 0.95 else Vector3.RIGHT), at)
	Kit.tween_param(q, "prog", 0.0, 1.0, 0.26).tween_callback(holder.queue_free)
	Sfx.play("clink", at, 1.7, 0.4)


static func raise(who: Node3D, pos: Vector3) -> void:
	var c = Game.jutsu_floor_at(pos)
	var s = {"t": 0.0, "acc": 0.0, "tags": [], "inside": {}, "ring": null, "tear": {}}
	var oid = who.get_instance_id()
	var fn = func(dt: float) -> bool:
		return _tick(who, oid, c, s, dt)
	var root = Kit.ticker(c, fn)
	for k in 4:
		var a = PI * 0.25 + k * PI * 0.5
		var off = Vector3(cos(a), 0, sin(a)) * R
		var g = c + off
		g.y = Game.jutsu_floor_at(g).y
		var mi = MeshInstance3D.new()
		mi.mesh = _stake()
		root.add_child(mi)
		mi.global_position = c + Vector3.UP * 0.8
		mi.rotation.y = -a + PI * 0.5
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", g - Vector3.UP * 0.1, 0.22).set_delay(k * 0.04)
		s["tags"].append({"n": mi, "p": g})
	s["ring"] = _ring(c)
	Sfx.play("th_paper", c, 0.9, 0.8)
	Sfx.play("seal", c, 1.15, 0.6)
	for f in Kit.fighters():   # kurulurken içeride olanlar serbest; dışarıdan girilemez
		if Vector2(f.global_position.x - c.x, f.global_position.z - c.z).length() < R:
			s["inside"][f.get_instance_id()] = true
	if who is Player:
		Hud.msg("Kekkai kuruldu: yakında kal, chakra akıyor.", Color(0.75, 0.85, 0.95))


static func _end(c: Vector3, s: Dictionary) -> bool:
	if is_instance_valid(s["ring"]):
		var r: MeshInstance3D = s["ring"]
		Yk.fade(r, 0.0, 0.3)
	Sfx.play("th_paper", c, 0.7, 0.5)
	return true


static func _tick(who: Node3D, oid: int, c: Vector3, s: Dictionary, dt: float) -> bool:
	s["t"] += dt
	s["acc"] += dt
	var d2 = func(p: Vector3) -> float:
		return Vector2(p.x - c.x, p.z - c.z).length()
	if float(s["t"]) >= LIFE or not is_instance_valid(who) or who.is_dead() or d2.call(who.global_position) > R + LEASH:
		return _end(c, s)
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if who.get("chakra") != null:
		who.chakra = float(who.chakra) - mx * DRAIN * dt
		if float(who.chakra) <= 0.0:
			who.chakra = 0.0
			return _end(c, s)
	# mermiler
	for p in who.get_tree().get_nodes_in_group("projectiles"):
		if p.dead or not p.blockable or p.shooter == null or not is_instance_valid(p.shooter) or not Combat.hostile(who, p.shooter):
			continue
		var pp: Vector3 = p.global_position
		if d2.call(pp) < R and pp.y - c.y < HEIGHT and d2.call(p.shooter.global_position) >= R:
			_ripple(pp, Vector3(pp.x - c.x, 0, pp.z - c.z))
			p.dead = true
			p.queue_free()
			Yk.pay(who, BLOCK_COST)
	if float(s["acc"]) < 0.05:
		return false
	var step = float(s["acc"])
	s["acc"] = 0.0
	# bedenler ve sökme
	for f in Kit.fighters():
		if not Combat.hostile(who, f) or f.is_dead():
			continue
		var fp: Vector3 = f.global_position
		var dd: float = d2.call(fp)
		var id = f.get_instance_id()
		if bool(s["inside"].get(id, false)):
			if dd > R + 0.5:
				s["inside"].erase(id)
			else:
				_tear(f, id, s, step)
			continue
		if dd < R + 0.25 and fp.y - c.y < HEIGHT:
			var out = Vector3(fp.x - c.x, 0, fp.z - c.z)
			out = out.normalized() if out.length() > 0.01 else Vector3.BACK
			f.global_position = Vector3(c.x, fp.y, c.z) + out * (R + 0.3)
			if f is CharacterBody3D:
				f.velocity = out * 7.0 + Vector3.UP * 1.5
			if Game.now() >= float(s.get("rip_t", 0.0)):
				s["rip_t"] = Game.now() + 0.2
				_ripple(fp + Vector3.UP, out)
	if (s["tags"] as Array).size() < 3:
		Combat.popup_text(c + Vector3.UP * 1.5, "Bariyer düştü", Color(0.75, 0.85, 0.95))
		return _end(c, s)
	return false


static func _tear(f: Node3D, id: int, s: Dictionary, dt: float) -> void:
	var tags: Array = s["tags"]
	for i in range(tags.size() - 1, -1, -1):
		var e: Dictionary = tags[i]
		if f.global_position.distance_to(e["p"]) < TEAR_R + 0.6:
			var k = "%d:%d" % [id, i]
			s["tear"][k] = float(s["tear"].get(k, 0.0)) + dt
			if float(s["tear"][k]) >= TEAR_T:
				if is_instance_valid(e["n"]):
					e["n"].queue_free()
				tags.remove_at(i)
				s["tear"].clear()
				Sfx.play("th_paper", f.global_position, 1.3, 0.6)
			return


## Yapay zekâ: yaralıyken ve rakip uzaktan atıyorsa kendini çevirir
static func ai_wants(e: Node3D, d: float) -> bool:
	return float(e.hp) < float(e.max_hp) * 0.6 and d > 7.0 and float(e.chakra) > float(e.max_chakra) * 0.35
