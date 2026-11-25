class_name ArcaneFX
extends RefCounted
## Gizem / yasak teknik / algılama grubu: 15 tekniğin KENDİ görselleri + ana ağaçtan satır satır taşınan oynanış.
## Hazır / ortak efekt yardımcısı yok. Kendi gölgelendiricileri: yumuşak cel bulut (koyu kenarlı toz / chakra dili),
## hız çizgisi, kameraya dönük şerit (iplik, sargı, ruh akışı), zemin katmanı (dalga halkası / leke / ağ / mühür halkası),
## su-kristal küre (kenar bandı, parıltı, iç halkalar, içinde uzak görüntü), toon katı + mürekkep kontur, hayalet kopya.
## Kendi parçacık (MultiMesh) / yörünge / şerit / çatlak düzeneği (Ticker).
##  · omote_renge: hız çizgileri, fırlatış tozu, arkada beliren kalıntı gölge, önkollardan çözülüp uçan iki yassı sargı bandı
##    (kaotik halkalar → sıkı sarım, kolları bedene bağlar), arkadan kavrayıp başaşağı dönüş, sarmal hız çizgileriyle matkap dalışı, krater (çatlak, moloz, toz halkası, kalıcı çukur izi)
##  · izanami: hasar yok; kurbanın çevresinde dönen kuzgunlar, düşen kara tüyler, soğuk çivit gölge, geriye dönen üç tomoe,
##    her döngüde donmuş ak an kopyası; atanın gözü kapanır (kan izi). Döngü kırılınca kopyalar ak pul, kuzgunlar tüy olur
##  · gedo_rinne_tensei: zeminde Rinnegan halkaları, Cehennem Kralı toz bulutları arasında yerden yükselir, çenesi açılır,
##    ağzından göğe yeşil ruh sağanağı, ruhlar yay çizip bedenlere iner; atandan kül rengi yaşam tülleri; yerde yarık
##  · hebi_bunshin: atan yılan gibi kıvrılan bir oyuk izi bırakıp geri kayar; klon patlayınca kıvrık beyaz yılan yığınına
##    çöker, beyaz yılanlar sinüs çizerek düşmanlara sürünüp ısırır (zehir damlası)
##  · sennyu: bedenin donmuş kopyası yüzeye gömülür (dalga halkaları), yer altında ilerleyen tümsek, hedefin yanında
##    kopya yüzeyden yükselir, çıkış darbesi
##  · chakura_kyuin: hedefin bedeninden kopan mavi chakra alev dilleri avuca emilir, üç kollu dalgalı akış, avuçta girdap
##  · iwa_hachinosu: delikli mor-kahve kaya kovanı (dibinde mağara, içinde atan larva) yerden çıkar; çevresinde arılar,
##    deliklerden arı fışkırır, rakiplerden deliklere chakra akar; batınca moloz
##  · sanbo_kyukai: parmaklardan kuklalara titreşen chakra ipleri, yerde üçgen bağ, kukla göğüslerinde dönen havalandırma,
##    pembe-bej emme girdabı + çekilen toz / taş, ezişte arkadan moloz ve toz savrulması
##  · algılama (hepsi Combat.start_sensing):
##    sensa_kaibyo: atılan kum topu havada dağılır, taneler yere dev kedi yüzü resmi çizer; algılanan rakip ayağında kum
##    saiko_denshin: avuçtan en yakın zihne uzanan iplik, iplikten geri akan anı pulları; zihinlerde ak küre
##    kanchi_suikyu: yerden avuca sarmal su damlaları, avuçta halkalı su küresi, zeminde su dalgası; rakip ayağında halka
##    tomegane: önde ayaklı kristal küre; içinde en yakın rakibin GERÇEK uzak görüntüsü; parıltı, bakış çizgisi
##    kanchi_denden: atandan yükselen ak zihin silueti, takım arkadaşlarına iplik + aktarım boncukları; rakipte sarkaç
##    jogan_kanpa: gözde mavi-ak çakım, çevrede uzayın cam gibi çatlaması, rakip bedenlerinde zayıf noktalar
##    hijutsu_mushiyose: avuçta mavi chakra, zeminde ağ açılır, uğur böceği / tırtıl / kurtçuk / böcek / güve toplanır

const BAND := Color(0.95, 0.94, 0.9)
const DUST := Color(0.72, 0.64, 0.52)
const DUST_D := Color(0.38, 0.31, 0.25)
const EARTH := Color(0.5, 0.4, 0.31)
const INK := Color(0.06, 0.05, 0.07)
const SOUL := Color(0.42, 1.0, 0.72)
const SNAKE_W := Color(0.9, 0.88, 0.93)
const SNAKE_B := Color(0.8, 0.76, 0.68)
const CHAKRA := Color(0.45, 0.72, 1.0)
const SAND := Color(0.83, 0.68, 0.46)
const SAND_D := Color(0.6, 0.42, 0.3)
const MIND := Color(0.93, 0.92, 1.0)
const LILAC := Color(0.72, 0.62, 0.95)
const WATER := Color(0.5, 0.76, 0.97)
const JOGAN := Color(0.55, 0.8, 1.0)
const STRINGC := Color(0.95, 0.8, 0.52)
const HIVE := Color(0.44, 0.25, 0.3)
const TEAL := Color(0.12, 0.22, 0.26)

static var _shaders := {}
static var _cache := {}


# ═════════════════════════════════════════ gölgelendiriciler ═════════════════════════════════════════

const SH_NOISE := """
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

## Yumuşak cel leke (kameraya dönük dörtgen): gürültülü kenar, isteğe bağlı koyu kontur halkası (toz bulutu / alev dili)
const SH_SOFT := """
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 rim_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim_amt = 0.0;
uniform float wob = 0.35;
uniform float hard = 0.5;
varying float seed;
void vertex() { seed = float(INSTANCE_ID) * 0.731; }
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float n = n2(q * 2.2 + vec2(seed, seed * 1.7));
	float r = 1.0 - wob * n;
	float sf = mix(0.45, 0.04, hard);
	float body = 1.0 - smoothstep(r - sf, r, d);
	if (body < 0.01) { discard; }
	float rim = smoothstep(r - 0.3, r - 0.18, d) * rim_amt;
	ALBEDO = mix(COLOR.rgb * tint.rgb, rim_col.rgb, rim);
	ALPHA = body * COLOR.a * tint.a;
}
"""

## Hız çizgisi / sağanak çizgisi: UV.x boyunca kuyruğu incelen sert kenarlı çubuk
const SH_STREAK := """
uniform vec4 tint : source_color = vec4(1.0);
uniform float hard = 0.7;
void fragment() {
	float v = abs(UV.y * 2.0 - 1.0);
	float body = 1.0 - smoothstep(hard, 1.0, v);
	float len = smoothstep(0.0, 0.55, UV.x) * (1.0 - smoothstep(0.9, 1.0, UV.x));
	float a = body * len * COLOR.a * tint.a;
	if (a < 0.01) { discard; }
	ALBEDO = COLOR.rgb * tint.rgb;
	ALPHA = a;
}
"""

## Şerit: ortası core_col, kenarı rim_col (cel bant); isteğe bağlı akan kesikler
const SH_STRIP := """
uniform vec4 core_col : source_color = vec4(1.0);
uniform vec4 rim_col : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float core_w = 0.45;
uniform float dash = 0.0;
uniform float flow = 0.0;
void fragment() {
	float v = abs(UV.y * 2.0 - 1.0);
	float inner = step(v, core_w);
	vec4 c = mix(rim_col, core_col, inner);
	float a = c.a * COLOR.a * (1.0 - smoothstep(0.86, 1.0, v));
	if (dash > 0.0) { a *= step(fract(UV.x * dash - TIME * flow), 0.62); }
	if (a < 0.01) { discard; }
	ALBEDO = c.rgb;
	ALPHA = a;
}
"""

## Zemin katmanı (yatay düzlem, UV 0..1): 0 dalga halkaları, 1 gürültü kenarlı leke, 2 ağ (ışınsal tel + çokgen halka),
## 3 mühür halkaları (içe akan eşit aralıklı ince halkalar)
const SH_GROUND := """
uniform int mode = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 tint2 : source_color = vec4(1.0);
uniform float prog = 0.0;
uniform float fade = 1.0;
uniform float rings = 3.0;
uniform float width = 0.02;
uniform float spokes = 10.0;
uniform float seed = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	if (d > 1.0) { discard; }
	float ang = atan(q.y, q.x);
	float a = 0.0;
	vec3 col = tint.rgb;
	if (mode == 0) {
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			if (fi >= rings) { break; }
			float rr = prog - fi * 0.16;
			if (rr <= 0.0) { continue; }
			float w = width * (1.2 - rr * 0.6);
			a = max(a, step(abs(d - rr), w) * (1.0 - rr * 0.7));
		}
	} else if (mode == 1) {
		float n = n2(q * 3.0 + vec2(seed)) * 0.35 + n2(q * 9.0 - vec2(seed)) * 0.15;
		float edge = prog * (0.75 + n);
		a = step(d, edge);
		col = mix(tint.rgb, tint2.rgb, step(edge - 0.12, d));
	} else if (mode == 2) {
		float sect = TAU / spokes;
		float am = mod(ang + sect * 0.5, sect) - sect * 0.5;
		float spoke = step(abs(sin(am)) * d, width);
		float dp = d * cos(am);
		float rg = step(abs(fract(dp * rings) - 0.5), width * rings * 0.8) * step(0.08, d);
		a = max(spoke, rg) * step(d, prog) * (1.0 - d * 0.45);
		col = mix(tint.rgb, tint2.rgb, smoothstep(prog - 0.15, prog, d));
	} else {
		float rr = fract(d * rings + TIME * 0.35);
		a = step(abs(rr - 0.5), width * rings) * step(d, prog) * step(0.06, d);
		col = mix(tint.rgb, tint2.rgb, d);
	}
	a *= fade * tint.a;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Su / kristal küre: cel kenar bandı, iki parıltı lekesi, içe akan halkalar, iç girdap, içinde görüntü (view_tex)
const SH_BUBBLE := """
uniform vec4 tint : source_color = vec4(0.5, 0.75, 1.0, 0.35);
uniform vec4 rim_col : source_color = vec4(0.85, 0.95, 1.0, 0.9);
uniform float rings_amt = 0.0;
uniform float swirl_amt = 0.0;
uniform float view_amt = 0.0;
uniform float fade = 1.0;
uniform sampler2D view_tex : source_color, hint_default_black;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = step(0.7, f);
	vec2 hn = NORMAL.xy;
	float rd = length(hn);
	float hl = 1.0 - step(0.16, length(hn - vec2(-0.32, 0.42)));
	float hl2 = 1.0 - step(0.06, length(hn - vec2(-0.1, 0.62)));
	float rg = step(abs(fract(rd * 4.0 - TIME * 0.7) - 0.5), 0.05) * rings_amt * (1.0 - rim);
	float sw = n2(vec2(atan(hn.y, hn.x) * 2.0 + TIME * 1.6, rd * 5.0 - TIME * 0.8)) * swirl_amt;
	vec3 col = tint.rgb + vec3(sw * 0.3);
	vec3 vt = texture(view_tex, vec2(hn.x * 0.55 + 0.5, 0.5 - hn.y * 0.55)).rgb;
	float vin = view_amt * (1.0 - rim);
	col = mix(col, vt, vin);
	col = mix(col, rim_col.rgb, rim);
	col = mix(col, vec3(1.0), clamp(hl + hl2 + rg * 0.8, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(mix(tint.a, rim_col.a, rim) + hl + hl2 + rg * 0.5 + vin * 0.7, 0.0, 1.0) * fade;
}
"""

## Toon katı (köşe rengi): gürültüyle çözülme (kenarı burn_col), anlık parlama
const SH_SOLID := """
uniform vec4 tint : source_color = vec4(1.0);
uniform float dissolve = 0.0;
uniform vec4 burn_col : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float nscale = 2.5;
uniform float flash = 0.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float n = n2(lp.xy * nscale + vec2(lp.z * 1.7, 0.0)) * 0.6 + n2(lp.zy * nscale * 2.3) * 0.4;
	if (n < dissolve) { discard; }
	vec3 base = COLOR.rgb * tint.rgb;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	float edge = step(n, dissolve + 0.05) * step(0.001, dissolve);
	EMISSION = burn_col.rgb * edge + base * flash;
}
"""

## Mürekkep kontur (ters kabuk): köşe normaline göre büyür; yalnız kameradan uzağa bakan yüzler çizilir (sarma yönünden bağımsız)
const SH_LINE := """
uniform vec4 line_col : source_color = vec4(0.06, 0.05, 0.07, 1.0);
uniform float thick = 0.03;
uniform float dissolve = 0.0;
uniform float nscale = 2.5;
varying vec3 lp;
varying vec3 vn;
varying vec3 vpos;
void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * thick;
	vn = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vpos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	if (dot(normalize(vn), -normalize(vpos)) > 0.0) { discard; }
	float n = n2(lp.xy * nscale + vec2(lp.z * 1.7, 0.0)) * 0.6 + n2(lp.zy * nscale * 2.3) * 0.4;
	if (n < dissolve) { discard; }
	ALBEDO = line_col.rgb;
}
"""

## Hayalet kopya: yarı saydam iç + sert kenar bandı, isteğe bağlı yatay titreşim bantları
const SH_GHOST := """
uniform vec4 tint : source_color = vec4(0.8, 0.85, 1.0, 0.5);
uniform vec4 rim_col : source_color = vec4(1.0);
uniform float fade = 1.0;
uniform float bands = 0.0;
uniform float glow_amt = 0.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = step(0.55, f);
	float b = 1.0;
	if (bands > 0.0) { b = 0.55 + 0.45 * step(0.5, fract(wp.y * bands + TIME * 1.5)); }
	vec3 col = mix(tint.rgb, rim_col.rgb, rim);
	ALBEDO = col * (1.0 + glow_amt);
	ALPHA = clamp(tint.a * b + rim * rim_col.a * 0.6, 0.0, 1.0) * fade;
}
"""


static func _shader(body: String, add := false, xray := false) -> Shader:
	var key = "%s|%s|%s" % [body, add, xray]
	if _shaders.has(key):
		return _shaders[key]
	var blend = "blend_add" if add else "blend_mix"
	var rm := ""
	match body:
		"solid":
			rm = "diffuse_toon, specular_disabled, cull_disabled"
		"line":
			rm = "unshaded, cull_disabled, shadows_disabled"
		"bubble", "ghost":
			rm = "unshaded, cull_back, depth_draw_never, shadows_disabled, " + blend
		_:
			rm = "unshaded, cull_disabled, depth_draw_never, shadows_disabled, " + blend
	if xray:
		rm += ", depth_test_disabled"
	var code := ""
	match body:
		"soft":
			code = SH_SOFT
		"streak":
			code = SH_STREAK
		"strip":
			code = SH_STRIP
		"ground":
			code = SH_GROUND
		"bubble":
			code = SH_BUBBLE
		"solid":
			code = SH_SOLID
		"line":
			code = SH_LINE
		"ghost":
			code = SH_GHOST
	var s = Shader.new()
	s.code = "shader_type spatial;\nrender_mode " + rm + ";\n" + SH_NOISE + "\n" + code
	_shaders[key] = s
	return s


static func _mat(body: String, params := {}, add := false, xray := false) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader(body, add, xray)
	for k in params:
		m.set_shader_parameter(k, params[k])
	if xray:
		m.render_priority = 10
	return m


## Yumuşak leke malzemesi (paylaşılan, parametreye göre bir kez kurulur)
static func _soft(add := false, xray := false, rim := 0.0, rim_col := INK, hard := 0.5, wob := 0.35) -> ShaderMaterial:
	var key = "soft%s%s%.2f%.2f%.2f%s" % [add, xray, rim, hard, wob, rim_col.to_html()]
	if not _cache.has(key):
		_cache[key] = _mat("soft", {"rim_amt": rim, "rim_col": rim_col, "hard": hard, "wob": wob}, add, xray)
	return _cache[key]


## Tek dörtgen için renkli leke / çizgi malzemesi (köşe rengi beyaz olduğundan renk tint ile verilir)
static func _soft_c(col: Color, add := false, xray := false, rim := 0.0, rim_col := INK, hard := 0.9, wob := 0.1) -> ShaderMaterial:
	return _mat("soft", {"tint": col, "rim_amt": rim, "rim_col": rim_col, "hard": hard, "wob": wob}, add, xray)


static func _streak_c(col: Color, add := true, xray := false) -> ShaderMaterial:
	return _mat("streak", {"tint": col}, add, xray)


static func _streak(add := false, xray := false) -> ShaderMaterial:
	var key = "streak%s%s" % [add, xray]
	if not _cache.has(key):
		_cache[key] = _mat("streak", {}, add, xray)
	return _cache[key]


static func _stripm(core: Color, rim: Color, core_w := 0.45, add := false, xray := false, dash := 0.0, flow := 0.0) -> ShaderMaterial:
	return _mat("strip", {"core_col": core, "rim_col": rim, "core_w": core_w, "dash": dash, "flow": flow}, add, xray)


static func _solid() -> ShaderMaterial:
	if not _cache.has("solid"):
		_cache["solid"] = _mat("solid")
	return _cache["solid"]


static func _line(thick: float) -> ShaderMaterial:
	var key = "line%.3f" % thick
	if not _cache.has(key):
		_cache[key] = _mat("line", {"thick": thick})
	return _cache[key]


## Toon katı + mürekkep konturlu örnek
static func _solid_mi(mesh: Mesh, thick := 0.02, shadow := false) -> MeshInstance3D:
	var mi = _mi(mesh, _solid())
	if thick > 0.0:
		mi.material_overlay = _line(thick)
	if shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


# ═════════════════════════════════════════ altyapı ═════════════════════════════════════════

## Her karede fn(node, dt, age) çağıran düğüm; fn false dönünce silinir
class Ticker extends Node3D:
	var fn := Callable()
	var age := 0.0

	func _process(dt: float) -> void:
		age += dt
		if not fn.is_valid() or not fn.call(self, dt, age):
			queue_free()


static func _scene(pj: PathJutsu) -> Node:
	return pj.get_tree().current_scene


static func _tick(pj: PathJutsu, pos: Vector3, fn: Callable, parent: Node = null) -> Ticker:
	var n = Ticker.new()
	n.fn = fn
	if parent != null and is_instance_valid(parent):
		parent.add_child(n)
		n.position = pos
	else:
		_scene(pj).add_child(n)
		n.global_position = pos
	return n


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["quad"] = q
	return _cache["quad"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache["plane"] = p
	return _cache["plane"]


static func _sphere() -> SphereMesh:
	if not _cache.has("sphere"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 20
		s.rings = 12
		_cache["sphere"] = s
	return _cache["sphere"]


## MB ile kurulan, bir kez önbelleğe alınan toon mesh
static func _built(key: String, fn: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var b: MB = fn.call()
		_cache[key] = b.build(null)
	return _cache[key]


static func _cam(n: Node) -> Vector3:
	var vp = n.get_viewport()
	var cm = vp.get_camera_3d() if vp else null
	return cm.global_position if cm else Vector3(0, 60, 0)


static func _height(n: Node3D) -> float:
	return float(n.get("height")) if n.get("height") != null else 1.8


static func _radius(n: Node3D) -> float:
	return float(n.get("radius")) if n.get("radius") != null else 0.38


static func _flat_dir(c: Node3D) -> Vector3:
	var fd: Vector3 = c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD
	fd.y = 0.0
	return fd.normalized() if fd.length() > 0.01 else Vector3.FORWARD


static func _grad(cols: Array, u: float) -> Color:
	var n = cols.size()
	if n == 1:
		return cols[0]
	var f = clampf(u, 0.0, 1.0) * (n - 1)
	var i = mini(int(f), n - 2)
	return (cols[i] as Color).lerp(cols[i + 1], f - i)


static func _rand_unit() -> Vector3:
	var z = randf_range(-1.0, 1.0)
	var a = randf() * TAU
	var r = sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a))


static func _cone_dir(d: Vector3, spread: float) -> Vector3:
	var cz = lerpf(1.0, cos(spread), randf())
	var sz = sqrt(maxf(0.0, 1.0 - cz * cz))
	var a = randf() * TAU
	var t1 = d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 = d.cross(t1)
	return (d * cz + (t1 * cos(a) + t2 * sin(a)) * sz).normalized()


static func _face_basis(to_cam: Vector3, sx0: float, sy0: float, roll := 0.0) -> Basis:
	var sx = maxf(sx0, 0.0005)   # sıfır ölçek tekil taban uyarısı basar
	var sy = maxf(sy0, 0.0005)
	var z = to_cam.normalized() if to_cam.length() > 0.001 else Vector3.BACK
	var up = Vector3.UP if absf(z.y) < 0.98 else Vector3.FORWARD
	var x = up.cross(z).normalized()
	var y = z.cross(x)
	if roll != 0.0:
		var cr = cos(roll)
		var sr = sin(roll)
		var x2 = x * cr + y * sr
		y = y * cr - x * sr
		x = x2
	return Basis(x * sx, y * sy, z)


static func _streak_basis(v: Vector3, to_cam: Vector3, length: float, width: float) -> Basis:
	var d = v.normalized() if v.length() > 0.001 else Vector3.UP
	var y = d.cross(to_cam)
	if y.length() < 0.001:
		y = d.cross(Vector3.RIGHT)
	y = y.normalized()
	return Basis(d * length, y * width, d.cross(y))


## +Z ileri bakan model için yön tabanı
static func _look_basis(fwd_v: Vector3, s0: float) -> Basis:
	var s = maxf(s0, 0.0005)
	var z = fwd_v.normalized() if fwd_v.length() > 0.001 else Vector3.FORWARD
	var up = Vector3.UP if absf(z.y) < 0.98 else Vector3.RIGHT
	var x = up.cross(z).normalized()
	var y = z.cross(x)
	return Basis(x * s, y * s, z * s)


## Y eksenini n'ye çeviren taban
static func _basis_y_to(n: Vector3) -> Basis:
	var ax = Vector3.UP.cross(n)
	if ax.length() < 0.0001:
		return Basis() if n.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(ax.normalized(), Vector3.UP.angle_to(n))


static func _gy(p: Vector3) -> float:
	return Game.ground_height(p.x, p.z)


static func _bone(n: Node3D, bone: String) -> Node3D:
	var m = n.get("model")
	if m == null or not is_instance_valid(m) or m.get("skel") == null or m.skel.find_bone(bone) < 0:
		return null
	var ba = BoneAttachment3D.new()
	ba.bone_name = bone
	m.skel.add_child(ba)
	return ba


static func _targets(c: Node3D, r: float) -> Array:
	var out = []
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if f != c and Combat.hostile(c, f) and not f.is_dead() and (f as Node3D).global_position.distance_to(c.global_position) <= r:
			out.append(f)
	out.sort_custom(func(a, b): return a.global_position.distance_to(c.global_position) < b.global_position.distance_to(c.global_position))
	return out


## Algılama ölçeği: tekniğin kademesinden (eski genel algılayıcı işaretlemesiyle aynı menzil: 60 + kademe × 20 m, 12 sn)
static func _sense_rd(id: String) -> Vector2:
	var d: Dictionary = Data.jutsu.get(id, {})
	var tier = int(d.get("tier", 2))
	return Vector2(60.0 + tier * 20.0, 12.0)


## Düğüm geçerliyse konumu + kayma; değilse null (bağ kopar)
static func _at_fn(n: Node3D, off: Vector3) -> Callable:
	var w = weakref(n)
	return func():
		var x = w.get_ref()
		if x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return null
		return x.global_position + off


static func _head_fn(n: Node3D, k := 0.93) -> Callable:
	var w = weakref(n)
	return func():
		var x = w.get_ref()
		if x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return null
		if x.has_method("is_dead") and x.is_dead():
			return null
		return x.global_position + Vector3.UP * _height(x) * k


# ───────────────────────── parçacık düzeneği (MultiMesh) ─────────────────────────

## n parça: at çevresinde doğar; mode "face" (kameraya dönük leke), "stretch" (hıza göre uzayan çizgi),
## "tumble" (3B dönen parça), "flat" (yere yatık). Renk ömür boyunca cols üzerinde akar.
static func _spray(pj: PathJutsu, at: Vector3, n: int, o: Dictionary) -> Ticker:
	var mesh: Mesh = o.get("mesh", _quad())
	var mat: Material = o.get("mat", _soft())
	var mode: String = String(o.get("mode", "face"))
	var life: Vector2 = o.get("life", Vector2(0.6, 1.0))
	var spd: Vector2 = o.get("spd", Vector2(1.0, 3.0))
	var dir: Vector3 = (o.get("dir", Vector3.UP) as Vector3).normalized()
	var spread: float = deg_to_rad(float(o.get("spread", 60.0)))
	var rad: float = float(o.get("radius", 0.2))
	var flat: bool = bool(o.get("flat", false))
	var radial: bool = bool(o.get("radial", false))
	var inward: bool = bool(o.get("inward", false))
	var grav: float = float(o.get("grav", 0.0))
	var drag: float = float(o.get("drag", 0.0))
	var sz: Vector2 = o.get("size", Vector2(0.2, 0.4))
	var grow: float = float(o.get("grow", 1.0))
	var cols: Array = o.get("cols", [Color.WHITE, Color(1, 1, 1, 0)])
	var stretch: float = float(o.get("stretch", 0.08))
	var ground: bool = bool(o.get("ground", false))
	var pull: Callable = o.get("pull", Callable())
	var pull_k: float = float(o.get("pull_k", 0.0))
	var swirl: float = float(o.get("swirl", 0.0))
	var dl: Vector2 = o.get("delay", Vector2.ZERO)
	var spin: float = float(o.get("spin", 0.0))
	var P = []
	var V = []
	var A = []
	var L = []
	var S = []
	var D = []
	var R = []
	var G = []
	for i in n:
		var off: Vector3
		if flat:
			var a = randf() * TAU
			var r = rad * sqrt(randf())
			off = Vector3(cos(a) * r, 0.0, sin(a) * r)
		else:
			off = _rand_unit() * rad * pow(randf(), 0.33)
		var dv = _cone_dir(dir, spread)
		var hz = Vector3(off.x, 0.0, off.z)
		if radial and hz.length() > 0.001:
			dv = (hz.normalized() + dir * 0.35).normalized()
		if inward and off.length() > 0.001:
			dv = -off.normalized()
		P.append(off)
		V.append(dv * randf_range(spd.x, spd.y))
		A.append(0.0)
		L.append(randf_range(life.x, life.y))
		S.append(randf_range(sz.x, sz.y))
		D.append(randf_range(dl.x, dl.y))
		R.append(_rand_unit())
		G.append(Game.ground_height(at.x + off.x, at.z + off.z) - at.y + 0.03 if ground else -INF)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	var hid = Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), Vector3(0, -500, 0))
	for i in n:
		mm.set_instance_transform(i, hid)
	var tk = _tick(pj, at, func(node, dt, age) -> bool:
		var cam: Vector3 = _cam(node) - at
		var pp = Vector3.ZERO
		if pull.is_valid():
			var pv = pull.call()
			if pv != null:
				pp = (pv as Vector3) - at
		var alive = false
		for i in n:
			if age < D[i]:
				alive = true
				continue
			A[i] += dt
			var u = A[i] / L[i]
			if u >= 1.0:
				mm.set_instance_transform(i, hid)
				continue
			alive = true
			var v: Vector3 = V[i]
			var p: Vector3 = P[i]
			v.y -= grav * dt
			if drag > 0.0:
				v *= maxf(0.0, 1.0 - drag * dt)
			if pull_k > 0.0:
				var to = pp - p
				var dd = to.length()
				if dd < 0.12:
					A[i] = L[i]
				elif dd > 0.0:
					v += to / dd * pull_k * dt
					v *= maxf(0.0, 1.0 - 2.0 * dt)
			if swirl != 0.0:
				var h = Vector3(p.x, 0.0, p.z)
				if h.length() > 0.05:
					v += Vector3(-h.z, 0.0, h.x).normalized() * swirl * dt
			p += v * dt
			if p.y < G[i]:
				p.y = G[i]
				v = Vector3(v.x * 0.3, 0.0, v.z * 0.3)
			P[i] = p
			V[i] = v
			var s = S[i] * lerpf(1.0, grow, u)
			var b: Basis
			if mode == "stretch":
				b = _streak_basis(v, cam - p, s * (1.0 + v.length() * stretch), s * 0.2)
			elif mode == "tumble":
				b = Basis(R[i], A[i] * spin + R[i].x * 3.0).scaled(Vector3.ONE * s)
			elif mode == "flat":
				b = (Basis(Vector3.UP, R[i].x * 6.0 + A[i] * spin) * Basis(Vector3.RIGHT, -PI * 0.5)).scaled(Vector3.ONE * s)
			else:
				b = _face_basis(cam - p, s, s, R[i].x * 3.0 + A[i] * spin)
			mm.set_instance_transform(i, Transform3D(b, p))
			mm.set_instance_color(i, _grad(cols, u))
		return alive)
	tk.add_child(mmi)
	return tk


