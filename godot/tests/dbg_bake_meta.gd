extends Node
var main: Node
func _f(path: String) -> void:
	var root = (ResourceLoader.load(path) as PackedScene).instantiate()
	var tot := {}
	var nodes = [root] + root.find_children("*", "", true, false)
	for n in nodes:
		for m in n.get_meta_list():
			var sz = var_to_bytes(n.get_meta(m)).size()
			tot[m] = int(tot.get(m, 0)) + sz
	var mm_bytes = 0
	for n in root.find_children("*", "MultiMeshInstance3D", true, false):
		if n.multimesh:
			mm_bytes += n.multimesh.buffer.size() * 4
	var mesh_bytes = 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if n.mesh:
			for s in n.mesh.get_surface_count():
				mesh_bytes += var_to_bytes(n.mesh.surface_get_arrays(s)).size()
	var col = 0
	for n in root.find_children("*", "CollisionShape3D", true, false):
		if n.shape:
			col += var_to_bytes(n.shape.get("data") if n.shape is ConcavePolygonShape3D else 0).size()
	print("BM ", path.get_file(), " meta=", tot, " mm=", mm_bytes, " mesh=", mesh_bytes, " col=", col)
	root.free()
func _ready() -> void:
	_f("D:/Naruto 3D Game/_tmp/bake_dev/kiri_c3404b9803ca.scn")
	_f("D:/Naruto 3D Game/godot/data/bake/kiri_36b1e58530dd.scn")
	get_tree().quit()
