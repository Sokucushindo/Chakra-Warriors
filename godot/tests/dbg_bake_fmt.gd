extends Node
var main: Node
func _f(path: String) -> void:
	var root = (ResourceLoader.load(path) as PackedScene).instantiate()
	var fm := {}
	var mats := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if n.mesh == null:
			continue
		for s in n.mesh.get_surface_count():
			var a = n.mesh.surface_get_arrays(s)
			var parts = []
			for i in Mesh.ARRAY_MAX:
				if a[i] != null:
					parts.append(i)
			var k = str(parts) + " " + n.mesh.get_class() + " fmt=" + str(n.mesh.surface_get_format(s) if n.mesh is ArrayMesh else -1)
			fm[k] = int(fm.get(k, 0)) + 1
			var m = n.mesh.surface_get_material(s)
			var mk = (m.get_class() + ":" + (m.resource_path if m.resource_path != "" else "embedded")) if m else "null"
			mats[mk] = int(mats.get(mk, 0)) + 1
		var mo = n.material_override
		if mo:
			var mk2 = "ovr " + mo.get_class() + ":" + (mo.resource_path if mo.resource_path != "" else "embedded")
			mats[mk2] = int(mats.get(mk2, 0)) + 1
	print("BF ", path.get_file(), " formats=", fm)
	print("BF ", path.get_file(), " mats=", mats)
	root.free()
func _ready() -> void:
	_f("D:/Naruto 3D Game/_tmp/bake_dev/kiri_c3404b9803ca.scn")
	_f("D:/Naruto 3D Game/godot/data/bake/kiri_36b1e58530dd.scn")
	get_tree().quit()
