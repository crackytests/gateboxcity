shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform float curve_amount : hint_range(0.0, 0.12) = 0.045;
uniform float chroma_amount : hint_range(0.0, 4.0) = 1.15;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.34;
uniform float grille_strength : hint_range(0.0, 1.0) = 0.18;
uniform float ghost_strength : hint_range(0.0, 1.0) = 0.16;
uniform float static_strength : hint_range(0.0, 1.0) = 0.055;
uniform float jitter_strength : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.58;
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.025;
uniform float phosphor_warmth : hint_range(0.0, 1.0) = 0.22;
uniform float dark_bleed : hint_range(0.0, 1.0) = 0.12;
uniform float tear_frequency : hint_range(0.0, 1.0) = 0.22;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 curve_uv(vec2 uv) {
	vec2 centered = uv * 2.0 - 1.0;
	float radius = dot(centered, centered);
	centered *= 1.0 + radius * curve_amount;
	return centered * 0.5 + 0.5;
}

vec3 sample_crt(vec2 uv, vec2 chroma_dir, vec2 pixel_size) {
	vec2 red_uv = uv + chroma_dir * chroma_amount * pixel_size;
	vec2 blue_uv = uv - chroma_dir * chroma_amount * pixel_size;
	float r = texture(screen_texture, red_uv).r;
	vec3 base = texture(screen_texture, uv).rgb;
	float b = texture(screen_texture, blue_uv).b;
	return vec3(r, base.g, b);
}

void fragment() {
	vec2 raw_uv = SCREEN_UV;
	vec2 uv = curve_uv(raw_uv);
	vec2 pixel_size = SCREEN_PIXEL_SIZE;

	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec2 center_dir = normalize((uv - 0.5) + vec2(0.0001));

	float line_id = floor(uv.y * 180.0);
	float slow_noise = hash12(vec2(line_id * 0.173, floor(TIME * 10.0)));
	float burst = step(1.0 - tear_frequency * 0.035, slow_noise);
	float tear_wave = sin(uv.y * 82.0 + TIME * 18.0);
	float tear = burst * tear_wave * 0.018 * jitter_strength;
	float small_jitter = (hash12(vec2(floor(TIME * 28.0), line_id)) - 0.5) * 0.0015 * jitter_strength;
	uv.x += tear + small_jitter;

	vec3 color = sample_crt(uv, center_dir, pixel_size);
	vec3 ghost_a = texture(screen_texture, uv - vec2(2.0, 0.0) * pixel_size).rgb;
	vec3 ghost_b = texture(screen_texture, uv + vec2(4.0 + tear * 80.0, 0.0) * pixel_size).rgb;
	color = mix(color, color + ghost_a * 0.22 + ghost_b * 0.12, ghost_strength);

	float scanline = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	float scanline_mask = mix(1.0, 0.74 + scanline * 0.26, scanline_strength);

	float grille_slot = mod(FRAGCOORD.x, 3.0);
	vec3 grille = vec3(0.88, 1.0, 0.9);
	grille.r += step(grille_slot, 0.9) * 0.2;
	grille.b += step(2.0, grille_slot) * 0.18;
	grille.g += (1.0 - abs(grille_slot - 1.4)) * 0.08;
	color *= mix(vec3(1.0), grille, grille_strength);
	color *= scanline_mask;

	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 haunted_tint = mix(vec3(0.92, 1.04, 0.92), vec3(1.06, 0.94, 1.08), smoothstep(0.0, 1.0, luma));
	color *= mix(vec3(1.0), haunted_tint, phosphor_warmth);
	color = mix(color, color * color * 1.35, dark_bleed * (1.0 - luma));

	float noise = hash12(FRAGCOORD.xy + vec2(TIME * 87.1, TIME * 19.7)) - 0.5;
	color += noise * static_strength;

	float flicker = 1.0 + (sin(TIME * 55.0) * 0.5 + hash12(vec2(floor(TIME * 24.0), 6.7)) - 0.5) * flicker_strength;
	color *= flicker;

	vec2 vignette_uv = raw_uv * (1.0 - raw_uv.yx);
	float vignette = pow(clamp(vignette_uv.x * vignette_uv.y * 18.0, 0.0, 1.0), 0.32);
	color *= mix(1.0 - vignette_strength, 1.0, vignette);

	float edge_glow = smoothstep(0.34, 0.98, distance(raw_uv, vec2(0.5)));
	vec3 edge_color = vec3(0.04, 0.12, 0.08) + vec3(0.04, 0.0, 0.06) * sin(TIME * 1.7);
	color = mix(color, edge_color, edge_glow * 0.18 * effect_strength);

	vec3 final_color = mix(texture(screen_texture, SCREEN_UV).rgb, color * inside, effect_strength);
	COLOR = vec4(final_color, 1.0);
}
