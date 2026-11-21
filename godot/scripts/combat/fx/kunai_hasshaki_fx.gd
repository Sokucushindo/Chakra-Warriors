extends RefCounted
## Kunai Hasshaki (el kunai atarı; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/kunai_hasshaki_fx.gd). Kanon (Narutopedia "Handheld Kunai Launcher", Shippūden filmi Bonds,
## Boruto 56): makineli tüfek gibi yüksek hızda kunai yağdırır, isabeti bozulmaz; Gökyüzü Ülkesi ninjaları uçarken kullanır, Tenten kuklalarına takar.
## Görünüş refs/kunai_hasshaki: zeytin-bej gövde, geniş ağızlı namlu, ön tutamak, üstte şarjör.
## Zayıflık: 24 kunailik şarjör biter, doldurmak kombonun bir adımı; tek kunai zayıf, yakın dövüş yok. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")

const ID := "kunai_hasshaki"
const MAG := 24
const REFILL := 4.0
const SPEED := 72.0
const GRAV := 1.0
const MUZZLE := Vector3(0, 0.02, 0.66)

const FLASH_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(1.0, 0.86, 0.55);
	ALPHA = smoothstep(0.1, 0.8, v) * (1.0 - UV.x) * fade_k;
}
"""


static func build(b: MB) -> void:
	var body = Color(0.55, 0.47, 0.27)
	var dark = Color(0.17, 0.16, 0.13)
	var pale = Color(0.72, 0.67, 0.5)
	b.add("box", Vector3(0, 0, 0.14), Vector3(0.07, 0.085, 0.42), body)
	Loft.tube(b, [Vector3(0, 0.015, 0.3), Vector3(0, 0.015, 0.52), Vector3(0, 0.015, 0.66)], [0.034, 0.04, 0.066], pale, 10, 2)
	b.add("cyl", MUZZLE, Vector3(0.09, 0.01, 0.06), dark, Vector3(90, 0, 0), 10)
	b.add("box", Vector3(0, 0.09, -0.02), Vector3(0.05, 0.12, 0.13), body.darkened(0.15))   # üstteki şarjör
	b.add("box", Vector3(0, 0.155, -0.02), Vector3(0.058, 0.014, 0.14), dark)
	b.add("box", Vector3(0, -0.085, -0.03), Vector3(0.038, 0.1, 0.05), dark, Vector3(-14, 0, 0))   # arka tutamak
	b.add("box", Vector3(0, -0.07, 0.26), Vector3(0.034, 0.08, 0.04), dark, Vector3(10, 0, 0))     # ön tutamak
	b.add("box", Vector3(0, -0.008, -0.13), Vector3(0.05, 0.06, 0.14), body.darkened(0.25))


static func _kunai() -> Mesh:
	return Yk.mesh("hassha_kunai", func():
		var b = MB.new()
		var k = MB.new()
		CharacterModel._kunai_mesh(k)
		b.add_mesh(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.72), Vector3.ZERO))
		return b.build(Props.toon()))


static func _ammo(who: Node3D) -> int:
	if Game.now() - float(who.get_meta("kh_t", -99.0)) > REFILL:
		who.set_meta("kh_mag", MAG)
	return int(who.get_meta("kh_mag", MAG))


static func _muzzle(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, ID)
	return n.to_global(MUZZLE) if n != null else who.global_position + Vector3.UP * 1.3 + who.face_dir() * 0.7


static func _vis() -> Node3D:
	var root = Node3D.new()
	var v = MeshInstance3D.new()
	v.mesh = _kunai()
	v.rotation.y = PI
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(v)
	return root


static func _one(who: Node3D, to: Vector3, dmg: float) -> void:
	var left = _ammo(who)
	if left <= 0:
		return
	who.set_meta("kh_mag", left - 1)
	who.set_meta("kh_t", Game.now())
	var from = _muzzle(who)
	var dir: Vector3 = (to - from).normalized()
	_flash(from, dir)
	Sfx.play("throw_kunai", from, randf_range(1.5, 1.75), 0.28)
	var cb = func(pos: Vector3, tgt: Node3D) -> void:
		if tgt != null and is_instance_valid(tgt):
			Sfx.play("hit_claw", pos, 1.5, 0.25)
			var mi = MeshInstance3D.new()
			mi.mesh = _kunai()
			U.pin(mi, tgt, pos - dir * 0.14, dir, 1.6)
	U.fire(who, from, U.solve(from, to, SPEED, GRAV), {"g": GRAV, "r": 0.1, "life": 1.5, "stick": true, "vis": _vis(), "hit": cb,
		"info": {"dmg": dmg, "knock": 0.5, "kind": "light", "hitstop": 0.0, "tool": "kunai", "blade": true}})


static func _flash(from: Vector3, dir: Vector3) -> void:
	var s = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var mi = Yk.strip([from, from + dir * 0.18 + s * 0.012, from + dir * 0.36], 0.05, Yk.mat("hassha_alev", FLASH_SH), 0.9)
	Yk.fade(mi, 0.0, 0.07)


## n kunai, gap aralıkla; off(j) nişan kayması
static func _stream(who: Node3D, n: int, gap: float, tg: Node3D, aim: Vector3, off: Callable, dmg: float) -> void:
	if _ammo(who) <= 0:
		Sfx.play("click", who.global_position + Vector3.UP * 1.3, 0.7, 0.6)
		if who is Player:
			Combat.popup_text(who.global_position + Vector3.UP * 2.1, "Şarjör boş", Color(0.85, 0.82, 0.7))
		return
	for j in n:
		Yk.after(who, j * gap, func():
			var p: Vector3 = U.chest(tg) if U.alive(tg) else aim
			U.face(who, p)
			_one(who, p + (off.call(j) as Vector3), dmg))


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	if i == 3:
		if who is CharacterBody3D:
			var f: Vector3 = who.face_dir()
			who.velocity.x = -f.x * 7.0
			who.velocity.z = -f.z * 7.0
			who.velocity.y = 4.0
		Yk.after(who, 0.42, func():
			who.set_meta("kh_mag", MAG)
			Sfx.play("clink", who.global_position + Vector3.UP * 1.3, 0.8, 0.7))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	var f = Yk.face(who)
	var s = Vector3.UP.cross(f).normalized()
	var jit = func(_j: int) -> Vector3:
		return Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
	match i:
		0, 1:
			_stream(who, 3, 0.07, tg, aim, jit, dmg * 0.3)
		2:
			var d = maxf(4.0, aim.distance_to(who.global_position))
			_stream(who, 9, 0.05, null, aim, func(j: int) -> Vector3:
				return s * ((float(j) / 8.0 - 0.5) * d * 0.7), dmg * 0.2)
		4:
			_stream(who, 12, 0.07, tg, aim, jit, dmg * 0.22)
		5:
			var n = _ammo(who)
			_stream(who, n, 0.028, tg, aim, func(_j: int) -> Vector3:
				return Vector3(randf_range(-0.3, 0.3), randf_range(-0.25, 0.25), randf_range(-0.3, 0.3)), dmg * 0.2)
			if who is CharacterBody3D:   # geri tepme
				who.velocity.x = -f.x * 5.0
				who.velocity.z = -f.z * 5.0
