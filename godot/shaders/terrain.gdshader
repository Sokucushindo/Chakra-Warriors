// Clipmap arazi: yükseklik GPU'da makro harita + ayrıntı gürültüsünden hesaplanır (world_height.gdshaderinc).
// Anime/boyalı yüzeyler: çimen lekeleri, katmanlı kaya, kum dalgası, yol (oyuncu çevresindeki yerel yol dokusundan).
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

#include "res://shaders/world_height.gdshaderinc"

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D road_tex : filter_linear, repeat_disable;   // oyuncu çevresindeki yollar (R) - RoadMap düğümü çizer
uniform vec4 road_rect;                                         // x0, z0, boyut, -
uniform vec4 villages[16];                                      // x, z, yarıçap, zemin biyomu
uniform int village_count = 0;
uniform vec4 hokage_rock = vec4(0.0);   // x0, x1, yüz hattı (dünya z), tepe yüksekliği: altın-toprak kaya dağı
uniform float level_eps = 0.0;
uniform sampler2D tex_cobble : filter_linear_mipmap_anisotropic, repeat_enable;   // köy döşemesi (parke taşı)
uniform sampler2D tex_stone : filter_linear_mipmap_anisotropic, repeat_enable;    // cadde iri taş
uniform sampler2D tex_rock : filter_linear_mipmap_anisotropic, repeat_enable;     // yarlar / kayalıklar
uniform sampler2D tex_sand : filter_linear_mipmap_anisotropic, repeat_enable;     // çöl, kumsal
uniform sampler2D tex_forest : filter_linear_mipmap_anisotropic, repeat_enable;   // orman zemini
uniform sampler2D tex_dirt : filter_linear_mipmap_anisotropic, repeat_enable;     // köy dışı toprak yollar
uniform sampler2D tex_grass : filter_linear_mipmap_anisotropic, repeat_enable;    // çimenli zemin
uniform sampler2D tex_snow : filter_linear_mipmap_anisotropic, repeat_enable;     // kar: rüzgârla dalgalanmış kar yüzeyi
uniform float texel = 4.0;

varying vec3 wpos;
varying float slope;
varying vec3 vbump;
varying float vgrass;   // çimen zemini: gölge tonu gri-mor yerine mavi-yeşil   // toprak kabartması (görüş uzayı): ışıkta güneş yönüne göre açık / koyu

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float e = max(texel, 1.5);
	float h = world_height(w.xz);
	// yumuşak normal (kullanıcı: yol "köşeli köşeli"): yükseklik haritası iki doğrusal örneklendiği için tek ölçekli farkta
	// eğim her hücre sınırında sıçrıyor -> düz toprakta köşeli ışık yamaları. Çapraz komşularda ve iki ölçekte ortalama.
	vec2 g = vec2(0.0);
	for (int i = 0; i < 5; i++) {
		vec2 o = (i == 0) ? vec2(0.0) : vec2((i == 1 || i == 2) ? e : -e, (i == 1 || i == 3) ? e : -e) * 0.75;
		float ee = e * 1.5;
		g.x += world_height(w.xz + o + vec2(ee, 0.0)) - world_height(w.xz + o - vec2(ee, 0.0));
		g.y += world_height(w.xz + o + vec2(0.0, ee)) - world_height(w.xz + o - vec2(0.0, ee));
	}
	g /= 5.0;
	vec3 n = normalize(vec3(-g.x, 3.0 * e, -g.y));
	VERTEX.y = h - level_eps;
	NORMAL = n;
	wpos = vec3(w.x, h, w.z);
	slope = 1.0 - n.y;
}

// sinüssüz hash (Hoskins): sin() büyük dünya koordinatlarında GPU'da hassasiyet kaybedip toprakta dikdörtgen ton blokları yapıyordu
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { s += vnoise(p) * a; p *= 2.07; a *= 0.5; } return s; }

// değer gürültüsü + türevi (x: değer, yz: eğim) — kabartma eğimi tek seferde (sonlu farkla 3 kez hesaplamak pahalıydı)
vec3 vnoise_d(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	float k = a - b - c + d;
	return vec3(a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y, du * vec2((b - a) + k * u.y, (c - a) + k * u.x));
}

