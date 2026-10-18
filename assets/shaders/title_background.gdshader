shader_type canvas_item;

// 프로젝트 벨카 - 타이틀 배경 숨쉬기 (피그마 시안 .background-image · background-breathe)
// saturate · brightness 를 GDScript 가 14초 동안 0.78/0.82 ↔ 0.92/0.90 으로 오간다.
uniform float saturation = 0.78;
uniform float brightness = 0.82;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	c.rgb = mix(vec3(g), c.rgb, saturation) * brightness;
	COLOR = c;
}
