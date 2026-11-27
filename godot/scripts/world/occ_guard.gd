## OccGuard (preload ile: const OccGuard = preload("res://scripts/world/occ_guard.gd"))
extends RefCounted
## Kamera gizleyici (OccluderInstance3D) kutusunun içine düşmesin: Godot içinde kalınan gizleyicinin arkasındaki HER ŞEYİ
## gizler ("kamera binalara yaklaşınca etraf yok oluyor"). Ev gizleyicileri kayıtlı ev ölçüsünden kurulur; kayıt saçak /
## sundurmayı da içerdiğinden kutu bazı evlerde duvardan 1 m'ye kadar taşar (ölçüm: tests/test_cam_occ.gd, kameranın %16-18'i
## kutu içindeydi). Kutular köy kurulunca / önbellekten yüklenince kaydedilir; oyuncu kamerası her karede yakınındakilere bakar.

const CELL := 32.0
static var grid := {}   # Vector2i -> [[düğüm, v0, ex, ey, ez], ...]


static func add(oi: OccluderInstance3D) -> void:
	var oc = oi.occluder
	if not oc is ArrayOccluder3D or not oi.is_inside_tree():
		return
	var vs: PackedVector3Array = oc.vertices
	var xf: Transform3D = oi.global_transform
	for i in range(0, vs.size() - 7, 8):   # Builder.build_occluders: kutu başına 8 köşe (0..3 alt --, -+, +-, ++; 4..7 üst)
		var v0: Vector3 = xf * vs[i]
		var rec = [oi, v0, xf * vs[i + 2] - v0, xf * vs[i + 4] - v0, xf * vs[i + 1] - v0]
		var c: Vector3 = v0 + (rec[2] + rec[4]) * 0.5
		var r = ((rec[2] as Vector3).length() + (rec[4] as Vector3).length()) * 0.5
		for cx in range(floori((c.x - r) / CELL), floori((c.x + r) / CELL) + 1):
			for cz in range(floori((c.z - r) / CELL), floori((c.z + r) / CELL) + 1):
				var k = Vector2i(cx, cz)
				if not grid.has(k):
					grid[k] = []
				grid[k].append(rec)


## Köy kökü (önbellekten yüklenen sahne) altındaki tüm gizleyiciler
static func scan(root: Node) -> void:
	for oi in root.find_children("*", "OccluderInstance3D", true, false):
		add(oi)


static func inside(p: Vector3, margin := 0.35) -> bool:
	var lst = grid.get(Vector2i(floori(p.x / CELL), floori(p.z / CELL)))
	if lst == null:
		return false
	var dead := false
	for rec in lst:
		if not is_instance_valid(rec[0]):
			dead = true
			continue
		var d: Vector3 = p - rec[1]
		var ok := true
		for k in [2, 3, 4]:
			var e: Vector3 = rec[k]
			var L = e.length()
			var t = d.dot(e) / L
			if t < -margin or t > L + margin:
				ok = false
				break
		if ok:
			return true
	if dead:   # köy silindi: kayıtları temizle
		grid[Vector2i(floori(p.x / CELL), floori(p.z / CELL))] = lst.filter(func(r): return is_instance_valid(r[0]))
	return false