// yuvarlak taşlar: hücre başına en fazla bir taş, hücreden taşmaz (tek hücre bakılır); kubbe yüksekliği (m) + eğim
vec3 pebbles(vec2 p, float cell, float dens, float rmin, float rmax) {
	vec2 c = floor(p / cell);
	if (hash(c + 3.7) > dens) return vec3(0.0);
	float r = mix(rmin, rmax, hash(c + 5.9));
	float sq = 1.0 + hash(c + 8.1) * 0.5;   // biraz yassı
	float m = r * sq / cell;
	vec2 o = mix(vec2(m), vec2(1.0 - m), vec2(hash(c), hash(c + 1.3)));
	vec2 d = (p / cell - c - o) * cell;
	d.x *= sq;
	float k = 1.0 - dot(d, d) / (r * r);
	if (k <= 0.0) return vec3(0.0);
	float hk = r * 0.55;
	float sk = sqrt(max(k, 0.03));
	return vec3(sqrt(k) * hk, hk * 0.5 / sk * (-2.0 / (r * r)) * vec2(d.x * sq, d.y));
}

// toprak yol kabartması (m) + eğim: yumrular + seyrek taş / çakıl tümsekleri (çatlak denendi: kıvrık solucan gibi duruyordu).
// fk / mk: ince / orta ayrıntı payı (uzakta piksel altına düşen ayrıntı söner: kıpırdama yok)
vec3 dirt_h(vec2 p, float fk, float mk) {
	vec3 n1 = vnoise_d(p * 0.7), n2 = vnoise_d(p * 2.3 + 5.1);
	vec3 h = vec3(n1.x - 0.5, n1.yz * 0.7) * 0.10 * mk + vec3(n2.x - 0.5, n2.yz * 2.3) * 0.04 * mk;
	h += pebbles(p, 0.9, 0.3, 0.07, 0.16) * 0.85 * mk;           // seyrek iri taş (7-16 cm yarıçap)
	h += pebbles(p + 17.0, 0.35, 0.45, 0.03, 0.07) * 0.85 * fk;   // çakıl
	return h;
}