## Hareketli merkez (center_fn) çevresinde eğik halkalarda dönen n parça (arılar, kum taneleri, avuç girdabı)
static func _orbit(pj: PathJutsu, center_fn: Callable, n: int, rr: Vector2, dur: float, o: Dictionary, parent: Node = null) -> Ticker:
	var mesh: Mesh = o.get("mesh", _quad())
	var mat: Material = o.get("mat", _soft())
	var size: float = float(o.get("size", 0.1))
	var col: Color = o.get("col", Color.WHITE)
	var speed: float = float(o.get("speed", 2.0))
	var bob: float = float(o.get("bob", 0.2))
	var tilt: float = float(o.get("tilt", 0.3))
	var hgt: Vector2 = o.get("h", Vector2.ZERO)
	var face: bool = bool(o.get("face", true))
	var shrink: float = float(o.get("shrink", 1.0))
	var fin: float = float(o.get("fin", 0.4))
	var RI = []
	var PH = []
	var SP = []
	var HI = []
	var AX = []
	for i in n:
		RI.append(randf_range(rr.x, rr.y))
		PH.append(randf() * TAU)
		SP.append(speed * randf_range(0.7, 1.3) * (1.0 if randf() < 0.8 else -1.0))
		HI.append(randf_range(hgt.x, hgt.y))
		var ax = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		AX.append(Basis(ax.normalized(), randf() * tilt) if ax.length() > 0.01 else Basis())
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var tk = _tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
		if age >= dur:
			return false
		var cv = center_fn.call()
		if cv == null:
			return false
		var cen: Vector3 = cv
		node.global_position = cen
		var cam = _cam(node) - cen
		var env = minf(1.0, age / 0.25) * clampf((dur - age) / fin, 0.0, 1.0)
		var kr = lerpf(1.0, shrink, age / dur)
		for i in n:
			var ph = PH[i] + age * SP[i]
			var loc = Vector3(cos(ph) * RI[i] * kr, HI[i] + sin(age * 3.1 + PH[i]) * bob, sin(ph) * RI[i] * kr)
			var p = (AX[i] as Basis) * loc
			var b: Basis
			if face:
				b = _face_basis(cam - p, size, size, ph)
			else:
				var tg = (AX[i] as Basis) * Vector3(-sin(ph), 0.0, cos(ph)) * signf(SP[i])
				b = _look_basis(tg, size)
			mm.set_instance_transform(i, Transform3D(b, p))
			mm.set_instance_color(i, Color(col.r, col.g, col.b, col.a * env))
		return true, parent)
	tk.add_child(mmi)
	return tk


# ───────────────────────── şerit düzeneği ─────────────────────────

## Kameraya dönük şerit: pts boyunca ws yarı genişlik, al saydamlık (UV.x baştan sona)
static func _strip(im: ImmediateMesh, mat: Material, pts: Array, ws: Array, al: Array, cam: Vector3) -> void:
	var n = pts.size()
	if n < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		var sd: Vector3 = tn.cross(cam - p)
		if sd.length_squared() < 1e-8:
			sd = tn.cross(Vector3.UP)
		if sd.length_squared() < 1e-8:
			sd = Vector3.RIGHT
		sd = sd.normalized() * float(ws[i])
		var u = float(i) / float(n - 1)
		var col = Color(1, 1, 1, float(al[i]))
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(u, 0.0))
		im.surface_add_vertex(p + sd)
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(u, 1.0))
		im.surface_add_vertex(p - sd)
	im.surface_end()


## path(u, age) -> Vector3 (null dönerse şerit kopar). reveal: baş 0→1 bu sürede ilerler; tail > 0: yalnız baştan geriye
## o kadarlık hareketli parça (boncuk / akan çizgi); taper 0 sabit, 1 iki uç incelir, 2 sona doğru, 3 başa doğru incelir
static func _ribbon(pj: PathJutsu, path: Callable, dur: float, width: float, mat: Material, segs := 16, o := {}) -> Ticker:
	var reveal: float = float(o.get("reveal", 0.0))
	var tail: float = float(o.get("tail", 0.0))
	var taper: int = int(o.get("taper", 1))
	var fin: float = float(o.get("fin", 0.3))
	var delay: float = float(o.get("delay", 0.0))
	var im = ImmediateMesh.new()
	var mi = _mi(im, null)
	mi.extra_cull_margin = 64.0
	var tk = _tick(pj, Vector3.ZERO, func(node, _dt, age0) -> bool:
		im.clear_surfaces()
		var age = age0 - delay
		if age < 0.0:
			return true
		if age >= dur:
			return false
		var hs = age / reveal if reveal > 0.0 else 1.0
		var head = clampf(hs, 0.0, 1.0)
		var tl = 0.0
		if tail > 0.0:
			tl = clampf(hs - tail, 0.0, 1.0)
			if tl >= 1.0:
				return false
		if head - tl < 0.002:
			return true
		var env = minf(1.0, age / 0.06) * clampf((dur - age) / maxf(fin, 0.01), 0.0, 1.0)
		var pts = []
		var ws = []
		var al = []
		for k in segs + 1:
			var f = float(k) / segs
			var v = path.call(lerpf(tl, head, f), age)
			if v == null:
				return false
			pts.append(v)
			var w = width
			if taper == 1:
				w *= 0.25 + 0.75 * sin(PI * f)
			elif taper == 2:
				w *= lerpf(1.0, 0.15, f)
			elif taper == 3:
				w *= lerpf(0.15, 1.0, f)
			ws.append(w)
			al.append(env)
		_strip(im, mat, pts, ws, al, _cam(node))
		return true)
	tk.add_child(mi)
	return tk


## İki uç arasında (uçlar canlı Callable) yay çizen yol; uçtan biri null olursa null
static func _arc_path(a_fn: Callable, b_fn: Callable, lift: float, wave := 0.0, wave_f := 6.0) -> Callable:
	return func(u: float, age: float):
		var a = a_fn.call()
		var b = b_fn.call()
		if a == null or b == null:
			return null
		var av: Vector3 = a
		var bv: Vector3 = b
		var p = av.lerp(bv, u) + Vector3.UP * sin(u * PI) * lift
		if wave != 0.0:
			var dd = bv - av
			var sd = dd.cross(Vector3.UP)
			sd = sd.normalized() if sd.length() > 0.001 else Vector3.RIGHT
			p += sd * sin(u * wave_f * PI + age * 9.0) * wave * sin(u * PI)
		return p


static func _const(v: Vector3) -> Callable:
	return func(): return v


## Yol boyunca akan boncuk / pul akışı: her parça span sn arayla doğar, travel sn'de yolu geçer (back: sondan başa)
static func _beads(pj: PathJutsu, path: Callable, n: int, span: float, travel: float, size: float, col: Color, mat: Material, back := false) -> Ticker:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad()
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1000, 4000))
	var hid = Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), Vector3(0, -500, 0))
	var tk = _tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
		var cam = _cam(node)
		var alive = false
		for i in n:
			var s0 = span * i / maxf(1.0, n - 1.0)
			var u = (age - s0) / travel
			if u < 0.0:
				alive = true
				mm.set_instance_transform(i, hid)
				continue
			if u >= 1.0:
				mm.set_instance_transform(i, hid)
				continue
			alive = true
			var pv = path.call(1.0 - u if back else u, age)
			if pv == null:
				return false
			var p: Vector3 = pv
			var sc = size * (0.6 + 0.4 * sin(u * PI))
			mm.set_instance_transform(i, Transform3D(_face_basis(cam - p, sc, sc, age * 4.0 + i), p))
			mm.set_instance_color(i, Color(col.r, col.g, col.b, col.a * minf(1.0, sin(u * PI) * 3.0)))
		return alive)
	tk.add_child(mmi)
	return tk


# ───────────────────────── zemin ─────────────────────────

## Zemin katmanı (bkz. SH_GROUND): mode 0 dalga halkaları (dur boyunca dışa akar); diğerleri grow sn'de açılır, sonda söner
static func _ground(pj: PathJutsu, at: Vector3, R: float, dur: float, p: Dictionary, grow := 0.3, xray := false, parent: Node = null, loop := 0.0) -> Ticker:
	var m = _mat("ground", p, false, xray)
	var mi = _mi(_plane(), m)
	mi.scale = Vector3(R, 1.0, R)
	var mode = int(p.get("mode", 0))
	var rings = float(p.get("rings", 3.0))
	var tk = _tick(pj, at + Vector3.UP * 0.05, func(_n, _dt, age) -> bool:
		if age >= dur:
			return false
		var u = age / dur
		if mode == 0:
			var w = fmod(age, loop) / loop if loop > 0.0 else u
			m.set_shader_parameter("prog", w * (1.0 + 0.16 * (rings - 1.0)))
			if loop > 0.0:
				m.set_shader_parameter("fade", clampf((dur - age) / 0.5, 0.0, 1.0))
		else:
			var g = clampf(age / maxf(grow, 0.01), 0.0, 1.0)
			m.set_shader_parameter("prog", 1.0 - pow(1.0 - g, 3.0))
			m.set_shader_parameter("fade", 1.0 - smoothstep(0.65, 1.0, u))
		return true, parent)
	tk.add_child(mi)
	return tk


static func _flat_mat() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Zemin çatlakları: merkezden dallanan, kırık çizgili koyu yarıklar (zemine oturur), hızla açılır, dur sonunda söner
static func _cracks(pj: PathJutsu, at: Vector3, R: float, n: int, dur: float, col := Color(0.1, 0.08, 0.07, 0.95), dir := Vector3.ZERO, fan := TAU) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_a = atan2(dir.z, dir.x) if dir.length() > 0.01 else 0.0
	for k in n:
		var a = base_a + (fan * (float(k) / n - 0.5) if fan < TAU else TAU * k / n) + randf_range(-0.3, 0.3)
		var L = R * randf_range(0.5, 1.0)
		_crack_branch(st, at, Vector3.ZERO, Vector3(cos(a), 0.0, sin(a)), L, R * 0.045, col, 2)
	var mat = _flat_mat()
	var mi = _mi(st.commit(), mat)
	var tk = _tick(pj, at, func(_n, _dt, age) -> bool:
		if age >= dur:
			return false
		var g = clampf(age / 0.16, 0.0, 1.0)
		mi.scale = Vector3(lerpf(0.25, 1.0, g), 1.0, lerpf(0.25, 1.0, g))
		mat.albedo_color = Color(1, 1, 1, 1.0 - smoothstep(dur * 0.6, dur, age))
		return true)
	tk.add_child(mi)


static func _crack_branch(st: SurfaceTool, at: Vector3, p0: Vector3, d: Vector3, L: float, w: float, col: Color, depth: int) -> void:
	var segs = 5
	var p = p0
	var dd = d
	var ww = w
	for s in segs:
		dd = dd.rotated(Vector3.UP, randf_range(-0.45, 0.45))
		var q = p + dd * (L / segs)
		var w2 = ww * 0.72
		var s0 = Vector3(-dd.z, 0.0, dd.x) * ww
		var s1 = Vector3(-dd.z, 0.0, dd.x) * w2
		var y0 = Game.ground_height(at.x + p.x, at.z + p.z) - at.y + 0.035
		var y1 = Game.ground_height(at.x + q.x, at.z + q.z) - at.y + 0.035
		var a0 = Vector3(p.x, y0, p.z) + s0
		var b0 = Vector3(p.x, y0, p.z) - s0
		var a1 = Vector3(q.x, y1, q.z) + s1
		var b1 = Vector3(q.x, y1, q.z) - s1
		for v in [a0, b0, a1, a1, b0, b1]:
			st.set_color(col)
			st.add_vertex(v)
		if depth > 0 and (s == 1 or s == 3) and randf() < 0.6:
			_crack_branch(st, at, q, dd.rotated(Vector3.UP, randf_range(0.6, 1.0) * (1.0 if randf() < 0.5 else -1.0)), L * 0.4, w2 * 0.8, col, depth - 1)
		p = q
		ww = w2


## Yere yatık iz: noktalar boyunca düz şerit (zemine oturur), dur sonunda söner
static func _ground_trail(pj: PathJutsu, pts: Array, width: float, col: Color, dur: float) -> void:
	if pts.size() < 2:
		return
	var at: Vector3 = pts[0]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var p: Vector3 = pts[i] - at
		var q: Vector3 = pts[i + 1] - at
		var d = q - p
		d.y = 0.0
		var sd = Vector3(-d.z, 0.0, d.x).normalized() * width * (0.4 + 0.6 * sin(PI * float(i) / (pts.size() - 1)) + 0.2)
		var yp = Game.ground_height(at.x + p.x, at.z + p.z) - at.y + 0.03
		var yq = Game.ground_height(at.x + q.x, at.z + q.z) - at.y + 0.03
		var a0 = Vector3(p.x, yp, p.z)
		var a1 = Vector3(q.x, yq, q.z)
		for v in [a0 + sd, a0 - sd, a1 + sd, a1 + sd, a0 - sd, a1 - sd]:
			st.set_color(col)
			st.add_vertex(v)
	var mat = _flat_mat()
	var mi = _mi(st.commit(), mat)
	var tk = _tick(pj, at, func(_n, _dt, age) -> bool:
		if age >= dur:
			return false
		mat.albedo_color = Color(1, 1, 1, 1.0 - smoothstep(dur * 0.5, dur, age))
		return true)
	tk.add_child(mi)


# ───────────────────────── ortak parça kalıpları (yalnız bu dosyanın) ─────────────────────────

## Cel toz bulutu: koyu konturlu kabarık lekeler
static func _dust(pj: PathJutsu, at: Vector3, n: int, o: Dictionary) -> void:
	var d = {"mat": _soft(false, false, 0.55, DUST_D, 0.85, 0.3), "life": Vector2(0.8, 1.3), "spd": Vector2(2.0, 5.0),
		"size": Vector2(0.5, 1.0), "grow": 1.8, "drag": 2.4, "cols": [Color(DUST, 0.95), Color(DUST, 0.85), Color(DUST.lightened(0.1), 0.0)]}
	d.merge(o, true)
	_spray(pj, at, n, d)


## Moloz: dönen kaya parçaları (toon katı), yere düşer
static func _debris(pj: PathJutsu, at: Vector3, n: int, col: Color, spd: float, size := 0.22, dir := Vector3.UP, spread := 55.0) -> void:
	var rock = _built("rock_chip", func():
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(1.0, 0.7, 0.85), Color.WHITE, Vector3(12, 30, 8))
		b.add("box", Vector3(0.2, 0.2, 0.1), Vector3(0.6, 0.5, 0.6), Color(0.85, 0.85, 0.85), Vector3(-20, 10, 35))
		return b)
	_spray(pj, at + Vector3.UP * 0.2, n, {"mesh": rock, "mat": _solid(), "mode": "tumble", "spin": 9.0, "life": Vector2(1.2, 1.8),
		"spd": Vector2(spd * 0.5, spd), "dir": dir, "spread": spread, "grav": 22.0, "ground": true, "radius": 0.4,
		"size": Vector2(size * 0.5, size), "cols": [col, col.darkened(0.15)]})


## Kopya (pişmiş poz): n'in o anki görünüşü dondurulur. keep_mats: kendi malzemeleriyle (opak heykel), değilse mat
static func _ghost(pj: PathJutsu, n: Node3D, mat: Material, shift := Vector3.ZERO, keep_mats := false) -> Node3D:
	var holder = Node3D.new()
	_scene(pj).add_child(holder)
	holder.global_position = n.global_position + shift
	var m = n.get("model")
	if m == null or not is_instance_valid(m):
		return holder
	var inv = Transform3D(Basis(), n.global_position).affine_inverse()
	for x in (m as Node).find_children("*", "MeshInstance3D", true, false):
		var src := x as MeshInstance3D
		if src.mesh == null or not src.is_visible_in_tree():
			continue
		var mesh: Mesh = src.mesh
		if src.skin != null or src.get_node_or_null(src.skeleton) is Skeleton3D:
			var baked = src.bake_mesh_from_current_skeleton_pose()
			if baked:
				mesh = baked
		var e = MeshInstance3D.new()
		e.mesh = mesh
		if keep_mats:
			for si in mesh.get_surface_count():
				var sm = src.get_active_material(si)
				if sm:
					e.set_surface_override_material(si, sm)
		else:
			e.material_override = mat
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if keep_mats else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(e)
		e.transform = inv * src.global_transform
	return holder


static func _ghost_mat(tint: Color, rim: Color, bands := 0.0, glow := 0.0, xray := false) -> ShaderMaterial:
	return _mat("ghost", {"tint": tint, "rim_col": rim, "bands": bands, "glow_amt": glow}, false, xray)


## Hayalet kopyayı life sn'de söndürüp siler (rise: o sürede yukarı kayma)
static func _fade_ghost(pj: PathJutsu, holder: Node3D, mat: ShaderMaterial, hold: float, life: float, rise := 0.0) -> void:
	var y0 = holder.position.y
	var tk = _tick(pj, Vector3.ZERO, func(_n, _dt, age) -> bool:
		if not is_instance_valid(holder):
			return false
		if age >= hold + life:
			holder.queue_free()
			return false
		mat.set_shader_parameter("fade", minf(1.0, age / 0.08) * (1.0 - clampf((age - hold) / life, 0.0, 1.0)))
		holder.position.y = y0 + rise * minf(1.0, age / maxf(hold + life, 0.01))
		return true)
	tk.name = "GhostFade"


# ═════════════════════════════════════════ 1) Ön Lotus ═════════════════════════════════════════

## Kanon: ilk kapı (Kaimon) zorla açılır — bedel can (yalnız kapı kapalıyken). Görsel: bedenden ince sıcak buhar.
static func _gate_open(pj: PathJutsu, c: Node3D, frac: float) -> void:
	if PathJutsu.gate_level(c) < 1:
		if c is Player:
			c.hp = maxf(1.0, c.hp - c.max_hp * frac)
		c.set_meta("gates", 1)
		c.set_meta("gates_until", Game.now() + 8.0)
	_spray(pj, c.global_position + Vector3.UP * 1.0, 10, {"mat": _soft(false, false, 0.0, INK, 0.3, 0.45), "radius": 0.35,
		"spd": Vector2(0.6, 1.4), "dir": Vector3.UP, "spread": 25.0, "life": Vector2(0.6, 0.9), "size": Vector2(0.25, 0.4), "grow": 2.2,
		"cols": [Color(1, 1, 1, 0.0), Color(0.95, 1.0, 0.95, 0.35), Color(1, 1, 1, 0.0)]})


