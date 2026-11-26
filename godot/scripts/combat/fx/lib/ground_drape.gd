extends Node
## Zemin örtüsü (yalnız geometri, görünüş yok): yere serilen DÜZ efekt meshlerini (birikinti, iz, çatlak, halka, yanık, lav gölü...)
## engebeli araziye oturtur. Efektin kendi meshi / malzemesi / renkleri / UV'leri aynen kalır; yalnız köşeler (gerekirse
## sıklaştırılıp) altlarındaki zeminin yüksekliğine kaydırılır. Düz zeminde orijinal mesh hiç değişmez.
## Kullanım: kütüphanelerin put() / scene_add() yerleştirme noktaları auto(n) çağırır. Tek bir yönetici düğüm izlenen
## meshlerin dönüşümüne bakar: büyüyen / dönen / kayan alan dönüşümü değişince (kısıtlı sıklıkta) yeniden oturtulur.
## Çatıda / köprüde / havada duran ya da dikey düz efektlere dokunulmaz (zeminden uzak ya da ince ekseni dikey değil).

static var enabled := true   # test: önce / sonra karşılaştırması
const MIN_RANGE := 0.12      # alan altındaki zemin farkı bundan azsa (m) orijinal düz mesh kalır
const LIFT := 0.03           # oturtulan köşelere ek kaldırma (arazi çizimiyle z-çakışması olmasın)
const CELL := 1.0            # zemin yüksekliği önbellek hücresi (m)
const MAX_TRIS := 5000
const BUDGET := 3            # karede en çok kaç yeniden oturtma

static var _hc := {}         # Vector2i -> zemin yüksekliği
static var _hc_water := -1
static var _sub := {}        # mesh id + hedef kenar -> sıklaştırılmış yüzey dizileri
static var _mgr: Node = null

var _items: Array = []       # {mi, orig, own: ArrayMesh, draped, last, has_last, pending, next, still}
var _n := 0


## Yerleştirilen düğüm (ya da doğrudan çocukları) yere serili düz meshse izlemeye alır
static func auto(n: Node) -> void:
	if not enabled or n == null or not is_instance_valid(n):
		return
	if n is MeshInstance3D:
		_try(n)
	elif n is Node3D and n.get_child_count() <= 12:
		for ch in n.get_children():
			if ch is MeshInstance3D:
				_try(ch)


static func _try(mi: MeshInstance3D) -> void:
	if mi.mesh == null or mi.has_meta("drape_off") or mi.has_meta("_drape"):
		return
	if not _usable(mi.mesh):
		return
	var m = _manager(mi)
	if m == null:
		return
	mi.set_meta("_drape", true)
	m._items.append({"mi": weakref(mi), "orig": mi.mesh, "own": null, "draped": false, "last": Transform3D(), "has_last": false, "pending": true, "next": 0, "still": 0})


static func _manager(mi: Node) -> Node:
	if _mgr != null and is_instance_valid(_mgr) and _mgr.is_inside_tree():
		return _mgr
	if not mi.is_inside_tree():
		return null
	var sc = mi.get_tree().current_scene
	if sc == null:
		return null
	_mgr = load("res://scripts/combat/fx/lib/ground_drape.gd").new()
	_mgr.name = "GroundDrape"
	sc.add_child(_mgr)
	return _mgr


## Örtülebilir mesh: 1-4 üçgen yüzeyi, biçim anahtarı yok, çok büyük değil
static func _usable(mesh: Mesh) -> bool:
	if mesh is ArrayMesh and (mesh as ArrayMesh).get_blend_shape_count() > 0:
		return false
	var n = mesh.get_surface_count()
	if n < 1 or n > 4:
		return false
	if mesh is ArrayMesh:   # PrimitiveMesh (Plane / Quad / Sphere) hep üçgendir; tür sorgusu yalnız ArrayMesh'te var
		for si in n:
			if (mesh as ArrayMesh).surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
				return false
	elif not (mesh is PrimitiveMesh):
		return false
	return mesh.get_aabb().size.length() > 0.05


## Dünya ölçeğiyle ince eksen (0 x, 1 y, 2 z): diğerlerinin %8'inden ince ve dünyada dik (yukarı) duruyorsa; değilse -1.
## (Lav gölü gibi kabarık meshler Y'de basılarak düzleşir: yerel değil ölçekli boyuta bakılır.)
static func _thin_axis(mesh: Mesh, b: Basis) -> int:
	var s = mesh.get_aabb().size
	var ws = Vector3(s.x * b.x.length(), s.y * b.y.length(), s.z * b.z.length())
	var mx = maxf(ws.x, maxf(ws.y, ws.z))
	if mx < 0.3:
		return -1
	for ax in 3:
		if ws[ax] <= mx * 0.08:
			var d: Vector3 = b[ax]
			if d.length() > 0.0001 and absf(d.normalized().y) > 0.8:
				return ax
			return -1
	return -1


