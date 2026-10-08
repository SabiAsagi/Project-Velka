shader_type canvas_item;

// 화면 가장자리를 어둡게 / 물들인다 (긴장 연출, 괴이세계)
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float inner : hint_range(0.0, 1.0) = 0.3;
uniform float outer : hint_range(0.0, 1.5) = 0.85;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float d = length(uv) / 0.8;
	float a = smoothstep(inner, outer, d) * strength;
	COLOR = vec4(tint.rgb, tint.a * a);
}
