shader_type canvas_item;

// 프로젝트 벨카 - 흑백 CCTV 화면 (기본 디자인 시안 .kind-frames: grayscale + contrast 1.25 + brightness 0.9)
uniform float contrast = 1.25;
uniform float brightness = 0.9;

void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	g = (g - 0.5) * contrast + 0.5;
	COLOR = vec4(vec3(clamp(g * brightness, 0.0, 1.0)), c.a);
}
