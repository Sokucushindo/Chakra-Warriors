extends RefCounted
## Model verisini ekran kartından geri OKUMADAN almak: surface_get_arrays her çağrıda ana akışı ekran kartının işini
## bitirmesini beklemeye zorluyordu (NPC kurulumunda her yerde FPS çöküşü). Oyunun ürettiği modeller verisini "_arr"
## meta'sına iliştirir; okunması gereken başka modeller bir kez okunup saklanır.


## Yüzey dizileri: DERİN kopya (paketli diziler paylaşılır: çağıran köşeleri yerinde değiştirince saklanan veri bozuluyor,
## yüz varyantları "Invalid array format" ile kurulamıyordu). Saklama kilitli: arka plan işi (yüz / saç) ile ana akış aynı anda yazar.
static var _mx := Mutex.new()
static func get_arrays(m: Mesh, si: int = 0) -> Array:
	if m == null:
		return []
	_mx.lock()
	var memo: Array = m.get_meta("_arr", []) if m.has_meta("_arr") else []
	if si < memo.size() and memo[si] is Array and not (memo[si] as Array).is_empty():
		var c: Array = (memo[si] as Array).duplicate(true)
		_mx.unlock()
		return c
	_mx.unlock()
	var a: Array = m.surface_get_arrays(si)
	_mx.lock()
	memo = m.get_meta("_arr", []) if m.has_meta("_arr") else []
	if memo.size() <= si:
		memo.resize(si + 1)
	memo[si] = a
	m.set_meta("_arr", memo)
	_mx.unlock()
	return a.duplicate(true)


## SurfaceTool.commit yerine: aynı modeli kurar ve verisini iliştirir
static func commit(st: SurfaceTool, into: ArrayMesh = null) -> ArrayMesh:
	var arrs := st.commit_to_arrays()
	var m := into if into != null else ArrayMesh.new()
	var si := m.get_surface_count()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	_mx.lock()
	var memo: Array = m.get_meta("_arr", []) if m.has_meta("_arr") else []
	if memo.size() <= si:
		memo.resize(si + 1)
	memo[si] = arrs
	m.set_meta("_arr", memo)
	_mx.unlock()
	return m
