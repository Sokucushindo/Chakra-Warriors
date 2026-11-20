extends RefCounted
## Canavar elle modelleme çekirdeği (set_el.gd'deki El mantığının dev canavar ölçüsüne uyarlanmışı).
## Her parça tek parça kesintisiz yüzey; her köşe gerçek kemiklere ağırlıkla bağlı (parça kopmaz / uçmaz).
## Kemikler BeastRig'in pivot düğümlerinden kurulur; Kopru her kare pivot dönüşlerini kemiklere aktarır
## (animasyon sistemi değişmez). Ölçü "tasarım birimi"nde (BeastRig.D = 10 birim boy), ileri -Z.

var V := PackedVector3Array()
var Nn := PackedVector3Array()
var Cc := PackedColorArray()
var Bi := PackedInt32Array()
var Wt := PackedFloat32Array()
var Ix := PackedInt32Array()
var bones := {}          # Node3D ya da ad -> kemik indeksi
var skel: Skeleton3D
var root: Node3D
var kopru
var shade := Callable()   # (renk, normal) -> renk: alt yüzler koyu


# ------------------------------------------------------------------ iskelet
## Pivotların kök uzayındaki (tasarım uzayı) dinlenme dönüşümü
func rs(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


static func _is_pivot(n: Node) -> bool:
	return n.get_class() == "Node3D" and not String(n.name).begins_with("carpisma") and not String(n.name).begins_with("weak")


## Pivot ağacından iskelet. mixes: [[ad, düğümA, düğümB, oran, tasarım konumu], ...] (omurga/boyun: iki pivot arası harman kemik)
func rig(r: BeastRig, rt: Node3D, mixes: Array) -> void:
	root = rt
	skel = Skeleton3D.new()
	skel.name = "ElIskelet"
	var piv := []
	var stack := [[rt, -1]]
	while not stack.is_empty():
		var e: Array = stack.pop_front()
		for ch in (e[0] as Node).get_children():
			if not _is_pivot(ch):
				continue
			var bi := skel.get_bone_count()
			skel.add_bone("%s_%d" % [ch.name, bi])
			skel.set_bone_parent(bi, int(e[1]))
			skel.set_bone_rest(bi, (ch as Node3D).transform)
			bones[ch] = bi
			piv.append([bi, ch])
			stack.append([ch, bi])
	var mx := []
	for m in mixes:
		var bi := skel.get_bone_count()
		skel.add_bone(String(m[0]))
		skel.set_bone_parent(bi, -1)
		var rest := Transform3D(Basis.IDENTITY, m[4])
		skel.set_bone_rest(bi, rest)
		bones[String(m[0])] = bi
		mx.append([bi, m[1], rs(m[1]).affine_inverse() * rest, m[2], rs(m[2]).affine_inverse() * rest, float(m[3])])
	skel.reset_bone_poses()
	rt.add_child(skel)
	kopru = Kopru.new()
	kopru.name = "ElKopru"
	kopru.root = rt
	kopru.skel = skel
	kopru.piv = piv
	kopru.mix = mx
	kopru.process_priority = 50   # BeastRig pivotları yazdıktan SONRA
	r.add_child(kopru)


## İnce köprü: BeastRig'in pivot dönüşlerini kemik pozlarına yazar
class Kopru extends Node:
	var root: Node3D
	var skel: Skeleton3D
	var piv := []
	var mix := []

	func _process(_dt: float) -> void:
		sync()

	func _rs(n: Node3D) -> Transform3D:
		var t := Transform3D.IDENTITY
		var c: Node = n
		while c != null and c != root:
			t = (c as Node3D).transform * t
			c = c.get_parent()
		return t

	func sync() -> void:
		if skel == null or not is_instance_valid(skel):
			return
		for e in piv:
			var n: Node3D = e[1]
			skel.set_bone_pose_position(e[0], n.position)
			skel.set_bone_pose_rotation(e[0], n.quaternion)
			skel.set_bone_pose_scale(e[0], n.scale)
		for e in mix:
			var g: Transform3D = (_rs(e[1]) * e[2]).interpolate_with(_rs(e[3]) * e[4], e[5])
			skel.set_bone_pose_position(e[0], g.origin)
			skel.set_bone_pose_rotation(e[0], g.basis.get_rotation_quaternion())
			skel.set_bone_pose_scale(e[0], g.basis.get_scale())


## Yüzeyi derili ağ olarak iskelete bağla
func finish(mat: Material) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_NORMAL] = Nn
	arr[Mesh.ARRAY_COLOR] = Cc
	arr[Mesh.ARRAY_BONES] = Bi
	arr[Mesh.ARRAY_WEIGHTS] = Wt
	arr[Mesh.ARRAY_INDEX] = Ix
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "ElGovde"
	mi.mesh = am
	mi.material_override = mat
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = skel.create_skin_from_rest_transforms()
	mi.extra_cull_margin = 2.0
	kopru.sync()
	return mi


