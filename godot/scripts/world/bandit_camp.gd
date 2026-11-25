extends RefCounted
## Haritadaki "Haydut Kampı" (world.json landmark bandit_camp). Eskiden 9 eğik prizma çatı + tek silindirdi ("aşırı kötü").
## Kaynak: refs/bandit_camp (sb_camp_pot: kanvas çadır + tencere sehpası, sb_canopy_camp: mahya çadırları + halatlar + ateş,
## sb_official_camp: eşya üstüne gerilmiş derme bezler, Gatosthugs / MujinaBandits: derme çatma haydut çetesi).
## Düzen: sivri kazık çit (kapı yola bakar, iki yanda gözcü kulesi, arkada üçüncü kule), ortada ateş + kütük oturaklar,
## ateşe bakan mahya / konik çadırlar, büyük lider çadırı, ganimet sundurması, silah sehpaları, çamaşır ipi, kafes,
## odun yığını, kurutma sehpası, toprak patikalar (RoadMap), dışarıda ağaçlar ve kayalar. Her parça kendi zemin yüksekliğinde.
## Çarpışma görselin kendi şeklinden: kazıklar dilim dilim, kule ayak / döşeme / korkuluk / çatı, çadır yüzleri (içine girilir).

const R_WALL := 30.0
const BARK := Color(0.4, 0.29, 0.18)
const POLE := Color(0.36, 0.26, 0.16)
const PLANK := Color(0.5, 0.37, 0.24)

var b: Builder
var rng := RandomNumberGenerator.new()
var F := Vector2(0, 1)   # kapı yönü (yerel x doğu, n kuzey)
var Rt := Vector2(1, 0)
var kind := "bandit"


static func build(parent: Node3D, l: Dictionary, enemy_kind := "bandit") -> void:
	var c = load("res://scripts/world/bandit_camp.gd").new()
	c.kind = enemy_kind
	c._build(parent, l)


## (f, r) kamp düzlemi -> yerel (x, n): f kapıya doğru, r sağa
func _xn(f: float, r: float) -> Vector2:
	return F * f + Rt * r


func gy(x: float, n: float) -> float:
	var wp = b.w(Vector3(x, 0, n))
	return Game.terrain_height(wp.x, wp.z) - b.origin.y


## (f, r) noktasının dünya konumu (zeminde) + dy
func W(f: float, r: float, dy := 0.0) -> Vector3:
	var p = _xn(f, r)
	return b.w(Vector3(p.x, gy(p.x, p.y) + dy, p.y))


## Dünya dönüşümü: (f, r) zemininde, +z yerel ekseni dünya xz'de `face` yönüne bakar (face kamp düzleminde (f, r) yönü)
func xf(f: float, r: float, face: Vector2, dy := 0.0) -> Transform3D:
	var d2 = _xn(face.x, face.y).normalized()   # yerel (x, n)
	var d = Vector3(d2.x, 0, -d2.y)   # dünya
	return Transform3D(Basis.looking_at(-d, Vector3.UP), W(f, r, dy))


func face_to(f: float, r: float, tf: float, tr: float) -> Vector2:
	return Vector2(tf - f, tr - r)


func mb(p: Vector3, sz := 4.0) -> MB:
	return b._mb(p, sz)


## [dünya Transform3D, boyut] kutu listesini çarpışmaya ekle
func cols_add(cols: Array) -> void:
	CampKit.add_cols(b, cols)


func _col_box(t: Transform3D, size: Vector3) -> void:
	if not is_instance_valid(b.body):
		return
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.transform = Transform3D(t.basis.orthonormalized(), t.origin)
	b.add_shape(cs)
	b.add_solid(t.origin, size.x * 0.5, size.z * 0.5, 0.0)


## İki dünya noktası arası silindir çarpışma (eğik sırık / bacak)
func _col_rod(a: Vector3, c: Vector3, r: float) -> void:
	if not is_instance_valid(b.body):
		return
	var d = c - a
	var L = d.length()
	if L < 0.05:
		return
	var y = d / L
	var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y).normalized()
	var cs = CollisionShape3D.new()
	var sh = CylinderShape3D.new()
	sh.radius = r
	sh.height = L
	cs.shape = sh
	cs.transform = Transform3D(Basis(x, y, z), (a + c) * 0.5)
	b.add_shape(cs)
	b.add_solid((a + c) * 0.5, r, r, 0.0)


func _build(parent: Node3D, l: Dictionary) -> void:
	b = Builder.new(parent, l["x"], l["y"], l["base"], "Kamp")
	b.landscape = false
	rng.seed = 2131
	# kapı, Konoha'dan gelen yolun son parçasına bakar
	var road_dir = Vector2(-0.74, 0.67)
	for rd in Game.roads:
		if String(rd.get("b", "")) == "bandit_camp" or String(rd.get("a", "")) == "bandit_camp":
			var pts: PackedVector2Array = rd["pts"]
			if pts.size() >= 2:
				var c = Vector2(float(l["x"]), float(l["y"]))
				var far_pt = pts[pts.size() - 2] if pts[pts.size() - 1].distance_to(c) < pts[0].distance_to(c) else pts[1]
				road_dir = (far_pt - c).normalized()
			break
	F = road_dir
	_layout(float(l["x"]), float(l["y"]))
	# düşmanlar (eski kamp ile aynı: 6 haydut, açık zemine doğar, çit içinde gezer)
	Spawner.camp(b.w(Vector3(0, gy(0, 0), 0)), kind, 6)
	b.finish()


