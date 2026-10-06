shader_type canvas_item;
// 프로젝트 벨카 - 생존 수치 화면 효과
// hurt: 낮은 체력/출혈의 붉은 테두리, pulse: 심박 박동, corruption: 정신력 저하(탈색·노이즈·흔들림)

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float corruption : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 40.0 + TIME * 3.0) * 0.0025 * corruption;
	vec3 col = texture(screen_tex, uv).rgb;
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray) * vec3(0.95, 0.9, 0.92), corruption * 0.75);
	col += (hash(UV * 500.0 + TIME) - 0.5) * 0.18 * corruption;
	float edge = smoothstep(0.3, 0.8, length((UV - 0.5) * vec2(1.0, 0.85)));
	float beat = 0.6 + 0.4 * sin(TIME * (5.0 + 5.0 * pulse));
	col = mix(col, vec3(0.55, 0.0, 0.02), edge * (hurt * 0.85 + pulse * 0.25) * beat);
	COLOR = vec4(col, 1.0);
}
