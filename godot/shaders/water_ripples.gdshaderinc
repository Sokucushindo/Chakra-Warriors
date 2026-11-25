// Su yüzeyi dalgaları (WaterWaves): jutsu çarpması, dev beden, düşüş, su üstünde adım.
// g_ripples: 64x1 RGBAF doku, her teksel bir halka: (x, z, yaş sn, boyut R m). g_ripple_n etkin halka sayısı.
// Tüm su yüzeyleri (deniz, göl, kanal, dere, gölet, şelale havuzu) aynı alanı örnekler: dalga her suda aynı yerde görünür.
global uniform sampler2D g_ripples : filter_nearest;
global uniform float g_ripple_n;

// x: yükseklik (m), yz: eğim (dh/dx, dh/dz), w: köpük 0..1
vec4 ripple_field(vec2 p) {
	vec4 acc = vec4(0.0);
	int n = int(g_ripple_n);
	for (int i = 0; i < n; i++) {
		vec4 r = texelFetch(g_ripples, ivec2(i, 0), 0);
		float R = r.w;
		float age = r.z;
		vec2 d = p - r.xy;
		float dist = length(d);
		dist += (sin(p.x * 1.7 + p.y * 1.3) * 0.6 + sin(p.y * 3.1 - p.x * 2.2) * 0.4) * min(0.04 + R * 0.015, 0.35);   // halka kusursuz daire olmasın (organik kenar)
		float spd = 1.4 + sqrt(R) * 2.3;            // büyük çarpma daha hızlı ve uzağa yayılır
		float lam = 0.32 + R * 0.17;                 // dalga boyu
		float front = age * spd + R * 0.3;
		if (dist > front + lam * 2.0) {
			continue;
		}
		float life = 1.5 + sqrt(R) * 1.5;
		float fade = clamp(1.0 - age / life, 0.0, 1.0);
		if (fade <= 0.0) {
			continue;
		}
		fade *= fade;
		float amp = (0.035 + R * 0.05) * fade / (1.0 + dist / (R * 1.5 + 1.0));
		float x = dist - front;
		// öndeki dalga dik, arkasında sönerek gelen halkalar (büyükte daha çok halka)
		float env = x > 0.0 ? exp(-x * x / (lam * lam * 0.5)) : exp(x / (lam * (2.2 + min(R, 20.0) * 0.08)));
		float ph = x * 6.2831 / lam;
		float w = sin(ph);
		vec2 rdir = dist > 0.001 ? d / dist : vec2(0.0);
		float slope = amp * env * cos(ph) * 6.2831 / lam;
		float cr = R * 0.45 + 0.25;
		float core = exp(-age * 2.5) * exp(-dist * dist / (cr * cr));   // çarpma noktasında kabaran / çöken su
		acc.x += amp * env * w + core * amp * 1.6;
		acc.yz += rdir * slope;
		acc.w += env * fade * smoothstep(0.5, 0.95, w) * (0.4 + min(R, 8.0) * 0.045)
			+ exp(-x * x / (lam * lam * 0.12)) * fade * 0.45
			+ core * fade * 0.9;
	}
	float gl = length(acc.yz);
	if (gl > 1.4) {
		acc.yz *= 1.4 / gl;
	}
	acc.w = 0.85 * (1.0 - exp(-acc.w * 1.3));   // üst üste binen halkalar bembeyaz leke yapmasın
	return acc;
}
