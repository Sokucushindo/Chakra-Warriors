extends "res://tests/shorts_kit.gd"
## Bütün Suiton teknikleri (element == suiton, Güç sırasıyla) kuklaya, yatay 1920x1080.
## 11'erli gruplar: SCENES=c0,c3 ile yalnız o grup yeniden çekilir. Her çekimden sonra tekniğin bıraktığı her şey silinir.
const PER := 11
var ids: Array = []


func landscape() -> bool:
	return true


func scenes() -> Array:
	var out = []
	for k in 10:
		out.append("c%d" % k)
	return out


func setup_player(pr: Dictionary) -> void:
	pr["level"] = 120
	pl.apply_profile_stats()
	Gear.grant(pr, "set_jonin", "set")
	for k in Data.jutsu:
		var jd = Data.jutsu[k]
		if jd is Dictionary and String(jd.get("element", "")) == "suiton":
			ids.append(String(k))
	ids.sort_custom(func(a, b):
		var la = float(Data.jutsu[a].get("level", 1))
		var lb = float(Data.jutsu[b].get("level", 1))
		return la < lb if la != lb else a < b)
	print("SUITON toplam ", ids.size())
	pr["learned"] = ids.duplicate()


func s_c0() -> void: await _chunk(0)
func s_c1() -> void: await _chunk(1)
func s_c2() -> void: await _chunk(2)
func s_c3() -> void: await _chunk(3)
func s_c4() -> void: await _chunk(4)
func s_c5() -> void: await _chunk(5)
func s_c6() -> void: await _chunk(6)
func s_c7() -> void: await _chunk(7)
func s_c8() -> void: await _chunk(8)
func s_c9() -> void: await _chunk(9)


func _chunk(k: int) -> void:
	var part = ids.slice(k * PER, (k + 1) * PER)
	if part.is_empty():
		return
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	await _goto(field + Vector3(18, 0, 0))
	var p0 = pl.global_position
	var yaw0 = pl.yaw
	for id in part:
		var jd: Dictionary = Data.jutsu[id]
		var big = String(jd.get("shape", "")) in ["aoe", "field", "summon", "wall", "line", "beam"] or float(jd.get("level", 1)) >= 18
		var before = {}
		for ch in get_tree().current_scene.get_children():
			before[ch] = true
		for ch in pl.get_children():
			before[ch] = true
		for ch in pl.model.get_children():
			before[ch] = true
		# her teknik aynı yerden, aynı yöne
		pl.global_position = p0
		pl.velocity = Vector3.ZERO
		pl.yaw = yaw0
		await _w(0.2)
		await _dshot(id, String(jd.get("name", id)), 2.4 if big else 2.0, big, "j_" + id, Color(0.55, 0.8, 1.0))
		# temizlik: tekniğin sahneye bıraktığı her şey (sis, su zemini, klon, kalkan...) + oyuncu üstündeki etkiler
		for ch in get_tree().current_scene.get_children() + pl.get_children() + pl.model.get_children():
			if not before.has(ch) and not ch is Player and ch != cam:
				ch.queue_free()
		Game.world.env.set_tint(Color(0, 0, 0, 0))   # sis / mürekkep tonları (Kirigakure ekranı beyaza boyuyordu)
		_clear_fx()
		pl.statuses.clear()
		Buffs.reset()
		pl.model.visible = true
		_god()
		await _w(0.5)
