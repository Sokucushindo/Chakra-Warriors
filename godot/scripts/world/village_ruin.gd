class_name VillageRuin
extends RefCounted
## Kalıcı köy yıkıntısı (köy saldırısı: WorldAssault.ruins()).
## Köyler önbellekten (VillageBake) yüklendiğinde evler WorldDamage'a kayıtlı değildir; bu yüzden yıkıntı köy sahnesindeki
## GERÇEK örnekler üzerinde çalışır: bölgedeki her MultiMesh örneği (ev duvarı, çatısı, ayrıntısı, köy içi ağaç, direk)
## gizlenir, o örneğe ait çarpışma şekilleri kapatılır, evlerin yerine moloz yığını (çarpışmalı) konur. Uzak görünümde
## hücrenin birleşik kabuğu (tek mesh) gizlenir, yerine o hücrenin yakın örnekleri uzaktan da çizilir.
## Bölge küçüldükçe (onarım, dışından içine) dışında kalan örnekler eski hâline döner. Girilebilen / etkileşimli binalar
## (dükkân, görev yeri) ayakta kalır.

const GCELL := 12.0
const VL = preload("res://scripts/world/village_life.gd")
const BAND := 18.0       # onarım cephesi: bölge kenarından içeri bu kadar metredeki evler inşa hâlinde (iskele + yükselen duvar)
const MAX_SITES := 4     # aynı anda işçi çalışan şantiye
static var _z := {}     # bölge kimliği -> {root, busy, groups, shells, ext, r_idx, applied}
static var _t := 0.0
static var _vs: WeakRef = null
static var _kon: WeakRef = null


static func _root_of(vid: String) -> Node3D:
	if Game.world == null:
		return null
	if vid == "konoha":
		if _kon == null or _kon.get_ref() == null:
			var n = Game.world.find_child("Konoha", true, false)
			if n == null:
				return null
			_kon = weakref(n)
		return _kon.get_ref()
	if _vs == null or _vs.get_ref() == null:
		var n2 = Game.world.find_child("VillageStream", true, false)
		if n2 == null:
			return null
		_vs = weakref(n2)
	var vs = _vs.get_ref()
	var rec = vs.built.get(vid)
	if rec == null or not rec.get("done", false):
		return null
	return vs.get_node_or_null("Koy_" + vid)


static func _drop(st: Dictionary, restore: bool, host: Node) -> void:
	if restore and st.get("root_ref") != null and st["root_ref"].get_ref() != null and not st.get("busy", false):
		_apply(st, -1.0, false, host)
	for g in st.get("groups", []):
		var rb = g.get("rubble")
		if rb != null and is_instance_valid(rb):
			rb.queue_free()
		var rc = g.get("rubble_cs")
		if rc != null and is_instance_valid(rc):
			rc.queue_free()
		_site_end(g)
	for pair in st.get("sites", []):
		pair[0]["off"] = true
	for e in st.get("cm", []):
		if is_instance_valid(e["mi"]):
			e["mi"].mesh = e["orig"]
	st["dead"] = true


static func tick(dt: float, host: Node) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	var zones: Array = WorldAssault.ruins()
	for id in _z.keys():
		if not zones.any(func(z): return int(z.get("id", 0)) == id):
			_drop(_z[id], true, host)
			_z.erase(id)
	if zones.is_empty() or Game.player == null:
		return
	var pp: Vector3 = Game.player.global_position
	for z in zones:
		var id = int(z.get("id", 0))
		var root = _root_of(String(z["vid"]))
		var st = _z.get(id)
		if root == null:
			if st != null:
				_drop(st, false, host)
				_z.erase(id)
			continue
		if st != null and not st.get("busy", false) and (st["root_ref"].get_ref() != root or float(z["r"]) > float(st["r_idx"]) + 0.5):
			_drop(st, st["root_ref"].get_ref() == root, host)
			_z.erase(id)
			st = null
		if st == null:
			if Vector2(pp.x - float(z["x"]), pp.z - float(z["z"])).length() > float(z["r"]) + 1600.0:
				continue
			st = {"root_ref": weakref(root), "busy": true, "groups": [], "shells": [], "ext": [], "r_idx": float(z.get("r_max", z["r"])), "applied": -1.0,
				"cells_on": String(z["vid"]) != "konoha", "cm": []}
			_z[id] = st
			_index(st, z, root, host)
			continue
		if st.get("busy", false):
			continue
		var rr = WorldAssault.ruin_r(z)
		if absf(rr - float(st["applied"])) > 0.75 or st.get("pending", false):
			_apply(st, rr, z.get("live", false), host)
			if not z.get("live", false):
				_rebuild(st, z, rr, host)


