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
var cells: Array = []        # [{"c": Vector2 yerel merkez, "top": float, "ring": int, "r": Rect2 yerel taban}] oyun alanındaki kütle tepeleri
var stacks: Array = []       # üstteki küçük kütleler [{"r", "top"}] (mini harita)
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
					cells.append({"c": Vector2.ZERO, "top": 0.0, "ring": 0, "r": Rect2(-29, -29, 58, 58)})
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
				cells.append({"c": r.get_center(), "top": top, "ring": ring, "r": r})
			if rng.randf() < 0.32:
				# üstüne oturan küçük kütle (anime: basamaklı yığınlar); merkezi kapatmaz (doğuş noktası tepe merkezinde)
				var sx = r.size.x * rng.randf_range(0.28, 0.44)
				var sz = r.size.y * rng.randf_range(0.28, 0.44)
				var qx = 1.0 if rng.randf() < 0.5 else -1.0
				var qz = 1.0 if rng.randf() < 0.5 else -1.0
				var cx = r.get_center().x + qx * (r.size.x * 0.5 - sx * 0.5 - 0.4)
				var cz = r.get_center().y + qz * (r.size.y * 0.5 - sz * 0.5 - 0.4)
				var t2 = top + snappedf(rng.randf_range(2.5, 10.0), 1.5)
				_block(st, body, Rect2(cx - sx * 0.5, cz - sz * 0.5, sx, sz), t2, top - 0.01, col, rng)
				if col:
					stacks.append({"r": Rect2(cx - sx * 0.5, cz - sz * 0.5, sx, sz), "top": t2})   # yalnız harita çizimi
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
	MsArts.kamui_vortex(eye_point(pl), 1.9, 1.0)
	Sfx.play("kamui_in", ret_pos, 1.0)
	pass
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
	MsArts.kamui_vortex(eye_point(pl), 1.9, 0.7, {"pull": -0.5})
	_shrink(pl, 0.35, true)   # boyutta burgaçtan açılarak belirir
	_spawn_held()
	if how == "self":
		_open_rift(global_position + Vector3(0, 1.2, -3.0))
		rift_t = -1.0
	else:
		rift_t = RIFT_DELAY
	await Interiors.inst._fade(0.0, 0.35)
	MsArts.kamui_vortex(eye_point(pl), 1.9, 0.8, {"pull": -0.5})
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
	MsArts.kamui_vortex(eye_point(pl), 1.9, 0.8)
	Sfx.play("kamui_in", pl.global_position, 1.0)
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
	MsArts.kamui_vortex(eye_point(pl), 1.9, 0.8, {"pull": -0.5})
	_shrink(pl, 0.4, true)   # burgaçtan açılarak çıkar
	await Interiors.inst._fade(0.0, 0.3)
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


## Kanon (Obito'nun kendi Kamui'si): beden dönmez — sağ gözü merkez alan uzay burgacına çekilir (twist_into); grow=true tersi (çıkış).
static func _shrink(n: Node3D, dur: float, grow := false) -> void:
	twist_into(n, eye_point(n), dur, grow)


