class_name FutonFXE
extends RefCounted
## Fūton grubu E: Rasenshuriken ailesi + Bashōsen rüzgâr sargısı + Senpō kum fırtınası.
## Kendi gölgelendiricileri: Rasengan çekirdeği (dönen sarmal cel küre), Rasenshuriken bıçak diski (dört süpürülmüş ince bıçak,
## önde keskin beyaz kenar, arkada saydam lif lif çözülen kuyruk), mikro rüzgâr bıçakları küresi (dolu kabuk değil: sayısız ince
## kesik çizgiden oluşan dönen küre). Akım çizgisi / perde / basınç / zemin izi / savrulan parça yapı taşları FutonLib'den.
## Her tekniğin ölçeği, rengi ve sahnelenmesi kendine özgü. Oynanış ana ağaçtaki işleyicilerden satır satır taşındı;
## eski görsel çağrıların oyun etkileri (rüzgârın yanan zemini büyütmesi, yarık zemin) açıkça korunur.

const WIND := Color(0.9, 0.96, 1.0, 0.95)
const PALE := Color(0.78, 0.9, 1.0, 0.9)
const BLUE_IN := Color(0.92, 0.98, 1.0, 1.0)
const BLUE_OUT := Color(0.36, 0.62, 1.0, 1.0)
const SAGE := Color(1.0, 0.6, 0.2, 0.9)
const GOLD_IN := Color(1.0, 0.98, 0.84, 1.0)
const GOLD_OUT := Color(1.0, 0.7, 0.16, 1.0)
const GOLD := Color(1.0, 0.86, 0.42, 0.95)
const DARK_IN := Color(0.05, 0.02, 0.09, 1.0)
const DARK_OUT := Color(0.42, 0.2, 0.64, 1.0)
const VIOLET := Color(0.4, 0.2, 0.58, 0.9)
const SAND := Color(0.93, 0.8, 0.55, 0.95)

static var _c := {}

# ================================================================== gölgelendiriciler
## Rasengan çekirdeği (SphereMesh r=1): ortası beyaz, kenarı mavi; yüzeyde dönen sarmal bantlar ve ince parlak sarmal çizgiler,
## koyu ince kontur. inner / outer / streak renkleriyle Bijūdama (kara) ve Rikudō (altın) çekirdeği de olur.
const CORE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform vec4 inner : source_color = vec4(0.92, 0.98, 1.0, 1.0);
instance uniform vec4 outer : source_color = vec4(0.36, 0.62, 1.0, 1.0);
instance uniform vec4 streak : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float spin = 7.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float near = 2.6;

FNOISE

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 n = normalize(lp);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	float lon = atan(n.z, n.x);
	float t = TIME * spin;
	float sw = wn(vec2(lon * 1.9 + lat * 3.0 - t + seed, lat * 5.0 + t * 0.3));
	float tone = fr + (sw - 0.5) * 0.45;
	vec3 col = inner.rgb;
	if (tone > 0.72) {
		col = outer.rgb;
	} else if (tone > 0.42) {
		col = mix(inner.rgb, outer.rgb, 0.45);
	}
	float l1 = fract(lon * 0.6366 + lat * 0.9 - t * 0.15 + seed);
	float g1 = step(0.45, wn(vec2(lon * 3.0 - t, lat * 6.0 + seed)));
	float l2 = fract(lon * 1.1141 - lat * 1.3 + t * 0.2 + seed * 0.5);
	float g2 = step(0.55, wn(vec2(lat * 7.0 + t, lon * 2.0 - seed)));
	if (abs(l1 - 0.5) < 0.035 * g1 || abs(l2 - 0.5) < 0.02 * g2) {
		col = streak.rgb;
	}
	float a = mix(0.95, 0.78, fr);
	if (fr > 0.9) {
		col = outer.rgb * 0.55;
		a = 0.9;
	}
	ALBEDO = col;
	ALPHA = a * fade * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Rasenshuriken bıçak diski (PlaneMesh 1x1, XZ düzlemi). blades adet ince süpürülmüş bıçak: ön kenar keskin beyaz şerit + önünde
## ince koyu kontur, gövde yarı saydam, kuyruk lif lif çözülür; tüm disk üstünde çok soluk dönen hava, dış kenarda kopuk halka.
## grow 0..1: bıçaklar merkezden dışa açılır. Dönüş gölgelendiricide (spin).
const DISC_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(0.86, 0.94, 1.0, 1.0);
instance uniform float blades = 4.0;
instance uniform float sweep = 1.8;
instance uniform float spin = 9.0;
instance uniform float grow = 1.0;
instance uniform float alpha_k = 1.0;
instance uniform float hole = 0.14;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float near = 2.6;

FNOISE

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float big = max(grow, 0.001);
	if (r > big) {
		discard;
	}
	float rr = r / big;
	float an = atan(p.y, p.x);
	float ba = an - TIME * spin + rr * sweep + seed;
	float f = fract(ba * blades / 6.2831853);
	float w = mix(0.6, 0.1, smoothstep(0.25, 1.0, rr)) * smoothstep(hole * 0.6, hole + 0.12, rr);
	float k = (f - (1.0 - w)) / max(w, 0.001);
	vec3 col = tint.rgb;
	float al = 0.0;
	float hz = wf(vec2(rr * 6.0 - TIME * 2.0, ba * 3.0));
	if (rr < 0.92) {
		al = 0.08 + 0.08 * step(0.55, hz);
	}
	if (k > 0.0) {
		float st = wn(vec2(rr * 38.0 + seed * 3.0, ba * 1.5));
		if (k > 0.86) {
			col = vec3(1.0);
			al = 0.95;
		} else if (k > 0.45) {
			col = st > 0.6 ? vec3(1.0) : tint.rgb;
			al = st > 0.6 ? 0.8 : 0.5;
		} else if (st > 0.5) {
			col = mix(tint.rgb, vec3(1.0), 0.5);
			al = max(al, 0.1 + 0.3 * k / 0.45);
		}
	} else if (f < 0.012 && w > 0.05) {
		col = tint.rgb * 0.45;
		al = 0.6;
	}
	float ring = abs(rr - 0.96);
	if (ring < 0.012 && wn(vec2(an * 6.0 - TIME * spin * 1.2, seed)) > 0.5) {
		col = vec3(1.0);
		al = max(al, 0.7);
	}
	al *= alpha_k * fade * tint.a;
	if (al < 0.02) {
		discard;
	}
	ALBEDO = col;
	ALPHA = al * smoothstep(near * 0.35, near, length(VERTEX));
}
"""

## Mikro rüzgâr bıçakları küresi (SphereMesh r=1, iki yüzlü): yüzeyde dönen, yanıp sönen sayısız kısa ince kesik çizgi.
## Dolu kabuk yok; yalnız çok soluk kenar pusu (haze). lift: çizgi çekirdeğinin beyaza çekilmesi (kara küre için düşük).
const NEEDLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(0.9, 0.96, 1.0, 1.0);
instance uniform float density = 16.0;
instance uniform float swirl = 1.4;
instance uniform float cut = 0.8;
instance uniform float haze = 0.05;
instance uniform float lift = 0.8;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float near = 4.0;

FNOISE

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float needle(vec2 g, float s, float ct, float tm) {
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float ph = fract(wh(cell * 1.7 + vec2(s + 3.1, s)) + tm * 1.9);
	if (ph > 0.7) {
		return 0.0;
	}
	float ang = (wh(cell + vec2(s, s * 0.5)) - 0.5) * 1.4;
	vec2 dir = vec2(cos(ang), sin(ang));
	f += (vec2(wh(cell + vec2(s + 5.0, 1.0)), wh(cell + vec2(2.0, s + 9.0))) - 0.5) * 0.3;
	float al = dot(f, dir);
	float ac = abs(dot(f, vec2(-dir.y, dir.x)));
	float len0 = ct * 0.5 * (0.5 + wh(cell * 2.3 + vec2(s, 0.7)));
	if (abs(al) > len0) {
		return 0.0;
	}
	float w = 0.05 * (1.0 - abs(al) / len0) + 0.004;
	if (ac < w * 0.45) {
		return 1.0;
	}
	return ac < w ? 0.5 : 0.0;
}

void fragment() {
	vec3 n = normalize(lp);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	float lon = atan(n.z, n.x) + TIME * swirl * (1.0 + 0.4 * sin(lat * 3.0 + seed));
	vec2 g = vec2(lon / 6.2831853 * density * 2.0, (lat / 3.14159 + 0.5) * density);
	float v = max(needle(g, seed, cut, TIME), needle(g * 1.7 + vec2(0.5, 0.3), seed + 11.0, cut, TIME));
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 col = tint.rgb;
	float a = haze * fr;
	if (v > 0.9) {
		col = mix(tint.rgb, vec3(1.0), lift);
		a = 0.95;
	} else if (v > 0.4) {
		a = max(a, 0.5);
	}
	a *= (0.55 + 0.45 * fr) * tint.a * fade;
	if (a < 0.02) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a * smoothstep(near * 0.35, near, length(VERTEX));
}
"""