## Vahşi doğadaki haydut / kaçak kampı POI'si (PoiBuilder "camp"): aynı kamp, verilen Builder'a; kapı en yakın yola
## (200 m içinde yoksa POI yönüne) bakar. Düşmanları PoiBuilder doğurur. b.finish() çağıranda.
static func build_poi(pb: Builder, p: Dictionary) -> void:
	var c = load("res://scripts/world/bandit_camp.gd").new()
	c.b = pb
	c.rng.seed = hash(String(p["id"]))
	var m = Vector2(float(p["x"]), float(p["y"]))
	var rp: Vector2 = Roadside._nearest_road_point(m, 200.0)
	if rp != Vector2.INF and rp.distance_to(m) > 1.0:
		c.F = (rp - m).normalized()
	else:
		var yw = deg_to_rad(float(p.get("yaw", 0.0)))
		c.F = Vector2(sin(yw), cos(yw))
	c._layout(m.x, m.y)


func _layout(mx: float, my: float) -> void:
	Roadside._add_clear(mx, my, R_WALL + 8.0)   # orman ağaçları / çalı çitin içinden çıkmasın
	Rt = Vector2(F.y, -F.x)
	_ground_paths()
	_palisade()
	_gate()
	_tower(R_WALL - 4.2, -7.0, 0.0)
	_tower(R_WALL - 4.2, 7.0, 0.0)
	_tower(-R_WALL + 4.5, 9.0, 1.0)
	_fire_area()
	_tents()
	_loot_shelter()
	_props()
	_surroundings()


# ---------------------------------------------------------------- zemin: toprak patikalar ve çiğnenmiş meydan
func _ground_paths() -> void:
	var RM = preload("res://scripts/world/road_map.gd")
	var lane = func(f0: float, r0: float, f1: float, r1: float, half: float) -> void:
		var a = W(f0, r0); var e = W(f1, r1)
		RM.add_lane(Vector2(a.x, a.z), Vector2(e.x, e.z), half, true)
	lane.call(R_WALL + 14.0, 0.0, 2.0, 0.0, 2.3)   # kapıdan ateşe
	for k in 6:   # ateş çevresi çiğnenmiş meydan (yıldız şeritler)
		var a = TAU * k / 6.0
		lane.call(cos(a) * 6.5, sin(a) * 6.5, -cos(a) * 6.5, -sin(a) * 6.5, 3.6)
	lane.call(0.0, 0.0, -15.0, 0.0, 1.4)   # lider çadırına
	lane.call(0.0, 0.0, -9.0, 15.0, 1.2)   # ganimet sundurmasına
	lane.call(0.0, 0.0, 5.0, -16.0, 1.1)
	lane.call(R_WALL - 6.0, 0.0, R_WALL - 5.0, -12.0, 1.0)
	for k in 9:   # tellerin içinde, çit boyunca dolanan nöbet patikası (parça parça)
		var a0 = TAU * (k + 0.1) / 9.0; var a1 = TAU * (k + 0.9) / 9.0
		lane.call(cos(a0) * 24.5, sin(a0) * 24.5, cos(a1) * 24.5, sin(a1) * 24.5, 1.1)
	for sp in [[60.0, 12.5], [95.0, 13.0], [128.0, 12.0], [-62.0, 12.5], [-100.0, 13.5], [-138.0, 12.5], [40.0, 19.0], [-40.0, 19.0]]:   # ateşten çadır kapılarına
		var a2 = deg_to_rad(sp[0])
		lane.call(cos(a2) * 4.5, sin(a2) * 4.5, cos(a2) * (sp[1] - 1.2), sin(a2) * (sp[1] - 1.2), 0.9)


# ---------------------------------------------------------------- sivri kazık çit
## Çit yarıçapı açıya göre hafif dalgalı (elle çakılmış, pergelle çizilmemiş); kapı (0) ve arka (180) hizasında tam R_WALL
func wall_r(a: float) -> float:
	return R_WALL * (1.0 + 0.045 * sin(3.0 * a) + 0.025 * sin(5.0 * a))


func _palisade() -> void:
	var gate_half = 3.4
	var circ = TAU * R_WALL
	var n = int(circ / 0.4)
	var seg_logs: Array = []
	var rails_prev = null
	for i in n:
		var a = TAU * i / n
		var f = cos(a) * wall_r(a)
		var r = sin(a) * wall_r(a)
		if f > 0.0 and absf(r) < gate_half:
			if not seg_logs.is_empty():
				_palisade_col(seg_logs)
				seg_logs = []
			rails_prev = null
			continue
		var d = 0.3 + rng.randf() * 0.12
		var h = 3.3 + rng.randf() * 0.6 + (0.25 if i % 7 == 0 else 0.0)
		var base = W(f, r, -0.35)
		var lean = Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
		var top = base + Vector3(0, h, 0) + lean
		var m = mb(base, 4.5)
		var col = BARK.darkened(rng.randf() * 0.22).lerp(Color(0.46, 0.38, 0.26), rng.randf() * 0.25)
		CampKit._rod(m, Transform3D.IDENTITY, base, top, d * 0.5, col, 6)
		CampKit._rodk(m, Transform3D.IDENTITY, "cone", top - Vector3(0, 0.02, 0), top + Vector3(0, 0.55 + rng.randf() * 0.2, 0) + lean * 0.3, d * 0.5, col.lightened(0.12), 6)
		seg_logs.append([base, top, d])
		if seg_logs.size() >= 6:
			_palisade_col(seg_logs)
			seg_logs = [seg_logs[seg_logs.size() - 1]]
		# iç yüzde iki bağlama kirişi (her 6 kazıkta bir parça) + ip sargısı
		if i % 6 == 0:
			var ri = wall_r(a) - 0.35
			var p_cur = [W(cos(a) * ri, sin(a) * ri, 0.9), W(cos(a) * ri, sin(a) * ri, 2.5)]
			if rails_prev != null:
				for k in 2:
					CampKit._rod(m, Transform3D.IDENTITY, rails_prev[k], p_cur[k], 0.09, BARK.darkened(0.15), 5)
			rails_prev = p_cur
	if not seg_logs.is_empty():
		_palisade_col(seg_logs)


