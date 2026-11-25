extends RefCounted
## (class_name yok: kullanan dosyalar const FacadeKit = preload(...) ile yükler — sınıf önbelleği yenilemeden çalışsın)
## Özel binaların ARKA ve YAN cepheleri (2026-11-25, kullanıcı: "binalar önden çok güzel ama arka tarafları çok boş"):
## bir duvar yüzünü binanın kendi diliyle giydirir — kat kat pencere sırası (çerçeve, cam / shōji / kafes / yarık, denizlik,
## bazılarında açık kepenk, çiçek kutusu, perde), kat kuşakları, köşe yağmur boruları + oluk, arka kapı (saçak, payandalar,
## basamaklar, lamba), çatı altı kafes havalandırmaları ve dipte gündelik eşya (sandık, fıçı, odun yığını, kova, süpürge,
## çamaşır ipi). Hepsi Builder kutularıyla birleşik ağa girer (ayrı düğüm yok); yalnız çarpılabilecek eşya / basamak katıdır.
##
## Koordinat: x, n = duvar yüzünün ORTA noktası (Builder yereli), face = yüzün dışa bakan normali (derece; normal (sin, cos)),
## u = duvar boyunca (sağ el: face 0'da doğu), d = duvardan dışarı. y0 = duvarın taban yüksekliği (b.yoff'a göre).

const GLASS := Color(0.55, 0.7, 0.82)
const SHOJI := Color(0.95, 0.93, 0.85)


## karşılaştırma görüntüsü için geçici kapatma (NO_BACKS=1: eski çıplak cepheler)
static func on() -> bool:
	return OS.get_environment("NO_BACKS") == ""


static func _p(x: float, n: float, face: float, u: float, d: float) -> Vector2:
	var f = deg_to_rad(face)
	return Vector2(x + cos(f) * u + sin(f) * d, n - sin(f) * u + cos(f) * d)


## Duvar yüzünde (u, y, d) noktasına kutu: boyut x duvar boyunca, z duvardan dışarı
static func _bx(b: Builder, x: float, n: float, face: float, u: float, y: float, d: float, size: Vector3, col: Color, collide := false, tilt := 0.0) -> void:
	var q = _p(x, n, face, u, d)
	b.box(Vector3(q.x, y, q.y), size, col, face, collide, Vector3(-tilt, 0, 0) if tilt != 0.0 else Vector3.ZERO)


## Yerel zemin yüksekliği (b.yoff'a göre)
static func ground(b: Builder, x: float, n: float) -> float:
	return Game.terrain_height(b.origin.x + x, b.origin.z - n) - b.origin.y - b.yoff


static func _skip(u: float, half: float, skips: Array) -> bool:
	for s in skips:
		if u + half > float(s[0]) and u - half < float(s[1]):
			return true
	return false


