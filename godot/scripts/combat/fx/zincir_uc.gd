extends MultiMeshInstance3D
## Ucu ağırlıklı gerçek zincir (hedef: res://scripts/combat/fx/zincir_uc.gd). Flail ve Kusari Fūbō kullanır; görsel parçaları silah verir.
## Verlet düğümleri: sap sallanınca zincir gecikir, ağırlık savrulur (ikincil hareket). Vuruşta uç bir süre yola bağlanır (drive),
## bırakılınca hızını koruyarak salınmaya döner. Oyuncu ve düşman aynı.

const N := 9
const GRAV := 15.0

var anchor: Node3D
var off := Vector3.ZERO
var body: Node3D          # zemin yüksekliği için karakter
var head: MeshInstance3D
var length := 1.0
var pts: Array = []
var prv: Array = []
var ready_pts := false
var d_t := -1.0
var d_T := 0.0
var d_path := Callable()


func setup(owner_body: Node3D, a: Node3D, o: Vector3, head_mesh: Mesh, link_mesh: Mesh, L: float) -> void:
	body = owner_body
	anchor = a
	off = o
	length = L
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link_mesh
	mm.instance_count = N * 2
	multimesh = mm
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	head = MeshInstance3D.new()
	head.mesh = head_mesh
	add_child(head)
	process_priority = 60


func drive(T: float, path: Callable) -> void:
	d_T = maxf(T, 0.02)
	d_t = 0.0
	d_path = path


func _reset(A: Vector3) -> void:
	pts.clear()
	prv.clear()
	for i in N + 1:
		var p = A + Vector3.DOWN * length * float(i) / N
		pts.append(p)
		prv.append(p)
	ready_pts = true


func _process(dt: float) -> void:
	if not is_instance_valid(anchor):
		visible = false
		return
	var A: Vector3 = anchor.to_global(off)
	var cam = get_viewport().get_camera_3d()
	if not anchor.is_visible_in_tree() or (cam != null and cam.global_position.distance_squared_to(A) > 1600.0):
		visible = false
		return
	visible = true
	global_transform = Transform3D.IDENTITY
	if not ready_pts or (pts[0] as Vector3).distance_to(A) > 3.5:
		_reset(A)
	var h = minf(dt, 0.033)
	for i in range(1, N + 1):
		var p: Vector3 = pts[i]
		var v: Vector3 = (p - (prv[i] as Vector3)) * 0.985
		prv[i] = p
		pts[i] = p + v + Vector3.DOWN * GRAV * h * h
	var seg = length / N
	var driving = d_t >= 0.0 and d_path.is_valid()
	if driving:
		d_t += dt
		var k = clampf(d_t / d_T, 0.0, 1.0)
		var q: Vector3 = d_path.call(k, A)
		pts[N] = q
		seg = maxf(seg, A.distance_to(q) / N)   # uzak vuruşta zincir gerilir
		if k >= 1.0:
			d_t = -1.0
	for _it in 6:
		pts[0] = A
		for i in N:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var d = b - a
			var l = d.length()
			if l < 0.0001:
				continue
			var e = d * (1.0 - seg / l)
			var wa = 0.0 if i == 0 else 0.5
			var wb = 1.0 if i == 0 else 0.5
			if i + 1 == N:   # ağır uç: zincir ona uyar
				wb = 0.0 if driving else 0.2
				wa = 1.0 - wb
			pts[i] = a + e * wa
			pts[i + 1] = b - e * wb
	if is_instance_valid(body):
		var fl = body.global_position.y + 0.08
		for i in range(1, N + 1):
			var p: Vector3 = pts[i]
			if p.y < fl:
				p.y = fl
				pts[i] = p
	var mi = 0
	for i in N:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var dv = b - a
		var dn = dv.normalized() if dv.length() > 0.001 else Vector3.DOWN
		var x = dn.cross(Vector3.UP if absf(dn.y) < 0.9 else Vector3.RIGHT).normalized()
		var st = maxf(0.6, dv.length() * 0.5 / 0.05)
		for j in 2:
			var xx = x if j == 0 else x.rotated(dn, PI * 0.5)
			multimesh.set_instance_transform(mi, Transform3D(Basis(dn * st, xx, dn.cross(xx)), a.lerp(b, (j + 0.5) * 0.5)))
			mi += 1
	var tip: Vector3 = pts[N]
	var td: Vector3 = tip - (pts[N - 1] as Vector3)
	var tn = td.normalized() if td.length() > 0.001 else Vector3.DOWN
	head.global_transform = Transform3D(Basis.looking_at(-tn, Vector3.UP if absf(tn.y) < 0.95 else Vector3.RIGHT), tip)
