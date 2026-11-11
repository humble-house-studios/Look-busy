shader_type canvas_item;
// The title screen's camera picture (busy_title.gd), finished like a 2007
// console title: bloom round everything bright, a warm golden-hour grade
// with violet shadows, a soft light leak from the window side, a touch of
// colour fringing at the edges, film grain and a vignette. `flash` is the
// white-gold dip between shots.

uniform float flash = 0.0;
uniform float leak = 1.0;
uniform float bloom = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 bright(sampler2D tex, vec2 uv) {
	vec3 c = texture(tex, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	return c * smoothstep(0.78, 1.0, l);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 c = uv - 0.5;
	// Colour fringing, stronger toward the corners.
	vec2 fr = c * dot(c, c) * 0.012;
	vec3 col = vec3(texture(TEXTURE, uv + fr).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - fr).b);
	// Bloom: two rings of taps round the pixel, bright parts only.
	vec3 glow = vec3(0.0);
	float aspect = px.y / px.x;
	for (int i = 0; i < 10; i++) {
		float a = float(i) * 0.6283 + 0.3;
		vec2 d = vec2(cos(a), sin(a) * aspect);
		glow += bright(TEXTURE, uv + d * 0.012) * 0.6;
		glow += bright(TEXTURE, uv + d * 0.03) * 0.4;
	}
	col *= 0.9;
	col += glow / 10.0 * bloom;
	// Grade: lift the shadows toward violet, warm the highlights, a gentle
	// S-curve for punch.
	float l = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, col * vec3(1.06, 0.98, 0.88), smoothstep(0.35, 0.9, l));
	col += vec3(0.05, 0.02, 0.08) * (1.0 - smoothstep(0.0, 0.35, l));
	col = clamp(col, 0.0, 1.4);
	col = mix(col, col * col * (3.0 - 2.0 * min(col, vec3(1.0))), 0.35);
	// Roll the brightest highlights off instead of clipping them flat.
	vec3 over = max(col - 0.8, vec3(0.0));
	col = min(col, vec3(0.8)) + over / (1.0 + over * 2.5);
	// A light leak drifting in from the left (the window side).
	float lk = smoothstep(0.75, 0.0, uv.x + sin(TIME * 0.3) * 0.08) * (0.55 + 0.45 * sin(TIME * 0.21 + uv.y * 2.0));
	col += vec3(1.0, 0.5, 0.2) * lk * 0.08 * leak;
	// Vignette and grain.
	col *= 1.0 - smoothstep(0.35, 0.85, length(c * vec2(1.0, 0.8))) * 0.55;
	col += (hash(uv * 900.0 + fract(TIME * 7.0) * 50.0) - 0.5) * 0.035;
	// The dip between shots.
	col = mix(col, vec3(1.0, 0.9, 0.72), flash);
	COLOR = vec4(col, 1.0);
}
