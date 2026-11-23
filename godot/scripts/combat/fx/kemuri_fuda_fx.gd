extends RefCounted
## Kemuri Fuda (煙 etiketi; kanonda adsız; hedef: res://scripts/combat/fx/kemuri_fuda_fx.gd). Kanon (Narutopedia "Smoke Tag", "Winding Smoke Technique" / Maki Kemuri no Jutsu, Shippūden 316):
## ortasında 煙 yazan büyük kâğıt; kullanan etiketi gösterip mühür yapar, YEŞİL duman süzülerek bütün alanı kaplar, düşmanların görüşünü keser; kaçmak ya da gizlice vurmak için.
## Görünüş refs/kemuri_fuda: krem kâğıt + kara yazı; duman yarı saydam, düz renkli yeşil katmanlar, içindekiler seçilir.
## Oyunda: atılmaz, elde gösterilip açılır. Kemuridama'dan farkı: yavaş yayılır, çok geniştir (16 m), yere yakın; kullanan VE yoldaşları görür. Oyunun duman görüş sistemini kullanır (Combat.hidden_from). Rüzgâr dağıtır.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const K = preload("res://scripts/combat/fx/kemuridama_fx.gd")

const R := 16.0
const LIFE := 15.0
const GROW_T := 5.5
const FADE := 2.5

static var _veil := 0.0
static var _frame := -1