static func _hits(ab: AABB, c: Vector2, r: float) -> bool:
	var dx = maxf(maxf(ab.position.x - c.x, c.x - ab.end.x), 0.0)
	var dz = maxf(maxf(ab.position.z - c.y, c.y - ab.end.z), 0.0)
	return dx * dx + dz * dz <= r * r


## Bölgenin (en büyük yarıçapıyla) kapsadığı örnekleri, kabukları ve çarpışma şekillerini çıkarır. Kare başına ~4 ms.
static func _index(st: Dictionary, z: Dictionary, root: Node3D, host: Node) -> void:
	var tree = host.get_tree()
	var c = Vector2(float(z["x"]), float(z["z"]))
	var R = float(st["r_idx"]) + 2.0
	var t0 = Time.get_ticks_usec()
	var shells: Array = []
	var begins: Array = []
	var cells_on: bool = st.get("cells_on", false)
	var cm: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if cells_on:
			if mi.mesh is ArrayMesh and _hits(mi.global_transform * mi.get_aabb(), c, R):
				cm.append({"mi": mi, "orig": mi.mesh, "ab": mi.global_transform * mi.get_aabb(), "sig": 0})
			continue
		if mi.visibility_range_begin > 1.0 and mi.mesh != null:
			if not mi.visibility_range_begin in begins:
				begins.append(mi.visibility_range_begin)
			var sab: AABB = mi.global_transform * mi.get_aabb()
			if _hits(sab, c, R):
				shells.append([mi, sab])
	var groups := {}
	var ext: Array = []
	var n = 0
	for mmi in root.find_children("*", "MultiMeshInstance3D", true, false):
		n += 1
		if n % 200 == 0 and Time.get_ticks_usec() - t0 > 4000:
			await tree.process_frame
			t0 = Time.get_ticks_usec()
			if st.get("dead", false) or not is_instance_valid(root):
				return
		if not is_instance_valid(mmi):
			continue
		var mm: MultiMesh = mmi.multimesh
		if mm == null or mm.mesh == null or mm.instance_count == 0:
			continue
		var gx: Transform3D = mmi.global_transform
		var ab: AABB = gx * mmi.get_aabb()
		var house_part = false
		for b in begins:
			if absf(mmi.visibility_range_end - float(b)) < 1.5:
				house_part = true
				break
		if house_part and not shells.is_empty():
			var mc = ab.get_center()
			for sh in shells:
				var sa: AABB = sh[1]
				if mc.x >= sa.position.x and mc.x <= sa.end.x and mc.z >= sa.position.z and mc.z <= sa.end.z:
					ext.append([mmi, mmi.visibility_range_end, sh[0]])
					break
		if not _hits(ab, c, R):
			continue
		var mab: AABB = mm.mesh.get_aabb()
		for i in mm.instance_count:
			var xf: Transform3D = mm.get_instance_transform(i)
			var sc = xf.basis.get_scale()
			if sc.x < 0.01:
				continue
			var gxf: Transform3D = gx * xf
			var o: Vector3 = gxf.origin
			var dist = Vector2(o.x - c.x, o.z - c.y).length()
			if dist > R:
				continue
			var key = Vector3i(roundi(o.x * 2.0), roundi(o.y * 2.0), roundi(o.z * 2.0))
			var g = groups.get(key)
			if g == null:
				g = {"pos": o, "dist": dist, "items": [], "w": 0.0, "d": 0.0, "h": 0.0, "house": false, "shapes": [], "hidden": false, "prot": false,
					"wall": Color(0.8, 0.76, 0.68), "roof": Color(0.55, 0.3, 0.22), "basis": gxf.basis.orthonormalized()}
				groups[key] = g
			var col = mm.get_instance_color(i) if mm.use_colors else Color.WHITE
			g["items"].append([mm, i, xf, gxf, col])
			g["w"] = maxf(g["w"], mab.size.x * sc.x)
			g["d"] = maxf(g["d"], mab.size.z * sc.z)
			g["h"] = maxf(g["h"], mab.end.y * sc.y)
			if house_part:
				g["house"] = true
				if mm.use_colors:
					if mab.position.y < 0.6:
						g["wall"] = col
					else:
						g["roof"] = col
	# girilebilen / etkileşimli binalar ayakta kalır
	var grid := {}
	for g in groups.values():
		if g["house"]:
			var pr = maxf(g["w"], g["d"]) * 0.6 + 3.0
			var p: Vector3 = g["pos"]
			for it in Interact.items:
				var ip: Vector3 = it["pos"]
				if absf(ip.x - p.x) < pr and absf(ip.z - p.z) < pr:
					g["prot"] = true
					break
		if g["prot"]:
			continue
		var k = Vector2i(floori(g["pos"].x / GCELL), floori(g["pos"].z / GCELL))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(g)
	# çarpışma şekilleri: en yakın gizlenecek örneğe bağlanır
	var free: Array = []
	n = 0
	for cs in root.find_children("*", "CollisionShape3D", true, false):
		n += 1
		if n % 400 == 0 and Time.get_ticks_usec() - t0 > 4000:
			await tree.process_frame
			t0 = Time.get_ticks_usec()
			if st.get("dead", false) or not is_instance_valid(root):
				return
		if not is_instance_valid(cs) or cs.shape == null or cs.shape is ConcavePolygonShape3D or cs.disabled:
			continue
		var gp: Vector3 = cs.global_position
		if absf(gp.x - c.x) > R or absf(gp.z - c.y) > R:
			continue
		if cs.shape is BoxShape3D and maxf(cs.shape.size.x, cs.shape.size.z) > 30.0:
			continue
		var ck = Vector2i(floori(gp.x / GCELL), floori(gp.z / GCELL))
		var best = null
		var bd = 1e9
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for g in grid.get(ck + Vector2i(dx, dz), []):
					var gpos: Vector3 = g["pos"]
					var dd = Vector2(gp.x - gpos.x, gp.z - gpos.z).length()
					if dd <= maxf(g["w"], g["d"]) * 0.5 + 0.6 and dd < bd:
						bd = dd
						best = g
		if best != null:
			best["shapes"].append(cs)
		elif cells_on:
			free.append(cs)
	var all_groups: Array = groups.values()
	if cells_on:
		all_groups.append_array(_cluster(free, c, R))
		st["cm"] = cm
	st["groups"] = all_groups
	st["shells"] = shells
	st["ext"] = ext
	st["busy"] = false


