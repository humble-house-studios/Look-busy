// PS1-style surface for the office: wobbly snapped vertices, warped (affine)
// textures, light worked out per vertex, chunky procedural texels, fog, and a
// 15-bit dithered palette. Unshaded, so it looks the same on every renderer.
// The room's lights are fixed below (they match office.gd's layout,
// including the window's daylight and the glow from each CRT).
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 albedo : source_color = vec3(0.6);
uniform vec3 albedo2 : source_color = vec3(0.4);
// 0 flat, 1 carpet, 2 ceiling tiles, 3 wood, 4 blinds, 5 lino, 6 speckle, 7 keys
uniform int pattern = 0;
// Texels per metre.
uniform float texel = 24.0;
uniform vec3 emission : source_color = vec3(0.0);
// 0 = no vertex wobble (the screen pass), 1 = full PS1 wobble.
uniform float wobble = 1.0;
// The rooms past the office door (scenes/office/ladder.gd) bring their own
// lights, ambient and haze; office materials leave these at their defaults.
uniform float office_lights = 1.0;
uniform vec3 room_pos[6];
uniform vec3 room_col[6];
uniform float room_range = 0.0;
uniform vec3 room_ambient = vec3(-1.0);
uniform vec3 room_fog = vec3(-1.0);
// After hours (0 = golden hour, 1 = night): set for the whole office by
// look_busy.gd when 5 PM rings mid-game (project.godot [shader_globals]).
global uniform float after_hours;

varying vec4 aff;
varying vec3 light;
varying vec3 wnormal;
varying float fog;

// Golden hour: a low orange sun through the window blinds does the work (two
// lights: the glass, and the long beam it throws across the carpet), the
// ceiling panels are dimmed, a soft glow comes off each CRT, and a faint warm
// bounce keeps the far right corner (the Loot Machine) readable. Low ambient
// so shapes get real shadows, which is what stops the boxes looking flat.
const int LIGHTS = 8;
const vec3 L_POS[8] = vec3[](vec3(0.0, 2.45, -1.6), vec3(0.0, 2.45, 2.2), vec3(-3.1, 1.6, -0.5), vec3(-1.0, 0.3, -0.2), vec3(0.0, 1.17, -2.15), vec3(-2.75, 1.15, 2.0), vec3(2.75, 1.15, -0.9), vec3(2.7, 1.4, 1.0));
const vec3 L_COL[8] = vec3[](vec3(0.22, 0.17, 0.12), vec3(0.2, 0.15, 0.1), vec3(1.7, 0.95, 0.42), vec3(1.1, 0.55, 0.2), vec3(0.25, 0.35, 0.45), vec3(0.25, 0.4, 0.4), vec3(0.3, 0.4, 0.3), vec3(0.32, 0.2, 0.11));
const float L_RANGE[8] = float[](6.0, 6.0, 8.5, 4.5, 1.8, 1.6, 1.6, 3.6);
// After hours: ceiling off, moonlight in the window, Dale's desk lamp where
// the sunbeam was, and the CRTs (and the Loot Machine) light the room.
const vec3 N_POS3 = vec3(-2.45, 1.15, -0.3);
const vec3 N_COL[8] = vec3[](vec3(0.0), vec3(0.03, 0.04, 0.07), vec3(0.18, 0.26, 0.5), vec3(1.0, 0.62, 0.3), vec3(0.45, 0.75, 1.0), vec3(0.35, 0.85, 0.75), vec3(0.45, 0.9, 0.45), vec3(0.5, 0.2, 0.14));
const float N_RANGE[8] = float[](6.0, 6.0, 6.0, 2.6, 3.2, 2.8, 2.8, 2.6);
const vec3 N_AMBIENT = vec3(0.07, 0.08, 0.14);
const vec3 N_FOG_COL = vec3(0.03, 0.04, 0.09);
const vec3 AMBIENT = vec3(0.32, 0.25, 0.22);
const vec3 FOG_COL = vec3(0.9, 0.7, 0.52);
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Sky bounce from above, warm floor bounce from below.
	float ah = clamp(after_hours, 0.0, 1.0);
	vec3 amb = room_ambient.x < 0.0 ? mix(AMBIENT, N_AMBIENT, ah) : room_ambient;
	vec3 lit = amb * (0.85 + 0.15 * n.y);
	for (int i = 0; i < LIGHTS; i++) {
		vec3 lp = i == 3 ? mix(L_POS[i], N_POS3, ah) : L_POS[i];
		vec3 d = lp - wp;
		float dist = max(length(d), 0.001);
		float att = clamp(1.0 - dist / mix(L_RANGE[i], N_RANGE[i], ah), 0.0, 1.0);
		lit += office_lights * mix(L_COL[i], N_COL[i], ah) * att * att * (0.3 + 0.7 * max(dot(n, d / dist), 0.0));
	}
	if (room_range > 0.0) {
		for (int i = 0; i < 6; i++) {
			vec3 d = room_pos[i] - wp;
			float dist = max(length(d), 0.001);
			float att = clamp(1.0 - dist / room_range, 0.0, 1.0);
			lit += room_col[i] * att * att * (0.3 + 0.7 * max(dot(n, d / dist), 0.0));
		}
	}
	light = lit;
	wnormal = n;
	vec4 view = VIEW_MATRIX * vec4(wp, 1.0);
	// A faint warm haze at the far end of the room (not dark fog); after
	// hours the dark closes in.
	float vd = length(view.xyz);
	fog = mix(0.22 * smoothstep(4.0, 12.0, vd), 0.55 * smoothstep(2.5, 10.0, vd), office_lights * ah);
	vec4 clip = PROJECTION_MATRIX * view;
	// Snap to a coarse screen grid: the classic PS1 jitter.
	vec2 grid = VIEWPORT_SIZE * 0.5;
	vec2 snapped = round(clip.xy / clip.w * grid) / grid * clip.w;
	clip.xy = mix(clip.xy, snapped, wobble);
	POSITION = clip;
	// Interpolate world position * w and w, then divide: affine texture warp.
	aff = vec4(wp * clip.w, clip.w);
}

