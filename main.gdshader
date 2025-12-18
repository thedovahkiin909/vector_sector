shader_type canvas_item;

// CRT Effect Shader for Retro Terminal
// Godot 4.4 compatible

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.30;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.02;
uniform float noise_strength : hint_range(0.0, 0.1) = 0.02;
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.015;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.002;

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// No curvature distortion (removed entirely)
	
	// Chromatic aberration for color separation (vibrant effect)
	float r = texture(SCREEN_TEXTURE, uv + vec2(chromatic_aberration, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(chromatic_aberration, 0.0)).b;
	vec3 col = vec3(r, g, b);
	
	// More vibrant scanlines (doubled strength, increased frequency)
	col -= sin(uv.y * 800.0) * scanline_strength;
	
	// Lightening vignette effect (brightens edges)
	vec2 centered = uv * 2.0 - 1.0;
	float vig = vignette_strength * smoothstep(0.0, 1.0, length(centered));
	col *= 1.0 + vig;
	
	// Film grain noise
	float noise = fract(
		sin(dot(uv * TIME, vec2(12.9898, 78.233))) * 43758.5453
	);
	col += (noise - 0.5) * noise_strength;
	
	// Subtle screen flicker
	col *= 1.0 + sin(TIME * 60.0) * flicker_strength;
	
	// Slight green boost for terminal aesthetic
	col.g *= 1.08;
	
	COLOR = vec4(col, 1.0);
}
