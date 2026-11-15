extends Node
## Uzun oturum sızıntısı: sahnedeki parçacık düğümleri kimde birikiyor. Köyde gezip (SEC sn) öncesi / sonrası sayımı karşılaştırır.
var main: Node


func census() -> Dictionary:
	var out := {}
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is GPUParticles3D:
			var sig := ""
			var q: Node = n
			for i in 4:
				if q == null:
					break
				var nm := String(q.name)
				var s := ""
				for ch in nm:
					if not ch.is_valid_int() and ch != "@":
						s += ch
				var scr = q.get_script()
				sig = s + ("<" + String(scr.resource_path).get_file() + ">" if scr else "") + "/" + sig
				q = q.get_parent()
			sig += " os=%s em=%s am=%d life=%.1f" % [n.one_shot, n.emitting, n.amount, n.lifetime]
			out[sig] = int(out.get(sig, 0)) + 1
	return out


func total(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += int(d[k])
	return t


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3),
		"bottom": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	Hud.close_dialog()
	var pl = main.player
	pl.combat.invuln = 9999.0
	var a := census()
	print("BAŞ: %d parçacık düğümü" % total(a))
	var sec := float(OS.get_environment("SEC")) if OS.get_environment("SEC") != "" else 90.0
	var v = Game.village("konoha")
	var c: Vector3 = Game.from_map(Vector2(v["x"], v["y"]))
	var t := 0.0
	var ang := 0.0
	while t < sec:
		var dt := get_process_delta_time()
		t += dt
		ang += dt * 0.12
		var r := 60.0 + 90.0 * (0.5 + 0.5 * sin(t * 0.07))
		var at := c + Vector3(cos(ang) * r, 0, sin(ang) * r)
		at.y = Game.ground_height(at.x, at.z) + 1.0
		if OS.get_environment("MOVE") == "":
			pl.global_position = pl.global_position.move_toward(at, 16.0 * dt)
			pl.velocity = Vector3.ZERO
		else:
			# gerçek hareket: koş + atıl + zıpla + uzun sıçrayış (ayak tozu, iniş, hız çizgisi efektleri çalışsın)
			Input.action_press("forward")
			var ph := fmod(t, 6.0)
			if ph > 1.0 and ph < 4.0:
				Input.action_press("dash")
			else:
				Input.action_release("dash")
			if ph > 4.5 and ph < 4.6:
				Input.action_press("jump")
			else:
				Input.action_release("jump")
			if ph > 5.2 and ph < 5.3:
				Input.action_press("leap")
			else:
				Input.action_release("leap")
		await get_tree().process_frame
	for an in ["forward", "dash", "jump", "leap"]:
		Input.action_release(an)
	await get_tree().create_timer(5.0).timeout
	var b := census()
	print("SON: %d parçacık düğümü (%.0f sn)" % [total(b), sec])
	var keys: Array = b.keys()
	keys.sort_custom(func(x, y): return int(b[x]) - int(a.get(x, 0)) > int(b[y]) - int(a.get(y, 0)))
	for k in keys.slice(0, 14):
		print("  +%d (şimdi %d)  %s" % [int(b[k]) - int(a.get(k, 0)), int(b[k]), k])
	get_tree().quit()