# ================================================================== malzeme / örgü
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _c.has(key):
		return _c[key]
	var sh = Shader.new()
	sh.code = code.replace("FNOISE", FutonLib.FNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	_c[key] = m
	return m


static func _sphere() -> SphereMesh:
	if not _c.has("sphere"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 40
		s.rings = 20
		_c["sphere"] = s
	return _c["sphere"]


static func _disc_mesh() -> PlaneMesh:
	if not _c.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(1.0, 1.0)
		_c["plane"] = p
	return _c["plane"]


static func _later(host: Node, sec: float, fn: Callable) -> void:
	host.get_tree().create_timer(sec).timeout.connect(fn)


## Merminin destan ölçeği (çarpma anında): kutudaki mermiden
static func _ep(box: Dictionary) -> float:
	var pr = box.get("pr", null)
	if pr != null and is_instance_valid(pr):
		return float(pr.epic)
	return 1.0


## Eski çarpma görsellerinin oyun etkileri: rüzgâr yanan zemini büyütür; yarık zemin üstünden geçeni yavaşlatır
static func _ground(pos: Vector3, wind_r: float, crack_r: float) -> void:
	GroundFX.wind(pos, wind_r)
	if crack_r >= 1.5:
		GroundFX.add(FutonLib.floor_at(pos), "cracked", crack_r * 0.6, 5.0)


# ================================================================== yapı taşları (bu grubun)
## Rasengan çekirdeği
static func core(host: Node, pos: Vector3, r: float, inner: Color, outer: Color, o := {}) -> MeshInstance3D:
	var mi = FutonLib.gi(_sphere(), _mat("core", CORE_SHADER))
	mi.set_instance_shader_parameter("inner", inner)
	mi.set_instance_shader_parameter("outer", outer)
	mi.set_instance_shader_parameter("streak", o.get("streak", Color(1, 1, 1, 1)))
	mi.set_instance_shader_parameter("spin", float(o.get("spin", 7.0)))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	if o.has("near"):
		mi.set_instance_shader_parameter("near", float(o["near"]))
	FutonLib.put(host, mi, pos, o.get("parent", null))
	mi.scale = Vector3.ONE * r
	return mi


## Bıçak diski (parent'a bağlı, yerel XZ düzleminde)
static func disc(host: Node, parent: Node3D, size: float, tint: Color, o := {}) -> MeshInstance3D:
	var mi = FutonLib.gi(_disc_mesh(), _mat("disc", DISC_SHADER))
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("blades", float(o.get("blades", 4.0)))
	mi.set_instance_shader_parameter("sweep", float(o.get("sweep", 1.8)))
	mi.set_instance_shader_parameter("spin", float(o.get("spin", 9.0)))
	mi.set_instance_shader_parameter("grow", float(o.get("grow", 1.0)))
	mi.set_instance_shader_parameter("alpha_k", float(o.get("alpha", 1.0)))
	mi.set_instance_shader_parameter("hole", float(o.get("hole", 0.14)))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("near", float(o.get("near", 2.6)))
	FutonLib.put(host, mi, o.get("pos", Vector3.ZERO), parent)
	mi.scale = Vector3(size, 1.0, size)
	return mi


## Rasenshuriken gövdesi (anime: küçük mavi çekirdek + çevresinde dört ince süpürülmüş beyaz rüzgâr bıçağı + kopuk dış halka).
## Sahneye eklenmez; çağıran bağlar. o: inner, outer, streak, tint, core_r (disk çapına oran), spin, rings (dış halka çizgisi rengi),
## halo (geniş soluk üçüncü katman, Ōdama)
static func shuriken(host: Node, size: float, o := {}) -> Node3D:
	var root = Node3D.new()
	var sp = float(o.get("spin", 9.0))
	var tint: Color = o.get("tint", Color(0.86, 0.94, 1.0, 1.0))
	var cr = core(host, Vector3.ZERO, size * float(o.get("core_r", 0.11)), o.get("inner", BLUE_IN), o.get("outer", BLUE_OUT),
		{"parent": root, "streak": o.get("streak", Color(1, 1, 1, 1)), "spin": sp * 0.8})
	var da = disc(host, root, size, tint, {"spin": sp, "sweep": 1.8})
	var db = disc(host, root, size * 1.14, tint.lightened(0.3), {"spin": sp * 0.75, "sweep": 2.6, "alpha": 0.45, "pos": Vector3(0, -0.02, 0)})
	var discs = [da, db]
	if bool(o.get("halo", false)):
		discs.append(disc(host, root, size * 1.5, Color(0.95, 0.97, 1.0, 0.7), {"spin": sp * 0.45, "sweep": 3.4, "blades": 6.0, "alpha": 0.35, "hole": 0.3, "pos": Vector3(0, 0.03, 0)}))
	var rc: Color = o.get("rings", WIND)
	for q in 2:
		FutonLib.fixed(host, FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, size * 0.53, size * 0.53, 0.0, 0.0, q * PI + 0.4, 0.32, 18), size * 0.012, "line", rc,
			{"parent": root, "hint": Vector3.UP, "twin": false, "flow": 9.0})
	root.set_meta("discs", discs)
	root.set_meta("core", cr)
	return root


static func set_grow(body: Node3D, v: float) -> void:
	if not is_instance_valid(body) or not body.has_meta("discs"):
		return
	for d in body.get_meta("discs"):
		if is_instance_valid(d):
			d.set_instance_shader_parameter("grow", v)


## Mikro bıçak küresi örneği (tween'siz). o: tint, density, swirl, cut, haze, lift, near, parent
static func needles(host: Node, pos: Vector3, r: float, o := {}) -> MeshInstance3D:
	var mi = FutonLib.gi(_sphere(), _mat("needle", NEEDLE_SHADER))
	mi.set_instance_shader_parameter("tint", o.get("tint", WIND))
	mi.set_instance_shader_parameter("density", float(o.get("density", 16.0)))
	mi.set_instance_shader_parameter("swirl", float(o.get("swirl", 1.4)))
	mi.set_instance_shader_parameter("cut", float(o.get("cut", 0.8)))
	mi.set_instance_shader_parameter("haze", float(o.get("haze", 0.05)))
	mi.set_instance_shader_parameter("lift", float(o.get("lift", 0.8)))
	mi.set_instance_shader_parameter("near", float(o.get("near", 5.0)))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	FutonLib.put(host, mi, pos, o.get("parent", null))
	mi.scale = Vector3.ONE * r
	return mi


## Genişleyen mikro bıçak küresi: grow_t'de açılır, hold kalır, sonra out oranına (küçülerek ya da açılarak) söner.
## o: needles() ayarları + aspect (Vector3), delay, grow_t, out
static func dome(host: Node, pos: Vector3, rad: float, hold: float, o := {}) -> MeshInstance3D:
	var mi = needles(host, pos, rad * 0.08, o)
	var asp: Vector3 = o.get("aspect", Vector3.ONE)
	mi.scale = asp * rad * 0.08
	mi.visible = false
	var tw = mi.create_tween()
	var dl = float(o.get("delay", 0.0))
	if dl > 0.0:
		tw.tween_interval(dl)
	tw.tween_callback(func(): mi.visible = true)
	tw.tween_property(mi, "scale", asp * rad, float(o.get("grow_t", 0.3))).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(FutonLib.pf(mi, "fade"), 1.0, 0.0, 0.45)
	tw.parallel().tween_property(mi, "scale", asp * rad * float(o.get("out", 0.55)), 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Çekirdeğin çarpmada kalıp küçülmesi
static func _core_hold(host: Node, pos: Vector3, r: float, life: float, inner: Color, outer: Color, o := {}) -> MeshInstance3D:
	var cm = core(host, pos, r * 0.3, inner, outer, o)
	var tw = cm.create_tween()
	tw.tween_property(cm, "scale", Vector3.ONE * r, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.05, life - 0.5))
	tw.tween_property(cm, "scale", Vector3.ONE * 0.04, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(cm.queue_free)
	return cm


## Küre sönünce geride kalan kesik: ışınsal süpürme, bıçak yarıkları, fırlayan kaya / çakıl, yere çöken toz
static func _aftermath(host: Node, pos: Vector3, rad: float, delay: float, o := {}) -> void:
	var g = FutonLib.floor_at(pos)
	if pos.y - g.y > rad * 1.1:
		return
	var gc = FutonLib.ground_col(g)
	_later(host, delay, func():
		FutonLib.scour(host, g, Vector3.FORWARD, rad * 2.2, rad * 2.2, 5.0, 1)
		for i in int(o.get("slits", 2)):
			var sd = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			FutonLib.scour(host, g + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)) * rad, sd, rad * 1.4, rad * 1.4, 5.5, 2)
		FutonLib.chunks(host, g, int(o.get("chunks", 6)), clampf(rad * 0.9, 4.0, 12.0), gc.darkened(0.35), clampf(rad * 0.05, 0.2, 0.6))
		FutonLib.bits(host, g + Vector3.UP * 0.3, int(clampf(rad * 2.0, 8.0, 30.0)), "grit", {"life": 1.1, "size": 0.14, "radius": rad * 0.6, "dir": Vector3.UP,
			"spread": 70.0, "vmin": 4.0, "vmax": 9.0, "spin": 600.0, "g": Vector3(0, -9, 0), "turb": false,
			"cols": [gc.darkened(0.3), gc.darkened(0.4), Color(gc.r, gc.g, gc.b, 0.0)]})
		FutonLib.bits(host, g + Vector3.UP * 0.4, int(clampf(rad * 1.5, 6.0, 20.0)), "puff", {"life": 1.4, "size": clampf(rad * 0.25, 0.8, 3.0), "radius": rad * 0.9,
			"dir": Vector3.UP, "spread": 80.0, "vmin": 1.5, "vmax": 4.0, "radial": 3.0, "g": Vector3(0, -0.3, 0), "damp": 1.5, "grow": [0.6, 1.5], "spin": 30.0,
			"burst": 0.6, "cols": FutonLib.dust_cols(g, 0.7)}))