const SHEET_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, skip_vertex_transform;
instance uniform float grow = 0.0;
instance uniform float fade_k = 1.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	vec3 c = VERTEX * vec3(grow, 1.0, grow);
	c.x += sin(TIME * 0.22 + sd * 40.0) * 0.8;
	c.z += cos(TIME * 0.18 + sd * 60.0) * 0.8;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	v.x += (UV.x - 0.5) * (5.0 + COLOR.g * 7.0) * (0.3 + 0.7 * grow);
	v.y += (0.5 - UV.y) * (1.6 + COLOR.g * 1.8) * min(1.0, grow * 2.5);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	float top = 0.22 + 0.13 * sin(UV.x * 7.0 + sd * 30.0 + TIME * 0.35) + 0.06 * sin(UV.x * 17.0 - sd * 20.0);
	float side = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	if (UV.y < top || side < 0.05) discard;
	float band = step(top + 0.16, UV.y);
	ALBEDO = mix(vec3(0.62, 0.86, 0.62), vec3(0.42, 0.68, 0.46), band);
	ALPHA = 0.3 * fade_k * side * (1.0 - smoothstep(0.82, 1.0, UV.y)) * smoothstep(0.5, 2.0, -VERTEX.z);
}
"""

const VEIL_SH := """shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;
uniform float k = 0.0;
void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}
void fragment() {
	float w = SCREEN_UV.y + 0.05 * sin(SCREEN_UV.x * 9.0 + TIME * 0.4) + 0.025 * sin(SCREEN_UV.x * 21.0 - TIME * 0.3);
	float b = step(0.48, w);
	ALBEDO = mix(vec3(0.62, 0.86, 0.62), vec3(0.42, 0.68, 0.46), b);
	ALPHA = k * (0.34 + 0.2 * b);
}
"""


static func _tag_mesh() -> Mesh:
	return Yk.mesh("kemuri_etiket", func():
		var b = MB.new()
		var ink = Color(0.06, 0.05, 0.05)
		b.add("box", Vector3.ZERO, Vector3(0.14, 0.32, 0.003), Color(0.93, 0.89, 0.74))
		var rng = RandomNumberGenerator.new()
		rng.seed = 316
		for x in [-0.045, 0.045]:   # kenarlarda kıvrık yazı
			for k in 8:
				var y = -0.13 + k * 0.037
				if absf(y) > 0.05:
					b.add("box", Vector3(x + rng.randf_range(-0.008, 0.008), y, 0.002), Vector3(0.022, 0.006, 0.001), ink, Vector3(0, 0, rng.randf_range(-50, 50)))
		for st in [[0, 0.03, 0.08, 0.008, 0], [0, 0.0, 0.07, 0.008, 0], [-0.03, 0.0, 0.008, 0.07, 0], [0.012, -0.01, 0.008, 0.055, 0], [-0.002, -0.036, 0.075, 0.008, 0], [0.02, 0.012, 0.03, 0.006, -35]]:   # sade 煙
			b.add("box", Vector3(st[0], st[1], 0.002), Vector3(st[2], st[3], 0.001), ink, Vector3(0, 0, st[4]))
		return b.build(Props.toon()))


static func _sheets() -> Mesh:
	return Yk.mesh("kemuri_katman", func():
		var items := []
		for i in 46:
			var a = randf() * TAU
			var r = sqrt(randf()) * R * 0.86
			items.append([Vector3(cos(a) * r, randf_range(0.5, 1.5), sin(a) * r), Color(randf(), randf(), 0.0, 1.0)])
		return Kit.card_mesh(items))


## Alet tuşu: etiket gösterilir, mühür, yanarak açılır
static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	var m = who.get("model")
	if m != null and m.get("overlay") != null:
		m.overlay.set_pose("seal", 1.0)
	var mi = MeshInstance3D.new()
	mi.mesh = _tag_mesh()
	Kit.scene().add_child(mi)
	var fw = Yk.face(who)
	var follow = func(_v: float):
		if is_instance_valid(mi) and is_instance_valid(who):
			mi.global_transform = Transform3D(Basis.looking_at(-fw, Vector3.UP), who.global_position + Vector3.UP * 1.25 + fw * 0.42)
	var tw = mi.create_tween()
	tw.tween_method(follow, 0.0, 1.0, 0.42)
	tw.tween_property(mi, "scale", Vector3(1.0, 0.02, 1.0), 0.14)
	tw.tween_callback(mi.queue_free)
	Sfx.play("seal", who.global_position, 0.9, 0.7)
	Yk.after(who, 0.42, func():
		if m != null and is_instance_valid(m):
			m.overlay.set_pose("seal", 0.0)
		release(who, who.global_position))
	return null


static func release(who: Node3D, at: Vector3) -> void:
	var c = Game.jutsu_floor_at(at)
	var s = {"t": 0.0, "life": LIFE, "acc": 0.0, "n": null, "mi": null}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		var n: Node3D = s["n"]
		s["acc"] += dt
		if float(s["acc"]) >= 0.2:
			s["acc"] = 0.0
			if n.get_meta("wind", false) or K._wind_near(n):
				s["life"] = minf(float(s["life"]), t + 1.0)
			K._drop_locks()
		var life: float = s["life"]
		var g = smoothstep(0.0, GROW_T, t)
		var e = clampf((t - (life - FADE)) / FADE, 0.0, 1.0)
		var mi: MeshInstance3D = s["mi"]
		mi.set_instance_shader_parameter("grow", maxf(0.12, g))
		mi.set_instance_shader_parameter("fade_k", 1.0 - e)
		n.set_meta("r", R * maxf(0.12, g) * (1.0 - e))
		_veil_tick(who, dt)
		if t >= life:
			n.remove_from_group(K.GROUP)
			return true
		return false
	var root = Kit.ticker(c, fn)
	s["n"] = root
	root.add_to_group(K.GROUP)
	root.set_meta("owner_id", who.get_instance_id() if is_instance_valid(who) else 0)
	root.set_meta("ally_safe", true)   # kullanan ve yoldaşları görür (kemuridama.veiled)
	root.set_meta("c", c + Vector3.UP * 1.2)
	root.set_meta("r", 0.0)
	s["mi"] = Kit.cards(root, _sheets(), Yk.mat("kemuri_yesil", SHEET_SH), Vector3(24, 6, 24))
	Sfx.play("poof", c, 0.6, 0.6)
	Sfx.play("wind", c, 0.55, 0.4)


static func _veil_tick(who: Node3D, dt: float) -> void:
	var fr = Engine.get_physics_frames()
	if fr == _frame:
		return
	_frame = fr
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or pl.cam == null:
		return
	var want = 0.0
	var cp: Vector3 = pl.cam.global_position
	for c in Kit.tree().get_nodes_in_group(K.GROUP):
		if c.get_meta("ally_safe", false) and cp.distance_to(c.get_meta("c")) < float(c.get_meta("r", 0.0)) * 0.92 and cp.y - (c.get_meta("c") as Vector3).y < 2.0:
			want = 0.45 if is_instance_valid(who) and not Combat.hostile(who, pl) else 1.0
			break
	_veil = move_toward(_veil, want, dt * 1.2)
	var v = Kit.screen("kemuri_fuda", VEIL_SH)
	v.visible = _veil > 0.01
	v.material_override.set_shader_parameter("k", _veil)
