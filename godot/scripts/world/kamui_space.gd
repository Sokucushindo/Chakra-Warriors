extends Node3D
## Kamui Kūkan (神威空間): Obito / Kakashi Mangekyō'sunun bağlı olduğu boyut. Kaynak: refs/kamui_dimension (Narutopedia
## "Kamui Dimension" + Shippuden Kakashi - Obito dövüşü kareleri): simsiyah boşluk, düzensiz ızgarada uzayıp giden boz-mavi beton
## kütleler; üstleri soluk buz mavisi, yanları aşağı doğru kararır, kenarlarında ince açık çizgi, yüzeyde lekeler / çukurcuklar;
## gölgesiz düz ışık, uzaktaki kütleler karanlığa gömülür.
## Dünyanın ALT m üstünde, girilen yerin tam tepesinde kurulur (dünya akışı oyuncunun gerçek yerinde kalsın).
## Oyuncu: kendi Kamui'siyle girer / çıkar (yuva tekniği "Kamui Kūkan", çıkış = bıraktığı yer) ya da düşman Kamui'siyle çekilir
## (çıkış yarığı RIFT_DELAY sn sonra uzakta açılır; kendi Kamui'si varsa hemen çıkabilir).
## Çekilen NPC'ler kayıt olarak burada kalır (Game.profile["kamui_held"]); oyuncu içerideyken tutsak kuşağında durur.
## Yapay zekâ Obito tarzı Mangekyō sahipleri zor durumda buraya kaçar, sonra rakibinin yanında belirir (oyuncuyla aynı kural).
## class_name yok: kullananlar preload eder.

const ALT := 3000.0
const CELL := 20.0
const HALF := 17        # çarpışmalı oyun alanı: ±17 hücre (±350 m)
const FAR := 26         # görsel halka (çarpışmasız siluet) ±26 hücre
const FLOOR := -40.0
const WRAP := 340.0     # bu çizgiyi geçen karşı kenardan girer (sonsuz boyut)
const RIFT_DELAY := 12.0
const SELF_COST := 30.0
const SELF_CD := 20.0
const PULL_IMMUNE := 45.0   # çekilip çıkan oyuncu bu süre yeniden çekilemez
const RETREAT_TIME := 9.0
const RETREAT_CD := 45.0
const MAX_HELD := 24
const TOP := Color(0.58, 0.69, 0.79)
const SIDE_LIT := Color(0.3, 0.39, 0.47)
const SIDE_DIM := Color(0.2, 0.27, 0.34)
const EDGE := Color(0.78, 0.88, 0.98)

static var inst = null

var built := false
var cells: Array = []        # [{"c": Vector2 yerel merkez, "top": float, "ring": int}] oyun alanındaki kütle tepeleri
var player_in := false
var how := ""                # "self" | "pulled"
var ret_pos := Vector3.ZERO
var ret_yaw := 0.0
var rift: Node3D = null
var exit_item := {}
var rift_t := -1.0
var busy := false
var live: Array = []         # içeride duran tutsak düğümleri
var away: Array = []         # [{"e", "until", "from"}] boyuta kaçan yapay zekâ
var _uid := 0


# ------------------------------------------------------------------ erişim
static func node():
	if inst == null or not is_instance_valid(inst):
		inst = load("res://scripts/world/kamui_space.gd").new()
		inst.name = "KamuiKukan"
		Game.get_tree().current_scene.add_child(inst)
	return inst


static func player_inside() -> bool:
	return inst != null and is_instance_valid(inst) and inst.player_in


static func held() -> Array:
	if not Game.profile.has("kamui_held"):
		Game.profile["kamui_held"] = []
	return Game.profile["kamui_held"]


## Oyuncunun Kamui boyutuna erişimi (Obito ya da Kakashi tarzı Mangekyō)
static func has_access(pr: Dictionary) -> bool:
	var st = Eyes.ms_styles(pr)
	return "obito" in st or "kakashi" in st


static func _blocked() -> String:
	if Interiors.inst and Interiors.inst.inside != "":
		return "Kapalı bir yerdesin: Kamui girdabı burada açılmaz."
	if TailedBeasts.mind != null:
		return "Zihin dünyasındasın."
	return ""


# ------------------------------------------------------------------ boyutun kendisi
func _ready() -> void:
	_build()
	visible = false


