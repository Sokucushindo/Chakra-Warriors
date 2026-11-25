extends Node
## İki köy önbelleğini karşılaştır: düğüm türü / ad ön ekine göre köşe + örnek sayısı
var main: Node
func _stats(path: String) -> Dictionary:
	var ps: PackedScene = ResourceLoader.load(path)
	var root = ps.instantiate()
	var out := {}
	for n in root.find_children("*", "", true, false):
		var key = n.get_class() + ":" + String(n.name).rstrip("0123456789@_").left(18)
		var v := 0
		if n is MeshInstance3D and n.mesh:
			for s in n.mesh.get_surface_count():
				v += (n.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		elif n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
			v = n.multimesh.instance_count
		elif n is CollisionShape3D and n.shape is ConcavePolygonShape3D:
			v = (n.shape as ConcavePolygonShape3D).get_faces().size()
		if not out.has(key):
			out[key] = [0, 0]
		out[key][0] += 1
		out[key][1] += v
	root.free()
	return out
func _ready() -> void:
	for vid in OS.get_environment("VIDS").split(","):
		var a = _stats(OS.get_environment("OLD").replace("VID", vid))
		var b = _stats(OS.get_environment("NEW").replace("VID", vid))
		var rows = []
		for k in b:
			var o = a.get(k, [0, 0])
			if b[k][1] - o[1] != 0 or b[k][0] - o[0] != 0:
				rows.append([b[k][1] - o[1], k, o, b[k]])
		for k in a:
			if not b.has(k):
				rows.append([-a[k][1], k, a[k], [0, 0]])
		rows.sort_custom(func(x, y): return absi(x[0]) > absi(y[0]))
		for r in rows.slice(0, 15):
			print("BD %s %s fark=%d eski=%s yeni=%s" % [vid, r[1], r[0], str(r[2]), str(r[3])])
	get_tree().quit()