## Rasenshuriken küresinin hücre kesikleri (eski _rasen_burst'ün hasarı birebir: 0.15 sn sonra 9 x 0.12 sn)
static func _cut_ticks(host: Node, c: Node3D, pos: Vector3, rad: float, m: float) -> void:
	var tk = Node3D.new()
	FutonLib.put(host, tk, pos)
	FutonLib.kill(host, 1.8, tk)
	var ht = tk.create_tween()
	ht.tween_interval(0.15)
	for i in 9:
		ht.tween_callback(func():
			if is_instance_valid(c):
				Combat.hit_sphere(c, pos, rad, {"dmg": 8.0 * m, "element": "fuuton", "knock": 0.5, "kind": "light", "hitstop": 0.02}))
		ht.tween_interval(0.12)


## Merkeze sarmal çizgilerle çekilen hava (toplanma)
static func _inspiral(host: Node, at: Vector3, r: float, n: int, life: float, tint: Color, o := {}) -> void:
	var ax: Vector3 = o.get("axis", Vector3.UP)
	var flat = float(o.get("flat", 0.4))
	for i in n:
		var a0 = TAU * i / float(n) + randf() * 0.4
		var h0 = randf_range(-1.0, 1.0) * r * flat
		var pts = FutonLib.helix_pts(at, ax, r * randf_range(0.8, 1.1), r * 0.06, h0, 0.0, a0, randf_range(0.5, 0.9), 22)
		FutonLib.line(host, pts, float(o.get("w", 0.04)) * maxf(1.0, r * 0.3), life, tint, {"delay": i * float(o.get("stagger", 0.03)), "grow": 0.7, "flow": 6.0, "near": 2.0})


# ================================================================== 1. Fūton: Rasenshuriken (hazırlık + atış + küre)
## Görünüş (ref: kol başın üstünde; mavi çekirdek, çevresinde geniş beyaz bıçak diski): avuçta önce çekirdek belirir, bıçaklar dışa
## açılır; çevreden ince hava çizgileri sarmallanarak toplanır, çınlayan basınç halkası. Uçuşta disk eğik döner, uçlarından iki
## çığlık çizgisi tirbuşon gibi iz bırakır. Çarpmada beyaz mikro bıçak küresi açılır, içinde mavi çekirdek, sonra küçülerek söner;
## yerde ışınsal süpürme ve bıçak yarıkları kalır.
static func form_fuuton_rasenshuriken(j, c: Node3D, dur: float) -> void:
	var md = c.get("model")
	if md == null or md.skel == null or md.skel.find_bone("RightHand") < 0:
		return
	var ba = BoneAttachment3D.new()
	ba.bone_name = "RightHand"
	md.skel.add_child(ba)
	var holder = Node3D.new()
	ba.add_child(holder)
	holder.top_level = true   # kemik dönüşünü almasın: disk dünyada yatay kalır
	var body = shuriken(j, 2.8)
	holder.add_child(body)
	body.scale = Vector3.ONE * 0.05
	set_grow(body, 0.0)
	c.set_meta("rs_form", holder)
	var tw = body.create_tween()
	tw.tween_property(body, "scale", Vector3.ONE, maxf(0.2, dur * 0.45)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): set_grow(body, v), 0.0, 1.0, maxf(0.2, dur * 0.5))
	Sfx.play("rasengan", c.global_position, 0.8)
	var stt = {"t": 0.0}
	var timer = Timer.new()
	timer.wait_time = 1.0 / 60.0
	holder.add_child(timer)
	timer.timeout.connect(func():
		stt["t"] += 1.0 / 60.0
		if not is_instance_valid(ba) or not ba.is_inside_tree():
			return
		holder.global_position = ba.global_position + Vector3.UP * 0.55
		var fdv: Vector3 = c.face_dir() if is_instance_valid(c) and c.has_method("face_dir") else Vector3.FORWARD
		holder.global_basis = Basis(fdv.cross(Vector3.UP).normalized(), 0.6)   # disk arkaya (kameraya) eğik: bıçaklar görünür
		var fi = int(stt["t"] * 60.0)
		if fi % 6 == 0:
			_inspiral(j, holder.global_position, 2.2, 2, 0.32, WIND, {"w": 0.025})
		if stt["t"] > 0.3 and fi % 18 == 0:
			FutonLib.warp(j, holder.global_position, 1.9, 1.3, 0.28, {"power": 0.9, "glint": 0.5})   # çınlayan basınç halkası
		if stt["t"] > 0.25 and fi % 20 == 0:
			Sfx.play("wind", holder.global_position, 1.8, 0.35)   # ince çınlama/uğultu
		if stt["t"] > dur + 0.6:   # atış kesildiyse kendini temizler
			ba.queue_free())
	timer.start()
	holder.global_position = ba.global_position + Vector3.UP * 0.55


static func fuuton_rasenshuriken(j, c: Node3D, t: Node3D) -> void:
	var start = j._hand(c) + Vector3.UP * 0.5
	if c.has_meta("rs_form"):
		var held = c.get_meta("rs_form")
		c.remove_meta("rs_form")
		if is_instance_valid(held):
			start = held.global_position
			var hb = held.get_parent()
			if is_instance_valid(hb):
				hb.queue_free()
	var pr = Projectile.new()
	pr.shooter = c
	pr.vel = j._aim(c, t) * 26.0
	pr.radius = 1.6
	pr.life = 3.0
	pr.homing = t
	pr.homing_turn = 2.0
	# ortak hasar (rütbe + efsane kademe + ustalık): %20 çarpma, asıl hasar genişleyen kürenin 9 hücre kesiği
	var total = JutsuEngine.base_dmg(c, Data.jutsu.get("fuuton_rasenshuriken", {})) * j._elem_bonus(c, "fuuton")
	pr.info = {"dmg": total * 0.2, "element": "fuuton", "knock": 4.0, "kind": "heavy", "hitstop": 0.05}
	var mb = total * 1.6 / 72.0
	var rb = shuriken(j, 2.8 * pr.epic)
	rb.rotation.x = 0.5   # uçuşta disk hafif eğik (yandan bakınca bıçaklar görünür)
	pr.add_child(rb)
	Sfx.play("rasengan", c.global_position, 1.4)
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		var ep = float(pr.epic) if is_instance_valid(pr) else 1.0
		_classic_burst(j, c, pos, mb, ep)
	j.get_tree().current_scene.add_child(pr)
	pr.global_position = start
	for q in 2:   # bıçak uçlarından tirbuşon çığlık çizgileri
		FutonLib.follow(j, pr, 0.05, 16, WIND, {"offset": Vector3(cos(q * PI), sin(q * PI), 0.0) * 1.3 * pr.epic, "spin": 11.0, "flow": 9.0})
	FutonLib.follow(j, pr, 0.55 * pr.epic, 12, PALE, {"kind": "sheet", "opacity": 0.3, "lines": 3.0, "near": 3.0})


static func _classic_burst(host: Node, c: Node3D, pos: Vector3, m: float, ep: float) -> void:
	var rad = 6.0 * ep
	dome(host, pos, rad, 1.0, {"density": 16.0, "swirl": 1.6, "out": 0.5})
	dome(host, pos, rad * 1.06, 0.95, {"density": 11.0, "swirl": -1.0, "cut": 0.6, "tint": PALE, "delay": 0.05, "haze": 0.03, "out": 0.6})
	_core_hold(host, pos, clampf(rad * 0.2, 0.5, 3.0), 1.6, BLUE_IN, BLUE_OUT)
	FutonLib.warp(host, pos, rad * 0.3, rad * 1.6, 0.5, {"power": 2.2, "glint": 0.5})
	_aftermath(host, pos, rad, 1.25, {"slits": 3, "chunks": 7})
	_ground(FutonLib.floor_at(pos) + Vector3.UP * 0.5, rad * 1.8 * ep, rad * 1.3 * ep)
	Sfx.play("wind", pos, 0.6)
	Sfx.play("rasengan", pos, 0.7)
	if Game.world:
		Game.world.env.add_shake(1.0)
	_cut_ticks(host, c, pos, rad, m)