# ------------------------------------------------------------------ ağırlık
func _bi(b) -> int:
	if b is int:
		return b
	return int(bones[b])


## [[kemik, ağırlık], ...] -> en ağır 4, toplamı 1
func skin(list: Array) -> void:
	var acc := {}
	for e in list:
		var w := float(e[1])
		if w <= 0.0:
			continue
		var k := _bi(e[0])
		acc[k] = float(acc.get(k, 0.0)) + w
	var arr := []
	for k in acc:
		arr.append([k, acc[k]])
	arr.sort_custom(func(x, y): return x[1] > y[1])
	if arr.is_empty():
		arr = [[_bi(list[0][0]) if not list.is_empty() else 0, 1.0]]
	var tot := 0.0
	for i in mini(4, arr.size()):
		tot += float(arr[i][1])
	for i in 4:
		if i < arr.size():
			Bi.append(int(arr[i][0]))
			Wt.append(float(arr[i][1]) / tot)
		else:
			Bi.append(0)
			Wt.append(0.0)


## Zincir boyunca ağırlık: anchors [[koordinat, kemik], ...] artan ya da azalan; x bu koordinatta
static func chain(x: float, anchors: Array) -> Array:
	var n := anchors.size()
	var asc := float(anchors[n - 1][0]) > float(anchors[0][0])
	for i in n - 1:
		var a: float = anchors[i][0]
		var b: float = anchors[i + 1][0]
		if (x <= b) if asc else (x >= b):
			if (x <= a) if asc else (x >= a):
				return [[anchors[i][1], 1.0]]
			var t := smoothstep(0.0, 1.0, inverse_lerp(a, b, x))
			return [[anchors[i][1], 1.0 - t], [anchors[i + 1][1], t]]
	return [[anchors[n - 1][1], 1.0]]


# ------------------------------------------------------------------ yüzey
## Halka satırlarından yüzey (normaller yüzlerden). rows[j][i] nokta, cols / skins aynı biçimde
func grid(rows: Array, cols: Array, skins: Array, closed: bool) -> void:
	var nj := rows.size()
	var ni: int = (rows[0] as Array).size()
	var base := V.size()
	var nr := []
	nr.resize(nj * ni)
	nr.fill(Vector3.ZERO)
	var nq: int = ni if closed else ni - 1
	for j in nj - 1:
		for i in nq:
			var i2 := (i + 1) % ni
			var a: Vector3 = rows[j][i]
			var fn: Vector3 = -(rows[j][i2] - a).cross(rows[j + 1][i2] - a)
			var fn2: Vector3 = -(rows[j + 1][i2] - a).cross(rows[j + 1][i] - a)
			fn += fn2
			for v in [[i, j], [i2, j], [i2, j + 1], [i, j + 1]]:
				nr[v[1] * ni + v[0]] += fn
	for j in nj:
		for i in ni:
			var p: Vector3 = rows[j][i]
			V.append(p)
			var n0: Vector3 = nr[j * ni + i]
			var nn := n0.normalized() if n0.length_squared() > 1e-14 else Vector3.UP
			Nn.append(nn)
			var c: Color = cols[j][i]
			Cc.append(shade.call(c, nn) if shade.is_valid() else c)
			skin(skins[j][i])
	for j in nj - 1:
		for i in nq:
			var i2 := (i + 1) % ni
			var q0 := base + j * ni + i
			var q1 := base + j * ni + i2
			var q2 := base + (j + 1) * ni + i2
			var q3 := base + (j + 1) * ni + i
			Ix.append_array(PackedInt32Array([q0, q1, q2, q0, q2, q3]))


## Yüzey satırlarının yönünü düzelt: dış normal ref yönüne baksın
static func _orient(rows: Array, cols: Array, skins: Array, ref_out: Vector3, j: int, closed := true) -> void:
	var r0: Array = rows[j]
	var r1: Array = rows[j + 1]
	var a: Vector3 = r0[0]
	var fn: Vector3 = -(r0[1] - a).cross(r1[1] - a)
	if fn.dot(ref_out) < 0.0:
		for k in rows.size():
			(rows[k] as Array).reverse()
			(cols[k] as Array).reverse()
			(skins[k] as Array).reverse()