## Yarıçapa göre gizle / geri getir. rr < 0: hepsini geri getir.
static func _apply(st: Dictionary, rr: float, is_live: bool, host: Node) -> void:
	var pp: Vector3 = Game.player.global_position if Game.player != null else Vector3.ZERO
	var fx = 0
	var pending = false
	for g in st["groups"]:
		var want = rr >= 0.0 and float(g["dist"]) <= rr and not g["prot"]
		if want == g["hidden"]:
			continue
		var show_fx = want and is_live and g["house"] and (g["pos"] as Vector3).distance_to(pp) < 170.0
		if show_fx and fx >= 4:
			pending = true   # canlı saldırıda yakındaki evler sırayla çöker (dalga): kalanlar sonraki turda
			continue
		g["hidden"] = want
		for it in g["items"]:
			var mm: MultiMesh = it[0]
			if not is_instance_valid(mm):
				continue
			var xf: Transform3D = it[2]
			mm.set_instance_transform(it[1], Transform3D(xf.basis.scaled(Vector3.ONE * 0.001), xf.origin) if want else xf)
		for cs in g["shapes"]:
			if is_instance_valid(cs):
				cs.set_deferred("disabled", want)
		if want and g["house"]:
			_rubble(g, host, show_fx)
			if show_fx:
				fx += 1
				_collapse_fx(g, host)
		elif not want:
			_site_end(g)
			for k in ["rubble", "rubble_cs"]:
				var nd = g.get(k)
				if nd != null and is_instance_valid(nd):
					nd.queue_free()
				g.erase(k)
	if st.get("cells_on", false):
		st["pending"] = pending
		if not pending:
			st["applied"] = rr
		_cells_refresh(st, host)
		return
	# uzak kabuklar: bölgeye değen hücrenin birleşik mesh'i gizlenir, yakın örnekleri uzaktan da çizilir
	var any = false
	for g in st["groups"]:
		if g["hidden"]:
			any = true
			break
	for sh in st["shells"]:
		var mi = sh[0]
		if is_instance_valid(mi):
			mi.visible = not any
	for e in st["ext"]:
		var mmi = e[0]
		if is_instance_valid(mmi) and is_instance_valid(e[2]):
			mmi.visibility_range_end = e[2].visibility_range_end if any else float(e[1])
	st["pending"] = pending
	if not pending:
		st["applied"] = rr