# ================================================================== 2. Senpō: Fūton Rasenshuriken
## Görünüş (kaynaksız; kanon: doğa enerjisiyle fırlatılabilir, uçarken büyür): başın üstünde turuncu-beyaz doğa enerjisi sarmalları
## ve kıvılcım motları içeri çekilir; beyaz bıçaklı Rasenshuriken etrafında üç turuncu sennin girdabı döner, uçtukça büyür.
## Çarpmada daha büyük mikro bıçak küresi; yüzeyinden yukarı doğru turuncu sarmal doğa çizgileri kıvrılarak kopar.
static func senpo_futon_rasenshuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var tt = pj.tg(c, t, 40.0)
	var over = c.global_position + Vector3.UP * 2.4 + c.face_dir() * 0.6
	_inspiral(pj, over, 3.2, 6, 0.6, SAGE, {"w": 0.05, "stagger": 0.06, "flat": 0.8})
	_inspiral(pj, over, 2.4, 5, 0.5, WIND, {"w": 0.03, "stagger": 0.08})
	FutonLib.bits(pj, over, 26, "grit", {"life": 0.7, "size": 0.09, "radius": 3.0, "radial": -14.0, "tang": 8.0, "vmin": 0.0, "vmax": 0.5, "g": Vector3.ZERO,
		"spread": 180.0, "burst": 0.2, "turb": false, "cols": [Color(1, 0.75, 0.3, 0), Color(1, 0.7, 0.25, 1), Color(1, 0.9, 0.6, 0)]})
	FutonLib.warp(pj, over, 2.8, 0.4, 0.7, {"ring": false, "power": -1.4, "swirl": 2.2})
	pj.after(0.7, func():
		if not pj.live(c):
			return
		var core_n = Node3D.new()
		var body = shuriken(pj, 2.86, {"spin": 10.0})
		body.rotation.x = 0.5
		core_n.add_child(body)
		var box = {}
		var pr = pj.shot(c, over, pj.aim_at(c, tt, over), 22.0, core_n, pj.inf(c, "senpo_futon_rasenshuriken", 1.4, {"knock": 6.0, "kind": "heavy", "element": "fuuton"}), tt, false, 2.6, func(p, _h):
			_senpo_burst(pj, p, _ep(box))
			pj.every(1.6, 0.2, func(_i, _k):
				pj.hit(c, p, 8.0, pj.inf(c, "senpo_futon_rasenshuriken", 0.45, {"knock": 0.0, "kind": "light", "element": "fuuton", "bleed": 2.0})), Callable())
			pj.shake(1.4))
		box["pr"] = pr
		pr.homing_turn = 2.5
		pr.radius = 1.6
		for q in 3:   # turuncu sennin girdabı
			var a = TAU * q / 3.0
			FutonLib.follow(pj, pr, 0.06, 14, SAGE, {"offset": Vector3(cos(a), sin(a), 0.0) * 1.8, "spin": 8.0, "flow": 7.0})
		pj.every(1.6, 0.1, func(_i, k):
			if is_instance_valid(core_n):
				core_n.scale = Vector3.ONE * (1.0 + k * 0.8), Callable()))
	Sfx.play("rasengan", c.global_position, 1.2)


static func _senpo_burst(host: Node, p: Vector3, ep: float) -> void:
	var rad = 8.0 * ep
	dome(host, p, rad, 1.6, {"density": 18.0, "swirl": 2.0, "out": 0.5})
	dome(host, p, rad * 0.8, 1.5, {"density": 12.0, "swirl": -1.4, "cut": 0.5, "tint": Color(1.0, 0.86, 0.66, 0.8), "lift": 0.6, "delay": 0.06})
	_core_hold(host, p, clampf(rad * 0.18, 0.5, 3.0), 2.1, BLUE_IN, BLUE_OUT, {"streak": Color(1.0, 0.85, 0.55)})
	FutonLib.warp(host, p, rad * 0.3, rad * 1.7, 0.55, {"power": 2.4, "glint": 0.6})
	for w in 6:   # yüzeyden kopan turuncu doğa sarmalları
		var dl = 0.2 + w * 0.22
		var a0 = randf() * TAU
		_later(host, dl, func():
			FutonLib.line(host, FutonLib.helix_pts(p, Vector3.UP, rad * 0.5, rad * 1.15, -rad * 0.4, rad * 0.9, a0, 1.1, 34), 0.09 * ep, 0.8, SAGE, {"grow": 0.6, "flow": 5.0, "near": 4.0}))
	_aftermath(host, p, rad, 1.85, {"slits": 3, "chunks": 8})
	_ground(FutonLib.floor_at(p) + Vector3.UP * 0.5, rad * 1.8 * ep, rad * 1.3 * ep)
	Sfx.play("wind", p, 0.6)
	Sfx.play("rasengan", p, 0.7)


# ================================================================== 3. Ōdama Rasenshuriken
## Görünüş (ref: üç klonun başı üstünde tuttuğu, geniş elips beyaz girdap içinde büyük mavi çekirdek): başın 4.5 m üstünde dev
## Rasenshuriken; üç katmanlı bıçak diski + geniş soluk altı kollu hale; çevreden yatay elips üstünde uzun hava çizgileri çekilir,
## vakum diski. Çarpmada basık (geniş, alçak) dev mikro bıçak küresi; içinde yatay dönen kesme halkaları, büyük mavi çekirdek.
static func odama_rasenshuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var tt = pj.tg(c, t, 40.0)
	var over = c.global_position + Vector3.UP * 4.5
	var big = shuriken(pj, 5.2, {"core_r": 0.16, "spin": 6.0, "halo": true})
	FutonLib.put(pj, big, over)
	var fdv: Vector3 = c.face_dir()
	big.global_basis = Basis(fdv.cross(Vector3.UP).normalized(), 0.35)
	big.scale = Vector3.ONE * 0.1
	for i in 10:   # yatay elips üstünden çekilen uzun çizgiler
		var a0 = TAU * i / 10.0
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var a = a0 + u * 2.4
			var r = lerpf(9.0, 0.6, u * u)
			return over + Vector3(cos(a) * r, sin(a * 2.0) * 0.6 * (1.0 - u), sin(a) * r * 0.45), 26)
		FutonLib.line(pj, pts, 0.07, 0.8, WIND, {"delay": i * 0.05, "grow": 0.7, "flow": 6.0})
	FutonLib.warp(pj, over, 5.0, 1.0, 0.8, {"ring": false, "power": -1.8, "swirl": 1.6})
	var tw = big.create_tween()
	tw.tween_property(big, "scale", Vector3.ONE, 0.8)
	tw.tween_callback(func():
		big.queue_free()
		if not pj.live(c):
			return
		var body = shuriken(pj, 4.16, {"core_r": 0.16, "spin": 6.5, "halo": true})
		body.rotation.x = 0.5
		var core_n = Node3D.new()
		core_n.add_child(body)
		var box = {}
		var pr = pj.shot(c, over, pj.aim_at(c, tt, over), 26.0, core_n, pj.inf(c, "odama_rasenshuriken", 2.0, {"knock": 10.0, "kind": "heavy", "element": "fuuton"}), tt, false, 2.0, func(p, _h):
			_odama_burst(pj, p, _ep(box))
			pj.every(1.4, 0.2, func(_i, _k):
				pj.hit(c, p, 9.0, pj.inf(c, "odama_rasenshuriken", 0.5, {"knock": 0.0, "kind": "light", "element": "fuuton", "bleed": 2.0})), Callable())
			pj.shake(1.6))
		box["pr"] = pr
		pr.radius = 1.6
		FutonLib.follow(pj, pr, 1.4, 12, PALE, {"kind": "sheet", "opacity": 0.3, "lines": 5.0, "near": 5.0}))
	Sfx.play("wind", c.global_position, 0.7)


static func _odama_burst(host: Node, p: Vector3, ep: float) -> void:
	var rad = 9.0 * ep
	var flat = Vector3(1.25, 0.72, 1.25)
	dome(host, p, rad, 1.4, {"density": 20.0, "swirl": 1.2, "aspect": flat, "out": 0.5, "near": 7.0})
	dome(host, p, rad * 0.7, 1.35, {"density": 13.0, "swirl": -1.8, "aspect": flat, "cut": 0.55, "tint": PALE, "delay": 0.08, "near": 7.0})
	_core_hold(host, p, clampf(rad * 0.22, 0.8, 3.0), 1.9, BLUE_IN, BLUE_OUT)
	for i in 5:   # yatay dönen kesme halkaları
		var hy = (i - 2) * rad * 0.16
		var rr = rad * 1.2 * sqrt(maxf(0.1, 1.0 - pow(hy / (rad * 0.72), 2.0)))
		var a0 = randf() * TAU
		_later(host, 0.1 + i * 0.05, func():
			FutonLib.line(host, FutonLib.helix_pts(p, Vector3.UP, rr * 0.7, rr, hy, hy, a0, 1.4, 44), 0.12 * ep, 1.3, WIND, {"grow": 0.5, "flow": 12.0, "near": 6.0}))
	FutonLib.warp(host, p, rad * 0.4, rad * 2.0, 0.6, {"power": 2.6, "glint": 0.5, "near": 6.0})
	_aftermath(host, p, rad, 1.7, {"slits": 4, "chunks": 10})
	_ground(FutonLib.floor_at(p) + Vector3.UP * 0.5, rad * 1.8 * ep, rad * 1.3 * ep)
	Sfx.play("wind", p, 0.6)
	Sfx.play("rasengan", p, 0.7)