## Kazık dilimi çarpışması: dilimin ilk-son kazığı arasında, kazık boyunca (sivri uçlar hariç) eğik olmayan ince kutu
func _palisade_col(logs: Array) -> void:
	if logs.size() < 2:
		var only = logs[0]
		_col_rod(only[0], only[1], only[2] * 0.5)
		return
	var a: Vector3 = logs[0][0]
	var e: Vector3 = logs[logs.size() - 1][0]
	var lo = INF; var hi = -INF
	for lg in logs:
		lo = minf(lo, (lg[0] as Vector3).y)
		hi = maxf(hi, (lg[1] as Vector3).y)
	var mid = (a + e) * 0.5
	var d = Vector3(e.x - a.x, 0, e.z - a.z)
	var L = d.length() + 0.4
	var yaw = atan2(-d.z, d.x)
	_col_box(Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, (lo + hi) * 0.5, mid.z)), Vector3(L, hi - lo, 0.42))


# ---------------------------------------------------------------- kapı: iki kalın direk, kiriş, tabela, iki kanat (biri açık)
func _gate() -> void:
	var fg = R_WALL
	var m = mb(W(fg, 0), 4.5)
	var I = Transform3D.IDENTITY
	for s in [-1.0, 1.0]:
		var p0 = W(fg, s * 3.6, -0.4)
		var p1 = p0 + Vector3(0, 5.6, 0)
		CampKit._rod(m, I, p0, p1, 0.32, BARK.darkened(0.1), 8)
		CampKit._rodk(m, I, "cone", p1, p1 + Vector3(0, 0.6, 0), 0.32, BARK.lightened(0.05), 8)
		_col_rod(p0, p1, 0.32)
		# direğe bağlı meşale
		var tp = W(fg - 0.7, s * 2.9)
		CampKit.torch(m, I, tp, 2.3)
		_col_rod(tp, tp + Vector3(0, 2.3, 0), 0.06)
		CampKit.fire_fx(b.root, tp + Vector3(0, 2.25, 0), 0.45)
	var a = W(fg, -4.2, 4.9); var e = W(fg, 4.2, 4.9)
	a.y = maxf(a.y, e.y); e.y = a.y
	CampKit._rod(m, I, a, e, 0.22, BARK.darkened(0.2), 7)
	_col_rod(a, e, 0.22)
	# tabela: kirişten iki iple asılı tahta, üstünde kırmızı çapraz çentik (çete işareti)
	var sg = (a + e) * 0.5 - Vector3(0, 1.0, 0)
	var t = xf(fg + 0.25, 0, Vector2(1, 0))
	var sb = Transform3D(t.basis, sg)
	CampKit._p(m, sb, "box", Vector3.ZERO, Vector3(1.8, 0.6, 0.08), PLANK.darkened(0.15))
	CampKit._p(m, sb, "box", Vector3(0, 0, 0.05), Vector3(1.2, 0.09, 0.02), Color(0.6, 0.12, 0.1), Vector3(0, 0, 18))
	CampKit._p(m, sb, "box", Vector3(0, 0, 0.05), Vector3(1.2, 0.09, 0.02), Color(0.6, 0.12, 0.1), Vector3(0, 0, -18))
	for s in [-1.0, 1.0]:
		CampKit._rod(m, I, sg + t.basis.x * (0.75 * s) + Vector3(0, 0.3, 0), (a + e) * 0.5 + t.basis.x * (0.85 * s), 0.012, CampKit.ROPE, 4)
	# kanatlar: dikey kütükler + iki yatay kuşak; sol kanat içe 75° açık, sağ kanat 25° aralık
	for s in [-1.0, 1.0]:
		var ang = deg_to_rad(75.0 if s < 0 else 25.0)
		var hinge = Vector2(fg, s * 3.2)
		var inw = Vector2(-sin(ang), -s * cos(ang))   # menteşeden kanat ucuna (f, r)
		var leaf_w = 3.1
		var logs = 8
		var pts: Array = []
		for k in logs:
			var q = hinge + inw * (leaf_w * (k + 0.5) / logs)
			var p0 = W(q.x, q.y, 0.05)
			var p1 = p0 + Vector3(0, 3.6 + (0.2 if k % 2 else 0.0), 0)
			CampKit._rod(m, I, p0, p1, 0.18, BARK.darkened(0.05 + 0.1 * (k % 2)), 6)
			CampKit._rodk(m, I, "cone", p1, p1 + Vector3(0, 0.4, 0), 0.18, BARK.lightened(0.08), 6)
			pts.append(p0)
		for y in [0.8, 2.9]:
			var q0 = W(hinge.x, hinge.y, 0); var q1 = W((hinge + inw * leaf_w).x, (hinge + inw * leaf_w).y, 0)
			CampKit._rod(m, I, q0 + Vector3(0, y, 0) + Vector3(0, 0, 0), q1 + Vector3(0, y, 0), 0.08, BARK.darkened(0.25), 5)
		var c0: Vector3 = pts[0]; var c1: Vector3 = pts[pts.size() - 1]
		var mid = (c0 + c1) * 0.5
		var d = c1 - c0
		_col_box(Transform3D(Basis(Vector3.UP, atan2(-d.z, d.x)), mid + Vector3(0, 1.9, 0)), Vector3(Vector2(d.x, d.z).length() + 0.36, 3.8, 0.36))