func _build() -> void:
	if built:
		return
	built = true
	var rng = RandomNumberGenerator.new()
	rng.seed = 6131
	var nz = FastNoiseLite.new()
	nz.seed = 77
	nz.frequency = 0.11
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body = StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	for gx in range(-FAR, FAR + 1):
		for gz in range(-FAR, FAR + 1):
			var ring = maxi(absi(gx), absi(gz))
			var col = ring <= HALF
			if ring <= 1:
				if gx == 0 and gz == 0:   # varış: 3 hücrelik geniş düz kütle
					_block(st, body, Rect2(-29, -29, 58, 58), 0.0, FLOOR, col, rng)
					cells.append({"c": Vector2.ZERO, "top": 0.0, "ring": 0})
				continue
			if ring >= 3 and rng.randf() < 0.07:
				continue   # boşluk: dibe kadar iner (anime: kütle aralarında derin yarıklar)
			var n = nz.get_noise_2d(gx, gz) * 0.5 + 0.5
			var top = snappedf(lerpf(-8.0, 30.0, n) + rng.randf_range(-5.0, 5.0), 1.5)
			if ring == 2:
				top = clampf(top, -1.5, 3.0)   # varışın çevresi: yürüyerek / sıçrayarak geçilir
			elif ring == 3:
				top = clampf(top, -4.5, 7.5)
			if not col:
				top += rng.randf_range(4.0, 26.0)   # uzak siluet: daha yüksek, ufku kapatır
			var c = Vector2(gx, gz) * CELL
			var ml = rng.randf_range(0.6, 4.0)
			var mr = rng.randf_range(0.6, 4.0)
			var mt = rng.randf_range(0.6, 4.0)
			var mb = rng.randf_range(0.6, 4.0)
			var r = Rect2(c.x - CELL * 0.5 + ml, c.y - CELL * 0.5 + mt, CELL - ml - mr, CELL - mt - mb)
			_block(st, body, r, top, FLOOR, col, rng)
			if col:
				cells.append({"c": r.get_center(), "top": top, "ring": ring})
			if rng.randf() < 0.32:
				# üstüne oturan küçük kütle (anime: basamaklı yığınlar); merkezi kapatmaz (doğuş noktası tepe merkezinde)
				var sx = r.size.x * rng.randf_range(0.28, 0.44)
				var sz = r.size.y * rng.randf_range(0.28, 0.44)
				var qx = 1.0 if rng.randf() < 0.5 else -1.0
				var qz = 1.0 if rng.randf() < 0.5 else -1.0
				var cx = r.get_center().x + qx * (r.size.x * 0.5 - sx * 0.5 - 0.4)
				var cz = r.get_center().y + qz * (r.size.y * 0.5 - sz * 0.5 - 0.4)
				_block(st, body, Rect2(cx - sx * 0.5, cz - sz * 0.5, sx, sz), top + snappedf(rng.randf_range(2.5, 10.0), 1.5), top - 0.01, col, rng)
	# dip: yarıklardan düşen burada durur (koyu, ışıksız)
	var ext = (FAR + 1) * CELL
	_block(st, body, Rect2(-ext, -ext, ext * 2.0, ext * 2.0), FLOOR, FLOOR - 4.0, true, rng, 0.25)
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm = ShaderMaterial.new()
	sm.shader = _shader()
	mi.material_override = sm
	mi.extra_cull_margin = 64.0
	add_child(mi)


