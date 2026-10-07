// 프로젝트 벨카 - 화면 노이즈 (지지직) 오버레이
// 용도: 사진·화면에 "무언가 스쳐 지나가는" 순간 (프롤로그 P-02 사진 노이즈 등)
// 대상: Forward+ / 2D CanvasItem, 전체 화면 ColorRect 한 장. 텍스처 샘플 없음.
shader_type canvas_item;

group_uniforms noise;
/// 노이즈 알갱이 크기 (화면 픽셀 단위)
uniform float grain_size : hint_range(1.0, 8.0) = 3.0;
/// 노이즈가 바뀌는 속도 (초당 프레임 수)
uniform float flicker_rate : hint_range(1.0, 60.0) = 24.0;
/// 전체 불투명도
uniform float strength : hint_range(0.0, 1.0) = 0.55;
/// 가로 줄무늬(주사선) 세기
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
group_uniforms;

// 2D 해시: 좌표마다 0~1 의사 난수
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * flicker_rate);
	vec2 cell = floor(FRAGCOORD.xy / grain_size);
	float n = hash(cell + frame * 7.13);
	// 줄마다 밝기를 흔들어 주사선처럼 보이게
	float line = hash(vec2(floor(FRAGCOORD.y / (grain_size * 2.0)), frame));
	float value = mix(n, n * line, scanline_strength);
	COLOR = vec4(vec3(value), strength);
}