# ------------------------------------------------------------------ birleşik hücreli köyler (Konoha dışı)
## Bu köylerde evler tek tek örnek değil: mahalle (hücre) başına birleştirilmiş mesh'in parçası. Ev = üst üste / yan yana
## çarpışma şekilleri kümesi. Bölgedeki şekiller evlere kümelenir (en büyük şekil çekirdek, merkezi onun taban izine düşenler
## üyesi); yıkılan evin taban izine düşen üçgenler hücre mesh'lerinin kopyasından çıkarılır (yakın / orta / uzak kademe hepsi).
static func _shape_foot(cs: CollisionShape3D) -> Array:
	var sh = cs.shape
	var gt: Transform3D = cs.global_transform
	var sc = gt.basis.get_scale()
	var o = gt.origin
	if sh is BoxShape3D:
		var up: Vector3 = gt.basis.y.normalized()
		if up.y < 0.9:
			return []   # eğik kutu (çatı yüzü, payanda): çekirdek olmaz
		var yaw = gt.basis.get_euler().y
		var hx = sh.size.x * sc.x * 0.5
		var hz = sh.size.z * sc.z * 0.5
		return [o.x, o.z, cos(yaw), sin(yaw), hx, hz, false, sqrt(hx * hx + hz * hz), sh.size.y * sc.y, o.y - sh.size.y * sc.y * 0.5]
	if sh is CylinderShape3D:
		var r = sh.radius * maxf(sc.x, sc.z)
		return [o.x, o.z, 1.0, 0.0, r, r, true, r, sh.height * sc.y, o.y - sh.height * sc.y * 0.5]
	if sh is ConvexPolygonShape3D:
		var r2 = 0.0
		var y0 = 1e9
		var y1 = -1e9
		for q in sh.points:
			var v: Vector3 = gt.basis * q
			r2 = maxf(r2, v.x * v.x + v.z * v.z)
			y0 = minf(y0, v.y)
			y1 = maxf(y1, v.y)
		var rc = sqrt(r2)
		return [o.x, o.z, 1.0, 0.0, rc, rc, true, rc, y1 - y0, o.y + y0]
	return []


static func _in_foot(f: Array, x: float, z: float, m: float) -> bool:
	var dx = x - float(f[0])
	var dz = z - float(f[1])
	if f[6]:
		var r = float(f[4]) + m
		return dx * dx + dz * dz <= r * r
	return absf(dx * float(f[2]) - dz * float(f[3])) <= float(f[4]) + m and absf(dx * float(f[3]) + dz * float(f[2])) <= float(f[5]) + m


