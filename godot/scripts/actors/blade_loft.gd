extends RefCounted
## Silah modelleme yardımcısı: kesit dizisinden (aynı köşe sayılı kapalı çokgenler, x-y düzleminde) z boyunca gövde örer.
## flat = true: her yüz kendi normaliyle (ağız şevi / sırt çizgisi toon gölgede keskin görünür), yüz rengi face_cols[i] (i: kesitte i -> i+1 kenarı).
## flat = false: komşu yüzlerin ortalama normali (sap, boru, topuz gibi yuvarlak gövdeler).
## Uçlar: cap0 / cap1 ile kesit merkezinden yelpaze kapak. Tüm noktalar xf ile dönüştürülür.


static func loft(b: MB, secs: Array, zs: Array, face_cols: Array, flat := true, cap0 := true, cap1 := true, xf := Transform3D.IDENTITY) -> void:
	var ns: int = secs.size()
	if ns < 2:
		return
	var n: int = (secs[0] as PackedVector2Array).size()
	var nb := xf.basis.inverse().transposed()
	var P := []   # P[s][i] Vector3
	for s in ns:
		var row := []
		var sec: PackedVector2Array = secs[s]
		for i in n:
			row.append(Vector3(sec[i].x, sec[i].y, float(zs[s])))
		P.append(row)
	if flat:
		for s in ns - 1:
			for i in n:
				var j := (i + 1) % n
				var a: Vector3 = P[s][i]
				var bb: Vector3 = P[s][j]
				var c: Vector3 = P[s + 1][j]
				var d: Vector3 = P[s + 1][i]
				var nm := (c - a).cross(d - bb)
				if nm.length() < 1e-10:
					continue
				nm = nm.normalized()
				var col: Color = face_cols[i % face_cols.size()]
				var base := b.verts.size()
				for q in [a, bb, c, d]:
					b.verts.append(xf * q)
					b.normals.append((nb * nm).normalized())
					b.colors.append(col)
					b.uvs.append(Vector2(float(i) / n, float(s) / (ns - 1)))
				b.idx.append_array(_quad(base, nm, a, bb, c))
	else:
		# ortak köşeler, ortalama normal
		var N := []
		for s in ns:
			var row := []
			for i in n:
				row.append(Vector3.ZERO)
			N.append(row)
		for s in ns - 1:
			for i in n:
				var j := (i + 1) % n
				var nm: Vector3 = ((P[s + 1][j] as Vector3) - P[s][i]).cross((P[s + 1][i] as Vector3) - P[s][j])
				for k in [[s, i], [s, j], [s + 1, i], [s + 1, j]]:
					N[k[0]][k[1]] += nm
		var base := b.verts.size()
		for s in ns:
			for i in n:
				var nm: Vector3 = N[s][i]
				if nm.length() < 1e-10:
					var p: Vector3 = P[s][i]
					nm = Vector3(p.x, p.y, 0.0)
				b.verts.append(xf * (P[s][i] as Vector3))
				b.normals.append((nb * nm.normalized()).normalized())
				b.colors.append(face_cols[i % face_cols.size()])
				b.uvs.append(Vector2(float(i) / n, float(s) / (ns - 1)))
		for s in ns - 1:
			for i in n:
				var j := (i + 1) % n
				var a := base + s * n + i
				var bq := base + s * n + j
				var c := base + (s + 1) * n + j
				var d := base + (s + 1) * n + i
				var nm: Vector3 = ((P[s + 1][j] as Vector3) - P[s][i]).cross((P[s + 1][i] as Vector3) - P[s][j])
				b.idx.append_array(_quad_idx(a, bq, c, d, nm, P[s][i], P[s][j], P[s + 1][j]))
	if cap0:
		_cap(b, P[0], face_cols[0], -1.0, xf, nb)
	if cap1:
		_cap(b, P[ns - 1], face_cols[0], 1.0, xf, nb)


## dörtgen iki üçgen; sarım normal yönüne göre seçilir (dış yüz görünsün)
static func _quad(base: int, nm: Vector3, a: Vector3, bb: Vector3, c: Vector3) -> PackedInt32Array:
	return _quad_idx(base, base + 1, base + 2, base + 3, nm, a, bb, c)


static func _quad_idx(a: int, bq: int, c: int, d: int, nm: Vector3, pa: Vector3, pb: Vector3, pc: Vector3) -> PackedInt32Array:
	# Godot ön yüz = saat yönü (kameradan bakınca); (pb - pa) x (pc - pa) normalle aynı yöndeyse sırayı çevir
	if (pb - pa).cross(pc - pa).dot(nm) > 0.0:
		return PackedInt32Array([a, c, bq, a, d, c])
	return PackedInt32Array([a, bq, c, a, c, d])


static func _cap(b: MB, row: Array, col: Color, sgn: float, xf: Transform3D, nb: Basis) -> void:
	var n := row.size()
	var cen := Vector3.ZERO
	for p in row:
		cen += p
	cen /= n
	var span := 0.0
	for p in row:
		span = maxf(span, (p - cen).length())
	if span < 1e-5:
		return
	var nm := Vector3(0, 0, sgn)
	var base := b.verts.size()
	b.verts.append(xf * cen)
	b.normals.append((nb * nm).normalized())
	b.colors.append(col)
	b.uvs.append(Vector2.ZERO)
	for p in row:
		b.verts.append(xf * (p as Vector3))
		b.normals.append((nb * nm).normalized())
		b.colors.append(col)
		b.uvs.append(Vector2.ZERO)
	for i in n:
		var j := (i + 1) % n
		var pa: Vector3 = cen
		var pb: Vector3 = row[i]
		var pc: Vector3 = row[j]
		if (pb - pa).cross(pc - pa).dot(nm) > 0.0:
			b.idx.append_array([base, base + 1 + j, base + 1 + i])
		else:
			b.idx.append_array([base, base + 1 + i, base + 1 + j])


## Yuvarlatılmış dikdörtgen / elips kesit (rx: x yarı-eni, ry: y yarı-boyu, squ: 0 = elips, büyüdükçe köşeli)
static func oval(rx: float, ry: float, n := 16, squ := 0.0, ox := 0.0, oy := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		var c := cos(a)
		var s := sin(a)
		var e := 2.0 / (2.0 + squ * 6.0)   # süperelips üssü: squ büyüdükçe köşeli
		out.append(Vector2(ox + rx * signf(c) * pow(absf(c), e), oy + ry * signf(s) * pow(absf(s), e)))
	return out