# ------------------------------------------------------------------ zemin yüksekliği (1 m hücre, çift doğrusal)
static func _cell(i: int, j: int) -> float:
	var k = Vector2i(i, j)
	var v = _hc.get(k)
	if v == null:
		v = Game.jutsu_floor(i * CELL, j * CELL)
		_hc[k] = v
	return v


static func height(x: float, z: float) -> float:
	var fx = x / CELL
	var fz = z / CELL
	var i = floori(fx)
	var j = floori(fz)
	var tx = fx - i
	var tz = fz - j
	return lerpf(lerpf(_cell(i, j), _cell(i + 1, j), tx), lerpf(_cell(i, j + 1), _cell(i + 1, j + 1), tx), tz)


static func _indoors() -> bool:
	var it = Interiors.inst
	return it != null and is_instance_valid(it) and it.inside != ""


# ------------------------------------------------------------------ izleme
func _process(_dt: float) -> void:
	_n += 1
	if _items.is_empty():
		return
	if _hc.size() > 250000 or Game.water_list.size() != _hc_water:
		_hc.clear()
		_hc_water = Game.water_list.size()
	var budget = BUDGET
	var i = _items.size() - 1
	while i >= 0:
		var it: Dictionary = _items[i]
		var mi = it["mi"].get_ref()
		if it.get("dead", false) or mi == null or not is_instance_valid(mi) or not mi.is_inside_tree():
			_items.remove_at(i)
			i -= 1
			continue
		if it["still"] > 30 and not it["pending"] and (_n + i) % 4 != 0:   # uzun süre kıpırdamayan alan: dört karede bir bak
			i -= 1
			continue
		var t: Transform3D = mi.global_transform
		if not it["has_last"] or _changed(it["last"], t):
			it["still"] = 0
			it["pending"] = true
		else:
			it["still"] += 1
		# değişirken en çok üç karede bir yeniden oturt (büyüyen alan); kare bütçesi dolarsa sonraki kareye kalır
		if it["pending"] and _n >= int(it["next"]):
			if _thin_axis(it["orig"], t.basis) < 0 or _indoors():   # yere serili düz değil (mermi, dik halka, taç...): ucuz ret
				it["pending"] = false
				it["next"] = _n + 3
				it["last"] = t
				it["has_last"] = true
				_restore(it, mi)
			elif budget > 0:
				budget -= 1
				it["pending"] = false
				it["next"] = _n + 3
				it["last"] = t
				it["has_last"] = true
				_drape(it, mi, t)
		i -= 1