## Atılış hız çizgileri: başlangıçtan varışa uzanan ince soluk çizgiler
static func _dash_lines(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var mat = _stripm(Color(1, 1, 1, 0.95), Color(0.75, 0.78, 0.8, 0.6), 0.5)
	var d = b - a
	var sd = d.cross(Vector3.UP).normalized() if d.cross(Vector3.UP).length() > 0.01 else Vector3.RIGHT
	for k in 7:
		var off = sd * randf_range(-0.55, 0.55) + Vector3.UP * randf_range(0.35, 1.7)
		var pa = a + off
		var pb = b + off - d.normalized() * 0.6
		_ribbon(pj, func(u, _age): return pa.lerp(pb, u), 0.32, randf_range(0.018, 0.035), mat, 4, {"reveal": 0.1, "tail": 0.55, "taper": 2})
	_dust(pj, a, 6, {"flat": true, "radial": true, "radius": 0.4, "spd": Vector2(1.5, 3.0), "size": Vector2(0.3, 0.55), "life": Vector2(0.5, 0.8)})


## Çeneden fırlatış: ayak dibinde yayılan toz + hedefle yükselen hava çizgileri
static func _launch_kick(pj: PathJutsu, tt: Node3D) -> void:
	var g = pj.gp(tt.global_position)
	_dust(pj, g, 12, {"flat": true, "radial": true, "radius": 0.5, "spd": Vector2(3.0, 5.5), "size": Vector2(0.4, 0.75), "life": Vector2(0.6, 0.95)})
	_spray(pj, g + Vector3.UP * 0.6, 10, {"mat": _streak(), "mode": "stretch", "stretch": 0.12, "radius": 0.6, "flat": true,
		"spd": Vector2(10.0, 15.0), "dir": Vector3.UP, "spread": 6.0, "life": Vector2(0.18, 0.3), "size": Vector2(0.35, 0.5),
		"cols": [Color(1, 1, 1, 0.9), Color(0.9, 0.92, 0.95, 0.0)]})


## Gölge gibi arkada beliriş: soluk kalıntı kopya
static func _afterimage(pj: PathJutsu, c: Node3D) -> void:
	var m = _ghost_mat(Color(0.82, 0.9, 0.84, 0.32), Color(1, 1, 1, 0.9))
	var g = _ghost(pj, c, m, Vector3.ZERO)
	_fade_ghost(pj, g, m, 0.05, 0.3)


## Krater: çatlak, moloz, yayılan toz halkası, toz şok halkası, kalıcı çukur izi
static func _crater(pj: PathJutsu, p: Vector3, s := 1.0) -> void:
	_cracks(pj, p, 3.4 * s, 9, 6.5)
	_debris(pj, p, int(18 * s), EARTH, 9.0 * s, 0.3 * s)
	_dust(pj, p, int(22 * s), {"flat": true, "radial": true, "radius": 0.8 * s, "spd": Vector2(4.0, 7.5), "size": Vector2(0.8, 1.5) * s,
		"life": Vector2(0.9, 1.5), "drag": 2.2, "dir": Vector3.UP})
	_ground(pj, p, 6.5 * s, 0.45, {"mode": 0, "tint": Color(0.86, 0.8, 0.68, 0.85), "rings": 2.0, "width": 0.035})
	_ground(pj, p, 2.4 * s, 7.0, {"mode": 1, "tint": Color(0.22, 0.18, 0.15, 0.55), "tint2": Color(0.12, 0.1, 0.08, 0.7), "seed": randf() * 10.0}, 0.12)


## Sargı bandı malzemesi: kirli beyaz pamuk bant — kenarda ince koyu çizgi, enine kırışık izleri, ince dokuma, toon ışık.
## Saydamlık yerine titreşimli kesme: opak kalır, üst üste sarılan katmanlar sıralama hatası vermez (sönerken seyrelir)
static func _band_mat() -> ShaderMaterial:
	if not _cache.has("omote_band"):
		var sh = Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled, unshaded;
uniform vec3 base_col = vec3(0.93, 0.91, 0.85);
uniform vec3 edge_col = vec3(0.5, 0.48, 0.46);
varying vec3 wn;
float hb(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	if (COLOR.a < 0.999 && hb(floor(FRAGCOORD.xy)) > COLOR.a) { discard; }
	float e = min(UV.y, 1.0 - UV.y);
	vec3 col = mix(edge_col, base_col, smoothstep(0.05, 0.12, e));
	float k = abs(fract(UV.x * 0.23 + sin(UV.y * 2.7 + floor(UV.x * 0.23) * 1.7) * 0.25) - 0.5);
	col *= mix(0.94, 1.0, smoothstep(0.0, 0.03, k));
	col *= 0.965 + 0.035 * sin(UV.x * 55.0) * sin(UV.y * 40.0);
	col *= mix(0.92, 1.0, smoothstep(0.0, 0.5, e));
	// kendi iki tonlu cel ışığı (sahne ışığının mavi gök dolgusu bandı maviye boyuyordu): üstten aydınlık, altı gölge
	float l = dot(FRONT_FACING ? wn : -wn, normalize(vec3(0.35, 1.0, 0.25)));
	col *= mix(0.74, 1.0, smoothstep(-0.15, 0.1, l));
	if (!FRONT_FACING) { col *= 0.9; }
	ALBEDO = col;
}
"""
		var m = ShaderMaterial.new()
		m.shader = sh
		_cache["omote_band"] = m
	return _cache["omote_band"]


## Yassı bant şeridi: p noktaları, wv yarım en vektörleri, nv yüzey normalleri; uv.x = boy / en (kırışık aralığı bant enine bağlı)
static func _band_strip(im: ImmediateMesh, p: Array, wv: Array, nv: Array, al: float) -> void:
	var n = p.size()
	if n < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _band_mat())
	var run = 0.0
	for i in n:
		if i > 0:
			run += (p[i] as Vector3).distance_to(p[i - 1])
		var w: Vector3 = wv[i]
		var u = run / maxf(0.01, w.length() * 2.0)
		for sd in [1.0, -1.0]:
			im.surface_set_color(Color(1, 1, 1, al))
			im.surface_set_normal(nv[i])
			im.surface_set_uv(Vector2(u, 0.0 if sd > 0.0 else 1.0))
			im.surface_add_vertex((p[i] as Vector3) + w * sd)
	im.surface_end()


## Serbest bant parçası (uçuşan / sarkan): noktalar boyunca kendi ekseninde burulan yassı çerçeve
static func _band_free(im: ImmediateMesh, pts: Array, hw: float, ref: Vector3, twist: float, ph: float, al: float) -> void:
	var n = pts.size()
	var P = []
	var W = []
	var N = []
	for i in n:
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		tn = tn.normalized() if tn.length() > 1e-5 else Vector3.UP
		var b0 = tn.cross(ref)
		if b0.length() < 1e-3:
			b0 = tn.cross(Vector3.RIGHT)
		b0 = b0.normalized()
		var b1 = tn.cross(b0)
		var a = ph + twist * float(i) / maxf(1.0, n - 1)
		var wd = b0 * cos(a) + b1 * sin(a)
		P.append(pts[i])
		W.append(wd * hw)
		N.append(wd.cross(tn).normalized())
	_band_strip(im, P, W, N, al)


static func _bz(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float) -> Vector3:
	var v = 1.0 - u
	return a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + d * u * u * u


## Matkap dalışı: dönerek inen bedenin çevresinde, arkasında (yukarıda) kalan sarmal hız çizgileri (anime: hortum izi)
static func _drill_lines(pj: PathJutsu, S: Dictionary, dur: float) -> void:
	var mat = _stripm(Color(1, 1, 1, 0.85), Color(0.78, 0.82, 0.8, 0.5), 0.5)
	var hs: float = S["hs"]
	for k in 4:
		var ph = TAU * k / 4.0
		_ribbon(pj, func(u, age):
			if not S.has("ct") or S["slam"]:
				return null
			var cen: Vector3 = S["ct"]
			var a = ph + u * TAU * 1.6 - age * 18.0
			var r = (0.7 + 0.6 * u) * hs
			return cen + Vector3(cos(a) * r, -0.6 * hs + u * 4.5, sin(a) * r), dur, 0.045, mat, 24, {"taper": 1, "fin": 0.15})


# Ön Lotus zamanlaması (sn; anime sırası: çeneden tekme → arkada beliriş → sargı → arkadan kavrayış → başaşağı dönüş → çakılış)
const LT_RISE := 0.7                    # tekmeyle tepeye (H ≈ 10 m): y = H(1-(1-u)^2) → ilk hız 2H/T ≈ 29 m/sn
const LT_FLY := 0.45                    # sargılar önkollardan çözülüp uçar
const LT_TOUCH := 0.75                  # sargı ucu bedene değer
const LT_WRAP := 1.3                    # sarım tamam (iki bant × 7 tur)
const LT_TIGHT := Vector2(1.05, 1.42)   # gevşek kaotik halkalar bedene sıkıca kapanır
const LT_HUG := Vector2(1.3, 1.5)       # arkadan kavrayış
const LT_FLIP := 1.75                   # ikisi birlikte başaşağı
const LT_LET := 2.25                    # atan son anda bırakıp takla atarak sıçrar
const LT_SLAM := 2.35                   # hedefin başı yere çakılır
const LT_POST := 1.05                   # çakılıştan sonra sargının gevşeyip yere düşmesi

# pozlar (model uzayı: +Z önü, +X sol yanı; kemik yönleri)
const LP_KICK := {"arms": [["RightUpperLeg", Vector3(-0.05, 0.8, 0.6)], ["RightLowerLeg", Vector3(-0.05, 0.93, 0.36)],
	["LeftUpperArm", Vector3(0.85, -0.35, -0.3)], ["LeftLowerArm", Vector3(0.8, -0.45, -0.25)],
	["RightUpperArm", Vector3(-0.85, -0.35, -0.3)], ["RightLowerArm", Vector3(-0.8, -0.45, -0.25)]], "spine": -22.0, "neck": 12.0}
const LP_FLING := {"arms": [["LeftUpperArm", Vector3(0.55, 0.15, 0.82)], ["LeftLowerArm", Vector3(0.35, 0.25, 0.9)],
	["RightUpperArm", Vector3(-0.55, 0.15, 0.82)], ["RightLowerArm", Vector3(-0.35, 0.25, 0.9)],
	["LeftUpperLeg", Vector3(0.08, -0.75, 0.65)], ["LeftLowerLeg", Vector3(0.05, -0.9, -0.4)],
	["RightUpperLeg", Vector3(-0.08, -0.75, 0.65)], ["RightLowerLeg", Vector3(-0.05, -0.9, -0.4)]], "spine": 10.0}
const LP_HUG := {"arms": [["LeftUpperArm", Vector3(0.3, -0.2, 0.93)], ["LeftLowerArm", Vector3(-0.75, -0.1, 0.65)], ["LeftHand", Vector3(-0.8, -0.1, 0.55)],
	["RightUpperArm", Vector3(-0.3, -0.2, 0.93)], ["RightLowerArm", Vector3(0.75, -0.1, 0.65)], ["RightHand", Vector3(0.8, -0.1, 0.55)],
	["LeftUpperLeg", Vector3(0.05, -0.97, -0.22)], ["LeftLowerLeg", Vector3(0.03, -0.95, -0.3)],
	["RightUpperLeg", Vector3(-0.05, -0.97, -0.22)], ["RightLowerLeg", Vector3(-0.03, -0.95, -0.3)]],
	"fL": [0.9, 0.9, 1.0, 1.0, 0.6], "fR": [0.9, 0.9, 1.0, 1.0, 0.6], "spine": 8.0, "neck": 18.0}
const LP_TUCK := {"arms": [["LeftUpperArm", Vector3(0.4, -0.3, 0.86)], ["LeftLowerArm", Vector3(0.1, 0.6, 0.8)],
	["RightUpperArm", Vector3(-0.4, -0.3, 0.86)], ["RightLowerArm", Vector3(-0.1, 0.6, 0.8)],
	["LeftUpperLeg", Vector3(0.1, 0.2, 0.97)], ["LeftLowerLeg", Vector3(0.05, -0.95, 0.2)],
	["RightUpperLeg", Vector3(-0.1, 0.2, 0.97)], ["RightLowerLeg", Vector3(-0.05, -0.95, 0.2)]], "spine": 30.0, "neck": 20.0}
const LP_BOUND := {"arms": [["LeftUpperArm", Vector3(0.17, -0.98, 0.04)], ["LeftLowerArm", Vector3(0.08, -0.97, 0.22)],
	["RightUpperArm", Vector3(-0.17, -0.98, 0.04)], ["RightLowerArm", Vector3(-0.08, -0.97, 0.22)],
	["LeftUpperLeg", Vector3(0.04, -1.0, 0.0)], ["LeftLowerLeg", Vector3(0.02, -1.0, -0.05)],
	["RightUpperLeg", Vector3(-0.04, -1.0, 0.0)], ["RightLowerLeg", Vector3(-0.02, -1.0, -0.05)]], "neck": -15.0}


## Ön Lotus: hedefe atıl, çeneden yukarı tekmele, havada sargıyla sar, arkadan kavrayıp başaşağı döndür ve yere çak
## (ana ağaçtan: Lotus şartı + kapı bedeli). Oyuncu ve düşman aynı işlev.
static func omote_renge(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	if tt == null:   # yakında rakip yok: teknik başlamaz, kapı bedeli ödenmez
		pj.lotus_no_target(c, "Omote Renge")
		return
	_gate_open(pj, c, 0.05)
	if tt == null or not pj._lotus_open(c, tt):
		pj.busy(c, 1.4)
		pj.anim(c, "hook", 1.5)
		# ıska: boşa savrulan tekmenin yay çizen hava kesiği
		var fd0 = _flat_dir(c)
		var base = c.global_position + Vector3.UP * 0.5
		var sd = fd0.cross(Vector3.UP).normalized()
		var mat = _stripm(Color(1, 1, 1, 0.9), Color(0.8, 0.82, 0.85, 0.5), 0.5)
		for k in 3:
			var r = 1.1 + k * 0.18
			_ribbon(pj, func(u, _age): return base + fd0 * cos(lerpf(-0.4, 1.9, u)) * r + Vector3.UP * sin(lerpf(-0.4, 1.9, u)) * r + sd * (k - 1) * 0.12,
				0.28, 0.05, mat, 14, {"reveal": 0.1, "tail": 0.7, "taper": 1})
		return
	pj.busy(c, LT_LET + 0.5)
	var fd = pj.fwd(c, tt)
	var start = c.global_position
	c.global_position = pj.gp(tt.global_position - fd * 1.0)
	_dash_lines(pj, start, c.global_position)
	Sfx.play("hit_heavy", c.global_position, 1.1)
	tt.take_hit(pj.inf(c, "omote_renge", 0.3, {"launch": 14.0, "knock": 0.0, "kind": "heavy"}))
	_launch_kick(pj, tt)
	if not pj.live(tt):
		return
	var hgt: float = float(tt.get("height")) if tt.get("height") != null else 1.8
	var hgl: float = float(c.get("height")) if c.get("height") != null else 1.8
	var hs = clampf(hgt / 1.8, 0.5, 8.0)   # hedef boyu: sargı yarıçapı / eni bedenle büyür
	var cb = _bone(tt, "UpperChest")
	if cb == null:
		cb = _bone(tt, "Chest")
	var S = {"c": c, "t": tt, "fd": fd, "hgt": hgt, "hgl": hgl, "hs": hs, "g0": pj.gp(tt.global_position),
		"H": 10.0 + hgt * 0.3, "rad": 0.27 * hs, "turns": 7.0, "yaw": atan2(fd.x, fd.z), "yawL": atan2(-fd.x, -fd.z), "spin": 0.0,
		"kick": c.global_position + Vector3.UP * hgl * 0.55, "tb": [_bone(tt, "Hips"), cb],
		"lb": [[_bone(c, "LeftLowerArm"), _bone(c, "LeftHand")], [_bone(c, "RightLowerArm"), _bone(c, "RightHand")]],
		"slam": false, "slam_age": LT_SLAM, "lee_done": false, "tgt_done": false, "fz": {}, "ev": {}}
	var md = c.get("model")
	if md and md.get("rig"):
		md.rig.reach_arms = []   # avuç uzatma IK'si kavrayış pozuyla çakışmasın
	# oyuncu gövdesi fizik karelerinden yumuşatılır (interpolasyon): sıra boyunca kapat, yoksa her karede yazılan
	# dönüş / konum fizik adımının dik duruşuyla karışır (atan yan yatık görünüyordu); bitince eski hâline döner
	for n in [c, tt]:
		S["pim_%d" % n.get_instance_id()] = n.physics_interpolation_mode
		n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var im = ImmediateMesh.new()
	var mi = _mi(im, null)
	mi.extra_cull_margin = 64.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	S["im"] = im
	var tk = _tick(pj, Vector3.ZERO, func(_n, dt, age) -> bool: return _lotus_step(pj, S, dt, age))
	tk.add_child(mi)
	tk.name = "OmoteRenge"


## Bedeni merkezinden yerleştir: model (pitch, yaw) ile döner, düğüm ayak tarafına düşer (başaşağıyken ayaklar üstte)
static func _lotus_place(n: Node3D, ctr: Vector3, pitch: float, yaw: float, h: float) -> void:
	var md = n.get("model")
	var B = Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var mp = (md as Node3D).position if md else Vector3.ZERO
	n.global_position = ctr - B * (Vector3.UP * h * 0.55) - mp
	if md:
		md.rotation = Vector3(pitch, yaw, 0.0)
	if "velocity" in n:
		n.velocity = Vector3.ZERO


static func _lotus_pose(n: Node3D, pose: Dictionary) -> void:
	if n == null or not is_instance_valid(n):
		return
	var md = n.get("model")
	if md == null or md.get("overlay") == null:
		return
	md.overlay.cast_pose = pose
	md.overlay.set_pose("cast", 0.0 if pose.is_empty() else 1.0)


## Modeli dik konuma ve kendi pozuna geri ver
static func _lotus_free(n: Node3D, S: Dictionary) -> void:
	if n == null or not is_instance_valid(n):
		return
	_lotus_pose(n, {})
	var md = n.get("model")
	if md:
		md.rotation.x = 0.0
		md.rotation.z = 0.0
	var key = "pim_%d" % n.get_instance_id()
	if S.has(key):
		n.physics_interpolation_mode = S[key]
		S.erase(key)
		n.reset_physics_interpolation()


static func _lotus_hang(H: float, a: float) -> float:
	return H + 0.12 * sin((a - LT_RISE) * 4.0)


## Kare kare sıra: hedefin ve atanın gövdesini sürer, sargıyı çizer
static func _lotus_step(pj: PathJutsu, S: Dictionary, dt: float, age: float) -> bool:
	var c = S["c"]
	var tt = S["t"]
	var cl = is_instance_valid(c) and not c.is_dead()
	var tl = is_instance_valid(tt) and not tt.is_dead()
	var ev: Dictionary = S["ev"]
	if not S["slam"] and not (cl and tl):
		# biri öldü / silindi: tutuş çözülür, sargı olduğu yerde gevşeyip düşer
		if tl:
			S["fz"] = _lotus_frame(S)
		S["slam"] = true
		S["slam_age"] = age
		_lotus_free(c if is_instance_valid(c) else null, S)
		_lotus_free(tt if is_instance_valid(tt) else null, S)
		S["lee_done"] = true
		S["tgt_done"] = true
	if not S["slam"]:
		var hgt: float = S["hgt"]
		var H: float = S["H"]
		var c0: Vector3 = S["g0"] + Vector3.UP * hgt * 0.55
		var pitch = 0.0
		var ct: Vector3
		if age < LT_RISE:
			var u = age / LT_RISE
			ct = c0 + Vector3.UP * H * (1.0 - (1.0 - u) * (1.0 - u))
		elif age < LT_HUG.y:
			ct = c0 + Vector3.UP * _lotus_hang(H, age)
		elif age < LT_FLIP:
			var u = (age - LT_HUG.y) / (LT_FLIP - LT_HUG.y)
			ct = c0 + Vector3.UP * (_lotus_hang(H, LT_HUG.y) + 0.45 * (1.0 - (1.0 - u) * (1.0 - u)))
			pitch = -PI * smoothstep(0.0, 1.0, u)
			if not ev.has("flip"):
				ev["flip"] = true
				Sfx.play("whoosh", ct, 0.8)
		else:
			var u = clampf((age - LT_FLIP) / (LT_SLAM - LT_FLIP), 0.0, 1.0)
			ct = c0 + Vector3.UP * lerpf(_lotus_hang(H, LT_HUG.y) + 0.45, -0.1 * hgt, u * u)
			pitch = -PI
			S["spin"] = float(S["spin"]) + lerpf(5.0, 30.0, u) * dt
			if not ev.has("drill"):
				ev["drill"] = true
				_drill_lines(pj, S, LT_SLAM - LT_FLIP + 0.05)
				Sfx.play("whoosh", ct, 0.6)
		var yaw: float = float(S["yaw"]) + float(S["spin"])
		S["ct"] = ct
		_lotus_place(tt, ct, pitch, yaw, hgt)
		if tt is Enemy:   # havada bağlıyken toparlanıp hamle yapamaz (kanon: sargıyla kolları bedene bağlı)
			tt.state = "knockdown"
			tt.state_t = 0.0
		if age >= LT_TOUCH:
			# sargıya girince gövde dik kalır: yere serilme klibi (sırtüstü yatış) kalçayı düşürüp bedeni sargıdan çıkarıyordu
			var tm = tt.get("model")
			if tm and tm.has_method("play") and tm.get("current") != "fall":
				tm.play("fall", 0.12, 1.0, true)
		if age >= LT_TIGHT.x:
			_lotus_pose(tt, LP_BOUND)
		# atan: tekme → gölge gibi arkasında (aşağıda) yükseliş → arkadan kavrayış → birlikte başaşağı
		if age < LT_LET:
			var B = Basis.from_euler(Vector3(pitch, yaw, 0.0))
			var fd: Vector3 = S["fd"]
			var lag = lerpf(1.7, 0.75, smoothstep(0.2, 0.75, age))
			var follow = ct + fd * 0.85 - Vector3.UP * lag
			var cp: Vector3
			if age < 0.2:
				cp = S["kick"]
				_lotus_place(c, cp, 0.0, S["yawL"], S["hgl"])
				_lotus_pose(c, LP_KICK)
			elif age < LT_HUG.x:
				var k = smoothstep(0.2, 0.45, age)
				cp = (S["kick"] as Vector3).lerp(follow, k)
				_lotus_place(c, cp, 0.0, lerp_angle(S["yawL"], S["yaw"], k), S["hgl"])
				_lotus_pose(c, LP_FLING)
				if not ev.has("air"):
					ev["air"] = true
					_afterimage(pj, c)   # Kage Buyō: yerdeki kalıntı gölge, beden hedefin ardında
					pj.anim(c, "air", 1.4)
			else:
				var hug = ct + B * Vector3(0.0, -0.1, (float(S["rad"]) * 0.8 + 0.14))   # göğsü hedefin sırtında
				cp = follow.lerp(hug, smoothstep(LT_HUG.x, LT_HUG.y, age))
				_lotus_place(c, cp, pitch, yaw, S["hgl"])
				_lotus_pose(c, LP_HUG)
			S["lc"] = cp
		if age >= LT_FLY and not ev.has("unspool"):
			ev["unspool"] = true
			Sfx.play("whoosh", S["lc"], 1.3)
		if age >= LT_SLAM - 1.0 / 120.0:
			_lotus_impact(pj, S, age)
	# atan son anda bırakır: ileri takla atıp hedefin yanına iner
	if age >= LT_LET and not S["lee_done"] and cl:
		if not S.has("rel"):
			S["rel"] = S["lc"]
			S["rel_yaw"] = float(S["yaw"]) + float(S["spin"])
			_lotus_pose(c, LP_TUCK)
		var k = clampf((age - LT_LET) / 0.45, 0.0, 1.0)
		var land = pj.gp((S["g0"] as Vector3) + (S["fd"] as Vector3) * 2.6) + Vector3.UP * float(S["hgl"]) * 0.55
		var p = (S["rel"] as Vector3).lerp(land, k) + Vector3.UP * 1.1 * sin(k * PI)
		_lotus_place(c, p, lerpf(-PI, -TAU, smoothstep(0.0, 1.0, k)), S["rel_yaw"], S["hgl"])
		if k >= 1.0:
			S["lee_done"] = true
			_lotus_free(c, S)
			pj.anim(c, "land", 1.4)
	# çakılış sonrası: hedef kısa an başı gömülü kalır, sonra yere yığılır
	if S["slam"] and not S["tgt_done"] and is_instance_valid(tt):
		if tl and age < float(S["slam_age"]) + 0.2:
			_lotus_place(tt, S["ct"], -PI, float(S["yaw"]) + float(S["spin"]), S["hgt"])
		else:
			S["tgt_done"] = true
			_lotus_free(tt, S)
			tt.global_position = pj.gp(S["ct"])
	_lotus_band(S, age, cl)
	if S["slam"] and age > float(S["slam_age"]) + LT_POST:
		if not S["lee_done"] and cl:
			return true   # atan hâlâ inişte
		for b in S["tb"]:
			if b != null and is_instance_valid(b):
				b.queue_free()
		for pr in S["lb"]:
			for b in pr:
				if b != null and is_instance_valid(b):
					b.queue_free()
		return false
	return true


## Çakılış: krater, sarsıntı, ağır hasar (hedef + çevresi)
static func _lotus_impact(pj: PathJutsu, S: Dictionary, age: float) -> void:
	S["fz"] = _lotus_frame(S)
	S["slam"] = true
	S["slam_age"] = age
	var c = S["c"]
	var p = pj.gp(S["ct"])
	_crater(pj, p, maxf(1.0, float(S["hs"]) * 0.7))
	pj.shake(0.9)
	Sfx.play("boom", p, 0.8)
	pj.hit(c, p + Vector3.UP * 0.6, 3.0 * maxf(1.0, float(S["hs"]) * 0.7), pj.inf(c, "omote_renge", 1.4, {"knock": 8.0, "kind": "heavy"}))


## Sarılan bedenin çerçevesi (gerçek kemiklerden: kalça → üst göğüs; dönüşü ve ters dönüşü izler)
static func _lotus_frame(S: Dictionary) -> Dictionary:
	var tt: Node3D = S["t"]
	var hs: float = S["hs"]
	var md = tt.get("model")
	var bas: Basis = (md as Node3D).global_basis.orthonormalized() if md else Basis()
	var hip: Vector3
	var chest: Vector3
	var hb = S["tb"][0]
	var cb = S["tb"][1]
	if hb != null and is_instance_valid(hb) and cb != null and is_instance_valid(cb):
		hip = hb.global_position
		chest = cb.global_position
	else:
		var o: Vector3 = (md as Node3D).global_position if md else tt.global_position
		hip = o + bas.y * float(S["hgt"]) * 0.5
		chest = o + bas.y * float(S["hgt"]) * 0.74
	var A = (chest - hip).normalized() if chest.distance_to(hip) > 0.01 else bas.y
	var f = -bas.z
	var R0 = f - A * A.dot(f)
	R0 = R0.normalized() if R0.length() > 0.01 else A.cross(Vector3.RIGHT).normalized()
	return {"lo": hip - A * 0.14 * hs, "hi": chest + A * 0.05 * hs, "A": A, "R0": R0, "R1": A.cross(R0)}


## Sarmal üstündeki nokta: f 0..1 (yukarıdan aşağı tur tur); loose 1: animedeki geniş, eğik, kaotik halkalar → 0: sıkı sarım
static func _coil_pt(fr: Dictionary, S: Dictionary, s: int, f: float, loose: float, age: float) -> Array:
	var rad: float = S["rad"]
	var turns: float = S["turns"]
	var A: Vector3 = fr["A"]
	var lo: Vector3 = fr["lo"]
	var hi: Vector3 = fr["hi"]
	var pitch = lo.distance_to(hi) / turns
	var th = s * PI + f * turns * TAU
	var sd = 1.7 + s * 2.3
	var cen = hi.lerp(lo, f) - A * pitch * 0.5 * s
	var r = rad + (s * 0.008 + f * 0.014) * float(S["hs"]) + loose * rad * (1.1 + 0.75 * sin(th * 0.43 + sd + age * 2.0))
	var radial: Vector3 = (fr["R0"] as Vector3) * cos(th) + (fr["R1"] as Vector3) * sin(th)
	var tilt = loose * rad * 1.3 * sin(th + sd + 1.8 * sin(th * 0.21 + sd))
	return [cen + radial * r + A * tilt, radial]


## Sargı: iki önkoldan çözülen iki bant — uçuş, bedene kaotik halkalar, sıkı sarım, atanın koluna gergin bağ,
## serbest ucun rüzgârda çırpınması (ikincil hareket); çakılıştan sonra gevşeyip yere yığılır ve söner
static func _lotus_band(S: Dictionary, age: float, cl: bool) -> void:
	var im: ImmediateMesh = S["im"]
	im.clear_surfaces()
	if age < LT_FLY:
		return
	var tt = S["t"]
	var post: bool = S["slam"]
	var fr: Dictionary
	if post:
		fr = S["fz"]
	elif is_instance_valid(tt):
		fr = _lotus_frame(S)
	if fr.is_empty():
		return
	var hs: float = S["hs"]
	var hw = 0.045 * hs
	var ur = clampf((age - float(S["slam_age"])) / LT_POST, 0.0, 1.0) if post else 0.0
	var loose = ur * 1.4 if post else 1.0 - smoothstep(LT_TIGHT.x, LT_TIGHT.y, age)
	var w = 1.0 if post else clampf((age - LT_TOUCH) / (LT_WRAP - LT_TOUCH), 0.0, 1.0)
	w = 1.0 - (1.0 - w) * (1.0 - w)
	var al = 1.0 - smoothstep(0.55, 1.0, ur)
	var held = cl and not post and not S.has("rel")
	var gy = (S["g0"] as Vector3).y
	var lc: Vector3 = S.get("lc", fr["hi"])
	for s in 2:
		var anchor = Vector3.ZERO
		var have_anchor = false
		var lb: Array = S["lb"][s]
		if held:
			if lb[0] != null and is_instance_valid(lb[0]) and lb[1] != null and is_instance_valid(lb[1]):
				anchor = (lb[0] as Node3D).global_position.lerp((lb[1] as Node3D).global_position, 0.55)
			else:
				anchor = lc + Vector3.UP * 0.3 + (S["fd"] as Vector3).cross(Vector3.UP) * (0.3 if s == 0 else -0.3)
			have_anchor = true
		var out = (anchor - lc).normalized() if have_anchor and anchor.distance_to(lc) > 0.01 else Vector3.UP
		if age < LT_TOUCH:
			if not have_anchor:
				continue
			# uçuş: bant ucu önkoldan geniş bir yay çizip bedenin yanına gelir, arkasında dalgalanan bant
			var k = clampf((age - LT_FLY) / (LT_TOUCH - LT_FLY), 0.0, 1.0)
			var e = k * k * (3.0 - 2.0 * k)
			var c0 = _coil_pt(fr, S, s, 0.0, 1.0, age)
			var cp: Vector3 = c0[0]
			var tip = _bz(anchor, anchor + out * 1.3 + Vector3.UP * 0.5, cp + (c0[1] as Vector3) * 1.4 * hs + Vector3.UP * 0.4, cp, e)
			var perp = (anchor - tip).cross(Vector3.UP)
			perp = perp.normalized() if perp.length() > 0.01 else Vector3.RIGHT
			var pts = []
			for i in 19:
				var u = i / 18.0
				pts.append(_bz(tip, tip.lerp(anchor, 0.33) + perp * 0.5 * sin(age * 9.0 + s * 2.0), anchor + out * 0.6, anchor, u)
					+ perp * 0.12 * sin(u * 9.0 - age * 16.0 + s) * (1.0 - u))
			_band_free(im, pts, hw, Vector3.UP, 2.5, age * 6.0 + s, al)
			continue
		# sarmal
		var M = int(ceil(float(S["turns"]) * 24.0 * w)) + 1
		var cps = []
		var rds = []
		for i in M + 1:
			var f = w * float(i) / M
			var q = _coil_pt(fr, S, s, f, loose, age)
			var p: Vector3 = q[0]
			if post:   # gevşeyen halkalar yere yığılır
				p.y = lerpf(p.y, maxf(gy + 0.03 + 0.02 * sin(i * 1.7), p.y - 6.0 * ur * ur), smoothstep(0.0, 0.8, ur))
			cps.append(p)
			rds.append(q[1])
		var A: Vector3 = fr["A"]
		var W = []
		var N = []
		for i in cps.size():
			var tn: Vector3 = (cps[mini(i + 1, cps.size() - 1)] as Vector3) - (cps[maxi(i - 1, 0)] as Vector3)
			tn = tn.normalized() if tn.length() > 1e-5 else Vector3.RIGHT
			var wd = A - tn * A.dot(tn)
			wd = wd.normalized() if wd.length() > 0.05 else tn.cross(rds[i]).normalized()
			W.append(wd * hw)
			N.append(rds[i])
		_band_strip(im, cps, W, N, al)
		# serbest uç: dalışta hava akımıyla yukarı, yoksa yerçekimiyle aşağı sarkıp çırpınır
		var t0: Vector3 = ((cps[0] as Vector3) - (cps[1] as Vector3)).normalized() if cps.size() > 1 else Vector3.UP
		var drag = Vector3.UP if (age > LT_FLIP and not post) else Vector3.DOWN
		var tdir = (t0 * 0.45 + drag * 0.55).normalized()
		var tb = tdir.cross(A)
		tb = tb.normalized() if tb.length() > 0.01 else Vector3.RIGHT
		var tail = []
		for j in 8:
			var v = j / 7.0
			tail.append((cps[0] as Vector3) + tdir * v * 0.5 * hs + tb * 0.09 * hs * v * sin(age * 22.0 + j * 1.3 + s * 2.0))
		_band_free(im, tail, hw, A, 0.8, 0.0, al)
		# atanın önkoluna gergin bağ
		if have_anchor:
			var pe: Vector3 = cps[cps.size() - 1]
			var te: Vector3 = (pe - (cps[maxi(0, cps.size() - 2)] as Vector3)).normalized()
			var lead = []
			for i in 15:
				var u = i / 14.0
				lead.append(_bz(pe, pe + te * 0.6 * hs, anchor + out * 0.4, anchor, u) + Vector3.UP * 0.05 * sin(u * PI) * sin(age * 12.0 + s))
			_band_free(im, lead, hw, A, 1.2, 0.0, al)


# ═════════════════════════════════════════ 2) Izanami ═════════════════════════════════════════

## Kuzgun: kara-mor gövde, gaga, kuyruk; iki kanat menteşeli (çırpar). Ön +Z.
static func _crow() -> Node3D:
	var root = Node3D.new()
	var body = _built("crow_body", func():
		var b = MB.new()
		var K = Color(0.07, 0.06, 0.1)
		b.add("sphere", Vector3.ZERO, Vector3(0.22, 0.2, 0.42), K, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0, 0.07, 0.22), Vector3(0.17, 0.16, 0.18), K, Vector3.ZERO, 10)
		b.add("cone", Vector3(0, 0.06, 0.35), Vector3(0.05, 0.12, 0.05), Color(0.2, 0.19, 0.22), Vector3(90, 0, 0), 6)
		b.add("box", Vector3(0, 0.0, -0.3), Vector3(0.16, 0.02, 0.22), K, Vector3(-8, 0, 0))
		b.add("sphere", Vector3(0.06, 0.1, 0.28), Vector3(0.03, 0.03, 0.02), Color(0.75, 0.1, 0.1), Vector3.ZERO, 6)
		b.add("sphere", Vector3(-0.06, 0.1, 0.28), Vector3(0.03, 0.03, 0.02), Color(0.75, 0.1, 0.1), Vector3.ZERO, 6)
		return b)
	var wing = _built("crow_wing", func():
		var b = MB.new()
		var K = Color(0.09, 0.07, 0.12)
		b.add("box", Vector3(0.2, 0, 0), Vector3(0.4, 0.02, 0.2), K)
		for q in 4:
			b.add("box", Vector3(0.36 + q * 0.03, 0, -0.08 - q * 0.04), Vector3(0.1, 0.015, 0.16), K.lightened(0.05), Vector3(0, -15 - q * 8, 0))
		return b)
	root.add_child(_solid_mi(body, 0.012))
	var wings = []
	for sx in [-1.0, 1.0]:
		var piv = Node3D.new()
		piv.position = Vector3(sx * 0.08, 0.05, 0.0)
		var wm = _solid_mi(wing, 0.01)
		wm.scale = Vector3(sx, 1.0, 1.0)
		piv.add_child(wm)
		root.add_child(piv)
		wings.append(piv)
	root.set_meta("wings", wings)
	return root


## Kara tüy (yassı, uzun baklava)
static func _feather_mesh() -> ArrayMesh:
	return _built("feather", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.05, 0.005, 0.22), Color(0.08, 0.06, 0.11), Vector3.ZERO, 6)
		b.add("box", Vector3(0, 0.004, 0), Vector3(0.006, 0.004, 0.22), Color(0.25, 0.22, 0.3))
		return b)


## Döngü sahnesi: kurbanın çevresinde dönen kuzgunlar (6 sn), çivit gölge, geriye dönen üç tomoe; break'ten sonra kuzgunlar dağılır
static func _loop_stage(pj: PathJutsu, anchor: Vector3, dur: float) -> Dictionary:
	var g = pj.gp(anchor)
	_ground(pj, g, 3.6, dur + 0.4, {"mode": 1, "tint": Color(TEAL, 0.42), "tint2": Color(0.05, 0.1, 0.12, 0.55), "seed": randf() * 9.0}, 0.6)
	var state = {"kick": 0.0}
	# kuzgunlar
	var crows = []
	for k in 3:
		var cr = _crow()
		_scene(pj).add_child(cr)
		cr.global_position = anchor + Vector3.UP * 2.0
		crows.append(cr)
	var R = [2.4, 2.9, 2.1]
	var H = [2.2, 2.9, 1.6]
	_tick(pj, anchor, func(_n, _dt, age) -> bool:
		var out = age > dur
		if age > dur + 1.1:
			for cr in crows:
				if is_instance_valid(cr):
					cr.queue_free()
			return false
		for k in crows.size():
			var cr: Node3D = crows[k]
			if not is_instance_valid(cr):
				continue
			var ph = age * (1.1 + k * 0.25) * (1.0 if k != 1 else -1.0) + k * 2.1
			var r = R[k] + (pow(age - dur, 2.0) * 22.0 if out else 0.0)
			var p = anchor + Vector3(cos(ph) * r, H[k] + sin(age * 2.0 + k) * 0.3 + (age - dur) * 4.0 * float(out), sin(ph) * r)
			var tg = Vector3(-sin(ph), 0.0, cos(ph)) * (1.0 if k != 1 else -1.0)
			cr.global_transform = Transform3D(_look_basis(tg, 1.0 if not out else maxf(0.05, 1.0 - (age - dur))), p)
			for wv in cr.get_meta("wings"):
				var piv: Node3D = wv
				piv.rotation.z = sin(age * 15.0 + k) * 0.75 * signf(piv.position.x)
		return true)
	# üç tomoe: kurbanın göğsü hizasında yatay döner; her geri sarmada hızla ters döner
	var tom = Node3D.new()
	var tmesh = _built("tomoe", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.18, 0.05, 0.18), Color(0.08, 0.02, 0.03), Vector3.ZERO, 10)
		Loft.tube(b, [Vector3(0.0, 0, -0.05), Vector3(0.1, 0, -0.14), Vector3(0.24, 0, -0.12)], [0.06, 0.04, 0.012], Color(0.08, 0.02, 0.03), 6, 3)
		return b)
	for k in 3:
		var a = TAU * k / 3.0
		var mi = _solid_mi(tmesh, 0.0)
		mi.position = Vector3(cos(a) * 1.15, 0.0, sin(a) * 1.15)
		mi.rotation.y = -a
		tom.add_child(mi)
	_scene(pj).add_child(tom)
	tom.global_position = anchor + Vector3.UP * 1.05
	tom.scale = Vector3.ONE * 0.01
	_tick(pj, anchor, func(_n, dt, age) -> bool:
		if not is_instance_valid(tom):
			return false
		if age > dur + 0.4:
			tom.queue_free()
			return false
		state["kick"] = maxf(0.0, float(state["kick"]) - dt * 2.5)
		tom.rotation.y += dt * (0.9 - float(state["kick"]) * 14.0)
		var sc = minf(1.0, age / 0.4) * clampf((dur + 0.4 - age) / 0.4, 0.0, 1.0)
		tom.scale = Vector3.ONE * maxf(0.01, sc)
		return true)
	return state


## Atanın gözü: kızıl Sharingan pırıltısı, yanakta kan izi; süre sonunda göz kapağı gibi kapanır
static func _closing_eye(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hb = _bone(c, "Head")
	if hb == null:
		return
	var glint = _mi(_quad(), _soft_c(Color(1.0, 0.15, 0.12, 0.95), true))
	glint.position = Vector3(0.032, 0.06, 0.1)
	glint.scale = Vector3(0.07, 0.07, 0.07)
	hb.add_child(glint)
	var tear = _built("blood_tear", func():
		var b = MB.new()
		b.add("box", Vector3(0, -0.025, 0), Vector3(0.006, 0.05, 0.004), Color(0.55, 0.02, 0.04))
		b.add("sphere", Vector3(0, -0.052, 0), Vector3(0.01, 0.012, 0.006), Color(0.55, 0.02, 0.04), Vector3.ZERO, 6)
		return b)
	var tm = _mi(tear, _solid())
	tm.position = Vector3(0.032, 0.05, 0.098)
	tm.scale = Vector3(1.0, 0.05, 1.0)
	hb.add_child(tm)
	_tick(pj, Vector3.ZERO, func(_n, _dt, age) -> bool:
		if not is_instance_valid(hb) or not is_instance_valid(glint):
			return false
		if age >= dur:
			hb.queue_free()
			return false
		var cam = _cam(glint)
		var p = glint.global_position
		var close = clampf((age - (dur - 0.6)) / 0.6, 0.0, 1.0)
		glint.global_transform = Transform3D(_face_basis(cam - p, 0.08, maxf(0.001, 0.08 * (1.0 - close)), 0.0), p)
		tm.scale = Vector3(1.0, maxf(0.05, minf(1.0, age / 1.2)), 1.0)
		return true)


## Donmuş an: kurbanın o anki pozu soluk, titreşimli kopya olarak kalır
static func _echo(pj: PathJutsu, tt: Node3D, shift: Vector3) -> Node3D:
	var m = _ghost_mat(Color(0.74, 0.84, 0.92, 0.5), Color(0.95, 1.0, 1.0, 0.95), 7.0)
	var g = _ghost(pj, tt, m, shift)
	g.set_meta("m", m)
	g.set_meta("f", 1.0)
	m.set_shader_parameter("fade", 0.0)
	var tw = g.create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("fade", v), 0.0, 1.0, 0.15)
	return g


## Izanami (kanon, Itachi): kurban iki anın arasında döngüye hapsolur — her seferinde aynı ana geri sarılır; döngüden
## yalnız kaderini kabul ederek çıkar (Kabuto Edo Tensei'yi bıraktı). Bedeli: kullanıcının bir gözü sonsuza dek kararır.
## Oyunda: 6 sn döngü (her 1 sn başa sarılır), sonunda boss olmayan düşman savaşmayı bırakır; boss/oyuncu ağır sersemler.
static func izanami(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	if tt == null:
		if c is Player:
			Hud.msg("Izanami: döngüye alınacak hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var gm = Eyes.genjutsu_land(c, tt, true)
	if gm <= 0.0:
		return
	pj.busy(c, 0.8)
	_closing_eye(pj, c, 6.0)
	var anchor = tt.global_position
	var pale = Color(0.92, 0.97, 1.0, 0.85)
	Sfx.play("genjutsu", anchor, 0.6)
	pj.st(tt, "stun", 6.2)
	# kurban oyuncuysa dünyası soğur (aynı anı yaşıyor): soluk çivit perde döngü boyunca
	if tt is Player and Game.world and Game.world.env:
		Game.world.env.flash_tint(Color(0.62, 0.72, 0.76, 0.3), 6.0)
	var stage = _loop_stage(pj, anchor, 6.0)
	var echoes: Array = []
	var trail = _stripm(Color(1, 1, 1, 0.9), Color(0.7, 0.85, 0.9, 0.5), 0.4)
	# döngü: her saniye kurban aynı ana geri sarılır — terk ettiği an donmuş ak bir kopya olarak kalır, kopyalar birikir
	for k in 6:
		pj.after(k * 1.0, func():
			if not pj.live(tt):
				return
			var from = tt.global_position
			if k > 0:
				# kopya kurbanın ardında, her döngüde biraz daha geride ve sırayla sağa-sola (iz gibi okunur); eskiler solar
				var bk = -tt.face_dir() if tt.has_method("face_dir") else Vector3.BACK
				var sd = bk.cross(Vector3.UP) * (0.55 if k % 2 == 0 else -0.55)
				for e in echoes:
					if is_instance_valid(e):
						var f = maxf(0.15, float(e.get_meta("f")) - 0.14)
						e.set_meta("f", f)
						(e.get_meta("m") as ShaderMaterial).set_shader_parameter("fade", f)
				echoes.append(_echo(pj, tt, bk * (0.6 + 0.55 * k) + sd))
			tt.global_position = anchor
			if tt.get("model"):
				tt.model.play(["hit", "block", "idle", "hit", "crouch", "idle"][k], 0.02, 1.2, true)
				var m = tt.model
				var tw = m.create_tween()
				for f in 3:
					tw.tween_callback(func(): if is_instance_valid(m): m.visible = false)
					tw.tween_interval(0.04)
					tw.tween_callback(func(): if is_instance_valid(m): m.visible = true)
					tw.tween_interval(0.05)
			stage["kick"] = 1.0
			# geri sarma: kopyadan bedene akan ince soluk çizgiler (zamanda geri akış)
			for n in 8:
				var q = Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 1.8), randf_range(-0.5, 0.5))
				var pa = from + q
				var pb = anchor + q * 0.6
				_ribbon(pj, func(u, _age): return pa.lerp(pb, u) + Vector3.UP * sin(u * PI) * 0.3, 0.42, 0.025, trail, 10,
					{"reveal": 0.25, "tail": 0.6, "taper": 3, "delay": n * 0.02})
			# kuzgun tüyleri savrulur
			_spray(pj, anchor + Vector3.UP * 2.2, 7, {"mesh": _feather_mesh(), "mat": _solid(), "mode": "tumble", "spin": 4.0, "radius": 1.6,
				"spd": Vector2(0.2, 0.8), "dir": Vector3.DOWN, "spread": 70.0, "grav": 1.2, "drag": 1.5, "life": Vector2(1.4, 2.0),
				"size": Vector2(0.8, 1.2), "cols": [Color.WHITE]})
			if tt is Player:
				if Game.world and Game.world.env:
					Game.world.env.screen_flash(0.35)
			Sfx.play("genjutsu", anchor, 0.35))   # kanon: Izanami hasar vermez, yalnız hapseder
	pj.after(6.1, func():
		for e in echoes:   # döngü kırılır: donmuş anlar soluk pullara dağılır
			if is_instance_valid(e):
				_spray(pj, e.global_position + Vector3.UP, 12, {"mat": _soft(false, false, 0.0, INK, 0.9, 0.15), "radius": 0.6,
					"spd": Vector2(0.4, 1.6), "dir": Vector3.UP, "spread": 120.0, "life": Vector2(0.7, 1.1), "size": Vector2(0.05, 0.1),
					"cols": [pale, Color(0.8, 0.9, 1.0, 0.0)]})
				var em: ShaderMaterial = e.get_meta("m")
				var tw = e.create_tween()
				tw.tween_method(func(v): em.set_shader_parameter("fade", v), float(e.get_meta("f")), 0.0, 0.5)
				tw.tween_callback(e.queue_free)
		_spray(pj, anchor + Vector3.UP * 2.4, 26, {"mesh": _feather_mesh(), "mat": _solid(), "mode": "tumble", "spin": 6.0, "radius": 2.6,
			"spd": Vector2(1.0, 3.0), "dir": Vector3.UP, "spread": 160.0, "grav": 1.5, "drag": 1.2, "life": Vector2(1.6, 2.4),
			"size": Vector2(0.8, 1.3), "cols": [Color.WHITE]})
		if not pj.live(tt):
			return
		if not (tt is Player) and not tt.has_meta("boss") and "team" in tt:
			# kaderini kabul etti: savaşmayı bırakır
			tt.team = "neutral"
			tt.set("target", null)
			if tt.get("model"):
				tt.model.play("idle", 0.2)
			Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Kaderini kabul etti...", Color(0.95, 0.85, 0.85))
		else:
			pj.st(tt, "stun", 2.5)
			pj.st(tt, "fear", 4.0)
			Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Döngüden kurtuldu", Color(0.95, 0.85, 0.85)))
	# kanon bedeli: bir göz sonsuza dek kararır (Izanagi ile aynı sistem; düşman da gözünü kaybeder)
	if c is Player and c.combat and c.combat.modes and c.combat.modes.eyes:
		c.combat.modes.eyes.izanagi_cost("İzanami")
	elif c.has_meta("eyes"):
		c.remove_meta("eyes")
		Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Gözü karardı", Color(0.7, 0.2, 0.25))


# ═════════════════════════════════════════ 3) Gedō — Rinne Tensei ═════════════════════════════════════════

## Cehennem Kralı başı (ön +Z): uzun soluk lavanta yüz, gözleri ve tepeyi geçen mor bant, halkalı Rinnegan gözler,
## iri burun, önünde altın 王 yazılı kara taç, taçtan geriye kıvrılan uzun ak teller, arkada açılan kızıl yaka,
## menteşeli alt çene (açılınca dişli kara ağız). Boy ~8 m. Dönen: {"root", "jaw", "mouth"(yerel)}
static func _king() -> Dictionary:
	var root = Node3D.new()
	var head = _built("king_head", func():
		var b = MB.new()
		var SK = Color(0.88, 0.86, 0.92)
		var SKD = Color(0.74, 0.7, 0.8)
		var PUR = Color(0.4, 0.2, 0.5)
		var RED = Color(0.45, 0.06, 0.09)
		var REDI = Color(0.26, 0.03, 0.06)
		var BLK = Color(0.07, 0.06, 0.08)
		var WHT = Color(0.97, 0.97, 0.95)
		for k in 13:   # yaka: başın arkasında yay, dışa açılan kızıl paneller
			var ang = lerpf(-1.7, 1.7, k / 12.0)
			var dv = Vector3(sin(ang), 0.0, -cos(ang))
			var yaw = rad_to_deg(atan2(dv.x, dv.z))
			b.add("box", dv * 2.3 + Vector3(0, 2.6, 0), Vector3(1.05, 5.4 - absf(ang) * 0.9, 0.16), RED, Vector3(-16, yaw, 0))
			b.add("box", dv * 2.16 + Vector3(0, 2.6, 0), Vector3(1.0, 5.2 - absf(ang) * 0.9, 0.06), REDI, Vector3(-16, yaw, 0))
		Loft.blob(b, Vector3(0, 3.4, 0), Vector3.UP, 5.2, [Vector2(0.95, 0.85), Vector2(1.5, 1.25), Vector2(1.65, 1.38), Vector2(1.5, 1.3), Vector2(1.0, 0.95)], SK, 20, Callable(), Vector3(0, 0, 1))
		b.add("sphere", Vector3(0, 4.4, 0.95), Vector3(3.0, 1.3, 0.9), PUR, Vector3.ZERO, 16)   # göz bandı
		Loft.tube(b, [Vector3(0, 4.9, 1.15), Vector3(0, 5.7, 0.75), Vector3(0, 6.0, -0.2), Vector3(0, 5.5, -1.1)], [Vector2(0.3, 0.12), Vector2(0.32, 0.12), Vector2(0.3, 0.12), Vector2(0.2, 0.1)], PUR, 8, 3)
		for sx in [-1.0, 1.0]:
			var ep = Vector3(sx * 0.62, 4.4, 1.33)
			b.add("sphere", ep, Vector3(0.62, 0.38, 0.12), Color(0.86, 0.82, 0.95), Vector3(0, sx * 16, 0), 12)
			for q in 3:
				var s = 0.14 + q * 0.1
				b.add("torus", ep + Vector3(0, 0, 0.04 + q * 0.004), Vector3(s, s, s), Color(0.32, 0.2, 0.42), Vector3(90, sx * 16, 0), 14)
			b.add("sphere", ep + Vector3(0, 0, 0.05), Vector3(0.07, 0.07, 0.03), Color(0.25, 0.14, 0.32), Vector3.ZERO, 6)
			b.add("box", ep + Vector3(0, 0.32, 0.03), Vector3(0.8, 0.09, 0.06), BLK, Vector3(0, sx * 16, sx * 12))
		Loft.tube(b, [Vector3(0, 4.2, 1.4), Vector3(0, 3.6, 1.6), Vector3(0, 3.15, 1.65)], [0.18, 0.3, 0.36], SKD, 10, 3)
		for sx in [-1.0, 1.0]:
			b.add("sphere", Vector3(sx * 0.2, 3.08, 1.86), Vector3(0.12, 0.07, 0.05), BLK, Vector3.ZERO, 6)
		b.add("sphere", Vector3(0, 2.15, 1.0), Vector3(2.3, 1.4, 0.95), Color(0.14, 0.03, 0.05), Vector3.ZERO, 14)   # ağız içi
		for k in 9:   # üst dişler
			var x = lerpf(-0.95, 0.95, k / 8.0)
			b.add("box", Vector3(x, 2.62, 1.36 - absf(x) * 0.2), Vector3(0.2, 0.32, 0.12), WHT)
		b.add("box", Vector3(0, 6.3, 0.05), Vector3(1.6, 1.4, 1.4), BLK, Vector3(-4, 0, 0))   # taç
		b.add("cone", Vector3(0, 7.3, 0.0), Vector3(1.0, 0.7, 0.9), BLK, Vector3.ZERO, 4)
		b.add("box", Vector3(0, 6.1, 0.82), Vector3(1.35, 1.15, 0.1), BLK, Vector3(-4, 0, 0))
		b.add("box", Vector3(0, 6.85, 0.8), Vector3(1.2, 0.1, 0.12), WHT)
		for sx in [-1.0, 1.0]:   # tacın yan kanatları + geriye kıvrılan uzun ak teller
			b.add("box", Vector3(sx * 1.05, 6.25, 0.2), Vector3(0.7, 0.9, 0.08), BLK, Vector3(0, sx * -25, sx * -18))
			Loft.tube(b, [Vector3(sx * 0.5, 6.9, 0.3), Vector3(sx * 1.2, 8.2, -0.3), Vector3(sx * 2.0, 8.4, -1.4), Vector3(sx * 2.6, 7.0, -2.2), Vector3(sx * 2.8, 5.0, -2.4)], [0.12, 0.11, 0.09, 0.07, 0.02], WHT, 6, 4)
			Loft.tube(b, [Vector3(sx * 0.7, 6.8, 0.1), Vector3(sx * 1.6, 7.6, -0.6), Vector3(sx * 2.3, 7.2, -1.6), Vector3(sx * 2.4, 5.6, -2.0)], [0.07, 0.06, 0.05, 0.015], WHT.darkened(0.08), 6, 4)
		return b)
	var hm = _solid_mi(head, 0.05, true)
	root.add_child(hm)
	var jaw = Node3D.new()
	jaw.position = Vector3(0, 2.55, 0.35)
	root.add_child(jaw)
	var jm = _built("king_jaw", func():
		var b = MB.new()
		var SK = Color(0.86, 0.84, 0.9)
		Loft.blob(b, Vector3(0, -0.65, 0.55), Vector3(0, 0, 1), 2.2, [Vector2(1.2, 0.55), Vector2(1.35, 0.7), Vector2(1.1, 0.55), Vector2(0.6, 0.3)], SK, 16)
		b.add("sphere", Vector3(0, -0.3, 0.9), Vector3(1.8, 0.5, 1.2), Color(0.5, 0.12, 0.18), Vector3.ZERO, 12)   # dil / ağız tabanı
		for k in 8:
			var x = lerpf(-0.85, 0.85, k / 7.0)
			b.add("box", Vector3(x, -0.1, 1.45 - absf(x) * 0.25), Vector3(0.2, 0.28, 0.12), Color(0.97, 0.97, 0.95))
		return b)
	jaw.add_child(_solid_mi(jm, 0.045, true))
	var kanji = Label3D.new()
	kanji.text = "王"
	kanji.font_size = 160
	kanji.pixel_size = 0.005
	kanji.modulate = Color(0.98, 0.82, 0.2)
	kanji.outline_size = 0
	kanji.position = Vector3(0, 6.05, 0.885)
	kanji.rotation = Vector3(-0.07, 0.0, 0.0)
	root.add_child(kanji)
	return {"root": root, "jaw": jaw, "mouth": Vector3(0, 2.4, 1.6)}


## Gedō — Rinne Tensei no Jutsu (kanon): Cehennem Kralı yerden yükselir, ağzından ölülerin ruhlarını salar; ruhlar
## bedenlerine döner ve yakın zamanda ölmüş müttefikler dirilir. Bedeli kullanıcının yaşamıdır (Nagato'nun saçı ağardı ve öldü):
## burada çağıranın canı 1'e iner, 60 sn iyileşemez ve ağırlaşır (düşman çağıran aynı bedeli öder).
static func gedo_rinne_tensei_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 2.4)
	if c is Player:
		c.input_locked = 2.2
	var fd: Vector3 = c.face_dir()
	var at = pj.gp(c.global_position + fd * 5.0)
	# hazırlık: atanın ayağı altında Rinnegan halkaları; Kral'ın çıkacağı yerde yer yarılır
	_ground(pj, pj.gp(c.global_position), 3.2, 3.0, {"mode": 3, "tint": Color(0.75, 0.62, 0.95, 0.75), "tint2": Color(0.45, 0.3, 0.7, 0.75), "rings": 6.0, "width": 0.012}, 0.5)
	_cracks(pj, at, 5.5, 10, 9.0)
	var kh = _king()
	var head: Node3D = kh["root"]
	_scene(pj).add_child(head)
	head.global_position = at - Vector3.UP * 8.0
	head.rotation.y = atan2(-fd.x, -fd.z)   # Kral atana bakar
	_dust(pj, at, 26, {"flat": true, "radial": true, "radius": 2.6, "spd": Vector2(2.5, 5.0), "size": Vector2(1.4, 2.6), "life": Vector2(1.4, 2.2), "drag": 1.6, "dir": Vector3.UP})
	_debris(pj, at, 16, EARTH, 8.0, 0.4)
	var tw = head.create_tween()
	tw.tween_property(head, "global_position", at - Vector3.UP * 0.6, 0.7).set_trans(Tween.TRANS_BACK)
	tw.tween_property(kh["jaw"], "rotation:x", 0.75, 0.4)
	var now = Time.get_ticks_msec() / 1000.0
	var team = String(c.team)
	var targets: Array = []
	for f in Enemy.fallen:
		if String(f["team"]) == team and now - float(f["t"]) < 120.0 and (f["pos"] as Vector3).distance_to(c.global_position) < 70.0:
			targets.append(f)
	tw.tween_callback(func():
		if not is_instance_valid(head):
			return
		var mouth: Vector3 = head.global_transform * (kh["mouth"] as Vector3)
		var green = Color(0.75, 1.0, 0.85)
		var up_dir = (Vector3.UP + (head.global_transform.basis.z.normalized()) * 0.3).normalized()
		# referans: ağızdan göğe fışkıran yeşil ruh sağanağı (cel çizgiler) + kalın yeşil sis sütunu
		pj.every(1.4, 0.1, func(_i, _k):
			_spray(pj, mouth, 14, {"mat": _streak(), "mode": "stretch", "stretch": 0.07, "radius": 0.7, "spd": Vector2(14.0, 22.0),
				"dir": up_dir, "spread": 16.0, "life": Vector2(0.6, 1.0), "size": Vector2(0.5, 0.8),
				"cols": [Color(0.6, 1.0, 0.85, 0.95), Color(0.35, 0.95, 0.7, 0.8), Color(0.3, 0.9, 0.65, 0.0)]})
			_spray(pj, mouth, 3, {"mat": _soft(false, false, 0.25, Color(0.2, 0.7, 0.5), 0.6, 0.3), "radius": 0.5, "spd": Vector2(6.0, 10.0),
				"dir": up_dir, "spread": 12.0, "life": Vector2(0.8, 1.1), "size": Vector2(1.0, 1.6), "grow": 2.0, "drag": 0.6,
				"cols": [Color(0.55, 1.0, 0.8, 0.7), Color(0.4, 0.95, 0.7, 0.45), Color(0.4, 0.9, 0.7, 0.0)]}), Callable())
		var soul_m = _stripm(Color(0.85, 1.0, 0.92, 0.95), Color(0.35, 0.95, 0.65, 0.75), 0.4)
		for f in targets:
			var e = Enemy.new()
			e.setup(f["arch"])
			e.team = f["team"]
			e.set_meta("respawn", false)
			if f["teammate"]:
				e.set_meta("teammate", true)
				if String(f["friend_id"]) != "":
					e.set_meta("friend_id", f["friend_id"])
			_scene(pj).add_child(e)
			e.global_position = pj.gp(f["pos"])
			# ruh yay çizip bedene iner, beden üstünde yeşil sütun
			var body_p = e.global_position + Vector3.UP * 1.0
			_ribbon(pj, _arc_path(_const(mouth), _const(body_p), 9.0, 0.4, 3.0), 1.3, 0.22, soul_m, 24, {"reveal": 0.55, "tail": 0.6, "taper": 3})
			_spray(pj, e.global_position, 14, {"mat": _streak(), "mode": "stretch", "stretch": 0.1, "radius": 0.6, "flat": true, "delay": Vector2(0.5, 0.8),
				"spd": Vector2(3.0, 6.0), "dir": Vector3.UP, "spread": 8.0, "life": Vector2(0.5, 0.8), "size": Vector2(0.3, 0.5),
				"cols": [Color(0.7, 1.0, 0.85, 0.9), Color(0.4, 0.95, 0.7, 0.0)]})
			Combat.popup_text(e.global_position + Vector3.UP * 2.6, "Dirildi", green)
			Enemy.fallen.erase(f)
		# müttefikler tam iyileşir
		for a2 in pj.get_tree().get_nodes_in_group("fighters"):
			if not Combat.hostile(c, a2) and a2 != c and a2.global_position.distance_to(c.global_position) < 40.0 and a2.get("max_hp") != null:
				a2.hp = a2.max_hp
				_spray(pj, a2.global_position + Vector3.UP * 2.6, 8, {"mat": _soft(true, false, 0.0, INK, 0.8, 0.2), "radius": 0.5,
					"spd": Vector2(0.8, 1.6), "dir": Vector3.DOWN, "spread": 20.0, "life": Vector2(0.8, 1.1), "size": Vector2(0.1, 0.18),
					"cols": [Color(0.6, 1.0, 0.8, 0.0), Color(0.6, 1.0, 0.8, 0.9), Color(0.5, 1.0, 0.75, 0.0)]})
		if pj.live(c):
			c.hp = 1.0
			# yaşamın bedeli: atandan kül rengi tüller yükselir
			_spray(pj, c.global_position + Vector3.UP * 1.0, 16, {"mat": _soft(false, false, 0.3, Color(0.35, 0.35, 0.38), 0.6, 0.4), "radius": 0.4,
				"spd": Vector2(0.6, 1.4), "dir": Vector3.UP, "spread": 25.0, "life": Vector2(1.2, 1.8), "size": Vector2(0.25, 0.45), "grow": 2.0,
				"cols": [Color(0.8, 0.8, 0.82, 0.0), Color(0.75, 0.75, 0.78, 0.55), Color(0.6, 0.6, 0.62, 0.0)]})
			if c is Player:
				Buffs.add("rinne_bedel", 60.0, {"speed": 0.6, "melee": 0.6, "no_heal": 1.0, "_name": "Samsara Bedeli", "_desc": "yaşamını verdin: iyileşemezsin, ağırlaştın"})
			else:
				c.set_meta("rinne_bedel", true)
			Combat.popup_text(c.global_position + Vector3.UP * 2.8, "Yaşamın bedeli ödendi", Color(0.9, 0.9, 0.9))
			if c is Player and targets.is_empty():
				Hud.msg("Rinne Tensei: diriltilecek yakın zamanda ölmüş müttefik yok — müttefikler iyileşti.", Color(0.75, 1.0, 0.85)))
	tw.tween_interval(1.4)
	tw.tween_property(kh["jaw"], "rotation:x", 0.0, 0.3)
	tw.tween_callback(func():
		_dust(pj, at, 16, {"flat": true, "radial": true, "radius": 2.2, "spd": Vector2(2.0, 4.0), "size": Vector2(1.2, 2.2), "life": Vector2(1.2, 1.8), "dir": Vector3.UP}))
	tw.tween_property(head, "global_position", at - Vector3.UP * 8.0, 0.6)
	tw.tween_callback(head.queue_free)
	Sfx.play("fire", c.global_position, 0.6)


# ═════════════════════════════════════════ 4) Yılan Klonu ═════════════════════════════════════════

static func _snake_seg() -> ArrayMesh:
	return _built("snake_seg", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(1.0, 0.8, 1.4), SNAKE_W, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0, -0.18, 0), Vector3(0.8, 0.5, 1.3), SNAKE_B, Vector3.ZERO, 8)
		b.add("box", Vector3(0, 0.38, 0), Vector3(0.25, 0.06, 0.9), Color(0.72, 0.68, 0.8))
		return b)


static func _snake_head() -> ArrayMesh:
	return _built("snake_head", func():
		var b = MB.new()
		Loft.blob(b, Vector3(0, 0, 0.1), Vector3(0, 0, 1), 0.36, [Vector2(0.08, 0.06), Vector2(0.11, 0.07), Vector2(0.09, 0.055), Vector2(0.04, 0.03)], SNAKE_W, 10)
		for sx in [-1.0, 1.0]:
			b.add("sphere", Vector3(sx * 0.07, 0.035, 0.17), Vector3(0.035, 0.03, 0.03), Color(0.85, 0.7, 0.15), Vector3.ZERO, 6)
			b.add("box", Vector3(sx * 0.072, 0.036, 0.18), Vector3(0.006, 0.026, 0.01), INK)
			b.add("box", Vector3(sx * 0.012, -0.005, 0.38), Vector3(0.008, 0.008, 0.07), Color(0.75, 0.15, 0.25), Vector3(0, sx * 20, 0))
		return b)


## Kıvrık beyaz yılan yığını (klonun çöktüğü yer)
static func _snake_heap() -> ArrayMesh:
	return _built("snake_heap", func():
		var b = MB.new()
		for k in 6:
			var c0 = Vector3(randf_range(-0.35, 0.35), 0.12 + k * 0.1, randf_range(-0.35, 0.35))
			var pts = []
			var rr = randf_range(0.28, 0.45)
			var a0 = randf() * TAU
			for q in 9:
				var a = a0 + q * 0.75
				pts.append(c0 + Vector3(cos(a) * rr, sin(q * 0.9) * 0.06, sin(a) * rr))
			Loft.tube(b, pts, [0.06, 0.075, 0.08, 0.08, 0.075, 0.07, 0.06, 0.045, 0.02], SNAKE_W.darkened(k * 0.02), 8, 3)
		return b)


## Bir yılan: baş + 7 halka, yol boyunca sinüs çizerek sürünür; varınca done, 0.8 sn sonra küçülüp kaybolur
static func _snake_run(pj: PathJutsu, a: Vector3, b: Vector3, dur: float, wiggle: float, done: Callable) -> void:
	var root = Node3D.new()
	_scene(pj).add_child(root)
	root.global_position = Vector3.ZERO
	var hm = _solid_mi(_snake_head(), 0.008)
	root.add_child(hm)
	var segs = []
	for j in 7:
		var sm = _solid_mi(_snake_seg(), 0.006)
		root.add_child(sm)
		segs.append(sm)
	var d = b - a
	var sd = d.cross(Vector3.UP)
	sd = sd.normalized() if sd.length() > 0.001 else Vector3.RIGHT
	var ph = randf() * TAU
	var path = func(u: float) -> Vector3:
		var p = a.lerp(b, u) + sd * sin(u * TAU * 2.2 + ph) * wiggle * (1.0 - u * 0.7)
		var gy = Game.ground_height(p.x, p.z) + 0.08
		return Vector3(p.x, lerpf(gy, maxf(gy, b.y), pow(u, 4.0)), p.z)   # yerde sürünür, sonda ısırmak için kalkar
	var st = {"bit": false}
	_tick(pj, Vector3.ZERO, func(_n, _dt, age) -> bool:
		if not is_instance_valid(root):
			return false
		if age >= 1.0:
			root.queue_free()
			return false
		var u = clampf(age / dur, 0.0, 1.0)
		if u >= 1.0 and not st["bit"]:
			st["bit"] = true
			done.call()
		var shrink = clampf((1.0 - age) / 0.2, 0.0, 1.0)
		var hp: Vector3 = path.call(u)
		var hn: Vector3 = path.call(minf(1.0, u + 0.02))
		var tg = hn - hp if u < 1.0 else (b - a)
		hm.global_transform = Transform3D(_look_basis(tg, shrink), hp)
		for j in segs.size():
			var uj = maxf(0.0, u - (j + 1) * 0.05)
			var pj0: Vector3 = path.call(uj)
			var pj1: Vector3 = path.call(minf(1.0, uj + 0.02))
			var s = (0.17 - j * 0.014) * shrink
			(segs[j] as Node3D).global_transform = Transform3D(_look_basis(pj1 - pj0 if (pj1 - pj0).length() > 0.0001 else tg, s), pj0)
		return true)


## Yılan klonu: yerinde bir klon kalır, sen geri sıçrarsın; klon vurulunca yılan sürüsüne dağılıp çevreyi ısırır
static func hebi_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var at = c.global_position
	pj.decoy(c, at, 12.0, func(pos: Vector3):
		# klon beyaz yılan yığınına çöker
		var heap = _solid_mi(_snake_heap(), 0.01)
		pj.scene_add(heap, pj.gp(pos))
		heap.scale = Vector3(1.3, 2.4, 1.3)
		var htw = heap.create_tween()
		htw.tween_property(heap, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		htw.tween_interval(0.7)
		htw.tween_property(heap, "scale", Vector3(1.2, 0.05, 1.2), 0.5).set_ease(Tween.EASE_IN)
		htw.tween_callback(heap.queue_free)
		_dust(pj, pj.gp(pos), 6, {"flat": true, "radial": true, "radius": 0.5, "spd": Vector2(1.5, 3.0), "size": Vector2(0.3, 0.55), "life": Vector2(0.5, 0.8)})
		var near = pj.enemies_near(c, pos, 11.0)
		for k in 8:
			var e = near[k % near.size()] if not near.is_empty() else null
			var to = e.global_position + Vector3.UP * 0.6 if e else pos + Vector3(cos(k * 0.785), 0, sin(k * 0.785)) * 7.0
			_snake_run(pj, pos + Vector3.UP * 0.6, to, 0.35 + k * 0.03, 0.6, func():
				if e and pj.live(e):
					# zehirli ısırık (ana ağaçtaki zehir: hafif vuruş + yanma süresi)
					pj.hit(c, e.global_position + Vector3.UP * e.height * 0.6, e.radius + 0.6, pj.inf(c, "hebi_bunshin_no_jutsu", 0.25, {"knock": 1.0, "kind": "light", "burn": 3.0, "hitstop": 0.03}))
					_spray(pj, e.global_position + Vector3.UP * e.height * 0.6, 7, {"mat": _soft(false, false, 0.5, Color(0.25, 0.08, 0.3), 0.8, 0.25),
						"radius": 0.15, "spd": Vector2(1.0, 2.5), "dir": Vector3.UP, "spread": 70.0, "grav": 9.0, "life": Vector2(0.35, 0.55),
						"size": Vector2(0.08, 0.14), "cols": [Color(0.62, 0.3, 0.75, 0.95), Color(0.45, 0.6, 0.25, 0.0)]})))
	# yılan gibi yere yatıp geriye kayar: kıvrılan oyuk izi + toz
	var from_p = at
	c.global_position = pj.gp(at - d * 6.0)
	if c is Player:
		c.combat.invuln = 0.4
	var side = d.cross(Vector3.UP).normalized()
	var pts = []
	for k in 22:
		var q = k / 21.0
		pts.append(pj.gp(from_p - d * 6.0 * q) + side * sin(q * 12.0) * 0.4)
	_ground_trail(pj, pts, 0.16, Color(0.2, 0.16, 0.13, 0.6), 3.0)
	for k in 4:
		_dust(pj, pts[k * 5], 3, {"radius": 0.2, "spd": Vector2(0.5, 1.5), "size": Vector2(0.25, 0.4), "life": Vector2(0.5, 0.8), "delay": Vector2(k * 0.05, k * 0.05 + 0.02)})


# ═════════════════════════════════════════ 5) Yüzeye Gizlenme ═════════════════════════════════════════

## Yüzeyin içinde ilerleyen tümsek: alçak koyu kabarık; arkasında küçük dalga halkaları
static func _burrow_bulge(pj: PathJutsu, a: Vector3, b: Vector3, dur: float) -> void:
	var mound = _built("sennyu_mound", func():
		var mb = MB.new()
		mb.add("sphere", Vector3.ZERO, Vector3(1.2, 0.35, 1.6), Color(0.3, 0.3, 0.24), Vector3.ZERO, 12)
		return mb)
	var mi = _solid_mi(mound, 0.015)
	_scene(pj).add_child(mi)
	var st = {"next": 0.0}
	_tick(pj, a, func(_n, _dt, age) -> bool:
		if not is_instance_valid(mi):
			return false
		if age >= dur:
			mi.queue_free()
			return false
		var u = age / dur
		var p = a.lerp(b, u)
		p.y = Game.ground_height(p.x, p.z) - 0.05
		var d = b - a
		d.y = 0.0
		mi.global_transform = Transform3D(_look_basis(d, 1.0).scaled(Vector3(1.0, 0.6 + 0.4 * sin(age * 18.0), 1.0)), p)
		if age >= float(st["next"]):
			st["next"] = age + 0.12
			_ground(pj, p, 1.3, 0.5, {"mode": 0, "tint": Color(0.82, 0.86, 0.78, 0.8), "rings": 2.0, "width": 0.045})
		return true)


## Yüzeye gömülen / yükselen opak kopya: down true ise yüzeyden aşağı batar, değilse aşağıdan yükselir
static func _surface_statue(pj: PathJutsu, g: Node3D, hgt: float, at: Vector3, down: bool, dur: float) -> Node3D:
	g.visible = true
	g.global_position = at - (Vector3.ZERO if down else Vector3.UP * hgt)
	var tw = g.create_tween()
	tw.tween_property(g, "global_position", at - (Vector3.UP * hgt if down else Vector3.ZERO), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN if down else Tween.EASE_OUT)
	if down:
		tw.tween_callback(g.queue_free)
	_ground(pj, at, 1.6, dur + 0.25, {"mode": 0, "tint": Color(0.86, 0.9, 0.82, 0.85), "rings": 3.0, "width": 0.03})
	_ground(pj, at, 0.9, dur + 0.6, {"mode": 1, "tint": Color(0.16, 0.18, 0.14, 0.45), "tint2": Color(0.1, 0.1, 0.08, 0.6), "seed": randf() * 9.0}, 0.15)
	return g


## Yüzeye Gizlenme: bedenin yere/ağaca erir; görünmeden kayıp hedefin yanından çıkarsın
static func sennyu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.9)
	var start = c.global_position
	var hgt = _height(c) + 0.2
	# iki donmuş kopya gizlenmeden önce pişirilir: biri burada batar, öteki varış yerinde yükselir
	var up_statue = _ghost(pj, c, null, Vector3.ZERO, true)
	up_statue.visible = false
	_surface_statue(pj, _ghost(pj, c, null, Vector3.ZERO, true), hgt, pj.gp(start), true, 0.35)
	if c.get("model"):
		c.model.visible = false
	if c is Player:
		Buffs.add("sennyu", 0.9, {"stealth": 1.0, "armor": 0.0, "_desc": "yüzeyin içindesin"})
	var dest = pj.gp((tt.global_position - pj.fwd(c, t) * 1.5) if is_instance_valid(tt) else start + pj.fwd(c, t) * 12.0)
	_burrow_bulge(pj, pj.gp(start), dest, 0.55)
	pj.free_after(0.75, up_statue)   # atan bu arada ölse de kopya kalmaz
	pj.after(0.5, func():
		if is_instance_valid(up_statue):
			_surface_statue(pj, up_statue, hgt, dest, false, 0.2))
	pj.after(0.7, func():
		if not is_instance_valid(c):
			return
		c.global_position = dest + Vector3.UP * 0.1
		if c.get("model"):
			c.model.visible = true
		_dust(pj, dest, 8, {"flat": true, "radial": true, "radius": 0.5, "spd": Vector2(1.5, 3.0), "size": Vector2(0.35, 0.6), "life": Vector2(0.5, 0.8)})
		var hs = pj.hit(c, dest + Vector3.UP + c.face_dir(), 1.6, pj.inf(c, "sennyu_no_jutsu", 1.0, {"knock": 6.0, "kind": "heavy"}))
		if not hs.is_empty():
			# yüzeyden fırlayan darbe: hedefte kısa çarpma halkası + yukarı çizgiler
			var hp: Vector3 = (hs[0] as Node3D).global_position + Vector3.UP * 1.0
			_spray(pj, hp, 8, {"mat": _streak(), "mode": "stretch", "stretch": 0.1, "radius": 0.2, "spd": Vector2(6.0, 10.0),
				"dir": (c.face_dir() + Vector3.UP * 0.6).normalized(), "spread": 35.0, "life": Vector2(0.15, 0.25), "size": Vector2(0.3, 0.45),
				"cols": [Color(1, 1, 1, 0.95), Color(0.9, 0.9, 0.85, 0.0)]})
			pj.shake(0.3))
	Sfx.play("earth", c.global_position, 1.3)


# ═════════════════════════════════════════ 6) Chakra Emme ═════════════════════════════════════════

## Chakra Emme: dokunduğun hedefin chakrasını kendine çekersin (ref: hedefin bedeninden kopan mavi chakra alevleri ele akar)
static func chakura_kyuin_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 1.2)
	if tt == null:
		return
	pj._jump_at(c, tt, 0.0, 6.0)
	var cw = weakref(c)
	var palm = func():
		var x = cw.get_ref()
		return pj.hand_pos(x, true) if x != null and is_instance_valid(x) else null
	var flame = _soft(false, false, 0.5, Color(0.88, 0.96, 1.0), 0.8, 0.4)
	var flow_m = _stripm(Color(0.85, 0.95, 1.0, 0.95), Color(0.4, 0.68, 1.0, 0.75), 0.35)
	# avuçta emme girdabı
	_orbit(pj, palm, 10, Vector2(0.12, 0.28), 1.15, {"mat": _soft(true, false, 0.0, INK, 0.85, 0.2), "size": 0.08, "col": Color(0.6, 0.85, 1.0, 0.9),
		"speed": 9.0, "bob": 0.04, "tilt": 0.6, "shrink": 0.3})
	pj.every(1.0, 0.1, func(_i, _k):
		if pj.live(c) and pj.live(tt):
			var a = tt.global_position + Vector3.UP * 1.2
			# hedefin bedeninden kopan mavi chakra alev dilleri avuca çekilir
			_spray(pj, a, 5, {"mat": flame, "radius": 0.45, "spd": Vector2(0.5, 1.5), "dir": Vector3.UP, "spread": 50.0,
				"life": Vector2(0.45, 0.6), "size": Vector2(0.22, 0.38), "grow": 0.4, "pull": palm, "pull_k": 26.0,
				"cols": [Color(0.5, 0.75, 1.0, 0.0), Color(0.42, 0.7, 1.0, 0.85), Color(0.7, 0.88, 1.0, 0.7), Color(0.9, 0.97, 1.0, 0.0)]})
			if _i % 3 == 0:
				var tw2 = weakref(tt)
				var src = func():
					var y = tw2.get_ref()
					return (y as Node3D).global_position + Vector3.UP * 1.2 if y != null and is_instance_valid(y) else null
				for j in 3:   # ref: hedeften ele akan üç kollu dalgalı chakra akışı
					_ribbon(pj, _arc_path(src, palm, 0.35 + j * 0.15, 0.18, 4.0 + j), 0.4, 0.07, flow_m, 14, {"reveal": 0.18, "tail": 0.7, "taper": 3, "delay": j * 0.04})
			tt.take_hit(pj.inf(c, "chakura_kyuin_jutsu", 0.15, {"knock": 0.0, "kind": "light"}))
			if c is Player:
				c.chakra = minf(c.max_chakra, c.chakra + c.max_chakra * 0.04)
			pj.st(tt, "slow", 0.3))
	Sfx.play("absorb", c.global_position, 0.8)


# ═════════════════════════════════════════ 7) Kaya Kovanı ═════════════════════════════════════════

## Kaya kovan (ref Rock Hive): mor-kahve alacalı tümsek, kenarı açık halkalı kovan delikleri, önde mağara; içinde larva.
## Ön +Z. meta "holes": deliklerin yerel konumları
static func _hive() -> Node3D:
	var root = Node3D.new()
	var holes: Array = []
	var rx = 2.4
	var ry = 2.2
	var rz = 2.2
	for k in 18:
		var az = TAU * fmod(k * 0.618, 1.0)
		var el = 0.28 + fmod(k * 0.377, 1.0) * 0.95
		if absf(wrapf(az, -PI, PI)) < 0.6 and el < 0.75:
			el += 0.55
		holes.append(Vector3(rx * cos(el) * sin(az), ry * sin(el), rz * cos(el) * cos(az)))
	var mesh = _built("rock_hive2", func():
		# kaba gri-kahve taş: köşeli kaya yığını (yassı yüzeyli "boulder" parçaları), kovan delikleri çevresinde
		# bal mumu / kehribar lekeleri, koyu oyuklar, çatlaklar. Toon ışığı açık tonları pembeleştiriyordu: renkler koyu tutulur.
		var b = MB.new()
		var stones = [Color(0.3, 0.27, 0.23), Color(0.25, 0.22, 0.19), Color(0.35, 0.31, 0.25), Color(0.28, 0.26, 0.24), Color(0.22, 0.19, 0.16)]
		var AMBER = Color(0.62, 0.38, 0.08)
		var HOLE = Color(0.04, 0.03, 0.025)
		b.add("boulder", Vector3(0, -0.2, 0), Vector3(rx, ry * 1.15, rz) * 1.9, stones[0], Vector3(0, 20, 0), 3)   # çekirdek
		for i in 30:   # yüzeye oturan köşeli kaya parçaları
			var az = TAU * fmod(i * 0.618 + 0.13, 1.0)
			var el = asin(clampf(fmod(i * 0.381, 1.0), 0.0, 0.97))
			var sp = Vector3(rx * cos(el) * sin(az), ry * sin(el), rz * cos(el) * cos(az)) * 0.86
			var s = 1.05 + fmod(i * 0.29, 0.6)
			b.add("boulder", sp, Vector3(s * 1.2, s * 0.85, s), stones[i % stones.size()], Vector3(fmod(i * 37.0, 30.0) - 15.0, i * 53.0, fmod(i * 23.0, 24.0) - 12.0), 11 + i)
		for hp in holes:
			var n = Vector3(hp.x / (rx * rx), hp.y / (ry * ry), hp.z / (rz * rz)).normalized()
			var eul = _basis_y_to(n).get_euler() * (180.0 / PI)
			var s = 0.42 + fmod(hp.x * 3.7 + hp.z, 0.22)
			var base = hp + n * 0.2
			b.add("sphere", base, Vector3(s * 1.7, 0.1, s * 1.55), AMBER, eul, 12)   # bal mumu lekesi
			b.add("sphere", base - n * 0.04 + _basis_y_to(n) * Vector3(0, 0, -s * 0.9), Vector3(s * 0.5, 0.08, s * 1.1), AMBER.darkened(0.15), eul, 8)   # aşağı akan damla
			for q in 4:   # kırık taş ağız
				var qa = TAU * q / 4.0 + hp.x
				var off = _basis_y_to(n) * Vector3(cos(qa) * s * 0.75, 0.05, sin(qa) * s * 0.75)
				b.add("boulder", base + off, Vector3(0.3, 0.2, 0.26) * (s * 2.0), stones[(q + 1) % stones.size()].darkened(0.1), eul, 40 + q)
			b.add("sphere", base + n * 0.03, Vector3(s * 0.95, 0.16, s * 0.95), HOLE, eul, 10)   # koyu oyuk
		for i in 14:   # çatlaklar: yüzeyde kırık koyu çizgiler
			var az = TAU * fmod(i * 0.437 + 0.31, 1.0)
			var el = 0.15 + fmod(i * 0.29, 1.0) * 1.1
			var cp = Vector3(rx * cos(el) * sin(az), ry * sin(el), rz * cos(el) * cos(az)) * 1.03
			var n = Vector3(cp.x / (rx * rx), cp.y / (ry * ry), cp.z / (rz * rz)).normalized()
			var bs = _basis_y_to(n)
			var a0 = fmod(i * 1.9, PI)
			for q in 3:
				var o = bs * Vector3(cos(a0 + q * 0.6) * q * 0.28, 0.0, sin(a0 + q * 0.6) * q * 0.28)
				b.add("box", cp + o, Vector3(0.05, 0.05, 0.36), HOLE, ((bs * Basis(Vector3.UP, a0 + q * 0.6)).get_euler() * (180.0 / PI)), 4)
		b.add("sphere", Vector3(0, 0.15, rz - 0.05), Vector3(2.0, 1.7, 0.8), HOLE, Vector3.ZERO, 14)   # mağara
		for k in 6:   # mağara ağzı: kaba taş kemer + kehribar sızıntı
			var a = lerpf(-1.4, 1.4, k / 5.0)
			b.add("boulder", Vector3(sin(a) * 1.05, 0.1 + cos(a) * 0.9, rz + 0.08), Vector3(0.75, 0.55, 0.5), stones[k % stones.size()], Vector3(0, k * 40, rad_to_deg(a)), 60 + k)
			if k % 2 == 1:
				b.add("cone", Vector3(sin(a) * 0.8, cos(a) * 0.75 - 0.05, rz + 0.15), Vector3(0.12, 0.35, 0.12), AMBER, Vector3(180, 0, 0), 6)
		return b)
	root.add_child(_solid_mi(mesh, 0.045, true))
	var larva = _built("hive_larva", func():
		var b = MB.new()
		for q in 5:
			b.add("sphere", Vector3((q - 2) * 0.32, 0.0, 0.0), Vector3(0.42, 0.42, 0.42) * (1.0 - absf(q - 2) * 0.15), Color(0.93, 0.87, 0.7), Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.75, 0.05, 0.0), Vector3(0.22, 0.22, 0.22), Color(0.55, 0.3, 0.15), Vector3.ZERO, 8)
		return b)
	var lm = _solid_mi(larva, 0.015)
	lm.name = "Larva"
	lm.position = Vector3(0, 0.45, rz - 0.55)
	root.add_child(lm)
	root.set_meta("holes", holes)
	return root


static func _bee_mesh() -> ArrayMesh:
	return _built("bee", func():
		var b = MB.new()
		var Y = Color(1.0, 0.78, 0.15)
		b.add("sphere", Vector3(0, 0, -0.03), Vector3(0.12, 0.11, 0.2), Y, Vector3.ZERO, 10)
		for q in 2:
			b.add("box", Vector3(0, 0, -0.06 + q * 0.07), Vector3(0.125, 0.115, 0.025), INK)
		b.add("sphere", Vector3(0, 0.01, 0.09), Vector3(0.09, 0.09, 0.08), INK, Vector3.ZERO, 8)
		b.add("cone", Vector3(0, 0, -0.15), Vector3(0.02, 0.05, 0.02), INK, Vector3(-90, 0, 0), 5)
		for sx in [-1.0, 1.0]:
			b.add("box", Vector3(sx * 0.08, 0.06, 0.0), Vector3(0.14, 0.006, 0.07), Color(0.92, 0.95, 1.0), Vector3(0, sx * 15, sx * 22))
		return b)


## Iwa Hachinosu (ref: "Rock Hive" — kaya kovan dev arı larvasını barındırır; larva chakra yer)
static func iwa_hachinosu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "iwa_hachinosu"
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var at: Vector3 = pj.gp(c.global_position + d * 5.0)
	if tt:
		at = pj.gp(c.global_position.lerp(tt.global_position, 0.7))
	var cw = weakref(c)
	var hive = _hive()
	pj.scene_add(hive, at)
	hive.rotation.y = atan2(-d.x, -d.z)   # mağara atana bakar
	hive.scale = Vector3(1, 0.02, 1)
	var hw = weakref(hive)
	var ht = hive.create_tween()
	ht.tween_property(hive, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cracks(pj, at, 4.2, 9, 9.6)
	_debris(pj, at, 14, Color(0.3, 0.27, 0.23), 9.0, 0.35)
	_dust(pj, at, 18, {"flat": true, "radial": true, "radius": 2.0, "spd": Vector2(2.5, 5.0), "size": Vector2(0.8, 1.5), "life": Vector2(0.9, 1.4), "dir": Vector3.UP})
	Sfx.play("earth", at, 0.8)
	var top: Vector3 = at + Vector3.UP * 2.2
	var bee = _bee_mesh()
	var hive_top = func():
		var h = hw.get_ref()
		return (h as Node3D).global_position + Vector3.UP * 1.6 if h != null and is_instance_valid(h) else null
	_orbit(pj, hive_top, 16, Vector2(2.6, 4.2), 9.2, {"mesh": bee, "mat": _solid(), "size": 1.7, "col": Color.WHITE, "speed": 2.2, "bob": 0.5,
		"tilt": 0.35, "face": false, "h": Vector2(-1.0, 1.0), "fin": 0.6})
	var flow_m = _stripm(Color(0.85, 0.95, 1.0, 0.9), Color(0.45, 0.72, 1.0, 0.7), 0.35)
	var hole_w = func() -> Vector3:
		var h = hw.get_ref()
		if h == null or not is_instance_valid(h):
			return top
		var hl: Array = h.get_meta("holes")
		return (h as Node3D).global_transform * (hl[randi() % hl.size()] as Vector3)
	var drain = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc) or hw.get_ref() == null:
			return
		if i % 3 == 0:
			# bir delikten arı fışkırır
			var hp: Vector3 = hole_w.call()
			_spray(pj, hp, 5, {"mesh": bee, "mat": _solid(), "mode": "tumble", "spin": 3.0, "radius": 0.1, "spd": Vector2(2.0, 4.0),
				"dir": (hp - at).normalized(), "spread": 30.0, "drag": 1.5, "life": Vector2(0.6, 0.9), "size": Vector2(1.4, 1.8), "cols": [Color.WHITE]})
		if i % 5 != 4:
			return
		var h2 = hw.get_ref()
		if h2 != null:
			var lv = (h2 as Node).get_node_or_null("Larva")
			if lv:
				var lt = lv.create_tween()
				lt.tween_property(lv, "scale", Vector3(1.25, 1.15, 1.25), 0.12)
				lt.tween_property(lv, "scale", Vector3.ONE, 0.25)
		for e in pj.enemies_near(cc, at, 7.0):   # larva chakra yer
			e.take_hit(pj.inf(cc, id, 0.12, {"knock": 0.0, "kind": "light", "chakra_drain": 6.0, "hitstop": 0.0}))
			var ep: Vector3 = e.global_position + Vector3.UP * 1.1
			var hp2: Vector3 = hole_w.call()
			_ribbon(pj, _arc_path(_const(ep), _const(hp2), 1.2, 0.15, 3.0), 0.5, 0.06, flow_m, 14, {"reveal": 0.25, "tail": 0.7, "taper": 3})
	pj.every(9.0, 0.1, drain, func():
		var h = hw.get_ref()
		if h != null:
			var t2 = h.create_tween()
			t2.tween_property(h, "scale", Vector3(1, 0.02, 1), 0.5).set_ease(Tween.EASE_IN)
			t2.tween_callback(h.queue_free)
			_debris(pj, at, 10, Color(0.3, 0.27, 0.23), 6.0, 0.3)
			_dust(pj, at, 14, {"flat": true, "radial": true, "radius": 2.0, "spd": Vector2(1.5, 3.5), "size": Vector2(0.8, 1.4), "life": Vector2(1.0, 1.5), "dir": Vector3.UP}))


# ═════════════════════════════════════════ 8) Üç Mücevher Emip Ezme ═════════════════════════════════════════

## Parmaklardan kuklalara titreşen chakra ipleri (ref: bej-turuncu kırık çizgiler)
static func _puppet_strings(pj: PathJutsu, c: Node3D, units: Array, dur: float) -> void:
	var mat = _stripm(Color(1.0, 0.9, 0.62, 0.95), Color(0.78, 0.52, 0.3, 0.8), 0.5)
	var cw = weakref(c)
	for k in units.size():
		var uw = weakref(units[k])
		var right = k % 2 == 0
		_ribbon(pj, func(u, age):
			var x = cw.get_ref()
			var y = uw.get_ref()
			if x == null or y == null or not is_instance_valid(x) or not is_instance_valid(y):
				return null
			var a: Vector3 = pj.hand_pos(x, right)
			var b: Vector3 = (y as Node3D).global_position + Vector3.UP * 1.3
			var dd = b - a
			var sd = dd.cross(Vector3.UP)
			sd = sd.normalized() if sd.length() > 0.001 else Vector3.RIGHT
			var zig = (fmod(floor(u * 18.0 + age * 25.0), 2.0) * 2.0 - 1.0) * 0.035 * sin(u * PI)
			return a.lerp(b, u) + sd * zig + Vector3.DOWN * sin(u * PI) * 0.15, dur, 0.016, mat, 24, {"reveal": 0.15, "taper": 0})


## Kukla göğsündeki açılan havalandırma: kara ağız, metal kenar, dönen kanatlar (Z ekseninde)
static func _vent() -> Node3D:
	var root = Node3D.new()
	var base = _built("puppet_vent", func():
		var b = MB.new()
		b.add("cyl", Vector3.ZERO, Vector3(0.5, 0.05, 0.5), Color(0.08, 0.05, 0.05), Vector3(90, 0, 0), 16)
		b.add("torus", Vector3.ZERO, Vector3(0.56, 0.5, 0.56), Color(0.55, 0.52, 0.5), Vector3(90, 0, 0), 16)
		return b)
	root.add_child(_solid_mi(base, 0.01))
	var blades = _built("puppet_blades", func():
		var b = MB.new()
		for q in 6:
			var a = TAU * q / 6.0
			b.add("box", Vector3(cos(a), sin(a), 0) * 0.11, Vector3(0.2, 0.05, 0.012), Color(0.7, 0.66, 0.6), Vector3(0, 30, rad_to_deg(a)))
		return b)
	var bm = _solid_mi(blades, 0.0)
	bm.name = "Blades"
	bm.position = Vector3(0, 0, 0.03)
	root.add_child(bm)
	return root


## Emme girdabı: yerde üçgen bağ, kukla göğüslerinde dönen havalandırma, merkeze kıvrılan pembe-bej sarmal çizgiler,
## çekilen toz ve taşlar
static func _suction(pj: PathJutsu, cen: Vector3, units: Array, dur: float) -> void:
	var tri = _stripm(Color(1.0, 0.88, 0.6, 0.85), Color(0.8, 0.5, 0.35, 0.6), 0.45, false, false, 6.0, 1.5)
	for k in units.size():
		var ua = units[k]
		var ub = units[(k + 1) % units.size()]
		if units.size() < 2 or not is_instance_valid(ua) or not is_instance_valid(ub):
			continue
		var pa: Vector3 = (ua as Node3D).global_position + Vector3.UP * 0.08
		var pb: Vector3 = (ub as Node3D).global_position + Vector3.UP * 0.08
		_ribbon(pj, func(u, _age): return pa.lerp(pb, u), dur + 0.3, 0.05, tri, 12, {"reveal": 0.2, "taper": 0})
	for uv in units:
		if not is_instance_valid(uv):
			continue
		var v = _vent()
		(uv as Node3D).add_child(v)
		v.position = Vector3.UP * 1.25
		v.look_at(cen + Vector3.UP * 1.25, Vector3.UP)
		v.scale = Vector3.ONE * 0.05
		v.create_tween().tween_property(v, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		var vw = weakref(v)
		_tick(pj, Vector3.ZERO, func(_n, dt, age) -> bool:
			var x = vw.get_ref()
			if x == null or not is_instance_valid(x):
				return false
			if age >= dur + 0.3:
				x.queue_free()
				return false
			var bl = (x as Node).get_node_or_null("Blades")
			if bl:
				bl.rotation.z += dt * 22.0
			return true)
		# havalandırmadan merkeze emilen hava çizgileri
		var vp: Vector3 = (uv as Node3D).global_position + Vector3.UP * 1.25
		var to_c = cen + Vector3.UP * 1.0
		var vd = (to_c - vp).normalized()
		pj.every(dur, 0.2, func(_i, _k):
			_spray(pj, vp, 3, {"mat": _streak(), "mode": "stretch", "stretch": 0.08, "radius": 0.25, "spd": Vector2(8.0, 12.0),
				"dir": vd, "spread": 10.0, "life": Vector2(0.3, 0.4), "size": Vector2(0.3, 0.45),
				"cols": [Color(1.0, 0.85, 0.85, 0.85), Color(0.95, 0.7, 0.72, 0.0)]}), Callable())
	var swirl_m = _stripm(Color(1.0, 0.86, 0.84, 0.8), Color(0.78, 0.42, 0.48, 0.65), 0.4)
	for k in 9:
		var ph = TAU * k / 9.0
		var hk = 1.0 + 0.6 * (k % 3)
		_ribbon(pj, func(u, age):
			var a = ph + age * 5.5 + u * 2.6
			var r = lerpf(6.5, 0.3, u)
			return cen + Vector3(cos(a) * r, 0.25 + sin(u * PI) * hk, sin(a) * r), dur, 0.07, swirl_m, 20, {"taper": 1, "fin": 0.3})
	pj.every(dur, 0.25, func(_i, _k):
		_dust(pj, cen, 5, {"flat": true, "radius": 5.5, "spd": Vector2(0.2, 0.6), "pull": _const(cen + Vector3.UP * 0.6), "pull_k": 14.0,
			"size": Vector2(0.45, 0.8), "grow": 0.5, "life": Vector2(0.7, 1.0), "drag": 0.0})
		_debris(pj, cen + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0)), 2, EARTH, 3.0, 0.16), Callable())


## Ezişin ardından savrulma: arkaya moloz, toz, savrulma çatlakları ve hız çizgileri; ezik iz
static func _expel(pj: PathJutsu, cen: Vector3, back: Vector3) -> void:
	_spray(pj, cen + Vector3.UP * 1.0, 18, {"mat": _soft(false, false, 0.55, DUST_D, 0.85, 0.3), "radius": 1.6, "inward": true,
		"spd": Vector2(5.0, 8.0), "life": Vector2(0.18, 0.25), "size": Vector2(0.5, 0.9), "cols": [Color(DUST, 0.0), Color(DUST, 0.9)]})
	_debris(pj, cen, 20, EARTH, 15.0, 0.3, (back + Vector3.UP * 0.5).normalized(), 30.0)
	_dust(pj, cen + Vector3.UP * 0.8, 20, {"dir": back, "spread": 30.0, "spd": Vector2(6.0, 11.0), "size": Vector2(0.8, 1.5), "grow": 2.2, "life": Vector2(0.9, 1.4), "drag": 2.0})
	_cracks(pj, cen, 4.0, 6, 6.0, Color(0.1, 0.08, 0.07, 0.95), back, 1.4)
	var sm = _stripm(Color(1, 1, 1, 0.9), Color(0.85, 0.8, 0.75, 0.5), 0.5)
	var sd = back.cross(Vector3.UP).normalized()
	for k in 6:
		var off = sd * randf_range(-1.2, 1.2) + Vector3.UP * randf_range(0.4, 2.0)
		var pa = cen + off
		var pb = cen + off + back * randf_range(6.0, 9.0)
		_ribbon(pj, func(u, _age): return pa.lerp(pb, u), 0.35, 0.03, sm, 4, {"reveal": 0.12, "tail": 0.6, "taper": 3})
	_ground(pj, cen, 2.4, 6.0, {"mode": 1, "tint": Color(0.26, 0.2, 0.17, 0.5), "tint2": Color(0.14, 0.1, 0.09, 0.65), "seed": randf() * 9.0}, 0.15)


## Üç Mücevher Emip Ezme (ref: üç Chikamatsu kuklası üçgen dizilir, göğüs mekanizmalarını açar; kasırga hedefleri merkeze emer, ezer, arkadan fırlatır)
static func sanbo_kyukai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	pj.anim(c, "cast", 1.0)
	var tt = pj.tg(c, t, 22.0)
	var cen = pj.gp(tt.global_position if tt else c.global_position + c.face_dir() * 8.0)
	var list = ClanConstruct.spawn(c, "puppet", 3, Jutsu._jd("sanbo_kyukai"))
	var units: Array = list if list is Array else []
	for k in units.size():
		var a = TAU * k / 3.0
		if is_instance_valid(units[k]):
			units[k].global_position = pj.gp(cen + Vector3(cos(a), 0, sin(a)) * 4.5)
			# iple çekilip yere konan kukla: ayak dibinde kısa toz
			_dust(pj, units[k].global_position, 5, {"flat": true, "radial": true, "radius": 0.4, "spd": Vector2(1.5, 3.0), "size": Vector2(0.3, 0.55), "life": Vector2(0.5, 0.8)})
	_puppet_strings(pj, c, units, 4.0)
	Sfx.play("wind", cen, 0.6)
	var dur = 2.6
	pj.after(0.4, func():
		_suction(pj, cen, units, dur)
		pj.every(dur, 0.1, func(_i, _k):
			for e in pj.enemies_near(c, cen, 9.0):
				var dd = cen - e.global_position
				dd.y = 0
				if dd.length() > 0.6 and e is CharacterBody3D:
					e.velocity = dd.normalized() * minf(14.0, dd.length() * 4.0) + Vector3.UP * 1.5
				if dd.length() < 1.6 and randf() < 0.25:
					e.take_hit(pj.inf(c, "sanbo_kyukai", 0.12, {"knock": 0.0, "kind": "crush", "pierce_guard": true})), func():
			# ezilen her şey arkadan fırlatılır
			var back = (cen - c.global_position)
			back.y = 0
			back = back.normalized()
			for e in pj.enemies_near(c, cen, 3.0):
				e.take_hit(pj.inf(c, "sanbo_kyukai", 0.8, {"knock": 18.0, "launch": 6.0, "dir": back, "kind": "heavy", "hitstop": 0.08}))
			_expel(pj, cen, back)
			pj.shake(0.6)))


# ═════════════════════════════════════════ 9) Algılama — Kum Kedi Resmi ═════════════════════════════════════════

## Kedi yüzü resmi (ref: yere kumla çizilmiş iki halkalı yüz, kulaklar, dikey gözler, bıyık): 2B noktalar (y = ileri)
static func _cat_pattern() -> Array:
	var pts = []
	for i in 170:
		var a = TAU * i / 170.0
		pts.append(Vector2(cos(a), sin(a)) * (3.0 + randf_range(-0.1, 0.1)))
	for i in 130:
		var a = TAU * i / 130.0
		pts.append(Vector2(cos(a), sin(a)) * (2.3 + randf_range(-0.08, 0.08)))
	for sx in [-1.0, 1.0]:
		var e0 = Vector2(sx * 0.95, 2.85)
		var e1 = Vector2(sx * 1.75, 3.75)
		var e2 = Vector2(sx * 2.5, 1.75)
		for i in 26:
			pts.append(e0.lerp(e1, i / 25.0) + Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05)))
			pts.append(e1.lerp(e2, i / 25.0) + Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05)))
		for i in 22:   # dikey göz çizgileri
			pts.append(Vector2(sx * 0.75 + randf_range(-0.07, 0.07), lerpf(0.25, 1.2, i / 21.0)))
		for w in 3:   # bıyıklar
			var y0 = -0.25 - w * 0.3
			for i in 12:
				var f = i / 11.0
				pts.append(Vector2(sx * lerpf(1.0, 2.05, f), y0 - (w - 1) * 0.15 * f) + Vector2(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03)))
	for sx3 in [-1.0, 1.0]:   # ω ağız: iki küçük alt yay
		for i in 12:
			var g = PI + PI * i / 11.0
			pts.append(Vector2(sx3 * 0.2 + cos(g) * 0.2, -0.55 + sin(g) * 0.18))
	return pts


## Sensa Kaibyō (algılama): avuçta toplanan kum topu havaya atılır, dağılır; taneler yere dev bir kedi yüzü çizer ve
## alanı gözetler. Algılanan rakiplerin ayağında dönen kum taneleri (duvar ardından görünür).
static func sensa_kaibyo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var rd = _sense_rd("sensa_kaibyo")
	Combat.start_sensing(c, rd.x, rd.y)
	var fd = _flat_dir(c)
	var right = fd.cross(Vector3.UP).normalized()
	var ctr = pj.gp(c.global_position + fd * 6.5)
	var hand0: Vector3 = pj.hand_pos(c, true)
	var apex = ctr + Vector3.UP * 7.0
	var cw = weakref(c)
	var palm = func():
		var x = cw.get_ref()
		return pj.hand_pos(x, true) if x != null and is_instance_valid(x) else null
	var grain_m = _soft(false, false, 0.0, INK, 0.95, 0.1)
	_spray(pj, hand0, 24, {"mat": grain_m, "radius": 1.4, "spd": Vector2(0.0, 0.4), "pull": palm, "pull_k": 30.0, "life": Vector2(0.3, 0.45),
		"size": Vector2(0.03, 0.05), "cols": [Color(SAND, 0.0), Color(SAND, 1.0)]})
	# resim: taneler tepeden yere iner, durur, sonunda rüzgârla dağılır
	var pat = _cat_pattern()
	var n = pat.size()
	var T = []
	var D = []
	var W = []
	for i in n:
		var q: Vector2 = pat[i]
		var wp = ctr + right * q.x + fd * q.y
		wp.y = Game.ground_height(wp.x, wp.z) + 0.04
		T.append(wp - ctr)
		D.append(0.55 + q.length() / 3.8 * 0.45 + randf() * 0.05)
		W.append(Vector3(randf_range(-0.5, 0.5), randf_range(0.6, 1.6), randf_range(-0.5, 0.5)) + fd * randf_range(1.0, 2.5))
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad()
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = grain_m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 16, 24))
	var ball_mesh = _built("sand_ball", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.4, Color(0.93, 0.9, 0.84), Vector3.ZERO, 14)
		return b)
	var ball = _solid_mi(ball_mesh, 0.012)
	var hold_end = 0.55 + 1.0 + rd.y * 0.55
	var hid = Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), Vector3(0, -500, 0))
	var sand_cols = [SAND_D, SAND_D.darkened(0.12), SAND, Color(0.66, 0.46, 0.33)]
	var tk = _tick(pj, ctr, func(node, _dt, age) -> bool:
		if age >= hold_end + 1.4:
			return false
		var cam = _cam(node) - ctr
		# top: elden tepeye yay
		if age < 0.55:
			var u = age / 0.55
			ball.visible = true
			ball.global_position = hand0.lerp(apex, u) + Vector3.UP * sin(u * PI) * 1.5
		elif ball.visible:
			ball.visible = false
			_spray(pj, apex, 26, {"mat": grain_m, "radius": 0.3, "spd": Vector2(2.0, 5.0), "dir": Vector3.DOWN, "spread": 80.0, "grav": 6.0,
				"life": Vector2(0.4, 0.7), "size": Vector2(0.05, 0.09), "cols": [Color(SAND, 1.0), Color(SAND, 0.0)]})
			Sfx.play("whoosh", apex, 0.8)
		for i in n:
			var s0: float = D[i]
			if age < s0:
				mm.set_instance_transform(i, hid)
				continue
			var p: Vector3
			var al = 1.0
			if age < s0 + 0.45:
				var u = (age - s0) / 0.45
				p = (apex - ctr).lerp(T[i], u * u) + Vector3.UP * sin(u * PI) * 0.6
			elif age < hold_end:
				p = T[i]
			else:
				var u2 = (age - hold_end) / 1.4
				p = T[i] + (W[i] as Vector3) * u2 * 2.0
				al = 1.0 - u2
			var b = (Basis(Vector3.UP, i * 1.7) * Basis(Vector3.RIGHT, -PI * 0.5)).scaled(Vector3.ONE * (0.11 if i % 3 else 0.08))
			if age < s0 + 0.45 or age >= hold_end:
				b = _face_basis(cam - p, 0.08, 0.08, i)
			mm.set_instance_transform(i, Transform3D(b, p))
			var cl: Color = sand_cols[i % sand_cols.size()]
			mm.set_instance_color(i, Color(cl.r, cl.g, cl.b, al))
		return true)
	tk.add_child(mmi)
	_scene(pj).add_child(ball)
	ball.global_position = hand0
	pj.free_after(hold_end + 1.5, ball)
	# algılanan rakipler: ayaklarında dönen kum taneleri (duvar ardından görünür)
	if c is Player:
		for f in _targets(c, rd.x):
			_orbit(pj, _at_fn(f, Vector3.UP * 0.15), 14, Vector2(0.55, 0.75), rd.y, {"mat": _soft(false, true, 0.0, INK, 0.95, 0.1), "size": 0.07,
				"col": Color(SAND.lightened(0.15), 0.95), "speed": 1.8, "bob": 0.06, "tilt": 0.15, "h": Vector2(0.0, 0.15)})


# ═════════════════════════════════════════ 10) Algılama — Zihin Okuma ═════════════════════════════════════════

## Saiko Denshin (Yamanaka, zihin okuma): avuçtan en yakın zihne uzanan ince ak iplik; iplikten atanın başına anı
## pulları akar; okunan zihnin başında ak küre (ortası kara nokta). Menzildeki diğer zihinler küçük ak kürelerle görünür.
static func saiko_denshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj._yama_seal(c)
	var rd = _sense_rd("saiko_denshin")
	Combat.start_sensing(c, rd.x, rd.y)
	var foes = _targets(c, rd.x)
	var cw = weakref(c)
	var palm = func():
		var x = cw.get_ref()
		return pj.hand_pos(x, true) if x != null and is_instance_valid(x) else null
	var thread = _stripm(Color(1, 1, 1, 0.95), Color(LILAC, 0.6), 0.45, false, true)
	# atanın başında ince lila tüller
	_spray(pj, c.global_position + Vector3.UP * _height(c), 8, {"mat": _soft(true, false, 0.0, INK, 0.8, 0.3), "radius": 0.25,
		"spd": Vector2(0.3, 0.7), "dir": Vector3.UP, "spread": 30.0, "life": Vector2(0.8, 1.2), "size": Vector2(0.12, 0.2),
		"cols": [Color(LILAC, 0.0), Color(LILAC, 0.6), Color(MIND, 0.0)]})
	if foes.is_empty():
		var fd = _flat_dir(c)
		var a0: Vector3 = pj.hand_pos(c, true)
		_ribbon(pj, func(u, age): return a0 + fd * u * 6.0 + Vector3.UP * sin(u * 9.0 + age * 6.0) * 0.1 * u, 0.9, 0.02, thread, 16, {"reveal": 0.4, "tail": 0.5, "taper": 2})
		return
	var near: Node3D = foes[0]
	var head_fn = _head_fn(near)
	var path = _arc_path(palm, head_fn, 0.6, 0.12, 5.0)
	_ribbon(pj, path, 2.6, 0.022, thread, 22, {"reveal": 0.35, "taper": 1})
	# anı pulları: hedefin zihninden atanın avucuna geri akar
	_beads(pj, path, 14, 1.8, 0.55, 0.09, Color(MIND, 0.95), _soft(false, true, 0.6, LILAC, 0.98, 0.0), true)
	_mind_orb(pj, near, 2.8, 0.32)
	if c is Player:
		for i in range(1, foes.size()):
			_mind_orb(pj, foes[i], rd.y, 0.16)


## Zihin küresi: başın üstünde ak küre, ortasında kara nokta (duvar ardından görünür)
static func _mind_orb(pj: PathJutsu, f: Node3D, dur: float, size: float) -> void:
	var hf = _head_fn(f, 1.12)
	var white = _soft_c(Color(1, 1, 1, 0.95), false, true, 0.45, LILAC, 0.9, 0.08)
	var dot = _soft_c(Color(0.08, 0.06, 0.12, 1.0), false, true, 0.0, INK, 0.95, 0.0)
	var a = _mi(_quad(), white)
	var b = _mi(_quad(), dot)
	_tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
		if age >= dur:
			return false
		var hv = hf.call()
		if hv == null:
			return false
		var p: Vector3 = hv
		var cam = _cam(node)
		var s = size * (1.0 + 0.08 * sin(age * 5.0)) * minf(1.0, age / 0.2) * clampf((dur - age) / 0.3, 0.0, 1.0)
		a.global_transform = Transform3D(_face_basis(cam - p, s, s * 1.2), p)
		b.global_transform = Transform3D(_face_basis(cam - p, s * 0.28, s * 0.28), p + (cam - p).normalized() * 0.01)
		return true).add_child(a)
	a.get_parent().add_child(b)


# ═════════════════════════════════════════ 11) Algılama — Su Küresi ═════════════════════════════════════════

## Kanchi Suikyū: yerden sarmal su damlaları avuca toplanır, avuçta içinde halkalar akan su küresi; zeminde dışa yayılan
## su dalgası; sonunda küre damlalara çözülür, yerde ıslak iz. Rakiplerin ayağında tekrar eden su halkası.
static func kanchi_suikyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var rd = _sense_rd("kanchi_suikyu")
	Combat.start_sensing(c, rd.x, rd.y)
	var cw = weakref(c)
	var above = func():
		var x = cw.get_ref()
		return pj.hand_pos(x, true) + Vector3.UP * 0.3 if x != null and is_instance_valid(x) else null
	var drop = _soft(false, false, 0.5, Color(0.9, 0.97, 1.0), 0.9, 0.1)
	_spray(pj, pj.gp(c.global_position), 26, {"mat": drop, "flat": true, "radius": 2.4, "spd": Vector2(0.5, 1.5), "dir": Vector3.UP, "spread": 10.0,
		"pull": above, "pull_k": 22.0, "swirl": 6.0, "life": Vector2(0.45, 0.6), "size": Vector2(0.06, 0.1),
		"cols": [Color(WATER, 0.0), Color(WATER, 0.95), Color(0.85, 0.95, 1.0, 0.9)]})
	var bm = _mat("bubble", {"tint": Color(0.45, 0.72, 0.95, 0.35), "rim_col": Color(0.85, 0.95, 1.0, 0.9), "rings_amt": 1.0, "swirl_amt": 0.4})
	var sph = _mi(_sphere(), bm)
	_scene(pj).add_child(sph)
	var dur = 2.8
	_tick(pj, Vector3.ZERO, func(_n, _dt, age) -> bool:
		if not is_instance_valid(sph):
			return false
		var pv = above.call()
		if age >= dur or pv == null:
			var last = sph.global_position
			sph.queue_free()
			_spray(pj, last, 18, {"mat": drop, "radius": 0.2, "spd": Vector2(0.5, 2.0), "dir": Vector3.UP, "spread": 120.0, "grav": 14.0, "ground": true,
				"life": Vector2(0.5, 0.8), "size": Vector2(0.05, 0.09), "cols": [Color(WATER, 0.95), Color(WATER, 0.0)]})
			_ground(pj, pj.gp(last), 0.9, 4.0, {"mode": 1, "tint": Color(0.18, 0.26, 0.34, 0.45), "tint2": Color(0.12, 0.18, 0.26, 0.55), "seed": randf() * 9.0}, 0.2)
			return false
		var g = clampf((age - 0.3) / 0.35, 0.0, 1.0)
		var s = maxf(0.001, 0.55 * (1.0 - pow(1.0 - g, 3.0)) * (1.0 + 0.04 * sin(age * 11.0)))
		sph.global_transform = Transform3D(Basis.from_scale(Vector3(s, s * (1.0 + 0.05 * sin(age * 7.0)), s)), pv)
		return true)
	pj.after(0.6, func():
		var x = cw.get_ref()
		if x != null and is_instance_valid(x):
			_ground(pj, pj.gp((x as Node3D).global_position), 16.0, 1.8, {"mode": 0, "tint": Color(0.8, 0.92, 1.0, 0.85), "rings": 3.0, "width": 0.008}))
	if c is Player:
		for f in _targets(c, rd.x):
			_ground(pj, Vector3.ZERO, 1.1, rd.y, {"mode": 0, "tint": Color(0.75, 0.9, 1.0, 0.9), "rings": 2.0, "width": 0.05}, 0.3, true, f, 1.6)


# ═════════════════════════════════════════ 12) Algılama — Teleskop ═════════════════════════════════════════

## Tōmegane no Jutsu (Hiruzen'in kristal küresi): önde ayaklı kristal küre belirir, içi döner; oyuncuda küre en yakın
## rakibin GERÇEK uzak görüntüsünü gösterir (küçük bir gözcü kamerasıyla). Kürede parıltı, küreden rakibe bakış çizgisi;
## algılanan rakiplerin üstünde yanıp sönen yıldız parıltısı.
static func tomegane_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var rd = _sense_rd("tomegane_no_jutsu")
	Combat.start_sensing(c, rd.x, rd.y)
	var dur = 3.0
	var cw = weakref(c)
	var spot = func():
		var x = cw.get_ref()
		if x == null or not is_instance_valid(x):
			return null
		return (x as Node3D).global_position + Vector3.UP * 1.25 + _flat_dir(x) * 0.7
	var root = Node3D.new()
	var stand = _built("crystal_stand", func():
		var b = MB.new()
		b.add("torus", Vector3(0, -0.22, 0), Vector3(0.38, 0.4, 0.38), Color(0.45, 0.3, 0.18), Vector3.ZERO, 16)
		for q in 3:
			var a = TAU * q / 3.0
			b.add("cyl", Vector3(cos(a) * 0.13, -0.33, sin(a) * 0.13), Vector3(0.03, 0.22, 0.03), Color(0.4, 0.26, 0.15), Vector3(cos(a) * 15, 0, sin(a) * 15), 6)
		b.add("cyl", Vector3(0, -0.45, 0), Vector3(0.36, 0.04, 0.36), Color(0.35, 0.22, 0.13), Vector3.ZERO, 14)
		return b)
	root.add_child(_solid_mi(stand, 0.01))
	var bm = _mat("bubble", {"tint": Color(0.7, 0.8, 1.0, 0.45), "rim_col": Color(0.95, 0.97, 1.0, 0.95), "swirl_amt": 1.0, "rings_amt": 0.0})
	var orb = _mi(_sphere(), bm)
	orb.scale = Vector3.ONE * 0.5
	root.add_child(orb)
	_scene(pj).add_child(root)
	var foes = _targets(c, rd.x)
	var vp: SubViewport = null
	var cam3: Camera3D = null
	if c is Player and not foes.is_empty():
		vp = SubViewport.new()
		vp.size = Vector2i(192, 192)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.world_3d = c.get_viewport().world_3d
		cam3 = Camera3D.new()
		cam3.fov = 45.0
		vp.add_child(cam3)
		root.add_child(vp)
		cam3.current = true
		bm.set_shader_parameter("view_tex", vp.get_texture())
	var seen: Node3D = foes[0] if not foes.is_empty() else null
	var sw = weakref(seen) if seen else null
	_tick(pj, Vector3.ZERO, func(_n, _dt, age) -> bool:
		if not is_instance_valid(root):
			return false
		var pv = spot.call()
		if age >= dur or pv == null:
			root.queue_free()
			return false
		root.global_position = pv
		root.scale = Vector3.ONE * (minf(1.0, age / 0.25) * clampf((dur - age) / 0.25, 0.0, 1.0) + 0.001)
		var va = clampf((age - 0.45) / 0.35, 0.0, 1.0) * clampf((dur - 0.3 - age) / 0.3, 0.0, 1.0)
		bm.set_shader_parameter("swirl_amt", 1.0 - va * 0.8)
		if cam3 and sw:
			var s = sw.get_ref()
			if s != null and is_instance_valid(s):
				var sp: Vector3 = (s as Node3D).global_position
				var to_me = (pv - sp)
				to_me.y = 0.0
				to_me = to_me.normalized() if to_me.length() > 0.01 else Vector3.BACK
				cam3.look_at_from_position(sp + to_me * 3.6 + Vector3.UP * 2.0, sp + Vector3.UP * 1.1, Vector3.UP)
				bm.set_shader_parameter("view_amt", va * 0.9)
			else:
				bm.set_shader_parameter("view_amt", 0.0)
		return true)
	# küre parıltısı: dört kollu yıldız
	pj.after(0.35, func():
		var pv = spot.call()
		if pv == null:
			return
		var gl = _streak_c(Color(0.95, 0.97, 1.0, 1.0), true)
		for k in 2:
			var bb = _mi(_quad(), gl)
			_scene(pj).add_child(bb)
			var st0 = {"k": k}
			_tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
				if not is_instance_valid(bb):
					return false
				var p2 = spot.call()
				if age >= 0.45 or p2 == null:
					bb.queue_free()
					return false
				var p: Vector3 = p2 + Vector3(-0.1, 0.12, 0.0)
				var s = sin(age / 0.45 * PI)
				bb.global_transform = Transform3D(_face_basis(_cam(node) - p, 0.9 * s, 0.05 * s, PI * 0.5 * float(st0["k"]) + 0.3), p)
				return true))
	if seen:
		var sight = _stripm(Color(0.95, 0.97, 1.0, 0.8), Color(0.65, 0.75, 1.0, 0.45), 0.4, true, true, 10.0, 2.0)
		_ribbon(pj, _arc_path(spot, _head_fn(seen, 0.7), 0.0), 2.4, 0.02, sight, 24, {"reveal": 0.4, "taper": 2, "delay": 0.4})
	if c is Player:
		for f in foes:
			_star_mark(pj, f, rd.y)


## Yanıp sönen dört kollu yıldız (rakibin üstünde, duvar ardından görünür)
static func _star_mark(pj: PathJutsu, f: Node3D, dur: float) -> void:
	var hf = _head_fn(f, 1.25)
	var gl = _streak_c(Color(0.92, 0.95, 1.0, 1.0), true, true)
	var q1 = _mi(_quad(), gl)
	var q2 = _mi(_quad(), gl)
	var ph = randf() * TAU
	var tk = _tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
		if age >= dur:
			return false
		var hv = hf.call()
		if hv == null:
			return false
		var p: Vector3 = hv
		var cam = _cam(node)
		var s = (0.45 + 0.35 * maxf(0.0, sin(age * 3.0 + ph))) * minf(1.0, age / 0.2) * clampf((dur - age) / 0.4, 0.0, 1.0)
		q1.global_transform = Transform3D(_face_basis(cam - p, s, s * 0.08, 0.0), p)
		q2.global_transform = Transform3D(_face_basis(cam - p, s, s * 0.08, PI * 0.5), p)
		return true)
	tk.add_child(q1)
	tk.add_child(q2)


# ═════════════════════════════════════════ 13) Algılama — Aktarım ═════════════════════════════════════════

## Kanchi Denden (Yamanaka, algı aktarımı; ref: ak parlayan zihin silueti, elinden takım arkadaşlarının başına iplikler):
## atandan ak zihin silueti yükselir; menzildeki takım arkadaşlarına iplikler uzanır, ipliklerde aktarım boncukları akar.
## Menzildeki rakipler 10 sn işaretli (başlarının üstünde sallanan ak sarkaç boncuk).
static func kanchi_denden(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj._yama_seal(c)   # referans: el başa konarak algı aktarımı
	Combat.start_sensing(c, 80.0, 10.0)
	var gm = _ghost_mat(Color(1.0, 1.0, 1.0, 0.55), Color(1, 1, 1, 1.0), 0.0, 0.6)
	var fig = _ghost(pj, c, gm, Vector3.ZERO)
	fig.scale = Vector3.ONE * 1.12
	_fade_ghost(pj, fig, gm, 1.6, 0.8, 0.45)
	var hand = c.global_position + Vector3.UP * (_height(c) * 0.75 + 0.3) + _flat_dir(c).cross(Vector3.UP) * 0.45
	var thread = _stripm(Color(1, 1, 1, 0.95), Color(0.85, 0.85, 0.9, 0.55), 0.5)
	var bead = _soft(true, false, 0.0, INK, 0.95, 0.0)
	var k = 0
	for a in c.get_tree().get_nodes_in_group("fighters"):
		if a == c or Combat.hostile(c, a) or a.is_dead() or (a as Node3D).global_position.distance_to(c.global_position) > 80.0:
			continue
		var path = _arc_path(_const(hand), _head_fn(a), 1.2)
		_ribbon(pj, path, 2.6, 0.018, thread, 22, {"reveal": 0.3 + k * 0.05, "taper": 2})
		_beads(pj, path, 3, 1.2, 0.45, 0.12, Color(1, 1, 1, 0.95), bead)
		k += 1
	# ana ağaç (c_kanchi_denden): chakra nabzı 80 m'ye yayılır, düşmanlar 10 sn işaretli kalır
	for e in pj.enemies_near(c, c.global_position, 80.0):   # referans: görünür algı dalgası yok; algılanan düşman işaretlenir
		pj.st(e, "marked", 10.0)
		_pendulum(pj, e, 10.0)
	Sfx.play("genjutsu", c.global_position, 1.8)


## Ak sarkaç boncuk (ref: zihin figürünün elinden sarkan ak yumurta): rakibin başı üstünde ipte sallanır
static func _pendulum(pj: PathJutsu, f: Node3D, dur: float) -> void:
	var hf = _head_fn(f, 1.0)
	var line = _stripm(Color(1, 1, 1, 0.9), Color(0.8, 0.8, 0.85, 0.6), 0.5, false, true)
	var egg = _soft(false, true, 0.5, Color(0.7, 0.7, 0.78), 0.95, 0.0)
	var q = _mi(_quad(), egg)
	var ph = randf() * TAU
	var piv = func():
		var hv = hf.call()
		return (hv as Vector3) + Vector3.UP * 1.25 if hv != null else null
	var bob = func():
		var pv = piv.call()
		if pv == null:
			return null
		var sw = sin(Game.now() * 2.4 + ph) * 0.35
		return (pv as Vector3) + Vector3(sin(sw), -cos(sw), 0.0) * 0.5
	_ribbon(pj, _arc_path(piv, bob, 0.0), dur, 0.008, line, 4, {"taper": 0})
	var tk = _tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
		if age >= dur:
			return false
		var bv = bob.call()
		if bv == null:
			return false
		var p: Vector3 = bv
		var s = 0.16 * minf(1.0, age / 0.2) * clampf((dur - age) / 0.3, 0.0, 1.0)
		q.global_transform = Transform3D(_face_basis(_cam(node) - p, s * 0.8, s), p)
		return true)
	tk.add_child(q)


# ═════════════════════════════════════════ 14) Algılama — Jōgan ═════════════════════════════════════════

## Jōgan gözü: sağ gözde mavi-ak çakım (açılışta büyük, sonra küçük sabit pırıltı), çevresinde ince çizgiler
static func _jogan_eye(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var hb = _bone(c, "Head")
	if hb == null:
		return
	var gl = _mi(_quad(), _soft_c(Color(0.8, 0.92, 1.0, 0.95), true))
	hb.add_child(gl)
	gl.position = Vector3(-0.032, 0.06, 0.1)
	var sm = _streak_c(Color(JOGAN, 0.9), true)
	var s1 = _mi(_quad(), sm)
	var s2 = _mi(_quad(), sm)
	hb.add_child(s1)
	hb.add_child(s2)
	_tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
		if not is_instance_valid(hb) or not is_instance_valid(gl):
			return false
		if age >= dur:
			hb.queue_free()
			return false
		var p = gl.global_position
		var cam = _cam(node)
		var burst = maxf(0.0, 1.0 - age / 0.35)
		var s = (0.06 + burst * 0.3) * clampf((dur - age) / 0.4, 0.0, 1.0)
		gl.global_transform = Transform3D(_face_basis(cam - p, s, s), p)
		s1.global_transform = Transform3D(_face_basis(cam - p, s * 4.0, s * 0.25, 0.4), p)
		s2.global_transform = Transform3D(_face_basis(cam - p, s * 3.0, s * 0.2, 0.4 + PI * 0.5), p)
		return true)


## Uzayın cam gibi çatlaması: atanın çevresinde havada beliren kırık mavi-ak çizgiler
static func _space_cracks(pj: PathJutsu, c: Node3D) -> void:
	var mat = _stripm(Color(1, 1, 1, 0.95), Color(JOGAN, 0.7), 0.4, true)
	var cen = c.global_position
	for k in 12:
		var a = TAU * k / 12.0 + randf_range(-0.2, 0.2)
		var r = randf_range(2.5, 6.0)
		var p0 = cen + Vector3(cos(a) * r, randf_range(0.4, 3.2), sin(a) * r)
		var pts = [p0]
		var d = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		for q in 5:
			d = (d + Vector3(randf_range(-0.9, 0.9), randf_range(-0.9, 0.9), randf_range(-0.9, 0.9))).normalized()
			pts.append((pts[-1] as Vector3) + d * randf_range(0.25, 0.6))
		_ribbon(pj, func(u, _age):
			var f = u * (pts.size() - 1)
			var i = mini(int(f), pts.size() - 2)
			return (pts[i] as Vector3).lerp(pts[i + 1], f - i), 0.9, randf_range(0.02, 0.035), mat, 10, {"reveal": 0.12, "taper": 1, "fin": 0.5, "delay": k * 0.02})


## Zayıf noktalar (tenketsu): rakibin bedeninde atan küçük mavi noktalar (duvar ardından görünür)
static func _weak_points(pj: PathJutsu, f: Node3D, dur: float) -> void:
	var h = _height(f)
	var spots = [Vector3(0, h * 0.62, 0), Vector3(-0.18, h * 0.76, 0), Vector3(0.18, h * 0.76, 0), Vector3(0, h * 0.45, 0), Vector3(0, h * 0.9, 0)]
	var mat = _soft(true, true, 0.0, INK, 0.9, 0.0)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad()
	mm.instance_count = spots.size()
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	var tk = _tick(pj, Vector3.ZERO, func(node, _dt, age) -> bool:
		if age >= dur:
			return false
		var cam = _cam(node)
		var env = minf(1.0, age / 0.3) * clampf((dur - age) / 0.4, 0.0, 1.0)
		for i in spots.size():
			var p: Vector3 = spots[i]
			var wp = node.global_transform * p
			var s = (0.09 + 0.04 * sin(age * 6.0 + i)) * env
			mm.set_instance_transform(i, Transform3D(node.global_transform.basis.inverse() * _face_basis(cam - wp, s, s), p))
			mm.set_instance_color(i, Color(0.75, 0.9, 1.0, 0.95 * env))
		return true, f)
	tk.add_child(mmi)


## Jōgan: Kanpa no Me — klonlar/genjutsu çözülür, zayıf noktalar görünür (10 sn zırh delen vuruşlar)
static func jogan_kanpa(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.3)
	_jogan_eye(pj, c, 10.0)
	Combat.start_sensing(c, 50.0, 10.0)
	_space_cracks(pj, c)
	_ground(pj, pj.gp(c.global_position), 50.0, 1.6, {"mode": 0, "tint": Color(0.75, 0.88, 1.0, 0.7), "rings": 2.0, "width": 0.003})
	for n in pj.get_tree().get_nodes_in_group("fighters"):
		if n is ShadowClone and n.get("team") != c.get("team"):
			# klon çözülür: mavi-ak kırık parçalara dağılır
			_spray(pj, n.global_position + Vector3.UP, 16, {"mat": _soft(true, false, 0.0, INK, 1.0, 0.0), "mode": "stretch", "stretch": 0.05,
				"radius": 0.5, "spd": Vector2(1.5, 4.0), "spread": 180.0, "drag": 2.0, "life": Vector2(0.4, 0.7), "size": Vector2(0.12, 0.25),
				"cols": [Color(0.9, 0.97, 1.0, 0.95), Color(JOGAN, 0.0)]})
			n.queue_free()
	if c is Player:
		for s in ["stun", "fear", "confuse"]:
			c.statuses.erase(s)
		Buffs.add("jogan_icgoru", 10.0, {"melee": 1.15, "jutsu": 1.07, "_name": "Jōgan İçgörü", "_desc": "zayıf noktalar görünür, genjutsu işlemez"})
		for f in _targets(c, 50.0):
			_weak_points(pj, f, 10.0)
	Sfx.play("genjutsu", c.global_position, 1.4)


# ═════════════════════════════════════════ 15) Algılama — Böcek Toplama ═════════════════════════════════════════

## Toplanan böcekler (ref: uğur böceği, tırtıl, kurtçuk, kın kanatlı, çekirge, güve). Ön +Z.
static func _critter(kind: int) -> ArrayMesh:
	return _built("critter%d" % kind, func():
		var b = MB.new()
		match kind:
			0:   # uğur böceği
				b.add("sphere", Vector3(0, 0.05, 0), Vector3(0.2, 0.12, 0.24), Color(0.85, 0.12, 0.1), Vector3.ZERO, 12)
				b.add("sphere", Vector3(0, 0.03, 0.12), Vector3(0.1, 0.07, 0.07), INK, Vector3.ZERO, 8)
				for q in 6:
					b.add("sphere", Vector3((q % 2 * 2 - 1) * 0.05, 0.1, -0.06 + (q / 2) * 0.06), Vector3(0.035, 0.02, 0.035), INK, Vector3.ZERO, 6)
				b.add("box", Vector3(0, 0.105, 0), Vector3(0.006, 0.01, 0.22), INK)
			1:   # tırtıl
				for q in 7:
					b.add("sphere", Vector3(0, 0.05 + sin(q * 0.9) * 0.01, -0.21 + q * 0.07), Vector3(0.1, 0.1, 0.09), Color(0.45, 0.68, 0.45).lightened(0.05 * (q % 2)), Vector3.ZERO, 8)
				b.add("sphere", Vector3(0, 0.06, 0.29), Vector3(0.09, 0.09, 0.08), Color(0.35, 0.55, 0.35), Vector3.ZERO, 8)
			2:   # kurtçuk
				for q in 5:
					b.add("sphere", Vector3(0, 0.05, -0.14 + q * 0.07), Vector3(0.1, 0.09, 0.09) * (1.0 - absf(q - 2) * 0.12), Color(0.95, 0.92, 0.82), Vector3.ZERO, 8)
			3:   # kın kanatlı
				b.add("sphere", Vector3(0, 0.05, 0), Vector3(0.16, 0.1, 0.22), Color(0.36, 0.3, 0.26), Vector3.ZERO, 10)
				b.add("sphere", Vector3(0, 0.04, 0.12), Vector3(0.09, 0.07, 0.07), INK, Vector3.ZERO, 8)
				for sx in [-1.0, 1.0]:
					for q in 3:
						b.add("box", Vector3(sx * 0.1, 0.02, -0.06 + q * 0.06), Vector3(0.08, 0.01, 0.012), INK, Vector3(0, sx * (20 - q * 20), sx * -25))
			4:   # çekirge
				b.add("sphere", Vector3(0, 0.06, 0), Vector3(0.07, 0.07, 0.26), Color(0.4, 0.7, 0.3), Vector3.ZERO, 8)
				for sx in [-1.0, 1.0]:
					b.add("box", Vector3(sx * 0.05, 0.1, -0.06), Vector3(0.015, 0.015, 0.2), Color(0.32, 0.58, 0.24), Vector3(30, sx * 10, 0))
					b.add("box", Vector3(sx * 0.03, 0.12, 0.18), Vector3(0.006, 0.006, 0.16), Color(0.32, 0.58, 0.24), Vector3(-30, sx * 15, 0))
			_:   # güve
				b.add("sphere", Vector3(0, 0.05, 0), Vector3(0.06, 0.06, 0.16), Color(0.45, 0.36, 0.22), Vector3.ZERO, 8)
				for sx in [-1.0, 1.0]:
					b.add("sphere", Vector3(sx * 0.1, 0.06, 0.0), Vector3(0.18, 0.012, 0.16), Color(0.98, 0.85, 0.3), Vector3(0, sx * -15, sx * 15), 10)
		return b)


## Böcek: kenardan avuca sürünerek gelir, bekler, sonra dağılır
static func _critter_walk(pj: PathJutsu, kind: int, from: Vector3, to: Vector3, dur: float) -> void:
	var mi = _solid_mi(_critter(kind), 0.006)
	_scene(pj).add_child(mi)
	var away = from + (from - to).normalized() * 1.5
	var ph = randf() * TAU
	_tick(pj, Vector3.ZERO, func(_n, _dt, age) -> bool:
		if not is_instance_valid(mi):
			return false
		if age >= dur:
			mi.queue_free()
			return false
		var p: Vector3
		var d: Vector3
		var s = 1.6
		if age < 0.9:
			var u = age / 0.9
			p = from.lerp(to, 1.0 - pow(1.0 - u, 2.0))
			d = to - from
		elif age < dur - 0.6:
			p = to
			d = to - from
		else:
			var u2 = (age - (dur - 0.6)) / 0.6
			p = to.lerp(away, u2)
			d = away - to
			s *= 1.0 - u2
		var sd = d.cross(Vector3.UP).normalized() if d.cross(Vector3.UP).length() > 0.001 else Vector3.RIGHT
		p += sd * sin(age * 14.0 + ph) * 0.04
		p.y = Game.ground_height(p.x, p.z) + 0.01
		mi.global_transform = Transform3D(_look_basis(Vector3(d.x, 0.0, d.z), maxf(0.01, s)), p)
		return true)


## Gizli Teknik: Böcek Toplama (ref: avuç yere değer, mavi chakra ağı yayılır, böcekler gelir)
static func hijutsu_mushiyose(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "crouch", 1.0)
	var g = pj.gp(c.global_position + c.face_dir() * 0.8)
	Combat.start_sensing(c, 45.0, 12.0)
	# avuçta mavi chakra, zeminde ağ (ışınsal teller + halkalar) açılır
	_spray(pj, g + Vector3.UP * 0.15, 12, {"mat": _soft(false, false, 0.45, Color(0.85, 0.95, 1.0), 0.75, 0.4), "radius": 0.3, "spd": Vector2(0.1, 0.5),
		"dir": Vector3.UP, "spread": 50.0, "life": Vector2(0.5, 0.9), "size": Vector2(0.18, 0.32), "delay": Vector2(0.0, 0.5),
		"cols": [Color(0.45, 0.75, 1.0, 0.0), Color(0.45, 0.75, 1.0, 0.85), Color(0.7, 0.9, 1.0, 0.0)]})
	_ground(pj, g, 6.5, 2.6, {"mode": 2, "tint": Color(0.6, 0.85, 1.0, 0.85), "tint2": Color(0.9, 0.97, 1.0, 0.95), "spokes": 10.0, "rings": 2.4, "width": 0.012}, 0.6)
	for k in 8:
		var a = randf() * TAU
		var from = g + Vector3(cos(a), 0.0, sin(a)) * randf_range(4.5, 6.5)
		var to = g + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.6, 1.3)
		_critter_walk(pj, k % 6, from, to, 2.6)
	Sfx.play("th_bugs", g, 1.2)
	pj.after(0.8, func():
		var n = 0
		for e in pj.enemies_near(c, c.global_position, 45.0):
			pj.st(e, "marked", 12.0)
			n += 1
			if c is Player:
				_moth_mark(pj, e, 12.0)
		if c is Player:
			Hud.msg("Böcekler %d düşmanın yerini fısıldadı (işaretlendi)." % n, Color(0.6, 0.85, 1.0)))


## İşaretli rakibin başı üstünde kanat çırpan küçük güve
static func _moth_mark(pj: PathJutsu, f: Node3D, dur: float) -> void:
	var mi = _solid_mi(_critter(5), 0.006)
	var hf = _head_fn(f, 1.15)
	var ph = randf() * TAU
	var tk = _tick(pj, Vector3.ZERO, func(_n, _dt, age) -> bool:
		if age >= dur:
			return false
		var hv = hf.call()
		if hv == null:
			return false
		var a = age * 2.5 + ph
		var p: Vector3 = (hv as Vector3) + Vector3(cos(a) * 0.35, sin(age * 7.0) * 0.08, sin(a) * 0.35)
		var s = 1.4 * minf(1.0, age / 0.3) * clampf((dur - age) / 0.4, 0.0, 1.0)
		mi.global_transform = Transform3D(_look_basis(Vector3(-sin(a), 0.0, cos(a)), maxf(0.01, s)).scaled(Vector3(1.0, 0.6 + 0.4 * absf(sin(age * 20.0)), 1.0)), p)
		return true)
	tk.add_child(mi)