## Tüp: pts yerel noktalar (Catmull-Rom), rad aynı noktalarda Vector2(yan rx, üst ry).
## upv: kesitin "üst" yönü (Vector3 ya da Callable(t) -> Vector3); a = 0 üst, a = PI/2 yan (T x U).
## colf(t, a, p) -> renk, skinf(t, a, p) -> kemik listesi, bump(t, a) -> yarıçap çarpanı farkı. xf: yerel -> tasarım uzayı.
## Döndürdüğü örnekleyici (at / at_dir) yüzeye oturan tutam, şerit, diş için.
func tube(pts: Array, rad: Array, colf: Callable, skinf: Callable, rings: int, seg: int, upv = Vector3.UP, cap0 := false, cap1 := true, bump := Callable(), xf := Transform3D.IDENTITY) -> Dictionary:
	var DP := []
	var DR := []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(0, i - 1)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(n - 1, i + 2)]
		var r0: Vector2 = rad[maxi(0, i - 1)]
		var r1: Vector2 = rad[i]
		var r2: Vector2 = rad[i + 1]
		var r3: Vector2 = rad[mini(n - 1, i + 2)]
		for k in 12:
			var u := float(k) / 12.0
			DP.append(Loft._cr(p0, p1, p2, p3, u))
			var rr: Vector2 = Loft._cr(r0, r1, r2, r3, u)
			DR.append(Vector2(maxf(rr.x, 0.004), maxf(rr.y, 0.004)))
	DP.append(pts[n - 1])
	DR.append(rad[n - 1])
	var m := DP.size()
	var cum := [0.0]
	for i in m - 1:
		cum.append(float(cum[i]) + (DP[i + 1] - DP[i]).length())
	var L: float = cum[m - 1]
	var info := {"C": [], "U": [], "S": [], "R": [], "T": [], "rings": rings, "bump": bump, "xf": xf, "L": L}
	var rows := []
	var cols := []
	var skins := []
	var k := 0
	var prevU := Vector3.ZERO
	for j in rings + 1:
		var t := float(j) / rings
		var s := t * L
		while k < m - 2 and s > float(cum[k + 1]):
			k += 1
		var u := clampf((s - float(cum[k])) / maxf(1e-6, float(cum[k + 1]) - float(cum[k])), 0.0, 1.0)
		var ctr: Vector3 = (DP[k] as Vector3).lerp(DP[k + 1], u)
		var rr: Vector2 = (DR[k] as Vector2).lerp(DR[k + 1], u)
		var T: Vector3 = (DP[mini(m - 1, k + 2)] - DP[maxi(0, k - 1)]).normalized()
		var up: Vector3 = upv.call(t) if upv is Callable else upv
		var U := up - T * up.dot(T)
		if U.length() < 0.08:
			U = prevU - T * prevU.dot(T) if prevU != Vector3.ZERO else T.cross(Vector3.RIGHT if absf(T.x) < 0.9 else Vector3.FORWARD)
		U = U.normalized()
		prevU = U
		var S := T.cross(U).normalized()
		info["C"].append(ctr)
		info["U"].append(U)
		info["S"].append(S)
		info["R"].append(rr)
		info["T"].append(T)
		var ro := []
		var co := []
		var so := []
		for i in seg:
			var a := TAU * i / seg
			var b := 1.0 + (float(bump.call(t, a)) if bump.is_valid() else 0.0)
			var p := ctr + (U * cos(a) * rr.y + S * sin(a) * rr.x) * b
			ro.append(xf * p)
			co.append(colf.call(t, a, p))
			so.append(skinf.call(t, a, p))
		rows.append(ro)
		cols.append(co)
		skins.append(so)
	var jm := clampi(rings / 2, 0, rings - 1)
	_orient(rows, cols, skins, xf.basis * (info["U"][jm] as Vector3), jm)
	if cap1:
		var pl: Vector3 = info["C"][rings]
		var ro := []
		for i in seg:
			ro.append(xf * pl)
		rows.append(ro)
		cols.append((cols[rings] as Array).duplicate())
		skins.append((skins[rings] as Array).duplicate())
	if cap0:
		var pf: Vector3 = info["C"][0]
		var ro := []
		for i in seg:
			ro.append(xf * pf)
		rows.push_front(ro)
		cols.push_front((cols[0] as Array).duplicate())
		skins.push_front((skins[0] as Array).duplicate())
	grid(rows, cols, skins, true)
	return info


## Örnekleyici: yerel uzayda [nokta, normal] (t 0..1 tüp boyunca, a kesit açısı)
static func at(info: Dictionary, t: float, a: float, lift := 0.0) -> Array:
	var rings: int = info["rings"]
	var x := clampf(t, 0.0, 1.0) * rings
	var j := mini(int(x), rings - 1)
	var f := x - j
	var C: Vector3 = (info["C"][j] as Vector3).lerp(info["C"][j + 1], f)
	var U: Vector3 = (info["U"][j] as Vector3).lerp(info["U"][j + 1], f).normalized()
	var S: Vector3 = (info["S"][j] as Vector3).lerp(info["S"][j + 1], f).normalized()
	var R: Vector2 = (info["R"][j] as Vector2).lerp(info["R"][j + 1], f)
	var bump: Callable = info["bump"]
	var b := 1.0 + (float(bump.call(t, a)) if bump.is_valid() else 0.0)
	var nrm := (U * cos(a) / maxf(R.y, 0.01) + S * sin(a) / maxf(R.x, 0.01)).normalized()
	return [C + (U * cos(a) * R.y + S * sin(a) * R.x) * b + nrm * lift, nrm]