static func _changed(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_squared_to(b.origin) > 0.15 * 0.15:
		return true
	for k in 3:
		var la = a.basis[k].length()
		var lb = b.basis[k].length()
		if absf(la - lb) > 0.06 * maxf(la, 0.001):
			return true
		if la > 0.0001 and lb > 0.0001 and a.basis[k].dot(b.basis[k]) / (la * lb) < 0.998:
			return true
	return false


func _restore(it: Dictionary, mi: MeshInstance3D) -> void:
	if it["draped"]:
		mi.mesh = it["orig"]
		it["draped"] = false
	_set_tilt(it, mi, Basis.IDENTITY)


## Eğik kip: düğümün kendi dönüşü yamacın düzlemine yatırılır (mesh değişmez). Önceki eğiklik geri alınıp yenisi uygulanır;
## efektin ölçek / dönüş tween'leri ayrı tutulduğundan bozulmaz.
func _set_tilt(it: Dictionary, mi: MeshInstance3D, r: Basis) -> void:
	var prev: Basis = it.get("tilt", Basis.IDENTITY)
	if prev.is_equal_approx(r):
		return
	mi.basis = r * (prev.inverse() * mi.basis)
	it["tilt"] = r
	it["last"] = mi.global_transform


func _drape(it: Dictionary, mi: MeshInstance3D, t: Transform3D) -> void:
	var orig: Mesh = it["orig"]
	if mi.mesh != orig and mi.mesh != it["own"]:   # efekt kendi meshini değiştirdi: bırak
		it["dead"] = true
		return
	var ax = _thin_axis(orig, t.basis)
	if ax < 0:
		_restore(it, mi)
		return
	var ab: AABB = orig.get_aabb()
	var c: Vector3 = t * ab.get_center()
	var h0 = height(c.x, c.z)
	if c.y - h0 > 0.8 or c.y - h0 < -0.5:   # çatı / köprü / hava / bilerek gömülü: dokunma
		_restore(it, mi)
		return
	# kaba ön bakış: alanın altında zemin farkı yoksa düz mesh kalır
	var corners = []
	for k in 8:
		corners.append(t * ab.get_endpoint(k))
	var mn = Vector2(INF, INF)
	var mxp = Vector2(-INF, -INF)
	for p in corners:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mxp = Vector2(maxf(mxp.x, p.x), maxf(mxp.y, p.z))
	var rng = 0.0
	for gx in 5:
		for gz in 5:
			var hx = lerpf(mn.x, mxp.x, gx / 4.0)
			var hz = lerpf(mn.y, mxp.y, gz / 4.0)
			rng = maxf(rng, absf(height(hx, hz) - h0))
	if rng < MIN_RANGE:
		_restore(it, mi)
		return
	# Y'de basılmış mesh (lav gölü: ölçek.y 0.09): köşe kaydırması yerel uzayda 1/ölçek kat büyür ve yerel konumdan desen
	# üreten gölgelendiricilerin deseni çekilir. Bunlarda mesh değişmez; düğüm yamacın düzlemine yatırılır.
	var prev_tilt: Basis = it.get("tilt", Basis.IDENTITY)
	if (prev_tilt.inverse() * t.basis)[ax].length() < 0.5:
		var sx = 0.0
		var sz = 0.0
		var sxx = 0.0
		var szz = 0.0
		var sxz = 0.0
		var sxh = 0.0
		var szh = 0.0
		for gx in 5:
			for gz in 5:
				var dx = lerpf(mn.x, mxp.x, gx / 4.0) - c.x
				var dz = lerpf(mn.y, mxp.y, gz / 4.0) - c.z
				var dh = height(c.x + dx, c.z + dz) - h0
				sxx += dx * dx
				szz += dz * dz
				sxz += dx * dz
				sxh += dx * dh
				szh += dz * dh
		var det = sxx * szz - sxz * sxz
		if absf(det) < 0.0001:
			return
		var ga = (sxh * szz - szh * sxz) / det
		var gb = (szh * sxx - sxh * sxz) / det
		var nrm = Vector3(-ga, 1.0, -gb).normalized()
		var par = mi.get_parent()
		if par is Node3D:
			nrm = ((par as Node3D).global_basis.orthonormalized().inverse() * nrm).normalized()
		if it["draped"]:
			mi.mesh = orig
			it["draped"] = false
		_set_tilt(it, mi, Basis(Quaternion(Vector3.UP, nrm)))
		return
	if not prev_tilt.is_equal_approx(Basis.IDENTITY):
		_set_tilt(it, mi, Basis.IDENTITY)
		t = mi.global_transform
	# sıklaştır (yerel uzayda, önbellekli) + köşeleri zemine kaydır
	var s = ab.size
	var diam = 0.0
	var wscale = 0.0
	for k in 3:
		if k != ax:
			diam = maxf(diam, s[k])
			wscale = maxf(wscale, t.basis[k].length())
	var target = maxf(diam / 12.0, 0.5 / maxf(wscale, 0.001))
	target = pow(2.0, roundf(log(target) / log(2.0)))
	var surfs: Array = _subdivided(orig, target)
	var bup: Vector3 = t.basis.inverse() * Vector3.UP
	var own: ArrayMesh = it["own"]
	if own == null:
		own = ArrayMesh.new()
		it["own"] = own
	own.clear_surfaces()
	# alanın altındaki hücre yükseklikleri bir kez diziye (köşe başına dört sözlük okuması yerine); değerler height() ile aynı
	var gi0 = floori(mn.x / CELL) - 1
	var gj0 = floori(mn.y / CELL) - 1
	var gw = floori(mxp.x / CELL) - gi0 + 3
	var gh = floori(mxp.y / CELL) - gj0 + 3
	var grid := PackedFloat32Array()
	grid.resize(gw * gh)
	for gj in gh:
		for gi in gw:
			grid[gj * gw + gi] = _cell(gi0 + gi, gj0 + gj)
	for sd in surfs:
		var arrs: Array = (sd["arrs"] as Array).duplicate()
		var src: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
		var vs := PackedVector3Array()
		vs.resize(src.size())
		for q in src.size():
			var v: Vector3 = src[q]
			var w: Vector3 = t * v
			var fx = w.x / CELL
			var fz = w.z / CELL
			var ci = floori(fx)
			var cj = floori(fz)
			var li = ci - gi0
			var lj = cj - gj0
			var hh: float
			if li >= 0 and lj >= 0 and li + 1 < gw and lj + 1 < gh:
				var tx = fx - ci
				var o = lj * gw + li
				hh = lerpf(lerpf(grid[o], grid[o + 1], tx), lerpf(grid[o + gw], grid[o + gw + 1], tx), fz - cj)
			else:
				hh = height(w.x, w.z)
			vs[q] = v + bup * (hh - h0 + LIFT)
		arrs[Mesh.ARRAY_VERTEX] = vs
		own.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
		if sd["mat"] != null:
			own.surface_set_material(own.get_surface_count() - 1, sd["mat"])
	mi.mesh = own
	it["draped"] = true


# ------------------------------------------------------------------ sıklaştırma (kenar ortası bölme, çatlaksız)
static func _subdivided(mesh: Mesh, target: float) -> Array:
	var key = "%d_%.4f" % [mesh.get_instance_id(), target]
	if _sub.has(key):
		return _sub[key]
	if _sub.size() > 96:
		_sub.clear()
	var out = []
	for si in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(si)
		var mat = mesh.surface_get_material(si)
		if mat == null and mesh is PrimitiveMesh:
			mat = (mesh as PrimitiveMesh).material
		out.append({"arrs": _split(a, target), "mat": mat})
	_sub[key] = out
	return out


static func _split(a: Array, target: float) -> Array:
	var V: PackedVector3Array = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var N = (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate() if a[Mesh.ARRAY_NORMAL] != null else null
	var T = (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate() if a[Mesh.ARRAY_TANGENT] != null else null
	var C = (a[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate() if a[Mesh.ARRAY_COLOR] != null else null
	var U = (a[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate() if a[Mesh.ARRAY_TEX_UV] != null else null
	var U2 = (a[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).duplicate() if a[Mesh.ARRAY_TEX_UV2] != null else null
	var I := PackedInt32Array()
	if a[Mesh.ARRAY_INDEX] != null:
		I = (a[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
	else:
		for q in V.size():
			I.append(q)
	var t2 = target * target
	for _pass in 5:
		if I.size() / 3 > MAX_TRIS:
			break
		var mids := {}
		var mark := false
		for f in I.size() / 3:
			var ia = I[f * 3]
			var ib = I[f * 3 + 1]
			var ic = I[f * 3 + 2]
			if V[ia].distance_squared_to(V[ib]) > t2 or V[ib].distance_squared_to(V[ic]) > t2 or V[ic].distance_squared_to(V[ia]) > t2:
				mark = true
				for e in [[ia, ib], [ib, ic], [ic, ia]]:
					var k = Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
					if not mids.has(k):
						mids[k] = -1
		if not mark:
			break
		for k in mids:   # kenar ortası köşeleri (tüm öznitelikler ara değer)
			var p: int = k.x
			var q: int = k.y
			mids[k] = V.size()
			V.append((V[p] + V[q]) * 0.5)
			if N != null:
				var nn: Vector3 = N[p] + N[q]
				N.append(nn.normalized() if nn.length() > 0.0001 else N[p])
			if T != null:
				for z in 4:
					T.append((T[p * 4 + z] + T[q * 4 + z]) * 0.5)
			if C != null:
				C.append(C[p].lerp(C[q], 0.5))
			if U != null:
				U.append((U[p] + U[q]) * 0.5)
			if U2 != null:
				U2.append((U2[p] + U2[q]) * 0.5)
		var J := PackedInt32Array()
		for f in I.size() / 3:
			var va = I[f * 3]
			var vb = I[f * 3 + 1]
			var vc = I[f * 3 + 2]
			var mab = mids.get(Vector2i(mini(va, vb), maxi(va, vb)), -1)
			var mbc = mids.get(Vector2i(mini(vb, vc), maxi(vb, vc)), -1)
			var mca = mids.get(Vector2i(mini(vc, va), maxi(vc, va)), -1)
			var tris = []
			if mab >= 0 and mbc >= 0 and mca >= 0:
				tris = [va, mab, mca, mab, vb, mbc, mca, mbc, vc, mab, mbc, mca]
			elif mab >= 0 and mbc >= 0:
				tris = [mab, vb, mbc, va, mab, mbc, va, mbc, vc]
			elif mab >= 0 and mca >= 0:
				tris = [va, mab, mca, mab, vb, vc, mab, vc, mca]
			elif mbc >= 0 and mca >= 0:
				tris = [mca, mbc, vc, va, vb, mbc, va, mbc, mca]
			elif mab >= 0:
				tris = [va, mab, vc, mab, vb, vc]
			elif mbc >= 0:
				tris = [va, vb, mbc, va, mbc, vc]
			elif mca >= 0:
				tris = [va, vb, mca, mca, vb, vc]
			else:
				tris = [va, vb, vc]
			for x in tris:
				J.append(x)
		I = J
	var r = []
	r.resize(Mesh.ARRAY_MAX)
	r[Mesh.ARRAY_VERTEX] = V
	r[Mesh.ARRAY_NORMAL] = N
	r[Mesh.ARRAY_TANGENT] = T
	r[Mesh.ARRAY_COLOR] = C
	r[Mesh.ARRAY_TEX_UV] = U
	r[Mesh.ARRAY_TEX_UV2] = U2
	r[Mesh.ARRAY_INDEX] = I
	return r
