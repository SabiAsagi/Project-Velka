shader_type spatial;
// 프로젝트 벨카 - 조사 가능 오브젝트 강조 오버레이 (material_overlay 전용)
// 윤곽(림) 위주로 은은하게 빛나며 맥동한다. 색은 조작 캐릭터 테마색을 넘겨받는다.
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 glow_color : source_color = vec4(0.27, 0.63, 0.71, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.8;
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float pulse_speed = 4.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	ALBEDO = glow_color.rgb * (0.18 + rim) * intensity * pulse;
}
