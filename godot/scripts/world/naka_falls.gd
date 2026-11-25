class_name NakaFalls
extends RefCounted
## Naka Nehri'nin kaynağı: Hokage Kayası'nın batı yamacından dökülen şelale.
## Tek su perdesi mesh'i kaya yüzünü izler (her yükseklikte kaya derinliği ölçülür: havada durmaz, kayaya gömülmez),
## gölgelendiricide aşağı kayan akış çizgileri + kenar / dip köpüğü; dipte köpüklü, kaynayan gölet nehrin başına bağlanır,
## iki yanda ve gölet kıyısında kayalar. Toplam iki mesh, iki malzeme.

const ROWS := 18
const COLS := 6
const MID := 3   # orta sütun
const GAP := 0.9   # su perdesi kaya yüzünden bu kadar önde akar

static var _falls_mat: ShaderMaterial
static var _pool_mat: ShaderMaterial


static func _gy(b: Builder, x: float, n: float) -> float:
	var wp = b.w(Vector3(x, 0, n))
	return Game.terrain_height(wp.x, wp.z) - b.origin.y


## build_konoha._cliff_surface ile aynı arama (kaba 8 m adım + ikili arama); kaya bulunmazsa NAN döner
static func _surface(b: Builder, x: float, cliff_n: float, y: float) -> float:
	var nn = cliff_n - 140.0
	while nn < cliff_n + 220.0:
		if _gy(b, x, nn + 8.0) > y:
			var lo = nn
			var hi = nn + 8.0
			for k in 4:
				var mid = (lo + hi) * 0.5
				if _gy(b, x, mid) > y:
					hi = mid
				else:
					lo = mid
			return hi
		nn += 8.0
	return NAN