static func _cluster(free: Array, c: Vector2, R: float) -> Array:
	var ents: Array = []
	for cs in free:
		var f = _shape_foot(cs)
		if f.is_empty() or float(f[8]) < 2.2:
			continue   # yassı döşeme / basamak ev değildir
		ents.append([f, cs])
	ents.sort_custom(func(a, b): return float(a[0][7]) > float(b[0][7]))
	var out: Array = []
	var grid := {}
	for e in ents:
		var f: Array = e[0]
		var k = Vector2i(floori(float(f[0]) / GCELL), floori(float(f[1]) / GCELL))
		var home = null
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for g in grid.get(k + Vector2i(dx, dz), []):
					if _in_foot(g["foot"][0], float(f[0]), float(f[1]), 0.8):
						home = g
						break
				if home != null:
					break
			if home != null:
				break
		if home != null:
			home["shapes"].append(e[1])
			home["foot"].append(f)
			home["h"] = maxf(float(home["h"]), float(f[9]) + float(f[8]) - (home["pos"] as Vector3).y)
			continue
		var rad = float(f[7])
		if rad < 1.8 or rad > 24.0 or float(f[8]) < 2.6:
			continue   # direk / çit çekirdek olmaz; dev yapılar (kule, sur, arena) ayakta kalır
		var dist = Vector2(float(f[0]) - c.x, float(f[1]) - c.y).length()
		if dist > R:
			continue
		var pos = Vector3(float(f[0]), Game.ground_height(float(f[0]), float(f[1])), float(f[1]))
		var prot = false
		for it in Interact.items:
			var ip: Vector3 = it["pos"]
			if _in_foot(f, ip.x, ip.z, 3.0):
				prot = true
				break
		var g2 = {"pos": pos, "dist": dist, "items": [], "w": float(f[4]) * 2.0, "d": float(f[5]) * 2.0, "h": float(f[9]) + float(f[8]) - pos.y, "house": true, "shapes": [e[1]],
			"hidden": false, "prot": prot, "wall": Color(0.8, 0.76, 0.68), "roof": Color(0.55, 0.3, 0.22), "basis": Basis(Vector3.UP, atan2(float(f[3]), float(f[2]))), "foot": [f], "cid": out.size() + 1}
		out.append(g2)
		if not grid.has(k):
			grid[k] = []
		grid[k].append(g2)
	return out


## Yıkık evlerin üçgenlerini hücre mesh'lerinden çıkarır (özgün mesh saklanır; ev onarılınca geri gelir). Kareler boyunca çalışır.
static func _cells_refresh(st: Dictionary, host: Node) -> void:
	if st.get("cm_busy", false):
		st["cm_again"] = true
		return
	st["cm_busy"] = true
	var tree = host.get_tree()
	while true:
		st["cm_again"] = false
		var down: Array = []
		for g in st["groups"]:
			if g.has("foot") and g["hidden"]:
				down.append(g)
		var t0 = Time.get_ticks_usec()
		for e in st["cm"]:
			var mi = e["mi"]
			if not is_instance_valid(mi):
				continue
			var ab: AABB = e["ab"]
			var grid := {}
			var sig = 0
			for g in down:
				for f in g["foot"]:
					var br = float(f[7]) + 1.5
					if float(f[0]) + br < ab.position.x or float(f[0]) - br > ab.end.x or float(f[1]) + br < ab.position.z or float(f[1]) - br > ab.end.z:
						continue
					sig = hash([sig, g["cid"], f[0], f[1]])
					for gx in range(floori((float(f[0]) - br) / 8.0), floori((float(f[0]) + br) / 8.0) + 1):
						for gz in range(floori((float(f[1]) - br) / 8.0), floori((float(f[1]) + br) / 8.0) + 1):
							var gk = Vector2i(gx, gz)
							if not grid.has(gk):
								grid[gk] = []
							grid[gk].append(f)
			if sig == int(e["sig"]):
				continue
			e["sig"] = sig
			if grid.is_empty():
				mi.mesh = e["orig"]
				continue
			var orig: ArrayMesh = e["orig"]
			var nm = ArrayMesh.new()
			var gt: Transform3D = mi.global_transform
			var ident = gt.is_equal_approx(Transform3D.IDENTITY)
			for s in orig.get_surface_count():
				var arr: Array = orig.surface_get_arrays(s)
				if orig.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
					nm.add_surface_from_arrays(orig.surface_get_primitive_type(s), arr)
					nm.surface_set_material(nm.get_surface_count() - 1, orig.surface_get_material(s))
					continue
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx = arr[Mesh.ARRAY_INDEX]
				var has_idx = idx != null and (idx as PackedInt32Array).size() > 0
				var cnt = ((idx as PackedInt32Array).size() if has_idx else vs.size()) / 3
				var keep = PackedInt32Array()
				for t in cnt:
					var i0 = idx[t * 3] if has_idx else t * 3
					var i1 = idx[t * 3 + 1] if has_idx else t * 3 + 1
					var i2 = idx[t * 3 + 2] if has_idx else t * 3 + 2
					var ctr: Vector3 = (vs[i0] + vs[i1] + vs[i2]) / 3.0
					if not ident:
						ctr = gt * ctr
					var lst = grid.get(Vector2i(floori(ctr.x / 8.0), floori(ctr.z / 8.0)))
					var kill = false
					if lst != null:
						for f in lst:
							if _in_foot(f, ctr.x, ctr.z, 1.0):
								kill = true
								break
					if not kill:
						keep.append(i0)
						keep.append(i1)
						keep.append(i2)
					if t % 3000 == 2999 and Time.get_ticks_usec() - t0 > 5000:
						await tree.process_frame
						t0 = Time.get_ticks_usec()
						if st.get("dead", false) or not is_instance_valid(mi):
							st["cm_busy"] = false
							return
				if keep.is_empty():
					continue
				arr[Mesh.ARRAY_INDEX] = keep
				nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				nm.surface_set_material(nm.get_surface_count() - 1, orig.surface_get_material(s))
			if st.get("dead", false) or not is_instance_valid(mi):
				st["cm_busy"] = false
				return
			mi.mesh = nm
		if not st.get("cm_again", false):
			break
	st["cm_busy"] = false