# ================================================================== 4. Bijūdama Rasenshuriken
## Görünüş (kaynaksız; kanon: kara Bijūdama çekirdeği etrafında rüzgâr bıçakları): kara-mor motlar başın üstünde sıkışır, kara
## çekirdek şişer; atılan gövde kara-mor sarmal çekirdek + soluk leylak bıçak diski, ardında leylak izler. Çarpmada önce içe çöken
## vakum, kara çekirdek patlayıp söner, beyaz ve kara-mor iki mikro bıçak küresi zıt yönde döner, dev basınç halkası.
static func bijudama_rasenshuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 50.0)
	var over = c.global_position + Vector3.UP * 4.0 + c.face_dir()
	FutonLib.bits(pj, over, 40, "grit", {"life": 0.8, "size": 0.12, "radius": 3.4, "radial": -12.0, "tang": 6.0, "vmin": 0.0, "vmax": 0.4, "g": Vector3.ZERO,
		"spread": 180.0, "burst": 0.25, "turb": false, "cols": [Color(0.3, 0.1, 0.4, 0), Color(0.12, 0.04, 0.18, 1), Color(0.5, 0.3, 0.7, 0)]})
	_inspiral(pj, over, 3.0, 6, 0.7, VIOLET, {"w": 0.05, "stagger": 0.07, "flat": 1.0})
	var bd = core(pj, over, 0.05, DARK_IN, DARK_OUT, {"streak": Color(0.7, 0.5, 0.95), "spin": 4.0})
	var bt = bd.create_tween()
	bt.tween_property(bd, "scale", Vector3.ONE * 0.85, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	bt.tween_callback(bd.queue_free)
	pj.after(0.8, func():
		if not pj.live(c):
			return
		var core_n = Node3D.new()
		var body = shuriken(pj, 3.9, {"inner": DARK_IN, "outer": DARK_OUT, "streak": Color(0.75, 0.6, 1.0), "core_r": 0.2, "tint": Color(0.88, 0.86, 1.0, 1.0),
			"rings": Color(0.85, 0.78, 1.0, 0.9), "spin": 8.0})
		body.rotation.x = 0.5
		core_n.add_child(body)
		var box = {}
		var pr = pj.shot(c, over, pj.aim_at(c, tt, over), 20.0, core_n, pj.inf(c, "bijudama_rasenshuriken", 2.4, {"knock": 10.0, "kind": "heavy", "element": "fuuton"}), tt, false, 3.0, func(p, _h):
			_bijuu_burst(pj, p, _ep(box))
			pj.every(1.6, 0.2, func(_i, _k):
				pj.hit(c, p, 11.0, pj.inf(c, "bijudama_rasenshuriken", 0.5, {"knock": 0.0, "kind": "light", "element": "fuuton", "bleed": 2.0})), Callable())
			pj.shake(2.0))
		box["pr"] = pr
		pr.homing_turn = 2.0
		pr.radius = 1.8
		for q in 2:
			FutonLib.follow(pj, pr, 0.07, 16, Color(0.6, 0.45, 0.85, 0.9), {"offset": Vector3(cos(q * PI), sin(q * PI), 0.0) * 1.7, "spin": -9.0, "flow": 7.0}))
	Sfx.play("roar", c.global_position, 0.8)


static func _bijuu_burst(host: Node, p: Vector3, ep: float) -> void:
	FutonLib.warp(host, p, 6.0, 0.8, 0.22, {"ring": false, "power": -2.6, "swirl": 2.4})
	var dk = core(host, p, 0.4, DARK_IN, DARK_OUT, {"streak": Color(0.7, 0.5, 0.95), "spin": 10.0})
	var tw = dk.create_tween()
	tw.tween_interval(0.18)
	tw.tween_property(dk, "scale", Vector3.ONE * 3.4, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(dk, "scale", Vector3.ONE * 0.05, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(dk.queue_free)
	dome(host, p, 10.0 * ep, 1.3, {"density": 17.0, "swirl": 1.8, "delay": 0.2, "out": 0.5, "near": 6.0})
	dome(host, p, 7.5 * ep, 1.25, {"density": 12.0, "swirl": -2.2, "cut": 0.9, "tint": VIOLET, "lift": 0.25, "haze": 0.08, "delay": 0.24, "out": 0.4, "near": 6.0})
	FutonLib.warp(host, p, 2.0, 18.0 * ep, 0.7, {"power": 2.8, "glint": 0.4, "delay": 0.2, "near": 7.0})
	_aftermath(host, p, 11.0 * ep, 1.6, {"slits": 5, "chunks": 12})
	_ground(p, 18.0 * ep, 14.0 * ep)
	Sfx.play("wind", p, 0.5)


# ================================================================== 5. Rikudō: Chōōdama Rasenshuriken
## Görünüş (ref: Altı Yol / Kurama modunda altın çekirdekli dev Rasenshuriken, çevresinde savrulan beyaz rüzgâr halkaları):
## başın üstünde üç eğik altın yörünge halkası daralarak toplanır; altın-beyaz çekirdekli dev disk, çevresinde üç eğik dönen
## yörünge halkası ve altın kuyruklar. Ardından üç küçük altın Rasenshuriken yelpaze olarak atılır. Çarpmada iç içe üç küre
## (altın iç, beyaz orta, seyrek dış), açılan eğik basınç halkaları ve altın motlar.
static func rikudo_chooodama_rasenshuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var id = "rikudo_chooodama_rasenshuriken"
	var s = 2.4
	var mul = 2.6
	var blast_r = 22.0
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 50.0)
	var over = c.global_position + Vector3.UP * (3.0 + s) + c.face_dir() * 0.6
	for i in 3:   # daralan eğik altın yörüngeler
		var ax = Vector3(sin(i * 2.1), 1.6, cos(i * 2.1)).normalized()
		FutonLib.line(pj, FutonLib.helix_pts(over, ax, 7.0, s * 1.2, 0.0, 0.0, i * 1.3, 1.6, 48), 0.08, 0.8, GOLD, {"delay": i * 0.08, "grow": 0.8, "flow": 7.0})
	FutonLib.bits(pj, over, 30, "grit", {"life": 0.8, "size": 0.1, "radius": 4.0, "radial": -10.0, "tang": 10.0, "vmin": 0.0, "vmax": 0.5, "g": Vector3.ZERO,
		"spread": 180.0, "burst": 0.2, "turb": false, "cols": [Color(1, 0.9, 0.5, 0), Color(1, 0.85, 0.35, 1), Color(1, 1, 0.8, 0)]})
	pj.after(0.8, func():
		if not pj.live(c):
			return
		var core_n = Node3D.new()
		var body = shuriken(pj, s * 2.6, {"inner": GOLD_IN, "outer": GOLD_OUT, "streak": Color(1, 1, 0.9), "core_r": 0.15, "rings": GOLD, "spin": 8.0})
		body.rotation.x = 0.5
		core_n.add_child(body)
		_orbit_rings(pj, core_n, s * 1.9, GOLD)
		var box = {}
		var pr = pj.shot(c, over, pj.aim_at(c, tt, over), 20.0, core_n, pj.inf(c, id, mul, {"knock": 8.0, "kind": "heavy", "element": "fuuton"}), tt, false, 3.0, func(p, _h):
			_rikudo_burst(pj, p, blast_r, _ep(box))
			pj.every(1.8, 0.2, func(_i, _k):
				pj.hit(c, p, blast_r * 0.6, pj.inf(c, id, mul * 0.3, {"knock": 0.0, "kind": "light", "element": "fuuton", "bleed": 2.0})), Callable())
			pj.shake(1.8))
		box["pr"] = pr
		pr.homing_turn = 2.0
		pr.radius = s * 1.2
		for tc in [Color(1.0, 0.85, 0.4, 0.8), Color(1.0, 0.95, 0.7, 0.8)]:   # bıçakların arkasında altın kuyruklar
			var off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * s * 1.6
			FutonLib.follow(pj, pr, 0.5 * s, 14, tc, {"kind": "sheet", "opacity": 0.45, "lines": 3.0, "offset": off, "near": 4.0}))
	Sfx.play("rasengan", c.global_position, 0.9)
	# Altı Yol: ardından üç küçük Rasenshuriken
	for k in 3:
		pj.after(0.9 + k * 0.15, func():
			if pj.live(c):
				var tt2 = pj.tg(c, t, 50.0)
				var from = c.global_position + Vector3.UP * 3.0 + c.face_dir().rotated(Vector3.UP, (k - 1) * 0.8) * 2.0
				var mini = shuriken(pj, 1.56, {"inner": GOLD_IN, "outer": GOLD_OUT, "rings": GOLD, "spin": 12.0})
				mini.rotation.x = 0.5
				var box2 = {}
				var pr2 = pj.shot(c, from, pj.aim_at(c, tt2, from), 24.0, mini, pj.inf(c, id, 0.6, {"knock": 6.0, "kind": "heavy", "element": "fuuton"}), tt2, false, 2.6, func(p, _h):
					var e2 = _ep(box2)
					dome(pj, p, 3.0 * e2, 0.3, {"density": 10.0, "swirl": 2.4, "tint": Color(1.0, 0.94, 0.75, 0.95), "out": 0.4})
					FutonLib.warp(pj, p, 0.5, 6.0 * e2, 0.4, {"power": 1.8, "glint": 0.6})
					GroundFX.wind(p, 6.0 * e2))
				box2["pr"] = pr2
				pr2.homing_turn = 3.0
				FutonLib.follow(pj, pr2, 0.04, 12, GOLD, {"offset": Vector3(0.8, 0, 0), "spin": 14.0}))


## Eğik dönen yörünge halkaları (parent'a bağlı, her biri kendi hızında döner)
static func _orbit_rings(host: Node, parent: Node3D, r: float, col: Color) -> void:
	for i in 3:
		var h = Node3D.new()
		parent.add_child(h)
		h.rotation = Vector3(0.5 + i * 1.05, i * 0.9, 0.3 * i)
		FutonLib.fixed(host, FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, r, r, 0.0, 0.0, 0.0, 0.72, 36), r * 0.02, "line", col,
			{"parent": h, "hint": Vector3.UP, "twin": false, "flow": 10.0})
		var tw = Game.safe_loops(h.create_tween())
		tw.tween_property(h, "rotation:y", TAU, 0.7 + i * 0.25).as_relative()


static func _rikudo_burst(host: Node, p: Vector3, blast_r: float, ep: float) -> void:
	var rad = blast_r * 0.6 * ep
	dome(host, p, rad * 0.55, 1.8, {"density": 14.0, "swirl": 2.2, "tint": GOLD, "lift": 0.6, "out": 0.4, "near": 6.0})
	dome(host, p, rad * 0.85, 1.75, {"density": 18.0, "swirl": -1.4, "delay": 0.08, "out": 0.5, "near": 7.0})
	dome(host, p, rad, 1.7, {"density": 24.0, "swirl": 1.0, "cut": 0.55, "tint": PALE, "haze": 0.03, "delay": 0.16, "out": 0.6, "near": 8.0})
	_core_hold(host, p, clampf(rad * 0.16, 0.8, 3.0), 2.3, GOLD_IN, GOLD_OUT, {"streak": Color(1, 1, 0.9)})
	for i in 3:   # açılan eğik basınç halkaları
		var nb = Basis(Vector3(sin(i * 2.1), 0.0, cos(i * 2.1)).normalized(), 0.5 + i * 0.35) * FutonLib.flat_basis()
		FutonLib.warp(host, p, rad * 0.2, rad * 1.5, 0.7, {"bill": false, "basis": nb, "power": 2.4, "glint": 0.6, "delay": i * 0.1, "near": 8.0})
	FutonLib.bits(host, p, 90, "grit", {"life": 1.3, "size": 0.16, "radius": rad * 0.4, "vmin": 8.0, "vmax": 20.0, "spread": 180.0, "tang": 30.0, "damp": 2.0,
		"g": Vector3.ZERO, "turb": false, "burst": 0.75, "cols": [Color(1, 1, 0.85, 0), Color(1, 0.88, 0.45, 1), Color(1, 0.95, 0.7, 0)]})
	_aftermath(host, p, rad, 2.1, {"slits": 5, "chunks": 12})
	_ground(FutonLib.floor_at(p) + Vector3.UP * 0.5, rad * 1.8 * ep, rad * 1.3 * ep)
	Sfx.play("wind", p, 0.6)
	Sfx.play("rasengan", p, 0.7)


# ================================================================== 6. Oyako Rasengan
## Görünüş (ref: iki el arasında dev soluk mavi küre, ortası bembeyaz, yüzeyi ince iplik dokulu, çevresine ışınsal kıvılcım
## çizgileri; şuriken değil Rasengan): yanında ebeveyn klon belirir; iki elden çizgiler aradaki küreye akar, küre şişer,
## yüzeyinde sık iplik bıçaklar döner, dışa ince ışınlar fışkırır. Hedefe itilince öğütür: dışa açılan sarmal oyuk çizgileri,
## basınç halkası, yerde ışınsal oyuk ve yarıklar.
static func oyako_rasengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.4)
	var d = pj._face(c, tt)
	var side = d.cross(Vector3.UP).normalized()
	# ebeveyn gölge klon belirir (küçük klon pufu)
	FutonLib.bits(pj, c.global_position + side * 0.9 + Vector3.UP, 6, "puff", {"life": 0.45, "size": 0.7, "radius": 0.4, "vmin": 1.0, "vmax": 2.5, "spread": 180.0,
		"g": Vector3.ZERO, "grow": [0.6, 1.4], "cols": [Color(1, 1, 1, 0), Color(0.95, 0.97, 1.0, 0.8), Color(1, 1, 1, 0)]})
	var ras = Node3D.new()
	FutonLib.put(pj, ras, c.global_position + Vector3.UP * 1.1 + d * 0.9 + side * 0.45)
	core(pj, Vector3.ZERO, 0.3, Color(0.98, 1.0, 1.0, 1.0), Color(0.52, 0.76, 1.0, 1.0), {"parent": ras, "spin": 10.0, "streak": Color(0.85, 0.95, 1.0)})
	needles(pj, Vector3.ZERO, 0.33, {"parent": ras, "density": 22.0, "swirl": 3.0, "cut": 0.5, "tint": Color(0.8, 0.92, 1.0, 0.9), "haze": 0.12, "near": 2.6})
	ras.create_tween().tween_property(ras, "scale", Vector3.ONE * 4.0, 0.7).set_trans(Tween.TRANS_QUAD)
	pj.every(0.75, 0.08, func(i, k):
		if not is_instance_valid(ras) or not pj.live(c):
			return
		var cp = ras.global_position
		var rr = 0.33 * ras.scale.x
		if i % 2 == 0:   # iki elden aradaki küreye akan çizgiler
			for hs in [true, false]:
				var hp = pj.hand_pos(c, hs)
				FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
					return hp.lerp(cp, u) + Vector3.UP * sin(u * PI) * 0.25, 10), 0.03, 0.25, PALE, {"grow": 0.8, "flow": 8.0, "near": 1.5})
		for q in 3:   # dışa fışkıran ince ışınlar
			var dir = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
			FutonLib.line(pj, PackedVector3Array([cp + dir * rr * 1.05, cp + dir * rr * (1.5 + k)]), 0.025, 0.2, WIND, {"grow": 0.5, "flow": 10.0, "near": 1.5}), Callable())
	pj.after(0.8, func():
		if not pj.live(c):
			ras.queue_free()
			return
		var from = ras.global_position
		var dest = (tt.global_position + Vector3.UP if is_instance_valid(tt) else from + d * 10.0)
		FutonLib.follow(pj, ras, 0.6, 10, PALE, {"kind": "sheet", "opacity": 0.4, "lines": 3.0, "near": 2.0})
		var tw = ras.create_tween()
		tw.tween_property(ras, "global_position", dest, 0.25)
		tw.tween_callback(func():
			pj.hit(c, dest, 3.5, pj.inf(c, "oyako_rasengan", 2.6, {"knock": 24.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.12}))
			_oyako_grind(pj, dest, (dest - from).normalized())
			_ground(dest, 5.0, 3.5)
			pj.shake(0.7))
		tw.tween_property(ras, "scale", Vector3.ONE * 0.05, 0.25)
		tw.tween_callback(ras.queue_free))
	Sfx.play("rasengan", c.global_position, 0.8)