## Bir duvar yüzünü giydirir. w: yüz genişliği, h: duvar yüksekliği (y0'dan). o (hepsi isteğe bağlı):
##  floors, fh (kat yüksekliği), win (Vector2 pencere), pitch (pencere aralığı), kind ("glass" "shoji" "lattice" "slit" "round"),
##  frame, glass, shutter (Color: kepenk; yoksa kepenk yok), sill (bool), band (Color: kat kuşağı), band_d (kuşak çıkıntısı),
##  door (float u: arka kapı), door_w, door_h, door_col, awning (Color: kapı saçağı), lamp (bool), steps (bool),
##  pipes (Color: köşe yağmur boruları + çatı oluğu), vents (Color: çatı altı kafes menfezleri), skip ([[u0, u1], ...] pencere yok),
##  windows (bool), win_y (ilk sıra pencere merkezi), base (Color: taban şeridi),
##  props ("" | "service" | "home" | "kitchen" | "shrine" | "clinic"), seed, ground_win (bool: zemin katta pencere), margin
static func dress(b: Builder, x: float, n: float, face: float, w: float, y0: float, h: float, o := {}) -> void:
	if not on():
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", int(absf(x) * 7.0 + absf(n) * 13.0 + face)))
	var floors: int = int(o.get("floors", maxi(1, int(h / 4.0))))
	var fh: float = float(o.get("fh", h / floors))
	var win: Vector2 = o.get("win", Vector2(1.6, 1.7))
	var pitch: float = float(o.get("pitch", 4.0))
	var kind: String = o.get("kind", "glass")
	var frame: Color = o.get("frame", Color(0.32, 0.22, 0.15))
	var glass: Color = o.get("glass", SHOJI if kind == "shoji" else GLASS)
	var margin: float = float(o.get("margin", 1.6))
	var skips: Array = o.get("skip", [])
	var door_u = o.get("door", null)
	var door_w: float = float(o.get("door_w", 1.8))
	var door_h: float = float(o.get("door_h", 2.5))
	var win_skips = skips   # kapının üstündeki kat pencereleri kalır; kapı önü eşya / boru almaz
	if door_u != null:
		skips = skips + [[float(door_u) - door_w * 0.5 - 0.9, float(door_u) + door_w * 0.5 + 0.9]]
	# --- pencere sıraları
	var usable = w - margin * 2.0
	var cnt = maxi(1, int(usable / pitch) + 1) if usable > win.x else 0
	var step = usable / maxf(1.0, float(cnt - 1)) if cnt > 1 else 0.0
	if not o.get("windows", true):
		cnt = 0
	for f in floors:
		if f == 0 and not o.get("ground_win", true):
			continue
		var wy = y0 + f * fh + fh * (0.52 if f > 0 else 0.48)
		if o.has("win_y"):
			wy = float(o["win_y"]) + f * fh
		for k in cnt:
			var u = -usable * 0.5 + k * step if cnt > 1 else 0.0
			if _skip(u, win.x * 0.5, win_skips):
				continue
			if f == 0 and door_u != null and absf(u - float(door_u)) < door_w + 1.0:
				continue
			_window(b, x, n, face, u, wy, win, kind, frame, glass, o, rng, f)
	# --- kat kuşakları (ön cephedeki kat kirişleri / bantları arkada da sürer)
	if o.has("band"):
		var bc: Color = o["band"]
		var bd: float = float(o.get("band_d", 0.12))
		for f in range(1, floors):
			_bx(b, x, n, face, 0.0, y0 + f * fh, bd * 0.5 + 0.02, Vector3(w + 0.1, 0.32, bd), bc)
		_bx(b, x, n, face, 0.0, y0 + 0.35, 0.05, Vector3(w + 0.06, 0.7, 0.1), o.get("base", bc.darkened(0.15)))   # su basman / taban şeridi
	# --- köşe yağmur boruları + çatı oluğu (dipte yağmur fıçısı)
	if o.has("pipes"):
		var pc: Color = o["pipes"]
		_bx(b, x, n, face, 0.0, y0 + h - 0.15, 0.22, Vector3(w + 0.2, 0.18, 0.3), pc)
		for sx in [-1.0, 1.0]:
			if rng.randf() < 0.25 and w < 12.0:
				continue
			var pu = sx * (w * 0.5 - 0.45)
			if _skip(pu, 0.3, skips):
				continue
			_bx(b, x, n, face, pu, y0 + h * 0.5, 0.2, Vector3(0.18, h, 0.18), pc)
			for k in int(h / 3.0):   # boru kelepçeleri
				_bx(b, x, n, face, pu, y0 + 1.5 + k * 3.0, 0.2, Vector3(0.26, 0.08, 0.26), pc.darkened(0.25))
			if sx > 0.0 and o.get("props", "") != "":   # yağmur fıçısı
				var q = _p(x, n, face, pu, 0.75)
				var g = ground(b, q.x, q.y)
				b.cyl(Vector3(q.x, g + 0.45, q.y), 0.9, 0.9, Color(0.42, 0.3, 0.2), true, 10)
				b.cyl(Vector3(q.x, g + 0.62, q.y), 0.95, 0.07, Color(0.25, 0.25, 0.27), false, 10)
				b.cyl(Vector3(q.x, g + 0.25, q.y), 0.95, 0.07, Color(0.25, 0.25, 0.27), false, 10)
	# --- çatı altı kafes menfezleri
	if o.has("vents"):
		var vc: Color = o["vents"]
		var nv = maxi(1, int(w / 9.0))
		for k in nv:
			var vu = -w * 0.5 + (k + 0.5) * w / nv
			var vy = y0 + h - 0.8
			_bx(b, x, n, face, vu, vy, 0.06, Vector3(1.6, 0.7, 0.1), vc.darkened(0.3))
			for j in 5:
				_bx(b, x, n, face, vu - 0.64 + j * 0.32, vy, 0.12, Vector3(0.07, 0.7, 0.06), vc)
	# --- arka kapı
	if door_u != null:
		back_door(b, x, n, face, float(door_u), y0, o)
	# --- dipte gündelik eşya
	var pk: String = o.get("props", "")
	if pk != "":
		props(b, x, n, face, w, y0, pk, rng, skips)


