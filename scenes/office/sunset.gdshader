shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
// The sunset: a painted evening over the bay, alive. It hangs framed on the
// office wall (office.gd _build_sunset_picture), fills the view out of
// Dale's window (_build_window), and opens the title screen
// (busy_title.gd, the camera starts on the picture). The sun sinks and
// rises a little on a slow loop, clouds drift, the water glitters, the palm
// sways, two gulls cross. `night` (after hours) turns it to dusk: the sun
// gone, stars out, the city lit. Drawn on a chunky texel grid with an
// ordered dither, like everything else in the office.

uniform float night : hint_range(0.0, 1.0) = 0.0;
// Width / height of the quad (keeps the sun round).
uniform float aspect = 1.5;
// Texels across the picture (the PS1 grid); 0 = smooth.
uniform float grid = 260.0;
// How bright it reads in the room (the print is lit by the room, the
// window view is the real light).
uniform float level = 1.0;
// Where the horizon and the sun sit (0..1 up the picture).
uniform float horizon = 0.36;
uniform float sun_x = 0.6;
// 1 = the window view (no palm in front, the city wider).
uniform float window_view = 0.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 3.7);
		a *= 0.5;
	}
	return v;
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec3 scene(vec2 uv, float t) {
	float h = horizon;
	float dusk = smoothstep(0.0, 1.0, night);
	// The sun drifts down and back up over a couple of minutes, and sinks
	// right away after hours.
	vec2 sun = vec2(sun_x, h + 0.085 + 0.035 * sin(t * 0.045) - dusk * 0.2);
	vec2 q = vec2(uv.x * aspect, uv.y);
	vec2 sq = vec2(sun.x * aspect, sun.y);
	float d = length(q - sq);

	// ---- sky: gold at the horizon, coral, then violet up top.
	vec3 top = mix(vec3(0.28, 0.2, 0.48), vec3(0.03, 0.04, 0.13), dusk);
	vec3 mid = mix(vec3(0.98, 0.46, 0.42), vec3(0.2, 0.12, 0.3), dusk);
	vec3 low = mix(vec3(1.0, 0.74, 0.36), vec3(0.5, 0.22, 0.28), dusk);
	float y = uv.y - h;
	vec3 col = mix(low, mid, smoothstep(0.0, 0.22, y));
	col = mix(col, top, smoothstep(0.2, 0.62, y));
	// The glow round the sun.
	col += vec3(1.0, 0.58, 0.25) * exp(-d * 5.5) * 0.55 * (1.0 - dusk * 0.8);
	// Stars after hours.
	vec2 sg = floor(uv * vec2(aspect, 1.0) * 90.0);
	float star = step(0.985, hash(sg)) * smoothstep(0.12, 0.35, y) * (0.6 + 0.4 * sin(t * 3.0 + hash(sg + 3.0) * 40.0));
	col += vec3(0.9, 0.9, 1.0) * star * dusk;

	// ---- the sun.
	float r = 0.075;
	float disc = 1.0 - smoothstep(r - 0.004, r + 0.004, d);
	vec3 sun_col = mix(vec3(1.0, 0.95, 0.72), vec3(1.0, 0.62, 0.3), smoothstep(0.0, r, sun.y - uv.y + r * 0.4));
	col = mix(col, sun_col, disc * step(h, uv.y));

	// ---- clouds: long streaks drifting right, lit from underneath.
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		vec2 cp = vec2(uv.x * (2.2 + fi) * aspect * 0.5 - t * (0.006 + fi * 0.004), uv.y * (11.0 + fi * 5.0) + fi * 7.0);
		float c = fbm(cp);
		float band = smoothstep(0.03, 0.09, y) * (1.0 - smoothstep(0.3 + fi * 0.15, 0.55 + fi * 0.15, y));
		float m = smoothstep(0.52, 0.68, c) * band;
		float under = clamp((fbm(cp + vec2(0.0, -0.35)) - c) * 6.0 + 0.5, 0.0, 1.0);
		vec3 lit = mix(vec3(1.0, 0.62, 0.48), vec3(1.0, 0.85, 0.55), exp(-d * 4.0));
		vec3 shade = mix(vec3(0.55, 0.3, 0.5), vec3(0.62, 0.32, 0.42), fi);
		vec3 cc = mix(shade, lit, under);
		cc = mix(cc, vec3(0.16, 0.1, 0.22), dusk * 0.85);
		col = mix(col, cc, m * 0.9);
	}

	// ---- far hills, hazy purple, lighter toward the sun.
	float hill = h + (0.02 + 0.075 * smoothstep(0.42, 0.0, uv.x) + 0.04 * smoothstep(0.78, 1.0, uv.x)) * (0.65 + 0.35 * fbm(vec2(uv.x * 9.0, 1.0)));
	vec3 hill_col = mix(vec3(0.5, 0.3, 0.45), vec3(0.85, 0.5, 0.45), exp(-abs(uv.x - sun.x) * 3.0) * 0.6);
	hill_col = mix(hill_col, vec3(0.1, 0.07, 0.16), dusk);
	if (uv.y < hill && uv.y >= h) {
		col = hill_col;
	}

	// ---- the city on the far shore: blocks, windows lit as it gets dark.
	float cw = window_view > 0.5 ? 0.55 : 0.36;
	if (uv.x < cw) {
		float bx = floor(uv.x * 70.0);
		float bh = 0.012 + 0.07 * pow(hash(vec2(bx, 2.0)), 2.2) * smoothstep(cw, cw * 0.4, uv.x);
		if (uv.y >= h && uv.y < h + bh) {
			col = mix(vec3(0.33, 0.2, 0.36), vec3(0.06, 0.05, 0.1), dusk);
			vec2 wg = floor(vec2(uv.x * 280.0, uv.y * 260.0));
			float lit = step(0.55, hash(wg)) * step(0.5, fract(uv.x * 140.0)) * (0.25 + 0.75 * dusk);
			col += vec3(1.0, 0.82, 0.4) * lit * 0.8;
		}
	}

	// ---- the bay: deep blue-violet, the sun's road glittering down it.
	if (uv.y < h) {
		float depth = h - uv.y;
		vec3 far = mix(vec3(0.78, 0.45, 0.5), vec3(0.18, 0.12, 0.25), dusk);
		vec3 near = mix(vec3(0.16, 0.16, 0.38), vec3(0.03, 0.04, 0.1), dusk);
		col = mix(far, near, smoothstep(0.0, h, depth));
		float wave = sin(depth * 160.0 / (depth + 0.06) - t * 1.4 + noise(vec2(uv.x * 30.0, depth * 40.0)) * 3.0);
		float road = exp(-abs(uv.x - sun.x) * aspect / (0.035 + depth * 0.5)) * (1.0 - dusk);
		float glint = smoothstep(0.55, 0.95, wave) * step(0.35, noise(vec2(uv.x * 90.0, depth * 70.0 - t * 2.0)));
		col += vec3(1.0, 0.72, 0.4) * road * (0.25 + 0.9 * glint);
		col += vec3(0.25, 0.2, 0.35) * smoothstep(0.7, 1.0, wave) * 0.15;
		// The city's lights in the water.
		if (uv.x < cw) {
			col += vec3(1.0, 0.8, 0.4) * dusk * 0.25 * step(0.8, hash(floor(vec2(uv.x * 140.0, depth * 90.0 - t)))) * smoothstep(0.08, 0.0, depth);
		}
	}

	// ---- two gulls crossing.
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		vec2 gp = vec2(fract(t * 0.012 + fi * 0.37) * 1.4 - 0.2, h + 0.3 + fi * 0.06 + sin(t * 0.3 + fi) * 0.02);
		vec2 gq = (uv - gp) * vec2(aspect, 1.0);
		float flap = 0.012 + 0.006 * sin(t * 6.0 + fi * 2.0);
		float g = min(seg(gq, vec2(-0.022, flap), vec2(0.0, 0.0)), seg(gq, vec2(0.0, 0.0), vec2(0.022, flap)));
		col = mix(col, vec3(0.15, 0.08, 0.15), (1.0 - smoothstep(0.002, 0.004, g)) * (1.0 - dusk * 0.5));
	}

	// ---- a palm in front, swaying (the painting only).
	if (window_view < 0.5) {
		vec2 base = vec2(0.86, 0.0);
		float sway = sin(t * 0.7) * 0.012;
		vec2 crown = vec2(0.8 + sway, 0.78);
		vec2 pq = uv * vec2(aspect, 1.0);
		float trunk = 1e3;
		vec2 prev = base * vec2(aspect, 1.0);
		for (int i = 1; i <= 6; i++) {
			float k = float(i) / 6.0;
			vec2 p = mix(base, crown, k);
			p.x += sin(k * 2.4) * 0.05 + sway * k * k;
			p *= vec2(aspect, 1.0);
			trunk = min(trunk, seg(pq, prev, p) - mix(0.018, 0.01, k));
			prev = p;
		}
		float fronds = 1e3;
		vec2 c = crown * vec2(aspect, 1.0);
		c.x += sway * aspect;
		for (int f = 0; f < 7; f++) {
			float a = -0.3 + float(f) * 0.62 + sin(t * 0.9 + float(f)) * 0.05;
			vec2 dir = vec2(cos(a), sin(a));
			vec2 pp = c;
			for (int s = 1; s <= 5; s++) {
				float k = float(s) / 5.0;
				vec2 np = c + dir * k * 0.2 + vec2(0.0, -k * k * 0.12);
				fronds = min(fronds, seg(pq, pp, np) - 0.012 * (1.0 - k * 0.8));
				pp = np;
			}
		}
		float palm = min(trunk, fronds);
		vec3 dark = mix(vec3(0.16, 0.08, 0.14), vec3(0.02, 0.02, 0.05), dusk);
		col = mix(col, dark, 1.0 - smoothstep(0.0, 0.003, palm));
	}

	// Brush strokes: long dabs of thicker and thinner paint.
	col *= 1.0 + (fbm(uv * vec2(14.0, 70.0)) - 0.5) * 0.12;
	return col;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec2 cell = vec2(grid, grid / aspect);
	vec2 px = grid > 0.0 ? (floor(uv * cell) + 0.5) / cell : uv;
	vec3 col = scene(px, TIME);
	// 15-bit colour with a 4x4 ordered dither, on the texel grid.
	if (grid > 0.0) {
		ivec2 b = ivec2(mod(floor(uv * cell), 4.0));
		float bayer = BAYER[b.y * 4 + b.x] / 16.0 - 0.5;
		col = floor(col * 31.0 + bayer + 0.5) / 31.0;
	}
	ALBEDO = col * level;
}