## Kamui yutuşu (anime ref: refs/kamui_anime): beden KENDİ ETRAFINDA DÖNMEZ; burgaç merkezine (göz / dokunulan / odaklanan
## nokta) doğru akarak küçülür — enine önce incelir, boyuna sonra çekilir. Sarmal burkulmayı burgacın ekran bükülmesi verir
## (MsArts.kamui_vortex arkasındaki bedeni de sarmala büker). amount < 1: kısmi çekiş, sonra geri yaylanır (direnen hedef).
## grow=true: burgaçtan dışa açılarak belirir. Bitişte gizlenir (hide) ya da eski hâline döner.
static func twist_into(n: Node3D, center: Vector3, dur: float, grow := false, amount := 1.0, hide := true) -> void:
	if n == null or not is_instance_valid(n):
		return
	var m = n.get("model")
	if m == null or not is_instance_valid(m) or not (m is Node3D):
		return
	var par = m.get_parent() as Node3D
	if par == null:
		return
	if m.has_meta("kamui_tw"):
		var old = m.get_meta("kamui_tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		m.scale = m.get_meta("kamui_s0")
		m.position = m.get_meta("kamui_p0")
	var s0: Vector3 = m.scale
	var p0: Vector3 = m.position
	m.set_meta("kamui_s0", s0)
	m.set_meta("kamui_p0", p0)
	var cl: Vector3 = par.to_local(center)
	var f = func(k: float) -> void:   # k: 0 tam beden -> 1 burgaçta yok
		if not is_instance_valid(m):
			return
		var kw = clampf(k * 1.3, 0.0, 1.0)   # enine daha erken incelir: burgaca akan beden
		var sx = lerpf(1.0, 0.015, kw)
		var sy = lerpf(1.0, 0.015, k)
		m.scale = Vector3(s0.x * sx, s0.y * sy, s0.z * sx)
		m.position = cl + Vector3((p0.x - cl.x) * sx, (p0.y - cl.y) * sy, (p0.z - cl.z) * sx)
	var tw = m.create_tween()
	m.set_meta("kamui_tw", tw)
	if grow:
		m.visible = true
		f.call(1.0)
		tw.tween_method(f, 1.0, 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif amount < 0.999:
		tw.tween_method(f, 0.0, amount, dur * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_method(f, amount, 0.0, dur * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_method(f, 0.0, 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(m):
			if not grow and amount >= 0.999 and hide:
				m.visible = false
			m.scale = s0
			m.position = p0
			m.remove_meta("kamui_tw"))


## Hedef Kamui burgacına yutulur (oyuncunun / NPC'nin dokunuşla çekişi, Kakashi'nin uzak odağı, Kamui Raikiri): burgaç merkezde
## açılır, beden ona akar ve gözden kaybolur; ancak ondan SONRA on_gone çağrılır (ölüm karesi / ceset görünmez).
## Boyuttaki tutsak yeniden çekilirse dünyada çekildiği yere geri salınır (release).
static func swallow(c: Node3D, h: Node3D, center: Vector3, dur: float, on_gone: Callable) -> void:
	if h == null or not is_instance_valid(h):
		return
	var hh = float(h.get("height")) if h.get("height") != null else 1.8
	MsArts.kamui_vortex(center, hh * 1.7, dur + 0.45, {"pull": 0.6, "twist": 1.2})   # anime: hedefin çevresindeki geniş uzay burkulur
	if h is Enemy and h.has_meta("kamui_prisoner"):
		twist_into(h, center, dur)
		h.get_tree().create_timer(dur + 0.02).timeout.connect(func():
			if is_instance_valid(h) and not h.is_dead():
				release(h))
		return
	h.set_meta("kamui_from", {"pos": h.global_position, "yaw": float(h.get("facing")) if h.get("facing") != null else 0.0})
	twist_into(h, center, dur)
	h.get_tree().create_timer(dur + 0.02).timeout.connect(func():
		if is_instance_valid(h) and not h.is_dead():
			if h.get("model"):
				h.model.visible = false
			on_gone.call())


## Dokunarak / yakından yutma noktası: hedefin göğsünde, çekene bakan yüzeyde (anime: elin değdiği yer)
static func touch_point(c: Node3D, h: Node3D) -> Vector3:
	var hh = float(h.get("height")) if h.get("height") != null else 1.8
	var d = c.global_position - h.global_position
	d.y = 0.0
	var rad = float(h.get("radius")) if h.get("radius") != null else 0.4
	return h.global_position + Vector3.UP * hh * 0.62 + (d.normalized() * rad * 0.8 if d.length() > 0.01 else Vector3.ZERO)


## Sağ göz noktası (dünya): burgaç oradan açılır
static func eye_point(n: Node3D) -> Vector3:
	var h = float(n.get("height")) if n.get("height") != null else 1.8
	var fwd = n.face_dir() if n.has_method("face_dir") else Vector3.FORWARD
	var right = fwd.cross(Vector3.UP).normalized()
	return n.global_position + Vector3.UP * h * 0.92 + fwd * 0.12 + right * 0.04


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
	var fr: Dictionary = h.get_meta("kamui_from", {"pos": h.global_position, "yaw": float(h.get("facing")) if h.get("facing") != null else 0.0})
	var rec = {"a": var_to_str(a), "by": "player" if c == Game.player else "npc", "name": String(h.get("display_name")),
		"pos": var_to_str(fr["pos"]), "yaw": float(fr["yaw"]), "by_id": str(c.get_instance_id()) if c else ""}   # salınınca tam bu yere döner; by_id: yutan (yapay zekâ kendi tutsağını çıkarır)
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


## Boyuttaki tutsak yeniden Kamui'ye alındı: dünyada çekildiği yere (dolu ise en yakın boş zemine) canlı döner, burgaçtan açılarak
## belirir; kaydı boyuttan silinir (kanon: Obito yuttuğunu çıkardığı yere bırakır)
static func release(e: Node3D) -> void:
	var ks = node()
	var uid = int(e.get_meta("kamui_prisoner", -1))
	var rec := {}
	for r in held():
		if int(r.get("uid", -2)) == uid:
			rec = r
	ks._drop_record(uid)
	ks.live.erase(e)
	if rec.is_empty():
		rec = {"a": var_to_str((e as Enemy).arch.duplicate(true)), "name": String(e.get("display_name"))}
	var to = str_to_var(String(rec.get("pos", ""))) if rec.has("pos") else null
	if not to is Vector3:
		to = ks.ret_pos + Vector3(3.0, 0.0, 3.0)   # eski kayıt (yer saklanmamış): girişin yanına
	_retire(e)
	var p: Vector3 = Interiors.inst._exit_floor(to) if Interiors.inst else to
	var w = _emerge(rec, p, float(rec.get("yaw", 0.0)))
	if w and Game.player:
		Combat.popup_text(Game.player.global_position + Vector3.UP * 2.4, Lang.t("%s boyuttan salındı") % String(w.display_name), Color(0.75, 0.6, 0.95))


## Boyuttan çıkan tutsağın içerideki düğümü: hemen gizlenir / dövüş dışı kalır, birkaç sn sonra silinir (havadaki aletlerinin
## karesi onu hâlâ tutuyor olabilir: anında silmek "Lambda capture freed" hatası veriyordu)
static func _retire(e: Node3D) -> void:
	e.visible = false
	e.set_physics_process(false)
	e.set("collision_layer", 0)
	e.remove_from_group("fighters")
	e.set("dead", true)
	e.get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(e):
			e.queue_free())


## Kayıttaki kişiyi dünyada p noktasında canlı çıkarır: gözündeki burgaçtan açılarak belirir (çıkış sesi)
static func _emerge(rec: Dictionary, p: Vector3, yaw: float) -> Enemy:
	var a = str_to_var(String(rec.get("a", "")))
	if not a is Dictionary or (a as Dictionary).is_empty():
		return null
	a["respawn"] = false
	var ks = node()
	var w := Enemy.new()
	w.setup(a)
	ks.get_tree().current_scene.add_child(w)
	w.global_position = p + Vector3.UP * 0.05
	w.home = p
	w.facing = yaw
	w.set_meta("respawn", false)
	if w.has_method("reset_physics_interpolation"):
		w.reset_physics_interpolation()
	WorldPeople.on_kamui_released(String(a.get("world_person", "")))
	MsArts.kamui_vortex(eye_point(w), 1.8, 1.0, {"pull": -0.5})
	twist_into(w, eye_point(w), 0.5, true)
	Sfx.play("kamui_out", p, 0.9)
	return w


# ------------------------------------------------------------------ Kamui: Hōshutsu (boyuttan dışarı çıkarma)
## Kanon: Kamui boyutuna aldığını sahibi istediği yere geri çıkarır (Obito boyuttakileri dışarı taşır; yuttuğu saldırı da
## boyutta kalır, kendi burgacından geri çıkar). Yutulan mermiler (Kamui: içine çek ile) oturumda burada bekler.
const STORE_MAX := 3
static var stored_shots: Array = []   # oyuncunun yuttuğu Projectile düğümleri (sahneden ayrılmış)


## Yutulan mermilerin deposu: oyuncunun ortak deposu, yapay zekânın kendi deposu (meta)
static func _shots_of(c: Node) -> Array:
	if c is Player:
		return stored_shots
	if not c.has_meta("kamui_shots"):
		c.set_meta("kamui_shots", [])
	return c.get_meta("kamui_shots")


## Yakındaki düşman mermisini (jutsu / alet) boyuta yutar: true = yuttu
static func absorb_projectile(c: Node3D, r := 8.0) -> bool:
	var best: Node3D = null
	var bd = r
	for pr in c.get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(pr) or pr.get("dead") or pr.get("shooter") == c:
			continue
		var sh = pr.get("shooter")
		if sh != null and is_instance_valid(sh) and not Combat.hostile(c, sh):
			continue
		var d = pr.global_position.distance_to(c.global_position + Vector3.UP)
		if d < bd:
			bd = d
			best = pr
	if best == null:
		return false
	best.set_physics_process(false)
	best.set("vel", (best.get("vel") as Vector3) * 0.0 if best.get("vel") is Vector3 else Vector3.ZERO)
	var at = best.global_position
	MsArts.kamui_vortex(at, 1.0, 0.7, {"pull": 0.6})
	Sfx.play("kamui_in", at, 1.1)
	var s0: Vector3 = best.scale
	var tw = best.create_tween()
	tw.tween_property(best, "scale", s0 * 0.02, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not is_instance_valid(best):
			return
		best.scale = s0
		if best.get_parent():
			best.get_parent().remove_child(best)
		if not is_instance_valid(c):
			best.queue_free()
			return
		var st: Array = _shots_of(c)
		st.append(best)
		while st.size() > STORE_MAX:
			var old = st.pop_front()
			if is_instance_valid(old):
				old.queue_free())
	Combat.popup_text(at + Vector3.UP * 0.6, "Kamui'ye yutuldu", Color(0.75, 0.6, 0.95))
	return true


## Hōshutsu: önce yutulmuş saldırı (sırayla) hedefe doğru burgaçtan geri fırlar; yoksa boyuttaki en eski tutsak nişan
## noktasında burgaçtan çıkar ve ona en yakın dövüşçüye saldırır (kanon: boyuttan çıkan kendi iradesiyle davranır).
## true = bir şey çıkarıldı
static func release_out(c: Node3D, t: Node3D) -> bool:
	var fwd: Vector3 = c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD
	if c is Player and c.has_method("cam_forward"):
		fwd = c.cam_forward()
		fwd.y = 0.0
		fwd = fwd.normalized()
	var shots: Array = _shots_of(c)
	while not shots.is_empty():
		var pr = shots.pop_front()
		if not is_instance_valid(pr):
			continue
		var at = c.global_position + Vector3.UP * 1.4 + fwd * 1.6
		var aim = (t.global_position + Vector3.UP * float(t.get("height") if t.get("height") != null else 1.8) * 0.55 - at).normalized() if t and is_instance_valid(t) else fwd
		c.get_tree().current_scene.add_child(pr)
		pr.global_position = at
		var spd = maxf(18.0, (pr.get("vel") as Vector3).length() if pr.get("vel") is Vector3 else 0.0)
		pr.set("vel", aim * maxf(spd, 22.0))
		pr.set("shooter", c)
		var inf: Dictionary = (pr.get("info") as Dictionary).duplicate() if pr.get("info") is Dictionary else {}
		inf["attacker"] = c
		pr.set("info", inf)
		pr.set("hit_list", [])
		pr.set("homing", t if t and is_instance_valid(t) else null)
		pr.set("life", 3.0)
		if pr.has_method("look_at"):
			pr.look_at(at + aim, Vector3.UP if absf(aim.y) < 0.95 else Vector3.RIGHT)
		pr.set_physics_process(true)
		MsArts.kamui_vortex(at, 1.0, 0.6, {"pull": -0.6})
		Sfx.play("kamui_out", at, 1.0)
		Combat.popup_text(at + Vector3.UP * 0.6, "Kamui: Hōshutsu", Color(0.75, 0.6, 0.95))
		return true
	var L: Array = held()
	var ks = node()
	if ks.player_in:
		return false
	var ri = -1
	for i in L.size():
		if c is Player or String(L[i].get("by_id", "")) == str(c.get_instance_id()):   # yapay zekâ yalnız kendi yuttuğunu çıkarır
			ri = i
			break
	if ri < 0:
		return false
	var rec: Dictionary = L[ri]
	var to: Vector3
	if t and is_instance_valid(t):
		var side = fwd.cross(Vector3.UP).normalized()
		to = t.global_position + side * 2.5
	else:
		to = c.global_position + fwd * 8.0
	to = Game.jutsu_floor_at(to + Vector3.UP * 2.0)
	L.remove_at(ri)
	var d = (t.global_position - to) if t and is_instance_valid(t) else -fwd
	var w = _emerge(rec, to, atan2(-d.x, -d.z))
	if w == null:
		return false
	# boyuttan sersem çıkan: yanındaki ilk dövüşçüye (çağıranın hedefi varsa ona) saldırır
	var near: Node3D = t if t and is_instance_valid(t) and not t.is_dead() and t != w else null
	if near == null:
		var bd = 15.0
		for f in w.get_tree().get_nodes_in_group("fighters"):
			if f != w and f != c and not f.is_dead() and f.global_position.distance_to(to) < bd:
				bd = f.global_position.distance_to(to)
				near = f
	w.target = near if near else c
	if near:
		w.state = "chase"
	Combat.popup_text(to + Vector3.UP * 2.4, Lang.t("%s boyuttan salındı") % String(w.display_name), Color(0.75, 0.6, 0.95))
	return true


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
	MsArts.kamui_vortex(eye_point(e), 1.8, 0.9)
	Combat.popup_text(from + Vector3.UP * 2.6, "Kamui!", Color(0.75, 0.6, 0.9))
	Sfx.play("kamui_in", from, 0.9)
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
		_shrink(e, 0.35, true)   # oyuncu da boyutta: burada belirir, dövüş sürer
		return
	to = Game.jutsu_floor_at(to + Vector3.UP * 2.0) + Vector3.UP * 0.1
	if (to - (a["from"] as Vector3)).length() > 80.0:
		to = a["from"]
	e.global_position = to
	e.velocity = Vector3.ZERO
	if e.has_method("reset_physics_interpolation"):
		e.reset_physics_interpolation()
	MsArts.kamui_vortex(eye_point(e), 1.8, 0.8, {"pull": -0.5})
	_shrink(e, 0.4, true)   # burgaçtan açılarak çıkar (oyuncuyla aynı)
	Sfx.play("kamui_out", to, 0.9)


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
			continue
		# kök neden (Enemy._patrol): gezinti noktası kütle dışına düşüyordu, artık aynı zeminde kalır; bu yalnız güvenlik (yarığa düşen evine)
		if e.global_position.y < float(e.home.y) - 6.0:
			e.global_position = e.home
			e.velocity = Vector3.ZERO
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
