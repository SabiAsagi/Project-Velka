shader_type canvas_item;
// 프로젝트 벨카 - 스파이 비전 화면 오버레이
// 화면 가장자리를 청록색으로 물들이고 가는 주사선을 흘려 '분석 모드' 느낌을 준다.

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.2, 0.75, 0.85, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float vignette = smoothstep(0.25, 0.75, length(centered * vec2(1.0, 0.8)));
	float scan = 0.5 + 0.5 * sin((UV.y + TIME * 0.08) * 420.0);
	float alpha = (vignette * 0.55 + scan * 0.04) * strength;
	COLOR = vec4(tint.rgb, alpha);
}
