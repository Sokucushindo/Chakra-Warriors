extends RefCounted
## Model verisini ekran kartından geri OKUMADAN almak: surface_get_arrays her çağrıda ana akışı ekran kartının işini
## bitirmesini beklemeye zorluyordu (NPC kurulumunda her yerde FPS çöküşü). Oyunun ürettiği modeller verisini "_arr"
## meta'sına iliştirir; okunması gereken başka modeller bir kez okunup saklanır.


## Yüzey dizileri (dış kap kopyası: çağıran diziyi değiştirse de saklanan bozulmaz; paketli diziler zaten kopyala-yaz)
static func get_arrays(m: Mesh, si: int = 0) -> Array:
	if m == null:
		return []
	var memo: Array = m.get_meta("_arr", []) if m.has_meta("_arr") else []
	if si < memo.size() and memo[si] is Array and not (memo[si] as Array).is_empty():
		return (memo[si] as Array).duplicate()
	var a: Array = m.surface_get_arrays(si)
	if memo.size() <= si:
		memo.resize(si + 1)
	memo[si] = a
	m.set_meta("_arr", memo)
	return a.duplicate()


## SurfaceTool.commit yerine: aynı modeli kurar ve verisini iliştirir
static func commit(st: SurfaceTool, into: ArrayMesh = null) -> ArrayMesh:
	var arrs := st.commit_to_arrays()
	var m := into if into != null else ArrayMesh.new()
	var si := m.get_surface_count()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	var memo: Array = m.get_meta("_arr", []) if m.has_meta("_arr") else []
	if memo.size() <= si:
		memo.resize(si + 1)
	memo[si] = arrs
	m.set_meta("_arr", memo)
	return m
