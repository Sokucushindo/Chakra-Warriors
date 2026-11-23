extends RefCounted
## Aynı modeli farklı renkte göstermek: toon gölgelendiricisinin boya eşlemesi (dye_a: kaynak renk ailesi -> hedef renk,
## tonlar korunur). Kafalık / maske önbelleği rengi anahtardan çıkarır; ilk kurulan renk saklanır, diğer renkler bununla çevrilir
## (her farklı renkli NPC'de başlığı sıfırdan kurmak FPS'i 7-10'a düşürüyordu). Malzemeler çift başına önbellekli.

static var _mats := {}


static func mat(src: Color, dst: Color) -> Material:
	if src.is_equal_approx(dst):
		return Props.toon()
	var k := src.to_html(false) + ">" + dst.to_html(false)
	if _mats.has(k):
		return _mats[k]
	if _mats.size() > 400:
		_mats.clear()
	var m: ShaderMaterial = Props.toon().duplicate()
	m.set_shader_parameter("dye_a", Vector4(src.r, src.g, src.b, 1.0))
	m.set_shader_parameter("dye_a_to", Vector4(dst.r, dst.g, dst.b, 1.0))
	_mats[k] = m
	return m


## Kaynak renk ailesinden bir rengi (ör. sarkan uç rengi) hedefe çevirir: parlaklık oranı korunur
static func remap(c: Color, src: Color, dst: Color) -> Color:
	var ls := maxf((src.r + src.g + src.b) / 3.0, 0.002)
	var lc := maxf((c.r + c.g + c.b) / 3.0, 0.002)
	var k := lc / ls
	if (Vector3(c.r, c.g, c.b) / lc).distance_to(Vector3(src.r, src.g, src.b) / ls) > 0.25:
		return c
	return Color(clampf(dst.r * k, 0, 1), clampf(dst.g * k, 0, 1), clampf(dst.b * k, 0, 1), c.a)
