extends RefCounted
## Bijūgan (尾獣丸; hedef: res://scripts/combat/fx/bijugan_fx.gd). Kanon (Narutopedia "Tailed Beast Drug", roman Sakura Hiden; Kido Tsumiki, Magire): Naruto'nun DNA'sından kapsül. Yutan kuyruklu chakra pelerini
## kazanır; kuyruk sayısı chakrasına bağlı (1-9); kuyruklar kunai, taijutsu ve ninjutsuyu savuşturur. Zayıflık: süre sınırlı, pelerin bedeni korumaz, bilinç kaybında söner. Görsel kaynağı yok.
## Pelerin oyunun jinchūriki görünüşü (BeastCloak.build_cloak): mevcut sistem yeniden kullanıldı. Kuyruk savunması Combat kalkanı (hasar indirimi değil). Satılmaz: S görevi ödülü.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const T = preload("res://scripts/combat/fx/tuketim.gd")
const BC = preload("res://scripts/combat/beast_cloak.gd")

const DUR := 20.0
const TAIL_HP := 24.0
const COL := Color(1.0, 0.42, 0.1)


static func build(b: MB) -> void:
	b.add("sphere", Vector3(0, 0, 0.011), Vector3(0.026, 0.026, 0.04), Color(0.92, 0.44, 0.12), Vector3.ZERO, 8)
	b.add("sphere", Vector3(0, 0, -0.011), Vector3(0.026, 0.026, 0.04), Color(0.14, 0.1, 0.1), Vector3.ZERO, 8)


static func _end(who: Node3D, d: Dictionary) -> void:
	if is_instance_valid(d["mesh"]):
		d["mesh"].queue_free()
	if is_instance_valid(d["ears"]):
		d["ears"].queue_free()
	if is_instance_valid(d["tail_root"]) and d["tail_root"].get_parent() != null:
		d["tail_root"].get_parent().queue_free()
	if not is_instance_valid(who):
		return
	if who is Player:
		Buffs.remove("bijugan")
	elif who.get("buffs") != null:
		who.buffs.erase("bijugan")
	Combat.popup_text(who.global_position + Vector3.UP * 2.2, "Pelerin söndü", COL)


static func use(who: Node3D) -> void:
	var m = who.get("model")
	if m == null or m.get("body_mesh") == null:
		return
	T.pose(who, "bijugan", {"LeftUpperArm": Vector3(0.28, -0.55, 0.78), "LeftLowerArm": Vector3(-0.5, 0.82, 0.25)}, 0.55)
	who.get_tree().create_timer(0.4).timeout.connect(func():
		if not is_instance_valid(who) or who.is_dead() or not is_instance_valid(m):
			return
		var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
		var ch = float(who.get("chakra")) if who.get("chakra") != null else mx
		var n = clampi(ceili(ch / maxf(mx, 1.0) * 9.0), 1, 9)   # kanon: kuyruk sayısı chakraya bağlı
		var d: Dictionary = BC.build_cloak(m, COL)
		var tails: Array = BC.build_tails(d["tail_root"], n, 1, d["mat"])
		var mods = {"melee": 1.3, "speed": 1.18, "jutsu": 1.12}
		if who is Player:
			Buffs.add("bijugan", DUR, mods)
		elif who.has_method("add_buff"):
			who.add_buff("bijugan", DUR, mods)
		Combat.set_shield(who, "bijugan", TAIL_HP * n)
		Combat.popup_text(who.global_position + Vector3.UP * 2.3, "%d kuyruk" % n, COL)
		Sfx.play("roar", who.global_position, 1.3, 0.5)
		var s = {"t": 0.0}
		var fn = func(dt: float) -> bool:
			s["t"] += dt
			var out = not is_instance_valid(who) or who.is_dead() or float(s["t"]) >= DUR or who.has_status("stun")   # kanon: bilinç kaybında söner
			if out:
				_end(who, d)
				return true
			for i in tails.size():   # kuyruklar kökten uca dalgalanır
				var segs: Array = tails[i]
				for k in range(1, segs.size()):
					if is_instance_valid(segs[k]):
						var w = float(s["t"]) * 2.4 - k * 0.65 + i * 1.7
						segs[k].rotation = Vector3(sin(w) * 0.17, cos(w * 0.8) * 0.15, 0.0)
			return false
		Kit.ticker(who.global_position, fn))


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	who.set_meta("bijugan_ictim", true)
	use(who)
	return null


static func player_use(p: Node3D) -> void:
	if Buffs.has("beast") or Buffs.has("bijugan"):
		Hud.msg("Zaten chakra pelerinindesin.", Color(1, 0.75, 0.5))
		return
	if T.gate(p, "bijugan", 0.0, true, 0.55):
		use(p)
