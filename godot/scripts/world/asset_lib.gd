class_name AssetLib
extends RefCounted
## Hazır 3B model paketleri (assets/packs, assets/sketchfab) için yükleyici:
## sahneyi tek bir ArrayMesh'e birleştirir (malzeme başına bir yüzey), ölçekler, zemine oturtur,
## malzemeleri anime ışığına (asset_toon) çevirir. Sonuçlar önbelleğe alınır; MultiMesh ile kullanılır.

const FOLIAGE_WORDS := ["leaf", "leaves", "grass", "flower", "petal", "bush", "fern", "clover", "plant", "foliage", "bamboo", "needle"]

static var _cache := {}
static var _mats := {}
static var _sizes := {}


static var _parts := {}   # "yol|düğüm" -> [[mesh, yüzey, xform], AABB]


## path: glTF/GLB; height > 0 ise o yüksekliğe ölçeklenir (yoksa scale çarpanı); zemin y=0, xz merkezlenir
static func mesh(path: String, height := 0.0, scale := 1.0, opts := {}) -> ArrayMesh:
	if OS.get_environment("ASSET_PACKS") == "0":
		return null
	var key = "%s|%.3f|%.3f|%s" % [path, height, scale, str(opts)]
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		push_warning("AssetLib: yok " + path)
		_cache[key] = null
		return null
	# parçalar + sınırlar (yol|düğüm başına bir kez): aynı sahneyi her çağrıda yeniden açıp tüm köşeleri
	# GDScript'te gezmek kasaba evlerinde açılışa ~8 sn ekliyordu
	var pk = path + "|" + String(opts.get("node", ""))
	if not _parts.has(pk):
		var ps: PackedScene = load(path)
		var root: Node = ps.instantiate()
		var pl: Array = []  # [mesh, surface, xform]
		_collect(root, Transform3D.IDENTITY, pl, true, String(opts.get("node", "")), String(opts.get("node", "")) == "")
		var ab0 := AABB()
		var first := true
		for p in pl:
			var m: Mesh = p[0]
			var arr = m.surface_get_arrays(p[1])
			for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var w: Vector3 = p[2] * v
				if first:
					ab0 = AABB(w, Vector3.ZERO)
					first = false
				else:
					ab0 = ab0.expand(w)
		root.free()
		_parts[pk] = [pl, ab0]
	var parts: Array = _parts[pk][0]
	var ab: AABB = _parts[pk][1]
	var s = scale
	if height > 0.0 and ab.size.y > 0.001:
		s = height / ab.size.y
	var center = ab.get_center()
	var fix = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(-center.x * s, -ab.position.y * s, -center.z * s))
	if opts.get("keep_origin", false):
		fix = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO)
	if opts.has("yaw"):
		fix = Transform3D(Basis(Vector3.UP, deg_to_rad(float(opts["yaw"]))), Vector3.ZERO) * fix
	# malzemeye göre grupla
	var groups := {}   # mat key -> [SurfaceTool, ShaderMaterial]
	var only: String = opts.get("only", "")      # yalnızca adı bunu içeren malzemeler
	var skip: String = opts.get("skip", "")
	for p in parts:
		var m: Mesh = p[0]
		var sm: Material = m.surface_get_material(p[1])
		var mname = (sm.resource_name if sm else "").to_lower()
		if only != "" and not mname.contains(only):
			continue
		if skip != "" and mname.contains(skip):
			continue
		var mk = str(sm.get_instance_id()) if sm else "none"
		if not groups.has(mk):
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[mk] = [st, convert_material(sm, opts)]
		var stt: SurfaceTool = groups[mk][0]
		stt.append_from(m, p[1], fix * p[2])
	var out = ArrayMesh.new()
	for mk in groups:
		var st: SurfaceTool = groups[mk][0]
		var a = st.commit_to_arrays()
		if a[Mesh.ARRAY_VERTEX] == null or (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		# MultiMesh örnek rengi COLOR ile gelsin: vertex rengini beyaz yap
		var n = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if a[Mesh.ARRAY_COLOR] == null:
			var cols = PackedColorArray()
			cols.resize(n)
			cols.fill(Color.WHITE)
			a[Mesh.ARRAY_COLOR] = cols
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		out.surface_set_material(out.get_surface_count() - 1, groups[mk][1])
	_sizes[key] = ab.size * s
	_cache[key] = out
	return out


static func size_of(path: String, height := 0.0, scale := 1.0, opts := {}) -> Vector3:
	var key = "%s|%.3f|%.3f|%s" % [path, height, scale, str(opts)]
	if not _sizes.has(key):
		mesh(path, height, scale, opts)
	return _sizes.get(key, Vector3.ONE)


static func _collect(n: Node, xf: Transform3D, out: Array, is_root: bool, node_name := "", inside := true) -> void:
	var t = xf
	if n is Node3D and not is_root:
		t = xf * (n as Node3D).transform
	var ins = inside or (node_name != "" and String(n.name) == node_name)
	if ins and n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m: Mesh = (n as MeshInstance3D).mesh
		for i in m.get_surface_count():
			out.append([m, i, t])
	for c in n.get_children():
		_collect(c, t, out, false, node_name, ins)


## Bir malzemeyi anime ışıklı malzemeye çevirir (doku korunur)
static func convert_material(src: Material, opts := {}) -> ShaderMaterial:
	var key = (str(src.get_instance_id()) if src else "none") + str(opts.get("tint", "")) + str(opts.get("sway", "")) + str(opts.get("sat", ""))
	if _mats.has(key):
		return _mats[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/asset_toon.gdshader")
	var name = (src.resource_name if src else "").to_lower()
	var tex: Texture2D = null
	var col := Color.WHITE
	var transparent := false
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
		col = (src as BaseMaterial3D).albedo_color
		transparent = (src as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var foliage = transparent
	for w in FOLIAGE_WORDS:
		if name.contains(w):
			foliage = true
	if tex:
		m.set_shader_parameter("tex", tex)
	if opts.has("tint"):
		col = col * Color(opts["tint"])
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("cutout", foliage)
	if not foliage:
		m.set_shader_parameter("saturation", float(opts.get("sat", 1.0)))
	if foliage and opts.get("sway", true):
		m.set_shader_parameter("sway", float(opts.get("sway_amt", 0.08)))
		m.set_shader_parameter("sway_h", float(opts.get("sway_h", 6.0)))
	_mats[key] = m
	return m


## Bir sahneyi (bina, kapı, fener...) olduğu gibi örnekler; malzemeleri çevirir. height>0: o yüksekliğe ölçek.
static func instance(path: String, height := 0.0, scale := 1.0, opts := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh(path, height, scale, opts)
	return mi


## Otomatik basitleştirilmiş kopya (uzak mesafe): ratio = hedef üçgen oranı (0.1 = %10)
static func lod(m: ArrayMesh, ratio := 0.15) -> ArrayMesh:
	if m == null:
		return null
	var key = "lod|%d|%.3f" % [m.get_instance_id(), ratio]
	if _cache.has(key):
		return _cache[key]
	var out = ArrayMesh.new()
	for i in m.get_surface_count():
		var a = m.surface_get_arrays(i)
		var im = ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a)
		im.generate_lods(60.0, 25.0, [])
		var base: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var want = int(base.size() * ratio)
		var best: PackedInt32Array = base
		for li in im.get_surface_lod_count(0):
			var idx: PackedInt32Array = im.get_surface_lod_indices(0, li)
			best = idx
			if idx.size() <= want:
				break
		var b = a.duplicate()
		b[Mesh.ARRAY_INDEX] = best
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b)
		out.surface_set_material(i, m.surface_get_material(i))
	_cache[key] = out
	return out


## Aksesuarlar: kodla üretilen modeller (hazır model paketi kaldırıldı). anahtar -> varsayılan yükseklik (m)
const PROPS := {"torii_red": 7.0, "torii_small": 4.5, "bench": 1.0}   # bambu: Builder.prop oyunun anime bambusunu kullanır
const _PROP_REF := {"torii_red": 7.0, "torii_small": 7.0, "bench": 0.95}   # modelin kurulduğu boy


static func prop(kind: String, height := 0.0) -> ArrayMesh:
	if not PROPS.has(kind):
		return null
	var h: float = height if height > 0.0 else float(PROPS[kind])
	var key = "prop|%s|%.2f" % [kind, h]
	if _cache.has(key):
		return _cache[key]
	var s: float = h / float(_PROP_REF[kind])
	var mb := MB.new()
	match kind:
		"torii_red", "torii_small":
			_torii(mb, s)
		"bench":
			_bench(mb, s)
	var m: ArrayMesh = mb.build(Props.toon())
	_cache[key] = m
	return m


## Myōjin torii (7 m): içe hafif eğik iki direk + siyah taban, direkleri delip taşan nuki kirişi, ortada gakuzuka,
## kırmızı shimaki üstünde uçları yukarı kıvrık siyah kasagi
static func _torii(mb: MB, s: float) -> void:
	var red := Color(0.84, 0.2, 0.12)
	var red_d := Color(0.62, 0.12, 0.08)
	var blk := Color(0.12, 0.1, 0.1)
	var half := 2.3
	for sx in [-1.0, 1.0]:
		var lean: float = 2.2 * sx   # tepeleri içe
		mb.add_grad("cyl", Vector3(sx * half, 3.0, 0) * s, Vector3(0.6, 5.9, 0.6) * s, red, red_d, Vector3(0, 0, lean), 12)
		mb.add("cyl", Vector3(sx * half, 0.28, 0) * s, Vector3(0.82, 0.56, 0.82) * s, blk, Vector3.ZERO, 12)   # kamaki (siyah taban)
		mb.add("cyl", Vector3(sx * half, 0.6, 0) * s, Vector3(0.7, 0.08, 0.7) * s, Color(0.75, 0.6, 0.2), Vector3.ZERO, 12)   # pirinç bilezik
	mb.add("box", Vector3(0, 4.55, 0) * s, Vector3(6.5, 0.36, 0.26) * s, red)          # nuki
	mb.add("box", Vector3(0, 5.12, 0) * s, Vector3(0.36, 0.78, 0.24) * s, red_d)       # gakuzuka
	mb.add("box", Vector3(0, 5.62, 0) * s, Vector3(6.0, 0.34, 0.34) * s, red)          # shimaki
	mb.add("box", Vector3(0, 5.98, 0) * s, Vector3(5.0, 0.4, 0.5) * s, blk)            # kasagi orta
	for sx in [-1.0, 1.0]:
		# kasagi kanatları: uca doğru yükselen iki parça (sorihashi kıvrımı)
		mb.add("box", Vector3(sx * 2.95, 6.03, 0) * s, Vector3(1.1, 0.4, 0.52) * s, blk, Vector3(0, 0, 5.0 * sx))
		mb.add("box", Vector3(sx * 3.7, 6.16, 0) * s, Vector3(0.75, 0.36, 0.5) * s, blk, Vector3(0, 0, 14.0 * sx))
	mb.add("box", Vector3(0, 6.22, 0) * s, Vector3(4.6, 0.1, 0.42) * s, Color(0.2, 0.17, 0.16))   # üst sırt


## Ahşap bank: üç tahta oturak, iki ayak çerçevesi, eğik iki tahta arkalık
static func _bench(mb: MB, s: float) -> void:
	var wood := Color(0.62, 0.44, 0.27)
	var wood_d := Color(0.38, 0.26, 0.16)
	for k in 3:
		mb.add("box", Vector3(0, 0.46, -0.16 + k * 0.16) * s, Vector3(1.9, 0.05, 0.14) * s, wood.lightened(0.04 * k))
	for sx in [-1.0, 1.0]:
		mb.add("box", Vector3(sx * 0.78, 0.22, 0.12) * s, Vector3(0.08, 0.44, 0.08) * s, wood_d)
		mb.add("box", Vector3(sx * 0.78, 0.22, -0.16) * s, Vector3(0.08, 0.44, 0.08) * s, wood_d)
		mb.add("box", Vector3(sx * 0.78, 0.41, -0.02) * s, Vector3(0.08, 0.06, 0.46) * s, wood_d)   # oturak taşıyıcı
		mb.add("box", Vector3(sx * 0.78, 0.68, 0.25) * s, Vector3(0.07, 0.56, 0.07) * s, wood_d, Vector3(-12, 0, 0))   # arkalık dikmesi
		mb.add("box", Vector3(sx * 0.78, 0.1, -0.02) * s, Vector3(0.07, 0.05, 0.4) * s, wood_d)   # alt bağ
	mb.add("box", Vector3(0, 0.66, 0.27) * s, Vector3(1.86, 0.11, 0.035) * s, wood, Vector3(-12, 0, 0))
	mb.add("box", Vector3(0, 0.86, 0.31) * s, Vector3(1.86, 0.11, 0.035) * s, wood.lightened(0.05), Vector3(-12, 0, 0))


## Hazır Japon kasaba evleri (Sketchfab "Stylized Little Japanese Town Street"): [[mesh, boyut], ...]
const TOWN_STREET := "res://assets/sketchfab/jp_town_street/jp_town_street.glb"
const TOWN_HOUSES := ["DomekRdy_1", "DomekRdy_2", "DomekRdy_3", "DomekRdy_4", "DomekRdy_5", "DomekRdy_Ksiegarnia", "DomekRdy_Kwiaciarnia"]
static var _houses: Array = []
static func town_houses() -> Array:
	if not _houses.is_empty() or not ResourceLoader.exists(TOWN_STREET):
		return _houses
	# ortak ölçek: en uzun ev ~11 m
	var hmax = 0.0
	for nm in TOWN_HOUSES:
		hmax = maxf(hmax, size_of(TOWN_STREET, 0.0, 1.0, {"node": nm, "sway": false}).y)
	if hmax <= 0.0:
		return _houses
	var sc = 11.0 / hmax
	for nm in TOWN_HOUSES:
		var m = mesh(TOWN_STREET, 0.0, sc, {"node": nm, "sway": false, "sat": 0.72, "tint": Color(1.0, 0.96, 0.9)})
		if m != null and m.get_surface_count() > 0:
			_houses.append([m, size_of(TOWN_STREET, 0.0, sc, {"node": nm, "sway": false, "sat": 0.72, "tint": Color(1.0, 0.96, 0.9)})])
	return _houses


## Büyük Japon tapınağı (pagoda) — Sketchfab "Japanese Shrine"
const TEMPLE := "res://assets/sketchfab/jp_temple/jp_temple.glb"
static func temple(height := 26.0) -> ArrayMesh:
	return mesh(TEMPLE, height, 1.0, {"sway": false})


## Stilize kaya parçaları (Sketchfab "Free Pack - Rocks Stylized"): her biri ayrı mesh
const ROCKS := "res://assets/sketchfab/rocks_stylized/rocks_stylized.glb"
static func rock_parts(height: float) -> Array:
	var out = []
	if not ResourceLoader.exists(ROCKS):
		return out
	var ps: PackedScene = load(ROCKS)
	var r = ps.instantiate()
	var names = []
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		names.append(String(mi.get_parent().name) if String(mi.name).begins_with("Object") else String(mi.name))
	r.free()
	for nm in names:
		var m = mesh(ROCKS, height, 1.0, {"node": nm, "sway": false})
		if m != null and m.get_surface_count() > 0:
			out.append(m)
	return out