# ---------------------------------------------------------------- gözcü kulesi (yagura): 4 eğik bacak, çapraz destek, döşeme,
# kazık korkuluk, dört dikmeli piramit çatı, merdiven
func _tower(f: float, r: float, rear: float) -> void:
	var I = Transform3D.IDENTITY
	var g0 = W(f, r)
	var m = mb(g0, 4.5)
	var hp = 6.0   # döşeme
	var foot = 1.8
	var topw = 1.35
	var ax = Vector3(_xn(1, 0).x, 0, -_xn(1, 0).y).normalized()   # dünya f yönü
	var az = Vector3(_xn(0, 1).x, 0, -_xn(0, 1).y).normalized()   # dünya r yönü
	var base_y = g0.y
	var corners: Array = []
	for sf in [-1.0, 1.0]:
		for sr in [-1.0, 1.0]:
			var fp = Vector2(f + sf * foot, r + sr * foot)
			var p0 = W(fp.x, fp.y, -0.3)
			var p1 = g0 + ax * (sf * topw) + az * (sr * topw)
			p1.y = base_y + hp + 2.3
			CampKit._rod(m, I, p0, p1, 0.17, BARK.darkened(0.05), 7)
			_col_rod(p0, p1, 0.17)
			corners.append([p0, p1, sf, sr])
	var at_h = func(c: Array, y: float) -> Vector3:
		var p0: Vector3 = c[0]; var p1: Vector3 = c[1]
		return p0.lerp(p1, clampf((y - p0.y) / (p1.y - p0.y), 0.0, 1.0))
	# çapraz destekler (her yüz, iki kat) + yatay kuşaklar
	var order = [0, 1, 3, 2, 0]
	for k in 4:
		var c0 = corners[order[k]]; var c1 = corners[order[k + 1]]
		for lv in [[base_y + 0.6, base_y + 3.2], [base_y + 3.2, base_y + hp - 0.2]]:
			CampKit._rod(m, I, at_h.call(c0, lv[0]), at_h.call(c1, lv[1]), 0.07, BARK.darkened(0.18), 5)
			CampKit._rod(m, I, at_h.call(c1, lv[0]), at_h.call(c0, lv[1]), 0.07, BARK.darkened(0.18), 5)
		CampKit._rod(m, I, at_h.call(c0, base_y + 3.2), at_h.call(c1, base_y + 3.2), 0.08, BARK.darkened(0.1), 5)
	# döşeme (tahtalar) + kirişler
	var py = base_y + hp
	var pw = topw * 2.0 + 0.9
	var bas = Basis(ax, Vector3.UP, az)
	var pt = Transform3D(bas, Vector3(g0.x, py, g0.z))
	for k in 7:
		var o = -pw * 0.5 + pw * (k + 0.5) / 7.0
		CampKit._p(m, pt, "box", Vector3(o, 0, 0), Vector3(pw / 7.0 - 0.03, 0.12, pw), PLANK.darkened(0.06 * (k % 3)))
	for s in [-1.0, 1.0]:
		CampKit._p(m, pt, "box", Vector3(0, -0.15, s * pw * 0.4), Vector3(pw + 0.2, 0.2, 0.2), BARK.darkened(0.2))
	_col_box(Transform3D(bas, Vector3(g0.x, py - 0.05, g0.z)), Vector3(pw, 0.22, pw))
	# korkuluk: üç yanda sık kısa kazıklar + üst kiriş; merdiven tarafı (kamp içine bakan) açık
	var open_side = -1.0 if rear < 0.5 else 1.0   # kapı kuleleri içe (f-), arka kule içe (f+)
	for side in 4:
		var nrm = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][side]
		if side == (0 if open_side > 0 else 1):
			continue
		var tan = Vector3(nrm.z, 0, nrm.x)
		var cnt = 9
		for k in cnt:
			var o = -pw * 0.5 + pw * (k + 0.5) / cnt
			var lp = nrm * (pw * 0.5 - 0.06) + tan * o
			CampKit._p(m, pt, "cyl", lp + Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), BARK.darkened(0.08 * (k % 2)), Vector3.ZERO, 5)
		CampKit._p(m, pt, "box", nrm * (pw * 0.5 - 0.06) + Vector3(0, 1.08, 0), Vector3(absf(tan.x) * pw + 0.12, 0.12, absf(tan.z) * pw + 0.12), BARK.darkened(0.2))
		var wc = pt * (nrm * (pw * 0.5 - 0.06) + Vector3(0, 0.6, 0))
		_col_box(Transform3D(bas, wc), Vector3(absf(tan.x) * pw + 0.12 + absf(nrm.x) * 0.15, 1.2, absf(tan.z) * pw + 0.12 + absf(nrm.z) * 0.15))
	# çatı: dört dikme + kare piramit (koni 4 dilim, 45°) + saçak
	for sf in [-1.0, 1.0]:
		for sr in [-1.0, 1.0]:
			var c = pt * Vector3(sf * (pw * 0.5 - 0.1), 0, sr * (pw * 0.5 - 0.1))
			CampKit._rod(m, I, c, c + Vector3(0, 2.3, 0), 0.07, POLE, 5)
	var rt = Transform3D(bas * Basis(Vector3.UP, PI * 0.25), Vector3(g0.x, py + 2.3, g0.z))
	CampKit._p(m, rt, "cone", Vector3(0, 0.75, 0), Vector3(pw * 1.62, 1.5, pw * 1.62), Color(0.52, 0.44, 0.3), Vector3.ZERO, 4)
	CampKit._p(m, rt, "cone", Vector3(0, 0.02, 0), Vector3(pw * 1.64, 0.08, pw * 1.64), Color(0.38, 0.3, 0.2), Vector3.ZERO, 4)
	var rp = PackedVector3Array()
	for k in 4:
		var aa = TAU * k / 4.0
		rp.append(rt.basis * Vector3(cos(aa) * pw * 0.81, 0.0, sin(aa) * pw * 0.81))
	rp.append(Vector3(0, 1.5, 0))
	b._collide_convex(rt.origin, rp, pw * 0.8)
	# merdiven: açık yandan zemine eğik
	var lt = pt * Vector3(open_side * (pw * 0.5 - 0.05), 0.0, 0.0)
	var lb = W(f + open_side * (pw * 0.5 + 2.4), r, 0.0)
	var side_v = az * 0.32
	for s in [-1.0, 1.0]:
		CampKit._rod(m, I, lb + side_v * s, lt + side_v * s + Vector3(0, 0.9, 0), 0.05, POLE, 5)
	var rungs = 14
	for k in range(1, rungs):
		var q = lb.lerp(lt, float(k) / rungs)
		CampKit._rod(m, I, q - side_v, q + side_v, 0.03, POLE.lightened(0.1), 4)
	var lm = (lb + lt) * 0.5
	var ld = lt - lb
	var lz = ld.normalized()
	var lx = az
	_col_box(Transform3D(Basis(lx, lz.cross(lx), lz), lm), Vector3(0.75, 0.08, ld.length()))