## Normali dir'e en çok bakan kesit açısı
static func a_dir(info: Dictionary, t: float, dir: Vector3) -> float:
	var best := 0.0
	var bd := -9.0
	for i in 72:
		var a := TAU * i / 72.0
		var d: float = (at(info, t, a)[1] as Vector3).dot(dir.normalized())
		if d > bd:
			bd = d
			best = a
	return best


## Yüzeye oturan kabartma şerit (göz bandı, dudak, kas çizgisi): path [(t, a), ...], wfn(u) yarı genişlik
func band(info: Dictionary, path: Array, wfn: Callable, col: Color, skinf: Callable, lift := 0.03, dens := 6) -> void:
	var dp := []
	for i in path.size() - 1:
		for k in dens:
			dp.append((path[i] as Vector2).lerp(path[i + 1], float(k) / dens))
	dp.append(path[path.size() - 1])
	var xf: Transform3D = info["xf"]
	var n := dp.size()
	var pts := []
	var nrs := []
	for q in dp:
		var s := at(info, q.x, q.y)
		pts.append(s[0])
		nrs.append(s[1])
	var rows := []
	var cols := []
	var skins := []
	for i in n:
		var d: Vector3 = (pts[mini(n - 1, i + 1)] - pts[maxi(0, i - 1)]).normalized()
		var o: Vector3 = nrs[i]
		var w: float = wfn.call(float(i) / (n - 1))
		var sd := d.cross(o).normalized() * w
		var p: Vector3 = pts[i]
		var sw: Array = skinf.call(dp[i].x, dp[i].y, p)
		rows.append([xf * (p + sd - o * 0.02), xf * (p + sd * 0.8 + o * lift), xf * (p - sd * 0.8 + o * lift), xf * (p - sd - o * 0.02)])
		cols.append([col, col, col, col])
		skins.append([sw, sw, sw, sw])
	var a: Vector3 = rows[0][1]
	var fn: Vector3 = -(rows[0][2] - a).cross(rows[1][2] - a)
	if fn.dot(xf.basis * (nrs[0] as Vector3)) < 0.0:
		for k in rows.size():
			(rows[k] as Array).reverse()
	grid(rows, cols, skins, false)


## Sivri yassı kürk tutamı: kökü yüzeyin içinde, geniş yüzü yüzeye yatık; ağırlığı oturduğu yüzeyinki
func tuft(base: Vector3, nrm: Vector3, dir: Vector3, ln: float, w: float, col: Color, sw: Array, xf := Transform3D.IDENTITY, thick := 0.32, curl := 0.12) -> void:
	var d := dir.normalized()
	var o := (nrm - d * nrm.dot(d)).normalized()
	if o.length() < 0.1:
		o = nrm
	var p0 := base - nrm * w * 0.9 - d * w * 0.4   # kök yüzeyin iyice içinde: dışarıda yassı leke bırakmaz
	var pts := [p0, base + d * ln * 0.3 + o * ln * curl * 0.5, base + d * ln * 0.68 + o * ln * curl, base + d * ln + o * ln * curl * 0.6]
	var rad := [Vector2(w * 0.55, w * thick * 0.7), Vector2(w * 0.62, w * thick * 0.8), Vector2(w * 0.34, w * thick * 0.55), Vector2(0.01, 0.01)]
	tube(pts, rad, func(t, _a, _p): return col.lightened(0.06 * t), func(_t, _a, _p): return sw, 6, 7, o, false, true, Callable(), xf)


## Pençe / diş: sivri, hafif kıvrık koni (kökü gömülü)
func claw(base: Vector3, dir: Vector3, ln: float, r: float, col: Color, sw: Array, xf := Transform3D.IDENTITY, bend_dir := Vector3.ZERO, seg := 7) -> void:
	var d := dir.normalized()
	var bd := bend_dir if bend_dir != Vector3.ZERO else d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.UP)
	bd = (bd - d * bd.dot(d)).normalized()
	var pts := [base - d * r * 0.8, base + d * ln * 0.45 + bd * ln * 0.07, base + d * ln * 0.8 + bd * ln * 0.03, base + d * ln - bd * ln * 0.06]
	var rad := [Vector2(r, r), Vector2(r * 0.78, r * 0.7), Vector2(r * 0.4, r * 0.36), Vector2(0.006, 0.006)]
	tube(pts, rad, func(_t, _a, _p): return col, func(_t, _a, _p): return sw, 6, seg, bd, false, true, Callable(), xf)