## Tek kütle: üst yüz + 4 yan (alt yok). UV = yüzdeki metre konumu, UV2 = yüz boyutu (gölgelendirici kenar çizgisini buradan çizer)
func _block(st: SurfaceTool, body: StaticBody3D, r: Rect2, top: float, bottom: float, col: bool, rng: RandomNumberGenerator, dim := 1.0) -> void:
	var x0 = r.position.x
	var z0 = r.position.y
	var x1 = r.end.x
	var z1 = r.end.y
	var v = rng.randf_range(0.93, 1.05) * dim
	var tc = Color(TOP.r * v, TOP.g * v, TOP.b * v)
	_quad(st, [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)], Vector3.UP,
		[tc, tc, tc, tc], [Vector2(0, 0), Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y), Vector2(0, r.size.y)], r.size)
	var h = top - bottom
	var mid = maxf(bottom, top - 16.0)
	var sides = [[Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(0, 0, 1)], [Vector3(x1, 0, z0), Vector3(x0, 0, z0), Vector3(0, 0, -1)],
		[Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(1, 0, 0)], [Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(-1, 0, 0)]]
	for s in sides:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var nrm: Vector3 = s[2]
		var L = a.distance_to(b)
		# ışık önden-soldan: +z ve -x yüzleri açık, diğerleri koyu (anime karelerindeki iki ton)
		var base: Color = SIDE_LIT if (nrm.z > 0.5 or nrm.x < -0.5) else SIDE_DIM
		base = Color(base.r * v, base.g * v, base.b * v)
		var low = base.darkened(0.62)
		var deep = base.darkened(0.88)
		var cm = low
		# üst parça: tepeden 16 m aşağıya base -> low; alt parça: low -> deep
		_quad(st, [Vector3(a.x, top, a.z), Vector3(b.x, top, b.z), Vector3(b.x, mid, b.z), Vector3(a.x, mid, a.z)], nrm,
			[base, base, cm, cm], [Vector2(0, 0), Vector2(L, 0), Vector2(L, top - mid), Vector2(0, top - mid)], Vector2(L, h))
		if mid > bottom + 0.01:
			_quad(st, [Vector3(a.x, mid, a.z), Vector3(b.x, mid, b.z), Vector3(b.x, bottom, b.z), Vector3(a.x, bottom, a.z)], nrm,
				[cm, cm, deep, deep], [Vector2(0, top - mid), Vector2(L, top - mid), Vector2(L, h), Vector2(0, h)], Vector2(L, h))
	if col:
		var bs = BoxShape3D.new()
		bs.size = Vector3(r.size.x, h, r.size.y)
		var o = body.create_shape_owner(body)
		body.shape_owner_add_shape(o, bs)
		body.shape_owner_set_transform(o, Transform3D(Basis.IDENTITY, Vector3(r.get_center().x, (top + bottom) * 0.5, r.get_center().y)))


## Dörtgen (a b c d sırasıyla kenar boyunca); ön yüz normale bakacak sırayla iki üçgen
func _quad(st: SurfaceTool, p: Array, n: Vector3, c: Array, uv: Array, size: Vector2) -> void:
	var tris = [[0, 1, 2], [0, 2, 3]]
	var flip = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(n) > 0.0   # Godot ön yüzü saat yönü: çapraz çarpım normale ters olmalı
	for t in tris:
		var ids = [t[0], t[2], t[1]] if flip else t
		for i in ids:
			st.set_normal(n)
			st.set_color(c[i])
			st.set_uv(uv[i])
			st.set_uv2(size)
			st.add_vertex(p[i])