static func _window(b: Builder, x: float, n: float, face: float, u: float, wy: float, win: Vector2, kind: String, frame: Color, glass: Color, o: Dictionary, rng: RandomNumberGenerator, fl: int) -> void:
	match kind:
		"slit":   # dar yarık (sur / karargâh): koyu oyuk + taş lento
			_bx(b, x, n, face, u, wy, 0.04, Vector3(win.x * 0.45, win.y, 0.1), Color(0.07, 0.07, 0.08))
			_bx(b, x, n, face, u, wy + win.y * 0.5 + 0.12, 0.1, Vector3(win.x * 0.75, 0.24, 0.2), frame)
			return
		"round":   # yuvarlak lomboz
			var q = _p(x, n, face, u, 0.06)
			b.disc(Vector3(q.x, wy, q.y), win.x + 0.3, 0.14, frame, face, 14)
			var q2 = _p(x, n, face, u, 0.12)
			b.disc(Vector3(q2.x, wy, q2.y), win.x, 0.1, glass, face, 14)
			return
	_bx(b, x, n, face, u, wy, 0.06, Vector3(win.x + 0.3, win.y + 0.3, 0.12), frame)
	var curtain = kind == "glass" and rng.randf() < 0.3
	_bx(b, x, n, face, u, wy, 0.11, Vector3(win.x, win.y, 0.06), glass)
	if curtain:   # yarı çekili perde (pencereler birbirinin kopyası görünmesin)
		var cc = [Color(0.95, 0.92, 0.8), Color(0.85, 0.75, 0.6), Color(0.78, 0.86, 0.9)][rng.randi() % 3]
		_bx(b, x, n, face, u - win.x * 0.25 * (1.0 if rng.randf() < 0.5 else -1.0), wy + win.y * 0.1, 0.13, Vector3(win.x * 0.45, win.y * 0.8, 0.03), cc)
	match kind:
		"shoji", "lattice":   # kâğıt panoyu ızgara çıtaları böler
			var nv = maxi(2, int(win.x / 0.45))
			for j in range(1, nv):
				_bx(b, x, n, face, u - win.x * 0.5 + j * win.x / nv, wy, 0.15, Vector3(0.05, win.y, 0.04), frame)
			var nh = maxi(2, int(win.y / 0.5))
			for j in range(1, nh):
				_bx(b, x, n, face, u, wy - win.y * 0.5 + j * win.y / nh, 0.15, Vector3(win.x, 0.05, 0.04), frame)
		_:
			_bx(b, x, n, face, u, wy, 0.15, Vector3(0.07, win.y, 0.04), frame)
			_bx(b, x, n, face, u, wy + win.y * 0.12, 0.15, Vector3(win.x, 0.06, 0.04), frame)
	if o.get("sill", true):
		_bx(b, x, n, face, u, wy - win.y * 0.5 - 0.2, 0.16, Vector3(win.x + 0.5, 0.12, 0.3), frame.lightened(0.12))
	# kepenkler: bazıları açık (iki yana), bazıları yarı kapalı (tek kanat), kimi pencerede çiçek kutusu
	if o.has("shutter"):
		var sc: Color = o["shutter"]
		var r = rng.randf()
		if r < 0.55:
			for sx in [-1.0, 1.0]:
				_bx(b, x, n, face, u + sx * (win.x * 0.5 + 0.15 + win.x * 0.25), wy, 0.1, Vector3(win.x * 0.48, win.y + 0.15, 0.06), sc)
				for j in 3:
					_bx(b, x, n, face, u + sx * (win.x * 0.5 + 0.15 + win.x * 0.25), wy - win.y * 0.33 + j * win.y * 0.33, 0.14, Vector3(win.x * 0.44, 0.05, 0.03), sc.darkened(0.25))
		elif r < 0.75:
			_bx(b, x, n, face, u - win.x * 0.25, wy, 0.17, Vector3(win.x * 0.5, win.y, 0.05), sc)
	if fl > 0 and rng.randf() < float(o.get("flower", 0.22)):
		_bx(b, x, n, face, u, wy - win.y * 0.5 - 0.42, 0.32, Vector3(win.x + 0.1, 0.36, 0.42), Color(0.45, 0.3, 0.2))
		var fc = [Color(0.86, 0.25, 0.3), Color(0.95, 0.75, 0.3), Color(0.85, 0.5, 0.75), Color(0.95, 0.95, 0.9)][rng.randi() % 4]
		for j in 3:
			var q = _p(x, n, face, u - win.x * 0.33 + j * win.x * 0.33, 0.35)
			b.sphere(Vector3(q.x, wy - win.y * 0.5 - 0.12, q.y), Vector3(0.5, 0.38, 0.4), Color(0.3, 0.52, 0.28) if j % 2 == 0 else fc, 6)