# ---------------------------------------------------------------- ateş: taş halka, odunlar, tencere sehpası, kütük oturaklar, kase/testi
func _fire_area() -> void:
	var t = xf(0, 0, Vector2(1, 0))
	var m = mb(t.origin, 4.0)
	CampKit.campfire(m, t, true)
	CampKit.fire_fx(b.root, t.origin)
	for k in 5:
		var a = TAU * k / 5.0 + 0.3
		var f = cos(a) * 3.4; var r = sin(a) * 3.4
		var lt = xf(f, r, Vector2(-sin(a), cos(a)), 0.22)
		var L = 1.8 + rng.randf() * 0.5
		CampKit._rod(m, Transform3D.IDENTITY, lt * Vector3(0, 0, -L * 0.5), lt * Vector3(0, 0, L * 0.5), 0.24, BARK.darkened(rng.randf() * 0.15), 8)
		CampKit._p(m, lt, "cyl", Vector3(0, 0, L * 0.5), Vector3(0.44, 0.02, 0.44), Color(0.66, 0.52, 0.34), Vector3(90, 0, 0), 8)   # kesik yüz
		_col_rod(lt * Vector3(0, 0, -L * 0.5), lt * Vector3(0, 0, L * 0.5), 0.24)
	# ateş kenarında kaseler, sake testisi, şiş
	for k in 3:
		var a2 = TAU * k / 3.0 + 1.0
		var p = xf(cos(a2) * 1.9, sin(a2) * 1.9, Vector2(1, 0))
		CampKit._p(m, p, "hemi", Vector3(0, 0.07, 0), Vector3(0.22, 0.28, 0.22), Color(0.6, 0.3, 0.2) if k % 2 else Color(0.3, 0.28, 0.26), Vector3(180, 0, 0), 8)
	var jt = xf(2.4, -1.2, Vector2(1, 0))
	CampKit._p(m, jt, "sphere", Vector3(0, 0.2, 0), Vector3(0.34, 0.4, 0.34), Color(0.78, 0.72, 0.6), Vector3.ZERO, 8)
	CampKit._p(m, jt, "cyl", Vector3(0, 0.45, 0), Vector3(0.1, 0.14, 0.1), Color(0.78, 0.72, 0.6), Vector3.ZERO, 6)
	for k in 2:
		var s0 = W(-1.2 + k * 2.2, 1.0 - k * 0.3, 0.0)
		var s1 = W(-0.4 + k * 1.2, 0.3 - k * 0.1, 0.75)
		CampKit._rod(m, Transform3D.IDENTITY, s0, s1, 0.012, Color(0.6, 0.5, 0.35), 4)
		CampKit._p(m, Transform3D(Basis(), s0.lerp(s1, 0.8)), "sphere", Vector3.ZERO, Vector3(0.12, 0.16, 0.12), Color(0.62, 0.42, 0.26), Vector3.ZERO, 6)


