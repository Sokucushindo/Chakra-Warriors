// Dünyada duran Mangekyō diski (Kotoamatsukami: gökteki göz / kurbanın başındaki iz). Desen sahibinin gerçek göz deseni.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
#include "res://shaders/mangekyo.gdshaderinc"
uniform vec4 ms_a = vec4(13.0, 4.0, 1.0, 0.55);
uniform vec4 ms_b = vec4(0.2, 0.0, 0.0, 0.6);
uniform vec4 col : source_color = vec4(0.9, 0.05, 0.06, 1.0);
uniform float fade = 1.0;
uniform float glow = 1.6;
uniform bool billboard = false;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0;
	float r = length(q);
	vec3 c = mix(col.rgb * glow, col.rgb * 0.6, smoothstep(0.45, 1.0, r));
	if (ms_ink(q / 0.94, ms_a, ms_b, TIME) > 0.5) c = vec3(0.02);
	c = mix(c, vec3(0.04, 0.0, 0.0), smoothstep(0.9, 0.96, r));
	ALBEDO = c;
	ALPHA = (1.0 - smoothstep(0.97, 1.0, r)) * fade;
}
