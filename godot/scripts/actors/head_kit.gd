extends RefCounted
## Kafalık yapım araçları (hasır / lake / örgü dönel gövde, ip, Head kemiğine takma). head_v2*, mask_v2_b ortak kullanır.

const ROPE := Color(0.24, 0.18, 0.13)


static func _hw(m) -> float:
	var ab: AABB = m.head_ab
	return clampf(ab.size.x, 0.16, 0.26) if ab.size.x > 0.05 else 0.2


## Catmull-Rom ile sıklaştırılmış profil (r, y)
static func _curve(p: Array, sub: int) -> Array:
	var out := []
	for i in p.size() - 1:
		var p0: Vector2 = p[maxi(i - 1, 0)]
		var p1: Vector2 = p[i]
		var p2: Vector2 = p[i + 1]
		var p3: Vector2 = p[mini(i + 2, p.size() - 1)]
		for k in sub:
			var t := float(k) / sub
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(p[p.size() - 1])
	return out


## Dönel gövde. prof: üstten dışa / aşağı giden (r, y). colf(i, j, a, nokta) -> Color; off(a, j) -> Vector2(r çarpanı, y farkı)
static func _rev(mb: MB, prof: Array, na: int, colf: Callable, off := Callable(), sz := 1.0) -> void:
	var nj := prof.size()
	var nr := []
	for j in nj:
		var d: Vector2 = prof[mini(j + 1, nj - 1)] - prof[maxi(j - 1, 0)]
		nr.append(Vector2(-d.y, d.x).normalized())
	var pt = func(a: float, j: int) -> Vector3:
		var q: Vector2 = prof[j]
		var o: Vector2 = off.call(a, j) if off.is_valid() else Vector2(1.0, 0.0)
		return Vector3(sin(a) * q.x * o.x, q.y + o.y, cos(a) * q.x * o.x * sz)
	var nv = func(a: float, j: int) -> Vector3:
		var q: Vector2 = nr[j]
		return Vector3(sin(a) * q.x, q.y, cos(a) * q.x).normalized()
	for i in na:
		var a0 := TAU * i / na - PI
		var a1 := TAU * (i + 1) / na - PI
		for j in nj - 1:
			var c: Color = colf.call(i, j, (a0 + a1) * 0.5, prof[j])
			var b: int = mb.verts.size()
			for v in [[a0, j], [a1, j], [a1, j + 1], [a0, j + 1]]:
				mb.verts.append(pt.call(v[0], v[1]))
				mb.normals.append(nv.call(v[0], v[1]))
				mb.colors.append(c)
				mb.uvs.append(Vector2.ZERO)
			for k in [0, 1, 2, 0, 2, 3]:
				mb.idx.append(b + k)


## İki nokta arası ince ip / çubuk
static func _cord(mb: MB, a: Vector3, b: Vector3, w: float, c: Color) -> void:
	var d := b - a
	var up := d.normalized()
	var x := up.cross(Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(up).normalized()
	mb.add_xf("box", Transform3D(Basis(x * w, up * d.length(), z * w), (a + b) * 0.5), c)


static func _put(m, mb: MB, o: Vector3) -> MeshInstance3D:
	return m._mesh_on("Head", mb.build(LazyFx.g("Props").toon()), Transform3D(Basis.IDENTITY, o))


## Çene ipi: şapka içinden iki yandan çene altında düğüm
static func _chin(mb: MB, base_y: float, m, hw: float, c: Color) -> void:
	var hc: Vector3 = m._head_center()
	var chin: float = m.eye_center_model.y - 0.135 - base_y
	var knot := Vector3(0, chin, 0.055)
	for s in [-1.0, 1.0]:
		var top := Vector3(s * hw * 0.53, 0.02, 0.0)
		var mid := Vector3(s * hw * 0.51, (hc.y - base_y) - 0.06, 0.03)
		_cord(mb, top, mid, 0.007, c)
		_cord(mb, mid, knot, 0.007, c)
	mb.add("sphere", knot, Vector3(0.018, 0.016, 0.016), c.darkened(0.15), Vector3.ZERO, 8)
	_cord(mb, knot, knot + Vector3(0.012, -0.05, 0.006), 0.006, c)
	_cord(mb, knot, knot + Vector3(-0.01, -0.042, 0.008), 0.006, c)
