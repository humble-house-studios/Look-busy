shader_type canvas_item;
// LOOK BUSY on the title screen (busy_title.gd): polished gold, bright on
// top and deep orange underneath with a hard sheen line across the middle,
// a white glint sweeping through every few seconds. The dark outline the
// Label draws first is left as it is.

uniform float height = 120.0;
uniform float width = 600.0;
uniform float glint = 0.0;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (COLOR.r < 0.6) {
		COLOR = tex * COLOR;
	} else {
		float g = clamp(lp.y / height, 0.0, 1.0);
		vec3 top = vec3(1.0, 0.98, 0.84);
		vec3 mid = vec3(1.0, 0.82, 0.32);
		vec3 low = vec3(0.98, 0.48, 0.1);
		vec3 col = mix(top, mid, smoothstep(0.15, 0.5, g));
		col = mix(col, low, smoothstep(0.52, 0.95, g));
		// The sheen line: a bright edge just above the middle.
		col += vec3(0.35, 0.3, 0.2) * (1.0 - smoothstep(0.0, 0.04, abs(g - 0.5)));
		// The glint, a slanted white band crossing left to right.
		float x = lp.x / width - g * 0.18;
		col += vec3(1.0) * (1.0 - smoothstep(0.0, 0.05, abs(x - glint))) * 0.85;
		COLOR = vec4(col, tex.a * COLOR.a);
	}
}