## at: nehrin ilk kontrol noktası (x, n); cliff_n: kayalık çizgisi
static func build(b: Builder, decor: Node3D, at: Vector2, cliff_n: float) -> void:
	var g = _gy(b, at.x, at.y)
	var y_pool = g + 0.42
	# kayalığın tepesi (şelale ağzı): nehir başından kuzeye arazinin en yüksek yeri; en çok 46 m
	var hmax = g
	var nn = at.y
	while nn < cliff_n + 220.0:
		hmax = maxf(hmax, _gy(b, at.x, nn))
		nn += 4.0
	var y_top = minf(g + 46.0, hmax - 0.4)
	if y_top < y_pool + 4.0:
		y_top = y_pool + 4.0
	var w_top = 7.0
	var w_bot = 11.0
	# ---- su perdesi: her sütun için yukarıdan aşağı kaya derinliği; su geri kayaya girmez (yukarıdan süren en küçük n)
	var grid: Array = []   # [satır][sütun] -> Vector3 (x, y, n)
	var prev: Array = []
	for c in COLS:
		prev.append(INF)
	for r in ROWS:
		var t = float(r) / (ROWS - 1)
		var y = lerpf(y_top, y_pool - 0.15, t)
		var half = lerpf(w_top, w_bot, t * t) * 0.5
		var row: Array = []
		for c in COLS:
			var u = float(c) / (COLS - 1)
			var x = at.x + (u - 0.5) * 2.0 * half
			var s = _surface(b, x, cliff_n, y + 0.5)
			var n = prev[c]
			if not is_nan(s):
				n = minf(n, s - GAP)
			if is_inf(n):
				n = cliff_n - 2.0
			if r == 0:
				n -= 0.6   # ağızda su biraz dışarı fırlar
			n = maxf(n, at.y + 5.0)   # dipteki yükselen arazi perdeyi göletin önüne çekmesin
			prev[c] = n
			row.append(Vector3(x, y, n))
		grid.append(row)
	# sütunlar arası yumuşatma (kaya pürüzü perdeyi kırışık göstermesin)
	for r in ROWS:
		var row: Array = grid[r]
		var sm: Array = []
		for c in COLS:
			var a: Vector3 = row[maxi(0, c - 1)]
			var m: Vector3 = row[c]
			var d: Vector3 = row[mini(COLS - 1, c + 1)]
			sm.append(Vector3(m.x, m.y, minf(m.z, (a.z + m.z * 2.0 + d.z) * 0.25)))   # yalnız kayadan uzaklaştırır
		grid[r] = sm
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	for r in ROWS:
		if r > 0:
			var p0: Vector3 = grid[r - 1][MID]
			var p1: Vector3 = grid[r][MID]
			along += p0.distance_to(p1)
		for c in COLS:
			var p: Vector3 = grid[r][c]
			st.set_color(Color(0.0, float(r) / (ROWS - 1), 0.0))
			st.set_uv(Vector2(float(c) / (COLS - 1), along * 0.25))
			st.add_vertex(b.w(Vector3(p.x, p.y, p.z)))
	for r in ROWS - 1:
		for c in COLS - 1:
			var i0 = r * COLS + c
			st.add_index(i0)
			st.add_index(i0 + 1)
			st.add_index(i0 + COLS)
			st.add_index(i0 + 1)
			st.add_index(i0 + COLS + 1)
			st.add_index(i0 + COLS)
	st.generate_normals()
	var fm = MeshInstance3D.new()
	fm.mesh = st.commit()
	fm.material_override = _falls()
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fm.visibility_range_end = b.view_dist
	b.root.add_child(fm)
	# ---- dip göleti: merkez çarpma noktası, güneyde nehrin başına uzanır; kenarı nehir suyuna karışır
	var imp: Vector3 = grid[ROWS - 1][MID]
	var n_imp = imp.z - 0.4
	var rx = w_bot * 0.5 + 3.5
	var rs = maxf(6.0, n_imp - at.y + 2.5)   # güneye (nehre) doğru
	var rn = 2.0                              # kuzeye (kaya dibine) doğru
	var ps = SurfaceTool.new()
	ps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var SEG := 28
	var RING := 6
	ps.set_uv(Vector2.ZERO)
	ps.set_normal(Vector3.UP)
	ps.add_vertex(b.w(Vector3(at.x, y_pool, n_imp)))
	for k in RING:
		var rr = float(k + 1) / RING
		for s in SEG:
			var a = TAU * s / SEG
			var dx = cos(a)
			var dn = sin(a)
			var px = at.x + dx * rx * rr
			var pn = n_imp + dn * (rn if dn > 0.0 else rs) * rr
			ps.set_uv(Vector2(dx, dn) * rr)
			ps.set_normal(Vector3.UP)
			ps.add_vertex(b.w(Vector3(px, y_pool, pn)))
	for s in SEG:
		ps.add_index(0)
		ps.add_index(1 + s)
		ps.add_index(1 + (s + 1) % SEG)
	for k in RING - 1:
		for s in SEG:
			var a0 = 1 + k * SEG + s
			var a1 = 1 + k * SEG + (s + 1) % SEG
			ps.add_index(a0)
			ps.add_index(a0 + SEG)
			ps.add_index(a1)
			ps.add_index(a1)
			ps.add_index(a0 + SEG)
			ps.add_index(a1 + SEG)
	var pm = MeshInstance3D.new()
	pm.mesh = ps.commit()
	pm.material_override = _pool()
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pm.visibility_range_end = b.view_dist
	b.root.add_child(pm)
	var mid_n = n_imp - (rs - rn) * 0.5
	var wc = b.w(Vector3(at.x, y_pool, mid_n))
	Game.add_water(pm, Vector2(wc.x, wc.z), Vector2(rx * 2.0, rs + rn), 0.0, wc.y, true)
	b._grass_clear(b.w(Vector3(at.x, 0, mid_n)), Vector3(rx * 2.0 + 2.0, 0.1, rs + rn + 2.0), 0.0)   # suyun içinden çimen çıkmasın
	# ---- kayalar: perdenin iki yanında büyük kaya, gölet kıyısında irili ufaklı, suyun içinde bir iki yassı taş, ağızda çerçeve
	var rng = RandomNumberGenerator.new()
	rng.seed = 4711
	var col = Color(0.47, 0.45, 0.42)
	for sd in [-1.0, 1.0]:
		var bx = at.x + sd * (w_bot * 0.5 + 1.8)
		b.boulder(Vector3(bx, _gy(b, bx, n_imp + 0.5) - 0.3, n_imp + 0.5), Vector3(4.6, 3.8, 4.2) * rng.randf_range(0.9, 1.15), col.darkened(rng.randf_range(0.0, 0.15)), 3 + int(sd), true, rng.randf() * 360.0)
		var tx = at.x + sd * (w_top * 0.5 + 1.2)
		var s_top = _surface(b, tx, cliff_n, y_top - 1.0)
		if not is_nan(s_top):
			b.boulder(Vector3(tx, y_top - 1.2, s_top - 0.6), Vector3(3.2, 2.4, 3.0), col.darkened(0.1), 7 + int(sd), false, rng.randf() * 360.0)
	for i in 9:
		var a = lerpf(-0.15, PI + 0.15, (i + rng.randf_range(-0.3, 0.3)) / 8.0) + PI   # güney yarım halka (nehir ağzı hariç)
		var dx = cos(a)
		var dn = sin(a)
		if absf(dx) < 0.35:
			continue   # nehrin girişi açık kalsın
		var px = at.x + dx * (rx + 0.4)
		var pn = n_imp + dn * (rs + 0.4)
		var sz = rng.randf_range(1.0, 2.2)
		b.boulder(Vector3(px, _gy(b, px, pn) + 0.1, pn), Vector3(sz * 1.2, sz * 0.7, sz), col.lightened(rng.randf_range(-0.05, 0.08)), i, sz > 1.6, rng.randf() * 360.0)
	for i in 3:
		var px = at.x + rng.randf_range(-rx, rx) * 0.6
		var pn = n_imp - rng.randf_range(2.5, rs * 0.7)
		b.boulder(Vector3(px, y_pool - 0.25, pn), Vector3(1.4, 0.6, 1.2) * rng.randf_range(0.8, 1.3), col.darkened(0.2), 11 + i, false, rng.randf() * 360.0)