static func _oyako_grind(host: Node, p: Vector3, d: Vector3) -> void:
	var ax = d if d.length() > 0.1 else Vector3.FORWARD
	for i in 8:   # öğüten sarmal oyuk çizgileri (itme ekseni etrafında dışa açılır)
		FutonLib.line(host, FutonLib.helix_pts(p, ax, 0.8, 4.5, 0.0, 2.5, TAU * i / 8.0, 0.8, 24), 0.07, 0.45, WIND, {"delay": i * 0.015, "grow": 0.6, "flow": 10.0})
	FutonLib.warp(host, p, 0.6, 6.0, 0.45, {"power": 2.4, "glint": 0.6})
	FutonLib.warp(host, p, 1.2, 0.2, 0.3, {"ring": false, "power": -1.6, "swirl": 2.6, "delay": 0.05})
	var g = FutonLib.floor_at(p)
	if p.y - g.y < 4.0:
		FutonLib.scour(host, g, ax, 7.0, 7.0, 4.0, 1)
		FutonLib.scour(host, g, ax, 4.0, 4.0, 4.5, 2)
		FutonLib.chunks(host, g, 5, 7.0, FutonLib.ground_col(g).darkened(0.35), 0.28, ax + Vector3.UP)
		FutonLib.bits(host, g + Vector3.UP * 0.3, 18, "grit", {"life": 0.9, "size": 0.12, "radius": 1.0, "tang": 16.0, "dir": Vector3.UP, "spread": 60.0,
			"vmin": 3.0, "vmax": 7.0, "spin": 700.0, "g": Vector3(0, -9, 0), "turb": false, "cols": [Color(0.5, 0.45, 0.4, 1), Color(0.45, 0.4, 0.35, 1), Color(0.45, 0.4, 0.35, 0)]})


