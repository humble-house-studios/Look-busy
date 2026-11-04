// The arcade cages' glass (scenes/ladder/cage3d.gd): nearly clear head on,
// brighter and bluer where you see it edge-on (so the box reads as glass),
// with a soft diagonal sheen that slides across as you walk past.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.75, 0.9, 1.0);
uniform float base_alpha = 0.07;
uniform float edge = 0.4;
uniform float sheen = 0.18;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float f = pow(1.0 - facing, 3.0);
	// Diagonal bands fixed to the world, seen through the camera: they slide
	// across the pane as you move.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float s = sin(dot(wpos - cam * 0.35, vec3(5.0, 7.0, 5.0)));
	float band = smoothstep(0.86, 1.0, s) + 0.5 * smoothstep(0.97, 1.0, sin(dot(wpos, vec3(13.0, 17.0, 13.0))));
	vec3 col = mix(tint * 0.6, vec3(1.0), 0.35 * f + band * 0.6);
	ALBEDO = col;
	ALPHA = clamp(base_alpha + edge * f + band * sheen, 0.0, 0.85);
}
