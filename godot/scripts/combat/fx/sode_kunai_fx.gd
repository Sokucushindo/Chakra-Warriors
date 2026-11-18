extends RefCounted
## Sode Kunai (Narutopedia "Hidden Kunai Mechanism", hedef: res://scripts/combat/fx/sode_kunai_fx.gd). Kanon kullanıcı: Naruto (manga 283), anime: Jiraiya, Boruto.
## Kanon: kunai kolluğun içinden yaylı telle anında fırlar ve geri çekilir; kaynak görselde avcun altından, halkasına bağlı beyaz telle çıkar.
## Mekanik (alet tuşu): el hareketi olmadan kısa menzilde bir dürtme. Rakip vuruşa kalkmışken yakalarsa hazırlığını keser, fazla hasar verir ("Gizli Kunai!").
## Mermi yok: kunai telden ayrılmaz, ele döner. Blok tuşundan da basılabilir (alet sistemi izin veriyor). Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const REACH := 3.4
const DMG := 9.0
const SURPRISE_X := 1.9
const WINDUP := 0.5      # rakibin saldırısı bu kadar yeniyse hâlâ hazırlıkta sayılır
const OUT_T := 0.07
const HOLD_T := 0.06
const BACK_T := 0.13

const SPRING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	ALBEDO = vec3(0.92, 0.91, 0.86);
}
"""


static func _spring_mesh() -> Mesh:
	return Kit.cached_mesh("sode_spring", func():
		var c = CylinderMesh.new()
		c.top_radius = 0.009
		c.bottom_radius = 0.009
		c.height = 1.0
		c.radial_segments = 5
		c.rings = 1
		return c)


static func _hand(who: Node3D) -> Vector3:
	var pj = PathJutsu.get_pinst()
	return pj.hand_pos(who, true) if pj != null else Kit.chest(who)


static func _basis(d: Vector3) -> Basis:
	var z = d.normalized()
	var x = (Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).cross(z).normalized()
	return Basis(x, z.cross(x), z)


static func _aim_dir(who: Node3D, from: Vector3, dir: Vector3, target: Node3D) -> Vector3:
	if target != null and is_instance_valid(target) and not target.is_dead():
		var c = Kit.chest(target)
		if c.distance_to(from) < REACH + 1.0:
			return (c - from).normalized()
	return dir.normalized()


## Projectile.tool çağırır; mermi üretmez (dönüşü kullanan yer yok)
static func launch(who: Node3D, _start: Vector3, dir: Vector3, target: Node3D) -> Projectile:
	var kn = MeshInstance3D.new()
	kn.mesh = CharacterModel.weapon_mesh("kunai")
	var s = {"t": 0.0, "hit": false}
	var T = OUT_T + HOLD_T + BACK_T
	var spring = MeshInstance3D.new()
	spring.mesh = _spring_mesh()
	spring.material_override = Kit.shader_mat("sode_spring", SPRING_SH)
	spring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who) or who.is_dead():
			return true
		s["t"] += dt
		var t: float = s["t"]
		if t >= T:
			return true
		var h = _hand(who)
		var d = _aim_dir(who, h, dir, target)
		var u = clampf(t / OUT_T, 0.0, 1.0) if t < OUT_T + HOLD_T else 1.0 - pow(clampf((t - OUT_T - HOLD_T) / BACK_T, 0.0, 1.0), 2.0)
		var tip = h + d * REACH * u
		kn.global_transform = Transform3D(_basis(d), tip - d * 0.28)
		var base = tip - d * 0.3
		var seg = base - h
		var L = maxf(seg.length(), 0.02)
		var y = seg / L if seg.length() > 0.01 else d
		var x = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
		spring.global_transform = Transform3D(Basis(x, y * L, x.cross(y)), h + seg * 0.5)
		if t >= OUT_T and not bool(s["hit"]):
			s["hit"] = true
			_strike(who, tip, d)
		return false
	var root = Kit.ticker(who.global_position, fn)
	root.add_child(kn)
	root.add_child(spring)
	var h0 = _hand(who)
	kn.global_transform = Transform3D(_basis(dir), h0)
	spring.global_transform = Transform3D(Basis.from_scale(Vector3.ZERO), h0)
	Sfx.play("blade", h0, 1.8, 0.55)
	return null


static func _strike(who: Node3D, tip: Vector3, d: Vector3) -> void:
	var base = DMG * Kit.tool_mult(who)
	var caught := []
	for f in Kit.fighters():   # vuruştan ÖNCE bak: isabet saldırıyı keseceği için sonra okunmaz
		if Combat.hostile(who, f) and not f.is_dead() and Combat.capsule_hit(tip, f, 0.55) and Combat.windup_of(f) < WINDUP:
			caught.append(f)
	var hits = Combat.hit_sphere(who, tip, 0.55, {"dmg": base, "knock": 1.0, "kind": "light", "hitstop": 0.05, "melee": true, "dir": Vector3(d.x, 0, d.z).normalized(), "tool": "sode_kunai"})
	for h in hits:
		if not h in caught or h.is_dead():
			continue
		h.take_hit({"dmg": base * (SURPRISE_X - 1.0), "knock": 2.0, "kind": "light", "hitstop": 0.08, "melee": true, "attacker": who, "dir": Vector3(d.x, 0, d.z).normalized(), "tool": "sode_kunai"})
		if h.has_method("stagger"):
			h.stagger(0.55)
		elif h.has_method("apply_status"):
			h.apply_status("stun", 0.4)
		Combat.popup_text(h.global_position + Vector3.UP * (Kit.height_of(h) + 0.3), "Gizli Kunai!", Color(1.0, 0.85, 0.5))
	if not hits.is_empty():
		Sfx.play("hit_blade", tip, 1.25, 0.8)