# ================================================================== 7. Fūton: Rasenrenshuriken
## Görünüş (ref: iki elde birer Rasenshuriken; biri yakında kılıç gibi keser, sonra ikisi ard arda fırlatılır): iki elde ayrı
## tonlu (beyaz / hafif turkuaz) iki küçük disk; yakın savuruşta geniş yatay kesik hilali + kavisli kesme çizgileri. Her mermi
## çarpınca daha küçük küre açar ve ekvatorundan dışa testere gibi dönen hilal bıçaklar fırlar.
static func futon_rasenrenshuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 34.0)
	pj.busy(c, 1.3)
	pj.anim(c, "cast", 0.9)
	var tints = [Color(0.88, 0.95, 1.0, 1.0), Color(0.8, 1.0, 0.96, 1.0)]
	var bodies = []
	for k in 2:
		var b = shuriken(pj, 2.4, {"tint": tints[k], "spin": 11.0})
		FutonLib.put(pj, b, pj.hand_pos(c, k == 0) + Vector3.UP * 0.6)
		bodies.append(b)
	pj.every(0.7, 1.0 / 30.0, func(_i, _k):
		for k in 2:
			if pj.live(c) and is_instance_valid(bodies[k]):
				bodies[k].global_position = pj.hand_pos(c, k == 0) + Vector3.UP * 0.7 + c.face_dir() * 0.3, Callable())
	Sfx.play("wind", c.global_position, 0.6)
	# 1) yakında savuruş: soldaki kılıç gibi keser
	pj.after(0.45, func():
		if pj.live(c):
			pj.anim(c, "slash_c", 1.3)
			var at = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 2.2
			_ren_slash(pj, at, c.face_dir())
			GroundFX.wind(at, 2.6)
			pj.hit(c, at, 2.6, pj.inf(c, "futon_rasenrenshuriken", 0.6, {"knock": 8.0, "kind": "heavy", "bleed": 3.0})))
	# 2) ikisi ard arda fırlatılır
	for k in 2:
		pj.after(0.75 + k * 0.25, func():
			if not pj.live(c) or not is_instance_valid(bodies[k]):
				return
			var b = bodies[k]
			var from = b.global_position
			b.queue_free()
			var body = shuriken(pj, 2.4, {"tint": tints[k], "spin": 11.0})
			body.rotation.x = 0.4
			var box = {}
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 30.0, body, pj.inf(c, "futon_rasenrenshuriken", 0.2, {"knock": 2.0, "kind": "light"}), tt, false, 2.0, func(p, _h):
				if is_instance_valid(c):
					_ren_burst(pj, c, p, pj._mult_of(c) * 0.9, _ep(box), tints[k]))
			box["pr"] = pr
			FutonLib.follow(pj, pr, 0.04, 14, tints[k], {"offset": Vector3(1.1, 0, 0), "spin": 13.0, "flow": 9.0})
			Sfx.play("whoosh", from, 0.8))


static func _ren_slash(host: Node, at: Vector3, fd: Vector3) -> void:
	var sd = FutonLib.side_of(fd)
	FutonLib.blade(host, at, FutonLib.blade_basis(fd, Vector3.UP), 4.6, 0.35, WIND, {"thick": 0.22, "jag": 0.6, "wisp": 1.4, "vel": fd * 6.0})
	for i in 5:   # kavisli kesme çizgileri (savuruş yayı)
		var h = (i - 2) * 0.18
		FutonLib.line(host, FutonLib.path_pts(func(u: float) -> Vector3:
			var a = lerpf(-1.2, 1.2, u)
			return at - fd * 1.4 + (fd * cos(a) + sd * sin(a)) * (2.0 + i * 0.12) + Vector3.UP * h, 18), 0.04, 0.3, WIND, {"delay": i * 0.02, "grow": 0.7, "flow": 10.0})
	FutonLib.warp(host, at, 0.4, 2.8, 0.3, {"power": 1.6})


static func _ren_burst(host: Node, c: Node3D, p: Vector3, m: float, ep: float, tint: Color) -> void:
	var rad = 6.5 * ep
	dome(host, p, rad, 1.0, {"density": 14.0, "swirl": 2.2, "tint": tint, "out": 0.5})
	_core_hold(host, p, clampf(rad * 0.16, 0.5, 2.0), 1.5, BLUE_IN, BLUE_OUT)
	for i in 6:   # ekvatordan dışa dönen testere hilalleri
		var a = TAU * i / 6.0 + randf() * 0.3
		var out = Vector3(cos(a), 0.0, sin(a))
		var tg = out.cross(Vector3.UP)
		FutonLib.blade(host, p + out * rad * 0.5, FutonLib.blade_basis(tg, Vector3.UP), rad * 0.45, 0.6, tint,
			{"thick": 0.2, "jag": 0.8, "wisp": 1.2, "vel": out * rad * 1.1, "spin": 6.0, "delay": 0.1 + i * 0.03})
	FutonLib.warp(host, p, rad * 0.3, rad * 1.5, 0.45, {"power": 2.0, "glint": 0.5})
	_aftermath(host, p, rad, 1.25, {"slits": 3, "chunks": 6})
	_ground(FutonLib.floor_at(p) + Vector3.UP * 0.5, rad * 1.8 * ep, rad * 1.3 * ep)
	Sfx.play("wind", p, 0.6)
	Sfx.play("rasengan", p, 0.7)
	if Game.world:
		Game.world.env.add_shake(1.0)
	_cut_ticks(host, c, p, rad, m)


# ================================================================== 8. Bashōsen: Kaze no Maki
## Görünüş (ref: yelpaze savruluşunda turkuaz hava üstünde uzun, ince, kıvrık beyaz çizgiler ve geniş soluk perdeler): yelpaze
## elde açılır, tüylerinden kısa hava kıvrımları kopar; savuruşta ileri yelpazelenen uzun kıvrık çizgiler + geniş perde. Ardından
## ileri yürüyen sarmal sargı (Coil of Wind): tabanda dar hızlı sarmal, üstte geniş yavaş perde sarmalı, yükselen uzun çizgiler,
## tabanda dönen toz/yaprak; geçtiği yolda süpürülmüş toz izi.
static func bashosen_kaze_no_maki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	_fan(pj, c)
	pj.after(0.35, func():
		var tor = Node3D.new()   # hortumun görünmez merkezi
		var start = pj.gp(c.global_position + d * 4.0)
		pj.scene_add(tor, start + Vector3.UP * 13.0)
		_fan_gust(pj, c.global_position + Vector3.UP * 1.2, d)
		FutonLib.scour(pj, start, d, 42.0, 8.0, 4.5, 0, Color(-1, 0, 0), {"grow_t": 3.0})
		Sfx.play("wind", start, 0.6)
		pj.shake(0.6)
		var hits = {}
		var tint = Color(0.86, 1.0, 0.97, 0.95)
		pj.every(3.0, 1.0 / 30.0, func(i, k):
			if not is_instance_valid(tor):
				return
			var p = pj.gp(start + d * (k * 42.0)) + Vector3.UP * 13.0
			tor.global_position = p
			tor.rotate_y(0.6)
			var base = p - Vector3.UP * 12.0
			if i % 4 == 0:   # gövde: dar hızlı alt sarmal + geniş yavaş üst perde sarmalı
				var a0 = i * 0.6
				FutonLib.line(pj, FutonLib.helix_pts(base, Vector3.UP, 2.0, 3.6, 0.3, 9.0, a0, 2.4, 40), 0.08, 0.45, tint, {"grow": 0.6, "flow": 9.0, "near": 3.0})
				FutonLib.sheet(pj, FutonLib.helix_pts(base, Vector3.UP, 4.2, 6.8, 4.0, 15.0, a0 + PI, 1.0, 26), 0.9, 0.6, Color(0.8, 0.95, 1.0, 0.9),
					{"grow": 0.6, "opacity": 0.35, "lines": 3.0, "flow": 4.0, "near": 6.0})
			if i % 6 == 0:   # tabandan yükselen uzun kıvrık çizgiler
				var ph = randf() * TAU
				FutonLib.line(pj, FutonLib.path_pts(func(q: float) -> Vector3:
					return base + Vector3(cos(ph + q * 7.0) * (2.0 + q * 4.0), q * 16.0, sin(ph + q * 7.0) * (2.0 + q * 4.0)), 28), 0.11, 0.7, WIND, {"grow": 0.5, "flow": 7.0, "near": 4.0})
			if i % 10 == 0:   # tabanda dönen toz + yaprak
				FutonLib.bits(pj, base + Vector3.UP * 0.4, 8, "puff", {"life": 1.2, "size": 1.6, "radius": 2.5, "vmin": 1.0, "vmax": 3.0, "dir": Vector3.UP, "spread": 40.0,
					"tang": 14.0, "g": Vector3(0, 2.0, 0), "damp": 0.8, "grow": [0.6, 1.4], "spin": 40.0, "burst": 0.4, "cols": FutonLib.dust_cols(base, 0.7)})
				if FutonLib.has_leaves(base):
					FutonLib.bits(pj, base + Vector3.UP * 0.5, 8, "leaf", {"life": 1.6, "size": 0.2, "radius": 2.5, "vmin": 2.0, "vmax": 5.0, "dir": Vector3.UP, "spread": 30.0,
						"tang": 18.0, "g": Vector3(0, 4.0, 0), "damp": 0.5, "spin": 500.0, "burst": 0.3, "cols": FutonLib.leaf_cols(base)})
			for e in pj.enemies_near(c, base, 6.5):
				if pj.live(e):
					e.global_position = e.global_position.lerp(base + Vector3.UP * minf(10.0, 2.0 + hits.get(e, 0) * 0.4), 0.15)
					hits[e] = hits.get(e, 0) + 1
					if hits[e] % 6 == 1:
						pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.6, pj.inf(c, "bashosen_kaze_no_maki", 0.35, {"element": "fuuton", "knock": 4.0, "launch": 4.0, "kind": "heavy"})), func():
			if is_instance_valid(tor):
				pj.fade_free(tor, 0.0, 0.4)))


