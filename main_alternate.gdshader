// CRT Shader by Harrison Allen
// Refactored variant: curvature removed, flat screen

shader_type canvas_item;

// === INPUT TEXTURE ===
uniform sampler2D tex : filter_linear;

// === MASK SELECTION ===
uniform int mask_type : hint_enum(
	"Dots:1",
	"Aperture Grille:2",
	"Wide Grille:3",
	"Wide Soft Grille:4",
	"Slot Mask:5",
	"Null:0") = 1;

// === IMAGE CONTROLS ===
uniform float sharpness : hint_range(0.5, 1.0) = 0.6666667;
uniform float color_offset : hint_range(-0.5, 0.5) = 0.0;
uniform float mask_brightness : hint_range(0.0, 1.0) = 1.0;
uniform float scanline_brightness : hint_range(0.5, 1.0) = 1.0;
uniform float min_scanline_thickness : hint_range(0.25, 1.0) = 0.5;
uniform float wobble_strength : hint_range(0.0, 1.0) = 0.0;

varying flat float wobble;

void vertex()
{
	// Horizontal CRT jitter only
	wobble = cos(TIME * TAU * 15.0) * wobble_strength / 8192.0;
}

// === COLOR SPACE CONVERSION ===
vec3 linear_to_srgb(vec3 col)
{
	return mix(
		(pow(col, vec3(1.0 / 2.4)) * 1.055) - 0.055,
		col * 12.92,
		lessThan(col, vec3(0.0031318))
	);
}

vec3 srgb_to_linear(vec3 col)
{
	return mix(
		pow((col + 0.055) / 1.055, vec3(2.4)),
		col / 12.92,
		lessThan(col, vec3(0.04045))
	);
}

// === SCANLINE SAMPLING (LINEAR COLOR) ===
vec3 scanlines(vec2 uv)
{
	uv *= vec2(textureSize(tex, 0));

	int y = int(uv.y + 0.5) - 1;
	float x = floor(uv.x);

	float ax = x - 2.0;
	float bx = x - 1.0;
	float cx = x;
	float dx = x + 1.0;
	float ex = x + 2.0;

	vec3 ua = srgb_to_linear(texelFetch(tex, ivec2(int(ax), y), 0).rgb);
	vec3 ub = srgb_to_linear(texelFetch(tex, ivec2(int(bx), y), 0).rgb);
	vec3 uc = srgb_to_linear(texelFetch(tex, ivec2(int(cx), y), 0).rgb);
	vec3 ud = srgb_to_linear(texelFetch(tex, ivec2(int(dx), y), 0).rgb);
	vec3 ue = srgb_to_linear(texelFetch(tex, ivec2(int(ex), y), 0).rgb);

	y += 1;

	vec3 la = srgb_to_linear(texelFetch(tex, ivec2(int(ax), y), 0).rgb);
	vec3 lb = srgb_to_linear(texelFetch(tex, ivec2(int(bx), y), 0).rgb);
	vec3 lc = srgb_to_linear(texelFetch(tex, ivec2(int(cx), y), 0).rgb);
	vec3 ld = srgb_to_linear(texelFetch(tex, ivec2(int(dx), y), 0).rgb);
	vec3 le = srgb_to_linear(texelFetch(tex, ivec2(int(ex), y), 0).rgb);

	vec3 beam = vec3(uv.x - 0.5);
	beam.r -= color_offset;
	beam.b += color_offset;

	vec3 wa = smoothstep(1, 0, (beam - ax) * sharpness);
	vec3 wb = smoothstep(1, 0, (beam - bx) * sharpness);
	vec3 wc = smoothstep(1, 0, abs(beam - cx) * sharpness);
	vec3 wd = smoothstep(1, 0, (dx - beam) * sharpness);
	vec3 we = smoothstep(1, 0, (ex - beam) * sharpness);

	vec3 norm = vec3(1.0) / (wa + wb + wc + wd + we);

	vec3 upper = (ua * wa + ub * wb + uc * wc + ud * wd + ue * we) * norm * scanline_brightness;
	vec3 lower = (la * wa + lb * wb + lc * wc + ld * wd + le * we) * norm * scanline_brightness;

	vec3 ut = mix(vec3(min_scanline_thickness), vec3(1.0), upper);
	vec3 lt = mix(vec3(min_scanline_thickness), vec3(1.0), lower);

	float saw = (uv.y + 0.5) - float(y);

	vec3 ul = smoothstep(1.0, 0.0, vec3(saw) / ut) * upper / ut;
	vec3 ll = smoothstep(1.0, 0.0, vec3(1.0 - saw) / lt) * lower / lt;

	return ul + ll;
}

// === PHOSPHOR MASK PATTERNS ===
vec4 generate_mask(vec2 fc)
{
	switch (mask_type)
	{
		case 1:
		{
			const vec3 p[] = {vec3(1,0,0), vec3(0,1,0), vec3(0,0,1), vec3(0)};
			ivec2 i = ivec2(fc);
			return vec4(p[(i.y * 2 + i.x) % 4], 0.25);
		}
		case 2:
		{
			const vec3 p[] = {vec3(0,1,0), vec3(1,0,1)};
			return vec4(p[int(fc.x) % 2], 0.5);
		}
		case 3:
		{
			const vec3 p[] = {vec3(1,0,0), vec3(0,1,0), vec3(0,0,1), vec3(0)};
			return vec4(p[int(fc.x) % 4], 0.25);
		}
		case 4:
		{
			const vec3 p[] = {
				vec3(1.0,0.125,0.0),
				vec3(0.125,1.0,0.125),
				vec3(0.0,0.125,1.0),
				vec3(0.125,0.0,0.125)};
			return vec4(p[int(fc.x) % 4], 0.3125);
		}
		case 5:
		{
			const vec3 p[] = {
				vec3(1,0,1), vec3(0,1,0), vec3(1,0,1), vec3(0,1,0),
				vec3(0,0,1), vec3(0,1,0), vec3(1,0,0), vec3(0,0,0),
				vec3(1,0,1), vec3(0,1,0), vec3(1,0,1), vec3(0,1,0),
				vec3(1,0,0), vec3(0,0,0), vec3(0,0,1), vec3(0,1,0)};
			ivec2 i = ivec2(fc) % 4;
			return vec4(p[i.y * 4 + i.x], 0.375);
		}
		default:
			return vec4(0.5);
	}
}

vec3 apply_mask(vec3 linear_col, vec2 fc)
{
	vec4 m = generate_mask(fc);
	linear_col *= mix(m.w, 1.0, mask_brightness);

	vec3 target = linear_col / m.w;
	vec3 primary = clamp(target, 0.0, 1.0);
	vec3 secondary = (target - primary) / (1.0 / m.w - 1.0);

	primary *= m.rgb;
	primary += secondary * (1.0 - m.rgb);

	return primary;
}

void fragment()
{
	vec2 uv = UV;
	uv.x += wobble;

	vec3 col = scanlines(uv);
	col = apply_mask(col, FRAGCOORD.xy);
	col = linear_to_srgb(col);

	COLOR.rgb = col;
}