## Arka kapı: çerçeve + kanat + kol, üstünde payandalı küçük eğik saçak, yanında duvar lambası, önünde basamaklar (katı)
static func back_door(b: Builder, x: float, n: float, face: float, u: float, y0: float, o := {}) -> void:
	if not on():
		return
	var dw: float = float(o.get("door_w", 1.8))
	var dh: float = float(o.get("door_h", 2.5))
	var frame: Color = o.get("frame", Color(0.32, 0.22, 0.15))
	var dc: Color = o.get("door_col", Color(0.45, 0.3, 0.18))
	_bx(b, x, n, face, u, y0 + dh * 0.5 + 0.08, 0.06, Vector3(dw + 0.4, dh + 0.25, 0.14), frame)
	_bx(b, x, n, face, u, y0 + dh * 0.5, 0.12, Vector3(dw, dh, 0.08), dc)
	for j in 2:   # kanat panoları
		_bx(b, x, n, face, u, y0 + dh * (0.3 + j * 0.42), 0.17, Vector3(dw * 0.75, dh * 0.3, 0.03), dc.darkened(0.18))
	_bx(b, x, n, face, u + dw * 0.36, y0 + dh * 0.48, 0.2, Vector3(0.08, 0.3, 0.08), Color(0.75, 0.62, 0.3))
	if o.has("awning"):
		var ac: Color = o["awning"]
		_bx(b, x, n, face, u, y0 + dh + 0.55, 0.75, Vector3(dw + 1.4, 0.14, 1.5), ac, false, 16.0)
		_bx(b, x, n, face, u, y0 + dh + 0.36, 1.48, Vector3(dw + 1.45, 0.16, 0.08), ac.darkened(0.25))
		for sx in [-1.0, 1.0]:   # çapraz payandalar
			var q = _p(x, n, face, u + sx * (dw * 0.5 + 0.5), 0.45)
			b.box(Vector3(q.x, y0 + dh + 0.15, q.y), Vector3(0.1, 0.9, 0.1), frame, face, false, Vector3(-40, 0, 0))
	if o.get("lamp", true):
		var lq = _p(x, n, face, u - dw * 0.5 - 0.55, 0.22)
		b.box(Vector3(lq.x, y0 + dh - 0.1, lq.y), Vector3(0.08, 0.08, 0.35), Color(0.2, 0.2, 0.2), face, false)
		var lq2 = _p(x, n, face, u - dw * 0.5 - 0.55, 0.42)
		b.cyl(Vector3(lq2.x, y0 + dh - 0.32, lq2.y), 0.32, 0.42, Color(1.0, 0.9, 0.62), false, 8)
		b.cyl(Vector3(lq2.x, y0 + dh - 0.08, lq2.y), 0.38, 0.06, Color(0.2, 0.2, 0.2), false, 8)
	var sq0 = _p(x, n, face, u, 0.6)
	if o.get("steps", true) and y0 - ground(b, sq0.x, sq0.y) > 0.08:
		var g = ground(b, sq0.x, sq0.y)
		var rise = y0 - g
		var ns = clampi(int(ceil(rise / 0.22)), 1, 6)
		var sh = maxf(rise, 0.18) / ns
		for k in ns:   # en üst basamak kapı eşiği hizasında, aşağı indikçe dışarı uzar (katı: üstüne basılır)
			var top = y0 - k * sh
			var bot = g - 0.4
			var sq = _p(x, n, face, u, 0.45 + k * 0.4)
			b.box(Vector3(sq.x, (top + bot) * 0.5, sq.y), Vector3(dw + 1.0, top - bot, 0.9 + 0.0), Color(0.62, 0.6, 0.57).darkened(0.04 * k), face, true)