void fragment() {
	vgrass = 0.0;
	vec2 uv = (wpos.xz - world_rect.xy) / world_rect.zw;
	vec3 base = texture(albedo_map, uv).rgb;
	vec4 bio = wh_bilin(biome_map, wpos.xz);
	ivec2 bc = clamp(ivec2((wpos.xz - world_rect.xy) / macro_res), ivec2(0), ivec2(macro_size) - 1);
	int b = int(texelFetch(biome_map, bc, 0).r * 255.0 + 0.5);
	// köy zemini: keskin daire (makro harita 32 m, köy kenarı tırtıklı olmasın)
	for (int i = 0; i < village_count; i++) {
		vec4 v = villages[i];
		float d = length(wpos.xz - v.xy);
		if (d < v.z * 0.95) { b = int(v.w); }
	}
	float n1 = fbm(wpos.xz * 0.08);
	float n2 = vnoise(wpos.xz * 0.9);
	float n3 = vnoise(wpos.xz * 4.0);
	float n4 = fbm(wpos.xz * 0.011);
	// geniş ölçekli renk çeşitliliği (32 m doku düz görünmesin)
	base *= 0.9 + n4 * 0.22;
	if (b == 11) base = vec3(0.2, 0.42, 0.1);   // köy çimeni: ot öbekleriyle aynı koyu doygun yeşil (soluk açık yeşil lekeler kalmasın)
	if (b == 13) base = vec3(0.85, 0.71, 0.52);
	if (b == 14) base = vec3(0.59, 0.57, 0.53);
	if (b == 15) base = vec3(0.89, 0.91, 0.94);
	// boyalı çimen: büyük açık/koyu lekeler + sarımsı çiçekli alanlar
	float gfw = length(fwidth(wpos.xz));   // piksel başı metre (dal dışında: türev dallı akışta tanımsız)
	if (b == 2 || b == 7 || b == 6 || b == 11 || b == 4 || b == 10) {
		// net kenarlı iki basamak açık/koyu alan (anime boyama; eskisi tek yumuşak geçiş: bulanık halı)
		float patch = smoothstep(0.47, 0.51, n1) * 0.6 + smoothstep(0.6, 0.64, n1) * 0.4;
		base *= mix(0.84, 1.14, patch);
		base = mix(base, base * vec3(1.12, 1.08, 0.7), smoothstep(0.7, 0.85, fbm(wpos.xz * 0.03 + 7.0)) * 0.6);
		base *= 0.93 + n3 * 0.12;
		float gk = 1.0 - smoothstep(0.02, 0.08, gfw);   // yakın ayrıntı: uzakta söner
		if (gk > 0.0) {
			// temas gölgesi: çimen tutamlarının dibi koyu (grass.gdshader ile aynı 0.6 m ızgara + kayma: tutamın tam altına düşer)
			vec2 gc = floor(wpos.xz / 0.6 + 0.5);
			float ao = 0.0;
			for (int gy = -1; gy <= 1; gy++) {
				for (int gx = -1; gx <= 1; gx++) {
					vec2 cl = gc + vec2(float(gx), float(gy));
					vec2 ctr = cl * 0.6 + (vec2(hash(cl + 1.7), hash(cl + 9.3)) - 0.5) * 0.6;
					float hs = 0.7 + hash(cl + 2.9) * 0.6;
					float on = (b == 11) ? step(0.12, hash(floor(ctr * 0.18))) : 1.0;   // köyde çimensiz açıklıkta leke yok
					ao = max(ao, (1.0 - smoothstep(0.05 * hs, 0.22 * hs, distance(wpos.xz, ctr))) * on);   // küçük: seyrek yerde çamur birikintisi gibi durmasın
				}
			}
			base *= 1.0 + (0.05 - ao * 0.3) * gk;   // tutam dibi koyu, aralar biraz açık (ortalama parlaklık korunur)
		}
		// gerçek çimen zemini: yakında ince yaprak dokusu, uzakta iri lekeler (iki ölçek: tekrar deseni görünmesin)
		float gt = texture(tex_grass, wpos.xz * 0.16).r * 0.6 + texture(tex_grass, wpos.xz * 0.023 + 0.37).r * 0.4;
		base *= 1.0 + (gt - 0.5) * 0.28;   // doku gri toprak fotoğrafı: güçlüyken (0.75) yeşili kirli çamur lekesine çeviriyordu
		// koyulaşan yer kahveye değil derin yeşile gitsin: parlaklık düştükçe doygunluk artar, ton mavi-yeşile kayar
		float glum = dot(base, vec3(0.299, 0.587, 0.114));
		float gdark = clamp(1.0 - glum / 0.3, 0.0, 1.0);
		base = max(mix(vec3(glum), base, 1.0 + gdark * 0.25), vec3(0.0)) * mix(vec3(1.0), vec3(0.9, 1.0, 0.96), gdark);
		vgrass = 1.0;
	}
	// çöl köyü (Suna): kum taşı döşeme + seyrek yeşillik. Konoha (11) eski hâlinde: çimen zemin
	if (b == 13) {
		vec2 tt = wpos.xz / vec2(2.2, 1.6);
		tt.x += step(0.5, fract(tt.y * 0.5)) * 0.5;
		vec2 f = abs(fract(tt) - 0.5);
		float joint = smoothstep(0.44, 0.49, max(f.x, f.y));
		float tone = hash(floor(tt));
		vec3 pave = mix(vec3(0.8, 0.68, 0.49), vec3(0.88, 0.77, 0.58), tone);
		pave *= (1.0 - joint * 0.25) * (0.94 + n3 * 0.08);
		pave *= 1.0 + (texture(tex_cobble, wpos.xz * 0.45).r - 0.5) * 0.8;
		pave = mix(pave, pave * vec3(0.82, 0.8, 0.74), smoothstep(0.55, 0.8, fbm(wpos.xz * 0.05 + 3.0)) * 0.5);
		float bed = smoothstep(0.49, 0.53, fbm(wpos.xz * 0.045 + 11.0));
		float dirt = smoothstep(0.46, 0.49, fbm(wpos.xz * 0.045 + 11.0)) * (1.0 - bed);
		vec3 ground = mix(pave, vec3(0.7, 0.55, 0.38), dirt);
		ground = mix(ground, mix(base, vec3(0.55, 0.62, 0.32), 0.6), bed * 0.35);
		base = ground;
	}
	if (b == 2) base *= 1.0 + (texture(tex_forest, wpos.xz * 0.12).r - 0.5) * 0.7;   // orman zemini: yaprak, dal, toprak
	if (b == 3 || b == 1 || b == 13) base *= 1.0 + (texture(tex_sand, wpos.xz * 0.15).r - 0.5) * 0.7;   // kum dokusu
	if (b == 3 || b == 1) {
		float rip = sin(wpos.x * 1.6 + wpos.z * 0.7 + n1 * 6.0) * 0.5 + 0.5;
		base *= 0.92 + rip * 0.1 + n2 * 0.06;
	}
	if (b == 13) {
		float rip = sin(wpos.x * 1.1 + wpos.z * 0.5 + n1 * 5.0) * 0.5 + 0.5;
		base *= 0.93 + rip * 0.06 + n2 * 0.06;
	}
	if (b == 14) {
		vec2 tt = wpos.xz / 1.7;
		tt.x += step(0.5, fract(tt.y * 0.5)) * 0.5;
		vec2 f = abs(fract(tt) - 0.5);
		float joint = smoothstep(0.45, 0.49, max(f.x, f.y));
		base *= (0.9 + hash(floor(tt)) * 0.18) * (1.0 - joint * 0.3);
		base *= 1.0 + (texture(tex_stone, wpos.xz * 0.35).r - 0.5) * 0.8;   // taş köy döşemesi
	}
	if (b == 15 || b == 8) {
		base = mix(base, vec3(1.0), 0.12) + step(0.985, n3) * 0.22;
		// kar dokusu iki ölçekte (tekrar görünmesin) + rüzgâr sırtları + mavimsi çukurlar
		float sn = texture(tex_snow, wpos.xz * 0.12).r * 0.6 + texture(tex_snow, wpos.xz * 0.021 + 0.41).r * 0.4;
		base *= 0.86 * (1.0 + (sn - 0.5) * 1.2);   // beyaza patlamasın: doku görünsün
		float drift = sin(wpos.x * 0.35 + wpos.z * 0.18 + n1 * 5.0) * 0.5 + 0.5;
		base = mix(base, base * vec3(0.84, 0.9, 1.0), smoothstep(0.55, 0.95, drift) * 0.35);
	}
	// yol: yerel yol dokusu (2 m), dışında kaba makro yol
	vec2 ruv = (wpos.xz - road_rect.xy) / max(road_rect.z, 1.0);
	float rmask;
	if (road_rect.z > 0.0 && ruv.x > 0.01 && ruv.y > 0.01 && ruv.x < 0.99 && ruv.y < 0.99) {
		// 2 m/piksel maske: tek örnek + keskin eşik dikdörtgen ton blokları yapıyordu (kullanıcı: "köşeli köşeli") -> 9 noktalı yumuşatma
		vec2 tx = 1.0 / vec2(textureSize(road_tex, 0));
		rmask = texture(road_tex, ruv).r * 0.25;
		rmask += (texture(road_tex, ruv + vec2(tx.x, 0.0)).r + texture(road_tex, ruv - vec2(tx.x, 0.0)).r
			+ texture(road_tex, ruv + vec2(0.0, tx.y)).r + texture(road_tex, ruv - vec2(0.0, tx.y)).r) * 0.125;
		rmask += (texture(road_tex, ruv + tx).r + texture(road_tex, ruv - tx).r
			+ texture(road_tex, ruv + vec2(tx.x, -tx.y)).r + texture(road_tex, ruv + vec2(-tx.x, tx.y)).r) * 0.0625;
	} else {
		rmask = smoothstep(0.55, 0.9, bio.g) * 0.8;
	}
	// toprak yol (ref toprakyol.png): kenar dalgalı ve düzensiz (genişlik yol boyunca değişir), çim öbekleri kenara taşar
	float ew = vnoise(wpos.xz * 0.07) * 0.55 + vnoise(wpos.xz * 0.3) * 0.3 + vnoise(wpos.xz * 1.3) * 0.15;
	float rm2 = rmask + (ew - 0.5) * 0.6;
	float road = smoothstep(0.36, 0.52, rm2);
	road *= smoothstep(-0.6, 0.1, wpos.y);   // su altında (deniz seviyesi 0) yol boyanmaz
	// lekeli toprak: büyük açık/koyu alanlar + küçük koyu benekler (çiğnenmiş toprak), ortası daha açık (yürüme izi)
	// (yol dokusu 2 m/piksel: tonu ona bağlamak kare kare desen yapıyordu -> yalnız yumuşak dünya gürültüsü)
	float blot = fbm(wpos.xz * 0.18 + vec2(13.1, 7.7));
	float blot2 = fbm(wpos.xz * 0.6 + vec2(3.3, 1.9));
	// anime boyama: açık-koyu alanlar net kenarlı iki basamak (eskisi tek yumuşak geçiş: tonlar birbirine bulanıyordu)
	vec3 dirt = mix(vec3(0.5, 0.36, 0.23), vec3(0.74, 0.58, 0.39), smoothstep(0.42, 0.47, blot) * 0.55 + smoothstep(0.58, 0.62, blot) * 0.45);
	dirt = mix(dirt, dirt * vec3(0.78, 0.8, 0.7), smoothstep(0.6, 0.64, blot2) * 0.7);           // zeytin-koyu lekeler (ref)
	dirt *= mix(0.84, 1.0, smoothstep(0.55, 0.95, rm2));   // kenara doğru koyu, orta açık (yürüme izi)
	dirt *= 0.94 + n3 * 0.1;
	dirt = pow(dirt, vec3(2.2));   // tonlar sRGB'de seçildi (lineer verilince soluk bej görünüyordu)
	if (b == 14 || b == 15) dirt = vec3(0.62, 0.6, 0.56) * (0.88 + n3 * 0.16);
	if (b == 8 || b == 9) dirt = vec3(0.52, 0.47, 0.42) * (0.88 + n3 * 0.18);  // karlı/dağ yolu: ıslak çakıl
	// toprak dokusu her yerde iki ölçekte (kullanıcı: "aşırı bulanık"; köy içinde hiç ince doku yoktu) + küçük çakıl benekleri
	float td = texture(tex_dirt, wpos.xz * 0.35).r * 0.6 + texture(tex_dirt, wpos.xz * 0.09 + 0.31).r * 0.4;
	dirt *= 1.0 + (td - 0.5) * (b != 11 ? 0.9 : 0.75);
	float peb = vnoise(wpos.xz * 6.0);
	dirt = mix(dirt, dirt * 1.25, smoothstep(0.82, 0.9, peb) * 0.6);
	dirt = mix(dirt, dirt * 0.7, smoothstep(0.85, 0.93, vnoise(wpos.xz * 5.0 + 17.0)) * 0.5);
	// kabartma (kullanıcı: "düz zemin"): yükseklikten normal + oyuk koyu / tümsek açık boyama
	vec3 dnrm = vec3(0.0);
	float fw = length(fwidth(wpos.xz));   // dal dışında (türev dallı akışta tanımsız)
	float fk = 1.0 - smoothstep(0.012, 0.04, fw);
	float mk = 1.0 - smoothstep(0.04, 0.15, fw);
	if (road > 0.01 && mk > 0.0) {
		vec3 hd = dirt_h(wpos.xz, fk, mk);
		float h0 = hd.x;
		vec2 dg = hd.yz;
		float dl = length(dg);
		if (dl > 0.9) dg *= 0.9 / dl;
		dnrm = vec3(-dg.x, 0.0, -dg.y) * road;
		dirt *= 1.0 + clamp(h0 * 3.5, -0.3, 0.25);
	}
	// kenar: toprağın hemen dışında koyu çim kuşağı (çim öbeklerinin gölgesi, anime boyama gibi)
	float rim = smoothstep(0.3, 0.42, rm2) * (1.0 - road);
	base *= 1.0 - rim * 0.28;
	base = mix(base, dirt, road * 0.95);
	// yarlar: katmanlı kaya
	float rock = smoothstep(0.3, 0.5, slope + (n2 - 0.5) * 0.18);
	float strata = sin(wpos.y * 0.9 + n1 * 3.0) * 0.5 + 0.5;
	float strata2 = sin(wpos.y * 3.1 + n2 * 2.0) * 0.5 + 0.5;
	vec3 rockc = mix(vec3(0.45, 0.4, 0.36), vec3(0.62, 0.55, 0.47), strata);
	if (b == 3 || b == 5) rockc = mix(vec3(0.62, 0.42, 0.3), vec3(0.8, 0.6, 0.42), strata);
	rockc *= 0.85 + strata2 * 0.2;
	rockc *= mix(0.75, 1.0, smoothstep(0.0, 0.15, abs(fract(wpos.y * 0.25 + n1) - 0.5)));
	rockc *= 1.0 + (texture(tex_rock, vec2(wpos.x + wpos.z, wpos.y) * 0.06).r - 0.5) * 1.1;   // gerçek kaya yüzeyi dokusu
	// tüm yarlar: dikey çatlaklar + kaya blokları (düz bant bant duvar gibi durmasın)
	float blk = vnoise(vec2(wpos.x * 0.045 + wpos.z * 0.045, wpos.y * 0.09));
	float crk = smoothstep(0.86, 0.95, vnoise(vec2((wpos.x + wpos.z) * 0.11, wpos.y * 0.018)));
	rockc *= (0.88 + blk * 0.24) * (1.0 - crk * 0.45);
	// Hokage Kayası: altın-toprak sarısı kaya dağı (referans), koyu oyuklar, aydınlık çıkıntılar, yer yer yeşil çalı kümeleri
	if (hokage_rock.w > 0.0 && wpos.x > hokage_rock.x - 400.0 && wpos.x < hokage_rock.y + 400.0 && wpos.z < hokage_rock.z + 120.0 && wpos.z > hokage_rock.z - 900.0) {
		float k1 = fbm(wpos.xz * 0.012 + vec2(wpos.y * 0.01));
		float k2 = vnoise(vec2((wpos.x + wpos.z) * 0.06, wpos.y * 0.035));
		vec3 gold = mix(vec3(0.42, 0.28, 0.14), vec3(0.8, 0.6, 0.3), smoothstep(0.2, 0.8, k1 * 0.6 + k2 * 0.4));
		gold = mix(gold, vec3(0.92, 0.74, 0.42), smoothstep(0.8, 0.95, k2) * 0.5);          // aydınlık çıkıntı
		float groove = vnoise(vec2((wpos.x + wpos.z) * 0.05, wpos.y * 0.008)) * 0.6 + vnoise(vec2((wpos.x + wpos.z) * 0.17, wpos.y * 0.02)) * 0.4;
		gold *= mix(1.08, 0.55, smoothstep(0.55, 0.85, groove));                               // dikey oluk gölgeleri (kontrast)
		gold *= 1.0 - smoothstep(0.86, 0.94, vnoise(vec2((wpos.x + wpos.z) * 0.12, wpos.y * 0.015))) * 0.5;   // ince çatlaklar
		gold *= 0.85 + blk * 0.3;
		float moss = smoothstep(0.62, 0.72, fbm(wpos.xz * 0.02 + vec2(7.0, wpos.y * 0.03))) * smoothstep(0.75, 0.45, slope);
		gold = mix(gold, vec3(0.22, 0.42, 0.36), moss * 0.85);                                // yeşil çalı kümeleri
		rockc = gold * 0.86 * (1.0 + (texture(tex_rock, vec2(wpos.x + wpos.z, wpos.y) * 0.05).r - 0.5) * 1.4);   // kaya dokusu altın tonda da
	}
	base = mix(base, rockc, rock);
	// nehir kıyısı ıslaklığı + sahil
	base = mix(base, base * vec3(0.7, 0.85, 0.75), bio.b * 0.5);
	base *= mix(0.72, 1.0, smoothstep(-0.2, 1.4, wpos.y));
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	base = max(mix(vec3(lum), base, 1.12), vec3(0.0));
	ALBEDO = base;
	ROUGHNESS = 0.95;
	vbump = mat3(VIEW_MATRIX) * dnrm * (1.0 - rock);
	NORMAL = normalize(NORMAL + vbump);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// ikinci bant yumuşak: düz zeminde ndl tam keskin eşiğe denk gelince her üçgen ayrı ton alıyor (kare kare zemin)
	float t = smoothstep(-0.03, 0.05, ndl) * 0.6 + smoothstep(0.1, 0.65, ndl) * 0.4;
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 shade = mix(mix(vec3(0.3, 0.33, 0.5), vec3(0.26, 0.4, 0.42), vgrass), vec3(1.0), t * ATTENUATION);   // koyu, belirgin gölge (eskisi 0.5: gölgeler seçilmiyordu)
		shade *= 1.0 + clamp(dot(vbump, LIGHT) * 0.9, -0.32, 0.22) * ATTENUATION;   // tepe güneşte de kabartma seçilsin (toon bandı doyuyor)
		DIFFUSE_LIGHT += LIGHT_COLOR * shade / PI;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR * (0.35 + 0.65 * t) * ATTENUATION / PI;
	}
}