void fragment() {
	vec3 wp = aff.xyz / aff.w;
	vec3 an = abs(wnormal);
	vec2 p = an.y > max(an.x, an.z) ? wp.xz : (an.x > an.z ? wp.zy : wp.xy);
	vec2 tp = floor(p * texel);
	float h = hash(tp);
	vec3 col = albedo;
	if (pattern == 1) {
		col = mix(albedo, albedo2, step(0.6, h)) * (0.85 + 0.3 * hash(tp + 7.0));
	} else if (pattern == 2) {
		vec2 f = fract(p / 0.6);
		float edge = step(0.93, max(f.x, f.y));
		col = mix(albedo * (0.93 + 0.12 * step(0.8, h)), albedo2, edge);
	} else if (pattern == 3) {
		float g = fract(tp.y * 0.21 + sin(tp.x * 0.05) * 0.6 + h * 0.15);
		col = mix(albedo, albedo2, step(0.62, g));
	} else if (pattern == 4) {
		col = mix(albedo, albedo2, step(0.6, fract(wp.y * 11.0)));
	} else if (pattern == 5) {
		vec2 c = floor(p / 0.3);
		col = mix(albedo, albedo2, mod(c.x + c.y, 2.0)) * (0.92 + 0.12 * h);
	} else if (pattern == 6) {
		col = albedo * (0.9 + 0.2 * h);
	} else if (pattern == 7) {
		vec2 f = fract(p * vec2(38.0, 30.0));
		col = mix(albedo2, albedo, step(0.22, min(f.x, f.y)));
	}
	col = col * light + emission;
	float ah = clamp(after_hours, 0.0, 1.0) * office_lights;
	col = mix(col, room_fog.x < 0.0 ? mix(FOG_COL, N_FOG_COL, ah) : room_fog, fog);
	// Grade: lift the shadows toward peach (golden hour), or blue after hours.
	col += mix(vec3(0.05, 0.025, 0.0), vec3(0.0, 0.01, 0.035), ah) * (1.0 - clamp(dot(col, vec3(0.333)), 0.0, 1.0));
	// 15-bit colour with a 4x4 ordered dither.
	ivec2 fc = ivec2(FRAGCOORD.xy) % 4;
	float d = BAYER[fc.y * 4 + fc.x] / 16.0 - 0.5;
	col = pow(max(col, vec3(0.0)), vec3(1.0 / 2.2));
	col = floor(col * 31.0 + 0.5 + d) / 31.0;
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
}