# ---------------------------------------------------------------- çadırlar: ateşe bakan mahya / konik çadırlar + lider çadırı
func _tents() -> void:
	var cloths = [Color(0.72, 0.66, 0.52), Color(0.56, 0.52, 0.38), Color(0.5, 0.46, 0.4), Color(0.62, 0.5, 0.36), Color(0.45, 0.47, 0.36), Color(0.66, 0.6, 0.5)]
	var spots = [[60.0, 12.5, "ridge"], [95.0, 13.0, "cone"], [128.0, 12.0, "ridge"], [-62.0, 12.5, "ridge"], [-100.0, 13.5, "ridge"], [-138.0, 12.5, "cone"], [150.0, 19.5, "ridge"], [40.0, 19.0, "ridge"], [-40.0, 19.0, "ridge"]]
	for i in spots.size():
		var a = deg_to_rad(float(spots[i][0]))
		var rr: float = spots[i][1]
		var f = cos(a) * rr; var r = sin(a) * rr
		var face = face_to(f, r, 0, 0)
		var t = xf(f, r, face)
		var cols: Array = []
		var cl: Color = cloths[i % cloths.size()].darkened(rng.randf() * 0.08)
		if spots[i][2] == "cone":
			CampKit.cone_tent(mb(t.origin, 4.0), t, cl, 1.9 + rng.randf() * 0.3, 2.9 + rng.randf() * 0.3, cols)
		else:
			CampKit.tent(mb(t.origin, 4.0), t, cl, 2.7 + rng.randf() * 0.4, 2.0 + rng.randf() * 0.25, 3.3 + rng.randf() * 0.5, rng, 0.0, cols)
		cols_add(cols)
	# lider çadırı: büyük duvar çadırı (iki açıklık), önünde sandık ve bayrak direği
	var lf = -18.0
	var lt = xf(lf, 0, Vector2(1, 0))
	var lc: Array = []
	CampKit.tent(mb(lt.origin, 5.0), lt, Color(0.58, 0.28, 0.22), 4.4, 3.1, 6.0, rng, 1.25, lc)
	cols_add(lc)
	var ct = xf(lf + 4.2, 1.9, Vector2(1, 0.3))
	CampKit.crate(mb(ct.origin, 2.0), ct, 0.8, Color(0.42, 0.28, 0.18))
	CampKit._p(mb(ct.origin, 2.0), ct, "torus", Vector3(0, 0.45, 0.41), Vector3(0.14, 0.14, 0.05), Color(0.7, 0.6, 0.3), Vector3(90, 0, 0), 8)
	_col_box(Transform3D(ct.basis, ct.origin + Vector3(0, 0.4, 0)), Vector3(0.8, 0.8, 0.8))
	var fp = W(lf + 4.0, -2.8)
	var m = mb(fp, 4.5)
	CampKit._rod(m, Transform3D.IDENTITY, fp + Vector3(0, -0.3, 0), fp + Vector3(0, 6.5, 0), 0.07, POLE, 6)
	_col_rod(fp, fp + Vector3(0, 6.5, 0), 0.08)
	var bt = Transform3D(xf(lf + 4.0, -2.8, Vector2(0, 1)).basis, fp + Vector3(0, 6.3, 0))
	var flag_f = func(u: float, v: float) -> Vector3: return Vector3(0.04 * sin(u * 7.0), -v * 1.5, 0.1 + u * 1.0)
	CampKit._cloth(m, bt, flag_f, 4, 3, Color(0.55, 0.12, 0.1), Vector3(-1, -0.7, 0.6), 77, -100.0)
	CampKit._rod(m, Transform3D.IDENTITY, fp + Vector3(0, 6.32, 0), bt * Vector3(0, 0, 1.15), 0.02, POLE, 4)


# ---------------------------------------------------------------- ganimet sundurması (çalıntı mal) + odun sundurması
func _loot_shelter() -> void:
	var I = Transform3D.IDENTITY
	var st = xf(-10.0, 17.5, Vector2(0.35, -1))
	var m = mb(st.origin, 4.5)
	var cols: Array = []
	CampKit.lean_to(m, st, Color(0.42, 0.44, 0.36), 5.2, 3.2, 2.4, cols)
	cols_add(cols)
	# altında: sandıklar, fıçılar, çuvallar, pirinç balyaları, testiler
	var items = [["crate", -1.6, -1.2, 0.9], ["crate", -1.6, -1.2, 0.0], ["barrel", -0.4, -1.9, 1.0], ["barrel", 0.5, -2.0, 0.9], ["sack", 1.5, -1.4, 1.0],
		["sack", 1.1, -0.9, 0.85], ["bale", 0.0, -0.8, 1.0], ["crate", 2.0, -2.3, 0.0], ["jar", -0.9, -0.4, 1.0]]
	for it in items:
		var lt = st * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(it[1], 0, it[2]))
		lt.origin.y = Game.terrain_height(lt.origin.x, lt.origin.z)
		match it[0]:
			"crate":
				var s = 0.85 if it[3] == 0.0 else 0.75
				if it[3] > 0.0:
					lt.origin.y += 0.85   # üst üste
				CampKit.crate(m, lt, s)
				_col_box(Transform3D(lt.basis, lt.origin + Vector3(0, s * 0.5, 0)), Vector3(s, s, s))
			"barrel":
				CampKit.barrel(m, lt, it[3])
				_col_rod(lt.origin, lt.origin + Vector3(0, it[3], 0), it[3] * 0.36)
			"sack":
				CampKit.sack(m, lt, it[3])
			"bale":   # saman bağlı pirinç balyası (yatay)
				CampKit._p(m, lt, "cyl", Vector3(0, 0.35, 0), Vector3(0.7, 1.1, 0.7), Color(0.82, 0.72, 0.45), Vector3(0, 0, 90), 9)
				for k in 2:
					CampKit._p(m, lt, "cyl", Vector3(-0.3 + k * 0.6, 0.35, 0), Vector3(0.73, 0.06, 0.73), CampKit.ROPE.darkened(0.2), Vector3(0, 0, 90), 9)
			"jar":
				CampKit._p(m, lt, "sphere", Vector3(0, 0.3, 0), Vector3(0.5, 0.55, 0.5), Color(0.45, 0.3, 0.22), Vector3.ZERO, 8)
				CampKit._p(m, lt, "cyl", Vector3(0, 0.6, 0), Vector3(0.24, 0.12, 0.24), Color(0.4, 0.27, 0.2), Vector3.ZERO, 8)
	# ikinci sundurma: odun yığını (kütük istifi) + kesme kütüğü ve balta
	var wt = xf(-6.0, -20.0, Vector2(0.2, 1))
	var m2 = mb(wt.origin, 4.5)
	var c2: Array = []
	CampKit.lean_to(m2, wt, Color(0.5, 0.42, 0.32), 4.0, 2.4, 2.0, c2)
	cols_add(c2)
	for row in 3:
		for k in 6 - row:
			var y = 0.17 + row * 0.3
			var x = -1.3 + k * 0.32 + row * 0.16
			CampKit._p(m2, wt, "cyl", Vector3(x, y, -1.2), Vector3(0.3, 1.6, 0.3), BARK.darkened(0.05 * ((k + row) % 3)), Vector3(90, rng.randf_range(-4, 4), 0), 7)
	_col_box(Transform3D(wt.basis, wt * Vector3(-0.5, 0.48, -1.2)), Vector3(2.0, 0.96, 1.6))
	var bk = xf(-2.6, -17.3, Vector2(1, 0))
	CampKit._p(m2, bk, "cyl", Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7), BARK, Vector3.ZERO, 9)
	CampKit._p(m2, bk, "cyl", Vector3(0, 0.605, 0), Vector3(0.62, 0.01, 0.62), Color(0.68, 0.55, 0.36), Vector3.ZERO, 9)
	CampKit._rod(m2, I, bk * Vector3(0.05, 0.62, 0.0), bk * Vector3(0.5, 1.15, 0.35), 0.025, Color(0.45, 0.33, 0.2), 4)
	CampKit._p(m2, bk, "box", Vector3(0.05, 0.66, 0.0), Vector3(0.22, 0.16, 0.03), Color(0.6, 0.62, 0.66), Vector3(0, -35, 40))
	_col_rod(bk.origin, bk.origin + Vector3(0, 0.6, 0), 0.35)
	for k in 5:   # yere saçılmış yarık odunlar
		var q = xf(-2.0 + rng.randf_range(-1.0, 1.0), -16.2 + rng.randf_range(-1.0, 1.0), Vector2(rng.randf() - 0.5, rng.randf() - 0.5))
		CampKit._p(m2, q, "box", Vector3(0, 0.07, 0), Vector3(0.14, 0.12, 0.55), Color(0.62, 0.48, 0.3), Vector3.ZERO)