static func _rubble(g: Dictionary, host: Node, grow: bool) -> void:
	var w = clampf(snappedf(float(g["w"]), 2.0), 4.0, 26.0)
	var d = clampf(snappedf(float(g["d"]), 2.0), 4.0, 26.0)
	var wall: Color = (g["wall"] as Color).lerp(host.CHARCOAL, 0.3)
	var roof: Color = (g["roof"] as Color).lerp(Color(0.1, 0.09, 0.09), 0.3)
	var rub = MeshInstance3D.new()
	rub.mesh = host._rubble_wd(w, d, Color(snappedf(wall.r, 0.1), snappedf(wall.g, 0.1), snappedf(wall.b, 0.1)), Color(snappedf(roof.r, 0.1), snappedf(roof.g, 0.1), snappedf(roof.b, 0.1)))
	rub.layers = 2
	host.get_tree().current_scene.add_child(rub)
	var yaw = Basis(Vector3.UP, (g["basis"] as Basis).get_euler().y)
	rub.global_transform = Transform3D(yaw, g["pos"])
	g["rubble"] = rub
	if grow:
		rub.scale = Vector3(1, 0.05, 1)
		var tw = rub.create_tween()
		tw.tween_interval(0.9)
		tw.tween_property(rub, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(w * 0.85, 1.6, d * 0.85)
	cs.shape = bs
	host._body_node().add_child(cs)
	cs.global_transform = Transform3D(yaw, (g["pos"] as Vector3) + Vector3.UP * 0.8)
	g["rubble_cs"] = cs


## Gözünün önünde çöken ev: parçaları yerinde ezilir, toz ve moloz saçılır
static func _collapse_fx(g: Dictionary, host: Node) -> void:
	var scene = host.get_tree().current_scene
	var wp: Vector3 = g["pos"]
	var foot = maxf(float(g["w"]), float(g["d"]))
	for it in g["items"]:
		var mm: MultiMesh = it[0]
		if not is_instance_valid(mm) or mm.mesh == null or mm.mesh.get_aabb().size.y * (it[3] as Transform3D).basis.get_scale().y < 1.5:
			continue
		var mi = MeshInstance3D.new()
		mi.mesh = mm.mesh
		mi.layers = 2
		mi.material_override = host._tint_mat(it[4])
		scene.add_child(mi)
		mi.global_transform = it[3]
		var s0: Vector3 = mi.scale
		var tw = mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "scale", Vector3(s0.x * 1.06, s0.y * 0.06, s0.z * 1.06), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mi, "rotation:x", mi.rotation.x + deg_to_rad(randf_range(-7.0, 7.0)), 1.1)
		tw.chain().tween_callback(mi.queue_free)
	VFX.debris(wp + Vector3.UP * float(g["h"]) * 0.6, g["wall"], 14, 9.0, 0.5)
	VFX.debris(wp + Vector3.UP * float(g["h"]), g["roof"], 10, 8.0, 0.4)
	for k in 3:
		var a = TAU * k / 3.0
		FX.dust(wp + Vector3(cos(a), 0, sin(a)) * foot * 0.5, 2.2)
	Sfx.play("boom", wp, 0.9, 0.7)
	if Game.world and Game.world.env and Game.player and wp.distance_to(Game.player.global_position) < 80.0:
		Game.world.env.add_shake(0.5)


