extends Node
## Konoha sahne ağacı dökümü: düğüm / şekil türleri (köyü sahneye eklemek ~2,7 sn sürüyor)
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12),
		"top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	var _n0 := 0
	for w in [1, 5, 10, 20]:
		await get_tree().create_timer(float(w) if w == 1 else 5.0 if w == 5 else 5.0 if w == 10 else 10.0).timeout
		var _c = 0
		for n in main.world.find_children("*", "MultiMeshInstance3D", true, false):
			_c += 1
		print("KS t+%d: MMI %d, kare süresi %.1f ms" % [w, _c, 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)])
	var best: Node = null
	var bn := 0
	for n in main.world.find_children("*", "Node3D", true, false):
		if String(n.name).to_lower().begins_with("konoha"):
			var c = n.find_children("*", "", true, false).size()
			if c > bn:
				bn = c
				best = n
	print("KS konoha kökü: %s, %d düğüm" % [best.name if best else "yok", bn])
	if best == null:
		get_tree().quit()
		return
	var cls := {}
	var shp := {}
	var bodies := {}
	for n in best.find_children("*", "", true, false):
		cls[n.get_class()] = int(cls.get(n.get_class(), 0)) + 1
		if n is CollisionShape3D and n.shape:
			var k = n.shape.get_class()
			shp[k] = int(shp.get(k, 0)) + 1
		if n is StaticBody3D:
			var cnt = n.get_children().filter(func(c): return c is CollisionShape3D).size()
			var b = "1" if cnt <= 1 else ("2-10" if cnt <= 10 else ("11-100" if cnt <= 100 else ">100"))
			bodies[b] = int(bodies.get(b, 0)) + 1
	for k in cls:
		if cls[k] > 50:
			print("KS sınıf %6d %s" % [cls[k], k])
	for k in shp:
		print("KS şekil %6d %s" % [shp[k], k])
	for k in bodies:
		print("KS gövde(şekil sayısı %s): %d" % [k, bodies[k]])
	# tek şekilli gövde: boyut dağılımı (BoxShape3D)
	var small := 0
	var tiny := 0
	for n in best.find_children("*", "CollisionShape3D", true, false):
		if n.shape is BoxShape3D:
			var sz: Vector3 = n.shape.size
			if sz.x * sz.y * sz.z < 0.5:
				tiny += 1
			elif sz.x * sz.y * sz.z < 4.0:
				small += 1
	var rh := {}
	var hh := {}
	for n in best.find_children("*", "CollisionShape3D", true, false):
		if n.shape is CapsuleShape3D:
			var r: float = n.shape.radius
			var k = "r<0.15" if r < 0.15 else ("r<0.2" if r < 0.2 else ("r<0.3" if r < 0.3 else ("r<0.5" if r < 0.5 else "r>=0.5")))
			rh[k] = int(rh.get(k, 0)) + 1
			var y = n.global_position.y - Game.terrain_height(n.global_position.x, n.global_position.z)
			var hk = "y<3" if y < 3.0 else ("y<6" if y < 6.0 else ("y<10" if y < 10.0 else "y>=10"))
			hh[hk] = int(hh.get(hk, 0)) + 1
	print("KS kapsül yarıçap: ", rh)
	print("KS kapsül yükseklik: ", hh)
	var ih := {}
	var tot := 0
	var meshes := {}
	for n in best.find_children("*", "MultiMeshInstance3D", true, false):
		var c: int = n.multimesh.instance_count
		tot += c
		var k = "1" if c == 1 else ("2-3" if c <= 3 else ("4-10" if c <= 10 else ("11-50" if c <= 50 else ">50")))
		ih[k] = int(ih.get(k, 0)) + 1
		meshes[n.multimesh.mesh] = true
	print("KS MMI örnek dağılımı: ", ih, " toplam örnek ", tot, " farklı mesh ", meshes.size())
	print("KS kutu <0.5 m3: %d, <4 m3: %d" % [tiny, small])
	get_tree().quit()
