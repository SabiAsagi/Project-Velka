shader_type canvas_item;

// 프로젝트 벨카 - 타이틀 오른쪽 그림자 형체 (피그마 시안 .apparition-figure, 176 x 544)
//   머리: 타원 34% x 11% @ (50%, 9%), 검정 .95 → 투명 72%
//   몸  : 타원 50% x 46% @ (50%, 56%), 검정 .90 → 투명 74%
// filter: blur(6px) 는 이미 부드러운 그라데이션이라 거의 차이가 없어 생략한다.

float blob(vec2 uv, vec2 c, vec2 r, float a, float stop) {
	float d = length((uv - c) / r);
	return a * clamp(1.0 - d / stop, 0.0, 1.0);
}

void fragment() {
	float head = blob(UV, vec2(0.5, 0.09), vec2(0.34, 0.11), 0.95, 0.72);
	float body = blob(UV, vec2(0.5, 0.56), vec2(0.5, 0.46), 0.9, 0.74);
	float a = head + body * (1.0 - head);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