## Duvar dibine gündelik eşya: türüne göre sandık yığını, fıçı, odun yığını, kova, süpürge, çamaşır ipi, bitki saksısı.
## skips: kapı vb. önü boş kalacak u aralıkları
static func props(b: Builder, x: float, n: float, face: float, w: float, y0: float, kind: String, rng: RandomNumberGenerator, skips := []) -> void:
	if not on():
		return
	var slots = maxi(1, int(w / 7.0))
	var wood = Color(0.5, 0.36, 0.22)
	for k in slots:
		var u = -w * 0.5 + (k + 0.5) * w / slots + rng.randf_range(-1.2, 1.2)
		if absf(u) > w * 0.5 - 1.2 or _skip(u, 1.4, skips):
			continue
		if rng.randf() < 0.3:
			continue   # her yer dolu olmasın
		var pick = rng.randi() % 6
		match kind:
			"kitchen": pick = [0, 1, 2, 2, 4, 5][rng.randi() % 6]
			"home": pick = [2, 3, 4, 5, 5, 1][rng.randi() % 6]
			"shrine": pick = [2, 4, 2, 4, 5, 2][rng.randi() % 6]
			"clinic": pick = [0, 1, 5, 0, 4, 1][rng.randi() % 6]
		var q = _p(x, n, face, u, 0.0)
		var g = ground(b, q.x, q.y)
		match pick:
			0:   # sandık yığını (katı)
				var nb = 1 + rng.randi() % 3
				for j in nb:
					var s = rng.randf_range(0.7, 1.0)
					var cq = _p(x, n, face, u + (j % 2) * 0.9 - 0.45 * float(nb > 1), 0.75)
					var cy = g + s * 0.5 + (0.9 if j == 2 else 0.0)
					b.box(Vector3(cq.x, cy, cq.y), Vector3(s, s, s), wood.lightened(rng.randf() * 0.15), face + rng.randf_range(-8, 8), true)
					b.box(Vector3(cq.x, cy, cq.y), Vector3(s + 0.04, 0.08, s + 0.04), wood.darkened(0.3), face, false)
			1:   # fıçılar (katı)
				for j in 1 + rng.randi() % 2:
					var bq = _p(x, n, face, u + j * 1.05, 0.7)
					b.cyl(Vector3(bq.x, g + 0.5, bq.y), 0.9, 1.0, Color(0.46, 0.32, 0.2), true, 10)
					for hy in [0.22, 0.78]:
						b.cyl(Vector3(bq.x, g + hy, bq.y), 0.95, 0.06, Color(0.22, 0.22, 0.24), false, 10)
			2:   # odun yığını: duvara yaslı istif + duvara bakan kütük uçları, üstünde kiremit kapak
				var lw = rng.randf_range(2.2, 3.4)
				var lh = rng.randf_range(0.9, 1.4)
				var oq = _p(x, n, face, u, 0.45)
				b.box(Vector3(oq.x, g + lh * 0.5, oq.y), Vector3(lw, lh, 0.8), Color(0.46, 0.32, 0.2), face, true)
				for r in int(lh / 0.3):
					for j in int(lw / 0.3):
						if rng.randf() < 0.75:
							var eq = _p(x, n, face, u - lw * 0.5 + 0.15 + j * 0.3 + (r % 2) * 0.08, 0.86)
							b.disc(Vector3(eq.x, g + 0.15 + r * 0.3, eq.y), 0.28, 0.04, Color(0.78, 0.62, 0.42).darkened(rng.randf() * 0.15), face, 6)
				var rq = _p(x, n, face, u, 0.5)
				b.box(Vector3(rq.x, g + lh + 0.12, rq.y), Vector3(lw + 0.3, 0.08, 1.1), Color(0.32, 0.3, 0.3), face, false, Vector3(-10, 0, 0))
			3:   # çamaşır / kurutma ipi: iki direk + ip + asılı bezler
				var span = rng.randf_range(3.0, 4.6)
				for sx in [-1.0, 1.0]:
					var pq = _p(x, n, face, u + sx * span * 0.5, 1.6)
					b.box(Vector3(pq.x, g + 1.1, pq.y), Vector3(0.12, 2.2, 0.12), wood.darkened(0.2), face, true)
				_bx(b, x, n, face, u, g + 2.05, 1.6, Vector3(span, 0.03, 0.03), Color(0.85, 0.82, 0.75))
				var cols = [Color(0.95, 0.95, 0.92), Color(0.3, 0.42, 0.68), Color(0.85, 0.4, 0.3), Color(0.92, 0.85, 0.6), Color(0.4, 0.6, 0.45)]
				if kind == "clinic":
					cols = [Color(0.97, 0.97, 0.96), Color(0.9, 0.95, 0.95), Color(0.97, 0.97, 0.96)]
				var nc = 2 + rng.randi() % 3
				for j in nc:
					var cl = rng.randf_range(0.6, 1.0)
					_bx(b, x, n, face, u - span * 0.38 + j * span * 0.76 / maxf(1.0, nc - 1), g + 2.02 - cl * 0.5, 1.6, Vector3(0.75, cl, 0.03), cols[rng.randi() % cols.size()])
			4:   # kova + süpürge + taş basamak
				var kq = _p(x, n, face, u, 0.55)
				b.cyl(Vector3(kq.x, g + 0.22, kq.y), 0.5, 0.44, Color(0.55, 0.4, 0.24), false, 10)
				var sq = _p(x, n, face, u + 0.7, 0.2)
				b.box(Vector3(sq.x, g + 0.85, sq.y), Vector3(0.06, 1.7, 0.06), wood, face, false, Vector3(-12, 0, 8))
				b.box(Vector3(sq.x, g + 0.18, sq.y + 0.0), Vector3(0.45, 0.36, 0.12), Color(0.75, 0.65, 0.35), face, false, Vector3(-12, 0, 8))
				var tq = _p(x, n, face, u - 0.8, 0.6)
				b.box(Vector3(tq.x, g + 0.1, tq.y), Vector3(0.9, 0.2, 0.6), Color(0.6, 0.6, 0.58), face + 7.0, false)
			5:   # saksılar / bodur çalılar
				for j in 2 + rng.randi() % 2:
					var sq2 = _p(x, n, face, u - 0.6 + j * 0.7, 0.5)
					b.cyl(Vector3(sq2.x, g + 0.25, sq2.y), 0.55, 0.5, Color(0.58, 0.32, 0.22), false, 8)
					b.sphere(Vector3(sq2.x, g + 0.7, sq2.y), Vector3(0.75, 0.6, 0.7), Color(0.3, 0.52, 0.28).lightened(rng.randf() * 0.12), 6)


