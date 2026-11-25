extends Node
var main: Node
func _f(path: String) -> void:
	var root = (ResourceLoader.load(path) as PackedScene).instantiate()
	var uniq := {}
	var uses := 0
	var by_name := {}
	for n in root.find_children("*", "", true, false):
		var m = null
		if n is MeshInstance3D: m = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh: m = n.multimesh.mesh
		if m == null: continue
		uses += 1
		var id = m.get_instance_id()
		if not uniq.has(id):
			uniq[id] = 0
			var sz = 0
			for s in m.get_surface_count():
				sz += (m.surface_get_arrays(s)[0] as PackedVector3Array).size()
			var par = String(n.get_parent().name).rstrip("0123456789@_").left(20)
			by_name[par] = by_name.get(par, [0, 0])
			by_name[par][0] += 1
			by_name[par][1] += sz
	var rows = []
	for k in by_name: rows.append([by_name[k][1], k, by_name[k][0]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("BS ", path.get_file(), " kullanim=", uses, " benzersiz=", uniq.size(), " ilk=", rows.slice(0, 8))
	root.free()
func _ready() -> void:
	_f("D:/Naruto 3D Game/_tmp/bake_dev/kiri_c3404b9803ca.scn")
	_f("D:/Naruto 3D Game/godot/data/bake/kiri_36b1e58530dd.scn")
	get_tree().quit()
