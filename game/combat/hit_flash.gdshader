// Shared hit flash: mixes the sprite toward the palette white (f4f4f4).
// Set flash from 0 to 1 on the sprite's ShaderMaterial.
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
const vec3 FLASH_WHITE = vec3(0.957, 0.957, 0.957);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, FLASH_WHITE, flash), c.a);
}