## Düz çatıya su deposu (anime Konoha çatılarının simgesi): ayaklı silindir, kapak, kenarda merdiven
static func roof_tank(b: Builder, x: float, n: float, y: float, d := 2.6, col := Color(0.82, 0.84, 0.86)) -> void:
	if not on():
		return
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(x + sx * d * 0.32, y + 0.5, n + sz * d * 0.32), Vector3(0.16, 1.0, 0.16), Color(0.3, 0.3, 0.32), 0, false)
	b.cyl(Vector3(x, y + 1.0 + d * 0.45, n), d, d * 0.9, col, true, 12)
	b.cone(Vector3(x, y + 1.0 + d * 0.9 + 0.2, n), d * 1.05, 0.4, col.darkened(0.2), 12)
	for k in 2:
		b.cyl(Vector3(x, y + 1.0 + d * (0.25 + k * 0.4), n), d + 0.06, 0.08, col.darkened(0.3), false, 12)
	b.box(Vector3(x + d * 0.5 + 0.08, y + 1.0 + d * 0.45, n), Vector3(0.05, d * 0.9 + 1.0, 0.5), Color(0.3, 0.3, 0.32), 0, false)


## Çatkılı ahşap duvar (shinkabe): eşit aralıklı dikmeler + yatay kirişler (ön cephenin dilini arka / yanlara taşır)
static func timber(b: Builder, x: float, n: float, face: float, w: float, y0: float, h: float, pitch: float, beams: Array, col: Color) -> void:
	if not on():
		return
	var np = maxi(1, int(round(w / pitch)))
	for k in np + 1:
		_bx(b, x, n, face, -w * 0.5 + k * w / np, y0 + h * 0.5, 0.08, Vector3(0.42, h, 0.22), col)
	for by in beams:
		_bx(b, x, n, face, 0.0, y0 + float(by), 0.09, Vector3(w + 0.1, 0.38, 0.22), col)