static func _shader() -> Shader:
	var s = Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 edge_col = vec3(0.78, 0.88, 0.98);
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 p = UV;
	vec3 c = COLOR.rgb;
	// beton: geniş leke + ince kumlanma
	float n = vn(p * 0.18) * 0.5 + vn(p * 0.9) * 0.3 + vn(p * 4.0) * 0.2;
	c *= 0.84 + 0.26 * n;
	// seyrek çukurcuklar
	vec2 g = p * 2.4;
	float pit = step(0.975, h21(floor(g) + 3.1)) * smoothstep(0.2, 0.06, length(fract(g) - 0.5));
	c *= 1.0 - pit * 0.3;
	// kenar çizgisi: yüzün dört kenarı (ekranda en az ~1 piksel)
	float d = min(min(p.x, UV2.x - p.x), min(p.y, UV2.y - p.y));
	float px = fwidth(p.x) + fwidth(p.y);
	float w = max(0.05, px * 0.7);
	float e = 1.0 - smoothstep(w, w + px, d);
	c = mix(c, edge_col * (0.55 + 0.45 * COLOR.r / 0.6), e * 0.8);
	ALBEDO = pow(c, vec3(2.2)) * 1.15;   // renkler anime karesinden (sRGB) okundu: doğrusal ışığa çevir
}
"""
	return s


# ------------------------------------------------------------------ konumlar
## Boyutu (kimse içinde değilken) verilen dünya noktasının tepesine taşır; içerideki kaçaklar da birlikte kayar
func _place_over(wp: Vector3) -> void:
	var o = Vector3(wp.x, Game.terrain_height(wp.x, wp.z) + ALT, wp.z)
	var d = o - global_position
	if player_in or d.length() < 1.0:
		return
	global_position = o
	for a in away:
		if is_instance_valid(a["e"]):
			a["e"].global_position += d


func _top(cell: Dictionary) -> Vector3:
	var c: Vector2 = cell["c"]
	return global_position + Vector3(c.x, float(cell["top"]) + 0.1, c.y)


## Varıştan dist_min..dist_max uzakta, tepesi lo..hi arasında bir kütlenin tepesi (rng ile)
func _cell_at(dmin: float, dmax: float, lo := -99.0, hi := 99.0, rng: RandomNumberGenerator = null) -> Dictionary:
	var c = cells.filter(func(x):
		var L = (x["c"] as Vector2).length()
		return L >= dmin and L <= dmax and float(x["top"]) >= lo and float(x["top"]) <= hi)
	if c.is_empty():
		return cells[0]
	return c[(rng.randi() if rng else randi()) % c.size()]


func arrival() -> Vector3:
	return global_position + Vector3(0, 0.1, 6.0)


# ------------------------------------------------------------------ oyuncu
## Oyuncu boyuta girer. how_: "self" (kendi Kamui'si) | "pulled" (düşman çekti; çıkış yarığı gecikir)
func enter_player(how_: String) -> void:
	var pl = Game.player
	if pl == null or busy or player_in:
		return
	busy = true
	how = how_
	ret_pos = pl.global_position
	ret_yaw = float(pl.yaw)
	_place_over(ret_pos)
	MsArts.kamui_vortex(ret_pos + Vector3.UP * 1.0, 1.3, 1.0)
	Sfx.play("th_teleport", ret_pos, 0.8, 0.7)
	Sfx.play("genjutsu", ret_pos, 0.6, 0.6)
	_shrink(pl, 0.45)
	await get_tree().create_timer(0.45).timeout
	if pl == null or not is_instance_valid(pl):
		busy = false
		return
	await Interiors.inst._fade(1.0, 0.2)
	visible = true
	player_in = true
	Game.set_meta("kamui_space", true)
	if Game.world:
		Game.world.env.set_space(true)
	Interiors.inst._teleport(arrival(), ret_yaw)
	if pl.combat:
		pl.combat.action = ""
	pl.model.visible = true
	_spawn_held()
	if how == "self":
		_open_rift(global_position + Vector3(0, 1.2, -3.0))
		rift_t = -1.0
	else:
		rift_t = RIFT_DELAY
	await Interiors.inst._fade(0.0, 0.35)
	MsArts.kamui_vortex(pl.global_position + Vector3.UP * 1.0, 1.3, 0.8)
	if how == "self":
		Hud.banner("KAMUI KŪKAN", "Boyuttasın. Çıkmak için Kamui'yi yeniden kullan ya da girdaba gir [F] — bıraktığın yere dönersin.", Color(0.7, 0.8, 0.95))
	else:
		var own = has_access(Game.profile)
		Hud.banner("KAMUI KŪKAN", "Kamui boyutuna çekildin! Kendi Kamui'n varsa hemen çıkabilirsin." if own else "Kamui boyutuna çekildin! Boyut yırtılınca (%d sn) çıkış girdabını bul [F]." % int(RIFT_DELAY), Color(0.75, 0.6, 0.95))
	busy = false


func leave_player() -> void:
	var pl = Game.player
	if pl == null or busy or not player_in:
		return
	busy = true
	MsArts.kamui_vortex(pl.global_position + Vector3.UP * 1.0, 1.3, 0.8)
	Sfx.play("th_teleport", pl.global_position, 0.9, 0.7)
	_shrink(pl, 0.4)
	await get_tree().create_timer(0.4).timeout
	await Interiors.inst._fade(1.0, 0.2)
	_close_inside()
	var p = Interiors.inst._exit_floor(ret_pos)   # bıraktığın yer (doluysa en yakın boş zemin)
	p.y += 0.05
	Interiors.inst._teleport(p, ret_yaw)
	if how == "pulled":
		pl.set_meta("kamui_pull_immune", Game.now() + PULL_IMMUNE)
	if pl.combat:
		pl.combat.invuln = maxf(pl.combat.invuln, 0.8)   # çıkışta üstüne kurulu tuzaktan kısa koruma (giriş anıyla aynı)
	await Interiors.inst._fade(0.0, 0.3)
	MsArts.kamui_vortex(p + Vector3.UP * 1.0, 1.3, 0.8)
	busy = false


## İçerinin kapanışı (çıkış, ölüm, ışınlanma): ortam geri, tutsaklar kayda döner
func _close_inside() -> void:
	player_in = false
	Game.remove_meta("kamui_space")
	if Game.world:
		Game.world.env.set_space(false)
	_close_rift()
	rift_t = -1.0
	for e in live:
		if is_instance_valid(e):
			e.queue_free()   # kaydı duruyor: bir dahaki girişte yine orada
	live.clear()
	visible = not away.is_empty()


func _open_rift(at: Vector3) -> void:
	_close_rift()
	rift = MsArts.kamui_vortex(at, 1.5, 1e6)
	exit_item = {"pos": at, "radius": 3.5, "kind": "kamui_exit", "label": "Kamui: boyuttan çık"}
	Interact.add(exit_item)


func _close_rift() -> void:
	if rift and is_instance_valid(rift):
		rift.queue_free()
	rift = null
	if not exit_item.is_empty():
		Interact.items.erase(exit_item)
	exit_item = {}


static func _shrink(n: Node3D, dur: float) -> void:
	var m = n.get("model")
	if m == null:
		return
	var s0: Vector3 = m.scale
	var tw = m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", s0 * 0.05, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "rotation:y", m.rotation.y + TAU * 2.0, dur)
	tw.chain().tween_callback(func():
		if is_instance_valid(m):
			m.scale = s0)


# ------------------------------------------------------------------ tutsaklar (çekilen NPC'ler)
## Kamui'nin yuttuğu kişi boyutta kalır: kayıt (arketip) saklanır; oyuncu içerideyse hemen orada belirir
static func capture(c: Node3D, h: Node3D) -> void:
	if not (h is Enemy):
		return
	if h.has_meta("kamui_prisoner"):
		h.remove_meta("kamui_prisoner")   # boyuttaki tutsak yeniden yutuldu: zaten içeride, kaydı silinmesin
		return
	var a: Dictionary = (h as Enemy).arch.duplicate(true)
	a["respawn"] = false
	a["xp"] = 0
	a["ryo"] = 0
	a["no_world"] = true
	var L: Array = held()
	var rec = {"a": var_to_str(a), "by": "player" if c == Game.player else "npc", "name": String(h.get("display_name"))}
	L.append(rec)
	while L.size() > MAX_HELD:
		L.pop_front()
	if player_inside():
		inst._spawn_one(rec, L.size() - 1)


func _spawn_held() -> void:
	var L: Array = held()
	for i in L.size():
		_spawn_one(L[i], i)


func _spawn_one(rec: Dictionary, i: int) -> void:
	var a = str_to_var(String(rec.get("a", "")))
	if not a is Dictionary or (a as Dictionary).is_empty():
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = 900 + i * 31
	var cell = _cell_at(70.0, 150.0, -10.0, 20.0, rng)   # tutsak kuşağı: varıştan uzak (girer girmez üstüne çullanmasınlar)
	var e := Enemy.new()
	e.setup(a)
	get_tree().current_scene.add_child(e)
	var at = _top(cell) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	e.global_position = at
	e.home = at
	e.set_meta("respawn", false)
	_uid += 1
	rec["uid"] = _uid
	e.set_meta("kamui_prisoner", _uid)
	live.append(e)


func _drop_record(uid: int) -> void:
	var L: Array = held()
	for i in range(L.size() - 1, -1, -1):
		if int(L[i].get("uid", -1)) == uid:
			L.remove_at(i)


# ------------------------------------------------------------------ yapay zekâ: boyuta kaçış
## Obito tarzı Mangekyō sahibi düşman boyuta çekilir; RETREAT_TIME sonra rakibinin yanında (yoksa ayrıldığı yerde) belirir
static func retreat(e: Node3D) -> bool:
	if not is_instance_valid(e) or e.is_dead() or e.has_meta("kamui_away"):
		return false
	var ks = node()
	if not ks.player_in:
		ks._place_over(e.global_position)
	var from = e.global_position
	MsArts.kamui_vortex(from + Vector3.UP * 1.0, 1.2, 0.9)
	Combat.popup_text(from + Vector3.UP * 2.6, "Kamui!", Color(0.75, 0.6, 0.9))
	Sfx.play("th_teleport", from, 0.85, 0.7)
	_shrink(e, 0.4)
	e.set_meta("kamui_away", true)
	ks.visible = true
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var cell = ks._cell_at(40.0, 120.0, -10.0, 20.0, rng)
	ks.get_tree().create_timer(0.42).timeout.connect(func():
		if not is_instance_valid(e):
			return
		e.global_position = ks._top(cell)
		e.velocity = Vector3.ZERO
		if e.has_method("reset_physics_interpolation"):
			e.reset_physics_interpolation()
		if ks.player_in:
			MsArts.kamui_vortex(e.global_position + Vector3.UP, 1.2, 0.8))
	ks.away.append({"e": e, "until": Game.now() + RETREAT_TIME, "from": from})
	return true


func _return_away(a: Dictionary) -> void:
	var e = a["e"]
	e.remove_meta("kamui_away")
	var t = e.get("target")
	var to: Vector3 = a["from"]
	if t != null and is_instance_valid(t) and not t.is_dead() and not (t == Game.player and player_in):
		var off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 3.5
		to = t.global_position + off   # kanon: rakibin yanında / arkasında belirir
	elif player_in and t == Game.player:
		return   # oyuncu da boyutta: burada dövüşmeye devam
	to = Game.jutsu_floor_at(to + Vector3.UP * 2.0) + Vector3.UP * 0.1
	if (to - (a["from"] as Vector3)).length() > 80.0:
		to = a["from"]
	e.global_position = to
	e.velocity = Vector3.ZERO
	if e.has_method("reset_physics_interpolation"):
		e.reset_physics_interpolation()
	MsArts.kamui_vortex(to + Vector3.UP * 1.0, 1.2, 0.8)
	Sfx.play("th_teleport", to, 0.9, 0.6)


# ------------------------------------------------------------------ kare
func _process(dt: float) -> void:
	var now = Game.now()
	for i in range(away.size() - 1, -1, -1):
		var a = away[i]
		var e = a["e"]
		if not is_instance_valid(e) or e.is_dead():
			away.remove_at(i)
			continue
		if now >= float(a["until"]):
			away.remove_at(i)
			_return_away(a)
	if not player_in:
		if visible and away.is_empty():
			visible = false
		return
	var pl = Game.player
	if pl == null or not is_instance_valid(pl):
		_close_inside()
		return
	var lp = pl.global_position - global_position
	if not busy and (Vector2(lp.x, lp.z).length() > 600.0 or absf(lp.y) > 300.0):
		_close_inside()   # öldü / başka yere ışınlandı: boyut kapanır
		return
	# tutsak öldüyse kaydı da gider
	for i in range(live.size() - 1, -1, -1):
		var e = live[i]
		if not is_instance_valid(e) or e.is_dead():
			if is_instance_valid(e):
				_drop_record(int(e.get_meta("kamui_prisoner", -1)))
			live.remove_at(i)
	if rift_t > 0.0:
		rift_t -= dt
		if rift_t <= 0.0:
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var cell = _cell_at(26.0, 48.0, 0.0, 7.5, rng)
			_open_rift(_top(cell) + Vector3.UP * 1.2)
			Hud.msg("Boyut yırtıldı: çıkış girdabı açıldı — bul ve [F].", Color(0.75, 0.6, 0.95), 5.0)
	if busy:
		return
	# sonsuz boyut: kenarı geçen karşı kenardan girer; dibin altına düşen varışa döner
	if absf(lp.x) > WRAP or absf(lp.z) > WRAP:
		var np = lp
		if absf(lp.x) > WRAP:
			np.x -= signf(lp.x) * WRAP * 2.0
		if absf(lp.z) > WRAP:
			np.z -= signf(lp.z) * WRAP * 2.0
		var w = Game.jutsu_floor_at(global_position + Vector3(np.x, 80.0, np.z))
		pl.global_position = Vector3(w.x, maxf(w.y, global_position.y + FLOOR) + 0.1, w.z)
		pl.reset_physics_interpolation()
	elif lp.y < FLOOR - 12.0:
		Interiors.inst._teleport(arrival(), float(pl.yaw))