# ---------------------------------------------------------------- dağınık eşya: silah sehpaları, çamaşır ipi, kafes, kurutma sehpası,
# su fıçıları, sandık yığınları, hedef tahtası
func _props() -> void:
	var I = Transform3D.IDENTITY
	for wr in [[7.5, 3.8, Vector2(-1, -0.5)], [-5.5, -4.5, Vector2(1, 0.8)], [19.5, -6.0, Vector2(0, 1)]]:
		var t = xf(wr[0], wr[1], wr[2])
		CampKit.weapon_rack(mb(t.origin, 3.0), t, rng)
		_col_box(Transform3D(t.basis, t.origin + Vector3(0, 0.75, 0)), Vector3(2.2, 1.5, 0.5))
	# çamaşır ipi: iki direk arası, asılı bezler
	var la = Vector2(10.0, -15.0); var lb = Vector2(4.0, -21.0)
	var ta = W(la.x, la.y); var tb = W(lb.x, lb.y)
	var dx = Vector3(tb.x - ta.x, 0, tb.z - ta.z)
	var L = dx.length()
	var lt = Transform3D(Basis(Vector3.UP, atan2(-dx.z, dx.x)), ta)
	lt.origin.y = minf(ta.y, tb.y)
	CampKit.cloth_line(mb(ta, 3.0), lt, L, 2.3 + absf(ta.y - tb.y), rng)
	_col_rod(ta, ta + Vector3(0, 2.4, 0), 0.06)
	_col_rod(tb, tb + Vector3(0, 2.4, 0), 0.06)
	# esir kafesi: kalın çerçeve + sık çubuklar + bağlı kapı, içinde saman
	var ct = xf(-15.0, -12.5, Vector2(1, 0.5))
	var m = mb(ct.origin, 4.0)
	var cw = 2.2; var ch = 1.9
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			CampKit._p(m, ct, "box", Vector3(sx * cw * 0.5, ch * 0.5, sz * cw * 0.5), Vector3(0.14, ch, 0.14), BARK.darkened(0.15))
	for y in [0.08, ch]:
		for s in [-1.0, 1.0]:
			CampKit._p(m, ct, "box", Vector3(0, y, s * cw * 0.5), Vector3(cw, 0.12, 0.12), BARK.darkened(0.2))
			CampKit._p(m, ct, "box", Vector3(s * cw * 0.5, y, 0), Vector3(0.12, 0.12, cw), BARK.darkened(0.2))
	for k in 7:
		var o = -cw * 0.5 + cw * (k + 0.5) / 7.0
		for s in [-1.0, 1.0]:
			CampKit._p(m, ct, "cyl", Vector3(o, ch * 0.5, s * cw * 0.5), Vector3(0.07, ch, 0.07), BARK, Vector3.ZERO, 5)
			if s > 0.0 or k % 2 == 0:
				CampKit._p(m, ct, "cyl", Vector3(s * cw * 0.5, ch * 0.5, o), Vector3(0.07, ch, 0.07), BARK, Vector3.ZERO, 5)
	for k in 5:
		CampKit._p(m, ct, "box", Vector3(-cw * 0.5 + cw * (k + 0.5) / 5.0, ch + 0.08, 0), Vector3(cw / 5.0 - 0.03, 0.06, cw + 0.1), PLANK.darkened(0.1))
	CampKit._p(m, ct, "cyl", Vector3(0.3, 0.12, -0.3), Vector3(1.2, 0.2, 1.0), Color(0.78, 0.68, 0.42), Vector3.ZERO, 8)
	CampKit._p(m, ct, "torus", Vector3(cw * 0.5 + 0.02, 1.0, 0.5), Vector3(0.18, 0.2, 0.18), CampKit.ROPE, Vector3(0, 0, 90), 8)
	for sx in [-1.0, 1.0]:
		_col_box(Transform3D(ct.basis, ct * Vector3(sx * cw * 0.5, ch * 0.5, 0)), Vector3(0.14, ch, cw))
		_col_box(Transform3D(ct.basis, ct * Vector3(0, ch * 0.5, sx * cw * 0.5)), Vector3(cw, ch, 0.14))
	_col_box(Transform3D(ct.basis, ct * Vector3(0, ch + 0.08, 0)), Vector3(cw, 0.08, cw))
	# kurutma sehpası: iki A ayak + kiriş, asılı balıklar ve et şeritleri
	var dt = xf(9.0, 15.5, Vector2(-0.6, -1))
	var md = mb(dt.origin, 3.0)
	for sx in [-1.0, 1.0]:
		CampKit._rod(md, I, dt * Vector3(sx * 1.2, 0, -0.5), dt * Vector3(sx * 1.2, 1.9, 0), 0.04, POLE, 5)
		CampKit._rod(md, I, dt * Vector3(sx * 1.2, 0, 0.5), dt * Vector3(sx * 1.2, 1.9, 0), 0.04, POLE, 5)
	CampKit._rod(md, I, dt * Vector3(-1.35, 1.85, 0), dt * Vector3(1.35, 1.85, 0), 0.04, POLE, 5)
	for k in 7:
		var x = -1.0 + k * 0.33
		var top = dt * Vector3(x, 1.83, 0)
		CampKit._rod(md, I, top, top - Vector3(0, 0.15, 0), 0.006, CampKit.ROPE, 3)
		if k % 2 == 0:
			CampKit._p(md, Transform3D(dt.basis, top - Vector3(0, 0.42, 0)), "sphere", Vector3.ZERO, Vector3(0.12, 0.55, 0.05), Color(0.55, 0.52, 0.48), Vector3.ZERO, 6)
			CampKit._p(md, Transform3D(dt.basis, top - Vector3(0, 0.72, 0)), "cone", Vector3.ZERO, Vector3(0.14, 0.12, 0.03), Color(0.45, 0.42, 0.4), Vector3(180, 0, 0), 4)
		else:
			CampKit._p(md, Transform3D(dt.basis, top - Vector3(0, 0.36, 0)), "box", Vector3.ZERO, Vector3(0.09, 0.45, 0.02), Color(0.5, 0.2, 0.15))
	_col_box(Transform3D(dt.basis, dt * Vector3(0, 0.95, 0)), Vector3(2.5, 1.9, 0.12))
	# kapı içi: su fıçıları, kova, sandık yığını
	for k in 3:
		var q = xf(21.5, 3.3 + k * 0.85, Vector2(1, 0))
		CampKit.barrel(mb(q.origin, 2.0), q, 1.05, Color(0.44, 0.31, 0.2).darkened(0.05 * k))
		_col_rod(q.origin, q.origin + Vector3(0, 1.05, 0), 0.38)
	var kv = xf(20.6, 5.7, Vector2(1, 0))
	CampKit._p(mb(kv.origin, 1.0), kv, "cyl", Vector3(0, 0.2, 0), Vector3(0.4, 0.4, 0.4), Color(0.5, 0.38, 0.24), Vector3.ZERO, 8)
	for st in [[22.5, -3.5, 0], [22.5, -3.5, 1], [21.4, -4.3, 0], [12.0, 20.0, 0], [11.2, 20.6, 0], [11.6, 20.3, 1]]:
		var q = xf(st[0], st[1], Vector2(1, rng.randf_range(-0.4, 0.4)))
		var s = 0.9 if st[2] == 0 else 0.7
		q.origin.y += 0.9 * st[2]
		CampKit.crate(mb(q.origin, 2.0), q, s)
		_col_box(Transform3D(q.basis, q.origin + Vector3(0, s * 0.5, 0)), Vector3(s, s, s))
	# hedef tahtası (kunai talimi): saman dolu hasır kütük, saplanmış kunailer
	var tt = xf(4.0, 19.0, face_to(4.0, 19.0, 2.0, 9.0))
	var mt = mb(tt.origin, 3.0)
	CampKit._p(mt, tt, "cyl", Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6), Color(0.72, 0.62, 0.38), Vector3.ZERO, 9)
	for y in [0.4, 1.0, 1.6]:
		CampKit._p(mt, tt, "cyl", Vector3(0, y, 0), Vector3(0.63, 0.06, 0.63), CampKit.ROPE.darkened(0.25), Vector3.ZERO, 9)
	for k in 3:
		var y2 = 0.8 + k * 0.32
		CampKit._rod(mt, I, tt * Vector3(-0.1 + k * 0.1, y2, 0.28), tt * Vector3(-0.1 + k * 0.1, y2 + 0.04, 0.55), 0.015, Color(0.2, 0.2, 0.22), 4)
	_col_rod(tt.origin, tt.origin + Vector3(0, 1.8, 0), 0.3)


# ---------------------------------------------------------------- çevre: çit dışında ağaçlar ve kayalar (kapı önü + yol boş)
func _surroundings() -> void:
	var rock = Color(0.46, 0.44, 0.41)
	for k in 8:
		var a = TAU * k / 8.0 + 0.5 + rng.randf_range(-0.2, 0.2)
		if cos(a) > 0.8:
			continue
		var rr = R_WALL + rng.randf_range(4.0, 9.0)
		var p = _xn(cos(a) * rr, sin(a) * rr)
		var s = Vector3(rng.randf_range(1.6, 3.2), rng.randf_range(1.2, 2.2), rng.randf_range(1.6, 3.0))
		b.boulder(Vector3(p.x, gy(p.x, p.y) + s.y * 0.3, p.y), s, rock.darkened(rng.randf() * 0.15), 3 + k, true, rng.randf() * 360.0)
	# ağaçlar: kampın çevresi zaten orman (bitki örtüsü yalnız çit + 8 m içini boşaltır); köy süs ağacı (sakura / akçaağaç) yok