# ------------------------------------------------------------------ onarım (kullanıcı: "onarım için animasyon da yap şehirdekilere")
## Bölge dışından içine doğru onarılır. Kenardaki evler şantiyedir: moloz kalkar, çevresine iskele kurulur, duvarlar
## kat kat yükselir; köylüler başında çalışır (çekiç sallar, diz çöküp çakar, tahta taşır — VillageLife "repair" mekânı,
## köyün var olan işçi düzeni). Ev tamamlanınca iskele sökülür, gerçek ev geri gelir.
static func _rebuild(st: Dictionary, z: Dictionary, rr: float, host: Node) -> void:
	var fronts: Array = []
	for g in st["groups"]:
		if not g["house"] or g["prot"]:
			continue
		if g["hidden"] and rr - float(g["dist"]) <= BAND:
			if not g.has("build"):
				_site_begin(g, host)
			_site_progress(g, clampf(1.0 - (rr - float(g["dist"])) / BAND, 0.0, 1.0))
			fronts.append(g)
		elif g.has("build"):
			_site_end(g)
	# işçiler: en ilerlemiş şantiyelerde
	var vid = String(z["vid"])
	if not VL.sites.has(vid):
		return
	if not st.has("sites"):
		st["sites"] = []
	var now = Time.get_ticks_msec()
	var sl: Array = st["sites"]
	for pair in sl:
		var g0 = pair[1]
		if g0 != null and not g0.has("build"):
			pair[0]["off"] = true
			pair[1] = null
			pair[2] = now
	fronts.sort_custom(func(a, b): return float(a["dist"]) > float(b["dist"]))
	for g in fronts:
		if sl.any(func(pr): return pr[1] == g):
			continue
		var pair = null
		for pr in sl:
			if pr[1] == null and now - int(pr[2]) > 3000:
				pair = pr
				break
		if pair == null:
			if sl.size() >= MAX_SITES:
				break
			var sd = {"type": "repair", "pos": Vector3.ZERO, "off": true}
			(VL.sites[vid] as Array).append(sd)
			pair = [sd, null, 0]
			sl.append(pair)
		var yaw: Basis = Basis(Vector3.UP, (g["basis"] as Basis).get_euler().y)
		var out = yaw * Vector3(0, 0, -1)   # ön cephe (-Z)
		var s: Dictionary = pair[0]
		s["pos"] = (g["pos"] as Vector3) + out * (float(g["d"]) * 0.5 + 1.6)
		s["house"] = g["pos"]
		s["w"] = float(g["w"])
		s["off"] = false
		pair[1] = g


