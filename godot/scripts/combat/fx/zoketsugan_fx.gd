extends RefCounted
## Zōketsugan (増血丸; hedef: res://scripts/combat/fx/zoketsugan_fx.gd). Kanon (Narutopedia "Blood Increasing Pill", One Decade One Hundred Ninja s.103):
## kan yapımını hızlandıran hap; çok kan kaybeden ninja dövüşe devam edebilsin diye yutar. Kullanıcı: Kabuto. Görünüş refs/zoketsugan: iki parmak arasında koyu kızıl-kahve minik top.
## Mekanik: anında iyileştirmez; EKSİK kanın bir kısmını birkaç saniyede yerine koyar, azken daha çok işe yarar. Oyuncu [Y], düşman canı azalınca.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")

const NEED_HP := 0.8      # bundan sağlıklıysa hap boşa gitmez
const REFILL := 0.45      # eksik canın geri gelen payı
const TIME := 8.0
const STEPS := 16
const AI_CD := 150.0

const PULSE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float d = abs(UV.x - prog);
	float band = 1.0 - smoothstep(0.02, 0.2, d);
	ALBEDO = mix(vec3(0.34, 0.02, 0.05), vec3(0.86, 0.12, 0.14), band);
	ALPHA = smoothstep(0.15, 0.6, v) * band * fade_k * 0.85;
	if (ALPHA < 0.02) discard;
}
"""


static func _bead() -> Mesh:
	return Yk.mesh("zoketsu_top", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.022, Color(0.24, 0.06, 0.07), Vector3.ZERO, 8)
		return b.build(Props.toon()))


static func mouth(who: Node3D) -> Vector3:
	return who.global_position + Vector3.UP * Yk.height_of(who) * 0.9 + Yk.face(who) * 0.12


## Hap elden ağza gider (el mühür duruşuna kalkar); done yutunca çağrılır. Seishingan da bunu kullanır.
static func eat(who: Node3D, mesh: Mesh, done: Callable) -> void:
	var m = who.get("model")
	if m != null and m.get("overlay") != null:
		m.overlay.set_pose("seal", 1.0)
		Yk.after(who, 0.42, func():
			if is_instance_valid(m):
				m.overlay.set_pose("seal", 0.0))
	var scene = Yk.root()
	if scene == null:
		done.call()
		return
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	scene.add_child(mi)
	var a: Vector3 = Yk.hand(who)
	mi.global_position = a
	var tw = mi.create_tween()
	tw.tween_interval(0.14)
	tw.tween_method(func(u: float):
		if is_instance_valid(mi) and is_instance_valid(who):
			mi.global_position = a.lerp(mouth(who), u), 0.0, 1.0, 0.16)
	tw.tween_callback(func():
		mi.queue_free()
		if is_instance_valid(who):
			Sfx.play("heal", who.global_position, 0.6, 0.6)
			done.call())


## Kızıl dalga göğüsten uzuvlara yayılır (yeni kan)
static func _pulse(who: Node3D) -> void:
	var f = Yk.face(who)
	var s = Vector3.UP.cross(f).normalized()
	var h = Yk.height_of(who)
	var c: Vector3 = who.global_position + Vector3.UP * h * 0.72 + f * 0.17
	var ends = [Yk.hand(who, true), Yk.hand(who, false), who.global_position + s * 0.13 + Vector3.UP * 0.1, who.global_position - s * 0.13 + Vector3.UP * 0.1]
	var m = Yk.mat("zoketsu_kan", PULSE_SH)
	for e in ends:
		var pts = []
		for k in 7:
			var u = k / 6.0
			pts.append(c.lerp(e, u) + f * 0.05 * sin(u * PI) + s * 0.025 * sin(u * 9.0))
		var mi = Yk.strip(pts, 0.022, m, 0.4)
		var tw = mi.create_tween()
		tw.tween_method(func(v: float):
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("prog", v), 0.0, 1.0, 0.42)
		Yk.fade(mi, 0.3, 0.14)


static func _refill(who: Node3D) -> void:
	var mult = 1.0 + (Stats.skill(Game.profile, "heal") if who is Player else 0.0)
	var total = (float(who.max_hp) - float(who.hp)) * REFILL * mult
	for k in STEPS:
		Yk.after(who, float(k) * TIME / STEPS, func():
			if not who.is_dead():
				who.hp = minf(float(who.max_hp), float(who.hp) + total / STEPS)
				if k % 3 == 0:
					_pulse(who))


## true: hap yendi (bekleme süresi başlar). ClanMech.use_extra_pill ve düşman çağırır
static func use(who: Node3D) -> bool:
	if float(who.hp) >= float(who.max_hp) * NEED_HP:
		if who is Player:
			Hud.msg("Kan kaybın az: Zōketsugan'a gerek yok.", Color(1, 0.75, 0.6))
		return false
	eat(who, _bead(), func():
		Combat.popup_text(who.global_position + Vector3.UP * (Yk.height_of(who) + 0.4), "Zōketsugan", Color(0.9, 0.3, 0.3))
		_refill(who))
	return true


## Düşman: yaralıyken, hapın bekleme süresi dolmuşsa (oyuncuyla aynı süre)
static func ai(e: Node3D) -> void:
	if float(e.skill) < 0.35 or float(e.hp) >= float(e.max_hp) * 0.5 or Game.now() < float(e.get_meta("zoketsu_cd", 0.0)):
		return
	if use(e):
		e.set_meta("zoketsu_cd", Game.now() + AI_CD)