## Bashōsen (kuşanılan silah modeli) elde açılır; sırttaki gizlenir, chakra emilir (bashosen_fan'ın oynanışı birebir).
## Savuruşta tüylerden kısa hava kıvrımları kopar.
static func _fan(pj: PathJutsu, c: Node3D) -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = CharacterModel.weapon_mesh("bashosen")
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	pj.after(0.2, func():
		if is_instance_valid(root):
			var fp = root.global_position + Vector3.UP * 0.8
			for i in 5:
				var a0 = randf() * TAU
				FutonLib.line(pj, FutonLib.helix_pts(fp, Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5)), 0.2, 0.9, 0.0, 1.2, a0, 0.6, 12), 0.03, 0.4,
					Color(0.85, 1.0, 0.95, 0.9), {"delay": i * 0.03, "grow": 0.6, "flow": 8.0, "near": 1.5}))
	var md = c.get("model")
	var hidden = []
	if md and "weapons" in md:
		for w in md.weapons:
			if String(w.get("id", "")) == "bashosen" and is_instance_valid(w["node"]) and w["node"].visible:
				w["node"].visible = false
				hidden.append(w["node"])
	pj.after(1.9, func():
		for n in hidden:
			if is_instance_valid(n):
				n.visible = true)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(root)
		root.rotation_degrees = Vector3(-90, 0, 0)
	else:
		pj.scene_add(root, pj.hand_pos(c, true))
	root.scale = Vector3.ONE * 0.05
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(ba):
			ba.queue_free()
		elif is_instance_valid(root):
			root.queue_free())
	if c is Player:
		c.chakra = maxf(0.0, c.chakra - c.max_chakra * 0.15)
		Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Bashōsen chakranı emiyor!", Color(0.95, 0.85, 0.5))
	pj.busy(c, 1.1)
	pj.anim(c, "slash_a", 1.0)
	return root


## Yelpaze savuruşu: ileri yelpazelenen uzun kıvrık ince çizgiler + iki geniş soluk perde
static func _fan_gust(host: Node, o: Vector3, d: Vector3) -> void:
	var sd = FutonLib.side_of(d)
	for i in 12:
		var lat = randf_range(-1.0, 1.0)
		var cv = randf_range(-1.0, 1.0)
		var hy = randf_range(-0.6, 1.6)
		var ln = randf_range(13.0, 18.0)
		FutonLib.line(host, FutonLib.path_pts(func(u: float) -> Vector3:
			return o + d * (u * ln) + sd * (lat * u * 4.0 + cv * sin(u * PI) * 1.6) + Vector3.UP * (hy * u + sin(u * 5.0 + cv) * 0.3), 22), randf_range(0.04, 0.08), 0.6, WIND, {"delay": i * 0.02, "grow": 0.55, "flow": 9.0, "near": 2.5})
	for q in 2:
		var s = 1.0 if q == 0 else -1.0
		FutonLib.sheet(host, FutonLib.path_pts(func(u: float) -> Vector3:
			return o + d * (u * 16.0) + sd * s * sin(u * PI) * 2.0 + Vector3.UP * (0.4 + u * 0.8), 20), 2.2, 0.65, Color(0.75, 0.95, 1.0, 0.9), {"delay": 0.05 + q * 0.05, "grow": 0.5, "opacity": 0.4, "lines": 4.0, "near": 4.0})


# ================================================================== 9. Senpō: Fūton Sajin
## Görünüş (kaynaksız; kanon: doğa enerjili kum-toz fırtınası, görüşü kapatır): ağızdan dört dalga hâlinde ileri yuvarlanan iki
## tonlu kum-toz duvarı (büyüyerek ilerleyen topaklar), içinde hızlı çakıl ve alçak kum perdesi; ekseni etrafında turuncu-altın
## sennin sarmalları kıvrılır; yerde 26 m süpürülmüş kum izi.
static func senpo_futon_sajin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	for k in 4:
		pj.after(k * 0.12, func():
			if not pj.live(c):
				return
			var o = c.global_position + Vector3.UP * (0.8 + k * 0.3)
			_sand_wave(pj, o, d, k))
	pj.every(1.2, 0.2, func(_i, k):
		var q = c.global_position + d * (4.0 + k * 18.0)
		for e in pj.enemies_near(c, q, 6.0):
			if pj.live(e):
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.5, pj.inf(c, "senpo_futon_sajin", 0.35, {"knock": 8.0, "launch": 2.0, "kind": "heavy", "element": "fuuton"}))
				if e.has_method("lose_target"):
					e.lose_target(3.0)
				if e.has_method("apply_status"):
					e.apply_status("slow", 3.0), Callable())
	pj.shake(0.7)
	Sfx.play("wind", c.global_position, 0.6)


static func _sand_wave(host: Node, o: Vector3, d: Vector3, k: int) -> void:
	var sand = SAND
	var sc = [Color(sand.r, sand.g, sand.b, 0.0), Color(sand.r, sand.g, sand.b, 0.85), Color(sand.r * 0.9, sand.g * 0.88, sand.b * 0.85, 0.7), Color(sand.r, sand.g, sand.b, 0.0)]
	# yuvarlanan kum-toz duvarı
	FutonLib.bits(host, o + d * 1.0, 14, "puff", {"life": 1.3, "size": 2.0, "radius": 1.2, "dir": d, "spread": 18.0, "vmin": 14.0, "vmax": 22.0, "damp": 1.2,
		"g": Vector3(0, -0.3, 0), "grow": [0.5, 2.4], "spin": 50.0, "burst": 0.7, "cols": sc})
	FutonLib.bits(host, o + d * 1.0, 18, "grit", {"life": 1.0, "size": 0.1, "radius": 0.8, "dir": d, "spread": 14.0, "vmin": 20.0, "vmax": 28.0, "damp": 0.5,
		"g": Vector3(0, -3.0, 0), "spin": 700.0, "turb": false, "burst": 0.6, "cols": [sand.darkened(0.3), sand.darkened(0.4), Color(sand.r, sand.g, sand.b, 0.0)]})
	var sd = FutonLib.side_of(d)
	FutonLib.sheet(host, FutonLib.path_pts(func(u: float) -> Vector3:
		return o + d * (1.0 + u * 23.0) + sd * sin(u * 4.0 + k) * 0.8 - Vector3.UP * (0.4 + u * 0.3), 22), 3.4, 1.0, sand, {"grow": 0.6, "opacity": 0.5, "lines": 3.0, "flow": 5.0, "near": 4.0})
	if k % 2 == 0:   # sennin sarmalları
		for q in 2:
			FutonLib.line(host, FutonLib.helix_pts(o + d * 1.0, d, 1.0, 3.6, 0.0, 22.0, q * PI + k, 2.2, 44), 0.06, 1.0, SAGE, {"grow": 0.6, "flow": 6.0, "near": 2.5})
	if k == 0:
		FutonLib.scour(host, FutonLib.floor_at(o), d, 26.0, 10.0, 4.0, 0, Color(sand.r * 0.82, sand.g * 0.8, sand.b * 0.78, 0.7), {"grow_t": 1.0})