static func _site_begin(g: Dictionary, host: Node) -> void:
	var rb = g.get("rubble")
	if rb != null and is_instance_valid(rb):
		rb.queue_free()
	g.erase("rubble")
	var w = float(g["w"])
	var d = float(g["d"])
	var h = maxf(3.0, float(g["h"]) * 0.8)
	var root = Node3D.new()
	host.get_tree().current_scene.add_child(root)
	root.global_transform = Transform3D(Basis(Vector3.UP, (g["basis"] as Basis).get_euler().y), g["pos"])
	# iskele: çevrede direkler, her katta yürüme tahtası, çapraz bağlar
	var b = MB.new()
	var wood = Color(0.62, 0.47, 0.28)
	var dark = Color(0.45, 0.33, 0.2)
	var hw = w * 0.5 + 0.7
	var hd = d * 0.5 + 0.7
	var nx = maxi(2, int(ceil(w / 3.2)) + 1)
	var nz = maxi(2, int(ceil(d / 3.2)) + 1)
	var pts: Array = []
	for i in nx:
		var x = lerpf(-hw, hw, i / float(nx - 1))
		pts.append(Vector2(x, -hd))
		pts.append(Vector2(x, hd))
	for i in range(1, nz - 1):
		var zz = lerpf(-hd, hd, i / float(nz - 1))
		pts.append(Vector2(-hw, zz))
		pts.append(Vector2(hw, zz))
	for q in pts:
		b.add("box", Vector3(q.x, (h + 0.8) * 0.5, q.y), Vector3(0.14, h + 0.8, 0.14), dark, Vector3.ZERO, 4)
	var lv = 2.4
	while lv < h + 0.3:
		for side in [-1.0, 1.0]:
			b.add("box", Vector3(0, lv, side * hd), Vector3(hw * 2.0 + 0.3, 0.07, 0.55), wood, Vector3.ZERO, 4)
			b.add("box", Vector3(0, lv + 0.9, side * (hd + 0.25)), Vector3(hw * 2.0 + 0.3, 0.07, 0.07), dark, Vector3.ZERO, 4)
			b.add("box", Vector3(side * hw, lv, 0), Vector3(0.55, 0.07, hd * 2.0 + 0.3), wood, Vector3.ZERO, 4)
		lv += 2.4
	for side in [-1.0, 1.0]:
		var L = sqrt(pow(hw * 0.9, 2.0) + pow(h, 2.0))
		b.add("box", Vector3(-hw * 0.45, h * 0.5, side * (hd + 0.05)), Vector3(0.08, L, 0.08), dark, Vector3(0, 0, rad_to_deg(atan2(hw * 0.9, h)) * side), 4)
	# yığılı kereste ve tuğla
	for k in 5:
		b.add("box", Vector3(hw + 1.6, 0.12 + k * 0.13, -hd * 0.3 + (k % 2) * 0.1), Vector3(0.9, 0.12, 3.0), wood.darkened(0.05 * (k % 3)), Vector3(0, (k % 2) * 4.0, 0), 4)
	b.add("box", Vector3(-hw - 1.4, 0.3, hd * 0.2), Vector3(1.2, 0.6, 0.9), Color(0.72, 0.42, 0.3), Vector3.ZERO, 4)
	var sc = MeshInstance3D.new()
	sc.mesh = b.build(Props.toon())
	sc.layers = 2
	root.add_child(sc)
	# yükselen duvar: evin kendi duvar mesh'i
	var wall: MeshInstance3D = null
	var best_h = 0.0
	for it in g["items"]:
		var mm: MultiMesh = it[0]
		if not is_instance_valid(mm) or mm.mesh == null:
			continue
		var ab: AABB = mm.mesh.get_aabb()
		if ab.position.y < 0.6 and ab.size.y > best_h and ab.size.x > 2.0:
			best_h = ab.size.y
			if wall == null:
				wall = MeshInstance3D.new()
				wall.layers = 2
				host.get_tree().current_scene.add_child(wall)
			wall.mesh = mm.mesh
			wall.material_override = host._tint_mat(it[4])
			wall.global_transform = it[3]
	var sy = 1.0
	if wall != null:
		sy = wall.scale.y
		wall.scale.y = sy * 0.04
	g["build"] = {"root": root, "wall": wall, "sy": sy}


static func _site_progress(g: Dictionary, prog: float) -> void:
	var bd: Dictionary = g["build"]
	var wall = bd.get("wall")
	if wall != null and is_instance_valid(wall):
		wall.create_tween().tween_property(wall, "scale:y", float(bd["sy"]) * maxf(0.04, prog), 5.0)


static func _site_end(g: Dictionary) -> void:
	if not g.has("build"):
		return
	for k in ["root", "wall"]:
		var n = g["build"].get(k)
		if n != null and is_instance_valid(n):
			n.queue_free()
	g.erase("build")