static func _falls() -> ShaderMaterial:
	if _falls_mat == null:
		_falls_mat = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// şelale perdesi: UV.x enine (0..1), UV.y aşağı doğru metre/4; COLOR.g = 0 ağız, 1 dip
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
void vertex() {
	float w = vn(vec2(UV.x * 5.0, UV.y * 0.6 - TIME * 1.3));
	VERTEX += NORMAL * (w - 0.5) * 0.35;
}
void fragment() {
	vec2 uv = UV;
	float down = COLOR.g;
	float t = TIME;
	// dikey uzamış, aşağı kayan çizgiler (üç ölçek, farklı hız)
	float s1 = vn(vec2(uv.x * 16.0, uv.y * 0.9 - t * 2.2));
	float s2 = vn(vec2(uv.x * 38.0 + 5.0, uv.y * 1.8 - t * 3.4));
	float s3 = vn(vec2(uv.x * 7.0 + 11.0, uv.y * 0.4 - t * 1.4));
	float body = s1 * 0.5 + s2 * 0.3 + s3 * 0.2;
	vec3 deep = vec3(0.14, 0.38, 0.55);
	vec3 light = vec3(0.55, 0.8, 0.93);
	vec3 foam = vec3(0.94, 0.97, 1.0);
	vec3 c = mix(deep, light, smoothstep(0.3, 0.75, body));
	float hi = smoothstep(0.66, 0.8, s2 * 0.6 + s1 * 0.4);                  // beyaz akış çizgileri
	float edge = min(uv.x, 1.0 - uv.x);
	float edgef = smoothstep(0.2, 0.02, edge + (s1 - 0.5) * 0.1);           // yanlarda köpük
	float lip = smoothstep(0.08, 0.0, down + (s2 - 0.5) * 0.04);            // ağızda köpük
	float bot = smoothstep(0.7, 0.98, down + (s2 - 0.5) * 0.2);             // dipte çalkantı
	float f = clamp(hi * 0.75 + edgef + lip * 0.7 + bot, 0.0, 1.0);
	c = mix(c, foam, f);
	ALBEDO = c;
	EMISSION = c * 0.12;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.45;
	// yırtık kenarlar: perde düz çizgiyle bitmez
	ALPHA = smoothstep(0.0, 0.05, edge - (s2 - 0.5) * 0.07 - (s3 - 0.5) * 0.04);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
		_falls_mat.shader = sh
	return _falls_mat


static func _pool() -> ShaderMaterial:
	if _pool_mat == null:
		_pool_mat = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// dip göleti: UV = çarpma noktasından normalize uzaklık (r = 0 merkez, 1 kenar); köpük halkaları dışa yayılır,
// merkezde su kaynar (köşeler yukarı oynar), kenar nehir suyu rengine karışır
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
void vertex() {
	float r = length(UV);
	float boil = smoothstep(0.5, 0.0, r);
	VERTEX.y += boil * (0.15 + 0.6 * vn(UV * 9.0 + vec2(TIME * 1.7, -TIME * 1.3)));
}
void fragment() {
	float r = length(UV);
	vec2 d = r > 0.001 ? UV / r : vec2(0.0, 1.0);
	float t = TIME;
	float ring = vn(d * 3.0 + vec2(r * 9.0 - t * 1.5, 0.0) + d.yx * 2.0);
	float pt = vn(UV * 7.0 + d * (r * 4.0 - t * 0.9));
	float churn = smoothstep(0.55, 0.15, r + (ring - 0.5) * 0.35);          // merkezde beyaz çalkantı
	float trail = smoothstep(0.62, 0.78, pt) * smoothstep(1.0, 0.35, r);  // dışa akan köpük lekeleri
	vec3 deep = vec3(0.05, 0.2, 0.27);
	vec3 shallow = vec3(0.13, 0.36, 0.42);
	vec3 foam = vec3(0.93, 0.97, 1.0);
	vec3 c = mix(deep, shallow, pt * 0.6);
	c = mix(c, foam, clamp(churn + trail * 0.8, 0.0, 1.0));
	ALBEDO = c;
	EMISSION = foam * churn * 0.1;
	ROUGHNESS = mix(0.08, 0.6, churn);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = mix(0.88, 1.0, churn) * smoothstep(1.0, 0.86, r);
}
"""
		_pool_mat.shader = sh
	return _pool_mat
