shader_type spatial;
render_mode unshaded;

instance uniform float fade : hint_range(0.0, 1.0) = 0.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	ivec2 pixel = ivec2(mod(floor(FRAGCOORD.xy), 4.0));
	float threshold = (BAYER[pixel.y * 4 + pixel.x] + 0.5) / 16.0;
	if (fade >= 1.0 || threshold < fade) {
		discard;
	}
	ALBEDO = vec3(0.35, 0.25, 0.8);
}
