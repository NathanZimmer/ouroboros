// Copied from https://godotshaders.com/shader/3d-pixelation-filter/
shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture;

const int pixel_size = 8; //resolution must be divisible by pixel_size

void fragment() {
	float x = float(int(FRAGCOORD.x) % pixel_size);
	float y = float(int(FRAGCOORD.y) % pixel_size);

	x = FRAGCOORD.x + floor(float(pixel_size) / 2.0) - x;
	y = FRAGCOORD.y + floor(float(pixel_size) / 2.0) - y;

	ALBEDO = texture(screen_texture, vec2(x, y) / VIEWPORT_SIZE).xyz;
}