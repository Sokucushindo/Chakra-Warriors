// Kamui girdabı (anime ref: refs/kamui_anime — Obito'nun çıkışı/yutuşu, Kakashi'nin uzak Kamui'si): uzay odak noktasına doğru
// SARMAL bükülür. Arkadaki dünya (içindeki beden dahil) merkeze doğru burkularak çekilir (ekran dokusu, gerçek ekran ölçeğinde
// dönen bükülme), üstünde merkeze akan çok sayıda ince koyu mürekkep çizgisi (logaritmik sarmal), ortada küçük kara nokta.
// Kenarda bükülme yumuşakça söner (görünür kabuk / disk yok). Kameraya bakan dörtgen; UV -> ekran dönüşümü türevlerden.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;   // derinlik testi açık: burgaç bedenin ARKASINA konur, beden önünde ona akar

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float strength = 1.0;    // 0..1 açılış/kapanış
uniform float twist = 1.0;       // burkulma çarpanı (1 = merkezde ~1.6 tur)
uniform float pull = 0.35;       // + içe çekiş (yutma), - dışa itiş (çıkış)
uniform float spin = 1.0;        // akış yönü/hızı (+ içe akar)
uniform float core = 0.07;       // kara nokta yarıçapı (UV, 0..0.5)
uniform float ink = 1.0;         // mürekkep çizgisi yoğunluğu

float h1(float n) { return fract(sin(n * 91.345) * 47453.21); }

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;           // 0 merkez .. 1 kenar
	if (r > 1.0) discard;
	float s = strength;
	float dirn = sign(spin + 1e-4);
	float fall = pow(1.0 - r, 1.25);
	float soft = smoothstep(1.0, 0.6, r);
	// güçlü sarmal burkulma (merkezde ~0.8 tur) + içe çekiş; TIME yok (zamanla artan dönüş halkaya sarar)
	float ang0 = pow(1.0 - r, 1.5) * 5.2 * twist * s * dirn;
	float scl = 1.0 + pull * fall * s * 2.0;
	// UV farkını ekran farkına çevir (dörtgen düzlemsel: türev Jakobyeni tam)
	mat2 dS = mat2(dFdx(SCREEN_UV), dFdy(SCREEN_UV));
	mat2 dU = mat2(dFdx(UV), dFdy(UV));
	float det = determinant(dU);
	mat2 J = abs(det) > 1e-12 ? dS * inverse(dU) : mat2(0.0);
	// açısal sürükleme: 4 örnek (anime: arka plan merkez çevresinde yay yay sürüklenmiş çizgilere dönüşür)
	vec3 bg = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		float ang = ang0 * (1.0 - float(k) * 0.12);
		float cs = cos(ang), sn = sin(ang);
		vec2 rc = vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs) * scl;
		vec2 off = J * (rc - c);
		bg += textureLod(screen_tex, clamp(SCREEN_UV + off * soft, vec2(0.001), vec2(0.999)), 0.5).rgb;
	}
	bg *= 0.25;
	// kollar: merkezden çıkıp dönerek açılan kalın, uçlara doğru incelen koyu mürekkep (7) + aralarında ince çizgiler (17)
	float a = atan(c.y, c.x);
	float rr = max(r, 0.015);
	float ph = a * 7.0 / 6.2831853 + log(rr) * 1.25 * twist * dirn - TIME * spin * 0.3;
	float arm = floor(ph);
	float fr = fract(ph);
	float cr = core * 2.0 * s;
	float t = clamp((r - cr) / max(0.92 - cr, 0.05), 0.0, 1.0);
	float taper = pow(sin(3.14159 * pow(t, 0.7)), 0.8);          // ortada kalın, merkezde ve uçta sivri
	float lenk = mix(0.55, 1.0, h1(arm + 5.0));                    // kol boyları farklı
	taper *= 1.0 - smoothstep(lenk - 0.15, lenk, t);
	float w = mix(0.10, 0.26, h1(arm + 3.0)) * taper;
	float line = 1.0 - smoothstep(w * 0.55, w, abs(fr - 0.5));
	float ph2 = a * 17.0 / 6.2831853 + log(rr) * 1.6 * twist * dirn - TIME * spin * 0.45;
	float thin = (1.0 - smoothstep(0.02, 0.05, abs(fract(ph2) - 0.5))) * step(0.35, h1(floor(ph2) + 11.0)) * 0.45;
	thin *= smoothstep(0.95, 0.5, r) * smoothstep(cr, cr * 2.5, r);
	line = max(line, thin) * s * ink;
	float lit = (1.0 - smoothstep(0.0, 0.025, abs(fract(ph + 0.37) - 0.5))) * step(0.55, h1(arm + 9.0)) * taper * s * 0.25;
	vec3 col = bg * (1.0 - 0.42 * fall * s);
	col = mix(col, vec3(0.88, 0.9, 0.96), lit);
	col = mix(col, vec3(0.025, 0.02, 0.045), clamp(line, 0.0, 1.0) * 0.9);
	// kara çekirdek: Kamui boyutuna açılan delik + koyu hale
	float hole = 1.0 - smoothstep(cr * 0.8, cr, r);
	float halo = (1.0 - smoothstep(cr, cr * 3.0, r)) * 0.6 * s;
	col = mix(col, vec3(0.015, 0.01, 0.025), max(hole, halo));
	ALBEDO = col;
	// yumuşak kesişim: zemine / duvara değdiği yerde düz kesik çizgi yerine 1.2 m'de söner
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	float scene_z = -vp.z / vp.w;
	float near_fade = clamp((scene_z - (-VERTEX.z)) / 1.2, 0.0, 1.0);
	ALPHA = clamp(soft * min(1.0, s * 3.0) * near_fade, 0.0, 1.0);
}
